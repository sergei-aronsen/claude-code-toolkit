# Phase 16: Template Propagation — 49 Prompt Files - Research

**Researched:** 2026-04-26
**Domain:** Bash splice scripting, Makefile/CI gate extension, 49 Markdown prompt files
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- D-01: Single Bash script `scripts/propagate-audit-pipeline-v42.sh`; reads components at run time
- D-02: Components are SOT; script is downstream consumer; never duplicates bodies
- D-03: Deterministic order (`find templates -path "*/prompts/*.md" | sort`); atomic rewrite via tempfile + mv
- D-04: Script lives in `scripts/` (not tests, not components)
- D-05: Top-of-file callout = HTML comment, 2-3 lines, references `.claude/rules/audit-exceptions.md`
- D-06: SELF-CHECK section: replace body of existing `## NN. SELF-CHECK` (preserve NN), or append above "report format" section if none exists
- D-07: OUTPUT FORMAT appended at file bottom, BELOW any existing report-format section
- D-08: Council Handoff footer = LAST H2 section; quotes byte-exact slot string `_pending — run /council audit-review_` (em-dash U+2014)
- D-09: 4 sentinel comments per file (`<!-- v42-splice: ... -->`); 4 = full splice; 1-3 = partial-splice error
- D-10: Script writes summary: `Processed N files: M spliced, K already-spliced, P skipped (errors)`
- D-11: Spliced blocks ship in English; surrounding prose untouched
- D-12: Script touches ONLY the 4 insertion points — no whole-file regex
- D-13: Extend Makefile `validate` target with `grep -F 'Council handoff'` + `grep -F '1. **Read context**'`
- D-14: Mirror same gates in `.github/workflows/quality.yml` `validate-templates` job
- D-15: New Makefile Test 20 — runs splice script twice in scratch dir, asserts idempotency via `diff -r`
- D-16: No new `components/*.md` SOT in Phase 16
- D-17: Script references components by relative path from repo root; fails fast if missing

### Claude's Discretion

- Exact wording of top-of-file HTML callout (D-05): 2-3 lines, reference `.claude/rules/audit-exceptions.md` by full relative path, mention auditor must consult before reporting
- Exact wording of Council handoff footer (D-08): quote byte-exact slot string, link to `commands/audit.md` Phase 5 and `commands/council.md` `## Modes`
- Whether to use `awk`, `sed`, or pure Bash for block insertion
- Sentinel comment text format: `<!-- v42-splice: <block-name> -->` (D-09 suggests this namespace)

### Deferred Ideas (OUT OF SCOPE)

- Localizing spliced contract blocks into Russian/Spanish/Japanese
- Auto-running splice script in CI on every PR touching `components/audit-*.md`
- Per-framework custom Council handoff footers referencing framework-specific commands
- Replacing existing audit prompt content with v4.2 rewrite
- Versioned splice scripts for future migrations (`propagate-audit-pipeline-v43.sh`)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEMPLATE-01 | All 49 prompt files updated with: (a) callout, (b) 6-step SELF-CHECK, (c) structured OUTPUT FORMAT, (d) Council handoff footer | File survey confirms 49 files exist; insertion point analysis completed |
| TEMPLATE-02 | Existing language preserved — no translation drift | All 49 files are English-only; script touches only 4 insertion points (D-12) |
| TEMPLATE-03 | `make validate` + CI asserts `Council handoff` and `1. **Read context**` markers | Makefile lines 115-134 and quality.yml lines 44-68 identified for extension |
</phase_requirements>

---

## Domain Overview

Phase 16 implements a single idempotent Bash splice script that walks 49 Markdown prompt files and inserts four blocks into each, extending two CI gates, and adding one regression test.

**File count confirmed:** `find templates -path '*/prompts/*.md' | sort` returns exactly 49 files across 7 frameworks (base, laravel, rails, nextjs, nodejs, python, go) × 7 prompt types (SECURITY_AUDIT, CODE_REVIEW, PERFORMANCE_AUDIT, MYSQL_PERFORMANCE_AUDIT, POSTGRES_PERFORMANCE_AUDIT, DEPLOY_CHECKLIST, DESIGN_REVIEW). [VERIFIED: filesystem scan]

**No `templates/global/prompts/` directory exists** — the `find` pattern `templates/*/prompts/*.md` naturally excludes global. [VERIFIED: filesystem scan]

---

## Existing Patterns (with file:line references)

### SOT Components — Splice Bodies

`components/audit-fp-recheck.md` [VERIFIED: file read]
- Line 1: H1 title (skip in splice — copy from H2 `## Procedure` onwards)
- Lines 3-4: intro paragraph (skip)
- Line 6: `## Procedure` — first H2; this is the splice start line
- Lines 8-16: 6-step ordered list with exact labels `1. **Read context**` ... `6. **Severity sanity check**`
- Line 22: `## Skipped (FP recheck) Entry Format` — H2 with table
- Line 41: `## When a Finding Survives All Six Steps` — H2
- Line 44: `## Anti-Patterns` — H2
- Last line: 49. No trailing blank line.
- markdownlint: clean (verified, 0 errors)

`components/audit-output-format.md` [VERIFIED: file read]
- Line 1: H1 title (skip in splice)
- Lines 3-4: intro paragraph (skip)
- Line 6: `## Report Path` — first H2; splice start
- Contains: `## Type Slug to Prompt File Map`, `## YAML Frontmatter`, `## Section Order (Fixed)`, `## Summary Section`, `## Finding Entry Schema`, `## Verbatim Code Block (AUDIT-03)`, `## Skipped (allowlist) Section`, `## Skipped (FP recheck) Section`, `## Council Verdict Slot (handoff to Phase 15)`, `## Full Report Skeleton`
- markdownlint: clean (verified, 0 errors)

**Splice body extraction:** In the script, read each component file fully; extract from the first `## ` heading through EOF. In Bash: `awk 'found || /^## /{found=1; print}' components/audit-fp-recheck.md`.

### Existing SELF-CHECK Sections — Pre-splice State

Survey of `grep -n "^## [0-9]*\. SELF-CHECK"` across all 49 files: [VERIFIED: filesystem scan]

**Has SELF-CHECK (28 files):**
- `CODE_REVIEW.md` × 7 frameworks: `## 7. SELF-CHECK` (base), `## 7. SELF-CHECK` (laravel), `## 6. SELF-CHECK` (nextjs), etc. Section number varies per file.
- `DEPLOY_CHECKLIST.md` × 7 frameworks: all have SELF-CHECK
- `PERFORMANCE_AUDIT.md` × 7 frameworks: all have SELF-CHECK (e.g., laravel `## 6. SELF-CHECK` at line 671)
- `SECURITY_AUDIT.md` — base: `## 11. SELF-CHECK` (line 440); laravel: `## 13. SELF-CHECK` (line 822); nextjs: `## 11. SELF-CHECK` (line 889)

**No SELF-CHECK (21 files):**
- `DESIGN_REVIEW.md` × 7 frameworks — no numbered sections at all; uses emoji headings (`## 🎯 Scope`)
- `MYSQL_PERFORMANCE_AUDIT.md` × 7 frameworks
- `POSTGRES_PERFORMANCE_AUDIT.md` × 7 frameworks

**Existing SELF-CHECK body is a 4-row table** (e.g., base/SECURITY_AUDIT.md line 441-450), NOT the 6-step procedure. The splice replaces this table body with the SOT procedure body (D-06). The heading number NN is preserved.

### Existing REPORT FORMAT Sections — Pre-splice State

**Has REPORT FORMAT (35 files):**
- `SECURITY_AUDIT.md`, `CODE_REVIEW.md`, `DEPLOY_CHECKLIST.md`, `PERFORMANCE_AUDIT.md` across all 7 frameworks — all have existing report format sections
- e.g., base/SECURITY_AUDIT.md: `## 12. REPORT FORMAT` (line 453); laravel/SECURITY_AUDIT.md: `## 14. REPORT FORMAT` (line 835)
- `CODE_REVIEW.md` base: report template is embedded inline within `## 8. REPORT FORMAT` (line 190)

**No REPORT FORMAT (14 files):**
- `DESIGN_REVIEW.md` × 7 — has `## 📝 Report Template` (non-numbered, emoji heading)
- `MYSQL_PERFORMANCE_AUDIT.md` × 7
- `POSTGRES_PERFORMANCE_AUDIT.md` × 7

Per D-07: OUTPUT FORMAT block appended BELOW any existing format section. For files with no format section, appended at end of file.

### Section Numbering Analysis

The script must compute NN (the next section number) for:
1. The replacement SELF-CHECK heading `## NN. SELF-CHECK (FP Recheck — 6-Step Procedure)` — use the existing number when replacing; assign next integer when appending.
2. The OUTPUT FORMAT heading `## NN+1. OUTPUT FORMAT (Structured Report Schema — Phase 14)`.
3. The Council Handoff heading (last H2, no number required by D-08).

**Highest existing section numbers seen:**
- base/SECURITY_AUDIT.md ends at `## 13. ACTIONS` (line 488)
- laravel/SECURITY_AUDIT.md ends at `## 15. ACTIONS` (line 877)
- base/MYSQL_PERFORMANCE_AUDIT.md ends at `## 9. Migration Safety`
- base/POSTGRES_PERFORMANCE_AUDIT.md ends at `## 11. Migration Safety`
- base/DESIGN_REVIEW.md — no numbered sections

For DESIGN_REVIEW files: since there are no numbered sections, SELF-CHECK and OUTPUT FORMAT must be appended without numeric prefixes, or with `## SELF-CHECK (FP Recheck — 6-Step Procedure)` (unnumbered). The planner must lock this edge case — see Open Questions.

### Makefile Validate Target — Current State

`Makefile` lines 115-134 [VERIFIED: file read]:

```make
validate:
    @ERRORS=0; \
    for f in $$(find templates -path '*/prompts/*.md' \( \
        -name 'PERFORMANCE_AUDIT.md' -o \
        -name 'CODE_REVIEW.md' -o \
        -name 'DEPLOY_CHECKLIST.md' \)); do \
        if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then ...
        if ! grep -qE "САМОПРОВЕРКА|SELF-CHECK" "$$f" 2>/dev/null; then ...
    done
```

**Scope gap:** Only 3 of 7 prompt types are checked. `SECURITY_AUDIT.md`, `DESIGN_REVIEW.md`, `MYSQL_PERFORMANCE_AUDIT.md`, `POSTGRES_PERFORMANCE_AUDIT.md` are not in the Makefile loop.

**D-13 extension:** Add two more `grep -F` checks inside the SAME loop, and either expand the `-name` filter to cover all 7 prompt types or add a separate loop for the new markers. Since post-splice ALL 49 files will carry the new markers, the simplest approach is to extend the find to cover `'*.md'` (all prompt files) for the new marker checks, OR add an additional loop over all 49 files just for the two new greps.

### quality.yml validate-templates — Current State

`.github/workflows/quality.yml` lines 44-68 [VERIFIED: file read]:

```yaml
for f in templates/**/SECURITY_AUDIT.md templates/**/PERFORMANCE_AUDIT.md \
         templates/**/CODE_REVIEW.md templates/**/DEPLOY_CHECKLIST.md; do
  grep -q "QUICK CHECK" "$f"
  grep -q "САМОПРОВЕРКА\|SELF-CHECK" "$f"
  grep -q "ФОРМАТ ОТЧЁТА\|OUTPUT FORMAT" "$f"
done
```

**Scope:** 4 of 7 prompt types (adds SECURITY_AUDIT over Makefile). Missing: DESIGN_REVIEW, MYSQL_PERFORMANCE_AUDIT, POSTGRES_PERFORMANCE_AUDIT.

**D-14 extension:** Add two greps for `Council handoff` and `1. **Read context**` to the existing per-file body. Also expand the glob to cover all 7 prompt types (add `templates/**/DESIGN_REVIEW.md templates/**/MYSQL_PERFORMANCE_AUDIT.md templates/**/POSTGRES_PERFORMANCE_AUDIT.md`).

### Test Scaffold Analog — test-audit-pipeline.sh

`scripts/tests/test-audit-pipeline.sh` [VERIFIED: file read]:
- Line 20: `SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-audit-pipeline.XXXXXX")`
- Line 21: `trap 'rm -rf "$SCRATCH"' EXIT`
- Lines 25-26: `report_pass()`/`report_fail()` accumulator idiom
- Lines 488-493: summary + `exit 1` if any failures

`scripts/tests/test-council-audit-review.sh` [VERIFIED: file read]:
- Line 24: mktemp scratch + trap
- Lines 326-330: `cp "$FIXTURE_REPORT" "$SCRATCH/report.md"` then diff pre/post — exact pattern for Test 20 idempotency check

**Test 20 structure:** Create scratch dir; copy `templates/` into scratch; run splice script; run splice script again; assert `diff -r run1/ run2/` is empty. Alternatively: run once on scratch copy, run again on same copy; `git diff --stat` (zero lines) or `diff -r original_copy/ scratch_after_second_run/`.

### Atomic Tempfile+mv Pattern (Shell)

From `scripts/update-claude.sh` lines 840, 896 [VERIFIED: file read]:

```bash
CLAUDE_MD_TMP=$(mktemp)
# ... write to CLAUDE_MD_TMP ...
mv "$CLAUDE_MD_TMP" "$CLAUDE_MD"
```

From `scripts/council/brain.py` lines 299-317 [VERIFIED: file read]:

```python
with tempfile.NamedTemporaryFile(mode="w", delete=False,
        dir=str(parent), suffix=".tmp", prefix=".council_") as tmp:
    tmp.write(content)
    tmp_path = tmp.name
os.replace(tmp_path, str(path))
```

**Shell analog for the splice script:**

```bash
tmp=$(mktemp "${dest}.XXXXXX")
# write new content to $tmp
mv "$tmp" "$dest"
```

Use `"${dest}.XXXXXX"` (tempfile in same directory) to guarantee same filesystem for atomic rename.

---

## Implementation Approach

### Script Skeleton

```bash
#!/bin/bash
# scripts/propagate-audit-pipeline-v42.sh
# Fan-out v4.2 audit pipeline contracts to all 49 prompt files.
# Usage: bash scripts/propagate-audit-pipeline-v42.sh [--dry-run]
# Exit: 0 = success, 1 = partial-splice error or missing component
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FP_RECHECK_SOT="$REPO_ROOT/components/audit-fp-recheck.md"
OUTPUT_FORMAT_SOT="$REPO_ROOT/components/audit-output-format.md"

# Phase 1: Guard — SOT components must exist
[ -f "$FP_RECHECK_SOT" ] || { echo "ERROR: $FP_RECHECK_SOT missing" >&2; exit 1; }
[ -f "$OUTPUT_FORMAT_SOT" ] || { echo "ERROR: $OUTPUT_FORMAT_SOT missing" >&2; exit 1; }

# Phase 2: Extract splice bodies (from first ## heading to EOF)
FP_RECHECK_BODY=$(awk 'found || /^## /{found=1; print}' "$FP_RECHECK_SOT")
OUTPUT_FORMAT_BODY=$(awk 'found || /^## /{found=1; print}' "$OUTPUT_FORMAT_SOT")

SPLICED=0; ALREADY_SPLICED=0; ERRORS=0

# Phase 3: Walk files deterministically
while IFS= read -r f; do
    # D-09: sentinel detection
    s1=$(grep -cF '<!-- v42-splice: callout -->' "$f" || true)
    s2=$(grep -cF '<!-- v42-splice: fp-recheck-section -->' "$f" || true)
    s3=$(grep -cF '<!-- v42-splice: output-format-section -->' "$f" || true)
    s4=$(grep -cF '<!-- v42-splice: council-handoff -->' "$f" || true)
    total=$((s1 + s2 + s3 + s4))

    if [ "$total" -eq 4 ]; then
        echo "[skip] already-spliced: $f"
        ALREADY_SPLICED=$((ALREADY_SPLICED + 1))
        continue
    fi
    if [ "$total" -gt 0 ] && [ "$total" -lt 4 ]; then
        echo "ERROR: partial-splice ($total/4 sentinels): $f" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Phase 4: Insert 4 blocks — write to tempfile, then mv atomically
    tmp=$(mktemp "${f}.XXXXXX")
    insert_blocks "$f" "$tmp"   # implementation detail: awk/Python/pure-bash
    mv "$tmp" "$f"
    SPLICED=$((SPLICED + 1))
    echo "[spliced] $f"
done < <(find "$REPO_ROOT/templates" -path '*/prompts/*.md' | sort)

echo "Processed $((SPLICED + ALREADY_SPLICED + ERRORS)) files: $SPLICED spliced, $ALREADY_SPLICED already-spliced, $ERRORS skipped (errors)"
[ "$ERRORS" -eq 0 ] || exit 1
```

### Block Insertion Logic

The `insert_blocks` function must handle four distinct insertion points:

**Block 1 — Top-of-file callout (D-05):**
Insert the HTML comment block after line 1 (H1 title) and any tagline paragraph (lines starting with `>` or blank after H1), before the first `---` divider. Simplest approach: find line number of first `---` separator, insert before it.

```bash
# Sentinel: <!-- v42-splice: callout -->
# Content:
<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Before reporting any finding, consult this file.
     Manage entries with /audit-skip and /audit-restore. -->
```

**Block 2 — SELF-CHECK section (D-06):**
- If file has `^## [0-9]+\. SELF-CHECK`: replace the section body (from heading to next `---` or next `^## `) while preserving the heading line. Insert sentinel as first line after heading.
- If no SELF-CHECK: insert the new section above the first `## [NN]. REPORT FORMAT` or `## [NN]. OUTPUT FORMAT` occurrence; compute NN as `max_section_number + 1`.

**Block 3 — OUTPUT FORMAT section (D-07):**
Insert below the last existing report-format or output-format section (or at EOF if none). NN = SELF-CHECK number + 1.

**Block 4 — Council Handoff footer (D-08):**
Append as last H2 in file, after OUTPUT FORMAT. No numeric prefix required by D-08.

**Implementation tool choice:** `awk` is the most portable choice for multi-line insertion with line-number awareness. Pure Bash (while-read line array) is viable but verbose. `sed` is too limited for multi-line replace. Recommendation: awk for block detection + Python heredoc-free pure-bash for the output (or a single awk script that handles all 4 insertions in one pass over the file). [ASSUMED — discretion area per D-18 in CONTEXT.md]

### Markefile Test 20 Structure

```bash
# scripts/tests/test-template-propagation.sh
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-template-propagation.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

# Copy templates to scratch
cp -r "$REPO_ROOT/templates" "$SCRATCH/templates-run1"

# Run 1
(cd "$SCRATCH" && bash "$REPO_ROOT/scripts/propagate-audit-pipeline-v42.sh")

cp -r "$SCRATCH/templates" "$SCRATCH/templates-run2"  # after first run

# Run 2
(cd "$SCRATCH" && bash "$REPO_ROOT/scripts/propagate-audit-pipeline-v42.sh")

# Assert idempotency
if diff -r "$SCRATCH/templates-run2" "$SCRATCH/templates" >/dev/null 2>&1; then
    report_pass "Idempotency: second run produces zero diff"
else
    report_fail "Idempotency: second run mutated files"
fi
```

The script operates on `REPO_ROOT/templates` by default. For test isolation, pass `TEMPLATES_ROOT` env override or `--templates-dir` flag. The planner must lock this — see Open Questions.

---

## Validation Architecture

### Testable Invariants for CI Gate (D-13/D-14)

After splice, every file in `templates/*/prompts/*.md` must satisfy:

| Invariant | grep command | Fails if |
|-----------|-------------|----------|
| Contains `Council handoff` | `grep -F 'Council handoff'` | D-08 footer missing |
| Contains `1. **Read context**` | `grep -F '1. **Read context**'` | FP-recheck step 1 missing |
| Contains `QUICK CHECK` | `grep -q 'QUICK CHECK'` | Pre-existing check; 14 files lack it (DESIGN_REVIEW, MYSQL/POSTGRES) — need scope adjustment |
| Contains `SELF-CHECK` | `grep -qE 'САМОПРОВЕРКА\|SELF-CHECK'` | Pre-existing check |

**Scope of new checks (D-13/D-14):** The two new marker checks must cover ALL 49 files. The existing Makefile loop only covers 3 prompt types (PERFORMANCE_AUDIT, CODE_REVIEW, DEPLOY_CHECKLIST). A new loop or expanded find expression is needed.

Recommended Makefile extension:

```make
# New loop covering all 49 files for v4.2 markers
for f in $$(find templates -path '*/prompts/*.md'); do \
    if ! grep -qF 'Council handoff' "$$f" 2>/dev/null; then \
        echo "❌ Missing Council handoff: $$f"; ERRORS=$$((ERRORS + 1)); \
    fi; \
    if ! grep -qF '1. **Read context**' "$$f" 2>/dev/null; then \
        echo "❌ Missing FP-recheck step 1: $$f"; ERRORS=$$((ERRORS + 1)); \
    fi; \
done
```

### Test 20 Idempotency Invariants

| Check | Command | Expected |
|-------|---------|----------|
| 4 sentinels per file after run 1 | `grep -cF 'v42-splice:' "$f"` | 4 |
| Zero diff between run 1 and run 2 output | `diff -r` | empty |
| Exit code of second run | `$?` | 0 |
| `already-spliced` count after run 2 | parse script stdout | equals 49 |

### Sentinel Scheme (D-09)

Four sentinel strings, each unique per block:

```text
<!-- v42-splice: callout -->
<!-- v42-splice: fp-recheck-section -->
<!-- v42-splice: output-format-section -->
<!-- v42-splice: council-handoff -->
```

Detection in script: `grep -cF '<!-- v42-splice:' "$f"` returns 0-4. Partial = error.
Detection in CI: `grep -F 'Council handoff'` and `grep -F '1. **Read context**'` are the human-readable contract markers (more stable than sentinel comments).

---

## Risks and Pitfalls

### Pitfall 1: Section Number Computation for Files Without SELF-CHECK

**What goes wrong:** Files like DESIGN_REVIEW.md have no numbered sections (`## 🎯 Scope` uses emoji, no integer prefix). Computing "NN = max_section_number + 1" returns 1. Inserting `## 1. SELF-CHECK (FP Recheck...)` into a file whose existing sections are unnumbered creates inconsistency.

**Why it happens:** The 21 files without SELF-CHECK span 3 prompt types: DESIGN_REVIEW (emoji headings), MYSQL_PERFORMANCE_AUDIT, POSTGRES_PERFORMANCE_AUDIT (numbered but no SELF-CHECK).

**How to avoid:** Script must detect whether target file uses numeric section prefixes. If no `## [0-9]` pattern found in file, use unnumbered heading `## SELF-CHECK (FP Recheck — 6-Step Procedure)`. Lock this in the plan.

**Warning sign:** `grep -cE '^## [0-9]+\.' "$f"` returns 0 for DESIGN_REVIEW files.

### Pitfall 2: Line-Ending Contamination (CRLF)

**What goes wrong:** macOS `mktemp` + `awk` produces LF output. If any source prompt file has CRLF line endings, `awk` line matching on `^## ` may fail silently (the `\r` before `\n` means `$0` ends with `\r`, not matching `^## $`).

**How to avoid:** At script start, verify all 49 source files are LF-only with `grep -cU $'\r'`. The repo uses LF throughout (verified — all existing templates pass markdownlint with no MD009 trailing-space errors). Add assertion in script: `if grep -qU $'\r' "$f"; then echo "ERROR: CRLF detected in $f" >&2; ERRORS=$((ERRORS+1)); continue; fi`.

### Pitfall 3: Markdownlint Compliance of Inserted Blocks

**What goes wrong:** Spliced blocks contain ordered lists (`1. **Read context**` ... `6. **Severity sanity check**`). MD029 (ordered list style) is set to `ordered` in `.markdownlint.json` — the 1-6 numbering is already sequential, so no issue. MD031/MD032 require blank lines before/after code blocks and lists.

**SOT components already pass markdownlint** (verified, 0 errors). However, the insertion joins require blank lines between the existing file content and the inserted block's first heading. The script must emit a blank line before each inserted H2.

**HTML comment blocks (callout):** MD033 is disabled in `.markdownlint.json` — HTML comments are allowed. No lint risk.

### Pitfall 4: Replacing SELF-CHECK Body Doubles the Section

**What goes wrong:** Script finds `## 11. SELF-CHECK` at line 440. It inserts the new 6-step body right after the heading but does NOT remove the old 4-row table body. Both old and new content coexist.

**How to avoid:** The `insert_blocks` function must consume (delete) all lines from the heading through the section's end delimiter (`---` separator or next `^## ` heading) before inserting the new body. Use awk's range pattern: `NR==heading_line, /^---/ || /^## /`.

### Pitfall 5: OUTPUT FORMAT Appended Twice If Script Has Off-by-One in Sentinel Detection

**What goes wrong:** Script checks `<!-- v42-splice: output-format-section -->` sentinel ONLY in the sentinel detection phase (top of loop). If sentinel is absent but another "OUTPUT FORMAT" string is present from a pre-existing `## 12. OUTPUT FORMAT` heading, the script still appends — resulting in two OUTPUT FORMAT sections.

**How to avoid:** Sentinel check is authoritative; do not fall back to content-based detection for skip decisions. The sentinel IS the idempotency token — if it's absent, the block has not been spliced regardless of content-alike text.

### Pitfall 6: Partial Splice on Script Interruption (Ctrl-C Mid-Write)

**What goes wrong:** Script is interrupted after writing 2 of 4 blocks, before `mv "$tmp" "$f"`. The tempfile is left in `templates/`, the original is unmodified. On re-run, sentinel count = 0 (original is intact), so script re-processes cleanly.

**Why this is safe:** Atomic rewrite via tempfile+mv means the ORIGINAL file is not modified until `mv` succeeds. If interrupted before `mv`, the original is intact and re-runnable. Add `trap 'rm -f "$tmp"' INT TERM` inside the per-file loop to clean up the orphaned tempfile.

### Pitfall 7: `find` Glob Picking Up Non-Target Files

**What goes wrong:** `find templates -path '*/prompts/*.md'` picks up any future `.md` file added to a `prompts/` directory (e.g., a `README.md`). Such files lack section structure and will fail block insertion.

**How to avoid:** Constrain find to the 7 known filename patterns: `\( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o ... \)`. D-03 specifies `find templates -path "*/prompts/*.md" | sort` without filename filtering — but an explicit allowlist is safer. This is a discretion-area decision for the planner.

### Pitfall 8: MD024 Duplicate Headings

**What goes wrong:** Post-splice, every file will have `## Council verdict` as the Council Handoff section heading — but `## Council verdict` also appears as a section heading in `components/audit-output-format.md` within the `## Full Report Skeleton` block (embedded in a code fence). MD024 (`siblings_only: true`) only flags duplicates at the same level that are siblings. Since the Council Handoff footer and the code-fence content are at different nesting levels, no MD024 violation occurs. [VERIFIED: markdownlint config, SOT components pass]

---

## Open Questions (RESOLVED WHERE POSSIBLE)

1. **Section numbers in DESIGN_REVIEW files (21 files without existing SELF-CHECK + no numeric headings)**
   - What we know: DESIGN_REVIEW files use emoji headings (`## 🎯 Scope`), no integer prefix
   - What's unclear: Should the inserted headings be `## SELF-CHECK (FP Recheck — 6-Step Procedure)` (no number) or `## 1. SELF-CHECK ...`?
   - Recommendation: Use unnumbered headings for DESIGN_REVIEW (detect via `grep -cE '^## [0-9]+\.' "$f"` == 0). For MYSQL/POSTGRES files (numbered but no SELF-CHECK), assign next number after the last `## NN.` heading found. **Planner must lock this.**

2. **Scope of `find` in Makefile D-13 extension — expand to all 7 or add separate loop?**
   - Current Makefile loop covers only PERFORMANCE_AUDIT, CODE_REVIEW, DEPLOY_CHECKLIST (3/7 types)
   - Quality.yml covers 4/7 (adds SECURITY_AUDIT)
   - The two new marker checks must cover all 49 files
   - Recommendation: Add a SEPARATE loop for the new markers that uses `find templates -path '*/prompts/*.md'` (all 49 files). Leave existing QUICK CHECK loop unchanged to avoid breaking its established scope. **Planner must lock.**

3. **`insert_blocks` implementation tool — awk vs pure Bash?**
   - Awk: handles multi-line range deletion + insertion in one pass; portable; concise (~50 lines)
   - Pure Bash: readable but verbose; requires line array in memory
   - Recommendation: awk; matches `set -euo pipefail` discipline and avoids GNU-only patterns. **Planner should lock.**

4. **Test 20 templates directory isolation — env override or flag?**
   - The script operates on `REPO_ROOT/templates` by default. To run against a scratch copy, either: (a) add `--templates-dir "$scratch/templates"` flag, or (b) use env var `SPLICE_TEMPLATES_DIR`
   - Recommendation: env var `SPLICE_TEMPLATES_DIR` (consistent with `TK_UPDATE_FILE_SRC` pattern in `update-claude.sh`). **Planner must lock.**

5. **Council Handoff footer exact heading text (D-08)**
   - The footer is the LAST H2 section. D-08 says "Council Handoff footer" — the heading should be `## Council Handoff` to match the `Council handoff` marker greps (D-13/D-14 use `grep -F 'Council handoff'`, lowercase `h` in `handoff`).
   - Confirmed: heading `## Council Handoff` satisfies `grep -F 'Council handoff'` (case-sensitive, exact substring match succeeds). [VERIFIED: string match]

---

## Sources

### Primary (HIGH confidence)

- `components/audit-fp-recheck.md` — splice body, step labels, section structure
- `components/audit-output-format.md` — splice body, Council verdict slot byte-exact string
- `Makefile` lines 115-150 — existing validate loop structure and scope
- `.github/workflows/quality.yml` lines 44-68 — existing CI validate structure and scope
- `scripts/tests/test-audit-pipeline.sh` — mktemp+trap+PASS/FAIL counter pattern
- `scripts/tests/test-council-audit-review.sh` — pre/post diff pattern for Test 20
- `scripts/council/brain.py` lines 299-317 — `atomic_write_text` pattern
- `scripts/update-claude.sh` lines 840, 896 — shell `mktemp` + `mv` atomic pattern
- All 49 prompt files under `templates/*/prompts/*.md` — section structure survey

### Secondary (MEDIUM confidence)

- `.markdownlint.json` — MD029/MD031/MD032/MD033/MD040 rules affecting spliced content
- `scripts/cell-parity.sh` — fan-out loop pattern (while-read + ERRORS accumulator)
