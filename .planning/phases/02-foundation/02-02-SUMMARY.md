---
phase: 02-foundation
plan: "02"
subsystem: manifest
status: PARTIAL
tags: [manifest, schema, v2, conflicts_with, checkpoint]
dependency_graph:
  requires: [02-01]
  provides: [manifest-v2, validate-manifest]
  affects: [Makefile, manifest.json, scripts/validate-manifest.py]
tech_stack:
  added: []
  patterns: [python3-json-validator, manifest-object-schema]
key_files:
  created: []
  modified: []
decisions:
  - "PENDING: Task 1 checkpoint — user must select option-a, option-b, or option-c before manifest.json is written"
metrics:
  completed_date: "2026-04-17"
  tasks_completed: 0
  tasks_total: 3
  files_changed: 0
---

# Phase 2 Plan 02: Manifest v2 Schema + Conflict Annotations Summary

**Status: PARTIAL — blocked at Task 1 checkpoint (user decision required)**

**One-liner:** Manifest v2 schema migration paused for user decision on MANIFEST-03 count
discrepancy (7 confirmed SP conflicts vs requirement wording of ≥10).

---

## What Was Accomplished

Task 1 of 3 reached — this task is a `checkpoint:decision` gate (blocking).

No files were modified. The checkpoint was reached cleanly with:

- All required files read and analyzed
- 7 confirmed SP conflicts identified via live scan (RESEARCH.md Authoritative Conflict Map)
- `templates/base/skills/debugging/SKILL.md` confirmed UNTRACKED in main repo, absent from worktree
- 30 commands on disk (`commands/*.md`) confirmed vs 29 in manifest (design.md added post-v1)
- Three resolution options fully documented in `02-02-CHECKPOINT.md`

---

## Checkpoint: Task 1 — Resolve MANIFEST-03 Count Discrepancy

**File:** `.planning/phases/02-foundation/02-02-CHECKPOINT.md`

**Decision required (select one):**

| Option | Description | Conflict Count | REQUIREMENTS.md |
|--------|-------------|----------------|-----------------|
| option-a | Commit debugging/SKILL.md + amend MANIFEST-03 to "7 confirmed" | 7 | Amended |
| option-b | Exclude debugging/SKILL.md + amend MANIFEST-03 to "6 confirmed" | 6 | Amended |
| option-c | Commit debugging/SKILL.md + keep ≥10 by broadening definition | ≥10 | Unchanged |

**Research recommendation:** option-a (commit the untracked file, amend MANIFEST-03 to reflect 7 confirmed conflicts accurately).

---

## Deviations from Plan

None — plan executed correctly up to the blocking checkpoint. Task 1 requires no file edits;
it is a pure decision gate.

---

## Pending Tasks (after user decision)

### Task 2: Rewrite manifest.json to v2 schema + apply decision from Task 1

- Migrate all bare-string entries to `{ "path": "...", ... }` objects
- Add `conflicts_with: ["superpowers"]` to confirmed SP conflicts (6 or 7 per decision)
- Bump `manifest_version` to 2 (underscore form, not dot)
- Update `updated` field to today's date
- Migrate `templates.*` from strings to `{ "path": "..." }` objects
- Leave `claude_md_sections` unchanged (D-13)
- Add 30th command (design.md) that was missing from v1 manifest
- Conditionally amend REQUIREMENTS.md MANIFEST-03 text

### Task 3: Create scripts/validate-manifest.py + extend Makefile validate

- Python3 validator: version check, path existence, vocabulary, drift
- Make executable (`chmod +x`)
- Extend Makefile `validate` target to invoke the script
- Verify `make validate` and `make check` both pass

---

## Known Discovery: 30th Command in manifest

The v1 manifest lists 29 commands, but 30 `.md` files exist in `commands/` (design.md was added
in commit `1419e13` after the manifest was last updated). The v2 rewrite in Task 2 must include
`commands/design.md` in `files.commands[]`. This is a drift fix baked into the migration.

---

## Self-Check

No files committed yet — checkpoint triggered before any modifications.
CHECKPOINT.md and SUMMARY.md are the only new files created by this agent run.

## Self-Check: PASSED

Checkpoint documented correctly. No plan artifacts were modified prematurely.
Continuation agent will receive Task 1 decision via resume signal and execute Tasks 2+3.
