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
7. **Write in English** — all rules and docs in English regardless of conversation language
