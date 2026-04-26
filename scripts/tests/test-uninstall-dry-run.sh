#!/usr/bin/env bash
# test-uninstall-dry-run.sh — UN-02 zero-mutation contract for uninstall.sh --dry-run.
#
# Assertions (8 total):
#   1. --dry-run exits 0
#   2. [- REMOVE] group renders for clean-SHA file (1 file)
#   3. [? MODIFIED] group renders for user-edited file (1 file)
#   4. [? MISSING] group renders for absent registered file (1 file) — single-char "?" marker
#   5. Total: 3 files footer present
#   6. Zero new files created after dry-run (find -newer marker)
#   7. No .claude-backup-pre-uninstall-* directory created
#   8. State file contents unchanged (SHA256 digest identical pre/post)
#
# Usage: bash scripts/tests/test-uninstall-dry-run.sh
# Exit:  0 = all 8 assertions passed, 1 = any failed

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

# assert_contains <pattern> <haystack> <label>
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -qE -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}

# cross-platform sha256: prefer sha256sum (Linux), fall back to shasum -a 256 (macOS)
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
SANDBOX="$(mktemp -d /tmp/uninstall-dryrun.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude/commands" "$SANDBOX/.claude/agents"

# File 1: matches recorded SHA -> classified REMOVE
printf 'clean content\n' > "$SANDBOX/.claude/commands/clean.md"
SHA_CLEAN="$(sha256_any "$SANDBOX/.claude/commands/clean.md")"

# File 2: content differs from recorded SHA -> classified MODIFIED
printf 'user-edited content\n' > "$SANDBOX/.claude/agents/edited.md"
SHA_EDITED_RECORDED="0000000000000000000000000000000000000000000000000000000000000000"

# File 3: registered but not present on disk -> classified MISSING
SHA_MISSING="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

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
    {"path": ".claude/commands/clean.md",  "sha256": "$SHA_CLEAN",          "installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/agents/edited.md",   "sha256": "$SHA_EDITED_RECORDED","installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/skills/missing.md",  "sha256": "$SHA_MISSING",        "installed_at": "2026-04-26T00:00:00Z"}
  ],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF

# ─────────────────────────────────────────────────
# Capture pre-run state
# ─────────────────────────────────────────────────
MARKER_FILE="/tmp/uninstall-dryrun-marker.$$"
touch "$MARKER_FILE"
trap 'rm -f "$MARKER_FILE"; rm -rf "$SANDBOX"' EXIT

STATE_SHA_BEFORE="$(sha256_any "$SANDBOX/.claude/toolkit-install.json")"

# ─────────────────────────────────────────────────
# Invoke dry-run
# ─────────────────────────────────────────────────
OUTPUT=""
RC=0
OUTPUT=$(bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1) || RC=$?

# ─────────────────────────────────────────────────
# Assertions
# ─────────────────────────────────────────────────
echo ""
echo "Assertions:"

# 1. exits 0
if [ "$RC" -eq 0 ]; then
    assert_pass "--dry-run exits 0"
else
    assert_fail "--dry-run exits 0" "exit code was $RC"
fi

# 2. [- REMOVE] group with 1 file
assert_contains '^\[- REMOVE\][[:space:]]+1 files$' "$OUTPUT" "[- REMOVE] header shows 1 file"

# 3. [? MODIFIED] group with 1 file
assert_contains '^\[\? MODIFIED\][[:space:]]+1 files$' "$OUTPUT" "[? MODIFIED] header shows 1 file"

# 4. [? MISSING] group with 1 file — single-char "?" marker (corrected ROADMAP criterion #2)
assert_contains '^\[\? MISSING\][[:space:]]+1 files$' "$OUTPUT" "[? MISSING] header shows 1 file"

# 5. Total: 3 files footer
if printf '%s\n' "$OUTPUT" | grep -qF 'Total: 3 files'; then
    assert_pass "Total: 3 files footer present"
else
    assert_fail "Total: 3 files footer present" "line 'Total: 3 files' not found in output"
fi

# 6. Zero new files created (find -newer marker)
NEW_COUNT="$(find "$SANDBOX" -newer "$MARKER_FILE" -type f | wc -l | tr -d '[:space:]')"
if [ "$NEW_COUNT" -eq 0 ]; then
    assert_pass "zero new files created after dry-run (find -newer marker)"
else
    assert_fail "zero new files created after dry-run (find -newer marker)" \
        "$NEW_COUNT new file(s) found: $(find "$SANDBOX" -newer "$MARKER_FILE" -type f | head -5 | tr '\n' ' ')"
fi

# 7. No backup directory created
BACKUP_COUNT="$(find "$SANDBOX" -maxdepth 2 \( -name '.claude-backup-*' -o -name '.claude-backup-pre-uninstall-*' \) -type d | wc -l | tr -d '[:space:]')"
if [ "$BACKUP_COUNT" -eq 0 ]; then
    assert_pass "no .claude-backup-pre-uninstall-* directory created"
else
    assert_fail "no .claude-backup-pre-uninstall-* directory created" \
        "$BACKUP_COUNT backup dir(s) found"
fi

# 8. State file unchanged (SHA256 digest identical pre/post)
STATE_SHA_AFTER="$(sha256_any "$SANDBOX/.claude/toolkit-install.json")"
if [ "$STATE_SHA_BEFORE" = "$STATE_SHA_AFTER" ]; then
    assert_pass "toolkit-install.json unchanged after dry-run"
else
    assert_fail "toolkit-install.json unchanged after dry-run" \
        "SHA before=$STATE_SHA_BEFORE, after=$STATE_SHA_AFTER"
fi

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-dry-run: all 8 assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-dry-run: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output:"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
