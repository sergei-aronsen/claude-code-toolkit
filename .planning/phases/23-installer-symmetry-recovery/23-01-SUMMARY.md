---
phase: 23-installer-symmetry-recovery
plan: "01"
subsystem: installer-scripts
tags: [banner, no-banner, flag-parity, init-claude, init-local, test-extension]
dependency_graph:
  requires: []
  provides: [BANNER-01]
  affects: [scripts/init-claude.sh, scripts/init-local.sh, scripts/tests/test-install-banner.sh]
tech_stack:
  added: []
  patterns: [NO_BANNER=0 boolean flag, if [[ $NO_BANNER -eq 0 ]] gate, while/$# argparse with shift]
key_files:
  created: []
  modified:
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/tests/test-install-banner.sh
decisions:
  - "Used single-line --no-banner) NO_BANNER=1; shift ;; clause form in both init scripts so grep pattern '--no-banner) NO_BANNER=1' matches (plan A5 assertion requires it)"
  - "Added shellcheck disable=SC2016 on A6/A7 grep lines — single quotes are intentional to match literal $NO_BANNER in source files"
  - "D-06 assumption in CONTEXT.md was wrong: init-local.sh already has --help block at HEAD, so --no-banner was added to both Usage line and help-line block (R-05)"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-27"
  tasks_completed: 3
  files_modified: 3
---

# Phase 23 Plan 01: --no-banner Symmetry for Init Scripts Summary

BANNER-01 closed: both init-claude.sh and init-local.sh now honour `--no-banner` (and `NO_BANNER=1` env) to suppress the closing "To remove: bash <(curl ...)" line — symmetric with update-claude.sh, which already supported this flag.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add `--no-banner` to `scripts/init-claude.sh` | 22bff25 | scripts/init-claude.sh |
| 2 | Add `--no-banner` to `scripts/init-local.sh` | f83ae7f | scripts/init-local.sh |
| 3 | Extend `test-install-banner.sh` with A4-A7 | e5905ec | scripts/tests/test-install-banner.sh |

## What Was Built

### scripts/init-claude.sh (+6 lines, -2 lines)

Four surgical changes per D-01:

1. `NO_BANNER=0` default declaration inserted after `DRY_RUN=false` (line 21)
2. `--no-banner) NO_BANNER=1; shift ;;` argparse clause inserted after `--no-bootstrap` clause
3. `--no-banner` appended to the Flags error string
4. Banner echo wrapped: `if [[ $NO_BANNER -eq 0 ]]; then echo "To remove: ..."; fi`

### scripts/init-local.sh (+7 lines, -2 lines)

Five surgical changes per D-01 + R-05:

1. `NO_BANNER=0` default declaration inserted after `NO_BOOTSTRAP=false` (line 84)
2. `--no-banner) NO_BANNER=1; shift ;;` argparse clause inserted after `--no-bootstrap` clause
3. `[--no-banner]` appended to Usage line in `--help` block
4. `--no-banner` help line inserted after `--no-bootstrap` in the `--help` options block
5. Banner echo (last line of file) wrapped: `if [[ $NO_BANNER -eq 0 ]]; then echo "To remove: ..."; fi` — file now ends with `fi` (R-08)

### scripts/tests/test-install-banner.sh (+42 lines, -2 lines)

- Header comment updated: "Assertions (3 total)" -> "Assertions (7 total)", A4-A7 listed
- Exit comment updated: "all 3 assertions passed" -> "all 7 assertions passed"
- Four new source-grep assertions inserted after A3:
  - **A4**: `init-claude.sh` defines `NO_BANNER=0` default (`^NO_BANNER=0`)
  - **A5**: `init-claude.sh` argparse contains `--no-banner) NO_BANNER=1` clause
  - **A6**: `init-claude.sh` banner gated by `if [[ $NO_BANNER -eq 0 ]]` (R-04 direction-pin)
  - **A7**: `init-local.sh` has all three patterns combined in single assertion
- `shellcheck disable=SC2016` added to A6 and A7 grep lines (SC2016 fires on intentional single-quoted `$NO_BANNER` literal patterns)

## Verification Results

All verification commands from plan passed:

```text
bash scripts/tests/test-install-banner.sh  — 7/7 assertions PASS
shellcheck scripts/init-claude.sh          — PASS
shellcheck scripts/init-local.sh           — PASS
shellcheck scripts/tests/test-install-banner.sh — PASS
D-02 banner count=1 in all 3 installers   — PASS
bash scripts/init-local.sh --help | grep --no-banner — PASS
bash scripts/init-claude.sh --unknown-arg | grep --no-banner — PASS (Flags string)
make check                                 — PASS (shellcheck + markdownlint + validate)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SC2016 shellcheck warning on intentional single-quoted $NO_BANNER patterns**

- **Found during:** Task 3 (shellcheck on test-install-banner.sh)
- **Issue:** SC2016 reports "Expressions don't expand in single quotes" on `grep -q 'if \[\[ \$NO_BANNER -eq 0 \]\]'` — but the single quotes are intentional (we're searching for the literal string `$NO_BANNER` in source code)
- **Fix:** Added `# shellcheck disable=SC2016` comment above the A6 and A7 grep lines with explanation
- **Files modified:** scripts/tests/test-install-banner.sh
- **Commit:** e5905ec (included in Task 3 commit)

**2. [Rule 2 - Missing functionality] --no-banner added to --help block in init-local.sh**

- **Found during:** Task 2 research (CONTEXT.md D-06 assumption was wrong)
- **Issue:** CONTEXT.md D-06 said "If init-local.sh lacks a --help block, do NOT add one." At HEAD, init-local.sh already has a full --help block at lines 107-121. The plan's interfaces section (R-05) explicitly calls this out as a required correction.
- **Fix:** Added --no-banner to both the Usage line and the options help-line block per R-05 guidance
- **Files modified:** scripts/init-local.sh
- **Commit:** f83ae7f (part of Task 2)

**3. [Rule 1 - Format] --no-banner) clause uses single-line form**

- **Found during:** Task 1 verification (grep pattern mismatch)
- **Issue:** Initial implementation used multi-line form (--no-banner) on one line, NO_BANNER=1 on next). The plan's acceptance criteria and test assertion A5 grep for `'--no-banner) NO_BANNER=1'` — both tokens on the same line.
- **Fix:** Changed to single-line form `--no-banner) NO_BANNER=1; shift ;;` matching the plan's `key_links.via` pattern. Applied same form to init-local.sh from the start.
- **Files modified:** scripts/init-claude.sh, scripts/init-local.sh
- **Commits:** 22bff25, f83ae7f

## Known Stubs

None — all banner conditional logic is fully wired and verified by source-grep assertions.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. The `--no-banner` flag is a boolean with integer comparison only; threat model T-23-01-01 through T-23-01-04 all accepted with ZERO surface (see plan threat_model).

## Notes for Downstream Plans

- Plan 23-02 (KEEP-01) and Plan 23-03 (KEEP-02) are independent — no banner-related coupling
- No CHANGELOG.md update in this plan (consolidated into Plan 23-03 along with KEEP-01/KEEP-02 bullets per D-18)
- No docs/INSTALL.md update in this plan (consolidated into Plan 23-03 per D-18)
- Test 25 (`test-install-banner.sh`) now runs 7 assertions instead of 3

## Regression Commands

```bash
bash scripts/tests/test-install-banner.sh
shellcheck scripts/init-claude.sh scripts/init-local.sh scripts/tests/test-install-banner.sh
BANNER='To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)'
[ "$(grep -cF "$BANNER" scripts/init-claude.sh)" -eq 1 ]
[ "$(grep -cF "$BANNER" scripts/init-local.sh)" -eq 1 ]
bash scripts/init-local.sh --help 2>&1 | grep -q -- '--no-banner'
bash scripts/init-claude.sh --unknown-arg 2>&1 | grep -q -- '--no-banner'
make check
```

## Self-Check: PASSED

All files and commits verified:

- FOUND: scripts/init-claude.sh
- FOUND: scripts/init-local.sh
- FOUND: scripts/tests/test-install-banner.sh
- FOUND: .planning/phases/23-installer-symmetry-recovery/23-01-SUMMARY.md
- FOUND commit 22bff25 (Task 1)
- FOUND commit f83ae7f (Task 2)
- FOUND commit e5905ec (Task 3)
