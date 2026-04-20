#!/usr/bin/env bash
# validate-release.sh — Phase 7 v4.0.0 release validation matrix runner (SKELETON).
# Runs 13 cells (4 modes × 3 scenarios + 1 translation-sync) in sandboxed $HOME.
# Asserts 4 invariants per cell (D-03). Fail-fast on first red cell (D-02).
#
# Plan 07-01 status: SKELETON ONLY. Helpers + run_cell wrapper exist.
# Cell bodies land in Plan 07-03.
#
# Usage:
#   bash scripts/validate-release.sh --self-test   # runs helper self-tests
#   bash scripts/validate-release.sh --cell <name> # Plan 07-03
#   bash scripts/validate-release.sh               # print usage
#
# Exit: 0 = all PASS, 1 = first FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
MANIFEST_FILE="${REPO_ROOT}/manifest.json"

# ─── Color constants (tty-auto-disable) ─────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    # shellcheck disable=SC2034
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    # shellcheck disable=SC2034
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# ─── Global PASS/FAIL counters ───────────────────────────────────────────────
PASS=0
FAIL=0

# ─── Core assertion helpers ──────────────────────────────────────────────────

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ ${msg}" >&2
        echo "    expected: ${expected}" >&2
        echo "    actual:   ${actual}" >&2
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1))
        echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ ${msg}" >&2
        echo "    expected substring: ${needle}" >&2
    fi
}

# ─── Library source guards ───────────────────────────────────────────────────

require_lib() {
    local lib_path="$1"
    if [ ! -f "$lib_path" ]; then
        echo "ERROR: required library not found: $lib_path" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
}

require_lib "${REPO_ROOT}/scripts/detect.sh"
require_lib "${LIB_DIR}/install.sh"
require_lib "${LIB_DIR}/state.sh"

# Run detection so HAS_SP / HAS_GSD are available for mode recommendations
detect_superpowers 2>/dev/null || true
detect_gsd 2>/dev/null || true

# ─── Invariant 2: toolkit-install.json schema + content ─────────────────────
# assert_state_schema <state_file> <expected_mode>
assert_state_schema() {
    local state_file="$1" expected_mode="$2"
    if [ ! -f "$state_file" ]; then
        FAIL=$((FAIL + 1))
        echo "  ✗ state file missing: $state_file" >&2
        return
    fi
    if ! jq empty "$state_file" 2>/dev/null; then
        FAIL=$((FAIL + 1))
        echo "  ✗ state file invalid JSON: $state_file" >&2
        return
    fi
    assert_eq "$expected_mode" "$(jq -r '.mode' "$state_file")" "state.mode = $expected_mode"
    assert_eq "object" "$(jq -r '.detected | type' "$state_file")" "state.detected is object"
    local bad_entries
    bad_entries=$(jq '[.installed_files[] | select(.path == null or .sha256 == null or .installed_at == null)] | length' "$state_file")
    assert_eq "0" "$bad_entries" "all installed_files entries have path+sha256+installed_at"
    local bad_skips
    bad_skips=$(jq '[.skipped_files[] | select(.path == null or .reason == null)] | length' "$state_file")
    assert_eq "0" "$bad_skips" "all skipped_files entries have path+reason"
}

# ─── Invariant 3: settings.json foreign-key byte-identity (SP/GSD hooks preserved) ──
# assert_settings_foreign_intact <before_json> <after_json>
# Args are JSON strings (pre-extracted by caller via jq '{hooks, enabledPlugins, ...}').
# shellcheck disable=SC2329
assert_settings_foreign_intact() {
    local before="$1" after="$2"
    assert_eq "$before" "$after" "settings.json foreign keys byte-identical pre/post"
}

# ─── Invariant 4: no skipped file landed in CELL_HOME/.claude/ ──────────────
# assert_skiplist_clean <cell_home> <mode>
assert_skiplist_clean() {
    local cell_home="$1" mode="$2"
    local skip_set
    skip_set=$(compute_skip_set "$mode" "$MANIFEST_FILE")
    local landed=0
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if [ -f "${cell_home}/.claude/${p}" ]; then
            FAIL=$((FAIL + 1))
            echo "  ✗ skip-list violation: ${p} landed in mode ${mode}" >&2
            landed=1
        fi
    done < <(jq -r '.[]' <<<"$skip_set")
    if [ "$landed" = "0" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ no skip-list files landed in mode ${mode}"
    fi
}

# ─── VALIDATE-03 runtime layer (D-11): no TK agent basename matches SP agent ─
# assert_no_agent_collision <cell_home>
assert_no_agent_collision() {
    local cell_home="$1"
    local sp_agents="${cell_home}/.claude/plugins/cache/claude-plugins-official/superpowers"
    local tk_agents="${cell_home}/.claude/agents"
    if [ ! -d "$sp_agents" ] || [ ! -d "$tk_agents" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ agent-collision check skipped (no SP cache or TK agents dir in sandbox)"
        return
    fi
    local colliding=0
    while IFS= read -r sp_agent; do
        local base
        base="$(basename "$sp_agent")"
        if [ -f "${tk_agents}/${base}" ]; then
            FAIL=$((FAIL + 1))
            echo "  ✗ agent collision: ${base} present in both SP cache and TK agents/" >&2
            colliding=1
        fi
    done < <(find "$sp_agents" -name '*.md' -mindepth 3 -maxdepth 3 2>/dev/null)
    if [ "$colliding" = "0" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ no TK↔SP agent basename collision"
    fi
}

# ─── Fail-fast cell runner (D-02) ────────────────────────────────────────────
# run_cell <cell_name> <body_function_name>
# Invokes body; exits 1 immediately if any assertion inside the body FAILed.
# shellcheck disable=SC2329
run_cell() {
    local cell_name="$1" body_fn="$2"
    local before_fail=$FAIL
    echo ""
    echo "${CYAN}━━ Cell: ${cell_name} ━━${NC}"
    "$body_fn"
    local new_fails
    new_fails=$((FAIL - before_fail))
    if [ "$new_fails" -gt 0 ]; then
        echo "${RED}FAIL: ${cell_name}: ${new_fails} assertion(s) failed${NC}" >&2
        exit 1
    fi
    echo "${GREEN}PASS: ${cell_name}${NC}"
}

# ─── Self-test: exercise helpers against synthetic fixtures ──────────────────
self_test() {
    local TMP
    TMP="$(mktemp -d -t tk-selftest.XXXXXX)"
    trap 'rm -rf "$TMP"' EXIT

    echo "${BLUE}Running validate-release.sh self-test...${NC}"
    echo ""

    # assert_eq: pass path
    assert_eq "a" "a" "assert_eq detects equality"

    # assert_eq: fail path (verify the FAIL counter increments, then reset)
    local baseline_fail=$FAIL
    assert_eq "a" "b" "assert_eq detects inequality (expected to FAIL)" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail" ]; then
        FAIL=$baseline_fail
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_eq FAIL-path works"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_eq FAIL-path did not trigger" >&2
    fi

    # assert_contains: pass path
    assert_contains "world" "hello world" "assert_contains finds substring"

    # assert_contains: fail path (verify the FAIL counter increments, then reset)
    local baseline_fail2=$FAIL
    assert_contains "missing" "hello world" "assert_contains reports missing (expected to FAIL)" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail2" ]; then
        FAIL=$baseline_fail2
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_contains FAIL-path works"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_contains FAIL-path did not trigger" >&2
    fi

    # assert_state_schema with a valid minimal state
    local STATE="$TMP/state.json"
    cat > "$STATE" <<'JSON'
{
  "version": 2,
  "mode": "standalone",
  "detected": {"superpowers": {"present": false}, "gsd": {"present": false}},
  "installed_files": [{"path": "a.md", "sha256": "abc", "installed_at": "2026-01-01"}],
  "skipped_files": [],
  "installed_at": "2026-01-01"
}
JSON
    assert_state_schema "$STATE" "standalone"

    # assert_state_schema: missing file path triggers FAIL
    local baseline_fail3=$FAIL
    assert_state_schema "$TMP/nonexistent.json" "standalone" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail3" ]; then
        FAIL=$baseline_fail3
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_state_schema rejects missing file"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_state_schema did not reject missing file" >&2
    fi

    # compute_skip_set reachable
    local skip
    skip=$(compute_skip_set "complement-sp" "$MANIFEST_FILE")
    assert_eq "array" "$(jq -r 'type' <<<"$skip")" "compute_skip_set returns JSON array for complement-sp"

    # sha256_file reachable
    local HFILE="$TMP/hash-me"
    echo "hello" > "$HFILE"
    local H
    H=$(sha256_file "$HFILE")
    assert_eq "64" "${#H}" "sha256_file returns 64-char hex"

    # assert_skiplist_clean: create a sandbox with no skipped files (clean pass)
    local CLEAN_HOME="$TMP/clean_home"
    mkdir -p "${CLEAN_HOME}/.claude"
    assert_skiplist_clean "$CLEAN_HOME" "complement-sp"

    # assert_no_agent_collision: sandbox with no SP cache → skipped pass
    local NOCOL_HOME="$TMP/nocol_home"
    mkdir -p "${NOCOL_HOME}/.claude/agents"
    assert_no_agent_collision "$NOCOL_HOME"

    echo ""
    echo "Self-test results: ${PASS} passed, ${FAIL} failed"
    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# ─── CLI dispatcher ──────────────────────────────────────────────────────────
case "${1:-}" in
    --self-test)
        self_test
        ;;
    --cell)
        echo "ERROR: --cell <name> not wired yet (Plan 07-03)" >&2
        exit 2
        ;;
    "")
        cat <<USAGE
Usage: bash scripts/validate-release.sh <command>

Commands:
  --self-test      Exercise invariant helpers against synthetic fixtures (Plan 07-01).
  --cell <name>    Run a single matrix cell (Plan 07-03 -- not yet wired).

Phase 7 v4.0.0 release validation runner.
USAGE
        exit 0
        ;;
    *)
        echo "ERROR: unknown arg: $1" >&2
        exit 2
        ;;
esac
