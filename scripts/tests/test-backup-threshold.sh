#!/usr/bin/env bash
# test-backup-threshold.sh — BACKUP-02 non-fatal threshold warning assertions.
#
# Scenarios (09-VALIDATION.md rows 9-02-01..03):
#   - count=10 (boundary): warn_if_too_many_backups is silent
#   - count=11: warn_if_too_many_backups emits warning line
#   - migrate-to-complement: warning emitted from migrate path, migration continues (exit 0)
#   - negative: setup-security.sh does NOT contain the wiring
#
# Exit 0 on all pass, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-migrate-v2.json"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected substring: ${needle}"
        echo "    in: ${haystack}" | head -5
    fi
}

assert_not_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if ! echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    unexpected substring found: ${needle}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-backup-threshold.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# seed_backup_dirs <home> <count>
# Creates .claude-backup-<epoch>-<n> siblings under <home>
seed_backup_dirs() {
    local home="$1" count="$2"
    local base_epoch=1713974400 i
    for ((i = 0; i < count; i++)); do
        mkdir -p "$home/.claude-backup-$((base_epoch + i))-$((1000 + i))"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario: boundary_10_silent
# warn_if_too_many_backups must stay silent when count == 10 (boundary)
# 9-02-02
# ─────────────────────────────────────────────────────────────────────────────
scenario_boundary_10_silent() {
    echo ""
    echo "Scenario: boundary_10_silent (9-02-02)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/unit-10"
    mkdir -p "$SCR"
    seed_backup_dirs "$SCR" 10

    local OUT
    OUT=$(HOME="$SCR" bash -c 'source "$1"; warn_if_too_many_backups' -- \
            "$REPO_ROOT/scripts/lib/backup.sh" 2>&1 || true)

    assert_not_contains "toolkit backup dirs under" "$OUT" \
        "count=10: warn_if_too_many_backups silent at boundary"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario: trigger_11_warns
# warn_if_too_many_backups must emit the warning line when count == 11
# 9-02-01
# ─────────────────────────────────────────────────────────────────────────────
scenario_trigger_11_warns() {
    echo ""
    echo "Scenario: trigger_11_warns (9-02-01)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/unit-11"
    mkdir -p "$SCR"
    seed_backup_dirs "$SCR" 11

    local OUT
    OUT=$(HOME="$SCR" bash -c 'source "$1"; warn_if_too_many_backups' -- \
            "$REPO_ROOT/scripts/lib/backup.sh" 2>&1 || true)

    assert_contains "11 toolkit backup dirs under" "$OUT" \
        "count=11: threshold warning emitted"
    assert_contains "update-claude.sh --clean-backups" "$OUT" \
        "count=11: warning points to --clean-backups"
}

# ─────────────────────────────────────────────────────────────────────────────
# seed_migrate_standalone_state <state_path>
# Writes a minimal standalone-mode state with one installed file so migrate
# finds a duplicate and proceeds past the "nothing to migrate" early exit.
# ─────────────────────────────────────────────────────────────────────────────
seed_migrate_standalone_state() {
    local state_path="$1"
    mkdir -p "$(dirname "$state_path")"
    # sha256 of "debug-content" — hardcoded to avoid dependency on python3 here
    local h
    h=$(python3 -c 'import hashlib; print(hashlib.sha256(b"debug-content").hexdigest())')
    jq -n --arg h "$h" \
        '{"version": 2, "mode": "standalone",
          "synthesized_from_filesystem": true,
          "detected": {"superpowers": {"present": false, "version": ""},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": [{"path": "commands/debug.md", "sha256": $h,
                                "installed_at": "2026-04-15T12:00:00Z"}],
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' > "$state_path"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario: migrate_warns
# Running migrate-to-complement.sh with 10 pre-seeded dirs (backup creation
# brings count to 11) emits the threshold warning and exits 0 (non-fatal).
# 9-02-03
# ─────────────────────────────────────────────────────────────────────────────
scenario_migrate_warns() {
    echo ""
    echo "Scenario: migrate_warns (9-02-03)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/migrate-warn"
    local SP_CACHE_FIXTURE="${FIXTURES_DIR}/sp-cache"
    mkdir -p "$SCR/.claude/commands"
    seed_backup_dirs "$SCR" 10

    # Seed a duplicate file that matches the manifest so migrate reaches the backup block
    echo "debug-content" > "$SCR/.claude/commands/debug.md"

    # Toolkit file source dir — same content so it counts as a hash-matching duplicate
    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"

    # Standalone state with the duplicate registered
    seed_migrate_standalone_state "$SCR/.claude/toolkit-install.json"

    local OUT RC
    # Drive migrate-to-complement.sh under sandbox HOME.
    # HAS_SP=true + TK_MIGRATE_SP_CACHE_DIR ensures duplicate detection proceeds.
    # HOME= makes warn_if_too_many_backups use the sandbox (10 pre-seeded + 1 backup = 11).
    # --yes skips per-file prompts.
    RC=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes 2>&1) || RC=$?

    assert_contains "toolkit backup dirs under" "$OUT" \
        "migrate: threshold warning emitted after backup creation"
    assert_eq "0" "$RC" \
        "migrate: exits 0 (warning is non-fatal)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario: setup_security_excluded
# setup-security.sh must NOT contain warn_if_too_many_backups (RESEARCH.md audit)
# Negative assertion — no runtime execution needed.
# ─────────────────────────────────────────────────────────────────────────────
scenario_setup_security_excluded() {
    echo ""
    echo "Scenario: setup_security_excluded"
    echo "---"
    local SETUP_SECURITY="$REPO_ROOT/scripts/setup-security.sh"

    if grep -q 'warn_if_too_many_backups' "$SETUP_SECURITY" 2>/dev/null; then
        FAIL=$((FAIL + 1))
        echo "  ✗ setup-security.sh must NOT contain warn_if_too_many_backups (excluded per RESEARCH.md)"
    else
        PASS=$((PASS + 1))
        echo "  ✓ setup-security.sh does not contain warn_if_too_many_backups (correct exclusion)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────────────────────────────────
scenario_boundary_10_silent
scenario_trigger_11_warns
scenario_migrate_warns
scenario_setup_security_excluded

echo ""
echo "─────────────────────────────────"
echo "Results: PASS=${PASS} FAIL=${FAIL}"
echo "─────────────────────────────────"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
