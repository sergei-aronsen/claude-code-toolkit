# Phase 29 — Code Review

**Reviewer:** gsd-code-reviewer (sonnet)
**Date:** 2026-04-29
**Depth:** standard
**Scope:** scripts/lib/state.sh, scripts/lib/bridges.sh, scripts/update-claude.sh, scripts/uninstall.sh, scripts/init-local.sh, scripts/migrate-to-complement.sh, scripts/tests/test-bridges-sync.sh
**Verdict:** issues_found → fixed inline

## Findings

### WR-01 — uninstall.sh:278 — modified-bridge prompt suppressed by `is_protected_path`

**File:** `scripts/uninstall.sh:268-282`
**Severity:** WARNING
**Confidence:** 95%

`prompt_modified_for_uninstall` runs `is_protected_path "$local_path"` as a defense-in-depth guard. `is_protected_path:174` returns 0 (protected) for any path outside `$CLAUDE_DIR`. Bridges (project-local `<root>/GEMINI.md`, global `~/.gemini/GEMINI.md`, `~/.codex/AGENTS.md`) all live outside `$CLAUDE_DIR` by design — they were thus silently appended to `KEEP_LIST` without the `[y/N/d]` prompt firing. Test S8 passed for the wrong reason: the injected `N` answer was never consumed.

**Failure scenario:** user edits `GEMINI.md`, runs `uninstall.sh`. Bridge classified MODIFIED → enters `prompt_modified_for_uninstall` → `is_protected_path` returns 0 → file silently kept, no prompt shown. User cannot opt to remove their modified bridge via the standard `[y/N/d]` flow.

**Fix:** added `BRIDGE_PATHS` linear-scan bypass to `prompt_modified_for_uninstall`. If the path matches a tracked bridge, skip the `is_protected_path` check.

**Status:** FIXED in commit `<WR-fix>` (this branch).

### WR-02 — bridges.sh:123 + update-claude.sh:554 — sync_bridges silent no-op in production

**File:** `scripts/lib/bridges.sh:122-123, 282-283, 348-349`
**Severity:** WARNING
**Confidence:** 95%

All three Phase 29 helpers (`_bridge_write_state_entry`, `_bridge_set_user_owned`, `_bridge_remove_state_entry`) hardcoded `state_file="${home}/.claude/toolkit-install.json"` where `home = ${TK_BRIDGE_HOME:-$HOME}`. In production (no `TK_BRIDGE_HOME`), helpers always wrote to GLOBAL `$HOME/.claude/toolkit-install.json`.

But `update-claude.sh:158` and `init-claude.sh:72` set `STATE_FILE="$CLAUDE_DIR/toolkit-install.json"` with `CLAUDE_DIR=".claude"` — PROJECT-LOCAL state. Consequences:

1. Self-deadlock guard never fired in production (different lock dirs).
2. `write_state` at `update-claude.sh:1215` captured `bridges=[]` from project state and overwrote project state with empty bridges.
3. `sync_bridges` read project state, saw no bridges, silently no-op'd.

Tests passed only because hermetic sandbox sets `TK_BRIDGE_HOME == TK_UPDATE_HOME == $SANDBOX` — both paths converge.

**Failure scenario:** real user runs `update-claude.sh` after editing `CLAUDE.md`. `sync_bridges` reads project state file (no bridges[]). Loop body never executes. `[~ UPDATE] GEMINI.md` never printed. Bridge files become stale. The entire Phase 29 sync feature is dead in production.

**Fix:** introduced `_bridge_state_file()` / `_bridge_lock_dir()` helpers. Resolution priority: TK_BRIDGE_HOME (sandbox) → STATE_FILE inherited from caller (project-local) → state.sh global default. All 3 callsites use the helpers.

**Status:** FIXED in commit `<WR-fix>` (this branch).

### IN-01 — update-claude.sh:370 — synthesize_v3_state calls write_state with 8 args

**File:** `scripts/update-claude.sh:370`
**Severity:** INFO
**Confidence:** 75%

`synthesize_v3_state` calls `write_state` without explicit 9th (synth_flag) and 10th (bridges_json) args. Writes default `'[]'` for bridges (preserve-on-default path triggered). Behavior is correct for the v3→v4 synthesis path but silently swallows JSON parse errors from corrupt state files. Acceptable for this edge case (synthesis is a fallback when state is missing/malformed anyway).

**Status:** ACKNOWLEDGED. No fix in Phase 29.

### IN-02 — test-bridges-sync.sh S8 — exercises wrong code path

**File:** `scripts/tests/test-bridges-sync.sh` S8
**Severity:** INFO
**Confidence:** 90%

S8 validates the correct outcome (modified bridge `N` keeps file) but only because WR-01 silently skipped the prompt. After WR-01 fix, S8 now exercises the real prompt path. Re-validated post-fix: S8 still PASS.

**Status:** SELF-CORRECTED by WR-01 fix.

## Invariants Verified

| Invariant | Result |
|---|---|
| Bash 3.2+ POSIX (no `declare -A/-n`, `read -N`, `${var^^}`, `mapfile`) | CLEAN |
| Sourced libs no `set -euo pipefail` | CLEAN (state.sh, bridges.sh) |
| write_state 10-arg backward compat | CLEAN (default `'[]'` preserves) |
| Lock correctness (caller-PID guard, all-paths release) | CLEAN |
| Atomic state mutation (mkstemp + os.replace) | CLEAN |
| Idempotent flag mode (--break/--restore exit 0) | CLEAN |
| `[y/N/d]` fail-closed N | CLEAN |
| Sync decision tree single state mutation | CLEAN |
| Uninstall protection bypass scoped to BRIDGE_PATHS only | CLEAN (after WR-01 fix) |
| No raw user input → shell | CLEAN (target case-validated, paths quoted) |
| shellcheck `-S warning` | CLEAN |
| Self-deadlock fix (caller-PID guard) | CLEAN (after WR-02 fix — guard now sees correct lock dir) |
| TOCTOU windows | None identified |

## STATUS: clean (post-fix)

Two real WARNING bugs found and fixed atomically before Phase 29 closeout. WR-02 was a critical-feature-dead-in-production bug masked by sandbox path collapse in tests. Both fixes verified by re-running all 5 baseline test suites: PASS=5/25/26/43/17.
