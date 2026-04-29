---
phase: 30-install-time-ux
plan: "01"
subsystem: bridges
tags: [bridges, dispatch, helpers, ux, library]
dependency_graph:
  requires: [28-bridge-foundation, 29-sync-uninstall]
  provides: [bridge_install_prompts, _bridge_cli_version, _bridge_cli_label, _bridge_match, dispatch-order-extended]
  affects: [scripts/lib/bridges.sh, scripts/lib/dispatch.sh]
tech_stack:
  added: []
  patterns: [IFS-split-comma-list, fail-soft-version-probe, tty-source-test-seam, fail-closed-no-tty]
key_files:
  modified:
    - scripts/lib/bridges.sh
    - scripts/lib/dispatch.sh
decisions:
  - "bridge_install_prompts defaults Y at install-time (additive UX); bridge_prompt_drift defaults N (destructive — Phase 29 pattern)"
  - "_bridge_match uses IFS-split on comma with param-expansion whitespace trim for Bash 3.2 portability (no mapfile, no associative arrays)"
  - "bridge_install_prompts placed at END of bridges.sh after bridge_prompt_drift per plan spec; dispatch cases deferred to install.sh in Plan 30-02"
  - "BRIDGES_FORCE fail-fast second pass fires AFTER success loop so partial bridge set is created before exit-1"
metrics:
  duration_minutes: 12
  completed_date: "2026-04-29"
  tasks_completed: 4
  tasks_total: 4
  files_modified: 2
  assertions_passed: 99
  assertions_failed: 0
---

# Phase 30 Plan 01: Install-time UX Library Helpers Summary

Wave 1 library changes: 4 new functions in `scripts/lib/bridges.sh` (1 public + 3 internal) and `TK_DISPATCH_ORDER` extended from 6 to 8 elements in `scripts/lib/dispatch.sh`. All 99 baseline assertions across 4 hermetic test suites remain green.

## Net-New Functions in bridges.sh

| Function | Lines | Type | Purpose |
|---|---|---|---|
| `_bridge_cli_label` | 114–121 | internal | Maps `gemini`/`codex` to user-facing prompt string |
| `_bridge_cli_version` | 128–135 | internal | Fail-soft CLI version probe via `head -1` |
| `_bridge_match` | 141–157 | internal | Bash 3.2-portable comma-list membership test (IFS-split + param-expansion trim) |
| `bridge_install_prompts` | 558–631 | **public** | Install-time per-CLI prompt orchestrator for init-claude.sh / init-local.sh |

All three internal helpers are placed in the existing internal-helpers block, after `_bridge_global_dir()` (line 108). `bridge_install_prompts` is appended after `bridge_prompt_drift` at the end of the file.

## Diff Applied to dispatch.sh Lines 53-56

```text
- # Canonical install order — DISPATCH-01 contract.
+ # Canonical install order — DISPATCH-01 contract + BRIDGE-UX-01 (Phase 30) extension.
  # Guard uses the variable-is-unset-or-empty form to avoid nounset errors.
  if [[ -z "${TK_DISPATCH_ORDER[*]:-}" ]]; then
-     TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)
+     TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline gemini-bridge codex-bridge)
  fi
```

Array length: 6 → 8. `${TK_DISPATCH_ORDER[6]}` = `gemini-bridge`, `${TK_DISPATCH_ORDER[7]}` = `codex-bridge`.

## BACKCOMPAT-01 Evidence

All four hermetic test suites re-run after Tasks 1-3 with zero regressions:

| Suite | Expected | Actual | Result |
|---|---|---|---|
| `test-bootstrap.sh` | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| `test-install-tui.sh` | PASS=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| `test-bridges-foundation.sh` | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |
| `test-bridges-sync.sh` | PASS=25 FAIL=0 | PASS=25 FAIL=0 | PASS |

**Combined: 99 PASS, 0 FAIL.**

## No set -euo pipefail in Sourced Libs

```text
grep -c "set -euo pipefail" scripts/lib/bridges.sh  → 0 matches
grep -c "set -euo pipefail" scripts/lib/dispatch.sh → 0 matches
```

Both files remain sourced-lib safe. The IMPORTANT comment at bridges.sh:21 and dispatch.sh:24 explicitly document this invariant.

## shellcheck Results

```text
shellcheck -S warning scripts/lib/bridges.sh   → (no output — clean)
shellcheck -S warning scripts/lib/dispatch.sh  → (no output — clean)
```

## File Ownership

This plan owns **only** `scripts/lib/bridges.sh` and `scripts/lib/dispatch.sh`.

- `scripts/install.sh` — untouched (Plan 30-02 owns TUI row extension + dispatch cases)
- `scripts/init-claude.sh` — untouched (Plan 30-03 owns argv parsing + bridge_install_prompts call)
- `scripts/init-local.sh` — untouched (Plan 30-03 owns argv parsing + bridge_install_prompts call)

## Commits

| Hash | Message |
|---|---|
| `b876d09` | feat(bridges): add _bridge_cli_version, _bridge_cli_label, _bridge_match helpers |
| `bcef08d` | feat(bridges): add bridge_install_prompts orchestrator (BRIDGE-UX-02) |
| `1fbca48` | feat(dispatch): append gemini-bridge + codex-bridge to TK_DISPATCH_ORDER |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `scripts/lib/bridges.sh` exists and defines all 4 new functions: FOUND
- `scripts/lib/dispatch.sh` has `gemini-bridge codex-bridge` at indices 6 and 7: FOUND
- Commits b876d09, bcef08d, 1fbca48: FOUND
- shellcheck clean: CONFIRMED
- No `set -euo pipefail` in either sourced lib: CONFIRMED
- All 99 baseline assertions green: CONFIRMED
