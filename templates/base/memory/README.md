# Memory Sync

This directory contains MCP memory export for synchronization between computers.

## Files

| File | Description |
|------|----------|
| `knowledge-graph.json` | Project entities and relations (Knowledge Graph) |
| `project-context.md` | General project context (Memory Bank) |
| `decisions-log.md` | Architectural decisions |
| `*.md` | Other Memory Bank files |

## Export (before commit)

### Memory Bank

```bash
cp ~/.claude/memory-bank/[PROJECT_NAME]/*.md .claude/memory/
```

### Knowledge Graph

Ask Claude:

```text
Export Knowledge Graph to .claude/memory/knowledge-graph.json
(only entities of this project)
```

## Import

### Memory Bank (new computer only)

Memory Bank is file-based and persists automatically. Import only when MCP files are missing.

```text
Read .md files from .claude/memory/ → mcp__memory-bank__memory_bank_write
```

### Knowledge Graph (EVERY session)

> **Knowledge Graph is in-memory only — data is lost on every restart of Claude Code.**

```text
# 1. Check if graph is empty
mcp__memory__read_graph()

# 2. If empty — import from knowledge-graph.json:
mcp__memory__create_entities(entities: [...from JSON...])
mcp__memory__create_relations(relations: [...from JSON...])
```

## When to sync

- **Export:** before commits, after adding architectural decisions
- **Import Memory Bank:** when cloning, after pull with memory changes
- **Import Knowledge Graph:** at the start of every session (always starts empty)
