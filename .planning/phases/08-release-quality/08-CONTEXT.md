# Phase 8: Release Quality - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning
**Mode:** `--auto` (all decisions selected from recommended defaults)

<domain>
## Phase Boundary

Phase 8 hardens the v4.0 release-validation infrastructure without changing any
install behavior. Three scoped deliverables:

1. **REL-01 — bats port.** Replicate all 13 cells from `scripts/validate-release.sh`
   as bats test files under `scripts/tests/matrix/*.bats`. Preserve 63 existing
   assertions verbatim. Ship `make test-matrix-bats`. Bash runner stays functional.
2. **REL-02 — cell-parity gate.** New `make check` target `cell-parity` that
   asserts every cell name appears in all three surfaces: `validate-release.sh
   --list`, `docs/INSTALL.md`, `docs/RELEASE-CHECKLIST.md`.
3. **REL-03 — `--collect-all` aggregation.** Flag on `validate-release.sh` that
   runs every cell regardless of failures and emits an aggregated ASCII table.
   Default fail-fast behavior unchanged without the flag.

**In scope:** test-infra refactor, docs-parity lint, runner aggregation flag.
**Out of scope:** bash runner removal (stays for transition), docs restructure
beyond adding missing `--cell` commands, Phase 11 styled diff (`--dry-run`),
Phase 9 detection/backup work.

</domain>

<decisions>
## Implementation Decisions

### REL-01 — bats port

- **D-01:** Bats file layout = **per-mode** (one file per install mode + one for
  translation-sync). Yields 5 files:
  - `scripts/tests/matrix/standalone.bats` (3 cells)
  - `scripts/tests/matrix/complement-sp.bats` (3 cells)
  - `scripts/tests/matrix/complement-gsd.bats` (3 cells)
  - `scripts/tests/matrix/complement-full.bats` (3 cells)
  - `scripts/tests/matrix/translation-sync.bats` (1 cell)
  Balances parallelism and readability; mirrors docs structure; avoids single
  627-line monolith and 13-file sprawl.

- **D-02:** Shared helpers (sandbox_setup, stage_sp_cache, stage_gsd_cache,
  setup_v3x_worktree, assert_eq, assert_contains, assert_state_schema,
  assert_settings_foreign_intact, assert_skiplist_clean,
  assert_no_agent_collision, compute_skip_set, sha256_file) are extracted to
  **`scripts/tests/matrix/lib/helpers.bash`**. Both the existing bash runner
  (`validate-release.sh`) and the new bats files source this lib. Zero
  duplication, zero assertion drift.

- **D-03:** Assertion preservation rule = **1:1 byte-for-byte.** Each bats `@test`
  invokes the same `assert_*` helper with identical args as the corresponding
  bash cell body. A bats test that would produce a different FAIL count than the
  bash cell is a plan-time defect. The 63-assertion target is verified by a
  plan-time diff: count of `assert_` invocations in bats files must equal the
  count in the bash runner's cell bodies.

- **D-04:** `make test-matrix-bats` target = thin wrapper that runs
  `bats scripts/tests/matrix/*.bats` and exits non-zero on any failing test.
  Independent of existing `make test` (Test 16 stays as-is during transition).

- **D-05:** Bash runner (`scripts/validate-release.sh --all`) remains functional
  and authoritative. Bats suite is additive, not replacing. Removal deferred to
  a future milestone (v4.2+).

### REL-02 — cell-parity

- **D-06:** Three surfaces checked for every cell name:
  1. `scripts/validate-release.sh --list` output (source of truth — `CELLS=()`
     array).
  2. `docs/INSTALL.md` — occurrences of `--cell <name>` in runnable command
     snippets.
  3. `docs/RELEASE-CHECKLIST.md` — occurrences of `--cell <name>` in runnable
     command snippets (NOT section headings — the doc groups by mode, not by
     cell, and restructuring to per-cell headings would double its length for
     no reader benefit).

  Rationale for deviating from REL-02 phrasing "section heading in
  RELEASE-CHECKLIST.md": `--cell <name>` in command snippets is the actual
  cross-reference surface used today (RELEASE-CHECKLIST.md lines 14, 31–33,
  43–45, 55–57, 67–69, 81). Section-heading matching would fail 13/13 cells
  against existing doc and force unnecessary restructure.

- **D-07:** Parity rule = **strict 3/3.** Any cell name missing from any of the
  three surfaces fails the gate. Matches REL-02 spec literal "Fails if any cell
  name appears in ≤2 of 3 surfaces."

- **D-08:** `docs/INSTALL.md` does NOT currently contain `--cell <name>`
  commands. Plan-time action: add a runnable command column or inline snippet
  per table row so cell names become visible. This keeps INSTALL.md user-facing
  while satisfying parity. Also fixes pre-existing drift: INSTALL.md intro says
  "12 cells"; runner has 13 (translation-sync is the 13th). Plan 8.x updates
  the intro.

- **D-09:** Cell-parity implementation = **pure shell + grep + jq** (no Python,
  no new deps). Parses `validate-release.sh --list`, greps both docs for
  `--cell [a-z][a-z0-9-]*` patterns, emits three-column presence table on
  failure.

- **D-10:** Makefile target name = **`cell-parity`**. Wired into `check` target
  after `validate-commands`:
  `check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands cell-parity`.
  Also wired into `.github/workflows/quality.yml` under the `validate-templates`
  job (single-step addition).

### REL-03 — `--collect-all`

- **D-11:** `validate-release.sh --collect-all` flag semantics:
  - Runs all 13 cells regardless of individual failures (no fail-fast).
  - Per-cell output unchanged — each cell still prints `PASS`/`FAIL` and
    assertion lines.
  - After all cells complete, emits an **aggregated ASCII table** with columns:
    `Cell | Pass | Fail | Status`. Summary line: `Matrix: X/13 cells passed,
    Y assertions passed, Z assertions failed`.
  - Exit code: **0 if every cell passed; 1 if any cell had at least one fail.**
    No graded exit codes. CI reads the summary table from stdout.

- **D-12:** Default behavior (no `--collect-all`) stays **exactly** as today —
  fail-fast at first red cell, preserved sandbox at `/tmp/tk-matrix-<cell>-<ts>/`,
  `exit 1` at first failure. Zero regression in existing `--all` path.

- **D-13:** Aggregated table format = plain ASCII with `|` separators, no color
  fallback when stdout non-TTY. Chezmoi-grade styling (colors, right-aligned
  counts) is Phase 11 scope (`UX-01`) — do not bundle here.

- **D-14:** `--collect-all` implemented as a flag alongside `--all`, not
  replacing it:
  - `--all` → fail-fast (today's behavior).
  - `--collect-all` → aggregate-then-fail.
  - Mutually exclusive; passing both is an argument error.

### CI integration

- **D-15:** CI bats install = **`bats-core-action`** pinned to full SHA in
  `.github/workflows/quality.yml`. Matches existing pinned-SHA convention
  (checkout@34e1148…, shellcheck@00b27aa…, markdownlint-cli2@455b6612…).
  Avoids brew/apt drift between macOS dev and Linux CI.

- **D-16:** New CI job = **`test-matrix-bats`** (runs `make test-matrix-bats`).
  Parallel to existing `test-init-script` job; does NOT replace it. Runs on
  `ubuntu-latest`. Cell-parity check runs inside the existing
  `validate-templates` job via the `check` target, not a separate job.

### Transition + compatibility

- **D-17:** During transition both bash and bats runners MUST produce identical
  PASS/FAIL counts against the same HEAD. Plan includes a parity-audit step:
  `diff <(bash validate-release.sh --all | grep '^  [✓✗]') <(bats scripts/tests/matrix/*.bats --tap ...)`
  comparison, with deviation = plan-time bug.

- **D-18:** No changes to any cell body semantics. Sandbox paths, env vars,
  stub fixtures (stage_sp_cache, stage_gsd_cache), v3.x worktree setup all
  preserved verbatim. The port is mechanical, not a rewrite.

- **D-19:** Branch naming = `feature/rel-01-bats-port`, `feature/rel-02-cell-parity`,
  `feature/rel-03-collect-all`. One PR per REQ for reviewability.

### Claude's Discretion

- Exact partition of 63 assertions across the 5 bats files — determined by
  existing cell membership in `validate-release.sh`, no redistribution.
- Bats `setup_file` vs `setup` granularity — Claude picks at implement time
  based on fixture reuse patterns.
- Whether `--collect-all` aggregated table uses `printf` width specifiers or
  `column -t` — Claude picks based on macOS BSD compatibility.
- Exact `--cell <name>` placement in `docs/INSTALL.md` (new column vs inline
  command under each scenario) — Claude picks during Plan 8.x for readability.

### Folded Todos

No pending todos matched Phase 8 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` §"Phase 8: Release Quality" — goal, depends, success criteria.
- `.planning/REQUIREMENTS.md` §"Release Quality" — REL-01, REL-02, REL-03 acceptance criteria.
- `.planning/PROJECT.md` §"Constraints" — POSIX-shell invariant, macOS BSD compat, `curl | bash` no-stdin assumption.

### Existing release-validation infra (port targets)
- `scripts/validate-release.sh` — 627-line bash runner, 13 cells, `--all` /
  `--cell` / `--list` / `--self-test` dispatch (lines 573–627).
- `scripts/validate-release.sh` §cell bodies (lines 280–470) — the 13
  `cell_*` functions containing all 63 assertions.
- `scripts/validate-release.sh` §helpers (lines 48–257) — assert_* +
  sandbox_* + stage_* helpers to be extracted to shared lib.
- `scripts/tests/test-matrix.sh` — existing thin wrapper (15 lines) delegating
  to `validate-release.sh --all`. Reference for `test-matrix-bats` wrapper.

### Parity surfaces
- `docs/INSTALL.md` — 77 lines, 4 mode tables, no `--cell` commands present.
  Plan 8.x adds them.
- `docs/RELEASE-CHECKLIST.md` — 117 lines, `--cell <name>` present in table rows
  at lines 14, 31–33, 43–45, 55–57, 67–69, 81. Mode-based section headings.

### Quality gate wiring
- `Makefile` §`check` target (lines 17–18) — where `cell-parity` hooks in.
- `Makefile` §`validate-commands` (lines 217–220) — closest analog for new
  `cell-parity` target (HARDEN-A-01 pattern from Phase 12).
- `.github/workflows/quality.yml` §`validate-templates` job (lines 37–72) —
  where cell-parity CI step hooks in.
- `.github/workflows/quality.yml` §`test-init-script` job (lines 73–94) —
  sibling-pattern for new `test-matrix-bats` job.
- `scripts/validate-commands.py` — reference for the shell-or-Python decision
  (HARDEN-A-01 chose Python; cell-parity stays in pure shell per D-09).

### Manifest and detection (context only — not modified)
- `manifest.json` — file inventory; version currently 3.0.0, CHANGELOG aligned.
- `scripts/detect.sh` — detection (Phase 9 territory; mentioned here only
  because cells stub its outputs via `HAS_SP` / `HAS_GSD` env).
- `scripts/lib/install.sh`, `scripts/lib/state.sh` — sourced by runner.

### Prior-phase contexts (pattern continuity)
- `.planning/milestones/v4.0-phases/07-*` (if present) — original Phase 7
  validation context that produced today's runner.
- `.planning/phases/12-audit-verification-template-hardening/12-CONTEXT.md` —
  most recent CONTEXT.md; pattern reference for decision density and REQ-ID
  wiring.

### External references
- bats-core docs — https://bats-core.readthedocs.io/ (Context7 query at
  plan-research time if needed).
- `bats-core-action` — GitHub Action for CI install; pin to full SHA per
  project convention.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- **`scripts/validate-release.sh`** (627 lines) — single source for all 13 cell
  bodies. Each `cell_*` function is already a self-contained `@test`-shaped
  body. Port is mechanical.
- **Assert helpers** (lines 48–257) — 5 named helpers + 2 generic (`assert_eq`,
  `assert_contains`). Already language-agnostic enough to be sourced from bats.
- **Sandbox helpers** (`sandbox_setup`, `setup_v3x_worktree`) — produce isolated
  `$HOME` per cell. Directly reusable under bats `setup`.
- **Stub fixtures** (`stage_sp_cache`, `stage_gsd_cache`) — synthetic SP/GSD
  plugin trees. Reusable verbatim.
- **`scripts/tests/test-matrix.sh`** — 15-line wrapper template for
  `make test-matrix-bats` target.
- **`scripts/validate-commands.py`** (HARDEN-A-01, Phase 12) — pattern for
  "new check target wired into make check + CI". Cell-parity follows the same
  shape but stays in pure shell (D-09).
- **Pinned-SHA actions in `quality.yml`** — convention for new
  `bats-core-action` reference.

### Established patterns
- **`set -euo pipefail`** at top of every shell script.
- **ANSI color with TTY auto-disable** (`if [ -t 1 ]`) — bash runner already
  does this (lines 24–40). Any new aggregated-table output follows same rule.
- **`HOME` override per cell** for sandboxing — bats `setup` must preserve this.
- **jq for JSON parsing** — state schema, manifest skip sets. No regressions;
  bats tests call the same jq queries.
- **Conventional Commits** — `feat(rel-01):`, `feat(rel-02):`, `feat(rel-03):`
  prefixes.
- **Per-REQ branch + PR** — one PR per requirement when scope permits.

### Integration points
- **`Makefile:17`** — `check` target string extends to add `cell-parity`.
- **`Makefile` new targets** — `cell-parity` + `test-matrix-bats` appended to
  `.PHONY` list and body.
- **`.github/workflows/quality.yml:13–72`** — new bats job slot + parity step.
- **`scripts/validate-release.sh` §dispatcher** (lines 573–627) — adds
  `--collect-all` case alongside `--all`.

### Creative options
- **Shared-lib extraction** (D-02) unlocks future re-use: any new validation
  harness (Phase 9 detection tests, Phase 11 styled-diff tests) can source the
  same `helpers.bash` and inherit the assert_* vocabulary.
- **Aggregated table** (D-11) is a primitive that Phase 11's chezmoi-grade
  styled diff can later color without touching the data layer.

### Constraints surfaced during scout
- **bats not installed locally** — developers need `brew install bats-core`
  (macOS) once. README / CLAUDE.md gets a one-liner install hint.
- **macOS BSD `column -t`** has different flags than GNU — aggregated table
  formatting must avoid GNU-only options (printf width specifiers are safe).
- **`curl | bash` no-stdin** invariant untouched — neither bats port nor
  parity check run in that pipe; both are dev/CI-only surfaces.

</code_context>

<specifics>
## Specific Ideas

- REL-02 spec phrasing says "section heading in `docs/RELEASE-CHECKLIST.md`"
  but the doc's actual structure is mode-grouped, not cell-grouped. D-06
  relaxes the surface definition to `--cell <name>` command occurrences,
  matching the doc's real cross-reference pattern. If planner prefers strict
  section-heading parity, that requires per-cell headings in RELEASE-CHECKLIST
  (doubling its length) — explicitly rejected here.

- `docs/INSTALL.md` intro says "12 cells" (line 1); runner has 13. This
  pre-existing drift is fixed as a side effect of REL-02 surface work.

- Translation-sync is the 13th cell but behaves structurally different from
  the 12 mode×scenario cells (runs `make translation-drift` under the hood).
  All 13 cells (including translation-sync) go through the parity gate.

- Plan-time parity audit (D-17) is a one-time diff, not an ongoing gate. If
  bats and bash runners diverge after this phase (e.g., v4.2 Phase X fixes
  an assertion in one but not the other), that's a review-time catch, not a
  CI gate. Adding a CI-time PASS-count diff is a Phase 9+ candidate if drift
  becomes a real problem.

- Phase 11 (UX-01 chezmoi-grade `--dry-run`) will restyle output across
  install/update/migrate. REL-03's aggregated table is intentionally plain
  ASCII here so Phase 11 can theme it later without semantic churn.

</specifics>

<deferred>
## Deferred Ideas

- **Remove bash `validate-release.sh`** after bats suite proves parity — v4.2+.
  Keeping both during transition (D-05) is explicit REL-01 scope.
- **Per-cell section headings in `docs/RELEASE-CHECKLIST.md`** — rejected;
  would double doc length for no reader benefit. Mode-grouped structure stays.
- **JSON output from `--collect-all`** — not in scope; ASCII table only.
  If a tooling need arises (release dashboard, etc.), add `--collect-all
  --json` flag later.
- **Graded exit codes from `--collect-all`** (e.g., exit N = N cells failed)
  — rejected; standard 0/1 is enough for CI. Summary table carries the
  detail.
- **Auto-updating `docs/INSTALL.md` cell count** from `validate-release.sh
  --list` — Phase 9+ consideration if cells grow beyond the current 13.
- **Test 16 (`scripts/tests/test-matrix.sh`) becoming a bats-aware wrapper**
  — deferred; existing `make test` flow unchanged in Phase 8.
- **Reviewed Todos (not folded):** none — no pending todos matched this
  phase's scope.

</deferred>

---

*Phase: 08-release-quality*
*Context gathered: 2026-04-24*
