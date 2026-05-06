#!/bin/bash
#
# setup-cost-routing.sh
# Install talkstream/better-model + run `npx better-model init` to add the
# model-routing block to ~/.claude/CLAUDE.md.
#
# better-model is the v6.0 cost-routing primitive: it routes Sonnet 4.6
# (60% of tasks), Opus 4.7 (architecture/security), and Haiku 4.5 (search/
# trivial) per slash-command + subagent. Zero deps, MIT, npm-installable.
#
# Usage:
#   bash scripts/setup-cost-routing.sh             # install + init
#   bash scripts/setup-cost-routing.sh --dry-run   # show, don't write
#   bash scripts/setup-cost-routing.sh --uninstall # remove the routing block

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

DRY_RUN=0
UNINSTALL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)
            cat <<EOF
setup-cost-routing.sh — install better-model + write routing block

better-model lives upstream at https://www.npmjs.com/package/better-model
(MIT, zero deps, talkstream/better-model). It writes a routing block into
~/.claude/CLAUDE.md that maps slash commands and subagents to specific
Claude models for cost efficiency.

Options:
  --dry-run    print what would happen
  --uninstall  remove the routing block (keeps better-model installed)
  -h, --help   this help

After install:
  /gsd-fast    → Haiku 4.5  (cheap, search-only)
  /gsd-quick   → Sonnet 4.6 (default working model, 60% of tasks)
  /gsd-plan-phase → Opus 4.7 (architecture, security, multi-file refactor)
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

# ─────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────

if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} node not found — install Node.js 18+ first" >&2
    exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} npx not found — install Node.js 18+ first" >&2
    exit 1
fi

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# ─────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────

if [ "$UNINSTALL" -eq 1 ]; then
    echo -e "${CYAN}Removing better-model routing block from $GLOBAL_CLAUDE_MD${NC}"
    if [ ! -f "$GLOBAL_CLAUDE_MD" ]; then
        echo -e "  ${YELLOW}⚠${NC} $GLOBAL_CLAUDE_MD not found — nothing to remove"
        exit 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${YELLOW}[dry-run]${NC} would strip block between <!-- BETTER-MODEL ROUTING START --> and <!-- BETTER-MODEL ROUTING END -->"
        exit 0
    fi
    BACKUP="${GLOBAL_CLAUDE_MD}.bak.$(date +%s)"
    cp "$GLOBAL_CLAUDE_MD" "$BACKUP"
    # Sed in-place across BSD/GNU: write to tmp + mv
    TMP=$(mktemp "${GLOBAL_CLAUDE_MD}.tmp.XXXXXX")
    awk '
        /<!-- BETTER-MODEL ROUTING START -->/ { skip=1; next }
        /<!-- BETTER-MODEL ROUTING END -->/   { skip=0; next }
        !skip { print }
    ' "$GLOBAL_CLAUDE_MD" > "$TMP"
    mv "$TMP" "$GLOBAL_CLAUDE_MD"
    echo -e "  ${GREEN}✓${NC} Removed routing block (backup: $BACKUP)"
    echo -e "  Note: better-model npm package itself is still installed."
    exit 0
fi

# ─────────────────────────────────────────────────
# Install path
# ─────────────────────────────────────────────────

echo -e "${CYAN}Installing better-model (cost routing for Claude Code)${NC}"
echo "  CLAUDE_DIR: $CLAUDE_DIR"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "  ${YELLOW}[dry-run]${NC} would run: npx better-model init"
    echo -e "  ${YELLOW}[dry-run]${NC} would back up $GLOBAL_CLAUDE_MD before init writes its block"
    exit 0
fi

# better-model init writes a routing block into ~/.claude/CLAUDE.md.
# Back up first so user can revert.
if [ -f "$GLOBAL_CLAUDE_MD" ]; then
    BACKUP="${GLOBAL_CLAUDE_MD}.bak.$(date +%s)"
    cp "$GLOBAL_CLAUDE_MD" "$BACKUP"
    echo -e "  ${GREEN}✓${NC} Backup: $BACKUP"
fi

mkdir -p "$CLAUDE_DIR"

echo -e "  Running: ${CYAN}npx -y better-model init${NC}"
echo ""

if npx -y better-model init; then
    echo ""
    echo -e "  ${GREEN}✓${NC} better-model routing block written to $GLOBAL_CLAUDE_MD"
else
    rc=$?
    echo ""
    echo -e "  ${RED}✗${NC} npx better-model init exited $rc" >&2
    if [ -n "${BACKUP:-}" ] && [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$GLOBAL_CLAUDE_MD"
        echo -e "  ${YELLOW}⚠${NC} Restored CLAUDE.md from backup" >&2
    fi
    exit "$rc"
fi

cat <<EOF

Done.

Routing now active for new Claude Code sessions:
  /gsd-fast        → Haiku 4.5   (cheapest, doc/search/trivial)
  /gsd-quick       → Sonnet 4.6  (default; 60% of work)
  /gsd-plan-phase  → Opus 4.7    (architecture, security, multi-file)

Track cost discipline: ~/.claude/skills/cost-routing-discipline/SKILL.md
Uninstall the routing block: bash scripts/setup-cost-routing.sh --uninstall
EOF
