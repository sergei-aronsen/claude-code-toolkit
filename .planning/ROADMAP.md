# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- ✅ **v4.4 Bootstrap & Polish** — Phases 21–23 (shipped 2026-04-27). See `.planning/milestones/v4.4-ROADMAP.md`.
- ✅ **v4.6 Install Flow UX & Desktop Reach** — Phases 24–27 (shipped 2026-04-29). See `.planning/milestones/v4.6-ROADMAP.md`.
- 🚧 **v4.7 Multi-CLI Bridge** — Phases 28–31 (active, scoped 2026-04-29).

## v4.7 Multi-CLI Bridge — Active

**Goal:** Copy `CLAUDE.md` → `GEMINI.md` (Gemini CLI) and `CLAUDE.md` → `AGENTS.md` (OpenAI Codex CLI) at install time with SHA256 drift tracking and a `[y/N/d]` prompt on update, so users running multiple agentic CLIs do not maintain duplicate context files manually.

**Coverage:** 18 v4.7 REQ-IDs mapped 1:1 across 4 phases. 100% coverage, no orphans.

**Wave plan:**

- **Wave 1:** Phase 28 (foundation) — must complete first
- **Wave 2:** Phases 29 + 30 (sync + UX) — can run in parallel after Phase 28 ships
- **Wave 3:** Phase 31 (distribution + tests + docs) — depends on 28 + 29 + 30

## Phases

- [ ] **Phase 28: Bridge Foundation** — Detect Gemini/Codex CLIs and ship `bridges.sh` lib that generates plain-copy bridge files with SHA256 tracking.
- [ ] **Phase 29: Sync & Uninstall Integration** — `update-claude.sh` syncs bridges with `[y/N/d]` drift prompt + `--break-bridge` opt-out; `uninstall.sh` removes bridges symmetrically.
- [ ] **Phase 30: Install-time UX** — `install.sh` TUI rows + per-CLI prompts in `init-claude.sh` / `init-local.sh` + `--no-bridges` / `--bridges <list>` flags.
- [ ] **Phase 31: Distribution + Tests + Docs** — manifest 4.7.0 bump, `test-bridges.sh` (≥15 assertions), `docs/BRIDGES.md` + `INSTALL.md`/README updates, CHANGELOG `[4.7.0]`.

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
<summary>✅ v4.4 Bootstrap & Polish (Phases 21–23) — SHIPPED 2026-04-27</summary>

- [x] Phase 21: SP/GSD Bootstrap Installer (3/3 plans) — completed 2026-04-27
- [x] Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` (2/2 plans) — completed 2026-04-27
- [x] Phase 23: Installer Symmetry & Recovery (3/3 plans) — completed 2026-04-27

</details>

<details>
<summary>✅ v4.6 Install Flow UX & Desktop Reach (Phases 24–27) — SHIPPED 2026-04-29</summary>

- [x] Phase 24: Unified TUI Installer + Centralized Detection (5/5 plans) — completed 2026-04-29
- [x] Phase 25: MCP Selector (4/4 plans) — completed 2026-04-29
- [x] Phase 26: Skills Selector (4/4 plans) — completed 2026-04-29
- [x] Phase 27: Marketplace Publishing + Claude Desktop Reach (4/4 plans) — completed 2026-04-29

</details>

---

## Phase Details

### Phase 28: Bridge Foundation

**Goal**: Toolkit detects Gemini CLI and OpenAI Codex CLI presence, and ships a `bridges.sh` library that produces a plain-copy bridge file (`GEMINI.md` / `AGENTS.md`) with a canonical auto-generated header and registers each bridge in `~/.claude/toolkit-install.json` with both source-SHA256 and bridge-SHA256.
**Depends on**: Nothing (entry phase). Builds on v4.6 Phase 24 lib foundation (`scripts/lib/{tui.sh, detect2.sh, dispatch.sh}`).
**Requirements**: BRIDGE-DET-01, BRIDGE-DET-02, BRIDGE-DET-03, BRIDGE-GEN-01, BRIDGE-GEN-02, BRIDGE-GEN-03, BRIDGE-GEN-04
**Success Criteria** (what must be TRUE):
  1. Running `is_gemini_installed` / `is_codex_installed` from `detect2.sh` returns 0/1 binary, fail-soft when CLI absent (no error).
  2. Calling `bridge_create_project gemini` from a project directory writes `GEMINI.md` next to `CLAUDE.md` with the byte-identical auto-generated header at the top followed by one blank line then the verbatim CLAUDE.md content; re-running yields the same content.
  3. Calling `bridge_create_global codex` writes `~/.codex/AGENTS.md` (and creates `~/.codex/` if missing); never modifies `~/.claude/CLAUDE.md`.
  4. After bridge creation, `~/.claude/toolkit-install.json` contains a new `bridges[]` entry with `target`, `path`, `scope`, `source_sha256`, `bridge_sha256`, `user_owned: false` for every bridge.
  5. New detection probes coexist with the existing 6 v4.6 binary probes (toolkit, superpowers, gsd, security, rtk, statusline) without breaking `test-install-tui.sh` PASS=43.
**Plans**: 3 plans
- [x] 28-01-PLAN.md — Detection probes (`is_gemini_installed` / `is_codex_installed` in detect2.sh)
- [x] 28-02-PLAN.md — Bridges library (`scripts/lib/bridges.sh` with `bridge_create_project` / `bridge_create_global` + state mutation)
- [x] 28-03-PLAN.md — Hermetic smoke test (`scripts/tests/test-bridges-foundation.sh`, 5 assertions)

### Phase 29: Sync & Uninstall Integration

**Goal**: `update-claude.sh` keeps every registered bridge in sync with its `CLAUDE.md` source — recopying when source drifted, prompting `[y/N/d]` when the bridge itself was user-edited, and skipping bridges marked `user_owned`. `uninstall.sh` removes bridges as ordinary tracked artifacts with the existing v4.3 [y/N/d] modified-file prompt and v4.4 `--keep-state` semantics.
**Depends on**: Phase 28 (consumes `bridges.sh` API + `bridges[]` state schema).
**Requirements**: BRIDGE-SYNC-01, BRIDGE-SYNC-02, BRIDGE-SYNC-03, BRIDGE-UN-01, BRIDGE-UN-02
**Success Criteria** (what must be TRUE):
  1. After editing `CLAUDE.md` and running `update-claude.sh`, every clean bridge is rewritten and `[~ UPDATE] GEMINI.md` appears in the chezmoi-grade summary; recorded SHA256s are refreshed in toolkit-install.json.
  2. After editing `GEMINI.md` (user-modified bridge) and running `update-claude.sh`, the user is prompted `[y/N/d]` per drifted bridge with default `N`; `d` shows a diff and re-prompts; `N` keeps the user file untouched.
  3. Running `update-claude.sh --break-bridge gemini` flips `user_owned: true` for that bridge, and the very next `update-claude.sh` run logs `[- SKIP] GEMINI.md (--break-bridge)` and performs no copy; `--restore-bridge gemini` reverses the flag and the next run re-syncs.
  4. When `CLAUDE.md` is deleted, `update-claude.sh` logs `[? ORPHANED] GEMINI.md (CLAUDE.md missing)` and leaves the bridge file on disk; no exit-1.
  5. Running `uninstall.sh` removes clean bridges as `[- REMOVE]`, prompts `[y/N/d]` for user-modified bridges, preserves bridges under `--keep-state`, and the v4.3 `diff -q` base-plugin invariant remains green.
**Plans**: 3 plans
- [x] 29-01-PLAN.md — Foundation primitives (extend `write_state` to 10-arg `bridges_json`, add `_bridge_set_user_owned`/`_bridge_remove_state_entry`/`bridge_prompt_drift` helpers, update `init-local.sh` + `migrate-to-complement.sh` callers)
- [x] 29-02-PLAN.md — Sync loop in `update-claude.sh` (`--break-bridge`/`--restore-bridge` flags + `sync_bridges()` decision tree with `[~ UPDATE]`/`[~ MODIFIED]`/`[- SKIP]`/`[? ORPHANED]` logging)
- [x] 29-03-PLAN.md — Uninstall integration in `uninstall.sh` + new hermetic `scripts/tests/test-bridges-sync.sh` (≥10 assertions; BACKCOMPAT-01 PASS=26/43/5)

### Phase 30: Install-time UX

**Goal**: From the very first install, users see bridge options as part of the unified TUI (`scripts/install.sh`) and as inline prompts in `init-claude.sh` / `init-local.sh`. Non-interactive installs honour `--no-bridges` / `TK_NO_BRIDGES=1` to skip and `--bridges gemini,codex` to force-create. CLI-absent rows never appear, so users without the target CLIs see no clutter.
**Depends on**: Phase 28 (uses `bridges.sh` + `is_gemini_installed` / `is_codex_installed`). Can run in parallel with Phase 29.
**Requirements**: BRIDGE-UX-01, BRIDGE-UX-02, BRIDGE-UX-03, BRIDGE-UX-04
**Success Criteria** (what must be TRUE):
  1. With `gemini` on PATH, the v4.6 `install.sh` Components page shows a `[ ] Gemini CLI bridge (CLAUDE.md → GEMINI.md) [detected: gemini@<version>]` row; with `codex` on PATH, an analogous Codex row appears; CLIs absent → rows hidden.
  2. After `init-claude.sh` / `init-local.sh` finishes populating `.claude/`, every detected CLI triggers a per-CLI prompt `Gemini CLI detected. Create GEMINI.md → CLAUDE.md bridge? [Y/n]` defaulting `Y`; on no-TTY (CI / piped) installs the prompt fail-closes to `N`.
  3. `--no-bridges` flag and `TK_NO_BRIDGES=1` env var on any of `init-claude.sh`, `init-local.sh`, `install.sh` skip every bridge prompt and create zero bridges (mirrors v4.4 `--no-bootstrap` symmetry).
  4. `--bridges gemini,codex` flag forces non-interactive bridge creation for the named CLIs; absent CLI under `--fail-fast` exits 1; absent CLI without `--fail-fast` warns and continues.
  5. v4.6 BACKCOMPAT-01 invariant holds: `init-claude.sh` URL stays byte-identical and v4.4 `test-bootstrap.sh` PASS=26 + v4.6 `test-install-tui.sh` PASS=43 stay green throughout this phase.
**Plans**: 3 plans
- [ ] 30-01-PLAN.md — Wave 1 helpers (bridges.sh: bridge_install_prompts + _bridge_cli_version/_bridge_cli_label/_bridge_match; dispatch.sh: TK_DISPATCH_ORDER append)
- [ ] 30-02-PLAN.md — Wave 2 install.sh (conditional TUI rows + dispatch case + --no-bridges / --bridges flags + mutex)
- [ ] 30-03-PLAN.md — Wave 2 init-claude.sh + init-local.sh post-install bridge_install_prompts call + new test-bridges-install-ux.sh hermetic suite (>=12 assertions)
**UI hint**: yes

### Phase 31: Distribution + Tests + Docs

**Goal**: Bridge feature is shipped end-to-end — `manifest.json` registers `bridges.sh`, version bumps to `4.7.0`, hermetic `test-bridges.sh` proves all four UX/Sync/Uninstall branches, and users discover the feature through `docs/BRIDGES.md` plus the `Installer Flags` table in `docs/INSTALL.md` and the README "Killer Features" grid.
**Depends on**: Phases 28 + 29 + 30 (lib, sync, UX must all be present before tests + docs can lock the contract).
**Requirements**: BRIDGE-DIST-01, BRIDGE-DIST-02, BRIDGE-TEST-01, BRIDGE-DOCS-01, BRIDGE-DOCS-02
**Success Criteria** (what must be TRUE):
  1. `manifest.json` lists `scripts/lib/bridges.sh` under `files.libs[]`, version field shows `4.7.0`, and `update-claude.sh` auto-discovers bridges.sh on a stale install via the existing v4.4 LIB-01 D-07 jq path with zero new code.
  2. `scripts/tests/test-bridges.sh` runs hermetic with ≥15 assertions covering: plain-copy correctness, idempotent re-create, drift `[y/N/d]` branches, `--break-bridge` persistence, `--no-bridges` / `TK_NO_BRIDGES=1` skip, `--bridges gemini,codex` force, uninstall round-trip; existing `test-bootstrap.sh` PASS=26 and `test-install-tui.sh` PASS=43 unchanged.
  3. `docs/BRIDGES.md` documents supported CLIs (Gemini → `GEMINI.md`, Codex → `AGENTS.md` per OpenAI standard), plain-copy semantics + drift behavior, opt-out mechanics (`--no-bridges`, `--break-bridge`, `--restore-bridge`), and the symlink-vs-copy tradeoff rationale.
  4. `docs/INSTALL.md` `Installer Flags` table gains rows for `--no-bridges`, `--bridges <list>`, `--break-bridge <name>`, `--restore-bridge <name>`; README "Killer Features" grid mentions multi-CLI bridge support.
  5. `CHANGELOG.md [4.7.0]` is a single consolidated entry covering all 18 BRIDGE-* requirements (mirrors v4.4/v4.6 consolidation pattern); `make check` green; CI `validate-templates` green.
**Plans**: TBD

---

## Historical Progress

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v4.0 Complement Mode | 1–7 + 6.1 | 29/29 | ✅ Shipped | 2026-04-21 |
| v4.1 Polish & Upstream | 8–12 | 13/13 | ✅ Shipped | 2026-04-25 |
| v4.2 Audit System v2 | 13–17 | 22/22 | ✅ Shipped | 2026-04-26 |
| v4.3 Uninstall | 18–20 | 10/10 | ✅ Shipped | 2026-04-26 |
| v4.4 Bootstrap & Polish | 21–23 | 8/8 | ✅ Shipped | 2026-04-27 |
| v4.6 Install Flow UX & Desktop Reach | 24–27 | 17/17 | ✅ Shipped | 2026-04-29 |
| v4.7 Multi-CLI Bridge | 28–31 | 0/TBD | 🚧 Active | TBD |

## v4.7 Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 28. Bridge Foundation | 3/3 | Complete   | 2026-04-29 |
| 29. Sync & Uninstall Integration | 3/3 | Complete   | 2026-04-29 |
| 30. Install-time UX | 0/3 | Planned     | - |
| 31. Distribution + Tests + Docs | 0/TBD | Not started | - |
