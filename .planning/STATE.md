---
gsd_state_version: 1.0
milestone: v4.9
milestone_name: Integrations Catalog
status: defining_requirements
stopped_at: v4.9 milestone started — PROJECT.md updated, REQUIREMENTS.md next
last_updated: "2026-05-02T00:00:00.000Z"
last_activity: 2026-05-02
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** v4.9 Integrations Catalog — unify MCPs + companion CLIs into one TUI page, expand catalog from 9 → 19 entries, drop `sequential-thinking`.

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-02 — Milestone v4.9 started

## Plan Count Estimate

_To be filled by gsd-roadmapper after REQUIREMENTS.md is approved._

## Accumulated Context

### Decisions (carry-over relevant for v4.9)

Full log in PROJECT.md Key Decisions table. Recent highlights still relevant:

- **Phase 25 (v4.6) MCP catalog foundation:** `scripts/lib/mcp-catalog.json` + `scripts/lib/mcp.sh` + 9-MCP TUI is the foundation. v4.9 extends, does not rewrite.
- **Phase 24 (v4.6) lib foundation:** `scripts/lib/{tui.sh, detect2.sh, dispatch.sh}` is the integration point — new categories + status detection extend tui.sh, not new machinery.
- **BACKCOMPAT-01 (v4.6):** `--mcps` flag must continue to work as alias for `--integrations` after rename. URL byte-identicality preserved.
- **v4.4 LIB-01 D-07 jq path** (`.files | to_entries[] | .value[] | .path`) auto-discovers any new `files.libs[]` entry — `cli-installer.sh` adds zero new code to `update-claude.sh` if registered there.
- **v4.3 UN-03 `[y/N/d]` prompt contract:** read from `< /dev/tty`, fail-closed `N` on no-TTY. Reuse for `unofficial` MCP confirmation prompts (notebooklm, telegram).
- **Phase 25 D-08 continue-on-error pattern:** per-MCP install failure does not abort the loop; reuse for CLI installs in v4.9.
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

### Pending Todos

None at requirements-defining stage. Roadmapper kicks off after REQUIREMENTS.md is approved.

### Blockers/Concerns

None. v4.6 Phase 25 foundation is solid — extension path is clear.

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
| Future | `--preset minimal\|full\|dev` | TUI-FUT-02 — no demand surfaced (revisit at 19-entry catalog?) |
| Future | Grouped sections in TUI (Essentials / Optional) | **PROMOTED to v4.9 — categories are the answer** |
| Future | MCP catalog auto-sync with upstream registry | MCP-FUT-02 |
| Future | Marketplace signing/integrity | MKT-FUT-01 — no Anthropic spec yet |
| Deferred | Branding substitution layer for bridge files | BRIDGE-FUT-01 |
| Deferred | Per-CLI tone overlay snippets | BRIDGE-FUT-02 |
| Deferred | Cursor `.cursorrules` / Aider `CONVENTIONS.md` | BRIDGE-FUT-03/04 |
| Deferred | `update-claude.sh --bridges-only` mode | BRIDGE-FUT-05 |
| Parallel track | Council Rework | concurrent session |

## Session Continuity

Last session: 2026-05-02T00:00:00Z
Started: v4.9 Integrations Catalog milestone
Resume file: `.planning/PROJECT.md` (Current Milestone section)

**Next steps:**

1. Define REQUIREMENTS.md with REQ-IDs covering: catalog schema migration (CAT-*), CLI installer lib (CLI-*), TUI redesign with categories + status (TUI-*), 11 new entries (INT-*), drop sequential-thinking (DROP-*), docs (DOCS-*), tests (TEST-*).
2. Spawn `gsd-roadmapper` to create phased plan (Phase 32 onward).
3. Execute phases.
