#!/usr/bin/env bash
# test-migrate-diff.sh — Phase 5 Plan 05-02 three-way diff + user-mod detection assertions.
#
# Scenarios:
# 1. no-duplicates → exit 0 with "No duplicate files found"
# 2. three-column diff renders (TK / on-disk / SP) with header + data row
# 3. signal-a user-mod flagged (disk != state sha256)
# 4. signal-b user-mod flagged (disk != TK template)
# 5. clean file — 3-column row, NO warning
# 6. SP missing → two-column fallback (D-72) + warning
# 7. --dry-run creates no backup dir
# 8. --no-backup hard-fails

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
        echo "    in output: ${haystack}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-migrate-diff.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# Helper: seed a state file with given version + installed_files entries
# Usage: seed_state_file <path> <mode> <synth_flag> [<rel> <sha256>]...
seed_state_file() {
    local state_path="$1" mode="$2" synth_flag="$3"
    shift 3
    local entries="[]"
    while [[ $# -ge 2 ]]; do
        local p="$1" h="$2"; shift 2
        entries=$(jq --arg p "$p" --arg h "$h" \
            '. + [{"path": $p, "sha256": $h, "installed_at": "2026-04-15T12:00:00Z"}]' \
            <<<"$entries")
    done
    mkdir -p "$(dirname "$state_path")"
    jq -n --arg mode "$mode" --argjson synth "$synth_flag" --argjson files "$entries" \
        '{"version": 2, "mode": $mode,
          "synthesized_from_filesystem": $synth,
          "detected": {"superpowers": {"present": false, "version": ""},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": $files,
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' \
        > "$state_path"
}

# Helper: compute sha256 of file content (inline, avoids depending on state.sh)
sha256_of() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}

# ─────────────────────────────────────────────────
# Scenario 1: no duplicates → exit 0
# ─────────────────────────────────────────────────
scenario_no_duplicates_exit_0() {
    echo ""
    echo "Scenario 1: no duplicates on disk → 'No duplicate files found' + exit 0"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/rules"
    echo "rules-content" > "$SCR/.claude/rules/README.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC"

    local EXIT=0
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1) || EXIT=$?
    assert_eq "0" "$EXIT" "exit 0 on no duplicates"
    assert_contains "No duplicate files found" "$OUT" "'No duplicate files found' message"
}

# ─────────────────────────────────────────────────
# Scenario 2: three-column diff renders
# ─────────────────────────────────────────────────
scenario_three_column_diff_renders() {
    echo ""
    echo "Scenario 2: 3-column diff renders with header + per-file row"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude/commands"
    echo "tk-debug-content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "tk-debug-content" > "$FILE_SRC/commands/debug.md"

    local OUT
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1 || true)

    assert_contains "TK tmpl"   "$OUT" "header mentions 'TK tmpl' column"
    assert_contains "on-disk"   "$OUT" "header mentions 'on-disk' column"
    assert_contains "SP equiv"  "$OUT" "header mentions 'SP equiv' column"
    assert_contains "commands/debug.md" "$OUT" "commands/debug.md listed in data row"
}

# ─────────────────────────────────────────────────
# Scenario 3: signal-a user-mod (disk hash != state sha256)
# ─────────────────────────────────────────────────
scenario_signal_a_user_mod() {
    echo ""
    echo "Scenario 3: signal-a user-mod — disk hash != state sha256"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude/commands"
    echo "USER-MODIFIED-debug" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "USER-MODIFIED-debug" > "$FILE_SRC/commands/debug.md"  # same as disk → signal-b clean

    # Seed state with a DIFFERENT sha256 (simulating original install-time content)
    seed_state_file "$SCR/.claude/toolkit-install.json" "standalone" "false" \
        "commands/debug.md" "0000000000000000000000000000000000000000000000000000000000000000"

    local OUT
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes < /dev/null 2>&1 || true)

    assert_contains "locally modified" "$OUT" "signal-a warning: 'locally modified'"
    assert_contains "differs from state hash" "$OUT" "signal-a warning mentions state hash"
}

# ─────────────────────────────────────────────────
# Scenario 4: signal-b user-mod (disk == state sha256, != TK template)
# ─────────────────────────────────────────────────
scenario_signal_b_user_mod() {
    echo ""
    echo "Scenario 4: signal-b user-mod — disk == state.sha256 but != TK template"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR/.claude/commands"
    echo "DISK-AND-STATE" > "$SCR/.claude/commands/debug.md"
    local DISK_HASH
    DISK_HASH=$(sha256_of "$SCR/.claude/commands/debug.md")

    # FILE_SRC has DIFFERENT content (→ TK template hash differs)
    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "TK-TEMPLATE-DIFFERENT" > "$FILE_SRC/commands/debug.md"

    # Seed state with the SAME hash as on-disk (signal-a clean)
    seed_state_file "$SCR/.claude/toolkit-install.json" "standalone" "true" \
        "commands/debug.md" "$DISK_HASH"

    local OUT
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes < /dev/null 2>&1 || true)

    assert_contains "TK template" "$OUT" "signal-b warning mentions 'TK template'"
}

# ─────────────────────────────────────────────────
# Scenario 5: clean file — no warning
# ─────────────────────────────────────────────────
scenario_clean_no_warning() {
    echo ""
    echo "Scenario 5: clean file — state.sha256 == disk == TK template"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s5"
    mkdir -p "$SCR/.claude/commands"
    echo "CLEAN-CONTENT" > "$SCR/.claude/commands/debug.md"
    local H
    H=$(sha256_of "$SCR/.claude/commands/debug.md")

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "CLEAN-CONTENT" > "$FILE_SRC/commands/debug.md"

    seed_state_file "$SCR/.claude/toolkit-install.json" "standalone" "false" \
        "commands/debug.md" "$H"

    local OUT
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1 || true)

    # No "locally modified" line for this file
    if echo "$OUT" | grep -q "locally modified"; then
        FAIL=$((FAIL + 1)); echo "  ✗ expected NO 'locally modified' warning on clean file"
        echo "    output was: $OUT"
    else
        PASS=$((PASS + 1)); echo "  ✓ no 'locally modified' warning on clean file"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 6: SP missing → two-column fallback (D-72)
# ─────────────────────────────────────────────────
scenario_sp_missing_two_column() {
    echo ""
    echo "Scenario 6: SP fixture absent → third column '—' + warning (D-72)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s6"
    mkdir -p "$SCR/.claude/commands"
    echo "content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "content" > "$FILE_SRC/commands/debug.md"

    # Empty SP cache — SP file for systematic-debugging/SKILL.md does NOT exist
    local EMPTY_SP="$SCR/empty-sp"
    mkdir -p "$EMPTY_SP/superpowers/5.0.7/"

    local OUT
    OUT=$(TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$EMPTY_SP" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1 || true)

    assert_contains "SP file not found" "$OUT" "D-72 SP missing warning"
    # The data row should contain a '—' in the SP column for debug.md (lazy check)
    if echo "$OUT" | grep "commands/debug.md" | grep -q -- "—"; then
        PASS=$((PASS + 1)); echo "  ✓ SP column shows '—' in data row"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ SP column did not show '—' in data row"
        echo "    relevant output: $(echo "$OUT" | grep 'commands/debug.md' || echo '(none)')"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 7: --dry-run creates no backup
# ─────────────────────────────────────────────────
scenario_dry_run_no_backup() {
    echo ""
    echo "Scenario 7: --dry-run creates no backup dir, removes no files"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s7"
    mkdir -p "$SCR/.claude/commands"
    echo "content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "content" > "$FILE_SRC/commands/debug.md"

    # Use SCR as HOME so the backup dir (if erroneously created) appears under $SCR/
    HOME="$SCR" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run >/dev/null 2>&1 || true

    # No backup dir should exist under $SCR
    local BACKUP_COUNT
    BACKUP_COUNT=$(find "$SCR" -maxdepth 1 -type d -name ".claude-backup-pre-migrate-*" 2>/dev/null | wc -l | tr -d ' ')
    assert_eq "0" "$BACKUP_COUNT" "no backup dir created under --dry-run"
    # File still present
    assert_eq "true" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "file not removed under --dry-run"
}

# ─────────────────────────────────────────────────
# Scenario 8: --no-backup flag hard-fails
# ─────────────────────────────────────────────────
scenario_no_backup_flag_fails() {
    echo ""
    echo "Scenario 8: --no-backup rejected with exit code 1"
    echo "---"
    local EXIT=0
    OUT=$(bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --no-backup 2>&1) || EXIT=$?
    assert_eq "1" "$EXIT" "--no-backup exits 1"
    assert_contains "not allowed" "$OUT" "--no-backup error message mentions 'not allowed'"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
scenario_no_duplicates_exit_0
scenario_three_column_diff_renders
scenario_signal_a_user_mod
scenario_signal_b_user_mod
scenario_clean_no_warning
scenario_sp_missing_two_column
scenario_dry_run_no_backup
scenario_no_backup_flag_fails

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
