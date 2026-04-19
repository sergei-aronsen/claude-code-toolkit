# [Project Name] — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Laravel + [Vue/Inertia/Livewire] + [MySQL/PostgreSQL]
**Type:** [SaaS/API/Dashboard/etc.]
**Description:** [Brief description]

## Required Base Plugins

This toolkit is designed to **complement** two Claude Code plugins. Install them first for
the full experience; TK will auto-detect them and skip duplicate files.

| Plugin | Purpose | Install |
|--------|---------|---------|
| `superpowers` (obra) | Skills (debugging, plans, TDD, verification, worktrees), `code-reviewer` agent | `claude plugin install superpowers@claude-plugins-official` |
| `get-shit-done` (gsd-build) | Phase-based workflow: `/gsd-plan-phase`, `/gsd-execute-phase`, and more | `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)` |

> **Without these plugins** TK still installs in `standalone` mode — you get every TK file,
> but you'll miss SP's systematic debugging and GSD's phase workflow. See
> [optional-plugins.md](https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/components/optional-plugins.md)
> for the full rationale (components are repo-root assets — they are NOT installed into
> `.claude/`, so use the absolute GitHub blob URL).

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

## AT THE START OF EACH SESSION

1. **Verify directory:** `pwd` + `git rev-parse --show-toplevel` — lock this directory for the session
2. **Context is auto-loaded** from `.claude/rules/` — no manual reads needed
3. **For on-demand details:** read `.claude/docs/` files as needed

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

## Visual Self-Testing

After UI changes, test with Playwright MCP: navigate, check errors, interact, screenshot. Always call `browser_close` after. Guide: `components/playwright-self-testing.md`

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

## 🎓 Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |
| `i18n` | When adding multilanguage support, translations, localization |

Load: `Read .claude/skills/{skill-name}/SKILL.md`

---

## Scratchpad

Complex tasks: `.claude/scratchpad/current-task.md` for plans, `findings.md` for research, `decisions.md` for decisions.

---

## Knowledge Persistence

On significant changes, update: (1) `.claude/rules/` for project facts, (2) `.claude/CLAUDE.md` if workflow changed, (3) docs/README for humans.

---

## Supreme Council (Optional)

For high-stakes changes, use multi-AI review:
`/council "feature description"` or `brain "feature description"`

**When to use:** New features, security, refactoring, payments, breaking API changes.
**Output:** `.claude/scratchpad/council-report.md` (APPROVED / REJECTED)

Full guide: `components/supreme-council.md`

---

## Skill Accumulation (Self-Learning)

**You can learn from corrections and accumulate project knowledge.**

### When to CREATE a new skill

Suggest creating a skill when:

- User corrected you 2+ times on the same topic
- Discovered project-specific convention
- User said "remember this" or "always do it this way"

**Format:**

```text
Noticed a pattern: [description]
Save as skill '[name]'?
Will activate on: [triggers]
```

### When to UPDATE an existing skill

Suggest updating when you used a skill but user corrected:

```text
New information for skill '[name]':
Current: [what's in skill]
New: [what was learned]

Update?
[A] Add rule [B] Replace [C] Exception [D] No
```

### Lessons from Debugging

Use `/learn` to save debugging insights as scoped rule files in `.claude/rules/` (e.g., `rules/database.md` with `globs: ["models/**"]`). Rules auto-load only when working with matching files — no manual reads needed.

### When NOT to suggest

- One-time correction
- Obvious things
- User already declined

### Skills files

```text
.claude/skills/
├── skill-rules.json      # Activation rules
└── [skill-name]/
    └── SKILL.md          # Accumulated knowledge
```

---

## Project-Specific Notes

<!-- Add known gotchas, public endpoints, and project-specific issues here -->
