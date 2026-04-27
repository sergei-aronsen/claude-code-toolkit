---
phase: 23-installer-symmetry-recovery
plan: "02"
subsystem: uninstall
tags: [keep-state, partial-uninstall-recovery, argparse, boolean-gate, KEEP-01]
dependency_graph:
  requires: [23-01-PLAN.md]
  provides: [KEEP-01 implementation in scripts/uninstall.sh]
  affects: [scripts/tests/test-uninstall-keep-state.sh (Plan 23-03 will test this)]
tech_stack:
  added: []
  patterns:
    - "for/arg argparse loop with env-var precedence: KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}"
    - "boolean gate: if [[ $KEEP_STATE -eq 0 ]]; then rm ...; else log_info ...; fi"
    - "SC2034 forward-reference via : \"$VAR\" for shellcheck-clean distant consumption"
key_files:
  modified:
    - scripts/uninstall.sh
decisions:
  - "R-06 honored: NO shift in --keep-state) clause — script uses for/arg loop, not while/$#"
  - "D-07 honored: inner if rm -f block preserved byte-identical inside outer KEEP_STATE gate"
  - "D-09 honored: KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0} seeds default, CLI overrides to 1"
  - "D-06 invariant intact: state-delete gate sits at same byte offset, no reordering"
  - "sed range updated 3,18p → 3,19p to include new --keep-state usage line in --help output"
metrics:
  duration_minutes: 5
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
  files_created: 0
  completed_date: "2026-04-27"
---

# Phase 23 Plan 02: --keep-state flag for uninstall.sh Summary

**One-liner:** KEEP-01 wired — `--keep-state` / `TK_UNINSTALL_KEEP_STATE=1` preserves `toolkit-install.json` behind a boolean gate on the existing `rm -f "$STATE_FILE"` call at the D-06 LAST-step position.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Add KEEP_STATE default + argparse clause + Usage comment | 7d532e0 | +KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}, +--keep-state) clause, +usage line, sed 3,18p→3,19p, SC2034 ref |
| 2 | Wrap state-delete block with KEEP_STATE gate | 8b943f9 | +if [[ $KEEP_STATE -eq 0 ]] outer gate, +log_info else branch, +2 comment lines |

## What Was Built

`scripts/uninstall.sh` gains full KEEP-01 wiring in two atomic commits:

**Task 1 (argparse side):**
- `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` inserted after `DRY_RUN=0` — env-var seeds the default (D-09), CLI flag overrides
- `--keep-state) KEEP_STATE=1 ;;` clause inserted after `--dry-run)` in the `for arg in "$@"` loop — no `shift` per R-06 (this script uses for/arg, not while/$#)
- Usage comment `#   bash scripts/uninstall.sh --keep-state  # preserve toolkit-install.json for re-run recovery` added between `--dry-run` and `--help` lines
- `sed -n '3,18p'` updated to `sed -n '3,19p'` so `--help` output includes the new usage line
- SC2034 comment and `: "$DRY_RUN"` reference updated to cover `KEEP_STATE` too

**Task 2 (gate side):**
- Original 5-line `if rm -f "$STATE_FILE"; then ... fi` block wrapped with `if [[ $KEEP_STATE -eq 0 ]]; then ... else log_info ...; fi`
- Inner block preserved byte-identical, indented one level deeper (D-07: gate the existing call, do NOT redesign)
- `else` branch: `log_info "State file preserved (--keep-state): $STATE_FILE"` — informational tone (state preserved is user's explicit choice, not an error)
- Two new comment lines added explaining the KEEP_STATE branch and cross-link to KEEP-02 test (Plan 23-03)
- D-06 LAST-step invariant intact: gate sits at same byte offset, no reordering of backup/snapshot/sentinel-strip/diff-q steps
- Post-gate lines (`echo ""`, `log_success "Uninstall complete..."`, `exit 0`) remain outside, always reached on both branches

## Net Diff

~18 lines added, ~7 removed (net +11) across one file:
- +1 Usage comment line
- +1 KEEP_STATE default line
- +3 argparse clause lines (`--keep-state)`, `KEEP_STATE=1`, `;;`)
- +1 updated SC2034 reference line (old `: "$DRY_RUN"` → `: "$DRY_RUN" "$KEEP_STATE"`)
- +2 comment lines in state-delete block
- +1 outer `if [[ $KEEP_STATE -eq 0 ]]; then` line
- +1 `else` line
- +1 `log_info "State file preserved..."` line
- Inner block: 5 lines + extra indentation (counts as modified, not added)

## Verification Results

### KEEP-01 Source-Grep Signals

```
KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}   PASS — env-var-defaulted init present
--keep-state) clause                        PASS — argparse clause present
KEEP_STATE=1                                PASS — clause body sets flag
sed -n '3,19p'                              PASS — sed range updated
--help shows --keep-state                   PASS — Usage documents the flag
--help shows 'preserve toolkit-install.json' PASS — Usage describes purpose
if [[ $KEEP_STATE -eq 0 ]]                 PASS — gate present, correct direction
log_info "State file preserved"             PASS — else-branch message present
rm -f "$STATE_FILE" count == 1             PASS — rm -f preserved exactly once inside gate
```

### Regression Tests (all 5 v4.3 uninstall tests)

```
test-uninstall-dry-run.sh      8/8 assertions PASS
test-uninstall-backup.sh      12/12 assertions PASS
test-uninstall-prompt.sh      10/10 assertions PASS
test-uninstall.sh             18/18 assertions PASS
test-uninstall-idempotency.sh  5/5 assertions PASS
test-uninstall-state-cleanup.sh 11/11 assertions PASS
```

All 64 assertions across 6 test files pass — proves D-06 LAST-step + D-10 backup + UN-01..UN-08 invariants are preserved on the default branch.

### Static Analysis

```
shellcheck scripts/uninstall.sh   PASS (no new warnings, SC2034 satisfied)
make check                        PASS (shellcheck + markdownlint + validate all green)
```

### Smoke Test

```
--keep-state against empty sandbox (no state file): exits 0, prints "Toolkit not installed; nothing to do."
```
Idempotency guard at line 389 fires correctly — KEEP_STATE parsed but gate never reached when state file absent (R-01 behavior confirmed).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The KEEP-01 implementation is complete. The `--keep-state` branch (log_info + preserve) is the full implementation per spec. Plan 23-03 will add `scripts/tests/test-uninstall-keep-state.sh` (KEEP-02) to prove the end-to-end contract through real install+uninstall sandbox runs.

## Notes for Downstream

- **Plan 23-03 (KEEP-02):** Will add `scripts/tests/test-uninstall-keep-state.sh` exercising S1 (N-choice preserves state, second run re-classifies), S2 (y-choice also preserves state), S3 (env-var path D-09). That test is the proof gate; this plan is the implementation gate.
- **CHANGELOG.md `[4.4.0]` Added bullet** for KEEP-01 will be written in Plan 23-03 (consolidated bullet writes per D-18).
- **docs/INSTALL.md flag documentation** for `--keep-state` will be added in Plan 23-03 (consolidated docs writes per D-18).
- **Re-run verification commands:**

```bash
shellcheck scripts/uninstall.sh
grep -q '^KEEP_STATE=\${TK_UNINSTALL_KEEP_STATE:-0}' scripts/uninstall.sh
grep -qE '^[[:space:]]*--keep-state\)' scripts/uninstall.sh
grep -q 'if \[\[ \$KEEP_STATE -eq 0 \]\]' scripts/uninstall.sh
grep -q 'log_info "State file preserved' scripts/uninstall.sh
bash scripts/uninstall.sh --help 2>&1 | grep -q -- '--keep-state'
bash scripts/tests/test-uninstall.sh
bash scripts/tests/test-uninstall-idempotency.sh
bash scripts/tests/test-uninstall-state-cleanup.sh
```

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `--keep-state` flag is a value-less boolean parsed via literal `case "$arg" in --keep-state)` match — zero interpolation surface. `TK_UNINSTALL_KEEP_STATE` env var feeds only into `[[ $KEEP_STATE -eq 0 ]]` integer comparison — non-integer values default to `0` (safe path = delete state). See plan threat model T-23-02-01 and T-23-02-02 for full analysis.

## Self-Check: PASSED

- FOUND: .planning/phases/23-installer-symmetry-recovery/23-02-SUMMARY.md
- FOUND: scripts/uninstall.sh
- FOUND: commit 7d532e0 (Task 1 — argparse + KEEP_STATE default)
- FOUND: commit 8b943f9 (Task 2 — state-delete gate)
