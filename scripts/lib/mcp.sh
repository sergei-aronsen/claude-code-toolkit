#!/bin/bash

# Claude Code Toolkit — MCP Catalog Loader + Detection (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   mcp_catalog_load           — parses scripts/lib/mcp-catalog.json into MCP_* arrays
#   mcp_catalog_names          — prints 9 names one-per-line (alpha sorted)
#   is_mcp_installed <name>    — returns 0 (installed) / 1 (not installed) / 2 (claude CLI absent)
# Globals (write):
#   MCP_NAMES[]            — 9 catalog keys (alpha order)
#   MCP_DISPLAY[]          — display_name strings (parallel to MCP_NAMES)
#   MCP_ENV_KEYS[]         — env-var names joined with ';' (empty string = zero-config)
#   MCP_INSTALL_ARGS[]     — install_args[] joined with $'\037' (unit-separator) for safe split
#   MCP_DESCS[]            — description strings (parallel)
#   MCP_OAUTH[]            — 0/1 ints (parallel)
# Test seams:
#   TK_MCP_CLAUDE_BIN     — override path to claude binary (mocked in tests)
#   TK_MCP_CATALOG_PATH   — override path to mcp-catalog.json (mocked in tests)
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
    if printf '%s\n' "$list_out" | grep -E "^${name}([[:space:]]|$)" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
