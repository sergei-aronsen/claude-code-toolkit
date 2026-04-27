---
phase: 23-installer-symmetry-recovery
reviewed: 2026-04-27T10:55:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/uninstall.sh
  - scripts/tests/test-install-banner.sh
  - scripts/tests/test-uninstall-keep-state.sh
  - Makefile
  - .github/workflows/quality.yml
  - CHANGELOG.md
  - docs/INSTALL.md
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-04-27T10:55:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 23 introduced three symmetric features across the installer suite: `--no-banner`/`NO_BANNER=1` for `init-claude.sh` and `init-local.sh`, `--keep-state`/`TK_UNINSTALL_KEEP_STATE=1` for `uninstall.sh`, and the accompanying test harness in `test-uninstall-keep-state.sh`.

The shell-script implementation is solid: argument parsers are correct for their respective loop styles (while/$# for init scripts; for/arg for uninstall.sh), the KEEP_STATE env-var precedence uses the correct `${TK_UNINSTALL_KEEP_STATE:-0}` form, the gate (`[[ $KEEP_STATE -eq 0 ]]`) is positioned after sentinel-strip and base-plugin diff-q as required by D-06, and the banner string is byte-identical across all three installers. ShellCheck passes clean on all scripts at `-S warning` severity.

One warning-level issue was found: both `init-claude.sh` and `init-local.sh` advertise `NO_BANNER=1` as a working environment variable equivalent in their help text and in the CHANGELOG/INSTALL.md docs, but neither script actually reads `NO_BANNER` from the environment. The variable is unconditionally initialised to `0` and only set to `1` via the `--no-banner` argparse clause. The equivalent env-var for `--no-bootstrap` (`TK_NO_BOOTSTRAP=1`) is correctly implemented for comparison; `NO_BANNER` is not. Two info items cover a missing gate in the test assertions (the env-var path is never exercised by `test-install-banner.sh`) and a minor documentation inconsistency.

## Warnings

### WR-01: `NO_BANNER=1` env var advertised but not implemented in `init-claude.sh` and `init-local.sh`

**File:** `scripts/init-claude.sh:21` / `scripts/init-local.sh:84`
**Issue:** Both scripts unconditionally initialise `NO_BANNER=0` and only set it to `1` through the `--no-banner` argparse clause. The env var `NO_BANNER=1` is never read from the process environment. Contrast with `TK_NO_BOOTSTRAP=1`, which IS read in the bootstrap guard at line 115 of both scripts using `${TK_NO_BOOTSTRAP:-}`. The CHANGELOG [4.4.0] reads "both installers now accept `--no-banner` (and the `NO_BANNER=1` env var)", the INSTALL.md table column reads "Equivalent env: `NO_BANNER=1`", and `init-local.sh --help` line 121 echoes "env: NO_BANNER=1". All three documentation surfaces are incorrect.

Users running `NO_BANNER=1 bash <(curl ... init-claude.sh)` or `NO_BANNER=1 bash ... init-local.sh` will receive the banner line despite setting the env var.

**Fix:** Apply the same env-read pattern used by `TK_NO_BOOTSTRAP` immediately after the default declaration:

```bash
# In scripts/init-claude.sh (line 21) and scripts/init-local.sh (line 84):
# Change:
NO_BANNER=0

# To:
NO_BANNER=${NO_BANNER:-0}
```

This single-line change makes the env-var path functional without altering the `--no-banner` argparse clause or the gate check. The pattern is already established by `update-claude.sh`, which also reads `NO_BANNER=0` as a default and honours a pre-existing env export (though it too uses the unconditional `NO_BANNER=0` initialisation — it just happens to be overridable via the argparse before the gate fires in the same shell invocation, not across subshell boundaries).

## Info

### IN-01: `test-install-banner.sh` does not test the `NO_BANNER=1` env-var path

**File:** `scripts/tests/test-install-banner.sh:67-101`
**Issue:** Assertions A4-A7 are source-grep checks that verify the three code-level patterns exist (default, argparse clause, gate condition). None of the 7 assertions exercise the env-var path at runtime — no assertion runs either installer with `NO_BANNER=1` in the environment and checks that the banner line is absent from output. This means the gap identified in WR-01 (env var not read) passes all 7 assertions without triggering a test failure. The test suite provides coverage confidence that the patterns exist but not that the env-var contract works end-to-end.

**Fix:** After resolving WR-01, add an assertion that runs `init-local.sh --no-bootstrap --dry-run` (or a minimal invocation) with `NO_BANNER=1` in the environment and confirms the banner line is absent from stdout, matching the runtime contract pattern already used in `test-uninstall-keep-state.sh` S3.

### IN-02: `docs/INSTALL.md` symmetry note contains a subtle inaccuracy

**File:** `docs/INSTALL.md:42`
**Issue:** The `--no-banner` row says "Symmetric with `update-claude.sh` which already honoured this flag." However `update-claude.sh` also uses the unconditional `NO_BANNER=0` initialisation (line 11 of that file) rather than `NO_BANNER=${NO_BANNER:-0}`, so it also does not read the env var from the process environment — the "symmetry" in the note refers to having the flag, not to the env-var path working. This is a minor documentation imprecision; it doesn't introduce a bug but may set incorrect user expectations.

**Fix:** After resolving WR-01 for all three scripts (including `update-claude.sh`), the note becomes accurate and no further change is needed. Alternatively, qualify the note to "Symmetric with `update-claude.sh` (same `--no-banner` flag; env-var path requires the `${NO_BANNER:-0}` form in all three scripts)."

---

_Reviewed: 2026-04-27T10:55:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
