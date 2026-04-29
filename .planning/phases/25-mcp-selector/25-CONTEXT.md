# Phase 25: MCP Selector - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

A developer running `scripts/install.sh --mcps` browses a curated catalog of nine MCP servers via a TUI page, selects which ones to install, completes per-MCP secret-collection wizards (hidden input via `read -rs`), persists API keys in `~/.claude/mcp-config.env` (mode 0600), and runs `claude mcp add` for each selected server. When the `claude` CLI is absent, the page renders with a warning and the install action is disabled — never errors.

Out of scope: skill installation (Phase 26), marketplace publishing (Phase 27), MCP server authoring, custom (non-curated) MCP additions.
</domain>

<decisions>
## Implementation Decisions

### MCP Catalog Source
- **Catalog format:** JSON file at `scripts/lib/mcp-catalog.json`. Version-controllable, scriptable, future-edits don't require shell-script rewrites.
- **Curated 9 MCPs (v1):** `context7`, `sentry`, `sequential-thinking`, `playwright`, `notion`, `magic`, `firecrawl`, `resend`, `openrouter`. (Matches user's existing MCP usage signal; broad coverage of dev/observability/integration.)
- **Status detection:** Run `claude mcp list` when CLI present, parse output to mark each catalog entry `installed` / `not installed`. When CLI absent, every entry shows `?` status.
- **Per-MCP metadata schema:** `{ name, display_name, env_var_keys: [], install_args: [], description, requires_oauth: bool }`. JSON object keyed by `name`.

### Wizard UX & Secret Storage
- **Hidden input pattern:** `read -rsp "<key>: "` followed by an explicit newline echo. Key never echoed, never logged, never written to history.
- **Storage path:** `~/.claude/mcp-config.env` with `chmod 0600` enforced at write time (matches ROADMAP SC-4).
- **Collision handling:** Per-key `[y/N]` prompt when a key already exists in the env file. Default = `N` (keep existing). User can override.
- **OAuth-only MCPs:** Skip the wizard step. Print `OAuth flow handled by claude mcp add — follow CLI prompts` and dispatch directly.

### Failure & Degradation
- **Claude CLI absent:** Render the TUI page normally but show a banner `claude CLI not found — MCPs cannot be installed from here. See docs/INSTALL.md`. Disable the install action (Enter is no-op).
- **`claude mcp add` failure:** Mark that MCP `failed: <stderr last line>` in the per-MCP summary. Continue installing the rest (parallel-mode robustness).
- **Missing env vars at install time:** Fail-closed for that single MCP. Mark `skipped: missing required keys`. Continue with rest.
- **Test scaffold:** Hermetic `scripts/tests/test-mcp-selector.sh` mirroring `test-install-tui.sh`. Test seams: `TK_MCP_CLAUDE_BIN` (replace `claude` binary), `TK_MCP_CONFIG_HOME` (sandbox `~/.claude`), `TK_MCP_TTY_SRC` (raw-input fixture).

### Claude's Discretion
- Specific TUI layout details (column widths, color choices) follow Phase 24's `tui.sh` conventions.
- Error message wording is at Claude's discretion within the contract above.
- Test assertion count target ≥ 12 (covering catalog parse, status detection, wizard hidden-input, file mode 0600, collision prompt, CLI-absent path, install-success/failure paths).
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/lib/tui.sh` (Phase 24) — `tui_checklist`, `tui_confirm_prompt`, NO_COLOR three-layer gate, `TK_TUI_TTY_SRC` seam, `_tui_restore` trap pattern.
- `scripts/lib/detect2.sh` (Phase 24) — pattern for `is_*_installed` probes; new `is_mcp_installed <name>` follows same shape.
- `scripts/lib/dispatch.sh` (Phase 24) — `dispatch_*` per-component pattern; new `dispatch_mcps` joins `TK_DISPATCH_ORDER`.
- `scripts/install.sh` (Phase 24) — main orchestrator; gains `--mcps` flag routing to MCP page; existing `--yes`/`--dry-run`/`--force`/`--no-banner` semantics preserved.

### Established Patterns
- Bash 3.2 compatibility — no `mapfile`, no `${var^^}`, all libs use POSIX-friendly constructs.
- Test seams via `TK_*` env var overrides (precedent: `TK_TUI_TTY_SRC`, `TK_BOOTSTRAP_TTY_SRC`, `TK_DISPATCH_OVERRIDE_*`).
- Test scripts hermetic: sandbox `$HOME` to a tmpdir, override CLI lookups via `PATH` or `TK_*_BIN`.
- File-mode enforcement: `chmod 0600` immediately after `printf > file` (precedent: backup snapshot writes).
- `manifest.json` `files.libs[]` and `files.scripts[]` sorted alphabetically (24-05 D-XX); new entries added alphabetically.

### Integration Points
- `scripts/install.sh` argparse loop — add `--mcps` branch routing to `_run_mcp_selector`.
- `scripts/lib/dispatch.sh` `TK_DISPATCH_ORDER` — append `mcps` if it becomes a top-level checklist item; otherwise route only via `--mcps` subcommand.
- `manifest.json` — register `scripts/lib/mcp.sh` (new dispatcher), `scripts/lib/mcp-catalog.json` (new asset), `scripts/tests/test-mcp-selector.sh` (new test).
- `Makefile` — add `Test 32` target invoking `test-mcp-selector.sh`.
- `.github/workflows/quality.yml` — extend the `Tests 21-31` step to `Tests 21-32`.
- `docs/INSTALL.md` — new `### --mcps flag` subsection under existing `## install.sh (unified entry, v4.5+)` section.
</code_context>

<specifics>
## Specific Ideas

- The 9 curated MCPs were chosen from the user's existing MCP server list visible in this project's environment (Context7, Sentry, Notion, Playwright, Magic, Firecrawl, OpenRouter, NotebookLM, YouTrack, Sequential-thinking). Replaced NotebookLM and YouTrack with Resend and Sequential-thinking for broader applicability; this keeps the count at 9 and avoids OAuth-heavy entries in v1.
- Reuse `_tui_enter_raw` / `_tui_restore` semantics directly — do not create a parallel raw-mode handler.
- Wizard MUST flush stdin between key prompts (no buffered input bleeding from previous entries).
</specifics>

<deferred>
## Deferred Ideas

- **Custom MCP addition (BYO catalog entry)** — user-supplied MCPs not in the curated list. Defer to a future phase (could become "MCP-USER-01").
- **MCP removal flow** — `--mcps-remove` to uninstall MCPs from the catalog. Defer; users can use `claude mcp remove` directly.
- **Per-MCP version pinning** — track which MCP version was installed. Defer; `claude mcp add` controls version internally.
- **Bulk-import existing `mcp-config.env`** — if user already has the file, reuse keys without re-prompting. Could be added as a passive enhancement post-v1.
- **OAuth wizard variant** — for MCPs requiring browser-based OAuth (Notion, GDrive). Defer; v1 routes them straight to `claude mcp add` and lets the CLI handle OAuth prompts.
</deferred>
