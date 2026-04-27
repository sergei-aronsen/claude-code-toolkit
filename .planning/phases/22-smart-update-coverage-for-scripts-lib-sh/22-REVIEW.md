---
phase: 22-smart-update-coverage-for-scripts-lib-sh
reviewed: 2026-04-27T09:35:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - manifest.json
  - CHANGELOG.md
  - scripts/tests/test-update-libs.sh
  - Makefile
  - .github/workflows/quality.yml
findings:
  critical: 0
  warning: 0
  info: 4
  total: 4
status: clean
---

# Phase 22: Code Review Report

**Reviewed:** 2026-04-27T09:35:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** clean (4 informational notes, no blockers)

## Summary

Phase 22 closes the silent gap where `update-claude.sh` skipped `scripts/lib/*.sh`
helpers (LIB-01..02). Five files changed:

- `manifest.json`: bumped 4.3.0 → 4.4.0; added `files.libs[]` with all six lib paths
- `CHANGELOG.md`: prepended `## [4.4.0] - 2026-04-27` consolidating Phase 21 + 22
- `scripts/tests/test-update-libs.sh`: NEW — 5-scenario hermetic integration test
- `Makefile`: wired Test 29 + standalone `test-update-libs` target
- `.github/workflows/quality.yml`: extended CI step `Tests 21-29` with the new test

**Verification performed during review:**

- `python3 scripts/validate-manifest.py` → PASSED (manifest schema v2 valid;
  `files.libs[]` paths resolve via fallback to repo root; no duplicates)
- `shellcheck -S warning scripts/tests/test-update-libs.sh` → no findings
- `markdownlint CHANGELOG.md` → no findings (MD040/MD031/MD032/MD026 all clean)
- `bash scripts/tests/test-update-libs.sh` → 15/15 PASS
- Idempotency: two consecutive runs produced identical PASS=15 FAIL=0
- bash 3.2 portability: `trap … RETURN` confirmed function-scoped on Darwin's
  `GNU bash 3.2.57(1)-release` (per-function cleanup; no trap leakage)
- Regression coverage: S1 actively detects "skip-libs" regressions because the
  manifest fixture and `TK_UPDATE_LIB_DIR` seam force the lib through the
  manifest-driven update loop; if the loop reverted to ignoring `files.libs[]`
  the post-update SHA assertion would fail with the stale-canary content.

**Security posture:**

- `manifest.json` is pure data — no exec content, no secrets, no shell-injectable strings
- Test seam env vars (`TK_UPDATE_HOME`, `TK_UPDATE_FILE_SRC`,
  `TK_UPDATE_MANIFEST_OVERRIDE`, `TK_UPDATE_LIB_DIR`, `TK_UNINSTALL_HOME`,
  `TK_UNINSTALL_LIB_DIR`) are caller-controlled and only consulted inside the
  toolkit's own scripts. The test points all of them at `mktemp -d /tmp/...`
  sandboxes and `$REPO_ROOT/scripts/lib/`, no relative-path tricks. No path
  traversal risk: `update-claude.sh` constructs paths as
  `"$TK_UPDATE_LIB_DIR/$lib_name"` where `$lib_name` is a hardcoded literal.
- `python3 -c "..."` JSON state seed (lines 116-129) takes only literal Python
  source; argv[1] is the sandbox state path. No interpolation of untrusted
  values into the heredoc. Safe.
- `trap "rm -rf '${SANDBOX:?}'" RETURN` (lines 99/158/196/240/289) uses the
  `${VAR:?}` operator which aborts if `SANDBOX` is empty, preventing
  catastrophic `rm -rf /` if `mktemp` ever returned empty.

**Strict-mode hygiene:**

- `set -euo pipefail` at line 18 — correct
- `|| RC=$?` and `|| RC_DRY=$?` patterns (lines 139, 178, 213, 272, 311) are
  the canonical bash idiom for capturing exit codes under `set -e` without
  swallowing failures. Valid.
- Final block `if [[ $FAIL -gt 0 ]]; then exit 1; fi` (lines 349-351) ensures
  non-zero exit on any failed assertion.

**CI/Makefile integrity:**

- Makefile uses TAB indentation throughout; new Test 29 block (lines 147-148)
  matches the surrounding style; standalone `test-update-libs` target
  (lines 152-154) added with `.PHONY` extension on line 1
- YAML step at `.github/workflows/quality.yml:109-119` correctly extends the
  existing `Tests 21-28` block by renaming to `Tests 21-29` and appending
  `bash scripts/tests/test-update-libs.sh` as the last command. Indentation
  correct, no broken step ordering.

No critical issues, no warnings. The four notes below are minor style/portability
observations that do not affect correctness or security.

## Info

### IN-01: `head -15` in assertion error path is fine but uses GNU/BSD-shared shape

**File:** `scripts/tests/test-update-libs.sh:43,52`
**Issue:** `printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'` works
identically on macOS BSD `head`/`sed` and GNU coreutils — no portability concern.
Just noting that `head -n 15` is the more strictly-portable form (some BSD
variants have deprecated the bare-N form, though Darwin's `head` accepts it).
**Fix:** Optional; current form works on every shipping macOS/Linux. Skip
unless adding new BSD targets.

### IN-02: `MTIME_BEFORE`/`MTIME_AFTER` rely on second-resolution `stat`

**File:** `scripts/tests/test-update-libs.sh:168,180`
**Issue:** `stat -f %m` (BSD) and `stat -c %Y` (GNU) both report seconds since
epoch. If `update-claude.sh` ever genuinely rewrote `backup.sh` within the same
second as the seed `cp` (the test seeds the file then immediately runs update),
the mtime would compare equal and the test would falsely pass. In practice
update-claude does dozens of jq/curl/cp operations before reaching the file
loop, so a sub-second collision is extremely unlikely. The current SHA-based
S1/S3 assertions provide the strong correctness signal; mtime in S2 is a
secondary "cheap rewrite-detection" check. Noting for awareness only.
**Fix:** No action recommended. If sub-second precision matters in the future,
use `stat -f %Fm` (BSD) / `stat -c %Y.%N` (GNU) with cross-platform parsing.

### IN-03: `assert_eq` and `assert_contains` use shared `$haystack` shadowing

**File:** `scripts/tests/test-update-libs.sh:30-54`
**Issue:** `assert_pass` / `assert_fail` are defined at script scope and rely
on the global `PASS` / `FAIL` counters via direct mutation. Under `set -u` this
works because the variables are initialized at lines 27-28. Code is clean — no
bug. Noting that this is the canonical bash assertion pattern used throughout
the toolkit's other test files (`test-state.sh`, `test-detect.sh`, etc.) so
consistency is preserved.
**Fix:** None — this is a stylistic observation, not a defect.

### IN-04: CHANGELOG entry for v4.4.0 consolidates two phases without a divider

**File:** `CHANGELOG.md:8-29`
**Issue:** The `## [4.4.0]` block contains two distinct features (Phase 21
SP/GSD bootstrap installer, Phase 22 lib smart-update coverage) under a single
`### Added` heading separated only by a blank line. This is a minor narrative
choice and does not violate Keep-a-Changelog format or any markdownlint rule.
A reader skimming the changelog might miss that two separate phases shipped in
this release.
**Fix:** Optional. If clearer attribution is desired, split into two
`### Added` subsections (e.g. `### Added — Phase 21: Bootstrap` and
`### Added — Phase 22: Lib Coverage`), or use bold lead-in lines. Current form
is acceptable.

---

_Reviewed: 2026-04-27T09:35:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
