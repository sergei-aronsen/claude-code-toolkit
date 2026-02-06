# Features and Examples

Detailed descriptions of Claude Code Toolkit features with usage examples.

---

## Self-Learning System

Claude learns from your corrections and accumulates project knowledge.

**Two mechanisms:**

| Mechanism | What it does | When to use |
|-----------|--------------|-------------|
| `/learn` | Saves **one-time** problem solution | Solved non-trivial problem, found workaround |
| **Skill Accumulation** | Accumulates **recurring** patterns | Claude noticed it was corrected 2+ times |

**The difference:**

```text
/learn  → "How I solved problem X"     (one-time fix)
skill   → "How we always do Y"         (project pattern)
```

**Example /learn:**

```text
> /learn

Analyzing session...
Found: Prisma Serverless Connection Fix

Problem: Connection timeout in Vercel Edge Functions
Solution: Add ?connection_limit=1 to DATABASE_URL

Save to .claude/learned/prisma-serverless.md? → yes
```

**Example Skill Accumulation:**

```text
User: create endpoint for users
Claude: [creates endpoint]
User: no, we use Zod for validation and AppError for errors

Claude: Noticed pattern: endpoints use Zod + AppError
        Save as skill 'backend-endpoints'?
        Will activate on: endpoint, api, route

User: yes

[Next time Claude uses Zod + AppError right away]
```

---

## Auto-Activation Hooks

**Problem:** You have 10 skills, but forget to use them.

**Solution:** Hook intercepts prompt **BEFORE** sending to Claude and recommends loading a skill.

```text
User prompt → Hook analyzes → Scoring → Recommendation
```

**Scoring system:**

| Trigger | Points | Example |
|---------|--------|---------|
| keyword | +2 | "endpoint" in prompt |
| intentPattern | +4 | "create.*endpoint" |
| pathPattern | +5 | File `src/api/*` is open |

**Example:**

```text
Prompt: "create POST endpoint for registration"
File: src/api/auth.controller.ts

SKILL RECOMMENDATIONS:
[HIGH] backend-dev (score: 13)
[HIGH] security-review (score: 12)

Use Skill tool to load guidelines.
```

---

## Memory Persistence

**Problem:** MCP memory is stored locally. Move to another computer — memory lost.

**Solution:** Export to `.claude/memory/` → commit to git → available everywhere.

```text
.claude/memory/
├── knowledge-graph.json   # Component relationships
├── project-context.md     # Project context
└── decisions-log.md       # Why we made decision X
```

**Workflow:**

```text
At session start:    Check sync → Load memory from MCP
After changes:       Export → Commit .claude/memory/
On new computer:     Pull → Import to MCP
```

---

## Systematic Debugging (/debug)

**Iron Law:**

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

**4 phases:**

| Phase | What to do | Exit criteria |
|-------|------------|---------------|
| **1. Root Cause** | Read errors, reproduce, trace data flow | Understand WHAT and WHY |
| **2. Pattern** | Find working example, compare | Found differences |
| **3. Hypothesis** | Formulate theory, test ONE change | Confirmed |
| **4. Fix** | Write test, fix, verify | Tests green |

**Rule of three fixes:**

```text
If 3+ fixes didn't work — STOP!
This is not a bug. This is an architectural problem.
```

---

## Production Safety (/deploy, /fix-prod)

**Problem:** Deploys break production, fixes introduce new bugs, workers crash.

**Solution:** Safety-first approach to production operations.

**Key rules:**

| Rule | Why |
|------|-----|
| **Incremental deploy** | One change → verify → next change. Batch deploys hide which change broke things |
| **Rolling worker restart** | Never restart all at once — active jobs fail and exceed retry limits |
| **Simplest fix first** | Remove unnecessary code before adding new. Don't try complex hacks |
| **Verify file target** | Confirm correct file variant (V2/legacy), correct branch, not already fixed upstream |

**Example /deploy:**

```text
> /deploy

Phase 1: Pre-Deploy
  Git: clean, up to date with origin/main
  Tests: 47 passed
  Build: success

Phase 2: Deploy
  Code pulled, migrations run, cache cleared
  Workers: rolling restart (graceful)

Phase 3: Verification
  Endpoints: all 200
  Errors: none in last 60s
  Workers: running normally

Result: SUCCESS
```

**Example /fix-prod:**

```text
> /fix-prod queue jobs timing out

Phase 1: Diagnose
  Logs: Redis connection timeout after deploy
  Root cause: Redis config not cached

Phase 2: Fix
  php artisan config:cache (1 line change)

Phase 3: Verify
  Queue processing normally, no errors
```

---

## Structured Workflow

**Problem:** Claude often "codes right away" instead of understanding the task.

**Solution:** 3 phases with explicit restrictions:

| Phase | Access | What's allowed |
|-------|--------|----------------|
| **RESEARCH** | Read-only | Glob, Grep, Read — understand context |
| **PLAN** | Scratchpad-only | Write plan in `.claude/scratchpad/` |
| **EXECUTE** | Full | Only after plan confirmation |

```text
User: Add email validation

Claude: Phase 1: RESEARCH
        [Reads files, searches patterns]
        Found: form in RegisterForm.tsx, validation via Zod

        Phase 2: PLAN
        [Creates plan in .claude/scratchpad/current-task.md]
        Plan ready. Confirm to proceed.

User: ok

Claude: Phase 3: EXECUTE
        Step 1: Adding schema...
        Step 2: Integrating into form...
        Step 3: Tests...
```

---

## Usage Examples

### /verify — pre-commit check

```text
> /verify

Running checks...
Build: passed
TypeScript: no errors
ESLint: 2 warnings (unused imports)
Tests: 23 passed

Recommendation: fix lint warnings before commit.
```

### /debug — systematic debugging

```text
> /debug API returns 500 on /api/users

Phase 1: ROOT CAUSE ANALYSIS
├── Reading app/api/users/route.ts
├── Checking logs
└── Found: prisma.user.findMany() without try/catch

Phase 2: HYPOTHESIS
└── Database connection timeout on cold start

Phase 3: FIX
└── Adding error handling + retry logic

Phase 4: VERIFY
└── Testing endpoint — works
```

### /audit security — security audit

```text
> /audit security

SECURITY AUDIT REPORT
=====================

CRITICAL (1)
├── SQL Injection in UserController:45
└── Recommendation: use prepared statements

MEDIUM (2)
├── No rate limiting on /api/login
└── CORS configured as Access-Control-Allow-Origin: *

LOW (1)
└── Debug mode in .env.example
```

---

## Templates (7 options)

| Template | For what | Features |
|----------|----------|----------|
| `base/` | Any project | Universal rules |
| `laravel/` | Laravel + Vue/Inertia | Eloquent, migrations, Blade, Pint |
| `rails/` | Ruby on Rails + Hotwire | ActiveRecord, Turbo, Stimulus, RSpec |
| `nextjs/` | Next.js + TypeScript | App Router, RSC, Tailwind |
| `nodejs/` | Node.js + Express/Fastify | Zod, Pino, async patterns |
| `python/` | Python + FastAPI/Django | Pydantic v2, SQLAlchemy 2.0 |
| `go/` | Go + Gin/Chi | Goroutines, table-driven tests |

---

## Slash Commands (26 total)

| Command | Description |
|---------|-------------|
| `/verify` | Pre-commit check: build, types, lint, tests |
| `/debug [problem]` | 4-phase debugging: root cause → hypothesis → fix → verify |
| `/learn` | Save problem solution to `.claude/learned/` |
| `/plan` | Create plan in scratchpad before implementation |
| `/audit [type]` | Run audit (security, performance, code, design, database) |
| `/test` | Write tests for module |
| `/refactor` | Refactoring while preserving behavior |
| `/fix [issue]` | Fix specific issue |
| `/explain` | Explain how code works |
| `/doc` | Generate documentation |
| `/context-prime` | Load project context at session start |
| `/checkpoint` | Save progress to scratchpad |
| `/handoff` | Prepare task handoff (summary + next steps) |
| `/worktree` | Git worktrees management |
| `/update-toolkit` | Reinstall or update Claude Code Toolkit |
| `/migrate` | Database migration assistance |
| `/find-function` | Find function by name/description |
| `/find-script` | Find script in package.json/composer.json |
| `/tdd` | Test-Driven Development workflow |
| `/docker` | Generate Dockerfile and docker-compose |
| `/api` | Design REST API endpoints, generate OpenAPI |
| `/e2e` | Generate E2E tests with Playwright |
| `/perf` | Performance analysis: N+1, bundle, memory |
| `/deploy` | Safe deployment with pre/post checks and verification |
| `/fix-prod` | Production hotfix: diagnose → minimal fix → verify |
| `/deps` | Dependency audit: security, licenses, outdated |

---

## Audits (7 types)

| Audit | File | What it checks |
|-------|------|----------------|
| **Security** | `SECURITY_AUDIT.md` | SQL injection, XSS, CSRF, auth, secrets |
| **Performance** | `PERFORMANCE_AUDIT.md` | N+1, bundle size, caching, lazy loading |
| **Code Review** | `CODE_REVIEW.md` | Patterns, readability, SOLID, DRY |
| **Design Review** | `DESIGN_REVIEW.md` | UI/UX, accessibility, responsive (Playwright MCP) |
| **MySQL** | `MYSQL_PERFORMANCE_AUDIT.md` | performance_schema, indexes, slow queries |
| **PostgreSQL** | `POSTGRES_PERFORMANCE_AUDIT.md` | pg_stat_statements, bloat, connections |
| **Deploy** | `DEPLOY_CHECKLIST.md` | Pre-deploy checklist |

---

## Components (24+ guides)

| Component | Description |
|-----------|-------------|
| `structured-workflow.md` | 3-phase approach: Research → Plan → Execute |
| `smoke-tests-guide.md` | Minimal API tests (Laravel/Next.js/Node.js) |
| `hooks-auto-activation.md` | Skills auto-activation by prompt context |
| `skill-accumulation.md` | Self-learning: Claude accumulates project knowledge |
| `modular-skills.md` | Progressive disclosure for large guidelines |
| `spec-driven-development.md` | Specifications before code |
| `mcp-servers-guide.md` | Recommended MCP servers |
| `memory-persistence.md` | MCP memory sync with Git |
| `plan-mode-instructions.md` | Think levels: think → think hard → ultrathink |
| `git-worktrees-guide.md` | Parallel work on branches |
| `devops-highload-checklist.md` | Highload projects checklist |
| `api-health-monitoring.md` | API endpoints monitoring |
| `bootstrap-workflow.md` | New project workflow |
| `github-actions-guide.md` | CI/CD workflow templates |
| `pre-commit-hooks.md` | Husky, lint-staged, pre-commit |
| `deployment-strategies.md` | Blue-green, canary, rolling updates |
| `production-safety.md` | Deploy safety, worker safety, bug fix approach, file targeting |
