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

# Audit L4 — global rules §2: every outgoing HTTP request must use a real
# browser User-Agent so origin servers, CDNs and rate-limit shields don't
# treat us as a default `curl/8.x` client (which several hosts now
# silently drop or 403). Constant is shared by every script that sources
# bootstrap.sh OR runs a fresh shell that re-sources it. Override with
# the env var only if you really need to (e.g. tests, traffic-tagging).
# shellcheck disable=SC2034  # exported for sourced consumers and inline curl callers
[[ -z "${TK_USER_AGENT:-}" ]] && TK_USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'

# Local log helpers — defined here because lib/install.sh does NOT export log_*.
# Shape mirrors scripts/uninstall.sh:71-74. Use these instead of raw echo for consistency.
_bootstrap_log_info()    { echo -e "${BLUE}ℹ${NC} $1" >&2; }
_bootstrap_log_warning() { echo -e "${YELLOW}⚠${NC} $1" >&2; }

# _bootstrap_prompt_and_run <plugin_name> <prompt_text> <cmd_string>
# Renders one [y/N] prompt; on y, evals $cmd; failure is non-fatal.
# Audit C2: bootstrap previously eval'd $cmd from env. Same RCE shape as
# dispatch.sh — an attacker who exports TK_BOOTSTRAP_SP_CMD before curl|bash
# turned the install pipeline into shell injection. Now the runner takes a
# function name (bash builtin / function — no shell parser involvement) and
# only falls back to eval when TK_TEST=1.
_bootstrap_run_sp_default() {
    claude plugin install 'superpowers@claude-plugins-official'
}

_bootstrap_run_gsd_default() {
    # Audit H1: GSD installer is a third-party `curl|bash` over HTTPS only.
    # No checksum, no GPG signature, no pinned commit — repo takeover or
    # account hijack of `gsd-build` becomes RCE under the installing user.
    # Guarded by:
    #   1) the [y/N] prompt in _bootstrap_prompt_and_run (see below),
    #   2) an extra explicit URL display + warning here so the user has the
    #      target visible before bytes are executed,
    #   3) optional integrity check via TK_GSD_PIN_SHA256 — when set, the
    #      installer is downloaded to a tempfile, sha256 verified, then run.
    local url='https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh'
    _bootstrap_log_warning "About to fetch + execute third-party installer:"
    _bootstrap_log_warning "  $url"
    _bootstrap_log_warning "  This runs arbitrary upstream code under your account."
    if [[ -n "${TK_GSD_PIN_SHA256:-}" ]]; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/gsd-installer.XXXXXX.sh")
        # Audit M3: shell-safe trap registration (printf '%q' for paths with `'`).
        local _quoted_tmp
        _quoted_tmp=$(printf '%q' "$tmp")
        # shellcheck disable=SC2064
        trap "rm -f $_quoted_tmp" RETURN
        if ! curl -sSLf -A "$TK_USER_AGENT" --max-time 60 --connect-timeout 10 --retry 2 "$url" -o "$tmp"; then
            _bootstrap_log_warning "GSD installer download failed — aborting."
            return 1
        fi
        local actual
        if command -v sha256sum >/dev/null 2>&1; then
            actual=$(sha256sum "$tmp" | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            actual=$(shasum -a 256 "$tmp" | awk '{print $1}')
        else
            _bootstrap_log_warning "Neither sha256sum nor shasum found — cannot verify TK_GSD_PIN_SHA256. Aborting."
            return 1
        fi
        if [[ "$actual" != "$TK_GSD_PIN_SHA256" ]]; then
            _bootstrap_log_warning "GSD installer SHA-256 mismatch:"
            _bootstrap_log_warning "  expected: $TK_GSD_PIN_SHA256"
            _bootstrap_log_warning "  actual:   $actual"
            _bootstrap_log_warning "Aborting."
            return 1
        fi
        _bootstrap_log_info "GSD installer SHA-256 verified"
        bash "$tmp"
        return $?
    fi
    bash <(curl -sSL -A "$TK_USER_AGENT" --max-time 60 --connect-timeout 10 --retry 2 "$url")
}

_bootstrap_prompt_and_run() {
    local plugin_name="$1" prompt_text="$2" runner="$3"
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
            if [[ "${TK_TEST:-0}" == "1" && -n "${TK_BOOTSTRAP_OVERRIDE_CMD:-}" ]]; then
                # Test seam: only when TK_TEST=1 AND an explicit override is set.
                # shellcheck disable=SC2294
                eval "$TK_BOOTSTRAP_OVERRIDE_CMD" || rc=$?
            else
                "$runner" || rc=$?
            fi
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

    # SP prompt block — idempotency, missing-CLI, then prompt.
    if [[ -d "$sp_dir" ]]; then
        _bootstrap_log_info "superpowers already installed — skipping."
    elif ! command -v claude >/dev/null 2>&1; then
        _bootstrap_log_warning "claude CLI not on PATH — superpowers bootstrap skipped (install Claude Code first)."
    else
        TK_BOOTSTRAP_OVERRIDE_CMD="${TK_BOOTSTRAP_SP_CMD:-${TK_SP_INSTALL_CMD:-}}" \
            _bootstrap_prompt_and_run "superpowers" \
                "Install superpowers via plugin marketplace? [y/N] " \
                _bootstrap_run_sp_default
    fi

    # GSD prompt block — independent of SP.
    # Audit H1: prompt copy now flags the third-party + curl|bash nature so a
    # user defaulting to "y" sees the trust boundary before pressing enter.
    if [[ -d "$gsd_dir" ]]; then
        _bootstrap_log_info "get-shit-done already installed — skipping."
    else
        TK_BOOTSTRAP_OVERRIDE_CMD="${TK_BOOTSTRAP_GSD_CMD:-${TK_GSD_INSTALL_CMD:-}}" \
            _bootstrap_prompt_and_run "get-shit-done" \
                "Install get-shit-done? Runs third-party curl|bash from raw.githubusercontent.com/gsd-build/get-shit-done (set TK_GSD_PIN_SHA256 to verify). [y/N] " \
                _bootstrap_run_gsd_default
    fi

    return 0
}
