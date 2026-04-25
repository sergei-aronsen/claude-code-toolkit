---
phase: 11-ux-polish
plan: "02"
subsystem: update-dry-run
tags:
  - dry-run
  - ux
  - shell
  - update-flow
dependency_graph:
  requires:
    - scripts/lib/dry-run-output.sh (dro_* library, Plan 11-01)
  provides:
    - scripts/update-claude.sh (DRY_RUN flag + print_update_dry_run + early-exit before backup)
    - scripts/tests/test-update-dry-run.sh (5-scenario test suite)
  affects:
    - scripts/update-claude.sh (modified)
tech_stack:
  added: []
  patterns:
    - "DRY_RUN vs DRY_RUN_CLEAN dual-flag: --dry-run sets both for backwards compat"
    - "Read-only phase: detect + manifest + state + DIFFS_JSON + SKIPPED_BY_MODE_JSON all computed before early-exit"
    - "SKIPPED_BY_MODE_JSON moved before is_update_noop to be available for dry-run printer"
    - "Exit before acquire_lock and BACKUP_DIR: zero filesystem writes when DRY_RUN=1"
key_files:
  created:
    - scripts/tests/test-update-dry-run.sh
  modified:
    - scripts/update-claude.sh
decisions:
  - "Decision A3 locked: --dry-run (without --clean-backups) exits after all read-only steps (detect/manifest/state/diffs/SKIPPED_BY_MODE_JSON) but before acquire_lock and BACKUP_DIR creation"
  - "SKIPPED_BY_MODE_JSON moved from install loop (~line 714) to before is_update_noop (~line 639) — no semantic change, pure read-only computation"
  - "--dry-run sets both DRY_RUN=1 and DRY_RUN_CLEAN=1: --clean-backups --dry-run dispatch fires at line 378 (before new dry-run path), so backwards compat is preserved"
  - "NO_COLOR test scope narrowed to dro_* output lines only: update-claude.sh log_info/log_success use hardcoded ANSI codes outside the dro_* contract"
metrics:
  duration_minutes: ~35
  completed_date: "2026-04-25"
  tasks_completed: 2
  files_changed: 2
  lines_added: 426
  lines_removed: 15
---

# Phase 11 Plan 02: UX Polish — Update --dry-run Full Preview Summary

**One-liner:** `update-claude.sh --dry-run` shows chezmoi-grade 4-group grouped preview (INSTALL/UPDATE/SKIP/REMOVE) via shared `dro_*` library, exiting before backup creation with zero filesystem writes.

## What Was Built

### Task 1: scripts/update-claude.sh (MODIFIED — +105 lines / -15 lines)

Five changes made to the script:

**1. DRY_RUN=0 flag** (line 21) — new flag distinct from `DRY_RUN_CLEAN`. The `--dry-run` arg case now sets BOTH (`DRY_RUN=1; DRY_RUN_CLEAN=1`) so the existing `--clean-backups --dry-run` workflow continues unchanged (`run_clean_backups` dispatch at line 378 exits before the new dry-run path is reached).

**2. LIB_DRO_TMP mktemp** (line 59) — added alongside the other lib tmpfiles. Both EXIT trap lines updated to include `"$LIB_DRO_TMP"` for cleanup (line 61 and line 667 + line 966).

**3. dry-run-output.sh in lib_pair loop** (line 84) — 5th entry `"dry-run-output.sh:$LIB_DRO_TMP"` added to the for-loop that downloads and sources all libs.

**4. SKIPPED_BY_MODE_JSON pre-computation moved** — previously at ~line 714 (inside the install loop block, after `acquire_lock`). Now at line 636–643, immediately after `MODIFIED_ACTUAL=$(compute_modified_actual)` and BEFORE `is_update_noop` check. The computation is read-only; moving it earlier has zero semantic effect on the install flow but makes it available for the dry-run printer.

**5. print_update_dry_run() function** (lines 363–430) — new function inserted between `print_update_summary` and the MAIN block. Reads `NEW_FILES`, `MODIFIED_ACTUAL`, `SKIPPED_BY_MODE_JSON`, `REMOVED_FROM_MANIFEST` from outer scope. Calls `dro_init_colors`, up to four `dro_print_header` calls, `dro_print_file` per path, `dro_print_total`. Empty groups are omitted.

**6. Dry-run exit block** (lines 650–661) — inserted AFTER `is_update_noop` check (line 645) and BEFORE `acquire_lock` (line 668):

```bash
if [[ $DRY_RUN -eq 1 && $CLEAN_BACKUPS -eq 0 ]]; then
    print_update_dry_run
    exit 0
fi
```

### Task 2: scripts/tests/test-update-dry-run.sh (NEW — 321 lines)

Five scenario functions using the `TK_UPDATE_HOME` / `TK_UPDATE_LIB_DIR` / `TK_UPDATE_MANIFEST_OVERRIDE` / `TK_UPDATE_FILE_SRC` seam pattern from `test-update-summary.sh`:

| Scenario | Assertions | Result |
|----------|-----------|--------|
| `scenario_install_group_renders` | exits 0, zero writes, no backup, `[+ INSTALL]` header, `Total:` footer | 5 OK |
| `scenario_remove_group_renders` | `[- REMOVE]` header for orphan path in state | 1 OK |
| `scenario_skip_group_renders` | `[- SKIP]` header + `conflicts_with:superpowers` annotation for complement-sp mode | 2 OK |
| `scenario_no_color` | dro_* output lines ANSI-free with `NO_COLOR=1` | 1 OK |
| `scenario_clean_backups_unchanged` | `run_clean_backups` path fires, `print_update_dry_run` NOT triggered | 2 OK |

**Total: 11/11 assertions pass.**

## Output Format

```text
[+ INSTALL]                                     16 files
  agents/code-reviewer.md
  agents/planner.md
  ...

[- SKIP]                                         9 files
  agents/code-reviewer.md  (conflicts_with:superpowers)
  commands/debug.md  (conflicts_with:superpowers)
  ...

Total: 25 files
```

## SKIPPED_BY_MODE_JSON Line Number Verification

- Before move: was inside the install loop at ~line 714 (after `acquire_lock`, after backup creation)
- After move: line 639 (before `is_update_noop` at line 645, before `acquire_lock` at line 668)
- Confirmed: `SKIPPED_BY_MODE_JSON=` at line 639 < `if is_update_noop` at line 645

## DRY_RUN vs DRY_RUN_CLEAN Separation

| Flag | Set by | Consumed by |
|------|--------|-------------|
| `DRY_RUN_CLEAN=1` | `--dry-run` arg | `run_clean_backups "$KEEP_N" "$DRY_RUN_CLEAN"` at line 379 |
| `DRY_RUN=1` | `--dry-run` arg | New exit block at line 658 (`if [[ $DRY_RUN -eq 1 && $CLEAN_BACKUPS -eq 0 ]]`) |

When `--clean-backups --dry-run` is passed: `CLEAN_BACKUPS=1` so the new exit block condition is false — `run_clean_backups` dispatch runs unmodified.

## Test Results

```text
bash scripts/tests/test-update-dry-run.sh:  PASS 11, FAIL 0
bash scripts/tests/test-dry-run.sh:         PASS 7,  FAIL 0  (no regression)
bash scripts/tests/test-update-summary.sh:  PASS 17, FAIL 0  (no regression)
make check:                                 all checks passed
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `extra_env[@]: unbound variable` under `set -u` with empty array**

- **Found during:** First test run — `run_update_dryrun` passed `"$@"` into `env "${extra_env[@]}"`, which fails under `set -u` when no extra args are provided
- **Fix:** Replaced `env "${extra_env[@]}"` pattern with an explicit export/unset loop — iterates over `"$@"` directly, exports each `KEY=val`, then unsets after the subshell completes
- **Files modified:** `scripts/tests/test-update-dry-run.sh`

**2. [Rule 1 - Bug] NO_COLOR test scope was too broad**

- **Found during:** NO_COLOR scenario — `update-claude.sh` emits `log_info`/`log_warning` lines using hardcoded `$BLUE`/`$CYAN`/`$GREEN` constants defined unconditionally at file top (not gated by NO_COLOR)
- **Issue:** The plan's NO_COLOR assertion targeted the full output, but only `dro_*` functions (from `dry-run-output.sh`) respect `NO_COLOR`. The surrounding log output is outside the dro_* contract and was not part of the UX-01 NO_COLOR requirement.
- **Fix:** Added `assert_dryrun_lines_ansi_free` helper that extracts only the lines emitted by `print_update_dry_run` (`[...]` headers, indented file lines, `Total:`) and checks those lines are ANSI-free
- **Files modified:** `scripts/tests/test-update-dry-run.sh`

## Known Stubs

None — all functions fully implemented and wired. `print_update_dry_run` reads real computed accumulators (`NEW_FILES`, `MODIFIED_ACTUAL`, `SKIPPED_BY_MODE_JSON`, `REMOVED_FROM_MANIFEST`).

## Threat Flags

None — no new network endpoints or auth paths. The `dry-run-output.sh` download follows the same trust boundary as existing lib downloads (HTTPS to raw.githubusercontent.com, hard-fail on error). Threat register items T-11-02-01 through T-11-02-03 all carry `accept` disposition per plan.

## Self-Check

Files exist:

- `scripts/update-claude.sh` FOUND
- `scripts/tests/test-update-dry-run.sh` FOUND

Commits exist:

- `58018ee` — Task 1: DRY_RUN flag + wiring + print_update_dry_run + early-exit FOUND
- `b800d04` — Task 2: test-update-dry-run.sh 5 scenarios FOUND

## Self-Check: PASSED
