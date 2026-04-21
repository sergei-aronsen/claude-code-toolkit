---
phase: 03-install-flow
plan: "01"
subsystem: infra
tags: [shell-library, plugin-detection, install-flow, sourced-lib, manifest-v2]

# Dependency graph
requires:
  - phase: 02-foundation
    provides: detect.sh (HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION exports); lib/state.sh sourced-library invariants; manifest.json v2 schema with conflicts_with vocabulary
provides:
  - scripts/lib/install.sh sourced library exporting MODES, recommend_mode, compute_skip_set, backup_settings_once, print_dry_run_grouped (stub)
  - detect.sh + lib/install.sh wiring in init-claude.sh (remote mktemp+curl+trap pattern) before any filesystem write
  - detect.sh + lib/install.sh wiring in init-local.sh (SCRIPT_DIR-relative source) before any filesystem write
  - detect.sh wiring in update-claude.sh (soft-fail fallback; variables exposed for Phase 4 consumption)
  - manifest_version guard in both init scripts (hard-fail on manifest_version != 2)
affects: [03-02 (mode selection, --mode flag, jq skip-list filter, grouped dry-run), 03-03 (settings.json safe merge), 04-update-flow (UPDATE-01 branches on HAS_SP/HAS_GSD)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sourced-library invariant mirrors scripts/lib/state.sh: NO set -euo pipefail, zero stdout on source, diagnostics to stderr"
    - "Remote sourcing pattern: mktemp + trap-before-curl + curl -sSLf + source (init-claude.sh, update-claude.sh)"
    - "Local sourcing pattern: source \"$SCRIPT_DIR/detect.sh\" / source \"$SCRIPT_DIR/lib/install.sh\" (init-local.sh)"
    - "Hard-fail vs soft-fail asymmetry: install scripts hard-fail on detect.sh download failure; update script soft-fails (transient network tolerance)"
    - "Manifest version guard: jq -r '.manifest_version' + explicit equality check against literal '2'"

key-files:
  created:
    - scripts/lib/install.sh
  modified:
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/update-claude.sh

key-decisions:
  - "Option A for Task 4 — scripts/lib/install.sh NOT added to manifest.json. validate-manifest.py Check 6 only scans commands/ and templates/base/skills/, not scripts/. Manifest tracks user-installed files; internal toolkit infrastructure is repo-internal."
  - "shellcheck SC2034 disables on forward-referenced variables (MANIFEST_FILE in init-claude.sh, HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION fallbacks in update-claude.sh) — consumed by downstream Plan 03-02 / Phase 4."
  - "Omitted plan's inline redundant `log_warning() { ... }` definition from update-claude.sh soft-fail branch — real definition lives at line 49 and the else-branch uses `echo -e` directly, not log_warning."

patterns-established:
  - "Sourced-library skeleton pattern: NO errexit/pipefail, zero stdout on source, forward-ref functions silenced via # shellcheck disable=SC2034"
  - "Remote-vs-local dual sourcing: same detect.sh / lib/install.sh consumed by both curl|bash (mktemp+trap) and local clone (SCRIPT_DIR) install paths"
  - "Consolidated trap pattern: when adding a second/third temp file to an install script, re-register trap with all current temp files in a single `trap '...' EXIT` call"

requirements-completed: [DETECT-05]

# Metrics
duration: 14min
completed: 2026-04-18
---

# Phase 3 Plan 01: Install-Flow Foundation Summary

**Shared install library (scripts/lib/install.sh) with 4-mode skip-set helper plus detect.sh wiring across all three install/update scripts — Phase 3 plumbing without user-visible behavior change.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-04-18T12:28 UTC (first task: lib/install.sh)
- **Completed:** 2026-04-18T12:42 UTC
- **Tasks:** 4 (Task 4 was a no-op per Option A decision)
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `scripts/lib/install.sh` created as a sourced library with the full skeleton that Plans 03-02 and 03-03 will fill in:
  - `MODES` array (4 entries in prompt order)
  - `recommend_mode()` pure function over `$HAS_SP` / `$HAS_GSD`
  - `compute_skip_set()` backed by a single jq filter over `manifest.json` — verified 7 SP conflicts, 0 standalone, 0 GSD-only, 7 full-complement against the current manifest
  - `backup_settings_once()` idempotent one-shot `.bak.<unix-ts>` backup (verified: nonexistent path → no-op; repeated calls → single backup)
  - `print_dry_run_grouped()` stub (full implementation lands in Plan 03-02)
- `scripts/init-claude.sh` sources `detect.sh` + `lib/install.sh` via remote mktemp+curl+trap pattern, fetches `manifest.json` to `$MANIFEST_FILE`, and hard-fails on `manifest_version != 2` — all before any filesystem write
- `scripts/init-local.sh` sources `detect.sh` + `lib/install.sh` via `$SCRIPT_DIR` and hard-fails on `manifest_version != 2` before any filesystem write
- `scripts/update-claude.sh` sources `detect.sh` via remote mktemp+trap pattern with soft-fail fallback (`HAS_SP=false / HAS_GSD=false / SP_VERSION="" / GSD_VERSION=""`) — exposes variables for Phase 4 consumption without adding any branching in Phase 3
- `make shellcheck && make validate && make test` all exit 0 after changes

## Task Commits

Each task was committed atomically with `--no-verify` (parallel-worktree execution):

1. **Task 1: Create scripts/lib/install.sh skeleton (sourced library)** — `de6a505` (feat)
2. **Task 2: Source detect.sh + lib/install.sh in init-claude.sh and init-local.sh, add manifest_version guard** — `ae59c4b` (feat)
3. **Task 3: Source detect.sh in update-claude.sh (variable exposure only)** — `007892c` (feat)
4. **Task 4: Add scripts/lib/install.sh to manifest.json** — **no commit (Option A no-op; see Decisions Made)**

_Note: Plan metadata commit (SUMMARY.md + STATE/ROADMAP updates) is owned by the orchestrator in the worktree-parallel model — not this executor._

## Files Created/Modified

### Created

- `scripts/lib/install.sh` (75 lines) — shared install helpers: MODES array, `recommend_mode`, `compute_skip_set` (jq over manifest.json), `backup_settings_once` (idempotent), `print_dry_run_grouped` (stub). Sourced-library invariant: no errexit, zero stdout on source, diagnostics to stderr.

### Modified

- `scripts/init-claude.sh` — added Phase 3 DETECT-05 wiring block between `SKIP_COUNCIL` and `detect_framework()` (lines 48-84 post-edit). Downloads `detect.sh`, `lib/install.sh`, and `manifest.json` into temp files via `mktemp` + `curl -sSLf` + `trap ... EXIT`. Sources both shell files. Hard-fails with `${RED}✗${NC}` on `manifest_version != 2`. Exposes `$MANIFEST_FILE` (pointing at the fetched temp manifest) for Plan 03-02 consumption.
- `scripts/init-local.sh` — added Phase 3 DETECT-05 wiring block between `CLAUDE_DIR` and `# Flags` (lines 34-48 post-edit). Sources `$SCRIPT_DIR/detect.sh` and `$SCRIPT_DIR/lib/install.sh`. Hard-fails on `manifest_version != 2` using the already-defined `$MANIFEST_FILE`.
- `scripts/update-claude.sh` — added Phase 3 DETECT-05 wiring block between `MANIFEST_URL` and `# HELPER FUNCTIONS` (lines 19-44 post-edit). Downloads `detect.sh` to temp file; on failure prints `⚠` warning and sets `HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION=""` so Phase 4 logic can detect the "unknown" state.

### Not modified (Option A decision for Task 4)

- `manifest.json` — unchanged. `scripts/lib/install.sh` is internal infrastructure, not a user-installed file. `scripts/validate-manifest.py` Check 6 only scans `commands/` and `templates/base/skills/`, so `make validate` stays green without a manifest entry.

## Decisions Made

1. **Task 4 → Option A (no manifest.json change).** Per the plan's decision rule, `make validate` passes without adding `scripts/lib/install.sh` to `manifest.json` because `validate-manifest.py` Check 6 scans only user-facing directories (`commands/`, `templates/base/skills/`). The manifest's `files.*` section describes *installed* files; repo-internal infrastructure (scripts, Makefile, validators, lib files) is not subject to manifest tracking. No `infrastructure` category needed.
2. **shellcheck SC2034 disable on forward-referenced variables.** `MANIFEST_FILE` in init-claude.sh (Plan 03-02 consumer) and the `HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION` fallback block in update-claude.sh (Phase 4 consumer) trigger SC2034 in the Phase 3 scope. Silenced with per-line `# shellcheck disable=SC2034` + explicit comment about the downstream consumer — same approach used in `scripts/detect.sh` for its color constants.

## Detect.sh wiring locations (line numbers post-edit)

| Script | Lines | Pattern | Failure mode |
|--------|-------|---------|--------------|
| `scripts/init-claude.sh` | 48-84 | Remote mktemp+curl+trap, consolidated trap on DETECT_TMP/LIB_INSTALL_TMP/MANIFEST_TMP | **Hard-fail** on detect.sh / lib/install.sh / manifest.json download failure |
| `scripts/init-local.sh` | 34-48 | `source "$SCRIPT_DIR/detect.sh"` / `source "$SCRIPT_DIR/lib/install.sh"` | **Hard-fail** on manifest_version != 2 |
| `scripts/update-claude.sh` | 19-44 | Remote mktemp+curl+trap on DETECT_TMP only | **Soft-fail** on detect.sh download failure — sets HAS_SP=false/HAS_GSD=false fallbacks |

## Functions exported by lib/install.sh — contracts

| Function / var | Contract |
|----------------|----------|
| `MODES` (array) | `("standalone" "complement-sp" "complement-gsd" "complement-full")` — 4 entries, prompt order |
| `recommend_mode` | Reads `$HAS_SP` / `$HAS_GSD`, echoes one of the 4 mode names to stdout. Defaults to `standalone` when either var is unset. |
| `compute_skip_set <mode> <manifest_path>` | Echoes JSON array of `.path` values whose `conflicts_with` intersects the mode's skip set. Returns 1 with stderr on unknown mode or missing jq. Verified: 0/7/0/7 against current manifest. |
| `backup_settings_once <settings_path>` | Creates `<settings_path>.bak.$(date +%s)` ONCE per run and sets `$TK_SETTINGS_BACKUP`. No-op if file missing or `$TK_SETTINGS_BACKUP` already set. |
| `print_dry_run_grouped <manifest> <mode>` | **STUB** — full implementation lands in Plan 03-02. Echoes "TODO" to stderr and returns 0. |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added shellcheck SC2034 disable comments on forward-referenced variables**

- **Found during:** Task 2 (init-claude.sh edit) and Task 3 (update-claude.sh edit)
- **Issue:** `MANIFEST_FILE` (init-claude.sh) and `HAS_SP`/`HAS_GSD`/`SP_VERSION`/`GSD_VERSION` (update-claude.sh soft-fail branch) trigger SC2034 "appears unused" because they are consumed by Plan 03-02 / Phase 4, not within this plan. `make shellcheck` was failing.
- **Fix:** Added per-line `# shellcheck disable=SC2034` with explicit comment referencing the downstream consumer. Mirrors the existing pattern in `scripts/detect.sh` for its color constants.
- **Files modified:** `scripts/init-claude.sh`, `scripts/update-claude.sh`
- **Verification:** `make shellcheck` exits 0 after fix.
- **Committed in:** `ae59c4b` (Task 2), `007892c` (Task 3)

**2. [Rule 1 - Bug] Omitted redundant inline log_warning() definition in update-claude.sh soft-fail branch**

- **Found during:** Task 3
- **Issue:** Plan text included `log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }` inside the else-branch "in case it's needed below" — but (a) the real `log_warning` is defined unconditionally at line 49 just below this block, and (b) the else-branch uses `echo -e "${YELLOW}⚠${NC} ..."` directly, not `log_warning`. Defining it inside the else-branch would be dead code and potentially trigger shellcheck SC2317 (unreachable command).
- **Fix:** Omitted the inline redefinition; kept only the direct `echo -e` warning call. Behavior-equivalent to plan intent ("soft-fail prints a warning") and cleaner.
- **Files modified:** `scripts/update-claude.sh`
- **Verification:** `make shellcheck` green; warning still prints on download failure.
- **Committed in:** `007892c` (Task 3)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 cleanup bug)
**Impact on plan:** Both auto-fixes preserve plan intent and the project-wide `make check` gate. No scope creep.

## Issues Encountered

- **Worktree base mismatch at startup.** The pre-bash Safety Net blocked the prescribed `git reset --hard` and `git checkout -- .` commands in `<worktree_branch_check>`. Since `git status` confirmed the working tree was clean, I used the safer `git merge --ff-only <target>` to fast-forward the worktree to the correct base commit — no uncommitted work lost, exact same end state. Documented here for the orchestrator.
- No other issues during task execution.

## Next Phase Readiness

- Plan 03-02 can now consume `compute_skip_set`, `recommend_mode`, `MODES`, `$MANIFEST_FILE` (init-claude.sh), `$HAS_SP`/`$HAS_GSD` directly — all plumbing in place.
- Plan 03-03 can now consume `backup_settings_once` from the shared library.
- Phase 4 UPDATE-01 can branch on `$HAS_SP`/`$HAS_GSD` in update-claude.sh (with the soft-fail fallback giving it a usable "unknown" signal).

## Self-Check: PASSED

**Created files verified on disk:**

- `scripts/lib/install.sh` — FOUND (75 lines)

**Task commits verified in git log:**

- `de6a505` — FOUND — `feat(03-01): add scripts/lib/install.sh sourced library skeleton`
- `ae59c4b` — FOUND — `feat(03-01): wire detect.sh and lib/install.sh into init scripts`
- `007892c` — FOUND — `feat(03-01): source detect.sh in update-claude.sh (D-31)`

**Gate verification:**

- `make shellcheck` → exits 0 ✓
- `make validate` → exits 0 ✓
- `make test` → Tests 1-5 all pass ✓
- `compute_skip_set complement-sp manifest.json | jq length` → `7` ✓
- `compute_skip_set standalone manifest.json | jq length` → `0` ✓
- Zero stdout on `source scripts/lib/install.sh` ✓
- `grep -c "set -euo pipefail" scripts/lib/install.sh` → `0` ✓

---

*Phase: 03-install-flow*
*Plan: 03-01*
*Completed: 2026-04-18*
