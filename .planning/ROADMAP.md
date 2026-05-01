# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- ✅ **v4.4 Bootstrap & Polish** — Phases 21–23 (shipped 2026-04-27). See `.planning/milestones/v4.4-ROADMAP.md`.
- ✅ **v4.6 Install Flow UX & Desktop Reach** — Phases 24–27 (shipped 2026-04-29). See `.planning/milestones/v4.6-ROADMAP.md`.
- ✅ **v4.8 Multi-CLI Bridge** — Phases 28–31 (shipped 2026-04-29). See `.planning/milestones/v4.8-ROADMAP.md`.
- 🚧 **v4.9 Integrations Catalog** — Phases 32–35 (active, started 2026-05-02).

## Active Milestone

**v4.9 Integrations Catalog** — unify the existing 9-MCP catalog into a 19-entry **Integrations** catalog combining MCP servers + companion CLIs (`wrangler`, `supabase`, `stripe`, `aws`, `nlm`) under one TUI page. Add 11 new entries, drop 1 (sequential-thinking), re-categorize existing 8. Cross-platform CLI installer with post-install hints. `unofficial` warning badges. Category grouping in TUI.

### Phases

- [ ] **Phase 32: Foundation — Schema Migration + CLI Installer Library** — `integrations-catalog.json` schema, validator, `cli-installer.sh` library, backward-compat `--mcps` alias.
- [ ] **Phase 33: Catalog Population — 11 New Entries + Drop + Re-categorize** — supabase, cloudflare, stripe, aws-cost-explorer, aws-cloudwatch-logs, notebooklm, youtrack, linear, jira, figma, slack, telegram; drop sequential-thinking; tag 8 existing entries with category.
- [ ] **Phase 34: TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags** — category headers, per-component status detection, `unofficial` `[y/N]` confirm, `--mcp-only`/`--cli-only` flags, summary table.
- [ ] **Phase 35: Distribution + Tests + Docs** — manifest 4.9.0, version-align, 3 test suites (catalog, CLI installer, integrations TUI), `docs/INTEGRATIONS.md`, INSTALL.md flag rows, README, CHANGELOG `[4.9.0]`.

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

<details>
<summary>✅ v4.8 Multi-CLI Bridge (Phases 28–31) — SHIPPED 2026-04-29</summary>

- [x] Phase 28: Bridge Foundation (3/3 plans) — completed 2026-04-29
- [x] Phase 29: Sync & Uninstall Integration (3/3 plans) — completed 2026-04-29
- [x] Phase 30: Install-time UX (3/3 plans) — completed 2026-04-29
- [x] Phase 31: Distribution + Tests + Docs (3/3 plans) — completed 2026-04-29

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
- [x] 30-01-PLAN.md — Wave 1 helpers (bridges.sh: bridge_install_prompts + _bridge_cli_version/_bridge_cli_label/_bridge_match; dispatch.sh: TK_DISPATCH_ORDER append)
- [x] 30-02-PLAN.md — Wave 2 install.sh (conditional TUI rows + dispatch case + --no-bridges / --bridges flags + mutex)
- [x] 30-03-PLAN.md — Wave 2 init-claude.sh + init-local.sh post-install bridge_install_prompts call + new test-bridges-install-ux.sh hermetic suite (>=12 assertions)
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
**Plans**: 3 plans
- [x] 31-01-PLAN.md — Manifest registration (`scripts/lib/bridges.sh` in `files.libs[]`) + version bump to 4.7.0 in manifest + 3 plugin.json files + CHANGELOG `[4.7.0]` consolidated entry
- [x] 31-02-PLAN.md — Aggregator test (`scripts/tests/test-bridges.sh` wrapping the 3 existing bridge suites = 50 assertions) + CI integration (`quality.yml` test-init-script append)
- [x] 31-03-PLAN.md — `docs/BRIDGES.md` (NEW, 9 sections) + `docs/INSTALL.md` Installer Flags table extension (4 new flag rows + Multi-CLI Bridges sub-section) + README Killer Features grid row

### Phase 32: Foundation — Schema Migration + CLI Installer Library

**Goal**: Migrate `mcp-catalog.json` schema to `integrations-catalog.json` with per-entry `components: { mcp?, cli? }` blocks and `category` + `unofficial` fields; ship a cross-platform CLI installer library (`scripts/lib/cli-installer.sh`) that detects CLIs via `command -v`, dispatches install via `brew`/`apt`/shell installers without auto-elevation, and prints post-install hints to stderr. Backward-compat alias `--mcps` → `--integrations` with stderr deprecation note. This phase unblocks Phases 33 and 34 — every downstream entry depends on the schema being ready and the CLI installer being callable.
**Depends on**: Nothing (entry phase). Builds on v4.6 Phase 25 foundation (`scripts/lib/mcp-catalog.json` + `mcp.sh`) and v4.6 Phase 24 lib foundation (`scripts/lib/{tui.sh, detect2.sh, dispatch.sh}`).
**Requirements**: CAT-01, CAT-02, CAT-03, CAT-04, CLI-01, CLI-02, CLI-03, CLI-04
**Success Criteria** (what must be TRUE):
  1. `scripts/lib/integrations-catalog.json` exists at the new path with the 9 existing entries already populated (schema-only migration, content unchanged); `scripts/lib/mcp-catalog.json` is removed; `scripts/lib/mcp.sh` reads the new path and existing v4.6 `test-mcp-selector.sh` PASS=21 stays green.
  2. Running `python3 scripts/validate-integrations-catalog.py` against the new file passes for valid entries and fails with explicit error messages on: unknown `category`, missing `mcp.install_args`, missing `cli.detect_cmd`, missing `cli.install.darwin` or `cli.install.linux`. `make check` invokes the validator and fails the build on schema violations.
  3. Sourcing `scripts/lib/cli-installer.sh` and calling `cli_detect wrangler` returns 0 when `wrangler` is on PATH and 1 otherwise; calling `cli_install wrangler "npm i -g wrangler" "npm i -g wrangler"` on macOS dispatches to the darwin command, returns rc of `npm`, captures stderr to `mktemp` for diagnostics, and never invokes `sudo`.
  4. On an unsupported platform (e.g., `uname` returns `MINGW64_NT`), `cli_install` exits non-zero with `Error: unsupported platform <name> — toolkit installs CLIs on darwin/linux only` to stderr; on macOS without `brew`, prints `brew not found — install via https://brew.sh first, then re-run` and returns non-zero (continue-on-error, not abort).
  5. Running `bash scripts/install.sh --mcps` in v4.9 prints `Note: --mcps is deprecated, use --integrations (alias preserved through v5.0)` to stderr but otherwise behaves byte-identically to `--integrations` (BACKCOMPAT-01 invariant preserved).
**Plans**: 3 plans
- [ ] 32-01-PLAN.md — Schema migration + Python validator + `--mcps`/`--integrations` alias (CAT-01..04)
- [ ] 32-02-PLAN.md — `scripts/lib/cli-installer.sh` library: cli_detect, cli_install, cli_post_install_hint (CLI-01..04)
- [ ] 32-03-PLAN.md — Hermetic smoke `test-integrations-foundation.sh` covering all 8 REQ-IDs at contract level
**UI hint**: no

### Phase 33: Catalog Population — 11 New Entries + Drop + Re-categorize

**Goal**: Populate `integrations-catalog.json` to 19 final entries: add 12 new (`supabase`, `cloudflare`, `stripe`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `notebooklm`, `youtrack`, `linear`, `jira`, `figma`, `slack`, `telegram`), drop 1 (`sequential-thinking`), tag the 8 surviving existing entries (context7, firecrawl, magic, notion, openrouter, playwright, resend, sentry) with their `category` field. CLI blocks added to `firecrawl`, `playwright`, `sentry` (existing entries with valuable CLIs) and to all new entries with companion CLIs (supabase, cloudflare, stripe, aws-cost-explorer + aws-cloudwatch-logs share `aws`, notebooklm).
**Depends on**: Phase 32 (consumes the new schema with `components`, `category`, `unofficial` fields and the `cli-installer.sh` API).
**Requirements**: INT-01, INT-02, INT-03, INT-04, INT-05, INT-06, INT-07, INT-08, INT-09, INT-10, INT-11, INT-12, DROP-01, EXIST-01
**Success Criteria** (what must be TRUE):
  1. `integrations-catalog.json` has exactly 19 entries; running `python3 scripts/validate-integrations-catalog.py` passes; `sequential-thinking` no longer appears in the catalog file.
  2. Each of the 12 new entries (INT-01..12) has its declared `mcp` and/or `cli` block populated per REQUIREMENTS.md spec — including correct `install_args[]`, `env_var_keys[]`, `requires_oauth`, `cli.detect_cmd`, `cli.install.{darwin,linux}`, and `cli.post_install_hint` where applicable; `notebooklm` and `telegram` carry `unofficial: true`.
  3. All 8 surviving existing entries carry a valid `category` from the canonical 10-list (`docs-research`, `backend`, `payments`, `email`, `workspace`, `project-management`, `communication`, `design`, `dev-tools`, `monitoring`); `firecrawl`, `playwright`, `sentry` gain optional `cli` blocks; the other 5 stay MCP-only.
  4. AWS entries (`aws-cost-explorer`, `aws-cloudwatch-logs`) declare the same shared `aws` CLI block per spec — installer dedupes by `cli.detect_cmd` so the user is prompted once, not twice.
  5. Running v4.6 `test-mcp-selector.sh` against the populated catalog still passes its 21 baseline assertions (no regression in MCP-only flow); category assignments lint-clean against the validator's category enum.
**Plans**: 4 plans
**UI hint**: no

### Phase 34: TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags

**Goal**: Render the 19-entry catalog as a category-grouped TUI page with per-component status detection, an `unofficial` confirm gate, and `--mcp-only` / `--cli-only` modifier flags. Closing summary table prints per-entry × per-component status. This is the user-facing payoff phase of v4.9 — it's where the schema and catalog show up as a polished install experience.
**Depends on**: Phase 32 (CLI-installer + schema), Phase 33 (populated 19-entry catalog). Phases 33 and 34 cannot ship in parallel: TUI-02 status detection and TUI-05 summary table require the populated catalog.
**Requirements**: TUI-01, TUI-02, TUI-03, TUI-04, TUI-05
**Success Criteria** (what must be TRUE):
  1. Running `scripts/install.sh --integrations` renders rows grouped by `category` with category headers (e.g., `── Backend ──`); category order matches the canonical 10-list in CAT-03; rows within a category are alphabetical; entries with `unofficial: true` carry a yellow `!` glyph next to the name.
  2. Each TUI row displays per-component status detected at TUI launch: MCP column (`✓ installed` / `✗ not installed` / `⊘ already`) via `claude mcp list`; CLI column (`✓ installed` / `✗ not installed` / `⊘ already`) via `command -v` from `cli-installer.sh::cli_detect`; no cache file — re-detected every launch.
  3. Selecting an `unofficial` entry (notebooklm or telegram) triggers a per-row `[y/N]` confirm prompt (`< /dev/tty`, fail-closed `N`, mirrors v4.3 UN-03 contract); rejecting drops the entry from the install queue without aborting.
  4. `--mcp-only` installs only MCP components from selected rows, skipping every `cli` block; `--cli-only` does the inverse; using both flags together exits non-zero with `Error: --mcp-only and --cli-only are mutually exclusive` to stderr (mirrors v4.8 `--bridges`/`--no-bridges` mutex pattern).
  5. After dispatch, the install summary prints a per-entry, per-component status table (entry × {MCP, CLI} matrix) — mirroring Phase 25 D-28 summary contract — with `✓ installed` / `⊘ already present` / `✗ failed: <reason>` per cell; idempotent re-runs are no-ops on already-present components.
**Plans**: 3 plans
**UI hint**: yes

### Phase 35: Distribution + Tests + Docs

**Goal**: Ship v4.9 end-to-end — `manifest.json` bumps to 4.9.0 and registers the new lib + script + JSON catalog, `init-claude.sh --version` / `init-local.sh --version` derive from manifest at runtime per v4.3 D-22, three new hermetic test suites lock the schema + CLI installer + integrations TUI contract, and users discover the feature through `docs/INTEGRATIONS.md` + INSTALL.md + README + CHANGELOG. Mirrors v4.8 Phase 31 close-pattern: tests-first, then manifest, then docs-last.
**Depends on**: Phases 32 + 33 + 34 (schema, catalog, TUI must all be present before tests + docs can lock the contract).
**Requirements**: DIST-01, DIST-02, TEST-01, TEST-02, TEST-03, TEST-04, DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05
**Success Criteria** (what must be TRUE):
  1. `manifest.json` version field shows `4.9.0`; `files.libs[]` registers `scripts/lib/cli-installer.sh`; the existing `mcp-catalog.json` registry entry is replaced with `scripts/lib/integrations-catalog.json`; `files.scripts[]` registers `scripts/validate-integrations-catalog.py`. `update-claude.sh` auto-discovers all three on a stale install via the existing v4.4 LIB-01 D-07 jq path with zero new code; `init-claude.sh --version` and `init-local.sh --version` both print `4.9.0` derived from manifest at runtime.
  2. Three new hermetic test suites pass: `test-integrations-catalog.sh` (≥10 assertions covering 19 entries, valid categories, all `cli` blocks have `detect_cmd` + OS keys, all MCP blocks have `install_args`); `test-cli-installer.sh` (≥8 assertions covering success / already-present / brew-absent fallback / Windows-rejection / post-install-hint emission with mocked shims); `test-integrations-tui.sh` (≥15 new assertions on top of Phase 25 baseline, covering category headers, `unofficial` confirm, `--mcp-only` skip, `--cli-only` skip, summary table).
  3. All 3 new test suites wired into `Makefile` as Tests 31, 32, 33 and into `.github/workflows/quality.yml` step `Tests 21-33`; CI green on PR; existing `test-mcp-selector.sh` PASS=21, `test-bootstrap.sh` PASS=26, `test-install-tui.sh` PASS=43 baselines unchanged (BACKCOMPAT-01 preserved).
  4. `docs/INTEGRATIONS.md` exists and documents: 19-entry table grouped by category, `--mcp-only` / `--cli-only` flags, `unofficial` semantics + the Y/N confirm gate, OAuth setup links, troubleshooting (missing `brew`, post-install hint surface), and a dedicated **"Global vs per-project"** section stating that toolkit installs MCPs + CLIs globally on the dev machine and never touches per-project SDKs (DOCS-02 boundary).
  5. `docs/INSTALL.md` `## Installer Flags` table gains rows for `--integrations`, `--mcp-only`, `--cli-only` plus `--mcps` deprecation note; `README.md` "Killer Features" grid gains a 1-line Integrations Catalog bullet; `CHANGELOG.md [4.9.0]` is a single consolidated entry (Added / Changed / Removed) per v4.4/v4.6/v4.8 convention; `make check` green; CI `validate-templates` green.
**Plans**: 4 plans
**UI hint**: no

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
| v4.8 Multi-CLI Bridge | 28–31 | 12/12 | ✅ Shipped | 2026-04-29 |
| v4.9 Integrations Catalog | 32–35 | 0/14 (planned) | 🚧 Active | TBD |

## v4.9 Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 32. Foundation — Schema Migration + CLI Installer Library | 0/3 | Not started | - |
| 33. Catalog Population — 11 New Entries + Drop + Re-categorize | 0/4 | Not started | - |
| 34. TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags | 0/3 | Not started | - |
| 35. Distribution + Tests + Docs | 0/4 | Not started | - |
