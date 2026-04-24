---
phase: 09-backup-detection
plan: "04"
subsystem: detect
tags:
  - detect
  - version-skew
  - shell
  - tdd
dependency_graph:
  requires:
    - 09-03
  provides:
    - warn_version_skew helper in scripts/lib/install.sh
    - version-skew warning in update-claude.sh
  affects:
    - scripts/lib/install.sh
    - scripts/update-claude.sh
tech_stack:
  added: []
  patterns:
    - jq soft-fail on state JSON parse (.detected.superpowers.version / .detected.gsd.version)
    - YELLOW echo -e warning pattern (install.sh convention)
    - TK_UPDATE_HOME + seed_state_with_versions test seam
key_files:
  created:
    - scripts/tests/test-detect-skew.sh
  modified:
    - scripts/lib/install.sh
    - scripts/update-claude.sh
decisions:
  - "D-22 enforced: warn_version_skew called only in update-claude.sh, not init or migrate"
  - "D-23 emission position: after STATE_MANIFEST_HASH extraction, before migrate hint block"
  - "Test assertion for GSD-silent scenario uses 'Base plugin version changed: get-shit-done' substring (not bare 'get-shit-done') because update output includes get-shit-done in skip-set mode text"
metrics:
  duration: 12min
  completed: "2026-04-24T18:12:46Z"
  tasks_completed: 1
  files_changed: 3
---

# Phase 9 Plan 04: DETECT-07 Version-Skew Warning Summary

**One-liner:** `warn_version_skew()` helper in `install.sh` compares `.detected.superpowers.version` / `.detected.gsd.version` from state schema v2 against current `SP_VERSION`/`GSD_VERSION`, emitting one YELLOW warning line per changed plugin during `update-claude.sh`.

## What Was Built

### `scripts/lib/install.sh` — `warn_version_skew()` appended

New helper function at end of file reads plugin versions from `~/.claude/toolkit-install.json`
via jq paths `.detected.superpowers.version` and `.detected.gsd.version` (state schema v2).

Key properties:
- Guard: `[[ -f "${STATE_FILE:-}" ]] || return 0` — silent when state file absent
- Guard: `command -v jq &>/dev/null || return 0` — silent when jq absent
- Fires only when stored version is non-empty AND differs from `$SP_VERSION` / `$GSD_VERSION`
- `echo -e "${YELLOW}⚠${NC}"` inline (not via `log_warning`) to interpolate version variables
- No `set -e`/`set -u`/`set -o pipefail` added (sourced-lib invariant preserved)

### `scripts/update-claude.sh` — single call site

Inserted on line 407, exactly 3 lines after `STATE_MANIFEST_HASH=$(jq -r '.manifest_hash ...`
and before the Phase 5 migrate hint block — satisfies D-23 emission position.

### `scripts/tests/test-detect-skew.sh` — new test file (211 lines)

TDD test covering 6 scenarios:

| Scenario | Assertion |
|----------|-----------|
| SP skew only | SP warning present; GSD skew warning absent |
| Both SP + GSD skew | Two warning lines (SP + GSD) |
| Version match | No warning (silent per D-25) |
| Empty stored version | No warning (D-23: fires only when stored non-empty) |
| No STATE_FILE | Returns 0 silently |
| D-22 scope lock | Negative grep on init-claude.sh + migrate-to-complement.sh |

All 10 assertions pass (`PASS: 10 FAIL: 0`).

## D-22 Scope Audit (Explicit Confirmation)

- `scripts/init-claude.sh` — does NOT contain `warn_version_skew` (verified by grep + test)
- `scripts/migrate-to-complement.sh` — does NOT contain `warn_version_skew` (verified by grep + test)

## Branch

`feature/detect-07-version-skew` (per D-30)

## TDD Gate Compliance

- RED commit: `f4f7ae3` — test(09-04): add failing tests for DETECT-07 version-skew warning
- GREEN commit: `d4a85e1` — feat(09-04): implement DETECT-07 warn_version_skew() helper and wire into update-claude.sh

## Verification Results

```
bash scripts/tests/test-detect-skew.sh → PASS: 10 FAIL: 0
make check → All checks passed!
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test assertion for "GSD silent" scenario was too broad**

- **Found during:** GREEN phase (Scenario 1 false failure)
- **Issue:** `assert_not_contains "get-shit-done"` matched normal update output that mentions
  `get-shit-done` in skip-set mode text (e.g. `SKIP - conflicts_with:get-shit-done`). The
  update runs with `HAS_SP=true` which recommends `complement-sp` mode, causing the normal
  install report to list `get-shit-done` as a skipped plugin.
- **Fix:** Changed assertion needle to `"Base plugin version changed: get-shit-done"` — the
  exact warning prefix — which is unambiguous and only emitted by `warn_version_skew()`.
- **Files modified:** `scripts/tests/test-detect-skew.sh`

**2. [Rule 1 - Bug] warn_version_skew call was 4 lines after STATE_MANIFEST_HASH (acceptance criterion requires within 3)**

- **Found during:** Acceptance check `grep -A3`
- **Issue:** Original insertion had a blank separator line between `STATE_MANIFEST_HASH=` line
  and the new call block, putting `warn_version_skew` on line +4.
- **Fix:** Removed the blank separator line so the comment + call land within 3 lines.
- **Files modified:** `scripts/update-claude.sh`

## Known Stubs

None.

## Threat Flags

None. `warn_version_skew` reads user-owned state file via jq soft-fail (`2>/dev/null || echo ""`).
Large/malformed version strings echo inline but cause no behavioral change (T-9-05 / T-9-B4-01
both accepted in plan threat model).
