# Phase 16: Template Propagation — 49 Prompt Files - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 5 (2 new scripts, 49 prompt edits, Makefile, quality.yml)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/propagate-audit-pipeline-v42.sh` | utility | batch, file-I/O | `scripts/update-claude.sh` (atomic rewrite) + `scripts/cell-parity.sh` (fan-out loop) | role-match |
| `scripts/tests/test-template-propagation.sh` | test | batch, file-I/O | `scripts/tests/test-audit-pipeline.sh` | exact |
| 49 `templates/*/prompts/*.md` edits | config | transform | `templates/base/prompts/SECURITY_AUDIT.md` | exact |
| `Makefile` validate extension | config | request-response | `Makefile` lines 115-134 | exact |
| `.github/workflows/quality.yml` validate-templates extension | config | request-response | `.github/workflows/quality.yml` lines 44-68 | exact |

---

## Pattern Assignments

### `scripts/propagate-audit-pipeline-v42.sh` (utility, batch file-I/O)

**Analogs:**
- `scripts/update-claude.sh` — atomic tempfile+mv rewrite pattern
- `scripts/cell-parity.sh` — ERRORS accumulator + while-read fan-out loop

**Script header pattern** (from `scripts/update-claude.sh` lines 1-8 and `scripts/tests/test-audit-pipeline.sh` lines 1-10):

```bash
#!/bin/bash
# scripts/propagate-audit-pipeline-v42.sh
# Fan-out v4.2 audit pipeline contracts to all 49 prompt files.
# Usage: bash scripts/propagate-audit-pipeline-v42.sh [--dry-run]
#        SPLICE_TEMPLATES_DIR=/path/to/templates bash scripts/propagate-audit-pipeline-v42.sh
# Exit: 0 = all pass, 1 = partial-splice error or missing SOT component
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

**SOT guard pattern** (from `scripts/tests/test-audit-pipeline.sh` lines 32-38 and `scripts/update-claude.sh` TEMPLATE_URL guard):

```bash
FP_RECHECK_SOT="$REPO_ROOT/components/audit-fp-recheck.md"
OUTPUT_FORMAT_SOT="$REPO_ROOT/components/audit-output-format.md"

[ -f "$FP_RECHECK_SOT" ] || { echo "ERROR: $FP_RECHECK_SOT missing" >&2; exit 1; }
[ -f "$OUTPUT_FORMAT_SOT" ] || { echo "ERROR: $OUTPUT_FORMAT_SOT missing" >&2; exit 1; }
```

**Splice body extraction pattern** (from RESEARCH.md recommendation, awk idiom):

```bash
FP_RECHECK_BODY=$(awk 'found || /^## /{found=1; print}' "$FP_RECHECK_SOT")
OUTPUT_FORMAT_BODY=$(awk 'found || /^## /{found=1; print}' "$OUTPUT_FORMAT_SOT")
```

**ERRORS accumulator + fan-out loop pattern** (from `scripts/update-claude.sh` validate loop and `Makefile` lines 117-134):

```bash
SPLICED=0; ALREADY_SPLICED=0; ERRORS=0

TEMPLATES_ROOT="${SPLICE_TEMPLATES_DIR:-$REPO_ROOT/templates}"

while IFS= read -r f; do
    # sentinel detection (D-09)
    total=$(grep -cF '<!-- v42-splice:' "$f" || true)

    if [ "$total" -eq 4 ]; then
        echo "[skip] already-spliced: $f"
        ALREADY_SPLICED=$((ALREADY_SPLICED + 1))
        continue
    fi
    if [ "$total" -gt 0 ] && [ "$total" -lt 4 ]; then
        present=$(grep -oF '<!-- v42-splice:' "$f" | paste -sd ',' -)
        echo "ERROR: partial-splice ($total/4 sentinels present: $present): $f" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # CRLF guard (Pitfall 2)
    if grep -qU $'\r' "$f" 2>/dev/null; then
        echo "ERROR: CRLF detected in $f" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    tmp=$(mktemp "${f}.XXXXXX")
    trap 'rm -f "$tmp"' INT TERM
    insert_blocks "$f" "$tmp"
    mv "$tmp" "$f"
    SPLICED=$((SPLICED + 1))
    echo "[spliced] $f"
done < <(find "$TEMPLATES_ROOT" -path '*/prompts/*.md' \
    \( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o \
       -name 'PERFORMANCE_AUDIT.md' -o -name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
       -name 'POSTGRES_PERFORMANCE_AUDIT.md' -o -name 'DEPLOY_CHECKLIST.md' -o \
       -name 'DESIGN_REVIEW.md' \) | sort)

echo "Processed $((SPLICED + ALREADY_SPLICED + ERRORS)) files: $SPLICED spliced, $ALREADY_SPLICED already-spliced, $ERRORS skipped (errors)"
[ "$ERRORS" -eq 0 ] || exit 1
```

**Atomic tempfile+mv pattern** (from `scripts/update-claude.sh` lines 840-841, 896):

```bash
# In update-claude.sh (lines 840, 896):
CLAUDE_MD_TMP=$(mktemp)
# ... write to CLAUDE_MD_TMP ...
mv "$CLAUDE_MD_TMP" "$CLAUDE_MD"

# Adaptation for splice script (tempfile in same dir for atomic rename):
tmp=$(mktemp "${f}.XXXXXX")
# ... write new content to $tmp ...
mv "$tmp" "$f"
```

**Section-number detection pattern** (needed by insert_blocks for DESIGN_REVIEW edge case — Pitfall 1):

```bash
# Detect whether file uses numeric section prefixes
uses_numbered_sections() {
    grep -cqE '^## [0-9]+\.' "$1"
}

# Get highest existing section number
max_section_number() {
    grep -oE '^## ([0-9]+)\.' "$1" | grep -oE '[0-9]+' | sort -n | tail -1
}
```

**Summary + exit code pattern** (from `scripts/tests/test-audit-pipeline.sh` lines 488-493):

```bash
printf '\nProcessed %d files: %d spliced, %d already-spliced, %d skipped (errors)\n' \
    "$((SPLICED + ALREADY_SPLICED + ERRORS))" "$SPLICED" "$ALREADY_SPLICED" "$ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
```

---

### `scripts/tests/test-template-propagation.sh` (test, batch file-I/O)

**Analog:** `scripts/tests/test-audit-pipeline.sh` (exact match)

**Script header + scaffold pattern** (from `scripts/tests/test-audit-pipeline.sh` lines 1-27):

```bash
#!/bin/bash
# Claude Code Toolkit - test-template-propagation.sh
# Test 20: idempotency regression for propagate-audit-pipeline-v42.sh.
# Runs the splice script twice on a scratch copy of templates/ and asserts
# the second run produces zero diff (D-09 contract, D-15).
# Usage: bash scripts/tests/test-template-propagation.sh
# Exit: 0 = all pass, 1 = any fail
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPLICE_SCRIPT="$REPO_ROOT/scripts/propagate-audit-pipeline-v42.sh"

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-template-propagation.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }
```

**Pre/post diff pattern** (from `scripts/tests/test-council-audit-review.sh` line 24 + diff idiom):

```bash
# Copy templates to scratch
cp -r "$REPO_ROOT/templates" "$SCRATCH/templates"

# Run 1 — splices all 49 files
SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT"

# Snapshot post-run-1 state
cp -r "$SCRATCH/templates" "$SCRATCH/templates-after-run1"

# Run 2 — must be a no-op (all files already-spliced)
SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT"

# Assert idempotency
if diff -r "$SCRATCH/templates-after-run1" "$SCRATCH/templates" >/dev/null 2>&1; then
    report_pass "Idempotency: second run produces zero diff across 49 prompt files"
else
    report_fail "Idempotency: second run mutated files (diff -r shows changes)"
    diff -r "$SCRATCH/templates-after-run1" "$SCRATCH/templates" | head -40
fi
```

**Sentinel count assertion per file** (from `scripts/tests/test-audit-pipeline.sh` grep-count pattern lines 46-53):

```bash
# Assert each prompt file carries exactly 4 sentinels after run 1
SENTINEL_ERRORS=0
while IFS= read -r f; do
    count=$(grep -cF '<!-- v42-splice:' "$f" || true)
    if [ "$count" -ne 4 ]; then
        report_fail "Sentinel count: expected 4, got $count in $f"
        SENTINEL_ERRORS=$((SENTINEL_ERRORS + 1))
    fi
done < <(find "$SCRATCH/templates" -path '*/prompts/*.md' \
    \( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o \
       -name 'PERFORMANCE_AUDIT.md' -o -name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
       -name 'POSTGRES_PERFORMANCE_AUDIT.md' -o -name 'DEPLOY_CHECKLIST.md' -o \
       -name 'DESIGN_REVIEW.md' \) | sort)
if [ "$SENTINEL_ERRORS" -eq 0 ]; then
    report_pass "Sentinel count: all 49 prompt files carry exactly 4 v42-splice sentinels"
fi
```

**Results block pattern** (from `scripts/tests/test-audit-pipeline.sh` lines 488-493):

```bash
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

### 49 `templates/*/prompts/*.md` edits (config, transform)

**Analog:** `templates/base/prompts/SECURITY_AUDIT.md`

**Existing SELF-CHECK section structure** (from `templates/base/prompts/SECURITY_AUDIT.md` lines 440-451):

```markdown
## 11. SELF-CHECK

**Before adding vulnerability to report:**

| Question | If "no" → reconsider severity |
| -------- | ---------------------------------- |
| Is this **exploitable** in real conditions? | Theoretical ≠ real threat |
| Is there an **attack path** for attacker? | Internal-only ≠ CRITICAL |
| **What damage** on successful attack? | Public data leak ≠ password leak |
| Is **auth** required for exploitation? | Auth-required lowers severity |

---

## 12. REPORT FORMAT
```

**Post-splice target structure for each file — 4 insertion points:**

```markdown
# [Prompt Title]

<!-- v42-splice: callout -->
<!-- Audit exceptions allowlist: .claude/rules/audit-exceptions.md
     Consult this file before reporting any finding. Use /audit-skip to add entries,
     /audit-restore to remove them. -->

[existing prompt body...]

## NN. SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->

[body of components/audit-fp-recheck.md from ## Procedure onwards]

---

[existing report format section if present...]

## NN+1. OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->

[body of components/audit-output-format.md from ## Report Path onwards]

---

## Council Handoff
<!-- v42-splice: council-handoff -->

When the structured report is complete, hand it off to the Supreme Council for
peer review. See `commands/audit.md` Phase 5 (Council Pass — mandatory) for the
invocation: `/council audit-review --report <path>`. The Council runs in
audit-review mode (see `commands/council.md` `## Modes`). The Council verdict
slot in the report is pre-populated with the byte-exact placeholder
`_pending — run /council audit-review_` (U+2014 em-dash) and is overwritten by
the Council pass.
```

**DESIGN_REVIEW edge case — unnumbered headings** (21 files, no `## [0-9]+\.` pattern):

```markdown
## SELF-CHECK (FP Recheck — 6-Step Procedure)
<!-- v42-splice: fp-recheck-section -->
[fp-recheck body]

## OUTPUT FORMAT (Structured Report Schema — Phase 14)
<!-- v42-splice: output-format-section -->
[output-format body]

## Council Handoff
<!-- v42-splice: council-handoff -->
[council handoff prose]
```

---

### `Makefile` validate target extension (config, request-response)

**Analog:** `Makefile` lines 115-134 (exact match)

**Current validate loop pattern** (lines 115-134):

```make
validate:
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' \( \
		-name 'PERFORMANCE_AUDIT.md' -o \
		-name 'CODE_REVIEW.md' -o \
		-name 'DEPLOY_CHECKLIST.md' \)); do \
		if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing QUICK CHECK: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -qE "САМОПРОВЕРКА|SELF-CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing САМОПРОВЕРКА: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	...
```

**Extension pattern — add a SEPARATE loop after the existing one** (per D-13, separate loop leaves existing QUICK CHECK scope intact):

```make
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md'); do \
		if ! grep -qF 'Council handoff' "$$f" 2>/dev/null; then \
			echo "❌ Missing Council handoff: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
		if ! grep -qF '1. **Read context**' "$$f" 2>/dev/null; then \
			echo "❌ Missing FP-recheck step 1: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS errors"; \
		exit 1; \
	fi
```

**Test 20 registration pattern** (from Makefile lines 108-112, append after Test 19):

```make
	@echo ""
	@echo "Test 20: template propagation idempotency (propagate-audit-pipeline-v42.sh)"
	@bash scripts/tests/test-template-propagation.sh
	@echo ""
	@echo "All tests passed!"
```

---

### `.github/workflows/quality.yml` validate-templates extension (config, request-response)

**Analog:** `.github/workflows/quality.yml` lines 44-68 (exact match)

**Current CI loop pattern** (lines 44-68):

```yaml
- name: Check required sections in audit files
  run: |
    echo "Checking audit files for required sections..."
    ERRORS=0

    for f in templates/**/SECURITY_AUDIT.md templates/**/PERFORMANCE_AUDIT.md \
             templates/**/CODE_REVIEW.md templates/**/DEPLOY_CHECKLIST.md; do
      [ -f "$f" ] || continue
      if ! grep -q "QUICK CHECK" "$f"; then
        echo "❌ Missing QUICK CHECK: $f"
        ERRORS=$((ERRORS + 1))
      fi
      if ! grep -q "САМОПРОВЕРКА\|SELF-CHECK" "$f"; then
        echo "❌ Missing SELF-CHECK section: $f"
        ERRORS=$((ERRORS + 1))
      fi
      if ! grep -q "ФОРМАТ ОТЧЁТА\|OUTPUT FORMAT" "$f"; then
        echo "❌ Missing REPORT FORMAT: $f"
        ERRORS=$((ERRORS + 1))
      fi
    done

    if [ $ERRORS -gt 0 ]; then
      echo "Found $ERRORS errors"
      exit 1
    fi
    echo "✅ All audit templates valid"
```

**Extension pattern — add step after the existing step** (per D-14, mirror Makefile new loop):

```yaml
- name: Check v4.2 pipeline markers in all 49 prompt files
  run: |
    echo "Checking v4.2 audit pipeline markers (Council handoff + FP-recheck step 1)..."
    ERRORS=0

    for f in templates/**/SECURITY_AUDIT.md templates/**/CODE_REVIEW.md \
             templates/**/PERFORMANCE_AUDIT.md templates/**/MYSQL_PERFORMANCE_AUDIT.md \
             templates/**/POSTGRES_PERFORMANCE_AUDIT.md templates/**/DEPLOY_CHECKLIST.md \
             templates/**/DESIGN_REVIEW.md; do
      [ -f "$f" ] || continue
      if ! grep -qF 'Council handoff' "$f"; then
        echo "❌ Missing Council handoff: $f"
        ERRORS=$((ERRORS + 1))
      fi
      if ! grep -qF '1. **Read context**' "$f"; then
        echo "❌ Missing FP-recheck step 1: $f"
        ERRORS=$((ERRORS + 1))
      fi
    done

    if [ $ERRORS -gt 0 ]; then
      echo "Found $ERRORS errors"
      exit 1
    fi
    echo "✅ All 49 prompt files carry v4.2 pipeline markers"
```

---

## Shared Patterns

### Set-euo-pipefail Header
**Source:** All scripts in `scripts/` (e.g., `scripts/update-claude.sh` line 8, `scripts/tests/test-audit-pipeline.sh` line 8)
**Apply to:** `propagate-audit-pipeline-v42.sh`, `test-template-propagation.sh`

```bash
set -euo pipefail
```

### REPO_ROOT Resolution
**Source:** `scripts/tests/test-audit-pipeline.sh` line 10
**Apply to:** Both new scripts

```bash
# test scripts (two levels deep from repo root):
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# scripts/ scripts (one level deep):
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

### ERRORS Accumulator Exit Pattern
**Source:** `Makefile` lines 131-134 and `scripts/tests/test-audit-pipeline.sh` lines 488-493
**Apply to:** `propagate-audit-pipeline-v42.sh`, both Makefile and CI extensions

```bash
[ "$ERRORS" -eq 0 ] || exit 1
```

### mktemp + trap Cleanup
**Source:** `scripts/tests/test-audit-pipeline.sh` lines 20-21
**Apply to:** `test-template-propagation.sh` (scratch dir), `propagate-audit-pipeline-v42.sh` (per-file tmp cleanup)

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-template-propagation.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT
```

### Env Var Test Seam (TK_UPDATE_FILE_SRC pattern)
**Source:** `scripts/update-claude.sh` lines 846-861 (`TK_UPDATE_FILE_SRC` env override for hermetic tests)
**Apply to:** `propagate-audit-pipeline-v42.sh` — use `SPLICE_TEMPLATES_DIR` env var as the test isolation seam (consistent naming convention)

```bash
TEMPLATES_ROOT="${SPLICE_TEMPLATES_DIR:-$REPO_ROOT/templates}"
```

### Markdownlint Compliance for Inserted Blocks
**Source:** `.markdownlint.json` (MD031/MD032 blank lines around code blocks/lists; MD040 language on fenced blocks; MD033 HTML allowed)
**Apply to:** All 4 inserted blocks in each prompt file

- Insert a blank line before each new H2 heading when appending to existing content
- The FP-recheck body has sequential 1-6 numbering — MD029 `ordered` style is already satisfied
- HTML comment sentinels are safe — MD033 is disabled

---

## No Analog Found

All files have close analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/tests/`, `Makefile`, `.github/workflows/quality.yml`, `templates/base/prompts/`, `components/`
**Files scanned:** 8 analog files read in full or in part
**Pattern extraction date:** 2026-04-26
