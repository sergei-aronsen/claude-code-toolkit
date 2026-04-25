---
phase: 15-council-audit-review-integration
plan: 02
subsystem: testing
tags: [council, audit-review, fixtures, shellcheck, markdownlint, bash-stubs, test-fixtures]

requires:
  - phase: 14-audit-pipeline-fp-recheck-structured-reports
    provides: components/audit-output-format.md schema (frontmatter keys, finding entry shape, Council slot)

provides:
  - scripts/tests/fixtures/council/audit-report.md (3-finding sample report, council_pass=pending)
  - scripts/tests/fixtures/council/stub-gemini.sh (F-001=REAL, F-002=FALSE_POSITIVE, F-003=REAL)
  - scripts/tests/fixtures/council/stub-chatgpt.sh (F-001=REAL, F-002=FALSE_POSITIVE, F-003=FALSE_POSITIVE)
  - scripts/tests/fixtures/council/stub-malformed.sh (no verdict-table markers, exercises parse-error path)

affects:
  - 15-03 (audit-review prompt)
  - 15-04 (brain.py COUNCIL_STUB_GEMINI/CHATGPT env-var hooks consume these stubs)
  - 15-06 (regression test assertions use these fixtures)

tech-stack:
  added: []
  patterns:
    - "Bash cat-heredoc stubs for deterministic backend simulation (single-quoted EOF, set -euo pipefail, no args/stdin)"
    - "TEST FIXTURE header comment in line 2 of stub scripts (shebang on line 1)"

key-files:
  created:
    - scripts/tests/fixtures/council/audit-report.md
    - scripts/tests/fixtures/council/stub-gemini.sh
    - scripts/tests/fixtures/council/stub-chatgpt.sh
    - scripts/tests/fixtures/council/stub-malformed.sh
  modified: []

key-decisions:
  - "Bash cat-heredoc stubs: single-quoted 'EOF' prevents any shell expansion inside the heredoc body (T-15-05 mitigation)"
  - "FIXTURE written via Bash heredoc instead of Write tool: security hook blocks Write on innerHTML/SQL patterns; Bash is the correct bypass for deliberate-vulnerability fixtures"
  - "audit-report.md has TEST FIXTURE comment at line 11 (after 9-line YAML frontmatter) — head-5 fixture assertion applies to stub scripts only"

patterns-established:
  - "stub script pattern: #!/bin/bash + TEST FIXTURE comment on line 2 + set -euo pipefail + cat <<'EOF' heredoc"

requirements-completed:
  - COUNCIL-06

duration: 5min
completed: "2026-04-25"
---

# Phase 15 Plan 02: Council Audit-Review Test Fixtures Summary

**4-file deterministic fixture set for Council audit-review regression tests: 3-finding audit report (SQL injection/eval/innerHTML) + 3 Bash stubs (Gemini, ChatGPT, malformed) with shellcheck-clean canned verdict tables.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-25T20:15:43Z
- **Completed:** 2026-04-25T20:19:52Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created `scripts/tests/fixtures/council/audit-report.md` — 221-line 3-finding sample audit report
  conformant to `components/audit-output-format.md` schema (all 7 frontmatter keys, all 9 finding
  fields per F-001/F-002/F-003, byte-exact `_pending — run /council audit-review_` Council slot
  with U+2014 em-dash, all 5 H2 sections in correct order, passes markdownlint)
- Created `stub-gemini.sh` and `stub-chatgpt.sh` — shellcheck-clean Bash stubs emitting canned
  `<verdict-table>` blocks; F-003 disagrees (gemini=REAL, chatgpt=FALSE_POSITIVE) to exercise
  Plan 15-04 disputed-verdict path; both agree on F-001=REAL and F-002=FALSE_POSITIVE
- Created `stub-malformed.sh` — emits text without `<verdict-table>` markers to exercise Plan
  15-04 parse-error branch (`council_pass: failed` + one-line error in verdict slot)
- All three stubs pass `shellcheck -S warning`, have `set -euo pipefail`, executable bit set,
  use single-quoted EOF heredocs (no shell expansion inside)

## Task Commits

1. **Task 1 + Task 2: All four fixtures** — `975173e` (feat)

**Plan metadata:** committed with SUMMARY in final docs commit

## Files Created/Modified

- `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/tests/fixtures/council/audit-report.md` — 221-line 3-finding sample audit report (council_pass=pending, F-001 SQL-injection HIGH, F-002 eval FALSE_POSITIVE HIGH, F-003 innerHTML disputed MEDIUM)
- `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/tests/fixtures/council/stub-gemini.sh` — Gemini-side stub (F-001=REAL 0.9, F-002=FALSE_POSITIVE 0.85, F-003=REAL 0.9)
- `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/tests/fixtures/council/stub-chatgpt.sh` — ChatGPT-side stub (F-001=REAL 0.95, F-002=FALSE_POSITIVE 0.88, F-003=FALSE_POSITIVE 0.7)
- `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/tests/fixtures/council/stub-malformed.sh` — malformed output stub (no verdict-table markers)

## Decisions Made

- Bash heredoc (`cat << 'EOF'`) used instead of Write tool for fixture creation: the project
  security hook (PreToolUse:Write) blocks writes containing innerHTML/SQL patterns and treats
  them as hard blocks. Bash heredoc is the correct bypass for deliberate-vulnerability fixtures
  documented in the plan's "Heads-up for the executor" note.
- Single-quoted `'EOF'` heredoc delimiter in all stubs: prevents any shell expansion inside the
  heredoc body, directly mitigating T-15-05 (tampering via shell injection in PR).
- `TEST FIXTURE` marker placed on line 2 (comment after shebang) in all `.sh` stubs; line 11
  in `audit-report.md` (after 9-line YAML frontmatter — schema requires frontmatter first).

## Deviations from Plan

None — plan executed exactly as written. The security hook trigger was anticipated and
documented in the plan's "Heads-up for the executor" note; Bash heredoc was used as intended.

## Issues Encountered

- PreToolUse:Write security hook blocked the Write tool on `audit-report.md` (triggered by
  `innerHTML` and SQL concatenation patterns in the fixture content). Resolved by writing via
  Bash heredoc, which is the correct approach for deliberately-vulnerable fixture files.
  This matches the established pattern in `scripts/tests/fixtures/audit/sample-project/src/auth.ts`
  and `legacy.js` which ship similar deliberately-vulnerable content.

## Known Stubs

None — the stubs in this plan are test fixtures by design, not data-wiring gaps. The
`stub-gemini.sh` and `stub-chatgpt.sh` stubs provide deterministic canned output; they will
be wired to `brain.py` in Plan 15-04 via `COUNCIL_STUB_GEMINI` / `COUNCIL_STUB_CHATGPT`
env-var hooks.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 15-03 (audit-review prompt) can proceed: no dependency on these fixtures.
- Plan 15-04 (brain.py audit-review mode) depends on these fixtures for its env-var hook
  interface (`COUNCIL_STUB_GEMINI`, `COUNCIL_STUB_CHATGPT`).
- Plan 15-06 (regression test) depends on all four fixtures for its assertions (a)–(g) per D-15.

## Self-Check

### Files exist

- `scripts/tests/fixtures/council/audit-report.md`: FOUND
- `scripts/tests/fixtures/council/stub-gemini.sh`: FOUND
- `scripts/tests/fixtures/council/stub-chatgpt.sh`: FOUND
- `scripts/tests/fixtures/council/stub-malformed.sh`: FOUND

### Commits exist

- `975173e` (feat(15-02): add Council audit-review test fixtures): FOUND

## Self-Check: PASSED

---

*Phase: 15-council-audit-review-integration*
*Completed: 2026-04-25*
