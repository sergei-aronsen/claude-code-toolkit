# Phase 34: TUI Redesign — Categories, Status, Unofficial Confirm, Component Flags — Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** Auto-discuss

<domain>
## Phase Boundary

Render the 20-entry integrations catalog as a category-grouped TUI page in `scripts/install.sh --integrations` with:
1. **Category headers** — visual grouping by canonical 10-list category
2. **Per-component status** — `MCP: ✓/✗/⊘` and `CLI: ✓/✗/⊘` columns per row, detected on every launch
3. **Unofficial confirm gate** — yellow `!` glyph + `[y/N]` prompt before installing entries with `unofficial: true`
4. **Component flags** — `--mcp-only` / `--cli-only` global flags with mutex enforcement
5. **Summary table** — per-entry × per-component status table at end of install run

REQ-IDs: TUI-01, TUI-02, TUI-03, TUI-04, TUI-05 (5 of 36).

This is the user-facing payoff phase of v4.9 — the schema (Phase 32) and populated catalog (Phase 33) come alive here as a polished install experience.

</domain>

<decisions>
## Implementation Decisions

### Plan structure (3 plans per STATE.md)

- **D-01:** Plan 34-01: Category-grouped rendering + per-component status (TUI-01 + TUI-02). Extends `scripts/lib/mcp.sh` rendering layer + `scripts/install.sh` TUI page invocation.
- **D-02:** Plan 34-02: Unofficial confirm gate + `--mcp-only` / `--cli-only` mutex flags (TUI-03 + TUI-04). New flag parsing in `install.sh` + per-row prompt in dispatch loop.
- **D-03:** Plan 34-03: Per-component summary table at install close (TUI-05). New summary helper in `mcp.sh` or a new `scripts/lib/integrations-summary.sh`.

### Wave structure

- **D-04:** All 3 plans touch `scripts/lib/mcp.sh` and/or `scripts/install.sh` — same files. **Sequential execution.** No worktrees (avoid merge conflicts on shared files).

### Category-grouped rendering (TUI-01)

- **D-05:** Categories rendered as visual section headers `── <Category Name> ──` (no checkbox, just label) before each group of entries.
- **D-06:** Category order matches canonical 10-list from CAT-03: `docs-research`, `backend`, `payments`, `email`, `workspace`, `project-management`, `communication`, `design`, `dev-tools`, `monitoring`. Categories with zero entries in catalog are SKIPPED (no empty headers).
- **D-07:** Within each category, entries sort alphabetically by entry name (the JSON key, not display_name).
- **D-08:** TUI rows keep their existing structure (`[x] <name>  <description>`) plus new status columns appended right-aligned.

### Per-component status detection (TUI-02)

- **D-09:** MCP status: parse `claude mcp list 2>/dev/null` output. If entry's MCP name (first element of `install_args`) appears in the list → `⊘ already installed`. Else → `✗`. If `claude` CLI absent → all MCP statuses become `?` (unknown).
- **D-10:** CLI status: per entry with `components.cli` present, run `command -v <detect_cmd>` → `⊘` (already) / `✗` (not). Entries without CLI block → `—` (n/a, not displayed in CLI column).
- **D-11:** Status detect runs ONCE at TUI launch (not per-render-frame). Cached in associative-array-equivalent (Bash 3.2 — use parallel arrays `STATUS_MCP_NAMES[]` + `STATUS_MCP_VALUES[]`).
- **D-12:** Re-detection happens on dispatch loop entry, not on every keypress — flicker-free.

### Unofficial confirm gate (TUI-03)

- **D-13:** Entries with `unofficial: true` render with a yellow `!` glyph (ANSI yellow, fallback to `[!]` plain text under NO_COLOR).
- **D-14:** When user selects an unofficial entry for install, BEFORE invoking `claude mcp add` or `cli_install`, prompt: `! '<display_name>' is community-maintained / browser-automation. Install anyway? [y/N]`. Read from `< /dev/tty`, fail-closed `N` (Phase 18 UN-03 contract).
- **D-15:** Skip prompt if `--yes` global flag is active. Log decision to summary either way.
- **D-16:** Test seam: `TK_INTEGRATIONS_TTY_SRC` env var (mirror Phase 28 `TK_BRIDGE_TTY_SRC` pattern).

### `--mcp-only` / `--cli-only` flags (TUI-04)

- **D-17:** New `install.sh` flags. Mutually exclusive — using both prints `--mcp-only and --cli-only are mutually exclusive` to stderr + exit 2.
- **D-18:** Default (no flag) installs both components when both available. `--mcp-only` skips CLI dispatch step. `--cli-only` skips MCP dispatch step.
- **D-19:** When entry has only one component (e.g., MCP-only entries like notion), the matching `--*-only` flag is a no-op for that entry; the mismatching flag silently skips the entry. No error, no warning per entry.
- **D-20:** Summary table (TUI-05) reflects skipped components as `⊘ skipped (--mcp-only|--cli-only)`.

### Summary table (TUI-05)

- **D-21:** Print at end of dispatch loop, mirrors Phase 25 D-28 contract. Columns: `Entry | MCP | CLI | Notes`.
- **D-22:** Status glyphs: `✓ installed` (newly), `⊘ already` (pre-existing), `✗ failed: <reason>` (with first stderr line truncated to 60 chars), `— n/a` (no component), `⊘ skipped` (--*-only).
- **D-23:** Use existing `dro_*` helpers (`dro_print_header`, `dro_print_file`, `dro_print_total`) for consistency with chezmoi-grade output across init/update.
- **D-24:** Total line: `Installed: N MCPs, M CLIs | Skipped: X | Failed: Y`.

### Backward compat

- **D-25:** Existing `--mcps` flow (Phase 25) must keep working. The new `--integrations` page is the canonical entry; `--mcps` is alias (Phase 32 D-22). 21-assertion `test-mcp-selector.sh` baseline must not regress.
- **D-26:** Test `test-integrations-foundation.sh` (32 assertions) must keep passing.

### Bash 3.2 invariants

- **D-27:** No associative arrays. Use parallel `*_KEYS[]` + `*_VALUES[]` arrays.
- **D-28:** No `read -N`. Use `read -r` with single-byte limit via `head -c1` if needed.
- **D-29:** No `${var,,}` lowercasing. Use `tr '[:upper:]' '[:lower:]'`.

### Claude's Discretion

- Exact ANSI color codes for `!` glyph (yellow chosen, but byte-level is flexible).
- Whether to render category headers with `── X ──` or `── X ──────────────────` padded — UI flair, planner picks.
- Internal helper names within mcp.sh / new files.
- Whether to add a `--no-status` flag to skip detection (e.g., for fully-offline TUI rendering) — defer unless Phase 35 tests need it.
- Layout of summary table column widths — adapt to terminal width if `tput cols` available, fallback to 80-col fixed.

</decisions>

<canonical_refs>
## Canonical References

### Milestone scoping
- `.planning/PROJECT.md` § Current Milestone v4.9
- `.planning/REQUIREMENTS.md` — TUI-01..05 verbatim
- `.planning/ROADMAP.md` Phase 34
- `.planning/STATE.md` § Plan Count Estimate (Phase 34 = 3 plans)

### Phase 32/33 outputs (foundation)
- `scripts/lib/integrations-catalog.json` — 20-entry catalog with categories + unofficial flags + cli blocks (Phase 33 final state)
- `scripts/lib/mcp.sh` — extended catalog loader from Phase 32; existing public functions to extend: `mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`
- `scripts/lib/cli-installer.sh` — `cli_detect`, `cli_install`, `cli_post_install_hint` (Phase 32 Plan 32-02)
- `scripts/install.sh` — TUI orchestrator with `--integrations`/`--mcps` flag handler at lines ~60-260
- `scripts/lib/dry-run-output.sh` — `dro_*` helpers for summary table

### Reference patterns
- v4.8 Phase 30 — `--bridges` / `--no-bridges` mutex contract; mirror for `--mcp-only` / `--cli-only`
- v4.6 Phase 25 D-28 — per-MCP summary table contract
- v4.3 Phase 18 UN-03 — `< /dev/tty` + fail-closed N prompt
- v4.6 Phase 24 — TUI render primitives in `scripts/lib/tui.sh`

### Bash 3.2 invariants
- v4.6 Phase 24 BACKCOMPAT-01

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mcp.sh` `mcp_catalog_load` — already loads new schema (Phase 32). Extend rendering, not loading.
- `mcp.sh` `mcp_status_array` — current status detection (binary present/absent). Extend to per-component (MCP + CLI).
- `mcp.sh` `mcp_wizard_run` — per-entry install dispatch. Extend with unofficial gate + component-only flag.
- `cli-installer.sh` `cli_detect`, `cli_install` — drop-in CLI primitives.
- `dry-run-output.sh` `dro_*` — summary table helpers.
- `tui.sh` — rendering primitives (assume row/header/footer helpers exist; verify in plan).

### Established Patterns
- TUI rendering uses ANSI color constants, falls back to plain text under NO_COLOR.
- All prompts read from `< /dev/tty` with fail-closed N.
- Status detection: parse external CLI output, never persist.
- Continue-on-error in dispatch loop (Phase 25 D-08).

### Integration Points
- `scripts/install.sh` CLI flag block (~lines 60-260) — add `--mcp-only`, `--cli-only`, mutex check.
- `mcp.sh` rendering — add category grouping pre-pass + per-component status columns.
- Dispatch loop — add unofficial gate prompt + component-only filtering.
- Post-dispatch summary — new helper or inline `dro_*` block.

</code_context>

<deferred>
## Deferred Ideas

- `--no-status` flag for offline TUI render — defer.
- AWS shared-CLI dedup auto-detection — current dispatch loop calls `cli_detect aws` once via the catalog block being identical; no special-case code needed in Phase 34. If duplicates surface in summary table, fix in Phase 35 polish.
- Search/filter input in TUI — TUI-FUT-05 from REQUIREMENTS.md.
- `--preset minimal|full|dev` — TUI-FUT-04.

</deferred>

---

*Phase: 34-tui-redesign-categories-status-unofficial-confirm-component-flags*
*Context gathered: 2026-05-02*
