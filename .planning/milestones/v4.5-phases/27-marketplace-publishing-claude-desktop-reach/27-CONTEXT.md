# Phase 27: Marketplace Publishing + Claude Desktop Reach - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

The toolkit becomes discoverable and installable via Claude Code's plugin marketplace mechanism. A repo-root `.claude-plugin/marketplace.json` declares 3 sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`) each with valid `plugin.json` schema. Desktop users (no `claude` CLI on PATH) running `scripts/install.sh` route automatically to `--skills-only` mode placing skills at `~/.claude/plugins/tk-skills/`. CI gates skill compatibility for Desktop via `validate-skills-desktop.sh`. `docs/CLAUDE_DESKTOP.md` documents capability matrix. README + INSTALL.md document both channels.

Out of scope: actual marketplace.json publication PR to upstream Anthropic registry; cross-platform Desktop testing; non-skill plugin Desktop reach.
</domain>

<decisions>
## Implementation Decisions

### Marketplace Surface Layout

- **`.claude-plugin/marketplace.json` schema** (per MKT-01):
  ```json
  {
    "name": "claude-code-toolkit",
    "owner": { "name": "sergei-aronsen" },
    "plugins": [
      { "name": "tk-skills", "source": "./plugins/tk-skills" },
      { "name": "tk-commands", "source": "./plugins/tk-commands" },
      { "name": "tk-framework-rules", "source": "./plugins/tk-framework-rules" }
    ]
  }
  ```
- **NO version in marketplace.json plugin entries** (per MKT-02 explicit guidance — `plugin.json` silently wins).

### Sub-Plugin Structure

- **`plugins/tk-skills/`** (Desktop-compatible):
  - `.claude-plugin/plugin.json` — version 4.5.0, category "skills", tags ["mirror", "marketplace"], description "22 curated skills mirrored from skills.sh"
  - `skills/` symlink or directory mirror of `templates/skills-marketplace/<name>/` content
  - LICENSE file at sub-plugin root

- **`plugins/tk-commands/`** (Code only):
  - `.claude-plugin/plugin.json` — version 4.5.0, category "commands", tags ["slash-commands", "code-only"], description "29 slash commands for Claude Code workflows"
  - `commands/` directory mirror of repo `commands/*.md`

- **`plugins/tk-framework-rules/`** (Code only):
  - `.claude-plugin/plugin.json` — version 4.5.0, category "rules", tags ["framework-templates", "code-only"]
  - `templates/` mirror of `templates/{base,laravel,rails,nextjs,nodejs,python,go}/`

- **Mirroring strategy:** Symlinks at first, with `make build-marketplace` target that resolves to real copies for distribution. (Symlinks keep CI simple and the plugin tree stays in sync with primary content.)

### Validate-Skills-Desktop Gate

- **`scripts/validate-skills-desktop.sh`** (DESK-02) scans every `templates/skills-marketplace/<name>/SKILL.md` for:
  - Bash code-block fences with `bash` lang AND code that requires `Read`/`Write`/`Bash`/`Grep`/`Edit` tool execution
  - Explicit references to "Use the Read tool" / "Run via Bash" / "Execute X"
- Heuristic: regex match on `(?:Read|Write|Bash|Grep|Edit|Task)\(` or `Use (?:the )?(?:Read|Bash|Write) tool` in SKILL.md.
- Per-skill verdict: **PASS** if no matches (Desktop-safe, instruction-only), **FLAG** otherwise (Code-only).
- Output table to stdout + `.audit-skills-desktop.txt` artifact.
- **Threshold:** at least 4 skills must PASS or `make validate-skills-desktop` exits 1 (DESK-04).

### Install.sh Desktop-Only Routing (DESK-03)

- **Detection:** `command -v claude` returns non-zero → set `TK_DESKTOP_ONLY=1` internally.
- **Routing:** When `TK_DESKTOP_ONLY=1` and no explicit `--mcps`/`--skills`/etc flag passed, `install.sh` auto-promotes to `--skills-only` mode.
- **`--skills-only` semantics:**
  - Skills installed to `~/.claude/plugins/tk-skills/` (NOT project-local `.claude/skills/`).
  - Banner: `Claude CLI not detected — installing skills only. Skills available in Claude Desktop Code tab. See docs/CLAUDE_DESKTOP.md for full capability matrix.`
  - Other components (MCPs, security setup, statusline) not offered.

### CLAUDE_DESKTOP.md Capability Matrix

- Table format with 4 columns: Capability | Desktop Code Tab | Desktop Chat Tab | Code Terminal
- Rows: skills, slash-commands, MCPs, statusline, security wizard, framework rules
- Verdicts: ✅ available, ❌ unavailable, ⚠ partial (with footnote)
- Plain-English explanation of "why" plugins don't work in Chat tab + remote sessions
- Read-time target: under 1 minute (DESK-01)

### Make Targets + CI Wiring

- **`make validate-marketplace`** — gated behind `TK_HAS_CLAUDE_CLI=1` env var (CI runner doesn't have `claude` by default per MKT-03). Runs `claude plugin marketplace add ./` from a hermetic clone, asserts 3 sub-plugins discovered.
- **`make validate-skills-desktop`** — runs `scripts/validate-skills-desktop.sh`, exits 1 if fewer than 4 PASS.
- **`make check`** chains both. `validate-marketplace` is no-op without `TK_HAS_CLAUDE_CLI=1` (skips with skip notice).
- CI: extends quality.yml `Tests 21-33` step name to `Tests 21-34` (validate-marketplace step + validate-skills-desktop step).

### Version Source-of-Truth (MKT-02)

- All `plugin.json` files declare version `4.5.0` (the milestone version).
- `manifest.json` v4.5.0 bumped in this phase (final phase of v4.5 milestone).
- `CHANGELOG.md [4.5.0]` section documents Phase 24-27 deliverables in one entry (mirrors v4.4 consolidation).

### Claude's Discretion

- Specific category/tag values in `plugin.json` follow Anthropic plugin marketplace conventions where available; if conventions are TBD, use lowercase kebab-case.
- Capability matrix wording in CLAUDE_DESKTOP.md.
- Exact heuristic regex for `validate-skills-desktop.sh`.
- Symlink vs build-marketplace target decision can flip if symlinks cause platform issues (Windows CI).
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/install.sh` (Phase 24+25+26) — already gates on `command -v claude`; extend with `TK_DESKTOP_ONLY` auto-detection.
- `scripts/lib/skills.sh` (Phase 26) — `is_skill_installed`, `skills_install` reusable for `--skills-only` Desktop path.
- `manifest.json` schema validator (`scripts/validate-manifest.sh`) — pattern for new `validate-marketplace.sh`.
- `Makefile` — chain new validators into `make check`.
- `templates/skills-marketplace/` (Phase 26) — content directly mirrored as `tk-skills` plugin.

### Established Patterns
- All shell scripts: `set -euo pipefail`, ANSI color helpers, `${RED}/${GREEN}/${YELLOW}/${NC}`.
- Validators exit 1 on failure with clear `Error:` prefix; exit 0 on success or skip with `[skipped]` notice.
- `make` targets idempotent.

### Integration Points
- `manifest.json` — version 4.4.0 → 4.5.0 bump.
- `CHANGELOG.md` — new `[4.5.0]` section consolidating phases 24-27.
- `Makefile` — new targets: `validate-marketplace`, `validate-skills-desktop`, `build-marketplace` (optional). `make check` chain extended.
- `.github/workflows/quality.yml` — extend "Tests 21-33" step + new "validate-marketplace" + "validate-skills-desktop" steps.
- `README.md` — new "Install via marketplace" section.
- `docs/INSTALL.md` — both channels documented as equivalent for Code; marketplace-only for Desktop.
- `scripts/install.sh` — Desktop-only routing branch.

### File Layout

```
.claude-plugin/
  marketplace.json
plugins/
  tk-skills/
    .claude-plugin/plugin.json
    skills/  (symlink → ../../templates/skills-marketplace/)
    LICENSE
  tk-commands/
    .claude-plugin/plugin.json
    commands/  (symlink → ../../commands/)
  tk-framework-rules/
    .claude-plugin/plugin.json
    templates/  (symlink → ../../templates/) — excludes skills-marketplace
docs/
  CLAUDE_DESKTOP.md  (new)
scripts/
  validate-skills-desktop.sh  (new)
  validate-marketplace.sh  (new — wraps `claude plugin marketplace add`)
  install.sh  (modified — Desktop routing)
```
</code_context>

<specifics>
## Specific Ideas

- Symlinks chosen over copies for sub-plugin trees: zero duplication, zero stale-content drift, simpler maintenance. macOS + Linux symlinks Just Work; Windows CI uses Git Bash which respects symlinks — verify on first CI run.
- The `validate-skills-desktop.sh` heuristic is intentionally conservative: PASS only if no tool-execution patterns. Skills with FLAG verdict CAN still be installed locally — the gate is for Desktop reach quality, not for blocking installation.
- `--skills-only` is also accessible explicitly via `scripts/install.sh --skills-only` even with CLI present (for users who want only skills regardless of CLI availability).
- `claude` CLI is required for `make validate-marketplace`; CI runner does not have it. Default: `validate-marketplace` skips with `[skipped — TK_HAS_CLAUDE_CLI not set]` notice.
</specifics>

<deferred>
## Deferred Ideas

- **Upstream marketplace registry PR** — submitting `claude-code-toolkit` to Anthropic's central marketplace registry. Manual maintainer task post-merge.
- **Cross-platform Desktop reach beyond skills** — getting MCPs, statusline, etc. into Desktop. Requires Anthropic plugin runtime expansion; defer.
- **Plugin auto-update via marketplace** — pulling updates from marketplace.json source. Phase 27 is publish-only; pull-side handled by Anthropic's plugin runtime.
- **Per-platform install instructions** — Windows-specific marketplace setup, Linux distros, etc. Defer; v1 documents macOS + generic Bash 3.2.
- **Internal sub-plugin auto-version-sync** — keep all 3 plugin.json versions in sync programmatically. Defer; manual bump once per milestone is fine.
</deferred>
