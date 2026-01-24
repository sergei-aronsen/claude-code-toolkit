#!/bin/bash

# Claude Guides Update Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/digitalplanetno/claude-guides/main"
CLAUDE_DIR=".claude"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Guides Update               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

if [[ ! -d "$CLAUDE_DIR" ]]; then
    echo -e "${RED}Error: $CLAUDE_DIR not found. Run init-claude.sh first${NC}"
    exit 1
fi

# Backup
BACKUP_DIR=".claude-backup-$(date +%Y%m%d-%H%M%S)"
cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
echo -e "${GREEN}✓${NC} Backup: $BACKUP_DIR"

# Update agents and commands (safe to update)
for file in agents/code-reviewer.md agents/test-writer.md agents/planner.md \
            commands/plan.md commands/tdd.md commands/audit.md; do
    curl -sSL "$REPO_URL/templates/base/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null && \
        echo -e "${GREEN}✓${NC} Updated: $file" || \
        echo -e "${YELLOW}⚠${NC} Skipped: $file"
done

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo -e "${YELLOW}Note:${NC} CLAUDE.md and settings.json preserved (customize manually)"
