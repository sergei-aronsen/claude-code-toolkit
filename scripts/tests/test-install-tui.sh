#!/usr/bin/env bash
# test-install-tui.sh — Phase 24 hermetic integration test.
#
# Scenarios (extended in Plan 04 to ≥15 total assertions):
#   S1_detect — clean HOME → all six is_*_installed return 1 (not installed)
#   S2_detect — populated HOME → each positive probe condition satisfied → 0
#   [Wave 3 / Plan 04 will add: S3_tui_keys, S4_yes_mode, S5_dry_run,
#    S6_force, S7_no_tty_fallback, S8_ctrlc_restore, S9_dispatch_order, etc.]
#
# Test seam env vars: TK_TUI_TTY_SRC (Plan 02), TK_DISPATCH_OVERRIDE_<NAME> (Plan 04)
#
# Usage: bash scripts/tests/test-install-tui.sh
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
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

# Helper: build a mock script in $1 that prints $2 then exits with code $3.
mk_mock() {
    local path="$1" message="$2" exit_code="${3:-0}"
    printf '#!/bin/bash\necho %q\nexit %s\n' "$message" "$exit_code" > "$path"
    chmod +x "$path"
}

echo "test-install-tui.sh: TUI-01..07, DET-01..05, DISPATCH-01..03 integration suite"
echo ""

# ─────────────────────────────────────────────────
# S1_detect — clean HOME → all six is_*_installed return 1 (not installed)
# DET-01..DET-05 negative path
# ─────────────────────────────────────────────────
run_s1_detect() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_detect: clean HOME → all probes return 1 --"

    # Empty $PATH override directory (no rtk, no cc-safety-net binary)
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # No ~/.claude at all in the clean sandbox.

    local SP GSD TK SEC RTK SL
    SP=0; GSD=0; TK=0; SEC=0; RTK=0; SL=0
    HOME="$SANDBOX" PATH="$FAKE_BIN:/usr/bin:/bin" \
        bash -c "
            source '$REPO_ROOT/scripts/lib/detect2.sh'
            is_superpowers_installed && echo SP=1 || echo SP=0
            is_gsd_installed         && echo GSD=1 || echo GSD=0
            is_toolkit_installed     && echo TK=1 || echo TK=0
            is_security_installed    && echo SEC=1 || echo SEC=0
            is_rtk_installed         && echo RTK=1 || echo RTK=0
            is_statusline_installed  && echo SL=1 || echo SL=0
        " > "$SANDBOX/probe.out" 2>/dev/null

    SP=$(grep '^SP='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    GSD=$(grep '^GSD=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    TK=$(grep '^TK='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SEC=$(grep '^SEC=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    RTK=$(grep '^RTK=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SL=$(grep '^SL='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)

    assert_eq "0" "$SP"  "S1_detect: SP=0 in clean HOME (DET-01)"
    assert_eq "0" "$GSD" "S1_detect: GSD=0 in clean HOME (DET-01)"
    assert_eq "0" "$TK"  "S1_detect: TK=0 in clean HOME (DET-05)"
    assert_eq "0" "$SEC" "S1_detect: SEC=0 in clean HOME (DET-02)"
    assert_eq "0" "$RTK" "S1_detect: RTK=0 in clean HOME (DET-04)"
    assert_eq "0" "$SL"  "S1_detect: SL=0 in clean HOME (DET-03)"
}

# ─────────────────────────────────────────────────
# S2_detect — populated HOME → each component's positive condition satisfied
# DET-02..DET-05 positive path (DET-01 SP/GSD verified separately by test-detect.sh)
# ─────────────────────────────────────────────────
run_s2_detect() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_detect: populated HOME → positive probes return 0 --"

    # DET-05: create toolkit-install.json
    mkdir -p "$SANDBOX/.claude"
    echo '{"version":"4.4.0"}' > "$SANDBOX/.claude/toolkit-install.json"

    # DET-03: create statusline.sh + settings.json with "statusLine" key
    echo '#!/bin/bash' > "$SANDBOX/.claude/statusline.sh"
    chmod +x "$SANDBOX/.claude/statusline.sh"
    printf '%s\n' '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}' \
        > "$SANDBOX/.claude/settings.json"

    # DET-02: mock cc-safety-net binary on PATH + write hook file referencing it
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    mk_mock "$FAKE_BIN/cc-safety-net" "fake-cc-safety-net" 0
    mkdir -p "$SANDBOX/.claude/hooks"
    printf '%s\n' '#!/bin/bash' 'cc-safety-net "$@"' > "$SANDBOX/.claude/hooks/pre-bash.sh"

    # DET-04: mock rtk binary on PATH
    mk_mock "$FAKE_BIN/rtk" "fake-rtk" 0

    local TK SEC RTK SL
    TK=0; SEC=0; RTK=0; SL=0
    HOME="$SANDBOX" PATH="$FAKE_BIN:/usr/bin:/bin" \
        bash -c "
            source '$REPO_ROOT/scripts/lib/detect2.sh'
            is_toolkit_installed     && echo TK=1 || echo TK=0
            is_security_installed    && echo SEC=1 || echo SEC=0
            is_rtk_installed         && echo RTK=1 || echo RTK=0
            is_statusline_installed  && echo SL=1 || echo SL=0
        " > "$SANDBOX/probe.out" 2>/dev/null

    TK=$(grep '^TK='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SEC=$(grep '^SEC=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    RTK=$(grep '^RTK=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SL=$(grep '^SL='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)

    assert_eq "1" "$TK"  "S2_detect: TK=1 with toolkit-install.json (DET-05)"
    assert_eq "1" "$SEC" "S2_detect: SEC=1 with cc-safety-net + pre-bash.sh wired (DET-02)"
    assert_eq "1" "$RTK" "S2_detect: RTK=1 with rtk on PATH (DET-04)"
    assert_eq "1" "$SL"  "S2_detect: SL=1 with statusline.sh + settings.json wired (DET-03)"
}

run_s1_detect
run_s2_detect

echo ""
echo "test-install-tui complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
