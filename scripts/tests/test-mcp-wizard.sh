#!/usr/bin/env bash
# test-mcp-wizard.sh — Task 2 (Plan 25-02) TDD RED phase.
# Tests mcp_wizard_run (to be added to scripts/lib/mcp.sh).
# All assertions here FAIL before implementation (TDD RED gate).
#
# Usage: bash scripts/tests/test-mcp-wizard.sh
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
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "pattern unexpectedly found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    else
        assert_pass "$label"
    fi
}

printf "=== mcp-wizard tests (Plan 25-02 Task 2) ===\n"

SANDBOX="$(mktemp -d /tmp/mcp-wizard.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# Build a mock claude binary that records argv + env to a file.
cat > "$SANDBOX/claude" <<'MOCK'
#!/bin/bash
printf 'argv:' > "$SANDBOX/claude.argv"
for a in "$@"; do printf ' %s' "$a"; done >> "$SANDBOX/claude.argv"
printf '\n' >> "$SANDBOX/claude.argv"
printf 'env:CTX=%s\n' "${CONTEXT7_API_KEY:-}" >> "$SANDBOX/claude.argv"
printf 'env:SENTRY=%s\n' "${SENTRY_AUTH_TOKEN:-}" >> "$SANDBOX/claude.argv"
exit 0
MOCK
# Inject SANDBOX into the mock at write time (heredoc can't expand inside MOCK quotes).
sed -i.bak "s|\\\$SANDBOX|${SANDBOX}|g" "$SANDBOX/claude"
chmod +x "$SANDBOX/claude"
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"
mcp_catalog_load

# ── Test 1: --dry-run with zero-config MCP — no claude invocation, prints "would run" ──
OUTPUT=$(mcp_wizard_run sequential-thinking --dry-run 2>&1)
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_fail "T1: dry-run must not invoke claude" "claude.argv exists"
else
    assert_pass "T1: dry-run must not invoke claude"
fi
assert_contains "would run" "$OUTPUT" "T1: dry-run output contains 'would run'"

# ── Test 2: zero-config MCP invocation populates argv correctly ───────────────
rm -f "$SANDBOX/claude.argv"
mcp_wizard_run sequential-thinking
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_pass "T2: claude was invoked for sequential-thinking"
else
    assert_fail "T2: claude was invoked for sequential-thinking" "claude.argv missing"
fi
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "argv:" "$ARGV_CONTENT" "T2: argv line present"
assert_contains "mcp" "$ARGV_CONTENT" "T2: argv contains 'mcp'"
assert_contains "add" "$ARGV_CONTENT" "T2: argv contains 'add'"
assert_contains "sequential-thinking" "$ARGV_CONTENT" "T2: argv contains 'sequential-thinking'"
rm -f "$SANDBOX/claude.argv"

# ── Test 3: keyed MCP (context7) — env var plumbed to claude + secret persisted ──
printf 'test_secret_ctx7\n' > "$SANDBOX/tty.fix"
TK_MCP_TTY_SRC="$SANDBOX/tty.fix" mcp_wizard_run context7
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "env:CTX=test_secret_ctx7" "$ARGV_CONTENT" "T3: CONTEXT7_API_KEY plumbed to claude"
# Secret persisted to mcp-config.env
cfg_file="$SANDBOX/.claude/mcp-config.env"
if [[ -f "$cfg_file" ]] && grep -q "^CONTEXT7_API_KEY=test_secret_ctx7$" "$cfg_file"; then
    assert_pass "T3: secret persisted to mcp-config.env"
else
    assert_fail "T3: secret persisted to mcp-config.env" "key not found in $(cat "$cfg_file" 2>/dev/null || echo 'file missing')"
fi
# File mode 0600
mode_ok=0
if stat -f %Mp%Lp "$cfg_file" 2>/dev/null | grep -q "^0600$"; then mode_ok=1
elif [ "$(stat -c %a "$cfg_file" 2>/dev/null)" = "600" ]; then mode_ok=1; fi
assert_eq "1" "$mode_ok" "T3: mcp-config.env mode is 0600 after wizard"
rm -f "$SANDBOX/claude.argv"

# ── Test 4: secret value must NOT appear in stdout/stderr ─────────────────────
printf 'leaked_secret_zzz\n' > "$SANDBOX/tty.fix2"
rm -f "$SANDBOX/.claude/mcp-config.env"
OUTPUT=$(TK_MCP_TTY_SRC="$SANDBOX/tty.fix2" mcp_wizard_run context7 2>&1 || true)
assert_not_contains "leaked_secret_zzz" "$OUTPUT" "T4: secret value not in stdout/stderr (hidden-input contract)"
rm -f "$SANDBOX/claude.argv"

# ── Test 5: OAuth-only MCP (notion) skips env prompts, invokes claude directly ──
rm -f "$SANDBOX/claude.argv"
mcp_wizard_run notion
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "argv:" "$ARGV_CONTENT" "T5: claude invoked for notion"
assert_contains "notion" "$ARGV_CONTENT" "T5: argv contains 'notion'"
rm -f "$SANDBOX/claude.argv"

# ── Test 6: CLI absent → return 2 (fail-soft, MCP-02 contract) ───────────────
unset TK_MCP_CLAUDE_BIN
rc=0
# Restrict PATH so 'claude' cannot be found
(
    export PATH="/usr/bin:/bin"
    source "${REPO_ROOT}/scripts/lib/mcp.sh"
    mcp_catalog_load
    mcp_wizard_run sequential-thinking 2>/dev/null
) || rc=$?
assert_eq "2" "$rc" "T6: CLI absent returns exit code 2"
# Restore for any further tests
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
