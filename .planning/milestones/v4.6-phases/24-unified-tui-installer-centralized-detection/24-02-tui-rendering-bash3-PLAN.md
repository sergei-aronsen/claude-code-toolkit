---
phase: 24
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/tui.sh
autonomous: true
requirements:
  - TUI-01
  - TUI-02
  - TUI-03
  - TUI-04
  - TUI-05
  - TUI-06
requirements_addressed:
  - TUI-01
  - TUI-02
  - TUI-03
  - TUI-04
  - TUI-05
  - TUI-06
tags: bash,tui,terminal,phase-24

must_haves:
  truths:
    - "tui_checklist function reads keystrokes from < $TK_TUI_TTY_SRC (default /dev/tty) using read -rsn1 + read -rsn2 two-pass arrow detection (Bash 3.2 compat)"
    - "Pressing ↑/↓ moves focus, space toggles selection, enter confirms, q or Ctrl-C cancels"
    - "Already-installed items render as [installed ✓] (not togglable); uninstalled items pre-checked [x]"
    - "EXIT INT TERM trap restores stty BEFORE entering raw mode (TUI-03 ordering)"
    - "NO_COLOR env var (any value) AND [ -t 1 ] gate ANSI color output (TUI-06)"
    - "Confirmation prompt 'Install N component(s)? [y/N]' renders after enter; default N cancels"
    - "tui_confirm_prompt is a separate exported function so install.sh can drive confirmation outside the menu loop"
    - "Bash 3.2 compatible: NO declare -A, NO declare -n, NO read -N, NO float read -t"
  artifacts:
    - path: "scripts/lib/tui.sh"
      provides: "tui_checklist + tui_confirm_prompt menu rendering API"
      contains: "tui_checklist tui_confirm_prompt _tui_read_key _tui_render _tui_enter_raw _tui_restore"
  key_links:
    - from: "scripts/lib/tui.sh"
      to: "$TK_TUI_TTY_SRC (default /dev/tty)"
      via: "per-read < redirection (NOT exec < /dev/tty)"
      pattern: "read.*<.*TK_TUI_TTY_SRC"
    - from: "scripts/lib/tui.sh trap registration"
      to: "_tui_restore handler"
      via: "trap '_tui_restore || true' EXIT INT TERM"
      pattern: "trap.*_tui_restore.*EXIT.*INT.*TERM"
    - from: "scripts/lib/tui.sh"
      to: "TUI_RESULTS[] global array"
      via: "writes selected indices on enter"
      pattern: "TUI_RESULTS\\["
---

<objective>
Create `scripts/lib/tui.sh` — a Bash 3.2 compatible TUI checklist library exposing two functions:

1. `tui_checklist` — renders a grouped checkbox menu (Bootstrap / Core / Optional sections per D-01) with arrow-navigation; writes user's selection into the global array `TUI_RESULTS[]` (one `1` or `0` per item, indices match the input).
2. `tui_confirm_prompt` — renders a `Install N component(s)? [y/N]` prompt and returns 0 (yes) or 1 (no/default) (TUI-05).

Critical Bash 3.2 constraints (TUI-01):
- `read -rsn1` (lowercase n) for single-byte read; `read -rsn2` for the 2-byte arrow tail. NEVER `read -N` (Bash 4.2+).
- NO `declare -A` / `declare -n` namerefs (Bash 4+). Use parallel indexed arrays + global `TUI_RESULTS[]`.
- NO float `read -t 0.1` (Bash 4+).

The TUI MUST register the EXIT/INT/TERM trap BEFORE entering raw mode (TUI-03) so Ctrl-C mid-render restores `stty` cleanly. The trap handler MUST use `|| true` to prevent compounding restore failures.

Purpose: Plan 04 (`scripts/install.sh`) consumes both functions to render the unified install checklist. Plans 25 (MCPs) and 26 (Skills) reuse the same `tui_checklist` API for their catalogs — this is a foundation lib, not a single-use one.

Output: `scripts/lib/tui.sh` (new sourced lib, no errexit, ~280 lines).
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
@scripts/lib/bootstrap.sh
@scripts/lib/dry-run-output.sh

<canonical_refs>
- 24-PATTERNS.md §"scripts/lib/tui.sh (new sourced lib, TTY read/write)" (lines 25-149) — exact lib header pattern, color guard, TTY seam, trap structure, raw-mode helpers, key-read pattern, parallel array state
- 24-RESEARCH.md §2 "Bash 3.2 TUI Implementation" (lines 101-251) — keystroke pattern, arrow key mapping table, render loop, raw mode enter/exit, anti-patterns
- 24-RESEARCH.md §3 "ANSI / Terminal Compatibility Matrix" (lines 253-303) — sequence safety table, NO_COLOR contract
- 24-RESEARCH.md §4 "/dev/tty Patterns Under curl | bash" (lines 305-383) — per-read redirection, no exec
- 24-RESEARCH.md §10 Risk 1 (Bash 3.2 read -rsn2 atomicity), Risk 4 (/dev/tty in Docker), Risk 5 (stty -g triple-fallback)
- scripts/lib/bootstrap.sh:42-48 — TK_BOOTSTRAP_TTY_SRC seam pattern (TK_TUI_TTY_SRC mirrors this exactly per D-33)
- scripts/lib/dry-run-output.sh:21-38 — dro_init_colors NO_COLOR + [ -t 1 ] gate idiom (TUI-06 contract)
- 24-CONTEXT.md D-01..D-03 (grouped sections), D-16..D-20 (visual + key bindings), D-33 (test seam)
</canonical_refs>

<interfaces>
<!-- Key contracts and patterns the executor MUST use directly. -->

From scripts/lib/bootstrap.sh:42-48 (the TTY seam pattern to mirror exactly):
```bash
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

local choice=""
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    _bootstrap_log_info "bootstrap skipped — no TTY"
    return 0
fi
```

From scripts/lib/dry-run-output.sh:21-38 (NO_COLOR + TTY gate idiom — copy this contract):
```bash
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    _DRO_G='\033[0;32m'
    _DRO_NC='\033[0m'
else
    _DRO_G=''
    _DRO_NC=''
fi
```

From scripts/lib/dry-run-output.sh:48-55 (Bash 3.2 indirect expansion — eval-based, not declare -n):
```bash
eval "color_val=\${$color_var:-}"
local header_text="[${marker} ${label}]"
printf '%b%-44s%6d files%b\n' "$color_val" "$header_text" "$count" "${_DRO_NC:-}"
```

ANSI sequences confirmed safe on macOS Terminal / iTerm2 / xterm / tmux / screen (24-RESEARCH.md §3):
- `\e[?25l` — hide cursor
- `\e[?25h` — show cursor
- `\e[H` — move cursor to row 1, col 1
- `\e[J` — erase from cursor to end of screen
- `\e[2K` — erase current line
- `\e[2m` — dim (for section headers + descriptions)
- `\e[0m` — reset

Arrow key bytes:
- ↑ Up: `$'\e[A'` (3 bytes: ESC `[` `A`)
- ↓ Down: `$'\e[B'` (3 bytes: ESC `[` `B`)

Public API (the contract Plan 04 consumes):
```
tui_checklist
  Inputs: parallel arrays MUST be set by the caller before invocation:
    TUI_LABELS=()    # display name per item, e.g. "superpowers"
    TUI_GROUPS=()    # group name per item: "Bootstrap" | "Core" | "Optional"
    TUI_INSTALLED=() # 1=already installed, 0=not installed
    TUI_DESCS=()     # one-line description per item
  Outputs:
    TUI_RESULTS=()   # 1=user wants to install, 0=skip; same length as TUI_LABELS
    Return code: 0 on enter, 1 on q/Ctrl-C/EOF cancel
  Stdout/stderr: TUI rendering writes to /dev/tty directly (NOT stdout)
                 so callers can capture stdout without polluting the menu

tui_confirm_prompt <prompt_text>
  Inputs: $1 = prompt text, e.g. "Install 4 component(s)? [y/N] "
  Outputs:
    Return code: 0 if user types y or Y; 1 otherwise (default N)
  Stdout/stderr: writes prompt to /dev/tty
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write scripts/lib/tui.sh — Bash 3.2 TUI checklist + confirm prompt (TUI-01..TUI-06)</name>
  <files>scripts/lib/tui.sh</files>

  <read_first>
    - scripts/lib/bootstrap.sh (lines 1-99) — analog file for sourced-lib structure (header, color guards, TK_*_TTY_SRC seam, _<lib>_log_* helpers, no-errexit comment)
    - scripts/lib/dry-run-output.sh (lines 1-72) — pattern for NO_COLOR gate, eval-based indirect expansion, color var caching idiom
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/lib/tui.sh (new sourced lib)" (lines 25-149) — verbatim patterns to copy
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §2 "Bash 3.2 TUI Implementation" (lines 101-251) — keystroke + render + raw-mode patterns
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §3 "ANSI / Terminal Compatibility Matrix" — sequence safety
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §4 "/dev/tty Patterns" (lines 305-383) — per-read redirection, no exec
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-CONTEXT.md decisions D-01..D-03 (grouped sections), D-16..D-20 (visual/keys), D-33 (test seam)
  </read_first>

  <behavior>
    - Sourcing scripts/lib/tui.sh under `set -euo pipefail` exits 0 (no errcascade)
    - tui_checklist iterates `TUI_LABELS[]` indices; renders sections grouped by `TUI_GROUPS[]` value transitions
    - Pre-selection rule: `TUI_INSTALLED[i]=1` → render `[installed ✓]`, leave `TUI_RESULTS[i]=0` and skip in toggle (D-13). `TUI_INSTALLED[i]=0` → pre-check `TUI_RESULTS[i]=1` (matches --yes default-set per D-12)
    - Up arrow ($'\e[A'): decrement FOCUS_IDX, skipping no items (selection cycles top-to-bottom is acceptable)
    - Down arrow ($'\e[B'): increment FOCUS_IDX, skipping installed items at toggle time only (focus can rest on installed items so user sees them)
    - Space: toggles `TUI_RESULTS[FOCUS_IDX]` between 0 and 1, but ONLY if `TUI_INSTALLED[FOCUS_IDX]=0` (installed items can't be unchecked from this UI)
    - Enter ($'\n' or $'\r' or empty): exits the loop with return 0
    - q (lowercase or uppercase) OR EOF on read: exits the loop with return 1 (cancel)
    - Ctrl-C: trap fires, _tui_restore runs, process exits via INT signal propagation
    - Color rendering: gated by `_TUI_COLOR=1` only when `[ -t 1 ]` AND `! [ -n "${NO_COLOR+x}" ]` AND `[[ "${TERM:-dumb}" != "dumb" ]]`
    - tui_confirm_prompt reads one line via `read -r -p "$1" choice < "$tty_target"`; returns 0 if `[[ "${choice:-N}" =~ ^[yY]$ ]]`, else 1
    - All TTY access uses per-read `< "${TK_TUI_TTY_SRC:-/dev/tty}"` redirection (NOT exec)
  </behavior>

  <action>
Create `scripts/lib/tui.sh`. The file is ~280 lines. Use this structure exactly (executor MUST keep function names, signatures, and the trap-before-raw-mode ordering verbatim; non-functional whitespace differences acceptable):

```bash
#!/bin/bash

# Claude Code Toolkit — TUI Checklist Library (v4.6+)
# Source this file. Do NOT execute it directly.
# Exposes: tui_checklist, tui_confirm_prompt
# Globals (read):  TK_TUI_TTY_SRC, NO_COLOR, TERM, TUI_LABELS, TUI_GROUPS,
#                  TUI_INSTALLED, TUI_DESCS
# Globals (write): TUI_RESULTS[], _TUI_COLOR, _TUI_SAVED_STTY (internal)
#
# Bash 3.2 compatibility:
#   - read -rsn1 + read -rsn2 two-pass arrow detection (no read -N which is 4.2+)
#   - parallel indexed arrays (no declare -A which is 4.0+, no declare -n which is 4.3+)
#   - integer read -t timeouts only (no float, which is 4.0+)
#   - eval-based indirect expansion (mirrors dry-run-output.sh:51-53)
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

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

# Internal log helpers — underscore prefix avoids name collision with caller.
_tui_log_info()    { echo -e "${BLUE}ℹ${NC} $1" >&2; }
_tui_log_warning() { echo -e "${YELLOW}⚠${NC} $1" >&2; }

# Color gating per TUI-06 + RESEARCH.md §3:
# `${NO_COLOR+x}` expands to "x" when NO_COLOR is SET (even empty), "" when unset.
# `[ -t 1 ]` disables color when stdout is not a TTY.
# `[[ "${TERM:-dumb}" != "dumb" ]]` disables color in restricted CI containers.
_tui_init_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [[ "${TERM:-dumb}" != "dumb" ]]; then
        _TUI_COLOR=1
    else
        _TUI_COLOR=0
    fi
}

# Saved stty state (set by _tui_enter_raw, restored by _tui_restore).
# Empty string when stty -g failed (e.g. no TTY); _tui_restore falls back to `stty sane`.
_TUI_SAVED_STTY=""

# Enter raw mode: hide cursor, save stty, disable canonical mode + echo.
# All TTY access uses per-read redirection (TK_TUI_TTY_SRC test seam, mirrors bootstrap.sh:42-48).
_tui_enter_raw() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    _TUI_SAVED_STTY=$(stty -g <"$tty_target" 2>/dev/null || echo "")
    printf '\e[?25l' > /dev/tty 2>/dev/null || true   # hide cursor
    stty -icanon -echo <"$tty_target" 2>/dev/null || true
}

# Restore terminal mode. Triple-fallback: saved string → stty sane → silent || true.
# Always restores cursor visibility. Idempotent — safe to call multiple times.
_tui_restore() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    if [[ -n "$_TUI_SAVED_STTY" ]]; then
        stty "$_TUI_SAVED_STTY" <"$tty_target" 2>/dev/null || \
            stty sane <"$tty_target" 2>/dev/null || true
    else
        stty sane <"$tty_target" 2>/dev/null || true
    fi
    printf '\e[?25h' > /dev/tty 2>/dev/null || true   # show cursor
    _TUI_SAVED_STTY=""
}

# Bash 3.2 keystroke read — two-pass for arrow escape sequences.
# Returns the raw byte(s) on stdout. Empty string on EOF.
# Supports: $'\e[A' ↑, $'\e[B' ↓, $'\e[C' →, $'\e[D' ←, ' ' space,
#           $'\n' / $'\r' / "" enter, 'q'/'Q' quit, $'\e' bare escape.
_tui_read_key() {
    local k=""
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    if ! IFS= read -rsn1 k <"$tty_target" 2>/dev/null; then
        printf ''
        return 1   # EOF — caller treats as cancel
    fi
    if [[ "$k" == $'\e' ]]; then
        local extra=""
        # Read up to 2 more bytes for the arrow tail. read -rsn2 without -t blocks
        # until exactly 2 bytes arrive. In standard terminals the [A or [B sequence
        # arrives in one OS write so blocking is fine. The 2>/dev/null || true
        # handles the case where only 1 extra byte was available (bare ESC).
        IFS= read -rsn2 extra <"$tty_target" 2>/dev/null || true
        k="${k}${extra}"
    fi
    printf '%s' "$k"
    return 0
}

# Render one frame of the TUI. Writes to /dev/tty (NOT stdout) so callers can
# capture stdout without polluting the menu. Section headers are derived from
# TUI_GROUPS[] transitions — adjacent items in the same group share a header.
_tui_render() {
    # Move cursor to top-left and erase to end-of-screen (RESEARCH.md §3 — no
    # alternate screen; simpler clear+redraw approach).
    printf '\e[H\e[J' > /dev/tty 2>/dev/null || true

    local total="${#TUI_LABELS[@]}"
    local prev_group=""
    local i

    for (( i=0; i<total; i++ )); do
        local label="${TUI_LABELS[$i]:-}"
        local grp="${TUI_GROUPS[$i]:-}"
        local installed="${TUI_INSTALLED[$i]:-0}"
        local checked="${TUI_RESULTS[$i]:-0}"

        # Section header on group change.
        if [[ "$grp" != "$prev_group" && -n "$grp" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                printf '\n  \e[2m%s\e[0m\n' "$grp" > /dev/tty 2>/dev/null || true
            else
                printf '\n  %s\n' "$grp" > /dev/tty 2>/dev/null || true
            fi
            prev_group="$grp"
        fi

        # Focus indicator (D-16: arrow ▶, NOT reverse video).
        local arrow="  "
        if [[ "$i" -eq "${FOCUS_IDX:-0}" ]]; then
            arrow="${TK_TUI_ARROW:-▶ }"
        fi

        # Checkbox glyph (D-17).
        local box="[ ]"
        if [[ "$installed" -eq 1 ]]; then
            box="[installed ✓]"
        elif [[ "$checked" -eq 1 ]]; then
            box="[x]"
        fi

        printf '%s%s %s\n' "$arrow" "$box" "$label" > /dev/tty 2>/dev/null || true
    done

    # Help line (D-19: always shown for discoverability).
    printf '\n  \e[2m↑↓ move · space toggle · enter confirm · q quit\e[0m\n' \
        > /dev/tty 2>/dev/null || true
    if [[ "${_TUI_COLOR:-0}" -ne 1 ]]; then
        # Strip ANSI when colors disabled — re-render the help line plain.
        printf '\r\e[2K  ↑↓ move · space toggle · enter confirm · q quit\n' \
            > /dev/tty 2>/dev/null || true
    fi

    # Description line for focused item (D-20: single dimmed line).
    local desc="${TUI_DESCS[${FOCUS_IDX:-0}]:-}"
    if [[ -n "$desc" ]]; then
        if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
            printf '  \e[2m%s\e[0m\n' "$desc" > /dev/tty 2>/dev/null || true
        else
            printf '  %s\n' "$desc" > /dev/tty 2>/dev/null || true
        fi
    fi
}

# tui_checklist — render the checklist menu and capture user selection.
# Globals consumed (read by caller): TUI_LABELS[] TUI_GROUPS[] TUI_INSTALLED[] TUI_DESCS[]
# Globals produced: TUI_RESULTS[] (parallel index, 1=install / 0=skip)
# Return: 0 on enter, 1 on cancel (q/Ctrl-C/EOF)
tui_checklist() {
    local total="${#TUI_LABELS[@]}"
    if [[ "$total" -eq 0 ]]; then
        _tui_log_warning "tui_checklist invoked with empty TUI_LABELS"
        return 1
    fi

    _tui_init_colors

    # Pre-selection per D-12: pre-check uninstalled items, leave installed unchecked.
    TUI_RESULTS=()
    local i
    for (( i=0; i<total; i++ )); do
        if [[ "${TUI_INSTALLED[$i]:-0}" -eq 1 ]]; then
            TUI_RESULTS[$i]=0
        else
            TUI_RESULTS[$i]=1
        fi
    done

    FOCUS_IDX=0

    # CRITICAL (TUI-03): trap MUST be registered BEFORE _tui_enter_raw.
    # The || true on the handler prevents compounding failures.
    trap '_tui_restore || true' EXIT INT TERM

    _tui_enter_raw

    local rc=0
    while true; do
        _tui_render

        local key=""
        if ! key=$(_tui_read_key); then
            # EOF — fail-closed cancel (TUI-02 D-11).
            rc=1
            break
        fi

        case "$key" in
            $'\e[A')
                # ↑ Up
                if [[ "$FOCUS_IDX" -gt 0 ]]; then
                    FOCUS_IDX=$((FOCUS_IDX - 1))
                fi
                ;;
            $'\e[B')
                # ↓ Down
                if [[ "$FOCUS_IDX" -lt $((total - 1)) ]]; then
                    FOCUS_IDX=$((FOCUS_IDX + 1))
                fi
                ;;
            ' ')
                # Space — toggle, but installed items are immutable (D-13).
                if [[ "${TUI_INSTALLED[$FOCUS_IDX]:-0}" -ne 1 ]]; then
                    if [[ "${TUI_RESULTS[$FOCUS_IDX]:-0}" -eq 1 ]]; then
                        TUI_RESULTS[$FOCUS_IDX]=0
                    else
                        TUI_RESULTS[$FOCUS_IDX]=1
                    fi
                fi
                ;;
            ''|$'\n'|$'\r')
                # Enter — confirm.
                rc=0
                break
                ;;
            q|Q)
                # Quit — cancel.
                rc=1
                break
                ;;
            *)
                # Unrecognized — ignore and re-render.
                ;;
        esac
    done

    _tui_restore
    trap - EXIT INT TERM

    # Final render (post-restore) so the user sees the final state in normal mode.
    return "$rc"
}

# tui_confirm_prompt — render a single line [y/N] prompt.
# $1 = prompt text (e.g. "Install 4 component(s)? [y/N] ")
# Return: 0 if user typed y/Y; 1 otherwise (default N, EOF, q/Q).
# Reads from < "${TK_TUI_TTY_SRC:-/dev/tty}" — same seam as the main checklist.
tui_confirm_prompt() {
    local prompt_text="${1:-Confirm? [y/N] }"
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    local choice=""
    if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
        # No TTY — fail-closed N per TUI-02 / D-11.
        return 1
    fi
    case "${choice:-N}" in
        y|Y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
```

Critical rules:

1. **NO `set -euo pipefail`** anywhere in this file — sourced libs must not alter caller error mode (verified pattern: bootstrap.sh:19, detect.sh:11, dry-run-output.sh:8).
2. **TTY access pattern** is per-read `< "$tty_target"` redirection — NEVER `exec < /dev/tty`. The `tty_target` var is computed inside each function (NOT a global). This mirrors bootstrap.sh:43-48 exactly per D-33.
3. **Trap ordering (TUI-03)**: the `trap '_tui_restore || true' EXIT INT TERM` line MUST appear BEFORE the `_tui_enter_raw` call, in the same `tui_checklist` function body. Reordering breaks the Ctrl-C-restores-terminal contract.
4. **Render output goes to `> /dev/tty`** (with `2>/dev/null || true` to suppress errors when /dev/tty is absent). Stdout MUST stay clean so the install.sh orchestrator can capture status without menu noise.
5. **Bash 3.2 compatibility audit**: do NOT use `declare -A`, `declare -n`, `read -N` (capital), `read -t 0.1` (float), `${var:0:1}` slicing on locale-encoded strings (works for ASCII only; ok here). Acceptable: `read -rsn1`, `read -rsn2`, `[[ ... ]]`, `(( ... ))`, parallel indexed arrays.
6. **NO_COLOR test** uses `[ -z "${NO_COLOR+x}" ]` — this is the no-color.org canonical test (presence of var, even empty string, disables color). Verified pattern: dry-run-output.sh:26.
7. **`TK_TUI_ARROW` env override**: per RESEARCH §12.2 open question — allow `export TK_TUI_ARROW='>'` as a no-configure escape hatch for terminals that don't render `▶`.
8. **No usage of `TUI_RESULTS=()` outside `tui_checklist`** — the function fully populates it on every invocation.
9. **`shellcheck -S warning` MUST pass clean.** Ignore SC2034 on color guards (already done). All variable expansions use `${var:-}` defaults to satisfy nounset.

Implements decisions:
- D-01..D-03: grouped sections, non-selectable headers, in-group dispatch order
- D-13: installed items immutable in toggle
- D-16..D-20: arrow indicator, checkbox glyphs, key bindings, help line, description line
- D-33: TK_TUI_TTY_SRC seam mirrors TK_BOOTSTRAP_TTY_SRC

Implements requirements: TUI-01 (Bash 3.2 keystroke), TUI-02 (TK_TUI_TTY_SRC seam + fail-closed), TUI-03 (trap before raw), TUI-04 (label + status + description), TUI-05 (tui_confirm_prompt), TUI-06 (NO_COLOR + TTY + TERM=dumb gate).

Note: TUI-07 (≥15 assertions in test-install-tui.sh) is delivered by Plan 04, not here. This plan only delivers the lib itself.
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/lib/tui.sh && bash -c 'set -euo pipefail; source scripts/lib/tui.sh && for f in tui_checklist tui_confirm_prompt _tui_read_key _tui_render _tui_enter_raw _tui_restore _tui_init_colors; do [[ "$(type -t "$f")" == "function" ]] || { echo "MISSING: $f"; exit 1; }; done && echo all-functions-defined'</automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/lib/tui.sh` exists
    - Sourcing under `set -euo pipefail` exits 0 (no errcascade)
    - All seven functions defined as `function` type: `tui_checklist`, `tui_confirm_prompt`, `_tui_read_key`, `_tui_render`, `_tui_enter_raw`, `_tui_restore`, `_tui_init_colors`
    - File contains exact string `# IMPORTANT: No errexit/nounset/pipefail` (sourced-lib invariant marker)
    - File does NOT contain `set -euo pipefail` (grep returns no match)
    - File does NOT contain `read -N` (Bash 4.2+ only — would break Bash 3.2)
    - File does NOT contain `declare -A` or `declare -n` (Bash 4+ only)
    - File contains `read -rsn1` AND `read -rsn2` (Bash 3.2 two-pass arrow detection)
    - File contains `trap '_tui_restore || true' EXIT INT TERM` (TUI-03 contract)
    - File contains `TK_TUI_TTY_SRC` (D-33 test seam)
    - File contains `[ -z "${NO_COLOR+x}" ]` (TUI-06 NO_COLOR contract per no-color.org)
    - File contains `[[ "${TERM:-dumb}" != "dumb" ]]` (RESEARCH §3 dumb-terminal guard)
    - File contains `TUI_RESULTS=()` (output array — TUI-01 contract)
    - File contains `[installed ✓]` AND `[ ]` AND `[x]` (TUI-04 checkbox glyphs per D-17)
    - `shellcheck -S warning scripts/lib/tui.sh` exits 0
  </acceptance_criteria>

  <done>
    Lib sourceable; functions defined; key contracts (trap order, TTY seam, NO_COLOR, Bash 3.2 keystroke pattern) all verified by grep checks. Plan 04 will exercise the full keystroke matrix in test-install-tui.sh.
  </done>
</task>

<task type="auto">
  <name>Task 2: Smoke-test tui.sh by sourcing it under various seam configurations</name>
  <files>scripts/lib/tui.sh</files>

  <read_first>
    - scripts/lib/tui.sh (just created in Task 1)
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §10 Risk 1 (Bash 3.2 read -rsn2 atomicity), Risk 4 (no-TTY in Docker)
  </read_first>

  <action>
Execute three smoke checks to validate the lib BEFORE Plan 04 wires it into the orchestrator. Run each check as a separate bash command and assert outcomes.

Check 1 — Source under set -euo pipefail without args (no TUI invocation):

```bash
bash -c 'set -euo pipefail; source scripts/lib/tui.sh; echo source-ok'
```
Expected: exit 0, prints `source-ok`.

Check 2 — `tui_confirm_prompt` returns 1 (no/EOF) on /dev/null TTY source:

```bash
bash -c '
set -euo pipefail
source scripts/lib/tui.sh
TK_TUI_TTY_SRC=/dev/null
if tui_confirm_prompt "skip-prompt? [y/N] "; then
    echo CONFIRMED
    exit 1
else
    echo DECLINED
fi
'
```
Expected: exit 0, prints `DECLINED`.

Check 3 — `tui_confirm_prompt` returns 0 (yes) when TTY source is a fixture file containing "y\n":

```bash
TMP=$(mktemp /tmp/tui-fixture.XXXXXX)
printf 'y\n' > "$TMP"
bash -c "
set -euo pipefail
source scripts/lib/tui.sh
TK_TUI_TTY_SRC='$TMP'
if tui_confirm_prompt 'confirm-y? [y/N] '; then
    echo CONFIRMED
else
    echo DECLINED
    exit 1
fi
"
rm -f "$TMP"
```
Expected: exit 0, prints `CONFIRMED`.

If any check fails, debug `tui.sh` (likely candidates: TTY redirection syntax, return-code conventions, `read -r -p` quoting) and re-run the failing check.

Note: Full `tui_checklist` keystroke testing is deferred to Plan 04's `test-install-tui.sh` extension. Those tests need a sandbox HOME + parallel arrays, which is a heavier setup. Here we only smoke the simpler `tui_confirm_prompt` happy/sad paths to flush out gross errors before Plan 04 starts.
  </action>

  <verify>
    <automated>bash -c 'set -euo pipefail; source scripts/lib/tui.sh; echo source-ok' && bash -c 'set -euo pipefail; source scripts/lib/tui.sh; TK_TUI_TTY_SRC=/dev/null; if tui_confirm_prompt "x"; then echo BAD; exit 1; fi; echo DECLINED' && TMP=$(mktemp /tmp/tui-fixture-confirm.XXXXXX); printf 'y\n' > "$TMP"; bash -c "set -euo pipefail; source scripts/lib/tui.sh; TK_TUI_TTY_SRC='$TMP'; tui_confirm_prompt 'x'" && echo CONFIRMED; rm -f "$TMP"</automated>
  </verify>

  <acceptance_criteria>
    - Check 1 exits 0 and prints `source-ok`
    - Check 2 exits 0 and prints `DECLINED` (TUI-02 fail-closed contract for /dev/null TTY)
    - Check 3 exits 0 and prints `CONFIRMED` (fixture-based input works through TK_TUI_TTY_SRC seam)
    - No errors written to stderr in any check
  </acceptance_criteria>

  <done>
    Lib loads and `tui_confirm_prompt` honors the TK_TUI_TTY_SRC seam in both directions. Ready for Plan 04 to drive `tui_checklist`.
  </done>
</task>

<task type="auto">
  <name>Task 3: make check + commit tui.sh</name>
  <files>scripts/lib/tui.sh</files>

  <read_first>
    - Makefile (lines 36-43) — make check / shellcheck targets
    - scripts/lib/tui.sh — the file being committed
  </read_first>

  <action>
1. Run `shellcheck -S warning scripts/lib/tui.sh` — must exit 0.
2. Run `bash scripts/tests/test-bootstrap.sh` — must exit 0 (BACKCOMPAT-01 invariant: this lib was added without touching init-claude.sh, so all 26 assertions stay green).
3. Run `markdownlint -c .markdownlint.json scripts/lib/tui.sh 2>/dev/null || true` (the file is .sh not .md so lint is a no-op; the check exists to ensure no markdown was accidentally placed).
4. Commit `scripts/lib/tui.sh` only:

```bash
git add scripts/lib/tui.sh
git commit -m "$(cat <<'EOF'
feat(24): add lib/tui.sh Bash 3.2 TUI checklist + confirm prompt

TUI-01..TUI-06 implementation. Exposes tui_checklist (grouped checkbox
menu with arrow/space/enter navigation) and tui_confirm_prompt (single
[y/N] prompt). Both use per-read < "${TK_TUI_TTY_SRC:-/dev/tty}"
redirection mirroring v4.4 TK_BOOTSTRAP_TTY_SRC seam shape exactly.

Bash 3.2 compatibility:
- read -rsn1 + read -rsn2 two-pass arrow detection (no read -N)
- parallel indexed arrays TUI_LABELS / TUI_GROUPS / TUI_INSTALLED /
  TUI_DESCS / TUI_RESULTS (no declare -A or declare -n namerefs)
- integer read timeouts only (no float -t 0.1)

TUI-03 contract: trap '_tui_restore || true' EXIT INT TERM is
registered BEFORE _tui_enter_raw, so Ctrl-C mid-render restores stty
(triple-fallback: saved string → stty sane → silent || true).

TUI-06 NO_COLOR: gates ANSI on [-t 1] AND [-z "${NO_COLOR+x}"] AND
[[ "${TERM:-dumb}" != "dumb" ]] per no-color.org + RESEARCH §3.

D-01..D-03 grouped sections, D-13 installed-items-immutable, D-16
arrow indicator (NOT reverse video), D-17 checkbox glyphs, D-19
help line always shown, D-20 description on focused row, D-33
TK_TUI_TTY_SRC test seam.

Refs: 24-CONTEXT.md D-01..D-03, D-13, D-16..D-20, D-33;
24-RESEARCH.md §2 (Bash 3.2 TUI), §3 (ANSI matrix), §4 (/dev/tty).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/lib/tui.sh && bash scripts/tests/test-bootstrap.sh && git log -1 --pretty=%B | head -1 | grep -q '^feat(24): add lib/tui.sh'</automated>
  </verify>

  <acceptance_criteria>
    - shellcheck passes (exit 0)
    - test-bootstrap.sh passes (26 assertions green; BACKCOMPAT-01)
    - Most recent commit subject matches `feat(24): add lib/tui.sh Bash 3.2 TUI checklist`
    - `git show --stat HEAD` shows ONLY `scripts/lib/tui.sh` modified (no other files)
  </acceptance_criteria>

  <done>
    Plan 02 lands as a single conventional commit. Wave 1 TUI lib ready for Plan 04 orchestrator.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user keystrokes → tui.sh | Untrusted byte stream from /dev/tty (or test fixture) |
| sourced lib → caller | tui.sh executes inside any caller's process; must not alter caller error mode or leak globals |
| stty raw mode → terminal | tui.sh enters raw mode; must always exit raw mode even on signal/error |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-04 | Denial of service | TTY raw mode left dangling on crash exposes user to blind-typing | mitigate | Triple-fallback EXIT trap: saved stty string → stty sane → silent || true (RESEARCH §10 Risk 5; verified in _tui_restore) |
| T-24-06 | Tampering | TK_TUI_TTY_SRC env var allows arbitrary file as keystroke source | accept | Test-only seam mirroring v4.4 TK_BOOTSTRAP_TTY_SRC (already accepted threat there); user already controls their own env; no privilege boundary crossed |
| T-24-07 | Information disclosure | Stdout pollution by TUI render | mitigate | All render output goes to `> /dev/tty 2>/dev/null` — stdout stays clean for caller capture |
| T-24-08 | Denial of service | read -rsn2 may block forever on partial arrow sequence | accept | RESEARCH §10 Risk 1 — known Bash 3.2 limitation; mitigated by atomic OS write of arrow sequence in standard terminals; SSH/dropped-connection fallback is `stty sane` recovery (same failure mode as `vim`/`less`) |
</threat_model>

<verification>
After Task 3 completes:

```bash
# Lib loads cleanly
bash -c 'set -euo pipefail; source scripts/lib/tui.sh; echo loaded-clean'

# Public API defined
bash -c 'source scripts/lib/tui.sh; type -t tui_checklist tui_confirm_prompt'

# Confirm prompt fail-closed on no-TTY
bash -c 'set -euo pipefail; source scripts/lib/tui.sh; TK_TUI_TTY_SRC=/dev/null; ! tui_confirm_prompt "x"'

# Confirm prompt accepts y via fixture
TMP=$(mktemp); printf 'y\n' > "$TMP"; bash -c "set -euo pipefail; source scripts/lib/tui.sh; TK_TUI_TTY_SRC='$TMP'; tui_confirm_prompt 'x'"; rm -f "$TMP"

# BACKCOMPAT-01 regression
bash scripts/tests/test-bootstrap.sh

# Lint
shellcheck -S warning scripts/lib/tui.sh
```
</verification>

<success_criteria>
- `scripts/lib/tui.sh` exists with `tui_checklist` and `tui_confirm_prompt` exported
- Bash 3.2 compat verified by grep (no `read -N`, no `declare -A`, no `declare -n`)
- TUI-03 trap-before-raw-mode contract present
- TUI-06 NO_COLOR + TTY + TERM=dumb three-layer gate present
- TK_TUI_TTY_SRC seam mirrors bootstrap.sh per-read pattern (NOT exec)
- shellcheck clean
- `tui_confirm_prompt` smoke-tested in both fail-closed and confirmed paths
- test-bootstrap.sh stays green (26 assertions)
- Single conventional commit `feat(24): add lib/tui.sh ...`
</success_criteria>

<output>
After Plan 02 completes, create `.planning/phases/24-unified-tui-installer-centralized-detection/24-02-SUMMARY.md` describing:
- Files created: `scripts/lib/tui.sh`
- Public API: tui_checklist (grouped checklist with arrow/space/enter), tui_confirm_prompt ([y/N] prompt)
- Bash 3.2 compatibility decisions (read -rsn1/2, parallel arrays, eval-based indirect)
- TUI-03 trap-ordering contract location (line numbers in the lib)
- TK_TUI_TTY_SRC test seam contract (mirrors v4.4 bootstrap)
- Decisions implemented: D-01..D-03, D-13, D-16..D-20, D-33
- Requirements addressed: TUI-01, TUI-02, TUI-03, TUI-04, TUI-05, TUI-06
- Downstream contract: Plan 04 sources this lib from install.sh; extends test-install-tui.sh with keystroke fixture scenarios for TUI-07 (≥15 assertions)
</output>
