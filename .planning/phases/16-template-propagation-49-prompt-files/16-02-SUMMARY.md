---
phase: 16-template-propagation-49-prompt-files
plan: "02"
subsystem: test-infrastructure
tags: [test, idempotency, splice, regression, bash]
requirements: [TEMPLATE-03]
dependency_graph:
  requires: [16-01]
  provides: [Test-20-regression-guard]
  affects: [16-04-Makefile-wiring]
tech_stack:
  added: []
  patterns: [PASS/FAIL-counter, mktemp-scratch-trap, awk-portable-delete]
key_files:
  created:
    - scripts/tests/test-template-propagation.sh
  modified: []
decisions:
  - "Use 'Council Handoff' (capital H) for marker check — matches byte-exact output of splice script (splice script emits '## Council Handoff'). Plan spec said 'Council handoff' (lowercase); fixed to match actual contract."
  - "Use awk for partial-splice sentinel removal (Test Group 5) instead of sed -i to avoid BSD/GNU portability divergence."
metrics:
  duration_minutes: 8
  completed: "2026-04-25"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 16 Plan 02: Test 20 — Template Propagation Regression Summary

**One-liner:** Bash regression test asserting splice-script idempotency (zero diff on run 2) and byte-exact sentinel + marker presence across all 49 prompt files.

## What Was Built

`scripts/tests/test-template-propagation.sh` — Test 20, 195 lines, 5 test groups:

| Group | Description | Assertions |
|-------|-------------|------------|
| 1 | Setup: shellcheck sanity + 49-file count | 2 |
| 2 | Run 1: splice exits 0, summary "49 spliced" | 2 |
| 3 | Per-file: 4 sentinels each + contract markers + em-dash slot | 3 pass/fail buckets covering all 49 files |
| 4 | Idempotency: run 2 exits 0, "0 spliced, 49 already-spliced", zero diff | 3 |
| 5 | Partial-splice negative test: awk removes one sentinel, script must exit 1 | 1 |

End-to-end result: **11 passed, 0 failed**.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong case on 'Council Handoff' marker assertion**

- **Found during:** First end-to-end test run (49/49 FAIL on the marker check)
- **Issue:** Plan spec referenced `'Council handoff'` (lowercase 'h') but the splice script emits `## Council Handoff` (capital H on "Handoff"). The grep was case-sensitive and matched nothing.
- **Fix:** Changed assertion to `grep -qF 'Council Handoff'` matching the byte-exact output of `propagate-audit-pipeline-v42.sh` line 151.
- **Files modified:** `scripts/tests/test-template-propagation.sh`
- **Commit:** 6b2c2d1 (same task commit — fixed inline before staging)

## Portability Notes

- **awk vs sed:** Test Group 5 uses `awk '!/<!-- v42-splice: council-handoff -->/'` to delete a sentinel line. `sed -i` requires `-i ''` on macOS BSD and `-i.bak` (or bare `-i`) on GNU Linux — the awk form is portable across both.
- **wc -l | tr -d ' ':** Used to strip leading whitespace from BSD `wc` output (GNU omits it).
- **find with `\( -name ... -o ... \)`:** Same find expression as the splice script itself — guaranteed to match the same 49 files.

## Shellcheck Notes

No `# shellcheck disable` directives needed. All 195 lines pass `-S warning` cleanly.

## Live Templates Isolation

The test operates exclusively within a `mktemp -d` scratch directory. The invocation pattern is:

```bash
SPLICE_TEMPLATES_DIR="$SCRATCH/templates" bash "$SPLICE_SCRIPT"
```

The live `templates/` directory is never modified. The `trap 'rm -rf "$SCRATCH"' EXIT` cleans up on both success and failure paths.

## Self-Check

- `scripts/tests/test-template-propagation.sh` exists: FOUND
- Commit 6b2c2d1 exists: FOUND
- `shellcheck -S warning` exits 0: CONFIRMED
- `[ -x ... ]` passes: CONFIRMED
- End-to-end: 11 passed, 0 failed

## Self-Check: PASSED
