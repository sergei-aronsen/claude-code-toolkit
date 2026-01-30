# Code Review — Go Template

## Goal

Comprehensive code review of a Go application. Act as a Senior Tech Lead.

> **Recommended model:** Use **Claude Opus 4.5** (`claude-opus-4-5-20251101`) for code review — works better with code analysis.

---

## 0. QUICK CHECK (5 minutes)

| # | Check | Command | Expected |
| --- | ------- | --------- | ---------- |
| 1 | Build | `go build ./...` | No errors |
| 2 | Vet | `go vet ./...` | No warnings |
| 3 | Lint | `golangci-lint run` | No issues |
| 4 | Tests (race) | `go test -race ./...` | All pass, no races |
| 5 | Vulnerabilities | `govulncheck ./...` | No known vulns |

---

## 0.1 AUTO-CHECK SCRIPT

```bash
#!/bin/bash
# go-code-check.sh

echo "Go Code Quality Check..."

# 1. Build
go build ./... > /dev/null 2>&1 && echo "[OK] Build" || echo "[FAIL] Build errors"

# 2. Vet
go vet ./... 2>&1 | grep -q "." && echo "[WARN] go vet issues" || echo "[OK] go vet"

# 3. Lint
if command -v golangci-lint &> /dev/null; then
  golangci-lint run --timeout 5m > /dev/null 2>&1 && echo "[OK] Lint" || echo "[WARN] Lint issues"
else
  echo "[SKIP] golangci-lint not installed"
fi

# 4. Tests with race detection
go test -race -count=1 ./... > /dev/null 2>&1 && echo "[OK] Tests (race)" || echo "[FAIL] Tests or race"

# 5. Vulnerability check
if command -v govulncheck &> /dev/null; then
  govulncheck ./... 2>&1 | grep -q "No vulnerabilities" && echo "[OK] No vulns" || echo "[WARN] Vulns"
else
  echo "[SKIP] govulncheck not installed"
fi

# 6. God files (>400 lines, excluding tests)
GOD=$(find . -name "*.go" ! -name "*_test.go" ! -path "./vendor/*" -exec wc -l {} \; | awk '$1>400' | wc -l | tr -d ' ')
[ "$GOD" -eq 0 ] && echo "[OK] No god files" || echo "[WARN] $GOD files >400 lines"

# 7. TODO/FIXME
TODOS=$(grep -rn "TODO\|FIXME\|HACK" --include="*.go" . 2>/dev/null | grep -v vendor | wc -l | tr -d ' ')
echo "[INFO] TODO/FIXME/HACK: $TODOS"

# 8. Debug prints left in code
DEBUGS=$(grep -rn "fmt\.Print\|log\.Print" --include="*.go" . 2>/dev/null | grep -v vendor | grep -v _test.go | wc -l | tr -d ' ')
[ "$DEBUGS" -lt 5 ] && echo "[OK] Debug prints: $DEBUGS" || echo "[WARN] Debug prints: $DEBUGS"

# 9. go mod tidy check
cp go.sum go.sum.bak 2>/dev/null
go mod tidy > /dev/null 2>&1
diff go.sum go.sum.bak > /dev/null 2>&1 && echo "[OK] go.mod tidy" || echo "[WARN] go.mod needs tidy"
mv go.sum.bak go.sum 2>/dev/null

echo "Done!"
```

---

## 0.2 PROJECT SPECIFICS — [Project Name]

**Accepted decisions (no need to fix):**

- [Conscious architectural decisions]

**Key files for review:**

- `cmd/` — application entry points
- `internal/handler/` — HTTP handlers (should be thin)
- `internal/service/` — business logic
- `internal/repository/` — data access layer

**Project patterns:**

- Handlers for HTTP routing
- Services for business logic
- Repository pattern for data access
- Middleware for cross-cutting concerns

---

## 0.3 SEVERITY LEVELS

| Level | Description | Action |
| ------- | ---------- | ---------- |
| CRITICAL | Bug, security issue, data loss, data race | **BLOCKER** — fix now |
| HIGH | Serious logic problem, goroutine leak | Fix before merge |
| MEDIUM | Code smell, maintainability | Fix in this PR |
| LOW | Style, nice-to-have | Can be deferred |

---

## 1. SCOPE REVIEW

### 1.1 Define review scope

```bash
# Recent changes
git diff --name-only HEAD~5

# Uncommitted changes
git status --short

# Changed Go files only
git diff --name-only HEAD~5 -- '*.go'
```

- [ ] Which files changed
- [ ] Which new files created
- [ ] Relationship between changes

### 1.2 Categorization

- [ ] Handlers (internal/handler/*)
- [ ] Services (internal/service/*)
- [ ] Repository (internal/repository/*)
- [ ] Models (internal/model/*)
- [ ] Middleware (internal/middleware/*)
- [ ] Config (internal/config/*)
- [ ] Entry points (cmd/*)
- [ ] Migrations (migrations/*)

---

## 2. ARCHITECTURE & STRUCTURE

### 2.1 Single Responsibility

```go
// BAD -- handler does everything
func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    json.NewDecoder(r.Body).Decode(&req)
    if req.Email == "" { http.Error(w, "email required", 400); return }
    hash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    h.db.ExecContext(r.Context(), "INSERT INTO users ...", req.Email, string(hash))
    w.WriteHeader(http.StatusCreated)
}

// GOOD -- handler only coordinates
func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req dto.CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid body"); return
    }
    user, err := h.userService.Create(r.Context(), req)
    if err != nil { handleServiceError(w, err); return }
    respondJSON(w, http.StatusCreated, user)
}
```

- [ ] Handlers < 100 lines, handler methods < 30 lines
- [ ] Business logic in services, not in handlers
- [ ] Data access in repositories, not in services
- [ ] Each package has a clear, single responsibility
- [ ] Interfaces are small and focused (interface segregation)

### 2.2 Dependency Injection

```go
// BAD -- hardcoded dependencies
func (s *UserService) Create(ctx context.Context, req CreateUserRequest) (*User, error) {
    db, _ := sql.Open("postgres", os.Getenv("DATABASE_URL"))
}

// GOOD -- accept interfaces, return structs
type UserRepository interface {
    Create(ctx context.Context, user *model.User) error
}

type UserService struct {
    repo   UserRepository
    logger *slog.Logger
}

func NewUserService(repo UserRepository, logger *slog.Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}
```

- [ ] Accept interfaces, return structs
- [ ] Dependencies injected via constructor (`NewXxx`)
- [ ] No global state or package-level mutable variables
- [ ] No `init()` functions for dependency setup
- [ ] Interfaces defined by consumer, not provider

### 2.3 Proper Placement

```text
project/
├── cmd/                  # Entry points (main packages)
├── internal/             # Private application code
│   ├── config/           # Configuration loading
│   ├── handler/          # HTTP handlers (thin)
│   ├── service/          # Business logic
│   ├── repository/       # Data access
│   ├── model/            # Domain models
│   ├── dto/              # Request/response DTOs
│   └── middleware/        # HTTP middleware
├── pkg/                  # Public reusable packages
└── migrations/           # Database migrations
```

- [ ] Files in correct directories
- [ ] No God-files (> 400 lines for non-test files)
- [ ] `internal/` used for private application code
- [ ] `cmd/` contains only main packages with minimal logic
- [ ] Test files co-located with source (`*_test.go`)

### 2.4 Go-Specific Patterns

```go
// BAD -- no context, fire-and-forget goroutine
func ProcessOrder(orderID string) error {
    order := fetchOrder(orderID)
    go sendNotification(order)
    return nil
}

// GOOD -- context propagation, managed goroutines, error wrapping
func (s *OrderService) ProcessOrder(ctx context.Context, orderID string) error {
    order, err := s.repo.FindByID(ctx, orderID)
    if err != nil { return fmt.Errorf("fetch order %s: %w", orderID, err) }
    g, ctx := errgroup.WithContext(ctx)
    g.Go(func() error { return s.notifier.Send(ctx, order) })
    return g.Wait()
}
```

- [ ] Context passed as first parameter to all functions
- [ ] Goroutines managed (errgroup, WaitGroup)
- [ ] Errors always wrapped with context using `%w`
- [ ] Graceful shutdown implemented for servers

---

## 3. CODE QUALITY

### 3.1 Naming

```go
// BAD
var svc_user *UserService       // underscores
func proc(d []byte) error {}    // abbreviation
type IUserService interface {}  // C#-style prefix

// GOOD
var userService *UserService
func ProcessPayload(data []byte) error {}
type Reader interface { Read(p []byte) (n int, err error) }
```

- [ ] **Packages** — lowercase, single word: `user`, `auth`, `config`
- [ ] **Exported** — PascalCase: `UserService`, `ErrNotFound`
- [ ] **Unexported** — camelCase: `userRepo`, `validateInput`
- [ ] **No underscores** in Go names (except test functions)
- [ ] **Acronyms** — consistent case: `ID`, `URL`, `HTTP`
- [ ] **Interfaces** — describe behavior: `Reader`, `UserRepository`
- [ ] **Getters** — no `Get` prefix: `user.Name()` not `user.GetName()`
- [ ] **Error variables** — `Err` prefix: `ErrNotFound`, `ErrTimeout`

### 3.2 Complexity

```go
// BAD -- deep nesting (4 levels)
for _, item := range items {
    if item.Type == "order" {
        if item.Status == "active" {
            if item.Amount > 0 { /* ... */ }
        }
    }
}

// GOOD -- early returns, guard clauses, extracted function
for _, item := range items {
    if err := processItem(item); err != nil {
        return fmt.Errorf("process item %s: %w", item.ID, err)
    }
}
func processItem(item Item) error {
    if !item.IsProcessable() { return nil }
    if item.Amount <= 0 { return fmt.Errorf("invalid amount: %d", item.Amount) }
    return nil
}
```

- [ ] Functions < 40 lines (ideally < 20)
- [ ] Nesting < 3 levels
- [ ] Early returns and guard clauses used
- [ ] Switch over long if-else chains

### 3.3 DRY

```go
// BAD -- duplicated query + scan logic for each status
func GetActiveUsers(ctx context.Context, db *sql.DB) ([]User, error) { /* ... */ }
func GetPendingUsers(ctx context.Context, db *sql.DB) ([]User, error) { /* ... */ }

// GOOD -- parameterized with shared scan
func (r *UserRepo) FindByStatus(ctx context.Context, status string) ([]User, error) {
    rows, err := r.db.QueryContext(ctx, "SELECT id, name FROM users WHERE status = $1", status)
    if err != nil { return nil, fmt.Errorf("query users: %w", err) }
    defer rows.Close()
    return scanUsers(rows)
}
```

- [ ] No copy-paste code
- [ ] Common logic extracted into shared functions

### 3.4 Type Safety

```go
// BAD -- unchecked assertion (panics)
m := data.(map[string]interface{})

// GOOD -- safe assertion with named types
type OrderStatus string
const ( OrderStatusPending OrderStatus = "pending" )

orderEvent, ok := event.(*OrderEvent)
if !ok { return fmt.Errorf("unexpected event type: %T", event) }
```

- [ ] Concrete types over `interface{}` / `any` where possible
- [ ] Type assertions use two-value form (`val, ok := x.(Type)`)
- [ ] Constants with named types for enumerations
- [ ] Compile-time interface compliance (`var _ Interface = (*Struct)(nil)`)

### 3.5 Go Idioms

```go
// BAD
if err == nil { return user, nil } else { return nil, err }
func init() { globalDB, _ = sql.Open("postgres", os.Getenv("DB_URL")) }

// GOOD
if err != nil { return nil, fmt.Errorf("find user %s: %w", id, err) }
return user, nil

func NewApp(cfg Config) (*App, error) {
    db, err := sql.Open("postgres", cfg.DatabaseURL)
    if err != nil { return nil, fmt.Errorf("open database: %w", err) }
    return &App{db: db}, nil
}
```

- [ ] Error check: `if err != nil { return ..., err }`
- [ ] No `else` after `return` — use early returns
- [ ] `defer` for cleanup (file close, mutex unlock, rows close)
- [ ] Zero values are meaningful (no unnecessary initialization)
- [ ] No `init()` — prefer explicit initialization
- [ ] `errors.New()` for simple, `fmt.Errorf()` for formatted errors
- [ ] `range` over slices/maps, not index-based loops

---

## 4. ERROR HANDLING

### 4.1 Error Wrapping

```go
// BAD -- no context, swallowed error
if err != nil { return err }                          // bare return
if err != nil { log.Println(err); return nil }        // swallowed

// GOOD -- wrapped with context
if err := s.repo.Save(ctx, order); err != nil {
    return fmt.Errorf("save order: %w", err)
}
```

- [ ] All errors wrapped with `fmt.Errorf("context: %w", err)`
- [ ] Wrap context describes the current operation
- [ ] No bare `return err` without context
- [ ] No silently swallowed errors

### 4.2 Custom Error Types and Sentinel Errors

```go
// Sentinel errors
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)

// Custom error type
type ValidationError struct { Field, Message string }
func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s — %s", e.Field, e.Message)
}

// Usage with errors.Is / errors.As
if errors.Is(err, ErrNotFound) {
    respondError(w, http.StatusNotFound, "not found")
}
var validErr *ValidationError
if errors.As(err, &validErr) {
    respondError(w, http.StatusBadRequest, validErr.Error())
}
```

- [ ] Sentinel errors for expected conditions (`ErrNotFound`, `ErrTimeout`)
- [ ] Custom error types implement `Error()` and `Unwrap()`
- [ ] `errors.Is()` for sentinel checks, not `==`
- [ ] `errors.As()` for type assertions on errors
- [ ] Never expose internal errors to API clients
- [ ] No empty `if err != nil {}` blocks
- [ ] No `panic()` in library code

---

## 5. CONCURRENCY

### 5.1 Goroutine Safety

```go
// BAD -- data race
type Counter struct { count int }
func (c *Counter) Increment() { c.count++ }

// GOOD -- mutex or atomic
type Counter struct { mu sync.Mutex; count int }
func (c *Counter) Increment() { c.mu.Lock(); defer c.mu.Unlock(); c.count++ }

// BAD -- closure captures loop variable (pre Go 1.22)
for _, item := range items { go func() { process(item) }() }
// GOOD
for _, item := range items { go func(it Item) { process(it) }(item) }
```

- [ ] No shared mutable state without synchronization
- [ ] `sync.Mutex` / `sync.RWMutex` for shared state
- [ ] `sync/atomic` for simple counters and flags
- [ ] `sync.Once` for one-time initialization
- [ ] No data races (`go test -race` passes)

### 5.2 Context Propagation

```go
// BAD -- no context, no timeout
resp, err := http.Get(url)

// GOOD -- context-aware request
req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
resp, err := s.client.Do(req)
defer resp.Body.Close()
```

- [ ] `context.Context` is the first parameter of every I/O function
- [ ] Context passed through the entire call chain
- [ ] `context.WithTimeout` for bounded operations
- [ ] Database queries use `QueryContext` / `ExecContext`
- [ ] Never store context in a struct field
- [ ] Check `ctx.Err()` in long-running loops

### 5.3 Resource Leaks

```go
// BAD -- goroutine leak (blocks forever)
ch := make(chan Event)
go func() { for { ch <- waitForEvent() } }()

// GOOD -- managed goroutine with context exit
ch := make(chan Event)
go func() {
    defer close(ch)
    for {
        select {
        case <-ctx.Done(): return
        default:
            event, err := waitForEvent(ctx)
            if err != nil { return }
            select { case ch <- event: case <-ctx.Done(): return }
        }
    }
}()
```

- [ ] All goroutines have an exit condition (context, done channel)
- [ ] Channels closed by sender when done
- [ ] `defer` immediately after resource acquisition
- [ ] `http.Response.Body` and `sql.Rows` always closed
- [ ] `errgroup` or `sync.WaitGroup` for goroutine completion

---

## 6. DOCUMENTATION

### 6.1 Go Doc Comments

```go
// BAD
func Process(data []byte) error {}
// GetUser gets a user
func GetUser(id string) *User {}

// GOOD
// Process validates and transforms the raw event payload into domain events.
// It returns an error if the payload is malformed or exceeds 10MB.
func Process(data []byte) error {}
```

- [ ] All exported functions/types have doc comments starting with their name
- [ ] Package-level `doc.go` for packages with significant public API
- [ ] Comments explain "why", not "what"
- [ ] No commented-out code

### 6.2 Package Comments

```go
// Package user provides user management functionality including
// creation, authentication, and profile operations.
package user
```

- [ ] Every package has a package comment
- [ ] Package comment describes purpose and main types

---

## 7. SECURITY & PERFORMANCE

### 7.1 Security

```go
// BAD -- SQL injection, command injection, path traversal
query := fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", name)
cmd := exec.Command("sh", "-c", "echo " + userInput)
os.Open(filepath.Join("/uploads", userInput))

// GOOD
db.QueryContext(ctx, "SELECT * FROM users WHERE name = $1", name)
cmd := exec.CommandContext(ctx, "echo", userInput)
cleanPath := filepath.Clean(userInput)
if strings.Contains(cleanPath, "..") { return fmt.Errorf("invalid path") }
```

- [ ] No SQL injection — always parameterized queries (`$1`, `?`)
- [ ] No command injection — no user input to `os/exec` via shell
- [ ] No path traversal — validate paths, use `filepath.Clean`
- [ ] Authorization checked in middleware or handler
- [ ] No secrets hardcoded (use env vars or secret managers)
- [ ] Input size limits (`http.MaxBytesReader`)

### 7.2 Performance

```go
// BAD -- string concat in loop, no preallocation
result := ""
for _, u := range users { result += u.Name + ", " }

// GOOD -- strings.Builder, preallocated slice
var b strings.Builder
for i, u := range users { if i > 0 { b.WriteString(", ") }; b.WriteString(u.Name) }
results := make([]Result, 0, len(items))
```

- [ ] `strings.Builder` for string concatenation in loops
- [ ] Slice preallocation with `make([]T, 0, capacity)` when size known
- [ ] `sync.Pool` for frequently allocated/freed objects
- [ ] Database queries indexed (check with EXPLAIN)
- [ ] N+1 query patterns avoided (batch loading)
- [ ] Connection pools sized (`sql.DB.SetMaxOpenConns`)
- [ ] HTTP client with timeouts (`&http.Client{Timeout: 10 * time.Second}`)

---

## 8. SELF-CHECK

**Before adding an issue to the report:**

| Question | If "no" then do not include |
| -------- | ------------------------- |
| Does it affect **functionality** or **maintainability**? | Cosmetics are not critical |
| Will **fixing benefit** developers/users? | Refactoring for the sake of refactoring is a waste |
| Is it a **violation** of project conventions? | Check existing patterns |
| Is the **time worth** fixing? | 5 min fix vs 1 hour review |

**DO NOT include in report:**

| Seems like a problem | Why it may not be |
| ------------------- | --------------------- |
| "No comments" | Code may be self-documenting |
| "Long file" | If logically related and cohesive — OK |
| "Could use generics" | Not every function needs generics |
| "Should use channels" | Mutex may be simpler and correct |
| "Error message style" | If consistent within the project — OK |
| "No doc.go" | Small internal packages may not need it |
| "init() used" | May be intentional (driver registration) |

**Checklist:**

```text
[ ] This is a REAL problem, not personal preference
[ ] There is a SPECIFIC suggestion for a fix
[ ] The fix WILL NOT BREAK functionality
[ ] This is NOT an intentional design decision
[ ] I checked with go vet / golangci-lint before flagging style issues
```

---

## 9. REPORT FORMAT

```markdown
# Code Review Report — [Project Name]
Date: [date]
Scope: [which files/commits reviewed]

## Summary

| Category | Issues | Critical |
|-----------|---------|-----------|
| Architecture | X | X |
| Code Quality | X | X |
| Error Handling | X | X |
| Concurrency | X | X |
| Security | X | X |
| Performance | X | X |

## CRITICAL Issues

| # | File | Line | Issue | Solution |
|---|------|--------|----------|---------|
| 1 | handler/user.go | 45 | Data race on shared map | Use sync.RWMutex or sync.Map |

## Code Suggestions

### 1. user_handler.go — extract business logic

```go
// Before (internal/handler/user_handler.go:45-120)
func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
    // 75 lines of mixed concerns...
}

// After
func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req dto.CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid body"); return
    }
    user, err := h.userService.Create(r.Context(), req)
    if err != nil { handleServiceError(w, err); return }
    respondJSON(w, http.StatusCreated, user)
}
```text

### 2. order_service.go — add error wrapping

```go
// Before
if err != nil { return err }

// After
if err != nil { return fmt.Errorf("create order for user %s: %w", userID, err) }
```text

## Good Practices Found

- [What is done well in the codebase]

```text

---

## 10. ACTIONS

1. **Run Quick Check** — execute `go build`, `go vet`, `golangci-lint`, `go test -race`
2. **Define scope** — which files and packages to review
3. **Go through categories** — Architecture, Code Quality, Error Handling, Concurrency, Security, Performance
4. **Self-check** — filter out false positives against Go idioms
5. **Prioritize** — Critical (data races, security) then High then Medium
6. **Show fixes** — specific code before/after with file paths and line numbers

Start code review. Show scope and summary first.
