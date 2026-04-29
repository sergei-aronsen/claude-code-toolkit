---
phase: 24
plan: 04
type: execute
wave: 3
depends_on:
  - 24-01
  - 24-02
  - 24-03
files_modified:
  - scripts/install.sh
  - scripts/tests/test-install-tui.sh
  - Makefile
  - .github/workflows/quality.yml
autonomous: true
requirements:
  - TUI-07
  - DISPATCH-03
  - BACKCOMPAT-01
requirements_addressed:
  - TUI-07
  - DISPATCH-03
  - BACKCOMPAT-01
tags: bash,orchestrator,test,phase-24

must_haves:
  truths:
    - "scripts/install.sh is a NEW top-level orchestrator (NOT scripts/lib/install.sh which already exists as v4.4 Install Flow Library)"
    - "install.sh sources lib/{tui,detect2,dispatch}.sh from local clone OR via curl when run via curl|bash"
    - "Default flow: detect → render TUI → tui_confirm_prompt → dispatch in TK_DISPATCH_ORDER → dro_print_install_status summary"
    - "--yes flag bypasses TUI; synthesizes default-set (all uninstalled in canonical order); skips installed unless --force; runs non-interactively"
    - "--dry-run zero-mutation: every dispatcher prints would-run command but invokes nothing; exit 0"
    - "--force re-runs detected components"
    - "--fail-fast stops on first failure; default is continue-on-error"
    - "Per-component summary uses dro_print_install_status with states: 'installed ✓' | 'skipped' | 'failed (exit N)'"
    - "Exit code 0 if no failures, 1 if any failure (or --fail-fast triggered)"
    - "test-install-tui.sh contains ≥15 distinct assert_* invocations covering all flag modes + keystroke paths + no-TTY fallback"
    - "Makefile gains Test 31 (test-install-tui), .PHONY updated, target invokable standalone"
    - ".github/workflows/quality.yml adds test-install-tui.sh to the Tests 21-30 step (renamed Tests 21-31)"
    - "init-claude.sh URL stays byte-identical; bash scripts/tests/test-bootstrap.sh stays green (BACKCOMPAT-01)"
  artifacts:
    - path: "scripts/install.sh"
      provides: "Unified TUI install orchestrator (top-level, not lib)"
      contains: "tui_checklist tui_confirm_prompt dispatch_ TK_DISPATCH_ORDER dro_print_install_status"
      min_lines: 200
    - path: "scripts/tests/test-install-tui.sh"
      provides: "Hermetic ≥15 assertion test for TUI-07"
      contains: "assert_eq assert_contains run_s.*"
    - path: "Makefile"
      provides: "Test 31 target; .PHONY updated"
      contains: "test-install-tui"
    - path: ".github/workflows/quality.yml"
      provides: "CI step running test-install-tui.sh"
      contains: "test-install-tui.sh"
  key_links:
    - from: "scripts/install.sh"
      to: "scripts/lib/{tui,detect2,dispatch}.sh"
      via: "source SCRIPT_DIR/lib/<name>.sh OR curl when running curl|bash"
      pattern: "source.*lib/(tui|detect2|dispatch)"
    - from: "scripts/install.sh orchestration loop"
      to: "TK_DISPATCH_ORDER iteration"
      via: "for name in TK_DISPATCH_ORDER; dispatch_$name"
      pattern: "for.*TK_DISPATCH_ORDER"
    - from: "scripts/install.sh post-install summary"
      to: "dro_print_install_status helper"
      via: "writes per-component status using dro_*"
      pattern: "dro_print_install_status"
    - from: "scripts/tests/test-install-tui.sh keystroke fixture"
      to: "tui_checklist via TK_TUI_TTY_SRC"
      via: "printf raw bytes \\e[A \\e[B space \\n into fixture file"
      pattern: "TK_TUI_TTY_SRC"
---

<objective>
Build the top-level `scripts/install.sh` orchestrator (DISPATCH-03) and extend `scripts/tests/test-install-tui.sh` to ≥15 assertions (TUI-07).

The orchestrator:
1. Sources `lib/{tui,detect2,dispatch}.sh` (local from `scripts/lib/` OR via curl when running under `bash <(curl ...)`)
2. Adds a `dro_print_install_status` helper to the existing `dro_*` summary API (D-27)
3. Parses flags: `--yes`, `--no-color`, `--dry-run`, `--force`, `--fail-fast`, `--no-banner`
4. Invokes detection cache (`detect2_cache`)
5. Either: renders TUI checklist → confirmation prompt (`tui_checklist` + `tui_confirm_prompt`); OR: synthesizes default-set when `--yes` or no TTY available
6. Iterates `TK_DISPATCH_ORDER`; for each user-selected component: dispatches via `dispatch_<name>` with appropriate flags
7. Tracks per-component status (installed ✓ / skipped / failed); applies `--fail-fast` if set
8. Prints summary using `dro_print_install_status` rows + total line
9. Exits 0 on no failures, 1 on any failure

The test extension grows the assertion count from 10 (after Plan 01 seeded S1_detect + S2_detect) to ≥15 by adding scenarios: `--yes` non-interactive default-set with mock dispatchers, `--dry-run` zero-mutation contract, `--force` re-runs, `--fail-fast` stops on first failure, and no-TTY fallback exit.

CRITICAL BACKCOMPAT-01 INVARIANT: `scripts/init-claude.sh` is NOT modified. The 26-assertion `test-bootstrap.sh` stays green throughout this phase.

CRITICAL FILE NAMING: `scripts/install.sh` is a NEW TOP-LEVEL FILE. Do NOT modify `scripts/lib/install.sh` which already exists (v4.4 Install Flow Library — mode/merge helpers).

Output: 4 files written (install.sh new top-level, test-install-tui.sh extended, Makefile +Test 31, quality.yml +Test 31 step). Plan 05 wires manifest.json + docs/INSTALL.md (parallel within Wave 3, different files — no conflict).
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
@.planning/phases/24-unified-tui-installer-centralized-detection/24-VALIDATION.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-01-SUMMARY.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-02-SUMMARY.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-03-SUMMARY.md
@scripts/lib/tui.sh
@scripts/lib/detect2.sh
@scripts/lib/dispatch.sh
@scripts/lib/dry-run-output.sh
@scripts/init-claude.sh
@scripts/tests/test-bootstrap.sh
@scripts/tests/test-install-tui.sh
@Makefile
@.github/workflows/quality.yml

<canonical_refs>
- 24-PATTERNS.md §"scripts/install.sh (new top-level orchestrator, executable)" (lines 297-381) — shebang, flag-parsing, CLEANUP_PATHS+trap, remote lib download, NO_BANNER gate
- 24-PATTERNS.md §"scripts/tests/test-install-tui.sh" (lines 384-516) — assertion helpers, mk_mock, sandbox, fixture format, mock dispatcher injection
- 24-PATTERNS.md §"Makefile (modified)" (lines 599-631) — Test 31 pattern; .PHONY update
- 24-PATTERNS.md §"`.github/workflows/quality.yml`" (lines 634-661) — CI step pattern
- 24-PATTERNS.md §"`dro_*` post-install summary API" (lines 793-810) — `dro_print_install_status` helper signature
- 24-RESEARCH.md §6 "Dispatch Layer" (lines 502-589) — orchestrator flow design
- 24-RESEARCH.md §8 "Test Fixture Format" (lines 638-687) — TK_TUI_TTY_SRC raw-byte format with printf %b
- 24-RESEARCH.md §9 "Validation Architecture" (lines 690-744) — Nyquist signals, sampling rate
- 24-RESEARCH.md §10 Risks 1-9 — known limitations + mitigations
- 24-VALIDATION.md "Per-Task Verification Map" — DISPATCH-03 row test type "integration"
- scripts/init-claude.sh:88-133 — CLEANUP_PATHS + trap pattern + curl|source for libs
- scripts/lib/dry-run-output.sh:48-55 — column-width pattern for dro_print_install_status
- scripts/tests/test-bootstrap.sh — analog file for sandbox + fixture + assertion shape
</canonical_refs>

<interfaces>
From scripts/lib/tui.sh (Plan 02):
```
tui_checklist
  Reads:  TUI_LABELS[] TUI_GROUPS[] TUI_INSTALLED[] TUI_DESCS[]
  Writes: TUI_RESULTS[] (1=install / 0=skip)
  Return: 0 on enter, 1 on q/Ctrl-C/EOF cancel

tui_confirm_prompt <prompt_text>
  Return: 0 if y/Y typed; 1 otherwise (default N, EOF)
```

From scripts/lib/detect2.sh (Plan 01):
```
is_<name>_installed  — six probes returning 0/1
detect2_cache         — populates IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL
```

From scripts/lib/dispatch.sh (Plan 03):
```
TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)
dispatch_<name> [--force] [--dry-run] [--yes]   — six dispatchers
TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>=<path>     — test seam
```

From scripts/lib/dry-run-output.sh:
```
dro_init_colors       — populate _DRO_G/_DRO_C/_DRO_Y/_DRO_R/_DRO_NC
dro_print_header      — header row (existing API)
dro_print_total       — total row (existing API)
```

The new helper `dro_print_install_status` follows D-27 (lives inline in install.sh, not added to dro lib — keeps dro lib stable):

```bash
# install.sh adds inline (NOT to dry-run-output.sh):
print_install_status() {
    local component="$1" state="$2"
    case "$state" in
        installed*)  printf '  ${_DRO_G:-}%-30s %s${_DRO_NC:-}\n' "$component" "$state" ;;
        skipped)     printf '  ${_DRO_Y:-}%-30s %s${_DRO_NC:-}\n' "$component" "$state" ;;
        failed*)     printf '  ${_DRO_R:-}%-30s %s${_DRO_NC:-}\n' "$component" "$state" ;;
        *)           printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}
```

Component group/description mapping for the TUI (D-01..D-03):
| Index | Name | Group | Description |
|-------|------|-------|-------------|
| 0 | superpowers | Bootstrap | Skills + code-reviewer agent (claude plugin) |
| 1 | get-shit-done | Bootstrap | Phase-based workflow (curl install) |
| 2 | toolkit | Core | Claude Code Toolkit core (init-claude.sh) |
| 3 | security | Optional | Global security rules + cc-safety-net hook |
| 4 | rtk | Optional | 60-90% token savings on dev commands |
| 5 | statusline | Optional | macOS rate-limit statusline (Keychain) |

Component dispatch name mapping (TK_DISPATCH_ORDER name → dispatch function):
- superpowers → dispatch_superpowers
- gsd → dispatch_gsd  (NOT dispatch_get-shit-done — name uses underscore in function, hyphen in label)
- toolkit → dispatch_toolkit
- security → dispatch_security
- rtk → dispatch_rtk
- statusline → dispatch_statusline

Detection cache var mapping (per Plan 01):
- superpowers → IS_SP
- gsd → IS_GSD
- toolkit → IS_TK
- security → IS_SEC
- rtk → IS_RTK
- statusline → IS_SL
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create scripts/install.sh — top-level unified orchestrator (DISPATCH-03)</name>
  <files>scripts/install.sh</files>

  <read_first>
    - scripts/init-claude.sh (lines 1-150) — analog file: shebang, flag parsing, CLEANUP_PATHS, trap, REPO_URL, lib download pattern
    - scripts/lib/tui.sh (just created in Plan 02) — public API: tui_checklist, tui_confirm_prompt
    - scripts/lib/detect2.sh (just created in Plan 01) — public API: is_*_installed, detect2_cache, IS_* cache vars
    - scripts/lib/dispatch.sh (just created in Plan 03) — public API: TK_DISPATCH_ORDER, dispatch_*
    - scripts/lib/dry-run-output.sh — dro_init_colors helpers
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/install.sh" (lines 297-381) — full pattern set
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §6 (orchestrator flow)
    - 24-CONTEXT.md D-04..D-15 (TUI flow + --yes semantics), D-27..D-29 (summary), D-30..D-32 (BACKCOMPAT)
  </read_first>

  <behavior>
    - `bash scripts/install.sh --dry-run` (with TK_DISPATCH_OVERRIDE_* mocks set) prints one [+ INSTALL] line per uninstalled component, prints summary, exits 0
    - `bash scripts/install.sh --yes` with mock dispatchers: invokes each dispatcher in TK_DISPATCH_ORDER, prints `installed ✓` for each successful one, exits 0
    - `bash scripts/install.sh --yes --fail-fast` with first dispatcher failing: stops after first failure; remaining show 'skipped'; exits 1
    - `bash scripts/install.sh` without TTY (TK_TUI_TTY_SRC=/dev/null) and no `--yes`: prints fail-closed message and exits 0 (D-11)
    - `bash scripts/install.sh --yes --force`: re-runs all components regardless of detection
    - `bash scripts/install.sh --yes` (no --force) skips installed components (sets status 'skipped')
    - Final summary line: `Installed: N · Skipped: M · Failed: K`
  </behavior>

  <action>
Create `scripts/install.sh` (top-level — NOT lib/install.sh) with this structure. The file is ~280 lines. Keep flag names, ordering, status-string formats, and `print_install_status` exact:

```bash
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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)       YES=1;       shift ;;
        --no-color)  NO_COLOR=1;  export NO_COLOR; shift ;;
        --dry-run)   DRY_RUN=1;   shift ;;
        --force)     FORCE=1;     shift ;;
        --fail-fast) FAIL_FAST=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
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
    [[ ${#CLEANUP_PATHS[@]} -gt 0 ]] && rm -f "${CLEANUP_PATHS[@]}"
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

# Initialize colors for the dro_* family (used by summary).
dro_init_colors

# ─────────────────────────────────────────────────
# Detection cache (D-23)
# ─────────────────────────────────────────────────
detect2_cache

# ─────────────────────────────────────────────────
# Component metadata — labels, groups, descriptions.
# Index order matches TK_DISPATCH_ORDER from dispatch.sh.
# ─────────────────────────────────────────────────
TUI_LABELS=("superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline")
TUI_GROUPS=("Bootstrap"   "Bootstrap"      "Core"    "Optional" "Optional" "Optional")
TUI_INSTALLED=("$IS_SP" "$IS_GSD" "$IS_TK" "$IS_SEC" "$IS_RTK" "$IS_SL")
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
else
    # TUI mode — render checklist + confirmation.
    if ! tui_checklist; then
        # User cancelled (q/Ctrl-C/EOF). Fail-closed exit 0 per D-11.
        echo "Install cancelled."
        exit 0
    fi
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
fi

# ─────────────────────────────────────────────────
# Per-component status string (D-27).
# Uses dro_* color vars set by dro_init_colors above.
# ─────────────────────────────────────────────────
print_install_status() {
    local component="$1" state="$2"
    case "$state" in
        installed*)  printf '  %b%-30s %s%b\n' "${_DRO_G:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        skipped)     printf '  %b%-30s %s%b\n' "${_DRO_Y:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        failed*)     printf '  %b%-30s %s%b\n' "${_DRO_R:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        *)           printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}

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

for i in 0 1 2 3 4 5; do
    local_name="${TK_DISPATCH_ORDER[$i]}"
    local_label="${TUI_LABELS[$i]}"
    COMPONENT_NAMES+=("$local_label")

    if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
        # User did not select OR pre-installed (without --force).
        # Pre-installed shows 'installed ✓' state; user-skipped shows nothing
        # in summary (we still want to show ALL components in summary, so set
        # state to 'skipped' for unselected uninstalled, 'installed ✓' for
        # already-installed).
        if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
            COMPONENT_STATUS+=("installed ✓")
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            COMPONENT_STATUS+=("skipped")
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
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
        continue
    fi

    # Build per-dispatch flags.
    local_flags=()
    [[ "$FORCE" -eq 1 ]]   && local_flags+=("--force")
    [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")
    [[ "$YES" -eq 1 ]]     && local_flags+=("--yes")

    # Dispatch with continue-on-error (D-08). Capture exit code.
    local_rc=0
    "dispatch_$local_name" "${local_flags[@]}" || local_rc=$?

    if [[ $local_rc -eq 0 ]]; then
        COMPONENT_STATUS+=("installed ✓")
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    else
        COMPONENT_STATUS+=("failed (exit $local_rc)")
        FAILED_COUNT=$((FAILED_COUNT + 1))
        if [[ "$FAIL_FAST" -eq 1 ]]; then
            # Stop dispatching; remaining components stay 'skipped'.
            for j in $((i + 1)) 2 3 4 5; do
                if [[ $j -le 5 && $j -gt $i ]]; then
                    COMPONENT_NAMES+=("${TUI_LABELS[$j]}")
                    COMPONENT_STATUS+=("skipped")
                    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                fi
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
```

Critical rules:

1. **NEW TOP-LEVEL FILE**. Path: `scripts/install.sh`. Do NOT touch `scripts/lib/install.sh` (which is the v4.4 Install Flow Library — completely different).
2. **`set -euo pipefail`** at the top — this is a top-level executable, NOT a sourced lib.
3. **Lib sourcing**: when running via `curl | bash` or `bash <(curl ...)`, libs MUST be downloaded to mktemp first. When running locally, source from `scripts/lib/<name>.sh` directly. The `_is_curl_pipe` helper is identical to dispatch.sh's `_dispatch_is_curl_pipe`.
4. **detect2.sh dependency on detect.sh**: `detect2.sh` internally `source $(dirname BASH_SOURCE)/../detect.sh` — that relative path resolves correctly from `scripts/lib/` LOCALLY but NOT under curl|bash (BASH_SOURCE is /dev/fd/N). Workaround: install.sh sources detect.sh manually FIRST (before sourcing detect2.sh) when running curl|bash. The detect2.sh internal source-line then becomes redundant but harmless (detect.sh's || true guards make re-sourcing safe).
5. **`local_*` prefix for inline-loop locals**: bash 3.2 doesn't have `local` outside functions, so we use `local_<name>` plain variables to avoid collisions with already-set state. (The `for i in ...` loop runs in the global scope.)
6. **dispatch invocation via dynamic name**: `"dispatch_$local_name" "${local_flags[@]}"` is the canonical pattern; `local_name` is taken from `TK_DISPATCH_ORDER[i]` which is project-controlled (no user input). Safe per T-24-01.
7. **--fail-fast remaining-components-as-skipped**: when bailing out mid-loop, populate the remaining indices in COMPONENT_NAMES + COMPONENT_STATUS so the summary still shows all 6 rows.
8. **Exit code 0 if FAILED_COUNT=0, else 1** (D-29).
9. **Closing banner** mirrors `init-claude.sh` `NO_BANNER` honor pattern (D-31).
10. **No-TTY auto-fallback**: when `tui_checklist` returns 1 (which happens on EOF / no /dev/tty), the orchestrator prints "Install cancelled." and exits 0. The `--yes` flag is the explicit non-interactive entry — without it, no TTY = exit 0 fail-closed (D-11).
11. **`shellcheck -S warning`** must pass; ignore SC2034 for some color codes (project pattern; add `# shellcheck disable=SC2034` per-line if needed).

Implements DISPATCH-03 (top-level orchestrator). Honors all decisions D-01..D-32 except those covered by libs (D-21..D-26 for dispatch.sh, D-33..D-34 for tests).
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/install.sh && bash -n scripts/install.sh && bash scripts/install.sh --help | grep -q "Skip TUI" && echo install-sh-syntax-and-help-ok</automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/install.sh` exists at TOP-LEVEL `scripts/` (NOT `scripts/lib/`)
    - File starts with `#!/bin/bash` and contains `set -euo pipefail`
    - File contains all six flag handlers: `--yes`, `--no-color`, `--dry-run`, `--force`, `--fail-fast`, `--no-banner`
    - File contains `--help` flag with usage text mentioning all flags
    - File contains `_is_curl_pipe` helper AND `_source_lib` helper
    - File sources four libs: `dry-run-output`, `detect2`, `tui`, `dispatch`
    - File contains `detect2_cache` invocation
    - File contains `TUI_LABELS=` populated with the six component names in canonical order
    - File contains `tui_checklist` AND `tui_confirm_prompt` invocations (TUI mode branch)
    - File contains a `--yes` branch that synthesizes default-set when YES=1
    - File contains the dispatch loop iterating six indices with `dispatch_$local_name` invocation
    - File contains `print_install_status` helper using `_DRO_G/_DRO_Y/_DRO_R/_DRO_NC`
    - File contains the summary line format `'Installed: %d · Skipped: %d · Failed: %d\n'`
    - File contains `NO_BANNER` honor at the closing banner
    - `shellcheck -S warning scripts/install.sh` exits 0
    - `bash -n scripts/install.sh` exits 0 (syntax)
    - `bash scripts/install.sh --help` exits 0 with usage text
    - File does NOT modify scripts/init-claude.sh (BACKCOMPAT-01)
    - `git diff --name-only` after this task includes `scripts/install.sh` but NOT `scripts/init-claude.sh`
  </acceptance_criteria>

  <done>
    install.sh runs end-to-end against mock dispatchers (verified in Task 2). Real dispatcher invocation is gated by tests in Task 2 + manual smoke in Task 4.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Extend scripts/tests/test-install-tui.sh to ≥15 assertions (TUI-07 + DISPATCH-03)</name>
  <files>scripts/tests/test-install-tui.sh</files>

  <read_first>
    - scripts/tests/test-install-tui.sh (current state — has S1_detect + S2_detect from Plan 01, ~10 assertions)
    - scripts/tests/test-bootstrap.sh — analog: mock script invocation via TK_BOOTSTRAP_SP_CMD
    - scripts/install.sh (just created in Task 1)
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/tests/test-install-tui.sh" — fixture format, mock dispatcher injection
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §8 (test fixture format), §9 (Nyquist signals)
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-VALIDATION.md "Per-Task Verification Map"
  </read_first>

  <behavior>
    - Total assertion count is ≥15 (`grep -c "assert_eq\|assert_contains\|assert_not_contains" scripts/tests/test-install-tui.sh` ≥ 15)
    - Test exits 0 with `PASS=N FAIL=0` for some N ≥ 15
    - Scenarios cover: keystroke matrix S1_detect/S2_detect (already there), --yes non-interactive (S3_yes), --dry-run zero-mutation (S4_dry_run), --force re-runs detected (S5_force), --fail-fast stops on first failure (S6_fail_fast), no-TTY fallback (S7_no_tty)
    - Each scenario uses a fresh sandbox HOME + override env vars; no real ~/.claude touched
  </behavior>

  <action>
Edit `scripts/tests/test-install-tui.sh` to add five new scenarios after the existing `run_s1_detect` and `run_s2_detect` calls. Add the new scenario functions BEFORE the final invocation block, and add the calls to `run_s3_yes`, `run_s4_dry_run`, `run_s5_force`, `run_s6_fail_fast`, `run_s7_no_tty` after `run_s2_detect`.

Use Edit tool to find:

```bash
run_s1_detect
run_s2_detect

echo ""
echo "test-install-tui complete: PASS=$PASS FAIL=$FAIL"
```

Replace with all the new scenario functions + the invocation list. The new scenario functions go BEFORE the `run_s1_detect` invocation line. Best approach: locate the last `run_s2_detect()` closing brace, and append the new functions after it (before the `run_s1_detect` invocation line).

Insert these new scenario functions right before the `run_s1_detect` invocation:

```bash
# ─────────────────────────────────────────────────
# S3_yes — --yes bypasses TUI, dispatches all uninstalled in canonical order
# DISPATCH-03 + D-12 default-set
# ─────────────────────────────────────────────────
run_s3_yes() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_yes: --yes synthesizes default-set, mock dispatchers invoked --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # No installed components in clean sandbox.

    # Mock all six dispatchers.
    local MOCK_SP="$SANDBOX/mock-sp.sh"      ; mk_mock "$MOCK_SP"      "mock-sp-ran"      0
    local MOCK_GSD="$SANDBOX/mock-gsd.sh"    ; mk_mock "$MOCK_GSD"     "mock-gsd-ran"     0
    local MOCK_TK="$SANDBOX/mock-tk.sh"      ; mk_mock "$MOCK_TK"      "mock-tk-ran"      0
    local MOCK_SEC="$SANDBOX/mock-sec.sh"    ; mk_mock "$MOCK_SEC"     "mock-sec-ran"     0
    local MOCK_RTK="$SANDBOX/mock-rtk.sh"    ; mk_mock "$MOCK_RTK"     "mock-rtk-ran"     0
    local MOCK_SL="$SANDBOX/mock-sl.sh"      ; mk_mock "$MOCK_SL"      "mock-sl-ran"      0

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$MOCK_SP" \
        TK_DISPATCH_OVERRIDE_GSD="$MOCK_GSD" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        TK_DISPATCH_OVERRIDE_SECURITY="$MOCK_SEC" \
        TK_DISPATCH_OVERRIDE_RTK="$MOCK_RTK" \
        TK_DISPATCH_OVERRIDE_STATUSLINE="$MOCK_SL" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes 2>&1
    ) || RC=$?

    assert_eq      "0" "$RC"          "S3_yes: install.sh exits 0 with --yes"
    assert_contains "mock-tk-ran"     "$OUTPUT" "S3_yes: toolkit dispatcher invoked"
    assert_contains "mock-sec-ran"    "$OUTPUT" "S3_yes: security dispatcher invoked"
    assert_contains "Installed: 6"    "$OUTPUT" "S3_yes: summary shows 6 installed (DISPATCH-01 canonical order)"
}

# ─────────────────────────────────────────────────
# S4_dry_run — --dry-run zero-mutation contract (Nyquist signal 3)
# ─────────────────────────────────────────────────
run_s4_dry_run() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_dry_run: --yes --dry-run prints would-run, no dispatcher invoked --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # Mock dispatcher writes a sentinel file IF invoked.
    local SENTINEL="$SANDBOX/sentinel-toolkit"
    local MOCK_TK="$SANDBOX/mock-tk-sentinel.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$SENTINEL" > "$MOCK_TK"
    chmod +x "$MOCK_TK"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --dry-run 2>&1
    ) || RC=$?

    assert_eq       "0" "$RC"          "S4_dry_run: install.sh --yes --dry-run exits 0"
    assert_contains "INSTALL.*toolkit" "$OUTPUT" "S4_dry_run: prints [+ INSTALL] toolkit (would run)"
    if [[ -e "$SENTINEL" ]]; then
        assert_fail "S4_dry_run: dispatcher must NOT execute under --dry-run" \
            "sentinel file was created at $SENTINEL"
    else
        assert_pass "S4_dry_run: dispatcher NOT executed (zero-mutation contract)"
    fi
}

# ─────────────────────────────────────────────────
# S5_force — --force re-runs already-installed component
# D-14
# ─────────────────────────────────────────────────
run_s5_force() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_force: --yes --force re-runs already-installed toolkit --"

    # Pre-install toolkit (DET-05 condition).
    mkdir -p "$SANDBOX/.claude"
    echo '{"version":"4.4.0"}' > "$SANDBOX/.claude/toolkit-install.json"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    local MOCK_TK="$SANDBOX/mock-tk.sh"
    mk_mock "$MOCK_TK" "force-tk-ran" 0

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS=":" \
        TK_DISPATCH_OVERRIDE_GSD=":" \
        TK_DISPATCH_OVERRIDE_SECURITY=":" \
        TK_DISPATCH_OVERRIDE_RTK=":" \
        TK_DISPATCH_OVERRIDE_STATUSLINE=":" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --force 2>&1
    ) || RC=$?

    assert_eq       "0" "$RC"            "S5_force: install.sh --yes --force exits 0"
    assert_contains "force-tk-ran"        "$OUTPUT" "S5_force: toolkit dispatcher re-runs despite is_toolkit_installed=1"
}

# ─────────────────────────────────────────────────
# S6_fail_fast — --fail-fast stops on first failure
# D-09
# ─────────────────────────────────────────────────
run_s6_fail_fast() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_fail_fast: first dispatcher fails → orchestrator stops, exits 1 --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # SP dispatcher fails (exit 7); subsequent dispatchers should NOT run.
    local MOCK_SP_FAIL="$SANDBOX/mock-sp-fail.sh"
    mk_mock "$MOCK_SP_FAIL" "sp-failing" 7
    local MOCK_LATER_SENTINEL="$SANDBOX/sentinel-later"
    local MOCK_GSD_LATER="$SANDBOX/mock-gsd-later.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$MOCK_LATER_SENTINEL" > "$MOCK_GSD_LATER"
    chmod +x "$MOCK_GSD_LATER"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_DISPATCH_OVERRIDE_SUPERPOWERS="$MOCK_SP_FAIL" \
        TK_DISPATCH_OVERRIDE_GSD="$MOCK_GSD_LATER" \
        TK_DISPATCH_OVERRIDE_TOOLKIT=":" \
        TK_DISPATCH_OVERRIDE_SECURITY=":" \
        TK_DISPATCH_OVERRIDE_RTK=":" \
        TK_DISPATCH_OVERRIDE_STATUSLINE=":" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" --yes --fail-fast 2>&1
    ) || RC=$?

    assert_eq       "1" "$RC"          "S6_fail_fast: install.sh exits 1 on first failure"
    assert_contains "failed" "$OUTPUT" "S6_fail_fast: summary shows failed status"
    if [[ -e "$MOCK_LATER_SENTINEL" ]]; then
        assert_fail "S6_fail_fast: GSD dispatcher MUST NOT run after SP fails (D-09)" \
            "sentinel created at $MOCK_LATER_SENTINEL"
    else
        assert_pass "S6_fail_fast: GSD dispatcher did not run after SP failure (D-09)"
    fi
}

# ─────────────────────────────────────────────────
# S7_no_tty — no TTY + no --yes → fail-closed exit 0
# D-11
# ─────────────────────────────────────────────────
run_s7_no_tty() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S7_no_tty: TK_TUI_TTY_SRC=/dev/null + no --yes → fail-closed --"

    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"

    # Mock all dispatchers as a sentinel-write so we can prove they didn't run.
    local SENTINEL="$SANDBOX/no-tty-sentinel"
    local MOCK_TK="$SANDBOX/mock-tk-notty.sh"
    printf '#!/bin/bash\ntouch %q\nexit 0\n' "$SENTINEL" > "$MOCK_TK"
    chmod +x "$MOCK_TK"

    RC=0
    OUTPUT=$(
        HOME="$SANDBOX" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        TK_TUI_TTY_SRC=/dev/null \
        TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
        NO_COLOR=1 \
        bash "$REPO_ROOT/scripts/install.sh" 2>&1
    ) || RC=$?

    assert_eq       "0" "$RC" "S7_no_tty: install.sh exits 0 (fail-closed)"
    if [[ -e "$SENTINEL" ]]; then
        assert_fail "S7_no_tty: dispatcher MUST NOT run when no TTY and no --yes" \
            "sentinel created at $SENTINEL"
    else
        assert_pass "S7_no_tty: dispatcher did not run (D-11 fail-closed contract)"
    fi
}
```

Then update the invocation block at the bottom from:

```bash
run_s1_detect
run_s2_detect
```

To:

```bash
run_s1_detect
run_s2_detect
run_s3_yes
run_s4_dry_run
run_s5_force
run_s6_fail_fast
run_s7_no_tty
```

Critical rules:

1. Each scenario uses isolated `mktemp -d` sandbox; `trap "rm -rf '${SANDBOX:?}'" RETURN` per scenario.
2. **TK_DISPATCH_OVERRIDE_<NAME>=":"**: passing literal `":"` (the bash builtin no-op) silences dispatchers we don't care about in a given scenario. The dispatcher invokes `bash "$TK_DISPATCH_OVERRIDE_<NAME>"` which runs `bash :` → exit 0. This is cleaner than building 6 mock scripts per scenario.
3. **NO_COLOR=1** on every install.sh invocation so OUTPUT capture is plain-text grep-friendly.
4. Use `HOME="$SANDBOX"` to prevent any real `~/.claude` interference (detection probes hit the sandbox).
5. The sentinel-file approach (touch a file IFF dispatcher runs) is the canonical zero-mutation proof — verified against test-bootstrap.sh:265-271 for similar pattern.
6. Total new assertions added: 4 (S3_yes) + 3 (S4_dry_run) + 2 (S5_force) + 3 (S6_fail_fast) + 2 (S7_no_tty) = **14 new assertions**.
7. Combined with Plan 01's 10 (S1+S2): total = **24 assertions** ≥ 15 (TUI-07 contract).
  </action>

  <verify>
    <automated>bash scripts/tests/test-install-tui.sh && grep -c "assert_eq\|assert_contains\|assert_not_contains\|assert_pass\|assert_fail" scripts/tests/test-install-tui.sh | awk '{ if ($1 < 15) { print "TOO_FEW_ASSERTIONS:", $1; exit 1 } else { print "OK assertions=" $1 } }'</automated>
  </verify>

  <acceptance_criteria>
    - `scripts/tests/test-install-tui.sh` contains all seven scenario functions: `run_s1_detect`, `run_s2_detect`, `run_s3_yes`, `run_s4_dry_run`, `run_s5_force`, `run_s6_fail_fast`, `run_s7_no_tty`
    - All seven scenarios are invoked at the bottom of the file
    - `bash scripts/tests/test-install-tui.sh` exits 0
    - Final output line shows `PASS=N FAIL=0` with N ≥ 15 (likely 24+)
    - `grep -c "assert_eq\|assert_contains\|assert_pass\|assert_fail" scripts/tests/test-install-tui.sh` returns ≥ 15
    - File contains `TK_DISPATCH_OVERRIDE_TOOLKIT` (mock dispatcher injection — D-33)
    - File contains `TK_TUI_TTY_SRC=/dev/null` (no-TTY fallback test — D-11)
    - File contains a sentinel-file assertion (`SENTINEL` variable + `[[ -e "$SENTINEL" ]]` check) for zero-mutation proof
    - `shellcheck -S warning scripts/tests/test-install-tui.sh` exits 0
    - `bash scripts/tests/test-bootstrap.sh` exits 0 (BACKCOMPAT-01 invariant)
  </acceptance_criteria>

  <done>
    test-install-tui.sh has ≥15 assertions covering DISPATCH-03 + TUI-07 + flag matrix + no-TTY fallback. Hermetic test passes locally.
  </done>
</task>

<task type="auto">
  <name>Task 3: Wire test-install-tui.sh into Makefile (Test 31) + .github/workflows/quality.yml</name>
  <files>Makefile, .github/workflows/quality.yml</files>

  <read_first>
    - Makefile (lines 1, 148-161) — current .PHONY line + Test 30 block + standalone target
    - .github/workflows/quality.yml (lines 109-120) — current "Tests 21-30" CI step
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"Makefile (modified)" + §"`.github/workflows/quality.yml`" — exact addition patterns
  </read_first>

  <behavior>
    - `make test` runs all tests INCLUDING Test 31 (test-install-tui.sh) and exits 0
    - `make test-install-tui` exists as a standalone target and exits 0 when invoked
    - `.github/workflows/quality.yml` "Tests 21-30" step is renamed to "Tests 21-31" and includes `bash scripts/tests/test-install-tui.sh` in the run list
    - markdownlint and shellcheck still pass after Makefile / workflow modifications
  </behavior>

  <action>
**Makefile changes:**

1. Add `test-install-tui` to the `.PHONY` line at the top of Makefile.
2. Find the block ending at the current "All tests passed!" line:

```makefile
	@echo "Test 30: --keep-state partial-uninstall recovery (KEEP-01..02)"
	@bash scripts/tests/test-uninstall-keep-state.sh
	@echo ""
	@echo "All tests passed!"
```

Replace with:

```makefile
	@echo "Test 30: --keep-state partial-uninstall recovery (KEEP-01..02)"
	@bash scripts/tests/test-uninstall-keep-state.sh
	@echo ""
	@echo "Test 31: TUI install checklist + dispatch (TUI-01..07, DET-01..05, DISPATCH-01..03)"
	@bash scripts/tests/test-install-tui.sh
	@echo ""
	@echo "All tests passed!"
```

3. Find the "Test 30 — --keep-state partial-uninstall recovery" target block:

```makefile
# Test 30 — --keep-state partial-uninstall recovery (KEEP-01..02), invokable standalone
test-uninstall-keep-state:
	@bash scripts/tests/test-uninstall-keep-state.sh
```

After it (before the next `# Validate templates` block), add:

```makefile

# Test 31 — TUI install checklist + dispatch (TUI-01..07, DET-01..05, DISPATCH-01..03), invokable standalone
test-install-tui:
	@bash scripts/tests/test-install-tui.sh
```

4. Update the `.PHONY` line at the top of Makefile (line 1). Find:

```makefile
.PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install test-update-libs test-uninstall-keep-state
```

Append `test-install-tui` to the end (before the closing newline):

```makefile
.PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install test-update-libs test-uninstall-keep-state test-install-tui
```

**quality.yml changes:**

1. Find the existing "Tests 21-30" step (around lines 109-120):

```yaml
      - name: Tests 21-30 — uninstall + banner suite + bootstrap + lib coverage (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02, BANNER-01, KEEP-01..02)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
          bash scripts/tests/test-update-libs.sh
          bash scripts/tests/test-uninstall-keep-state.sh
```

Rename and extend:

```yaml
      - name: Tests 21-31 — uninstall + banner + bootstrap + lib + TUI install (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02, BANNER-01, KEEP-01..02, TUI-01..07, DET-01..05, DISPATCH-01..03)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
          bash scripts/tests/test-update-libs.sh
          bash scripts/tests/test-uninstall-keep-state.sh
          bash scripts/tests/test-install-tui.sh
```

After both edits:

1. Run `make test` — should now run all 31 tests and exit 0.
2. Run `make test-install-tui` standalone — should exit 0.
3. Run `markdownlint -c .markdownlint.json .github/workflows/quality.yml 2>/dev/null || true` — yaml is not markdown so this is a no-op.
4. Optionally run `shellcheck` on Makefile recipes (Makefile line targets are bash but not shell-check ed by default).
  </action>

  <verify>
    <automated>grep -q 'test-install-tui' Makefile && grep -q 'Test 31:' Makefile && grep -q 'test-install-tui.sh' .github/workflows/quality.yml && make test-install-tui && bash scripts/tests/test-install-tui.sh</automated>
  </verify>

  <acceptance_criteria>
    - Makefile `.PHONY` line includes `test-install-tui`
    - Makefile contains `Test 31: TUI install checklist` echo line in the test recipe
    - Makefile contains a standalone `test-install-tui:` target that runs the test
    - `.github/workflows/quality.yml` has the renamed "Tests 21-31" step
    - `.github/workflows/quality.yml` contains `bash scripts/tests/test-install-tui.sh` in the run-list
    - `make test-install-tui` exits 0
    - `bash scripts/tests/test-install-tui.sh` exits 0
    - `bash scripts/tests/test-bootstrap.sh` still exits 0 (BACKCOMPAT-01 invariant)
  </acceptance_criteria>

  <done>
    Test 31 wired into Makefile + CI. Local `make test-install-tui` and CI both run the new hermetic test.
  </done>
</task>

<task type="auto">
  <name>Task 4: Manual smoke + make check + commit Wave 3 orchestrator</name>
  <files>scripts/install.sh, scripts/tests/test-install-tui.sh, Makefile, .github/workflows/quality.yml</files>

  <read_first>
    - scripts/install.sh (just created in Task 1)
    - scripts/tests/test-install-tui.sh (just extended in Task 2)
    - Makefile + .github/workflows/quality.yml (just updated in Task 3)
  </read_first>

  <action>
1. Run shellcheck on all four files:

```bash
shellcheck -S warning scripts/install.sh scripts/tests/test-install-tui.sh
```

2. Run the full Phase 24 test suite locally:

```bash
make test-install-tui    # Test 31 standalone
bash scripts/tests/test-bootstrap.sh   # BACKCOMPAT-01 — must stay green
```

3. Run `make check` and confirm shellcheck + markdownlint + validate all pass:

```bash
make check
```

If any failures: stop and fix the offending file. Common candidates:
- shellcheck SC2034 (unused vars) → add `# shellcheck disable=SC2034` comment per line
- markdownlint MD040/MD031/MD032 → these affect .md files only; quality.yml change is yaml not md so should be safe
- Validate templates failures → these affect templates/ which Phase 24 doesn't touch

4. Manual smoke (optional but recommended): run `bash scripts/install.sh --help` and confirm usage prints; run `bash scripts/install.sh --dry-run --yes` against the local clone (no curl) and confirm it prints six [+ INSTALL] lines + summary + exits 0.

5. Commit all four files together as ONE atomic commit (Wave 3 orchestrator):

```bash
git add scripts/install.sh scripts/tests/test-install-tui.sh Makefile .github/workflows/quality.yml
git commit -m "$(cat <<'EOF'
feat(24): add scripts/install.sh unified orchestrator + Test 31 (TUI-07, DISPATCH-03)

DISPATCH-03: scripts/install.sh is a NEW top-level orchestrator (NOT
scripts/lib/install.sh which already exists as v4.4 Install Flow Lib).
Sources lib/{tui,detect2,dispatch}.sh from local clone OR via curl when
running under bash <(curl ...). Single entry point flow:

  1. Parse --yes, --no-color, --dry-run, --force, --fail-fast, --no-banner
  2. detect2_cache populates IS_SP / IS_GSD / IS_TK / IS_SEC / IS_RTK / IS_SL
  3. Either: tui_checklist (interactive) → tui_confirm_prompt;
     OR: --yes synthesizes default-set (all uninstalled in canonical order)
  4. Iterate TK_DISPATCH_ORDER; dispatch_$name with parsed flags
  5. Track per-component status (installed ✓ / skipped / failed)
  6. dro_print_install_status summary + total line + closing banner

D-08 default continue-on-error; D-09 --fail-fast opt-in stops on first
failure (remaining show 'skipped'). D-11 fail-closed exit 0 when no TTY
and no --yes. D-12 --yes default-set = all uninstalled. D-13 already-
installed skipped under --yes (unless --force). D-29 exit 0 on no
failures, 1 on any.

TUI-07: scripts/tests/test-install-tui.sh extended to ≥15 assertions
across seven scenarios: S1_detect (clean HOME / DET-01..05 negative),
S2_detect (populated HOME / positive probes), S3_yes (--yes invokes
all six dispatchers), S4_dry_run (zero-mutation contract via sentinel
file), S5_force (--force re-runs detected components), S6_fail_fast
(stops after first failure, remaining components NOT executed),
S7_no_tty (TK_TUI_TTY_SRC=/dev/null + no --yes → fail-closed exit 0).

Test wiring: Makefile gains Test 31 + standalone test-install-tui
target; .github/workflows/quality.yml step renamed Tests 21-31.

BACKCOMPAT-01 invariant preserved: scripts/init-claude.sh URL byte-
identical; test-bootstrap.sh 26 assertions stay green.

Refs: 24-CONTEXT.md D-04..D-15, D-27..D-32; 24-RESEARCH.md §6, §8, §9;
24-VALIDATION.md per-task verification map.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/install.sh scripts/tests/test-install-tui.sh && bash scripts/tests/test-install-tui.sh && bash scripts/tests/test-bootstrap.sh && git log -1 --pretty=%B | head -1 | grep -q '^feat(24): add scripts/install.sh unified orchestrator'</automated>
  </verify>

  <acceptance_criteria>
    - shellcheck passes on `scripts/install.sh` and `scripts/tests/test-install-tui.sh`
    - `bash scripts/tests/test-install-tui.sh` exits 0 with PASS ≥ 15 FAIL=0
    - `bash scripts/tests/test-bootstrap.sh` exits 0 with FAIL=0 (BACKCOMPAT-01 invariant)
    - `make check` exits 0
    - Most recent commit subject: `feat(24): add scripts/install.sh unified orchestrator + Test 31 (TUI-07, DISPATCH-03)`
    - Commit modifies exactly 4 files: `scripts/install.sh`, `scripts/tests/test-install-tui.sh`, `Makefile`, `.github/workflows/quality.yml`
    - `git diff HEAD~1 HEAD scripts/init-claude.sh | wc -l` returns 0 (init-claude.sh NOT modified by this commit — BACKCOMPAT-01)
  </acceptance_criteria>

  <done>
    Plan 04 lands as a single conventional commit. Wave 3 unified orchestrator + hermetic test in CI. Phase 24 ready for manifest.json + docs/INSTALL.md wiring (Plan 05).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user shell → install.sh | Untrusted env (HOME, PATH, NO_COLOR, TERM, TK_*); flag set parsed and validated against allowlist |
| install.sh → libs (tui/detect2/dispatch) | Project-controlled libs from same repo; downloaded via HTTPS or local clone |
| install.sh → dispatcher | Component name iterated from project-controlled TK_DISPATCH_ORDER; never from user input |
| install.sh → /dev/tty (TUI render) | Output to /dev/tty isolated from stdout; per-read redirection |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-01 | Tampering / Code injection | dispatch_$local_name dynamic invocation | mitigate | local_name read from TK_DISPATCH_ORDER (project-controlled hardcoded array). User cannot inject component names; the parsed flag set is also from a hardcoded allowlist |
| T-24-02 | Information disclosure | --dry-run output reveals TK_REPO_URL | accept | URL is public (raw.githubusercontent.com on a public repo); no secret exposure. Same as v4.4 init-claude.sh |
| T-24-03 | Tampering | bash <(curl -sSL .../install.sh) supply-chain risk | accept | Out of scope for Phase 24 (BACKCOMPAT-01 invariant — same risk as v4.4 init-claude.sh). HTTPS-only and curl -f fail-fast on bad fetch documented for completeness |
| T-24-04 | Denial of service | Stuck TUI raw mode after Ctrl-C mid-render | mitigate | tui.sh handles via _tui_restore EXIT trap (covered in Plan 02). install.sh inherits this through trap chain |
| T-24-11 | Tampering | TK_DISPATCH_OVERRIDE_* env vars allow arbitrary script execution | accept | Test-only seam. User already controls their env. Same risk class as v4.4 TK_BOOTSTRAP_SP_CMD |
| T-24-12 | Denial of service | Mock dispatcher writes outside per-test SANDBOX | mitigate | Hermetic test: every scenario creates its own mktemp sandbox + sets HOME=$SANDBOX. Mock scripts only touch files inside that sandbox. The sentinel-file pattern uses `$SANDBOX/sentinel-*` paths exclusively |
</threat_model>

<verification>
After Task 4 completes:

```bash
# Lib + script syntax + behavior
shellcheck -S warning scripts/install.sh scripts/tests/test-install-tui.sh
bash -n scripts/install.sh
bash scripts/install.sh --help

# Hermetic test ≥15 assertions
bash scripts/tests/test-install-tui.sh
grep -c "assert_eq\|assert_contains\|assert_pass\|assert_fail" scripts/tests/test-install-tui.sh

# Standalone Make target
make test-install-tui

# Full make test (Tests 21-31)
make test

# BACKCOMPAT-01 — 26 assertions stay green
bash scripts/tests/test-bootstrap.sh

# init-claude.sh untouched
git diff main HEAD scripts/init-claude.sh | wc -l   # should be 0

# make check (full quality gate)
make check
```
</verification>

<success_criteria>
- `scripts/install.sh` exists at TOP-LEVEL `scripts/` (NOT `scripts/lib/`); sources tui.sh, detect2.sh, dispatch.sh; orchestrates the full install flow
- All six flags supported: `--yes`, `--no-color`, `--dry-run`, `--force`, `--fail-fast`, `--no-banner`, plus `--help`
- TUI mode renders checklist + confirmation; `--yes` mode synthesizes default-set
- Continue-on-error by default (D-08); `--fail-fast` opt-in (D-09)
- Per-component status states: installed ✓ / skipped / failed (exit N) — D-10
- Final summary line: `Installed: N · Skipped: M · Failed: K`
- Exit code 0 on no failures, 1 on any failure (D-29)
- `scripts/tests/test-install-tui.sh` has ≥15 assertions across 7 scenarios
- Makefile Test 31 wired + standalone target invokable
- `.github/workflows/quality.yml` runs test-install-tui.sh in CI
- BACKCOMPAT-01 invariant: test-bootstrap.sh 26 assertions stay green; init-claude.sh URL byte-identical
- `make check` exits 0
- Single conventional commit `feat(24): add scripts/install.sh unified orchestrator + Test 31 (TUI-07, DISPATCH-03)`
</success_criteria>

<output>
After Plan 04 completes, create `.planning/phases/24-unified-tui-installer-centralized-detection/24-04-SUMMARY.md` describing:
- Files created: `scripts/install.sh`
- Files modified: `scripts/tests/test-install-tui.sh` (extended), `Makefile`, `.github/workflows/quality.yml`
- Public API: `scripts/install.sh` flag set + flow
- Test scenarios added: S3_yes, S4_dry_run, S5_force, S6_fail_fast, S7_no_tty (≥14 new assertions on top of Plan 01's 10)
- Total Phase 24 assertion count: ≥24
- BACKCOMPAT-01 verification: test-bootstrap.sh exit 0 with 26 assertions
- Decisions implemented: D-04..D-15, D-27..D-32
- Requirements addressed: TUI-07, DISPATCH-03, BACKCOMPAT-01
- Downstream contract: Plan 05 wires manifest.json + docs/INSTALL.md (parallel within Wave 3)
</output>
