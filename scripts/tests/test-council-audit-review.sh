#!/bin/bash
# Claude Code Toolkit - test-council-audit-review.sh
# Validates Phase 15 council audit-review mode: verdict slot rewrite, council_pass
# frontmatter mutation, parallel dispatch, disagreement handling, malformed-output
# parse error, severity-not-reclassified guarantee, FP-nudge / disputed-prompt UX text,
# Modes-section documentation. Wired as Makefile Test 19.
# Usage: bash scripts/tests/test-council-audit-review.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/scripts/tests/fixtures/council"
PROMPT_FILE="$REPO_ROOT/scripts/council/prompts/audit-review.md"
BRAIN="$REPO_ROOT/scripts/council/brain.py"
AUDIT_CMD="$REPO_ROOT/commands/audit.md"
COUNCIL_CMD="$REPO_ROOT/commands/council.md"

if [ ! -d "$FIXTURE_DIR" ]; then
    printf 'ERROR: fixture dir not found at %s\n' "$FIXTURE_DIR" >&2
    exit 1
fi

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-council-audit-review.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# =============================================================================
# Test Group 1 — Plan 15-01 prompt static contracts
# =============================================================================

if [ ! -f "$PROMPT_FILE" ]; then
    report_fail "Plan 15-01 prompt file missing: $PROMPT_FILE"
else
    report_pass "Plan 15-01 prompt file exists"

    PROMPT_LINES=$(wc -l < "$PROMPT_FILE" | tr -d ' ')
    if [[ "$PROMPT_LINES" -ge 100 && "$PROMPT_LINES" -le 180 ]]; then
        report_pass "Plan 15-01 prompt: line count $PROMPT_LINES in [100, 180]"
    else
        report_fail "Plan 15-01 prompt: line count $PROMPT_LINES outside [100, 180]"
    fi

    if grep -qF 'DO NOT reclassify severity' "$PROMPT_FILE"; then
        report_pass "Plan 15-01 prompt: COUNCIL-02 phrase 'DO NOT reclassify severity' present"
    else
        report_fail "Plan 15-01 prompt: COUNCIL-02 phrase missing"
    fi

    if grep -qF '| ID | verdict | confidence | justification |' "$PROMPT_FILE"; then
        report_pass "Plan 15-01 prompt: COUNCIL-03 column header byte-exact"
    else
        report_fail "Plan 15-01 prompt: COUNCIL-03 column header missing"
    fi

    for marker in '<verdict-table>' '</verdict-table>' '<missed-findings>' '</missed-findings>'; do
        if grep -qF "$marker" "$PROMPT_FILE"; then
            report_pass "Plan 15-01 prompt: D-10 marker '$marker' present"
        else
            report_fail "Plan 15-01 prompt: D-10 marker '$marker' missing"
        fi
    done

    if grep -qF '_pending — run /council audit-review_' "$PROMPT_FILE"; then
        report_pass "Plan 15-01 prompt: D-18 byte-exact slot string present"
    else
        report_fail "Plan 15-01 prompt: D-18 byte-exact slot string missing"
    fi

    for verdict in 'REAL' 'FALSE_POSITIVE' 'NEEDS_MORE_CONTEXT'; do
        if grep -qF "$verdict" "$PROMPT_FILE"; then
            report_pass "Plan 15-01 prompt: verdict value '$verdict' present"
        else
            report_fail "Plan 15-01 prompt: verdict value '$verdict' missing"
        fi
    done

    if grep -qF 'components/severity-levels.md' "$PROMPT_FILE"; then
        report_pass "Plan 15-01 prompt: D-06 severity-levels.md reference by path present"
    else
        report_fail "Plan 15-01 prompt: D-06 severity-levels.md reference missing"
    fi

    if grep -qF '{REPORT_CONTENT}' "$PROMPT_FILE"; then
        report_pass "Plan 15-01 prompt: {REPORT_CONTENT} interpolation token present"
    else
        report_fail "Plan 15-01 prompt: {REPORT_CONTENT} interpolation token missing"
    fi

    if python3 -c "
import sys
data = open('$PROMPT_FILE').read()
if chr(0x2014) not in data:
    sys.exit(1)
" 2>/dev/null; then
        report_pass "Plan 15-01 prompt: em-dash U+2014 byte integrity"
    else
        report_fail "Plan 15-01 prompt: em-dash U+2014 missing or wrong codepoint"
    fi
fi

# =============================================================================
# Test Group 2 — Plan 15-02 fixtures static contracts
# =============================================================================

FIXTURE_REPORT="$FIXTURE_DIR/audit-report.md"
if [ -f "$FIXTURE_REPORT" ]; then
    report_pass "Plan 15-02 fixture exists: audit-report.md"

    FIXTURE_LINES=$(wc -l < "$FIXTURE_REPORT" | tr -d ' ')
    if [[ "$FIXTURE_LINES" -ge 80 ]]; then
        report_pass "Plan 15-02 fixture: line count $FIXTURE_LINES >= 80"
    else
        report_fail "Plan 15-02 fixture: line count $FIXTURE_LINES < 80"
    fi

    if grep -qE '^council_pass: pending' "$FIXTURE_REPORT"; then
        report_pass "Plan 15-02 fixture: council_pass: pending present"
    else
        report_fail "Plan 15-02 fixture: council_pass: pending missing"
    fi

    for fid in F-001 F-002 F-003; do
        if grep -qF "### Finding $fid" "$FIXTURE_REPORT"; then
            report_pass "Plan 15-02 fixture: $fid heading present"
        else
            report_fail "Plan 15-02 fixture: $fid heading missing"
        fi
    done

    if grep -qF '_pending — run /council audit-review_' "$FIXTURE_REPORT"; then
        report_pass "Plan 15-02 fixture: Council slot placeholder byte-exact"
    else
        report_fail "Plan 15-02 fixture: Council slot placeholder missing"
    fi
else
    report_fail "Plan 15-02 fixture missing: audit-report.md"
fi

for stub in stub-gemini.sh stub-chatgpt.sh stub-malformed.sh; do
    if [ -x "$FIXTURE_DIR/$stub" ]; then
        report_pass "Plan 15-02 stub exists and executable: $stub"
    else
        report_fail "Plan 15-02 stub missing or not executable: $stub"
    fi
done

# =============================================================================
# Test Group 3 — Plan 15-03 commands/audit.md Council Handoff regression guards
# =============================================================================

if [ -f "$AUDIT_CMD" ]; then
    if grep -qF '## Council Handoff (Phase 15)' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: Council Handoff heading present"
    else
        report_fail "commands/audit.md: Council Handoff heading missing"
    fi

    if grep -qF 'Council confirmed F-NNN as FALSE_POSITIVE' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: D-12 FP nudge phrase present (COUNCIL-05)"
    else
        report_fail "commands/audit.md: D-12 FP nudge phrase missing"
    fi

    if grep -qF '/audit-skip <path>:<line> <rule>' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: D-12 nudge syntax present"
    else
        report_fail "commands/audit.md: D-12 nudge syntax missing"
    fi

    if grep -qF 'is disputed:' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: D-13 disputed prompt phrase present"
    else
        report_fail "commands/audit.md: D-13 disputed prompt phrase missing"
    fi

    for opt in '(R)eal' '(F)alse positive' '(N)eeds more context'; do
        if grep -qF "$opt" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: D-13 disputed option '$opt' present"
        else
            report_fail "commands/audit.md: D-13 disputed option '$opt' missing"
        fi
    done

    if grep -qF 'No default' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: D-13 'No default' rule present"
    else
        report_fail "commands/audit.md: D-13 'No default' rule missing"
    fi

    if grep -qiE 'NEVER (writes|auto-writes)' "$AUDIT_CMD"; then
        report_pass "commands/audit.md: COUNCIL-05 'NEVER writes' rule present"
    else
        report_fail "commands/audit.md: COUNCIL-05 'NEVER writes' rule missing"
    fi

    # Phase headings guard — all 6 phases (0-5) must still be present post-edit
    for n in 0 1 2 3 4 5; do
        if grep -qE "^### Phase ${n}" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: Phase $n heading preserved"
        else
            report_fail "commands/audit.md: Phase $n heading lost (regression)"
        fi
    done

    # AUDIT-XX traceability comments
    for req in AUDIT-01 AUDIT-02 AUDIT-03 AUDIT-04 AUDIT-05; do
        if grep -qF "$req" "$AUDIT_CMD"; then
            report_pass "commands/audit.md: $req traceability comment preserved"
        else
            report_fail "commands/audit.md: $req traceability comment lost (regression)"
        fi
    done
else
    report_fail "commands/audit.md not found"
fi

# =============================================================================
# Test Group 4 — Plan 15-05 commands/council.md ## Modes regression guards
# =============================================================================

if [ -f "$COUNCIL_CMD" ]; then
    if grep -qF '## Modes' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: ## Modes heading present (D-14)"
    else
        report_fail "commands/council.md: ## Modes heading missing (D-14)"
    fi

    if grep -qF '### validate-plan (default)' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: validate-plan H3 present"
    else
        report_fail "commands/council.md: validate-plan H3 missing"
    fi

    if grep -qF '### audit-review' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: audit-review H3 present"
    else
        report_fail "commands/council.md: audit-review H3 missing"
    fi

    if grep -qF '/council audit-review --report' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: D-02 invocation syntax present"
    else
        report_fail "commands/council.md: D-02 invocation syntax missing"
    fi

    if grep -qF 'scripts/council/prompts/audit-review.md' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: prompt-file link present (D-14)"
    else
        report_fail "commands/council.md: prompt-file link missing (D-14)"
    fi

    if grep -qF '| ID | verdict | confidence | justification |' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: COUNCIL-03 column header documented"
    else
        report_fail "commands/council.md: COUNCIL-03 column header missing"
    fi

    if grep -qF 'PROCEED / SIMPLIFY / RETHINK / SKIP' "$COUNCIL_CMD"; then
        report_pass "commands/council.md: validate-plan verdict scheme preserved"
    else
        report_fail "commands/council.md: validate-plan verdict scheme lost (regression)"
    fi

    COUNCIL_LINES=$(wc -l < "$COUNCIL_CMD" | tr -d ' ')
    if [[ "$COUNCIL_LINES" -le 210 ]]; then
        report_pass "commands/council.md: line count $COUNCIL_LINES <= 210 (D-14 cap)"
    else
        report_fail "commands/council.md: line count $COUNCIL_LINES > 210 (D-14 cap exceeded)"
    fi
else
    report_fail "commands/council.md not found"
fi

# =============================================================================
# Test Group 5 — Plan 15-04 brain.py static contracts
# =============================================================================

if [ -f "$BRAIN" ]; then
    if grep -qF 'import argparse' "$BRAIN"; then
        report_pass "brain.py: argparse imported"
    else
        report_fail "brain.py: argparse not imported"
    fi

    if grep -qF 'ThreadPoolExecutor' "$BRAIN"; then
        report_pass "brain.py: ThreadPoolExecutor imported (D-08)"
    else
        report_fail "brain.py: ThreadPoolExecutor not imported"
    fi

    for fn in run_audit_review extract_block parse_verdict_table resolve_council_status rewrite_report; do
        if grep -qE "^def ${fn}" "$BRAIN"; then
            report_pass "brain.py: ${fn}() defined"
        else
            report_fail "brain.py: ${fn}() missing"
        fi
    done

    for env in COUNCIL_STUB_GEMINI COUNCIL_STUB_CHATGPT; do
        if grep -qF "$env" "$BRAIN"; then
            report_pass "brain.py: $env env-var hook present"
        else
            report_fail "brain.py: $env env-var hook missing"
        fi
    done

    if python3 "$BRAIN" --help 2>&1 | grep -qF 'audit-review'; then
        report_pass "brain.py: --help shows audit-review mode"
    else
        report_fail "brain.py: --help does not show audit-review mode"
    fi
else
    report_fail "brain.py not found at $BRAIN"
fi

# =============================================================================
# Test Group 6 — End-to-end disputed flow with stubs (D-15-a, b, c, e)
# =============================================================================

# Copy fixture to scratch; keep an unmodified pre-run copy for Group 7 diff
cp "$FIXTURE_REPORT" "$SCRATCH/report.md"
PRE_REPORT="$SCRATCH/pre-report.md"
cp "$FIXTURE_REPORT" "$PRE_REPORT"

# brain.py validates the --report path is inside cwd via validate_file_path().
# Run brain.py from SCRATCH so the relative path "report.md" resolves within it.
set +e
(
    cd "$SCRATCH"
    COUNCIL_STUB_GEMINI="$FIXTURE_DIR/stub-gemini.sh" \
    COUNCIL_STUB_CHATGPT="$FIXTURE_DIR/stub-chatgpt.sh" \
    python3 "$BRAIN" --mode audit-review --report report.md \
        >"$SCRATCH/stdout.log" 2>"$SCRATCH/stderr.log"
)
E2E_RC=$?
set -e

if [[ "$E2E_RC" -eq 0 ]]; then
    report_pass "End-to-end: brain.py --mode audit-review exits 0 with stubs (D-15-a)"
else
    report_fail "End-to-end: brain.py --mode audit-review exited non-zero. stderr: $(cat "$SCRATCH/stderr.log")"
fi

if grep -qF '| ID | verdict | confidence | justification |' "$SCRATCH/report.md"; then
    report_pass "End-to-end: verdict table header byte-exact in rewritten report (D-15-b, COUNCIL-03)"
else
    report_fail "End-to-end: verdict table header missing post-rewrite"
fi

if grep -qE '^council_pass: disputed$' "$SCRATCH/report.md"; then
    report_pass "End-to-end: council_pass mutated to 'disputed' (F-003 disagreement) (D-15-c, COUNCIL-06)"
else
    SEEN_PASS=$(grep -E '^council_pass:' "$SCRATCH/report.md" || true)
    report_fail "End-to-end: council_pass not mutated to disputed (saw: $SEEN_PASS)"
fi

if grep -qE '\| F-001 \| REAL \|' "$SCRATCH/report.md"; then
    report_pass "End-to-end: F-001 row marked REAL (both stubs agree)"
else
    report_fail "End-to-end: F-001 REAL row missing in verdict table"
fi

if grep -qE '\| F-002 \| FALSE_POSITIVE \|' "$SCRATCH/report.md"; then
    report_pass "End-to-end: F-002 row marked FALSE_POSITIVE (both stubs agree)"
else
    report_fail "End-to-end: F-002 FALSE_POSITIVE row missing in verdict table"
fi

if grep -qE '\| F-003 \| disputed \|' "$SCRATCH/report.md"; then
    report_pass "End-to-end: F-003 row marked disputed (D-15-e, COUNCIL-06)"
else
    report_fail "End-to-end: F-003 disputed row missing"
fi

# Confidence for disputed F-003 should be 0.7 = min(stub-gemini=0.9, stub-chatgpt=0.7)
if grep -qE '\| F-003 \| disputed \| 0\.7[0-9]? \|' "$SCRATCH/report.md"; then
    report_pass "End-to-end: F-003 disputed confidence is 0.7 = min(0.9, 0.7) (D-09)"
else
    F003_ROW=$(grep -E '\| F-003 \|' "$SCRATCH/report.md" | head -1 || true)
    report_fail "End-to-end: F-003 disputed confidence not 0.7 (saw: $F003_ROW)"
fi

# =============================================================================
# Test Group 7 — Other sections byte-identical pre/post (D-15-d)
# =============================================================================

# Filter out the two known mutation regions:
#   - council_pass: line in frontmatter (mutated from pending -> disputed)
#   - everything from `## Council verdict` to end of file (slot rewrite + missed findings)
filter_report() {
    awk '
        /^## Council verdict$/ { stop=1 }
        !stop && !/^council_pass:/ { print }
    ' "$1"
}

filter_report "$PRE_REPORT" > "$SCRATCH/pre-filtered.md"
filter_report "$SCRATCH/report.md" > "$SCRATCH/post-filtered.md"

if diff -q "$SCRATCH/pre-filtered.md" "$SCRATCH/post-filtered.md" >/dev/null 2>&1; then
    report_pass "End-to-end: report sections outside Council slot byte-identical pre/post (D-15-d)"
else
    DIFF_OUT=$(diff "$SCRATCH/pre-filtered.md" "$SCRATCH/post-filtered.md" | head -20)
    report_fail "End-to-end: report sections drifted pre/post (D-15-d). Diff: $DIFF_OUT"
fi

# =============================================================================
# Test Group 8 — Severity not reclassified post-audit-review (COUNCIL-02)
# =============================================================================

# Original fixture severities (per Plan 15-02 audit-report.md):
#   F-001: HIGH (SEC-SQL-INJECTION)
#   F-002: HIGH (SEC-EVAL)
#   F-003: MEDIUM (SEC-XSS)
# After audit-review, the ## Findings section's **Severity:** bullets MUST be unchanged.

if grep -A 3 -F '### Finding F-001' "$SCRATCH/report.md" | grep -qF '**Severity:** HIGH'; then
    report_pass "COUNCIL-02: F-001 severity preserved as HIGH"
else
    report_fail "COUNCIL-02: F-001 severity drifted post-audit-review"
fi

if grep -A 3 -F '### Finding F-002' "$SCRATCH/report.md" | grep -qF '**Severity:** HIGH'; then
    report_pass "COUNCIL-02: F-002 severity preserved as HIGH"
else
    report_fail "COUNCIL-02: F-002 severity drifted post-audit-review"
fi

if grep -A 3 -F '### Finding F-003' "$SCRATCH/report.md" | grep -qF '**Severity:** MEDIUM'; then
    report_pass "COUNCIL-02: F-003 severity preserved as MEDIUM"
else
    report_fail "COUNCIL-02: F-003 severity drifted post-audit-review"
fi

# =============================================================================
# Test Group 9 — Malformed backend output -> council_pass: failed + parse error (D-15-f)
# =============================================================================

cp "$FIXTURE_REPORT" "$SCRATCH/malformed-report.md"

# Run from SCRATCH so validate_file_path() in brain.py accepts the relative path.
set +e
(
    cd "$SCRATCH"
    COUNCIL_STUB_GEMINI="$FIXTURE_DIR/stub-malformed.sh" \
    COUNCIL_STUB_CHATGPT="$FIXTURE_DIR/stub-malformed.sh" \
    python3 "$BRAIN" --mode audit-review --report malformed-report.md \
        >"$SCRATCH/malformed-stdout.log" 2>"$SCRATCH/malformed-stderr.log"
)
MALFORMED_RC=$?
set -e

if [[ "$MALFORMED_RC" -ne 0 ]]; then
    report_pass "Malformed: brain.py exited non-zero (D-15-f)"
else
    report_fail "Malformed: brain.py exited 0 (expected non-zero per D-15-f)"
fi

if grep -qE '^council_pass: failed$' "$SCRATCH/malformed-report.md"; then
    report_pass "Malformed: council_pass mutated to 'failed' (D-15-f)"
else
    SEEN_MALF=$(grep -E '^council_pass:' "$SCRATCH/malformed-report.md" || true)
    report_fail "Malformed: council_pass not mutated to 'failed' (saw: $SEEN_MALF)"
fi

if grep -qiF 'Council parse error' "$SCRATCH/malformed-report.md"; then
    report_pass "Malformed: 'Council parse error' message in verdict slot (D-15-f)"
else
    report_fail "Malformed: 'Council parse error' message missing in verdict slot"
fi

# =============================================================================
# Test Group 10 — Backward compat (validate-plan flow not broken)
# =============================================================================

if python3 "$BRAIN" --help >/dev/null 2>&1; then
    report_pass "Backward compat: brain.py --help exits 0"
else
    report_fail "Backward compat: brain.py --help failed"
fi

if python3 "$BRAIN" --help 2>&1 | grep -qF 'plan'; then
    report_pass "Backward compat: --help shows positional 'plan' argument"
else
    report_fail "Backward compat: --help does not show positional plan"
fi

set +e
python3 "$BRAIN" >/dev/null 2>"$SCRATCH/noargs.log"
NOARGS_RC=$?
set -e
if [[ "$NOARGS_RC" -ne 0 ]]; then
    report_pass "Backward compat: brain.py with no args exits non-zero (prints help)"
else
    report_fail "Backward compat: brain.py with no args exited 0 (should be non-zero)"
fi

set +e
python3 "$BRAIN" --mode audit-review >/dev/null 2>"$SCRATCH/missing-report.log"
MISSING_REPORT_RC=$?
set -e
if [[ "$MISSING_REPORT_RC" -ne 0 ]]; then
    report_pass "Backward compat: --mode audit-review without --report exits non-zero (D-02)"
else
    report_fail "Backward compat: --mode audit-review without --report exited 0 (should be non-zero per D-02)"
fi

# =============================================================================
# Results
# =============================================================================

printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
