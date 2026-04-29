---
phase: 29-sync-uninstall-integration
plan: "02"
subsystem: update-claude
tags: [bridges, sync, update-flow, break-bridge, restore-bridge, bash3.2]
dependency_graph:
  requires: [29-01]
  provides: [sync_bridges, --break-bridge, --restore-bridge, BRIDGES_JSON-passthrough]
  affects: [29-03]
tech_stack:
  added: []
  patterns: [indexed-while-argv-parser, sync-loop-decision-tree, bridges-json-capture-before-write]
key_files:
  created: []
  modified:
    - scripts/update-claude.sh
    - scripts/lib/bridges.sh
decisions:
  - "sync_bridges called in both is_update_noop branch and after print_update_summary — CLAUDE.md edits bypass manifest hash diff so both paths must sync"
  - "bridges.sh sibling-source guarded by write_state presence check to survive tmpfile sourcing in update-claude.sh"
  - "BRIDGES_JSON capture is explicit (not relying on 29-01 preserve-by-default) for resilience against future write_state refactors"
metrics:
  duration: "~35 minutes"
  completed: "2026-04-29T19:30:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 29 Plan 02: sync_bridges + break/restore-bridge Flags Summary

Wires `scripts/lib/bridges.sh` into the `update-claude.sh` lifecycle: adds
`--break-bridge` / `--restore-bridge` state-only flags and the `sync_bridges()`
decision-tree loop that runs on every update invocation regardless of no-op status.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Source bridges.sh + argv flags + state-only short-circuit | fbf3dc1 | scripts/update-claude.sh, scripts/lib/bridges.sh |
| 2 | sync_bridges() function + BRIDGES_JSON capture + invocation sites | 38feedf | scripts/update-claude.sh |

## Argv Parser Shape

Replaced the original `for arg in "$@"` single-token loop with an indexed
`while [[ $i -le $# ]]` loop that peeks `${!next_idx}` for 2-token forms:

```text
--break-bridge=gemini     (1-token, =VALUE suffix)
--break-bridge gemini     (2-token, next-arg peek)
--restore-bridge=codex    (1-token)
--restore-bridge codex    (2-token)
```

All original flags (`--no-banner`, `--offer-mode-switch`, `--prune`,
`--clean-backups`, `--keep`, `--dry-run`) unchanged — new cases appended
before the `*) ;;` catch-all.

## State-Only Short-Circuit (lines 177-222)

Positioned **after** lib sourcing (requires `_bridge_set_user_owned`) and
**after** `STATE_FILE` / `LOCK_DIR` test-seam overrides. Shape:

```text
if BREAK_BRIDGE or RESTORE_BRIDGE set:
  reject mutual use → exit 2
  normalize target via tr '[:upper:]' '[:lower:]'  # Bash 3.2: no ${var,,}
  validate target ∈ {gemini, codex} → exit 2 on unknown
  export TK_BRIDGE_HOME from TK_UPDATE_HOME (test seam linkage)
  call _bridge_set_user_owned <target> true|false
  log_success + exit 0   (never falls through to regular update flow)
```

## sync_bridges Decision Tree (lines 546-645)

Function defined at line 546 in the helpers block, before `# MAIN`.

| Branch | Trigger | Action | Log marker |
|--------|---------|--------|------------|
| 1 SKIP | `user_owned == true` | continue | `[- SKIP]` |
| 2 ORPHAN | source CLAUDE.md missing | auto-flip user_owned=true, continue | `[? ORPHANED]` |
| 3 DRIFT | bridge SHA differs from recorded | `bridge_prompt_drift` → y: rewrite / N: keep | `[~ UPDATE]` / `[~ MODIFIED]` |
| 4 REWRITE | source SHA changed, bridge clean | `bridge_create_project` or `bridge_create_global` | `[~ UPDATE]` |
| 5 IN-SYNC | all SHAs match | silent no-op | (none) |

Dispatch by scope: `global` → `bridge_create_global`; `project` → `bridge_create_project "$b_target" "$scope_root"`.

## sync_bridges Invocation Sites

| Site | Line | Rationale |
|------|------|-----------|
| `is_update_noop` branch | ~869 | CLAUDE.md edits don't change manifest hash; bridges must still sync when manifest is clean |
| After `print_update_summary` | ~1225 | Non-noop path: run after toolkit files are written so bridges reflect latest source |

Both sites are idempotent for in-sync bridges (silent no-op).
Dry-run path (`DRY_RUN=1`) exits before both sites — bridges sync is
deferred for dry-run (acceptable per CONTEXT.md "Deferred" BRIDGE-FUT-?).

## BRIDGES_JSON Capture Pattern

```bash
# Lines 1211-1217 (before write_state call)
BRIDGES_JSON='[]'
if [[ -f "$STATE_FILE" ]]; then
    BRIDGES_JSON=$(jq -c '.bridges // []' "$STATE_FILE" 2>/dev/null || echo '[]')
fi
write_state "$STATE_MODE" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" \
            "$FINAL_INSTALLED_CSV" "$FINAL_SKIPPED_CSV" "false" "$MANIFEST_HASH" \
            "$BRIDGES_JSON"
```

Captures the on-disk `bridges[]` **before** `write_state` rebuilds the full
JSON document. Passes it as the explicit 10th arg so the rebuild preserves
bridge entries. Defensive against any future refactor that changes the
29-01 "preserve-by-default" behavior.

## Test Seam Map: TK_UPDATE_HOME → TK_BRIDGE_HOME

The state-only dispatch and `sync_bridges` both export:

```bash
export TK_BRIDGE_HOME="${TK_UPDATE_HOME:-${TK_BRIDGE_HOME:-$HOME}}"
```

This links the existing `TK_UPDATE_HOME` test seam (used by `update-claude.sh`
to sandbox `$CLAUDE_DIR` and `$STATE_FILE`) to `TK_BRIDGE_HOME` (used by
`bridge_create_*` and `_bridge_set_user_owned` to sandbox bridge file paths
and state file access). Tests that set `TK_UPDATE_HOME` automatically get
hermetic bridge operations at no extra configuration cost.

## Deviation: bridges.sh Sibling-Source Guard (Rule 1 — Bug Fix)

**Found during:** Task 1 verification (`test-update-drift.sh` — 2 passed, 15 failed)

**Issue:** `bridges.sh` sources `state.sh` and `dry-run-output.sh` relative to
`BASH_SOURCE[0]`. When `update-claude.sh` copies `bridges.sh` to a tmpfile and
sources it, `BASH_SOURCE[0]` resolves to the tmpdir — `state.sh` does not exist
there. Error: `bridges.XXXXXX: line 45: /tmp/state.sh: No such file or directory`.

**Fix:** Wrapped the sibling `source` calls in a `command -v write_state` guard
in `scripts/lib/bridges.sh`. Since `state.sh` is already sourced earlier in
the lib loop, `write_state` is already in scope — the guard skips the
re-source cleanly.

**Files modified:** `scripts/lib/bridges.sh`
**Commit:** fbf3dc1 (included in Task 1 commit)

## BACKCOMPAT-01 Verdict

All baseline test suites pass with original PASS counts after both tasks:

| Test | Expected | Actual | Result |
|------|----------|--------|--------|
| test-bootstrap.sh | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| test-install-tui.sh | PASS=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| test-bridges-foundation.sh | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |
| test-update-drift.sh | 17 passed, 0 failed | 17 passed, 0 failed | PASS |

## shellcheck Result

`shellcheck -S warning` clean on both modified files:

- `scripts/update-claude.sh` — PASS (1273 lines)
- `scripts/lib/bridges.sh` — PASS

## Known Stubs

None. All decision-tree branches are fully wired to existing helpers.

## Threat Flags

None. Changes are internal update-flow orchestration with no new network
endpoints, auth paths, or user-input-derived file operations.

## Self-Check: PASSED

- `scripts/update-claude.sh` contains `sync_bridges()` at line 546
- `scripts/update-claude.sh` contains `BRIDGES_JSON` at lines 1211–1217
- `scripts/update-claude.sh` contains `BREAK_BRIDGE` / `RESTORE_BRIDGE` (14 occurrences)
- `scripts/update-claude.sh` ≥ 1100 lines (actual: 1273)
- `scripts/lib/bridges.sh` contains `write_state` guard for sibling sourcing
- Commits fbf3dc1 and 38feedf both present in git log
- All 4 test suites green
