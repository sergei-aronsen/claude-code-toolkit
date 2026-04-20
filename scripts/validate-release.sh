#!/usr/bin/env bash
# validate-release.sh — Phase 7 v4.0.0 release validation matrix runner (SKELETON).
# Runs 13 cells (4 modes × 3 scenarios + 1 translation-sync) in sandboxed $HOME.
# Asserts 4 invariants per cell (D-03). Fail-fast on first red cell (D-02).
#
# Plan 07-01 status: SKELETON ONLY. Helpers + run_cell wrapper exist.
# Cell bodies land in Plan 07-03.
#
# Usage:
#   bash scripts/validate-release.sh --self-test   # runs helper self-tests
#   bash scripts/validate-release.sh --cell <name> # Plan 07-03
#   bash scripts/validate-release.sh               # print usage
#
# Exit: 0 = all PASS, 1 = first FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
MANIFEST_FILE="${REPO_ROOT}/manifest.json"

# ─── Color constants (tty-auto-disable) ─────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    # shellcheck disable=SC2034
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    # shellcheck disable=SC2034
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# ─── Global PASS/FAIL counters ───────────────────────────────────────────────
PASS=0
FAIL=0

# ─── Core assertion helpers ──────────────────────────────────────────────────

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ ${msg}" >&2
        echo "    expected: ${expected}" >&2
        echo "    actual:   ${actual}" >&2
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1))
        echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ ${msg}" >&2
        echo "    expected substring: ${needle}" >&2
    fi
}

# ─── Library source guards ───────────────────────────────────────────────────

require_lib() {
    local lib_path="$1"
    if [ ! -f "$lib_path" ]; then
        echo "ERROR: required library not found: $lib_path" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
}

require_lib "${REPO_ROOT}/scripts/detect.sh"
require_lib "${LIB_DIR}/install.sh"
require_lib "${LIB_DIR}/state.sh"

# Run detection so HAS_SP / HAS_GSD are available for mode recommendations
detect_superpowers 2>/dev/null || true
detect_gsd 2>/dev/null || true

# ─── Sandbox helpers (D-04, D-06) ────────────────────────────────────────────
REPO_ROOT_ABS="$REPO_ROOT"
PRE_40_COMMIT="e9411201db9dde6a0676a5a5b09fb80d8893e507"
declare -a CELL_WORKTREES=()

sandbox_setup() {
    local cell_name="$1"
    local cell_home
    cell_home="/tmp/tk-matrix-${cell_name}-$(date +%s)"
    rm -rf "$cell_home"
    mkdir -p "$cell_home/.claude"
    echo "$cell_home"
}

stage_sp_cache() {
    local cell_home="$1" ver="${2:-5.0.7}"
    local cache_root="$cell_home/.claude/plugins/cache/claude-plugins-official/superpowers/$ver"
    mkdir -p "$cache_root/agents"
    cat > "$cache_root/agents/code-reviewer.md" <<'AGENT'
# SP code-reviewer agent (stub fixture for matrix cell)
AGENT
}

stage_gsd_cache() {
    local cell_home="$1"
    mkdir -p "$cell_home/.claude/get-shit-done/bin"
    cat > "$cell_home/.claude/get-shit-done/bin/gsd-tools.cjs" <<'GSD'
#!/usr/bin/env node
// Stub GSD fixture for matrix cell
GSD
    chmod +x "$cell_home/.claude/get-shit-done/bin/gsd-tools.cjs"
}

snapshot_foreign_settings() {
    local settings="$1"
    if [ -f "$settings" ]; then
        jq '{hooks: .hooks, enabledPlugins: .enabledPlugins, user_setting_unrelated: .user_setting_unrelated}' \
            "$settings" 2>/dev/null || echo '{}'
    else
        echo '{}'
    fi
}

seed_foreign_settings() {
    local cell_home="$1"
    local sj="$cell_home/.claude/settings.json"
    mkdir -p "$(dirname "$sj")"
    cat > "$sj" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "echo [SP] pretooluse"}]}
    ]
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true
  },
  "user_setting_unrelated": "preserved-by-user",
  "permissions": {"deny": []}
}
JSON
}

# CELL_WT_PATH is the out-parameter set by setup_v3x_worktree.
# Cannot use $() subshell capture — array mutation inside $() does not propagate.
CELL_WT_PATH=""

setup_v3x_worktree() {
    local wt
    wt="/tmp/tk-matrix-worktree-$$-$(date +%s)"
    rm -rf "$wt"
    git -C "$REPO_ROOT_ABS" worktree add --detach "$wt" "$PRE_40_COMMIT" >/dev/null 2>&1
    CELL_WORKTREES+=("$wt")
    CELL_WT_PATH="$wt"
}

cleanup_v3x_worktrees() {
    for wt in "${CELL_WORKTREES[@]:-}"; do
        [ -n "$wt" ] && git -C "$REPO_ROOT_ABS" worktree remove "$wt" >/dev/null 2>&1 || true
    done
    CELL_WORKTREES=()
}

trap cleanup_v3x_worktrees EXIT

# ─── Invariant 2: toolkit-install.json schema + content ─────────────────────
# assert_state_schema <state_file> <expected_mode>
assert_state_schema() {
    local state_file="$1" expected_mode="$2"
    if [ ! -f "$state_file" ]; then
        FAIL=$((FAIL + 1))
        echo "  ✗ state file missing: $state_file" >&2
        return
    fi
    if ! jq empty "$state_file" 2>/dev/null; then
        FAIL=$((FAIL + 1))
        echo "  ✗ state file invalid JSON: $state_file" >&2
        return
    fi
    assert_eq "$expected_mode" "$(jq -r '.mode' "$state_file")" "state.mode = $expected_mode"
    assert_eq "object" "$(jq -r '.detected | type' "$state_file")" "state.detected is object"
    local bad_entries
    bad_entries=$(jq '[.installed_files[] | select(.path == null or .sha256 == null or .installed_at == null)] | length' "$state_file")
    assert_eq "0" "$bad_entries" "all installed_files entries have path+sha256+installed_at"
    local bad_skips
    bad_skips=$(jq '[.skipped_files[] | select(.path == null or .reason == null)] | length' "$state_file")
    assert_eq "0" "$bad_skips" "all skipped_files entries have path+reason"
}

# ─── Invariant 3: settings.json foreign-key byte-identity (SP/GSD hooks preserved) ──
# assert_settings_foreign_intact <before_json> <after_json>
# Args are JSON strings (pre-extracted by caller via jq '{hooks, enabledPlugins, ...}').
# shellcheck disable=SC2329
assert_settings_foreign_intact() {
    local before="$1" after="$2"
    assert_eq "$before" "$after" "settings.json foreign keys byte-identical pre/post"
}

# ─── Invariant 4: no skipped file landed in CELL_HOME/.claude/ ──────────────
# assert_skiplist_clean <cell_home> <mode>
assert_skiplist_clean() {
    local cell_home="$1" mode="$2"
    local skip_set
    skip_set=$(compute_skip_set "$mode" "$MANIFEST_FILE")
    local landed=0
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if [ -f "${cell_home}/.claude/${p}" ]; then
            FAIL=$((FAIL + 1))
            echo "  ✗ skip-list violation: ${p} landed in mode ${mode}" >&2
            landed=1
        fi
    done < <(jq -r '.[]' <<<"$skip_set")
    if [ "$landed" = "0" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ no skip-list files landed in mode ${mode}"
    fi
}

# ─── VALIDATE-03 runtime layer (D-11): no TK agent basename matches SP agent ─
# assert_no_agent_collision <cell_home>
assert_no_agent_collision() {
    local cell_home="$1"
    local sp_agents="${cell_home}/.claude/plugins/cache/claude-plugins-official/superpowers"
    local tk_agents="${cell_home}/.claude/agents"
    if [ ! -d "$sp_agents" ] || [ ! -d "$tk_agents" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ agent-collision check skipped (no SP cache or TK agents dir in sandbox)"
        return
    fi
    local colliding=0
    while IFS= read -r sp_agent; do
        local base
        base="$(basename "$sp_agent")"
        if [ -f "${tk_agents}/${base}" ]; then
            FAIL=$((FAIL + 1))
            echo "  ✗ agent collision: ${base} present in both SP cache and TK agents/" >&2
            colliding=1
        fi
    done < <(find "$sp_agents" -name '*.md' -mindepth 3 -maxdepth 3 2>/dev/null)
    if [ "$colliding" = "0" ]; then
        PASS=$((PASS + 1))
        echo "  ✓ no TK↔SP agent basename collision"
    fi
}

# ─── Fail-fast cell runner (D-02) ────────────────────────────────────────────
# run_cell <cell_name> <body_function_name>
# Invokes body; exits 1 immediately if any assertion inside the body FAILed.
# shellcheck disable=SC2329
run_cell() {
    local cell_name="$1" body_fn="$2"
    local before_fail=$FAIL
    echo ""
    echo "${CYAN}━━ Cell: ${cell_name} ━━${NC}"
    "$body_fn"
    local new_fails
    new_fails=$((FAIL - before_fail))
    if [ "$new_fails" -gt 0 ]; then
        echo "${RED}FAIL: ${cell_name}: ${new_fails} assertion(s) failed${NC}" >&2
        exit 1
    fi
    echo "${GREEN}PASS: ${cell_name}${NC}"
}

# ─── Cell body functions (13 cells) ─────────────────────────────────────────

# Cell 1/13: standalone-fresh
cell_standalone_fresh() {
    local CH rc
    CH=$(sandbox_setup "standalone-fresh")
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode standalone >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "init-local.sh --mode standalone exits 0"
    assert_state_schema "$CH/.claude/toolkit-install.json" "standalone"
    assert_skiplist_clean "$CH" "standalone"
}

# Cell 2/13: standalone-upgrade
cell_standalone_upgrade() {
    local CH WT rc
    CH=$(sandbox_setup "standalone-upgrade")
    setup_v3x_worktree; WT="$CELL_WT_PATH"
    ( cd "$CH" && HOME="$CH" bash "$WT/scripts/init-local.sh" >/dev/null 2>&1 ) || true
    HOME="$CH" \
        TK_UPDATE_HOME="$CH" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$REPO_ROOT_ABS/manifest.json" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT_ABS" \
        HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
        bash "$REPO_ROOT_ABS/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 && rc=0 || rc=$?
    assert_eq "0" "$rc" "update-claude.sh after v3.x install exits 0"
    assert_state_schema "$CH/.claude/toolkit-install.json" "standalone"
    assert_skiplist_clean "$CH" "standalone"
}

# Cell 3/13: standalone-rerun
# Idempotency: install then re-run init-local.sh; state must survive intact.
# No-op semantics (backup count) are covered by Test 11 (test-update-summary.sh).
cell_standalone_rerun() {
    local CH rc
    CH=$(sandbox_setup "standalone-rerun")
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode standalone >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "first init-local.sh --mode standalone exits 0"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode standalone >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "re-run init-local.sh exits 0 (idempotent)"
    assert_state_schema "$CH/.claude/toolkit-install.json" "standalone"
    assert_skiplist_clean "$CH" "standalone"
}

# Cell 4/13: complement-sp-fresh
cell_complement_sp_fresh() {
    local CH rc
    CH=$(sandbox_setup "complement-sp-fresh")
    stage_sp_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "init-local.sh --mode complement-sp exits 0"
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-sp"
    assert_skiplist_clean "$CH" "complement-sp"
    assert_no_agent_collision "$CH"
}

# Cell 5/13: complement-sp-upgrade
# Note: v3.x install places code-reviewer.md on disk; update-claude.sh with SP detected
# does NOT remove it (user must run migrate-to-complement.sh). Agent-collision is expected
# pre-migration and is NOT asserted here (D-11 applies to fresh+rerun cells only).
cell_complement_sp_upgrade() {
    local CH WT rc
    CH=$(sandbox_setup "complement-sp-upgrade")
    setup_v3x_worktree; WT="$CELL_WT_PATH"
    stage_sp_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$WT/scripts/init-local.sh" >/dev/null 2>&1 ) || true
    HOME="$CH" \
        TK_UPDATE_HOME="$CH" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$REPO_ROOT_ABS/manifest.json" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT_ABS" \
        HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
        bash "$REPO_ROOT_ABS/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 && rc=0 || rc=$?
    assert_eq "0" "$rc" "update-claude.sh with SP detected exits 0"
    assert_eq "object" "$(jq -r '.detected | type' "$CH/.claude/toolkit-install.json")" "state.detected present"
}

# Cell 6/13: complement-sp-rerun
cell_complement_sp_rerun() {
    local CH
    CH=$(sandbox_setup "complement-sp-rerun")
    stage_sp_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) || true
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) || true
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-sp"
    assert_skiplist_clean "$CH" "complement-sp"
    assert_no_agent_collision "$CH"
}

# Cell 7/13: complement-gsd-fresh
cell_complement_gsd_fresh() {
    local CH rc
    CH=$(sandbox_setup "complement-gsd-fresh")
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-gsd >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "init-local.sh --mode complement-gsd exits 0"
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-gsd"
    assert_skiplist_clean "$CH" "complement-gsd"
}

# Cell 8/13: complement-gsd-upgrade
cell_complement_gsd_upgrade() {
    local CH WT rc
    CH=$(sandbox_setup "complement-gsd-upgrade")
    setup_v3x_worktree; WT="$CELL_WT_PATH"
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$WT/scripts/init-local.sh" >/dev/null 2>&1 ) || true
    HOME="$CH" \
        TK_UPDATE_HOME="$CH" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$REPO_ROOT_ABS/manifest.json" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT_ABS" \
        HAS_SP=false HAS_GSD=true SP_VERSION="" GSD_VERSION="1.0.0" \
        bash "$REPO_ROOT_ABS/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 && rc=0 || rc=$?
    assert_eq "0" "$rc" "update-claude.sh with GSD detected exits 0"
    assert_eq "object" "$(jq -r '.detected | type' "$CH/.claude/toolkit-install.json")" "state.detected present"
}

# Cell 9/13: complement-gsd-rerun
cell_complement_gsd_rerun() {
    local CH
    CH=$(sandbox_setup "complement-gsd-rerun")
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-gsd >/dev/null 2>&1 ) || true
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-gsd >/dev/null 2>&1 ) || true
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-gsd"
    assert_skiplist_clean "$CH" "complement-gsd"
}

# Cell 10/13: complement-full-fresh
cell_complement_full_fresh() {
    local CH rc
    CH=$(sandbox_setup "complement-full-fresh")
    stage_sp_cache "$CH"
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-full >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "init-local.sh --mode complement-full exits 0"
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-full"
    assert_skiplist_clean "$CH" "complement-full"
    assert_no_agent_collision "$CH"
}

# Cell 11/13: complement-full-upgrade
# Note: v3.x install places code-reviewer.md on disk; update-claude.sh with SP+GSD detected
# does NOT remove it (user must run migrate-to-complement.sh). Agent-collision is expected
# pre-migration and is NOT asserted here (D-11 applies to fresh+rerun cells only).
cell_complement_full_upgrade() {
    local CH WT rc
    CH=$(sandbox_setup "complement-full-upgrade")
    setup_v3x_worktree; WT="$CELL_WT_PATH"
    stage_sp_cache "$CH"
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$WT/scripts/init-local.sh" >/dev/null 2>&1 ) || true
    HOME="$CH" \
        TK_UPDATE_HOME="$CH" \
        TK_UPDATE_LIB_DIR="$LIB_DIR" \
        TK_UPDATE_MANIFEST_OVERRIDE="$REPO_ROOT_ABS/manifest.json" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT_ABS" \
        HAS_SP=true HAS_GSD=true SP_VERSION="5.0.7" GSD_VERSION="1.0.0" \
        bash "$REPO_ROOT_ABS/scripts/update-claude.sh" --no-banner --no-offer-mode-switch >/dev/null 2>&1 && rc=0 || rc=$?
    assert_eq "0" "$rc" "update-claude.sh with SP+GSD detected exits 0"
    assert_eq "object" "$(jq -r '.detected | type' "$CH/.claude/toolkit-install.json")" "state.detected present"
}

# Cell 12/13: complement-full-rerun
cell_complement_full_rerun() {
    local CH
    CH=$(sandbox_setup "complement-full-rerun")
    stage_sp_cache "$CH"
    stage_gsd_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-full >/dev/null 2>&1 ) || true
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-full >/dev/null 2>&1 ) || true
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-full"
    assert_skiplist_clean "$CH" "complement-full"
    assert_no_agent_collision "$CH"
}

# Cell 13/13: translation-sync
cell_translation_sync() {
    local drift_exit
    (
        cd "$REPO_ROOT_ABS"
        make translation-drift >/dev/null 2>&1
    ) && drift_exit=0 || drift_exit=$?
    assert_eq "0" "$drift_exit" "make translation-drift exits 0 (all translations within ±20% of README.md)"
}

# ─── Self-test: exercise helpers against synthetic fixtures ──────────────────
self_test() {
    local TMP
    TMP="$(mktemp -d -t tk-selftest.XXXXXX)"
    trap 'rm -rf "$TMP"' EXIT

    echo "${BLUE}Running validate-release.sh self-test...${NC}"
    echo ""

    # assert_eq: pass path
    assert_eq "a" "a" "assert_eq detects equality"

    # assert_eq: fail path (verify the FAIL counter increments, then reset)
    local baseline_fail=$FAIL
    assert_eq "a" "b" "assert_eq detects inequality (expected to FAIL)" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail" ]; then
        FAIL=$baseline_fail
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_eq FAIL-path works"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_eq FAIL-path did not trigger" >&2
    fi

    # assert_contains: pass path
    assert_contains "world" "hello world" "assert_contains finds substring"

    # assert_contains: fail path (verify the FAIL counter increments, then reset)
    local baseline_fail2=$FAIL
    assert_contains "missing" "hello world" "assert_contains reports missing (expected to FAIL)" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail2" ]; then
        FAIL=$baseline_fail2
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_contains FAIL-path works"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_contains FAIL-path did not trigger" >&2
    fi

    # assert_state_schema with a valid minimal state
    local STATE="$TMP/state.json"
    cat > "$STATE" <<'JSON'
{
  "version": 2,
  "mode": "standalone",
  "detected": {"superpowers": {"present": false}, "gsd": {"present": false}},
  "installed_files": [{"path": "a.md", "sha256": "abc", "installed_at": "2026-01-01"}],
  "skipped_files": [],
  "installed_at": "2026-01-01"
}
JSON
    assert_state_schema "$STATE" "standalone"

    # assert_state_schema: missing file path triggers FAIL
    local baseline_fail3=$FAIL
    assert_state_schema "$TMP/nonexistent.json" "standalone" 2>/dev/null
    if [ "$FAIL" -gt "$baseline_fail3" ]; then
        FAIL=$baseline_fail3
        PASS=$((PASS + 1))
        echo "  ✓ self-test: assert_state_schema rejects missing file"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ self-test: assert_state_schema did not reject missing file" >&2
    fi

    # compute_skip_set reachable
    local skip
    skip=$(compute_skip_set "complement-sp" "$MANIFEST_FILE")
    assert_eq "array" "$(jq -r 'type' <<<"$skip")" "compute_skip_set returns JSON array for complement-sp"

    # sha256_file reachable
    local HFILE="$TMP/hash-me"
    echo "hello" > "$HFILE"
    local H
    H=$(sha256_file "$HFILE")
    assert_eq "64" "${#H}" "sha256_file returns 64-char hex"

    # assert_skiplist_clean: create a sandbox with no skipped files (clean pass)
    local CLEAN_HOME="$TMP/clean_home"
    mkdir -p "${CLEAN_HOME}/.claude"
    assert_skiplist_clean "$CLEAN_HOME" "complement-sp"

    # assert_no_agent_collision: sandbox with no SP cache → skipped pass
    local NOCOL_HOME="$TMP/nocol_home"
    mkdir -p "${NOCOL_HOME}/.claude/agents"
    assert_no_agent_collision "$NOCOL_HOME"

    echo ""
    echo "Self-test results: ${PASS} passed, ${FAIL} failed"
    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# ─── CLI dispatcher ─────────────────────────────────────────────────────────
CELLS=(
    standalone-fresh standalone-upgrade standalone-rerun
    complement-sp-fresh complement-sp-upgrade complement-sp-rerun
    complement-gsd-fresh complement-gsd-upgrade complement-gsd-rerun
    complement-full-fresh complement-full-upgrade complement-full-rerun
    translation-sync
)

cell_fn_for() {
    echo "cell_$(echo "$1" | tr '-' '_')"
}

case "${1:-}" in
    --self-test)
        self_test
        ;;
    --list)
        for c in "${CELLS[@]}"; do echo "$c"; done
        exit 0
        ;;
    --cell)
        [ -z "${2:-}" ] && { echo "ERROR: --cell requires a name" >&2; exit 2; }
        cell="$2"
        match=0
        for c in "${CELLS[@]}"; do [ "$c" = "$cell" ] && match=1; done
        if [ "$match" = "0" ]; then
            echo "ERROR: unknown cell: $cell" >&2
            echo "Known cells:" >&2
            for c in "${CELLS[@]}"; do echo "  $c" >&2; done
            exit 2
        fi
        run_cell "$cell" "$(cell_fn_for "$cell")"
        echo ""
        echo "Results: ${PASS} passed, ${FAIL} failed"
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
    --all)
        for c in "${CELLS[@]}"; do
            run_cell "$c" "$(cell_fn_for "$c")"
        done
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Matrix complete: ${PASS} assertions passed, ${FAIL} failed across ${#CELLS[@]} cells"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
    "")
        cat <<USAGE
Usage: bash scripts/validate-release.sh <command>

Commands:
  --self-test      Exercise invariant helpers against synthetic fixtures.
  --list           Print all 13 cell names, one per line.
  --cell <name>    Run a single matrix cell.
  --all            Run all 13 cells fail-fast.

Phase 7 v4.0.0 release validation runner.
USAGE
        exit 0
        ;;
    *)
        echo "ERROR: unknown arg: $1" >&2
        exit 2
        ;;
esac
