---
phase: 29-sync-uninstall-integration
plan: "03"
subsystem: uninstall / bridges-test
tags: [bridges, uninstall, classify_bridge_file, BRIDGE-UN-01, BRIDGE-UN-02, hermetic-test, bash3.2]
dependency_graph:
  requires: [29-01, 29-02]
  provides: [BRIDGE-UN-01, BRIDGE-UN-02, test-bridges-sync]
  affects: [29-final, phase-30]
tech_stack:
  added: []
  patterns: [caller-holds-lock guard, bridge-path-protection-bypass, parallel-indexed-arrays]
key_files:
  created:
    - scripts/tests/test-bridges-sync.sh
  modified:
    - scripts/uninstall.sh
    - scripts/lib/bridges.sh
decisions:
  - "classify_bridge_file bypasses is_protected_path — bridges live outside CLAUDE_DIR/ by design"
  - "REMOVE_LIST loop bypasses is_protected_path for bridge paths (BRIDGE_PATHS linear scan)"
  - "self-deadlock guard: if LOCK_DIR/pid == $$ then skip acquire/release in _bridge_write_state_entry, _bridge_set_user_owned, _bridge_remove_state_entry"
  - "_bridge_remove_state_entry called BEFORE state-file deletion (line 659+), gated on KEEP_STATE=0"
metrics:
  duration: "~50 minutes"
  completed: "2026-04-29T19:03:33Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
  files_created: 1
---

# Phase 29 Plan 03: Uninstall Integration + Hermetic Smoke Test Summary

Wires `bridges[]` into the `uninstall.sh` lifecycle (BRIDGE-UN-01/02) and ships
`scripts/tests/test-bridges-sync.sh` — a hermetic smoke test covering all 5 ROADMAP
success criteria + the BACKCOMPAT-01 invariant. Two Rule 1 bugs found during testing
and auto-fixed in-plan.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Extend uninstall.sh — source bridges.sh, classify bridges[], remove + state-purge | d254182 | scripts/uninstall.sh |
| 1-fix | Rule 1: self-deadlock + bridge path protection bypass | 741a41a | scripts/lib/bridges.sh, scripts/uninstall.sh |
| 2 | Create test-bridges-sync.sh — hermetic Phase 29 smoke test | 3822dd0 | scripts/tests/test-bridges-sync.sh |

## File Line Counts

| File | Lines | Status |
|------|-------|--------|
| scripts/uninstall.sh | 776 | modified (+88 net from plan, +12 from fixes) |
| scripts/tests/test-bridges-sync.sh | 348 | created |
| scripts/lib/bridges.sh | 467 | modified (lock guard fixes) |

## Bridges Classification Flow

### Why classify_bridge_file instead of classify_file

`classify_file` calls `is_protected_path` first, which returns 0 (protected) for any
path outside `$CLAUDE_DIR/`. Bridge files live at `<project>/GEMINI.md` — next to
`CLAUDE.md`, not inside `.claude/`. Using `classify_file` would always return PROTECTED
for every bridge entry, silently skipping them.

`classify_bridge_file` bypasses `is_protected_path` entirely, adding only a focused
inline check for the SP and GSD trees (the two paths that MUST never be touched):

```bash
case "$path" in
    "$HOME"/.claude/plugins/cache/.../superpowers/*) printf 'PROTECTED'; return 0 ;;
    "$HOME"/.claude/get-shit-done/*)                 printf 'PROTECTED'; return 0 ;;
esac
```

### Why the REMOVE_LIST loop also needs a bypass

`uninstall.sh` has a defense-in-depth `is_protected_path` check inside the REMOVE_LIST
deletion loop (line 616). Even after `classify_bridge_file` correctly classified the
bridge as REMOVE, `is_protected_path` in the deletion loop would block it again. Fix:
linear scan of `BRIDGE_PATHS` to identify bridge entries and skip the `is_protected_path`
call for them.

## Order-of-Operations for bridges[] State Cleanup vs --keep-state

```text
1. acquire_lock
2. UN-04: backup CLAUDE_DIR
3. REMOVE_LIST: rm bridge files + installed_files (bridge bypass added)
4. MODIFIED_LIST: per-file [y/N/d] prompts
5. Phase 29: bridges[] purge — _bridge_remove_state_entry for each DELETED_LIST entry
   GATED ON: KEEP_STATE=0 && DELETED_LIST non-empty && BRIDGE_PATHS non-empty
6. UN-05: strip sentinel block
7. UN-05: base-plugin diff-q invariant check
8. UN-05: state-file delete (LAST, KEEP_STATE gate)
```

When `--keep-state`:
- Steps 3-4 still run (bridge files and installed files are removed)
- Step 5 is SKIPPED (`KEEP_STATE=0` gate false) → bridges[] entries survive
- Step 8 is SKIPPED → state file survives with its bridges[] array intact

This implements BRIDGE-UN-02: `--keep-state` preserves bridges[] alongside
installed_files[] for re-run recovery.

## Test Seam Map

| Seam | Purpose | Used in |
|------|---------|---------|
| `TK_BRIDGE_HOME` | sandboxes state file, lock dir, bridge write paths | install_seed, run_update, run_uninstall |
| `TK_UPDATE_HOME` | update-claude.sh reads CLAUDE_DIR + STATE_FILE from here | run_update |
| `TK_UNINSTALL_HOME` | uninstall.sh reads CLAUDE_DIR + STATE_FILE from here | run_uninstall |
| `TK_UPDATE_LIB_DIR` | update-claude.sh sources local lib files (no curl) | run_update |
| `TK_UNINSTALL_LIB_DIR` | uninstall.sh sources local lib files (no curl) | run_uninstall |
| `TK_BRIDGE_TTY_SRC` | drift-prompt answer injection for S3a/S3b | scenario_s3a, scenario_s3b |
| `TK_UNINSTALL_TTY_FROM_STDIN` | uninstall [y/N/d] answer injection | scenario_s8 |
| `TK_UPDATE_MANIFEST_OVERRIDE` | points at repo manifest.json (no network) | run_update |
| `TK_UPDATE_FILE_SRC` | update-claude.sh resolves toolkit files locally | run_update |
| `HOME="$sandbox"` | ensures uninstall.sh's SP_DIR/GSD_DIR resolve to sandbox | run_uninstall |

`TK_UPDATE_HOME` and `TK_BRIDGE_HOME` are set to the SAME sandbox so the test seam
linking in `sync_bridges` (`export TK_BRIDGE_HOME="${TK_UPDATE_HOME:-...}"`) routes
bridge state writes to the same sandbox as the update's STATE_FILE reads.

## Scenario List — S1 to S10 with PASS Results

| Scenario | Description | Assertions | Result |
|----------|-------------|------------|--------|
| S1 | Clean source/bridge match → silent no-op | 3 | PASS |
| S2 | Source edited → `[~ UPDATE]` + SHA refresh | 2 | PASS |
| S3a | Bridge edited, drift prompt `y` → overwrite | 2 | PASS |
| S3b | Bridge edited, drift prompt `N` → keep | 2 | PASS |
| S4 | `--break-bridge gemini` → user_owned=true → SKIP | 3 | PASS |
| S5 | `--restore-bridge gemini` → user_owned=false → re-sync | 2 | PASS |
| S6 | Source deleted → `[? ORPHANED]` + auto-flip user_owned | 2 | PASS |
| S7 | uninstall.sh clean bridge → REMOVE + bridges[] purged | 2 | PASS |
| S8 | uninstall.sh modified bridge + N → KEPT, entry preserved | 2 | PASS |
| S9 | uninstall.sh --keep-state → file removed, bridges[] kept | 2 | PASS |
| S10 | BACKCOMPAT-01: all three prior tests PASS unchanged | 3 | PASS |
| **Total** | | **25** | **PASS=25 FAIL=0** |

## BACKCOMPAT-01 Verdict

| Test | Expected | Actual | Result |
|------|----------|--------|--------|
| test-bootstrap.sh | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| test-install-tui.sh | PASS=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| test-bridges-foundation.sh | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |

## shellcheck Result

`shellcheck -S warning` clean on all modified/created files:

- `scripts/uninstall.sh` — PASS (776 lines)
- `scripts/lib/bridges.sh` — PASS (467 lines)
- `scripts/tests/test-bridges-sync.sh` — PASS (348 lines)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Self-deadlock in bridge state helpers when called from update-claude.sh/uninstall.sh**

- **Found during:** Task 2 S2/S3a/S5/S6 failures (sync scenarios not logging `[~ UPDATE]` or `[? ORPHANED]`)
- **Issue:** `update-claude.sh` holds `acquire_lock` (line 892). `sync_bridges` calls `bridge_create_project` → `_bridge_write_state_entry` → `acquire_lock`. Same process, same LOCK_DIR. `acquire_lock` sees the lock held by the same PID, spins 3x (1s each), then returns 1 silently. Bridge rewrite proceeds but state write is dropped, so SHAs are never refreshed. Same issue for `uninstall.sh` + `_bridge_remove_state_entry`.
- **Fix:** Added caller-holds-lock guard to all three state-mutating helpers (`_bridge_write_state_entry`, `_bridge_set_user_owned`, `_bridge_remove_state_entry`): `_existing_pid=$(cat "${LOCK_DIR}/pid"); if [[ "$_existing_pid" == "$$" ]]; then _caller_holds_lock=1; fi`. Skip acquire/release when caller already owns the lock.
- **Files modified:** `scripts/lib/bridges.sh`
- **Commit:** 741a41a

**2. [Rule 1 - Bug] Bridge path protection bypass missing in REMOVE_LIST loop**

- **Found during:** Task 2 S7/S9 failures (bridge file still existed after uninstall)
- **Issue:** `uninstall.sh` REMOVE_LIST loop has a defense-in-depth `is_protected_path "$abs_path"` check. `is_protected_path` returns 0 (protected) for any path outside `$CLAUDE_DIR/`. Bridge files at `<project>/GEMINI.md` are outside `CLAUDE_DIR`, so they were silently skipped at deletion time, even though `classify_bridge_file` had correctly placed them in REMOVE_LIST.
- **Fix:** Linear scan of `BRIDGE_PATHS` array to identify bridge paths; skip `is_protected_path` for them (they were already cleared by `classify_bridge_file`'s focused SP/GSD guard).
- **Files modified:** `scripts/uninstall.sh`
- **Commit:** 741a41a

## Known Stubs

None. All scenarios are fully wired to real behavior.

## Threat Flags

None. Changes are internal lifecycle management: uninstall cleanup and hermetic tests. No new network endpoints, auth paths, or trust boundaries introduced.

## Self-Check: PASSED

- `scripts/uninstall.sh` contains `LIB_BRIDGES_TMP` (3 occurrences), `bridges.sh:` (1), `classify_bridge_file` (1 def), `BRIDGE_PATHS` (15 refs), `_bridge_remove_state_entry` (3 refs), `.bridges // []` (1)
- `scripts/tests/test-bridges-sync.sh` exists, executable, 348 lines, PASS=26/43/5 baked in
- `scripts/lib/bridges.sh` contains caller-holds-lock guard in all 3 state helpers
- `bash scripts/tests/test-bridges-sync.sh` reports PASS=25 FAIL=0
- `test-bootstrap.sh` PASS=26, `test-install-tui.sh` PASS=43, `test-bridges-foundation.sh` PASS=5 all green
- `shellcheck -S warning` clean on all three modified/created files
- Commits d254182, 741a41a, 3822dd0 all present in git log
