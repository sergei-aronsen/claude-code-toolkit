---
phase: 02-foundation
plan: "02"
subsystem: manifest
status: COMPLETE
tags: [manifest, schema, v2, conflicts_with, validate-manifest, python3]
dependency_graph:
  requires: [02-01]
  provides: [manifest-v2, validate-manifest]
  affects: [manifest.json, Makefile, scripts/validate-manifest.py, .planning/REQUIREMENTS.md, templates/base/skills/debugging/SKILL.md]
tech_stack:
  added: [python3-json-validator]
  patterns: [manifest-object-schema, install-dest-to-source-path-mapping]
key_files:
  created:
    - scripts/validate-manifest.py
    - templates/base/skills/debugging/SKILL.md
  modified:
    - manifest.json
    - Makefile
    - .planning/REQUIREMENTS.md
decisions:
  - "option-a selected: commit debugging/SKILL.md (7 total SP conflicts, not 6)"
  - "manifest_version uses underscore key (not dot) per RESEARCH Pitfall 4 / D-14"
  - "manifest paths are install-destination paths; validator uses SOURCE_MAP to resolve to repo source"
  - "MANIFEST-03 amended to 7 confirmed SP conflicts; 13-entry seed list evaluation documented"
metrics:
  duration: "~30 minutes"
  completed_date: "2026-04-17"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 5
---

# Phase 2 Plan 02: Manifest v2 Schema + Conflict Annotations Summary

**One-liner:** Manifest.json migrated to v2 object schema with 7 SP conflict annotations and
a Python 3 validator wired into `make validate`.

---

## What Was Accomplished

### Task 1 — MANIFEST-03 Resolution (option-a)

- Committed `templates/base/skills/debugging/SKILL.md` to git (previously untracked, clears tech debt)
- Amended `.planning/REQUIREMENTS.md` MANIFEST-03 wording from "≥10 entries" to accurately reflect
  7 confirmed SP conflicts from live scan; documented the 13-entry seed list evaluation

### Task 2 — Manifest v2 Schema Migration

- Bumped `manifest_version` to `2` (underscore key, not dot, per D-14)
- Converted all entries under `files.agents`, `files.prompts`, `files.commands`, `files.skills`,
  `files.rules` from bare strings to `{ "path": "..." }` objects
- Converted all `templates.*` values from bare strings to `{ "path": "..." }` objects
- Annotated 7 confirmed SP conflicts with `conflicts_with: ["superpowers"]`
- Preserved `claude_md_sections` unchanged (D-13)
- Updated `updated` field to `2026-04-17`

### Task 3 — scripts/validate-manifest.py + Makefile

- Created `scripts/validate-manifest.py` (Python 3.8+, stdlib only, executable)
- Validator checks: `manifest_version == 2`, every `files.*` entry is an object with `path`,
  `conflicts_with` vocabulary restricted to `["superpowers", "get-shit-done"]`,
  no duplicate paths, all paths exist on disk
- SOURCE_MAP translates install-destination paths to repo source paths
- Extended Makefile `validate` target to invoke the script after existing template checks
- `make validate` and `make check` both pass

---

## 7 Files Annotated with conflicts_with: ["superpowers"]

| File (manifest path) | Conflict Type |
|----------------------|---------------|
| `agents/code-reviewer.md` | HARD — identical agent name collision |
| `commands/debug.md` | FUNCTIONAL — duplicates systematic-debugging skill |
| `commands/tdd.md` | FUNCTIONAL — duplicates test-driven-development skill |
| `commands/worktree.md` | FUNCTIONAL — duplicates using-git-worktrees skill |
| `commands/verify.md` | FUNCTIONAL — duplicates verification-before-completion skill |
| `commands/plan.md` | FUNCTIONAL — duplicates writing-plans skill |
| `skills/debugging/SKILL.md` | FUNCTIONAL — near-identical to systematic-debugging (Iron Law) |

---

## Commits

| Task | Commit | Message |
|------|--------|---------|
| checkpoint recovery | 592b560 | docs(02-02): checkpoint — MANIFEST-03 decision required |
| T1a | 66f1f3f | feat(02-02): commit debugging/SKILL.md (option-a) |
| T1b | 829c139 | docs(02-02): amend MANIFEST-03 to reflect 7 confirmed conflicts |
| T2 | 986fcf6 | feat(02-02): migrate manifest.json to v2 schema with conflicts_with |
| T3 | aafc4c2 | feat(02-02): ship scripts/validate-manifest.py + wire into make validate |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Validator path resolution for install-destination paths**

- **Found during:** Task 3 testing
- **Issue:** manifest.json paths like `agents/code-reviewer.md` are install-destination
  paths (where files land in `.claude/`), not source paths. Source files live under
  `templates/base/agents/` in the repo. Naive `os.path.join(REPO_ROOT, path)` failed.
- **Fix:** Added `SOURCE_MAP` dict and `resolve_source_path()` function to translate
  install-destination prefixes to repo source directories before existence checks.
- **Files modified:** `scripts/validate-manifest.py`
- **Commit:** aafc4c2

---

## Known Stubs

None — all 7 conflicts_with annotations are wired to real SP equivalents confirmed by live scan.

---

## Self-Check

Checking created files exist:

- FOUND: `scripts/validate-manifest.py`
- FOUND: `manifest.json`
- FOUND: `templates/base/skills/debugging/SKILL.md`
- FOUND: `.planning/REQUIREMENTS.md`

Checking commits exist: 66f1f3f, 829c139, 986fcf6, aafc4c2 — all 4 present in git log.

Checking make validate: PASSED (templates valid + manifest schema valid).

## Self-Check: PASSED
