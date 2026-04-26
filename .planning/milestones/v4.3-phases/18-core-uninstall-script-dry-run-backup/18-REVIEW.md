---
phase: 18-core-uninstall-script-dry-run-backup
reviewed: 2026-04-26T09:53:22Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Makefile
  - scripts/lib/backup.sh
  - scripts/tests/test-uninstall-backup.sh
  - scripts/tests/test-uninstall-dry-run.sh
  - scripts/tests/test-uninstall-prompt.sh
  - scripts/uninstall.sh
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-04-26T09:53:22Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 18 implements UN-01..UN-04 for `scripts/uninstall.sh`: dry-run preview,
backup-before-delete, hash-matched deletion, and the [y/N/d] prompt loop for
modified files. The architecture is sound — the test seam design (`TK_UNINSTALL_HOME`,
`TK_UNINSTALL_LIB_DIR`, `TK_UNINSTALL_TTY_FROM_STDIN`) isolates sandbox runs cleanly,
and the zero-mutation dry-run contract is correctly enforced by exiting before any
backup/lock/delete logic. Two warnings were found: both relate to the
`is_protected_path` defense-in-depth layer receiving relative paths and producing a
double-`.claude` path segment that causes the base-plugin protection check to silently
misfire. Neither bug is reachable through the primary classification path
(`classify_file` always passes absolute paths), but they defeat the stated intent of
the secondary safety net.

## Warnings

### WR-01: `is_protected_path` receives relative paths at delete time, breaking the defense-in-depth check

**File:** `scripts/uninstall.sh:437`

**Issue:** The UN-01 delete loop calls `is_protected_path "$rel"` where `$rel` is the
raw relative path from `installed_files[].path` (e.g.
`.claude/get-shit-done/plugin.md`). `is_protected_path` resolves relative paths by
prepending `$CLAUDE_DIR` (line 145), producing a double-`.claude` path:
`$HOME/.claude/.claude/get-shit-done/plugin.md`. This path does not match the
protection pattern `"$HOME"/.claude/get-shit-done/*` (line 156), so `is_protected_path`
returns 1 (not protected) for any relative path to a base-plugin file. The comment at
line 436 explicitly claims this is a defense-in-depth invariant for UN-01; the
invariant does not hold for relative paths.

The primary guard in `classify_file` passes an absolute path to `is_protected_path`
(line 179) and correctly classifies protected files as `PROTECTED`, so they never
reach `REMOVE_LIST`. The bug is only reachable through state corruption or future
code that populates `REMOVE_LIST` directly. Nevertheless, a defense-in-depth check
that silently fails is worse than no check.

**Fix:** Resolve the relative path to absolute against `PROJECT_DIR` before calling
`is_protected_path` in the delete loop, matching how `classify_file` does it:

```bash
# In the UN-01 delete loop (around line 437):
# Replace:
if is_protected_path "$rel"; then

# With:
abs_check="$rel"
case "$rel" in
    /*) : ;;
    *)  abs_check="$PROJECT_DIR/$rel" ;;
esac
if is_protected_path "$abs_check"; then
```

---

### WR-02: `is_protected_path` defense-in-depth check in `prompt_modified_for_uninstall` has the same relative-path bug

**File:** `scripts/uninstall.sh:222`

**Issue:** `prompt_modified_for_uninstall` calls `is_protected_path "$rel"` at line
222 with the original relative path from the state file. The same double-`.claude`
resolution described in WR-01 applies here: `is_protected_path` prepends `CLAUDE_DIR`
to a relative path already containing `.claude/`, producing a path like
`$SANDBOX/.claude/.claude/get-shit-done/file.md` that does not match the GSD
protection pattern. In theory, `classify_file` would classify a GSD file as
`PROTECTED` and never add it to `MODIFIED_LIST`, so this prompt function would never
be called for such a file. The function comment says "Defense-in-depth: never prompt
on a protected path"; that guarantee cannot be relied upon for relative paths.

**Fix:** Same pattern as WR-01 — resolve to absolute before the call:

```bash
# Replace line 222:
if is_protected_path "$rel"; then

# With:
_abs_rel="$rel"
case "$rel" in /*) : ;; *) _abs_rel="$PROJECT_DIR/$rel" ;; esac
if is_protected_path "$_abs_rel"; then
```

---

## Info

### IN-01: `classify_file` doc comment lists `KEEP` as a possible return value but the function never returns it

**File:** `scripts/uninstall.sh:162`

**Issue:** The comment block at lines 162-166 documents five possible stdout values:
`REMOVE | KEEP | MODIFIED | MISSING | PROTECTED`. The function body (lines 173-198)
never emits `KEEP`. The corresponding `KEEP)` arm in the classification while-loop at
line 375 is dead code. Stale documentation causes confusion when reading the function
contract and could lead a future author to assume `KEEP_LIST` is pre-populated by
classification.

**Fix:** Remove `KEEP` from the comment's return-value list and remove the dead arm
from the while-loop:

```bash
# Line 162 comment — change to:
# Stdout: one of: REMOVE | MODIFIED | MISSING | PROTECTED

# Line 375 — remove dead arm:
# KEEP) KEEP_LIST+=("$path") ;;   ← delete this line
```

---

### IN-02: `test-uninstall-dry-run.sh` does not pass `HOME=$SANDBOX` to the uninstall invocation

**File:** `scripts/tests/test-uninstall-dry-run.sh:119`

**Issue:** The dry-run test exports `TK_UNINSTALL_HOME="$SANDBOX"` but invokes
`bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run` without setting `HOME="$SANDBOX"`.
The backup and prompt tests both pass `HOME="$SANDBOX"` to their invocations. In the
current implementation this is safe: dry-run exits at line 392 before any code path
that reads `$HOME` for lock, backup, or protection checks. However, the omission is
an inconsistency that would silently fail if future code added `$HOME`-relative logic
before the dry-run exit point.

**Fix:** Add `HOME="$SANDBOX"` to the invocation for consistency with the other two
test scripts and to future-proof the test isolation:

```bash
# Replace line 119:
OUTPUT=$(bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1) || RC=$?

# With:
OUTPUT=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1) || RC=$?
```

---

_Reviewed: 2026-04-26T09:53:22Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
