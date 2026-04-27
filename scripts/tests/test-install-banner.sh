#!/usr/bin/env bash
# test-install-banner.sh — banner line presence gate (UN-07 / D-09).
#
# Source-greps each installer for the locked "To remove:" banner line.
# No network, no /tmp churn, runs in milliseconds.
#
# Assertions (7 total):
#   A1. scripts/init-claude.sh contains the locked banner line (exactly once)
#   A2. scripts/init-local.sh contains the locked banner line (exactly once)
#   A3. scripts/update-claude.sh contains the locked banner line (exactly once)
#   A4. scripts/init-claude.sh defines NO_BANNER=0 default                       (BANNER-01)
#   A5. scripts/init-claude.sh argparse contains --no-banner) NO_BANNER=1 clause (BANNER-01)
#   A6. scripts/init-claude.sh banner echo gated by [[ $NO_BANNER -eq 0 ]]       (BANNER-01)
#   A7. scripts/init-local.sh has all three patterns (default, clause, gate)     (BANNER-01)
#
# Usage: bash scripts/tests/test-install-banner.sh
# Exit:  0 = all 7 assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() {
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "$1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    printf "      %s\n" "$2"
}

BANNER='To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)'

check_banner() {
    local file="$1" label="$2"
    local count
    # grep -cF: fixed-string count. -F (no regex) so the URL is not interpreted.
    # 2>/dev/null masks "No such file" so we can format our own error message.
    # || true: grep -c returns 1 on zero matches; we always want count=0 in that case.
    count=$(grep -cF "$BANNER" "$REPO_ROOT/$file" 2>/dev/null || true)
    # If grep failed entirely (file missing), count may be empty — coerce to 0.
    count=${count:-0}
    if [ "$count" -eq 1 ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected exactly 1 match, got $count in $file"
    fi
}

echo "Running test-install-banner..."
echo ""

check_banner "scripts/init-claude.sh"   "A1: init-claude.sh contains banner line (exactly once)"
check_banner "scripts/init-local.sh"    "A2: init-local.sh contains banner line (exactly once)"
check_banner "scripts/update-claude.sh" "A3: update-claude.sh contains banner line (exactly once)"

# A4: init-claude.sh defines NO_BANNER=0 default (BANNER-01)
if grep -q '^NO_BANNER=0' "$REPO_ROOT/scripts/init-claude.sh"; then
    assert_pass "A4: init-claude.sh defines NO_BANNER=0 default"
else
    assert_fail "A4: init-claude.sh defines NO_BANNER=0 default" \
        "pattern '^NO_BANNER=0' not found in scripts/init-claude.sh"
fi

# A5: init-claude.sh argparse contains --no-banner) NO_BANNER=1 clause (BANNER-01)
if grep -q -- '--no-banner) NO_BANNER=1' "$REPO_ROOT/scripts/init-claude.sh"; then
    assert_pass "A5: init-claude.sh has --no-banner) NO_BANNER=1 clause"
else
    assert_fail "A5: init-claude.sh has --no-banner) NO_BANNER=1 clause" \
        "pattern '--no-banner) NO_BANNER=1' not found in scripts/init-claude.sh"
fi

# A6: init-claude.sh banner echo gated by [[ $NO_BANNER -eq 0 ]] (BANNER-01, R-04 direction-pin)
# shellcheck disable=SC2016  # single quotes intentional: grep literal '$NO_BANNER' in source file
if grep -q 'if \[\[ \$NO_BANNER -eq 0 \]\]' "$REPO_ROOT/scripts/init-claude.sh"; then
    assert_pass "A6: init-claude.sh banner gated by [[ \$NO_BANNER -eq 0 ]]"
else
    assert_fail "A6: init-claude.sh banner gated by [[ \$NO_BANNER -eq 0 ]]" \
        "pattern not found (check for inverted condition or wrong operator)"
fi

# A7: init-local.sh has all three patterns (BANNER-01)
# shellcheck disable=SC2016  # single quotes intentional: grep literal '$NO_BANNER' in source file
if grep -q '^NO_BANNER=0' "$REPO_ROOT/scripts/init-local.sh" && \
   grep -q -- '--no-banner) NO_BANNER=1' "$REPO_ROOT/scripts/init-local.sh" && \
   grep -q 'if \[\[ \$NO_BANNER -eq 0 \]\]' "$REPO_ROOT/scripts/init-local.sh"; then
    assert_pass "A7: init-local.sh has NO_BANNER=0, --no-banner clause, and gate"
else
    assert_fail "A7: init-local.sh has NO_BANNER=0, --no-banner clause, and gate" \
        "one or more patterns missing — check NO_BANNER=0 default, --no-banner) clause, if [[ \$NO_BANNER -eq 0 ]] gate"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-install-banner: all %d assertions passed${NC}\n" "$PASS"
    exit 0
else
    printf "${RED}✗ test-install-banner: %d of %d assertions FAILED${NC}\n" \
        "$FAIL" "$((PASS + FAIL))"
    exit 1
fi
