# claude-code-toolkit

## What This Is

A toolkit that augments **Claude Code** with CLAUDE.md templates, slash commands, components, skills, and the Supreme Council multi-AI plan validator. Targets solo developers who want a curated, framework-aware setup on top of base plugins (`superpowers`, `get-shit-done`).

After v4.0 the toolkit positions itself as a **complement, not a replacement**: at install time it detects whether `superpowers` and `get-shit-done` are present and only installs files that do not duplicate those plugins. Users without the bases still get the full standalone install.

## Core Value

**Install only what adds value over `superpowers` + `get-shit-done`.** No duplicate commands, no shadow agents, no name collisions. The toolkit's unique contributions (Council, framework CLAUDE.md templates, components library, cheatsheets) are always installed; everything else is conditional on detected base plugins.

## Requirements

### Validated

<!-- Inferred from existing codebase as of v3.0.0 -->

- ✓ 7 framework CLAUDE.md templates (`base`, `laravel`, `rails`, `nextjs`, `nodejs`, `python`, `go`) — `templates/`
- ✓ 29 slash commands shipped via `commands/*.md` — `commands/`
- ✓ 30 reusable components in `components/*.md` for assembling custom CLAUDE.md
- ✓ 9 cheatsheets (en, ru, de, fr, es, pt, zh, ja, ko) — `cheatsheets/`
- ✓ Supreme Council (multi-AI debate: Gemini + ChatGPT) — `commands/council.md`, `scripts/setup-council.sh`, installs to `~/.claude/council/`
- ✓ Smart update mechanism via `manifest.json` versioning — `scripts/update-claude.sh`
- ✓ Install scripts: global (`init-claude.sh`), local (`init-local.sh`), update (`update-claude.sh`), security (`setup-security.sh`), statusline (`install-statusline.sh`)
- ✓ Markdown linting toolchain (markdownlint + shellcheck + custom validate) — `Makefile`
- ✓ CI quality gate via GitHub Actions — `.github/workflows/quality.yml`
- ✓ Codebase map produced and committed in `.planning/codebase/`
- ✓ `update-claude.sh` re-evaluates detection on every run, surfaces mode drift, diffs against manifest, and prints 4-group summary — Validated in Phase 4: update-flow (UPDATE-01..06)
- ✓ `migrate-to-complement.sh` enumerates v3.x duplicates, shows three-way diff, backs up before removal, requires per-file confirmation, rewrites state to `complement-*` mode, is idempotent — Validated in Phase 5: migration (MIGRATE-01..06)
- ✓ README repositions toolkit as "plays nicely with `superpowers` + `get-shit-done`" — Validated in Phase 6: documentation (DOCS-01)
- ✓ Each `templates/*/CLAUDE.md` documents required base plugins and how this toolkit layers on top — Validated in Phase 6: documentation (DOCS-02)
- ✓ Bump version to `4.0.0` and document breaking changes in `CHANGELOG.md` — Validated in Phase 6: documentation (DOCS-03)
- ✓ `docs/INSTALL.md` 12-cell install matrix (4 modes × 3 scenarios) — Validated in Phase 6: documentation (DOCS-04)
- ✓ Recommended optional plugins documented (rtk, caveman, superpowers, get-shit-done) with caveats and upstream verification — Validated in Phase 6: documentation (DOCS-05, DOCS-06, DOCS-07, DOCS-08)
- ✓ Install matrix ported to bats under `scripts/tests/matrix/*.bats` with shared `scripts/tests/matrix/lib/helpers.bash` lib; 63 assertions preserved 1:1; `make test-matrix-bats` + CI job pinned to `bats-core/bats-action@77d6fb60…` — Validated in Phase 8: release-quality (REL-01)
- ✓ `scripts/cell-parity.sh` enforces 3-surface parity (validate-release.sh --list × docs/INSTALL.md × docs/RELEASE-CHECKLIST.md); wired into `make check` + CI `validate-templates`; INSTALL.md carries 13 `--cell` commands + "13 cells" intro — Validated in Phase 8: release-quality (REL-02)
- ✓ `scripts/validate-release.sh --collect-all` runs all 13 cells with aggregated ASCII table; `--all` fail-fast unchanged; `--all` + `--collect-all` mutex error — Validated in Phase 8: release-quality (REL-03)

## Current Milestone: v4.1 Polish & Upstream

**Goal:** Harden the v4.0 release cycle with bats-based matrix automation, backup hygiene, detection enhancements, and UX polish — plus file upstream GSD CLI issues discovered during v4.0.

**Target features:**

- Release quality (bats-based install matrix, docs cell-parity check, `--collect-all` for `validate-release.sh`)
- Backup hygiene (`--clean-backups` flag, threshold warnings)
- Detection enhancements (`claude plugin list` integration, plugin version skew detection)
- Upstream GSD CLI issues (file in `gsd-build/get-shit-done`, do NOT patch in this repo)
- UX polish (chezmoi-grade styled `--dry-run` diff)

### Active

<!-- v4.1 milestone: Polish & Upstream -->

- [x] **REL-01** — Migrate install matrix from bash `validate-release.sh` to bats (TEST-01 carryover) — shipped Phase 8
- [x] **REL-02** — Auto-check cell parity between `docs/INSTALL.md` and `docs/RELEASE-CHECKLIST.md` — shipped Phase 8
- [x] **REL-03** — Add `--collect-all` fail mode to `scripts/validate-release.sh` (default stays fail-fast) — shipped Phase 8
- [ ] **BACKUP-01** — `--clean-backups` flag for `scripts/update-claude.sh` (carryover)
- [ ] **BACKUP-02** — Warn when backup directory count exceeds threshold (carryover)
- [ ] **DETECT-06** — Integrate `claude plugin list` as detection input alongside filesystem check
- [ ] **DETECT-07** — Detect SP/GSD version skew between install time and current, emit warning
- [ ] **UPSTREAM-01** — File issue in `gsd-build/get-shit-done` for `audit-open` ReferenceError (`gsd-tools.cjs:786`)
- [ ] **UPSTREAM-02** — File issue in `gsd-build/get-shit-done` for `milestone complete` accomplishment-extraction noise
- [ ] **UPSTREAM-03** — File issue in `gsd-build/get-shit-done` for missing auto-sync of ROADMAP checkboxes on plan completion
- [ ] **UX-01** — chezmoi-grade styled diff output for `--dry-run` mode

<details>
<summary>v4.0 requirements moved to Validated (shipped 2026-04-21)</summary>

- ✓ Detect installed `superpowers` (filesystem path: `~/.claude/plugins/cache/claude-plugins-official/superpowers/`) — v4.0 Phase 2 (DETECT-01..05)
- ✓ Detect installed `get-shit-done` (filesystem path: `~/.claude/get-shit-done/`) — v4.0 Phase 2 (DETECT-02)
- ✓ 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full` — v4.0 Phase 3 (MODE-01)
- ✓ Auto-recommend mode based on detection; user-overridable — v4.0 Phase 3 (MODE-02, MODE-03)
- ✓ Skip-list per mode via manifest — v4.0 Phase 3 (MODE-04, MODE-06)
- ✓ `~/.claude/toolkit-install.json` install state with SHA256 + atomic writes + mkdir lock — v4.0 Phase 2 (STATE-01..05)
- ✓ `manifest.json` v2 schema with `conflicts_with` / `requires_base` — v4.0 Phase 2 (MANIFEST-01..04)
- ✓ `setup-security.sh` safe JSON merge with `_tk_owned` marker + backup + restore-on-failure — v4.0 Phase 3 (SAFETY-01..04)
- ✓ 13-cell install matrix validated via `scripts/validate-release.sh --all` (63 assertions) — v4.0 Phase 7 (VALIDATE-01..04)

</details>

### Out of Scope

- Re-implementing `superpowers` or `get-shit-done` features in TK — duplicates the source-of-truth, hard to keep in sync
- Auto-installing SP/GSD on user's behalf — user controls their plugin set; we only suggest
- Migrating users without consent — every change to user filesystem requires explicit `[y/N]` prompt and backup
- Detection via `claude plugin list` (CLI) as primary path — filesystem detection remains primary in v4.1; CLI is added as a secondary input (DETECT-06), never sole source
- Splitting Council into a separate plugin — Council is TK's killer feature, splitting adds maintenance overhead with no clear win
- Backwards-compat shims to keep deprecated TK commands working alongside SP/GSD equivalents — clean break, conventional commits with `BREAKING CHANGE:` footers

## Context

- **Target user:** solo developer using Claude Code with global `~/.claude/` install. Has likely installed `superpowers` (obra) and `get-shit-done` (gsd-build) plugins already, or will soon.
- **Distribution:** repository at `sergei-aronsen/claude-code-toolkit`, installed via `curl ... | bash` or `git clone`. License MIT. Maintainer: Sergei Aronsen.
- **Codebase state (from `.planning/codebase/`):** Markdown + Shell + YAML repo, no runtime. ~30 commands, ~30 components, 7 templates, 9 cheatsheets, manifest-driven updates.
- **Known concerns surfaced by codebase mapper (`.planning/codebase/CONCERNS.md`):**
  - `commands/design.md` missing from `update-claude.sh:147` (drift vs `manifest.json:30`)
  - Version drift: `manifest.json` 3.0.0 vs `init-local.sh:11` 2.0.0 vs `CHANGELOG.md` empty `[Unreleased]`
  - `update-claude.sh:186-195` uses GNU-only `head -n -1` — silent breakage on macOS BSD
  - `setup-council.sh` reads stdin without `< /dev/tty` — fails under `curl | bash`
  - `setup-security.sh` mutates `~/.claude/settings.json` without backup
  - Cross-template skill divergence
- **Confirmed conflicts with SP/GSD (from analysis):**
  - 7 hard duplicates: TK `commands/{debug,tdd,worktree,verify,checkpoint,handoff,learn,audit,context-prime,plan}.md`, TK `templates/base/skills/debugging/`, TK `templates/base/agents/{code-reviewer,planner}.md`
  - Critical: `code-reviewer` agent has identical name in both TK and SP — direct namespace collision
  - TK `commands/debug.md` even copies the "Iron Law" formulation from SP `systematic-debugging` skill verbatim
- **Unique TK value (must survive every install mode):** Council, CLAUDE.md framework templates, components library, cheatsheets, `helpme`/`find-function`/`find-script`/`update-toolkit`/`rollback-update` utility commands, framework-specific skills (`tailwind`, `i18n`, `observability`, `llm-patterns`, `api-design`, `database`, `docker`, `ai-models`).

## Constraints

- **Tech stack**: Markdown + POSIX shell (bash, must work on macOS BSD and GNU Linux). No Node/Python runtime dependency for install scripts.
- **Compatibility**: install scripts must work under `curl ... | bash` (no stdin assumptions without `< /dev/tty`); macOS BSD `head`/`sed`/`tail` (no GNU-only flags).
- **Safety**: never overwrite `~/.claude/settings.json` without backup and JSON merge; never delete user files without confirmation; every destructive action prompts.
- **Detection**: filesystem-only (no `claude plugin list` dependency in v4.0).
- **Quality gate**: `make check` (markdownlint + shellcheck + validate) must pass on every PR; CI enforced via `.github/workflows/quality.yml`.
- **Versioning**: v4.0.0 is a breaking release — `manifest.json`, `CHANGELOG.md`, `init-local.sh`, and any other version reference must align.
- **Commits**: Conventional Commits, branches `feature/xxx` / `fix/xxx`, never push directly to `main`.

## Current State

**Shipped:** v4.0 Complement Mode (2026-04-21) — 8 phases, 29 plans, 56 tasks.

Toolkit now detects `superpowers` + `get-shit-done` at install time and installs only unique-value files via 4 modes (`standalone`, `complement-sp`, `complement-gsd`, `complement-full`). Manifest-driven skip-lists, atomic state in `~/.claude/toolkit-install.json`, safe migration path for v3.x users, and a 13-cell release validation matrix.

**Release tag:** `v4.0.0` — manual step outside milestone (per CLAUDE.md "never push directly to main"). User runs `git tag -a v4.0.0 -m "Release 4.0.0"` + `git push --tags`.

## Next Milestone Goals

_To be defined via `/gsd-new-milestone`._

v4.1 candidate carry-overs from v4.0 deferred items: Bats-based matrix automation (TEST-01), `--clean-backups` flag (BACKUP-01), backup-count warning (BACKUP-02), `claude plugin list` integration (DETECT-FUT-01), plugin version skew (DETECT-FUT-02), INSTALL.md ↔ RELEASE-CHECKLIST.md parity auto-check.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bump to v4.0.0 (breaking) | Install behavior changes by default. Clean signal beats silent additive change. | ✓ Good — shipped 2026-04-21 |
| Auto-detect SP/GSD via filesystem only | Reliable, no CLI dependency, fast (single `[ -d ... ]` checks). `claude plugin list` may be added later as enhancement. | ✓ Good — DETECT-01..04 validated in Phase 2 |
| Auto-detect + offer migration for existing v3.x users | Don't strand users on conflicting install. Always backup, always confirm. | ✓ Good — `migrate-to-complement.sh` with three-way diff + full backup (Phase 5) |
| Keep Supreme Council inside TK | Killer feature; extracting into separate plugin adds maintenance overhead with no clear distribution win. | ✓ Good — council survives all 4 install modes |
| Document required base plugins in every template's CLAUDE.md | Sets correct expectation: "TK is built on top of SP+GSD". Reduces support questions. | ✓ Good — all 7 templates carry section, CI-enforced (Phase 6) |
| Persist install state in `~/.claude/toolkit-install.json` | Single source of truth for `update-claude.sh` to know what was installed and in which mode. Survives between runs. | ✓ Good — STATE-01..05 (Phase 2), state schema v2 with `synthesized_from_filesystem` for v3.x users (Phase 5) |
| Extend `manifest.json` per-file with `requires_base` / `conflicts_with` | Declarative skip-logic instead of hardcoded arrays in shell scripts. Easier to audit and extend. | ✓ Good — MANIFEST-01..04 (Phase 2); `make check` enforces via `agent-collision-static` |
| `setup-security.sh` switches to safe JSON merge with backup | Prevents the documented risk of clobbering SP hooks in `~/.claude/settings.json`. | ✓ Good — SAFETY-01..04 with `_tk_owned` marker append-both policy (Phase 3) |
| Phase 6 translation deferral (reversed mid-v4.0) | Originally deferred to v4.1; reversed when user inserted Phase 6.1 so v4.0 ships English + 8 translations consistent. | ✓ Good — 8/8 translations within ±20% of README.md (Phase 6.1), `make translation-drift` green |
| Release date flip manual; `git tag` manual | CLAUDE.md "never push directly to main" invariant — agent cannot cut release tags. | ✓ Good — Phase 7 ends at ready-to-tag; user tags manually (D-08) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):

1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):

1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-24 — Phase 8 (Release Quality) shipped: REL-01 bats port, REL-02 cell-parity gate, REL-03 --collect-all flag. v4.1 progress: 3/11 requirements validated (Phases 8 + 12 complete).*
