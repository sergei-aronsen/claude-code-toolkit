#!/usr/bin/env bash
# test-update-deps-skills-pins.sh — v6.37.0 skills_pins path extension
# (v6.44.0 coverage extended 10 → 23 pins; 22 active + 1 no-upstream-found).
#
# Scenarios:
#   S1_manifest_23_skill_pins       — skills_pins has exactly 23 keys (22 active + memo-skill)
#   S2_path_field_on_monorepo_pins  — 8 v6.43.0 monorepo pins carry expected "path"
#   S3_no_path_on_standalone_pins   — huashu-design + resend + notebooklm have no "path" key
#   S4_commits_are_full_shas        — every active pin has a 40-char hex commit (not null)
#   S5_status_active_on_22_pins     — 22 pins _status: "active"; memo-skill _status: "no-upstream-found"
#   S6_register_dep_22_skills       — register_dep "Skill" lines = 22 in update-deps.sh
#   S7_probe_functions_defined      — 22 probe_skill_* functions defined
#   S8_upgrade_functions_defined    — 22 upgrade_skill_* functions defined
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

echo "test-update-deps-skills-pins.sh: v6.44.0 skills_pins coverage 22 active + 1 no-upstream"
echo ""

manifest="$REPO_ROOT/manifest.json"
deps_sh="$REPO_ROOT/scripts/update-deps.sh"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq not on PATH — this test requires jq"
    exit 1
fi

# v6.43.0 baseline monorepo pins (others added v6.44.0 use varied path roots
# tested in S2b below; this array is the original 8 with skills/* convention).
MONOREPO_PIN_NAMES=(docx find-skills firecrawl pdf shadcn vercel-composition-patterns vercel-react-best-practices webapp-testing)
STANDALONE_PIN_NAMES=(huashu-design resend notebooklm)
PROBE_FN_NAMES=(
    probe_skill_ai_models probe_skill_analytics_tracking
    probe_skill_chrome_extension_development probe_skill_copywriting
    probe_skill_docx probe_skill_find_skills probe_skill_firecrawl
    probe_skill_huashu_design probe_skill_i18n_localization
    probe_skill_next_best_practices probe_skill_notebooklm probe_skill_pdf
    probe_skill_resend probe_skill_seo_audit probe_skill_shadcn
    probe_skill_stripe_best_practices probe_skill_tailwind_design_system
    probe_skill_typescript_advanced_types probe_skill_ui_ux_pro_max
    probe_skill_vercel_composition_patterns probe_skill_vercel_react_best_practices
    probe_skill_webapp_testing
)
UPGRADE_FN_NAMES=(
    upgrade_skill_ai_models upgrade_skill_analytics_tracking
    upgrade_skill_chrome_extension_development upgrade_skill_copywriting
    upgrade_skill_docx upgrade_skill_find_skills upgrade_skill_firecrawl
    upgrade_skill_huashu_design upgrade_skill_i18n_localization
    upgrade_skill_next_best_practices upgrade_skill_notebooklm upgrade_skill_pdf
    upgrade_skill_resend upgrade_skill_seo_audit upgrade_skill_shadcn
    upgrade_skill_stripe_best_practices upgrade_skill_tailwind_design_system
    upgrade_skill_typescript_advanced_types upgrade_skill_ui_ux_pro_max
    upgrade_skill_vercel_composition_patterns upgrade_skill_vercel_react_best_practices
    upgrade_skill_webapp_testing
)

declare -A MONOREPO_PATH=(
    [docx]="skills/docx"
    [find-skills]="skills/find-skills"
    [firecrawl]="skills/firecrawl-cli"
    [pdf]="skills/pdf"
    [shadcn]="skills/shadcn"
    [vercel-composition-patterns]="skills/composition-patterns"
    [vercel-react-best-practices]="skills/react-best-practices"
    [webapp-testing]="skills/webapp-testing"
)
# v6.44.0 monorepo pins with non-skills/* path roots — checked separately.
declare -A V644_MONOREPO_PATH=(
    [ai-models]="plugins/learning/skills/ai-models"
    [analytics-tracking]="skills/analytics-tracking"
    [chrome-extension-development]="chrome-extension-development"
    [copywriting]="skills/copywriting"
    [i18n-localization]="skills/i18n-localization"
    [next-best-practices]="skills/next-best-practices"
    [seo-audit]="skills/seo-audit"
    [stripe-best-practices]="skills/stripe-best-practices"
    [tailwind-design-system]="plugins/frontend-mobile-development/skills/tailwind-design-system"
    [typescript-advanced-types]="plugins/javascript-typescript/skills/typescript-advanced-types"
    [ui-ux-pro-max]=".claude/skills/ui-ux-pro-max"
)
NO_UPSTREAM_PIN_NAMES=(memo-skill)
ACTIVE_PIN_NAMES=(
    ai-models analytics-tracking chrome-extension-development copywriting docx
    find-skills firecrawl huashu-design i18n-localization next-best-practices
    notebooklm pdf resend seo-audit shadcn stripe-best-practices
    tailwind-design-system typescript-advanced-types ui-ux-pro-max
    vercel-composition-patterns vercel-react-best-practices webapp-testing
)

echo "-- S1_manifest_23_skill_pins --"
count=$(jq -r '.skills_pins | length' "$manifest")
if [ "$count" = "23" ]; then
    assert_pass "S1: skills_pins has 23 keys"
else
    assert_fail "S1: skills_pins count" "expected 23, got $count"
fi

echo "-- S2_path_field_on_monorepo_pins (v6.43.0 + v6.44.0) --"
for name in "${MONOREPO_PIN_NAMES[@]}"; do
    path=$(jq -r --arg n "$name" '.skills_pins[$n].path // ""' "$manifest")
    expected="${MONOREPO_PATH[$name]}"
    if [ "$path" = "$expected" ]; then
        assert_pass "S2: $name.path = $expected"
    else
        assert_fail "S2: $name.path" "expected '$expected', got '$path'"
    fi
done
for name in "${!V644_MONOREPO_PATH[@]}"; do
    path=$(jq -r --arg n "$name" '.skills_pins[$n].path // ""' "$manifest")
    expected="${V644_MONOREPO_PATH[$name]}"
    if [ "$path" = "$expected" ]; then
        assert_pass "S2b: $name.path = $expected"
    else
        assert_fail "S2b: $name.path" "expected '$expected', got '$path'"
    fi
done

echo "-- S3_no_path_on_standalone_pins --"
for name in "${STANDALONE_PIN_NAMES[@]}"; do
    has_path=$(jq -r --arg n "$name" '.skills_pins[$n].path // "null"' "$manifest")
    if [ "$has_path" = "null" ]; then
        assert_pass "S3: $name has no path / path is null (standalone)"
    else
        assert_fail "S3: $name.path key" "standalone repo must not declare a path value; got '$has_path'"
    fi
done

echo "-- S4_commits_are_full_shas (active only; memo-skill skipped) --"
for name in "${ACTIVE_PIN_NAMES[@]}"; do
    commit=$(jq -r --arg n "$name" '.skills_pins[$n].commit // ""' "$manifest")
    if [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
        assert_pass "S4: $name.commit is 40-char hex"
    else
        assert_fail "S4: $name.commit" "expected 40-char hex, got '$commit'"
    fi
done

echo "-- S5_status_active_on_22_pins + no-upstream-found on memo-skill --"
for name in "${ACTIVE_PIN_NAMES[@]}"; do
    status=$(jq -r --arg n "$name" '.skills_pins[$n]._status // ""' "$manifest")
    if [ "$status" = "active" ]; then
        assert_pass "S5: $name._status = active"
    else
        assert_fail "S5: $name._status" "expected 'active', got '$status'"
    fi
done
for name in "${NO_UPSTREAM_PIN_NAMES[@]}"; do
    status=$(jq -r --arg n "$name" '.skills_pins[$n]._status // ""' "$manifest")
    if [ "$status" = "no-upstream-found" ]; then
        assert_pass "S5b: $name._status = no-upstream-found"
    else
        assert_fail "S5b: $name._status" "expected 'no-upstream-found', got '$status'"
    fi
done

echo "-- S6_register_dep_22_skills --"
n_lines=$(grep -c '^register_dep ".*"\s*"Skill"' "$deps_sh" || true)
if [ "$n_lines" = "22" ]; then
    assert_pass "S6: register_dep \"Skill\" lines = 22"
else
    assert_fail "S6: register_dep Skill count" "expected 22, got $n_lines"
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
