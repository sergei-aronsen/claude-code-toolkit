#!/bin/bash

# Claude Code Toolkit — Per-Component Dispatcher Library (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   TK_DISPATCH_ORDER  array — canonical install order (DISPATCH-01)
#   dispatch_superpowers  — invokes claude plugin install (TK_SP_INSTALL_CMD)
#   dispatch_gsd          — invokes upstream curl install (TK_GSD_INSTALL_CMD)
#   dispatch_toolkit      — invokes init-claude.sh (or local init-local.sh)
#   dispatch_security     — invokes setup-security.sh [--yes]
#   dispatch_rtk          — invokes brew install rtk && rtk init -g </dev/null
#   dispatch_statusline   — invokes install-statusline.sh [--yes]
#   dispatch_council      — invokes setup-council.sh (no flags wired today)
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
[[ -z "${CYAN:-}"   ]] && CYAN='\033[0;36m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'

# Canonical SP/GSD install commands.
#
# Audit C2: these used to be `eval "$TK_*_INSTALL_CMD"`, with the env-supplied
# value substituted into eval. The "TRUSTED" comment was wrong — an attacker
# who exports `TK_SP_INSTALL_CMD='rm -rf ~'` BEFORE the user runs `curl|bash`
# turns the install pipeline into RCE under the user's account.
#
# Lockdown:
#  - Default install commands are now baked into _dispatch_run_sp_default /
#    _dispatch_run_gsd_default (functions, no eval).
#  - The TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD env vars STILL exist for
#    dry-run display ("would run: ...") and for legitimate forks/mirrors,
#    but they are only executed when TK_TEST=1 is also set. In production
#    (TK_TEST unset / != "1") the env override is ignored and the hardcoded
#    function runs — overrides are documented to go through the
#    TK_DISPATCH_OVERRIDE_SUPERPOWERS / _GSD path-to-script seam instead.
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD="npx --yes get-shit-done-cc@${TK_GSD_NPM_VERSION:-1.42.2}"

# Hardcoded default execution paths — strings live in code, never in env.
_dispatch_run_sp_default() {
    claude plugin install 'superpowers@claude-plugins-official'
}

_dispatch_run_gsd_default() {
    # Audit 2026-05-14 H-1: mirror lib/bootstrap.sh:54-86 (PR #125). GSD
    # migrated from `curl|bash` to npm package `get-shit-done-cc`. The old
    # raw.githubusercontent.com/gsd-build/... URL now 404s — this dispatcher
    # was silently broken before. The npm path is also safer (registry
    # integrity hash, pinned version tag).
    local pkg_version="${TK_GSD_NPM_VERSION:-1.42.2}"
    if [[ ! "$pkg_version" =~ ^(latest|[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?)$ ]]; then
        _dispatch_log_warning "TK_GSD_NPM_VERSION '${pkg_version}' is not a semver/tag — refusing to install."
        return 1
    fi
    if ! command -v npx >/dev/null 2>&1; then
        _dispatch_log_warning "npx not on PATH — install Node.js first to use GSD."
        return 1
    fi
    npx --yes "get-shit-done-cc@${pkg_version}"
}

# Default repo URL (overridable for testing or fork installs).
# Audit H5: TK_TOOLKIT_REF pins to a tag/SHA (default `main`); TK_REPO_URL
# remains the highest-priority override (full URL with ref baked in).
[[ -z "${TK_TOOLKIT_REF:-}" ]] && TK_TOOLKIT_REF='main'
# Audit INF-MED-2 (2026-04-30 deep): allowlist guard — TK_TOOLKIT_REF flows
# raw into curl URLs. Reject anything outside the tag/SHA charset plus any
# `..` traversal. Tags / branches / SHAs do not contain `..`.
if ! [[ "$TK_TOOLKIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$TK_TOOLKIT_REF" == *..* ]]; then
    echo "Error: TK_TOOLKIT_REF must match [A-Za-z0-9._/-]+ and must not contain '..' (got: $TK_TOOLKIT_REF)" >&2
    return 1 2>/dev/null || exit 1
fi
[[ -z "${TK_REPO_URL:-}" ]] && TK_REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/${TK_TOOLKIT_REF}"

# Audit L4 — global rules §2: outgoing curl gets a real browser UA.
# Default mirrors lib/bootstrap.sh; safe to redefine here for callers
# that source dispatch.sh without also sourcing bootstrap.sh.
# shellcheck disable=SC2034
[[ -z "${TK_USER_AGENT:-}" ]] && TK_USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36'

# Audit INF-MED-3 (2026-04-30 deep): export so children inherit pinned ref +
# UA across `bash <(curl ...)` boundaries.
export TK_TOOLKIT_REF TK_USER_AGENT

# Canonical install order — DISPATCH-01 contract + BRIDGE-UX-01 (Phase 30) extension.
# Guard uses the variable-is-unset-or-empty form to avoid nounset errors.
if [[ -z "${TK_DISPATCH_ORDER[*]:-}" ]]; then
    # Skills BEFORE mcp-servers so the MCP "needs API key" follow-up block
    # is the LAST thing on screen — that block contains action items the
    # user must execute, so keeping it terminal-final maximises its
    # visibility (user feedback 2026-05-01).
    TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline council claude-memo gemini-bridge codex-bridge skills mcp-servers)
fi

# Internal log helpers — underscore prefix.
_dispatch_log_info()    { echo -e "${CYAN}i${NC} $1" >&2; }
_dispatch_log_warning() { echo -e "${YELLOW}!${NC} $1" >&2; }

# Curl-pipe vs local invocation detection (D-24, RESEARCH §4).
# install.sh exports TK_CURL_PIPE=1 when it detected curl|bash mode at boot.
# That env var is the authoritative signal — a lib sourced from /tmp/<lib>-XXX
# sees its own BASH_SOURCE[0] as the tmpfile path (NOT /dev/fd/*), so the local
# BASH_SOURCE/$0 heuristic returns false and the sibling fallback resolves to
# "/tmp/../X" (ENOENT, exit 127). Honour TK_CURL_PIPE first; fall back to the
# heuristic for callers that source dispatch.sh directly without install.sh.
_dispatch_is_curl_pipe() {
    if [[ "${TK_CURL_PIPE:-}" == "1" ]]; then
        return 0
    fi
    if [[ "${TK_CURL_PIPE:-}" == "0" ]]; then
        return 1
    fi
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

    # Audit H6: TK_DISPATCH_OVERRIDE_* is a TEST SEAM. Honour it only
    # when TK_TEST=1 — otherwise an attacker who sets the env var
    # gets arbitrary script execution under the user's account.
    # Same RCE class as the eval gate at lines 127-131.
    if [[ -n "${TK_DISPATCH_OVERRIDE_SUPERPOWERS:-}" && "${TK_TEST:-0}" == "1" ]]; then
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
    # Audit C2: only honour the env override when explicitly in test mode.
    # In production, run the hardcoded function — env vars cannot inject.
    if [[ "${TK_TEST:-0}" == "1" ]]; then
        eval "$TK_SP_INSTALL_CMD"
    else
        _dispatch_run_sp_default
    fi
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

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_GSD:-}" && "${TK_TEST:-0}" == "1" ]]; then
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
    # Audit C2: only honour the env override when explicitly in test mode.
    if [[ "${TK_TEST:-0}" == "1" ]]; then
        eval "$TK_GSD_INSTALL_CMD"
    else
        _dispatch_run_gsd_default
    fi
}

# dispatch_toolkit — init-claude.sh (curl-pipe) or init-local.sh (local).
dispatch_toolkit() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ; pass_args+=("--dry-run") ;;
            # Forward --yes so init-claude.sh skips its select_framework /
            # select_mode / Council interactive prompts (it learned --yes in
            # the same patch that surfaced this bug — user pressed ↑/↓ on a
            # raw `read` prompt and saw `^[[A^[[B` echo back).
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$yes"

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_TOOLKIT:-}" && "${TK_TEST:-0}" == "1" ]]; then
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

    # TK_DISPATCHED=1 tells init-claude.sh it is a sub-installer; it suppresses
    # its standalone finale ("Installation Complete!", recommend_*, "Verify",
    # "Restart Claude Code", "To remove", "Read POST_INSTALL.md") so the parent
    # install.sh can emit its own consolidated summary AFTER all dispatchers
    # finish (user report 2026-05-01: standalone finale appeared mid-flow).
    if _dispatch_is_curl_pipe; then
        TK_DISPATCHED=1 bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/init-claude.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path init-claude.sh)"
        TK_DISPATCHED=1 bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_security — setup-security.sh.
# Audit M1: --dry-run is honoured at the dispatcher level (prints "would run …"
# and exits 0). It is NOT passed through to setup-security.sh because that
# script fails-closed on unknown flags by design. If a future setup-security.sh
# learns --dry-run, also add it to its pass_args here.
dispatch_security() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Audit 2026-05-18 (v6.48.1): setup-security.sh fails-closed on unknown
            # flags (M3/M4). It accepts ONLY --yes today. --force must NOT be
            # passed through or the security install dies with "unknown flag:
            # --force" → exit 1. --force is still consumed at the dispatcher
            # level for parity with other dispatchers and dry-run rendering.
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_SECURITY:-}" && "${TK_TEST:-0}" == "1" ]]; then
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
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/setup-security.sh") ${pass_args[@]+"${pass_args[@]}"}
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

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_RTK:-}" && "${TK_TEST:-0}" == "1" ]]; then
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
    # Audit 2026-05-13: rtk is installed from homebrew-core (well-reviewed
    # trust boundary), but the wrapped install/init pair gives a third-party
    # tool privileged rewrite power over every Bash command (see
    # setup-security.sh combined PreToolUse hook). The hook itself now
    # re-checks rewrites via cc-safety-net (audit 2026-05-13 #4) — this
    # block surfaces the resolved version so the user/log shows what was
    # actually installed and pinned at install time. TK_RTK_MIN_VERSION can
    # opt the installer into refusing an older bottle.
    if ! brew install rtk; then
        _dispatch_log_warning "brew install rtk failed"
        return 1
    fi
    if command -v rtk >/dev/null 2>&1; then
        local rtk_version
        rtk_version="$(rtk --version 2>/dev/null | head -n1)"
        _dispatch_log_info "rtk installed: ${rtk_version:-unknown}"
        if [[ -n "${TK_RTK_MIN_VERSION:-}" ]] && [[ -n "$rtk_version" ]]; then
            # Strip leading non-digits, compare lexicographically on dotted
            # numerics. POSIX `sort -V` is GNU-only; fall back to a literal
            # equality / "starts with" check for the minimum case.
            local rtk_numeric
            rtk_numeric="$(echo "$rtk_version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
            if [[ -n "$rtk_numeric" && "$rtk_numeric" != "${TK_RTK_MIN_VERSION}" ]]; then
                local lowest
                lowest="$(printf '%s\n%s\n' "$rtk_numeric" "$TK_RTK_MIN_VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)"
                if [[ "$lowest" != "$TK_RTK_MIN_VERSION" ]]; then
                    _dispatch_log_warning "rtk ${rtk_numeric} is below TK_RTK_MIN_VERSION=${TK_RTK_MIN_VERSION} — aborting before rtk init"
                    return 1
                fi
            fi
        fi
    fi
    rtk init -g </dev/null
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

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_STATUSLINE:-}" && "${TK_TEST:-0}" == "1" ]]; then
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
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/install-statusline.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path install-statusline.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_council — setup-council.sh.
# Audit M1 parity: --dry-run is honoured at the dispatcher level (prints
# "would run …" and returns 0). Not passed through.
# Audit 2026-05-18 (v6.48.1): setup-council.sh has NO argument-parsing
# block (it never reads $@). Unknown flags are silently dropped, not
# fail-closed. Strip --force and --yes from pass_args so the dispatcher
# doesn't misrepresent target capability. The 7 interactive prompts in
# setup-council.sh are not currently bypassable — adding argparse +
# --yes wiring is deferred (council install rare in install.sh flow).
dispatch_council() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force" "$yes"

    # Audit H6: TK_TEST=1 gate (test seam, not a runtime override).
    if [[ -n "${TK_DISPATCH_OVERRIDE_COUNCIL:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] council (would run override: $TK_DISPATCH_OVERRIDE_COUNCIL)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_COUNCIL" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] council (would run: bash <(curl -sSL $TK_REPO_URL/scripts/setup-council.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/setup-council.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path setup-council.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_claude_memo — install-claude-memo.sh.
# Wires sergei-aronsen/claude-memo (persistent engineering memory: vault +
# SQLite/FTS5 + multilingual-e5-large embeddings + 4 SessionStart/End/
# PreCompact/Stop hooks). Heavy: pulls a ~1.1 GB embedding model on first
# run and merges hooks into ~/.claude/settings.json (shared global
# config), so we always pass --yes through when the parent install.sh
# is itself running --yes.
#
# Mirrors dispatch_council semantics: --dry-run is honoured at the
# dispatcher level (prints "would run …" and returns 0).
dispatch_claude_memo() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ; pass_args+=("--dry-run") ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) pass_args+=("$1") ;;
        esac
        shift
    done
    : "$force"

    if [[ -n "${TK_DISPATCH_OVERRIDE_CLAUDE_MEMO:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] claude-memo (would run override: $TK_DISPATCH_OVERRIDE_CLAUDE_MEMO)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_CLAUDE_MEMO" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] claude-memo (would run: bash <(curl -sSL $TK_REPO_URL/scripts/install-claude-memo.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/install-claude-memo.sh") ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path install-claude-memo.sh)"
        bash "$sibling" ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_mcp_servers — re-invokes install.sh in --mcps mode so the user
# sees the dedicated MCP catalog TUI (9 curated MCP servers). Spawning a
# sub-install is cheaper than embedding the catalog into the main TUI
# (would push the row count past 20 and crowd the screen).
dispatch_mcp_servers() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ; pass_args+=("--dry-run") ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) ;;
        esac
        shift
    done
    : "$force"

    if [[ -n "${TK_DISPATCH_OVERRIDE_MCP_SERVERS:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] mcp-servers (would run override: $TK_DISPATCH_OVERRIDE_MCP_SERVERS)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_MCP_SERVERS" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] mcp-servers (would run: bash <(curl -sSL $TK_REPO_URL/scripts/install.sh) --integrations${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    # v6.23.4: scrub TK_MCP_CATALOG_PATH from child env. Parent's
    # main-TUI pre-collection block (install.sh:1847+) exports
    # TK_MCP_CATALOG_PATH for its OWN mcp_catalog_load; the export
    # then propagates to children via inheritance. The v6.23.1 F-1
    # audit gate (install.sh:277) rejects any pre-set
    # TK_MCP_CATALOG_PATH without TK_TEST=1, so child install.sh
    # exits 1 before it can re-download the catalog itself. Unset
    # the var here so the child sees a clean slate and triggers its
    # own download (one extra ~16KB curl per dispatch — negligible).
    if _dispatch_is_curl_pipe; then
        env -u TK_MCP_CATALOG_PATH bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/install.sh") --integrations ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path install.sh)"
        env -u TK_MCP_CATALOG_PATH bash "$sibling" --integrations ${pass_args[@]+"${pass_args[@]}"}
    fi
}

# dispatch_skills — re-invokes install.sh in --skills mode so the user sees
# the dedicated Skills catalog TUI. Same rationale as dispatch_mcp_servers.
dispatch_skills() {
    local force=0 dry_run=0 yes=0
    local pass_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ; pass_args+=("--force") ;;
            --dry-run) dry_run=1 ; pass_args+=("--dry-run") ;;
            --yes)     yes=1     ; pass_args+=("--yes") ;;
            *) ;;
        esac
        shift
    done
    : "$force"

    if [[ -n "${TK_DISPATCH_OVERRIDE_SKILLS:-}" && "${TK_TEST:-0}" == "1" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
            echo "[+ INSTALL] skills (would run override: $TK_DISPATCH_OVERRIDE_SKILLS)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_SKILLS" ${pass_args[@]+"${pass_args[@]}"}
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] skills (would run: bash <(curl -sSL $TK_REPO_URL/scripts/install.sh) --skills${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    # v6.23.4: same env-scrub as dispatch_mcp_servers. See comment
    # there. Parent's TK_MCP_CATALOG_PATH leaks into child via env
    # inheritance and trips the F-1 audit gate at install.sh:277.
    if _dispatch_is_curl_pipe; then
        env -u TK_MCP_CATALOG_PATH bash <(curl -sSL -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/install.sh") --skills ${pass_args[@]+"${pass_args[@]}"}
    else
        local sibling
        sibling="$(_dispatch_sibling_path install.sh)"
        env -u TK_MCP_CATALOG_PATH bash "$sibling" --skills ${pass_args[@]+"${pass_args[@]}"}
    fi
}
