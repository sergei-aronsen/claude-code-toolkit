---
phase: 24
plan: 03
type: execute
wave: 2
depends_on:
  - 24-01
files_modified:
  - scripts/lib/dispatch.sh
  - scripts/setup-security.sh
  - scripts/install-statusline.sh
autonomous: true
requirements:
  - DISPATCH-01
  - DISPATCH-02
requirements_addressed:
  - DISPATCH-01
  - DISPATCH-02
tags: bash,dispatch,lib,phase-24

must_haves:
  truths:
    - "dispatch.sh exposes six dispatchers (superpowers, gsd, toolkit, security, rtk, statusline)"
    - "Each dispatcher accepts --force, --dry-run, --yes and passes them through (or no-ops) per RESEARCH §6 flag inventory"
    - "Curl-pipe vs local invocation auto-detected via BASH_SOURCE[0] and $0 (D-24)"
    - "setup-security.sh accepts --yes flag without erroring; existing four steps still run (no behavior change today)"
    - "install-statusline.sh accepts --yes flag as no-op without erroring"
    - "TK_DISPATCH_OVERRIDE_<NAME> env var test seam: when set, dispatcher execs the override script with parsed flags appended"
    - "Dispatch order constant TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline) per DISPATCH-01"
    - "Each dispatcher returns the underlying script's exit code unchanged (no wrapping)"
  artifacts:
    - path: "scripts/lib/dispatch.sh"
      provides: "Six per-component dispatcher functions + canonical order constant"
      contains: "dispatch_superpowers dispatch_gsd dispatch_toolkit dispatch_security dispatch_rtk dispatch_statusline TK_DISPATCH_ORDER"
    - path: "scripts/setup-security.sh"
      provides: "Existing security setup + new --yes flag accepted without error"
      contains: "--yes"
    - path: "scripts/install-statusline.sh"
      provides: "Existing statusline install + new --yes flag accepted without error (no-op)"
      contains: "--yes"
  key_links:
    - from: "scripts/lib/dispatch.sh"
      to: "scripts/lib/optional-plugins.sh"
      via: "uses TK_SP_INSTALL_CMD and TK_GSD_INSTALL_CMD constants"
      pattern: "TK_SP_INSTALL_CMD|TK_GSD_INSTALL_CMD"
    - from: "scripts/lib/dispatch.sh"
      to: "scripts/init-claude.sh / scripts/setup-security.sh / scripts/install-statusline.sh"
      via: "curl-pipe mode: bash <(curl ...); local mode: bash $SCRIPT_DIR/<sibling>.sh"
      pattern: "BASH_SOURCE.*0.*== /dev/fd"
    - from: "scripts/setup-security.sh"
      to: "argument loop"
      via: "--yes case branch sets YES=1"
      pattern: "--yes.*YES=1"
    - from: "scripts/install-statusline.sh"
      to: "argument loop"
      via: "--yes case branch sets YES=1 (no-op)"
      pattern: "--yes.*YES=1"
---

<objective>
Create `scripts/lib/dispatch.sh` — a sourced lib exposing six per-component dispatcher functions (`dispatch_superpowers`, `dispatch_gsd`, `dispatch_toolkit`, `dispatch_security`, `dispatch_rtk`, `dispatch_statusline`) plus a canonical order constant `TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)`.

Each dispatcher:

1. Parses `--force`, `--dry-run`, `--yes` flags and passes them through to the underlying installer (or no-ops as appropriate per RESEARCH §6 flag inventory)
2. Auto-detects curl-pipe vs local invocation via `[[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]` (D-24)
3. Honors `TK_DISPATCH_OVERRIDE_<NAME>` env var as a test seam (when set, exec's the override instead of the real installer — mirrors `TK_BOOTSTRAP_SP_CMD` pattern from v4.4)
4. Returns the underlying script's exit code unchanged

Also patch `scripts/setup-security.sh` and `scripts/install-statusline.sh` to accept the `--yes` flag without erroring (DISPATCH-02). Both scripts have ZERO existing interactive `read` prompts today (verified RESEARCH §1, §6) — the flag is a parse-and-store no-op for symmetry with the dispatch contract.

Purpose: Plan 04 (`scripts/install.sh`) calls `dispatch_<name>` for each user-selected component. Without this lib, the orchestrator would have to inline subprocess invocation per component. Without the `--yes` patches, the dispatcher would have to special-case which scripts accept which flags.

Output: `scripts/lib/dispatch.sh` (new sourced lib) + minimal flag-parsing additions to `setup-security.sh` and `install-statusline.sh`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-CONTEXT.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-01-SUMMARY.md
@scripts/lib/optional-plugins.sh
@scripts/lib/bootstrap.sh
@scripts/lib/detect2.sh
@scripts/setup-security.sh
@scripts/install-statusline.sh
@scripts/uninstall.sh

<canonical_refs>
- 24-PATTERNS.md §"scripts/lib/dispatch.sh (new sourced lib, subprocess dispatcher)" (lines 226-294) — lib header pattern, flag parsing, curl-pipe detection, idempotency skip
- 24-PATTERNS.md §"scripts/setup-security.sh (modified)" (lines 519-545) — minimal flag parsing addition pattern
- 24-PATTERNS.md §"scripts/install-statusline.sh (modified)" (lines 547-565) — minimal flag parsing addition pattern
- 24-RESEARCH.md §6 "Dispatch Layer" (lines 502-589) — flag inventory matrix, function signatures, curl-pipe detection, RTK install path
- 24-RESEARCH.md §10 Risk 8 (rtk init -g interactivity) — pipe /dev/null fallback
- 24-RESEARCH.md §10 Risk 9 (install-statusline.sh exits 1 on Linux) — continue-on-error pattern
- 24-CONTEXT.md D-24 (curl-pipe vs local), D-25 (dispatcher contract), D-26 (--yes treatment per script)
- scripts/lib/optional-plugins.sh:18-19 — TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD constants
- scripts/uninstall.sh:26-46 — argument-loop case-block pattern to mirror in dispatchers
</canonical_refs>

<interfaces>
From scripts/lib/optional-plugins.sh:16-19 (constants to reuse, NOT redefine):

```bash
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'
```

From scripts/uninstall.sh:26-46 (the argument loop case-block style to mirror):

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   force=1 ;;
        --dry-run) dry_run=1 ;;
        --yes)     yes=1 ;;
        *) ;;
    esac
    shift
done
```

Full canonical install commands per RESEARCH §6:

- toolkit: `bash <(curl -sSL $TK_REPO_URL/scripts/init-claude.sh) [--force]`
- security: `bash <(curl -sSL $TK_REPO_URL/scripts/setup-security.sh) [--yes] [--force]`
- statusline: `bash <(curl -sSL $TK_REPO_URL/scripts/install-statusline.sh) [--yes]`
- rtk: `brew install rtk && rtk init -g </dev/null` (no TK script; pipe /dev/null per RESEARCH §10 Risk 8)

Test seam pattern: `TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>` env var (e.g. `TK_DISPATCH_OVERRIDE_TOOLKIT`) — when set, dispatcher execs the override script with parsed flags appended, instead of curling+invoking the real installer. Mirrors v4.4 `TK_BOOTSTRAP_SP_CMD` shape.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create scripts/lib/dispatch.sh — six dispatchers + TK_DISPATCH_ORDER constant (DISPATCH-01)</name>
  <files>scripts/lib/dispatch.sh</files>

  <read_first>
    - scripts/lib/optional-plugins.sh (lines 1-42) — analog file; reuse TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD
    - scripts/lib/bootstrap.sh (lines 1-99) — pattern reference for sourced-lib header, color guards, no-errexit comment
    - scripts/init-claude.sh (lines 1-58) — argument loop pattern, REPO_URL constant, color codes
    - scripts/uninstall.sh (lines 26-46) — flag-parsing case-block style
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/lib/dispatch.sh" (lines 226-294)
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §6 (lines 502-589)
  </read_first>

  <behavior>
    - Sourcing scripts/lib/dispatch.sh under `set -euo pipefail` exits 0 (no errcascade)
    - All six dispatcher functions defined; each takes [--force] [--dry-run] [--yes] in any order
    - TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline) array initialized when unset (matches DISPATCH-01)
    - dispatch_<name> with --dry-run prints "[+ INSTALL] <name> (would run: <command>)" and returns 0 without executing
    - dispatch_<name> with TK_DISPATCH_OVERRIDE_<NAME>=<path> set: execs the override script with parsed flags, returns its exit code
    - Without --dry-run and without TK_DISPATCH_OVERRIDE_<NAME>: invokes the real installer via curl-pipe (when BASH_SOURCE[0] is /dev/fd/* or $0 is bash) or local sibling path otherwise
    - dispatch_rtk pipes `</dev/null` to handle RESEARCH §10 Risk 8 (rtk init -g interactivity)
  </behavior>

  <action>
Create `scripts/lib/dispatch.sh` with this exact structure (executor MUST keep function names, the TK_DISPATCH_ORDER array, the override seam name, and curl-pipe detection logic verbatim; minor whitespace differences acceptable):

```bash
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
if [[ "${#TK_DISPATCH_ORDER[@]}" -eq 0 ]]; then
    TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)
fi

# Internal log helpers — underscore prefix.
_dispatch_log_info()    { echo -e "${BLUE}ℹ${NC} $1" >&2; }
_dispatch_log_warning() { echo -e "${YELLOW}⚠${NC} $1" >&2; }

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
        if [[ "$dry_run" -eq 1 && "${#pass_args[@]}" -eq 0 ]]; then
            echo "[+ INSTALL] toolkit (would run override: $TK_DISPATCH_OVERRIDE_TOOLKIT)"
            return 0
        fi
        bash "$TK_DISPATCH_OVERRIDE_TOOLKIT" "${pass_args[@]}"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] toolkit (would run: bash <(curl -sSL $TK_REPO_URL/scripts/init-claude.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/init-claude.sh") "${pass_args[@]}"
    else
        local sibling
        sibling="$(_dispatch_sibling_path init-claude.sh)"
        bash "$sibling" "${pass_args[@]}"
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
        bash "$TK_DISPATCH_OVERRIDE_SECURITY" "${pass_args[@]}"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] security (would run: bash <(curl -sSL $TK_REPO_URL/scripts/setup-security.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/setup-security.sh") "${pass_args[@]}"
    else
        local sibling
        sibling="$(_dispatch_sibling_path setup-security.sh)"
        bash "$sibling" "${pass_args[@]}"
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
        bash "$TK_DISPATCH_OVERRIDE_STATUSLINE" "${pass_args[@]}"
        return $?
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] statusline (would run: bash <(curl -sSL $TK_REPO_URL/scripts/install-statusline.sh)${pass_args[*]:+ ${pass_args[*]}})"
        return 0
    fi

    if _dispatch_is_curl_pipe; then
        bash <(curl -sSL "$TK_REPO_URL/scripts/install-statusline.sh") "${pass_args[@]}"
    else
        local sibling
        sibling="$(_dispatch_sibling_path install-statusline.sh)"
        bash "$sibling" "${pass_args[@]}"
    fi
}
```

Critical rules:

1. **NO `set -euo pipefail`** anywhere in this file (sourced lib).
2. **NO `eval` of user-controlled input** — only `eval "$TK_SP_INSTALL_CMD"` and `eval "$TK_GSD_INSTALL_CMD"` which are project-controlled constants from optional-plugins.sh. The dispatcher does NOT eval any user-controlled string (T-24-01 mitigation: hardcoded component names; no user-controlled string passes to bash -c).
3. **Test seam name**: `TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>` for each of the 6 components. Uppercase, no dashes — name component is mapped: superpowers → SUPERPOWERS, get-shit-done → GSD, install-statusline → STATUSLINE.
4. **Curl-pipe detection** (D-24): `[[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]`. Local-mode fallback resolves via `${SCRIPT_DIR}/../<sibling>` because dispatch.sh lives in `scripts/lib/`.
5. **dispatch_rtk** pipes `</dev/null` to `rtk init -g` per RESEARCH §10 Risk 8.
6. **shellcheck SC2034 silencing**: each dispatcher has `: "$var"` lines for unused parsed flags.

Implements DISPATCH-01 (six dispatchers in canonical TK_DISPATCH_ORDER). Sets up `--yes` pass-through plumbing; the actual `--yes` flag-parsing additions in the underlying scripts come in Task 2.
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/lib/dispatch.sh && bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh && for f in dispatch_superpowers dispatch_gsd dispatch_toolkit dispatch_security dispatch_rtk dispatch_statusline; do [[ "$(type -t "$f")" == "function" ]] || { echo "MISSING: $f"; exit 1; }; done; echo "${TK_DISPATCH_ORDER[*]}" | grep -q "^superpowers gsd toolkit security rtk statusline$" && echo all-six-dispatchers-and-order-ok'</automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/lib/dispatch.sh` exists
    - Sourcing under `set -euo pipefail` exits 0
    - All six functions defined as `function` type: `dispatch_superpowers`, `dispatch_gsd`, `dispatch_toolkit`, `dispatch_security`, `dispatch_rtk`, `dispatch_statusline`
    - Helper functions `_dispatch_is_curl_pipe`, `_dispatch_sibling_path`, `_dispatch_log_info`, `_dispatch_log_warning` defined
    - After source: `${TK_DISPATCH_ORDER[*]}` equals `superpowers gsd toolkit security rtk statusline`
    - File contains exact string `# IMPORTANT: No errexit/nounset/pipefail` (sourced-lib invariant)
    - File does NOT contain `set -euo pipefail`
    - File contains `TK_DISPATCH_OVERRIDE_SUPERPOWERS`, `TK_DISPATCH_OVERRIDE_GSD`, `TK_DISPATCH_OVERRIDE_TOOLKIT`, `TK_DISPATCH_OVERRIDE_SECURITY`, `TK_DISPATCH_OVERRIDE_RTK`, `TK_DISPATCH_OVERRIDE_STATUSLINE` (all six test seams)
    - File contains `BASH_SOURCE[0]:-` AND `/dev/fd/*` (D-24 curl-pipe detection)
    - File contains `rtk init -g </dev/null` (RESEARCH §10 Risk 8 mitigation)
    - File contains `eval "$TK_SP_INSTALL_CMD"` AND `eval "$TK_GSD_INSTALL_CMD"` (canonical install command invocation)
    - Smoke test: `bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; dispatch_toolkit --dry-run' | grep -q "INSTALL.*toolkit"` exits 0
    - `shellcheck -S warning scripts/lib/dispatch.sh` exits 0
  </acceptance_criteria>

  <done>
    Lib sourceable; six dispatchers defined; canonical order constant set; test seams in place. Ready for Plan 04 to drive end-to-end orchestration.
  </done>
</task>

<task type="auto">
  <name>Task 2: Patch --yes flag into setup-security.sh and install-statusline.sh (DISPATCH-02)</name>
  <files>scripts/setup-security.sh, scripts/install-statusline.sh</files>

  <read_first>
    - scripts/setup-security.sh (full file, 1-280) — current implementation; NO existing argument loop today
    - scripts/install-statusline.sh (full file) — current implementation; NO existing argument loop today
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/setup-security.sh (modified)" (lines 519-545) — exact addition pattern
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/install-statusline.sh (modified)" (lines 547-565) — exact addition pattern
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §6 + §1 — verified BOTH scripts have zero existing interactive `read` prompts
    - 24-CONTEXT.md D-26 — `setup-security.sh` learns a real `--yes` flag (gates future interactive prompts; today is no-op since current code has zero `read -r -p` blocks); `install-statusline.sh` learns `--yes` as accepted-but-no-op (semantic symmetry; the script is already non-interactive)
  </read_first>

  <behavior>
    setup-security.sh:
    - `bash scripts/setup-security.sh --yes` exits with the same exit code it would without the flag (DISPATCH-02 contract: parse-and-no-op today)
    - `bash scripts/setup-security.sh` without `--yes` continues to behave byte-identically to v4.4 (no other flag changes)
    - `bash scripts/setup-security.sh --unknown-flag` warns "unknown flag: --unknown-flag (ignoring)" but continues (does NOT abort)
    - `YES=1` is exposed as a script-level variable that future interactive `read -r -p` blocks can guard with `[[ "$YES" -eq 1 ]] || read ...` (per D-26 future-proofing)

    install-statusline.sh:
    - `bash scripts/install-statusline.sh --yes` on macOS with valid keychain token completes successfully (same behavior as no flag)
    - `bash scripts/install-statusline.sh --yes` on Linux still exits 1 with the existing "requires macOS" error (no-op flag does not bypass platform check)
    - `bash scripts/install-statusline.sh` without `--yes` continues to behave byte-identically to v4.4
    - The script's existing `set -euo pipefail` continues to fire on actual errors
  </behavior>

  <action>
This task makes parallel sibling edits: ~10 lines added to each of two scripts. Both share identical parse-and-no-op semantics (DISPATCH-02 contract); both insert their argument loop AFTER color constants and BEFORE `REPO_URL`. Pattern is intentionally near-identical so future engineers can read either as a reference for the other.

**Edit 1 — `scripts/setup-security.sh`:**

The current `scripts/setup-security.sh` has NO argument loop (verified by reading the file). Insert a minimal argument loop right after the color constants block (currently around lines 18-24). The file already has `set -euo pipefail` at line 16, so the argument-loop code runs under errexit; that's fine.

Use the Edit tool to find the exact block:

```bash
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
```

Replace with:

```bash
NC='\033[0m'

# DISPATCH-02 — accept --yes for symmetry with TUI dispatch contract.
# Today the script has zero interactive `read -r -p` blocks, so YES=1 is a
# parse-and-store no-op. Future interactive prompts can guard with:
#   [[ "$YES" -eq 1 ]] || read -r -p "..." choice
# Unknown flags are warned (not fatal) so the dispatcher can pass new flags
# through without breaking older versions of the script.
YES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) YES=1 ;;
        *) echo -e "${YELLOW}⚠${NC} unknown flag: $1 (ignoring)" ;;
    esac
    shift
done
: "${YES}"  # silence shellcheck SC2034 — YES consumed by future read blocks

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
```

**Edit 2 — `scripts/install-statusline.sh`:**

The current `scripts/install-statusline.sh` has NO argument loop. Insert one right after the color constants (currently lines 8-13). Use the Edit tool to find:

```bash
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
```

Replace with:

```bash
NC='\033[0m'

# DISPATCH-02 — accept --yes as no-op for symmetry with TUI dispatch contract.
# install-statusline.sh has zero interactive `read -r -p` blocks (it reads only
# from the macOS Keychain, which has no interactive prompt component). YES=1 is
# parse-and-store today; future-proof against any interactive prompt added later.
YES=0
for _arg in "$@"; do
    case "$_arg" in
        --yes) YES=1 ;;
        *) echo -e "${YELLOW}⚠${NC} unknown flag: $_arg (ignoring)" ;;
    esac
done
: "${YES}"  # silence shellcheck SC2034 — no-op stub today

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
```

Critical rules (apply to BOTH files):

1. The argument loop comes AFTER color constants (so `${YELLOW}` is already defined for the warning) and BEFORE `REPO_URL` (so REPO_URL stays at its current line position relative to the rest of the script).
2. The `*)` branch warns but does NOT exit — DISPATCH-02 contract is "accept --yes" not "validate every flag". Other flags would never reach this script via the dispatcher today, but the warning prevents future surprises.
3. `: "${YES}"` is the project's idiomatic shellcheck SC2034 silencer (mirrors scripts/init-claude.sh:60-64 pattern).
4. Do NOT add any logic that USES `$YES` today — the variable is a contract surface for future interactive prompts. Adding usage now would change behavior, violating D-26.

File-specific notes:

- **setup-security.sh** uses `while [[ $# -gt 0 ]]` + `shift` (preserves $@ contract for future flag pass-through).
- **install-statusline.sh** uses `for _arg in "$@"` loop instead — both work equivalently for parse-only; the for-loop is shorter and matches the simpler semantic ("we just iterate flags, we never shift them away"). The macOS check at `if [[ "$(uname)" != "Darwin" ]]` runs AFTER the argument loop — meaning `--yes --some-other-flag` still reaches the platform check and exits 1 on Linux. This is correct per RESEARCH §10 Risk 9 (continue-on-error in the dispatcher handles the exit-1 result).

Implements DISPATCH-02 (real `--yes` flag accepted by setup-security.sh; no-op `--yes` flag accepted by install-statusline.sh; no behavior change today; future interactive prompts can guard with `$YES`).
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/setup-security.sh scripts/install-statusline.sh && grep -q "YES=0" scripts/setup-security.sh && grep -q '\-\-yes) YES=1' scripts/setup-security.sh && grep -q "YES=0" scripts/install-statusline.sh && grep -q '\-\-yes) YES=1' scripts/install-statusline.sh && bash -n scripts/setup-security.sh && bash -n scripts/install-statusline.sh && echo both-yes-flags-added</automated>
  </verify>

  <acceptance_criteria>
    setup-security.sh:
    - contains `YES=0` declaration
    - contains `--yes) YES=1` case branch (or equivalent: `--yes) YES=1 ;;`)
    - contains the argument loop `while [[ $# -gt 0 ]]` block
    - `shellcheck -S warning scripts/setup-security.sh` exits 0
    - `bash -n scripts/setup-security.sh` exits 0 (syntax check)
    - `bash scripts/tests/test-setup-security-rtk.sh` exits 0 (existing test stays green; the RTK-related test is not affected by argument-loop addition)

    install-statusline.sh:
    - contains `YES=0` declaration
    - contains `--yes) YES=1` case branch
    - contains the for-loop `for _arg in "$@"` block
    - `shellcheck -S warning scripts/install-statusline.sh` exits 0
    - `bash -n scripts/install-statusline.sh` exits 0 (syntax check)
    - Smoke: on macOS, `bash scripts/install-statusline.sh --yes` does not produce a `--yes: command not found` or unknown-flag error from bash's argument parser (the script's argument loop intercepts it). [Note: full execution may still fail at Keychain step if no valid token exists; that's expected behavior, not an argument-handling regression.]
  </acceptance_criteria>

  <done>
    Both scripts accept `--yes` flag without erroring. Existing logic in both scripts unchanged (parse-and-store no-op today). Future interactive prompts in either script can guard with `[[ "$YES" -eq 1 ]]`.
  </done>
</task>

<task type="auto">
  <name>Task 3: Smoke-test full Wave 2 contract (dispatch.sh end-to-end with mock dispatchers)</name>
  <files>scripts/lib/dispatch.sh, scripts/setup-security.sh, scripts/install-statusline.sh</files>

  <read_first>
    - scripts/lib/dispatch.sh (just created)
    - scripts/setup-security.sh (just patched)
    - scripts/install-statusline.sh (just patched)
  </read_first>

  <action>
Run four end-to-end smoke checks to validate the Wave 2 contract before committing.

Check 1 — All six dispatchers under --dry-run produce the expected stdout:

```bash
bash -c '
set -euo pipefail
source scripts/lib/dispatch.sh
dispatch_superpowers --dry-run
dispatch_gsd          --dry-run
dispatch_toolkit      --dry-run
dispatch_security     --dry-run --yes
dispatch_rtk          --dry-run
dispatch_statusline   --dry-run --yes
' | tee /tmp/dispatch-dry-run.out
grep -q "INSTALL.*superpowers"  /tmp/dispatch-dry-run.out
grep -q "INSTALL.*get-shit-done" /tmp/dispatch-dry-run.out
grep -q "INSTALL.*toolkit"       /tmp/dispatch-dry-run.out
grep -q "INSTALL.*security"      /tmp/dispatch-dry-run.out
grep -q "INSTALL.*rtk"           /tmp/dispatch-dry-run.out
grep -q "INSTALL.*statusline"    /tmp/dispatch-dry-run.out
rm -f /tmp/dispatch-dry-run.out
echo all-six-dry-run-ok
```
Expected: prints `all-six-dry-run-ok`.

Check 2 — TK_DISPATCH_OVERRIDE_<NAME> seam works (mock dispatcher invoked):

```bash
TMP_MOCK=$(mktemp /tmp/mock-toolkit.XXXXXX)
printf '#!/bin/bash\necho mock-toolkit-ran\nexit 0\n' > "$TMP_MOCK"
chmod +x "$TMP_MOCK"
bash -c "
set -euo pipefail
source scripts/lib/dispatch.sh
TK_DISPATCH_OVERRIDE_TOOLKIT='$TMP_MOCK'
dispatch_toolkit --force
" | tee /tmp/dispatch-override.out
grep -q "mock-toolkit-ran" /tmp/dispatch-override.out
rm -f /tmp/dispatch-override.out "$TMP_MOCK"
echo override-seam-ok
```
Expected: prints `override-seam-ok`.

Check 3 — setup-security.sh accepts --yes without erroring:

```bash
bash -n scripts/setup-security.sh
# Don't actually run it (would touch ~/.claude); just confirm syntax + flag accepted.
# Run only the argument-loop subset by extracting the first 30 lines:
echo 'echo $YES' >> /tmp/security-flag-test.sh
head -30 scripts/setup-security.sh > /tmp/security-flag-test.sh
echo 'echo "YES=$YES"' >> /tmp/security-flag-test.sh
bash /tmp/security-flag-test.sh --yes 2>&1 | tee /tmp/security-yes-test.out
grep -q "YES=1" /tmp/security-yes-test.out
rm -f /tmp/security-flag-test.sh /tmp/security-yes-test.out
echo setup-security-yes-ok
```

Note: this approximation extracts the first 30 lines (color block + argument loop) and adds a print statement. If the argument loop is fully contained in those lines, the test passes. If the loop was placed deeper, expand the head count to 40.

Expected: prints `setup-security-yes-ok`.

Check 4 — BACKCOMPAT-01 invariant: test-bootstrap.sh stays green (existing 26 assertions unchanged):

```bash
bash scripts/tests/test-bootstrap.sh
```
Expected: exit 0 with `PASS=26 FAIL=0` (or whatever the v4.4 assertion count is — the key signal is FAIL=0).

If any check fails, fix the offending file and re-run that check before proceeding to Task 4.
  </action>

  <verify>
    <automated>bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; for d in dispatch_superpowers dispatch_gsd dispatch_toolkit dispatch_security dispatch_rtk dispatch_statusline; do "$d" --dry-run | grep -q "INSTALL" || { echo "FAIL: $d"; exit 1; }; done; echo all-six-ok' && bash scripts/tests/test-bootstrap.sh > /tmp/bootstrap-after.log 2>&1 && grep -q "FAIL=0" /tmp/bootstrap-after.log && rm -f /tmp/bootstrap-after.log</automated>
  </verify>

  <acceptance_criteria>
    - All six dispatchers print "INSTALL" line under --dry-run (Check 1 passes)
    - TK_DISPATCH_OVERRIDE_TOOLKIT seam invokes mock script (Check 2 passes)
    - setup-security.sh argument loop sets YES=1 when --yes is passed (Check 3 passes)
    - test-bootstrap.sh exits 0 with FAIL=0 (Check 4 passes — BACKCOMPAT-01 invariant)
  </acceptance_criteria>

  <done>
    Wave 2 contract validated end-to-end. Dispatcher functional across all six components. v4.4 BOOTSTRAP-01..04 contract preserved.
  </done>
</task>

<task type="auto">
  <name>Task 4: make check + commit Wave 2 deliverables</name>
  <files>scripts/lib/dispatch.sh, scripts/setup-security.sh, scripts/install-statusline.sh</files>

  <read_first>
    - Makefile (lines 36-43)
  </read_first>

  <action>
1. Run `shellcheck -S warning scripts/lib/dispatch.sh scripts/setup-security.sh scripts/install-statusline.sh` — must exit 0.
2. Commit the three files together as ONE atomic commit (Wave 2 deliverable):

```bash
git add scripts/lib/dispatch.sh scripts/setup-security.sh scripts/install-statusline.sh
git commit -m "$(cat <<'EOF'
feat(24): add lib/dispatch.sh + --yes flag wiring (DISPATCH-01..02)

DISPATCH-01: scripts/lib/dispatch.sh exposes six dispatchers
(dispatch_superpowers, dispatch_gsd, dispatch_toolkit, dispatch_security,
dispatch_rtk, dispatch_statusline) and the canonical install order
constant TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk
statusline).

Each dispatcher accepts [--force] [--dry-run] [--yes] flags; --dry-run
prints the would-run command without invocation. Curl-pipe vs local
detection via [[ BASH_SOURCE[0] == /dev/fd/* || \$0 == bash ]] (D-24).
Test seam TK_DISPATCH_OVERRIDE_<NAME> mirrors v4.4 TK_BOOTSTRAP_SP_CMD
shape: when set, dispatcher execs the override script with parsed flags
appended.

dispatch_rtk pipes </dev/null to rtk init -g per RESEARCH §10 Risk 8.
dispatch_security and dispatch_statusline pass --yes through; the
underlying scripts now accept --yes (DISPATCH-02).

DISPATCH-02: scripts/setup-security.sh and scripts/install-statusline.sh
gain a --yes flag. Both scripts have zero interactive read prompts today
(verified RESEARCH §1, §6) — the flag is a parse-and-store no-op for
symmetry with the dispatch contract. Future interactive prompts can
guard with [[ "\$YES" -eq 1 ]] || read -r -p ...

Refs: 24-CONTEXT.md D-24..D-26, 24-RESEARCH.md §6 (dispatch layer),
§10 Risk 8 (rtk).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/lib/dispatch.sh scripts/setup-security.sh scripts/install-statusline.sh && git log -1 --pretty=%B | head -1 | grep -q '^feat(24): add lib/dispatch.sh + --yes flag wiring' && git show --stat HEAD | grep -E 'scripts/(lib/dispatch.sh|setup-security.sh|install-statusline.sh)' | wc -l | grep -q '^[ ]*3$'</automated>
  </verify>

  <acceptance_criteria>
    - shellcheck passes on all three files
    - Most recent commit subject: `feat(24): add lib/dispatch.sh + --yes flag wiring (DISPATCH-01..02)`
    - Commit modifies exactly three files: `scripts/lib/dispatch.sh`, `scripts/setup-security.sh`, `scripts/install-statusline.sh`
    - test-bootstrap.sh still passes after the commit (`bash scripts/tests/test-bootstrap.sh` exits 0)
  </acceptance_criteria>

  <done>
    Plan 03 lands as a single conventional commit. Wave 2 dispatch lib + --yes wiring ready for Plan 04 orchestrator.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| install.sh orchestrator → dispatch.sh | Component name is hardcoded by the orchestrator (always one of the 6 in TK_DISPATCH_ORDER); not user-supplied free-form |
| dispatch.sh → curl|bash subprocess | Repo URL constant TK_REPO_URL is project-controlled; flag set passed to subprocess is also project-controlled |
| user shell → setup-security.sh / install-statusline.sh | New --yes flag accepted; unknown flags warn but don't abort |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-01 | Tampering / Code injection | `dispatch_<name>` invokes installers via `bash -c "..."` — command injection vector if component name were user-controlled | mitigate | Hardcoded component-name allowlist in TK_DISPATCH_ORDER. The orchestrator (install.sh, Plan 04) never passes user input to dispatch_<name> — it iterates the canonical array. The dispatcher ONLY evals project-controlled constants TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD; for toolkit / security / statusline, it uses `bash <(curl ...) "${pass_args[@]}"` where pass_args is itself parsed from a hardcoded flag set (--force / --dry-run / --yes) — not arbitrary input |
| T-24-03 | Tampering | `bash <(curl -sSL .../install.sh)` supply-chain risk | accept | Out of scope for Phase 24 (BACKCOMPAT-01 — same risk as v4.4 init-claude.sh); documented for completeness |
| T-24-09 | Information disclosure | `--dry-run` output reveals TK_REPO_URL in stdout | accept | URL is public (raw.githubusercontent.com on a public repo); no secret exposure |
| T-24-10 | Denial of service | Mock dispatcher via TK_DISPATCH_OVERRIDE_* could runaway | accept | Test-only seam; user already controls their env; same risk class as v4.4 TK_BOOTSTRAP_SP_CMD |
</threat_model>

<verification>
After Task 4 completes:

```bash
# Lib loads cleanly
bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; echo loaded-clean'

# All six dispatchers + canonical order
bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; for d in "${TK_DISPATCH_ORDER[@]}"; do type -t "dispatch_$d"; done'

# All six --dry-run print "INSTALL" line
bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; for d in "${TK_DISPATCH_ORDER[@]}"; do dispatch_"$d" --dry-run | head -1; done' | grep -c "^\[+ INSTALL\]"

# setup-security.sh and install-statusline.sh accept --yes
grep -q "YES=0" scripts/setup-security.sh
grep -q '\-\-yes) YES=1' scripts/setup-security.sh
grep -q "YES=0" scripts/install-statusline.sh
grep -q '\-\-yes) YES=1' scripts/install-statusline.sh

# BACKCOMPAT-01 regression
bash scripts/tests/test-bootstrap.sh

# Lint
shellcheck -S warning scripts/lib/dispatch.sh scripts/setup-security.sh scripts/install-statusline.sh
```
</verification>

<success_criteria>
- `scripts/lib/dispatch.sh` exists with six dispatchers + TK_DISPATCH_ORDER constant
- All six dispatchers accept `--force`, `--dry-run`, `--yes` and pass them through (or no-op) appropriately
- TK_DISPATCH_OVERRIDE_<NAME> test seam present for all six (mirrors v4.4 pattern)
- Curl-pipe detection via BASH_SOURCE[0] / $0 (D-24)
- dispatch_rtk pipes /dev/null to rtk init -g (RESEARCH §10 Risk 8)
- `scripts/setup-security.sh` accepts `--yes` flag (DISPATCH-02 contract; today no-op since zero interactive reads exist)
- `scripts/install-statusline.sh` accepts `--yes` flag as no-op (DISPATCH-02 symmetry)
- test-bootstrap.sh stays green (BACKCOMPAT-01)
- shellcheck clean across all three files
- Single conventional commit `feat(24): add lib/dispatch.sh + --yes flag wiring (DISPATCH-01..02)`
</success_criteria>

<output>
After Plan 03 completes, create `.planning/phases/24-unified-tui-installer-centralized-detection/24-03-SUMMARY.md` describing:
- Files created: `scripts/lib/dispatch.sh`
- Files modified: `scripts/setup-security.sh` (added `--yes` flag), `scripts/install-statusline.sh` (added `--yes` no-op flag)
- Public API: six dispatcher functions + TK_DISPATCH_ORDER constant
- Test seam contract: TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>
- Curl-pipe vs local detection logic (D-24)
- Decisions implemented: D-04 (TK_SP/GSD_INSTALL_CMD reuse), D-24, D-25, D-26
- Requirements addressed: DISPATCH-01, DISPATCH-02
- Downstream contract: Plan 04 sources this lib from install.sh; iterates `TK_DISPATCH_ORDER` to dispatch components in canonical order
</output>
