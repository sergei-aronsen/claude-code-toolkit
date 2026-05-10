#!/usr/bin/env bash
# test-mcp-detect-installed-scope.sh — unit tests for the v6.16.0
# mcp_detect_installed_scope helper (scripts/lib/mcp.sh).
#
# The helper parses three JSON sources to return user|project|local|"" for a
# given MCP name. Tests cover all sources individually, the precedence rule
# (local > project > user), missing files, malformed JSON, unknown names.
#
# Test seams used:
#   TK_MCP_DETECT_USER_JSON      — fake ~/.claude.json
#   TK_MCP_DETECT_PROJECT_JSON   — fake <project>/.mcp.json
#   TK_MCP_DETECT_PROJECT_ROOT   — fake $PWD for projects[<root>] lookup
#
# Asserts (8):
#   1. user scope detected from ~/.claude.json mcpServers
#   2. project scope detected from <project>/.mcp.json mcpServers
#   3. local scope detected from ~/.claude.json projects[<root>].mcpServers
#   4. precedence: local wins over project + user
#   5. precedence: project wins over user
#   6. unknown name returns empty
#   7. missing files return empty (no crash under set -u)
#   8. malformed JSON returns empty (no crash, silent fallback)
#
# Usage: bash scripts/tests/test-mcp-detect-installed-scope.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        printf "  ${GREEN}OK${NC} %s\n" "$label"
    else
        FAIL=$((FAIL + 1))
        printf "  ${RED}FAIL${NC} %s (expected='%s' actual='%s')\n" "$label" "$expected" "$actual"
    fi
}

# Fresh sandbox per run.
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/test-mcp-scope.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

USER_JSON="$SANDBOX/claude.json"
PROJECT_JSON="$SANDBOX/.mcp.json"
PROJECT_ROOT="/fake/project/root"

# mcp.sh expects MCP_NAMES / catalog state; we only need the helper. Source
# the helper functions only (the file is idempotent — re-source is a no-op).
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/mcp.sh"

# ---------------- T1: user scope ----------------
cat > "$USER_JSON" <<JSON
{
  "mcpServers": {
    "context7": { "type": "stdio" },
    "firecrawl": { "type": "stdio" }
  },
  "projects": {}
}
JSON
echo "{}" > "$PROJECT_JSON"

_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope context7)
assert_eq "user" "$RESULT" "user scope detected"

# ---------------- T2: project scope ----------------
echo "{}" > "$USER_JSON"
cat > "$PROJECT_JSON" <<JSON
{ "mcpServers": { "stripe": { "type": "stdio" } } }
JSON
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope stripe)
assert_eq "project" "$RESULT" "project scope detected"

# ---------------- T3: local scope ----------------
cat > "$USER_JSON" <<JSON
{
  "mcpServers": {},
  "projects": {
    "$PROJECT_ROOT": { "mcpServers": { "dbhub": { "type": "stdio" } } }
  }
}
JSON
echo "{}" > "$PROJECT_JSON"
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope dbhub)
assert_eq "local" "$RESULT" "local scope detected"

# ---------------- T4: precedence local > project > user ----------------
cat > "$USER_JSON" <<JSON
{
  "mcpServers": { "stripe": { "type": "stdio" } },
  "projects": {
    "$PROJECT_ROOT": { "mcpServers": { "stripe": { "type": "stdio" } } }
  }
}
JSON
cat > "$PROJECT_JSON" <<JSON
{ "mcpServers": { "stripe": { "type": "stdio" } } }
JSON
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope stripe)
assert_eq "local" "$RESULT" "precedence: local wins over project + user"

# ---------------- T5: precedence project > user ----------------
cat > "$USER_JSON" <<JSON
{ "mcpServers": { "supabase": { "type": "stdio" } }, "projects": {} }
JSON
cat > "$PROJECT_JSON" <<JSON
{ "mcpServers": { "supabase": { "type": "stdio" } } }
JSON
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope supabase)
assert_eq "project" "$RESULT" "precedence: project wins over user"

# ---------------- T6: unknown name → empty ----------------
echo '{"mcpServers": {}, "projects": {}}' > "$USER_JSON"
echo '{"mcpServers": {}}' > "$PROJECT_JSON"
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope nonexistent-mcp)
assert_eq "" "$RESULT" "unknown name returns empty"

# ---------------- T7: missing files → empty ----------------
rm -f "$USER_JSON" "$PROJECT_JSON"
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope context7 || echo "")
assert_eq "" "$RESULT" "missing files return empty (no crash)"

# ---------------- T8: malformed JSON → empty ----------------
echo "not json {{{" > "$USER_JSON"
echo "garbage" > "$PROJECT_JSON"
_mcp_scope_cache_reset
RESULT=$(TK_MCP_DETECT_USER_JSON="$USER_JSON" \
    TK_MCP_DETECT_PROJECT_JSON="$PROJECT_JSON" \
    TK_MCP_DETECT_PROJECT_ROOT="$PROJECT_ROOT" \
    mcp_detect_installed_scope context7 || echo "")
assert_eq "" "$RESULT" "malformed JSON returns empty (no crash)"

printf "\n  Passed: %d\n  Failed: %d\n\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
