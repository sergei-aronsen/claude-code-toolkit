---
phase: 19-state-cleanup-idempotency
plan: "02"
subsystem: scripts/uninstall.sh
tags: [uninstall, sentinel-strip, base-plugin-invariant, state-delete, bash]
requirements: [UN-05]
dependency_graph:
  requires: [19-01]
  provides: [UN-05-source-impl]
  affects: [scripts/uninstall.sh]
tech_stack:
  added: []
  patterns:
    - awk one-line lookahead buffer for leading/trailing blank strip around START/END pairs
    - RETURN-scoped mktemp trap (same as prompt_modified_for_uninstall)
    - diff -q sorted file-list snapshot for base-plugin invariant (defense-in-depth)
key_files:
  modified:
    - scripts/uninstall.sh
decisions:
  - D-06 order honored: backup → strip → file-delete (Phase 18) → state-delete (LAST)
  - D-09 idempotency preserved: no-op exits at line 376 guard before any snapshot finds run
  - D-10 fail-loud: base-plugin mutation → log_error + exit 1, STATE_FILE preserved
  - D-03 least-destruction: empty CLAUDE.md left on disk, never deleted by strip
  - D-02 graceful abort: unmatched START/END markers → log_warning + return 0, file untouched
metrics:
  duration_seconds: 196
  completed_date: "2026-04-26"
  tasks_completed: 3
  files_changed: 1
---

# Phase 19 Plan 02: UN-05 Sentinel Strip + Base-Plugin Invariant + State Delete — Summary

**One-liner:** awk-based `<!-- TOOLKIT-START/END -->` sentinel strip + diff-q base-plugin invariant + `rm -f toolkit-install.json` as LAST step of successful uninstall flow.

## What Was Done

Implemented UN-05 in `scripts/uninstall.sh` across 3 tasks:

### Task 1 — `strip_sentinel_block` helper (commit `454077b`)

Added `strip_sentinel_block()` function before the `# ─── MAIN ───` divider (line 314).

- awk one-line lookahead buffer (`buf`/`have_buf`/`last_was_blank`) retroactively drops the blank line preceding `<!-- TOOLKIT-START -->` without two-pass parsing
- RETURN-scoped `mktemp` trap cleans sentinel-strip temp on any return path
- `grep -cF` with `|| true` avoids `set -e` exit on zero-match count
- Handles: absent file, zero markers, unmatched pairs (warning), multiple pairs, empty result (left on disk per D-03)

### Task 2 — Base-plugin snapshot infrastructure (commit `d240429`)

- 4 new mktemp tmps (`SP_SNAP_TMP`, `GSD_SNAP_TMP`, `SP_AFTER_TMP`, `GSD_AFTER_TMP`) registered in the single EXIT trap (all 7 tmps cleaned on any exit)
- `SP_DIR` / `GSD_DIR` variables with `TK_UNINSTALL_HOME` seam override (parallel to existing `CLAUDE_DIR`/`STATE_FILE`/`LOCK_DIR` override block)
- Pre-mutation `find "$SP_DIR" -type f 2>/dev/null | sort > "$SP_SNAP_TMP"` placed AFTER `STATE_JSON=$(read_state)` and BEFORE classification — honoring D-09 (no-op exits at line 376 before this code)

### Task 3 — Wire strip + invariant + state delete into MAIN (commit `a4fe61c`)

Replaced the Phase 18 deferred placeholder (`log_info "Phase 18 (v4.3 Wave 1)..."`) with the Phase 19 finalization block at end of MAIN:

1. **Line 631** — `strip_sentinel_block "$GLOBAL_CLAUDE_MD"` (with `TK_UNINSTALL_HOME` seam)
2. **Line 638** — `diff -q "$SP_SNAP_TMP" "$SP_AFTER_TMP"` invariant check (+ GSD at line 644)
3. **Line 653** — `rm -f "$STATE_FILE"` state delete (LAST mutating step)
4. **Line 658** — `log_success "Uninstall complete. Toolkit removed from ${PROJECT_DIR}/.claude/"`

## Lines Added/Changed

| Metric | Value |
|--------|-------|
| Total lines in `scripts/uninstall.sh` before | 524 |
| Total lines after | 661 |
| Net addition | +137 |
| Tasks | 3 |
| Commits | 3 |

## Test Pass Output — All 4 Tests

```text
test-uninstall-dry-run:    8/8 assertions passed
test-uninstall-backup:    12/12 assertions passed
test-uninstall-prompt:    10/10 assertions passed
test-uninstall-idempotency: 5/5 assertions passed
```

No regressions. `make check` passes (shellcheck + markdownlint + validate).

## Order Verification

| Operation | Line | Role |
|-----------|------|------|
| Backup (`cp -R CLAUDE_DIR BACKUP_DIR`) | 508 | Phase 18 — always first |
| File-delete loop (`rm -f` REMOVE_LIST) | 536 | Phase 18 |
| Modified-file prompt loop | 562 | Phase 18 |
| `strip_sentinel_block "$GLOBAL_CLAUDE_MD"` | 631 | Phase 19 — strip |
| `diff -q "$SP_SNAP_TMP" "$SP_AFTER_TMP"` | 638 | Phase 19 — invariant check |
| `rm -f "$STATE_FILE"` | 653 | Phase 19 — state delete (LAST) |

D-06 order confirmed: backup → strip → file-delete → state-delete.

## UN-05 Source-Level Implementation Status

UN-05 is fully implemented at the source level. `scripts/uninstall.sh` now:

- Deletes `~/.claude/toolkit-install.json` at end of successful flow
- Strips `<!-- TOOLKIT-START --> ... <!-- TOOLKIT-END -->` blocks from `~/.claude/CLAUDE.md` when present (graceful no-op when absent — D-01)
- Verifies `superpowers` and `get-shit-done` plugin trees are byte-list-identical pre vs post
- All three operations are gated by the existing UN-06 idempotency guard at line 376 — no-op runs exit before any of this code executes

Plan 03 will add the integration test (`test-uninstall-state-cleanup.sh`) that exercises this path end-to-end with sentinel fixture and state-file deletion assertions.

## Deviations from Plan

None — plan executed exactly as written. The awk implementation in Task 1 followed the PLAN.md verbatim (lookahead-buffer variant) rather than the simpler PATTERNS.md skeleton, as specified in the plan's "awk implementation note."

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns beyond what the threat model in the plan already covers. T-19-02-03 (tempfile race) is mitigated by the RETURN-scoped trap on `sentinel-strip.XXXXXX`.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `scripts/uninstall.sh` exists | FOUND |
| `19-02-SUMMARY.md` exists | FOUND |
| Commit `454077b` (Task 1) | FOUND |
| Commit `d240429` (Task 2) | FOUND |
| Commit `a4fe61c` (Task 3) | FOUND |
| `strip_sentinel_block()` in uninstall.sh | FOUND |
| `rm -f "$STATE_FILE"` in uninstall.sh | FOUND |
| `diff -q "$SP_SNAP_TMP"` invariant in uninstall.sh | FOUND |
