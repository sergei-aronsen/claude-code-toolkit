---
phase: 18-core-uninstall-script-dry-run-backup
plan: 04
subsystem: infra
tags: [uninstall, shell, bash, interactive-prompt, yn-prompt, tty, test, un-03, bash32]

requires:
  - phase: 18-core-uninstall-script-dry-run-backup
    plan: 03
    provides: scripts/uninstall.sh backup+delete loop, MODIFIED_LIST, DELETED_LIST, KEEP_LIST arrays
provides:
  - scripts/uninstall.sh: prompt_modified_for_uninstall() function + MODIFIED_LIST iteration loop
  - scripts/tests/test-uninstall-prompt.sh: 10-assertion hermetic proof of UN-03 [y/N/d] branches
affects: []

tech-stack:
  added: []
  patterns:
    - "TK_UNINSTALL_TTY_FROM_STDIN seam: redirects read from /dev/tty to /dev/stdin for hermetic test injection"
    - "TK_UNINSTALL_FILE_SRC seam: points to parent of .claude/ so $TK_UNINSTALL_FILE_SRC/$rel resolves correctly"
    - "while :; do ... done re-entrant loop: d branch re-enters prompt without returning — loop body handles diff render"
    - "trap 'rm -f ...' RETURN inside function: reference_tmp cleaned on every return path"
    - "bash 3.2 array-length guard preserved: if [[ ${#MODIFIED_LIST[@]} -gt 0 ]] — no inline [@]:- default"
    - "NO local keyword in MAIN block; local permitted (and used) inside function bodies (SC2168 clean)"

key-files:
  created:
    - scripts/tests/test-uninstall-prompt.sh
  modified:
    - scripts/uninstall.sh
    - scripts/tests/test-uninstall-backup.sh
    - Makefile

key-decisions:
  - "TK_UNINSTALL_FILE_SRC must point to parent of .claude/ — state file paths are .claude/commands/..., so the seam dir is resolved as $TK_UNINSTALL_FILE_SRC/$rel which already includes .claude/ in the rel"
  - "test-uninstall-backup.sh A10 updated from 'KEPT (modified) 1' to 'KEPT 1' — 18-04 prompt loop now runs even in non-interactive test (fail-closed N on /dev/tty unavailable → KEEP_LIST)"
  - "Reference content for diff must differ materially from live content — trivial diff (identical bytes) causes A7 to fail, proving the test fixture actually exercises the diff path"

requirements-completed:
  - UN-03

duration: ~8min
completed: 2026-04-26
---

# Phase 18 Plan 04: UN-03 [y/N/d] Interactive Prompt for Modified Files

**`prompt_modified_for_uninstall()` + MODIFIED_LIST loop added to `scripts/uninstall.sh`. Every MODIFIED file triggers a re-entrant `[y/N/d]` prompt: `y` removes, `N` (default) keeps, `d` shows non-trivial diff and re-prompts. Reads `/dev/tty`; fail-closed `N` when unavailable. `test-uninstall-prompt.sh` proves all three branches via stdin injection — 10 assertions pass including A7 (W2 closure: diff body non-empty).**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-26T09:37:49Z
- **Completed:** 2026-04-26T09:45:50Z
- **Tasks:** 2
- **Files modified:** 3 (uninstall.sh, test-uninstall-backup.sh, Makefile)
- **Files created:** 1 (test-uninstall-prompt.sh)

## prompt_modified_for_uninstall Structure

```text
prompt_modified_for_uninstall() {
    1. Resolve rel → abs path via PROJECT_DIR (not CLAUDE_DIR)
    2. Defense-in-depth: is_protected_path() check → KEEP_LIST + return
    3. Build reference_tmp via seam (TK_UNINSTALL_FILE_SRC) or curl
    4. Set tty_target: /dev/tty (prod) or /dev/stdin (TK_UNINSTALL_TTY_FROM_STDIN)
    5. while :; do
         read -r -p "[y/N/d]:" choice < "$tty_target" || choice="N"  # fail-closed
         case "${choice:-N}":
           y|Y) rm -f; DELETED_LIST+=; return 0
           d|D) diff -u local reference (or "unavailable" message); loop continues
           *)   KEEP_LIST+=; return 0
       done
}
```

## TK_UNINSTALL_TTY_FROM_STDIN Test Seam Contract

| Variable | Value in prod | Value in test | Effect |
|----------|--------------|---------------|--------|
| `TK_UNINSTALL_TTY_FROM_STDIN` | unset | `1` | `tty_target` = `/dev/stdin` instead of `/dev/tty` |
| `TK_UNINSTALL_FILE_SRC` | unset | `$SANDBOX/.reference` | Reference dir for `d`-branch diff content |

`TK_UNINSTALL_FILE_SRC/$rel` must resolve to the reference file. Since `$rel` is the state-file path (e.g., `.claude/commands/diff-then-keep.md`), `TK_UNINSTALL_FILE_SRC` must point to the **parent of `.claude/`**, not inside `.claude/`. The reference file lives at `$TK_UNINSTALL_FILE_SRC/.claude/commands/diff-then-keep.md`.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add prompt_modified_for_uninstall + MODIFIED_LIST loop | `b192d12` | scripts/uninstall.sh, scripts/tests/test-uninstall-backup.sh |
| 2 | Add test-uninstall-prompt.sh (10 assertions) | `3c65cf0` | scripts/tests/test-uninstall-prompt.sh |
| — | Makefile Test 23 entry | `bfd9b3c` | Makefile |

## Test Transcript — test-uninstall-prompt.sh (all 10 assertions)

```text
Assertions:
  OK A1: uninstall exits 0
  OK A2: commands/yes-remove.md DELETED (y branch)
  OK A3: commands/diff-then-keep.md KEPT (d → N branch)
  OK A4: commands/empty-default.md KEPT (default N branch)
  OK A5: output contains diff header '── diff: local vs reference'
  OK A6: output contains diff footer '── end diff ──'
  OK A7: diff body has non-header +/- lines (non-trivial diff — W2 closed)
  OK A8: output contains 'KEPT 2' (2 files kept)
  OK A9: output contains 'DELETED 1' (1 file removed)
  OK A10: exactly 1 .claude-backup-pre-uninstall-* dir created (UN-04)

✓ test-uninstall-prompt: all 10 assertions passed
```

## W2 Closure — A7 Non-Trivial Diff Assertion

The plan required that the reference content be **materially different** from the live content so the `diff -u` output is non-trivially empty. The fixture writes:

- **Live**: `user-edited diff-then-keep — LIVE VERSION`
- **Reference**: `pristine reference content for diff-then-keep\nsecond line in reference only`

A7 strips diff-u header lines (`+++`/`---`) and asserts at least one body line starts with `+` or `-`:

```bash
DIFF_BODY=$(printf '%s\n' "$OUTPUT" \
    | awk '/── diff: local vs reference/{p=1; next} /── end diff ──/{p=0} p' \
    | grep -E '^[+-]' \
    | grep -vE '^(\+\+\+|---)' || true)
[ -n "$DIFF_BODY" ] || { echo "✗ A7: diff body empty"; exit 1; }
```

## Cross-Test Smoke Summary

All three uninstall test scripts pass green from the current state:

```text
✓ test-uninstall-dry-run: all 8 assertions passed
✓ test-uninstall-backup: all 12 assertions passed
✓ test-uninstall-prompt: all 10 assertions passed
```

Total: 30 assertions across 3 test scripts, all green.

## Phase 18 Deliverable — UN-01..UN-04 Complete

| Req | Description | Delivered by |
|-----|-------------|-------------|
| UN-01 | Delete only hash-matched files (REMOVE_LIST) | 18-01 classify_file + 18-03 delete loop |
| UN-02 | --dry-run zero-mutation preview | 18-02 print_uninstall_dry_run |
| UN-03 | [y/N/d] prompt for MODIFIED files; default N; d re-prompts | **18-04 (this plan)** |
| UN-04 | Backup CLAUDE_DIR before any rm | 18-03 cp -R backup + snapshot |

Phase 19 picks up UN-05 (state cleanup: toolkit-install.json removal) and UN-06 (CLAUDE.md sentinel block removal).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TK_UNINSTALL_FILE_SRC path level fix**

- **Found during:** Task 2 test execution
- **Issue:** Test set `TK_UNINSTALL_FILE_SRC="$SANDBOX/.reference/.claude"` but function resolves `$TK_UNINSTALL_FILE_SRC/$rel` where `$rel` is `.claude/commands/diff-then-keep.md` — producing a double `.claude` path that didn't exist → "Reference unavailable" → A5/A6/A7 fail.
- **Fix:** Changed `TK_UNINSTALL_FILE_SRC` to point at `$SANDBOX/.reference` (parent of `.claude/`), placed reference file at `$SANDBOX/.reference/.claude/commands/diff-then-keep.md`. Updated both the `export` line and the invocation block in the test. Added explanatory comment to the test documenting the path resolution contract.
- **Files modified:** `scripts/tests/test-uninstall-prompt.sh`
- **Commit:** `3c65cf0`

**2. [Rule 1 - Regression] test-uninstall-backup.sh A10 updated for 18-04 behavior**

- **Found during:** Task 1 — 18-03 test asserts `KEPT (modified) 1` in summary, but 18-04 replaces that placeholder with the real `[y/N/d]` prompt loop which runs even in non-interactive tests (fail-closed N → KEEP_LIST → outputs `KEPT 1`).
- **Fix:** Updated A10 in `test-uninstall-backup.sh` to assert `KEPT 1` (the new output format) instead of `KEPT (modified) 1` (18-03 placeholder).
- **Files modified:** `scripts/tests/test-uninstall-backup.sh`
- **Commit:** `b192d12`

---

**Total deviations:** 2 auto-fixed (Rule 1 — both correctness fixes, no scope creep)

## Threat Surface Scan

T-18-04-05 (TK_UNINSTALL_TTY_FROM_STDIN seam abused in production): mitigated — documented inline as CI/test-only seam matching existing TK_*_LIB_DIR / TK_*_FILE_SRC convention. Redirect only changes WHERE the prompt reads from; no security impact in itself.

No new network endpoints, auth paths, or schema changes introduced. `diff -u` renders reference content to terminal (read-only, not executed). T-18-04-02 (curl-fetched reference shown via diff): accepted per threat model — user adjudicates; content is never executed.

---

*Phase: 18-core-uninstall-script-dry-run-backup*
*Completed: 2026-04-26*
