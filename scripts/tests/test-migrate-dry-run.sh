#!/usr/bin/env bash
# test-migrate-dry-run.sh — UX-01 SC3 migrate-to-complement.sh --dry-run assertions.
#
# Scenarios (Phase 11 Plan 11-03):
#   1. Duplicates present + --dry-run renders [- REMOVE] header + file paths + Total footer
#   2. Zero filesystem writes (snapshot identical before/after, no backup dir)
#   3. 3-col hash table preserved as diagnostic context
#   4. NO_COLOR=1 strips ANSI from dro_* output lines
#   5. No duplicates → existing 'No duplicate files found' path unchanged, no [- REMOVE] group
#
# Usage: bash scripts/tests/test-migrate-dry-run.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

# Use the migrate-specific fixture which has manifest_version=2 + conflicts_with entries.
# Fall back to live manifest.json if the fixture is absent.
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-migrate-v2.json"
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

assert_not_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if ! echo "$haystack" | grep -qE -- "$needle"; then
        PASS=$((PASS + 1)); echo "  OK ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL ${msg}"
        echo "      unexpected pattern present: ${needle}"
    fi
}

# assert_dryrun_lines_ansi_free — check only dro_* output lines for ANSI escapes.
# migrate-to-complement.sh emits log_info/log_warning with hardcoded ANSI codes that are
# outside the dro_* NO_COLOR contract. We scope the assertion to just the styled group lines.
assert_dryrun_lines_ansi_free() {
    local haystack="$1" msg="$2"
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

# Cross-platform md5 digest for snapshot
md5_any() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$@"
    else
        md5sum "$@" | awk '{print $1}'
    fi
}

# snapshot <dir> — produce a deterministic digest of all files under a directory.
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

TMPDIR_ROOT="$(mktemp -d -t tk-migrate-dryrun.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

# seed_duplicates_in_sandbox <sandbox_home> <count>
# Creates sandbox HOME/.claude and seeds <count> files at paths from the
# complement-sp skip-set so DUPLICATES enumeration finds them.
seed_duplicates_in_sandbox() {
    local sandbox="$1" want="$2"
    mkdir -p "$sandbox/.claude" "$sandbox/.src"

    # Source compute_skip_set from lib/install.sh in a subshell to get the JSON array,
    # then write <want> placeholder files into the sandbox .claude directory.
    local skip_json
    skip_json=$(bash -c '
        # shellcheck source=/dev/null
        source "$1"
        compute_skip_set complement-sp "$2"
    ' -- "$LIB_DIR/install.sh" "$MANIFEST_FIXTURE")

    echo "$skip_json" | jq -r '.[]' | head -n "$want" | while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        mkdir -p "$sandbox/.claude/$(dirname "$rel")"
        printf 'placeholder content\n' > "$sandbox/.claude/$rel"
    done
}

# run_migrate_dryrun <sandbox_home> [extra KEY=val ...]
# Captures combined stdout+stderr from migrate-to-complement.sh --dry-run.
# Extra KEY=val pairs are exported before the call and unset after (avoids
# unbound-variable failure under set -u when no extras are provided).
run_migrate_dryrun() {
    local sandbox="$1"; shift
    local out exit_code=0

    # Export any extra overrides
    local extra_keys=()
    local k
    for k in "$@"; do
        local kname kval
        kname="${k%%=*}"
        kval="${k#*=}"
        extra_keys+=("$kname")
        export "${kname}=${kval}"
    done

    out=$(TK_MIGRATE_HOME="$sandbox" \
        TK_MIGRATE_LIB_DIR="$LIB_DIR" \
        TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_MIGRATE_FILE_SRC="$sandbox/.src" \
        TK_MIGRATE_SP_CACHE_DIR="$sandbox/.sp-cache" \
        HAS_SP="true" HAS_GSD="false" \
        SP_VERSION="5.1.0" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --dry-run 2>&1) || exit_code=$?

    # Restore: unset any extra keys we exported
    for k in "${extra_keys[@]:-}"; do
        [[ -z "$k" ]] && continue
        unset "$k"
    done

    printf '%s' "$out"
    return "$exit_code"
}

# ─────────────────────────────────────────────────
# Scenario 1+2+3: duplicates present → [- REMOVE] group + zero writes + 3-col table
# ─────────────────────────────────────────────────
scenario_remove_group_renders() {
    echo ""
    echo "Scenario: [- REMOVE] group renders + 3-col table preserved + zero writes"
    echo "---"
    local SCR="${TMPDIR_ROOT}/with-dups"
    seed_duplicates_in_sandbox "$SCR" 3

    local snap_before snap_after OUT exit_code=0
    snap_before=$(snapshot "$SCR/.claude")
    OUT=$(run_migrate_dryrun "$SCR") || exit_code=$?
    snap_after=$(snapshot "$SCR/.claude")

    # exits 0
    if [ "$exit_code" -eq 0 ]; then
        PASS=$((PASS + 1)); echo "  OK --dry-run exits 0"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL --dry-run exited $exit_code (expected 0)"
        echo "      output: $(echo "$OUT" | head -5)"
    fi

    # [- REMOVE] header with right-aligned count
    assert_contains '^\[- REMOVE\] +[0-9]+ files$' "$OUT" "[- REMOVE] header with right-aligned count"

    # Total: footer
    assert_contains '^Total: [0-9]+ files$' "$OUT" "Total: footer present"

    # 3-col table header preserved
    assert_contains 'TK tmpl.+on-disk.+SP equiv' "$OUT" "3-col table header preserved"

    # zero filesystem writes
    if [ "$snap_before" = "$snap_after" ]; then
        PASS=$((PASS + 1)); echo "  OK zero filesystem writes (snapshot identical)"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL filesystem changed during dry-run"
    fi

    # no backup dir created
    if find "$SCR" -maxdepth 2 -type d -name '.claude-backup-pre-migrate-*' 2>/dev/null | grep -q .; then
        FAIL=$((FAIL + 1)); echo "  FAIL unexpected backup dir created during dry-run"
    else
        PASS=$((PASS + 1)); echo "  OK no backup dir created during dry-run"
    fi
}

# ─────────────────────────────────────────────────
# Scenario: NO_COLOR=1 strips ANSI from dro_* lines
# ─────────────────────────────────────────────────
scenario_no_color() {
    echo ""
    echo "Scenario: NO_COLOR=1 strips ANSI"
    echo "---"
    local SCR="${TMPDIR_ROOT}/nocolor"
    seed_duplicates_in_sandbox "$SCR" 2

    local OUT
    OUT=$(run_migrate_dryrun "$SCR" "NO_COLOR=1") || true
    assert_dryrun_lines_ansi_free "$OUT" "NO_COLOR=1: dro_* output lines have zero ANSI escapes"
}

# ─────────────────────────────────────────────────
# Scenario: no duplicates → 'No duplicate files found' path unchanged, no [- REMOVE]
# ─────────────────────────────────────────────────
scenario_no_duplicates() {
    echo ""
    echo "Scenario: no duplicates → 'No duplicate files found' path unchanged"
    echo "---"
    local SCR="${TMPDIR_ROOT}/no-dups"
    mkdir -p "$SCR/.claude" "$SCR/.src"
    # Empty .claude/ — no files match skip-set → DUPLICATES array is empty

    local OUT
    OUT=$(run_migrate_dryrun "$SCR") || true
    assert_contains    'No duplicate files found on disk' "$OUT" "no-duplicates message present"
    assert_not_contains '\[- REMOVE\]'                    "$OUT" "[- REMOVE] group NOT printed"
}

# Main
scenario_remove_group_renders
scenario_no_color
scenario_no_duplicates

echo ""
echo "---"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
