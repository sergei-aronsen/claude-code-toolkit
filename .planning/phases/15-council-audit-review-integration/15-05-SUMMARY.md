---
phase: 15-council-audit-review-integration
plan: "05"
subsystem: docs
tags: [council, audit-review, commands, markdownlint]

requires:
  - phase: 15-01
    provides: scripts/council/prompts/audit-review.md (prompt SOT referenced by path)
  - phase: 15-04
    provides: brain.py --mode and --report flags documented in new Modes section

provides:
  - "## Modes H2 section in commands/council.md documenting validate-plan and audit-review modes"
  - "User-facing /council audit-review --report <path> invocation surface (COUNCIL-01)"
  - "Per-finding verdict table contract (COUNCIL-03) documented"
  - "Disputed semantics and COUNCIL-06 constraint documented"

affects:
  - 15-06-testing
  - audit-workflow

tech-stack:
  added: []
  patterns:
    - "Modes section pattern: H2 with H3 subsections, each with Invocation/Produces/When to use/Prompt/Output fields"

key-files:
  created: []
  modified:
    - commands/council.md

key-decisions:
  - "Inserted ## Modes between ## Usage and ## When to Use (per insertion target in plan interfaces)"
  - "Used horizontal rule separators between H3 subsections matching existing file style"
  - "Kept net addition to +52 lines (within ≤60 cap, D-14)"
  - "Documented COUNCIL-02/06 constraints inline in audit-review subsection — no separate section needed"

patterns-established:
  - "Modes documentation pattern: each mode gets Invocation (fenced text block), Produces, When to use, Prompt, Output fields"

requirements-completed:
  - COUNCIL-01

duration: 1min
completed: "2026-04-25"
---

# Phase 15 Plan 05: Council Modes Documentation Summary

**`## Modes` section added to `commands/council.md` — surfaces `/council audit-review --report <path>` as user-facing Phase 5 mandatory step with full verdict-table contract (COUNCIL-01/02/03/04/06)**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-04-25T20:31:16Z
- **Completed:** 2026-04-25T20:32:09Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Inserted `## Modes` H2 section (52 net lines) between `## Usage` and `## When to Use`
- Documented `validate-plan` subsection preserving existing PROCEED/SIMPLIFY/RETHINK/SKIP verdict scheme
- Documented `audit-review` subsection with invocation syntax, verdict table column contract, mandatory-Phase-5 framing, COUNCIL-02/06 constraints, and prompt SOT link
- File grew from 144 to 196 lines (net +52, within ≤60 D-14 cap); passes markdownlint

## Task Commits

1. **Task 1: Insert ## Modes section** - `b8a8133` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `commands/council.md` — Added `## Modes` H2 with `### validate-plan (default)` and `### audit-review` H3 subsections

## Decisions Made

- Inserted the new section between Usage and When to Use as specified in the plan interfaces
- Used existing `---` horizontal rule style for subsection separators (matches surrounding file)
- Documented COUNCIL-02/06 constraints inline rather than in a separate section (keeps the section self-contained)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 15-06 (regression tests) can now assert byte-exact presence of all documented contract strings
- `commands/council.md` is complete for v4.2 audit-review integration

---

*Phase: 15-council-audit-review-integration*
*Completed: 2026-04-25*
