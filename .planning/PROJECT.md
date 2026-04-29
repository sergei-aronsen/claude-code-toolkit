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
- ✓ `scripts/uninstall.sh` reads `~/.claude/toolkit-install.json`, classifies every entry via SHA256 (`is_protected_path` → `MISSING` → SHA compare), removes only hash-match files; superpowers + get-shit-done trees never deleted; defense-in-depth `is_protected_path` re-check at delete time uses absolute paths — Validated in Phase 18: core-uninstall-script-dry-run-backup (UN-01)
- ✓ `scripts/uninstall.sh --dry-run` prints chezmoi-grade 4-group preview (`[- REMOVE]` / `[? MODIFIED]` / `[? MISSING]` / total) using existing `dro_*` primitives, exits 0 with zero filesystem mutations; hermetic test (8 assertions) enforces zero-mutation contract — Validated in Phase 18 (UN-02)
- ✓ Per-MODIFIED-file `[y/N/d]` prompt via `< /dev/tty` with re-entrant `d`-branch diff loop, fail-closed `N` default if `/dev/tty` unavailable, works under `bash <(curl -sSL ...)` — Validated in Phase 18 (UN-03)
- ✓ Backup-before-delete to `~/.claude-backup-pre-uninstall-<unix-ts>/` via `cp -R` with `toolkit-install.json` snapshot inside backup; `lib/backup.sh` `list_backup_dirs`/`warn_if_too_many_backups` extended for new pattern (enables `--clean-backups` pruning) — Validated in Phase 18 (UN-04)
- ✓ `strip_sentinel_block()` awk helper strips `<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->` blocks from `~/.claude/CLAUDE.md` with leading/trailing blank-line trimming; unmatched markers → log_warning + leave-untouched (D-02 no partial-strip); empty file after strip → leave on disk (D-03 least-destruction); base-plugin invariant `diff -q` on sorted `find` output of superpowers + get-shit-done trees fails loudly with `exit 1` + state preserved on mutation (D-10); `~/.claude/toolkit-install.json` deleted as the LAST mutating step (D-06) — Validated in Phase 19: state-cleanup-idempotency (UN-05)
- ✓ `[[ ! -f "$STATE_FILE" ]]` guard at line 389 fires before lock acquisition / backup / snapshot — second invocation prints exact locked log line `✓ Toolkit not installed; nothing to do.` and exits 0 with zero filesystem mutations (no `.claude-backup-pre-uninstall-*` dir on no-op runs) — Validated in Phase 19 (UN-06)
- ✓ `manifest.json` `4.3.0` registers `scripts/uninstall.sh` under new `files.scripts[]` array; `init-local.sh --version` derives from manifest at runtime so version-align gate stays a 2-file (manifest + CHANGELOG) atomic bump; identical `To remove: bash <(curl -sSL .../scripts/uninstall.sh)` line in all 3 installers (`init-claude.sh`, `init-local.sh`, `update-claude.sh` with `NO_BANNER=1` guard); `CHANGELOG.md [4.3.0]` Added section covers UN-01..UN-08 — Validated in Phase 20: distribution-tests (UN-07)
- ✓ `scripts/tests/test-uninstall.sh` round-trip integration test (5 scenarios S1-S5, 18 assertions) exercises real `init-local.sh` → uninstall.sh contract: clean → uninstall → `find .claude -type f == 0`, modified-file `y/N/d` branches via `TK_UNINSTALL_TTY_FROM_STDIN=1`, base-plugin SHA256 invariant, `--dry-run` zero-mutation, double-uninstall no-op; `scripts/tests/test-install-banner.sh` source-grep gate (3 assertions); Makefile Tests 24-27 + `.github/workflows/quality.yml` `validate-templates` job mirrors all 7 uninstall-suite tests (67 assertions) in CI — Validated in Phase 20 (UN-08)
- ✓ Rule-1 install/uninstall contract gap fix: `scripts/init-local.sh` `INSTALLED_PATHS[]` now tracks 6 previously-untracked groups (cheatsheets×9, lessons-learned, audit-exceptions, scratchpad/current-task.md, CLAUDE.md, settings.json) — surfaced by Phase 20 S1 round-trip; closes silent gap where files were installed but not registered in `toolkit-install.json` — Validated in Phase 20
- ✓ `scripts/lib/bootstrap.sh` `bootstrap_base_plugins()` runs in `init-claude.sh` + `init-local.sh` BEFORE `detect.sh` — two-prompt SP/GSD pre-install flow; reads `< /dev/tty` (override `TK_BOOTSTRAP_TTY_SRC`) with fail-closed `N` on EOF/no-tty; canonical `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` constants in `optional-plugins.sh:18-19` (single source of truth per D-12); idempotency probes suppress prompts if `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or `~/.claude/get-shit-done/` already exist (D-08); non-fatal `eval` captures rc and warns instead of aborting (D-10); `TK_NO_BOOTSTRAP=1` byte-quiet opt-out (D-17); `--no-bootstrap` CLI flag in both installers + `--help` listing; post-bootstrap `detect.sh` re-source so `HAS_SP`/`HAS_GSD` reflect new state (BOOTSTRAP-03); `scripts/tests/test-bootstrap.sh` 5-scenario hermetic test (26 assertions) wired into Makefile Test 28 + CI `quality.yml` `Tests 21-28` step; `docs/INSTALL.md` `## Installer Flags` section documents `--no-bootstrap` + `TK_NO_BOOTSTRAP` — Validated in Phase 21: sp-gsd-bootstrap-installer (BOOTSTRAP-01..04)
- ✓ `manifest.json` `4.4.0` registers all six `scripts/lib/*.sh` helpers (`backup`, `bootstrap`, `dry-run-output`, `install`, `optional-plugins`, `state`) under new top-level `files.libs[]` array — `update-claude.sh` auto-discovers them via existing `.files | to_entries[] | .value[] | .path` jq path with ZERO code changes (D-07); `scripts/tests/test-update-libs.sh` hermetic 5-scenario regression test (15 assertions, idempotent) covers stale-refresh / clean-untouched / fresh-install / modified-file-fail-closed / uninstall round-trip via `TK_UPDATE_HOME`/`TK_UPDATE_FILE_SRC`/`TK_UPDATE_MANIFEST_OVERRIDE`/`TK_UPDATE_LIB_DIR`/`TK_UNINSTALL_HOME` seams; wired into Makefile Test 29 (+ standalone `test-update-libs` target) + CI `quality.yml` `Tests 21-29` step; `CHANGELOG.md [4.4.0]` consolidates Phase 21 + Phase 22 in single release entry — Validated in Phase 22: smart-update-coverage-for-scripts-lib-sh (LIB-01, LIB-02)
- ✓ `scripts/init-claude.sh` + `scripts/init-local.sh` learn `--no-banner` flag and `NO_BANNER=1` env-var (env-form `NO_BANNER=${NO_BANNER:-0}` so caller env is honoured) — byte-symmetric with `update-claude.sh`'s existing flag (also fixed to env-form for true symmetry per WR-01 in Phase 23 REVIEW); `if [[ $NO_BANNER -eq 0 ]]` gate around closing `To remove: bash <(curl …)` echo (D-04); `scripts/tests/test-install-banner.sh` extended 3→7 source-grep assertions (A4-A7 cover env-form default + clause + gate in both init scripts); D-02 banner-string byte-identicality preserved across all 3 installers (`grep -cF` count = 1) — Validated in Phase 23: installer-symmetry-recovery (BANNER-01)
- ✓ `scripts/uninstall.sh` learns `--keep-state` (and `TK_UNINSTALL_KEEP_STATE=1` env var) gating the existing `rm -f "$STATE_FILE"` block at the UN-05 D-06 LAST-step position (no reorder of backup/snapshot/sentinel-strip/diff-q invariants); `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` at top with CLI > env > default precedence (Phase 21 D-16 mirror); replaces `rm -f` with `log_info "State file preserved (--keep-state): $STATE_FILE"` on `--keep-state` branch; `--help` block + `docs/INSTALL.md` Installer Flags row document the surface; `scripts/tests/test-uninstall-keep-state.sh` (260 lines, S1+S2+S3 hermetic scenarios, 11 assertions) proves the four KEEP-02 contract assertions A1-A4 (state file present post-`--keep-state`-N-run, second invocation not a no-op, MODIFIED list non-empty, base-plugin diff-q invariant holds) plus full-y branch + env-only path; wired into Makefile Test 30 + CI `quality.yml` step renamed `Tests 21-29` → `Tests 21-30`; `CHANGELOG.md [4.4.0]` Added gains 3 bullets (BANNER-01 + KEEP-01 + KEEP-02), consolidated v4.4 entry preserved (D-18) — Validated in Phase 23 (KEEP-01, KEEP-02)

<details>
<summary>v4.3 requirements (shipped 2026-04-26)</summary>

- ✓ UN-01..UN-04 (Phase 18 — uninstall.sh foundation: argparse, state load, SHA256 classify, base-plugin guard, dry-run preview, backup-before-delete, [y/N/d] modified prompt)
- ✓ UN-05..UN-06 (Phase 19 — state cleanup: strip_sentinel_block, base-plugin diff -q invariant, state-file delete LAST, idempotency guard with locked log line)
- ✓ UN-07..UN-08 (Phase 20 — distribution: manifest.json files.scripts + 4.3.0 bump, "To remove" banner in 3 installers, CHANGELOG [4.3.0], round-trip test 18 assertions, banner gate, CI mirror in quality.yml)

</details>

<details>
<summary>v4.2 requirements (shipped 2026-04-26)</summary>

- ✓ EXC-01..05 (Phase 13 — FP allowlist + `/audit-skip` + `/audit-restore` + installer wiring)
- ✓ AUDIT-01..05 (Phase 14 — allowlist parser, 6-step FP recheck, structured `.claude/audits/<type>-<HHMM>.md` reports with ±10 lines verbatim code)
- ✓ COUNCIL-01..06 (Phase 15 — mandatory `/council audit-review`, severity reclass forbidden, REAL/FALSE_POSITIVE verdicts, missed findings, FP nudge UX, parallel Gemini+ChatGPT with `disputed` flagging)
- ✓ TEMPLATE-01..03 (Phase 16 — 49 prompt files spliced with 4 contract blocks, RU/EN preserved, CI gate asserts markers)
- ✓ DIST-01..03 (Phase 17 — manifest 4.2.0, `audit-review.md` installer, CHANGELOG `[4.2.0]`)

</details>

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

- **v4.5 Install Flow UX & Desktop Reach** (2026-04-29) — 4 phases (24–27), 17 plans, 42 tasks, 36 REQ-IDs (TUI-01..07, DET-01..05, DISPATCH-01..03, BACKCOMPAT-01, MCP-01..05, MCP-SEC-01/02, SKILL-01..05, MKT-01..04, DESK-01..04). Single guided TUI installer (`scripts/install.sh`) replaces 5 separate curl-bash invocations: `scripts/lib/{tui,detect2,dispatch}.sh` foundation + 6-component selector. Phase 25 ships 9-MCP curated TUI (`scripts/lib/mcp-catalog.json` + `mcp.sh`) with hidden-input wizard and `~/.claude/mcp-config.env` (mode 0600). Phase 26 mirrors 22 curated skills under `templates/skills-marketplace/<name>/` installable via `cp -R` to `~/.claude/skills/`. Phase 27 publishes plugin marketplace (`.claude-plugin/marketplace.json` + 3 sub-plugins `tk-skills`/`tk-commands`/`tk-framework-rules` via relative symlinks) + `docs/CLAUDE_DESKTOP.md` capability matrix + auto-routing to `--skills-only` when `claude` CLI absent. 5 hermetic test suites (PASS=104+: test-install-tui 43, test-mcp-selector 21, test-install-skills 15, test-update-libs 15, test-bootstrap 26 unchanged). Manifest 4.4.0 → 4.5.0 with new `files.skills_marketplace[]` (22 entries). 8 HUMAN-UAT items deferred (live PTY + external CLI) and 5 advisory code-review WRs. Tagged `v4.5.0`.
- **v4.4 Bootstrap & Polish** (2026-04-27) — 3 phases (21–23), 8 plans, 19 tasks, 9 REQ-IDs (BOOTSTRAP-01..04, LIB-01/02, BANNER-01, KEEP-01/02). `scripts/lib/bootstrap.sh` invokes canonical SP/GSD installers (`claude plugin install superpowers@claude-plugins-official`, `bash <(curl -sSL .../get-shit-done/.../install.sh)`) before `detect.sh` and re-runs detection after; `< /dev/tty` with fail-closed `N`; `--no-bootstrap` + `TK_NO_BOOTSTRAP=1` opt-out. `manifest.json` gained `files.libs[]` covering `scripts/lib/{backup,bootstrap,dry-run-output,install,optional-plugins,state}.sh` so `update-claude.sh` refreshes them via existing jq path. `init-claude.sh` + `init-local.sh` learned `--no-banner` (env-form `NO_BANNER=${NO_BANNER:-0}` for byte-symmetry). `scripts/uninstall.sh --keep-state` (and `TK_UNINSTALL_KEEP_STATE=1`) preserves `~/.claude/toolkit-install.json` for partial-uninstall recovery. 30 Makefile tests + CI Tests 21-30. Tagged `v4.4.0`.
- **v4.3 Uninstall** (2026-04-26) — 3 phases (18–20), 10 plans, 12 tasks, 8 REQ-IDs (UN-01..UN-08). `scripts/uninstall.sh` reads `~/.claude/toolkit-install.json`, classifies via SHA256, prompts `[y/N/d]` for modified files, backs up to `~/.claude-backup-pre-uninstall-<ts>/`, strips toolkit sentinel block from `~/.claude/CLAUDE.md`, verifies base-plugin invariant via `diff -q`, deletes state file LAST, idempotent on second invocation. 7 hermetic test files (67 assertions: dry-run + backup + prompt + idempotency + state-cleanup + round-trip + banner-gate). Manifest 4.3.0 registers `files.scripts[]`; identical `To remove` banner in all 3 installers; CI mirror in `quality.yml`. Tagged `v4.3.0`.
- **v4.2 Audit System v2** (2026-04-26) — 5 phases (13–17), 22 plans, 22 REQ-IDs. Persistent FP allowlist (`.claude/rules/audit-exceptions.md` + `/audit-skip` + `/audit-restore`), `/audit` rewritten to a 6-phase pipeline with 6-step FP recheck and structured reports at `.claude/audits/<type>-<HHMM>.md` (±10 lines verbatim code per finding), mandatory `/council audit-review` pass with per-finding REAL/FALSE_POSITIVE verdicts (severity reclassification forbidden), and 49 prompt files spliced across 7 frameworks. Tagged `v4.2.0`.
- **v4.1 Polish & Upstream** (2026-04-25) — 5 phases (8–12), 13 plans, 11 REQ-IDs. Bats-based install-matrix automation, backup hygiene (`--clean-backups` + threshold warns), `claude plugin list` cross-check, version-skew warnings, chezmoi-grade `--dry-run` UX across all 3 install scripts, and three filed upstream issues for gsd-build/get-shit-done bugs that should not be patched in this repo. Tagged `v4.1.0` (patch `v4.1.1` 2026-04-25).
- **v4.0 Complement Mode** (2026-04-21) — 8 phases, 29 plans, 56 tasks. Detects `superpowers` + `get-shit-done` at install time and installs only unique-value files via 4 modes. Tagged `v4.0.0`.

## Next Milestone Goals (v4.6 — TBD)

v4.5 milestone archive: `.planning/milestones/v4.5-{ROADMAP,REQUIREMENTS}.md`. Audit: `.planning/v4.5-MILESTONE-AUDIT.md` (passed, 36/36 REQ-IDs).

**Pending HUMAN-UAT from v4.5** (run when convenient — not blocking ship):

- Phase 24: live PTY interactive TUI render + Ctrl-C terminal restore
- Phase 25: live PTY MCP wizard with real `claude` CLI detection + hidden-input visual confirmation
- Phase 26: live PTY interactive 22-row Skills TUI render
- Phase 27: live `claude plugin marketplace add ./` smoke + Claude Desktop end-to-end install

**Optional follow-ups:**

- `/gsd-code-review-fix 24` to address 4 advisory WR findings in `tui.sh` + 1 in `dispatch.sh` (low real-world risk).
- Submit toolkit to upstream Anthropic marketplace registry (MKT-04 follow-up; manual).

**Carry-overs from previous milestones (still deferred):**

- `--no-council` flag for `/audit` — keep deferred (mandatory pass guarantees FP discipline; revisit if friction surfaces)
- Sentinel writer instrumentation in `setup-security.sh` / `init-claude.sh` (Phase 19 D-01 — reader side already shipped in v4.3)
- Selective uninstall (`--only commands/`, `--except council/`) — combinatorial test surface, only revisit on real demand
- Permanently locked out: Docker-per-cell isolation (conflicts with POSIX invariant), agent-cut release tags (CLAUDE.md "never push main")

v4.6 scope to be defined via `/gsd-new-milestone` when ready.

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
| Council `audit-review` MUST NOT reclassify severity (COUNCIL-02) | Auditor owns severity; Council confirms REAL/FALSE_POSITIVE only. Splitting the two responsibilities prevents Council drift and keeps a single source of truth for severity. | ✓ Good — locked in prompt + Test 19 verdict-table contract (v4.2 Phase 15) |
| No `--no-council` flag in v4.2 | If Council pass is optional, users skip it under deadline pressure and the trust guarantee evaporates. Mandatory pass forces the FP discipline; revisit only if Council friction surfaces. | ✓ Good — flag absent from `commands/audit.md` 6-phase contract (v4.2 Phase 14/15) |
| Verbatim ±10 lines code block per finding (AUDIT-03) | Council reasons from code, not labels. Embedding code makes the report self-contained and lets disputed verdicts be re-checked offline without re-reading the repo. | ✓ Good — schema enforced by Test 17 + 49 propagated prompts (v4.2 Phase 14/16) |
| Splice 4 contract blocks into all 49 prompts via one atomic commit (Phase 16) | RU/EN partitions + 7 frameworks × 7 prompt types = high drift surface. Doing it in one commit keeps `make validate` deterministic and makes the contract change auditable as a single changeset. | ✓ Good — commit `33be0b1` shipped clean; CI gate Test 20 + `validate-templates` job locks markers |

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
*Last updated: 2026-04-29 — **v4.5 Install Flow UX & Desktop Reach** shipped via `/gsd-complete-milestone v4.5`. 4 phases (24–27), 17 plans, 42 tasks, 36/36 REQ-IDs, 28/28 cross-phase connections wired, 5 of 6 E2E flows verified (1 platform-boundary deferred). 8 HUMAN-UAT items + 5 advisory WRs deferred — not blocking ship. v4.5 archived at `.planning/milestones/v4.5-{ROADMAP,REQUIREMENTS}.md`. Tagged `v4.5.0`.*
