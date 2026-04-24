---
phase: 12-audit-verification-template-hardening
plan: "02"
subsystem: quality-gates
tags: [harden, validation, makefile, ci, commands]
dependency_graph:
  requires: [12-01]
  provides: [validate-commands-target, commands-lint-ci]
  affects: [Makefile, .github/workflows/quality.yml, commands/]
tech_stack:
  added: [scripts/validate-commands.py]
  patterns: [ERRORS-accumulator-Makefile, python-stdlib-validator]
key_files:
  created:
    - scripts/validate-commands.py
  modified:
    - Makefile
    - .github/workflows/quality.yml
    - commands/rollback-update.md
    - commands/update-toolkit.md
    - .planning/REQUIREMENTS.md
    - .planning/phases/12-audit-verification-template-hardening/12-AUDIT.md
decisions:
  - "Used Python validator script (not Makefile grep) for heading detection to get accurate line-anchored regex matching of ## Purpose and ## Usage — more robust than shell grep for multi-heading files"
  - "Fixed two non-compliant command files (rollback-update.md, update-toolkit.md) by renaming ## Description to ## Purpose before wiring the lint gate, ensuring make check exits 0 immediately"
  - "Added CI step to existing validate-templates job rather than a new job — minimizes CI overhead and follows the existing pattern"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-24"
  tasks_completed: 2
  files_changed: 8
---

# Phase 12 Plan 02: HARDEN-A-01 Implementation Summary

**One-liner:** `validate-commands` Makefile target enforcing `## Purpose` and `## Usage` headings across all 30 `commands/*.md` files via Python stdlib validator wired into `make check` and CI.

## What Was Built

### Approved HARDEN-A-NN REQs Implemented

| HARDEN ID | Derived From | Artifact | Status |
|-----------|--------------|----------|--------|
| HARDEN-A-01 | AUDIT-12 | `scripts/validate-commands.py` + `make validate-commands` | Done |

### New Makefile Targets Added

- `validate-commands` — calls `python3 scripts/validate-commands.py`; wired into `check` dependency chain after `agent-collision-static`

### New Validator Scripts Added

- `scripts/validate-commands.py` — Python 3.8+ stdlib only; walks `commands/*.md` (excluding `README.md`); checks each file for `## Purpose` and `## Usage` H2 headings using line-anchored regex; exits 0 with count on pass, exits 1 with per-file error messages on fail

### CI Steps Added

- Step name: `HARDEN-A-01 — validate commands/*.md required headings`
- Job: `validate-templates` in `.github/workflows/quality.yml`
- Invocation: `run: make validate-commands`

### Pre-existing Files Fixed (deviation — Rule 2)

Two `commands/*.md` files lacked `## Purpose` heading (had `## Description` instead):

- `commands/rollback-update.md` — renamed `## Description` → `## Purpose`
- `commands/update-toolkit.md` — renamed `## Description` → `## Purpose`

These fixes were required to ensure `make check` exits 0 on the current repo state after the new lint gate was added.

## Rejected / Deferred REQs (carry-over from 12-01)

No Wave A REQs were rejected. All other wave proposals (Wave B, Wave C) were deferred to v4.2+:

| HARDEN ID | Wave | Status | Reason |
|-----------|------|--------|--------|
| HARDEN-B-01 | B | Deferred v4.2+ | AUDIT-10: collision detection policy — undeclared behavior, architectural change |
| HARDEN-C-01 | C | Deferred v4.2+ | AUDIT-02: compatibility.json for inter-template compat matrix |
| HARDEN-C-02 | C | Deferred v4.2+ | AUDIT-04: merge-strategy declaration document |
| HARDEN-C-03 | C | Deferred v4.2+ | AUDIT-06: version pinning / template.lock.json |
| HARDEN-C-04 | C | Deferred v4.2+ | AUDIT-14: uninstall semantics / script |
| HARDEN-C-05 | C | Deferred v4.2+ | AUDIT-15: template provenance in toolkit-install.json |

## Verification Outcomes

| Check | Result |
|-------|--------|
| `make check` | PASSED (exit 0) — all 30 command files valid |
| `make mdlint` | PASSED (exit 0) — all markdown files valid |
| `python3 -m py_compile scripts/validate-commands.py` | PASSED |
| `python3 scripts/validate-commands.py` standalone | PASSED — "commands/ validation PASSED (30 files checked)" |
| REQUIREMENTS.md HARDEN-A-01 | Status: Done |
| 12-AUDIT.md AUDIT-12 Action | → HARDEN-A-01 (implemented) |

## Gate Context

- User gate from Plan 12-01 resolved 2026-04-24: `HARDEN-A-01: approve`
- Gate was pre-resolved before this plan executed; Task 0 (original human gate) was skipped per orchestrator instructions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Fixed two commands/*.md missing ## Purpose heading**

- **Found during:** Task 1, pre-implementation scan of all `commands/*.md`
- **Issue:** `commands/rollback-update.md` and `commands/update-toolkit.md` both had `## Description` instead of `## Purpose`, which would cause the new lint gate to fail immediately, making `make check` exit 1
- **Fix:** Renamed `## Description` heading to `## Purpose` in both files
- **Files modified:** `commands/rollback-update.md`, `commands/update-toolkit.md`
- **Commit:** 710161f

## Wave B and Wave C REQs Pending v4.2+

**Wave B (install safety):**

- `HARDEN-B-01` (AUDIT-10): Unified collision detection policy declaration across all installer scripts

**Wave C (provenance/metadata):**

- `HARDEN-C-01` (AUDIT-02): Template compatibility matrix (`compatibility.json`)
- `HARDEN-C-02` (AUDIT-04): Merge-strategy declaration document
- `HARDEN-C-03` (AUDIT-06): Version pinning / `template.lock.json`
- `HARDEN-C-04` (AUDIT-14): Uninstall script / semantics
- `HARDEN-C-05` (AUDIT-15): Template provenance field in `toolkit-install.json`

## Self-Check: PASSED

- `scripts/validate-commands.py` exists: FOUND
- `Makefile` has `validate-commands:` target: FOUND
- `Makefile` check target includes `validate-commands`: FOUND
- `.github/workflows/quality.yml` has `make validate-commands` step: FOUND
- `REQUIREMENTS.md` HARDEN-A-01 = Done: FOUND
- `12-AUDIT.md` AUDIT-12 Action = (implemented): FOUND
- Commits: de6f82c (gate state), 710161f (implementation)
- STATE.md: NOT modified (orchestrator owns)
- ROADMAP.md: NOT modified (orchestrator owns)
