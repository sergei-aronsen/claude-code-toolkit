---
phase: 08-release-quality
plan: "01"
subsystem: test-infra
tags: [bats, release-matrix, helpers-extraction, REL-01]
dependency_graph:
  requires: []
  provides:
    - scripts/tests/matrix/lib/helpers.bash
    - scripts/tests/matrix/*.bats (5 files, 13 @test)
    - make test-matrix-bats
    - CI job test-matrix-bats
  affects:
    - scripts/validate-release.sh (sources helpers.bash instead of inline)
    - .github/workflows/quality.yml (new job)
    - Makefile (new target)
tech_stack:
  added:
    - bats-core v1.13.0 (test runner, brew install bats-core locally; CI via bats-core/bats-action)
    - bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43 (v4.0.0, CI install)
  patterns:
    - double-source guard (_TK_HELPERS_LOADED) for shared bash lib
    - BASH_SOURCE[0]-based REPO_ROOT derivation (4 levels up from scripts/tests/matrix/lib/)
    - bats setup() sourcing (per-test, not setup_file — ensures PASS/FAIL counter isolation)
    - TAP output via bats --tap
key_files:
  created:
    - scripts/tests/matrix/lib/helpers.bash (429 lines — shared assert_*/sandbox_*/cell_* lib)
    - scripts/tests/matrix/standalone.bats (3 @test, 19 assertions)
    - scripts/tests/matrix/complement-sp.bats (3 @test, 15 assertions)
    - scripts/tests/matrix/complement-gsd.bats (3 @test, 13 assertions)
    - scripts/tests/matrix/complement-full.bats (3 @test, 15 assertions)
    - scripts/tests/matrix/translation-sync.bats (1 @test, 1 assertion)
  modified:
    - scripts/validate-release.sh (removed 425 lines of inline helpers/cells, added 1 source line)
    - Makefile (added test-matrix-bats target + .PHONY entry)
    - .github/workflows/quality.yml (added test-matrix-bats job)
decisions:
  - "Removed REPO_ROOT and LIB_DIR from validate-release.sh after extraction (shellcheck SC2034 — both now owned exclusively by helpers.bash)"
  - "helpers.bash derives REPO_ROOT independently via BASH_SOURCE[0] (4 levels up), not from caller context"
  - "bats files use setup() not setup_file() — each @test runs in its own subprocess, PASS/FAIL counters reset automatically at source time"
  - "No run wrapper around cell_* calls — would swallow FAIL counter mutations into subshell"
metrics:
  duration_seconds: 383
  completed: "2026-04-24"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 3
---

# Phase 08 Plan 01: REL-01 bats Port Summary

**One-liner:** REL-01 complete — 13-cell install matrix ported to bats, 63 assertions preserved
via shared helpers.bash, bash runner unchanged and passing.

## What Was Built

### Task 1: Extract helpers.bash (refactor)

`scripts/tests/matrix/lib/helpers.bash` (429 lines) — extracted verbatim from
`scripts/validate-release.sh` (lines 23-463). Contains:

- Double-source guard (`_TK_HELPERS_LOADED=1`)
- REPO_ROOT derivation via `BASH_SOURCE[0]` (4 levels up from `lib/`)
- TTY-auto-disable color constants
- Global `PASS=0 FAIL=0` counters (reset per bats @test subprocess)
- 7 assert helpers: `assert_eq`, `assert_contains`, `assert_state_schema` (→4 asserts),
  `assert_settings_foreign_intact`, `assert_skiplist_clean`, `assert_no_agent_collision`
- 8 sandbox/fixture helpers: `sandbox_setup`, `stage_sp_cache`, `stage_gsd_cache`,
  `snapshot_foreign_settings`, `seed_foreign_settings`, `setup_v3x_worktree`,
  `cleanup_v3x_worktrees`, `trap cleanup_v3x_worktrees EXIT`
- All 13 `cell_*` body functions verbatim (1:1 D-03 parity)

`scripts/validate-release.sh` modified: removed 425 lines of inline content, replaced
with single `source "${SCRIPT_DIR}/tests/matrix/lib/helpers.bash"`.
Also removed `LIB_DIR` and `MANIFEST_FILE` declarations (now unused in runner;
owned by helpers.bash — shellcheck SC2034 auto-fix).

### Task 2: 5 bats files + Makefile + CI (test + feat + ci)

**5 bats files** under `scripts/tests/matrix/`:

| File | @test count | Assertion count |
|------|-------------|-----------------|
| standalone.bats | 3 | 19 |
| complement-sp.bats | 3 | 15 |
| complement-gsd.bats | 3 | 13 |
| complement-full.bats | 3 | 15 |
| translation-sync.bats | 1 | 1 |
| **Total** | **13** | **63** |

Each bats file: `setup()` sources helpers.bash, 2-line @test body (`cell_<name>()` +
`[ "$FAIL" -eq 0 ]`). No `run` wrapper (would hide FAIL mutations).

**Makefile:** `test-matrix-bats` target added to `.PHONY` and as recipe
`@bats scripts/tests/matrix/*.bats`. Not wired into `check:` (requires local bats).

**quality.yml:** `test-matrix-bats` job added — `bats-core/bats-action` pinned to full
SHA `77d6fb60505b4d0d1d73e48bd035b55074bbfb43` (v4.0.0). No `github-token:` input
(removed in v4.0.0 as breaking change).

## Parity Audit (D-17)

```text
bash runner PASS count: 63  (expected: 63)  ✓
bats @test PASS count:  13  (expected: 13)  ✓
```

Both runners agree. Parity confirmed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused REPO_ROOT and LIB_DIR from validate-release.sh**

- **Found during:** Task 1 verification (`make shellcheck`)
- **Issue:** After extracting helpers.bash, `LIB_DIR` and `MANIFEST_FILE` remained in
  `validate-release.sh` but were only used inside helpers.bash (which re-derives them
  independently). ShellCheck SC2034 warned "appears unused." Then `REPO_ROOT` also became
  unused after removing `LIB_DIR`/`MANIFEST_FILE`.
- **Fix:** Removed both `LIB_DIR`, `MANIFEST_FILE`, and `REPO_ROOT` declarations from
  validate-release.sh. `SCRIPT_DIR` retained (used to locate helpers.bash path).
- **Files modified:** `scripts/validate-release.sh`
- **Commit:** `9fa691a` (part of refactor commit)

## Known Stubs

None — all 13 cell bodies are fully implemented with live assertions.

## Threat Flags

No new security surface introduced. The `bats-core/bats-action` dependency is pinned to
full 40-char SHA (T-08-01-01 mitigation applied). Cell sandboxes write to `/tmp/` only.
`trap cleanup_v3x_worktrees EXIT` fires per @test subprocess (T-08-01-03 mitigated).

## Self-Check: PASSED

```text
FOUND: scripts/tests/matrix/lib/helpers.bash
FOUND: scripts/tests/matrix/standalone.bats
FOUND: scripts/tests/matrix/complement-sp.bats
FOUND: scripts/tests/matrix/complement-gsd.bats
FOUND: scripts/tests/matrix/complement-full.bats
FOUND: scripts/tests/matrix/translation-sync.bats
FOUND: 9fa691a (refactor commit)
FOUND: eca57b3 (test commit)
FOUND: 65f7c32 (feat commit)
FOUND: 78ccc81 (ci commit)
make shellcheck: PASS
make mdlint: PASS
make test-matrix-bats: 13/13 ok
bash --self-test: 13 passed, 0 failed
bash --all: 63 assertions passed
```

## Next Steps

Plan 08-02 (REL-02 `cell-parity`) and Plan 08-03 (REL-03 `--collect-all`) can now run
in parallel — both are independent of this plan's output. Plan 08-02 will wire
`cell-parity` into `make check`; Plan 08-03 adds `--collect-all` to `validate-release.sh`.
