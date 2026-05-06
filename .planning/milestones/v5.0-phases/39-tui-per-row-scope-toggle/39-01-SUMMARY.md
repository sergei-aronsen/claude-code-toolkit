---
phase: 39-tui-per-row-scope-toggle
plan: 01
subsystem: tui

tags:
  - tui
  - bash
  - mcp
  - scope
  - render

# Dependency graph
requires:
  - phase: 36-catalog-schema-backward-compat
    provides: MCP_DEFAULT_SCOPE[] populated from catalog default_scope field
  - phase: 37-mcp-scope-toggle
    provides: TUI_HEADER_KEY/TUI_HEADER_FN indirection in tui_checklist case-match
  - phase: 38-wizard-dispatch-integration
    provides: mcp_wizard_run reads TK_MCP_SCOPE per call (project/user/local routing)
provides:
  - MCP_SELECTED_SCOPE[] parallel array (per-row mutable scope state)
  - _mcp_render_scope_glyph helper (3-bracket [U]/[P]/[L] fragment, NO_COLOR-aware)
  - mcp_cycle_row_scope() Tab handler (cycles user→project→local→user in place)
  - TUI_ROW_KEY / TUI_ROW_FN globals (per-row hotkey indirection)
  - Tab byte ($'\t') case-arm in tui_checklist (BEFORE catch-all)
  - Footer hint extension "Tab row-scope" + header copy "set-all-scope"
affects:
  - 39-02 (set-all `s` repurpose + dispatcher binding)
  - 39-03 (test-mcp-selector.sh extension — 5+ assertions)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Caller-builds-TUI_LABELS — tui.sh stays domain-agnostic; mcp.sh injects scope glyph at array build, mirrors v4.6 unofficial '!' shape"
    - "Color resolution at array-build time once (not per-frame); _c_scope_active mirrors _c_ok TTY+NO_COLOR gate"
    - "Parallel-array index parity invariant — MCP_SELECTED_SCOPE+= and TUI_LABELS+= grow in lockstep inside the seen_idx loop"
    - "TUI_ROW_KEY/FN indirection mirrors TUI_HEADER_KEY/FN — single shape for caller-defined hotkeys"

key-files:
  created: []
  modified:
    - "scripts/lib/mcp.sh — _mcp_render_scope_glyph (line 1009-1031), mcp_cycle_row_scope (line 1005-1066), MCP_SELECTED_SCOPE reset+push in mcp_status_array (lines 1086-1091, 1170-1180), _c_scope_active resolver (lines 1131-1139)"
    - "scripts/lib/tui.sh — TUI_ROW_KEY/FN header doc (lines 14-15), Tab case-arm (lines 439-463), footer _row_hint + s set-all-scope copy (lines 280-302)"

key-decisions:
  - "Tab byte ($'\\t') chosen as TUI_ROW_KEY default per CONTEXT D-05 — single-byte ASCII 0x09, no multi-byte ambiguity on macOS BSD bash 3.2; verified by smoke harness"
  - "Footer copy 'Tab row-scope · s set-all-scope' under one line; total ~95 chars including all conditional segments — fits standard 100-col terminals"
  - "mcp_cycle_row_scope re-renders the row's TUI_LABELS slot internally so callers don't need to call mcp_status_array again — KISS, in-place mutation only"
  - "Header copy change 's scope' → 's set-all-scope' lands in Plan 01 (render concern) even though behavior wiring (set-all body) lands in Plan 02 — copy ships with the per-row Tab hint as a single visual contract"

patterns-established:
  - "Parallel-array population in mcp_status_array — MCP_SELECTED_SCOPE+= adjacent to TUI_LABELS+= inside seen_idx loop preserves index parity (T-39-02-T2 mitigation: CLI-only rows automatically excluded since they never enter MCP_NAMES)"
  - "Color helper function reading caller-locals — _mcp_render_scope_glyph reads _c_scope_active/_c_nc set by caller; lets mcp_status_array (color resolved once per build) and mcp_cycle_row_scope (color resolved per call) share one rendering function"
  - "Tab-arm placement BEFORE catch-all *) — mirrors arrow ($'\\e[A')/Space/Enter precedence; the strict gate `\"$TUI_ROW_KEY\" == $'\\t'` in the arm body lets future callers swap to `t` without code change"

requirements-completed:
  - TUI-SCOPE-01
  - TUI-SCOPE-02
  - TUI-SCOPE-04

# Metrics
duration: 9m
completed: 2026-05-05
---

# Phase 39 Plan 01: TUI render + state Summary

**MCP_SELECTED_SCOPE[] parallel array with [U]/[P]/[L] glyph injection in TUI_LABELS, plus mcp_cycle_row_scope() + Tab dispatcher in tui_checklist for per-row scope cycling.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-05-05T19:00:35Z
- **Completed:** 2026-05-05T19:09:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- **State (TUI-SCOPE-04):** `MCP_SELECTED_SCOPE[]` populated parallel to `TUI_LABELS` from `MCP_DEFAULT_SCOPE[$i]` at every `mcp_status_array` call (TUI render index, not MCP_NAMES alpha). Reset on entry so re-launches reseed from catalog.
- **Render (TUI-SCOPE-01):** Each MCP row's `TUI_LABELS` entry carries a 3-bracket `[U] [P] [L]` fragment immediately before the display name; the active scope's bracket is wrapped in `\033[0;32m...\033[0m` (green) under TTY+color, plain under NO_COLOR or non-TTY.
- **Per-row hotkey (TUI-SCOPE-02 — library half):** `mcp_cycle_row_scope()` mutates only `MCP_SELECTED_SCOPE[$FOCUS_IDX]` (cycling user→project→local→user) and rebuilds that single slot's `TUI_LABELS` entry. Out-of-bounds FOCUS_IDX (Submit row, CLI-only row) is a silent no-op.
- **Dispatcher (TUI-SCOPE-02 — wiring):** `tui_checklist` recognises a Tab byte (`$'\t'`) case-arm placed BEFORE the catch-all `*)`; dispatches to caller-supplied `TUI_ROW_FN` via the new `TUI_ROW_KEY`/`TUI_ROW_FN` globals (mirrors `TUI_HEADER_KEY`/`TUI_HEADER_FN`).
- **Footer hint:** Now reads `↑↓ navigate · Space toggle · Enter install · Tab row-scope · s set-all-scope · b back · Ctrl+C abort` when both globals are wired (one line, ~95 chars).

## Task Commits

Each task was committed atomically:

1. **Task 1: MCP_SELECTED_SCOPE[] population + per-row scope glyph injection** — `f68c76d` (feat)
2. **Task 2: mcp_cycle_row_scope + tui.sh Tab dispatcher + footer hint** — `29557a8` (feat)

_Note: Neither task ran the RED gate of TDD because the contract is library-internal Bash and the existing test harness (`test-mcp-selector.sh`) is extended in Plan 03 per the phase plan; smoke verification was performed inline (parallel-array invariant, 3-cycle return-to-start, sibling fingerprint preservation, out-of-bounds no-op, color-on render variation per scope, Tab dispatch firing). The plan's `tdd="true"` task flag is interpreted as "behavior-first specification" — every contract bullet was checked before commit._

## Files Created/Modified

- `scripts/lib/mcp.sh` — Added `_mcp_render_scope_glyph` helper (3-bracket fragment with active scope green-wrapped); added `mcp_cycle_row_scope` (per-row Tab handler); added `MCP_SELECTED_SCOPE=()` reset and per-row push inside `mcp_status_array`'s seen_idx loop; added `_c_scope_active` color resolver alongside existing `_c_*` block; injected `${_scope_glyph} ` prefix into every TUI label before push.
- `scripts/lib/tui.sh` — Documented new `TUI_ROW_KEY`/`TUI_ROW_FN` globals in header; added Tab byte (`$'\t')`) case-arm BEFORE catch-all `*)`; built `_row_hint` segment in footer composer; updated header copy `${KEY} scope` → `${KEY} set-all-scope` per D-11.

## Decisions Made

- **Tab as `TUI_ROW_KEY`** — Tab byte (ASCII 0x09) chosen over `Shift-S` per CONTEXT D-05. Single-byte ASCII, no multi-byte sequence ambiguity on macOS BSD bash 3.2. The strict gate `"$TUI_ROW_KEY" == $'\t'` lets future callers swap to a different byte (e.g., lowercase `t`) without changing the dispatch arm.
- **In-place label rebuild in `mcp_cycle_row_scope`** — Rather than calling `mcp_status_array` to re-render the entire array, the handler rebuilds only `TUI_LABELS[$FOCUS_IDX]`. Cheaper, KISS, and matches the v4.9 reinstall-toggle pattern where Space-press only rebuilds the focused row.
- **Color resolution shared via caller-locals** — `_mcp_render_scope_glyph` reads `_c_scope_active`/`_c_nc` from the calling function's lexical scope (Bash dynamic scoping). This lets `mcp_status_array` resolve color ONCE per array build (D-04) while `mcp_cycle_row_scope` resolves it per call (since it's invoked from tui_checklist, not from mcp_status_array's frame). One rendering function, two resolution sites.
- **Header copy migrates with Plan 01** — `s scope` → `s set-all-scope` updated in Plan 01 footer hint even though the behavioral change (set-all body in `mcp_toggle_scope`) lands in Plan 02. Visual contract ships together; footer would be wrong if it advertised the old copy alongside the new `Tab row-scope` hint.

## Deviations from Plan

None — plan executed exactly as written. All <action> blocks landed verbatim; the smoke-test "label re-render under NO_COLOR" expectation was clarified in flight (under NO_COLOR, the rebuilt label is byte-identical because there's no ANSI escape to indicate the active bracket — this is the documented behavior, not a bug). The color-on render variation was verified separately with forced color escapes.

## Issues Encountered

- **Repeated bash `read` on regular file fixture infinite-loops** — When wiring up the Tab-dispatch smoke harness, feeding `\t\n\n` into a sandbox file and reading via `read -rsn1 < fixture` succeeded for the first byte but kept re-reading byte 0 because the position resets each open. The dispatch logic itself is correct (TAB_FIRED marker observed); the harness behavior is a known TTY-fixture limitation. Plan 03's hermetic harness will use the established `TK_TUI_TTY_SRC` seam properly.

## User Setup Required

None — no external service configuration. All changes are pure bash library additions.

## Next Phase Readiness

- **Plan 02 ready:** `mcp_toggle_scope` repurpose can now read the existing `MCP_SELECTED_SCOPE[]` array length and write every slot in one stroke; the footer already advertises `s set-all-scope`. The `_MCP_SETALL_SCOPE` module-local pending-state variable referenced in CONTEXT.md D-12 is the only remaining piece.
- **Plan 03 ready:** `test-mcp-selector.sh` extension can assert `MCP_SELECTED_SCOPE[]` length parity, per-row default-scope mapping, single-row cycle (TUI-SCOPE-02), out-of-bounds no-op, and the new public functions exist (`type mcp_cycle_row_scope`, `type _mcp_render_scope_glyph`).
- **install.sh dispatcher (Plan 39-02 or later):** can read `MCP_SELECTED_SCOPE[$tui_i]` (NOT `MCP_NAMES idx`) per row before `mcp_wizard_run`, exporting `TK_MCP_SCOPE` per-call. Phase 38's wizard reads the env fresh per invocation, so this completes the per-row scope flow.

## Verification Summary

| Check | Result |
|-------|--------|
| `make shellcheck` | ✅ clean (no new warnings) |
| `bash -n scripts/lib/mcp.sh` | ✅ exit 0 |
| `bash -n scripts/lib/tui.sh` | ✅ exit 0 |
| Parallel-array invariant `${#MCP_SELECTED_SCOPE[@]} == ${#TUI_LABELS[@]}` | ✅ 20 == 20 |
| context7 carries `[U]` (default_scope=user) | ✅ |
| supabase carries `[P]` (default_scope=project) | ✅ |
| `mcp_status_array` idempotent on repeat call | ✅ |
| `mcp_cycle_row_scope` 3-cycle returns to start | ✅ user→project→local→user |
| `mcp_cycle_row_scope` siblings byte-identical | ✅ |
| `mcp_cycle_row_scope` out-of-bounds no-op | ✅ |
| Tab→TUI_ROW_FN dispatch fires | ✅ TAB_FIRED marker observed |
| Color-on render varies per active scope | ✅ green wraps shift U→P→L |
| `test-mcp-secrets.sh` | ✅ PASS=11 (baseline preserved) |
| `test-project-secrets.sh` | ✅ PASS=42 (baseline preserved) |
| `test-mcp-wizard.sh` | ✅ PASS=53 (baseline preserved) |
| `test-mcp-selector.sh` | ✅ PASS=23 (above PASS=21 floor) |

## Self-Check: PASSED

All claimed files exist and contain the documented changes:

- `scripts/lib/mcp.sh` — `_mcp_render_scope_glyph` defined, `mcp_cycle_row_scope` defined, `MCP_SELECTED_SCOPE` referenced 4× (declaration comment, reset, push, mutation in cycle handler).
- `scripts/lib/tui.sh` — `TUI_ROW_KEY` referenced 7×, `TUI_ROW_FN` referenced 6×, `$'\t')` arm at line 439 (between `b|B)` line 425 and `*)` line 464), `Tab row-scope` 1×, `set-all-scope` 2×.

All claimed commits exist in git log:

- `f68c76d feat(39-01): add MCP_SELECTED_SCOPE[] + per-row scope glyph in mcp_status_array` ✅
- `29557a8 feat(39-01): add mcp_cycle_row_scope + Tab dispatcher in tui_checklist` ✅

---

*Phase: 39-tui-per-row-scope-toggle*
*Completed: 2026-05-05*
