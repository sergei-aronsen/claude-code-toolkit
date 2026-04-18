#!/usr/bin/env bash
# test-migrate-idempotent.sh — Phase 5 Plan 05-03 idempotence + self-heal assertions.
#
# Scenarios:
# 1. normal second run — state=complement-sp + no duplicates → "Already migrated" + exit 0
# 2. self-heal — state=standalone + no duplicates → Plan 05-02's no-duplicates exit (also 0)
# 3. user re-created a duplicate — state=complement-sp + duplicate on disk → full flow runs (no early-exit)
# 4. complement-full — state=complement-full + no duplicates → "Already migrated to complement-full"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-migrate-v2.json"
SP_CACHE_FIXTURE_FULL="${FIXTURES_DIR}/sp-cache"
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

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected substring: ${needle}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-migrate-idem.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# Helper: seed state with arbitrary mode + installed_files entries
seed_state_with_mode() {
    local state_path="$1" mode="$2"; shift 2
    local entries="[]"
    while [[ $# -ge 2 ]]; do
        local p="$1" h="$2"; shift 2
        entries=$(jq --arg p "$p" --arg h "$h" \
            '. + [{"path": $p, "sha256": $h, "installed_at": "2026-04-15T12:00:00Z"}]' \
            <<<"$entries")
    done
    mkdir -p "$(dirname "$state_path")"
    jq -n --arg mode "$mode" --argjson files "$entries" \
        '{"version": 2, "mode": $mode,
          "synthesized_from_filesystem": false,
          "detected": {"superpowers": {"present": true,  "version": "5.0.7"},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": $files,
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' \
        > "$state_path"
}

# ─────────────────────────────────────────────────
# Scenario 1: normal second run
# ─────────────────────────────────────────────────
scenario_normal_second_run() {
    echo ""
    echo "Scenario 1: normal second run — state=complement-sp + no duplicates → Already migrated"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/rules"
    echo "rules-content" > "$SCR/.claude/rules/README.md"  # non-conflict

    seed_state_with_mode "$SCR/.claude/toolkit-install.json" "complement-sp" \
        "$SCR/.claude/rules/README.md" "dummy"

    local OUT EXIT=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" 2>&1) || EXIT=$?

    assert_eq "0" "$EXIT" "second run exits 0"
    assert_contains "Already migrated to complement-sp" "$OUT" "exact message 'Already migrated to complement-sp'"
    assert_contains "Nothing to do" "$OUT" "Scenario 1: script printed 'Nothing to do' phrase per ROADMAP SC-4"

    # No backup dir created
    local BACKUPS
    BACKUPS=$( (find "$SCR" -maxdepth 1 -type d -name ".claude-backup-pre-migrate-*" 2>/dev/null || true) | wc -l | tr -d " ")
    assert_eq "0" "$BACKUPS" "no backup dir on idempotent run"
}

# ─────────────────────────────────────────────────
# Scenario 2: self-heal — state rolled back to standalone, files already gone
# ─────────────────────────────────────────────────
scenario_selfheal_state_rollback_files_gone() {
    echo ""
    echo "Scenario 2: self-heal — state=standalone + no duplicates → exit 0"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude/rules"
    echo "rules-content" > "$SCR/.claude/rules/README.md"

    # Manual rollback: state says standalone but no SP-conflict files on disk
    seed_state_with_mode "$SCR/.claude/toolkit-install.json" "standalone" \
        "$SCR/.claude/rules/README.md" "dummy"

    local OUT EXIT=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" 2>&1) || EXIT=$?

    assert_eq "0" "$EXIT" "self-heal exits 0"
    # Either Plan 05-02 "No duplicate files found" OR Plan 05-03 "Already migrated" is acceptable;
    # both indicate correct no-op behavior. (state.mode=standalone takes Plan 05-02 branch.)
    if echo "$OUT" | grep -qE "No duplicate files found|Already migrated"; then
        PASS=$((PASS + 1)); echo "  ✓ self-heal message printed (no-op)"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ no self-heal message"
        echo "    output: $OUT"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 3: user re-created a duplicate → full flow runs
# ─────────────────────────────────────────────────
scenario_user_recreated_duplicate() {
    echo ""
    echo "Scenario 3: user re-created a duplicate → early-exit NOT taken, full flow runs"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude/commands"
    echo "re-created" > "$SCR/.claude/commands/debug.md"  # user manually placed it back

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "re-created" > "$FILE_SRC/commands/debug.md"

    seed_state_with_mode "$SCR/.claude/toolkit-install.json" "complement-sp" \
        "$SCR/.claude/rules/README.md" "dummy"

    local OUT EXIT=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1) || EXIT=$?

    assert_eq "0" "$EXIT" "dry-run exits 0"
    # early-exit NOT taken — output must show the 3-column diff
    assert_contains "TK tmpl"   "$OUT" "re-created duplicate triggered full flow (header printed)"
    # And the "Already migrated" message must NOT appear
    if echo "$OUT" | grep -q "Already migrated"; then
        FAIL=$((FAIL + 1)); echo "  ✗ 'Already migrated' should NOT appear when duplicate re-created"
    else
        PASS=$((PASS + 1)); echo "  ✓ 'Already migrated' correctly suppressed"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 4: complement-full mode
# ─────────────────────────────────────────────────
scenario_complement_full_already_migrated() {
    echo ""
    echo "Scenario 4: state=complement-full + no duplicates → Already migrated to complement-full"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR/.claude/rules"
    echo "rules-content" > "$SCR/.claude/rules/README.md"

    seed_state_with_mode "$SCR/.claude/toolkit-install.json" "complement-full" \
        "$SCR/.claude/rules/README.md" "dummy"

    local OUT EXIT=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=true SP_VERSION="5.0.7" GSD_VERSION="1.36.0" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" 2>&1) || EXIT=$?

    assert_eq "0" "$EXIT" "complement-full second run exits 0"
    assert_contains "Already migrated to complement-full" "$OUT" "exact message mentions complement-full"
    assert_contains "Nothing to do" "$OUT" "Scenario 4: script printed 'Nothing to do' phrase per ROADMAP SC-4"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
scenario_normal_second_run
scenario_selfheal_state_rollback_files_gone
scenario_user_recreated_duplicate
scenario_complement_full_already_migrated

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
