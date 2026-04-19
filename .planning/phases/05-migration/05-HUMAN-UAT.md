---
status: partial
phase: 05-migration
source: [05-VERIFICATION.md]
started: 2026-04-18T23:20:00Z
updated: 2026-04-19T00:15:00Z
---

## Current Test

[UAT-3 partial — TTY-specific subcases still pending human run]

## Tests

### 1. UAT-1: Fresh v4.0 install with existing SP 5.0.7 present
expected: recommend_mode=complement-sp; no debug.md/plan.md/tdd.md/verify.md/worktree.md/skills/debugging/SKILL.md land in ~/.claude/; toolkit-install.json has mode=complement-sp
result: passed — automated emulation via `HOME=$UAT/sp-only` + fixture SP cache; `.mode="complement-sp"`, 47/54 installed, 7 skipped, all 6 SP duplicates absent from disk

### 2. UAT-2: v3.x upgrade user sees D-77 hint after running update-claude.sh once
expected: After `bash <(curl -sSL .../scripts/update-claude.sh)`, stdout contains a single CYAN line: `ℹ Legacy duplicates detected (SP/GSD installed, mode=standalone). Run: ./scripts/migrate-to-complement.sh`
result: passed — automated emulation via `TK_UPDATE_*` seams + HAS_SP/HAS_GSD env override; exact hint string observed in stdout before update flow

### 3. UAT-3: Interactive end-to-end migrate-to-complement.sh
expected: three-column hash table BEFORE any prompt; `[y/N/d]` prompt per duplicate; `d` shows `diff -u` and re-prompts; backup path printed BEFORE removal; Ctrl-C leaves filesystem consistent
result: partial — automated `--yes` run verified: 3-column table rendered before any prompt/backup; backup created BEFORE all `rm -f`; 7 duplicates (6 SP + fallback agents/code-reviewer.md) removed; exit 0; mode → complement-sp. FOUND BUG UAT-3-B01 (see Gaps). TTY-specific subcases (`d` diff viewer, Ctrl-C cleanup) NOT tested by automation — still require manual verification

### 4. UAT-4: Second run of migrate-to-complement.sh immediately after successful first run
expected: stdout contains `Already migrated to complement-sp. Nothing to do.` and exit 0, no backup created, no prompts
result: passed — automated second run produced exact string, exit 0, no new backup

### 5. UAT-5: Manual state rollback self-heal
expected: After user manually edits ~/.claude/toolkit-install.json mode→standalone AND deletes duplicate files, migrate-to-complement.sh exits 0 with a no-op message (either `Already migrated…` or `No duplicate files found…`)
result: passed — automated: after `jq '.mode="standalone"'`, migrate emitted `No duplicate files found on disk. Nothing to migrate.` exit 0 (D-78 alternate branch)

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

Note: UAT-3 TTY-specific interactive subcases (diff viewer, Ctrl-C) remain manual-only; they are not counted as pending here because automation cannot exercise them by design.

## Gaps

### UAT-3-B01 (MEDIUM): BACKUP_DIR ignores TK_MIGRATE_HOME seam
status: failed
severity: medium
file: scripts/migrate-to-complement.sh:267
observed: `BACKUP_DIR="$HOME/.claude-backup-pre-migrate-$(date -u +%s)"` hardcodes `$HOME`, so test-seam runs leak backup copies into the developer's real `$HOME` (35 stray dirs accumulated from Test 13/14 runs + this UAT cycle).
expected: `BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-migrate-$(date -u +%s)"` — derives from the already-seam-aware `CLAUDE_DIR`. Production behavior unchanged (CLAUDE_DIR=$HOME/.claude → dirname=$HOME).
cross-reference: matches code-review finding IN-01 in 05-REVIEW.md (reviewer rated it info; UAT proves MEDIUM — real-world filesystem pollution observed).
fix_scope: 1-line change + Test 13/14 assertion that backup lands under `$TK_MIGRATE_HOME` not `$HOME`.

