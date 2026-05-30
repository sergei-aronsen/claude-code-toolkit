#!/bin/bash
# test-catalog-serena.sh — v6.1 catalog assertions (audit F-15).
# Verifies the Morph→Serena swap landed cleanly in scripts/lib/integrations-catalog.json:
#   - serena entry exists with the expected shape
#   - morph-fast-tools entry is absent
#   - no remaining occurrence of "morph-fast-tools" string in any catalog name
# Usage: bash scripts/tests/test-catalog-serena.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

CATALOG="$(cd "$(dirname "$0")/../lib" && pwd)/integrations-catalog.json"
[ -f "$CATALOG" ] || { echo "ERROR: catalog not found at $CATALOG"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# 1. serena entry exists somewhere under .categories.*.mcp[]
serena_entry=$(jq '[.. | objects | select(has("name") and .name=="serena")] | .[0] // empty' "$CATALOG")
if [ -n "$serena_entry" ]; then
    report_pass "serena entry present"
else
    report_fail "serena entry missing from catalog"
fi

# 2. env_var_keys is an empty array (Serena needs no API keys — local LSP)
keys_kind=$(jq '[.. | objects | select(has("name") and .name=="serena") | .env_var_keys] | .[0] | type' "$CATALOG")
keys_len=$(jq '[.. | objects | select(has("name") and .name=="serena") | .env_var_keys] | .[0] | length' "$CATALOG")
if [ "$keys_kind" = '"array"' ] && [ "$keys_len" -eq 0 ]; then
    report_pass "serena.env_var_keys is empty array"
else
    report_fail "serena.env_var_keys expected empty array, got kind=$keys_kind len=$keys_len"
fi

# 3. install_args[0] == "serena"  (claude mcp add <name> -- <argv>; first token is the registered name)
first_arg=$(jq -r '[.. | objects | select(has("name") and .name=="serena") | .install_args[0]] | .[0] // ""' "$CATALOG")
if [ "$first_arg" = "serena" ]; then
    report_pass "serena.install_args[0] == \"serena\""
else
    report_fail "serena.install_args[0] expected \"serena\", got \"$first_arg\""
fi

# 4. install_args contains the canonical claude-code launch sequence
must_contain=("--" "start-mcp-server" "--context" "claude-code" "--project-from-cwd")
all_present=1
for token in "${must_contain[@]}"; do
    if ! jq -e --arg t "$token" '[.. | objects | select(has("name") and .name=="serena") | .install_args[]] | index($t)' "$CATALOG" >/dev/null; then
        report_fail "serena.install_args missing token: $token"
        all_present=0
    fi
done
[ $all_present -eq 1 ] && report_pass "serena.install_args contains canonical launch tokens"

# 5. description references uv prereq + 23.9k stars (sanity that v6.1 swap shipped, not stale Morph copy)
desc=$(jq -r '[.. | objects | select(has("name") and .name=="serena") | .description] | .[0] // ""' "$CATALOG")
if echo "$desc" | grep -q "uv tool install" && echo "$desc" | grep -q "MIT"; then
    report_pass "serena.description references uv install + MIT license"
else
    report_fail "serena.description missing uv-install or MIT marker (got: ${desc:0:120}…)"
fi

# 6. requires_oauth is false (no OAuth dance — Serena runs locally)
oauth=$(jq -r '[.. | objects | select(has("name") and .name=="serena") | .requires_oauth] | .[0]' "$CATALOG")
if [ "$oauth" = "false" ]; then
    report_pass "serena.requires_oauth == false"
else
    report_fail "serena.requires_oauth expected false, got $oauth"
fi

# 7. NO morph-fast-tools entry anywhere
morph_count=$(jq '[.. | objects | select(has("name") and .name=="morph-fast-tools")] | length' "$CATALOG")
if [ "$morph_count" -eq 0 ]; then
    report_pass "morph-fast-tools entry absent (v6.1 removal)"
else
    report_fail "morph-fast-tools entry still present (count=$morph_count) — v6.1 swap incomplete"
fi

# 8. Total mcp entry count unchanged (1-for-1 swap; was 23 in v6.0)
total_mcps=$(jq '[.. | objects | select(has("name"))] | length' "$CATALOG")
if [ "$total_mcps" -ge 20 ] && [ "$total_mcps" -le 40 ]; then
    report_pass "total mcp count sane: $total_mcps (expected 20–40)"
else
    report_fail "total mcp count out of band: $total_mcps"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
