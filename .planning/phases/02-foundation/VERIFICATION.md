---
phase: 02-foundation
verified: 2026-04-17T21:08:56Z
status: gaps_found
score: 12/14
overrides_applied: 0
re_verification: false
gaps:
  - truth: "make validate fails if a file exists on disk in commands/ but is not listed in manifest.json files.commands (drift check)"
    status: failed
    reason: "validate-manifest.py delivers checks 1/2/3/4/5 (version, object-form, vocabulary, duplicates, manifest-to-disk existence) but omits the inverse drift check (disk-to-manifest). The Makefile legacy drift check at lines 99-118 compares manifest commands vs update-claude.sh loop, not commands/ on disk vs manifest. Adding a commands/ .md file not in manifest passes make validate without error."
    artifacts:
      - path: scripts/validate-manifest.py
        issue: "Missing disk-to-manifest drift enumeration for commands/ and templates/base/skills/. Plan spec in 02-02-PLAN.md behavior section and code skeleton both required: iterate commands_dir, iterate skills_dir, fail on files present on disk but absent from manifest."
    missing:
      - "Add os.listdir loop over commands/ in validate-manifest.py that fails on any .md file not in manifest files.commands[].path"
      - "Add os.listdir loop over templates/base/skills/*/SKILL.md in validate-manifest.py that fails on any SKILL.md not in manifest files.skills[].path"

  - truth: "Both init-claude.sh and update-claude.sh source detect.sh from a single canonical path; remote curl|bash callers download detect.sh to mktemp before sourcing (DETECT-05)"
    status: failed
    reason: "Neither scripts/init-claude.sh nor scripts/update-claude.sh was modified to source detect.sh. Decision D-28 deferred production wiring to Phase 3, but DETECT-05 is assigned to Phase 2 in ROADMAP.md and Phase 3 requirements list (MODE-01..06, SAFETY-01..04) does not include DETECT-05. This leaves the sourcing contract unverified and undocketed in any future phase."
    artifacts:
      - path: scripts/init-claude.sh
        issue: "No source detect.sh call-site, not even a commented stub"
      - path: scripts/update-claude.sh
        issue: "No source detect.sh call-site"
    missing:
      - "Add source detect.sh stub to scripts/init-claude.sh (even if the variables are not yet consumed) OR explicitly move DETECT-05 to Phase 3 requirements in ROADMAP.md"
deferred: []
---

# Phase 2: Foundation — Verification Report

**Phase Goal:** The toolkit has a single reliable way to detect SP and GSD, a declarative manifest schema encoding conflicts, and an atomic install-state file with locking — the three pillars everything else depends on.

**Verified:** 2026-04-17T21:08:56Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Sourcing detect.sh sets HAS_SP=false and HAS_GSD=false in empty HOME | VERIFIED | `make test` Test 4 Case 1: "neither" passes; zero stdout confirmed |
| 2 | SP only: HAS_SP=true, HAS_GSD=false, SP_VERSION populated | VERIFIED | Test 4 Case 2: "SP only" passes |
| 3 | GSD only: HAS_SP=false, HAS_GSD=true, GSD_VERSION populated | VERIFIED | Test 4 Case 3: "GSD only" passes |
| 4 | SP stale-cache disabled in settings.json → HAS_SP=false (no false positive) | VERIFIED | Test 4 Case 5: "SP stale-cache disabled" passes; jq has() fix documented in SUMMARY |
| 5 | Sourcing detect.sh does NOT alter caller errexit/pipefail/nounset state | VERIFIED | `grep -q 'set -euo pipefail' scripts/detect.sh` returns non-zero (absent) |
| 6 | Sourcing detect.sh emits zero stdout output | VERIFIED | `test -z "$(source scripts/detect.sh 2>&1)"` passes |
| 7 | make test invokes detect.sh harness and all five cases pass | VERIFIED | `make test` output: "Results: 5 passed, 0 failed" for Test 4 |
| 8 | manifest.json parses as valid JSON with top-level manifest_version: 2 | VERIFIED | `python3 -c 'import json;print(json.load(open("manifest.json"))["manifest_version"])'` → 2 |
| 9 | Every entry under files.* is an object with a path key (no bare strings) | VERIFIED | `python3 -c 'import json;m=json.load(open("manifest.json"));print(all(isinstance(e,dict) for b in m["files"].values() for e in b))'` → True |
| 10 | 7 confirmed SP duplicates annotated with conflicts_with: ["superpowers"] | VERIFIED | 7 entries confirmed; debugging/SKILL.md committed (option-a) |
| 11 | make validate fails on unknown conflicts_with value; passes on clean manifest | VERIFIED | `python3 scripts/validate-manifest.py` exits 0; validator rejects invalid vocabulary |
| 12 | make validate fails if manifest path does not exist on disk | VERIFIED | Manifest-to-disk check present; validator exits 1 on missing paths |
| 13 | **FAIL:** make validate fails if commands/ file on disk is not listed in manifest (drift check) | FAILED | Adding commands/ZZZTESTDRIFT.md and running `make validate` produces no error — disk-to-manifest drift detection is absent from validate-manifest.py |
| 14 | **FAIL:** Both init-claude.sh and update-claude.sh source detect.sh (DETECT-05) | FAILED | Neither script has been modified; no source detect.sh call-site exists in either file |

**Score:** 12/14 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/detect.sh` | detect_superpowers(), detect_gsd(), 4 exports, no set -euo pipefail | VERIFIED | All acceptance criteria pass; shellcheck clean |
| `scripts/tests/test-detect.sh` | 5-case harness (neither/SP/GSD/both/stale-cache) | VERIFIED | Executable, all 5 cases pass via `make test` |
| `scripts/validate-manifest.py` | v2 schema validator: version, object-form, vocabulary, drift, existence | STUB (partial) | Delivers version + object + vocabulary + duplicates + manifest→disk. Missing: disk→manifest drift enumeration |
| `manifest.json` | manifest_version:2, homogeneous objects, 7 conflicts_with annotations | VERIFIED | All 30 commands, 4 agents, 7 prompts, 10 skills, 2 rules as objects; 7 conflicts_with present |
| `Makefile` | Extended test target (Test 4 + Test 5), validate target invoking validator | VERIFIED | Test 4 + Test 5 present; `make validate` calls `python3 scripts/validate-manifest.py` |
| `scripts/lib/state.sh` | 7 functions, atomic write, mkdir lock, stale recovery, no set -euo pipefail | VERIFIED | All 7 functions present; os.replace + tempfile.mkstemp; kill -0 + age>3600 |
| `scripts/tests/test-state.sh` | 5 scenarios: round-trip, kill-9, concurrent lock, dead PID, old mtime | VERIFIED | All 6 pass assertions (Scenario B emits 2 sub-passes); "Results: 6 passed, 0 failed" |
| `templates/base/skills/debugging/SKILL.md` | Committed to git (option-a decision) | VERIFIED | `git ls-files --error-unmatch` succeeds |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| Makefile | scripts/tests/test-detect.sh | Test 4 make target | VERIFIED | `grep -q 'bash scripts/tests/test-detect.sh' Makefile` → match at line 64 |
| Makefile | scripts/tests/test-state.sh | Test 5 make target | VERIFIED | `grep -q 'bash scripts/tests/test-state.sh' Makefile` → match at line 67 |
| Makefile | scripts/validate-manifest.py | validate target | VERIFIED | `grep -q 'python3 scripts/validate-manifest.py' Makefile` → match at line 122 |
| scripts/tests/test-detect.sh | scripts/detect.sh | source under overridden HOME | VERIFIED | `source "$DETECT_SH"` at line 39 |
| scripts/tests/test-state.sh | scripts/lib/state.sh | source under overridden HOME | VERIFIED | `source "$STATE_SH"` at lines 38, 62, 72, 107, 111 |
| scripts/lib/state.sh | python3 tempfile.mkstemp + os.replace | write_state heredoc | VERIFIED | `grep -c 'os.replace\|tempfile.mkstemp' scripts/lib/state.sh` → 2 |
| scripts/lib/state.sh | python3 hashlib.sha256 | sha256_file helper | VERIFIED | `grep -q 'hashlib.sha256' scripts/lib/state.sh` → match |
| scripts/validate-manifest.py | manifest.json | MANIFEST_PATH auto-discovery | VERIFIED | Resolves via REPO_ROOT derived from script location |
| **MISSING:** scripts/init-claude.sh | scripts/detect.sh | source call-site (DETECT-05) | NOT WIRED | No source or reference to detect.sh in scripts/init-claude.sh |
| **MISSING:** scripts/update-claude.sh | scripts/detect.sh | source call-site (DETECT-05) | NOT WIRED | No source or reference to detect.sh in scripts/update-claude.sh |

---

## Data-Flow Trace (Level 4)

Phase 2 is plumbing only (D-28) — no production call sites consume the detection results yet. All three artifacts produce real data from filesystem probes (detect.sh), JSON-validated disk files (validate-manifest.py), and python3 hashlib (state.sh). No hollow props.

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| detect.sh: empty HOME → HAS_SP=false HAS_GSD=false | `bash -c 'SCRATCH=$(mktemp -d); HOME="$SCRATCH" source scripts/detect.sh; echo "HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD"; rm -rf "$SCRATCH"'` | HAS_SP=false HAS_GSD=false | PASS |
| detect.sh: no stdout during source | `test -z "$(source scripts/detect.sh 2>&1)"` | empty output | PASS |
| state.sh: no stdout during source | `test -z "$(bash -c 'source scripts/lib/state.sh' 2>&1)"` | empty output | PASS |
| validate-manifest.py: passes on current manifest | `python3 scripts/validate-manifest.py` | "manifest.json validation PASSED" exit 0 | PASS |
| validate-manifest.py: missing drift check | Add commands/ZZZTESTDRIFT.md, run `make validate` | PASSES (no error) — should fail | FAIL |
| make test: all 5 test groups | `make test` | 14 total passes, "All tests passed!" exit 0 | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DETECT-01 | 02-01 | detect_superpowers() returns 0 if cache dir exists with versioned subdir | SATISFIED | Function present; Test 4 Cases 2+4 verify |
| DETECT-02 | 02-01 | detect_gsd() returns 0 if get-shit-done/ + bin/gsd-tools.cjs present | SATISFIED | Function present; Test 4 Cases 3+4 verify |
| DETECT-03 | 02-01 | Cross-reference settings.json enabledPlugins to suppress stale-cache false positives | SATISFIED | jq has() implementation; Test 4 Case 5 verifies |
| DETECT-04 | 02-01 | detect.sh is sourced (not executed); exports HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION | SATISFIED | File sourced in tests; all 4 exports confirmed |
| DETECT-05 | 02-01 | Both init-claude.sh and update-claude.sh source detect.sh from a single canonical path | BLOCKED | Neither script sources detect.sh; D-28 deferred wiring but Phase 3 ROADMAP does not list DETECT-05 as a requirement |
| MANIFEST-01 | 02-02 | Each files.* entry is object with path, optional conflicts_with, optional requires_base | SATISFIED | All entries are objects; verified by validator and spot-check |
| MANIFEST-02 | 02-02 | Bump manifest.version to 2 | SATISFIED (deviation) | REQUIREMENTS.md says "manifest.version" (dot) but implementation uses "manifest_version" (underscore) per D-14/Pitfall 4. Plan frontmatter explicitly specifies underscore form. Functionally equivalent. |
| MANIFEST-03 | 02-02 | 7 confirmed SP duplicates annotated with conflicts_with | SATISFIED | 7 entries present; REQUIREMENTS.md amended to reflect live-scan count (option-a) |
| MANIFEST-04 | 02-02 | make validate enforces path existence, no-drift, vocabulary | PARTIAL | Path existence and vocabulary enforced. Disk-to-manifest drift detection missing from validate-manifest.py. |
| STATE-01 | 02-03 | toolkit-install.json schema: version, mode, detected, installed_files, skipped_files, installed_at | SATISFIED | write_state produces all required fields; Scenario A verifies |
| STATE-02 | 02-03 | Atomic writes via mktemp + mv (never half-written) | SATISFIED | tempfile.mkstemp + os.replace in state.sh; Scenario B kill-9 durability test passes |
| STATE-03 | 02-03 | mkdir-based lock at ~/.claude/.toolkit-install.lock | SATISFIED | acquire_lock/release_lock present; Scenario C concurrent-lock test passes |
| STATE-04 | 02-03 | Each installed_files entry stores SHA256 | SATISFIED | sha256_file via hashlib; Scenario A verifies 64-char hex |
| STATE-05 | 02-03 | Stale-lock recovery: lock >1h with no live PID → reclaim with warning | SATISFIED | Both signals (kill -0 + age>3600); Scenarios D+E both pass |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| scripts/validate-manifest.py | 60-184 | Drift detection (disk→manifest) missing despite plan spec | Warning | No CI catch when new command is added to commands/ without manifest update |
| scripts/init-claude.sh | — | DETECT-05 source not added | Warning | Phase 3 must add it; currently undocketed if Phase 3 ROADMAP does not include DETECT-05 |

---

## Human Verification Required

None — all checks are programmatic for this phase's deliverables. Phase 2 is plumbing only (D-28); no user-visible behavior exists to manually test.

---

## Gaps Summary

Two gaps block a clean PASS verdict:

**Gap 1 — validate-manifest.py missing drift detection (MANIFEST-04 partial):**
The plan specification for validate-manifest.py explicitly included a disk-to-manifest drift check: iterate `commands/` on disk and fail if any `.md` file is absent from `manifest.json files.commands`. The delivered implementation omits this check. The validator only verifies that every manifest entry exists on disk (manifest→disk), not the reverse. The existing Makefile legacy drift check (lines 99-118) compares manifest commands against the `update-claude.sh` loop, which is unrelated to disk enumeration. Adding a new command file to `commands/` without updating manifest silently passes `make validate`.

**Gap 2 — DETECT-05 not wired (init-claude.sh / update-claude.sh):**
DETECT-05 requires both install scripts to source `detect.sh` from a single canonical path. Neither script was modified in Phase 2 (decision D-28 deferred production wiring), but DETECT-05 is assigned to Phase 2 in ROADMAP.md, and Phase 3's requirements list (MODE-01..06, SAFETY-01..04) does not include DETECT-05. This creates a docketing gap: the requirement is not satisfied in Phase 2 and has no assigned phase for completion.

**Both gaps are fixable additions** — they do not require rearchitecting anything already delivered. The fix for Gap 1 is approximately 12 lines in validate-manifest.py (the exact code was in the PLAN spec but not carried forward into implementation). The fix for Gap 2 is either adding the source stub to both scripts, or moving DETECT-05 to Phase 3 ROADMAP requirements.

---

### Quality Gate Results

| Gate | Result |
|------|--------|
| make test (Tests 1-5) | PASS — 14 total pass assertions, exit 0 |
| make validate | PASS — templates valid, version aligned, manifest schema valid |
| make shellcheck | PASS — all scripts/\*.sh and scripts/lib/\*.sh and scripts/tests/\*.sh clean |
| make mdlint | PRE-EXISTING FAILURES — CLAUDE.md and components/orchestration-pattern.md errors not introduced by Phase 2 |

### Recommended Next Step

Fix the two gaps before proceeding to Phase 3:

1. **Gap 1 fix** (5-10 min): Add `os.listdir` drift loops to `scripts/validate-manifest.py` for `commands/` and `templates/base/skills/`. The exact code was in the 02-02-PLAN.md `<action>` block under "# (b) drift: commands/ files on disk not in manifest" — copy it in.

2. **Gap 2 resolution** (choose one):
   - Add `source "$(dirname "$0")/detect.sh"` stub to `scripts/init-claude.sh` and `scripts/update-claude.sh` (Phase 2 CONTEXT.md said "stubs only" was acceptable), OR
   - Explicitly add DETECT-05 to Phase 3 requirements in ROADMAP.md so it is not lost

After both gaps are closed: advance to Phase 3.

---

_Verified: 2026-04-17T21:08:56Z_
_Verifier: Claude (gsd-verifier)_
