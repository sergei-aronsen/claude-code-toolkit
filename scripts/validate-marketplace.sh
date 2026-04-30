#!/bin/bash
#
# validate-marketplace.sh — MKT-03
# Wraps `claude plugin marketplace add ./` smoke against the local repo.
# Gated by TK_HAS_CLAUDE_CLI=1 because CI runners do not ship `claude`.
# When the env-var is unset, this script prints a [skipped] notice and exits 0
# so it can be a member of `make check` without breaking CI.
#
# Usage:
#   TK_HAS_CLAUDE_CLI=1 bash scripts/validate-marketplace.sh   # full smoke
#   bash scripts/validate-marketplace.sh                       # skip (CI default)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "${TK_HAS_CLAUDE_CLI:-0}" != "1" ]; then
    echo -e "${YELLOW}[skipped]${NC} validate-marketplace: TK_HAS_CLAUDE_CLI not set"
    echo "  Set TK_HAS_CLAUDE_CLI=1 and ensure 'claude' is on PATH to run the smoke."
    exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} TK_HAS_CLAUDE_CLI=1 but 'claude' not found on PATH" >&2
    exit 1
fi

if [ ! -f ".claude-plugin/marketplace.json" ]; then
    echo -e "${RED}Error:${NC} .claude-plugin/marketplace.json not found at $(pwd)" >&2
    echo "  Run from repo root (where .claude-plugin/ lives)." >&2
    exit 1
fi

# Validate marketplace JSON before invoking claude (catch schema breaks early).
if ! python3 -c "import json,sys; json.load(open('.claude-plugin/marketplace.json'))" >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} .claude-plugin/marketplace.json is not valid JSON" >&2
    exit 1
fi

echo -e "${BLUE}Validating marketplace via claude CLI...${NC}"
echo ""

# Audit L12: predictable /tmp/tk-marketplace-out.$$ is symlink-attackable on
# shared hosts. Use mktemp for an O_EXCL-secured per-run path.
TMPOUT=$(mktemp -t tk-marketplace.XXXXXX)
trap 'rm -f "$TMPOUT"' EXIT

# Smoke: add the marketplace from the local repo. The CLI prints discovered plugins.
if ! claude plugin marketplace add ./ 2>&1 | tee "$TMPOUT"; then
    echo -e "${RED}✗${NC} claude plugin marketplace add ./ failed"
    exit 1
fi

# Assert all 3 sub-plugins are mentioned in the CLI output.
MISSING=0
for plugin in tk-skills tk-commands tk-framework-rules; do
    if ! grep -qF "$plugin" "$TMPOUT"; then
        echo -e "${RED}✗${NC} sub-plugin not discovered by CLI: $plugin"
        MISSING=$((MISSING + 1))
    fi
done
# trap EXIT removes $TMPOUT (Audit L12)

if [ "$MISSING" -gt 0 ]; then
    echo -e "${RED}✗${NC} $MISSING sub-plugin(s) missing from marketplace add output"
    exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} MKT-03 smoke green: 3 sub-plugins discovered"
exit 0
