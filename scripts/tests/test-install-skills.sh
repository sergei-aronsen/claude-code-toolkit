#!/usr/bin/env bash
# test-install-skills.sh — Phase 26 hermetic integration test.
#
# Scenarios (target ≥12 assertions across 6 scenarios):
#   S1_catalog_correctness   — SKILLS_CATALOG has 22 entries; alphabetical order
#   S2_detection_two_state   — is_skill_installed returns 0 (installed) / 1 (not installed)
#   S3_skills_install_basic  — skills_install copies one skill from mirror to TK_SKILLS_HOME via cp -R
#   S4_idempotency_no_force  — re-running skills_install on installed skill returns rc=2 (refused, no overwrite)
#   S5_force_overwrite       — skills_install --force on installed skill returns rc=0 (overwritten)
#   S6_install_sh_dry_run    — install.sh --skills --yes --dry-run produces 22 would-install rows; zero filesystem mutations
#
# Test seam env vars: TK_SKILLS_HOME, TK_SKILLS_MIRROR_PATH, TK_TUI_TTY_SRC
#
# Sample skills used in scenarios (3 of 22, per CONTEXT.md test strategy):
#   ai-models, pdf, tailwind-design-system
#
# Usage: bash scripts/tests/test-install-skills.sh
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
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

echo "test-install-skills.sh: SKILL-03..05 hermetic suite"
echo ""

# ─────────────────────────────────────────────────
# S1_catalog_correctness — SKILLS_CATALOG has 22 entries; alphabetical order
# SKILL-01
# ─────────────────────────────────────────────────
run_s1_catalog_correctness() {
    echo "  -- S1_catalog_correctness: 22 entries, alphabetical order, last is webapp-testing --"
    SKILLS_CATALOG=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/skills.sh"
    assert_eq "22" "${#SKILLS_CATALOG[@]}" "S1: catalog contains 22 entries"
    assert_eq "ai-models" "${SKILLS_CATALOG[0]}" "S1: alphabetical first entry is ai-models"
    assert_eq "webapp-testing" "${SKILLS_CATALOG[21]}" "S1: alphabetical last entry is webapp-testing"
}

# ─────────────────────────────────────────────────
# S2_detection_two_state — is_skill_installed returns 0 (installed) / 1 (not installed)
# SKILL-03
# ─────────────────────────────────────────────────
run_s2_detection_two_state() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_detection_two_state: is_skill_installed 0/1 contract --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME/ai-models"
    touch "$SKILLS_HOME/ai-models/SKILL.md"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        is_skill_installed ai-models
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S2: is_skill_installed ai-models returns 0 when dir exists"

    rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        is_skill_installed pdf
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "1" "$rc" "S2: is_skill_installed pdf returns 1 when dir absent"
}

# ─────────────────────────────────────────────────
# S3_skills_install_basic — skills_install copies one skill via cp -R (SKILL-03)
# ─────────────────────────────────────────────────
run_s3_skills_install_basic() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_skills_install_basic: cp -R correctness for sample skill --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install ai-models
        exit \$?
    " || rc=$?
    assert_eq "0" "$rc" "S3: skills_install ai-models returns 0 on success"

    if [[ -d "$SKILLS_HOME/ai-models" ]]; then
        assert_pass "S3: ~/.claude/skills/ai-models/ directory exists post-install"
    else
        assert_fail "S3: ~/.claude/skills/ai-models/ directory exists post-install" "directory missing"
    fi

    if [[ -f "$SKILLS_HOME/ai-models/SKILL.md" ]]; then
        assert_pass "S3: SKILL.md copied to target dir"
    else
        assert_fail "S3: SKILL.md copied to target dir" "SKILL.md missing"
    fi
}

# ─────────────────────────────────────────────────
# S4_idempotency_no_force — re-install without --force returns rc=2 (SKILL-04)
# ─────────────────────────────────────────────────
run_s4_idempotency_no_force() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_idempotency_no_force: re-install without --force returns rc=2 --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    # First install
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "source '${REPO_ROOT}/scripts/lib/skills.sh'; skills_install pdf" >/dev/null 2>&1

    # Marker: write a sentinel file inside the installed skill to confirm no overwrite
    echo "user-edit" > "$SKILLS_HOME/pdf/USER_EDIT.txt"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install pdf
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "2" "$rc" "S4: skills_install pdf returns 2 on already-installed (no --force)"

    # Sentinel preserved → no overwrite occurred
    if [[ -f "$SKILLS_HOME/pdf/USER_EDIT.txt" ]]; then
        assert_pass "S4: user sentinel file preserved (no overwrite)"
    else
        assert_fail "S4: user sentinel file preserved (no overwrite)" "USER_EDIT.txt was destroyed"
    fi
}

# ─────────────────────────────────────────────────
# S5_force_overwrite — --force re-installs over existing dir (SKILL-04)
# ─────────────────────────────────────────────────
run_s5_force_overwrite() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_force_overwrite: --force re-installs over existing dir --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "source '${REPO_ROOT}/scripts/lib/skills.sh'; skills_install tailwind-design-system" >/dev/null 2>&1

    echo "stale" > "$SKILLS_HOME/tailwind-design-system/STALE_USER_FILE.txt"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install tailwind-design-system --force
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S5: skills_install tailwind-design-system --force returns 0"

    # Stale file destroyed → overwrite occurred
    if [[ ! -f "$SKILLS_HOME/tailwind-design-system/STALE_USER_FILE.txt" ]]; then
        assert_pass "S5: stale user file destroyed (--force overwrote)"
    else
        assert_fail "S5: stale user file destroyed (--force overwrote)" "STALE_USER_FILE.txt still present"
    fi
}

# ─────────────────────────────────────────────────
# S6_install_sh_dry_run — --skills --yes --dry-run: 22 would-install rows, zero mutations (SKILL-05)
# ─────────────────────────────────────────────────
run_s6_install_sh_dry_run() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_install_sh_dry_run: --skills --yes --dry-run preview, zero mutations --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    local output rc=0
    output="$(
        TK_SKILLS_HOME="$SKILLS_HOME" \
        TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
        TK_TUI_TTY_SRC="$SANDBOX/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --skills --yes --dry-run 2>&1
    )" || rc=$?
    assert_eq "0" "$rc" "S6: install.sh --skills --yes --dry-run exits 0"

    local would_count
    would_count=$(printf '%s\n' "$output" | grep -c "would-install" || true)
    assert_eq "22" "$would_count" "S6: dry-run prints 22 would-install rows"

    # Zero filesystem mutations: SKILLS_HOME should still be empty.
    local file_count
    file_count=$(find "$SKILLS_HOME" -mindepth 1 | wc -l | tr -d ' ')
    assert_eq "0" "$file_count" "S6: TK_SKILLS_HOME has zero entries post-dry-run"
}

run_s1_catalog_correctness
run_s2_detection_two_state
run_s3_skills_install_basic
run_s4_idempotency_no_force
run_s5_force_overwrite
run_s6_install_sh_dry_run

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
