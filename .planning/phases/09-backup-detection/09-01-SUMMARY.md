---
phase: 09-backup-detection
plan: 01
subsystem: cli
tags: [backup, housekeeping, shell, update-claude, bash-unit-tests]

requires:
  - phase: 04-smart-update
    provides: update-claude.sh arg-parser and lib-sourcing infrastructure

provides:
  - scripts/lib/backup.sh with list_backup_dirs() and warn_if_too_many_backups()
  - update-claude.sh --clean-backups / --keep=N / --dry-run flag dispatch
  - test-clean-backups.sh: 8 scenarios, 22 assertions covering BACKUP-01 spec
  - REQUIREMENTS.md BACKUP-01/02 wording aligned to real on-disk patterns (D-01 fix)

affects:
  - 09-02 (BACKUP-02): sources backup.sh for warn_if_too_many_backups() call sites

tech-stack:
  added: []
  patterns:
    - sourced-lib no-errexit contract (backup.sh follows state.sh and install.sh)
    - FIFO+stdin fallback pattern for interactive prompts in tests
    - find -maxdepth 1 + arithmetic wc -l coercion for BSD/GNU portable counts

key-files:
  created:
    - scripts/lib/backup.sh
    - scripts/tests/test-clean-backups.sh
    - scripts/tests/test-backup-lib.sh
    - scripts/tests/test-detect-cli.sh
  modified:
    - scripts/update-claude.sh
    - .planning/REQUIREMENTS.md

key-decisions:
  - "D-01 applied: REQUIREMENTS.md phantom path ~/.claude/.toolkit-backup-* replaced with real patterns in BACKUP-01, BACKUP-02, and section header"
  - "Prompt reads from /dev/tty first, falls back to stdin for FIFO-based test support while staying curl|bash safe"
  - "run_clean_backups dispatched after .claude existence check but before lock acquisition (line 378 vs 387)"
  - "list_backup_dirs takes optional HOME argument for sandbox isolation in tests"

patterns-established:
  - "FIFO stdin fallback: printf prompt to stdout + read from /dev/tty with stdin fallback when tty unavailable"
  - "Sourced lib contract: no set -euo pipefail at file level, color constants redeclared with shellcheck disable=SC2034"

requirements-completed:
  - BACKUP-01

duration: 35min
completed: 2026-04-24
---

# Phase 9 Plan 01: Backup Housekeeping Library Summary

**`--clean-backups` flag on update-claude.sh backed by scripts/lib/backup.sh library with list_backup_dirs() and warn_if_too_many_backups(), plus 22-assertion test suite**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-24T17:18:00Z
- **Completed:** 2026-04-24T17:53:44Z
- **Tasks:** 2
- **Files modified:** 5 (2 new scripts, 2 new tests, 1 modified script, 1 modified spec)

## Accomplishments

- Created `scripts/lib/backup.sh`: sourced library with `list_backup_dirs()` (newest-epoch-first
  output via sort -rn) and `warn_if_too_many_backups()` (threshold > 10, BSD/GNU portable)
- Wired `--clean-backups`, `--keep=N`, and `--dry-run` into `scripts/update-claude.sh` with
  `run_clean_backups()` dispatched before lock acquisition; backup.sh sourced via LIB_BACKUP_TMP
- Created `scripts/tests/test-clean-backups.sh` with 8 scenarios: empty-set, dry-run, prompt y/n,
  fail-closed, --keep=3, invalid --keep (negative and non-numeric), rm-scope safety
- Patched `REQUIREMENTS.md` BACKUP-01, BACKUP-02, and section header to remove phantom
  `~/.claude/.toolkit-backup-*` path and reference real on-disk patterns (D-01)

## Task Commits

1. **Task 1: Create scripts/lib/backup.sh and patch REQUIREMENTS.md** - `54e0d0a` (feat)
2. **Task 2: Wire --clean-backups into update-claude.sh + test-clean-backups.sh** - `da14f62` (feat)

## Files Created/Modified

- `scripts/lib/backup.sh` - Sourced backup housekeeping library (list_backup_dirs, warn_if_too_many_backups)
- `scripts/update-claude.sh` - New --clean-backups/--keep=N/--dry-run flags + run_clean_backups() + backup.sh sourcing
- `scripts/tests/test-clean-backups.sh` - 8-scenario BACKUP-01 test suite (22 assertions)
- `scripts/tests/test-backup-lib.sh` - 6-assertion unit test for backup.sh library functions
- `scripts/tests/test-detect-cli.sh` - 6-scenario DETECT-06 CLI cross-check tests (staged from prior session)
- `.planning/REQUIREMENTS.md` - Remove phantom path, align BACKUP-01/02 wording to code reality

## Decisions Made

- Prompt implementation uses `printf` to stdout + `read < /dev/tty` with stdin fallback (not `-p` flag)
  so FIFO-based test injection works while remaining curl|bash safe (empty stdin defaults to N)
- `list_backup_dirs()` accepts optional HOME arg (not hardcoded `$HOME`) to enable sandbox isolation
- `run_clean_backups()` uses `TK_UPDATE_HOME` seam for the HOME arg to `list_backup_dirs`, keeping
  test isolation consistent with existing update-claude.sh test patterns

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prompt read fallback for FIFO test compatibility**

- **Found during:** Task 2 (test-clean-backups.sh execution)
- **Issue:** `read -r -p "..." var < /dev/tty` ignores FIFO stdin redirect; test scenarios
  scenario_prompt_mixed_y_n and scenario_rm_scope failed because `/dev/tty` bypassed `0<"$FIFO"`
- **Fix:** Changed prompt to `printf 'prompt'` (stdout) + `read < /dev/tty` with explicit stdin
  fallback (`read -r decision 2>/dev/null`) when tty unavailable; fail-closed default N on EOF
- **Files modified:** scripts/update-claude.sh
- **Verification:** All 22 test assertions pass including prompt-yn and rm-scope scenarios
- **Committed in:** da14f62 (Task 2 commit)

**2. [Rule 2 - Missing] REQUIREMENTS.md phantom path in section header and BACKUP-02 line**

- **Found during:** Task 1 acceptance criteria verification
- **Issue:** Plan spec only noted line 22 (BACKUP-01) but lines 20 and 23 also contained
  `~/.claude/.toolkit-backup-*`; acceptance criterion required zero occurrences across whole file
- **Fix:** Also patched section header (line 20) and BACKUP-02 line (line 23)
- **Files modified:** .planning/REQUIREMENTS.md
- **Verification:** `grep -n '.toolkit-backup'` returns 0 matches
- **Committed in:** 54e0d0a (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 missing completeness fix)
**Impact on plan:** Both fixes necessary for test correctness and spec completeness. No scope creep.

## Issues Encountered

- BSD `grep` treats `--clean-backups)` as a flag when passed as a pattern argument — used
  `grep -ne` with escaped pattern instead; the actual strings are present in the file

## Known Stubs

None — all behavior is fully implemented.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns beyond what the plan's
threat model already covers (T-9-01, T-9-02, T-9-03 all mitigated per plan).

## Next Phase Readiness

- `scripts/lib/backup.sh` ready for Plan 9.2 (BACKUP-02): `warn_if_too_many_backups()` is
  exported and callable; Plan 9.2 only needs to wire the call site in migrate-to-complement.sh
- `test-detect-cli.sh` is staged (committed in Task 1) awaiting Plan 9.3 (DETECT-06) which
  adds the CLI cross-check to detect.sh

## Self-Check

See below.

---

*Phase: 09-backup-detection*
*Completed: 2026-04-24*
