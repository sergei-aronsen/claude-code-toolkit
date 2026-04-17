# Roadmap: claude-code-toolkit v4.0 — Complement Mode

## Overview

v4.0 transforms the toolkit from a standalone installer into a complement that plays nicely with
`superpowers` and `get-shit-done`. The journey runs in seven phases: first fix the bugs that would
corrupt any new logic built on top of them, then build the detection + manifest + state foundation,
then refactor the install and update flows to be mode-aware, then ship the migration path for existing
v3.x users, then document the new behavior, and finally validate the full install matrix before
bumping to 4.0.0.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Pre-work Bug Fixes** - Fix the v3.x bugs that would corrupt any complement-mode logic built on top of them
- [ ] **Phase 2: Foundation** - Ship detect.sh, extend manifest schema, and establish install state with atomic writes and locking
- [ ] **Phase 3: Install Flow** - Refactor init-claude.sh + init-local.sh for 4-mode installs, dry-run, and safe settings merge
- [ ] **Phase 4: Update Flow** - Refactor update-claude.sh to re-evaluate state, surface drift, and apply mode-aware skip-lists
- [ ] **Phase 5: Migration** - Ship migrate-to-complement.sh for existing v3.x users with three-way diff and per-file confirmation
- [ ] **Phase 6: Documentation** - Reposition README, update all 7 templates, write CHANGELOG 4.0.0 breaking changes entry
- [ ] **Phase 7: Validation** - Run full 12-cell install matrix, align all version references, gate 4.0.0 release

## Phase Details

### Phase 1: Pre-work Bug Fixes
**Goal**: All known v3.x bugs that would silently corrupt complement-mode logic are eliminated before new code lands
**Depends on**: Nothing (first phase)
**Requirements**: BUG-01, BUG-02, BUG-03, BUG-04, BUG-05, BUG-06, BUG-07
**Success Criteria** (what must be TRUE):
  1. Running `/update-toolkit` on macOS with a customized CLAUDE.md preserves every user section intact (no truncation from BSD head)
  2. Running `bash <(curl ... setup-council.sh)` completes without hanging or consuming the curl stream as prompt input
  3. Entering an API key containing `"` or `\` through any script prompt produces a valid, parseable config.json
  4. `setup-security.sh` creates a timestamped backup of settings.json before any mutation, and the backup is confirmed present on disk
  5. `scripts/init-local.sh --version` and `manifest.json` and CHANGELOG.md all report the same version string
**Plans**: 7 plans

Plans:

- [x] 01-01-PLAN.md — BUG-01: replace GNU `head -n -1` with POSIX `sed ${d}` in update-claude.sh smart-merge
- [x] 01-02-PLAN.md — BUG-02: add `< /dev/tty` guards to interactive reads in setup-council.sh + early non-interactive guard
- [x] 01-03-PLAN.md — BUG-05: timestamped settings.json backup + restore-on-failure in setup-security.sh
- [x] 01-04-PLAN.md — BUG-03: JSON-escape API keys via `python3 json.dumps` in setup-council.sh and init-claude.sh
- [x] 01-05-PLAN.md — BUG-06: align versions — init-local.sh reads manifest.json, CHANGELOG `[Unreleased]` entry, Makefile alignment check
- [x] 01-06-PLAN.md — BUG-04: prompt before `sudo apt-get install tree` in setup-council.sh + visible errors
- [x] 01-07-PLAN.md — BUG-07: add `design.md` to update-claude.sh loop + Makefile manifest-drift check

### Phase 2: Foundation
**Goal**: The toolkit has a single reliable way to detect SP and GSD, a declarative manifest schema encoding conflicts, and an atomic install-state file with locking — the three pillars everything else depends on
**Depends on**: Phase 1
**Requirements**: DETECT-01, DETECT-02, DETECT-03, DETECT-04, DETECT-05, MANIFEST-01, MANIFEST-02, MANIFEST-03, MANIFEST-04, STATE-01, STATE-02, STATE-03, STATE-04, STATE-05
**Success Criteria** (what must be TRUE):
  1. Sourcing detect.sh sets HAS_SP and HAS_GSD correctly for all four combinations: neither present, SP only, GSD only, both present
  2. A SP install with stale cache dir but disabled in settings.json is detected as absent (no false positive)
  3. Every confirmed duplicate file in manifest.json has a conflicts_with annotation; `make validate` fails if a manifest path does not exist on disk
  4. toolkit-install.json survives a kill -9 mid-write with no truncation (next run parses it successfully or falls back to re-detection)
  5. Two concurrent runs of init-claude.sh are blocked by the mkdir lock; stale lock older than 1 hour is reclaimed with a visible warning
**Plans**: 3 plans

Plans:

- [x] 02-01-PLAN.md — detect.sh filesystem detection + five-case POSIX test harness (DETECT-01..05)
- [x] 02-02-PLAN.md — manifest v2 schema + validate-manifest.py + MANIFEST-03 count decision (MANIFEST-01..04)
- [x] 02-03-PLAN.md — scripts/lib/state.sh: atomic toolkit-install.json writes + mkdir lock with stale recovery (STATE-01..05)

### Phase 3: Install Flow
**Goal**: Users can install the toolkit in any of four modes via init-claude.sh and init-local.sh, with dry-run preview, mode auto-recommendation, and settings.json merged safely
**Depends on**: Phase 2
**Requirements**: MODE-01, MODE-02, MODE-03, MODE-04, MODE-05, MODE-06, SAFETY-01, SAFETY-02, SAFETY-03, SAFETY-04
**Success Criteria** (what must be TRUE):
  1. Fresh install on a machine with SP+GSD detected recommends complement-full mode; user can override to any other mode before any file is written
  2. `init-claude.sh --dry-run laravel` prints a per-file [INSTALL] / [SKIP - conflicts with superpowers] list and exits 0 without touching the filesystem
  3. Running init-claude.sh with SP present does not install any file whose conflicts_with includes superpowers
  4. After install, settings.json retains all hooks previously installed by SP or GSD; only TK-owned entries are added or replaced
  5. settings.json backup with unix-ts suffix exists on disk before any mutation; failed merge restores from backup before exiting non-zero
**Plans**: TBD
**UI hint**: no

### Phase 4: Update Flow
**Goal**: update-claude.sh re-evaluates detection on every run, identifies new and removed files from the manifest, surfaces mode drift to the user, and produces a grouped post-update summary
**Depends on**: Phase 3
**Requirements**: UPDATE-01, UPDATE-02, UPDATE-03, UPDATE-04, UPDATE-05, UPDATE-06
**Success Criteria** (what must be TRUE):
  1. Running update after installing SP prompts the user that the detected base set changed and offers to switch from standalone to complement-sp
  2. A file added to manifest.json since last install is detected and offered for install on next update run (mode-aware skip applied)
  3. A file removed from manifest.json since last install is detected and offered for deletion with backup and confirmation
  4. Post-update summary shows exactly four groups: INSTALLED N, UPDATED M, SKIPPED P (with reason per file), REMOVED Q (backed up to path)
  5. Running update twice in the same second does not produce a naming collision in backup dirs
**Plans**: TBD

### Phase 5: Migration
**Goal**: Existing v3.x users with SP or GSD installed can safely remove duplicate TK files via a dedicated migration script that shows a three-way diff, backs up everything first, and requires per-file confirmation
**Depends on**: Phase 4
**Requirements**: MIGRATE-01, MIGRATE-02, MIGRATE-03, MIGRATE-04, MIGRATE-05, MIGRATE-06
**Success Criteria** (what must be TRUE):
  1. migrate-to-complement.sh lists every v3.x duplicate (per manifest conflicts_with) with a three-column hash summary before asking the user anything
  2. A user-modified file (current hash != install-time hash from toolkit-install.json) shows an extra warning before its removal prompt
  3. The entire current install is backed up to ~/.claude-backup-pre-migrate-<unix-ts>/ and its path is printed before any file is removed
  4. Running the migration script twice on an already-migrated install prints "nothing to do" and exits 0
  5. toolkit-install.json is rewritten to reflect the new complement-* mode and updated installed_files list after migration completes
**Plans**: TBD

### Phase 6: Documentation
**Goal**: README positions the toolkit as a complement, every template documents required base plugins, CHANGELOG.md has a complete 4.0.0 entry, and recommended optional plugins (rtk, caveman) are documented with caveats
**Depends on**: Phase 5
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06, DOCS-07, DOCS-08
**Success Criteria** (what must be TRUE):
  1. README install section shows both standalone and complement paths with one paragraph of guidance each
  2. All 7 templates/*/CLAUDE.md files contain a "Required Base Plugins" section with SP and GSD install instructions
  3. CHANGELOG.md [4.0.0] entry lists every BREAKING CHANGE: mode behavior, removed duplicates, manifest schema bump
  4. docs/INSTALL.md (or README section) documents all 12 cells of the install matrix (4 modes x fresh/upgrade/re-run) with expected behavior per cell
  5. components/optional-plugins.md exists and documents rtk + caveman with their caveats (rtk-ls bug + exclusion config, caveman language limits, compress-mode CLAUDE.md backup warning); init-claude.sh prints the optional-plugins block at end of install; ~/.claude/RTK.md template carries the Known Issues section pointing to upstream issue #1276
  6. components/orchestration-pattern.md is finalized, registered in manifest.json under components, and cross-referenced from supreme-council.md and structured-workflow.md; README "Components" section links to it
**Plans**: TBD

### Phase 7: Validation
**Goal**: All 12 install matrix cells are manually smoke-tested and pass, make check passes clean, all version references are aligned, and 4.0.0 is ready to tag
**Depends on**: Phase 6
**Requirements**: VALIDATE-01, VALIDATE-02, VALIDATE-03, VALIDATE-04
**Success Criteria** (what must be TRUE):
  1. docs/RELEASE-CHECKLIST.md exists and covers all 12 cells (4 modes x fresh install, upgrade from v3.x, re-run idempotence)
  2. Each smoke-test cell verifies: toolkit-install.json correct, no unexpected files installed/skipped, settings.json keys intact, exit code 0
  3. In every complement mode, SP's code-reviewer agent and TK do not collide on the same agent name
  4. `make check` passes with zero errors; manifest.json schema validation passes; manifest.json, init-local.sh, and CHANGELOG.md all reference 4.0.0
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Pre-work Bug Fixes | 7/7 | Complete | 2026-04-17 |
| 2. Foundation | 0/3 | Planned | - |
| 3. Install Flow | 0/TBD | Not started | - |
| 4. Update Flow | 0/TBD | Not started | - |
| 5. Migration | 0/TBD | Not started | - |
| 6. Documentation | 0/TBD | Not started | - |
| 7. Validation | 0/TBD | Not started | - |
