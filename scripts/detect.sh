#!/bin/bash

# Claude Code Toolkit — Plugin Detection Library
# Source this file. Do NOT execute it directly.
# Exports: HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION
#
# Remote callers: DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX") && \
#   curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" && source "$DETECT_TMP"
# Local callers:  source "$(dirname "$0")/detect.sh"
#
# IMPORTANT: No errexit/nounset/pipefail here — sourced files must not alter caller error mode.

# Colors (defined but not used in detect.sh body — callers decide what to print per D-05)
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
# shellcheck disable=SC2034
NC='\033[0m'

# Path constants (per RESEARCH.md Pattern 1)
SP_PLUGIN_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"
SETTINGS_JSON="$HOME/.claude/settings.json"

detect_superpowers() {
    # Check filesystem: plugin directory must exist
    if [[ ! -d "$SP_PLUGIN_DIR" ]]; then
        HAS_SP=false
        SP_VERSION=""
        export HAS_SP SP_VERSION
        return 1
    fi

    # At least one versioned subdir (non-hidden entry in the dir)
    local ver
    ver=$(find "$SP_PLUGIN_DIR" -mindepth 1 -maxdepth 1 -not -name '.*' -type d 2>/dev/null \
        | sort -V | tail -1 | xargs -I{} basename {})
    if [[ -z "$ver" ]]; then
        HAS_SP=false
        SP_VERSION=""
        export HAS_SP SP_VERSION
        return 1
    fi

    # DETECT-03: Cross-reference settings.json to suppress stale-cache false positives.
    # Key "superpowers@claude-plugins-official" set to false means SP is disabled.
    # Missing key (older Claude Code) or value true both pass through.
    # NOTE: jq's // operator treats both null AND false as alternatives, so we use
    # has() to distinguish "key absent" (missing) from "key present but false".
    if [[ -f "$SETTINGS_JSON" ]] && command -v jq &>/dev/null; then
        local enabled
        enabled=$(jq -r '
            if (.enabledPlugins | type) == "object" and (.enabledPlugins | has("superpowers@claude-plugins-official"))
            then .enabledPlugins["superpowers@claude-plugins-official"] | tostring
            else "missing"
            end
        ' "$SETTINGS_JSON" 2>/dev/null || echo "missing")
        if [[ "$enabled" == "false" ]]; then
            HAS_SP=false
            SP_VERSION=""
            export HAS_SP SP_VERSION
            return 1
        fi
    fi

    # [STEP 4] DETECT-06: cross-check via the claude CLI plugin list (JSON mode).
    # SP only — GSD is not a plugin; never appears in the plugin list (see detect_gsd).
    # Silent skip when claude CLI absent or errors; FS result wins on any CLI failure (D-17).
    # Output captured once into cli_json; parsed twice via herestring to avoid two subprocesses.
    if command -v claude &>/dev/null && command -v jq &>/dev/null; then
        local cli_json cli_enabled cli_ver
        cli_json=$(claude plugin list --json 2>/dev/null || echo "")
        cli_enabled=$(jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled' \
            <<<"$cli_json" 2>/dev/null || echo "")
        cli_ver=$(jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version' \
            <<<"$cli_json" 2>/dev/null || echo "")
        case "$cli_enabled" in
            "false")
                # CLI explicitly disabled — override FS (D-16)
                HAS_SP=false
                SP_VERSION=""
                export HAS_SP SP_VERSION
                return 1
                ;;
            "true")
                # CLI confirms enabled; CLI version is authoritative over FS dir-name (D-18)
                [[ -n "$cli_ver" ]] && ver="$cli_ver"
                ;;
            "")
                # Empty: CLI doesn't know about SP, OR CLI errored, OR non-JSON output.
                # Fall back to FS truth (don't override). Do NOT treat as "false" (D-16).
                ;;
        esac
    fi

    HAS_SP=true
    SP_VERSION="$ver"
    export HAS_SP SP_VERSION
    return 0
}

detect_gsd() {
    # DETECT-06 does not apply: GSD is not a Claude Code plugin — it never appears
    # in the CLI plugin list output. Detection stays filesystem-only (D-13).
    # Filesystem only — GSD is not a Claude Code plugin; it has no entry in settings.json
    if [[ -d "$GSD_DIR" ]] && [[ -f "$GSD_DIR/bin/gsd-tools.cjs" ]]; then
        HAS_GSD=true
        GSD_VERSION=$(cat "$GSD_DIR/VERSION" 2>/dev/null || echo "")
    else
        HAS_GSD=false
        GSD_VERSION=""
    fi
    export HAS_GSD GSD_VERSION
}

# Call both functions. detect_superpowers returns 1 when SP is absent — the || true ensures
# that sourcing this file into a set -e context does not abort the caller on a normal "not found".
detect_superpowers || true
detect_gsd
