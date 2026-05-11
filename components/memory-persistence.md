# Knowledge Persistence — Native .claude/rules/ System

System for maintaining project knowledge across sessions using Claude Code's built-in rules mechanism.

## Why Native Files, Not MCP Memory Servers

MCP Memory Bank and Knowledge Graph are **deprecated** in this toolkit. Native `.claude/rules/` is the industry standard for AI coding agents because:

| Native files (.claude/rules/) | MCP Memory Servers |
|-------------------------------|-------------------|
| Auto-loaded every session (deterministic) | Agent must call tool (often forgets) |
| Git-tracked (branch = context) | Separate from git (state drift) |
| Human-readable (open file, edit) | Black box (hard to find/fix bad facts) |
| Zero token overhead | Tool descriptions + calls consume tokens |
| Zero infrastructure | Node.js processes, databases |
| Path-scoped via `globs:` | No file-aware routing |
| Survives /compact (re-read from disk) | Lost when context resets |

> **When MCP memory IS justified:** 1M+ line monorepos, multi-agent shared memory, semantic search over hundreds of decisions. For 95% of projects — native files win.

---

## Architecture

```text
.claude/
├── CLAUDE.md              # Workflow rules (auto-loaded, < 200 lines)
├── rules/                 # Project facts (auto-loaded)
│   ├── project-context.md # Core facts — servers, architecture, services
│   ├── [domain].md        # Domain-specific rules (path-scoped)
│   └── lessons-learned.md # Audit log from /learn (globs: [], NOT auto-loaded)
└── docs/                  # Reference docs (read on demand)
    ├── integrations.md
    └── decisions-log.md
```

---

## Tiered Architecture

### Tier 1: Always Auto-Loaded

| File | Purpose |
|------|---------|
| `.claude/CLAUDE.md` | Workflow rules, git conventions, security |
| `.claude/rules/project-context.md` | Core project facts (servers, architecture, services) |
| `.claude/rules/[domain].md` | Domain rules with `globs:` scope |

### Tier 1b: Path-Scoped (loaded when touching matching files)

| File | Loaded when | Example globs |
|------|-------------|---------------|
| `rules/typescript.md` | Editing `.ts`/`.tsx` files | `["**/*.ts", "**/*.tsx"]` |
| `rules/database.md` | Editing models/migrations | `["models/**", "prisma/**"]` |
| `rules/api.md` | Editing API routes | `["api/**", "routes/**"]` |

### Tier 2: On-Demand Reference

| File | Purpose |
|------|---------|
| `.claude/docs/integrations.md` | External services reference |
| `.claude/docs/decisions-log.md` | Historical decisions and rationale |
| `.claude/docs/[topic].md` | Deep reference material |

### Audit Trail (not auto-loaded)

| File | Purpose |
|------|---------|
| `.claude/rules/lessons-learned.md` | History of all lessons (`globs: []`) |

---

## Path-Scoped Rules

Use `globs:` frontmatter to load rules only when touching matching files:

```yaml
---
description: i18n rules for translations
globs:
  - "lang/**"
  - "resources/js/**"
---
```

Examples:

- `typescript.md` with `globs: ["**/*.ts"]` — loaded when editing TypeScript
- `database.md` with `globs: ["models/**", "prisma/**"]` — loaded when editing ORM code
- `testing.md` with `globs: ["tests/**", "**/*.test.*"]` — loaded when editing tests

---

## What to Store Where

### rules/ (auto-loaded, keep concise)

- Server IPs, architecture overview
- Key patterns and conventions
- Active issues and recent changes
- Domain-specific gotchas (per file type via globs)

### docs/ (on-demand, can be detailed)

- Full API reference for integrations
- Historical decision log
- Detailed server configuration
- Parsing/pipeline guides

### CLAUDE.md (workflow only)

- Git conventions
- Deploy procedures
- Security rules
- Plan mode instructions

---

## How /learn Creates Scoped Rules

The `/learn` command writes targeted rule files with narrow `globs:`:

```text
/learn prisma connection pooling fix
  → creates/updates .claude/rules/database.md (globs: ["models/**", "prisma/**"])
  → appends audit line to .claude/rules/lessons-learned.md
```

This ensures lessons are loaded **only when relevant**, not every session.

---

## Migration from MCP Memory Bank

If you previously used MCP Memory Bank or Knowledge Graph:

### 1. Create directories

```bash
mkdir -p .claude/rules .claude/docs
```

### 2. Move operational facts

Take key facts from MCP memory and write to `.claude/rules/project-context.md`:

```yaml
---
description: Core project facts
globs:
  - "**/*"
---
```

### 3. Move reference docs

```bash
mv .claude/memory/integrations.md .claude/docs/
mv .claude/memory/decisions-log.md .claude/docs/
```

### 4. Remove old memory

```bash
rm -rf .claude/memory/
```

### 5. Remove deprecated MCP servers

```bash
claude mcp remove memory-bank
claude mcp remove memory
```

### 6. Clean up CLAUDE.md

Remove "AT THE START OF EACH SESSION" MCP sync steps and "BEFORE COMMIT" memory sync commands.

---

## Two Layers — Project Rules vs Harness Auto-Memory

Claude Code exposes **two parallel memory stores**. They are NOT synchronized. Knowing which is which prevents stale-fact bugs.

| | `.claude/rules/*.md` (project rules) | `~/.claude/projects/<encoded-cwd>/memory/MEMORY.md` (auto-memory) |
|---|---|---|
| **Location** | Inside repo | User home, per-project subfolder |
| **Git-tracked** | Yes | No (local-only state) |
| **Who writes** | You + `/learn` + manual edits | Claude Code itself, autonomously |
| **Who reads** | Auto-loader at session start (via `globs:`) | Harness injects `MEMORY.md` into every turn |
| **Origin** | Toolkit (`templates/base/rules/`) | Built-in Claude Code feature |
| **Programmable** | Yes — format, scope, content under your control | Indirect — only via instructions in `~/.claude/CLAUDE.md` |
| **Lifecycle** | Lives until you delete or edit the file | Overwritten autonomously when model decides |

### Why conflict happens

When a fact changes (e.g., migration from R2 to Redis-via-SSH on 2026-03-23):

- Auto-memory updates automatically — model notices the change and rewrites the entry
- `.claude/rules/memory.md` stays stale — no manual edit, no `/learn` run

Next session loads **both** layers. If Claude does not reconcile dates, the stale fact from `rules/` wins by accident and gets quoted back to you as current.

### Conflict resolution protocol

When the two layers disagree on a fact:

1. Read the relevant `.claude/rules/*.md` (git-tracked source of truth)
2. Read `MEMORY.md` auto-memory entries on the same topic
3. **Default precedence — `.claude/rules/` wins** (git-tracked, human-managed)
4. If auto-memory is demonstrably newer (has a later dated event, references a real merged PR):
   - Update `.claude/rules/*.md` with the new fact
   - Commit the change (`feat: update rules/X — fact superseded by Y`)
   - Auto-memory will re-converge on next write
5. If `.claude/rules/` is newer (recent commit, audit entry):
   - Note the discrepancy to the user — the next auto-memory write will overwrite the stale entry; no manual intervention needed
6. Never silently quote the older layer — always disclose the conflict

Add this protocol to your project's `.claude/CLAUDE.md` (Knowledge Persistence section) if your team relies on auto-memory.

---

## Security

**NEVER store credentials in `.claude/rules/` or `.claude/docs/`** — these are git-tracked.

Use `.env` references instead:

```markdown
Credentials in `.env` — see `DATABASE_*`, `API_KEY_*` variables.
```

---

## Best Practices

1. **Keep rules/ concise** — auto-loaded into every session, affects context budget
2. **Use path-scoped globs** — narrowest scope wins, avoid `globs: ["**/*"]` where possible
3. **Separate facts from reference** — rules/ for quick facts, docs/ for deep dives
4. **One rule file per domain** — not per lesson (avoid file explosion)
5. **Update immediately** — when facts change, update rules/ right away
6. **No credentials in git** — only `.env` variable names, never values
7. **Write in English** — all rules, docs, and public GitHub content (PR titles/bodies, issue comments, code reviews, release notes) in English regardless of conversation language; chat replies and `.planning/` artifacts can stay in the user's preferred language
