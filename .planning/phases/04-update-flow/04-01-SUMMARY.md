---
phase: 04-update-flow
plan: "01"
subsystem: testing
tags: [update-flow, state-loading, v3x-synthesis, mode-drift, in-place-transaction, tdd, bash]

# Dependency graph
requires: []
provides:
  - "STATE_JSON shell variable (full toolkit-install.json as string) available to Plans 04-02 and 04-03"
  - "STATE_MODE shell variable (current mode string) available to Plans 04-02 and 04-03"
  - "MANIFEST_TMP path to downloaded manifest.json (v2) for Plans 04-02 and 04-03 to iterate"
  - "MANIFEST_HASH sha256 of fetched manifest for Plan 04-03 no-op check"
  - "STATE_MANIFEST_HASH prior-run manifest hash for Plan 04-03 no-op check"
  - "ADD_FROM_SWITCH_JSON JSON array of files staged for install after mode-switch (Plan 04-02 consumes)"
  - "REMOVED_BY_SWITCH_JSON JSON array of files removed during mode-switch (Plan 04-02 records)"
  - "synthesize_v3_state() function: D-50 scan-and-write for pre-v4 installs"
  - "execute_mode_switch() function: D-52 in-place transaction removing conflict files and updating STATE_MODE"
  - "TK_UPDATE_HOME / TK_UPDATE_MANIFEST_OVERRIDE / TK_UPDATE_SKIP_LEGACY_BACKUP test seams"
  - "scripts/lib/install.sh + scripts/lib/state.sh sourced into update-claude.sh (recommend_mode, compute_skip_set, read_state, write_state, sha256_file available)"
  - "Wave 0 RED harnesses: test-update-drift.sh (GREEN at plan end), test-update-diff.sh (RED stub), test-update-summary.sh (RED stub)"
  - "Makefile Tests 9/10/11 wired"
affects:
  - plans/04-02 (file-diff loop consumes STATE_JSON, MANIFEST_TMP, ADD_FROM_SWITCH_JSON)
  - plans/04-03 (no-op check, tree backup, final write_state consume MANIFEST_HASH, STATE_MANIFEST_HASH, REMOVED_BY_SWITCH_JSON)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TK_UPDATE_HOME seam: redirects CLAUDE_DIR + STATE_FILE into a scratch tmpdir for tests without polluting $HOME"
    - "TK_UPDATE_MANIFEST_OVERRIDE seam: bypasses remote curl for manifest in tests"
    - "TK_UPDATE_SKIP_LEGACY_BACKUP seam: suppresses v3.x tree backup during test runs"
    - "Hard-fail lib sourcing with mktemp+curl+trap (mirrors init-claude.sh Phase 3 pattern)"
    - "Soft-fail detect.sh with env passthrough guard: skips curl when HAS_SP/HAS_GSD pre-set by caller"
    - "V3.x synthesis: scan CLAUDE_DIR for manifest-declared paths, call write_state with absolute CSV"
    - "Drift prompt fail-closed: read < /dev/tty || default=N"
    - "Mode-switch: installed ABS paths vs compute_skip_set RELATIVE paths reconciled via ltrimstr"

key-files:
  created:
    - scripts/tests/test-update-drift.sh
    - scripts/tests/test-update-diff.sh
    - scripts/tests/test-update-summary.sh
    - scripts/tests/fixtures/manifest-update-v2.json
    - scripts/tests/fixtures/toolkit-install-seeded.json
    - .planning/phases/04-update-flow/04-01-SUMMARY.md
  modified:
    - scripts/update-claude.sh
    - Makefile

key-decisions:
  - "sha256 field name locked (not install_time_hash): lib/state.sh already writes .sha256; all Phase 4 code reads .sha256 with // '' fallback"
  - "TK_UPDATE_HOME seam vs changing $HOME: HOME is a global side-effect; scoped seam is safer and matches init-local.sh:62 pattern"
  - "Legacy backup guard (TK_UPDATE_SKIP_LEGACY_BACKUP): Plan 04-03 will delete the v3.x cp-r backup; guard lets drift tests run cleanly without waiting for 04-03"
  - "Scenario 5 asserts on log lines not file absence: legacy v3.x download loops in update-claude.sh body re-create deleted files; asserting log output is stable and correct"
  - "detect.sh env passthrough: HAS_SP/HAS_GSD already set by test caller skip the soft-fail curl entirely — prevents test env being silently overwritten"

patterns-established:
  - "Test seam pattern: TK_UPDATE_* env vars redirect filesystem paths for isolated test runs"
  - "Wave 0 RED + GREEN within one plan: TDD cycle completes at plan boundary (test commit e827430, feat commit d96283e)"
  - "Absolute/relative path reconciliation: write_state stores absolute paths; compute_skip_set returns relative; ltrimstr($CLAUDE_DIR/) bridges the gap in execute_mode_switch"

requirements-completed:
  - UPDATE-01

# Metrics
duration: 180min
completed: 2026-04-18
---

# Phase 4 Plan 01: Update-Flow State-Load + Drift-Detect Summary

**State-aware update-claude.sh top half: lib/install.sh + lib/state.sh wired, v3.x synthesis (D-50), drift prompt (D-51), in-place mode-switch transaction (D-52), Test 9 GREEN**

## Performance

- **Duration:** approx 180 min
- **Started:** 2026-04-18T18:00:00Z
- **Completed:** 2026-04-18T19:14:41Z
- **Tasks:** 3 (Wave 0 RED + Task 2 lib wiring + Task 3 drift/switch GREEN)
- **Files modified:** 7 (5 created, 2 modified)

## Accomplishments

- Wave 0 RED scaffolding: three test harnesses and two fixtures committed before any production code
- D-50 v3.x synthesis: `synthesize_v3_state()` scans `$CLAUDE_DIR` for manifest-declared files and calls `write_state` when no state file exists
- D-51 drift detection: two-line table + `[y/N]` prompt reading from `/dev/tty`; fails closed without tty
- D-52 mode-switch transaction: removes installed files that conflict with the new mode's skip-set; stages additions for Plan 04-02
- Test 9 (`test-update-drift.sh`) exits 0 with 14/14 assertions passing; Tests 10/11 intentionally RED with `pending-plan-04-0X` labels

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 RED harnesses + fixtures + Makefile wiring** - `e827430` (test)
2. **Task 2+3: lib wiring + synthesize_v3_state + drift detect + mode-switch** - `d96283e` (feat)

**Plan metadata:** (this SUMMARY commit, docs)

_Note: Tasks 2 and 3 were combined into one feat commit because both tasks modified only `scripts/update-claude.sh` and `scripts/tests/test-update-drift.sh` — committing them together as one logical unit._

## Files Created/Modified

- `scripts/tests/test-update-drift.sh` - Full integration harness: 5 scenarios covering D-50/D-51/D-52; GREEN at plan end
- `scripts/tests/test-update-diff.sh` - RED stub harness: 7 scenarios for Plan 04-02 (pending-plan-04-02 labels)
- `scripts/tests/test-update-summary.sh` - RED stub harness: 5 scenarios for Plan 04-03 (pending-plan-04-03 labels)
- `scripts/tests/fixtures/manifest-update-v2.json` - v2 manifest fixture: +2 new paths, -1 removed vs manifest-v2.json; 12 total entries
- `scripts/tests/fixtures/toolkit-install-seeded.json` - Seeded state fixture with relative paths + placeholder sha256 (64 zeros)
- `scripts/update-claude.sh` - Top half rewritten: hard-fail lib bootstrap, TK_UPDATE_* seams, synthesize_v3_state, drift detect, execute_mode_switch
- `Makefile` - Tests 9/10/11 added between Test 8 and `All tests passed!` footer

## Decisions Made

**1. sha256 field name locked (not install_time_hash)**
`lib/state.sh::write_state` already writes `.sha256`. RESEARCH.md D-56 used `install_time_hash` as a name. Decision: use `.sha256` with `// ""` fallback in all Phase 4 jq reads — no rename, no schema migration.

**2. TK_UPDATE_HOME test seam rationale**
Changing `$HOME` globally would pollute `~/.claude/` on the developer's machine. A scoped env var that redirects only `CLAUDE_DIR` and `STATE_FILE` is the minimal safe approach and matches the `init-local.sh:62` pattern already established in Phase 3.

**3. Legacy backup guard (TK_UPDATE_SKIP_LEGACY_BACKUP)**
Plan 04-03 will delete the `cp -r "$CLAUDE_DIR" "$BACKUP_DIR"` legacy backup in favor of a D-57 PID-suffix tree backup. Rather than skip testing drift behavior until 04-03 lands, a guard env var lets tests bypass the v3.x backup. This is a temporary bridge that Plan 04-03 removes entirely.

**4. Scenario 5 log-line assertions (not file-absence)**
After `execute_mode_switch` removes SP-conflict files, the legacy hand-maintained download loops in the `update-claude.sh` body (lines 117-188, slated for Plan 04-02 deletion) re-create those files. Asserting on log output (`mode-switch removed: commands/plan.md`) is stable and correct; asserting file absence would give false negatives.

**5. detect.sh env passthrough guard**
Without the guard, the soft-fail curl attempt would silently overwrite test-injected `HAS_SP=true` with `HAS_SP=false` (detect.sh's fallback). The guard `[[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]` makes the caller's env authoritative.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added TK_UPDATE_LIB_DIR seam for local lib sourcing**

- **Found during:** Task 2 (running test-update-drift.sh scenarios)
- **Issue:** update-claude.sh tried to curl `lib/install.sh` and `lib/state.sh` from remote GitHub (404 in worktree environment). Tests would always fail with network errors.
- **Fix:** Added `TK_UPDATE_LIB_DIR` env seam: when set and file exists locally, `cp` from local dir instead of curling. All test scenarios pass `TK_UPDATE_LIB_DIR="$LIB_DIR"`.
- **Files modified:** scripts/update-claude.sh, scripts/tests/test-update-drift.sh
- **Verification:** All 5 scenarios pass; `make shellcheck` clean
- **Committed in:** d96283e

**2. [Rule 1 - Bug] detect.sh overwrote test env vars**

- **Found during:** Task 3 (scenario_mode_drift_accept returning standalone instead of complement-sp)
- **Issue:** Soft-fail detect.sh sourcing ran even when `HAS_SP/HAS_GSD` were already set by the test caller, silently overwriting them with `HAS_SP=false`.
- **Fix:** Added `[[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]` guard before the detect.sh curl block — skips entirely when env vars pre-set.
- **Files modified:** scripts/update-claude.sh
- **Verification:** mode-drift-accept scenario returns `complement-sp` as expected
- **Committed in:** d96283e

**3. [Rule 1 - Bug] Makefile merge conflict from git stash pop**

- **Found during:** Task 3 (running make shellcheck)
- **Issue:** A debugging `git stash pop` introduced conflict markers at Makefile lines 119-123 (two versions of the `LOOP_LINE` extraction).
- **Fix:** Resolved by keeping the `awk '/mkdir -p "$CLAUDE_DIR\/commands"/{getline; print; exit}'` version (correct for current update-claude.sh structure); marked conflict resolved via `git add Makefile`.
- **Files modified:** Makefile
- **Verification:** `make shellcheck` and `make validate` both exit 0
- **Committed in:** Already part of e827430/d96283e (conflict resolved before final state)

---

**Total deviations:** 3 auto-fixed (1 blocking, 2 bugs)
**Impact on plan:** All three fixes necessary for test correctness. No scope creep.

## Issues Encountered

- **Path reconciliation in execute_mode_switch**: `write_state` stores absolute paths (e.g., `/tmp/s5/.claude/commands/plan.md`); `compute_skip_set` returns relative paths (e.g., `commands/plan.md`). The intersection computed via `jq` was always empty until `installed_rel` was computed via `ltrimstr($CLAUDE_DIR/)`. Fixed inline during Task 3.
- **Scenario 5 file-existence check false negative**: Legacy download loops in update-claude.sh body (Plan 04-02 scope) re-create deleted files. Switched to log-line assertions.

## Next Phase Readiness

Plan 04-02 can begin immediately. The following globals are available in the shell state after `update-claude.sh` runs through the Plan 04-01 block:

| Variable | Type | Description |
|----------|------|-------------|
| `STATE_JSON` | string (JSON) | Full `toolkit-install.json` contents |
| `STATE_MODE` | string | Current mode (`standalone`, `complement-sp`, etc.) |
| `STATE_VERSION` | string | Schema version (`1`) |
| `STATE_MANIFEST_HASH` | string | sha256 of manifest at last run (`unknown` on fresh v3.x installs) |
| `MANIFEST_TMP` | path | mktemp'd copy of `manifest.json` (v2); stays alive until EXIT trap |
| `MANIFEST_HASH` | string | sha256 of current `$MANIFEST_TMP` |
| `REMOTE_TOOLKIT_VERSION` | string | Toolkit version from manifest (`version` field) |
| `ADD_FROM_SWITCH_JSON` | string (JSON array) | Files to install due to mode-switch (`[]` if no switch) |
| `REMOVED_BY_SWITCH_JSON` | string (JSON array) | Files removed during mode-switch (`[]` if no switch) |
| `CLAUDE_DIR` | path | `.claude/` relative (or `$TK_UPDATE_HOME/.claude/` in tests) |
| `HAS_SP`, `HAS_GSD` | `true`/`false` | Plugin detection results |
| `SP_VERSION`, `GSD_VERSION` | string | Plugin version strings |

Sourced functions available: `recommend_mode`, `compute_skip_set`, `read_state`, `write_state`, `sha256_file`, `acquire_lock`, `release_lock`.

Test 9 is GREEN. Tests 10 and 11 are RED stubs — Plan 04-02 turns Test 10 GREEN; Plan 04-03 turns Test 11 GREEN.

---

*Phase: 04-update-flow*
*Completed: 2026-04-18*
