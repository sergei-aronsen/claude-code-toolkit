#!/usr/bin/env bash
# test-update-deps-skills-pins.sh — v6.37.0 skills_pins path extension
# (v6.41.0 coverage extended 5 → 9 pins).
#
# Scenarios:
#   S1_manifest_9_skill_pins        — skills_pins has exactly 9 keys
#   S2_path_field_on_monorepo_pins  — 7 monorepo pins carry "path": "skills/<name>"
#   S3_no_path_on_standalone_pins   — huashu-design + resend have no "path" key (standalone)
#   S4_commits_are_full_shas        — every active pin has a 40-char hex commit (not null)
#   S5_status_active_on_9_pins      — all 9 pins are _status: "active"
#   S6_register_dep_9_skills        — register_dep "Skill" lines = 9 in update-deps.sh
#   S7_probe_functions_defined      — 9 probe_skill_* functions defined
#   S8_upgrade_functions_defined    — 9 upgrade_skill_* functions defined
#   S9_probe_pdf_2_field_output     — bash update-deps.sh --check pdf emits 2 tab-separated fields
#   S10_probe_pinned_is_12char      — pinned column is 12-char hex prefix (not "—") for active pins
#
# Usage: bash scripts/tests/test-update-deps-skills-pins.sh
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

echo "test-update-deps-skills-pins.sh: v6.37.0 skills_pins path extension"
echo ""

manifest="$REPO_ROOT/manifest.json"
deps_sh="$REPO_ROOT/scripts/update-deps.sh"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq not on PATH — this test requires jq"
    exit 1
fi

SKILL_PIN_NAMES=(docx find-skills firecrawl huashu-design pdf resend vercel-composition-patterns vercel-react-best-practices webapp-testing)
MONOREPO_PIN_NAMES=(docx find-skills firecrawl pdf vercel-composition-patterns vercel-react-best-practices webapp-testing)
STANDALONE_PIN_NAMES=(huashu-design resend)
PROBE_FN_NAMES=(probe_skill_docx probe_skill_find_skills probe_skill_firecrawl probe_skill_huashu_design probe_skill_pdf probe_skill_resend probe_skill_vercel_composition_patterns probe_skill_vercel_react_best_practices probe_skill_webapp_testing)
UPGRADE_FN_NAMES=(upgrade_skill_docx upgrade_skill_find_skills upgrade_skill_firecrawl upgrade_skill_huashu_design upgrade_skill_pdf upgrade_skill_resend upgrade_skill_vercel_composition_patterns upgrade_skill_vercel_react_best_practices upgrade_skill_webapp_testing)

declare -A MONOREPO_PATH=(
    [docx]="skills/docx"
    [find-skills]="skills/find-skills"
    [firecrawl]="skills/firecrawl-cli"
    [pdf]="skills/pdf"
    [vercel-composition-patterns]="skills/composition-patterns"
    [vercel-react-best-practices]="skills/react-best-practices"
    [webapp-testing]="skills/webapp-testing"
)

echo "-- S1_manifest_9_skill_pins --"
count=$(jq -r '.skills_pins | length' "$manifest")
if [ "$count" = "9" ]; then
    assert_pass "S1: skills_pins has 9 keys"
else
    assert_fail "S1: skills_pins count" "expected 9, got $count"
fi

echo "-- S2_path_field_on_monorepo_pins --"
for name in "${MONOREPO_PIN_NAMES[@]}"; do
    path=$(jq -r --arg n "$name" '.skills_pins[$n].path // ""' "$manifest")
    expected="${MONOREPO_PATH[$name]}"
    if [ "$path" = "$expected" ]; then
        assert_pass "S2: $name.path = $expected"
    else
        assert_fail "S2: $name.path" "expected '$expected', got '$path'"
    fi
done

echo "-- S3_no_path_on_standalone_pins --"
for name in "${STANDALONE_PIN_NAMES[@]}"; do
    path=$(jq -r --arg n "$name" '.skills_pins[$n] | has("path")' "$manifest")
    if [ "$path" = "false" ]; then
        assert_pass "S3: $name has no path key (standalone)"
    else
        assert_fail "S3: $name.path key" "standalone repo must not declare path; jq has('path') returned '$path'"
    fi
done

echo "-- S4_commits_are_full_shas --"
for name in "${SKILL_PIN_NAMES[@]}"; do
    commit=$(jq -r --arg n "$name" '.skills_pins[$n].commit // ""' "$manifest")
    if [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
        assert_pass "S4: $name.commit is 40-char hex"
    else
        assert_fail "S4: $name.commit" "expected 40-char hex, got '$commit'"
    fi
done

echo "-- S5_status_active_on_9_pins --"
for name in "${SKILL_PIN_NAMES[@]}"; do
    status=$(jq -r --arg n "$name" '.skills_pins[$n]._status // ""' "$manifest")
    if [ "$status" = "active" ]; then
        assert_pass "S5: $name._status = active"
    else
        assert_fail "S5: $name._status" "expected 'active', got '$status'"
    fi
done

echo "-- S6_register_dep_9_skills --"
n_lines=$(grep -c '^register_dep ".*"\s*"Skill"' "$deps_sh" || true)
if [ "$n_lines" = "9" ]; then
    assert_pass "S6: register_dep \"Skill\" lines = 9"
else
    assert_fail "S6: register_dep Skill count" "expected 9, got $n_lines"
fi

echo "-- S7_probe_functions_defined --"
for fn in "${PROBE_FN_NAMES[@]}"; do
    if grep -q "^${fn}()" "$deps_sh"; then
        assert_pass "S7: $fn defined"
    else
        assert_fail "S7: $fn missing" "function definition not found in update-deps.sh"
    fi
done

echo "-- S8_upgrade_functions_defined --"
for fn in "${UPGRADE_FN_NAMES[@]}"; do
    if grep -q "^${fn}()" "$deps_sh"; then
        assert_pass "S8: $fn defined"
    else
        assert_fail "S8: $fn missing" "function definition not found in update-deps.sh"
    fi
done

echo "-- S9_probe_pdf_2_field_output --"
# Probe may hit the network. Tolerate failure but require 2 fields and pinned non-"—".
out=$(bash "$deps_sh" --check pdf 2>/dev/null | tail -n 1)
fields=$(printf '%s' "$out" | awk -F'\t' '{print NF}')
if [ "$fields" = "2" ]; then
    assert_pass "S9: --check pdf emits 2 tab-separated fields"
else
    assert_fail "S9: --check pdf field count" "got '$out' (fields=$fields)"
fi

echo "-- S10_probe_pinned_is_12char --"
out=$(bash "$deps_sh" --check pdf 2>/dev/null | tail -n 1)
pinned=$(printf '%s' "$out" | awk -F'\t' '{print $1}')
if [[ "$pinned" =~ ^[0-9a-f]{12}$ ]]; then
    assert_pass "S10: pdf pinned column is 12-char hex"
else
    assert_fail "S10: pdf pinned shape" "expected 12-char hex, got '$pinned'"
fi

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
