# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- 🚧 **v4.4 Bootstrap & Polish** — Phases 21–23 (in progress)

## Phases

<details>
<summary>✅ v4.0 Complement Mode (Phases 1–7 + 6.1) — SHIPPED 2026-04-21</summary>

- [x] Phase 1: Pre-work Bug Fixes (7/7 plans) — completed 2026-04-21
- [x] Phase 2: Foundation (3/3 plans) — completed 2026-04-21
- [x] Phase 3: Install Flow (3/3 plans) — completed 2026-04-21
- [x] Phase 4: Update Flow (3/3 plans) — completed 2026-04-21
- [x] Phase 5: Migration (3/3 plans) — completed 2026-04-21
- [x] Phase 6: Documentation (3/3 plans) — completed 2026-04-19
- [x] Phase 6.1: README translations sync (3/3 plans, INSERTED) — completed 2026-04-21
- [x] Phase 7: Validation (4/4 plans) — completed 2026-04-21

</details>

<details>
<summary>✅ v4.1 Polish & Upstream (Phases 8–12) — SHIPPED 2026-04-25</summary>

- [x] Phase 8: Release Quality (3/3 plans) — completed 2026-04-24
- [x] Phase 9: Backup & Detection (4/4 plans) — completed 2026-04-24
- [x] Phase 10: Upstream GSD Issues (1/1 plan) — completed 2026-04-24
- [x] Phase 11: UX Polish (3/3 plans) — completed 2026-04-25
- [x] Phase 12: Audit Verification + Template Hardening (2/2 plans, INSERTED) — completed 2026-04-24

</details>

<details>
<summary>✅ v4.2 Audit System v2 (Phases 13–17) — SHIPPED 2026-04-26</summary>

- [x] Phase 13: Foundation — FP Allowlist + Skip/Restore Commands (5/5 plans) — completed 2026-04-25
- [x] Phase 14: Audit Pipeline — FP Recheck + Structured Reports (4/4 plans) — completed 2026-04-25
- [x] Phase 15: Council Audit-Review Integration (6/6 plans) — completed 2026-04-25
- [x] Phase 16: Template Propagation — 49 Prompt Files (4/4 plans) — completed 2026-04-25
- [x] Phase 17: Distribution — Manifest, Installers, CHANGELOG (3/3 plans) — completed 2026-04-26

</details>

<details>
<summary>✅ v4.3 Uninstall (Phases 18–20) — SHIPPED 2026-04-26</summary>

- [x] Phase 18: Core Uninstall — Script + Dry-Run + Backup (4/4 plans) — completed 2026-04-26
- [x] Phase 19: State Cleanup + Idempotency (3/3 plans) — completed 2026-04-26
- [x] Phase 20: Distribution + Tests (3/3 plans) — completed 2026-04-26

</details>

<details>
<summary>🚧 v4.4 Bootstrap & Polish (Phases 21–23) — IN PROGRESS</summary>

- [x] **Phase 21: SP/GSD Bootstrap Installer** — Before detection, `init-claude.sh`/`init-local.sh` offer to install SP/GSD via their canonical commands; `--no-bootstrap` skips for CI (completed 2026-04-27)
- [ ] **Phase 22: Smart-Update Coverage for `scripts/lib/*.sh`** — Register `lib/backup.sh`, `lib/dry-run-output.sh`, `lib/install.sh`, `lib/state.sh` in `manifest.json` so `update-claude.sh` keeps them current
- [ ] **Phase 23: Installer Symmetry & Recovery** — `init-claude.sh`/`init-local.sh` learn `--no-banner`; `uninstall.sh` learns `--keep-state` to preserve state file for partial-uninstall recovery

</details>

## Phase Details

### Phase 21: SP/GSD Bootstrap Installer

**Goal**: Users running `init-claude.sh` or `init-local.sh` for the first time can install `superpowers` and/or `get-shit-done` before the toolkit detection logic runs, without leaving the installer or issuing additional commands.

**Depends on**: Phase 20 (v4.3 complete — `detect.sh` and `toolkit-install.json` already ship)

**Requirements**: BOOTSTRAP-01, BOOTSTRAP-02, BOOTSTRAP-03, BOOTSTRAP-04

**Success Criteria** (what must be TRUE):

1. User runs `init-claude.sh`; before detection fires, they see two prompts — `Install superpowers via plugin marketplace? [y/N]` and `Install get-shit-done via curl install script? [y/N]` — answering `y` to SP triggers `claude plugin install superpowers@claude-plugins-official` with its output streaming to the terminal (BOOTSTRAP-01, BOOTSTRAP-02)
2. After bootstrap, the toolkit proceeds with detection and installs in the correct mode — e.g. answering `y` to SP causes the resulting `toolkit-install.json` to record `complement-sp` mode rather than `standalone` (BOOTSTRAP-03)
3. Running `init-claude.sh --no-bootstrap` (or with `TK_NO_BOOTSTRAP=1` in env) produces zero bootstrap prompts and unchanged v4.3 install behaviour; `--help` output lists the flag; `docs/INSTALL.md` documents it (BOOTSTRAP-04)
4. `scripts/tests/test-bootstrap.sh` passes all three branches — prompt-y, prompt-N, `--no-bootstrap` skip — with no stdin/TTY assumption failures in piped mode (BOOTSTRAP-04)

**Plans**: 3 plans

- [x] 21-01-PLAN.md — Library + constants extraction (scripts/lib/bootstrap.sh + TK_SP_INSTALL_CMD/TK_GSD_INSTALL_CMD constants in optional-plugins.sh)
- [x] 21-02-PLAN.md — Installer integration (init-claude.sh + init-local.sh: --no-bootstrap flag, source bootstrap.sh, call bootstrap_base_plugins, re-source detect.sh)
- [x] 21-03-PLAN.md — Test + distribution surface (scripts/tests/test-bootstrap.sh, Makefile Test 28, CI mirror, docs/INSTALL.md)

---

### Phase 22: Smart-Update Coverage for `scripts/lib/*.sh`

**Goal**: Users who run `update-claude.sh` after a toolkit release get all four `scripts/lib/*.sh` files refreshed, not just top-level scripts — closing the silent gap where lib files can drift behind the published version.

**Depends on**: Phase 21

**Requirements**: LIB-01, LIB-02

**Success Criteria** (what must be TRUE):

1. `manifest.json` lists `scripts/lib/backup.sh`, `scripts/lib/dry-run-output.sh`, `scripts/lib/install.sh`, and `scripts/lib/state.sh` under a designated section (`files.libs[]` or extended `files.scripts[]`), each with its target install path; `make check` (markdownlint + shellcheck + validate + version-align) stays green (LIB-01)
2. Running `update-claude.sh` when a lib file on disk is stale (different SHA256 from the downloaded version) causes that file to be refreshed using the same diff/backup/safe-write contract as top-level scripts — the post-update file SHA256 matches the manifest fixture (LIB-02)
3. `scripts/tests/test-update-libs.sh` passes: a deliberately stale `lib/backup.sh` on disk gets refreshed on `update-claude.sh`; post-update SHA256 matches the manifest fixture (LIB-02)

**Plans**: TBD

---

### Phase 23: Installer Symmetry & Recovery

**Goal**: Users running installers in CI get clean output (no banner noise) regardless of which installer they call; users who aborted an uninstall by answering N can re-run `uninstall.sh` and see the remaining files rather than a silent no-op.

**Depends on**: Phase 22

**Requirements**: BANNER-01, KEEP-01, KEEP-02

**Success Criteria** (what must be TRUE):

1. Running `init-claude.sh --no-banner` or `init-local.sh --no-banner` (or with `NO_BANNER=1`) suppresses the closing `To remove: bash <(curl …)` line; running without the flag prints it as before — behaviour is byte-identical to `update-claude.sh`'s existing `--no-banner` (BANNER-01)
2. `scripts/tests/test-install-banner.sh` extended assertions cover both `init-claude.sh` and `init-local.sh` in `--no-banner` mode and default mode (BANNER-01)
3. Running `uninstall.sh --keep-state` (or `TK_UNINSTALL_KEEP_STATE=1`) leaves `~/.claude/toolkit-install.json` on disk after the run ends — even when the user answered N on all modified files (KEEP-01)
4. A second invocation of `uninstall.sh` (without `--keep-state`) after a prior `--keep-state` run is NOT a no-op: it re-classifies the still-present modified files and presents the `[y/N/d]` prompt for each (KEEP-02)
5. `scripts/tests/test-uninstall-keep-state.sh` passes all four assertions: state file exists post-run, second invocation is not a no-op, MODIFIED list is non-empty on second invocation, base-plugin invariant (`diff -q`) still passes (KEEP-02)

**Plans**: TBD

---

## Progress

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v4.0 Complement Mode | 1–7 + 6.1 | 29/29 | ✅ Shipped | 2026-04-21 |
| v4.1 Polish & Upstream | 8–12 | 13/13 | ✅ Shipped | 2026-04-25 |
| v4.2 Audit System v2 | 13–17 | 22/22 | ✅ Shipped | 2026-04-26 |
| v4.3 Uninstall | 18–20 | 10/10 | ✅ Shipped | 2026-04-26 |
| v4.4 Bootstrap & Polish | 21–23 | 0/~8 (Phase 21 planned: 3) | 🚧 In progress | — |
