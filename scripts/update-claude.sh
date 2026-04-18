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
for arg in "$@"; do
    case "$arg" in
        --no-banner) NO_BANNER=1 ;;
        --offer-mode-switch=yes)                       OFFER_MODE_SWITCH="yes" ;;
        --offer-mode-switch=no|--no-offer-mode-switch) OFFER_MODE_SWITCH="no" ;;
        --offer-mode-switch=interactive)               OFFER_MODE_SWITCH="interactive" ;;
        --prune=yes)                                   PRUNE_MODE="yes" ;;
        --prune=no|--no-prune)                         PRUNE_MODE="no" ;;
        --prune=interactive)                           PRUNE_MODE="interactive" ;;
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
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$MANIFEST_TMP"' EXIT

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
for lib_pair in "install.sh:$LIB_INSTALL_TMP" "state.sh:$LIB_STATE_TMP"; do
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
    write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" ""
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
    # shellcheck disable=SC2034  # REMOVED_BY_SWITCH_JSON consumed by Plan 04-03 summary
    REMOVED_BY_SWITCH_JSON="$files_to_remove_abs"
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

# REMOTE_VERSION alias for legacy summary block below (Plan 04-03 replaces the summary)
REMOTE_VERSION="$REMOTE_TOOLKIT_VERSION"
log_info "Remote version: ${CYAN}$REMOTE_VERSION${NC}"

# Check local version
LOCAL_VERSION="unknown"
if [[ -f "$CLAUDE_DIR/.toolkit-version" ]]; then
    LOCAL_VERSION=$(cat "$CLAUDE_DIR/.toolkit-version")
fi
log_info "Local version: ${CYAN}$LOCAL_VERSION${NC}"

# Backup (legacy v3.x format — Plan 04-03 replaces with D-57 PID-suffix tree backup)
if [[ -z "${TK_UPDATE_SKIP_LEGACY_BACKUP:-}" ]]; then
    BACKUP_DIR=".claude-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
    log_success "Backup created: $BACKUP_DIR"
fi

# ─────────────────────────────────────────────────
# Phase 4 Plan 04-02 — UPDATE-02/03/04 manifest-driven diff + dispatch
# TK_UPDATE_FILE_SRC: test seam — when set, reads file content from local dir instead of curl.
#                     NEVER set in production; CI/test use only.
# ─────────────────────────────────────────────────

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

echo ""
log_info "Updating toolkit files..."

# ── New files (D-54) — auto-install silently ──
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    dest="$CLAUDE_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    install_status=1
    # TK_UPDATE_FILE_SRC: test seam for hermetic file-src injection (never set in production)
    if [[ -n "${TK_UPDATE_FILE_SRC:-}" && -f "$TK_UPDATE_FILE_SRC/$rel" ]]; then
        cp "$TK_UPDATE_FILE_SRC/$rel" "$dest"
        install_status=$?
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
    # TK_UPDATE_FILE_SRC: test seam for hermetic file-src injection (never set in production)
    if [[ -n "${TK_UPDATE_FILE_SRC:-}" && -f "$TK_UPDATE_FILE_SRC/$rel" ]]; then
        cp "$TK_UPDATE_FILE_SRC/$rel" "$remote_tmp"
    else
        if ! curl -sSLf "$REPO_URL/$rel" -o "$remote_tmp" 2>/dev/null; then
            log_warning "Cannot fetch remote $rel for compare; skipping"
            rm -f "$remote_tmp"
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
                rm -f "$remote_tmp"
                return 0 ;;
            d|D)
                diff -u "$local_path" "$remote_tmp" || true ;;
            *)
                SKIPPED_PATHS+=("$rel:locally_modified")
                rm -f "$remote_tmp"
                return 0 ;;
        esac
    done
}

while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    prompt_modified_file "$rel"
done < <(jq -r '.[]' <<<"$MODIFIED_CANDIDATES")

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

# ============================================================================
# SAVE VERSION
# ============================================================================

echo "$REMOTE_VERSION" > "$CLAUDE_DIR/.toolkit-version"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Update Complete!                                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Version: ${CYAN}$LOCAL_VERSION${NC} → ${CYAN}$REMOTE_VERSION${NC}"
if [[ -z "${TK_UPDATE_SKIP_LEGACY_BACKUP:-}" ]]; then
    echo -e "Backup:  ${CYAN}${BACKUP_DIR:-none}${NC}"
fi
echo ""
echo -e "${YELLOW}What was updated:${NC}"
echo "  • agents/       — subagent definitions"
echo "  • prompts/      — audit templates"
echo "  • skills/       — all framework skills (10 total)"
echo "  • CLAUDE.md     — system sections (user sections preserved)"
echo ""
echo -e "${YELLOW}What was preserved:${NC}"
echo "  • Project Overview, Structure, Commands"
echo "  • Project-Specific Notes, Known Gotchas"
echo "  • settings.json, settings.local.json"
echo "  • rules/ content (if existed)"
echo "  • skills/skill-rules.json (if existed)"
echo ""
echo -e "${CYAN}Changelog:${NC} https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/CHANGELOG.md"
echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
