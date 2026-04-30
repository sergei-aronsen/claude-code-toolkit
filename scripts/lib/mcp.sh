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
# Globals (write, Plan 02):
#   MCP_SECRET_KEYS[]      — keys from mcp-config.env (parallel to MCP_SECRET_VALUES)
#   MCP_SECRET_VALUES[]    — values from mcp-config.env
# Test seams:
#   TK_MCP_CLAUDE_BIN     — override path to claude binary (mocked in tests)
#   TK_MCP_CATALOG_PATH   — override path to mcp-catalog.json (mocked in tests)
#   TK_MCP_TTY_SRC        — override /dev/tty for wizard read prompts (Plan 02)
#   TK_MCP_CONFIG_HOME    — override $HOME for mcp-config.env path resolution (Plan 02)
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

# Internal helper — resolves sibling mcp-catalog.json path from BASH_SOURCE.
_mcp_default_catalog_path() {
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
    echo "${d}/mcp-catalog.json"
}

# mcp_catalog_load — parse mcp-catalog.json into six parallel arrays.
# Populates MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH.
# Returns 1 if catalog is missing or jq is absent.
mcp_catalog_load() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
    if [[ ! -f "$catalog_path" ]]; then
        echo -e "${RED}✗${NC} mcp-catalog.json not found at $catalog_path" >&2
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
    local name
    while IFS= read -r name; do
        # shellcheck disable=SC2034
        MCP_NAMES+=("$name")
        # shellcheck disable=SC2034
        MCP_DISPLAY+=("$(jq -r --arg n "$name" '.[$n].display_name' "$catalog_path")")
        # shellcheck disable=SC2034
        MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.[$n].env_var_keys | join(";")' "$catalog_path")")
        # Use $'\037' (unit separator, ASCII 31) to join install_args[] — survives spaces in args.
        # shellcheck disable=SC2034
        MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '[.[$n].install_args[] ] | join("")' "$catalog_path")")
        # shellcheck disable=SC2034
        MCP_DESCS+=("$(jq -r --arg n "$name" '.[$n].description' "$catalog_path")")
        if [[ "$(jq -r --arg n "$name" '.[$n].requires_oauth' "$catalog_path")" == "true" ]]; then
            # shellcheck disable=SC2034
            MCP_OAUTH+=(1)
        else
            # shellcheck disable=SC2034
            MCP_OAUTH+=(0)
        fi
    done < <(jq -r 'keys | sort | .[]' "$catalog_path")
}

# mcp_catalog_names — print all 9 catalog names, one per line, alphabetically sorted.
mcp_catalog_names() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
    jq -r 'keys | sort | .[]' "$catalog_path"
}

# is_mcp_installed <name> — three-state return (MCP-02 fail-soft contract):
#   0 = MCP is installed (found in `claude mcp list` output)
#   1 = MCP is NOT installed (CLI present but name absent)
#   2 = claude CLI absent OR `claude mcp list` failed (unknown state)
# When CLI absent, prints exactly ONE warning to stderr (global guard _MCP_CLI_WARNED).
is_mcp_installed() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} is_mcp_installed: missing argument" >&2
        return 1
    fi
    local claude_bin="${TK_MCP_CLAUDE_BIN:-}"
    if [[ -z "$claude_bin" ]]; then
        if command -v claude >/dev/null 2>&1; then
            claude_bin="claude"
        fi
    fi
    if [[ -z "$claude_bin" ]]; then
        # MCP-02 fail-soft: warn once (global guard) then return 2 — caller distinguishes from 1.
        if [[ -z "${_MCP_CLI_WARNED:-}" ]]; then
            echo -e "${YELLOW}!${NC} claude CLI not found — MCP detection unavailable" >&2
            _MCP_CLI_WARNED=1
        fi
        return 2
    fi
    local list_out
    if ! list_out=$("$claude_bin" mcp list 2>/dev/null); then
        # CLI present but list failed (e.g., not authenticated). Treat as state 2 (unknown).
        return 2
    fi
    # Match a row that begins with "<name>" followed by whitespace OR end-of-line.
    # `claude mcp list` rows look like "context7    sse    https://..."
    # Audit M-MCP: $name was interpolated into the regex without escaping. An
    # MCP entry whose registered name contains "." or "+" (both legal) would
    # match unrelated rows. Escape regex metacharacters before substitution.
    local _name_escaped
    _name_escaped=$(printf '%s' "$name" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g')
    if printf '%s\n' "$list_out" | grep -E "^${_name_escaped}([[:space:]]|\$)" >/dev/null 2>&1; then
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
        if ! read -r -p "[y/N] Overwrite ${key}? " choice < "$tty_src" 2>/dev/null; then
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
        echo "OAuth flow handled by claude mcp add — follow CLI prompts."
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
                if ! read -rsp "${env_key}: " collected_value < "$tty_src" 2>/dev/null; then
                    collected_value=""
                fi
                # Print newline after hidden input so terminal cursor advances.
                printf '\n' >&2
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
#   TUI_LABELS[]      — 9 names (alpha)
#   TUI_GROUPS[]      — all "MCP" (single section)
#   TUI_INSTALLED[]   — 0/1 per probe (state=2 maps to 0 with [unavailable] in desc)
#   TUI_DESCS[]       — description strings (prefixed when CLI absent)
#   MCP_CLI_PRESENT   — 0 if all 9 probes returned 2 (no CLI), 1 otherwise
mcp_status_array() {
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi
    TUI_LABELS=()
    TUI_GROUPS=()
    TUI_INSTALLED=()
    TUI_DESCS=()
    MCP_CLI_PRESENT=0
    local i name desc rc
    for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
        name="${MCP_NAMES[$i]}"
        desc="${MCP_DESCS[$i]}"
        TUI_LABELS+=("${MCP_DISPLAY[$i]}")
        TUI_GROUPS+=("MCP")
        rc=0
        is_mcp_installed "$name" || rc=$?
        case "$rc" in
            0)
                TUI_INSTALLED+=(1)
                MCP_CLI_PRESENT=1
                ;;
            1)
                TUI_INSTALLED+=(0)
                MCP_CLI_PRESENT=1
                ;;
            *)
                # rc=2 (CLI absent or list failed) — render row but mark unavailable.
                # Using *) instead of 2) to treat any unexpected return as unavailable
                # (fail-soft posture if jq fails or catalog is corrupted).
                TUI_INSTALLED+=(0)
                desc="[unavailable] ${desc}"
                ;;
        esac
        TUI_DESCS+=("$desc")
    done
    export MCP_CLI_PRESENT
}
