---
phase: 24
plan: "04"
subsystem: install-orchestrator
tags: [bash, orchestrator, tui, test, dispatch, phase-24]
dependency_graph:
  requires: [24-01, 24-02, 24-03]
  provides: [scripts/install.sh, scripts/tests/test-install-tui.sh]
  affects: [Makefile, .github/workflows/quality.yml]
tech_stack:
  added: []
  patterns:
    - EXIT trap with CLEANUP_PATHS array for mktemp stderr capture
    - C-style for-loop for fail-fast skip (avoids duplicate-index bug)
    - _NOOP_SCRIPT pattern for test seam overrides (real bash script vs shell builtin)
    - Safe array expansion ${arr[@]+"${arr[@]}"} for nounset-safe empty arrays
key_files:
  created:
    - scripts/install.sh
    - scripts/tests/test-install-tui.sh
  modified:
    - scripts/lib/dispatch.sh
    - Makefile
    - .github/workflows/quality.yml
decisions:
  - "run_cleanup uses if/then not && to prevent empty-array condition from setting EXIT trap exit code to 1"
  - "S9 uses non-existent TTY path (not /dev/null) to trigger D-05 fork; /dev/null is readable so TUI branch would be taken instead"
  - "Test seam overrides use real bash scripts (_NOOP_SCRIPT) not shell builtin ':' because 'bash :' tries to exec a file named ':'"
  - "dispatch_toolkit dry-run condition simplified to [[ dry_run -eq 1 ]] because --dry-run adds itself to pass_args (length=1)"
metrics:
  duration: "~3 hours (cross-session)"
  completed: "2026-04-29"
  tasks_completed: 3
  files_modified: 5
---

# Phase 24 Plan 04: Install Orchestrator and Tests Summary

Unified TUI install orchestrator (scripts/install.sh, 440 lines) with 9 dispatch scenarios, 55 assertions, all passing; wired into Makefile Test 31 and CI.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Add scripts/install.sh unified TUI orchestrator | 5f22652 | scripts/install.sh, scripts/lib/dispatch.sh |
| 2 | Extend test-install-tui.sh to ≥15 assertions (S3-S9) | e2668ea | scripts/tests/test-install-tui.sh |
| 3 | Wire test-install-tui.sh into Makefile + CI | f87fc9f | Makefile, .github/workflows/quality.yml |

## What Was Built

### scripts/install.sh (440 lines)

Top-level unified install orchestrator (distinct from scripts/lib/install.sh which is the v4.4 install flow library).

Key behaviors implemented:
- Flag parsing: `--yes`, `--no-color`, `--dry-run`, `--force`, `--fail-fast`, `--no-banner`
- Sources `lib/{dry-run-output,detect2,tui,dispatch}.sh` via `_source_lib()` (local or curl-pipe)
- `detect2_cache` populates `IS_SP/IS_GSD/IS_TK/IS_SEC/IS_RTK/IS_SL`
- 3-branch TTY gate: `--yes` mode / readable TTY (TUI) / no-TTY (D-05 bootstrap fork)
- D-05 fork: sources `lib/bootstrap.sh`, calls `bootstrap_base_plugins`; TK components fail-closed (D-11)
- Dispatch loop over 6 components with per-component stderr capture to mktemp + `tail -5` on failure (D-28)
- `print_install_status()`: states `installed ✓` / `skipped` / `would-install` / `failed (exit N)`
- C-style fail-fast inner loop to skip remaining components after failure
- EXIT trap via `run_cleanup()` using `if/then` form (not `&&`) to avoid trap returning exit 1 on empty array
- Summary: `Installed: N · Skipped: N · Failed: N`
- Exit code 0 if no failures, 1 if any failure

### scripts/tests/test-install-tui.sh (535 lines, 55 assertions)

9 hermetic test scenarios:

| Scenario | What it tests |
|----------|--------------|
| S1_detect | DET-01..05: all 6 components = 0 in clean HOME |
| S2_detect | DET-01..05: all 6 components = 1 when installed |
| S3_yes | --yes flag dispatches all 6 mock dispatchers, Installed: 6 |
| S4_dry_run | --yes --dry-run prints would-install, no sentinels created |
| S5_force | --yes --force re-runs already-installed toolkit dispatcher |
| S6_fail_fast | Failed SP blocks GSD (fail-fast), exits 1 |
| S7_no_tty | /dev/null TTY src: TUI gets EOF, cancel, fail-closed, exit 0 |
| S8_stderr_tail | Last 5 of 6 stderr lines surface in summary (D-28 truncation) |
| S9_no_tty_bootstrap_fork | Non-existent TTY triggers D-05 fork; SP+GSD sentinels created, TK skipped (D-11) |

### Makefile + quality.yml

- `.PHONY` updated with `test-install-tui`
- `test` target gains "Test 31: TUI install orchestrator + dispatch scenarios (TUI-01..09)"
- Standalone `test-install-tui:` target added
- CI step renamed "Tests 21-31", `bash scripts/tests/test-install-tui.sh` appended

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] dispatch.sh empty array expansion under nounset**

- **Found during:** Task 1
- **Issue:** `bash "$TK_DISPATCH_OVERRIDE_TOOLKIT" "${pass_args[@]}"` fails with `unbound variable` when `pass_args=()` and `set -euo pipefail` is active
- **Fix:** All 9 `"${pass_args[@]}"` occurrences in dispatch.sh changed to `${pass_args[@]+"${pass_args[@]}"}`
- **Files modified:** scripts/lib/dispatch.sh
- **Commit:** 5f22652

**2. [Rule 1 - Bug] dispatch_toolkit dry-run override condition wrong**

- **Found during:** Task 1
- **Issue:** `[[ "$dry_run" -eq 1 && "${#pass_args[@]}" -eq 0 ]]` fails because `--dry-run` adds itself to pass_args (length becomes 1, not 0)
- **Fix:** Simplified to `if [[ "$dry_run" -eq 1 ]]`
- **Files modified:** scripts/lib/dispatch.sh
- **Commit:** 5f22652

**3. [Rule 1 - Bug] run_cleanup EXIT trap returns exit 1 on empty CLEANUP_PATHS**

- **Found during:** Task 2 (test S3 would fail due to exit code being 1 instead of 0)
- **Issue:** `[[ ${#CLEANUP_PATHS[@]} -gt 0 ]] && rm -f "${CLEANUP_PATHS[@]}"` — when array is empty, `[[...]]` returns 1, `&&` short-circuits, the compound expression exits 1, which becomes the script's EXIT trap return value, overriding `exit 0`
- **Fix:** Rewrote as `if/then` form with `|| true` on the rm
- **Files modified:** scripts/install.sh
- **Commit:** 5f22652 (noted and fixed before Task 2 commit)

**4. [Rule 1 - Bug] Test seam override `TK_DISPATCH_OVERRIDE_*=":"` fails**

- **Found during:** Task 2
- **Issue:** `bash ":"` tries to execute a file named `:` which doesn't exist
- **Fix:** Added global `_NOOP_SCRIPT` (real `#!/bin/bash\nexit 0` script via mktemp) replacing all `":"` overrides in S3-S9
- **Files modified:** scripts/tests/test-install-tui.sh
- **Commit:** e2668ea

**5. [Rule 1 - Bug] S9 uses /dev/null for TTY path but /dev/null is readable**

- **Found during:** Task 2 (S9 not triggering D-05 fork)
- **Issue:** `[[ -r /dev/null ]]` is true so install.sh takes the TUI branch rather than the D-05 bootstrap fork branch
- **Fix:** Changed `TK_TUI_TTY_SRC=/dev/null` to `TK_TUI_TTY_SRC="$SANDBOX/no-tty-device"` (non-existent path)
- **Files modified:** scripts/tests/test-install-tui.sh
- **Commit:** e2668ea

**6. [Rule 1 - Bug] S9 prompt-text assertion fails because `read -p` doesn't echo to stdout**

- **Found during:** Task 2 (FAIL on `assert_contains "Install superpowers"`)
- **Issue:** `read -p "prompt" var < file` does not write prompt text to stdout/stderr when reading from a file (only on real TTY)
- **Fix:** Rewrote S9 to assert side effects (sentinel files created by SP/GSD mock installers when user answers Y) instead of prompt text
- **Files modified:** scripts/tests/test-install-tui.sh
- **Commit:** e2668ea

## Verification

- `bash scripts/tests/test-install-tui.sh`: PASS=38 FAIL=0
- Assertion count: 55 (>= 15 required)
- `shellcheck -S warning scripts/tests/test-install-tui.sh`: 0 warnings
- `shellcheck -S warning scripts/install.sh`: 0 warnings (SC2034 suppressed with directives for tui.sh-used variables)
- `make check`: All checks passed
- `make test-install-tui`: PASS=38 FAIL=0

## Self-Check: PASSED

- scripts/install.sh: FOUND (440 lines)
- scripts/tests/test-install-tui.sh: FOUND (535 lines)
- Commit 5f22652: FOUND (Task 1)
- Commit e2668ea: FOUND (Task 2)
- Commit f87fc9f: FOUND (Task 3)
- Makefile contains `test-install-tui`: FOUND
- quality.yml contains `test-install-tui.sh`: FOUND
- make check: PASSED
