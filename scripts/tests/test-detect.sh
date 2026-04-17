#!/bin/bash
# Claude Code Toolkit — detect.sh test harness
# Usage: bash scripts/tests/test-detect.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

# Compute absolute path to detect.sh — works when invoked from any CWD
DETECT_SH="$(cd "$(dirname "$0")/.." && pwd)/detect.sh"
[ -f "$DETECT_SH" ] || { echo "ERROR: detect.sh not found at $DETECT_SH"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-detect.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

run_case() {
    local label="$1"
    local setup_cmd="$2"
    local expect_sp="$3"
    local expect_gsd="$4"

    HOME="$SCRATCH"
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"

    eval "$setup_cmd"

    HAS_SP=""
    HAS_GSD=""
    # shellcheck disable=SC2034
    SP_VERSION=""
    # shellcheck disable=SC2034
    GSD_VERSION=""

    # shellcheck source=/dev/null
    # Use || true: detect_superpowers returns 1 when SP absent; must not abort the harness
    source "$DETECT_SH" || true

    local ok=true
    [ "$HAS_SP" = "$expect_sp" ] || ok=false
    [ "$HAS_GSD" = "$expect_gsd" ] || ok=false

    if $ok; then
        echo "✅ PASS: $label (HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD)"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $label (expected HAS_SP=$expect_sp HAS_GSD=$expect_gsd, got HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD)"
        FAIL=$((FAIL + 1))
    fi
}

# Case 1: neither SP nor GSD installed
run_case "neither" \
    "true" \
    "false" "false"

# Case 2: SP only — cache dir + settings.json with enabledPlugins true
# shellcheck disable=SC2016
run_case "SP only" \
    'mkdir -p "$SCRATCH/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7"; printf "{\"enabledPlugins\":{\"superpowers@claude-plugins-official\":true}}" > "$SCRATCH/.claude/settings.json"' \
    "true" "false"

# Case 3: GSD only — bin/gsd-tools.cjs + VERSION file
# shellcheck disable=SC2016
run_case "GSD only" \
    'mkdir -p "$SCRATCH/.claude/get-shit-done/bin"; touch "$SCRATCH/.claude/get-shit-done/bin/gsd-tools.cjs"; printf "1.36.0" > "$SCRATCH/.claude/get-shit-done/VERSION"' \
    "false" "true"

# Case 4: both SP and GSD installed
# shellcheck disable=SC2016
run_case "both" \
    'mkdir -p "$SCRATCH/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7"; mkdir -p "$SCRATCH/.claude/get-shit-done/bin"; touch "$SCRATCH/.claude/get-shit-done/bin/gsd-tools.cjs"; printf "1.36.0" > "$SCRATCH/.claude/get-shit-done/VERSION"; printf "{\"enabledPlugins\":{\"superpowers@claude-plugins-official\":true}}" > "$SCRATCH/.claude/settings.json"' \
    "true" "true"

# Case 5: SP stale-cache disabled — cache dir present but enabledPlugins = false (DETECT-03 regression)
# shellcheck disable=SC2016
run_case "SP stale-cache disabled" \
    'mkdir -p "$SCRATCH/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7"; printf "{\"enabledPlugins\":{\"superpowers@claude-plugins-official\":false}}" > "$SCRATCH/.claude/settings.json"' \
    "false" "false"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
