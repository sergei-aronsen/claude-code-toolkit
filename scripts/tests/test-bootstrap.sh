#!/usr/bin/env bash
# test-bootstrap.sh — BOOTSTRAP-01..04 hermetic integration test.
#
# Five scenarios:
#   S1 — y/y for both → mocks invoked, install continues
#   S2 — N/N for both → no mocks invoked
#   S3 — --no-bootstrap → no prompt rendered, byte-quiet (D-17)
#         + TK_NO_BOOTSTRAP=1 env-var form equivalent (D-16)
#   S4 — claude CLI missing → SP prompt suppressed with warn; GSD prompt still rendered
#   S5 — SP mock exits 1 (failure) → non-fatal, GSD prompt independent
#
# Total assertions: 26 (5 per scenario S1..S5 + 1 extra TK_NO_BOOTSTRAP coverage in S3)
# Test seam env vars: TK_BOOTSTRAP_SP_CMD, TK_BOOTSTRAP_GSD_CMD, TK_BOOTSTRAP_TTY_SRC, TK_NO_BOOTSTRAP
# Driver: bash scripts/init-local.sh (uses local repo paths; no GitHub curl)
#
# Usage: bash scripts/tests/test-bootstrap.sh
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

echo "test-bootstrap.sh: BOOTSTRAP-01..04 integration suite"
echo ""

# ─────────────────────────────────────────────────
# S1 — prompt y/y for both → mocks invoked, install continues
# ─────────────────────────────────────────────────
run_s1() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1: prompt y/y for both → mocks invoked --"

    local MOCK_SP="$SANDBOX/mock-sp.sh"
    local MOCK_GSD="$SANDBOX/mock-gsd.sh"
    mk_mock "$MOCK_SP"  "mock-sp-ran"  0
    mk_mock "$MOCK_GSD" "mock-gsd-ran" 0

    local ANSWER_FILE="$SANDBOX/answers"
    printf 'y\ny\n' > "$ANSWER_FILE"

    # Provide a fake `claude` on PATH so SP isn't suppressed by D-09.
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    mk_mock "$FAKE_BIN/claude" "fake-claude" 0

    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TEST=1 \
        TK_BOOTSTRAP_SP_CMD="$MOCK_SP" \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        bash "$REPO_ROOT/scripts/init-local.sh" --dry-run base 2>&1) || RC=$?

    assert_eq "0" "$RC" "S1: init-local exits 0"
    assert_contains "mock-sp-ran"  "$OUTPUT" "S1: SP mock invoked"
    assert_contains "mock-gsd-ran" "$OUTPUT" "S1: GSD mock invoked"
    assert_not_contains "install failed" "$OUTPUT" "S1: no install-failed warning"
    # Mocks don't actually create the SP/GSD dirs, so post-detect mode is still standalone.
    assert_contains "standalone" "$OUTPUT" "S1: post-bootstrap mode resolves (mocks don't install)"
}

# ─────────────────────────────────────────────────
# S2 — prompt N/N for both → no mocks invoked
# ─────────────────────────────────────────────────
run_s2() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2: prompt N/N for both → no mocks invoked --"

    local MOCK_SP="$SANDBOX/mock-sp.sh"
    local MOCK_GSD="$SANDBOX/mock-gsd.sh"
    mk_mock "$MOCK_SP"  "mock-sp-ran"  0
    mk_mock "$MOCK_GSD" "mock-gsd-ran" 0

    local ANSWER_FILE="$SANDBOX/answers"
    printf 'N\nN\n' > "$ANSWER_FILE"

    # Provide a fake `claude` on PATH so SP prompt renders (then user answers N).
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    mk_mock "$FAKE_BIN/claude" "fake-claude" 0

    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TEST=1 \
        TK_BOOTSTRAP_SP_CMD="$MOCK_SP" \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        bash "$REPO_ROOT/scripts/init-local.sh" --dry-run base 2>&1) || RC=$?

    assert_eq "0" "$RC" "S2: init-local exits 0"
    assert_not_contains "mock-sp-ran"  "$OUTPUT" "S2: SP mock NOT invoked (answer N)"
    assert_not_contains "mock-gsd-ran" "$OUTPUT" "S2: GSD mock NOT invoked (answer N)"
    assert_not_contains "install failed" "$OUTPUT" "S2: no install-failed warning"
    assert_contains "standalone" "$OUTPUT" "S2: post-bootstrap mode is standalone"
}

# ─────────────────────────────────────────────────
# S3 — --no-bootstrap byte-quiet (D-17) + TK_NO_BOOTSTRAP=1 equivalence (D-16)
# ─────────────────────────────────────────────────
run_s3() {
    local SANDBOX RC OUTPUT OUTPUT2
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3: --no-bootstrap byte-quiet (D-17) + TK_NO_BOOTSTRAP=1 (D-16) --"

    # First invocation: --no-bootstrap CLI flag form
    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        bash "$REPO_ROOT/scripts/init-local.sh" --no-bootstrap --dry-run base 2>&1) || RC=$?

    assert_eq "0" "$RC" "S3: exits 0 with --no-bootstrap"
    assert_not_contains "Install superpowers via plugin marketplace" "$OUTPUT" "S3: SP prompt NOT rendered (--no-bootstrap)"
    assert_not_contains "Install get-shit-done via curl install script" "$OUTPUT" "S3: GSD prompt NOT rendered (--no-bootstrap)"
    assert_not_contains "bootstrap skipped" "$OUTPUT" "S3: no 'bootstrap skipped' info line (byte-quiet)"
    assert_not_contains "install failed" "$OUTPUT" "S3: no failure warnings"

    # Second invocation: TK_NO_BOOTSTRAP=1 env-var form (D-16 equivalence)
    OUTPUT2=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        TK_NO_BOOTSTRAP=1 \
        bash "$REPO_ROOT/scripts/init-local.sh" --dry-run base 2>&1) || true
    assert_not_contains "Install superpowers via plugin marketplace" "$OUTPUT2" "S3: TK_NO_BOOTSTRAP=1 also suppresses SP prompt"
}

# ─────────────────────────────────────────────────
# S4 — claude CLI missing → SP suppressed with warn, GSD still renders
# ─────────────────────────────────────────────────
run_s4() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4: claude CLI missing → SP suppressed, GSD still renders --"

    local MOCK_GSD="$SANDBOX/mock-gsd.sh"
    mk_mock "$MOCK_GSD" "mock-gsd-ran" 0

    # Only one answer line — GSD prompt only (SP is suppressed due to missing claude CLI).
    local ANSWER_FILE="$SANDBOX/answers"
    printf 'y\n' > "$ANSWER_FILE"

    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        PATH="/usr/bin:/bin" \
        TK_TEST=1 \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        bash "$REPO_ROOT/scripts/init-local.sh" --dry-run base 2>&1) || RC=$?

    assert_eq "0" "$RC" "S4: init-local exits 0"
    assert_contains "claude CLI not on PATH" "$OUTPUT" "S4: claude-missing warning emitted"
    assert_not_contains "Install superpowers via plugin marketplace" "$OUTPUT" "S4: SP prompt NOT rendered (no claude CLI)"
    assert_contains "mock-gsd-ran" "$OUTPUT" "S4: GSD mock still invoked"
    assert_not_contains "install failed" "$OUTPUT" "S4: no install-failed warning"
}

# ─────────────────────────────────────────────────
# S5 — SP mock exits 1 (failure) → non-fatal, GSD prompt independent
# ─────────────────────────────────────────────────
run_s5() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5: SP mock exits 1 → non-fatal, GSD runs independently --"

    local MOCK_SP="$SANDBOX/mock-sp.sh"
    local MOCK_GSD="$SANDBOX/mock-gsd.sh"
    mk_mock "$MOCK_SP"  "mock-sp-ran"  1
    mk_mock "$MOCK_GSD" "mock-gsd-ran" 0

    local ANSWER_FILE="$SANDBOX/answers"
    printf 'y\ny\n' > "$ANSWER_FILE"

    # Provide a fake `claude` on PATH so SP prompt renders.
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    mk_mock "$FAKE_BIN/claude" "fake-claude" 0

    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TEST=1 \
        TK_BOOTSTRAP_SP_CMD="$MOCK_SP" \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        bash "$REPO_ROOT/scripts/init-local.sh" --dry-run base 2>&1) || RC=$?

    assert_eq "0" "$RC" "S5: init-local exits 0 (SP failure is non-fatal)"
    assert_contains "mock-sp-ran" "$OUTPUT" "S5: SP mock was invoked"
    assert_contains "superpowers install failed" "$OUTPUT" "S5: SP failure warning emitted"
    assert_contains "exit code 1" "$OUTPUT" "S5: failure warning shows exit code"
    assert_contains "mock-gsd-ran" "$OUTPUT" "S5: GSD mock still invoked (independent of SP)"
}

run_s1
echo ""
run_s2
echo ""
run_s3
echo ""
run_s4
echo ""
run_s5

echo ""
echo "Bootstrap test complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
