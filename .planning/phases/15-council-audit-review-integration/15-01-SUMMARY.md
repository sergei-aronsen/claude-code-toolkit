---
phase: 15-council-audit-review-integration
plan: 01
status: complete
completed: 2026-04-25
self_check: PASSED
requirements: [COUNCIL-02, COUNCIL-03, COUNCIL-04]
subsystem: testing
tags: [council, audit, prompt-template, brain.py, markdownlint]

requires: []
provides:
  - "scripts/council/prompts/audit-review.md — SOT prompt for Council audit-review mode"
  - "COUNCIL-02 enforcement: DO NOT reclassify severity constraint (byte-exact)"
  - "COUNCIL-03 enforcement: | ID | verdict | confidence | justification | table header (byte-exact)"
  - "COUNCIL-04 enforcement: Missed Findings section with location/rule/code excerpt/claim/suggested severity"
  - "D-10: <verdict-table> and <missed-findings> wrapper markers for deterministic parser extraction"
  - "D-18: _pending — run /council audit-review_ slot string (U+2014 em-dash) + all 5 bullet labels"
  - "D-07: <!-- File: <path> Lines: <start>-<end> --> code block header contract documented"
  - "{REPORT_CONTENT} interpolation token for brain.py str.replace at runtime"
affects: [15-02, 15-03, 15-04, 15-05, 15-06]

tech-stack:
  added: []
  patterns: ["prompt-as-contract: byte-exact strings in prompt enforce parser invariants in brain.py"]

key-files:
  created: ["scripts/council/prompts/audit-review.md"]
  modified: []

key-decisions:
  - "Place {REPORT_CONTENT} at the bottom of the prompt so constraint instructions precede injected content, reducing prompt-injection risk (T-15-04)"
  - "Severity disagreements routed to advisory section after </missed-findings>, never in verdict table (T-15-01)"
  - "Reference components/severity-levels.md by path only — rubric not redefined in the prompt (D-06)"

patterns-established:
  - "Prompt-as-contract: byte-exact strings in the prompt are the single enforcement point for parser invariants. brain.py does not re-validate; the prompt is the gate."
  - "Advisory-section pattern: disagreements with auditor go in ## Severity disagreements (advisory), not in machine-parsed output blocks"

requirements-completed: [COUNCIL-02, COUNCIL-03, COUNCIL-04]

duration: 8min
completed: 2026-04-25
task_commits:
  - hash: "7723b5d"
    message: "feat(15-01): add Council audit-review prompt SOT"
---

# Phase 15 Plan 01: Council Audit-Review Prompt SOT Summary

**Council audit-review prompt at `scripts/council/prompts/audit-review.md` encodes COUNCIL-02/03/04
via byte-exact contract strings and deterministic `<verdict-table>` / `<missed-findings>` output markers**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-25T20:08:00Z
- **Completed:** 2026-04-25T20:16:56Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `scripts/council/prompts/audit-review.md` (164 lines) — the single source of truth the
  Council `audit-review` mode interpolates into Gemini and ChatGPT requests
- All 15 acceptance criteria pass: byte-exact contract strings verified with `grep -qF` and
  `python3` em-dash byte check; markdownlint clean with project `.markdownlint.json` rules
- Prompt injection defense: `{REPORT_CONTENT}` token placed at end of prompt so role + constraints
  precede injected report content (T-15-04 mitigation)

## Task Commits

1. **Task 1: Create scripts/council/prompts/audit-review.md** - `7723b5d` (feat)

**Plan metadata:** pending docs commit

## Files Created/Modified

- `scripts/council/prompts/audit-review.md` — Council audit-review prompt SOT (164 lines); consumed
  by `brain.py --mode audit-review` via `str.replace("{REPORT_CONTENT}", report_text)`

## Decisions Made

- `{REPORT_CONTENT}` placed at bottom of prompt so model receives role + constraints before
  any injected content — reduces effective surface for prompt-injection attacks inside report text
- Severity disagreements routed to advisory `## Severity disagreements (advisory)` section placed
  after `</missed-findings>`, never inside the machine-parsed verdict table; keeps orchestrator
  extraction deterministic
- Rubric referenced by path (`components/severity-levels.md`) and never redefined inline — prevents
  accidental drift if severity definitions change in the component

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `scripts/council/prompts/audit-review.md` is ready for Plan 15-02 (`commands/audit.md` extension)
  and Plan 15-03 (`commands/council.md` extension) to reference this prompt by path
- Plan 15-04 (`brain.py` `run_audit_review()`) will `str.replace("{REPORT_CONTENT}", ...)` at
  runtime — token is present and verified
- All byte-exact contract strings that Plan 15-04 parser relies on are confirmed present

## Self-Check: PASSED

- `scripts/council/prompts/audit-review.md` exists: FOUND
- Commit `7723b5d` exists: FOUND

---

*Phase: 15-council-audit-review-integration*
*Completed: 2026-04-25*
