---
phase: 11-ux-polish
plan: "01"
subsystem: dry-run-output
tags:
  - dry-run
  - ux
  - shell
  - shared-lib
  - no-color
dependency_graph:
  requires: []
  provides:
    - scripts/lib/dry-run-output.sh (dro_* function library)
  affects:
    - scripts/lib/install.sh (print_dry_run_grouped refactored)
    - scripts/init-claude.sh (downloads + sources dry-run-output.sh)
    - scripts/init-local.sh (sources dry-run-output.sh locally)
    - scripts/tests/test-dry-run.sh (assertions updated)
tech_stack:
  added:
    - "scripts/lib/dry-run-output.sh: new sourced bash library"
  patterns:
    - "Two-pass collect-then-print grouped output (arrays first, headers second)"
    - "NO_COLOR + TTY combined gate via ${NO_COLOR+x} presence test"
    - "printf %b color wraps entire line to avoid %-Ns byte-count inflation"
    - "Indirect eval expansion for color-var-name args (bash 3.2 compatible)"
key_files:
  created:
    - scripts/lib/dry-run-output.sh
  modified:
    - scripts/lib/install.sh
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/tests/test-dry-run.sh
decisions:
  - "Decision A3 locked: single shared lib (dry-run-output.sh) used by all three install scripts; plans 11-02 and 11-03 will source it"
  - "Two-pass strategy in print_dry_run_grouped: collect all entries into arrays, then print grouped sections with headers"
  - "[SKIP regex updated from prefix-match \\[SKIP to exact \\[- SKIP\\] — old format was [SKIP - conflicts_with:...], new is [- SKIP] header"
metrics:
  duration_minutes: ~30
  completed_date: "2026-04-25"
  tasks_completed: 2
  files_changed: 5
  lines_added: 148
  lines_removed: 27
---

# Phase 11 Plan 01: UX Polish — Shared Dry-Run Output Library Summary

**One-liner:** Chezmoi-grade grouped `--dry-run` output via new `scripts/lib/dry-run-output.sh`
shared bash library with NO_COLOR + TTY gating, replacing interleaved `[INSTALL]`/`[SKIP]` lines
with grouped `[+ INSTALL]` / `[- SKIP]` sections and right-aligned counts.

## What Was Built

### Task 1: scripts/lib/dry-run-output.sh (NEW — 72 lines)

A sourced bash library exposing four functions:

- `dro_init_colors()` — sets `_DRO_G/_DRO_C/_DRO_Y/_DRO_R/_DRO_NC` with combined NO_COLOR +
  TTY gate. Uses `${NO_COLOR+x}` presence test (not `$NO_COLOR` which fails under `set -u`,
  not `${NO_COLOR:-}` which conflates unset with empty per no-color.org).
- `dro_print_header <marker> <label> <count> <color_var>` — fixed 44-col label + 6-col
  right-aligned count. Color wraps the entire line via `%b` to prevent ANSI bytes inflating
  `%-44s` padding (RESEARCH.md Pitfall 6).
- `dro_print_file <filepath>` — 2-space indented file line, no color.
- `dro_print_total <count>` — `Total: N files` footer preserving existing `^Total:` test contract.

Sourced-lib invariant honored: no `set -e`/`-u`/`-o pipefail` at file level.

### Task 2: Refactor + Wire

**scripts/lib/install.sh** — `print_dry_run_grouped` refactored from single-pass interleaved
printing to two-pass strategy: first pass collects into `INSTALL_PATHS[]` and `SKIP_PATHS[]`
arrays, second pass calls `dro_print_header` / `dro_print_file` / `dro_print_total`. Old inline
`printf '%b[INSTALL]%b %s/%s\n'` format removed.

**scripts/init-claude.sh** — Added `LIB_DRO_TMP` mktemp + curl fetch of
`scripts/lib/dry-run-output.sh` + `source "$LIB_DRO_TMP"` + updated all 4 EXIT trap lines to
include `"$LIB_DRO_TMP"` for cleanup (7 occurrences total).

**scripts/init-local.sh** — Added `source "$SCRIPT_DIR/lib/dry-run-output.sh"` alongside
`lib/install.sh` (required for tests — Rule 3 auto-fix).

**scripts/tests/test-dry-run.sh** — Three assertion updates:
1. `\[INSTALL\]` → `\[\+ INSTALL\]` (format changed)
2. `\[SKIP` → `\[- SKIP\]` (old format was `[SKIP - conflicts_with:...]`, new is `[- SKIP]` header)
3. New NO_COLOR=1 assertion block added before Results footer

## Test Results

Before refactor (baseline from RESEARCH.md): 4 assertions, format was interleaved lines.

After refactor: **7/7 assertions pass** including:

- `init-local.sh --dry-run exits 0` ✓
- `zero filesystem writes (snapshot identical)` ✓
- `[+ INSTALL] present` ✓
- `[- SKIP] present` ✓
- `^Total: footer present` ✓
- `ANSI-clean when non-TTY` ✓
- `NO_COLOR=1: ANSI-clean` ✓

`make check` (shellcheck + markdownlint + validate): all green.

## Output Format

```text
[+ INSTALL]                                     47 files
  agents/agents/planner.md
  agents/agents/security-auditor.md
  ...

[- SKIP]                                         7 files
  commands/commands/debug.md  (conflicts_with:superpowers)
  commands/commands/plan.md  (conflicts_with:superpowers)
  ...

Total: 54 files
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] scripts/init-local.sh missing dry-run-output.sh source**

- **Found during:** Task 2 test run — `bash scripts/tests/test-dry-run.sh` failed with
  `ERROR: dry-run-output.sh not sourced — print_dry_run_grouped cannot render`
- **Issue:** Plan specified wiring for `init-claude.sh` (remote curl-based) but omitted
  `init-local.sh` (local-path-based), which is what `test-dry-run.sh` actually invokes.
- **Fix:** Added `source "$SCRIPT_DIR/lib/dry-run-output.sh"` between `lib/install.sh` and
  `lib/state.sh` sources in `init-local.sh`
- **Files modified:** `scripts/init-local.sh`
- **Commit:** c55304e

**2. [Rule 1 - Bug] `\[SKIP` regex no longer matches new `[- SKIP]` format**

- **Found during:** Task 2 test run — 6/7 passing, SKIP assertion failed
- **Issue:** Plan correctly updated `[INSTALL]` → `[+ INSTALL]` regex but the RESEARCH.md
  noted `\[SKIP` "SURVIVES (prefix match)" — true for old `[SKIP - conflicts_with:]` format,
  but NOT for new grouped header `[- SKIP]` where SKIP does not immediately follow `[`
- **Fix:** Updated assertion from `grep -qE '\[SKIP'` to `grep -qE '\[- SKIP\]'`
- **Files modified:** `scripts/tests/test-dry-run.sh`
- **Commit:** c55304e

## ANSI Escape Verification

| Scenario | Result |
|----------|--------|
| Non-TTY (stdout redirected to file) | Zero ANSI escapes ✓ |
| NO_COLOR=1 (any TTY state) | Zero ANSI escapes ✓ |
| TTY without NO_COLOR | Colors enabled (manual smoke test confirms `\033[0;32m`) |

## Branch

`feature/ux-01-shared-lib-init`

## Sourced-lib Invariant Confirmation

`scripts/lib/dry-run-output.sh` contains zero occurrences of `set -e`, `set -u`,
`set -eu`, `set -euo`, or `set -o pipefail` at file level. Verified by:

```bash
! grep -qE '^\s*set -(e|u|eu|euo|o pipefail)' scripts/lib/dry-run-output.sh
```

## Known Stubs

None — all functions are fully implemented and wired. No placeholder data flows to output.

## Threat Flags

None — no new network endpoints or auth paths introduced. The `dry-run-output.sh` download
follows the same trust boundary as existing `lib/install.sh` and `lib/backup.sh` (HTTPS to
raw.githubusercontent.com, hard-fail on download error). T-11-01-02 (NO_COLOR injection)
mitigated by presence-test `${NO_COLOR+x}` — value never evaluated as code.

## Self-Check

Files created/modified exist:

- `scripts/lib/dry-run-output.sh` ✓
- `scripts/lib/install.sh` ✓
- `scripts/init-claude.sh` ✓
- `scripts/init-local.sh` ✓
- `scripts/tests/test-dry-run.sh` ✓

Commits exist:

- `f1a1511` — Task 1: dry-run-output.sh + test regex update ✓
- `c55304e` — Task 2: refactor + wire + auto-fixes ✓
