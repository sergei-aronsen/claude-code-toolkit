---
phase: 14-audit-pipeline-fp-recheck-structured-reports
reviewed: 2026-04-25T21:20:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - components/audit-fp-recheck.md
  - components/audit-output-format.md
  - commands/audit.md
  - scripts/tests/test-audit-pipeline.sh
  - scripts/tests/fixtures/audit/allowlist-populated.md
  - scripts/tests/fixtures/audit/allowlist-empty.md
  - scripts/tests/fixtures/audit/sample-project/src/auth.ts
  - scripts/tests/fixtures/audit/sample-project/lib/utils.py
  - scripts/tests/fixtures/audit/sample-project/src/legacy.js
  - Makefile
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-25T21:20:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed all 10 Phase 14 deliverables: two new components (`audit-fp-recheck.md`,
`audit-output-format.md`), the rewritten `commands/audit.md`, the Bash regression test with
5 fixture files, and the Makefile edit. The test passes all 82 assertions (exit 0). ShellCheck
passes at warning level. Both components pass markdownlint.

No critical or security findings. The test fixtures are correctly isolated under
`scripts/tests/fixtures/audit/` and each carries an explicit header comment warning reviewers
not to alter the deliberately vulnerable patterns. The dangerous patterns (SQL concat,
dynamic code execution) do not appear outside the fixture tree.

Two warnings found:

1. The Phase 0 illustrative shell snippet in `commands/audit.md` has a temp file leak —
   `ALLOWLIST_TMP` is created unconditionally by `mktemp` but the cleanup `trap` is only
   registered inside the `if [ -f "$EXC_FILE" ]` branch, leaving the temp file uncleaned
   when the allowlist is absent (the common case for new projects).
2. The fixture `lib/utils.py` claims the dangerous call is at "line ~5" but the actual
   dynamic-code pattern is at line 18. Under the byte-exact match rule (D-07), the allowlist
   entry `lib/utils.py:5` would never suppress a real audit finding at line 18, making the
   allowlist-suppression test path non-representative.

Three informational observations follow.

---

## Warnings

### WR-01: Temp file leak when allowlist is absent — Phase 0 snippet

**File:** `commands/audit.md:97-112`

**Issue:** `ALLOWLIST_TMP="$(mktemp)"` is called unconditionally before the
`if [ -f "$EXC_FILE" ]` guard. The `trap 'rm -f "$STRIPPED_TMP" "$ALLOWLIST_TMP"' EXIT`
that cleans it up is registered **inside** the `if` block. When `audit-exceptions.md` is
absent (the common initial state for any project), `mktemp` creates a temp file in `/tmp`
but the trap is never set, so the file is never removed. The leak occurs on every audit
invocation for projects with no allowlist.

This is an illustrative snippet in Markdown instructions that Claude follows. If Phase 16
copies this snippet verbatim into any shell-executable context the leak becomes a real OS
resource issue. As instructions it still teaches incorrect cleanup discipline.

**Fix:**

```bash
# Move STRIPPED_TMP outside the if block and register the trap unconditionally:
EXC_FILE=".claude/rules/audit-exceptions.md"
ALLOWLIST_TMP="$(mktemp)"
STRIPPED_TMP="$(mktemp)"
trap 'rm -f "$STRIPPED_TMP" "$ALLOWLIST_TMP"' EXIT   # always registered

if [ -f "$EXC_FILE" ]; then
    sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"
    grep '^### ' "$STRIPPED_TMP" | while IFS= read -r heading; do
        entry="${heading#'### '}"
        path_line="${entry% — *}"
        rule="${entry##* — }"
        printf '%s:%s\n' "$path_line" "$rule"
    done > "$ALLOWLIST_TMP"
fi
```

---

### WR-02: Fixture line number mismatch — allowlist-suppression path non-representative

**File:** `scripts/tests/fixtures/audit/sample-project/lib/utils.py:3` and
`scripts/tests/fixtures/audit/allowlist-populated.md:20`

**Issue:** The fixture header says "The dynamic-execution call on line ~5 is INTENTIONAL"
and the allowlist entry is `### lib/utils.py:5 — SEC-DYNAMIC-EXEC`. The actual dangerous
call (`exec(code_obj, namespace)`) is at **line 18**. Line 5 is inside the module docstring.

Under the byte-exact match rule (D-07), a real audit that flags `lib/utils.py:18` searches
for `lib/utils.py:18` in the allowlist. It would not find `lib/utils.py:5` and would not
suppress the finding. The intended allowlist-suppression demonstration does not actually work
if a real audit is run against the fixture.

The regression test only validates allowlist parser mechanics (triple extraction, comment
stripping, em-dash integrity) against the heading string `lib/utils.py:5` — it never
cross-references the allowlist line number against the actual `exec` call in the source file.
Tests pass, but the fixture does not represent a realistic end-to-end suppression scenario.

**Fix:** Update the allowlist entry to match the actual dangerous line. The simplest
approach — update `allowlist-populated.md` line 20:

```markdown
### lib/utils.py:18 — SEC-DYNAMIC-EXEC
```

And update the fixture header comment from "line ~5" to "line ~18". Then update the test
script's hardcoded expected values at lines 273, 288, 302, 317, and 398 accordingly.

---

## Info

### IN-01: "six H2 sections" claim is incorrect — there are five

**File:** `components/audit-output-format.md:64`

**Issue:** The Section Order prose says "the report MUST contain these **six** H2 sections"
but the numbered list has exactly **five** items. The count "six" originates from D-13 in
CONTEXT.md which lists 6 items total (YAML frontmatter + 5 H2 sections), but YAML
frontmatter is not an H2 section. Phase 15's parser navigates by literal H2 headings so the
incorrect count does not break runtime behavior, but it misleads spec readers.

**Fix:** Change "six H2 sections" to "five H2 sections" at line 64.

---

### IN-02: Full Report Skeleton examples use different rule IDs and line numbers than the actual fixtures

**File:** `components/audit-output-format.md:232-238`

**Issue:** The Full Report Skeleton's Skipped section examples use `SEC-EVAL` and
`src/legacy.js:14`, but the actual test fixture and mock report use `SEC-DYNAMIC-EXEC`
and `src/legacy.js:18`. The allowlist row uses `SEC-EVAL` for `lib/utils.py:5` while the
fixture uses `SEC-DYNAMIC-EXEC`. These are illustrative examples so they have no runtime
impact, but they diverge from the canonical fixture that Phase 15 and future contributors
would compare against.

**Fix (optional):** Align the skeleton examples to match the fixture rule IDs and line
numbers, or add a note that the skeleton uses synthetic values independent of the regression
fixture.

---

### IN-03: Coverage Dimension 3 (surviving finding full schema) is tested only indirectly

**File:** `scripts/tests/test-audit-pipeline.sh`

**Issue:** The 14-VALIDATION.md Coverage Dimensions require asserting that a surviving
finding "renders full schema (D-14)." Test Group 3 (line 140) asserts that
`audit-output-format.md` has all 9 field definitions in its numbered list — a check on the
SOT document, not on an actual report output. The mock report in Test Group 8 contains a
complete `### Finding F-001` entry, but no assertion validates that the mock report's finding
entry contains all required byte-exact bullet labels. A future edit that removes a field from
the mock report would still pass all 82 tests.

**Fix (optional):** Add assertions in Test Group 8 verifying the bullet labels in the mock
report:

```bash
for field_label in '**Severity:**' '**Rule:**' '**Location:**' '**Claim:**' \
                   '**Code:**' '**Data flow:**' '**Why it is real:**' '**Suggested fix:**'; do
    if grep -qF "$field_label" "$MOCK_REPORT"; then
        report_pass "Mock report finding: field label present: $field_label"
    else
        report_fail "Mock report finding: field label missing: $field_label"
    fi
done
```

---

_Reviewed: 2026-04-25T21:20:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
