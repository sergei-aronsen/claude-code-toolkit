---
phase: 08-release-quality
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - .github/workflows/quality.yml
  - Makefile
  - docs/INSTALL.md
  - scripts/cell-parity.sh
  - scripts/tests/matrix/lib/helpers.bash
  - scripts/tests/matrix/standalone.bats
  - scripts/tests/matrix/complement-sp.bats
  - scripts/tests/matrix/complement-gsd.bats
  - scripts/tests/matrix/complement-full.bats
  - scripts/tests/matrix/translation-sync.bats
  - scripts/validate-release.sh
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-04-24
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 8 delivers REL-01 (bats matrix port), REL-02 (cell-parity gate), and REL-03
(`--collect-all` aggregated table). The overall structure is solid: helpers.bash is
well-factored with a correct double-source guard and POSIX-safe cell list construction,
bats files follow a clean setup()/source/call/assert pattern, and validate-release.sh's
`--collect-all` implementation is correct. CI is properly pinned to full SHAs.

Three issues require attention before merge:

1. `cell-parity.sh` has a logic error in its guard check that silently passes on a
   non-existent runner under certain file-system states.
2. Complement rerun cells silently swallow `init-local.sh` exit codes, masking failures.
3. `make validate` and the CI `validate-templates` job check different sets of audit
   files — a long-standing gate drift that can hide SECURITY_AUDIT.md regressions
   locally.

---

## Warnings

### WR-01: cell-parity.sh guard uses `&&` instead of `||` — silently skips on non-existent runner

**File:** `scripts/cell-parity.sh:17`

**Issue:** The guard that detects an unusable runner reads:

```bash
if [ ! -x "$RUNNER" ] && [ ! -f "$RUNNER" ]; then
```

With `&&`, the block fires only when _both_ conditions are true: the file is not
executable AND does not exist. If `validate-release.sh` exists on disk but is not
executable (e.g., after a fresh `git clone` with a broken `chmod`, or on a filesystem
that strips +x bits), then `[ ! -x ]` is true but `[ ! -f ]` is false, so the guard
does NOT fire. The script then calls `bash "$RUNNER" --list` which will succeed anyway
because `bash file` ignores the execute bit — so in practice this causes no real
failure today. However the intent of the guard is to fail fast on a missing or unusable
runner, and the current condition does not cover the "file missing" path reliably when
`$RUNNER` points at a symlink or non-regular file that is not executable.

**Fix:** Use `||` to fail on either condition, or simplify to a plain existence check
since `bash` does not require `+x`:

```bash
if [ ! -f "$RUNNER" ]; then
    echo "ERROR: $RUNNER not found" >&2; exit 2
fi
```

---

### WR-02: Complement rerun cells swallow `init-local.sh` exit codes

**File:** `scripts/tests/matrix/lib/helpers.bash:326-327, 367-368, 414-415`

**Issue:** The three complement rerun cell functions (`cell_complement_sp_rerun`,
`cell_complement_gsd_rerun`, `cell_complement_full_rerun`) invoke `init-local.sh` with
`|| true` and never assert the exit code:

```bash
( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) || true
( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) || true
```

By contrast, `cell_standalone_rerun` (lines 280-283) captures `rc` and asserts exit 0
for both the first and second runs. If `init-local.sh` starts exiting non-zero on rerun
for complement modes (e.g., due to a regression in idempotency logic), these cells
will still report PASS because the only assertions that follow check state schema and
skip-list — which may vacuously pass on a partial filesystem state.

**Fix:** Mirror the standalone-rerun pattern:

```bash
cell_complement_sp_rerun() {
    local CH rc
    CH=$(sandbox_setup "complement-sp-rerun")
    stage_sp_cache "$CH"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "first init-local.sh --mode complement-sp exits 0"
    ( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" --mode complement-sp >/dev/null 2>&1 ) && rc=0 || rc=$?
    assert_eq "0" "$rc" "re-run init-local.sh --mode complement-sp exits 0 (idempotent)"
    assert_state_schema "$CH/.claude/toolkit-install.json" "complement-sp"
    assert_skiplist_clean "$CH" "complement-sp"
    assert_no_agent_collision "$CH"
}
```

Apply the same pattern to `cell_complement_gsd_rerun` (lines 363-371) and
`cell_complement_full_rerun` (lines 409-419).

---

### WR-03: `make validate` omits `SECURITY_AUDIT.md` — local gate drifts from CI

**File:** `Makefile:108-111`

**Issue:** The `validate` Makefile target searches only for `PERFORMANCE_AUDIT.md`,
`CODE_REVIEW.md`, and `DEPLOY_CHECKLIST.md` in template prompt directories. The CI
`validate-templates` job (`.github/workflows/quality.yml:48`) additionally includes
`SECURITY_AUDIT.md` in its loop. This means running `make check` locally will not
catch a missing `QUICK CHECK` or `SELF-CHECK` section in any `SECURITY_AUDIT.md`
file, but CI will reject it. Contributors get a false green from `make check`.

**Fix:** Add `SECURITY_AUDIT.md` to the `find` predicate in the `validate` target:

```makefile
for f in $$(find templates -path '*/prompts/*.md' \( \
    -name 'PERFORMANCE_AUDIT.md' -o \
    -name 'SECURITY_AUDIT.md' -o \
    -name 'CODE_REVIEW.md' -o \
    -name 'DEPLOY_CHECKLIST.md' \)); do \
```

---

## Info

### IN-01: `cell_translation_sync` does not sandbox `$HOME` despite INSTALL.md claim

**File:** `scripts/tests/matrix/lib/helpers.bash:422-428`
**Cross-reference:** `docs/INSTALL.md:91`

**Issue:** `docs/INSTALL.md` line 91 states:

> Runs `make translation-drift` under a sandboxed `$HOME` and reports PASS/FAIL.

The actual implementation in `cell_translation_sync` does not override `HOME`:

```bash
cell_translation_sync() {
    local drift_exit
    (
        cd "$REPO_ROOT_ABS"
        make translation-drift >/dev/null 2>&1
    ) && drift_exit=0 || drift_exit=$?
```

`make translation-drift` reads `README.md` and `docs/readme/*.md` from the repo — not
from `$HOME` — so the HOME override is not functionally required for correctness.
However the documentation creates a false expectation. Either remove "under a sandboxed
`$HOME`" from INSTALL.md, or add `HOME="$(mktemp -d)"` to the subshell (consistent with
other cells that override HOME).

**Fix (documentation path):** Update `docs/INSTALL.md:91`:

```markdown
Runs `make translation-drift` in a repo-root subshell and reports PASS/FAIL.
```

---

### IN-02: `validate-release.sh` `self_test()` trap overwrites helpers.bash EXIT trap

**File:** `scripts/validate-release.sh:93`

**Issue:** `helpers.bash` registers `trap cleanup_v3x_worktrees EXIT` at source time
(line 161). When `validate-release.sh` is invoked with `--self-test`, `self_test()`
registers a second EXIT trap at line 93:

```bash
trap 'rm -rf "$TMP"' EXIT
```

In bash, a second `trap ... EXIT` replaces the first. This silently unregisters the
`cleanup_v3x_worktrees` trap. In practice, `self_test()` never calls
`setup_v3x_worktree`, so `CELL_WORKTREES` stays empty and no worktrees leak. The issue
is latent: if a future modification to `self_test()` ever exercises worktree setup, the
cleanup trap will be missing and git worktrees will leak under `/tmp`.

**Fix:** Append rather than replace the EXIT trap:

```bash
trap 'cleanup_v3x_worktrees; rm -rf "$TMP"' EXIT
```

Or use the accumulating pattern:

```bash
_EXISTING_TRAP=$(trap -p EXIT)
trap 'cleanup_v3x_worktrees; rm -rf "$TMP"; '"${_EXISTING_TRAP:-true}" EXIT
```

The simpler fix is sufficient for current usage.

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
