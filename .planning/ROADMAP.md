# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- ✅ **v4.4 Bootstrap & Polish** — Phases 21–23 (shipped 2026-04-27). See `.planning/milestones/v4.4-ROADMAP.md`.
- ✅ **v4.6 Install Flow UX & Desktop Reach** — Phases 24–27 (shipped 2026-04-29). See `.planning/milestones/v4.6-ROADMAP.md`.
- ✅ **v4.8 Multi-CLI Bridge** — Phases 28–31 (shipped 2026-04-29). See `.planning/milestones/v4.8-ROADMAP.md`.
- ✅ **v4.9 Integrations Catalog** — Phases 32–35 (shipped 2026-05-02).
- 🚧 **v5.0 Per-MCP Scope + Project Secrets Boundary** — Phases 36–41 (active, started 2026-05-04).

## Active Milestone

**v5.0 Per-MCP Scope + Project Secrets Boundary** — give the user granular per-MCP scope control (`user` vs `project`) with sensible per-MCP defaults baked into the catalog, treat secrets correctly per scope (`~/.claude/mcp-config.env` for user-scope, `<project>/.env` + `${VAR}` substitution in `.mcp.json` for project-scope, never literal secrets in shared files), close the secrets-leak gap on uninstall (per-MCP keys + full-toolkit `mcp-config.env` cleanup prompts; project `.env` files never touched), and add Calendly to the catalog as an official MCP. Google Workspace deliberately NOT added — claude.ai's built-in Gmail/Calendar/Drive connectors already cover that surface.

### Phases

- [ ] **Phase 36: Catalog Schema + Backward Compat** — `default_scope` field on every MCP entry, validator enforcement, `mcp_catalog_load` silent fallback to `user` for pre-v5.0 catalogs.
- [ ] **Phase 37: Project Secrets Library** — new `scripts/lib/project-secrets.sh` (`.env` writer, `.gitignore` guard, `${VAR}` renderer, defense-in-depth literal-secret refusal, metacharacter rejection) plus its hermetic test suite.
- [ ] **Phase 38: Wizard Dispatch Integration** — `mcp_wizard_run` learns per-MCP scope routing, defer-secrets path extended to project scope, post-install summary printer updated, wizard tests extended.
- [ ] **Phase 39: TUI Per-Row Scope Toggle** — per-row `[U]/[P]/[L]` indicator, single-row hotkey, global `s` repurposed as "set all", `MCP_SELECTED_SCOPE[]` parallel array, dispatcher per-row injection, selector tests extended.
- [ ] **Phase 40: Uninstall Secret Cleanup + Calendly + Validator** — uninstall.sh per-MCP + full-toolkit secret-cleanup prompts, project `.env` never touched, `--keep-state` implies `--keep-secrets`, Calendly catalog entry, Google Workspace decision logged, validator + uninstall tests extended.
- [ ] **Phase 41: Distribution + Docs** — manifest 5.0.0 + `project-secrets.sh` registration, version-align across init scripts + 3 plugin.json files, CHANGELOG `[5.0.0]` consolidated, `docs/INTEGRATIONS.md` Per-MCP Scope section, INSTALL.md flag rows, UNINSTALL.md secret-cleanup section.

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

<details>
<summary>✅ v4.9 Integrations Catalog (Phases 32–35) — SHIPPED 2026-05-02</summary>

- [x] Phase 32: Foundation — Schema Migration + CLI Installer Library (3/3 plans) — completed 2026-05-02
- [x] Phase 33: Catalog Population — 11 New Entries + Drop + Re-categorize (4/4 plans) — completed 2026-05-02
- [x] Phase 34: TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags (3/3 plans) — completed 2026-05-02
- [x] Phase 35: Distribution + Tests + Docs (4/4 plans) — completed 2026-05-02

</details>

---

## Phase Details

### Phase 36: Catalog Schema + Backward Compat

**Goal**: Every MCP entry in `integrations-catalog.json` carries a `default_scope: "user"|"project"` field with sensible per-MCP defaults baked in, the validator enforces the field, and pre-v5.0 catalogs (or pre-v5.0 user installs that re-source an old catalog) keep working via a silent fallback to `user` in `mcp_catalog_load`. This is the foundation phase — every downstream phase reads the new field. Backward-compat fallback ships in the same plan as the schema field so there is never a window where the catalog has the field but the loader doesn't tolerate its absence.
**Depends on**: Nothing (entry phase). Builds on v4.9 Phase 32 catalog schema (`scripts/lib/integrations-catalog.json` + `scripts/validate-integrations-catalog.py` + `scripts/lib/mcp.sh::mcp_catalog_load`).
**Requirements**: SCOPE-01, SCOPE-02, SCOPE-03
**Success Criteria** (what must be TRUE):
  1. Every `components.mcp.<name>` block in `integrations-catalog.json` carries a `default_scope` field with value `"user"` or `"project"`; CLI-only entries are unaffected.
  2. Personal-tooling MCPs (`firecrawl`, `notebooklm`, `notion`, `youtrack`, `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`) default to `user`; per-app infra MCPs (`supabase`, `cloudflare`, `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `jira`, `linear`, `telegram`) default to `project`.
  3. Running `python3 scripts/validate-integrations-catalog.py` fails loudly when an MCP entry lacks `default_scope` or carries an invalid enum value; passes for valid entries; `make check` invokes the validator and fails the build on schema violations.
  4. Sourcing `scripts/lib/mcp.sh` against a synthetic catalog where one MCP omits `default_scope` results in `mcp_catalog_load` silently treating that entry as `user` with no warning emitted on stderr; v4.9 baselines (`test-mcp-selector.sh` PASS=21, `test-integrations-catalog.sh` PASS≥10) stay green.
**Plans**: 2 plans
- [x] 36-01-foundation-PLAN.md — catalog edits + validator extension + loader fallback (single landing per D-10)
- [x] 36-02-test-contract-PLAN.md — TEST-06 validator enforcement test + backward-compat sibling test + Makefile wiring
**UI hint**: no

### Phase 37: Project Secrets Library

**Goal**: Ship a new `scripts/lib/project-secrets.sh` library that owns the project-scope secrets boundary end-to-end: writes `KEY=value` to `<project>/.env` (mode 0600, idempotent merge with collision prompt), guarantees `.env` is in `<project>/.gitignore` (appends with leading comment if missing), renders `${VAR}` substitution form for `.mcp.json` env blocks, refuses any literal secret in `.mcp.json` env blocks (defense-in-depth), and rejects shell-metacharacter values. The library lands together with its hermetic test suite — the lib is meaningless without its test surface, and TEST-01 is the contract that locks the secrets boundary.
**Depends on**: Phase 36 (consumes `default_scope` semantics for sensible defaults; the lib itself is scope-agnostic but its callers in Phase 38 will branch on scope).
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, TEST-01
**Success Criteria** (what must be TRUE):
  1. Sourcing `scripts/lib/project-secrets.sh` exposes three callable functions (`project_secrets_write_env`, `project_secrets_ensure_gitignore`, `project_secrets_render_mcp_env_block`) and produces zero side effects on the filesystem at source time.
  2. Calling `project_secrets_write_env <project_root> KEY value` against a fresh project creates `<project>/.env` with mode 0600 (verified via `stat -f %Lp` on macOS / `stat -c %a` on Linux), writes the literal `KEY=value` line, and on re-invocation with the same key prompts `[y/N] Overwrite KEY in <project>/.env?` via `< /dev/tty` (fail-closed N) — Y replaces, N preserves.
  3. Calling `project_secrets_ensure_gitignore <project_root>` appends `.env\n` (with the leading toolkit comment) when `.gitignore` lacks an exact `^\.env$` line; is a no-op when `.env` is already present; never matches `*.env` or `# .env` as "present"; creates `.gitignore` if missing.
  4. Any code path that writes to `.mcp.json` (in this lib or in `mcp_wizard_run`) refuses to write a string value into an `env` block that does not match `^\$\{[A-Z_][A-Z0-9_]*\}$`; refusal returns rc=1 with `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)` to stderr; `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam works and warns when honored.
  5. `scripts/tests/test-project-secrets.sh` exists with ≥18 hermetic, idempotent assertions covering: 0600 mode enforcement, idempotent merge prompt branches, `.gitignore` append + no-op + false-negative-on-`*.env` cases, `${VAR}` renderer output, SEC-05 literal-secret refusal contract, SEC-06 metacharacter rejection (`$`, backtick, backslash, single + double quote, newline), and the `TK_PROJECT_SECRETS_ALLOW_LITERAL` test seam warning.
**Plans**: 2 plans
- [x] 37-01-secrets-lib-PLAN.md — scripts/lib/project-secrets.sh with 4 public functions + private helpers (SEC-01..06)
- [x] 37-02-test-contract-PLAN.md — scripts/tests/test-project-secrets.sh ≥18 assertions + Makefile + CI wiring (TEST-01)
**UI hint**: no

### Phase 38: Wizard Dispatch Integration

**Goal**: `mcp_wizard_run` learns per-MCP scope routing — when the caller exports `TK_MCP_SCOPE=project`, the wizard collects keys via the existing v4.6 hidden-input prompt loop, writes the real values to `<project>/.env` via `project_secrets_write_env`, ensures `.env` is in `.gitignore` once, and invokes `claude mcp add --scope project ...` with the env block rendered as `${VAR}` substitution form (never literal values). When `TK_MCP_SCOPE=user` (or unset), the v4.6/v4.9 behavior is preserved verbatim. The defer-secrets path (`TK_MCP_DEFER_SECRETS=1`) is extended for project scope: stub entries land in `<project>/.env`, the deferred queue tuple grows to 4 fields, and the post-install summary prints scope-correct hints.
**Depends on**: Phase 37 (consumes `project_secrets_write_env`, `project_secrets_ensure_gitignore`, `project_secrets_render_mcp_env_block`, and the SEC-05 literal-refusal contract).
**Requirements**: DISP-01, DISP-02, DISP-03, DISP-04, TEST-02, TEST-03
**Success Criteria** (what must be TRUE):
  1. With `TK_MCP_SCOPE=project` and `TK_PROJECT_ROOT=/tmp/p` exported, completing the wizard for a multi-key MCP results in real values written to `/tmp/p/.env` (mode 0600), `/tmp/p/.gitignore` containing `.env`, `claude mcp add --scope project ...` invoked with `--env KEY=${KEY}` substitution form, and `~/.claude/mcp-config.env` left byte-identical (no regression on user-scope flow).
  2. With `TK_MCP_SCOPE=user` (or unset) the wizard behaves byte-identically to v4.9: keys land in `~/.claude/mcp-config.env` via `mcp_secrets_set`, `claude mcp add --scope user ...` is invoked with literal env values exported via `env KEY=V`, and no `<project>/.env` is created or modified.
  3. Defer-secrets path with `TK_MCP_DEFER_SECRETS=1` and `TK_MCP_SCOPE=project` pre-creates blank stub entries in `<project>/.env` (not `mcp-config.env`), triggers `project_secrets_ensure_gitignore` once before the first stub write, and the deferred queue tuple has 4 fields (`name\tkeys\tinstall_args\tscope`) so the post-install summary printer can render scope-correct hints.
  4. The post-install summary printer (already part of `install.sh`'s MCP wizard close) prints the chosen scope alongside each MCP's keys-needed list; project-scope rows additionally print `→ Edit <project>/.env to fill values; ensure .env is in your .gitignore (we appended it).`.
  5. `scripts/tests/test-mcp-wizard.sh` extended from PASS=14 to PASS≥20 with DISP-01 / DISP-02 / DISP-03 happy paths plus the DISP-04 summary-line assertion; `scripts/tests/test-mcp-secrets.sh` extended from PASS=11 with the shared `_mcp_validate_value` boundary scenarios from SEC-06; v4.9 `test-mcp-selector.sh` PASS=21 baseline unchanged.
**Plans**: 3 plans
- [x] 38-01-PLAN.md — mcp_wizard_run scope-routing branch + 4-tuple deferred queue write + project-scope defer mirror (DISP-01, DISP-02, DISP-03 wizard side)
- [x] 38-02-PLAN.md — install.sh post-install summary 4-field tuple reader + per-scope dispatch blocks (DISP-03 reader side, DISP-04)
- [x] 38-03-PLAN.md — test-mcp-wizard.sh extension (PASS≥20) + test-mcp-secrets.sh boundary preservation (TEST-02, TEST-03)
**UI hint**: no

### Phase 39: TUI Per-Row Scope Toggle

**Goal**: Each MCP row in the integrations TUI carries its own scope indicator (`[U]/[P]/[L]`) immediately after the checkbox, with a per-row hotkey to flip a single row's scope and the existing global `s` keypress repurposed as a "set ALL visible rows to scope X" convenience. Per-row state is held in a parallel `MCP_SELECTED_SCOPE[]` array initialized from `default_scope` at TUI launch. The dispatcher exports `TK_MCP_SCOPE` per-row before invoking `mcp_wizard_run` so users can install some MCPs globally and others into a project in one pass.
**Depends on**: Phase 36 (consumes `default_scope` for initial values), Phase 38 (the dispatcher's per-row export targets the wizard contract that Phase 38 lands).
**Requirements**: TUI-SCOPE-01, TUI-SCOPE-02, TUI-SCOPE-03, TUI-SCOPE-04, TUI-SCOPE-05, TEST-04
**Success Criteria** (what must be TRUE):
  1. Running `scripts/install.sh --integrations` renders each MCP row with a scope indicator (`[U]`, `[P]`, or `[L]`) immediately after the checkbox; the chosen scope is colored green when color is enabled; setting `NO_COLOR=1` produces plain bracket form per [no-color.org](https://no-color.org).
  2. Pressing the per-row scope hotkey on a highlighted row cycles only that row's scope (`U → P → L → U`); other rows are unaffected; the binding is documented in the TUI hint footer.
  3. Pressing the global `s` keypress (the v4.9 Phase 37 / commit `fc000d5` global toggle, repurposed) cycles a global scope value and assigns it to every visible row in one stroke; the banner reads `s: set all to <scope>` instead of the v4.9 toggle copy.
  4. Per-row scope state lives in a Bash 3.2-compatible parallel array `MCP_SELECTED_SCOPE[]` (parallel to `MCP_NAMES`, `MCP_STATUS`, `MCP_HAS_CLI`) initialized from each entry's `default_scope` via `mcp_status_array`; no associative arrays, no `mapfile`, no `${var,,}`.
  5. The MCP install loop in `install.sh` reads `MCP_SELECTED_SCOPE[$i]` per row and exports `TK_MCP_SCOPE=<scope>` for that single `mcp_wizard_run` invocation; `--mcp-scope <s>` CLI flag still honored as a non-interactive force-set; `scripts/tests/test-mcp-selector.sh` extended from PASS=21 with TUI-SCOPE-01..05 scenarios.
**Plans**: 3 plans
- [x] 39-01-PLAN.md — MCP_SELECTED_SCOPE state + per-row scope glyph render + Tab dispatcher in tui.sh (TUI-SCOPE-01, TUI-SCOPE-02, TUI-SCOPE-04)
- [x] 39-02-PLAN.md — Repurpose mcp_toggle_scope as set-all + install.sh per-row TK_MCP_SCOPE export + TUI_ROW_KEY/FN wiring (TUI-SCOPE-03, TUI-SCOPE-05)
- [ ] 39-03-PLAN.md — test-mcp-selector.sh ≥5 new assertions for TUI-SCOPE-01..05 (PASS≥26 floor) (TEST-04)
**UI hint**: yes

### Phase 40: Uninstall Secret Cleanup + Calendly + Validator

**Goal**: Close the secrets-leak gap on uninstall — removing a single MCP triggers `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?` (default N, fail-closed N on no-TTY), full toolkit uninstall asks once about the entire `mcp-config.env`, project `.env` files are **never** touched, and `--keep-state` (v4.4 KEEP-01) implies `--keep-secrets`. Add Calendly to the catalog as an official MCP (`developer.calendly.com/calendly-mcp-server`, `default_scope: user`, `requires_oauth: true`); explicitly NOT add a Google Workspace MCP — claude.ai's built-in Gmail/Calendar/Drive connectors already cover that surface (decision logged in PROJECT.md + CHANGELOG). Catalog validator gains a SCOPE-01 assertion alongside the new entry; uninstall test suite extended.
**Depends on**: Phase 36 (Calendly catalog entry needs the `default_scope` schema), Phase 37 (UN-SEC-04 negative assertion proves no `.env` outside `~/.claude/` is opened — needs `project-secrets.sh` to be the only path that writes project `.env`), Phase 38 (uninstall key-cleanup needs to know the same key list the wizard wrote). Can run in parallel with Phase 39 (no shared files).
**Requirements**: UN-SEC-01, UN-SEC-02, UN-SEC-03, UN-SEC-04, UN-SEC-05, INT-13, INT-14, TEST-05, TEST-06
**Success Criteria** (what must be TRUE):
  1. Removing a single MCP via toolkit-driven uninstall path triggers `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?` via `< /dev/tty` (fail-closed N on no-TTY, mirrors v4.3 UN-03); on Y `mcp-config.env` is rewritten without those keys (mode 0600 preserved); on N (default) the keys remain.
  2. Full toolkit uninstall (`scripts/uninstall.sh` whole-toolkit path) prompts ONCE about the entire `~/.claude/mcp-config.env` (`[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?`); on Y the file is deleted before the LAST-step `STATE_FILE` removal (UN-05 D-06 ordering preserved); the v4.3 base-plugin `diff -q` invariant still runs and still wins.
  3. Project `.env` files outside `~/.claude/` are **never** opened or modified by `uninstall.sh` — verified by hermetic filesystem-fingerprint diff in `test-uninstall-state-cleanup.sh`; `--keep-state` (and `TK_UNINSTALL_KEEP_STATE=1`) implies `--keep-secrets` — neither `mcp-config.env` nor any other secret-bearing file is touched; documented in `--help` and `docs/INSTALL.md`.
  4. `integrations-catalog.json` contains a `calendly` MCP entry with `display_name: "Calendly"`, `unofficial: false`, `default_scope: "user"`, `requires_oauth: true`, populated `install_args` per the official MCP server spec, no CLI block; the catalog explicitly does NOT contain any `google-workspace` entry, with the decision logged in PROJECT.md Key Decisions and CHANGELOG `[5.0.0]`.
  5. `scripts/validate-integrations-catalog.py` enforces SCOPE-01 (every MCP has `default_scope` with valid enum) — extends the existing validator, no new file; `scripts/tests/test-uninstall-state-cleanup.sh` extended with UN-SEC-01 / UN-SEC-03 Y/N branches, UN-SEC-04 negative assertion, and UN-SEC-05 `--keep-state` preservation; `test-integrations-catalog.sh` PASS≥10 stays green and gains the SCOPE-01 / Calendly assertions.
**Plans**: TBD
**UI hint**: no

### Phase 41: Distribution + Docs

**Goal**: Ship v5.0 end-to-end — `manifest.json` bumps to 5.0.0 and registers `scripts/lib/project-secrets.sh` under `files.libs[]`, `init-claude.sh --version` / `init-local.sh --version` derive `5.0.0` from manifest at runtime per v4.3 D-22, 3 plugin.json files (`tk-skills`, `tk-commands`, `tk-framework-rules`) bump to `5.0.0` to keep the version-align gate green, and users discover the feature through `docs/INTEGRATIONS.md` Per-MCP Scope section + INSTALL.md flag rows + UNINSTALL.md secret-cleanup section + CHANGELOG `[5.0.0]` consolidated entry. Mirrors the v4.4 / v4.6 / v4.8 / v4.9 close-pattern: tests-first (already shipped in Phases 37–40), then manifest, then docs-last.
**Depends on**: Phases 36 + 37 + 38 + 39 + 40 (schema, lib, dispatch, TUI, uninstall + Calendly must all be present before docs and CHANGELOG can lock the contract).
**Requirements**: DIST-01, DIST-02, DIST-03, DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. `manifest.json` version field shows `5.0.0`, `files.libs[]` registers `scripts/lib/project-secrets.sh`, and `update-claude.sh` auto-discovers the new lib on a stale install via the existing v4.4 LIB-01 D-07 jq path with zero new code; `init-claude.sh --version` and `init-local.sh --version` both print `5.0.0` derived from manifest at runtime; 3 plugin.json files (`tk-skills`, `tk-commands`, `tk-framework-rules`) carry `version: 5.0.0`; `make version-align` green.
  2. `CHANGELOG.md [5.0.0]` is a single consolidated Added / Changed / Removed entry per v4.4 / v4.6 / v4.8 / v4.9 convention, covering SCOPE-01..03, TUI-SCOPE-01..05, SEC-01..06, DISP-01..04, UN-SEC-01..05, INT-13..14, plus the v4.9 → v5.0 rationale (per-row scope was originally a v4.9 follow-up but grew enough to warrant a major bump because it changes the secrets-handling boundary).
  3. `docs/INTEGRATIONS.md` gains a "Per-MCP Scope" section documenting the `[U]`/`[P]`/`[L]` semantics, where each scope's secrets live (`mcp-config.env` vs `<project>/.env`), the `${VAR}` substitution convention in `.mcp.json`, the `.gitignore` guard, and worked examples for both user-scope and project-scope flows.
  4. `docs/INSTALL.md` `## Installer Flags` table gains rows for any new CLI flags emerging from planning (e.g., `--mcp-scope=user|project`); README "Killer Features" grid mentions per-MCP scope control as a v5.0 highlight; `docs/UNINSTALL.md` (or the existing uninstall section in INSTALL.md) documents the new secret-cleanup prompts (per-MCP `mcp-config.env` and full-toolkit) and the explicit "project `.env` never touched" contract.
  5. `make check` green; CI `validate-templates` green; v4.6 BACKCOMPAT-01 invariant holds (`init-claude.sh` URL byte-identical, `test-bootstrap.sh` PASS=26 unchanged, `test-install-tui.sh` PASS=43 unchanged); ready to tag `v5.0.0`.
**Plans**: TBD
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
| v4.9 Integrations Catalog | 32–35 | 14/14 | ✅ Shipped | 2026-05-02 |
| v5.0 Per-MCP Scope + Project Secrets Boundary | 36–41 | 0/22 (planned) | 🚧 Active | TBD |

## v5.0 Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 36. Catalog Schema + Backward Compat | 2/2 | Complete   | 2026-05-04 |
| 37. Project Secrets Library | 2/2 | Complete   | 2026-05-05 |
| 38. Wizard Dispatch Integration | 3/3 | Complete   | 2026-05-05 |
| 39. TUI Per-Row Scope Toggle | 2/3 | In Progress|  |
| 40. Uninstall Secret Cleanup + Calendly + Validator | 0/5 | Not started | - |
| 41. Distribution + Docs | 0/3 | Not started | - |
