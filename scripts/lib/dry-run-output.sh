#!/bin/bash

# Claude Code Toolkit — Dry-Run Output Library (Phase 11 / UX-01)
# Source this file. Do NOT execute it directly.
# Exposes: dro_init_colors, dro_print_header, dro_print_file, dro_print_total
# Globals: _DRO_G _DRO_C _DRO_Y _DRO_R _DRO_NC (set by dro_init_colors)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            Color gating respects no-color.org: NO_COLOR present (any value, including
#            empty string) disables ANSI. TTY check ([ -t 1 ]) disables ANSI when stdout
#            is not a terminal. Both gates must pass for color to render.
#
# Format target (chezmoi-grade, fixed 44-col label + 6-col count = 80-col friendly):
#   [+ INSTALL]                                  5 files
#     commands/plan.md
#     ...
#   Total: 17 files

# dro_init_colors — sets _DRO_G/_DRO_C/_DRO_Y/_DRO_R/_DRO_NC based on TTY + NO_COLOR.
# No args. Always returns 0. Safe under `set -u` via ${NO_COLOR+x} presence test.
dro_init_colors() {
    # NO_COLOR test per no-color.org: presence (any value) disables color.
    # ${NO_COLOR+x} expands to "x" when NO_COLOR is SET (even if empty string),
    # to "" when NO_COLOR is unset. Safer than ${NO_COLOR:-} which conflates
    # "unset" with "set to empty" — see RESEARCH.md §"NO_COLOR + TTY Detection".
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _DRO_G='\033[0;32m'   # green  — [+ INSTALL]
        _DRO_C='\033[0;36m'   # cyan   — [~ UPDATE]
        _DRO_Y='\033[1;33m'   # yellow — [- SKIP]
        _DRO_R='\033[0;31m'   # red    — [- REMOVE]
        _DRO_NC='\033[0m'
    else
        _DRO_G=''
        _DRO_C=''
        _DRO_Y=''
        _DRO_R=''
        _DRO_NC=''
    fi
}

# dro_print_header — print one section header line with right-aligned count.
# Args: $1=marker (one char: + | - | ~), $2=label (e.g. "INSTALL"), $3=count (integer),
#       $4=color-var-name (one of: _DRO_G | _DRO_C | _DRO_Y | _DRO_R)
# Format: "[<marker> <label>]" left-aligned in 44 cols, count right-aligned in 6 cols, " files" literal.
# Color is applied to the WHOLE line (not interleaved into %-44s) to keep printf padding
# accurate — ANSI bytes don't count as visible chars in the terminal but DO count in
# `%-Ns` width math. See RESEARCH.md Pitfall 6.
dro_print_header() {
    local marker="$1" label="$2" count="$3" color_var="$4"
    local color_val=""
    # Indirect expansion (bash 3.2 compatible): use eval to read $_DRO_G etc.
    eval "color_val=\${$color_var:-}"
    local header_text="[${marker} ${label}]"
    printf '%b%-44s%6d files%b\n' "$color_val" "$header_text" "$count" "${_DRO_NC:-}"
}

# dro_print_file — print one indented file line under a section header.
# Args: $1=filepath (or "filepath  (annotation)")
# Format: "  <filepath>" (2-space indent, no color, no marker).
dro_print_file() {
    local filepath="$1"
    printf '  %s\n' "$filepath"
}

# dro_print_total — print the final total footer.
# Args: $1=total-count
# Format: "Total: <N> files" — exactly matches the existing `^Total:` assertion in
# test-dry-run.sh, so the existing test pass survives the format upgrade.
dro_print_total() {
    local total="$1"
    printf 'Total: %d files\n' "$total"
}
