#!/usr/bin/env bash
# test-install-banner.sh — banner line presence gate (UN-07 / D-09).
#
# Source-greps each installer for the locked "To remove:" banner line.
# No network, no /tmp churn, runs in milliseconds.
#
# Assertions (3 total):
#   A1. scripts/init-claude.sh contains the locked banner line (exactly once)
#   A2. scripts/init-local.sh contains the locked banner line (exactly once)
#   A3. scripts/update-claude.sh contains the locked banner line (exactly once)
#
# Usage: bash scripts/tests/test-install-banner.sh
# Exit:  0 = all 3 assertions passed, 1 = any failed

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

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-install-banner: all %d assertions passed${NC}\n" "$PASS"
    exit 0
else
    printf "${RED}✗ test-install-banner: %d of %d assertions FAILED${NC}\n" \
        "$FAIL" "$((PASS + FAIL))"
    exit 1
fi
