#!/bin/bash
# test-bridges.sh — v4.7 Multi-CLI Bridge aggregator (BRIDGE-TEST-01).
#
# Wraps the 3 hermetic bridge suites and emits a combined PASS=N FAIL=N summary.
#
# Usage: bash scripts/tests/test-bridges.sh
# Exit:  0 = all child suites green, 1 = any child suite failed
set -euo pipefail
cd "$(dirname "$0")/.."
PASS=0; FAIL=0
for suite in test-bridges-foundation.sh test-bridges-sync.sh test-bridges-install-ux.sh; do
    if bash "tests/$suite" >/tmp/bridges-out.$$ 2>&1; then
        last=$(tail -1 /tmp/bridges-out.$$)
        PASS=$((PASS + $(echo "$last" | grep -oE 'PASS=[0-9]+' | tail -1 | cut -d= -f2)))
        FAIL=$((FAIL + $(echo "$last" | grep -oE 'FAIL=[0-9]+' | tail -1 | cut -d= -f2)))
        echo "  ✓ $suite — $last"
    else
        echo "  ✗ $suite FAILED"
        cat /tmp/bridges-out.$$
        FAIL=$((FAIL + 1))
    fi
    rm -f /tmp/bridges-out.$$
done
echo "test-bridges (aggregate) complete: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
