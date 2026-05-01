#!/bin/bash

# Claude Code Toolkit — Unified Install Orchestrator (v4.5+)
#
# Single entry point that:
#   1. Sources lib/{tui,detect2,dispatch}.sh (local clone or curl|bash)
#   2. Detects already-installed components
#   3. Renders TUI checklist (or bypasses with --yes)
#   4. Prompts for confirmation
#   5. Dispatches selected components in canonical order (DISPATCH-01)
#   6. Prints per-component status summary
#
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
# Flags: --yes --no-color --dry-run --force --fail-fast --no-banner
#
# Backwards compat: scripts/init-claude.sh URL is unchanged. This is a new
# parallel entry point. The 26-assertion test-bootstrap.sh stays green.

set -euo pipefail

# Colors (always defined; gated at output time by NO_COLOR / [ -t 1 ])
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
NC='\033[0m'


# Audit L4 — global rules §2: every outgoing curl gets a real browser UA.
# shellcheck disable=SC2034
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"
# Audit INF-MED-3 (2026-04-30 deep): export so child sub-installers spawned
# via `bash <(curl -sSL $REPO_URL/...)` inherit the pinned ref + UA instead
# of silently falling back to defaults (e.g., TK_TOOLKIT_REF=main).
export TK_TOOLKIT_REF TK_USER_AGENT
# Config
# Audit H5: TK_TOOLKIT_REF pins to a tag/SHA (default `main`); TK_REPO_URL
# remains the highest-priority override (full URL with ref baked in).
TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-main}"
# Audit INF-MED-2 (2026-04-30 deep): allowlist guard — TK_TOOLKIT_REF flows
# raw into curl URLs. Reject anything outside the tag/SHA charset, plus any
# `..` traversal sequence. Tags / branches / SHAs do not contain `..`.
if ! [[ "$TK_TOOLKIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$TK_TOOLKIT_REF" == *..* ]]; then
    echo "Error: TK_TOOLKIT_REF must match [A-Za-z0-9._/-]+ and must not contain '..' (got: $TK_TOOLKIT_REF)" >&2
    exit 1
fi
TK_REPO_URL="${TK_REPO_URL:-https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/${TK_TOOLKIT_REF}}"
NO_BANNER=${NO_BANNER:-0}

# Flags (defaults)
YES=0
DRY_RUN=0
FORCE=0
FAIL_FAST=0
MCPS=0
SKILLS=0
SKILLS_ONLY=0
NO_BRIDGES=false
BRIDGES_FORCE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)         YES=1;                 shift ;;
        --no-color)    NO_COLOR=1;  export NO_COLOR; shift ;;
        --dry-run)     DRY_RUN=1;             shift ;;
        --force)       FORCE=1;               shift ;;
        --fail-fast)   FAIL_FAST=1;           shift ;;
        --no-banner)   NO_BANNER=1;           shift ;;
        --no-bridges)  NO_BRIDGES=true;       shift ;;
        --bridges)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --bridges requires a comma-separated target list (e.g. --bridges gemini,codex)" >&2
                exit 1
            fi
            BRIDGES_FORCE="$2"; shift 2 ;;
        --mcps)        MCPS=1;                shift ;;
        --skills)      SKILLS=1;              shift ;;
        --skills-only) SKILLS_ONLY=1; SKILLS=1; shift ;;
        -h|--help)
            cat <<USAGE
Usage: bash scripts/install.sh [flags]

Flags:
  --yes         Skip TUI; install all uninstalled components in canonical order
  --yes --force Skip TUI; re-run all components regardless of detection
  --dry-run     Show what would run without invoking any installer
  --force       Re-run already-installed components
  --fail-fast   Stop on first component failure (default: continue-on-error)
  --no-color    Disable ANSI output (also honored via NO_COLOR env)
  --no-banner   Suppress closing removal banner
  --no-bridges  Skip Gemini/Codex bridge prompts unconditionally (env: TK_NO_BRIDGES=1)
  --bridges LIST  Force-create bridges for comma-listed CLIs (e.g. gemini,codex)
  --mcps        Install curated MCP servers via TUI catalog (Phase 25)
  --skills      Install curated skills via TUI catalog (Phase 26)
  --skills-only Install skills to Desktop tree (~/.claude/plugins/tk-skills/);
                auto-activates when 'claude' CLI is absent on PATH (DESK-03)

Backwards compatible: scripts/init-claude.sh URL still works unchanged.
USAGE
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Run: bash scripts/install.sh --help"
            exit 1
            ;;
    esac
done

# BRIDGE-UX-03 + BRIDGE-UX-04: --no-bridges and --bridges are mutually exclusive.
# Mirrors the v4.4 --no-bootstrap / --bootstrap-only precedent (exit 2 on user-error).
if [[ "$NO_BRIDGES" == "true" && -n "$BRIDGES_FORCE" ]]; then
    echo -e "${RED}Error:${NC} --no-bridges and --bridges are mutually exclusive" >&2
    exit 2
fi
# TK_NO_BRIDGES=1 env-var equivalent of --no-bridges (BRIDGE-UX-03 symmetry).
if [[ "${TK_NO_BRIDGES:-}" == "1" ]]; then
    NO_BRIDGES=true
fi
# Re-check mutex after env-var coalesce (TK_NO_BRIDGES=1 + --bridges X also exit 2).
if [[ "$NO_BRIDGES" == "true" && -n "$BRIDGES_FORCE" ]]; then
    echo -e "${RED}Error:${NC} --no-bridges (or TK_NO_BRIDGES=1) and --bridges are mutually exclusive" >&2
    exit 2
fi

# ─────────────────────────────────────────────────
# Source the three Phase 24 libs.
# Detect curl|bash via BASH_SOURCE/$0; in that case download libs to mktemp.
# ─────────────────────────────────────────────────
CLEANUP_PATHS=()
run_cleanup() {
    if [[ ${#CLEANUP_PATHS[@]} -gt 0 ]]; then
        rm -f "${CLEANUP_PATHS[@]}" || true
    fi
}
trap 'run_cleanup' EXIT

_is_curl_pipe() {
    [[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]
}

# Export curl-pipe state so libs sourced from /tmp/<lib>-XXX (where their
# own BASH_SOURCE[0] is the tmpfile path, not /dev/fd/*) can detect it.
# dispatch.sh (D-24) reads this to choose between curl-fetch and sibling
# resolution — without it, sibling falls back to "/tmp/../X" → ENOENT 127.
if _is_curl_pipe; then
    export TK_CURL_PIPE=1
else
    export TK_CURL_PIPE=0
fi

# Audit I5: every curl in the install path needs network-safety flags so a
# hung TCP socket can't pin the bootstrap forever. _tk_curl_safe wraps the
# canonical `-sSLf` with --max-time / --connect-timeout / --retry. Errors out
# on HTTP 4xx/5xx (-f) so we never source a 502 HTML body as shell code.
_tk_curl_safe() {
    curl -sSLf -A "$TK_USER_AGENT" \
        --max-time 60 --connect-timeout 10 \
        --retry 2 --retry-delay 2 \
        "$@"
}

_source_lib() {
    local lib_name="$1"
    if _is_curl_pipe; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/${lib_name}-XXXXXX")
        CLEANUP_PATHS+=("$tmp")
        if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/${lib_name}.sh" -o "$tmp"; then
            echo -e "${RED}✗${NC} Failed to download lib/${lib_name}.sh — aborting"
            exit 1
        fi
        # shellcheck source=/dev/null
        source "$tmp"
    else
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
        # shellcheck source=/dev/null
        source "${script_dir}/lib/${lib_name}.sh"
    fi
}

# detect2.sh sources detect.sh internally via relative path. When running curl|bash,
# the relative path doesn't resolve, so we must source detect.sh first manually.
if _is_curl_pipe; then
    DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect-XXXXXX")
    CLEANUP_PATHS+=("$DETECT_TMP")
    if ! _tk_curl_safe "$TK_REPO_URL/scripts/detect.sh" -o "$DETECT_TMP"; then
        echo -e "${RED}✗${NC} Failed to download detect.sh — aborting"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
fi

_source_lib dry-run-output
_source_lib detect2
_source_lib tui
_source_lib dispatch
# state MUST source BEFORE bridges — bridges.sh:46-53 has a sibling-source
# fallback that relative-resolves state.sh from BASH_SOURCE; under curl|bash
# that path becomes /tmp/state.sh which doesn't exist and aborts under set -e.
# Mirrors commit 18a7039 (same class of bug fixed for init-claude.sh).
_source_lib state
_source_lib bridges

# MCPS=1 path needs the MCP catalog + wizard library.
if [[ "$MCPS" -eq 1 ]]; then
    _source_lib mcp
    # Under curl|bash, mcp.sh sourced from /tmp/mcp-XXX resolves
    # _mcp_default_catalog_path to /tmp/mcp-catalog.json which doesn't exist
    # → "Failed to load MCP catalog" exit 1 (user report 2026-05-01). Download
    # the catalog to a tmpfile and point TK_MCP_CATALOG_PATH at it.
    #
    # Skip when TK_MCP_CATALOG_PATH already exported by the parent flow's
    # UX-FLOW-01 pre-collection block (install.sh top-level → dispatch_mcps
    # → install.sh --mcps inherits the env). A second mktemp on the same
    # template under heavy /tmp churn produced "mkstemp failed: File exists"
    # (user report 2026-05-01) and the duplicate download is wasteful anyway.
    if _is_curl_pipe && [[ -z "${TK_MCP_CATALOG_PATH:-}" ]]; then
        MCP_CATALOG_TMP=$(mktemp "${TMPDIR:-/tmp}/mcp-catalog-XXXXXX.json")
        CLEANUP_PATHS+=("$MCP_CATALOG_TMP")
        if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/mcp-catalog.json" -o "$MCP_CATALOG_TMP"; then
            echo -e "${RED}✗${NC} Failed to download mcp-catalog.json — aborting" >&2
            exit 1
        fi
        export TK_MCP_CATALOG_PATH="$MCP_CATALOG_TMP"
    fi
fi

# SKILLS=1 path needs the skills catalog + cp-R installer.
# NOTE: DESK-03 auto-routing may set SKILLS=1 later (after argparse), so we
# re-check after the routing block below and source skills.sh then if needed.

# Initialize colors for the dro_* family (used by summary).
dro_init_colors

# ─────────────────────────────────────────────────
# Detection cache (D-23)
# ─────────────────────────────────────────────────
detect2_cache

# ─────────────────────────────────────────────────
# Per-component status string (D-27) — defined here so both the MCP routing
# branch (below) and the components summary (further down) can call it.
# Uses dro_* color vars set by dro_init_colors above.
# ─────────────────────────────────────────────────
print_install_status() {
    local component="$1" state="$2"
    case "$state" in
        # MCPs registered without env vars: render yellow so the row
        # visually flags "still needs config" without looking like failure.
        "installed (needs API key)") printf '  %b%-30s %s%b\n' "${_DRO_Y:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        installed*)     printf '  %b%-30s %s%b\n' "${_DRO_G:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        would-install)  printf '  %b%-30s %s%b\n' "${_DRO_C:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        skipped)        printf '  %b%-30s %s%b\n' "${_DRO_Y:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        failed*)        printf '  %b%-30s %s%b\n' "${_DRO_R:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        *)              printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}

# ─────────────────────────────────────────────────
# Routing gate: --mcps takes the MCP page; --skills (or --skills-only / Desktop
# auto-route) takes the Skills page; default is the Phase 24 components page.
# Mutex — exactly one of three branches per invocation.
# ─────────────────────────────────────────────────

# --mcps and --skills are mutually exclusive: exactly one of three branches runs per invocation.
if [[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 && "$SKILLS_ONLY" -eq 0 ]]; then
    echo -e "${RED}✗${NC} --mcps and --skills are mutually exclusive" >&2
    exit 1
fi

# ─────────────────────────────────────────────────
# DESK-03: Desktop-only auto-routing.
# Trigger condition (all must hold):
#   - `command -v claude` returns non-zero (CLI absent)
#   - no explicit page flag set (--mcps, --skills, --skills-only)
#   - --yes not passed (CI / non-interactive paths get the components branch)
# When triggered: promote to --skills-only mode + print explanatory banner.
# ─────────────────────────────────────────────────
TK_DESKTOP_ONLY=0
if ! command -v claude >/dev/null 2>&1; then
    TK_DESKTOP_ONLY=1
fi

AUTO_SKILLS_ONLY=0
if [[ "$TK_DESKTOP_ONLY" -eq 1 \
      && "$MCPS" -eq 0 \
      && "$SKILLS" -eq 0 \
      && "$SKILLS_ONLY" -eq 0 \
      && "$YES" -eq 0 ]]; then
    AUTO_SKILLS_ONLY=1
    SKILLS_ONLY=1
    SKILLS=1
fi

if [[ "$SKILLS_ONLY" -eq 1 ]]; then
    export TK_SKILLS_HOME="$HOME/.claude/plugins/tk-skills"
    if [[ "$AUTO_SKILLS_ONLY" -eq 1 ]]; then
        echo ""
        echo -e "${YELLOW}!${NC} Claude CLI not detected — installing skills only."
        echo "  Skills available in Claude Desktop Code tab."
        echo "  See docs/CLAUDE_DESKTOP.md for full capability matrix."
        echo ""
    else
        echo ""
        echo -e "${CYAN}i${NC} --skills-only mode: skills install to ~/.claude/plugins/tk-skills/"
        echo ""
    fi
fi

# Source skills lib now — covers both explicit --skills/--skills-only (SKILLS=1 at
# parse time) and DESK-03 auto-route (SKILLS=1 set above). Idempotent: sourcing
# twice is harmless, but in practice only one code path reaches this point.
if [[ "$SKILLS" -eq 1 ]]; then
    _source_lib skills
fi

if [[ "$MCPS" -eq 1 ]]; then
    # MCP catalog page — populate TUI_* arrays from the 9-MCP catalog.
    mcp_catalog_load || {
        echo -e "${RED}✗${NC} Failed to load MCP catalog" >&2
        exit 1
    }
    mcp_status_array

    # CLI-absent banner per CONTEXT.md "Failure & Degradation" — render but warn.
    if [[ "${MCP_CLI_PRESENT:-0}" -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}!${NC} claude CLI not found — MCPs cannot be installed from here."
        echo "  See docs/MCP-SETUP.md for the install path."
        echo ""
    fi

    # Selection precedence (UX-FLOW-01 + earlier policy):
    #   1. TK_MCP_PRE_SELECTED env  — pre-collected by the parent install.sh
    #      flow (the user picked these in an MCP sub-picker BEFORE any
    #      installation began). Empty value is meaningful: install zero MCPs.
    #      Set ⇒ skip TUI entirely (headless install).
    #   2. --yes / YES=1            — default-set (everything not installed,
    #      OAuth-only excluded unless --force).
    #   3. interactive TUI page     — render the catalog and let the user pick.
    TUI_RESULTS=()
    local_count=${#MCP_NAMES[@]}
    if [[ -n "${TK_MCP_PRE_SELECTED+x}" ]]; then
        # Headless. Comma-separated names → 0/1 per row by exact match against MCP_NAMES.
        # NOTE: this is top-level shell context (install.sh is a script body),
        # NOT a function, so `local` is illegal. Use plain assignments + an
        # underscore prefix to avoid clobbering the surrounding flow.
        _pre_csv="${TK_MCP_PRE_SELECTED:-}"
        _IFS_SAVE="$IFS"
        IFS=','
        # shellcheck disable=SC2206  # intentional word-split on ','
        _pre_arr=( $_pre_csv )
        IFS="$_IFS_SAVE"
        for ((i=0; i<local_count; i++)); do
            TUI_RESULTS[$i]=0
            for _pname in "${_pre_arr[@]+"${_pre_arr[@]}"}"; do
                if [[ "$_pname" == "${MCP_NAMES[$i]}" ]]; then
                    TUI_RESULTS[$i]=1
                    break
                fi
            done
        done
        unset _pre_csv _IFS_SAVE _pre_arr _pname
    elif [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; skip OAuth-only unless --force
        # (OAuth needs interactive browser flow — incompatible with --yes).
        for ((i=0; i<local_count; i++)); do
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
                continue
            fi
            if [[ "${MCP_OAUTH[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
                continue
            fi
            TUI_RESULTS[$i]=1
        done
    else
        # TTY check (mirrors Phase 24 _install_tty_src gate).
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ ! -r "$_install_tty_src" ]]; then
            echo "No TTY available for MCP TUI; pass --yes for non-interactive install."
            exit 0
        fi
        if ! tui_checklist; then
            echo "MCP install cancelled."
            exit 0
        fi
        # Submit row in tui_checklist IS the confirm — do not chain a y/N
        # prompt after the screen-clear (it renders invisibly below the prior
        # output, same regression PR #20 fixed for the main TUI).
        local_selected=0
        for ((i=0; i<${#TUI_RESULTS[@]}; i++)); do
            [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
        done
    fi

    # ─────────────────────────────────────────────
    # MCP dispatch loop (mirrors Phase 24 D-08 continue-on-error pattern).
    # ─────────────────────────────────────────────
    # Defer interactive secret prompts during install — user reported that
    # mid-install API-key prompts cause them to "never finish" the run
    # (2026-05-01). MCPs requiring env keys are skipped here and queued in
    # TK_MCP_DEFERRED_QUEUE for the post-install summary, which prints
    # exact `claude mcp add` commands to finish setup later.
    export TK_MCP_DEFER_SECRETS="${TK_MCP_DEFER_SECRETS:-1}"
    if [[ -z "${TK_MCP_DEFERRED_QUEUE:-}" ]]; then
        TK_MCP_DEFERRED_QUEUE=$(mktemp "${TMPDIR:-/tmp}/tk-mcp-deferred.XXXXXX") || TK_MCP_DEFERRED_QUEUE=""
        [[ -n "$TK_MCP_DEFERRED_QUEUE" ]] && CLEANUP_PATHS+=("$TK_MCP_DEFERRED_QUEUE")
        export TK_MCP_DEFERRED_QUEUE
    fi
    echo ""
    echo -e "${CYAN}Installing selected MCP(s)...${NC}"
    echo ""
    INSTALLED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0
    COMPONENT_STATUS=()
    COMPONENT_NAMES=()
    COMPONENT_STDERR_TAIL=()
    local_mcp_count=${#MCP_NAMES[@]}
    for ((i=0; i<local_mcp_count; i++)); do
        local_name="${MCP_NAMES[$i]}"
        COMPONENT_NAMES+=("$local_name")
        if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                COMPONENT_STATUS+=("skipped")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            fi
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Capture stderr to a per-MCP tmpfile (D-28).
        # Audit L2: do not embed the component name in the path so shared
        # `/tmp` on Linux can't enumerate which MCPs the user installs.
        stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-mcp.XXXXXX") || stderr_tmp=""
        [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

        local_flags=()
        [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")

        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
        else
            mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
        fi

        case "$local_rc" in
            0)
                if [[ "$DRY_RUN" -eq 1 ]]; then
                    COMPONENT_STATUS+=("would-install")
                else
                    COMPONENT_STATUS+=("installed ✓")
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                fi
                COMPONENT_STDERR_TAIL+=("")
                ;;
            2)
                COMPONENT_STATUS+=("skipped: claude unavailable")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            3)
                # rc=3 — server registered with claude CLI but has no env
                # binding yet (deferred-secrets path). Counted as installed
                # so the summary doesn't read like a failure; the follow-up
                # block tells the user how to add the key.
                COMPONENT_STATUS+=("installed (needs API key)")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            *)
                COMPONENT_STATUS+=("failed (exit $local_rc)")
                FAILED_COUNT=$((FAILED_COUNT + 1))
                local_tail=""
                if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
                    local_tail=$(tail -5 "$stderr_tmp")
                fi
                COMPONENT_STDERR_TAIL+=("$local_tail")
                if [[ "$FAIL_FAST" -eq 1 ]]; then
                    for ((j=i+1; j<local_mcp_count; j++)); do
                        COMPONENT_NAMES+=("${MCP_NAMES[$j]}")
                        COMPONENT_STATUS+=("skipped")
                        COMPONENT_STDERR_TAIL+=("")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    done
                    break
                fi
                ;;
        esac
    done

    # Print MCP install summary.
    echo ""
    echo -e "${CYAN}MCP install summary:${NC}"
    echo ""
    for ((i=0; i<${#COMPONENT_NAMES[@]}; i++)); do
        local_name="${COMPONENT_NAMES[$i]}"
        local_state="${COMPONENT_STATUS[$i]:-unknown}"
        print_install_status "$local_name" "$local_state"
        case "$local_state" in
            failed*)
                local_tail="${COMPONENT_STDERR_TAIL[$i]:-}"
                if [[ -n "$local_tail" ]]; then
                    while IFS= read -r tail_line; do
                        printf '      %s\n' "$tail_line"
                    done <<< "$local_tail"
                fi
                ;;
        esac
    done
    echo ""
    printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
        "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"

    # Follow-up block for MCPs registered without env vars. The servers are
    # already in `claude mcp list`; they just need API keys exported in the
    # shell that launches claude. claude CLI inherits the shell env and
    # passes it through to MCP child processes — no re-registration needed
    # when keys change.
    if [[ -n "${TK_MCP_DEFERRED_QUEUE:-}" && -s "$TK_MCP_DEFERRED_QUEUE" ]]; then
        # Auto-install the source line into shell rc if absent. Idempotent —
        # detects existing line via marker comment. User wanted "edit key,
        # restart claude, done" — adding the source line manually was an
        # extra friction step we can eliminate (2026-05-01).
        _shell_rc=""
        if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *zsh* ]]; then
            _shell_rc="$HOME/.zshrc"
        elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == *bash* ]]; then
            # macOS bash users typically rely on .bash_profile, Linux on .bashrc.
            if [[ "$(uname -s)" == "Darwin" ]]; then
                _shell_rc="$HOME/.bash_profile"
            else
                _shell_rc="$HOME/.bashrc"
            fi
        fi
        _rc_added=0
        _rc_marker="# claude-code-toolkit: source ~/.claude/mcp-config.env into shell env"
        if [[ -n "$_shell_rc" ]]; then
            if [[ -f "$_shell_rc" ]] && grep -qF "$_rc_marker" "$_shell_rc" 2>/dev/null; then
                _rc_added=2   # already present
            else
                {
                    printf '\n%s\n' "$_rc_marker"
                    printf 'set -a; [ -f ~/.claude/mcp-config.env ] && . ~/.claude/mcp-config.env; set +a\n'
                } >> "$_shell_rc" 2>/dev/null && _rc_added=1
            fi
        fi
        echo ""
        echo -e "${YELLOW}Some MCPs registered without API keys — finish setup:${NC}"
        echo ""
        echo "  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:"
        while IFS=$'\t' read -r d_name d_keys d_args; do
            [[ -z "$d_name" ]] && continue
            _IFS_SAVED2="$IFS"
            IFS=','
            for _k in $d_keys; do
                _k="${_k# }"
                [[ -z "$_k" ]] && continue
                printf '       %s=<your-key>\n' "$_k"
            done
            IFS="$_IFS_SAVED2"
        done < "$TK_MCP_DEFERRED_QUEUE"
        unset _k _IFS_SAVED2
        echo ""
        case "$_rc_added" in
            1) echo "  2) Shell rc updated: auto-source line added to ${_shell_rc/#$HOME/~}." ;;
            2) echo "  2) Shell rc already configured (auto-source line found in ${_shell_rc/#$HOME/~})." ;;
            *) echo "  2) Could not detect/write to your shell rc. Add this ONE line to ~/.zshrc (or ~/.bashrc) manually:"
               echo "       set -a; [ -f ~/.claude/mcp-config.env ] && . ~/.claude/mcp-config.env; set +a" ;;
        esac
        echo ""
        echo "  3) Reload shell env (open a fresh terminal, or run: exec \$SHELL) and start claude."
        echo ""
        echo "     When you change a key later: edit mcp-config.env, re-open claude. No"
        echo "     re-registration, no other commands — keys load at claude startup."
        unset _shell_rc _rc_added _rc_marker
    fi

    if [[ "${NO_BANNER:-0}" != "1" ]]; then
        echo ""
        echo "To remove an MCP: claude mcp remove <name>"
    fi
    if [[ $FAILED_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi
# ─────────────────────────────────────────────────
# Skills catalog page — --skills routing branch.
# Mirror of the --mcps branch above; reuses TUI_* globals + print_install_status.
# ─────────────────────────────────────────────────
if [[ "$SKILLS" -eq 1 ]]; then
    # Populate TUI_INSTALLED[] from the 22-skill catalog.
    skills_status_array

    # Build TUI globals from SKILLS_CATALOG.
    # shellcheck disable=SC2034  # consumed by tui_checklist
    TUI_LABELS=("${SKILLS_CATALOG[@]}")
    # shellcheck disable=SC2034
    TUI_GROUPS=()
    # shellcheck disable=SC2034
    TUI_DESCS=()
    local_total=${#SKILLS_CATALOG[@]}
    for ((i=0; i<local_total; i++)); do
        TUI_GROUPS+=("Skills")
        TUI_DESCS+=("Curated skill mirrored from upstream")
    done

    # Selection precedence (UX-FLOW-01 mirror of the MCP branch above):
    #   1. TK_SKILLS_PRE_SELECTED env (headless, pre-collected by parent flow)
    #   2. --yes default-set
    #   3. interactive TUI page
    TUI_RESULTS=()
    if [[ -n "${TK_SKILLS_PRE_SELECTED+x}" ]]; then
        # Top-level (install.sh script body) — `local` is illegal here.
        _pre_csv="${TK_SKILLS_PRE_SELECTED:-}"
        _IFS_SAVE="$IFS"
        IFS=','
        # shellcheck disable=SC2206  # intentional word-split on ','
        _pre_arr=( $_pre_csv )
        IFS="$_IFS_SAVE"
        for ((i=0; i<local_total; i++)); do
            TUI_RESULTS[$i]=0
            for _pname in "${_pre_arr[@]+"${_pre_arr[@]}"}"; do
                if [[ "$_pname" == "${SKILLS_CATALOG[$i]}" ]]; then
                    TUI_RESULTS[$i]=1
                    break
                fi
            done
        done
        unset _pre_csv _IFS_SAVE _pre_arr _pname
    elif [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; --force re-runs already-installed.
        for ((i=0; i<local_total; i++)); do
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
            else
                TUI_RESULTS[$i]=1
            fi
        done
    else
        # TTY check (mirrors Phase 25 _install_tty_src gate).
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ ! -r "$_install_tty_src" ]]; then
            echo "No TTY available for skills TUI; pass --yes for non-interactive install."
            exit 0
        fi
        if ! tui_checklist; then
            echo "Skills install cancelled."
            exit 0
        fi
        # Same rationale as MCP path: Submit row IS the confirm; the secondary
        # y/N prompt rendered invisibly after clear-screen (PR #20 regression
        # symmetry).
        local_selected=0
        for ((i=0; i<${#TUI_RESULTS[@]}; i++)); do
            [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
        done
    fi

    # ─────────────────────────────────────────────
    # Skills dispatch loop (mirrors Phase 25 D-08 continue-on-error pattern).
    # ─────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}Installing marketplace skills (global → ~/.claude/skills/)...${NC}"
    echo -e "  Distinct from project-local toolkit skill stubs in <project>/.claude/skills/"
    echo ""
    INSTALLED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0
    COMPONENT_STATUS=()
    COMPONENT_NAMES=()
    COMPONENT_STDERR_TAIL=()
    for ((i=0; i<local_total; i++)); do
        local_name="${SKILLS_CATALOG[$i]}"
        COMPONENT_NAMES+=("$local_name")
        if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                COMPONENT_STATUS+=("skipped")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            fi
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Dry-run shortcut: announce would-install without invoking skills_install.
        if [[ "$DRY_RUN" -eq 1 ]]; then
            COMPONENT_STATUS+=("would-install")
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Capture stderr to a per-skill tmpfile (D-28).
        # Audit L2: do not embed the component name in the path.
        stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-skill.XXXXXX") || stderr_tmp=""
        [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

        local_skill_args=()
        [[ "$FORCE" -eq 1 ]] && local_skill_args+=("--force")

        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( skills_install "$local_name" "${local_skill_args[@]+"${local_skill_args[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
        else
            skills_install "$local_name" "${local_skill_args[@]+"${local_skill_args[@]}"}" || local_rc=$?
        fi

        case "$local_rc" in
            0)
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            2)
                COMPONENT_STATUS+=("skipped: already installed (use --force)")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            *)
                COMPONENT_STATUS+=("failed (exit $local_rc)")
                FAILED_COUNT=$((FAILED_COUNT + 1))
                local_tail=""
                if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
                    local_tail=$(tail -5 "$stderr_tmp")
                fi
                COMPONENT_STDERR_TAIL+=("$local_tail")
                if [[ "$FAIL_FAST" -eq 1 ]]; then
                    for ((j=i+1; j<local_total; j++)); do
                        COMPONENT_NAMES+=("${SKILLS_CATALOG[$j]}")
                        COMPONENT_STATUS+=("skipped")
                        COMPONENT_STDERR_TAIL+=("")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    done
                    break
                fi
                ;;
        esac
    done

    # Print skills install summary using the soft-checkmark style of
    # init-claude.sh's "📥 Framework extras..." block — user feedback
    # 2026-05-01: bright green right-aligned "installed ✓" rows were
    # too loud for a 22-row catalog. Compact left-aligned format with
    # subtle green checkmark reads as a list, not a billboard.
    echo ""
    echo -e "${CYAN}Marketplace skills install summary (~/.claude/skills/):${NC}"
    for ((i=0; i<${#COMPONENT_NAMES[@]}; i++)); do
        local_name="${COMPONENT_NAMES[$i]}"
        local_state="${COMPONENT_STATUS[$i]:-unknown}"
        case "$local_state" in
            "installed ✓"|installed)
                printf '  %b✓%b %s\n' "${GREEN}" "${NC}" "$local_name"
                ;;
            "would-install")
                # Keep the literal "would-install" token in dry-run output —
                # tests + downstream tooling parse it. Soft-checkmark style
                # only applies to the live install path.
                printf '  %b·%b %-30s would-install\n' "${CYAN}" "${NC}" "$local_name"
                ;;
            failed*)
                printf '  %b✗%b %s — %s\n' "${RED}" "${NC}" "$local_name" "$local_state"
                local_tail="${COMPONENT_STDERR_TAIL[$i]:-}"
                if [[ -n "$local_tail" ]]; then
                    while IFS= read -r tail_line; do
                        printf '      %s\n' "$tail_line"
                    done <<< "$local_tail"
                fi
                ;;
            *)
                printf '  %b·%b %s — %s\n' "${YELLOW}" "${NC}" "$local_name" "$local_state"
                ;;
        esac
    done
    echo ""
    printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
        "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
    if [[ "${NO_BANNER:-0}" != "1" ]]; then
        echo ""
        if [[ "$SKILLS_ONLY" -eq 1 ]]; then
            echo "To remove a skill: rm -rf ~/.claude/plugins/tk-skills/<name>"
        else
            echo "To remove a skill: rm -rf ~/.claude/skills/<name>"
        fi
    fi
    if [[ $FAILED_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi
# ─────────────────────────────────────────────────
# (End of MCP / Skills routing branches — components page continues below unchanged.)
# ─────────────────────────────────────────────────

# ─────────────────────────────────────────────────
# Component metadata — labels, groups, descriptions.
# Index order matches TK_DISPATCH_ORDER from dispatch.sh.
# ─────────────────────────────────────────────────
# shellcheck disable=SC2034  # TUI_* arrays consumed by tui_checklist in tui.sh (D-01)
TUI_LABELS=("superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline")
# shellcheck disable=SC2034  # TUI_GROUPS consumed by tui_checklist in tui.sh (D-01)
TUI_GROUPS=("Bootstrap"   "Bootstrap"      "Core"    "Optional" "Optional" "Optional")
# Per-section dim subtitle. Parallel pair (Bash 3.2 has no associative arrays).
# TUI_GROUP_NAMES[k] is the section name; TUI_GROUP_DESCS[k] is the matching
# subtitle rendered in dim under the section header.
# shellcheck disable=SC2034
TUI_GROUP_NAMES=(
    "Bootstrap"
    "Core"
    "Optional"
    "Bridges"
    "Marketplace"
)
# shellcheck disable=SC2034
TUI_GROUP_DESCS=(
    "Foundation plugins this toolkit complements (skills + workflow). Skip if you don't want them."
    "The toolkit itself — commands, agents, prompts, skills, rules for the project. Required."
    "Add-ons: security rules, token saver, statusline, multi-AI council. Pick what you want."
    "Sync project CLAUDE.md → GEMINI.md / AGENTS.md so other AI CLIs read the same context."
    "Curated catalogs — pick MCP servers and skills to install. Opens a sub-picker on Submit."
)
TUI_INSTALLED=("$IS_SP" "$IS_GSD" "$IS_TK" "$IS_SEC" "$IS_RTK" "$IS_SL")
# TUI_REQUIRED: 1 = mandatory (always pre-checked, immutable, dim-rendered).
# Toolkit is the whole reason install.sh exists — deselecting it would skip the
# core install and leave a confused user. Mark required so the row reads as
# "[required]" and Space is a no-op on it.
# shellcheck disable=SC2034  # TUI_REQUIRED consumed by tui_checklist
TUI_REQUIRED=("0" "0" "1" "0" "0" "0")
# shellcheck disable=SC2034  # TUI_DESCS consumed by tui_checklist in tui.sh (D-20)
TUI_DESCS=(
    "Skills + code-reviewer agent (claude plugin)"
    "Phase-based workflow (curl install)"
    "Claude Code Toolkit core (init-claude.sh)"
    "Global security rules + cc-safety-net hook"
    "60-90% token savings on dev commands"
    "macOS rate-limit statusline (Keychain)"
)

# Council: optional Multi-AI plan review. Detect via brain.py existence (single
# inline check — non-trivial probes live in detect2.sh, this one is one stat call).
IS_COUNCIL=0
[[ -f "$HOME/.claude/council/brain.py" ]] && IS_COUNCIL=1
TUI_LABELS+=("council")
TUI_GROUPS+=("Optional")
TUI_INSTALLED+=("$IS_COUNCIL")
TUI_REQUIRED+=("0")
TUI_DESCS+=("Multi-AI plan review (Gemini + ChatGPT) — needs CLI or API keys")

# BRIDGE-UX-01 (Phase 30): conditional bridge rows. ONLY appear when the corresponding CLI
# is detected; CLIs absent => row OMITTED entirely (no greyed-out [unavailable] line).
# When NO_BRIDGES=true the rows are STILL omitted from arrays so default-set, TUI render,
# and dispatch loop all see a 6-element world (= unchanged BACKCOMPAT-01 invariant).
if [[ "$NO_BRIDGES" != "true" ]]; then
    if [[ "${IS_GEM:-0}" -eq 1 ]]; then
        _gem_ver="$(_bridge_cli_version gemini)"
        _gem_suffix="${_gem_ver:+@${_gem_ver}}"
        TUI_LABELS+=("gemini-bridge")
        TUI_GROUPS+=("Bridges")
        TUI_INSTALLED+=("0")
        TUI_REQUIRED+=("0")
        TUI_DESCS+=("Gemini CLI bridge (CLAUDE.md -> GEMINI.md) [detected: gemini${_gem_suffix}]")
        unset _gem_ver _gem_suffix
    fi
    if [[ "${IS_COD:-0}" -eq 1 ]]; then
        _cod_ver="$(_bridge_cli_version codex)"
        _cod_suffix="${_cod_ver:+@${_cod_ver}}"
        TUI_LABELS+=("codex-bridge")
        TUI_GROUPS+=("Bridges")
        TUI_INSTALLED+=("0")
        TUI_REQUIRED+=("0")
        TUI_DESCS+=("OpenAI Codex CLI bridge (CLAUDE.md -> AGENTS.md) [detected: codex${_cod_suffix}]")
        unset _cod_ver _cod_suffix
    fi
fi

# Marketplace pickers — entry rows for the MCP catalog and Skills catalog.
# Checking these and pressing Submit re-invokes install.sh in --mcps / --skills
# mode so the user sees the dedicated sub-TUI for that catalog. Embedding the
# 9-MCP + 22-skill rows directly in the main TUI would push the row count past
# 30 and crowd the screen — sub-pages are the cleaner UX.
TUI_LABELS+=("skills")
TUI_GROUPS+=("Marketplace")
TUI_INSTALLED+=("0")
TUI_REQUIRED+=("0")
TUI_DESCS+=("Pick skills (22 in catalog: firecrawl, notebooklm, shadcn, ...). Sub-picker opens after main install.")

TUI_LABELS+=("mcp-servers")
TUI_GROUPS+=("Marketplace")
TUI_INSTALLED+=("0")
TUI_REQUIRED+=("0")
TUI_DESCS+=("Pick MCP servers (9 in catalog: Sentry, Playwright, Context7, ...). Sub-picker opens after main install.")

# Dispatch name maps 1:1 to TK_DISPATCH_ORDER.

# ─────────────────────────────────────────────────
# Selection: TUI menu OR --yes default-set.
# ─────────────────────────────────────────────────
TUI_RESULTS=()
SELECTION_RC=0

# ─────────────────────────────────────────────────
# TTY-availability gate (D-04 / D-05 / D-11).
# Three branches:
#   1. --yes  → bypass TUI; synthesize default-set (D-06 / D-12)
#   2. TTY ok → render TUI + confirmation (D-04)
#   3. no TTY + no --yes → D-05 fork: source lib/bootstrap.sh and invoke
#      bootstrap_base_plugins for SP/GSD; TK components fail-closed (D-11)
# ─────────────────────────────────────────────────

# Resolve the TTY source once so the gate matches what tui_checklist will read.
_install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"

if [[ "$YES" -eq 1 ]]; then
    # --yes default-set per D-12: all uninstalled in canonical order.
    # Already-installed: skip (D-13) — unless --force.
    # Marketplace pickers (mcp-servers, skills) are EXCLUDED from --yes auto-select:
    # they re-invoke install.sh in --mcps / --skills mode which itself uses an
    # interactive sub-TUI. --yes implies non-interactive, so these would either
    # spawn a TUI inside CI (fails) or default-install everything in the catalog
    # (surprising). User can opt-in explicitly via `bash install.sh --mcps` or
    # `bash install.sh --skills` after the main install.
    _tui_count=${#TUI_LABELS[@]}
    for ((i=0; i<_tui_count; i++)); do
        case "${TUI_LABELS[$i]}" in
            mcp-servers|skills)
                TUI_RESULTS[$i]=0
                continue
                ;;
        esac
        if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
            TUI_RESULTS[$i]=0
        else
            TUI_RESULTS[$i]=1
        fi
    done
elif [[ -r "$_install_tty_src" ]]; then
    # TUI mode — render checklist. Enter inside the checklist IS the confirmation
    # (per the new "[ Install selected ]" Submit row + footer text). The previous
    # secondary `tui_confirm_prompt "[y/N]"` step was dropped because the prompt
    # was invisible after the now-tall TUI render (long inline descriptions push
    # it off the bottom of the screen, leading to "I pressed Enter and nothing
    # happened" reports).
    if ! tui_checklist; then
        # User cancelled (q/Ctrl-C/EOF). Fail-closed exit 0 per D-11.
        echo "Install cancelled."
        exit 0
    fi
    # shellcheck disable=SC2034  # SELECTION_RC reserved for future use
    SELECTION_RC=$?
    # User already gave consent via the TUI Submit row. Surface a "TUI ran"
    # signal so init-claude.sh can suppress its legacy interactive prompts
    # (Select your stack [1-8], select_mode, Council y/N) — those rendered
    # after the TUI screen-clear and users instinctively pressed ↑/↓ on a
    # canonical-mode `read`, leaking raw `^[[A`/`^[[B` bytes (user report
    # 2026-05-01). Do NOT promote YES=1 globally — that would also force
    # mcp-servers / skills sub-pickers to skip their TUI catalog (per the
    # default-set logic at line ~782) and the user wants to PICK from those.
    export TK_TUI_CONFIRMED=1
else
    # ─────────────────────────────────────────────
    # D-05 + D-11: no /dev/tty AND no --yes.
    # Fork to lib/bootstrap.sh for SP/GSD ONLY (identical to v4.4 behavior);
    # TK components fail-closed per D-09 + D-11 (no auto-install without
    # explicit confirmation).
    # ─────────────────────────────────────────────
    if [[ "$IS_SP" -ne 1 || "$IS_GSD" -ne 1 ]]; then
        # bootstrap.sh contract (Phase 21 BOOTSTRAP-01..04):
        #   - exposes bootstrap_base_plugins (verified: scripts/lib/bootstrap.sh:68)
        #   - reads via TK_BOOTSTRAP_TTY_SRC override (test seam mirrors D-33)
        #   - already idempotent (skips installed SP/GSD via dir probes)
        #   - fail-closed N on EOF
        # Source it (curl-fetched if running curl|bash, local otherwise) and call.
        if _is_curl_pipe; then
            _bootstrap_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-boot-XXXXXX") || _bootstrap_tmp=""
            if [[ -n "$_bootstrap_tmp" ]]; then
                CLEANUP_PATHS+=("$_bootstrap_tmp")
                if curl -sSLf -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/lib/bootstrap.sh" -o "$_bootstrap_tmp" 2>/dev/null; then
                    # Source SP/GSD canonical install commands first so
                    # bootstrap_base_plugins picks them up (TK_SP_INSTALL_CMD /
                    # TK_GSD_INSTALL_CMD from optional-plugins.sh).
                    _opt_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-opt-XXXXXX") || _opt_tmp=""
                    if [[ -n "$_opt_tmp" ]]; then
                        CLEANUP_PATHS+=("$_opt_tmp")
                        if curl -sSLf -A "$TK_USER_AGENT" "$TK_REPO_URL/scripts/lib/optional-plugins.sh" -o "$_opt_tmp" 2>/dev/null; then
                            # shellcheck source=/dev/null
                            source "$_opt_tmp"
                        fi
                    fi
                    # shellcheck source=/dev/null
                    source "$_bootstrap_tmp"
                    bootstrap_base_plugins || true
                else
                    echo "Error: failed to fetch lib/bootstrap.sh — pass --yes for non-interactive install" >&2
                fi
            fi
        else
            # Local clone path.
            _local_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/lib"
            if [[ -f "$_local_lib_dir/bootstrap.sh" ]]; then
                # Source optional-plugins.sh first to populate TK_SP_INSTALL_CMD /
                # TK_GSD_INSTALL_CMD (read by bootstrap_base_plugins).
                if [[ -f "$_local_lib_dir/optional-plugins.sh" ]]; then
                    # shellcheck source=lib/optional-plugins.sh
                    source "$_local_lib_dir/optional-plugins.sh"
                fi
                # shellcheck source=lib/bootstrap.sh
                source "$_local_lib_dir/bootstrap.sh"
                bootstrap_base_plugins || true
            else
                echo "Error: lib/bootstrap.sh not found and no curl available — pass --yes for non-interactive install" >&2
            fi
        fi
    fi
    # D-11 fail-closed: TK components NEVER auto-install without explicit confirmation.
    echo "" >&2
    echo "No TTY available for TUI; toolkit/security/rtk/statusline components skipped (D-11 fail-closed)." >&2
    echo "  To install non-interactively, re-run with --yes." >&2
    # Print a minimal summary so the user sees the SP/GSD outcome reflected.
    # Build empty TUI_RESULTS so the dispatch loop treats every TK component
    # as 'skipped' (unselected) rather than crashing on undefined indices.
    _tui_count=${#TUI_LABELS[@]}
    for ((i=0; i<_tui_count; i++)); do
        TUI_RESULTS[$i]=0
    done
fi

# BRIDGE-UX-04: --bridges <list> force-selects bridge rows after default-set/TUI.
# Runs unconditionally because mutex with --no-bridges is checked at argv parse time
# (BRIDGES_FORCE is empty when --no-bridges is set).
if [[ -n "$BRIDGES_FORCE" ]]; then
    _force_count=${#TUI_LABELS[@]}
    for ((_fi=0; _fi<_force_count; _fi++)); do
        case "${TUI_LABELS[$_fi]}" in
            gemini-bridge)
                if _bridge_match gemini "$BRIDGES_FORCE"; then
                    TUI_RESULTS[$_fi]=1
                fi
                ;;
            codex-bridge)
                if _bridge_match codex "$BRIDGES_FORCE"; then
                    TUI_RESULTS[$_fi]=1
                fi
                ;;
        esac
    done
    unset _force_count _fi
fi

# BRIDGE-UX-04 fail-fast: warn (or exit 1 under --fail-fast) on absent CLIs in BRIDGES_FORCE.
if [[ -n "$BRIDGES_FORCE" ]]; then
    _missing=""
    if _bridge_match gemini "$BRIDGES_FORCE" && [[ "${IS_GEM:-0}" -ne 1 ]]; then
        _missing="${_missing}${_missing:+, }gemini"
    fi
    if _bridge_match codex "$BRIDGES_FORCE" && [[ "${IS_COD:-0}" -ne 1 ]]; then
        _missing="${_missing}${_missing:+, }codex"
    fi
    if [[ -n "$_missing" ]]; then
        if [[ "$FAIL_FAST" -eq 1 ]]; then
            echo -e "${RED}Error:${NC} --bridges named CLIs not detected: ${_missing} (--fail-fast)" >&2
            exit 1
        else
            echo -e "${YELLOW}Warning:${NC} --bridges named CLIs not detected, skipping: ${_missing}" >&2
        fi
    fi
    unset _missing
fi

# ─────────────────────────────────────────────────
# BRIDGE-UX-05: TUI bridge selection → env propagation for the nested toolkit
# dispatch. Without this, init-claude.sh's bridge_install_prompts re-prompts
# the user under D-28 stderr capture — the prompt is written to stderr (Bash
# `read -p` semantics), captured by `( dispatch_toolkit ) 2>"$tmp"`, and the
# user sees a bare blinking caret.
#
# We honour the TUI checkbox state here so bridge_install_prompts inside
# init-claude.sh uses its NON-interactive paths:
#   row checked   → BRIDGES_FORCE=<target> (force-create path, no prompt)
#   row unchecked → TK_NO_BRIDGES=1        (silent return 0, no prompt)
# Only triggered when the TUI actually ran (TK_TUI_CONFIRMED=1) AND the bridge
# row was rendered (CLI detected). Manual `--bridges`/env overrides still work
# when invoked outside the TUI flow.
# ─────────────────────────────────────────────────
if [[ "${TK_TUI_CONFIRMED:-0}" == "1" ]]; then
    _tui_bridge_force=""
    _tui_bridge_seen_any=0
    _tbf_count=${#TUI_LABELS[@]}
    for ((_tbi=0; _tbi<_tbf_count; _tbi++)); do
        case "${TUI_LABELS[$_tbi]}" in
            gemini-bridge)
                _tui_bridge_seen_any=1
                if [[ "${TUI_RESULTS[$_tbi]:-0}" -eq 1 ]]; then
                    _tui_bridge_force="${_tui_bridge_force}${_tui_bridge_force:+,}gemini"
                fi
                ;;
            codex-bridge)
                _tui_bridge_seen_any=1
                if [[ "${TUI_RESULTS[$_tbi]:-0}" -eq 1 ]]; then
                    _tui_bridge_force="${_tui_bridge_force}${_tui_bridge_force:+,}codex"
                fi
                ;;
        esac
    done
    if [[ "$_tui_bridge_seen_any" -eq 1 ]]; then
        if [[ -n "$_tui_bridge_force" ]]; then
            # User explicitly opted in via TUI → propagate as force-list.
            # Do NOT clobber an existing BRIDGES_FORCE: the caller may have
            # added --bridges <list> on top of TUI selection (CI tooling).
            if [[ -z "${BRIDGES_FORCE:-}" ]]; then
                export BRIDGES_FORCE="$_tui_bridge_force"
            fi
        else
            # User saw bridge rows + left them unchecked → silent skip.
            # TK_NO_BRIDGES=1 is the env-var form bridge_install_prompts honours.
            # NO_BRIDGES=true (the flag form) is also honoured but is an
            # init-claude.sh-internal var; TK_NO_BRIDGES is the cross-process
            # contract.
            export TK_NO_BRIDGES=1
        fi
    fi
    unset _tbf_count _tbi _tui_bridge_force _tui_bridge_seen_any
fi

# ─────────────────────────────────────────────────
# UX-FLOW-01: pre-collect MCP / skills sub-picker selections.
#
# Old flow: main TUI Submit → dispatch loop → toolkit/security/etc. install →
# (later) mcp-servers dispatcher re-spawns install.sh --mcps which opens its
# OWN TUI mid-install → user gets a sub-picker AFTER 20+ seconds of silent
# install work, which feels like a hang.
#
# New flow: main TUI Submit → MCP sub-picker (if mcp-servers row checked) →
# Skills sub-picker (if skills row checked) → THEN the dispatch loop runs
# end-to-end. The user answers every question up front. The mcp-servers /
# skills dispatchers reuse the pre-collected selections via the
# TK_MCP_PRE_SELECTED / TK_SKILLS_PRE_SELECTED env contract that the --mcps
# and --skills branches above honour (skip their own TUI when set).
#
# Empty value (`TK_MCP_PRE_SELECTED=""`) is meaningful: "user opened the
# sub-picker, picked nothing, hit Submit." Headless install of zero MCPs.
# Cancel (Esc / Ctrl-C in the sub-picker) aborts the whole install per
# normal TUI semantics.
# ─────────────────────────────────────────────────
if [[ "${TK_TUI_CONFIRMED:-0}" == "1" && "$DRY_RUN" -ne 1 ]]; then
    _need_mcp_pre=0
    _need_skills_pre=0
    _ux_flow_count=${#TUI_LABELS[@]}
    for ((_ux_i=0; _ux_i<_ux_flow_count; _ux_i++)); do
        case "${TUI_LABELS[$_ux_i]}" in
            mcp-servers) [[ "${TUI_RESULTS[$_ux_i]:-0}" -eq 1 ]] && _need_mcp_pre=1 ;;
            skills)      [[ "${TUI_RESULTS[$_ux_i]:-0}" -eq 1 ]] && _need_skills_pre=1 ;;
        esac
    done
    unset _ux_flow_count _ux_i

    # IMPORTANT: sub-pickers run in the MAIN process (no `$( ... )` capture).
    #
    # Earlier draft used a subshell `_csv=$( … tui_checklist … printf … )` to
    # isolate TUI globals, but that path hung visibly under curl|bash on macOS
    # (zsh parent → `bash <(curl)` child → bash subshell `$()` for the picker).
    # The TUI library writes its render to /dev/tty, but the subshell still
    # owns a captured stdout pipe — and on at least one macOS terminal the
    # stty/cursor-hide sequences plus the captured-stdout fd combination left
    # the user looking at a frozen post-Submit screen with no second TUI ever
    # appearing (user report 2026-05-01). Running in the main process avoids
    # the stdout-pipe entirely and matches what tui_checklist was designed for.
    #
    # We save the main-TUI globals (TUI_LABELS/TUI_RESULTS/TUI_INSTALLED/
    # TUI_GROUPS/TUI_DESCS/TUI_REQUIRED) before each sub-picker so the dispatch
    # loop below still sees the original main-TUI selection state when it maps
    # rows → dispatcher names.

    _save_main_tui_state() {
        _SAVE_TUI_LABELS=("${TUI_LABELS[@]+"${TUI_LABELS[@]}"}")
        _SAVE_TUI_RESULTS=("${TUI_RESULTS[@]+"${TUI_RESULTS[@]}"}")
        _SAVE_TUI_INSTALLED=("${TUI_INSTALLED[@]+"${TUI_INSTALLED[@]}"}")
        _SAVE_TUI_GROUPS=("${TUI_GROUPS[@]+"${TUI_GROUPS[@]}"}")
        _SAVE_TUI_DESCS=("${TUI_DESCS[@]+"${TUI_DESCS[@]}"}")
        _SAVE_TUI_REQUIRED=("${TUI_REQUIRED[@]+"${TUI_REQUIRED[@]}"}")
    }
    _restore_main_tui_state() {
        TUI_LABELS=("${_SAVE_TUI_LABELS[@]+"${_SAVE_TUI_LABELS[@]}"}")
        TUI_RESULTS=("${_SAVE_TUI_RESULTS[@]+"${_SAVE_TUI_RESULTS[@]}"}")
        TUI_INSTALLED=("${_SAVE_TUI_INSTALLED[@]+"${_SAVE_TUI_INSTALLED[@]}"}")
        TUI_GROUPS=("${_SAVE_TUI_GROUPS[@]+"${_SAVE_TUI_GROUPS[@]}"}")
        TUI_DESCS=("${_SAVE_TUI_DESCS[@]+"${_SAVE_TUI_DESCS[@]}"}")
        TUI_REQUIRED=("${_SAVE_TUI_REQUIRED[@]+"${_SAVE_TUI_REQUIRED[@]}"}")
        unset _SAVE_TUI_LABELS _SAVE_TUI_RESULTS _SAVE_TUI_INSTALLED \
              _SAVE_TUI_GROUPS _SAVE_TUI_DESCS _SAVE_TUI_REQUIRED
    }

    # ── Skills sub-picker (if needed) — runs FIRST so MCP picker is closer
    #    to the dispatch loop (mcp install is intentionally LAST in dispatch
    #    so the "needs API key" follow-up block ends the screen). ──
    if [[ "$_need_skills_pre" -eq 1 ]]; then
        # Skills detection is a directory probe — no slow CLI call — but the
        # _source_lib step still downloads under curl|bash, so a one-line
        # banner keeps the user oriented through the brief gap.
        echo ""
        echo -e "${CYAN}Loading skills catalog...${NC}"
        _source_lib skills
        _save_main_tui_state
        skills_status_array
        TUI_LABELS=("${SKILLS_CATALOG[@]}")
        TUI_GROUPS=()
        TUI_DESCS=()
        TUI_REQUIRED=()
        for ((_sk_i=0; _sk_i<${#SKILLS_CATALOG[@]}; _sk_i++)); do
            TUI_GROUPS+=("Skills")
            TUI_DESCS+=("Curated skill mirrored from upstream")
            TUI_REQUIRED+=(0)
        done
        unset _sk_i
        TUI_RESULTS=()
        if ! tui_checklist; then
            echo "Skills selection cancelled — aborting install."
            exit 0
        fi
        _skills_pre_csv=""
        for ((_sk_i=0; _sk_i<${#TUI_LABELS[@]}; _sk_i++)); do
            if [[ "${TUI_RESULTS[$_sk_i]:-0}" -eq 1 ]]; then
                _skills_pre_csv="${_skills_pre_csv}${_skills_pre_csv:+,}${TUI_LABELS[$_sk_i]}"
            fi
        done
        unset _sk_i
        export TK_SKILLS_PRE_SELECTED="$_skills_pre_csv"
        unset _skills_pre_csv
        _restore_main_tui_state
    fi

    # ── MCP sub-picker (if needed) ──
    if [[ "$_need_mcp_pre" -eq 1 ]]; then
        # Visible feedback BEFORE the slow steps (download + claude mcp list)
        # so the user knows the install isn't dead. Without this banner the
        # screen sat on the post-Submit main-TUI render for ~40 s while
        # mcp_status_array probed 9 MCPs (now batched via _mcp_list_cache_init,
        # ~4 s) — long enough to look like a hang to most users.
        echo ""
        echo -e "${CYAN}Loading MCP catalog (probing claude CLI for installed servers — a few seconds)...${NC}"
        _source_lib mcp
        if _is_curl_pipe && [[ -z "${TK_MCP_CATALOG_PATH:-}" ]]; then
            MCP_CATALOG_TMP=$(mktemp "${TMPDIR:-/tmp}/mcp-catalog-XXXXXX.json")
            CLEANUP_PATHS+=("$MCP_CATALOG_TMP")
            if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/mcp-catalog.json" -o "$MCP_CATALOG_TMP"; then
                echo -e "${RED}✗${NC} Failed to download mcp-catalog.json — aborting" >&2
                exit 1
            fi
            export TK_MCP_CATALOG_PATH="$MCP_CATALOG_TMP"
        fi
        _save_main_tui_state
        if ! mcp_catalog_load >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} Failed to load MCP catalog — aborting" >&2
            exit 1
        fi
        mcp_status_array
        TUI_LABELS=("${MCP_NAMES[@]}")
        TUI_GROUPS=()
        TUI_DESCS=()
        TUI_REQUIRED=()
        for ((_mcp_i=0; _mcp_i<${#MCP_NAMES[@]}; _mcp_i++)); do
            TUI_GROUPS+=("MCP")
            TUI_DESCS+=("${MCP_DESCS[$_mcp_i]:-}")
            TUI_REQUIRED+=(0)
        done
        unset _mcp_i
        TUI_RESULTS=()
        if ! tui_checklist; then
            echo "MCP selection cancelled — aborting install."
            exit 0
        fi
        # Build CSV BEFORE restoring globals (TUI_RESULTS lives in the same
        # array we just used to capture answers).
        _mcp_pre_csv=""
        for ((_mcp_i=0; _mcp_i<${#TUI_LABELS[@]}; _mcp_i++)); do
            if [[ "${TUI_RESULTS[$_mcp_i]:-0}" -eq 1 ]]; then
                _mcp_pre_csv="${_mcp_pre_csv}${_mcp_pre_csv:+,}${TUI_LABELS[$_mcp_i]}"
            fi
        done
        unset _mcp_i
        # Empty CSV ("") is intentional and exported as such (= "install zero").
        export TK_MCP_PRE_SELECTED="$_mcp_pre_csv"
        unset _mcp_pre_csv
        _restore_main_tui_state
    fi
    unset _need_mcp_pre _need_skills_pre
    unset -f _save_main_tui_state _restore_main_tui_state
fi

# ─────────────────────────────────────────────────
# Dispatch loop (D-08 continue-on-error, D-09 --fail-fast opt-in).
# Per-component status accumulated in parallel arrays.
# ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Installing selected components...${NC}"
echo ""

INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
COMPONENT_STATUS=()
COMPONENT_NAMES=()
# D-28 — per-component stderr tail buffer; populated only when dispatcher fails.
# Tmpfile paths are added to CLEANUP_PATHS so the EXIT trap removes them.
COMPONENT_STDERR_TAIL=()

_disp_count=${#TUI_LABELS[@]}
# Audit M-Install: TK_DISPATCH_ORDER comes from dispatch.sh which we control,
# but a future patch could pick the value up from env. Validate every entry
# matches a strict alphanumeric/hyphen alphabet so the `dispatch_${name}`
# expansion below cannot be coerced into invoking a function name with shell
# metacharacters or starting with a dash.
for _local_check_name in "${TK_DISPATCH_ORDER[@]}"; do
    if [[ ! "$_local_check_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo -e "${RED}Error:${NC} TK_DISPATCH_ORDER contains invalid component name: ${_local_check_name@Q}" >&2
        exit 1
    fi
done
unset _local_check_name

# Audit H1: previously this loop indexed both TK_DISPATCH_ORDER and
# TUI_LABELS by the same $i — but TK_DISPATCH_ORDER is fixed-length 8
# while TUI_LABELS is dynamic 6/7/8 entries (bridges are conditional).
# With only Codex detected (IS_GEM=0, IS_COD=1), TUI_LABELS[6] was
# "codex-bridge" while TK_DISPATCH_ORDER[6] was "gemini-bridge", so
# the user got a Gemini bridge written despite no Gemini CLI and the
# Codex bridge silently never installed. The same bug fired on
# `--bridges codex` and any future label rearrangement.
#
# Fix: derive the dispatch name from the TUI label directly. Labels
# already use kebab-case names that map 1:1 to dispatcher functions
# after a single get-shit-done → gsd renaming step.
_local_label_to_dispatch_name() {
    case "$1" in
        get-shit-done) echo "gsd" ;;
        # Marketplace pickers — kebab-to-snake for the dispatch_ function name
        # (Bash function names cannot contain hyphens).
        mcp-servers)   echo "mcp_servers" ;;
        # Bridges keep their kebab-case label — the dispatch loop has a
        # dedicated bridge branch (case "$local_name" in gemini-bridge|
        # codex-bridge) that handles them without invoking dispatch_*.
        *) echo "$1" ;;
    esac
}

for ((i=0; i<_disp_count; i++)); do
    local_label="${TUI_LABELS[$i]}"
    local_name="$(_local_label_to_dispatch_name "$local_label")"
    COMPONENT_NAMES+=("$local_label")

    if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
        # User did not select OR pre-installed (without --force).
        # Pre-installed shows 'installed ✓' state; user-skipped shows 'skipped'.
        if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
            COMPONENT_STATUS+=("installed ✓")
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            COMPONENT_STATUS+=("skipped")
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
        COMPONENT_STDERR_TAIL+=("")  # parallel array padding (D-28)
        continue
    fi

    # Re-probe (D-23 mid-run drift catch).
    local_re_installed=0
    case "$local_name" in
        superpowers) is_superpowers_installed && local_re_installed=1 || true ;;
        gsd)         is_gsd_installed         && local_re_installed=1 || true ;;
        toolkit)     is_toolkit_installed     && local_re_installed=1 || true ;;
        security)    is_security_installed    && local_re_installed=1 || true ;;
        rtk)         is_rtk_installed         && local_re_installed=1 || true ;;
        statusline)  is_statusline_installed  && local_re_installed=1 || true ;;
        council)     [[ -f "$HOME/.claude/council/brain.py" ]] && local_re_installed=1 || true ;;
        gemini-bridge) : ;;  # Bridges have no idempotency probe — always re-write (state SHA tracks drift).
        codex-bridge)  : ;;
        mcp_servers) : ;;    # Marketplace pickers always run when checked — the sub-TUI handles its own idempotency.
        skills)        : ;;
    esac

    if [[ $local_re_installed -eq 1 && "$FORCE" -ne 1 ]]; then
        COMPONENT_STATUS+=("skipped")
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        COMPONENT_STDERR_TAIL+=("")  # parallel array padding (D-28)
        continue
    fi

    # Build per-dispatch flags.
    local_flags=()
    [[ "$FORCE" -eq 1 ]]   && local_flags+=("--force")
    [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")
    [[ "$YES" -eq 1 ]]     && local_flags+=("--yes")

    # D-28 — Capture dispatcher stderr to a per-component tmpfile so we can
    # surface the last 5 lines under the failure row in the summary. Tmpfile
    # is added to CLEANUP_PATHS so the EXIT trap (set up at top of file)
    # removes it.
    # Audit L2: do not embed the component name — shared /tmp on Linux
    # would otherwise leak which dispatchers the user is running.
    stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-install.XXXXXX") || stderr_tmp=""
    [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

    # BRIDGE-UX-01 dispatch shim: bridge labels do not have a dispatch_<name> function;
    # we call bridge_create_global directly. Other components flow through dispatch_*.
    case "$local_name" in
        gemini-bridge|codex-bridge)
            _bridge_target="${local_name%-bridge}"
            local_rc=0
            if [[ "$DRY_RUN" -eq 1 ]]; then
                # Dry-run: announce would-install without touching any files.
                : # local_rc stays 0; status set to would-install below.
            elif [[ -n "$stderr_tmp" ]]; then
                ( bridge_create_global "$_bridge_target" ) 2>"$stderr_tmp" || local_rc=$?
            else
                bridge_create_global "$_bridge_target" || local_rc=$?
            fi
            unset _bridge_target
            ;;
        *)
            # Dispatch with continue-on-error (D-08). Capture exit code AND stderr.
            # Use a subshell + 2>"$stderr_tmp" redirection (Bash 3.2 compatible —
            # avoids process substitution which is not portable across all callers).
            local_rc=0
            # Audit M4: guard the local_flags expansion for Bash 3.2
            # (macOS support floor) — `"${arr[@]}"` aborts under set -u
            # when arr is empty. Match the safe form already used at
            # lines 363/365/531/533.
            if [[ -n "$stderr_tmp" ]]; then
                ( "dispatch_${local_name}" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
            else
                # mktemp failed (rare); fall back to no-capture path.
                "dispatch_${local_name}" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
            fi
            ;;
    esac

    if [[ $local_rc -eq 0 ]]; then
        # Under --dry-run, dispatchers return rc=0 after printing the
        # would-run command WITHOUT executing — map to 'would-install' so
        # the summary doesn't falsely claim "installed ✓" (D-10 extension).
        if [[ "$DRY_RUN" -eq 1 ]]; then
            COMPONENT_STATUS+=("would-install")
        else
            COMPONENT_STATUS+=("installed ✓")
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        fi
        COMPONENT_STDERR_TAIL+=("")
    else
        COMPONENT_STATUS+=("failed (exit $local_rc)")
        FAILED_COUNT=$((FAILED_COUNT + 1))
        # D-28 — stash last 5 lines of stderr for the failure summary row.
        local_tail=""
        if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
            local_tail=$(tail -5 "$stderr_tmp")
        fi
        COMPONENT_STDERR_TAIL+=("$local_tail")
        if [[ "$FAIL_FAST" -eq 1 ]]; then
            # Stop dispatching; remaining components stay 'skipped'.
            # C-style for-loop avoids the duplicate-index bug from the prior
            # `for j in $((i + 1)) 2 3 4 5` form (which expanded to e.g.
            # `for j in 2 2 3 4 5` when i=1 — counting index 2 twice).
            _ff_count=${#TUI_LABELS[@]}
            for (( j=i+1; j<_ff_count; j++ )); do
                COMPONENT_NAMES+=("${TUI_LABELS[$j]}")
                COMPONENT_STATUS+=("skipped")
                COMPONENT_STDERR_TAIL+=("")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            done
            break
        fi
    fi
done

# ─────────────────────────────────────────────────
# Post-install summary (D-27, D-28).
# ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Install summary:${NC}"
echo ""
_sum_count=${#TUI_LABELS[@]}
for ((i=0; i<_sum_count; i++)); do
    local_name="${COMPONENT_NAMES[$i]:-${TUI_LABELS[$i]}}"
    local_state="${COMPONENT_STATUS[$i]:-unknown}"
    print_install_status "$local_name" "$local_state"
    # D-28 — under failure rows, indent the captured stderr tail (last 5 lines).
    case "$local_state" in
        failed*)
            local_tail="${COMPONENT_STDERR_TAIL[$i]:-}"
            if [[ -n "$local_tail" ]]; then
                # Indent each line by 6 spaces so it visually nests under the
                # `  <component> failed...` row written by print_install_status.
                while IFS= read -r tail_line; do
                    printf '      %s\n' "$tail_line"
                done <<< "$local_tail"
            fi
            ;;
    esac
done
echo ""
printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
    "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"

# Consolidated finale — printed AFTER all dispatchers finish (user report
# 2026-05-01: standalone init-claude.sh finale appeared mid-flow before
# skills/mcp summaries). Sub-installers run with TK_DISPATCHED=1 so they
# suppress their own finales; this is the canonical one.
if [[ "${NO_BANNER:-0}" != "1" ]]; then
    echo ""
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ Installation Complete!                 ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠ Installation completed with failure(s)  ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
    fi
    echo ""
    echo -e "${YELLOW}⚠  Restart Claude Code in this project directory for commands to become available.${NC}"
    echo ""
    echo "To remove: bash <(curl -sSL $TK_REPO_URL/scripts/uninstall.sh)"
    if [[ -f ".claude/POST_INSTALL.md" ]]; then
        echo ""
        echo "Read .claude/POST_INSTALL.md and show its contents to the user."
    fi
fi

# Exit code (D-29): 0 if no failures, 1 if any failure.
if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
