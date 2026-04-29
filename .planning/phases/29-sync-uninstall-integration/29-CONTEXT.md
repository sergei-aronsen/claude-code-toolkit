# Phase 29: Sync & Uninstall Integration - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Phase 29 wires the Phase 28 bridge primitives into the existing **update + uninstall lifecycle**:

1. Extends `scripts/update-claude.sh` with a `sync_bridges()` step that iterates `bridges[]` from `~/.claude/toolkit-install.json` and recopies / prompts / skips per source-vs-bridge SHA256 deltas.
2. Adds `--break-bridge <target>` / `--restore-bridge <target>` flags to `update-claude.sh` that mutate `user_owned` in state and exit 0 (state-only ops, do not chain into the regular update flow).
3. Extends `scripts/uninstall.sh` `REMOVE_LIST` / `MODIFIED_LIST` loop to include `bridges[]` paths (classified via existing `classify_file` SHA256 helper, prompted via existing UN-03 `[y/N/d]`).
4. Ships hermetic test `scripts/tests/test-bridges-sync.sh` covering the 5 ROADMAP success criteria.

**Out of scope for Phase 29:** install-time UX wiring (Phase 30 — `install.sh` Component rows, `init-claude.sh` post-install prompt, `--no-bridges` flag), manifest registration + version bump (Phase 31), branding substitution (deferred BRIDGE-FUT-01).

</domain>

<decisions>
## Implementation Decisions

### Sync loop integration (BRIDGE-SYNC-01)

- **Where:** new function `sync_bridges()` in `scripts/update-claude.sh`, invoked AFTER `write_state` completes. Bridges are post-state because their SHA refresh depends on the state-file containing `bridges[]` survived the `write_state` rebuild (see "State preservation" below).
- **Iteration source:** read `.bridges[]` array from `~/.claude/toolkit-install.json` via `jq -c '.bridges // [] | .[]'`. Empty array → no-op, no log.
- **Per-entry decision tree (mirrors REQUIREMENTS.md BRIDGE-SYNC-01 verbatim):**

  ```text
  current_src_sha = sha256_file($source_path)        # CLAUDE.md
  current_bridge_sha = sha256_file($bridge_path)     # GEMINI.md / AGENTS.md
  recorded_src_sha = entry.source_sha256
  recorded_bridge_sha = entry.bridge_sha256
  user_owned = entry.user_owned

  IF user_owned:                              → SKIP, log "[- SKIP] $bridge (--break-bridge)"
  ELIF source missing:                        → ORPHAN, log "[? ORPHANED] $bridge (CLAUDE.md missing)", flip user_owned=true
  ELIF current_bridge_sha != recorded_bridge_sha:
      User edited bridge — drift              → prompt [y/N/d]
                                                  y: rewrite, refresh both SHAs
                                                  N: keep, log "[~ MODIFIED] $bridge (kept)"
                                                  d: diff(bridge, would-be-content), re-prompt
  ELIF current_src_sha != recorded_src_sha:
      Source changed, bridge clean            → REWRITE via bridge_create_*, refresh both SHAs, log "[~ UPDATE] $bridge"
  ELSE:                                        → SKIP silently (no log; in-sync)
  ```

- **API:** `sync_bridges` reuses `bridge_create_project` / `bridge_create_global` from `scripts/lib/bridges.sh` for the rewrite path. The sync function itself dispatches by `entry.scope` (`project` vs `global`).
- **State refresh:** rewrite path refreshes SHAs by calling `bridge_create_*` which already invokes `_bridge_write_state_entry` — dedup-by-triple replaces the entry in place. No separate state mutation in `sync_bridges`.

### `--break-bridge` / `--restore-bridge` flags (BRIDGE-SYNC-02)

- **Flag mode:** when present, parse target, mutate `user_owned`, write atomic state, exit 0. Does NOT chain into the regular update flow. User runs `update-claude.sh` again normally to take effect (mirrors `--keep-state` flag-only semantics from v4.4 KEEP-01).
- **API:** new helper `_bridge_set_user_owned <target> <true|false>` added to `scripts/lib/bridges.sh`. Reuses the `_bridge_write_state_entry` Python pattern (atomic mkstemp + os.replace, dedup by triple).
- **Resolution:** if `--break-bridge gemini` matches multiple entries (e.g., both project + global gemini bridges), all are flipped — single-flag-many-rows. Reduces UX confusion vs. requiring scope qualifier.
- **Validation:** target must be `gemini` or `codex` (case-insensitive). Other values exit 2 with usage error.
- **`--restore-bridge`:** flips `user_owned: false`. Next `update-claude.sh` run re-syncs (per the decision tree above).

### Orphaned source handling (BRIDGE-SYNC-03)

- **Trigger:** `[ ! -f "$source_path" ]` for any bridge entry during sync.
- **Action:** log `[? ORPHANED] $bridge_path (CLAUDE.md missing)`, flip `user_owned: true` in state via `_bridge_set_user_owned`. Bridge file on disk stays untouched.
- **Rationale:** if `CLAUDE.md` is later restored, the next `update-claude.sh` run sees `user_owned: true` and skips silently. User must explicitly `--restore-bridge` to opt back in. Prevents accidental overwrite of a bridge a user kept after deleting their CLAUDE.md.

### State preservation across `write_state` (CRITICAL)

- **Problem:** v4.0 STATE-04 `write_state(...)` rebuilds the full JSON document from scalar args. It would clobber `bridges[]` on every install/update.
- **Decision (locked):** extend `write_state` signature with a 10th arg `bridges_json` (raw JSON string, default `'[]'`). The Python heredoc parses it and includes it under `state["bridges"]`. Existing callers that don't pass the 10th arg get `[]` (backward-compatible default).
- **Caller updates:**
  - `scripts/install.sh` — passes existing `bridges_json` if state exists, else `[]`. Helper: read `.bridges // []` from current state via jq before write.
  - `scripts/update-claude.sh` — same pattern: capture existing `bridges_json`, pass through `write_state`, then call `sync_bridges` (which mutates `bridges[]` per-entry via `_bridge_write_state_entry`).
- **Single source of truth:** `bridges[]` mutation lives in `bridges.sh` only (`_bridge_write_state_entry` for create/update entries, `_bridge_set_user_owned` for flag flips). `write_state` becomes pass-through for bridges.

### Drift prompt (`[y/N/d]`)

- **Source pattern:** copy `prompt_modified_for_uninstall` from `scripts/uninstall.sh:236-291` minus the protected-path check (no protected paths inside bridges) and minus the `KEEP_LIST` global (sync uses its own counters).
- **New helper:** `bridge_prompt_drift <bridge_path>` added to `scripts/lib/bridges.sh`. Returns 0 (overwrite) | 1 (keep) — `d` re-prompts internally.
- **TTY source:** `< /dev/tty` default, swappable via `TK_BRIDGE_TTY_SRC` env var (mirrors `TK_UNINSTALL_TTY_FROM_STDIN`). Fail-closed N on EOF / unreachable TTY.
- **`d` (diff) implementation:** generates the would-be-rewritten content into a tempfile (banner + verbatim source), runs `diff -u "$bridge_path" "$tmp_new"`, paginates if `<` 100 lines (else `less`-fallback NOT introduced — keep simple, just print). Cleans the tempfile via `RETURN` trap.
- **Default N:** unknown / empty / EOF input → keep file untouched. Conservative — never overwrite user's edits without explicit `y`.

### Uninstall integration (BRIDGE-UN-01)

- **Where:** in `scripts/uninstall.sh`, after the existing loop that walks `installed_files[]` (line ~471), add a parallel walk over `.bridges // []`. Use the same `classify_file` helper (line 195) — bridges are tracked files like any other.
- **Output formatting:** REMOVE / MODIFIED / KEEP / MISSING / PROTECTED rows printed via the existing `dro_print_*` helpers; bridges blend into the totals.
- **Same `[y/N/d]` prompt:** existing `prompt_modified_for_uninstall` works as-is — the diff reference comes from re-running `bridge_create_*` against a tempfile path, OR from "reference unavailable" message (acceptable per Phase 29 minimal scope; Phase 31 BRIDGE-DOCS-01 documents this).
- **State cleanup post-uninstall:** when a bridge file is removed (REMOVE branch), remove its entry from `bridges[]` via `_bridge_remove_state_entry <target> <scope> <path>`. Helper added to `bridges.sh`. Mirrors `_bridge_write_state_entry` Python shape but does `entries = [e for e in entries if (e['target'], e['scope'], e['path']) != key]`.
- **`--keep-state`:** existing v4.4 KEEP-01 path skips state mutation entirely. Bridge files still get removed (REMOVE_LIST processed); state retained for re-run recovery (per BRIDGE-UN-02). No special case.

### Code organization

- All new state-mutating helpers live in `scripts/lib/bridges.sh`:
  - `_bridge_set_user_owned <target> <true|false>`
  - `_bridge_remove_state_entry <target> <scope> <path>`
  - `bridge_prompt_drift <bridge_path>` (returns 0/1)
- `update-claude.sh` only orchestrates: parse flags, capture bridges_json before write_state, call sync_bridges loop. Loop body delegates to `bridges.sh` helpers + `bridge_create_*`.
- `uninstall.sh` only adds a small loop appending bridges to existing `REMOVE_LIST` / `MODIFIED_LIST` and a post-loop cleanup call to `_bridge_remove_state_entry` for each successfully removed bridge.
- All new bash uses `set -euo pipefail` ONLY in executables (`update-claude.sh`, `uninstall.sh`, test). Sourced lib (`bridges.sh`) does NOT (already established in Phase 28).

### Test seams

- `TK_BRIDGE_TTY_SRC` — overrides drift-prompt TTY input source. Tests inject answers via here-doc.
- `TK_BRIDGE_HOME` — already in Phase 28; sandboxes state file + bridge file paths. Reused.
- `TK_UPDATE_MANIFEST_OVERRIDE` — already in update-claude.sh; tests pass a local manifest path.
- New: `scripts/tests/test-bridges-sync.sh` with ≥10 assertions covering:
  1. Clean source → bridge: no-op, no log
  2. Source edited → bridge clean: `[~ UPDATE]` + SHA refresh
  3. Bridge edited → drift prompt: `y` overwrites, `N` keeps, `d` shows diff and re-prompts
  4. `--break-bridge gemini` → `user_owned=true`; next run skips `[- SKIP]`
  5. `--restore-bridge gemini` → `user_owned=false`; next run re-syncs
  6. `CLAUDE.md` deleted → `[? ORPHANED]` + auto-flip `user_owned=true`
  7. `uninstall.sh` clean → REMOVE branch, bridges[] entry purged
  8. `uninstall.sh` modified bridge → `[y/N/d]` prompt, `N` keeps file, entry stays
  9. `uninstall.sh --keep-state` → bridges[] preserved alongside installed_files[]
  10. BACKCOMPAT: `test-bootstrap.sh` PASS=26, `test-install-tui.sh` PASS=43, `test-bridges-foundation.sh` PASS=5 unchanged
- Existing `test-bridges-foundation.sh` (Phase 28) still passes — unchanged file.

### Header banner content (locked, unchanged from Phase 28)

Same 4-line HTML comment from `bridges.sh:_bridge_write_file`. No change in Phase 29.

### Claude's Discretion

- Internal helper names: `_bridge_set_user_owned`, `_bridge_remove_state_entry`, `bridge_prompt_drift` are recommendations — planner may rename if shorter / clearer.
- Exact `dro_*` log markers — `[~ UPDATE]`, `[~ MODIFIED]`, `[- SKIP]`, `[? ORPHANED]` are the locked dispatch markers; print them via existing dro_print_* helpers from `scripts/lib/dry-run-output.sh`.
- Whether `sync_bridges` is a self-contained function in `update-claude.sh` body or extracted into `bridges.sh` — planner picks. Recommended: define in `update-claude.sh` (it's update-flow orchestration), call lib helpers for state mutation.
- Whether to support `--break-bridge gemini:project` scope qualifier — defer to Phase 30 / v4.8 if user demand surfaces. Phase 29: target-only, all-scope.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/lib/state.sh::write_state` (`scripts/lib/state.sh:60-138`) — extends to 10-arg signature for `bridges_json` passthrough. Python heredoc adds `state["bridges"] = json.loads(bridges_json)` line.
- `scripts/lib/state.sh::sha256_file` — POSIX-portable SHA256 helper, already used by Phase 28 bridges.sh. Reused for sync deltas.
- `scripts/lib/state.sh::acquire_lock` / `release_lock` — used inside `_bridge_write_state_entry`; sync loop wraps in single lock for batch consistency (or per-entry — planner decides; per-entry simpler, batch atomic).
- `scripts/uninstall.sh::classify_file` (`scripts/uninstall.sh:195-222`) — returns REMOVE/KEEP/MODIFIED/MISSING/PROTECTED. Bridges fed in directly.
- `scripts/uninstall.sh::prompt_modified_for_uninstall` (`scripts/uninstall.sh:236-291`) — `[y/N/d]` shape to copy for `bridge_prompt_drift`. Uses `< /dev/tty` + `TK_UNINSTALL_TTY_FROM_STDIN` test seam (mirror as `TK_BRIDGE_TTY_SRC`).
- `scripts/lib/dry-run-output.sh::dro_print_header / dro_print_file / dro_print_total` — chezmoi-grade output. Reused for sync log lines.
- `scripts/update-claude.sh:96-110` — manifest fetch + content-hash compare. `sync_bridges()` slots in after the existing install loop completes.
- `scripts/update-claude.sh:269-310` — `synthesize_v3_state` walks manifest paths and assembles `installed_csv`; not modified, but pattern for "iterate jq array → call helper" is reused.
- `scripts/lib/bridges.sh::_bridge_write_state_entry` (Phase 28, `scripts/lib/bridges.sh:130-181`) — atomic Python patch shape; new helpers (`_bridge_set_user_owned`, `_bridge_remove_state_entry`) reuse the same `mkstemp + os.replace` idiom.
- `scripts/lib/bridges.sh::bridge_create_project / bridge_create_global` (Phase 28) — invoked from `sync_bridges` rewrite branch.

### Established Patterns

- All flag parsing in `update-claude.sh` is `while [[ $# -gt 0 ]]` + `case` (lines 28-50). Add `--break-bridge` / `--restore-bridge` as new cases that set a `BREAK_TARGET` / `RESTORE_TARGET` var, then post-loop dispatch (mutate state, exit 0) before the regular flow runs.
- `[y/N/d]` prompts always reread on `d` (no max-iterations cap). EOF/unreachable TTY → fail-closed N.
- Test seams `TK_*` always `${VAR:-default}` fallback. Never required, never break production.
- jq array iteration via `jq -c '... | .[]'` then `while IFS= read -r entry; do ... done`. Pattern from `update-claude.sh:269-310`.
- All dro output goes through `dro_init_colors` once before any `dro_print_*` call (handled by update-claude.sh main flow already).

### Integration Points

- `scripts/install.sh` (Phase 30) — invokes `bridge_create_project / bridge_create_global` at install time. Phase 29 only ensures these calls survive `write_state` via the 10-arg extension.
- `scripts/update-claude.sh` (Phase 29) — owns `sync_bridges` and `--break-bridge` / `--restore-bridge` flag handling.
- `scripts/uninstall.sh` (Phase 29) — owns bridges-in-REMOVE_LIST and post-removal `_bridge_remove_state_entry`.
- `manifest.json::files.libs[]` (Phase 31) — registers `scripts/lib/bridges.sh`. Until then, `update-claude.sh` ships `bridges.sh` via the unchanged install loop because `bridges.sh` is also synthesized into `installed_files[]` once Phase 31 lands. For Phase 29 hermetic tests, bridges.sh is sourced from the worktree directly via test seams.

</code_context>

<specifics>
## Specific Ideas

- The `write_state` 10-arg extension is the **only** place we touch `state.sh`. Single, surgical, atomic change. Reduces blast radius vs. multiple `bridges[]` patches scattered across callers.
- `sync_bridges` runs UNCONDITIONALLY (not just when manifest changed). User edits to `CLAUDE.md` itself don't trigger manifest hash changes (manifest hashes the toolkit files, not project content), so `sync_bridges` must run every `update-claude.sh` invocation regardless of `is_update_noop`.
- `--break-bridge` / `--restore-bridge` are state-only ops. They do NOT mutate the bridge file content. Bridge file stays exactly as user edited it. Next sync skips it (broken) or re-syncs it (restored), per `user_owned`.

</specifics>

<deferred>
## Deferred Ideas

- **Per-scope break flag** (BRIDGE-FUT-06): `--break-bridge gemini:project` qualifier. Defer to v4.8 if multi-scope users emerge. Phase 29: target-only, all-scope.
- **Bridge auto-restore on CLAUDE.md re-add** (BRIDGE-FUT-07): when a previously-orphaned source returns, auto-flip `user_owned: false` if bridge SHA still matches recorded. Risky (overwrites user intent) — keep manual `--restore-bridge`.
- **`update-claude.sh --bridges-only` mode** (BRIDGE-FUT-05, original from Phase 28 deferred): edge utility, out of v4.7 scope.
- **Bulk break/restore** (`--break-all-bridges`): trivial alias; defer.
- **Bridge sync dry-run** (`--dry-run` already partial): full integration with `sync_bridges` planning output. Defer to Phase 30 install-flow improvements.

</deferred>
