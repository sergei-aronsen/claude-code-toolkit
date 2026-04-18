---
phase: 04-update-flow
fixed_at: 2026-04-18T00:00:00Z
review_path: .planning/phases/04-update-flow/04-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-04-18T00:00:00Z
**Source review:** .planning/phases/04-update-flow/04-REVIEW.md
**Iteration:** 1

**Summary:**

- Findings in scope: 4 (WR-01, WR-02 revised, WR-03, WR-04)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: `remote_tmp` not cleaned up on the `d` (diff) loop iteration

**Files modified:** `scripts/update-claude.sh`
**Commit:** aea881f
**Applied fix:** Added `trap "rm -f '$remote_tmp'" RETURN` immediately after `mktemp` in
`prompt_modified_file`. Removed the three manual `rm -f "$remote_tmp"` calls in the
`y|Y`, TK_UPDATE_FILE_SRC-missing, and curl-failure arms — the RETURN trap covers all
exit paths including repeated `d` loops and abnormal exits under `set -euo pipefail`.

### WR-02: `REMOVED_BY_SWITCH_JSON` surfaces absolute paths, breaking relative-path guard in final-CSV builder

**Files modified:** `scripts/update-claude.sh`
**Commit:** a5f6be5
**Applied fix:** In `execute_mode_switch`, changed the `REMOVED_BY_SWITCH_JSON` assignment
to strip the `CLAUDE_DIR/` prefix via `jq -c --arg base "$CLAUDE_DIR/" '[.[] | ltrimstr($base)]'`
before storing. This ensures paths pushed into `REMOVED_PATHS` (lines 526-529) are
relative strings that match the `grep -Fxq "$rel"` guard in the `FINAL_INSTALLED_CSV`
builder (line 710). `STATE_JSON` update still uses `files_to_remove_abs` (absolute)
which is correct — normalization of `STATE_JSON` paths happens later at line 389.

### WR-03: `STATE_TMP` not registered with the EXIT trap

**Files modified:** `scripts/update-claude.sh`
**Commit:** 86b87fd
**Applied fix:** Added a `trap` update immediately before writing to `STATE_TMP` that
includes `rm -f "$STATE_TMP"` alongside the existing cleanup actions
(`release_lock`, temp file removals). This ensures a SIGKILL between the `jq` write
and the `mv` cannot leave a `toolkit-install.json.tmp.<pid>` orphan on disk.

### WR-04: `is_update_noop` double-counts switch-staged files via stale accumulators

**Files modified:** `scripts/update-claude.sh`
**Commit:** 0f4c581
**Applied fix:** After merging `ADD_FROM_SWITCH_JSON` into `NEW_FILES` and after
`execute_mode_switch` has applied removals to `STATE_JSON`, both accumulators are
reset to `'[]'`. This means conditions 5 and 6 of `is_update_noop` now only fire
if there is genuinely pending switch work not already captured elsewhere — clarifying
intent and eliminating the misleading double-count path described in the review.

---

_Fixed: 2026-04-18T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
