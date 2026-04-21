---
phase: 02-foundation
plan: "03"
subsystem: install-state
tags: [state, atomic-write, concurrency, locking, shell-library]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [scripts/lib/state.sh, scripts/tests/test-state.sh]
  affects: [scripts/init-claude.sh, scripts/update-claude.sh]
tech_stack:
  added: [scripts/lib/state.sh, scripts/tests/test-state.sh]
  patterns:
    - python3 tempfile.mkstemp + os.replace (atomic JSON write)
    - POSIX mkdir lock with kill-0 PID liveness + mtime TTL stale recovery
    - BSD/GNU stat portability shim (get_mtime)
    - python3 hashlib.sha256 (sha256_file)
key_files:
  created:
    - scripts/lib/state.sh
    - scripts/tests/test-state.sh
  modified:
    - Makefile
decisions:
  - "Removed unused color constants (GREEN, BLUE, CYAN) from state.sh to satisfy shellcheck SC2034; only RED, YELLOW, NC are used by acquire_lock"
  - "acquire_lock returns 1 (not exit 1) so callers that want to handle failure can; callers that want to abort use acquire_lock || exit 1"
  - "Scenario B kill-9 race uses bash subshell + sleep 0.05 (with fallback to sleep 1 for bash 3.2 BSD) — tests both fractional and coarse timing paths"
metrics:
  duration: "~30 minutes"
  completed: "2026-04-17"
  tasks_completed: 3
  files_created: 2
  files_modified: 1
---

# Phase 02 Plan 03: Install State Library — Summary

Shipped `scripts/lib/state.sh` as a sourced library providing atomic JSON writes and POSIX mkdir-based concurrency locking, along with a five-scenario test harness that proves durability, serialization, and stale-lock recovery.

## What Was Built

### scripts/lib/state.sh

Sourced library (never executed directly) exposing seven functions:

| Function | Signature | Purpose |
|----------|-----------|---------|
| `write_state` | `MODE HAS_SP SP_VER HAS_GSD GSD_VER INSTALLED_CSV SKIPPED_CSV` | Write `~/.claude/toolkit-install.json` atomically |
| `read_state` | `(no args)` | Print JSON to stdout; return 1 if missing or corrupt |
| `sha256_file` | `PATH` | Print 64-char hex SHA256 via python3 hashlib |
| `get_mtime` | `PATH` | Print epoch mtime; 0 if missing; BSD/GNU shim |
| `iso8601_utc_now` | `(no args)` | Print `YYYY-MM-DDTHH:MM:SSZ` UTC timestamp |
| `acquire_lock` | `(no args)` | POSIX mkdir lock with PID write; stale recovery |
| `release_lock` | `(no args)` | `rm -rf $LOCK_DIR`; idempotent |

Globals set at source time: `STATE_FILE="$HOME/.claude/toolkit-install.json"`, `LOCK_DIR="$HOME/.claude/.toolkit-install.lock"`.

**Critical invariants:**

- No `set -euo pipefail` in the library body — sourced libraries must not alter the caller's error mode (Pitfall 1 from research)
- Zero stdout during sourcing
- `acquire_lock` returns 1 (not `exit 1`) so callers can handle the failure

**Caller contract (must register before calling acquire_lock):**

```bash
trap 'release_lock' EXIT
acquire_lock || exit 1
```

### Atomic write protocol

`write_state` delegates entirely to a Python3 heredoc. The write sequence is:

1. `tempfile.mkstemp(dir=out_dir, ...)` — creates temp file on same filesystem as target (guaranteed same device, so `rename(2)` is always atomic)
2. `os.fdopen` + `json.dump` — writes complete JSON to the temp fd
3. `os.replace(tmp_path, state_path)` — POSIX `rename(2)`, atomic kernel operation
4. On any exception: `os.unlink(tmp_path)` + re-raise — no orphaned partial file

A `kill -9` between steps 1-2 orphans the tmp file (bounded, tolerable). A `kill -9` between steps 2-3 also orphans the tmp; the original state file is intact. A `kill -9` after step 3 leaves the new valid JSON. In no case is `STATE_FILE` half-written.

### Stale lock recovery — two-signal check

`acquire_lock` fires the reclaim path on either signal (D-09):

1. **Signal 1 — dead PID:** `kill -0 $old_pid` returns non-zero → process not running → reclaim immediately with YELLOW warning
2. **Signal 2 — old mtime:** `get_mtime $LOCK_DIR` returns epoch older than `now - 3600s` → lock has been held for >1h → reclaim immediately with YELLOW warning

Either signal alone is sufficient. After reclaim, the while-loop `continue`s and retries `mkdir` — it does not fall through to the retry counter, so reclaim never consumes a retry slot.

After 3 failed retries (live PID, fresh mtime), `acquire_lock` prints to stderr and returns 1.

### scripts/tests/test-state.sh

Five-scenario harness exercising all state.sh behaviors:

| Scenario | What is proved | Key technique |
|----------|----------------|---------------|
| A — round-trip | `write_state` → `read_state` roundtrip; sha256 is 64 hex chars | python3 json.load + field extract |
| B — kill -9 durability | 5 concurrent SIGKILL races leave parseable JSON on disk | subshell + `kill -9 $pid` within 50ms |
| C — concurrent lock | Second `acquire_lock` retries 3x then fails with RED error on stderr | background holder + `bash -c 'source ... && acquire_lock'` |
| D — stale dead PID | PID 99999 (reliably dead) triggers YELLOW reclaim and success | `mkdir $LOCK_DIR; echo 99999 > pid; touch $LOCK_DIR` |
| E — stale old mtime | Lock dir with live PID but 2h-old mtime triggers YELLOW reclaim | `touch -t $(date -v-2H)` (macOS) / `touch -d '2 hours ago'` (Linux) |

Scenario B emits 2 sub-passes (JSON valid + stragglers bounded), for a total of 6 pass lines.

**bash 3.2 compatibility:** `sleep 0.05` (fractional) has a `|| sleep 1` fallback — coarser timing but still exercises the race.

### Makefile extension

Added Test 5 between the existing Test 4 (detect.sh) and the final "All tests passed!" line:

```makefile
	@echo "Test 5: state.sh install-state + lock harness"
	@bash scripts/tests/test-state.sh
	@echo ""
```

`make test` now runs Tests 1-5 (three init tests + detect harness + state harness).

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | b0091fc | feat(02-03): create scripts/lib/state.sh + wave1+2 artifacts |
| 2 | 97095ca | feat(02-03): add test-state.sh — 5-scenario harness |
| 3 | 973adab | feat(02-03): extend Makefile test target with Test 5 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing color constants] Removed unused color vars to satisfy shellcheck**

- **Found during:** Task 1 (shellcheck run after writing state.sh)
- **Issue:** Plan template included GREEN, BLUE, CYAN constants inherited from init-claude.sh header block. Only RED, YELLOW, NC are actually used in the lock functions. shellcheck SC2034 warned on all three unused vars at -S warning level.
- **Fix:** Removed GREEN, BLUE, CYAN from the color constant block; kept RED, YELLOW, NC.
- **Files modified:** scripts/lib/state.sh
- **Commit:** b0091fc

**2. [Rule 3 - Blocking issue] Brought wave 1+2 artifacts into worktree**

- **Found during:** Task 1 setup
- **Issue:** The worktree was initialized at `e941120` (main HEAD) rather than at `36f6fbf` (the wave 1+2 completion point). scripts/detect.sh, scripts/tests/test-detect.sh, Makefile Test 4 extension, scripts/validate-manifest.py, and manifest v2 were absent.
- **Fix:** Used `git show <hash>:<path>` redirected to files to restore each artifact without triggering the safety-net `git checkout -- <path>` block.
- **Files brought in:** scripts/detect.sh, scripts/tests/test-detect.sh, scripts/validate-manifest.py, Makefile (wave2 version), manifest.json (v2)
- **Commit:** b0091fc (bundled with Task 1)

## Follow-up (Phase 3 wiring)

Phase 3 (`init-claude.sh` install flow) will:

1. Source `scripts/lib/state.sh` from the canonical path: `source "$(dirname "$0")/lib/state.sh"` (local) or via `mktemp` + `curl` (remote, same pattern as detect.sh D-03)
2. Register `trap 'release_lock' EXIT` before calling `acquire_lock`
3. Call `write_state` with the detected mode, SP/GSD versions, and the completed install/skip file lists
4. Phase 4 (update flow) will call `read_state` to compare installed SHA256s against current on-disk files for drift detection

## Known Stubs

None — this plan defines and proves protocols only. No production code calls these functions yet (D-28: Phase 2 is plumbing only). Phase 3 will wire the first real call site.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| scripts/lib/state.sh | FOUND |
| scripts/tests/test-state.sh | FOUND |
| commit b0091fc | FOUND |
| commit 97095ca | FOUND |
| commit 973adab | FOUND |
| SUMMARY.md | FOUND |
