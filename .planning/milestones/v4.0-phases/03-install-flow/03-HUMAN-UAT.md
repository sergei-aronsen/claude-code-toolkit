---
status: partial
phase: 03-install-flow
source: [03-VERIFICATION.md]
started: 2026-04-18T13:22:00Z
updated: 2026-04-18T13:22:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Remote curl|bash install against actual github.com
expected: On machine with superpowers at ~/.claude/plugins/cache/superpowers, `bash <(curl -sSL .../init-claude.sh) --dry-run` downloads detect.sh + lib/install.sh + manifest.json via mktemp, prints `Detected plugins: OK superpowers (<ver>)`, recommends complement-sp, produces grouped dry-run output, exits 0, writes nothing to ~/.claude/.
result: [pending]

### 2. Interactive mode prompt under real tty
expected: On machine with SP+GSD detected, `bash scripts/init-claude.sh` from a real terminal prints `Detected plugins: OK superpowers (...) OK get-shit-done (...)` → `Recommended: complement-full`; empty input defaults to complement-full. Second run with choice `1` selects standalone.
result: [pending]

### 3. Mode-change prompt (D-42) under real tty
expected: With ~/.claude/toolkit-install.json showing mode=standalone, `bash scripts/init-claude.sh --force --mode complement-sp` prompts `Switching standalone -> complement-sp will rewrite the install. Backup current state and proceed? [y/N]:`. `y` → creates `.bak.<ts>` and proceeds. ENTER (empty) → `Aborted. Pass --force-mode-change to bypass the prompt under curl|bash.` exit 0.
result: [pending]

### 4. Real setup-security.sh against settings.json with SP+GSD hooks
expected: On dev machine with ~/.claude/settings.json already containing SP+GSD Bash hooks, `bash scripts/setup-security.sh` leaves `jq '.hooks.PreToolUse | length'` == 3 (SP at [0], GSD at [1], TK at [2] with `_tk_owned: true`). `.bak.<ts>` exists next to settings.json. SP's original command unchanged.
result: [pending]

### 5. Visual inspection of ANSI colors in real terminal
expected: `bash scripts/init-local.sh --dry-run --mode complement-sp` from a real terminal renders `[INSTALL]` lines in green and `[SKIP - conflicts_with:superpowers]` lines in yellow.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
