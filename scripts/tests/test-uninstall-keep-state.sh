#!/usr/bin/env bash
# test-uninstall-keep-state.sh — KEEP-01/KEEP-02 partial-uninstall recovery contract.
#
# Verifies that --keep-state preserves toolkit-install.json and that a subsequent
# uninstall.sh invocation re-classifies still-present modified files (i.e. is NOT
# a no-op). Mirrors the shape of test-uninstall.sh (S1/S2/S3 scenarios) and reuses
# the assertion helpers from test-uninstall-idempotency.sh.
#
# Three scenarios (each a self-contained sandbox):
#   S1. --keep-state + N-choice: state file survives, second run re-classifies
#       Asserts A1 (state present), A2 (second run not no-op via 'Backup created:'),
#       A3 (MODIFIED list non-empty), A4 (base-plugin diff-q invariant via exit 0)
#   S2. --keep-state + y-choice: state file survives even on full-y branch
#       Asserts A1 only (state present)
#   S3. TK_UNINSTALL_KEEP_STATE=1 env-only (no flag): D-09 env-precedence path
#       Asserts A1 only (state present)
#
# Test seams (Phase 18-22 lineage):
#   TK_UNINSTALL_HOME           — redirects CLAUDE_DIR / STATE_FILE / LOCK_DIR to sandbox
#   TK_UNINSTALL_LIB_DIR        — sources lib files from repo root
#   TK_UNINSTALL_TTY_FROM_STDIN — reads [y/N/d] prompts from /dev/stdin instead of /dev/tty
#   TK_UNINSTALL_KEEP_STATE     — KEEP-01 D-09 env-var precedence path (S3)
#
# Usage: bash scripts/tests/test-uninstall-keep-state.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# ─────────────────────────────────────────────────
# Assertion helpers (copy verbatim from test-uninstall-idempotency.sh:27-60)
# ─────────────────────────────────────────────────
assert_pass() {
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "$1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    printf "      %s\n" "$2"
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}

# ─────────────────────────────────────────────────
# S1 — --keep-state + N-choice: state survives, second run re-classifies
# ─────────────────────────────────────────────────
run_s1() {
    local SANDBOX RC OUTPUT CANARY
    SANDBOX="$(mktemp -d /tmp/test-uninstall-keep-state.XXXXXX)"
    # shellcheck disable=SC2064  # expand $SANDBOX NOW for the trap
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S1: --keep-state + N-choice, state survives, second run re-classifies --"

    # Real install via init-local.sh
    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S1 setup" "init-local.sh must succeed before test"
        return
    fi
    if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_fail "S1 setup" "toolkit-install.json missing after init-local.sh"
        return
    fi

    # Modify a canary so the uninstaller classifies at least one MODIFIED file
    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    if [ -z "$CANARY" ]; then
        assert_fail "S1 setup: pick canary" "no .md/.json file in installed_files[]"
        return
    fi
    printf '\n# S1 keep-state modification\n' >> "$SANDBOX/$CANARY"

    # First uninstall WITH --keep-state, answer N to every modified prompt
    RC=0
    OUTPUT=$(printf 'N\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" --keep-state 2>&1) || RC=$?

    assert_eq "0" "$RC" "S1: first uninstall (--keep-state, N) exits 0"

    # A1 — state file preserved by --keep-state
    if [ -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_pass "S1-A1: state file preserved after --keep-state run (KEEP-01)"
    else
        assert_fail "S1-A1: state file preserved" "toolkit-install.json absent — gate failed"
    fi

    # Second uninstall WITHOUT --keep-state — must NOT be a no-op
    RC=0
    OUTPUT=$(printf 'y\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    # A2 — second run proceeded past idempotency guard (line 389)
    # 'Backup created:' is logged at scripts/uninstall.sh:525 — proves backup completed
    assert_contains 'Backup created:' "$OUTPUT" \
        "S1-A2: second run not a no-op (Backup created: marker present)"

    # A3 — MODIFIED list re-classified the still-present modified canary
    # 'MODIFIED' literal is in classify_file output and dry-run header
    assert_contains 'MODIFIED' "$OUTPUT" \
        "S1-A3: MODIFIED files re-classified on second run (non-empty list)"

    # A4 — base-plugin diff-q invariant (UN-05 D-10) still passes
    # exit 0 proves the diff-q check at uninstall.sh succeeded
    assert_eq "0" "$RC" \
        "S1-A4: second run exits 0 (base-plugin diff-q invariant holds)"

    # Bonus: confirm default-branch deletes state file as before (no regression)
    if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_pass "S1: control — second run (no --keep-state) deletes state file (UN-05 default unchanged)"
    else
        assert_fail "S1: control — second run deletes state" \
            "toolkit-install.json still present after non-keep-state run — default-branch regression"
    fi
}

# ─────────────────────────────────────────────────
# S2 — --keep-state + y-choice: state file survives full-y branch
# ─────────────────────────────────────────────────
run_s2() {
    local SANDBOX RC OUTPUT CANARY
    SANDBOX="$(mktemp -d /tmp/test-uninstall-keep-state.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S2: --keep-state + y-choice, state file survives full-y branch --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S2 setup" "init-local.sh must succeed before test"
        return
    fi

    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    [ -n "$CANARY" ] || { assert_fail "S2 setup: pick canary" "no canary"; return; }
    printf '\n# S2 keep-state y-modification\n' >> "$SANDBOX/$CANARY"

    RC=0
    OUTPUT=$(printf 'y\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" --keep-state 2>&1) || RC=$?

    assert_eq "0" "$RC" "S2: --keep-state + y-choice exits 0"

    # A1 — state file preserved even after y-branch (KEEP-01 is independent of [y/N/d])
    if [ -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_pass "S2-A1: state file preserved on y-branch --keep-state run"
    else
        assert_fail "S2-A1: state file preserved on y-branch" \
            "toolkit-install.json absent after y-branch --keep-state — gate misplaced inside [y/N/d] loop?"
    fi

    # Sanity: y-branch should have removed the modified canary
    if [ ! -f "$SANDBOX/$CANARY" ]; then
        assert_pass "S2: y-branch removed the modified canary (UN-03 default unchanged)"
    else
        assert_fail "S2: y-branch removed canary" "canary still present — y-choice regression"
    fi
}

# ─────────────────────────────────────────────────
# S3 — TK_UNINSTALL_KEEP_STATE=1 env-only path (no flag): D-09 env-precedence
# ─────────────────────────────────────────────────
run_s3() {
    local SANDBOX RC OUTPUT CANARY
    SANDBOX="$(mktemp -d /tmp/test-uninstall-keep-state.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S3: TK_UNINSTALL_KEEP_STATE=1 env-only (no flag), D-09 env-precedence --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S3 setup" "init-local.sh must succeed before test"
        return
    fi

    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    [ -n "$CANARY" ] || { assert_fail "S3 setup: pick canary" "no canary"; return; }
    printf '\n# S3 env-only modification\n' >> "$SANDBOX/$CANARY"

    # Invoke uninstall.sh with env var set, NO --keep-state flag
    RC=0
    OUTPUT=$(printf 'N\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_KEEP_STATE=1 \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S3: TK_UNINSTALL_KEEP_STATE=1 env-only exits 0"

    # A1 — state file preserved via env-var path (no --keep-state flag)
    if [ -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_pass "S3-A1: TK_UNINSTALL_KEEP_STATE=1 preserves state file (D-09 env-precedence)"
    else
        assert_fail "S3-A1: TK_UNINSTALL_KEEP_STATE=1 preserves state" \
            "toolkit-install.json absent after env-only run — env-var path broken"
    fi
}

# ─────────────────────────────────────────────────
# Main run block
# ─────────────────────────────────────────────────
echo "Running test-uninstall-keep-state..."
echo ""
run_s1
run_s2
run_s3

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-keep-state: all %d assertions passed${NC}\n" "$PASS"
    exit 0
else
    printf "${RED}✗ test-uninstall-keep-state: %d of %d assertions FAILED${NC}\n" \
        "$FAIL" "$((PASS + FAIL))"
    exit 1
fi
