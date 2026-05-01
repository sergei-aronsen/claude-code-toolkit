# Requirements: claude-code-toolkit — Milestone v4.9 (Integrations Catalog)

**Defined:** 2026-05-02
**Core Value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.

## Milestone v4.9 Requirements

### Catalog Schema (CAT)

- [ ] **CAT-01**: `scripts/lib/integrations-catalog.json` (renamed from `mcp-catalog.json`) supports per-entry `components: { mcp?, cli? }` blocks where each component is independently optional. `mcp-catalog.json` removed; `scripts/lib/mcp.sh` reads the new path.
- [ ] **CAT-02**: Each MCP block carries `install_args[]`, `env_var_keys[]`, `requires_oauth: bool`, optional `description`. Each CLI block carries `detect_cmd: string`, `install: { darwin: string, linux: string }`, optional `post_install_hint: string`. Schema validated by a new `scripts/validate-integrations-catalog.py` invoked from `make check`.
- [ ] **CAT-03**: Each entry carries `category: string` (one of: `docs-research`, `backend`, `payments`, `email`, `workspace`, `project-management`, `communication`, `design`, `dev-tools`, `monitoring`) and optional `unofficial: true` flag. Validator rejects unknown categories.
- [ ] **CAT-04**: Backward-compat: `--mcps` CLI flag in `scripts/install.sh` continues to function as alias for `--integrations`. Deprecation note printed to stderr; exit behavior unchanged.

### CLI Installer Library (CLI)

- [x] **CLI-01**: `scripts/lib/cli-installer.sh` exposes `cli_detect <name>` (returns 0 if `command -v` succeeds, 1 otherwise) and `cli_install <name> <darwin_cmd> <linux_cmd>` (dispatches by `uname`, returns rc of underlying installer).
- [x] **CLI-02**: `cli_install` fails fast on Windows / unsupported `uname` with explicit error to stderr; never auto-elevates with `sudo`. If `brew` is absent on macOS, prints fallback instruction and returns non-zero (skipped, not aborted at top level).
- [x] **CLI-03**: `cli_install` uses continue-on-error semantics in the dispatch loop (mirroring Phase 25 D-08). Per-CLI stderr captured to `mktemp` for diagnostics; aggregate summary printed at end with `✓ installed` / `⊘ already present` / `✗ failed: <reason>` per row.
- [x] **CLI-04**: Post-install hints printed to stderr verbatim from catalog `cli.post_install_hint`. Toolkit never executes `<tool> login` automatically — users run it themselves.

### TUI Redesign (TUI)

- [ ] **TUI-01**: `scripts/install.sh --integrations` page groups rows by `category` with category headers (e.g., `── Backend ──`); category order matches the canonical 10-list in CAT-03; rows within a category are alphabetical.
- [ ] **TUI-02**: Each row displays per-component status: MCP column (`✓` / `✗` / `⊘ already`) detected via `claude mcp list`; CLI column (`✓` / `✗` / `⊘ already`) detected via `command -v`. Re-detected on every TUI launch — no cache file.
- [ ] **TUI-03**: Entries with `unofficial: true` render with a yellow `!` glyph next to the name and require a per-row `[y/N]` confirm prompt before install (`< /dev/tty`, fail-closed `N`). Reuse Phase 18 UN-03 prompt pattern.
- [ ] **TUI-04**: New global flags: `--mcp-only` installs only MCP components from selected rows; `--cli-only` installs only CLI components; default (no flag) installs both when both available. Mutually exclusive — using both errors out.
- [ ] **TUI-05**: Install summary at end prints per-entry, per-component status table (entry × {MCP, CLI} matrix). Mirrors Phase 25 D-28 summary contract.

### New Integrations (INT)

- [ ] **INT-01**: `supabase` entry — MCP (`@supabase/mcp-server-supabase`) + CLI (`brew install supabase/tap/supabase` darwin, official shell installer linux) + post-install hint `supabase login`. Category: `backend`.
- [ ] **INT-02**: `cloudflare` entry — MCP (`@cloudflare/mcp-server-cloudflare`) + CLI `wrangler` (`npm i -g wrangler` darwin+linux) + post-install hint `wrangler login`. Category: `backend`.
- [ ] **INT-03**: `stripe` entry — MCP (`@stripe/mcp-server-stripe`) + CLI (`brew install stripe/stripe-cli/stripe` darwin, apt-deb method linux) + post-install hint `stripe login`. Category: `payments`.
- [ ] **INT-04**: `aws-cost-explorer` entry — MCP only (`@awslabs/mcp-server-cost-explorer` or current name). Category: `backend`. CLI shared with INT-05.
- [ ] **INT-05**: `aws-cloudwatch-logs` entry — MCP (`@awslabs/mcp-server-cloudwatch-logs`) + shared `aws` CLI (`brew install awscli` darwin, official bundled installer linux) + post-install hint `aws configure`. Category: `backend`.
- [ ] **INT-06**: `notebooklm` entry — MCP + CLI (`nlm` via `pipx install nlm` or community recipe) + post-install hint `nlm login`. `unofficial: true`. Category: `docs-research`.
- [ ] **INT-07**: `youtrack` entry — MCP only (`@jetbrains/mcp-server-youtrack`). Auth via API token env var. Category: `project-management`.
- [ ] **INT-08**: `linear` entry — MCP only (`@linear/mcp-server`). Auth via API key env var. Category: `project-management`.
- [ ] **INT-09**: `jira` entry — MCP only (Atlassian official). Auth via API token + workspace URL. Category: `project-management`.
- [ ] **INT-10**: `figma` entry — MCP only (Figma Dev Mode MCP). Auth via personal access token. Category: `design`.
- [ ] **INT-11**: `slack` entry — MCP only (Slack official). Auth via bot token + workspace ID. Category: `communication`.
- [ ] **INT-12**: `telegram` entry — MCP only (community implementation, pinned by SHA). `unofficial: true`. Auth via bot token. Category: `communication`.

### Drops (DROP)

- [ ] **DROP-01**: `sequential-thinking` entry removed from catalog. Native Claude extended thinking covers the use case. CHANGELOG notes the removal under v4.9 with migration note (no action needed; users keep existing install if any).

### Existing Re-categorization (EXIST)

- [ ] **EXIST-01**: All 8 surviving existing entries (context7, firecrawl, magic, notion, openrouter, playwright, resend, sentry) tagged with `category` per the canonical 10-list. Optional CLI block added to `firecrawl`, `playwright`, `sentry` (their CLIs exist and add value); other 5 stay MCP-only.

### Documentation (DOCS)

- [ ] **DOCS-01**: New `docs/INTEGRATIONS.md` documents the catalog: 19-entry table, category groupings, install flow, `unofficial` semantics, `--mcp-only` / `--cli-only` flags, troubleshooting (missing `brew`, OAuth setup links).
- [ ] **DOCS-02**: New `docs/INTEGRATIONS.md` "Global vs per-project" section explicitly states: toolkit installs MCPs + CLIs **globally** on the dev machine; SDKs (`stripe-node`, `@supabase/supabase-js`, etc.) are **per-project** and never touched by toolkit.
- [ ] **DOCS-03**: `docs/INSTALL.md` `## Installer Flags` table updated with `--integrations`, `--mcp-only`, `--cli-only` rows and `--mcps` deprecation note.
- [ ] **DOCS-04**: `README.md` "Killer Features" section adds Integrations Catalog bullet (1 line).
- [ ] **DOCS-05**: `CHANGELOG.md` `[4.9.0]` consolidated single block per v4.4/v4.6/v4.8 convention. Sections: Added (CAT, CLI, TUI, INT-01..12), Changed (EXIST-01, CAT-04 alias), Removed (DROP-01).

### Tests (TEST)

- [ ] **TEST-01**: `scripts/tests/test-integrations-catalog.sh` validates `integrations-catalog.json` against the schema (19 entries, all categories valid, all `cli` blocks have `detect_cmd` and OS keys, all MCP blocks have `install_args`). Hermetic — does not invoke `claude` or `brew`. ≥10 assertions.
- [ ] **TEST-02**: `scripts/tests/test-cli-installer.sh` exercises `cli_detect` + `cli_install` with mocked `command -v` and `brew`/`apt` shims. Covers: success, already-present, brew-absent fallback, Windows-rejection, post-install hint emission. ≥8 assertions.
- [ ] **TEST-03**: `scripts/tests/test-integrations-tui.sh` extends existing `test-mcp-selector.sh` (PASS=21 baseline) with new assertions: category headers render, `unofficial` confirm prompt fires, `--mcp-only` skips CLI install, `--cli-only` skips MCP install, summary table shows per-component status. ≥15 new assertions on top of baseline.
- [ ] **TEST-04**: All 3 new test suites wired into `Makefile` (Tests 31, 32, 33) and `.github/workflows/quality.yml` step `Tests 21-33`.

### Distribution (DIST)

- [ ] **DIST-01**: `manifest.json` bumped 4.8.0 → 4.9.0. New `scripts/lib/cli-installer.sh` registered under `files.libs[]`. `scripts/lib/integrations-catalog.json` registered (replaces `mcp-catalog.json` entry). `scripts/validate-integrations-catalog.py` registered under `files.scripts[]`.
- [ ] **DIST-02**: `init-claude.sh --version` and `init-local.sh --version` derive from manifest at runtime — version-align gate stays a 2-file (manifest + CHANGELOG) atomic bump per v4.3 D-22 contract.

## Future Requirements

Deferred to future release. Tracked but not in v4.9 roadmap.

### Catalog (CAT-FUT)

- **CAT-FUT-01**: Catalog auto-sync with upstream MCP registry (Anthropic / community) — drop manual JSON maintenance. Blocked on no upstream registry yet.
- **CAT-FUT-02**: User-extensible catalog at `~/.claude/integrations-catalog.local.json` merged at TUI load. Lower priority — solo-dev rarely adds custom entries.

### TUI (TUI-FUT)

- **TUI-FUT-04**: `--preset minimal|full|dev` to install pre-defined bundles (e.g., `dev` = sentry + playwright + context7). Revisit after 19-entry catalog in production.
- **TUI-FUT-05**: Search/filter input in TUI (type to narrow rows). Only useful at >30 entries.

### CLI Installer (CLI-FUT)

- **CLI-FUT-01**: Windows support via WSL detection or chocolatey. Out of scope per POSIX invariant; revisit if Windows demand surfaces.
- **CLI-FUT-02**: Version pinning per CLI (`cli.version_pin: "x.y.z"`). KISS — vendors handle their own update channels.

### Integrations (INT-FUT)

- **INT-FUT-01**: Mailgun MCP (no official, no critical use case for chat-time). Skip unless community produces one.
- **INT-FUT-02**: Cursor `.cursorrules` / Aider `CONVENTIONS.md` bridges (BRIDGE-FUT-03/04 carry-over from v4.8).
- **INT-FUT-03**: Discord MCP. Niche; revisit if requested.
- **INT-FUT-04**: GitHub Issues MCP (covered by `gh` CLI today; revisit if MCP adds tool-call value).

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Auto-execute `wrangler login` / `supabase login` / `stripe login` | Security boundary — toolkit never opens a browser or runs OAuth flows on user's behalf. Hint-only contract. |
| Install per-project SDKs (`@supabase/supabase-js`, `stripe-node`, etc.) | Out-of-band — SDKs belong in `package.json`/`composer.json`, not in `~/.claude/`. Documented in DOCS-02. |
| Full AWS Labs MCP set (Bedrock, ECS, CDK, …) | Curated catalog; 2 narrow MCPs (Cost Explorer + CloudWatch Logs) are the tested set. Users wanting more install manually. |
| Mailgun MCP | No critical chat-time use case + no major official MCP. SDK in app code is the right shape. |
| Discord MCP | Niche; revisit on demand. |
| Custom catalog editor UI | KISS — JSON file is editable; validator catches mistakes. |
| Per-CLI auth wizard with browser handoff | Goes beyond toolkit's "config + hints" boundary. Vendors own their auth flow. |
| Auto-update for installed CLIs | `brew upgrade` / `npm update -g` are user-driven; toolkit installs once and gets out of the way. |
| Pinning MCP versions to SHA in catalog | Maintenance burden; rely on `npx -y` latest pull semantics. Revisit if drift causes incidents. |
| Integration with `superpowers` plugin auto-discovery | superpowers manages its own skill loading; toolkit MCPs/CLIs are independent layer. |
| Telemetry / usage reporting | Privacy-first toolkit posture; no opt-out telemetry. |

## Traceability

Mapped by `gsd-roadmapper` 2026-05-02. All 36 v4.9 REQ-IDs assigned to exactly one of Phases 32-35.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CAT-01 | Phase 32 | Pending |
| CAT-02 | Phase 32 | Pending |
| CAT-03 | Phase 32 | Pending |
| CAT-04 | Phase 32 | Pending |
| CLI-01 | Phase 32 | Complete |
| CLI-02 | Phase 32 | Complete |
| CLI-03 | Phase 32 | Complete |
| CLI-04 | Phase 32 | Complete |
| TUI-01 | Phase 34 | Pending |
| TUI-02 | Phase 34 | Pending |
| TUI-03 | Phase 34 | Pending |
| TUI-04 | Phase 34 | Pending |
| TUI-05 | Phase 34 | Pending |
| INT-01 | Phase 33 | Pending |
| INT-02 | Phase 33 | Pending |
| INT-03 | Phase 33 | Pending |
| INT-04 | Phase 33 | Pending |
| INT-05 | Phase 33 | Pending |
| INT-06 | Phase 33 | Pending |
| INT-07 | Phase 33 | Pending |
| INT-08 | Phase 33 | Pending |
| INT-09 | Phase 33 | Pending |
| INT-10 | Phase 33 | Pending |
| INT-11 | Phase 33 | Pending |
| INT-12 | Phase 33 | Pending |
| DROP-01 | Phase 33 | Pending |
| EXIST-01 | Phase 33 | Pending |
| DOCS-01 | Phase 35 | Pending |
| DOCS-02 | Phase 35 | Pending |
| DOCS-03 | Phase 35 | Pending |
| DOCS-04 | Phase 35 | Pending |
| DOCS-05 | Phase 35 | Pending |
| TEST-01 | Phase 35 | Pending |
| TEST-02 | Phase 35 | Pending |
| TEST-03 | Phase 35 | Pending |
| TEST-04 | Phase 35 | Pending |
| DIST-01 | Phase 35 | Pending |
| DIST-02 | Phase 35 | Pending |

**Coverage:**

- v4.9 requirements: 36 total
- Mapped to phases: 36 ✓
- Unmapped: 0
- Phase distribution: Phase 32 (8), Phase 33 (14), Phase 34 (5), Phase 35 (11)

---
*Requirements defined: 2026-05-02*
*Last updated: 2026-05-02 — Traceability mapped by `gsd-roadmapper`; 36/36 REQ-IDs assigned to Phases 32-35.*
