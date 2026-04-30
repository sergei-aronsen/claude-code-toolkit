#!/bin/bash

# Claude Code Toolkit — Centralized Detection v2 Library
# Source this file. Do NOT execute it directly.
# Sources detect.sh first (do not duplicate SP/GSD logic — DET-01).
# Exposes:
#   is_codex_installed        — BRIDGE-DET-02: command -v codex
#   is_gemini_installed       — BRIDGE-DET-01: command -v gemini
#   is_gsd_installed          — wraps HAS_GSD from detect.sh (DET-01)
#   is_rtk_installed          — DET-04: command -v rtk
#   is_security_installed     — DET-02: cc-safety-net on PATH AND hook wired
#   is_statusline_installed   — DET-03: ~/.claude/statusline.sh + statusLine key
#   is_superpowers_installed  — wraps HAS_SP from detect.sh (DET-01)
#   is_toolkit_installed      — DET-05: ~/.claude/toolkit-install.json exists
# Globals (write, optional): IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL IS_GEM IS_COD
# (cache vars, populated only if the caller invokes detect2_cache).
#
# IMPORTANT: No errexit/nounset/pipefail here — sourced files must not alter caller error mode.

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

# Source detect.sh — provides HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION.
# detect.sh ends with `detect_superpowers || true` + `detect_gsd`, so sourcing
# under set -e is safe (Risk 6 from RESEARCH.md §10).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)/../detect.sh"

# DET-01: SP/GSD wrappers — DO NOT re-implement filesystem probes; reuse detect.sh exports.
is_superpowers_installed() {
    [[ "${HAS_SP:-false}" == "true" ]]
}

# BRIDGE-DET-02: OpenAI Codex CLI presence (binary on PATH).
# Soft cross-check: ~/.codex/ dir as confirmation only — CLI-PATH wins on conflict.
# Fail-soft: absent CLI returns 1 with no stderr, no warning.
is_codex_installed() {
    command -v codex >/dev/null 2>&1
}

# BRIDGE-DET-01: Google Gemini CLI presence (binary on PATH).
# Soft cross-check: ~/.gemini/ dir as confirmation only — CLI-PATH wins on conflict.
# Fail-soft: absent CLI returns 1 with no stderr, no warning.
is_gemini_installed() {
    command -v gemini >/dev/null 2>&1
}

is_gsd_installed() {
    [[ "${HAS_GSD:-false}" == "true" ]]
}

# DET-05: toolkit install state file (single source of truth, written by init-claude.sh).
is_toolkit_installed() {
    [[ -f "$HOME/.claude/toolkit-install.json" ]]
}

# DET-02: cc-safety-net hook AND wired into pre-bash.sh OR settings.json.
# Fixes v4.4 regression where brew-installed cc-safety-net was missed.
# Returns 0 only when binary exists AND a wiring check succeeds — incomplete
# install (binary present, hook absent) returns 1.
#
# Audit M5: previously `grep -q "cc-safety-net"` matched inside string values,
# Markdown comments, plugin metadata fields, or `_disabled_cc-safety-net` keys —
# false-positive "installed". Hook file remains a grep (it's a shell script, not
# JSON). settings.json now uses python3+json to walk hooks.PreToolUse[*].hooks[*]
# .command and require the substring INSIDE an actual command field. Falls back
# to grep only when python3 is absent (rare on macOS/Linux).
is_security_installed() {
    if ! command -v cc-safety-net >/dev/null 2>&1; then
        return 1
    fi
    local hooks_file="$HOME/.claude/hooks/pre-bash.sh"
    local settings_file="$HOME/.claude/settings.json"
    # The combined hook script is owned by TK and is plain bash — grep is safe.
    if [[ -f "$hooks_file" ]] && grep -q "cc-safety-net" "$hooks_file" 2>/dev/null; then
        return 0
    fi
    if [[ -f "$settings_file" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$settings_file" <<'PYEOF' 2>/dev/null && return 0
import json, sys
try:
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
except Exception:
    sys.exit(1)
for entry in (cfg.get('hooks', {}).get('PreToolUse', []) or []):
    for h in (entry.get('hooks', []) or []):
        cmd = h.get('command', '')
        if isinstance(cmd, str) and ('cc-safety-net' in cmd or 'pre-bash.sh' in cmd):
            sys.exit(0)
sys.exit(1)
PYEOF
        else
            # Fallback: anchor inside a JSON `"command": "..."` field.
            if grep -qE '"command"[[:space:]]*:[[:space:]]*"[^"]*(cc-safety-net|pre-bash\.sh)' \
                    "$settings_file" 2>/dev/null; then
                return 0
            fi
        fi
    fi
    return 1
}

# DET-04: PATH-agnostic RTK probe (covers brew /opt/homebrew/bin AND /usr/local/bin).
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}

# DET-03: statusline.sh exists AND statusLine key wired in settings.json.
# Top-level "statusLine" key per install-statusline.sh — NOT ".statusLine.enabled".
# Audit S-LOW-1 (2026-04-30 deep): bare `grep -q '"statusLine"'` matched any
# substring "statusLine" inside a description/comment field, or keys like
# "statusLine_disabled". Match the canonical key shape ("statusLine" followed
# by `:`) via `grep -E`, with a python+json fallback for hardened matching.
is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    local settings="$HOME/.claude/settings.json"
    [[ -f "$settings" ]] || return 1
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
except Exception:
    sys.exit(1)
sys.exit(0 if "statusLine" in cfg else 1)' "$settings" 2>/dev/null
    else
        grep -qE '"statusLine"[[:space:]]*:' "$settings" 2>/dev/null
    fi
}

# Optional helper: cache all probes into IS_* vars. Callers that need
# the cache pattern (D-23) call this once at startup, then re-probe before
# each dispatch.
detect2_cache() {
    IS_SP=0;  is_superpowers_installed && IS_SP=1  || true
    IS_GSD=0; is_gsd_installed         && IS_GSD=1 || true
    IS_TK=0;  is_toolkit_installed     && IS_TK=1  || true
    IS_SEC=0; is_security_installed    && IS_SEC=1 || true
    IS_RTK=0; is_rtk_installed         && IS_RTK=1 || true
    IS_SL=0;  is_statusline_installed  && IS_SL=1  || true
    IS_COD=0; is_codex_installed       && IS_COD=1 || true
    IS_GEM=0; is_gemini_installed      && IS_GEM=1 || true
    export IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL IS_COD IS_GEM
}
