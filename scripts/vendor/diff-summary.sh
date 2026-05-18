#!/bin/bash
# scripts/vendor/diff-summary.sh
#
# For each vendor in manifest.json:vendor_pins, generates a structured markdown
# diff summary between the pinned commit and current HEAD. Output is consumed
# by /vendor-changelog command's analysis prompt.
#
# Usage:
#   scripts/vendor/diff-summary.sh                                  # default paths
#   scripts/vendor/diff-summary.sh manifest.json _external out.md
#
# Output: writes structured markdown to OUT path. Exits 0 on success, 1 on
# manifest read failure.
set -euo pipefail

MANIFEST="${1:-manifest.json}"
EXTERNAL_DIR="${2:-_external}"
OUT="${3:-/tmp/vendor-diffs.md}"
COMMIT_LIMIT="${VENDOR_DIFF_COMMIT_LIMIT:-50}"
CHANGELOG_LIMIT="${VENDOR_DIFF_CHANGELOG_LINES:-150}"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifest not found: $MANIFEST" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq required but not installed" >&2
    exit 1
fi

# Header
{
    echo "# Vendor Diff Summary"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Toolkit version: $(jq -r '.version // "unknown"' "$MANIFEST")"
    echo "Toolkit build date: $(jq -r '.build_date // .updated // "unknown"' "$MANIFEST")"
    echo ""
} > "$OUT"

# Iterate vendors
vendors=$(jq -r '.vendor_pins // {} | to_entries[] | "\(.key)|\(.value.repo)|\(.value.commit // "")|\(.value.tag // "")|\(.value.pinned_at // "")"' "$MANIFEST")

if [[ -z "$vendors" ]]; then
    echo "## No vendor pins in manifest" >> "$OUT"
    exit 0
fi

while IFS='|' read -r name repo pinned_commit pinned_tag pinned_at; do
    [[ -z "$name" ]] && continue
    dir="$EXTERNAL_DIR/$name"

    {
        echo "## $name"
        echo ""
        echo "- **Repo:** \`$repo\`"
        echo "- **Pinned commit:** \`${pinned_commit:-<unset>}\`"
        echo "- **Pinned tag:** \`${pinned_tag:-<unset>}\`"
        echo "- **Pinned at:** \`${pinned_at:-<unset>}\`"
    } >> "$OUT"

    if [[ ! -d "$dir/.git" ]]; then
        echo "- **Status:** ⚠ vendor sources not present at \`$dir\` — run \`scripts/vendor/clone-pinned.sh\` first" >> "$OUT"
        echo "" >> "$OUT"
        continue
    fi

    head_commit=$(cd "$dir" && git rev-parse HEAD 2>/dev/null || echo "")
    head_date=$(cd "$dir" && git log -1 --format=%ci HEAD 2>/dev/null || echo "")

    {
        echo "- **HEAD commit:** \`$head_commit\`"
        echo "- **HEAD date:** $head_date"
    } >> "$OUT"

    if [[ -z "$pinned_commit" || "$pinned_commit" == "null" ]]; then
        {
            echo "- **Status:** ⚠ no pinned commit — first-run baseline only"
            echo ""
        } >> "$OUT"
        continue
    fi

    # Verify pinned commit exists in current clone. If missing, try a
    # targeted fetch by SHA — handles the release-branch case where the
    # pin lives on a tag/branch not in `main` history (common when vendors
    # tag releases off a release branch). Only after that fails do we
    # report force-push/shallow as the suspected cause.
    if ! (cd "$dir" && git cat-file -e "${pinned_commit}^{commit}" 2>/dev/null); then
        if (cd "$dir" && git fetch --quiet origin "$pinned_commit" 2>/dev/null) \
           && (cd "$dir" && git cat-file -e "${pinned_commit}^{commit}" 2>/dev/null); then
            : # fetched successfully — pin was on a non-main branch
        else
            {
                echo "- **Status:** ⚠ pinned commit \`$pinned_commit\` not reachable even after \`git fetch origin <sha>\` (force-pushed, deleted, or repo-renamed). Re-clone with VENDOR_CLONE_DEPTH=1000 to rule out depth, then inspect upstream."
                echo ""
            } >> "$OUT"
            continue
        fi
    fi

    commits_count=$(cd "$dir" && git rev-list "$pinned_commit"..HEAD --count 2>/dev/null || echo "0")
    echo "- **Commits since pin:** $commits_count" >> "$OUT"
    echo "" >> "$OUT"

    if [[ "$commits_count" == "0" ]]; then
        {
            echo "_No changes since pin._"
            echo ""
        } >> "$OUT"
        continue
    fi

    # Commits
    {
        echo "### Commits"
        echo ""
        echo '```'
        (cd "$dir" && git log "$pinned_commit"..HEAD --oneline 2>/dev/null | head -"$COMMIT_LIMIT") || true
        echo '```'
        echo ""
    } >> "$OUT"

    # Diff stat
    {
        echo "### Diff stat (top changed paths)"
        echo ""
        echo '```'
        (cd "$dir" && git diff "$pinned_commit"..HEAD --stat 2>/dev/null | tail -50) || true
        echo '```'
        echo ""
    } >> "$OUT"

    # CHANGELOG (if present)
    if [[ -f "$dir/CHANGELOG.md" ]]; then
        {
            echo "### CHANGELOG.md (top $CHANGELOG_LIMIT lines)"
            echo ""
            echo '```markdown'
            head -"$CHANGELOG_LIMIT" "$dir/CHANGELOG.md"
            echo '```'
            echo ""
        } >> "$OUT"
    fi

    # Detect BREAKING marker in commits or changelog
    if (cd "$dir" && git log "$pinned_commit"..HEAD --oneline 2>/dev/null | grep -qiE 'BREAKING|breaking change|major bump'); then
        echo "**🚨 BREAKING marker detected in commit messages — review carefully.**" >> "$OUT"
        echo "" >> "$OUT"
    fi
    if [[ -f "$dir/CHANGELOG.md" ]] && head -"$CHANGELOG_LIMIT" "$dir/CHANGELOG.md" | grep -qiE '^.*BREAKING'; then
        echo "**🚨 BREAKING marker detected in CHANGELOG — review carefully.**" >> "$OUT"
        echo "" >> "$OUT"
    fi
done <<< "$vendors"

echo "Diff summary written: $OUT" >&2
exit 0
