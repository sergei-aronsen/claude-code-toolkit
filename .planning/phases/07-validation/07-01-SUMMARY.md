---
phase: "07-validation"
plan: "01"
subsystem: "validation"
tags: ["shell", "testing", "release-validation", "invariants"]
dependency_graph:
  requires: []
  provides:
    - "scripts/validate-release.sh skeleton with 7 callable helpers"
    - "assert_state_schema, assert_settings_foreign_intact, assert_skiplist_clean, assert_no_agent_collision, run_cell (contract for Plan 07-03)"
  affects:
    - "make shellcheck (validate-release.sh now in scripts/ tree)"
tech_stack:
  added: []
  patterns:
    - "tty-aware color constants with SC2034 disable guards"
    - "require_lib() guard pattern: exit 1 if library missing"
    - "PASS/FAIL counters + assert_eq/assert_contains (from test-migrate-flow.sh shape)"
    - "SC2329 disable for exported-but-not-locally-called helpers"
key_files:
  created:
    - scripts/validate-release.sh
  modified: []
decisions:
  - "Removed name parameter from require_lib() — path is the only needed arg; name was unused (SC2034)"
  - "Added SC2329 disable on assert_settings_foreign_intact and run_cell — both are skeleton exports for Plan 07-03, not called in --self-test"
  - "Renamed local variable path→lib_path in require_lib to avoid shadowing the shell builtin concept"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-20T21:30:17Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 07 Plan 01: validate-release.sh Skeleton Summary

Creates `scripts/validate-release.sh` — the Phase 7 matrix runner skeleton with 7 invariant helpers, a fail-fast `run_cell` wrapper, and a `--self-test` flag that proves all helpers work against synthetic fixtures (13 assertions, 0 failures).

## What Was Built

`scripts/validate-release.sh` is a POSIX-bash script (`set -euo pipefail`) that:

1. Sources three libraries via guarded `require_lib()` — exits 1 if any is missing:
   - `scripts/detect.sh` (exports `HAS_SP`, `HAS_GSD`)
   - `scripts/lib/install.sh` (exports `compute_skip_set`)
   - `scripts/lib/state.sh` (exports `sha256_file`)

2. Defines 7 callable functions (the Plan 07-03 contract):

| Function | Invariant | Description |
|---|---|---|
| `assert_eq` | core | String equality; prints expected/actual on FAIL |
| `assert_contains` | core | Substring grep; prints needle on FAIL |
| `assert_state_schema` | D-03 #2 | Validates toolkit-install.json mode + schema |
| `assert_settings_foreign_intact` | D-03 #3 | Byte-compares settings.json foreign subtrees |
| `assert_skiplist_clean` | D-03 #4 | Verifies no skipped files landed in CELL_HOME |
| `assert_no_agent_collision` | D-11 | Detects TK↔SP agent basename collisions |
| `run_cell` | D-02 | Fail-fast wrapper: exits 1 on first red cell |

3. `--self-test` path: 13 synthetic assertions covering all helper pass + fail paths, exits 0.

4. `--cell <name>` stub: exits 2 with "not wired yet" message (Plan 07-03).

5. No-arg path: prints usage and exits 0.

## Helper Function Signatures (Plan 07-03 contract)

```bash
assert_eq        <expected> <actual> <msg>
assert_contains  <needle> <haystack> <msg>
assert_state_schema          <state_file> <expected_mode>
assert_settings_foreign_intact <before_json> <after_json>
assert_skiplist_clean        <cell_home> <mode>
assert_no_agent_collision    <cell_home>
run_cell                     <cell_name> <body_function_name>
```

## Sourced Library Paths

```text
${REPO_ROOT}/scripts/detect.sh      → HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION
${REPO_ROOT}/scripts/lib/install.sh → compute_skip_set, MODES, recommend_mode
${REPO_ROOT}/scripts/lib/state.sh   → sha256_file, write_state, read_state
```

## Self-Test Exit-Zero Confirmation

```text
Self-test results: 13 passed, 0 failed
Exit code: 0
```

## Canonical Pre-4.0 Commit for Plan 07-03

For v3.x upgrade cells, Plan 07-03 references this SHA directly:

- **Commit:** `e9411201db9dde6a0676a5a5b09fb80d8893e507`
- **Message:** "fix: add /design command to all documentation and manifest"
- **Date:** 2026-03-16
- **Why:** Last v3.x-shaped commit; parent of `c5c8cbc` which bumped `manifest_version: 2` and added `[4.0.0]` CHANGELOG entry.
- **No `v3.0.0` tag** — reference this SHA directly via `git worktree add` or `git checkout`.

## Verification Results

```text
shellcheck -S error scripts/validate-release.sh  → PASS (exit 0)
make shellcheck                                  → PASS (exit 0)
bash scripts/validate-release.sh --self-test     → PASS (13/13, exit 0)
bash scripts/validate-release.sh                 → usage printed (exit 0)
bash scripts/validate-release.sh --cell foo      → exit 2
git diff --stat (only scripts/validate-release.sh modified)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed `name` param in `require_lib` to `lib_path`**

- **Found during:** Task 1 verification (`make shellcheck`)
- **Issue:** `require_lib` had a `name` parameter that was unused (only `path` was needed); shellcheck SC2034 warning.
- **Fix:** Removed the `name` parameter entirely; callers updated to pass only the path.
- **Files modified:** `scripts/validate-release.sh`
- **Commit:** bb6bfd9

**2. [Rule 2 - Missing] Added SC2329 disables for skeleton-only exported helpers**

- **Found during:** Task 1 verification (`make shellcheck`)
- **Issue:** `assert_settings_foreign_intact` and `run_cell` are defined for Plan 07-03 consumption but not called in `--self-test`; shellcheck SC2329 (function never invoked).
- **Fix:** Added `# shellcheck disable=SC2329` directives above each function, matching the pattern used in `test-migrate-flow.sh` (line 35).
- **Files modified:** `scripts/validate-release.sh`
- **Commit:** bb6bfd9 (incorporated before commit)

## Known Stubs

| Stub | File | Line | Reason |
|---|---|---|---|
| `--cell <name>` dispatcher | scripts/validate-release.sh | ~250 | Cell bodies land in Plan 07-03; stub exits 2 with clear error |

The `--cell` stub is intentional per plan scope. It does not block the plan's goal (skeleton + helpers established).

## Threat Flags

None. This script runs in a sandboxed `$HOME` with read-only access to `manifest.json`. No network, no user input flowing to dangerous functions, no auth paths modified.

## Self-Check: PASSED

```bash
[ -f "scripts/validate-release.sh" ] → FOUND
[ -x "scripts/validate-release.sh" ] → FOUND
git log --oneline | grep "bb6bfd9"   → FOUND: bb6bfd9 feat(07-01): add validate-release.sh skeleton
```
