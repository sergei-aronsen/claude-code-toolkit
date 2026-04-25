# Security Audit — Go Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 14. SSRF (Server-Side Request Forgery)

If the application fetches URLs provided by users via `net/http`, attackers can target internal services or cloud metadata.

```go
// ❌ Dangerous — SSRF
url := r.URL.Query().Get("url")
resp, _ := http.Get(url) // Can access internal services!

// ✅ Safe — validate URL before fetching
func isURLSafe(rawURL string) bool {
    u, err := url.Parse(rawURL)
    if err != nil {
        return false
    }
    if u.Scheme != "http" && u.Scheme != "https" {
        return false
    }
    blocked := []string{"127.0.0.1", "localhost", "169.254.169.254",
        "0.0.0.0", "[::1]"}
    blockedPrefixes := []string{"10.", "172.16.", "172.17.", "172.18.",
        "172.19.", "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
        "172.25.", "172.26.", "172.27.", "172.28.", "172.29.", "172.30.",
        "172.31.", "192.168.", "fc00:", "fe80:"}
    host := strings.ToLower(u.Hostname())
    for _, b := range blocked {
        if host == b {
            return false
        }
    }
    for _, p := range blockedPrefixes {
        if strings.HasPrefix(host, p) {
            return false
        }
    }
    return true
}

// Usage
client := &http.Client{Timeout: 10 * time.Second}
if !isURLSafe(userURL) {
    http.Error(w, "URL not allowed", http.StatusBadRequest)
    return
}
resp, err := client.Get(userURL)
```

- [ ] URLs from user input are validated before `http.Get()` / `http.Client.Do()`
- [ ] Internal/private IP ranges are blocked
- [ ] Only http/https schemes allowed
- [ ] Cloud metadata endpoints blocked (169.254.169.254)
- [ ] `http.Client` has `Timeout` configured

---

## 17. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

## Procedure

For every candidate finding, execute these six steps in order. Produce a `## SELF-CHECK` block per finding (in your scratchpad — not the final report) before deciding whether to report or drop it. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow user input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look exploitable in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the threat surface (e.g. an upstream sanitizer documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, etc.), the finding is a design trade-off, not a vulnerability. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual exploit scenario, not the rule label. A theoretical XSS sink behind 3 unlikely preconditions and no PII is not CRITICAL. If you cannot describe a concrete attack path the user would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `lib/utils.py:5` | `SEC-EVAL` | 5 | `eval is required by build-time codegen; never reached at runtime` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not exploit-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op (record `cross-ref skipped: no allowlist file present`) but the step itself MUST be acknowledged in the SELF-CHECK trace.

## 15. REPORT FORMAT

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

## 16. ACTIONS

## 18. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

## Report Path

```text
.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md
```

- `<type>` is one of the 7 canonical slugs documented in the next section. Backward-compat aliases resolve to a canonical slug at dispatch time.
- Timestamp is local time, generated with `date '+%Y-%m-%d-%H%M'` (24-hour, no separator between hour and minute).
- The audit creates the directory with `mkdir -p .claude/audits` on first write.
- The toolkit does NOT auto-add `.claude/audits/` to `.gitignore` — let the user decide which audit reports to commit.

---

## Type Slug to Prompt File Map

| `/audit` argument | Report filename slug | Prompt loaded |
|-------------------|----------------------|---------------|
| `security` | `security` | `templates/<framework>/prompts/SECURITY_AUDIT.md` |
| `code-review` | `code-review` | `templates/<framework>/prompts/CODE_REVIEW.md` |
| `performance` | `performance` | `templates/<framework>/prompts/PERFORMANCE_AUDIT.md` |
| `deploy-checklist` | `deploy-checklist` | `templates/<framework>/prompts/DEPLOY_CHECKLIST.md` |
| `mysql-performance` | `mysql-performance` | `templates/<framework>/prompts/MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres-performance` | `postgres-performance` | `templates/<framework>/prompts/POSTGRES_PERFORMANCE_AUDIT.md` |
| `design-review` | `design-review` | `templates/<framework>/prompts/DESIGN_REVIEW.md` |

Backward-compat aliases: `code` resolves to `code-review` and `deploy` resolves to `deploy-checklist` at dispatch time. The report filename ALWAYS uses the canonical slug, never the alias.

---

## YAML Frontmatter

Every report opens with a YAML frontmatter block containing exactly these 7 keys:

```yaml
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 3
skipped_allowlist: 1
skipped_fp_recheck: 2
council_pass: pending
---
```

- `audit_type` — one of the 7 canonical slugs from the type map.
- `timestamp` — quoted `YYYY-MM-DD-HHMM` (the same string used in the report filename).
- `commit_sha` — `git rev-parse --short HEAD` output, or the literal string `none` when the project is not a git repo.
- `total_findings` — integer count of entries in the `## Findings` section.
- `skipped_allowlist` — integer count of rows in the `## Skipped (allowlist)` table.
- `skipped_fp_recheck` — integer count of rows in the `## Skipped (FP recheck)` table.
- `council_pass` — starts at `pending`. Phase 15's `/council audit-review` mutates this to `passed`, `failed`, or `disputed` after collating per-finding verdicts.

---

## Section Order (Fixed)

After the YAML frontmatter, the report MUST contain these five H2 sections in this exact order:

1. `## Summary`
2. `## Findings`
3. `## Skipped (allowlist)`
4. `## Skipped (FP recheck)`
5. `## Council verdict`

Plus the report's title H1 (`# <Type Title> Audit — <project name>`) immediately after the closing `---` of the frontmatter and before `## Summary`.

Do NOT reorder. Do NOT introduce intermediate H2 sections. Render an empty section as the literal placeholder `_None_` — the allowlist case uses a longer placeholder shown verbatim in the Skipped (allowlist) section below. Phase 15 navigates by these literal H2 headings.

---

## Summary Section

The Summary table has columns `severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck`, with one row per severity (CRITICAL, HIGH, MEDIUM, LOW). The rubric is in `components/severity-levels.md` — do not redefine. INFO is NOT a reportable finding severity; informational observations belong in the audit's scratchpad, never in `## Findings`. See the Full Report Skeleton below for the verbatim layout.

---

## Finding Entry Schema (### Finding F-NNN)

Each surviving finding becomes an `### Finding F-NNN` H3 block. `F-NNN` is zero-padded to 3 digits and sequential per report (`F-001`, `F-002`, ...). The 9 fields appear in this exact order:

1. **ID** — the `F-NNN` identifier matching the H3 heading.
2. **Severity** — one of CRITICAL, HIGH, MEDIUM, LOW (per `components/severity-levels.md`).
3. **Rule** — the auditor's rule-id (e.g. `SEC-SQL-INJECTION`, `PERF-N+1`).
4. **Location** — `<path>:<start>-<end>` for a range, or `<path>:<line>` for a single point.
5. **Claim** — one-sentence statement of the alleged issue, ≤ 160 chars.
6. **Code** — verbatim ±10 lines around the flagged line, fenced with the language matching the source extension (see Verbatim Code Block section).
7. **Data flow** — markdown bullet list tracing input from origin to the flagged sink, ≤ 6 hops.
8. **Why it is real** — 2-4 sentences citing concrete tokens visible in the Code block. This field is what the Council reasons from in Phase 15.
9. **Suggested fix** — diff-style hunk or replacement snippet showing the corrected pattern.

See the Full Report Skeleton below for the verbatim entry template (a SQL-INJECTION example demonstrating all 9 fields).

The bullet labels (`**Severity:**`, `**Rule:**`, `**Location:**`, `**Claim:**`) and section labels (`**Code:**`, `**Data flow:**`, `**Why it is real:**`, `**Suggested fix:**`) are byte-exact — Phase 15's Council parser navigates the entry by them.

---

## Verbatim Code Block (AUDIT-03)

### Layout

```text
<!-- File: <path> Lines: <start>-<end> -->
[optional clamp note]
[fenced code block here with <lang> from the Extension Map]
```

`<lang>` is the language fence selected per the Extension to Language Fence Map below. `start = max(1, L - 10)` and `end = min(T, L + 10)` where `L` is the flagged line and `T` is the total line count of the file. The HTML range comment is the FIRST line above the fence; the clamp note (when present) is the SECOND line above the fence.

### Clamp Behaviour

When the ±10 range is clipped by the start or end of the file, emit a `<!-- Range clamped to file bounds (start-end) -->` note immediately above the fenced block. Example: flagged line 5 in an 8-line file → `start = max(1, 5-10) = 1`, `end = min(8, 5+10) = 8`, rendered range `1-8`, clamp note required.

### Extension to Language Fence Map

| Extension(s) | Fence |
|--------------|-------|
| `.ts`, `.tsx` | `ts` (or `tsx` for JSX-bearing files) |
| `.js`, `.jsx`, `.mjs`, `.cjs` | `js` |
| `.py` | `python` |
| `.sh`, `.bash`, `.zsh` | `bash` |
| `.rb` | `ruby` |
| `.go` | `go` |
| `.php` | `php` |
| `.md` | `markdown` |
| `.yml`, `.yaml` | `yaml` |
| `.json` | `json` |
| `.toml` | `toml` |
| `.html`, `.htm` | `html` |
| `.css`, `.scss`, `.sass` | `css` |
| `.sql` | `sql` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.kt`, `.kts` | `kotlin` |
| `.swift` | `swift` |
| *unknown* | `text` |

The code block MUST be verbatim — no ellipses, no redaction, no `// ... rest of function` cuts. Council reasons from the actual code, not a paraphrase.

---

## Skipped (allowlist) Section

Columns: `ID | path:line | rule | council_status`. Empty-state placeholder is the literal string `_None — no` followed by a backtick-quoted `audit-exceptions.md` reference and `in this project_`. The verbatim layout is in the Full Report Skeleton below.

`council_status` is parsed from the matching entry's `**Council:**` bullet inside `audit-exceptions.md`. Allowed values: `unreviewed`, `council_confirmed_fp`, `disputed`. Use `sed '/^<!--/,/^-->/d'` (per `commands/audit-restore.md` post-13-05 fix) to strip HTML comment blocks before walking entries — the seed file ships with an HTML-commented example heading that would otherwise produce false matches. The `F-A001`..`F-ANNN` numbering is independent of `F-NNN` for surviving findings.

---

## Skipped (FP recheck) Section

Columns: `path:line | rule | dropped_at_step | one_line_reason`. Empty-state placeholder: `_None_`. The verbatim layout is in the Full Report Skeleton below.

`dropped_at_step` MUST be an integer in 1-6 matching the FP-recheck step where the finding was dropped (see `components/audit-fp-recheck.md`). `one_line_reason` MUST be ≤ 100 chars and reference concrete tokens visible in the source — never `looks fine`, `trusted code`, or `out of scope`.

---

## Council Verdict Slot (handoff to Phase 15)

The audit writes this section as a literal placeholder. Phase 15's `/council audit-review` mutates it in place after collating Gemini + ChatGPT verdicts.

```markdown
## Council verdict

_pending — run /council audit-review_
```

Byte-exact constraints: U+2014 em-dash (literal `—`, not hyphen-minus, not en-dash); single-underscore italic (`_..._`), no asterisks; no backticks, no bold, no code fence, no trailing whitespace. DO NOT REFORMAT — Phase 15 greps for this exact byte sequence to locate the slot before rewriting it.

---

## Full Report Skeleton

<output_format>

```text
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/users.ts:42
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

[fenced code block here — verbatim ±10 lines around src/users.ts:42, ts language fence]

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.
- No parameterized binding between origin and sink.

**Why it is real:**

The literal `db.query("SELECT * FROM users WHERE id=" + req.params.id)` concatenates an Express request parameter directly into the SQL string. The route is public, so an attacker can supply a malicious id and reach the sink unauthenticated.

**Suggested fix:**

[fenced code block here — replacement using parameterized query]

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:5 | SEC-EVAL | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| src/legacy.js:14 | SEC-EVAL | 3 | eval guarded by isBuildTime(); never reached at runtime |

## Council verdict

_pending — run /council audit-review_
```

</output_format>

1. **Quick Check** — go through 5 points
2. **gosec scan** — `gosec ./...`
3. **Scan** — go through all sections
4. **Classify** — Critical → Low
5. **Document** — file, line, code
6. **Fix** — suggest specific fix

Start audit. Quick Check first, then Executive Summary.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
