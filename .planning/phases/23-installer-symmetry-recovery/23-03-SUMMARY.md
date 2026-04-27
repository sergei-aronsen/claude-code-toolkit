---
phase: 23-installer-symmetry-recovery
plan: "03"
subsystem: testing
tags: [bash, uninstall, keep-state, hermetic-test, makefile, ci, changelog, docs]

requires:
  - phase: 23-02
    provides: KEEP_STATE gate in uninstall.sh and TK_UNINSTALL_KEEP_STATE env-var support

provides:
  - scripts/tests/test-uninstall-keep-state.sh — 3-scenario hermetic test proving KEEP-02 end-to-end
  - Makefile Test 30 block and test-uninstall-keep-state standalone target
  - CI step Tests 21-30 with BANNER-01 + KEEP-01..02 in coverage list
  - CHANGELOG.md [4.4.0] consolidated with BANNER-01 + KEEP-01 + KEEP-02 bullets
  - docs/INSTALL.md Installer Flags table rows and extended sections for --no-banner and --keep-state

affects:
  - Phase 23 (complete — all 3 plans shipped)
  - v4.4.0 release documentation

tech-stack:
  added: []
  patterns:
    - "S1/S2/S3 scenario function shape with mktemp sandbox + trap RETURN cleanup (mirrors test-uninstall.sh)"
    - "TK_UNINSTALL_TTY_FROM_STDIN=1 stdin injection for prompt-loop tests in CI"
    - "assert_pass/assert_fail/assert_eq/assert_contains helpers copied verbatim from test-uninstall-idempotency.sh"
    - "Backup created: output marker as primary not-a-no-op assertion (line 525 of uninstall.sh)"

key-files:
  created:
    - scripts/tests/test-uninstall-keep-state.sh
    - .planning/phases/23-installer-symmetry-recovery/23-03-SUMMARY.md
  modified:
    - Makefile
    - .github/workflows/quality.yml
    - CHANGELOG.md
    - docs/INSTALL.md

key-decisions:
  - "Used 'Backup created:' (line 525) as A2 not-a-no-op marker — proves backup completed AND idempotency guard did not fire"
  - "11 assertions total (S1: 6 incl. control, S2: 2, S3: 1) — exceeds D-14 minimum of 8 required by spec"
  - "Control assertion added in S1: confirms non-keep-state second run deletes state (UN-05 default unchanged)"
  - "S2 sanity assertion: confirms y-branch removed the modified canary (UN-03 default unchanged)"
  - "KEEP-STATE gate placed after diff-q invariant in uninstall.sh (D-07/D-10) — A4 exit-0 proves both"

patterns-established:
  - "Test 30 wiring: same Makefile PHONY + block + standalone + CI step append pattern as Tests 21-29"
  - "D-18 changelog discipline: append to existing [4.4.0] Added section, never create new release block"

requirements-completed:
  - KEEP-02

duration: 3min
completed: 2026-04-27
---

# Phase 23 Plan 03: test-uninstall-keep-state.sh + docs Summary

**KEEP-02 hermetic test proving --keep-state end-to-end: 11 assertions across S1+S2+S3 scenarios; Makefile Test 30 + CI Tests 21-30; CHANGELOG [4.4.0] consolidated with BANNER-01+KEEP-01+KEEP-02; docs/INSTALL.md Installer Flags updated**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-27T10:41:29Z
- **Completed:** 2026-04-27T10:44:30Z
- **Tasks:** 3 of 3
- **Files modified:** 5 (1 created, 4 updated)

## Accomplishments

- Created `scripts/tests/test-uninstall-keep-state.sh` (260 lines, 11 assertions) proving KEEP-02 contract through real `init-local.sh` + `uninstall.sh` round-trips in `/tmp` sandboxes
- Wired Test 30 into Makefile (PHONY + block + standalone target) and renamed CI step `Tests 21-29` → `Tests 21-30` with `BANNER-01, KEEP-01..02` in coverage list
- Consolidated v4.4 release: appended BANNER-01 + KEEP-01 + KEEP-02 bullets to existing `[4.4.0]` Added section (D-18 single-entry invariant), added `--no-banner` and `--keep-state` rows plus extended sections to docs/INSTALL.md

## Task Commits

1. **Task 1: Create test-uninstall-keep-state.sh** — `e7107f9` (test)
2. **Task 2: Wire into Makefile + quality.yml** — `0862092` (chore)
3. **Task 3: CHANGELOG + INSTALL.md docs** — `3f57a33` (docs)

## Files Created/Modified

- `scripts/tests/test-uninstall-keep-state.sh` — new; 3-scenario hermetic test (S1: A1-A4+control, S2: A1+sanity, S3: A1); 11 assertions; shellcheck-clean
- `Makefile` — PHONY append, Test 30 block before "All tests passed!", standalone `test-uninstall-keep-state` target
- `.github/workflows/quality.yml` — step renamed `Tests 21-30`; `BANNER-01, KEEP-01..02` in coverage list; `bash scripts/tests/test-uninstall-keep-state.sh` appended
- `CHANGELOG.md` — three bullets appended to `[4.4.0]` Added section (BANNER-01, KEEP-01, KEEP-02); single release entry preserved per D-18
- `docs/INSTALL.md` — `--no-banner` and `--keep-state` rows added to Installer Flags table; `### --no-banner (v4.4+)` and `### --keep-state for uninstall.sh (v4.4+)` extended sections added

## Decisions Made

- Used `Backup created:` (uninstall.sh line 525) as A2 not-a-no-op marker — proves backup completed AND idempotency guard at line 389 did not fire (stronger than `Creating backup at` at line 514 which fires before success)
- 11 total assertions (vs. D-14 minimum of 8) — added control assertion in S1 and sanity in S2 for free at negligible cost, strengthening regression coverage
- KEEP_STATE gate in uninstall.sh sits after the diff-q invariant check — A4's exit-0 proves both the base-plugin invariant and the KEEP_STATE branch execute correctly
- `--no-banner` row inserted between `--no-bootstrap` and `--no-council` in docs table to maintain alphabetical-ish flag ordering

## Deviations from Plan

None — plan executed exactly as written. All 3 scenario functions (S1+S2+S3) implemented as specified in D-16. All 4 required A1-A4 assertions present in S1 (D-14). Test seams TK_UNINSTALL_HOME, TK_UNINSTALL_LIB_DIR, TK_UNINSTALL_TTY_FROM_STDIN=1, TK_UNINSTALL_KEEP_STATE=1 all present.

## Issues Encountered

None — `make check` clean, shellcheck clean, all 11 assertions pass on first run.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 23 is complete. All 3 plans shipped:

- Plan 23-01: BANNER-01 — `--no-banner` for `init-claude.sh` + `init-local.sh`
- Plan 23-02: KEEP-01 — `--keep-state` gate in `uninstall.sh`
- Plan 23-03: KEEP-02 — hermetic test + distribution docs (this plan)

v4.4.0 milestone ready for `git tag v4.4.0` after milestone verification gate passes. Single `[4.4.0]` CHANGELOG entry consolidates Phase 21 (BOOTSTRAP-01..04) + Phase 22 (LIB-01..02) + Phase 23 (BANNER-01, KEEP-01, KEEP-02) per D-18.

## Known Stubs

None.

## Threat Flags

None — test file uses existing mktemp + trap RETURN patterns, no new network endpoints or auth paths introduced.

---

*Phase: 23-installer-symmetry-recovery*
*Completed: 2026-04-27*
