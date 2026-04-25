# Code Review — Go Template

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add
     an entry, /audit-restore to remove one. -->

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

## 8. SELF-CHECK (FP Recheck — 6-Step Procedure)
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

## 9. OUTPUT FORMAT (Structured Report Schema — Phase 14)
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

1. **Run Quick Check** — execute `go build`, `go vet`, `golangci-lint`, `go test -race`
2. **Define scope** — which files and packages to review
3. **Go through categories** — Architecture, Code Quality, Error Handling, Concurrency, Security, Performance
4. **Self-check** — filter out false positives against Go idioms
5. **Prioritize** — Critical (data races, security) then High then Medium
6. **Show fixes** — specific code before/after with file paths and line numbers

Start code review. Show scope and summary first.

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
