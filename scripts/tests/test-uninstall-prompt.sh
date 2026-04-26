#!/usr/bin/env bash
# test-uninstall-prompt.sh — UN-03 [y/N/d] interactive prompt via stdin injection.
#
# Tests prompt_modified_for_uninstall() through the TK_UNINSTALL_TTY_FROM_STDIN seam.
# Three MODIFIED files exercise each branch:
#   commands/yes-remove.md      → choice "y"  → removed
#   commands/diff-then-keep.md  → choice "d" then "N" → diff rendered, kept
#   commands/empty-default.md   → empty input (default N) → kept
#
# Assertions (10 total):
#   A1.  Exit code 0
#   A2.  commands/yes-remove.md is DELETED (y branch)
#   A3.  commands/diff-then-keep.md is KEPT (d → N branch)
#   A4.  commands/empty-default.md is KEPT (default N branch)
#   A5.  Output contains "── diff: local vs reference" (d branch header)
#   A6.  Output contains "── end diff ──" (d branch footer)
#   A7.  Diff body has at least one +/- line (not headers) — proves non-trivial diff
#   A8.  Output contains "KEPT 2" (KEEP_LIST has 2 entries)
#   A9.  Output contains "DELETED 1" (only yes-remove)
#   A10. Backup directory created (UN-04 still holds)
#
# Usage: bash scripts/tests/test-uninstall-prompt.sh
# Exit:  0 = all 10 assertions passed, 1 = any failed

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
        printf '%s\n' "$haystack" | head -20 | sed 's/^/        /'
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
SANDBOX="$(mktemp -d /tmp/uninstall-prompt.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"
export TK_UNINSTALL_TTY_FROM_STDIN=1

# ── Live .claude/ sandbox (user's "current" versions — these are the modified files) ──
mkdir -p "$SANDBOX/.claude/commands"

printf 'user-edited yes-remove\n' > "$SANDBOX/.claude/commands/yes-remove.md"
printf 'user-edited diff-then-keep — LIVE VERSION\n' > "$SANDBOX/.claude/commands/diff-then-keep.md"
printf 'user-edited empty-default\n' > "$SANDBOX/.claude/commands/empty-default.md"

# ── Reference directory — DISTINCT content for diff-then-keep.md ──
# State file entries use the full relative path: ".claude/commands/diff-then-keep.md"
# prompt_modified_for_uninstall resolves:
#   $TK_UNINSTALL_FILE_SRC/$rel
#   = $SANDBOX/.reference / .claude/commands/diff-then-keep.md
#   = $SANDBOX/.reference/.claude/commands/diff-then-keep.md
# So TK_UNINSTALL_FILE_SRC must point to $SANDBOX/.reference (NOT .reference/.claude).
# The reference file sits at $SANDBOX/.reference/.claude/commands/diff-then-keep.md.
# Content is intentionally different from the live version so `diff -u` produces at
# least one body line starting with "+" or "-" (A7 closes W2).
mkdir -p "$SANDBOX/.reference/.claude/commands"
# NOTE: only diff-then-keep.md needs to be in the reference dir — the other two
# files never reach the d branch (yes-remove uses "y", empty-default uses "").
printf 'pristine reference content for diff-then-keep\nsecond line in reference only\n' \
    > "$SANDBOX/.reference/.claude/commands/diff-then-keep.md"

export TK_UNINSTALL_FILE_SRC="$SANDBOX/.reference"

# ── State file: all 3 files are MODIFIED (recorded SHA = zeros ≠ current SHA) ──
SHA_ZERO="0000000000000000000000000000000000000000000000000000000000000000"

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
    {"path": ".claude/commands/yes-remove.md",     "sha256": "$SHA_ZERO", "installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/commands/diff-then-keep.md", "sha256": "$SHA_ZERO", "installed_at": "2026-04-26T00:00:00Z"},
    {"path": ".claude/commands/empty-default.md",  "sha256": "$SHA_ZERO", "installed_at": "2026-04-26T00:00:00Z"}
  ],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF

# ─────────────────────────────────────────────────
# Invoke non-dry-run uninstall with injected stdin answers:
#   Line 1: "y"   → yes-remove.md (y branch → remove)
#   Line 2: "d"   → diff-then-keep.md (d branch → show diff)
#   Line 3: "N"   → diff-then-keep.md re-prompt after diff (N branch → keep)
#   Line 4: ""    → empty-default.md (empty input → default N → keep)
# ─────────────────────────────────────────────────
STDIN_INPUT=$(printf 'y\nd\nN\n\n')

OUTPUT=""
RC=0
OUTPUT=$(printf '%s' "$STDIN_INPUT" | \
    HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    TK_UNINSTALL_FILE_SRC="$SANDBOX/.reference" \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

# ─────────────────────────────────────────────────
# Assertions
# ─────────────────────────────────────────────────
echo ""
echo "Assertions:"

# A1: exit code 0
assert_eq "0" "$RC" "A1: uninstall exits 0"

# A2: yes-remove.md deleted (y branch)
if [ ! -f "$SANDBOX/.claude/commands/yes-remove.md" ]; then
    assert_pass "A2: commands/yes-remove.md DELETED (y branch)"
else
    assert_fail "A2: commands/yes-remove.md DELETED (y branch)" "file still present"
fi

# A3: diff-then-keep.md kept (d → N branch)
if [ -f "$SANDBOX/.claude/commands/diff-then-keep.md" ]; then
    assert_pass "A3: commands/diff-then-keep.md KEPT (d → N branch)"
else
    assert_fail "A3: commands/diff-then-keep.md KEPT (d → N branch)" "file was deleted"
fi

# A4: empty-default.md kept (default N branch)
if [ -f "$SANDBOX/.claude/commands/empty-default.md" ]; then
    assert_pass "A4: commands/empty-default.md KEPT (default N branch)"
else
    assert_fail "A4: commands/empty-default.md KEPT (default N branch)" "file was deleted"
fi

# A5: d branch header rendered
assert_contains '── diff: local vs reference' "$OUTPUT" \
    "A5: output contains diff header '── diff: local vs reference'"

# A6: d branch footer rendered
assert_contains '── end diff ──' "$OUTPUT" \
    "A6: output contains diff footer '── end diff ──'"

# A7 (W2 closure): diff body contains at least one non-header +/- line.
# diff -u file headers look like "+++ /path/to/file" and "--- /path/to/file".
# Change lines start with a single + or - followed by the changed content.
# We strip headers (lines starting with +++ or ---) and check what remains.
DIFF_BODY=$(printf '%s\n' "$OUTPUT" \
    | awk '/── diff: local vs reference/{p=1; next} /── end diff ──/{p=0} p' \
    | grep -E '^[+-]' \
    | grep -vE '^(\+\+\+|---)' || true)
if [ -n "$DIFF_BODY" ]; then
    assert_pass "A7: diff body has non-header +/- lines (non-trivial diff — W2 closed)"
else
    assert_fail "A7: diff body has non-header +/- lines (non-trivial diff — W2 closed)" \
        "diff body empty — reference appears identical to live file"
fi

# A8: KEPT 2 in output (diff-then-keep + empty-default both in KEEP_LIST)
assert_contains 'KEPT 2' "$OUTPUT" "A8: output contains 'KEPT 2' (2 files kept)"

# A9: DELETED 1 in output (only yes-remove)
assert_contains 'DELETED 1' "$OUTPUT" "A9: output contains 'DELETED 1' (1 file removed)"

# A10: backup directory created (UN-04 still holds)
BACKUP_COUNT="$(find "$SANDBOX" -maxdepth 1 -type d -name '.claude-backup-pre-uninstall-*' | wc -l | tr -d '[:space:]')"
assert_eq "1" "$BACKUP_COUNT" "A10: exactly 1 .claude-backup-pre-uninstall-* dir created (UN-04)"

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-prompt: all 10 assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-prompt: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output:"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
