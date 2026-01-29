# [Project Name] — Claude Code Instructions

## Project Overview

**Stack:** Python 3.11+ + FastAPI/Django + uv/Poetry
**Type:** [API/Microservice/Backend/ML Service]
**Database:** PostgreSQL / MongoDB / Redis
**Testing:** pytest + pytest-asyncio

---

## Compact Instructions

> **When compacting, preserve these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/commands, ALWAYS validate with Pydantic
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly
5. **Types:** ALWAYS use type hints, mypy must pass

---

## AT THE START OF EACH SESSION

### 1. Check Memory Synchronization

```bash
# Compare MCP vs git file dates
ls -la ~/.claude/memory-bank/[PROJECT_NAME]/*.md
ls -la .claude/memory/*.md
```

- **MCP newer than git** → copy: `cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/`
- **git newer than MCP** (new computer) → import memory into MCP

### 2. Read Project Memory

```text
mcp__memory-bank__memory_bank_read (projectName: "[PROJECT_NAME]", fileName: "project-context.md")
mcp__memory__read_graph()
```

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

## Quick Commands

| Command | Description |
| --------- | -------- |
| `/verify` | Quick check: types, lint, tests |
| `/debug` | Systematic debugging (4 phases, root cause first) |
| `/learn` | Save problem solution to `.claude/learned/` |
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
| `python` | Async patterns, Pydantic v2, testing |

Load: `Read .claude/skills/python/SKILL.md`

---

## Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## Knowledge Persistence (SAVE YOUR KNOWLEDGE!)

When making **significant changes** — save knowledge to THREE places:

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
