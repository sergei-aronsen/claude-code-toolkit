#!/usr/bin/env bash
# test-migrate-flow.sh — Phase 5 Plan 05-03 full flow + state rewrite + partial + lock.
#
# Scenarios:
# 1. accept-all (via --yes) — all duplicates removed, state rewritten to complement-sp
# 2. decline-all (via </dev/null) — no files removed, state still records complement-sp + skipped_files
# 3. partial (via --yes, only 1 duplicate seeded) — mixed outcome: 1 removed, state has the non-conflict files
# 4. backup-failure aborts — no files touched, exit 1 (via chmod read-only HOME)
# 5. synth_flag=false in post-migration state (not a synthesis write)
# 6. concurrent-lock — pre-seeded live PID in LOCK_DIR → migrate exits 1, no files touched

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-migrate-v2.json"
SP_CACHE_FIXTURE_FULL="${FIXTURES_DIR}/sp-cache"
LIB_DIR="${REPO_ROOT}/scripts/lib"

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
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-migrate-flow.XXXXXX)"
trap 'chmod -R 755 "${TMPDIR_ROOT}" 2>/dev/null || true; rm -rf "${TMPDIR_ROOT}"' EXIT

# Helpers
sha256_of() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}
seed_standalone_state() {
    # seed_standalone_state <state_path> [<rel> <content>]...
    # Writes a standalone-mode state with installed_files entries hashed from given contents.
    local state_path="$1"; shift
    local entries="[]"
    while [[ $# -ge 2 ]]; do
        local p="$1" content="$2"; shift 2
        local tmp; tmp=$(mktemp)
        printf '%s' "$content" > "$tmp"
        local h; h=$(sha256_of "$tmp"); rm -f "$tmp"
        entries=$(jq --arg p "$p" --arg h "$h" \
            '. + [{"path": $p, "sha256": $h, "installed_at": "2026-04-15T12:00:00Z"}]' \
            <<<"$entries")
    done
    mkdir -p "$(dirname "$state_path")"
    jq -n --argjson files "$entries" \
        '{"version": 2, "mode": "standalone",
          "synthesized_from_filesystem": true,
          "detected": {"superpowers": {"present": false, "version": ""},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": $files,
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' \
        > "$state_path"
}

# ─────────────────────────────────────────────────
# Scenario 1: accept-all via --yes
# ─────────────────────────────────────────────────
scenario_accept_all() {
    echo ""
    echo "Scenario 1: accept-all (--yes) → all duplicates removed, state → complement-sp"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"
    echo "plan-content"  > "$SCR/.claude/commands/plan.md"
    echo "rules-content" > "$SCR/.claude/rules/README.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands" "$FILE_SRC/rules"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"
    echo "plan-content"  > "$FILE_SRC/commands/plan.md"
    echo "rules-content" > "$FILE_SRC/rules/README.md"

    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content" \
        "commands/plan.md"  "plan-content" \
        "rules/README.md"   "rules-content"

    HOME="$SCR" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes >/dev/null 2>&1 || true

    assert_eq "false" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "commands/debug.md removed"
    assert_eq "false" "$( [ -f "$SCR/.claude/commands/plan.md" ] && echo true || echo false)" \
        "commands/plan.md removed"
    assert_eq "true" "$( [ -f "$SCR/.claude/rules/README.md" ] && echo true || echo false)" \
        "rules/README.md preserved (not conflicting)"

    # Backup dir exists
    local BACKUPS
    BACKUPS=$(find "$SCR" -maxdepth 1 -type d -name ".claude-backup-pre-migrate-*" | wc -l | tr -d " ")
    assert_eq "1" "$BACKUPS" "1 pre-migrate backup dir created"

    # State rewritten
    assert_eq "complement-sp" "$(jq -r .mode "$SCR/.claude/toolkit-install.json")" \
        "state.mode = complement-sp after migration"
    # skipped_files empty for accept-all
    assert_eq "0" "$(jq -r '.skipped_files | length' "$SCR/.claude/toolkit-install.json")" \
        "skipped_files is empty under accept-all"
}

# ─────────────────────────────────────────────────
# Scenario 2: decline-all via </dev/null (fail-closed to N)
# ─────────────────────────────────────────────────
scenario_decline_all() {
    echo ""
    echo "Scenario 2: decline-all (</dev/null fail-closed) → no removal, state → complement-sp + skipped_files"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s2"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"
    echo "plan-content"  > "$SCR/.claude/commands/plan.md"
    echo "rules-content" > "$SCR/.claude/rules/README.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands" "$FILE_SRC/rules"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"
    echo "plan-content"  > "$FILE_SRC/commands/plan.md"
    echo "rules-content" > "$FILE_SRC/rules/README.md"

    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content" \
        "commands/plan.md"  "plan-content" \
        "rules/README.md"   "rules-content"

    HOME="$SCR" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" </dev/null >/dev/null 2>&1 || true

    assert_eq "true" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "commands/debug.md preserved (fail-closed = N)"
    assert_eq "true" "$( [ -f "$SCR/.claude/commands/plan.md" ] && echo true || echo false)" \
        "commands/plan.md preserved (fail-closed = N)"

    assert_eq "complement-sp" "$(jq -r .mode "$SCR/.claude/toolkit-install.json")" \
        "state.mode = complement-sp even under decline-all (D-79)"

    local SKIP_COUNT
    SKIP_COUNT=$(jq -r '.skipped_files | length' "$SCR/.claude/toolkit-install.json")
    # Two duplicates (debug.md + plan.md) — both declined. (rules/README.md is not a duplicate.)
    assert_eq "2" "$SKIP_COUNT" "2 kept_by_user entries in skipped_files"

    local FIRST_REASON
    FIRST_REASON=$(jq -r '.skipped_files[0].reason' "$SCR/.claude/toolkit-install.json")
    assert_eq "kept_by_user" "$FIRST_REASON" "first skipped reason = kept_by_user"
}

# ─────────────────────────────────────────────────
# Scenario 3: partial — only 1 duplicate seeded, --yes removes it
# ─────────────────────────────────────────────────
scenario_partial() {
    echo ""
    echo "Scenario 3: partial (1 duplicate seeded, --yes) — state reflects the mix"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s3"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"   # duplicate (conflicts with SP)
    echo "rules-content" > "$SCR/.claude/rules/README.md"      # not a duplicate

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands" "$FILE_SRC/rules"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"
    echo "rules-content" > "$FILE_SRC/rules/README.md"

    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content" \
        "rules/README.md"   "rules-content"

    HOME="$SCR" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes >/dev/null 2>&1 || true

    assert_eq "false" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "commands/debug.md removed"
    assert_eq "true" "$( [ -f "$SCR/.claude/rules/README.md" ] && echo true || echo false)" \
        "rules/README.md preserved"

    # installed_files now has rules/README.md (the non-conflict survivor)
    local HAS_RULES
    HAS_RULES=$(jq -r '[.installed_files[].path] | any(endswith("rules/README.md"))' \
        "$SCR/.claude/toolkit-install.json")
    assert_eq "true" "$HAS_RULES" "installed_files contains rules/README.md"

    # installed_files does NOT have commands/debug.md
    local HAS_DEBUG
    HAS_DEBUG=$(jq -r '[.installed_files[].path] | any(endswith("commands/debug.md"))' \
        "$SCR/.claude/toolkit-install.json")
    assert_eq "false" "$HAS_DEBUG" "installed_files does NOT contain migrated commands/debug.md"
}

# ─────────────────────────────────────────────────
# Scenario 4: backup failure aborts before any rm
# ─────────────────────────────────────────────────
# Strategy: set HOME to a path whose parent doesn't exist, so the cp -R for
# backup (which uses $HOME/.claude-backup-pre-migrate-*) fails. Meanwhile
# CLAUDE_DIR uses TK_MIGRATE_HOME=$SCR, so enumerate/diff/acquire_lock all
# succeed — only the backup cp -R fails. This decouples backup failure from
# lock acquisition (which needs CLAUDE_DIR's parent to be writable).
scenario_backup_failure_aborts() {
    echo ""
    echo "Scenario 4: backup failure → no files removed, exit 1"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s4"
    mkdir -p "$SCR/.claude/commands"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"

    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content"

    # HOME points at a non-existent parent → cp -R "$CLAUDE_DIR" "$HOME/.claude-backup-..."
    # will fail because the parent directory cannot be created. Lock acquisition
    # uses CLAUDE_DIR=$TK_MIGRATE_HOME/.claude which is writable, so it succeeds.
    local BAD_HOME="$SCR/nonexistent-parent/home"
    # Note: BAD_HOME does NOT exist — cp -R to $BAD_HOME/.claude-backup-... fails.

    local EXIT=0
    HOME="$BAD_HOME" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes >/dev/null 2>&1 || EXIT=$?

    # migrate should have exited non-zero because cp -R backup failed
    if [ "$EXIT" != "0" ]; then
        PASS=$((PASS + 1)); echo "  ✓ migrate exited non-zero on backup failure (exit=$EXIT)"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ migrate should have exited non-zero on backup failure"
    fi
    # MIGRATE-04 invariant: backup failure must NOT remove any files
    assert_eq "true" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "no files removed after backup failure (MIGRATE-04 invariant)"
    # No backup dir created at the real TMPDIR_ROOT level either.
    # BAD_HOME path never existed, so find returns nonzero — guard with || true
    # so pipefail doesn't abort the test.
    local BACKUPS
    BACKUPS=$( (find "$BAD_HOME" -maxdepth 1 -type d -name ".claude-backup-pre-migrate-*" 2>/dev/null || true) | wc -l | tr -d " ")
    assert_eq "0" "$BACKUPS" "no partial backup dir left behind"
}

# ─────────────────────────────────────────────────
# Scenario 5: synth_flag=false in post-migration state
# ─────────────────────────────────────────────────
scenario_synth_flag_false() {
    echo ""
    echo "Scenario 5: post-migration state has synthesized_from_filesystem=false"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s5"
    mkdir -p "$SCR/.claude/commands"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"

    # Seed with synth=true (simulating the prior v3.x synthesis)
    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content"

    HOME="$SCR" \
    TK_MIGRATE_HOME="$SCR" \
    TK_MIGRATE_LIB_DIR="$LIB_DIR" \
    TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_MIGRATE_FILE_SRC="$FILE_SRC" \
    TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
    HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes >/dev/null 2>&1 || true

    assert_eq "false" "$(jq -r '.synthesized_from_filesystem' "$SCR/.claude/toolkit-install.json")" \
        "post-migration state has synthesized_from_filesystem=false (production write)"
}

# ─────────────────────────────────────────────────
# Scenario 6: concurrent-lock — pre-seeded live PID prevents migration
# ─────────────────────────────────────────────────
scenario_concurrent_lock() {
    echo ""
    echo "Scenario 6: concurrent lock held → migrate exits non-zero"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s6"
    mkdir -p "$SCR/.claude/commands"
    echo "debug-content" > "$SCR/.claude/commands/debug.md"

    local FILE_SRC="$SCR/tk-files"
    mkdir -p "$FILE_SRC/commands"
    echo "debug-content" > "$FILE_SRC/commands/debug.md"

    seed_standalone_state "$SCR/.claude/toolkit-install.json" \
        "commands/debug.md" "debug-content"

    # Pre-create the lock with the test process PID (alive) so acquire_lock sees it as live
    mkdir -p "$SCR/.claude/.toolkit-install.lock"
    echo "$$" > "$SCR/.claude/.toolkit-install.lock/pid"

    local OUT EXIT=0
    OUT=$(HOME="$SCR" \
          TK_MIGRATE_HOME="$SCR" \
          TK_MIGRATE_LIB_DIR="$LIB_DIR" \
          TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_MIGRATE_FILE_SRC="$FILE_SRC" \
          TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes 2>&1) || EXIT=$?

    # Lock is held by our $$ → acquire_lock retries 3x then exits 1.
    if [ "$EXIT" != "0" ]; then
        PASS=$((PASS + 1)); echo "  ✓ migrate exited non-zero when lock held (exit=$EXIT)"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ migrate should have exited non-zero under concurrent lock"
        echo "    output: $OUT"
    fi
    # File should still be present (migrate never got past the lock)
    assert_eq "true" "$( [ -f "$SCR/.claude/commands/debug.md" ] && echo true || echo false)" \
        "no files removed when lock held"

    # Cleanup the manufactured lock so EXIT trap does not see it (trap's release_lock is
    # a no-op if the lock is ours from the script, but we pre-seeded it externally here).
    rm -rf "$SCR/.claude/.toolkit-install.lock"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
scenario_accept_all
scenario_decline_all
scenario_partial
scenario_backup_failure_aborts
scenario_synth_flag_false
scenario_concurrent_lock

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
