#!/bin/bash

# Claude Code Toolkit — Dependency Update Dashboard
#
# Shows installed + latest version of every tracked dependency across the
# three layers (toolkit, base plugins, external tools) in an aligned table,
# then lets the user pick what to upgrade via a one-keystroke prompt
# (a/o/c/n) plus a comma-list custom mode. Manual control, no auto-update.
#
# Usage:
#   bash scripts/update-deps.sh                  # table + interactive picker
#   bash scripts/update-deps.sh --dry-run        # table only, exit 0
#   bash scripts/update-deps.sh --yes            # update every outdated dep
#   bash scripts/update-deps.sh --check <name>   # probe a single dep, print TSV
#
# Exit codes:
#   0 — all selected upgrades succeeded (or nothing selected)
#   1 — at least one upgrade failed
#   2 — usage / argument error

set -euo pipefail

# ───────── flag parsing ─────────
DRY_RUN=0
YES=0
CHECK_ONE=""
_PREV_ARG=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes)     YES=1 ;;
        --check)   ;;
        --check=*) CHECK_ONE="${arg#--check=}" ;;
        --help|-h)
            sed -n '3,20p' "$0"
            exit 0
            ;;
        *)
            if [[ "$_PREV_ARG" == "--check" ]]; then
                CHECK_ONE="$arg"
            else
                echo "unknown flag: $arg" >&2
                exit 2
            fi
            ;;
    esac
    _PREV_ARG="$arg"
done
unset _PREV_ARG

# ───────── colors ─────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ───────── probe registry ─────────
DEP_NAME=()
DEP_LAYER=()
DEP_PROBE=()
DEP_UPGRADE=()
DEP_NOTES=()

register_dep() {
    DEP_NAME+=("$1")
    DEP_LAYER+=("$2")
    DEP_PROBE+=("$3")
    DEP_UPGRADE+=("$4")
    DEP_NOTES+=("${5:-}")
}

# ───────── probes — return "installed<TAB>latest" ─────────

probe_toolkit() {
    local installed="" latest=""
    if [[ -f "$SCRIPT_DIR/../manifest.json" ]] && command -v jq &>/dev/null; then
        installed=$(jq -r '.version // ""' "$SCRIPT_DIR/../manifest.json" 2>/dev/null)
    fi
    if command -v gh &>/dev/null; then
        latest=$(gh api repos/sergei-aronsen/claude-code-toolkit/releases/latest --jq '.tag_name // ""' 2>/dev/null | sed 's/^v//')
    fi
    printf '%s\t%s\n' "${installed:-?}" "${latest:-?}"
}

upgrade_toolkit() {
    echo "Toolkit updates from inside Claude Code via /update-toolkit. Run that command in your project." >&2
    return 0
}

# Resolve `<owner>/<repo>` for an installed plugin. First tries the local
# plugin.json `.repository` field; falls back to a hardcoded mapping for
# plugins whose plugin.json carries a null repository (e.g. caveman). Final
# fallback is empty string — caller treats that as "rolling, no upstream
# version checkable".
_resolve_plugin_source_repo() {
    local id="$1"  # form: "name@marketplace"
    local pname="${id%@*}"
    local marketplace="${id##*@}"
    local cache_dir="$HOME/.claude/plugins/cache/$marketplace/$pname"
    local repo=""
    if [[ -d "$cache_dir" ]]; then
        local latest_local
        latest_local=$(ls -t "$cache_dir" 2>/dev/null | head -1)
        if [[ -n "$latest_local" ]]; then
            local plugin_json="$cache_dir/$latest_local/.claude-plugin/plugin.json"
            if [[ -f "$plugin_json" ]] && command -v jq &>/dev/null; then
                repo=$(jq -r 'if (.repository | type) == "string" then .repository
                              elif (.repository | type) == "object" then .repository.url // ""
                              else "" end' "$plugin_json" 2>/dev/null \
                    | sed -E 's#^https?://github\.com/##; s#\.git$##' \
                    | head -1)
            fi
        fi
    fi
    # Hardcoded fallback for plugins whose plugin.json has no repository.
    if [[ -z "$repo" || "$repo" == "null" ]]; then
        case "$id" in
            "caveman@caveman")                        repo="JuliusBrussee/caveman" ;;
            "superpowers@claude-plugins-official")    repo="obra/superpowers" ;;
            "ru-text@claude-community")               repo="talkstream/ru-text" ;;
        esac
    fi
    printf '%s\n' "$repo"
}

# Fetch the version that the marketplace currently SHIPS (which can lag
# the source repo's HEAD). Reads the local marketplace.json, finds the
# plugin entry, and resolves the pinned `.source.sha` → `<repo>/plugin.json
# at sha`. Returns empty when the marketplace either ships HEAD (no .sha)
# or has no entry. Caller falls back to source-HEAD probing in that case.
#
# Why this exists: `claude plugin update ru-text@claude-community` says
# "already at 1.4.0" even though the source repo is at 1.7.2 — because the
# marketplace pin is at a 1.4.0 SHA. User-visible reality is what the
# marketplace ships, not what the source repo holds.
_fetch_marketplace_pinned_version() {
    local id="$1"  # "name@marketplace"
    local pname="${id%@*}"
    local marketplace="${id##*@}"
    local mkt_json="$HOME/.claude/plugins/marketplaces/$marketplace/.claude-plugin/marketplace.json"
    [[ -f "$mkt_json" ]] || return 0
    command -v jq &>/dev/null || return 0
    local sha repo
    sha=$(jq -r --arg n "$pname" \
        '.plugins[] | select(.name == $n) | (.source.sha // empty)' \
        "$mkt_json" 2>/dev/null | head -1)
    [[ -z "$sha" ]] && return 0
    repo=$(jq -r --arg n "$pname" \
        '.plugins[] | select(.name == $n) | (.source.url // empty)' \
        "$mkt_json" 2>/dev/null \
        | sed -E 's#^https?://github\.com/##; s#\.git$##' \
        | head -1)
    [[ -z "$repo" ]] && return 0
    if command -v gh &>/dev/null; then
        gh api "repos/$repo/contents/.claude-plugin/plugin.json?ref=$sha" --jq '.content' 2>/dev/null \
            | base64 -d 2>/dev/null \
            | jq -r '.version // empty' 2>/dev/null \
            | head -1
    fi
}

# Fetch upstream version from a GitHub source repo's plugin.json. Returns
# empty string when the repo has no version field (e.g. caveman) or the
# fetch fails. Uses gh api (RTK-immune) so the curl-rewrite hook does not
# corrupt the JSON response.
_fetch_upstream_plugin_version() {
    local repo="$1"  # form: "owner/name"
    [[ -z "$repo" ]] && return 0
    if ! command -v gh &>/dev/null; then
        return 0
    fi
    gh api "repos/$repo/contents/.claude-plugin/plugin.json" --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null \
        | jq -r '.version // empty' 2>/dev/null \
        | head -1
}

# Fetch the short SHA of HEAD on the source repo's default branch. Used as
# a fallback "version" for commit-pinned plugins (caveman) where the
# upstream plugin.json carries no version field.
_fetch_upstream_head_sha() {
    local repo="$1"
    [[ -z "$repo" ]] && return 0
    if ! command -v gh &>/dev/null; then
        return 0
    fi
    gh api "repos/$repo/commits/HEAD" --jq '.sha' 2>/dev/null \
        | cut -c1-12
}

probe_plugin() {
    local id="$1" installed="" latest=""
    if command -v claude &>/dev/null && command -v jq &>/dev/null; then
        installed=$(claude plugin list --json 2>/dev/null \
            | jq -r --arg id "$id" '.[] | select(.id == $id) | .version // empty' 2>/dev/null \
            | head -1)
    fi
    # First try marketplace-pinned version (matches what `claude plugin update`
    # actually ships). Falls back to source-repo HEAD when marketplace either
    # tracks HEAD (no .sha pin) or has no plugin entry.
    latest=$(_fetch_marketplace_pinned_version "$id")
    if [[ -z "$latest" || "$latest" == "null" ]]; then
        local repo
        repo=$(_resolve_plugin_source_repo "$id")
        if [[ -n "$repo" ]]; then
            latest=$(_fetch_upstream_plugin_version "$repo")
            # If upstream plugin.json has no version field (caveman case), fall
            # back to short HEAD SHA so we can still detect drift via inequality.
            if [[ -z "$latest" || "$latest" == "null" ]]; then
                latest=$(_fetch_upstream_head_sha "$repo")
            fi
        fi
    fi
    printf '%s\t%s\n' "${installed:-?}" "${latest:-—}"
}

upgrade_plugin() {
    local id="$1"
    if ! command -v claude &>/dev/null; then
        echo "claude CLI not on PATH" >&2
        return 1
    fi
    claude plugin update "$id"
}

probe_superpowers()       { probe_plugin "superpowers@claude-plugins-official"; }
probe_caveman()           { probe_plugin "caveman@caveman"; }
probe_ru_text()           { probe_plugin "ru-text@claude-community"; }

upgrade_superpowers()     { upgrade_plugin "superpowers@claude-plugins-official"; }
upgrade_caveman()         { upgrade_plugin "caveman@caveman"; }
upgrade_ru_text()         { upgrade_plugin "ru-text@claude-community"; }

probe_gsd() {
    local installed="" latest=""
    [[ -f "$HOME/.claude/get-shit-done/VERSION" ]] && installed=$(cat "$HOME/.claude/get-shit-done/VERSION" 2>/dev/null)
    if command -v gh &>/dev/null; then
        latest=$(gh api repos/gsd-build/get-shit-done/releases/latest --jq '.tag_name // ""' 2>/dev/null | sed 's/^v//')
    fi
    printf '%s\t%s\n' "${installed:-?}" "${latest:-?}"
}

upgrade_gsd() {
    bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/install.sh) </dev/tty
}

probe_npm() {
    local pkg="$1" installed="" latest=""
    if command -v npm &>/dev/null; then
        installed=$(npm ls -g --depth=0 --json 2>/dev/null \
            | jq -r --arg p "$pkg" '.dependencies[$p].version // ""' 2>/dev/null)
        latest=$(npm view "$pkg" version 2>/dev/null | tr -d '\n')
    fi
    printf '%s\t%s\n' "${installed:-—}" "${latest:-?}"
}

upgrade_npm() { npm install -g "$1@latest"; }

probe_cc_safety_net() { probe_npm "cc-safety-net"; }
probe_better_model()  { probe_npm "better-model"; }
probe_gsd_sdk()       { probe_npm "get-shit-done-cc"; }

upgrade_cc_safety_net() { upgrade_npm "cc-safety-net"; }
upgrade_better_model()  { upgrade_npm "better-model"; }
upgrade_gsd_sdk()       { upgrade_npm "get-shit-done-cc"; }

probe_rtk() {
    local installed="" latest=""
    command -v rtk &>/dev/null && installed=$(rtk --version 2>/dev/null | awk '{print $NF}')
    if command -v brew &>/dev/null; then
        latest=$(brew info --json=v2 rtk 2>/dev/null \
            | jq -r '.formulae[0].versions.stable // ""' 2>/dev/null)
    fi
    printf '%s\t%s\n' "${installed:-?}" "${latest:-?}"
}

upgrade_rtk() {
    if ! command -v brew &>/dev/null; then
        echo "brew not on PATH (rtk distributed via homebrew)" >&2
        return 1
    fi
    brew upgrade rtk
}

# Generic helper — is an MCP server registered with Claude Code?
# Reads `~/.claude.json` directly via jq. Avoids `claude mcp list` because
# that command spawns every registered MCP to verify connectivity, and some
# servers (serena) open a localhost dashboard window on launch (user report
# 2026-05-06: probing the dashboard opened http://127.0.0.1:24282 in browser).
_is_mcp_registered() {
    local name="$1"
    local cfg="$HOME/.claude.json"
    [[ -f "$cfg" ]] || return 1
    command -v jq &>/dev/null || return 1
    jq -e --arg n "$name" '.mcpServers // {} | has($n)' "$cfg" >/dev/null 2>&1
}

probe_serena() {
    local installed="" latest="" registered=0
    _is_mcp_registered "serena" && registered=1
    if command -v uv &>/dev/null; then
        # `uv tool list` emits "serena-agent v1.2.0" — strip the leading 'v'
        # so equality vs PyPI's "1.2.0" works (user report 2026-05-06: dashboard
        # claimed serena outdated immediately after upgrade because v-prefix
        # broke comparison).
        installed=$(uv tool list 2>/dev/null \
            | awk '/^serena-agent/ {print $2; exit}' \
            | tr -d '\n' \
            | sed 's/^v//')
    fi
    # Serena-MCP registered but the underlying serena-agent is missing from
    # uv. Show "agent-missing" so the dashboard surfaces actionable state
    # (the MCP entry will fail-to-connect at runtime until the agent is
    # installed via `uv tool install -p 3.13 serena-agent@latest`).
    if [[ -z "$installed" && "$registered" -eq 1 ]]; then
        installed="agent-missing"
    fi
    if command -v gh &>/dev/null; then
        # PyPI exposes JSON metadata; fetch via gh-style GET → fallback to
        # python urllib if curl is RTK-rewritten. For MVP just use python3.
        if command -v python3 &>/dev/null; then
            latest=$(python3 -c "
import json, urllib.request
try:
    with urllib.request.urlopen('https://pypi.org/pypi/serena-agent/json', timeout=3) as r:
        print(json.load(r).get('info', {}).get('version', ''))
except Exception:
    pass
" 2>/dev/null)
        fi
    fi
    printf '%s\t%s\n' "${installed:-—}" "${latest:-?}"
}

upgrade_serena() {
    if ! command -v uv &>/dev/null; then
        echo "uv not on PATH (serena distributed via uv tool)" >&2
        return 1
    fi
    # If the agent is missing, the upgrade-action becomes a fresh install.
    if ! uv tool list 2>/dev/null | grep -q '^serena-agent'; then
        uv tool install -p 3.13 serena-agent@latest --prerelease=allow
    else
        uv tool upgrade serena-agent --prerelease=allow
    fi
}

# claude-context — Zilliz vector-DB semantic code search MCP. Distributed
# via npx (auto-rolling on every CC restart), so the dashboard shows it as
# `↻ rolling` and the upgrade action is a no-op informational message.
probe_claude_context() {
    local installed="" latest=""
    if _is_mcp_registered "claude-context"; then
        # npx auto-resolves "@latest" on each invocation, but the most-recent
        # cached copy lives under ~/.npm/_npx/<hash>/node_modules/<pkg>. Pick
        # the newest matching package.json by mtime and read its version.
        local newest pkg_json
        newest=""
        for pkg_json in "$HOME"/.npm/_npx/*/node_modules/@zilliz/claude-context-mcp/package.json; do
            [[ -f "$pkg_json" ]] || continue
            if [[ -z "$newest" || "$pkg_json" -nt "$newest" ]]; then
                newest="$pkg_json"
            fi
        done
        if [[ -n "$newest" ]] && command -v jq &>/dev/null; then
            installed=$(jq -r '.version // empty' "$newest" 2>/dev/null)
        fi
        # Registered but never invoked yet — npx hasn't cached it.
        [[ -z "$installed" ]] && installed="not-cached"
    fi
    if command -v npm &>/dev/null; then
        latest=$(npm view "@zilliz/claude-context-mcp" version 2>/dev/null | tr -d '\n')
    fi
    printf '%s\t%s\n' "${installed:-—}" "${latest:-?}"
}

upgrade_claude_context() {
    if ! command -v npx &>/dev/null; then
        echo "npx not on PATH" >&2
        return 1
    fi
    echo "Pre-warming npx cache for @zilliz/claude-context-mcp@latest..."
    npx -y @zilliz/claude-context-mcp@latest --version >/dev/null 2>&1 || true
    echo "Done. Restart Claude Code to load the new version."
}

# ───────── register all deps ─────────
# Note: the 4 anthropic-shipped plugins (code-review, commit-commands,
# security-guidance, frontend-design) intentionally NOT registered here —
# they have no public version metadata (rolling main-branch tracking) and
# their `claude plugin list` output reports "unknown". Showing them in the
# dashboard would just be noise — Claude Code refreshes them automatically
# on plugin sync.

register_dep "toolkit"          "Toolkit"   probe_toolkit          upgrade_toolkit          "Run /update-toolkit inside Claude Code"
register_dep "superpowers"      "Bootstrap" probe_superpowers      upgrade_superpowers      "Anthropic plugin marketplace"
register_dep "get-shit-done"    "Bootstrap" probe_gsd              upgrade_gsd              "Standalone curl installer"
register_dep "ru-text"          "Bootstrap" probe_ru_text          upgrade_ru_text          ""
register_dep "caveman"          "Optional"  probe_caveman          upgrade_caveman          ""
register_dep "cc-safety-net"    "External"  probe_cc_safety_net    upgrade_cc_safety_net    "PreToolUse danger blocker"
register_dep "rtk"              "External"  probe_rtk              upgrade_rtk              "Token optimizer (brew)"
register_dep "better-model"     "External"  probe_better_model     upgrade_better_model     "Cost routing"
register_dep "get-shit-done-cc" "External"  probe_gsd_sdk          upgrade_gsd_sdk          "GSD SDK CLI helper"
register_dep "serena"           "MCP"       probe_serena           upgrade_serena           "LSP code search/refactor (uv tool serena-agent)"
register_dep "claude-context"   "MCP"       probe_claude_context   upgrade_claude_context   "Vector-DB semantic search (npx)"

# ───────── --check single-dep ─────────

if [[ -n "$CHECK_ONE" ]]; then
    for ((i=0; i<${#DEP_NAME[@]}; i++)); do
        if [[ "${DEP_NAME[$i]}" == "$CHECK_ONE" ]]; then
            "${DEP_PROBE[$i]}"
            exit 0
        fi
    done
    echo "unknown dep: $CHECK_ONE" >&2
    exit 2
fi

# ───────── header ─────────

echo -e "${CYAN}Claude Code Toolkit — Dependency Update Dashboard${NC}"
local_build_date=""
[[ -f "$SCRIPT_DIR/../manifest.json" ]] && command -v jq &>/dev/null \
    && local_build_date=$(jq -r '.updated // ""' "$SCRIPT_DIR/../manifest.json" 2>/dev/null)
local_cc_ver=""
command -v claude &>/dev/null && local_cc_ver=$(claude --version 2>/dev/null | head -1)
[[ -n "$local_build_date" || -n "$local_cc_ver" ]] && \
    echo -e "${DIM}Toolkit build date: ${local_build_date:-?} · CC: ${local_cc_ver:-?}${NC}"
unset local_build_date local_cc_ver
echo ""
echo -e "${DIM}Probing installed and latest versions...${NC}"

# ───────── probe everything ─────────

ROW_NAME=()
ROW_LAYER=()
ROW_INSTALLED=()
ROW_LATEST=()
ROW_STATUS=()    # "outdated" | "current" | "unknown" | "missing"
ROW_NOTE=()
ROW_UPGRADE_FN=()

for ((i=0; i<${#DEP_NAME[@]}; i++)); do
    out=$("${DEP_PROBE[$i]}" 2>/dev/null || printf '?\t?\n')
    inst=$(printf '%s' "$out" | cut -f1)
    lat=$(printf '%s'  "$out" | cut -f2)

    # Hide rows the user has not installed locally OR rolling-update plugins
    # with no version metadata (— or unknown).
    if [[ "$inst" == "?" || "$inst" == "—" || "$inst" == "unknown" || -z "$inst" ]]; then
        continue
    fi

    # Special status mapping:
    #   inst="rolling"        — npx-based MCPs that re-fetch on each invocation;
    #                           no manual upgrade applies, status="rolling".
    #   inst="agent-missing"  — MCP registered but its underlying agent (e.g.
    #                           serena-agent via uv) is not installed → action
    #                           needed; status="outdated" (the upgrade fn will
    #                           run a fresh install).
    if [[ "$inst" == "rolling" ]]; then
        status="rolling"
    elif [[ "$inst" == "agent-missing" ]]; then
        status="outdated"
    elif [[ "$lat" == "—" || "$lat" == "?" || -z "$lat" ]]; then
        status="unknown"
    else
        # Normalize before equality: strip leading 'v' from both sides so
        # "v1.2.0" == "1.2.0" (uv tool list emits v-prefix).
        _inst_norm="${inst#v}"
        _lat_norm="${lat#v}"
        if [[ "$_inst_norm" == "$_lat_norm" ]]; then
            status="current"
        else
            status="outdated"
        fi
    fi

    ROW_NAME+=("${DEP_NAME[$i]}")
    ROW_LAYER+=("${DEP_LAYER[$i]}")
    ROW_INSTALLED+=("$inst")
    ROW_LATEST+=("$lat")
    ROW_STATUS+=("$status")
    ROW_NOTE+=("${DEP_NOTES[$i]}")
    ROW_UPGRADE_FN+=("${DEP_UPGRADE[$i]}")
done

ROW_COUNT=${#ROW_NAME[@]}

# ───────── compute column widths ─────────

W_NAME=3   # "DEP"
W_INST=9   # "INSTALLED"
W_LAT=6    # "LATEST"
for ((i=0; i<ROW_COUNT; i++)); do
    [[ ${#ROW_NAME[$i]}      -gt $W_NAME ]] && W_NAME=${#ROW_NAME[$i]}
    [[ ${#ROW_INSTALLED[$i]} -gt $W_INST ]] && W_INST=${#ROW_INSTALLED[$i]}
    [[ ${#ROW_LATEST[$i]}    -gt $W_LAT  ]] && W_LAT=${#ROW_LATEST[$i]}
done

# ───────── count outdated (used by both static + interactive paths) ─────────

OUTDATED_COUNT=0
for s in "${ROW_STATUS[@]}"; do
    [[ "$s" == "outdated" ]] && OUTDATED_COUNT=$((OUTDATED_COUNT + 1))
done

# ───────── render helpers ─────────

# Picks the right colored status token for a given row. Reused by both the
# static table (--dry-run / final summary) and the interactive picker.
_status_token() {
    case "$1" in
        outdated)  printf '%b↑ update%b' "$YELLOW" "$NC" ;;
        current)   printf '%b✓ up-to-date%b' "$GREEN" "$NC" ;;
        rolling)   printf '%b↻ auto%b' "$DIM" "$NC" ;;
        unknown)   printf '%b? unknown%b' "$DIM" "$NC" ;;
        *)         printf '%b—%b' "$DIM" "$NC" ;;
    esac
}

# Static table — used by --dry-run AND printed AFTER an interactive session
# (so the user sees a record of what they picked even after the alt screen
# closes). When `mode=picker-final` the [x] / [ ] checkboxes from the last
# selection are rendered too.
_render_static_table() {
    local mode="${1:-plain}"
    printf "  %-${W_NAME}s   %-${W_INST}s   %-${W_LAT}s   %s\n" "DEP" "INSTALLED" "LATEST" "STATUS"
    printf '  %s\n' "$(printf -- '─%.0s' $(seq 1 $((W_NAME + W_INST + W_LAT + 30))))"
    local last_layer="" r note sym box prefix
    for ((r=0; r<ROW_COUNT; r++)); do
        if [[ "${ROW_LAYER[$r]}" != "$last_layer" ]]; then
            [[ -n "$last_layer" ]] && echo ""
            echo -e "  ${BLUE}${ROW_LAYER[$r]}${NC}"
            last_layer="${ROW_LAYER[$r]}"
        fi
        sym=$(_status_token "${ROW_STATUS[$r]}")
        note=""
        [[ -n "${ROW_NOTE[$r]}" ]] && note="${DIM}  ${ROW_NOTE[$r]}${NC}"
        if [[ "$mode" == "picker-final" ]]; then
            box=" "
            [[ "${SELECTED[$r]:-0}" -eq 1 ]] && box="x"
            prefix="  [$box] "
        else
            prefix="  "
        fi
        printf "%s%-${W_NAME}s   %-${W_INST}s   %-${W_LAT}s   %b%b\n" \
            "$prefix" "${ROW_NAME[$r]}" "${ROW_INSTALLED[$r]}" "${ROW_LATEST[$r]}" "$sym" "$note"
    done
}

# Interactive checkbox picker — alt-screen, ↑↓ navigate, Space toggle, Enter
# submit, a/o/n bulk shortcuts, Ctrl+C abort. Pre-fills SELECTED[i]=1 for
# every row already flagged "outdated" (saves a keystroke). Reads keys from
# /dev/tty so the script can also be invoked via curl|bash without breaking
# stdin.
_interactive_picker() {
    if [[ ! -e /dev/tty ]]; then
        echo "no /dev/tty — interactive picker unavailable" >&2
        return 2
    fi
    local focus=0 key rest j picked
    # Pre-select outdated rows.
    for ((j=0; j<ROW_COUNT; j++)); do
        if [[ "${ROW_STATUS[$j]}" == "outdated" ]]; then
            SELECTED[$j]=1
        fi
    done

    # Enter alt-screen + hide cursor. Restore on RETURN.
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    # shellcheck disable=SC2317
    _picker_cleanup() {
        tput cnorm 2>/dev/null || true
        tput rmcup 2>/dev/null || true
    }
    trap '_picker_cleanup; trap - INT; exit 130' INT

    # One-shot clear on entry. Subsequent iterations only home + per-line
    # erase so the screen does not flicker on every key press.
    printf '\033[2J\033[H'

    while true; do
        # Move cursor home WITHOUT clearing screen — `\033[2J` followed by
        # rewriting causes a visible blank-then-paint flicker on every key
        # press (user report 2026-05-06: ↑/↓ caused visible blink). Instead
        # we overprint each row in place and append `\033[K` (erase to end
        # of line) so no stale chars remain. After the last row we emit
        # `\033[J` to clear any leftover lines from a previous taller render.
        printf '\033[H'
        printf "%b%b%s\n" "${CYAN}Choose what to upgrade${NC}    ${DIM}↑↓ navigate · Space toggle · Enter submit · a/o/n bulk · Ctrl+C abort${NC}" "" $'\033[K'
        printf '%s\n' $'\033[K'
        printf "      %-${W_NAME}s   %-${W_INST}s   %-${W_LAT}s   %s%s\n" "DEP" "INSTALLED" "LATEST" "STATUS" $'\033[K'
        printf '      %s%s\n' "$(printf -- '─%.0s' $(seq 1 $((W_NAME + W_INST + W_LAT + 30))))" $'\033[K'
        local last_layer="" r sym note box marker
        for ((r=0; r<ROW_COUNT; r++)); do
            if [[ "${ROW_LAYER[$r]}" != "$last_layer" ]]; then
                if [[ -n "$last_layer" ]]; then
                    printf '%s\n' $'\033[K'
                fi
                printf "      %b%s%b%s\n" "${BLUE}" "${ROW_LAYER[$r]}" "${NC}" $'\033[K'
                last_layer="${ROW_LAYER[$r]}"
            fi
            sym=$(_status_token "${ROW_STATUS[$r]}")
            note=""
            [[ -n "${ROW_NOTE[$r]}" ]] && note="${DIM}  ${ROW_NOTE[$r]}${NC}"
            box=" "
            [[ "${SELECTED[$r]:-0}" -eq 1 ]] && box="x"
            if [[ "$r" -eq "$focus" ]]; then
                marker="  ${CYAN}▶${NC} "
            else
                marker="    "
            fi
            printf "%b[%s] %-${W_NAME}s   %-${W_INST}s   %-${W_LAT}s   %b%b%s\n" \
                "$marker" "$box" "${ROW_NAME[$r]}" "${ROW_INSTALLED[$r]}" "${ROW_LATEST[$r]}" "$sym" "$note" $'\033[K'
        done
        picked=0
        for s in "${SELECTED[@]}"; do
            [[ "$s" -eq 1 ]] && picked=$((picked + 1))
        done
        printf '%s\n' $'\033[K'
        printf "  %b%s%b%s\n" "${CYAN}" "Selected: ${picked} of ${ROW_COUNT}" "${NC}" $'\033[K'
        printf '%s\n' $'\033[K'
        # Action footer — explicit visual buttons. Enter triggers Update on
        # whatever is currently picked; q exits without changes.
        local _btn_update _btn_exit
        if [[ $picked -gt 0 ]]; then
            _btn_update="${GREEN}[ Update (Enter) ]${NC}"
        else
            _btn_update="${DIM}[ Update (Enter) ]${NC}"
        fi
        _btn_exit="${YELLOW}[ Exit (q) ]${NC}"
        printf "  %b    %b%s\n" "$_btn_update" "$_btn_exit" $'\033[K'
        # Erase any leftover lines from a previous taller render.
        printf '\033[J'

        # Read 1 char. Arrow keys arrive as Esc + '[' + 'A'/'B'.
        IFS= read -rsn1 key </dev/tty
        case "$key" in
            $'\033')
                # Arrow keys send 3-byte sequence: ESC + '[' + 'A'/'B'/'C'/'D'
                # (xterm/normal mode) OR ESC + 'O' + 'A'/'B'/'C'/'D' (application
                # cursor mode used by some macOS terminal apps).
                #
                # CRITICAL: Bash 3.2 (macOS default `/bin/bash`) does NOT
                # support fractional `-t` timeouts. `read -t 0.3` is invalid
                # and fails immediately, so the `[A` bytes leak to the next
                # loop iteration where 'A' matches the select-all branch.
                # User report 2026-05-06: ↑ flipped every row to [x]; ↓ no-op.
                #
                # Fix: read exactly 2 follow-up bytes with integer 1 s
                # timeout. Arrow sequences arrive in <10 ms so 1 s never
                # fires for legit keys; bare ESC blocks 1 s then no-ops
                # (use 'q' or Ctrl+C to cancel).
                local _seq=""
                IFS= read -rsn2 -t 1 _seq </dev/tty 2>/dev/null || true
                case "$_seq" in
                    "[A"|"OA") ((focus > 0)) && focus=$((focus - 1)) ;;
                    "[B"|"OB") ((focus < ROW_COUNT - 1)) && focus=$((focus + 1)) ;;
                    # Empty / unknown → no-op
                esac
                unset _seq
                ;;
            " ")
                if [[ "${SELECTED[$focus]:-0}" -eq 1 ]]; then
                    SELECTED[$focus]=0
                else
                    SELECTED[$focus]=1
                fi
                ;;
            "")
                # Enter — submit
                break
                ;;
            "a"|"A")
                for ((j=0; j<ROW_COUNT; j++)); do SELECTED[$j]=1; done
                ;;
            "o"|"O")
                for ((j=0; j<ROW_COUNT; j++)); do
                    if [[ "${ROW_STATUS[$j]}" == "outdated" ]]; then
                        SELECTED[$j]=1
                    else
                        SELECTED[$j]=0
                    fi
                done
                ;;
            "n"|"N")
                for ((j=0; j<ROW_COUNT; j++)); do SELECTED[$j]=0; done
                ;;
            "q"|"Q")
                _picker_cleanup
                trap - INT
                echo "Cancelled."
                exit 0
                ;;
        esac
    done

    _picker_cleanup
    trap - INT
    return 0
}

# ───────── render OR pick depending on mode ─────────

# Build SELECTED[i]=0 array up front. _interactive_picker pre-fills outdated
# rows; --yes path fills outdated explicitly; --dry-run never touches it.
SELECTED=()
for ((i=0; i<ROW_COUNT; i++)); do
    SELECTED+=("0")
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    _render_static_table plain
    echo ""
    echo -e "${DIM}(--dry-run — not updating)${NC}"
    exit 0
fi

if [[ "$YES" -eq 1 ]]; then
    echo ""
    _render_static_table plain
    echo ""
    echo -e "${CYAN}--yes: updating every outdated dep...${NC}"
    for ((i=0; i<ROW_COUNT; i++)); do
        [[ "${ROW_STATUS[$i]}" == "outdated" ]] && SELECTED[$i]=1
    done
else
    _interactive_picker
    # After the picker exits, alt-screen is restored. Re-render the table
    # with [x] / [ ] checkboxes so the user sees what they picked.
    echo ""
    echo -e "${CYAN}Selection:${NC}"
    echo ""
    _render_static_table picker-final
    echo ""
fi

# ───────── tally selection ─────────

PICKED=0
for s in "${SELECTED[@]}"; do
    [[ "$s" -eq 1 ]] && PICKED=$((PICKED + 1))
done

if [[ $PICKED -eq 0 ]]; then
    echo "Nothing selected. Exiting."
    exit 0
fi

# ───────── execute ─────────

echo ""
echo -e "${CYAN}Upgrading ${PICKED} dep$([ "$PICKED" = "1" ] || echo "s")...${NC}"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
RESULT_LINES=()

for ((i=0; i<ROW_COUNT; i++)); do
    if [[ "${SELECTED[$i]}" -ne 1 ]]; then
        continue
    fi
    name="${ROW_NAME[$i]}"
    fn="${ROW_UPGRADE_FN[$i]}"
    echo -e "${BLUE}→ ${name}${NC}"
    if "$fn"; then
        RESULT_LINES+=("  ${GREEN}✓${NC} ${name}")
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        rc=$?
        RESULT_LINES+=("  ${RED}✗${NC} ${name} (exit $rc)")
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
done

# ───────── summary ─────────

echo ""
echo -e "${CYAN}Update summary:${NC}"
echo ""
for line in "${RESULT_LINES[@]}"; do
    echo -e "$line"
done
echo ""
printf 'Upgraded: %d · Failed: %d\n' "$PASS_COUNT" "$FAIL_COUNT"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
