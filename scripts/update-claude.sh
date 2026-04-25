#!/bin/bash

# Claude Code Toolkit — Smart Update Script
# Updates toolkit files while preserving user customizations in CLAUDE.md

set -euo pipefail

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-01 — flag parsing (before color constants)
# ─────────────────────────────────────────────────
NO_BANNER=0
OFFER_MODE_SWITCH="interactive"
PRUNE_MODE="interactive"
# Phase 9 Plan 09-01 — BACKUP-01 --clean-backups flag state
CLEAN_BACKUPS=0
KEEP_N=""
DRY_RUN_CLEAN=0
# Phase 11 Plan 11-02 — UX-01 full update preview flag (distinct from DRY_RUN_CLEAN
# which only governs --clean-backups). The --dry-run arg sets BOTH so existing
# `--clean-backups --dry-run` workflow continues unchanged (RESEARCH Pitfall 3).
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --no-banner) NO_BANNER=1 ;;
        --offer-mode-switch=yes)                       OFFER_MODE_SWITCH="yes" ;;
        --offer-mode-switch=no|--no-offer-mode-switch) OFFER_MODE_SWITCH="no" ;;
        --offer-mode-switch=interactive)               OFFER_MODE_SWITCH="interactive" ;;
        --prune=yes)                                   PRUNE_MODE="yes" ;;
        --prune=no|--no-prune)                         PRUNE_MODE="no" ;;
        --prune=interactive)                           PRUNE_MODE="interactive" ;;
        --clean-backups)  CLEAN_BACKUPS=1 ;;
        --keep=*)         KEEP_N="${arg#--keep=}" ;;
        --dry-run)        DRY_RUN=1; DRY_RUN_CLEAN=1 ;;
        *) ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR=".claude"
# shellcheck disable=SC2034  # MANIFEST_URL kept as legacy reference; Plan 04-02 removes it
MANIFEST_URL="$REPO_URL/manifest.json"

# ─────────────────────────────────────────────────
# Phase 4 (Plan 04-01) — extend DETECT-05 wiring with lib/install.sh + lib/state.sh + remote manifest
# (replaces the Phase 3 soft-fail-only block)
# ─────────────────────────────────────────────────
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install.XXXXXX")
LIB_STATE_TMP=$(mktemp "${TMPDIR:-/tmp}/state.XXXXXX")
LIB_OPTIONAL_PLUGINS_TMP=$(mktemp "${TMPDIR:-/tmp}/optional-plugins.XXXXXX")
LIB_BACKUP_TMP=$(mktemp "${TMPDIR:-/tmp}/backup.XXXXXX")
LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output.XXXXXX")
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$LIB_OPTIONAL_PLUGINS_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$MANIFEST_TMP"' EXIT

# detect.sh — still soft-fail (transient network tolerance); fallback sets HAS_SP/HAS_GSD=false
# Honor pre-set env vars (test seam: tests export HAS_SP/HAS_GSD to bypass detect.sh).
if [[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]; then
    : # env vars already set by caller (test seam or CI override) — skip detect.sh
elif curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
else
    echo -e "${YELLOW}⚠${NC} Could not fetch detect.sh — plugin detection unavailable"
    # shellcheck disable=SC2034  # consumed by recommend_mode in lib/install.sh
    HAS_SP=false
    # shellcheck disable=SC2034
    HAS_GSD=false
    # shellcheck disable=SC2034
    SP_VERSION=""
    # shellcheck disable=SC2034
    GSD_VERSION=""
fi

# lib/install.sh + lib/state.sh — HARD-fail (Phase 4 update flow cannot proceed without them)
# TK_UPDATE_LIB_DIR: test seam — when set, sources libs from local path instead of remote curl
for lib_pair in "install.sh:$LIB_INSTALL_TMP" "state.sh:$LIB_STATE_TMP" "optional-plugins.sh:$LIB_OPTIONAL_PLUGINS_TMP" "backup.sh:$LIB_BACKUP_TMP" "dry-run-output.sh:$LIB_DRO_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_UPDATE_LIB_DIR:-}" && -f "$TK_UPDATE_LIB_DIR/$lib_name" ]]; then
        cp "$TK_UPDATE_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
        echo -e "${RED}✗${NC} Failed to fetch scripts/lib/$lib_name — update cannot proceed"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
done

# Remote manifest — HARD-fail; TK_UPDATE_MANIFEST_OVERRIDE bypasses network for tests
MANIFEST_SRC="${TK_UPDATE_MANIFEST_OVERRIDE:-}"
if [[ -n "$MANIFEST_SRC" && -f "$MANIFEST_SRC" ]]; then
    cp "$MANIFEST_SRC" "$MANIFEST_TMP"
else
    if ! curl -sSLf "$REPO_URL/manifest.json" -o "$MANIFEST_TMP"; then
        echo -e "${RED}✗${NC} Failed to fetch manifest.json — update cannot proceed"
        exit 1
    fi
fi
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP" 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    echo -e "${RED}✗${NC} manifest.json has manifest_version=${MANIFEST_VER:-unknown}; update-claude.sh expects v2"
    exit 1
fi
REMOTE_TOOLKIT_VERSION=$(jq -r '.version' "$MANIFEST_TMP")
# shellcheck disable=SC2034  # REMOTE_TOOLKIT_VERSION consumed by Plan 04-03 no-op check
: "$REMOTE_TOOLKIT_VERSION"

# B2: manifest content-hash for no-op check (NOT the toolkit version string)
# shellcheck disable=SC2034  # MANIFEST_HASH consumed by Plan 04-03 no-op check and final write_state
MANIFEST_HASH=$(sha256_file "$MANIFEST_TMP")

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-01 — CLAUDE_DIR / STATE_FILE override for test seams (TK_UPDATE_HOME)
# ─────────────────────────────────────────────────
if [[ -n "${TK_UPDATE_HOME:-}" ]]; then
    CLAUDE_DIR="$TK_UPDATE_HOME/.claude"
fi
# shellcheck disable=SC2034  # STATE_FILE consumed by read_state/write_state in lib/state.sh
STATE_FILE="$CLAUDE_DIR/toolkit-install.json"
# shellcheck disable=SC2034  # LOCK_DIR consumed by acquire_lock in lib/state.sh (Plan 04-03 wires the lock)
LOCK_DIR="$CLAUDE_DIR/.toolkit-install.lock"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# _fmt_age — internal helper; prints e.g. "14d 3h", "5h 12m", "47m", "<1m"
_fmt_age() {
    local secs="$1"
    local days=$(( secs / 86400 ))
    local hours=$(( (secs % 86400) / 3600 ))
    local mins=$(( (secs % 3600) / 60 ))
    if   [[ $days  -gt 0 ]]; then echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then echo "${hours}h ${mins}m"
    elif [[ $mins  -gt 0 ]]; then echo "${mins}m"
    else echo "<1m"
    fi
}

# run_clean_backups — BACKUP-01 dispatch.
# Args: $1 = KEEP_N value (may be empty); $2 = DRY_RUN_CLEAN (0 or 1)
# Exit: 0 clean / 1 partial rm failure / 2 bad --keep value
run_clean_backups() {
    local keep_n="$1" dry_run="$2"
    local rc=0

    # Validate --keep value (D-06 exit 2)
    if [[ -n "$keep_n" ]]; then
        if ! [[ "$keep_n" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✗${NC} --keep value must be a non-negative integer (got: $keep_n)" >&2
            return 2
        fi
    fi

    # Enumerate backup dirs (newest-epoch-first from list_backup_dirs)
    local dirs=()
    while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        dirs+=("$d")
    done < <(list_backup_dirs "${TK_UPDATE_HOME:-$HOME}")

    # Empty-set (D-07)
    if [[ ${#dirs[@]} -eq 0 ]]; then
        echo "No toolkit backup directories found under \$HOME."
        return 0
    fi

    # Classify dirs into keep set (first N) vs prompt set (remainder)
    local keep_count=0
    [[ -n "$keep_n" ]] && keep_count="$keep_n"

    local now_epoch idx=0
    now_epoch=$(date -u +%s)
    for d in "${dirs[@]}"; do
        local name epoch age_secs size age_str
        name="$(basename "$d")"
        case "$name" in
            .claude-backup-[0-9]*-[0-9]*)
                epoch="${name#.claude-backup-}"; epoch="${epoch%-*}" ;;
            .claude-backup-pre-migrate-[0-9]*)
                epoch="${name#.claude-backup-pre-migrate-}" ;;
            *) idx=$((idx + 1)); continue ;;
        esac
        age_secs=$(( now_epoch - epoch ))
        size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "?")
        age_str=$(_fmt_age "$age_secs")

        if [[ $idx -lt $keep_count ]]; then
            # Keep (newest N)
            if [[ $dry_run -eq 1 ]]; then
                echo "[would keep]   $d  (size: $size, age: $age_str)"
            else
                echo "Keeping: $d  (size: $size, age: $age_str)"
            fi
        else
            if [[ $dry_run -eq 1 ]]; then
                echo "[would remove] $d  (size: $size, age: $age_str)"
            else
                local decision=""
                printf 'Remove %s (size: %s, age: %s)? [y/N]: ' "$d" "$size" "$age_str"
                if ! read -r decision < /dev/tty 2>/dev/null; then
                    # /dev/tty unavailable (curl|bash or test FIFO) — try stdin
                    if ! read -r decision 2>/dev/null; then
                        decision="N"   # fail-closed: EOF or no input
                    fi
                fi
                case "${decision:-N}" in
                    y|Y)
                        if ! rm -rf "$d"; then
                            echo -e "${RED}✗${NC} Failed to remove $d" >&2
                            rc=1
                        fi
                        ;;
                    *) : ;;
                esac
            fi
        fi
        idx=$((idx + 1))
    done

    return $rc
}

detect_framework() {
    if [[ -f "artisan" ]]; then
        echo "laravel"
    elif [[ -f "bin/rails" ]] || [[ -f "config/application.rb" ]]; then
        echo "rails"
    elif [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "next.config.ts" ]]; then
        echo "nextjs"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
        echo "python"
    elif [[ -f "package.json" ]]; then
        echo "nodejs"
    else
        echo "base"
    fi
}

# synthesize_v3_state <manifest_path>
# D-50: scan $CLAUDE_DIR for manifest-declared files, build installed_csv of absolute paths,
# call lib/state.sh::write_state. Prints ONE info line explaining the synthesis.
synthesize_v3_state() {
    local manifest_file="$1"
    local mode installed_csv=""
    mode=$(recommend_mode)
    while IFS= read -r path; do
        if [[ -f "$CLAUDE_DIR/$path" ]]; then
            if [[ -n "$installed_csv" ]]; then installed_csv+=","; fi
            installed_csv+="$CLAUDE_DIR/$path"
        fi
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$manifest_file")
    log_info "First update after v3.x — synthesized install state from filesystem (mode=$mode)."
    write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" "" "true"
}

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-03 — helper functions
# ─────────────────────────────────────────────────

# compute_modified_actual
# D-59 pre-dispatch: iterate MODIFIED_CANDIDATES; collect only paths where on-disk
# sha256 differs from stored sha256. Pure read-only — no prompts, no side effects.
# Consumes: $MODIFIED_CANDIDATES (JSON array), $STATE_JSON, $CLAUDE_DIR
# Emits (stdout): JSON array of relative paths with real hash divergence.
compute_modified_actual() {
    local out="[]"
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        local stored actual local_path
        local_path="$CLAUDE_DIR/$rel"
        stored=$(jq -r --arg p "$rel" \
            '.installed_files[] | select(.path == $p) | .sha256 // ""' \
            <<<"$STATE_JSON")
        # Pitfall 11: empty stored hash — unknown install-time state; skip
        [[ -z "$stored" ]] && continue
        [[ ! -f "$local_path" ]] && continue
        actual=$(sha256_file "$local_path" 2>/dev/null || echo "")
        [[ -z "$actual" ]] && continue
        if [[ "$actual" != "$stored" ]]; then
            out=$(jq --arg p "$rel" '. + [$p]' <<<"$out")
        fi
    done < <(jq -r '.[]' <<<"$MODIFIED_CANDIDATES")
    printf '%s' "$out"
}

# is_update_noop
# D-59: returns 0 (no-op) if all 5 conditions hold; 1 otherwise.
# B2: compares manifest content hash, NOT toolkit version string.
is_update_noop() {
    [[ "$STATE_MODE" == "$RECOMMENDED" ]] || return 1
    [[ "$(jq length <<<"$NEW_FILES")" -eq 0 ]] || return 1
    [[ "$(jq length <<<"$REMOVED_FROM_MANIFEST")" -eq 0 ]] || return 1
    [[ "$(jq length <<<"$MODIFIED_ACTUAL")" -eq 0 ]] || return 1
    [[ "$(jq length <<<"$ADD_FROM_SWITCH_JSON")" -eq 0 ]] || return 1
    [[ "$(jq length <<<"$REMOVED_BY_SWITCH_JSON")" -eq 0 ]] || return 1
    # B2: STATE_VERSION is schema version (1); REMOTE_TOOLKIT_VERSION is "3.0.0" — they NEVER match.
    # Compare manifest content hash instead.
    [[ "$STATE_MANIFEST_HASH" == "$MANIFEST_HASH" ]] || return 1
    return 0
}

# print_update_summary <backup_dir>
# D-58: print four-group post-run summary (INSTALLED / UPDATED / SKIPPED / REMOVED).
# Colors auto-disabled when stdout is not a tty (matches Phase 3 D-36 / Plan 03-02 ANSI pattern).
print_update_summary() {
    local backup_dir="$1"
    local _G _C _Y _R _NC
    if [ -t 1 ]; then
        _G='\033[0;32m'; _C='\033[0;36m'; _Y='\033[1;33m'; _R='\033[0;31m'; _NC='\033[0m'
    else
        _G=''; _C=''; _Y=''; _R=''; _NC=''
    fi
    local n_ins n_upd n_skp n_rem
    n_ins=${#INSTALLED_PATHS[@]}
    n_upd=${#UPDATED_PATHS[@]}
    n_skp=${#SKIPPED_PATHS[@]}
    n_rem=${#REMOVED_PATHS[@]}

    echo ""
    echo "Update Summary"
    echo "──────────────"
    printf '%bINSTALLED %d%b\n' "$_G" "$n_ins" "$_NC"
    for p in "${INSTALLED_PATHS[@]:-}"; do
        [[ -z "$p" ]] && continue
        printf '  %s (new in manifest)\n' "$p"
    done
    printf '%bUPDATED %d%b\n' "$_C" "$n_upd" "$_NC"
    for p in "${UPDATED_PATHS[@]:-}"; do
        [[ -z "$p" ]] && continue
        printf '  %s (remote hash changed)\n' "$p"
    done
    printf '%bSKIPPED %d%b\n' "$_Y" "$n_skp" "$_NC"
    for entry in "${SKIPPED_PATHS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        # entry format: "path:reason" — render as "  path (reason)"
        local rp rr
        rp="${entry%%:*}"
        rr="${entry#*:}"
        printf '  %s (%s)\n' "$rp" "$rr"
    done
    printf '%bREMOVED %d%b (backed up to %s)\n' "$_R" "$n_rem" "$_NC" "$backup_dir"
    for p in "${REMOVED_PATHS[@]:-}"; do
        [[ -z "$p" ]] && continue
        printf '  %s\n' "$p"
    done
}

# print_update_dry_run — UX-01 SC2 chezmoi-grade preview of update actions.
# Reads from outer-scope arrays/JSON populated by the read-only diff phase:
#   NEW_FILES (jq array, +)                — paths to install
#   MODIFIED_ACTUAL (jq array, ~)          — paths to update (hash differs from state)
#   SKIPPED_BY_MODE_JSON (jq array, -)     — paths skipped by mode skip-set
#   REMOVED_FROM_MANIFEST (jq array, -)    — paths removed from manifest
# Color via dro_* helpers (TTY + NO_COLOR gated).
# Zero filesystem writes. No prompts. Returns 0.
print_update_dry_run() {
    if ! command -v dro_init_colors >/dev/null 2>&1; then
        echo "ERROR: dry-run-output.sh not sourced — print_update_dry_run cannot render" >&2
        return 1
    fi
    dro_init_colors

    local install_count update_count skip_count remove_count total
    install_count=$(jq length <<<"$NEW_FILES")
    update_count=$(jq length <<<"$MODIFIED_ACTUAL")
    skip_count=$(jq length <<<"$SKIPPED_BY_MODE_JSON")
    remove_count=$(jq length <<<"$REMOVED_FROM_MANIFEST")
    total=$((install_count + update_count + skip_count + remove_count))

    if [ "$install_count" -gt 0 ]; then
        dro_print_header "+" "INSTALL" "$install_count" _DRO_G
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            dro_print_file "$p"
        done < <(jq -r '.[]' <<<"$NEW_FILES")
        echo ""
    fi

    if [ "$update_count" -gt 0 ]; then
        dro_print_header "~" "UPDATE" "$update_count" _DRO_C
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            dro_print_file "$p"
        done < <(jq -r '.[]' <<<"$MODIFIED_ACTUAL")
        echo ""
    fi

    if [ "$skip_count" -gt 0 ]; then
        dro_print_header "-" "SKIP" "$skip_count" _DRO_Y
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            local reason
            reason=$(jq -r --arg p "$p" '
                .files | to_entries[] | .value[] | select(.path == $p) |
                (.conflicts_with // [] | join(","))
            ' "$MANIFEST_TMP")
            dro_print_file "${p}  (conflicts_with:${reason:-unknown})"
        done < <(jq -r '.[]' <<<"$SKIPPED_BY_MODE_JSON")
        echo ""
    fi

    if [ "$remove_count" -gt 0 ]; then
        dro_print_header "-" "REMOVE" "$remove_count" _DRO_R
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            dro_print_file "$p"
        done < <(jq -r '.[]' <<<"$REMOVED_FROM_MANIFEST")
        echo ""
    fi

    dro_print_total "$total"
}

# ============================================================================
# MAIN
# ============================================================================

if [[ $NO_BANNER -eq 0 ]]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Claude Code Toolkit — Smart Update                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

# Check if .claude exists
if [[ ! -d "$CLAUDE_DIR" ]]; then
    log_error "$CLAUDE_DIR not found. Run init-claude.sh first:"
    echo "  bash <(curl -sSL $REPO_URL/scripts/init-claude.sh)"
    exit 1
fi

# Phase 9 Plan 09-01 — BACKUP-01 --clean-backups dispatch.
# Runs BEFORE lock acquisition + tree backup so cleanup never mutates .claude/.
if [[ $CLEAN_BACKUPS -eq 1 ]]; then
    run_clean_backups "${KEEP_N:-}" "$DRY_RUN_CLEAN"
    exit $?
fi

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-01 — D-50 state load / v3.x synthesis
# ─────────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
    synthesize_v3_state "$MANIFEST_TMP"
fi
if ! STATE_JSON=$(read_state); then
    log_error "toolkit-install.json unreadable at $STATE_FILE — re-synthesizing"
    # Preserve corrupt file for debug (RESEARCH Pitfall 10)
    if [[ -f "$STATE_FILE" ]]; then
        cp "$STATE_FILE" "${STATE_FILE}.corrupt.$(date -u +%s)"
    fi
    synthesize_v3_state "$MANIFEST_TMP"
    STATE_JSON=$(read_state) || { log_error "synthesis failed — abort"; exit 1; }
fi
STATE_MODE=$(jq -r '.mode' <<<"$STATE_JSON")
# shellcheck disable=SC2034  # STATE_VERSION is schema version (1); kept for diagnostics
STATE_VERSION=$(jq -r '.version // "unknown"' <<<"$STATE_JSON")
# B2: manifest content hash from prior run — absent on freshly-synthesized v3.x state
# shellcheck disable=SC2034  # STATE_MANIFEST_HASH consumed by Plan 04-03 is_update_noop condition
STATE_MANIFEST_HASH=$(jq -r '.manifest_hash // "unknown"' <<<"$STATE_JSON")
# Phase 9 Plan 09-04 — DETECT-07 version-skew warning (non-fatal, D-24).
# Emitted AFTER read_state + STATE_MANIFEST_HASH extraction, BEFORE migrate hint / summary.
warn_version_skew

# ─────────────────────────────────────────────────
# Phase 5 Plan 05-01 — D-77 migrate hint (standalone + SP/GSD present + duplicate on disk)
# Read-only probe. No state mutation, no exit. Normal update flow continues below.
# ─────────────────────────────────────────────────
if [[ "$STATE_MODE" == "standalone" && \
      ( "$HAS_SP" == "true" || "$HAS_GSD" == "true" ) ]]; then
    _HINT_HIT=false
    _HINT_SKIP_JSON=$(compute_skip_set "$(recommend_mode)" "$MANIFEST_TMP")
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        if [[ -f "$CLAUDE_DIR/$_rel" ]]; then _HINT_HIT=true; break; fi
    done < <(jq -r '.[]' <<<"$_HINT_SKIP_JSON")
    if [[ "$_HINT_HIT" == "true" ]]; then
        echo -e "${CYAN}ℹ${NC} Legacy duplicates detected (SP/GSD installed, mode=standalone). Run: ./scripts/migrate-to-complement.sh"
    fi
    unset _HINT_HIT _HINT_SKIP_JSON _rel
fi

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-01 — D-51 drift detect + D-52 in-place mode switch
# ─────────────────────────────────────────────────
RECOMMENDED=$(recommend_mode)
ADD_FROM_SWITCH_JSON='[]'
REMOVED_BY_SWITCH_JSON='[]'

execute_mode_switch() {
    local new_mode="$1"
    local installed_abs installed_rel all_paths new_skip files_to_remove_abs files_to_add
    # installed_abs: absolute paths from state (as written by write_state)
    installed_abs=$(jq -c '[.installed_files[].path]' <<<"$STATE_JSON")
    # installed_rel: relative suffix of each installed path for skip-set comparison
    # (skip set contains relative paths like "commands/plan.md")
    installed_rel=$(jq -c --arg base "$CLAUDE_DIR/" \
                        '[.installed_files[].path | ltrimstr($base)]' <<<"$STATE_JSON")
    all_paths=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
    if ! new_skip=$(compute_skip_set "$new_mode" "$MANIFEST_TMP"); then
        log_error "compute_skip_set failed for mode=$new_mode — aborting switch"
        return 1
    fi

    # files_to_remove_abs: absolute paths of installed files whose relative path is in skip set
    files_to_remove_abs=$(jq -nc \
                               --argjson iabs "$installed_abs" \
                               --argjson irel "$installed_rel" \
                               --argjson s    "$new_skip" \
                               '[ range($irel | length) |
                                  . as $idx |
                                  $irel[$idx] as $r |
                                  $iabs[$idx] as $a |
                                  select($s | index($r) != null) |
                                  $a ]')
    files_to_add=$(jq -nc --argjson a "$all_paths" --argjson s "$new_skip" --argjson i "$installed_rel" \
                          '(($a - $s) - $i)')

    # Delete the now-conflicting files (use absolute path directly)
    while IFS= read -r abs_path; do
        [[ -z "$abs_path" ]] && continue
        if [[ -f "$abs_path" ]]; then
            rm -f "$abs_path"
            log_info "mode-switch removed: ${abs_path#"$CLAUDE_DIR/"}"
        fi
    done < <(jq -r '.[]' <<<"$files_to_remove_abs")

    # shellcheck disable=SC2034  # ADD_FROM_SWITCH_JSON consumed by Plan 04-02 download loop
    ADD_FROM_SWITCH_JSON="$files_to_add"
    # Normalize to relative paths (strip CLAUDE_DIR/ prefix) so REMOVED_PATHS guard at
    # FINAL_INSTALLED_CSV builder uses consistent relative-path comparison (WR-02).
    # shellcheck disable=SC2034  # REMOVED_BY_SWITCH_JSON consumed by Plan 04-03 summary
    REMOVED_BY_SWITCH_JSON=$(jq -c --arg base "$CLAUDE_DIR/" '[.[] | ltrimstr($base)]' <<<"$files_to_remove_abs")
    STATE_MODE="$new_mode"

    # Update in-memory STATE_JSON: update mode and remove switched-out files
    STATE_JSON=$(jq --arg m "$new_mode" --argjson rm "$files_to_remove_abs" \
                    '.mode = $m |
                     .installed_files = [.installed_files[] |
                                         select(.path as $p | ($rm | index($p)) == null)]' \
                    <<<"$STATE_JSON")
    log_info "mode-switch: recorded mode is now $STATE_MODE (removed $(jq length <<<"$files_to_remove_abs") file(s), $(jq length <<<"$files_to_add") file(s) staged for install)"
}

if [[ "$STATE_MODE" != "$RECOMMENDED" ]]; then
    printf 'Current:     %s\n'                           "$STATE_MODE"
    printf 'Recommended: %s (based on detected SP+GSD)\n' "$RECOMMENDED"
    local_switch_decision="N"
    case "$OFFER_MODE_SWITCH" in
        yes) local_switch_decision="y" ;;
        no)  local_switch_decision="N" ;;
        interactive)
            if ! read -r -p "Switch to $RECOMMENDED? [y/N]: " local_switch_decision < /dev/tty 2>/dev/null; then
                local_switch_decision="N"  # fail-closed under curl|bash
            fi
            ;;
    esac
    case "${local_switch_decision:-N}" in
        y|Y) execute_mode_switch "$RECOMMENDED" ;;
        *)   log_info "Keeping current mode $STATE_MODE — duplicates may be installed/removed accordingly" ;;
    esac
fi

# Detect framework
FRAMEWORK=$(detect_framework)
log_info "Detected framework: ${CYAN}$FRAMEWORK${NC}"
TEMPLATE_URL="$REPO_URL/templates/$FRAMEWORK"

log_info "Remote version: ${CYAN}$REMOTE_TOOLKIT_VERSION${NC}"

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-02 — UPDATE-02/03/04 manifest-driven diff + dispatch
# TK_UPDATE_FILE_SRC: test seam — when set, reads file content from local dir instead of curl.
#                     NEVER set in production; CI/test use only.
# ─────────────────────────────────────────────────

# Normalize installed_files paths to relative (strip CLAUDE_DIR/ prefix).
# write_state stores absolute paths when called with absolute installed_csv;
# compute_file_diffs_obj compares against manifest's relative paths — both must match.
# execute_mode_switch (above) already completed and needed the absolute paths, so we
# normalize here, after the drift/mode-switch block.
STATE_JSON=$(jq --arg base "$CLAUDE_DIR/" \
    '.installed_files = [.installed_files[] |
         .path = (.path | ltrimstr($base))]' \
    <<<"$STATE_JSON")

# Accumulator arrays (consumed by Plan 04-03 summary printer)
# shellcheck disable=SC2034  # consumed by Plan 04-03 summary printer
INSTALLED_PATHS=()
# shellcheck disable=SC2034  # consumed by Plan 04-03 summary printer
UPDATED_PATHS=()
# shellcheck disable=SC2034  # consumed by Plan 04-03 summary printer
SKIPPED_PATHS=()    # entries are "path:reason" strings
# shellcheck disable=SC2034  # consumed by Plan 04-03 summary printer
REMOVED_PATHS=()

DIFFS_JSON=$(compute_file_diffs_obj "$STATE_JSON" "$MANIFEST_TMP" "$STATE_MODE")

# Merge switch-staged additions into NEW_FILES (deduped)
NEW_FILES=$(jq -nc --argjson a "$(jq -c '.new' <<<"$DIFFS_JSON")" \
                     --argjson b "$ADD_FROM_SWITCH_JSON" \
                     '[($a + $b) | unique | .[]]')
REMOVED_FROM_MANIFEST=$(jq -c '.removed' <<<"$DIFFS_JSON")
MODIFIED_CANDIDATES=$(jq -c '.modified_candidates' <<<"$DIFFS_JSON")

# Reset switch accumulators: ADD_FROM_SWITCH_JSON is now fully represented in NEW_FILES;
# REMOVED_BY_SWITCH_JSON removals are reflected in STATE_JSON after execute_mode_switch.
# Resetting prevents is_update_noop conditions 5/6 from double-counting (WR-04).
ADD_FROM_SWITCH_JSON='[]'
REMOVED_BY_SWITCH_JSON='[]'

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-03 — D-59 no-op early-exit
# Pre-dispatch read-only hash check to determine if anything actually changed.
# ─────────────────────────────────────────────────
MODIFIED_ACTUAL=$(compute_modified_actual)

# ── Skip-set pre-computation (moved here from install loop for dry-run access) ──
# Phase 11 Plan 11-02 — UX-01: must be available before dry-run exit below.
# Formula: (manifest - installed) ∩ skip_set  i.e. would-be-new files filtered out by mode.
# Previously-installed files in skip_set are handled by the removed-files path, not here.
SKIP_SET_JSON=$(compute_skip_set "$STATE_MODE" "$MANIFEST_TMP")
MANIFEST_FILES_JSON=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
INSTALLED_PATHS_JSON=$(jq -c '[.installed_files[].path]' <<<"$STATE_JSON")
SKIPPED_BY_MODE_JSON=$(jq -nc \
    --argjson manifest "$MANIFEST_FILES_JSON" \
    --argjson installed "$INSTALLED_PATHS_JSON" \
    --argjson skipset "$SKIP_SET_JSON" \
    '($manifest - $installed) - (($manifest - $installed) - $skipset)')

if is_update_noop; then
    echo "Already up-to-date. Nothing to do."
    exit 0
fi

# ─────────────────────────────────────────────────
# Phase 11 Plan 11-02 — UX-01 SC2 full update --dry-run preview.
# Decision A3 (locked): when --dry-run is passed without --clean-backups, run all
# read-only steps (already complete by here) then print 4-group preview and exit 0
# BEFORE acquire_lock, BEFORE BACKUP_DIR creation, BEFORE any file write.
# When --clean-backups is also passed, the earlier dispatch at line ~378 exits before
# control reaches here, so this block is skipped (CLEAN_BACKUPS path unchanged).
# ─────────────────────────────────────────────────
if [[ $DRY_RUN -eq 1 && $CLEAN_BACKUPS -eq 0 ]]; then
    print_update_dry_run
    exit 0
fi

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-03 — mutation lock + D-57 tree backup
# Lock registered before backup; EXIT trap consolidates cleanup.
# ─────────────────────────────────────────────────
trap 'release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$MANIFEST_TMP"' EXIT
acquire_lock || exit 1

BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"
cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
log_success "Backup created: $BACKUP_DIR"
warn_if_too_many_backups

echo ""
log_info "Updating toolkit files..."

# ── New files (D-54) — auto-install silently ──
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    dest="$CLAUDE_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    install_status=1
    # TK_UPDATE_FILE_SRC: test seam for hermetic file-src injection (never set in production).
    # When set, ONLY copy from the seam dir; never fall through to curl (hermetic boundary).
    if [[ -n "${TK_UPDATE_FILE_SRC:-}" ]]; then
        if [[ -f "$TK_UPDATE_FILE_SRC/$rel" ]]; then
            cp "$TK_UPDATE_FILE_SRC/$rel" "$dest"
            install_status=$?
        else
            install_status=1  # missing from seam dir = treat as download failure
        fi
    else
        if curl -sSLf "$REPO_URL/$rel" -o "$dest" 2>/dev/null; then
            install_status=0
        else
            install_status=1
        fi
    fi
    if [[ $install_status -eq 0 ]]; then
        INSTALLED_PATHS+=("$rel")
        log_success "Installed: $rel"
    else
        log_warning "Download failed: $rel"
        SKIPPED_PATHS+=("$rel:download_failed")
    fi
done < <(jq -r '.[]' <<<"$NEW_FILES")

# ── Skip-set tracking (W2 fix: only paths that WOULD be new but are filtered by mode) ──
# SKIPPED_BY_MODE_JSON already computed before the dry-run exit (Phase 11 Plan 11-02 move).
# This loop populates SKIPPED_PATHS for the post-run summary printer.
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    reason=$(jq -r --arg p "$rel" '
        .files | to_entries[] | .value[] | select(.path == $p) |
        (.conflicts_with // [] | join(","))
    ' "$MANIFEST_TMP")
    SKIPPED_PATHS+=("$rel:conflicts_with:${reason:-unknown}")
done < <(jq -r '.[]' <<<"$SKIPPED_BY_MODE_JSON")

# ── Removed files (D-55) — batch prompt ──
REMOVED_COUNT=$(jq length <<<"$REMOVED_FROM_MANIFEST")
if [[ "$REMOVED_COUNT" -gt 0 ]]; then
    echo "The following files were removed from manifest.json since last install:"
    jq -r '.[]' <<<"$REMOVED_FROM_MANIFEST" | sed 's/^/  /'
    local_prune_decision="N"
    case "$PRUNE_MODE" in
        yes) local_prune_decision="y" ;;
        no)  local_prune_decision="N" ;;
        interactive)
            if ! read -r -p "Delete $REMOVED_COUNT files removed from manifest? [y/N]: " local_prune_decision < /dev/tty 2>/dev/null; then
                local_prune_decision="N"
            fi
            ;;
    esac
    case "${local_prune_decision:-N}" in
        y|Y)
            while IFS= read -r rel; do
                [[ -z "$rel" ]] && continue
                if [[ -f "$CLAUDE_DIR/$rel" ]]; then
                    rm -f "$CLAUDE_DIR/$rel"
                    REMOVED_PATHS+=("$rel")
                fi
            done < <(jq -r '.[]' <<<"$REMOVED_FROM_MANIFEST")
            ;;
        *)
            while IFS= read -r rel; do
                [[ -z "$rel" ]] && continue
                SKIPPED_PATHS+=("$rel:removal_declined")
            done < <(jq -r '.[]' <<<"$REMOVED_FROM_MANIFEST")
            ;;
    esac
fi

# Mode-switch-removed files already deleted on disk by Plan 04-01's execute_mode_switch;
# surface them in the summary (they belong in REMOVED_PATHS per D-58).
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    REMOVED_PATHS+=("$rel")
done < <(jq -r '.[]' <<<"$REMOVED_BY_SWITCH_JSON")

# ── Modified files (D-56) — per-file [y/N/d] prompt ──
prompt_modified_file() {
    local rel="$1" local_path remote_tmp stored actual
    local_path="$CLAUDE_DIR/$rel"
    stored=$(jq -r --arg p "$rel" '.installed_files[] | select(.path == $p) | .sha256 // ""' <<<"$STATE_JSON")
    # Pitfall 11: empty stored hash = unknown install-time state -> skip silently
    if [[ -z "$stored" ]]; then
        return 0
    fi
    # Missing on disk — state thinks it's installed but file is gone; don't prompt
    if [[ ! -f "$local_path" ]]; then
        SKIPPED_PATHS+=("$rel:missing_on_disk")
        return 0
    fi
    actual=$(sha256_file "$local_path") || { SKIPPED_PATHS+=("$rel:hash_failed"); return 0; }
    # Identical — no action, no log
    if [[ "$actual" == "$stored" ]]; then
        return 0
    fi
    # Modified — fetch remote for comparison/overwrite
    remote_tmp=$(mktemp "${TMPDIR:-/tmp}/remote.XXXXXX")
    # shellcheck disable=SC2064  # intentional: variable captured at trap registration time
    trap "rm -f '$remote_tmp'" RETURN
    # TK_UPDATE_FILE_SRC: test seam for hermetic file-src injection (never set in production).
    # When set, ONLY copy from the seam dir; never fall through to curl (hermetic boundary).
    if [[ -n "${TK_UPDATE_FILE_SRC:-}" ]]; then
        if [[ -f "$TK_UPDATE_FILE_SRC/$rel" ]]; then
            cp "$TK_UPDATE_FILE_SRC/$rel" "$remote_tmp"
        else
            log_warning "Cannot fetch remote $rel for compare (not in TK_UPDATE_FILE_SRC); skipping"
            SKIPPED_PATHS+=("$rel:remote_fetch_failed")
            return 0
        fi
    else
        if ! curl -sSLf "$REPO_URL/$rel" -o "$remote_tmp" 2>/dev/null; then
            log_warning "Cannot fetch remote $rel for compare; skipping"
            SKIPPED_PATHS+=("$rel:remote_fetch_failed")
            return 0
        fi
    fi
    while :; do
        local choice=""
        if ! read -r -p "File $rel modified locally. Overwrite? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                cp "$remote_tmp" "$local_path"
                UPDATED_PATHS+=("$rel")
                return 0 ;;
            d|D)
                diff -u "$local_path" "$remote_tmp" || true ;;
            *)
                SKIPPED_PATHS+=("$rel:locally_modified")
                return 0 ;;
        esac
    done
}

while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    prompt_modified_file "$rel"
done < <(jq -r '.[]' <<<"$MODIFIED_ACTUAL")

# ============================================================================
# SMART MERGE CLAUDE.md
# ============================================================================

echo ""
log_info "Updating CLAUDE.md (preserving user sections)..."

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD_NEW=$(mktemp)

# Download new template
if ! curl -sSL "$TEMPLATE_URL/CLAUDE.md" -o "$CLAUDE_MD_NEW" 2>/dev/null; then
    curl -sSL "$REPO_URL/templates/base/CLAUDE.md" -o "$CLAUDE_MD_NEW" 2>/dev/null
fi

if [[ -f "$CLAUDE_MD" ]] && [[ -f "$CLAUDE_MD_NEW" ]]; then
    # Extract user sections from current CLAUDE.md
    # These sections contain project-specific customizations

    USER_SECTIONS_FILE=$(mktemp)

    # Extract Project Overview section
    sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true

    # Extract Project Structure section
    sed -n '/^## 📁 Project Structure/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true

    # Extract Essential Commands section
    sed -n '/^## ⚡ Essential Commands/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.commands" 2>/dev/null || true

    # Extract Project-Specific Notes section
    sed -n '/^## ⚠️ Project-Specific Notes/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.notes" 2>/dev/null || true

    # If no user sections extracted, this might be first install or different format
    # In that case, just use the new template

    HAS_USER_CONTENT=false
    for section in overview structure commands notes; do
        if [[ -s "$USER_SECTIONS_FILE.$section" ]]; then
            # Check if it's not just placeholder text
            if ! grep -q '\[Project Name\]\|\[Framework\]\|\[command\]\|\[List project' "$USER_SECTIONS_FILE.$section" 2>/dev/null; then
                HAS_USER_CONTENT=true
                break
            fi
        fi
    done

    if [[ "$HAS_USER_CONTENT" == "true" ]]; then
        log_info "Found user customizations, merging..."

        # Start with new template
        cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"

        # Replace placeholder sections with user content
        # This is a simplified approach - for each user section, replace the placeholder in new template

        for section in overview structure commands notes; do
            if [[ -s "$USER_SECTIONS_FILE.$section" ]]; then
                # Get the section header pattern
                case $section in
                    overview)  PATTERN="## 🎯 Project Overview" ;;
                    structure) PATTERN="## 📁 Project Structure" ;;
                    commands)  PATTERN="## ⚡ Essential Commands" ;;
                    notes)     PATTERN="## ⚠️ Project-Specific Notes" ;;
                esac

                # Find line numbers for replacement
                START_LINE=$(grep -n "^$PATTERN" "$CLAUDE_MD" | head -1 | cut -d: -f1)
                if [[ -n "$START_LINE" ]]; then
                    # Find next section
                    END_LINE=$(tail -n +$((START_LINE + 1)) "$CLAUDE_MD" | grep -n "^## " | head -1 | cut -d: -f1)
                    if [[ -n "$END_LINE" ]]; then
                        END_LINE=$((START_LINE + END_LINE - 1))
                    else
                        END_LINE=$(wc -l < "$CLAUDE_MD")
                    fi

                    # Replace section
                    {
                        head -n $((START_LINE - 1)) "$CLAUDE_MD"
                        cat "$USER_SECTIONS_FILE.$section"
                        tail -n +$((END_LINE + 1)) "$CLAUDE_MD"
                    } > "$CLAUDE_MD.tmp"
                    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
                fi
            fi
        done

        log_success "CLAUDE.md merged (user sections preserved)"
    else
        log_info "No user customizations found, using new template"
        cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"
        log_success "CLAUDE.md updated"
    fi

    # Cleanup temp files
    rm -f "$USER_SECTIONS_FILE"* "$CLAUDE_MD_NEW"
else
    # No existing CLAUDE.md, just copy new one
    cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"
    log_success "CLAUDE.md created"
    rm -f "$CLAUDE_MD_NEW"
fi

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-03 — persist final state atomically
# ─────────────────────────────────────────────────

# Build the post-dispatch installed_files CSV (absolute paths so write_state hashes them).
# Keep survivors from pre-run state minus anything removed this run,
# then append newly installed paths.
FINAL_INSTALLED_CSV=""
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    # skip if removed this run
    if printf '%s\n' "${REMOVED_PATHS[@]:-}" | grep -Fxq "$rel"; then continue; fi
    [[ -n "$FINAL_INSTALLED_CSV" ]] && FINAL_INSTALLED_CSV+=","
    FINAL_INSTALLED_CSV+="$CLAUDE_DIR/$rel"
done < <(jq -r '.installed_files[].path' <<<"$STATE_JSON")
for rel in "${INSTALLED_PATHS[@]:-}"; do
    [[ -z "$rel" ]] && continue
    [[ -n "$FINAL_INSTALLED_CSV" ]] && FINAL_INSTALLED_CSV+=","
    FINAL_INSTALLED_CSV+="$CLAUDE_DIR/$rel"
done

# Build skipped CSV (entries already in path:reason form)
FINAL_SKIPPED_CSV=""
for entry in "${SKIPPED_PATHS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    [[ -n "$FINAL_SKIPPED_CSV" ]] && FINAL_SKIPPED_CSV+=","
    FINAL_SKIPPED_CSV+="$entry"
done

write_state "$STATE_MODE" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" \
            "$FINAL_INSTALLED_CSV" "$FINAL_SKIPPED_CSV"

# B2: write_state does not accept a manifest_hash arg — post-process atomically.
# This allows the next run's no-op check to compare manifest content hashes.
STATE_TMP="${STATE_FILE}.tmp.$$"
# Register STATE_TMP cleanup before writing so SIGKILL between jq and mv leaves no orphan.
trap 'rm -f "$STATE_TMP"; release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$LIB_DRO_TMP" "$MANIFEST_TMP"' EXIT
jq --arg mh "$MANIFEST_HASH" '. + { manifest_hash: $mh }' "$STATE_FILE" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE_FILE"

print_update_summary "$BACKUP_DIR"
recommend_optional_plugins

echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
