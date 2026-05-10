---
gsd_state_version: 1.0
milestone: v6.15.x
milestone_name: "Meta-Audit Wave-2 Architecture Pass (post-Council)"
status: in_progress
last_updated: "2026-05-10T18:00:00Z"
last_activity: 2026-05-10
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 3
  completed_plans: 2
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-06)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** v6.15.x architecture pass on the 7 base prompts. Council validated the plan on 2026-05-10 with verdict SIMPLIFY (both Skeptic and Pragmatist) — see `.claude/scratchpad/council-v615-2026-05-10.md`. Three sequential phases.

## Current Position

Active milestone: v6.15.0 (planning, started 2026-05-10).

Recently shipped (2026-05-06 → 2026-05-10):

- v6.0 (2026-05-06) — Toolkit overlay redesign (PRs #41-47)
- v6.1 (2026-05-06) — Morph→Serena swap + 5 audit findings (PRs #49-53)
- v6.3 (2026-05-07) — Product-thinking gate + vendor changelog + auto-format hook (PR #60)
- v6.4 (2026-05-07) — Project-scope MCP storage redesign (PR #66)
- v6.11 (2026-05-08) — CODE_REVIEW regression rewrite (PR #77)
- v6.12 (2026-05-08) — SECURITY_AUDIT adversarial rewrite (PR #78)
- v6.12.1 (2026-05-09) — Meta-audit cleanup (PR #79)
- v6.13.0 (2026-05-09) — F-006 propagator demote + 5-prompt meta-audit (PR #81)
- v6.14.0 (2026-05-10) — Base-prompt meta-audit wave 1: F-101/F-104/F-107/F-111 (PR #82)
- v6.14.1 (2026-05-10) — wave-2 surgical (PR #84): F-357, F-381, F-320, F-232 + 3 FP drops
- v6.14.2 (2026-05-10) — wave-2 calibration (PR #86): F-221, F-261/F-263/F-265, F-380, F-385, F-396, F-352/F-365, F-367 + 3 FP drops
- v6.14.3 (2026-05-10) — wave-2 calibration (PR #87): F-242, F-243, F-358, F-360, F-361, F-398 + 3 FP drops

Wave-2 progress: **23/139 closed + 9 FP drops = 32 of 139 resolved**. Remaining ~107.

## Active Phases

### Phase 1 — v6.15.0 — DEPLOY rework (council Decision 1) ✅

**Status:** Shipped (PR #88, commit f6d9140, 2026-05-10). Risk realized: MEDIUM, no surprises.

Strip audit machinery from `templates/base/prompts/DEPLOY_CHECKLIST.md` per F-290. Council additions over my original plan:

- ALSO strip the QUICK CHECK table — Skeptic flagged it as audit-pattern artifact, not deploy procedure (F-291).
- Update 4 infrastructure files, not just splice script (Pragmatist):
  - `scripts/propagate-audit-pipeline-v42.sh:603-607` (config-driven exclusion)
  - `Makefile:341-367` (validate-templates exclusion)
  - `.github/workflows/quality.yml:82-119` (CI gate exclusion)
  - `scripts/tests/test-template-propagation.sh:46-50` (test fixture exclusion)
- Add auth/crypto-specific monitoring story to phases 5 & 7 (Pragmatist) — auth-failure metrics, anomaly alerts, audit logs, rollback triggers tied to account takeover risk.

Closes wave-2 findings: F-290..F-306 (17 findings).

### Phase 2 — v6.15.1 — DESIGN identity split (council Decision 2) ✅

**Status:** Shipped (commit pending PR, 2026-05-10). Risk realized: LOW.

Council APPROVED. Delete Phase 7 ("Code Health") from `templates/base/prompts/DESIGN_REVIEW.md` (F-321, F-329). Re-home content:

- Component reuse + design tokens + magic numbers → `templates/base/prompts/CODE_REVIEW.md` (architecture sub-section).
- Bundle size + lazy loading → `templates/base/prompts/PERFORMANCE_AUDIT.md` (frontend perf sub-section).

Closes wave-2 findings: F-321, F-329, partial F-326. Other DESIGN_REVIEW findings (F-322, F-324, F-327, F-328) sequenced for v6.14.4 or after Phase 3.

### Phase 3 — v6.15.2 — Framework drift via components splice (council Decision 3, REVISED)

**Status:** Planning. Risk: MEDIUM (lower than original sentinel-sync plan).

**Original plan REJECTED by Skeptic.** Sentinel sync was overengineered (~560 manual sentinel insertions across 16 files). Use existing component-splice infrastructure.

**Revised approach:** Extract drifting sections from `templates/base/prompts/*.md` into new components:

- `components/audit-severity-anchor.md` — canonical severity rubric reference + Severity Ceiling Table (F-242).
- `components/audit-uncertainty-discipline.md` — UNCERTAINTY DISCIPLINE block (parity across all 7 audits, addresses F-204, F-301, F-327).
- `components/audit-fp-control-gates.md` — FALSE-POSITIVE CONTROL three-gate structure (F-260, F-324, F-363).

Extend `scripts/propagate-audit-pipeline-v42.sh` with new splice blocks + sentinels for these components (the script already does this for callout / fp-recheck / output-format / council-handoff — adding 3 more blocks is ~50 lines of code, not 560 manual insertions).

Re-splice all 35 framework prompts via `--force`. Frameworks gain v6.14.x severity rubric / FP gates / uncertainty discipline without per-file work.

Closes wave-2 findings: F-204, F-260, F-272, F-301, F-324, F-327, F-363 + framework-drift backlog (KNOWN-DEBT-1).

## Session Continuity

Last session: 2026-05-10
Started: v6.15.0 planning post-Council

**Next steps:**

1. ✅ Phase 1 — DEPLOY rework: shipped as PR #88 (f6d9140). Awaiting merge.
2. ✅ Phase 2 — DESIGN split: shipped on `fix/v615-1-design-split` branch. PR pending.
3. ▶ Phase 3 — Framework drift via components: extract 3 new components, extend splice pipeline, re-splice 35 files, ship as PR.

After all 3 phases, re-evaluate remaining wave-2 findings (~80 left after architecture pass) for surgical close-out.

## Deferred Findings

- **F-003** (v6.12.1) — Category enum wider than effective audit-type scope.
- **F-007 / F-008 / F-010** (v6.12.1) — Finding IDs unrecoverable.

## Council Report

`.claude/scratchpad/council-v615-2026-05-10.md` — full Skeptic + Pragmatist report. Both verdicts: SIMPLIFY. Plan revised per their concerns; proceeding with implementation.
