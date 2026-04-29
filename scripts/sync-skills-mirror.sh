#!/bin/bash
# Claude Code Toolkit — Skills Mirror Sync (Maintainer Tool)
#
# Re-syncs templates/skills-marketplace/<name>/ from the local user's
# ~/.claude/skills/<name>/ source-of-truth. Run manually before committing
# a new mirror snapshot. NOT wired into install path or CI.
#
# Usage:
#   bash scripts/sync-skills-mirror.sh             # sync all 22 catalog skills
#   bash scripts/sync-skills-mirror.sh ai-models   # sync one skill
#   bash scripts/sync-skills-mirror.sh --dry-run   # preview without writes
#
# Test seams:
#   TK_SKILLS_SRC      — override source skills home (default: $HOME/.claude/skills)
#   TK_SKILLS_DEST     — override dest mirror path (default: <repo>/templates/skills-marketplace)
#
# Exit codes:
#   0 success
#   1 missing source dir for one or more catalog skills
#   2 invalid argument

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Color helpers
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -n "${NO_COLOR+x}" ]] || ! [ -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Script location + source the canonical skills catalog
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/skills.sh
source "${SCRIPT_DIR}/lib/skills.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
DRY_RUN=0
SINGLE_SKILL=""

_usage() {
    cat <<EOF
Usage: bash scripts/sync-skills-mirror.sh [OPTIONS] [skill-name]

Re-sync templates/skills-marketplace/ from local ~/.claude/skills/ source-of-truth.
Maintainer tool — not wired into install path or CI.

OPTIONS:
  --dry-run     Preview copy operations without writing any files.
  -h, --help    Show this help message.

ARGUMENTS:
  skill-name    Sync only this one skill (must be in the 22-skill catalog).
                If omitted, all 22 catalog skills are synced.

TEST SEAMS:
  TK_SKILLS_SRC   Override source directory (default: \$HOME/.claude/skills)
  TK_SKILLS_DEST  Override dest directory (default: <repo>/templates/skills-marketplace)

EXIT CODES:
  0  All requested skills synced successfully (or dry-run preview complete).
  1  One or more source directories missing (MISSING > 0).
  2  Invalid argument (unknown flag or skill name not in catalog).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            _usage
            exit 0
            ;;
        -*)
            echo -e "${RED}✗${NC} Unknown option: $1" >&2
            _usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$SINGLE_SKILL" ]]; then
                echo -e "${RED}✗${NC} Too many positional arguments: '$1'" >&2
                _usage >&2
                exit 2
            fi
            SINGLE_SKILL="$1"
            shift
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Resolve source + dest paths (honor test seams)
# ─────────────────────────────────────────────────────────────────────────────
SKILLS_SRC="${TK_SKILLS_SRC:-$HOME/.claude/skills}"
SKILLS_DEST="${TK_SKILLS_DEST:-${REPO_ROOT}/templates/skills-marketplace}"

# ─────────────────────────────────────────────────────────────────────────────
# Build sync list
# ─────────────────────────────────────────────────────────────────────────────
sync_list=()

if [[ -n "$SINGLE_SKILL" ]]; then
    # Validate that the requested skill is in the curated catalog.
    found=0
    for entry in "${SKILLS_CATALOG[@]}"; do
        if [[ "$entry" == "$SINGLE_SKILL" ]]; then
            found=1
            break
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        echo -e "${RED}✗${NC} '$SINGLE_SKILL' is not in the 22-skill catalog" >&2
        echo "Run without arguments to see all catalog skills." >&2
        exit 2
    fi
    sync_list=("$SINGLE_SKILL")
else
    sync_list=("${SKILLS_CATALOG[@]}")
fi

# ─────────────────────────────────────────────────────────────────────────────
# Sync loop
# ─────────────────────────────────────────────────────────────────────────────
SYNCED=0
MISSING=0

echo -e "${BLUE}Skills Mirror Sync${NC}"
echo "  Source : ${SKILLS_SRC}"
echo "  Dest   : ${SKILLS_DEST}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  Mode   : dry-run (no writes)"
fi
echo ""

for name in "${sync_list[@]}"; do
    src="${SKILLS_SRC}/${name}"
    dest="${SKILLS_DEST}/${name}"
    if [[ ! -d "$src" ]]; then
        echo -e "${YELLOW}!${NC} ${name}: source missing at ${src} (skip)"
        MISSING=$((MISSING + 1))
        continue
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${BLUE}~${NC} would sync: ${src} → ${dest}"
        continue
    fi
    if [[ -d "$dest" ]]; then
        rm -rf "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
    echo -e "${GREEN}✓${NC} synced: ${name}"
    SYNCED=$((SYNCED + 1))
done

printf '\nSynced: %d · Missing: %d · Total: %d\n' "$SYNCED" "$MISSING" "${#sync_list[@]}"

if [[ "$MISSING" -gt 0 ]]; then
    exit 1
fi
exit 0
