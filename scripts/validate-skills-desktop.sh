#!/bin/bash
#
# validate-skills-desktop.sh — DESK-02 + DESK-04
# Scans every templates/skills-marketplace/<name>/SKILL.md for Code-only
# tool-execution patterns. Skills without matches are PASS (Desktop-safe
# instruction-only); skills with matches are FLAG (Code-terminal only).
#
# Threshold (DESK-04): at least 4 skills must PASS or the script exits 1.
#
# Usage: bash scripts/validate-skills-desktop.sh
# Output: per-skill verdict to stdout + .audit-skills-desktop.txt artifact.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

THRESHOLD=4
MIRROR_DIR="${TK_SKILLS_MIRROR:-templates/skills-marketplace}"
ARTIFACT="${TK_SKILLS_AUDIT_FILE:-.audit-skills-desktop.txt}"

if [ ! -d "$MIRROR_DIR" ]; then
    echo -e "${RED}Error:${NC} skills mirror dir not found: $MIRROR_DIR" >&2
    exit 1
fi

PASS_COUNT=0
FLAG_COUNT=0
PASS_NAMES=()
FLAG_NAMES=()

# Heuristic — extended grep for either tool call pattern OR English instruction.
# FLAG_REGEX intentionally conservative: matches anything that suggests the
# skill needs Claude Code's tool-execution layer.
FLAG_REGEX='(Read|Write|Bash|Grep|Edit|Task)\(|Use (the )?(Read|Bash|Write) tool'

# Iterate skills in alphabetical order (predictable output for diffing).
while IFS= read -r skill_dir; do
    name=$(basename "$skill_dir")
    skill_md="$skill_dir/SKILL.md"
    if [ ! -f "$skill_md" ]; then
        continue
    fi
    if grep -E -q "$FLAG_REGEX" "$skill_md"; then
        FLAG_COUNT=$((FLAG_COUNT + 1))
        FLAG_NAMES+=("$name")
    else
        PASS_COUNT=$((PASS_COUNT + 1))
        PASS_NAMES+=("$name")
    fi
done < <(find "$MIRROR_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# Build artifact + stdout in one go (artifact is plain text, stdout is colored).
{
    echo "# Skills Desktop-safety audit"
    echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Mirror: $MIRROR_DIR"
    echo "# Threshold (DESK-04): >= $THRESHOLD PASS"
    echo ""
    echo "## PASS ($PASS_COUNT)"
    for n in "${PASS_NAMES[@]+"${PASS_NAMES[@]}"}"; do
        echo "  $n"
    done
    echo ""
    echo "## FLAG ($FLAG_COUNT)"
    for n in "${FLAG_NAMES[@]+"${FLAG_NAMES[@]}"}"; do
        echo "  $n"
    done
} > "$ARTIFACT"

echo -e "${BLUE}Skills Desktop-safety audit${NC}"
echo ""
echo -e "${GREEN}PASS ($PASS_COUNT)${NC}:"
for n in "${PASS_NAMES[@]+"${PASS_NAMES[@]}"}"; do
    echo -e "  ${GREEN}✓${NC} $n"
done
echo ""
echo -e "${YELLOW}FLAG ($FLAG_COUNT)${NC}:"
for n in "${FLAG_NAMES[@]+"${FLAG_NAMES[@]}"}"; do
    echo -e "  ${YELLOW}⚠${NC} $n"
done
echo ""
echo "Artifact: $ARTIFACT"
echo ""

if [ "$PASS_COUNT" -lt "$THRESHOLD" ]; then
    echo -e "${RED}✗${NC} DESK-04 gate failed: only $PASS_COUNT skill(s) PASS Desktop-safety (need >= $THRESHOLD)"
    exit 1
fi

echo -e "${GREEN}✓${NC} DESK-04 gate green: $PASS_COUNT skill(s) PASS (threshold: $THRESHOLD)"
exit 0
