---
phase: 19-state-cleanup-idempotency
plan: 01
subsystem: testing
tags: [bash, shellcheck, uninstall, idempotency, sandbox, regression-test]

# Dependency graph
requires:
  - phase: 18-uninstall-core
    provides: "uninstall.sh with UN-06 idempotency guard at lines 296-299"
provides:
  - "Hermetic 5-assertion regression test for UN-06 no-op contract"
  - "Automated gate: missing toolkit-install.json → exit 0 + zero side-effects"
affects: [19-02, 19-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TK_UNINSTALL_HOME + TK_UNINSTALL_LIB_DIR sandbox seam for hermetic shell tests"
    - "find -newer MARKER_FILE for zero-side-effects assertion in bash tests"
    - "assert_contains with literal ✓ glyph for log_success vs log_info distinction"

key-files:
  created:
    - scripts/tests/test-uninstall-idempotency.sh
  modified: []

key-decisions:
  - "assert_contains patterns use plain grep -q (not -qE) so ✓ glyph requires no escaping"
  - "Trap uses ${SANDBOX:?} and ${MARKER_FILE:?} guards to prevent rm -rf on empty var (T-19-01-01)"
  - "A2 omits trailing period from pattern so cosmetic punctuation changes cannot break the test"

patterns-established:
  - "Idempotency test pattern: mktemp sandbox + MARKER_FILE + TK_UNINSTALL_HOME seam + 5 assertions (A1 exit code, A2 message, A3 prefix, A4 no-backup, A5 zero new files)"

requirements-completed: [UN-06]

# Metrics
duration: 8min
completed: 2026-04-26
---

# Phase 19 Plan 01: State Cleanup + Idempotency Summary

**Hermetic 5-assertion bash test that locks the UN-06 no-op contract: absent toolkit-install.json exits 0 with exact log wording and zero filesystem side-effects**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-26T10:00:00Z
- **Completed:** 2026-04-26T10:08:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `scripts/tests/test-uninstall-idempotency.sh` (125 lines, mode 0755, shellcheck clean)
- All 5 assertions pass against Phase 18 baseline `uninstall.sh` guard (lines 296-299)
- UN-06 requirement is now backed by an automated regression test; any future edit to the
  guard's log wording, exit code, or pre-exit side-effects will be caught immediately

## Test Pass Output

```text
Assertions:
  OK A1: no-op exits 0
  OK A2: no-op message present
  OK A3: ✓ success prefix present
  OK A4: no .claude-backup-pre-uninstall-* created on no-op
  OK A5: zero new files created in sandbox after no-op

✓ test-uninstall-idempotency: all 5 assertions passed
```

## Task Commits

1. **Task 1: Create scripts/tests/test-uninstall-idempotency.sh** - `7fa2e8f` (test)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `scripts/tests/test-uninstall-idempotency.sh` - Hermetic 5-assertion test for UN-06 idempotency guard

## Decisions Made

- Used plain `grep -q` (not `-qE`) in `assert_contains` so the `✓` glyph needs no escaping
- Trap uses `${SANDBOX:?}` and `${MARKER_FILE:?}` parameter-length guards per threat model T-19-01-01
- A2 asserts `'Toolkit not installed; nothing to do'` without trailing period so cosmetic wording tweaks
  (e.g. removing the period) don't break the assertion while still catching phrase regressions
- `HOME="$SANDBOX"` passed at invocation (in addition to `TK_UNINSTALL_HOME`) as defense-in-depth for
  any residual `$HOME` references inside the script

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- UN-06 is now under automated regression coverage
- Plans 19-02 and 19-03 can modify `uninstall.sh` knowing that any regression in the no-op path
  will be caught by this test on every `make check` / CI run

## Known Stubs

None.

## Threat Flags

None — test file introduces no new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- `[ -f scripts/tests/test-uninstall-idempotency.sh ]` → FOUND
- `[ -x scripts/tests/test-uninstall-idempotency.sh ]` → FOUND
- `git log --oneline | grep 7fa2e8f` → FOUND: `7fa2e8f test(19-01): add hermetic idempotency test for UN-06 guard`

---

*Phase: 19-state-cleanup-idempotency*
*Completed: 2026-04-26*
