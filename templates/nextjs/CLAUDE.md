# [Project Name] — Claude Code Instructions

## 🎯 Project Overview

**Stack:** Next.js 15 + TypeScript + Tailwind CSS + Prisma
**Type:** [SaaS/Dashboard/E-commerce/Marketing Site]
**Database:** PostgreSQL 15+ / MySQL 8.x
**Node:** 20+ | **Package Manager:** pnpm

---

## 📌 Compact Instructions

> **When compacting, preserve these critical rules:**

1. **Security:** DO NOT concatenate user input in SQL/HTML, ALWAYS validate input
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **Next.js:** App Router, Server Components by default, 'use client' only when necessary
8. **User-Agent:** NEVER use default library UA, ALWAYS set real browser User-Agent

---

## AT THE START OF EACH SESSION

1. **Verify directory:** `pwd` + `git rev-parse --show-toplevel` — lock this directory for the session
2. **Context is auto-loaded** from `.claude/rules/` — no manual reads needed
3. **For on-demand details:** read `.claude/docs/` files as needed

---

## 🧠 WORKFLOW RULES (MANDATORY!)

### Plan Mode — ALWAYS USE BEFORE CODE

1. **Activate Plan Mode** — `Shift+Tab` twice
2. **Research** the task and existing code
3. **Create a plan** in `.claude/scratchpad/current-task.md`
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
- **CHANGELOG** — update for `feat:`, `fix:`, breaking changes
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push. **Before build/deploy: `git fetch origin main && git merge origin/main`** to include changes from other sessions.
- **BEFORE COMMIT** — run `pnpm lint`, then `git pull --rebase`, fix all errors
- **WORKTREES** — if in branch `work-1`/`work-2`/etc., **always run `git status` first** before sync. If uncommitted changes — ask user! Then: `git fetch origin main && git reset --hard origin/main`. See `components/git-worktrees-guide.md`

---

## 📁 Project Structure (Next.js App Router)

```text
src/
├── app/
│   ├── (auth)/           # Route groups
│   ├── api/              # API routes
│   ├── layout.tsx        # Root layout
│   └── page.tsx          # Home page
├── components/
│   ├── ui/               # Reusable UI components
│   └── features/         # Feature-specific components
├── lib/
│   ├── db.ts             # Database client
│   ├── auth.ts           # Auth utilities
│   └── utils.ts          # Helper functions
└── types/                # TypeScript types
```

---

## ⚡ Essential Commands

```bash
# Development
pnpm dev                       # Start dev server

# Testing
pnpm test                      # Run tests
pnpm test:watch                # Watch mode

# Code Quality
pnpm lint                      # ESLint
pnpm type-check                # TypeScript check

# Build
pnpm build                     # Production build
```

---

## 🔒 Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS validate with Zod on the server
2. **SQL Injection** — ONLY Prisma/Drizzle ORM, NEVER raw queries with user input
3. **XSS** — React escapes automatically, DO NOT use `dangerouslySetInnerHTML`
4. **Authorization** — ALWAYS check in Server Components and API routes
5. **Secrets** — ONLY via `.env.local`, NEVER hardcode
6. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36' } })`

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
- **NEVER** batch-restart all workers — use `pm2 reload` (graceful)
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
3. **No Boilerplate:** No excessive abstraction layers unless explicitly requested.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## 💻 Coding Style (Next.js)

- Server Components by default
- 'use client' only when necessary (interactivity, hooks)
- Zod for validation
- Server Actions for mutations
- Tailwind CSS for styling

---

## 🎨 Code Style

### Naming Conventions (Next.js)

- **Components:** `PascalCase.tsx`
- **Utilities:** `camelCase.ts`
- **API routes:** `route.ts` in folder
- **Variables:** `camelCase`
- **Types:** `PascalCase`

### Best Practices

- Maximum 200 lines per file
- Single responsibility per component
- Strict TypeScript
- Comments for complex logic
- **All code comments, commit messages, and documentation in English** regardless of conversation language

---

## 🤖 Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests (Vitest) |
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
