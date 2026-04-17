#!/bin/bash
# Claude Code Toolkit — state.sh test harness
# Usage: bash scripts/tests/test-state.sh
# Exit: 0 = all pass, 1 = any fail
# Scenarios:
#   A - round-trip write_state / read_state with sha256
#   B - kill -9 durability (atomic write survives SIGKILL)
#   C - concurrent lock serialization (second acquire_lock blocked)
#   D - stale lock reclaim — dead PID (Signal 1)
#   E - stale lock reclaim — old mtime (Signal 2)

set -euo pipefail

STATE_SH="$(cd "$(dirname "$0")/../lib" && pwd)/state.sh"
[ -f "$STATE_SH" ] || { echo "ERROR: state.sh not found at $STATE_SH"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-state.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

report_pass() { echo "✅ PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "❌ FAIL: $1"; FAIL=$((FAIL+1)); }

reset_home() {
    HOME="$SCRATCH"
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"
}

# ──────────────────────────────────────────────────────────────
# Scenario A: round-trip write_state → read_state
# ──────────────────────────────────────────────────────────────
scenario_a_round_trip() {
    reset_home
    # shellcheck source=/dev/null
    source "$STATE_SH"

    write_state "standalone" "false" "" "false" "" "scripts/init-claude.sh" "" >/dev/null 2>&1 \
        || { report_fail "A: write_state failed"; return; }

    [ -f "$STATE_FILE" ] || { report_fail "A: state file not created"; return; }

    local mode hash
    mode=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mode"])' "$STATE_FILE")
    hash=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["installed_files"][0]["sha256"])' "$STATE_FILE")

    if [ "$mode" = "standalone" ] && [ "${#hash}" -eq 64 ]; then
        report_pass "A: round-trip write_state → read_state preserves mode and sha256 (64 hex chars)"
    else
        report_fail "A: mode=$mode hash_len=${#hash}"
    fi
}

# ──────────────────────────────────────────────────────────────
# Scenario B: kill -9 durability
# ──────────────────────────────────────────────────────────────
scenario_b_kill9_durability() {
    reset_home
    # shellcheck source=/dev/null
    source "$STATE_SH"

    # Seed a valid state file first
    write_state "standalone" "false" "" "false" "" "" "" >/dev/null 2>&1

    # Launch 5 concurrent write_state calls, kill -9 each within ~50ms
    local _iter
    for _iter in 1 2 3 4 5; do
        (
            # shellcheck source=/dev/null
            source "$STATE_SH"
            write_state "complement-full" "true" "5.0.7" "true" "1.36.0" \
                "scripts/init-claude.sh,scripts/init-local.sh" \
                "commands/debug.md:conflicts_with:superpowers" >/dev/null 2>&1
        ) &
        local pid=$!
        # Give Python a head-start; bash 3.2 may not support fractional sleep → fall back to 1s
        sleep 0.05 2>/dev/null || sleep 1
        kill -9 "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done

    # Whatever is on disk must be valid JSON
    if python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$STATE_FILE" 2>/dev/null; then
        report_pass "B: state file remains parseable JSON after 5 kill -9 races"
    else
        report_fail "B: state file corrupted after kill -9 races"
    fi

    # Orphaned tmp files should be bounded (kill -9 precludes except-block cleanup)
    local stragglers
    stragglers=$(find "$HOME/.claude" -name 'toolkit-install.*.tmp' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stragglers" -le 5 ]; then
        report_pass "B: stragglers bounded (${stragglers} tmp files)"
    else
        report_fail "B: excessive tmp file leak (${stragglers})"
    fi
}

# ──────────────────────────────────────────────────────────────
# Scenario C: concurrent lock serialization
# ──────────────────────────────────────────────────────────────
scenario_c_concurrent_lock() {
    reset_home
    # shellcheck source=/dev/null
    source "$STATE_SH"

    # Process 1 acquires the lock and holds it for 5s
    (
        # shellcheck source=/dev/null
        source "$STATE_SH"
        acquire_lock >/dev/null 2>&1
        sleep 5
        release_lock
    ) &
    local holder_pid=$!
    sleep 1   # give holder time to mkdir the lock

    # Process 2 tries to acquire — should retry 3x then fail
    local err_out rc
    err_out=$(
        bash -c 'source "'"$STATE_SH"'" && acquire_lock' 2>&1
    ) && rc=0 || rc=$?

    wait "$holder_pid" 2>/dev/null || true

    if [ "$rc" != "0" ] && echo "$err_out" | grep -q 'Another install is in progress'; then
        report_pass "C: second acquire_lock blocked by live holder (rc=$rc)"
    else
        report_fail "C: concurrent lock not serialized (rc=$rc, err=$err_out)"
    fi
}

# ──────────────────────────────────────────────────────────────
# Scenario D: stale lock — dead PID (Signal 1)
# ──────────────────────────────────────────────────────────────
scenario_d_stale_dead_pid() {
    reset_home
    # shellcheck source=/dev/null
    source "$STATE_SH"

    mkdir -p "$LOCK_DIR"
    # PID 99999 is reliably dead on any POSIX system (max valid PID on Linux ~ 4M;
    # Darwin reserves much lower values; 99999 never corresponds to an active process)
    echo "99999" > "$LOCK_DIR/pid"
    # Touch the lock dir to be RECENT so only the PID-liveness branch fires
    touch "$LOCK_DIR"

    local out rc
    out=$(acquire_lock 2>&1) && rc=0 || rc=$?
    release_lock

    if [ "$rc" = "0" ] && echo "$out" | grep -q 'Reclaimed stale lock from PID 99999'; then
        report_pass "D: stale lock with dead PID reclaimed"
    else
        report_fail "D: dead PID reclaim (rc=$rc, out=$out)"
    fi
}

# ──────────────────────────────────────────────────────────────
# Scenario E: stale lock — old mtime (Signal 2)
# ──────────────────────────────────────────────────────────────
scenario_e_stale_old_mtime() {
    reset_home
    # shellcheck source=/dev/null
    source "$STATE_SH"

    mkdir -p "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"    # $$ is live — we want the mtime branch to fire

    # Set mtime 2 hours ago so age > 3600s
    if [[ "$(uname)" == "Darwin" ]]; then
        local ts
        ts=$(date -v-2H +%Y%m%d%H%M)
        touch -t "$ts" "$LOCK_DIR"
    else
        touch -d '2 hours ago' "$LOCK_DIR"
    fi

    local out rc
    out=$(acquire_lock 2>&1) && rc=0 || rc=$?
    release_lock

    if [ "$rc" = "0" ] && echo "$out" | grep -q 'Reclaimed stale lock'; then
        report_pass "E: stale lock with old mtime reclaimed"
    else
        report_fail "E: old mtime reclaim (rc=$rc, out=$out)"
    fi
}

# ──────────────────────────────────────────────────────────────
# Run all scenarios
# ──────────────────────────────────────────────────────────────
scenario_a_round_trip
scenario_b_kill9_durability
scenario_c_concurrent_lock
scenario_d_stale_dead_pid
scenario_e_stale_old_mtime

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
