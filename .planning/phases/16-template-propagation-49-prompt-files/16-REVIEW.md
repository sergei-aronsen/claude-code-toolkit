---
phase: 16-template-propagation-49-prompt-files
reviewed: 2026-04-25T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - scripts/propagate-audit-pipeline-v42.sh
  - scripts/tests/test-template-propagation.sh
  - templates/base/prompts/SECURITY_AUDIT.md
  - templates/python/prompts/MYSQL_PERFORMANCE_AUDIT.md
  - templates/laravel/prompts/DESIGN_REVIEW.md
  - templates/nextjs/prompts/SECURITY_AUDIT.md
  - Makefile
  - .github/workflows/quality.yml
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-04-25
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 16 fan-out script (`propagate-audit-pipeline-v42.sh`) is structurally sound: shellcheck-clean,
idempotent via sentinel counting, atomic write via tempfile-then-mv, correct RETURN-trap cleanup of
block_dir. The Python inline rewrite logic handles numbered/unnumbered headings and all three splice
paths (replace-existing-SC, insert-before-RF, append-EOF). All 49 prompt files carry 4 sentinels,
the correct markers, and the byte-exact em-dash slot string.

Three issues require attention. The most severe is a silent CI gate failure: the `quality.yml`
`templates/**/` glob expands to zero files in bash (no `globstar`), so the v4.2 marker check and the
original audit-template check both pass vacuously on Ubuntu CI. The Makefile `validate` target uses
`find` and is unaffected. The second issue is a heading-number collision in two `SECURITY_AUDIT.md`
files (base, nextjs) where the splice inserts `## 12. OUTPUT FORMAT` without deleting the existing
`## 12. REPORT FORMAT`, producing two headings numbered 12 with `## 13. ACTIONS` sandwiched between
them. The third is that Test 20 runs only locally (`make test`) and is absent from the CI workflow.

## Critical Issues

### CR-01: CI validate-templates glob silently matches zero files — gate passes vacuously

**File:** `.github/workflows/quality.yml:48,75`

**Issue:** Both CI template-validation steps iterate over `templates/**/SECURITY_AUDIT.md` (and the
other six types) using a bare bash `for` loop. On the GitHub Actions Ubuntu runner, bash does not
enable `globstar` by default, so `**` is treated as a single wildcard star that matches one directory
level. Because the prompt files live at `templates/<framework>/prompts/SECURITY_AUDIT.md` (two levels
deep), `templates/**/SECURITY_AUDIT.md` expands to nothing, the loop body never executes, `ERRORS`
stays at 0, and both checks print the `✅` success line without ever reading a file.

Verified locally: `bash -c 'for f in templates/**/SECURITY_AUDIT.md; do [ -f "$f" ] || continue; echo "$f"; done'` produces zero output from the project root.

The Makefile `validate` target is **unaffected** because it uses `find templates -path '*/prompts/*.md' -name 'SECURITY_AUDIT.md'` which works portably.

**Fix:**

Replace the glob with `find … | while IFS= read -r f` (mirroring the Makefile) in both
affected steps:

```yaml
# quality.yml — "Check required sections" step (line ~44)
- name: Check required sections in audit files
  run: |
    echo "Checking audit files for required sections..."
    ERRORS=0
    while IFS= read -r f; do
      if ! grep -q "QUICK CHECK" "$f"; then
        echo "❌ Missing QUICK CHECK: $f"; ERRORS=$((ERRORS + 1))
      fi
      if ! grep -q "САМОПРОВЕРКА\|SELF-CHECK" "$f"; then
        echo "❌ Missing SELF-CHECK section: $f"; ERRORS=$((ERRORS + 1))
      fi
      if ! grep -q "ФОРМАТ ОТЧЁТА\|OUTPUT FORMAT" "$f"; then
        echo "❌ Missing REPORT FORMAT: $f"; ERRORS=$((ERRORS + 1))
      fi
    done < <(find templates -path '*/prompts/*.md' \( -name 'SECURITY_AUDIT.md' \
        -o -name 'PERFORMANCE_AUDIT.md' -o -name 'CODE_REVIEW.md' \
        -o -name 'DEPLOY_CHECKLIST.md' \))
    if [ $ERRORS -gt 0 ]; then echo "Found $ERRORS errors"; exit 1; fi
    echo "✅ All audit templates valid"

# quality.yml — "Check v4.2 pipeline markers" step (line ~70)
- name: Check v4.2 pipeline markers in all 49 prompt files
  run: |
    echo "Checking v4.2 audit pipeline markers..."
    ERRORS=0
    while IFS= read -r f; do
      if ! grep -qF 'Council Handoff' "$f"; then
        echo "❌ Missing 'Council Handoff' marker: $f"; ERRORS=$((ERRORS + 1))
      fi
      if ! grep -qF '1. **Read context**' "$f"; then
        echo "❌ Missing '1. **Read context**' marker: $f"; ERRORS=$((ERRORS + 1))
      fi
      if ! grep -qF '6. **Severity sanity check**' "$f"; then
        echo "❌ Missing '6. **Severity sanity check**' marker: $f"; ERRORS=$((ERRORS + 1))
      fi
    done < <(find templates -path '*/prompts/*.md' \( -name 'SECURITY_AUDIT.md' \
        -o -name 'CODE_REVIEW.md' -o -name 'PERFORMANCE_AUDIT.md' \
        -o -name 'MYSQL_PERFORMANCE_AUDIT.md' \
        -o -name 'POSTGRES_PERFORMANCE_AUDIT.md' \
        -o -name 'DEPLOY_CHECKLIST.md' -o -name 'DESIGN_REVIEW.md' \))
    if [ $ERRORS -gt 0 ]; then echo "Found $ERRORS v4.2 marker errors"; exit 1; fi
    echo "✅ All 49 prompt files carry v4.2 pipeline markers (TEMPLATE-03)"
```

## Warnings

### WR-01: Duplicate `## 12.` heading number in SECURITY_AUDIT.md (base, nextjs)

**File:** `templates/base/prompts/SECURITY_AUDIT.md:493,528,530` and
`templates/nextjs/prompts/SECURITY_AUDIT.md` (same structure)

**Issue:** The splice inserts `## 12. OUTPUT FORMAT` (of_num = sc_num + 1 = 11 + 1 = 12) but does
**not** delete the existing `## 12. REPORT FORMAT` section. The Python rewriter only skips the old
SELF-CHECK body (the `in_skip` path); it appends `of_blk` **after** `rf_end` (the line that starts
`## 13. ACTIONS`), leaving both headings in the file. The resulting section order is:

```text
## 11. SELF-CHECK …     ← replaced correctly
## 12. REPORT FORMAT    ← old, retained
## 13. ACTIONS          ← old, retained
## 12. OUTPUT FORMAT    ← new, appended ← duplicate number
## Council Handoff      ← new, appended
```

The four sentinel count passes (4 of 4), so the idempotency guard fires and the situation is frozen.
All 49 files have this structure or do not exhibit it; the issue manifests only where a `## NN. REPORT
FORMAT` existed before the splice (`base` and `nextjs` SECURITY_AUDIT files).

The TEMPLATE-02 requirement (pre-existing prose byte-identical) holds — no original text was
mutated — but the heading numbering is misleading to Claude when reading the prompt.

**Fix:** Two options:

Option A — remove the old REPORT FORMAT section in the same Python pass (add a skip range for
`rf_start..rf_end-1` analogous to the `in_skip` mechanism for SELF-CHECK):

```python
# In the Python rewriter, after Block 2a skip logic, add:
if has_rf and lineno == rf_start and has_sc:
    # skip old report-format body: same in_skip mechanism
    in_rf_skip = True
    i += 1
    continue
if in_rf_skip:
    if lineno < rf_end:
        i += 1
        continue
    else:
        in_rf_skip = False
        # emit the first line after rf_start (rf_end = ## 13. ACTIONS or EOF)
        # and insert of_blk before it
        append_block(out, of_blk)
        of_emitted = True
        out.append(lines[i])
        i += 1
        continue
```

Option B (simpler) — manually delete the now-superseded `## 12. REPORT FORMAT` blocks from the two
affected files and re-run with the sentinel approach amended to handle this.

### WR-02: Test 20 is absent from CI (`quality.yml`) — idempotency regression not gated in CI

**File:** `.github/workflows/quality.yml`

**Issue:** `make test` runs Test 20 (`scripts/tests/test-template-propagation.sh`), which is the only
automated check for splice idempotency, sentinel counts, marker presence, and partial-splice
detection. This test is not wired into `quality.yml`. If the splice script is re-run in a future
commit and breaks idempotency (e.g. a change to a sentinel tag), CI would not catch it.

The Makefile `test` target is not invoked by any CI job (only `lint`, `validate`, `validate-base-plugins`,
`version-align`, `translation-drift`, `agent-collision-static`, `validate-commands`, `cell-parity` run
in CI).

**Fix:** Add a test step to the `validate-templates` job or a dedicated `test-propagation` job:

```yaml
# quality.yml — in validate-templates job, or as a separate job
- name: Test 20 — template propagation idempotency
  run: bash scripts/tests/test-template-propagation.sh
```

Note: this test requires `python3` (used by the splice script), `shellcheck`, and `diff`. All are
available on `ubuntu-latest`.

## Info

### IN-01: Success message in test reports `Council handoff` (lowercase h) but the marker is `Council Handoff`

**File:** `scripts/tests/test-template-propagation.sh:133`

**Issue:** The `report_pass` call says `"contract markers: all 49 files contain 'Council handoff' + '1. **Read context**'"` with a lowercase `h` in `handoff`, while the actual splice script emits `## Council Handoff` (uppercase H) and the grep at line 109 correctly tests for `'Council Handoff'`. The test logic is correct; only the human-readable pass message has the wrong capitalisation.

**Fix:**

```bash
# Line 133 — change:
report_pass "contract markers: all 49 files contain 'Council handoff' + '1. **Read context**'"
# to:
report_pass "contract markers: all 49 files contain 'Council Handoff' + '1. **Read context**'"
```

---

_Reviewed: 2026-04-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
