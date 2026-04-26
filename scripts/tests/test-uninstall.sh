#!/usr/bin/env bash
# test-uninstall.sh — UN-08 round-trip integration test.
#
# Runs the REAL init-local.sh against a /tmp/ sandbox, then runs the REAL
# uninstall.sh. No synthetic state-file fabrication — proves the install→uninstall
# contract end-to-end.
#
# Five scenario blocks:
#   S1 — clean round-trip (no modifications)
#   S2 — modified file, choice "y" (remove)
#   S3 — modified file, choice "N" (keep, default)
#   S4 — modified file, choice "d" then "N" (diff → keep)
#   S5 — --dry-run zero-mutation + double-uninstall idempotency
#
# Usage: bash scripts/tests/test-uninstall.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

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
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

# cross-platform sha256
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# ─────────────────────────────────────────────────
# S1: clean round-trip (no modifications)
# ─────────────────────────────────────────────────
run_s1() {
    local SANDBOX RC OUTPUT FILE_COUNT
    SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
    # shellcheck disable=SC2064  # we want $SANDBOX expanded NOW for the trap
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S1: clean round-trip --"

    # Real install
    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S1 setup: init-local.sh exited non-zero" "(install must succeed before uninstall can be tested)"
        return
    fi
    # Sanity: install produced a state file
    if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_fail "S1 setup: toolkit-install.json present after init" "(state file missing — install did not record)"
        return
    fi

    # Real uninstall (no stdin needed — no modifications)
    RC=0
    OUTPUT=$(HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S1: uninstall exits 0 on clean round-trip"

    # Critical assertion: 0 toolkit files left in .claude/ after uninstall
    FILE_COUNT="$(find "$SANDBOX/.claude" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
    assert_eq "0" "$FILE_COUNT" "S1: find .claude -type f == 0 after clean round-trip"

    # State file deleted
    if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
        assert_pass "S1: toolkit-install.json absent after clean uninstall (UN-05)"
    else
        assert_fail "S1: toolkit-install.json absent" "file still present"
    fi
}

# ─────────────────────────────────────────────────
# S2: modified file, choice "y" (remove)
# ─────────────────────────────────────────────────
run_s2() {
    local SANDBOX RC OUTPUT CANARY
    local BACKUP_DIR
    SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S2: modified file, choice 'y' --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S2 setup" "init-local.sh failed"
        return
    fi

    # Pick a canary that init-local.sh definitely installed.
    # Use jq to select the first .md/.json file path from installed_files[].
    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    if [ -z "$CANARY" ]; then
        assert_fail "S2 setup: pick canary" "no .md/.json file in installed_files[]"
        return
    fi
    # Modify the canary
    printf '\n# S2 modification — should trigger MODIFIED prompt\n' >> "$SANDBOX/$CANARY"

    # Inject "y\n" via stdin and invoke uninstall
    RC=0
    OUTPUT=$(printf 'y\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S2: uninstall exits 0 on 'y' choice for modified file"

    # Modified file is deleted (y choice removes it)
    if [ ! -f "$SANDBOX/$CANARY" ]; then
        assert_pass "S2: modified canary deleted after 'y' choice"
    else
        assert_fail "S2: modified canary deleted" "file still exists at $CANARY"
    fi

    # Backup directory exists (UN-04 invariant).
    # uninstall.sh runs: cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
    # so the backup contains the .claude/ tree without the .claude/ prefix:
    #   $BACKUP_DIR/agents/planner.md  (not $BACKUP_DIR/.claude/agents/planner.md)
    # Strip the leading ".claude/" from CANARY to build the backup path.
    BACKUP_DIR="$(find "$SANDBOX" -maxdepth 1 -name '.claude-backup-pre-uninstall-*' -type d 2>/dev/null | head -1)"
    if [ -n "$BACKUP_DIR" ]; then
        assert_pass "S2: backup directory created"
        # Strip ".claude/" prefix — backup is a flat copy of .claude/ contents
        CANARY_IN_BACKUP="${CANARY#.claude/}"
        if [ -f "$BACKUP_DIR/$CANARY_IN_BACKUP" ]; then
            assert_pass "S2: backup preserves canary copy (UN-04)"
        else
            assert_fail "S2: backup preserves canary" "$BACKUP_DIR/$CANARY_IN_BACKUP missing"
        fi
    else
        assert_fail "S2: backup directory created" "no .claude-backup-pre-uninstall-* in SANDBOX"
    fi
}

# ─────────────────────────────────────────────────
# S3: modified file, choice "N" (keep, default)
# ─────────────────────────────────────────────────
run_s3() {
    local SANDBOX RC OUTPUT CANARY
    SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S3: modified file, choice 'N' (default) --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S3 setup" "init-local.sh failed"
        return
    fi

    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    if [ -z "$CANARY" ]; then
        assert_fail "S3 setup: pick canary" "no .md/.json file in installed_files[]"
        return
    fi
    printf '\n# S3 modification — should be kept on N choice\n' >> "$SANDBOX/$CANARY"

    # Inject "N\n" — explicit keep
    RC=0
    OUTPUT=$(printf 'N\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S3: uninstall exits 0 on 'N' choice"

    # Modified file is PRESERVED (N choice keeps it)
    if [ -f "$SANDBOX/$CANARY" ]; then
        assert_pass "S3: modified canary preserved after 'N' choice (UN-03 default keep)"
    else
        assert_fail "S3: modified canary preserved" "file deleted despite N choice"
    fi
}

# ─────────────────────────────────────────────────
# S4: modified file, choice "d" then "N" (diff renders, then keep)
# ─────────────────────────────────────────────────
run_s4() {
    local SANDBOX RC OUTPUT CANARY
    SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S4: modified file, choice 'd' then 'N' --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S4 setup" "init-local.sh failed"
        return
    fi

    CANARY=$(jq -r '.installed_files[] | .path' "$SANDBOX/.claude/toolkit-install.json" \
             | grep -E '\.(md|json)$' | grep -v 'toolkit-install' | head -1)
    if [ -z "$CANARY" ]; then
        assert_fail "S4 setup: pick canary" "no .md/.json file in installed_files[]"
        return
    fi
    printf '\n# S4 modification — d should render diff then re-prompt\n' >> "$SANDBOX/$CANARY"

    RC=0
    OUTPUT=$(printf 'd\nN\n' | \
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        TK_UNINSTALL_TTY_FROM_STDIN=1 \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S4: uninstall exits 0 on 'd' then 'N' choice"

    # Diff branch rendered SOMETHING — either a "diff" / "@@" / "Reference unavailable"
    # marker (curl may fail in CI sandbox without network — uninstall.sh handles that
    # by printing "reference unavailable" per Phase 18 SC#3).
    if printf '%s' "$OUTPUT" | grep -qE '(@@|Reference unavailable|reference unavailable|diff )'; then
        assert_pass "S4: 'd' branch rendered diff or unavailable notice"
    else
        assert_fail "S4: 'd' branch rendered" "no diff or unavailable marker in output"
        printf '      output (last 20 lines):\n'
        printf '%s\n' "$OUTPUT" | tail -20 | sed 's/^/        /'
    fi

    # After d → N the canary is preserved
    if [ -f "$SANDBOX/$CANARY" ]; then
        assert_pass "S4: canary preserved after 'd' then 'N'"
    else
        assert_fail "S4: canary preserved" "file deleted despite final N choice"
    fi
}

# ─────────────────────────────────────────────────
# S5: --dry-run zero-mutation + double-uninstall idempotency
# ─────────────────────────────────────────────────
run_s5() {
    local SANDBOX RC1 RC2 RC3 OUTPUT_DRY OUTPUT_RUN1 OUTPUT_RUN2
    local PRE_TREE POST_DRY_TREE
    SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- Scenario S5: --dry-run + double-uninstall idempotency --"

    if ! (cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1); then
        assert_fail "S5 setup" "init-local.sh failed"
        return
    fi

    # Snapshot the .claude/ tree (sorted find listing) BEFORE dry-run
    PRE_TREE=$(find "$SANDBOX/.claude" -type f 2>/dev/null | sort)

    # 1. --dry-run zero-mutation
    RC1=0
    # OUTPUT_DRY captured for potential debug but not asserted on (tree diff is the real check)
    OUTPUT_DRY=""
    OUTPUT_DRY=$(HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1) || RC1=$?
    assert_eq "0" "$RC1" "S5.1: --dry-run exits 0"
    # Silence unused-variable lint (OUTPUT_DRY preserved for diagnostics if test fails)
    : "${OUTPUT_DRY}"

    # POST_DRY_TREE must equal PRE_TREE — zero filesystem mutations
    POST_DRY_TREE=$(find "$SANDBOX/.claude" -type f 2>/dev/null | sort)
    if [ "$PRE_TREE" = "$POST_DRY_TREE" ]; then
        assert_pass "S5.1: --dry-run produced zero filesystem changes (UN-02)"
    else
        assert_fail "S5.1: --dry-run zero-mutation" "tree changed under --dry-run"
    fi

    # No backup directory should exist after --dry-run
    if [ -z "$(find "$SANDBOX" -maxdepth 1 -name '.claude-backup-pre-uninstall-*' -type d 2>/dev/null)" ]; then
        assert_pass "S5.1: --dry-run created no backup directory"
    else
        assert_fail "S5.1: --dry-run created no backup" "backup dir found"
    fi

    # 2. Real uninstall (sanity baseline)
    RC2=0
    # OUTPUT_RUN1 captured for potential debug if S5.2 fails
    OUTPUT_RUN1=""
    OUTPUT_RUN1=$(HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC2=$?
    assert_eq "0" "$RC2" "S5.2: first real uninstall exits 0"
    # Silence unused-variable lint (OUTPUT_RUN1 preserved for diagnostics)
    : "${OUTPUT_RUN1}"

    # 3. Second invocation — must print no-op and exit 0
    RC3=0
    OUTPUT_RUN2=$(HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC3=$?
    assert_eq "0" "$RC3" "S5.3: second uninstall exits 0 (UN-06 idempotency)"

    if printf '%s\n' "$OUTPUT_RUN2" | grep -qF 'Toolkit not installed; nothing to do'; then
        assert_pass "S5.3: second invocation prints no-op message (UN-06)"
    else
        assert_fail "S5.3: second invocation prints no-op message" \
            "RC=$RC3; tail: $(printf '%s\n' "$OUTPUT_RUN2" | tail -5)"
    fi
}

# ─────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────
echo "Running test-uninstall (round-trip integration)..."
echo ""

run_s1
echo ""
run_s2
echo ""
run_s3
echo ""
run_s4
echo ""
run_s5

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall: all %d assertions passed${NC}\n" "$PASS"
    exit 0
else
    printf "${RED}✗ test-uninstall: %d of %d assertions FAILED${NC}\n" \
        "$FAIL" "$((PASS + FAIL))"
    exit 1
fi
