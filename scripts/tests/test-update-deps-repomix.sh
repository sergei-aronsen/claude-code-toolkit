#!/usr/bin/env bash
# test-update-deps-repomix.sh — v6.23 update-deps integration for repomix pin.
#
# Scenarios:
#   U1_probe_repomix_registered  — DEP_NAME array contains "repomix"
#   U2_probe_runs                — update-deps.sh --check repomix returns 2 tab-separated fields
#   U3_pin_sync_dry_smoke        — _sync_repomix_pin is callable (symbol resolves)
#   U4_pin_files_present         — every file _sync_repomix_pin targets exists in the repo
#
# Usage: bash scripts/tests/test-update-deps-repomix.sh
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

echo "test-update-deps-repomix.sh: v6.23 update-deps repomix probe + upgrade"
echo ""

deps_sh="$REPO_ROOT/scripts/update-deps.sh"

echo "-- U1_probe_repomix_registered --"
if grep -q 'register_dep "repomix"' "$deps_sh"; then
    assert_pass "U1: register_dep \"repomix\" line present"
else
    assert_fail "U1: register_dep line missing" "grep returned no match"
fi

echo "-- U2_probe_runs --"
if command -v npm >/dev/null 2>&1; then
    out=$(bash "$deps_sh" --check repomix 2>&1 | tail -n 1)
    fields=$(printf '%s' "$out" | awk -F'\t' '{print NF}')
    if [ "$fields" = "2" ]; then
        assert_pass "U2: --check repomix emits 2 tab-separated fields"
    else
        assert_fail "U2: --check repomix output shape" "got '$out' (fields=$fields)"
    fi
else
    printf "  ${YELLOW}SKIP${NC} U2: npm not on PATH\n"
fi

echo "-- U3_pin_sync_dry_smoke --"
# Source the script in a subshell and verify _sync_repomix_pin symbol exists.
# Don't actually invoke it (would touch manifest.json).
if bash -c "source '$deps_sh' >/dev/null 2>&1; declare -F _sync_repomix_pin" >/dev/null 2>&1; then
    assert_pass "U3: _sync_repomix_pin function declared"
else
    # Source can fail if the script has a main-body executor — fall back to
    # grep for the function definition.
    if grep -q '^_sync_repomix_pin()' "$deps_sh"; then
        assert_pass "U3: _sync_repomix_pin function defined (grep)"
    else
        assert_fail "U3: _sync_repomix_pin missing" "neither source nor grep found it"
    fi
fi

echo "-- U4_pin_files_present --"
# Every file _sync_repomix_pin rewrites must exist on disk so the sed step
# doesn't silently no-op after a refactor.
targets=(
    "scripts/council/pack.py"
    "scripts/lib/integrations-catalog.json"
    "commands/pack.md"
    "templates/base/skills/repomix/SKILL.md"
)
missing=0
for f in "${targets[@]}"; do
    if [ ! -f "$REPO_ROOT/$f" ]; then
        missing=$((missing + 1))
        printf "      missing: %s\n" "$f"
    fi
done
if [ "$missing" -eq 0 ]; then
    assert_pass "U4: all 4 pin-target files exist"
else
    assert_fail "U4: $missing target file(s) missing" "_sync_repomix_pin would no-op silently"
fi

# ─────────────────────────────────────────────────
# U5 (v6.24.4) — probe_gsd MUST NOT call the legacy
# raw.githubusercontent.com/gsd-build/get-shit-done curl|bash URL.
# GSD migrated to the get-shit-done-cc npm package; the old URL 404s.
# ─────────────────────────────────────────────────
echo "-- U5_gsd_npm_migration: probe_gsd uses npx, not legacy curl|bash --"
UPDATE_SRC="${REPO_ROOT}/scripts/update-deps.sh"
if grep -vE '^[[:space:]]*#' "$UPDATE_SRC" \
   | grep -qE 'raw\.githubusercontent\.com/gsd-build/get-shit-done'; then
    assert_fail "U5: legacy gsd-build/get-shit-done URL still active in update-deps.sh" \
        "GSD migrated to npm; probe_gsd should call 'npx get-shit-done-cc@<semver>'"
else
    assert_pass "U5: legacy gsd-build/get-shit-done URL not active in update-deps.sh"
fi
if grep -qE 'npx[[:space:]]+--yes[[:space:]]+"?get-shit-done-cc' "$UPDATE_SRC"; then
    assert_pass "U5: update-deps.sh invokes get-shit-done-cc via npx"
else
    assert_fail "U5: update-deps.sh does not invoke npx get-shit-done-cc" \
        "missing 'npx --yes get-shit-done-cc@<ver>' invocation"
fi
if grep -qE 'TK_GSD_NPM_VERSION' "$UPDATE_SRC" \
   && grep -qE '"\$pkg_version"[[:space:]]+=~[[:space:]]+\^\(latest\|' "$UPDATE_SRC"; then
    assert_pass "U5: TK_GSD_NPM_VERSION semver/tag allowlist guard present"
else
    assert_fail "U5: TK_GSD_NPM_VERSION semver/tag allowlist guard missing" \
        "version must be validated before passing into 'npx <pkg>@<ver>'"
fi

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
