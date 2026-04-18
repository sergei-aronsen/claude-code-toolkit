---
phase: 03-install-flow
plan: "03"
subsystem: install-security
tags: [settings-merge, hook-collision, atomic-write, backup, safety-02, threat-model, tk-owned-marker]

# Dependency graph
requires:
  - phase: 03-install-flow
    plan: "01"
    provides: scripts/lib/install.sh skeleton with backup_settings_once sentinel + TK_SETTINGS_BACKUP global; sourced-library invariants
  - phase: 03-install-flow
    plan: "02"
    provides: print_dry_run_grouped full implementation; manifest-driven install modes; parallel-Phase-3 contract
provides:
  - merge_settings_python helper in scripts/lib/install.sh (partition by _tk_owned marker, append-both policy, atomic write via tempfile.mkstemp + os.replace)
  - merge_plugins_python helper in scripts/lib/install.sh (additive enabledPlugins merge preserving foreign keys)
  - TK_TEST_INJECT_FAILURE=1 environment variable injection point for test 8c (raises RuntimeError before atomic write)
  - scripts/setup-security.sh refactored to use backup_settings_once + merge_settings_python + merge_plugins_python; destructive matcher filter removed
  - SAFETY-04 INVARIANT header comment in setup-security.sh documenting the TK-owned subtree contract
  - scripts/tests/test-safe-merge.sh with 3 scenarios (8a foreign keys preserved, 8b backup created, 8c restore on failure)
  - Makefile Test 8 wired after Test 7
  - Fresh-install JSON template in setup-security.sh else-branch carries _tk_owned: true for re-run identification
affects: [04-update-flow (UPDATE-05 PID-aware backup naming builds on TK_SETTINGS_BACKUP sentinel contract), 05-security-hardening (the _tk_owned marker vocabulary is the ownership mechanism for any future TK-owned keys beyond hooks.PreToolUse)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TK-ownership marker pattern: _tk_owned: true inside a hook dict survives json.load/json.dump round-trip and is invisible to Claude Code hook execution (schema tolerance)"
    - "Append-both hook policy: foreign_entries + [new_tk_entry] ordering ensures SP/GSD hooks fire FIRST by array order; TK cannot preempt foreign security-critical hooks (T-03-04 mitigation)"
    - "Shared backup sentinel across multi-step scripts: TK_SETTINGS_BACKUP global + backup_settings_once idempotent → exactly ONE .bak.<unix-ts> per setup-security.sh run even with 2+ merge operations"
    - "Test-injection environment variable: TK_TEST_INJECT_FAILURE=1 raises RuntimeError BEFORE any file mutation → caller restore-from-backup logic exercised without corrupting test fixtures"
    - "Scenario-per-function test harness (mirrors test-state.sh): reset_scratch helper + assert_eq helper + per-scenario function keeps each test hermetic"

key-files:
  created:
    - scripts/tests/test-safe-merge.sh
  modified:
    - scripts/lib/install.sh
    - scripts/setup-security.sh
    - Makefile

key-decisions:
  - "assert_eq helper added to test-safe-merge.sh (not in plan) — refactored away SC2015 (A && B || C) info warnings to keep make shellcheck warning-free. report_pass/report_fail always return 0 so the pattern was safe, but the helper is cleaner and matches test-state.sh's explicit if/else style."
  - "Makefile edit included the `@echo \"\"` separator BETWEEN Test 8 invocation and `@echo \"All tests passed!\"` to match the cadence of Tests 1-7 (each followed by a blank line). Plan wording was ambiguous on placement; chose consistency with existing Tests."
  - "merge_plugins_python honors TK_TEST_INJECT_FAILURE=1 for symmetry with merge_settings_python (plan only required it on the former) — simpler to reason about and enables future plugin-level failure tests without re-editing lib/install.sh."

patterns-established:
  - "TK-ownership marker (_tk_owned: true) is the canonical mechanism for identifying TK-authored entries in ~/.claude/settings.json — any future TK-owned key beyond hooks.PreToolUse should adopt the same sentinel"
  - "One-backup-per-run across multi-mutation scripts: source lib/install.sh → call backup_settings_once before every merge → subsequent calls are no-ops via the TK_SETTINGS_BACKUP global"
  - "Restore-on-failure pattern: every merge_*_python call is wrapped in if/else with cp \"$TK_SETTINGS_BACKUP\" \"$SETTINGS_JSON\"; exit 1 on failure → pre-merge state is always recoverable"
  - "Plan-level TDD cadence (test(RED) → feat(GREEN) → refactor): Task 1 added failing test harness, Task 2 made it pass via lib helpers, Task 3 refactored the consuming script to call the new helpers — each commit atomic, verifiable independently"

requirements-completed: [SAFETY-01, SAFETY-02, SAFETY-03, SAFETY-04]

# Metrics
duration: 5min
completed: 2026-04-18
---

# Phase 3 Plan 03: Settings.json Safe Merge Summary

**Eliminated the SAFETY-02 violation at `setup-security.sh:228-230` (destructive `matcher != 'Bash'` filter that silently overwrote SP/GSD hooks) by introducing an `_tk_owned` marker-based append-both merge, backed by atomic writes and a single-backup-per-run sentinel.**

## Performance

- **Duration:** ~5 min (354s)
- **Started:** 2026-04-18T13:02:41Z (first task: test-safe-merge.sh scaffolding)
- **Completed:** 2026-04-18T13:08:35Z (final commit: setup-security.sh refactor)
- **Tasks:** 3 (test/feat/refactor atomic commits)
- **Files touched:** 4 (1 created, 3 modified)

## Accomplishments

- **Task 1 (RED):** Created `scripts/tests/test-safe-merge.sh` (160 lines) with 3 scenario functions following the test-state.sh pattern. Wired Test 8 into Makefile after Test 7. Test correctly fails RED (`merge_settings_python: command not found`).
- **Task 2 (GREEN):** Added `merge_settings_python` and `merge_plugins_python` to `scripts/lib/install.sh`. Test 8 turns green: 11/11 assertions pass across scenarios 8a/8b/8c.
- **Task 3 (refactor):** Refactored `scripts/setup-security.sh` Steps 3 + 4 to call the new helpers. The destructive `entry.get('matcher') != 'Bash'` filter is **gone**. Fresh-install JSON template carries `_tk_owned: true`. SAFETY-04 INVARIANT comment added to header. Restore-on-failure wired to `$TK_SETTINGS_BACKUP`.
- `make shellcheck && make validate && make test` all exit 0 after every commit.
- **Net LOC change:** setup-security.sh shrank by 70 lines (-126 / +56) because the refactor replaced three duplicated inline python3 heredocs with three `merge_*_python` calls.

## Task Commits

Each task committed atomically with `--no-verify` (parallel-worktree execution):

1. **Task 1: test-safe-merge.sh scaffolding + Makefile entry (RED phase)** — `cf703ad` (test)
2. **Task 2: merge_settings_python + merge_plugins_python in lib/install.sh (GREEN)** — `be36742` (feat)
3. **Task 3: setup-security.sh Step 3/4 refactor to use safe-merge helpers (SAFETY-02 fix)** — `6a8186e` (refactor)

*Note: Plan metadata commit (SUMMARY.md + STATE/ROADMAP updates) is owned by the orchestrator in the worktree-parallel model — not this executor.*

## Files Created/Modified

### Created

- `scripts/tests/test-safe-merge.sh` (163 lines) — scenario-per-function harness mirroring test-state.sh. Sources `scripts/lib/install.sh`, seeds a scratch settings.json with 2 foreign Bash hooks + a foreign enabledPlugins entry + an unrelated user key, then exercises `backup_settings_once` + `merge_settings_python` against the three SAFETY scenarios. Exit 0 on all pass.

### Modified

- `scripts/lib/install.sh` (+102 / -1) — appended two functions AFTER `print_dry_run_grouped`:
  - `merge_settings_python <path> <hook_cmd>` — python3 heredoc. json.load → partition PreToolUse by `_tk_owned` marker → `foreign_entries + [new_tk_entry]` → `tempfile.mkstemp(dir=os.path.dirname(path))` → `os.replace`. On `TK_TEST_INJECT_FAILURE=1` raises RuntimeError BEFORE any file I/O.
  - `merge_plugins_python <path> <plugin_csv>` — same atomic merge for `enabledPlugins`; uses `setdefault('enabledPlugins', {})` so it handles both "add new key" and "merge into existing" paths in a single implementation.
- `scripts/setup-security.sh` (+56 / -126) — four changes:
  1. Header block: SAFETY-04 INVARIANT comment (lines 8-14) documenting the TK-owned subtree contract.
  2. Source lib/install.sh (lines 27-41) — dual-mode: local sibling path for `scripts/setup-security.sh ...` invocations, remote `curl -sSLf` into mktemp for `bash <(curl ...)` invocations. `trap 'rm -f "$LIB_INSTALL_TMP"' EXIT` for cleanup.
  3. Step 3 merge (lines 210-246): `backup_settings_once "$SETTINGS_JSON"` → `if merge_settings_python "$SETTINGS_JSON" "$HOOK_COMMAND"; then success; else cp "$TK_SETTINGS_BACKUP" "$SETTINGS_JSON"; exit 1; fi`. **The destructive `entry.get('matcher') != 'Bash'` filter is GONE.**
  4. Step 3 fresh-install else-branch: inline JSON template now carries `"_tk_owned": true` on the TK hook entry so re-runs correctly identify it.
  5. Step 4 both merge paths (lines 306-341) refactored to call `backup_settings_once` + `merge_plugins_python "$SETTINGS_JSON" "$PLUGIN_CSV"` with the same restore-on-failure wrap. `PLUGINS_JSON` JSON-array shell construction replaced with a simpler CSV via `$(IFS=,; echo "${PLUGINS[*]}")`.
- `Makefile` (+3 / 0) — Test 8 invocation added between Test 7 and the "All tests passed!" footer, with a trailing blank `@echo ""` matching the cadence of Tests 1-7.

## Decisions Made

1. **assert_eq helper in test-safe-merge.sh (not in plan).** The plan's inline `[ "$a" = "$b" ] && report_pass ... || report_fail ...` pattern triggers shellcheck SC2015 ("A && B || C is not if-then-else") at info severity. `make shellcheck` passes because info warnings are below the fail threshold, but for code hygiene the 8 assertion sites were refactored to call a shared `assert_eq LABEL EXPECTED ACTUAL` helper using explicit if/else. Output is identical; shellcheck becomes warning-free.
2. **merge_plugins_python honors TK_TEST_INJECT_FAILURE (plan only required it on merge_settings_python).** Symmetric behavior is easier to reason about and future-proofs the helper for plugin-level failure tests without another lib/install.sh edit.
3. **PLUGINS_JSON → PLUGIN_CSV.** The old Step 4 built a JSON array string `[...]` for `json.loads(sys.argv[2])`. The new `merge_plugins_python` accepts a simple comma-separated string and splits on `,`, which removes one JSON-shell-escape round-trip and matches the plan's function signature `merge_plugins_python <settings_path> <plugin_csv>`.

## Lib helper contracts (post-03-03)

| Function / var | Contract |
|----------------|----------|
| `merge_settings_python <settings_path> <hook_command>` | python3 atomic merge of TK-owned PreToolUse Bash hook. Foreign entries preserved verbatim (partitioned by `_tk_owned` marker absence). TK entry appended at end (append-both / D-39). Atomic write via `tempfile.mkstemp` + `os.replace`. Returns 0 on success. On `TK_TEST_INJECT_FAILURE=1` raises RuntimeError BEFORE any write → returns non-zero; caller restores from `$TK_SETTINGS_BACKUP`. Creates settings.json from scratch with a skeleton if missing. |
| `merge_plugins_python <settings_path> <plugin_csv>` | Additive enabledPlugins merge. Preserves every existing entry; only ADDS missing plugin keys with value `True`. Uses `setdefault('enabledPlugins', {})` so works for both "key missing" and "key present" paths. Same atomic write + TK_TEST_INJECT_FAILURE semantics as merge_settings_python. `plugin_csv` is `"a@scope,b@scope,..."`. |
| `TK_TEST_INJECT_FAILURE` (env var) | When set to `1`, both merge helpers raise RuntimeError before any file I/O. Caller sees non-zero return; settings.json is unchanged. Used by test-safe-merge.sh scenario 8c. |
| `TK_SETTINGS_BACKUP` (global, from 03-01) | Sentinel path to the `.bak.<unix-ts>` backup. Set by first `backup_settings_once` call; empty on first call if no pre-existing settings.json. Both Step 3 and Step 4 of setup-security.sh read it in their restore-on-failure paths. |

## Test 8 scenario proofs

| Scenario | Proves |
|----------|--------|
| **8a: foreign keys preserved** | After `merge_settings_python` against a seeded settings.json with 2 foreign Bash hooks + a foreign enabledPlugins entry + an unrelated user key: `.hooks.PreToolUse` has exactly 3 entries; foreign SP hook at [0]; foreign GSD hook at [1]; TK entry at [2] with `_tk_owned: true`; unrelated user key unchanged; foreign `user-custom@third-party` plugin preserved. **SAFETY-02 fixed.** |
| **8b: backup created before mutation** | After `backup_settings_once` + `merge_settings_python`: `TK_SETTINGS_BACKUP` is set, points to an existing file, MD5 of backup equals MD5 of pre-merge settings.json, and filename matches `.bak.<unix-ts>` pattern. **SAFETY-03 pre-condition satisfied.** |
| **8c: restore on simulated failure** | With `TK_TEST_INJECT_FAILURE=1`: `merge_settings_python` returns non-zero (RuntimeError propagates out of python3 subshell). `cp "$TK_SETTINGS_BACKUP" "$settings"` restores pre-merge content exactly (MD5 match). **SAFETY-03 restore-on-failure verified end-to-end.** |

## Threat Model Recap

All 4 STRIDE threats (T-03-01 … T-03-04) mitigated or accepted with explicit justification in `03-03-PLAN.md`:

| Threat | Category | Mitigation in code |
|--------|----------|---------------------|
| T-03-01 | Tampering (TOCTOU) | Single python3 process holds settings.json from `json.load` through `os.replace`. Backup via `cp` one-shot immediately before python3 invocation. Window bounded by python3 startup (~50ms). |
| T-03-02 | Tampering (backup collision) | **Accepted risk.** `.bak.$(date +%s)` gives 1-second resolution. Concurrent TK installs are blocked by `lib/state.sh` lock (from Phase 2). Phase 4 UPDATE-05 will add PID-aware naming for the routine update path. |
| T-03-03 | DoS (malformed JSON) | `merge_*_python` wraps `json.load` in try/except implicitly (RuntimeError propagates). Backup is taken BEFORE python3 invocation, so on failure the original is preserved. Test 8c verifies this path. |
| T-03-04 | Elevation of Privilege (hook preemption) | Append-both ordering `foreign_entries + [new_tk_entry]` ensures SP/GSD hooks fire FIRST by Claude Code's array-order hook execution semantics. TK cannot preempt foreign security-critical hooks. Test 8a verifies foreign hooks at indexes 0..N-1 with TK at index N. |

## Co-existence verification

Manual visual check (via test-safe-merge.sh scenario 8a, which seeds the exact SP + GSD structure from the dev machine):

- **Input:** settings.json with `/sp/pre-bash.sh` hook at [0], `/gsd/gsd-validate.sh` hook at [1], `code-review@claude-plugins-official: True`, `user-custom@third-party: True`, and `user_setting_unrelated: "leave-me-alone"`.
- **After `merge_settings_python "$settings" "/tk/pre-bash.sh"`:** `.hooks.PreToolUse[0].hooks[0].command == "/sp/pre-bash.sh"`, `.hooks.PreToolUse[1].hooks[0].command == "/gsd/gsd-validate.sh"`, `.hooks.PreToolUse[2]._tk_owned == true`, `.user_setting_unrelated == "leave-me-alone"`, `.enabledPlugins["user-custom@third-party"] == true`.
- **Conclusion:** TK setup on a real SP+GSD machine preserves every foreign hook and every foreign plugin; TK entry is appended, not substituted. The old `setup-security.sh:228-230` behavior (destroying both SP and GSD Bash hooks) is fully eliminated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Broken if/fi structure after initial Step 4 refactor**

- **Found during:** Task 3 sub-step D (Step 4 refactor)
- **Issue:** The first Edit of the "enabledPlugins key missing" else-branch accidentally dropped the inner `fi` for the `[[ -n "${TK_SETTINGS_BACKUP:-}" ]]` test, leaving the `exit 1` statement at the wrong nesting level and causing an `else ... fi` mismatch.
- **Fix:** Re-read the affected lines, issued a second Edit that explicitly fixed the nesting by moving `fi` before `exit 1` and aligning indentation with the parallel Step 3 block.
- **Files modified:** `scripts/setup-security.sh`
- **Verification:** `shellcheck scripts/setup-security.sh` → 0 warnings. `make test` Tests 1-8 all green.
- **Committed in:** `6a8186e` (Task 3 — final structure committed cleanly)

**2. [Rule 2 - Quality] Added assert_eq helper to test-safe-merge.sh**

- **Found during:** Task 1 post-write shellcheck
- **Issue:** Plan-specified pattern `[ "$a" = "$b" ] && report_pass ... || report_fail ...` triggered 8 × SC2015 info warnings. `make shellcheck` still passed (info below threshold), but warning-free output is preferred for code hygiene and matches test-state.sh's explicit if/else style.
- **Fix:** Introduced `assert_eq LABEL EXPECTED ACTUAL` helper. Same observable behavior; cleaner shellcheck output.
- **Files modified:** `scripts/tests/test-safe-merge.sh`
- **Verification:** `shellcheck scripts/tests/test-safe-merge.sh` → 0 warnings. `bash scripts/tests/test-safe-merge.sh` → 11/11 pass.
- **Committed in:** `cf703ad` (Task 1 — the final committed file already uses assert_eq)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 code-quality)
**Impact on plan:** Both auto-fixes preserve plan intent and sharpen the `make check` gate. Behavior observable from tests is identical to the plan's acceptance criteria.

## Issues Encountered

- **Worktree base mismatch at startup.** Worktree was one commit behind the plan's `ACTUAL_BASE`. Safety Net blocks `git reset --hard`, so used `git merge --ff-only a5ddd56...` to fast-forward — no uncommitted work lost.
- **Safety Net blocks `rm -rf` on mktemp paths.** A planned manual-sanity verification using `SCRATCH=$(mktemp -d) ... rm -rf "$SCRATCH"` was blocked by the pre-bash safety net ("rm -rf outside cwd is blocked"). The test harness already exercises the same code paths at higher fidelity, so the manual sanity step was skipped without loss of verification coverage.

## Next Phase Readiness

- **Phase 4 (update-flow) UPDATE-05** can build PID-aware `.bak.<unix-ts>.<pid>` naming on top of the `TK_SETTINGS_BACKUP` sentinel contract established here.
- **Phase 5 (security-hardening)** can extend the `_tk_owned` marker vocabulary to any future TK-managed key in settings.json (e.g., `permissions.deny` entries, TK env block) using the same partition-and-append pattern.
- Any future installer that mutates `~/.claude/settings.json` should `source scripts/lib/install.sh` and call `backup_settings_once` + `merge_*_python` — never open-code a python3 heredoc merge that could reintroduce the SAFETY-02 pattern.

## Self-Check: PASSED

**Created files verified on disk:**

- `scripts/tests/test-safe-merge.sh` — FOUND (163 lines, shellcheck-clean, 11/11 assertions pass)

**Modified files verified on disk:**

- `scripts/lib/install.sh` — FOUND (contains `merge_settings_python()` and `merge_plugins_python()` definitions)
- `scripts/setup-security.sh` — FOUND (SAFETY-04 INVARIANT header present; destructive matcher filter removed; 3× `backup_settings_once` calls)
- `Makefile` — FOUND (Test 8 wired after Test 7)

**Task commits verified in git log:**

- `cf703ad` — FOUND — `test(03-03): add test-safe-merge.sh scaffolding (RED phase)`
- `be36742` — FOUND — `feat(03-03): add merge_settings_python + merge_plugins_python to lib/install.sh`
- `6a8186e` — FOUND — `refactor(03-03): setup-security.sh Step 3/4 use safe-merge helpers (SAFETY-02 fix)`

**Gate verification:**

- `make shellcheck` → exits 0 ✓
- `make validate` → exits 0 ✓
- `make test` → Tests 1-8 all pass ✓
- `bash scripts/tests/test-safe-merge.sh` → 11/11 PASS, exits 0 ✓
- `grep -cE "entry.get..matcher.. ?!= ?.Bash" scripts/setup-security.sh` → 0 ✓ (destructive filter gone)
- `grep -cF "config['hooks']['PreToolUse'] = [" scripts/setup-security.sh` → 0 ✓ (duplicate destructive block gone)
- `grep -c "SAFETY-04 INVARIANT" scripts/setup-security.sh` → 1 ✓
- `grep -c "backup_settings_once" scripts/setup-security.sh` → 4 (3 call sites + 1 doc reference) ✓
- `grep -c "_tk_owned" scripts/setup-security.sh` → 3 (doc + comment + JSON template) ✓

## TDD Gate Compliance

Plan type is `execute` (not `tdd`) but Tasks 1-3 followed the RED → GREEN → REFACTOR cycle implicitly:

1. **RED (`cf703ad` — test):** test-safe-merge.sh added, invocation returns `merge_settings_python: command not found` (expected failure).
2. **GREEN (`be36742` — feat):** merge_settings_python + merge_plugins_python added to lib/install.sh, Test 8 turns green (11/11 pass).
3. **REFACTOR (`6a8186e` — refactor):** setup-security.sh Steps 3+4 refactored to call the new helpers; destructive matcher filter removed; behavior still verified by Test 8.

Commit-type gate sequence (test → feat → refactor) present in git log in correct order.

---

*Phase: 03-install-flow*
*Plan: 03-03*
*Completed: 2026-04-18*
