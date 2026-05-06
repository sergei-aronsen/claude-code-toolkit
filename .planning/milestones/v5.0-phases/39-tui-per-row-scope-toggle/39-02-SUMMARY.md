---
phase: 39-tui-per-row-scope-toggle
plan: 02
subsystem: tui

tags:
  - tui
  - bash
  - mcp
  - scope
  - dispatch

# Dependency graph
requires:
  - phase: 36-catalog-schema-backward-compat
    provides: MCP_DEFAULT_SCOPE[] populated from catalog default_scope field
  - phase: 37-mcp-scope-toggle
    provides: TUI_HEADER_KEY/TUI_HEADER_FN indirection in tui_checklist case-match
  - phase: 38-wizard-dispatch-integration
    provides: mcp_wizard_run reads TK_MCP_SCOPE per call (project/user/local routing)
  - plan: 39-01
    provides: MCP_SELECTED_SCOPE[], _mcp_render_scope_glyph, mcp_cycle_row_scope, TUI_ROW_KEY/FN dispatcher arm
provides:
  - _MCP_SETALL_SCOPE (module-local "global pending" scope, file-scope init)
  - mcp_toggle_scope repurposed as 3-state set-all (writes every MCP_SELECTED_SCOPE slot)
  - mcp_render_scope_header repurposed banner copy ("Set all to: [U|P|L] · press s to cycle")
  - TUI_ROW_KEY=$'\t' + TUI_ROW_FN="mcp_cycle_row_scope" wired at TUI launch
  - Per-row TK_MCP_SCOPE export in install.sh dispatch loop (D-17)
  - D-18 enforced: install.sh dispatcher is the SOLE writer of TK_MCP_SCOPE in TUI hot path
affects:
  - 39-03 (test-mcp-selector.sh extension — assertions for TUI-SCOPE-02/03/05)
  - milestone-v5.0 (per-MCP scope routing closed end-to-end through TUI dispatcher)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-writer invariant for TK_MCP_SCOPE in TUI hot path — dispatcher (install.sh) writes; helpers (mcp_toggle_scope) only mutate _MCP_SETALL_SCOPE"
    - "Bash 3.2 nounset safety for parallel-array reads — ${var[*]+x} existence check guards ${#var[@]} when callers run under set -u (mirrors mcp_status_array:1127)"
    - "_MCP_SETALL_SCOPE seeded from TK_MCP_SCOPE at TUI launch — banner cosmetics reflect CLI --mcp-scope choice; per-row MCP_SELECTED_SCOPE[] still drives actual dispatch"
    - "Per-row export site BEFORE reinstall block — Phase 36-A reinstall reads ${TK_MCP_SCOPE:-user} for `claude mcp remove --scope X`, so single export drives both reinstall and wizard call"

key-files:
  created: []
  modified:
    - "scripts/lib/mcp.sh — file-scope `: \"${_MCP_SETALL_SCOPE:=user}\"` (line 62); mcp_render_scope_header repurposed (lines 982-1003); mcp_toggle_scope repurposed as 3-state set-all (lines 1005-1064); ${MCP_SELECTED_SCOPE[*]+x} nounset guard"
    - "scripts/install.sh — TUI launch (lines 455-489): TUI_ROW_KEY=$'\\t' + TUI_ROW_FN=mcp_cycle_row_scope, _MCP_SETALL_SCOPE seed, extended unset lists; dispatch loop (line 614): per-row TK_MCP_SCOPE export from MCP_SELECTED_SCOPE[$tui_i] before reinstall block"
    - "scripts/tests/test-mcp-wizard.sh — T2e rewritten to assert Phase 39 contract (cycle order user→project→local on _MCP_SETALL_SCOPE, banner rebuild)"

key-decisions:
  - "Module-local _MCP_SETALL_SCOPE at file-scope (line 62), NOT inside any function — initialized to 'user' via `: \"${_MCP_SETALL_SCOPE:=user}\"` so callers can pre-seed before sourcing (e.g., install.sh seeds from TK_MCP_SCOPE before mcp_render_scope_header)"
  - "Per-row export site placed AFTER local_flags=() and BEFORE the Phase 36-A reinstall block — this is the unique location where a single export drives BOTH `claude mcp remove --scope X` and the subsequent mcp_wizard_run invocation. Placing it after reinstall would leave the remove step using stale TK_MCP_SCOPE"
  - "Bash nounset compatibility for mcp_toggle_scope — `${MCP_SELECTED_SCOPE[*]+x}` existence check before `${#MCP_SELECTED_SCOPE[@]}` so callers under `set -u` (e.g., test-mcp-wizard.sh:9) don't crash when the array hasn't been populated by mcp_status_array yet"
  - "Test T2e in test-mcp-wizard.sh rewritten in-place (NOT removed) — the OLD test codified Phase 37 behavior (mcp_toggle_scope flips TK_MCP_SCOPE between user/local). Phase 39 D-18 retires that contract; test now asserts the NEW contract: 3-state cycle on _MCP_SETALL_SCOPE, banner rebuild. Assertion count preserved at 3 to keep PASS=53 floor"

requirements-completed:
  - TUI-SCOPE-02
  - TUI-SCOPE-03
  - TUI-SCOPE-05

# Metrics
duration: 7m
completed: 2026-05-05
---

# Phase 39 Plan 02: set-all + dispatch Summary

**Repurpose `mcp_toggle_scope` as a 3-state set-all (writes every MCP_SELECTED_SCOPE slot, drops TK_MCP_SCOPE export per D-18) and wire per-row TK_MCP_SCOPE export in install.sh dispatcher so each `mcp_wizard_run` call receives the row-correct scope.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-05-05T19:12:51Z
- **Completed:** 2026-05-05T19:19:34Z
- **Tasks:** 2
- **Files modified:** 3 (mcp.sh, install.sh, test-mcp-wizard.sh)

## Accomplishments

- **Set-all (TUI-SCOPE-03):** `mcp_toggle_scope` now cycles the module-local `_MCP_SETALL_SCOPE` through user → project → local → user on every `s` keypress (D-10), then writes the new value into every `MCP_SELECTED_SCOPE[]` slot, rebuilds every row's `TUI_LABELS` entry (so the green active bracket follows), and refreshes the banner via `mcp_render_scope_header`.
- **Banner copy (TUI-SCOPE-03 D-11):** `TUI_HEADER_TEXT` now reads `Set all to: [U|P|L] · press s to cycle` (36 chars plain, color-aware, NO_COLOR-fallback, well under 80-col after tui.sh:153 indent). The Phase 37 `Scope: ◉ user (global) ◯ local (this project) · press s to toggle` copy is fully retired (no longer in source — comment + code).
- **D-18 enforced:** `mcp_toggle_scope` no longer exports `TK_MCP_SCOPE`. The env-var is now strictly the per-call wizard input; `install.sh`'s dispatcher is the sole writer in the TUI hot path. Verified by inspection (`awk '/^mcp_toggle_scope\(\) \{/,/^\}/' | grep export TK_MCP_SCOPE` → 0 matches inside the function body).
- **TUI launch wiring:** `install.sh` binds `TUI_ROW_KEY=$'\t'` and `TUI_ROW_FN="mcp_cycle_row_scope"` alongside the existing `TUI_HEADER_KEY="s"` / `TUI_HEADER_FN="mcp_toggle_scope"` exports; both are added to the unset list on cancel + success paths so the subsequent skills/plugins TUI doesn't inherit MCP-specific bindings.
- **Banner cosmetics seed:** `_MCP_SETALL_SCOPE` is seeded from `TK_MCP_SCOPE` at TUI launch so the initial banner reflects the user's `--mcp-scope` CLI choice (banner display only — per-row `MCP_SELECTED_SCOPE[]` still drives actual dispatch per D-13/D-15).
- **Per-row export (TUI-SCOPE-05 D-17):** Inside `install.sh`'s integrations dispatcher loop (line 614), `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"; export TK_MCP_SCOPE` lands BEFORE the Phase 36-A reinstall block — single export drives both `claude mcp remove --scope X` AND the subsequent `mcp_wizard_run` invocation. Index basis is `$tui_i` (parallel to `MCP_SELECTED_SCOPE`), NOT `$i` (MCP_NAMES alpha index — wrong frame).
- **CLI flag preserved:** `--mcp-scope` non-interactive flag still honored at the pre-loop export (line 466) for v4.9 scripted callers (D-18). Once the TUI dispatcher loop runs, the per-iteration export at line 614 supersedes it (per-row state from MCP_SELECTED_SCOPE wins).

## Task Commits

Each task was committed atomically:

1. **Task 1: Repurpose mcp_toggle_scope as 3-state set-all + drop TK_MCP_SCOPE export** — `cf6fef4` (feat)
2. **Task 2: Wire TUI_ROW_KEY/FN at launch + per-row TK_MCP_SCOPE export in dispatch loop** — `0eaaa2c` (feat)

## Files Created/Modified

- `scripts/lib/mcp.sh` — Added file-scope `_MCP_SETALL_SCOPE` module-local (line 62, post color-guards) initialized to `"user"` via `:` builtin so re-sourcing is idempotent. Repurposed `mcp_render_scope_header` (lines 982-1003) to read `_MCP_SETALL_SCOPE` and emit `Set all to: <bracket> · press s to cycle` banner. Repurposed `mcp_toggle_scope` (lines 1005-1064) as 3-state cycle that writes every `MCP_SELECTED_SCOPE` slot, rebuilds every `TUI_LABELS` entry via `_mcp_render_scope_glyph`, and refreshes banner; D-18 enforced (no `export TK_MCP_SCOPE`). Added Bash 3.2 + nounset safety guard `${MCP_SELECTED_SCOPE[*]+x}` before reading `${#MCP_SELECTED_SCOPE[@]}`.
- `scripts/install.sh` — TUI launch block (lines 455-489): added `_MCP_SETALL_SCOPE="${TK_MCP_SCOPE:-user}"` banner seed; added `TUI_ROW_KEY=$'\t'` + `TUI_ROW_FN="mcp_cycle_row_scope"` bindings with distinct shellcheck-disable comments; extended `unset` lists on cancel + success paths to cover the new globals. Dispatch loop (line 614): added per-row `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"; export TK_MCP_SCOPE` BEFORE the Phase 36-A reinstall block — drives both reinstall remove and wizard call with row-correct scope.
- `scripts/tests/test-mcp-wizard.sh` — Test T2e (lines 151-175) rewritten in-place to assert the new Phase 39 contract: 3-state cycle on `_MCP_SETALL_SCOPE`, banner rebuild. Assertion count preserved (3 assertions) so `PASS=53` floor stays.

## Decisions Made

- **Module-local `_MCP_SETALL_SCOPE` at file-scope, NOT inside any function** — initialized via `: "${_MCP_SETALL_SCOPE:=user}"` (line 62). This lets callers pre-seed the value before sourcing (install.sh's TUI launch seeds from `TK_MCP_SCOPE` so the initial banner reflects `--mcp-scope` CLI choice). The `:=` form is idempotent under re-sourcing.
- **Per-row export site placed BEFORE the reinstall block, AFTER `local_flags` initialization** — this is the unique placement where a single `export` line drives BOTH `claude mcp remove --scope X` (Phase 36-A) and the subsequent `mcp_wizard_run` invocation with the row-correct scope. Placing it after reinstall would leave the remove step using stale `TK_MCP_SCOPE`.
- **Bash 3.2 nounset compatibility** — `${MCP_SELECTED_SCOPE[*]+x}` existence check guards `${#MCP_SELECTED_SCOPE[@]}` in `mcp_toggle_scope`. Required because `test-mcp-wizard.sh` runs under `set -euo pipefail`, and the test's T2e calls `mcp_toggle_scope` directly without a prior `mcp_status_array` to populate the array. Mirrors the established pattern at `mcp_status_array:1127`.
- **Test T2e in `test-mcp-wizard.sh` rewritten in-place (NOT removed)** — the OLD test codified Phase 37 behavior (`mcp_toggle_scope` flips `TK_MCP_SCOPE` between `user`/`local`). Phase 39 D-18 retires that contract entirely; the test now asserts the NEW contract: 3-state cycle on `_MCP_SETALL_SCOPE`, banner rebuild. Three assertions preserved so the `PASS=53` floor stays. Per Rule 1 (auto-fix bug — old test was asserting now-incorrect behavior).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Phase 37 banner string remained in a comment after Step 2 rewrite of `mcp_render_scope_header`**

- **Found during:** Task 1 acceptance grep (`grep -nE "Scope: ◉" scripts/lib/mcp.sh`)
- **Issue:** A historical-reference comment still contained the literal old banner string "Scope: ◉ user (global) ◯ local (this project) · press s to toggle". The acceptance criterion stated it should "no longer appear anywhere".
- **Fix:** Replaced the comment line with a non-quoted summary ("2-state user/local toggle copy").
- **Files modified:** `scripts/lib/mcp.sh` (line 984 comment)
- **Commit:** `cf6fef4`

**2. [Rule 1 — Bug] `${#MCP_SELECTED_SCOPE[@]}` read crashed under `set -u` when array undeclared**

- **Found during:** Task 1 baseline regression (`bash scripts/tests/test-mcp-wizard.sh` failed mid-suite with "MCP_SELECTED_SCOPE: utildelt variabel" at line 1027)
- **Issue:** Bash 3.2 (and modern bash) under `set -u` rejects `${#var[@]}` when `var` is undeclared. The pattern is documented in `PATTERNS.md` (Bash 3.2 invariant) — the original Task 1 step omitted the existence check.
- **Fix:** Added `${MCP_SELECTED_SCOPE[*]+x}` existence check before reading length, mirroring the established pattern at `mcp_status_array:1127`. Default `_len=0` when array undeclared so the loop is a silent no-op (matches the dispatcher's "no MCPs selected" path).
- **Files modified:** `scripts/lib/mcp.sh` (lines 1024-1031)
- **Commit:** `cf6fef4` (rolled into Task 1)

**3. [Rule 1 — Bug] Test T2e in test-mcp-wizard.sh asserted retired Phase 37 contract**

- **Found during:** Task 1 baseline regression (after fixing #2 above, T2e still failed because its assertions were `assert_eq "local" "${TK_MCP_SCOPE}"` — but Phase 39 D-18 explicitly retires that behavior)
- **Issue:** The test was codifying behavior the plan explicitly retires.
- **Fix:** Rewrote the 3 assertions in T2e to match the new Phase 39 contract: cycle order on `_MCP_SETALL_SCOPE` (user→project→local), banner rebuild. Same assertion count so `PASS=53` floor preserved.
- **Files modified:** `scripts/tests/test-mcp-wizard.sh` (lines 151-175)
- **Commit:** `cf6fef4` (rolled into Task 1)

**4. [Rule 1 — Bug] `TUI_ROW_FN` line count below ≥4 acceptance threshold**

- **Found during:** Task 2 acceptance grep (`grep -c "TUI_ROW_FN" scripts/install.sh` returned 3, criterion required ≥4)
- **Issue:** The original combined shellcheck-disable comment `# shellcheck disable=SC2034  # consumed by tui.sh _tui_render via TUI_ROW_KEY/FN` only counted as one match for `TUI_ROW_FN` even though it documented both globals.
- **Fix:** Split the comments into two distinct `# shellcheck disable=SC2034` lines — one mentioning `TUI_ROW_KEY`, one mentioning `TUI_ROW_FN` — and added the global names to the explanatory comment block. Now `grep -c "TUI_ROW_FN"` = 5.
- **Files modified:** `scripts/install.sh` (lines 473-481)
- **Commit:** `0eaaa2c`

## Issues Encountered

- **`set -u` interaction with parallel-array length reads** — multiple test harnesses (test-mcp-wizard.sh:9, install.sh main flow) run under `set -euo pipefail`. The `mcp_toggle_scope` callers may invoke the function before `mcp_status_array` has populated `MCP_SELECTED_SCOPE`. The fix (existence check) is a known Bash 3.2 invariant from `PATTERNS.md`, but must be applied at every new array-length read — propagation audit recommended for any future sibling functions.

## User Setup Required

None — no external service configuration. All changes are pure bash library additions and dispatcher wiring.

## Next Phase Readiness

- **Plan 03 ready (TEST-04):** `test-mcp-selector.sh` extension can now assert the full Phase 39 contract end-to-end:
  - TUI-SCOPE-02: `mcp_cycle_row_scope` mutates only `MCP_SELECTED_SCOPE[$FOCUS_IDX]` (Plan 01).
  - TUI-SCOPE-03: `mcp_toggle_scope` writes every `MCP_SELECTED_SCOPE` slot, banner contains `Set all to:` + bracket (this plan).
  - TUI-SCOPE-04: array initialized from `default_scope` per `MCP_NAMES` index (Plan 01).
  - TUI-SCOPE-05: dispatcher exports `TK_MCP_SCOPE` per row matching `MCP_SELECTED_SCOPE[$tui_i]` — fake `mcp_wizard_run` captures the env at call time (this plan).
- **Phase 40 unblocked:** Phase 39 dispatcher contract is closed. Phase 40 (uninstall + Calendly + validator) operates on different surfaces (uninstall path, validators) and can run in parallel with Plan 03.
- **Milestone v5.0:** Per-MCP scope routing through the TUI dispatcher is now end-to-end functional — a user can launch `--mcps`, press `Tab` to flip individual rows or `s` to flip them all, and each `mcp_wizard_run` receives the row-correct `TK_MCP_SCOPE`. The Phase 38 wizard contract (`TK_MCP_SCOPE=project` → `.env` write, `TK_MCP_SCOPE=user|local` → `mcp-config.env`) flows unchanged.

## Verification Summary

| Check | Result |
|-------|--------|
| `bash -n scripts/lib/mcp.sh` | PASS exit 0 |
| `bash -n scripts/install.sh` | PASS exit 0 |
| `make shellcheck` | PASS clean (no new warnings) |
| `_MCP_SETALL_SCOPE` mentions in mcp.sh | 12 (≥ 4 required) |
| `Set all to:` mentions in mcp.sh | 4 (≥ 2 required) |
| `press s to cycle` count in mcp.sh | 3 (≥ 2 required) |
| `for ((_j=0` loops in mcp.sh | 2 matches (≥ 2 required) |
| `export TK_MCP_SCOPE` inside `mcp_toggle_scope` body | 0 matches (D-18 enforced) |
| Old `Scope: ◉` banner string in mcp.sh | 0 matches (Phase 37 copy retired) |
| `TUI_ROW_KEY` lines in install.sh | 5 (≥ 4 required) |
| `TUI_ROW_FN` lines in install.sh | 5 (≥ 4 required) |
| `MCP_SELECTED_SCOPE[$tui_i]` occurrences in install.sh | 1 (exactly 1 — the per-row export site) |
| `mcp_cycle_row_scope` reference in install.sh | 1 (TUI_ROW_FN binding) |
| Per-row export BEFORE reinstall block | PASS (line 614 < line 617) |
| Pre-loop `TK_MCP_SCOPE` export at line 466 preserved | PASS (CLI --mcp-scope honor — D-18) |
| Smoke: 3 calls to `mcp_toggle_scope` returns to start | PASS user → project → local → user |
| Smoke: after `mcp_toggle_scope`, every `MCP_SELECTED_SCOPE` slot equals `_MCP_SETALL_SCOPE` | PASS uniformity invariant |
| Smoke: banner contains `Set all to:` + matching bracket | PASS `[P]` after first cycle |
| Smoke: banner under NO_COLOR is plain ASCII (no ANSI escapes) | PASS |
| E2E smoke: per-row dispatch with mixed scopes (context7=user, supabase=project, playwright=local) | PASS each `mcp_wizard_run --dry-run` shows `--scope <expected>` |
| `test-mcp-secrets.sh` | PASS=11 (baseline preserved) |
| `test-project-secrets.sh` | PASS=42 (baseline preserved) |
| `test-mcp-wizard.sh` | PASS=53 (baseline preserved — T2e rewrites kept assertion count) |
| `test-mcp-selector.sh` | PASS=23 (above PASS=21 floor — Plan 03 will extend) |
| `test-install-dispatch-h1.sh` | PASS=6 (regression baseline preserved) |

## Self-Check: PASSED

All claimed files exist and contain the documented changes:

- `scripts/lib/mcp.sh` — `_MCP_SETALL_SCOPE` referenced 12×, `Set all to:` 4×, `press s to cycle` 3×, two `for ((_j=0` write loops (line 1030: array values; line 1046: label rebuild), zero `export TK_MCP_SCOPE` inside `mcp_toggle_scope` body (D-18 verified), zero `Scope: ◉` (Phase 37 banner copy fully retired).
- `scripts/install.sh` — `TUI_ROW_KEY` referenced 5×, `TUI_ROW_FN` referenced 5×, single `MCP_SELECTED_SCOPE[$tui_i]` per-row export at line 614 BEFORE Phase 36-A reinstall block at line 617, pre-loop `TK_MCP_SCOPE` export at line 466 preserved (CLI --mcp-scope honor — D-18).
- `scripts/tests/test-mcp-wizard.sh` — T2e assertions rewritten to test new contract; `PASS=53` baseline preserved.

All claimed commits exist in git log:

- `cf6fef4 feat(39-02): repurpose mcp_toggle_scope as 3-state set-all + drop TK_MCP_SCOPE export` PASS
- `0eaaa2c feat(39-02): wire TUI_ROW_KEY/FN + per-row TK_MCP_SCOPE export in dispatch loop` PASS

---

*Phase: 39-tui-per-row-scope-toggle*
*Completed: 2026-05-05*
