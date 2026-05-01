#!/bin/bash

# Claude Code Toolkit — TUI Checklist Library (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes: tui_checklist, tui_confirm_prompt
# Globals (read):  TK_TUI_TTY_SRC, NO_COLOR, TERM, TUI_LABELS, TUI_GROUPS,
#                  TUI_INSTALLED, TUI_DESCS, TUI_REQUIRED (optional),
#                  TUI_GROUP_NAMES + TUI_GROUP_DESCS (optional, parallel pair
#                  for per-section dim subtitles — Bash 3.2 compat substitute
#                  for an associative array)
# Globals (write): TUI_RESULTS[], _TUI_COLOR, _TUI_SAVED_STTY (internal)
#
# TUI_REQUIRED[i]=1 marks a row as mandatory: pre-checked, immutable
# (space is no-op), rendered as `[required]`. Used for toolkit (the
# whole reason the user is running install.sh).
#
# Bash 3.2 compatibility:
#   - read -rsn1 + read -rsn2 two-pass arrow detection (no capital-N flag, which is 4.2+)
#   - parallel indexed arrays (no associative arrays which are 4.0+, no namerefs which are 4.3+)
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
_tui_log_info()    { echo -e "${BLUE}i${NC} $1" >&2; }
_tui_log_warning() { echo -e "${YELLOW}!${NC} $1" >&2; }

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
# WR-02: cursor-hide writes to $tty_target (not hard-coded /dev/tty) to honor the
# test seam consistently — prevents tests from leaking real-terminal state changes.
_tui_enter_raw() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    _TUI_SAVED_STTY=$(stty -g <"$tty_target" 2>/dev/null || echo "")
    printf '\e[?25l' >> "$tty_target" 2>/dev/null || true   # hide cursor
    stty -icanon -echo <"$tty_target" 2>/dev/null || true
}

# Restore terminal mode. Triple-fallback: saved string → stty sane → silent || true.
# Always restores cursor visibility. Idempotent — safe to call multiple times.
# WR-02: cursor-show writes to $tty_target (not hard-coded /dev/tty) to honor the
# test seam consistently.
_tui_restore() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    if [[ -n "$_TUI_SAVED_STTY" ]]; then
        stty "$_TUI_SAVED_STTY" <"$tty_target" 2>/dev/null || \
            stty sane <"$tty_target" 2>/dev/null || true
    else
        stty sane <"$tty_target" 2>/dev/null || true
    fi
    printf '\e[?25h' >> "$tty_target" 2>/dev/null || true   # show cursor
    _TUI_SAVED_STTY=""
}

# Bash 3.2 keystroke read — two-pass for arrow escape sequences.
# Returns the raw byte(s) on stdout. Empty string on EOF.
# Supports: $'\e[A' up, $'\e[B' down, $'\e[C' right, $'\e[D' left, ' ' space,
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

# Render one frame of the TUI. Writes to $tty_target (NOT stdout) so callers can
# capture stdout without polluting the menu. Section headers are derived from
# TUI_GROUPS[] transitions — adjacent items in the same group share a header.
# WR-03: all printf calls go to "$tty_target" (TK_TUI_TTY_SRC seam) — same pattern
# as _tui_read_key — so tests can redirect rendered output for inspection.
_tui_render() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"

    # Move cursor to top-left and erase to end-of-screen (RESEARCH.md §3 — no
    # alternate screen; simpler clear+redraw approach).
    printf '\e[H\e[J' >> "$tty_target" 2>/dev/null || true

    local total="${#TUI_LABELS[@]}"
    local prev_group=""
    local i

    for (( i=0; i<total; i++ )); do
        local label="${TUI_LABELS[$i]:-}"
        local grp="${TUI_GROUPS[$i]:-}"
        local installed="${TUI_INSTALLED[$i]:-0}"
        local required="${TUI_REQUIRED[$i]:-0}"
        local checked="${TUI_RESULTS[$i]:-0}"
        local desc="${TUI_DESCS[$i]:-}"
        local row_num=$((i + 1))

        # Section header on group change — extra blank line above for clearer separation.
        # Optional dim subtitle from TUI_GROUP_DESCS (associative-style: matched by name
        # via parallel-array lookup so we stay Bash 3.2 compatible — no `declare -A`).
        if [[ "$grp" != "$prev_group" && -n "$grp" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                printf '\n  \e[1m%s\e[0m\n' "$grp" >> "$tty_target" 2>/dev/null || true
            else
                printf '\n  %s\n' "$grp" >> "$tty_target" 2>/dev/null || true
            fi
            # Lookup group description: TUI_GROUP_NAMES[k] == "$grp" → TUI_GROUP_DESCS[k].
            # `${TUI_GROUP_NAMES[@]+...}` expands to empty when the array is unset/empty,
            # so the loop is a no-op when callers omit the optional pair (Bash 3.2 has no
            # `${#var[@]:-0}` syntax — that form is rejected as invalid substitution).
            local _grp_desc="" _grp_count=0 _gk
            if [[ -n "${TUI_GROUP_NAMES[@]+x}" ]]; then
                _grp_count="${#TUI_GROUP_NAMES[@]}"
            fi
            for (( _gk=0; _gk<_grp_count; _gk++ )); do
                if [[ "${TUI_GROUP_NAMES[$_gk]:-}" == "$grp" ]]; then
                    _grp_desc="${TUI_GROUP_DESCS[$_gk]:-}"
                    break
                fi
            done
            if [[ -n "$_grp_desc" ]]; then
                if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                    printf '  \e[2m%s\e[0m\n' "$_grp_desc" >> "$tty_target" 2>/dev/null || true
                else
                    printf '  %s\n' "$_grp_desc" >> "$tty_target" 2>/dev/null || true
                fi
            fi
            prev_group="$grp"
        fi

        # Focus indicator (D-16: arrow, NOT reverse video).
        local arrow="  "
        if [[ "$i" -eq "${FOCUS_IDX:-0}" ]]; then
            arrow="${TK_TUI_ARROW:-▶ }"
        fi

        # Checkbox glyph (D-17). Priority: required > installed > checked > unchecked.
        local box="[ ]"
        if [[ "$required" -eq 1 ]]; then
            box="[required]"
        elif [[ "$installed" -eq 1 ]]; then
            box="[installed ✓]"
        elif [[ "$checked" -eq 1 ]]; then
            box="[x]"
        fi

        # Numbered prefix + label row. Immutable rows (installed/required) render dim
        # so they read as "disabled" — user knows space won't toggle them.
        if [[ "${_TUI_COLOR:-0}" -eq 1 ]] && { [[ "$installed" -eq 1 ]] || [[ "$required" -eq 1 ]]; }; then
            printf '%s\e[2m%d. %s %s\e[0m\n' "$arrow" "$row_num" "$box" "$label" >> "$tty_target" 2>/dev/null || true
        else
            printf '%s%d. %s %s\n' "$arrow" "$row_num" "$box" "$label" >> "$tty_target" 2>/dev/null || true
        fi

        # Inline dimmed description under EVERY row (was previously focus-only at file bottom).
        if [[ -n "$desc" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                printf '       \e[2m%s\e[0m\n' "$desc" >> "$tty_target" 2>/dev/null || true
            else
                printf '       %s\n' "$desc" >> "$tty_target" 2>/dev/null || true
            fi
        fi
    done

    # Synthetic Submit row at FOCUS_IDX == total (one past last item). Always renderable;
    # serves as a visible "button" the user can navigate to. Enter on any row confirms,
    # but the explicit Submit row makes the action obvious without reading the footer.
    local submit_arrow="  "
    if [[ "${FOCUS_IDX:-0}" -eq "$total" ]]; then
        submit_arrow="${TK_TUI_ARROW:-▶ }"
    fi
    if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
        printf '\n%s\e[1;32m[ Install selected ]\e[0m  \e[2m← press Enter\e[0m\n' \
            "$submit_arrow" >> "$tty_target" 2>/dev/null || true
    else
        printf '\n%s[ Install selected ]  ← press Enter\n' \
            "$submit_arrow" >> "$tty_target" 2>/dev/null || true
    fi

    # Updated footer text.
    if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
        printf '\n  \e[2m↑↓ navigate · Space toggle · Enter install · Esc cancel\e[0m\n' \
            >> "$tty_target" 2>/dev/null || true
    else
        printf '\n  ↑↓ navigate · Space toggle · Enter install · Esc cancel\n' \
            >> "$tty_target" 2>/dev/null || true
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
    # Required items always pre-checked (immutable, can't be deselected).
    TUI_RESULTS=()
    local i
    for (( i=0; i<total; i++ )); do
        if [[ "${TUI_REQUIRED[$i]:-0}" -eq 1 ]]; then
            TUI_RESULTS[$i]=1
        elif [[ "${TUI_INSTALLED[$i]:-0}" -eq 1 ]]; then
            TUI_RESULTS[$i]=0
        else
            TUI_RESULTS[$i]=1
        fi
    done

    FOCUS_IDX=0

    # WR-04: Save the parent script's EXIT trap before installing our own.
    # `trap -p EXIT` prints the parent's trap definition (or empty if unset).
    # We restore it on normal return so that parent cleanup (e.g. install.sh's
    # run_cleanup for tmpfiles) is not silently dropped after tui_checklist returns.
    local _parent_exit_trap
    _parent_exit_trap=$(trap -p EXIT 2>/dev/null || echo "")

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
                # Up
                if [[ "$FOCUS_IDX" -gt 0 ]]; then
                    FOCUS_IDX=$((FOCUS_IDX - 1))
                fi
                ;;
            $'\e[B')
                # Down. FOCUS_IDX can extend to `total` (the synthetic Submit row).
                if [[ "$FOCUS_IDX" -lt "$total" ]]; then
                    FOCUS_IDX=$((FOCUS_IDX + 1))
                fi
                ;;
            ' ')
                # Space — toggle, but installed AND required items are immutable.
                # Submit row (FOCUS_IDX == total) also no-op for space.
                if [[ "$FOCUS_IDX" -lt "$total" ]] \
                   && [[ "${TUI_INSTALLED[$FOCUS_IDX]:-0}" -ne 1 ]] \
                   && [[ "${TUI_REQUIRED[$FOCUS_IDX]:-0}" -ne 1 ]]; then
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
    # WR-04: Restore parent EXIT trap so that the caller's cleanup is preserved.
    # If the parent had a trap, `eval` re-installs it verbatim (output of `trap -p`
    # is in shell-readable syntax). If not, clear our handler with `trap - EXIT`.
    if [[ -n "$_parent_exit_trap" ]]; then
        eval "$_parent_exit_trap"
    else
        trap - EXIT
    fi
    trap - INT TERM

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
