# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [6.0.0] - 2026-05-06

**Three-layer overlay redesign — TK on top of `superpowers` + `get-shit-done`,
plus optional external tools.**

### Added

- **Advisory hooks** (PR #43) — four opt-in Claude Code hooks under
  `templates/global/hooks/` that nudge toward the right tool at the right phase
  without ever blocking:
  - `tk-pre-gsd-plan-council.sh` (UserPromptSubmit) — suggests `/council` when
    `/gsd-plan-phase` touches auth/payments/security/db-migration keywords.
  - `tk-post-gsd-phase-audit.sh` (Stop) — suggests `/audit security && /audit code`
    after `/gsd-execute-phase` completes.
  - `tk-pre-ship-reality-check.sh` (PreToolUse Bash) — reminds reality-check
    skill before push to main / vercel/netlify/fly/kubectl deploy.
  - `tk-cost-warning.sh` (Stop) — once per session when transcript suggests
    >`TK_COST_WARN_KTOK` (default 200k) tokens consumed.
  - Installer at `scripts/install-hooks.sh` with atomic JSON merge,
    `_tk_owned + _tk_hook_id` markers, `--dry-run`, `--uninstall`.
- **Cost routing** (PR #45) — `scripts/setup-cost-routing.sh` wraps
  `npx -y better-model init` to route Sonnet 4.6 (60% of tasks), Opus 4.7
  (architecture/security), Haiku 4.5 (search/trivial) per slash command.
  Backup + restore on failure; `--uninstall` strips the routing block cleanly.
- **External MCPs in integrations catalog** (PR #45):
  - `morph-fast-tools` (dev-tools) — Fast Apply diffs + warpgrep_codebase_search.
  - `claude-context` (dev-tools) — vector-DB code search via Milvus + OpenAI/Voyage.
  - Catalog grows 21 → 23 entries.
- **New skills** (PR #42) under `templates/base/skills/`:
  - `production-observability`, `reality-check`, `cost-routing-discipline`,
    `gsd-mode-selector`, `domain-expert-simulation`.
- **New rules** (PR #42) auto-loaded every session:
  - `cost-discipline.md`, `non-programmer-safeguards.md`, `three-layer-bridge.md`.
- **New components** (PR #42) — `production-observability`, `cost-discipline`,
  `vendor-risk`, `domain-expert-simulation`, `large-codebase-search`,
  `external-tools-recommended`.
- **`/vendor-audit` slash command** (PR #42) — quarterly external dependency
  risk review (GSD, Superpowers, Morph, better-model, claude-context).
- **Architecture docs** (PR #46) — `docs/architecture.md` (three-layer
  diagram + runtime composition matrix); `docs/non-programmer-mode.md`
  (recommended setup + cost expectations for solo founders).

### Changed

- **Trimmed duplicates with GSD/Superpowers** (PR #41) — removed 26 commands,
  9 components, 2 base skills (testing + debugging — covered by Superpowers
  TDD + systematic-debugging), 2 templates (nextjs covered by GSD
  skills-marketplace; nodejs merged into base). Net deletion: ~28k LOC.
- **Trimmed framework templates** (PR #44) — removed 32 framework template
  files (byte-identical to base or stale copies). Each of
  `templates/{laravel,rails,python,go}/` shrinks 23-25 → 16 files.
  `init-claude.sh` framework→base fallback chain handles the missing files.
  -8.7k LOC.

### Migration

Existing v5.x users on `complement-sp` / `complement-full` will see hard-
deleted files vanish on next `/update-toolkit` — intended. Run
`scripts/migrate-to-complement.sh` if you were on `standalone` and now have
SP+GSD installed; otherwise no manual migration. `install-hooks.sh` and
`setup-cost-routing.sh` are opt-in and never auto-run.

## [5.0.0] - 2026-05-06

**Per-MCP Scope + Project Secrets Boundary** — give the user granular per-MCP
scope control (`user` vs `project`) with sensible per-MCP defaults baked into
the catalog, treat secrets correctly per scope (`~/.claude/mcp-config.env` for
user-scope, `<project>/.env` + `${VAR}` substitution in `.mcp.json` for
project-scope, never literal secrets in shared files), close the secrets-leak
gap on uninstall (per-MCP keys + full-toolkit `mcp-config.env` cleanup
prompts; project `.env` files never touched), add Calendly to the catalog,
and explicitly NOT add a Google Workspace MCP — claude.ai's built-in
Gmail/Calendar/Drive connectors already cover that surface.

### v4.9 → v5.0 rationale

Per-row MCP scope was originally a v4.9 follow-up — the v4.9 close shipped a
single global `s` toggle (commit `fc000d5`, Phase 37) that flipped scope for
the whole picker at once. User testing surfaced the friction: solo
developers want a personal-tooling MCP (`context7`, `notebooklm`) installed
once on their machine and a per-app infra MCP (`supabase`, `stripe`) wired
into a single project's repo. One global flip makes the second case noisy.

The v5.0 release reframes the global toggle as a "set all" convenience and
adds per-row indicators (`[U]`/`[P]`/`[L]`) plus a per-row hotkey. The
implementation grew enough to warrant a major bump because it changes the
secrets-handling boundary itself: user-scope keys still live in
`~/.claude/mcp-config.env` (mode 0600), but project-scope writes land in
`<project>/.env` (mode 0600, with `.gitignore` guard) while `.mcp.json`
inside the repo carries only `${VAR}` substitution form — never literal
values. Defense-in-depth: a literal-secret refusal regex (`^\$\{[A-Z_][A-Z0-9_]*\}$`)
guards every code path that writes to `.mcp.json`. Uninstall gains paired
`[y/N]` cleanup prompts for residual secrets; project `.env` files are
**never** touched by `uninstall.sh`. The v4.9 behavior remains the
default for users who never reach for the per-row toggle.

### Added — Catalog schema: `default_scope` (Phase 36)

- **`default_scope: "user"|"project"` field** on every `components.mcp.<name>`
  block in `scripts/lib/integrations-catalog.json` (SCOPE-01). Personal-tooling
  MCPs default `user`: `firecrawl`, `notebooklm`, `notion`, `youtrack`,
  `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`,
  `calendly`. Per-app infra MCPs default `project`: `supabase`, `cloudflare`,
  `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`,
  `jira`, `linear`, `telegram` (SCOPE-02).
- **Validator enforcement** — `scripts/validate-integrations-catalog.py` fails
  when any MCP entry omits `default_scope` or carries an invalid enum value;
  wired into `make validate-catalog` and the `make check` quality gate.
- **Backward-compat fallback** — `mcp_catalog_load` in `scripts/lib/mcp.sh`
  silently treats absence as `user` (SCOPE-03). Pre-v5.0 catalogs and
  pre-v5.0 user installs continue to work without warnings.

### Added — Project secrets library `scripts/lib/project-secrets.sh` (Phase 37)

New library owns the project-scope secrets boundary end-to-end:

- **`project_secrets_write_env <project_root> <KEY> <VALUE>`** writes
  `KEY=VALUE` to `<project>/.env`, mode 0600 enforced via `touch && chmod
  0600` BEFORE first write. Idempotent merge: if `KEY` exists, prompts
  `[y/N] Overwrite KEY in <project>/.env?` reusing the v4.3 UN-03 contract
  (`< /dev/tty`, fail-closed N) (SEC-01, SEC-02).
- **`project_secrets_ensure_gitignore <project_root>`** appends `.env\n`
  with leading toolkit comment when `<project>/.gitignore` lacks an exact
  `^\.env$` line; idempotent on re-run; never matches `*.env` or `# .env`
  as "present"; creates `.gitignore` if missing (SEC-03).
- **`project_secrets_render_mcp_env_block <KEY1> <KEY2> ...`** returns the
  JSON object string `{"KEY1": "${KEY1}", "KEY2": "${KEY2}"}` for
  embedding into `.mcp.json` as the `env` field — `claude` resolves the
  vars from the environment at MCP launch (SEC-04).
- **Defense-in-depth literal-secret refusal** — any code path that writes
  to `.mcp.json` refuses string values that don't match
  `^\$\{[A-Z_][A-Z0-9_]*\}$`. Refusal returns rc=1 with `✗ refusing to
  write literal value into .mcp.json (use ${VAR} substitution)` to stderr.
  `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam exists for hermetic
  tests only and prints a one-line warning when honored (SEC-05).
- **Metacharacter rejection** — `project_secrets_write_env` rejects values
  containing `$`, backtick, backslash, double-quote, single-quote, or
  newline. Same allow-list as `_mcp_validate_value` in `mcp.sh` — shared
  helper across the secrets boundary (SEC-06).
- **Test contract** — new `scripts/tests/test-project-secrets.sh` with
  ≥18 hermetic, idempotent assertions covering all six SEC contracts.
  PASS=42 at ship.

### Added — Wizard dispatch integration (Phase 38)

`mcp_wizard_run` in `scripts/lib/mcp.sh` learns per-MCP scope routing:

- **`TK_MCP_SCOPE=project` branch** — wizard collects each env-var via the
  existing v4.6 hidden-input prompt loop, calls `project_secrets_write_env`
  per key (writes real values to `<project>/.env` mode 0600), calls
  `project_secrets_ensure_gitignore` once before the first write, and
  invokes `claude mcp add --scope project ...` with the env block rendered
  as `${VAR}` substitution form — never literal values. SEC-05 verifier
  refuses any literal in the resulting `.mcp.json` (DISP-01).
- **`TK_MCP_SCOPE=user` (or unset) branch** preserves v4.6/v4.9 behavior
  byte-identically: keys land in `~/.claude/mcp-config.env` via
  `mcp_secrets_set`, `claude mcp add --scope user ...` is invoked with
  literal env values exported via `env KEY=V`. No regression on existing
  user-scope flow (DISP-02).
- **Defer-secrets path extension** — `TK_MCP_DEFER_SECRETS=1` with
  `TK_MCP_SCOPE=project` pre-creates blank stub entries in
  `<project>/.env` (not `mcp-config.env`), triggers
  `project_secrets_ensure_gitignore` once before the first stub write.
  Deferred queue tuple grows from 3 to 4 fields
  (`name\tkeys\tinstall_args\tscope`) so the post-install summary can print
  scope-correct hints (DISP-03).
- **Post-install summary printer** — prints per-MCP scope alongside the
  existing keys-needed list. Project-scope rows additionally print
  `→ Edit <project>/.env to fill values; ensure .env is in your .gitignore
  (we appended it).` (DISP-04).
- **Tests** — `scripts/tests/test-mcp-wizard.sh` extended from PASS=14 to
  PASS=53 with DISP-01/02/03 happy paths and the DISP-04 summary-line
  assertion. `scripts/tests/test-mcp-secrets.sh` extended with the shared
  `_mcp_validate_value` boundary scenarios from SEC-06.

### Added — TUI per-row scope toggle (Phase 39)

- **Per-row scope indicator** — each MCP row in the integrations TUI
  carries a scope indicator (`[U]`, `[P]`, or `[L]`) immediately after the
  checkbox; the chosen scope is colored green when color is enabled.
  `NO_COLOR=1` produces plain bracket form per [no-color.org](https://no-color.org)
  (TUI-SCOPE-01).
- **Per-row hotkey** — pressing the per-row scope hotkey on a highlighted
  row cycles only that row's scope (`U → P → L → U`); other rows are
  unaffected. Binding documented in the TUI hint footer (TUI-SCOPE-02).
- **Global `s` repurposed as "set all"** — the v4.9 Phase 37 (`fc000d5`)
  global toggle is repurposed: pressing `s` cycles a global scope value
  and assigns it to every visible row in one stroke. Banner now reads
  `s: set all to <scope>` (TUI-SCOPE-03).
- **`MCP_SELECTED_SCOPE[]` parallel array** — Bash 3.2-compatible state
  parallel to `MCP_NAMES`/`MCP_STATUS`/`MCP_HAS_CLI`, initialized from
  each entry's `default_scope` via `mcp_status_array`. No associative
  arrays, no `mapfile`, no `${var,,}` (TUI-SCOPE-04).
- **Per-row dispatch** — the `install.sh` MCP install loop reads
  `MCP_SELECTED_SCOPE[$i]` per row and exports `TK_MCP_SCOPE=<scope>` for
  that single `mcp_wizard_run` invocation. The pre-v5.0 single-shell
  `TK_MCP_SCOPE` global is retired in favor of per-call injection
  (TUI-SCOPE-05).
- **`--mcp-scope=user|project|local` CLI flag** — non-interactive
  force-set still honored (`TK_MCP_SCOPE_CLI` broadcasts into every
  `MCP_SELECTED_SCOPE[]` slot). Invalid values exit 2 with a clear
  error.
- **Tests** — `scripts/tests/test-mcp-selector.sh` extended from PASS=21
  to PASS=36 with TUI-SCOPE-01..05 scenarios.

### Added — Uninstall secret cleanup (Phase 40)

- **Per-MCP secret cleanup** — `uninstall_prompt_mcp_keys <name>
  [<key>...]` helper in `scripts/uninstall.sh`. Reads keys for the named
  MCP from the catalog and prompts `[y/N] also remove keys K1, K2 from
  ~/.claude/mcp-config.env?` via `< /dev/tty` (fail-closed N on no-TTY,
  mirrors v4.3 UN-03). On Y: atomic `mktemp + mv + chmod 0600` rewrite
  drops only the named MCP's keys; other MCPs' entries preserved
  byte-identically. Mode 0600 enforced before AND after rewrite
  (UN-SEC-01). Called immediately after each toolkit-driven `claude mcp
  remove <name>` (UN-SEC-02).
- **Full-toolkit secret cleanup** — full uninstall now prompts ONCE about
  the entire `~/.claude/mcp-config.env`: `[y/N] also remove
  ~/.claude/mcp-config.env (X keys for Y MCPs)?` via `< /dev/tty`
  (fail-closed N). On Y the file is deleted before the LAST-step
  `STATE_FILE` removal (v4.3 UN-05 D-06 ordering preserved). The base-plugin
  `diff -q` invariant still runs and still wins (UN-SEC-03).
- **Project `.env` files NEVER touched** — `uninstall.sh` is now an
  explicit contract: project `.env` files outside `~/.claude/` are never
  opened or modified. Verified by hermetic filesystem-fingerprint diff in
  `test-uninstall-state-cleanup.sh`. Documented in `--help` output and
  `docs/INSTALL.md` (UN-SEC-04).
- **`--keep-state` implies `--keep-secrets`** — passing `--keep-state` (or
  `TK_UNINSTALL_KEEP_STATE=1`) preserves both the per-MCP and full-toolkit
  secret-cleanup paths along with the existing state file. Documented in
  `--help` and `docs/INSTALL.md` (UN-SEC-05).
- **Tests** — `scripts/tests/test-uninstall-state-cleanup.sh` extended
  with UN-SEC-01-Y/N branches, UN-SEC-03-Y/N branches, UN-SEC-04 negative
  fingerprint diff, UN-SEC-05 `--keep-state` preservation.

### Added — Calendly MCP (INT-13)

- **`calendly`** — official Calendly MCP server
  (`developer.calendly.com/calendly-mcp-server`). Added to the catalog with
  `display_name: "Calendly"`, `category: "workspace"`, `unofficial: false`,
  `default_scope: "user"`, `requires_oauth: true`. CLI block omitted (no
  companion CLI). Catalog count: 20 → 21 entries.

### Removed — Google Workspace MCP locked out (INT-14)

The catalog explicitly does **not** add a `google-workspace` MCP. Decision
logged in `.planning/PROJECT.md` Key Decisions and here: claude.ai's built-in
Gmail/Calendar/Drive connectors already cover that surface. Adding a
community wrapper would duplicate Anthropic's official OAuth flow and break
under upstream API changes. Re-evaluate only if Anthropic deprecates the
connectors (`INT-FUT-05`).

### Added — Distribution + docs (Phase 41)

- **`manifest.json` 4.9.0 → 5.0.0** with `scripts/lib/project-secrets.sh`
  registered under `files.libs[]` (alpha-ordered between `optional-plugins.sh`
  and `skills.sh`). `update-claude.sh` auto-discovers via the v4.4 LIB-01
  D-07 jq path — zero code changes (DIST-01).
- **`init-claude.sh --version` and `init-local.sh --version` print
  `5.0.0`** derived from manifest at runtime per v4.3 D-22. 3 plugin.json
  files (`tk-skills`, `tk-commands`, `tk-framework-rules`) bumped from
  4.8.0 → 5.0.0. `make version-align` green (DIST-02).
- **`docs/INTEGRATIONS.md` Per-MCP Scope section** — documents `[U]`/`[P]`/
  `[L]` semantics, where each scope's secrets live (`mcp-config.env` vs
  `<project>/.env`), the `${VAR}` substitution convention in `.mcp.json`,
  the `.gitignore` guard, and worked examples for both user-scope and
  project-scope flows (DOCS-01).
- **`docs/INSTALL.md` Installer Flags table** gains a row for
  `--mcp-scope=user|project|local` (DOCS-02). README "Killer Features"
  grid mentions per-MCP scope control as a v5.0 highlight.
- **`docs/INSTALL.md` Uninstall section** documents the new secret-cleanup
  prompts (per-MCP `[y/N]` and full-toolkit `[y/N]`), the explicit
  "project `.env` never touched" contract, and the `--keep-state` implies
  `--keep-secrets` rule (DOCS-03).

### Carry-over from v4.9 close (Phase 36-A polish)

The following Phase 36-A polish items were authored on the v4.9 release
branch and ship as part of v5.0:

- **MCP install↔reinstall toggle** — Space on a row already showing
  `[installed ✓]` toggles to `[reinstall ↻]` (light-green ANSI `\e[92m`).
  Submit calls `claude mcp remove` then re-adds via `mcp_wizard_run`.
  `TUI_REINSTALLABLE[]` opt-in defaults to 0; skills surface unaffected.
- **Install transcript polish** — silenced `claude mcp add` chatter via
  unified stderr+stdout capture wrapper; recolored `skipped` rows grey
  (was yellow); dropped duplicate "Integrations Install Summary" matrix
  table (-154 LOC in `lib/mcp.sh`); dropped trailing key-rotation explainer
  plus "To remove an MCP" line; renamed `To remove:` → `To uninstall:` in
  the completion banner across 4 producers.
- **mktemp template suffix collision on macOS BSD** —
  `mcp-catalog-XXXXXX.json`, `integrations-catalog-XXXXXX.json`,
  `gsd-installer.XXXXXX.sh` reduced to plain X-run templates; BSD mktemp
  refused trailing chars and produced `mkstemp failed: File exists` on
  second invocation.
- **`test-mcp-wizard.sh`** — swapped removed `sequential-thinking` to
  `playwright`.
- **CI** — `actions/checkout` bumped from `v4` (Node 20) to `v6.0.2` (Node
  24) per [GitHub deprecation notice](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/).

### Migration

- Existing v4.x users — re-run `update-claude.sh` to pick up the new
  `project-secrets.sh` lib via the v4.4 LIB-01 D-07 auto-discovery path.
  No manual fetch, no manifest edit, no code change.
- Pre-v5.0 user-scope MCPs in `~/.claude/mcp-config.env` stay where they
  are. Backward-compat fallback (SCOPE-03) ensures pre-v5.0 catalogs
  without `default_scope` continue to work — the loader silently treats
  absence as `user`.
- To move an existing user-scope MCP to project-scope: re-run the
  toolkit's MCP wizard, flip the row's scope indicator with the per-row
  hotkey, and submit. The wizard writes to the project's `.env` and
  registers `claude mcp add --scope project ...` with `${VAR}` substitution
  form; the user-scope entry can be removed via `claude mcp remove --scope
  user <name>` afterwards.
- No interactive migration prompt — pre-v5.0 installs continue to work
  unchanged. Out-of-scope: encrypt `mcp-config.env` at rest, auto-rotate
  secrets, Windows-native scope semantics (carry-over per
  REQUIREMENTS.md).

## [4.9.0] - 2026-05-02

Major install UX overhaul on top of 4.8.x — focused on PR #28 install run on
macOS and a series of user reports between 2026-05-01 and 2026-05-02.

Phases 32-35 (Integrations Catalog) consolidated v4.9 around a unified
MCP + companion-CLI install page. See [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md)
for the full reference.

### Added — Integrations Catalog (Phases 32-35)

Unified MCP + CLI install page accessible via `--integrations` (or the
deprecated `--mcps` alias). Replaces the old MCP-only page.

- **20 MCP servers across 10 categories** — `docs-research`, `backend`,
  `payments`, `email`, `workspace`, `project-management`, `communication`,
  `design`, `dev-tools`, `monitoring`. The TUI groups entries by category
  in canonical order; categories with zero entries silently skip.
- **8 companion CLIs** — install the official command-line tool for the
  same vendor alongside the MCP server. Cross-platform via `uname -s`
  dispatch (`brew install` on Darwin, vendor user-space tarball or
  `npm install -g` on Linux). NEVER auto-prefixes `sudo`. Brew-absent on
  Darwin yields a single-line hint and rc=3 — toolkit never auto-installs
  Homebrew.
- **Per-component status detection** — TUI shows `[MCP:✓ CLI:—]` per
  row (✓ installed, ✗ absent, ⊘ unknown, — n/a). MCP probe via
  `claude mcp list` (cached once per shell, ~4s); CLI probe via
  `command -v` (sub-millisecond, no cache).
- **`unofficial: true` confirm gate** — community / browser-automation
  entries (`notebooklm`, `telegram`) get a yellow `!` glyph in the TUI
  and a `[y/N]` confirm prompt before install. Default N (fail-closed
  per UN-03 contract). `--yes` does NOT bypass this prompt — security
  boundary. `ALWAYS_YES=1` env override bypasses (trusted automation).
- **`--mcp-only` / `--cli-only` mutex flags** — install only the MCP side
  or only the CLI side of selected entries. Mutually exclusive (passing
  both exits with rc=2 + stderr "mutually exclusive").
- **Closing summary table** — Entry × MCP × CLI matrix with per-component
  glyphs, Notes column for skip reasons, and `Installed: N MCPs, M CLIs ·
  Skipped: X · Failed: Y` total line.

### Added — 12 new integrations (INT-01..12)

- **Backend**: `supabase` (MCP+CLI), `cloudflare` (MCP+wrangler),
  `aws-cost-explorer` (MCP+`aws`), `aws-cloudwatch-logs` (MCP+shared
  `aws` CLI — installer detects shared dependency, installs `aws` once
  per session)
- **Payments**: `stripe` (MCP+CLI)
- **Project Management**: `youtrack`, `linear`, `jira` (MCP only)
- **Design**: `figma` (MCP only)
- **Communication**: `slack` (MCP), `telegram` (MCP, unofficial)
- **Docs/Research**: `notebooklm` (MCP, unofficial)

### Added — CLI installer library (`scripts/lib/cli-installer.sh`)

Public primitives consumed by the integrations TUI dispatch loop:

- `cli_detect <name>` — `command -v` wrapper, no caching, sub-millisecond.
- `cli_install <name> <darwin_cmd> <linux_cmd>` — `uname -s` dispatch
  with `TK_CLI_UNAME` test seam. Brew-absent fallback (rc=3) on Darwin
  via `TK_CLI_BREW_BIN` seam. NO sudo auto-prefix EVER (D-17). Trusts
  the curated catalog input (validator-enforced shape) so `eval` is
  safe inside that boundary.
- `cli_post_install_hint <hint>` — writes `→ Next: <hint>` to stderr
  ONLY (stdout stays parseable). Toolkit NEVER auto-runs `<tool> login`
  — boundary is "config + hints", not "auth flows".

### Added — Schema validator + 3 hermetic test suites

- **Validator** `scripts/validate-integrations-catalog.py` (Python stdlib
  only, no `jsonschema` dependency, Python 3.8+). Wired into `make
  validate-catalog` and CI's `validate-templates` job.
- **Test 45** `scripts/tests/test-integrations-catalog.sh` (PASS=14,
  floor 10): schema-only checks for catalog file — `schema_version=2`,
  10 categories, 20 MCP entries, 8 CLI entries, required fields,
  unofficial set is exactly `{notebooklm, telegram}`, no
  `sequential-thinking`, no `sudo` token in any install string.
- **Test 46** `scripts/tests/test-cli-installer.sh` (PASS=24, floor 8):
  primitives test for `cli_detect` / `cli_install` / `cli_post_install_hint`
  with `TK_CLI_UNAME` + `TK_CLI_BREW_BIN` seams.
- **Test 47** `scripts/tests/test-integrations-tui.sh` (PASS=36,
  floor 15): Phase 34 TUI redesign assertions — category-grouped
  rendering, unofficial glyph, parallel-array length, mocked claude
  flow, `unofficial_confirm` ALWAYS_YES + TTY paths,
  `--mcp-only`/`--cli-only` mutex, summary table format, zero-entry
  category skip via fixture catalog.

### Added — `docs/INTEGRATIONS.md`

Complete catalog reference with category-grouped tables, install flow,
unofficial semantics, OAuth setup links per entry, troubleshooting, and
a dedicated **Global vs per-project** section establishing the
toolkit/SDK boundary (DOCS-02): catalog ships globals only, never
per-project SDKs.

### Changed — Schema migration (CAT-01..03)

- `scripts/lib/mcp-catalog.json` → `scripts/lib/integrations-catalog.json`
  (`schema_version: 2`). New top-level structure: `categories[]`,
  `components.mcp{}`, `components.cli{}`. 8 surviving Phase 32 entries
  (`context7`, `firecrawl`, `magic`, `notion`, `openrouter`, `playwright`,
  `resend`, `sentry`) tagged with category. Optional CLI blocks added to
  `firecrawl`, `playwright`, `sentry` whose CLIs add real value.
- `scripts/lib/mcp.sh` rewritten to read schema v2 — `mcp_catalog_load`,
  `mcp_categories_load`, `mcp_status_array`, `_mcp_category_display`,
  `unofficial_confirm`, `print_integrations_summary`. Bash 3.2 parallel
  arrays only (`MCP_NAMES[]`, `MCP_CATEGORY[]`, `MCP_UNOFFICIAL[]`,
  `TUI_GROUPS[]`, etc.).
- `scripts/install.sh` adds `--integrations`, `--mcp-only`, `--cli-only`,
  `--mcps` (deprecated alias) flags + dispatch loop with per-row
  unofficial-confirm gate, MCP-side dispatch, CLI-side dispatch via
  `cli_install`, summary table renderer.

### Changed — `--mcps` flag deprecated

`--mcps` continues to work as an alias for `--integrations` but prints a
one-line stderr deprecation note: `⚠ --mcps is deprecated; use
--integrations (alias retained until v6.0)`. Alias removal is post-v5.0.

### Changed — `manifest.json` 4.8.0 → 4.9.0

`files.libs[]` registers `cli-installer.sh` and `integrations-catalog.json`
(replacing `mcp-catalog.json`); `files.scripts[]` registers
`validate-integrations-catalog.py`. `update-claude.sh` auto-discovers
all three via the existing v4.4 LIB-01 D-07 jq path — no script code
changes required for smart-update coverage.

### Changed — `init-claude.sh --version` parity with `init-local.sh`

Added `--version` / `-v` flag to `init-claude.sh` deriving version from
manifest at runtime (v4.3 D-22 contract). Reads local manifest when run
from a clone; curls `$REPO_URL/manifest.json` when run via `curl | bash`.
Both installers now print `claude-code-toolkit v4.9.0` on `--version`.

### Removed — `sequential-thinking` (DROP-01)

Removed from catalog. Native Claude extended thinking covers the use case
adequately. Existing user installs are unaffected — toolkit doesn't
auto-uninstall MCPs when the catalog drops them (boundary preserved).
Users with `sequential-thinking` in their `claude mcp list` keep the
server registered until they manually `claude mcp remove sequential-thinking`.

### Migration notes

Users on v4.8 → v4.9: re-run `update-claude.sh` to pick up the new lib,
script, and JSON catalog. No manual catalog re-fetch needed; the
v4.4 LIB-01 D-07 jq-path auto-discovery handles all three.

### Added — Back navigation in multi-step picker flow (UX-FLOW-02)

Press `b` (or `B`) inside the skills or MCP sub-picker to return to the
previous step. Skills picker → main TUI; MCP picker → skills picker (or
main TUI if skills wasn't selected). Previously selected items are
re-checked when re-entering a picker via Back. Gated on
`TK_TUI_ALLOW_BACK=1`. Footer hint shows `· b back` only in multi-step mode.

### Added — MCP secrets deferred (registered without API key during install)

Mid-install API-key prompts caused users to abandon the flow. New
`TK_MCP_DEFER_SECRETS=1` mode (default during dispatch): MCPs needing env
keys are registered with `claude mcp add` *without* env vars (so they
appear in `claude mcp list` with empty env binding), keys queued in
`~/.claude/mcp-config.env` as empty stubs (mode 0600), and a one-time
shell-rc auto-source line is appended to `~/.zshrc` / `~/.bash_profile` /
`~/.bashrc` (idempotent via marker comment). User fills mcp-config.env,
opens fresh terminal, launches claude — MCPs pick up keys at startup.
No re-registration when keys change later.

Status row reads `installed (needs API key)` (yellow). Post-summary
follow-up block prints a 3-step recipe.

### Added — Tooltip / banner colors switched to CYAN

Sweep `${BLUE}` → `${CYAN}` across `init-claude.sh`, `install.sh`,
`init-local.sh`, `update-claude.sh`. Dark-blue text was unreadable on
macOS Terminal default dark theme.

### Changed — Atomic TUI render eliminates flicker AND bleed-through

`_tui_render` builds the entire frame as a single string and writes to
the TTY in ONE printf. Solves both flicker (per-line printfs caused
visible repaints between syscalls) and bleed-through (gap lines retained
content from prior frames). Atomic write + `\e[H\e[J` at frame start.

### Changed — Install order: skills BEFORE mcp-servers

`TK_DISPATCH_ORDER` reordered so the MCP "needs API key" follow-up block
ends the screen. Main TUI marketplace section + pre-collection sub-pickers
also reordered.

### Changed — Skills install summary uses soft-checkmark style

Bright-green right-aligned `installed ✓` rows replaced with a leading
`✓ name` row (matching `init-claude.sh`'s "📥 Framework extras..." style).
Failures render `✗ name — reason` in red. Dry-run keeps the literal
`would-install` token (tests parse it).

### Changed — Consolidated install finale at top-level

Sub-installers run with `TK_DISPATCHED=1` and suppress their standalone
finale (recommend_security/statusline/optional_plugins, "Verify",
"Restart Claude Code", POST_INSTALL note). Parent `install.sh` emits ONE
consolidated finale AFTER all dispatchers complete.

### Changed — Project-local skill stubs deduplicated against marketplace

Removed `ai-models`, `tailwind`, `i18n` from every framework template
(base + nodejs + go + python + laravel + rails + nextjs). Each
`skill-rules.json` updated. ~4685 lines deleted. Marketplace versions
(`ai-models`, `tailwind-design-system`, `i18n-localization`) cover the
same ground. Kept project-local stubs unique to the toolkit:
`api-design`, `council-integration`, `database`, `debugging`, `docker`,
`llm-patterns`, `observability`, `testing`.

### Fixed — Esc detection on macOS Terminal / iTerm2

`tui_checklist` case match extended from `$'\e')` to
`$'\e' | $'\e\e' | $'\e\e\e')`. macOS Terminal + iTerm2 "Send +Esc"
config emits 2-3 bytes per Esc keypress; the read-ahead window catches
them. Previous single-arm match dropped these into `*) ignore` and
"Esc did nothing". Footer text changed `Esc cancel` → `Ctrl+C abort`.

### Fixed — `claude mcp list` cached once per install

`mcp_status_array` previously called `claude mcp list` 9 times (once per
MCP catalog entry) for ~40 s on macOS. New `_mcp_list_cache_init`
function memoizes once per shell. Visible "Loading MCP catalog..."
banner added.

### Fixed — Sub-pickers run in main process (no subshell)

UX-FLOW-01 originally captured sub-picker output via subshell `$()`.
On macOS the TUI library's stty/cursor-hide sequences plus captured-stdout
fd combination left the post-Submit screen frozen. Sub-pickers now run
in the main process with `_save_main_tui_state` / `_restore_main_tui_state`
helpers.

### Fixed — Mid-install banner suppressed in dispatch mode

`init-claude.sh` invoked from `install.sh` dispatch loop printed its
standalone "Installation Complete!" + recommendations block BEFORE
skills/MCP dispatchers ran. `TK_DISPATCHED=1` suppresses it.

### Fixed — `mcp-catalog.json` race-on-mktemp

`--mcps` branch unconditionally re-`mktemp`'d a catalog file even when
the parent UX-FLOW-01 block already exported `TK_MCP_CATALOG_PATH`.
Under heavy `/tmp` churn BSD `mkstemp` gave up with `File exists`.
Guard added.

### Fixed — `gemini-bridge` symlink failure message

Two-line message replaced with 5-line diagnostic naming the symlink
target, explaining *why* we refuse (could clobber another tool's config),
and printing the literal `rm <path>` command to fix it.

### Changed — Pre-collect all TUI selections before installing (UX-FLOW-01)

Previously the install flow was: main TUI → Submit → run toolkit / security /
etc. → 20 s pause → MCP sub-picker → Submit → install MCPs → skills sub-picker
→ Submit → install skills. The mid-install sub-pickers felt like a hang and
broke the user's mental model of "answer questions, then watch the install".

New flow: main TUI → Submit → MCP sub-picker (if `mcp-servers` row checked)
→ Submit → skills sub-picker (if `skills` row checked) → Submit → THEN the
dispatch loop runs end-to-end with no further prompts.

Implementation: `install.sh` collects MCP / skills selections in subshells
(so the main TUI globals aren't clobbered) right after the bridge plumbing
block. Selections are exported as `TK_MCP_PRE_SELECTED` / `TK_SKILLS_PRE_SELECTED`
comma-separated lists. The `--mcps` and `--skills` branches honour these
env vars: when set (even empty), they skip their own TUI render and build
`TUI_RESULTS` directly from the pre-collected list. Empty value (`TK_MCP_PRE_SELECTED=""`)
is meaningful — "user opened the picker, picked nothing, hit Submit" — and
results in a headless install of zero items rather than falling back to a
TUI that would reopen mid-install.

Cancel semantics preserved: pressing Esc / Ctrl-C in the MCP or skills sub-
picker aborts the entire install (no partial component install).

New regression test `scripts/tests/test-flow-prequestions.sh` (8/8 PASS):
asserts pre-selected env produces exactly the named items, empty env produces
zero items, and unset env falls back to the legacy `--yes` default-set path.

### Fixed — Invisible-prompt regression (TUI dispatch)

After a user pressed Submit on the main TUI, `init-claude.sh` ran under
`install.sh`'s D-28 stderr-capture wrapper (`( dispatch_toolkit ) 2>"$tmp"`).
Bash's `read -p "prompt"` writes the prompt to **stderr**, so the bridge
install prompt (`Gemini detected. Create GEMINI.md → CLAUDE.md bridge?
[Y/n]:`) landed in the captured tmpfile and the user saw a bare blinking
caret with no instruction.

Two-layer fix:

1. **Structural:** new `tui_tty_read` helper in `scripts/lib/tui.sh` writes
   the prompt directly to the TTY device (not stderr), immune to parent
   stderr capture. Refactored 5 call sites — `lib/tui.sh:tui_confirm_prompt`,
   `lib/bridges.sh` × 2 (drift overwrite, install prompt),
   `lib/bootstrap.sh:_bootstrap_prompt_and_run`, `lib/mcp.sh` × 2 (overwrite,
   secret-key entry). Helper supports a `TK_TUI_PROMPT_SINK` regression-test
   seam and char-device detection so legacy regular-file / process-
   substitution test seams continue to work without truncating answers.
2. **UX:** `install.sh` plumbs the TUI bridge selection (rows 8/9) into
   `init-claude.sh` via `BRIDGES_FORCE` / `TK_NO_BRIDGES` env vars. When the
   user selects bridges in the main TUI, `bridge_install_prompts` takes its
   non-interactive force path (no second prompt). When the user leaves the
   bridge rows unchecked, `TK_NO_BRIDGES=1` silences project-bridge prompts
   entirely. Manual `--bridges <list>` / `--no-bridges` overrides still work
   when invoked outside the TUI flow.

`tui.sh` is now downloaded by `init-claude.sh` and `update-claude.sh` BEFORE
`bridges.sh` / `bootstrap.sh` / `mcp.sh` so their lazy-source guard
(`command -v tui_tty_read`) reports defined and the per-lib `BASH_SOURCE`
fallback (which fails under curl|bash because libs live in `/tmp/<lib>`
without sibling files) is skipped.

New regression test `scripts/tests/test-invisible-prompt.sh` (14/14 PASS):
asserts prompts never reach captured stderr, exercises both the helper unit
and the real bridge / mcp paths under a stderr-capture wrapper. All existing
suites still pass (test-bridges-sync 25/0, test-mcp-secrets 11/0,
test-bridges-install-ux 20/0, test-bootstrap 26/0, test-install-tui 52/0).

### Audit Sweep 260430-go5 (PR #15) — 18 findings + dead-code

Deep 4-agent audit (security, code-review, infra/CI, shell) on 2026-04-30.
1 finding withdrawn as false positive (Read-tool render artifact). Cross-checked
against parallel Gemini audit which caught 1 additional dead-code item.

#### Fixed — High

- **H1** — `install.sh` dispatch index mismatch installed wrong bridge under
  Codex-only scenario (`IS_GEM=0 IS_COD=1`). Now uses name-based lookup with
  `_local_label_to_dispatch_name()` helper. New regression test
  `scripts/tests/test-install-dispatch-h1.sh` (6/6 PASS).
- **H3** — `setup-security.sh` silently skipped RTK.md install under
  `bash <(curl ...)` because `dirname $0` resolved to `/dev/fd`. Curl-pipe
  detection added with download fallback.
- **H4** — `init-claude.sh` echoed Gemini/OpenAI/OpenRouter API keys to terminal
  scrollback (`read -r -p`). Switched 3 sites to `read -rs -p` matching the
  hardened `setup-council.sh` pattern.
- **H5** — Distribution chain hardcoded to mutable `main` ref. New
  `TK_TOOLKIT_REF` env var (default `main`) on all 8 installers +
  `lib/dispatch.sh`. Documented in `docs/INSTALL.md`. Optional
  `TK_TOOLKIT_PIN_SHA256` checksum mode deferred.
- **H6** — `TK_DISPATCH_OVERRIDE_*` env-bash without `TK_TEST=1` gate while
  `eval` siblings already gated by audit C2. Gate parity restored across 6
  dispatchers + 7 test blocks.

#### Fixed — Medium

- **M1** — `install.sh:837` called undefined `log_error` → exit 127 if
  validator triggered. Inlined the error echo.
- **M2** — `uninstall.sh` reclassified empty-installed-sha files from
  `MODIFIED` to `REMOVE` so users no longer get spurious `[y/N/d]` prompts on
  toolkit-owned files they never edited.
- **M3** — Trap regression of audit M6 fix in `propagate-audit-pipeline-v42.sh`
  (line 300) and `lib/bootstrap.sh` (line 67). Now uses `printf %q` quoting
  matching the corrected pattern at `propagate-audit-pipeline-v42.sh:128`.
- **M4** — `install.sh:917,920` empty-array expansion crashed under Bash 3.2
  `set -u`. Switched to `${arr[@]+"${arr[@]}"}` form matching siblings 363/365.
- **M5** — `setup-council.sh:512` `read /dev/tty` killed installer under
  `set -e` with no TTY. Added `|| true` guard matching every other `read`
  in the repo.
- **M6** — `update-claude.sh:1129/1211/1212` bare `mktemp` calls leaked on
  SIGINT — registered to EXIT trap.
- **M7** — `.github/workflows/quality.yml` added `concurrency:`
  cancel-in-progress group; force-push no longer spawns redundant 5-job runs.
- **M8** — `templates/global/statusline.sh` and `rate-limit-probe.sh` now
  early-exit on non-Darwin platforms (BSD-only `stat -f %m` was silently
  misbehaving on Linux).

#### Fixed — Low

- **L1** — `mcp_secrets_load` validates key shape (`^[A-Z_][A-Z0-9_]*$`)
  alongside values.
- **L2** — `install.sh` removed component name from `/tmp` stderr templates
  (3 sites — line 892 also leaked); now mktemp randomness only.
- **L3** — `lib/skills.sh:147` `rm -rf` guarded against `/` and empty target.
- **L4** — Browser `User-Agent` added to all `curl` invocations (project
  global rule §2 violation). New `TK_USER_AGENT` constant in 3 libs +
  inline `-A` injection across 13 scripts. 17 files touched.
- **L5** — `scripts/council/brain.py` sanitizes ANSI/control chars from
  reviewer output before writing to disk (3 sites including `missed_text`).
  Pattern copied from `update-claude.sh:1005-1008`.

#### Withdrawn — false positive

- **H2** — `lib/mcp.sh:85` claimed empty join separator. `xxd` confirmed the
  literal `\x1f` (ASCII 31 unit-separator) byte was already present; Read-tool
  renderer displayed US byte as nothing, fooling the audit agent. Source code
  was correct.

#### Dead code

- **T1** — Removed unused `sha256_any()` helper from
  `scripts/tests/test-uninstall-prompt.sh:65-72` (caught by parallel Gemini
  cross-audit).

## [4.8.0] - 2026-04-29

### Added — Multi-CLI Bridge

- **CLI detection** (`scripts/lib/detect2.sh`) — BRIDGE-DET-01, BRIDGE-DET-02,
  BRIDGE-DET-03: Phase 28. `is_gemini_installed` and `is_codex_installed` probes
  added alongside the existing 6 binary probes from v4.6 Phase 24. Both return
  0/1 binary, fail-soft via `command -v <cli>` with `[ -d ~/.gemini/ ]` /
  `[ -d ~/.codex/ ]` as soft cross-check. `detect2_cache` exports `IS_GEM` and
  `IS_COD`.

- **Bridge generation library** (`scripts/lib/bridges.sh`, 467 lines) —
  BRIDGE-GEN-01, BRIDGE-GEN-02, BRIDGE-GEN-03, BRIDGE-GEN-04: Phase 28.
  `bridge_create_project <target>` writes
  `<project>/GEMINI.md` (gemini) or `<project>/AGENTS.md` (codex) — note this
  is the OpenAI standard, NOT `CODEX.md`. `bridge_create_global <target>` writes
  `~/.gemini/GEMINI.md` / `~/.codex/AGENTS.md` and never touches the canonical
  `CLAUDE.md`. Auto-generated header banner is byte-identical across all
  bridges. Each bridge registers in `~/.claude/toolkit-install.json::bridges[]`
  with `target`, `path`, `scope`, `source_sha256`, `bridge_sha256`,
  `user_owned: false`. Atomic state writes via `tempfile.mkstemp + os.replace`.

- **Sync on update** (`scripts/update-claude.sh`) — BRIDGE-SYNC-01, BRIDGE-SYNC-02,
  BRIDGE-SYNC-03: Phase 29.
  `sync_bridges()` iterates `bridges[]` from state file. Source-drift detection
  (recorded `source_sha256` differs from current) triggers re-copy and SHA
  refresh, logging `[~ UPDATE] GEMINI.md`. Bridge-drift detection (user edited
  the bridge file) triggers `[y/N/d]` prompt with default `N`; `d` shows diff
  and re-prompts (mirrors v4.3 UN-03 contract). Orphaned source (CLAUDE.md
  deleted) logs `[? ORPHANED]` and auto-flips `user_owned: true`.

- **Break/restore bridges** (`scripts/update-claude.sh`) — BRIDGE-SYNC-02:
  Phase 29. `--break-bridge <target>` flips `user_owned: true` for the named
  bridge; subsequent updates skip it with `[- SKIP]`. `--restore-bridge <target>`
  reverses the flag and resumes sync on next update.

- **Uninstall integration** (`scripts/uninstall.sh`) — BRIDGE-UN-01, BRIDGE-UN-02:
  Phase 29. Bridges from `bridges[]` are classified via `classify_bridge_file`
  helper: clean → REMOVE_LIST; user-modified → MODIFIED_LIST with v4.3 `[y/N/d]`
  prompt. `is_protected_path` correctly bypassed for bridges. `--keep-state`
  (v4.4 KEEP-01) preserves `bridges[]` entries alongside the rest of
  toolkit-install.json — no special-case handling needed.

- **Install-time UX** (`scripts/install.sh`, `scripts/init-claude.sh`,
  `scripts/init-local.sh`) — BRIDGE-UX-01, BRIDGE-UX-02, BRIDGE-UX-03,
  BRIDGE-UX-04: Phase 30. The unified TUI
  (`install.sh`) shows conditional `gemini-bridge` / `codex-bridge` rows in
  the Components page when the corresponding CLI is detected; rows hidden
  otherwise. `init-claude.sh` and `init-local.sh` post-install per-CLI prompt
  defaulting `Y`, fail-closed `N` on no-TTY (CI / piped install). All 3 entry
  points support `--no-bridges` / `TK_NO_BRIDGES=1` (skip) and `--bridges
  gemini,codex` (force-create non-interactively). With `--fail-fast`, absent
  CLI exits 1; without, warns and continues.

- **Multi-CLI bridge documentation** (`docs/BRIDGES.md`, `docs/INSTALL.md`,
  `README.md`) — BRIDGE-DOCS-01, BRIDGE-DOCS-02: Phase 31. New `docs/BRIDGES.md` documents
  supported CLIs (Gemini → `GEMINI.md`, OpenAI Codex → `AGENTS.md`),
  plain-copy semantics, drift handling, opt-out (`--no-bridges`,
  `--break-bridge`, `--restore-bridge`), force-create (`--bridges <list>`),
  symlink-vs-copy rationale, uninstall behaviour, future scope. `INSTALL.md`
  Installer Flags table extended with 4 new flag rows. `README.md` Killer
  Features grid mentions multi-CLI bridges.

- **Manifest registration** (`manifest.json`) — BRIDGE-DIST-01: Phase 31.
  `scripts/lib/bridges.sh` added to `files.libs[]` (alphabetized between
  `bootstrap.sh` and `cli-recommendations.sh`). Auto-discovered by
  `update-claude.sh` via the v4.4 LIB-01 D-07 jq path with zero code changes.

### Changed

- **`write_state` arity extended** (`scripts/lib/state.sh`) — Phase 29 D-29-01
  backward-compatible 10-arg variant accepts `bridges_json` as the 10th
  positional. Existing 9-arg callers (`init-claude.sh`, `update-claude.sh`,
  `install.sh`) work unchanged via Bash positional-default semantics.
  `init-local.sh` and `migrate-to-complement.sh` updated to pass the 10th arg.

- **Manifest version** bumped from 4.6.0 to 4.7.0. All 3 plugin manifests
  (`tk-skills`, `tk-commands`, `tk-framework-rules`) bumped in lock-step.

### Fixed

- **Phase 29 WR-01** — uninstall `[y/N/d]` bypass for user-modified bridges
  fixed by routing through existing v4.3 prompt path instead of skipping.

- **Phase 29 WR-02** — state file path mismatch in test fixtures (was using
  `STATE_FILE_HOME` instead of `TK_BRIDGE_HOME`) corrected; all hermetic tests
  now run in fully isolated sandboxes.

- **Phase 30 WR-01** — silent `--bridges <list>` failure when named CLI absent
  without `--fail-fast` now prints a warning to stderr and continues.

### Tests

- 3 new hermetic suites totalling 50 assertions:
  - `scripts/tests/test-bridges-foundation.sh` (5 assertions, Phase 28)
  - `scripts/tests/test-bridges-sync.sh` (25 assertions, Phase 29)
  - `scripts/tests/test-bridges-install-ux.sh` (20 assertions, Phase 30)
- `scripts/tests/test-bridges.sh` (NEW) — aggregator wrapping the 3 suites
  with a single PASS/FAIL summary; wired into CI (`quality.yml`
  test-init-script job).

### Compatibility

- BACKCOMPAT-01 preserved across all v4.6 baselines:
  - `test-bootstrap.sh` PASS=26 unchanged
  - `test-install-tui.sh` PASS=43 unchanged
  - All 7 v4.3 uninstall-suite tests unchanged
  - All v4.6 MCP / Skills / Marketplace tests unchanged

## [4.7.0] - 2026-04-29

### Phase 24 Sub-Phases 2–10 — Council rework

#### Added — Sub-Phase 2 (editable system prompts)

- Externalized Skeptic / Pragmatist / audit-review system prompts to
  `~/.claude/council/prompts/*.md`. brain.py reads them via `load_prompt()`
  and falls back to embedded constants when files are missing.
- Mandatory FP-recheck + Confidence triad + code citation block in every
  verdict per the new prompt template.
- `.upstream-new.md` sidecar pattern preserves user edits on update,
  mirroring `setup-security.sh`.

#### Added — Sub-Phase 3 (context enrichment + redaction)

- Context bundle now includes README head, `.planning/PROJECT.md`,
  recent git log, TODO/FIXME grep, and matching test files for any
  source files Gemini selects in discovery.
- `apply_context_budget()` proportional truncation guards a 200K total
  context cap.
- `redact_context()` strips Stripe live keys, Anthropic `sk-ant-`,
  generic high-entropy hex, and `.env` quoted secrets before sending.
  Patterns live in editable `~/.claude/council/redaction-patterns.txt`.
- `COUNCIL_DEBUG=1` stderr trace shows context block sizes + redaction
  counts.

#### Added — Sub-Phase 4 (cost tracking)

- Append-only `~/.claude/council/usage.jsonl` log of every Council call
  with provider, model, mode, tokens, dollar cost, and verdict.
- `pricing.json` overlays a built-in `DEFAULT_PRICING` table; CLI
  providers cost $0 with chars/4 estimated tokens marked
  `estimated: true`.
- New `/council-stats` slash command renders `--day | --week | --month
  | --total | --since/--until | --csv` summaries from the log.
- Optional `COUNCIL_COST_CONFIRM_THRESHOLD=<usd>` cost gate prompts the
  user before any call whose estimated input cost exceeds the threshold;
  CI / non-TTY runs auto-proceed with stderr warning.

#### Added — Sub-Phase 5 (provider hardening + fallback)

- Codex CLI provider for ChatGPT (mode: cli) using `codex exec --model
  X --config model_reasoning_effort=Y -`.
- `reasoning.effort` pinned to `high` for the gpt-5.2 / o3 family
  (configurable via `config.openai.reasoning_effort`).
- Gemini `thinkingConfig.thinkingBudget=32768` set for the API path.
- OpenRouter free-model fallback chain (`tencent/hy3-preview:free`,
  `nvidia/nemotron-3-super-120b-a12b:free`,
  `inclusionai/ling-2.6-1t:free`, `openrouter/free`) kicks in when the
  primary backend errors. Recorded with `fallback_used: true`.
- `setup-council.sh` wizard now prompts for Codex CLI vs API and
  optional OpenRouter key.

#### Added — Sub-Phase 6 (content-hash cache)

- `~/.claude/council/cache/<key>.json` cache keyed by
  sha256(plan | git_head | cwd). Hits within TTL replay output with a
  `[cached <ts>]` marker and zero provider calls.
- TTL configurable via `config.cache.ttl_days` (default 7).
- `--no-cache` flag bypasses for one run.
- New `/council clear-cache` slash command + `brain clear-cache`
  subcommand.
- Cache hits log a `cache_hit: true` row to `usage.jsonl` so
  `/council-stats` reflects savings.

#### Added — Sub-Phase 7 (GSD integration)

- `templates/base/skills/council-integration/SKILL.md` documents
  the integration patterns for `/gsd-plan-phase --council`,
  `/gsd-execute-phase --council`, and the audit Council pass.
  Verdict-handling rules (PROCEED / SIMPLIFY / RETHINK / SKIP) +
  troubleshooting matrix.
- Skill triggers in `skill-rules.json` + manifest registration.

#### Added — Sub-Phase 8 (QoL features)

- `detect_domain()` classifies the plan into security / performance /
  ux / migration / general from regex on plan keywords.
- 8 persona overlay prompts under
  `templates/council-prompts/personas/`. Non-general domains layer the
  matching `<domain>-skeptic.md` / `<domain>-pragmatist.md` overlay on
  top of the base prompt at every reviewer call site.
- `--dry-run` flag builds the full Skeptic + Pragmatist prompts (with
  context, persona, redaction) and prints them with an estimated cost.
  Exits 0 without API calls.
- `--format json` emits a single-line JSON object
  `{verdict, skeptic, pragmatist, concerns_skeptic[], concerns_pragmatist[],
  domain, plan_hash, git_head, fallback_used: {skeptic, pragmatist},
  cache_hit, ...}` for tooling integration. Cache hits also emit JSON
  with `cache_hit: true`.
- TL;DR auto-summary block at the top of every written
  `council-report.md` carries verdict + top 3 concerns + detected
  domain.
- New `--mode retro --commit <sha>` retrospective review reads the
  commit diff plus the prior Council report and renders ALIGNED /
  DRIFT / UNCLEAR.

#### Added — Sub-Phase 9 (multilingual prompts)

- Russian translations of the four system prompts under
  `templates/council-prompts/ru/`.
- `--lang en|ru|auto` flag (default `auto`). `auto` reads the first
  500 chars of `~/.claude/CLAUDE.md` and switches to ru when the
  Cyrillic ratio exceeds 0.2.
- `load_prompt()` and `load_persona()` lookup order:
  `<lang>/<name>.md` → `<name>.md` → embedded fallback.
- Verdict tokens stay English so the orchestrator's parser remains
  language-agnostic.

#### Added — Sub-Phase 10 (docs + version bump)

- Rewrite of `commands/council.md` covering all new flags and modes.
- New `docs/COUNCIL.md` deep reference: architecture, provider matrix,
  cost considerations, customization (prompt editing, redaction
  patterns, persona prompts, ru locale), MCP integration pointer.
- README "Killer Features" row refreshed; pointer to
  `docs/COUNCIL.md`.
- Manifest version bumped from 4.6.0 to 4.7.0; plugin manifests
  follow.

#### Notes

Sub-Phase 11 (MCP server for Claude Desktop) is in progress on the
same milestone branch and will ship under a subsequent CHANGELOG
entry. Sub-Phase 1 already shipped under [4.5.0] - 2026-04-29.

## [4.6.0] - 2026-04-29

### Added

- **Unified TUI installer** (`scripts/install.sh`) — TUI-01..07, DET-01..05,
  DISPATCH-01..03, BACKCOMPAT-01: Phase 24. Single curl-bash entry point
  rendering an arrow-navigable Bash 3.2 checklist (no Bash 4-only constructs)
  with auto-detect of toolkit / superpowers / GSD / security pack / RTK /
  statusline. `--yes` for CI, `--force` re-runs detected, `--no-color`
  honored, `Ctrl-C` restores terminal cleanly. Foundation libs
  (`scripts/lib/{tui,detect2,dispatch}.sh`) reused by Phases 25-26. Hermetic
  test: `scripts/tests/test-install-tui.sh` (38+ assertions, Test 31).

- **MCP catalog + per-MCP wizard** (`scripts/lib/mcp.sh`,
  `scripts/lib/mcp-catalog.json`) — MCP-01..05,
  MCP-SEC-01..02: Phase 25. Nine curated MCP servers (`context7`, `firecrawl`,
  `magic`, `notion`, `openrouter`, `playwright`, `resend`, `sentry`,
  `sequential-thinking`) browsable via `scripts/install.sh --mcps`. Per-MCP
  wizard collects API keys with hidden input (`read -rs`), persists to
  `~/.claude/mcp-config.env` (mode 0600), invokes `claude mcp add`. Fail-soft
  when CLI absent. Hermetic test: `scripts/tests/test-mcp-selector.sh`
  (Test 32).

- **Skills marketplace mirror** (`templates/skills-marketplace/`,
  `scripts/lib/skills.sh`, `scripts/sync-skills-mirror.sh`) — SKILL-01..05:
  Phase 26. 22 curated skills mirrored from upstream skills.sh (license-audited,
  documented in `docs/SKILLS-MIRROR.md`). `scripts/install.sh --skills`
  copies selected skills to `~/.claude/skills/<name>/` via `cp -R`.
  `manifest.json` registers all 22 under `files.skills_marketplace[]` so
  `update-claude.sh` ships skill updates. Hermetic test:
  `scripts/tests/test-install-skills.sh` (15 assertions, Test 33).

- **Plugin marketplace surface** (`.claude-plugin/marketplace.json`,
  `plugins/tk-{skills,commands,framework-rules}/.claude-plugin/plugin.json`,
  symlink trees) — MKT-01, MKT-02: Phase 27. Three sub-plugins discoverable
  via `claude plugin marketplace add sergei-aronsen/claude-code-toolkit`.
  `tk-skills` is Desktop-Code-tab compatible; `tk-commands` and
  `tk-framework-rules` are Code-only. Sub-plugin content trees are relative
  symlinks into the canonical repo content (zero duplication, zero drift).
  Version is the single source of truth in each `plugin.json` (4.6.0);
  `marketplace.json` plugin entries do not declare versions per spec.

- **Marketplace + Desktop-skills validators** (`scripts/validate-marketplace.sh`,
  `scripts/validate-skills-desktop.sh`) — MKT-03, DESK-02, DESK-04: Phase 27.
  `validate-marketplace` runs `claude plugin marketplace add ./` smoke when
  `TK_HAS_CLAUDE_CLI=1` (CI default skips with no-op notice).
  `validate-skills-desktop` scans every `templates/skills-marketplace/*/SKILL.md`
  for tool-execution patterns; PASS = Desktop-safe instruction-only,
  FLAG = Code-terminal-only. Threshold: >= 4 PASS or `make check` fails. Both
  targets wired into `make check`; `validate-skills-desktop` runs as a
  dedicated CI step.

- **Desktop-only auto-routing** (`scripts/install.sh --skills-only`) — DESK-03:
  Phase 27. Users without `claude` on PATH running the installer (no flags) are
  auto-routed to `--skills-only` mode; skills land at
  `~/.claude/plugins/tk-skills/<name>/` (Desktop install location) instead of
  `~/.claude/skills/<name>/`. One-line banner explains the routing. Explicit
  `--skills-only` flag also available for users with the CLI who only want
  skills. Hermetic test: `scripts/tests/test-install-tui.sh` S10 scenario.

- **Claude Desktop capability matrix** (`docs/CLAUDE_DESKTOP.md`) — DESK-01:
  Phase 27. Four-column matrix (Capability x Desktop Code Tab x Desktop Chat
  Tab x Code Terminal) covering skills, slash commands, MCPs, statusline,
  security pack, and framework rules. Plain-English explanation of why Chat
  tab and remote Code sessions block plugins. Read-time target: under one
  minute.

- **Marketplace install documentation** (`README.md`, `docs/INSTALL.md`) —
  MKT-04: Phase 27. README and INSTALL.md gain "Install via marketplace"
  sections alongside the existing curl-bash install. Both channels documented
  as equivalent for terminal Code users; marketplace is the only path for
  Desktop users.

### Changed

- **Manifest version** bumped from 4.4.0 to 4.6.0 (final v4.5 milestone bump).
  `init-local.sh --version` derives from manifest at runtime, so no script
  changes needed.

- **`make check` chain** extended with `validate-skills-desktop` (always
  runs) and `validate-marketplace` (runs `claude plugin marketplace add ./`
  when `TK_HAS_CLAUDE_CLI=1`, no-op skip otherwise).

- **CI workflow** (`quality.yml`) gains a dedicated
  `DESK-02/DESK-04 — Skills Desktop-safety audit` step.

## [4.5.0] - 2026-04-29

### Phase 24 Sub-Phase 1 — Globalize Council artifacts

#### Added

- **Global `/council` slash command** — `setup-council.sh` and
  `init-claude.sh::setup_council` now download `commands/council.md`
  upstream into `~/.claude/commands/` (alongside the existing
  `~/.claude/council/brain.py`, `~/.claude/council/config.json`, and
  `~/.claude/council/prompts/audit-review.md` artifacts). Idempotent +
  mtime-aware download mirrors the `prompts/audit-review.md` pattern.
  Result: one global Council install drives every project, no per-project
  duplication.

- **`scripts/lib/cli-recommendations.sh`** — shared helper that detects
  whether `gemini` (Gemini CLI) and `codex` (Codex CLI) are on `$PATH`
  and prints install hints for whichever is missing. Sourced by both
  `setup-council.sh` and `init-claude.sh::setup_council`. Output is
  appended to `~/.claude/council/setup.log` for later auditing.
  Detection is informational only — never blocks setup.

- **Supreme Council section in `templates/global/CLAUDE.md`** —
  new section 15, with `## 16. USER PREFERENCES` renumbered from 15.
  Carries the v4.4 per-project Council description verbatim;
  Sub-Phase 2 will rewrite the body around the FP-recheck mandate.

- **Stale per-project `council.md` cleanup** in
  `scripts/migrate-to-complement.sh` — runs at the dry-run preview, the
  "no SP/GSD duplicates found" early exit, and the production tail.
  Detects `./.claude/commands/council.md` left over from v4.4 installs,
  warns when a global counterpart with different sha256 exists (possible
  user customization), and prompts for interactive removal. `--yes`
  accepts automatically; idempotent on re-run.

- **`verify-install.sh` Council checks** — Section 5 now verifies
  `~/.claude/commands/council.md` exists, `brain.py` is `+x`,
  `config.json` permissions are `0600` (BSD `stat -f %Lp` with GNU
  `stat -c %a` fallback), and `alias brain=` is declared in
  `.zshrc` / `.bash_profile` / `.bashrc`.

#### Changed

- **Per-project `commands/council.md` no longer ships** — removed from
  `manifest.json::files.commands[]`. Smart-update / fresh installs no
  longer copy it into `./.claude/commands/`. Existing v4.4 installs keep
  their local copy until `migrate-to-complement.sh` is run.
- **`templates/{base,go,laravel,nextjs,nodejs,python,rails}/CLAUDE.md`** —
  `## Supreme Council (Optional)` body shrinks to a one-line pointer
  (`> Supreme Council is global — see ~/.claude/CLAUDE.md ...`). Heading
  drops the `(Optional)` suffix to match
  `manifest.json::claude_md_sections.system`.
- **`scripts/validate-manifest.py`** — new `GLOBAL_ONLY_COMMANDS` set
  exempts `council.md` from the disk-to-manifest drift check so the file
  can stay in `commands/` for upstream curl fetches without re-triggering
  drift.
- **`README.md`** — Killer Features row notes `/council` is now installed
  globally to `~/.claude/commands/`.

#### Notes

This release closes Phase 24 Sub-Phase 1 (Globalize Council artifacts).
Sub-Phases 2–11 (file-based prompts, FP-recheck, context enrichment,
cost tracking, OpenRouter / Codex CLI fallback, caching, GSD
integration, QoL flags, multilingual prompts, MCP server) follow under
the same v4.5.0 heading as they ship.

## [4.4.0] - 2026-04-27

### Added

- **SP/GSD bootstrap installer** (`scripts/lib/bootstrap.sh`, `scripts/lib/optional-plugins.sh`) —
  BOOTSTRAP-01..04: `init-claude.sh` and `init-local.sh` now offer to install `superpowers`
  via `claude plugin install superpowers@claude-plugins-official` and `get-shit-done` via the
  canonical curl install before detection runs. Prompts default to `N`, fail closed when no
  TTY is available, and `--no-bootstrap` (or `TK_NO_BOOTSTRAP=1`) suppresses them entirely
  for CI. After bootstrap, `detect.sh` re-runs so the toolkit installs in the correct mode
  (`complement-sp` / `complement-gsd` / `complement-full`). Hermetic test:
  `scripts/tests/test-bootstrap.sh` (Test 28).

- **Smart-update coverage for `scripts/lib/*.sh`** — LIB-01: all six sourced helper libraries
  (`backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`,
  `state.sh`) registered in `manifest.json` under a new `files.libs[]` array. LIB-02:
  `update-claude.sh` now refreshes stale lib files using the same diff/backup/safe-write
  contract as top-level scripts — zero code changes to the update loop required (the existing
  `jq -c '[.files | to_entries[] | .value[] | .path]'` query auto-discovers the new key).
  Hermetic test: `scripts/tests/test-update-libs.sh` (Test 29) — five scenarios proving
  stale-refresh, clean-untouched, fresh-install, modified-file fail-closed, and uninstall
  round-trip across all six libs.

- **`--no-banner` flag for `init-claude.sh` and `init-local.sh`** — BANNER-01: both
  installers now accept `--no-banner` (and the `NO_BANNER=1` env var) to suppress the
  closing `To remove: bash <(curl …)` line. Default behaviour (flag absent) is byte-identical
  to v4.3. Symmetric with `update-claude.sh`, which already honoured this flag. Hermetic test:
  `scripts/tests/test-install-banner.sh` extended from 3 to 7 source-grep assertions
  covering the new defaults, argparse clauses, and gates in both init scripts.

- **`--keep-state` flag for `scripts/uninstall.sh`** — KEEP-01: passing `--keep-state`
  (or setting `TK_UNINSTALL_KEEP_STATE=1`) preserves `~/.claude/toolkit-install.json`
  after the run instead of deleting it as the LAST step. All other UN-01..UN-08 invariants
  (backup, sentinel-strip, base-plugin diff-q) are unchanged. A subsequent `uninstall.sh`
  invocation sees the state file, re-classifies still-present modified files, and re-presents
  the `[y/N/d]` prompt — enabling recovery after a partial-N uninstall session.

- **Hermetic test for `--keep-state`** — KEEP-02: `scripts/tests/test-uninstall-keep-state.sh`
  (Test 30) proves three scenarios end-to-end: N-choice preserves state and second run
  re-classifies modified files (S1: A1+A2+A3+A4); y-choice preserves state on full-y branch
  (S2: A1); `TK_UNINSTALL_KEEP_STATE=1` env-only path preserves state with no `--keep-state`
  flag (S3: A1, D-09 env-precedence).

## [4.3.0] - 2026-04-26

### Added

- **Uninstall script** (`scripts/uninstall.sh`) — single command to safely remove every
  toolkit-installed file from a project's `.claude/` while preserving user modifications
  and base plugins (`superpowers`, `get-shit-done`).
  - UN-01: removes registered files only when current SHA256 matches the recorded hash;
    files outside the project's `.claude/` and inside base-plugin trees are never touched
  - UN-02: `--dry-run` prints a 4-group preview (REMOVE / KEEP / MODIFIED / MISSING) and
    exits 0 with zero filesystem changes
  - UN-03: modified files trigger a `[y/N/d]` prompt read from `< /dev/tty`; default `N`
    keeps the file, `d` shows a diff against the manifest reference and re-prompts
  - UN-04: full `.claude/` backup written to `~/.claude-backup-pre-uninstall-<unix-ts>/`
    before any delete; `--no-backup` flag does not exist

- **State cleanup + idempotency**
  - UN-05: deletes `~/.claude/toolkit-install.json` after successful removal and strips
    any `<!-- TOOLKIT-START -->`…`<!-- TOOLKIT-END -->` block from `~/.claude/CLAUDE.md`;
    user-authored sections preserved verbatim
  - UN-06: second invocation detects missing state file, prints
    `✓ Toolkit not installed; nothing to do`, exits 0, creates no backup directory

- **Distribution** — `manifest.json` registers `scripts/uninstall.sh` under
  `files.scripts[]`; `init-claude.sh`, `init-local.sh`, and `update-claude.sh` end-of-run
  banners include the line
  `To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)`
  (UN-07).

- **Round-trip integration test** — `scripts/tests/test-uninstall.sh` (Makefile Test 24)
  exercises the full install→uninstall round-trip across 5 scenario blocks; new
  `scripts/tests/test-install-banner.sh` (Test 25) gates banner presence in all 3
  installers (UN-08).

## [4.2.0] - 2026-04-26

### Added

- **Persistent FP allowlist** — `.claude/rules/audit-exceptions.md` auto-seeds via `globs: ["**/*"]`
  and is consulted by `/audit` Phase 0 to drop known false positives before reporting (EXC-01..05).
- **`/audit-skip <file:line> <rule> <reason>`** — appends a structured exception block to
  `audit-exceptions.md` after validating the file:line exists in the working tree and that the
  entry is not already allowlisted.
- **`/audit-restore <file:line> <rule>`** — comment-aware removal of an allowlist entry with a
  `[y/N]` confirmation prompt.
- **6-phase `/audit` workflow** — load context → quick check → deep analysis → 6-step FP recheck
  → structured report → mandatory Council pass. Every reported finding survives the FP-recheck and
  ships with verbatim ±10 lines of source code so the Council reasons from the code, not the rule
  label.
- **Structured audit reports** — `/audit` writes to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md`
  with a fixed schema: Summary table → Findings (ID, severity, rule, location, claim, verbatim
  code, data flow, "why it's real", suggested fix) → Skipped (allowlist) → Skipped (FP recheck)
  → Council verdict slot.
- **Mandatory Supreme Council `audit-review` mode** — every `/audit` run terminates in
  `/council audit-review --report <path>`. Council emits per-finding
  `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT` verdicts with confidence scores in `[0.0, 1.0]`,
  plus a "Missed findings" section. Severity reclassification is explicitly forbidden (COUNCIL-02).
- **`brain.py --mode audit-review`** — runs Gemini and ChatGPT in parallel for audit-review, flags
  per-finding disagreements as `disputed` without auto-resolution.
- **Template propagation across all 49 prompt files** — every
  `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md`
  carries the audit-exceptions callout, 6-step FP-recheck SELF-CHECK, structured OUTPUT FORMAT,
  and Council Handoff footer.

### Changed

- **`manifest.json`** — bumped to `4.2.0` and registered `templates/base/rules/audit-exceptions.md`
  under `files.rules`.
- **`commands/audit.md`** — rewritten around the 6-phase workflow; documents the Council Handoff UX
  (FALSE_POSITIVE nudge → user runs `/audit-skip`; disputed verdict prompt).
- **`commands/council.md`** — added `## Modes` section with `audit-review` subsection documenting
  input format (path to structured audit report), expected Council prompt, and verdict-table output
  schema.

### Fixed

- *None — this is an additive feature release. See [4.1.1] for the prior patch.*

### Documentation

- **CI gates** — `make validate` now asserts every audit prompt carries the `Council Handoff`
  marker plus all six numbered FP-recheck steps; missing markers fail the build (TEMPLATE-03).
- **`make test`** — adds Test 18 (audit pipeline fixture), Test 19 (Council audit-review
  verdict-slot rewrite + parallel dispatch), Test 20 (template propagation idempotency).

## [4.1.1] - 2026-04-25

### Fixed

- **CRIT-01** — Replaced fragile 95-line emoji-anchored sed smart-merge in `update-claude.sh` with chezmoi-style `.new` flow. Toolkit never touches user `CLAUDE.md`; updates land as `CLAUDE.md.new` for manual review/merge.
- **CRIT-02** — Aligned `manifest.json` version with v4.1.0 git tag.
- **C-01..C-10** — Lock TOCTOU fix in `state.sh`, atomic state-write with manifest_hash, `curl -sSLf` (fail on HTTP 4xx/5xx) across all installers, anchored regex in `setup-security.sh`, JSON-based plugin presence check.
- **Sec-H1** — Anthropic OAuth Bearer token moved off `curl` argv. Written to `mktemp` header file with `chmod 600`, passed via `-H @file`. EXIT trap cleans up.
- **BRAIN-H1..H4, M1, M2, M5** — `brain.py` corrected docstring, `Path.relative_to` validation, stdin body, header-file auth (chmod 0o600), partial-Council fallback (one provider failure → use surviving verdict), per-provider availability flags.
- **S-01** — All hook scripts in `templates/*/settings.json` read `f=$(jq -r '.tool_input.file_path // empty')` from STDIN. Removed undefined `$FILE_PATH` references.
- **PERF-02** — `sha256_file` prefers `sha256sum` → `shasum -a 256` → chunked Python fallback.
- **T-02, T-05** — New regression suite `test-claude-md-new.sh` (19 assertions, 7 scenarios). CI matrix extended to `[ubuntu-latest, macos-latest]` for `test-init-script` job.
- **M-03** — `make shellcheck` extended to `templates/global/`.

### Notes

Patch release closing 53 audit findings (2 CRIT, 14 HIGH, 20 MED, 17 LOW) cross-reviewed by Supreme Council. Council follow-up applied 4 additional refinements (passes A/B/C/D).

## [4.1.0] - 2026-04-25

### Added

- Phase 11 UX polish: chezmoi-grade dry-run preview with `[+ ADD]` / `[~ MOD]` / `[- REMOVE]` grouping for both `install` and `update` flows.
- `migrate-to-complement.sh --dry-run` now emits the same grouped preview before any destructive change.
- New audit pipeline (`AUDIT-REPORT.md`) — full deep audit covering security, correctness, performance, portability, JSON state-file integrity. Cross-AI reviewed via Supreme Council (Gemini Skeptic + ChatGPT Pragmatist).

### Fixed

- `manifest.json` `version` and `updated` fields now match the `v4.1.0` git tag (previously drifted at `4.0.0` / `2026-04-19`).

### Notes

This release closes the v4.1 milestone. See `.planning/archived/v4.1/` for phase artifacts.

## [4.0.0] - 2026-04-21

### BREAKING CHANGES

- **Default install behavior changes when SP and/or GSD are detected.** Previously (v3.x) all
  54 TK files installed unconditionally. v4.0 auto-selects `complement-*` mode and skips 7 files
  (6 commands/skills + 1 agent) that duplicate SP functionality. Users who relied on TK's
  `/debug`, `/plan`, `/tdd`, `/verify`, `/worktree`, `skills/debugging`, or TK-owned
  `agents/code-reviewer.md` will instead use SP's equivalents. Override: `--mode standalone`.
- **7 files are no longer installed in `complement-sp` mode:** `agents/code-reviewer.md`,
  `commands/debug.md`, `commands/plan.md`, `commands/tdd.md`, `commands/verify.md`,
  `commands/worktree.md`, `skills/debugging/SKILL.md`. Users relying on TK's copies must use
  SP's equivalents.
- **`manifest.json` schema bumped from v1 (implicit) to v2 (explicit `manifest_version: 2`).**
  Old v3.x install scripts refuse to run against a v2 manifest. Users running an old installer
  against the v4.0 repo see a hard error: `manifest.json has manifest_version=2; this installer
  expects v1`.
- **`toolkit-install.json` state schema bumped v1 → v2.** v1 installs read correctly via
  `jq '... // false'` backwards-compat default on the new `synthesized_from_filesystem` field,
  but v1 tooling reading the new field directly will see `null`.
- **`scripts/init-local.sh` no longer hardcodes version.** Reads from `manifest.json` at runtime
  via `jq`. The `VERSION="2.0.0"` constant is removed from line 11.
- **`scripts/update-claude.sh` no longer hand-iterates a file list.** The iterated list now comes
  from `manifest.json`. Custom TK installs that relied on update-claude.sh skipping certain files
  will see those files installed on next update (if listed in manifest).
- **`~/.claude/settings.json` is now merged additively.** `setup-security.sh` no longer overwrites
  the file — it reads, merges only TK-owned keys (permissions.deny, hooks.PreToolUse, env block),
  and writes via atomic temp-file rename.
- **Post-update summary format changed** from unstructured log lines to a 4-group block
  (`INSTALLED N`, `UPDATED M`, `SKIPPED P (with reason)`, `REMOVED Q (backed up to path)`).
  Users who scrape update output must adjust. Backup directories are now suffixed with PID
  (`~/.claude-backup-<unix-ts>-<pid>/`) to prevent same-second collision.

### Added

- `scripts/detect.sh` — filesystem detection of `superpowers` and `get-shit-done`; sources
  `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` environment variables.
- `scripts/lib/install.sh` — `recommend_mode`, `compute_skip_set`, `MODES` array for
  mode-aware installs.
- `scripts/lib/state.sh` — atomic `write_state`, `acquire_lock`, `release_lock`, `sha256_file`
  for install-state management.
- `scripts/migrate-to-complement.sh` — one-time migration for v3.x users with SP/GSD installed;
  three-column hash diff, `[y/N/d]` per-file prompt, `cp -R` full backup, idempotent.
- `~/.claude/toolkit-install.json` — install state file: mode, detected bases, installed files
  with sha256 hashes, skipped files with reasons. Schema v2 adds `synthesized_from_filesystem`.
- 4 install modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`.
- `--mode <name>` flag on `init-claude.sh` and `init-local.sh` — overrides auto-detected mode
  with interactive prompt and auto-recommendation.
- `--dry-run` flag on `init-claude.sh` — previews `[INSTALL]`/`[SKIP]` per file without writing.
- `--offer-mode-switch=yes|no|interactive`, `--prune=yes|no|interactive`, `--no-banner` flags
  on `update-claude.sh`.
- `conflicts_with`, `sp_equivalent`, `requires_base` fields on per-file manifest entries.
- `make validate-manifest.py` check — every manifest path exists, `conflicts_with` values are
  from the known plugin set.
- Makefile test targets: 14 test groups (up from 0), all hermetic — covering detect, install,
  state, update drift, update diff, update summary, migrate diff, migrate flow, migrate idempotence.
- `components/orchestration-pattern.md` — lean orchestrator + fat subagents pattern.
- `components/optional-plugins.md` — rtk, caveman, superpowers, get-shit-done recommendations
  with verified caveats.
- `templates/global/RTK.md` — fallback RTK notes with rtk-ai/rtk#1276 caveat and workaround.
- `## Required Base Plugins` section in all 7 `templates/*/CLAUDE.md` files — discloses SP/GSD
  dependency and install commands so new users set up the full complement stack first.
- `manifest.json` `inventory.components` bucket (non-install metadata for Phase 6 components).
- `Makefile validate-base-plugins` drift guard — verifies all 7 templates carry the section
  heading on every `make check`.

### Changed

- `scripts/init-claude.sh` — refactored to 4-mode dispatch; sources `detect.sh` +
  `lib/install.sh` from `$REPO_URL` on remote installs; respects `--mode` override;
  manifest-schema-v2 guard hard-fails on v1 manifests.
- `scripts/init-local.sh` — same mode-aware logic as `init-claude.sh`; reads version from
  `manifest.json` at runtime (removes `VERSION="2.0.0"` hardcode).
- `scripts/update-claude.sh` — rewritten for re-detection on every run, mode-drift surfacing,
  manifest-driven iteration, 4-group summary, D-77 migrate hint when complement migration
  is appropriate.
- `scripts/setup-security.sh` — safe `~/.claude/settings.json` merge with timestamped backup
  (`settings.json.bak.<unix-ts>`); restore-on-merge-failure.
- `scripts/setup-council.sh` — `< /dev/tty` guards on every interactive `read`; silent
  `read -rs` for API-key prompts; `python3 json.dumps()` for API-key heredoc interpolation.
- `README.md` — repositioned as "complement to superpowers + get-shit-done"; install section
  shows standalone + complement modes with one paragraph of guidance per mode.
- `manifest.json` — schema v2 (`manifest_version: 2`); 7 entries gain `conflicts_with`; 6
  entries gain `sp_equivalent`.

### Fixed

- BUG-01: BSD-incompatible `head -n -1` in `scripts/update-claude.sh` smart-merge replaced
  with POSIX `sed '$d'`. Silent CLAUDE.md truncation on macOS fixed.
- BUG-02: `< /dev/tty` guards on every interactive `read` in `scripts/setup-council.sh`;
  silent `read -rs` for API-key prompts. Fixes curl|bash prompts being consumed as stream.
- BUG-03: `python3 json.dumps` JSON-escapes API keys containing `"`, `\`, newline in
  heredoc-written `config.json`. Fixes malformed Council config.
- BUG-04: Silent `sudo apt-get install tree` in `setup-council.sh` replaced with interactive
  prompt and visible error path.
- BUG-05: `setup-security.sh` timestamped backup of `~/.claude/settings.json` before every
  mutation; restore-on-merge-failure.
- BUG-06: `scripts/init-local.sh` reads version from `manifest.json`; `make validate`
  enforces manifest ↔ CHANGELOG version alignment.
- BUG-07: `commands/design.md` added to `update-claude.sh` loop (structurally fixed in
  Phase 4: update loop now iterates manifest, not a hand-list).

### Migration from v3.x

See [docs/INSTALL.md](docs/INSTALL.md) for the install matrix and `scripts/migrate-to-complement.sh`
for the automated migration path (per-file confirmation, full backup before any removal).

## [3.0.0] - 2026-02-16

### Added

- **Supreme Council** — multi-AI code review system (Gemini + ChatGPT)
  - `brain.py` orchestrator: sends plans to Gemini (Architect) and ChatGPT (Critic)
  - 4-phase review: Context Discovery → Architectural Audit → Second Opinion → Final Report
  - Security-hardened vs original: no hardcoded keys, no shell=True, temp file cleanup, input validation
  - Configurable models via `~/.claude/council/config.json` with env var overrides
  - Gemini modes: CLI (free with subscription) or API
  - Path traversal protection, file size limits, command timeouts
- **`/council` command** — multi-AI pre-implementation review
  - Run before coding high-stakes features (auth, payments, refactoring)
  - Outputs APPROVED/REJECTED report to `.claude/scratchpad/council-report.md`
- **`setup-council.sh`** — installation script
  - Dependency checks (Python 3.8+, tree, curl)
  - Interactive Gemini mode selection (CLI vs API)
  - API key configuration (prompt + env var support)
  - Automatic `brain` shell alias
  - Installation verification
- **Supreme Council component** — `components/supreme-council.md`
  - Full documentation: how it works, when to use, configuration, security improvements
- Supreme Council section in base CLAUDE.md template
- `/council` command distributed to all projects via init-claude.sh

### Changed

- Updated README: 26 → 29 slash commands, added Supreme Council to features and quick start
- Updated `manifest.json` to v3.0.0
- Updated `init-claude.sh` with council command and setup recommendation

## [2.8.0] - 2026-02-06

### Added

- **Production Safety Guide** — new component `components/production-safety.md`
  - Deployment safety: incremental deploy pattern, pre/post-deploy verification
  - Queue and worker safety: rolling restarts, check before modify, test on subset
  - Bug fix approach: simplest solution first, rule of three attempts
  - File targeting: verify correct variant, branch, upstream status
  - Rollback decision framework: when to rollback vs hotfix
- **`/deploy` command** — safe deployment workflow with 4 phases
  - Pre-deploy: git state, conflict check, tests, build
  - Deploy: framework-specific steps with rolling worker restart
  - Post-deploy: smoke tests, log check, worker status
  - Rollback decision: automatic verification with user approval
  - Framework auto-detection (Laravel, Next.js, Node.js, Python, Go)
- **`/fix-prod` command** — production hotfix workflow
  - Diagnose first (gather evidence, identify scope, rollback decision)
  - Minimal change rule (fix only the broken thing)
  - Post-fix monitoring (immediate + short-term)
  - Common production issues quick reference
- **Production Safety section** in all 7 CLAUDE.md templates
  - Bug Fix Approach rules
  - Deployment safety rules
  - File Targeting checklist
  - Laravel template: extra Queue and Worker Safety subsection
- Inspired by insights from 94 Claude Code sessions (1,307 messages)

### Changed

- Updated Quick Commands table in all templates (+2 commands: `/deploy`, `/fix-prod`)
- Updated README: 24 → 26 slash commands, 23+ → 24+ guides
- Updated `docs/features.md` with Production Safety section and new commands
- Updated `manifest.json` to v2.8.0 with Production Safety section

## [2.6.0] - 2026-01-23

### Added

- **Compact Instructions** — section for preserving critical rules during `/compact`
  - Added to all CLAUDE.md templates (base, laravel, nextjs)
  - 4-5 key rules that should be preserved after compaction
  - Security, Architecture, Workflow, Git + framework-specific
- **AI Models skill** — extracted from CLAUDE.md into separate skill
  - `skills/ai-models/SKILL.md` — loaded on demand
  - Claude 4.5 (Opus, Sonnet, Haiku) with model IDs
  - Gemini 3 (Pro, Flash) with model IDs
  - Code examples for Python, TypeScript, PHP
- **Available Skills** section in CLAUDE.md templates
- **DATABASE_PERFORMANCE_AUDIT.md** — renamed and moved to `templates/*/prompts/`

### Changed

- **README.md** — reorganized section order:
  Who Is This For → Quick Start → Key Concepts → Structure → What's Inside → MCP → Examples
- Templates in "What's Inside" is now the first item
- Security audit example uses `/audit security`
- Updated audit count: 5 → 6 (added Database)
- CLAUDE.md templates reduced by 10-20%

### Fixed

- Markdown syntax issues in laravel template

## [2.5.0] - 2026-01-23

### Added

- **`/verify` command** — quick check before PR
  - Build, types, lint, tests in one command
  - Modes: `quick`, `full`, `pre-commit`, `pre-pr`
  - Security scan for pre-pr mode
  - Auto-detection of framework (Laravel, Next.js, Node.js)
- **`/learn` command** — extracting and saving patterns
  - Saves problem solutions to `.claude/rules/lessons-learned.md` (auto-loaded)
  - Integration with Memory Bank and Knowledge Graph
  - Pattern types: error resolution, workarounds, debugging, user corrections
  - **Mistakes & Learnings** pattern (Error → Learning → Prevention) from loki-mode
  - Self-Correction Protocol for automatic learning from mistakes
- **`/debug` command** — systematic debugging process
  - 4 phases: Root Cause → Pattern Analysis → Hypothesis → Implementation
  - Rule "3+ fixes = architectural problem"
  - Common Rationalizations table
  - Inspired by [superpowers](https://github.com/obra/superpowers)
- **`/worktree` command** — git worktrees management
  - Actions: create, list, remove, cleanup
  - Supplement to existing `components/git-worktrees-guide.md`
- **Enhanced Security Audit** — concepts from Trail of Bits
  - "Context before vulnerabilities" principle
  - Codebase Size Strategy (SMALL/MEDIUM/LARGE)
  - Risk Level Triggers (HIGH/MEDIUM/LOW)
  - Rationalizations table
  - Sharp Edges section (API footguns)
  - Red Flags for immediate escalation
- **Hooks Auto-Activation** — automatic skills activation (`components/hooks-auto-activation.md`)
  - **Scoring system** — different triggers give different points (keywords: 2, intentPatterns: 4, pathPatterns: 5)
  - **Confidence levels** — HIGH/MEDIUM/LOW based on score
  - **Threshold filtering** — minConfidenceScore, maxSkillsToShow
  - **Exclude patterns** — false positives prevention
  - **JSON Schema** — validation and IDE autocomplete
  - TypeScript implementation with examples
  - Inspired by [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)
- **Modular Skills** — progressive disclosure (`components/modular-skills.md`)
  - Splitting large guidelines into modules
  - Navigation table in main SKILL.md
  - Resources loaded on demand
  - 60-85% token savings
- **Skill Accumulation** — self-learning system (`components/skill-accumulation.md`)
  - Automatic skill creation when patterns are detected
  - Updating existing skills on user corrections
  - Proposal formats for creation/update
  - Templates in `templates/base/skills/`
- **Design Review** — UI/UX audit with Playwright MCP (`templates/*/prompts/DESIGN_REVIEW.md`)
  - 7-phase review process (Preparation → Interaction → Responsiveness → Visual → Accessibility → Robustness → Code)
  - Triage matrix: [Blocker], [High], [Medium], [Nitpick]
  - WCAG 2.1 AA accessibility checks
  - Responsive testing (1440px, 768px, 375px)
  - Next.js specific version with hydration, next/image, Tailwind checks
  - Inspired by [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)
- **Structured Workflow** — 3-phase development approach (`components/structured-workflow.md`)
  - Phase 1: RESEARCH (read-only) — only Glob, Grep, Read
  - Phase 2: PLAN (scratchpad-only) — plan in `.claude/scratchpad/`
  - Phase 3: EXECUTE (full access) — after confirmation
  - Explicit tool restrictions by phase
  - Plan template with checkboxes
  - Inspired by [RIPER-5](https://github.com/tony/claude-code-riper-5)
- **Smoke Tests Guide** — minimal tests for API (`components/smoke-tests-guide.md`)
  - What to test: health, auth, core CRUD
  - Examples for Laravel (Pest), Next.js (Vitest), Node.js (Jest)
  - GitHub Actions workflow
  - Checklist for new project
- Inspired by [everything-claude-code](https://github.com/affaan-m/everything-claude-code), [superpowers](https://github.com/obra/superpowers), [Trail of Bits](https://github.com/trailofbits/skills), [loki-mode](https://github.com/asklokesh/loki-mode), [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)

### Changed

- Updated README with `/verify` and `/learn` in commands table
- Added Quick Commands section to all templates

## [2.4.0] - 2026-01-22

### Added

- **Gemini 3 models support** — AI Models section now includes both Claude and Gemini
  - Claude 4.5: Opus, Sonnet, Haiku
  - Gemini 3: Pro, Flash
  - Code examples for both providers (Python, PHP, TypeScript)
  - Deprecation warning for old versions (Claude 3.5/4.0, Gemini 1.x/2.x)
- **Architecture Guidelines (STRICT!)** section in all templates:
  - KISS Principle — simplest working solution
  - YAGNI — no features "for the future"
  - No Boilerplate — no Interfaces/Factories/DTOs unless requested
  - File Structure — prefer larger files, ask before creating new files
- **Coding Style** section:
  - Functional programming over complex OOP
  - Don't over-split functions (50 lines is fine)
  - One file doing one thing well > 5 files with abstractions
- **Bootstrap Workflow** documentation:
  - New section in README.md
  - New component `components/bootstrap-workflow.md`
  - Correct order: IDEA → STACK → INSTRUCTIONS → ADAPTATION
  - Example prompts for Laravel and Next.js projects
- **Knowledge Persistence** pattern — save knowledge to 3 places:
  - CLAUDE.md (for Claude Code)
  - docs/README (for humans)
  - MCP Memory (for persistence between sessions)
- **CHANGELOG rule** in Git Workflow — update on `feat:`, `fix:`, breaking changes
- **`/install` command** — quick installation from Claude Guides repository

### Changed

- Renamed "Claude Models" section to "AI Models" in all templates
- Updated all CLAUDE.md templates with new guidelines

## [2.3.0] - 2026-01-22

### Added

- Memory Persistence system — MCP memory sync with Git
  - New component `components/memory-persistence.md` with full documentation
  - Template files in `templates/*/memory/`:
    - `README.md` — sync instructions for each project
    - `knowledge-graph.json` — Knowledge Graph export template
    - `project-context.md` — Memory Bank context template
- Session start workflow in all CLAUDE.md templates:
  - Check MCP vs git sync dates
  - Read project memory from MCP
  - Load Knowledge Graph relationships

### Changed

- Updated all CLAUDE.md templates (base, laravel, nextjs):
  - Added "AT THE START OF EACH SESSION" section with sync check
  - Added pre-commit sync instructions in Knowledge Persistence
  - Added immediate sync rule after MCP changes
- Updated `mcp-servers-guide.md` with Git sync section
- Updated README.md with Memory Persistence subsection

## [2.2.0] - 2026-01-21

### Added

- Knowledge Graph Memory MCP server (`@modelcontextprotocol/server-memory`)
  - Builds entity relationships instead of simple key-value storage
  - Best suited for Claude Opus 4.5 architectural analysis
- Spec-Driven Development component (`components/spec-driven-development.md`)
  - Write specifications before code
  - Template for .spec.md files
  - Workflow: spec → review → implement
- `.claude/specs/` directory structure for projects

### Changed

- Updated MCP servers guide with Knowledge Graph Memory
- Updated README with Spec-Driven Development section

## [2.1.0] - 2026-01-21

### Added

- MCP Servers Guide (`components/mcp-servers-guide.md`)
  - context7 — documentation lookup for libraries
  - playwright — browser automation and UI testing
  - memory-bank — project memory between sessions
  - sequential-thinking — step-by-step problem solving
- Quick install commands for MCP servers in README

## [1.1.0] - 2025-01-13

### Added

- CI/CD with GitHub Actions (shellcheck, markdownlint, template validation)
- `update-claude.sh` script for updating templates in existing projects
- Dry-run mode (`--dry-run`) for init scripts
- More framework detection (Django, Rails, Go, Rust)
- Makefile for development tasks
- Pre-commit hooks configuration
- GitHub issue and PR templates
- New commands: `/fix`, `/explain`, `/test`, `/refactor`, `/migrate`
- Example configurations for Laravel SaaS, Next.js Dashboard, Monorepo
- LICENSE (MIT)
- SECURITY.md
- CONTRIBUTING.md

### Changed

- Improved init scripts with backup functionality
- Better error handling in shell scripts

## [1.0.0] - 2025-01-13

### Added

- Initial release
- Base templates (framework-agnostic):
  - SECURITY_AUDIT.md
  - PERFORMANCE_AUDIT.md
  - CODE_REVIEW.md
  - DEPLOY_CHECKLIST.md
- Laravel-specific templates
- Next.js-specific templates
- Reusable components:
  - severity-levels.md
  - self-check-section.md
  - report-format.md
  - quick-check-scripts.md
- Slash commands: `/doc`, `/find-script`, `/find-function`, `/audit`
- Init scripts (`init-claude.sh`, `init-local.sh`)
- README with usage instructions
