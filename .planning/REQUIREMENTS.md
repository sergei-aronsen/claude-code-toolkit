# Requirements — v4.5 Install Flow UX & Desktop Reach

**Defined:** 2026-04-29
**Core Value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Milestone goal:** Replace the multi-command first-run flow with one TUI installer (Components / MCPs / Skills) and publish the toolkit as a Claude Code plugin marketplace so Claude Desktop users get the value surface architecturally available to them.

## v4.5 Requirements

Requirements grouped by phase. Each maps to exactly one phase via the Traceability table.

### Phase 24 — Unified TUI Installer + Centralized Detection

#### TUI library (foundation reused by Phases 25–26)

- [x] **TUI-01**: `scripts/lib/tui.sh` exposes `tui_checklist <items_var> <results_var>` that renders a Bash 3.2 compatible checkbox menu (`read -rsn1` + `read -rsn2` for arrow tail; no `read -N`, no float `-t`, no `declare -n` namerefs). Live tested on macOS Bash 3.2.57.
- [x] **TUI-02**: TUI reads exclusively from `< /dev/tty` with `TK_TUI_TTY_SRC` test seam (mirrors `TK_BOOTSTRAP_TTY_SRC` from v4.4 BOOTSTRAP-01). Fail-closed default-set when `/dev/tty` unavailable (CI, piped install).
- [x] **TUI-03**: TUI registers `trap '<restore-stty>' EXIT INT TERM` BEFORE entering raw mode. Ctrl-C mid-render restores terminal cleanly. Restore uses `|| true` so trap failure doesn't compound.
- [x] **TUI-04**: Each item displays label + status (`[ ]`, `[x]`, `[installed ✓]`) + optional description on focused row. Selection visually distinguished (reverse video or arrow indicator).
- [x] **TUI-05**: Confirmation step before any installer runs (`Install N component(s)? [y/N]`). Default N. Cancel returns to menu without changes.
- [x] **TUI-06**: `--no-color` and `${NO_COLOR+x}` honored ([no-color.org](https://no-color.org)). `[ -t 1 ]` gates color output.
- [x] **TUI-07**: `scripts/tests/test-install-tui.sh` hermetic test (≥15 assertions): keystroke injection via fixture file, no-TTY fallback path, `--yes` non-interactive default-set, `--dry-run` zero-mutation, `--force` re-runs detected components.

#### Centralized detection v2

- [x] **DET-01**: `scripts/lib/detect2.sh` sources existing `scripts/detect.sh` (does not duplicate SP/GSD logic). Adds `is_<name>_installed` functions returning 0/1 for: `toolkit`, `superpowers`, `gsd`, `security`, `rtk`, `statusline`.
- [x] **DET-02**: `is_security_installed` uses `command -v cc-safety-net` (covers brew **and** npm install paths) plus `grep cc-safety-net ~/.claude/hooks/pre-bash.sh` (or equivalent settings.json scan). Fixes v4.4 regression where brew installs were missed.
- [x] **DET-03**: `is_statusline_installed` checks `~/.claude/statusline.sh` exists AND `grep statusLine ~/.claude/settings.json` returns 0.
- [x] **DET-04**: `is_rtk_installed` uses `command -v rtk` (filesystem and PATH agnostic).
- [x] **DET-05**: `is_toolkit_installed` checks `~/.claude/toolkit-install.json` exists (existing v4.0 STATE-01 contract).

#### Dispatch + install.sh entry

- [x] **DISPATCH-01**: `scripts/lib/dispatch.sh` exposes per-component dispatchers (`dispatch_toolkit`, `dispatch_security`, `dispatch_rtk`, `dispatch_statusline`) that invoke existing per-component scripts as `bash -c` subprocesses with appropriate flags. Order-of-operations contract: SP/GSD → toolkit → security → RTK → statusline.
- [x] **DISPATCH-02**: `setup-security.sh` learns `--yes` flag that gates every interactive `read -r -p` block (use safe defaults). `install-statusline.sh` learns `--yes` as accepted-but-no-op (semantic symmetry). `init-claude.sh` already non-interactive — no flag added.
- [x] **DISPATCH-03**: `scripts/install.sh` is a new top-level orchestrator (NOT a trampoline). Sources `lib/{tui,detect2,dispatch}.sh`, runs detection → TUI → confirmation → dispatch → post-install summary. Failure of step N reports per-component status; remaining components continue (configurable via `--fail-fast`).

#### Backwards compatibility

- [x] **BACKCOMPAT-01**: Existing `init-claude.sh` URL stays valid and unchanged. v4.4 BOOTSTRAP-01..04 contract preserved (26-assertion `test-bootstrap.sh` stays green throughout Phase 24). `bootstrap.sh` becomes the no-TTY fallback for SP/GSD prompts only — TUI replaces the interactive layer above it. `--no-bootstrap`, `--no-banner`, `TK_NO_BOOTSTRAP`, `NO_BANNER` env-vars/flags preserved on all paths.

### Phase 25 — MCP Selector

#### MCP catalog + per-MCP wizard

- [x] **MCP-01**: `templates/mcps/<name>/{mcp.json, setup.sh, config-prompt.txt, README.md}` per MCP for nine curated entries: `context7`, `magic`, `notebooklm`, `openrouter`, `playwright`, `sentry`, `sequential-thinking`, `toolbox`, `youtrack`. `mcp.json` describes the install command + env-var requirements; `setup.sh` is optional pre-req installer (e.g., `npm install -g @playwright/mcp`); `config-prompt.txt` is plaintext template for the per-MCP prompt.
- [x] **MCP-02**: `is_mcp_installed <name>` parses `claude mcp list` output (one MCP per row) and returns 0/1. Fail-soft: if `claude` CLI absent, return "unknown" and warn rather than error.
- [ ] **MCP-03**: `scripts/install.sh --mcps` (or second TUI page) renders the catalog with detected status per MCP. Selected MCPs trigger per-MCP wizard.
- [ ] **MCP-04**: Per-MCP wizard reads `config-prompt.txt`, prompts inline for required values (`read -rs` for sensitive fields like API keys, `read -r` for URLs/usernames), runs `setup.sh` if present, then invokes `claude mcp add <name> <flags-from-mcp.json>` with collected values plumbed in via env vars.
- [ ] **MCP-05**: `scripts/tests/test-install-mcp.sh` hermetic test: mock `claude mcp list` and `claude mcp add` via PATH override, assert per-MCP wizard prompts/persistence/invocation contract for at least one zero-config MCP (sequential-thinking) and one keyed MCP (openrouter).

#### MCP secrets handling

- [ ] **MCP-SEC-01**: `~/.claude/mcp-config.env` created with mode `0600` (owner-only readable, `chmod 600` after write). File is gitignored at user level (TUI prints warning if user is inside a git worktree without `.gitignore`).
- [ ] **MCP-SEC-02**: `mcp-config.env` schema is `KEY=value` lines (no quotes, trailing newline per entry). TUI appends; existing keys are overwritten with `[y/N]` confirmation. `docs/MCP-SETUP.md` documents the file location, plaintext-on-disk caveat, and a "rotate to secret manager" recipe.

### Phase 26 — Skills Selector

#### Skills marketplace mirror

- [ ] **SKILL-01**: `templates/skills-marketplace/<name>/SKILL.md` mirrors 22 curated skills sourced from skills.sh upstream: `ai-models`, `analytics-tracking`, `chrome-extension-development`, `copywriting`, `docx`, `find-skills`, `firecrawl`, `i18n-localization`, `memo-skill`, `next-best-practices`, `notebooklm`, `pdf`, `resend`, `seo-audit`, `shadcn`, `stripe-best-practices`, `tailwind-design-system`, `typescript-advanced-types`, `ui-ux-pro-max`, `vercel-composition-patterns`, `vercel-react-best-practices`, `webapp-testing`. Each ships with companion files where they exist (`AUTHENTICATION.md`, `references/`, `scripts/`, etc.).
- [ ] **SKILL-02**: License audit: every mirrored skill has its license file (`LICENSE` or equivalent header) preserved. `docs/SKILLS-MIRROR.md` records skills.sh upstream URLs, mirror-date, and re-sync procedure.
- [ ] **SKILL-03**: `is_skill_installed <name>` checks `[ -d ~/.claude/skills/<name>/ ]`. `scripts/install.sh --skills` (or third TUI page) renders catalog with detected status, copies selected from `templates/skills-marketplace/<name>/` to `~/.claude/skills/<name>/` via `cp -R`. Idempotent: re-install with `--force` overwrites.
- [ ] **SKILL-04**: `scripts/tests/test-install-skills.sh` hermetic test: `cp -R` correctness, idempotency on re-run, `--force` overwrite, refusal-to-overwrite without `--force`.
- [ ] **SKILL-05**: `manifest.json` registers `templates/skills-marketplace/` content under a new `files.skills_marketplace[]` (or extends `templates`) so `update-claude.sh` ships skill updates to existing TK installs.

### Phase 27 — Marketplace Publishing + Claude Desktop Reach

#### Marketplace surface

- [ ] **MKT-01**: `.claude-plugin/marketplace.json` at repo root with schema `{name, owner.name, plugins[]}` validated against current Anthropic spec at `code.claude.com/docs/en/plugin-marketplaces`. `name` = `claude-code-toolkit`, `owner.name` = `sergei-aronsen`. Three sub-plugins listed.
- [ ] **MKT-02**: `plugins/<name>/.claude-plugin/plugin.json` for three sub-plugins: `tk-skills` (skills surface — Desktop-compatible), `tk-commands` (29 slash commands — Code only), `tk-framework-rules` (7 framework CLAUDE.md template fragments — Code only). Each plugin.json declares `version`, `description`, `category`, `tags`. Version is the single source of truth (do NOT also set version in marketplace.json entry — `plugin.json` silently wins).
- [ ] **MKT-03**: Live `claude plugin marketplace add ./` smoke test from a hermetic clone validates the marketplace structure end-to-end. `make validate-marketplace` target runs the smoke (gated behind opt-in `TK_HAS_CLAUDE_CLI=1` env-var; CI runner does not have `claude` by default).
- [ ] **MKT-04**: README + `docs/INSTALL.md` gain a "Install via marketplace" section alongside the curl-bash install. Both channels documented as equivalent for Code users; marketplace is the only path for Desktop users.

#### Claude Desktop reach

- [ ] **DESK-01**: `docs/CLAUDE_DESKTOP.md` documents the capability matrix: Claude Desktop Code tab has full plugin runtime parity with terminal Claude Code; Desktop Chat tab has no plugin system; remote (cloud-hosted) Code sessions block plugins per Anthropic docs. Marketplace is the only Desktop install channel (`/plugin marketplace add ./local-dir` is blocked).
- [ ] **DESK-02**: `scripts/validate-skills-desktop.sh` scans `templates/skills-marketplace/*/SKILL.md` for Code-only assumptions (Bash code blocks that *require* execution by the agent, references to `Read`/`Bash`/`Write` tools as required dependencies). Output: per-skill PASS/FLAG verdict. Wired into `make check`.
- [ ] **DESK-03**: `scripts/install.sh` detects Desktop-only users (no `claude` CLI on PATH) and routes to `--skills-only` branch that places skills under `~/.claude/plugins/tk-skills/` (instead of project `.claude/`). Surfaces a one-liner explaining the limitation.
- [ ] **DESK-04**: Skill audit gate fails Phase 27 if fewer than 4 skills pass `validate-skills-desktop.sh`. Below that threshold, `tk-skills` sub-plugin scope rebalances toward instruction-only (zero-tool) skills.

## Future Requirements

Deferred from v4.5 — tracked for later milestones.

### Installer UX

- **TUI-FUT-01**: Live install progress bar (currently line-based status sufficient)
- **TUI-FUT-02**: `--preset minimal|full|dev` for opinionated component bundles
- **TUI-FUT-03**: Grouped sections in TUI (Essentials / Optional)

### MCP

- **MCP-FUT-01**: MCP rotate-to-secret-manager recipe automation (1Password CLI / Vault integration)
- **MCP-FUT-02**: MCP catalog auto-sync with upstream registry (poll mcp-registry on update)

### Marketplace

- **MKT-FUT-01**: Marketplace signing/integrity once Anthropic spec exists
- **MKT-FUT-02**: Per-plugin telemetry/usage opt-in

## Out of Scope

Explicit exclusions for v4.5 with reasoning.

- **Full Anthropic Desktop API integration** — Claude Desktop Chat tab has no plugin system. Targeting Chat-tab users requires API-level work outside the plugin framework. Out of v4.5 by definition.
- **Skill install via skills.sh trampoline** — rejected in favour of TK-mirror approach (no external runtime dependency, predictable license/version surface).
- **`claude` CLI vendored in TK install path** — TK does not vendor third-party binaries. Phase 25 fail-soft if `claude` absent; user installs CLI separately.
- **MCP install via custom shell wrappers per MCP** — TK invokes `claude mcp add` and lets the CLI manage runtime. No custom wrapper scripts beyond optional pre-req `setup.sh` for npm-installed MCP servers.
- **Backwards-compat shim for old per-component install commands** — old curl-bash URLs continue to work unchanged (BACKCOMPAT-01); a deprecation phase is **not** scheduled. New entry point coexists indefinitely.
- **Selective uninstall (`--only commands/`, `--except council/`)** — combinatorial test surface, only revisit on real demand.

## Traceability

Phases mapped to requirements. Filled by gsd-roadmapper on 2026-04-29.

| Phase | Requirements | Status |
|-------|--------------|--------|
| 24 — Unified TUI Installer + Centralized Detection | TUI-01, TUI-02, TUI-03, TUI-04, TUI-05, TUI-06, TUI-07, DET-01, DET-02, DET-03, DET-04, DET-05, DISPATCH-01, DISPATCH-02, DISPATCH-03, BACKCOMPAT-01 | Pending |
| 25 — MCP Selector | MCP-01, MCP-02, MCP-03, MCP-04, MCP-05, MCP-SEC-01, MCP-SEC-02 | Pending |
| 26 — Skills Selector | SKILL-01, SKILL-02, SKILL-03, SKILL-04, SKILL-05 | Pending |
| 27 — Marketplace + Desktop Reach | MKT-01, MKT-02, MKT-03, MKT-04, DESK-01, DESK-02, DESK-03, DESK-04 | Pending |
