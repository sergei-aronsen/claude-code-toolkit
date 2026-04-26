---
phase: 18-core-uninstall-script-dry-run-backup
plan: 02
subsystem: infra
tags: [uninstall, shell, bash, dry-run, dro, zero-mutation, sha256]

requires:
  - phase: 18-core-uninstall-script-dry-run-backup
    plan: 01
    provides: scripts/uninstall.sh foundation (argparse, state load, classify_file, DRY_RUN flag)
provides:
  - scripts/uninstall.sh: --dry-run 4-group preview (print_uninstall_dry_run, DRY_RUN early-exit)
  - scripts/tests/test-uninstall-dry-run.sh: hermetic 8-assertion zero-mutation test
affects: [18-03, 18-04]

tech-stack:
  added: []
  patterns:
    - "classify_file resolves relative paths against PROJECT_DIR (parent of .claude/), not CLAUDE_DIR — avoids double-.claude path bug"
    - "print_uninstall_dry_run reads outer-scope arrays (REMOVE_LIST/MODIFIED_LIST/MISSING_LIST/KEEP_LIST) built during classification loop"
    - "DRY_RUN early-exit placed AFTER classification loop, BEFORE any backup/delete code — permanent placement contract for 18-03/18-04"
    - "MODIFIED and MISSING both use single-char '?' marker (dro_print_header API); groups distinguished by LABEL column only"

key-files:
  created:
    - scripts/tests/test-uninstall-dry-run.sh
  modified:
    - scripts/uninstall.sh

key-decisions:
  - "classify_file must resolve against PROJECT_DIR not CLAUDE_DIR: installed_files[].path entries are .claude/commands/foo.md (relative to project root), so CLAUDE_DIR/.claude/commands/foo.md creates a double-.claude path — fix applied as Rule 1 bug"
  - "KEEP_LIST initialized empty in 18-02; populated by 18-04 [y/N/d] prompt — array accumulator pattern ready"
  - "DRY_RUN early-exit is unconditional and permanent: plans 18-03 and 18-04 MUST add backup+delete code AFTER this exit block, never before"
  - "MISSING and MODIFIED both use '?' single-char marker — dro_print_header signature accepts one char only; groups visually distinguished by label (MODIFIED vs MISSING)"

requirements-completed:
  - UN-02

duration: 15min
completed: 2026-04-26
---

# Phase 18 Plan 02: Dry-Run Preview Output Summary

**`scripts/uninstall.sh --dry-run` renders a 4-group chezmoi-grade preview using `dro_*` primitives (REMOVE/KEEP/MODIFIED/MISSING), exits 0 with zero filesystem mutations — UN-02 zero-mutation contract proven by hermetic 8-assertion test**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-26T09:25:00Z
- **Completed:** 2026-04-26T09:29:30Z
- **Tasks:** 2
- **Files modified:** 2 (uninstall.sh modified, test-uninstall-dry-run.sh created)

## Accomplishments

- `print_uninstall_dry_run()` added to `scripts/uninstall.sh` — reads outer-scope arrays (REMOVE_LIST, MODIFIED_LIST, MISSING_LIST, KEEP_LIST) populated during classification loop; renders 4 conditional groups using `dro_print_header` / `dro_print_file` / `dro_print_total`; calls `dro_init_colors` for TTY+NO_COLOR gated ANSI
- Classification loop replaced counter-only increments with 5 array accumulators (REMOVE_LIST, MODIFIED_LIST, MISSING_LIST, PROTECTED_LIST, KEEP_LIST); counters derived from array lengths via `${#ARRAY[@]}`
- DRY_RUN early-exit block inserted immediately after classification loop, before any future backup/delete code — permanent placement contract for plans 18-03/18-04
- `scripts/tests/test-uninstall-dry-run.sh` created (executable, shellcheck clean) — hermetic 8-assertion test using `TK_UNINSTALL_HOME` + `TK_UNINSTALL_LIB_DIR` seams; all 8 assertions pass
- Test wired as Test 21 in Makefile under existing numbered test sequence
- `make check` (markdownlint + shellcheck + validate-templates) passes green

## print_uninstall_dry_run Structure

```text
print_uninstall_dry_run()
  ├── dro_init_colors        — TTY + NO_COLOR gated _DRO_* vars
  ├── local total = n_remove + n_keep + n_modified + n_missing
  ├── if n_remove > 0  → dro_print_header "-" "REMOVE" n_remove _DRO_R  + file loop
  ├── if n_keep > 0    → dro_print_header "~" "KEEP"   n_keep   _DRO_C  + file loop (empty in 18-02; 18-04 populates)
  ├── if n_modified > 0→ dro_print_header "?" "MODIFIED" n_modified _DRO_Y + file loop (with annotation)
  ├── if n_missing > 0 → dro_print_header "?" "MISSING"  n_missing  _DRO_Y + file loop (with annotation)
  └── dro_print_total total
```

## DRY_RUN Early-Exit Placement Contract

```bash
# (classification loop populates arrays here)
n_remove=${#REMOVE_LIST[@]}
...

# UN-02 dry-run early exit. Must run AFTER classification (read-only) and
# BEFORE any backup/lock/delete logic added by plans 18-03/18-04.
if [[ $DRY_RUN -eq 1 ]]; then
    print_uninstall_dry_run
    exit 0
fi

# TODO(18-03): replace with backup + delete loop
exit 0
```

Plans 18-03 and 18-04 MUST add their backup+delete code AFTER this `if [[ $DRY_RUN -eq 1 ]]` block — inserting before it would break the zero-mutation invariant.

## Test Invocation Transcript

```text
Assertions:
  OK --dry-run exits 0
  OK [- REMOVE] header shows 1 file
  OK [? MODIFIED] header shows 1 file
  OK [? MISSING] header shows 1 file
  OK Total: 3 files footer present
  OK zero new files created after dry-run (find -newer marker)
  OK no .claude-backup-pre-uninstall-* directory created
  OK toolkit-install.json unchanged after dry-run

✓ test-uninstall-dry-run: all 8 assertions passed
```

## MISSING/MODIFIED Marker Confirmation

Both MISSING and MODIFIED groups use the single-char `?` marker per the `dro_print_header` API contract (`$1=marker, one char: + | - | ~ | ?`). They are distinguished by the LABEL column:

- `[? MODIFIED]` — file exists but SHA differs; annotated with `(will prompt: y=remove / N=keep / d=diff)`
- `[? MISSING]` — file registered in state but absent on disk; annotated with `(registered but absent on disk)`

This matches the corrected ROADMAP success criterion #2 (`[? MISSING]` not `[?? MISSING]`).

## Task Commits

1. **Task 1: Add 4-group dry-run preview to scripts/uninstall.sh** — `edc28a6` (feat)
2. **Task 2: Add scripts/tests/test-uninstall-dry-run.sh** — `eccf342` (test)

## Files Created/Modified

- `scripts/uninstall.sh` — Added `print_uninstall_dry_run()`, array accumulators, DRY_RUN early-exit, classify_file path fix
- `scripts/tests/test-uninstall-dry-run.sh` — New hermetic test (8 assertions, mode 0755, shellcheck clean)
- `Makefile` — Added Test 21 entry

## Decisions Made

- **classify_file resolves against PROJECT_DIR:** `installed_files[].path` values are project-root-relative (`.claude/commands/foo.md`). Resolving against `CLAUDE_DIR` ($SANDBOX/.claude) produced `.claude/.claude/commands/foo.md` — all files showed as MISSING. Fix: use `PROJECT_DIR` (parent of `CLAUDE_DIR`). Rule 1 auto-fix.
- **KEEP_LIST initialized empty:** Populated by 18-04's interactive [y/N/d] prompt; array accumulator is wired and ready.
- **DRY_RUN placement is permanent:** Acts as a hard gate — all future mutation code (18-03 backup, 18-04 prompts) goes after this block.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] classify_file path resolution: PROJECT_DIR not CLAUDE_DIR**

- **Found during:** Task 1 smoke test
- **Issue:** `installed_files[].path` entries like `.claude/commands/clean.md` are relative to the project root (parent of `.claude/`). `classify_file` resolved them against `CLAUDE_DIR` (`$SANDBOX/.claude`), producing `$SANDBOX/.claude/.claude/commands/clean.md` — a double-`.claude` path. All files appeared MISSING regardless of actual state.
- **Fix:** Changed the relative-path resolution in `classify_file` from `$CLAUDE_DIR/$path` to `$PROJECT_DIR/$path`. `PROJECT_DIR` is already set to `$(dirname "$CLAUDE_DIR")`.
- **Files modified:** `scripts/uninstall.sh` (classify_file function, comment updated)
- **Verification:** Smoke test now correctly shows 1 REMOVE + 1 MODIFIED + 1 MISSING for the 3-entry fixture.
- **Committed in:** `edc28a6` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug: wrong path resolution base in classify_file)
**Impact on plan:** Required for correct classification. No scope creep. All plan acceptance criteria pass.

## Hook Surface for Plans 18-03/18-04

| Symbol | Type | Purpose |
|--------|------|---------|
| `print_uninstall_dry_run()` | function | UN-02 4-group preview; reads outer-scope arrays |
| `REMOVE_LIST` / `MODIFIED_LIST` / `MISSING_LIST` / `KEEP_LIST` | bash arrays | Classification results; KEEP_LIST populated by 18-04 |
| `n_remove` / `n_modified` / `n_missing` / `n_keep` | integers | Array-length counters |
| DRY_RUN early-exit block | code | Permanent gate: after classification, before any mutation |

## Next Phase Readiness

- **18-03 (backup+delete):** Add backup call and delete loop AFTER the `if [[ $DRY_RUN -eq 1 ]]` block; `CLAUDE_DIR`, `STATE_JSON`, `REMOVE_LIST` are all populated and ready
- **18-04 (prompts+state-cleanup):** Populate `KEEP_LIST` from interactive [y/N/d] prompts on `MODIFIED_LIST` entries; `print_uninstall_dry_run` already handles non-empty `KEEP_LIST` via the `[~ KEEP]` group

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `dro_print_file` uses `printf '  %s\n'` which does not interpret escape sequences — control characters in file paths print literally without affecting subsequent output lines (T-18-02-01 mitigated).

---

*Phase: 18-core-uninstall-script-dry-run-backup*
*Completed: 2026-04-26*
