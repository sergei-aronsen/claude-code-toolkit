#!/usr/bin/env bash
# test-mcp-secrets.sh — Task 1 (Plan 25-02) TDD RED phase.
# Tests mcp_secrets_load + mcp_secrets_set (to be added to scripts/lib/mcp.sh).
# All assertions here FAIL before implementation (TDD RED gate).
#
# Usage: bash scripts/tests/test-mcp-secrets.sh
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
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    fi
}

printf "=== mcp-secrets tests (Plan 25-02 Task 1) ===\n"

SANDBOX="$(mktemp -d /tmp/mcp-secrets.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"

# ── Test 1: load from non-existent file returns empty arrays ──────────────────
mcp_secrets_load
assert_eq "0" "${#MCP_SECRET_KEYS[@]}" "T1: empty load — MCP_SECRET_KEYS length 0"
assert_eq "0" "${#MCP_SECRET_VALUES[@]}" "T1: empty load — MCP_SECRET_VALUES length 0"

# ── Test 2: set + load roundtrip ──────────────────────────────────────────────
mcp_secrets_set FOO bar
mcp_secrets_load
assert_eq "1" "${#MCP_SECRET_KEYS[@]}" "T2: after set — array length 1"
assert_eq "FOO" "${MCP_SECRET_KEYS[0]}" "T2: after set — key is FOO"
assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "T2: after set — value is bar"

# ── Test 3: file mode 0600 (cross-platform) ───────────────────────────────────
cfg_file="$SANDBOX/.claude/mcp-config.env"
mode_ok=0
if stat -f %Mp%Lp "$cfg_file" 2>/dev/null | grep -q "^0600$"; then
    mode_ok=1
elif [ "$(stat -c %a "$cfg_file" 2>/dev/null)" = "600" ]; then
    mode_ok=1
fi
assert_eq "1" "$mode_ok" "T3: file mode is 0600"

# ── Test 4: validation rejects $ in value ─────────────────────────────────────
if mcp_secrets_set BAD 'value$injection' 2>/dev/null; then
    assert_fail "T4: $ in value rejected" "mcp_secrets_set returned 0 — should have returned 1"
else
    assert_pass "T4: $ in value rejected"
fi

# ── Test 5: collision prompt — answer N keeps existing ────────────────────────
TK_MCP_TTY_SRC=<(printf 'N\n') mcp_secrets_set FOO new_value 2>/dev/null || true
mcp_secrets_load
assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "T5: collision N preserves existing value"

# ── Test 6: collision prompt — answer y overwrites ────────────────────────────
TK_MCP_TTY_SRC=<(printf 'y\n') mcp_secrets_set FOO updated 2>/dev/null || true
mcp_secrets_load
assert_eq "updated" "${MCP_SECRET_VALUES[0]}" "T6: collision y overwrites value"

# ── Test 7: multiple keys stored correctly ────────────────────────────────────
mcp_secrets_set ALPHA first
mcp_secrets_set BETA second
mcp_secrets_load
assert_eq "3" "${#MCP_SECRET_KEYS[@]}" "T7: three keys total (FOO, ALPHA, BETA)"

# ── Test 8: mode still 0600 after multiple writes ─────────────────────────────
mode_ok2=0
if stat -f %Mp%Lp "$cfg_file" 2>/dev/null | grep -q "^0600$"; then
    mode_ok2=1
elif [ "$(stat -c %a "$cfg_file" 2>/dev/null)" = "600" ]; then
    mode_ok2=1
fi
assert_eq "1" "$mode_ok2" "T8: mode 0600 preserved after multiple writes"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
