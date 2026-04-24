---
phase: 09-backup-detection
plan: "03"
subsystem: detection
tags:
  - detect
  - cli
  - shell
  - detect-06
dependency_graph:
  requires:
    - 09-01-PLAN (scripts/lib/backup.sh created, branch established)
  provides:
    - DETECT-06 CLI cross-check in detect_superpowers()
    - test-detect-cli.sh automated regression suite (6 scenarios)
  affects:
    - scripts/detect.sh
    - scripts/tests/test-detect-cli.sh
tech_stack:
  added: []
  patterns:
    - single-subprocess capture into variable, parse twice via herestring (Pitfall 5 fix)
    - case "$cli_enabled" dispatch: false/true/empty branches
    - command -v guard for CLI and jq availability
key_files:
  modified:
    - scripts/detect.sh
  created:
    - scripts/tests/test-detect-cli.sh
decisions:
  - D-13 honored: DETECT-06 applies to SP only; GSD stays FS-only; comment added to detect_gsd()
  - D-15 honored: CLI absent = silent skip, FS wins
  - D-16 honored: false branch overrides FS; empty branch = FS wins (not treated as false)
  - D-17 honored: CLI error / non-JSON = soft-fail, FS wins
  - D-18 honored: CLI version authoritative over FS dir-name when CLI present and enabled
  - Pitfall 5 fixed: one subprocess call, two jq parses from captured variable
metrics:
  duration_minutes: 25
  completed: "2026-04-24"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 2
requirements:
  - DETECT-06
---

# Phase 09 Plan 03: DETECT-06 CLI Cross-Check Summary

One-liner: DETECT-06 step 4 inserts `claude plugin list --json` cross-check into `detect_superpowers()` after the settings.json gate, capturing output once and dispatching on `cli_enabled` (false/true/empty) with full FS fallback on any CLI failure.

## What Was Built

### scripts/detect.sh (MODIFIED)

`detect_superpowers()` gains a 4th verification layer inserted between the existing settings.json gate (STEP 3) and the final `HAS_SP=true` assignment:

- **Guard:** `command -v claude && command -v jq` — silent skip when either absent
- **Single subprocess:** `cli_json=$(claude plugin list --json 2>/dev/null || echo "")`
- **Two jq parses via herestring:** `cli_enabled` and `cli_ver` from same captured variable
- **case dispatch:**
  - `"false"` → `HAS_SP=false; SP_VERSION=""; return 1` (CLI overrides FS, D-16)
  - `"true"` → `[[ -n "$cli_ver" ]] && ver="$cli_ver"` (CLI version wins, D-18)
  - `""` → no action, FS result wins (absent/error/non-JSON/SP not in list, D-15/D-17)

`detect_gsd()` gains a comment at the top of its body explaining why DETECT-06 does not apply (GSD is not a Claude Code plugin, never appears in plugin list, D-13).

Sourced-lib invariant preserved: no `set -e`/`set -u`/`set -o pipefail` at file level.

### scripts/tests/test-detect-cli.sh (MODIFIED — bug-fixed)

Pre-existing test file (created in plan 09-01 commit 54e0d0a) with 6 scenarios covering VALIDATION.md rows 9-03-01..06. One bug was fixed during GREEN phase execution (see Deviations).

## Verification

```text
bash scripts/tests/test-detect-cli.sh
DETECT-06 CLI cross-check scenarios
---
  ✓ CLI enabled + version → SP_VERSION=5.1.0 (CLI wins, D-18)
  ✓ CLI disabled → HAS_SP=false (CLI overrides FS, D-16)
  ✓ CLI absent → FS wins, SP_VERSION=5.0.7 (D-15)
  ✓ CLI error → soft-fail, FS wins (D-17)
  ✓ CLI non-JSON → jq fails → FS wins (D-17)
  ✓ CLI empty [] → FS wins, NOT treated as false (D-16 empty branch)

---
PASS: 6
FAIL: 0

make check → All checks passed
grep -c 'claude plugin list --json' scripts/detect.sh → 1 (single subprocess)
```

## Commits

| Hash | Message |
|------|---------|
| `4527422` | feat(detect-06): insert CLI cross-check step 4 into detect_superpowers() |

Note: Test file was pre-committed in `54e0d0a` (plan 09-01 context); the bug fix was included in `4527422`.

## Branch

`feature/detect-06-cli-crosscheck` (per D-30)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `set -e` + `&&` short-circuit exit in test-detect-cli.sh**

- **Found during:** GREEN phase — test runner exited after 2 cases instead of running all 6
- **Root cause:** `[[ "$scenario" != "absent" ]] && chmod +x "$bin_dir/claude"` — when `scenario=absent`, the `[[ ]]` test returns exit code 1, and with `set -euo pipefail` active in the outer harness, the `&&` expression's exit code 1 caused the script to abort immediately
- **Fix:** Changed to `if [[ "$scenario" != "absent" ]]; then chmod +x "$bin_dir/claude"; fi` — the `if` construct never propagates a non-zero exit from the condition
- **Files modified:** `scripts/tests/test-detect-cli.sh` line 66
- **Commit:** `4527422`

**2. [Rule 1 - Bug] Comment strings inflated `grep -c 'claude plugin list --json'` count**

- **Found during:** Acceptance criteria verification
- **Root cause:** Three comment lines in detect.sh repeated the exact string `claude plugin list --json`, causing `grep -c` to return 4 instead of 1
- **Fix:** Paraphrased comment strings to avoid the exact command string; only the actual subprocess call at line 79 retains it
- **Files modified:** `scripts/detect.sh` (comment text only)
- **Commit:** `4527422`

## Known Stubs

None — all data paths are wired. FS and CLI sources are fully connected to HAS_SP/SP_VERSION exports.

## Threat Flags

No new security surface introduced. The three threat model entries (T-9-03, T-9-04, T-9-B3-01) from the plan's `<threat_model>` are all mitigated or accepted as documented:

- T-9-03 (malicious claude binary): mitigated by `jq 2>/dev/null || echo ""` soft-fail; worst case = FS-only degradation
- T-9-04 (TOCTOU): accepted; detection is read-only, no state mutation
- T-9-B3-01 (cli_json in process memory): accepted; local scope, no export, data already public

## Self-Check

- [x] `scripts/detect.sh` exists: FOUND
- [x] `scripts/tests/test-detect-cli.sh` exists: FOUND
- [x] Commit `4527422` exists: FOUND
- [x] `bash scripts/tests/test-detect-cli.sh` exits 0 with PASS:6 FAIL:0
- [x] `grep -c 'claude plugin list --json' scripts/detect.sh` = 1
- [x] No `set -e` at file level in detect.sh
- [x] `DETECT-06 does not apply` comment in detect_gsd()
- [x] `make check` exits 0

## Self-Check: PASSED
