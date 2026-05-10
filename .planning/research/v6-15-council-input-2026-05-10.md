# v6.15.x Architecture Plan — Council Input

**Date:** 2026-05-10
**Author:** Claude Opus 4.7 (autonomous mode)
**Scope:** Three architecture-level decisions needed for v6.15.x meta-audit wave-2 close-out.

This document is the input to `/council` for `claude-code-toolkit` v6.15.x. Council should validate the proposed approach, identify risks, and either APPROVE the plan or REJECT with concrete alternative.

---

## Context

`claude-code-toolkit` v6.14.0 wave-1 + v6.14.1/2/3 (PRs #82, #84, #86, #87) closed 23 of ~139 wave-2 meta-audit findings on the 7 base prompts. Remaining ~110 findings break into three architecture-level batches that each need a design decision before execution. Each batch will become its own PR or PR chain.

Wave-2 findings file: `.planning/research/meta-audit-wave2-2026-05-10.md`.

---

## Decision 1 — DEPLOY_CHECKLIST rework (F-290)

### Problem

`templates/base/prompts/DEPLOY_CHECKLIST.md` is a **deployment checklist** (numbered phases 0-8: code cleanup → quality → DB → environment → security → deployment steps → verification → rollback plan). The v4.2 audit pipeline propagation injected the **audit-prompt machinery** (SELF-CHECK 6-step FP recheck, OUTPUT FORMAT structured report schema, FALSE-POSITIVE CONTROL gates, Council Handoff slot) into every prompt under `templates/base/prompts/`, treating DEPLOY_CHECKLIST as if it were an audit prompt.

Result: a DevOps operator running this checklist faces a 6-step false-positive recheck procedure on a checkbox-only workflow. There are no "candidate findings" to evaluate — the prompt is just checkboxes. Sections 9-10 of the file (lines 238-563) are not used by anyone running DEPLOY_CHECKLIST.

### Wave-2 evidence

- F-290 — fundamental category mismatch.
- F-291 — checkbox-only QUICK CHECK assumes verification (conflicts with CODE_REVIEW's "do not infer status from inspection").
- F-292..F-306 — 14 MEDIUM findings on missing safety gaps that a real deploy checklist should cover (atomicity, rollback-point clarity, backward-compatibility check on migrations, pre-deploy baseline metrics, threat model integration, smoke-test automation, rollback-trigger specificity).

### Proposed approach (Option D — strip audit machinery, keep one file)

Single-file rework. Remove sections 9-10 (SELF-CHECK + OUTPUT FORMAT + Council Handoff). Keep DEPLOY_CHECKLIST as a pure deployment checklist with phases 0-8. Update splice pipeline (`scripts/propagate-audit-pipeline-v42.sh`) to skip DEPLOY_CHECKLIST entirely (a config-driven exclusion list, not hardcoded).

Then close the 14 MED findings as inline edits to phases 0-8:

- Phase 6 (DEPLOYMENT) — replace numbered comments inside code blocks with explicit phase blocks (Pre-Deploy / Deploy / Post-Deploy) and atomicity statements ("if step 5 fails, exit maintenance mode is **NOT** automatic — see Phase 8").
- Phase 3 (DATABASE) — add backward-compatibility check ("Queries do not reference dropped columns").
- Phase 5 (SECURITY) — link to threat-model file or `## PROJECT SPECIFICS`.
- Phase 7 (VERIFICATION) — name "automated test suite re-run" + "load test validation" + "feature flag state checks" as required, not optional.
- Phase 8 (ROLLBACK) — add runbook reference, define "critical functionality" as project-local list, name corruption-detection method, time-window guidance.
- Pre-deploy baseline — add a new ## Phase 0a "Pre-deploy Baseline" capturing error rate / latency p95 / GC pauses BEFORE the deploy starts, so post-deploy comparison has a baseline.
- Hotfix path — narrow scope of "Quick Check only" with a conditional note that hotfix MUST still cover phase 5 (SECURITY) if patching auth/crypto.

Rejected alternatives:

- Option A (split into 2 prompts: `DEPLOY_CHECKLIST.md` + `DEPLOY_AUDIT.md`) — adds a 9th file, doubles maintenance burden, and "deploy audit" doesn't have an obvious customer (the SECURITY_AUDIT and CODE_REVIEW already cover what would go there).
- Option B (keep machinery, document that it's optional) — leaves the user-facing confusion intact; adds nothing.
- Option C (delete DEPLOY_CHECKLIST entirely) — too aggressive; the checklist content is genuinely useful, just packaged wrong.

### Estimated effort

~6-8h. Single file edit + propagation-script update + tests + CHANGELOG entry. PR risk: MEDIUM (touches workflow operators rely on, but the changes are net-positive — fewer surprises).

---

## Decision 2 — DESIGN_REVIEW identity split (F-321 / F-329)

### Problem

`templates/base/prompts/DESIGN_REVIEW.md` titles itself "UI/UX Quality Audit" but Phase 7 ("Code Health", lines 186-208) audits software architecture: component reusability, design tokens, magic numbers, bundle size, lazy loading. These are CODE_REVIEW or PERFORMANCE_AUDIT concerns, not UI/UX. A reviewer running DESIGN_REVIEW expecting UI/UX feedback gets architecture findings mixed in; a reviewer running CODE_REVIEW for component-reuse questions doesn't see them because they're elsewhere.

The v6.14.1 surgical PR (F-320) already added a `## GOAL` section that **explicitly excludes** these concerns from DESIGN_REVIEW's stated scope. Phase 7 contradicts the GOAL section.

### Proposed approach (Option B — remove Phase 7, no new file)

Single-file edit. Delete Phase 7 from DESIGN_REVIEW. Move the actual content (component reuse, design tokens, magic numbers, bundle size, lazy loading) to one of:

- `templates/base/prompts/CODE_REVIEW.md` Phase X (under "Architecture & Structure" if such a section exists, otherwise as a new sub-section).
- `templates/base/prompts/PERFORMANCE_AUDIT.md` Phase Y (bundle size and lazy loading specifically).

This is a **non-destructive move** — no content lost, just re-homed.

Rejected alternatives:

- Option A (split DESIGN_REVIEW into `DESIGN_REVIEW.md` (UI/UX) + `DESIGN_SYSTEM_CODE_HEALTH.md` (architecture)) — adds a 9th audit file. The "design system code health" content is small (~30 lines) and doesn't justify its own prompt, especially when CODE_REVIEW already covers component patterns.
- Option C (rename Phase 7 to "Design System Code Health" and limit scope to design-token files only) — keeps the scope creep, just renames it. Doesn't fix the GOAL contradiction.

### Estimated effort

~3-4h. Move content + update GOAL to confirm the split + tests + CHANGELOG. PR risk: LOW (deleting content that the GOAL section already disclaims).

Closes wave-2 findings: F-321, F-329, partial F-326 (scope ambiguity). Other DESIGN_REVIEW findings (F-322, F-324, F-327, F-328) are independent and ship in v6.14.4 / v6.14.5.

---

## Decision 3 — KNOWN-DEBT-1 framework prompt drift sweep

### Problem

`templates/{laravel,rails,python,go}/prompts/*.md` (28 files) carry substantially older content than `templates/base/prompts/*.md` (7 files, the canonical SOT). The v4.2 splice pipeline propagates **only the four splice blocks** (callout, fp-recheck, output-format, council-handoff). Surrounding body content does not propagate.

Drift profile (line-count delta vs base, measured 2026-05-10):

| Prompt | Base | Laravel | Rails | Python | Go |
|--------|------|---------|-------|--------|-----|
| CODE_REVIEW | 532 | +278 | +278 | +529 | +384 |
| DEPLOY_CHECKLIST | 563 | +212 | +325 | +617 | +669 |
| DESIGN_REVIEW | 682 | -15 | -15 | -15 | -15 |
| MYSQL_PERF | 846 | -9 | +1 | -18 | -18 |
| PERFORMANCE_AUDIT | 633 | +368 | +260 | +69 | +39 |
| POSTGRES_PERF | 901 | +3 | +12 | +19 | +3 |
| SECURITY_AUDIT | 971 | +181 | +160 | +76 | +177 |

Two profiles:

- **Heavy-drift** (CODE_REVIEW, DEPLOY_CHECKLIST, PERFORMANCE_AUDIT, SECURITY_AUDIT): frameworks add 200-700 lines of framework-specific content (e.g., Laravel "## 4. LARAVEL BEST PRACTICES → 4.1 Eloquent Usage / 4.2 Request Validation / 4.3 Config & Environment"). NOT pure stale; real value-add.
- **Stale-but-aligned** (DESIGN_REVIEW, MYSQL/POSTGRES_PERFORMANCE_AUDIT): within ±20 lines of base. Pure regen candidates.

Heavy-drift prompts also use **different structural organization** than base (numbered phases vs flat H2 sections). Two parallel architectures, not one with drift.

### Proposed approach (Option C — hybrid, per-profile)

**Phase 1 (v6.15.0)**: Stale-but-aligned prompts (DESIGN_REVIEW, MYSQL_PERFORMANCE_AUDIT, POSTGRES_PERFORMANCE_AUDIT — 12 files: 4 frameworks × 3 prompts) get **Option A (regen from base)**.

- These differ from base by ±20 lines — the framework variants are essentially stale snapshots, not active divergence.
- New propagation script `scripts/propagate-framework-stale.sh` copies `templates/base/prompts/<X>.md` to `templates/<framework>/prompts/<X>.md` for the 3 stale-aligned prompts.
- No `_specifics/` overlay needed for these prompts (framework-specific content is minimal or absent).

**Phase 2 (v6.15.1)**: Heavy-drift prompts (CODE_REVIEW, DEPLOY_CHECKLIST, PERFORMANCE_AUDIT, SECURITY_AUDIT — 16 files: 4 frameworks × 4 prompts) get **Option B (sentinel-based section sync)**.

- Add per-section sentinels to base prompts: `<!-- v615-sync: SEVERITY-START -->...<!-- v615-sync: SEVERITY-END -->` around sections that should sync (severity rubric reference, FALSE-POSITIVE CONTROL three-gate structure, UNCERTAINTY DISCIPLINE, REALISTIC EXPLOITABILITY FILTER).
- Add matching sentinels in each framework variant at the corresponding location (one-time manual placement).
- New propagation script `scripts/propagate-framework-sync.sh` reads sentinel ranges from base, replaces matching ranges in framework files. Frameworks keep their numbered-phase organization and framework-specific sections.

**Phase 3 (v6.15.2)**: CI integration. `make check` fails if base prompt is edited inside a sentinel range without re-running the appropriate propagation script. `.github/workflows/quality.yml` `validate-templates` job extended to enforce.

Rejected alternatives:

- **Pure Option A** (regen all 28 files from base + per-framework `_specifics/` overlays). Destructive: framework numbered-phase organization is lost, framework users (especially Laravel) lose curated content like `## 4. LARAVEL BEST PRACTICES`. High migration disruption.
- **Pure Option B** (sentinel sync everywhere). Engineering-heavy: ~20 sentinels per file × 28 files = ~560 manual sentinel insertions. Stale-but-aligned prompts don't need sentinels — Option A is cheaper and fine.

### Estimated effort

- Phase 1: ~1 day (12 file regenerations, scoped script, tests).
- Phase 2: ~3-4 days (sentinel design + manual placement across 16 files, propagation script, tests).
- Phase 3: ~1 day (CI integration).
- Total: ~5-6 days. PR risk: HIGH (touches 28 production-shipped files; needs `/council` validation BEFORE Phase 2 starts).

Each phase ships as a separate PR for review-ability.

---

## Acceptance criteria (all three decisions)

- All 7 base prompts pass `make check` after each phase.
- Re-running propagation scripts on a clean tree produces zero diff (idempotent).
- Wave-2 findings closed by each phase explicitly named in CHANGELOG.
- No content loss — framework-specific content preserved verbatim where it adds value.
- CI gate fails on base prompt change inside a sentinel range without propagation re-run.

## Council request

For each of the three decisions:

1. Approve / reject the proposed approach.
2. If approve, identify the highest-risk failure mode and a concrete mitigation.
3. If reject, propose a concrete alternative — not "consider X" but "do X by editing file Y line Z".

Cross-cutting questions for council:

- Does anything in the v6.0..v6.14.3 history suggest these architecture choices conflict with established conventions?
- Is the wave-2 finding population large enough (~110 remaining) to justify the architecture-level work, or should we close more surgical findings first and revisit?
- Should `templates/nextjs/prompts/` and `templates/nodejs/prompts/` (currently absent) be added in this same milestone, or deferred?
