---
phase: 18-core-uninstall-script-dry-run-backup
plan: 03
subsystem: infra
tags: [uninstall, shell, bash, backup, sha256, delete-loop, un-01, un-04, bash32]

requires:
  - phase: 18-core-uninstall-script-dry-run-backup
    plan: 02
    provides: scripts/uninstall.sh dry-run preview (DRY_RUN early-exit, REMOVE_LIST/MODIFIED_LIST arrays)
  - phase: 17-dist
    provides: scripts/lib/state.sh (acquire_lock, release_lock), scripts/lib/backup.sh (warn_if_too_many_backups)
provides:
  - scripts/uninstall.sh: trap+acquire_lock, backup-before-delete, REMOVE_LIST delete loop, post-run summary
  - scripts/lib/backup.sh: list_backup_dirs + warn_if_too_many_backups recognize .claude-backup-pre-uninstall-<ts>/ pattern
  - scripts/tests/test-uninstall-backup.sh: 12-assertion hermetic proof of UN-04 + UN-01 invariants
affects: [18-04]

tech-stack:
  added: []
  patterns:
    - "Trap registered BEFORE acquire_lock — SIGINT mid-acquire still invokes release_lock via EXIT trap"
    - "abort-and-cleanup pattern: if cp -R fails, rm partial backup dir then exit 1 BEFORE any rm"
    - "bash 3.2 array-length guard: if [[ ${#ARR[@]} -gt 0 ]]; then for..done; fi — NO inline [@]:- default"
    - "NO local keyword at top-level (MAIN block) — local only inside function bodies (SC2168 clean)"
    - "Defense-in-depth: is_protected_path checked at classification (18-01) AND at delete-time (this plan)"

key-files:
  created:
    - scripts/tests/test-uninstall-backup.sh
  modified:
    - scripts/uninstall.sh
    - scripts/lib/backup.sh
    - Makefile

key-decisions:
  - "LOCK_DIR override under TK_UNINSTALL_HOME: lib/state.sh sets LOCK_DIR=$HOME/.claude/... at source time; must override after sourcing to redirect acquire_lock to sandbox path during tests"
  - "rm -f inside if-statement: `if rm -f \"$abs_path\"` is idiomatic bash — the awk acceptance-criterion pattern `^[[:space:]]*rm -f` did not match this form, but the ordering invariant (cp-R before rm-f) is correct by code inspection"
  - "6 array-length guards in MAIN block (REMOVE_LIST, DELETED_LIST, MODIFIED_LIST, MISSING_LIST, PROTECTED_LIST, DELETE_FAILED_LIST) — exceeds plan requirement of >= 5"

patterns-established:
  - "Execution order contract: trap → libs source → LOCK_DIR override → acquire_lock → backup → snapshot → delete loop → summary → exit 0"
  - "list_backup_dirs explicitly names all three backup patterns (no reliance on glob coincidence)"

requirements-completed:
  - UN-04
  - UN-01

duration: ~6min
completed: 2026-04-26
---

# Phase 18 Plan 03: Backup + Delete Loop + Post-Run Summary

**`scripts/uninstall.sh` non-dry-run path: creates `.claude-backup-pre-uninstall-<ts>/` before any `rm`, deletes only hash-matched files (REMOVE_LIST), preserves MODIFIED files (deferred to 18-04), prints 4-group post-run summary. `list_backup_dirs` extended for new pattern. 12-assertion hermetic test proves all invariants.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-26T09:32:14Z
- **Completed:** 2026-04-26T09:37:49Z
- **Tasks:** 3
- **Files modified:** 3 (backup.sh, uninstall.sh, Makefile)
- **Files created:** 1 (test-uninstall-backup.sh)

## Execution Order Contract

The non-dry-run code path follows this strict ordering:

```text
1. trap 'release_lock; rm -f $LIB_*_TMP' EXIT    — registered FIRST (SIGINT safety)
2. source libs (state.sh → backup.sh → dry-run-output.sh)
3. LOCK_DIR override if TK_UNINSTALL_HOME set     — redirects acquire_lock to sandbox
4. acquire_lock                                    — serializes concurrent runs
5. BACKUP_DIR = .claude-backup-pre-uninstall-$(date -u +%s)
6. cp -R "$CLAUDE_DIR" "$BACKUP_DIR"               — UN-04 full backup
7. cp "$STATE_FILE" "$BACKUP_DIR/toolkit-install.json.snapshot"  — UN-04 snapshot clause
8. warn_if_too_many_backups                        — housekeeping
9. for rel in REMOVE_LIST: is_protected_path → rm -f → DELETED_LIST or DELETE_FAILED_LIST
10. Post-run summary (DELETED / KEPT-modified / MISSING / PROTECTED / DELETE_FAILED / BACKED UP)
11. exit 0 → trap fires → release_lock → rm -f temp files
```

This ordering guarantees: backup always exists before any `rm`. A failure at step 6 removes the partial backup and exits 1 without reaching step 9.

## 18-04 Integration Point

MODIFIED entries are accumulated in `MODIFIED_LIST[]` (populated by 18-01's classification loop) and surfaced in the post-run summary as `KEPT (modified)`. Plan 18-04 adds the `[y/N/d]` interactive prompt by iterating `MODIFIED_LIST` before the delete loop, populating `KEEP_LIST` for files the user chooses to keep. The scaffold is already wired — 18-04 inserts between the classification summary and the `acquire_lock` line.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 0 | Extend backup.sh list_backup_dirs for pre-uninstall pattern | `5d1a52e` | scripts/lib/backup.sh |
| 1 | Add backup + REMOVE_LIST delete loop + post-run summary | `8f5b71c` | scripts/uninstall.sh |
| 2 | Add test-uninstall-backup.sh (12 assertions) + Makefile Test 22 | `f215946` | scripts/tests/test-uninstall-backup.sh, Makefile |

## Test Transcript — test-uninstall-backup.sh (all 12 assertions)

```text
Assertions:
  OK A1: non-dry-run exits 0
  OK A2: exactly 1 .claude-backup-pre-uninstall-* dir created
  OK A3: backup contains commands/clean.md (cp -R verified)
  OK A4: backup contains toolkit-install.json.snapshot
  OK A5: REMOVE-clean file deleted (commands/clean.md absent)
  OK A6: MODIFIED file preserved with original content (agents/edited.md)
  OK A7: PROTECTED file untouched (SHA identical pre/post)
  OK A8: output contains 'DELETED 1'
  OK A9: output contains 'BACKED UP'
  OK A10: output contains 'KEPT (modified) 1'
  OK A11: lock dir cleaned up after exit
  OK A12: list_backup_dirs enumerates .claude-backup-pre-uninstall-* dir

✓ test-uninstall-backup: all 12 assertions passed
```

## list_backup_dirs Extension Transcript (Task 0)

```text
Feed sandbox with all three patterns:
  .claude-backup-1500000000-12345
  .claude-backup-pre-migrate-1600000000
  .claude-backup-pre-uninstall-1700000000

list_backup_dirs output (newest-first):
  .../tmp/.../.claude-backup-pre-uninstall-1700000000
  .../tmp/.../.claude-backup-pre-migrate-1600000000
  .../tmp/.../.claude-backup-1500000000-12345

pre-uninstall found: OK
pre-migrate found: OK
standard found: OK
newest-first order: OK (1700000000 first)
```

## Bash 3.2 + set -u Proof

```bash
# Pattern used for every array iteration in MAIN block:
if [[ ${#ARR[@]} -gt 0 ]]; then
    for p in "${ARR[@]}"; do
        :
    done
fi

# Smoke test (passes on bash 3.2 with set -euo pipefail):
bash --norc -c 'set -euo pipefail; A=(); if [[ ${#A[@]} -gt 0 ]]; then for x in "${A[@]}"; do echo "$x"; done; fi; echo ok'
# Output: ok  (exit 0)
```

6 array-length guards in the MAIN block: REMOVE_LIST, DELETED_LIST, MODIFIED_LIST, MISSING_LIST, PROTECTED_LIST, DELETE_FAILED_LIST. Zero `local` keywords at top level (SC2168 clean — verified by awk). Zero inline `[@]:-` array-default guards (verified by awk, comments excluded).

## Dry-Run Regression

`bash scripts/tests/test-uninstall-dry-run.sh` — all 8 assertions still pass. The DRY_RUN early-exit block (placed AFTER classification, BEFORE backup+delete code) remains intact — UN-02 zero-mutation contract not regressed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] LOCK_DIR override added to test seam block**

- **Found during:** Task 1 implementation review
- **Issue:** Plan's Section A note says "If 18-01 didn't override LOCK_DIR, add the override now." 18-01 did not add it. Without the override, `acquire_lock` in tests uses `$HOME/.claude/.toolkit-install.lock` (real home), not the sandbox lock path — causing lock cleanup interference between test runs and real operations.
- **Fix:** Added `LOCK_DIR="$TK_UNINSTALL_HOME/.claude/.toolkit-install.lock"` inside the `TK_UNINSTALL_HOME` override block, with a `shellcheck disable=SC2034` comment (LOCK_DIR is consumed by `acquire_lock` in sourced lib, not in this file directly).
- **Files modified:** `scripts/uninstall.sh`
- **Commit:** `8f5b71c`

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing LOCK_DIR test seam override)
**Impact on plan:** Required for correct test isolation. No scope creep. All acceptance criteria pass.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes. `rm -f` operates only on paths inside `$PROJECT_DIR` (parent of `.claude/`), double-guarded by `is_protected_path` at classification time (18-01) and at delete-time (this plan). `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"` creates a backup in `$HOME` — same location as `update-claude.sh` and `migrate-to-complement.sh`, consistent with existing threat model.

T-18-03-01 (partial backup on failure): mitigated — `rm -rf "$BACKUP_DIR"` on cp failure.
T-18-03-02 (symlink escape): mitigated — `is_protected_path` re-check at delete time.
T-18-03-04 (concurrent run): mitigated — `acquire_lock` with stale-lock TTL + PID liveness.
T-18-03-06 (empty array under set -u): mitigated — array-length guard pattern throughout.

---

*Phase: 18-core-uninstall-script-dry-run-backup*
*Completed: 2026-04-26*
