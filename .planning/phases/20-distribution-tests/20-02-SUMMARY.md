---
phase: 20-distribution-tests
plan: "02"
subsystem: installers + tests
tags:
  - distribution
  - banners
  - installers
  - tests
dependency_graph:
  requires:
    - "20-01"
  provides:
    - UN-07 banner portion (all 3 installers carry locked banner echo)
    - Test 25 banner gate (Makefile wired)
  affects:
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/update-claude.sh
    - scripts/tests/test-install-banner.sh
    - Makefile
tech_stack:
  added: []
  patterns:
    - source-grep gate (grep -cF count-mode, not quiet-mode)
    - NO_BANNER guard block (update-claude.sh parity with legacy header banner)
key_files:
  created:
    - scripts/tests/test-install-banner.sh
  modified:
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/update-claude.sh
    - Makefile
decisions:
  - "D-06: banner string is byte-identical across all 3 installers — single BANNER= variable in test is the canonical source-of-truth"
  - "D-07: update-claude.sh new echo wrapped in its own if [[ $NO_BANNER -eq 0 ]]; then...fi — Restart Claude Code line remains unconditional"
  - "D-08: init-claude.sh and init-local.sh have no NO_BANNER variable — banner echo is unconditional in both"
  - "D-09: test uses grep -cF (count-mode, exactly 1) not grep -q (quiet) — catches accidental duplication"
metrics:
  duration: "~3 minutes"
  completed_date: "2026-04-26"
  tasks_completed: 5
  files_changed: 5
  commits: 5
---

# Phase 20 Plan 02: Installer Banner + Test 25 Gate Summary

**One-liner:** Byte-identical `To remove:` uninstall banner added to all 3 installers, gated by Test 25 source-grep using `grep -cF` count assertion.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add banner to init-claude.sh | db7d01b | scripts/init-claude.sh |
| 2 | Add banner to init-local.sh | 7ba8632 | scripts/init-local.sh |
| 3 | Add NO_BANNER-guarded banner to update-claude.sh | 1846b63 | scripts/update-claude.sh |
| 4 | Create test-install-banner.sh | ffba55d | scripts/tests/test-install-banner.sh |
| 5 | Wire Test 25 in Makefile | 9f6d1ed | Makefile |

## Verification Results

All 7 plan verification criteria passed simultaneously at HEAD:

1. `grep -cF "$BANNER" scripts/init-claude.sh` = **1**
2. `grep -cF "$BANNER" scripts/init-local.sh` = **1**
3. `grep -cF "$BANNER" scripts/update-claude.sh` = **1**
4. `bash scripts/tests/test-install-banner.sh` = **0 (3/3 assertions pass)**
5. `make test` = **0 (all tests 1-23 + Test 25 pass)**
6. `make check` = **0 (lint + validate + version-align green)**
7. `bash scripts/init-local.sh --version` = **4.3.0** (auto-derived from Plan 01's manifest bump)

## Key Implementation Notes

### Banner String (byte-identical across all 3 installers)

```text
To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)
```

All three installers use plain `echo` (no `-e`, no `${YELLOW}`/`${NC}` ANSI wrappers, no quotes around the URL). This ensures `grep -cF` in the test matches the source line exactly.

### NO_BANNER Guard in update-claude.sh (D-07)

The banner echo in `update-claude.sh` is wrapped in its own `if [[ $NO_BANNER -eq 0 ]]; then ... fi` block appended after the existing final Restart Claude Code line. The Restart echo remains unconditional — matching prior behavior. The new guard provides parity with the legacy header banner suppression at lines 433-438.

### init-claude.sh and init-local.sh (D-08)

Neither script has a `NO_BANNER` variable. Both banner echoes are unconditional. No `--no-banner` flag was added to either script.

### Test 25 Source-Grep Gate (D-09)

`test-install-banner.sh` uses `grep -cF "$BANNER"` (count-mode, fixed-string) and asserts `count -eq 1` for each installer. Count-mode (not quiet-mode) catches accidental duplication — a second copy would produce `count=2`, failing the assertion. A missing file produces `count=0` via `|| true` + `count=${count:-0}` coercion, also failing the assertion with a clear error message.

### Makefile Test Slot Ordering

The Makefile slot ordering is temporarily **23 → 25 → All tests passed**. The gap between 23 and 25 is intentional — Plan 03 (Wave 3) will insert Test 24 (round-trip integration) between them, yielding the final order 23 → 24 → 25 → All tests passed.

### init-local.sh --version (auto-derived)

No version string edit was needed in `init-local.sh`. It reads version from `manifest.json` at runtime (lines 17-23). Plan 01 already bumped `manifest.json` to `4.3.0`, so `bash scripts/init-local.sh --version` returns `4.3.0` automatically.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All banner lines are wired directly; test assertions are live source-greps against real installer files.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The three new `echo` lines emit text to stdout only. The test file reads installer sources via `grep -cF` (read-only). No new threat surface beyond what the plan's threat model already covers.

## Self-Check: PASSED

Files created/modified:

- [x] `scripts/init-claude.sh` — banner echo present, POST_INSTALL.md callout is last line
- [x] `scripts/init-local.sh` — banner echo is last line, version = 4.3.0
- [x] `scripts/update-claude.sh` — banner wrapped in NO_BANNER guard after Restart line
- [x] `scripts/tests/test-install-banner.sh` — mode 0755, shellcheck clean, 3/3 pass
- [x] `Makefile` — Test 25 block TAB-indented, `make test` green

Commits verified:

- [x] db7d01b — feat(20-02): add uninstall banner to init-claude.sh
- [x] 7ba8632 — feat(20-02): add uninstall banner to init-local.sh
- [x] 1846b63 — feat(20-02): add NO_BANNER-guarded uninstall banner to update-claude.sh
- [x] ffba55d — feat(20-02): add test-install-banner.sh — 3-assertion source-grep gate
- [x] 9f6d1ed — feat(20-02): wire Test 25 banner gate in Makefile
