#!/usr/bin/env bash
# test-mcp-repomix.sh — v6.23 repomix MCP catalog entry validation.
#
# Scenarios:
#   M1_catalog_row_parses     — jq -e '.components.mcp.repomix' returns truthy
#   M2_catalog_entry_shape    — required fields present, category valid, no env_var_keys
#   M3_npx_help               — `npx -y repomix@<pin> --help` exits 0 (smoke)
#   M4_pin_consistency        — manifest.json:vendor_pins.repomix.tag matches install_args
#
# Usage: bash scripts/tests/test-mcp-repomix.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

echo "test-mcp-repomix.sh: v6.23 MCP catalog entry"
echo ""

catalog="$REPO_ROOT/scripts/lib/integrations-catalog.json"
manifest="$REPO_ROOT/manifest.json"

echo "-- M1_catalog_row_parses --"
if jq -e '.components.mcp.repomix' "$catalog" >/dev/null 2>&1; then
    assert_pass "M1: catalog has components.mcp.repomix"
else
    assert_fail "M1: catalog missing repomix entry" "expected truthy result from jq"
fi

echo "-- M2_catalog_entry_shape --"
name=$(jq -r '.components.mcp.repomix.name' "$catalog")
category=$(jq -r '.components.mcp.repomix.category' "$catalog")
env_keys_count=$(jq -r '.components.mcp.repomix.env_var_keys | length' "$catalog")
oauth=$(jq -r '.components.mcp.repomix.requires_oauth' "$catalog")
scope=$(jq -r '.components.mcp.repomix.default_scope' "$catalog")
assert_eq "repomix" "$name" "M2: name field matches"
assert_eq "dev-tools" "$category" "M2: category is dev-tools"
assert_eq "0" "$env_keys_count" "M2: env_var_keys empty (zero-secret)"
assert_eq "false" "$oauth" "M2: requires_oauth=false"
assert_eq "user" "$scope" "M2: default_scope=user"

echo "-- M3_npx_help --"
if command -v npx >/dev/null 2>&1; then
    pinned=$(jq -r '.vendor_pins.repomix.tag' "$manifest" | sed 's/^v//')
    if npx -y "repomix@${pinned}" --help >/dev/null 2>&1; then
        assert_pass "M3: npx -y repomix@${pinned} --help exits 0"
    else
        assert_fail "M3: npx repomix --help failed" "exit non-zero"
    fi
else
    printf "  ${YELLOW}SKIP${NC} M3: npx not on PATH (CI environment)\n"
fi

echo "-- M4_pin_consistency --"
manifest_tag=$(jq -r '.vendor_pins.repomix.tag' "$manifest" | sed 's/^v//')
install_pin=$(jq -r '.components.mcp.repomix.install_args | join(" ")' "$catalog" \
    | grep -oE 'repomix@[0-9]+\.[0-9]+\.[0-9]+' \
    | sed 's/^repomix@//')
assert_eq "$manifest_tag" "$install_pin" "M4: manifest tag matches MCP install_args pin"

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
