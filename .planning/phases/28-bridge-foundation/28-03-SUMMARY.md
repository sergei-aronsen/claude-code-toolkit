---
phase: 28-bridge-foundation
plan: "03"
subsystem: testing
tags:
  - testing
  - bridges
  - detection
  - hermetic
  - smoke-test
dependency_graph:
  requires:
    - 28-01  # detect2.sh with is_gemini_installed + is_codex_installed
    - 28-02  # bridges.sh with bridge_create_project + bridge_create_global
  provides:
    - scripts/tests/test-bridges-foundation.sh
  affects:
    - Phase 31 BRIDGE-TEST-01 (extends this scaffold to >=15 assertions)
tech_stack:
  added: []
  patterns:
    - Bash EXIT-trap sandbox cleanup (avoids RETURN-trap pitfall with source calls)
    - Global lib sourcing before scenario functions (test isolation without lib re-sourcing)
    - Python heredoc (<<'PYEOF') for JSON schema validation in shell tests
key_files:
  created:
    - scripts/tests/test-bridges-foundation.sh
  modified: []
decisions:
  - Source detect2.sh and bridges.sh at top level, not inside scenario functions
  - Use EXIT trap + _SANDBOXES array instead of per-scenario RETURN trap
  - Five scenarios map 1:1 to the 5 must_have truths in the plan
metrics:
  duration: "~25 minutes"
  completed: "2026-04-29"
  tasks: 2
  files_created: 1
  files_modified: 0
requirements:
  - BRIDGE-DET-01
  - BRIDGE-DET-02
  - BRIDGE-DET-03
  - BRIDGE-GEN-01
  - BRIDGE-GEN-02
  - BRIDGE-GEN-03
  - BRIDGE-GEN-04
---

# Phase 28 Plan 03: Bridge Foundation Smoke Test Summary

Hermetic 5-scenario smoke test exercising Phase 28's detection probes (28-01) and
bridge generation library (28-02) end-to-end. The test exits 0 with PASS=5 FAIL=0
on a clean run and establishes the scaffold Phase 31's BRIDGE-TEST-01 extends.

## Tasks Completed

### Task 1: Create scripts/tests/test-bridges-foundation.sh

**File:** `scripts/tests/test-bridges-foundation.sh` (270 lines)
**Commit:** `06fdb16`

Created a hermetic 5-scenario smoke test. Key implementation decisions:

- Libs sourced globally before scenario functions (see Deviations below)
- EXIT trap with `_SANDBOXES` array handles cleanup instead of per-scenario RETURN traps
- Python `<<'PYEOF'` heredoc in S4 validates full bridges[] schema
- `TK_BRIDGE_HOME` exported per-scenario, unset at end of each scenario function

### Task 2: BACKCOMPAT-01 Verification (read-only)

Confirmed all three test suites pass with correct PASS counts.

## Five Scenarios (S1..S5)

| ID | Scenario | Assertion | Result |
|----|----------|-----------|--------|
| S1 | Detection probes binary 0/1, no stderr | `is_gemini_installed` and `is_codex_installed` each return 0 or 1 with empty stderr | PASS |
| S2 | `bridge_create_project gemini` writes GEMINI.md | File exists, `head -1` is `<!--`, verbatim source content present | PASS |
| S3 | `bridge_create_project codex` writes AGENTS.md | `AGENTS.md` exists, `CODEX.md` absent, banner present | PASS |
| S4 | bridges[] state entry schema | target, scope, path-suffix, source_sha256 (64-hex), bridge_sha256 (64-hex), user_owned=false all correct | PASS |
| S5 | Idempotent re-run + sandbox isolation | SHA unchanged on re-run, bridges[] count stays 1, real `$HOME/.gemini/GEMINI.md` and `$HOME/.codex/AGENTS.md` untouched | PASS |

## Final PASS Count

```text
test-bridges-foundation complete: PASS=5 FAIL=0
```

## BACKCOMPAT-01 Verification

| Test Suite | Expected | Actual | Status |
|-----------|---------|--------|--------|
| test-bootstrap.sh | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| test-install-tui.sh | PASS>=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| test-bridges-foundation.sh | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |

## Shellcheck Results

```text
shellcheck -S warning scripts/lib/detect2.sh       → exit 0
shellcheck -S warning scripts/lib/bridges.sh        → exit 0
shellcheck -S warning scripts/tests/test-bridges-foundation.sh → exit 0
```

## Acceptance Criteria Coverage

- [x] `scripts/tests/test-bridges-foundation.sh` exists and is executable
- [x] First line is `#!/usr/bin/env bash`
- [x] `set -euo pipefail` present
- [x] `PASS=0` and `FAIL=0` counter initializers present
- [x] `assert_pass()` and `assert_fail()` helpers verbatim from test-bootstrap.sh
- [x] `TK_BRIDGE_HOME` exported as test seam per-scenario
- [x] `is_gemini_installed` and `is_codex_installed` called in S1
- [x] `bridge_create_project gemini` called in S2 and S5
- [x] `bridge_create_project codex` called in S3
- [x] `AGENTS.md` referenced (S3 assertion)
- [x] `/GEMINI.md` referenced (S4 schema, S2 check)
- [x] Summary line `test-bridges-foundation complete: PASS=$PASS FAIL=$FAIL`
- [x] Exits 0, trailing line matches `PASS=5 FAIL=0`
- [x] Real `$HOME` files untouched (S5)
- [x] `~/.claude/toolkit-install.json` has no sandbox-path entries after test
- [x] `shellcheck -S warning` exits 0
- [x] `manifest.json` NOT modified (Phase 31 BRIDGE-DIST-01)
- [x] BACKCOMPAT-01: test-bootstrap PASS=26, test-install-tui PASS=43

## Phase 31 Extension Plan

Phase 31's `BRIDGE-TEST-01` (requires >=15 assertions) extends this scaffold by adding:

1. Drift detection: modify source CLAUDE.md, call `bridge_create_project`, verify SHA256 changes
2. `--break-bridge` persistence: assert `user_owned=true` after breaking
3. `TK_NO_BRIDGES=1` skip: verify bridge_create_* returns non-zero and writes nothing
4. `--bridges <list>` force: verify only specified targets are created
5. Uninstall round-trip: call uninstall with bridges[] entries, verify files removed
6. Global-scope variant: `bridge_create_global gemini` writes under `$TK_BRIDGE_HOME/.gemini/`
7. State de-dup: run `bridge_create_project gemini` twice, assert bridges[] count stays at 1 (already partially in S5, expanded)
8. Missing source returns 1: call without CLAUDE.md, assert exit code 1
9. Bad target returns 3: call with `bridge_create_project unknowncli`, assert exit code 3
10. State path under TK_BRIDGE_HOME: confirm state_file is in sandbox, not real `$HOME`

The scaffold's `_SANDBOXES` array, `mk_sandbox` helper, global lib sourcing, and
assert_* idioms are fully reusable — Phase 31 adds new `run_s6`..`run_s15` functions.

## Manifest Note

`manifest.json` was NOT modified. Per REQUIREMENTS.md traceability, `BRIDGE-DIST-01`
(registering `scripts/lib/bridges.sh` in `files.libs[]`) is a Phase 31 task. Phase 28
ships the library and test only; distribution registration is deferred.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed RETURN-trap pitfall: source calls inside functions fire RETURN trap**

- **Found during:** Task 1 — test execution, S2 and S3 failing with GEMINI.md / AGENTS.md absent
- **Issue:** The plan specified `trap "rm -rf '${sandbox:?}'" RETURN` inside each scenario function,
  AND `source bridges.sh` inside each scenario function. In Bash, `source` triggers the RETURN trap
  when it completes, firing the sandbox cleanup BEFORE the scenario body ran `bridge_create_project`.
  This caused `[[ -f CLAUDE.md ]]` to return false (directory deleted) → bridge returned exit 1 →
  `set -euo pipefail` aborted the test.
- **Fix:** Source both `detect2.sh` and `bridges.sh` once at the top level (before any run_s*
  functions are called). Replaced per-scenario `trap ... RETURN` with a global `_SANDBOXES` array
  and single `trap '_cleanup_sandboxes' EXIT` at the top of the script. This matches the
  `test-mcp-secrets.sh` pattern exactly (`source mcp.sh` at line 46, `trap ... EXIT` at line 41).
- **Files modified:** `scripts/tests/test-bridges-foundation.sh`
- **Commit:** `06fdb16` (same commit — fix applied during initial write after test run revealed failure)

## Known Stubs

None. All 5 scenarios make real assertions against real library behavior.

## Threat Flags

None. This plan creates a test-only file. No new network endpoints, auth paths, file access
patterns at trust boundaries, or schema changes outside the hermetic `/tmp` sandbox.

## Self-Check: PASSED

- `scripts/tests/test-bridges-foundation.sh` exists: FOUND
- Commit `06fdb16` exists: FOUND
- PASS=5 FAIL=0 on clean run: VERIFIED
- BACKCOMPAT-01 baselines: PASS=26 and PASS=43 VERIFIED
- shellcheck clean across all three Phase 28 files: VERIFIED
- manifest.json unmodified: VERIFIED
