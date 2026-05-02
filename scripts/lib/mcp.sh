#!/bin/bash

# Claude Code Toolkit — MCP Catalog Loader + Detection + Wizard (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes (Plan 01):
#   mcp_catalog_load           — parses scripts/lib/mcp-catalog.json into MCP_* arrays
#   mcp_catalog_names          — prints 9 names one-per-line (alpha sorted)
#   is_mcp_installed <name>    — returns 0 (installed) / 1 (not installed) / 2 (claude CLI absent)
# Exposes (Plan 02):
#   mcp_secrets_load           — populates MCP_SECRET_KEYS[] MCP_SECRET_VALUES[] from mcp-config.env
#   mcp_secrets_set <KEY> <V>  — append/overwrite KEY=V in mcp-config.env (mode 0600)
#   mcp_wizard_run <name> [--dry-run] — per-MCP install wizard (hidden input + claude mcp add)
# Globals (write, Plan 01):
#   MCP_NAMES[]            — 9 catalog keys (alpha order)
#   MCP_DISPLAY[]          — display_name strings (parallel to MCP_NAMES)
#   MCP_ENV_KEYS[]         — env-var names joined with ';' (empty string = zero-config)
#   MCP_INSTALL_ARGS[]     — install_args[] joined with $'\037' (unit-separator) for safe split
#   MCP_DESCS[]            — description strings (parallel)
#   MCP_OAUTH[]            — 0/1 ints (parallel)
# Globals (write, Phase 34-01):
#   MCP_CATEGORY[]         — entry's category (parallel; e.g. "backend", "docs-research")
#   MCP_HAS_CLI[]          — 0/1 — 1 if components.cli.<name> block present in catalog
#   MCP_UNOFFICIAL[]       — 0/1 — 1 if components.mcp.<name>.unofficial == true
#   MCP_CLI_DETECT[]       — `detect_cmd` from components.cli (empty when MCP_HAS_CLI=0)
#   CATEGORIES_ORDER[]     — canonical ordered list from .categories[] in the catalog
#   MCP_STATUS[]           — "installed"|"absent"|"unknown" (per-entry MCP install state)
#   CLI_STATUS[]           — "installed"|"absent"|"na" (per-entry companion CLI state)
# Globals (write, Plan 02):
#   MCP_SECRET_KEYS[]      — keys from mcp-config.env (parallel to MCP_SECRET_VALUES)
#   MCP_SECRET_VALUES[]    — values from mcp-config.env
# Test seams:
#   TK_MCP_CLAUDE_BIN          — override path to claude binary (mocked in tests)
#   TK_MCP_CATALOG_PATH        — override path to mcp-catalog.json (mocked in tests)
#   TK_MCP_TTY_SRC             — override /dev/tty for wizard read prompts (Plan 02)
#   TK_MCP_CONFIG_HOME         — override $HOME for mcp-config.env path resolution (Plan 02)
#   TK_INTEGRATIONS_TTY_SRC    — override /dev/tty for unofficial_confirm prompts (Phase 34-02)
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
# shellcheck disable=SC2034
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
# shellcheck disable=SC2034
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
# shellcheck disable=SC2034
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'

# Internal helper — resolves sibling integrations-catalog.json path from BASH_SOURCE.
# Phase 32-01 (CAT-01): catalog renamed mcp-catalog.json → integrations-catalog.json
# to make room for non-MCP component types (skills, plugins, statuslines) under
# components.<type>.<name>. Public function names (mcp_catalog_load, etc.) are
# unchanged — only the on-disk filename and internal jq paths moved.
_mcp_default_catalog_path() {
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
    echo "${d}/integrations-catalog.json"
}

# Lazy-source tui.sh so tui_tty_read is available for the wizard prompts. The
# wizard runs under install.sh's `( … ) 2>"$stderr_tmp"` dispatch wrapper
# (install.sh:401-405), so any `read -p "..."` would write the prompt to a
# captured stderr stream and the user would see only a blinking cursor.
if ! command -v tui_tty_read >/dev/null 2>&1; then
    _MCP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_MCP_LIB_DIR}/tui.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_MCP_LIB_DIR}/tui.sh"
    fi
fi

# mcp_catalog_load — parse mcp-catalog.json into six parallel arrays.
# Populates MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH.
# Returns 1 if catalog is missing or jq is absent.
mcp_catalog_load() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
    if [[ ! -f "$catalog_path" ]]; then
        echo -e "${RED}✗${NC} integrations-catalog.json not found at $catalog_path" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} jq required for mcp_catalog_load" >&2
        return 1
    fi
    # shellcheck disable=SC2034
    MCP_NAMES=()
    # shellcheck disable=SC2034
    MCP_DISPLAY=()
    # shellcheck disable=SC2034
    MCP_ENV_KEYS=()
    # shellcheck disable=SC2034
    MCP_INSTALL_ARGS=()
    # shellcheck disable=SC2034
    MCP_DESCS=()
    # shellcheck disable=SC2034
    MCP_OAUTH=()
    # Phase 34-01: parallel arrays for category grouping + component metadata.
    # shellcheck disable=SC2034
    MCP_CATEGORY=()
    # shellcheck disable=SC2034
    MCP_HAS_CLI=()
    # shellcheck disable=SC2034
    MCP_UNOFFICIAL=()
    # shellcheck disable=SC2034
    MCP_CLI_DETECT=()
    local name
    while IFS= read -r name; do
        # shellcheck disable=SC2034
        MCP_NAMES+=("$name")
        # shellcheck disable=SC2034
        MCP_DISPLAY+=("$(jq -r --arg n "$name" '.components.mcp[$n].display_name' "$catalog_path")")
        # shellcheck disable=SC2034
        MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.components.mcp[$n].env_var_keys | join(";")' "$catalog_path")")
        # Use $'\037' (unit separator, ASCII 31) to join install_args[] — survives spaces in args.
        # shellcheck disable=SC2034
        MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '[.components.mcp[$n].install_args[] ] | join("")' "$catalog_path")")
        # shellcheck disable=SC2034
        MCP_DESCS+=("$(jq -r --arg n "$name" '.components.mcp[$n].description' "$catalog_path")")
        if [[ "$(jq -r --arg n "$name" '.components.mcp[$n].requires_oauth' "$catalog_path")" == "true" ]]; then
            # shellcheck disable=SC2034
            MCP_OAUTH+=(1)
        else
            # shellcheck disable=SC2034
            MCP_OAUTH+=(0)
        fi

        # Phase 34-01: category (default empty string when missing for back-compat
        # with v4.6 schema-v1 catalogs that lack the `category` field).
        # shellcheck disable=SC2034
        MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // ""' "$catalog_path")")

        # Phase 34-01: unofficial flag (default 0; 1 only when set true).
        if [[ "$(jq -r --arg n "$name" '.components.mcp[$n].unofficial // false' "$catalog_path")" == "true" ]]; then
            # shellcheck disable=SC2034
            MCP_UNOFFICIAL+=(1)
        else
            # shellcheck disable=SC2034
            MCP_UNOFFICIAL+=(0)
        fi

        # Phase 34-01: CLI presence + detect_cmd. components.cli.<name> may be absent.
        # `// empty` exits jq with no output when the path doesn't exist; capture and
        # branch instead of relying on the brittle "null" string from `// null`.
        local _cli_detect
        _cli_detect="$(jq -r --arg n "$name" '.components.cli[$n].detect_cmd // empty' "$catalog_path")"
        if [[ -n "$_cli_detect" ]]; then
            # shellcheck disable=SC2034
            MCP_HAS_CLI+=(1)
            # shellcheck disable=SC2034
            MCP_CLI_DETECT+=("$_cli_detect")
        else
            # shellcheck disable=SC2034
            MCP_HAS_CLI+=(0)
            # shellcheck disable=SC2034
            MCP_CLI_DETECT+=("")
        fi
    done < <(jq -r '.components.mcp | keys | sort | .[]' "$catalog_path")
}

# mcp_categories_load — populate CATEGORIES_ORDER[] from the catalog's
# top-level `.categories[]` array (canonical order — Phase 33 D-06).
# Side-effects: writes CATEGORIES_ORDER. Safe to call before mcp_catalog_load.
# Returns 1 if catalog missing or jq absent (matches mcp_catalog_load contract).
mcp_categories_load() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
    if [[ ! -f "$catalog_path" ]]; then
        echo -e "${RED}✗${NC} integrations-catalog.json not found at $catalog_path" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} jq required for mcp_categories_load" >&2
        return 1
    fi
    # shellcheck disable=SC2034
    CATEGORIES_ORDER=()
    local cat
    while IFS= read -r cat; do
        [[ -z "$cat" ]] && continue
        # shellcheck disable=SC2034
        CATEGORIES_ORDER+=("$cat")
    done < <(jq -r '.categories[]? // empty' "$catalog_path")
}

# _mcp_category_display — title-case a kebab-case category key for the
# section header (e.g. "docs-research" -> "Docs Research").
# Bash 3.2: no `${var,,}` / `${var^^}`. Use `tr` + per-word capitalisation
# via parameter expansion of the first byte.
_mcp_category_display() {
    local key="${1:-}"
    [[ -z "$key" ]] && { echo ""; return 0; }
    local out="" word first rest
    local IFS_SAVED="$IFS"
    IFS='-'
    # shellcheck disable=SC2206
    local words=( $key )
    IFS="$IFS_SAVED"
    for word in "${words[@]+"${words[@]}"}"; do
        [[ -z "$word" ]] && continue
        word=$(printf '%s' "$word" | tr '[:upper:]' '[:lower:]')
        first="${word:0:1}"
        rest="${word:1}"
        first=$(printf '%s' "$first" | tr '[:lower:]' '[:upper:]')
        if [[ -z "$out" ]]; then
            out="${first}${rest}"
        else
            out="${out} ${first}${rest}"
        fi
    done
    echo "$out"
}

# mcp_status_detect — populate per-component status arrays.
# Globals (write):
#   MCP_STATUS[]   — "installed"|"absent"|"unknown" (parallel to MCP_NAMES)
#   CLI_STATUS[]   — "installed"|"absent"|"na" (parallel; "na" = entry has no CLI)
# Reads MCP_NAMES[] / MCP_HAS_CLI[] / MCP_CLI_DETECT[] (must be loaded first).
# MCP detect uses the cached `claude mcp list` (single CLI call per shell).
# CLI detect uses `command -v <detect_cmd>` (sub-millisecond — no caching).
# Runs ONCE per TUI launch; not per render frame (D-11 / TUI-02).
mcp_status_detect() {
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi
    # shellcheck disable=SC2034
    MCP_STATUS=()
    # shellcheck disable=SC2034
    CLI_STATUS=()
    _mcp_list_cache_init
    local mcp_unknown=0
    case "${_MCP_LIST_CACHED:-}" in
        __no_cli__|__list_failed__) mcp_unknown=1 ;;
    esac
    local i name detect rc
    for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
        name="${MCP_NAMES[$i]}"
        if [[ "$mcp_unknown" -eq 1 ]]; then
            # shellcheck disable=SC2034
            MCP_STATUS+=("unknown")
        else
            rc=0
            is_mcp_installed "$name" || rc=$?
            case "$rc" in
                0)  # shellcheck disable=SC2034
                    MCP_STATUS+=("installed") ;;
                1)  # shellcheck disable=SC2034
                    MCP_STATUS+=("absent") ;;
                *)  # shellcheck disable=SC2034
                    MCP_STATUS+=("unknown") ;;
            esac
        fi

        if [[ "${MCP_HAS_CLI[$i]:-0}" == "1" ]]; then
            detect="${MCP_CLI_DETECT[$i]:-}"
            if [[ -n "$detect" ]] && command -v "$detect" >/dev/null 2>&1; then
                # shellcheck disable=SC2034
                CLI_STATUS+=("installed")
            else
                # shellcheck disable=SC2034
                CLI_STATUS+=("absent")
            fi
        else
            # shellcheck disable=SC2034
            CLI_STATUS+=("na")
        fi
    done
}

# unofficial_confirm <display_name> — Phase 34-02 (TUI-03) — gate install of an
# entry whose `unofficial: true` flag is set. Reads from
# ${TK_INTEGRATIONS_TTY_SRC:-/dev/tty}, fail-closed N (matches v4.3 UN-03 contract).
# Bypassed when ALWAYS_YES=1 (set by --yes path).
# Returns:
#   0 — user said yes (or --yes bypass) — install allowed
#   1 — user said no / EOF / no readable TTY — install must be skipped
unofficial_confirm() {
    local display="${1:-this entry}"
    local tty_src="${TK_INTEGRATIONS_TTY_SRC:-/dev/tty}"

    # --yes bypass. The exported flag from install.sh is also accepted as
    # ALWAYS_YES=1 for symmetry with bridge/bootstrap precedents.
    if [[ "${ALWAYS_YES:-0}" == "1" ]]; then
        return 0
    fi

    # Audit the TTY source. Fail-closed N when unreadable (no-TTY CI runs and
    # the TUI guard at install.sh:398 already ensures interactive TTY is wired
    # by the time we reach here).
    if [[ ! -r "$tty_src" ]]; then
        return 1
    fi

    # Print warning + prompt. Use stderr so install.sh's `( wizard ) 2>"$tmp"`
    # capture wrappers don't swallow the question silently.
    if [ -t 2 ] && [ -z "${NO_COLOR+x}" ]; then
        printf '\n%b!%b %s is community-maintained / browser-automation.\nInstall anyway? [y/N] ' \
            "${YELLOW}" "${NC}" "$display" >&2
    else
        printf '\n[!] %s is community-maintained / browser-automation.\nInstall anyway? [y/N] ' \
            "$display" >&2
    fi

    local reply=""
    if ! IFS= read -r reply <"$tty_src" 2>/dev/null; then
        reply=""
    fi
    case "$reply" in
        y|Y|yes|YES|Yes) return 0 ;;
        *)               return 1 ;;
    esac
}

# print_integrations_summary — Phase 34-03 (TUI-05) — per-entry × per-component
# install summary table. Renders after the dispatch loop completes. Mirrors
# Phase 25 D-28 contract (Entry | MCP | CLI | Notes).
#
# Reads parallel arrays (caller must populate):
#   RESULT_NAMES[]     — entry name (parallel index)
#   RESULT_MCP_STATE[] — one of: installed | installed:needs-key | already |
#                                 would-install | skipped:<reason> |
#                                 failed:exit-N: <stderr-line> | na | unknown
#   RESULT_CLI_STATE[] — same set, plus "na" for entries without CLI block
#
# Writes:
#   Stdout — formatted table + total line.
#
# Glyphs (per D-22):
#   ✓ installed (green)
#   ⊘ already   (cyan)
#   ✗ failed    (red, with truncated reason in Notes column)
#   ⊘ skipped   (yellow, with reason in Notes)
#   —           (n/a, neutral)
#   ?           (unknown — defensive fallback)
#
# Total line (per D-24):
#   Installed: N MCPs, M CLIs | Skipped: X | Failed: Y
print_integrations_summary() {
    # Bash 3.2: `${#var[@]:-0}` is rejected as bad substitution; use existence
    # test mirroring tui.sh:164.
    if [[ -z "${RESULT_NAMES[*]+x}" ]] || [[ "${#RESULT_NAMES[@]}" -eq 0 ]]; then
        return 0
    fi

    # NO_COLOR-aware code resolution (no-color.org semantics).
    local _g="" _c="" _y="" _r="" _b="" _bold="" _nc=""
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _g=$'\033[0;32m'
        _c=$'\033[0;36m'
        _y=$'\033[1;33m'
        _r=$'\033[0;31m'
        _b=$'\033[0;34m'
        _bold=$'\033[1m'
        _nc=$'\033[0m'
    fi

    # Header — single empty line above + bold blue title to separate from the
    # legacy MCP install summary block.
    echo ""
    printf '%b━━━ Integrations Install Summary ━━━%b\n' "$_b" "$_nc"
    printf '%-28s %-14s %-14s %s\n' "Entry" "MCP" "CLI" "Notes"
    printf '%-28s %-14s %-14s %s\n' \
        "────────────────────────────" "──────────────" "──────────────" "─────"

    local installed_mcp=0 installed_cli=0 skipped=0 failed=0
    local i name mcp cli mcp_glyph cli_glyph notes mcp_reason cli_reason

    for ((i=0; i<${#RESULT_NAMES[@]}; i++)); do
        name="${RESULT_NAMES[$i]}"
        mcp="${RESULT_MCP_STATE[$i]:-unknown}"
        cli="${RESULT_CLI_STATE[$i]:-na}"
        mcp_reason=""
        cli_reason=""

        # MCP cell — case-match on prefix to handle compound states like
        # "skipped:claude-unavailable" / "failed:exit-2: error msg".
        case "$mcp" in
            installed)
                mcp_glyph="${_g}✓${_nc}"
                installed_mcp=$((installed_mcp + 1))
                ;;
            installed:needs-key)
                mcp_glyph="${_y}✓${_nc}"
                installed_mcp=$((installed_mcp + 1))
                mcp_reason="needs API key"
                ;;
            would-install)
                mcp_glyph="${_c}·${_nc}"
                mcp_reason="would-install"
                ;;
            already)
                mcp_glyph="${_c}⊘${_nc}"
                ;;
            skipped:*)
                mcp_glyph="${_y}⊘${_nc}"
                mcp_reason="${mcp#skipped:}"
                skipped=$((skipped + 1))
                ;;
            failed:*)
                mcp_glyph="${_r}✗${_nc}"
                mcp_reason="${mcp#failed:}"
                failed=$((failed + 1))
                ;;
            na)
                mcp_glyph="—"
                ;;
            *)
                mcp_glyph="?"
                ;;
        esac

        # CLI cell — same shape.
        case "$cli" in
            installed)
                cli_glyph="${_g}✓${_nc}"
                installed_cli=$((installed_cli + 1))
                ;;
            would-install)
                cli_glyph="${_c}·${_nc}"
                cli_reason="would-install"
                ;;
            already)
                cli_glyph="${_c}⊘${_nc}"
                ;;
            skipped:*)
                cli_glyph="${_y}⊘${_nc}"
                cli_reason="${cli#skipped:}"
                skipped=$((skipped + 1))
                ;;
            failed:*)
                cli_glyph="${_r}✗${_nc}"
                cli_reason="${cli#failed:}"
                failed=$((failed + 1))
                ;;
            na)
                cli_glyph="—"
                ;;
            *)
                cli_glyph="?"
                ;;
        esac

        # Notes column — combine MCP + CLI reasons (truncate to 60 cols total).
        notes=""
        if [[ -n "$mcp_reason" && -n "$cli_reason" ]]; then
            notes="MCP: ${mcp_reason}; CLI: ${cli_reason}"
        elif [[ -n "$mcp_reason" ]]; then
            notes="$mcp_reason"
        elif [[ -n "$cli_reason" ]]; then
            notes="$cli_reason"
        fi
        if [[ "${#notes}" -gt 60 ]]; then
            notes="${notes:0:57}..."
        fi

        # %b for color codes; visible-width math compensates for the 8-byte
        # ANSI prefix/suffix on glyphs by widening the column to 14 chars
        # (vs 1-byte glyph) so plain — / ✓ / ✗ all align under both color
        # and NO_COLOR.
        printf '%-28s %-14b %-14b %s\n' "$name" "$mcp_glyph" "$cli_glyph" "$notes"
    done

    echo ""
    printf '%bInstalled:%b %d MCPs, %d CLIs · Skipped: %d · Failed: %d\n' \
        "$_bold" "$_nc" "$installed_mcp" "$installed_cli" "$skipped" "$failed"
}

# mcp_catalog_names — print all 9 catalog names, one per line, alphabetically sorted.
mcp_catalog_names() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
    jq -r '.components.mcp | keys | sort | .[]' "$catalog_path"
}

# _mcp_list_cache_init — invoke `claude mcp list` AT MOST ONCE per shell and
# memoise the output. mcp_status_array probes 9 MCPs back-to-back; without
# this cache each probe spawned a fresh `claude` process whose cold-start
# cost is ~4 s on macOS. 9 × 4 s = 40 s wall-time after the user pressed
# Submit on the main TUI, which looks identical to a hang (user report
# 2026-05-01). Memoising the call drops it to a single ~4 s round-trip.
#
# State machine via _MCP_LIST_CACHED:
#   ""               → cache cold (initial)
#   "ok"             → list captured in _MCP_LIST_CACHE_OUT
#   "__no_cli__"     → claude CLI absent on PATH and no override
#   "__list_failed__"→ CLI present but `mcp list` returned non-zero
#                      (auth missing, transient daemon error, etc.)
#
# The cache is shell-global. Tests that mock the CLI via TK_MCP_CLAUDE_BIN
# already run each scenario in a fresh `bash -c` subshell, so the cache
# resets naturally between scenarios. If a future test mutates
# TK_MCP_CLAUDE_BIN inside a single shell, it must `unset _MCP_LIST_CACHED
# _MCP_LIST_CACHE_OUT` to invalidate.
_mcp_list_cache_init() {
    [[ -n "${_MCP_LIST_CACHED:-}" ]] && return 0
    local claude_bin="${TK_MCP_CLAUDE_BIN:-}"
    if [[ -z "$claude_bin" ]] && command -v claude >/dev/null 2>&1; then
        claude_bin="claude"
    fi
    if [[ -z "$claude_bin" ]]; then
        _MCP_LIST_CACHED="__no_cli__"
        _MCP_LIST_CACHE_OUT=""
        return 0
    fi
    if _MCP_LIST_CACHE_OUT=$("$claude_bin" mcp list 2>/dev/null); then
        _MCP_LIST_CACHED="ok"
    else
        _MCP_LIST_CACHED="__list_failed__"
        _MCP_LIST_CACHE_OUT=""
    fi
    return 0
}

# is_mcp_installed <name> — three-state return (MCP-02 fail-soft contract):
#   0 = MCP is installed (found in `claude mcp list` output)
#   1 = MCP is NOT installed (CLI present but name absent)
#   2 = claude CLI absent OR `claude mcp list` failed (unknown state)
# When CLI absent, prints exactly ONE warning to stderr (global guard _MCP_CLI_WARNED).
# Backed by _mcp_list_cache_init to keep wall-time linear per shell, not per probe.
is_mcp_installed() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} is_mcp_installed: missing argument" >&2
        return 1
    fi
    _mcp_list_cache_init
    case "${_MCP_LIST_CACHED:-}" in
        __no_cli__)
            # MCP-02 fail-soft: warn once (global guard) then return 2.
            if [[ -z "${_MCP_CLI_WARNED:-}" ]]; then
                echo -e "${YELLOW}!${NC} claude CLI not found — MCP detection unavailable" >&2
                _MCP_CLI_WARNED=1
            fi
            return 2
            ;;
        __list_failed__)
            return 2
            ;;
    esac
    # Match a row that begins with "<name>" followed by ":", whitespace, or EOL.
    # `claude mcp list` output evolved across CLI versions:
    #   old: "context7    sse    https://..."           (whitespace-separated)
    #   new: "context7: npx -y @upstash/... - ✓ Conn"   (colon after name)
    # The probe must accept both. user report 2026-05-02: every MCP showed
    # MCP:✗ in the integrations TUI even though `claude mcp list` listed
    # them — root cause was the regex requiring whitespace and missing the
    # colon variant.
    #
    # Audit M-MCP: $name was interpolated into the regex without escaping. An
    # MCP entry whose registered name contains "." or "+" (both legal) would
    # match unrelated rows. Escape regex metacharacters before substitution.
    local _name_escaped
    _name_escaped=$(printf '%s' "$name" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g')
    if printf '%s\n' "${_MCP_LIST_CACHE_OUT:-}" | grep -E "^${_name_escaped}([[:space:]:]|\$)" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Secrets persistence — ~/.claude/mcp-config.env (MCP-SEC-01, MCP-SEC-02)
# ─────────────────────────────────────────────────────────────────────────────

# _mcp_config_path — resolve ~/.claude/mcp-config.env honoring TK_MCP_CONFIG_HOME test seam.
_mcp_config_path() {
    echo "${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env"
}

# _mcp_validate_value — reject values with shell metacharacters that would expand when sourced.
# Rejected: $, backtick, backslash, double-quote, single-quote, newline.
# Returns 0 if safe, 1 if rejected (caller re-prompts or errors).
_mcp_validate_value() {
    local v="$1"
    if [[ "$v" == *'$'* || "$v" == *'`'* || "$v" == *'\'* || "$v" == *'"'* || "$v" == *"'"* ]]; then
        return 1
    fi
    # Reject embedded newline (would split KEY=VALUE records).
    if [[ "$v" == *$'\n'* ]]; then
        return 1
    fi
    return 0
}

# mcp_secrets_load — populate parallel arrays MCP_SECRET_KEYS[] MCP_SECRET_VALUES[] from
# ~/.claude/mcp-config.env. Empty/absent file → both arrays length 0.
# Comments (#-prefix) and blank lines are skipped. Lines without '=' are skipped silently.
# Reads from ${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env.
# shellcheck disable=SC2034
mcp_secrets_load() {
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    local cfg
    cfg="$(_mcp_config_path)"
    if [[ ! -f "$cfg" ]]; then
        return 0
    fi
    local line key value
    while IFS= read -r line; do
        # Skip comments and blank lines.
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        # Require KEY=value form.
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        # Trim leading/trailing whitespace from key.
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        [[ -z "$key" ]] && continue
        # Audit L1: defense in depth — only accept keys shaped like real
        # POSIX env-var names (uppercase letter or underscore, then
        # alphanumeric/underscore). Rejects shell metacharacters and
        # leading digits that could later be reflected into env or
        # argv via `export "$key=..."` or `--header "$key:..."`.
        if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            continue
        fi
        MCP_SECRET_KEYS+=("$key")
        MCP_SECRET_VALUES+=("$value")
    done < "$cfg"
}

# _mcp_secrets_index — echo the 0-based index of $1 in MCP_SECRET_KEYS; returns 1 if absent.
# Requires mcp_secrets_load to have been called first.
_mcp_secrets_index() {
    local target="$1"
    local i
    for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
        if [[ "${MCP_SECRET_KEYS[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# mcp_secrets_set <KEY> <VALUE> — append or overwrite KEY=VALUE in mcp-config.env.
# Security order-of-operations (MCP-SEC-01):
#   1. mkdir -p ~/.claude
#   2. touch mcp-config.env (creates if absent)
#   3. chmod 0600 mcp-config.env (idempotent — before any write)
#   4. Load existing entries via mcp_secrets_load
#   5. If KEY already present:
#        prompt "[y/N] Overwrite KEY?" via TK_MCP_TTY_SRC (default /dev/tty)
#        default N → no write, return 0 (preserves existing value)
#        y/Y → rewrite file with new value at the existing key position
#   6. If KEY absent: append "KEY=VALUE\n" to file
#   7. chmod 0600 again (idempotent — defends against umask widening on rewrite)
# Returns:
#   0 on success (write or deliberate no-op via N choice)
#   1 on validation failure, missing KEY arg, or write error
mcp_secrets_set() {
    local key="${1:-}"
    local value="${2:-}"
    if [[ -z "$key" ]]; then
        echo -e "${RED}✗${NC} mcp_secrets_set: missing KEY argument" >&2
        return 1
    fi
    if ! _mcp_validate_value "$value"; then
        echo -e "${RED}✗${NC} mcp_secrets_set: value for ${key} contains shell metacharacters (\$, backtick, backslash, quote, newline) — refusing to write" >&2
        return 1
    fi
    local cfg
    cfg="$(_mcp_config_path)"
    mkdir -p "$(dirname "$cfg")" || return 1
    touch "$cfg" || return 1
    chmod 0600 "$cfg" || return 1
    mcp_secrets_load
    local idx
    if idx=$(_mcp_secrets_index "$key"); then
        # Collision: key already present — prompt for confirmation.
        local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"
        local choice
        # tui_tty_read writes prompt to TTY (not stderr) so it stays visible
        # under the install.sh:401 `( mcp_wizard_run ) 2>"$stderr_tmp"` wrapper.
        if ! tui_tty_read choice "[y/N] Overwrite ${key}? " 0 "$tty_src"; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                # Rewrite the file, substituting the updated value at the matching index.
                local tmp
                tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
                local i
                for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
                    if [[ "$i" -eq "$idx" ]]; then
                        printf '%s=%s\n' "$key" "$value" >> "$tmp"
                    else
                        printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp"
                    fi
                done
                mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
                chmod 0600 "$cfg" || return 1
                ;;
            *)
                # Default N: keep existing value, no write.
                return 0
                ;;
        esac
    else
        # Key is new: append entry.
        printf '%s=%s\n' "$key" "$value" >> "$cfg" || return 1
        chmod 0600 "$cfg" || return 1
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-MCP install wizard (MCP-04)
# ─────────────────────────────────────────────────────────────────────────────

# _mcp_resolve_claude_bin — echo path to claude binary (honors TK_MCP_CLAUDE_BIN seam).
# Returns 1 if no binary is found (caller handles fail-soft warning + return 2).
_mcp_resolve_claude_bin() {
    if [[ -n "${TK_MCP_CLAUDE_BIN:-}" ]]; then
        echo "$TK_MCP_CLAUDE_BIN"
        return 0
    fi
    if command -v claude >/dev/null 2>&1; then
        echo "claude"
        return 0
    fi
    return 1
}

# _mcp_lookup_index — echo 0-based index of <name> in MCP_NAMES[]; returns 1 if absent.
# Requires mcp_catalog_load to have been called first.
_mcp_lookup_index() {
    local target="$1"
    local i
    for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
        if [[ "${MCP_NAMES[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# mcp_wizard_run <name> [--dry-run] — drive the per-MCP install flow.
# Steps:
#   1. Resolve catalog index for <name>; error if not in curated catalog.
#   2. Check claude CLI presence (test-seam aware); absent → warn once + return 2.
#   3. If requires_oauth=1: skip env-prompt step, print OAuth notice.
#   4. For each env_var_key in MCP_ENV_KEYS[idx] (semicolon-split):
#        prompt with read -rsp (hidden input) via TK_MCP_TTY_SRC,
#        retry up to 3 times on empty input,
#        persist via mcp_secrets_set (collision prompt + 0600 enforcement inside).
#   5. If --dry-run: print "[+ INSTALL] mcp <name> (would run: <cmd>)" → return 0, no writes.
#   6. Invoke `env KEY=VALUE... <claude_bin> mcp add <install_args>`.
#      Return the exact exit code of that invocation.
# Returns:
#   0  install success (or dry-run)
#   1  missing argument, unknown MCP name, or required key not provided after 3 attempts
#   2  claude CLI absent (fail-soft, MCP-02)
#   N  exit code propagated from `claude mcp add` (N > 0 on install failure)
mcp_wizard_run() {
    local name=""
    local dry_run=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1 ;;
            -*) echo -e "${YELLOW}!${NC} mcp_wizard_run: ignoring unknown flag $1" >&2 ;;
            *)  [[ -z "$name" ]] && name="$1" ;;
        esac
        shift
    done

    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} mcp_wizard_run: missing MCP name argument" >&2
        return 1
    fi

    # Ensure catalog is loaded.
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi

    local idx
    if ! idx=$(_mcp_lookup_index "$name"); then
        echo -e "${RED}✗${NC} mcp_wizard_run: '$name' not in curated catalog" >&2
        return 1
    fi

    # Resolve claude binary (fail-soft when absent).
    local claude_bin
    if ! claude_bin=$(_mcp_resolve_claude_bin); then
        if [[ -z "${_MCP_CLI_WARNED:-}" ]]; then
            echo -e "${YELLOW}!${NC} claude CLI not found — cannot install MCPs from here. See docs/MCP-SETUP.md" >&2
            _MCP_CLI_WARNED=1
        fi
        return 2
    fi

    local oauth="${MCP_OAUTH[$idx]}"
    local env_keys_csv="${MCP_ENV_KEYS[$idx]}"
    local install_args_packed="${MCP_INSTALL_ARGS[$idx]}"

    # Reconstruct install_args[] from the unit-separator-packed string (ASCII 31 = $'\037').
    local IFS_SAVED="$IFS"
    IFS=$'\037'
    # shellcheck disable=SC2206
    local install_args=( $install_args_packed )
    IFS="$IFS_SAVED"

    local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"

    # Dry-run early-out — print the would-run command and return without any
    # secrets collection or claude invocation. Moved before the secrets loop so
    # --dry-run is fully non-interactive (no TTY required, no env file writes).
    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] mcp ${name} (would run: ${claude_bin} mcp add ${install_args[*]})"
        return 0
    fi

    # Collect env vars (skipped for OAuth-only MCPs).
    local exported_env=()
    if [[ "$oauth" -eq 1 ]]; then
        # OAuth-only MCPs let `claude mcp add` print its own "Added stdio MCP
        # server" line — no narration needed from us.
        :
    elif [[ -n "$env_keys_csv" && "${TK_MCP_DEFER_SECRETS:-0}" == "1" ]]; then
        # Defer mode (set by install.sh during dispatch). Don't block the
        # install on interactive secret prompts — user reported they "never
        # finish the install" if it hangs on key entry mid-flow (2026-05-01).
        # Strategy (refined 2026-05-01 per user feedback): DO register the
        # MCP via `claude mcp add` so it shows up in `claude mcp list` and
        # the entry exists in ~/.claude.json. Pass NO env vars — claude
        # CLI registers the server with an empty env map. The MCP server
        # will fail at first use until the user supplies the API key,
        # but the registration itself completes during install. Queue
        # the (name, keys, install_args) tuple for the parent to print
        # follow-up instructions.
        local _deferred_keys="${env_keys_csv//;/, }"
        if [[ -n "${TK_MCP_DEFERRED_QUEUE:-}" ]]; then
            printf '%s\t%s\t%s\n' "$name" "$_deferred_keys" "${install_args[*]}" \
                >> "$TK_MCP_DEFERRED_QUEUE" 2>/dev/null || true
        fi
        # Pre-create empty stub entries in mcp-config.env so the user can
        # `vi ~/.claude/mcp-config.env` and just fill values — no need to
        # remember which keys belong where. mcp_secrets_set handles 0600
        # + collision (existing entries are preserved).
        local IFS_SAVED2="$IFS"
        IFS=';'
        # shellcheck disable=SC2206
        local _stub_keys=( $env_keys_csv )
        IFS="$IFS_SAVED2"
        local _stub_key
        for _stub_key in "${_stub_keys[@]}"; do
            [[ -z "$_stub_key" ]] && continue
            # Only stub if absent — never overwrite an existing value.
            mcp_secrets_load
            if ! _mcp_secrets_index "$_stub_key" >/dev/null 2>&1; then
                # Append a placeholder entry directly (skip mcp_secrets_set's
                # interactive collision prompt — guaranteed absent here).
                local _env_path
                _env_path="$(_mcp_config_path)"
                mkdir -p "$(dirname "$_env_path")" 2>/dev/null || true
                printf '%s=\n' "$_stub_key" >> "$_env_path" 2>/dev/null || true
                chmod 0600 "$_env_path" 2>/dev/null || true
            fi
        done
        # Run `claude mcp add` WITHOUT env vars — server registers in
        # claude.json with no env binding. claude CLI inherits shell env
        # at launch and propagates it to MCP child processes, so once the
        # user fills mcp-config.env (toolkit auto-installs the source
        # line into ~/.zshrc / ~/.bashrc) and reloads their shell, MCPs
        # pick up the keys at next claude startup. No re-registration
        # needed when keys change later — edit + re-open claude.
        "$claude_bin" mcp add "${install_args[@]}"
        local _add_rc=$?
        if [[ "$_add_rc" -ne 0 ]]; then
            return "$_add_rc"
        fi
        # rc=3 = registered-without-env (distinct from rc=0 = fully wired,
        # rc=2 = claude CLI absent). Caller maps rc=3 to a "needs API key"
        # status row, NOT a failure.
        return 3
    elif [[ -n "$env_keys_csv" ]]; then
        local IFS_SAVED2="$IFS"
        IFS=';'
        # shellcheck disable=SC2206
        local env_keys=( $env_keys_csv )
        IFS="$IFS_SAVED2"
        local env_key
        for env_key in "${env_keys[@]}"; do
            [[ -z "$env_key" ]] && continue
            local collected_value=""
            local attempts=0
            while [[ -z "$collected_value" && "$attempts" -lt 3 ]]; do
                # tui_tty_read writes prompt to TTY (not stderr) so it stays
                # visible under install.sh's `( mcp_wizard_run ) 2>"$tmp"`
                # wrapper. silent=1 suppresses echo of the secret value;
                # tui_tty_read prints its own newline after silent reads, so
                # the legacy `printf '\n' >&2` afterwards is dropped.
                if ! tui_tty_read collected_value "${env_key}: " 1 "$tty_src"; then
                    collected_value=""
                fi
                attempts=$((attempts + 1))
                if [[ -z "$collected_value" ]]; then
                    echo -e "${YELLOW}!${NC} ${env_key} cannot be empty (attempt ${attempts}/3)" >&2
                fi
            done
            if [[ -z "$collected_value" ]]; then
                echo -e "${RED}✗${NC} mcp_wizard_run: missing required key ${env_key} after 3 attempts" >&2
                return 1
            fi
            # Persist to mcp-config.env (handles 0600 + collision prompt).
            if ! mcp_secrets_set "$env_key" "$collected_value"; then
                return 1
            fi
            # Queue for export to child process only (scoped via `env` below).
            exported_env+=("${env_key}=${collected_value}")
            # Overwrite local copy immediately — never let it linger as a named var.
            collected_value=""
        done
    fi

    # Invoke claude mcp add with env vars scoped to the child process only.
    if [[ "${#exported_env[@]}" -gt 0 ]]; then
        env "${exported_env[@]}" "$claude_bin" mcp add "${install_args[@]}"
    else
        "$claude_bin" mcp add "${install_args[@]}"
    fi
}

# ─────────────────────────────────────────────────
# TUI page assembly helper (MCP-03)
# ─────────────────────────────────────────────────

# mcp_status_array — populate TUI_LABELS/GROUPS/INSTALLED/DESCS for the MCP page.
# Side effects: writes to global arrays consumed by tui_checklist (from lib/tui.sh).
# Globals (write):
#   TUI_LABELS[]        — entry display names; unofficial entries get a leading
#                         yellow `!` glyph (`! NotebookLM`) — visible badge per
#                         TUI-03. Plain `[!]` under NO_COLOR.
#   TUI_GROUPS[]        — title-cased category (e.g. "Backend", "Docs Research").
#                         Phase 34-01 (TUI-01): grouped rendering replaces flat
#                         "MCP" placeholder. Section headers come for free from
#                         tui_checklist's TUI_GROUPS[] transition logic.
#   TUI_INSTALLED[]     — 0/1 per probe (state=2 maps to 0 with [unavailable] in desc)
#   TUI_DESCS[]         — description with appended `[MCP:✓ CLI:—]` status block
#                         (TUI-02). Glyphs: ✓ installed, ✗ absent, ⊘ unknown,
#                         — n/a (entry has no CLI block).
#   TUI_GROUP_NAMES[]   — list of distinct categories present (for subtitle lookup)
#   TUI_GROUP_DESCS[]   — empty strings (parallel) — keeps tui.sh's subtitle
#                         lookup contract happy without forcing per-section copy.
#   MCP_CLI_PRESENT     — 0 if all probes returned 2 (no CLI), 1 otherwise
#
# Iteration order: by CATEGORIES_ORDER[] then alphabetical within each category.
# Categories with zero entries produce NO header (skipped silently per D-06).
# Bash 3.2: parallel arrays only — no associative arrays, no `mapfile`.
mcp_status_array() {
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi
    # Bash 3.2: `${#var[@]:-0}` is rejected as "bad substitution"; use `${var[*]+x}`
    # existence test (mirrors the established pattern at tui.sh:164).
    if [[ -z "${CATEGORIES_ORDER[*]+x}" ]] || [[ "${#CATEGORIES_ORDER[@]}" -eq 0 ]]; then
        mcp_categories_load || return 1
    fi

    # Detect once per launch (D-11) — populates MCP_STATUS[] + CLI_STATUS[].
    mcp_status_detect

    TUI_LABELS=()
    TUI_GROUPS=()
    TUI_INSTALLED=()
    TUI_DESCS=()
    TUI_GROUP_NAMES=()
    TUI_GROUP_DESCS=()
    # Phase 36-A: every installed MCP is reinstallable from the TUI
    # (Space cycles install ↔ reinstall). The reinstall path = claude mcp
    # remove + claude mcp add — works uniformly for npx/uvx/HTTP/SSE
    # transports, so no per-transport gating here.
    TUI_REINSTALLABLE=()
    # Phase 34-01 ordering map: install.sh's dispatch loop iterates by
    # MCP_NAMES alphabetical order, but the TUI renders in category-grouped
    # order (alpha-within-category). TUI_RESULTS / TUI_LABELS / TUI_INSTALLED
    # are populated by tui_checklist using the TUI render index, so the
    # dispatch loop MUST translate TUI index ↔ MCP_NAMES index to read the
    # right selection per entry. TUI_TO_MCP_IDX[$tui_idx] = MCP_NAMES idx,
    # MCP_TO_TUI_IDX[$mcp_idx] = TUI render idx.
    TUI_TO_MCP_IDX=()
    MCP_TO_TUI_IDX=()
    # Initialise MCP_TO_TUI_IDX with placeholders so partial fills are safe.
    local _zfill
    for ((_zfill=0; _zfill<${#MCP_NAMES[@]}; _zfill++)); do
        MCP_TO_TUI_IDX+=(-1)
    done
    unset _zfill
    MCP_CLI_PRESENT=0

    # NO_COLOR-aware glyph helpers. Resolve once — these strings are appended
    # into TUI_DESCS verbatim and re-rendered every frame, so building them
    # per-row would be wasteful. `${NO_COLOR+x}` follows no-color.org semantics
    # (presence disables, even when empty).
    local _g_ok="✓" _g_no="✗" _g_unk="⊘" _g_na="—" _g_bang="!"
    local _c_ok="" _c_no="" _c_unk="" _c_y="" _c_nc=""
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _c_ok=$'\033[0;32m'
        _c_no=$'\033[0;31m'
        _c_unk=$'\033[0;36m'
        _c_y=$'\033[1;33m'
        _c_nc=$'\033[0m'
    fi

    # Walk categories in canonical order. For each, gather alphabetic entries.
    # Two passes per category: first compute matching indices, then emit them.
    local cat cat_display cat_count i name desc mcp_g cli_g status_block label
    local seen_idx j
    for cat in "${CATEGORIES_ORDER[@]+"${CATEGORIES_ORDER[@]}"}"; do
        # Collect entry indices in this category. MCP_NAMES is already alpha
        # sorted by mcp_catalog_load, so push order = alphabetic per category.
        seen_idx=()
        for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
            if [[ "${MCP_CATEGORY[$i]:-}" == "$cat" ]]; then
                seen_idx+=("$i")
            fi
        done
        cat_count=${#seen_idx[@]}
        # Skip categories with zero entries — no empty headers per D-06.
        [[ "$cat_count" -eq 0 ]] && continue

        cat_display=$(_mcp_category_display "$cat")
        TUI_GROUP_NAMES+=("$cat_display")
        TUI_GROUP_DESCS+=("")

        for j in "${seen_idx[@]+"${seen_idx[@]}"}"; do
            i="$j"
            name="${MCP_NAMES[$i]}"
            desc="${MCP_DESCS[$i]}"

            # Record the index map: ${#TUI_LABELS[@]} is the about-to-be-pushed
            # TUI index (current length BEFORE the push). MCP_NAMES idx = $i.
            TUI_TO_MCP_IDX+=("$i")
            MCP_TO_TUI_IDX[$i]="${#TUI_LABELS[@]}"

            # Yellow `!` for unofficial entries (TUI-03 badge).
            if [[ "${MCP_UNOFFICIAL[$i]:-0}" == "1" ]]; then
                if [[ -n "$_c_y" ]]; then
                    label="${_c_y}${_g_bang}${_c_nc} ${MCP_DISPLAY[$i]}"
                else
                    label="[!] ${MCP_DISPLAY[$i]}"
                fi
            else
                label="${MCP_DISPLAY[$i]}"
            fi
            TUI_LABELS+=("$label")
            TUI_GROUPS+=("$cat_display")

            # MCP installed/absent → set TUI_INSTALLED for tui.sh's [installed ✓]
            # immutable-row treatment. Unknown → 0 (selectable; status column
            # makes the unknown state explicit in the description).
            # TUI_REINSTALLABLE: 1 only for installed rows (Space cycles
            # them install ↔ reinstall). Absent and unknown rows get 0.
            case "${MCP_STATUS[$i]:-unknown}" in
                installed)
                    TUI_INSTALLED+=(1)
                    TUI_REINSTALLABLE+=(1)
                    MCP_CLI_PRESENT=1
                    mcp_g="${_c_ok}${_g_ok}${_c_nc}"
                    ;;
                absent)
                    TUI_INSTALLED+=(0)
                    TUI_REINSTALLABLE+=(0)
                    MCP_CLI_PRESENT=1
                    mcp_g="${_c_no}${_g_no}${_c_nc}"
                    ;;
                *)
                    # unknown — claude CLI absent or list failed.
                    TUI_INSTALLED+=(0)
                    TUI_REINSTALLABLE+=(0)
                    mcp_g="${_c_unk}${_g_unk}${_c_nc}"
                    desc="[unavailable] ${desc}"
                    ;;
            esac

            # CLI status column.
            case "${CLI_STATUS[$i]:-na}" in
                installed) cli_g="${_c_ok}${_g_ok}${_c_nc}" ;;
                absent)    cli_g="${_c_no}${_g_no}${_c_nc}" ;;
                *)         cli_g="$_g_na" ;;
            esac

            # Append status block to description. Format chosen for compact
            # one-line read under the row label (tui.sh line 208 indents
            # description under each row).
            status_block="[MCP:${mcp_g} CLI:${cli_g}]"
            TUI_DESCS+=("${desc} ${status_block}")
        done
    done

    export MCP_CLI_PRESENT
}
