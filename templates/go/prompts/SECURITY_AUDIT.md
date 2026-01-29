# Security Audit — Go Template

## Goal

Comprehensive security audit of Go application (Gin/Chi). Act as a Senior Security Engineer.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for audits.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Hardcoded secrets | `grep -rn "sk-\|password.*:=.*\"" . --include="*.go"` | Empty |
| 2 | SQL injection | `grep -rn "fmt.Sprintf.*SELECT\|Sprintf.*INSERT" . --include="*.go"` | Empty |
| 3 | Unchecked errors | `golangci-lint run --enable errcheck` | No errors |
| 4 | gosec scan | `gosec ./...` | No high severity |
| 5 | go mod audit | `go list -json -m all \| nancy sleuth` | No vulnerabilities |
| 6 | Secret key | `echo $JWT_SECRET \| wc -c` | >= 32 characters |
| 7 | Open redirect | `grep -rn "Redirect.*c.Query\|Redirect.*r.URL" . --include="*.go"` | Check validation |
| 8 | .env public | Verify `.env` not in static/ directory | Not accessible |

If all 5 = OK → Basic security level OK.

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# security-check.sh

echo "Security Quick Check — Go..."

# 1. Hardcoded secrets
SECRETS=$(grep -rn "sk-\|apiKey.*:=.*\"[a-zA-Z0-9]" . --include="*.go" 2>/dev/null | grep -v "_test.go\|os.Getenv")
[ -z "$SECRETS" ] && echo "Secrets: No hardcoded keys" || echo "Secrets: Found hardcoded keys!"

# 2. SQL injection patterns
SQLI=$(grep -rn 'fmt.Sprintf.*"SELECT\|fmt.Sprintf.*"INSERT\|fmt.Sprintf.*"UPDATE' . --include="*.go" 2>/dev/null)
[ -z "$SQLI" ] && echo "SQL: No injection patterns" || echo "SQL: Potential injection!"

# 3. Unchecked errors
ERRS=$(golangci-lint run --enable errcheck 2>/dev/null | grep -c "Error return value")
[ "$ERRS" -eq 0 ] && echo "Errors: All checked" || echo "Errors: $ERRS unchecked errors"

# 4. exec.Command
EXEC=$(grep -rn "exec.Command" . --include="*.go" 2>/dev/null | grep -v "_test.go")
[ -z "$EXEC" ] && echo "Exec: No exec.Command" || echo "Exec: Found exec.Command (verify input)"

# 5. gosec (if available)
if command -v gosec &> /dev/null; then
    gosec -quiet ./... 2>/dev/null | grep -q "High" && echo "Gosec: High severity issues" || echo "Gosec: No high severity"
else
    echo "Gosec: Not installed (run: go install github.com/securego/gosec/v2/cmd/gosec@latest)"
fi

# 6. Secret key strength
SECRET_LEN=$(echo -n "$JWT_SECRET" | wc -c)
[ "$SECRET_LEN" -ge 32 ] && echo "Secret: JWT_SECRET is strong (${SECRET_LEN} chars)" || echo "Secret: JWT_SECRET too short (${SECRET_LEN} chars, need >= 32)"

# 7. Open redirect
REDIRECT=$(grep -rn "Redirect.*c.Query\|Redirect.*r.URL.Query\|Redirect.*r.FormValue" . --include="*.go" 2>/dev/null | grep -v "_test.go")
[ -z "$REDIRECT" ] && echo "Redirect: No open redirect patterns" || echo "Redirect: Found redirect patterns (verify validation)"

# 8. Dangerous functions
DANGEROUS=$(grep -rn 'exec\.Command.*"-c"\|os\.Exec\|exec\.Command.*+' . --include="*.go" 2>/dev/null | grep -v "test\|vendor\|_test.go")
[ -z "$DANGEROUS" ] && echo "Commands: No shell injection patterns" || echo "Commands: Found exec patterns (verify input)"

# 9. .env exposure
ENV_SERVE=$(grep -rn 'FileServer.*Dir(".")' . --include="*.go" 2>/dev/null | grep -v "test\|vendor")
[ -z "$ENV_SERVE" ] && echo "Static: Not serving root dir" || echo "Static: Serving root directory (may expose .env)!"

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS

**Fill before audit:**

**Already implemented:**

- [ ] Authentication: [JWT / Session / OAuth2]
- [ ] Authorization: [Middleware / RBAC]
- [ ] Input validation: [go-playground/validator]
- [ ] Database: [sqlx / GORM / pgx / raw SQL]

**Public endpoints (by design):**

- `/health` — health check
- `/metrics` — Prometheus metrics
- `/api/webhooks/*` — webhooks (verify signature!)

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Exploitable vulnerability: RCE, SQLi, auth bypass | **BLOCKER** — fix immediately |
| HIGH | Serious vulnerability, requires auth or complex exploitation | Fix before deploy |
| MEDIUM | Potential vulnerability, low risk | Fix in next sprint |
| LOW | Best practice, defense in depth | Backlog |
| INFO | Information, no action required | — |

---

## 1. INPUT VALIDATION

### 1.1 go-playground/validator

```go
// CRITICAL — no validation
func CreateUser(c *gin.Context) {
    var req map[string]interface{}
    c.BindJSON(&req)  // Anything goes!
}

// Good — validator
import "github.com/go-playground/validator/v10"

type CreateUserRequest struct {
    Email string `json:"email" validate:"required,email"`
    Name  string `json:"name" validate:"required,min=2,max=100"`
    Age   *int   `json:"age" validate:"omitempty,gte=0,lte=150"`
}

var validate = validator.New()

func CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    if err := validate.Struct(req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
}
```

- [ ] All endpoints validate input
- [ ] String fields have max length
- [ ] Number fields have boundaries

### 1.2 Path Parameters

```go
// CRITICAL — no UUID validation
func GetUser(c *gin.Context) {
    id := c.Param("id")  // Can be anything
    user, _ := db.Query("SELECT * FROM users WHERE id = $1", id)
}

// Good — validation
import "github.com/google/uuid"

func GetUser(c *gin.Context) {
    id := c.Param("id")
    if _, err := uuid.Parse(id); err != nil {
        c.JSON(400, gin.H{"error": "invalid id"})
        return
    }
}
```

- [ ] UUID parameters validated
- [ ] Integer parameters parsed with validation

---

## 2. SQL INJECTION

### 2.1 Raw Queries

```go
// CRITICAL — SQL Injection
id := c.Param("id")
query := fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", id)
db.Query(query)

// CRITICAL — string concatenation
search := c.Query("q")
query := "SELECT * FROM users WHERE name LIKE '%" + search + "%'"

// Good — parameterized queries
db.Query("SELECT * FROM users WHERE id = $1", id)
db.Query("SELECT * FROM users WHERE name LIKE $1", "%"+search+"%")

// Good — sqlx
var user User
err := db.Get(&user, "SELECT * FROM users WHERE id = $1", id)
```

- [ ] No fmt.Sprintf in SQL
- [ ] No string concatenation in SQL
- [ ] Placeholders used ($1, ?)

### 2.2 GORM

```go
// CRITICAL — Raw with concatenation
db.Raw("SELECT * FROM users WHERE name = '" + name + "'").Scan(&users)

// Good — bindings
db.Raw("SELECT * FROM users WHERE name = ?", name).Scan(&users)

// Better — Query API
db.Where("name = ?", name).Find(&users)
```

- [ ] Raw() always with bindings
- [ ] Query API used where possible

---

## 3. COMMAND INJECTION

### 3.1 exec.Command

```go
// CRITICAL — Command Injection
filename := c.PostForm("filename")
cmd := exec.Command("sh", "-c", "convert "+filename+" output.pdf")

// CRITICAL — via bash
exec.Command("bash", "-c", userInput)

// Good — no shell, argument list
filename := filepath.Base(c.PostForm("filename"))  // Sanitize
cmd := exec.Command("convert", filename, "output.pdf")
```

- [ ] No exec.Command with shell (-c)
- [ ] Filenames sanitized via filepath.Base()
- [ ] User input never passed to shell

### 3.2 Dangerous Functions

Some Go functions allow arbitrary command execution.

```go
// ❌ Dangerous — shell injection via os/exec
cmd := exec.Command("sh", "-c", userInput)
cmd := exec.Command("bash", "-c", "echo " + userInput)

// ✅ Safe — no shell, arguments as array
cmd := exec.Command("echo", userInput)  // Direct exec, no shell
```

- [ ] No `exec.Command("sh", "-c", userInput)` — use direct command + args
- [ ] No string concatenation in command arguments
- [ ] No `os.Exec` with user-controlled paths
- [ ] CGo calls validated if accepting user input

---

## 4. AUTHENTICATION

### 4.1 JWT Security

```go
// CRITICAL — weak secret
var jwtSecret = []byte("secret")

// CRITICAL — no method verification
token.Claims.(*jwt.RegisteredClaims)  // Without algorithm check

// Good
var jwtSecret = []byte(os.Getenv("JWT_SECRET"))  // Minimum 32 characters

func ParseToken(tokenString string) (*jwt.RegisteredClaims, error) {
    token, err := jwt.ParseWithClaims(
        tokenString,
        &jwt.RegisteredClaims{},
        func(token *jwt.Token) (interface{}, error) {
            // Verify algorithm
            if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
            }
            return jwtSecret, nil
        },
    )
    if err != nil {
        return nil, err
    }
    return token.Claims.(*jwt.RegisteredClaims), nil
}
```

- [ ] JWT secret from env (minimum 32 characters)
- [ ] Algorithm verified in callback
- [ ] Expiration verified

### 4.2 Password Hashing

```go
// CRITICAL — plain text
user.Password = password

// CRITICAL — weak hash
hash := md5.Sum([]byte(password))

// ✅ BEST — Argon2id (OWASP recommended)
import "golang.org/x/crypto/argon2"

func HashPassword(password string) (string, error) {
    salt := make([]byte, 16)
    if _, err := rand.Read(salt); err != nil {
        return "", err
    }
    hash := argon2.IDKey([]byte(password), salt, 3, 64*1024, 4, 32)
    // Store: $argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>
    return encodeArgon2Hash(hash, salt), nil
}

// ✅ Good — bcrypt (acceptable alternative)
import "golang.org/x/crypto/bcrypt"

func HashPassword(password string) (string, error) {
    bytes, err := bcrypt.GenerateFromPassword([]byte(password), 12)  // Min cost 12
    return string(bytes), err
}

func CheckPassword(password, hash string) bool {
    err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
    return err == nil
}
```

- [ ] Passwords hashed with Argon2id (preferred) or bcrypt (cost >= 12)
- [ ] No MD5/SHA1/SHA256 for passwords
- [ ] Use crypto/rand for salt generation (not math/rand)

---

## 5. ERROR HANDLING

### 5.1 Unchecked Errors

```go
// CRITICAL — error ignored
file, _ := os.Open(filename)  // Can be nil!
defer file.Close()

db.Exec("DELETE FROM users WHERE id = $1", id)  // Error lost

// Good — always check
file, err := os.Open(filename)
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer file.Close()

if _, err := db.Exec("DELETE FROM users WHERE id = $1", id); err != nil {
    return fmt.Errorf("failed to delete user: %w", err)
}
```

- [ ] All errors checked
- [ ] No `_` for error values
- [ ] Errors wrapped with context (%w)

### 5.2 Error Exposure

```go
// CRITICAL — technical details to user
func GetUser(c *gin.Context) {
    user, err := db.GetUser(id)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})  // Stack trace!
        return
    }
}

// Good — generic messages
func GetUser(c *gin.Context) {
    user, err := db.GetUser(id)
    if err != nil {
        log.Error("failed to get user", "error", err, "id", id)
        c.JSON(500, gin.H{"error": "internal error"})
        return
    }
}
```

- [ ] User does not see stack traces
- [ ] Errors logged with context

---

## 6. AUTHORIZATION

### 6.1 Resource Access

```go
// CRITICAL — no ownership check
func GetDocument(c *gin.Context) {
    id := c.Param("id")
    doc, _ := db.GetDocument(id)
    c.JSON(200, doc)  // Anyone can access!
}

// Good — ownership check
func GetDocument(c *gin.Context) {
    userID := c.GetString("user_id")  // From middleware
    docID := c.Param("id")

    doc, err := db.GetDocumentByUser(docID, userID)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            c.JSON(404, gin.H{"error": "not found"})
            return
        }
        c.JSON(500, gin.H{"error": "internal error"})
        return
    }
    c.JSON(200, doc)
}
```

- [ ] Protected routes check auth middleware
- [ ] Resource ownership verified

---

## 7. TLS & CRYPTO

### 7.1 TLS Configuration

```go
// CRITICAL — weak TLS settings
server := &http.Server{}

// Good — modern settings
server := &http.Server{
    TLSConfig: &tls.Config{
        MinVersion:               tls.VersionTLS13,
        PreferServerCipherSuites: true,
    },
}
```

- [ ] Minimum TLS 1.2 (preferably 1.3)
- [ ] Strong cipher suites

### 7.2 Random Generation

```go
// CRITICAL — predictable random
import "math/rand"
token := rand.Int63()

// Good — cryptographically secure
import "crypto/rand"

func GenerateToken(length int) (string, error) {
    bytes := make([]byte, length)
    if _, err := rand.Read(bytes); err != nil {
        return "", err
    }
    return base64.URLEncoding.EncodeToString(bytes), nil
}
```

- [ ] crypto/rand used for secrets
- [ ] math/rand only for non-security purposes

---

## 8. SECRETS MANAGEMENT

```go
// CRITICAL — hardcoded
var apiKey = "sk-ant-xxxxx"

// Good — env variables
var apiKey = os.Getenv("API_KEY")

// Better — viper/envconfig
type Config struct {
    APIKey string `envconfig:"API_KEY" required:"true"`
}
```

- [ ] No hardcoded secrets
- [ ] Secrets from env variables
- [ ] Using viper/envconfig

### 8.2 Secret Key Validation

```go
// ❌ Weak secret
var jwtSecret = []byte("secret")
var jwtSecret = []byte(os.Getenv("JWT_SECRET")) // No length check!

// ✅ Strong secret with validation
func init() {
    secret := os.Getenv("JWT_SECRET")
    if len(secret) < 32 {
        log.Fatal("JWT_SECRET must be at least 32 characters")
    }
}
```

- [ ] JWT secret is at least 32 characters
- [ ] Application validates secret length on startup
- [ ] No weak fallback values
- [ ] Different secrets per environment

### 8.3 Session/Token Timeout

```go
// ❌ Bad — no expiration
token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
    "user_id": userID,
    // No "exp" claim!
})

// ✅ Good — short expiration
token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
    Subject:   userID,
    ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * time.Minute)),
    IssuedAt:  jwt.NewNumericDate(time.Now()),
})

// ✅ Cookie-based sessions
http.SetCookie(w, &http.Cookie{
    Name:     "session",
    Value:    sessionID,
    MaxAge:   1800,     // 30 minutes
    HttpOnly: true,
    Secure:   true,
    SameSite: http.SameSiteLaxMode,
})
```

- [ ] Session/token expiry is configured (recommended: 15-30 minutes for sensitive apps)
- [ ] JWT has `ExpiresAt` claim (recommended: 15-60 minutes)
- [ ] Cookie `MaxAge` is set
- [ ] `HttpOnly`, `Secure`, `SameSite` cookie flags set
- [ ] Refresh token rotation is implemented
- [ ] Session is invalidated on logout (server-side session store)

---

## 9. RATE LIMITING

```go
// CRITICAL — no rate limiting
r.POST("/login", loginHandler)

// Good — rate limiting middleware
import "golang.org/x/time/rate"

func RateLimiter(limit rate.Limit, burst int) gin.HandlerFunc {
    limiter := rate.NewLimiter(limit, burst)
    return func(c *gin.Context) {
        if !limiter.Allow() {
            c.JSON(429, gin.H{"error": "rate limit exceeded"})
            c.Abort()
            return
        }
        c.Next()
    }
}

r.POST("/login", RateLimiter(rate.Every(time.Minute/5), 5), loginHandler)
```

- [ ] Login endpoint has rate limiting
- [ ] Sensitive endpoints protected

---

## 10. CONTEXT PROPAGATION

```go
// CRITICAL — no context
func GetUser(id string) (*User, error) {
    row := db.QueryRow("SELECT * FROM users WHERE id = $1", id)
    // Not cancelled on timeout!
}

// Good — context propagation
func GetUser(ctx context.Context, id string) (*User, error) {
    row := db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id)
}

// In handler
func GetUserHandler(c *gin.Context) {
    ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
    defer cancel()

    user, err := GetUser(ctx, c.Param("id"))
}
```

- [ ] Context passed everywhere
- [ ] Timeout set for DB/HTTP calls
- [ ] Context cancelled via defer cancel()

---

## 11. DEPENDENCY SECURITY

```bash
# Nancy (govulncheck alternative)
go list -json -m all | nancy sleuth

# Govulncheck (official)
govulncheck ./...

# go mod tidy
go mod tidy
```

- [ ] govulncheck without critical vulnerabilities
- [ ] Dependencies updated

---

## 12. UNSAFE DESERIALIZATION

Deserializing untrusted data can lead to unexpected behavior.

```go
// ❌ Risky — gob/encoding can instantiate arbitrary types
gob.Register(MyType{})
decoder := gob.NewDecoder(userInput)
decoder.Decode(&target)

// ✅ Safe — JSON is data-only
json.NewDecoder(userInput).Decode(&target)
```

- [ ] No `encoding/gob` with untrusted input (gob can call methods during decode)
- [ ] `encoding/xml` input is validated (XXE attacks possible)
- [ ] YAML parsing uses safe defaults (no arbitrary type instantiation)
- [ ] Prefer JSON for external data exchange

---

## 13. OPEN REDIRECTION

```go
// ❌ Dangerous — redirect to user-supplied URL
func Callback(c *gin.Context) {
    returnURL := c.Query("returnUrl")
    c.Redirect(http.StatusFound, returnURL) // Open redirect!
}

// ✅ Safe — validate URL
var allowedHosts = map[string]bool{
    "myapp.com":     true,
    "www.myapp.com": true,
}

func Callback(c *gin.Context) {
    returnURL := c.Query("returnUrl")
    parsed, err := url.Parse(returnURL)
    if err != nil || (parsed.Host != "" && !allowedHosts[parsed.Host]) {
        c.Redirect(http.StatusFound, "/")
        return
    }
    c.Redirect(http.StatusFound, returnURL)
}
```

- [ ] No `c.Redirect()` with raw user input
- [ ] Redirect URLs validated against whitelist or restricted to relative paths

### 13.2 Host Injection

```go
// ❌ Dangerous — trusting Host header
func ForgotPassword(c *gin.Context) {
    host := c.Request.Host
    resetLink := fmt.Sprintf("https://%s/reset?token=%s", host, token) // Spoofable!
}

// ✅ Safe — use configured base URL
var baseURL = os.Getenv("APP_URL")

func ForgotPassword(c *gin.Context) {
    resetLink := fmt.Sprintf("%s/reset?token=%s", baseURL, token)
}
```

- [ ] Password reset links use configured `APP_URL`, not `c.Request.Host`
- [ ] Email links use configured base URL

### 13.3 HSTS (HTTP Strict Transport Security)

```go
// Middleware
func HSTS() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
        c.Next()
    }
}

r := gin.Default()
r.Use(HSTS())
```

- [ ] HSTS header set in production
- [ ] `max-age` >= 31536000

### 13.4 .env Public Access

`.env` files accessible via web expose all secrets.

```go
// ❌ Dangerous — serving entire directory including .env
http.Handle("/", http.FileServer(http.Dir(".")))

// ✅ Safe — serve only specific directory
http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
```

- [ ] `.env` is not served by the HTTP handler (not in static file directories)
- [ ] `.env` is in `.gitignore`
- [ ] Sensitive config loaded from environment variables, not `.env` in production
- [ ] Web server/reverse proxy blocks access to dotfiles
- [ ] `.env` file permissions: `600` or `640`
- [ ] Application binary runs as non-root user
- [ ] Log directory not world-writable
- [ ] Config files not world-readable

### 13.5 Open Redirection (net/http)

Redirecting users to unvalidated URLs enables phishing attacks.

```go
// ❌ Dangerous — redirect to user-supplied URL
http.Redirect(w, r, r.URL.Query().Get("redirect"), http.StatusFound)

// ✅ Safe — validate redirect URL
func safeRedirect(w http.ResponseWriter, r *http.Request, fallback string) {
    target := r.URL.Query().Get("redirect")
    u, err := url.Parse(target)
    if err != nil || u.Host != "" { // Reject absolute URLs
        http.Redirect(w, r, fallback, http.StatusFound)
        return
    }
    http.Redirect(w, r, target, http.StatusFound)
}
```

- [ ] No redirects using raw user input (`r.URL.Query()`, `r.FormValue()`)
- [ ] Redirect URLs are validated (relative-only or domain whitelist)
- [ ] External URLs require explicit allow-list

---

## 14. REPORT FORMAT

```markdown
# Security Audit Report — [Project Name]
Date: [date]
Auditor: Claude (Senior Security Engineer)

## Executive Summary

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | X | X fixed |
| HIGH | X | X fixed |
| MEDIUM | X | X fixed |
| LOW | X | - |

**Overall Risk Level**: [Critical/High/Medium/Low]

## CRITICAL Vulnerabilities

### CRIT-001: [Title]
**Location**: `internal/handler/xxx.go:XX`
**Description**: ...
**Impact**: ...
**Remediation**: ...

## Security Controls in Place
- [x] JWT authentication
- [x] Input validation (validator)
- [ ] Rate limiting on all endpoints
```

---

## 15. ACTIONS

1. **Quick Check** — go through 5 points
2. **gosec scan** — `gosec ./...`
3. **Scan** — go through all sections
4. **Classify** — Critical → Low
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start audit. Quick Check first, then Executive Summary.
