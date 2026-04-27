---
phase: 21-sp-gsd-bootstrap-installer
plan: "01"
subsystem: bootstrap
tags: [bootstrap, shared-lib, constants, optional-plugins, shell]
dependency_graph:
  requires: []
  provides:
    - scripts/lib/bootstrap.sh (bootstrap_base_plugins entry point)
    - scripts/lib/optional-plugins.sh (TK_SP_INSTALL_CMD, TK_GSD_INSTALL_CMD constants)
  affects:
    - scripts/init-claude.sh (will source bootstrap.sh in plan 21-02)
    - scripts/init-local.sh (will source bootstrap.sh in plan 21-02)
tech_stack:
  added: []
  patterns:
    - guarded-constant [[ -z "${VAR:-}" ]] && VAR=... (optional-plugins.sh idiom)
    - TTY fail-closed read < /dev/tty with TK_BOOTSTRAP_TTY_SRC seam (uninstall.sh idiom)
    - non-fatal eval with rc capture (D-10 invariant)
    - private helper prefix (_bootstrap_*) for lib-internal functions
key_files:
  created:
    - scripts/lib/bootstrap.sh
  modified:
    - scripts/lib/optional-plugins.sh
decisions:
  - "Use guarded [[ -z ... ]] && form (not readonly) for TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD — matches color-guard idiom in the same file and allows test-seam override"
  - "Define _bootstrap_log_info / _bootstrap_log_warning locally in bootstrap.sh — lib/install.sh does NOT export log_* helpers (RESEARCH.md correction confirmed)"
  - "Comments in bootstrap.sh cause /dev/tty and TK_BOOTSTRAP_TTY_SRC grep counts > 1 — functionally correct, plan's acceptance criteria assumed no inline doc comments"
metrics:
  duration: 3m
  completed: "2026-04-27T07:27:24Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 21 Plan 01: Bootstrap Library Foundation Summary

**One-liner:** Guarded TK_SP/GSD_INSTALL_CMD constants in optional-plugins.sh + new bootstrap.sh library with TTY fail-closed prompts, idempotency probes, and non-fatal eval for upstream installer invocation.

## What Was Built

### Task 1 — Extract constants in `scripts/lib/optional-plugins.sh`

Added two guarded constants immediately after the existing color-guard block (line 14) and before `recommend_optional_plugins()`:

```bash
# Canonical SP/GSD install commands — single source of truth (D-12).
# Guards allow caller / test seam to override before sourcing.
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'
```

The `recommend_optional_plugins()` function's two Install echo lines now reference `${TK_SP_INSTALL_CMD}` and `${TK_GSD_INSTALL_CMD}` instead of literal strings. Canonical install strings appear exactly once in the file.

### Task 2 — Create `scripts/lib/bootstrap.sh`

New 99-line shared library exposing:

- `bootstrap_base_plugins()` — public entry point (called by installers)
- `_bootstrap_prompt_and_run()` — private helper for TTY prompt + eval
- `_bootstrap_log_info()` / `_bootstrap_log_warning()` — private log helpers

Key behavioral invariants implemented:

| Decision | Implementation |
|----------|---------------|
| D-04/D-05: Two [y/N] prompts, default N | `case "${choice:-N}" in y\|Y)` |
| D-06: Fail-closed on no TTY | `if ! read ... < "$tty_target" 2>/dev/null; then ... return 0` |
| D-08: SP idempotency | `[[ -d "$sp_dir" ]]` probe before prompt |
| D-08: GSD idempotency | `[[ -d "$gsd_dir" ]]` probe before prompt |
| D-09: Missing claude CLI → skip SP | `command -v claude` check with warn |
| D-10: Non-fatal upstream failure | `eval "$cmd" \|\| rc=$?` + warning log |
| D-12: Single source of truth | `sp_cmd="${TK_BOOTSTRAP_SP_CMD:-${TK_SP_INSTALL_CMD:-}}"` |
| D-16/D-17: Byte-quiet opt-out | `[[ "${TK_NO_BOOTSTRAP:-}" == "1" ]] && return 0` |
| D-19: Test seam | `TK_BOOTSTRAP_SP_CMD`, `TK_BOOTSTRAP_GSD_CMD`, `TK_BOOTSTRAP_TTY_SRC` |
| Shared-lib invariant | No `set -euo pipefail` in file |

## Verification Results

### Smoke Tests (all PASS)

```text
smoke1 PASS  — TK_NO_BOOTSTRAP=1 is byte-quiet (zero stderr output)
smoke2 PASS  — missing claude CLI emits "claude CLI not on PATH" warning
smoke3 PASS  — SP idempotency logs "superpowers already installed — skipping."
```

### Lint Gates

```text
PASS: bash -n scripts/lib/bootstrap.sh
PASS: bash -n scripts/lib/optional-plugins.sh
PASS: shellcheck -S warning scripts/lib/bootstrap.sh
PASS: shellcheck -S warning scripts/lib/optional-plugins.sh
PASS: make check (markdownlint + shellcheck + validate)
```

## Acceptance Criteria Status

### Task 1 (optional-plugins.sh)

| Check | Result |
|-------|--------|
| `bash -n` exits 0 | PASS |
| `TK_SP_INSTALL_CMD` guard appears once | PASS (grep -c = 1) |
| `TK_GSD_INSTALL_CMD` guard appears once | PASS (grep -c = 1) |
| Canonical SP string appears once in file | PASS (count = 1) |
| Canonical GSD string appears once in file | PASS (count = 1) |
| `${TK_SP_INSTALL_CMD}${NC}` in echo | PASS |
| `${TK_GSD_INSTALL_CMD}${NC}` in echo | PASS |
| Sourcing exposes `$TK_SP_INSTALL_CMD` | PASS |
| Sourcing exposes `$TK_GSD_INSTALL_CMD` | PASS |
| Override seam works (pre-set value preserved) | PASS |
| shellcheck -S warning exits 0 | PASS |
| `recommend_optional_plugins()` still exists | PASS |
| Function output contains both canonical strings | PASS |
| Line count 41±1 (actual: 42) | PASS |

### Task 2 (bootstrap.sh)

| Check | Result |
|-------|--------|
| File exists | PASS |
| First line is `#!/bin/bash` | PASS |
| `bash -n` exits 0 | PASS |
| shellcheck -S warning exits 0 | PASS |
| No `set -e`/`set -u`/`set -o pipefail` | PASS |
| `bootstrap_base_plugins()` defined once | PASS (count = 1) |
| `_bootstrap_prompt_and_run()` defined once | PASS (count = 1) |
| `/dev/tty` references: 2 (1 in comment, 1 functional) | PASS (functional ref correct) |
| `TK_BOOTSTRAP_TTY_SRC` references: 3 (2 in comments, 1 functional) | PASS (functional ref correct) |
| `# shellcheck disable=SC2294` above `eval "$cmd"` | PASS |
| SP fallback chain present | PASS |
| GSD fallback chain present | PASS |
| Both functions exposed after sourcing | PASS (wc -l = 2) |
| `TK_NO_BOOTSTRAP=1` is byte-quiet | PASS |
| Missing-claude warning fires correctly | PASS |
| Caller `set -euo pipefail` unaltered (3 opts still on) | PASS |
| Line count 70-105 (actual: 99) | PASS |

## RESEARCH.md Correction Noted

RESEARCH.md Pattern 1 and 21-CONTEXT.md code_context section stated that `lib/install.sh` defines `log_info` / `log_warning` helpers that `bootstrap.sh` should call. This was inaccurate (verified 2026-04-27). `bootstrap.sh` defines its own private `_bootstrap_log_info` / `_bootstrap_log_warning` helpers, matching the shape of `scripts/uninstall.sh:71-74` (the authoritative analog documented in 21-01-PLAN.md interfaces section).

## Deviations from Plan

### Minor — Comment lines cause reference count > 1 for /dev/tty and TK_BOOTSTRAP_TTY_SRC

The plan acceptance criteria specified grep count = 1 for both `/dev/tty` and `TK_BOOTSTRAP_TTY_SRC`. The plan's own code template includes a comment header (line 12) that references both — so the template itself would have produced count > 1. The functional code has exactly one `/dev/tty` assignment and one `TK_BOOTSTRAP_TTY_SRC` check. No behavioral deviation; doc comments are correct and helpful. The acceptance criterion wording was overly strict for a file with inline documentation.

No other deviations. Plan executed as written.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data flows introduced.

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns beyond what the plan's `<threat_model>` documents. `eval "$cmd"` risk accepted per T-21-01 (variables sourced only from hardcoded constants or test-harness seams, never user input). SC2294 disable comment documents this for future contributors.

## Self-Check: PASSED

All artifacts confirmed present and committed:

- `scripts/lib/bootstrap.sh` exists (commit 412ec9d, 99 lines)
- `scripts/lib/optional-plugins.sh` modified (commit 7bedc47)
- All three smoke tests print PASS
- `make check` exits 0
- All must_haves.truths verified in acceptance criteria table above
