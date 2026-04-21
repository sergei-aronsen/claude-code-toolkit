---
phase: 05-migration
plan: 01
subsystem: migration
tags: [state-schema, manifest, sp_equivalent, d-71, d-75, d-76, d-77, update-claude, write_state]

# Dependency graph
requires:
  - phase: 02-foundation
    provides: scripts/lib/state.sh (write_state base signature), scripts/lib/install.sh (recommend_mode, compute_skip_set)
  - phase: 04-update-flow
    provides: scripts/update-claude.sh (synthesize_v3_state, state-load block, end-of-run write_state)
provides:
  - "state schema v2 with synthesized_from_filesystem boolean (D-75)"
  - "manifest.json sp_equivalent field populated on 6 of 7 SP duplicates (D-71 escape hatch)"
  - "update-claude.sh D-77 migrate hint (standalone + SP/GSD + duplicate on disk)"
  - "update-claude.sh synthesize_v3_state records synth_flag=true (D-50 retrofit)"
affects: [05-02-migrate-core, 05-03-state-rewrite]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "8-positional-arg write_state with backwards-compat default"
    - "Triple-AND read-only probe (no state mutation) for D-77 hint"
    - "JSON top-level explanatory note key (sp_equivalent_note) for field semantics"
    - "Pre-flight jq -e fixture assertion guarding scenario drift"

key-files:
  created:
    - ".planning/phases/05-migration/05-01-SUMMARY.md"
    - ".planning/phases/05-migration/deferred-items.md"
  modified:
    - "scripts/lib/state.sh"
    - "scripts/update-claude.sh"
    - "manifest.json"
    - "scripts/tests/test-update-drift.sh"

key-decisions:
  - "D-75: state schema v2 adds synthesized_from_filesystem boolean — backwards-compat via jq // false default"
  - "D-71: 6 of 7 SP duplicates carry sp_equivalent; agents/code-reviewer.md uses same-basename fallback"
  - "D-77: migrate hint is a read-only probe (no state mutation, no exit) — emitted only when triple-AND holds"
  - "Task 3 Scenario 7 uses TK_UPDATE_FILE_SRC=EMPTY_SRC to prevent seed-step downloads contaminating the no-duplicates-on-disk precondition"

patterns-established:
  - "write_state contract evolution: add positional arg with ${N:-default} fallback + version bump + new field between existing fields"
  - "Read-only probe pattern: underscore-prefixed locals, unset cleanup, no state mutation"
  - "Fixture pre-flight assertion: jq -e inside test scenario fails loudly on fixture drift"

requirements-completed: []

# Metrics
duration: 9min
completed: 2026-04-18
---

# Phase 5 Plan 01: Migration Foundation Summary

**State schema v2 with synthesized_from_filesystem, manifest sp_equivalent field on 6 SP duplicates, and D-77 migrate hint emitted after state load — all three foundations land atomically so plans 05-02 and 05-03 consume a stable contract.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-18T21:46:06Z
- **Completed:** 2026-04-18T21:54:41Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- `scripts/lib/state.sh` bumped to schema v2: write_state accepts 8th positional arg `synth_flag` (default false), Python heredoc unpacks `sys.argv[1:10]`, serialized state contains `"version": 2` and `"synthesized_from_filesystem": <bool>`. Backwards compat preserved — 7-arg legacy callers default to false, v1 readers use `jq // false`.
- `scripts/update-claude.sh::synthesize_v3_state` now passes `"true"` as 8th positional arg to `write_state`, marking the state file as filesystem-synthesized for D-73 two-signal user-mod detection in 05-02. End-of-run `write_state` at line 752 unchanged (post-dispatch persist, not synthesis).
- `scripts/update-claude.sh` D-77 hint block inserted after state-load/detect: triple-AND probe (state.mode=standalone + any base plugin present + manifest-skip-set ∩ disk non-empty) emits a single-line CYAN hint pointing at `./scripts/migrate-to-complement.sh`. No state mutation, no exit, no hint otherwise.
- `manifest.json` extended with `sp_equivalent` field on 6 of 7 SP duplicates per RESEARCH §D-71 verbatim mapping. `agents/code-reviewer.md` remains unchanged (same-basename fallback per D-71 row 6). Top-level `sp_equivalent_note` documents field semantics.
- `scripts/tests/test-update-drift.sh` extended with Scenario 6 (D-77 hint fires) and Scenario 7 (D-77 hint suppressed when no duplicates on disk). Scenario 6 carries a `jq -e` pre-flight assertion guarding fixture drift. Test suite now 17 scenarios, all green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend `scripts/lib/state.sh` with write_state v2 schema (D-75)** - `7aa397d` (feat)
2. **Task 2: Retrofit `scripts/update-claude.sh` — D-50 synth flag + D-77 hint** - `b1f7b81` (feat)
3. **Task 3: manifest.json sp_equivalent + Test 9 hint scenarios** - `b484015` (feat)

_Note: Plan is TDD-style but each task is a single-commit feat (RED/GREEN collapsed: verify block defines failing assertions, implementation makes them pass — confirmed by pre-edit RED check on each file before editing)._

## Files Created/Modified

- `scripts/lib/state.sh` - write_state signature +1 arg (synth_flag), version 1→2, serialized `synthesized_from_filesystem` field
- `scripts/update-claude.sh` - synthesize_v3_state call adds `"true"` 8th arg; +17 lines for D-77 hint block after state-load
- `manifest.json` - +6 sp_equivalent fields verbatim per RESEARCH §D-71; +1 sp_equivalent_note top-level key
- `scripts/tests/test-update-drift.sh` - +2 scenarios (hint emits/suppressed) invoked after existing 5 scenarios; pre-flight jq fixture assertion in Scenario 6; TK_UPDATE_FILE_SRC empty-src pattern in Scenario 7
- `.planning/phases/05-migration/deferred-items.md` - pre-existing markdownlint errors outside plan scope

## Decisions Made

- **Test design fix for Scenario 7 (TK_UPDATE_FILE_SRC pattern):** The initial plan version of Scenario 7 did not prevent the seed-step download loop. On a fresh `$SCR/.claude/` with default `TK_UPDATE_FILE_SRC`, update-claude.sh downloads every manifest path (including SP duplicates). That contaminated the "no duplicates on disk" precondition for Scenario 7. Mirrored Scenario 1's pattern: `EMPTY_SRC="$SCR/.empty-src"; mkdir -p "$EMPTY_SRC"; TK_UPDATE_FILE_SRC="$EMPTY_SRC"` on both the seed run and the assertion run. This is test-scaffolding, not a behavior change — the production code (update-claude.sh hint block) is exactly per plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test harness bug] Scenario 7 missing TK_UPDATE_FILE_SRC empty-src guard**

- **Found during:** Task 3 (end-to-end test run)
- **Issue:** Plan-specified Scenario 7 seed step caused update-claude.sh to download every manifest path into `$SCR/.claude/`, including the SP duplicates `commands/{debug,plan,tdd,verify,worktree}.md`. When the scenario ran its "no duplicates on disk" assertion phase with `HAS_SP=true`, the D-77 hint correctly fired (duplicates were on disk — scenario-setup bug, not hint bug). Without the fix, Scenario 7 always fails.
- **Fix:** Mirrored Scenario 1's pattern — added `local EMPTY_SRC="$SCR/.empty-src"; mkdir -p "$EMPTY_SRC"` and passed `TK_UPDATE_FILE_SRC="$EMPTY_SRC"` on both seed and assertion runs.
- **Files modified:** `scripts/tests/test-update-drift.sh` (Scenario 7 only)
- **Verification:** `bash scripts/tests/test-update-drift.sh` → 17/17 pass; Scenario 7 correctly asserts hint suppressed.
- **Committed in:** `b484015` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — test harness scenario-setup bug)
**Impact on plan:** Pure test-scaffolding fix. Production D-77 hint block in `update-claude.sh` is exactly per plan. The test now meaningfully asserts the suppression behavior (scenario succeeds iff the filesystem intersection probe logic is correct).

## Issues Encountered

- Initial `make test` log truncation (cc-safety-net) — worked around by running `bash scripts/tests/{test-update-drift,test-update-diff,test-update-summary}.sh` individually to confirm Tests 9/10/11 green. `make test` exit code was 0, confirming all 11 test groups passed.

## Deferred Issues

Pre-existing markdownlint errors in files outside plan scope (logged in `.planning/phases/05-migration/deferred-items.md`):

- `CLAUDE.md:471,486` (MD022, MD032)
- `components/orchestration-pattern.md:211,214,221,224,225,229,230,231` (MD031, MD029, MD032, MD040)

Verified at base commit `0ab7fd5` — NOT introduced by Plan 05-01. Per SCOPE BOUNDARY rule, these are out-of-scope and tracked for future cleanup.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Ready for 05-02 (migrate core):** `sp_equivalent` is queryable via:
  ```bash
  jq -r --arg p "$rel" '.files | to_entries[] | .value[] | select(.path == $p) | .sp_equivalent // ""' manifest.json
  ```
  Empty string = same-basename fallback (agents/code-reviewer.md path).
- **Ready for 05-03 (state rewrite + idempotence):** `write_state` accepts 8 positional args. Migrate core (05-02) invokes it with the new mode + empty synth_flag (or `"true"` if migration itself synthesizes state from filesystem).
- **Hint surface in place:** 05-02's `migrate-to-complement.sh` has a documented entry point via the D-77 hint. Users upgrading from v3.x → v4.x will discover the migrate script through update-claude.sh output.

## Threat Flags

No new security surface introduced. All changes are local state serialization + CLI text output. Existing `validate-manifest.py` `ALLOWED_CONFLICTS` pinning covers the new `sp_equivalent` field indirectly (values are committed + PR-reviewed; no user input reaches this path in 05-01 scope).

## Self-Check: PASSED

- `[x]` `scripts/lib/state.sh` contains `synth_flag="${8:-false}"` — FOUND
- `[x]` `scripts/lib/state.sh` contains `sys.argv[1:10]` — FOUND
- `[x]` `scripts/lib/state.sh` contains `"version": 2,` — FOUND
- `[x]` `scripts/lib/state.sh` contains `synthesized_from_filesystem` — FOUND
- `[x]` `scripts/update-claude.sh` contains `D-77 migrate hint` — FOUND
- `[x]` `scripts/update-claude.sh` contains `Legacy duplicates detected` — FOUND
- `[x]` `manifest.json` has 6 `sp_equivalent` entries (jq verified) — FOUND
- `[x]` `manifest.json` has no sp_equivalent on `agents/code-reviewer.md` — VERIFIED
- `[x]` Commit `7aa397d` — FOUND in git log
- `[x]` Commit `b1f7b81` — FOUND in git log
- `[x]` Commit `b484015` — FOUND in git log
- `[x]` `bash scripts/tests/test-update-drift.sh` — 17/17 passed
- `[x]` `bash scripts/tests/test-update-diff.sh` — 13/13 passed
- `[x]` `bash scripts/tests/test-update-summary.sh` — 17/17 passed
- `[x]` `make validate` — passed
- `[x]` `make test` — exit 0 (all 11 groups green)
- `[x]` `shellcheck --severity=warning` — clean on all 3 modified scripts

---
*Phase: 05-migration*
*Completed: 2026-04-18*
