---
phase: 24-unified-tui-installer-centralized-detection
fixed_at: 2026-04-29T15:33:47Z
review_path: .planning/milestones/v4.5-phases/24-unified-tui-installer-centralized-detection/24-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 24: Code Review Fix Report

**Fixed at:** 2026-04-29T15:33:47Z
**Source review:** `.planning/milestones/v4.5-phases/24-unified-tui-installer-centralized-detection/24-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope: 4 (CR + WR; IN findings excluded per `fix_scope=critical_warning`)
- Fixed: 4
- Skipped: 0
- Verification: `bash -n` syntax checks PASS for both files; `bash scripts/tests/test-install-tui.sh` PASS=43 FAIL=0; `make shellcheck` PASS

## Fixed Issues

### WR-01: `eval` usage with a user-controllable installation command

**Files modified:** `scripts/lib/dispatch.sh`
**Commit:** 4d9af0f
**Applied fix:** Added a SECURITY comment block above the `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` assignments documenting that these env-controlled strings are TRUSTED installer inputs (passed to `eval` to support `bash <(curl ...)` constructs), MUST NOT be populated from untrusted data, and that test injection should use `TK_DISPATCH_OVERRIDE_SUPERPOWERS` / `_GSD` (which take a script path and execute via `bash <path>`, no `eval`). The reviewer's stricter alternative (hardcode default + remove env shortcut) was not adopted: the existing `TK_DISPATCH_OVERRIDE_*` seam is already the safer test path, and the env-var shortcut is needed for fork/mirror overrides documented elsewhere. Documentation matches reviewer's primary recommendation.

### WR-02: `_tui_enter_raw` and cursor hide write to hard-coded `/dev/tty`, bypassing the `TK_TUI_TTY_SRC` test seam

**Files modified:** `scripts/lib/tui.sh`
**Commit:** 618ced1
**Applied fix:** Changed `printf '\e[?25l' > /dev/tty` (line 55) to `printf '\e[?25l' > "$tty_target"` and `printf '\e[?25h' > /dev/tty` (line 69) to `printf '\e[?25h' > "$tty_target"`. Both functions already had `local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"` at the top, so the cursor escape sequences now route through the same test seam used by `stty` and `_tui_read_key`. Added inline `# WR-02:` comments on both functions. No behavior change in production (default seam = `/dev/tty`).

### WR-03: `_tui_render` writes all output to hard-coded `/dev/tty`, not to the `TK_TUI_TTY_SRC` seam

**Files modified:** `scripts/lib/tui.sh`
**Commit:** d51633c
**Applied fix:** Added `local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"` at the top of `_tui_render`, then replaced all 9 `> /dev/tty` redirections in the function (clear, group header colored/uncolored, item line, help line colored/uncolored, description line colored/uncolored) with `> "$tty_target"`. Added `# WR-03:` comment in the function header explaining the seam pattern matches `_tui_read_key`. Tests S3-S10 still pass (all 43 assertions green) because `--yes` and `TK_TUI_TTY_SRC=/dev/null` paths bypass the render entirely.

### WR-04: `tui_checklist` traps `EXIT` permanently and overwrites parent's EXIT trap

**Files modified:** `scripts/lib/tui.sh`
**Commit:** e58d29a
**Applied fix:** Save the parent's EXIT trap definition with `local _parent_exit_trap; _parent_exit_trap=$(trap -p EXIT 2>/dev/null || echo "")` BEFORE installing `trap '_tui_restore || true' EXIT INT TERM`. After `_tui_restore`, restore the parent trap conditionally: `if [[ -n "$_parent_exit_trap" ]]; then eval "$_parent_exit_trap"; else trap - EXIT; fi`, then `trap - INT TERM`. This preserves caller cleanup (e.g. `install.sh:run_cleanup` for tmpfiles) which was previously silently dropped after `tui_checklist` returned. Reviewer noted the SIGTERM-during-restore edge case as uncommon and worth noting; the implemented save/restore is the standard recovery pattern (`stty sane` already covers terminal recovery via the existing triple-fallback in `_tui_restore`).

## Skipped Issues

None — all in-scope WR findings fixed cleanly.

## Notes on Out-of-Scope (Info) Findings

Per `fix_scope=critical_warning`, the following IN-* findings were NOT addressed in this run:

- **IN-01** — `install-statusline.sh` `for _arg` loop style inconsistency (not a defect; cosmetic alignment with project style).
- **IN-02** — `detect2.sh` source-path edge case when `BASH_SOURCE[0]` is empty (subtle correctness risk only in unusual contexts).
- **IN-03** — `install.sh` `SELECTION_RC=$?` dead code (already annotated `reserved for future use`).
- **IN-04** — `test-install-tui.sh` `assert_not_contains "installed"` substring breadth (currently passes; tighten if future output adds containing strings).
- **IN-05** — `manifest.json` version `4.4.0` → `4.5.0` — **already_fixed in Phase 27** (per orchestrator's note; manifest version bump landed with the v4.5 milestone alignment work).

These can be addressed in a follow-up `fix_scope=all` pass if desired.

---

_Fixed: 2026-04-29T15:33:47Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
