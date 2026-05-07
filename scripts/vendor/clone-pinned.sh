#!/bin/bash
# scripts/vendor/clone-pinned.sh
#
# Shallow-clones (or fetches) each pinned vendor from manifest.json:vendor_pins
# into _external/<name>/. Idempotent: if dir exists, fetches; else clones.
#
# Usage:
#   scripts/vendor/clone-pinned.sh                       # default paths
#   scripts/vendor/clone-pinned.sh manifest.json _external
#
# Exits:
#   0 — success (all vendors fetched or cloned)
#   1 — manifest read failure
#   2 — at least one vendor fetch failed (others still attempted)
set -euo pipefail

MANIFEST="${1:-manifest.json}"
EXTERNAL_DIR="${2:-_external}"
DEPTH="${VENDOR_CLONE_DEPTH:-200}"

# Color helpers
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; CYAN=''; NC=''
fi

if [[ ! -f "$MANIFEST" ]]; then
    echo -e "${RED}✗${NC} Manifest not found: $MANIFEST" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} jq required but not installed" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} git required but not installed" >&2
    exit 1
fi

mkdir -p "$EXTERNAL_DIR"

# Read vendor names + repos
vendors=$(jq -r '.vendor_pins // {} | to_entries[] | "\(.key)|\(.value.repo)"' "$MANIFEST" 2>/dev/null)
if [[ -z "$vendors" ]]; then
    echo -e "${YELLOW}⚠${NC} No vendor_pins in manifest" >&2
    exit 0
fi

failures=0
total=0
echo -e "${CYAN}Cloning/fetching pinned vendors (depth=$DEPTH)...${NC}"

while IFS='|' read -r name repo; do
    [[ -z "$name" || -z "$repo" || "$repo" == "null" ]] && continue
    total=$((total + 1))
    dir="$EXTERNAL_DIR/$name"

    if [[ -d "$dir/.git" ]]; then
        # Existing clone — fetch
        if (cd "$dir" && git fetch --depth "$DEPTH" origin 2>/dev/null); then
            head_short=$(cd "$dir" && git rev-parse --short HEAD 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓${NC} $name (fetched, HEAD=$head_short)"
        else
            echo -e "  ${YELLOW}⚠${NC} $name fetch failed (using existing copy)"
            failures=$((failures + 1))
        fi
    else
        # Fresh clone
        if git clone --depth "$DEPTH" "$repo" "$dir" 2>/dev/null; then
            head_short=$(cd "$dir" && git rev-parse --short HEAD 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓${NC} $name (cloned, HEAD=$head_short)"
        else
            echo -e "  ${RED}✗${NC} $name clone failed: $repo"
            failures=$((failures + 1))
        fi
    fi
done <<< "$vendors"

echo ""
if [[ $failures -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} All $total vendors ready in $EXTERNAL_DIR/"
    exit 0
else
    echo -e "${YELLOW}⚠${NC} $((total - failures))/$total vendors ready (${failures} failed)"
    exit 2
fi
