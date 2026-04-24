---
phase: 09-backup-detection
plan: 02
subsystem: cli
tags: [backup, warning, shell, update-claude, migrate-to-complement, bash-unit-tests]

requires:
  - phase: 09-backup-detection
    plan: 01
    provides: scripts/lib/backup.sh with warn_if_too_many_backups() already implemented

provides:
  - warn_if_too_many_backups() wired into update-claude.sh after successful backup creation
  - warn_if_too_many_backups() wired into migrate-to-complement.sh after successful backup creation
  - backup.sh sourced in migrate-to-complement.sh via LIB_BACKUP_TMP + lib-loop pattern
  - scripts/tests/test-backup-threshold.sh: 4-scenario, 6-assertion BACKUP-02 test suite

affects:
  - 09-03, 09-04 (none — BACKUP-02 is informational output only, no interface changes)

tech-stack:
  added: []
  patterns:
    - warn_if_too_many_backups call-after-log_success pattern (D-11)
    - lib sourcing loop extension for backup.sh in migrate-to-complement.sh
    - isolated HOME subshell for unit-testing sourced lib functions

key-files:
  created:
    - scripts/tests/test-backup-threshold.sh
  modified:
    - scripts/update-claude.sh
    - scripts/migrate-to-complement.sh

key-decisions:
  - "setup-security.sh explicitly excluded per RESEARCH.md audit — it creates .bak.* files only, never sibling .claude-backup-* dirs; test locks this in with a negative grep assertion"
  - "scenario_migrate_warns uses HAS_SP=true + TK_MIGRATE_SP_CACHE_DIR + seeded duplicate file to reach the backup block — HAS_SP=false causes early exit before backup creation"
  - "Unit scenarios (boundary-10-silent, trigger-11-warns) drive warn_if_too_many_backups directly via HOME=<sandbox> subshell rather than full update-claude.sh run — faster and isolated"

patterns-established:
  - "HOME=<sandbox> subshell pattern: HOME='$SCR' bash -c 'source lib; fn' for sourced-lib unit tests"
  - "seed_backup_dirs helper: creates .claude-backup-<epoch>-<n> dirs with fixed base epoch for reproducible counts"

requirements-completed:
  - BACKUP-02

duration: 20min
completed: 2026-04-24
---

# Phase 9 Plan 02: BACKUP-02 Threshold Warning Call Sites Summary

**Non-fatal ⚠ threshold warning wired into both backup-creating scripts (update-claude.sh + migrate-to-complement.sh) via centralized warn_if_too_many_backups() from scripts/lib/backup.sh**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-24T18:05:00Z
- **Completed:** 2026-04-24T18:25:00Z
- **Tasks:** 1
- **Files modified:** 3 (2 modified scripts, 1 new test file)

## Accomplishments

- Wired `warn_if_too_many_backups` into `update-claude.sh` on the line immediately after
  `log_success "Backup created: $BACKUP_DIR"` — the function was already in scope via the
  `backup.sh:$LIB_BACKUP_TMP` entry added by Plan 09-01 Task 2
- Added `LIB_BACKUP_TMP` mktemp declaration + trap cleanup + `backup.sh` to the lib sourcing loop
  in `migrate-to-complement.sh`, then wired the call after its backup creation success line
- Created `scripts/tests/test-backup-threshold.sh` with 4 scenarios covering all 3 VALIDATION.md
  rows (9-02-01..03) plus the setup-security.sh exclusion audit; all 6 assertions pass

## Task Commits

1. **Task 1: Wire warn_if_too_many_backups + create test-backup-threshold.sh** - `d35559b` (feat)

## Files Created/Modified

- `scripts/update-claude.sh` — `warn_if_too_many_backups` call after backup creation (~line 572)
- `scripts/migrate-to-complement.sh` — `LIB_BACKUP_TMP` mktemp + trap + backup.sh in lib loop + call after backup creation
- `scripts/tests/test-backup-threshold.sh` — 4-scenario BACKUP-02 test suite (6 assertions)

## Decisions Made

- `scenario_migrate_warns` requires `HAS_SP=true` + `TK_MIGRATE_SP_CACHE_DIR` + seeded duplicate
  file to reach the backup block; `HAS_SP=false` causes an "nothing to migrate" early exit at
  line 220 before backup creation. This is correct behavior, not a bug.
- Unit scenarios drive `warn_if_too_many_backups` directly via `HOME=<sandbox> bash -c 'source lib; fn'`
  rather than full `update-claude.sh` runs. This keeps BACKUP-02 unit tests focused, fast, and
  independent of the update flow complexity. The migrate integration test provides end-to-end
  coverage for the full call chain.
- `setup-security.sh` exclusion is locked via a negative grep assertion in the test file,
  ensuring the RESEARCH.md D-28 audit finding cannot be silently violated by future changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] scenario_migrate_warns initial sandbox insufficient**

- **Found during:** Task 1 (test execution — migrate scenario)
- **Issue:** Initial `scenario_migrate_warns` used `HAS_SP=false` which caused migrate to exit 0
  at "No duplicate files found" before reaching the backup block, so the threshold warning was
  never emitted
- **Fix:** Switched to `HAS_SP=true` + `TK_MIGRATE_SP_CACHE_DIR` + seeded duplicate file +
  `seed_migrate_standalone_state` helper to produce a scenario that genuinely reaches backup creation
- **Files modified:** `scripts/tests/test-backup-threshold.sh`
- **Verification:** `bash scripts/tests/test-backup-threshold.sh` exits 0, PASS=6 FAIL=0
- **Committed in:** d35559b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — test scenario bug)
**Impact on plan:** Fix was necessary for test correctness. No scope creep.

## Issues Encountered

None beyond the scenario-seeding deviation above.

## setup-security.sh Audit Confirmation

`scripts/setup-security.sh` was inspected and confirmed untouched per RESEARCH.md audit. It does
not create sibling `.claude-backup-*` directories — it only calls `backup_settings_once()` from
`lib/install.sh` which creates `~/.claude/settings.json.bak.<epoch>`. The `scenario_setup_security_excluded`
test assertion locks this finding permanently.

## Known Stubs

None — all behavior is fully implemented.

## Threat Flags

None — this plan introduces only informational terminal output. No new network endpoints,
auth paths, file access patterns, or destructive operations (T-9-B2-01 disposition: accept,
per plan threat model).

## Branch

`feature/backup-02-threshold-warning` (per D-30)

## Next Phase Readiness

- BACKUP-02 complete; threshold warning fires from both callers
- Plan 09-03 (DETECT-06) already shipped (see git log); Plan 09-04 (DETECT-07) is next
- `scripts/lib/backup.sh` stable — no changes needed for remaining plans in Phase 9

## Self-Check

See below.

---

*Phase: 09-backup-detection*
*Completed: 2026-04-24*
