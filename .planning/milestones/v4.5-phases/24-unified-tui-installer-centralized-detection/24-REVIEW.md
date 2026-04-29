---
phase: 24-unified-tui-installer-centralized-detection
reviewed: 2026-04-29T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - .github/workflows/quality.yml
  - docs/INSTALL.md
  - Makefile
  - manifest.json
  - scripts/install-statusline.sh
  - scripts/install.sh
  - scripts/lib/detect2.sh
  - scripts/lib/dispatch.sh
  - scripts/lib/tui.sh
  - scripts/setup-security.sh
  - scripts/tests/test-install-tui.sh
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-04-29
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 24 introduces the unified TUI install orchestrator (`scripts/install.sh`), centralized detection (`scripts/lib/detect2.sh`), a Bash 3.2-compatible TUI checklist (`scripts/lib/tui.sh`), and a per-component dispatcher (`scripts/lib/dispatch.sh`). Supporting changes update `manifest.json`, `docs/INSTALL.md`, `Makefile`, `scripts/setup-security.sh` (DISPATCH-02 `--yes` symmetry), `scripts/install-statusline.sh` (DISPATCH-02 `--yes` symmetry), and the integration test suite `scripts/tests/test-install-tui.sh`.

The code is architecturally sound. The three libraries correctly avoid `set -euo pipefail` (sourced-file constraint), the TUI cleanup trap is registered before `_tui_enter_raw` (TUI-03 noted in comments), and the dispatch seam pattern is well-documented and comprehensively tested.

The following findings are all low-to-medium severity. No critical (security/crash/data loss) issues were found.

## Warnings

### WR-01: `eval` usage with a user-controllable installation command

**File:** `scripts/lib/dispatch.sh:98` and `scripts/lib/dispatch.sh:128`

**Issue:** `dispatch_superpowers` and `dispatch_gsd` call `eval "$TK_SP_INSTALL_CMD"` / `eval "$TK_GSD_INSTALL_CMD"` to invoke the install commands. `TK_SP_INSTALL_CMD` and `TK_GSD_INSTALL_CMD` are set from environment variables when the caller supplies them. An environment variable injection — e.g. a user exports `TK_SP_INSTALL_CMD='rm -rf ~'` before running `install.sh` — causes arbitrary command execution.

The default values are safe bash strings, but the guard only prevents redefinition if the variable is already set; it does not sanitize the value:

```bash
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
```

Because these commands already contain shell-pipe constructs (`bash <(curl ...)`), `eval` is genuinely required to execute them — but the env-var injection surface should be documented. Alternatively, the default commands could be executed via a fixed code path, reserving `eval` only for the override case.

**Fix:** Document that `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` are trusted installer inputs (not user-input fields), and add a comment warning authors not to populate them from untrusted data. If a stricter approach is needed, remove the env-var shortcut path and only honor `TK_DISPATCH_OVERRIDE_*` (the explicit test seam), routing the default through a hardcoded `bash <(curl ...)` call that cannot be overridden via environment:

```bash
dispatch_superpowers() {
    ...
    if [[ "$dry_run" -eq 1 ]]; then
        echo "[+ INSTALL] superpowers (would run: $TK_SP_INSTALL_CMD)"
        return 0
    fi
    # Execute default command directly — not via eval — to avoid injection.
    claude plugin install superpowers@claude-plugins-official
}
```

---

### WR-02: `_tui_enter_raw` and cursor hide write to hard-coded `/dev/tty`, bypassing the `TK_TUI_TTY_SRC` test seam

**File:** `scripts/lib/tui.sh:55` and `scripts/lib/tui.sh:69`

**Issue:** `_tui_enter_raw` sends `printf '\e[?25l'` to `/dev/tty` (not `$tty_target`) and `stty` reads from `$tty_target` correctly. Likewise `_tui_restore` sends `printf '\e[?25h'` to `/dev/tty`. In tests that override `TK_TUI_TTY_SRC` to a file path (e.g. a FIFO or a temp file), the cursor visibility escape sequences are sent to the real `/dev/tty`, which leaks test-time terminal state changes out of the sandbox. If the test runs in a CI environment without `/dev/tty` (e.g. inside a Docker container), the `|| true` suppresses failures, but it also means the cursor-hide is silently skipped while stty is attempted on the override path — inconsistent behavior between seam and real execution.

```bash
# Line 55 — hard-coded /dev/tty, not tty_target:
printf '\e[?25l' > /dev/tty 2>/dev/null || true   # hide cursor
stty -icanon -echo <"$tty_target" 2>/dev/null || true
```

**Fix:** Use `$tty_target` consistently for all TTY I/O in `_tui_enter_raw` and `_tui_restore`:

```bash
_tui_enter_raw() {
    local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"
    _TUI_SAVED_STTY=$(stty -g <"$tty_target" 2>/dev/null || echo "")
    printf '\e[?25l' > "$tty_target" 2>/dev/null || true
    stty -icanon -echo <"$tty_target" 2>/dev/null || true
}
```

Apply the same fix to `_tui_restore` line 69 (`printf '\e[?25h' > /dev/tty`).

---

### WR-03: `_tui_render` writes all output to hard-coded `/dev/tty`, not to the `TK_TUI_TTY_SRC` seam

**File:** `scripts/lib/tui.sh:103` and throughout `_tui_render`

**Issue:** Every `printf` in `_tui_render` targets `/dev/tty` directly:

```bash
printf '\e[H\e[J' > /dev/tty 2>/dev/null || true
...
printf '%s%s %s\n' "$arrow" "$box" "$label" > /dev/tty 2>/dev/null || true
```

This means the rendered TUI is never visible in tests that redirect `TK_TUI_TTY_SRC` to a file and capture `install.sh`'s combined stdout+stderr. More importantly, test S3_yes through S9 in `test-install-tui.sh` bypass the TUI entirely via `--yes` or `TK_TUI_TTY_SRC=/dev/null`, so the render path is not exercised by the current test suite. The hard-coding prevents future tests from inspecting rendered output.

**Fix:** Use `local tty_target="${TK_TUI_TTY_SRC:-/dev/tty}"` at the top of `_tui_render` and pipe all `printf` calls to `"$tty_target"` instead of `/dev/tty`. This is the same seam pattern already used by `_tui_read_key`.

---

### WR-04: `tui_checklist` traps `EXIT` permanently and removes it only after normal exit — SIGTERM during `_tui_restore` can leave terminal in raw mode

**File:** `scripts/lib/tui.sh:190-245`

**Issue:** The trap is registered with:

```bash
trap '_tui_restore || true' EXIT INT TERM
```

and cleared with:

```bash
trap - EXIT INT TERM
```

However, if `_tui_restore` itself is interrupted mid-execution (e.g. a second SIGTERM arrives while the first handler is running), the terminal stty restore and cursor-show can be partially applied, leaving the terminal in a degraded state. This is an uncommon edge case but worth noting because `stty sane` is the standard recovery.

Additionally, the `EXIT` trap set here overwrites any `EXIT` trap set by the parent script (`install.sh`). `install.sh` sets its own `run_cleanup` EXIT trap to remove tmpfiles. When `tui_checklist` sets `trap '_tui_restore || true' EXIT`, the parent's `run_cleanup` trap is replaced. After `tui_checklist` clears it with `trap - EXIT`, the parent's cleanup trap is gone too. This means tmpfiles registered in `CLEANUP_PATHS` before the TUI call are not cleaned up if the process exits after the TUI returns normally.

**Fix:** Save and restore the parent EXIT trap:

```bash
_PARENT_EXIT_TRAP=$(trap -p EXIT)
trap '_tui_restore || true' EXIT INT TERM
...
_tui_restore
# Restore parent trap (or clear if it was empty).
if [[ -n "$_PARENT_EXIT_TRAP" ]]; then
    eval "$_PARENT_EXIT_TRAP"
else
    trap - EXIT
fi
trap - INT TERM
```

---

## Info

### IN-01: `setup-security.sh` — argument parsing uses a `for _arg` loop instead of `while [[ $# -gt 0 ]]` + `shift` (inconsistency with project style)

**File:** `scripts/install-statusline.sh:20-25`

**Issue:** `install-statusline.sh` uses `for _arg in "$@"` to parse flags, while all other scripts in this codebase (including `setup-security.sh` and `install.sh`) use `while [[ $# -gt 0 ]]; do ... shift; done`. The `for` loop works correctly for simple parsing but prevents accumulating unknown flags or passing remaining arguments forward. More importantly the project's documented style (CLAUDE.md) is the `while/shift` pattern.

**Fix:** Align with project style:

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) YES=1 ;;
        *) echo -e "${YELLOW}⚠${NC} unknown flag: $1 (ignoring)" ;;
    esac
    shift
done
```

---

### IN-02: `detect2.sh` — `source "$(... && pwd || pwd)/../detect.sh"` silently succeeds with wrong path on `dirname` failure

**File:** `scripts/lib/detect2.sh:34`

**Issue:** The source path construction uses:

```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)/../detect.sh"
```

If `BASH_SOURCE[0]` is empty (e.g. `eval`-sourced in some shells) and `dirname ""` fails, `cd "" && pwd` fails silently and falls back to `|| pwd`, which returns the *current working directory* — not the script directory. This causes the `../detect.sh` path to resolve relative to `$PWD`, which may or may not be the repo root. In normal usage this is fine, but it is a subtle correctness risk when the library is sourced from unexpected contexts.

**Fix:** Add explicit error handling:

```bash
_detect2_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" \
    || { echo "detect2.sh: cannot determine script dir" >&2; return 1; }
source "${_detect2_dir}/../detect.sh"
```

---

### IN-03: `install.sh` — `SELECTION_RC=$?` after `tui_checklist` always captures `0` because the `if ! tui_checklist` branch returns early on failure

**File:** `scripts/install.sh:195-196`

**Issue:**

```bash
if ! tui_checklist; then
    echo "Install cancelled."
    exit 0
fi
# shellcheck disable=SC2034  # SELECTION_RC reserved for future use
SELECTION_RC=$?
```

After the `if ! tui_checklist` block, `$?` is always 0 — because if `tui_checklist` returned non-zero, execution would have already exited. `SELECTION_RC` is explicitly marked `reserved for future use` via the shellcheck disable, so this is not a current bug. However, it introduces dead/misleading code.

**Fix:** Remove the assignment or restructure to capture the actual return code:

```bash
tui_rc=0
tui_checklist || tui_rc=$?
if [[ "$tui_rc" -ne 0 ]]; then
    echo "Install cancelled."
    exit 0
fi
```

---

### IN-04: `test-install-tui.sh` — S4_dry_run assertion pattern is overly broad and will produce a false pass

**File:** `scripts/tests/test-install-tui.sh:242`

**Issue:**

```bash
assert_not_contains "installed" "$OUTPUT" "S4_dry_run: summary must NOT contain 'installed' state (false-positive guard)"
```

The string `"installed"` also matches the header line `"Installing selected components..."` printed by `install.sh` line 293. If that header is present in `$OUTPUT`, this assertion will fail spuriously. In practice `NO_COLOR=1` is set, so ANSI codes won't confuse the match, but the word "Installing" contains "installed" as a substring ... actually it does not (Installing vs installed — different). However, the assertion does match "already installed" or any component description containing "installed". A more precise pattern would be `"installed ✓"` matching only the summary state string.

**Fix:** Use the exact state string produced by `print_install_status`:

```bash
assert_not_contains "installed ✓" "$OUTPUT" "S4_dry_run: summary must NOT show 'installed ✓' state under --dry-run"
```

---

### IN-05: `manifest.json` version field (`4.4.0`) does not reflect the v4.5 work introduced in this phase

**File:** `manifest.json:3`

**Issue:** `manifest.json` declares `"version": "4.4.0"` and `"updated": "2026-04-27"`, yet Phase 24 introduces new distributable files (`scripts/install.sh`, `scripts/lib/detect2.sh`, `scripts/lib/dispatch.sh`, `scripts/lib/tui.sh`) that are now listed in the `"scripts"` and `"libs"` sections. The `version-align` CI check (Makefile:247) validates that `manifest.json` version == `CHANGELOG.md` top entry == `init-local.sh --version`. If `CHANGELOG.md` or `init-local.sh` already carry `4.5.0`, this field will cause the CI gate to fail. If they also still say `4.4.0`, the version is consistent but silently misrepresents the new release.

**Fix:** Bump `manifest.json` version (and `updated`) to match the target release version for Phase 24 before merging. Confirm alignment via `make version-align`.

---

_Reviewed: 2026-04-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
