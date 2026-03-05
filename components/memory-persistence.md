# Knowledge Persistence — Using .claude/rules/ for Auto-Loaded Context

System for maintaining project knowledge across sessions using Claude Code's built-in rules system.

## The Old Way (MCP Memory Bank)

Previously, project context was stored in MCP servers (Memory Bank, Knowledge Graph) and manually synced to `.claude/memory/`. This required:

- Manual MCP reads at session start
- Manual sync before commits
- Knowledge Graph re-import every session (in-memory only)
- 3-way sync between MCP, git, and auto-memory

**Problems:** Sync was often skipped, leading to stale context. Knowledge Graph was lost on every restart.

## The New Way (.claude/rules/)

Claude Code **auto-loads** all `.md` files from `.claude/rules/` into every session. No manual reads needed.

```text
.claude/
├── CLAUDE.md              # Workflow rules (auto-loaded)
├── rules/                 # Project facts (auto-loaded)
│   ├── project-context.md # Core facts — servers, architecture, services
│   └── [domain].md        # Domain-specific rules (path-scoped)
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

### Tier 2: On-Demand Reference

| File | Purpose |
|------|---------|
| `.claude/docs/integrations.md` | External services reference |
| `.claude/docs/decisions-log.md` | Historical decisions and rationale |
| `.claude/docs/[topic].md` | Deep reference material |

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

- `i18n.md` — loaded when editing `lang/` or `resources/js/`
- `go-crawler.md` — loaded when editing `tools/crawler/`
- `playwright.md` — loaded when editing screenshot-related files

---

## What to Store Where

### rules/ (auto-loaded, keep concise)

- Server IPs, architecture overview
- Key patterns and conventions
- Active issues and recent changes
- Queue/worker configuration
- Proxy setup summary

### docs/ (on-demand, can be detailed)

- Full API reference for integrations
- Historical decision log
- Detailed server configuration
- Parsing/pipeline guides
- Worker configuration details

### CLAUDE.md (workflow only)

- Git conventions
- Deploy procedures
- Security rules
- Plan mode instructions

---

## Migration from MCP Memory Bank

### 1. Create rules/ directory

```bash
mkdir -p .claude/rules .claude/docs
```

### 2. Move operational facts

Take key facts from your MCP memory bank files and consolidate into `.claude/rules/project-context.md`:

```yaml
---
description: Core project facts
globs:
  - "**/*"
---
```

### 3. Move reference docs

Move detailed reference material to `.claude/docs/`:

```bash
# If you had these in .claude/memory/:
mv .claude/memory/integrations.md .claude/docs/
mv .claude/memory/decisions-log.md .claude/docs/
mv .claude/memory/server-config.md .claude/docs/
```

### 4. Remove old memory

```bash
rm -rf .claude/memory/
```

### 5. Remove MCP servers (optional)

Memory Bank and Knowledge Graph MCP servers are no longer needed. You can remove them:

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
2. **Use path-scoped globs** — domain-specific rules load only when relevant
3. **Separate facts from reference** — rules/ for quick facts, docs/ for deep dives
4. **Update immediately** — when facts change, update rules/ right away
5. **No credentials in git** — only `.env` variable names, never values
6. **Write in English** — all rules and docs in English regardless of conversation language
