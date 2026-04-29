# [Project Name] — Claude Code Instructions

## Project Overview

**Stack:** Node.js 20+ + Express/Fastify + TypeScript + pnpm
**Type:** [API/Microservice/Backend]
**Database:** PostgreSQL / MongoDB / Redis
**Testing:** Vitest + Supertest

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

1. **Security:** DO NOT concatenate user input in SQL/commands, ALWAYS validate input with Zod
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Async:** ALWAYS await promises, ALWAYS handle errors
8. **User-Agent:** NEVER use default library UA, ALWAYS set real browser User-Agent

---

## AT THE START OF EACH SESSION

1. **Verify directory:** `pwd` + `git rev-parse --show-toplevel` — lock this directory for the session
2. **Context is auto-loaded** from `.claude/rules/` — no manual reads needed
3. **For on-demand details:** read `.claude/docs/` files as needed

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
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push. **Before build/deploy: `git fetch origin main && git merge origin/main`** to include changes from other sessions.
- **BEFORE COMMIT** — run `pnpm lint`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

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
8. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `axios.get(url, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36' } })`

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
- **NEVER** batch-restart all workers — use `pm2 reload` (graceful)
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

## Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |
| `nodejs` | Async patterns, validation, security |
| `i18n` | When adding multilanguage support, translations, localization |

Load: `Read .claude/skills/{skill-name}/SKILL.md`

---

## Scratchpad

Complex tasks: `.claude/scratchpad/current-task.md` for plans, `findings.md` for research, `decisions.md` for decisions.

---

## Knowledge Persistence

On significant changes, update: (1) `.claude/rules/` for project facts, (2) `.claude/CLAUDE.md` if workflow changed, (3) docs/README for humans.

---

## Supreme Council

> Supreme Council is global — see `~/.claude/CLAUDE.md` "Supreme Council" section.

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
