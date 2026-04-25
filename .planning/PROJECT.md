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
- ✓ `scripts/update-claude.sh --clean-backups` lists sibling `~/.claude-backup-*` + `~/.claude-backup-pre-migrate-*` dirs with size + age, per-dir `[y/N]` prompt, `--keep=N` preserves N newest by parsed epoch, `--dry-run` lists only, exit 0/1/2 — Validated in Phase 9: backup-detection (BACKUP-01)
- ✓ `scripts/lib/backup.sh` `warn_if_too_many_backups()` emitted from `update-claude.sh` + `migrate-to-complement.sh` when combined backup count > 10; non-fatal; `setup-security.sh` excluded (creates `.bak.*` inside `.claude/`, not sibling dirs) — Validated in Phase 9: backup-detection (BACKUP-02)
- ✓ `scripts/detect.sh` `detect_superpowers()` gains 4th verification layer parsing `claude plugin list --json`; CLI disabled overrides FS; CLI version wins when enabled; soft-fail to FS on CLI absent/error/non-JSON; GSD stays FS-only (not a Claude plugin) — Validated in Phase 9: backup-detection (DETECT-06)
- ✓ `scripts/lib/install.sh` `warn_version_skew()` emitted from `update-claude.sh` only (D-22 scope lock); compares `.detected.{superpowers,gsd}.version` in `~/.claude/toolkit-install.json` vs current; non-fatal one-line `⚠ Base plugin version changed` warning per changed plugin — Validated in Phase 9: backup-detection (DETECT-07)
- ✓ Three upstream GSD CLI bugs filed in `gsd-build/get-shit-done` ([#2659](https://github.com/gsd-build/get-shit-done/issues/2659) audit-open ReferenceError, [#2660](https://github.com/gsd-build/get-shit-done/issues/2660) extractOneLinerFromBody returns label, [#2661](https://github.com/gsd-build/get-shit-done/issues/2661) ROADMAP checkbox auto-sync gap) with full repro + suggested fixes; zero toolkit code changes per SC4 — Validated in Phase 10: upstream-gsd-issues (UPSTREAM-01/02/03)
- ✓ `scripts/lib/dry-run-output.sh` shared library (`dro_init_colors`/`dro_print_header`/`dro_print_file`/`dro_print_total`); chezmoi-grade `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` grouped output across `init-claude.sh`, `update-claude.sh` (added `DRY_RUN` flag exiting before backup), `migrate-to-complement.sh` (replaced 1-liner with `[- REMOVE]` group); `${NO_COLOR+x}` + `[ -t 1 ]` gates per [no-color.org](https://no-color.org) — Validated in Phase 11: ux-polish (UX-01)
- ✓ ChatGPT pass-3 audit verified against codebase (8/15 FALSE, 6/15 PARTIAL deferred to v4.2+, 1/15 REAL = uninstall script as HARDEN-C-04); Wave-A `scripts/validate-commands.py` enforces `## Purpose`/`## Usage` H2 headings on `commands/*.md` via `make validate-commands` + CI — Validated in Phase 12: audit-verification-template-hardening (HARDEN-A-01)

## Current Milestone: v4.2 (To Be Defined)

**Goal:** TBD via `/gsd-new-milestone`.

### Active

_Empty — v4.1 shipped. New requirements added when v4.2 starts._

<details>
<summary>v4.1 requirements (shipped 2026-04-25)</summary>

- ✓ REL-01..03 (Phase 8 — bats matrix, cell-parity, `--collect-all`)
- ✓ BACKUP-01..02, DETECT-06..07 (Phase 9 — `--clean-backups`, threshold warns, plugin list integration, version-skew)
- ✓ UPSTREAM-01..03 (Phase 10 — 3 issues filed in gsd-build/get-shit-done; zero toolkit code)
- ✓ UX-01 (Phase 11 — chezmoi-grade `--dry-run` across init/update/migrate)
- ✓ HARDEN-A-01 (Phase 12 — commands/ linting + ChatGPT audit verification)

</details>

<details>
<summary>v4.0 requirements (shipped 2026-04-21)</summary>

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
- **Detection**: filesystem-primary; `claude plugin list` is a secondary cross-check (DETECT-06, v4.1) — never sole source. Filesystem wins on any CLI failure.
- **Quality gate**: `make check` (markdownlint + shellcheck + validate) must pass on every PR; CI enforced via `.github/workflows/quality.yml`.
- **Versioning**: v4.0.0 is a breaking release — `manifest.json`, `CHANGELOG.md`, `init-local.sh`, and any other version reference must align.
- **Commits**: Conventional Commits, branches `feature/xxx` / `fix/xxx`, never push directly to `main`.

## Current State

**Shipped:**

- **v4.1 Polish & Upstream** (2026-04-25) — 5 phases (8–12), 13 plans, 11 REQ-IDs. Bats-based install-matrix automation, backup hygiene (`--clean-backups` + threshold warns), `claude plugin list` cross-check, version-skew warnings, chezmoi-grade `--dry-run` UX across all 3 install scripts, and three filed upstream issues for gsd-build/get-shit-done bugs that should not be patched in this repo. Tagged `v4.1.0`.
- **v4.0 Complement Mode** (2026-04-21) — 8 phases, 29 plans, 56 tasks. Detects `superpowers` + `get-shit-done` at install time and installs only unique-value files via 4 modes. Tagged `v4.0.0`.

## Next Milestone Goals

_To be defined via `/gsd-new-milestone`._

v4.2 candidate carry-overs from v4.1 audit + v4.0 lockouts:

- HARDEN-C-04 — uninstall script (only REAL finding from ChatGPT pass-3 audit)
- AUDIT-02/04/06/10/15 — Wave B/C hardening deferred from Phase 12 (compat matrix, merge strategy, version pinning, collision detection policy, provenance metadata)
- Installable GSD CLI wrapper in toolkit (crosses repo boundary — deferred from v4.1)
- Permanently locked out: Docker-per-cell isolation (conflicts with POSIX invariant), agent-cut release tags (CLAUDE.md "never push main")

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
| Release date flip manual; `git tag` manual | CLAUDE.md "never push directly to main" invariant — agent cannot cut release tags. | ✓ Good — Phase 7 ends at ready-to-tag; user tags manually (D-08). v4.1 followed same pattern, tagged `v4.1.0` 2026-04-25. |
| Upstream GSD CLI bugs filed, not patched | TK and gsd-build/get-shit-done are separate repos with separate maintainers; patching upstream code in TK creates a fork burden. Filing well-formed issues is correct boundary. | ✓ Good — 3 issues filed in Phase 10 (#2659/#2660/#2661); zero toolkit code changes per SC4 |
| Cherry-pick "Surgical Changes" from forrestchang/andrej-karpathy-skills | 83K-star plugin had 65 lines; 3/4 rules duplicated existing KISS/YAGNI/Plan Mode coverage. Cherry-pick avoids redundant skill activation while owning the unique concept. | ✓ Good — `components/surgical-changes.md` shipped; full plugin not installed |
| Shared `scripts/lib/dry-run-output.sh` over per-script duplication (UX-01) | Three scripts needed identical chezmoi-grade output. Precedent from `scripts/lib/backup.sh` (Phase 9). One contract, one place to fix bugs, all 3 install scripts source it via curl. | ✓ Good — `dro_*` API used by init/update/migrate (Phase 11) |

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
*Last updated: 2026-04-25 — v4.1 Polish & Upstream milestone complete (5/5 phases, 11/11 REQ-IDs validated). Tagged `v4.1.0`. Next: `/gsd-new-milestone` for v4.2.*
