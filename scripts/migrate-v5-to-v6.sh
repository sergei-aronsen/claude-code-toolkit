#!/bin/bash
#
# migrate-v5-to-v6.sh
# Convenience wrapper for v5.x → v6.0 migration.
#
# v6.0 deleted ~28k LOC of duplication with GSD/Superpowers (PR 1) and
# trimmed framework templates by another 8.7k LOC (PR 4). The standard
# `/update-toolkit` flow already handles deletes via manifest diff, but
# this script adds a v6-specific pre-flight checklist + post-update hint
# for the new opt-in installers (advisory hooks + cost routing).
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/migrate-v5-to-v6.sh)
#   bash scripts/migrate-v5-to-v6.sh --dry-run

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

REPO_URL="${TK_REPO_URL:-https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main}"
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"

DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            cat <<EOF
migrate-v5-to-v6.sh — guided v5.x → v6.0 migration.

What it does:
  1. Verifies you have a project-level .claude/ install
  2. Reads .claude/.toolkit-version (or manifest path) to confirm baseline
  3. Runs scripts/update-claude.sh to refresh files (handles deletes)
  4. Optionally invokes scripts/migrate-to-complement.sh if SP/GSD detected
  5. Prints opt-in install hints for new v6 features (hooks, cost-routing)

Options:
  --dry-run    show what would happen, write nothing
  -h, --help   show this help
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} unknown arg: $1" >&2
            exit 2
            ;;
    esac
    shift
done

CLAUDE_DIR=".claude"
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${RED}Error:${NC} no .claude/ directory in $(pwd)" >&2
    echo -e "  Run from your project root after installing the toolkit." >&2
    exit 1
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Toolkit v5.x → v6.0 Migration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect installed version (best-effort — may be missing on old installs)
INSTALLED_VERSION="unknown"
if [ -f "$CLAUDE_DIR/toolkit-install.json" ] && command -v jq >/dev/null 2>&1; then
    INSTALLED_VERSION=$(jq -r '.toolkit_version // .version // "unknown"' "$CLAUDE_DIR/toolkit-install.json" 2>/dev/null || echo "unknown")
fi
echo -e "  Currently installed: ${YELLOW}$INSTALLED_VERSION${NC}"
echo -e "  Migrating to:        ${GREEN}6.0.0${NC}"
echo ""

# Step 1: standard update (handles deletes via manifest diff)
echo -e "${CYAN}Step 1/3: Refresh toolkit files (will delete v5-only files)${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "  ${YELLOW}[dry-run]${NC} would run: bash <(curl -sSL $REPO_URL/scripts/update-claude.sh) --dry-run"
else
    if ! bash <(curl -sSL -A "$TK_USER_AGENT" "$REPO_URL/scripts/update-claude.sh"); then
        echo -e "  ${RED}✗${NC} update-claude.sh failed — aborting migration" >&2
        exit 1
    fi
fi
echo ""

# Step 2: complement-mode migration if SP/GSD detected
echo -e "${CYAN}Step 2/3: Complement-mode migration (if SP/GSD installed)${NC}"
SP_PRESENT=0
GSD_PRESENT=0
[ -d "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers" ] && SP_PRESENT=1
[ -d "$HOME/.claude/plugins/cache/gsd-build" ] && GSD_PRESENT=1
[ -d "$HOME/.claude/plugins/cache/get-shit-done" ] && GSD_PRESENT=1

if [ "$SP_PRESENT" -eq 1 ] || [ "$GSD_PRESENT" -eq 1 ]; then
    echo -e "  Detected: SP=$SP_PRESENT, GSD=$GSD_PRESENT"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${YELLOW}[dry-run]${NC} would run: bash $REPO_URL/scripts/migrate-to-complement.sh"
    else
        echo -e "  Running migrate-to-complement.sh (per-file confirm + backup)..."
        bash <(curl -sSL -A "$TK_USER_AGENT" "$REPO_URL/scripts/migrate-to-complement.sh") || {
            echo -e "  ${YELLOW}⚠${NC} migrate-to-complement.sh declined or aborted — continuing"
        }
    fi
else
    echo -e "  ${YELLOW}⊘${NC} SP/GSD not detected — skipping complement migration"
fi
echo ""

# Step 3: post-migration hints
echo -e "${CYAN}Step 3/3: New v6.0 opt-in features${NC}"
echo ""
echo -e "${YELLOW}🪝 Advisory Hooks${NC} — never blocks; reminds /council, /audit,"
echo -e "  reality-check, cost-warning at the right phase."
echo -e "  ${CYAN}bash <(curl -sSL $REPO_URL/scripts/install-hooks.sh)${NC}"
echo ""
echo -e "${YELLOW}💰 Cost Routing${NC} — Sonnet 4.6 / Opus 4.7 / Haiku 4.5 per command."
echo -e "  Cuts ~50% off blended cost. Powered by talkstream/better-model."
echo -e "  ${CYAN}bash <(curl -sSL $REPO_URL/scripts/setup-cost-routing.sh)${NC}"
echo ""

cat <<EOF

${GREEN}✓ Migration to v6.0.0 complete${NC}

Read about the new architecture: ${CYAN}docs/architecture.md${NC}
Recommended setup for solo founders: ${CYAN}docs/non-programmer-mode.md${NC}
Full release notes: ${CYAN}https://github.com/sergei-aronsen/claude-code-toolkit/releases/tag/v6.0.0${NC}
EOF
