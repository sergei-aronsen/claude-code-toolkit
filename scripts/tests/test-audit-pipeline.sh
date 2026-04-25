#!/bin/bash
# Claude Code Toolkit - test-audit-pipeline.sh
# Validates schema contracts shipped by Plans 14-01, 14-02, 14-03:
# allowlist parser, FP-recheck schema, report path/frontmatter/Council slot.
# Usage: bash scripts/tests/test-audit-pipeline.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures/audit"
COMPONENTS_DIR="$REPO_ROOT/components"
COMMANDS_DIR="$REPO_ROOT/commands"

if [ ! -d "$FIXTURE_DIR" ]; then
    printf 'ERROR: fixture dir not found at %s\n' "$FIXTURE_DIR" >&2
    exit 1
fi

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-audit-pipeline.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# =============================================================================
# Test Group 1 — SOT Component Existence Guards
# =============================================================================

for comp in audit-fp-recheck.md audit-output-format.md; do
    if [ -f "$COMPONENTS_DIR/$comp" ]; then
        report_pass "SOT component exists: $comp"
    else
        report_fail "SOT component missing: $comp"
    fi
done

# =============================================================================
# Test Group 2 — components/audit-fp-recheck.md schema
# =============================================================================

FP_RECHECK="$COMPONENTS_DIR/audit-fp-recheck.md"

if [ -f "$FP_RECHECK" ]; then
    # Count numbered ordered-list items
    STEP_COUNT="$(grep -cE '^[0-9]+\. \*\*' "$FP_RECHECK" || true)"
    if [ "$STEP_COUNT" -eq 6 ]; then
        report_pass "audit-fp-recheck.md: exactly 6 numbered steps"
    else
        report_fail "audit-fp-recheck.md: expected 6 numbered steps, got $STEP_COUNT"
    fi

    # Each step label present
    for label in "**Read context**" "**Trace data flow**" "**Check execution context**" "**Cross-reference exceptions**" "**Apply platform-constraint rule**" "**Severity sanity check**"; do
        if grep -qF "$label" "$FP_RECHECK"; then
            report_pass "audit-fp-recheck.md: step label present: $label"
        else
            report_fail "audit-fp-recheck.md: step label missing: $label"
        fi
    done

    # Section headings present
    if grep -qF '## Skipped (FP recheck)' "$FP_RECHECK"; then
        report_pass "audit-fp-recheck.md: '## Skipped (FP recheck)' heading present"
    else
        report_fail "audit-fp-recheck.md: '## Skipped (FP recheck)' heading missing"
    fi

    if grep -qF 'dropped_at_step' "$FP_RECHECK"; then
        report_pass "audit-fp-recheck.md: dropped_at_step column present"
    else
        report_fail "audit-fp-recheck.md: dropped_at_step column missing"
    fi
else
    report_fail "Test Group 2 skipped: audit-fp-recheck.md not found"
fi

# =============================================================================
# Test Group 3 — components/audit-output-format.md schema
# =============================================================================

OUT_FORMAT="$COMPONENTS_DIR/audit-output-format.md"

if [ -f "$OUT_FORMAT" ]; then
    # Report path pattern present (D-12)
    if grep -qF '.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md' "$OUT_FORMAT"; then
        report_pass "audit-output-format.md: report path pattern present"
    else
        report_fail "audit-output-format.md: report path pattern missing"
    fi

    # All 7 YAML frontmatter keys
    for key in audit_type timestamp commit_sha total_findings skipped_allowlist skipped_fp_recheck council_pass; do
        if grep -qE "^${key}:" "$OUT_FORMAT"; then
            report_pass "audit-output-format.md: frontmatter key present: $key"
        else
            report_fail "audit-output-format.md: frontmatter key missing: $key"
        fi
    done

    # H2 sections in correct order using line numbers from the full file.
    # The component file has both description H2s (e.g. "## Council Verdict Slot")
    # and the skeleton H2s (e.g. "## Council verdict"). We use the LAST occurrence
    # of each canonical skeleton heading to anchor on the Full Report Skeleton block.
    SUMMARY_LINE="$(grep -n '^## Summary$' "$OUT_FORMAT" | tail -1 | cut -d: -f1 || true)"
    FINDINGS_LINE="$(grep -n '^## Findings$' "$OUT_FORMAT" | tail -1 | cut -d: -f1 || true)"
    SKIP_AL_LINE="$(grep -n '^## Skipped (allowlist)$' "$OUT_FORMAT" | tail -1 | cut -d: -f1 || true)"
    SKIP_FP_LINE="$(grep -n '^## Skipped (FP recheck)$' "$OUT_FORMAT" | tail -1 | cut -d: -f1 || true)"
    COUNCIL_LINE="$(grep -n '^## Council verdict$' "$OUT_FORMAT" | tail -1 | cut -d: -f1 || true)"

    ORDER_OK=true
    for ln in "$SUMMARY_LINE" "$FINDINGS_LINE" "$SKIP_AL_LINE" "$SKIP_FP_LINE" "$COUNCIL_LINE"; do
        if [ -z "$ln" ]; then
            ORDER_OK=false
        fi
    done

    if [[ "$ORDER_OK" == "true" ]] && \
       [[ "$SUMMARY_LINE" -lt "$FINDINGS_LINE" ]] && \
       [[ "$FINDINGS_LINE" -lt "$SKIP_AL_LINE" ]] && \
       [[ "$SKIP_AL_LINE" -lt "$SKIP_FP_LINE" ]] && \
       [[ "$SKIP_FP_LINE" -lt "$COUNCIL_LINE" ]]; then
        report_pass "audit-output-format.md: H2 sections in correct order"
    else
        report_fail "audit-output-format.md: H2 section order wrong (Summary=$SUMMARY_LINE Findings=$FINDINGS_LINE SkipAL=$SKIP_AL_LINE SkipFP=$SKIP_FP_LINE Council=$COUNCIL_LINE)"
    fi

    # All 7 canonical slugs
    for slug in security code-review performance deploy-checklist mysql-performance postgres-performance design-review; do
        if grep -qF "$slug" "$OUT_FORMAT"; then
            report_pass "audit-output-format.md: canonical slug present: $slug"
        else
            report_fail "audit-output-format.md: canonical slug missing: $slug"
        fi
    done

    # 9-field finding entry: fields are in numbered ordered list "N. **Label**"
    FIELD_COUNT="$(grep -cE '^[0-9]+\. \*\*(ID|Severity|Rule|Location|Claim|Code|Data flow|Why it is real|Suggested fix)\*\*' "$OUT_FORMAT" || true)"
    if [ "$FIELD_COUNT" -ge 9 ]; then
        report_pass "audit-output-format.md: all 9 finding entry fields present ($FIELD_COUNT)"
    else
        report_fail "audit-output-format.md: expected 9 finding entry fields, found $FIELD_COUNT"
    fi

    # Verbatim code block format header
    if grep -qF '<!-- File:' "$OUT_FORMAT"; then
        report_pass "audit-output-format.md: verbatim code block header '<!-- File:' present"
    else
        report_fail "audit-output-format.md: verbatim code block header '<!-- File:' missing"
    fi

    # Clamp note present
    if grep -qF 'Range clamped to file bounds' "$OUT_FORMAT"; then
        report_pass "audit-output-format.md: clamp note 'Range clamped to file bounds' present"
    else
        report_fail "audit-output-format.md: clamp note 'Range clamped to file bounds' missing"
    fi

    # Council slot byte-exact (U+2014 em-dash literal)
    if grep -qF '_pending — run /council audit-review_' "$OUT_FORMAT"; then
        report_pass "audit-output-format.md: Council slot string byte-exact present"
    else
        report_fail "audit-output-format.md: Council slot string byte-exact missing"
    fi
else
    report_fail "Test Group 3 skipped: audit-output-format.md not found"
fi

# =============================================================================
# Test Group 4 — commands/audit.md regression guards
# =============================================================================

AUDIT_CMD="$COMMANDS_DIR/audit.md"

if [ -f "$AUDIT_CMD" ]; then
    # 6-phase headings present
    for n in 0 1 2 3 4 5; do
        if grep -qE "^### Phase ${n}" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: Phase $n heading present"
        else
            report_fail "commands/audit.md: Phase $n heading missing"
        fi
    done

    # Allowlist file path present
    if grep -qF '.claude/rules/audit-exceptions.md' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: allowlist path present"
    else
        report_fail "commands/audit.md: allowlist path missing"
    fi

    # Comment-stripping pattern present
    if grep -qF "sed '/^<!--/,/^-->/d'" "$AUDIT_CMD"; then
        report_pass "commands/audit.md: comment-stripping pattern present"
    else
        report_fail "commands/audit.md: comment-stripping pattern missing"
    fi

    # All 7 canonical slugs
    for slug in security code-review performance deploy-checklist mysql-performance postgres-performance design-review; do
        if grep -qF "$slug" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: canonical slug present: $slug"
        else
            report_fail "commands/audit.md: canonical slug missing: $slug"
        fi
    done

    # Backward-compat aliases
    if grep -qF '`code`' "$AUDIT_CMD" || grep -qF "code\`" "$AUDIT_CMD"; then
        report_pass "commands/audit.md: alias 'code' present"
    else
        report_fail "commands/audit.md: alias 'code' missing"
    fi
    if grep -qF '`deploy`' "$AUDIT_CMD" || grep -qF "deploy\`" "$AUDIT_CMD"; then
        report_pass "commands/audit.md: alias 'deploy' present"
    else
        report_fail "commands/audit.md: alias 'deploy' missing"
    fi

    # AUDIT-XX traceability comments
    for req in AUDIT-01 AUDIT-02 AUDIT-03 AUDIT-04 AUDIT-05; do
        if grep -qF "$req" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: traceability comment present: $req"
        else
            report_fail "commands/audit.md: traceability comment missing: $req"
        fi
    done

    # Council handoff
    if grep -qF '/council audit-review' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: Council handoff present"
    else
        report_fail "commands/audit.md: Council handoff missing"
    fi

    # Related Commands extensions
    if grep -qF '/audit-skip' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: Related Commands includes /audit-skip"
    else
        report_fail "commands/audit.md: Related Commands missing /audit-skip"
    fi
    if grep -qF '/audit-restore' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: Related Commands includes /audit-restore"
    else
        report_fail "commands/audit.md: Related Commands missing /audit-restore"
    fi

    # No backtick-text fences in the 6-phase workflow body (only the Usage block
    # at the top of the file legitimately uses ```text for the /audit command
    # synopsis; any ```text inside the 6-Phase Workflow section is an orphan).
    PHASE_SECTION_TEXT_FENCES="$(awk '/^## 6-Phase Workflow/,/^## [A-Z]/' "$AUDIT_CMD" | grep -cE '^\`\`\`text$' || true)"
    if [ "$PHASE_SECTION_TEXT_FENCES" -eq 0 ]; then
        report_pass "commands/audit.md: no orphan \`\`\`text fence in 6-Phase Workflow section"
    else
        report_fail "commands/audit.md: $PHASE_SECTION_TEXT_FENCES orphan \`\`\`text fence(s) in 6-Phase Workflow section"
    fi
else
    report_fail "Test Group 4 skipped: commands/audit.md not found"
fi

# =============================================================================
# Test Group 5 — Allowlist parser regression (Pitfall 3 guard)
# =============================================================================

EXC_FILE="$FIXTURE_DIR/allowlist-populated.md"
STRIPPED="$SCRATCH/stripped.md"

sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED"

# Real entry heading must survive the strip.
if grep -Fxq -- '### lib/utils.py:18 — SEC-DYNAMIC-EXEC' "$STRIPPED"; then
    report_pass "Allowlist parser: real entry heading present after comment strip"
else
    report_fail "Allowlist parser: real entry heading lost during comment strip"
fi

# HTML-commented example heading must NOT survive the strip — Pitfall 3 regression guard.
if ! grep -Fxq -- '### scripts/setup-security.sh:142 — SEC-RAW-EXEC' "$STRIPPED"; then
    report_pass "Allowlist parser: HTML-commented example heading correctly stripped (Pitfall 3 guard)"
else
    report_fail "Allowlist parser: HTML-commented example heading leaked through (Pitfall 3 regression)"
fi

# Extracted triple matches expected.
EXTRACTED="$(grep '^### ' "$STRIPPED" | head -1)"
EXPECTED='### lib/utils.py:18 — SEC-DYNAMIC-EXEC'
if [ "$EXTRACTED" = "$EXPECTED" ]; then
    report_pass "Allowlist parser: extracted heading matches expected triple"
else
    report_fail "Allowlist parser: extracted '$EXTRACTED' != expected '$EXPECTED'"
fi

# =============================================================================
# Test Group 6 — Em-dash byte integrity (U+2014)
# =============================================================================

if python3 -c "
import sys
data = open('$EXC_FILE').read()
lines = [l for l in data.splitlines() if 'lib/utils.py:18' in l]
if not lines:
    print('FAIL: lib/utils.py:18 heading not found')
    sys.exit(1)
heading = lines[0]
sep_idx = heading.find('—')
if sep_idx == -1:
    print('FAIL: separator not found in heading')
    sys.exit(1)
sep_char = heading[sep_idx]
codepoint = ord(sep_char)
if codepoint != 0x2014:
    print('FAIL: expected U+2014, got U+%04X' % codepoint)
    sys.exit(1)
" 2>/dev/null; then
    report_pass "Em-dash byte integrity: separator in lib/utils.py:18 heading is U+2014"
else
    report_fail "Em-dash byte integrity: separator is NOT U+2014"
fi

# =============================================================================
# Test Group 7 — Report filename regex (all 7 canonical slugs)
# =============================================================================

TIMESTAMP="$(date '+%Y-%m-%d-%H%M')"
for slug in security code-review performance deploy-checklist mysql-performance postgres-performance design-review; do
    FILENAME="${slug}-${TIMESTAMP}.md"
    if printf '%s' "$FILENAME" | grep -qE '^[a-z-]+-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.md$'; then
        report_pass "Report filename regex matches: $FILENAME"
    else
        report_fail "Report filename regex FAILED: $FILENAME"
    fi
done

# =============================================================================
# Test Group 8 — Mock report YAML frontmatter (all 7 keys)
# =============================================================================

MOCK_REPORT="$SCRATCH/mock-report.md"
cat > "$MOCK_REPORT" << 'REPORT_EOF'
---
audit_type: security
timestamp: "2026-04-25-1730"
commit_sha: a1b2c3d
total_findings: 1
skipped_allowlist: 1
skipped_fp_recheck: 1
council_pass: pending
---

# Security Audit — claude-code-toolkit

## Summary

| severity | count_reported | count_skipped_allowlist | count_skipped_fp_recheck |
|----------|----------------|-------------------------|--------------------------|
| HIGH | 1 | 1 | 1 |

## Findings

### Finding F-001

- **Severity:** HIGH
- **Rule:** SEC-SQL-INJECTION
- **Location:** src/auth.ts:14
- **Claim:** User-supplied id flows into a string-concatenated SQL query without parameterization.

**Code:**

<!-- File: src/auth.ts Lines: 1-24 -->

```ts
const sql = "SELECT * FROM users WHERE id=" + id;
```

**Data flow:**

- `req.params.id` arrives from the HTTP route handler.
- Passed unchanged into `db.query()`.

**Why it is real:**

The literal string concatenation at src/auth.ts:14 combines `req.params.id` directly into the
SQL string. No parameterized binding exists between origin and sink.

**Suggested fix:**

```ts
const sql = "SELECT * FROM users WHERE id=?";
db.query(sql, [id]);
```

## Skipped (allowlist)

| ID | path:line | rule | council_status |
|----|-----------|------|----------------|
| F-A001 | lib/utils.py:18 | SEC-DYNAMIC-EXEC | unreviewed |

## Skipped (FP recheck)

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| sample-project/src/legacy.js:18 | SEC-DYNAMIC-EXEC | 3 | eval is reached only when isBuildTime() is true; never executed at request time |

## Council verdict

_pending — run /council audit-review_
REPORT_EOF

# Verify all 7 YAML frontmatter keys in mock report
for key in audit_type timestamp commit_sha total_findings skipped_allowlist skipped_fp_recheck council_pass; do
    if grep -qE "^${key}:" "$MOCK_REPORT"; then
        report_pass "Mock report YAML: key present: $key"
    else
        report_fail "Mock report YAML: key missing: $key"
    fi
done

# =============================================================================
# Test Group 9 — Council slot byte-exact (D-15)
# =============================================================================

if grep -Fxq '_pending — run /council audit-review_' "$MOCK_REPORT"; then
    report_pass "Council slot string byte-exact (D-15): present in mock report"
else
    report_fail "Council slot string byte-exact (D-15): not found in mock report"
fi

# =============================================================================
# Test Group 10 — dropped_at_step range + physical FP-recheck fixture
# =============================================================================

LEGACY_JS="$FIXTURE_DIR/sample-project/src/legacy.js"

# 10.1: Physical fixture file exists
if [ -f "$LEGACY_JS" ]; then
    report_pass "Test Group 10: legacy.js fixture exists"
else
    report_fail "Test Group 10: legacy.js fixture not found at $LEGACY_JS"
fi

# 10.2: Build-time guard present in fixture
if grep -qE 'isBuildTime|process\.env\.BUILD' "$LEGACY_JS"; then
    report_pass "Test Group 10: build-time guard present in legacy.js"
else
    report_fail "Test Group 10: build-time guard missing from legacy.js"
fi

# 10.3: eval-pattern present in fixture
if grep -qE 'eval|Function\(' "$LEGACY_JS"; then
    report_pass "Test Group 10: eval/Function pattern present in legacy.js"
else
    report_fail "Test Group 10: eval/Function pattern missing from legacy.js"
fi

# 10.4-6: Assert FP-recheck row in mock report references the physical fixture
if grep -qF 'sample-project/src/legacy.js:' "$MOCK_REPORT"; then
    report_pass "Test Group 10: mock report Skipped (FP recheck) row references legacy.js"
else
    report_fail "Test Group 10: mock report missing legacy.js reference in Skipped (FP recheck)"
fi

# 10.5: Extract dropped_at_step from the legacy.js row and verify it is 3
FP_ROW="$(grep 'sample-project/src/legacy.js:' "$MOCK_REPORT" | head -1)"
if [ -n "$FP_ROW" ]; then
    DROPPED_STEP="$(printf '%s' "$FP_ROW" | awk -F'|' '{gsub(/ /,"",$4); print $4}')"
    # Verify it is an integer in range 1-6
    if printf '%s' "$DROPPED_STEP" | grep -qE '^[1-6]$'; then
        report_pass "Test Group 10: dropped_at_step='$DROPPED_STEP' is integer in 1-6"
    else
        report_fail "Test Group 10: dropped_at_step='$DROPPED_STEP' is NOT integer in 1-6"
    fi
    # Verify specifically it is 3 (Step 3 = execution context for build-time eval)
    if [ "$DROPPED_STEP" = "3" ]; then
        report_pass "Test Group 10: dropped_at_step is 3 (Step 3 = execution context)"
    else
        report_fail "Test Group 10: dropped_at_step is '$DROPPED_STEP', expected 3 (execution context)"
    fi
else
    report_fail "Test Group 10: no legacy.js row found in mock report"
fi

# =============================================================================
# Results
# =============================================================================

printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
