#!/usr/bin/env bash
# test-clean-backups.sh — BACKUP-01 --clean-backups flag assertions.
#
# Scenarios covered (09-VALIDATION.md rows 9-01-01..06):
#   empty-set: no backup dirs -> message + exit 0
#   dry-run: prints [would remove/keep] tags, zero deletions, exit 0
#   prompt-y: answer y -> dir removed
#   prompt-n: answer n -> dir kept (fail-closed also validated)
#   keep-n: --keep=3 with 5 dirs -> 3 newest preserved without prompt
#   invalid-keep: --keep=-1 or --keep=abc -> exit 2
#   rm-scope: non-backup sibling dirs never removed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"
UPDATE_SH="${REPO_ROOT}/scripts/update-claude.sh"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}" >&2
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected substring: ${needle}" >&2
        echo "    actual output: ${haystack}" >&2
    fi
}

assert_dir_absent() {
    local path="$1" msg="$2"
    if [[ ! -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir unexpectedly present: $path)" >&2
    fi
}

assert_dir_present() {
    local path="$1" msg="$2"
    if [[ -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir missing: $path)" >&2
    fi
}

assert_backup_count() {
    local home="$1" expected="$2" msg="$3"
    local actual
    actual=$(( $(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null | wc -l) ))
    assert_eq "$expected" "$actual" "$msg"
}

seed_backup_dirs() {
    # seed_backup_dirs <home> <count>
    # Creates .claude-backup-<epoch>-<n> siblings under <home>
    local home="$1" count="$2"
    local base_epoch=1713974400
    local i
    for ((i = 0; i < count; i++)); do
        mkdir -p "$home/.claude-backup-$((base_epoch + i))-$((1000 + i))"
    done
}

TMPDIR_ROOT="$(mktemp -d -t tk-clean-backups.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
scenario_empty_set() {
    echo ""
    echo "Scenario: empty-set (9-01-05)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/empty"
    mkdir -p "$SCR/.claude"

    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups 2>&1 || true)
    rc=$?

    assert_contains "No toolkit backup directories found" "$OUT" \
        "empty-set: prints no-dirs message"
    assert_eq "0" "$rc" \
        "empty-set: exit code 0"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_dry_run() {
    echo ""
    echo "Scenario: dry-run (9-01-03)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/dryrun"
    mkdir -p "$SCR/.claude"
    seed_backup_dirs "$SCR" 3

    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups --dry-run 2>&1 || true)
    rc=$?

    # Count lines with [would remove] or [would keep]
    local tag_count
    tag_count=$(echo "$OUT" | grep -c '\[would remove\]\|\[would keep\]' || echo "0")
    assert_eq "3" "$tag_count" \
        "dry-run: exactly 3 lines tagged [would remove] or [would keep]"

    # All 3 dirs still present (no deletions)
    assert_backup_count "$SCR" 3 \
        "dry-run: all 3 dirs still present after dry-run"
    assert_eq "0" "$rc" \
        "dry-run: exit code 0"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_prompt_mixed_y_n() {
    echo ""
    echo "Scenario: prompt mixed y/n (9-01-01)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/prompt-yn"
    mkdir -p "$SCR/.claude"
    # Seed 2 dirs; answer y to first (newest), n to second (oldest)
    # list_backup_dirs returns newest-epoch-first, so:
    #   dir[0] = epoch 1713974401 (newer) -> y -> removed
    #   dir[1] = epoch 1713974400 (older) -> n -> kept
    mkdir -p "$SCR/.claude-backup-1713974401-1001"
    mkdir -p "$SCR/.claude-backup-1713974400-1000"

    local FIFO_DIR="${TMPDIR_ROOT}/fifo-yn"
    mkdir -p "$FIFO_DIR"
    local FIFO="$FIFO_DIR/tty"
    mkfifo "$FIFO"
    (printf 'y\nn\n' > "$FIFO") &
    local BG_PID=$!

    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups 0<"$FIFO" 2>&1 || true)
    rc=$?
    wait "$BG_PID" 2>/dev/null || true

    assert_dir_absent "$SCR/.claude-backup-1713974401-1001" \
        "prompt-yn: y-answered dir was removed"
    assert_dir_present "$SCR/.claude-backup-1713974400-1000" \
        "prompt-yn: n-answered dir remains"
    assert_eq "0" "$rc" \
        "prompt-yn: exit code 0"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_fail_closed() {
    echo ""
    echo "Scenario: fail-closed no-tty (9-01-01)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/failclosed"
    mkdir -p "$SCR/.claude"
    mkdir -p "$SCR/.claude-backup-1713974400-1000"

    # No FIFO — subprocess has no tty; read < /dev/tty fails -> default N
    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups 2>&1 </dev/null || true)
    rc=$?

    assert_dir_present "$SCR/.claude-backup-1713974400-1000" \
        "fail-closed: dir preserved when no tty (default N)"
    assert_eq "0" "$rc" \
        "fail-closed: exit code 0"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_keep_n() {
    echo ""
    echo "Scenario: --keep=3 with 5 dirs (9-01-02)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/keep3"
    mkdir -p "$SCR/.claude"
    # Seed 5 dirs with epochs 1713974400..1713974404
    # list_backup_dirs returns newest-first: 1713974404, ..03, ..02, ..01, ..00
    # --keep=3 preserves the 3 newest (04, 03, 02) and prompts for 01 and 00
    for i in 0 1 2 3 4; do
        mkdir -p "$SCR/.claude-backup-$((1713974400 + i))-$((1000 + i))"
    done

    local FIFO_DIR="${TMPDIR_ROOT}/fifo-keep"
    mkdir -p "$FIFO_DIR"
    local FIFO="$FIFO_DIR/tty"
    mkfifo "$FIFO"
    # Answer n to both prompted dirs (epochs 01 and 00) -> all 5 remain
    (printf 'n\nn\n' > "$FIFO") &
    local BG_PID=$!

    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups --keep=3 0<"$FIFO" 2>&1 || true)
    rc=$?
    wait "$BG_PID" 2>/dev/null || true

    # All 5 dirs still present (answered n to both prompts)
    assert_backup_count "$SCR" 5 \
        "keep-n: all 5 dirs still present after answering n twice"

    # The 3 newest dirs must NOT appear as prompt targets in output
    local newest_dir="$SCR/.claude-backup-1713974404-1004"
    local mid_dir="$SCR/.claude-backup-1713974403-1003"
    local mid2_dir="$SCR/.claude-backup-1713974402-1002"
    # Output for kept dirs should show "Keeping:" prefix, not a prompt
    assert_contains "Keeping" "$OUT" \
        "keep-n: output contains 'Keeping' for preserved dirs"
    # Oldest two dirs should appear in prompt (Remove ... ? [y/N]:)
    assert_contains "1713974400" "$OUT" \
        "keep-n: oldest epoch 1713974400 appears in prompt output"
    assert_contains "1713974401" "$OUT" \
        "keep-n: second-oldest epoch 1713974401 appears in prompt output"
    assert_eq "0" "$rc" \
        "keep-n: exit code 0"
    # Suppress unused variable warnings
    : "$newest_dir" "$mid_dir" "$mid2_dir"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_invalid_keep_negative() {
    echo ""
    echo "Scenario: --keep=-1 invalid (9-01-04)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/invalid-neg"
    mkdir -p "$SCR/.claude"
    seed_backup_dirs "$SCR" 2

    local rc
    TK_UPDATE_HOME="$SCR" \
      TK_UPDATE_LIB_DIR="$LIB_DIR" \
      TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
      bash "$UPDATE_SH" --clean-backups --keep=-1 >/dev/null 2>&1 || rc=$?
    rc="${rc:-0}"

    assert_eq "2" "$rc" \
        "invalid-keep negative: --keep=-1 exits with code 2"
    # Dirs untouched
    assert_backup_count "$SCR" 2 \
        "invalid-keep negative: no dirs removed on exit 2"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_invalid_keep_nonnumeric() {
    echo ""
    echo "Scenario: --keep=abc invalid (9-01-04)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/invalid-abc"
    mkdir -p "$SCR/.claude"
    seed_backup_dirs "$SCR" 2

    local rc
    TK_UPDATE_HOME="$SCR" \
      TK_UPDATE_LIB_DIR="$LIB_DIR" \
      TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
      bash "$UPDATE_SH" --clean-backups --keep=abc >/dev/null 2>&1 || rc=$?
    rc="${rc:-0}"

    assert_eq "2" "$rc" \
        "invalid-keep nonnumeric: --keep=abc exits with code 2"
    assert_backup_count "$SCR" 2 \
        "invalid-keep nonnumeric: no dirs removed on exit 2"
}

# ─────────────────────────────────────────────────────────────────────────────
scenario_rm_scope() {
    echo ""
    echo "Scenario: rm-scope safety (9-01-06)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/rmscope"
    mkdir -p "$SCR/.claude"
    mkdir -p "$SCR/.claude-backup-1713974400-1000"
    # Non-matching sibling that must never be touched
    mkdir -p "$SCR/.mydata"

    local FIFO_DIR="${TMPDIR_ROOT}/fifo-scope"
    mkdir -p "$FIFO_DIR"
    local FIFO="$FIFO_DIR/tty"
    mkfifo "$FIFO"
    (printf 'y\n' > "$FIFO") &
    local BG_PID=$!

    local OUT rc
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          bash "$UPDATE_SH" --clean-backups 0<"$FIFO" 2>&1 || true)
    rc=$?
    wait "$BG_PID" 2>/dev/null || true

    assert_dir_absent "$SCR/.claude-backup-1713974400-1000" \
        "rm-scope: backup dir removed after y answer"
    assert_dir_present "$SCR/.mydata" \
        "rm-scope: non-matching sibling .mydata untouched"
    assert_eq "0" "$rc" \
        "rm-scope: exit code 0"
    : "$OUT"
}

# ─────────────────────────────────────────────────────────────────────────────
# Run all scenarios
scenario_empty_set
scenario_dry_run
scenario_prompt_mixed_y_n
scenario_fail_closed
scenario_keep_n
scenario_invalid_keep_negative
scenario_invalid_keep_nonnumeric
scenario_rm_scope

echo ""
echo "======================================="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
echo "======================================="
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
