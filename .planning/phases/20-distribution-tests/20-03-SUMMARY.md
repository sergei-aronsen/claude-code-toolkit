---
phase: 20-distribution-tests
plan: "03"
subsystem: tests
tags:
  - distribution
  - tests
  - integration
  - round-trip
  - uninstall
  - UN-08
dependency_graph:
  requires:
    - "20-01 (manifest 4.3.0 — read by init-local.sh during S1 install)"
    - "20-02 (Makefile Test 25 already wired — this plan inserts Test 24 before it)"
    - "19-state-cleanup-idempotency (uninstall.sh UN-05/UN-06 implementation)"
    - "18-core-uninstall-script-dry-run-backup (uninstall.sh UN-01/02/03/04 implementation)"
  provides:
    - "UN-08 — end-to-end round-trip integration test"
    - "scripts/tests/test-uninstall.sh (5-scenario integration driver)"
    - "Makefile Test 24 slot (23 -> 24 -> 25 -> All tests passed)"
  affects:
    - "scripts/init-local.sh (INSTALLED_PATHS tracking fixed for 13 previously-untracked files)"
    - "Makefile (Test 24 inserted between Test 23 and Test 25)"
tech_stack:
  added: []
  patterns:
    - "Per-scenario sandbox isolation via mktemp -d + trap RETURN (each run_sN function owns its own /tmp/test-uninstall-roundtrip.XXXXXX)"
    - "Real installer round-trip: (cd SANDBOX && bash init-local.sh) before every uninstall invocation"
    - "jq-based canary selection from installed_files[].path for S2/S3/S4 modified-file scenarios"
    - "Backup path strip: CANARY_IN_BACKUP=${CANARY#.claude/} to match cp -R layout in .claude-backup-pre-uninstall-* dirs"
key_files:
  created:
    - path: scripts/tests/test-uninstall.sh
      description: "5-scenario UN-08 round-trip integration test (374 lines, 18 assertions)"
  modified:
    - path: Makefile
      description: "Test 24 slot inserted between Test 23 and Test 25 (3-line TAB block)"
    - path: scripts/init-local.sh
      description: "INSTALLED_PATHS[] tracking fixed for 6 previously-untracked file groups (cheatsheets, lessons-learned, audit-exceptions, scratchpad, CLAUDE.md, settings.json)"
decisions:
  - "Canary selection uses jq -r '.installed_files[].path' | grep -E '.(md|json)$' | head -1 — keeps the test resilient to future install-set changes rather than hardcoding a path"
  - "Backup assertion strips .claude/ prefix from CANARY to match actual cp -R $CLAUDE_DIR layout (backup dir contains agents/, commands/, etc. directly, not .claude/agents/)"
  - "Rule 1 fix applied to init-local.sh: 13 files installed but not tracked in INSTALLED_PATHS[] caused S1 file-count to be 13 not 0 after round-trip; fixed by adding INSTALLED_PATHS+=() after every untracked install"
metrics:
  duration_minutes: 35
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
  assertions_added: 18
---

# Phase 20 Plan 03: Uninstall Round-Trip Integration Test Summary

**One-liner:** UN-08 round-trip integration test with 5 scenarios (S1-S5) using real init-local.sh + uninstall.sh, plus Rule 1 fix for 13 untracked files in init-local.sh.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Create scripts/tests/test-uninstall.sh (5 scenarios, 18 assertions) | eadd36b | DONE |
| 2 | Wire Makefile Test 24 between Test 23 and Test 25 | 9676bde | DONE |

## Test Results

All 5 scenario blocks pass against the real init-local.sh + uninstall.sh contract:

- **S1** (clean round-trip): `find .claude -type f == 0` after uninstall, toolkit-install.json absent
- **S2** (modified + y): canary deleted, backup directory created, backup preserves pre-uninstall copy (UN-04)
- **S3** (modified + N): canary preserved (UN-03 default-keep branch)
- **S4** (modified + d then N): diff branch rendered (or "reference unavailable" in offline CI), canary preserved
- **S5** (--dry-run + double-uninstall): zero filesystem changes under --dry-run (UN-02), second invocation exits 0 with "Toolkit not installed; nothing to do" (UN-06)

Total: 18 assertions, 0 failures.

## Makefile Ordering

Final sequence after all three Phase 20 plans:

```
Test 23: uninstall [y/N/d] prompt loop (UN-03)
Test 24: uninstall round-trip integration (UN-08)  <-- this plan
Test 25: installer banner gate (UN-07)             <-- Plan 02
All tests passed!
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] init-local.sh did not track 13 installed files in INSTALLED_PATHS[]**

- **Found during:** Task 1 execution — S1 file-count assertion failed (13 files, not 0)
- **Issue:** `cheatsheets/*.md` (9 files), `rules/lessons-learned.md`, `rules/audit-exceptions.md`, `scratchpad/current-task.md`, `.claude/CLAUDE.md`, and `settings.json` were all installed by `init-local.sh` but never appended to `INSTALLED_PATHS[]`. Since `write_state` only records files in `INSTALLED_PATHS`, `uninstall.sh` had no knowledge of these 13 files and could not remove them.
- **Fix:** Added `INSTALLED_PATHS+=("...")` immediately after every `cp`/`cat >` that creates one of these files.
- **Files modified:** `scripts/init-local.sh`
- **Commit:** eadd36b

**2. [Rule 1 - Bug] S2 backup path assertion used wrong path prefix**

- **Found during:** Task 1 execution — S2 backup assertion failed
- **Issue:** `uninstall.sh` creates backup via `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"`, which copies the `.claude/` directory tree INTO `$BACKUP_DIR`. The backed-up file is at `$BACKUP_DIR/agents/planner.md` (no `.claude/` prefix), but the test was checking `$BACKUP_DIR/$CANARY` where `$CANARY = ".claude/agents/planner.md"` — an extra `.claude/` level.
- **Fix:** Added `CANARY_IN_BACKUP="${CANARY#.claude/}"` to strip the prefix before building the backup path.
- **Files modified:** `scripts/tests/test-uninstall.sh`
- **Commit:** eadd36b

## Verification Gate Results

All conditions from plan `<verification>` block satisfied:

1. `bash scripts/tests/test-uninstall.sh` — exits 0, 18/18 assertions passed
2. `make test` — exits 0, Tests 1-25 all pass
3. `make check` — exits 0, lint + validate + version-align green
4. `find /tmp -maxdepth 1 -name 'test-uninstall-roundtrip.*' -type d` — empty after `make test` (per-scenario traps cleaned up)
5. Makefile ordering: Test 23 @ line 121, Test 24 @ line 124, Test 25 @ line 127, "All tests passed!" @ line 130
6. No regression: manifest.json, CHANGELOG.md, installer banners, test-install-banner.sh from Plans 01-02 unchanged

## Phase 20 Completion

Phase 20 is now complete:

- **Plan 01** (20-01): manifest 4.3.0 bump + CHANGELOG [4.3.0] entry + version-align gate
- **Plan 02** (20-02): installer banners (UN-07) + Makefile Test 25
- **Plan 03** (20-03): round-trip integration test (UN-08) + Makefile Test 24

All UN-07 and UN-08 requirements are closed. The v4.3 milestone has one remaining step: replacing the `YYYY-MM-DD` placeholder in manifest.json and CHANGELOG.md with the real ISO date at tag commit time (per D-15 decision).

## Known Stubs

None — the round-trip test exercises real production code paths with no hardcoded or fabricated state.

## Self-Check: PASSED

All files present:

- FOUND: scripts/tests/test-uninstall.sh
- FOUND: Makefile
- FOUND: scripts/init-local.sh
- FOUND: .planning/phases/20-distribution-tests/20-03-SUMMARY.md

All commits present:

- FOUND: eadd36b (feat(20-03): add UN-08 round-trip integration test + fix init-local.sh tracking)
- FOUND: 9676bde (feat(20-03): wire Test 24 (uninstall round-trip) into Makefile)
