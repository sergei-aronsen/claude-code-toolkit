#!/bin/bash

# Claude Code Toolkit — Install Flow Library
# Source this file. Do NOT execute it directly.
# Exposes: MODES, recommend_mode, compute_skip_set, print_dry_run_grouped,
#          backup_settings_once
# Globals: TK_SETTINGS_BACKUP (set by backup_settings_once on first call per run)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            All diagnostics go to stderr (>&2). Functions returning values use stdout.

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m'

# Mode constants (D-33). Order matches the interactive prompt 1..4 in init-claude.sh.
MODES=("standalone" "complement-sp" "complement-gsd" "complement-full")

# recommend_mode — pure function over $HAS_SP and $HAS_GSD (set by detect.sh).
# Stdout: one of the four mode strings.
recommend_mode() {
    if   [[ "${HAS_SP:-false}"  == "true" && "${HAS_GSD:-false}" == "true" ]]; then echo "complement-full"
    elif [[ "${HAS_SP:-false}"  == "true" ]];                                  then echo "complement-sp"
    elif [[ "${HAS_GSD:-false}" == "true" ]];                                  then echo "complement-gsd"
    else                                                                            echo "standalone"
    fi
}

# compute_skip_set <mode> <manifest_path>
# Stdout: JSON array of paths to SKIP. Errors go to stderr; returns 1 on bad mode or missing jq.
# (Verified against current manifest.json with jq 1.7.1 per RESEARCH.md Pattern 5.)
compute_skip_set() {
    local mode="$1" manifest_path="$2"
    local skip_json
    case "$mode" in
        standalone)         skip_json='[]' ;;
        complement-sp)      skip_json='["superpowers"]' ;;
        complement-gsd)     skip_json='["get-shit-done"]' ;;
        complement-full)    skip_json='["superpowers","get-shit-done"]' ;;
        *)
            echo "ERROR: unknown mode: $mode" >&2
            return 1 ;;
    esac
    if ! jq --version >/dev/null 2>&1; then
        echo "ERROR: jq not found — required for install mode filtering" >&2
        return 1
    fi
    jq --argjson skip "$skip_json" \
      '[.files | to_entries[] | .value[] |
        select((.conflicts_with // []) as $cw |
               ($skip | any(. as $s | $cw | contains([$s])))) |
        .path]' \
      "$manifest_path"
}

# backup_settings_once <settings_path>
# Sets TK_SETTINGS_BACKUP global on first successful call. No-op on subsequent calls in same run.
# No-op when settings file does not exist.
backup_settings_once() {
    local settings_path="$1"
    [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && return 0
    [[ ! -f "$settings_path" ]] && return 0
    TK_SETTINGS_BACKUP="${settings_path}.bak.$(date +%s)"
    cp "$settings_path" "$TK_SETTINGS_BACKUP"
}

# print_dry_run_grouped <manifest_path> <mode>
# Prints one [INSTALL]/[SKIP - conflicts_with:<plugin>] line per file in manifest.files.*,
# followed by a Total: footer. ANSI colors auto-disable when stdout is not a tty (D-36).
# Zero filesystem writes. Returns 0.
print_dry_run_grouped() {
    local manifest_path="$1" mode="$2"
    local _GREEN _YELLOW _NC
    if [ -t 1 ]; then
        _GREEN='\033[0;32m'; _YELLOW='\033[1;33m'; _NC='\033[0m'
    else
        _GREEN=''; _YELLOW=''; _NC=''
    fi

    # Build the same skip_json as compute_skip_set (kept inline so the jq filter
    # can produce the {bucket, path, skip, reason} stream in one pass).
    local skip_json
    case "$mode" in
        standalone)         skip_json='[]' ;;
        complement-sp)      skip_json='["superpowers"]' ;;
        complement-gsd)     skip_json='["get-shit-done"]' ;;
        complement-full)    skip_json='["superpowers","get-shit-done"]' ;;
        *)
            echo "ERROR: unknown mode: $mode" >&2
            return 1 ;;
    esac
    if ! jq --version >/dev/null 2>&1; then
        echo "ERROR: jq not found - required for dry-run output" >&2
        return 1
    fi

    local install_count=0 skip_count=0
    while IFS= read -r line; do
        local bucket path skip reason
        bucket=$(printf '%s' "$line" | jq -r '.bucket')
        path=$(printf '%s'   "$line" | jq -r '.path')
        skip=$(printf '%s'   "$line" | jq -r '.skip')
        reason=$(printf '%s' "$line" | jq -r '.reason')
        if [ "$skip" = "true" ]; then
            printf '%b[SKIP - conflicts_with:%s]%b %s/%s\n' "$_YELLOW" "$reason" "$_NC" "$bucket" "$path"
            skip_count=$((skip_count + 1))
        else
            printf '%b[INSTALL]%b %s/%s\n' "$_GREEN" "$_NC" "$bucket" "$path"
            install_count=$((install_count + 1))
        fi
    done < <(jq -c --argjson skip "$skip_json" '
        .files | to_entries[] |
        .key as $b | .value[] |
        { bucket: $b, path: .path,
          skip: ((.conflicts_with // []) as $cw |
                 ($skip | any(. as $s | $cw | contains([$s])))),
          reason: ((.conflicts_with // []) | join(",")) }
    ' "$manifest_path")

    echo ""
    echo "Total: $install_count install, $skip_count skip"
}
