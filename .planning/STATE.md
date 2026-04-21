---
gsd_state_version: 1.0
milestone: v4.1
milestone_name: Polish & Upstream
status: defining_requirements
stopped_at: v4.1 milestone initialized — roadmap defined, awaiting Phase 8 discuss
last_updated: "2026-04-21T10:00:00.000Z"
last_activity: 2026-04-21
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** v4.1 Polish & Upstream — Phase 8 (Release Quality) up next.

## Current Position

Milestone: v4.1 Polish & Upstream
Phase: Not started (defining requirements complete, awaiting Phase 8 discuss)
Status: Ready for Phase 8
Last activity: 2026-04-21 — v4.1 milestone initialized

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed (v4.1): 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

_No plans executed yet in v4.1._

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.

Recent v4.1 scope decisions:

- 2026-04-21: v4.1 scope locked from v4.0 deferred items + retrospective inefficiencies — 5 topic areas, 11 REQ-IDs across 4 phases
- 2026-04-21: Upstream GSD CLI bugs (audit-open ReferenceError, milestone-complete summary noise, ROADMAP auto-sync) to be filed as upstream issues, NOT patched in this repo (UPSTREAM-01/02/03 file issues only)
- 2026-04-21: `claude plugin list` becomes secondary detection input — filesystem remains primary (DETECT-06 reverses v4.0 "CLI never" out-of-scope item)
- 2026-04-21: Chose "fast" pacing (skip discuss-milestone + research) — scope is carry-overs from v4.0, well-understood

### Roadmap Evolution

- 2026-04-21: v4.1 roadmap created — 4 phases (8–11), continuing phase numbering from v4.0

### Pending Todos

None yet for v4.1.

### Blockers/Concerns

None at milestone start.

## Deferred Items

v4.0 deferred items now promoted into v4.1:

| v4.0 Deferral | v4.1 REQ-ID | Status |
|---------------|-------------|--------|
| BACKUP-01: --clean-backups flag | BACKUP-01 | Promoted into Phase 9 |
| BACKUP-02: warn on backup count threshold | BACKUP-02 | Promoted into Phase 9 |
| DETECT-FUT-01: claude plugin list integration | DETECT-06 | Promoted into Phase 9 |
| DETECT-FUT-02: plugin version skew detection | DETECT-07 | Promoted into Phase 9 |
| TEST-01: bats automation for install matrix | REL-01 | Promoted into Phase 8 |

v4.2+ carry-overs (locked out of v4.1):

| Category | Item | Status |
|----------|------|--------|
| Locked out | Docker-per-cell isolation | Permanently out (conflicts with POSIX invariant) |
| Locked out | Auto-cut `git tag` from phase execution | Permanently out (CLAUDE.md "never push main") |
| Deferred | Installable GSD CLI wrapper in toolkit | v4.2+ (crosses repo boundary) |

## Session Continuity

Last session: 2026-04-21T10:00:00.000Z
Stopped at: v4.1 milestone initialized — ready for Phase 8 discuss
Resume file: .planning/ROADMAP.md
