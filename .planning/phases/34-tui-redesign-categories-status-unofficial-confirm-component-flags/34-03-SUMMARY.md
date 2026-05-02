---
phase: 34
plan: 03
plan_id: 34-03
title: Per-component install summary table
subsystem: scripts/lib + scripts/install.sh
tags: [tui, integrations, summary, ux, ordering-bug-fix]
req_ids: [TUI-05]
dependency_graph:
  requires:
    - "Plan 34-02 — RESULT_NAMES[] / RESULT_MCP_STATE[] / RESULT_CLI_STATE[] populated by dispatch loop"
    - "Plan 34-01 — MCP_DISPLAY[] / MCP_NAMES[] / MCP_TO_TUI_IDX[] (added in this plan, retroactively)"
  provides:
    - "print_integrations_summary() in scripts/lib/mcp.sh"
    - "TUI_TO_MCP_IDX[] / MCP_TO_TUI_IDX[] index translation arrays (Rule 1 retroactive fix to Plan 34-01)"
    - "Closing per-entry × per-component table with totals line"
  affects:
    - "scripts/lib/mcp.sh (new public function + index map population)"
    - "scripts/install.sh (selection blocks + dispatch loop + fail-fast pad now use TUI-index translation)"
tech_stack:
  added: []
  patterns:
    - "Bidirectional index map for parallel arrays in different orderings (TUI render order ↔ catalog alpha order)"
    - "NO_COLOR-aware glyph table (✓/⊘/✗/—/?) consistent with mcp_status_array"
    - "case-prefix matching on compound state strings (`skipped:reason`, `failed:exit-N: stderr-line`) to extract notes"
key_files:
  created: []
  modified:
    - scripts/lib/mcp.sh
    - scripts/install.sh
decisions:
  - "Augment, don't replace: legacy 'MCP install summary' block kept verbatim (preserves test-mcp-selector S7/S13 contracts), new table prints AFTER it. Both visible per dispatch run."
  - "Glyph mapping per D-22: ✓ installed (green), ⊘ already (cyan), ✗ failed (red, with truncated reason), · would-install (cyan dot), ⊘ skipped (yellow), — n/a (neutral), ? unknown (defensive). Distinct visual hierarchy without overloading any single glyph."
  - "Notes column truncates compound MCP+CLI reasons to 60 chars total (D-22 contract). Format: 'MCP: <reason>; CLI: <reason>' when both have reasons; single-side reason otherwise."
  - "Total line: 'Installed: N MCPs, M CLIs · Skipped: X · Failed: Y' (D-24). Counts are derived from RESULT_* arrays inside print_integrations_summary, not from the legacy COMPONENT_STATUS counters — keeps the function self-contained."
  - "Bidirectional index map (TUI_TO_MCP_IDX / MCP_TO_TUI_IDX) added to mcp.sh as part of mcp_status_array's reordering logic. Without it, install.sh's dispatch loop reads TUI_RESULTS[$i] (TUI-render order) against MCP_NAMES[$i] (alpha order) — guaranteed wrong selection mapping."
  - "Place summary table function in mcp.sh (not a new file) — the data shape and color helpers it needs already live there; new file would mean duplicating glyph + NO_COLOR boilerplate."
metrics:
  completed_date: 2026-05-02
  scripts_lib_mcp_sh_lines_delta: "+~174"
  scripts_install_sh_lines_delta: "+~50 / -~23"
  baselines_preserved:
    test-mcp-selector: 21/21 PASS
    test-integrations-foundation: 32/32 PASS
    test-install-dispatch-h1: 6/6 PASS
    make_check: rc=0
---

# Phase 34 Plan 03: Per-component install summary table

## One-liner

Adds `print_integrations_summary()` to `scripts/lib/mcp.sh` and hooks it into the close of the `--integrations` dispatch loop in `install.sh` — renders a per-entry × per-component (MCP × CLI) status table with glyph-coded states (✓/⊘/✗/—) plus a chezmoi-grade total line, while RETROACTIVELY fixing a Plan 34-01 ordering bug that was misaligning `TUI_RESULTS[]` with `MCP_NAMES[]`.

## What Changed

### `scripts/lib/mcp.sh`

**New `print_integrations_summary()` function (~150 lines)**:

Reads `RESULT_NAMES[]` / `RESULT_MCP_STATE[]` / `RESULT_CLI_STATE[]` (populated by the install.sh dispatch loop in Plan 34-02). Renders:

```text
━━━ Integrations Install Summary ━━━
Entry                        MCP            CLI            Notes
──────────────────────────── ────────────── ────────────── ─────
context7                     ⊘            —
firecrawl                    ✓             ✓
notebooklm                   ⊘            —            unofficial-declined
aws-cloudwatch-logs          ✓             ⊘            CLI: already
sentry                       ✗             ✓             MCP: exit-1: connection refused
...

Installed: 3 MCPs, 2 CLIs · Skipped: 1 · Failed: 1
```

Glyph mapping (per D-22):

| State (RESULT_*) | Glyph | Color |
|---|---|---|
| `installed` | ✓ | green |
| `installed:needs-key` | ✓ | yellow (counted as installed; needs API key in Notes) |
| `would-install` | · | cyan (dry-run) |
| `already` | ⊘ | cyan |
| `skipped:<reason>` | ⊘ | yellow (reason in Notes) |
| `failed:exit-N: <stderr>` | ✗ | red (truncated to 60 cols in Notes) |
| `na` | — | neutral |
| anything else | ? | defensive |

NO_COLOR-aware: when `NO_COLOR` is set or stdout isn't a TTY, all color codes resolve to empty strings.

Notes column composes per-state reasons:

- Both sides have reasons → `MCP: <r>; CLI: <r>`
- Single-side reason → bare reason
- 60-char total cap with `…` ellipsis on overflow

Total line uses `${_bold}Installed:` highlighting + center-dot separators (·) consistent with the existing legacy summary line `Installed: %d · Skipped: %d · Failed: %d`.

**Bash 3.2 invariant fix (Rule 1)**: `${#RESULT_NAMES[@]:-0}` is rejected as bad substitution. Replaced with the `[[ -z "${var[*]+x}" ]] || [[ "${#var[@]}" -eq 0 ]]` existence test pattern.

**Index map population in `mcp_status_array`**: see "Deviations" below — this is a Rule 1 retroactive fix to Plan 34-01.

### `scripts/install.sh`

**Hook in dispatch close**: After the existing `printf 'Installed: %d · Skipped: %d · Failed: %d\n'` line, calls `print_integrations_summary` so the new table renders after the legacy per-row block. Both are visible — keeps S7/S13 baseline assertions happy while adding the new TUI-05 surface.

**Dispatch loop translation (Rule 1 retroactive fix to Plan 34-01)**:

The MCP dispatch loop now iterates by TUI render index (`tui_i`) and translates to MCP_NAMES index (`i`) via `TUI_TO_MCP_IDX[]`. Same translation applied to:

- The `TK_MCP_PRE_SELECTED` headless block (writes `TUI_RESULTS[$tui_i]=1` when `MCP_NAMES[$_mcp_idx]` matches a CSV entry)
- The `--yes` default-set block (reads `TUI_INSTALLED[$tui_i]` and `MCP_OAUTH[$_mcp_idx]` separately)
- The fail-fast pad-out block (translates `j` → `_j_mcp` to read `MCP_NAMES[$_j_mcp]` / `MCP_HAS_CLI[$_j_mcp]`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, retroactive] TUI-render-order ↔ MCP_NAMES-alpha-order index mismatch from Plan 34-01**

- **Found during:** Plan 34-03 self-test — manual smoke run with `claude mcp list` mock returning `context7` and `supabase` showed the summary table writing `would-install` for `context7` (which the mock said was already installed) and `unselected` for the wrong row.
- **Issue:** Plan 34-01's rewrite of `mcp_status_array` reorders entries by category (TUI render order = alpha-within-category, walked via `CATEGORIES_ORDER[]`). But install.sh's dispatch loop, headless pre-selected block, and `--yes` default-set block all read `TUI_RESULTS[$i]` / `TUI_INSTALLED[$i]` against `MCP_NAMES[$i]` (alpha order). Since `${MCP_NAMES[3]}=context7` ≠ `${TUI_LABELS[3]}=AWS CloudWatch Logs`, the loop was selecting the wrong entries. **Critical correctness bug** introduced by Plan 34-01 but undetected because no baseline test exercises a non-empty `claude mcp list` mock through the install flow.
- **Fix:** Two-part:
  1. `mcp.sh:mcp_status_array` now populates `TUI_TO_MCP_IDX[]` (parallel to TUI arrays — TUI idx → catalog idx) and `MCP_TO_TUI_IDX[]` (parallel to MCP_NAMES — catalog idx → TUI idx).
  2. `install.sh` rewrites three index-using blocks to iterate by TUI render index and translate.
- **Files modified:** scripts/lib/mcp.sh, scripts/install.sh
- **Caught by:** Plan 34-03 manual smoke (would have caused unpredictable wrong-row installs in production). Per lessons-learned 260430-go5 H1: "Single-CLI scenarios are first-class test cases" — this same class of bug was caught last sweep.

**2. [Rule 1 - Bug] Bash 3.2 `${#var[@]:-0}` rejected as bad substitution**

- **Found during:** Plan 34-03 first smoke run
- **Issue:** Same pattern as Plan 34-01 caught — `${#RESULT_NAMES[@]:-0}` produces "ugyldig substitusjon" under macOS Bash 3.2.
- **Fix:** Use existence test `[[ -z "${var[*]+x}" ]] || [[ "${#var[@]}" -eq 0 ]]` mirroring tui.sh:164.
- **Files modified:** scripts/lib/mcp.sh

**3. [Rule 1 - Bug] `local` outside function scope**

- **Found during:** Plan 34-03 shellcheck pass
- **Issue:** Added `local _j_mcp` inside the fail-fast block in install.sh which is top-level shell context, not a function. shellcheck SC2168.
- **Fix:** Replace with plain `_j_mcp=""` underscore-prefixed assignment (matches the pattern at install.sh:386 used for `_pre_csv` / `_IFS_SAVE` etc.).
- **Files modified:** scripts/install.sh

## Threat Flags

None. The new function reads pre-populated arrays in the caller's context, performs no FS or network IO, no `eval` / `exec`, no shell expansion of user-controlled data (states are matched against literal `case` patterns; reasons are interpolated via `printf '%s'` only). The retroactive index-map fix tightens correctness — no new attack surface.

## Self-Check: PASSED

- scripts/lib/mcp.sh: present, +174 lines (`print_integrations_summary` + index-map init in `mcp_status_array`)
- scripts/install.sh: present, +50/-23 lines (dispatch + selection + fail-fast pad use index translation; `print_integrations_summary` hook added at close)
- test-mcp-selector.sh: PASS=21 FAIL=0 (preserved through all retroactive fixes)
- test-integrations-foundation.sh: PASS=32 FAIL=0 (preserved)
- test-install-dispatch-h1.sh: PASS=6 FAIL=0 (the dispatch-name-based-lookup regression test mentioned in lessons-learned — also still green)
- shellcheck scripts/install.sh scripts/lib/mcp.sh: clean
- make check: rc=0

## TDD Gate Compliance

This plan is `type: auto`, not TDD-gated. Plan-level type frontmatter is `auto` (no `type: tdd`).

## Lessons-Learned Carry-Over

- **Pattern propagation requires a sweep, not a fix** (260430-go5): the index-map bug from Plan 34-01 surfaced only because Plan 34-03's print-table-from-RESULT_* exposed an exact mock-mcp-list scenario where the bug manifests visually. Future plans that change array iteration ordering MUST run a "translate every index reader" sweep, not assume the existing call sites are still correct.
- **Single-side scenarios are first-class test cases**: a future regression test (Phase 35 TEST-03) should mock `claude mcp list` returning a single MCP that is NOT alphabetically first — exercises the index map with a non-trivial mapping (otherwise both `MCP_NAMES[0]` and `TUI_LABELS[0]` happen to match by coincidence).
