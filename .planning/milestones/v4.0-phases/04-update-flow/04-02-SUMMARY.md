---
phase: 04-update-flow
plan: "02"
subsystem: update-flow
tags: [manifest-driven, file-diffs, skip-set, new-files, removed-files, modified-files, sha256, bug-07-structural-fix, b3-atomic]

# Dependency graph
requires:
  - "04-01 (STATE_JSON, STATE_MODE, MANIFEST_TMP, ADD_FROM_SWITCH_JSON, REMOVED_BY_SWITCH_JSON)"
provides:
  - "compute_file_diffs_obj helper in scripts/lib/install.sh (new/removed/modified_candidates JSON)"
  - "INSTALLED_PATHS shell array: paths successfully installed in this update run"
  - "UPDATED_PATHS shell array: paths overwritten after [y] on modified-file prompt"
  - "SKIPPED_PATHS shell array: entries as 'path:reason' strings"
  - "REMOVED_PATHS shell array: paths deleted (manifest-removed or mode-switch-removed)"
  - "Manifest-driven install dispatch invariant: no hand-maintained file lists in update-claude.sh"
  - "TK_UPDATE_FILE_SRC test seam for hermetic file-src injection"
  - "Path normalization: installed_files paths normalized to relative before compute_file_diffs_obj"
affects:
  - plans/04-03 (summary printer + write_state consume INSTALLED_PATHS/UPDATED_PATHS/SKIPPED_PATHS/REMOVED_PATHS)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "compute_file_diffs_obj: single-object JSON form (new/removed/modified_candidates) — bash 3.2 safe, one jq call"
    - "B3 atomic commit: hand-list deletion + Makefile drift-check simplification in same commit so make check stays green"
    - "W2 SKIPPED_PATHS formula: (manifest - installed) intersect skip_set — not full skip_set, avoids tracking previously-installed files as skipped"
    - "Path normalization before compute_file_diffs_obj: ltrimstr(CLAUDE_DIR/) bridges write_state absolute paths vs manifest relative paths"
    - "TK_UPDATE_FILE_SRC test seam: allows hermetic tests without network; production never sets this var"
    - "prompt_modified_file: inline helper in update-claude.sh (not lib/install.sh) — needs direct access to STATE_JSON, UPDATED_PATHS, SKIPPED_PATHS, CLAUDE_DIR"

key-files:
  created:
    - .planning/phases/04-update-flow/04-02-SUMMARY.md
  modified:
    - scripts/lib/install.sh
    - scripts/update-claude.sh
    - scripts/tests/test-update-diff.sh
    - scripts/tests/test-update-drift.sh
    - Makefile

key-decisions:
  - "B3 rationale: Makefile drift-check simplification MUST land in same commit as hand-list deletion. Between commits, make validate walks update-claude.sh for 'for file in .../commands' — after deletion that line is gone, LOOP_CMDS goes empty, and every manifest command is flagged as missing. Keeping them in separate commits breaks CI between commits."
  - "W2 SKIPPED_PATHS formula: skip_set includes ALL paths conflicting with a plugin (e.g. all SP-conflict paths). If a previously-installed SP-conflict file is tracked in installed_files, it belongs in the removed-files path (user already has it), not in SKIPPED_PATHS. Formula: (manifest - installed) intersect skip_set — only would-be-new files that get filtered."
  - "TK_UPDATE_FILE_SRC seam rationale: CI machines lack network access to raw.githubusercontent.com. A local file-src override lets 7 scenarios run hermetically without mocking curl. Production never sets this var (documented in script header)."
  - "prompt_modified_file scope: inline in update-claude.sh (not moved to lib/install.sh) because it needs direct closure access to STATE_JSON, INSTALLED_PATHS, UPDATED_PATHS, SKIPPED_PATHS, CLAUDE_DIR. Moving it to lib would require passing 6+ parameters or exposing globals — more complexity with no benefit."
  - "Path normalization timing: ltrimstr(CLAUDE_DIR/) applied AFTER execute_mode_switch completes. execute_mode_switch relies on absolute paths in STATE_JSON (installed_abs) for direct rm -f. Normalizing before it would break the rm targets. Normalizing after is safe because compute_file_diffs_obj is called after the drift/mode-switch block."

# Metrics
duration: 95min
completed: 2026-04-18
---

# Phase 4 Plan 02: Manifest-Driven File-Diff Dispatch Summary

**Deleted all hand-maintained file-list loops from update-claude.sh; replaced with compute_file_diffs_obj-based manifest-driven dispatch for new/removed/modified files (UPDATE-02/03/04)**

## Performance

- **Duration:** approx 95 min
- **Started:** 2026-04-18T18:30:00Z
- **Completed:** 2026-04-18T19:33:52Z
- **Tasks:** 3 (feat + refactor B3 atomic + test)
- **Files modified:** 5

## Accomplishments

- Added `compute_file_diffs_obj` helper to `scripts/lib/install.sh` with exact signature `<state_json> <manifest_path> <mode>`; emits single JSON object with `.new`, `.removed`, `.modified_candidates`
- Deleted 5 hand-maintained file-list loops from `scripts/update-claude.sh` (agents, prompts, skills, commands, rules — ~72 lines)
- Wired manifest-driven install loop: new files auto-install (D-54); removed-files batch prompt (D-55); modified-files per-file `[y/N/d]` prompt (D-56)
- Simplified `Makefile` drift check from command-list comparison to structural guard: `grep -q 'compute_file_diffs_obj'`
- Added `TK_UPDATE_FILE_SRC` test seam for hermetic tests
- Added path normalization (ltrimstr `$CLAUDE_DIR/`) between drift/mode-switch block and `compute_file_diffs_obj` call
- Filled `test-update-diff.sh` with 7 real scenarios — Test 10 GREEN (13/13 pass)
- Fixed `test-update-drift.sh` scenario 5 assertion: `commands/debug.md` now correctly flagged as SP-conflict (deleted by mode-switch); test-update-drift.sh Test 9 now 14/14 pass

## Task Commits

1. **Task 1:** `9c6113d` — `feat(04-02): add compute_file_diffs_obj to lib/install.sh`
2. **Task 2 (B3 atomic):** `63b0559` — `refactor(04-02): delete hand-lists at update-claude.sh:117-188 + simplify Makefile drift check to structural guard (UPDATE-02/03/04, B3 atomic)`
3. **Task 3:** `c77996c` — `test(04-02): add TK_UPDATE_FILE_SRC seam + fill test-update-diff.sh (UPDATE-02/03/04 GREEN)`

## Files Created/Modified

- `scripts/lib/install.sh` — added `compute_file_diffs_obj` function (20 lines)
- `scripts/update-claude.sh` — deleted 5 hand-maintained loops; added manifest-driven dispatch (new/removed/modified); added path normalization; added `--prune` flag; added `INSTALLED_PATHS/UPDATED_PATHS/SKIPPED_PATHS/REMOVED_PATHS` arrays; `TEMPLATE_URL` retained for CLAUDE.md smart-merge block
- `scripts/tests/test-update-diff.sh` — replaced 7 stub scenarios with 7 real integration scenarios (Test 10 GREEN)
- `scripts/tests/test-update-drift.sh` — updated scenario 5 assertion: `debug.md` correctly deleted (SP-conflict), assertion changed from "preserved" to "deleted"
- `Makefile` — lines 117-137 replaced with structural grep guard (7 lines vs 21 lines)

## Decisions Made

**1. B3 atomic Makefile+hand-list deletion**

Makefile line 117-137 walked `update-claude.sh` for `for file in .../commands` to extract the command list, then compared against `manifest.json`. After deleting the hand-lists, `LOOP_LINE` goes empty and every manifest command fires `ERRORS+=1`. Keeping them in separate commits would break `make check` between commits. Solution: one atomic commit deletes the hand-list loops AND replaces the drift check with a structural `grep -q 'compute_file_diffs_obj'` guard.

**2. W2 SKIPPED_PATHS formula**

The skip_set for `complement-sp` mode is `[commands/debug.md, commands/plan.md, commands/tdd.md, ...]`. If these are already installed (in `installed_files`), they belong in the `removed-files` path — the user has them and they're now conflict. Tracking all of `skip_set` in `SKIPPED_PATHS` would double-count and confuse the Plan 04-03 summary. Formula: `(manifest - installed) intersect skip_set` — only files that would be new but are filtered by mode.

**3. TK_UPDATE_FILE_SRC seam**

CI environments lack network access to `raw.githubusercontent.com`. The seam lets test scenarios point at a local directory of fixture files. Implementation: single env var check before `curl` in both the new-file loop and the modified-file remote-fetch. Zero impact on production (var never set). Documented in script header comment.

**4. prompt_modified_file inline vs lib**

The function needs direct access to `STATE_JSON` (jq lookup of stored sha256), `UPDATED_PATHS`/`SKIPPED_PATHS` (array appends), `CLAUDE_DIR` (file path construction), and `TK_UPDATE_FILE_SRC` (test seam). Moving it to `lib/install.sh` would require passing 6+ parameters or introducing global conventions not established in Phase 3. Inline in `update-claude.sh` is the minimal-complexity choice per KISS.

**5. Path normalization placement**

`execute_mode_switch` uses `installed_abs` (absolute paths from state) to build `rm -f` targets. Normalizing `STATE_JSON` before this function would break rm targets. Normalization is placed AFTER the drift/mode-switch block — `STATE_JSON` still has absolute paths during execute_mode_switch, then becomes relative before `compute_file_diffs_obj`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] execute_mode_switch + path normalization timing**

- **Found during:** Task 3 (test-update-drift.sh scenario 5 failure)
- **Issue:** `compute_file_diffs_obj` received `STATE_JSON` with absolute paths (e.g., `/tmp/xxx/.claude/commands/debug.md`) while manifest had relative paths (e.g., `commands/debug.md`). The set subtraction produced wrong `.new`/`.removed`/`.modified_candidates` — all installed files appeared as "removed" from manifest.
- **Fix:** Added path normalization (`jq ltrimstr($CLAUDE_DIR/)`) on `STATE_JSON.installed_files[].path` AFTER the drift/mode-switch block and BEFORE `compute_file_diffs_obj`.
- **Files modified:** `scripts/update-claude.sh`
- **Committed in:** `c77996c`

**2. [Rule 1 - Bug] test-update-drift.sh scenario 5 wrong assertion**

- **Found during:** Task 3 (after path normalization fix, `commands/debug.md` still deleted)
- **Issue:** `manifest-update-v2.json` has `commands/debug.md` with `"conflicts_with": ["superpowers"]`. Plan 04-01's scenario 5 comment said "debug.md does not conflict" but the fixture disagrees. Plan 04-01 used log-line assertions (not file-absence) to avoid this, because legacy re-download loops would re-create deleted files. Plan 04-02 deleted those loops, making file-absence assertions stable. The assertion was now wrong.
- **Fix:** Changed `assert_eq "true" (debug.md preserved)` to `assert_eq "false" (debug.md deleted — SP-conflict)`.
- **Files modified:** `scripts/tests/test-update-drift.sh`
- **Committed in:** `c77996c`

**3. [Rule 3 - Blocking] TEMPLATE_URL unbound variable**

- **Found during:** Task 2 (end-to-end test of update-claude.sh)
- **Issue:** Deleting the hand-list section removed `TEMPLATE_URL="$REPO_URL/templates/$FRAMEWORK"` which is still used by the CLAUDE.md smart-merge block. `set -euo pipefail` aborted the script at that line.
- **Fix:** Added `TEMPLATE_URL="$REPO_URL/templates/$FRAMEWORK"` immediately after `FRAMEWORK=$(detect_framework)`.
- **Files modified:** `scripts/update-claude.sh`
- **Committed in:** `63b0559`

## Hand-Lists Deletion Audit

```text
grep -c "for file in agents/\|for file in prompts/\|for skill in\|for file in .*\.md$" scripts/update-claude.sh
```

Result: **0** — no hand-maintained file lists remain in `scripts/update-claude.sh`.

## Gate Verification Output

```text
make shellcheck:  ✅ ShellCheck passed
make validate:    ✅ Version aligned: 3.0.0
                  ✅ update-claude.sh is manifest-driven (no hand-maintained file lists)
                  ✅ All templates valid
                  ✅ Manifest schema valid

bash scripts/tests/test-update-drift.sh:  Results: 14 passed, 0 failed  (Test 9 GREEN)
bash scripts/tests/test-update-diff.sh:   Results: 13 passed, 0 failed  (Test 10 GREEN)
bash scripts/tests/test-update-summary.sh: Results: 0 passed, 5 failed  (Test 11 RED — Plan 04-03)
```

## Known Stubs

None — all dispatch paths are fully wired. `write_state` call is deferred to Plan 04-03 (as designed); accumulator arrays are populated but not written to disk until Plan 04-03's summary block runs.

## Threat Flags

None — no new network endpoints or auth paths introduced. `TK_UPDATE_FILE_SRC` is a test-only seam with no production surface.

## Next Phase Readiness

Plan 04-03 consumes the following from this plan's output:

| Variable | Type | Description |
|----------|------|-------------|
| `INSTALLED_PATHS` | `array` | Paths successfully installed (new files) |
| `UPDATED_PATHS` | `array` | Paths overwritten after user accepted modified-file prompt |
| `SKIPPED_PATHS` | `array` | Entries as `path:reason` strings |
| `REMOVED_PATHS` | `array` | Paths deleted (manifest-removed or mode-switch-removed) |
| `STATE_MODE` | `string` | Potentially updated mode after switch |
| `STATE_JSON` | `string (JSON)` | Updated in-memory state (mode updated, switch-removed files removed, paths normalized) |
| `MANIFEST_HASH` / `STATE_MANIFEST_HASH` | `string` | For Plan 04-03 no-op check |
| `REMOTE_TOOLKIT_VERSION` / `LOCAL_VERSION` | `string` | For Plan 04-03 version display |

Plan 04-03 implements: `write_state` call (persisting accumulated changes), no-op check (D-59), D-57 PID-suffix tree backup, final summary printer, and Test 11 GREEN.

## Self-Check: PASSED

All created files exist on disk. All commit hashes verified in git log. Test 10 GREEN (13/13). Test 9 GREEN (14/14). `compute_file_diffs_obj` present in both `scripts/lib/install.sh` and `scripts/update-claude.sh`. Hand-list grep returns 0.
