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
TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-v6.53.0}"
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
# Phase 34-02 (TUI-04): per-component dispatch flags. Mutually exclusive.
# When both set, exit 2 with stderr error mirroring v4.8 Phase 30
# --bridges/--no-bridges precedent.
MCP_ONLY=0
CLI_ONLY=0

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
        --mcps)
            # Phase 32-01 (CAT-04): --mcps remains a working alias for --integrations
            # but emits a one-line deprecation note to stderr (non-blocking).
            # The flag will be removed in v6.0; --integrations is the canonical form.
            MCPS=1
            echo -e "${YELLOW}⚠${NC} --mcps is deprecated; use --integrations (alias retained until v6.0)" >&2
            shift ;;
        --integrations) MCPS=1;               shift ;;
        --mcp-only)    MCP_ONLY=1;            shift ;;
        --cli-only)    CLI_ONLY=1;            shift ;;
        --skills)      SKILLS=1;              shift ;;
        --skills-only) SKILLS_ONLY=1; SKILLS=1; shift ;;
        --mcp-scope=*)
            # Phase 37 (mcp-scope-toggle): override the default `user` scope
            # for `claude mcp add` invocations. Accepts user|local|project;
            # any other value is rejected so a typo doesn't silently fall
            # back. The TUI also exposes an `s` toggle, but the CLI flag
            # wins (TK_MCP_SCOPE is read by mcp_wizard_run).
            _scope_arg="${1#--mcp-scope=}"
            case "$_scope_arg" in
                user|local|project)
                    # Phase 39 (HIGH-02): TK_MCP_SCOPE_CLI captures the
                    # explicit CLI value separately so headless dispatch can
                    # tell "user supplied --mcp-scope" from "default fallback
                    # to user". TK_MCP_SCOPE remains exported for the inline
                    # 1-MCP path (mcp_wizard_run reads it directly); the main
                    # TUI dispatcher consults TK_MCP_SCOPE_CLI to broadcast
                    # the override into every MCP_SELECTED_SCOPE[] slot
                    # (D-18 "CLI flag wins" intent).
                    TK_MCP_SCOPE_CLI="$_scope_arg"
                    export TK_MCP_SCOPE_CLI
                    TK_MCP_SCOPE="$_scope_arg"
                    export TK_MCP_SCOPE
                    ;;
                *)
                    echo -e "${RED}Error:${NC} --mcp-scope must be one of: user, local, project (got: $_scope_arg)" >&2
                    exit 2
                    ;;
            esac
            unset _scope_arg
            shift
            ;;
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
  --integrations  Install curated integrations (MCPs, etc.) via TUI catalog
  --mcps          Deprecated alias for --integrations (removed in v6.0)
  --mcp-only    Install only MCP servers; skip companion CLI binaries
  --cli-only    Install only companion CLI binaries; skip MCP server registration
                  (--mcp-only and --cli-only are mutually exclusive)
  --skills      Install curated skills via TUI catalog
  --skills-only Install skills to Desktop tree (~/.claude/plugins/tk-skills/);
                auto-activates when 'claude' CLI is absent on PATH (DESK-03)
  --mcp-scope=SCOPE  Scope for 'claude mcp add' (user|local|project; default: user).
                     Inside the MCP TUI, press 's' to toggle user ↔ local.

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

# Phase 34-02 (TUI-04): --mcp-only / --cli-only mutex. Mirrors the v4.8 Phase 30
# bridges precedent — exit 2 on user-error per the BOOTSTRAP-04 contract.
if [[ "$MCP_ONLY" -eq 1 && "$CLI_ONLY" -eq 1 ]]; then
    echo -e "${RED}Error:${NC} --mcp-only and --cli-only are mutually exclusive" >&2
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

# AUDIT-P4 (logic audit 2026-05-18): redirect to update-claude.sh when an
# existing project install is detected. install.sh is idempotent at the file
# level but does NOT carry the smart-merge logic that update-claude.sh uses
# to preserve user-customized sections of CLAUDE.md. Re-running install.sh
# expecting "update" semantics silently overwrites those sections.
# Skip when --force, --dry-run, or TK_FORCE_REINSTALL=1.
if [[ $FORCE -eq 0 ]] && [[ $DRY_RUN -eq 0 ]] && [[ -z "${TK_FORCE_REINSTALL:-}" ]] && [[ -f ".claude/.toolkit-version" ]]; then
    _existing_ver=$(cat .claude/.toolkit-version 2>/dev/null | head -n 1 | tr -d '[:space:]')
    echo -e "${YELLOW}⚠ Existing toolkit installation detected: v${_existing_ver:-unknown}${NC}"
    echo ""
    echo "install.sh is for FIRST-TIME installs. To update an existing"
    echo "install while preserving your CLAUDE.md customizations, use:"
    echo ""
    echo -e "  ${GREEN}bash <(curl -sSL ${TK_REPO_URL}/scripts/update-claude.sh)${NC}"
    echo "  # or: /update-toolkit  (inside Claude Code)"
    echo ""
    echo "To force a clean re-install (overwrites managed files):"
    echo "  bash scripts/install.sh --force"
    echo "  # or set TK_FORCE_REINSTALL=1"
    echo ""
    exit 2
fi

# ─────────────────────────────────────────────────
# Source the three Phase 24 libs.
# Detect curl|bash via BASH_SOURCE/$0; in that case download libs to mktemp.
# ─────────────────────────────────────────────────
CLEANUP_PATHS=()
# Audit 2026-05-14 L-2: skills_fetch_mirror_via_tarball extracts the toolkit
# tarball into a directory tree (~5-15 MB). The previous EXIT trap used
# `rm -f` which silently fails on directories, leaking the extracted dir.
CLEANUP_DIRS=()
run_cleanup() {
    if [[ ${#CLEANUP_PATHS[@]} -gt 0 ]]; then
        rm -f "${CLEANUP_PATHS[@]}" || true
    fi
    if [[ ${#CLEANUP_DIRS[@]} -gt 0 ]]; then
        rm -rf "${CLEANUP_DIRS[@]}" || true
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

# Audit 2026-05-12 (F-1): TK_MCP_CATALOG_PATH is a test seam (used by
# scripts/tests/test-{integrations-foundation,uninstall-state-cleanup,
# catalog-scope-fallback,integrations-tui}.sh to point at synthetic
# fixtures). The catalog string flows into `bash -c` via cli-installer.sh,
# so a hostile pre-set env value is a clean RCE vector under the user's
# account. Mirror the C2/H6 lockdown: honour the override only when
# TK_TEST=1 is also set. Internal exports below (lines ~299, ~1898) happen
# AFTER this gate, so they remain unaffected.
if [[ -n "${TK_MCP_CATALOG_PATH:-}" && "${TK_TEST:-0}" != "1" ]]; then
    echo -e "${RED}Error:${NC} TK_MCP_CATALOG_PATH override is a test seam; requires TK_TEST=1." >&2
    echo "        Unset TK_MCP_CATALOG_PATH (env or shell rc) and re-run, or export TK_TEST=1 if you are running the test harness." >&2
    exit 1
fi

# MCPS=1 path needs the MCP catalog + wizard library.
if [[ "$MCPS" -eq 1 ]]; then
    # Source project-secrets BEFORE mcp.sh so the project_secrets_*
    # functions are declared by the time mcp.sh's guard at lines 97-106
    # runs `command -v project_secrets_write_env` and short-circuits the
    # BASH_SOURCE-relative lazy sibling-source. Under curl-pipe the lazy
    # path resolves to /tmp/project-secrets.sh (mcp.sh sits in
    # /tmp/mcp-XXXXXX), which doesn't exist — the silent miss left
    # project_secrets_write_env undeclared and project-scope MCPs
    # (cloudflare, stripe, mailgun, ...) failed at mcp.sh:782 with
    # `mcp_wizard_run: project-scope requested but scripts/lib/project-`
    # `secrets.sh not loaded` (user report 2026-05-12). Same class as the
    # v6.23.1 skills-curl-pipe path-resolution fix.
    _source_lib project-secrets
    _source_lib mcp
    # Phase 34-02 (TUI-04): cli-installer primitives for --cli-only / non-mcp-only paths.
    # cli_detect / cli_install / cli_post_install_hint are sub-millisecond on the
    # uncalled path, so unconditional source is safe even when only MCPs are installed.
    _source_lib cli-installer
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
    #
    # BSD mktemp (macOS): the X-run must be the LAST chars of the template,
    # otherwise X's stay literal and re-runs collide on the literal filename
    # (user report 2026-05-02). Drop the .json suffix — readers (jq) ignore
    # extension.
    if _is_curl_pipe && [[ -z "${TK_MCP_CATALOG_PATH:-}" ]]; then
        MCP_CATALOG_TMP=$(mktemp "${TMPDIR:-/tmp}/integrations-catalog-XXXXXX")
        CLEANUP_PATHS+=("$MCP_CATALOG_TMP")
        # Phase 32-01 (CAT-01): catalog renamed mcp-catalog.json → integrations-catalog.json.
        if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/integrations-catalog.json" -o "$MCP_CATALOG_TMP"; then
            echo -e "${RED}✗${NC} Failed to download integrations-catalog.json — aborting" >&2
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
        skipped)        printf '  %b%-30s %s%b\n' "${_DRO_GREY:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        failed*)        printf '  %b%-30s %s%b\n' "${_DRO_R:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        *)              printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}

# ─────────────────────────────────────────────────
# v6.16.0 (T-05/06/07) — MCP scope lock-screen
# ─────────────────────────────────────────────────
#
# Renders an interactive checklist where the SELECTION is locked (came from
# the integrations sub-picker via TK_MCP_PRE_SELECTED) but the per-row SCOPE
# is editable. Wires Tab/`s` through to the existing mcp_cycle_row_scope /
# mcp_toggle_scope dispatch (Phase 39 — previously dead code because the
# headless TK_MCP_PRE_SELECTED branch in the main TUI swallowed everything).
#
# Approach: build a SHADOW set of TUI arrays containing only rows whose
# MCP_NAMES entry appears in TK_MCP_PRE_SELECTED. Run tui_checklist on the
# shadow with TK_TUI_LOCK_SELECTION=1 + Tab/`s` wiring. After return, copy
# each shadow row's MCP_SELECTED_SCOPE back to its original index in the
# full MCP_SELECTED_SCOPE[] (parallel to TUI_LABELS). The full-sized arrays
# untouched outside the shadow are what the dispatcher loop at line ~590
# reads to drive `claude mcp add --scope <X>`.
#
# Reads:
#   TK_MCP_PRE_SELECTED — CSV of MCP_NAMES, set by the sub-picker
#   TUI_LABELS / TUI_GROUPS / TUI_INSTALLED / TUI_DESCS / TUI_TO_MCP_IDX
#       — populated by mcp_status_array (full catalog, render order)
#   MCP_SELECTED_SCOPE[] — parallel to TUI_LABELS, seeded from MCP_DEFAULT_SCOPE
#   MCP_NAMES[] — alphabetical
#
# Writes:
#   MCP_SELECTED_SCOPE[$tui_i] for each TUI row whose name is in PRE_SELECTED
#
# Cancel handling: tui_checklist rc=1 → "Install cancelled at scope picker."
# + exit 0 (matches sub-picker cancel behaviour).
mcp_cycle_row_scope_locked() {
    # T-06: Tab on installed rows is silent no-op (D-13 in CONTEXT.md). Re-scope
    # of installed MCPs would require `claude mcp remove + add` with re-OAuth /
    # secret prompt — out of phase scope (DEF-01).
    local _idx="${FOCUS_IDX:-0}"
    if [[ "${TUI_INSTALLED[$_idx]:-0}" -eq 1 ]]; then
        return 0
    fi
    mcp_cycle_row_scope
}

_run_mcp_scope_lock_screen() {
    # Bail if there's nothing to scope — empty selection means user picked zero
    # rows in the sub-picker.
    local _have_selection=0
    local _i
    for ((_i=0; _i<${#TUI_RESULTS[@]}; _i++)); do
        if [[ "${TUI_RESULTS[$_i]:-0}" -eq 1 ]]; then
            _have_selection=1
            break
        fi
    done
    if [[ "$_have_selection" -eq 0 ]]; then
        return 0
    fi

    # T-07: build shadow arrays (filtered to selected rows in original render
    # order). Save originals so we can restore after the lock-screen returns.
    local _SAVE_LABELS=("${TUI_LABELS[@]+"${TUI_LABELS[@]}"}")
    local _SAVE_GROUPS=("${TUI_GROUPS[@]+"${TUI_GROUPS[@]}"}")
    local _SAVE_INSTALLED=("${TUI_INSTALLED[@]+"${TUI_INSTALLED[@]}"}")
    local _SAVE_DESCS=("${TUI_DESCS[@]+"${TUI_DESCS[@]}"}")
    local _SAVE_REQUIRED=("${TUI_REQUIRED[@]+"${TUI_REQUIRED[@]}"}")
    local _SAVE_REINSTALLABLE=("${TUI_REINSTALLABLE[@]+"${TUI_REINSTALLABLE[@]}"}")
    local _SAVE_TUI_TO_MCP=("${TUI_TO_MCP_IDX[@]+"${TUI_TO_MCP_IDX[@]}"}")
    local _SAVE_MCP_SCOPE=("${MCP_SELECTED_SCOPE[@]+"${MCP_SELECTED_SCOPE[@]}"}")
    local _SAVE_RESULTS=("${TUI_RESULTS[@]+"${TUI_RESULTS[@]}"}")

    # _SHADOW_ORIG_IDX[$shadow_i] = original $tui_i — used to map results back.
    local _SHADOW_ORIG_IDX=()

    TUI_LABELS=()
    TUI_GROUPS=()
    TUI_INSTALLED=()
    TUI_DESCS=()
    TUI_REQUIRED=()
    TUI_REINSTALLABLE=()
    TUI_TO_MCP_IDX=()
    MCP_SELECTED_SCOPE=()

    for ((_i=0; _i<${#_SAVE_LABELS[@]}; _i++)); do
        if [[ "${_SAVE_RESULTS[$_i]:-0}" -ne 1 ]]; then
            continue
        fi
        _SHADOW_ORIG_IDX+=("$_i")
        TUI_LABELS+=("${_SAVE_LABELS[$_i]}")
        TUI_GROUPS+=("${_SAVE_GROUPS[$_i]}")
        TUI_DESCS+=("${_SAVE_DESCS[$_i]}")
        TUI_REQUIRED+=("${_SAVE_REQUIRED[$_i]:-0}")
        TUI_REINSTALLABLE+=("${_SAVE_REINSTALLABLE[$_i]:-0}")
        TUI_TO_MCP_IDX+=("${_SAVE_TUI_TO_MCP[$_i]:-$_i}")
        # Installed MCPs render with their *current* scope, locked. Newly-
        # selected MCPs use the catalog default already in MCP_SELECTED_SCOPE.
        local _row_name="${MCP_NAMES[${_SAVE_TUI_TO_MCP[$_i]:-$_i}]}"
        local _detected
        _detected=$(mcp_detect_installed_scope "$_row_name")
        if [[ -n "$_detected" ]]; then
            TUI_INSTALLED+=(1)
            MCP_SELECTED_SCOPE+=("$_detected")
        else
            TUI_INSTALLED+=(0)
            MCP_SELECTED_SCOPE+=("${_SAVE_MCP_SCOPE[$_i]:-user}")
        fi
    done

    # Rebuild every shadow-row TUI_LABELS slot from MCP_DISPLAY[] +
    # MCP_SELECTED_SCOPE[] via the canonical helper. Pre-2026-05-12 a manual
    # case-on-scope + prepend loop here read the already-glyphed label out of
    # _SAVE_LABELS (the parent TUI seeded by mcp_status_array's prior
    # _mcp_rebuild_row_labels call) and prepended a SECOND glyph, producing
    # visible `[U] [U] Name` / `[P] [P] Name` on screen until the user pressed
    # Tab (user report 2026-05-12, screenshot). Tab fired
    # `mcp_cycle_row_scope_locked` which rebuilt the row using the same
    # canonical MCP_DISPLAY[] path, masking the bug for that single row.
    # Delegating to the helper here removes the inline prepend entirely; the
    # helper writes a single-glyph label per row in one place.
    _mcp_rebuild_row_labels

    # Wire scope dispatcher and lock the selection.
    export TK_TUI_LOCK_SELECTION=1
    # shellcheck disable=SC2034  # consumed by tui.sh _tui_render
    TUI_HEADER_KEY="s"
    # shellcheck disable=SC2034
    TUI_HEADER_FN="mcp_toggle_scope"
    # shellcheck disable=SC2034
    TUI_ROW_KEY=$'\t'
    # shellcheck disable=SC2034
    TUI_ROW_FN="mcp_cycle_row_scope_locked"
    # shellcheck disable=SC2034
    TUI_HEADER_TEXT="Configure MCP scope (Tab toggles per-row, s sets all)"

    local _lock_rc=0
    tui_checklist || _lock_rc=$?

    unset TK_TUI_LOCK_SELECTION TUI_HEADER_KEY TUI_HEADER_FN \
          TUI_ROW_KEY TUI_ROW_FN TUI_HEADER_TEXT

    if [[ "$_lock_rc" -eq 1 ]]; then
        echo "Install cancelled at scope picker."
        exit 0
    fi

    # Map shadow MCP_SELECTED_SCOPE back into the full-size array at the
    # original positions, then restore the rest of the TUI state for the
    # dispatcher to read.
    local _shadow_scope=("${MCP_SELECTED_SCOPE[@]+"${MCP_SELECTED_SCOPE[@]}"}")
    MCP_SELECTED_SCOPE=("${_SAVE_MCP_SCOPE[@]+"${_SAVE_MCP_SCOPE[@]}"}")
    for ((_i=0; _i<${#_SHADOW_ORIG_IDX[@]}; _i++)); do
        local _orig="${_SHADOW_ORIG_IDX[$_i]}"
        MCP_SELECTED_SCOPE[$_orig]="${_shadow_scope[$_i]}"
    done

    TUI_LABELS=("${_SAVE_LABELS[@]+"${_SAVE_LABELS[@]}"}")
    TUI_GROUPS=("${_SAVE_GROUPS[@]+"${_SAVE_GROUPS[@]}"}")
    TUI_INSTALLED=("${_SAVE_INSTALLED[@]+"${_SAVE_INSTALLED[@]}"}")
    TUI_DESCS=("${_SAVE_DESCS[@]+"${_SAVE_DESCS[@]}"}")
    TUI_REQUIRED=("${_SAVE_REQUIRED[@]+"${_SAVE_REQUIRED[@]}"}")
    TUI_REINSTALLABLE=("${_SAVE_REINSTALLABLE[@]+"${_SAVE_REINSTALLABLE[@]}"}")
    TUI_TO_MCP_IDX=("${_SAVE_TUI_TO_MCP[@]+"${_SAVE_TUI_TO_MCP[@]}"}")
    TUI_RESULTS=("${_SAVE_RESULTS[@]+"${_SAVE_RESULTS[@]}"}")
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

    # Under curl-pipe, _source_lib wrote skills.sh into /tmp/skills-XXXXXX, so
    # skills.sh's BASH_SOURCE-relative mirror resolver collapses to
    # `/var/folders/.../templates/skills-marketplace` — a non-existent path —
    # and every fresh skill install fails with "source missing" (user report
    # 2026-05-12, huashu-design + impeccable). Pre-installed skills mask the
    # bug because the dispatch loop short-circuits "installed ✓" without
    # calling skills_install. Fix: download the toolkit tarball and export
    # both TK_SKILLS_MIRROR_PATH and TK_SKILLS_INSTALL_IMPECCABLE_CMD so the
    # downstream resolvers and the impeccable special-case find their files.
    # Mirrors the MCP-catalog curl-pipe handler at line ~291.
    if _is_curl_pipe && [[ -z "${TK_SKILLS_MIRROR_PATH:-}" ]]; then
        if ! skills_fetch_mirror_via_tarball; then
            echo -e "${RED}✗${NC} Failed to fetch toolkit tarball for skills install — aborting" >&2
            echo -e "  Set TK_SKILLS_MIRROR_PATH manually if you have a local clone." >&2
            exit 1
        fi
        # Audit 2026-05-14 L-2: register the extracted tmpdir for EXIT cleanup.
        if [[ -n "${TK_SKILLS_MIRROR_TMPDIR:-}" ]]; then
            CLEANUP_DIRS+=("$TK_SKILLS_MIRROR_TMPDIR")
        fi
    fi
fi

if [[ "$MCPS" -eq 1 ]]; then
    # MCP catalog page — populate TUI_* arrays from the 9-MCP catalog.
    mcp_catalog_load || {
        echo -e "${RED}✗${NC} Failed to load MCP catalog" >&2
        exit 1
    }
    mcp_status_array

    # Phase 39 (HIGH-02): CLI --mcp-scope wins over catalog defaults in
    # headless paths. mcp_status_array seeds MCP_SELECTED_SCOPE[] from
    # MCP_DEFAULT_SCOPE[i] (catalog defaults); without this broadcast, the
    # --yes and TK_MCP_PRE_SELECTED paths never run Tab/`s` so the CLI flag
    # is silently lost (D-18 violation). Per-row Tab/`s` mutations during
    # the interactive TUI still override per-iteration (writes land in
    # MCP_SELECTED_SCOPE before the dispatcher reads it at line ~615).
    if [[ -n "${TK_MCP_SCOPE_CLI:-}" ]]; then
        case "$TK_MCP_SCOPE_CLI" in
            user|local|project)
                if [[ -n "${MCP_SELECTED_SCOPE[*]+x}" ]]; then
                    for ((_si=0; _si<${#MCP_SELECTED_SCOPE[@]}; _si++)); do
                        MCP_SELECTED_SCOPE[$_si]="$TK_MCP_SCOPE_CLI"
                    done
                    unset _si
                    # Phase 39 MED-03: re-render TUI_LABELS[] from the new
                    # MCP_SELECTED_SCOPE[] values so the interactive --mcp-scope
                    # path shows row-glyphs that agree with the banner and the
                    # actual install scope. mcp_status_array seeded labels from
                    # MCP_DEFAULT_SCOPE[]; without this rebuild, labels would
                    # display the catalog-default mix while dispatch installs
                    # to the broadcast scope. Headless paths (--yes /
                    # TK_MCP_PRE_SELECTED) skip the TUI render so the cost is
                    # purely string-rebuild — no visible difference.
                    _mcp_rebuild_row_labels
                fi
                ;;
        esac
    fi

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
    # Phase 34-01 ordering: TUI_LABELS / TUI_INSTALLED are populated by
    # mcp_status_array in TUI render order (category-grouped, alpha-within),
    # NOT in MCP_NAMES alphabetical order. Iterate by TUI render index and
    # translate to MCP_NAMES idx via TUI_TO_MCP_IDX[] when reading per-entry
    # catalog metadata (MCP_OAUTH[], MCP_NAMES[], etc.).
    local_count=${#TUI_LABELS[@]}
    if [[ -n "${TK_MCP_PRE_SELECTED+x}" ]]; then
        # Headless. Comma-separated names → 0/1 per row by exact match against MCP_NAMES.
        _pre_csv="${TK_MCP_PRE_SELECTED:-}"
        _IFS_SAVE="$IFS"
        IFS=','
        # shellcheck disable=SC2206  # intentional word-split on ','
        _pre_arr=( $_pre_csv )
        IFS="$_IFS_SAVE"
        for ((tui_i=0; tui_i<local_count; tui_i++)); do
            TUI_RESULTS[$tui_i]=0
            _mcp_idx="${TUI_TO_MCP_IDX[$tui_i]:-$tui_i}"
            for _pname in "${_pre_arr[@]+"${_pre_arr[@]}"}"; do
                if [[ "$_pname" == "${MCP_NAMES[$_mcp_idx]}" ]]; then
                    TUI_RESULTS[$tui_i]=1
                    break
                fi
            done
        done
        unset _pre_csv _IFS_SAVE _pre_arr _pname _mcp_idx tui_i

        # v6.16.0 (T-05) — render the scope lock-screen so the user can pick
        # per-row scope before the dispatcher fires. Skipped when:
        #   - --mcp-scope was passed on CLI (TK_MCP_SCOPE_CLI applies set-all)
        #   - --yes was passed (non-interactive)
        #   - no readable TTY (CI / piped install)
        # Selection is locked at this point (came from the sub-picker), so the
        # lock-screen exposes only the scope toggle (Tab/`s`) — see
        # _run_mcp_scope_lock_screen above.
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ -z "${TK_MCP_SCOPE_CLI:-}" ]] \
           && [[ "$YES" -ne 1 ]] \
           && [[ -r "$_install_tty_src" ]]; then
            _run_mcp_scope_lock_screen
        fi
    elif [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; skip OAuth-only unless --force
        # (OAuth needs interactive browser flow — incompatible with --yes).
        for ((tui_i=0; tui_i<local_count; tui_i++)); do
            _mcp_idx="${TUI_TO_MCP_IDX[$tui_i]:-$tui_i}"
            if [[ "${TUI_INSTALLED[$tui_i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$tui_i]=0
                continue
            fi
            if [[ "${MCP_OAUTH[$_mcp_idx]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$tui_i]=0
                continue
            fi
            TUI_RESULTS[$tui_i]=1
        done
        unset _mcp_idx tui_i
    else
        # TTY check (mirrors Phase 24 _install_tty_src gate).
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ ! -r "$_install_tty_src" ]]; then
            echo "No TTY available for MCP TUI; pass --yes for non-interactive install."
            exit 0
        fi
        # Phase 37 (preserved for CLI --mcp-scope) + Phase 39 (TUI-SCOPE-03/05):
        # The pre-loop TK_MCP_SCOPE export is kept ONLY so the v4.9 CLI flag
        # --mcp-scope still wins for non-interactive scripted use. The TUI
        # dispatcher loop overwrites TK_MCP_SCOPE per-iteration from
        # MCP_SELECTED_SCOPE[$tui_i] (around line 600+) so this initial
        # export is effectively replaced once any TUI wizard runs (D-17/D-18).
        TK_MCP_SCOPE="${TK_MCP_SCOPE:-user}"
        export TK_MCP_SCOPE
        # Phase 39 (banner cosmetics): seed the set-all banner from CLI
        # --mcp-scope so the initial render reflects the user's CLI choice.
        # Per-row MCP_SELECTED_SCOPE[] still wins for actual dispatch
        # (D-13/D-15) — this assignment is purely banner display state.
        # LOW-03 fix: defense-in-depth validation. If a malformed
        # TK_MCP_SCOPE leaks in (caller bypassed the argument-parser
        # validator, or env from another tool), refuse outright rather
        # than letting mcp_render_scope_header silently fall through to
        # `[U]` while mcp_toggle_scope's first cycle silently drops it.
        _MCP_SETALL_SCOPE="${TK_MCP_SCOPE:-user}"
        case "$_MCP_SETALL_SCOPE" in
            user|local|project) ;;
            *) _MCP_SETALL_SCOPE="user" ;;
        esac
        mcp_render_scope_header
        # shellcheck disable=SC2034  # consumed by tui.sh _tui_render via TUI_HEADER_KEY/FN
        TUI_HEADER_KEY="s"
        # shellcheck disable=SC2034
        TUI_HEADER_FN="mcp_toggle_scope"
        # Phase 39 (TUI-SCOPE-02): per-row scope hotkey wiring — TUI_ROW_KEY
        # / TUI_ROW_FN globals. Tab byte ($'\t') dispatches mcp_cycle_row_scope
        # to mutate the focused row's MCP_SELECTED_SCOPE slot. Mirrors the
        # TUI_HEADER_KEY/FN shape; consumed by tui.sh's case-match Tab arm
        # (Plan 01 wired it).
        # shellcheck disable=SC2034  # consumed by tui.sh _tui_render via TUI_ROW_KEY
        TUI_ROW_KEY=$'\t'
        # shellcheck disable=SC2034  # consumed by tui.sh _tui_render via TUI_ROW_FN
        TUI_ROW_FN="mcp_cycle_row_scope"
        if ! tui_checklist; then
            unset TUI_HEADER_TEXT TUI_HEADER_KEY TUI_HEADER_FN \
                  TUI_ROW_KEY TUI_ROW_FN
            echo "MCP install cancelled."
            exit 0
        fi
        unset TUI_HEADER_TEXT TUI_HEADER_KEY TUI_HEADER_FN \
              TUI_ROW_KEY TUI_ROW_FN
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
    # Phase 34-02: per-component (MCP × CLI) result tracking — RESULT_* arrays
    # are populated alongside the legacy COMPONENT_* arrays so the existing
    # "MCP install summary" block keeps working unchanged. Plan 34-03 reads
    # these for the per-component summary table.
    RESULT_NAMES=()
    RESULT_MCP_STATE=()
    RESULT_CLI_STATE=()
    # Pass --yes through to unofficial_confirm via ALWAYS_YES (the symmetry
    # name used in mcp.sh:unofficial_confirm — keeps the env-var contract
    # decoupled from install.sh's $YES variable for testability).
    if [[ "$YES" -eq 1 ]]; then
        export ALWAYS_YES=1
    fi
    # Phase 34-01 ordering: TUI_RESULTS / TUI_INSTALLED / TUI_LABELS are
    # populated by tui_checklist in TUI render order (category-grouped).
    # MCP_NAMES is alphabetical. Iterate by TUI index and translate via
    # TUI_TO_MCP_IDX[] to the catalog index used by MCP_DISPLAY[],
    # MCP_HAS_CLI[], MCP_UNOFFICIAL[], etc.
    local_mcp_count=${#TUI_LABELS[@]}
    for ((tui_i=0; tui_i<local_mcp_count; tui_i++)); do
        i="${TUI_TO_MCP_IDX[$tui_i]:-$tui_i}"
        local_name="${MCP_NAMES[$i]}"
        COMPONENT_NAMES+=("$local_name")
        RESULT_NAMES+=("$local_name")
        if [[ "${TUI_RESULTS[$tui_i]:-0}" -ne 1 ]]; then
            if [[ "${TUI_INSTALLED[$tui_i]}" -eq 1 ]]; then
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                RESULT_MCP_STATE+=("already")
            else
                COMPONENT_STATUS+=("skipped")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                RESULT_MCP_STATE+=("skipped:unselected")
            fi
            # CLI side parallels: nothing to install when row not selected.
            if [[ "${MCP_HAS_CLI[$i]:-0}" == "1" ]]; then
                RESULT_CLI_STATE+=("skipped:unselected")
            else
                RESULT_CLI_STATE+=("na")
            fi
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Phase 34-02 (TUI-03): unofficial confirm gate. Runs BEFORE any install
        # action so a declined entry is recorded as skipped without touching
        # claude or the host CLI. --yes (ALWAYS_YES=1) bypasses the prompt.
        if [[ "${MCP_UNOFFICIAL[$i]:-0}" == "1" ]]; then
            if ! unofficial_confirm "${MCP_DISPLAY[$i]}"; then
                COMPONENT_STATUS+=("skipped: unofficial declined")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                RESULT_MCP_STATE+=("skipped:unofficial-declined")
                if [[ "${MCP_HAS_CLI[$i]:-0}" == "1" ]]; then
                    RESULT_CLI_STATE+=("skipped:unofficial-declined")
                else
                    RESULT_CLI_STATE+=("na")
                fi
                continue
            fi
        fi

        # ─── MCP install branch ────────────────────────────────────────────
        # Phase 34-02 (TUI-04): --cli-only skips the MCP install step. The
        # entry's CLI is installed below so the row is not entirely skipped.
        if [[ "$CLI_ONLY" -eq 1 ]]; then
            COMPONENT_STATUS+=("skipped (--cli-only)")
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            COMPONENT_STDERR_TAIL+=("")
            RESULT_MCP_STATE+=("skipped:cli-only")
        else
            # Capture stderr to a per-MCP tmpfile (D-28).
            # Audit L2: do not embed the component name in the path so shared
            # `/tmp` on Linux can't enumerate which MCPs the user installs.
            stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-mcp.XXXXXX") || stderr_tmp=""
            [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

            local_flags=()
            [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")

            # Phase 39 (TUI-SCOPE-05 D-17): export per-row scope for THIS
            # iteration's mcp_wizard_run invocation. The pre-loop export at
            # the TUI launch site set the CLI --mcp-scope value or "user"
            # default; we overwrite per-iteration so each MCP gets its own
            # scope (TUI Tab/`s` mutations land in MCP_SELECTED_SCOPE — read
            # here as the source of truth). Index basis is $tui_i (TUI render
            # order — parallel to MCP_SELECTED_SCOPE), NOT $i (MCP_NAMES alpha
            # index — wrong frame). Fallback to "user" when MCP_SELECTED_SCOPE
            # is unset/empty (defensive: pre-v5.0 callers, headless scripts
            # before mcp_status_array runs). The reinstall block immediately
            # below reads _scope_for_rm via ${TK_MCP_SCOPE:-user} so this
            # export drives BOTH `claude mcp remove --scope X` AND the wizard
            # call with the row-correct scope.
            TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"
            export TK_MCP_SCOPE

            # Phase 36-A: reinstall path — TUI_INSTALLED[tui_i]=1 AND
            # TUI_RESULTS[tui_i]=1 means the user toggled the row from
            # `[installed ✓]` to `[reinstall ↻]`. `claude mcp add` rejects
            # already-registered names, so remove first then re-add via
            # mcp_wizard_run. Skip the remove under --dry-run (no side
            # effects) — the wizard's --dry-run still prints the "would run
            # add" line which is what the user wants to see.
            local_reinstall=0
            if [[ "${TUI_INSTALLED[$tui_i]:-0}" -eq 1 ]]; then
                local_reinstall=1
                if [[ "$DRY_RUN" -ne 1 ]]; then
                    _claude_bin="${TK_MCP_CLAUDE_BIN:-claude}"
                    # Phase 37: pass --scope so we delete the entry from the
                    # same scope mcp_wizard_run will re-add it to. Without
                    # this, a user who toggled to `local` could end up with
                    # the old `user`-scope row still registered (or vice
                    # versa). `claude mcp remove --scope X` is a no-op when
                    # the name isn't in that scope, so falling through to
                    # the next add is safe under either ordering.
                    _scope_for_rm="${TK_MCP_SCOPE:-user}"
                    "$_claude_bin" mcp remove --scope "$_scope_for_rm" "$local_name" >/dev/null 2>&1 || true
                    unset _claude_bin _scope_for_rm
                fi
            fi

            local_rc=0
            if [[ -n "$stderr_tmp" ]]; then
                ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) >"$stderr_tmp" 2>&1 || local_rc=$?
            else
                mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
            fi

            case "$local_rc" in
                0)
                    if [[ "$DRY_RUN" -eq 1 ]]; then
                        if [[ "$local_reinstall" -eq 1 ]]; then
                            COMPONENT_STATUS+=("would-reinstall")
                            RESULT_MCP_STATE+=("would-reinstall")
                        else
                            COMPONENT_STATUS+=("would-install")
                            RESULT_MCP_STATE+=("would-install")
                        fi
                    else
                        if [[ "$local_reinstall" -eq 1 ]]; then
                            COMPONENT_STATUS+=("reinstalled ↻")
                            RESULT_MCP_STATE+=("reinstalled")
                        else
                            COMPONENT_STATUS+=("installed ✓")
                            RESULT_MCP_STATE+=("installed")
                        fi
                        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    fi
                    COMPONENT_STDERR_TAIL+=("")
                    ;;
                2)
                    COMPONENT_STATUS+=("skipped: claude unavailable")
                    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    COMPONENT_STDERR_TAIL+=("")
                    RESULT_MCP_STATE+=("skipped:claude-unavailable")
                    ;;
                3)
                    # rc=3 — server registered with claude CLI but has no env
                    # binding yet (deferred-secrets path). Counted as installed
                    # so the summary doesn't read like a failure; the follow-up
                    # block tells the user how to add the key.
                    COMPONENT_STATUS+=("installed (needs API key)")
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                    COMPONENT_STDERR_TAIL+=("")
                    RESULT_MCP_STATE+=("installed:needs-key")
                    ;;
                *)
                    COMPONENT_STATUS+=("failed (exit $local_rc)")
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    local_tail=""
                    if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
                        local_tail=$(tail -5 "$stderr_tmp")
                    fi
                    COMPONENT_STDERR_TAIL+=("$local_tail")
                    # Record the first stderr line (or short reason) for table notes.
                    local_first_line=""
                    if [[ -n "$local_tail" ]]; then
                        local_first_line=$(printf '%s' "$local_tail" | head -n1)
                    fi
                    RESULT_MCP_STATE+=("failed:exit-${local_rc}: ${local_first_line}")
                    if [[ "$FAIL_FAST" -eq 1 ]]; then
                        # Fail-fast: pad remaining slots so the parallel arrays
                        # stay aligned (RESULT_* and COMPONENT_* / TUI_RESULTS).
                        # Iterate by TUI index (matches outer loop), translate
                        # to MCP_NAMES idx via TUI_TO_MCP_IDX[] before reading
                        # per-entry catalog metadata (MCP_HAS_CLI[], etc.).
                        # Top-level shell context — `local` is illegal; use
                        # plain assignment + underscore prefix.
                        _j_mcp=""
                        for ((j=tui_i+1; j<local_mcp_count; j++)); do
                            _j_mcp="${TUI_TO_MCP_IDX[$j]:-$j}"
                            COMPONENT_NAMES+=("${MCP_NAMES[$_j_mcp]}")
                            COMPONENT_STATUS+=("skipped")
                            COMPONENT_STDERR_TAIL+=("")
                            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                            RESULT_NAMES+=("${MCP_NAMES[$_j_mcp]}")
                            RESULT_MCP_STATE+=("skipped:fail-fast")
                            if [[ "${MCP_HAS_CLI[$_j_mcp]:-0}" == "1" ]]; then
                                RESULT_CLI_STATE+=("skipped:fail-fast")
                            else
                                RESULT_CLI_STATE+=("na")
                            fi
                        done
                        unset _j_mcp
                        break 2   # break BOTH the case + outer for-i
                    fi
                    ;;
            esac
        fi

        # ─── CLI install branch ───────────────────────────────────────────
        # Phase 34-02 (TUI-04): --mcp-only skips the CLI install step.
        # Entries without a `components.cli` block report "na" regardless.
        # When the MCP side was skipped because the claude runtime is absent
        # (rc=2), the user is in browse-only mode — do NOT trigger eager CLI
        # installs that would surprise them with brew/npm activity. Only
        # --cli-only opts into the CLI side regardless of MCP-side state.
        _last_mcp_state="${RESULT_MCP_STATE[$((${#RESULT_MCP_STATE[@]} - 1))]:-}"
        if [[ "${MCP_HAS_CLI[$i]:-0}" != "1" ]]; then
            RESULT_CLI_STATE+=("na")
        elif [[ "$MCP_ONLY" -eq 1 ]]; then
            RESULT_CLI_STATE+=("skipped:mcp-only")
        elif [[ "$CLI_ONLY" -ne 1 ]] && [[ "$_last_mcp_state" == skipped:claude-unavailable ]]; then
            # MCP runtime missing → keep the row consistent: don't install CLI
            # under --yes default. User can re-run with --cli-only to override.
            RESULT_CLI_STATE+=("skipped:claude-unavailable")
        elif [[ "${CLI_STATUS[$i]:-absent}" == "installed" ]] && [[ "$FORCE" -ne 1 ]]; then
            # Already installed — cli_install would re-run the brew/npm command
            # which is idempotent but wasteful. Record as "already" so the
            # summary table can render ⊘ without misleading the user.
            RESULT_CLI_STATE+=("already")
        elif [[ "$DRY_RUN" -eq 1 ]]; then
            RESULT_CLI_STATE+=("would-install")
        else
            # Resolve install commands from the catalog. install.darwin /
            # install.linux are required schema fields when components.cli
            # is present (Phase 32-01 validator). `// empty` defends against
            # forward-compat schema variants where these become optional.
            _cli_catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
            _darwin_cmd=$(jq -r --arg n "$local_name" '.components.cli[$n].install.darwin // empty' "$_cli_catalog_path")
            _linux_cmd=$(jq -r --arg n "$local_name" '.components.cli[$n].install.linux // empty' "$_cli_catalog_path")
            _post_hint=$(jq -r --arg n "$local_name" '.components.cli[$n].post_install_hint // empty' "$_cli_catalog_path")
            cli_stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-cli.XXXXXX") || cli_stderr_tmp=""
            [[ -n "$cli_stderr_tmp" ]] && CLEANUP_PATHS+=("$cli_stderr_tmp")
            cli_rc=0
            if [[ -z "$_darwin_cmd" || -z "$_linux_cmd" ]]; then
                # Schema corruption — record + skip (don't abort the whole loop).
                RESULT_CLI_STATE+=("failed:catalog-missing-install-cmd")
                FAILED_COUNT=$((FAILED_COUNT + 1))
            else
                if [[ -n "$cli_stderr_tmp" ]]; then
                    ( cli_install "$local_name" "$_darwin_cmd" "$_linux_cmd" ) >"$cli_stderr_tmp" 2>&1 || cli_rc=$?
                else
                    cli_install "$local_name" "$_darwin_cmd" "$_linux_cmd" || cli_rc=$?
                fi
                case "$cli_rc" in
                    0)
                        RESULT_CLI_STATE+=("installed")
                        if [[ -n "$_post_hint" ]]; then
                            cli_post_install_hint "$_post_hint"
                        fi
                        ;;
                    2)
                        RESULT_CLI_STATE+=("skipped:unsupported-platform")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                        ;;
                    3)
                        RESULT_CLI_STATE+=("skipped:brew-absent")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                        ;;
                    *)
                        cli_first_line=""
                        if [[ -n "$cli_stderr_tmp" && -s "$cli_stderr_tmp" ]]; then
                            cli_first_line=$(head -n1 "$cli_stderr_tmp")
                        fi
                        RESULT_CLI_STATE+=("failed:exit-${cli_rc}: ${cli_first_line}")
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                        ;;
                esac
            fi
            unset _darwin_cmd _linux_cmd _post_hint _cli_catalog_path
        fi
        unset _last_mcp_state
    done

    # Bubble per-item status up to the parent install.sh (if invoked under
    # one) so the top-level summary can render an indented breakdown under
    # the `mcp-servers` parent row instead of a single rolled-up "installed ✓".
    if [[ -n "${TK_CHILD_STATE_DIR:-}" && -d "${TK_CHILD_STATE_DIR}" ]]; then
        {
            for ((j=0; j<${#COMPONENT_NAMES[@]}; j++)); do
                printf '%s\t%s\n' "${COMPONENT_NAMES[$j]}" "${COMPONENT_STATUS[$j]:-unknown}"
            done
        } > "${TK_CHILD_STATE_DIR}/mcp-servers.tsv" 2>/dev/null || true
    fi

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
        # Phase 38 (DISP-03/DISP-04): 4-field queue reader. Pre-v5.0 producers
        # leave the 4th field empty — fall back to scope=user for empty d_scope
        # (mirrors mcp.sh:674 default). Buckets per scope so two-block dispatch
        # (D-16) prints user-scope block first, project-scope block second.
        _user_rows=()
        _project_rows=()
        # shellcheck disable=SC2034  # d_args read positionally to skip the 3rd field; we only consume name/keys/scope here
        while IFS=$'\t' read -r d_name d_keys d_args d_scope; do
            [[ -z "$d_name" ]] && continue
            # D-10 back-compat: empty 4th field → scope=user (mirrors mcp.sh:674).
            [[ -z "${d_scope:-}" ]] && d_scope="user"
            case "$d_scope" in
                project) _project_rows+=("${d_name}"$'\t'"${d_keys}") ;;
                local|user|*) _user_rows+=("${d_name}"$'\t'"${d_keys}") ;;
            esac
        done < "$TK_MCP_DEFERRED_QUEUE"
        unset d_name d_keys d_args d_scope

        # ─── User-scope block (existing v4.9 copy — UNCHANGED) ───────────────
        if [[ "${#_user_rows[@]}" -gt 0 ]]; then
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
            # Phase 38 (MED-01 fix): wrap `set -- $_row` in a subshell so the
            # positional-param mutation is contained. At top-level, `set --`
            # would permanently overwrite the script's $@/$1/$2 — latent
            # time-bomb for any future feature flag check after summary or
            # `exec "$@"` re-entry. Subshell isolates the mutation per row.
            for _row in "${_user_rows[@]}"; do
                (
                    _IFS_SAVED2="$IFS"
                    IFS=$'\t'
                    # shellcheck disable=SC2086
                    set -- $_row
                    IFS="$_IFS_SAVED2"
                    _row_keys="$2"
                    IFS=','
                    for _k in $_row_keys; do
                        _k="${_k# }"
                        [[ -z "$_k" ]] && continue
                        printf '       %s=<your-key>\n' "$_k"
                    done
                )
            done
            unset _row
            echo ""
            case "$_rc_added" in
                1) echo "  2) Shell rc updated: auto-source line added to ${_shell_rc/#$HOME/~}." ;;
                2) echo "  2) Shell rc already configured (auto-source line found in ${_shell_rc/#$HOME/~})." ;;
                *) echo "  2) Could not detect/write to your shell rc. Add this ONE line to ~/.zshrc (or ~/.bashrc) manually:"
                   echo "       set -a; [ -f ~/.claude/mcp-config.env ] && . ~/.claude/mcp-config.env; set +a" ;;
            esac
            echo ""
            echo "  3) Reload shell env (open a fresh terminal, or run: exec \$SHELL) and start claude."
            unset _shell_rc _rc_added _rc_marker
        fi

        # ─── Project-scope block (NEW — D-14 copy) ───────────────────────────
        if [[ "${#_project_rows[@]}" -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}Some project-scope MCPs need API keys finished:${NC}"
            echo ""
            echo "  1) Open <project>/.env (already stubbed; mode 0600) and fill in:"
            # Phase 38 (MED-01 fix): wrap `set -- $_row` in a subshell — see
            # mirror comment on the user-block above. Project-block cloned
            # the v4.9 user-block pattern in Phase 38, doubling the surface
            # for the latent positional-param mutation; subshell contains it.
            for _row in "${_project_rows[@]}"; do
                (
                    _IFS_SAVED2="$IFS"
                    IFS=$'\t'
                    # shellcheck disable=SC2086
                    set -- $_row
                    IFS="$_IFS_SAVED2"
                    _row_keys="$2"
                    IFS=','
                    for _k in $_row_keys; do
                        _k="${_k# }"
                        [[ -z "$_k" ]] && continue
                        printf '       %s=<your-key>\n' "$_k"
                    done
                )
            done
            unset _row
            echo ""
            echo "  2) <project>/.gitignore already includes .env (toolkit added it)."
            echo ""
            echo "  3) Reload shell env from the project dir (or restart claude) and the MCP picks up the keys."
        fi

        unset _user_rows _project_rows
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
    # Populate TUI_INSTALLED[] from SKILLS_CATALOG (sourced from scripts/lib/skills.sh).
    skills_status_array

    # Build TUI globals from SKILLS_CATALOG.
    # shellcheck disable=SC2034  # consumed by tui_checklist
    TUI_LABELS=("${SKILLS_CATALOG[@]}")
    # shellcheck disable=SC2034
    TUI_GROUPS=()
    # shellcheck disable=SC2034
    TUI_DESCS=()
    # shellcheck disable=SC2034  # consumed by tui_checklist for inline GitHub URL render
    TUI_URLS=()
    local_total=${#SKILLS_CATALOG[@]}
    for ((i=0; i<local_total; i++)); do
        TUI_GROUPS+=("Skills")
        TUI_DESCS+=("$(_skills_description "${SKILLS_CATALOG[$i]}")")
        TUI_URLS+=("$(_skills_upstream_url "${SKILLS_CATALOG[$i]}")")
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
    # Bubble per-skill status up to parent install.sh (see same block in --mcps
    # mode for rationale). Parent reads this TSV and prints indented breakdown.
    if [[ -n "${TK_CHILD_STATE_DIR:-}" && -d "${TK_CHILD_STATE_DIR}" ]]; then
        {
            for ((j=0; j<${#COMPONENT_NAMES[@]}; j++)); do
                printf '%s\t%s\n' "${COMPONENT_NAMES[$j]}" "${COMPONENT_STATUS[$j]:-unknown}"
            done
        } > "${TK_CHILD_STATE_DIR}/skills.tsv" 2>/dev/null || true
    fi

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
)
# shellcheck disable=SC2034
TUI_GROUP_DESCS=(
    "Foundation plugins this toolkit complements (skills + workflow). Skip if you don't want them."
    "The toolkit itself — commands, agents, prompts, skills, rules for the project. Required."
    "Add-ons: security rules, token saver, statusline, multi-AI council. Pick what you want."
    "Mirror. Auto-regenerated GEMINI.md / AGENTS.md copies of CLAUDE.md so other AI CLIs read the same context."
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

# claude-memo: optional persistent engineering memory (vault + embeddings
# + auto-capture hooks). Detect via a unique signature file under any
# skill dir AND a populated vault. The skill may be installed via the
# toolkit's standalone installer (skills/memo-skill/) OR through a
# skills-marketplace that prepends a prefix (skills/i-memo-skill/), or
# any custom prefix. Probing by signature file (scripts/memo_engine.py
# is unique to claude-memo) is prefix-agnostic. Vault location is
# user-configurable via $MEMO_VAULT_PATH (set by claude-memo installer
# in shell rc); fall back to the default path. Either condition alone
# is incomplete state. The wrapper is idempotent so detection is a
# hint, not a hard gate.
IS_MEMO=0
_memo_vault="${MEMO_VAULT_PATH:-$HOME/memo-vault}"
_memo_skill_present=0
for _f in "$HOME/.claude/skills"/*/scripts/memo_engine.py; do
    [[ -f "$_f" ]] && { _memo_skill_present=1; break; }
done
if [[ $_memo_skill_present -eq 1 ]] && [[ -f "$_memo_vault/INDEX.md" ]]; then
    IS_MEMO=1
fi
unset _memo_vault _memo_skill_present _f
TUI_LABELS+=("claude-memo")
TUI_GROUPS+=("Optional")
TUI_INSTALLED+=("$IS_MEMO")
TUI_REQUIRED+=("0")
TUI_DESCS+=("Persistent engineering memory — vault + 4 hooks (downloads ~1.1GB embedding model)")

# BRIDGE-UX-01 (Phase 30): conditional bridge rows. ONLY appear when the corresponding CLI
# is detected; CLIs absent => row OMITTED entirely (no greyed-out [unavailable] line).
# When NO_BRIDGES=true the rows are STILL omitted from arrays so default-set, TUI render,
# and dispatch loop all see a 6-element world (= unchanged BACKCOMPAT-01 invariant).
#
# Idempotency probe: the main-TUI dispatch shim (search this file for
# BRIDGE-UX-01) calls `bridge_create_global` — never `bridge_create_project` —
# so the canonical bridge files live under the per-target global dirs:
#   gemini → $(_bridge_global_dir gemini)/GEMINI.md  (= $HOME/.gemini/GEMINI.md)
#   codex  → $(_bridge_global_dir codex)/AGENTS.md   (= $HOME/.codex/AGENTS.md)
# We confirm ownership by grepping the auto-generated banner
# ("claude-code-toolkit") in the first 5 lines — distinguishes the toolkit's
# bridge from a hand-written GEMINI.md/AGENTS.md the user may already keep at
# that path. The earlier `$PWD/{GEMINI,AGENTS}.md` probe (added in #64) was a
# leftover from the original `bridge_create_project` plan; the dispatch shim
# was switched to global in v4.8 (#14) and the probe was never updated, so
# the TUI re-offered both bridges on every install run even after a
# successful install (user report 2026-05-14, v6.25.2).
_bridge_target_installed() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    head -5 "$file" 2>/dev/null | grep -q "claude-code-toolkit"
}
if [[ "$NO_BRIDGES" != "true" ]]; then
    if [[ "${IS_GEM:-0}" -eq 1 ]]; then
        _gem_ver="$(_bridge_cli_version gemini)"
        _gem_suffix="${_gem_ver:+@${_gem_ver}}"
        _gem_installed=0
        _gem_global_path="$(_bridge_global_dir gemini)/GEMINI.md"
        _bridge_target_installed "$_gem_global_path" && _gem_installed=1
        TUI_LABELS+=("gemini-bridge")
        TUI_GROUPS+=("Bridges")
        TUI_INSTALLED+=("$_gem_installed")
        TUI_REQUIRED+=("0")
        TUI_DESCS+=("Gemini CLI bridge (CLAUDE.md -> GEMINI.md) [detected: gemini${_gem_suffix}]")
        unset _gem_ver _gem_suffix _gem_installed _gem_global_path
    fi
    if [[ "${IS_COD:-0}" -eq 1 ]]; then
        _cod_ver="$(_bridge_cli_version codex)"
        _cod_suffix="${_cod_ver:+@${_cod_ver}}"
        _cod_installed=0
        _cod_global_path="$(_bridge_global_dir codex)/AGENTS.md"
        _bridge_target_installed "$_cod_global_path" && _cod_installed=1
        TUI_LABELS+=("codex-bridge")
        TUI_GROUPS+=("Bridges")
        TUI_INSTALLED+=("$_cod_installed")
        TUI_REQUIRED+=("0")
        TUI_DESCS+=("OpenAI Codex CLI bridge (CLAUDE.md -> AGENTS.md) [detected: codex${_cod_suffix}]")
        unset _cod_ver _cod_suffix _cod_installed _cod_global_path
    fi
fi

# Marketplace catalog pickers (skills, mcp-servers) are NOT shown in the main TUI
# — the dedicated sub-pickers always run after main TUI Submit (interactive mode
# only) and the user picks individual items there. We append the labels to the
# parallel arrays AFTER tui_checklist returns so the dispatch loop processes
# them with TUI_RESULTS=1. In --yes / headless mode these are NOT appended,
# preserving the prior CI-safe behavior (no nested TUI in CI).

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
    #
    # Note: this is the main TUI only. Sub-pickers (skills, MCP) below run in
    # the UX-FLOW-01 pre-collection block. When a sub-picker presses 'b'
    # (Back), the pre-collection block jumps back here by setting
    # TK_TUI_REDO_MAIN=1 and `continue`-ing its enclosing loop. We don't wrap
    # this single-call site in a loop ourselves — the back-jump is handled
    # by the outer pre-collection state machine.
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
    # ─────────────────────────────────────────────
    # v6.16.0 — linear pre-collection: skills → mcp → dispatch.
    # The Phase 36-A back-navigation state machine (TK_TUI_ALLOW_BACK + rc=4
    # + outer redo-main loop) was removed in T-08b per user request
    # 2026-05-10 ("убрать Back отовсюду"). Cancel via Ctrl+C / q in any
    # sub-picker aborts the whole install (rc=1 → exit 0).
    #
    # save/restore helpers below remain because each sub-picker rebuilds
    # TUI_* with its own catalog contents; the dispatcher at line ~2120
    # needs the MAIN-TUI rows (toolkit, security, mcp-servers, skills, …)
    # to drive its install loop. The helpers swap state in/out around each
    # sub-picker.
    # ─────────────────────────────────────────────

    _save_main_tui_state() {
        _SAVE_TUI_LABELS=("${TUI_LABELS[@]+"${TUI_LABELS[@]}"}")
        _SAVE_TUI_RESULTS=("${TUI_RESULTS[@]+"${TUI_RESULTS[@]}"}")
        _SAVE_TUI_INSTALLED=("${TUI_INSTALLED[@]+"${TUI_INSTALLED[@]}"}")
        _SAVE_TUI_GROUPS=("${TUI_GROUPS[@]+"${TUI_GROUPS[@]}"}")
        _SAVE_TUI_DESCS=("${TUI_DESCS[@]+"${TUI_DESCS[@]}"}")
        _SAVE_TUI_REQUIRED=("${TUI_REQUIRED[@]+"${TUI_REQUIRED[@]}"}")
        _SAVE_TUI_REINSTALLABLE=("${TUI_REINSTALLABLE[@]+"${TUI_REINSTALLABLE[@]}"}")
    }
    _restore_main_tui_state() {
        TUI_LABELS=("${_SAVE_TUI_LABELS[@]+"${_SAVE_TUI_LABELS[@]}"}")
        TUI_RESULTS=("${_SAVE_TUI_RESULTS[@]+"${_SAVE_TUI_RESULTS[@]}"}")
        TUI_INSTALLED=("${_SAVE_TUI_INSTALLED[@]+"${_SAVE_TUI_INSTALLED[@]}"}")
        TUI_GROUPS=("${_SAVE_TUI_GROUPS[@]+"${_SAVE_TUI_GROUPS[@]}"}")
        TUI_DESCS=("${_SAVE_TUI_DESCS[@]+"${_SAVE_TUI_DESCS[@]}"}")
        TUI_REQUIRED=("${_SAVE_TUI_REQUIRED[@]+"${_SAVE_TUI_REQUIRED[@]}"}")
        TUI_REINSTALLABLE=("${_SAVE_TUI_REINSTALLABLE[@]+"${_SAVE_TUI_REINSTALLABLE[@]}"}")
        unset _SAVE_TUI_LABELS _SAVE_TUI_RESULTS _SAVE_TUI_INSTALLED \
              _SAVE_TUI_GROUPS _SAVE_TUI_DESCS _SAVE_TUI_REQUIRED \
              _SAVE_TUI_REINSTALLABLE
    }

    # Sub-pickers always run in interactive mode — the catalog rows were
    # removed from main TUI per user request 2026-05-06 ("redundant info,
    # the actual choice happens in next step anyway"). Sub-picker itself is
    # the opt-out: Submit empty = skip catalog entirely.

    # ─────────────── Skills sub-picker ───────────────
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
        TUI_DESCS+=("$(_skills_description "${SKILLS_CATALOG[$_sk_i]}")")
        TUI_REQUIRED+=(0)
    done
    unset _sk_i
    TUI_RESULTS=()
    _rc=0
    tui_checklist || _rc=$?
    case "$_rc" in
        0)
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
            ;;
        *)
            echo "Skills selection cancelled — aborting install."
            exit 0
            ;;
    esac

    # ─────────────── MCP sub-picker ───────────────
    echo ""
    echo -e "${CYAN}Loading MCP catalog (probing claude CLI for installed servers — a few seconds)...${NC}"
    # Same curl-pipe rationale as the top-level MCPS branch above: declare
    # project_secrets_* before mcp.sh's lazy-source guard runs.
    _source_lib project-secrets
    _source_lib mcp
    if _is_curl_pipe && [[ -z "${TK_MCP_CATALOG_PATH:-}" ]]; then
        # BSD mktemp (macOS): X-run must be at end. Drop .json
        # to avoid literal-filename collision on re-runs.
        MCP_CATALOG_TMP=$(mktemp "${TMPDIR:-/tmp}/mcp-catalog-XXXXXX")
        CLEANUP_PATHS+=("$MCP_CATALOG_TMP")
        # Phase 32-01 (CAT-01): catalog renamed
        # mcp-catalog.json → integrations-catalog.json. Old
        # name 404s on raw.githubusercontent.com (user report
        # 2026-05-02). The other block at line ~258 was
        # updated; this one was missed.
        if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/integrations-catalog.json" -o "$MCP_CATALOG_TMP"; then
            echo -e "${RED}✗${NC} Failed to download integrations-catalog.json — aborting" >&2
            exit 1
        fi
        export TK_MCP_CATALOG_PATH="$MCP_CATALOG_TMP"
    fi
    _save_main_tui_state
    if ! mcp_catalog_load >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Failed to load MCP catalog — aborting" >&2
        exit 1
    fi
                    # Phase 34-01: mcp_status_array now sets TUI_LABELS to
                    # display_name (with [!] prefix on unofficial entries) and
                    # TUI_GROUPS to title-cased categories. The sub-picker
                    # historically used raw MCP_NAMES for label-to-CSV exact
                    # match against TK_MCP_PRE_SELECTED. Preserve that contract
                    # by overwriting TUI_LABELS back to MCP_NAMES order, but
                    # KEEP the category groups + status-augmented descriptions
                    # produced by mcp_status_array — those are what the user
                    # sees and they don't affect the back-end CSV match.
                    mcp_status_array
                    # mcp_status_array iterates by category, so its TUI_*
                    # arrays are NOT in MCP_NAMES order. Rebuild them in
                    # category-grouped iteration order (alpha-within-category)
                    # using the parallel arrays already populated.
                    TUI_LABELS=()
                    TUI_GROUPS=()
                    TUI_DESCS=()
                    TUI_REQUIRED=()
                    for _cat_i in "${CATEGORIES_ORDER[@]+"${CATEGORIES_ORDER[@]}"}"; do
                        for ((_mcp_i=0; _mcp_i<${#MCP_NAMES[@]}; _mcp_i++)); do
                            if [[ "${MCP_CATEGORY[$_mcp_i]:-}" == "$_cat_i" ]]; then
                                TUI_LABELS+=("${MCP_NAMES[$_mcp_i]}")
                                TUI_GROUPS+=("$(_mcp_category_display "$_cat_i")")
                                # Reuse description-with-status block built by
                                # mcp_status_array — it's parallel to MCP_NAMES
                                # ordering inside each category, but easier to
                                # recompute here than to map indices across.
                                _mcp_desc="${MCP_DESCS[$_mcp_i]:-}"
                                # Append a status block mirroring mcp_status_array.
                                _mcp_status_word="${MCP_STATUS[$_mcp_i]:-unknown}"
                                _cli_status_word="${CLI_STATUS[$_mcp_i]:-na}"
                                case "$_mcp_status_word" in
                                    installed) _mcp_glyph="✓" ;;
                                    absent)    _mcp_glyph="✗" ;;
                                    *)         _mcp_glyph="⊘" ;;
                                esac
                                case "$_cli_status_word" in
                                    installed) _cli_glyph="✓" ;;
                                    absent)    _cli_glyph="✗" ;;
                                    *)         _cli_glyph="—" ;;
                                esac
                                # Mark unofficial inline so the [!] is visible
                                # in the sub-picker just like the main TUI.
                                if [[ "${MCP_UNOFFICIAL[$_mcp_i]:-0}" == "1" ]]; then
                                    _mcp_desc="[!] ${_mcp_desc}"
                                fi

                                # v6.16.0 (T-04) — append a scope hint so the
                                # user sees what scope the row will land in
                                # before the lock-screen. Glyph derives from:
                                #   - mcp_detect_installed_scope (T-02)
                                #     when the MCP is already registered →
                                #     "(installed: U/P/L)"
                                #   - MCP_DEFAULT_SCOPE[$_mcp_i] otherwise
                                #     → "(default: U/P/L)"
                                # IMPORTANT: only the description suffix is
                                # mutated. TUI_LABELS stays raw MCP_NAMES so
                                # the CSV-match below (line 1869–1872) keeps
                                # working — see comment at 1853–1861 in the
                                # pre-v6.16 code, preserved verbatim below.
                                _scope_detected=$(mcp_detect_installed_scope "${MCP_NAMES[$_mcp_i]}")
                                if [[ -n "$_scope_detected" ]]; then
                                    case "$_scope_detected" in
                                        user)    _scope_hint="(installed: U)" ;;
                                        project) _scope_hint="(installed: P)" ;;
                                        local)   _scope_hint="(installed: L)" ;;
                                        *)       _scope_hint="" ;;
                                    esac
                                else
                                    case "${MCP_DEFAULT_SCOPE[$_mcp_i]:-user}" in
                                        user)    _scope_hint="(default: U)" ;;
                                        project) _scope_hint="(default: P)" ;;
                                        local)   _scope_hint="(default: L)" ;;
                                        *)       _scope_hint="(default: U)" ;;
                                    esac
                                fi
                                TUI_DESCS+=("${_mcp_desc} [MCP:${_mcp_glyph} CLI:${_cli_glyph}] ${_scope_hint}")
                                TUI_REQUIRED+=(0)
                            fi
                        done
                    done
                    unset _mcp_i _cat_i _mcp_desc _mcp_status_word _cli_status_word _mcp_glyph _cli_glyph _scope_detected _scope_hint
                    # Restore prior MCP selection on Back-return (same pattern as skills).
                    TUI_RESULTS=()
                    if [[ -n "${TK_MCP_PRE_SELECTED:-}" ]]; then
                        _IFS_SAVED2="$IFS"
                        IFS=','
                        # shellcheck disable=SC2206
                        _prev_mcp=( ${TK_MCP_PRE_SELECTED} )
                        IFS="$_IFS_SAVED2"
                        for ((_mcp_i=0; _mcp_i<${#TUI_LABELS[@]}; _mcp_i++)); do
                            TUI_RESULTS[$_mcp_i]=0
                            for _p in "${_prev_mcp[@]+"${_prev_mcp[@]}"}"; do
                                if [[ "${TUI_LABELS[$_mcp_i]}" == "$_p" ]]; then
                                    TUI_RESULTS[$_mcp_i]=1
                                    break
                                fi
                            done
                        done
                        unset _mcp_i _p _prev_mcp _IFS_SAVED2
                    fi
    # v6.16.0 — sub-picker is a pre-collection screen whose ONLY contract is
    # "produce TK_MCP_PRE_SELECTED CSV of raw MCP_NAMES" for the main MCP TUI
    # (or the v6.16 lock-screen) to re-match. Wiring mcp_toggle_scope HERE
    # would corrupt every TUI_LABELS[] slot with a scope-glyph prefix
    # ("[U] context7"); the CSV builder below reads TUI_LABELS as raw names,
    # so exact-match would break. Per-row scope choice happens in the
    # lock-screen rendered by _run_mcp_scope_lock_screen (T-05).
    _rc=0
    tui_checklist || _rc=$?
    unset TUI_HEADER_TEXT
    case "$_rc" in
        0)
            _mcp_pre_csv=""
            for ((_mcp_i=0; _mcp_i<${#TUI_LABELS[@]}; _mcp_i++)); do
                if [[ "${TUI_RESULTS[$_mcp_i]:-0}" -eq 1 ]]; then
                    _mcp_pre_csv="${_mcp_pre_csv}${_mcp_pre_csv:+,}${TUI_LABELS[$_mcp_i]}"
                fi
            done
            unset _mcp_i
            export TK_MCP_PRE_SELECTED="$_mcp_pre_csv"
            unset _mcp_pre_csv
            _restore_main_tui_state
            ;;
        *)
            echo "MCP selection cancelled — aborting install."
            exit 0
            ;;
    esac

    unset _rc
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
# Child-state directory (user feedback 2026-05-06: "want to see which MCP
# servers actually got installed, not just the parent rolled-up row").
# Sub-installers (--mcps / --skills) write TAB-separated `name<TAB>status`
# lines to ${TK_CHILD_STATE_DIR}/${component}.tsv. Parent summary loop reads
# the file and renders an indented breakdown under the parent row.
TK_CHILD_STATE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tk-children.XXXXXX") || TK_CHILD_STATE_DIR=""
# CLEANUP_PATHS uses `rm -f` (file only); register dir cleanup separately.
if [[ -n "$TK_CHILD_STATE_DIR" ]]; then
    trap '[[ -d "$TK_CHILD_STATE_DIR" ]] && rm -rf "$TK_CHILD_STATE_DIR"; run_cleanup' EXIT
fi
export TK_CHILD_STATE_DIR

# Append catalog labels (skills, mcp-servers) to parallel arrays in interactive
# mode only — they are NOT shown in the main TUI, but the dispatch loop must
# still process them when sub-pickers populated TK_*_PRE_SELECTED. In --yes /
# headless mode (TK_TUI_CONFIRMED unset) we skip the append, preserving the
# prior CI-safe behavior of NOT installing catalog items unattended.
if [[ "${TK_TUI_CONFIRMED:-0}" == "1" ]]; then
    TUI_LABELS+=("skills")
    TUI_GROUPS+=("Catalogs")
    TUI_INSTALLED+=("0")
    TUI_REQUIRED+=("0")
    TUI_DESCS+=("(skills sub-picker)")
    TUI_RESULTS+=("1")
    TUI_REINSTALLABLE+=("0")

    TUI_LABELS+=("mcp-servers")
    TUI_GROUPS+=("Catalogs")
    TUI_INSTALLED+=("0")
    TUI_REQUIRED+=("0")
    TUI_DESCS+=("(mcp-servers sub-picker)")
    TUI_RESULTS+=("1")
    TUI_REINSTALLABLE+=("0")
fi

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
        # claude-memo → claude_memo (Bash function names cannot contain
        # hyphens). dispatch_claude_memo lives in scripts/lib/dispatch.sh.
        claude-memo)   echo "claude_memo" ;;
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
        claude_memo) local_memo_vault="${MEMO_VAULT_PATH:-$HOME/memo-vault}"
                     local_memo_skill=0
                     for local_f in "$HOME/.claude/skills"/*/scripts/memo_engine.py; do
                         [[ -f "$local_f" ]] && { local_memo_skill=1; break; }
                     done
                     [[ $local_memo_skill -eq 1 && -f "$local_memo_vault/INDEX.md" ]] && local_re_installed=1 || true
                     unset local_memo_vault local_memo_skill local_f ;;
        gemini-bridge) _bridge_target_installed "$(_bridge_global_dir gemini)/GEMINI.md" && local_re_installed=1 || true ;;
        codex-bridge)  _bridge_target_installed "$(_bridge_global_dir codex)/AGENTS.md"  && local_re_installed=1 || true ;;
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
    # User feedback 2026-05-06: expand the rolled-up `mcp-servers` and `skills`
    # parent rows with their per-item breakdown (sub-installer wrote a TSV file
    # under TK_CHILD_STATE_DIR — see the bubble-up blocks in --mcps / --skills).
    case "$local_name" in
        mcp-servers|skills)
            _child_tsv="${TK_CHILD_STATE_DIR:-}/${local_name}.tsv"
            if [[ -n "${TK_CHILD_STATE_DIR:-}" && -f "$_child_tsv" ]]; then
                while IFS=$'\t' read -r _child_name _child_state; do
                    [[ -z "$_child_name" ]] && continue
                    case "$_child_state" in
                        "installed ✓"|installed|"reinstalled ↻")
                            printf '  %b└ %-26s %b%s%b\n' "${GREEN:-}" "$_child_name" "${GREEN:-}" "$_child_state" "${NC:-}"
                            ;;
                        failed*)
                            printf '  %b└ %-26s %b%s%b\n' "${RED:-}" "$_child_name" "${RED:-}" "$_child_state" "${NC:-}"
                            ;;
                        skipped*)
                            printf '  %b└ %-26s %s%b\n' "${YELLOW:-}" "$_child_name" "$_child_state" "${NC:-}"
                            ;;
                        *)
                            printf '  └ %-26s %s\n' "$_child_name" "$_child_state"
                            ;;
                    esac
                done < "$_child_tsv"
            fi
            unset _child_tsv _child_name _child_state
            ;;
    esac
done
echo ""
# Top-level counters track parent rows only (mcp-servers, skills are 1-each
# regardless of how many children failed). User report 2026-05-07: a parent
# `mcp-servers failed (exit 1)` row hid 4 real MCP failures + 9 unselected
# rows behind a single "Failed: 1 · Skipped: 1" line. Tally child TSVs and
# annotate the line with `(+ N children)` so the headline matches the visible
# breakdown above.
_child_inst=0; _child_skip=0; _child_fail=0
for _child_tsv_path in "${TK_CHILD_STATE_DIR:-/dev/null}"/mcp-servers.tsv "${TK_CHILD_STATE_DIR:-/dev/null}"/skills.tsv; do
    [[ -f "$_child_tsv_path" ]] || continue
    while IFS=$'\t' read -r _cn _cs; do
        [[ -z "$_cn" ]] && continue
        case "$_cs" in
            "installed ✓"|installed|"reinstalled ↻"|"installed (needs API key)") _child_inst=$((_child_inst + 1)) ;;
            failed*) _child_fail=$((_child_fail + 1)) ;;
            skipped*) _child_skip=$((_child_skip + 1)) ;;
        esac
    done < "$_child_tsv_path"
done
unset _child_tsv_path _cn _cs
_child_total=$((_child_inst + _child_skip + _child_fail))
if [[ $_child_total -gt 0 ]]; then
    printf 'Installed: %d (+ %d children) · Skipped: %d (+ %d children) · Failed: %d (+ %d children)\n' \
        "$INSTALLED_COUNT" "$_child_inst" "$SKIPPED_COUNT" "$_child_skip" "$FAILED_COUNT" "$_child_fail"
else
    printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
        "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
fi
unset _child_inst _child_skip _child_fail _child_total

# Post-install setup guide — generates a per-machine HTML page with
# config instructions for everything that was actually installed (MCPs
# need API keys, claude-memo needs Obsidian vault path, RTK needs hook
# wiring, etc.). User feedback 2026-05-06: "После установки всех этих
# MCP, скиллов их же еще нужно настраивать. Было бы круто открывать
# локальную HTML-страницу с инструкциями по установке каждой из этих
# зависимостей." Generated only when at least one component succeeded
# AND the templates payload is on disk (manifest copied them as part of
# this same install). Honours TK_NO_OPEN=1 to skip the auto-`open`.
if [[ ${INSTALLED_COUNT:-0} -gt 0 && "${NO_BANNER:-0}" != "1" ]]; then
    _guide_lib=".claude/scripts/lib/post-install-guide.sh"
    _guide_templates=".claude/templates/post-install"
    if [[ -f "$_guide_lib" && -d "$_guide_templates" ]]; then
        # Component label list — only entries that ended in a "present"
        # state. Skip rolled-up parents (mcp-servers, skills) and base
        # plugins (superpowers, get-shit-done) — those don't have post-
        # install setup pages.
        _guide_installed=""
        for ((_gi=0; _gi<${#COMPONENT_NAMES[@]}; _gi++)); do
            _gn="${COMPONENT_NAMES[$_gi]:-}"
            _gs="${COMPONENT_STATUS[$_gi]:-}"
            [[ -z "$_gn" ]] && continue
            case "$_gs" in
                installed*|reinstalled*|"already installed"*)
                    case "$_gn" in
                        mcp-servers|skills|superpowers|get-shit-done) ;;
                        *) _guide_installed+="$_gn " ;;
                    esac
                    ;;
            esac
        done

        # MCP names from the child TSV the --mcps sub-installer wrote.
        _guide_mcps=""
        _mcp_tsv="${TK_CHILD_STATE_DIR:-}/mcp-servers.tsv"
        if [[ -n "${TK_CHILD_STATE_DIR:-}" && -f "$_mcp_tsv" ]]; then
            while IFS=$'\t' read -r _mname _mstate; do
                [[ -z "$_mname" ]] && continue
                case "$_mstate" in
                    installed*|reinstalled*) _guide_mcps+="$_mname " ;;
                esac
            done < "$_mcp_tsv"
        fi

        _guide_ver="${TK_TOOLKIT_VERSION:-}"
        if [[ -z "$_guide_ver" || "$_guide_ver" == "unknown" ]] && [[ -f ".claude/.toolkit-version" ]]; then
            _guide_ver="$(head -n1 .claude/.toolkit-version 2>/dev/null || echo)"
        fi
        if [[ -z "$_guide_ver" || "$_guide_ver" == "unknown" ]] && [[ -f "$HOME/.claude/.toolkit-version" ]]; then
            _guide_ver="$(head -n1 "$HOME/.claude/.toolkit-version" 2>/dev/null || echo)"
        fi
        if [[ -z "$_guide_ver" || "$_guide_ver" == "unknown" ]] && [[ -f "manifest.json" ]] && command -v jq >/dev/null 2>&1; then
            _guide_ver="$(jq -r '.version // "unknown"' manifest.json 2>/dev/null)"
        fi
        : "${_guide_ver:=unknown}"

        _guide_project_name="$(basename "$PWD" 2>/dev/null || echo project)"

        # shellcheck disable=SC1090
        if TK_GUIDE_TEMPLATES="$_guide_templates" \
           TK_GUIDE_INSTALLED="$_guide_installed" \
           TK_GUIDE_MCPS="$_guide_mcps" \
           TK_GUIDE_OUTPUT=".claude/setup-guide.html" \
           TK_GUIDE_TOOLKIT_VER="$_guide_ver" \
           TK_GUIDE_PROJECT_NAME="$_guide_project_name" \
           TK_GUIDE_PROJECT_ROOT="$PWD" \
               bash -c 'source "'"$_guide_lib"'" && post_install_guide_generate' \
               >/dev/null 2>&1; then
            echo ""
            echo -e "${CYAN}📘 Setup guide:${NC} .claude/setup-guide.html"
            echo "   Per-MCP API-key + per-component config walkthroughs."
            if [[ "$(uname)" == "Darwin" && "${TK_NO_OPEN:-0}" != "1" ]]; then
                # Auto-open in default browser on macOS only — xdg-open
                # on headless Linux often hangs / spawns chrome under root.
                (open ".claude/setup-guide.html" >/dev/null 2>&1 &) || true
            fi
        fi
        unset _guide_lib _guide_templates _guide_installed _guide_mcps _mcp_tsv _mname _mstate _guide_ver _guide_project_name
    fi
fi

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
    echo "To uninstall: bash <(curl -sSL $TK_REPO_URL/scripts/uninstall.sh)"
    if [[ -f ".claude/POST_INSTALL.md" ]]; then
        echo ""
        echo -e "${CYAN}📖 Next steps:${NC} .claude/POST_INSTALL.md"
        echo "   Recommended follow-ups (security setup, statusline, advisory hooks)."
    fi
fi

# Exit code (D-29): 0 if no failures, 1 if any failure.
if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
