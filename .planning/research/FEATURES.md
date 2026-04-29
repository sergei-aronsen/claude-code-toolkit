# Feature Research

**Domain:** Multi-component CLI TUI installer + Claude Code plugin marketplace publishing
**Researched:** 2026-04-29
**Confidence:** HIGH (official Anthropic docs + codebase analysis + pattern research)

---

## Context: v4.5 Scope

This file supersedes the v4.0 FEATURES.md for Phase 24 (Unified TUI Installer) and Phase 25
(Marketplace + Desktop reach). The old file covered complement-mode install flow; everything
in it is now shipped. This file covers only new v4.5 territory.

**Existing v4.4 capabilities that are the baseline for v4.5:**

- `scripts/lib/bootstrap.sh` — two-prompt `[y/N]` SP/GSD pre-install flow (BOOTSTRAP-01..04)
- `scripts/lib/optional-plugins.sh` — end-of-run `recommend_optional_plugins()` block
- `scripts/lib/dry-run-output.sh` — chezmoi-grade `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` grouped output
- `scripts/lib/detect.sh` — filesystem-primary detection with `claude plugin list` cross-check
- `scripts/init-claude.sh` — 5 separate install flags incl. `--no-bootstrap`, `--no-banner`, `--mode`, `--dry-run`, `--force`
- `scripts/uninstall.sh` — full SHA256 classify + `[y/N/d]` + `--keep-state` + backup

---

## Section 1: TUI Installer Feature Taxonomy (Phase 24)

### Table Stakes — Must-Have for the TUI Installer

Features users of any multi-component developer tool installer expect to exist. Missing these
means users regress from the current v4.4 sequential-prompt flow.

| Feature | Why Expected | Complexity | Category | REQ-ID Candidate |
|---------|--------------|------------|----------|-----------------|
| Arrow-key + Space toggle checkbox menu | Every developer knows `[space]` = select, `[enter]` = confirm from npm/rustup/homebrew select UIs. Absence = friction vs current linear prompts | MEDIUM | Table-stakes | TUI-01 |
| Pre-check already-installed components | Show `[installed]` label and pre-tick items already on disk. User should not need to re-read detection docs to understand what's safe to skip | LOW | Table-stakes | TUI-02 |
| Component descriptions visible in menu | Each row shows one-line purpose ("RTK — 60-90% token savings on dev commands"). Without this, users can't make informed checkbox choices | LOW | Table-stakes | TUI-03 |
| Confirmation step before any install runs | "You selected: Toolkit, Security Pack, RTK. Proceed? [Y/n]" — rustup model: 1) Proceed with standard 2) Customize 3) Cancel | LOW | Table-stakes | TUI-04 |
| Non-interactive `--yes` mode for CI | Must accept `--yes` flag that selects the default set and proceeds without TTY. All existing `--no-bootstrap` / `NO_BANNER=1` env overrides must still work | LOW | Table-stakes | TUI-05 |
| `--dry-run` pass-through | TUI renders the selected set, then runs all installers with `--dry-run`. Shows what would happen without writing. Reuses existing `dro_*` output | LOW | Table-stakes | TUI-06 |
| Abort / Ctrl-C handling | `stty sane` restore on `SIGINT` / `SIGTERM`; no garbled terminal left behind | LOW | Table-stakes | TUI-07 |
| Post-install summary | After all installers complete, print one-block summary: what was installed, what was skipped, what was already current | LOW | Table-stakes | TUI-08 |
| No-TTY graceful degradation | When stdout is not a terminal (piped, CI), fall back to linear `[y/N]` prompts — identical to current bootstrap.sh behavior | MEDIUM | Table-stakes | TUI-09 |

**Confidence:** HIGH — verified against blurayne pure-bash gist, rustup install UX, and existing
`bootstrap.sh` behavior pattern. The `/dev/tty` guard pattern is already in the codebase.

### Differentiators — Nice-to-Have for the TUI Installer

Features that make this TUI better than a simple upgrade to the sequential prompts.

| Feature | Value Proposition | Complexity | Category | Notes |
|---------|-------------------|------------|----------|-------|
| Grouped sections in menu ("Core" / "Optional") | Separates "Toolkit + Security" (recommended for all) from "RTK / Statusline / Council" (power-user). Prevents option paralysis for new users | LOW | Differentiator | Two visual sections; pre-select Core group by default |
| `[installed]` vs `[update available]` vs `[not installed]` state labels | Users know at a glance what the menu will do. chezmoi-style state display. More informative than boolean pre-check | MEDIUM | Differentiator | Requires centralized detection for all 6 components |
| Per-component version display | Show current installed version and available version in the menu row when detectable. Useful for statusline + RTK | MEDIUM | Differentiator | Version detection complexity varies: RTK via `rtk --version`, statusline via manifest |
| `--preset minimal|full|dev` flag | `--preset minimal` = Toolkit + Security only; `--preset full` = all; `--preset dev` = all + force-reinstall | MEDIUM | Differentiator | Rustup profile pattern. Useful for dotfiles/bootstrap scripts |
| Dependency hints in menu | If user unchecks Security Pack while Council is checked, show "Council benefits from Security Pack — installing both is recommended" | MEDIUM | Differentiator | Soft hint, never a hard block. Order-dependent logic |
| `--force` component re-install | For each checked component that shows `[installed]`, `--force` triggers its installer with `--force` flag | LOW | Differentiator | Extends existing `--force` flag semantics to TUI context |
| `NO_COLOR` / `NO_EMOJI` mode | Menu renders with plain ASCII `[x]` / `[ ]` and no color codes when `NO_COLOR` env is set or stdout is not a TTY | LOW | Differentiator | Extends existing `${NO_COLOR+x}` + `[ -t 1 ]` pattern from `dry-run-output.sh` |
| Re-runnable install.sh as health check | Running `install.sh` on an already-configured machine shows current state with `[installed]` labels for all components. No prompts, just status | LOW | Differentiator | Same as `verify-install.sh` but surfaced as the primary entry point |

### Anti-Features — Explicitly Must NOT Add

| Anti-Feature | Why It Seems Attractive | Why We Avoid It | What to Do Instead |
|---|---|---|---|
| `whiptail` or `dialog` dependency | Pre-installed on most Linux; gives ncurses polish | Not on macOS (where the primary install target is solo dev machines). Breaks POSIX constraint. `whiptail` behavior differs between versions | Pure-bash arrow-key TUI using `read -s -n1` + ANSI escape sequences from `/dev/tty` |
| `gum` (Charm) dependency | Beautiful, modern, single binary | Binary dependency for an installer = extra install step, versioning risk, macOS/Linux arch splits. Violates "no runtime dependency for install scripts" constraint | Use pure bash. Accept that the menu will be simpler visually |
| GUI fallback (zenity, Cocoa dialog) | Desktop users might prefer it | Breaks headless/SSH/CI use. Adds macOS-only paths. No real user demand for this in a developer tool | Stick to terminal TUI |
| Network calls during menu rendering | Auto-fetch current versions to display in menu | Adds latency before menu appears. If network is slow or offline, menu hangs or looks broken | Show menu immediately from local state; versions are fetched only when a component is selected for install |
| Telemetry / install analytics | Useful for understanding adoption | No privacy policy in place; violates user trust expectations for a POSIX shell script | Never collect telemetry |
| Wizard-style multi-page flow | Mimics native installers (macOS .pkg) | Harder to implement in pure bash; confusing when user wants to go back. Multiple pages = more failure surfaces | Single-screen checkbox menu with sections. Enter = confirm. Escape = cancel. Done. |
| Auto-updating install.sh itself | Keeps installer current | Circular dependency: installer must update itself from the internet before it knows what to install | User re-curls the latest `install.sh` via the documented command. No self-update in installer |

---

## Section 2: Centralized Detection for TUI (Phase 24)

### Table Stakes

| Feature | Why Expected | Complexity | Category | Notes |
|---------|--------------|------------|----------|-------|
| `is_rtk_installed` via `command -v rtk` | RTK is now a recommended component; current `setup-security.sh` only checks npm path, not brew path. `command -v` covers both | LOW | Table-stakes | DET-01 |
| `is_statusline_installed` via `~/.claude/statusline.sh` + `grep statusLine ~/.claude/settings.json` | Both signals needed: file presence alone doesn't mean it's wired into settings | LOW | Table-stakes | DET-02 |
| `is_cc_safety_net_installed` via `command -v cc-safety-net` | Safety net can be installed via brew OR npm; only `command -v` is reliable regardless of install method. Current `setup-security.sh` only checks npm | LOW | Table-stakes | DET-03 |
| `is_council_installed` via `[ -f ~/.claude/council/brain.py ]` | Simple file check is sufficient; already used internally | LOW | Table-stakes | DET-04 |
| All `is_*` functions exposed from `scripts/lib/detect.sh` | Single sourcing point so TUI, update, verify-install all use the same signals | LOW | Table-stakes | DET-05 |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Version detection for RTK (`rtk --version`) | Show "RTK 2.3.1 installed" vs "RTK not installed" in TUI | LOW | Parse first token of version output |
| Version detection for GSD (`grep version ~/.claude/get-shit-done/package.json`) | Useful for `warn_version_skew()` extension | LOW | Already has partial support via `toolkit-install.json` |
| Statusline wiring check (both file AND settings) | File present but not wired into settings = broken state. TUI should detect and offer to fix | MEDIUM | Two-signal check is novel over current single-signal |

---

## Section 3: Plugin Marketplace Feature Taxonomy (Phase 25)

The Anthropic Claude Code marketplace system is documented at `code.claude.com/docs/en/plugin-marketplaces`.
The following is based on HIGH confidence from official docs fetched 2026-04-29.

### Marketplace JSON Schema (Required Fields — Official Spec)

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "claude-code-toolkit",
  "owner": { "name": "Sergei Aronsen", "email": "sergei.aronsen@gmail.com" },
  "plugins": [
    {
      "name": "tk-skills",
      "source": "./plugins/tk-skills",
      "description": "Framework-aware agent skills (Desktop + Code)",
      "category": "development",
      "version": "4.5.0"
    }
  ]
}
```

Location: `.claude-plugin/marketplace.json` at repository root.

### Table Stakes — Marketplace

| Feature | Why Expected | Complexity | Category | Notes |
|---------|--------------|------------|----------|-------|
| `.claude-plugin/marketplace.json` at repo root | Required by Claude Code plugin system. Without this file, `/plugin marketplace add sergei-aronsen/claude-code-toolkit` fails entirely | LOW | Table-stakes | MKT-01 |
| At least one plugin with `name` + `source` + `description` | Minimum for a plugin to be installable from the marketplace | LOW | Table-stakes | MKT-02 |
| `version` field on each plugin | Without explicit version, every git commit counts as a new version — users get unintended updates on `marketplace update` | LOW | Table-stakes | MKT-03 |
| `category` field on each plugin | Used for discovery in the `/plugin` Discover tab. Must match one of: `development`, `security`, `productivity`, `design`, `database`, `deployment`, `monitoring` | LOW | Table-stakes | MKT-04 |
| Relative-path source that works with git-based marketplace add | Plugins in the same repo use `"source": "./plugins/tk-skills"`. Path resolves relative to marketplace root (repo root), not `.claude-plugin/` directory | LOW | Table-stakes | MKT-05 |
| `plugin.json` manifest inside each plugin | `<plugin-dir>/.claude-plugin/plugin.json` with `name`, `description`, `version`. Required for plugin identity | LOW | Table-stakes | MKT-06 |
| Skills directory following `skills/<name>/SKILL.md` convention | Standard plugin component format. Claude auto-discovers skills on install | LOW | Table-stakes | MKT-07 |
| Auto-update via `version` bump | When TK ships a new version, bumping `version` in marketplace.json causes `/plugin marketplace update` to deliver it | LOW | Table-stakes | MKT-08 |

**Confidence:** HIGH — directly from official Anthropic plugin marketplace docs (fetched 2026-04-29).

### Differentiators — Marketplace

| Feature | Value Proposition | Complexity | Category | Notes |
|---------|-------------------|------------|----------|-------|
| Three sub-plugins with clear scope separation | `tk-skills` (Desktop-compatible), `tk-commands` (Code only), `tk-framework-rules` (Code only). Users can install only what works for their runtime | LOW | Differentiator | MKT-09 |
| `keywords` / `tags` for discovery | Improves searchability in `/plugin` Discover tab (e.g., `["security", "audit", "framework", "laravel", "nextjs"]`) | LOW | Differentiator | Official spec supports `keywords` and `tags` arrays |
| `homepage` pointing to docs | Links from plugin Discover tab to TK documentation | LOW | Differentiator | |
| SHA pinning for external plugin dependencies | If any sub-plugin depends on an external source, pin with `sha` for reproducible installs | MEDIUM | Differentiator | Only relevant if sub-plugins use `git-subdir` sources |
| `allowCrossMarketplaceDependenciesOn` listing `claude-plugins-official` | If `tk-commands` depends on superpowers being installed, declare the dependency explicitly rather than silently failing | MEDIUM | Differentiator | Official spec supports this field |
| Strict mode (`"strict": false`) for `tk-framework-rules` | Rules don't follow the standard `plugin.json` component schema; `strict: false` lets Claude Code parse them gracefully | LOW | Differentiator | Prevents install failures from non-standard content |

### Anti-Features — Marketplace

| Anti-Feature | Why We Avoid It | What to Do Instead |
|---|---|---|
| Shell scripts inside plugin bundles | Hooks that execute scripts work in Claude Code but not reliably in Desktop. Breaks the "Desktop-safe" promise for `tk-skills` | Skills in `tk-skills` must be pure Markdown SKILL.md files with no `hooks/` or `bin/` directories |
| MCP server in marketplace plugin | MCP requires running a server process; Desktop may not launch it | MCP setup stays in `scripts/setup-council.sh` (manual install); never inside marketplace plugins |
| Monitors directory in `tk-skills` | Monitor configs run `tail -F` and similar shell commands — not Desktop-safe | No monitors in marketplace plugins |
| `settings.json` in plugin bundle that overrides user settings | Could silently change user's Claude Code behavior on install | Plugin `settings.json` is limited to `agent` and `subagentStatusLine` keys; avoid even those in TK plugins |
| Monolithic single plugin | Bundles Code-only things (hooks, commands) with Desktop-safe things (skills). Desktop users get install errors or confusion | Split into three named plugins with clear runtime annotations in their descriptions |

---

## Section 4: Claude Desktop Reach (Phase 25)

### The Desktop/Code Compatibility Split

Based on official docs (HIGH confidence, fetched 2026-04-29):

| Component Type | Claude Code | Claude Desktop | Notes |
|---|---|---|---|
| Skills (`skills/<name>/SKILL.md`, pure markdown) | Yes | Yes | PRIMARY Desktop value. Skills work everywhere |
| Agents (`agents/*.md`, markdown + frontmatter) | Yes | Yes | Works, but `hooks`, `mcpServers`, `permissionMode` NOT supported in plugin agents |
| Slash commands (`commands/*.md`, flat markdown) | Yes | Yes (namespaced) | Skills replace commands for new plugins; both work |
| Hooks (`hooks/hooks.json`, shell execution) | Yes | No — Desktop has no shell executor | Never put hooks in Desktop-targeted plugins |
| MCP servers (`.mcp.json`, requires process spawn) | Yes | Partially — Desktop can connect to running MCP servers but cannot launch them via plugin | Keep MCP setup manual |
| LSP servers | Yes | No | Development-environment only |
| Monitors (`monitors/monitors.json`, `tail -F` shell) | Yes | No | Shell-dependent |
| Project rules (`.claude/rules/*.md`) | Yes | No — Desktop has no project context | CLAUDE.md and rules are Code-only |
| Local plugin install (`/plugin marketplace add ./local`) | CLI only | No — Desktop only supports marketplace-based install (confirmed Anthropic support 2026-04-22) | Users must use CLI to manage local plugins |

**Source:** `github.com/anthropics/claude-code/issues/52147` confirms Desktop plugin UI only supports marketplace-based installs as of 2026-04-22. Confidence: MEDIUM (GitHub issue + Anthropic support statement).

### Table Stakes — Desktop Reach

| Feature | Why Expected | Complexity | Category | Notes |
|---------|--------------|------------|----------|-------|
| `docs/CLAUDE_DESKTOP.md` explaining what works vs not | Desktop users who find TK via marketplace or README need a clear, honest compatibility table upfront. No documentation = confused installs and support requests | LOW | Table-stakes | DESK-01 |
| `tk-skills` plugin in marketplace with ONLY pure-markdown skills | Desktop users can `/plugin install tk-skills@claude-code-toolkit`. Zero shell, zero hooks, zero MCP. Just SKILL.md files | MEDIUM | Table-stakes | DESK-02 |
| Detection of Desktop-only context in `install.sh` | When the `claude` binary is absent but `.claude/` exists (Desktop creates it), route user to `docs/CLAUDE_DESKTOP.md` instead of the full TUI installer | MEDIUM | Table-stakes | DESK-03 |
| Audit of existing TK skills for Desktop safety | Every skill in `templates/*/skills/*/SKILL.md` must be reviewed: does it reference shell commands, `$CLAUDE_PROJECT_ROOT`, hooks, or bash in the body? If yes, it's Code-only | MEDIUM | Table-stakes | DESK-04 |

### Differentiators — Desktop Reach

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| `[Code only]` / `[Desktop + Code]` annotations in skill YAML frontmatter | Explicit machine-readable compatibility markers. Future `verify-install.sh` can check them | LOW | Custom frontmatter field; e.g., `runtime: desktop+code` |
| `--skills-only` flag in `install.sh` | Surfaces the subset install path from CLI. Useful for Desktop users who also have the CLI | MEDIUM | Places skills under `~/.claude/plugins/` (global install) instead of `.claude/` (project) |
| Honest "not supported" list in marketplace plugin description | `tk-framework-rules` description: "Requires Claude Code CLI. Not compatible with Claude Desktop." — prevents wasted installs | LOW | One-line description amendment |
| Desktop install documentation at top of README | Visible to users discovering via GitHub or marketplace | LOW | Existing README reorganization |

### Anti-Features — Desktop Reach

| Anti-Feature | Why We Avoid It | What to Do Instead |
|---|---|---|
| Claiming full parity with CLI when installing `tk-skills` | Creates false expectation that all TK features work in Desktop | Explicit compatibility table; honest "what you get" vs "what needs CLI" framing in CLAUDE_DESKTOP.md |
| Separate Desktop-specific maintenance track | Two copies of skills diverge quickly; 1-developer project cannot sustain it | Single skill source; use `runtime:` frontmatter annotation to mark Desktop-unsafe skills |
| Installing framework rules or hooks as part of Desktop path | Rules need CLAUDE.md context (Code only). Hooks need shell executor (Code only) | Desktop path installs ONLY `tk-skills` plugin; all other components are Code-only and documented as such |
| Requiring users to understand the Desktop/Code split before installing | Cognitive overhead before users see any value | Detection in `install.sh` automatically routes Desktop-only users; they never see the TUI |

---

## Feature Dependencies

```text
[TUI Installer]
    requires --> [Centralized Detection (DET-01..05)]
    requires --> [Non-TTY fallback (existing bootstrap.sh)]
    reuses   --> [dro_* output library (UX-01)]
    reuses   --> [--no-banner / --dry-run flags (BANNER-01)]

[Marketplace Publishing]
    requires --> [Skill audit for Desktop safety (DESK-04)]
    enables  --> [Desktop Reach (DESK-01..03)]

[Centralized Detection]
    extends  --> [detect.sh (DETECT-01..07, existing)]
    enables  --> [TUI pre-check labels (TUI-02)]
    enables  --> [Desktop routing in install.sh (DESK-03)]

[Desktop Reach]
    depends  --> [tk-skills plugin (DESK-02)]
    depends  --> [Marketplace Publishing (MKT-01..08)]

[--skills-only path]
    requires --> [Centralized Detection (detect Desktop context)]
    requires --> [tk-skills plugin exists in marketplace]
```

### Dependency Notes

- **TUI requires Centralized Detection:** Menu cannot show `[installed]` labels without unified
  `is_*_installed` functions covering all 6 components. This is the prerequisite blocker for Phase 24.

- **Marketplace requires Skill Audit:** Before publishing `tk-skills` to the marketplace, every
  skill must be reviewed for Desktop safety (DESK-04). Publishing untested skills damages Desktop
  users' trust immediately.

- **Desktop path requires Marketplace:** Desktop users cannot install via `curl | bash`. The only
  path is `/plugin install tk-skills@claude-code-toolkit`. Marketplace must ship before Desktop
  documentation is accurate.

- **bootstrap.sh is NOT replaced by TUI:** bootstrap.sh becomes the no-TTY fallback path inside
  the TUI's graceful degradation (TUI-09). When TTY is unavailable (CI, piped), `install.sh`
  delegates to the existing `bootstrap_base_plugins()` call. The `--no-bootstrap` and `TK_NO_BOOTSTRAP`
  opt-outs survive unchanged.

- **dry-run-output.sh is reused by TUI post-install summary:** The `dro_*` API already produces
  the exact grouped output format needed for TUI-08. No new output library needed.

---

## Phase Mapping: Phase 24 vs Phase 25

### Phase 24 — TUI Installer + Centralized Detection

| REQ-ID | Feature | Category | Complexity |
|--------|---------|----------|------------|
| TUI-01 | Arrow-key + space checkbox menu | Table-stakes | MEDIUM |
| TUI-02 | Pre-check installed components | Table-stakes | LOW |
| TUI-03 | Component descriptions in menu | Table-stakes | LOW |
| TUI-04 | Confirmation step | Table-stakes | LOW |
| TUI-05 | `--yes` non-interactive mode | Table-stakes | LOW |
| TUI-06 | `--dry-run` pass-through | Table-stakes | LOW |
| TUI-07 | Abort / Ctrl-C terminal restore | Table-stakes | LOW |
| TUI-08 | Post-install summary | Table-stakes | LOW |
| TUI-09 | No-TTY graceful degradation | Table-stakes | MEDIUM |
| DET-01 | `is_rtk_installed` via `command -v` | Table-stakes | LOW |
| DET-02 | `is_statusline_installed` (file + settings) | Table-stakes | LOW |
| DET-03 | `is_cc_safety_net_installed` via `command -v` | Table-stakes | LOW |
| DET-04 | `is_council_installed` via file check | Table-stakes | LOW |
| DET-05 | All `is_*` from `detect.sh` | Table-stakes | LOW |

Differentiators from Phase 24 to sequence for later in the phase:

- Grouped menu sections (LOW — schedule after TUI-01 works)
- `[installed]` vs `[update available]` state labels (MEDIUM — after DET-01..05)
- `NO_COLOR` / `NO_EMOJI` mode (LOW — extends existing pattern)
- `--preset minimal|full|dev` (MEDIUM — can be post-MVP for Phase 24)

### Phase 25 — Marketplace + Desktop Reach

| REQ-ID | Feature | Category | Complexity |
|--------|---------|----------|------------|
| MKT-01 | `.claude-plugin/marketplace.json` at repo root | Table-stakes | LOW |
| MKT-02 | At least one installable plugin | Table-stakes | LOW |
| MKT-03 | `version` field on each plugin | Table-stakes | LOW |
| MKT-04 | `category` field on each plugin | Table-stakes | LOW |
| MKT-05 | Relative-path source for git-based install | Table-stakes | LOW |
| MKT-06 | `plugin.json` manifest inside each plugin | Table-stakes | LOW |
| MKT-07 | `skills/<name>/SKILL.md` structure | Table-stakes | LOW |
| MKT-08 | Auto-update via `version` bump | Table-stakes | LOW |
| DESK-01 | `docs/CLAUDE_DESKTOP.md` | Table-stakes | LOW |
| DESK-02 | `tk-skills` plugin with pure-markdown skills | Table-stakes | MEDIUM |
| DESK-03 | Desktop context detection in `install.sh` | Table-stakes | MEDIUM |
| DESK-04 | Skill audit for Desktop safety | Table-stakes | MEDIUM |

---

## MVP Definition

### Phase 24 Launch Criteria

- [ ] TUI-01..09 all working (pure bash, no external deps, BSD + Linux compat)
- [ ] DET-01..05 unified in `scripts/lib/detect.sh`
- [ ] `scripts/install.sh` replaces the 5-command first-run flow
- [ ] Old `init-claude.sh` URL remains valid (trampoline to `install.sh` or preserved as-is)
- [ ] `--no-bootstrap`, `--no-banner`, `--yes`, `--dry-run` flags documented
- [ ] `scripts/tests/test-tui-installer.sh` hermetic test covering non-TTY fallback + `--yes` path
- [ ] CI test covers `TK_NO_BOOTSTRAP=1 bash install.sh --yes` (zero-interaction path)
- [ ] `make check` passes

### Phase 25 Launch Criteria

- [ ] DESK-04 complete (every TK skill reviewed for Desktop safety, unsafe ones annotated)
- [ ] DESK-02 complete (`tk-skills` plugin with only Desktop-safe skills)
- [ ] MKT-01..08 complete (`marketplace.json` verified against live spec)
- [ ] `/plugin marketplace add sergei-aronsen/claude-code-toolkit` works and installs `tk-skills`
- [ ] DESK-01 complete (`docs/CLAUDE_DESKTOP.md` with accurate compatibility table)
- [ ] DESK-03 complete (Desktop-only users routed from `install.sh` to docs)
- [ ] `CHANGELOG.md [4.5.0]` covers both phases
- [ ] `manifest.json` bumped to `4.5.0` with new `files.plugins[]` section

### Defer (Post-v4.5)

- `--preset minimal|full|dev` flag (MEDIUM complexity, low demand signal)
- `[update available]` version display in TUI (MEDIUM, requires version detection for all 6 components)
- `tk-commands` and `tk-framework-rules` marketplace sub-plugins (Code-only; Desktop-first is the priority)
- Per-component dependency hints in TUI (MEDIUM, soft UX enhancement)
- `allowCrossMarketplaceDependenciesOn: ["claude-plugins-official"]` (only needed if TK skills formally depend on SP)

---

## Comparable Tool Analysis

| Pattern | Reference | TK Approach |
|---------|-----------|-------------|
| TUI checkbox menu in pure bash | `blurayne/f63c5a8521c0eeab8e9afd8baa45c65e` gist — unicode `▣`/`□` checkboxes, `read -s -n1` key capture, `stty raw -echo` during menu, ANSI cursor control | Same approach adapted for Bash 3.2 compat: avoid `$'...'` quoting, avoid `read -N`, use `\033` escape forms |
| Default / Customize / Cancel flow | rustup — "1) Proceed with standard installation 2) Customize installation 3) Cancel installation" | TUI-04 confirmation step mirrors this but with checkboxes already customized in step 1 |
| No-TTY fallback to prompts | Existing `bootstrap.sh` in this codebase — `read < /dev/tty 2>/dev/null`, fail-closed `N` on EOF | TUI-09 reuses this pattern; TUI wrapper detects `[ -t 0 ]` and delegates to bootstrap.sh |
| Installed state labels | chezmoi `diff` output — `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` — already used in TK via `dro_*` | TUI menu labels mirror dro labels: `[installed]` = `[~ UPDATE]` in dry-run; clearer wording for interactive context |
| Marketplace JSON structure | `anthropics/claude-plugins-official` (2076 lines, 100+ plugins) — `name`, `source`, `category`, `author`, `version`, `tags` | TK marketplace.json with 3 sub-plugins, `git-subdir` sources pointing within same repo |
| Three-plugin split for runtime compat | No direct precedent found — this is novel in Claude ecosystem | `tk-skills` (Desktop-safe), `tk-commands` (Code only), `tk-framework-rules` (Code only) |
| Honest capability gap communication | Warp docs: macOS-only integrations documented as separate table with clear "macOS only" labels | `docs/CLAUDE_DESKTOP.md` table: "Works" / "Code only" / "Not supported" per component type |

---

## Key Risk Flags for Roadmap

1. **Bash 3.2 + BSD compat for arrow key TUI:** The main technical risk for Phase 24.
   `blurayne` gist requires Bash 4+. TK must work on macOS system bash (3.2). Arrow key escape
   sequences need `read -s -n1` + `case "$key" in $'\033'[A)` — but `$'...'` ANSI-C quoting
   requires bash 3.2+. The real risk is `read -N 1` (reads exactly 1 char, not line) which is
   bash 4+ only. Must use `read -n1` instead. **Needs explicit bash 3.2 compat test in Phase 24.**

2. **Marketplace schema evolving:** Official schema URL `https://anthropic.com/claude-code/marketplace.schema.json`
   does not exist (confirmed by search). Schema is inferred from official documentation examples.
   Phase 25 must verify `marketplace.json` against the live CLI at planning time, not just docs.

3. **Desktop plugin management CLI-only:** `/plugin marketplace add ./local-dir` does NOT work
   in Desktop app (confirmed GitHub issue #52147, Anthropic support 2026-04-22). Desktop users can
   ONLY install from a published marketplace. This makes Phase 25 a prerequisite for Desktop reach —
   there is no workaround that doesn't require the marketplace to be published first.

4. **Skill audit scope is unknown until done:** The number of TK skills that reference shell
   constructs, environment variables, or tool calls in their body is not yet counted. If most skills
   are Code-only, `tk-skills` Desktop value proposition weakens significantly. DESK-04 must happen
   early in Phase 25 to determine scope.

---

## Sources

- Official Anthropic marketplace docs: `code.claude.com/docs/en/plugin-marketplaces` (HIGH — fetched 2026-04-29)
- Official Anthropic plugin docs: `code.claude.com/docs/en/plugins` + `code.claude.com/docs/en/plugins-reference` (HIGH — fetched 2026-04-29)
- `anthropics/claude-plugins-official` marketplace.json: `github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json` (HIGH — official Anthropic repo)
- `obra/superpowers` marketplace.json: `github.com/obra/superpowers/blob/main/.claude-plugin/marketplace.json` (HIGH — reference implementation)
- `jnuyens/gsd-plugin` plugin structure: `github.com/jnuyens/gsd-plugin` (MEDIUM — third-party GSD plugin packaging)
- Pure-bash TUI implementation: `gist.github.com/blurayne/f63c5a8521c0eeab8e9afd8baa45c65e` (MEDIUM — requires Bash 4+, not directly usable but authoritative pattern)
- `bash-tui-toolkit`: `github.com/timo-reymann/bash-tui-toolkit` (MEDIUM — useful but Go-based or requires Bash 4+)
- Desktop plugin parity issue: `github.com/anthropics/claude-code/issues/52147` + Anthropic support statement 2026-04-22 (MEDIUM — GitHub issue)
- rustup installer UX: `github.com/rust-lang/rustup/issues/3429` + rustup.rs (MEDIUM — UX pattern reference)
- Existing TK codebase: `scripts/lib/bootstrap.sh`, `scripts/lib/optional-plugins.sh`, `scripts/init-claude.sh`, `docs/INSTALL.md` (HIGH — first-party)

---

*Feature research for: v4.5 Unified TUI Installer + Claude Code Plugin Marketplace*
*Researched: 2026-04-29*
