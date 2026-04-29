---
phase: 27-marketplace-publishing-claude-desktop-reach
plan: "03"
subsystem: installer
tags: [bash, install-sh, desktop, skills, tui, desk-03]

requires:
  - phase: 27-01-marketplace-surface
    provides: plugins/tk-skills structure and TK_SKILLS_HOME seam context
  - phase: 27-02-validators-and-make-wiring
    provides: make check gate that plan 03 must keep green

provides:
  - scripts/install.sh --skills-only flag (explicit opt-in)
  - DESK-03 auto-routing: CLI-absent users land in skills-only mode automatically
  - TK_SKILLS_HOME export redirecting skills to ~/.claude/plugins/tk-skills/
  - Desktop banner: "Claude CLI not detected — installing skills only."
  - S10 hermetic test proving the auto-route path end-to-end

affects:
  - docs/CLAUDE_DESKTOP.md (referenced in banner text)
  - future plans touching install.sh routing

tech-stack:
  added: []
  patterns:
    - "DESK-03 detection pattern: command -v claude >/dev/null 2>&1 as CLI probe"
    - "Deferred _source_lib skills call: source after auto-route block so DESK-03 can set SKILLS=1"
    - "TK_SKILLS_HOME env-var seam: already in skills.sh; installer sets it before skills branch"

key-files:
  created: []
  modified:
    - scripts/install.sh
    - scripts/tests/test-install-tui.sh

key-decisions:
  - "Move _source_lib skills to after DESK-03 block so auto-route (which sets SKILLS=1 late) also loads skills.sh"
  - "Use non-existent TK_TUI_TTY_SRC path in S10 (not readable) to trigger clean no-TTY exit rather than tui.sh /dev/tty errors"
  - "Mutex check updated to only reject --mcps + --skills when SKILLS_ONLY=0, allowing --skills-only to set SKILLS=1 without triggering the error"
  - "Auto-route does NOT fire when --yes is passed (CI/non-interactive paths keep components branch)"

patterns-established:
  - "Desktop-routing pattern: TK_DESKTOP_ONLY=1 + AUTO_SKILLS_ONLY=1 variables gate banner and redirection separately"
  - "Skills lib sourcing: always happens after DESK-03 block, conditional on SKILLS=1"

requirements-completed: [DESK-03]

duration: 8min
completed: 2026-04-29
---

# Phase 27 Plan 03: install.sh Desktop Routing Summary

**`--skills-only` flag + DESK-03 auto-routing wired into `scripts/install.sh`: CLI-absent users auto-promoted to skills-only mode with skills landing in `~/.claude/plugins/tk-skills/`, hermetically tested by new S10 scenario**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-29T14:40:46Z
- **Completed:** 2026-04-29T14:47:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `--skills-only` flag to `scripts/install.sh` argparse (sets `SKILLS_ONLY=1` + `SKILLS=1`)
- Implemented DESK-03 auto-detection block: `command -v claude` probe sets `TK_DESKTOP_ONLY=1`; when CLI absent + no page flags + no `--yes`, auto-promotes to skills-only and prints documented banner
- Exports `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` before skills branch runs, redirecting install target to Desktop plugin tree (zero changes to `scripts/lib/skills.sh` — existing seam honored)
- Added S10 hermetic test with 5 assertions proving auto-route path end-to-end; total test assertions went from 38 to 43

## Task Commits

1. **Task 1: --skills-only flag + Desktop auto-routing block** - `95890c0` (feat)
2. **Task 2: S10 hermetic test scenario** - `fbab138` (test)

## Files Created/Modified

- `scripts/install.sh` - Added `SKILLS_ONLY=0` default, `--skills-only` argparse case, `--help` entry, DESK-03 auto-detection block, `TK_SKILLS_HOME` export, conditional removal hint, deferred `_source_lib skills` call
- `scripts/tests/test-install-tui.sh` - Added `run_s10_desktop_auto_skills_only_routing` function and runner invocation

## Decisions Made

- **Deferred `_source_lib skills`**: Originally the skills lib was sourced at argparse-completion time (when `SKILLS=1`). DESK-03 sets `SKILLS=1` after argparse, so the source had to move to after the auto-route block. This is the key architectural fix that resolved the S7 regression (exit 127).
- **Non-existent TTY path in S10**: Using a non-existent file path for `TK_TUI_TTY_SRC` causes `[[ ! -r ]]` to be true, triggering "No TTY available for skills TUI" exit cleanly. A readable empty file would pass `-r` and try to render the TUI (hitting `/dev/tty` errors).
- **Mutex check**: Changed `MCPS=1 && SKILLS=1` mutex to additionally check `SKILLS_ONLY=0`, so `--skills-only` setting `SKILLS=1` doesn't incorrectly trigger the mutex error.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] S7 regression: exit 127 when `_source_lib skills` was called before DESK-03 block**

- **Found during:** Task 1 verification (running test-install-tui.sh after initial edit)
- **Issue:** The original plan placed the DESK-03 block after the `if [[ "$SKILLS" -eq 1 ]]; then _source_lib skills` call. S7 has no `claude` on PATH and no `--yes` → DESK-03 auto-route fires and sets `SKILLS=1` → the skills branch then calls `skills_status_array` which is undefined because skills.sh was never sourced (SKILLS was 0 at source-time). Result: exit 127.
- **Fix:** Moved `_source_lib skills` call to after the DESK-03 block, conditional on `SKILLS=1` (which now covers both explicit `--skills`/`--skills-only` and auto-route). Added explanatory comment.
- **Files modified:** scripts/install.sh
- **Verification:** `bash scripts/tests/test-install-tui.sh` went from PASS=37 FAIL=1 back to PASS=38 FAIL=0
- **Committed in:** 95890c0 (Task 1 commit)

**2. [Rule 1 - Bug] S10/A3 failed: `bash` not found when PATH="$FAKE_PATH" stripped /bin**

- **Found during:** Task 2 first run
- **Issue:** S10 used `PATH="$FAKE_PATH"` without `/usr/bin:/bin`, so `bash` itself was not found. All 5 assertions failed with "Permission denied" then "command not found: bash".
- **Fix:** Changed to `PATH="$FAKE_PATH:/usr/bin:/bin"` (matching the S1-S9 convention that keeps system tools available while omitting real `claude`).
- **Files modified:** scripts/tests/test-install-tui.sh
- **Committed in:** fbab138 (Task 2 commit)

**3. [Rule 1 - Bug] S10/A3 assertion target wrong: empty file passes `-r` check**

- **Found during:** Task 2 second run (after fixing PATH)
- **Issue:** Plan's S10 template used an empty TTY fixture file. `[[ -r "$file" ]]` is true for a readable empty file, so the skills branch proceeded to `tui_checklist` which opened `/dev/tty` directly (not `TK_TUI_TTY_SRC`) — producing device errors rather than "No TTY available for skills TUI".
- **Fix:** Changed `TTY_FIXTURE` to a non-existent path (`$SANDBOX/no-such-tty`). `! -r` is true → "No TTY available for skills TUI" printed → exit 0.
- **Files modified:** scripts/tests/test-install-tui.sh
- **Committed in:** fbab138 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 bugs)
**Impact on plan:** All fixes necessary for correctness. Net result matches plan intent exactly; only the TTY fixture mechanism and source-lib ordering differed from the template.

## Tests Passing

| Test file | PASS | FAIL | Notes |
|---|---|---|---|
| test-install-tui.sh | 43 | 0 | +5 from S10 (was 38) |
| test-bootstrap.sh | 26 | 0 | unchanged |
| test-mcp-selector.sh | 21 | 0 | unchanged |
| test-install-skills.sh | 15 | 0 | unchanged |
| make check | — | 0 | All checks passed |

## Behavioral Diff (before vs after)

**Before (CLI-absent user runs `bash scripts/install.sh`):**
- If no TTY: fork to bootstrap.sh for SP/GSD; TK components skipped
- If TTY available: full components TUI rendered (but nothing useful for Desktop user)

**After (DESK-03):**
- `command -v claude` returns non-zero → `TK_DESKTOP_ONLY=1`
- If no explicit page flags and no `--yes`: auto-promote to `--skills-only`, print banner:
  ```
  ! Claude CLI not detected — installing skills only.
    Skills available in Claude Desktop Code tab.
    See docs/CLAUDE_DESKTOP.md for full capability matrix.
  ```
- `TK_SKILLS_HOME=$HOME/.claude/plugins/tk-skills` exported
- Skills TUI shown (or "No TTY available" if non-interactive)
- Skills land in Desktop plugin tree, not `~/.claude/skills/`

## Known Stubs

None — skills land in real `TK_SKILLS_HOME` location; no hardcoded empty values flow to UI.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. `TK_SKILLS_HOME` is set from a hardcoded safe path (`$HOME/.claude/plugins/tk-skills`), not from user input.

## Next Phase Readiness

- DESK-03 complete; Desktop-only users auto-routed to skills
- `docs/CLAUDE_DESKTOP.md` (referenced in banner) was delivered in plan 27-01
- Phase 27 all three plans complete

## Self-Check

### Files exist

- `scripts/install.sh` — modified (yes, committed at 95890c0)
- `scripts/tests/test-install-tui.sh` — modified (yes, committed at fbab138)

### Commits exist

- 95890c0: feat(27-03): add --skills-only flag + Desktop auto-routing
- fbab138: test(27-03): add S10 Desktop auto-routing scenario

## Self-Check: PASSED

---
*Phase: 27-marketplace-publishing-claude-desktop-reach*
*Completed: 2026-04-29*
