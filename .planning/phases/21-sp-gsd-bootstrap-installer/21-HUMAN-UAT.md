---
status: partial
phase: 21-sp-gsd-bootstrap-installer
source: [21-VERIFICATION.md]
started: 2026-04-27T08:35:00Z
updated: 2026-04-27T08:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Real upstream installers succeed end-to-end

expected: In a clean $HOME, run init-claude.sh (no --no-bootstrap), answer y to both prompts; ~/.claude/plugins/cache/claude-plugins-official/superpowers/ and ~/.claude/get-shit-done/ both exist after.

result: [pending]

### 2. curl|bash install path exercises /dev/tty correctly

expected: Pipe init-claude.sh from raw URL after Phase 21 ships; user can answer prompts via real /dev/tty; behaviour matches local invocation.

result: [pending]

### 3. Visual review of two-prompt UX flow

expected: User sees SP prompt first, then GSD prompt; default N is clear; upstream installer output streams verbatim to stdout/stderr (D-11).

result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
