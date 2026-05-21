#!/bin/bash

# Claude Code Toolkit — TUI Checklist Library (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes: tui_checklist, tui_confirm_prompt, tui_tty_read
# Globals (read):  TK_TUI_TTY_SRC, NO_COLOR, TERM, TUI_LABELS, TUI_GROUPS,
#                  TUI_INSTALLED, TUI_DESCS, TUI_REQUIRED (optional),
#                  TUI_GROUP_NAMES + TUI_GROUP_DESCS (optional, parallel pair
#                  for per-section dim subtitles — Bash 3.2 compat substitute
#                  for an associative array),
#                  TUI_HEADER_TEXT (optional one-line banner above the list),
#                  TUI_HEADER_KEY  (optional 1-char key that fires TUI_HEADER_FN),
#                  TUI_HEADER_FN   (optional function name invoked on TUI_HEADER_KEY),
#                  TUI_ROW_KEY     (optional 1-byte key — typically $'\t' — that fires TUI_ROW_FN),
#                  TUI_ROW_FN      (optional function name invoked on TUI_ROW_KEY; FOCUS_IDX in scope)
# Globals (write): TUI_RESULTS[], _TUI_COLOR, _TUI_SAVED_STTY (internal)
#
# TUI_REQUIRED[i]=1 marks a row as mandatory: pre-checked, immutable
# (space is no-op), rendered as `[required]`. Used for toolkit (the
# whole reason the user is running install.sh).
#
# TUI_REINSTALLABLE[i]=1 marks an installed row as eligible for the
# install→reinstall toggle. Pressing Space cycles its TUI_RESULTS bit
# 0 ↔ 1 even though TUI_INSTALLED[i]==1. The render layer swaps
# `[installed ✓]` ↔ `[reinstall ↻]` accordingly (light-green for the
# reinstall state). Callers consume TUI_RESULTS as before — for an
# installed row they MUST also read TUI_INSTALLED[i] to know whether
# to skip vs reinstall. Default 0 preserves the legacy "installed
# rows are immutable" contract — Skills surface and any other caller
# that omits the array is unaffected.
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
_tui_log_info()    { echo -e "${CYAN}i${NC} $1" >&2; }
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
    # Enter alternate screen buffer when target appears to be a real TTY.
    # Bug 2026-05-07: frames > viewport height (27 MCPs × ~2 lines + headers
    # + footer ≈ 70 rows in a 30-row terminal) caused `\e[H\e[J` per-frame
    # clears to leave the previous frame's top in scrollback, so each
    # keypress duplicated the header/category banner. Alt screen isolates
    # the TUI from the user's scrollback — same pattern vim/less/htop use.
    #
    # Gating: was originally guarded by `_TUI_SAVED_STTY` non-empty, but a
    # user reported the dup persisting after that gate (2026-05-07 angry
    # report) — likely their `stty -g` returned empty for some shell-mode
    # reason and the gate suppressed the escape. The escape is harmless
    # bytes if the target isn't a real TTY (test seam files just gain a
    # `\e[?1049h` prefix), so widen the gate to "tty_target is a character
    # device OR is /dev/tty". Tests routing TK_TUI_TTY_SRC to a regular
    # file or named pipe still skip the escape so output assertions stay
    # clean. The matching `_tui_restore` exit-side is widened the same way.
    if [[ -n "$_TUI_SAVED_STTY" || -c "$tty_target" || "$tty_target" == /dev/tty ]]; then
        printf '\e[?1049h' >> "$tty_target" 2>/dev/null || true
    fi
    printf '\e[?25l' >> "$tty_target" 2>/dev/null || true   # hide cursor
    stty -icanon -echo <"$tty_target" 2>/dev/null || true
}

# Restore terminal mode. Triple-fallback: saved string → stty sane → silent || true.
# Always restores cursor visibility. Idempotent — safe to call multiple times.
# WR-02: cursor-show writes to $tty_target (not hard-coded /dev/tty) to honor the
# test seam consistently.
_tui_restore() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    # Leave alternate screen FIRST so any subsequent install output goes to the
    # main screen (where the user's scrollback lives). Mirror the entry-side
    # widened gate so symmetry holds even when stty -g returned empty.
    if [[ -n "$_TUI_SAVED_STTY" || -c "$tty_target" || "$tty_target" == /dev/tty ]]; then
        printf '\e[?1049l' >> "$tty_target" 2>/dev/null || true
    fi
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
        # Bare ESC vs arrow sequence (\e[A etc.) — without -t the read blocks
        # forever waiting for 2 more bytes, so a bare Esc keypress hangs the TUI.
        # Bash 3.2 (macOS floor) only accepts integer -t values; use 1s timeout.
        # On timeout (bare ESC) read returns >128 and `extra` stays empty —
        # caller's case matches "$'\e'" → cancel.
        local extra=""
        IFS= read -rsn2 -t 1 extra <"$tty_target" 2>/dev/null || true
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

    # Atomic frame composition: build the entire frame in a single string,
    # then write it to the tty in ONE printf. Per-line printfs (the previous
    # design) caused two problems:
    #   1. Visible flicker on macOS Terminal — each printf was a separate
    #      tty syscall, terminal repainted between them.
    #   2. Bleed-through of prior content (user report 2026-05-01: leftover
    #      "stripe-best-practices installed ✓" line peeking through the gap
    #      before the footer in the main components TUI). Per-line erase-to-
    #      EOL (\e[K) only cleared lines we wrote on; lines we *skipped over*
    #      with \n retained their prior content from a taller previous frame
    #      or from non-TUI output that happened to land in the viewport.
    # Single-write means the terminal sees one screen update — no flicker —
    # AND we start the frame with \e[H\e[J (home + clear-to-end-of-screen)
    # again, which is safe under atomic write because the user never sees
    # the cleared intermediate state.
    local _frame=""
    _frame+=$'\e[H\e[J'

    # Optional banner above the list (e.g. scope toggle for MCP picker).
    # Caller sets TUI_HEADER_TEXT to a single-line string. Rendered verbatim
    # so caller controls any inline color codes; under NO_COLOR / no-TTY the
    # caller is responsible for emitting plain glyphs.
    if [[ -n "${TUI_HEADER_TEXT:-}" ]]; then
        _frame+="  ${TUI_HEADER_TEXT}"$'\n\n'
    fi

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
        # Optional parallel array TUI_URLS[]; callers (skills picker) populate
        # an upstream GitHub URL string per row. Empty when caller omits the
        # array entirely (MCP / TK pickers) or per-row when no upstream is
        # known (e.g. memo-skill in skills picker). Rendered after desc as
        # ` · ${url}` when non-empty; tui itself adds no truncation — caller
        # owns width policy.
        local url=""
        if [[ -n "${TUI_URLS[*]+x}" ]]; then
            url="${TUI_URLS[$i]:-}"
        fi
        local row_num=$((i + 1))

        # Section header on group change — extra blank line above for clearer separation.
        # Optional dim subtitle from TUI_GROUP_DESCS (associative-style: matched by name
        # via parallel-array lookup so we stay Bash 3.2 compatible — no `declare -A`).
        if [[ "$grp" != "$prev_group" && -n "$grp" ]]; then
            if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
                _frame+=$'\n  \e[1m'"$grp"$'\e[0m\n'
            else
                _frame+=$'\n  '"$grp"$'\n'
            fi
            # Lookup group description: TUI_GROUP_NAMES[k] == "$grp" → TUI_GROUP_DESCS[k].
            # `${TUI_GROUP_NAMES[@]+...}` expands to empty when the array is unset/empty,
            # so the loop is a no-op when callers omit the optional pair (Bash 3.2 has no
            # `${#var[@]:-0}` syntax — that form is rejected as invalid substitution).
            local _grp_desc="" _grp_count=0 _gk
            # SC2199: use [*]+x (string concat) — [@]+x triggers shellcheck and is
            # semantically the same for the existence-check we want here.
            if [[ -n "${TUI_GROUP_NAMES[*]+x}" ]]; then
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
                    _frame+=$'  \e[2m'"$_grp_desc"$'\e[0m\n'
                else
                    _frame+="  $_grp_desc"$'\n'
                fi
            fi
            prev_group="$grp"
        fi

        # Focus indicator (D-16: arrow, NOT reverse video).
        local arrow="  "
        if [[ "$i" -eq "${FOCUS_IDX:-0}" ]]; then
            arrow="${TK_TUI_ARROW:-▶ }"
        fi

        # Checkbox glyph (D-17). Priority: required > installed-and-reinstalling
        # > installed > checked > unchecked.
        # Reinstall state: row is installed AND user toggled Space (TUI_RESULTS[i]=1)
        # AND TUI_REINSTALLABLE[i]=1 — render as `[reinstall ↻]` in light green so
        # the user can see at a glance which rows will be re-added on submit.
        local box="[ ]"
        local _reinstall=0
        if [[ "$required" -eq 1 ]]; then
            box="[required]"
        elif [[ "$installed" -eq 1 ]] \
             && [[ "${TUI_REINSTALLABLE[$i]:-0}" -eq 1 ]] \
             && [[ "$checked" -eq 1 ]]; then
            box="[reinstall ↻]"
            _reinstall=1
        elif [[ "$installed" -eq 1 ]]; then
            box="[installed ✓]"
        elif [[ "$checked" -eq 1 ]]; then
            box="[x]"
        fi

        # Numbered prefix + label + inline description. Pre-2026-05-07 the
        # description was a SECOND line under each row, but with 27 MCPs ×
        # 2 lines + headers + footer the frame easily exceeded a 30-row
        # terminal. The taller-than-viewport frame interacted badly with
        # the per-render `\e[H\e[J` clear (clears only the visible viewport
        # → when the new frame scrolls, the prior frame's TOP rows leaked
        # into scrollback above the viewport, producing visible duplication
        # on every keypress). Single-line rows roughly halve the frame
        # height and fit a 27-MCP picker into ~32 rows even with category
        # banners — well inside any modern terminal.
        local _label_render="${row_num}. ${box} ${label}"
        if [[ -n "$desc" ]]; then
            _label_render+=" — ${desc}"
        fi
        if [[ -n "$url" ]]; then
            _label_render+=" · ${url}"
        fi
        # Immutable rows (installed/required) render dim so they read as
        # "disabled" — user knows space won't toggle them. Exception:
        # reinstall state is bright light-green (call-out, not dim) so
        # the user can pick out pending re-adds at a glance. Description
        # always inherits the row's brightness — no separate dim styling
        # for the inline tail since the whole row is one stylistic unit.
        if [[ "${_TUI_COLOR:-0}" -eq 1 ]] && [[ "$_reinstall" -eq 1 ]]; then
            # \e[92m — bright (light) green. \e[0m resets all attrs.
            _frame+="$arrow"$'\e[92m'"${_label_render}"$'\e[0m\n'
        elif [[ "${_TUI_COLOR:-0}" -eq 1 ]] && { [[ "$installed" -eq 1 ]] || [[ "$required" -eq 1 ]]; }; then
            _frame+="$arrow"$'\e[2m'"${_label_render}"$'\e[0m\n'
        else
            _frame+="${arrow}${_label_render}"$'\n'
        fi
        unset _label_render
    done

    # Synthetic Submit row at FOCUS_IDX == total (one past last item). Always renderable;
    # serves as a visible "button" the user must navigate to before pressing Enter.
    # Enter from any other row jumps focus down to this row (intuitive shortcut)
    # — only Enter ON this row confirms install (prevents accidental triggers
    # while toggling checkboxes).
    local submit_arrow="  "
    if [[ "${FOCUS_IDX:-0}" -eq "$total" ]]; then
        submit_arrow="${TK_TUI_ARROW:-▶ }"
    fi
    if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
        _frame+=$'\n'"$submit_arrow"$'\e[1;32m[ Install selected ]\e[0m  \e[2m← press Enter\e[0m\n'
    else
        _frame+=$'\n'"${submit_arrow}[ Install selected ]  ← press Enter"$'\n'
    fi

    # Footer hint. Esc detection is unreliable on some macOS terminal configs
    # (Send +Esc / Esc-as-Meta), so the public hint advertises Ctrl+C — Esc is
    # still wired in tui_checklist's case match for terminals where it does work.
    # v6.16.0 — Back navigation removed; flow is linear. Cancel via Ctrl+C / q.
    # Phase 39 TUI-SCOPE-02: per-row hint surfaces only when caller wires the
    # Tab→TUI_ROW_FN dispatch. Composes with _header_hint (the s key) into a
    # single line; combined width was checked at planning (~95 chars under
    # 100-col terminals).
    local _row_hint=""
    if [[ -n "${TUI_ROW_KEY:-}" && -n "${TUI_ROW_FN:-}" ]]; then
        _row_hint=" · Tab row-scope"
    fi
    local _header_hint=""
    if [[ -n "${TUI_HEADER_KEY:-}" && -n "${TUI_HEADER_FN:-}" ]]; then
        # Phase 39 TUI-SCOPE-03 D-11: header key copy updated from "${KEY} scope"
        # (Phase 37) to "${KEY} set-all-scope" since `s` no longer toggles a
        # global flag — Plan 02 will make it write every row's
        # MCP_SELECTED_SCOPE slot. Updated here in Plan 01 because the footer
        # text is a render concern that ships with the per-row Tab hint;
        # behavior wiring lands in Plan 02.
        _header_hint=" · ${TUI_HEADER_KEY} set-all-scope"
    fi
    # v6.16.0 — replace "Space toggle" copy with "selection locked" when the
    # caller pre-locked the row checkboxes (e.g. MCP scope lock-screen). The
    # rest of the hint line composes the same way.
    local _toggle_hint="Space toggle"
    if [[ "${TK_TUI_LOCK_SELECTION:-0}" -eq 1 ]]; then
        _toggle_hint="selection locked"
    fi
    if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
        _frame+=$'\n  \e[2m↑↓ navigate · '"${_toggle_hint}"$' · Enter install'"${_row_hint}${_header_hint}"$' · Ctrl+C abort\e[0m\n'
    else
        _frame+=$'\n  ↑↓ navigate · '"${_toggle_hint}"$' · Enter install'"${_row_hint}${_header_hint}"$' · Ctrl+C abort\n'
    fi

    # Single atomic write — terminal renders one frame, no flicker, no bleed.
    printf '%s' "$_frame" >> "$tty_target" 2>/dev/null || true
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

    # Pre-selection: only required items are pre-checked (they cannot be
    # deselected anyway). Everything else — installed AND uninstalled — starts
    # unchecked so the user makes an explicit opt-in choice. Pre-checking
    # uninstalled rows used to default to "install everything new" but produced
    # accidental installs of features the user never asked for; the new policy
    # ("you mark what you want") matches direct user feedback (2026-05-07).
    TUI_RESULTS=()
    local i
    for (( i=0; i<total; i++ )); do
        # v6.16.0 — TK_TUI_LOCK_SELECTION=1: caller pre-locked the selection
        # (e.g. MCP scope lock-screen after the sub-picker). Every row pre-
        # checked, Space is a no-op (handled below), only Tab/s + Enter are
        # active. Required-only pre-check policy is bypassed in this mode.
        if [[ "${TK_TUI_LOCK_SELECTION:-0}" -eq 1 ]]; then
            TUI_RESULTS[$i]=1
        elif [[ "${TUI_REQUIRED[$i]:-0}" -eq 1 ]]; then
            TUI_RESULTS[$i]=1
        else
            TUI_RESULTS[$i]=0
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
                # Space — toggle. Required items are always immutable.
                # Installed items are immutable UNLESS TUI_REINSTALLABLE[i]=1
                # (caller-opt-in for the install↔reinstall cycle).
                # Submit row (FOCUS_IDX == total) is also no-op for space.
                # v6.16.0 — TK_TUI_LOCK_SELECTION=1: ALL rows immutable
                # (selection came pre-locked from a prior sub-picker).
                if [[ "${TK_TUI_LOCK_SELECTION:-0}" -eq 1 ]]; then
                    : # no-op — selection locked
                elif [[ "$FOCUS_IDX" -lt "$total" ]] \
                   && [[ "${TUI_REQUIRED[$FOCUS_IDX]:-0}" -ne 1 ]]; then
                    local _can_toggle=0
                    if [[ "${TUI_INSTALLED[$FOCUS_IDX]:-0}" -ne 1 ]]; then
                        _can_toggle=1
                    elif [[ "${TUI_REINSTALLABLE[$FOCUS_IDX]:-0}" -eq 1 ]]; then
                        _can_toggle=1
                    fi
                    if [[ "$_can_toggle" -eq 1 ]]; then
                        if [[ "${TUI_RESULTS[$FOCUS_IDX]:-0}" -eq 1 ]]; then
                            TUI_RESULTS[$FOCUS_IDX]=0
                        else
                            TUI_RESULTS[$FOCUS_IDX]=1
                        fi
                    fi
                fi
                ;;
            ''|$'\n'|$'\r')
                # Enter — confirm only when focus is on the synthetic Submit row
                # (FOCUS_IDX == total). On any other row it would be too easy to
                # trigger install accidentally while navigating; instead, jump
                # focus down to the Submit row so the next Enter confirms.
                if [[ "$FOCUS_IDX" -eq "$total" ]]; then
                    rc=0
                    break
                else
                    FOCUS_IDX="$total"
                fi
                ;;
            $'\e' | $'\e\e' | $'\e\e\e')
                # Bare Esc (or double/triple Esc) — cancel.
                # _tui_read_key uses `read -rsn2 -t 1` so a bare Esc press
                # normally returns "$'\e'" without the [A/[B suffix. But on
                # macOS Terminal.app + some iTerm2 configs (notably "Esc+ as
                # Meta" / "Send +Esc"), the Esc key emits two or three bytes
                # in quick succession (\e\e or \e\e\e) — fast enough that
                # _tui_read_key's read-ahead window catches them before the
                # 1-second timeout. Without the extra glob arms, those bytes
                # fell through to the `*) ignore` branch and the user reported
                # "Esc does nothing, only Ctrl-C cancels" (2026-05-01).
                rc=1
                break
                ;;
            q|Q)
                # Quit — cancel.
                rc=1
                break
                ;;
            $'\t')
                # Phase 39 TUI-SCOPE-02: per-row scope hotkey. Mirrors the
                # TUI_HEADER_KEY/FN indirection in the catch-all *) below but
                # binds to a dedicated TUI_ROW_KEY (typically Tab byte $'\t')
                # so the caller can wire a per-row mutator alongside the
                # global header toggle (`s` for set-all). Caller-supplied
                # function is invoked with no args; FOCUS_IDX is already a
                # global mutated by ↑/↓ above. Function MUST mutate
                # caller-side state (typically a parallel array) and may
                # also rebuild the row's TUI_LABELS slot so the next
                # _tui_render reflects the new state. No-op when the row
                # is out of bounds (Submit row, CLI-only row) — caller's
                # guard responsibility (see mcp_cycle_row_scope).
                #
                # Tab is ASCII 0x09 — single byte, no multi-byte ambiguity
                # (unlike arrow `\e[A`). Position: BEFORE the catch-all *)
                # so the header-fn dispatch doesn't shadow Tab. Caller opt-in
                # via TUI_ROW_KEY+TUI_ROW_FN; the row key is HARDCODED to Tab
                # in this case-arm — making it configurable would require
                # moving dispatch into the *) arm with a positional check
                # (deferred until D-05 actually needs another byte).
                # MED-02 fix: dropped redundant `"$TUI_ROW_KEY" == $'\t'`
                # inner-gate (case-arm already enforces Tab; the gate was
                # dead code that contradicted its own comment).
                if [[ -n "${TUI_ROW_KEY:-}" && -n "${TUI_ROW_FN:-}" ]]; then
                    "${TUI_ROW_FN}" || true
                fi
                ;;
            *)
                # Header-toggle key (caller-defined, e.g. `s` for MCP scope).
                # Folded into the catch-all so the gate doesn't shadow b|B
                # above. The function is called with no args; it is expected
                # to mutate TUI_HEADER_TEXT (and any caller-side state) so
                # the next _tui_render shows the new value.
                if [[ -n "${TUI_HEADER_KEY:-}" && -n "${TUI_HEADER_FN:-}" ]]; then
                    local _hk_lower="${TUI_HEADER_KEY}"
                    local _hk_upper
                    # Bash 3.2 has no ${var^^}; use tr.
                    _hk_upper=$(printf '%s' "$_hk_lower" | tr '[:lower:]' '[:upper:]' 2>/dev/null || printf '%s' "$_hk_lower")
                    if [[ "$key" == "$_hk_lower" || "$key" == "$_hk_upper" ]]; then
                        "${TUI_HEADER_FN}" || true
                    fi
                fi
                # Unrecognized otherwise — ignore and re-render.
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

# tui_tty_read — visible prompt + read into named variable, immune to caller's
# stderr capture (e.g., install.sh dispatch loop's `( … ) 2>"$stderr_tmp"` D-28).
#
# Why this exists: Bash `read -p "prompt"` writes the prompt string to STDERR
# (not the controlling terminal). When a parent runner redirects stderr to a
# tmpfile to harvest the failure tail (D-28 in install.sh:1066), the prompt
# disappears and the user sees a bare blinking caret with no clue what to
# type. tui_tty_read writes the prompt directly to the TTY device with
# `printf … > "$tty"` so the prompt is visible regardless of how the parent
# wires stderr.
#
# Args:
#   $1 — variable name to assign the answer into (must be a valid Bash
#        identifier; do not pass user-controlled input).
#   $2 — prompt text. Caller is responsible for trailing space (e.g. "Foo? [y/N]: ").
#   $3 — silent flag: "1" = no echo (passwords/API keys), default "0".
#   $4 — TTY override (optional). When non-empty, reads/writes against this path
#        instead of the default. Used by sibling libs that publish their own
#        test seam (e.g. bridges.sh exports TK_BRIDGE_TTY_SRC). Empty/unset
#        falls through to TK_TUI_TTY_SRC, then /dev/tty.
# Return:
#   0 — answer captured (may be empty string if user pressed Enter).
#   1 — TTY unreachable / EOF; caller should treat as fail-closed default.
#       The named variable is left empty in that case.
tui_tty_read() {
    local _varname="$1"
    local _prompt="$2"
    local _silent="${3:-0}"
    local _tty="${4:-${TK_TUI_TTY_SRC:-/dev/tty}}"

    # Defensive: reject non-identifier var names so we cannot get coerced into
    # writing into something like `PATH` if a future caller passes a literal.
    if [[ ! "$_varname" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        return 1
    fi

    # Initialise the target variable to empty so a no-TTY return path leaves a
    # consistent empty string (callers `${var:-default}` it).
    printf -v "$_varname" '%s' ''

    # Resolve where to write the prompt:
    #   1. TK_TUI_PROMPT_SINK (regression-test seam) — write prompt there,
    #      keeping the read path untouched. Lets tests assert prompt visibility
    #      independently of input feeding.
    #   2. Char devices (/dev/tty, /dev/ttyN, /dev/pts/N) — bidirectional;
    #      write prompt to the same path the read consumes.
    #   3. Regular files OR pipes (test seams: TK_BRIDGE_TTY_SRC=tmpfile pre-
    #      loaded with answer; or process substitution `<(printf 'y\n')` which
    #      yields a one-way pipe FD readable only by the consumer) — skip the
    #      prompt write entirely so the answer is neither truncated nor blocked
    #      on a write to a read-only pipe end. Mirrors the v4.7-era semantics
    #      where `read -p` wrote prompts to stderr (not to the path).
    local _prompt_sink="${TK_TUI_PROMPT_SINK:-}"
    if [[ -n "$_prompt_sink" ]]; then
        # `>>` because the sink may accumulate multiple prompts across one test.
        printf '%s' "$_prompt" >> "$_prompt_sink" 2>/dev/null || return 1
    elif [[ -c "$_tty" ]]; then
        printf '%s' "$_prompt" > "$_tty" 2>/dev/null || return 1
    fi
    # Regular file / pipe w/o sink: prompt write deliberately omitted — see above.

    # Indirect read-into-named-variable: `read VAR` reads INTO $VAR; we expand
    # $_varname to get the real var name and bash reads into it. Shellcheck
    # SC2229 flags this as suspicious (it cannot tell the difference between
    # "read into the value of $_varname" and "read into a var named _varname"),
    # so we silence it explicitly. The defensive identifier-regex check at the
    # top of the function bounds the value to a safe Bash name.
    if [[ "$_silent" -eq 1 ]]; then
        # `read -s` echoes nothing; print a newline ourselves for layout parity
        # with the non-silent path (matches the legacy `read -rs` user feel).
        # shellcheck disable=SC2229
        if ! read -rs "$_varname" < "$_tty" 2>/dev/null; then
            # Newline goes to the same destination the prompt did, so test sinks
            # capture the trailing \n too.
            if [[ -n "$_prompt_sink" ]]; then
                printf '\n' >> "$_prompt_sink" 2>/dev/null || true
            elif [[ -c "$_tty" ]]; then
                printf '\n' > "$_tty" 2>/dev/null || true
            fi
            return 1
        fi
        if [[ -n "$_prompt_sink" ]]; then
            printf '\n' >> "$_prompt_sink" 2>/dev/null || true
        elif [[ -c "$_tty" ]]; then
            printf '\n' > "$_tty" 2>/dev/null || true
        fi
    else
        # shellcheck disable=SC2229
        if ! read -r "$_varname" < "$_tty" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

# tui_confirm_prompt — render a single line [y/N] prompt.
# $1 = prompt text (e.g. "Install 4 component(s)? [y/N] ")
# Return: 0 if user typed y/Y; 1 otherwise (default N, EOF, q/Q).
# Reads from < "${TK_TUI_TTY_SRC:-/dev/tty}" — same seam as the main checklist.
tui_confirm_prompt() {
    local prompt_text="${1:-Confirm? [y/N] }"
    local choice=""
    # Use tui_tty_read so the prompt survives parent stderr capture.
    if ! tui_tty_read choice "$prompt_text"; then
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
