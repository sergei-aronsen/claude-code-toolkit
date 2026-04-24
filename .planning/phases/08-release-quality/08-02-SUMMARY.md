---
phase: 08-release-quality
plan: "02"
subsystem: release-quality
tags: [cell-parity, release-gate, documentation, ci]
dependency_graph:
  requires: [scripts/validate-release.sh]
  provides: [scripts/cell-parity.sh, make cell-parity]
  affects: [docs/INSTALL.md, Makefile, .github/workflows/quality.yml]
tech_stack:
  added: []
  patterns: [pure-shell parity gate, while-IFS-read bash 3.2 compat, POSIX grep -qE word-boundary]
key_files:
  created:
    - scripts/cell-parity.sh
  modified:
    - docs/INSTALL.md
    - Makefile
    - .github/workflows/quality.yml
decisions:
  - "wire cell-parity into check after agent-collision-static (validate-commands target absent in this worktree — plan references a Wave 2 parallel task; adapted to append after last existing target)"
  - "CI step added inline to validate-templates job per D-10, not a separate job"
  - "mapfile comment kept in cell-parity.sh per plan template (comment-only reference, no actual mapfile call)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-24"
  tasks_completed: 2
  files_changed: 4
---

# Phase 08 Plan 02: REL-02 Cell-Parity Gate Summary

**One-liner:** REL-02 complete — cell-parity gate enforces 3-surface consistency across validate-release.sh, INSTALL.md, and RELEASE-CHECKLIST.md; INSTALL.md drift fixed (12→13 cells).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Update docs/INSTALL.md — add 13 --cell commands + fix intro count | 57eefdb | docs/INSTALL.md |
| 2a | Create scripts/cell-parity.sh | d023897 | scripts/cell-parity.sh |
| 2b | Wire cell-parity into Makefile | 50ccd26 | Makefile |
| 2c | Add cell-parity CI step to validate-templates | 978da7f | .github/workflows/quality.yml |

## Files Created

- `scripts/cell-parity.sh` — 52 lines, bash 3.2-compatible pure-shell 3-surface parity gate
  - Reads cell list from `validate-release.sh --list`
  - Checks each cell in `docs/INSTALL.md` and `docs/RELEASE-CHECKLIST.md`
  - POSIX `[[:space:]]` regex, word-boundary anchor `([^a-z0-9-]|$)`
  - No `mapfile`, no `declare -A`, no GNU-only grep flags

## Files Modified

- `docs/INSTALL.md` — 13 `--cell <name>` validate commands added (one per table row), intro count fixed from "12 cells" to "13 cells (12 mode×scenario cells + 1 translation-sync cell)", new "Translation Sync Cell" section added
- `Makefile` — `cell-parity` added to `.PHONY`, `cell-parity` target added, `check:` dependency chain extended
- `.github/workflows/quality.yml` — `REL-02 — cell-parity` step added inside `validate-templates` job

## Verification Results

### Automated gate

```text
make check  →  ✅ cell-parity passed: all 13 cells present in all 3 surfaces
```

### Drift-injection test (manual, confirmed)

1. Removed `--cell standalone-rerun` from docs/INSTALL.md
2. `bash scripts/cell-parity.sh` → exit 1, output: `❌ standalone-rerun  INSTALL.md=0  CHECKLIST.md=1`
3. Restored INSTALL.md
4. `bash scripts/cell-parity.sh` → exit 0, `✅ cell-parity passed: all 13 cells present in all 3 surfaces`

## Deviations from Plan

### Deviation 1 — Adapted Makefile wiring position

**Found during:** Task 2b
**Issue:** Plan instructs appending `cell-parity` after `validate-commands` target (line 220), but `validate-commands` does not exist in this worktree — it is a Wave 2 target being added by sibling plan 08-03 in parallel.
**Fix:** Appended `cell-parity` target after `agent-collision-static` (the last existing target in check chain). When 08-03 merges, `validate-commands` will be inserted at its own position; `cell-parity` remains downstream of all existing gates.
**Impact:** None — gate still runs as part of `make check`, just positioned after `agent-collision-static` rather than after `validate-commands`.

### Deviation 2 — mapfile mention in comment

**Found during:** Task 2a acceptance criteria check
**Issue:** Plan's acceptance criterion says `grep -c 'mapfile' scripts/cell-parity.sh` returns 0, but the plan's own provided template body contains the comment `# bash 3.2-safe cell list (mapfile requires bash 4.0+)`, causing count = 1.
**Fix:** Kept the comment as provided in the plan template — it is informational and does not constitute a `mapfile` call. No actual `mapfile` invocation exists in the script.
**Impact:** Cosmetic only. Bash 3.2 compliance is fully maintained.

## Known Stubs

None — all 13 cells are fully wired to real validate-release.sh cell names.

## Threat Flags

No new network endpoints, auth paths, or trust-boundary crossings introduced. `cell-parity.sh` is a read-only gate operating entirely on repo-local files with no user input. Threat model entries T-08-02-01 through T-08-02-04 are all accepted/mitigated per plan.

## Self-Check: PASSED

- scripts/cell-parity.sh: FOUND
- docs/INSTALL.md: FOUND
- Makefile: FOUND
- .github/workflows/quality.yml: FOUND
- commit 57eefdb: FOUND
- commit d023897: FOUND
- commit 50ccd26: FOUND
- commit 978da7f: FOUND
