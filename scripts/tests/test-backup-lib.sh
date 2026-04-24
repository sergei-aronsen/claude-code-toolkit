#!/usr/bin/env bash
# test-backup-lib.sh — Unit tests for scripts/lib/backup.sh
#
# Tests:
#   1. Sourcing backup.sh into set -euo pipefail caller does not abort caller
#   2. list_backup_dirs() returns paths newest-epoch-first for a fixture HOME
#   3. list_backup_dirs() on empty HOME prints nothing and returns 0
#   4. warn_if_too_many_backups() at count=10 emits NO output
#   5. warn_if_too_many_backups() at count=11 emits one warning line
#   6. list_backup_dirs() silently ignores non-matching dirs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
BACKUP_SH="${LIB_DIR}/backup.sh"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  PASS: ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  PASS: ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: ${msg}"
        echo "    expected to contain: ${needle}"
        echo "    actual: ${haystack}"
    fi
}

assert_not_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if ! echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  PASS: ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: ${msg}"
        echo "    expected NOT to contain: ${needle}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-backup-lib.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# ─────────────────────────────────────────────────
echo ""
echo "Test 1: sourcing backup.sh does not abort set -euo pipefail caller"
echo "---"
OUT=$(bash -euo pipefail -c "source \"${BACKUP_SH}\"; echo sourced-ok" 2>&1 || true)
assert_contains "sourced-ok" "$OUT" "source inside set -euo pipefail exits 0 and prints sourced-ok"

# ─────────────────────────────────────────────────
echo ""
echo "Test 2: list_backup_dirs returns newest-epoch-first"
echo "---"
FIXTURE_HOME="${TMPDIR_ROOT}/fixture-home"
mkdir -p "${FIXTURE_HOME}"
# Create dirs: two regular backups + one pre-migrate
# Pre-migrate epoch 1713974420 is newest
mkdir -p "${FIXTURE_HOME}/.claude-backup-1713974410-999"
mkdir -p "${FIXTURE_HOME}/.claude-backup-1713974400-888"
mkdir -p "${FIXTURE_HOME}/.claude-backup-pre-migrate-1713974420"

OUT=$(bash -c "source \"${BACKUP_SH}\"; list_backup_dirs \"${FIXTURE_HOME}\"" 2>&1)
LINE1=$(echo "$OUT" | sed -n '1p')
LINE2=$(echo "$OUT" | sed -n '2p')
LINE3=$(echo "$OUT" | sed -n '3p')

assert_contains ".claude-backup-pre-migrate-1713974420" "$LINE1" "line 1 is pre-migrate (epoch 1713974420 — newest)"
assert_contains ".claude-backup-1713974410-999" "$LINE2" "line 2 is epoch 1713974410"
assert_contains ".claude-backup-1713974400-888" "$LINE3" "line 3 is epoch 1713974400 (oldest)"

# ─────────────────────────────────────────────────
echo ""
echo "Test 3: list_backup_dirs on empty HOME prints nothing"
echo "---"
EMPTY_HOME="${TMPDIR_ROOT}/empty-home"
mkdir -p "${EMPTY_HOME}"
OUT=$(bash -c "source \"${BACKUP_SH}\"; list_backup_dirs \"${EMPTY_HOME}\"" 2>&1 || true)
assert_eq "" "$OUT" "list_backup_dirs on empty HOME prints nothing"

# ─────────────────────────────────────────────────
echo ""
echo "Test 4: warn_if_too_many_backups at count=10 emits no output"
echo "---"
THRESH_HOME_10="${TMPDIR_ROOT}/thresh-10"
mkdir -p "${THRESH_HOME_10}"
for i in $(seq 1 10); do
    mkdir -p "${THRESH_HOME_10}/.claude-backup-171397440${i}-${i}"
done
OUT=$(HOME="${THRESH_HOME_10}" bash -c "source \"${BACKUP_SH}\"; warn_if_too_many_backups" 2>&1 || true)
assert_eq "" "$OUT" "count=10: no threshold warning emitted"

# ─────────────────────────────────────────────────
echo ""
echo "Test 5: warn_if_too_many_backups at count=11 emits one warning line"
echo "---"
THRESH_HOME_11="${TMPDIR_ROOT}/thresh-11"
mkdir -p "${THRESH_HOME_11}"
for i in $(seq 1 11); do
    mkdir -p "${THRESH_HOME_11}/.claude-backup-171397440${i}-${i}"
done
OUT=$(HOME="${THRESH_HOME_11}" bash -c "source \"${BACKUP_SH}\"; warn_if_too_many_backups" 2>&1 || true)
assert_contains "11 toolkit backup dirs" "$OUT" "count=11: warning line contains '11 toolkit backup dirs'"
assert_contains "update-claude.sh --clean-backups" "$OUT" "count=11: warning references --clean-backups"

# ─────────────────────────────────────────────────
echo ""
echo "Test 6: list_backup_dirs silently ignores non-matching dirs"
echo "---"
MIXED_HOME="${TMPDIR_ROOT}/mixed-home"
mkdir -p "${MIXED_HOME}"
mkdir -p "${MIXED_HOME}/.claude-backup-1713974400-111"    # valid
mkdir -p "${MIXED_HOME}/.claude-backup-malformed"         # invalid — no epoch
mkdir -p "${MIXED_HOME}/.claude-backup-pre-migrate-"     # invalid — no epoch
mkdir -p "${MIXED_HOME}/.myconfig"                        # invalid — unrelated
mkdir -p "${MIXED_HOME}/.claude"                          # invalid — not a backup

OUT=$(bash -c "source \"${BACKUP_SH}\"; list_backup_dirs \"${MIXED_HOME}\"" 2>&1)
LINE_COUNT=$(echo "$OUT" | grep -c '.' 2>/dev/null || echo "0")
assert_eq "1" "$LINE_COUNT" "only 1 valid dir returned (malformed + non-matching silently ignored)"
assert_contains ".claude-backup-1713974400-111" "$OUT" "valid dir is present in output"

# ─────────────────────────────────────────────────
echo ""
echo "Summary"
echo "======="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
