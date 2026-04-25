#!/bin/bash
# scripts/propagate-audit-pipeline-v42.sh
# Fan-out v4.2 audit pipeline contracts to all 49 framework prompt files.
#
# Inserts four sentinel-tagged blocks per file:
#   1. Top-of-file allowlist callout (HTML comment)
#   2. 6-step FP-recheck SELF-CHECK section (body from components/audit-fp-recheck.md)
#   3. Structured OUTPUT FORMAT section (body from components/audit-output-format.md)
#   4. Council Handoff footer with byte-exact slot string
#
# Idempotent: re-running produces zero diff. Uses <!-- v42-splice: ... --> sentinels.
#
# Usage: bash scripts/propagate-audit-pipeline-v42.sh [--dry-run]
#        SPLICE_TEMPLATES_DIR=/path/to/templates bash scripts/propagate-audit-pipeline-v42.sh
# Exit:  0 = all files processed; 1 = missing SOT, partial-splice, or other error

set -euo pipefail

# ─────────────────────────────────────────────────
# CLI flag parsing
# ─────────────────────────────────────────────────
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    esac
done

# ─────────────────────────────────────────────────
# Path resolution
# ─────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FP_RECHECK_SOT="$REPO_ROOT/components/audit-fp-recheck.md"
OUTPUT_FORMAT_SOT="$REPO_ROOT/components/audit-output-format.md"
TEMPLATES_ROOT="${SPLICE_TEMPLATES_DIR:-$REPO_ROOT/templates}"

# ─────────────────────────────────────────────────
# SOT guards (D-02, D-17)
# ─────────────────────────────────────────────────
[ -f "$FP_RECHECK_SOT" ]    || { echo "ERROR: SOT missing: $FP_RECHECK_SOT" >&2;    exit 1; }
[ -f "$OUTPUT_FORMAT_SOT" ] || { echo "ERROR: SOT missing: $OUTPUT_FORMAT_SOT" >&2; exit 1; }
[ -d "$TEMPLATES_ROOT" ]    || { echo "ERROR: templates dir missing: $TEMPLATES_ROOT" >&2; exit 1; }

# ─────────────────────────────────────────────────
# SOT body extraction (D-02) — run once before per-file loop
# ─────────────────────────────────────────────────
FP_RECHECK_BODY="$(awk 'found || /^## /{found=1; print}' "$FP_RECHECK_SOT")"
OUTPUT_FORMAT_BODY="$(awk 'found || /^## /{found=1; print}' "$OUTPUT_FORMAT_SOT")"

[ -n "$FP_RECHECK_BODY" ]    || { echo "ERROR: empty FP-recheck body extracted" >&2;    exit 1; }
[ -n "$OUTPUT_FORMAT_BODY" ] || { echo "ERROR: empty OUTPUT FORMAT body extracted" >&2; exit 1; }
[[ "$FP_RECHECK_BODY"    == "## "* ]] || { echo "ERROR: FP-recheck body does not start with ##" >&2;    exit 1; }
[[ "$OUTPUT_FORMAT_BODY" == "## "* ]] || { echo "ERROR: OUTPUT FORMAT body does not start with ##" >&2; exit 1; }

# ─────────────────────────────────────────────────
# insert_blocks() — rewrite a single file with 4 splice blocks
# Arguments: $1 = path to prompt file
# ─────────────────────────────────────────────────
insert_blocks() {
    local f="$1"
    local tmp
    tmp=$(mktemp "${f}.XXXXXX")
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" INT TERM

    # ── Shape detection (numbered vs unnumbered) ──
    local has_numbered_sections=0
    local existing_selfcheck_line=0
    local existing_selfcheck_num=""
    local max_section_num=0
    local existing_reportfmt_line=0

    if grep -qE '^## [0-9]+\.' "$f"; then
        has_numbered_sections=1
        max_section_num=$(grep -oE '^## [0-9]+\.' "$f" | grep -oE '[0-9]+' | sort -n | tail -1)
    fi

    # Find existing SELF-CHECK heading line + number (if any)
    local sc_line_raw
    sc_line_raw=$(grep -nE '^## ([0-9]+\.\s*)?SELF-CHECK' "$f" | head -1 || true)
    if [ -n "$sc_line_raw" ]; then
        existing_selfcheck_line=${sc_line_raw%%:*}
        existing_selfcheck_num=$(echo "${sc_line_raw#*:}" | grep -oE '^## [0-9]+' | grep -oE '[0-9]+' | head -1 || true)
    fi

    # Find existing REPORT FORMAT / OUTPUT FORMAT heading line (any numeric prefix)
    local rf_line_raw
    rf_line_raw=$(grep -nE '^## ([0-9]+\.\s*)?(REPORT FORMAT|OUTPUT FORMAT|ФОРМАТ ОТЧЁТА)' "$f" | head -1 || true)
    if [ -n "$rf_line_raw" ]; then
        existing_reportfmt_line=${rf_line_raw%%:*}
    fi

    # ── Section number computation (D-06, D-07, Pitfall 1) ──
    local sc_heading="" of_heading=""
    if [ "$has_numbered_sections" -eq 1 ]; then
        local sc_num of_num
        if [ -n "$existing_selfcheck_num" ]; then
            sc_num="$existing_selfcheck_num"
            of_num=$((sc_num + 1))
        else
            sc_num=$((max_section_num + 1))
            of_num=$((sc_num + 1))
        fi
        sc_heading="## ${sc_num}. SELF-CHECK (FP Recheck — 6-Step Procedure)"
        of_heading="## ${of_num}. OUTPUT FORMAT (Structured Report Schema — Phase 14)"
    else
        sc_heading="## SELF-CHECK (FP Recheck — 6-Step Procedure)"
        of_heading="## OUTPUT FORMAT (Structured Report Schema — Phase 14)"
    fi

    # ── Build the 4 block payloads ──
    local callout_block fp_block of_block ch_block

    # Block 1: top-of-file allowlist callout (D-05)
    callout_block=$(printf '%s\n%s\n%s\n%s' \
        '<!-- v42-splice: callout -->' \
        '<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md' \
        '     Consult this file before reporting any finding. Use /audit-skip to add' \
        '     an entry, /audit-restore to remove one. -->')

    # Block 2: SELF-CHECK section (D-06) — heading + sentinel + SOT body
    fp_block=$(printf '%s\n<!-- v42-splice: fp-recheck-section -->\n\n%s' \
        "$sc_heading" "$FP_RECHECK_BODY")

    # Block 3: OUTPUT FORMAT section (D-07) — heading + sentinel + SOT body
    of_block=$(printf '%s\n<!-- v42-splice: output-format-section -->\n\n%s' \
        "$of_heading" "$OUTPUT_FORMAT_BODY")

    # Block 4: Council Handoff footer (D-08) — byte-exact em-dash U+2014
    # The em-dash in the slot string below is U+2014 (0xE2 0x80 0x94).
    # DO NOT replace with hyphen-minus or en-dash.
    ch_block=$(printf '%s\n%s\n\n%s\n%s\n%s\n%s\n%s' \
        '## Council Handoff' \
        '<!-- v42-splice: council-handoff -->' \
        'When the structured report is complete, hand it off to the Supreme Council for' \
        'peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the' \
        'invocation: `/council audit-review --report <path>`. The Council runs in' \
        'audit-review mode (see `commands/council.md` `## Modes`). The Council verdict' \
        'slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.')

    # ── Compute section end lines for awk pass ──
    local selfcheck_end_line=0
    if [ "$existing_selfcheck_line" -gt 0 ]; then
        selfcheck_end_line=$(awk -v start="$existing_selfcheck_line" '
            NR > start && (/^## / || /^---$/) { print NR; exit }
            END { if (!found) print NR + 1 }
        ' "$f")
    fi

    local reportfmt_end_line=0
    if [ "$existing_reportfmt_line" -gt 0 ]; then
        reportfmt_end_line=$(awk -v start="$existing_reportfmt_line" '
            NR > start && /^## / { print NR; exit }
            END { if (!found) print NR + 1 }
        ' "$f")
    fi

    # ── Single awk pass: emit rewritten file with 4 insertions ──
    awk \
        -v callout_block="$callout_block" \
        -v fp_block="$fp_block" \
        -v of_block="$of_block" \
        -v ch_block="$ch_block" \
        -v sc_start="$existing_selfcheck_line" \
        -v sc_end="$selfcheck_end_line" \
        -v rf_start="$existing_reportfmt_line" \
        -v rf_end="$reportfmt_end_line" \
        -v has_sc=0 \
        -v has_rf=0 \
        -v has_of=0 \
    '
    BEGIN {
        in_skip = 0
        of_emitted = 0
        has_sc = (sc_start + 0 > 0)
        has_rf = (rf_start + 0 > 0)
    }

    # Block 1: callout — insert after H1 (NR == 1)
    NR == 1 {
        print
        print ""
        print callout_block
        next
    }

    # Block 2a: replace existing SELF-CHECK section
    has_sc && NR == sc_start {
        print ""
        print fp_block
        print ""
        in_skip = 1
        next
    }
    in_skip && NR < sc_end { next }
    in_skip && NR >= sc_end { in_skip = 0 }

    # Block 2b: insert fp_block BEFORE the report-format heading (when no existing SELF-CHECK)
    !has_sc && has_rf && NR == rf_start {
        print ""
        print fp_block
        print ""
        print
        next
    }

    # Block 3: insert of_block AFTER the report-format section ends
    has_rf && NR == rf_end {
        print
        print ""
        print of_block
        print ""
        of_emitted = 1
        next
    }

    { print }

    END {
        # Neither section existed: append fp + of at EOF
        if (!has_sc && !has_rf) {
            print ""
            print fp_block
            print ""
            print of_block
            print ""
            of_emitted = 1
        }
        # SELF-CHECK existed but no REPORT FORMAT: append of_block
        if (has_sc && !has_rf && !of_emitted) {
            print ""
            print of_block
            print ""
            of_emitted = 1
        }
        # Block 4: Council Handoff — always last
        print ""
        print ch_block
    }
    ' "$f" > "$tmp"

    # ── Post-write sanity: tempfile must contain all 4 sentinels ──
    local tmp_sentinels
    tmp_sentinels=$(grep -cF '<!-- v42-splice:' "$tmp" || true)
    if [ "$tmp_sentinels" -ne 4 ]; then
        echo "ERROR: post-splice tempfile has $tmp_sentinels/4 sentinels: $f" >&2
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$f"
    trap - INT TERM
}

# ─────────────────────────────────────────────────
# Per-file loop
# ─────────────────────────────────────────────────
SPLICED=0
ALREADY_SPLICED=0
ERRORS=0

while IFS= read -r f; do
    # D-09: sentinel detection
    total=$(grep -cF '<!-- v42-splice:' "$f" 2>/dev/null || true)

    if [ "$total" -eq 4 ]; then
        echo "[skip] already-spliced: ${f#"$REPO_ROOT/"}"
        ALREADY_SPLICED=$((ALREADY_SPLICED + 1))
        continue
    fi
    if [ "$total" -gt 0 ] && [ "$total" -lt 4 ]; then
        echo "ERROR: partial-splice ($total/4 sentinels): ${f#"$REPO_ROOT/"}" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Pitfall 2: CRLF guard
    if grep -qU $'\r' "$f" 2>/dev/null; then
        echo "ERROR: CRLF detected in ${f#"$REPO_ROOT/"}" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would splice: ${f#"$REPO_ROOT/"}"
        SPLICED=$((SPLICED + 1))
        continue
    fi

    if insert_blocks "$f"; then
        SPLICED=$((SPLICED + 1))
        echo "[spliced] ${f#"$REPO_ROOT/"}"
    else
        ERRORS=$((ERRORS + 1))
    fi

done < <(find "$TEMPLATES_ROOT" -path '*/prompts/*.md' \
    \( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o \
       -name 'PERFORMANCE_AUDIT.md' -o -name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
       -name 'POSTGRES_PERFORMANCE_AUDIT.md' -o -name 'DEPLOY_CHECKLIST.md' -o \
       -name 'DESIGN_REVIEW.md' \) | sort)

printf 'Processed %d files: %d spliced, %d already-spliced, %d skipped (errors)\n' \
    "$((SPLICED + ALREADY_SPLICED + ERRORS))" "$SPLICED" "$ALREADY_SPLICED" "$ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
