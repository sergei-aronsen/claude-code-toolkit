---
phase: 04-update-flow
plan: "03"
subsystem: update-flow
tags: [tree-backup, summary-printer, no-op-detection, locking, rollback-docs, ansi-auto-disable, tdd, bash]

# Dependency graph
requires:
  - "04-01 (STATE_JSON, STATE_MODE, MANIFEST_HASH, STATE_MANIFEST_HASH, ADD_FROM_SWITCH_JSON, REMOVED_BY_SWITCH_JSON)"
  - "04-02 (INSTALLED_PATHS, UPDATED_PATHS, SKIPPED_PATHS, REMOVED_PATHS arrays)"
provides:
  - "D-57 tree backup: BACKUP_DIR=<dirname $CLAUDE_DIR>/.claude-backup-<unix-ts>-$$"
  - "D-58 print_update_summary: 4-group post-run summary with ANSI auto-disable"
  - "D-59 is_update_noop: 5-condition check exits 0 with one-line message, no backup, no write_state"
  - "compute_modified_actual: pre-dispatch read-only hash check subset of MODIFIED_CANDIDATES"
  - "write_state called ONCE post-mutation with final installed CSV + manifest_hash post-processing"
  - "Lock-wrapped mutation: trap 'release_lock; rm -f <tmpfiles>' EXIT + acquire_lock || exit 1"
  - "TK_UPDATE_FILE_SRC hermetic boundary: when set, never falls through to curl"
affects:
  - "Phase 5 migration: reuses compute_file_diffs_obj + execute_mode_switch + tree-backup pattern"
  - "commands/rollback-update.md: listing glob .claude-backup-* matches new format"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "print_update_summary: local _G/_C/_Y/_R/_NC ANSI auto-disable (mirrors lib/install.sh:print_dry_run_grouped)"
    - "compute_modified_actual: pure read-only hash subset before dispatch — no prompts, no side effects"
    - "is_update_noop: 6-condition check (state.mode, new/removed/modified/switch arrays, manifest_hash)"
    - "write_state post-processing: jq + mv atomic pattern to add manifest_hash field"
    - "TK_UPDATE_FILE_SRC hermetic: when set, blocks curl fallback (empty dir = all downloads fail)"
    - "No-op algorithm: compute_modified_actual first, then is_update_noop, then lock+backup+dispatch"

key-files:
  created:
    - .planning/phases/04-update-flow/04-03-SUMMARY.md
  modified:
    - scripts/update-claude.sh
    - scripts/tests/test-update-summary.sh
    - scripts/tests/test-update-drift.sh
    - scripts/tests/test-update-diff.sh
    - commands/rollback-update.md

key-decisions:
  - "Modified-actual pre-dispatch: compute MODIFIED_ACTUAL before Plan 04-02 dispatch so is_update_noop can check it without running any prompts. Dispatch loop then iterates MODIFIED_ACTUAL (pre-hashed) instead of MODIFIED_CANDIDATES — avoids double-hashing and ensures no-op check is purely read-only."
  - "same-second concurrent test strategy: prove PID-suffix algorithm rather than racing two real update runs. Two bash subshells emit the path formula; since $$ differs per process, paths must differ even at the same unix-ts. Avoids lock serialization and process-timing flakiness in CI."
  - "write_state CSV-build approach: iterate STATE_JSON.installed_files[].path (post-normalized relative), filter out REMOVED_PATHS, prepend CLAUDE_DIR/ for absolute paths, append INSTALLED_PATHS. UPDATED_PATHS are already in state and survive the filter — write_state recomputes their sha256 from disk."
  - "TK_UPDATE_FILE_SRC hermetic boundary fix: original code fell through to curl when seam dir set but file absent. Fixed to block curl entirely when TK_UPDATE_FILE_SRC is set — empty dir = all downloads skipped. This is required for deterministic test assertions on installed_files count."
  - "manifest_hash post-processing: write_state does not accept manifest_hash arg (keep lib untouched per Phase 4 scope). Post-process STATE_FILE atomically via jq + mv $$.tmp pattern — same pattern as write_state itself."

requirements-completed:
  - UPDATE-05
  - UPDATE-06

# Metrics
duration: 14min
completed: 2026-04-18
---

# Phase 4 Plan 03: Tree Backup + 4-Group Summary + No-Op Exit Summary

**D-57 tree backup (unix-ts-pid), D-58 four-group summary, D-59 no-op early-exit, lock-wrapped mutation, final write_state — Phase 4 complete, all UPDATE-01..06 satisfied**

## Performance

- **Duration:** approx 14 min
- **Started:** 2026-04-18T19:42:18Z
- **Completed:** 2026-04-18T19:56:34Z
- **Tasks:** 3 (feat + test + docs)
- **Files modified:** 5

## Accomplishments

- D-57: BACKUP_DIR uses `<dirname $CLAUDE_DIR>/.claude-backup-$(date -u +%s)-$$` format (collision-safe PID suffix)
- D-58: `print_update_summary <backup_dir>` prints four groups (INSTALLED/UPDATED/SKIPPED/REMOVED) with ANSI auto-disable matching Plan 03-02 pattern
- D-59: `is_update_noop` checks 6 conditions (STATE_MODE==RECOMMENDED, empty new/removed/modified/switch arrays, manifest_hash match); exits 0 with single-line message, no backup, no write_state
- `compute_modified_actual`: pure read-only pre-dispatch hash subset; dispatch loop uses MODIFIED_ACTUAL instead of MODIFIED_CANDIDATES
- Final `write_state` call with post-dispatch installed CSV; manifest_hash atomically added via jq post-processing
- Lock wrapping: consolidated EXIT trap handles both release_lock and tempfile cleanup
- Legacy `TK_UPDATE_SKIP_LEGACY_BACKUP` seam and ASCII banner summary fully removed
- Test 11 GREEN: 17/17 assertions across 5 scenarios; Tests 9/10 preserved (14/14 and 13/13)
- `commands/rollback-update.md` updated with Backup Naming (v4.0+) section, all example paths updated, glob comment added
- `make check` green: shellcheck + mdlint + validate all pass

## Task Commits

1. **Task 1:** `8a57d46` — `feat(04-03): tree backup + 4-group summary + no-op exit + lock-wrapped mutation (UPDATE-05/06)`
2. **Task 2:** `65d09e1` — `test(04-03): fill test-update-summary.sh + drop legacy-backup test seam (UPDATE-05/06 GREEN)`
3. **Task 3:** `4819ccd` — `docs(04-03): update rollback-update.md for <unix-ts>-<pid> backup format`

## Files Created/Modified

- `scripts/update-claude.sh` — added compute_modified_actual, is_update_noop, print_update_summary; no-op check + lock + backup block; narrowed dispatch to MODIFIED_ACTUAL; write_state + manifest_hash post-processing; deleted legacy backup + ASCII summary; TK_UPDATE_FILE_SRC hermetic fix. 624→740 lines (+116)
- `scripts/tests/test-update-summary.sh` — replaced 5 stub scenarios with 5 real scenarios (Test 11 GREEN, 17/17)
- `scripts/tests/test-update-drift.sh` — dropped TK_UPDATE_SKIP_LEGACY_BACKUP; scenario 1 uses empty file-src for deterministic count
- `scripts/tests/test-update-diff.sh` — dropped TK_UPDATE_SKIP_LEGACY_BACKUP from all 7 scenarios
- `commands/rollback-update.md` — added Backup Naming (v4.0+) section; updated all example paths; added glob compatibility comment

## Decisions Made

**1. Modified-actual pre-dispatch computation**
Moving `compute_modified_actual` BEFORE Plan 04-02's dispatch resolves the chicken-and-egg problem: the no-op check needs to know if any files have real hash divergence, but Plan 04-02's dispatch runs prompts that are side effects. Solution: pure read-only hash scan computes the set first. The dispatch loop then iterates this pre-hashed subset (avoiding double-hashing). If the set is empty, no-op exits before any mutation.

**2. same-second concurrent test strategy (not real races)**
Attempting to race two real `update-claude.sh` processes would be serialized by `acquire_lock`, and asserting on backup dir count would be brittle in CI. The plan's approach of forking two bash subshells to emit the path formula is sufficient to prove the algorithm: `date -u +%s` could be the same, but `$$` always differs between child bash processes. Zero test flakiness, no timing dependencies.

**3. write_state CSV-build approach**
Alternative: accumulate a live JSON during dispatch (add each installed path as it's processed). Chose the post-dispatch CSV-build instead because: (a) bash associative arrays under `set -euo pipefail` are error-prone, (b) the STATE_JSON in-memory already has the pre-run installed files as ground truth, (c) REMOVED_PATHS filter is a simple grep exclusion, (d) write_state recomputes sha256 from disk — so UPDATED_PATHS files get the new remote hash automatically without any extra tracking.

**4. TK_UPDATE_FILE_SRC hermetic boundary fix (Rule 1 - Bug)**
The original seam allowed curl fallback when TK_UPDATE_FILE_SRC was set but the specific file was absent. Test scenario 1 (v3x upgrade) used this expecting downloads to fail silently, but on internet-connected machines the downloads succeeded, making `installed_files` count non-deterministic. Fix: when TK_UPDATE_FILE_SRC is set, block curl entirely — missing file = install_status=1. Updated scenario 1 to pass `TK_UPDATE_FILE_SRC` pointing at an empty dir for deterministic test behavior.

**5. Pre-Phase-4 line count**
- `scripts/update-claude.sh` pre-Phase-4: ~330 lines
- Post-Phase-4 (Plans 04-01 + 04-02 added, Plan 04-02 deleted ~72 lines of hand-lists): ~624 lines at start of Plan 04-03
- Post-Plan-04-03 (added 3 functions + no-op + lock + backup + write_state; deleted legacy backup + ASCII summary): 740 lines
- Net: +410 lines over pre-Phase-4, fully manifest-driven with no hand-maintained lists

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TK_UPDATE_FILE_SRC hermetic boundary allowed curl fallback**

- **Found during:** Task 1 (test-update-drift.sh scenario 1 assertion `installed_files|length == 3` failing with 7)
- **Issue:** When `TK_UPDATE_FILE_SRC` is set but the file doesn't exist in the seam directory, the original code fell through to `curl`. On an internet-connected machine, 4 files downloaded successfully, making the count 7 instead of 3.
- **Fix:** Changed the conditional to: when `TK_UPDATE_FILE_SRC` is set (non-empty), NEVER fall through to curl — missing file = install_status=1. Applied to both the new-file loop and `prompt_modified_file`. Updated test-update-drift.sh scenario 1 to pass `TK_UPDATE_FILE_SRC` pointing at an empty dir.
- **Files modified:** `scripts/update-claude.sh`, `scripts/tests/test-update-drift.sh`
- **Committed in:** `8a57d46`

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Required fix. Tests are now hermetic and deterministic regardless of network access.

## Gate Verification Output

```text
make check:
  shellcheck:  ✅ ShellCheck passed
  mdlint:      ✅ Markdownlint passed
  validate:    ✅ Version aligned: 3.0.0
               ✅ update-claude.sh is manifest-driven (no hand-maintained file lists)
               ✅ All templates valid
               ✅ Manifest schema valid

bash scripts/tests/test-update-drift.sh:   Results: 14 passed, 0 failed  (Test 9 GREEN)
bash scripts/tests/test-update-diff.sh:    Results: 13 passed, 0 failed  (Test 10 GREEN)
bash scripts/tests/test-update-summary.sh: Results: 17 passed, 0 failed  (Test 11 GREEN)
```

Note: Test 7 (`test-dry-run.sh`) has 4 pre-existing failures that are identical in both the main repo and the worktree — confirmed out-of-scope for Plan 04-03.

## Phase 4 Close Statement

All UPDATE-01 through UPDATE-06 requirements are satisfied:

- **UPDATE-01:** State loading, v3.x synthesis (D-50), drift detect (D-51), mode-switch (D-52) — Plan 04-01
- **UPDATE-02:** New-file auto-install from manifest (D-54) — Plan 04-02
- **UPDATE-03:** Removed-file batch prompt (D-55) — Plan 04-02
- **UPDATE-04:** Modified-file per-file [y/N/d] prompt (D-56) — Plan 04-02
- **UPDATE-05:** Tree backup `~/.claude-backup-<unix-ts>-<pid>/`, collision-safe, no-op skips backup — Plan 04-03
- **UPDATE-06:** 4-group summary (INSTALLED/UPDATED/SKIPPED/REMOVED) with ANSI auto-disable — Plan 04-03

ROADMAP Phase 4 can be checked off. Phase 4 is ready to merge as a single PR per D-62 with Conventional Commits:
`feat(04-01):`, `refactor(04-02):`, `test(04-02):`, `feat(04-03):`, `test(04-03):`, `docs(04-03):`

## Known Stubs

None — all dispatch paths are fully wired. `write_state` is called post-mutation with final state. Summary printer iterates the four accumulator arrays populated by Plans 04-02 and 04-03.

## Threat Flags

None — no new network endpoints or auth paths introduced. All changes are internal bash logic with no user-facing HTTP surface.

## Self-Check: PASSED

All created/modified files exist on disk. All commit hashes verified in git log.
Tests 9/10/11 GREEN. `make check` exits 0. `TK_UPDATE_SKIP_LEGACY_BACKUP` removed.
Legacy ASCII banner summary removed. `print_update_summary` present in scripts/update-claude.sh.
`commands/rollback-update.md` contains `<unix-ts>-<pid>` format and `Backup Naming (v4.0+)` section.
