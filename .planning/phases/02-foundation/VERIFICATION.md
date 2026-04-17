---
phase: 02-foundation
verified: 2026-04-17T22:15:00Z
status: passed
score: 14/14
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 12/14
  gaps_closed:
    - "make validate fails if commands/ file on disk is not listed in manifest (drift check — MANIFEST-04)"
    - "DETECT-05 docketed — moved to Phase 3 requirements in ROADMAP.md and REQUIREMENTS.md"
  gaps_remaining: []
  regressions: []
---

# Phase 2: Foundation — Verification Report

**Phase Goal:** The toolkit has a single reliable way to detect SP and GSD, a declarative manifest schema encoding conflicts, and an atomic install-state file with locking — the three pillars everything else depends on

**Verified:** 2026-04-17T22:15:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure commit 5fb6f28

---

## Re-Verification Summary

Two gaps from the initial 12/14 verdict were resolved in commit `5fb6f28`:

**Gap 1 — MANIFEST-04 drift check (now CLOSED):**
`scripts/validate-manifest.py` received Check 6 (lines 177-197). The check enumerates `commands/*.md` and `templates/base/skills/*/SKILL.md` on disk and fails if any file is absent from the manifest. Synthetic test confirmed: `touch commands/ZZZTESTDRIFT.md && python3 scripts/validate-manifest.py` exits 1 with "drift: commands/ZZZTESTDRIFT.md exists on disk but is not in manifest files.commands". After cleanup `make validate` exits 0.

**Gap 2 — DETECT-05 docketing (now CLOSED):**
DETECT-05 was moved from Phase 2 to Phase 3 via ROADMAP.md and REQUIREMENTS.md updates in commit `5fb6f28`. Phase 2 requirements line no longer lists DETECT-05. Phase 3 requirements line now lists DETECT-05 as its first entry. REQUIREMENTS.md traceability table row updated to Phase 3 with deferral note. REQUIREMENTS.md requirement text annotated with "(moved to Phase 3)". The sourcing contract is now tracked — it will be verified when Phase 3 closes.

**Regression check:** `make shellcheck` passes clean. `make test` (Tests 1-5): 14 pass assertions, exit 0. `make validate`: manifest schema PASSED, templates valid, versions aligned, drift clean.

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
| 13 | make validate fails if commands/ file on disk is not listed in manifest (drift check) | VERIFIED | Synthetic test: `touch commands/ZZZTESTDRIFT.md && python3 scripts/validate-manifest.py` exits 1 with drift error. After cleanup: exits 0. Check 6 at lines 177-197 of validate-manifest.py |
| 14 | DETECT-05 is docketed in an assigned future phase (not orphaned) | VERIFIED | ROADMAP.md Phase 2 requirements line omits DETECT-05; Phase 3 requirements line includes DETECT-05 as first entry. REQUIREMENTS.md traceability table row shows "Phase 3 — Pending (moved from Phase 2)". Production wiring will be verified at Phase 3 closure. |

**Score:** 14/14 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/detect.sh` | detect_superpowers(), detect_gsd(), 4 exports, no set -euo pipefail | VERIFIED | All acceptance criteria pass; shellcheck clean |
| `scripts/tests/test-detect.sh` | 5-case harness (neither/SP/GSD/both/stale-cache) | VERIFIED | Executable, all 5 cases pass via `make test` |
| `scripts/validate-manifest.py` | v2 schema validator: version, object-form, vocabulary, duplicates, existence, drift | VERIFIED | Delivers all 6 checks including disk-to-manifest drift enumeration for commands/ and skills/ |
| `manifest.json` | manifest_version:2, homogeneous objects, 7 conflicts_with annotations | VERIFIED | All 30 commands, 4 agents, 7 prompts, 10 skills, 2 rules as objects; 7 conflicts_with present |
| `Makefile` | Extended test target (Test 4 + Test 5), validate target invoking validator | VERIFIED | Test 4 + Test 5 present; `make validate` calls `python3 scripts/validate-manifest.py` |
| `scripts/lib/state.sh` | 7 functions, atomic write, mkdir lock, stale recovery, no set -euo pipefail | VERIFIED | All 7 functions present; os.replace + tempfile.mkstemp; kill -0 + age>3600 |
| `scripts/tests/test-state.sh` | 5 scenarios: round-trip, kill-9, concurrent lock, dead PID, old mtime | VERIFIED | All 6 pass assertions (Scenario B emits 2 sub-passes); "Results: 6 passed, 0 failed" |
| `templates/base/skills/debugging/SKILL.md` | Committed to git (option-a decision) | VERIFIED | `git ls-files --error-unmatch` succeeds |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Makefile | scripts/tests/test-detect.sh | Test 4 make target | VERIFIED | `grep -q 'bash scripts/tests/test-detect.sh' Makefile` → match at line 64 |
| Makefile | scripts/tests/test-state.sh | Test 5 make target | VERIFIED | `grep -q 'bash scripts/tests/test-state.sh' Makefile` → match at line 67 |
| Makefile | scripts/validate-manifest.py | validate target | VERIFIED | `grep -q 'python3 scripts/validate-manifest.py' Makefile` → match at line 122 |
| scripts/tests/test-detect.sh | scripts/detect.sh | source under overridden HOME | VERIFIED | `source "$DETECT_SH"` at line 39 |
| scripts/tests/test-state.sh | scripts/lib/state.sh | source under overridden HOME | VERIFIED | `source "$STATE_SH"` at lines 38, 62, 72, 107, 111 |
| scripts/lib/state.sh | python3 tempfile.mkstemp + os.replace | write_state heredoc | VERIFIED | `grep -c 'os.replace\|tempfile.mkstemp' scripts/lib/state.sh` → 2 |
| scripts/lib/state.sh | python3 hashlib.sha256 | sha256_file helper | VERIFIED | `grep -q 'hashlib.sha256' scripts/lib/state.sh` → match |
| scripts/validate-manifest.py | manifest.json | MANIFEST_PATH auto-discovery | VERIFIED | Resolves via REPO_ROOT derived from script location |
| scripts/validate-manifest.py | commands/ (disk) | Check 6 os.listdir loop | VERIFIED | Lines 180-187: enumerates commands/*.md, fails on unlisted files |
| scripts/validate-manifest.py | templates/base/skills/ (disk) | Check 6 SKILL.md loop | VERIFIED | Lines 189-197: enumerates skills/*/SKILL.md, fails on unlisted files |

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
| validate-manifest.py: drift check catches unlisted file | `touch commands/ZZZTESTDRIFT.md && python3 scripts/validate-manifest.py 2>&1` | "drift: commands/ZZZTESTDRIFT.md exists on disk but is not in manifest files.commands" — exit 1 | PASS |
| validate-manifest.py: clean after drift file removed | `rm commands/ZZZTESTDRIFT.md && python3 scripts/validate-manifest.py` | "manifest.json validation PASSED" exit 0 | PASS |
| make test: all 5 test groups | `make test` | 14 total passes, "All tests passed!" exit 0 | PASS |
| make shellcheck: no script regressions | `make shellcheck` | "ShellCheck passed" exit 0 | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DETECT-01 | 02-01 | detect_superpowers() returns 0 if cache dir exists with versioned subdir | SATISFIED | Function present; Test 4 Cases 2+4 verify |
| DETECT-02 | 02-01 | detect_gsd() returns 0 if get-shit-done/ + bin/gsd-tools.cjs present | SATISFIED | Function present; Test 4 Cases 3+4 verify |
| DETECT-03 | 02-01 | Cross-reference settings.json enabledPlugins to suppress stale-cache false positives | SATISFIED | jq has() implementation; Test 4 Case 5 verifies |
| DETECT-04 | 02-01 | detect.sh is sourced (not executed); exports HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION | SATISFIED | File sourced in tests; all 4 exports confirmed |
| DETECT-05 | — | Both init-claude.sh and update-claude.sh source detect.sh (production wiring) | DEFERRED TO PHASE 3 | Moved from Phase 2 per commit 5fb6f28; ROADMAP.md Phase 3 requirements now include DETECT-05; REQUIREMENTS.md traceability updated |
| MANIFEST-01 | 02-02 | Each files.* entry is object with path, optional conflicts_with, optional requires_base | SATISFIED | All entries are objects; verified by validator and spot-check |
| MANIFEST-02 | 02-02 | Bump manifest.version to 2 | SATISFIED (deviation) | REQUIREMENTS.md says "manifest.version" (dot) but implementation uses "manifest_version" (underscore) per D-14/Pitfall 4. Plan frontmatter explicitly specifies underscore form. Functionally equivalent. |
| MANIFEST-03 | 02-02 | 7 confirmed SP duplicates annotated with conflicts_with | SATISFIED | 7 entries present; REQUIREMENTS.md amended to reflect live-scan count (option-a) |
| MANIFEST-04 | 02-02 | make validate enforces path existence, no-drift, vocabulary | SATISFIED | Path existence, vocabulary, and disk-to-manifest drift all enforced. Check 6 closes the drift gap. |
| STATE-01 | 02-03 | toolkit-install.json schema: version, mode, detected, installed_files, skipped_files, installed_at | SATISFIED | write_state produces all required fields; Scenario A verifies |
| STATE-02 | 02-03 | Atomic writes via mktemp + mv (never half-written) | SATISFIED | tempfile.mkstemp + os.replace in state.sh; Scenario B kill-9 durability test passes |
| STATE-03 | 02-03 | mkdir-based lock at ~/.claude/.toolkit-install.lock | SATISFIED | acquire_lock/release_lock present; Scenario C concurrent-lock test passes |
| STATE-04 | 02-03 | Each installed_files entry stores SHA256 | SATISFIED | sha256_file via hashlib; Scenario A verifies 64-char hex |
| STATE-05 | 02-03 | Stale-lock recovery: lock >1h with no live PID → reclaim with warning | SATISFIED | Both signals (kill -0 + age>3600); Scenarios D+E both pass |

---

## Anti-Patterns Found

No blockers. Pre-existing markdownlint failures in `CLAUDE.md` and `components/orchestration-pattern.md` are not introduced by Phase 2 and remain out-of-scope here.

---

## Human Verification Required

None — all checks are programmatic for this phase's deliverables. Phase 2 is plumbing only (D-28); no user-visible behavior exists to manually test.

---

## Gaps Summary

No gaps. Both gaps from the initial verification are closed:

- Gap 1 (MANIFEST-04 drift): `validate-manifest.py` Check 6 now enumerates `commands/` and `templates/base/skills/*/SKILL.md` on disk and fails on any file absent from the manifest. Synthetic fixture test confirmed pass/fail behavior.
- Gap 2 (DETECT-05 docketing): DETECT-05 is explicitly assigned to Phase 3 in both ROADMAP.md and REQUIREMENTS.md. It will be verified at Phase 3 closure when `init-claude.sh` and `update-claude.sh` are refactored for mode-aware installs.

---

### Quality Gate Results

| Gate | Result |
|------|--------|
| make test (Tests 1-5) | PASS — 14 total pass assertions, exit 0 |
| make validate | PASS — templates valid, version aligned, manifest schema PASSED, drift clean |
| make shellcheck | PASS — all scripts/*.sh and scripts/lib/*.sh and scripts/tests/*.sh clean |
| make mdlint | PRE-EXISTING FAILURES — CLAUDE.md and components/orchestration-pattern.md errors not introduced by Phase 2 |

---

### Recommended Next Step

All Phase 2 must-haves verified. Advance to Phase 3: Install Flow.

Phase 3 picks up DETECT-05 (source detect.sh in init-claude.sh + update-claude.sh) as its first listed requirement — the production wiring left intentionally deferred in Phase 2 is now correctly scoped to the phase that consumes it (mode selection logic).

---

_Initial verification: 2026-04-17T21:08:56Z (12/14 — gaps_found)_
_Re-verified: 2026-04-17T22:15:00Z (14/14 — passed) after commit 5fb6f28_
_Verifier: Claude (gsd-verifier)_
