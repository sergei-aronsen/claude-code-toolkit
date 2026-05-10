# Framework Prompt Drift — Scoping Doc (KNOWN-DEBT-1)

**Date:** 2026-05-10
**Milestone:** v6.15.x (proposed)
**Risk:** HIGH (touches 28 production-shipped prompt files)
**Status:** Scoping — needs `/council` validation before execution

---

## Problem

`templates/{laravel,rails,python,go}/prompts/*.md` (28 files) carry substantially older content than `templates/base/prompts/*.md` (7 files, base SOT).

The v42 splice pipeline (`scripts/propagate-audit-pipeline-v42.sh`) propagates only **four sentinel-tagged blocks** (callout, FP-recheck, output-format, council-handoff). The surrounding body — including severity rubrics, UNCERTAINTY DISCIPLINE, scope/priority guidance, evidence rules, and business-logic validation — does NOT propagate from base to framework prompts.

Effect: today's base improvements (e.g., v6.14.0 F-104 FALSE-POSITIVE CONTROL three-gate order) live in `templates/base/` only. Framework users get stale content.

---

## Drift Profile (line-count delta vs base, measured 2026-05-10)

| Prompt | Base | Laravel | Rails | Python | Go |
|--------|------|---------|-------|--------|-----|
| CODE_REVIEW | 532 | +278 | +278 | +529 | +384 |
| DEPLOY_CHECKLIST | 563 | +212 | +325 | +617 | +669 |
| DESIGN_REVIEW | 682 | -15 | -15 | -15 | -15 |
| MYSQL_PERFORMANCE_AUDIT | 846 | -9 | +1 | -18 | -18 |
| PERFORMANCE_AUDIT | 633 | +368 | +260 | +69 | +39 |
| POSTGRES_PERFORMANCE_AUDIT | 901 | +3 | +12 | +19 | +3 |
| SECURITY_AUDIT | 971 | +181 | +160 | +76 | +177 |

**Two distinct profiles:**

1. **Heavy drift** (CODE_REVIEW, DEPLOY_CHECKLIST, PERFORMANCE_AUDIT, SECURITY_AUDIT) — frameworks add 200-700 lines of framework-specific content (e.g., Laravel "## 4. LARAVEL BEST PRACTICES → 4.1 Eloquent Usage / 4.2 Request Validation / 4.3 Config & Environment"). NOT pure stale; real value-add interwoven with base content.

2. **Stale-but-aligned** (DESIGN_REVIEW, MYSQL_PERFORMANCE_AUDIT, POSTGRES_PERFORMANCE_AUDIT) — within ±20 lines of base. Pure regen candidates.

---

## Structural Divergence

Heavy-drift prompts use **different organization** than base:

| Base | Frameworks |
|------|-----------|
| Flat H2 sections (`## GOAL`, `## QUICK CHECK`, `## SEVERITY AND CONFIDENCE`) | Numbered phases (`## 0. QUICK CHECK`, `## 0.3 SEVERITY LEVELS`, `## 1. SCOPE REVIEW`, `## 2. ARCHITECTURE & STRUCTURE`, `## 4. LARAVEL BEST PRACTICES`) |
| Audit-pipeline focused | Phase-by-phase walkthrough |

This is **two parallel architectures**, not one with drift. Any sync mechanism must reconcile organization, not just content.

---

## Options

### Option A — Regen frameworks from base + framework delta

**Mechanism:**

1. Adopt base structure as canonical for all 28 framework prompts.
2. Move framework-specific content (e.g., Laravel sections 4.1-4.3) to a new SOT: `templates/<framework>/prompts/_specifics/<PROMPT_NAME>.md`.
3. New propagation script `scripts/propagate-framework-prompts.sh`:
   - Copy `templates/base/prompts/<X>.md` to `templates/<framework>/prompts/<X>.md`
   - Append `templates/<framework>/prompts/_specifics/<X>.md` content as `## FRAMEWORK SPECIFICS` H2 subsection
   - Re-run v42 splice pipeline on framework files.
4. Run on every base-prompt change (CI gate).

**Pros:**

- Single source of truth for non-framework content.
- v6.14.0+ improvements automatically propagate.
- Future base changes are one PR away from all 28 files.
- Simple mental model.

**Cons:**

- **Destructive migration.** Framework numbered phases (`## 1. SCOPE REVIEW`, `## 4. LARAVEL BEST PRACTICES`) lose their phase identity, become flat H2.
- Existing users with `.claude/prompts/` overrides may experience confusing diffs.
- Manual extraction of framework specifics from heavy-drift prompts (one-time, ~16 hours).

**Effort:** ~3 days (extraction + script + re-splice + tests + CHANGELOG).

---

### Option B — Sentinel-based section sync

**Mechanism:**

1. Add per-section sentinels in base: `<!-- v6-sync: SEVERITY-START -->...<!-- v6-sync: SEVERITY-END -->`.
2. Add matching sentinels in each framework prompt at corresponding section.
3. Propagation script copies content between sentinels, preserving framework-only sections.
4. Frameworks keep their numbered-phase organization; only marked sections sync.

**Pros:**

- **Non-destructive.** Frameworks keep existing structure, including numbered phases.
- Per-section granularity — sync only what should sync.
- No migration disruption for users.

**Cons:**

- **Engineering-heavy.** ~20 sentinels per file × 28 files = ~560 sentinel insertions (one-time).
- Sentinel mismatches (base adds new section, framework doesn't have matching sentinel) need policy.
- `propagate-audit-pipeline-v42.sh` already exists — adding parallel sentinel system raises maintenance burden.
- Framework section numbering may drift further if base adds sections that conflict with framework numbering scheme.

**Effort:** ~5 days (sentinel design + insertion + propagation script + drift detection + tests + CHANGELOG).

---

### Option C — Hybrid (regen low-drift, sentinel-sync heavy-drift)

**Mechanism:**

- Low-drift prompts (DESIGN_REVIEW, MYSQL/POSTGRES_PERFORMANCE_AUDIT — 12 files) → Option A (regen from base).
- Heavy-drift prompts (CODE_REVIEW, DEPLOY_CHECKLIST, PERFORMANCE_AUDIT, SECURITY_AUDIT — 16 files) → Option B (sentinel sync).

**Pros:**

- Right tool per profile.
- Reduces blast radius — heavy-drift frameworks keep their custom organization, low-drift prompts get clean SOT.

**Cons:**

- Two propagation systems to maintain.
- Operators need to know which prompts use which system (rule file or naming convention).

**Effort:** ~4 days.

---

## Recommendation

**Option A is the safest long-term bet** if user surveys confirm frameworks rarely customize phase numbering. The numbered-phase organization may have been a one-time decision in v4.x that no one defends today; flattening to base structure aligns the entire codebase.

**Option B preserves user expectations** at the cost of long-term maintenance burden. Sentinel systems decay — every time someone forgets to add `<!-- v6-sync: ... -->` markers, drift returns.

**Option C is pragmatic** if drift profile is stable. Risk: profile may shift if frameworks accumulate more divergence.

**Council validation needed before execution.** This is a HIGH-risk change touching production-shipped content. Recommend `/council "framework prompt drift sweep — Option A vs B vs C"` with full scoping doc as input.

---

## Open Questions

1. Do users ever edit framework prompts (`.claude/prompts/<X>.md` after install)? If yes, destructive Option A is high-risk.
2. Is there telemetry on which prompts are most-used per framework? May change priority order.
3. Should `templates/nextjs/` and `templates/nodejs/` get prompts at all? They currently have none — silent regression vs other frameworks, or intentional skip?
4. Does Phase 26 Skills Selector affect this? (No — skills and prompts are separate paths.)

---

## Phase Plan (if Option A approved)

1. **v6.15.0 — Framework Specifics Extraction**
   - Manual extraction of framework-specific content from CODE_REVIEW, DEPLOY_CHECKLIST, PERFORMANCE_AUDIT, SECURITY_AUDIT (16 files × 4 frameworks).
   - Output: `templates/<fw>/prompts/_specifics/*.md`.
   - PR per framework (4 PRs) for review-ability.

2. **v6.15.1 — Propagation Script**
   - `scripts/propagate-framework-prompts.sh` (regen logic).
   - CI integration — fail if base prompt change skips framework re-propagation.
   - Tests against 4 frameworks × 7 prompts = 28 outputs.

3. **v6.15.2 — Migration & Distribution**
   - Run propagation script, verify all 28 outputs.
   - CHANGELOG entry with breaking-change callout.
   - Manifest version bump.
   - GitHub Release.

---

## Acceptance Criteria

- [ ] All 28 framework prompts pass `make check` after migration.
- [ ] Re-running propagation script on clean tree produces zero diff (idempotent).
- [ ] v6.14.0 base improvements (F-101 / F-104 / F-107 / F-111) visible in all 28 framework files post-migration.
- [ ] No user data loss — framework-specific content preserved in `_specifics/` SOT.
- [ ] CI gate fails on base prompt change without re-propagation.
