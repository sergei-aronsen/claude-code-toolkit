#!/bin/bash

# Claude Code Toolkit — Per-Component Dispatcher Library (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   TK_DISPATCH_ORDER  array — canonical install order (DISPATCH-01)
#   dispatch_superpowers  — invokes claude plugin install (TK_SP_INSTALL_CMD)
#   dispatch_gsd          — invokes upstream curl install (TK_GSD_INSTALL_CMD)
#   dispatch_toolkit      — invokes init-claude.sh (or local init-local.sh)
#   dispatch_security     — invokes setup-security.sh [--yes] [--force]
#   dispatch_rtk          — invokes brew install rtk && rtk init -g </dev/null
#   dispatch_statusline   — invokes install-statusline.sh [--yes]
# Globals (read): BASH_SOURCE, 0, TK_REPO_URL, TK_SP_INSTALL_CMD,
#                 TK_GSD_INSTALL_CMD, TK_DISPATCH_OVERRIDE_*
# Globals (write): TK_DISPATCH_ORDER (only if unset)
#
# Each dispatcher takes [--force] [--dry-run] [--yes] in any order. Returns
# the underlying script's exit code unchanged. --dry-run prints the would-run
# command and returns 0 without invocation.
#
# Test seam: TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>=<path> replaces the real
# installer with <path>. Mirrors v4.4 TK_BOOTSTRAP_SP_CMD pattern.
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards.
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

# Reuse canonical SP/GSD install commands from optional-plugins.sh (D-04).
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'

# Default repo URL (overridable for testing or fork installs).
[[ -z "${TK_REPO_URL:-}" ]] && TK_REPO_URL='https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main'

# Canonical install order — DISPATCH-01 contract.
# Guard uses the variable-is-unset-or-empty form to avoid nounset errors.
if [[ -z "${TK_DISPATCH_ORDER[*]:-}" ]]; then
    TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)
fi

# Internal log helpers — underscore prefix.
_dispatch_log_info()    { echo -e "${BLUE}i${NC} $1" >&2; }
_dispatch_log_warning() { echo -e "${YELLOW}!${NC} $1" >&2; }

# Curl-pipe vs local invocation detection (D-24, RESEARCH §4).
_dispatch_is_curl_pipe() {
    if [[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]; then
        return 0
    fi
    return 1
}

# Resolve sibling path for local invocation (when not curl-pipe).
_dispatch_sibling_path() {
    local name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
    echo "${script_dir}/../${name}"
}

# dispatch_superpowers — claude plugin install.
dispatch_superpowers() {
    local force=0 dry_run=0 yes=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ;;
            *) ;;
        esac
        shift
    done
    : "$force" "$yes"

    if [[ -n "${TK_DISPATCH_OVERRIDE_SUPERPOWERS:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] superpowers (would run override: $TK_DISPATCH_OVERRIDE_SUPERPOWERS)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_SUPERPOWERS"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] superpowers (would run: $TK_SP_INSTALL_CMD)"
        return 0
    fi
    eval "$TK_SP_INSTALL_CMD"
}

# dispatch_gsd — upstream curl install.
dispatch_gsd() {
    local force=0 dry_run=0 yes=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ;;
            *) ;;
        esac
        shift
    done
    : "$force" "$yes"

    if [[ -n "${TK_DISPATCH_OVERRIDE_GSD:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] gsd (would run override: $TK_DISPATCH_OVERRIDE_GSD)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_GSD"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] get-shit-done (would run: $TK_GSD_INSTALL_CMD)"
        return 0
    fi
    eval "$TK_GSD_INSTALL_CMD"
}

# dispatch_toolkit — init-claude.sh (curl-pipe) or init-local.sh (local).
dispatch_toolkit() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ; pass_args+=("--dry-run") ;;
            --yes)     yes=1     ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$yes"

    if [[ -n "${TK_DISPATCH_OVERRIDE_TOOLKIT:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] toolkit (would run override: $TK_DISPATCH_OVERRIDE_TOOLKIT)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_TOOLKIT" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] toolkit (would run: bash <(curl -sSL $TK_REPO_URL/scripts/init-claude.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/init-claude.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path init-claude.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_security — setup-security.sh.
dispatch_security() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    if [[ -n "${TK_DISPATCH_OVERRIDE_SECURITY:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] security (would run override: $TK_DISPATCH_OVERRIDE_SECURITY)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_SECURITY" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] security (would run: bash <(curl -sSL $TK_REPO_URL/scripts/setup-security.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/setup-security.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path setup-security.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_rtk — brew install rtk && rtk init -g.
dispatch_rtk() {
    local force=0 dry_run=0 yes=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ;;
            *) ;;
        esac
        shift
    done
    : "$force" "$yes"

    if [[ -n "${TK_DISPATCH_OVERRIDE_RTK:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] rtk (would run override: $TK_DISPATCH_OVERRIDE_RTK)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_RTK"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] rtk (would run: brew install rtk && rtk init -g </dev/null)"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        _dispatch_log_warning "brew not found — install Homebrew first: https://brew.sh"
        return 1
    fi
    brew install rtk && rtk init -g </dev/null
}

# dispatch_statusline — install-statusline.sh.
dispatch_statusline() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    if [[ -n "${TK_DISPATCH_OVERRIDE_STATUSLINE:-}" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] statusline (would run override: $TK_DISPATCH_OVERRIDE_STATUSLINE)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_STATUSLINE" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] statusline (would run: bash <(curl -sSL $TK_REPO_URL/scripts/install-statusline.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/install-statusline.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path install-statusline.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}
