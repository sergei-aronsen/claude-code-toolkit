# Scripts Taxonomy

`scripts/` contains ~30 shell + Python files with three top-level
prefixes (`init-`, `install-`, `setup-`) plus action verbs
(`update-`, `verify-`, `validate-`, `migrate-`, `sync-`,
`propagate-`, `detect-`, `cell-`) and three subdirectories
(`council/`, `prompt-engineer/`, `vendor/`). Logic audit 2026-05-18
surfaced that the mnemonic was ad-hoc. This document fixes the
taxonomy in place — no renames — so contributors can pick the right
prefix and consumers can predict invocation rules.

> **Rule of thumb.** Add a new script under `scripts/` only when it provides a user-invocable installer, setup, or maintenance action. Internal-only helpers live under `scripts/lib/`. Bridge integrations not tied to `.claude/` live under their own subdirectory (e.g., `scripts/council/`).

## Categories

### 1. Primary entry points

The two URLs users `curl | bash` from `README.md` / `docs/INSTALL.md`. Both are supported. Use `install.sh` for first-time interactive installs; `init-claude.sh` is the worker `install.sh` dispatches to and also the URL the per-cell `validate-release.sh --cell …` harness invokes for contract validation.

| Script | Invocation | Role |
|--------|-----------|------|
| `install.sh` | `curl \| bash` (README primary) | TUI orchestrator. Detects existing install, dispatches to per-component sub-installers via `lib/dispatch.sh`. Re-run with `.toolkit-version` present redirects to `update-claude.sh`. |
| `init-claude.sh` | `curl \| bash` (CI / cell validation) | Worker that downloads toolkit files into `./.claude/`. Invoked by `dispatch_toolkit` under `TK_DISPATCHED=1`. |
| `init-local.sh` | local clone only | Mirror of `init-claude.sh` for development. Used by `Makefile:test`. |

### 2. Single-component installers

One script per discrete component. Always opt-in. Each is reachable from `install.sh` TUI menu (when applicable) and exposed as a standalone `curl | bash` URL for headless install.

| Script | Component | Standalone URL? | Dispatched by `install.sh`? |
|--------|-----------|----------------|------------------------------|
| `install-statusline.sh` | macOS rate-limit statusline | yes | yes |
| `install-hooks.sh` | 4 advisory hooks (advisory mode, never blocks) | yes | yes (via `init-claude.sh:setup_hooks`) |
| `setup-security.sh` | global security CLAUDE.md + `cc-safety-net` plugin | yes | yes |
| `setup-council.sh` | Supreme Council multi-AI validator | yes | yes |
| `setup-cost-routing.sh` | `better-model` npm + `~/.claude/CLAUDE.md` block | yes | no (post-install opt-in) |

### 3. Opt-in extensions (not in default TUI)

These extend toolkit capability but are not part of the recommended default install. Each ships its own README/component doc. Discovery is via README and component docs, not the install TUI.

| Script | Extension | Where documented |
|--------|-----------|-------------------|
| `setup-comet.sh` | Comet research MCP bridge | `components/comet-research.md` |
| `setup-open-design.sh` | Open Design web UI | `components/open-design.md` |
| `setup-prompt-engineer.sh` | `pe` prompt-optimizer CLI alias | `CLAUDE.md` §Prompt Optimization Pipeline |

### 4. Third-party skill installers

Bridge installers that delegate to upstream skill repositories. Invoked via `lib/dispatch.sh` (claude-memo) or `lib/skills.sh` (impeccable). Not exposed as top-level `curl | bash` URLs.

| Script | Upstream | Invoked from |
|--------|----------|---------------|
| `install-claude-memo.sh` | `your-user/memo.git` placeholder | `lib/dispatch.sh:dispatch_claude_memo` |
| `install-impeccable.sh` | `pbakaus/impeccable` (npx) | `lib/skills.sh` |

### 5. Maintenance & lifecycle

| Script | Action | When to use |
|--------|--------|-------------|
| `update-claude.sh` | Smart in-place refresh with CLAUDE.md merge | `/update-toolkit` slash + safe re-run |
| `update-deps.sh` | Interactive Layer-1/2/3 dependency dashboard | `/update-deps` slash |
| `verify-install.sh` | Read-only health check | post-install + `~/.claude/scripts/` mirror |
| `uninstall.sh` | Project teardown + opt-in global teardown | `--remove-hooks` / `--remove-cost-routing` / `--keep-state` flags |
| `migrate-to-complement.sh` | One-time v3.x → v4 SP/GSD complement | only for v3.x cohort |
| `migrate-v5-to-v6.sh` | Guided v5.x → v6.0 wrapper | only for v5.x cohort |
| `archive-planning-to-vault.sh` | Move stale `.planning/` artifacts | maintainer-only |

### 6. Maintainer-only (not user-facing)

| Script | Action |
|--------|--------|
| `sync-skills-mirror.sh` | Resync `templates/skills-marketplace/` from upstream (closed-loop in v6.46.0+) |
| `generate-skills-catalog.sh` | Regenerate `templates/skills-catalog.json` from `manifest.json:skills_pins` (v6.46.0+) |
| `validate-manifest.py` | Manifest schema + drift + note↔data validator |
| `validate-commands.py` | Slash-command header validator |
| `validate-integrations-catalog.py` | Integrations catalog schema |
| `validate-marketplace.sh` | Plugin marketplace JSON validator |
| `validate-release.sh` | Per-cell install matrix validator |
| `validate-skills-desktop.sh` | Desktop-safe skill registry validator |
| `propagate-audit-pipeline-v42.sh` | SOT fan-out into 6 base audit prompts |
| `detect.sh` | Plugin presence detector (sourced by other installers) |
| `cell-parity.sh` | Cross-cell parity diff (CI helper) |
| `vendor/pin-vendors.sh`, `vendor/clone-pinned.sh`, `vendor/diff-summary.sh` | Vendor pin lifecycle (under `scripts/vendor/`) |

### 7. Internal libraries

Not user-invocable. Sourced by category 1-6 scripts. Listed only for
completeness — never `curl | bash` these. Live under `scripts/lib/`:

| File | Purpose |
|------|---------|
| `backup.sh` | Pre-update `.claude-backup-<timestamp>/` snapshot helper |
| `bootstrap.sh` | SP / GSD pre-install bootstrap contract |
| `bridges.sh` | Multi-CLI bridges (Gemini, Codex, …) sync + uninstall |
| `cli-installer.sh` | Companion CLI binary installer helpers |
| `cli-recommendations.sh` | Recommended-CLIs catalog + prompt helpers |
| `council-prompts.sh` | Council prompt-template loader |
| `detect2.sh` | Layered plugin/feature detection (v6 redesign) |
| `dispatch.sh` | Per-component installer dispatch table |
| `dry-run-output.sh` | `--dry-run` accumulator + formatter |
| `install.sh` | Shared install helpers (PreToolUse partition, file copy) |
| `integrations-catalog.json` | MCP + integration catalog (data, not code) |
| `mcp.sh` | `claude mcp add/remove` wrappers |
| `optional-plugins.sh` | Optional-plugin install helpers (caveman, …) |
| `post-install-guide.sh` | Closing banner + next-step recommendations |
| `project-secrets.sh` | Secret-bearing file detection (uninstall safety) |
| `skill-checksum.sh` | Reproducible directory-content hash (closed-loop sync, v6.46.0+) |
| `skills.sh` | Skills-mirror install + dispatch helpers |
| `state.sh` | `toolkit-install.json` state read/write |
| `tui.sh` | Shared TUI prompt + colour primitives |

### 8. Sub-tool subdirectories

Not first-class scripts. Live under their own subdirectory, ship
together as a unit, and are documented by their own README.

| Path | Purpose |
|------|---------|
| `scripts/council/` | Supreme Council (`brain.py`, `mcp-server.py`, `pack.py`, `prompts/`, `config.json.template`) |
| `scripts/prompt-engineer/` | `pe` prompt-optimizer CLI (`optimize_prompt.py`) |
| `scripts/vendor/` | Vendor-pin lifecycle scripts (listed under Category 6 above) |
| `scripts/tests/` | Maintainer test suite (`test-*.sh`) — invoked from `Makefile:test` |

## Prefix decision rule

When adding a new script under `scripts/`:

1. **Does it install or set up a component that the user opts into?**
   - First-time interactive entry point → `install.sh` (do not add another).
   - Single component installer with a `curl | bash` URL → `install-<name>.sh`.
   - Opt-in extension (not part of default TUI) → `setup-<name>.sh`.

2. **Is it a worker invoked by another script and never run directly by the user?**
   - Lives under `scripts/lib/`. No prefix needed.

3. **Is it a third-party skill installer?**
   - `install-<skill-name>.sh` (matches the existing pair).

4. **Is it a maintenance / validation / lifecycle action?**
   - Pick the action verb: `update-*`, `verify-*`, `validate-*`, `migrate-*`, `uninstall.sh`.

5. **Is it maintainer-only (not for end users)?**
   - Action verb without prefix is fine: `sync-*`, `propagate-*`, `cell-*`, `detect.sh`.

## Why no renames

Logic audit 2026-05-18 found the taxonomy unprincipled but every script is reachable from a stable URL (`curl | bash` consumers depend on the path). A rename ripples through:

- Every `bash <(curl -sSL .../scripts/<name>.sh)` invocation in README, docs, blog posts, screencasts, and user shell history.
- `dispatch.sh` URL constants.
- `manifest.json:files.scripts[].path` entries.
- Cell harness `validate-release.sh --cell` arguments.
- External integrations (e.g., `gsd-build` references to `setup-security.sh`).

Documentation is cheap; rename is breaking. Pick the prefix per the decision rule above and the existing 18 scripts stay as-is.
