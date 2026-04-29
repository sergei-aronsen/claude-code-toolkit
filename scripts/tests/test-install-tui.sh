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

# Global no-op script: exits 0 silently. Used as TK_DISPATCH_OVERRIDE_* value
# for dispatchers that should silently succeed in a given scenario.
# Cannot use ":" (shell builtin) — the override is passed to `bash <path>`.
_NOOP_SCRIPT="$(mktemp /tmp/test-install-tui-noop.XXXXXX)"
printf '#!/bin/bash\nexit 0\n' > "$_NOOP_SCRIPT"
chmod +x "$_NOOP_SCRIPT"
trap 'rm -f "$_NOOP_SCRIPT"' EXIT

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

# ─────────────────────────────────────────────────
# S3_yes — --yes bypasses TUI, dispatches all uninstalled in canonical order
# DISPATCH-03 + D-12 default-set
# ─────────────────────────────────────────────────
run_s3_yes() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_yes: --yes synthesizes default-set, mock dispatchers invoked --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # No installed components in clean sandbox.

    # Mock all six dispatchers.
    local MOCK_SP="$SANDBOX/mock-sp.sh"      ; mk_mock "$MOCK_SP"      "mock-sp-ran"      0
    local MOCK_GSD="$SANDBOX/mock-gsd.sh"    ; mk_mock "$MOCK_GSD"     "mock-gsd-ran"     0
    local MOCK_TK="$SANDBOX/mock-tk.sh"      ; mk_mock "$MOCK_TK"      "mock-tk-ran"      0
    local MOCK_SEC="$SANDBOX/mock-sec.sh"    ; mk_mock "$MOCK_SEC"     "mock-sec-ran"     0
    local MOCK_RTK="$SANDBOX/mock-rtk.sh"    ; mk_mock "$MOCK_RTK"     "mock-rtk-ran"     0
    local MOCK_SL="$SANDBOX/mock-sl.sh"      ; mk_mock "$MOCK_SL"      "mock-sl-ran"      0

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$MOCK_SP" \
        TK_DISPATCH_OVERRIDE_GSD="$MOCK_GSD" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        TK_DISPATCH_OVERRIDE_SECURITY="$MOCK_SEC" \
        TK_DISPATCH_OVERRIDE_RTK="$MOCK_RTK" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$MOCK_SL" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes 2>&1
    ) || RC=$?

    assert_eq      "0" "$RC"          "S3_yes: install.sh exits 0 with --yes"
    assert_contains "mock-tk-ran"     "$OUTPUT" "S3_yes: toolkit dispatcher invoked"
    assert_contains "mock-sec-ran"    "$OUTPUT" "S3_yes: security dispatcher invoked"
    assert_contains "Installed: 6"    "$OUTPUT" "S3_yes: summary shows 6 installed (DISPATCH-01 canonical order)"
}

# ─────────────────────────────────────────────────
# S4_dry_run — --dry-run zero-mutation contract (Nyquist signal 3)
# ─────────────────────────────────────────────────
run_s4_dry_run() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_dry_run: --yes --dry-run prints would-run, no dispatcher invoked --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # Mock dispatcher writes a sentinel file IF invoked.
    local SENTINEL="$SANDBOX/sentinel-toolkit"
    local MOCK_TK="$SANDBOX/mock-tk-sentinel.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$SENTINEL" > "$MOCK_TK"
    chmod +x "$MOCK_TK"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --dry-run 2>&1
    ) || RC=$?

    assert_eq           "0" "$RC"           "S4_dry_run: install.sh --yes --dry-run exits 0"
    assert_contains     "INSTALL.*toolkit"   "$OUTPUT" "S4_dry_run: prints [+ INSTALL] toolkit (would run)"
    # D-10 extension: under --dry-run, summary must show 'would-install', NOT 'installed checkmark'.
    # Calling it 'installed checkmark' would falsely claim work was done when nothing executed.
    assert_not_contains "installed" "$OUTPUT" "S4_dry_run: summary must NOT contain 'installed' state (false-positive guard)"
    assert_contains     "would-install"      "$OUTPUT" "S4_dry_run: summary contains 'would-install' state for dry-run dispatchers"
    if [[ -e "$SENTINEL" ]]; then
        assert_fail "S4_dry_run: dispatcher must NOT execute under --dry-run" \
            "sentinel file was created at $SENTINEL"
    else
        assert_pass "S4_dry_run: dispatcher NOT executed (zero-mutation contract)"
    fi
}

# ─────────────────────────────────────────────────
# S5_force — --force re-runs already-installed component
# D-14
# ─────────────────────────────────────────────────
run_s5_force() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_force: --yes --force re-runs already-installed toolkit --"

    # Pre-install toolkit (DET-05 condition).
    mkdir -p "$SANDBOX/.claude"
    echo '{"version":"4.4.0"}' > "$SANDBOX/.claude/toolkit-install.json"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    local MOCK_TK="$SANDBOX/mock-tk.sh"
    mk_mock "$MOCK_TK" "force-tk-ran" 0

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_GSD="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_SECURITY="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_RTK="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$_NOOP_SCRIPT" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --force 2>&1
    ) || RC=$?

    assert_eq       "0" "$RC"            "S5_force: install.sh --yes --force exits 0"
    assert_contains "force-tk-ran"        "$OUTPUT" "S5_force: toolkit dispatcher re-runs despite is_toolkit_installed=1"
}

# ─────────────────────────────────────────────────
# S6_fail_fast — --fail-fast stops on first failure
# D-09
# ─────────────────────────────────────────────────
run_s6_fail_fast() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_fail_fast: first dispatcher fails → orchestrator stops, exits 1 --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # SP dispatcher fails (exit 7); subsequent dispatchers should NOT run.
    local MOCK_SP_FAIL="$SANDBOX/mock-sp-fail.sh"
    mk_mock "$MOCK_SP_FAIL" "sp-failing" 7
    local MOCK_LATER_SENTINEL="$SANDBOX/sentinel-later"
    local MOCK_GSD_LATER="$SANDBOX/mock-gsd-later.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$MOCK_LATER_SENTINEL" > "$MOCK_GSD_LATER"
    chmod +x "$MOCK_GSD_LATER"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$MOCK_SP_FAIL" \
        TK_DISPATCH_OVERRIDE_GSD="$MOCK_GSD_LATER" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_SECURITY="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_RTK="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$_NOOP_SCRIPT" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --fail-fast 2>&1
    ) || RC=$?

    assert_eq       "1" "$RC"          "S6_fail_fast: install.sh exits 1 on first failure"
    assert_contains "failed" "$OUTPUT" "S6_fail_fast: summary shows failed status"
    if [[ -e "$MOCK_LATER_SENTINEL" ]]; then
        assert_fail "S6_fail_fast: GSD dispatcher MUST NOT run after SP fails (D-09)" \
            "sentinel created at $MOCK_LATER_SENTINEL"
    else
        assert_pass "S6_fail_fast: GSD dispatcher did not run after SP failure (D-09)"
    fi
}

# ─────────────────────────────────────────────────
# S7_no_tty — no TTY + no --yes → fail-closed exit 0
# D-11
# ─────────────────────────────────────────────────
run_s7_no_tty() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S7_no_tty: TK_TUI_TTY_SRC=/dev/null + no --yes → fail-closed --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # Mock all dispatchers as a sentinel-write so we can prove they didn't run.
    local SENTINEL="$SANDBOX/no-tty-sentinel"
    local MOCK_TK="$SANDBOX/mock-tk-notty.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$SENTINEL" > "$MOCK_TK"
    chmod +x "$MOCK_TK"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TUI_TTY_SRC=/dev/null \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" 2>&1
    ) || RC=$?

    assert_eq       "0" "$RC" "S7_no_tty: install.sh exits 0 (fail-closed)"
    if [[ -e "$SENTINEL" ]]; then
        assert_fail "S7_no_tty: dispatcher MUST NOT run when no TTY and no --yes" \
            "sentinel created at $SENTINEL"
    else
        assert_pass "S7_no_tty: dispatcher did not run (D-11 fail-closed contract)"
    fi
}

# ─────────────────────────────────────────────────
# S8_stderr_tail — D-28: failed components surface last 5 lines of stderr
# Mock dispatcher exits 1 after writing 6 stderr lines; assert summary
# contains lines 2..6 (the last 5) and NOT line 1 (truncated).
# ─────────────────────────────────────────────────
run_s8_stderr_tail() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S8_stderr_tail: failed dispatcher's last 5 stderr lines surface in summary --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # Mock dispatcher writes 6 distinct lines to stderr then exits 1.
    # Expected: summary contains line2..line6 (last 5); does NOT contain line1.
    local MOCK_TK_FAIL="$SANDBOX/mock-tk-stderr-fail.sh"
    cat > "$MOCK_TK_FAIL" <<'MOCK_EOF'
#!/bin/bash
printf 'line1-should-be-truncated\n' >&2
printf 'line2-tail\n'                 >&2
printf 'line3-tail\n'                 >&2
printf 'line4-tail\n'                 >&2
printf 'line5-tail\n'                 >&2
printf 'line6-tail\n'                 >&2
exit 1
MOCK_EOF
    chmod +x "$MOCK_TK_FAIL"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_GSD="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK_FAIL" \
        TK_DISPATCH_OVERRIDE_SECURITY="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_RTK="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$_NOOP_SCRIPT" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes 2>&1
    ) || RC=$?

    assert_eq           "1" "$RC"                     "S8_stderr_tail: install.sh exits 1 on dispatcher failure"
    assert_contains     "failed (exit 1)"  "$OUTPUT"  "S8_stderr_tail: summary shows 'failed (exit 1)' for toolkit"
    # Last 5 lines (line2..line6) MUST appear in summary tail output.
    assert_contains     "line2-tail"       "$OUTPUT"  "S8_stderr_tail: summary contains line2 (D-28 tail)"
    assert_contains     "line5-tail"       "$OUTPUT"  "S8_stderr_tail: summary contains line5 (D-28 tail)"
    assert_contains     "line6-tail"       "$OUTPUT"  "S8_stderr_tail: summary contains line6 (D-28 tail)"
    # First line MUST be truncated (only last 5 lines surface).
    assert_not_contains "line1-should-be-truncated" "$OUTPUT" "S8_stderr_tail: line1 truncated (D-28: only last 5 lines)"
}

# ─────────────────────────────────────────────────
# S9_no_tty_bootstrap_fork — D-05: when /dev/tty unreadable AND no --yes,
# install.sh sources lib/bootstrap.sh and invokes bootstrap_base_plugins
# for SP/GSD. TK components fail-closed (D-11). Identical to v4.4 behavior.
#
# Note: `read -p "prompt"` does not emit the prompt text to stdout/stderr when
# reading from a file (only on a real TTY). So we verify the fork ran via
# sentinel files: mock install commands write sentinel files; answering 'Y\nY\n'
# causes both commands to execute, proving bootstrap_base_plugins was invoked.
# ─────────────────────────────────────────────────
run_s9_no_tty_bootstrap_fork() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S9_no_tty_bootstrap_fork: D-05 fork to bootstrap.sh when no TTY + no --yes --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # Add a fake 'claude' binary so bootstrap.sh doesn't skip the SP prompt
    # due to "claude CLI not on PATH" guard (bootstrap.sh:81).
    printf '#!/bin/bash\nexit 0\n' > "$FAKE_BIN/claude"
    chmod +x "$FAKE_BIN/claude"

    # Mock SP/GSD install commands as sentinel writers.
    # Answering 'Y\nY\n' causes both commands to run, writing their sentinels.
    # Sentinel presence proves bootstrap_base_plugins was actually invoked and
    # the prompts were consumed from the fixture (D-05 fork ran successfully).
    local SP_SENTINEL="$SANDBOX/sp-install-ran"
    local GSD_SENTINEL="$SANDBOX/gsd-install-ran"
    local MOCK_SP_CMD="touch '$SP_SENTINEL'"
    local MOCK_GSD_CMD="touch '$GSD_SENTINEL'"

    # Inject 'Y\nY\n' — both prompts accepted, both install commands run.
    local ANSWER_FILE="$SANDBOX/bootstrap-answers"
    printf 'Y\nY\n' > "$ANSWER_FILE"

    # TK component dispatchers MUST NOT run under D-11 fail-closed.
    local TK_SENTINEL="$SANDBOX/tk-install-ran"
    local MOCK_TK="$SANDBOX/mock-tk-no-tty.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$TK_SENTINEL" > "$MOCK_TK"
    chmod +x "$MOCK_TK"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TUI_TTY_SRC="$SANDBOX/no-tty-device" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        TK_BOOTSTRAP_SP_CMD="$MOCK_SP_CMD" \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD_CMD" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        TK_DISPATCH_OVERRIDE_SECURITY="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_RTK="$_NOOP_SCRIPT" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$_NOOP_SCRIPT" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" 2>&1
    ) || RC=$?

    # D-05 contract assertions:
    assert_eq "0" "$RC" \
        "S9_no_tty_bootstrap_fork: install.sh exits 0 (fail-closed for TK, bootstrap fork for SP/GSD)"
    # SP sentinel proves bootstrap_base_plugins ran and SP prompt consumed 'Y'.
    if [[ -e "$SP_SENTINEL" ]]; then
        assert_pass "S9_no_tty_bootstrap_fork: SP install command ran (bootstrap fork invoked SP prompt, user answered Y)"
    else
        assert_fail "S9_no_tty_bootstrap_fork: SP install command did NOT run — bootstrap fork may not have executed" \
            "sentinel missing: $SP_SENTINEL"
    fi
    # GSD sentinel proves GSD prompt also consumed 'Y'.
    if [[ -e "$GSD_SENTINEL" ]]; then
        assert_pass "S9_no_tty_bootstrap_fork: GSD install command ran (bootstrap fork invoked GSD prompt, user answered Y)"
    else
        assert_fail "S9_no_tty_bootstrap_fork: GSD install command did NOT run — bootstrap GSD prompt may have failed" \
            "sentinel missing: $GSD_SENTINEL"
    fi
    # TK components MUST NOT have run (D-11 fail-closed).
    if [[ -e "$TK_SENTINEL" ]]; then
        assert_fail "S9_no_tty_bootstrap_fork: TK toolkit dispatcher MUST NOT run when no TTY and no --yes (D-11)" \
            "sentinel created at $TK_SENTINEL"
    else
        assert_pass "S9_no_tty_bootstrap_fork: TK toolkit dispatcher did NOT run (D-11 fail-closed for TK components)"
    fi
    # D-11 fail-closed message must appear in output.
    assert_contains "fail-closed" "$OUTPUT" \
        "S9_no_tty_bootstrap_fork: D-11 'fail-closed' message in output"
    # Summary must show all TK components as skipped (not dispatched).
    assert_contains "toolkit.*skipped" "$OUTPUT" \
        "S9_no_tty_bootstrap_fork: toolkit shows 'skipped' in summary (D-11 fail-closed)"
}

run_s1_detect
run_s2_detect
run_s3_yes
run_s4_dry_run
run_s5_force
run_s6_fail_fast
run_s7_no_tty
run_s8_stderr_tail
run_s9_no_tty_bootstrap_fork

echo ""
echo "test-install-tui complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
