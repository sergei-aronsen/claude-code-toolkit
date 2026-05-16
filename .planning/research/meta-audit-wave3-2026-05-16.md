# Meta-Audit Wave 3 — base audit prompts

**Date:** 2026-05-16
**Method:** 7 parallel `code-reviewer` subagents, each adversarial meta-audit of
one base audit prompt.
**Target:** `templates/base/prompts/*.md` (7 files, 5821 LOC).

Re-run of the Wave-2 adversarial sweep that produced ~146 findings before its
transcript was compacted in PR #82 (v6.14.0). The Wave-2 status doc at
`.planning/research/meta-audit-wave2-2026-05-10.md` lists 139 historical
findings; many are now closed (v6.14.0-v6.17.1 + v6.27.0). This wave is a fresh
inventory against the *current* file state.

## Numbers

| File | LOC | Findings | CRIT | HIGH | MED | LOW |
|------|-----|----------|------|------|-----|-----|
| CODE_REVIEW.md | 665 | 26 | 0 | 7 | 12 | 7 |
| DEPLOY_CHECKLIST.md | 475 (post-v6.27.0) | 20 | 0 | 5 | 7 | 8 |
| DESIGN_REVIEW.md | 642 | 27 | 0 | 9 | 11 | 7 |
| MYSQL_PERFORMANCE_AUDIT.md | 1041 | 27 | 1 | 7 | 9 | 10 |
| PERFORMANCE_AUDIT.md | 775 | 31 | 0 | 4 | 16 | 11 |
| POSTGRES_PERFORMANCE_AUDIT.md | 1051 | 28 | 0 | 9 | 12 | 7 |
| SECURITY_AUDIT.md | 1185 | 33 | 0 | 12 | 13 | 8 |
| **Total** | **5834** | **192** | **1** | **53** | **80** | **58** |

## Top 3 cross-cutting themes

### T1 — Modern-stack coverage gaps (2024-2026)

The prompts read as if frozen at ~mid-2023:

- **PERFORMANCE_AUDIT.md** — FID still cited as Core Web Vital. INP replaced
  FID in March 2024. No App Router / RSC streaming / partial pre-rendering /
  edge cold-start methodology.
- **SECURITY_AUDIT.md** — JWT entirely absent (alg=none, algorithm confusion,
  kid traversal, jwk/jku injection, unverified decode). OAuth `redirect_uri`
  validation specifics absent (subdomain wildcard, IDN homograph, path-prefix).
  HTTP request smuggling (CL.TE / TE.CL / TE.TE) absent. ReDoS, prototype
  pollution, indirect prompt injection, slopsquatting all missing or
  one-line-mentioned.
- **MYSQL_PERFORMANCE_AUDIT.md** — No EXPLAIN ANALYZE (8.0.18+), no covering
  index / leftmost-prefix rules with detection SQL, no INSTANT-vs-INPLACE
  DDL matrix, no replication-lag queries (`SHOW REPLICA STATUS`, GTID gaps).
- **POSTGRES_PERFORMANCE_AUDIT.md** — No XID wraparound check (single
  most-cited outage class), no `pg_stat_io` (PG 16+), no replication-slot
  orphan check, no HOT-update / fillfactor, no autovacuum per-table tuning,
  no JIT compilation threshold audit, no parallel-plan investigation.
- **DESIGN_REVIEW.md** — Anchored to WCAG 2.1 AA (ratified 2018). Missing
  WCAG 2.2 (ratified Oct 2023): focus-not-obscured, target-size 24×24,
  dragging movements, accessible authentication. No `prefers-reduced-motion`
  / `forced-colors` / RTL / dark-mode checks.
- **CODE_REVIEW.md** — No supply-chain dependency check, no LLM-prompt-
  injection in app code, no async/await pitfalls, no RSC boundary check,
  no TypeScript strict regressions.

### T2 — Severity rubric & calibration broken

- **MYSQL_PERFORMANCE_AUDIT.md:230, 683-686** — Gate 3 calibration references
  `## SEVERITY THRESHOLDS` and `## PROJECT SPECIFICS`. Neither section exists
  in this file. F-103 KNOWN-DEBT was supposed to close this; regression.
- **POSTGRES_PERFORMANCE_AUDIT.md:693-696** — Same broken cross-reference as
  MYSQL. Mirrored bug.
- **SECURITY_AUDIT.md:819-836** — Inline UNCERTAINTY DISCIPLINE prose
  duplicates the spliced rubric-anchors SOT (line 840-844). Drift surface
  reborn after F-104 closed it in v6.14.0.
- **PERFORMANCE_AUDIT.md:49-54 vs :305-310** — `## SEVERITY` says CRITICAL
  threshold = "p99 > 5s end-to-end"; the Redis table at line 305-310
  independently asserts "Critical: hit-ratio < 70%" with no latency mapping.
  Conflicting rubrics in the same file.
- **CODE_REVIEW.md:90 vs :307, 322** — Severity rubric references both
  `components/severity-levels.md` AND `components/audit-severity-anchor.md`.
  Two SOTs for the same rubric.

### T3 — Evidence gates absent or weak

- **F-108 KNOWN-DEBT still open** across both DB-perf prompts. Neither
  MYSQL nor POSTGRES audit requires `EXPLAIN` / `EXPLAIN ANALYZE` output
  in the `Code:` block of query findings. Statistical scan-ratio from
  `performance_schema` or `pg_stat_statements` is allowed as evidence,
  but it's not a plan — auditors can ship "this query is slow" findings
  without proof of the plan path.
- **DESIGN_REVIEW.md:450** — `Why it is real` field requires "concrete
  tokens visible in the Code block". For a contrast-violation finding the
  concrete artifact is the *number* (computed ratio), not "tokens in code".
  Schema forces design findings to fake textual citations.
- **DEPLOY_CHECKLIST.md:142-144** — Schema-vs-code ordering rule
  ("remove all `SELECT col` / `WHERE col` references at least one deploy
  ahead of the schema change") is prose-only, not a checkbox.
- **CODE_REVIEW.md** — No instruction telling the reviewer to read the PR
  description / commit message / linked issue. Reviewer has no input to
  derive intent beyond the code itself.

## Per-file recommendations

### CODE_REVIEW.md — targeted edits

3 categories of fix:

1. Add modern-stack categories (~150 LOC): async/await, RSC, TS strict,
   Go ctx, Python async cancel, LLM-in-app, supply-chain, retry/timeout
   policy, i18n.
2. Deduplicate vs sibling prompts (~50 LOC delete): drop priority-5 perf
   from `## SCOPE` (PERFORMANCE_AUDIT owns), move design-tokens +
   component-reuse to DESIGN_REVIEW SOT.
3. Add determinism anchors (~80 LOC): QUICK CHECK gets a `Command`
   column; PROJECT SPECIFICS uses HTML-comment placeholders; BUSINESS
   LOGIC categories get 1-line examples each.

### DEPLOY_CHECKLIST.md — surgical gate enforcement

3-PR plan suggested by audit:

- **v6.28.0** — F-002 (Phase 6 entry gate), F-003 (column-drop checkbox),
  F-005 (5.4 trigger grep pattern), F-007 (7.4-vs-8.2 threshold gap),
  F-011 (global n/a-justification rule). Closes prose-only gates that
  rely on human discipline.
- **v6.29.0** — Modern-stack pass: F-006 (artifact attestation), F-009
  (queue-message compat), F-010 (flag decommission via
  `components/feature-flag-lifecycle.md`), F-012 (multi-region/edge,
  needs new `components/deploy-templates/edge.md`), F-013 (canary
  statistical gate).
- Defer LOWs to a v6.28.x sweep.

### DESIGN_REVIEW.md — identity split + WCAG 2.2 refresh

F-106 KNOWN-DEBT (v6.14.x) is still open: file scope is UI/UX-only but
canonical slug `design-review` suggests architecture. **Recommendation**:
rename to `UI_DESIGN_REVIEW.md` + canonical slug `ui-design-review` AND
refresh accessibility to WCAG 2.2 with explicit `prefers-reduced-motion`,
`forced-colors`, RTL, dark-mode, SR-announcement gates. Add design-finding
example to OUTPUT FORMAT skeleton with field-semantics override for
measurement-based evidence.

### MYSQL_PERFORMANCE_AUDIT.md — v6.28.x blocker

F-001 (CRITICAL): phantom `## SEVERITY THRESHOLDS` / `## PROJECT SPECIFICS`
sections that Gate 3 calibration references. **Cannot be deferred** —
every Council pass downstream of this prompt operates with a broken
calibration anchor. Add the two missing sections + EXPLAIN evidence gate
in a single patch.

### PERFORMANCE_AUDIT.md — 2026 web-perf refresh

Replace FID with INP throughout. Add §3.7 RSC/Streaming + §6.5 Cold-Start.
Expand severity rubric to multi-axis (latency × blast-radius × QPS).
Convert binary checkboxes to "verified by `<command>` with output
`<threshold>`". Explicitly delegate deep DB-engine analysis to
MYSQL/POSTGRES audits.

### POSTGRES_PERFORMANCE_AUDIT.md — v6.28.x blocker (paired with MYSQL)

F-203 (HIGH): same phantom cross-reference as MYSQL F-001. **Treat as
single SOT fix** — the bug originates in `components/audit-fp-control-gates.md`
splice template that fans out to both. F-202 (HIGH): XID wraparound check
absent despite being the single most-cited outage class. F-209: volatile
DEFAULT trap buried in checklist; promote to its own subsection.

### SECURITY_AUDIT.md — highest-impact target

12 HIGH findings on 2024-2026 attack classes (JWT, OAuth specifics, SSRF
v6, request smuggling, ReDoS, prototype pollution, deserialization
extended, SameSite gaps, slopsquatting, indirect prompt injection,
inline rubric drift, CSP strict-dynamic). **Highest-impact target for
Item 3** — most findings are additive (new sections), splice sentinels
protect canonical 3-gate ordering, and updates immediately affect every
user running `/audit security`.

## Recommended sequencing for v6.28.0+ work

1. **v6.28.0** — SECURITY_AUDIT.md modernization (top 12 HIGH findings).
   Single file, additive edits, splice-safe. **Highest user impact.**
2. **v6.28.1** — DB-perf phantom cross-references (MYSQL F-001 + POSTGRES
   F-203 via SOT fix in `components/audit-fp-control-gates.md`). Surgical.
3. **v6.29.0** — PERFORMANCE_AUDIT.md FID→INP migration + RSC/Edge sections.
   Web-perf refresh.
4. **v6.30.0** — DESIGN_REVIEW.md rename to `UI_DESIGN_REVIEW.md` + WCAG
   2.2 refresh. Slug change requires aliasing for backwards-compat.
5. **v6.31.0** — DEPLOY_CHECKLIST.md gate enforcement (F-002/003/005/007/011).
6. **v6.32.0** — CODE_REVIEW.md modern-stack categories + dedup vs siblings.
7. **v6.33.0** — POSTGRES_PERFORMANCE_AUDIT.md PG16+ coverage (pg_stat_io,
   replication slots, autovacuum tuning, JIT thresholds).
8. **v6.34.0** — MYSQL_PERFORMANCE_AUDIT.md 8.0+ coverage (EXPLAIN ANALYZE,
   covering indexes, replication health, slow_query_log integration).

## Splice / SOT impact

Most findings are in prose sections outside splice sentinels — safe to
edit in place. SOT-touching changes:

- **F-203 MYSQL/POSTGRES phantom refs** → edit `components/audit-fp-control-gates.md`
  (or its sibling) to either remove the dangling cross-refs OR add the
  referenced sections to base prompts.
- **CODE_REVIEW F-005** (two severity-rubric SOTs) → reconcile
  `components/severity-levels.md` vs `components/audit-severity-anchor.md`.
  Pick one canonical; delete the other.
- **SECURITY_AUDIT F-012** inline rubric drift at 819-836 → delete inline
  prose, rely on existing `<!-- v42-splice: rubric-anchors -->`.

After any SOT edit, run `scripts/propagate-audit-pipeline-v42.sh --force`
to fan out to the 6 base audit prompts.

## Closure of prior KNOWN-DEBT

This wave verifies the post-v6.27.0 state of historical KNOWN-DEBT items:

- ✅ **F-101** (audit-output-format schema) — closed in v6.14.0.
- ✅ **F-104** (3-rubric collision in SECURITY) — closed in v6.14.0,
  except inline-prose regression at SECURITY:819-836 (this wave's
  SECURITY F-012).
- ✅ **F-105** (deploy decision-gate loophole) — closed in v6.17.0, except
  the prose-only enforcement issue (this wave's DEPLOY F-002).
- ❌ **F-103** (per-audit measurable severity rubric) — still open across
  all 4 perf prompts.
- ❌ **F-106** (DESIGN identity split) — still open (this wave's DESIGN F-001).
- ❌ **F-108** (DB-perf EXPLAIN evidence gate) — still open in both MYSQL
  + POSTGRES prompts (this wave's MYSQL F-002 + POSTGRES F-201).
- ❌ **F-109** (Postgres coverage extensions including XID wraparound) —
  still open (this wave's POSTGRES F-202).
- ❌ **F-112** (Laravel `get()` unbounded example) — still partial (this
  wave's MYSQL F-024).
- ❌ **F-113** (checklist-tick-boxes-without-evidence) — partially open
  (multiple this-wave findings reference binary checkboxes).
- ❌ **F-114** (propagate base-prompt fixes to framework prompts) — closed
  in v6.22.0 + v6.27.0 (framework prompts deleted; this wave needs no
  propagation step).

## Council Handoff

This research artifact is intended as input to scope the next series of
PRs (v6.28.0+). No code changes have been made — all 192 findings remain
unaddressed until per-PR scoping decisions are made.

Per Memory `project_v6270_shipped.md` lesson: spawn parallel agents,
extract findings into a planning doc, then ship 1-file-per-PR with full
test coverage. Do not bundle multiple audit prompts into a single PR —
each prompt is a SOT that affects every install.
