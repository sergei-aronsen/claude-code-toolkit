# Memory Persistence — Synchronizing Memory with Git

System for saving MCP memory (Memory Bank + Knowledge Graph) to repository for transfer between computers and team collaboration.

## Problem

MCP servers store data **locally**:

- Memory Bank → `~/.claude/memory-bank/` (file-based, persists between sessions)
- Knowledge Graph → **in-memory only** (lost on every restart of Claude Code or MCP server)

When transferring project to another computer or working in a team — Memory Bank files are lost.

**Knowledge Graph has an additional problem:** since it is in-memory only, data is lost not just on a new computer, but on **every restart** of Claude Code. It must be imported from `knowledge-graph.json` at the start of **every session**.

## Solution

Export memory to `.claude/memory/` inside the repository:

```text
.claude/
├── CLAUDE.md
├── memory/                    # ← Memory export for git
│   ├── README.md              # Sync instructions
│   ├── knowledge-graph.json   # Knowledge Graph (entities + relations)
│   ├── project-context.md     # Memory Bank files
│   ├── decisions-log.md
│   └── ...
```

---

## File Structure

### knowledge-graph.json

Export of project entities and relations:

```json
{
  "project": "project-name",
  "exported_at": "2025-01-22",
  "entities": [
    {
      "name": "AuthService",
      "entityType": "Service",
      "observations": [
        "Handles authentication",
        "Uses JWT tokens"
      ]
    }
  ],
  "relations": [
    {
      "from": "AuthService",
      "to": "UserModel",
      "relationType": "uses"
    }
  ]
}
```

### Memory Bank files (markdown)

| File | Content |
|------|---------|
| `project-context.md` | General project context |
| `architecture-notes.md` | Architecture notes |
| `decisions-log.md` | Decision log "why this way" |
| `server-config.md` | Server configurations (if applicable) |
| `integrations.md` | External services and APIs |

---

## Workflow

### At session start — check sync status

#### Memory Bank (file-based, persists automatically)

```bash
# Compare file dates MCP vs git
ls -la ~/.claude/memory-bank/[project]/*.md
ls -la .claude/memory/*.md
```

- **MCP newer than git** → copy: `cp ~/.claude/memory-bank/[project]/*.md .claude/memory/`
- **git newer than MCP** (new computer) → import into MCP via `mcp__memory-bank__memory_bank_write`

#### Knowledge Graph (in-memory, MUST import every session)

```text
# Step 1: Check if graph has data
mcp__memory__read_graph()

# Step 2: If empty — import from file
# Read .claude/memory/knowledge-graph.json, then:
mcp__memory__create_entities(entities: [...all entities from JSON...])
mcp__memory__create_relations(relations: [...all relations from JSON...])

# Step 3: Verify import
mcp__memory__read_graph()
```

> **Note:** Knowledge Graph import is needed at the start of **every session**, not just on a new computer. Memory Bank does not require import — it is file-based and persists automatically.

### After changes in MCP — sync immediately

```bash
# Memory Bank — copy files
cp ~/.claude/memory-bank/[project]/*.md .claude/memory/
```

```text
# Knowledge Graph — export via Claude
# Claude reads mcp__memory__read_graph() and writes to .claude/memory/knowledge-graph.json
Export Knowledge Graph to .claude/memory/knowledge-graph.json
(only entities from this project)
```

### Before commit — mandatory sync

1. Copy Memory Bank files
2. Update knowledge-graph.json
3. Add to commit

---

## Import

### When import is needed

| Server | When to import |
|--------|---------------|
| Memory Bank | Only on new computer / after `git pull` with memory changes |
| Knowledge Graph | **Every session** (in-memory only, always starts empty) |

### 1. Ensure MCP servers are configured

```bash
claude mcp list
# Should have: memory-bank, memory
```

### 2. Import Memory Bank (new computer only)

Memory Bank is file-based and persists automatically. Import is only needed when MCP files are missing or outdated compared to git.

Ask Claude:

```text
Import memory from .claude/memory/ into Memory Bank:
- Read each .md file
- Write via mcp__memory-bank__memory_bank_write (projectName: "[project]")
```

### 3. Import Knowledge Graph (every session)

> **Knowledge Graph is in-memory only.** It starts empty on every session. Always import.

Ask Claude:

```text
Import Knowledge Graph from .claude/memory/knowledge-graph.json:
- Read JSON
- Create entities via mcp__memory__create_entities
- Create relations via mcp__memory__create_relations
- Verify with mcp__memory__read_graph()
```

---

## Automation (optional)

### Pre-commit hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

PROJECT_NAME="your-project"
MEMORY_BANK_PATH="$HOME/.claude/memory-bank/$PROJECT_NAME"

if [ -d "$MEMORY_BANK_PATH" ]; then
    echo "Syncing Memory Bank to git..."
    cp "$MEMORY_BANK_PATH"/*.md .claude/memory/ 2>/dev/null
    git add .claude/memory/*.md
fi
```

### Makefile target

```makefile
sync-memory:
    @echo "Syncing Memory Bank..."
    @cp ~/.claude/memory-bank/$(PROJECT_NAME)/*.md .claude/memory/ 2>/dev/null || true
    @echo "Remember to export Knowledge Graph manually!"
```

---

## Instructions for CLAUDE.md

Add the following sections to your `CLAUDE.md`:

### Section "AT THE START OF EACH SESSION"

1. Check Memory Bank sync:
   - `ls -la ~/.claude/memory-bank/[project]/*.md`
   - `ls -la .claude/memory/*.md`
   - MCP newer than git → copy to `.claude/memory/`
   - git newer than MCP → import into MCP

2. Read Memory Bank:
   - `mcp__memory-bank__memory_bank_read(projectName, fileName)`

3. Import Knowledge Graph (required **every session** — in-memory only):
   - `mcp__memory__read_graph()` — check if empty
   - If empty → read `.claude/memory/knowledge-graph.json`
   - `mcp__memory__create_entities(entities)` + `mcp__memory__create_relations(relations)`
   - `mcp__memory__read_graph()` — verify import

### Section "BEFORE COMMIT"

1. Sync Memory Bank: `cp ~/.claude/memory-bank/[project]/*.md .claude/memory/`
2. Export Knowledge Graph to `.claude/memory/knowledge-graph.json`

See templates in `templates/*/CLAUDE.md` for ready examples.

---

## What to Store in Memory

### Memory Bank (facts)

- Project context (stack, architecture)
- Architectural decisions and their reasons
- Server configurations
- Integrations with external services
- Gotchas and known issues

### Knowledge Graph (relations)

- Project entities (Services, Jobs, Models)
- Relations between components (uses, depends_on, calls)
- Infrastructure dependencies
- Integrations

---

## Best Practices

1. **Sync immediately** — don't postpone
2. **Filter by project** — Knowledge Graph may contain data from other projects
3. **Check at session start** — to avoid working with stale memory
4. **Document decisions** — write "why", not just "what"
5. **Commit memory** — together with code, not separately
6. **Write in English** — all memory entries (entities, observations, decisions, notes) must be written in English, regardless of the conversation language
