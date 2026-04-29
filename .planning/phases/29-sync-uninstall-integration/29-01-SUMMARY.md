---
phase: 29-sync-uninstall-integration
plan: "01"
subsystem: state-lib / bridges-lib / installers
tags: [bridges, state, write_state, backcompat, bash3.2]
dependency_graph:
  requires: [28-02]
  provides: [write_state-10arg, _bridge_set_user_owned, _bridge_remove_state_entry, bridge_prompt_drift]
  affects: [29-02, 29-03]
tech_stack:
  added: []
  patterns: [atomic-mkstemp-os.replace, TK_BRIDGE_TTY_SRC test seam, bridges-preservation-by-default]
key_files:
  created: []
  modified:
    - scripts/lib/state.sh
    - scripts/lib/bridges.sh
    - scripts/init-local.sh
    - scripts/migrate-to-complement.sh
decisions:
  - "bridges_json default '[]' means preserve-on-disk, not wipe-to-empty"
  - "bridge_prompt_drift fails closed: EOF / unknown / empty -> return 1 (keep)"
  - "TK_BRIDGE_TTY_SRC mirrors TK_UNINSTALL_TTY_FROM_STDIN pattern"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-29T18:42:35Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
---

# Phase 29 Plan 01: Foundation Primitives (write_state + bridges helpers) Summary

Surgical wave extending `write_state` and `bridges.sh` with the three primitives
that Plans 29-02 (sync loop) and 29-03 (uninstall + tests) require. Zero new files;
four surgical edits; all existing tests pass unchanged.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Extend write_state to 10-arg signature | 52ec056 | scripts/lib/state.sh |
| 2 | Add _bridge_set_user_owned, _bridge_remove_state_entry, bridge_prompt_drift | d392657 | scripts/lib/bridges.sh |
| 3 | Update init-local.sh + migrate-to-complement.sh write_state callers | 796c482 | scripts/init-local.sh, scripts/migrate-to-complement.sh |

## write_state Final Signature (10 positional args)

```text
write_state <mode> <has_sp> <sp_ver> <has_gsd> <gsd_ver> \
            <installed_csv> <skipped_csv> <synth_flag> <manifest_hash> \
            <bridges_json>
```

| Pos | Name | Default | Notes |
|-----|------|---------|-------|
| $1 | mode | required | complement/complement-only/standalone |
| $2 | has_sp | required | true/false |
| $3 | sp_ver | required | empty string OK |
| $4 | has_gsd | required | true/false |
| $5 | gsd_ver | required | empty string OK |
| $6 | installed_csv | required | comma-separated abs paths |
| $7 | skipped_csv | required | comma-separated path:reason |
| $8 | synth_flag | `false` | true only for synthesize_v3_state |
| $9 | manifest_hash | `""` | content hash of manifest.json |
| $10 | bridges_json | `'[]'` | raw JSON string; default = preserve existing |

### bridges_json Preservation Semantics

- **Default `'[]'`** (9-arg callers, or explicit `"${10:-[]}"` fallback): Python block reads the existing `.bridges[]` from the on-disk state file (if it exists) and keeps it. Treats `'[]'` as "don't touch" not "wipe to empty."
- **Non-default JSON string** (callers that explicitly capture via `jq -c '.bridges // []'`): Python parses and writes the supplied array, overriding whatever is on disk. This is the path Plan 29-02 (`update-claude.sh`) will use.

## New Helper Signatures

### `_bridge_set_user_owned <target> <value>`

Flips `user_owned` on every `bridges[]` entry whose `target` matches. Single-flag-many-rows: `--break-bridge gemini` affects both project and global gemini bridges.

| Return Code | Meaning |
|-------------|---------|
| 0 | success (or no-op: no state file) |
| 1 | Python failure or lock failure |
| 3 | bad args (target not gemini/codex, value not true/false) |

### `_bridge_remove_state_entry <target> <scope> <path>`

Removes one `bridges[]` entry matching the `(target, scope, path)` triple. Atomic `mkstemp + os.replace`. No-op if state file missing or entry not found.

| Return Code | Meaning |
|-------------|---------|
| 0 | success (or no-op) |
| 1 | Python failure or lock failure |

### `bridge_prompt_drift <bridge_path> <source_path>`

Interactive `[y/N/d]` prompt for a drifted bridge file. Builds would-be-rewritten content (banner + verbatim source) in a tempfile; `d` diffs and re-prompts in a loop. `RETURN` trap cleans tempfile on any exit path.

| Return Code | Meaning |
|-------------|---------|
| 0 | user chose `y`/`Y` — overwrite |
| 1 | any other: `N`, unknown, empty, EOF — keep (fail-closed) |

### `TK_BRIDGE_TTY_SRC` Test Seam

When `TK_BRIDGE_TTY_SRC` is set (non-empty), `bridge_prompt_drift` reads from that path instead of `/dev/tty`. Mirrors `TK_UNINSTALL_TTY_FROM_STDIN` from `uninstall.sh`. Tests inject answers via a named tempfile:

```bash
printf 'y\n' > /tmp/tty.txt
TK_BRIDGE_TTY_SRC=/tmp/tty.txt bridge_prompt_drift /path/to/GEMINI.md /path/to/CLAUDE.md
# exits 0
```

EOF produces return 1 (fail-closed):

```bash
: > /tmp/eof.txt
TK_BRIDGE_TTY_SRC=/tmp/eof.txt bridge_prompt_drift /path/to/GEMINI.md /path/to/CLAUDE.md
# exits 1
```

## BACKCOMPAT-01 Verdict

All three baseline test suites pass with original PASS counts:

| Test | Expected | Actual | Result |
|------|----------|--------|--------|
| test-bootstrap.sh | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| test-install-tui.sh | PASS=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| test-bridges-foundation.sh | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |
| test-state.sh | 6 passed, 0 failed | 6 passed, 0 failed | PASS |
| test-update-drift.sh | 17 passed, 0 failed | 17 passed, 0 failed | PASS |

## shellcheck Result

`shellcheck -S warning` clean across all four modified files:

- `scripts/lib/state.sh` — PASS
- `scripts/lib/bridges.sh` — PASS
- `scripts/init-local.sh` — PASS
- `scripts/migrate-to-complement.sh` — PASS

No `set -euo pipefail` added to either sourced lib (invariant preserved).

## Deviations from Plan

None — plan executed exactly as written. The three tasks were implemented verbatim per the plan's `<action>` blocks. The only minor note is that `grep -c "BRIDGES_JSON" scripts/init-local.sh` returns 4 (the plan comment contains the word) vs the plan's minimum of 3 — this exceeds the criterion, not a violation.

## Known Stubs

None. No placeholder data or TODO stubs were introduced.

## Threat Flags

None. Changes are internal state mutation helpers (no new network endpoints, no auth paths, no file access from user input, no new trust boundaries).

## Self-Check: PASSED

- `scripts/lib/state.sh` exists and contains `bridges_json` (7 occurrences, ≥4 required)
- `scripts/lib/bridges.sh` exists and contains all three helper definitions
- `scripts/init-local.sh` exists and contains `BRIDGES_JSON` (4 occurrences, ≥3 required)
- `scripts/migrate-to-complement.sh` exists and contains `BRIDGES_JSON` (3 occurrences, ≥3 required)
- Commits 52ec056, d392657, 796c482 all present in git log
- All 5 test suites green
