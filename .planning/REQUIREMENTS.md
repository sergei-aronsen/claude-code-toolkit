# Requirements: claude-code-toolkit v4.0 — Complement Mode

**Defined:** 2026-04-17
**Core Value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions. Unique TK contributions always installed; everything else conditional on detected base plugins.

## v1 Requirements

Requirements for the v4.0 release. Each maps to one roadmap phase.

### Pre-work Bug Fixes

Bugs in shipped v3.x code that must be fixed before any complement-mode logic is layered on top. Multi-researcher convergence flagged each as load-bearing.

- [ ] **BUG-01**: Replace BSD-incompatible `head -n -1` in `scripts/update-claude.sh:186-195` with portable equivalent that does not silently strip trailing CLAUDE.md content on macOS
- [ ] **BUG-02**: Add `< /dev/tty` guards to every interactive `read` call in `scripts/setup-council.sh` (lines 93, 103, 134) so prompts work under `curl ... | bash`
- [ ] **BUG-03**: Replace bare API-key heredoc interpolation in `scripts/init-claude.sh:479,504,513-525` and `scripts/setup-council.sh:178-190` with `python3 json.dumps()` (or `jq --arg`) so keys containing `"` or `\` cannot break JSON
- [ ] **BUG-04**: Replace non-interactive `sudo apt-get` with `2>/dev/null` in `scripts/setup-council.sh:66` with explicit prompt + visible failure path
- [ ] **BUG-05**: `scripts/setup-security.sh` always backs up `~/.claude/settings.json` to `settings.json.bak.<unix-ts>` before any mutation
- [ ] **BUG-06**: Align version references — `manifest.json:2` (3.0.0) ↔ `scripts/init-local.sh:11` (currently 2.0.0) ↔ `CHANGELOG.md` `[Unreleased]` — all bump to 4.0.0 at end of milestone
- [ ] **BUG-07**: Add `commands/design.md` to `scripts/update-claude.sh:147` (or drive the list from `manifest.json`) so existing v3.x users get the file on update

### Plugin Detection

Filesystem-only detection of installed base plugins.

- [ ] **DETECT-01**: `scripts/detect.sh` exposes `detect_superpowers()` returning 0 if `~/.claude/plugins/cache/claude-plugins-official/superpowers/` exists with at least one versioned subdir
- [ ] **DETECT-02**: `scripts/detect.sh` exposes `detect_gsd()` returning 0 if `~/.claude/get-shit-done/` exists and contains `bin/gsd-tools.cjs`
- [ ] **DETECT-03**: Detection cross-references `~/.claude/settings.json` `enabledPlugins` (when present) to suppress stale-cache false positives
- [ ] **DETECT-04**: `detect.sh` is sourced (not executed) so callers can read exported variables `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION`
- [ ] **DETECT-05** (moved to Phase 3): Both `init-claude.sh` and `update-claude.sh` source `detect.sh` from a single canonical path; remote `curl|bash` callers download `detect.sh` to `mktemp` before sourcing. Deferred because production wiring consumes detect.sh at install-mode selection — wiring without a consumer would leave the contract unverified (D-28, Phase 2 verifier gap 2)

### Manifest Schema

Extend `manifest.json` to declare per-file conflicts. Single source of truth — no parallel skip-list arrays in shell scripts.

- [ ] **MANIFEST-01**: Each entry under `files.*` switches from bare string to object with `path`, optional `conflicts_with: ["superpowers" | "get-shit-done"]`, optional `requires_base: [...]`
- [ ] **MANIFEST-02**: Bump `manifest.version` field (separate from product version) to `2` to signal schema change; old scripts must refuse to run against v2 manifest
- [ ] **MANIFEST-03**: Each of the 7 confirmed hard duplicates (live scan against SP 5.0.7) is annotated with `conflicts_with`. The original 13-entry seed list (D-16) was fully evaluated; 7 confirmed SP equivalents, 6 TK-unique entries remain without `conflicts_with`.
- [ ] **MANIFEST-04**: `make validate` extends to verify every file path in manifest exists, every directory of files referenced has its files in manifest (no drift), and `conflicts_with` values are limited to the known plugin names

### Install Modes

Four install modes selectable at install time.

- [ ] **MODE-01**: `init-claude.sh` recognizes 4 modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`
- [ ] **MODE-02**: At install time `init-claude.sh` reads detection results and recommends the matching mode (e.g. SP+GSD detected → recommend `complement-full`)
- [ ] **MODE-03**: User can override the recommendation via interactive prompt or `--mode <name>` CLI flag
- [ ] **MODE-04**: Skip-list is computed at install time by `jq` filtering `manifest.json` entries whose `conflicts_with` overlaps with the active mode's "skip these bases" set
- [ ] **MODE-05**: `init-local.sh` respects the same mode + skip-list as `init-claude.sh` so per-project installs are consistent
- [ ] **MODE-06**: `--dry-run` flag prints per-file `[INSTALL]` / `[SKIP — conflicts with superpowers]` preview without touching the filesystem

### Install State

Persistent record of what was installed, in which mode, with content hashes for safe migration.

- [ ] **STATE-01**: `~/.claude/toolkit-install.json` schema captures `version`, `mode`, `detected: {superpowers, gsd}`, `installed_files: [{path, sha256, installed_at}]`, `skipped_files: [{path, reason}]`, `installed_at`
- [ ] **STATE-02**: Writes are atomic — `mktemp` then `mv` over the final path; never leave a half-written JSON
- [ ] **STATE-03**: Concurrent runs of `init-claude.sh` / `update-claude.sh` are blocked by an `mkdir`-based lock at `~/.claude/.toolkit-install.lock` (POSIX-atomic, no `flock` dependency)
- [ ] **STATE-04**: Each `installed_files` entry stores SHA256 of the file as written, enabling safe user-modification detection in migration
- [ ] **STATE-05**: Lock acquisition has a stale-lock recovery path (lock older than 1 hour with no live PID → reclaim with warning)

### Settings Safe Merge

`setup-security.sh` and any other script that mutates `~/.claude/settings.json` must be additive and reversible.

- [ ] **SAFETY-01**: `setup-security.sh` reads existing `~/.claude/settings.json` via `python3 json.load`, merges only the keys it owns, and writes back via `json.dump` to a temp file followed by atomic `mv`
- [ ] **SAFETY-02**: `setup-security.sh` never overwrites `hooks` from other plugins — merges per-key, preserving entries it did not create
- [ ] **SAFETY-03**: Backup with timestamp before every mutation (`settings.json.bak.<unix-ts>`); on failure, restore from backup before exiting non-zero
- [ ] **SAFETY-04**: Documented invariant: TK never edits keys outside its own `permissions.deny`, its own `hooks.PreToolUse[*]` entries, and its own env block

### Update Flow

`update-claude.sh` re-evaluates state on every run and surfaces drift.

- [ ] **UPDATE-01**: `update-claude.sh` reads `toolkit-install.json` and re-runs detection; if the detected base set changed since install, prompts user to re-evaluate mode
- [ ] **UPDATE-02**: Installed-file list is iterated from `manifest.json` filtered by the active mode (no hand-maintained list — fixes BUG-07 structurally)
- [ ] **UPDATE-03**: Files newly added to `manifest.json` since the last install are detected and offered to the user (with mode-aware skip)
- [ ] **UPDATE-04**: Files removed from `manifest.json` since the last install are detected and offered for deletion (with backup, with confirmation)
- [ ] **UPDATE-05**: Backup directories use timestamp + PID suffix (`~/.claude-backup-<unix-ts>-<pid>/`) so two updates in the same second do not collide
- [ ] **UPDATE-06**: Post-update summary shows `INSTALLED N`, `UPDATED M`, `SKIPPED P (reason)`, `REMOVED Q (backed up to <path>)`

### Migration

Standalone migration script for existing v3.x users discovered to have SP/GSD installed.

- [ ] **MIGRATE-01**: `scripts/migrate-to-complement.sh` is a separate file (not a flag on `update-claude.sh`) — destructive + one-time, isolated from routine update path
- [ ] **MIGRATE-02**: Migration enumerates v3.x duplicates (per `manifest.json` `conflicts_with`) and shows three-way diff per file: TK template hash vs current file hash vs SP/GSD equivalent (when readable)
- [ ] **MIGRATE-03**: Per-file `[y/N]` confirmation before any removal; user-modified files (current hash ≠ install-time hash from `STATE-04`) get an extra warning
- [ ] **MIGRATE-04**: Backup the entire current install to `~/.claude-backup-pre-migrate-<unix-ts>/` before any removal; print path on screen
- [ ] **MIGRATE-05**: After migration, rewrite `toolkit-install.json` to reflect the new `complement-*` mode and updated `installed_files` list
- [ ] **MIGRATE-06**: Migration script idempotent — running it twice on an already-migrated install reports "nothing to do" and exits 0

### Documentation

User-facing positioning and per-template plugin docs.

- [ ] **DOCS-01**: `README.md` repositions toolkit as "complement to `superpowers` + `get-shit-done`"; install section shows both modes (standalone vs complement) with one-paragraph guidance per mode
- [ ] **DOCS-02**: Each `templates/*/CLAUDE.md` (7 stacks) gains a `## Required Base Plugins` section listing `superpowers` and `get-shit-done` with install instructions
- [ ] **DOCS-03**: `CHANGELOG.md` `[4.0.0]` entry documents BREAKING CHANGES (default mode behavior changed; duplicates removed in complement modes; manifest schema bumped)
- [ ] **DOCS-04**: `docs/INSTALL.md` (or section in README) documents the install matrix (4 modes × {fresh, upgrade, re-run}) with what each cell does
- [ ] **DOCS-05**: New `components/optional-plugins.md` documents `rtk` (rtk-ai/rtk) and `caveman` (JuliusBrussee/caveman) as recommended optional plugins, with caveats verified against upstream on 2026-04-18: `rtk` `ls` command is broken on non-English locales — user-side workaround is `exclude_commands = ["ls"]` in `~/Library/Application Support/rtk/config.toml` (upstream issue rtk-ai/rtk#1276 OPEN; upstream's intended fix is internal `LC_ALL=C`, not the exclusion workaround — document the distinction honestly); `caveman` ships **en + wenyan** (Classical Chinese) language modes — not en + ru — and `caveman-compress` **auto-backs up** CLAUDE.md to `CLAUDE.original.md` (no manual backup required; document the auto-backup invariant but warn users the backup is single-generation and is overwritten on re-compress)
- [x] **DOCS-06**: `init-claude.sh` and `update-claude.sh` print a "recommended optional plugins" block at end of install (non-interactive — informational only, no auto-install) listing `rtk`, `caveman`, `superpowers`, `get-shit-done` with one-line install commands and the documented caveats
- [ ] **DOCS-07**: `~/.claude/RTK.md` template (shipped by TK to user's `~/.claude/`) gains a "Known Issues" section that documents the `ls` exclusion config and points to upstream issue rtk-ai/rtk#1276
- [x] **DOCS-08**: `components/orchestration-pattern.md` (drafted from vault notes — already in repo) is reviewed, polished, added to `manifest.json` under `components`, and cross-referenced from `components/supreme-council.md` and `components/structured-workflow.md`; README "Components" section gets a short blurb pointing to it

### Translations

README translation sync for v4.0 complement-first positioning.

- [x] **TRANS-01**: All 8 README translations (`docs/readme/{de,es,fr,ja,ko,pt,ru,zh}.md`) are within ±20% of `README.md`'s line count: each file has between 161 and 242 lines (inclusive), where the bounds derive from `floor(202 × 0.8) = 161` and `floor(202 × 1.2) = 242`.
- [x] **TRANS-02**: `make translation-drift` exits 0 when run from the repository root after all 8 translation files have been written. This is the mechanical gate that unblocks Phase 7 Plan 07-04 (`make check` dependency chain).
- [x] **TRANS-03**: Each of the 8 translations contains an equivalent of the English `## Install Modes` section with three subheadings equivalent to "Standalone install", "Complement install", and "Upgrading from v3.x" in its target language. The section conveys the complement-first positioning ("TK is a complement to `superpowers` + `get-shit-done`") at least once in localized prose. All install commands within the section are verbatim-identical to those in `README.md`.
- [x] **TRANS-04**: `make mdlint` exits 0 when run from the repository root after all 8 translation files have been written, with zero regressions versus the pre-phase baseline.

### Validation

Smoke testing the install matrix manually before release.

- [ ] **VALIDATE-01**: Manual smoke-test checklist covers all 12 cells (4 modes × {fresh install, upgrade from v3.x, re-run idempotence}); checklist lives in `docs/RELEASE-CHECKLIST.md`
- [ ] **VALIDATE-02**: Each smoke-test cell verifies: state file created/updated correctly, no unexpected files installed/skipped, no `~/.claude/settings.json` keys lost, exit code 0
- [ ] **VALIDATE-03**: Validation includes confirming SP `code-reviewer` agent and TK do not collide on the same agent name in any complement mode
- [ ] **VALIDATE-04**: Final pre-release: `make check` passes, `manifest.json` schema validation passes, version references aligned

## v2 Requirements

Deferred to a future release.

### Backup Hygiene

- **BACKUP-01**: `--clean-backups` flag on `update-claude.sh` removes backup dirs older than N days (default 30)
- **BACKUP-02**: `update-claude.sh` warns when backup count exceeds threshold (default 10)

### Detection Enhancements

- **DETECT-FUT-01**: Optional `claude plugin list` integration as a secondary detection signal (filesystem stays primary)
- **DETECT-FUT-02**: Detect plugin version skew — if installed SP/GSD version is incompatibly old, warn and suggest update

### Test Automation

- **TEST-01**: Replace manual install matrix smoke tests with `bats` (Bash Automated Testing System) suite in CI

### Orchestration Pattern (v4.1 milestone candidate)

GSD ships a "load-init-context" pattern: every workflow starts with `node $HOME/.claude/get-shit-done/bin/gsd-tools.cjs init <workflow>` returning a JSON config (`executor_model`, `verifier_model`, paths, flags) that drives subsequent subagent spawning. This is a powerful declarative-orchestration pattern that TK could adopt for its own multi-step workflows (Council debate, install matrix testing, audit pipelines).

- **ORCH-FUT-01**: ~~Document the orchestration pattern~~ — completed early as DOCS-08 in v4.0 (`components/orchestration-pattern.md` drafted from vault notes 2026-04-14..16); v4.1 follow-up only needs cross-linking once consumers exist
- **ORCH-FUT-02**: Ship `scripts/tk-tools.sh` with `init <workflow>` subcommand returning JSON config (`{model_profile, paths, flags, prerequisites}`) for TK-native workflows. Schema mirrors `gsd-tools.cjs init` (researcher_model, planner_model, etc.) so the pattern is portable
- **ORCH-FUT-03**: Refactor `commands/council.md` + `scripts/council/brain.py` to consume `tk-tools.sh init council` for model selection, round count, per-round prompt templates. Behavior unchanged for the user; config moves from Python constants into `~/.claude/council/config.json`
- **ORCH-FUT-04**: Add `scripts/tk-tools.sh agent-skills <agent>` returning the agent contract markdown (mirrors `gsd-tools.cjs agent-skills`) so future TK skills can compose subagent prompts the same way GSD workflows do
- **ORCH-FUT-05**: Worktree-isolation helper in `scripts/tk-tools.sh worktree {create|merge|cleanup} <branch>` for any future TK workflow that spawns subagents modifying shared files (vault pattern: `2026-04-15-git-worktree-isolation-for-subagent-execution-with-merge-back-to-main.md`)
- **ORCH-FUT-06**: Document migration path from hardcoded `brain.py` config to init-JSON-driven config in `CHANGELOG.md` v4.1 entry, with backwards-compat shim that reads the old constants if `config.json` is missing

## Out of Scope

Explicitly excluded from v4.0. Documented to prevent re-litigation.

| Feature | Reason |
|---------|--------|
| Re-implementing SP / GSD features in TK | Duplicates source-of-truth, hard to keep in sync, defeats the milestone |
| Auto-installing SP / GSD on user's behalf | User controls their plugin set; TK only suggests |
| Migrating users without explicit consent | Every filesystem mutation requires `[y/N]` and backup |
| Detection via `claude plugin list` (CLI) as primary path | Filesystem detection is more reliable, CLI-independent, faster |
| Splitting Council into a separate plugin | Killer feature; splitting adds maintenance overhead with no win |
| Backwards-compat shims to keep deprecated TK commands working | Clean break, Conventional Commits with `BREAKING CHANGE:` footer |
| `flock`-based locking | Linux-only; `mkdir` lock is POSIX-portable |
| `jq` for `~/.claude/settings.json` writes | `jq` hard-fails on JSON5-adjacent content; `python3 json` is more permissive |
| Auto-cleanup of old `.claude-backup-*` dirs | v4.1 concern; v4.0 backup count is bounded by user usage frequency |
| Per-file `--dry-run` rendering as a styled diff (chezmoi-grade) | v4.0 ships plain `[INSTALL] / [SKIP]` lines; styled diff is v4.1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | Phase 1 | Pending |
| BUG-02 | Phase 1 | Pending |
| BUG-03 | Phase 1 | Pending |
| BUG-04 | Phase 1 | Pending |
| BUG-05 | Phase 1 | Pending |
| BUG-06 | Phase 1 | Pending |
| BUG-07 | Phase 1 | Pending |
| DETECT-01 | Phase 2 | Pending |
| DETECT-02 | Phase 2 | Pending |
| DETECT-03 | Phase 2 | Pending |
| DETECT-04 | Phase 2 | Pending |
| DETECT-05 | Phase 3 | Pending (moved from Phase 2 — production wiring consumes detect.sh at install-mode selection) |
| MANIFEST-01 | Phase 2 | Pending |
| MANIFEST-02 | Phase 2 | Pending |
| MANIFEST-03 | Phase 2 | Pending |
| MANIFEST-04 | Phase 2 | Pending |
| STATE-01 | Phase 2 | Pending |
| STATE-02 | Phase 2 | Pending |
| STATE-03 | Phase 2 | Pending |
| STATE-04 | Phase 2 | Pending |
| STATE-05 | Phase 2 | Pending |
| MODE-01 | Phase 3 | Pending |
| MODE-02 | Phase 3 | Pending |
| MODE-03 | Phase 3 | Pending |
| MODE-04 | Phase 3 | Pending |
| MODE-05 | Phase 3 | Pending |
| MODE-06 | Phase 3 | Pending |
| SAFETY-01 | Phase 3 | Pending |
| SAFETY-02 | Phase 3 | Pending |
| SAFETY-03 | Phase 3 | Pending |
| SAFETY-04 | Phase 3 | Pending |
| UPDATE-01 | Phase 4 | Pending |
| UPDATE-02 | Phase 4 | Pending |
| UPDATE-03 | Phase 4 | Pending |
| UPDATE-04 | Phase 4 | Pending |
| UPDATE-05 | Phase 4 | Pending |
| UPDATE-06 | Phase 4 | Pending |
| MIGRATE-01 | Phase 5 | Pending |
| MIGRATE-02 | Phase 5 | Pending |
| MIGRATE-03 | Phase 5 | Pending |
| MIGRATE-04 | Phase 5 | Pending |
| MIGRATE-05 | Phase 5 | Pending |
| MIGRATE-06 | Phase 5 | Pending |
| DOCS-01 | Phase 6 | Pending |
| DOCS-02 | Phase 6 | Pending |
| DOCS-03 | Phase 6 | Pending |
| DOCS-04 | Phase 6 | Pending |
| DOCS-05 | Phase 6 | Pending |
| DOCS-06 | Phase 6 | Complete |
| DOCS-07 | Phase 6 | Pending |
| DOCS-08 | Phase 6 | Pending (component drafted, polish + manifest wiring left) |
| TRANS-01 | Phase 06.1 | Complete |
| TRANS-02 | Phase 06.1 | Complete |
| TRANS-03 | Phase 06.1 | Complete |
| TRANS-04 | Phase 06.1 | Complete |
| VALIDATE-01 | Phase 7 | Pending |
| VALIDATE-02 | Phase 7 | Pending |
| VALIDATE-03 | Phase 7 | Pending |
| VALIDATE-04 | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 59 total
- Mapped to phases: 59
- Unmapped: 0

---

*Requirements defined: 2026-04-17*
*Last updated: 2026-04-17 — added DOCS-05/06/07/08 (rtk + caveman + orchestration-pattern), refined ORCH-FUT-* v2 backlog with vault references*
