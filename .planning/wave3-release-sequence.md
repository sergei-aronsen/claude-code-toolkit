# Wave-3 Audit-Prompt Modernization — v6.29.0 → v6.34.0 Release Sequence

**Status:** active (started 2026-05-17, after v6.28.1 ship).
**Mandate:** autonomous execution per user instruction "не трогать" (do not interrupt).
**Source of scope:** `.planning/research/meta-audit-wave3-2026-05-16.md`.

## Pattern

Each release follows the established 2-PR pattern (proven v6.28.0 + v6.28.1):

1. **Feat PR** — additive edits to ONE audit prompt + (if SOT touched) propagator re-run.
   - Branch: `feat/v<X.Y.Z>-<slug>`.
   - Invariants preserved byte-exact: 6 v42-splice sentinels, 3 `_pending — run /council audit-review_` U+2014 slots, `1. **Read context**` + `6. **Severity sanity check**` SELF-CHECK anchors, schema labels, YAML frontmatter, `<output_format>` skeleton.
   - CHANGELOG entry under `[Unreleased]`.
   - `make check` 10/10 green pre-push.
   - Wait for CI (~3-5 min, bats matrix slowest), squash-merge with `--delete-branch`.

2. **Release PR** — manifest + CHANGELOG promotion + TK_TOOLKIT_REF bump.
   - Branch: `chore/release-v<X.Y.Z>`.
   - Bumps: `manifest.json` `version`/`updated`/`build_date`, CHANGELOG `[Unreleased]` → `[<X.Y.Z>] - <date>`, `TK_TOOLKIT_REF:-v<prev>` → `TK_TOOLKIT_REF:-v<X.Y.Z>` across 9 installer scripts (init-claude.sh, install-statusline.sh, install.sh, migrate-to-complement.sh, setup-council.sh, setup-prompt-engineer.sh, setup-security.sh, uninstall.sh, update-claude.sh).
   - `make check` 10/10 green.
   - CI green → squash-merge → tag `v<X.Y.Z>` → GH Release with CHANGELOG body.

3. **Memory pin** — write `~/.claude/projects/.../memory/project_v<X>_shipped.md`, update MEMORY.md index entry + version field.

## Release queue

### v6.29.0 — PERFORMANCE_AUDIT.md modernization

- **File:** `templates/base/prompts/PERFORMANCE_AUDIT.md`.
- **Findings closed:**
  - FID → INP migration (Core Web Vital changed March 2024).
  - App Router / RSC streaming / partial pre-rendering coverage.
  - Edge cold-start methodology (V8 isolate startup, regional warm-up, KV/D1 hot-path).
  - Severity-rubric conflict reconcile at `## SEVERITY` (line 49-54: p99 > 5s) vs Redis table (line 305-310: hit-ratio < 70%) — pick one canonical mapping, cross-reference Severity Ceiling Table.
- **Scope estimate:** ~200-300 LOC additive + 1 surgical reconcile.

### v6.30.0 — DESIGN_REVIEW.md slug rename + WCAG 2.2 refresh

- **Files:** `templates/base/prompts/DESIGN_REVIEW.md` → rename to `UI_DESIGN_REVIEW.md`. Canonical slug `design-review` → `ui-design-review`. Need back-compat aliasing in propagator + audit-output-format schema.
- **Findings closed:**
  - F-106 KNOWN-DEBT identity split (file scope is UI/UX-only but slug suggests architecture).
  - WCAG 2.2 (ratified Oct 2023): focus-not-obscured, target-size 24×24, dragging movements, accessible authentication.
  - `prefers-reduced-motion`, `forced-colors`, RTL, dark-mode, SR-announcement gates.
  - Design-finding example in OUTPUT FORMAT skeleton with field-semantics override for measurement-based evidence (`Why it is real` accepts computed ratio, not just "tokens in Code block").
- **Scope estimate:** ~250-350 LOC additive + rename + aliasing.
- **Risk:** higher than typical — slug change touches propagator + manifest. Test propagator dry-run + back-compat.

### v6.31.0 — DEPLOY_CHECKLIST.md gate enforcement

- **File:** `templates/base/prompts/DEPLOY_CHECKLIST.md`.
- **Findings closed:**
  - F-002: Phase 6 entry gate (was prose-only).
  - F-003: column-drop checkbox in Schema-vs-code ordering.
  - F-005: 5.4 trigger grep pattern.
  - F-007: 7.4-vs-8.2 threshold gap.
  - F-011: global n/a-justification rule.
- **Scope estimate:** ~150-200 LOC additive checkboxes + 1 grep-pattern block.

### v6.32.0 — CODE_REVIEW.md modern-stack categories

- **File:** `templates/base/prompts/CODE_REVIEW.md`.
- **Findings closed:**
  - 3 categories of fix from research doc:
    1. Add modern-stack categories (~150 LOC): async/await, RSC, TS strict, Go ctx, Python async cancel, LLM-in-app, supply-chain, retry/timeout policy, i18n.
    2. Dedupe vs sibling prompts (~50 LOC delete): drop priority-5 perf from SCOPE (PERFORMANCE_AUDIT owns), move design-tokens + component-reuse to DESIGN_REVIEW SOT.
    3. Determinism anchors (~80 LOC): QUICK CHECK gets a Command column; PROJECT SPECIFICS uses HTML-comment placeholders; BUSINESS LOGIC categories get 1-line examples.
  - F-005 severity-rubric SOT reconcile: `components/severity-levels.md` vs `components/audit-severity-anchor.md` — pick canonical, delete the other.
- **Scope estimate:** ~280 LOC additive - ~50 LOC delete + SOT consolidation.

### v6.33.0 — POSTGRES_PERFORMANCE_AUDIT.md PG16+ coverage

- **File:** `templates/base/prompts/POSTGRES_PERFORMANCE_AUDIT.md`.
- **Findings closed:**
  - F-201 EXPLAIN evidence gate.
  - F-203 phantom cross-reference fix (mirror of MYSQL F-001 — likely via `components/audit-fp-control-gates.md` or sibling SOT edit).
  - F-202 (XID wraparound — single most-cited outage class).
  - PG 16+ coverage: `pg_stat_io`, replication-slot orphan check, HOT-update / fillfactor, autovacuum per-table tuning, JIT compilation threshold audit, parallel-plan investigation.
- **Scope estimate:** ~300-400 LOC additive.

### v6.34.0 — MYSQL_PERFORMANCE_AUDIT.md 8.0+ coverage

- **File:** `templates/base/prompts/MYSQL_PERFORMANCE_AUDIT.md`.
- **Findings closed:**
  - F-001 phantom cross-reference fix (SOT-level).
  - F-002 EXPLAIN ANALYZE evidence gate (8.0.18+).
  - 8.0+ coverage: covering index / leftmost-prefix rules with detection SQL, INSTANT-vs-INPLACE DDL matrix, replication-lag queries (`SHOW REPLICA STATUS`, GTID gaps), slow_query_log integration.
  - F-024 Laravel `get()` unbounded example (still partial from earlier wave).
- **Scope estimate:** ~300-400 LOC additive.

## Autonomous execution rules

- **No interrupts** except hard blockers (CI failure that can't auto-diagnose, conflicting force-push, safety-net hook blocks on unfixable patterns).
- **Branch hygiene:** `git checkout -b feat/... main` from fresh main pulled after each release merge.
- **CI wait:** `ScheduleWakeup` with `delaySeconds=270` (cache-friendly) per CI cycle; usually 2 cycles per release (feat + release) = ~10 min per release.
- **Memory pin AFTER each ship** — never skip.
- **Lint clean BEFORE commit** — never push lint debt.
- **Lessons-learned:** if a new pattern emerges (security-hook bypass, propagator edge case, MD lint trap), commit to `.claude/rules/lessons-learned.md` AND memory.
- **Token budget:** ~6 releases × ~50k tokens = ~300k. Compaction will hit. Keep `MEMORY.md` index entry under 200 chars per release.

## Total estimate

- ~6 releases × ~10 min CI wait × 2 PRs + ~30 min hands-on per release = ~6-8 hours wall-clock, mostly waiting on CI.
- ~1500-2000 LOC net additive across the 6 audit prompts.
- All 12 Wave-3 HIGH SECURITY findings + ~40 of remaining 192 wave-3 findings closed by v6.34.0 ship.
- SOT touches: 1 likely (CODE_REVIEW F-005 severity-rubric reconcile), maybe a 2nd (DB-perf phantom xref).

## Out of scope (deferred past v6.34.0)

- Remaining ~140 wave-3 LOW/MED findings.
- Phase B Pocock doctrine (medium backlog, needs source from user).
- Skills + MCP tracking in `update-deps.sh` (medium backlog).
