#!/usr/bin/env bash
# test-claude-md-new.sh — Audit T-02 / CRIT-01 regression guard.
#
# Verifies the chezmoi-style CLAUDE.md.new flow that replaced the emoji-anchored
# smart-merge in scripts/update-claude.sh. Scenarios:
#
#   1. First install — no existing CLAUDE.md → file created, no .new written
#   2. Identical    — existing CLAUDE.md == upstream → no .new, info message
#   3. Differs      — existing CLAUDE.md != upstream → .new written, original
#                     bytes preserved
#   4. Empty src    — TK_UPDATE_FILE_SRC has no template → existing untouched,
#                     no .new written
#   5. Stale .new   — running on identical content removes a stale .new from a
#                     previous diverged run
#
# Exit 0 on all pass, 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"
LIB_DIR="${REPO_ROOT}/scripts/lib"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-claude-md-new.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# Mirror of sha256_of helper used elsewhere in the test suite.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Seed a minimal toolkit-install.json with one installed file so the no-op gate
# fails (forcing the full update flow to reach the CLAUDE.md handling block).
seed_minimal_state() {
    local state_path="$1"
    jq -n '{"version":1,"mode":"standalone",
            "detected":{"superpowers":{"present":false,"version":""},"gsd":{"present":false,"version":""}},
            "installed_files":[
              {"path":"rules/README.md","sha256":"deadbeef","installed_at":"2026-04-15T12:00:00Z"}
            ],
            "skipped_files":[],
            "installed_at":"2026-04-15T12:00:00Z"}' \
        > "$state_path"
}

# Build a FILE_SRC dir that satisfies update-claude.sh's manifest-driven loop
# (so the script reaches the CLAUDE.md block) and optionally includes a CLAUDE.md
# template. Args: <file_src> [<claude_md_content_or_empty>]
build_file_src() {
    local fs="$1" claude_md_body="${2-}"
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        mkdir -p "$fs/$(dirname "$rel")"
        echo "REMOTE-CONTENT-OF-$rel" > "$fs/$rel"
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_FIXTURE")
    if [[ -n "$claude_md_body" ]]; then
        mkdir -p "$fs/templates/base"
        printf '%s' "$claude_md_body" > "$fs/templates/base/CLAUDE.md"
    fi
}

# Run update-claude.sh against a hermetic fixture root. Stderr captured into
# stdout. --prune=no so we don't have to seed manifest hashes for every file.
run_update() {
    local scr="$1" file_src="$2"
    TK_UPDATE_HOME="$scr" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_FILE_SRC="$file_src" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" \
        --no-banner --no-offer-mode-switch --prune=no </dev/null 2>&1 || true
}

# ─────────────────────────────────────────────────
# Scenario 1: first install — no existing CLAUDE.md
# ─────────────────────────────────────────────────
scenario_first_install() {
    echo ""
    echo "Scenario 1: first-install (no existing CLAUDE.md)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude"
    seed_minimal_state "$SCR/.claude/toolkit-install.json"
    local FILE_SRC="$SCR/.src"
    build_file_src "$FILE_SRC" "TEMPLATE-VERSION-1"

    run_update "$SCR" "$FILE_SRC" >/dev/null

    [[ -f "$SCR/.claude/CLAUDE.md" ]] && local exists=true || local exists=false
    assert_eq "true" "$exists" "CLAUDE.md created from template"

    [[ -f "$SCR/.claude/CLAUDE.md.new" ]] && local new_exists=true || local new_exists=false
    assert_eq "false" "$new_exists" "no CLAUDE.md.new on first install"

    local body
    body=$(cat "$SCR/.claude/CLAUDE.md")
    assert_eq "TEMPLATE-VERSION-1" "$body" "CLAUDE.md content matches template byte-for-byte"
}

# ─────────────────────────────────────────────────
# Scenario 2: identical — existing CLAUDE.md byte-equals upstream
# ─────────────────────────────────────────────────
scenario_identical() {
    echo ""
    echo "Scenario 2: identical (existing == upstream)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude"
    seed_minimal_state "$SCR/.claude/toolkit-install.json"
    printf '%s' "TEMPLATE-VERSION-1" > "$SCR/.claude/CLAUDE.md"
    local FILE_SRC="$SCR/.src"
    build_file_src "$FILE_SRC" "TEMPLATE-VERSION-1"

    local OUT
    OUT=$(run_update "$SCR" "$FILE_SRC")

    [[ -f "$SCR/.claude/CLAUDE.md.new" ]] && local new_exists=true || local new_exists=false
    assert_eq "false" "$new_exists" "no CLAUDE.md.new when content matches"

    assert_eq "true" "$(echo "$OUT" | grep -q 'CLAUDE.md already matches latest template' && echo true || echo false)" \
        "stdout reports 'already matches latest template'"

    local body
    body=$(cat "$SCR/.claude/CLAUDE.md")
    assert_eq "TEMPLATE-VERSION-1" "$body" "existing CLAUDE.md left unmodified"
}

# ─────────────────────────────────────────────────
# Scenario 3: differs — write .new, leave original alone
# ─────────────────────────────────────────────────
scenario_differs() {
    echo ""
    echo "Scenario 3: differs (existing != upstream)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude"
    seed_minimal_state "$SCR/.claude/toolkit-install.json"
    # User has heavily customized CLAUDE.md — must NEVER be touched.
    local USER_CLAUDE_MD="USER-AUTHORED-PROJECT-CONTEXT
## My Custom Section
- proprietary content the smart-merge would have eaten
- includes line that starts with ## Performance (regex [^P] bug repro)
"
    printf '%s' "$USER_CLAUDE_MD" > "$SCR/.claude/CLAUDE.md"
    local USER_HASH
    USER_HASH=$(sha256_of "$SCR/.claude/CLAUDE.md")

    local FILE_SRC="$SCR/.src"
    build_file_src "$FILE_SRC" "UPSTREAM-TEMPLATE-V2"

    local OUT
    OUT=$(run_update "$SCR" "$FILE_SRC")

    [[ -f "$SCR/.claude/CLAUDE.md.new" ]] && local new_exists=true || local new_exists=false
    assert_eq "true" "$new_exists" "CLAUDE.md.new written when upstream differs"

    local new_body
    new_body=$(cat "$SCR/.claude/CLAUDE.md.new")
    assert_eq "UPSTREAM-TEMPLATE-V2" "$new_body" ".new file contains upstream template content"

    # CRITICAL: the user's CLAUDE.md must be byte-identical to what they wrote.
    local POST_HASH
    POST_HASH=$(sha256_of "$SCR/.claude/CLAUDE.md")
    assert_eq "$USER_HASH" "$POST_HASH" "user CLAUDE.md preserved byte-for-byte (CRIT-01 guard)"

    assert_eq "true" "$(echo "$OUT" | grep -q 'CLAUDE.md differs from upstream' && echo true || echo false)" \
        "stdout warns about divergence"
}

# ─────────────────────────────────────────────────
# Scenario 4: empty src — keep existing untouched
# ─────────────────────────────────────────────────
scenario_empty_src() {
    echo ""
    echo "Scenario 4: empty-src (no upstream template available)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR/.claude"
    seed_minimal_state "$SCR/.claude/toolkit-install.json"
    printf '%s' "USER-DOC-DO-NOT-TOUCH" > "$SCR/.claude/CLAUDE.md"
    local USER_HASH
    USER_HASH=$(sha256_of "$SCR/.claude/CLAUDE.md")

    # Build FILE_SRC with manifest files but NO templates/base/CLAUDE.md
    local FILE_SRC="$SCR/.src"
    build_file_src "$FILE_SRC" ""

    local OUT
    OUT=$(run_update "$SCR" "$FILE_SRC")

    [[ -f "$SCR/.claude/CLAUDE.md.new" ]] && local new_exists=true || local new_exists=false
    assert_eq "false" "$new_exists" "no CLAUDE.md.new when template src is empty"

    local POST_HASH
    POST_HASH=$(sha256_of "$SCR/.claude/CLAUDE.md")
    assert_eq "$USER_HASH" "$POST_HASH" "user CLAUDE.md preserved byte-for-byte on missing template"

    assert_eq "true" "$(echo "$OUT" | grep -q 'no CLAUDE.md template\|keeping existing file' && echo true || echo false)" \
        "stdout warns template unavailable"
}

# ─────────────────────────────────────────────────
# Scenario 5: stale .new cleared on identical re-run
# ─────────────────────────────────────────────────
scenario_stale_new_cleared() {
    echo ""
    echo "Scenario 5: stale-new-cleared"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s5"
    mkdir -p "$SCR/.claude"
    seed_minimal_state "$SCR/.claude/toolkit-install.json"
    # Existing CLAUDE.md matches what the next upstream will be.
    printf '%s' "TEMPLATE-VERSION-3" > "$SCR/.claude/CLAUDE.md"
    # But there's an old .new from a prior diverged run.
    printf '%s' "OLD-DIVERGED-CONTENT" > "$SCR/.claude/CLAUDE.md.new"

    local FILE_SRC="$SCR/.src"
    build_file_src "$FILE_SRC" "TEMPLATE-VERSION-3"

    run_update "$SCR" "$FILE_SRC" >/dev/null

    [[ -f "$SCR/.claude/CLAUDE.md.new" ]] && local new_exists=true || local new_exists=false
    assert_eq "false" "$new_exists" "stale CLAUDE.md.new cleared when content now matches"
}

# ─────────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────────
echo "Test: CLAUDE.md.new flow (audit T-02)"
echo "==============================================="
scenario_first_install
scenario_identical
scenario_differs
scenario_empty_src
scenario_stale_new_cleared

echo ""
echo "==============================================="
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] || exit 1
