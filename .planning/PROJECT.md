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

### Active

<!-- v4.0 milestone: Toolkit complement mode. Hypotheses until shipped. -->

- [ ] Detect installed `superpowers` (filesystem path: `~/.claude/plugins/cache/claude-plugins-official/superpowers/`)
- [ ] Detect installed `get-shit-done` (filesystem path: `~/.claude/get-shit-done/`)
- [ ] Define 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`
- [ ] Auto-recommend mode based on detection; user can override
- [ ] Skip-list per mode: which TK files NOT to install when each base is present
- [ ] Persist install state to `~/.claude/toolkit-install.json` (mode, detected versions, installed files, skipped files, timestamp)
- [ ] Extend `manifest.json` per-file with `requires_base: ["superpowers" | "get-shit-done" | null]` and `conflicts_with: [...]`
- [ ] `setup-security.sh` safely merges into `~/.claude/settings.json` (backup + JSON merge, never overwrite SP hooks)
- [ ] Migration path for existing v3.x users: `update-toolkit` detects SP/GSD post-fact and offers to remove duplicates with backup
- [ ] Each `templates/*/CLAUDE.md` documents required base plugins and how this toolkit layers on top
- [ ] README repositions toolkit as "plays nicely with `superpowers` + `get-shit-done`"
- [ ] Verify install/update flows in all 4 modes (smoke test or manual matrix)
- [ ] Bump version to `4.0.0` and document breaking changes in `CHANGELOG.md`

### Out of Scope

- Re-implementing `superpowers` or `get-shit-done` features in TK — duplicates the source-of-truth, hard to keep in sync
- Auto-installing SP/GSD on user's behalf — user controls their plugin set; we only suggest
- Migrating users without consent — every change to user filesystem requires explicit `[y/N]` prompt and backup
- Detection via `claude plugin list` (CLI) as primary path — filesystem detection is more reliable and CLI-independent (CLI may be used as a future enhancement, not v4.0)
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

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bump to v4.0.0 (breaking) | Install behavior changes by default. Clean signal beats silent additive change. | — Pending |
| Auto-detect SP/GSD via filesystem only | Reliable, no CLI dependency, fast (single `[ -d ... ]` checks). `claude plugin list` may be added later as enhancement. | — Pending |
| Auto-detect + offer migration for existing v3.x users | Don't strand users on conflicting install. Always backup, always confirm. | — Pending |
| Keep Supreme Council inside TK | Killer feature; extracting into separate plugin adds maintenance overhead with no clear distribution win. | — Pending |
| Document required base plugins in every template's CLAUDE.md | Sets correct expectation: "TK is built on top of SP+GSD". Reduces support questions. | — Pending |
| Persist install state in `~/.claude/toolkit-install.json` | Single source of truth for `update-claude.sh` to know what was installed and in which mode. Survives between runs. | — Pending |
| Extend `manifest.json` per-file with `requires_base` / `conflicts_with` | Declarative skip-logic instead of hardcoded arrays in shell scripts. Easier to audit and extend. | — Pending |
| `setup-security.sh` switches to safe JSON merge with backup | Prevents the documented risk of clobbering SP hooks in `~/.claude/settings.json`. | — Pending |

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
*Last updated: 2026-04-18 — Phase 4 (update-flow) complete. UPDATE-01..06 satisfied. 2 human-tty verification items pending in 04-HUMAN-UAT.md.*
