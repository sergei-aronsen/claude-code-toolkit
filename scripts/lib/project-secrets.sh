#!/bin/bash

# Claude Code Toolkit — Project Secrets Library (v5.0+)
# Source this file. Do NOT execute it directly.
# Exposes (Phase 37 / SEC-01..06):
#   project_secrets_write_env <root> <KEY> <VALUE>      — write KEY=VALUE to <root>/.env (mode 0600, idempotent)
#   project_secrets_ensure_gitignore <root>             — guarantee `.env` in <root>/.gitignore (D-07/08/09)
#   project_secrets_render_mcp_env_block <KEY...>       — echo {"K":"${K}",…} JSON for .mcp.json env block
#   project_secrets_validate_mcp_env_block <json>       — refuse literal values in .mcp.json env (defense in depth)
# Globals (write):
#   _PROJECT_SECRETS_KEYS[]                             — keys parsed from <root>/.env (private)
#   _PROJECT_SECRETS_VALUES[]                           — values parsed from <root>/.env (private)
# Test seams:
#   TK_MCP_TTY_SRC                                      — REUSED (D-05) — TTY source for collision prompt
#   TK_PROJECT_SECRETS_ALLOW_LITERAL                    — bypass SEC-05 literal refusal (test-only — D-15)
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

# Lazy-source mcp.sh so _mcp_validate_value (D-16) is available without
# duplicating the metacharacter regex. Sourcing mcp.sh transitively pulls in
# tui.sh (mcp.sh:69-75), which provides tui_tty_read for the collision prompt.
if ! command -v _mcp_validate_value >/dev/null 2>&1; then
    _PROJECT_SECRETS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh"
    fi
fi

# _project_secrets_load_env <env_path> — populate parallel arrays
# _PROJECT_SECRETS_KEYS[] and _PROJECT_SECRETS_VALUES[] from <env_path>.
# Mirrors mcp_secrets_load (mcp.sh:448-480) line-parser shape:
#   - skip ^[[:space:]]*# comments
#   - skip blank lines
#   - skip lines without '='
#   - audit L1 key guard ^[A-Z_][A-Z0-9_]*$ (defense in depth — drop malformed keys)
# Empty/absent file → both arrays length 0. Returns 0.
# shellcheck disable=SC2034
_project_secrets_load_env() {
    _PROJECT_SECRETS_KEYS=()
    _PROJECT_SECRETS_VALUES=()
    local cfg="${1:-}"
    if [[ -z "$cfg" || ! -f "$cfg" ]]; then
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
        _PROJECT_SECRETS_KEYS+=("$key")
        _PROJECT_SECRETS_VALUES+=("$value")
    done < "$cfg"
}

# _project_secrets_index <key> — echo 0-based index of $1 in _PROJECT_SECRETS_KEYS;
# returns 1 if absent. Requires _project_secrets_load_env to have been called first.
_project_secrets_index() {
    local target="$1"
    local i
    for ((i=0; i<${#_PROJECT_SECRETS_KEYS[@]}; i++)); do
        if [[ "${_PROJECT_SECRETS_KEYS[$i]}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# project_secrets_write_env <project_root> <KEY> <VALUE> — append or overwrite
# KEY=VALUE in <project_root>/.env. Mirrors mcp_secrets_set (mcp.sh:511-565)
# order-of-operations (D-04):
#   1. mkdir -p <project_root> (do NOT create paths above the caller-supplied root)
#   2. touch <project_root>/.env (creates if absent)
#   3. chmod 0600 <project_root>/.env (idempotent — before any write)
#   4. Load existing entries via _project_secrets_load_env
#   5. If KEY already present:
#        prompt "[y/N] Overwrite KEY in <root>/.env?" via TK_MCP_TTY_SRC (default /dev/tty)
#        default N → no write, return 0 (preserves existing value)
#        y/Y → rewrite file with new value at the existing key position
#   6. If KEY absent: append "KEY=VALUE\n" to file
#   7. chmod 0600 again (idempotent — defends against umask widening on rewrite)
# Reuses _mcp_validate_value (D-16) — rejects $, backtick, backslash, double-quote,
# single-quote, newline. Reuses TK_MCP_TTY_SRC (D-05) — does NOT coin a new seam.
# Returns:
#   0 on success (write or deliberate no-op via N choice)
#   1 on missing args, validation failure, or write error
project_secrets_write_env() {
    local project_root="${1:-}"
    local key="${2:-}"
    local value="${3:-}"
    if [[ -z "$project_root" ]]; then
        echo -e "${RED}✗${NC} project_secrets_write_env: missing project_root argument" >&2
        return 1
    fi
    if [[ -z "$key" ]]; then
        echo -e "${RED}✗${NC} project_secrets_write_env: missing KEY argument" >&2
        return 1
    fi
    if ! _mcp_validate_value "$value"; then
        echo -e "${RED}✗${NC} project_secrets_write_env: value for ${key} contains shell metacharacters — refusing to write" >&2
        return 1
    fi
    # Step 1: create the project root (NOT dirname — D-04 forbids paths above the root).
    mkdir -p "$project_root" || return 1
    local cfg="${project_root%/}/.env"
    # Steps 2-3: touch + chmod 0600 BEFORE any write.
    touch "$cfg" || return 1
    chmod 0600 "$cfg" || return 1
    # Step 4: load existing entries.
    _project_secrets_load_env "$cfg"
    local idx
    if idx=$(_project_secrets_index "$key"); then
        # Step 5: collision — prompt for confirmation via TK_MCP_TTY_SRC (D-05 reuse).
        local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"
        local choice
        if ! tui_tty_read choice "[y/N] Overwrite ${key} in ${project_root%/}/.env? " 0 "$tty_src"; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                # Step 6 (rewrite branch): rewrite the file via mktemp+mv,
                # substituting the updated value at the matching index.
                local tmp
                tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
                local i
                for ((i=0; i<${#_PROJECT_SECRETS_KEYS[@]}; i++)); do
                    if [[ "$i" -eq "$idx" ]]; then
                        printf '%s=%s\n' "$key" "$value" >> "$tmp"
                    else
                        printf '%s=%s\n' "${_PROJECT_SECRETS_KEYS[$i]}" "${_PROJECT_SECRETS_VALUES[$i]}" >> "$tmp"
                    fi
                done
                mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
                # Step 7: chmod 0600 again (defends against umask widening on rewrite).
                chmod 0600 "$cfg" || return 1
                ;;
            *)
                # Default N: keep existing value, no write.
                return 0
                ;;
        esac
    else
        # Step 6 (append branch): key is new, append entry.
        printf '%s=%s\n' "$key" "$value" >> "$cfg" || return 1
        # Step 7: chmod 0600 again (idempotent).
        chmod 0600 "$cfg" || return 1
    fi
    return 0
}

# project_secrets_ensure_gitignore <project_root> — guarantee `.env` is in
# <project_root>/.gitignore. Idempotent: re-run is a no-op when the line
# already exists (D-07 exact-fixed-line `grep -Fxq '.env'` — rejects `*.env`,
# `# .env`, `.env.local`). Creates .gitignore (mode 0644) when absent (D-09).
# When file exists with content not ending in newline: append a leading `\n`
# before the comment + `.env` block (D-08 — avoid pollution of trailing-blank
# convention).
# Returns:
#   0 on success (line present after call)
#   1 on missing project_root or write error
project_secrets_ensure_gitignore() {
    local project_root="${1:-}"
    if [[ -z "$project_root" ]]; then
        echo -e "${RED}✗${NC} project_secrets_ensure_gitignore: missing project_root argument" >&2
        return 1
    fi
    mkdir -p "$project_root" || return 1
    local gi="${project_root%/}/.gitignore"
    # D-07: exact-fixed-line match — rejects `*.env`, `# .env`, `.env.local`.
    if [[ -f "$gi" ]] && grep -Fxq '.env' "$gi"; then
        return 0
    fi
    if [[ ! -f "$gi" ]]; then
        # D-09: create the file with mode 0644.
        : > "$gi" || return 1
        chmod 0644 "$gi" || return 1
    elif [[ -s "$gi" ]] && [[ -n "$(tail -c 1 "$gi" 2>/dev/null)" ]]; then
        # D-08: file has content and does not end with a newline → leading blank.
        printf '\n' >> "$gi" || return 1
    fi
    # D-08: append two-line block (comment + .env).
    {
        printf '# claude-code-toolkit: never commit project-scope MCP secrets\n'
        printf '.env\n'
    } >> "$gi" || return 1
    chmod 0644 "$gi" || return 1
    return 0
}

# project_secrets_render_mcp_env_block <KEY1> <KEY2> ... — echo a JSON object
# string `{"KEY1":"${KEY1}","KEY2":"${KEY2}"}` to stdout. No trailing newline
# (caller pipes it directly into a JSON-aware tool — D-10).
# Empty arg list → echo `{}` (D-11). Each key validated against
# `^[A-Z_][A-Z0-9_]*$` (D-12) — invalid key returns 1 with stderr message.
# Repeated keys are tolerated: jq's reduce will collapse duplicates with last-wins.
# Returns:
#   0 on success
#   1 on invalid key
project_secrets_render_mcp_env_block() {
    if [[ $# -eq 0 ]]; then
        # D-11: empty arg list → {} with no trailing newline.
        printf '{}'
        return 0
    fi
    local k
    for k in "$@"; do
        # D-12: each key must shape like a POSIX env-var name.
        if [[ ! "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            echo -e "${RED}✗${NC} project_secrets_render_mcp_env_block: invalid key '$k'" >&2
            return 1
        fi
    done
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} project_secrets_render_mcp_env_block: jq required" >&2
        return 1
    fi
    # D-10: produce {"K1":"${K1}","K2":"${K2}"} via jq (compact, no trailing newline).
    # `--args` collects positional args into $ARGS.positional[]; reduce builds the object.
    jq -nc --args 'reduce $ARGS.positional[] as $k ({}; . + {($k): ("${" + $k + "}")})' -- "$@"
}

# project_secrets_validate_mcp_env_block <json_string> — defense-in-depth
# refusal of literal values in a .mcp.json env block. Parses JSON values via
# `jq -r '.[] | tostring'` and regex-tests each against `^\$\{[A-Z_][A-Z0-9_]*\}$`
# (D-13). Refusal returns rc=1 with stderr `✗ refusing to write literal value
# into .mcp.json (use ${VAR} substitution)` (D-14). Test seam
# TK_PROJECT_SECRETS_ALLOW_LITERAL=1 bypasses the regex check and emits a
# one-line warning (D-15).
# Returns:
#   0 if every value matches ${VAR} form (or bypass active)
#   1 on missing arg, missing jq, or any literal value (when not bypassed)
project_secrets_validate_mcp_env_block() {
    local json="${1:-}"
    if [[ -z "$json" ]]; then
        echo -e "${RED}✗${NC} project_secrets_validate_mcp_env_block: missing json argument" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} project_secrets_validate_mcp_env_block: jq required" >&2
        return 1
    fi
    local v
    while IFS= read -r v; do
        if [[ ! "$v" =~ ^\$\{[A-Z_][A-Z0-9_]*\}$ ]]; then
            if [[ "${TK_PROJECT_SECRETS_ALLOW_LITERAL:-}" == "1" ]]; then
                # D-15: documented test-only bypass; emit a loud warning.
                echo -e "${YELLOW}⚠${NC} project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only" >&2
                continue
            fi
            # D-14: the literal `${VAR}` substring must land in the message —
            # escape the dollar so bash does not expand it.
            echo -e "${RED}✗${NC} refusing to write literal value into .mcp.json (use \${VAR} substitution)" >&2
            return 1
        fi
    done < <(printf '%s' "$json" | jq -r '.[] | tostring' 2>/dev/null)
    return 0
}
