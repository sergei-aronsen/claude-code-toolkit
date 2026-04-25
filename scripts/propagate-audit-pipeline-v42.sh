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
# Extracts from the first ^## heading through EOF (skips H1 + intro prose)
# ─────────────────────────────────────────────────
FP_RECHECK_BODY="$(awk 'found || /^## /{found=1; print}' "$FP_RECHECK_SOT")"
OUTPUT_FORMAT_BODY="$(awk 'found || /^## /{found=1; print}' "$OUTPUT_FORMAT_SOT")"

[ -n "$FP_RECHECK_BODY" ]    || { echo "ERROR: empty FP-recheck body extracted" >&2;    exit 1; }
[ -n "$OUTPUT_FORMAT_BODY" ] || { echo "ERROR: empty OUTPUT FORMAT body extracted" >&2; exit 1; }
[[ "$FP_RECHECK_BODY"    == "## "* ]] || { echo "ERROR: FP-recheck body does not start with ##" >&2;    exit 1; }
[[ "$OUTPUT_FORMAT_BODY" == "## "* ]] || { echo "ERROR: OUTPUT FORMAT body does not start with ##" >&2; exit 1; }

# ─────────────────────────────────────────────────
# write_spliced_file() — emit the rewritten file to a given output path
#
# Uses awk to detect line anchors, then a Python3 rewrite script to perform
# the actual multi-block insertions. Python3 is available on all supported
# platforms (macOS 12+ ships it; Linux CI has python3 in PATH).
#
# Arguments:
#   $1 = source file path
#   $2 = destination file path (typically a tempfile)
#   $3 = sc_heading  (SELF-CHECK heading text)
#   $4 = of_heading  (OUTPUT FORMAT heading text)
# ─────────────────────────────────────────────────
write_spliced_file() {
    local src="$1"
    local dst="$2"
    local sc_heading="$3"
    local of_heading="$4"

    # Detect insertion anchors via awk (single-line output, no multi-line issue)
    local existing_selfcheck_line=0
    local existing_selfcheck_num=""
    local existing_reportfmt_line=0
    local selfcheck_end_line=0
    local reportfmt_end_line=0
    local total_lines
    total_lines=$(awk 'END{print NR}' "$src")

    local sc_raw
    sc_raw=$(grep -nE '^## ([0-9]+\.\s*)?SELF-CHECK' "$src" | head -1 || true)
    if [ -n "$sc_raw" ]; then
        existing_selfcheck_line=${sc_raw%%:*}
        existing_selfcheck_num=$(echo "${sc_raw#*:}" | grep -oE '^## [0-9]+' | grep -oE '[0-9]+' | head -1 || true)
    fi

    local rf_raw
    rf_raw=$(grep -nE '^## ([0-9]+\.\s*)?(REPORT FORMAT|OUTPUT FORMAT|ФОРМАТ ОТЧЁТА)' "$src" | head -1 || true)
    if [ -n "$rf_raw" ]; then
        existing_reportfmt_line=${rf_raw%%:*}
    fi

    if [ "$existing_selfcheck_line" -gt 0 ]; then
        selfcheck_end_line=$(awk -v start="$existing_selfcheck_line" '
            /^```/ { infence = !infence }
            NR > start && !infence && (/^## / || /^---$/) { found=1; print NR; exit }
            END { if (!found) print NR + 1 }
        ' "$src")
    fi

    if [ "$existing_reportfmt_line" -gt 0 ]; then
        reportfmt_end_line=$(awk -v start="$existing_reportfmt_line" '
            /^```/ { infence = !infence }
            NR > start && !infence && /^## / { found=1; print NR; exit }
            END { if (!found) print NR + 1 }
        ' "$src")
    fi

    # ── Build the 4 block files in a local temp dir ──
    local block_dir
    block_dir=$(mktemp -d "${TMPDIR:-/tmp}/v42splice.XXXXXX")
    # shellcheck disable=SC2064
    trap "rm -rf '$block_dir'" RETURN

    # Block 1: callout (D-05)
    {
        printf '<!-- v42-splice: callout -->\n'
        printf '<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md\n'
        printf '     Consult this file before reporting any finding. Use /audit-skip to add\n'
        printf '     an entry, /audit-restore to remove one. -->\n'
    } > "$block_dir/callout.txt"

    # Block 2: fp-recheck section (D-06) — heading + sentinel + SOT body
    {
        printf '%s\n' "$sc_heading"
        printf '<!-- v42-splice: fp-recheck-section -->\n'
        printf '\n'
        printf '%s\n' "$FP_RECHECK_BODY"
    } > "$block_dir/fp.txt"

    # Block 3: output-format section (D-07) — heading + sentinel + SOT body
    {
        printf '%s\n' "$of_heading"
        printf '<!-- v42-splice: output-format-section -->\n'
        printf '\n'
        printf '%s\n' "$OUTPUT_FORMAT_BODY"
    } > "$block_dir/of.txt"

    # Block 4: Council Handoff footer (D-08)
    # Em-dash below is U+2014 (0xE2 0x80 0x94) — do NOT replace with hyphen-minus.
    {
        printf '## Council Handoff\n'
        printf '<!-- v42-splice: council-handoff -->\n'
        printf '\n'
        printf 'When the structured report is complete, hand it off to the Supreme Council for\n'
        printf 'peer review. See `commands/audit.md` Phase 5 (Council Pass \xe2\x80\x94 mandatory) for the\n'
        printf 'invocation: `/council audit-review --report <path>`. The Council runs in\n'
        printf 'audit-review mode (see `commands/council.md` `## Modes`). The Council verdict\n'
        printf 'slot in the report is pre-populated with the byte-exact placeholder\n'
        printf '`_pending \xe2\x80\x94 run /council audit-review_` (U+2014 em-dash) and is overwritten by\n'
        printf 'the Council pass.\n'
    } > "$block_dir/ch.txt"

    # ── Python rewrite: insert blocks at computed line anchors ──
    python3 - \
        "$src" "$dst" \
        "$block_dir/callout.txt" \
        "$block_dir/fp.txt" \
        "$block_dir/of.txt" \
        "$block_dir/ch.txt" \
        "$existing_selfcheck_line" \
        "$selfcheck_end_line" \
        "$existing_reportfmt_line" \
        "$reportfmt_end_line" \
        "$total_lines" \
    <<'PYEOF'
import sys

src, dst = sys.argv[1], sys.argv[2]
callout_f, fp_f, of_f, ch_f = sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
sc_start  = int(sys.argv[7])
sc_end    = int(sys.argv[8])
rf_start  = int(sys.argv[9])
rf_end    = int(sys.argv[10])

def read_block(path):
    with open(path, 'r', encoding='utf-8') as fh:
        return fh.read()

callout = read_block(callout_f)
fp_blk  = read_block(fp_f)
of_blk  = read_block(of_f)
ch_blk  = read_block(ch_f)

def ensure_single_trailing_blank(buf):
    """Remove all trailing blank lines then append exactly one blank line."""
    while buf and buf[-1].rstrip('\n') == '':
        buf.pop()
    buf.append('\n')

def append_block(buf, block_text):
    """Ensure exactly one blank line before a block, then append it."""
    ensure_single_trailing_blank(buf)
    buf.append(block_text)
    if not block_text.endswith('\n'):
        buf.append('\n')

with open(src, 'r', encoding='utf-8') as fh:
    lines = fh.readlines()

out = []
has_sc = sc_start > 0
has_rf = rf_start > 0
of_emitted = False
in_skip = False
i = 0  # 0-based index; line number = i+1

while i < len(lines):
    lineno = i + 1  # 1-based

    # Block 1: After the H1 line (line 1), insert callout
    if lineno == 1:
        out.append(lines[i])
        out.append('\n')
        out.append(callout)
        if not callout.endswith('\n'):
            out.append('\n')
        i += 1
        continue

    # Block 2a: Replace existing SELF-CHECK section (skip old heading+body)
    if has_sc and lineno == sc_start:
        append_block(out, fp_blk)
        in_skip = True
        i += 1
        continue

    if in_skip:
        if lineno < sc_end:
            i += 1
            continue
        else:
            in_skip = False
            # sc_end line is the next ## heading — ensure one blank line before it
            ensure_single_trailing_blank(out)
            # Fall through to emit sc_end line normally

    # Block 2b: Insert fp_blk BEFORE report-format heading (no existing SELF-CHECK)
    if not has_sc and has_rf and lineno == rf_start:
        append_block(out, fp_blk)
        ensure_single_trailing_blank(out)
        out.append(lines[i])
        i += 1
        continue

    # Block 3: Insert of_blk AFTER report-format section ends
    if has_rf and lineno == rf_end:
        out.append(lines[i])
        append_block(out, of_blk)
        of_emitted = True
        i += 1
        continue

    out.append(lines[i])
    i += 1

# EOF fallbacks
if not has_sc and not has_rf:
    append_block(out, fp_blk)
    out.append('\n')
    append_block(out, of_blk)
    of_emitted = True

if has_sc and not has_rf and not of_emitted:
    append_block(out, of_blk)
    of_emitted = True

# Block 4: Council Handoff — always last
append_block(out, ch_blk)

with open(dst, 'w', encoding='utf-8') as fh:
    fh.writelines(out)
PYEOF
}

# ─────────────────────────────────────────────────
# insert_blocks() — rewrite a single prompt file in-place
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
    local existing_selfcheck_num=""
    local max_section_num=0

    if grep -qE '^## [0-9]+\.' "$f"; then
        has_numbered_sections=1
        max_section_num=$(grep -oE '^## [0-9]+\.' "$f" | grep -oE '[0-9]+' | sort -n | tail -1)
    fi

    local sc_raw
    sc_raw=$(grep -nE '^## ([0-9]+\.\s*)?SELF-CHECK' "$f" | head -1 || true)
    if [ -n "$sc_raw" ]; then
        existing_selfcheck_num=$(echo "${sc_raw#*:}" | grep -oE '^## [0-9]+' | grep -oE '[0-9]+' | head -1 || true)
    fi

    # ── Section number computation (D-06, D-07, Pitfall 1) ──
    local sc_heading of_heading
    if [ "$has_numbered_sections" -eq 1 ]; then
        local sc_num of_num
        if [ -n "$existing_selfcheck_num" ]; then
            sc_num="$existing_selfcheck_num"
            # of_num must come AFTER any existing numbered section (REPORT FORMAT,
            # ACTIONS, etc.) that follows SELF-CHECK to avoid heading collisions.
            if [ "$max_section_num" -gt "$sc_num" ]; then
                of_num=$((max_section_num + 1))
            else
                of_num=$((sc_num + 1))
            fi
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

    write_spliced_file "$f" "$tmp" "$sc_heading" "$of_heading"

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
