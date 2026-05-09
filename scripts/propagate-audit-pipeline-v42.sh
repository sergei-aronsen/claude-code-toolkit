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
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force)   FORCE=1;   shift ;;
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

# F-006: SOT body H2 (## Procedure / ## Skipped … / ## Report Path / ## Full
# Report Skeleton …) collides with the outer wrapper H2 (## <N>. SELF-CHECK
# … / ## <N>. OUTPUT FORMAT …) inserted by write_spliced_file. Demote every
# heading in the SOT body by one level (H2→H3, H3→H4, …) so it nests
# semantically under the wrapper instead of breaking out of it. Code-fenced
# regions are skipped — they contain illustrative markdown that must render
# verbatim.
demote_headings_one_level() {
    awk '
        /^```/ { infence = !infence; print; next }
        !infence && /^#+ / { print "#" $0; next }
        { print }
    '
}
FP_RECHECK_BODY="$(printf '%s\n' "$FP_RECHECK_BODY" | demote_headings_one_level)"
OUTPUT_FORMAT_BODY="$(printf '%s\n' "$OUTPUT_FORMAT_BODY" | demote_headings_one_level)"

[[ "$FP_RECHECK_BODY"    == "### "* ]] || { echo "ERROR: FP-recheck body does not start with ### after demote" >&2;    exit 1; }
[[ "$OUTPUT_FORMAT_BODY" == "### "* ]] || { echo "ERROR: OUTPUT FORMAT body does not start with ### after demote" >&2; exit 1; }

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
    # Audit M6: previous trap used single-quoted '$block_dir' which fails when
    # TMPDIR contains a literal `'` (broken trap registration → leaked tempdir
    # on every function return). Use printf '%q' to produce a shell-safe
    # representation regardless of $block_dir contents (matches uninstall.sh:312).
    local _quoted_block_dir
    _quoted_block_dir=$(printf '%q' "$block_dir")
    # shellcheck disable=SC2064
    trap "rm -rf $_quoted_block_dir" RETURN

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
# strip_splice_regions() — remove all 4 splice blocks from a previously-spliced
# file IN-PLACE. Used by --force mode so re-splicing is possible after SOT
# updates. Idempotent on virgin files (no sentinels → no-op).
#
# Stripping logic:
#   - callout: remove `<!-- v42-splice: callout -->` line + following HTML
#     comment block (`<!-- Audit exceptions allowlist...-->`).
#   - fp-recheck-section: walk back from sentinel to the parent `## ` heading,
#     forward through next `## ` (top-level) or EOF. Drop the whole region.
#   - output-format-section: same shape.
#   - council-handoff: walk back to `## Council Handoff` heading, forward to
#     EOF (always last block).
# ─────────────────────────────────────────────────
strip_splice_regions() {
    local f="$1"
    python3 - "$f" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as fh:
    lines = fh.readlines()

def find_line(needle):
    for i, ln in enumerate(lines):
        if needle in ln:
            return i
    return -1

def parent_h2(idx):
    """Walk back from idx (inclusive) to the nearest line starting with '## '."""
    j = idx
    while j >= 0 and not lines[j].startswith('## '):
        j -= 1
    return j

# Region boundaries are derived from the FOUR splice sentinels themselves.
# The SOT body inside fp-recheck and output-format regions contains its own
# '## ' headings (e.g. '## Procedure', '## Skipped (FP recheck) Entry Format'),
# so we cannot use "next ## heading" as a boundary. Instead we use the next
# splice region's parent_h2 line as the END of the current region.
#
# Layout in a properly-spliced file:
#
#   <H1>
#   <!-- v42-splice: callout -->
#   <!-- Audit exceptions allowlist: ... -->
#
#   ... outer prompt content ...
#
#   ## <N>. SELF-CHECK (FP Recheck — 6-Step Procedure)   ← parent of fp sentinel
#   <!-- v42-splice: fp-recheck-section -->
#
#   ## Procedure
#   ...SOT body (contains '## ' headings)...
#
#   ## <N+1>. OUTPUT FORMAT (...)                         ← parent of of sentinel
#   <!-- v42-splice: output-format-section -->
#
#   ## Report Path
#   ...SOT body...
#
#   ## Council Handoff                                    ← parent of council sentinel
#   <!-- v42-splice: council-handoff -->
#
#   ...footer text...EOF

callout_idx = find_line('<!-- v42-splice: callout -->')
fp_idx      = find_line('<!-- v42-splice: fp-recheck-section -->')
of_idx      = find_line('<!-- v42-splice: output-format-section -->')
ch_idx      = find_line('<!-- v42-splice: council-handoff -->')

ranges = []  # list of (start, end) line-index pairs to delete (end exclusive)

# ─── callout: sentinel + immediately-following HTML comment block ───
if callout_idx >= 0:
    end = callout_idx + 1
    if end < len(lines) and lines[end].startswith('<!--'):
        while end < len(lines):
            end += 1
            if end > 0 and '-->' in lines[end - 1]:
                break
    # Eat one trailing blank line if present
    if end < len(lines) and lines[end].strip() == '':
        end += 1
    ranges.append((callout_idx, end))

# ─── fp-recheck region: parent_h2(fp) → parent_h2(of) - 1 ───
if fp_idx >= 0:
    start = parent_h2(fp_idx)
    if of_idx > fp_idx:
        end = parent_h2(of_idx)
    elif ch_idx > fp_idx:
        end = parent_h2(ch_idx)
    else:
        end = len(lines)
    if start >= 0 and end > start:
        ranges.append((start, end))

# ─── output-format region: parent_h2(of) → parent_h2(council) - 1 ───
if of_idx >= 0:
    start = parent_h2(of_idx)
    if ch_idx > of_idx:
        end = parent_h2(ch_idx)
    else:
        end = len(lines)
    if start >= 0 and end > start:
        ranges.append((start, end))

# ─── council-handoff region: parent_h2(council) → EOF ───
if ch_idx >= 0:
    start = parent_h2(ch_idx)
    end = len(lines)
    if start >= 0:
        ranges.append((start, end))

# Apply deletions in reverse-line order (so earlier indices stay valid)
ranges.sort(key=lambda r: r[0], reverse=True)
for start, end in ranges:
    del lines[start:end]

# Collapse multiple consecutive blank lines into one
out = []
prev_blank = False
for ln in lines:
    is_blank = ln.strip() == ''
    if is_blank and prev_blank:
        continue
    out.append(ln)
    prev_blank = is_blank

# Trim trailing blanks; ensure exactly one trailing newline
while out and out[-1].strip() == '':
    out.pop()
out.append('\n')

with open(path, 'w', encoding='utf-8') as fh:
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
    # Audit M3: previous trap single-quoted '$tmp' which breaks when the
    # path contains a literal `'`. Use printf '%q' to produce a shell-safe
    # representation (matches the line-128 pattern in this same file).
    # Audit S-LOW-2 (2026-04-30 deep): also cover EXIT so a `set -e`
    # script-abort between mktemp and the trap-clear at line 359 cleans up
    # the tempfile instead of leaking it.
    local _quoted_tmp
    _quoted_tmp=$(printf '%q' "$tmp")
    # shellcheck disable=SC2064
    trap "rm -f $_quoted_tmp" INT TERM EXIT

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
    # Audit S-LOW-2: clear all signals we installed for this tempfile.
    trap - INT TERM EXIT
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
        if [ "$FORCE" -eq 1 ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "[dry-run] would re-splice (force): ${f#"$REPO_ROOT/"}"
                SPLICED=$((SPLICED + 1))
                continue
            fi
            strip_splice_regions "$f"
            # Recompute sentinel count after strip — must be 0 for normal splice path
            total=$(grep -cF '<!-- v42-splice:' "$f" 2>/dev/null || true)
            if [ "$total" -ne 0 ]; then
                echo "ERROR: strip left $total sentinels behind: ${f#"$REPO_ROOT/"}" >&2
                ERRORS=$((ERRORS + 1))
                continue
            fi
            # Fall through to normal splice path below
        else
            echo "[skip] already-spliced: ${f#"$REPO_ROOT/"}"
            ALREADY_SPLICED=$((ALREADY_SPLICED + 1))
            continue
        fi
    fi
    if [ "$total" -gt 0 ] && [ "$total" -lt 4 ]; then
        if [ "$FORCE" -eq 1 ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "[dry-run] would strip+splice (force, partial $total/4): ${f#"$REPO_ROOT/"}"
                SPLICED=$((SPLICED + 1))
                continue
            fi
            strip_splice_regions "$f"
            total=$(grep -cF '<!-- v42-splice:' "$f" 2>/dev/null || true)
            if [ "$total" -ne 0 ]; then
                echo "ERROR: strip left $total sentinels behind: ${f#"$REPO_ROOT/"}" >&2
                ERRORS=$((ERRORS + 1))
                continue
            fi
        else
            echo "ERROR: partial-splice ($total/4 sentinels): ${f#"$REPO_ROOT/"}" >&2
            ERRORS=$((ERRORS + 1))
            continue
        fi
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
