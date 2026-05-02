#!/usr/bin/env bash
# test-cli-installer.sh — Phase 35 (TEST-02) hermetic primitives test.
#
# Locks the CLI-01..04 contract for scripts/lib/cli-installer.sh primitives:
#   cli_detect <name>
#   cli_install <name> <darwin_cmd> <linux_cmd>
#   cli_post_install_hint <hint>
#
# Hermetic — uses TK_CLI_UNAME and TK_CLI_BREW_BIN test seams to mock platform
# and brew presence; never shells out to brew/npm/curl. Mirrors the harness
# shape of test-integrations-foundation.sh which already exercises a subset
# of these (S6-S12). This file re-exercises the same surface in isolation
# (per Phase 35 TEST-02 contract) plus adds the no-sudo-grep invariant and
# the empty-arg-rejection assertions not covered by the foundation test.
#
# Usage: bash scripts/tests/test-cli-installer.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB="${REPO_ROOT}/scripts/lib/cli-installer.sh"

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
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}

echo "test-cli-installer.sh: TEST-02 cli_detect / cli_install / cli_post_install_hint"
echo ""

# ─────────────────────────────────────────────────
# A1 — cli_detect bash returns 0 (real builtin path)
# ─────────────────────────────────────────────────
rc=0
bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_detect bash
" 2>/dev/null || rc=$?
assert_eq "0" "$rc" "A1: cli_detect bash returns 0"

# ─────────────────────────────────────────────────
# A2 — cli_detect on absent binary returns 1
# ─────────────────────────────────────────────────
rc=0
bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_detect __no_such_binary_xyz_pdq__ && exit 99 || exit \$?
" 2>/dev/null || rc=$?
assert_eq "1" "$rc" "A2: cli_detect on absent binary returns 1"

# ─────────────────────────────────────────────────
# A3 — cli_detect with empty arg returns 1 + writes error to stderr
# ─────────────────────────────────────────────────
out=""
rc=0
out=$(bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_detect '' && exit 99 || exit \$?
" 2>&1) || rc=$?
assert_eq "1" "$rc" "A3: cli_detect with empty arg returns 1"
assert_contains "missing argument" "$out" "A3: stderr mentions missing argument"

# ─────────────────────────────────────────────────
# A4 — cli_install Darwin runs darwin_cmd only
# ─────────────────────────────────────────────────
out=$(
    TK_CLI_UNAME=Darwin bash -c "
        # shellcheck disable=SC1091
        source '$LIB'
        cli_install fake-cli 'echo darwin-stub-ran' 'echo linux-stub-ran'
    " 2>&1
) || true
assert_contains "darwin-stub-ran" "$out" "A4: TK_CLI_UNAME=Darwin runs darwin_cmd"
assert_not_contains "linux-stub-ran" "$out" "A4: TK_CLI_UNAME=Darwin does NOT run linux_cmd"

# ─────────────────────────────────────────────────
# A5 — cli_install Linux runs linux_cmd only
# ─────────────────────────────────────────────────
out=$(
    TK_CLI_UNAME=Linux bash -c "
        # shellcheck disable=SC1091
        source '$LIB'
        cli_install fake-cli 'echo darwin-stub-ran' 'echo linux-stub-ran'
    " 2>&1
) || true
assert_contains "linux-stub-ran" "$out" "A5: TK_CLI_UNAME=Linux runs linux_cmd"
assert_not_contains "darwin-stub-ran" "$out" "A5: TK_CLI_UNAME=Linux does NOT run darwin_cmd"

# ─────────────────────────────────────────────────
# A6 — TK_CLI_UNAME=FreeBSD => exit 2 + stderr "unsupported platform"
# ─────────────────────────────────────────────────
rc=0
out=$(
    TK_CLI_UNAME=FreeBSD bash -c "
        # shellcheck disable=SC1091
        source '$LIB'
        cli_install fake-cli 'echo darwin-stub-ran' 'echo linux-stub-ran'
    " 2>&1
) || rc=$?
assert_eq "2" "$rc" "A6: unsupported platform returns rc=2"
assert_contains "unsupported platform" "$out" "A6: stderr mentions unsupported platform"
assert_contains "FreeBSD" "$out" "A6: stderr names the offending platform"

# ─────────────────────────────────────────────────
# A7 — Darwin + brew-prefixed darwin_cmd + brew absent => exit 3 + stderr hint
# ─────────────────────────────────────────────────
rc=0
out=$(
    TK_CLI_UNAME=Darwin TK_CLI_BREW_BIN="" bash -c "
        # shellcheck disable=SC1091
        source '$LIB'
        cli_install fake-cli 'brew install fake-cli' 'echo linux-not-ran'
    " 2>&1
) || rc=$?
assert_eq "3" "$rc" "A7: brew-prefixed darwin_cmd + brew absent returns rc=3"
assert_contains "brew not found" "$out" "A7: stderr hints brew not found"
assert_not_contains "linux-not-ran" "$out" "A7: linux_cmd never ran on Darwin"

# ─────────────────────────────────────────────────
# A8 — Darwin + brew-prefixed darwin_cmd + brew present => darwin_cmd runs (rc=0)
# We mock TK_CLI_BREW_BIN to a known existing path and replace the brew
# command body with a stub via setting TK_CLI_UNAME=Darwin and a fake darwin
# command that does NOT actually invoke brew (we're checking the gate, not
# the brew install itself). The library's brew-presence check uses
# TK_CLI_BREW_BIN's emptiness only as the gate.
# ─────────────────────────────────────────────────
rc=0
out=$(
    TK_CLI_UNAME=Darwin TK_CLI_BREW_BIN=/bin/sh bash -c "
        # shellcheck disable=SC1091
        source '$LIB'
        # darwin_cmd starts with 'brew ' so the gate fires; we override what
        # 'brew' resolves to by putting a stub on PATH that just echoes.
        STUB_DIR=\$(mktemp -d /tmp/cli-installer-stub.XXXXXX)
        printf '#!/bin/sh\necho brew-stub-ran \"\$@\"\n' > \"\$STUB_DIR/brew\"
        chmod +x \"\$STUB_DIR/brew\"
        export PATH=\"\$STUB_DIR:\$PATH\"
        cli_install fake-cli 'brew install fake-cli' 'echo linux-not-ran'
        rc=\$?
        rm -rf \"\$STUB_DIR\"
        exit \$rc
    " 2>&1
) || rc=$?
assert_eq "0" "$rc" "A8: brew-prefixed darwin_cmd + brew present returns rc=0"
assert_contains "brew-stub-ran" "$out" "A8: brew darwin_cmd actually ran"

# ─────────────────────────────────────────────────
# A9 — cli_post_install_hint writes to stderr only; stdout stays empty
# ─────────────────────────────────────────────────
SANDBOX=$(mktemp -d /tmp/cli-installer-test.XXXXXX)
trap 'rm -rf "${SANDBOX:?}"' EXIT
stdout_file="$SANDBOX/out"
stderr_file="$SANDBOX/err"
bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_post_install_hint 'wrangler login'
" >"$stdout_file" 2>"$stderr_file"
stdout_content=$(cat "$stdout_file")
stderr_content=$(cat "$stderr_file")
assert_eq "" "$stdout_content" "A9: stdout empty after cli_post_install_hint"
assert_contains "wrangler login" "$stderr_content" "A9: stderr contains the hint"
assert_contains "Next:" "$stderr_content" "A9: stderr contains 'Next:' prefix"

# ─────────────────────────────────────────────────
# A10 — cli_post_install_hint with empty arg is a silent no-op (rc=0)
# ─────────────────────────────────────────────────
rc=0
out=$(bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_post_install_hint ''
" 2>&1) || rc=$?
assert_eq "0" "$rc" "A10: cli_post_install_hint with empty arg returns 0"
assert_eq "" "$out" "A10: cli_post_install_hint with empty arg writes nothing"

# ─────────────────────────────────────────────────
# A11 — cli_install with missing args returns 1 + writes usage to stderr
# ─────────────────────────────────────────────────
rc=0
out=$(bash -c "
    # shellcheck disable=SC1091
    source '$LIB'
    cli_install '' '' ''
" 2>&1) || rc=$?
assert_eq "1" "$rc" "A11: cli_install with empty args returns 1"
assert_contains "usage:" "$out" "A11: stderr shows usage line"

# ─────────────────────────────────────────────────
# A12 — no `sudo` token in cli-installer.sh source (CLI-04 D-17 invariant).
# Ignore comment lines so the doc-block "No sudo auto-prefix EVER" doesn't
# trigger a false positive. We grep for sudo as a shell token only.
# ─────────────────────────────────────────────────
sudo_hits=$(grep -nE '^[[:space:]]*[^#]*\bsudo\b' "$LIB" || true)
if [[ -z "$sudo_hits" ]]; then
    assert_pass "A12: no executable sudo token in cli-installer.sh"
else
    assert_fail "A12: no executable sudo token in cli-installer.sh" "$sudo_hits"
fi

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
