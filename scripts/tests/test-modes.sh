#!/bin/bash
# Claude Code Toolkit - test-modes.sh
# Asserts compute_skip_set + recommend_mode against fixture manifest.
# Usage: bash scripts/tests/test-modes.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

INSTALL_LIB="$(cd "$(dirname "$0")/../lib" && pwd)/install.sh"
[ -f "$INSTALL_LIB" ] || { echo "ERROR: lib/install.sh not found at $INSTALL_LIB"; exit 1; }
FIXTURE="$(cd "$(dirname "$0")/fixtures" && pwd)/manifest-v2.json"
[ -f "$FIXTURE" ] || { echo "ERROR: fixture manifest not found at $FIXTURE"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-modes.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# shellcheck source=/dev/null
source "$INSTALL_LIB"

assert_skip_count() {
    local mode="$1" expected="$2"
    local out count
    out=$(compute_skip_set "$mode" "$FIXTURE")
    count=$(jq length <<< "$out")
    if [ "$count" -eq "$expected" ]; then
        report_pass "compute_skip_set $mode -> $count skips"
    else
        report_fail "compute_skip_set $mode -> expected $expected, got $count"
    fi
}

assert_recommend() {
    local sp="$1" gsd="$2" expected="$3"
    # recommend_mode reads $HAS_SP / $HAS_GSD from the environment at call time.
    # shellcheck disable=SC2034
    HAS_SP="$sp"
    # shellcheck disable=SC2034
    HAS_GSD="$gsd"
    local got
    got=$(recommend_mode)
    if [ "$got" = "$expected" ]; then
        report_pass "recommend_mode HAS_SP=$sp HAS_GSD=$gsd -> $got"
    else
        report_fail "recommend_mode HAS_SP=$sp HAS_GSD=$gsd -> expected $expected, got $got"
    fi
}

# MODE-04 - skip-set correctness against fixture (counts: 0 / 7 / 1 / 8)
assert_skip_count "standalone"      0
assert_skip_count "complement-sp"   7
assert_skip_count "complement-gsd"  1
assert_skip_count "complement-full" 8

# MODE-02 - recommendation logic (4 boolean combinations)
assert_recommend "true"  "true"  "complement-full"
assert_recommend "true"  "false" "complement-sp"
assert_recommend "false" "true"  "complement-gsd"
assert_recommend "false" "false" "standalone"

# MODE-04 - bogus mode rejected with stderr + return 1
err_output=$(compute_skip_set "bogus" "$FIXTURE" 2>&1 >/dev/null) || true
if echo "$err_output" | grep -q "ERROR: unknown mode: bogus"; then
    report_pass "compute_skip_set bogus -> returns error to stderr"
else
    report_fail "compute_skip_set bogus -> expected stderr error, got: $err_output"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
