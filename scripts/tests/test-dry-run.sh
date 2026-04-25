#!/bin/bash
# Claude Code Toolkit - test-dry-run.sh
# Asserts --dry-run grouped output format + zero filesystem writes (MODE-06).
# Usage: bash scripts/tests/test-dry-run.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INIT_LOCAL="$REPO_ROOT/scripts/init-local.sh"
[ -f "$INIT_LOCAL" ] || { echo "ERROR: init-local.sh not found"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-dry-run.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Cross-platform md5: macOS uses md5 -q, Linux uses md5sum
md5_any() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$@"
    else
        md5sum "$@" | awk '{print $1}'
    fi
}

# Snapshot a directory tree (returns hash of sorted file list + their hashes)
snapshot() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "empty"
        return
    fi
    find "$dir" -type f | sort | while IFS= read -r f; do
        printf '%s %s\n' "$f" "$(md5_any "$f")"
    done | md5_any
}

cd "$SCRATCH"
mkdir -p .claude

snapshot_before=$(snapshot "$SCRATCH/.claude")

# Run init-local.sh --dry-run --mode complement-sp
DRY_OUTPUT="$SCRATCH/dry_output.txt"
if bash "$INIT_LOCAL" --dry-run --mode complement-sp > "$DRY_OUTPUT" 2>&1; then
    report_pass "init-local.sh --dry-run --mode complement-sp exits 0"
else
    report_fail "init-local.sh --dry-run --mode complement-sp non-zero exit"
fi

snapshot_after=$(snapshot "$SCRATCH/.claude")
if [ "$snapshot_before" = "$snapshot_after" ]; then
    report_pass "dry-run: zero filesystem writes (snapshot identical)"
else
    report_fail "dry-run: filesystem changed during dry-run"
fi

if grep -qE '\[\+ INSTALL\]' "$DRY_OUTPUT"; then
    report_pass "dry-run output contains [+ INSTALL] lines"
else
    report_fail "dry-run output missing [+ INSTALL] lines"
fi

if grep -qE '\[SKIP' "$DRY_OUTPUT"; then
    report_pass "dry-run output contains [SKIP lines"
else
    report_fail "dry-run output missing [SKIP lines"
fi

if grep -qE '^Total:' "$DRY_OUTPUT"; then
    report_pass "dry-run output contains Total: footer"
else
    report_fail "dry-run output missing Total: footer"
fi

# ANSI auto-disable when stdout is not a tty: capture should have NO escape sequences
# (output redirected to file -> not a tty -> colors must be empty)
if grep -q $'\x1b\[' "$DRY_OUTPUT"; then
    report_fail "dry-run output contains ANSI escape codes when stdout is not a tty"
else
    report_pass "dry-run output is ANSI-clean when stdout is not a tty"
fi

# NO_COLOR=1 must suppress ANSI even on a TTY (no-color.org spec)
NO_COLOR_OUTPUT="$SCRATCH/no_color_output.txt"
NO_COLOR=1 bash "$INIT_LOCAL" --dry-run --mode complement-sp > "$NO_COLOR_OUTPUT" 2>&1 || true
if grep -q $'\x1b\[' "$NO_COLOR_OUTPUT"; then
    report_fail "NO_COLOR=1: dry-run output contains ANSI escape codes"
else
    report_pass "NO_COLOR=1: dry-run output is ANSI-clean"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
