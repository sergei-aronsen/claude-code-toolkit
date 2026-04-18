---
status: partial
phase: 05-migration
source: [05-VERIFICATION.md]
started: 2026-04-18T23:20:00Z
updated: 2026-04-18T23:20:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. UAT-1: Fresh v4.0 install with existing SP 5.0.7 present
expected: recommend_mode=complement-sp; no debug.md/plan.md/tdd.md/verify.md/worktree.md/skills/debugging/SKILL.md land in ~/.claude/; toolkit-install.json has mode=complement-sp
result: [pending]

### 2. UAT-2: v3.x upgrade user sees D-77 hint after running update-claude.sh once
expected: After `bash <(curl -sSL .../scripts/update-claude.sh)`, stdout contains a single CYAN line: `ℹ Legacy duplicates detected (SP/GSD installed, mode=standalone). Run: ./scripts/migrate-to-complement.sh`
result: [pending]

### 3. UAT-3: Interactive end-to-end migrate-to-complement.sh
expected: User sees three-column hash table BEFORE any prompt; [y/N/d] prompt fires per duplicate; `d` shows diff -u output and re-prompts; backup path printed BEFORE removal; Ctrl-C at any point leaves filesystem consistent (backup kept, nothing removed)
result: [pending]

### 4. UAT-4: Second run of migrate-to-complement.sh immediately after successful first run
expected: stdout contains `Already migrated to complement-sp. Nothing to do.` and exit 0, no backup created, no prompts
result: [pending]

### 5. UAT-5: Manual state rollback self-heal
expected: After user manually edits ~/.claude/toolkit-install.json mode→standalone AND deletes duplicate files, migrate-to-complement.sh exits 0 with a no-op message (either `Already migrated…` or `No duplicate files found…`)
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
