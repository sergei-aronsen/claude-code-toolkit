#!/bin/bash
# Claude Code Toolkit - test-template-propagation.sh
# Test 20: idempotency + marker-presence regression for propagate-audit-pipeline-v42.sh.
#
# Runs the splice script TWICE on a scratch copy of templates/, asserts:
#   1. Run 1 splices all 49 files (Processed line: "49 spliced, 0 already-spliced, 0 errors")
#   2. Each spliced file carries exactly 4 v42-splice sentinels
#   3. Each spliced file carries the 4 grep-verifiable contract markers
#   4. Run 2 produces zero diff (diff -r empty) and reports "0 spliced, 49 already-spliced"
#
# Usage: bash scripts/tests/test-template-propagation.sh
# Exit:  0 = all pass; 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPLICE_SCRIPT="$REPO_ROOT/scripts/propagate-audit-pipeline-v42.sh"

[ -f "$SPLICE_SCRIPT" ] || { printf 'ERROR: splice script missing: %s\n' "$SPLICE_SCRIPT" >&2; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-template-propagation.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
report_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# =============================================================================
# Test Group 1 — Setup
# =============================================================================

# 1.1: splice script is shellcheck-clean (sanity)
if shellcheck -S warning "$SPLICE_SCRIPT" >/dev/null 2>&1; then
    report_pass "splice script passes shellcheck -S warning"
else
    report_fail "splice script fails shellcheck -S warning"
fi

# 1.2: copy templates/ to scratch
cp -r "$REPO_ROOT/templates" "$SCRATCH/templates"

# 1.3: count source files (must be 49 across the 7 prompt types)
SRC_COUNT=$(find "$SCRATCH/templates" -path '*/prompts/*.md' \
    \( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o \
       -name 'PERFORMANCE_AUDIT.md' -o -name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
       -name 'POSTGRES_PERFORMANCE_AUDIT.md' -o -name 'DEPLOY_CHECKLIST.md' -o \
       -name 'DESIGN_REVIEW.md' \) | wc -l | tr -d ' ')

if [ "$SRC_COUNT" = "49" ]; then
    report_pass "source file count: 49 prompt files (7 frameworks x 7 types)"
else
    report_fail "source file count: expected 49, got $SRC_COUNT"
fi

# =============================================================================
# Test Group 2 — Run 1: splice all 49 files
# =============================================================================

RUN1_LOG="$SCRATCH/run1.log"
if SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT" > "$RUN1_LOG" 2>&1; then
    report_pass "run 1: splice script exited 0"
else
    report_fail "run 1: splice script exited non-zero (see $RUN1_LOG)"
    head -40 "$RUN1_LOG"
fi

# 2.1: run 1 must report all 49 files in a terminal state (either freshly
#      spliced or already-spliced from a previous live-templates apply).
#      The idempotency contract (run 2 byte-identical to run 1) is asserted
#      separately below — what matters here is that no file errored.
if grep -qE 'Processed 49 files: (49 spliced, 0 already-spliced|0 spliced, 49 already-spliced), 0 skipped' "$RUN1_LOG"; then
    report_pass "run 1: 49 files terminal (spliced or already-spliced), 0 errors"
else
    report_fail "run 1: summary does not match expected terminal state"
    grep -F 'Processed' "$RUN1_LOG" | head -3 || true
fi

# =============================================================================
# Test Group 3 — Per-file invariants after run 1
# =============================================================================

SENTINEL_FAIL=0
MARKER_FAIL=0
SLOT_FAIL=0

while IFS= read -r f; do
    rel="${f#"$SCRATCH/"}"

    # 3.1: exactly 4 v42-splice sentinels per file
    count=$(grep -cF '<!-- v42-splice:' "$f" 2>/dev/null || true)
    if [ "$count" != "4" ]; then
        report_fail "sentinel count: expected 4, got $count in $rel"
        SENTINEL_FAIL=$((SENTINEL_FAIL + 1))
    fi

    # 3.2: each named sentinel present exactly once
    for name in callout fp-recheck-section output-format-section council-handoff; do
        n=$(grep -cF "<!-- v42-splice: ${name} -->" "$f" 2>/dev/null || true)
        if [ "$n" != "1" ]; then
            report_fail "sentinel ${name}: expected 1, got $n in $rel"
            SENTINEL_FAIL=$((SENTINEL_FAIL + 1))
        fi
    done

    # 3.3: contract markers (TEMPLATE-03 grep gates Plan 16-04 will mirror)
    # Note: the splice script emits '## Council Handoff' (capital H) — match exactly.
    if ! grep -qF 'Council Handoff' "$f"; then
        report_fail "missing 'Council Handoff' heading in $rel"
        MARKER_FAIL=$((MARKER_FAIL + 1))
    fi
    if ! grep -qF '1. **Read context**' "$f"; then
        report_fail "missing '1. **Read context**' marker in $rel"
        MARKER_FAIL=$((MARKER_FAIL + 1))
    fi

    # 3.4: byte-exact em-dash slot string (U+2014)
    if ! grep -qF '_pending — run /council audit-review_' "$f"; then
        report_fail "missing em-dash slot string in $rel"
        SLOT_FAIL=$((SLOT_FAIL + 1))
    fi

done < <(find "$SCRATCH/templates" -path '*/prompts/*.md' \
    \( -name 'SECURITY_AUDIT.md' -o -name 'CODE_REVIEW.md' -o \
       -name 'PERFORMANCE_AUDIT.md' -o -name 'MYSQL_PERFORMANCE_AUDIT.md' -o \
       -name 'POSTGRES_PERFORMANCE_AUDIT.md' -o -name 'DEPLOY_CHECKLIST.md' -o \
       -name 'DESIGN_REVIEW.md' \) | sort)

if [ "$SENTINEL_FAIL" -eq 0 ]; then
    report_pass "sentinel invariants: all 49 files carry exactly 4 named v42-splice sentinels"
fi
if [ "$MARKER_FAIL" -eq 0 ]; then
    report_pass "contract markers: all 49 files contain 'Council handoff' + '1. **Read context**'"
fi
if [ "$SLOT_FAIL" -eq 0 ]; then
    report_pass "em-dash slot: all 49 files contain '_pending — run /council audit-review_' (U+2014)"
fi

# =============================================================================
# Test Group 4 — Idempotency: run 2 must be no-op
# =============================================================================

# Snapshot post-run-1 state
cp -r "$SCRATCH/templates" "$SCRATCH/templates-after-run1"

RUN2_LOG="$SCRATCH/run2.log"
if SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT" > "$RUN2_LOG" 2>&1; then
    report_pass "run 2: splice script exited 0"
else
    report_fail "run 2: splice script exited non-zero (see $RUN2_LOG)"
fi

# 4.1: run 2 must report "0 spliced, 49 already-spliced"
if grep -qF '0 spliced, 49 already-spliced, 0 skipped' "$RUN2_LOG"; then
    report_pass "run 2: summary reports 0 spliced, 49 already-spliced"
else
    report_fail "run 2: summary does not match '0 spliced, 49 already-spliced'"
    grep -F 'Processed' "$RUN2_LOG" | head -3 || true
fi

# 4.2: zero diff between snapshot and post-run-2 state (idempotency contract D-09)
if diff -r "$SCRATCH/templates-after-run1" "$SCRATCH/templates" >/dev/null 2>&1; then
    report_pass "idempotency: run 2 produces zero diff against post-run-1 snapshot"
else
    report_fail "idempotency: run 2 mutated files (diff -r shows changes)"
    diff -r "$SCRATCH/templates-after-run1" "$SCRATCH/templates" | head -40 || true
fi

# =============================================================================
# Test Group 5 — Partial-splice detection (D-09 negative test)
# =============================================================================

# Take one already-spliced file, remove ONE sentinel to simulate corruption.
# Use awk (portable across BSD + GNU) rather than sed -i which diverges between
# macOS (-i '' required) and Linux (-i.bak or -i).
TARGET="$SCRATCH/templates/base/prompts/CODE_REVIEW.md"
awk '!/<!-- v42-splice: council-handoff -->/' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"

PARTIAL_LOG="$SCRATCH/partial.log"
if SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT" > "$PARTIAL_LOG" 2>&1; then
    report_fail "partial-splice: script should have exited 1 but exited 0"
else
    if grep -qF 'partial-splice (3/4 sentinels)' "$PARTIAL_LOG"; then
        report_pass "partial-splice: script detects 3/4 sentinels and errors out"
    else
        report_fail "partial-splice: script errored but message did not include '3/4 sentinels'"
        head -10 "$PARTIAL_LOG" || true
    fi
fi

# =============================================================================
# Results
# =============================================================================

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
