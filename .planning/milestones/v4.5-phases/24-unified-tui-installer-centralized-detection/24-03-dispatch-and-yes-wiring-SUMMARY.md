---
phase: 24
plan: 03
subsystem: dispatch
tags: [bash, dispatch, lib, phase-24]
completed: "2026-04-29T10:57:29Z"

dependency_graph:
  requires:
    - phase: 24-01
      provides: scripts/lib/detect2.sh
    - phase: 24-02
      provides: scripts/lib/tui.sh
  provides:
    - scripts/lib/dispatch.sh (dispatch_superpowers, dispatch_gsd, dispatch_toolkit, dispatch_security, dispatch_rtk, dispatch_statusline, TK_DISPATCH_ORDER)
    - scripts/setup-security.sh (--yes flag accepted, DISPATCH-02)
    - scripts/install-statusline.sh (--yes flag accepted as no-op, DISPATCH-02)
  affects:
    - plans/24-04 (install.sh sources dispatch.sh; iterates TK_DISPATCH_ORDER to dispatch components)

tech_stack:
  added: []
  patterns:
    - sourced-lib header with color guards (no errexit)
    - TK_DISPATCH_OVERRIDE_<NAME> test seam (mirrors v4.4 TK_BOOTSTRAP_SP_CMD shape)
    - curl-pipe vs local detection via BASH_SOURCE[0]/dev/fd/* || $0==bash (D-24)
    - dispatch_rtk </dev/null pipe to handle rtk init -g interactivity (RESEARCH §10 Risk 8)
    - parse-and-store --yes no-op pattern for DISPATCH-02 symmetry
    - : "${YES}" shellcheck SC2034 silencer

key_files:
  created:
    - scripts/lib/dispatch.sh
  modified:
    - scripts/setup-security.sh
    - scripts/install-statusline.sh

decisions:
  - "D-24: curl-pipe detection via BASH_SOURCE[0]==/dev/fd/* || $0==bash; local mode resolves sibling via dirname BASH_SOURCE"
  - "D-25: dispatcher contract dispatch_<name> [--force] [--dry-run] [--yes]; each returns underlying exit code unchanged"
  - "D-26: setup-security.sh learns active --yes (gates future read prompts); install-statusline.sh learns --yes as accepted no-op"
  - "D-04: TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD reused from optional-plugins.sh, not redefined"
  - "TK_DISPATCH_ORDER unset-guard uses [[ -z ... :-]] form rather than ${#arr[@]} to avoid nounset errors when caller has set -u"

metrics:
  duration: "~4 minutes"
  completed: "2026-04-29"
  tasks_completed: 4
  files_created: 1
  files_modified: 2
---

# Phase 24 Plan 03: Dispatch and --yes Wiring Summary

**One-liner:** Six per-component dispatcher functions in a sourced lib with TK_DISPATCH_OVERRIDE test seams, curl-pipe/local detection, and `--yes` flag wired into setup-security.sh + install-statusline.sh.

## What Was Built

### `scripts/lib/dispatch.sh` — Per-Component Dispatcher Library (new, DISPATCH-01)

New sourced library (no `set -euo pipefail`) that:

- Defines `TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)` — canonical install order (DISPATCH-01)
- Exposes six dispatcher functions, each accepting `[--force] [--dry-run] [--yes]`:
  - `dispatch_superpowers` — `eval "$TK_SP_INSTALL_CMD"` (reuses D-04 constant)
  - `dispatch_gsd` — `eval "$TK_GSD_INSTALL_CMD"` (reuses D-04 constant)
  - `dispatch_toolkit` — `bash <(curl -sSL .../init-claude.sh)` or local sibling (D-24)
  - `dispatch_security` — `bash <(curl -sSL .../setup-security.sh)` with `--yes`/`--force` pass-through
  - `dispatch_rtk` — `brew install rtk && rtk init -g </dev/null` (RESEARCH §10 Risk 8 mitigation)
  - `dispatch_statusline` — `bash <(curl -sSL .../install-statusline.sh)` with `--yes` pass-through
- `TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>` test seam for all six (mirrors v4.4 `TK_BOOTSTRAP_SP_CMD`)
- `_dispatch_is_curl_pipe` helper for D-24 curl-pipe vs local detection
- `_dispatch_sibling_path` helper resolves `scripts/lib/../<sibling>.sh` for local invocation

### `scripts/setup-security.sh` — `--yes` flag added (DISPATCH-02)

- `while [[ $# -gt 0 ]]` + `shift` argument loop inserted after color constants, before `REPO_URL`
- `YES=0` declaration; `--yes) YES=1 ;;` case branch
- Unknown flags warn with `${YELLOW}⚠${NC} unknown flag: $1 (ignoring)` — not fatal
- `: "${YES}"` SC2034 silencer — future interactive prompts guard with `[[ "$YES" -eq 1 ]]`

### `scripts/install-statusline.sh` — `--yes` no-op flag added (DISPATCH-02)

- `for _arg in "$@"` loop (simpler parse-only form for a script with no flag pass-through needs)
- Same `YES=0` / `--yes) YES=1` / `: "${YES}"` pattern as setup-security.sh
- macOS check at `if [[ "$(uname)" != "Darwin" ]]` runs after the argument loop (correct — `--yes` does not bypass platform check)

## Verification Results

```text
shellcheck -S warning: PASS on all 3 files
source dispatch.sh under set -euo pipefail: loaded-clean
all-six-dispatchers-and-order-ok
all-six-dry-run-ok (each prints [+ INSTALL] line)
override-seam-ok (TK_DISPATCH_OVERRIDE_TOOLKIT mock invoked correctly)
setup-security-yes-ok (YES=1 confirmed via head-extract test)
Bootstrap test complete: PASS=26 FAIL=0  (BACKCOMPAT-01 invariant preserved)
```

## Public API Contract

```text
TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline)

dispatch_<name> [--force] [--dry-run] [--yes]
  --dry-run  : prints "[+ INSTALL] <name> (would run: <cmd>)", returns 0, no exec
  --force    : passed through to underlying script (toolkit, security)
  --yes      : passed through to setup-security.sh and install-statusline.sh

Test seam: TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>=<path>
  When set, dispatcher execs bash <path> [parsed-flags] instead of real installer
  Uppercase mapping: superpowers→SUPERPOWERS, gsd→GSD, toolkit→TOOLKIT,
                     security→SECURITY, rtk→RTK, statusline→STATUSLINE
```

## Decisions Implemented

| Decision | Description |
|----------|-------------|
| D-04 | TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD reused from optional-plugins.sh |
| D-24 | Curl-pipe detection via `BASH_SOURCE[0]==/dev/fd/*` or `$0==bash` |
| D-25 | Dispatcher contract: each accepts --force/--dry-run/--yes; returns exit code unchanged |
| D-26 | setup-security.sh: active --yes (future read guards); install-statusline.sh: --yes no-op |

## Requirements Addressed

| REQ-ID | Description | Status |
|--------|-------------|--------|
| DISPATCH-01 | Six dispatchers + TK_DISPATCH_ORDER canonical order constant | Done |
| DISPATCH-02 | --yes flag accepted by setup-security.sh (active) and install-statusline.sh (no-op) | Done |

## Downstream Contract

- Plan 24-04 (`install.sh`) sources `scripts/lib/dispatch.sh`, iterates `TK_DISPATCH_ORDER`, calls `dispatch_<name>` for each user-selected component
- `TK_DISPATCH_OVERRIDE_<NAME>` enables hermetic test isolation in `test-install-tui.sh` (Plan 04)
- `setup-security.sh` and `install-statusline.sh` both accept `--yes` — dispatcher can pass the flag through uniformly without per-script special-casing

## Commit

`cf0536b` — feat(24): add lib/dispatch.sh + --yes flag wiring (DISPATCH-01..02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TK_DISPATCH_ORDER unset-guard uses `:-` form instead of `${#arr[@]}`**

- **Found during:** Task 1 verification
- **Issue:** `if [[ "${#TK_DISPATCH_ORDER[@]}" -eq 0 ]]` fails with `unbound variable` when caller has `set -u` and `TK_DISPATCH_ORDER` is not yet declared (bash treats an undeclared array as unbound under nounset)
- **Fix:** Changed guard to `[[ -z "${TK_DISPATCH_ORDER[*]:-}" ]]` — the `:-` empty-string fallback safely handles the unset case without triggering nounset
- **Files modified:** `scripts/lib/dispatch.sh`
- **Verification:** `bash -c 'set -euo pipefail; source scripts/lib/dispatch.sh; echo loaded-clean'` exits 0

## Known Stubs

None — all six dispatchers invoke real installers (or honor the override seam). No placeholder data flows.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns beyond what is already present in the existing installer scripts. The `eval "$TK_SP_INSTALL_CMD"` / `eval "$TK_GSD_INSTALL_CMD"` calls operate on project-controlled constants (T-24-01 mitigated by hardcoded allowlist per plan threat model).

## Self-Check: PASSED

- `scripts/lib/dispatch.sh` exists: FOUND
- `scripts/setup-security.sh` contains `YES=0` and `--yes) YES=1`: FOUND
- `scripts/install-statusline.sh` contains `YES=0` and `--yes) YES=1`: FOUND
- Commit `cf0536b` exists: FOUND
- No unexpected file deletions in commit
- shellcheck -S warning: PASS on all 3 files
- test-bootstrap.sh: PASS=26 FAIL=0 (BACKCOMPAT-01)
