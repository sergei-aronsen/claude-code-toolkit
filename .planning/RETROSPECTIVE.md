# Project Retrospective

*Living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v4.0 — Complement Mode

**Shipped:** 2026-04-21
**Phases:** 8 (1–7 + 6.1 inserted) | **Plans:** 29 | **Tasks:** 56 | **Timeline:** 5 days (2026-04-17 → 2026-04-21)

### What Was Built

- Complement-aware install flow with 4 modes (`standalone`, `complement-sp`, `complement-gsd`, `complement-full`), manifest-driven skip-lists, atomic `~/.claude/toolkit-install.json` state with SHA256 hashes + `mkdir`-based lock
- Smart `update-claude.sh` that re-evaluates detection per-run, surfaces mode drift, handles new/removed/modified files from manifest diff, produces 4-group summary with `<unix-ts>-<pid>` tree backups
- `migrate-to-complement.sh` with three-way diff (TK template / on-disk / SP equivalent), two-signal user-modification detection, `[y/N/d]` per-file prompts, idempotent re-runs
- Complement-first README + 8 translations (de, es, fr, ja, ko, pt, ru, zh) within ±20% line-count drift, 7 framework templates with "Required Base Plugins" section, `docs/INSTALL.md` 12-cell matrix
- Release validation: `scripts/validate-release.sh` runs 13 sandbox cells with 63 assertions; `Makefile` enforces `version-align` + `translation-drift` + `agent-collision-static` via `make check`

### What Worked

- **Manifest-driven single source of truth** — `manifest.json` v2 with per-file `conflicts_with` eliminated parallel skip-list arrays in shell scripts; `make check` catches drift automatically
- **Sandbox-isolated install matrix** — `HOME=/tmp/tk-matrix-<cell>-<ts>/...` pattern let validate-release.sh exercise all 4 modes + fresh/upgrade/rerun scenarios without Docker dependency, matching the "POSIX shell, no runtime deps" invariant
- **Compose-existing-tests pattern** — Phase 7 matrix runner composed the 14 pre-existing `scripts/tests/*.sh` helpers instead of reimplementing invariants; dropped implementation cost significantly
- **Phase 6.1 insertion (decimal phase) mid-milestone** — when user reversed Phase 6's "translations deferred to v4.1" decision, `/gsd-insert-phase 6.1` created a clean phase boundary (7.1 syncs, 7 validates) without corrupting Phase 6 context or ROADMAP structure
- **Auto-chain discuss → plan → execute** for uncontested phases; human-verify checkpoint (`autonomous: false`) for the CHANGELOG date flip kept agent out of release-tag territory
- **Ready-to-tag boundary (D-08)** — ending Phase 7 at "CHANGELOG date flipped, `make check` green, tag manual" preserved the CLAUDE.md "never push directly to main" invariant; no agent-cut release tags

### What Was Inefficient

- **Initial Phase 6 deferral of translations** cost a round-trip: decision reversed mid-discuss, required inserting 6.1, Phase 7 gates had to wait on 6.1 landing. Lesson: don't defer tightly-coupled artifacts across milestone boundaries
- **Plan 07-04 release-gate triad** (pre-flight checkpoint + auto edit + final sign-off) re-ran every gate twice (once pre-edit, once post-edit) — correct for safety but expensive. Could be tightened with conditional re-run if edit scope is single-line
- **CLI audit-open broken at milestone close** (`ReferenceError: output is not defined` in `gsd-tools.cjs:786`) — couldn't run pre-close artifact audit. Worked around by skipping the step manually; needs upstream fix
- **Milestone-complete CLI accomplishment extraction** grabbed one-liner noise ("One-liner:", "Site 1", etc.) from SUMMARY.md frontmatter fields — had to rewrite MILESTONES.md by hand. CLI needs smarter summary-extract
- **ROADMAP checkbox drift** — phases 2–5 had `disk_status: complete` but `roadmap_complete: false` at milestone close; required 5 manual `update-plan-progress` calls. Should auto-sync on plan completion

### Patterns Established

- **`set -euo pipefail` + `&& rc=0 || rc=$?`** for exit-code capture without aborting — now the canonical bash idiom in this repo (see `validate-release.sh` cells)
- **`_tk_owned` marker** for settings.json merge — distinguishes TK-owned hook entries from SP/GSD entries, enables append-both policy without clobbering
- **Decimal phase insertion** (`6.1`) for urgent mid-milestone scope adjustments — clean roadmap, preserves existing phase contexts, ROADMAP renders them in-order
- **Dual-surface release checklist** — `docs/RELEASE-CHECKLIST.md` (human-readable) + `scripts/validate-release.sh` (runner) sharing the same cell snippets; one truth, two views
- **Phase-completion manual tag boundary** — milestone CLI archives; human cuts the release tag outside any GSD workflow

### Key Lessons

1. **Tightly-coupled artifacts (code + docs + translations) should ship in the same milestone** — deferring one across the boundary creates downstream blockers that force urgent decimal insertions
2. **Non-autonomous plans (`autonomous: false`) belong at release gates** — the CHANGELOG date flip would have been wrong to auto-commit without human approval; the checkpoint triad is the right shape
3. **Manifest v2 + `make check` beats runtime detection** — declarative conflicts annotated in `manifest.json` with static CI gates catches drift before install, no runtime sandbox needed
4. **Filesystem detection beats CLI detection for install-time logic** — `[ -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/ ]` is instant + dependency-free; `claude plugin list` can come later as an enhancement (DETECT-FUT-01)
5. **Compose existing test scripts, don't reimplement** — the 14 `scripts/tests/*.sh` atoms made the 13-cell matrix runner cheap; adding a new cell means composing existing assertions, not writing new ones

### Cost Observations

- **Model mix:** ~80% Sonnet (execution), ~15% Opus (planning + hard debugging), ~5% Haiku (codebase mapping)
- **Commits:** 50 total (33 feat, 26 fix, 50 docs — overlapping since conventional commits)
- **Notable efficiency:** Phase 7.1 (translations, 3 plans) executed in ~50 min wall-time — reusing English README as structural skeleton + ±20% drift gate kept scope tight; no per-language deep review needed
- **Notable cost:** Plan 07-04 ran `make check` + `validate-release.sh --all` (13 cells, 63 assertions) three times (pre-flight, post-edit, final sign-off) — ~3 min × 3 = ~9 min of gate runs per gate cycle. Acceptable for release gate; not for per-plan verification

---

## Milestone: v4.1 — Polish & Upstream

**Shipped:** 2026-04-25
**Phases:** 5 (8–12; Phase 12 inserted) | **Plans:** 13 | **REQ-IDs:** 11 | **Timeline:** 4 days (2026-04-21 → 2026-04-25)

### What Was Built

- Bats-based 13-cell install matrix (`scripts/tests/matrix/*.bats` + `helpers.bash`), `cell-parity` 3-surface gate, `--collect-all` aggregated runner mode (Phase 8)
- `scripts/lib/backup.sh` shared library: `--clean-backups` flag with size+age listing, threshold warnings, `--keep N` retention; `claude plugin list` cross-check as 4th detection layer (FS still primary); version-skew warnings on plugin updates (Phase 9)
- Three filed upstream issues in `gsd-build/get-shit-done` (#2659, #2660, #2661) with full repro + suggested fixes — zero toolkit code changes per SC4 (Phase 10)
- `scripts/lib/dry-run-output.sh` shared library + chezmoi-grade `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` grouped output across all 3 install scripts; NO_COLOR + non-TTY gates (Phase 11)
- ChatGPT pass-3 audit verified against codebase (8 FALSE, 6 PARTIAL deferred, 1 REAL); Wave-A `validate-commands.py` linting commands/*.md headings (Phase 12)

### What Worked

- **Cherry-pick over plugin install** — evaluated `forrestchang/andrej-karpathy-skills` (83K stars) and pulled only "Surgical Changes" rule into `components/`; rejected the full plugin (3/4 rules duplicated existing coverage). Pattern: measure before importing
- **Audit-then-implement gate** — Phase 12 verified 15 ChatGPT claims with `grep` + file reads BEFORE any hardening work; 8/15 turned out to be FALSE (hallucinated features that already existed). Saved a milestone of redundant work
- **Shared lib precedent reused** — `scripts/lib/dry-run-output.sh` (Phase 11) followed the `scripts/lib/backup.sh` pattern (Phase 9): mktemp download via curl, sourced-lib invariant, contract-tested via shell tests. Same pattern landed twice = pattern is now canonical
- **`fetch-depth: 0` for upstream worktree creation** — bats `-upgrade` cells were silently dropping in CI shallow clones; one-line `with: fetch-depth: 0` on `actions/checkout@v4` unblocked all 4 missing tests
- **Sequential dispatch + USE_WORKTREES=false** — running parallel-eligible plans sequentially on main tree avoided `.git/config.lock` contention and post-wave merge complexity. Trade slight wall-time for simpler invariants
- **`--auto` chain for predictable phases** — `/gsd-plan-phase N --auto` → research → plan → checker → execute → verify worked end-to-end for Phases 10/11. No interactive checkpoints needed for well-scoped work

### What Was Inefficient

- **CI gaps surfaced 59 commits late** — Phase 8 SC2034 + bats fetch-depth bugs only fired when accumulated commits hit `git push`. `make check` doesn't run bats matrix locally, so local-only validation missed them. Lesson: push more frequently, or add bats to `make check` when feasible
- **Open question A3 in Phase 11 research** — researcher asked "does update --dry-run mean full preview before write?" instead of recommending YES with rationale. Planner had to confirm. Future RESEARCH.md templates should default to confident recommendations with reversal hooks
- **MILESTONES.md accomplishment extraction (UPSTREAM-02 bug)** — `gsd-tools milestone complete` populated v4.1 entry with "One-liner:" labels and YAML frontmatter noise. We literally filed this as UPSTREAM-02 in this same milestone. Hand-rewrote the entry post-archive. Bug is upstream
- **Pre-close audit-open ReferenceError (UPSTREAM-01)** — couldn't run automated open-artifacts audit at milestone close, had to verify by hand. Same upstream bug we filed
- **Stale matrix worktrees in /tmp/** — Phase 8 bats runs left 16 detached-HEAD worktrees in `/tmp/tk-matrix-worktree-*` that needed manual `git worktree remove`. Sandbox cleanup should be automatic in `helpers.bash`

### Patterns Established

- **`scripts/lib/<feature>.sh` shared libraries** sourced via curl-to-mktemp by all install scripts — established by `backup.sh` (Phase 9), reaffirmed by `dry-run-output.sh` (Phase 11). New convention: per-feature libs in `scripts/lib/`, each with its own contract tests
- **NO_COLOR via `${NO_COLOR+x}` (presence test, not value test)** — survives `set -u`, matches no-color.org spec. Combined with `[ -t 1 ]` for TTY detection
- **Inserted phases for retroactive verification** — Phase 12 was inserted between Phase 8 execution and Phase 11 to ground-truth the ChatGPT audit before any HARDEN-* implementation. Decimal phases (`6.1` in v4.0) for forward-scope reversals; integer phases for retroactive insertions
- **External-repo triage matrix** — measure (size/lines), grid against existing toolkit coverage, install-as-is only if <50% overlap, otherwise cherry-pick concept. Documented in `project_surgical_changes_component.md` memory

### Key Lessons

1. **CI must run on every push, not every milestone** — 59 commits accumulated CI debt fired in one shot at Phase 11 close. Push at minimum after each phase; bats/expensive tests should opt-in via `make check-full` if needed
2. **Verify external audit claims before implementing** — Phase 12 found 8/15 ChatGPT claims were hallucinations of "missing" features that already existed. Always grep + file-read before opening a hardening wave
3. **Cherry-pick > install for thin viral repos** — high star count ≠ high substance. Karpathy plugin = 65 lines, 3/4 already covered. Treat external skills as inspiration, not dependencies
4. **Filing upstream issues IS shipped work** — Phase 10 (3 issues filed) was a full milestone phase with research, plan, checker, executor, verifier. Same gates applied to docs-only deliverables as code deliverables. Quality stays high
5. **Sandbox cleanup must live with the test, not the orchestrator** — orphaned `/tmp/tk-matrix-worktree-*` accumulated across CI runs. `trap cleanup EXIT` in `helpers.bash` would have cleaned automatically

### Cost Observations

- **Model mix:** ~70% Sonnet (executors + checkers), ~25% Opus (Phase 11 planner + cross-file orchestrator), ~5% Haiku (none used this milestone)
- **Commits:** ~50 in v4.1 (research/plan/exec/verify cycle per phase). 18 commits accumulated before final push (compared to v4.0's per-phase pushes)
- **Notable efficiency:** Phase 10 (file 3 issues) executed in ~5 min wall-time — single plan, 3 sequential `gh issue create` tasks, body files pre-redacted
- **Notable cost:** Phase 11 planner ran 895s (15 min, ~226K tokens) on Opus — 3 plans × 2 tasks × full ANSI/printf specifications + threat model + cross-plan contracts. Acceptable for shared-lib coordination phase

---

## Milestone: v4.2 — Audit System v2

**Shipped:** 2026-04-26
**Phases:** 5 (13–17) | **Plans:** 22 | **REQ-IDs:** 22 | **Timeline:** 2 days (2026-04-25 → 2026-04-26)

### What Was Built

- Persistent FP allowlist at `.claude/rules/audit-exceptions.md` (`globs:["**/*"]`) + `/audit-skip` (validated append, exact-triple dedupe, atomic write) + `/audit-restore` (`[y/N]` default-N, comment-aware sed-strip + `in_comment` awk state machine); installer wiring across `init-claude.sh` / `init-local.sh` / `update-claude.sh` (Phase 13)
- `commands/audit.md` rewritten as 6-phase workflow (load context → quick check → deep analysis → 6-step FP recheck → structured report → Council pass); reports land at `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` with verbatim ±10-line code blocks per finding + `Skipped (allowlist)` + `Skipped (FP recheck)` tables; locked by Test 17 (82 assertions) (Phase 14)
- Mandatory `/council audit-review --report <path>` pass with byte-exact `<verdict-table>` + `<missed-findings>` contract; per-finding `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT` + `[0.0, 1.0]` confidence; severity reclassification forbidden by prompt; `brain.py` parallel Gemini+ChatGPT with `disputed` flagging (Phase 15)
- 49 framework prompts spliced with 4 contract blocks (allowlist callout, FP-recheck SELF-CHECK, structured OUTPUT FORMAT, Council handoff footer) in atomic commit `33be0b1`; CI gate Test 20 + `validate-templates` (Phase 16)
- `manifest.json` 4.2.0 with `audit-exceptions.md` + `audit-review.md` registered; mtime-aware Council prompt installer in `setup-council.sh` Step 4 + `init-claude.sh setup_council()`; `CHANGELOG.md` `[4.2.0]` shipped 2026-04-26 (Phase 17)

### What Worked

- **Byte-exact contracts as the unit of work** — `<verdict-table>` and `<missed-findings>` markers were specified verbatim in plans, so executors couldn't drift; tests assert literal strings; Council prompt + auditor prompt + `brain.py` parser all agree by string identity, not interpretation
- **One atomic 49-file splice** (Phase 16) — propagating to 7 frameworks × 7 prompt types in a single commit kept the changeset reviewable as one unit; `make validate` either passes or fails the whole set, no partial drift
- **Splice script as the contract** — `scripts/propagate-audit-pipeline-v42.sh` made the 49-file change reproducible: re-run produces zero diff, regression tests assert idempotency. Beats hand-editing 49 files
- **Test 17 + Test 19 + Test 20 layered gates** — Test 17 locks audit pipeline schema, Test 19 locks Council fixture verdicts, Test 20 locks template propagation markers. Three independent gates surface drift at different layers
- **Severity-reclass-forbidden contract (COUNCIL-02)** — splitting "find" (auditor) from "verify" (Council) as separate single-purpose roles eliminated drift category; the Council literally cannot widen scope, only confirm/reject
- **D-12 nudge over auto-write** — `/audit` printing FP verdict + telling user to invoke `/audit-skip` (instead of auto-writing) keeps the user in the loop and prevents Council from overwriting the allowlist

### What Was Inefficient

- **`gsd-tools milestone complete` accomplishment extraction** still grabs SUMMARY.md noise ("One-liner:", "1. [Rule 1 - Bug]", code fences) — same upstream bug that bit v4.1, still unfixed, hand-rewrote MILESTONES.md again. Filed as #2660 during v4.1; remains open
- **Pre-close `audit-open` ReferenceError (#2659)** still throws on every milestone close — same upstream bug as v4.1, skipped audit step manually again
- **STATE.md `milestone_name` field** got literal placeholder `"milestone"` instead of `"Audit System v2"` — `gsd-tools milestone complete` warned about field name drift but didn't update; required hand-fix
- **Phase 17 had no real research** — distribution work (manifest bump + CHANGELOG date stamp + installer wiring) is mechanical; the research → plan → checker → executor cycle was overkill. Could have been a `/gsd-quick` pass, not a full phase
- **STATE.md "Deferred Items" table grew junk rows** — `gsd-tools` appended "Phase 13 P01 | 4 | 1 tasks | 1 files" duration entries to the deferred-items table during execution. Not deferrals at all, just stats. Hand-pruned at close

### Patterns Established

- **Byte-exact prompt contracts + test-asserted markers** — Council `<verdict-table>` + `<missed-findings>`, audit-prompt "Council handoff" footer, FP-recheck 6 numbered steps. Pattern: name a literal string, lock it via `grep -F` in a CI gate, never paraphrase
- **Splice script + idempotency test** — large multi-file content changes (49 files) ship as a script + a regression test asserting "running it twice produces no diff", never as a hand-commit
- **Three-layer audit pipeline gate** — schema test (Test 17) + verdict-fixture test (Test 19) + propagation test (Test 20). Each layer can fail independently, surfacing the regression at the right altitude
- **Single-purpose AI roles** — auditor finds, Council confirms, user persists. No role widens beyond contract. Locked by COUNCIL-02 (no severity reclass) + COUNCIL-05 (no auto-write)
- **mtime-aware idempotent installer** — `setup-council.sh` Step 4 only re-downloads `audit-review.md` if upstream is newer (`-nt`). Prevents clobbering local modifications; pattern reusable for future Council prompts

### Key Lessons

1. **Council's job is verification, not search** — letting Council reclassify severity merges two responsibilities and creates drift surface. The auditor owns the label; Council says only REAL/FALSE_POSITIVE. Locked by COUNCIL-02
2. **Verbatim code in the report beats verbatim summary** — embedding ±10 lines of actual source per finding (AUDIT-03) made disputed verdicts re-checkable offline; "trust the rule label" never works for cross-AI verification
3. **Mandatory > optional for trust gates** — a `--no-council` flag would have eroded the FP discipline under deadline pressure. Mandatory pass forces the cost upfront, every time. Revisit only if friction surfaces
4. **Atomic-commit propagation > per-file commits** for content-heavy phases — 49 files spliced in one commit kept review tractable; per-framework commits would have created 7-way drift surface
5. **Upstream bugs in the planning toolchain stay broken** — v4.0 → v4.1 → v4.2 all hit the same `audit-open ReferenceError` and same accomplishment-extraction noise. Filing issues isn't a fix; either patch upstream or stop using the broken commands

### Cost Observations

- **Model mix:** ~70% Sonnet (executors + 49-file splice), ~25% Opus (Phase 14 audit-pipeline cross-file orchestrator + Council prompt design), ~5% Haiku (codebase grep for marker assertions)
- **Commits:** 82 in v4.2 (`v4.1.1 → v4.2.0`); 207 files changed (+39997 / −18884)
- **Notable efficiency:** Phase 16 (49 prompt files) shipped in ~30 min wall-time after the splice script landed — script ran once, regression test confirmed idempotency, atomic commit
- **Notable cost:** Phase 14 cross-file orchestrator on Opus (~12 min) — `commands/audit.md` rewrite needed full ANSI/printf-style contract specification + threat model + 5 success criteria. Acceptable for the workflow contract that 49 prompts inherit

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Plans | Key Change |
|-----------|----------|--------|-------|------------|
| v4.0 | ~12 | 8 | 29 | Introduced complement-aware install + 4-mode matrix + insert-phase pattern for mid-milestone scope reversal |
| v4.1 | ~6 | 5 | 13 | Audit-then-implement gate (Phase 12), shared-lib pattern (`backup.sh` + `dry-run-output.sh`), upstream-issue-as-shipped-work (Phase 10) |
| v4.2 | ~5 | 5 | 22 | Byte-exact prompt contracts + test-asserted markers, splice-script + idempotency-test pattern for content-heavy phases, single-purpose AI role split (auditor finds / Council confirms / user persists) |

### Cumulative Quality

| Milestone | Tests | CI Gates | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v4.0 | 16 (`make test` harness) | shellcheck + markdownlint + validate + validate-base-plugins + version-align + translation-drift + agent-collision-static | 0 new runtime deps |
| v4.1 | 16 + bats 13-cell matrix + 3 dry-run test scripts (test-dry-run/test-update-dry-run/test-migrate-dry-run) | + cell-parity + validate-commands (commands/*.md headings) + bats matrix CI job | 0 new runtime deps; bats-core via pinned action only in CI |
| v4.2 | + Test 17 (audit pipeline, 82 assertions) + Test 19 (Council audit-review, 4-file fixture) + Test 20 (template propagation, 49-file marker regression) | + `validate-templates` job asserts `Council handoff` + 6 FP-recheck steps on all 49 prompts | 0 new runtime deps |

### Top Lessons (Verified Across Milestones)

1. **Filesystem detection beats CLI detection for install-time logic** — confirmed v4.0 (DETECT-01..05) and v4.1 (DETECT-06 added CLI as secondary cross-check, never primary)
2. **`make check` enforced gates beat documentation-only conventions** — every gate added (translation-drift, agent-collision-static in v4.0; cell-parity, validate-commands in v4.1; `validate-templates` Council/FP-recheck markers in v4.2) caught drift that prose docs alone would have let slip
3. **Manual release tag boundary holds (D-08)** — v4.0, v4.1, v4.2 all ended at "ready-to-tag, agent stops"; user cuts tag outside any workflow. CLAUDE.md "never push directly to main" invariant respected across three milestones
4. **Shared `scripts/lib/<feature>.sh` is now the convention** — `backup.sh` (v4.1) + `dry-run-output.sh` (v4.1) + the v4.0-era `install.sh` form a consistent pattern. New install-time logic should land here, not inlined in scripts
5. **Byte-exact contract strings beat prose specs for cross-AI work** (NEW v4.2) — Council prompt + auditor prompt + `brain.py` all agreed by literal `<verdict-table>` / `<missed-findings>` markers, not interpretation. Pattern: name the string, lock it via `grep -F` in CI, never paraphrase
6. **Upstream `gsd-tools` bugs persist across closes** (NEW v4.2) — `audit-open ReferenceError` (#2659) and accomplishment-extraction noise (#2660) hit v4.0, v4.1, v4.2 milestone closes identically. Filing issues isn't a fix; either patch upstream or stop using the broken commands
