# [Project Name] — Claude Code Instructions

## 🎯 Project Overview

**Stack:** [Framework] + [Frontend] + [Database]
**Type:** [SaaS/API/Dashboard/etc.]
**Description:** [Brief description]

---

## 📌 Compact Instructions

> **Keep these critical rules when compacting:**

1. **Security:** DO NOT concatenate user input in SQL/HTML, ALWAYS validate input
2. **Architecture:** KISS, YAGNI, DO NOT create files without confirmation
3. **Workflow:** Plan Mode before code, 3 phases (Research → Plan → Execute)
4. **Git:** Conventional Commits, DO NOT push to main directly

---

## AT THE START OF EACH SESSION

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

### 3. Load additional files if needed

- `decisions-log.md` — architectural decisions
- `server-config.md` — configurations (if any)
- `integrations.md` — external services (if any)

---

## WORKFLOW RULES (MANDATORY!)

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

**Prompt example:**

```text
"Analyze task [description]. Think harder about edge cases.
DO NOT WRITE CODE — plan only."
```

### Structured Workflow (for complex tasks)

For features, refactoring, multi-file changes — use 3 phases:

| Phase | Access | What to do |
| ---- | ------ | ---------- |
| **RESEARCH** | Read-only | Glob, Grep, Read — understand context |
| **PLAN** | Scratchpad-only | Write plan in `.claude/scratchpad/` |
| **EXECUTE** | Full access | After confirmation — implement |

**Rule:** Do not proceed to the next phase until you complete the current one.

### Git Workflow

- **Branch naming:** `feature/xxx`, `fix/xxx`, `refactor/xxx`
- **Commits:** Conventional Commits (`feat:`, `fix:`, `refactor:`)
- **NEVER** push directly to `main`
- **CHANGELOG** — update on `feat:`, `fix:`, breaking changes
- **BEFORE COMMIT** — sync memory:

```bash
cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/
# + export Knowledge Graph to .claude/memory/knowledge-graph.json
```

---

## 📁 Project Structure

```text
[Customize for your project]
src/
├── components/    # UI components
├── services/      # Business logic
├── models/        # Data models
└── utils/         # Helper functions
```

---

## ⚡ Essential Commands

```bash
# Development
[command]          # Start dev server

# Testing
[command]          # Run tests

# Code Quality
[command]          # Lint/format

# Build
[command]          # Build for production
```

---

## Security Rules (NEVER VIOLATE!)

1. **Input Validation** — ALWAYS validate user input
2. **SQL Injection** — NEVER concatenate user input into queries
3. **XSS** — NEVER output user data without escaping
4. **Authorization** — ALWAYS check permissions before operations
5. **Secrets** — NEVER hardcode keys and passwords

---

## Visual Self-Testing (Playwright MCP)

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow: navigate to page, check for console errors, interact with changed elements, take screenshots, report findings. If bug found — fix, redeploy, re-test.

Requires Playwright MCP server. Full guide: `components/playwright-self-testing.md`

---

## 🏗️ Architecture Guidelines (STRICT!)

1. **KISS Principle:** Simplest working solution. No premature optimization.
2. **YAGNI:** No features/abstractions "for the future". Solve only current problem.
3. **No Boilerplate:** No Interfaces/Factories/DTOs unless explicitly requested.
4. **File Structure:**
   - Keep logic co-located
   - Prefer larger files over many tiny files
   - **CRITICAL:** Do NOT create new files without asking confirmation first

## 💻 Coding Style

- Functional programming over complex OOP where possible
- If function fits in 50 lines — do NOT split into sub-functions
- One file doing one thing well > 5 files with abstractions

---

## 🎨 Code Style

### Naming Conventions

- **Files:** `kebab-case.ts` or `PascalCase.tsx` for components
- **Variables:** `camelCase`
- **Constants:** `UPPER_SNAKE_CASE`
- **Functions:** `camelCase`, verbs (`createUser`, `validateInput`)

### Best Practices

- Maximum 200 lines per file
- One responsibility per function/class
- Type annotations wherever possible
- Comments for complex logic

---

## 🤖 Available Agents

| Command | Agent | Purpose |
| --------- | ------- | --------- |
| `/agent:code-reviewer` | Code Reviewer | Deep code review |
| `/agent:test-writer` | Test Writer | TDD-style tests |
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

## Scratchpad

For complex tasks use `.claude/scratchpad/`:

- `current-task.md` — current plan with checkboxes
- `findings.md` — research notes
- `decisions.md` — architectural decisions log

---

## Knowledge Persistence (SAVE KNOWLEDGE!)

On **significant changes** — save knowledge to THREE places + sync:

### 1. CLAUDE.md — update this file

- New gotchas and limitations
- Architecture changes
- New patterns and practices

### 2. Documentation — update /docs or README

- API changes
- New features
- Developer instructions

### 3. MCP Memory — save for future sessions

> **IMPORTANT:** All memory entries must be written in English, regardless of conversation language.

**Knowledge Graph** (relationships and architecture):

```text
"Save to knowledge graph: module X depends on Y because of Z"
```

**Memory Bank** (facts and decisions):

```text
"Save to memory-bank: chose Redis because..."
```

### 4. IMMEDIATELY sync memory to git

After MCP changes — **immediately** copy to `.claude/memory/`:

```bash
cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/
```

And export Knowledge Graph to `.claude/memory/knowledge-graph.json`.

**Don't delay — do it right after MCP changes!**

### What to save

- Architectural decisions and their reasons
- Critical gotchas
- Module relationships
- Non-standard solutions

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

## ⚠️ Project-Specific Notes

### Known Gotchas

- [List project-specific issues]

### Public Endpoints (by design)

- `/api/health` — Health check
- `/webhooks/*` — External webhooks
