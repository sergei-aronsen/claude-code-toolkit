---
gsd_state_version: 1.0
milestone: v4.9
milestone_name: Integrations Catalog
current_plan: 4
status: executing
last_updated: "2026-05-02T08:00:00.000Z"
last_activity: 2026-05-02 — Phase 33 complete (Plans 33-01..04 merged sequentially on main); catalog populated to final 20-entry shape
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 14
  completed_plans: 7
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** Phase 33 complete — ready for Phase 34 (TUI Redesign)

## Current Position

Phase: 33 (catalog-population-11-new-entries-drop-recategorize) — COMPLETE
Plans done (Phase 32): 32-01 ✓, 32-02 ✓, 32-03 ✓
Plans done (Phase 33): 33-01 ✓ (INT-01/02/04/05 backend), 33-02 ✓ (INT-03/07-10 payments+pm+design), 33-03 ✓ (INT-06/11/12 comm+research), 33-04 ✓ (DROP-01 + EXIST-01)
Status: Phase 33 closed — catalog at final 20-entry / 8-CLI-block / 10-category shape; validator green, both baselines preserved
Last activity: 2026-05-02 — Phase 33 sequential execution on main (4 commits: 08455ee, f29bc80, a2d3326, 9481ee0)
Next: Phase 34 — TUI Redesign (TUI-01..05)

## Plan Count Estimate

Total estimated plans across v4.9: **14 plans** distributed across 4 phases.

| Phase | Plans | Rationale |
|-------|-------|-----------|
| 32. Foundation — Schema Migration + CLI Installer Library | 3 | (a) Schema rename + validator (`integrations-catalog.json` + `validate-integrations-catalog.py`, `mcp.sh` path swap, BACKCOMPAT alias `--mcps`); (b) `cli-installer.sh` library (`cli_detect`/`cli_install` + dispatch by `uname` + brew-absent fallback + continue-on-error + post-install hint stderr emit); (c) Hermetic smoke covering CAT-01..04 + CLI-01..04 surface contracts. Mirrors v4.8 Phase 28 (3-plan foundation) shape. |
| 33. Catalog Population — 11 New + Drop + Re-categorize | 4 | (a) Backend cluster (supabase, cloudflare, aws-cost-explorer, aws-cloudwatch-logs sharing `aws` CLI — INT-01, INT-02, INT-04, INT-05); (b) Payments + Project-Mgmt + Design (stripe + youtrack + linear + jira + figma — INT-03, INT-07..10); (c) Communication + Research with `unofficial` flags (slack, telegram, notebooklm — INT-06, INT-11, INT-12); (d) Drop `sequential-thinking` + tag 8 existing entries with category + add CLI blocks to firecrawl/playwright/sentry (DROP-01 + EXIST-01). 4 plans isolate change risk and let each cluster ship + test independently before TUI work begins. |
| 34. TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags | 3 | (a) Category-grouped rendering + per-component status detection (TUI-01, TUI-02 — extends `mcp.sh` rendering layer); (b) `unofficial` `[y/N]` confirm gate + `--mcp-only`/`--cli-only` flags with mutex (TUI-03, TUI-04 — reuses v4.3 UN-03 prompt + v4.8 mutex pattern); (c) Per-component summary table at dispatch close (TUI-05 — mirrors Phase 25 D-28 contract). Mirrors v4.8 Phase 30 (3-plan UX) shape. |
| 35. Distribution + Tests + Docs | 4 | (a) Manifest + version-align (DIST-01, DIST-02 — manifest 4.9.0 bump + 3 plugin.json sync + version-align gate); (b) Three hermetic test suites (TEST-01 catalog schema, TEST-02 cli-installer, TEST-03 integrations-tui) + Makefile/CI wiring (TEST-04); (c) `docs/INTEGRATIONS.md` NEW + Global-vs-per-project boundary (DOCS-01, DOCS-02); (d) INSTALL.md flag rows + README Killer Features bullet + CHANGELOG `[4.9.0]` consolidated (DOCS-03, DOCS-04, DOCS-05). Mirrors v4.8 Phase 31 close-pattern (3+ plans) — split to 4 because v4.9 ships 3 test suites vs v4.8's 1 aggregator. |

**Total: 14 plans.** Range matches "standard" granularity (5-8 phases recommended; 4 phases here is justified by tight foundation→population→UX→close dependency chain — same shape as v4.8 Multi-CLI Bridge which shipped 12 plans across 4 phases).

## Accumulated Context

### Decisions (carry-over relevant for v4.9)

Full log in PROJECT.md Key Decisions table. Recent highlights still relevant:

- **Phase 25 (v4.6) MCP catalog foundation:** `scripts/lib/mcp-catalog.json` + `scripts/lib/mcp.sh` + 9-MCP TUI is the foundation. v4.9 extends, does not rewrite.
- **Phase 24 (v4.6) lib foundation:** `scripts/lib/{tui.sh, detect2.sh, dispatch.sh}` is the integration point — new categories + status detection extend tui.sh, not new machinery.
- **BACKCOMPAT-01 (v4.6):** `--mcps` flag must continue to work as alias for `--integrations` after rename. URL byte-identicality preserved.
- **v4.4 LIB-01 D-07 jq path** (`.files | to_entries[] | .value[] | .path`) auto-discovers any new `files.libs[]` entry — `cli-installer.sh` adds zero new code to `update-claude.sh` if registered there.
- **v4.3 UN-03 `[y/N/d]` prompt contract:** read from `< /dev/tty`, fail-closed `N` on no-TTY. Reuse for `unofficial` MCP confirmation prompts (notebooklm, telegram).
- **Phase 25 D-08 continue-on-error pattern:** per-MCP install failure does not abort the loop; reuse for CLI installs in v4.9.
- **v4.8 Phase 30 mutex pattern:** `--bridges` / `--no-bridges` mutex contract. Reuse for `--mcp-only` / `--cli-only` mutex in TUI-04.
- **Bash 3.2 compatibility:** no `declare -A`, no `read -N`, no float `-t`, no `declare -n`. Inherited.

### Key v4.9 Constraints

- **Catalog rename, backward compat:** `mcp-catalog.json` → `integrations-catalog.json`; `mcp.sh` library functions keep their names (`mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`) — internal schema upgrade only. `--mcps` CLI flag stays as alias for `--integrations`.
- **Cross-platform CLI install:** `darwin` → `brew` preferred, fall-back to vendor's official shell installer (e.g. AWS CLI bundled installer). `linux` → `apt` / `snap` / shell installer. Windows out of scope (toolkit is POSIX-only — same constraint as v4.0).
- **Privilege detection:** if `brew` not present on macOS or `sudo` required, print fallback instruction and skip — never auto-elevate.
- **`unofficial` badge:** yellow `!` glyph in TUI; explicit confirmation prompt before install (Y/n with default N for safety).
- **Post-install hint surface:** stderr only, never auto-execute browser-based logins (`wrangler login`, `supabase login`, etc.).
- **Status detect:** `claude mcp list` for MCPs, `command -v <name>` for CLIs. Re-run on every TUI launch — no cache file.
- **Category grouping:** TUI groups visually but install array is flat (no nested logic in dispatch loop).
- **AWS scope-cap:** add 2 narrow MCPs (Cost Explorer + CloudWatch Logs) only. Full AWS Labs MCP set is out of catalog scope — too broad.
- **`unofficial` entries:** notebooklm + telegram. Hidden by default? Or visible with badge? **Decision: visible with badge + confirm prompt** — discoverability matters.

### Carry-overs from v4.8 (still deferred, not v4.9 scope)

- 8 HUMAN-UAT items from v4.6 (live PTY + external CLI) — run when convenient; do not block v4.9.
- 5 advisory code-review WR findings in Phase 24.
- `--no-council` flag for `/audit` — keep deferred.
- Sentinel writer instrumentation in `setup-security.sh` / `init-claude.sh` (Phase 19 D-01).
- Selective uninstall (`--only commands/`, `--except council/`).
- Branding substitution layer (BRIDGE-FUT-01).
- Cursor `.cursorrules` / Aider `CONVENTIONS.md` bridges (BRIDGE-FUT-03/04).
- Council Rework parallel track items.
- Permanently locked out: Docker-per-cell isolation, agent-cut release tags.

### Roadmap Evolution

- 2026-04-21: v4.0 shipped
- 2026-04-25: v4.1 shipped
- 2026-04-26: v4.2 + v4.3 shipped
- 2026-04-27: v4.4 shipped
- 2026-04-29: v4.6 + v4.7 + v4.8 all shipped
- 2026-05-02: v4.9 milestone started — Integrations Catalog scope captured in PROJECT.md
- 2026-05-02: v4.9 ROADMAP.md created — 4 phases (32-35), 14 plans, 36/36 REQ-IDs mapped

### Pending Todos

- Run `/gsd-plan-phase 32` to decompose Phase 32 (Foundation — Schema Migration + CLI Installer Library) into 3 atomic plans.

### Blockers/Concerns

None. v4.6 Phase 25 foundation is solid — extension path is clear. All 36 v4.9 REQ-IDs mapped to exactly one phase, no orphans.

### Quick Tasks Completed (recent)

| # | Description | Date | Commit |
|---|-------------|------|--------|
| 260501-lrq | Fix critical install bugs + Council in TUI dispatch + TUI render upgrade + 2 hermetic test suites | 2026-05-01 | 81ba552 |
| 260430-go5 | PR #15 — 18 audit findings closed + 1 Gemini dead-code | 2026-04-30 | 21 commits |

## Deferred Items

Carry-overs available for next milestone scoping (unchanged from v4.8 close):

| Category | Item | Status |
|----------|------|--------|
| Locked out | Docker-per-cell isolation | Permanently out (POSIX invariant) |
| Locked out | Auto-cut `git tag` from phase execution | Permanently out (CLAUDE.md "never push main") |
| Future | `--preset minimal\|full\|dev` | TUI-FUT-04 — revisit after 19-entry catalog in production |
| Future | TUI search/filter input | TUI-FUT-05 — only useful at >30 entries |
| Future | Catalog auto-sync with upstream MCP registry | CAT-FUT-01 — blocked on no upstream registry yet |
| Future | User-extensible local catalog | CAT-FUT-02 — solo-dev rarely adds custom entries |
| Future | Windows support via WSL/chocolatey | CLI-FUT-01 — out of scope per POSIX invariant |
| Future | CLI version pinning | CLI-FUT-02 — KISS, vendors handle update channels |
| Future | Mailgun MCP, Discord MCP, GitHub Issues MCP | INT-FUT-01/03/04 |
| Future | Cursor `.cursorrules` / Aider `CONVENTIONS.md` | BRIDGE-FUT-03/04 (carry-over from v4.8) |
| Deferred | Branding substitution layer for bridge files | BRIDGE-FUT-01 |
| Deferred | Per-CLI tone overlay snippets | BRIDGE-FUT-02 |
| Deferred | `update-claude.sh --bridges-only` mode | BRIDGE-FUT-05 |
| Parallel track | Council Rework | concurrent session |

## Session Continuity

Last session: 2026-05-01T23:51:08.129Z
Started: v4.9 Integrations Catalog milestone
Resume file: None

**Next steps:**

1. ✅ Define REQUIREMENTS.md with REQ-IDs covering: catalog schema migration (CAT-*), CLI installer lib (CLI-*), TUI redesign with categories + status (TUI-*), 11 new entries (INT-*), drop sequential-thinking (DROP-*), docs (DOCS-*), tests (TEST-*).
2. ✅ Create ROADMAP.md with 4-phase structure (32-35), 14 plans estimated, 36/36 REQ-IDs mapped.
3. ▶ Run `/gsd-plan-phase 32` to begin executing the milestone.
