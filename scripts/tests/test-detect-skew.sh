#!/usr/bin/env bash
# test-detect-skew.sh — DETECT-07 version-skew warning assertions.
#
# Scenarios (09-VALIDATION.md rows 9-04-01..05):
#   1. SP skew only → one warning line (superpowers old → new)
#   2. Both skew → two warning lines (superpowers + get-shit-done)
#   3. Match → no warning (silent)
#   4. Empty stored → no warning (D-23: silent when stored empty)
#   5. No STATE_FILE → warn_version_skew returns 0 silently
#
# Also asserts D-22 scope lock: warn_version_skew NOT called from init-claude.sh
# or migrate-to-complement.sh.
#
# Usage: bash scripts/tests/test-detect-skew.sh
# Exit: 0 all pass, 1 any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"

PASS=0
FAIL=0

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "      expected substring: ${needle}"
        echo "      in output:"
        echo "$haystack" | head -20 | sed 's/^/        /'
    fi
}

assert_not_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if ! echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "      unexpected substring present: ${needle}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-detect-skew.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# seed_state_with_versions <state_path> <sp_version> <gsd_version>
# Writes a minimal state schema v2 JSON to <state_path>.
seed_state_with_versions() {
    local state_path="$1" sp_ver="$2" gsd_ver="$3"
    mkdir -p "$(dirname "$state_path")"
    jq -n \
        --arg sp  "$sp_ver" \
        --arg gsd "$gsd_ver" \
        '{
          "version": 2,
          "mode": "standalone",
          "synthesized_from_filesystem": false,
          "manifest_hash": "dummy-hash-for-test",
          "detected": {
            "superpowers": {"present": true,  "version": $sp},
            "gsd":         {"present": false, "version": $gsd}
          },
          "installed_files": [],
          "skipped_files": [],
          "installed_at": "2026-01-01T00:00:00Z"
        }' > "$state_path"
}

# run_update <sandbox_home> <sp_ver> <gsd_ver>
# Runs update-claude.sh under the full seam and returns captured stdout+stderr.
# Sets HAS_SP/HAS_GSD based on whether version args are non-empty.
run_update() {
    local scr="$1" sp="$2" gsd="$3"
    local has_sp="true" has_gsd="true"
    [[ -z "$sp"  ]] && has_sp="false"
    [[ -z "$gsd" ]] && has_gsd="false"

    TK_UPDATE_HOME="$scr" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_FILE_SRC="$scr/.src" \
    HAS_SP="$has_sp" HAS_GSD="$has_gsd" \
    SP_VERSION="$sp" GSD_VERSION="$gsd" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch 2>&1 || true
}

# ─────────────────────────────────────────────────
# Scenario 1: SP skew only
# ─────────────────────────────────────────────────
scenario_sp_skew_only() {
    echo ""
    echo "Scenario 1: SP skew only"
    echo "---"
    local SCR="${TMPDIR_ROOT}/sp-only"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_state_with_versions "$SCR/.claude/toolkit-install.json" "5.0.7" ""
    local OUT
    OUT=$(run_update "$SCR" "5.1.0" "")
    assert_contains "superpowers 5.0.7 → 5.1.0"  "$OUT" "SP old → new in warning"
    assert_contains "review install matrix"        "$OUT" "guidance text present"
    assert_not_contains "Base plugin version changed: get-shit-done" "$OUT" "GSD skew warning silent when stored empty"
}

# ─────────────────────────────────────────────────
# Scenario 2: Both SP + GSD skew
# ─────────────────────────────────────────────────
scenario_both_skew() {
    echo ""
    echo "Scenario 2: Both SP + GSD skew"
    echo "---"
    local SCR="${TMPDIR_ROOT}/both"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_state_with_versions "$SCR/.claude/toolkit-install.json" "5.0.7" "1.2.0"
    local OUT
    OUT=$(run_update "$SCR" "5.1.0" "1.3.0")
    assert_contains "superpowers 5.0.7 → 5.1.0"   "$OUT" "SP warning line"
    assert_contains "get-shit-done 1.2.0 → 1.3.0"  "$OUT" "GSD warning line"
}

# ─────────────────────────────────────────────────
# Scenario 3: Match → silent
# ─────────────────────────────────────────────────
scenario_match_silent() {
    echo ""
    echo "Scenario 3: Match → silent"
    echo "---"
    local SCR="${TMPDIR_ROOT}/match"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_state_with_versions "$SCR/.claude/toolkit-install.json" "5.0.7" "1.2.0"
    local OUT
    OUT=$(run_update "$SCR" "5.0.7" "1.2.0")
    assert_not_contains "review install matrix" "$OUT" "no warning on version match"
}

# ─────────────────────────────────────────────────
# Scenario 4: Empty stored → silent
# ─────────────────────────────────────────────────
scenario_empty_stored_silent() {
    echo ""
    echo "Scenario 4: Empty stored → silent"
    echo "---"
    local SCR="${TMPDIR_ROOT}/empty"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_state_with_versions "$SCR/.claude/toolkit-install.json" "" ""
    local OUT
    OUT=$(run_update "$SCR" "5.1.0" "1.3.0")
    assert_not_contains "review install matrix" "$OUT" "no warning when stored versions empty"
}

# ─────────────────────────────────────────────────
# Scenario 5: No STATE_FILE → warn_version_skew returns 0 silently
# ─────────────────────────────────────────────────
scenario_no_state_silent() {
    echo ""
    echo "Scenario 5: warn_version_skew with no STATE_FILE → silent"
    echo "---"
    local OUT
    OUT=$(bash -c '
        source "$1"
        STATE_FILE=/nonexistent/path
        SP_VERSION="5.1.0"
        GSD_VERSION="1.3.0"
        YELLOW=""
        NC=""
        warn_version_skew
    ' -- "$REPO_ROOT/scripts/lib/install.sh" 2>&1 || true)
    assert_not_contains "review install matrix" "$OUT" "silent when STATE_FILE missing"
}

# ─────────────────────────────────────────────────
# D-22 scope lock assertions (negative grep)
# ─────────────────────────────────────────────────
scenario_d22_scope_lock() {
    echo ""
    echo "Scenario 6: D-22 scope lock — warn_version_skew NOT in init or migrate"
    echo "---"
    if ! grep -q 'warn_version_skew' "$REPO_ROOT/scripts/init-claude.sh"; then
        PASS=$((PASS + 1)); echo "  ✓ init-claude.sh does NOT reference warn_version_skew"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ init-claude.sh MUST NOT call warn_version_skew (D-22 scope lock)"
    fi
    if ! grep -q 'warn_version_skew' "$REPO_ROOT/scripts/migrate-to-complement.sh"; then
        PASS=$((PASS + 1)); echo "  ✓ migrate-to-complement.sh does NOT reference warn_version_skew"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ migrate-to-complement.sh MUST NOT call warn_version_skew (D-22 scope lock)"
    fi
}

# ─────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────
scenario_sp_skew_only
scenario_both_skew
scenario_match_silent
scenario_empty_stored_silent
scenario_no_state_silent
scenario_d22_scope_lock

echo ""
echo "---"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
