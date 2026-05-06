---
phase: 37
plan: 02
subsystem: testing
tags: [secrets, tests, hermetic, ci, makefile, sec-01, sec-02, sec-03, sec-04, sec-05, sec-06, test-01]
requires:
  - phase: 37-01-secrets-lib
    provides: scripts/lib/project-secrets.sh (4 public + 2 private functions, exact stderr phrases)
provides:
  - "scripts/tests/test-project-secrets.sh — hermetic 31-assertion contract for SEC-01..06"
  - "Makefile Test 49 row + standalone test-project-secrets target"
  - ".github/workflows/quality.yml orphan-triage step bumped to Tests 35-49"
  - "manifest.json files.libs[] entry for scripts/lib/project-secrets.sh (Rule-3 deviation — wave-1 gap)"
affects:
  - phase 38 (mcp_wizard_run scope routing — primary consumer of the lib; this contract guards regressions)
  - phase 40 (uninstall negative-contract — verifies project .env never opened)
  - phase 41 (DIST-01 manifest version bump — manifest entry for the lib already in place)
tech-stack:
  added: []
  patterns:
    - "Hermetic test scaffold: mktemp -d sandbox + trap rm -rf cleanup, no $HOME mutation"
    - "Cross-platform 0600 mode check helper (BSD `stat -f %Mp%Lp` then GNU `stat -c %a` fallback)"
    - "TK_MCP_TTY_SRC=<(printf 'y/N\\n') process-substitution seam for collision-prompt branches"
    - "Per-key-distinct metacharacter rejection assertions (DOLLAR, BTICK, BSLASH, DQUOTE, SQUOTE, NL)"
    - "Exact-fixed-line assertions on stderr refusal phrases — guards against silent message drift"
key-files:
  created:
    - scripts/tests/test-project-secrets.sh
  modified:
    - Makefile
    - .github/workflows/quality.yml
    - manifest.json
key-decisions:
  - "Per-block test layout (A=write_env, B=metacharacters, C=gitignore, D=render, E=validate) makes regressions name-localizable in CI logs"
  - "Both rc-check AND stderr-phrase asserts in SEC-05/SEC-06 — rc alone would miss silent message drift"
  - "Three-commit shape (test → wiring → manifest) keeps each commit independently revertable"
patterns-established:
  - "PASS=31 ceiling well above 18 floor — gives headroom when future SEC clauses added"
  - "Block-letter labels (T7..T12, T14b/T21b) — 'b' suffix for paired stderr-phrase asserts on the same trigger"
  - "Wave-1 manifest gap surfaces at wave-2 make check time — recorded as Rule-3 deviation, fixed in same plan"
requirements-completed:
  - TEST-01

# Metrics
duration: ~5 min
completed: 2026-05-05T16:14:13Z
---

# Phase 37 Plan 02: Test Contract Summary

**31 hermetic assertions lock the project-secrets boundary: every clause of SEC-01..06 — file mode 0600 on first write AND after rewrite, idempotent gitignore append with `*.env`/`# .env` false-negative invariants, all six metacharacter rejections with exact-phrase stderr asserts, `${VAR}` render exact form, and SEC-05 literal refusal + ALLOW_LITERAL bypass — fail loudly if regressed. Wired into `make test`, standalone `make test-project-secrets`, and the CI orphan-triage step (renamed Tests 35-43 → Tests 35-49).**

## Performance

- **Duration:** ~5 min (302 s)
- **Started:** 2026-05-05T16:09:11Z
- **Completed:** 2026-05-05T16:14:13Z
- **Tasks:** 3 plan tasks + 1 deviation fix
- **Files modified:** 3 modified, 1 created

## Accomplishments

- **31 PASS / 0 FAIL** in `scripts/tests/test-project-secrets.sh` (vs. ≥18 floor in D-18 / TEST-01)
- Hermetic + idempotent + double-run-safe: `mktemp -d /tmp/project-secrets.XXXXXX`, no `$HOME` mutation, trap cleanup, two consecutive runs both exit 0
- Every SEC-05 / SEC-06 / SEC-03 stderr refusal phrase grep-asserted verbatim — silent message drift now fails CI
- Reused existing `TK_MCP_TTY_SRC` seam (D-05) — no new TTY env var coined
- New `TK_PROJECT_SECRETS_ALLOW_LITERAL` bypass exercised AND its loud `⚠ test seam only` warning asserted
- `make test-project-secrets` runs the standalone target in isolation
- CI step name extended from `Tests 35-43` to `Tests 35-49 — orphan triage + Phase 37 project secrets library (audit INF-MED-1, SEC-01..06, TEST-01)`
- `make check` quality gate green end-to-end (resolved a wave-1 manifest-drift gap in the process)

## Task Commits

Each task committed atomically:

1. **Task 1: Author scripts/tests/test-project-secrets.sh — 31 hermetic assertions** — `8f30645` (feat)
2. **Task 2+3: Wire test into Makefile + CI quality.yml** — `7b18b5a` (chore)
3. **Deviation fix: manifest.json files.libs[] += scripts/lib/project-secrets.sh** — `325ede1` (chore — Rule 3)

## Files Created/Modified

- **Created:** `scripts/tests/test-project-secrets.sh` — 259-line hermetic test suite with assert helpers, mode-check helper, 31 assertions across 5 logical blocks
- **Modified:** `Makefile` — `.PHONY` += `test-project-secrets`; `test:` target gains `Test 49` row; new standalone `test-project-secrets:` target after `test-catalog-scope-fallback`
- **Modified:** `.github/workflows/quality.yml` — orphan-triage step name bumped (`Tests 35-43` → `Tests 35-49 — orphan triage + Phase 37 project secrets library …`); `bash scripts/tests/test-project-secrets.sh` appended to the `run:` block (line 156)
- **Modified:** `manifest.json` — `files.libs[]` insert of `scripts/lib/project-secrets.sh` (alpha-ordered between `optional-plugins.sh` and `skills.sh`); resolves a wave-1 omission that broke the disk-vs-manifest drift validator

## Decisions Made

- **Aimed at PASS=31, not the bare 18 floor.** D-18 says ≥18; the 25-assertion menu in PATTERNS.md was the natural target. Adding paired stderr-phrase asserts (T7b..T11b, T14b, T21b, T23b) is cheap and locks the exact wording — prevents a future "refactor stderr messages" PR from breaking the contract silently.
- **Used distinct keys per metacharacter (DOLLAR, BTICK, BSLASH, DQUOTE, SQUOTE, NL).** Reusing `BAD` across all six would cause the second through sixth attempts to hit the collision-prompt branch, masking the real refusal path. Distinct keys keep every assertion exercising the validator code, not the load-existing-and-prompt code.
- **Did NOT export TK_MCP_CONFIG_HOME.** PATTERNS.md §"Test-seam env-var naming" row 3 explicitly forbids it: setting that seam would mask a regression where the lib accidentally writes outside `<project>/.env`.
- **Process substitution `<(printf 'y\n')` for collision branches.** Bash 3.2-safe and matches `test-mcp-secrets.sh:78,83` precedent. Each call gets a fresh fd — survives the second run for free.
- **Three commits, not one.** The deviation fix to `manifest.json` is mechanically and semantically separable from the test+wiring; revert-isolating it preserves the option to roll back the manifest change without touching the test.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Wave-1 manifest.json drift broke `make check`**

- **Found during:** Final phase verification (`make check` after Task 3 wiring)
- **Issue:** Plan 37-01 created `scripts/lib/project-secrets.sh` on disk but did NOT update `manifest.json` `files.libs[]`. The disk-vs-manifest drift validator (`scripts/validate-manifest.py:243-246`, "Audit M1" guard) hard-fails on the first occurrence. CONTEXT.md scheduled the manifest insert for Phase 41 / DIST-01, but the validator predates that phase and is a hard gate today. Without the entry, `update-claude.sh` would silently skip propagating the lib to existing users.
- **Fix:** Added `{"path": "scripts/lib/project-secrets.sh"}` between `optional-plugins.sh` and `skills.sh` (alpha order: `o` < `p` < `s`) per PATTERNS.md §`manifest.json` lines 552-583. `update-claude.sh` auto-discovers via the v4.4 LIB-01 D-07 jq path — zero installer code changes.
- **Files modified:** `manifest.json` (3-line insert)
- **Verification:** `python3 scripts/validate-manifest.py` exits 0; `make check` reaches `All checks passed!`. Pre-fix output was `ERROR: drift: scripts/lib/project-secrets.sh exists on disk but is not in manifest files.libs`.
- **Committed in:** `325ede1` (separate atomic commit so it's independently revertable)

---

**Total deviations:** 1 auto-fixed (1 blocking — Rule 3)
**Impact on plan:** Necessary for the plan's own `make check` success criterion. The deferred Phase 41 / DIST-01 task that would have done this insert is now done; Phase 41 still needs the version bump and CHANGELOG `[5.0.0]` entry but no longer needs to touch `files.libs[]`. No scope creep — this is a 3-line correction to a wave-1 omission.

## Issues Encountered

- None during planned work. The manifest drift surfaced as a clean validator error with a precise actionable message — fixed in <2 min once observed.

## Self-Check: PASSED

- `scripts/tests/test-project-secrets.sh` exists (259 lines) — verified via `[ -f ... ]`
- All three commits exist in `git log`:
  - `8f30645` — `feat(37-02): scripts/tests/test-project-secrets.sh — hermetic SEC-01..06 contract`
  - `7b18b5a` — `chore(37-02): wire test-project-secrets into Makefile + CI quality.yml`
  - `325ede1` — `chore(37-02): manifest.json files.libs[] += scripts/lib/project-secrets.sh`
- Test exits 0 with `=== Results: 31 passed, 0 failed ===`
- Double-run safety verified (two back-to-back runs both exit 0)
- `shellcheck -S warning scripts/tests/test-project-secrets.sh` clean
- `make test-project-secrets` exits 0
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` exits 0
- `make check` exits 0 with `All checks passed!`

## Threat Model Mitigations (T-37-07..T-37-11)

| Threat ID | Status | Mitigation locked by which assertion |
|---|---|---|
| T-37-07 (lib regression breaks SEC-05 literal-refusal) | mitigated | T21 (rc=1) + T21b (exact stderr phrase `refusing to write literal value into .mcp.json`) |
| T-37-08 (lib regression breaks SEC-06 metacharacter rejection) | mitigated | T7..T12 — six distinct rc-rejections + T7b..T11b paired stderr-phrase asserts |
| T-37-09 (.env mode regresses to non-0600 on rewrite path) | mitigated | T3 (first-write mode) + T6 (rewrite-path mode) — both via BSD+GNU dual-stat helper |
| T-37-10 (TK_PROJECT_SECRETS_ALLOW_LITERAL leaks into prod via copypaste) | mitigated | T23b asserts the loud `test seam only` warning is emitted on every honored use |
| T-37-11 (DoS via pathological JSON to validate_mcp_env_block) | accept | Validator caller is `project_secrets_render_mcp_env_block` (tiny inputs); no untrusted external JSON enters this code path |

## Next Phase Readiness

- **Phase 37 closes:** SEC-01..06 + TEST-01 all locked (7/7 requirement IDs delivered across plans 37-01 and 37-02). `make check` is the green gate Phase 38 inherits.
- **Phase 38 (`mcp_wizard_run` scope routing):** Can call all four public functions; the regression net under each is now in CI on every PR.
- **Phase 40 (uninstall UN-SEC-04):** Asserts the **negative** contract (uninstall.sh never opens `<project>/.env`). The lib's contract surface is now grep-verifiable, so the uninstall test can grep for `project_secrets_*` and ensure none of those names appear in any uninstall code path.
- **Phase 41 (DIST-01):** Still owns the `manifest.json` `version: 4.9.0 → 5.0.0` bump, the `CHANGELOG.md` `[5.0.0]` entry, and the `init-local.sh --version` alignment. The `files.libs[]` insert that PATTERNS.md §`manifest.json` lines 552-583 had scheduled for Phase 41 is now already done (this plan, deviation 1).

## Threat Flags

None. The new surface is contained to a hermetic test file under `scripts/tests/` plus three line-level edits to existing build/CI manifests; no new network endpoints, no new auth paths, no new file access patterns outside the documented `mktemp -d` sandbox.
