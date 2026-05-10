#!/usr/bin/env bash
# test-tui-no-back.sh — regression test for v6.16.0 Back-removal (T-08a).
#
# As of v6.16.0 the Back key (`b`/`B`) and TK_TUI_ALLOW_BACK env var are
# REMOVED from tui_checklist. The flow is linear; cancel happens via Ctrl+C
# or q/Q only. The Phase 36-A pre-collection state machine that used rc=4
# for Back is gone (T-08b).
#
# Asserts (3):
#   1. footer hint never contains "b back" regardless of TK_TUI_ALLOW_BACK
#   2. tui.sh source contains no `b|B)` case arm and no rc=4 emission
#   3. setting TK_TUI_ALLOW_BACK=1 has no effect (silently ignored)
#
# Usage: bash scripts/tests/test-tui-no-back.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TUI_SH="${REPO_ROOT}/scripts/lib/tui.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n      %s\n" "$1" "$2"; }
assert_not_contains() {
    local pat="$1" hay="$2" label="$3"
    if ! printf '%s\n' "$hay" | grep -Fq -- "$pat"; then assert_pass "$label"
    else assert_fail "$label" "unexpected pattern present: $pat"; fi
}

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/test-tui-no-back.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

# T1 — render footer with TK_TUI_ALLOW_BACK=1 → no "b back" hint.
OUT="$SANDBOX/render-with-allow.out"
: > "$OUT"
NO_COLOR=1 TERM=dumb TK_TUI_TTY_SRC="$OUT" TK_TUI_ALLOW_BACK=1 \
    bash -c "
        set -u
        source '$TUI_SH'
        TUI_LABELS=('alpha')
        TUI_GROUPS=('G')
        TUI_INSTALLED=(0)
        TUI_REQUIRED=(0)
        TUI_RESULTS=(0)
        TUI_DESCS=('d')
        FOCUS_IDX=0
        _tui_init_colors
        _tui_render
    " 2>/dev/null || true
RENDERED=$(cat "$OUT")
assert_not_contains "b back" "$RENDERED" \
    "T1: footer omits 'b back' even when TK_TUI_ALLOW_BACK=1"

# T2 — source-level guarantees: no `b|B)` arm, no `rc=4`, no `_back_hint`.
SRC=$(cat "$TUI_SH")
assert_not_contains "b|B)" "$SRC" "T2a: tui.sh has no b|B) case arm"
assert_not_contains "rc=4" "$SRC" "T2b: tui.sh emits no rc=4"
assert_not_contains "_back_hint" "$SRC" "T2c: tui.sh has no _back_hint variable"
assert_not_contains "TK_TUI_ALLOW_BACK" "$SRC" "T2d: tui.sh has no TK_TUI_ALLOW_BACK reference"

# T3 — covered by T2d (env var has no remaining read-site).

printf "\n  Passed: %d\n  Failed: %d\n\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
