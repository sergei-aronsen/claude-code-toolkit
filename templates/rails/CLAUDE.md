# [Project Name] — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Ruby on Rails + [Hotwire/React/Vue] + [PostgreSQL/MySQL]
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
7. **Rails:** Convention over Configuration, Strong Parameters, Concerns for shared logic
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
- **BEFORE COMMIT** — run `bundle exec rubocop`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

---

## 📁 Project Structure (Rails)

```text
app/
├── controllers/        # Thin controllers
├── models/             # ActiveRecord models + business logic
│   └── concerns/       # Shared model logic
├── views/              # ERB/Haml templates
├── helpers/            # View helpers
├── services/           # Service objects (POROs)
├── jobs/               # Background jobs (Sidekiq/GoodJob)
└── mailers/            # Email logic
config/
├── routes.rb           # Routing
├── database.yml        # Database config
└── initializers/       # App configuration
db/
├── migrate/            # Database migrations
├── seeds.rb            # Seed data
└── schema.rb           # Current schema
spec/ or test/          # Tests (RSpec or Minitest)
```

---

## ⚡ Essential Commands

```bash
# Development
bin/rails server               # Start dev server
bin/rails console              # Rails console

# Testing
bin/rails test                 # Minitest
bundle exec rspec              # RSpec

# Code Quality
bundle exec rubocop            # Lint + format
bundle exec rubocop -a         # Auto-fix

# Database
bin/rails db:migrate           # Run migrations
bin/rails db:seed              # Run seeds
bin/rails db:reset             # Drop + create + migrate + seed

# Generators
bin/rails generate model User name:string email:string
bin/rails generate controller Users index show
bin/rails generate migration AddStatusToUsers status:integer
```

---

## 🔒 Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS use Strong Parameters
2. **SQL Injection** — ONLY ActiveRecord methods, NEVER raw queries with user input
3. **XSS** — ERB auto-escapes `<%= %>`, DO NOT use `raw()` or `html_safe` for user data
4. **CSRF** — Keep `protect_from_forgery` enabled
5. **Authorization** — Use Pundit or CanCanCan for authorization
6. **Secrets** — ONLY through credentials or ENV, NEVER hardcode
7. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `Faraday.new { |f| f.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36' }`

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
- **NEVER** batch-restart all workers — use rolling restarts
- Verify after every deploy: endpoints, logs, workers

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
3. **Convention over Configuration:** Follow Rails conventions.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## 💻 Coding Style (Rails)

- Fat models, skinny controllers
- Strong Parameters for input filtering
- Concerns for shared model/controller logic
- Service objects for complex business logic
- Follow Ruby style guide (Rubocop)

---

## 🎨 Code Style

### Naming Conventions (Rails)

- **Controllers:** `UsersController` (plural)
- **Models:** `User` (singular)
- **Tables:** `users` (plural, snake_case)
- **Migrations:** `create_users`, `add_email_to_users`
- **Variables:** `snake_case`
- **Methods:** `snake_case`
- **Classes:** `CamelCase`

### Best Practices

- Maximum 200 lines per file
- Single responsibility per class
- Use `frozen_string_literal: true` pragma
- Prefer symbols over strings for hash keys
- **All code comments, commit messages, and documentation in English** regardless of conversation language

---

## 🤖 Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (RSpec/Minitest) |
| `/agent:planner` | Planner | Task planning |

---

## 🎓 Available Skills

| Skill | When to load |
| ----- | --------------- |
| `rails` | Rails conventions, ActiveRecord, Hotwire |
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
