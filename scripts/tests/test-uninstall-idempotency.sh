#!/usr/bin/env bash
# test-uninstall-idempotency.sh — UN-06 idempotency contract for uninstall.sh.
#
# Assertions (5 total):
#   A1. No-op exits 0 when toolkit-install.json is absent
#   A2. Locked log message present: "Toolkit not installed; nothing to do"
#   A3. ✓ success prefix present (proves log_success, not log_info, was used)
#   A4. No .claude-backup-pre-uninstall-* directory created on no-op
#   A5. Zero new files created in sandbox after no-op (immediate exit proven)
#
# Usage: bash scripts/tests/test-uninstall-idempotency.sh
# Exit:  0 = all 5 assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# assert_pass <label> — record a pass
assert_pass() {
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "$1"
}

# assert_fail <label> <detail> — record a fail and print detail
assert_fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    printf "      %s\n" "$2"
}

# assert_eq <expected> <actual> <label>
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected='$expected' actual='$actual'"
    fi
}

# assert_contains <pattern> <haystack> <label>
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}

# ─────────────────────────────────────────────────
# Sandbox setup
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/uninstall-idempotency.XXXXXX)"
MARKER_FILE="/tmp/uninstall-idempotency-marker.$$"
touch "$MARKER_FILE"
trap 'rm -f "${MARKER_FILE:?}"; rm -rf "${SANDBOX:?}"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

# Create only the .claude directory shell — deliberately NO toolkit-install.json.
# Absence of the state file is the test premise that triggers the UN-06 no-op guard.
mkdir -p "$SANDBOX/.claude"

# ─────────────────────────────────────────────────
# Invoke uninstall (no-op path)
# ─────────────────────────────────────────────────
OUTPUT=""
RC=0
OUTPUT=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

# ─────────────────────────────────────────────────
# Assertions
# ─────────────────────────────────────────────────
echo ""
echo "Assertions:"

# A1: no-op exits 0
assert_eq "0" "$RC" "A1: no-op exits 0"

# A2: locked log message present (UN-06 contract surface, ROADMAP success criterion #3)
# Pattern excludes trailing period so cosmetic punctuation changes don't break this test.
assert_contains 'Toolkit not installed; nothing to do' "$OUTPUT" "A2: no-op message present"

# A3: ✓ success prefix present (proves log_success was used, not log_info)
# When stdout is captured via $(...) it is NOT a TTY so ANSI is stripped,
# but the literal ✓ glyph from log_success() is preserved.
assert_contains '✓ Toolkit not installed' "$OUTPUT" "A3: ✓ success prefix present"

# A4: no .claude-backup-pre-uninstall-* directory created (D-09 zero-side-effects)
BACKUP_COUNT="$(find "$SANDBOX" -maxdepth 2 \
    \( -name '.claude-backup-*' -o -name '.claude-backup-pre-uninstall-*' \) \
    -type d 2>/dev/null | wc -l | tr -d '[:space:]')"
assert_eq "0" "$BACKUP_COUNT" "A4: no .claude-backup-pre-uninstall-* created on no-op"

# A5: zero new files created anywhere in sandbox (proves D-07 immediate exit
#     before mktemp/lock/backup operations that would create temp files)
NEW_COUNT="$(find "$SANDBOX" -newer "$MARKER_FILE" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
assert_eq "0" "$NEW_COUNT" "A5: zero new files created in sandbox after no-op"

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-idempotency: all 5 assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-idempotency: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output:"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
