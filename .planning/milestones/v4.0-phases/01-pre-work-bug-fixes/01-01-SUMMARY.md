---
phase: 01-pre-work-bug-fixes
plan: "01"
subsystem: scripts/update-claude.sh
tags: [bug-fix, portability, bsd, macos, sed, smart-merge]
dependency_graph:
  requires: []
  provides: [BUG-01-fixed, portable-smart-merge]
  affects: [scripts/update-claude.sh, update-toolkit-workflow]
tech_stack:
  added: []
  patterns: [POSIX sed '$d' for last-line removal]
key_files:
  created: []
  modified:
    - scripts/update-claude.sh
decisions:
  - "Use sed '$d' (POSIX) instead of head -n -1 (GNU-only) — identical semantics, portable across BSD and GNU"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-17"
  tasks_completed: 2
  files_modified: 1
---

# Phase 01 Plan 01: Replace GNU head -n -1 with POSIX sed '$d' in smart-merge Summary

**One-liner:** Four `update-claude.sh` user-section extraction pipelines now use POSIX `sed '$d'` instead of GNU-only `head -n -1`, eliminating silent CLAUDE.md truncation on macOS/BSD.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace head -n -1 with sed '$d' in all four user-section extractions | 7339b3d | scripts/update-claude.sh |
| 2 | Smoke-verify extraction output with BSD-mode sed | (verification only) | none |

## Changes Made

### Task 1: Four-line substitution in scripts/update-claude.sh (lines 186-195)

**Before (GNU-only, broken on BSD):**

```bash
sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true
sed -n '/^## 📁 Project Structure/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true
sed -n '/^## ⚡ Essential Commands/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.commands" 2>/dev/null || true
sed -n '/^## ⚠️ Project-Specific Notes/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.notes" 2>/dev/null || true
```

**After (POSIX, portable):**

```bash
sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true
sed -n '/^## 📁 Project Structure/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true
sed -n '/^## ⚡ Essential Commands/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.commands" 2>/dev/null || true
sed -n '/^## ⚠️ Project-Specific Notes/,/^## /p' "$CLAUDE_MD" | sed '$d' > "$USER_SECTIONS_FILE.notes" 2>/dev/null || true
```

### Task 2: Smoke Verification

One-liner test confirmed `sed '$d'` behavior:

- `grep -c "| head -n -1" scripts/update-claude.sh` → `0` (PASS)
- `grep -c "| sed '$d' >" scripts/update-claude.sh` → `4` (PASS)
- `shellcheck scripts/update-claude.sh` → exit 0 (PASS)
- `bash -n scripts/update-claude.sh` → exit 0 (PASS)
- Smoke test: "OK: extraction preserved user content and stripped boundary header" (PASS)
- Automated form: PASS — `Line C` present, `## Next Section` absent from output

## Verification Results

```text
shellcheck scripts/update-claude.sh  → OK (no warnings)
bash -n scripts/update-claude.sh     → OK (valid syntax)
grep -c "| head -n -1" ...           → 0
grep -c "| sed '$d' >"  ...          → 4
Smoke test                           → OK
```

## Deviations from Plan

None — plan executed exactly as written.

## Threat Flags

None. The sed pipeline change operates on local user files only — no new network endpoints, auth paths, or trust boundary crossings introduced.

## Known Stubs

None.

## Self-Check: PASSED

- `scripts/update-claude.sh` exists and contains 4 instances of `| sed '$d' >`
- Commit 7339b3d exists in git log
- No files deleted by commit
- No modifications to STATE.md or ROADMAP.md
