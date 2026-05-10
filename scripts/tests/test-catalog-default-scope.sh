#!/usr/bin/env bash
# test-catalog-default-scope.sh — verifies the v6.16.0 catalog default_scope
# adjustments (comet-bridge → user, datadog → project, posthog → project) plus
# the cleanup of redundant `--scope project` from comet-bridge install_args[].
#
# Background: prior to v6.16.0 the catalog had three defaults that did not match
# the security/blast-radius logic discussed in `.planning/phases/16.0-install-mcp-scope-picker/16.0-CONTEXT.md`:
#   - comet-bridge was project-scope (single Comet profile per user — no blast
#     radius, should be user-scope) AND duplicated the scope inside install_args.
#   - datadog was user-scope (prod monitoring with ack/mute = real blast radius,
#     should be project-scope).
#   - posthog was user-scope (multi-product orgs read all events with personal
#     API key, should be project-scope).
#
# Asserts:
#   1. comet-bridge.default_scope == "user"
#   2. comet-bridge.install_args does NOT contain "--scope" anywhere
#   3. datadog.default_scope == "project"
#   4. posthog.default_scope == "project"
#   5. catalog still passes the schema validator (28 mcp entries)
#
# Usage: bash scripts/tests/test-catalog-default-scope.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CATALOG="${REPO_ROOT}/scripts/lib/integrations-catalog.json"

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

if ! command -v jq >/dev/null 2>&1; then
    printf "${RED}FAIL${NC} jq not installed (required by catalog validators).\n"
    exit 1
fi

if [ ! -f "$CATALOG" ]; then
    printf "${RED}FAIL${NC} catalog not found at %s\n" "$CATALOG"
    exit 1
fi

# Assertions 1, 3, 4 — default_scope values
assert_eq "user" \
    "$(jq -r '.components.mcp."comet-bridge".default_scope' "$CATALOG")" \
    "comet-bridge.default_scope == user"

assert_eq "project" \
    "$(jq -r '.components.mcp.datadog.default_scope' "$CATALOG")" \
    "datadog.default_scope == project"

assert_eq "project" \
    "$(jq -r '.components.mcp.posthog.default_scope' "$CATALOG")" \
    "posthog.default_scope == project"

# Assertion 2 — comet-bridge.install_args has no leftover --scope
# (the runtime prepends --scope dynamically; carrying it in install_args caused
# a duplicate flag that some Claude CLI versions reject).
SCOPE_IN_INSTALL_ARGS=$(jq -r '.components.mcp."comet-bridge".install_args | map(select(. == "--scope")) | length' "$CATALOG")
assert_eq "0" "$SCOPE_IN_INSTALL_ARGS" \
    "comet-bridge.install_args contains no --scope token"

# Assertion 5 — schema validator still passes (sanity)
if python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} catalog passes schema validator\n"
else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} catalog rejected by validate-integrations-catalog.py\n"
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" || true
fi

printf "\n  Passed: %d\n  Failed: %d\n\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
