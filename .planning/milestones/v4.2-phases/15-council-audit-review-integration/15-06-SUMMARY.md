---
phase: 15-council-audit-review-integration
plan: "06"
subsystem: test-infrastructure
tags:
  - testing
  - council
  - audit-review
  - regression
requirements:
  - COUNCIL-02
  - COUNCIL-03
  - COUNCIL-05
  - COUNCIL-06
dependency_graph:
  requires:
    - "15-01"
    - "15-02"
    - "15-03"
    - "15-04"
    - "15-05"
  provides:
    - regression-test-for-council-audit-review-contract
  affects:
    - Makefile
tech_stack:
  added: []
  patterns:
    - "cd SCRATCH + relative path for brain.py validate_file_path() compatibility"
    - "filter_report() awk idiom — drop mutation regions before diff"
key_files:
  created:
    - scripts/tests/test-council-audit-review.sh
  modified:
    - Makefile
decisions:
  - "Run brain.py from SCRATCH dir (cd subshell) so validate_file_path() accepts the /tmp report path — absolute paths outside cwd are rejected by brain.py's security check"
  - "filter_report() uses awk to drop council_pass: line + everything from ## Council verdict onwards before diff — clean way to isolate immutable sections"
metrics:
  duration_minutes: 25
  tasks_completed: 2
  files_created: 1
  files_modified: 1
  completed_date: "2026-04-25"
---

# Phase 15 Plan 06: Council Audit-Review Regression Test — Summary

End-to-end regression scaffold for the Phase 15 Council audit-review contract: 81-assertion, 10-group test in `scripts/tests/test-council-audit-review.sh` wired as Makefile Test 19. Locks every Council audit-review contract dimension against future drift.

## What Was Built

### Task 1 — `scripts/tests/test-council-audit-review.sh`

522-line Bash test script (executable, shellcheck -S warning clean, exits 0) modeled on `test-audit-pipeline.sh`. Implements 10 test groups:

| Group | Subject | Key assertions |
|-------|---------|----------------|
| 1 | Plan 15-01 prompt static contracts | DO NOT reclassify severity, column header, markers, slot string, severity ref, interpolation token, em-dash U+2014 |
| 2 | Plan 15-02 fixture guards | audit-report.md exists ≥80 lines, council_pass: pending, 3 findings, slot placeholder, 3 stubs executable |
| 3 | Plan 15-03 audit.md Council Handoff | FP nudge phrase, /audit-skip syntax, disputed prompt options, No default, NEVER writes, all Phase 0-5 headings, AUDIT-01–05 traceability |
| 4 | Plan 15-05 council.md Modes section | ## Modes H2, validate-plan H3, audit-review H3, invocation syntax, prompt-file link, COUNCIL-03 header, PROCEED/SIMPLIFY verdict scheme, ≤210 lines |
| 5 | Plan 15-04 brain.py static contracts | argparse, ThreadPoolExecutor, 5 functions, COUNCIL_STUB_* env-var hooks, --help shows audit-review |
| 6 | End-to-end disputed flow | exit 0, verdict table header byte-exact, council_pass: disputed, F-001 REAL, F-002 FALSE_POSITIVE, F-003 disputed confidence 0.7 |
| 7 | Other sections byte-identical | filter_report() awk + diff -q guards Summary, Findings, Skipped tables |
| 8 | Severity not reclassified | F-001 HIGH, F-002 HIGH, F-003 MEDIUM preserved post-run (COUNCIL-02) |
| 9 | Malformed output | non-zero exit, council_pass: failed, "Council parse error" in slot |
| 10 | Backward compat | --help exits 0, shows plan, no-args exits non-zero, --mode audit-review without --report exits non-zero |

**Result:** 81 PASS / 0 FAIL.

### Task 2 — Makefile Test 19 wiring

Inserted Test 19 block between Test 18 and "All tests passed!" echo (lines 109-111). TAB-indented recipe lines, em-dash U+2014 in description confirmed. `make test` exits 0.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] brain.py validate_file_path() rejects /tmp SCRATCH paths**

- **Found during:** Task 1, Group 6 first run (9 FAIL)
- **Issue:** `validate_file_path()` in brain.py resolves paths relative to `Path.cwd()` and rejects anything outside the project root. The `/tmp/test-council-audit-review.*/` SCRATCH dir is outside cwd, so `--report $SCRATCH/report.md` was rejected with "Audit report not found or outside project".
- **Fix:** Wrapped both end-to-end brain.py invocations in a `( cd "$SCRATCH"; python3 "$BRAIN" --mode audit-review --report report.md ... )` subshell so the relative path `report.md` resolves inside SCRATCH, which is the cwd for that subprocess.
- **Files modified:** `scripts/tests/test-council-audit-review.sh`
- **Commit:** included in e117df2

## Self-Check

### Verifications

```bash
test -x scripts/tests/test-council-audit-review.sh   # FOUND
shellcheck -S warning scripts/tests/test-council-audit-review.sh  # exit 0
bash scripts/tests/test-council-audit-review.sh       # 81 PASS / 0 FAIL
grep -F 'Test 19:' Makefile                           # FOUND at line 109
make check                                            # All checks passed!
```

Commit e117df2 (`feat(15-06): add Council audit-review regression test`) — verified in git log.
Commit 23177e4 (`feat(15-06): wire Council audit-review test as Makefile Test 19`) — verified in git log.

## Self-Check: PASSED
