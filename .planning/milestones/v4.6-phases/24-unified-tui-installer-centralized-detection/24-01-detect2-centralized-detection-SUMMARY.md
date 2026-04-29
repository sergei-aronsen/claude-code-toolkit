---
phase: 24
plan: 01
subsystem: detection
tags: [bash, detection, lib, phase-24]
completed: "2026-04-29T10:43:26Z"

dependency_graph:
  requires: []
  provides:
    - scripts/lib/detect2.sh (is_superpowers_installed, is_gsd_installed, is_toolkit_installed, is_security_installed, is_rtk_installed, is_statusline_installed, detect2_cache)
    - scripts/tests/test-install-tui.sh (S1_detect, S2_detect scaffold)
  affects:
    - plans/24-02 (tui.sh consumes detect2.sh probes)
    - plans/24-03 (dispatch.sh sources detect2.sh)
    - plans/24-04 (install.sh sources detect2.sh; test-install-tui.sh extended to ≥15 assertions)

tech_stack:
  added: []
  patterns:
    - sourced-lib header with color guards (no errexit)
    - binary 0/1 probe return (D-22)
    - detect2_cache helper for D-23 mid-run drift recheck
    - hermetic sandbox test with mktemp + trap RETURN cleanup

key_files:
  created:
    - scripts/lib/detect2.sh
    - scripts/tests/test-install-tui.sh
  modified: []

decisions:
  - "D-21: detect2.sh sources detect.sh — does not duplicate SP/GSD logic"
  - "D-22: binary 0/1 return from every is_*_installed probe"
  - "D-23: detect2_cache helper provided for callers needing mid-run drift recheck"

metrics:
  duration: "~15 minutes"
  completed: "2026-04-29"
  tasks_completed: 3
  files_created: 2
  assertions_added: 10
---

# Phase 24 Plan 01: detect2 Centralized Detection Summary

**One-liner:** Six `is_*_installed` probe functions in a sourced lib that wraps detect.sh SP/GSD exports and adds four new filesystem+PATH probes (toolkit, security, rtk, statusline).

## What Was Built

### `scripts/lib/detect2.sh` — Centralized Detection v2 Library

New sourced library (no `set -euo pipefail`) that:

- Sources `scripts/detect.sh` at the top for HAS_SP / HAS_GSD (D-21 — no duplication)
- Exposes six `is_*_installed` functions returning binary 0/1 (D-22):
  - `is_superpowers_installed` — wraps `HAS_SP` from detect.sh
  - `is_gsd_installed` — wraps `HAS_GSD` from detect.sh
  - `is_toolkit_installed` — `[[ -f $HOME/.claude/toolkit-install.json ]]` (DET-05)
  - `is_security_installed` — `command -v cc-safety-net` AND grep in pre-bash.sh OR settings.json (DET-02, fixes v4.4 brew-install miss)
  - `is_rtk_installed` — `command -v rtk` (DET-04)
  - `is_statusline_installed` — `[[ -f $HOME/.claude/statusline.sh ]]` AND grep `"statusLine"` in settings.json (DET-03)
- Exposes `detect2_cache` helper that populates `IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL` (D-23)

### `scripts/tests/test-install-tui.sh` — Hermetic Detection Test Scaffold

New test file seeded with two detection scenarios:

- **S1_detect**: clean HOME sandbox — all six probes return 1 (not installed)
- **S2_detect**: populated HOME sandbox — DET-02/03/04/05 positive conditions satisfied, probes return 0

10 assertions total. Plan 04 extends to ≥15 for TUI-07 requirement.

## Verification Results

```text
test-install-tui complete: PASS=10 FAIL=0
Bootstrap test complete: PASS=26 FAIL=0  (BACKCOMPAT-01 invariant)
shellcheck clean on both files
```

## Decisions Implemented

| Decision | Description |
|----------|-------------|
| D-21 | detect2.sh sources detect.sh once — SP/GSD logic not duplicated |
| D-22 | Every is_*_installed returns binary 0 (installed) or 1 (not installed) |
| D-23 | detect2_cache helper provided for callers needing startup cache + mid-run drift recheck |

## Requirements Addressed

| REQ-ID | Description | Status |
|--------|-------------|--------|
| DET-01 | SP/GSD detection wrappers around detect.sh exports | Done |
| DET-02 | cc-safety-net + hook wiring probe (fixes v4.4 brew-install miss) | Done |
| DET-03 | statusline.sh + settings.json statusLine key probe | Done |
| DET-04 | command -v rtk PATH probe | Done |
| DET-05 | toolkit-install.json existence probe | Done |

## Downstream Contract

- Plans 24-02 (`tui.sh`) and 24-03 (`dispatch.sh`) source `scripts/lib/detect2.sh` via `source "$(dirname "${BASH_SOURCE[0]}")/detect2.sh"`
- Plan 24-04 (`install.sh` + tests) extends `test-install-tui.sh` with TUI keystroke scenarios (S3+) to reach ≥15 total assertions
- `detect2_cache` is the recommended entry point for `install.sh` startup — call once, then re-probe before each dispatch (D-23)

## Commit

`cc58679` — feat(24): add lib/detect2.sh centralized is_*_installed wrapper

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `scripts/lib/detect2.sh` exists: FOUND
- `scripts/tests/test-install-tui.sh` exists: FOUND
- Commit `cc58679` exists: FOUND
- No unexpected file deletions in commit
- shellcheck clean
- test-install-tui.sh: PASS=10 FAIL=0
- test-bootstrap.sh: PASS=26 FAIL=0
