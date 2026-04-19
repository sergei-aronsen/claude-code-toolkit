# [Project Name] — Claude Code Instructions

## Project Overview

**Stack:** Python 3.11+ + FastAPI/Django + uv/Poetry
**Type:** [API/Microservice/Backend/ML Service]
**Database:** PostgreSQL / MongoDB / Redis
**Testing:** pytest + pytest-asyncio

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

## Compact Instructions

> **When compacting, preserve these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/commands, ALWAYS validate with Pydantic
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Types:** ALWAYS use type hints, mypy must pass
8. **User-Agent:** NEVER use default library UA, ALWAYS set real browser User-Agent

---

## AT THE START OF EACH SESSION

1. **Verify directory:** `pwd` + `git rev-parse --show-toplevel` — lock this directory for the session
2. **Context is auto-loaded** from `.claude/rules/` — no manual reads needed
3. **For on-demand details:** read `.claude/docs/` files as needed

---

## WORKFLOW RULES (MANDATORY!)

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
- **BEFORE COMMIT** — run `uv run ruff check . && uv run mypy src/`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

---

## Project Structure (FastAPI)

```text
src/
├── api/                 # API routes
│   ├── v1/
│   │   ├── users.py
│   │   └── health.py
│   └── deps.py          # Dependencies (auth, db)
├── core/                # Core configuration
│   ├── config.py        # Settings (Pydantic)
│   ├── security.py      # Auth, JWT
│   └── exceptions.py    # Custom exceptions
├── models/              # SQLAlchemy/Pydantic models
│   ├── user.py
│   └── base.py
├── schemas/             # Pydantic schemas (API I/O)
│   └── user.py
├── services/            # Business logic
│   └── user_service.py
├── repositories/        # Data access layer
│   └── user_repository.py
└── utils/               # Helper functions
```

### Project Structure (Django)

```text
project/
├── config/              # Project configuration
│   ├── settings/
│   │   ├── base.py
│   │   ├── local.py
│   │   └── production.py
│   ├── urls.py
│   └── wsgi.py
├── apps/                # Django apps
│   ├── users/
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── serializers.py
│   │   └── urls.py
│   └── core/
├── api/                 # DRF views
└── utils/               # Shared utilities
```

---

## Essential Commands

```bash
# Development (uv)
uv run python -m uvicorn src.main:app --reload    # FastAPI dev
uv run python manage.py runserver                  # Django dev

# Development (poetry)
poetry run uvicorn src.main:app --reload
poetry run python manage.py runserver

# Testing
uv run pytest                        # Run tests
uv run pytest -v --cov=src           # With coverage
uv run pytest -k "test_users"        # Filter tests

# Code Quality
uv run ruff check .                  # Lint
uv run ruff check . --fix            # Auto-fix
uv run ruff format .                 # Format
uv run mypy src/                     # Type check

# Dependencies
uv add package                       # Add dependency
uv add --dev package                 # Add dev dependency
uv sync                              # Sync dependencies
```

---

## Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS validate with Pydantic
2. **SQL Injection** — ONLY use ORM (SQLAlchemy/Django ORM), NEVER raw queries with user input
3. **Command Injection** — NEVER use subprocess with user input
4. **Authorization** — ALWAYS check permissions via dependencies
5. **Secrets** — ONLY through env variables (pydantic-settings)
6. **Password Hashing** — ONLY passlib with bcrypt
7. **Rate Limiting** — slowapi for FastAPI, django-ratelimit for Django
8. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `requests.get(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'})`

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
- **NEVER** batch-restart all workers — use graceful restart
- Verify after every deploy: endpoints, logs, workers

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

## Coding Style (Python)

- Type hints EVERYWHERE (mypy strict)
- Pydantic v2 for validation (not v1!)
- SQLAlchemy 2.0 style (async)
- Async/await for I/O operations
- Structured logging (structlog)

---

## Code Style

### Naming Conventions (Python)

- **Files:** `snake_case.py`
- **Classes:** `PascalCase`
- **Functions:** `snake_case`
- **Variables:** `snake_case`
- **Constants:** `UPPER_SNAKE_CASE`
- **Private:** `_leading_underscore`

### Best Practices

- Maximum 200 lines per file
- Single responsibility per module
- Type hints are mandatory
- Docstrings for public API
- **All code comments, commit messages, and documentation in English** regardless of conversation language

---

## Python Patterns

### Pydantic v2 Schemas

```python
from pydantic import BaseModel, Field, EmailStr
from datetime import datetime

class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    age: int | None = Field(default=None, ge=0, le=150)

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

### FastAPI Dependency Injection

```python
from fastapi import Depends, HTTPException, status
from typing import Annotated

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    user = await user_service.get_by_token(db, token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]
```

### Error Handling

```python
from fastapi import HTTPException

class AppException(Exception):
    def __init__(self, status_code: int, detail: str, code: str | None = None):
        self.status_code = status_code
        self.detail = detail
        self.code = code

# Usage
raise AppException(404, "User not found", "USER_NOT_FOUND")
```

### Async SQLAlchemy 2.0

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(
        select(User).where(User.email == email)
    )
    return result.scalar_one_or_none()
```

---

## Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (pytest) |
| `/agent:planner` | Planner | Task planning |
| `/agent:python-expert` | Python Expert | FastAPI/Django patterns |

---

## Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |
| `python` | Async patterns, Pydantic v2, testing |
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
