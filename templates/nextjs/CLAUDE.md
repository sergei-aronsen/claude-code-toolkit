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
6. **Next.js:** App Router, Server Components by default, 'use client' only when necessary

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
- **BEFORE COMMIT** — run `pnpm lint` (or project linters), fix all errors

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

---

## Visual Self-Testing (Playwright MCP)

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow: navigate to page, check for console errors, interact with changed elements, take screenshots, report findings. If bug found — fix, redeploy, re-test.

**IMPORTANT: Always call `browser_close` after finishing tests.** Multiple Claude sessions share the same Playwright browser profile. Leaving the browser open will block other sessions from launching it.

Requires Playwright MCP server. Full guide: `components/playwright-self-testing.md`

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
| `mysql audit` | Run `MYSQL_PERFORMANCE_AUDIT.md` |
| `postgres audit` | Run `POSTGRES_PERFORMANCE_AUDIT.md` |
| `deploy checklist` | Run `DEPLOY_CHECKLIST.md` |

---

## 🎓 Available Skills

| Skill | When to load |
| ----- | --------------- |
| `ai-models` | When working with AI API (Anthropic, Google) |

Load: `Read .claude/skills/ai-models/SKILL.md`

---

## 📝 Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## 🧠 Knowledge Persistence (SAVE KNOWLEDGE!)

For **significant changes** — save knowledge to THREE places:

1. **CLAUDE.md** — update this file
2. **Documentation** — update /docs or README
3. **MCP Memory** — save for future sessions (always in English, regardless of conversation language)

---

## ⚠️ Project-Specific Notes

### Known Gotchas

- [List project-specific issues]

### Public Endpoints (by design)

- `/api/health` — Health check
- `/api/webhooks/*` — External webhooks
