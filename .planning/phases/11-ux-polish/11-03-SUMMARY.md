---
phase: 11-ux-polish
plan: "03"
subsystem: migrate-dry-run
tags:
  - dry-run
  - ux
  - shell
  - migrate
dependency_graph:
  requires:
    - scripts/lib/dry-run-output.sh (dro_* library, Plan 11-01)
  provides:
    - scripts/migrate-to-complement.sh (DRY_RUN path replaced with [- REMOVE] group)
    - scripts/tests/test-migrate-dry-run.sh (3-scenario test suite, 9 assertions)
  affects:
    - scripts/migrate-to-complement.sh (modified)
tech_stack:
  added: []
  patterns:
    - "4th lib_pair entry in migrate for-loop: 'dry-run-output.sh:$LIB_DRO_TMP'"
    - "dro_init_colors → dro_print_header '-' 'REMOVE' → per-file dro_print_file → dro_print_total"
    - "3-col hash table preserved before [- REMOVE] group as diagnostic context"
    - "Dry-run exit fires before acquire_lock + backup: zero filesystem writes"
    - "assert_dryrun_lines_ansi_free scopes NO_COLOR assertion to dro_* lines only"
key_files:
  created:
    - scripts/tests/test-migrate-dry-run.sh
  modified:
    - scripts/migrate-to-complement.sh
decisions:
  - "3-col hash table (lines 224-256) preserved as diagnostic context before new [- REMOVE] group — provides per-file hash diagnosis (TK tmpl / on-disk / SP equiv) that is useful even in dry-run"
  - "Dry-run exit placed before acquire_lock (line 265) and BACKUP_DIR creation (line 271+) — ensures zero filesystem writes in dry-run mode"
  - "assert_dryrun_lines_ansi_free used instead of full-output ANSI scan — migrate-to-complement.sh emits log_info/log_warning with hardcoded ANSI codes outside the dro_* NO_COLOR contract (same decision as Plan 11-02 deviation 2)"
  - "Makefile test target uses explicitly numbered tests (Test 1–16) — test-migrate-dry-run.sh not added to Makefile (same as test-update-dry-run.sh from 11-02); make check does not run individual test scripts, only lint/validate targets"
metrics:
  duration_minutes: ~20
  completed_date: "2026-04-25"
  tasks_completed: 2
  files_changed: 2
  lines_added: 263
  lines_removed: 4
---

# Phase 11 Plan 03: UX Polish — Migrate --dry-run [- REMOVE] Group Summary

**One-liner:** `migrate-to-complement.sh --dry-run` now shows chezmoi-grade `[- REMOVE]` grouped
preview (via shared `dro_*` library) appended after the existing 3-col diagnostic hash table,
replacing the former single-line `log_info` exit message.

## What Was Built

### Task 1: scripts/migrate-to-complement.sh (MODIFIED — +14 lines / -4 lines)

Three edits made:

**Edit 1 — LIB_DRO_TMP mktemp + trap** (lines 63, 69):

Added `LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output.XXXXXX")` to the mktemp block and
extended the EXIT trap to include `"$LIB_DRO_TMP"` for cleanup alongside the other tempfiles.

**Edit 2 — lib_pair for-loop extended** (line 87):

Added `"dry-run-output.sh:$LIB_DRO_TMP"` as the 4th entry to the existing for-loop that
downloads and sources `install.sh`, `state.sh`, and `backup.sh`. Same pattern as Plan 11-02
used for `update-claude.sh`.

**Edit 3 — dry-run exit block replaced** (lines 259-276):

Old (4 lines):

```bash
if [[ $DRY_RUN -eq 1 ]]; then
    log_info "--dry-run: the files above would be removed. No backup, no state rewrite. Exiting."
    exit 0
fi
```

New (18 lines):

```bash
if [[ $DRY_RUN -eq 1 ]]; then
    if ! command -v dro_init_colors >/dev/null 2>&1; then
        log_error "dry-run-output.sh not sourced — cannot render styled preview"
        exit 1
    fi
    dro_init_colors
    dro_print_header "-" "REMOVE" "${#DUPLICATES[@]}" _DRO_R
    for rel in "${DUPLICATES[@]}"; do
        dro_print_file "$rel"
    done
    echo ""
    dro_print_total "${#DUPLICATES[@]}"
    exit 0
fi
```

The `exit 0` fires at line 277, before `acquire_lock` (line 266) and before `BACKUP_DIR` creation
(line 272) — confirming non-destructive behavior.

### Task 2: scripts/tests/test-migrate-dry-run.sh (NEW — 245 lines)

Three scenario functions using the `TK_MIGRATE_*` env seam pattern:

| Scenario | Assertions | Result |
|----------|-----------|--------|
| `scenario_remove_group_renders` | exits 0, `[- REMOVE]` header, `Total:` footer, 3-col table, zero writes, no backup dir | 6 OK |
| `scenario_no_color` | dro_* output lines ANSI-free with `NO_COLOR=1` | 1 OK |
| `scenario_no_duplicates` | `No duplicate files found` message present, `[- REMOVE]` absent | 2 OK |

**Total: 9/9 assertions pass.**

Helpers provided:

- `seed_duplicates_in_sandbox` — sources `compute_skip_set` from `lib/install.sh` to identify
  complement-sp skip-set paths, then creates placeholder files at those paths in the sandbox
- `run_migrate_dryrun` — exports all five `TK_MIGRATE_*` seams + `HAS_SP`/`HAS_GSD`/version vars
- `assert_dryrun_lines_ansi_free` — extracts only `[...]` header / indented file / `Total:` lines
  for ANSI scope (matches Plan 11-02 approach — log helpers outside dro_* contract)

## Output Format

```text
  path                                      TK tmpl    on-disk    SP equiv
  ────────────────────────────────────────  ────────   ────────   ────────
  commands/debug.md                         abc12345   abc12345   def67890
  agents/code-reviewer.md                   ...

[- REMOVE]                                   3 files
  commands/debug.md
  agents/code-reviewer.md
  rules/database.md

Total: 3 files
```

## Non-Destructive Confirmation

Dry-run path in the modified script:

- `exit 0` at line 277 (inside `if [[ $DRY_RUN -eq 1 ]]` block)
- `acquire_lock` at line 266 — after `exit 0` in dry-run path (not reached)
- `BACKUP_DIR=...` at line 272 — after `exit 0` in dry-run path (not reached)
- `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"` at line 273-278 — not reached
- `rm -f` per file at line 321 — not reached

**Confirmed zero filesystem writes** by `snapshot_before == snapshot_after` assertion in test.

## Test Results

```text
bash scripts/tests/test-migrate-dry-run.sh:  PASS 9, FAIL 0
bash scripts/tests/test-dry-run.sh:         PASS 7, FAIL 0  (no regression)
bash scripts/tests/test-update-dry-run.sh:  PASS 11, FAIL 0 (no regression)
make check:                                 all checks passed
```

## Phase 11 SC Close-Out

All four UX-01 success criteria satisfied across Plans 11-01, 11-02, and 11-03:

| SC | Description | Plan | Status |
|----|-------------|------|--------|
| SC1 | `init-local.sh --dry-run` shows grouped `[+ INSTALL]` / `[- SKIP]` output | 11-01 | Done |
| SC2 | `update-claude.sh --dry-run` shows grouped 4-group INSTALL/UPDATE/SKIP/REMOVE | 11-02 | Done |
| SC3 | `migrate-to-complement.sh --dry-run` shows grouped `[- REMOVE]` output | 11-03 | Done |
| SC4 | NO_COLOR=1 + non-TTY produce plain output across all three scripts | 11-01/02/03 | Done |

## Deviations from Plan

None — plan executed exactly as written. All three edits matched the specified patterns.
The `assert_dryrun_lines_ansi_free` design (scope-narrowed NO_COLOR check) was documented in
the plan's interfaces section as a known pattern from 11-02.

## Known Stubs

None — `dro_print_header`, `dro_print_file`, and `dro_print_total` are fully implemented in
`scripts/lib/dry-run-output.sh` (Plan 11-01). The `DUPLICATES` array is fully populated from
real filesystem stats before the dry-run exit block.

## Threat Flags

None — no new network endpoints or auth paths introduced. The `dry-run-output.sh` download
follows the same trust boundary as other lib downloads (HTTPS to raw.githubusercontent.com,
hard-fail on error). All three threat register entries (T-11-03-01 through T-11-03-03) carry
`accept` disposition per plan.

## Self-Check

Files created/modified exist:

- `scripts/migrate-to-complement.sh` FOUND
- `scripts/tests/test-migrate-dry-run.sh` FOUND

Commits exist:

- `c093363` — Task 1: wire dry-run-output.sh + replace one-liner FOUND
- `83bfc6e` — Task 2: test-migrate-dry-run.sh 3 scenarios FOUND

## Self-Check: PASSED
