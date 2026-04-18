#!/usr/bin/env bash
# test-update-drift.sh — Phase 4 Plan 04-01 drift + v3.x synthesis + mode-switch assertions.
#
# Scenarios:
# - v3x-upgrade-path         (D-50)
# - mode-drift-accept        (D-51)
# - mode-drift-decline       (D-51)
# - mode-drift-curlbash      (D-51 fail-closed)
# - mode-switch-transaction-integrity (D-52)
#
# Exit 0 on all pass, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"
SEED_FIXTURE="${FIXTURES_DIR}/toolkit-install-seeded.json"
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

TMPDIR_ROOT="$(mktemp -d -t tk-update-drift.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# ─────────────────────────────────────────────────
# Scenario 1: v3.x upgrade — synthesize state from filesystem (D-50)
# ─────────────────────────────────────────────────
scenario_v3x_upgrade_path() {
    echo ""
    echo "Scenario 1: v3.x upgrade — synthesize state from filesystem"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT"   > "$SCR/.claude/commands/plan.md"
    echo "DEBUG-CONTENT"  > "$SCR/.claude/commands/debug.md"
    echo "RULES-CONTENT"  > "$SCR/.claude/rules/README.md"

    # Run update-claude.sh with no pre-existing state
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch 2>&1 || true)

    assert_eq "true" "$( [ -f "$SCR/.claude/toolkit-install.json" ] && echo true || echo false)" \
        "synthesized state file exists"
    local synth_mode
    synth_mode=$(jq -r '.mode' "$SCR/.claude/toolkit-install.json" 2>/dev/null || echo "MISSING")
    assert_eq "standalone" "$synth_mode" "synthesized mode = standalone (no SP/GSD)"
    local synth_count
    synth_count=$(jq -r '.installed_files | length' "$SCR/.claude/toolkit-install.json" 2>/dev/null || echo "0")
    # 3 files seeded, all are in manifest-update-v2.json -> synthesis picks up all 3
    assert_eq "3" "$synth_count" "installed_files records all seeded files"
}

# ─────────────────────────────────────────────────
# Scenario 2: mode-drift accept (D-51)
# ─────────────────────────────────────────────────
scenario_mode_drift_accept() {
    echo ""
    echo "Scenario 2: mode-drift — accept switch to complement-sp"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT"   > "$SCR/.claude/commands/plan.md"
    echo "DEBUG-CONTENT"  > "$SCR/.claude/commands/debug.md"
    echo "RULES-CONTENT"  > "$SCR/.claude/rules/README.md"

    # Pre-seed state with mode=standalone
    TK_UPDATE_HOME="$SCR" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 || true

    assert_eq "standalone" "$(jq -r '.mode' "$SCR/.claude/toolkit-install.json" 2>/dev/null || echo MISSING)" \
        "pre-seeded state mode = standalone"

    # Now run with HAS_SP=true + accept switch
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --offer-mode-switch=yes 2>&1 || true)

    # Assert stdout contains drift indication
    if echo "$OUT" | grep -q "Current:"; then
        PASS=$((PASS + 1)); echo "  ✓ drift output contains 'Current:' label"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ drift output missing 'Current:' label"
        echo "    output was: $OUT"
    fi
    if echo "$OUT" | grep -q "Recommended:"; then
        PASS=$((PASS + 1)); echo "  ✓ drift output contains 'Recommended:' label"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ drift output missing 'Recommended:' label"
        echo "    output was: $OUT"
    fi

    # After switch, in-memory STATE_MODE should be complement-sp.
    # The mode-switch is reflected in the STATE_JSON (in-memory only in 04-01;
    # persisted write is Plan 04-03 scope). Here we verify via the mode-switch
    # log line rather than the persisted JSON (which is still the synthesis state).
    if echo "$OUT" | grep -q "mode-switch"; then
        PASS=$((PASS + 1)); echo "  ✓ mode-switch log line appears in output"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ mode-switch log line missing from output"
        echo "    output was: $OUT"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 3: mode-drift decline (D-51)
# ─────────────────────────────────────────────────
scenario_mode_drift_decline() {
    echo ""
    echo "Scenario 3: mode-drift — decline switch (stay in standalone)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT"   > "$SCR/.claude/commands/plan.md"
    echo "DEBUG-CONTENT"  > "$SCR/.claude/commands/debug.md"
    echo "RULES-CONTENT"  > "$SCR/.claude/rules/README.md"

    # Pre-seed state with mode=standalone
    TK_UPDATE_HOME="$SCR" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 || true

    # Now run with HAS_SP=true + DECLINE switch
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --offer-mode-switch=no 2>&1 || true)

    # Assert "Keeping current mode" message appears
    if echo "$OUT" | grep -q "Keeping current mode"; then
        PASS=$((PASS + 1)); echo "  ✓ 'Keeping current mode' message appears on decline"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ 'Keeping current mode' message missing on decline"
        echo "    output was: $OUT"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 4: mode-drift fail-closed under curl|bash (no /dev/tty) (D-51)
# ─────────────────────────────────────────────────
scenario_mode_drift_curlbash() {
    echo ""
    echo "Scenario 4: mode-drift — fail-closed under curl|bash (no /dev/tty)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT"   > "$SCR/.claude/commands/plan.md"
    echo "DEBUG-CONTENT"  > "$SCR/.claude/commands/debug.md"
    echo "RULES-CONTENT"  > "$SCR/.claude/rules/README.md"

    # Pre-seed state with mode=standalone
    TK_UPDATE_HOME="$SCR" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 || true

    # Run with HAS_SP=true and interactive mode but stdin from /dev/null (simulates curl|bash)
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --offer-mode-switch=interactive \
          < /dev/null 2>&1 || true)

    # Assert "Keeping current mode" message appears (fail-closed = same as N)
    if echo "$OUT" | grep -q "Keeping current mode"; then
        PASS=$((PASS + 1)); echo "  ✓ fail-closed: 'Keeping current mode' when no /dev/tty"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ fail-closed: 'Keeping current mode' missing when no /dev/tty"
        echo "    output was: $OUT"
    fi
}

# ─────────────────────────────────────────────────
# Scenario 5: mode-switch transaction integrity (D-52)
# ─────────────────────────────────────────────────
scenario_mode_switch_transaction_integrity() {
    echo ""
    echo "Scenario 5: mode-switch transaction integrity — SP-conflict files deleted"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s5"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules" "$SCR/.claude/agents"
    # Seed 4 files: commands/plan.md and agents/code-reviewer.md conflict with SP;
    # commands/debug.md and rules/README.md do not.
    echo "PLAN-CONTENT"           > "$SCR/.claude/commands/plan.md"
    echo "DEBUG-CONTENT"          > "$SCR/.claude/commands/debug.md"
    echo "CODE-REVIEWER-CONTENT"  > "$SCR/.claude/agents/code-reviewer.md"
    echo "RULES-CONTENT"          > "$SCR/.claude/rules/README.md"

    # Pre-seed state with mode=standalone and 4 installed files (absolute paths)
    local SEED_ABS
    SEED_ABS=$(jq \
        --arg prefix "$SCR/.claude" \
        '.installed_files = [
            {"path": ($prefix + "/commands/plan.md"),          "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "installed_at": "2026-04-15T12:00:00Z"},
            {"path": ($prefix + "/commands/debug.md"),         "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "installed_at": "2026-04-15T12:00:00Z"},
            {"path": ($prefix + "/agents/code-reviewer.md"),   "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "installed_at": "2026-04-15T12:00:00Z"},
            {"path": ($prefix + "/rules/README.md"),           "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "installed_at": "2026-04-15T12:00:00Z"}
        ]' \
        "$SEED_FIXTURE")

    echo "$SEED_ABS" > "$SCR/.claude/toolkit-install.json"

    # Run with HAS_SP=true + accept switch (mode standalone -> complement-sp)
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_SKIP_LEGACY_BACKUP=1 \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --offer-mode-switch=yes 2>&1 || true)

    # Assert mode-switch log lines appear for SP-conflict files
    # (Plan 04-02 deletes the legacy re-download loops; in Plan 04-01 the files are
    #  correctly removed by execute_mode_switch and then re-added by the legacy loops —
    #  so we verify the removal log line, not the post-run absence)
    if echo "$OUT" | grep -q "mode-switch removed: commands/plan.md"; then
        PASS=$((PASS + 1)); echo "  ✓ mode-switch removed: commands/plan.md (log confirmed)"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ mode-switch removed: commands/plan.md not in log"
        echo "    relevant output: $(echo "$OUT" | grep 'mode-switch' || echo '(no mode-switch lines)')"
    fi
    if echo "$OUT" | grep -q "mode-switch removed: agents/code-reviewer.md"; then
        PASS=$((PASS + 1)); echo "  ✓ mode-switch removed: agents/code-reviewer.md (log confirmed)"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ mode-switch removed: agents/code-reviewer.md not in log"
    fi
    # mode-switch completion log confirms new mode
    if echo "$OUT" | grep -q "mode-switch: recorded mode is now complement-sp"; then
        PASS=$((PASS + 1)); echo "  ✓ STATE_MODE updated to complement-sp after switch"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ STATE_MODE complement-sp not confirmed in log"
    fi

    # Non-conflict files should remain (not deleted by mode-switch)
    assert_eq "true" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "non-conflict commands/debug.md preserved after mode-switch"
    assert_eq "true" "$( [ -f "$SCR/.claude/rules/README.md" ] && echo true || echo false)" \
        "non-conflict rules/README.md preserved after mode-switch"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
scenario_v3x_upgrade_path
scenario_mode_drift_accept
scenario_mode_drift_decline
scenario_mode_drift_curlbash
scenario_mode_switch_transaction_integrity

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
