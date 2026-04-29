---
phase: 28-bridge-foundation
plan: "02"
subsystem: bridges
tags: [bridge, gemini, codex, state, atomic-json, bash-3.2]
dependency_graph:
  requires:
    - scripts/lib/state.sh (acquire_lock, release_lock, sha256_file)
    - scripts/lib/dry-run-output.sh (dro_* helpers)
  provides:
    - scripts/lib/bridges.sh (bridge_create_project, bridge_create_global)
  affects:
    - ~/.claude/toolkit-install.json (bridges[] array)
tech_stack:
  added: []
  patterns:
    - tempfile.mkstemp + os.replace atomic JSON patch (mirrors state.sh pattern)
    - single-quoted heredoc <<'BANNER' for byte-identical banner
    - TK_BRIDGE_HOME test seam (mirrors TK_MCP_CONFIG_HOME from Phase 25)
    - LOCK_DIR local override for hermetic test isolation
key_files:
  created:
    - scripts/lib/bridges.sh
  modified: []
decisions:
  - "Codex bridge filename is AGENTS.md (not CODEX.md) — OpenAI standard, locked in CONTEXT.md"
  - "write_state NOT reused — it rebuilds entire toolkit-install.json and would clobber installed_files[]"
  - "LOCK_DIR override (not subshell) chosen for acquire_lock isolation — simpler, no EXIT trap pollution"
  - "SHA256 computed AFTER _bridge_write_file returns — redirect must be closed before hashing (Pitfall 4)"
  - "TK_BRIDGE_HOME covers both state file path AND lock dir path for full hermetic test isolation"
  - "user_owned always False in Phase 28 — Phase 29 --break-bridge is the only flipper"
  - "Heredoc delimiter is BANNER (not EOF) to avoid collision with Python <<'PYEOF' blocks in same file"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-29"
  tasks_completed: 4
  files_created: 1
---

# Phase 28 Plan 02: Bridge Library Summary

One-liner: sourced Bash 3.2 library with `bridge_create_project`/`bridge_create_global` writing
banner-prefixed CLAUDE.md copies to GEMINI.md/AGENTS.md and registering each bridge in
toolkit-install.json via atomic python3 tempfile+os.replace patch.

## Tasks Completed

| Task | Name | Commit | Status |
|------|------|--------|--------|
| 1 | Create bridges.sh skeleton with header, color guards, source block, helper stubs | 67581c1 | DONE |
| 2 | Fill _bridge_write_file body — heredoc banner + verbatim source content | 67581c1 | DONE |
| 3 | Fill _bridge_write_state_entry body — atomic python3 tempfile patch of bridges[] | 67581c1 | DONE |
| 4 | Fill bridge_create_project and bridge_create_global public APIs | 67581c1 | DONE |

Tasks 1-4 were implemented in a single file creation (all bodies included from the start), then
verified and committed as one atomic unit.

## File Created

**scripts/lib/bridges.sh** — 249 lines

## Public API Signatures

```bash
bridge_create_project <target> [project_root]
# target: gemini | codex
# project_root: optional, defaults to $PWD
# Returns: 0=success, 1=missing source, 2=mkdir/write blocked, 3=bad target
# Writes: <project_root>/GEMINI.md or <project_root>/AGENTS.md

bridge_create_global <target>
# target: gemini | codex
# Returns: 0=success, 1=missing source, 2=mkdir/write blocked, 3=bad target
# Writes: ${TK_BRIDGE_HOME:-$HOME}/.gemini/GEMINI.md or ${TK_BRIDGE_HOME:-$HOME}/.codex/AGENTS.md
```

## Internal Helper Signatures

```bash
_bridge_home()                          # returns ${TK_BRIDGE_HOME:-$HOME}
_bridge_filename <target>               # gemini->GEMINI.md, codex->AGENTS.md; returns 1 on bad target
_bridge_global_dir <target>             # returns $home/.gemini or $home/.codex; returns 1 on bad target
_bridge_write_file <source> <target>    # writes banner+content; returns 0/1/2
_bridge_write_state_entry <target> <path> <scope> <source_sha> <bridge_sha>
                                        # patches .bridges[] atomically; returns 0/1
```

## Atomic JSON Patch Approach

`_bridge_write_state_entry` uses a `python3 - args <<'PYEOF'` inline block that:

1. Loads existing `toolkit-install.json` (or starts with `{}` if missing)
2. Deduplicates by `(target, scope, path)` triple — replaces in-place if found, appends if not
3. Sets `state["bridges"] = bridges`
4. Writes atomically via `tempfile.mkstemp(dir=out_dir) + os.replace`
5. Cleans up temp file if anything fails before `os.replace`

The lock is acquired via `acquire_lock` (from sourced `state.sh`) with `LOCK_DIR` temporarily
overridden to `${TK_BRIDGE_HOME}/.claude/.toolkit-install.lock` so hermetic tests do not collide
with the real `~/.claude/.toolkit-install.lock`. `LOCK_DIR` is restored after `release_lock`.

## Why write_state Was NOT Reused

`state.sh::write_state` rebuilds the **entire** `toolkit-install.json` document from fixed
positional arguments (`mode`, `has_sp`, `sp_ver`, `installed_csv`, etc.). Calling it for a
bridges-only patch would clobber `installed_files[]`, `mode`, `detected`, and all other top-level
keys. The bridges array mutation requires a surgical patch of only `.bridges[]`, which is why a
dedicated Python block with `tempfile.mkstemp + os.replace` was written (mirroring the pattern
from `state.sh` lines 125-136 verbatim).

## TK_BRIDGE_HOME Seam Coverage

`TK_BRIDGE_HOME` controls:

- Global write target: `${TK_BRIDGE_HOME:-$HOME}/.gemini/` and `${TK_BRIDGE_HOME:-$HOME}/.codex/`
- State file path: `${TK_BRIDGE_HOME:-$HOME}/.claude/toolkit-install.json`
- Lock dir path: `${TK_BRIDGE_HOME:-$HOME}/.claude/.toolkit-install.lock`

All three are in-scope for the seam, ensuring hermetic test sandboxes write nothing to real `$HOME`.
Pattern mirrors `TK_MCP_CONFIG_HOME` from v4.6 Phase 25.

## Pitfalls Hit During Implementation

**Pitfall 4 (redirect-vs-hash ordering):** SHA256 computation is deferred until AFTER
`_bridge_write_file` returns. This ensures the `} > "$target_path"` redirect has fully closed
the file descriptor before `sha256_file` reads the on-disk bytes. Computing SHA during the
write would hash a partial file.

**Safety net rm -rf block:** The test environment safety net blocks `rm -rf` on paths outside
the current working directory. Adapted verification commands to use a local `_test_sandbox/`
directory instead of `mktemp -d` with inline cleanup.

## Shellcheck Result

```text
shellcheck -S warning scripts/lib/bridges.sh  →  exit 0 (clean)
```

## Bash 3.2 Invariants Honored

- No `declare -A` (associative arrays)
- No `declare -n` (namerefs)
- No `mapfile` / `readarray`
- No `read -N`
- No `${var^^}` uppercase expansion
- No `set -euo pipefail` at file top (sourced lib invariant)

## Acceptance Criteria Coverage

All BRIDGE-GEN-01 through BRIDGE-GEN-04 requirements satisfied:

- BRIDGE-GEN-01: `bridge_create_project gemini` writes GEMINI.md; `bridge_create_project codex`
  writes AGENTS.md (NOT CODEX.md). Re-run yields byte-identical content. PASS
- BRIDGE-GEN-02: `bridge_create_global gemini` writes `$home/.gemini/GEMINI.md` after mkdir -p;
  `bridge_create_global codex` writes `$home/.codex/AGENTS.md`. Never touches source CLAUDE.md. PASS
- BRIDGE-GEN-03: Banner is byte-identical across all call sites — single `cat <<'BANNER'` heredoc
  in `_bridge_write_file` with single-quoted delimiter suppressing all expansion. PASS
- BRIDGE-GEN-04: Each successful create writes one entry in `toolkit-install.json::bridges[]` with
  all required fields; dedup by (target,scope,path); `user_owned: false`; atomic via tempfile+replace. PASS

## Deviations from Plan

None - plan executed exactly as written. All four tasks were implementable as a single
file-creation operation since the full content was specified verbatim in the plan, and
all verification checks passed on first attempt.

## Known Stubs

None. All public API functions are fully implemented.

## Threat Flags

None. `bridges.sh` reads local filesystem files only (CLAUDE.md under project root or home dir)
and writes to sibling files. No network endpoints, no auth paths, no user-controlled URL
construction. SHA256 hashes are computed after write using the trusted `sha256_file` helper.

## Self-Check: PASSED

- `scripts/lib/bridges.sh` exists at 249 lines: CONFIRMED
- Commit `67581c1` exists in git log: CONFIRMED
- All public API functions (`bridge_create_project`, `bridge_create_global`) declared and functional: CONFIRMED
- All internal helpers (`_bridge_home`, `_bridge_filename`, `_bridge_global_dir`, `_bridge_write_file`, `_bridge_write_state_entry`) declared and functional: CONFIRMED
- shellcheck -S warning exits 0: CONFIRMED
- No phantom state.sh names (`_state_lock`, `_atomic_json_write`, `state_get`, `state_set`): CONFIRMED
