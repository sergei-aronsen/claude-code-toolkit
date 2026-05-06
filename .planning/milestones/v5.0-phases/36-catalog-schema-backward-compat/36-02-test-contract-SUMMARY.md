---
phase: 36-catalog-schema-backward-compat
plan: 02-test-contract
subsystem: testing
tags: [hermetic-test, bash, python, validator, mcp, scope, backward-compat, makefile]

# Dependency graph
requires:
  - phase: 36-catalog-schema-backward-compat
    plan: 01-foundation
    provides: |
      `default_scope` field on every MCP entry in `integrations-catalog.json`,
      validator Check 11 enum enforcement, and `MCP_DEFAULT_SCOPE[]` parallel array
      with silent jq `// "user"` fallback in `mcp_catalog_load`.
provides:
  - "Three new `_pyq` assertions in `test-integrations-catalog.sh` (A15/A16/A17) that lock SCOPE-01 enforcement on the shipped catalog AND the SCOPE-02 grid spot-checks."
  - "New hermetic Bash test `scripts/tests/test-catalog-scope-fallback.sh` with four scenarios (BC1 D-09/D-11 silent-fallback contract; BC2/BC3/BC4 TEST-06 negative + positive validator cases on synthetic catalogs)."
  - "Makefile `test:` target gains Test 48 entry; new standalone `test-catalog-scope-fallback` target; `.PHONY` declaration extended."
  - "Test-foundation regression fix: S2/S3/S5 fixtures gain `default_scope` so Plan 01's validator extension does not short-circuit deeper assertions."
affects:
  - 37-project-secrets-library
  - 38-wizard-dispatch-integration
  - 39-tui-per-row-scope-toggle
  - 40-uninstall-secret-cleanup-calendly
  - 41-distribution-docs

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hermetic Bash test with synthetic-catalog `mktemp -d` sandboxes + `bash -c \"source mcp.sh; mcp_catalog_load\"` subshell pattern (verbatim mirror of `test-mcp-selector.sh::run_s1_catalog_correctness`)."
    - "Validator path-override seam reuse: `python3 scripts/validate-integrations-catalog.py \"$SANDBOX/synth.json\"` for negative-case TEST-06 scenarios."
    - "Single-quoted `<<'JSON'` heredocs to disable `$VAR` expansion inside synthetic JSON literals."
    - "Stderr-byte-zero assertion via `wc -c < stderr_tmp | tr -d ' '` for the D-11 silent-fallback contract."
    - "Sibling test-file pattern (D-14 discretion) — keeps `test-integrations-catalog.sh` purely-`_pyq`-shaped while gaining a hermetic synthetic-catalog harness in a separate file."

key-files:
  created:
    - "scripts/tests/test-catalog-scope-fallback.sh — 207 lines, 4 scenarios, 9 assertions, executable, Bash 3.2 compatible, hermetic."
  modified:
    - "scripts/tests/test-integrations-catalog.sh — gained 3 `_pyq` blocks (A15/A16/A17) inserted after A14; PASS rises 14 → 17."
    - "Makefile — Test 48 entry in `test:` target body; standalone `test-catalog-scope-fallback` target; `.PHONY` extended."
    - "scripts/tests/test-integrations-foundation.sh — S2/S3/S5 fixtures gain `\"default_scope\": \"user\"` so Plan 01's validator extension does not block S3/S5 from reaching their actual assertion targets."

key-decisions:
  - "Sibling test file `test-catalog-scope-fallback.sh` chosen over extending `test-integrations-catalog.sh` (D-14 discretion). Keeps the Phase 32-era `_pyq`-only style of the existing file intact while gaining the synthetic-catalog harness, and gains a new \"Test 48:\" line in `make test` for discoverability."
  - "Selector baseline canary is PASS=23 (NOT PASS=21 as the plan literal says). Plan 01 SUMMARY documented this 2-assertion drift accumulated in earlier work; the deviation_handling block in Plan 02's prompt locks it as the canary value."
  - "Auto-fix of test-integrations-foundation S2/S3/S5 fixtures (Rule 1 deviation) — Plan 01's validator extension introduced a regression that surfaced only at the `make test` chain layer; Plan 02's success criteria explicitly demands `make test` exit 0, making the fix in-scope."

patterns-established:
  - "Single-commit landing of test contract for a foundation phase — three test-only commits (A15-A17 meta-tests, sibling synthetic-catalog harness, Makefile wiring) preserve atomicity per task while keeping each commit reviewable in isolation."
  - "Re-source of `mcp.sh` per scenario via `bash -c \"source ...; ...\"` to clear `MCP_*` global state between scenarios (Bash 3.2 has no easy in-process array reset; matches `test-mcp-selector.sh:113-117` precedent)."
  - "Stderr-byte-zero contract assertion via `wc -c | tr -d ' '` — POSIX-portable across BSD/GNU `wc` differences; locks the D-11 silent-fallback semantic that Phase 38/39 will rely on."

requirements-completed:
  - SCOPE-03
  - TEST-06

# Metrics
duration: ~25 min
completed: 2026-05-04
---

# Phase 36 Plan 02: Test Contract Summary

**Plan 01's catalog + validator + loader contract is now regression-locked behind 3 new `_pyq` meta-tests, a hermetic 4-scenario synthetic-catalog harness, and a wired Makefile Test 48 — all v4.9 baselines preserved (selector PASS=23, integrations-catalog PASS=17, fallback PASS=9), `make check && make test` green end-to-end.**

## Performance

- **Duration:** ~25 min (4 sequential tasks + 1 deviation auto-fix + verification)
- **Started:** 2026-05-04T18:43:00Z
- **Completed:** 2026-05-04T19:08:00Z (approx)
- **Tasks:** 4 (Task 4 is verification-only)
- **Files modified:** 3 + 1 created

## Accomplishments

- **A15/A16/A17 _pyq assertions added to `test-integrations-catalog.sh`** — A15 walks every entry in `components.mcp.*` and asserts `default_scope ∈ {"user","project"}`; A16 spot-checks `aws-cloudwatch-logs.default_scope == "project"` (D-07 grid); A17 spot-checks `context7.default_scope == "user"` (D-06 grid). All three follow the existing `_pyq` `OK`-stdout contract verbatim. PASS rises 14 → 17, FAIL=0, D-12 floor of ≥10 preserved.
- **`scripts/tests/test-catalog-scope-fallback.sh` shipped** — 207-line hermetic Bash test, executable (`-rwxr-xr-x`), shellcheck-clean at warning severity, Bash 3.2 compatible (no `mapfile`, `declare -A`, `${var,,}`, `read -N`/`read -t` floats, or `declare -n`). Four scenarios:
  - **BC1** (silent-fallback contract): synthetic catalog with `withscope` (default_scope=project) + `noscope` (no field). Loader returns 0; missing → "user"; present → "project" verbatim; captured stderr is **zero bytes** (D-11 silent contract).
  - **BC2** (validator rejects missing field): synthetic catalog where every MCP omits `default_scope`. Validator exits non-zero; stderr mentions `default_scope`.
  - **BC3** (validator accepts valid enum): synthetic catalog with both `user` and `project` values. Validator exits 0.
  - **BC4** (validator rejects invalid enum): synthetic catalog with `default_scope: "global"`. Validator exits non-zero; stderr mentions `default_scope`.
  - Result: PASS=9 FAIL=0 (≥7 floor satisfied; 4 BC1 + 2 BC2 + 1 BC3 + 2 BC4).
- **Makefile wiring** — three surgical insertions:
  1. `test:` target body gains `@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"` + `@bash scripts/tests/test-catalog-scope-fallback.sh`, inserted between Test 47 and the trailing "All tests passed!" echo.
  2. New standalone target `test-catalog-scope-fallback:` added immediately after `test-integrations-tui` (mirrors the per-test standalone pattern at lines 226-260).
  3. `.PHONY` declaration extended with `test-catalog-scope-fallback`.
  Verified: `make -n test` parses (Test 48 appears in dry-run output between Test 47 and "All tests passed!"); `make -n test-catalog-scope-fallback` parses; `check:` body byte-identical (D-05 — Plan 02 wires `test:`, not `check:`).
- **Test-foundation fixture regression fix** (Rule 1 deviation) — see Deviations section below.
- **`make check && make test` exit 0 end-to-end** — all 48 numbered tests + 12 quality-gate sub-targets green. v4.9 baselines preserved (`test-mcp-selector.sh` PASS=23 unchanged, `test-integrations-catalog.sh` PASS=17 = 14+3, `test-catalog-scope-fallback.sh` PASS=9 ≥ 7 floor).

## Task Commits

Each task was committed atomically (Conventional Commits with `(36-02)` scope):

1. **Task 1: A15/A16/A17 _pyq assertions** — `5fddef7` (test)
2. **Task 2: test-catalog-scope-fallback.sh sibling test** — `2768c92` (test)
3. **Task 3: Makefile Test 48 + standalone target + .PHONY** — `bf14fc2` (build)
4. **Task 4 (deviation): test-integrations-foundation fixture fix** — `fd16c65` (fix)

Task 4 itself is verification-only (no edits); the auto-fix of S2/S3/S5 fixtures was committed separately as a Rule 1 deviation surfaced by Task 4's `make test` gate.

## Files Created/Modified

### Created

- `scripts/tests/test-catalog-scope-fallback.sh` — 207 lines (`grep -c JSON` returns 4; `grep -c '<<'\''JSON'\'''` returns 4; `grep -c '^run_bc' returns 4`; `grep -n 'set -euo pipefail'` returns line 20). Executable mode `-rwxr-xr-x`. Reuses `assert_pass`/`assert_fail`/`assert_eq` boilerplate verbatim from `test-integrations-catalog.sh:33-42`. Each scenario gets its own `mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX` sandbox cleaned up by a `trap "rm -rf '${SANDBOX:?}'" RETURN`. BC1 uses the `TK_MCP_CATALOG_PATH` test seam (mcp.sh:33) + `bash -c "source ...; mcp_catalog_load; ..."` subshell pattern (mirrors `test-mcp-selector.sh:113-117` verbatim). BC2/BC3/BC4 use the validator's `sys.argv[1]` path-override seam (validate-integrations-catalog.py:89).

### Modified

- `scripts/tests/test-integrations-catalog.sh` — 3 new `_pyq` blocks inserted between A14 (line 256-272) and the trailing `echo "Result: PASS=$PASS FAIL=$FAIL"` (now line 314). Each block follows the existing `# ───…───` separator + `_pyq "label" 'python_script'` shape verbatim. `grep -c 'A1[5-7]:'` returns 3, all located after the A14 line. The `_pyq` helper (lines 67-86), boilerplate (lines 23-42), and exit pattern (lines 313-315) are byte-unchanged. Final stdout: `Result: PASS=17 FAIL=0`.
- `Makefile` — three insertions described above. Recipe lines use literal TAB indent (verified with `sed -n '224p' Makefile | od -c` showing `\t @ e c h o`). Test-recipe ordering: Test 47 → Test 48 → "All tests passed!" (verified via `make -n test | tail -10`). `grep -c 'test-catalog-scope-fallback.sh' Makefile` returns 2 (one in `test:` recipe, one in standalone target body). `.PHONY` line extended; no second `.PHONY` line introduced.
- `scripts/tests/test-integrations-foundation.sh` — three negative-case fixtures (S2 broken/missing-display_name, S3 evil/bad-category, S5 lowercase_env/bad-env-var-key) gain `"default_scope": "user"` as the LAST key (after `requires_oauth`). Surgical: only the three negative fixtures touched; S4 (missing components, no MCP entries to walk) and the S1 positive case (uses the shipped catalog) untouched. Result: PASS rises 30 → 32, FAIL=0.

## Decisions Made

- **D-14 sibling test file** — chose `test-catalog-scope-fallback.sh` over extending `test-integrations-catalog.sh`. Rationale: the existing file is purely-`_pyq`-shaped (every assertion runs inline Python against the SHIPPED catalog); the fallback test needs a synthetic-catalog harness with `mktemp -d`, `bash -c "source mcp.sh; ..."`, and stderr capture — a different idiom that mixes poorly with `_pyq`. Sibling file matches `test-mcp-selector.sh::run_s1_catalog_correctness` (lines 64-86) verbatim and earns its own `Test 48:` line in `make test` output for discoverability. PATTERNS.md called this match-quality "exact (synthetic-catalog harness pattern)".
- **Two-layer SCOPE-01 enforcement** — TEST-06 satisfied at three layers per RESEARCH.md §"Open Questions (RESOLVED) #2":
  1. Validator runtime check (Plan 01's Check 11 — exit non-zero on missing/invalid).
  2. Meta-test on the SHIPPED catalog (`_pyq` A15 in `test-integrations-catalog.sh` — lock the catalog data layer).
  3. Hermetic synthetic-catalog tests on the validator's path-override seam (BC2/BC3/BC4 in `test-catalog-scope-fallback.sh` — lock the validator behavior on synthetic inputs).
- **No CHANGELOG / manifest mutation** (D-08) — confirmed `manifest.json` stays at `4.9.0` and `CHANGELOG.md` top entry stays at `[Unreleased]`. Phase 41 owns the consolidated `[5.0.0]` release entry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] test-integrations-foundation.sh fixtures broken by Plan 01's validator extension**

- **Found during:** Task 4 (verification gate — `make test` failed with `Result: PASS=30 FAIL=2` from Test 44).
- **Issue:** Plan 01's validator extension appended `default_scope` to the `REQUIRED_ENTRY_KEYS` tuple. The existing Phase 32-era negative fixtures in `test-integrations-foundation.sh` omit the field. The validator now fires Check 4 (missing-keys check) FIRST and short-circuits before reaching:
  - **S3** (`assert_contains "frobnicate"`) — expected stderr to name the offending invalid category, but stderr now reads `missing required keys: default_scope` instead.
  - **S5** (`assert_contains "env_var_keys"`) — expected stderr to name the offending lowercase env_var_key field, but stderr now reads the same default_scope-missing line.
  - **S2** (`assert_contains "display_name"`) was passing accidentally because BOTH `display_name` and `default_scope` were missing, so the error message listed both names; the assertion still matched.
- **Fix:** Added `"default_scope": "user"` as the LAST key in three fixtures (S2 broken, S3 evil, S5 lowercase_env) so the validator gets past Check 4 and surfaces the deeper assertion targets. S4 (missing components, no MCP entries to walk) was untouched.
- **Files modified:** `scripts/tests/test-integrations-foundation.sh` (3 fixtures, 6 insertions / 3 deletions for trailing-comma adjustments).
- **Verification:**
  - Per-fixture: rerun `bash scripts/tests/test-integrations-foundation.sh` → `Result: PASS=32 FAIL=0` (was 30/2; +2 unblocked).
  - Chain: rerun `make test` → exit 0 across all 48 tests (Test 44 now green).
- **Committed in:** `fd16c65` (separate fix commit, distinct from Tasks 1-3).
- **Scope-boundary check:** YES, in scope. Task 4's verify block hard-codes `make test` exit 0 as an acceptance criterion, and the failure was directly caused by the current phase's changes (Plan 01's validator extension). Per executor `<deviation_rules>` §SCOPE BOUNDARY: "Only auto-fix issues DIRECTLY caused by the current task's changes" — this regression is directly attributable to Phase 36 work.

**2. [Documentation drift, no code impact] Selector baseline number in plan literal**

- **Found during:** Task 1 / Task 4.
- **Issue:** Plan literal says `test-mcp-selector.sh PASS=21` in multiple places (objective, must-haves, success criteria). Actual baseline at execution start was PASS=23 (drift from earlier work that pre-dates Phase 36).
- **Fix:** None needed — plan prompt's `<deviation_handling>` block explicitly noted this drift and locked PASS=23 as the D-12 canary contract: "verify it is still 23 after your changes."
- **Verification:** `bash scripts/tests/test-mcp-selector.sh` → `Result: PASS=23 FAIL=0` (unchanged across all four task commits).
- **Committed in:** N/A (no code change).

---

**Total deviations:** 1 auto-fixed (Rule 1 bug), 1 documentation drift (no code impact).
**Impact on plan:** Auto-fix was strictly necessary to satisfy Task 4's `make test` exit-0 gate. No scope creep — the foundation-fixture fix is mechanical (gain a single key per fixture) and surgical (only the three negative fixtures touched).

## Issues Encountered

- **PreToolUse Read-before-Edit reminders** fired on every `Edit` despite the file being read earlier in the session. Hooks are advisory; runtime accepted all edits. Plan 01 SUMMARY noted the same harmless pattern.
- **macOS `cat -A` not available** (BSD `cat` lacks `-A`). The plan's TAB-verification command (`cat -A Makefile | grep ...`) failed with "illegal option -- A"; substituted with `od -c` against the same line range, which confirmed `\t @ e c h o` (TAB-prefixed recipe lines, as required by Make).
- **Safety-net blocked `git checkout <ref> -- <path>`** during deviation diagnosis — used `mktemp -d` + inline JSON heredoc to reproduce the failure mode without mutating working tree, which was sufficient.
- **Safety-net blocked `rm -rf $SANDBOX`** even with `${SANDBOX:?}` guard — left the diag dir for OS-level cleanup of `/tmp` (not a leak in CI; mktemp dirs auto-cleaned by `trap RETURN` inside the actual test scenarios).

## TDD Gate Compliance

Tasks 1 and 2 in the plan are tagged `tdd="true"`, but the project config has `workflow.tdd_mode: false` (`.planning/config.json`) and the plan itself acts as the **test contract** — there is no separate "implementation" phase to follow with `feat(...)` after a `test(...)` RED gate, because the implementation already shipped in Plan 01. So both Task 1 and Task 2 were committed as `test(36-02): ...` and represent the RED-locking-the-already-GREEN-feature pattern.

The git history for Phase 36 shows the standard plan-level TDD gate sequence:

- Plan 01 commits: `feat(36-01): seed default_scope...` + `feat(36-01): enforce default_scope...` + `feat(36-01): add MCP_DEFAULT_SCOPE[]...` (3 GREEN commits).
- Plan 02 commits: `test(36-02): lock SCOPE-01 + SCOPE-02 grid...` + `test(36-02): add test-catalog-scope-fallback.sh...` + `build(36-02): wire test-catalog-scope-fallback.sh into Makefile...` + `fix(36-02): add default_scope to test-integrations-foundation fixtures` (3 RED-lock commits + 1 fix commit).

REFACTOR phase: not applicable (test files don't refactor — they accumulate).

## User Setup Required

None — no external service configuration required. Plan 02 is repo-internal: test code, hermetic sandboxes in /tmp, no auth, no secrets, no network, no file uploads.

## Next Phase Readiness

- **Phase 37 (project-secrets library):** Ready. The `default_scope` semantics are now contract-locked at three layers (catalog data, validator, loader fallback), so Phase 37's `project-secrets.sh` can rely on `MCP_DEFAULT_SCOPE[$idx] == "project"` as the routing key without worrying about pre-v5.0 catalog regressions.
- **Phase 38 (wizard dispatch):** Ready. Reads `MCP_DEFAULT_SCOPE[]`. Loader contract (D-09 silent fallback) and validator contract (Check 11 enum enforcement) are both regression-locked.
- **Phase 39 (TUI per-row scope toggle):** Ready. Initializes `MCP_SELECTED_SCOPE[]` from `MCP_DEFAULT_SCOPE[]`. Same as 38: zero loader changes needed.
- **Phase 40 (Calendly + uninstall + validator SCOPE-01 assertion):** Ready. When the Calendly entry lands, validator Check 11 + the new `_pyq` A15 will both enforce `default_scope` on it automatically.
- **Phase 41 (close):** Ready. Plan 02 made zero `manifest.json` / `CHANGELOG.md` edits (D-08 — version bump deferred to Phase 41 to keep `version-align` Makefile gate green).

No blockers. No concerns.

## Self-Check

- ✅ `scripts/tests/test-catalog-scope-fallback.sh` exists and is executable (`-rwxr-xr-x`), 207 lines. `grep -c '<<'\''JSON'\'''` → 4; `grep -c 'mktemp -d /tmp/test-catalog-scope-fallback'` → 4; `grep -c 'TK_MCP_CATALOG_PATH='` → 1 (BC1 only).
- ✅ `scripts/tests/test-integrations-catalog.sh` modified — `grep -c 'A15:'` → 1; `grep -c 'A16:'` → 1; `grep -c 'A17:'` → 1; final stdout `Result: PASS=17 FAIL=0`.
- ✅ `Makefile` modified — `grep -c 'Test 48: catalog default_scope fallback' Makefile` → 1; `grep -c 'test-catalog-scope-fallback.sh' Makefile` → 2; `grep -E '^\.PHONY:.*test-catalog-scope-fallback' Makefile` matches.
- ✅ `scripts/tests/test-integrations-foundation.sh` modified — `grep -c '"default_scope":' scripts/tests/test-integrations-foundation.sh` → 3 (S2/S3/S5 fixtures only).
- ✅ Commit `5fddef7` exists (`test(36-02): lock SCOPE-01 + SCOPE-02 grid in test-integrations-catalog.sh`).
- ✅ Commit `2768c92` exists (`test(36-02): add test-catalog-scope-fallback.sh — D-09/D-11/TEST-06 contract`).
- ✅ Commit `bf14fc2` exists (`build(36-02): wire test-catalog-scope-fallback.sh into Makefile (Test 48)`).
- ✅ Commit `fd16c65` exists (`fix(36-02): add default_scope to test-integrations-foundation fixtures`).
- ✅ `bash scripts/tests/test-mcp-selector.sh` → `Result: PASS=23 FAIL=0` UNCHANGED from pre-Phase-36 baseline (D-12 canary).
- ✅ `bash scripts/tests/test-integrations-catalog.sh` → `Result: PASS=17 FAIL=0` (was 14, gained A15+A16+A17 = +3).
- ✅ `bash scripts/tests/test-catalog-scope-fallback.sh` → `Result: PASS=9 FAIL=0` (≥ 7 floor satisfied).
- ✅ `python3 scripts/validate-integrations-catalog.py` exits 0 on shipped catalog.
- ✅ `make check` exits 0 end-to-end.
- ✅ `make test` exits 0 end-to-end across all 48 numbered tests including Test 48.
- ✅ `make -n test-catalog-scope-fallback` parses (standalone target works).
- ✅ `manifest.json` `"version"` field = `4.9.0` UNCHANGED (D-08 — Phase 41 owns the bump).
- ✅ `CHANGELOG.md` top entry = `[Unreleased]` UNCHANGED (D-08).
- ✅ `bash -n scripts/tests/test-catalog-scope-fallback.sh` exits 0 (no syntax error).
- ✅ `shellcheck -S warning scripts/tests/test-catalog-scope-fallback.sh` exits 0 (no warnings).

## Self-Check: PASSED

---
*Phase: 36-catalog-schema-backward-compat*
*Plan: 02-test-contract*
*Completed: 2026-05-04*
