# Requirements — v5.0 Per-MCP Scope + Project Secrets Boundary

**Defined:** 2026-05-04
**Core Value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Milestone goal:** Give the user granular per-MCP scope control (`user` vs `project`) with sensible per-MCP defaults, treat secrets correctly per scope (no literal secrets in any file that lives in a project repo), close the secrets-leak gap on uninstall, and add Calendly to the catalog.

## v5.0 Requirements

Requirements grouped by category. Each maps to exactly one phase via the Traceability table.

### Catalog schema (`scripts/lib/integrations-catalog.json` + validator)

- [x] **SCOPE-01**: New per-entry `default_scope: "user"|"project"` field on every `components.mcp.<name>` block in `integrations-catalog.json`. Validator (`scripts/validate-integrations-catalog.py`) enforces the field is present and value is one of the two enum values for every MCP. CLI-only entries are unaffected (no scope concept for `command -v` checks).
- [x] **SCOPE-02**: Default-scope assignments baked into the catalog as follows. Personal-tooling MCPs default `user`: `firecrawl`, `notebooklm`, `notion`, `youtrack`, `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`. Per-app infra MCPs default `project`: `supabase`, `cloudflare`, `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `jira`, `linear`, `telegram`. Calendly default `user` (personal calendar tooling).
- [x] **SCOPE-03**: Backward-compat fallback in `mcp_catalog_load` (`scripts/lib/mcp.sh`): if a catalog entry lacks `default_scope`, treat it as `user` and emit no warning. Pre-v5.0 catalogs continue to work; pre-existing user installs are not broken.

### TUI per-row scope toggle (`scripts/lib/mcp.sh` + `scripts/lib/tui.sh`)

- [ ] **TUI-SCOPE-01**: Each MCP row in the integrations TUI carries a scope indicator immediately after the checkbox: `[U]` (user-scope), `[P]` (project-scope), `[L]` (legacy local-to-cwd). Indicator is colored green for the chosen scope. NO_COLOR-aware (plain bracket form when `NO_COLOR` is set).
- [ ] **TUI-SCOPE-02**: Hotkey to flip the scope of the currently-highlighted row only. Suggested binding: `Tab` (cycle U → P → L → U) or `Shift-S`. Final binding chosen during planning; documented in TUI hint footer either way.
- [ ] **TUI-SCOPE-03**: Existing global header `s` keypress (Phase 37, commit `fc000d5`) repurposed as "set ALL visible rows to scope X" shortcut — pressing `s` cycles a global scope value and assigns it to every row in one stroke. Banner updated to read `s: set all to <scope>` instead of the previous toggle copy.
- [ ] **TUI-SCOPE-04**: Per-row scope state stored in a parallel array `MCP_SELECTED_SCOPE[]` (parallel to `MCP_NAMES`/`MCP_STATUS`/`MCP_HAS_CLI`). Initialized from `default_scope` at TUI launch via `mcp_status_array`. Bash 3.2 compat (no associative arrays).
- [ ] **TUI-SCOPE-05**: Dispatcher (`install.sh` MCP install loop) reads `MCP_SELECTED_SCOPE[$i]` per row before invoking `mcp_wizard_run`, exporting `TK_MCP_SCOPE=<scope>` for that single invocation. The pre-v5.0 single-shell `TK_MCP_SCOPE` global is retired in favor of per-call injection (still honored on the CLI for `--mcp-scope <s>` non-interactive force-set).

### Project secrets writer (`scripts/lib/project-secrets.sh` — new lib)

- [ ] **SEC-01**: New library `scripts/lib/project-secrets.sh` exposes three functions: `project_secrets_write_env <project_root> <KEY> <VALUE>`, `project_secrets_ensure_gitignore <project_root>`, `project_secrets_render_mcp_env_block <KEY...>`. Read-only callers can `source` it without side effects.
- [ ] **SEC-02**: `project_secrets_write_env` writes `KEY=VALUE` to `<project_root>/.env`. File created if absent (mode 0600 enforced via `touch && chmod 0600` BEFORE first write). Idempotent merge: if `KEY` already exists in the file, prompt `[y/N] Overwrite KEY in <project>/.env?` reusing the v4.3 UN-03 `< /dev/tty` + fail-closed-N contract. Default N preserves existing value.
- [ ] **SEC-03**: `project_secrets_ensure_gitignore` checks `<project_root>/.gitignore` for an exact `.env` line (not `*.env`, not commented). If absent, appends `.env\n` with a leading comment `# claude-code-toolkit: never commit project-scope MCP secrets`. Creates `.gitignore` if missing. Idempotent on re-run.
- [ ] **SEC-04**: `project_secrets_render_mcp_env_block <KEY1> <KEY2> ...` returns a JSON object string `{"KEY1": "${KEY1}", "KEY2": "${KEY2}"}` for embedding into `.mcp.json` as the `env` field. The `${VAR}` form is the Claude Code substitution convention — `claude` resolves the var from the environment at MCP launch.
- [ ] **SEC-05**: Defense-in-depth literal-secret refusal: any function that writes to `.mcp.json` (whether in this lib or in the wizard) MUST refuse to write a string value into an `env` block that does not match the regex `^\$\{[A-Z_][A-Z0-9_]*\}$`. Refusal returns rc=1 with `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)` to stderr. Test seam `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` exists for hermetic tests only and prints a one-line warning when honored.
- [ ] **SEC-06**: `project_secrets_write_env` rejects any `VALUE` containing shell metacharacters (`$`, backtick, backslash, double-quote, single-quote, newline) — same allow-list as `_mcp_validate_value` in `mcp.sh`. Reuses or refactors the existing helper to share the rule.

### Wizard dispatch update (`scripts/lib/mcp.sh::mcp_wizard_run`)

- [ ] **DISP-01**: `mcp_wizard_run` reads `TK_MCP_SCOPE`. When `TK_MCP_SCOPE=project`, the wizard:
  - Resolves `project_root` from `pwd` (or `TK_PROJECT_ROOT` test seam).
  - Collects each env-var via the existing hidden-input prompt loop (3-attempt, mask-display) — unchanged from v4.6 MCP-04.
  - Calls `project_secrets_write_env` per key (writes to `<project>/.env`).
  - Calls `project_secrets_ensure_gitignore` once before the first write.
  - Invokes `claude mcp add --scope project ...` with the env block rendered as `${VAR}` substitution form (NOT literal values). Claude CLI is responsible for writing `.mcp.json` from those args; toolkit verifies the resulting file does not contain literal secrets via SEC-05.
- [ ] **DISP-02**: When `TK_MCP_SCOPE=user` or `TK_MCP_SCOPE=local` (or unset), wizard preserves v4.6/v4.9 behavior: write to `~/.claude/mcp-config.env` via `mcp_secrets_set`, invoke `claude mcp add --scope <user|local>` with literal env values exported via `env KEY=V`. No regression on existing flow.
- [ ] **DISP-03**: Defer-secrets path (`TK_MCP_DEFER_SECRETS=1`, set by install.sh during dispatch) extended for `project` scope: still pre-creates blank stub entries, but in `<project>/.env` (not `mcp-config.env`) when scope is `project`. Stub-only file write triggers `project_secrets_ensure_gitignore`. Deferred queue tuple grows to 4 fields: `name\tkeys\tinstall_args\tscope` so the post-install summary can print scope-correct "edit X file then reload" hints.
- [ ] **DISP-04**: Post-install summary printer (already part of install.sh's MCP wizard close) prints per-MCP scope alongside the existing keys-needed list. Project-scope MCPs get a distinct hint line: `→ Edit <project>/.env to fill values; ensure .env is in your .gitignore (we appended it).`

### Uninstall secret cleanup (`scripts/uninstall.sh`)

- [ ] **UN-SEC-01**: New helper `uninstall_prompt_mcp_keys <name> <key1> <key2>...` in `uninstall.sh`. Reads keys for the named MCP from the catalog (`integrations-catalog.json` `env_var_keys`). Prompts `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?` via `< /dev/tty` (fail-closed N on no-TTY, mirrors UN-03). On Y, rewrites `mcp-config.env` excluding those keys, preserves 0600. On N (default) the keys remain — user may reinstall the MCP later.
- [ ] **UN-SEC-02**: When `claude mcp remove <name>` is invoked from any toolkit-driven uninstall path (currently the bulk uninstall for the toolkit; future: per-MCP uninstall command if added), `uninstall_prompt_mcp_keys` is called immediately after.
- [ ] **UN-SEC-03**: Full toolkit uninstall (`scripts/uninstall.sh` whole-toolkit path) prompts ONCE about the entire `~/.claude/mcp-config.env`: `[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?` Default N — the user may keep the file independent of toolkit lifecycle. On Y, file deleted before the LAST-step `STATE_FILE` removal (UN-05 D-06 ordering preserved). The base-plugin invariant (`diff -q`) still runs and still wins.
- [ ] **UN-SEC-04**: Project `.env` files are **never** touched by `uninstall.sh`. Documented contract: project `.env` belongs to the user's project, not to the toolkit. Even when `--full` or any future flag is passed. Verified by hermetic test (no fopen of any `.env` file outside `~/.claude/`).
- [ ] **UN-SEC-05**: `uninstall.sh --keep-state` (v4.4 KEEP-01 carry) implies `--keep-secrets` — neither `mcp-config.env` nor any other secret-bearing file is touched on `--keep-state`. Documented in `--help` and `docs/INSTALL.md`.

### Catalog growth (`scripts/lib/integrations-catalog.json`)

- [ ] **INT-13**: Add `calendly` MCP entry to the catalog. `display_name: "Calendly"`, `category: "workspace"` (or new `scheduling` category if planning decides), `unofficial: false`, `default_scope: "user"`, `requires_oauth: true` (Calendly MCP uses OAuth per the official docs at `developer.calendly.com/calendly-mcp-server`). `install_args` populated per the official MCP server spec. CLI block omitted (no companion CLI).
- [ ] **INT-14**: Catalog explicitly does NOT add a "google-workspace" MCP. Decision logged in PROJECT.md and CHANGELOG: claude.ai's built-in Gmail/Calendar/Drive connectors already cover that surface. Adding a community wrapper would duplicate Anthropic's official OAuth flow and break under upstream API changes.

### Tests (`scripts/tests/`)

- [ ] **TEST-01**: New `scripts/tests/test-project-secrets.sh` (≥18 assertions, hermetic, idempotent). Coverage:
  - `project_secrets_write_env` creates `.env` with mode 0600 when absent.
  - `project_secrets_write_env` idempotent merge prompts on collision (Y overwrites, N preserves).
  - `project_secrets_ensure_gitignore` appends `.env` when missing, no-op when present (exact `^\.env$` match), no false-positive on `*.env` or `# .env`.
  - `project_secrets_render_mcp_env_block` produces `{"K1": "${K1}"}` form.
  - SEC-05 literal-secret refusal: writing literal value into `.mcp.json` returns rc=1 with stderr message.
  - SEC-06 metacharacter rejection.
  - `project_secrets_write_env` rejects values containing `$`, backtick, backslash, quote, newline.
  - `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam works and warns.
- [ ] **TEST-02**: Extend `scripts/tests/test-mcp-wizard.sh` (currently PASS=14) with scenarios for project-scope dispatch:
  - DISP-01 happy path: scope=project → keys land in `<project>/.env`, `.gitignore` updated, `.mcp.json` `env` block uses `${VAR}` form, `mcp-config.env` untouched.
  - DISP-02 no regression: scope=user → keys land in `mcp-config.env`, `<project>/.env` untouched.
  - DISP-03 defer-secrets path with scope=project → blank stubs in `<project>/.env`, queue tuple has 4 fields.
- [ ] **TEST-03**: Extend `scripts/tests/test-mcp-secrets.sh` (currently PASS=11) with scenarios for the new shared `_mcp_validate_value` boundary if refactored (SEC-06).
- [ ] **TEST-04**: Extend `scripts/tests/test-mcp-selector.sh` (currently PASS=21) with scenarios for per-row scope toggle:
  - TUI-SCOPE-01 indicator render in default state.
  - TUI-SCOPE-02 single-row hotkey flips one row only.
  - TUI-SCOPE-03 global `s` flips all visible rows.
  - TUI-SCOPE-04 `MCP_SELECTED_SCOPE[]` initialized from `default_scope`.
  - TUI-SCOPE-05 dispatcher exports per-row `TK_MCP_SCOPE` to `mcp_wizard_run`.
- [ ] **TEST-05**: Extend `scripts/tests/test-uninstall-state-cleanup.sh` (or sibling test as planning decides) with secret-cleanup prompt scenarios:
  - UN-SEC-01 single-MCP keys cleanup Y/N branches (file rewritten without those keys on Y, preserved on N).
  - UN-SEC-03 full-toolkit `mcp-config.env` cleanup Y/N branches.
  - UN-SEC-04 project `.env` is never opened/touched (negative assertion via filesystem fingerprint diff).
  - UN-SEC-05 `--keep-state` preserves all secret files.
- [ ] **TEST-06**: Catalog validator gains assertion for SCOPE-01: every MCP entry has `default_scope` field with valid enum value. Existing `scripts/validate-integrations-catalog.py` extended (no new file).

### Distribution + docs

- [ ] **DIST-01**: `manifest.json` registers `scripts/lib/project-secrets.sh` under existing `files.libs[]` array. `update-claude.sh` auto-discovers it via the v4.4 LIB-01 D-07 jq path — zero code changes to `update-claude.sh` needed. Manifest version bumped to `5.0.0` (major bump justified by user-visible scope semantics change in TUI + new uninstall prompts).
- [ ] **DIST-02**: `init-claude.sh` and `init-local.sh` `--version` outputs bump to `5.0.0` via the existing manifest-derivation path (single source of truth). 3 plugin.json files (`tk-skills`, `tk-commands`, `tk-framework-rules`) bump to `5.0.0` to keep version-align gate green.
- [ ] **DIST-03**: `CHANGELOG.md [5.0.0]` consolidated entry covers SCOPE-01..03, TUI-SCOPE-01..05, SEC-01..06, DISP-01..04, UN-SEC-01..05, INT-13..14, plus the v4.9 → v5.0 rationale (per-row scope was originally a v4.9 follow-up but grew enough to warrant a major bump because it changes the secrets-handling boundary).
- [ ] **DOCS-01**: New "Per-MCP Scope" section in `docs/INTEGRATIONS.md`. Documents the U/P/L semantics, where each scope's secrets live (`mcp-config.env` vs `<project>/.env`), the `${VAR}` substitution convention in `.mcp.json`, the `.gitignore` guard, and worked examples for both user-scope and project-scope flows.
- [ ] **DOCS-02**: `docs/INSTALL.md` "Installer Flags" table extended with any new CLI flags emerging from planning (e.g., `--mcp-scope=user|project`, `--mcp-scope-<name>=<scope>` for per-MCP non-interactive force). README "Killer Features" grid mentions per-MCP scope control as a v5.0 highlight.
- [ ] **DOCS-03**: `docs/UNINSTALL.md` (or the existing uninstall section in INSTALL.md) documents the new secret-cleanup prompts (`mcp-config.env` per-MCP and full-toolkit) and the explicit "project `.env` never touched" contract.

## Future Requirements

- **SCOPE-FUT-01**: Allow per-MCP scope override via env-var (e.g., `TK_MCP_SCOPE_supabase=user`) for non-interactive force without flags. Defer until friction surfaces.
- **SCOPE-FUT-02**: TUI `--preset minimal|full|dev` (carry-over) with per-preset scope assignments.
- **SEC-FUT-01**: Integration with macOS Keychain / Linux libsecret as an alternative store for `mcp-config.env`. Out of scope for v5.0 — adds a platform-specific dependency surface that needs its own milestone.
- **SEC-FUT-02**: Detect a 1Password / Vault secret manager and offer to use it instead of plaintext `.env`. Out of scope.
- **INT-FUT-05**: Google Workspace MCP wrapper — explicitly deferred (claude.ai connectors cover it). Re-evaluate only if Anthropic deprecates the connectors.
- **INT-FUT-06**: Zoom / Microsoft Teams MCPs — out of scope until official MCPs exist.

## Out of Scope

- **Auto-rotate secrets** — toolkit reads + writes secrets but does not detect leaked or stale keys. Outside the security-tooling charter.
- **Encrypt `mcp-config.env` at rest** — adds a passphrase prompt to every `claude` launch; usability cost outweighs threat (file is already 0600 + only readable by the user).
- **Migrate existing v4.x users to per-row scope** — pre-v5.0 installs continue to work via SCOPE-03 backward-compat fallback. No interactive migration prompt.
- **Add Google Workspace MCP** — see INT-14. claude.ai built-in connectors are the correct surface.
- **Modify project `.env` files outside the toolkit-managed key set** — UN-SEC-04 forbids any toolkit write to project `.env` during uninstall. Same posture during install: only the keys explicitly named by the active wizard run are written.
- **Web UI for managing scopes** — toolkit is POSIX terminal-only.
- **Windows-native scope semantics** — POSIX invariant carries forward.

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| SCOPE-01 | Phase 36 | not-started |
| SCOPE-02 | Phase 36 | not-started |
| SCOPE-03 | Phase 36 | not-started |
| TUI-SCOPE-01 | Phase 39 | not-started |
| TUI-SCOPE-02 | Phase 39 | not-started |
| TUI-SCOPE-03 | Phase 39 | not-started |
| TUI-SCOPE-04 | Phase 39 | not-started |
| TUI-SCOPE-05 | Phase 39 | not-started |
| SEC-01 | Phase 37 | not-started |
| SEC-02 | Phase 37 | not-started |
| SEC-03 | Phase 37 | not-started |
| SEC-04 | Phase 37 | not-started |
| SEC-05 | Phase 37 | not-started |
| SEC-06 | Phase 37 | not-started |
| DISP-01 | Phase 38 | not-started |
| DISP-02 | Phase 38 | not-started |
| DISP-03 | Phase 38 | not-started |
| DISP-04 | Phase 38 | not-started |
| UN-SEC-01 | Phase 40 | not-started |
| UN-SEC-02 | Phase 40 | not-started |
| UN-SEC-03 | Phase 40 | not-started |
| UN-SEC-04 | Phase 40 | not-started |
| UN-SEC-05 | Phase 40 | not-started |
| INT-13 | Phase 40 | not-started |
| INT-14 | Phase 40 | not-started |
| TEST-01 | Phase 37 | not-started |
| TEST-02 | Phase 38 | not-started |
| TEST-03 | Phase 38 | not-started |
| TEST-04 | Phase 39 | not-started |
| TEST-05 | Phase 40 | not-started |
| TEST-06 | Phase 40 | not-started |
| DIST-01 | Phase 41 | not-started |
| DIST-02 | Phase 41 | not-started |
| DIST-03 | Phase 41 | not-started |
| DOCS-01 | Phase 41 | not-started |
| DOCS-02 | Phase 41 | not-started |
| DOCS-03 | Phase 41 | not-started |

**Total: 37 REQ-IDs.** All mapped to phases 36–41. Coverage: 37/37 (100%), 0 orphans.
