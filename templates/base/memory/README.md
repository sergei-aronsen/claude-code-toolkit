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

## Import (on new computer)

### 1. Make sure MCP servers are configured

```bash
claude mcp list
```

### 2. Import memory

Ask Claude:

```text
Import project memory from .claude/memory/:
1. Memory Bank: read .md files → mcp__memory-bank__memory_bank_write
2. Knowledge Graph: read JSON → mcp__memory__create_entities/relations
```

## When to sync

- **Export:** before commits, after adding architectural decisions
- **Import:** when cloning, after pull with memory changes
