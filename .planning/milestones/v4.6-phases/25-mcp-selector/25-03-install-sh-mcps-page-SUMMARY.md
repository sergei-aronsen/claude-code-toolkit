---
phase: 25
plan: "03"
subsystem: install-sh-mcps-page
tags: [bash, install, tui, mcp, dispatch, phase-25]
dependency_graph:
  requires:
    - scripts/lib/mcp.sh (Plans 01 + 02 — catalog loader, wizard)
    - scripts/lib/tui.sh (Phase 24 — tui_checklist, tui_confirm_prompt)
    - scripts/lib/dispatch.sh (Phase 24 — dispatch loop pattern)
  provides:
    - scripts/install.sh (--mcps flag + MCP page routing)
    - scripts/lib/mcp.sh (mcp_status_array helper)
  affects:
    - scripts/install.sh (routing gate, print_install_status moved up)
    - scripts/lib/mcp.sh (dry-run early-out moved before secrets collection)
tech_stack:
  added:
    - mcp_status_array function in mcp.sh (51 lines)
    - --mcps routing branch in install.sh (~163 lines added)
  patterns:
    - Mutex routing gate: --mcps takes MCP page; default flow unchanged (BACKCOMPAT-01)
    - Three-state TUI_INSTALLED mapping: is_mcp_installed 0→1, 1→0, 2→0+[unavailable] prefix
    - MCP_CLI_PRESENT global distinguishes "all probes returned 2" from "at least one probe succeeded"
    - D-08 continue-on-error + D-28 stderr-tail pattern mirrored from Phase 24 dispatch loop
    - dry-run early-out moved before secrets collection in mcp_wizard_run (non-interactive)
key_files:
  created: []
  modified:
    - scripts/install.sh
    - scripts/lib/mcp.sh
decisions:
  - "print_install_status moved from line ~277 to before the MCP routing gate (after detect2_cache) — pure refactor enabling both MCP branch and components branch to call the same function"
  - "dry-run early-out in mcp_wizard_run moved BEFORE secrets collection loop — makes --dry-run fully non-interactive (no TTY required); overrides STATE.md decision 'secrets collected even in dry-run'"
  - "--mcps mutex: components page skipped entirely when --mcps is set; exit 0/1 at end of MCP branch prevents components code from executing"
  - "OAuth-only MCPs skipped by --yes default-set unless --force (OAuth requires browser interaction incompatible with non-interactive mode)"
  - "MCP_CLI_PRESENT=0 (all probes returned 2) triggers CLI-absent banner before TUI render; catalog still rendered for browse mode"
metrics:
  duration_seconds: 780
  completed_date: "2026-04-29"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 25 Plan 03: install.sh MCPs Page Summary

**One-liner:** `--mcps` flag added to `install.sh` with mutex routing to a 9-MCP TUI catalog page backed by `mcp_status_array`; per-MCP dispatch loop mirrors Phase 24 D-08/D-28 continue-on-error pattern; BACKCOMPAT-01 preserved (38+26 assertions green).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add mcp_status_array helper to scripts/lib/mcp.sh | c21cad3 | scripts/lib/mcp.sh |
| 2 | Add --mcps flag and routing branch to scripts/install.sh | e58f29e | scripts/install.sh, scripts/lib/mcp.sh |

## Insertion Point

The `--mcps` routing gate lands at **line 168** of the final `install.sh` (622 lines total), immediately after:

1. `detect2_cache` call (line 145)
2. `print_install_status` function definition (lines 152–161, moved up from original line ~277)

The MCP branch runs lines 168–331 and always terminates with `exit 0` or `exit 1`, so the Phase 24 components page (lines 336+) is unreachable when `--mcps` is set.

## print_install_status Refactor

`print_install_status` was moved **up** from its original position (~line 277 in the Phase 24 file) to line 152, before the MCP routing gate. This is a pure refactor — no logic changed, no behavior change for the components flow. Both the MCP branch and the components branch now call the same function defined once. The old definition was removed.

## Final Line Counts

| File | Phase 24 baseline | After Plan 03 |
|------|-------------------|---------------|
| scripts/install.sh | 440 | 622 (+182) |
| scripts/lib/mcp.sh | 433 (after Plans 01+02) | 486 (+53) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Moved dry-run early-out before secrets collection in mcp_wizard_run**

- **Found during:** Task 2 verification
- **Issue:** `mcp_wizard_run` collected API keys via TTY BEFORE the `--dry-run` early-out check. This caused `--mcps --dry-run --yes` to fail when no TTY was available (wizard tried `read -rsp` from `/dev/tty`, got empty input 3 times, returned exit 1 for each API-key MCP).
- **Fix:** Moved the dry-run early-out to immediately after `install_args` reconstruction and BEFORE the secrets collection loop. `--dry-run` is now fully non-interactive — no TTY, no env file writes, no API key prompts.
- **Overrides:** STATE.md decision "dry-run skips only claude mcp add — secrets collection runs even in dry-run mode". The correct behavior is: dry-run is a preview mode and must not prompt for secrets.
- **Files modified:** scripts/lib/mcp.sh
- **Commits:** e58f29e

## Verification Results

All plan verification criteria pass:

```text
shellcheck -S warning scripts/install.sh scripts/lib/mcp.sh   → 0 warnings
bash scripts/tests/test-install-tui.sh                        → PASS=38 FAIL=0
bash scripts/tests/test-bootstrap.sh                          → PASS=26 FAIL=0

Inline verify Test 1: --mcps --yes --dry-run prints MCP install summary + would-install rows  → PASS
Inline verify Test 2: --mcps --yes (no CLI) prints "claude CLI not found" banner              → PASS
Inline verify Test 3: default (no --mcps) shows "Install summary", not "MCP install summary" → PASS
```

## Known Stubs

None — all 9 MCPs are wired to real catalog entries; the dispatch loop calls `mcp_wizard_run` for real. The TUI renders actual `is_mcp_installed` detection state.

## Threat Flags

None — no new network endpoints or auth paths introduced. The `--mcps` flag routes to existing `mcp_wizard_run` (already audited in Plan 02). The dry-run path makes zero writes to disk.

## Self-Check: PASSED

- [x] scripts/install.sh exists and contains `--mcps`: FOUND
- [x] scripts/lib/mcp.sh contains `mcp_status_array`: FOUND
- [x] Commit c21cad3 exists: FOUND
- [x] Commit e58f29e exists: FOUND
- [x] test-install-tui.sh PASS=38 FAIL=0: VERIFIED
- [x] test-bootstrap.sh PASS=26 FAIL=0: VERIFIED
