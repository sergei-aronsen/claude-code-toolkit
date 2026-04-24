---
phase: 08-release-quality
plan: "03"
subsystem: scripts/validate-release.sh
tags: [rel-03, collect-all, aggregation, bash, matrix-runner]
requirements: [REL-03]

dependency_graph:
  requires: []
  provides: [--collect-all flag, collect_cell, print_aggregate_table, mutex guard]
  affects: [scripts/validate-release.sh]

tech_stack:
  added: []
  patterns: [indexed-accumulator-arrays, printf-BSD-portable, pre-parse-mutex-guard]

key_files:
  created: []
  modified:
    - scripts/validate-release.sh

decisions:
  - "Used indexed arrays (_COLL_NAMES/_COLL_PASS/_COLL_FAIL) not associative — bash 3.2 compatibility (no declare -A)"
  - "Used printf width specifiers for table, not GNU column --table-columns — BSD macOS portability (D-13 per 08-CONTEXT.md)"
  - "Mutex guard implemented as pre-parse loop over $@ before the case block — handles both orderings symmetrically (D-14)"
  - "collect_cell() invokes cell body via direct function call (not subshell) so PASS/FAIL globals propagate correctly"
  - "No color in aggregated table per D-13 — Phase 11 UX-01 scope for theming"

metrics:
  duration_seconds: ~25
  completed: "2026-04-24T14:22:22Z"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 8 Plan 03: REL-03 --collect-all Flag Summary

**One-liner:** REL-03 complete — `--collect-all` ships aggregated matrix view across all 13 cells; `--all` fail-fast untouched; mutex guard enforced (exit 2 both orderings).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add --collect-all dispatcher arm + collect_cell + print_aggregate_table + mutex guard | 3aa2b3d | scripts/validate-release.sh (+73 lines) |

## What Was Built

Added `--collect-all` flag to `scripts/validate-release.sh`. Changes are purely additive — no cell body or `--all` path was touched.

**New functions:**

- `collect_cell(cell_name, body_fn)` — sibling of `run_cell()`. Captures `PASS`/`FAIL` before/after invoking the cell body, computes per-cell delta, appends to `_COLL_NAMES`/`_COLL_PASS`/`_COLL_FAIL`. Does NOT exit 1 on failure.
- `print_aggregate_table()` — iterates accumulator arrays, emits BSD-portable `printf` ASCII table with header row `Cell | Pass | Fail | Status` and separator, then summary line.

**New globals (top-level, indexed arrays):**

```bash
declare -a _COLL_NAMES=()
declare -a _COLL_PASS=()
declare -a _COLL_FAIL=()
```

**Mutex guard (pre-parse before `case` block):**

Scans `$@` for `--all` and `--collect-all` simultaneously; emits `ERROR: --all and --collect-all are mutually exclusive` to stderr and exits 2 if both present. Order-symmetric.

**Dispatcher arm:**

```bash
--collect-all)
    for c in "${CELLS[@]}"; do
        collect_cell "$c" "$(cell_fn_for "$c")"
    done
    print_aggregate_table
    [ "$FAIL" -gt 0 ] && exit 1
    exit 0
    ;;
```

## Aggregated Table Fixture (clean HEAD)

```text
Cell                             Pass Fail Status
-------------------------------- ---- ---- ------
standalone-fresh                    6    0   PASS
standalone-upgrade                  6    0   PASS
standalone-rerun                    7    0   PASS
complement-sp-fresh                 7    0   PASS
complement-sp-upgrade               2    0   PASS
complement-sp-rerun                 6    0   PASS
complement-gsd-fresh                6    0   PASS
complement-gsd-upgrade              2    0   PASS
complement-gsd-rerun                5    0   PASS
complement-full-fresh               7    0   PASS
complement-full-upgrade             2    0   PASS
complement-full-rerun               6    0   PASS
translation-sync                    1    0   PASS

Matrix: 13/13 cells passed, 63 assertions passed, 0 failed
```

## Manual Drift-Injection Test Results

**Test 1 — --collect-all runs all 13 cells past a failure:**

Injected `assert_eq "0" "1" "force-fail-rel-03-test"` at top of `cell_standalone_fresh()`.

- Output: 13 cell headers present, `standalone-fresh` row shows `Fail=1 Status=FAIL`, remaining 12 rows show `PASS`.
- Summary: `Matrix: 12/13 cells passed, 63 assertions passed, 1 failed`
- Exit code: 1
- Confirmed: no early termination — all 13 cells ran.

**Test 2 — --all fail-fast regression (D-12):**

Same injection active. `bash scripts/validate-release.sh --all`:

- Output: only `━━ Cell: standalone-fresh ━━` header appeared; no subsequent cell headers.
- Exit code: 1
- Confirmed: fail-fast behavior preserved exactly.

**Test 3 — Mutex exit 2 (both orderings):**

- `--all --collect-all`: stderr `ERROR: --all and --collect-all are mutually exclusive`, exit 2.
- `--collect-all --all`: same error, exit 2.
- Confirmed: order-symmetric.

After all tests: patch reverted, clean HEAD run confirms `13/13 cells passed`, exit 0.

## Deviations from Plan

None — plan executed exactly as written. All implementation steps (1a–1f) followed the template in 08-PATTERNS.md §"scripts/validate-release.sh (modified — add --collect-all)".

## Known Stubs

None.

## Threat Flags

None. All additions are pure in-repo bash code to an existing script. No new network endpoints, auth paths, file operations, or schema changes. Threat register T-08-03-01 through T-08-03-05 verified closed per plan's `<threat_model>`.

## Self-Check: PASSED

- `scripts/validate-release.sh` exists and has all required symbols: VERIFIED
- Commit `3aa2b3d` exists: VERIFIED
- `bash -n scripts/validate-release.sh` exits 0: VERIFIED
- `bash scripts/validate-release.sh --self-test` exits 0: VERIFIED
- `bash scripts/validate-release.sh --collect-all` exits 0 on clean HEAD: VERIFIED
- `bash scripts/validate-release.sh --all --collect-all` exits 2: VERIFIED
- `make check` exits 0: VERIFIED

## Next

Runs parallel to Plan 08-01 (bats port) and Plan 08-02 (cell-parity). All three merge independently. No downstream plan depends on this one within Phase 8.
