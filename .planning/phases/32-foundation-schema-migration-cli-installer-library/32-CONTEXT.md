# Phase 32: Foundation — Schema Migration + CLI Installer Library — Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** Auto-discuss (decisions distilled from milestone-scoping conversation 2026-05-02)

<domain>
## Phase Boundary

Migrate `scripts/lib/mcp-catalog.json` to a richer schema published as `scripts/lib/integrations-catalog.json` that supports per-entry `components: { mcp?, cli? }` blocks plus `category` and `unofficial` fields. Ship a cross-platform CLI installer library (`scripts/lib/cli-installer.sh`) with `cli_detect` / `cli_install` primitives, OS dispatch, brew-absent fallback, no auto-elevation, and stderr-only post-install hints. Add a Python schema validator (`scripts/validate-integrations-catalog.py`) wired into `make check`. Backward-compat: `--mcps` CLI flag keeps working as alias for `--integrations` with a one-line stderr deprecation note.

**Catalog population (the actual 19 entries) is Phase 33. TUI redesign is Phase 34. Manifest bump + tests + docs are Phase 35.** Phase 32 ships infrastructure only — schema, validator, library, alias — not user-visible behavior changes.

REQ-IDs covered: CAT-01, CAT-02, CAT-03, CAT-04, CLI-01, CLI-02, CLI-03, CLI-04 (8 of 36).

</domain>

<decisions>
## Implementation Decisions

### Catalog file rename strategy

- **D-01:** Hard rename `scripts/lib/mcp-catalog.json` → `scripts/lib/integrations-catalog.json`. No symlink, no transitional period. v4.9 is a minor bump; clean break is acceptable.
- **D-02:** `scripts/lib/mcp.sh` reads the new path directly. Public function names (`mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`) keep their `mcp_` prefix for backward-compat with current callers in `scripts/install.sh`. Internal logic upgrades to read the new schema. Renaming the functions is a v5.0 concern.
- **D-03:** `manifest.json` `files.libs[]` updated atomically — old `mcp-catalog.json` entry replaced with `integrations-catalog.json` entry in Phase 35 DIST-01 (manifest bump deferred per v4.4/v4.6/v4.8 close-pattern). Phase 32 itself ships the new file beside the old one in commit history; the rename is a single git mv inside the schema-migration plan.

### Schema shape

- **D-04:** Top-level structure: `{ "<entry-name>": { ...entry } }` flat dict (preserves current shape). Each entry MUST carry `display_name: string`, `category: string`, `components: { ... }`. MAY carry `description: string`, `unofficial: bool`.
- **D-05:** `components` block has two optional sub-objects: `mcp` and `cli`. At least one MUST be present. Each entry can be MCP-only, CLI-only, or both.
- **D-06:** `components.mcp` schema: `{ install_args: string[], env_var_keys: string[], requires_oauth: bool, description?: string }`. `install_args[0]` is the canonical MCP name passed to `claude mcp add`.
- **D-07:** `components.cli` schema: `{ detect_cmd: string, install: { darwin: string, linux: string }, post_install_hint?: string }`. `detect_cmd` is the binary name fed to `command -v`. `install.{darwin,linux}` are full shell strings (e.g., `brew install supabase/tap/supabase`).
- **D-08:** `category: string` enum (validator-enforced): `docs-research`, `backend`, `payments`, `email`, `workspace`, `project-management`, `communication`, `design`, `dev-tools`, `monitoring`. Frozen list in v4.9; new categories require schema bump.
- **D-09:** `unofficial: true` flag MAY appear at entry top level. Default is `false` (omitted). When present, TUI renders yellow `!` glyph + per-row confirm prompt (Phase 34 TUI-03).

### Schema validator

- **D-10:** `scripts/validate-integrations-catalog.py` — Python 3 (toolkit already requires Python 3.8+ for `scripts/council/brain.py`, no new runtime dependency). Uses `json` stdlib; no `jsonschema` package — keep zero-dep posture.
- **D-11:** Validator checks: (a) every entry has `display_name`, `category`, `components`; (b) `category` ∈ enum; (c) at least one of `components.mcp` / `components.cli` present; (d) MCP block has required `install_args`/`env_var_keys`/`requires_oauth`; (e) CLI block has `detect_cmd` + `install.darwin` + `install.linux`; (f) `unofficial` if present is bool. Exit 0 on success, exit 1 with first error line on failure.
- **D-12:** Wired into `make check` via new `validate-catalog` target; CI mirrors via `validate-templates` job.
- **D-13:** Validator registered in `manifest.json` `files.scripts[]` in Phase 35 DIST-01.

### CLI installer library

- **D-14:** `scripts/lib/cli-installer.sh` — POSIX bash, sourced by `mcp.sh` and `install.sh`. Exports two public functions: `cli_detect <name>` and `cli_install <name> <darwin_cmd> <linux_cmd>`.
- **D-15:** `cli_detect <name>`: returns 0 if `command -v <name>` succeeds, 1 otherwise. Single-line implementation; idempotent; no side effects. No caching — re-run on every TUI launch (CAT-04 / TUI-02 contract).
- **D-16:** `cli_install <name> <darwin_cmd> <linux_cmd>`: dispatches by `uname -s`. macOS → run `<darwin_cmd>`. Linux → run `<linux_cmd>`. Anything else → echo `cli-installer: unsupported platform '$(uname -s)' for CLI '<name>'` to stderr, return 2.
- **D-17:** No `sudo` auto-prefix. Ever. If the install command needs root, that's the user's problem — they get a transparent error from `brew`/`apt`/installer and decide. Toolkit never elevates without explicit user action. Documented in `cli-installer.sh` header comment + DOCS-02.
- **D-18:** macOS brew-absent fallback: before invoking `<darwin_cmd>`, check if the command starts with `brew ` AND `command -v brew` fails. If so, echo `brew not found — install from https://brew.sh, then re-run` to stderr, return 3. Do NOT auto-install brew.
- **D-19:** Linux fallback strategy: NO auto-detection of distro. Catalog `install.linux` strings are vendor-recommended (e.g., `npm i -g wrangler` works everywhere npm exists; `curl -fsSL ... | tar` for AWS CLI; `brew install` if user has linuxbrew). If the command fails, return its rc — don't try alternatives. Vendors own their install instructions; toolkit just runs them.
- **D-20:** Continue-on-error semantics in dispatch loop (mirrors Phase 25 D-08): per-CLI install failure does NOT abort the loop. Capture stderr to `mktemp "${TMPDIR:-/tmp}/tk-cli.XXXXXX"`, accumulate `INSTALLED[]`, `SKIPPED[]`, `FAILED[]` arrays, print summary table at end with `✓ installed` / `⊘ already present` / `✗ failed: <first stderr line>`.
- **D-21:** Post-install hint output: stderr only (so stdout stays parseable for piping). Format: `→ Next: <hint>`. Toolkit never executes `<tool> login` automatically (`wrangler login`, `supabase login`, etc.) — boundary is "config + hints", not "auth flows".

### Backward-compat: `--mcps` alias

- **D-22:** `scripts/install.sh`: `--mcps` flag continues to set `MCPS=1` AND additionally prints `--mcps is deprecated; use --integrations instead. (still works, will continue working in v4.x)` to stderr on entry. Exit behavior unchanged.
- **D-23:** Alias works in BOTH `--mcps` and `--integrations` directions: any new code path checks `MCPS` (the existing var, kept) — no rename of the internal variable required. Reduces blast radius. New `--integrations` flag sets the same `MCPS=1`.
- **D-24:** Documentation update (DOCS-03 in Phase 35) explicitly notes `--mcps` is the legacy name and `--integrations` is preferred.

### Library function naming and exports

- **D-25:** Keep `mcp.sh` public function names (`mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`, etc.) — `install.sh` already calls these and we avoid breaking the integration. Internal renames (e.g., `_mcp_default_catalog_path`) are free.
- **D-26:** `cli-installer.sh` uses `cli_` prefix for public functions, `_cli_` for private (Bash 3.2 doesn't enforce, just convention).
- **D-27:** Source ordering in `install.sh`: `_source_lib state`, `_source_lib detect2`, then conditionally `_source_lib mcp` (which itself sources `cli-installer.sh` internally).

### Claude's Discretion

- Exact summary table column widths and ANSI styling (defer to existing `dro_*` helpers in `scripts/lib/dry-run-output.sh`).
- Internal helper names within `cli-installer.sh` (e.g., `_cli_dispatch_darwin` vs inlining).
- Whether to extract a shared "stderr capture to mktemp" helper between `mcp.sh` and `cli-installer.sh` or duplicate. Refactor opportunity, not blocking.
- Validator error message phrasing — must be specific (entry name + missing field), exact wording flexible.

</decisions>

<specifics>
## Specific Ideas

- Mirror v4.6 Phase 25 MCP wizard structure for the CLI installer's per-entry loop — same shape, swap "MCP add" for "CLI install".
- The 9-entry MCP catalog at `scripts/lib/mcp-catalog.json` (current state) IS the ground truth Phase 32 migrates FROM. Phase 32 commits the new schema **with the existing 9 entries** wrapped in `components.mcp` (status quo behavior preserved). Phase 33 then mutates the data — adds 11, drops 1, re-categorizes 8. Phase 32 itself MUST NOT touch entry data.
- `--mcps` deprecation note must NOT block the install — printing to stderr and continuing is enough. No `--strict` / fail-on-deprecated escalation.
- Schema validator can be invoked as both `python3 scripts/validate-integrations-catalog.py` (no args = validate the canonical file) and `python3 ... <path>` (validate arbitrary file). Lets future per-project catalog overrides use the same validator.
- Existing `mcp.sh` function `_mcp_default_catalog_path` resolves to either `${TK_MCP_CATALOG_PATH}` (env override for curl|bash flow) or the local `scripts/lib/mcp-catalog.json`. Phase 32 keeps this seam intact — just changes the default file basename to `integrations-catalog.json`. The env var name `TK_MCP_CATALOG_PATH` is preserved for backward compat (D-22 mirror); a new `TK_INTEGRATIONS_CATALOG_PATH` may be added in Phase 35 docs but not required for Phase 32.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scoping
- `.planning/PROJECT.md` § Current Milestone: v4.9 Integrations Catalog — milestone goal, target features, key context (categories list, global vs per-project boundary, post-install hint contract, AWS scope-cap rationale, unofficial badge semantics).
- `.planning/REQUIREMENTS.md` — REQ-IDs CAT-01..04, CLI-01..04 with full text.
- `.planning/ROADMAP.md` — Phase 32 success criteria.
- `.planning/STATE.md` § Plan Count Estimate, § Key v4.9 Constraints — implementation invariants.

### Foundation libraries (existing, MUST extend not rewrite)
- `scripts/lib/mcp.sh` — current MCP catalog loader + wizard. Public API to preserve: `mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`, env override `TK_MCP_CATALOG_PATH`.
- `scripts/lib/mcp-catalog.json` — current 9-entry file. Phase 32 renames to `integrations-catalog.json` and wraps each existing entry in `components.mcp`.
- `scripts/lib/tui.sh` — TUI rendering primitives. Phase 32 doesn't change this; Phase 34 does.
- `scripts/lib/detect2.sh` — binary detection probes. Phase 32 doesn't change this; the new `cli_detect` is independent (single-binary `command -v` check, no caching).
- `scripts/lib/dry-run-output.sh` — `dro_init_colors`, `dro_print_header`, `dro_print_file`, `dro_print_total`. Reuse for the install summary table at end of CLI dispatch loop.
- `scripts/install.sh` — orchestrator that consumes `mcp.sh`. The `--mcps` flag handler at lines 60-260 is the alias-extension target.

### Reference patterns from prior phases
- v4.6 Phase 25 (`.planning/milestones/v4.6-phases/25-mcp-selector/`) — direct predecessor; D-08 continue-on-error pattern, D-28 per-MCP stderr capture, MCP wizard `< /dev/tty` interaction, `--yes` honour.
- v4.4 LIB-01 — `manifest.json` `files.libs[]` registration so `update-claude.sh` auto-discovers new lib files via existing jq path.
- v4.3 UN-03 — `[y/N/d]` prompt contract via `< /dev/tty`. Not used in Phase 32 directly (no prompts in Phase 32) but pattern referenced for Phase 34.
- v4.8 Phase 28 — 3-plan foundation shape (detect probes + library + smoke test) — Phase 32 mirrors this structure (schema migration + cli-installer library + smoke test).

### Validators (existing, model)
- `scripts/validate-commands.py` (HARDEN-A-01, v4.1 Phase 12) — Python validator using `json` stdlib only, exit 0/1 contract, wired into `make check`. Phase 32's new validator follows this template.
- `scripts/cell-parity.sh` — another `make check` consumer, shows the wiring shape.

### Project conventions
- `CLAUDE.md` — markdown lint rules (MD040, MD031/MD032, MD026), Conventional Commits requirement, "never push directly to main" invariant.
- `Makefile` — current targets `check`, `lint`, `validate`, `validate-commands`. New `validate-catalog` target slots beside `validate-commands`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`scripts/lib/mcp.sh`** — already implements catalog loading, status array population, MCP wizard with `< /dev/tty` + `--yes` handling, continue-on-error dispatch. Phase 32 EXTENDS the loader to read the new schema; the wizard machinery stays put for Phase 34 to reuse.
- **`scripts/lib/dry-run-output.sh` `dro_*` helpers** — emit chezmoi-grade grouped output. `cli-installer.sh` summary table can use `dro_print_header "Installed"` / `dro_print_file "$name"` / `dro_print_total` for consistency.
- **`scripts/validate-commands.py`** — full template for the new `validate-integrations-catalog.py` (json stdlib, exit 0/1, error-with-line-number contract).
- **`mktemp` pattern** in `mcp.sh` lines 401-409 (per-MCP stderr capture) — copy verbatim into `cli_install`.
- **`uname -s` dispatch** — already used in `scripts/install-statusline.sh:24-28` (rejects non-Darwin); the negative-rejection style is the model for D-16.

### Established Patterns

- All scripts open with `#!/bin/bash` + `set -euo pipefail`. New `cli-installer.sh` follows.
- ANSI colors via constants `RED`/`GREEN`/`YELLOW`/`BLUE`/`CYAN`/`NC`. New library uses same constants (or sources `dry-run-output.sh` colors).
- Source-pattern under curl|bash: libs sourced from `/tmp/<name>-XXX` with seam env vars. `cli-installer.sh` adds nothing here — it's a leaf library, not a top-level installer.
- Idempotency via `[ ! -f ... ]` guards before file copies; `cli_detect` plays the same role for tools.
- Bash 3.2 invariant: no `declare -A`, no `read -N`, no float `-t` (Phase 24 BACKCOMPAT-01).

### Integration Points

- `scripts/install.sh:215-228` (current `--mcps` block) — extend with `--integrations` alias parsing, deprecation echo for `--mcps`. **Single-file change for D-22.**
- `scripts/lib/mcp.sh` `_mcp_default_catalog_path` — change default basename from `mcp-catalog.json` to `integrations-catalog.json`. **Two-line diff for D-25.**
- `scripts/lib/mcp.sh` catalog reader — schema-aware: detect old shape (top-level `install_args`) vs new shape (`components.mcp.install_args`). For Phase 32, only the new shape exists in the renamed file; reader can hard-require new shape.
- `Makefile:65-86` — add `validate-catalog: scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json` target; wire into `check` chain.
- `.github/workflows/quality.yml` `validate-templates` job — add `python3 scripts/validate-integrations-catalog.py` line beside existing `validate-commands.py` invocation.

</code_context>

<deferred>
## Deferred Ideas

- **Per-project local catalog override** (`~/.claude/integrations-catalog.local.json`) — TUI-FUT / CAT-FUT-02 in REQUIREMENTS.md. Future phase, not v4.9.
- **Catalog auto-sync with upstream registry** — CAT-FUT-01. Blocked on no upstream registry yet.
- **Version pinning per CLI** — CLI-FUT-02. Vendor-managed today; revisit on real drift incidents.
- **Windows / WSL support** — CLI-FUT-01. Out of scope per POSIX invariant.
- **TUI category headers** — TUI-01 in Phase 34, not Phase 32.
- **`unofficial` confirm prompt** — TUI-03 in Phase 34, not Phase 32.
- **`--mcp-only` / `--cli-only` flags** — TUI-04 in Phase 34, not Phase 32.
- **Renaming `mcp.sh` public functions to `integrations_*`** — defer to v5.0; v4.9 stays backward-compatible with current `install.sh` callers.

</deferred>

---

*Phase: 32-foundation-schema-migration-cli-installer-library*
*Context gathered: 2026-05-02*
