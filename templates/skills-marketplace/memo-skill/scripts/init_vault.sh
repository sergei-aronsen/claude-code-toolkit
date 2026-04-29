#!/usr/bin/env bash
# Initialize the engineering-brain Obsidian vault.
# Usage: bash init_vault.sh [/path/to/vault]

set -euo pipefail

VAULT_PATH="${1:-$HOME/engineering-brain}"

echo "═══════════════════════════════════════════════"
echo "  Initializing Engineering Brain vault"
echo "  Path: $VAULT_PATH"
echo "═══════════════════════════════════════════════"

# Create directory structure — engineering zone
mkdir -p "$VAULT_PATH"/{decisions,patterns,debug-logs,insights,tools,references,projects,daily-logs,.obsidian,.memo}

# Create directory structure — personal zone
mkdir -p "$VAULT_PATH"/{health,learning,ideas,life}

# .gitignore
if [ ! -f "$VAULT_PATH/.gitignore" ]; then
cat > "$VAULT_PATH/.gitignore" << 'EOF'
.memo/
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
EOF
echo "  ✓ .gitignore"
fi

# INDEX.md
if [ ! -f "$VAULT_PATH/INDEX.md" ]; then
cat > "$VAULT_PATH/INDEX.md" << 'EOF'
# Engineering Brain — Knowledge Index

Chronological index of all notes in this vault.
Engineering + personal — one brain, one vault.

Use `Ctrl/Cmd + O` in Obsidian to quick-open any note.
Use Graph View to explore connections.

---

EOF
echo "  ✓ INDEX.md"
fi

# Obsidian app config
if [ ! -f "$VAULT_PATH/.obsidian/app.json" ]; then
cat > "$VAULT_PATH/.obsidian/app.json" << 'EOF'
{
  "strictLineBreaks": false,
  "showFrontmatter": true,
  "livePreview": true,
  "foldHeading": true,
  "readableLineLength": true,
  "baseFontSize": 16
}
EOF
echo "  ✓ .obsidian/app.json"
fi

# Obsidian graph view — color-coded by note type
if [ ! -f "$VAULT_PATH/.obsidian/graph.json" ]; then
cat > "$VAULT_PATH/.obsidian/graph.json" << 'EOF'
{
  "collapse-filter": false,
  "search": "",
  "showTags": true,
  "showAttachments": false,
  "hideUnresolved": false,
  "showOrphans": true,
  "collapse-color-groups": false,
  "colorGroups": [
    {"query": "path:decisions",  "color": {"a": 1, "rgb": 14701138}},
    {"query": "path:patterns",   "color": {"a": 1, "rgb": 5431378}},
    {"query": "path:debug-logs", "color": {"a": 1, "rgb": 16744448}},
    {"query": "path:insights",   "color": {"a": 1, "rgb": 8689326}},
    {"query": "path:tools",      "color": {"a": 1, "rgb": 2201331}},
    {"query": "path:references", "color": {"a": 1, "rgb": 10066329}},
    {"query": "path:projects",   "color": {"a": 1, "rgb": 16761095}},
    {"query": "path:health",     "color": {"a": 1, "rgb": 3394611}},
    {"query": "path:learning",   "color": {"a": 1, "rgb": 8956346}},
    {"query": "path:ideas",      "color": {"a": 1, "rgb": 15634216}},
    {"query": "path:life",       "color": {"a": 1, "rgb": 13395558}}
  ],
  "collapse-display": false,
  "showArrow": true,
  "textFadeMultiplier": 0,
  "nodeSizeMultiplier": 1,
  "lineSizeMultiplier": 1,
  "collapse-forces": true,
  "centerStrength": 0.5,
  "repelStrength": 10,
  "linkStrength": 1,
  "linkDistance": 250
}
EOF
echo "  ✓ .obsidian/graph.json (color-coded)"
fi

# Welcome note
TODAY=$(date +%Y-%m-%d)
WELCOME="$VAULT_PATH/insights/${TODAY}-vault-initialized.md"
if [ ! -f "$WELCOME" ]; then
cat > "$WELCOME" << EOF
---
type: insight
created: ${TODAY}
updated: ${TODAY}
project: engineering-brain
tags:
  - meta
  - setup
aliases:
  - vault setup
  - engineering brain init
---

# Engineering Brain — Vault Initialized

## Context

Setting up a persistent engineering knowledge base with semantic search
for use across all projects and Claude Code sessions.

## Decision / Solution / Pattern

### Structure

| Folder | Purpose |
|--------|---------|
| \`decisions/\` | Architecture choices, tech stack picks, tradeoffs |
| \`patterns/\` | Reusable code patterns and approaches |
| \`debug-logs/\` | Bug fixes, error solutions, workarounds |
| \`insights/\` | Learnings, observations, discoveries |
| \`tools/\` | Tool configs, CLI commands, setup procedures |
| \`references/\` | External knowledge, article summaries |
| \`projects/\` | Project overviews and status snapshots |
| \`health/\` | Sport, health, productivity notes |
| \`learning/\` | Books, courses, languages, self-development |
| \`ideas/\` | Business ideas, hobbies, "what if..." |
| \`life/\` | Family, goals, travel, personal planning |

### How It Works

- Every note is atomic (one idea per file) with YAML frontmatter
- Notes link via \`[[wikilinks]]\` — Obsidian Graph View shows connections
- \`.memo/index.db\` provides semantic search via embeddings
- Use \`/memo\` in Claude Code to save, \`/memo find\` to search
- \`/memo reindex\` rebuilds the search index from scratch

### Key Commands

- \`/memo\` — save a new note
- \`/memo find {query}\` — semantic + keyword search
- \`/memo query {question}\` — AI-powered answer from vault
- \`/memo list\` — recent notes
- \`/memo lint\` — vault health check (7 checks)
- \`/memo dedup\` — find potential duplicates
- \`/memo stats\` — vault statistics
- \`/memo trace {concept}\` — evolution of an idea over time
- \`/memo project\` — create/update project overview
- \`/memo reindex\` — rebuild search index
- \`/memo obsidian-info\` — Obsidian CLI status

## Related

(This is the first note — links will grow as the vault fills up.)
EOF
echo "  ✓ Welcome note"

# Add to index
echo "- [${TODAY}] [[insights/${TODAY}-vault-initialized]] — Vault initialized" >> "$VAULT_PATH/INDEX.md"
fi

# Initialize git if not already
if [ ! -d "$VAULT_PATH/.git" ]; then
    cd "$VAULT_PATH"
    git init -q
    git add -A
    git commit -q -m "Initialize engineering-brain vault"
    echo "  ✓ Git repository initialized"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Vault ready at: $VAULT_PATH"
echo ""
echo "  Next steps:"
echo "  1. Open this folder in Obsidian"
echo "  2. pip install sentence-transformers"
echo "  3. python scripts/memo_engine.py warm-up"
echo "  4. bash scripts/setup_automation.sh $VAULT_PATH"
echo "  5. Add hooks to Claude Code (see AUTO_MEMO_SETUP.md)"
echo "  6. git remote add origin <your-repo> (for backup)"
echo "═══════════════════════════════════════════════"
