---
phase: 04-update-flow
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - commands/rollback-update.md
  - Makefile
  - scripts/lib/install.sh
  - scripts/tests/fixtures/manifest-update-v2.json
  - scripts/tests/fixtures/toolkit-install-seeded.json
  - scripts/tests/test-update-diff.sh
  - scripts/tests/test-update-drift.sh
  - scripts/tests/test-update-summary.sh
  - scripts/update-claude.sh
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

These files implement the Phase 4 update flow: manifest-driven diff, mode-switch
transaction, no-op detection, backup, and a four-group post-run summary. The
overall architecture is sound and the test harnesses are well-structured. No
security vulnerabilities or data-loss bugs were found; warnings are logic/correctness
issues that can cause silent failures or incorrect state on certain code paths.

---

## Warnings

### WR-01: `remote_tmp` not cleaned up on the `d` (diff) loop iteration

**File:** `scripts/update-claude.sh:569-587`

**Issue:** In `prompt_modified_file`, the `d|D` branch calls `diff` and then
loops back to re-prompt without cleaning up `remote_tmp`. Only the `y|Y` and
default (`N`) arms remove the tempfile. If the user answers `d` followed by
`d` again (or the loop exits abnormally), the tempfile leaks. Under
`set -euo pipefail` the outer script could also be killed between loop
iterations, leaving the tempfile behind permanently.

**Fix:**

```bash
# Register cleanup for remote_tmp immediately after creation, before the loop.
remote_tmp=$(mktemp "${TMPDIR:-/tmp}/remote.XXXXXX")
trap 'rm -f "$remote_tmp"' RETURN   # bash supports RETURN traps in functions

# Remove the manual rm -f calls inside y|Y and N arms (RETURN trap covers them).
```

---

### WR-02: `UPDATED_PATHS` entries are not included in `FINAL_INSTALLED_CSV`

**File:** `scripts/update-claude.sh:706-718`

**Issue:** The `FINAL_INSTALLED_CSV` builder (lines 706-718) iterates
`STATE_JSON.installed_files` (survivors) and `INSTALLED_PATHS` (newly
installed). It does not iterate `UPDATED_PATHS` (files overwritten by the
`y` branch of `prompt_modified_file`). Because `write_state` hashes files
from the CSV, updated files will keep their *pre-update* hash in
`toolkit-install.json`. This means the next run will always treat those
files as "modified" and re-prompt, never reaching the no-op fast path.

**Fix:**

```bash
# After the INSTALLED_PATHS loop, add:
for rel in "${UPDATED_PATHS[@]:-}"; do
    [[ -z "$rel" ]] && continue
    # Already in STATE_JSON.installed_files — will be hashed again by write_state.
    # No duplicate risk because the pre-run rel is stripped below via REMOVED_PATHS guard.
    # But the survivor loop already includes it (it was in state and NOT removed).
    # We only need to ensure the on-disk file is re-hashed, which write_state does
    # automatically when the path is in FINAL_INSTALLED_CSV. Since it comes from
    # STATE_JSON survivors it IS already included — but the hash stored in STATE_JSON
    # was the OLD hash. write_state re-hashes from disk, so survivors are fine.
    # No additional action needed IF write_state is called with the absolute path.
    # Verify: FINAL_INSTALLED_CSV uses "$CLAUDE_DIR/$rel" which triggers re-hash. ✓
done
```

Wait — re-checking: `write_state` re-hashes every path in `FINAL_INSTALLED_CSV`
from disk (see `state.sh:66`). Updated files ARE in `STATE_JSON.installed_files`
(they were not removed), so they ARE included in the survivor loop at line 707.
`write_state` will hash them from disk, picking up the new content. The actual
bug is narrower: if a file was in `UPDATED_PATHS` AND also appears in
`REMOVED_PATHS` (edge case: mode-switch removed it, then separately it was in
`MODIFIED_ACTUAL`), the `grep -Fxq` guard at line 710 would skip it. That
scenario is unlikely but indicates the removal guard should compare relative
paths consistently. Flag as info instead — see IN-01.

**Revised severity: Info** — see IN-01 below. Removing WR-02 from warnings.

---

### WR-02 (revised): `REMOVED_BY_SWITCH_JSON` surfaces absolute paths in `REMOVED_PATHS`, but removal guard in final-CSV builder uses relative-path comparison

**File:** `scripts/update-claude.sh:523-527` and `706-712`

**Issue:** `execute_mode_switch` pushes absolute paths into
`REMOVED_BY_SWITCH_JSON` (the `jq` expression produces absolute paths via
`$iabs`). These are later appended to `REMOVED_PATHS` (lines 524-527). In
`FINAL_INSTALLED_CSV`, the guard at line 710 compares relative `rel` from
`STATE_JSON.installed_files` against entries in `REMOVED_PATHS` with
`grep -Fxq`. If `REMOVED_PATHS` holds absolute paths like
`/tmp/tk-update-drift.XXX/s5/.claude/commands/plan.md`, and `rel` is the
relative path `commands/plan.md`, the comparison fails and the removed file is
re-added to `FINAL_INSTALLED_CSV` — writing a ghost entry that points to a
deleted file. On the next write_state call the file will not be found on disk
and will be recorded with `sha256: ""` (state.sh:68-69), silently corrupting
the state.

**Fix:**

```bash
# Normalize REMOVED_PATHS to relative paths before the FINAL_INSTALLED_CSV loop.
# Mode-switch removed paths are already stripped to relative by the log line
# (${abs_path#"$CLAUDE_DIR/"}) but REMOVED_PATHS receives the raw rel value
# from the manifest-driven removed-files path (which IS relative).
# Fix execute_mode_switch to push stripped paths:

while IFS= read -r abs_path; do
    [[ -z "$abs_path" ]] && continue
    local rel_path="${abs_path#"$CLAUDE_DIR/"}"
    if [[ -f "$abs_path" ]]; then
        rm -f "$abs_path"
        log_info "mode-switch removed: $rel_path"
    fi
    REMOVED_BY_SWITCH_JSON_REL+=("$rel_path")   # collect relative
done < <(jq -r '.[]' <<<"$files_to_remove_abs")

# Then surface to REMOVED_PATHS as relative strings.
```

---

### WR-03: `STATE_TMP` is not registered with the EXIT trap, risking a leftover temp file on hard kill

**File:** `scripts/update-claude.sh:733-735`

**Issue:** The final manifest-hash patch writes `STATE_TMP="${STATE_FILE}.tmp.$$"` and `mv`s it atomically. If the script is killed between `jq` writing to `STATE_TMP` and `mv` completing (SIGKILL, power loss), `STATE_TMP` is left on disk. Because the name includes `$$` it cannot be cleaned up by a subsequent run. For toolkit files in `~/.claude/` this is minor, but a leftover `.json.tmp.<pid>` file adjacent to `toolkit-install.json` could confuse state readers.

**Fix:**

```bash
STATE_TMP="${STATE_FILE}.tmp.$$"
# Register cleanup before writing:
trap 'rm -f "$STATE_TMP"; release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$MANIFEST_TMP"' EXIT
jq --arg mh "$MANIFEST_HASH" '. + { manifest_hash: $mh }' "$STATE_FILE" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE_FILE"
```

---

### WR-04: `is_update_noop` checks `ADD_FROM_SWITCH_JSON` and `REMOVED_BY_SWITCH_JSON` but these are never empty when mode drifted even if mode-switch was declined

**File:** `scripts/update-claude.sh:193-204`

**Issue:** `ADD_FROM_SWITCH_JSON` and `REMOVED_BY_SWITCH_JSON` are initialized
to `'[]'` and only mutated inside `execute_mode_switch`. When a mode drift is
detected but the user declines the switch (the `Keeping current mode` path),
those variables stay `'[]'`. The no-op check then evaluates them as empty arrays
which is correct for that branch. However, there is a subtle ordering issue: the
no-op check at line 418 is called *after* the manifest-driven diff block and
*after* `MODIFIED_ACTUAL` is computed, but `ADD_FROM_SWITCH_JSON` was already
merged into `NEW_FILES` at line 407. If `execute_mode_switch` ran and set
`ADD_FROM_SWITCH_JSON` to a non-empty value (mode switch accepted), then
`NEW_FILES` will be non-empty, so `is_update_noop` returns 1 at line 195 —
correctly. But the condition at line 199 re-reads `ADD_FROM_SWITCH_JSON`
directly, which is still the original value from `execute_mode_switch`, not the
merged `NEW_FILES`. This means `is_update_noop` double-counts switch-staged
files: they appear in `NEW_FILES` (condition 2) AND `ADD_FROM_SWITCH_JSON`
(condition 5). The no-op is correctly blocked in both paths, but the intent
described in the comment (condition 5 = "files staged by mode switch not yet
applied") is misleading and the redundant check could shadow future refactors.

**Fix:**

```bash
# After merging ADD_FROM_SWITCH_JSON into NEW_FILES, reset it to [] so
# is_update_noop condition 5 only triggers if there is pending switch work
# not already captured in NEW_FILES (currently there is none — they are merged).
# Document the intent explicitly:
ADD_FROM_SWITCH_JSON='[]'   # merged into NEW_FILES above; condition 5 is now redundant
REMOVED_BY_SWITCH_JSON='[]' # removals are reflected in STATE_JSON after execute_mode_switch
```

Alternatively, remove conditions 5 and 6 from `is_update_noop` since they are
always `[]` by the time the function is called (post-merge, post-execute).

---

## Info

### IN-01: Dead comment in `Makefile` validate target refers to `SECURITY_AUDIT.md` but test suite exercises update-flow scripts

**File:** `Makefile:93-109`

**Issue:** The `validate` target greps `templates -path '*/prompts/*.md'` for
`PERFORMANCE_AUDIT.md`, `CODE_REVIEW.md`, and `DEPLOY_CHECKLIST.md`. None of
these files exist in the repo's `templates/` tree based on the project
structure described in `CLAUDE.md` (the audit file name referenced in tests is
`SECURITY_AUDIT.md`). If those three files don't exist, the `for` loop silently
produces zero iterations and the validate target always passes regardless of
template integrity.

**Fix:** Either add the three audit files at the expected paths, or update the
glob pattern to match the files that actually exist (`SECURITY_AUDIT.md`).

---

### IN-02: `MANIFEST_URL` declared but unused after Phase 4

**File:** `scripts/update-claude.sh:37`

**Issue:** `MANIFEST_URL` is defined and has a `# shellcheck disable=SC2034` to
suppress the unused-variable warning, with a comment saying "Plan 04-02 removes
it." It was not removed in this phase. It occupies space and the `shellcheck`
suppress directive masks future accidental re-introduction of raw URL usage.

**Fix:** Remove the variable and its disable comment now that Plan 04-02 is
complete.

---

### IN-03: `sdk_state_file` fixture (`toolkit-install-seeded.json`) uses all-zero SHA256 hashes

**File:** `scripts/tests/fixtures/toolkit-install-seeded.json:9-13`

**Issue:** All four `sha256` values are the all-zeros sentinel
`0000000000000000000000000000000000000000000000000000000000000000`. The
Scenario 5 drift test (`test-update-drift.sh:231-241`) injects this fixture with
absolute path overrides and relies on mode-switch logic, not hash comparison. If
a future test scenario reads `.sha256` and compares against real file content, it
will always see a divergence (the file will never hash to all-zeros), producing
false "modified" classification. The fixture intent should be documented.

**Fix:** Add a comment in the fixture or a sibling `README` clarifying that
all-zero hashes are intentional sentinels used only for mode-switch tests where
hash accuracy is irrelevant.

---

### IN-04: `test-update-diff.sh` scenario 5 FIFO approach has a subtle race

**File:** `scripts/tests/test-update-diff.sh:295-313`

**Issue:** A background `(echo "y" > "$FIFO") &` is spawned before the main
`update-claude.sh` process reads from the FIFO. If the main process opens
`/dev/tty` for input rather than the redirected stdin, the background writer
will block indefinitely on the FIFO write until its timeout or the FIFO is
collected by the `EXIT` trap. This is noted in the test comment
("Either is acceptable"). However, `BG_PID` is `wait`ed at line 314 —
if the FIFO writer never unblocks (because `/dev/tty` was opened), `wait`
can hang the test indefinitely in environments where the test process has
a controlling terminal.

**Fix:**

```bash
# Cap the background writer wait time:
wait "$BG_PID" 2>/dev/null || true
# Add a guard to kill the BG process if it outlives a reasonable window:
(echo "y" > "$FIFO") & BG_PID=$!
# After the main command finishes:
kill "$BG_PID" 2>/dev/null || true
wait "$BG_PID" 2>/dev/null || true
```

---

### IN-05: `print_update_summary` format string for `REMOVED` unconditionally prints `backed up to <dir>`, even when `backup_dir` is empty

**File:** `scripts/update-claude.sh:245`

**Issue:** `print_update_summary` is always called with `$BACKUP_DIR` which is
always set (the backup is created before any dispatch). However, in the no-op
path the function is never called, and in a future refactor where the backup
step is skipped (e.g., a `--no-backup` flag), `backup_dir` could be empty, and
the summary line would read `(backed up to )`. Minor, but worth defensive
handling.

**Fix:**

```bash
if [[ -n "$backup_dir" ]]; then
    printf '%bREMOVED %d%b (backed up to %s)\n' "$_R" "$n_rem" "$_NC" "$backup_dir"
else
    printf '%bREMOVED %d%b\n' "$_R" "$n_rem" "$_NC"
fi
```

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
