#!/usr/bin/env bash
# test-flow-prequestions.sh — UX-FLOW-01 regression tests.
#
# Validates that install.sh's --mcps and --skills branches honour the
# TK_MCP_PRE_SELECTED / TK_SKILLS_PRE_SELECTED env contract that the new
# pre-collection main flow uses to drive headless sub-installs:
#
#   set + non-empty → install only the named items (skip own TUI)
#   set + empty     → install zero items (skip own TUI; do NOT fall back to TUI)
#   unset           → fall back to --yes default-set (this run uses --yes for
#                     hermeticity; the no-yes path requires a real TTY)
#
# Coverage:
#   M1 --mcps --dry-run + TK_MCP_PRE_SELECTED="context7,sentry"
#         → exactly 2 would-install rows (context7, sentry); other 7 = skipped
#   M2 --mcps --dry-run + TK_MCP_PRE_SELECTED="" (empty, exported)
#         → zero would-install rows; all 9 = skipped
#   M3 --mcps --dry-run + TK_MCP_PRE_SELECTED unset + --yes
#         → would-install rows match the default-set rule (≥1 would-install)
#   S1 --skills --dry-run + TK_SKILLS_PRE_SELECTED="firecrawl,shadcn" + --yes
#         → exactly 2 would-install rows
#   S2 --skills --dry-run + TK_SKILLS_PRE_SELECTED="" (empty, exported)
#         → zero would-install rows
#   S3 --skills --dry-run + TK_SKILLS_PRE_SELECTED unset + --yes
#         → 22 would-install rows (default-set baseline, mirrors S6 of
#           test-install-skills.sh)
#
# Usage: bash scripts/tests/test-flow-prequestions.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}

assert_ge() {
    local floor="$1" actual="$2" label="$3"
    if [ "$actual" -ge "$floor" ]; then assert_pass "$label"
    else assert_fail "$label" "expected >= $floor actual=$actual"; fi
}

_SANDBOXES=()
_cleanup_sandboxes() {
    local d
    for d in "${_SANDBOXES[@]+"${_SANDBOXES[@]}"}"; do
        case "$d" in
            /tmp/*) rm -rf "$d" 2>/dev/null || true ;;
        esac
    done
}
trap '_cleanup_sandboxes' EXIT

mk_sandbox() {
    local d
    d="$(mktemp -d /tmp/test-flow-prequestions.XXXXXX)"
    _SANDBOXES+=("$d")
    echo "$d"
}

# Count "would-install" rows in install.sh output (one per row in the dry-run summary).
_would_count() {
    grep -c "would-install" 2>/dev/null || true
}

# ────────────────────────── MCP scenarios ──────────────────────────

echo "=== M1: --mcps --dry-run + TK_MCP_PRE_SELECTED=\"context7,sentry\" ==="
sb=$(mk_sandbox)
out=$(
    TK_MCP_PRE_SELECTED="context7,sentry" \
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --dry-run 2>&1
)
m1_count=$(printf '%s\n' "$out" | _would_count)
assert_eq "2" "$m1_count" "M1.1 exactly 2 would-install rows"
# Spot-check the names appear next to would-install.
if printf '%s\n' "$out" | grep -E "context7.*would-install|would-install.*context7" >/dev/null; then
    assert_pass "M1.2 context7 row marked would-install"
else
    assert_fail "M1.2 context7 row marked would-install" "row not found in output"
fi
if printf '%s\n' "$out" | grep -E "sentry.*would-install|would-install.*sentry" >/dev/null; then
    assert_pass "M1.3 sentry row marked would-install"
else
    assert_fail "M1.3 sentry row marked would-install" "row not found in output"
fi

echo "=== M2: --mcps --dry-run + TK_MCP_PRE_SELECTED=\"\" (empty exported) ==="
sb=$(mk_sandbox)
out=$(
    TK_MCP_PRE_SELECTED="" \
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --dry-run 2>&1
)
m2_count=$(printf '%s\n' "$out" | _would_count)
assert_eq "0" "$m2_count" "M2.1 zero would-install rows when env=\"\""

echo "=== M3: --mcps --dry-run --yes + TK_MCP_PRE_SELECTED unset ==="
sb=$(mk_sandbox)
# Explicitly unset (in case parent shell exported it).
out=$(
    unset TK_MCP_PRE_SELECTED
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --dry-run --yes 2>&1
)
m3_count=$(printf '%s\n' "$out" | _would_count)
# Default-set picks all not-installed-and-not-OAuth-only — runner-dependent
# but always ≥1 on a fresh sandbox.
assert_ge 1 "$m3_count" "M3.1 default-set produces ≥1 would-install"

# ────────────────────────── Skills scenarios ──────────────────────────

echo "=== S1: --skills --dry-run + TK_SKILLS_PRE_SELECTED=\"firecrawl,shadcn\" ==="
sb=$(mk_sandbox)
out=$(
    TK_SKILLS_PRE_SELECTED="firecrawl,shadcn" \
    TK_SKILLS_HOME="$sb/skills" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --skills --dry-run 2>&1
)
s1_count=$(printf '%s\n' "$out" | _would_count)
assert_eq "2" "$s1_count" "S1.1 exactly 2 would-install rows"

echo "=== S2: --skills --dry-run + TK_SKILLS_PRE_SELECTED=\"\" (empty exported) ==="
sb=$(mk_sandbox)
out=$(
    TK_SKILLS_PRE_SELECTED="" \
    TK_SKILLS_HOME="$sb/skills" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --skills --dry-run 2>&1
)
s2_count=$(printf '%s\n' "$out" | _would_count)
assert_eq "0" "$s2_count" "S2.1 zero would-install rows when env=\"\""

echo "=== S3: --skills --dry-run --yes + TK_SKILLS_PRE_SELECTED unset (baseline) ==="
sb=$(mk_sandbox)
out=$(
    unset TK_SKILLS_PRE_SELECTED
    TK_SKILLS_HOME="$sb/skills" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    TK_TUI_TTY_SRC="$sb/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --skills --dry-run --yes 2>&1
)
s3_count=$(printf '%s\n' "$out" | _would_count)
# Mirror of S6 in test-install-skills.sh: full catalog = 22.
assert_eq "22" "$s3_count" "S3.1 default-set produces 22 would-install (baseline)"

# ────────────────────────── summary ──────────────────────────
echo ""
echo "──────────────────────────────────────────────"
printf "PASS: %d  FAIL: %d\n" "$PASS" "$FAIL"
echo "──────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
