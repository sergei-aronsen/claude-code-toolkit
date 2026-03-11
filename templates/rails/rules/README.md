# Rules Directory

Files in `.claude/rules/` are **auto-loaded** into every Claude Code session.

## How It Works

- Files with `globs: ["**/*"]` in frontmatter are loaded for ALL files
- Files with specific globs (e.g., `globs: ["lang/**"]`) are loaded only when working with matching files
- No manual reads needed — Claude always has this context

## Recommended Structure

| File | Purpose |
|------|---------|
| `project-context.md` | Core project facts (always loaded) |
| `[domain].md` | Domain-specific rules with `paths:` scope |

## Adding Path-Scoped Rules

Use `globs:` frontmatter to scope rules to specific files:

```yaml
---
description: i18n rules for translations
globs:
  - "lang/**"
  - "resources/js/**"
---
```

This rule file will only be loaded when Claude touches files matching those globs.

## Migration from MCP Memory

If you previously used MCP Memory Bank or Knowledge Graph:

1. Move operational facts to `.claude/rules/project-context.md`
2. Move large reference docs to `.claude/docs/`
3. Delete `.claude/memory/` directory
4. Remove deprecated MCP servers: `claude mcp remove memory-bank && claude mcp remove memory`

See `components/memory-persistence.md` for the full migration guide.
