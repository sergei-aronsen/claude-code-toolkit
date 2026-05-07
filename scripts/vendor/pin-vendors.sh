#!/bin/bash
# scripts/vendor/pin-vendors.sh
#
# Updates manifest.json:vendor_pins with the current HEAD commit + tag (if
# any) of each vendor in _external/. Designed to run on toolkit release
# (auto-invoked by .github/workflows/release-pin.yml on tag push) but also
# usable manually by the maintainer.
#
# Behavior:
#   - Reads manifest.json:vendor_pins to discover vendors + repos
#   - Calls clone-pinned.sh first to ensure _external/<name>/ is up to date
#   - For each vendor, captures HEAD commit + nearest tag + ISO date
#   - Writes updated manifest.json (atomic write via temp file)
#
# Usage:
#   scripts/vendor/pin-vendors.sh                  # default manifest + _external
#   scripts/vendor/pin-vendors.sh manifest.json _external
#   DRY_RUN=1 scripts/vendor/pin-vendors.sh        # preview without writing
set -euo pipefail

MANIFEST="${1:-manifest.json}"
EXTERNAL_DIR="${2:-_external}"
DRY_RUN="${DRY_RUN:-0}"

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
    echo -e "${RED}✗${NC} jq required" >&2
    exit 1
fi

# Step 1 — ensure vendors are cloned/fetched
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$script_dir/clone-pinned.sh" ]]; then
    echo -e "${CYAN}Step 1 — ensure vendors are present${NC}"
    "$script_dir/clone-pinned.sh" "$MANIFEST" "$EXTERNAL_DIR" || true
    echo ""
fi

# Step 2 — collect HEAD commit + tag for each vendor
echo -e "${CYAN}Step 2 — capture pins${NC}"

vendors=$(jq -r '.vendor_pins // {} | keys[]' "$MANIFEST")
[[ -z "$vendors" ]] && { echo -e "${YELLOW}⚠${NC} No vendor_pins in manifest"; exit 0; }

# Build a jq script that updates each vendor's pin
today=$(date -u +%Y-%m-%d)
updates="."
updated_count=0
skipped_count=0

while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    dir="$EXTERNAL_DIR/$name"

    if [[ ! -d "$dir/.git" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $name — no clone at $dir, skipping"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    head_commit=$(cd "$dir" && git rev-parse HEAD 2>/dev/null || echo "")
    if [[ -z "$head_commit" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $name — could not read HEAD, skipping"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # Nearest tag (annotated or lightweight). Empty if no tag reachable.
    head_tag=$(cd "$dir" && git describe --tags --exact-match 2>/dev/null || \
                cd "$dir" && git describe --tags --abbrev=0 2>/dev/null || echo "")

    short=$(printf '%s' "$head_commit" | cut -c1-12)
    tag_disp="${head_tag:-<no tag>}"
    echo -e "  ${GREEN}✓${NC} $name → ${short} (${tag_disp}) @ ${today}"

    # Append jq update fragment
    # Use --arg for safe string injection
    updates+=" | .vendor_pins[\"$name\"].commit = \$${name//-/_}_commit"
    updates+=" | .vendor_pins[\"$name\"].tag = \$${name//-/_}_tag"
    updates+=" | .vendor_pins[\"$name\"].pinned_at = \$today"

    # Stash args for the final jq call
    eval "ARG_${name//-/_}_COMMIT='$head_commit'"
    eval "ARG_${name//-/_}_TAG='$head_tag'"

    updated_count=$((updated_count + 1))
done <<< "$vendors"

echo ""

if [[ $updated_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No vendors to pin (all skipped)"
    exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "${CYAN}DRY_RUN — manifest not written${NC}"
    echo "Would update $updated_count vendors (skipped: $skipped_count)"
    exit 0
fi

# Step 3 — apply updates atomically
echo -e "${CYAN}Step 3 — write manifest${NC}"

tmp=$(mktemp "${TMPDIR:-/tmp}/manifest-XXXXXX.json")
trap 'rm -f "$tmp"' EXIT

# Build jq args dynamically
jq_args=(--arg today "$today")
while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    dir="$EXTERNAL_DIR/$name"
    [[ ! -d "$dir/.git" ]] && continue
    var_name="${name//-/_}"
    commit_var="ARG_${var_name}_COMMIT"
    tag_var="ARG_${var_name}_TAG"
    jq_args+=(--arg "${var_name}_commit" "${!commit_var:-}")
    jq_args+=(--arg "${var_name}_tag" "${!tag_var:-}")
done <<< "$vendors"

jq "${jq_args[@]}" "$updates" "$MANIFEST" > "$tmp"

if [[ ! -s "$tmp" ]]; then
    echo -e "${RED}✗${NC} jq produced empty output, aborting"
    exit 1
fi

# Validate JSON
if ! jq -e . "$tmp" >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} produced invalid JSON, aborting"
    exit 1
fi

mv "$tmp" "$MANIFEST"
trap - EXIT
echo -e "${GREEN}✓${NC} manifest.json updated ($updated_count pins)"
exit 0
