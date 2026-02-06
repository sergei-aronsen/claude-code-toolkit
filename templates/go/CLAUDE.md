# [Project Name] — Claude Code Instructions

## Project Overview

**Stack:** Go 1.21+ + Gin/Chi + go mod
**Type:** [API/Microservice/Backend/CLI]
**Database:** PostgreSQL / MongoDB / Redis
**Testing:** go test + testify

---

## Compact Instructions

> **When compacting, preserve these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/commands, ALWAYS validate input
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Errors:** ALWAYS check errors, ALWAYS wrap with context

---

## AT THE START OF EACH SESSION

### 0. Verify working directory (CRITICAL for worktrees)

```bash
pwd
git rev-parse --show-toplevel
```

**Lock this directory for the entire session.** Do NOT `cd` to parent folders, sibling worktrees, or the main repository. All file operations must stay within this directory.

### 1. Check Memory Sync

```bash
# Compare MCP vs git file dates
ls -la ~/.claude/memory-bank/[PROJECT_NAME]/*.md
ls -la .claude/memory/*.md
```

- **MCP newer than git** → copy: `cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/`
- **git newer than MCP** (new computer) → import memory into MCP

### 2. Read Project Memory (Memory Bank)

```text
mcp__memory-bank__memory_bank_read (projectName: "[PROJECT_NAME]", fileName: "project-context.md")
```

### 3. Import Knowledge Graph (required every session)

> **Knowledge Graph is in-memory only — data is lost on every restart of Claude Code.**

```text
# Check if graph has data
mcp__memory__read_graph()

# If empty — import from .claude/memory/knowledge-graph.json:
mcp__memory__create_entities(entities: [...entities from JSON...])
mcp__memory__create_relations(relations: [...relations from JSON...])
```

---

## WORKFLOW RULES (MANDATORY!)

### Plan Mode — ALWAYS USE BEFORE CODING

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Research** the task and existing code
3. **Create a plan** in `.claude/scratchpad/current-task.md`
4. **Wait for confirmation** before writing code

**Thinking levels:**

| Word | When to use |
| ------- | ------------------- |
| `think` | Simple tasks |
| `think hard` | Medium complexity |
| `think harder` | Architectural decisions |
| `ultrathink` | Critical decisions, security |

### Structured Workflow (for complex tasks)

| Phase | Access | What to do |
| ---- | ------ | ---------- |
| **RESEARCH** | Read-only | Glob, Grep, Read — understand context |
| **PLAN** | Scratchpad-only | Write plan in `.claude/scratchpad/` |
| **EXECUTE** | Full access | After confirmation — implement |

### Git Workflow

- **Branch naming:** `feature/xxx`, `fix/xxx`, `refactor/xxx`
- **Commits:** Conventional Commits (`feat:`, `fix:`, `refactor:`)
- **NEVER** push directly to `main`
- **CHANGELOG** — update on `feat:`, `fix:`, breaking changes
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push. **Before build/deploy: `git fetch origin main && git merge origin/main`** to include changes from other sessions.
- **BEFORE COMMIT** — run `golangci-lint run`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

---

## Project Structure (Go)

```text
cmd/
├── api/                 # Main application entry point
│   └── main.go
└── worker/              # Background worker entry point
    └── main.go

internal/                # Private application code
├── config/              # Configuration
│   └── config.go
├── handler/             # HTTP handlers (controllers)
│   ├── user_handler.go
│   └── health_handler.go
├── service/             # Business logic
│   └── user_service.go
├── repository/          # Data access layer
│   └── user_repository.go
├── model/               # Domain models
│   └── user.go
├── dto/                 # Data Transfer Objects
│   └── user_dto.go
├── middleware/          # HTTP middleware
│   ├── auth.go
│   └── logging.go
└── pkg/                 # Internal shared packages
    ├── validator/
    └── errors/

pkg/                     # Public packages (if library)
```

---

## Essential Commands

```bash
# Development
go run cmd/api/main.go              # Run application
air                                  # Hot reload (with air)

# Testing
go test ./...                        # Run all tests
go test ./... -v                     # Verbose
go test ./... -cover                 # With coverage
go test -race ./...                  # Race detection

# Code Quality
golangci-lint run                    # Lint (100+ linters)
golangci-lint run --fix              # Auto-fix
go fmt ./...                         # Format
go vet ./...                         # Static analysis

# Build
go build -o bin/api cmd/api/main.go # Build binary
go mod tidy                          # Cleanup dependencies
go mod download                      # Download dependencies
```

---

## Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS validate with go-playground/validator
2. **SQL Injection** — ONLY prepared statements, NEVER string concatenation
3. **Command Injection** — NEVER use exec with user input
4. **Authorization** — ALWAYS check permissions in middleware
5. **Secrets** — ONLY through env variables (viper/envconfig)
6. **Context** — ALWAYS propagate context for cancellation
7. **TLS** — ALWAYS TLS 1.3 in production

---

## Production Safety

### Bug Fix Approach

- Try **simplest solution first** — remove unnecessary code before adding new
- **ONE change at a time**, verify immediately
- If 2 attempts fail — **stop, re-analyze root cause** (`/debug`)
- After fix, verify no regressions

### Deployment

- Deploy **incrementally** — one logical change, verify between deploys
- Always fetch/merge latest before deploy
- **NEVER** batch-restart all service instances — use rolling restarts
- Verify after every deploy: endpoints, logs, services

### File Targeting

- Before editing, confirm **correct file variant** (V2, legacy, etc.)
- Confirm correct branch/worktree with `pwd` and `git branch`
- Check if already fixed upstream: `git log origin/main --oneline -5`

Full guide: `components/production-safety.md`

---

## Architecture Guidelines (STRICT!)

1. **KISS Principle:** Simplest working solution. No premature optimization.
2. **YAGNI:** No features/abstractions "for the future".
3. **No Boilerplate:** No excessive abstraction layers unless explicitly requested.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## Coding Style (Go)

- Accept interfaces, return structs
- Error handling: wrap with context using fmt.Errorf + %w
- Context propagation everywhere
- Table-driven tests
- No init() functions (explicit initialization)

---

## Code Style

### Naming Conventions (Go)

- **Files:** `snake_case.go`
- **Packages:** `lowercase` (one word)
- **Exported:** `PascalCase`
- **Unexported:** `camelCase`
- **Interfaces:** `PascalCase` + er suffix (Reader, Writer)
- **Acronyms:** Consistent case (URL, HTTP, ID)

### Best Practices

- Maximum 200 lines per file
- One responsibility per package
- Effective Go guidelines
- Comments for exported functions
- **All code comments, commit messages, and documentation in English** regardless of conversation language

---

## Go Patterns

### Error Handling

```go
// Custom error with context
type AppError struct {
    Code    string
    Message string
    Err     error
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %v", e.Message, e.Err)
    }
    return e.Message
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// Usage
func GetUser(ctx context.Context, id string) (*User, error) {
    user, err := repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user %s: %w", id, err)
    }
    if user == nil {
        return nil, &AppError{Code: "USER_NOT_FOUND", Message: "user not found"}
    }
    return user, nil
}
```

### Validation with go-playground/validator

```go
import "github.com/go-playground/validator/v10"

type CreateUserRequest struct {
    Email string `json:"email" validate:"required,email"`
    Name  string `json:"name" validate:"required,min=2,max=100"`
    Age   *int   `json:"age" validate:"omitempty,gte=0,lte=150"`
}

var validate = validator.New()

func (r *CreateUserRequest) Validate() error {
    return validate.Struct(r)
}
```

### Gin Handler

```go
func (h *UserHandler) Create(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    if err := req.Validate(); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    user, err := h.service.Create(c.Request.Context(), &req)
    if err != nil {
        // Handle different error types
        var appErr *AppError
        if errors.As(err, &appErr) {
            c.JSON(http.StatusBadRequest, gin.H{"error": appErr.Message, "code": appErr.Code})
            return
        }
        c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
        return
    }

    c.JSON(http.StatusCreated, user)
}
```

### Table-Driven Tests

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive numbers", 1, 2, 3},
        {"negative numbers", -1, -2, -3},
        {"zero", 0, 0, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

---

## Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (go test) |
| `/agent:planner` | Planner | Task planning |
| `/agent:go-expert` | Go Expert | Gin/Chi patterns, concurrency |

---

## Quick Commands

| Command | Description |
| --------- | -------- |
| `/verify` | Quick check: build, lint, tests |
| `/debug` | Systematic debugging (4 phases, root cause first) |
| `/learn` | Save problem solution to `.claude/learned/` |
| `/deploy` | Safe deployment with pre/post checks |
| `/fix-prod` | Production hotfix workflow |
| `/audit [type]` | Deep analysis (security, performance, code) |

---

## Available Audits

| Trigger | Action |
| --------- | -------- |
| `security audit` | Run `SECURITY_AUDIT.md` |
| `performance audit` | Run `PERFORMANCE_AUDIT.md` |
| `code review` | Run `CODE_REVIEW.md` |
| `postgres audit` | Run `POSTGRES_PERFORMANCE_AUDIT.md` |
| `deploy checklist` | Run `DEPLOY_CHECKLIST.md` |

---

## Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |
| `go` | Goroutines, error handling, table-driven tests |
| `i18n` | When adding multilanguage support, translations, localization |

Load: `Read .claude/skills/{skill-name}/SKILL.md`

---

## Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## Knowledge Persistence (SAVE KNOWLEDGE!)

On **significant changes** — save knowledge to THREE places:

1. **CLAUDE.md** — update this file
2. **Documentation** — update /docs or README
3. **MCP Memory** — save for future sessions (always in English, regardless of conversation language)

---

## Project-Specific Notes

### Known Gotchas

- [List project-specific issues]

### Public Endpoints (by design)

- `/health` — Health check
- `/metrics` — Prometheus metrics
- `/api/webhooks/*` — External webhooks
