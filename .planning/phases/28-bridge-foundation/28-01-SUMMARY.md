---
phase: 28-bridge-foundation
plan: "01"
subsystem: detection
tags: [detect2, bridge, gemini, codex, BRIDGE-DET-01, BRIDGE-DET-02, BRIDGE-DET-03]
dependency_graph:
  requires: []
  provides: [is_gemini_installed, is_codex_installed, IS_GEM, IS_COD]
  affects: [scripts/lib/detect2.sh]
tech_stack:
  added: []
  patterns: [Shape-A-single-command-v-probe, detect2_cache-IS-*-vars]
key_files:
  modified:
    - scripts/lib/detect2.sh
decisions:
  - "Inserted both new probes before is_gsd_installed (strict lex order: codex < gemini < gsd)"
  - "detect2_cache IS_COD/IS_GEM appended after IS_SL to preserve existing line ordering"
  - "Header Exposes block updated to alphabetical order by function name"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-29"
  tasks_completed: 2
  files_modified: 1
---

# Phase 28 Plan 01: detect2 Bridge Probes Summary

**One-liner:** Added `is_codex_installed` and `is_gemini_installed` binary probes to `detect2.sh` with IS_COD/IS_GEM cache vars, following the Shape-A `command -v` pattern.

## Tasks Completed

| # | Title | Commit |
|---|-------|--------|
| 1 | Add is_codex_installed and is_gemini_installed probes to detect2.sh | 66a5b95 |
| 2 | Verify detect2 backcompat — existing test-install-tui.sh PASS=43 unchanged | (read-only gate, no commit) |

## Files Modified

| File | Lines Before | Lines After | Delta |
|------|-------------|-------------|-------|
| `scripts/lib/detect2.sh` | 93 | 111 | +18 (+25 raw, -7 comment rewrite) |

## New Probe Locations (file:line after edit)

- `is_codex_installed()` — inserted at line 46 (before `is_gsd_installed`)
- `is_gemini_installed()` — inserted at line 53 (after `is_codex_installed`, before `is_gsd_installed`)
- `IS_COD=0; is_codex_installed` — line 107 in `detect2_cache`
- `IS_GEM=0; is_gemini_installed` — line 108 in `detect2_cache`
- `export IS_SP ... IS_COD IS_GEM` — line 109

## Verification Results

### Task 1 Acceptance Criteria

| Check | Result |
|-------|--------|
| `grep -c '^is_codex_installed()'` returns 1 | PASS |
| `grep -c '^is_gemini_installed()'` returns 1 | PASS |
| `command -v codex >/dev/null 2>&1` present | PASS |
| `command -v gemini >/dev/null 2>&1` present | PASS |
| `IS_COD=0; is_codex_installed` in detect2_cache | PASS |
| `IS_GEM=0; is_gemini_installed` in detect2_cache | PASS |
| export line includes IS_COD IS_GEM | PASS |
| No `set -euo pipefail` in file | PASS |
| Both functions defined after source | PASS |
| `is_gemini_installed` returns 0 or 1 (no stderr) | PASS (0 — gemini on PATH) |
| `is_codex_installed` returns 0 or 1 (no stderr) | PASS (0 — codex on PATH) |
| Clean PATH: `is_gemini_installed` returns 1 | PASS |
| Clean PATH: `is_codex_installed` returns 1 | PASS |
| `shellcheck -S warning` exits 0 | PASS |

### Task 2 — BACKCOMPAT-01 Gate

```
test-install-tui complete: PASS=43 FAIL=0
```

PASS count: 43 (matches v4.6 baseline exactly). FAIL=0. Gate PASSED.

## Acceptance Criteria Coverage

- BRIDGE-DET-01: `is_gemini_installed` defined, returns 0/1, no stderr — PASS
- BRIDGE-DET-02: `is_codex_installed` defined, returns 0/1, no stderr — PASS
- BRIDGE-DET-03: Both probes in `detect2_cache`, IS_COD/IS_GEM exported, test-install-tui PASS=43 — PASS
- shellcheck warning-level clean — PASS
- No `set -e` directive added — PASS
- "No errexit/nounset/pipefail here" comment preserved at line 18 — PASS

## Deviations from Plan

None — plan executed exactly as written.

**Alphabetical insertion note:** The plan's action block contained an internal deliberation about lex ordering. The correct resolution (codex < gemini < gsd, both inserted before `is_gsd_installed`) was applied as specified in the final CORRECT INSERTION section. The PATTERNS.md note that "gemini inserts between gsd and rtk" was overridden by the plan's own D-22/CONTEXT.md locked decision, which correctly places gemini before gsd (ge < gs lexicographically).

## Self-Check

- `scripts/lib/detect2.sh` exists and contains both new functions: CONFIRMED
- Commit 66a5b95 exists: CONFIRMED
- BACKCOMPAT-01 gate (PASS=43 FAIL=0): CONFIRMED
- shellcheck clean: CONFIRMED

## Self-Check: PASSED
