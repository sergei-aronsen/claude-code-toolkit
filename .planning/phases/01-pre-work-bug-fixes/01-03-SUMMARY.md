---
phase: 01-pre-work-bug-fixes
plan: "03"
subsystem: scripts/setup-security.sh
tags: [bug-fix, backup, restore-on-failure, settings-json, python3]
dependency_graph:
  requires: []
  provides: [BUG-05-backup-restore]
  affects: [scripts/setup-security.sh]
tech_stack:
  added: []
  patterns: [timestamped-backup-before-mutation, restore-on-failure-exit-1]
key_files:
  created: []
  modified:
    - scripts/setup-security.sh
decisions:
  - "SETTINGS_BACKUP is scoped per mutation block (not global) — each block computes its own $(date +%s) timestamp independently"
  - "exit 1 (not return 1) on failure — callers detect non-zero exit per D-13"
  - "cp (not mv) for backup — original file must still be in place when python3 reads it"
  - "No PID/nanosecond suffix added — timestamp-level uniqueness is acceptable per plan note; Phase 4 UPDATE-05 covers collision-proof naming"
metrics:
  duration: "15m"
  completed: "2026-04-17"
  tasks_completed: 2
  files_modified: 1
---

# Phase 01 Plan 03: settings.json Backup Before Mutation Summary

Wrapped all three `python3` JSON-merge blocks in `scripts/setup-security.sh` with a pre-mutation timestamped backup of `~/.claude/settings.json` and a restore-on-failure handler that copies the backup back before exiting non-zero (BUG-05).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Backup + restore-on-failure around all three python3 merge blocks | 0185d26 | scripts/setup-security.sh |
| 2 | Smoke-verify backup creation on a dummy settings.json | (verification only) | none |

## What Was Done

### Task 1: Three mutation sites patched

**Site 1** — Combined hook configuration (was ~line 201, now lines 202-247):

- Backup: line 203 (`SETTINGS_BACKUP="${SETTINGS_JSON}.bak.$(date +%s)"`)
- Pre-mutation `cp`: line 204
- Restore-on-failure: lines 245-247 (`cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"` + message + `exit 1`)

**Site 2** — Plugin merge (was ~line 310, now lines 316-349):

- Backup: line 317
- Pre-mutation `cp`: line 318
- Restore-on-failure: lines 347-349

**Site 3** — enabledPlugins key missing (was ~line 346, now lines 358-386):

- Backup: line 359
- Pre-mutation `cp`: line 360
- Restore-on-failure: lines 384-386

### Counts (post-edit)

| Check | Count | Required |
|-------|-------|----------|
| `SETTINGS_JSON}.bak.` occurrences | 3 | >= 3 |
| `cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"` occurrences | 3 | >= 3 |
| `restored from backup` occurrences | 3 | >= 3 |
| `exit 1` occurrences | 3 | 0 pre-edit + 3 |

### Task 2: Smoke test output

```text
backup created
content matches
OK: restore verified — hooks key present after restore
```

Backup file `settings.json.bak.1234` created with byte-identical content. After writing `CORRUPTED` to the original, restore from backup correctly recovered `{"hooks":{}}`.

### shellcheck output

```text
(no output — exit 0)
```

### bash -n output

```text
(no output — exit 0)
```

## Acceptance Criteria

- [x] `grep -c "SETTINGS_JSON}.bak." scripts/setup-security.sh` prints `3`
- [x] `grep -c 'cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"' scripts/setup-security.sh` prints `3`
- [x] `grep -c "restored from backup" scripts/setup-security.sh` prints `3`
- [x] `exit 1` count increased by 3 (was 0, now 3)
- [x] `shellcheck scripts/setup-security.sh` exits 0
- [x] `bash -n scripts/setup-security.sh` exits 0

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — changes are purely within `scripts/setup-security.sh` at the existing python3-mutation trust boundary already documented in the plan's threat model. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- File `scripts/setup-security.sh` confirmed modified (3 backup sites, 3 restore sites)
- Commit `0185d26` confirmed present in git log
- Task 2 verification passed (smoke test output confirmed)
