#!/bin/bash

# Claude Code Toolkit — Migrate-to-Complement Script
# One-time destructive migration for existing v3.x users with SP/GSD installed.
# Enumerates duplicates per manifest.json conflicts_with + recommend_mode, shows a
# three-column hash diff, takes a full backup, per-file [y/N/d] prompt.
#
# Usage:
#   bash scripts/migrate-to-complement.sh               # interactive default
#   bash scripts/migrate-to-complement.sh --dry-run     # preview only, no changes
#   bash scripts/migrate-to-complement.sh --yes         # accept all (automation)
#   bash scripts/migrate-to-complement.sh --verbose     # expand output
#   bash scripts/migrate-to-complement.sh --no-backup   # FORBIDDEN — exits 1
#
# Plan 05-02 ships: header + fetch + detect + enumerate + 3-way diff + prompt + backup.
# Plan 05-03 extends this same file with: lock acquire, state rewrite, idempotence early-exit.

set -euo pipefail

# ───────── flag parsing (before color constants) ─────────
YES=0
DRY_RUN=0
VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y)      YES=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --verbose|-v)  VERBOSE=1 ;;
        --no-backup)
            echo -e "\033[0;31m✗\033[0m --no-backup is not allowed. Backup before migration is an invariant." >&2
            exit 1
            ;;
        --help|-h)
            sed -n '3,18p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            # Audit M3: fail-closed on unknown flag. Migration is destructive
            # (renames duplicates after backup). A typo like `--dry-runn`
            # previously warned and proceeded with the interactive default.
            # Mirrors the uninstall.sh:42 / setup-security.sh:33 pattern.
            echo -e "\033[0;31m✗\033[0m unknown flag: $arg" >&2
            echo "Supported: --yes/-y --dry-run --verbose/-v --no-backup --help/-h" >&2
            exit 1
            ;;
    esac
done
# VERBOSE is reserved for Plan 05-03 (extended logging); referenced here to satisfy shellcheck
: "$VERBOSE"

# ───────── ANSI color constants ─────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"

# Audit L4 — global rules §2: every outgoing curl gets a real browser UA.
# shellcheck disable=SC2034
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"
log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# ───────── mktemp + trap EXIT cleanup ─────────
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install.XXXXXX")
LIB_STATE_TMP=$(mktemp "${TMPDIR:-/tmp}/state.XXXXXX")
LIB_BACKUP_TMP=$(mktemp "${TMPDIR:-/tmp}/backup.XXXXXX")
LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output.XXXXXX")
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
TK_TMPL_TMP=$(mktemp "${TMPDIR:-/tmp}/tk-tmpl.XXXXXX")
# EXIT trap: release_lock first (ignore failure if not yet sourced), then clean tempfiles.
# release_lock is defined by lib/state.sh which is sourced after the mktemps below.
# Guard with `|| true` so EXIT firing before the source does not produce a shell error.
trap 'release_lock 2>/dev/null || true; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$MANIFEST_TMP" "$TK_TMPL_TMP"' EXIT

# ───────── detect.sh soft-fail (with test seam) ─────────
if [[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]; then
    : # env vars set by caller (test seam or CI) — skip detect.sh fetch
elif curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
else
    log_warning "Could not fetch detect.sh — plugin detection unavailable"
    HAS_SP=false
    HAS_GSD=false
    SP_VERSION=""
    # shellcheck disable=SC2034  # GSD_VERSION exported for symmetry with detect.sh contract
    GSD_VERSION=""
fi

# ───────── lib/install.sh + lib/state.sh + lib/backup.sh HARD-fail (with test seam) ─────────
for lib_pair in "install.sh:$LIB_INSTALL_TMP" "state.sh:$LIB_STATE_TMP" "backup.sh:$LIB_BACKUP_TMP" "dry-run-output.sh:$LIB_DRO_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_MIGRATE_LIB_DIR:-}" && -f "$TK_MIGRATE_LIB_DIR/$lib_name" ]]; then
        cp "$TK_MIGRATE_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
        log_error "Failed to fetch scripts/lib/$lib_name — migrate cannot proceed"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
done

# ───────── remote manifest HARD-fail + schema check (with test seam) ─────────
MANIFEST_SRC="${TK_MIGRATE_MANIFEST_OVERRIDE:-}"
if [[ -n "$MANIFEST_SRC" && -f "$MANIFEST_SRC" ]]; then
    cp "$MANIFEST_SRC" "$MANIFEST_TMP"
elif ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/manifest.json" -o "$MANIFEST_TMP"; then
    log_error "Failed to fetch manifest.json — migrate cannot proceed"
    exit 1
fi
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP" 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    log_error "manifest.json has manifest_version=${MANIFEST_VER:-unknown}; migrate expects v2"
    exit 1
fi

# ───────── CLAUDE_DIR / STATE_FILE / LOCK_DIR (per-project, with test seam) ─────────
# TK installs to ./.claude/ per project (init-claude.sh / update-claude.sh /
# uninstall.sh all use the per-project path). Migration runs from the project
# root, so duplicates and state must be looked up there too.
# Previous default $HOME/.claude was wrong: TK never installs to the user
# home, so migrate enumerated zero duplicates regardless of project state.
CLAUDE_DIR="$(pwd)/.claude"
if [[ -n "${TK_MIGRATE_HOME:-}" ]]; then
    CLAUDE_DIR="$TK_MIGRATE_HOME/.claude"
fi
# shellcheck disable=SC2034  # STATE_FILE consumed by Plan 05-03 read_state/write_state
STATE_FILE="$CLAUDE_DIR/toolkit-install.json"
# shellcheck disable=SC2034  # LOCK_DIR consumed by Plan 05-03 acquire_lock/release_lock
LOCK_DIR="$CLAUDE_DIR/.toolkit-install.lock"

# ───────── helpers ─────────

# fetch_tk_template_hash <rel_path>
# Stdout: sha256 hash of the TK template (as it would be installed), or "" on failure.
fetch_tk_template_hash() {
    local rel="$1"
    local out=""
    if [[ -n "${TK_MIGRATE_FILE_SRC:-}" ]]; then
        if [[ -f "$TK_MIGRATE_FILE_SRC/$rel" ]]; then
            out=$(sha256_file "$TK_MIGRATE_FILE_SRC/$rel" 2>/dev/null || echo "")
        fi
    else
        if curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$rel" -o "$TK_TMPL_TMP" 2>/dev/null; then
            out=$(sha256_file "$TK_TMPL_TMP" 2>/dev/null || echo "")
        fi
    fi
    printf '%s' "$out"
}

# resolve_sp_path <rel_path>
# Stdout: absolute filesystem path to the SP equivalent, or "" if SP_VERSION empty.
resolve_sp_path() {
    local rel="$1"
    local sp_equiv
    sp_equiv=$(jq -r --arg p "$rel" \
        '.files | to_entries[] | .value[] | select(.path == $p) | .sp_equivalent // ""' \
        "$MANIFEST_TMP")
    # same-basename fallback (agents/code-reviewer.md)
    [[ -z "$sp_equiv" ]] && sp_equiv="$rel"
    # D-71 defensive: reject path traversal (.. / .)
    if [[ "$sp_equiv" == *"/../"* || "$sp_equiv" == *"/./"* || "$sp_equiv" == /* ]]; then
        echo ""
        return
    fi
    if [[ -z "$SP_VERSION" ]]; then
        echo ""
        return
    fi
    local sp_root="${TK_MIGRATE_SP_CACHE_DIR:-$HOME/.claude/plugins/cache/claude-plugins-official}"
    echo "$sp_root/superpowers/$SP_VERSION/$sp_equiv"
}

# short_hash <full_sha256>  — truncate to 8 chars for readability. "" stays "—".
short_hash() {
    local h="$1"
    if [[ -z "$h" ]]; then
        printf '—'
    else
        printf '%s' "${h:0:8}"
    fi
}

# cleanup_stale_council_command (Phase 24 Sub-Phase 1)
# v4.4 installs put commands/council.md into per-project ./.claude/commands/.
# v4.5 ships it globally via setup-council.sh. Detect leftover local copies
# and offer interactive removal. Idempotent — no-op if nothing to clean.
#
# Behaviour matrix:
#   local exists, global missing → recommend running setup-council.sh first.
#   local exists, global same    → safe to remove local (it's a duplicate).
#   local exists, global differs → may be user customization; warn + prompt.
#   local missing                → no-op.
cleanup_stale_council_command() {
    local local_council="$CLAUDE_DIR/commands/council.md"
    local global_council="$HOME/.claude/commands/council.md"

    [[ -f "$local_council" ]] || return 0

    local local_hash="" global_hash="" hashes_differ=false
    local_hash=$(sha256_file "$local_council" 2>/dev/null || echo "")
    if [[ -f "$global_council" ]]; then
        global_hash=$(sha256_file "$global_council" 2>/dev/null || echo "")
        if [[ -n "$local_hash" && -n "$global_hash" && "$local_hash" != "$global_hash" ]]; then
            hashes_differ=true
        fi
    fi

    echo ""
    log_warning "Stale per-project Council command detected:"
    echo "    $local_council"
    if [[ ! -f "$global_council" ]]; then
        echo "    Global counterpart at $global_council does NOT exist."
        echo "    Run setup-council.sh first, then re-run this migration."
        return 0
    fi
    if [[ "$hashes_differ" == "true" ]]; then
        echo "    Global $global_council exists with DIFFERENT contents."
        echo "    Your local file may carry user customizations."
    else
        echo "    Global counterpart exists at $global_council (identical content)."
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "    [dry-run] would offer interactive removal."
        return 0
    fi

    if [[ $YES -eq 1 ]]; then
        rm -f "$local_council"
        log_success "Removed $local_council (--yes)"
        return 0
    fi

    local choice=""
    if ! read -r -p "Remove stale per-project council.md? [y/N]: " choice < /dev/tty 2>/dev/null; then
        choice="N"
    fi
    case "${choice:-N}" in
        y|Y)
            rm -f "$local_council"
            log_success "Removed $local_council"
            ;;
        *)
            log_info "Kept $local_council"
            ;;
    esac
}

# ───────── MAIN ─────────

[[ ! -d "$CLAUDE_DIR" ]] && { log_error "$CLAUDE_DIR not found. Nothing to migrate."; exit 1; }

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Code Toolkit — Migrate to Complement Mode       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

RECOMMENDED=$(recommend_mode)
log_info "Detected: HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD → recommended mode: ${CYAN}$RECOMMENDED${NC}"

# ───────── idempotence early-exit (MIGRATE-06 / D-78) ─────────
# Two-signal AND: (a) state.mode != standalone AND (b) compute_skip_set ∩ filesystem empty.
# Self-healing: manual state rollback with duplicates already gone still exits cleanly.
STATE_MODE_CURRENT="standalone"
if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC2015
    STATE_MODE_CURRENT=$(jq -r '.mode // "standalone"' "$STATE_FILE" 2>/dev/null || echo "standalone")
fi
if [[ "$STATE_MODE_CURRENT" != "standalone" ]]; then
    _IDEMPOTENT_SKIP=$(compute_skip_set "$STATE_MODE_CURRENT" "$MANIFEST_TMP")
    _INTERSECTION_HIT=false
    while IFS= read -r _r; do
        [[ -z "$_r" ]] && continue
        if [[ -f "$CLAUDE_DIR/$_r" ]]; then _INTERSECTION_HIT=true; break; fi
    done < <(jq -r '.[]' <<<"$_IDEMPOTENT_SKIP")
    if [[ "$_INTERSECTION_HIT" == "false" ]]; then
        echo "Already migrated to $STATE_MODE_CURRENT. Nothing to do."
        exit 0
    fi
    unset _IDEMPOTENT_SKIP _INTERSECTION_HIT _r
fi

# ───────── enumerate duplicates ─────────
SKIP_SET_JSON=$(compute_skip_set "$RECOMMENDED" "$MANIFEST_TMP")
DUPLICATES=()
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if [[ -f "$CLAUDE_DIR/$rel" ]]; then
        DUPLICATES+=("$rel")
    fi
done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")

if [[ ${#DUPLICATES[@]} -eq 0 ]]; then
    log_success "No duplicate files found on disk. Nothing to migrate."
    # Phase 24 SP1: even with no SP/GSD duplicates, a v4.4 install may still
    # carry the legacy per-project council.md leftover. Run cleanup hook.
    cleanup_stale_council_command
    exit 0
fi

# ───────── three-column diff (MIGRATE-02) ─────────
echo ""
log_info "Found ${#DUPLICATES[@]} duplicate file(s). Computing three-way hash summary…"
echo ""
printf '  %-40s  %-10s  %-10s  %-10s\n' "path" "TK tmpl" "on-disk" "SP equiv"
printf '  %-40s  %-10s  %-10s  %-10s\n' "────────────────────────────────────────" "────────" "────────" "────────"

# Pre-compute and cache all three hashes per duplicate (avoids re-fetching during prompt loop).
declare -a TK_HASHES=()
declare -a DISK_HASHES=()
# shellcheck disable=SC2034  # SP_HASHES consumed by Plan 05-03 (post-loop state rewrite diff)
declare -a SP_HASHES=()
for i in "${!DUPLICATES[@]}"; do
    rel="${DUPLICATES[$i]}"
    tk_h=$(fetch_tk_template_hash "$rel")
    disk_h=$(sha256_file "$CLAUDE_DIR/$rel" 2>/dev/null || echo "")
    sp_path=$(resolve_sp_path "$rel")
    sp_h=""
    if [[ -n "$sp_path" && -f "$sp_path" ]]; then
        sp_h=$(sha256_file "$sp_path" 2>/dev/null || echo "")
    fi
    TK_HASHES[i]="$tk_h"
    DISK_HASHES[i]="$disk_h"
    SP_HASHES[i]="$sp_h"
    printf '  %-40s  %-10s  %-10s  %-10s\n' \
        "$rel" "$(short_hash "$tk_h")" "$(short_hash "$disk_h")" "$(short_hash "$sp_h")"
    # D-72 graceful degrade note for absent SP file
    if [[ -z "$sp_h" && -n "$sp_path" ]]; then
        log_warning "SP file not found at $sp_path — third column degraded to 2-column"
    fi
done
# SP_HASHES reserved for Plan 05-03 state-rewrite diff; reference here silences SC2034.
: "${SP_HASHES[*]:-}"
echo ""

# ───────── dry-run early exit (UX-01 SC3 — Phase 11 Plan 11-03) ─────────
# Preserves the 3-col hash table above for diagnostic context, then prints
# a chezmoi-grade [- REMOVE] grouped preview using shared dry-run-output.sh
# primitives. Zero filesystem writes, no backup, no state rewrite.
if [[ $DRY_RUN -eq 1 ]]; then
    if ! command -v dro_init_colors >/dev/null 2>&1; then
        log_error "dry-run-output.sh not sourced — cannot render styled preview"
        exit 1
    fi
    dro_init_colors
    dro_print_header "-" "REMOVE" "${#DUPLICATES[@]}" _DRO_R
    for rel in "${DUPLICATES[@]}"; do
        dro_print_file "$rel"
    done
    echo ""
    dro_print_total "${#DUPLICATES[@]}"
    # Phase 24 SP1: surface stale per-project council.md preview alongside
    # SP/GSD duplicates so dry-run users see the full picture.
    cleanup_stale_council_command
    exit 0
fi

# ───────── acquire mutation lock (Phase 2 D-08..D-11) ─────────
acquire_lock || { log_error "Another TK install/update is in progress. Exiting."; exit 1; }

# ───────── backup (MIGRATE-04) — BEFORE any rm ─────────
# Derive from CLAUDE_DIR so TK_MIGRATE_HOME seam is honored (UAT-3-B01).
# Production: CLAUDE_DIR=$HOME/.claude → backup at $HOME/.claude-backup-...  (unchanged).
# Test seam:  CLAUDE_DIR=$TK_MIGRATE_HOME/.claude → backup stays inside the test HOME.
# Audit M2: same-second collision when two parallel sessions both run migrate.
# Append $$ for PID disambiguation (matches uninstall.sh:612 + update-claude.sh:938).
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-migrate-$(date -u +%s)-$$"
log_info "Creating backup at $BACKUP_DIR (this may take a moment)…"
if ! cp -R "$CLAUDE_DIR" "$BACKUP_DIR"; then
    log_error "Backup failed — aborting migration without removing any files"
    # Clean up partial backup dir if it exists
    [[ -d "$BACKUP_DIR" ]] && rm -rf "$BACKUP_DIR"
    exit 1
fi
log_success "Backup created: $BACKUP_DIR"
warn_if_too_many_backups
echo ""

# ───────── per-file prompt loop (MIGRATE-03, D-73, D-74) ─────────
MIGRATED_PATHS=()
KEPT_PATHS=()

prompt_duplicate_file() {
    local rel="$1" tk_h="$2" disk_h="$3"
    local local_path="$CLAUDE_DIR/$rel"
    # D-73 two-signal user-mod detection.
    # Signal (a): current disk hash != state.installed_files[].sha256 (install-time hash).
    # Signal (b): current disk hash != TK template hash (signal (b) catches the
    # synthesis edge case where signal (a) is always satisfied by construction).
    local state_h=""
    if [[ -f "$STATE_FILE" ]]; then
        # Try both absolute and relative keys (Phase 4 stores relative after normalization).
        state_h=$(jq -r --arg p "$rel" --arg base "$CLAUDE_DIR/" \
            '(.installed_files[] | select(.path == $p or .path == ($base + $p)) | .sha256 // "") // ""' \
            "$STATE_FILE" 2>/dev/null || echo "")
    fi
    local modified=false
    local reason=""
    if [[ -n "$state_h" && "$disk_h" != "$state_h" ]]; then
        modified=true
        reason="modified since install (differs from state hash)"
    fi
    if [[ -n "$tk_h" && "$disk_h" != "$tk_h" ]]; then
        modified=true
        if [[ -n "$reason" ]]; then
            reason="$reason; also differs from TK template"
        else
            reason="modified vs TK template (signal b — synthesis case)"
        fi
    fi
    if [[ "$modified" == "true" ]]; then
        log_warning "File $rel locally modified: $reason"
    fi

    # --yes bypass — accept the removal immediately without prompting
    if [[ $YES -eq 1 ]]; then
        rm -f "$local_path"
        MIGRATED_PATHS+=("$rel")
        log_success "Removed (--yes): $rel"
        return 0
    fi

    while :; do
        local choice=""
        if ! read -r -p "Remove $rel? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
            choice="N"  # fail-closed under curl|bash
        fi
        case "${choice:-N}" in
            y|Y)
                rm -f "$local_path"
                MIGRATED_PATHS+=("$rel")
                return 0
                ;;
            d|D)
                # Re-fetch TK template into TK_TMPL_TMP (may have been overwritten by prior iterations)
                if [[ -n "${TK_MIGRATE_FILE_SRC:-}" && -f "$TK_MIGRATE_FILE_SRC/$rel" ]]; then
                    cp "$TK_MIGRATE_FILE_SRC/$rel" "$TK_TMPL_TMP"
                elif ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$rel" -o "$TK_TMPL_TMP" 2>/dev/null; then
                    log_warning "Cannot fetch TK template for diff; skipping diff render"
                    continue
                fi
                diff -u "$local_path" "$TK_TMPL_TMP" || true
                # re-enter loop for another prompt
                ;;
            *)
                KEPT_PATHS+=("$rel:kept_by_user")
                return 0
                ;;
        esac
    done
}

for i in "${!DUPLICATES[@]}"; do
    prompt_duplicate_file "${DUPLICATES[$i]}" "${TK_HASHES[$i]}" "${DISK_HASHES[$i]}"
done

# ───────── state rewrite (MIGRATE-05 / D-79) ─────────
# Build installed_files CSV (absolute paths so write_state computes sha256s).
# Strategy: enumerate every manifest.files.*.path that is NOT in the migrated set
# AND is currently present on disk → that's the post-migration installed set.
FINAL_INSTALLED_CSV=""
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    # Skip if this path was removed during migration
    _WAS_MIGRATED=false
    for mp in "${MIGRATED_PATHS[@]:-}"; do
        [[ "$mp" == "$rel" ]] && { _WAS_MIGRATED=true; break; }
    done
    [[ "$_WAS_MIGRATED" == "true" ]] && continue
    # Include only if still present on disk
    [[ -f "$CLAUDE_DIR/$rel" ]] || continue
    [[ -n "$FINAL_INSTALLED_CSV" ]] && FINAL_INSTALLED_CSV+=","
    FINAL_INSTALLED_CSV+="$CLAUDE_DIR/$rel"
done < <(jq -r '.files | to_entries[] | .value[] | .path' "$MANIFEST_TMP")
unset _WAS_MIGRATED

# Build skipped_files CSV in path:reason form (KEPT_PATHS already has this shape)
FINAL_SKIPPED_CSV=""
for entry in "${KEPT_PATHS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    [[ -n "$FINAL_SKIPPED_CSV" ]] && FINAL_SKIPPED_CSV+=","
    FINAL_SKIPPED_CSV+="$entry"
done

# Post-migration mode: D-79 — always recommend_mode regardless of partial/full acceptance
POST_MODE=$(recommend_mode)

# 8th positional arg is synth_flag="false" — this is a production migration write,
# NOT a synthesis. Plan 05-01's schema v2 extension is consumed here.
# Phase 29 BRIDGE-SYNC-02: preserve bridges[] across migrate. See init-local.sh
# for rationale; same 10-arg pattern.
BRIDGES_JSON='[]'
if [[ -f "$STATE_FILE" ]]; then
    BRIDGES_JSON=$(jq -c '.bridges // []' "$STATE_FILE" 2>/dev/null || echo '[]')
fi
write_state "$POST_MODE" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$FINAL_INSTALLED_CSV" "$FINAL_SKIPPED_CSV" "false" "" "$BRIDGES_JSON"

# ───────── four-group summary ─────────
echo ""
echo "Migration Summary"
echo "─────────────────"
printf '%bMIGRATED %d%b\n' "$GREEN" "${#MIGRATED_PATHS[@]}" "$NC"
for p in "${MIGRATED_PATHS[@]:-}"; do [[ -z "$p" ]] && continue; echo "  $p"; done
printf '%bKEPT %d%b\n' "$YELLOW" "${#KEPT_PATHS[@]}" "$NC"
for entry in "${KEPT_PATHS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    rp="${entry%%:*}"
    rr="${entry#*:}"
    printf '  %s (%s)\n' "$rp" "$rr"
done
printf '%bBACKED UP%b to %s (1 directory)\n' "$CYAN" "$NC" "$BACKUP_DIR"
printf '%bMODE%b %s → %s\n' "$BLUE" "$NC" "$STATE_MODE_CURRENT" "$POST_MODE"

echo ""
if [[ $VERBOSE -eq 1 ]]; then
    log_info "State written to: $STATE_FILE"
fi

# Phase 24 SP1: clean up legacy per-project council.md alongside SP/GSD migration.
cleanup_stale_council_command

log_warning "⚠ Restart Claude Code to apply changes."
