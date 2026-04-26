---
phase: 15-council-audit-review-integration
plan: "03"
subsystem: documentation
tags: [audit, council, false-positive, disputed, ux, commands]

requires:
  - phase: 15-01
    provides: scripts/council/prompts/audit-review.md prompt SOT (referenced in Orchestrator Reference subsection)
  - phase: 14
    provides: commands/audit.md 6-phase workflow and ## Council Handoff stub this plan extends
  - phase: 13
    provides: commands/audit-skip.md (the command the FP nudge directs users to invoke)
provides:
  - "commands/audit.md ## Council Handoff (Phase 15) section now contains three H3 subsections: FALSE_POSITIVE Nudge (COUNCIL-05), Disputed Resolution (D-13), Orchestrator Reference"
  - "D-12 nudge syntax /audit-skip <path>:<line> <rule> documented verbatim"
  - "D-13 disputed prompt with (R)eal / (F)alse positive / (N)eeds more context and No default rule documented verbatim"
  - "Explicit /audit NEVER writes to audit-exceptions.md statement (COUNCIL-05)"
affects:
  - 15-council-audit-review-integration
  - any phase extending commands/audit.md
  - plan 15-04 (brain.py consumer — implements the behaviors documented here)
  - plan 15-06 (regression test — asserts D-12/D-13 strings persist)

tech-stack:
  added: []
  patterns:
    - "FP nudge pattern: structured one-line command hint printed after Council returns FALSE_POSITIVE — user must invoke /audit-skip themselves"
    - "Disputed resolution pattern: three-option single-character prompt with no default, mirroring /audit-restore [y/N] style (Phase 13 EXC-02 contract)"

key-files:
  created: []
  modified:
    - commands/audit.md

key-decisions:
  - "Preserved existing intro paragraph verbatim (COUNCIL-01 language 'incomplete until Council returns' unchanged)"
  - "Three H3 subsections added inside existing H2 — no H2 restructuring"
  - "Both text fenced code blocks carry the 'text' language tag (MD040 compliance)"
  - "Orchestrator Reference subsection added as forward breadcrumb to Plan 15-04 brain.py and Plan 15-01 prompt file"

patterns-established:
  - "D-12 nudge format: 'Council confirmed F-NNN as FALSE_POSITIVE. / To persist: /audit-skip <path>:<line> <rule> <reason>'"
  - "D-13 disputed format: three-option menu, no default, user must choose before audit is complete"

requirements-completed: [COUNCIL-01, COUNCIL-05]

duration: 5min
completed: 2026-04-25
---

# Phase 15 Plan 03: Council Handoff UX Extension Summary

**`/audit` Council Handoff section extended with byte-exact FP nudge (D-12/COUNCIL-05) and disputed three-option prompt (D-13), locking both UX contracts into the user-facing command spec**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-25T20:15:00Z
- **Completed:** 2026-04-25T20:16:54Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `### FALSE_POSITIVE Nudge (COUNCIL-05)` subsection with byte-exact `Council confirmed F-NNN as FALSE_POSITIVE. / To persist: /audit-skip <path>:<line> <rule> "<reason>"` nudge text and explicit `/audit NEVER writes to .claude/rules/audit-exceptions.md directly` rule
- Added `### Disputed Resolution (D-13)` subsection with three-option prompt `(R)eal — keep as a finding` / `(F)alse positive — run /audit-skip` / `(N)eeds more context — leave open in next audit` and no-default rule
- Added `### Orchestrator Reference` subsection pointing to `scripts/council/brain.py --mode audit-review` and `scripts/council/prompts/audit-review.md`
- Preserved existing intro paragraph verbatim (COUNCIL-01 language intact), all 5 AUDIT-XX traceability comments, all 6 phase headings, Framework Detection, and Related Commands

## Task Commits

1. **Task 1: Extend Council Handoff section** - `60ae0d3` (feat)

**Plan metadata:** (committed with docs below)

## Files Created/Modified

- `commands/audit.md` — `## Council Handoff (Phase 15)` section extended from 1 paragraph to 4 paragraphs + 3 H3 subsections + 2 fenced code blocks (+32 lines, 207 → 237 total, within 215-240 band)

## Decisions Made

- Preserved existing intro paragraph verbatim — the COUNCIL-01 "incomplete until Council returns" language was already present; did not merge or rewrite it
- Added three H3 subsections inside the existing H2 rather than restructuring the H2 — minimal diff, zero risk to test-audit-pipeline.sh guards
- Both text code blocks use `text` language tag (MD040) with blank lines before/after (MD031) — verified by markdownlint

## Deviations from Plan

None — plan executed exactly as written. The edit matched the target expansion text from 15-PATTERNS.md and 15-CONTEXT.md D-12/D-13 verbatim.

## Issues Encountered

`npx markdownlint-cli` failed with ENOENT (no package.json in cwd — known repo constraint). Used the globally installed `markdownlint` binary directly, which passed with exit 0. This is consistent with how Phase 14 ran the same check.

## Known Stubs

None. `commands/audit.md` is a documentation file — no data flows, no UI rendering.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. Documentation-only edit.

## Next Phase Readiness

- Plan 15-04 (brain.py `--mode audit-review` implementation) now has the documented UX contract for the behaviors it implements
- Plan 15-06 (regression test) can assert the D-12 and D-13 strings persist in `commands/audit.md`
- test-audit-pipeline.sh 82/82 passing — no regressions from Phase 14

## Self-Check: PASSED

- `commands/audit.md` exists and contains all required strings
- Commit `60ae0d3` confirmed in git log
- markdownlint exits 0
- test-audit-pipeline.sh exits 0 (82 passed, 0 failed)
- Line count 237 — within acceptable band 215-240

---

*Phase: 15-council-audit-review-integration*
*Completed: 2026-04-25*
