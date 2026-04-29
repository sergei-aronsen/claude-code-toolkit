---
phase: 26
plan: "01"
subsystem: skills-selector
tags: [skills, catalog, library, sync, bash]
dependency_graph:
  requires: [scripts/lib/mcp.sh, scripts/lib/detect2.sh]
  provides: [scripts/lib/skills.sh, scripts/sync-skills-mirror.sh]
  affects: [scripts/install.sh, scripts/tests/test-install-skills.sh, manifest.json]
tech_stack:
  added: []
  patterns: [sourced-lib-invariant, TK_*-test-seam, cp-R-install]
key_files:
  created:
    - scripts/lib/skills.sh
    - scripts/sync-skills-mirror.sh
  modified: []
decisions:
  - "Two-state is_skill_installed (not three-state): skills have no CLI dependency, directory probe is sufficient"
  - "cp -R (not rsync): explicit SKILL-03 choice for simplicity and portability"
  - "sync-skills-mirror.sh not wired to CI or tests: dev-side maintainer tool only"
  - "SKILLS_CATALOG array defined at source time (not in a function): enables callers to iterate without calling a function"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-29"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 26 Plan 01: Skills Lib and Sync Script Summary

**One-liner:** Foundational skills library with 22-skill catalog, directory-probe installer, and maintainer re-sync tool using cp-R and TK_SKILLS_HOME/MIRROR_PATH test seams.

## What Was Built

Two shell files delivering the foundational skills infrastructure for Phase 26:

**`scripts/lib/skills.sh`** — sourced library (no set -euo pipefail):

- `SKILLS_CATALOG[]` — 22-entry array matching REQUIREMENTS.md SKILL-01 exactly (alphabetical)
- `skills_catalog_names()` — prints all 22 names one-per-line
- `is_skill_installed <name>` — two-state directory probe (`[ -d TK_SKILLS_HOME/<name> ]`); returns 0/1
- `skills_status_array()` — populates `TUI_INSTALLED[]` for install.sh `--skills` branch
- `skills_install <name> [--force]` — copies from mirror to target via `cp -R`; returns 2 if target exists without `--force`
- Color guards mirroring mcp.sh pattern; TK_SKILLS_HOME + TK_SKILLS_MIRROR_PATH seams

**`scripts/sync-skills-mirror.sh`** — standalone executable (`set -euo pipefail`):

- Sources `lib/skills.sh` to inherit canonical `SKILLS_CATALOG`
- Supports `--dry-run` (preview without writes), per-skill positional arg, `--help`
- TK_SKILLS_SRC + TK_SKILLS_DEST seams for hermetic overrides
- Exits 1 when any source skills are missing; exits 2 on invalid argument
- NOT wired to CI, test suite, or install path — dev-side maintainer tool only

## Verification

All plan verification steps passed:

1. `skills_catalog_names | wc -l` → 22
2. `declare -p SKILLS_CATALOG | grep -c 'webapp-testing'` → 1
3. `[ -x scripts/sync-skills-mirror.sh ]` → exit 0
4. `bash scripts/sync-skills-mirror.sh --help | grep -q Usage` → exit 0
5. `shellcheck -S warning scripts/lib/skills.sh scripts/sync-skills-mirror.sh` → 0 warnings
6. `make check` → All checks passed

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create scripts/lib/skills.sh | e4f6ca8 | scripts/lib/skills.sh |
| 2 | Create scripts/sync-skills-mirror.sh | f73f05b | scripts/sync-skills-mirror.sh |

## Deviations from Plan

None — plan executed exactly as written.

The only note: `skills_status_array()` does not populate `TUI_LABELS[]` or `TUI_GROUPS[]` (unlike `mcp_status_array`), because the plan spec only requires `TUI_INSTALLED[]`. Plan 03 (`install.sh --skills` page) will populate those additional arrays. This is intentional alignment with the plan's scope, not a deviation.

## Known Stubs

None. The library functions are fully implemented. No placeholder values or TODO stubs.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns at trust boundaries, or schema changes introduced. Skills install only copies local files from a repo-committed mirror to a user's home directory — no external network access in this plan.

## Self-Check: PASSED

- `scripts/lib/skills.sh` exists: FOUND
- `scripts/sync-skills-mirror.sh` exists: FOUND
- Commit e4f6ca8 exists: FOUND
- Commit f73f05b exists: FOUND
