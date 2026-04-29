---
phase: 24-unified-tui-installer-centralized-detection
plan: 02
subsystem: tui
tags: [bash, tui, terminal, bash32-compat, phase-24]

dependency_graph:
  requires:
    - phase: 24-01
      provides: scripts/lib/detect2.sh (is_*_installed probes, detect2_cache)
  provides:
    - scripts/lib/tui.sh (tui_checklist + tui_confirm_prompt API)
  affects:
    - plans/24-03 (dispatch.sh sources tui.sh for rendering)
    - plans/24-04 (install.sh sources tui.sh; test-install-tui.sh extended to ≥15 assertions for TUI-07)

tech-stack:
  added: []
  patterns:
    - sourced-lib header with color guards (no errexit, per bootstrap.sh precedent)
    - TK_TUI_TTY_SRC per-read redirection seam (mirrors TK_BOOTSTRAP_TTY_SRC exactly)
    - read -rsn1 + read -rsn2 two-pass arrow detection (Bash 3.2 compat)
    - parallel indexed arrays for TUI state (no associative arrays, no namerefs)
    - trap-before-raw-mode ordering (TUI-03 contract)
    - triple-fallback stty restore (saved string -> stty sane -> silent || true)
    - NO_COLOR gating via ${NO_COLOR+x} presence test (no-color.org canonical)

key-files:
  created:
    - scripts/lib/tui.sh
  modified: []

key-decisions:
  - "Comments referencing forbidden Bash 3.2 patterns use paraphrased descriptions to avoid grep false-positives in acceptance criteria checks"
  - "Help line rendered plain (no ANSI) when _TUI_COLOR=0, using separate plain printf branch rather than stripping sequences post-render"
  - "Log helpers use ASCII i/! markers instead of Unicode glyphs to avoid locale issues in restricted environments"

patterns-established:
  - "TUI render writes exclusively to /dev/tty — stdout stays clean for caller capture"
  - "trap-before-raw-mode: EXIT INT TERM registered before _tui_enter_raw in every function that enters raw mode"
  - "Per-read TTY redirection: tty_target computed inside each function, never global exec redirect"

requirements-completed: [TUI-01, TUI-02, TUI-03, TUI-04, TUI-05, TUI-06]

duration: 6min
completed: 2026-04-29
---

# Phase 24 Plan 02: TUI Rendering Bash 3.2 Summary

**Bash 3.2 compatible TUI checklist library with grouped checkbox menu (arrow/space/enter), [y/N] confirm prompt, and per-read /dev/tty seam — foundation for Plans 03, 04, 25, 26**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-29T10:44:32Z
- **Completed:** 2026-04-29T10:49:35Z
- **Tasks:** 3
- **Files created:** 1

## Accomplishments

- Created `scripts/lib/tui.sh` (270 lines) exposing `tui_checklist` and `tui_confirm_prompt`
- Verified all Bash 3.2 constraints: `read -rsn1`/`read -rsn2` two-pass arrow detection, parallel indexed arrays, no associative arrays or namerefs
- TUI-03 trap-before-raw-mode contract in place; triple-fallback `_tui_restore` prevents terminal left in raw mode on Ctrl-C
- TUI-06 three-layer NO_COLOR gate: `[ -t 1 ]` + `[ -z "${NO_COLOR+x}" ]` + `[[ "${TERM:-dumb}" != "dumb" ]]`
- BACKCOMPAT-01 preserved: `test-bootstrap.sh` still passes 26/26 assertions

## Task Commits

1. **Task 1+2: Write + smoke-test scripts/lib/tui.sh** - `221f549` (feat)
2. **Task 3: shellcheck + BACKCOMPAT-01 + commit** - included in `221f549`

**Plan metadata commit:** (see below)

## Files Created

- `scripts/lib/tui.sh` — TUI checklist library; exposes `tui_checklist` (grouped checkbox menu) and `tui_confirm_prompt` ([y/N] prompt); all render output to `/dev/tty`; stdout stays clean

## Public API Contract

```text
tui_checklist
  Input arrays (set before call):
    TUI_LABELS[]    — display names
    TUI_GROUPS[]    — "Bootstrap" | "Core" | "Optional"
    TUI_INSTALLED[] — 1=already installed, 0=not installed
    TUI_DESCS[]     — one-line description per item
  Output:
    TUI_RESULTS[]   — 1=install, 0=skip; parallel to TUI_LABELS
  Returns: 0 on enter, 1 on q/Ctrl-C/EOF

tui_confirm_prompt <prompt_text>
  Returns: 0 if user typed y/Y, 1 otherwise (default N)
```

## Key Implementation Details

- **TUI-03 trap location:** `tui_checklist` line with `trap '_tui_restore || true' EXIT INT TERM` appears immediately before `_tui_enter_raw` call
- **TK_TUI_TTY_SRC seam:** mirrors `bootstrap.sh:43-48` exactly — `local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"` computed inside each function, never a global exec redirect
- **Pre-selection (D-12):** uninstalled items pre-checked (`TUI_RESULTS[i]=1`), installed items set to 0 and rendered as `[installed ✓]` (immutable per D-13)
- **Arrow indicator (D-16):** `▶ ` prefix on focused row; overridable via `TK_TUI_ARROW` env for terminals that don't render the glyph
- **Checkbox glyphs (D-17):** `[ ]` unchecked, `[x]` checked, `[installed ✓]` for already-installed items

## Decisions Implemented

| Decision | Description |
|----------|-------------|
| D-01..D-03 | Grouped sections with dimmed headers; non-selectable; stable render order |
| D-13 | Installed items immutable in toggle (space key ignored when `TUI_INSTALLED[i]=1`) |
| D-16 | Arrow `▶` focus indicator, not reverse video |
| D-17 | `[ ]` / `[x]` / `[installed ✓]` glyph set |
| D-19 | Help line always shown at bottom of viewport |
| D-20 | Description line (single dimmed) for focused item |
| D-33 | `TK_TUI_TTY_SRC` test seam mirrors v4.4 `TK_BOOTSTRAP_TTY_SRC` |

## Requirements Addressed

| REQ-ID | Description | Status |
|--------|-------------|--------|
| TUI-01 | Bash 3.2 `read -rsn1`/`read -rsn2` keystroke detection | Done |
| TUI-02 | `TK_TUI_TTY_SRC` seam + fail-closed on EOF/no-TTY | Done |
| TUI-03 | Trap registered before raw mode entry | Done |
| TUI-04 | Label + status + description rendering per item | Done |
| TUI-05 | `tui_confirm_prompt` separate exported function | Done |
| TUI-06 | NO_COLOR + TTY + TERM=dumb three-layer color gate | Done |

Note: TUI-07 (≥15 assertions in test-install-tui.sh) is delivered by Plan 04.

## Downstream Contract

- Plan 24-03 (`dispatch.sh`) and Plan 24-04 (`install.sh`) source `scripts/lib/tui.sh`
- Plan 24-04 extends `test-install-tui.sh` with keystroke fixture scenarios to reach ≥15 total assertions (TUI-07)
- Plans 25 (MCP selector) and 26 (Skills selector) reuse `tui_checklist` unchanged — this lib is the foundation, not single-use

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment text avoided literal forbidden patterns for grep accuracy**

- **Found during:** Task 1 acceptance criteria verification
- **Issue:** Header comments contained literal strings `read -N`, `declare -A`, `declare -n` as anti-pattern examples; grep-based acceptance checks matched them as false positives
- **Fix:** Replaced with paraphrased equivalents ("capital-N flag", "associative arrays", "namerefs") so greps accurately reflect actual code usage
- **Files modified:** `scripts/lib/tui.sh`
- **Verification:** All 15 acceptance criteria grep checks pass
- **Committed in:** `221f549`

---

**Total deviations:** 1 auto-fixed (Rule 1 — comment text correction for grep accuracy)
**Impact on plan:** Minimal cosmetic change; no functional behavior affected.

## Issues Encountered

None.

## Known Stubs

None — `tui.sh` is a pure library; no data flows or UI rendering are stubbed. Plan 04 wires the full keystroke matrix via `test-install-tui.sh`.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns beyond `/dev/tty` (already in threat model as T-24-06/T-24-08), or schema changes.

## Self-Check: PASSED

- `scripts/lib/tui.sh` exists: FOUND
- Commit `221f549` exists: FOUND
- All 7 functions defined (tui_checklist, tui_confirm_prompt, _tui_read_key, _tui_render, _tui_enter_raw, _tui_restore, _tui_init_colors): PASS
- shellcheck -S warning: PASS
- test-bootstrap.sh: PASS=26 FAIL=0 (BACKCOMPAT-01)
- Smoke checks (source-ok, fail-closed, fixture-y): PASS
- No unexpected file deletions in commit

## Next Phase Readiness

- `tui.sh` API is stable and ready for Plan 24-03 (`dispatch.sh`) to source
- Plan 24-04 (`install.sh` orchestrator) can wire `tui_checklist` with the `TUI_LABELS/GROUPS/INSTALLED/DESCS` arrays populated from `detect2_cache` output
- `test-install-tui.sh` scaffold from Plan 01 (10 assertions) ready for Plan 04 to extend to ≥15

---

*Phase: 24-unified-tui-installer-centralized-detection*
*Completed: 2026-04-29*
