---
phase: 41-distribution-docs
plan: single-pass
subsystem: distribution
tags: [release, manifest, plugin.json, version-align, changelog, docs, integrations, install, uninstall, killer-features]

# Dependency graph
requires:
  - phase: 36-catalog-schema-backward-compat
    provides: SCOPE-01..03 default_scope schema + validator + backward-compat fallback
  - phase: 37-project-secrets-library
    provides: SEC-01..06 project-secrets.sh lib + literal-secret refusal contract (registered under manifest.libs[])
  - phase: 38-wizard-dispatch-integration
    provides: DISP-01..04 mcp_wizard_run scope routing + 4-tuple defer-secrets queue + summary printer
  - phase: 39-tui-per-row-scope-toggle
    provides: TUI-SCOPE-01..05 per-row indicator/hotkey/dispatcher + --mcp-scope CLI flag
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: UN-SEC-01..05 uninstall secret cleanup + INT-13 Calendly + INT-14 Google Workspace lock-out
provides:
  - "manifest.json v5.0.0 (4.9.0 → 5.0.0; updated 2026-05-06). project-secrets.sh registration confirmed under files.libs[] (alpha-ordered between optional-plugins.sh and skills.sh; landed during Phase 37 — Phase 41 verified, no edit needed)"
  - "3 plugin.json files (tk-skills, tk-commands, tk-framework-rules) bumped 4.8.0 → 5.0.0"
  - "init-claude.sh --version + init-local.sh --version both print 'claude-code-toolkit v5.0.0' (derived from manifest at runtime per v4.3 D-22)"
  - "make version-align green: manifest 5.0.0 == CHANGELOG 5.0.0 == init-local --version 5.0.0"
  - "CHANGELOG.md [5.0.0] consolidated release entry (256 insertions): SCOPE-01..03, SEC-01..06, DISP-01..04, TUI-SCOPE-01..05, UN-SEC-01..05, INT-13/14, plus v4.9 → v5.0 rationale paragraph and Phase 36-A polish carry-over"
  - "docs/INTEGRATIONS.md Per-MCP Scope section (~120 lines): [U]/[P]/[L] semantics, scope-vs-secrets-location table, TUI hotkeys (Tab per-row, s set-all), ${VAR} substitution convention, .gitignore guard, Context7 user-scope worked example, Supabase project-scope worked example, project .env never-touched cross-link to INSTALL.md#uninstall"
  - "docs/INTEGRATIONS.md catalog count bumped 20 → 21; Calendly added to Workspace category table (HTTP transport https://mcp.calendly.com/, OAuth DCR, official, user scope)"
  - "docs/INSTALL.md Installer Flags table: --mcp-scope=<scope> row added (rc=2 on invalid, wins over default_scope and per-row toggle)"
  - "docs/INSTALL.md new ## Uninstall section: per-MCP [y/N] cleanup prompt, full-toolkit [y/N] cleanup prompt, project .env NEVER touched contract (UN-SEC-04), --keep-state implies --keep-secrets (UN-SEC-05), uninstall flags table"
  - "README.md Killer Features grid: bumped Integrations Catalog count 20 → 21 (Calendly add); new 'Per-MCP Scope (v5.0)' row cross-linking to INTEGRATIONS.md#per-mcp-scope"
affects:
  - "v5.0.0 release tag eligibility — all 6 phases of the v5.0 milestone now closed; ready to tag once user signs off"
  - "Future Phase 41+: when v5.1 / v5.x phases land, the [Unreleased] header in CHANGELOG is now a clean anchor (post-fold) for the next consolidated entry"

# Tech tracking
tech-stack:
  added: []  # Pure release pass — no new external dependencies, no new scripts, no new tests.
  patterns:
    - "v4.x close-pattern preserved: tests-first (Phases 37-40), then manifest, then docs-last. Mirrors v4.4 / v4.6 / v4.8 / v4.9 close cadence."
    - "Single-pass execution per orchestrator decision (no per-task plans, no code-review, no verifier). Three commits group by concern: (1) manifest+plugins, (2) CHANGELOG, (3) docs."
    - "Conventional Commits: feat(41) for content (manifest+plugins), docs(41) for docs (CHANGELOG, INTEGRATIONS, INSTALL, README)."
    - "Markdownlint MD004 false-positive on continuation-line `+ ` was caught before commit and reworded to `plus` — keeps `make mdlint` green without disabling the rule."

key-files:
  created:
    - ".planning/phases/41-distribution-docs/41-SUMMARY.md (this file)"
  modified:
    - "manifest.json — version 4.9.0 → 5.0.0; updated 2026-05-02 → 2026-05-06. project-secrets.sh registration confirmed (no edit; landed during Phase 37)."
    - "plugins/tk-skills/.claude-plugin/plugin.json — version 4.8.0 → 5.0.0"
    - "plugins/tk-commands/.claude-plugin/plugin.json — version 4.8.0 → 5.0.0"
    - "plugins/tk-framework-rules/.claude-plugin/plugin.json — version 4.8.0 → 5.0.0"
    - "CHANGELOG.md — folded prior [Unreleased] (Phase 36-A polish: global scope toggle, install transcript polish, BSD mktemp fix) into [5.0.0] under 'Carry-over from v4.9 close'; +256 lines / -99 lines"
    - "docs/INTEGRATIONS.md — bumped 20 → 21 entries; added Calendly to Workspace category table; new ~120-line Per-MCP Scope section between OAuth setup and Global vs per-project"
    - "docs/INSTALL.md — added --mcp-scope=<scope> Installer Flags row; new ## Uninstall section before Translation Sync Cell"
    - "README.md — Killer Features grid: bumped 20 → 21 in Integrations Catalog row; added new 'Per-MCP Scope (v5.0)' row"

key-decisions:
  - "Phase 41 executed as a single-pass orchestrator decision: no per-task plans authored, no code-review/verifier spawned. All decisions inline in the user prompt; SCOPE/DOCS scope explicit. Mirrors the v4.x release-close pattern."
  - "manifest.json project-secrets.sh registration was already present (Phase 37-01 commit 0b0544f registered it under files.libs[] during the lib's birth). Phase 41's role here is verification only — no edit needed."
  - "init-claude.sh and init-local.sh --version derive from manifest at runtime per v4.3 D-22 — bumping manifest is sufficient, no script edits. Confirmed both print v5.0.0 after the manifest commit."
  - "[Unreleased] section folded entirely into [5.0.0]. The Phase 36-A polish (global scope toggle, install transcript polish, BSD mktemp fix, mcp-wizard sequential-thinking → playwright swap, GitHub Actions checkout v4 → v6.0.2 bump) was authored on the v4.9 release branch but never shipped — it ships as part of v5.0 under a 'Carry-over from v4.9 close' subsection. Empty [Unreleased] header retained as anchor for future v5.x entries."
  - "v4.9 → v5.0 major bump rationale paragraph included verbatim per user prompt: per-row scope was originally a v4.9 follow-up but grew enough to warrant a major bump because it changes the secrets-handling boundary (project secrets in <project>/.env instead of mcp-config.env, defense-in-depth literal-secret refusal, per-MCP user/project/local routing)."
  - "Calendly catalog table row uses HTTP transport `https://mcp.calendly.com/` (matches install_args in the catalog) instead of an `@calendly/mcp-server` npm package name — Calendly's MCP is HTTP-only, not stdio-over-npm. Auth column reads 'OAuth DCR (browser)' to surface the dynamic-client-registration flow."
  - "INT-14 (Google Workspace lock-out) made explicit in CHANGELOG ### Removed section. Decision was already in PROJECT.md and REQUIREMENTS.md but had no user-facing surface until this release entry."
  - "README.md highlight kept short (one row in the Killer Features table) and cross-links to docs/INTEGRATIONS.md#per-mcp-scope for the deep dive. Avoids duplicating prose."
  - "docs/INSTALL.md ## Uninstall section is brand-new (the file did not previously have a centralized uninstall section, only individual --keep-state notes). Created here per DOCS-03; serves as the user-facing surface for the entire UN-SEC-01..05 contract chain. Cross-linked from INTEGRATIONS.md#per-mcp-scope worked examples."
  - "MD004 false-positive on a `+ ` mid-paragraph (line 236 of CHANGELOG, continuation of an existing `-` list item) caught by markdownlint pre-commit. Reworded to `plus` — keeps the rule enabled without disabling-comment overhead."

patterns-established:
  - "v5.x release-close template: (1) bump manifest + plugin.json files, (2) fold [Unreleased] into the new release header in CHANGELOG with consolidated Added/Changed/Removed sections, (3) update docs (INTEGRATIONS for catalog/feature deep-dive, INSTALL for flags + uninstall, README for one-line highlight), (4) run make check + make version-align + targeted regression suites, (5) write SUMMARY + update STATE/REQUIREMENTS, (6) final metadata commit. No per-task plans needed for a release-close phase."
  - "Catalog count bump propagation: when a catalog entry lands (Phase 40 added Calendly: 20 → 21), it must be reflected in (a) docs/INTEGRATIONS.md heading, (b) docs/INTEGRATIONS.md per-category table, (c) README.md Killer Features grid, (d) test-mcp-selector.sh magic number (Phase 40-04 commit 0f45ddc handled the test side; Phase 41 closes the docs side)."

requirements-completed: [DIST-01, DIST-02, DIST-03, DOCS-01, DOCS-02, DOCS-03]

# Metrics
duration: ~25min
completed: 2026-05-06
---

# Phase 41: Distribution + Docs (Single-Pass)

**Final close phase of the v5.0 milestone — bumps manifest + 3 plugin.json files to 5.0.0, lands the consolidated CHANGELOG `[5.0.0]` entry covering all v5.0 requirement IDs (SCOPE/SEC/DISP/TUI-SCOPE/UN-SEC/INT), and ships user-facing docs: a deep-dive Per-MCP Scope section in INTEGRATIONS.md (with Context7 user-scope and Supabase project-scope worked examples), a brand-new Uninstall section in INSTALL.md (per-MCP + full-toolkit secret-cleanup prompts, project .env never-touched contract, --keep-state implies --keep-secrets), and a README Killer Features highlight cross-linking the new INTEGRATIONS.md section.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-06T08:00 (Phase 41 single-pass execution)
- **Completed:** 2026-05-06
- **Tasks:** 3 commits (manifest+plugins, CHANGELOG, docs)
- **Files modified:** 8 (manifest.json, 3 plugin.json, CHANGELOG.md, docs/INTEGRATIONS.md, docs/INSTALL.md, README.md)

## Accomplishments

### DIST-01: manifest.json bump + project-secrets.sh registration

- `manifest.json` `version` 4.9.0 → 5.0.0; `updated` 2026-05-02 → 2026-05-06.
- `scripts/lib/project-secrets.sh` already registered under `files.libs[]` from Phase 37-01 (commit `0b0544f`) — alpha-ordered between `optional-plugins.sh` and `skills.sh`. Phase 41 verified this; no edit needed.
- `update-claude.sh` auto-discovers the new lib via the existing v4.4 LIB-01 D-07 jq path — zero code changes to `update-claude.sh`.

### DIST-02: version-align across init scripts + 3 plugin.json files

- `init-claude.sh --version` and `init-local.sh --version` both print `claude-code-toolkit v5.0.0` (derived from manifest at runtime per v4.3 D-22).
- `plugins/tk-skills/.claude-plugin/plugin.json` — 4.8.0 → 5.0.0.
- `plugins/tk-commands/.claude-plugin/plugin.json` — 4.8.0 → 5.0.0.
- `plugins/tk-framework-rules/.claude-plugin/plugin.json` — 4.8.0 → 5.0.0.
- `make version-align` green: `manifest.json 5.0.0 == CHANGELOG.md 5.0.0 == init-local.sh --version 5.0.0`.

### DIST-03: CHANGELOG [5.0.0] consolidated entry

Single `## [5.0.0] - 2026-05-06` release section covering every v5.0 requirement ID:

- **v4.9 → v5.0 rationale paragraph** — explains why this milestone shipped as a major bump despite originating as a v4.9 follow-up: it changes the secrets-handling boundary itself (project secrets in `<project>/.env` instead of `mcp-config.env`, defense-in-depth literal-secret refusal, per-MCP user/project/local routing).
- **Added — Catalog schema** — SCOPE-01 (`default_scope` field), SCOPE-02 (per-MCP defaults grid), SCOPE-03 (silent fallback in `mcp_catalog_load`).
- **Added — Project secrets library** — SEC-01..06 (lib API, idempotent merge prompt, `.gitignore` guard, `${VAR}` renderer, defense-in-depth literal-secret refusal, metacharacter rejection, `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam).
- **Added — Wizard dispatch integration** — DISP-01 (project-scope branch), DISP-02 (user-scope no-regression), DISP-03 (defer-secrets path + 4-field queue tuple), DISP-04 (post-install summary printer).
- **Added — TUI per-row scope toggle** — TUI-SCOPE-01 (per-row indicator), TUI-SCOPE-02 (per-row hotkey), TUI-SCOPE-03 (`s` repurposed as set-all), TUI-SCOPE-04 (`MCP_SELECTED_SCOPE[]` parallel array), TUI-SCOPE-05 (per-row dispatch), `--mcp-scope=<scope>` CLI flag.
- **Added — Uninstall secret cleanup** — UN-SEC-01 (per-MCP `[y/N]` prompt + atomic 0600-preserving rewrite), UN-SEC-02 (post-`claude mcp remove` invocation), UN-SEC-03 (full-toolkit `[y/N]` prompt with D-06 ordering preservation), UN-SEC-04 (project `.env` never touched contract), UN-SEC-05 (`--keep-state` implies `--keep-secrets`).
- **Added — Calendly MCP** — INT-13 (Calendly catalog entry, HTTP transport, OAuth DCR, official, user scope, count 20 → 21).
- **Removed — Google Workspace MCP locked out** — INT-14 (decision logged: claude.ai connectors cover the surface).
- **Added — Distribution + docs** — DIST-01/02 (manifest + plugin bumps + version-align), DOCS-01/02/03 (this very phase's docs deliverables).
- **Carry-over from v4.9 close (Phase 36-A polish)** — install↔reinstall toggle, install transcript polish, BSD mktemp fix, `test-mcp-wizard.sh` swap (sequential-thinking → playwright), GitHub Actions `actions/checkout` v4 → v6.0.2.
- **Migration** subsection — covers re-running `update-claude.sh` to pick up the new lib via auto-discovery, backward-compat fallback (SCOPE-03), how to migrate an existing user-scope MCP to project-scope, and explicit out-of-scope items (encrypt at rest, auto-rotate, Windows-native scope semantics).

### DOCS-01: docs/INTEGRATIONS.md Per-MCP Scope section

New ~120-line section between "OAuth / auth setup" and "Global vs per-project":

- **Indicator/scope/keys-location/`claude mcp add`-flag/use-case table** — `[U]`, `[P]`, `[L]` semantics in one shot.
- **Defaults** — explicit per-MCP grid (personal-tooling defaults `user`; per-app infra defaults `project`).
- **TUI hotkeys table** — `Tab` (or `Shift-S`) for per-row, `s` for set-all, `Space` independent of scope indicator.
- **Project scope: where the secrets land** — 4-step deep-dive (hidden-input prompt, `project_secrets_write_env` writes to `<project>/.env` mode 0600, `project_secrets_ensure_gitignore` appends with leading toolkit comment, `claude mcp add --scope project` with `${VAR}` substitution form). Documents the SEC-05 defense-in-depth refusal regex `^\$\{[A-Z_][A-Z0-9_]*\}$`.
- **`${VAR}` substitution in `.mcp.json`** — full JSON example showing the `env` block shape; explains why `.mcp.json` lives in the repo and must never carry literal secrets.
- **Worked example: user scope (Context7)** — 7-step walkthrough from `--integrations` invocation to `mcp-config.env` write to shell rc auto-source.
- **Worked example: project scope (Supabase)** — 8-step walkthrough including the `Tab` flip option, `<project>/.env` write, `.gitignore` append, `.mcp.json` env block shape, and `direnv` / `dotenv` integration hint.
- **Project `.env` is never touched by uninstall** — short cross-link to INSTALL.md#uninstall for the full contract.

Also bumped catalog count "20 MCP servers" → "21 MCP servers" in the heading and added Calendly to the Workspace category table (`HTTP https://mcp.calendly.com/`, `OAuth DCR (browser)`, `official; user scope`).

### DOCS-02: docs/INSTALL.md flag row + README highlight

- **`--mcp-scope=<scope>` row** added to the Installer Flags table (between `--cli-only` and `--break-bridge`). Documents accepted values (`user`, `project`, `local`), rc=2 on invalid, "wins over `default_scope` and per-row TUI hotkey" semantics, and a cross-link to INTEGRATIONS.md.
- **README.md "Killer Features" grid** — bumped Integrations Catalog count "20" → "21" (Calendly), and added a new row: `**Per-MCP Scope (v5.0)** | Per-row scope toggle in the integrations TUI: [U] user / [P] project / [L] local. Project-scope writes secrets to <project>/.env (mode 0600) with auto-.gitignore guard; .mcp.json carries only ${VAR} substitution form. --mcp-scope=<scope> for non-interactive force-set.`. Cross-link to INTEGRATIONS.md#per-mcp-scope.

### DOCS-03: docs/INSTALL.md Uninstall section

Brand-new `## Uninstall` section before "Translation Sync Cell":

- **Top-level usage** — curl-pipe and local-clone invocations, v4.3 UN-01..UN-08 invariant recap (full backup, sentinel strip, base-plugin `diff -q` invariant).
- **Secret cleanup (v5.0+) — Per-MCP cleanup prompt** — `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?`; Y triggers atomic mode-0600-preserving rewrite that drops only the named MCP's keys (other entries byte-identical); N (default + fail-closed on no-TTY) preserves them.
- **Secret cleanup — Full-toolkit cleanup prompt** — `[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?`; Y deletes the file BEFORE the LAST-step `STATE_FILE` removal (UN-05 D-06 ordering preserved); N preserves.
- **Project `.env` files NEVER touched** — explicit contract; verified by hermetic filesystem-fingerprint diff in `test-uninstall-state-cleanup.sh` (UN-SEC-04).
- **`--keep-state` implies `--keep-secrets`** — preserves both `toolkit-install.json` AND all secret-bearing files; per-MCP cleanup helper skipped entirely; full-toolkit prompt does not fire (logs `mcp-config.env preserved (--keep-state): <path>` instead).
- **Uninstall flags table** — `--dry-run`, `--keep-state` (with v5.0+ "implies `--keep-secrets`" annotation), `--no-banner`, `--help`.

## Task Commits

Three task commits group by concern (single-pass per orchestrator decision):

1. **manifest + plugins** — `eeb2058` `feat(41): bump manifest + 3 plugin.json files to v5.0.0 (DIST-01/02)`. Files: `manifest.json`, `plugins/tk-skills/.claude-plugin/plugin.json`, `plugins/tk-commands/.claude-plugin/plugin.json`, `plugins/tk-framework-rules/.claude-plugin/plugin.json`.
2. **CHANGELOG** — `4303fd5` `docs(41): add CHANGELOG [5.0.0] consolidated entry (DIST-03)`. Files: `CHANGELOG.md` (+256 / -99).
3. **Docs** — `a76bfd2` `docs(41): add Per-MCP Scope + Uninstall sections + README highlight (DOCS-01/02/03)`. Files: `docs/INTEGRATIONS.md`, `docs/INSTALL.md`, `README.md`, `CHANGELOG.md` (MD004 fix).

(Final metadata commit lands after this SUMMARY is written.)

## Files Created/Modified

| File | Change |
|------|--------|
| `manifest.json` | version 4.9.0 → 5.0.0; updated 2026-05-02 → 2026-05-06 |
| `plugins/tk-skills/.claude-plugin/plugin.json` | version 4.8.0 → 5.0.0 |
| `plugins/tk-commands/.claude-plugin/plugin.json` | version 4.8.0 → 5.0.0 |
| `plugins/tk-framework-rules/.claude-plugin/plugin.json` | version 4.8.0 → 5.0.0 |
| `CHANGELOG.md` | folded prior [Unreleased] (Phase 36-A polish) into new [5.0.0] release entry under "Carry-over from v4.9 close"; added v4.9 → v5.0 rationale + Added/Changed/Removed/Migration subsections covering all 37 v5.0 REQ-IDs (+256 / -99 lines) |
| `docs/INTEGRATIONS.md` | new ~120-line "Per-MCP scope" section between OAuth setup and Global vs per-project; bumped catalog count 20 → 21 and added Calendly Workspace row |
| `docs/INSTALL.md` | added `--mcp-scope=<scope>` Installer Flags table row; new ## Uninstall section before Translation Sync Cell |
| `README.md` | bumped Integrations Catalog count 20 → 21; new "Per-MCP Scope (v5.0)" Killer Features row |
| `.planning/phases/41-distribution-docs/41-SUMMARY.md` | this file (created) |

## Decisions Made

See `key-decisions:` in the frontmatter for the full list. Highlights:

- **Single-pass orchestrator execution** — no per-task plans, no code-review, no verifier. Three commits group by concern. Mirrors the v4.4/v4.6/v4.8/v4.9 release-close cadence.
- **manifest.json `project-secrets.sh` registration was a no-op** — already landed during Phase 37-01 (commit `0b0544f`). Phase 41's role here is verification only.
- **init scripts derive version from manifest at runtime** per v4.3 D-22 — no script edits needed; bumping the manifest is sufficient.
- **[Unreleased] folded entirely into [5.0.0]** — the Phase 36-A polish (global scope toggle, install transcript polish, BSD mktemp fix, etc.) ships as part of v5.0 under "Carry-over from v4.9 close" subsection. Empty [Unreleased] header retained as anchor.
- **v4.9 → v5.0 major bump rationale** included verbatim in the CHANGELOG (per user prompt).
- **Calendly catalog table row uses HTTP transport** (`https://mcp.calendly.com/`) instead of an npm package — Calendly's MCP is HTTP-only, not stdio-over-npm.
- **INT-14 made user-facing** in the CHANGELOG ### Removed section (was internal-only in PROJECT.md / REQUIREMENTS.md).
- **README.md highlight** kept short (one row in the Killer Features table) and cross-links to INTEGRATIONS.md for the deep-dive — avoids prose duplication.
- **docs/INSTALL.md ## Uninstall section is brand-new** — the file did not previously have a centralized uninstall section, only individual `--keep-state` notes. Created here per DOCS-03; serves as the single user-facing surface for the entire UN-SEC-01..05 contract chain.
- **MD004 false-positive on `+ ` continuation line** caught by markdownlint pre-commit; reworded to `plus`. Keeps the rule enabled without disabling-comment overhead.

## Deviations from Plan

None — plan executed exactly as written by the orchestrator. Three minor in-flight micro-adjustments (none rise to deviation status):

1. **Calendly catalog row package name** — initial draft used `@calendly/mcp-server` (a guess). Corrected to `HTTP https://mcp.calendly.com/` after reading the actual `install_args` from `scripts/lib/integrations-catalog.json`. Documentation accuracy fix, caught before commit.
2. **MD004 false-positive on continuation `+ `** — caught by `npx markdownlint-cli` after the docs commit was drafted. Reworded `+ "To remove an MCP"` to `plus "To remove an MCP"`. Same edit committed alongside the docs commit (a76bfd2).
3. **PreToolUse:Edit READ-BEFORE-EDIT advisory reminders** fired multiple times despite having Read all relevant files at the top of the session. The runtime accepted all edits successfully — the reminders are advisory.

## Issues Encountered

None on the implementation side. All quality gates green on first or second attempt:

- `bash -n` clean across all touched files
- `make shellcheck` ✅ ShellCheck passed
- `make mdlint` ✅ Markdownlint passed (after MD004 fix)
- `make version-align` ✅ Version aligned: 5.0.0
- `make validate` ✅ All templates valid
- `make check` exit 0 ("All checks passed!")

### Test-suite regression check (CONTEXT D-18 baseline + BACKCOMPAT-01)

| Suite | Expected baseline | Result | Status |
|-------|-------------------|--------|--------|
| `test-bootstrap.sh` | PASS=26 (BACKCOMPAT-01 floor) | PASS=26 FAIL=0 | ✓ |
| `test-install-tui.sh` | PASS=43 (BACKCOMPAT-01 floor) | PASS=58 FAIL=0 | ✓ (suite has grown, no failures) |
| `test-mcp-selector.sh` | PASS=36 | PASS=36 FAIL=0 | ✓ |
| `test-mcp-wizard.sh` | PASS=53 | PASS=53 FAIL=0 | ✓ |
| `test-uninstall-state-cleanup.sh` | 17 assertions | 17 passed | ✓ |
| `test-project-secrets.sh` | PASS=42 | PASS=42 FAIL=0 | ✓ |
| `test-integrations-catalog.sh` | PASS=20 | PASS=20 FAIL=0 | ✓ |
| `make check` | exit 0 | exit 0 | ✓ |
| `make version-align` | green | green at 5.0.0 | ✓ |

No regressions caused by Phase 41. BACKCOMPAT-01 invariant holds: `init-claude.sh` URL byte-identical (no script edits in this phase), test-bootstrap PASS=26 unchanged, test-install-tui floor 43 met (actually PASS=58 due to suite growth across v5.0 phases).

## User Setup Required

None — pure release pass. No new credentials, no new infrastructure, no migration steps for existing users (re-running `update-claude.sh` picks up the new `project-secrets.sh` lib via the v4.4 LIB-01 D-07 auto-discovery path; backward-compat fallback SCOPE-03 ensures pre-v5.0 catalogs continue to work).

## Verification Battery

- `bash -n manifest.json plugin.json files` — N/A (JSON, not Bash). All three plugin.json files pass `jq -e .` and `python3 -c 'import json; json.load(open(...))'` implicitly via `make check`.
- `make shellcheck` → PASS (✅ ShellCheck passed).
- `make mdlint` → PASS (✅ Markdownlint passed).
- `make version-align` → PASS (✅ Version aligned: 5.0.0).
- `make validate` → PASS (✅ All templates valid; ✅ Manifest schema valid; ✅ Version aligned: 5.0.0).
- `make check` → exit 0 ("All checks passed!").
- `bash scripts/init-local.sh --version` → `claude-code-toolkit v5.0.0 (local)`.
- `bash scripts/init-claude.sh --version` → `claude-code-toolkit v5.0.0`.
- `grep '"version"' plugins/*/.claude-plugin/plugin.json` → all 3 show `"5.0.0"`.
- `grep -m1 '^## \[' CHANGELOG.md` → first hit is `## [Unreleased]`; second is `## [5.0.0] - 2026-05-06`; third is `## [4.9.0] - 2026-05-02`. Order correct.
- `npx --yes markdownlint-cli docs/INTEGRATIONS.md docs/INSTALL.md README.md CHANGELOG.md` → ok (no errors).
- `bash scripts/uninstall.sh --help | grep -q 'Project .env files are NEVER touched'` → PASS (UN-SEC-04 contract surfaced from --help; same string now repeated in docs/INSTALL.md ## Uninstall section).

## Next Phase Readiness

- **v5.0 milestone is complete** — all 6 phases (36..41) closed. All 37 REQ-IDs in REQUIREMENTS.md mapped to commits.
- **Ready to tag `v5.0.0`** — once user signs off. Toolkit's "never push main / never auto-tag" invariant means the tag is a manual user step.
- **CHANGELOG `[Unreleased]` section** retained as empty anchor for the next v5.x consolidated entry.
- **No deferred items added by Phase 41** — all v5.0 deferred items (SCOPE-FUT-01/02, SEC-FUT-01/02, INT-FUT-01/03/04/05/06, BRIDGE-FUT-01..05) carried over from v4.9 close are documented in REQUIREMENTS.md ## Future Requirements / ## Out of Scope.
- **Future v5.1+ phases** can use this SUMMARY's `patterns-established:` "v5.x release-close template" as the standard six-step playbook (manifest bump → CHANGELOG fold → docs → quality gates → SUMMARY → metadata commit).

---
*Phase: 41-distribution-docs*
*Completed: 2026-05-06*

## Self-Check: PASSED

- File `.planning/phases/41-distribution-docs/41-SUMMARY.md` exists: ✓
- Commit `eeb2058` (Task 1: manifest + plugins) present in git log: ✓
- Commit `4303fd5` (Task 2: CHANGELOG) present in git log: ✓
- Commit `a76bfd2` (Task 3: docs) present in git log: ✓
- `manifest.json` "version": "5.0.0": ✓
- 3 plugin.json files all show "version": "5.0.0": ✓
- `init-claude.sh --version` and `init-local.sh --version` print v5.0.0: ✓
- `make version-align` green at 5.0.0: ✓
- `make check` exit 0: ✓
- `make mdlint` green: ✓
- `make shellcheck` green: ✓
- BACKCOMPAT-01: `init-claude.sh` REPO_URL byte-identical (no script edits this phase): ✓
- BACKCOMPAT-01: test-bootstrap PASS=26 unchanged: ✓
- BACKCOMPAT-01: test-install-tui PASS=58 ≥ floor 43, no failures: ✓
- All targeted regression tests green (mcp-selector 36, mcp-wizard 53, uninstall-state-cleanup 17, project-secrets 42, integrations-catalog 20): ✓
- CHANGELOG [5.0.0] entry covers all 6 requirement categories (SCOPE/SEC/DISP/TUI-SCOPE/UN-SEC/INT) plus DIST/DOCS: ✓
- docs/INTEGRATIONS.md Per-MCP Scope section present with both worked examples (Context7 + Supabase): ✓
- docs/INSTALL.md `--mcp-scope` flag row + Uninstall section present: ✓
- README "Killer Features" mentions per-MCP scope as v5.0 highlight: ✓
- No threat flags introduced (no new code, all docs + version metadata): ✓
- No stubs introduced: ✓ (pure release pass)
