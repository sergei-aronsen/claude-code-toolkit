---
phase: 34
plan: 01
plan_id: 34-01
title: Category-grouped TUI rendering + per-component status detection
subsystem: scripts/lib + scripts/install.sh
tags: [tui, mcp, integrations, status-detection, categories]
req_ids: [TUI-01, TUI-02]
dependency_graph:
  requires:
    - "Phase 32 — schema v2 with .categories[] + components.{mcp,cli}.{name}"
    - "Phase 33 — populated 20-entry catalog with category + unofficial fields + 8 cli blocks"
  provides:
    - "MCP_CATEGORY[] / MCP_HAS_CLI[] / MCP_UNOFFICIAL[] / MCP_CLI_DETECT[] parallel arrays"
    - "CATEGORIES_ORDER[] canonical category order"
    - "MCP_STATUS[] / CLI_STATUS[] per-component status arrays"
    - "mcp_categories_load + mcp_status_detect + _mcp_category_display helpers"
    - "Category-grouped TUI rendering with [!] unofficial badge + [MCP:✓ CLI:✗] status block"
  affects:
    - "scripts/lib/mcp.sh (extends mcp_catalog_load + mcp_status_array)"
    - "scripts/install.sh (sub-picker rebuilds TUI arrays in category order)"
tech_stack:
  added: []
  patterns:
    - "Parallel arrays for Bash 3.2 compatibility (no associative arrays)"
    - "NO_COLOR-aware glyph selection (✓/✗/⊘/—) with ANSI fallback"
    - "Title-case kebab→display via tr + parameter expansion (no ${var^^})"
    - "jq // empty branch for optional schema fields (avoids 'null' string brittleness)"
key_files:
  created: []
  modified:
    - scripts/lib/mcp.sh
    - scripts/install.sh
decisions:
  - "Single-pass category iteration: walk CATEGORIES_ORDER, gather indices per category, emit alpha-sorted within. Skip empty categories silently (D-06)."
  - "Description-augmented status block instead of separate column: tui.sh already indents description under each row; appending [MCP:x CLI:y] keeps the layout single-column-friendly without rewriting tui_render."
  - "Unofficial badge: yellow `!` glyph when colors enabled, plain `[!]` under NO_COLOR. Inserted at start of label so it's visible in compact list."
  - "Sub-picker (back-nav path) uses raw MCP_NAMES for label-to-CSV match against TK_MCP_PRE_SELECTED, but preserves category grouping + status block in description — backward-compatible CSV format unchanged."
  - "mcp_status_detect is called inside mcp_status_array (single entry point); no separate launch hook needed in install.sh."
metrics:
  completed_date: 2026-05-02
  scripts_lib_mcp_sh_lines_added: 274
  scripts_install_sh_lines_added: 53
  baselines_preserved:
    test-mcp-selector: 21/21 PASS
    test-integrations-foundation: 32/32 PASS
    make_check: rc=0
---

# Phase 34 Plan 01: Category-grouped TUI rendering + per-component status

## One-liner

Renders the 20-entry integrations catalog grouped by canonical 10-category order with per-row `[MCP:✓ CLI:✗]` status indicators and a yellow `!` glyph for unofficial entries — extending `mcp.sh` parallel-array surface and reusing `tui.sh`'s built-in `TUI_GROUPS[]` section-header transition logic.

## What Changed

### `scripts/lib/mcp.sh`

**Extended `mcp_catalog_load`** to populate four new parallel arrays:

- `MCP_CATEGORY[]` — entry's category (`"backend"`, `"docs-research"`, etc.) — defaults to empty string for v4.6 schema-v1 catalogs (back-compat).
- `MCP_HAS_CLI[]` — `0/1` flag (1 when `components.cli.<name>` block present).
- `MCP_UNOFFICIAL[]` — `0/1` flag (1 when `components.mcp.<name>.unofficial == true`). Defaults to 0 via `// false` jq fallback.
- `MCP_CLI_DETECT[]` — the `detect_cmd` from `components.cli.<name>.detect_cmd`, or empty string when no CLI block.

Uses `// empty` jq fallback (not `// null`) — exits jq with no output when the schema path is absent, avoiding the brittle `"null"` string match at the bash side.

**Added three new functions**:

1. `mcp_categories_load` — populates `CATEGORIES_ORDER[]` from `.categories[]?` in canonical order.
2. `_mcp_category_display` — title-cases kebab-case keys (`docs-research` → `Docs Research`, `project-management` → `Project Management`). Bash 3.2 safe — uses `tr '[:upper:]' '[:lower:]'` + first-byte param expansion since `${var^^}` lands at Bash 4.0+.
3. `mcp_status_detect` — populates `MCP_STATUS[]` ("installed" | "absent" | "unknown") and `CLI_STATUS[]` ("installed" | "absent" | "na"). Reuses `_mcp_list_cache_init` for single-shot `claude mcp list` (lazy/cached, ~4s round-trip) and `command -v` for CLI detect (sub-millisecond per call). Runs once per TUI launch (D-11).

**Rewrote `mcp_status_array`** to:

- Walk `CATEGORIES_ORDER[]` in canonical order (10-list per Phase 33 D-06).
- For each category, gather catalog indices in alpha order (alpha guaranteed by `mcp_catalog_load`'s `keys | sort | .[]`), emit them.
- Categories with zero entries → no header, silent skip (D-06).
- Compose `TUI_LABELS[i]` with optional `! ` (yellow under color) or `[!] ` (plain under NO_COLOR) prefix on unofficial entries.
- Set `TUI_GROUPS[i]` to the title-cased category — drives `tui.sh`'s built-in section header logic at `tui.sh:151-181` (no new rendering machinery needed).
- Append `[MCP:✓ CLI:—]`-style status block to `TUI_DESCS[i]`, where glyphs map status states (✓ installed, ✗ absent, ⊘ unknown, — n/a).
- Populate `TUI_GROUP_NAMES[]` + `TUI_GROUP_DESCS[]` (parallel; descs left empty here) for the optional dim subtitle lookup at `tui.sh:164`.

**Bash 3.2 invariant fix (Rule 1):** initial implementation used `${#CATEGORIES_ORDER[@]:-0}` which Bash 3.2 rejects as "ugyldig substitusjon" (bad substitution). Replaced with the established existence-test pattern `[[ -z "${CATEGORIES_ORDER[*]+x}" ]] || [[ "${#CATEGORIES_ORDER[@]}" -eq 0 ]]` that mirrors `tui.sh:164`. Caught in self-test before commit.

### `scripts/install.sh`

The MCP sub-picker (back-nav path, lines ~1314-1396) historically used `MCP_NAMES` as the TUI label so `TK_MCP_PRE_SELECTED` CSV exact-match works. After `mcp_status_array` rewrite, its output `TUI_LABELS` is in category-iteration order with `[!]` badges — different from `MCP_NAMES` order. The sub-picker now:

- Calls `mcp_status_array` to populate the parallel category/status arrays.
- Walks `CATEGORIES_ORDER[]` to rebuild `TUI_LABELS[]` from raw `MCP_NAMES` (preserves CSV exact-match contract) but with `TUI_GROUPS[]` set to title-cased category.
- Manually rebuilds the status block + `[!]` description prefix for parity with the main TUI rendering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Invalid Bash 3.2 substitution `${#var[@]:-0}`**
- **Found during:** Task 3 self-test
- **Issue:** `${#CATEGORIES_ORDER[@]:-0}` produced "ugyldig substitusjon" under macOS Bash 3.2; arrays initialized to length 0
- **Fix:** Use existence test `[[ -z "${var[*]+x}" ]] || [[ "${#var[@]}" -eq 0 ]]` mirroring `tui.sh:164`
- **Files modified:** scripts/lib/mcp.sh
- **Caught by:** Self-test before commit

## Threat Flags

None. No new network endpoints, auth surfaces, file access patterns, or schema mutations introduced. Status detection reads `claude mcp list` (already gated by Phase 25 cache) and `command -v` (no FS write). Catalog read paths use existing `// empty` jq guards already validated by Phase 32 schema validator.

## Self-Check: PASSED

- scripts/lib/mcp.sh: present, +274 lines, source loads cleanly, all 4 new arrays populated correctly (verified manually with mock claude binary)
- scripts/install.sh: present, +53 lines in sub-picker block
- test-mcp-selector.sh: PASS=21 FAIL=0 (preserved)
- test-integrations-foundation.sh: PASS=32 FAIL=0 (preserved)
- shellcheck scripts/lib/mcp.sh scripts/install.sh: clean (no warnings)
- make check: rc=0 (lint + validate + parity all green)
