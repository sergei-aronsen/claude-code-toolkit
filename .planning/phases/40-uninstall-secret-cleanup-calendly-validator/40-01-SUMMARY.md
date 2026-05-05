---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 1
subsystem: infra
tags: [bash, uninstall, mcp, secrets, mcp-config.env, atomic-rewrite, jq, claude-cli]

# Dependency graph
requires:
  - phase: 25-mcp-foundation
    provides: scripts/lib/mcp.sh — mcp_secrets_load, _mcp_config_path, mcp_catalog_names, _mcp_list_cache_init, is_mcp_installed
  - phase: 32-catalog-rename
    provides: scripts/lib/integrations-catalog.json (env_var_keys per-MCP)
  - phase: 36-catalog-schema-backward-compat
    provides: SCOPE-01 default_scope field on every MCP entry (used downstream of this plan in 40-02/40-04)
provides:
  - "uninstall_prompt_mcp_keys <name> [<key>...] — TTY-prompt + atomic mode-0600 rewrite of ~/.claude/mcp-config.env that drops ONLY the named MCP's keys"
  - "First claude-mcp-remove loop in uninstall.sh — recovers names via claude mcp list ∩ mcp_catalog_names, runs `claude mcp remove --scope user <name>` per MCP, then calls the helper"
  - "lib/mcp.sh now sourced from uninstall.sh via TK_UNINSTALL_LIB_DIR test seam"
affects:
  - "40-02 (full-toolkit mcp-config.env prompt) — lands immediately downstream of this plan's per-MCP loop, before STATE_FILE removal"
  - "40-03 (KEEP_STATE implies KEEP_SECRETS) — wraps this plan's loop call site in a single [[ $KEEP_STATE -eq 0 ]] gate"
  - "40-05 (test-uninstall-state-cleanup.sh extension) — adds UN-SEC-01-Y / UN-SEC-01-N hermetic scenarios exercising this helper"

# Tech tracking
tech-stack:
  added: []  # No new external dependency. Reused jq (already required), bash 3.2+ (already required), claude CLI (already required by install.sh).
  patterns:
    - "TTY-read with TK_UNINSTALL_TTY_FROM_STDIN test seam + 5-attempt fail-closed-N cap (mirrors prompt_modified_for_uninstall:353-371)"
    - "Atomic mode-0600-preserving rewrite via mktemp + printf-loop + mv + chmod 0600 (mirrors mcp_secrets_set:553-583, with skip-set inversion)"
    - "Bash 3.2-safe skip-set membership via space-padded string + case word-boundary match (no associative array per CONTEXT D-16)"
    - "MCP recovery via `claude mcp list` ∩ mcp_catalog_names() intersection (fallback because installed_mcps[] does not exist in toolkit-install.json today; PATTERNS.md No Analog Found #2)"
    - "Graceful degradation: claude CLI absent → outer command -v guard false → silent skip (v4.4 LIB-01 D-09 fail-soft contract)"

key-files:
  created: []
  modified:
    - "scripts/uninstall.sh — added LIB_MCP_TMP, sourced lib/mcp.sh, defined uninstall_prompt_mcp_keys helper (~lines 408-533), inserted per-MCP cleanup loop (~lines 878-965)"

key-decisions:
  - "Reuse TK_UNINSTALL_TTY_FROM_STDIN test seam for the new helper — D-13 explicit (no new env-var coined). Helper TTY-read pattern mirrors prompt_modified_for_uninstall verbatim including 5-attempt fail-closed-N cap."
  - "Skip-set implemented as space-padded string `\" $* \"` with `case` word-boundary match instead of associative array — Bash 3.2 / macOS BSD compat per CONTEXT D-16."
  - "Per-MCP loop placed AFTER bridges[] purge and BEFORE post-run summary, NOT immediately upstream of STATE_FILE removal. Plan 40-02 will add the full-toolkit prompt at that final position; this placement keeps the 40-01 loop visible alongside the per-row classification output rather than after the user-facing summary."
  - "mcp_catalog_names() failure (catalog missing under curl-pipe) defended by `2>/dev/null || true` inside heredoc command-sub — even though Bash 3.2 doesn't propagate command-sub errexit, the explicit guard documents intent for future readers and survives any future inherit_errexit toggle."
  - "Helper logs only key NAMES and config-file path — never values (T-40-01-02 mitigation, CLAUDE.md §1 information-disclosure rule)."

patterns-established:
  - "uninstall_prompt_mcp_keys signature template: `<name> [<key>...]` returns 0 on N / no-op / OAuth-only / dry-run. Plan 40-02's full-toolkit helper will mirror this signature with name='*' and zero keys (to be confirmed in 40-02 planning)."
  - "Per-MCP loop scaffolding: `command -v claude` outer guard → INSTALLED_MCPS via while-read intersection → `if [[ ${#INSTALLED_MCPS[@]} -gt 0 ]]` → for-loop with `claude mcp remove` + helper call. Reusable shape if a future per-MCP uninstall command lands."
  - "Heredoc with command-substitution-with-fallback: `done <<EOF\\n\\$(some_cmd 2>/dev/null || true)\\nEOF` — Bash 3.2-safe, errexit-safe, line-delimited input-feed pattern."

requirements-completed: [UN-SEC-01, UN-SEC-02]

# Metrics
duration: 36min
completed: 2026-05-05
---

# Phase 40 Plan 1: uninstall_prompt_mcp_keys Helper + First claude-mcp-remove Loop in uninstall.sh

**Per-MCP secret-cleanup helper that prompts `[y/N] also remove keys K1, K2 from mcp-config.env?` and atomically rewrites the file in mode 0600 — closes the per-MCP half of the v5.0 uninstall secrets-leak gap.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-05-05T20:08:17Z
- **Completed:** 2026-05-05T20:44:50Z
- **Tasks:** 2
- **Files modified:** 1 (scripts/uninstall.sh; +225 lines: 136 helper / 89 loop / sourcing-loop tweak)

## Accomplishments

- New `uninstall_prompt_mcp_keys <name> [<key>...]` helper in `scripts/uninstall.sh` (~96 lines including docblock). Honors TK_UNINSTALL_TTY_FROM_STDIN test seam, defaults N, fails closed N on no-TTY (5-attempt cap). On Y: atomic `mktemp + mv + chmod 0600` rewrite that drops ONLY the named MCP's keys; other MCPs' entries preserved byte-identically. Mode 0600 enforced before AND after rewrite (defense-in-depth). Idempotent on repeat run (already-absent keys → file rewritten byte-identically).
- New per-MCP cleanup loop in the main flow (~lines 878-965). Recovers MCP names from `claude mcp list` ∩ `mcp_catalog_names()` (intersection because `installed_mcps[]` doesn't exist in `toolkit-install.json` today — PATTERNS.md "No Analog Found" #2). For each registered toolkit MCP: runs `claude mcp remove --scope user <name>` then calls the helper with that MCP's `env_var_keys` from the catalog.
- `scripts/lib/mcp.sh` added to uninstall.sh's `TK_UNINSTALL_LIB_DIR`-aware sourcing loop (was: `state.sh, backup.sh, dry-run-output.sh, bridges.sh`). Required to call `mcp_secrets_load`, `_mcp_config_path`, `mcp_catalog_names`, `_mcp_list_cache_init`, `is_mcp_installed`.
- Graceful degradation per v4.4 LIB-01 D-09 fail-soft contract: claude CLI absent → outer `command -v` guard false → empty `INSTALLED_MCPS` → block silently skipped, no log noise. Catalog file unreadable → empty `_keys` → helper short-circuits at `$# -lt 2`.
- D-08 dry-run gate inside helper: under `DRY_RUN=1` prints `[dry-run] would prompt: ...` and returns 0 with no filesystem writes (matches v4.3 zero-side-effects contract).
- Empty-keys path (Calendly / OAuth-only MCP): `if [[ $# -lt 2 ]]; then return 0; fi` short-circuits at the top of the helper. CONTEXT D-03 satisfied.

## Task Commits

Each task was committed atomically:

1. **Task 1: Source lib/mcp.sh from uninstall.sh + add uninstall_prompt_mcp_keys helper** — `48a661d` (feat)
2. **Task 2: Add per-MCP loop (claude mcp remove + uninstall_prompt_mcp_keys call)** — `71ba883` (feat)

(Final metadata commit lands after this SUMMARY is written.)

## Files Created/Modified

- `scripts/uninstall.sh` — three changes:
  1. New `LIB_MCP_TMP` mktemp (line 114), added to EXIT trap (line 122), and to the sourcing loop (line 129) with the existing `TK_UNINSTALL_LIB_DIR` test-seam pattern.
  2. New `uninstall_prompt_mcp_keys` function (~lines 408-533) — defined immediately after `prompt_modified_for_uninstall`, mirroring its TTY-handling pattern.
  3. New per-MCP cleanup block (~lines 878-965) — placed after the bridges[] purge block, before the post-run summary. Comment header explicitly documents D-04 graceful-degradation contract, D-06 ordering invariant, and the Plan 40-02/40-03 follow-on relationships.

## Decisions Made

- **Reuse TK_UNINSTALL_TTY_FROM_STDIN seam (no new env-var).** CONTEXT D-13 explicit. The helper's TTY block at lines 478-481 is a verbatim mirror of `prompt_modified_for_uninstall:353-356`.
- **Skip-set as space-padded string + `case` word-boundary match.** Bash 3.2 / macOS BSD compat per CONTEXT D-16 forbids `declare -A`. Pattern: `local skip_keys=" $* "` then `case "$skip_keys" in *" ${key} "*) ...`. Same idea is used for the BRIDGE_PATHS membership test at uninstall.sh:312-323 (parallel-array linear scan), so Bash 3.2 invariants are project-wide.
- **Helper placed after `prompt_modified_for_uninstall`, NOT in `lib/mcp.sh`.** CONTEXT D-01 explicit: uninstall-only logic stays in uninstall.sh; sibling functions (`prompt_modified_for_uninstall`, `strip_sentinel_block`, etc.) all live in-script. Keeps lib/mcp.sh's install/wizard surface unchanged.
- **Per-MCP loop placed BEFORE post-run summary** (not after sentinel-strip / base-plugin invariant block). The per-MCP `log_info "X MCP(s) registered..."` line and per-helper `log_success` lines belong with the file-classification narrative, not after `Uninstall Summary`. Plan 40-02 will sit downstream of the post-run summary, immediately upstream of `STATE_FILE` removal — that's the appropriate placement for the all-secrets prompt.
- **`claude mcp remove` quoted properly + suppressed via `>/dev/null 2>&1 || true`** (mirrors `install.sh:687` reinstall pattern). T-40-01-05 acceptance: a fake claude on PATH still cannot leak via this pipeline because output is muted; transient registration failures don't abort the uninstall (graceful per-MCP).
- **`jq -r --arg n "$_mcp_name"` for env_var_keys lookup.** T-40-01-04 mitigation: name passed as JSON variable, never interpolated into the filter string. Catalog source is toolkit-controlled, but this is defense-in-depth.

## Deviations from Plan

None — plan executed exactly as written, with one micro-adjustment:

### Micro-adjustment (not a deviation)

The plan's pseudocode in Task 2 used `# shellcheck disable=SC2086 -- intentional whitespace word-split on key list`. Shellcheck does NOT accept the `--` style for inline comments after directive keys (raised SC1072/SC1073 errors). Replaced with a separate documentation comment block above the directive, leaving just `# shellcheck disable=SC2086` on its own line. Equivalent semantics, accepted by shellcheck. Caught immediately by `shellcheck -S warning scripts/uninstall.sh` during Task 2 verification, fixed inline before commit.

## Issues Encountered

- **Pre-existing test failure unrelated to this plan:** `test-mcp-selector.sh:79` asserts `catalog contains 20 entries`, but commit `eae7b89 feat(40-04): add calendly MCP entry` (already on this branch from earlier Plan 40-04 work) bumps the count to 21. Test reports `PASS=35 FAIL=1` with `FAIL S1: catalog contains 20 entries`. **Out of scope for Plan 40-01** per the executor SCOPE BOUNDARY rule — this failure pre-existed at HEAD before Plan 40-01 began (verified via `git log --oneline -- scripts/lib/integrations-catalog.json` showing `eae7b89` lands BEFORE my commits `48a661d`/`71ba883`). PATTERNS.md "Calendly catalog entry" section already calls this out as Plan 40-04's responsibility ("Existing test `A5: components.mcp has exactly 20 entries` ... **WILL FAIL** after Calendly add (becomes 21). Phase 40 D-14 update bumps the magic number from 20 to 21 in that assertion."). The same fix needs to be applied to `test-mcp-selector.sh:79` (distinct from `test-integrations-catalog.sh` A5 — both files share the same stale 20 magic number). Logged in `deferred-items.md` for Plan 40-04 to pick up.

## User Setup Required

None — no external service configuration required. The new helper and loop are pure refactor + safety hardening; no new credentials, no new infrastructure dependencies.

## Verification Battery (matches plan `<verification>` section)

- `bash -n scripts/uninstall.sh` → PASS (clean parse).
- `shellcheck -S warning scripts/uninstall.sh` → PASS (clean).
- `make shellcheck` (project root) → PASS (✅ ShellCheck passed).
- `grep -c '^uninstall_prompt_mcp_keys()' scripts/uninstall.sh` → 1 (definition).
- `grep -nE 'uninstall_prompt_mcp_keys "\$_mcp_name"' scripts/uninstall.sh` → line 963 (call site).
- `grep -n '"mcp.sh:' scripts/uninstall.sh` → line 129 (sourcing loop, exactly once).
- `grep -n 'TK_UNINSTALL_TTY_FROM_STDIN' scripts/uninstall.sh` → existing line 363 + new line 481 (helper reuses seam, no new env var).
- `grep -n 'mktemp.*\.XXXXXX' scripts/uninstall.sh` → atomic-rewrite pattern present at line 512 (`tmp="$(mktemp "${cfg}.XXXXXX")"`).
- Ordering invariant: `INSTALLED_MCPS=()` at line 905 < `rm -f "$STATE_FILE"` at line 1050. UN-05 D-06 (STATE_FILE removal LAST) preserved.
- Idempotent dry-run smoke test (`TK_MCP_CLAUDE_BIN=/nonexistent`, twice in same sandbox) → both runs RC=0, no MCP-loop output (matches `<done>` criterion).
- Live (non-dry-run) smoke test in sandbox → RC=0, clean uninstall, no MCP-loop output when claude CLI absent.
- Inline functional test of helper (4 scenarios: drop one key / idempotent re-run / zero-keys call / drop multiple keys) → all behaviors verified against the contract: target keys dropped, other keys preserved byte-identically, mode 0600 maintained.

### Test-suite regression check (CONTEXT D-18 baseline)

| Suite | Expected baseline | Result | Status |
|-------|-------------------|--------|--------|
| `test-mcp-secrets.sh` | PASS=11 | 11 passed, 0 failed | ✓ |
| `test-mcp-wizard.sh` | PASS=53 | 53 passed, 0 failed | ✓ |
| `test-uninstall-state-cleanup.sh` | 11 assertions | all 11 passed | ✓ |
| `test-uninstall-prompt.sh` | 10 assertions | all 10 passed | ✓ |
| `test-uninstall-keep-state.sh` | 11 assertions | all 11 passed | ✓ |
| `test-project-secrets.sh` | PASS=42 | 42 passed, 0 failed | ✓ |
| `test-mcp-selector.sh` | PASS=36 | PASS=35 FAIL=1 | ⚠ pre-existing (Plan 40-04 owns; logged in deferred-items.md) |

No regressions caused by Plan 40-01.

## Next Phase Readiness

- **Plan 40-02** is unblocked: it lands the full-toolkit `mcp-config.env` prompt downstream of this plan's per-MCP loop, immediately upstream of STATE_FILE removal. The `mcp_secrets_load` global state populated by the helper is also reusable by 40-02's prompt-label logic (`X keys for Y MCPs` count surfaces from the same `MCP_SECRET_KEYS[]` array).
- **Plan 40-03** is unblocked: it wraps this plan's per-MCP loop call site in a `[[ $KEEP_STATE -eq 0 ]]` gate. Single-call-site change.
- **Plan 40-04** must update `test-mcp-selector.sh:79` magic-number (20 → 21) in addition to the `test-integrations-catalog.sh` A5 update already documented in PATTERNS.md. Logged in `deferred-items.md`.
- **Plan 40-05** test scenarios (UN-SEC-01-Y / UN-SEC-01-N) can target this helper directly via the `TK_UNINSTALL_TTY_FROM_STDIN=1` seam + STDIN-piped `y\n` or `N\n` answers, exercising the rewrite contract end-to-end.

UN-SEC-03 (full-toolkit `mcp-config.env` prompt) lands in Plan 40-02 immediately downstream of this plan's per-MCP loop.

---
*Phase: 40-uninstall-secret-cleanup-calendly-validator*
*Completed: 2026-05-05*

## Self-Check: PASSED

- File `scripts/uninstall.sh` exists and contains expected modifications: ✓
- Commit `48a661d` (Task 1) present in git log: ✓
- Commit `71ba883` (Task 2) present in git log: ✓
- `uninstall_prompt_mcp_keys` defined exactly once: ✓ (1 definition at line 438)
- `uninstall_prompt_mcp_keys "$_mcp_name"` call site exactly once: ✓ (1 call at line 963)
- `lib/mcp.sh` in sourcing loop exactly once: ✓ (line 129)
- `bash -n` clean: ✓
- `shellcheck -S warning` clean: ✓
- `make shellcheck` green: ✓
- UN-05 D-06 ordering preserved (per-MCP loop precedes STATE_FILE removal): ✓ (905 < 1050)
- No threat flags introduced: ✓ (all new surface covered by existing threat register T-40-01-01..06)
- No stubs introduced: ✓ (pure functional code, no UI placeholders, no TODO/FIXME)
