---
phase: 09-backup-detection
reviewed: 2026-04-24T18:15:47Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - scripts/lib/backup.sh
  - scripts/lib/install.sh
  - scripts/detect.sh
  - scripts/update-claude.sh
  - scripts/migrate-to-complement.sh
  - scripts/tests/test-clean-backups.sh
  - scripts/tests/test-backup-lib.sh
  - scripts/tests/test-backup-threshold.sh
  - scripts/tests/test-detect-cli.sh
  - scripts/tests/test-detect-skew.sh
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-04-24T18:15:47Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 9 ships BACKUP-01 (`--clean-backups`), BACKUP-02 (threshold warning), DETECT-06 (`claude plugin list --json` cross-check), and DETECT-07 (version-skew warning). The implementation is largely correct and the key invariants hold:

- No `set -euo pipefail` in either sourced lib (`backup.sh`, `install.sh`) — correct
- DETECT-06 is SP-only; `detect_gsd` stays filesystem-only — correct
- `warn_version_skew` is present in `update-claude.sh` only; D-22 scope lock confirmed (not in `init-claude.sh` or `migrate-to-complement.sh`)
- `warn_version_skew` reads `.detected.superpowers.version` / `.detected.gsd.version` (state schema v2) — correct
- `rm -rf` in `run_clean_backups` is gated by the `case` name-pattern guard — correct defense-in-depth
- `< /dev/tty` fallback to stdin with fail-closed default `N` — correct

Three warnings were found, none security-critical. Four informational items are also noted.

## Warnings

### WR-01: EXIT trap at line 876 omits `$LIB_BACKUP_TMP` and `$LIB_OPTIONAL_PLUGINS_TMP` (resource leak)

**File:** `scripts/update-claude.sh:876`

**Issue:** The final EXIT trap registration (after `write_state`) replaces the prior trap at line 569. It omits both `$LIB_BACKUP_TMP` and `$LIB_OPTIONAL_PLUGINS_TMP` from the `rm -f` list. If the script exits after this point (e.g., `jq` pipe failure at line 877, or normal exit), those two temp files are orphaned under `$TMPDIR`.

The line 569 trap also omits `$LIB_OPTIONAL_PLUGINS_TMP` (present at line 56 original trap, absent at 569).

The temp files are sourced libs and contain no secrets, so this is not a security issue — but on low-disk systems or in tight CI loops, orphaned `/tmp/optional-plugins.*` and `/tmp/backup.*` files accumulate.

**Fix:** Consolidate all temp-file paths into a single variable or array at the top, then reference it in every trap registration:

```bash
# At setup (near line 56):
_TK_TMPFILES=("$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" \
               "$LIB_OPTIONAL_PLUGINS_TMP" "$LIB_BACKUP_TMP" "$MANIFEST_TMP")

# Line 569 trap:
trap 'release_lock; rm -f "${_TK_TMPFILES[@]}"' EXIT

# Line 876 trap:
trap 'rm -f "$STATE_TMP"; release_lock; rm -f "${_TK_TMPFILES[@]}"' EXIT
```

---

### WR-02: `run_clean_backups` increments `idx` for unmatched dirs, skewing `--keep=N` accounting

**File:** `scripts/update-claude.sh:189`

**Issue:** The `case` arm at line 189 handles the hypothetical scenario where a dir returned by `list_backup_dirs` does not match either backup pattern:

```bash
*) idx=$((idx + 1)); continue ;;
```

`list_backup_dirs` already filters to matching names, so under normal operation no unmatched dir ever reaches this branch. However, if a race condition occurs (a dir with a matching prefix but non-conformant suffix is created between the two `find` calls), `idx` is incremented for the unmatched entry, causing subsequent real backup dirs to be classified as if they were one slot further back. This makes `--keep=N` keep fewer dirs than specified (off-by-one in the keep window).

The `continue` skips the `idx++` at line 225 — but the branch itself does `idx=$((idx+1))` before `continue`, so the net effect is the same: `idx` advances for non-removable entries.

**Fix:** Do not increment `idx` for unmatched/skipped entries; they should not count toward the keep window:

```bash
# Replace:
*) idx=$((idx + 1)); continue ;;

# With:
*) continue ;;
```

---

### WR-03: `test-backup-threshold.sh` comment contradicts implementation — `python3` dependency in test helper

**File:** `scripts/tests/test-backup-threshold.sh:120-122`

**Issue:** The comment on line 120 explicitly states the hash is hardcoded to avoid a `python3` dependency, but line 122 immediately calls `python3` to compute the hash dynamically:

```bash
# sha256 of "debug-content" — hardcoded to avoid dependency on python3 here
local h
h=$(python3 -c 'import hashlib; print(hashlib.sha256(b"debug-content").hexdigest())')
```

When `python3` is unavailable (e.g., minimal CI image), `h` will be empty, the `jq` call will set `sha256: ""` in the state file, and `scenario_migrate_warns` may behave unexpectedly — either the duplicate detection logic skips the hash-mismatch check (empty stored hash is ignored by `prompt_duplicate_file`'s Pitfall 11 guard) or the test passes for the wrong reason.

**Fix:** Either hardcode the known hash (the SHA-256 of `"debug-content\n"` is `e3d5241234ee25dcb7a3a26afd16b01c3c06ef7b2e28e6a11d12765f63e685c9`) and remove the `python3` call, or remove the misleading comment and rely on `python3` being available (consistent with the project's CLAUDE.md constraint of Python 3.8+):

```bash
# Option A — hardcode:
# sha256 of "debug-content\n" (echo produces trailing newline)
h="e3d5241234ee25dcb7a3a26afd16b01c3c06ef7b2e28e6a11d12765f63e685c9"

# Option B — remove misleading comment, keep python3 call:
h=$(python3 -c 'import hashlib; print(hashlib.sha256(b"debug-content\n").hexdigest())')
```

Note: verify which variant (`b"debug-content"` vs `b"debug-content\n"`) matches how `echo "debug-content" > file` writes the file to avoid a latent hash mismatch in the test fixture.

---

## Info

### IN-01: Redundant `-o -name '.claude-backup-pre-migrate-*'` in `find` predicates

**File:** `scripts/lib/backup.sh:38,50`

**Issue:** The pattern `.claude-backup-pre-migrate-*` is a strict subset of `.claude-backup-*`. The second `-o` condition in both `find` calls within `backup.sh` (lines 38 and 50) never matches anything that the first condition doesn't already match. This is harmless but misleading — a reader might infer these are disjoint patterns.

**Fix:** Simplify to a single pattern:

```bash
find "$home" -maxdepth 1 -type d -name '.claude-backup-*' 2>/dev/null
```

The `case` statement in `list_backup_dirs` (and in `run_clean_backups`) already correctly classifies regular vs pre-migrate dirs at the logic level.

---

### IN-02: `detect_superpowers` — `xargs -I{} basename {}` is an unnecessary subprocess chain

**File:** `scripts/detect.sh:44`

**Issue:** The version extraction at line 43–44 uses:

```bash
| sort -V | tail -1 | xargs -I{} basename {}
```

`xargs -I{}` spawns a subprocess per item. Since only one path reaches `xargs` (after `tail -1`), this works, but `basename` can be called directly via command substitution without `xargs`:

```bash
ver=$(find "$SP_PLUGIN_DIR" ... | sort -V | tail -1)
ver=$(basename "$ver")
```

This also avoids the edge case where `xargs` receives an empty input (when `find` returns nothing and `tail -1` emits nothing) and silently calls `basename ""` instead of returning an empty string — though in practice the `[[ -z "$ver" ]]` guard below catches this.

**Fix:**

```bash
ver=$(find "$SP_PLUGIN_DIR" -mindepth 1 -maxdepth 1 -not -name '.*' -type d 2>/dev/null \
    | sort -V | tail -1)
[[ -n "$ver" ]] && ver=$(basename "$ver")
```

---

### IN-03: `VERBOSE` flag in `migrate-to-complement.sh` reserved but not fully wired

**File:** `scripts/migrate-to-complement.sh:41,413`

**Issue:** `VERBOSE` is parsed from `--verbose/-v` at line 26, silenced with `: "$VERBOSE"` at line 41, and checked at line 413. Only one `log_info` call is guarded by `[[ $VERBOSE -eq 1 ]]`. The flag is documented in the usage header as providing "expand output" but its effect is effectively a no-op beyond that single line. This is not a bug (the comment at line 40 says "reserved for Plan 05-03") but it creates a user-visible flag with no meaningful effect, which is confusing.

**Fix:** Either remove `--verbose` from the public usage header until the implementation is complete, or add a note to the header that the flag is a no-op in the current release.

---

### IN-04: Test `test-detect-skew.sh` scenario 5 sources `install.sh` without `STATE_FILE` dependency satisfied

**File:** `scripts/tests/test-detect-skew.sh:165-174`

**Issue:** Scenario 5 sources `install.sh` directly in a sub-shell and calls `warn_version_skew` with `STATE_FILE=/nonexistent/path`. The function guards on `[[ -f "${STATE_FILE:-}" ]] || return 0`, so the test passes correctly. However, the sub-shell also sources `install.sh` without first sourcing `detect.sh`, so `SP_VERSION` and `GSD_VERSION` are set as bare shell variables rather than exports. This works because `warn_version_skew` accesses them via `${SP_VERSION:-}` (with default), but it means the test does not reproduce the actual call contract (caller must have sourced `detect.sh` first, per the function's own comment at line 231).

This is a test design observation only — the test correctly verifies the no-STATE_FILE path and there is no runtime correctness issue.

**Fix:** No code change required. Add a comment in the test clarifying that `SP_VERSION`/`GSD_VERSION` are set directly as a testing shortcut, not requiring `detect.sh`.

---

_Reviewed: 2026-04-24T18:15:47Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
