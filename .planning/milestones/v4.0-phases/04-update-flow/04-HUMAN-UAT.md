---
status: partial
phase: 04-update-flow
source: [04-VERIFICATION.md]
started: 2026-04-18T20:15:00Z
updated: 2026-04-18T20:15:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Production curl path for new-file install
expected: On a machine with network access, running `bash scripts/update-claude.sh` against a project where a file exists in the latest `manifest.json` but is absent from `~/.claude/toolkit-install.json` (no `TK_UPDATE_FILE_SRC` set) downloads the file via `curl -sSLf $REPO_URL/$path`, places it in `$CLAUDE_DIR/`, and summary shows `INSTALLED 1`.
result: [pending]

### 2. Interactive modified-file diff display
expected: Seed a project with a modified file (sha256 differs from state). Run `update-claude.sh` in an interactive terminal. Enter `d` at the `[y/N/d]:` prompt — unified diff (`--- ... +++ ... @@ ...`) displays and script re-prompts. Then `n` keeps local version.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps

### G-01 TK_UPDATE_SKIP_LEGACY_BACKUP dead-code remnant
status: cosmetic
artifacts:
  - path: scripts/tests/test-update-drift.sh
    lines: [94, 152, 190]
missing:
  - Remove `TK_UPDATE_SKIP_LEGACY_BACKUP=1` from 3 scenario invocations in test-update-drift.sh
impact: zero functional — var not read by update-claude.sh; all 14 drift tests pass
