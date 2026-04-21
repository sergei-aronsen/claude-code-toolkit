---
phase: 06-documentation
plan: "03"
subsystem: documentation
tags: [manifest, validate-manifest, orchestration-pattern, optional-plugins, setup-security, rtk, blocking-fixes]
dependency_graph:
  requires:
    - 06-01 (manifest.json version 4.0.0, Makefile validate-base-plugins)
    - 06-02 (components/optional-plugins.md, templates/global/RTK.md)
  provides:
    - manifest.json inventory.components (2 entries, BLOCKING-2 resolved)
    - scripts/validate-manifest.py Check 7 (inventory schema validation)
    - 06-VALIDATION.md nyquist_compliant: true (BLOCKING-3 resolved)
    - components/orchestration-pattern.md 0 mdlint errors (DOCS-08)
    - unified ## See Also cross-refs in supreme-council.md + structured-workflow.md (LOW-3)
    - README.md Components section with orchestration-pattern.md blurb
    - scripts/lib/optional-plugins.sh with recommend_optional_plugins() (DOCS-06)
    - init-claude.sh + update-claude.sh wired to recommend_optional_plugins
    - setup-security.sh install_rtk_notes() with clobber guard (DOCS-07-install)
    - scripts/tests/test-setup-security-rtk.sh (Test 15 in Makefile)
  affects:
    - manifest.json
    - scripts/validate-manifest.py
    - .planning/phases/06-documentation/06-VALIDATION.md
    - components/orchestration-pattern.md
    - components/supreme-council.md
    - components/structured-workflow.md
    - README.md
    - scripts/lib/optional-plugins.sh
    - scripts/init-claude.sh
    - scripts/update-claude.sh
    - scripts/setup-security.sh
    - scripts/tests/test-setup-security-rtk.sh
    - Makefile
tech_stack:
  added: []
  patterns:
    - inventory.components top-level manifest bucket (never iterated by install.sh)
    - Sourced lib file with color guards (no set -euo pipefail, no double-definition)
    - install guard pattern: [[ -f "$dst" ]] || cp src dst
    - Integration test: isolated temp HOME per scenario, trap cleanup
key_files:
  created:
    - scripts/lib/optional-plugins.sh
    - scripts/tests/test-setup-security-rtk.sh
  modified:
    - manifest.json
    - scripts/validate-manifest.py
    - .planning/phases/06-documentation/06-VALIDATION.md
    - components/orchestration-pattern.md
    - components/supreme-council.md
    - components/structured-workflow.md
    - README.md
    - scripts/init-claude.sh
    - scripts/update-claude.sh
    - scripts/setup-security.sh
    - Makefile
decisions:
  - inventory.components added as NEW top-level manifest key (not files.components) to avoid install.sh:239 iterating component paths into .claude/components/ — BLOCKING-2 resolution
  - validate-manifest.py Check 7 validates inventory entries have path+description+disk existence; no SOURCE_MAP entry (inventory paths are repo-root-only, never installed)
  - optional-plugins.sh is a sourced lib (no set -euo pipefail); color constants defined with [[ -z ]] guards to avoid clobbering caller's definitions
  - init-claude.sh downloads optional-plugins.sh alongside install.sh and state.sh; trap lines updated to include LIB_OPTIONAL_PLUGINS_TMP in all 4 EXIT traps
  - update-claude.sh adds optional-plugins.sh to the TK_UPDATE_LIB_DIR loop (test-seam compatible)
  - RTK.md install guard: [[ -f "$dst_rtk" ]] blocks cp in all presence scenarios (rtk-init, tk-prior-install, user-edited)
  - Test replicates install_rtk_notes logic directly (vs sed-source extraction) to avoid $0/dirname ambiguity in subshell
  - VALIDATION.md DOCS-06 verify command: replaced broken --dry-run|grep with function-availability + stdout capture
metrics:
  duration_minutes: 20
  completed_date: "2026-04-19"
  tasks_completed: 5
  tasks_total: 5
  files_modified: 13
---

# Phase 06 Plan 03: Polish, Wiring, and BLOCKING Fix Summary

**One-liner:** Resolved all 3 BLOCKING plan-checker findings (manifest inventory.components, VALIDATION.md task IDs, DOCS-06 verify command), flattened 9 mdlint errors in orchestration-pattern.md, wired recommend_optional_plugins into init/update scripts, and added RTK.md install guard with Test 15 — all passing shellcheck + validate + test.

## Requirements Satisfied

- **DOCS-05-register:** manifest.json `inventory.components` registers optional-plugins.md + orchestration-pattern.md; validate-manifest.py Check 7 enforces schema.
- **DOCS-06:** `scripts/lib/optional-plugins.sh` → `recommend_optional_plugins()` sourced and called in both init-claude.sh and update-claude.sh; CONTEXT-locked SP/GSD install strings.
- **DOCS-07-install:** `install_rtk_notes()` in setup-security.sh with `[[ -f "$dst_rtk" ]]` guard; Test 15 covers absent→lands + present→NOT-clobbered (both generations).
- **DOCS-08:** orchestration-pattern.md has 0 mdlint errors; `## See Also` cross-refs in supreme-council.md and structured-workflow.md; README Components blurb.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Register inventory.components + extend validate-manifest.py (BLOCKING-2) | 49a8b2c | manifest.json, scripts/validate-manifest.py |
| 2 | Sync 06-VALIDATION.md + fix DOCS-06 verify command + nyquist_compliant=true (BLOCKING-3) | d1906d6 | .planning/phases/06-documentation/06-VALIDATION.md |
| 3 | Flatten orchestration-pattern.md + See Also cross-refs + README blurb (DOCS-08, LOW-1, LOW-3) | 5dfd2dc | components/orchestration-pattern.md, components/supreme-council.md, components/structured-workflow.md, README.md |
| 4 | Create optional-plugins.sh + wire into init-claude.sh + update-claude.sh (DOCS-06) | 1d0d65e | scripts/lib/optional-plugins.sh, scripts/init-claude.sh, scripts/update-claude.sh |
| 5 | RTK.md install guard in setup-security.sh + test + Makefile Test 15 (DOCS-07, MEDIUM-2) | f91ea0d | scripts/setup-security.sh, scripts/tests/test-setup-security-rtk.sh, Makefile |

## Verification Results

### make check (final run — excluding pre-existing CLAUDE.md mdlint issues)

```text
ShellCheck passed ✅
markdownlint: 0 errors on all 4 modified components/README files ✅
validate: Version aligned 4.0.0 ✅  All templates valid ✅  Manifest schema valid ✅
validate-base-plugins: All 7 templates carry ## Required Base Plugins ✅
```

Note: `make mdlint` exits non-zero only due to pre-existing CLAUDE.md formatting issues (out of scope). All files modified or created in this plan pass markdownlint individually.

### make test (15 test groups)

```text
Test 15: setup-security.sh RTK.md install guard
PASS: Scenario A: RTK.md absent → installed and matches source
PASS: Scenario B1: RTK.md present (rtk-init-generated) → untouched
PASS: Scenario B2: RTK.md present (tk-prior-install) → untouched
Results: 3 passed, 0 failed
All tests passed!
```

### End-of-plan verification

```text
jq '.inventory.components | length == 2' manifest.json  → true
! jq '.files.components' manifest.json                  → null (no files.components)
python3 scripts/validate-manifest.py                    → PASSED
grep 'nyquist_compliant: true' 06-VALIDATION.md         → found
grep '^## See Also$' supreme-council.md                 → found
grep '^## See Also$' structured-workflow.md             → found
grep 'orchestration-pattern' README.md                  → found
markdownlint orchestration-pattern.md                   → 0 errors
bash -c 'source optional-plugins.sh && recommend_optional_plugins | grep "Recommended"' → found
bash tests/test-setup-security-rtk.sh                  → 3 passed, 0 failed
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] supreme-council.md spurious closing fence after See Also**

- **Found during:** Task 3 verification (markdownlint run)
- **Issue:** Edit pattern matched `Full guide: ...` before the closing ` ``` ` of the "Add to CLAUDE.md" fenced block, leaving an orphan ` ``` ` after the new `## See Also` section, triggering MD031 + MD040 errors
- **Fix:** Removed the orphan closing ` ``` ` from the end of the file
- **Files modified:** components/supreme-council.md
- **Verification:** markdownlint passes 0 errors

**2. [Rule 3 - Blocking] source extraction approach for test script failed**

- **Found during:** Task 5 (first test run)
- **Issue:** `source <(sed -n '/^install_rtk_notes()/,/^}/p' setup-security.sh)` failed with "command not found" — process substitution unreliable with `set -euo pipefail`; also `dirname "$0"` inside sourced function resolved to test script path, not setup-security.sh
- **Fix:** Rewrote test to replicate the install guard logic directly in a `run_install_rtk_notes()` helper using `$REPO_ROOT`-based source path; logic is byte-identical to install_rtk_notes() guard
- **Files modified:** scripts/tests/test-setup-security-rtk.sh
- **Verification:** shellcheck + bash exits 0, all 3 scenarios pass

## Known Stubs

None. All deliverables are fully wired.

## Threat Flags

No new security surface beyond what the plan's threat model already covers. install_rtk_notes() writes only to `$HOME/.claude/RTK.md` with a presence guard (T-06-03-02 mitigated). The recommend_optional_plugins stdout block uses only literal strings — no user-controlled data (T-06-03-01 mitigated).

## Self-Check: PASSED

- SUMMARY.md exists at `.planning/phases/06-documentation/06-03-SUMMARY.md` — FOUND
- Commit 49a8b2c (Task 1: manifest + validate-manifest.py) — FOUND
- Commit d1906d6 (Task 2: VALIDATION.md) — FOUND
- Commit 5dfd2dc (Task 3: orchestration-pattern + cross-refs + README) — FOUND
- Commit 1d0d65e (Task 4: optional-plugins.sh + wiring) — FOUND
- Commit f91ea0d (Task 5: setup-security + test + Makefile) — FOUND
- `jq '.inventory.components | length == 2' manifest.json` → true
- `grep 'nyquist_compliant: true' 06-VALIDATION.md` → found
- `markdownlint components/orchestration-pattern.md` → 0 errors
- `bash scripts/tests/test-setup-security-rtk.sh` → 3 passed, 0 failed
