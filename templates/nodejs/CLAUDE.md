# [Project Name] — Claude Code Instructions

## Project Overview

**Stack:** Node.js 20+ + Express/Fastify + TypeScript + pnpm
**Type:** [API/Microservice/Backend]
**Database:** PostgreSQL / MongoDB / Redis
**Testing:** Vitest + Supertest

---

## Compact Instructions

> **When compacting, preserve these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/commands, ALWAYS validate input with Zod
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Async:** ALWAYS await promises, ALWAYS handle errors

---

## AT THE START OF EACH SESSION

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

- **MCP is newer than git** → copy: `cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/`
- **git is newer than MCP** (new computer) → import memory into MCP

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

## WORKFLOW RULES (MANDATORY!)

### Plan Mode — ALWAYS USE BEFORE CODE

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Research** the task and existing code
3. **Create plan** in `.claude/scratchpad/current-task.md`
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
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push.
- **BEFORE COMMIT** — run `pnpm lint`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., sync with main before work (`git fetch origin main && git reset --hard origin/main`), merge when done. See `components/git-worktrees-guide.md`

---

## Project Structure (Node.js)

```text
src/
├── routes/              # Express/Fastify routes
│   ├── users.ts
│   └── health.ts
├── controllers/         # Request handlers
├── services/            # Business logic
├── repositories/        # Data access layer
├── middleware/          # Express/Fastify middleware
│   ├── auth.ts
│   ├── error-handler.ts
│   └── rate-limit.ts
├── validators/          # Zod schemas
├── types/               # TypeScript types
├── utils/               # Helper functions
└── config/              # Configuration
    ├── database.ts
    └── env.ts
```

---

## Essential Commands

```bash
# Development
pnpm dev                       # Start dev server
pnpm dev:watch                 # Watch mode (nodemon/tsx watch)

# Testing
pnpm test                      # Run tests (Vitest)
pnpm test:watch                # Watch mode
pnpm test:coverage             # Coverage report

# Code Quality
pnpm lint                      # ESLint
pnpm lint:fix                  # Auto-fix
pnpm format                    # Prettier
pnpm type-check                # TypeScript check

# Build
pnpm build                     # Production build
pnpm start                     # Start production server
```

---

## Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS validate with Zod at entry point
2. **SQL Injection** — ONLY ORM (Prisma/Drizzle/Knex), NEVER raw queries with user input
3. **Command Injection** — NEVER use exec/spawn with user input
4. **XSS** — ALWAYS escape output, use helmet.js
5. **Authorization** — ALWAYS check permissions in middleware
6. **Secrets** — ONLY through env variables, NEVER hardcode
7. **Rate Limiting** — ALWAYS on public endpoints

---

## Architecture Guidelines (STRICT!)

1. **KISS Principle:** Simplest working solution. No premature optimization.
2. **YAGNI:** No features/abstractions "for the future".
3. **No Boilerplate:** No excessive abstraction layers unless explicitly requested.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## Coding Style (Node.js)

- TypeScript strict mode
- Zod for all input validation
- Pino for logging (fastest)
- Async/await everywhere (no callbacks)
- Error handling with custom AppError class

---

## Code Style

### Naming Conventions (Node.js)

- **Files:** `kebab-case.ts`
- **Classes:** `PascalCase`
- **Functions:** `camelCase`
- **Variables:** `camelCase`
- **Constants:** `UPPER_SNAKE_CASE`
- **Types/Interfaces:** `PascalCase`

### Best Practices

- Maximum 200 lines per file
- Single responsibility per module
- Strict TypeScript (no any!)
- Comments for complex logic
- **All code comments, commit messages, and documentation in English** regardless of conversation language

---

## Node.js Patterns

### Error Handling

```typescript
// Custom error class
export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public code?: string
  ) {
    super(message);
  }
}

// Usage
throw new AppError(404, 'User not found', 'USER_NOT_FOUND');
```

### Validation with Zod

```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  age: z.number().int().positive().optional(),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;
```

### Async Handler (Express)

```typescript
// Wrap async handlers to catch errors
const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Usage
router.get('/users', asyncHandler(async (req, res) => {
  const users = await userService.findAll();
  res.json(users);
}));
```

---

## Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (Vitest) |
| `/agent:planner` | Planner | Task planning |
| `/agent:nodejs-expert` | Node.js Expert | Express/Fastify patterns |

---

## Quick Commands

| Command | Description |
| --------- | -------- |
| `/verify` | Quick check: build, types, lint, tests |
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
| `nodejs` | Async patterns, validation, security |

Load: `Read .claude/skills/nodejs/SKILL.md`

---

## Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## Knowledge Persistence (SAVE KNOWLEDGE!)

On **significant changes** — save knowledge in THREE places:

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
