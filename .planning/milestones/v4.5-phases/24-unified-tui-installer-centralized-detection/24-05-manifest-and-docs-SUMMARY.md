---
phase: 24-unified-tui-installer-centralized-detection
plan: "05"
subsystem: manifest
tags: [manifest, docs, distribution, tui, backcompat, phase-24]

dependency_graph:
  requires:
    - phase: 24-01
      provides: scripts/lib/detect2.sh
    - phase: 24-02
      provides: scripts/lib/tui.sh
    - phase: 24-03
      provides: scripts/lib/dispatch.sh
    - phase: 24-04
      provides: scripts/install.sh
  provides:
    - "manifest.json wires 3 new libs + 1 new script for smart-update auto-discovery"
    - "docs/INSTALL.md documents install.sh flag set + TUI controls for users"
  affects: [phase-25, phase-26, phase-27]

tech-stack:
  added: []
  patterns:
    - "manifest.json files.libs[] alphabetical sort order (detect2, dispatch, tui slot in correctly)"
    - "docs/INSTALL.md H2 section + H3 subsections pattern for new entry points (mirrors existing v4.4 structure)"

key-files:
  created: []
  modified:
    - manifest.json
    - docs/INSTALL.md

key-decisions:
  - "D-31: install.sh flags documented alongside (not replacing) init-claude.sh flags in INSTALL.md"
  - "Manifest version NOT bumped to 4.5.0 in Phase 24 — deferred to Phase 27 distribution phase per CONTEXT.md Deferred Ideas"
  - "libs[] entries sorted alphabetically; detect2 after bootstrap, dispatch after detect2, tui after state"
  - "scripts[] is order-preserving — install.sh appended after uninstall.sh (not alpha-sorted)"

patterns-established:
  - "New libs auto-discover via existing update-claude.sh jq path (.files | to_entries[] | .value[] | .path) with zero code changes (LIB-01 D-07)"
  - "INSTALL.md section insertion: new H2 sits AFTER existing flag subsections, BEFORE Mode: standalone, with its own closing --- separator"

requirements-completed: [BACKCOMPAT-01, TUI-07]

duration: 10min
completed: 2026-04-29
---

# Phase 24 Plan 05: Manifest and Docs Summary

**manifest.json wired with 4 new entries (install.sh + lib/{detect2,dispatch,tui}.sh) enabling smart-update auto-discovery; docs/INSTALL.md gains install.sh (unified entry, v4.5+) section with flag table, TUI controls, and BACKCOMPAT-01 note**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-29T11:20Z
- **Completed:** 2026-04-29
- **Tasks:** 3 (Task 1: manifest edits, Task 2: docs edit, Task 3: verify + commit)
- **Files modified:** 2

## Accomplishments

- `manifest.json` gains 4 entries: `scripts/install.sh` in `files.scripts[]` and `scripts/lib/{detect2,dispatch,tui}.sh` in `files.libs[]` (alphabetically sorted); `test-update-libs.sh` 15 assertions stay green confirming zero-special-casing auto-discovery invariant (LIB-01 D-07)
- `docs/INSTALL.md` gains `## install.sh (unified entry, v4.5+)` section (4 H3 subsections: Quick start, Flags, TUI controls, Backwards compatibility) documenting all 8 flags and TUI key bindings; markdownlint passes
- All existing v4.4 sections in INSTALL.md unchanged — D-31 invariant maintained; `test-bootstrap.sh` 26 assertions still green (BACKCOMPAT-01)

## Task Commits

All changes landed in one atomic commit (Tasks 1-3 combined per plan spec):

1. **Tasks 1-3: manifest + docs + verify** - `a426188` (docs)

## Files Created/Modified

- `manifest.json` — Added `scripts/install.sh` to `files.scripts[]`; added `scripts/lib/{detect2,dispatch,tui}.sh` to `files.libs[]` in alphabetical sort order
- `docs/INSTALL.md` — Added `## install.sh (unified entry, v4.5+)` section with Quick start, Flags table (8 flags), TUI controls table, and Backwards compatibility note

## Decisions Made

- Manifest version left at 4.4.0 — version bump to 4.5.0 is deferred to Phase 27 distribution phase per CONTEXT.md "Deferred Ideas"; `make validate` confirms `version-aligned: 4.4.0`
- `scripts[]` array is order-preserving (append after `uninstall.sh`), not alpha-sorted — matches existing project convention for additive entries in that array
- `libs[]` array is alpha-sorted — `detect2.sh` after `bootstrap.sh`, `dispatch.sh` after `detect2.sh`, `tui.sh` after `state.sh`

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 24 distribution side complete: all 4 new files (`tui.sh`, `detect2.sh`, `dispatch.sh`, `install.sh`) are registered in `manifest.json` for smart-update coverage
- Phase 25 (MCP Selector) can build on `detect2.sh` / `tui.sh` / `dispatch.sh` foundation; manifest pattern established
- `docs/INSTALL.md` pattern established for documenting new entry points alongside existing ones

## Threat Flags

None — `manifest.json` and `docs/INSTALL.md` are read-only data files (no code execution from manifest content; docs contain only public GitHub URLs).

---

*Phase: 24-unified-tui-installer-centralized-detection*
*Completed: 2026-04-29*

## Self-Check: PASSED

- manifest.json: FOUND
- docs/INSTALL.md: FOUND
- 24-05-manifest-and-docs-SUMMARY.md: FOUND
- Commit a426188: FOUND
- manifest.json libs[] contains detect2.sh, dispatch.sh, tui.sh: CONFIRMED
- manifest.json scripts[] contains install.sh: CONFIRMED
- docs/INSTALL.md contains `## install.sh (unified entry, v4.5+)`: CONFIRMED
