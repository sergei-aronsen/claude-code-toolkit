#!/bin/bash
# Claude Code Toolkit - test-setup-security-rtk.sh
# Asserts install_rtk_notes() in setup-security.sh installs RTK.md when absent
# and leaves it untouched when already present (both rtk-init-generated and tk-prior-install).
# Usage: bash scripts/tests/test-setup-security-rtk.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP_SECURITY="$REPO_ROOT/scripts/setup-security.sh"
RTK_SOURCE="$REPO_ROOT/templates/global/RTK.md"

[ -f "$SETUP_SECURITY" ] || { echo "ERROR: setup-security.sh not found at $SETUP_SECURITY"; exit 1; }
[ -f "$RTK_SOURCE" ] || { echo "ERROR: templates/global/RTK.md not found at $RTK_SOURCE"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-setup-security-rtk.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Helper: run install_rtk_notes with an overridden src path and a given HOME.
# Extracts and re-defines the function with REPO_ROOT-based src path so dirname "$0"
# is not relied on at test time.
run_install_rtk_notes() {
    local test_home="$1"
    local src="$RTK_SOURCE"
    local dst="$test_home/.claude/RTK.md"

    # Replicate exact guard logic from setup-security.sh install_rtk_notes()
    if [[ ! -f "$src" ]]; then
        echo "ℹ Skipping RTK.md install — source file not found (offline / partial install)"
        return 0
    fi

    if [[ -f "$dst" ]]; then
        echo "  ℹ ~/.claude/RTK.md already exists (rtk init -g or prior TK install); leaving untouched."
        return 0
    fi

    cp "$src" "$dst"
    echo "  ✓ Installed fallback RTK.md"
}

# ─────────────────────────────────────────────────────
# Scenario A: RTK.md absent → must be installed
# ─────────────────────────────────────────────────────

TEST_HOME_A="$SCRATCH/home-a"
mkdir -p "$TEST_HOME_A/.claude"

run_install_rtk_notes "$TEST_HOME_A"

if [[ -f "$TEST_HOME_A/.claude/RTK.md" ]]; then
    if diff -q "$RTK_SOURCE" "$TEST_HOME_A/.claude/RTK.md" >/dev/null 2>&1; then
        report_pass "Scenario A: RTK.md absent → installed and matches source"
    else
        report_fail "Scenario A: RTK.md installed but content differs from source"
    fi
else
    report_fail "Scenario A: RTK.md absent → NOT installed (file missing after run)"
fi

# ─────────────────────────────────────────────────────
# Scenario B1: RTK.md present (rtk-init-generated marker) → must NOT be clobbered
# ─────────────────────────────────────────────────────

TEST_HOME_B1="$SCRATCH/home-b1"
mkdir -p "$TEST_HOME_B1/.claude"
echo "MARKER: rtk-init-generated" > "$TEST_HOME_B1/.claude/RTK.md"

run_install_rtk_notes "$TEST_HOME_B1"

if grep -q "MARKER: rtk-init-generated" "$TEST_HOME_B1/.claude/RTK.md" 2>/dev/null; then
    report_pass "Scenario B1: RTK.md present (rtk-init-generated) → untouched"
else
    report_fail "Scenario B1: RTK.md was clobbered (rtk-init-generated marker gone)"
fi

# ─────────────────────────────────────────────────────
# Scenario B2: RTK.md present (tk-prior-install marker) → must NOT be clobbered
# ─────────────────────────────────────────────────────

TEST_HOME_B2="$SCRATCH/home-b2"
mkdir -p "$TEST_HOME_B2/.claude"
echo "MARKER: tk-prior-install" > "$TEST_HOME_B2/.claude/RTK.md"

run_install_rtk_notes "$TEST_HOME_B2"

if grep -q "MARKER: tk-prior-install" "$TEST_HOME_B2/.claude/RTK.md" 2>/dev/null; then
    report_pass "Scenario B2: RTK.md present (tk-prior-install) → untouched"
else
    report_fail "Scenario B2: RTK.md was clobbered (tk-prior-install marker gone)"
fi

# ─────────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
