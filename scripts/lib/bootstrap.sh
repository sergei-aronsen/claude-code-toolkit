#!/bin/bash

# Claude Code Toolkit — SP/GSD Pre-Install Bootstrap Library
# Source this file. Do NOT execute it directly.
# Exposes: bootstrap_base_plugins
# Globals (read): HOME, TK_NO_BOOTSTRAP, TK_BOOTSTRAP_SP_CMD, TK_BOOTSTRAP_GSD_CMD,
#                 TK_BOOTSTRAP_TTY_SRC, TK_SP_INSTALL_CMD, TK_GSD_INSTALL_CMD
# Globals (write): none
#
# Behavior contract (Phase 21 — BOOTSTRAP-01..04):
#   - Two sequential [y/N] prompts (SP first, GSD second). Default N. (D-04, D-05)
#   - Reads via < /dev/tty (override: TK_BOOTSTRAP_TTY_SRC). Fail-closed N if unreachable. (D-06)
#   - Suppresses SP prompt if ~/.claude/plugins/cache/claude-plugins-official/superpowers/ exists. (D-08)
#   - Suppresses SP prompt if `claude` CLI is not on PATH (with warn). (D-09)
#   - Suppresses GSD prompt if ~/.claude/get-shit-done/ exists. (D-08)
#   - On y: invokes upstream installer via eval; non-zero exit logs warn and continues. (D-10, D-11)
#   - TK_NO_BOOTSTRAP=1 returns 0 immediately with no output. (D-16, D-17)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034  # consumed by log helpers below
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
# shellcheck disable=SC2034
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
# shellcheck disable=SC2034
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
# shellcheck disable=SC2034
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'

# Local log helpers — defined here because lib/install.sh does NOT export log_*.
# Shape mirrors scripts/uninstall.sh:71-74. Use these instead of raw echo for consistency.
_bootstrap_log_info()    { echo -e "${BLUE}ℹ${NC} $1" >&2; }
_bootstrap_log_warning() { echo -e "${YELLOW}⚠${NC} $1" >&2; }

# _bootstrap_prompt_and_run <plugin_name> <prompt_text> <cmd_string>
# Renders one [y/N] prompt; on y, evals $cmd; failure is non-fatal.
_bootstrap_prompt_and_run() {
    local plugin_name="$1" prompt_text="$2" cmd="$3"
    local tty_target="/dev/tty"
    [[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

    local choice=""
    if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
        _bootstrap_log_info "bootstrap skipped — no TTY"
        return 0
    fi

    case "${choice:-N}" in
        y|Y)
            local rc=0
            # shellcheck disable=SC2294  # eval is intentional — test seam overrides production constant
            eval "$cmd" || rc=$?
            if [[ $rc -ne 0 ]]; then
                _bootstrap_log_warning "${plugin_name} install failed (exit code ${rc}) — continuing toolkit install"
            fi
            ;;
        *)
            : # N / default — silently skip
            ;;
    esac
}

# bootstrap_base_plugins — entry point called by init-claude.sh and init-local.sh.
# Returns 0 unconditionally. All upstream installer failures are non-fatal.
bootstrap_base_plugins() {
    # D-16/D-17: env-var opt-out is byte-quiet (no log line).
    [[ "${TK_NO_BOOTSTRAP:-}" == "1" ]] && return 0

    local sp_dir="${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers"
    local gsd_dir="${HOME}/.claude/get-shit-done"

    local sp_cmd="${TK_BOOTSTRAP_SP_CMD:-${TK_SP_INSTALL_CMD:-}}"
    local gsd_cmd="${TK_BOOTSTRAP_GSD_CMD:-${TK_GSD_INSTALL_CMD:-}}"

    # SP prompt block — idempotency, missing-CLI, then prompt.
    if [[ -d "$sp_dir" ]]; then
        _bootstrap_log_info "superpowers already installed — skipping."
    elif ! command -v claude >/dev/null 2>&1; then
        _bootstrap_log_warning "claude CLI not on PATH — superpowers bootstrap skipped (install Claude Code first)."
    else
        _bootstrap_prompt_and_run "superpowers" \
            "Install superpowers via plugin marketplace? [y/N] " \
            "$sp_cmd"
    fi

    # GSD prompt block — independent of SP.
    if [[ -d "$gsd_dir" ]]; then
        _bootstrap_log_info "get-shit-done already installed — skipping."
    else
        _bootstrap_prompt_and_run "get-shit-done" \
            "Install get-shit-done via curl install script? [y/N] " \
            "$gsd_cmd"
    fi

    return 0
}
