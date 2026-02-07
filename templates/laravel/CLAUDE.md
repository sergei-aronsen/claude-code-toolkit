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
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Laravel:** Eloquent ORM, Form Requests for validation, Policies for authorization
8. **User-Agent:** NEVER use default library UA, ALWAYS set real browser User-Agent

---

## 🚀 AT THE START OF EACH SESSION

### 0. Verify working directory (CRITICAL for worktrees)

```bash
pwd
git rev-parse --show-toplevel
```

**Lock this directory for the entire session.** Do NOT `cd` to parent folders, sibling worktrees, or the main repository. All file operations must stay within this directory.

### 1. Check memory synchronization

```bash
# Compare MCP vs git file dates
ls -la ~/.claude/memory-bank/[PROJECT_NAME]/*.md
ls -la .claude/memory/*.md
```

- **MCP newer than git** → copy: `cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/`
- **git newer than MCP** (new computer) → import memory into MCP

### 2. Read project memory (Memory Bank)

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
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push. **Before build/deploy: `git fetch origin main && git merge origin/main`** to include changes from other sessions.
- **BEFORE COMMIT** — run `./vendor/bin/pint`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

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
6. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `Http::withHeaders(['User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'])->get($url)`

---

## 🛡️ Production Safety

### Bug Fix Approach

- Try **simplest solution first** — remove unnecessary code before adding new
- **ONE change at a time**, verify immediately
- If 2 attempts fail — **stop, re-analyze root cause** (`/debug`)
- After fix, verify no regressions

### Deployment

- Deploy **incrementally** — one logical change, verify between deploys
- Always fetch/merge latest before deploy
- **NEVER** batch-restart all queue workers — use `php artisan queue:restart` (graceful)
- Verify after every deploy: endpoints, logs, workers

### Queue and Worker Safety

- **NEVER** restart all workers simultaneously — use rolling restarts
- Check active job count before modifying queue config
- Test queue changes on small subset first
- Before changing retry logic — check `php artisan queue:failed` count

### File Targeting

- Before editing, confirm **correct file variant** (V2, legacy, etc.)
- Confirm correct branch/worktree with `pwd` and `git branch`
- Check if already fixed upstream: `git log origin/main --oneline -5`

Full guide: `components/production-safety.md`

---

## Visual Self-Testing (Playwright MCP)

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow: navigate to page, check for console errors, interact with changed elements, take screenshots, report findings. If bug found — fix, redeploy, re-test.

**IMPORTANT: Always call `browser_close` after finishing tests.** Multiple Claude sessions share the same Playwright browser profile. Leaving the browser open will block other sessions from launching it.

Requires Playwright MCP server. Full guide: `components/playwright-self-testing.md`

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
- **All code comments, commit messages, and documentation in English** regardless of conversation language

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
| `/deploy` | Safe deployment with pre/post checks |
| `/fix-prod` | Production hotfix workflow |
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
| `i18n` | When adding multilanguage support, translations, localization |

Load: `Read .claude/skills/{skill-name}/SKILL.md`

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
3. **MCP Memory** — save for future sessions (always in English, regardless of conversation language)

---

## ⚠️ Project-Specific Notes

### Known Gotchas

- [List project-specific issues]

### Public Endpoints (by design)

- `/api/health` — Health check
- `/webhooks/*` — External webhooks
