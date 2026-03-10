# Claude Guides — Quick Reference

## Commands

| Command | What it does |
|---------|-------------|
| `/plan` | Create implementation plan before coding |
| `/debug` | Systematic 4-phase debugging |
| `/verify` | Pre-commit check: build, types, lint, tests |
| `/audit` | Run audit: security, performance, code, design, db |
| `/test` | Write tests for a module |
| `/tdd` | Test-Driven Development: tests first, then code |
| `/fix` | Fix a specific issue |
| `/refactor` | Improve structure without changing behavior |
| `/explain` | Explain how code or architecture works |
| `/doc` | Generate documentation |
| `/learn` | Save lesson to `.claude/rules/lessons-learned.md` (auto-loaded) |
| `/context-prime` | Load project context at session start |
| `/checkpoint` | Save progress to scratchpad |
| `/handoff` | Prepare task handoff with summary and next steps |
| `/update-toolkit` | Reinstall or update Claude Code Toolkit |
| `/worktree` | Manage git worktrees for parallel branches |
| `/migrate` | Create or troubleshoot database migrations |
| `/find-function` | Find function or class definition in codebase |
| `/find-script` | Find scripts in package.json, Makefile, etc. |
| `/docker` | Generate Dockerfile and docker-compose |
| `/api` | Design REST API, generate OpenAPI spec |
| `/e2e` | Generate E2E tests with Playwright |
| `/perf` | Performance analysis: N+1, bundle, memory |
| `/deps` | Dependency audit: security, licenses, outdated |

---

## Agents

Use agents for deep, focused analysis:

| Agent | How to call | Purpose |
|-------|------------|---------|
| Code Reviewer | `/agent:code-reviewer` | Review code against checklists |
| Test Writer | `/agent:test-writer` | Generate tests using TDD approach |
| Planner | `/agent:planner` | Break task into plan with phases |
| Security Auditor | `/agent:security-auditor` | Deep security analysis |

---

## Audits

Run via `/audit {type}`:

| Type | Checks |
|------|--------|
| `security` | SQL injection, XSS, CSRF, auth, secrets |
| `performance` | N+1 queries, caching, lazy loading, bundle size |
| `code` | Patterns, readability, SOLID, DRY |
| `design` | UI/UX, accessibility, responsive |
| `mysql` | Indexes, slow queries, performance_schema |
| `postgres` | pg_stat_statements, bloat, connections |
| `deploy` | Pre-deployment checklist |

---

## Skills

Skills activate automatically based on context (keywords, file patterns):

| Skill | Activates when |
|-------|---------------|
| Database | Migrations, indexes, queries |
| API Design | REST endpoints, OpenAPI, status codes |
| Docker | Containers, Dockerfile, compose |
| Testing | Tests, mocking, coverage |
| Tailwind | CSS styling, responsive design |
| Observability | Logging, metrics, tracing |
| LLM Patterns | RAG, embeddings, streaming |
| AI Models | Model selection, pricing, context windows |

---

## Workflow

### Three Phases (mandatory)

```text
RESEARCH (read-only) --> PLAN (scratchpad-only) --> EXECUTE (full access)
```

### Thinking Levels

| Level | When to use |
|-------|------------|
| `think` | Simple tasks, quick fixes |
| `think hard` | Multi-step features, refactoring |
| `ultrathink` | Architecture decisions, complex debugging |

---

## Scenarios — When to Use What

### I found a bug

```text
/debug description of the bug
```

Claude investigates root cause before fixing. After fix: `/verify`

### I need a code review

```text
/audit code
```

Or for a full review: `/audit security` then `/audit performance`

### I want to add a new feature

```text
/plan description of the feature
```

Claude creates a plan in scratchpad. After approval, executes it. Then: `/verify`

### I need to write tests

```text
/tdd module_name
```

Writes failing tests first, then writes minimal code to pass them.

### Before deploying

```text
/verify
/audit security
/audit deploy
```

Run all three to catch issues before they reach production.

### Starting a new session

```text
/context-prime
```

Loads project context so Claude understands the codebase from the start.

### Handing off to another developer

```text
/handoff
```

Creates a summary of what was done, current state, and next steps.

### I need to refactor safely

```text
/refactor target_code
```

Claude refactors while preserving behavior. Always runs tests after.

### I need to understand code I didn't write

```text
/explain path/to/file.ts
/explain authentication flow
```

### Database work

```text
/migrate create users table
/audit mysql
/audit postgres
```

### Performance issues

```text
/perf
/audit performance
```

### Dependency check

```text
/deps
```

Checks for security vulnerabilities, outdated packages, license issues.

---

## MCP Servers

| Server | Purpose |
|--------|---------|
| context7 | Up-to-date library documentation |
| playwright | Browser automation, UI testing, screenshots |
| sequential-thinking | Step-by-step problem solving |

---

## Quick Tips

- Always use `/plan` before big features — prevents wasted effort
- Run `/verify` before every commit — catches issues early
- Use `/learn` after solving tricky problems — saves knowledge for future sessions
- Start sessions with `/context-prime` — Claude works better with context
- Use `/checkpoint` during long tasks — progress is saved if session drops
