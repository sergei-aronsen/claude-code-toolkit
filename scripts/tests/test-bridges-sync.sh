#!/usr/bin/env bash
# test-bridges-sync.sh — Phase 29 hermetic smoke test for sync + uninstall integration.
#
# Scenarios (≥10 assertions):
#   S1  Clean source matching bridge → silent no-op (no SKIP/UPDATE/MODIFIED/ORPHANED log)
#   S2  Source edited, bridge clean → [~ UPDATE] + bridge SHA refreshed in state
#   S3a Bridge edited, drift prompt y → bridge overwritten, both SHAs refresh
#   S3b Bridge edited, drift prompt N → bridge kept, [~ MODIFIED] log
#   S4  --break-bridge gemini → user_owned=true; next sync_bridges run logs [- SKIP]
#   S5  --restore-bridge gemini → user_owned=false; next run re-syncs
#   S6  CLAUDE.md deleted → [? ORPHANED] + auto-flip user_owned=true
#   S7  uninstall.sh on clean bridge → REMOVE branch fires; bridges[] entry purged
#   S8  uninstall.sh on modified bridge with N response → KEPT; bridges[] entry stays
#   S9  uninstall.sh --keep-state → bridge file removed BUT bridges[] entry preserved
#   S10 BACKCOMPAT-01: invoke test-bootstrap.sh / test-install-tui.sh / test-bridges-foundation.sh
#       and assert each reports its expected PASS count unchanged
#
# Test seams:
#   TK_BRIDGE_HOME       — sandboxes ~/.claude/, ~/.gemini/, ~/.codex/, lock dir, state file
#   TK_UPDATE_HOME       — exported = TK_BRIDGE_HOME so update-claude.sh shares the sandbox
#   TK_UNINSTALL_HOME    — same shared sandbox for uninstall.sh
#   TK_UPDATE_LIB_DIR    — points at scripts/lib/ so update-claude.sh sources local libs
#   TK_UPDATE_MANIFEST_OVERRIDE — points at repo manifest.json (no curl)
#   TK_UPDATE_FILE_SRC   — points at repo root so update-claude.sh resolves files locally
#   TK_UNINSTALL_LIB_DIR — same as TK_UPDATE_LIB_DIR for uninstall
#   TK_UNINSTALL_FILE_SRC — same as TK_UPDATE_FILE_SRC for uninstall
#   TK_BRIDGE_TTY_SRC    — feeds drift-prompt answers via here-doc tempfile
#   TK_UNINSTALL_TTY_FROM_STDIN — feeds uninstall [y/N/d] answers via stdin
#
# Usage: bash scripts/tests/test-bridges-sync.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "unexpected pattern present: $pattern"
    else
        assert_pass "$label"
    fi
}

# Global sandbox cleanup tracker.
_SANDBOXES=()
_cleanup_sandboxes() {
    local d
    for d in "${_SANDBOXES[@]+"${_SANDBOXES[@]}"}"; do
        [[ -d "$d" ]] && rm -rf "${d:?}"
    done
}
trap '_cleanup_sandboxes' EXIT

mk_sandbox() {
    local d
    d="$(mktemp -d /tmp/test-bridges-sync.XXXXXX)"
    mkdir -p "$d/.claude"
    _SANDBOXES+=("$d")
    echo "$d"
}

# Source bridges.sh + state.sh once at the top level (avoid RETURN-trap pitfall
# from sourcing inside a function — see test-bridges-foundation.sh:73-79).
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/state.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/bridges.sh"

# ────────────────────────── helpers ──────────────────────────

# install_seed <sandbox> — prepare a sandboxed install with a CLAUDE.md +
# project bridge (gemini) + populated bridges[] state. Sets TK_BRIDGE_HOME
# globally so subsequent helper calls share the sandbox.
install_seed() {
    local sandbox="$1"
    export TK_BRIDGE_HOME="$sandbox"
    mkdir -p "$sandbox/.claude" "$sandbox/project"
    # Seed source CLAUDE.md (project root)
    cat > "$sandbox/project/CLAUDE.md" <<'CLAUDE'
# Project CLAUDE
Initial content.
CLAUDE
    # Seed minimal toolkit-install.json (so write_state defaults find it)
    cat > "$sandbox/.claude/toolkit-install.json" <<'STATE'
{
  "version": 2,
  "mode": "standalone",
  "installed_files": [],
  "skipped_files": [],
  "bridges": []
}
STATE
    # Create bridge via API
    bridge_create_project gemini "$sandbox/project" >/dev/null
}

# tty_seed <answer> — write a single-line answer file for TK_BRIDGE_TTY_SRC
# (the drift-prompt TTY override). Echoes the path on stdout.
tty_seed() {
    local ans="$1"
    local f
    f="$(mktemp /tmp/bridges-sync-tty.XXXXXX)"
    printf '%s\n' "$ans" > "$f"
    echo "$f"
}

# run_update — invoke update-claude.sh with all hermetic seams set.
run_update() {
    local sandbox="$1"; shift
    TK_UPDATE_HOME="$sandbox" \
    TK_BRIDGE_HOME="$sandbox" \
    TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UPDATE_MANIFEST_OVERRIDE="$REPO_ROOT/manifest.json" \
    TK_UPDATE_FILE_SRC="$REPO_ROOT" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    NO_BANNER=1 \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-offer-mode-switch --no-prune "$@" 2>&1
}

# run_uninstall — invoke uninstall.sh with all hermetic seams set.
run_uninstall() {
    local sandbox="$1"; shift
    TK_UNINSTALL_HOME="$sandbox" \
    TK_BRIDGE_HOME="$sandbox" \
    HOME="$sandbox" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_FILE_SRC="$REPO_ROOT" \
    bash "$REPO_ROOT/scripts/uninstall.sh" "$@" 2>&1
}

# ────────────────────────── scenarios ──────────────────────────

scenario_s1_clean_noop() {
    echo "── S1: clean source/bridge match → silent no-op ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    local out
    out=$(run_update "$sb" || true)
    assert_not_contains "\[~ UPDATE\]" "$out" "S1: no [~ UPDATE] when bridge in-sync"
    assert_not_contains "\[~ MODIFIED\]" "$out" "S1: no [~ MODIFIED] when bridge in-sync"
    assert_not_contains "\[? ORPHANED\]" "$out" "S1: no [? ORPHANED] when source present"
}

scenario_s2_source_edited() {
    echo "── S2: source edited → [~ UPDATE] ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    # Edit source CLAUDE.md
    echo "Added line." >> "$sb/project/CLAUDE.md"
    local out
    out=$(run_update "$sb" || true)
    assert_contains "\[~ UPDATE\]" "$out" "S2: [~ UPDATE] log on source edit"
    # State refresh: source_sha256 in bridges[] should match new file SHA
    local new_src_sha state_src_sha
    new_src_sha=$(sha256_file "$sb/project/CLAUDE.md")
    state_src_sha=$(jq -r '.bridges[0].source_sha256' "$sb/.claude/toolkit-install.json")
    assert_eq "$new_src_sha" "$state_src_sha" "S2: bridges[].source_sha256 refreshed"
}

scenario_s3a_bridge_edited_y() {
    echo "── S3a: bridge edited, drift prompt y → overwrite ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    echo "User edit to bridge." >> "$sb/project/GEMINI.md"
    local tty; tty=$(tty_seed "y")
    local out
    out=$(TK_BRIDGE_TTY_SRC="$tty" run_update "$sb" || true)
    rm -f "$tty"
    assert_contains "\[~ UPDATE\]" "$out" "S3a: [~ UPDATE] after y on drift prompt"
    # Bridge content should no longer contain "User edit"
    if grep -q "User edit to bridge." "$sb/project/GEMINI.md"; then
        assert_fail "S3a: bridge still contains user edit (overwrite failed)" "found in $sb/project/GEMINI.md"
    else
        assert_pass "S3a: user edit overwritten by rewrite"
    fi
}

scenario_s3b_bridge_edited_n() {
    echo "── S3b: bridge edited, drift prompt N → keep ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    echo "User edit retained." >> "$sb/project/GEMINI.md"
    local tty; tty=$(tty_seed "N")
    local out
    out=$(TK_BRIDGE_TTY_SRC="$tty" run_update "$sb" || true)
    rm -f "$tty"
    assert_contains "\[~ MODIFIED\]" "$out" "S3b: [~ MODIFIED] after N on drift prompt"
    if grep -q "User edit retained." "$sb/project/GEMINI.md"; then
        assert_pass "S3b: user edit preserved"
    else
        assert_fail "S3b: user edit lost (keep failed)" "$sb/project/GEMINI.md"
    fi
}

scenario_s4_break_bridge() {
    echo "── S4: --break-bridge gemini → user_owned=true → SKIP ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    run_update "$sb" --break-bridge gemini >/dev/null 2>&1 || true
    local user_owned
    user_owned=$(jq -r '.bridges[0].user_owned' "$sb/.claude/toolkit-install.json")
    assert_eq "true" "$user_owned" "S4: --break-bridge flips user_owned=true"
    # Now edit source and run again — should SKIP (no UPDATE)
    echo "Source change after break." >> "$sb/project/CLAUDE.md"
    local out2
    out2=$(run_update "$sb" || true)
    assert_contains "\[- SKIP\]" "$out2" "S4: subsequent run logs [- SKIP] for broken bridge"
    assert_not_contains "\[~ UPDATE\]" "$out2" "S4: subsequent run does NOT [~ UPDATE] broken bridge"
}

scenario_s5_restore_bridge() {
    echo "── S5: --restore-bridge gemini → user_owned=false → re-sync ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    run_update "$sb" --break-bridge gemini >/dev/null 2>&1 || true
    run_update "$sb" --restore-bridge gemini >/dev/null 2>&1 || true
    local user_owned
    user_owned=$(jq -r '.bridges[0].user_owned' "$sb/.claude/toolkit-install.json")
    assert_eq "false" "$user_owned" "S5: --restore-bridge flips user_owned=false"
    # Edit source and run — should now [~ UPDATE]
    echo "Re-synced." >> "$sb/project/CLAUDE.md"
    local out
    out=$(run_update "$sb" || true)
    assert_contains "\[~ UPDATE\]" "$out" "S5: post-restore run [~ UPDATE]s"
}

scenario_s6_orphan() {
    echo "── S6: source deleted → [? ORPHANED] + auto-flip user_owned ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    rm -f "$sb/project/CLAUDE.md"
    local out
    out=$(run_update "$sb" || true)
    assert_contains "\[? ORPHANED\]" "$out" "S6: [? ORPHANED] log on missing source"
    local user_owned
    user_owned=$(jq -r '.bridges[0].user_owned' "$sb/.claude/toolkit-install.json")
    assert_eq "true" "$user_owned" "S6: orphan auto-flips user_owned=true"
}

scenario_s7_uninstall_clean() {
    echo "── S7: uninstall.sh clean bridge → REMOVE + bridges[] entry purged ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    local out
    out=$(run_uninstall "$sb" 2>&1 || true)
    if [[ -f "$sb/project/GEMINI.md" ]]; then
        assert_fail "S7: bridge file still exists after uninstall" "$sb/project/GEMINI.md"
    else
        assert_pass "S7: bridge file removed"
    fi
    # State file deleted entirely (no --keep-state) — bridges[] effectively purged
    if [[ ! -f "$sb/.claude/toolkit-install.json" ]]; then
        assert_pass "S7: toolkit-install.json removed → bridges[] gone"
    else
        # If state survives (some other invariant), bridges[] must be empty
        local n
        n=$(jq -r '.bridges // [] | length' "$sb/.claude/toolkit-install.json")
        assert_eq "0" "$n" "S7: bridges[] purged"
    fi
}

scenario_s8_uninstall_modified_keep() {
    echo "── S8: uninstall.sh modified bridge + N → kept, no purge ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    echo "Local edit." >> "$sb/project/GEMINI.md"
    local out
    out=$(TK_UNINSTALL_TTY_FROM_STDIN=1 run_uninstall "$sb" --keep-state <<< "N" 2>&1 || true)
    if [[ -f "$sb/project/GEMINI.md" ]]; then
        assert_pass "S8: modified bridge kept after N response"
    else
        assert_fail "S8: modified bridge unexpectedly removed" "$sb/project/GEMINI.md"
    fi
    # bridges[] entry must persist (user kept the file, state preserved via --keep-state)
    local n
    n=$(jq -r '.bridges // [] | length' "$sb/.claude/toolkit-install.json")
    assert_eq "1" "$n" "S8: bridges[] entry preserved when file kept"
}

scenario_s9_uninstall_keep_state() {
    echo "── S9: uninstall.sh --keep-state → bridge removed BUT bridges[] preserved ──"
    local sb; sb=$(mk_sandbox); install_seed "$sb"
    local out
    out=$(run_uninstall "$sb" --keep-state 2>&1 || true)
    # Bridge file removed (REMOVE_LIST processed in --keep-state path)
    if [[ -f "$sb/project/GEMINI.md" ]]; then
        assert_fail "S9: bridge file should still be removed under --keep-state" "$sb/project/GEMINI.md"
    else
        assert_pass "S9: bridge file removed under --keep-state"
    fi
    # State file preserved AND bridges[] entry preserved (BRIDGE-UN-02)
    if [[ -f "$sb/.claude/toolkit-install.json" ]]; then
        local n
        n=$(jq -r '.bridges // [] | length' "$sb/.claude/toolkit-install.json")
        assert_eq "1" "$n" "S9: bridges[] entry preserved under --keep-state (BRIDGE-UN-02)"
    else
        assert_fail "S9: state file unexpectedly deleted under --keep-state" ""
    fi
}

scenario_s10_backcompat() {
    echo "── S10: BACKCOMPAT-01 — Phase 24/26/28 tests still PASS ──"
    local out
    out=$(bash "$REPO_ROOT/scripts/tests/test-bootstrap.sh" 2>&1 || true)
    assert_contains "PASS=26 FAIL=0" "$out" "S10a: test-bootstrap.sh PASS=26 FAIL=0 unchanged"
    out=$(bash "$REPO_ROOT/scripts/tests/test-install-tui.sh" 2>&1 || true)
    assert_contains "PASS=43 FAIL=0" "$out" "S10b: test-install-tui.sh PASS=43 FAIL=0 unchanged"
    out=$(bash "$REPO_ROOT/scripts/tests/test-bridges-foundation.sh" 2>&1 || true)
    assert_contains "PASS=5 FAIL=0" "$out" "S10c: test-bridges-foundation.sh PASS=5 FAIL=0 unchanged"
}

# ────────────────────────── run all scenarios ──────────────────────────

scenario_s1_clean_noop
scenario_s2_source_edited
scenario_s3a_bridge_edited_y
scenario_s3b_bridge_edited_n
scenario_s4_break_bridge
scenario_s5_restore_bridge
scenario_s6_orphan
scenario_s7_uninstall_clean
scenario_s8_uninstall_modified_keep
scenario_s9_uninstall_keep_state
scenario_s10_backcompat

echo ""
echo "Phase 29 sync test complete: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
