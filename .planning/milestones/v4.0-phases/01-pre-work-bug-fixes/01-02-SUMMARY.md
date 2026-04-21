---
phase: 01-pre-work-bug-fixes
plan: "02"
subsystem: infra
tags: [bash, shell, tty, interactive, setup-council, security]

requires: []
provides:
  - setup-council.sh with /dev/tty guards on all three interactive read calls
  - Early non-interactive guard that exits cleanly under curl | bash
affects:
  - 01-03 (BUG-03 JSON-escape fix also touches setup-council.sh)
  - Any plan that validates setup-council.sh invocation patterns

tech-stack:
  added: []
  patterns:
    - "read -rs -p ... < /dev/tty 2>/dev/null || true for silent optional API key prompts"
    - "if ! read -r -p ... < /dev/tty 2>/dev/null; then VAR=default; fi for choice prompts with defaults"
    - "[[ ! -r /dev/tty ]] early guard before any interactive section"

key-files:
  created: []
  modified:
    - scripts/setup-council.sh

key-decisions:
  - "Use if ! read ... form for GEMINI_CHOICE (has default) and || true form for API keys (optional, skippable)"
  - "Switch API key reads from -r to -rs (silent mode, D-08) to prevent shoulder-surf / scroll-back disclosure"
  - "Place early guard after COUNCIL_DIR variable, before the banner echo — fails loudly before any output"

patterns-established:
  - "Pattern BUG-02: All interactive read calls in installer scripts must redirect from /dev/tty, not stdin"
  - "Pattern D-08: API key read prompts use -rs (silent) to suppress echo"

requirements-completed:
  - BUG-02

duration: 5min
completed: "2026-04-17"
---

# Phase 01 Plan 02: /dev/tty Guards for setup-council.sh Summary

**Three interactive `read` calls in `setup-council.sh` patched with `< /dev/tty 2>/dev/null`
and an early `[[ ! -r /dev/tty ]]` guard added, fixing `curl | bash` hang and API key echo disclosure**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-17T12:53:00Z
- **Completed:** 2026-04-17T12:53:51Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `[[ ! -r /dev/tty ]]` guard after color constants, before banner — script exits with clear
  error message when run under `curl | bash` or in CI (no tty available)
- Patched GEMINI_CHOICE prompt (`if ! read ... < /dev/tty 2>/dev/null` with default fallback)
- Patched GEMINI_KEY and OPENAI_KEY prompts with `read -rs` (silent) and `< /dev/tty 2>/dev/null || true`
- API keys no longer echo to terminal (D-08 shoulder-surf mitigation)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add early non-interactive guard** - `87561f7` (fix)
2. **Task 2: Add /dev/tty guards to all three interactive read calls** - `d968b68` (fix)

## Patched Sites (before/after line numbers)

| Site | Variable | Before line | After lines | Form used |
|------|----------|-------------|-------------|-----------|
| 1 | GEMINI_CHOICE | 100 | 100-104 | `if ! read -r -p ... < /dev/tty 2>/dev/null` |
| 2 | GEMINI_KEY | 110 | 110-112 | `read -rs -p ... < /dev/tty 2>/dev/null \|\| true` + `echo ""` |
| 3 | OPENAI_KEY | 141 | 141-143 | `read -rs -p ... < /dev/tty 2>/dev/null \|\| true` + `echo ""` |

Early guard inserted at line 23 (after `COUNCIL_DIR=...`, before banner at line 30).

## Files Created/Modified

- `scripts/setup-council.sh` - Three read calls patched with /dev/tty redirect; early tty guard added

## Decisions Made

- Used `if ! read` form for GEMINI_CHOICE because it has a default value (`1`) that must be applied when
  the read fails (tty unavailable) — matches `init-claude.sh:84` analog exactly
- Used `|| true` form for API key prompts because they are skippable (empty is valid)
- Added `-s` flag to both API key reads (D-08): keys must not echo to screen to prevent shoulder-surf
  and scroll-back disclosure — this is a paired security fix within the same BUG-02 scope
- Early guard placed before the banner so even the visual output is skipped when tty is not available

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `setup-council.sh` is now safe to invoke via `bash <(curl -sSL ...)` — the tty guard and per-read
  redirects prevent curl stream consumption
- Plan 01-03 (BUG-03: JSON-escape API keys) will touch the same file at the heredoc write site

---

## Self-Check: PASSED

- `scripts/setup-council.sh` exists and has been modified: confirmed
- Task 1 commit `87561f7` exists: confirmed via `git log`
- Task 2 commit `d968b68` exists: confirmed via `git log`
- `grep -cE "read -r[s]? .*< /dev/tty 2>/dev/null" scripts/setup-council.sh` = 3: verified
- `grep -c '\[\[ ! -r /dev/tty \]\]' scripts/setup-council.sh` = 1: verified
- `shellcheck scripts/setup-council.sh` exits 0: verified

---

*Phase: 01-pre-work-bug-fixes*
*Completed: 2026-04-17*
