# Roadmap: claude-code-toolkit

## Milestones

- ✅ **v4.0 Complement Mode** — Phases 1–7 + 6.1 (shipped 2026-04-21). See `.planning/milestones/v4.0-ROADMAP.md`.
- ✅ **v4.1 Polish & Upstream** — Phases 8–12 (shipped 2026-04-25). See `.planning/milestones/v4.1-ROADMAP.md`.
- ✅ **v4.2 Audit System v2** — Phases 13–17 (shipped 2026-04-26). See `.planning/milestones/v4.2-ROADMAP.md`.
- ✅ **v4.3 Uninstall** — Phases 18–20 (shipped 2026-04-26). See `.planning/milestones/v4.3-ROADMAP.md`.
- ✅ **v4.4 Bootstrap & Polish** — Phases 21–23 (shipped 2026-04-27). See `.planning/milestones/v4.4-ROADMAP.md`.
- **v4.5 Install Flow UX & Desktop Reach** — Phases 24–27 (in progress).

## Phases

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

### v4.5 Install Flow UX & Desktop Reach

- [x] **Phase 24: Unified TUI Installer + Centralized Detection** — Single `scripts/install.sh` entry point with Bash 3.2 TUI checklist; shared libs (`tui.sh`, `detect2.sh`, `dispatch.sh`) reused by Phases 25–26 (completed 2026-04-29)
- [x] **Phase 25: MCP Selector** — Nine-entry MCP catalog with per-MCP install wizard, inline secret collection, and `mcp-config.env` secrets handling (completed 2026-04-29)
- [x] **Phase 26: Skills Selector** — 22-skill marketplace mirror with `is_skill_installed` detection and TUI-driven copy to `~/.claude/skills/` (completed 2026-04-29)
- [ ] **Phase 27: Marketplace Publishing + Claude Desktop Reach** — Plugin marketplace surface (`marketplace.json` + three sub-plugins), Desktop capability matrix, skill safety audit CI gate

## Phase Details

### Phase 24: Unified TUI Installer + Centralized Detection

**Goal**: A developer running `bash <(curl -sSL .../install.sh)` completes a guided first-run setup via a single TUI checklist instead of 5 separate curl-bash invocations

**Depends on**: Nothing (first phase of v4.5; builds on v4.4 foundation)

**Requirements**: TUI-01, TUI-02, TUI-03, TUI-04, TUI-05, TUI-06, TUI-07, DET-01, DET-02, DET-03, DET-04, DET-05, DISPATCH-01, DISPATCH-02, DISPATCH-03, BACKCOMPAT-01

**Phase outcome**: A user running `bash <(curl -sSL .../scripts/install.sh)` sees an arrow-navigable TUI checklist within 2 seconds, pre-checked for uninstalled components, and exits with a per-component status summary — while the existing `init-claude.sh` URL continues to work unchanged.

**Success Criteria** (what must be TRUE):

1. User running `bash <(curl -sSL .../scripts/install.sh)` sees a TUI checklist with arrow + space + enter navigation within 2 seconds on macOS Bash 3.2 and Linux Bash 4+
2. Already-installed components show `[installed ✓]` label and are pre-unchecked; uninstalled components are pre-checked; user can toggle any item before confirming
3. Pressing Ctrl-C mid-TUI-render restores the terminal to normal mode with no blind-typing side effects
4. Passing `--yes` flag (or piping stdin without a TTY) bypasses the menu and installs the default set non-interactively, enabling CI use
5. Existing `bash <(curl -sSL .../scripts/init-claude.sh)` URL invocations continue to work byte-identically with all v4.4 flags (`--no-bootstrap`, `--no-banner`, `TK_NO_BOOTSTRAP`, `NO_BANNER`) unchanged, and the 26-assertion `test-bootstrap.sh` stays green

**Plans**: 5 plans

- [ ] 24-01-PLAN.md — `lib/detect2.sh` centralized is_*_installed wrapper (Wave 1; DET-01..DET-05)
- [ ] 24-02-PLAN.md — `lib/tui.sh` Bash 3.2 TUI checklist + confirm prompt (Wave 1; TUI-01..TUI-06)
- [ ] 24-03-PLAN.md — `lib/dispatch.sh` six dispatchers + `--yes` flag wiring on setup-security.sh and install-statusline.sh (Wave 2; DISPATCH-01, DISPATCH-02)
- [ ] 24-04-PLAN.md — top-level `scripts/install.sh` orchestrator + `test-install-tui.sh` ≥15 assertions + Makefile/CI Test 31 (Wave 3; TUI-07, DISPATCH-03, BACKCOMPAT-01)
- [ ] 24-05-PLAN.md — `manifest.json` distribution wiring (3 libs + install.sh) + `docs/INSTALL.md` user-facing flag table (Wave 3, parallel with Plan 04; BACKCOMPAT-01, TUI-07)

**UI hint**: yes

### Phase 25: MCP Selector

**Goal**: A developer can browse and install curated MCP servers via a TUI catalog that handles secret collection and `claude mcp add` invocation without leaving the terminal

**Depends on**: Phase 24 (reuses `tui.sh`, `detect2.sh`, `dispatch.sh` libs from Phase 24)

**Requirements**: MCP-01, MCP-02, MCP-03, MCP-04, MCP-05, MCP-SEC-01, MCP-SEC-02

**Phase outcome**: Nine curated MCP servers are browsable via `scripts/install.sh --mcps`; selecting one opens a per-MCP wizard that prompts for API keys with hidden input, writes them to `~/.claude/mcp-config.env` (mode 0600), and runs `claude mcp add` — or reports "CLI unavailable" and degrades gracefully.

**Success Criteria** (what must be TRUE):

1. User running `scripts/install.sh --mcps` sees a TUI page listing nine MCPs with per-MCP detected/undetected status (using `claude mcp list` output when the CLI is present)
2. Selecting an MCP with required API keys opens an inline wizard that prompts for each secret with hidden input (`read -rs`), and the key is never echoed to the terminal or written to any log
3. After wizard completion, `claude mcp add <name> <flags>` is invoked with the collected values; user sees per-MCP `installed / skipped / failed` status in the post-install summary
4. `~/.claude/mcp-config.env` is created with mode 0600 (owner-only readable) and appends/overwrites individual keys with `[y/N]` confirmation on collision
5. When `claude` CLI is absent (Desktop-only or not yet installed), the MCP selector warns rather than errors and suggests the CLI install path

**Plans**: 4 plans

- [x] 25-01-mcp-catalog-and-loader-PLAN.md — `lib/mcp-catalog.json` (9-entry catalog) + `lib/mcp.sh` foundation: loader + `is_mcp_installed` three-state probe (Wave 1; MCP-01, MCP-02)
- [x] 25-02-wizard-and-secrets-PLAN.md — Per-MCP wizard with hidden input + `~/.claude/mcp-config.env` (0600) secrets persistence + collision prompt (Wave 2; MCP-04, MCP-SEC-01, MCP-SEC-02)
- [x] 25-03-install-sh-mcps-page-PLAN.md — `scripts/install.sh --mcps` flag wiring + TUI catalog page + `mcp_status_array` helper (Wave 3; MCP-03)
- [x] 25-04-tests-manifest-and-docs-PLAN.md — Hermetic `test-mcp-selector.sh` (≥12 assertions) + manifest.json + Makefile Test 32 + CI + `docs/MCP-SETUP.md` + `docs/INSTALL.md` --mcps subsection (Wave 4; MCP-05, MCP-SEC-02 doc, MCP-01 manifest)

### Phase 26: Skills Selector

**Goal**: A developer can browse and install from a curated 22-skill marketplace mirror via the TUI, with skills landing in `~/.claude/skills/<name>/` and becoming immediately loadable by Claude Code

**Depends on**: Phase 24 (reuses `tui.sh`, `detect2.sh`, `dispatch.sh` libs from Phase 24)

**Requirements**: SKILL-01, SKILL-02, SKILL-03, SKILL-04, SKILL-05

**Phase outcome**: Twenty-two curated skills are browsable via `scripts/install.sh --skills`; selected skills are copied to `~/.claude/skills/<name>/`; `manifest.json` registers the marketplace content under `files.skills_marketplace[]` so `update-claude.sh` keeps them current.

**Success Criteria** (what must be TRUE):

1. User running `scripts/install.sh --skills` sees a TUI page listing 22 skills with per-skill installed/uninstalled status (via `[ -d ~/.claude/skills/<name>/ ]` probe)
2. Skills installed via TUI appear under `~/.claude/skills/<name>/` and are loadable by Claude Code immediately after install (no restart required)
3. Re-running the install without `--force` skips already-installed skills; re-running with `--force` overwrites them — consistent with the component install behavior from Phase 24
4. `manifest.json` registers `templates/skills-marketplace/` content so `update-claude.sh` ships skill updates to existing TK installs on next run
5. Every mirrored skill has its upstream license file preserved in the mirror directory, and `docs/SKILLS-MIRROR.md` records the upstream URL and mirror date for each skill

**Plans**: 4 plans

- [x] 26-01-skills-lib-and-sync-script-PLAN.md — `scripts/lib/skills.sh` (catalog + is_skill_installed + skills_install) + `scripts/sync-skills-mirror.sh` standalone maintainer tool (Wave 1; SKILL-03)
- [x] 26-02-mirror-content-snapshot-PLAN.md — Commit 22-skill snapshot under `templates/skills-marketplace/` + per-skill license preservation with SKILL-LICENSE.md fallback (Wave 1; SKILL-01, SKILL-02)
- [x] 26-03-install-sh-skills-page-PLAN.md — `scripts/install.sh --skills` routing branch with TUI page + cp-R install + --force overwrite + dry-run preview (Wave 2; SKILL-03)
- [x] 26-04-tests-manifest-and-docs-PLAN.md — Hermetic `test-install-skills.sh` (15 assertions) + `manifest.json` `files.skills_marketplace[]` (22) + Makefile Test 33 + `sync-skills-mirror` target + CI Tests 21-33 + `docs/SKILLS-MIRROR.md` + `docs/INSTALL.md` --skills subsection (Wave 3; SKILL-04, SKILL-05)

### Phase 27: Marketplace Publishing + Claude Desktop Reach

**Goal**: The toolkit is discoverable and installable as a Claude Code plugin marketplace entry, and Claude Desktop users understand exactly which capabilities they can access and how to install the skills sub-plugin

**Depends on**: Phase 24 (requires Phase 24 `install.sh` `--skills-only` routing for Desktop users); Phase 26 (requires skills marketplace mirror to be in place for `tk-skills` sub-plugin to have content)

**Requirements**: MKT-01, MKT-02, MKT-03, MKT-04, DESK-01, DESK-02, DESK-03, DESK-04

**Phase outcome**: `claude plugin marketplace add sergei-aronsen/claude-code-toolkit` resolves to a validated marketplace structure; `docs/CLAUDE_DESKTOP.md` gives an honest capability matrix; `scripts/validate-skills-desktop.sh` CI gate ensures the `tk-skills` sub-plugin only ships Desktop-safe skills.

**Success Criteria** (what must be TRUE):

1. `claude plugin marketplace add sergei-aronsen/claude-code-toolkit` resolves the `.claude-plugin/marketplace.json` and lists three sub-plugins (`tk-skills`, `tk-commands`, `tk-framework-rules`) with valid `plugin.json` schema in each
2. A user reading `docs/CLAUDE_DESKTOP.md` can determine in under one minute which toolkit capabilities are available in the Desktop Code tab, which are Code-only, and which are unavailable in the Desktop Chat tab
3. `make check` includes `make validate-marketplace` (gated behind `TK_HAS_CLAUDE_CLI=1`) and `make validate-skills-desktop`; the skills desktop audit fails the build if fewer than 4 skills pass the Desktop-safety gate
4. A Desktop-only user (no `claude` CLI on PATH) running `scripts/install.sh` is automatically routed to `--skills-only` mode and told where skills are placed (`~/.claude/plugins/tk-skills/`) with a one-line explanation of the limitation
5. README and `docs/INSTALL.md` document both install channels (curl-bash for Code users; marketplace for Desktop users) as equivalent for Claude Code, with the marketplace as the only path for Desktop

**Plans**: 4 plans

- [x] 27-01-marketplace-surface-PLAN.md — `.claude-plugin/marketplace.json` + 3 sub-plugin `plugin.json` + symlink trees (Wave 1; MKT-01, MKT-02)
- [x] 27-02-validators-and-make-wiring-PLAN.md — `validate-skills-desktop.sh` + `validate-marketplace.sh` + Makefile/CI wiring (Wave 2; MKT-03, DESK-02, DESK-04)
- [ ] 27-03-install-sh-desktop-routing-PLAN.md — `scripts/install.sh` --skills-only flag + Desktop auto-routing + S10 hermetic test (Wave 3; DESK-03)
- [ ] 27-04-docs-manifest-changelog-PLAN.md — `docs/CLAUDE_DESKTOP.md` + README/INSTALL.md marketplace sections + manifest 4.5.0 + CHANGELOG [4.5.0] (Wave 4; DESK-01, MKT-04)

**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 24. Unified TUI Installer + Centralized Detection | 5/5 | Complete    | 2026-04-29 |
| 25. MCP Selector | 4/4 | Complete    | 2026-04-29 |
| 26. Skills Selector | 4/4 | Complete    | 2026-04-29 |
| 27. Marketplace Publishing + Claude Desktop Reach | 2/4 | In Progress|  |

---

## Historical Progress

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v4.0 Complement Mode | 1–7 + 6.1 | 29/29 | ✅ Shipped | 2026-04-21 |
| v4.1 Polish & Upstream | 8–12 | 13/13 | ✅ Shipped | 2026-04-25 |
| v4.2 Audit System v2 | 13–17 | 22/22 | ✅ Shipped | 2026-04-26 |
| v4.3 Uninstall | 18–20 | 10/10 | ✅ Shipped | 2026-04-26 |
| v4.4 Bootstrap & Polish | 21–23 | 8/8 | ✅ Shipped | 2026-04-27 |
