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

# Config
TK_REPO_URL="${TK_REPO_URL:-https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main}"
NO_BANNER=${NO_BANNER:-0}

# Flags (defaults)
YES=0
DRY_RUN=0
FORCE=0
FAIL_FAST=0
MCPS=0
SKILLS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)       YES=1;       shift ;;
        --no-color)  NO_COLOR=1;  export NO_COLOR; shift ;;
        --dry-run)   DRY_RUN=1;   shift ;;
        --force)     FORCE=1;     shift ;;
        --fail-fast) FAIL_FAST=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
        --mcps)      MCPS=1;      shift ;;
        --skills)    SKILLS=1;    shift ;;
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
  --mcps        Install curated MCP servers via TUI catalog (Phase 25)
  --skills      Install curated skills via TUI catalog (Phase 26)

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

_source_lib() {
    local lib_name="$1"
    if _is_curl_pipe; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/${lib_name}-XXXXXX")
        CLEANUP_PATHS+=("$tmp")
        if ! curl -sSLf "$TK_REPO_URL/scripts/lib/${lib_name}.sh" -o "$tmp"; then
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
    if ! curl -sSLf "$TK_REPO_URL/scripts/detect.sh" -o "$DETECT_TMP"; then
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

# MCPS=1 path needs the MCP catalog + wizard library.
if [[ "$MCPS" -eq 1 ]]; then
    _source_lib mcp
fi

# SKILLS=1 path needs the skills catalog + cp-R installer.
if [[ "$SKILLS" -eq 1 ]]; then
    _source_lib skills
fi

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
        installed*)     printf '  %b%-30s %s%b\n' "${_DRO_G:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        would-install)  printf '  %b%-30s %s%b\n' "${_DRO_C:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        skipped)        printf '  %b%-30s %s%b\n' "${_DRO_Y:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        failed*)        printf '  %b%-30s %s%b\n' "${_DRO_R:-}"    "$component" "$state" "${_DRO_NC:-}" ;;
        *)              printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}

# ─────────────────────────────────────────────────
# Routing gate: --mcps takes the MCP page; --skills takes the Skills page; default is
# the Phase 24 components page. Mutex — exactly one of three branches per invocation.
# ─────────────────────────────────────────────────

# --mcps and --skills are mutually exclusive: exactly one of three branches runs per invocation.
if [[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 ]]; then
    echo -e "${RED}✗${NC} --mcps and --skills are mutually exclusive" >&2
    exit 1
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

    # Selection: --yes default-set OR TUI page.
    TUI_RESULTS=()
    if [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; skip OAuth-only unless --force
        # (OAuth needs interactive browser flow — incompatible with --yes).
        local_count=${#MCP_NAMES[@]}
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
        # Count selected.
        local_selected=0
        for ((i=0; i<${#TUI_RESULTS[@]}; i++)); do
            [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
        done
        if ! tui_confirm_prompt "Install ${local_selected} MCP(s)? [y/N] "; then
            echo "MCP install cancelled."
            exit 0
        fi
    fi

    # ─────────────────────────────────────────────
    # MCP dispatch loop (mirrors Phase 24 D-08 continue-on-error pattern).
    # ─────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}Installing selected MCP(s)...${NC}"
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
        stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-mcp-${local_name}-XXXXXX") || stderr_tmp=""
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
    echo -e "${BLUE}MCP install summary:${NC}"
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
# (End of MCP routing branch — components page continues below unchanged.)
# ─────────────────────────────────────────────────

# ─────────────────────────────────────────────────
# Component metadata — labels, groups, descriptions.
# Index order matches TK_DISPATCH_ORDER from dispatch.sh.
# ─────────────────────────────────────────────────
# shellcheck disable=SC2034  # TUI_* arrays consumed by tui_checklist in tui.sh (D-01)
TUI_LABELS=("superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline")
# shellcheck disable=SC2034  # TUI_GROUPS consumed by tui_checklist in tui.sh (D-01)
TUI_GROUPS=("Bootstrap"   "Bootstrap"      "Core"    "Optional" "Optional" "Optional")
TUI_INSTALLED=("$IS_SP" "$IS_GSD" "$IS_TK" "$IS_SEC" "$IS_RTK" "$IS_SL")
# shellcheck disable=SC2034  # TUI_DESCS consumed by tui_checklist in tui.sh (D-20)
TUI_DESCS=(
    "Skills + code-reviewer agent (claude plugin)"
    "Phase-based workflow (curl install)"
    "Claude Code Toolkit core (init-claude.sh)"
    "Global security rules + cc-safety-net hook"
    "60-90% token savings on dev commands"
    "macOS rate-limit statusline (Keychain)"
)
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
    for i in 0 1 2 3 4 5; do
        if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
            TUI_RESULTS[$i]=0
        else
            TUI_RESULTS[$i]=1
        fi
    done
elif [[ -r "$_install_tty_src" ]]; then
    # TUI mode — render checklist + confirmation.
    if ! tui_checklist; then
        # User cancelled (q/Ctrl-C/EOF). Fail-closed exit 0 per D-11.
        echo "Install cancelled."
        exit 0
    fi
    # shellcheck disable=SC2034  # SELECTION_RC reserved for future use
    SELECTION_RC=$?
    # Count selected.
    local_selected=0
    for i in 0 1 2 3 4 5; do
        [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
    done
    # Confirmation prompt (TUI-05). Default N.
    if ! tui_confirm_prompt "Install ${local_selected} component(s)? [y/N] "; then
        echo "Install cancelled."
        exit 0
    fi
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
                if curl -sSLf "$TK_REPO_URL/scripts/lib/bootstrap.sh" -o "$_bootstrap_tmp" 2>/dev/null; then
                    # Source SP/GSD canonical install commands first so
                    # bootstrap_base_plugins picks them up (TK_SP_INSTALL_CMD /
                    # TK_GSD_INSTALL_CMD from optional-plugins.sh).
                    _opt_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-opt-XXXXXX") || _opt_tmp=""
                    if [[ -n "$_opt_tmp" ]]; then
                        CLEANUP_PATHS+=("$_opt_tmp")
                        if curl -sSLf "$TK_REPO_URL/scripts/lib/optional-plugins.sh" -o "$_opt_tmp" 2>/dev/null; then
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
    for i in 0 1 2 3 4 5; do
        TUI_RESULTS[$i]=0
    done
fi

# ─────────────────────────────────────────────────
# Dispatch loop (D-08 continue-on-error, D-09 --fail-fast opt-in).
# Per-component status accumulated in parallel arrays.
# ─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}Installing selected components...${NC}"
echo ""

INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
COMPONENT_STATUS=()
COMPONENT_NAMES=()
# D-28 — per-component stderr tail buffer; populated only when dispatcher fails.
# Tmpfile paths are added to CLEANUP_PATHS so the EXIT trap removes them.
COMPONENT_STDERR_TAIL=()

for i in 0 1 2 3 4 5; do
    local_name="${TK_DISPATCH_ORDER[$i]}"
    local_label="${TUI_LABELS[$i]}"
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
    stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-install-${local_name}-XXXXXX") || stderr_tmp=""
    [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

    # Dispatch with continue-on-error (D-08). Capture exit code AND stderr.
    # Use a subshell + 2>"$stderr_tmp" redirection (Bash 3.2 compatible —
    # avoids process substitution which is not portable across all callers).
    local_rc=0
    if [[ -n "$stderr_tmp" ]]; then
        ( "dispatch_${local_name}" "${local_flags[@]}" ) 2>"$stderr_tmp" || local_rc=$?
    else
        # mktemp failed (rare); fall back to no-capture path.
        "dispatch_${local_name}" "${local_flags[@]}" || local_rc=$?
    fi

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
            for (( j=i+1; j<=5; j++ )); do
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
echo -e "${BLUE}Install summary:${NC}"
echo ""
for i in 0 1 2 3 4 5; do
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

# Closing banner (NO_BANNER honored — D-31).
if [[ "${NO_BANNER:-0}" != "1" ]]; then
    echo ""
    echo "To remove: bash <(curl -sSL $TK_REPO_URL/scripts/uninstall.sh)"
fi

# Exit code (D-29): 0 if no failures, 1 if any failure.
if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
