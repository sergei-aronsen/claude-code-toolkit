#!/usr/bin/env bash
# test-dispatch-env-scrub.sh — regression test for v6.23.4
#
# Background:
#   The v6.23.1 F-1 audit gate (install.sh:277) rejects any pre-set
#   TK_MCP_CATALOG_PATH unless TK_TEST=1 is also set. Parent install.sh's
#   main-TUI pre-collection block (install.sh:1847+) exports
#   TK_MCP_CATALOG_PATH for its own mcp_catalog_load call, and that
#   export then leaks into children spawned by dispatch_skills /
#   dispatch_mcp_servers via standard bash env inheritance. Child
#   install.sh hits the F-1 gate at startup and exits 1 (curl 56 on
#   the pipe), so the user sees "skills failed (exit 1)" and
#   "mcp-servers failed (exit 1)" in the summary even though the
#   actual install logic never ran.
#
# Fix (dispatch.sh):
#   Prepend `env -u TK_MCP_CATALOG_PATH` to every child bash
#   invocation in dispatch_skills and dispatch_mcp_servers so the
#   child sees a clean slate and re-downloads the catalog itself.
#
# Scenarios:
#   S1 — dispatch_skills sibling-path branch: child inherits
#        TK_MCP_CATALOG_PATH=UNSET despite parent having it set.
#   S2 — dispatch_mcp_servers sibling-path branch: same expectation.
#
# Notes:
#   We exercise the sibling-path branch (TK_CURL_PIPE=0) because the
#   curl-pipe branch would actually hit raw.githubusercontent.com.
#   Both branches go through the same `env -u` prefix, so testing one
#   confirms the fix surface; the regex check below would catch any
#   regression in the curl-pipe branch too.
#
# Usage: bash scripts/tests/test-dispatch-env-scrub.sh
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

echo "test-dispatch-env-scrub.sh: v6.23.4 regression suite"
echo ""

# Static-grep sanity: both dispatch_* functions prefix child bash
# invocations with `env -u TK_MCP_CATALOG_PATH`. Catches accidental
# removal of the scrub even if the runtime branches are not exercised.
DISPATCH_SH="${REPO_ROOT}/scripts/lib/dispatch.sh"
echo "  -- static grep: env -u TK_MCP_CATALOG_PATH present in dispatch_*"
expected_hits=4   # curl-pipe + sibling for each of dispatch_skills, dispatch_mcp_servers
hits=$(grep -c "env -u TK_MCP_CATALOG_PATH bash" "$DISPATCH_SH" || true)
assert_eq "$expected_hits" "$hits" "static: 4 env-scrub invocations in dispatch.sh"

# Runtime: sibling-path branch of each dispatch_*.
SANDBOX=$(mktemp -d /tmp/test-dispatch-env-scrub.XXXXXX)
trap 'rm -rf "${SANDBOX:?}"' EXIT
mkdir -p "$SANDBOX/scripts/lib"
cp "$DISPATCH_SH" "$SANDBOX/scripts/lib/"

# Stub install.sh at the sibling path. Writes the inherited value to
# $TK_TEST_OUT and exits cleanly. NO --integrations / --skills flag
# parsing — the stub ignores argv and records env only.
cat > "$SANDBOX/scripts/install.sh" <<'STUB'
#!/bin/bash
echo "TK_MCP_CATALOG_PATH=${TK_MCP_CATALOG_PATH:-UNSET}" > "$TK_TEST_OUT"
STUB
chmod +x "$SANDBOX/scripts/install.sh"

# ─────────────────────────────────────────────────
# S1 — dispatch_skills env scrub
# ─────────────────────────────────────────────────
echo "  -- S1: dispatch_skills child inherits TK_MCP_CATALOG_PATH=UNSET --"
TK_TEST_OUT="$SANDBOX/result-skills"
export TK_TEST_OUT
TK_CURL_PIPE=0 \
TK_MCP_CATALOG_PATH=/tmp/parent-catalog-fake \
TK_USER_AGENT=test-agent \
TK_REPO_URL=https://example.invalid/repo \
bash -c "
    # shellcheck source=/dev/null
    source '$SANDBOX/scripts/lib/dispatch.sh'
    dispatch_skills
" 2>/dev/null
s1_result=$(cat "$TK_TEST_OUT")
assert_eq "TK_MCP_CATALOG_PATH=UNSET" "$s1_result" \
    "S1: dispatch_skills strips TK_MCP_CATALOG_PATH from child env"

# ─────────────────────────────────────────────────
# S2 — dispatch_mcp_servers env scrub
# ─────────────────────────────────────────────────
echo "  -- S2: dispatch_mcp_servers child inherits TK_MCP_CATALOG_PATH=UNSET --"
TK_TEST_OUT="$SANDBOX/result-mcps"
export TK_TEST_OUT
TK_CURL_PIPE=0 \
TK_MCP_CATALOG_PATH=/tmp/parent-catalog-fake \
TK_USER_AGENT=test-agent \
TK_REPO_URL=https://example.invalid/repo \
bash -c "
    # shellcheck source=/dev/null
    source '$SANDBOX/scripts/lib/dispatch.sh'
    dispatch_mcp_servers
" 2>/dev/null
s2_result=$(cat "$TK_TEST_OUT")
assert_eq "TK_MCP_CATALOG_PATH=UNSET" "$s2_result" \
    "S2: dispatch_mcp_servers strips TK_MCP_CATALOG_PATH from child env"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
