#!/bin/bash

# Claude Code Toolkit — Cross-Platform CLI Installer Library (v4.9+)
# Source this file. Do NOT execute it directly.
#
# Exposes:
#   cli_detect <name>
#       Return 0 if `command -v <name>` succeeds, 1 otherwise. Idempotent;
#       NO caching (D-15 / CAT-04 / TUI-02): re-run on every TUI launch so
#       tools the user installs out-of-band between launches are picked up.
#       `command -v` is sub-millisecond — no perf justification for cache.
#
#   cli_install <name> <darwin_cmd> <linux_cmd>
#       uname -s dispatch (D-16). Runs <darwin_cmd> on Darwin, <linux_cmd>
#       on Linux. Anything else -> stderr error + return 2.
#       On macOS where <darwin_cmd> starts with 'brew ' and `command -v brew`
#       fails -> stderr hint + return 3 (D-18 fallback; NEVER auto-installs
#       Homebrew). Returns rc of the underlying installer otherwise.
#       NO sudo auto-prefix EVER (D-17).
#
#   cli_post_install_hint <hint>
#       Print "-> Next: <hint>" to stderr ONLY (D-21). stdout stays parseable
#       for downstream piping. Toolkit NEVER auto-executes browser-based
#       logins (wrangler login, supabase login, stripe login, nlm login) —
#       boundary is "config + hints", not "auth flows".
#
# Test seams:
#   TK_CLI_UNAME           Override `uname -s` output (mocked in tests).
#   TK_CLI_BREW_BIN        Override `command -v brew` resolution. Set to ""
#                          to simulate brew-absent; set to a stub path to
#                          simulate brew-present. When unset, falls back to
#                          `command -v brew`.
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter
#            caller error mode (mcp.sh:29 invariant). Errexit lives only in
#            scripts/install.sh and standalone executables.
# IMPORTANT: No `sudo` auto-prefix. EVER. (D-17). If <darwin_cmd> or
#            <linux_cmd> needs root privileges, the user gets a transparent
#            error from brew/apt/dpkg/curl and decides — toolkit never elevates
#            without explicit user action. Documented in DOCS-02 (Phase 35).
# IMPORTANT: No distro detection on Linux (D-19). The catalog `install.linux`
#            string is vendor-recommended; toolkit just runs it. If the command
#            fails, return its rc — don't try alternatives.

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

# -----------------------------------------------------------------------------
# Public: cli_detect <name>
# -----------------------------------------------------------------------------

# cli_detect <name> — return 0 if `command -v <name>` succeeds, 1 otherwise.
# Single-line implementation; idempotent; no side effects; NO caching (D-15).
# Re-run on every TUI launch — tools the user installs out-of-band must be
# picked up. `command -v` is sub-millisecond; caching adds stale-state risk
# without measurable perf benefit (mcp.sh:135-153 caches `claude mcp list`
# because that call is ~4s; this one is not).
cli_detect() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} cli_detect: missing argument" >&2
        return 1
    fi
    command -v "$name" >/dev/null 2>&1
}
