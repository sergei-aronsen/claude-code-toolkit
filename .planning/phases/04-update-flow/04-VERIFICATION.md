---
phase: 04-update-flow
verified: 2026-04-18T20:15:00Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run update-claude.sh against a real project with a real manifest change (add a file, then update)"
    expected: "New file is auto-installed silently; summary shows INSTALLED 1"
    why_human: "Test harness uses TK_UPDATE_FILE_SRC seam; production path curls from raw.githubusercontent.com — cannot verify without network write"
  - test: "Run update-claude.sh on macOS in interactive terminal with a modified file"
    expected: "Prompt 'File X modified locally. Overwrite? [y/N/d]:' appears; d shows diff, re-prompts"
    why_human: "test-update-diff.sh scenario 7 (modified_file_diff) passes via fail-closed path (no-tty), not via interactive diff display. Human must verify tty path"
gaps:
  - truth: "TK_UPDATE_SKIP_LEGACY_BACKUP seam fully removed from all test files"
    status: partial
    reason: "Plan 04-03 SUMMARY claims cleanup but the env var still appears on 3 lines of test-update-drift.sh (lines 94, 152, 190). The variable is NOT read by update-claude.sh so it is dead code with no functional effect — all 14 test assertions pass. Gap is cosmetic."
    artifacts:
      - path: "scripts/tests/test-update-drift.sh"
        issue: "TK_UPDATE_SKIP_LEGACY_BACKUP=1 present at lines 94, 152, 190 — Plan 04-03 spec required removal"
    missing:
      - "Remove TK_UPDATE_SKIP_LEGACY_BACKUP=1 from 3 scenario invocations in test-update-drift.sh"
---

# Phase 4: Update Flow Verification Report

**Phase Goal:** update-claude.sh re-evaluates detection on every run, identifies new and removed files from the manifest, surfaces mode drift to the user, and produces a grouped post-update summary
**Verified:** 2026-04-18T20:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running update after installing SP prompts user that detected base set changed and offers to switch from standalone to complement-sp | VERIFIED | `execute_mode_switch` + drift detect block in `scripts/update-claude.sh`; Test 9 scenario `mode-drift-accept` passes |
| 2 | A file added to manifest.json since last install is detected and offered for install on next update (mode-aware skip applied) | VERIFIED | `compute_file_diffs_obj` + new-file auto-install loop; Test 10 scenarios `new_file_auto_install` + `new_file_filtered_by_skip_set` both pass |
| 3 | A file removed from manifest.json since last install is detected and offered for deletion with backup and confirmation | VERIFIED | Removed-file batch prompt (D-55) + `--prune` flag; Test 10 scenarios `removed_file_accept` + `removed_file_decline` pass |
| 4 | Post-update summary shows exactly four groups: INSTALLED N, UPDATED M, SKIPPED P (with reason per file), REMOVED Q (backed up to path) | VERIFIED | `print_update_summary` function in `scripts/update-claude.sh:206-246`; Test 11 scenario `full_run_summary_all_four_groups` passes |
| 5 | Running update twice in the same second does not produce a naming collision in backup dirs | VERIFIED | `BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"` at line 430; Test 11 scenario `same_second_concurrent_runs_no_collision` passes |

**Score:** 5/5 roadmap truths verified

### Plan Must-Have Truths (04-01 / UPDATE-01)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running update-claude.sh against host with no toolkit-install.json synthesizes one from manifest-file scan before any mutation | VERIFIED | `synthesize_v3_state()` at lines 143-158; invoked at lines 274-275 when `STATE_FILE` missing; Test 9 scenario 1 passes |
| 2 | Drift notice prints two-line table + [y/N] prompt reading from /dev/tty; fails closed without tty | VERIFIED | Drift block at lines 327-350; `read -r -p ... < /dev/tty 2>/dev/null` fail-closed pattern; Test 9 scenarios 2/3/4 pass |
| 3 | Accepting drift prompt runs single in-place mode-switch transaction within one backup snapshot | VERIFIED | `execute_mode_switch()` at lines 303-326; Test 9 scenario 5 passes (SP-conflict files deleted, STATE_MODE updated) |
| 4 | Declining drift prompt proceeds in previously recorded mode and logs duplicates warning | VERIFIED | `log_info "Keeping current mode $STATE_MODE — duplicates may be installed/removed accordingly"` at line 348; Test 9 scenario 3 passes |
| 5 | Wave 0 test files exist and are wired in Makefile Tests 9/10/11 | VERIFIED | All 3 test files exist; Makefile lines 78-86 wire tests 9/10/11; all pass |

### Plan Must-Have Truths (04-02 / UPDATE-02/03/04)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | update-claude.sh contains NO hand-maintained file lists | VERIFIED | `grep -c "for file in agents/..."` returns 0; validate target confirms: "update-claude.sh is manifest-driven" |
| 2 | Files newly added to manifest auto-installed silently; skip-set filtered files go to SKIPPED group | VERIFIED | New-file loop at lines 458-484; skip-set tracking at lines 487-508; Test 10 passes 13/13 |
| 3 | Files removed from manifest trigger single batch [y/N] prompt; accept=delete; decline=log removal_declined | VERIFIED | Removed-files block at lines 510-543; `--prune` flag; Test 10 passes |
| 4 | Each file in both state and manifest: on-disk SHA-256 compared; mismatch triggers [y/N/d] prompt; d shows diff | VERIFIED | `prompt_modified_file()` at lines 530-595; `diff -u` + re-prompt loop; Test 10 passes |
| 5 | Empty sha256 in state MUST NOT trigger modified-file prompt — skip silently | VERIFIED | Empty-stored guard `[[ -z "$stored" ]] && return 0` at line 551; Test 10 scenario passes |
| 6 | Hand-maintained loops at update-claude.sh:117-188 deleted AND Makefile drift check simplified in SAME commit (B3) | VERIFIED | Commit `63b0559` contains both changes atomically; Makefile structural grep guard present |

### Plan Must-Have Truths (04-03 / UPDATE-05/06)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | One tree backup at dirname($CLAUDE_DIR)/.claude-backup-unix-ts-pid/ before any mutation; no backup on no-op | VERIFIED | Line 430 `BACKUP_DIR=...$(date -u +%s)-$$`; no-op check exits before backup block; Test 11 passes 17/17 |
| 2 | Two concurrent updates in same second produce different backup dirs (PID suffix) | VERIFIED | Test 11 scenario 4 proves algorithm: bash subshells have different `$$` values |
| 3 | Four-group summary printed with ANSI auto-disable when stdout is not tty | VERIFIED | `print_update_summary` with `if [ -t 1 ]` ANSI guard; Test 11 scenario 2 passes |
| 4 | No-op condition: 5 conditions including manifest_hash match (B2 correction) exits 0 without backup/write_state | VERIFIED | `is_update_noop()` 6-condition check; `STATE_MANIFEST_HASH == MANIFEST_HASH` comparison; Test 11 scenarios 1 + 5 pass |
| 5 | write_state called exactly ONCE post-mutation | VERIFIED | Single `write_state` call at line 728; manifest_hash post-processed via jq+mv |
| 6 | commands/rollback-update.md documents new backup-path convention | VERIFIED | "Backup Naming (v4.0+)" section at line 16; `.claude-backup-<unix-ts>-<pid>` format documented |

**Score:** 6/6 plan must-have groups verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/tests/test-update-drift.sh` | Min 120 lines; D-50/D-51/D-52 harness | VERIFIED | 297 lines; 14/14 assertions pass |
| `scripts/tests/test-update-diff.sh` | Min 200 lines; 7 scenarios | VERIFIED | 473 lines; 13/13 assertions pass |
| `scripts/tests/test-update-summary.sh` | Min 180 lines; 5 scenarios | VERIFIED | 352 lines; 17/17 assertions pass |
| `scripts/tests/fixtures/manifest-update-v2.json` | Min 25 lines; 12 entries | VERIFIED | 37 lines; valid JSON with correct deltas |
| `scripts/tests/fixtures/toolkit-install-seeded.json` | Min 15 lines; correct schema | VERIFIED | 16 lines; valid JSON with sha256 fields |
| `scripts/update-claude.sh` | Contains `synthesize_v3_state` | VERIFIED | 4 occurrences confirmed |
| `scripts/lib/install.sh` | Contains `compute_file_diffs_obj` | VERIFIED | 2 occurrences; callable and verified |
| `scripts/update-claude.sh` | Contains `print_update_summary` | VERIFIED | 3 occurrences; called at line 737 |
| `scripts/tests/test-update-summary.sh` | Min 180 lines; GREEN | VERIFIED | 352 lines; 17/17 pass |
| `commands/rollback-update.md` | Contains `<unix-ts>-<pid>` format | VERIFIED | 2 occurrences; passes mdlint |
| `Makefile` | Contains `test-update-drift.sh` | VERIFIED | Tests 9/10/11 at lines 79/82/85 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/update-claude.sh` | `scripts/lib/state.sh` | `read_state` / `write_state` sourced via mktemp+curl+trap | VERIFIED | Lines 69-106; `source "$LIB_STATE_TMP"` |
| `scripts/update-claude.sh` | `scripts/lib/install.sh` | `recommend_mode` / `compute_skip_set` sourced | VERIFIED | Lines 69-106; `source "$LIB_INSTALL_TMP"` |
| `scripts/update-claude.sh` | `~/.claude/toolkit-install.json` | `synthesize_v3_state()` writes state before normal flow | VERIFIED | Lines 273-285; state written before any mutation |
| `scripts/update-claude.sh` | `scripts/lib/install.sh::compute_file_diffs_obj` | sourced helper produces JSON with .new/.removed/.modified_candidates | VERIFIED | Line 404 `DIFFS_JSON=$(compute_file_diffs_obj ...)` |
| `scripts/update-claude.sh` | `scripts/lib/state.sh::acquire_lock + release_lock` | trap + acquire around mutation block | VERIFIED | Lines 427-428 |
| `scripts/tests/test-update-drift.sh` | `scripts/tests/fixtures/toolkit-install-seeded.json` | test seeds scratch state | VERIFIED | Pattern `toolkit-install-seeded` appears in test file |
| `scripts/update-claude.sh` | Plan 04-02 `SKIPPED_PATHS/INSTALLED_PATHS/UPDATED_PATHS/REMOVED_PATHS` | `print_update_summary` iterates these arrays | VERIFIED | Line 737 `print_update_summary "$BACKUP_DIR"` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `scripts/update-claude.sh` summary output | `INSTALLED_PATHS`, `UPDATED_PATHS`, `SKIPPED_PATHS`, `REMOVED_PATHS` | `compute_file_diffs_obj` → dispatch loops → array appends | Yes — arrays populated from real manifest/state diff computation | FLOWING |
| `scripts/update-claude.sh` `STATE_JSON` | State from toolkit-install.json | `read_state` from `lib/state.sh` | Yes — reads real on-disk state file | FLOWING |
| `scripts/update-claude.sh` backup | `BACKUP_DIR` | `$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$` | Yes — real timestamp + PID | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Test 9: drift + synthesis | `bash scripts/tests/test-update-drift.sh` | 14 passed, 0 failed | PASS |
| Test 10: file-diff dispatch | `bash scripts/tests/test-update-diff.sh` | 13 passed, 0 failed | PASS |
| Test 11: summary + no-op + backup | `bash scripts/tests/test-update-summary.sh` | 17 passed, 0 failed | PASS |
| make shellcheck | `make shellcheck` | ShellCheck passed | PASS |
| make validate | `make validate` | Version aligned + manifest-driven guard + all templates valid | PASS |
| make test | `make test` | Exit code 0; Tests 1-11 all pass | PASS |
| Hand-list grep | `grep -c "for file in agents/..."` | 0 | PASS |
| compute_file_diffs_obj wired | `grep -c "compute_file_diffs_obj" scripts/update-claude.sh` | 2 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UPDATE-01 | 04-01 | `update-claude.sh` reads toolkit-install.json + re-runs detection; prompts on base-set change | SATISFIED | `synthesize_v3_state` + drift detect block; Test 9 GREEN |
| UPDATE-02 | 04-02 | Installed-file list iterated from manifest.json filtered by mode (no hand-maintained list) | SATISFIED | Hand-list grep returns 0; `compute_file_diffs_obj` wired; Test 10 GREEN |
| UPDATE-03 | 04-02 | Files newly added to manifest.json detected and offered with mode-aware skip | SATISFIED | New-file auto-install loop; skip-set filtering; Test 10 scenarios 1/2 pass |
| UPDATE-04 | 04-02 | Files removed from manifest.json detected and offered for deletion with backup + confirmation | SATISFIED | Removed-file batch prompt; `--prune` flag; Test 10 scenarios 3/4 pass |
| UPDATE-05 | 04-03 | Backup dirs use timestamp + PID suffix; no collision in same second | SATISFIED | `$(date -u +%s)-$$` format; Test 11 scenario 4 proves algorithm |
| UPDATE-06 | 04-03 | Post-update summary shows INSTALLED N / UPDATED M / SKIPPED P (reason) / REMOVED Q (backed up to path) | SATISFIED | `print_update_summary` function; Test 11 scenario 2 passes |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/tests/test-update-drift.sh` | 94, 152, 190 | `TK_UPDATE_SKIP_LEGACY_BACKUP=1` — dead env var that Plan 04-03 was supposed to remove | Warning | None functional — var not read by update-claude.sh; tests pass 14/14 |
| `CLAUDE.md` | 471, 486 | MD022/MD032 markdown lint errors (pre-existing, not Phase 4) | Info | Not Phase 4 scope |
| `components/orchestration-pattern.md` | 211-231 | MD031/MD029/MD040 markdown lint errors (pre-existing, not Phase 4) | Info | Not Phase 4 scope |

### Human Verification Required

#### 1. Production curl path for new-file install

**Test:** On a machine with network access, run `bash scripts/update-claude.sh` against a project where a file exists in the latest `manifest.json` but is absent from `~/.claude/toolkit-install.json`. No `TK_UPDATE_FILE_SRC` set.
**Expected:** File is downloaded via `curl -sSLf $REPO_URL/$path` and appears in `$CLAUDE_DIR/`. Summary shows `INSTALLED 1`.
**Why human:** All automated tests use `TK_UPDATE_FILE_SRC` seam to avoid network. Production curl path is untested programmatically.

#### 2. Interactive modified-file diff display

**Test:** Seed a project with a modified file (sha256 differs from state). Run `update-claude.sh` in an interactive terminal. Enter `d` at the `[y/N/d]:` prompt.
**Expected:** Unified diff (`--- ... +++ ... @@ ...`) is displayed; script re-prompts. Then enter `n` to keep local version.
**Why human:** `test-update-diff.sh` scenario 7 (`modified_file_diff`) passes via fail-closed path (no-tty condition returns N without displaying diff). The interactive tty path with actual diff output has not been exercised by automated tests.

### Gaps Summary

One minor gap found: `TK_UPDATE_SKIP_LEGACY_BACKUP=1` was specified for removal in Plan 04-03 but was not removed from `test-update-drift.sh`. The variable is ignored by `update-claude.sh` (no longer referenced), so it has zero functional impact — all 14 test assertions pass. The SUMMARY claimed the cleanup was done in commit `65d09e1` but that commit only touched `test-update-summary.sh`. This is a cosmetic gap. The plan 04-03 acceptance criteria checked `grep -r TK_UPDATE_SKIP_LEGACY_BACKUP scripts/update-claude.sh` (returns 0, correct) but the spec also called for removing from test files.

The `make check` mdlint failure is pre-existing (files `CLAUDE.md` and `components/orchestration-pattern.md` were last modified in commits before Phase 4; both are out of Phase 4 scope). Phase 4's own `commands/rollback-update.md` passes mdlint individually.

---

_Verified: 2026-04-18T20:15:00Z_
_Verifier: Claude (gsd-verifier)_
