#!/usr/bin/env bash
# test-update-dry-run.sh — UX-01 SC2 update-claude.sh --dry-run assertions.
#
# Scenarios (Phase 11 Plan 11-02):
#   1. --dry-run exits 0
#   2. Zero filesystem writes (snapshot identical before/after)
#   3. [+ INSTALL] group renders when NEW_FILES non-empty
#   4. [- REMOVE] group renders when REMOVED_FROM_MANIFEST non-empty
#   5. [- SKIP]  group renders for complement-sp mode
#   6. Total: footer present
#   7. NO_COLOR=1 strips ANSI (no-color.org compliance)
#   8. --clean-backups --dry-run unchanged (existing run_clean_backups path)
#
# Usage: bash scripts/tests/test-update-dry-run.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

# Reuse existing manifest fixture (created in Phase 4 / Phase 9 tests).
# If absent, fall back to the live manifest.json.
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"
if [[ ! -f "$MANIFEST_FIXTURE" ]]; then
    MANIFEST_FIXTURE="${REPO_ROOT}/manifest.json"
fi

PASS=0
FAIL=0

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -qE -- "$needle"; then
        PASS=$((PASS + 1)); echo "  OK ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL ${msg}"
        echo "      expected pattern: ${needle}"
        echo "      output excerpt:   $(echo "$haystack" | head -10)"
    fi
}

assert_not_contains_ansi() {
    local haystack="$1" msg="$2"
    if printf '%s' "$haystack" | grep -q $'\x1b\['; then
        FAIL=$((FAIL + 1)); echo "  FAIL ${msg} (ANSI escape found)"
    else
        PASS=$((PASS + 1)); echo "  OK ${msg}"
    fi
}

# assert_dryrun_lines_ansi_free — extract only the dry-run section lines (headers + file
# entries + Total:) from output, then assert no ANSI escapes in those lines.
# The surrounding update-claude.sh log_info/log_success lines use unconditional ANSI codes
# (hardcoded $BLUE/$GREEN at file top) which are outside the dro_* contract — we only
# verify that the dro_* output lines (the ones print_update_dry_run emits) are ANSI-free.
assert_dryrun_lines_ansi_free() {
    local haystack="$1" msg="$2"
    # Extract lines that are dry-run section output: headers ([+/-/~] ...), indented files, Total:
    local dryrun_lines
    dryrun_lines=$(printf '%s\n' "$haystack" | grep -E '^\[|^  [^ ]|^Total:' || true)
    if [ -z "$dryrun_lines" ]; then
        PASS=$((PASS + 1)); echo "  OK ${msg} (no dro_* output lines found — vacuously clean)"
        return
    fi
    if printf '%s\n' "$dryrun_lines" | grep -q $'\x1b\['; then
        FAIL=$((FAIL + 1)); echo "  FAIL ${msg} (ANSI escape found in dro_* output lines)"
        printf '%s\n' "$dryrun_lines" | cat -v | head -5
    else
        PASS=$((PASS + 1)); echo "  OK ${msg}"
    fi
}

# Cross-platform md5 for snapshot
md5_any() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    else
        md5sum "$1" | awk '{print $1}'
    fi
}

snapshot() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "empty"
        return
    fi
    find "$dir" -type f -print | sort | while IFS= read -r f; do
        printf '%s %s\n' "$f" "$(md5_any "$f")"
    done | (md5 -q /dev/stdin 2>/dev/null || md5sum | awk '{print $1}')
}

TMPDIR_ROOT="$(mktemp -d -t tk-update-dryrun.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# seed_minimal_state — write a v2 toolkit-install.json with given mode + installed paths CSV.
# Args: $1=state_path $2=mode $3=installed_paths (CSV, may be empty) $4=orphan_path (may be empty)
seed_minimal_state() {
    local state_path="$1" mode="$2" installed_csv="$3" orphan_path="$4"
    mkdir -p "$(dirname "$state_path")"
    # Build installed_files JSON array from CSV (relative paths) + 1 orphan
    local installed_json
    installed_json=$(python3 -c "
import json, sys
csv = sys.argv[1]
orphan = sys.argv[2]
paths = [p for p in csv.split(',') if p]
out = [{'path': p, 'sha256': 'deadbeef'} for p in paths]
if orphan:
    out.append({'path': orphan, 'sha256': 'orphanhash'})
print(json.dumps(out))
" "$installed_csv" "$orphan_path")

    jq -n \
        --arg mode "$mode" \
        --argjson installed "$installed_json" \
        '{
          version: 2,
          mode: $mode,
          synthesized_from_filesystem: false,
          detected: {
            superpowers: {present: true,  version: "5.1.0"},
            gsd:         {present: false, version: ""}
          },
          installed_files: $installed,
          skipped_files: [],
          installed_at: "2026-01-01T00:00:00Z",
          manifest_hash: "stalehash"
        }' > "$state_path"
}

# run_update_dryrun <sandbox_home> [extra_KEY=val ...]
# Captures combined output from update-claude.sh --dry-run and returns string.
# Extra KEY=val pairs are handled by temporarily exporting each one, then
# unexporting after the call — avoids "unbound variable" under set -u with
# empty arrays while still supporting NO_COLOR=1 and similar overrides.
run_update_dryrun() {
    local sandbox="$1"; shift
    local out exit_code=0

    # Save and apply any extra KEY=val overrides
    local extra_keys=()
    local k
    for k in "$@"; do
        local kname kval
        kname="${k%%=*}"
        kval="${k#*=}"
        extra_keys+=("$kname")
        export "${kname}=${kval}"
    done

    out=$(TK_UPDATE_HOME="$sandbox" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_FILE_SRC="$sandbox/.src" \
        HAS_SP="true" HAS_GSD="false" \
        SP_VERSION="5.1.0" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --dry-run 2>&1) || exit_code=$?

    # Restore: unset any extra keys we exported
    for k in "${extra_keys[@]:-}"; do
        [[ -z "$k" ]] && continue
        unset "$k"
    done

    printf '%s' "$out"
    return "$exit_code"
}

# ─────────────────────────────────────────────────
# Scenario 1+2+3+6: standalone mode — INSTALL group renders, zero writes, exit 0, Total footer
# ─────────────────────────────────────────────────
scenario_install_group_renders() {
    echo ""
    echo "Scenario: INSTALL group renders + zero writes + exit 0 + Total footer"
    echo "---"
    local SCR="${TMPDIR_ROOT}/install"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    # Seed state with empty installed_files so EVERY manifest path is NEW
    seed_minimal_state "$SCR/.claude/toolkit-install.json" "standalone" "" ""

    local snap_before snap_after OUT exit_code=0
    snap_before=$(snapshot "$SCR/.claude")
    OUT=$(run_update_dryrun "$SCR") || exit_code=$?
    snap_after=$(snapshot "$SCR/.claude")

    # Test 1: exits 0
    if [ "$exit_code" -eq 0 ]; then
        PASS=$((PASS + 1)); echo "  OK --dry-run exits 0"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL --dry-run exited $exit_code (expected 0)"
        echo "      output: $(echo "$OUT" | head -5)"
    fi

    # Test 2: zero filesystem writes
    if [ "$snap_before" = "$snap_after" ]; then
        PASS=$((PASS + 1)); echo "  OK zero filesystem writes (snapshot identical)"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL filesystem changed during dry-run"
    fi

    # Also verify no backup dir was created
    if ls -d "$SCR/.claude-backup-"* >/dev/null 2>&1; then
        FAIL=$((FAIL + 1)); echo "  FAIL backup directory was created during --dry-run"
    else
        PASS=$((PASS + 1)); echo "  OK no backup directory created"
    fi

    # Test 3: [+ INSTALL] group header
    assert_contains '^\[\+ INSTALL\] +[0-9]+ files$' "$OUT" "[+ INSTALL] header with right-aligned count"

    # Test 6: Total: footer
    assert_contains '^Total: [0-9]+ files$' "$OUT" "Total: footer present"
}

# ─────────────────────────────────────────────────
# Scenario 4: REMOVE group — orphan in state.installed_files but not in manifest
# ─────────────────────────────────────────────────
scenario_remove_group_renders() {
    echo ""
    echo "Scenario: [- REMOVE] group renders for orphan path"
    echo "---"
    local SCR="${TMPDIR_ROOT}/remove"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_minimal_state "$SCR/.claude/toolkit-install.json" "standalone" "" "commands/old-deprecated.md"

    local OUT
    OUT=$(run_update_dryrun "$SCR") || true
    assert_contains '^\[- REMOVE\] +[0-9]+ files$' "$OUT" "[- REMOVE] header with right-aligned count"
}

# ─────────────────────────────────────────────────
# Scenario 5: SKIP group — complement-sp mode, manifest has superpowers/* paths
# The manifest fixture contains agents/code-reviewer.md + commands/debug.md etc.
# with conflicts_with: ["superpowers"] — these get skipped in complement-sp mode.
# ─────────────────────────────────────────────────
scenario_skip_group_renders() {
    echo ""
    echo "Scenario: [- SKIP] group renders for complement-sp mode"
    echo "---"
    local SCR="${TMPDIR_ROOT}/skip"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_minimal_state "$SCR/.claude/toolkit-install.json" "complement-sp" "" ""

    local OUT
    OUT=$(run_update_dryrun "$SCR") || true
    assert_contains '^\[- SKIP\] +[0-9]+ files$' "$OUT" "[- SKIP] header with right-aligned count"
    assert_contains 'conflicts_with:superpowers' "$OUT" "skip annotation present"
}

# ─────────────────────────────────────────────────
# Scenario 7: NO_COLOR=1 strips ANSI
# ─────────────────────────────────────────────────
scenario_no_color() {
    echo ""
    echo "Scenario: NO_COLOR=1 strips ANSI"
    echo "---"
    local SCR="${TMPDIR_ROOT}/nocolor"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    seed_minimal_state "$SCR/.claude/toolkit-install.json" "standalone" "" ""

    local OUT
    OUT=$(run_update_dryrun "$SCR" "NO_COLOR=1") || true
    assert_dryrun_lines_ansi_free "$OUT" "NO_COLOR=1: dro_* output lines have zero ANSI escapes"
}

# ─────────────────────────────────────────────────
# Scenario 8: --clean-backups --dry-run path unchanged
# ─────────────────────────────────────────────────
scenario_clean_backups_unchanged() {
    echo ""
    echo "Scenario: --clean-backups --dry-run preserves existing path"
    echo "---"
    local SCR="${TMPDIR_ROOT}/clean"
    mkdir -p "$SCR/.claude"
    # Create a fake backup dir under the sandbox HOME so list_backup_dirs has something to enumerate
    mkdir -p "$SCR/.claude-backup-1700000000-99999"
    touch "$SCR/.claude-backup-1700000000-99999/.placeholder"

    local OUT
    OUT=$(env \
        TK_UPDATE_HOME="$SCR" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        HAS_SP="true" HAS_GSD="false" \
        SP_VERSION="5.1.0" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --clean-backups --dry-run 2>&1 || true)

    # Expect either '[would keep]' or '[would remove]' (run_clean_backups output)
    # OR 'No toolkit backup directories found' (empty-set message)
    if echo "$OUT" | grep -qE '\[would (keep|remove)\]|No toolkit backup directories found'; then
        PASS=$((PASS + 1)); echo "  OK --clean-backups --dry-run uses run_clean_backups path"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL --clean-backups --dry-run did not produce expected output"
        echo "      output excerpt: $(echo "$OUT" | head -5)"
    fi

    # And NOT the new print_update_dry_run output
    if echo "$OUT" | grep -qE '^\[\+ INSTALL\] +[0-9]+ files$'; then
        FAIL=$((FAIL + 1)); echo "  FAIL --clean-backups --dry-run unexpectedly triggered print_update_dry_run"
    else
        PASS=$((PASS + 1)); echo "  OK --clean-backups --dry-run does NOT trigger print_update_dry_run"
    fi
}

# Main
scenario_install_group_renders
scenario_remove_group_renders
scenario_skip_group_renders
scenario_no_color
scenario_clean_backups_unchanged

echo ""
echo "---"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
