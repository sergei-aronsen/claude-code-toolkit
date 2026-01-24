# [Project Name] — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Laravel + [Vue/Inertia/Livewire] + [MySQL/PostgreSQL]
**Type:** [SaaS/API/Dashboard/etc.]
**Description:** [Brief description]

---

## 📌 Compact Instructions

> **When compacting, keep these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/HTML, ALWAYS validate input
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before coding, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly
5. **Laravel:** Eloquent ORM, Form Requests for validation, Policies for authorization

---

## 🚀 AT THE START OF EACH SESSION

### 1. Check memory synchronization

```bash
# Compare MCP vs git file dates
ls -la ~/.claude/memory-bank/[PROJECT_NAME]/*.md
ls -la .claude/memory/*.md
```

- **MCP newer than git** → copy: `cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/`
- **git newer than MCP** (new computer) → import memory into MCP

### 2. Read project memory

```text
mcp__memory-bank__memory_bank_read (projectName: "[PROJECT_NAME]", fileName: "project-context.md")
mcp__memory__read_graph()
```

---

## 🧠 WORKFLOW RULES (MANDATORY!)

### Plan Mode — ALWAYS USE BEFORE CODING

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Research** the task and existing code
3. **Create a plan** in `.claude/scratchpad/current-task.md`
4. **Wait for confirmation** before writing code

**Thinking levels:**

| Keyword | When to use |
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

---

## 📁 Project Structure (Laravel)

```text
app/
├── Http/
│   ├── Controllers/     # Thin controllers
│   ├── Requests/        # Form Request validation
│   └── Middleware/
├── Models/              # Eloquent models
├── Services/            # Business logic
├── Policies/            # Authorization
└── Actions/             # Single-action classes
resources/
├── views/               # Blade templates
└── js/                  # Vue/Inertia components
```

---

## ⚡ Essential Commands

```bash
# Development
php artisan serve              # Start dev server
npm run dev                    # Vite dev server

# Testing
php artisan test               # Run tests
php artisan test --filter=     # Run specific test

# Code Quality
./vendor/bin/pint              # Laravel Pint (formatting)
./vendor/bin/phpstan analyse   # Static analysis

# Database
php artisan migrate            # Run migrations
php artisan migrate:fresh --seed  # Fresh DB with seeds
```

---

## 🔒 Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS use Form Requests
2. **SQL Injection** — ONLY Eloquent ORM, NEVER raw queries with user input
3. **XSS** — Blade automatically escapes `{{ }}`, DO NOT use `{!! !!}` for user data
4. **Authorization** — ALWAYS use Policies, check in controllers
5. **Secrets** — ONLY through `.env`, NEVER hardcode

---

## 🏗️ Architecture Guidelines (STRICT!)

1. **KISS Principle:** Simplest working solution. No premature optimization.
2. **YAGNI:** No features/abstractions "for the future".
3. **No Boilerplate:** No Repositories/Interfaces unless explicitly requested.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## 💻 Coding Style (Laravel)

- Use Eloquent over raw queries
- Form Requests for validation (not inline)
- Policies for authorization
- Actions for complex business logic
- PSR-12 code style (Laravel Pint)

---

## 🎨 Code Style

### Naming Conventions (Laravel)

- **Controllers:** `UserController` (singular)
- **Models:** `User` (singular)
- **Migrations:** `create_users_table` (plural)
- **Variables:** `$camelCase`
- **Methods:** `camelCase()`

### Best Practices

- Maximum 200 lines per file
- Single responsibility per class
- Type hints everywhere
- Comments for complex logic

---

## 🤖 Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (Pest) |
| `/agent:planner` | Planner | Task planning |

---

## ⚡ Quick Commands

| Command | Description |
| --------- | -------- |
| `/verify` | Quick check: build, types, lint, tests |
| `/debug` | Systematic debugging (4 phases, root cause first) |
| `/learn` | Save problem solution to `.claude/learned/` |
| `/audit [type]` | Deep analysis (security, performance, code) |

---

## 📋 Available Audits

| Trigger | Action |
| --------- | -------- |
| `security audit` | Run `SECURITY_AUDIT.md` |
| `performance audit` | Run `PERFORMANCE_AUDIT.md` |
| `code review` | Run `CODE_REVIEW.md` |
| `design review` | Run `DESIGN_REVIEW.md` (Playwright MCP) |
| `mysql audit` | Run `MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres audit` | Run `POSTGRES_PERFORMANCE_AUDIT.md` |
| `deploy checklist` | Run `DEPLOY_CHECKLIST.md` |

---

## 🎓 Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |

Load: `Read .claude/skills/ai-models/SKILL.md`

---

## 📝 Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## 🧠 Knowledge Persistence (SAVE KNOWLEDGE!)

On **significant changes** — save knowledge in THREE places:

1. **CLAUDE.md** — update this file
2. **Documentation** — update /docs or README
3. **MCP Memory** — save for future sessions

---

## ⚠️ Project-Specific Notes

### Known Gotchas

- [List project-specific issues]

### Public Endpoints (by design)

- `/api/health` — Health check
- `/webhooks/*` — External webhooks
