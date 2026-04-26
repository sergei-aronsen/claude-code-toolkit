#!/usr/bin/env bash
# test-uninstall-backup.sh — UN-04 backup-before-delete + UN-01 hash-match delete contract.
#
# Assertions (12 total):
#   A1.  Non-dry-run exits 0
#   A2.  Backup directory created (exactly 1 match for .claude-backup-pre-uninstall-*)
#   A3.  Backup contains commands/clean.md (proves cp -R worked)
#   A4.  Backup contains toolkit-install.json.snapshot (UN-04 snapshot clause)
#   A5.  REMOVE-clean file deleted from sandbox (.claude/commands/clean.md absent post-run)
#   A6.  MODIFIED file preserved (deferred to 18-04) — agents/edited.md still present + byte-identical
#   A7.  PROTECTED base-plugin file untouched (byte-identical SHA pre/post)
#   A8.  Output contains "DELETED 1"
#   A9.  Output contains "BACKED UP"
#   A10. Output contains "KEPT 1" (18-04 [y/N/d] prompt fail-closed N → KEEP_LIST)
#   A11. Lock dir cleaned up (released) after exit
#   A12. list_backup_dirs (scripts/lib/backup.sh) enumerates the new backup dir
#
# Usage: bash scripts/tests/test-uninstall-backup.sh
# Exit:  0 = all 12 assertions passed, 1 = any failed

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

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

# cross-platform sha256
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# ─────────────────────────────────────────────────
# Sandbox setup
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/uninstall-backup.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude/commands" \
         "$SANDBOX/.claude/agents" \
         "$SANDBOX/.claude/get-shit-done"

# F1: REMOVE-clean — current SHA matches recorded SHA
printf 'x\n' > "$SANDBOX/.claude/commands/clean.md"
SHA_CLEAN="$(sha256_any "$SANDBOX/.claude/commands/clean.md")"

# F2: MODIFIED — current content differs from recorded SHA
printf 'user-edited\n' > "$SANDBOX/.claude/agents/edited.md"
SHA_EDITED_RECORDED="0000000000000000000000000000000000000000000000000000000000000000"

# F3: MISSING — registered in state but never created on disk
SHA_MISSING="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# F4: PROTECTED — inside get-shit-done tree; HOME overridden to $SANDBOX so
# is_protected_path checks $HOME/.claude/get-shit-done/ against sandbox path.
printf 'DO NOT DELETE\n' > "$SANDBOX/.claude/get-shit-done/should-not-touch.md"
# Compute its SHA256 before the uninstall run for post-run comparison.
PRE_GSD_HASH="$(sha256_any "$SANDBOX/.claude/get-shit-done/should-not-touch.md")"
# Record it in state with its ACTUAL sha256 so it would be classified REMOVE
# if protection logic were absent — this makes it a true defense-in-depth probe.
SHA_GSD="$(sha256_any "$SANDBOX/.claude/get-shit-done/should-not-touch.md")"

cat > "$SANDBOX/.claude/toolkit-install.json" <<EOF
{
  "version": 2,
  "mode": "standalone",
  "synthesized_from_filesystem": false,
  "detected": {
    "superpowers": {"present": false, "version": ""},
    "gsd":         {"present": false, "version": ""}
  },
  "installed_files": [
    {"path": ".claude/commands/clean.md",                  "sha256": "$SHA_CLEAN",          "installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/agents/edited.md",                   "sha256": "$SHA_EDITED_RECORDED","installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/skills/missing.md",                  "sha256": "$SHA_MISSING",        "installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/get-shit-done/should-not-touch.md",  "sha256": "$SHA_GSD",            "installed_at": "2026-04-26T00:00:00Z"}
  ],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF

# ─────────────────────────────────────────────────
# Invoke non-dry-run uninstall
# ─────────────────────────────────────────────────
OUTPUT=""
RC=0
OUTPUT=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

# ─────────────────────────────────────────────────
# Assertions
# ─────────────────────────────────────────────────
echo ""
echo "Assertions:"

# A1: exit code 0
assert_eq "0" "$RC" "A1: non-dry-run exits 0"

# A2: exactly 1 backup directory created
BACKUP_COUNT="$(find "$SANDBOX" -maxdepth 1 -type d -name '.claude-backup-pre-uninstall-*' | wc -l | tr -d '[:space:]')"
assert_eq "1" "$BACKUP_COUNT" "A2: exactly 1 .claude-backup-pre-uninstall-* dir created"

# Resolve backup dir path for downstream assertions
BACKUP_PATH=""
if [ "$BACKUP_COUNT" -eq 1 ]; then
    BACKUP_PATH="$(find "$SANDBOX" -maxdepth 1 -type d -name '.claude-backup-pre-uninstall-*' | head -1)"
fi

# A3: backup contains commands/clean.md
if [ -n "$BACKUP_PATH" ] && [ -f "$BACKUP_PATH/commands/clean.md" ]; then
    assert_pass "A3: backup contains commands/clean.md (cp -R verified)"
else
    assert_fail "A3: backup contains commands/clean.md (cp -R verified)" "file absent in backup"
fi

# A4: backup contains toolkit-install.json.snapshot (UN-04 snapshot clause)
SNAP_COUNT="$(find "$SANDBOX" -maxdepth 3 -name 'toolkit-install.json.snapshot' | wc -l | tr -d '[:space:]')"
assert_eq "1" "$SNAP_COUNT" "A4: backup contains toolkit-install.json.snapshot"

# A5: REMOVE-clean file deleted from sandbox
if [ ! -f "$SANDBOX/.claude/commands/clean.md" ]; then
    assert_pass "A5: REMOVE-clean file deleted (commands/clean.md absent)"
else
    assert_fail "A5: REMOVE-clean file deleted (commands/clean.md absent)" "file still present"
fi

# A6: MODIFIED file preserved (deferred to 18-04)
if [ -f "$SANDBOX/.claude/agents/edited.md" ]; then
    EDITED_CONTENT="$(cat "$SANDBOX/.claude/agents/edited.md")"
    if [ "$EDITED_CONTENT" = "user-edited" ]; then
        assert_pass "A6: MODIFIED file preserved with original content (agents/edited.md)"
    else
        assert_fail "A6: MODIFIED file preserved with original content (agents/edited.md)" \
            "content changed: '$EDITED_CONTENT'"
    fi
else
    assert_fail "A6: MODIFIED file preserved with original content (agents/edited.md)" \
        "file was deleted (should have been kept)"
fi

# A7: PROTECTED base-plugin file untouched (byte-identical SHA)
if [ -f "$SANDBOX/.claude/get-shit-done/should-not-touch.md" ]; then
    POST_GSD_HASH="$(sha256_any "$SANDBOX/.claude/get-shit-done/should-not-touch.md")"
    if [ "$PRE_GSD_HASH" = "$POST_GSD_HASH" ]; then
        assert_pass "A7: PROTECTED file untouched (SHA identical pre/post)"
    else
        assert_fail "A7: PROTECTED file untouched (SHA identical pre/post)" \
            "SHA changed: pre=$PRE_GSD_HASH post=$POST_GSD_HASH"
    fi
else
    assert_fail "A7: PROTECTED file untouched (SHA identical pre/post)" \
        "file was deleted (PROTECTED invariant violated)"
fi

# A8: output contains "DELETED 1"
assert_contains 'DELETED 1' "$OUTPUT" "A8: output contains 'DELETED 1'"

# A9: output contains "BACKED UP"
assert_contains 'BACKED UP' "$OUTPUT" "A9: output contains 'BACKED UP'"

# A10: MODIFIED file kept after fail-closed N prompt (18-04 adds [y/N/d]; /dev/tty
# unavailable in non-interactive test → fail-closed N → KEEP_LIST → "KEPT 1")
assert_contains 'KEPT 1' "$OUTPUT" "A10: output contains 'KEPT 1' (fail-closed N via prompt)"

# A11: lock dir cleaned up after exit
if [ ! -d "$SANDBOX/.claude/.toolkit-install.lock" ]; then
    assert_pass "A11: lock dir cleaned up after exit"
else
    assert_fail "A11: lock dir cleaned up after exit" \
        "lock dir still present: $SANDBOX/.claude/.toolkit-install.lock"
fi

# A12: list_backup_dirs (Task 0 integration) enumerates the new backup dir
LIST_OUTPUT=""
LIST_OUTPUT="$(
    # shellcheck source=/dev/null
    source "$REPO_ROOT/scripts/lib/backup.sh"
    list_backup_dirs "$SANDBOX"
)"
if printf '%s\n' "$LIST_OUTPUT" | grep -q '.claude-backup-pre-uninstall-'; then
    assert_pass "A12: list_backup_dirs enumerates .claude-backup-pre-uninstall-* dir"
else
    assert_fail "A12: list_backup_dirs enumerates .claude-backup-pre-uninstall-* dir" \
        "not found in list_backup_dirs output: $LIST_OUTPUT"
fi

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-backup: all 12 assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-backup: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output:"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
