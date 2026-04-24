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

# Source shared test helpers (REL-01 extraction, 08-PATTERNS.md §helpers.bash)
# shellcheck source=scripts/tests/matrix/lib/helpers.bash
source "${SCRIPT_DIR}/tests/matrix/lib/helpers.bash"

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

# ─── CLI dispatcher ─────────────────────────────────────────────────────────
CELLS=(
    standalone-fresh standalone-upgrade standalone-rerun
    complement-sp-fresh complement-sp-upgrade complement-sp-rerun
    complement-gsd-fresh complement-gsd-upgrade complement-gsd-rerun
    complement-full-fresh complement-full-upgrade complement-full-rerun
    translation-sync
)

cell_fn_for() {
    echo "cell_$(echo "$1" | tr '-' '_')"
}

case "${1:-}" in
    --self-test)
        self_test
        ;;
    --list)
        for c in "${CELLS[@]}"; do echo "$c"; done
        exit 0
        ;;
    --cell)
        [ -z "${2:-}" ] && { echo "ERROR: --cell requires a name" >&2; exit 2; }
        cell="$2"
        match=0
        for c in "${CELLS[@]}"; do [ "$c" = "$cell" ] && match=1; done
        if [ "$match" = "0" ]; then
            echo "ERROR: unknown cell: $cell" >&2
            echo "Known cells:" >&2
            for c in "${CELLS[@]}"; do echo "  $c" >&2; done
            exit 2
        fi
        run_cell "$cell" "$(cell_fn_for "$cell")"
        echo ""
        echo "Results: ${PASS} passed, ${FAIL} failed"
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
    --all)
        for c in "${CELLS[@]}"; do
            run_cell "$c" "$(cell_fn_for "$c")"
        done
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Matrix complete: ${PASS} assertions passed, ${FAIL} failed across ${#CELLS[@]} cells"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
    "")
        cat <<USAGE
Usage: bash scripts/validate-release.sh <command>

Commands:
  --self-test      Exercise invariant helpers against synthetic fixtures.
  --list           Print all 13 cell names, one per line.
  --cell <name>    Run a single matrix cell.
  --all            Run all 13 cells fail-fast.

Phase 7 v4.0.0 release validation runner.
USAGE
        exit 0
        ;;
    *)
        echo "ERROR: unknown arg: $1" >&2
        exit 2
        ;;
esac
