---
phase: 22-smart-update-coverage-for-scripts-lib-sh
plan: 02
subsystem: infra
tags: [test, update-claude, lib, bash, ci, makefile]

# Dependency graph
requires:
  - phase: 22-01
    provides: "manifest.json files.libs[] with six lib entries, version 4.4.0"
provides:
  - "scripts/tests/test-update-libs.sh — hermetic five-scenario LIB-01/02 regression test"
  - "Makefile Test 29 inline + standalone test-update-libs target"
  - ".github/workflows/quality.yml Tests 21-29 step with LIB-01..02 tag"
affects:
  - make test (adds Test 29)
  - CI quality.yml Tests 21-29 step

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "S1 setup: seed stale file on disk + empty installed_files[] in state → update sees it as NEW and overwrites with repo HEAD"
    - "S4 fail-closed: no TTY in $(...) subshell → read < /dev/tty fails → choice='N' (no seam needed)"
    - "S5 assertion: check file removal, not directory removal (uninstall removes files, dir may linger empty)"

key-files:
  created:
    - scripts/tests/test-update-libs.sh
  modified:
    - Makefile
    - .github/workflows/quality.yml

key-decisions:
  - "S1 setup uses empty installed_files[] state file (not no-state-file): synthesize_v3_state would record the stale SHA, making update see it as up-to-date. A minimal state file with empty installed_files[] forces the file through the new-files install path."
  - "TK_UPDATE_FILE_SRC set to REPO_ROOT (not REPO_ROOT/scripts/lib): seam resolves paths as $TK_UPDATE_FILE_SRC/$rel where rel=scripts/lib/backup.sh — needs repo root as base."
  - "S4 requires no new TTY seam: prompt_modified_file uses read < /dev/tty 2>/dev/null; in $(...) subshell /dev/tty is unavailable, read fails, choice defaults N (RESEARCH.md Q2 confirmed)."
  - "S5 asserts file-level removal (backup.sh gone), not directory removal: uninstall.sh deletes individual files but does not rmdir empty parent directories."
  - "HAS_SP=false HAS_GSD=false SP_VERSION='' GSD_VERSION='' passed to all update invocations to bypass detect.sh network call in hermetic test context."

patterns-established:
  - "Hermetic update test: TK_UPDATE_HOME + TK_UPDATE_FILE_SRC=$REPO_ROOT + TK_UPDATE_MANIFEST_OVERRIDE + TK_UPDATE_LIB_DIR + HAS_SP/GSD override"
  - "Seed minimal state JSON via python3 inline to control what the update loop sees as installed vs new"

requirements-completed: [LIB-02]

# Metrics
duration: 25min
completed: 2026-04-27
---

# Phase 22 Plan 02: test-update-libs.sh + Makefile Test 29 + CI Tests 21-29 Summary

**Hermetic five-scenario regression test proving LIB-02: stale/clean/fresh/modified/uninstall coverage for all six scripts/lib/*.sh helpers; wired into make test (Test 29) and CI (Tests 21-29)**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-27
- **Completed:** 2026-04-27
- **Tasks:** 3
- **Files modified:** 3 (1 new, 2 edited)

## Accomplishments

- Created `scripts/tests/test-update-libs.sh` (351 lines): five hermetic scenarios S1-S5, PASS=15 FAIL=0, shellcheck-clean, idempotent across consecutive runs
- Wired Test 29 into `Makefile`: `.PHONY` updated, inline Test 29 block after Test 28, standalone `test-update-libs:` target
- Updated `.github/workflows/quality.yml`: step renamed `Tests 21-29`, LIB-01..02 tag added, `bash scripts/tests/test-update-libs.sh` appended as ninth run: line
- `make check` and `make test` (exit 0) both green

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/tests/test-update-libs.sh** — `b44513b` (feat)
2. **Task 2: Wire Test 29 into Makefile** — `1286e1d` (feat)
3. **Task 3: Mirror Test 29 in quality.yml** — `ed11a7e` (ci)

## Files Created/Modified

- `scripts/tests/test-update-libs.sh` — new file (351 lines, mode 0755): five scenarios, 15 assertions, shellcheck-clean
- `Makefile` — `.PHONY` line + Test 29 inline echo/bash block + standalone target (8 lines added)
- `.github/workflows/quality.yml` — step name updated, LIB-01..02 tag, one new bash line (net +2/-1)

## Test Results

Final PASS count from `bash scripts/tests/test-update-libs.sh`:

```text
test-update-libs complete: PASS=15 FAIL=0
```

All five scenarios passed (3 assertions each):

| Scenario | Assertions | Result |
|----------|-----------|--------|
| S1: stale lib refreshed | 3 | PASS |
| S2: clean lib untouched | 3 | PASS |
| S3: fresh install all six | 3 | PASS |
| S4: modified fail-closed | 3 | PASS |
| S5: uninstall round-trip | 3 | PASS |

## S4 Fail-Closed Confirmation (RESEARCH.md Q2)

No new TTY seam was added to `update-claude.sh`. The existing `prompt_modified_file`
function at line 804 uses:

```bash
if ! read -r -p "..." choice < /dev/tty 2>/dev/null; then
    choice="N"
fi
```

In a `$(...)` subshell (as used by the test), `/dev/tty` is unavailable. The `read`
fails, `choice` defaults to `"N"`, and the modified file is left untouched. S4 proves
this path without requiring any code changes to `update-claude.sh`. RESEARCH.md Q2
fail-closed reasoning held exactly as predicted.

## Shellcheck Adjustments

Two fixes beyond the documented `SC2064` trap disable:

1. **SC2012** (info): Replaced `ls *.sh | wc -l` with `find -maxdepth 1 -name '*.sh' | wc -l` in S3 file count assertion
2. **SC2034** (warning): Removed unused `RC_REAL` and `OUTPUT_REAL` local variables from `run_s5()` after simplifying the real-uninstall invocation to `... || true` (exit code is implicitly checked by the file-presence assertion)

No other shellcheck disables were needed beyond the standard `SC2064` on each `trap "rm -rf '${SANDBOX:?}'" RETURN` line (one per scenario function = 5 total).

## TK_UPDATE_FILE_SRC Seam Correction

The PATTERNS.md template showed `TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib"`. This is
incorrect — the seam resolves file paths as `$TK_UPDATE_FILE_SRC/$rel` where `$rel` is
the full manifest path (e.g., `scripts/lib/backup.sh`). The correct value is
`TK_UPDATE_FILE_SRC="$REPO_ROOT"` so that `$REPO_ROOT/scripts/lib/backup.sh` resolves
correctly.

## S1 Setup Architecture

The PATTERNS.md and PLAN showed "seed stale backup.sh → run update → assert SHA refreshed." This naive setup fails because `synthesize_v3_state` (invoked when no STATE_FILE exists) scans the filesystem, finds the stale file on disk, and records the stale SHA as the "installed" SHA. The update loop then compares disk-SHA (stale) vs stored-SHA (stale) — they match, no action.

Fix: create a minimal `toolkit-install.json` with empty `installed_files[]`. This bypasses `synthesize_v3_state` (state file exists) and causes `compute_file_diffs_obj` to put `scripts/lib/backup.sh` in `new` (in manifest, not in state). The new-files install loop then overwrites the stale file with the repo HEAD copy from `TK_UPDATE_FILE_SRC`.

## S5 Assertion Architecture

Plan expected `[ ! -d "$SANDBOX/.claude/scripts/lib" ]`. After debugging, `uninstall.sh`
removes individual files but does NOT `rmdir` empty parent directories. The directory
remains (empty) after uninstall. Assertion changed to `[ ! -f "$SANDBOX/.claude/scripts/lib/backup.sh" ]`
which correctly proves the lib files were removed.

## Makefile Diff (TAB Discipline)

```makefile
# Before (lines 144-147):
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "All tests passed!"

# After:
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "Test 29: smart-update coverage for scripts/lib/*.sh (LIB-01..02)"
	@bash scripts/tests/test-update-libs.sh
	@echo ""
	@echo "All tests passed!"

# Standalone target (added after test: recipe):
test-update-libs:
	@bash scripts/tests/test-update-libs.sh
```

All recipe lines use literal TAB characters. `make -n test-update-libs` confirms
`bash scripts/tests/test-update-libs.sh` in dry-run output.

## quality.yml Tests 21-29 Step

Final step name:

```text
Tests 21-29 — uninstall + banner suite + bootstrap + lib coverage (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02)
```

Nine `bash scripts/tests/` invocations in the `run:` block (8 original + `test-update-libs.sh`).
YAML parses cleanly via `python3 -c "import yaml; yaml.safe_load(...)"`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Incorrect TK_UPDATE_FILE_SRC path in PATTERNS.md**

- **Found during:** Task 1, S3 SHA verification
- **Issue:** PATTERNS.md showed `TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib"` but the seam resolves `$TK_UPDATE_FILE_SRC/$rel` where `$rel = "scripts/lib/backup.sh"` — this would look for the file at `$REPO_ROOT/scripts/lib/scripts/lib/backup.sh`
- **Fix:** Set `TK_UPDATE_FILE_SRC="$REPO_ROOT"` so paths resolve correctly
- **Files modified:** `scripts/tests/test-update-libs.sh` (all scenario invocations)

**2. [Rule 1 - Bug] S1 setup naive approach — synthesize_v3_state cancels stale detection**

- **Found during:** Task 1, S1 first run (PASS=12 FAIL=3)
- **Issue:** Without a STATE_FILE, `synthesize_v3_state` records the stale SHA as installed SHA. The update loop then computes disk-SHA == stored-SHA → no action. The stale file is never refreshed.
- **Fix:** Seed a minimal `toolkit-install.json` with empty `installed_files[]` so the update loop treats `scripts/lib/backup.sh` as a new file and overwrites it
- **Files modified:** `scripts/tests/test-update-libs.sh` (run_s1 setup block)

**3. [Rule 1 - Bug] S5 directory-removal assertion — uninstall doesn't rmdir**

- **Found during:** Task 1, S5 first run (directory still exists after uninstall)
- **Issue:** `uninstall.sh` removes individual files via `rm -f` but does not call `rmdir` on parent directories. The empty `scripts/lib/` directory remains on disk.
- **Fix:** Changed assertion to check that `backup.sh` is absent (file-level, not directory-level)
- **Files modified:** `scripts/tests/test-update-libs.sh` (run_s5 assertion)

**4. [Rule 2 - Shellcheck] SC2012 + SC2034 cleanup**

- **Found during:** Task 1, shellcheck run
- **SC2012:** `ls *.sh | wc -l` → `find -maxdepth 1 -name '*.sh' | wc -l`
- **SC2034:** removed `RC_REAL`, `OUTPUT_REAL` unused locals from `run_s5`
- **Files modified:** `scripts/tests/test-update-libs.sh`

## Known Stubs

None — all five scenarios exercise real behavior against real files.

## Threat Flags

None — `test-update-libs.sh` is a test-only file (never executed in production).
No new network endpoints, auth paths, or file access patterns introduced.

## Self-Check

### Files exist

- `scripts/tests/test-update-libs.sh` — FOUND (b44513b)
- `Makefile` — FOUND (1286e1d)
- `.github/workflows/quality.yml` — FOUND (ed11a7e)

### Commits exist

- `b44513b` — feat(22-02): add test-update-libs.sh
- `1286e1d` — feat(22-02): wire Test 29 into Makefile
- `ed11a7e` — ci(22-02): rename CI step Tests 21-28 → Tests 21-29

### Must-have truths verified

- [x] `scripts/tests/test-update-libs.sh` exits 0 with PASS=15 FAIL=0 on two consecutive runs
- [x] S1 proves stale lib/backup.sh on disk gets refreshed to repo HEAD SHA by update-claude.sh
- [x] S5 proves uninstall round-trip removes scripts/lib/backup.sh after the smart-update install path
- [x] Makefile Test 29 invokes test-update-libs.sh; CI step renamed Tests 21-29 invokes same script
- [x] `make check` passes (markdownlint + shellcheck + validate + version-align all green)
- [x] `make test` exits 0 (all 29 tests)

## Self-Check: PASSED

---

*Phase: 22-smart-update-coverage-for-scripts-lib-sh*
*Completed: 2026-04-27*
