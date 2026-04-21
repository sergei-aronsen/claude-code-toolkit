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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Plans | Key Change |
|-----------|----------|--------|-------|------------|
| v4.0 | ~12 | 8 | 29 | Introduced complement-aware install + 4-mode matrix + insert-phase pattern for mid-milestone scope reversal |

### Cumulative Quality

| Milestone | Tests | CI Gates | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v4.0 | 16 (`make test` harness) | shellcheck + markdownlint + validate + validate-base-plugins + version-align + translation-drift + agent-collision-static | 0 new runtime deps — everything stays POSIX shell + `jq` + `python3` (for JSON escape only) |

### Top Lessons (Verified Across Milestones)

_First milestone — cross-validation begins in v4.1._

1. _(placeholder — cross-milestone trend patterns emerge after 2+ milestones shipped)_
