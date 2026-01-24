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
4. **Git:** Conventional Commits, DO NOT push to main directly
5. **Rails:** Convention over Configuration, Strong Parameters, Concerns for shared logic

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

---

## 🤖 Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (RSpec/Minitest) |
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
| `postgres audit` | Run `POSTGRES_PERFORMANCE_AUDIT.md` |
| `deploy checklist` | Run `DEPLOY_CHECKLIST.md` |

---

## 🎓 Available Skills

| Skill | When to load |
| ----- | --------------- |
| `rails` | Rails conventions, ActiveRecord, Hotwire |
| `ai-models` | When working with AI API (Anthropic, Google) |

Load: `Read .claude/skills/rails/SKILL.md`

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

- `/health` — Health check
- `/webhooks/*` — External webhooks
