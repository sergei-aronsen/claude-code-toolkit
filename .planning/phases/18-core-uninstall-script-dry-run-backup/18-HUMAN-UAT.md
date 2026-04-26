---
status: partial
phase: 18-core-uninstall-script-dry-run-backup
source: [18-VERIFICATION.md]
started: 2026-04-26T10:15:00Z
updated: 2026-04-26T10:15:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Real /dev/tty prompt on actual terminal
expected: Run `bash scripts/uninstall.sh` in a real project with toolkit installed (not a test sandbox). The interactive `[y/N/d]` prompt reads from `/dev/tty`, default `N` keeps, `d` shows diff against remote reference and re-prompts, user input correctly routes to remove/keep. Tests use `TK_UNINSTALL_TTY_FROM_STDIN=1` seam to inject stdin; actual `/dev/tty` behavior under `bash <(curl -sSL ...)` requires a real terminal session.
result: [pending]

### 2. curl pipe end-to-end fetch
expected: Run `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh) --dry-run` from a project directory. Script fetches `state.sh`, `backup.sh`, `dry-run-output.sh` from GitHub, prints 4-group dry-run preview, exits 0. Tests use `TK_UNINSTALL_LIB_DIR` to bypass curl — real curl fetch path not exercised by automated tests.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
