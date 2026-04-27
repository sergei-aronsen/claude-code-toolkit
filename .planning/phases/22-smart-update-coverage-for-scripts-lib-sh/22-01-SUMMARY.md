---
phase: 22-smart-update-coverage-for-scripts-lib-sh
plan: 01
subsystem: infra
tags: [manifest, update-claude, lib, bash, versioning, changelog]

# Dependency graph
requires:
  - phase: 21-sp-gsd-bootstrap-installer
    provides: "bootstrap.sh and optional-plugins.sh (two of the six libs now registered)"
provides:
  - "manifest.json files.libs[] with all six scripts/lib/*.sh entries"
  - "version 4.4.0 in manifest.json, CHANGELOG.md, and init-local.sh --version"
  - "CHANGELOG.md [4.4.0] entry consolidating Phase 21 + Phase 22"
affects:
  - 22-02-test-update-libs
  - update-claude.sh update loop (auto-discovers libs via to_entries[])

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "files.libs[] parallel to files.scripts[] — semantic split for sourced helpers vs entry-points"
    - "version bump = manifest.json + CHANGELOG.md atomic pair, enforced by make version-align"

key-files:
  created: []
  modified:
    - manifest.json
    - CHANGELOG.md

key-decisions:
  - "files.libs[] omits description field — matches files.scripts[] convention; descriptions live in lib file headers (D-01)"
  - "Six entries in alphabetical order by basename: backup, bootstrap, dry-run-output, install, optional-plugins, state"
  - "Phase 21 (BOOTSTRAP-01..04) + Phase 22 (LIB-01..02) consolidated into single [4.4.0] CHANGELOG entry — Phase 21 was never separately released"
  - "No update-claude.sh code changes needed — existing jq .files | to_entries[] | .value[] | .path auto-discovers new libs key (D-01 / D-07 zero-special-casing invariant)"

patterns-established:
  - "New manifest file category: add as parallel top-level key under .files, no description field, alphabetical order"
  - "Validate with python3 scripts/validate-manifest.py — REPO_ROOT fallback covers scripts/ prefix paths"

requirements-completed: [LIB-01]

# Metrics
duration: 8min
completed: 2026-04-27
---

# Phase 22 Plan 01: Manifest Registration + Version 4.4.0 Summary

**Six `scripts/lib/*.sh` helpers registered in `manifest.json` under `files.libs[]`; version bumped 4.3.0 -> 4.4.0 with consolidated [4.4.0] CHANGELOG entry covering Phase 21 + Phase 22**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-27T08:44:00Z
- **Completed:** 2026-04-27T08:52:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Registered all six sourced helper libs (`backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`, `state.sh`) in `manifest.json` under a new `files.libs[]` top-level key — zero `update-claude.sh` code changes required
- Bumped toolkit version to 4.4.0 (`manifest.json .version`, `.updated`) and verified three-way match via `make version-align`
- Added `CHANGELOG.md [4.4.0]` section consolidating Phase 21 (BOOTSTRAP-01..04) and Phase 22 (LIB-01..02) work; markdownlint and full `make check` pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Register six lib helpers in manifest.json and bump version to 4.4.0** - `d929617` (feat)
2. **Task 2: Add CHANGELOG [4.4.0] consolidated entry covering Phase 21 + Phase 22** - `e7ac1c5` (docs)

**Plan metadata:** (final docs commit — see below)

## Files Created/Modified

- `manifest.json` — added `files.libs[]` with six alphabetical entries; bumped version to 4.4.0 and updated to 2026-04-27
- `CHANGELOG.md` — inserted `## [4.4.0] - 2026-04-27` section above [4.3.0] with BOOTSTRAP-01..04 and LIB-01..02 bullets

## Decisions Made

- **No description fields in files.libs[]**: existing `files.scripts[]` has no descriptions; keeping libs lean matches that convention (D-01). Descriptions live in lib file headers.
- **Alphabetical order**: `backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`, `state.sh` — consistent with existing array conventions.
- **Single [4.4.0] CHANGELOG entry**: Phase 21 was never tagged/released, so consolidating both phases into one entry is correct (no [4.3.1] or [4.4.0-pre] split needed).

## Version-Align Proof (Three-Way Match)

```text
Checking version alignment (manifest.json <-> CHANGELOG.md <-> init-local.sh)...
✅ Version aligned: 4.4.0
```

- `jq -r '.version' manifest.json` → `4.4.0`
- `grep -m1 '^## \[' CHANGELOG.md` → `## [4.4.0] - 2026-04-27`
- `bash scripts/init-local.sh --version` → `4.4.0` (reads from manifest.json at runtime, D-12)

## Update Loop Zero-Code-Change Confirmation

`update-claude.sh:637` extracts manifest file paths via:

```bash
MANIFEST_FILES_JSON=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
```

Adding `files.libs[]` as a new top-level key under `.files` is auto-discovered by `to_entries[]` iteration. No changes to `update-claude.sh` were necessary — D-01 / D-07 zero-special-casing invariant confirmed.

## Markdownlint Adjustments

No adjustments beyond the plan template were needed. The CHANGELOG entry passed markdownlint on first attempt (blank lines before/after lists and headings in place, no trailing punctuation, no code fences requiring MD040).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 22-01 complete: `manifest.json` registers all six libs; version-align gate green
- Plan 22-02 (`test-update-libs.sh`) can now proceed — the manifest registration is the prerequisite for writing the hermetic update test (S1-S5 scenarios)
- `make check` is fully green; CI will pass on push

## Self-Check

### Files exist

- `manifest.json` — FOUND (modified in d929617)
- `CHANGELOG.md` — FOUND (modified in e7ac1c5)

### Commits exist

- `d929617` — FOUND: feat(22-01): register scripts/lib/*.sh in manifest.json and bump version to 4.4.0
- `e7ac1c5` — FOUND: docs(22-01): add CHANGELOG [4.4.0] entry consolidating Phase 21 + Phase 22

### Must-have truths verified

- [x] `manifest.json` exposes all six `scripts/lib/*.sh` files under `files.libs[]` — `jq '.files.libs | length' manifest.json` = 6
- [x] `manifest.json` version equals 4.4.0 — `jq -r '.version' manifest.json` = `4.4.0`
- [x] `CHANGELOG.md` top entry is `[4.4.0]` consolidating Phase 21 + Phase 22 — `grep -m1 '^## \['` = `## [4.4.0] - 2026-04-27`
- [x] `make version-align` passes — three-way match 4.4.0 confirmed

## Self-Check: PASSED

---

*Phase: 22-smart-update-coverage-for-scripts-lib-sh*
*Completed: 2026-04-27*
