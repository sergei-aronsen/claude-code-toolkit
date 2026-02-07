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
4. **Git:** Conventional Commits, DO NOT push to main directly, RUN LINTERS before commit
5. **Language:** ALL code comments, commit messages, and docs in English only
6. **Directory:** STAY in current working directory, DO NOT cd to parent/sibling folders
7. **User-Agent:** NEVER use default library UA, ALWAYS set real browser User-Agent

---

## AT THE START OF EACH SESSION

### 0. Verify working directory (CRITICAL for worktrees)

```bash
pwd
git rev-parse --show-toplevel
```

**Lock this directory for the entire session.** Do NOT `cd` to parent folders, sibling worktrees, or the main repository. All file operations must stay within this directory.

If using worktrees (`lantern-1`, `lantern-2`, etc.) — each session must stay in its own worktree folder.

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

### 4. Load additional files if needed

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
- **PARALLEL SESSIONS** — user may run multiple Claude sessions simultaneously. If you see commits you didn't make, that's normal — another session made them. Always `git pull` before commit/push. **Before build/deploy: `git fetch origin main && git merge origin/main`** to include changes from other sessions.
- **BEFORE COMMIT** — run linters, pull latest, sync memory:

```bash
# Run project linters (adjust command for your project)
npm run lint   # or: make check / pnpm lint / etc.

# Pull latest changes (parallel sessions may have pushed)
git pull --rebase

# Sync memory
cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/
# + export Knowledge Graph to .claude/memory/knowledge-graph.json
```

### Git Worktree Workflow (Parallel Sessions)

> **If multiple Claude sessions work on same repo, use git worktrees to avoid conflicts.**

**At session start — detect worktree:**

```bash
git branch --show-current
```

- If branch is `work-1`, `work-2`, `work-3`, `work-4` → you're in a worktree
- If branch is `main` → you're in main repo

**⚠️ NEVER run destructive git commands without asking!**

Before `git reset --hard`, `git checkout .`, `git clean -f`, `git rebase`, `git stash`:

1. Run `git status` — check for uncommitted changes
2. If changes exist — **STOP and ASK USER**
3. Show what will be lost with `git diff`

**⚠️ NEVER do `git stash && git rebase && git stash pop` automatically!**

- Stash pop conflicts = changes stuck in stash
- Always commit first, then rebase (or use merge)

**⚠️ NEVER resolve merge conflicts automatically!**

- If you see `CONFLICT` — STOP and ask user
- Don't use `--theirs` or `--ours` without permission

**⚠️ Before EVERY push to main** — fetch and merge to avoid overwriting other sessions:

```bash
git fetch origin main
git merge origin/main
# If CONFLICT — STOP and ask user!
git push origin main
```

**Working in worktree (work-1, work-2, etc.):**

1. **Before starting** — check status then sync with main:

   ```bash
   git status  # CRITICAL: check for uncommitted changes first!
   # If changes exist — ask user before proceeding!
   git fetch origin main && git reset --hard origin/main
   ```

2. **Work normally** — make changes, test

3. **When complete** — merge to main:

   ```bash
   git add <files> && git commit -m "feat: ..."
   git checkout main && git merge work-X --no-edit && git push origin main
   git checkout work-X
   git status  # Check before reset!
   git reset --hard origin/main
   ```

Full guide: `components/git-worktrees-guide.md`

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
6. **User-Agent** — NEVER use default/library User-Agent for HTTP requests. ALWAYS set a real browser UA:
   `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36`

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
- **NEVER** batch-restart all workers — use rolling restarts
- Verify after every deploy: endpoints, logs, workers

### File Targeting

- Before editing, confirm **correct file variant** (V2, legacy, etc.)
- Confirm correct branch/worktree with `pwd` and `git branch`
- Check if already fixed upstream: `git log origin/main --oneline -5`

Full guide: `components/production-safety.md`

---

## Visual Self-Testing (Playwright MCP)

**After ANY visual/UI change, self-test using Playwright MCP before reporting completion.**

Workflow: navigate to page, check for console errors, interact with changed elements, take screenshots, report findings. If bug found — fix, redeploy, re-test.

**IMPORTANT: Always call `browser_close` after finishing tests.** Multiple Claude sessions share the same Playwright browser profile. Leaving the browser open will block other sessions from launching it.

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
- **All code comments, commit messages, and documentation in English** regardless of conversation language

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
| `/deploy` | Safe deployment with pre/post checks |
| `/fix-prod` | Production hotfix workflow |
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
| `i18n` | When adding multilanguage support, translations, localization |

Load: `Read .claude/skills/{skill-name}/SKILL.md`

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
