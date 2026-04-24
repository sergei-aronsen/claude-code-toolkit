---
phase: 8
slug: release-quality
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core v1.13.0 (install: `brew install bats-core` / `apt-get install bats`) |
| **Config file** | none — bats discovers `*.bats` files by glob |
| **Quick run command** | `bash scripts/validate-release.sh --self-test` (≤2 s helper checks) |
| **Full suite command** | `make test-matrix-bats` (runs all 5 bats files, ~90 s locally) |
| **Estimated runtime** | ~90 s full bats matrix; ~2 s self-test; ~0.5 s cell-parity |

---

## Sampling Rate

- **After every task commit:** `bash scripts/validate-release.sh --self-test` (fast, helper correctness) + `make shellcheck` + `make mdlint`
- **After every plan wave:** `make check` (lint + validate + cell-parity + all existing gates)
- **Before `/gsd-verify-work`:** `make test-matrix-bats` green AND `bash scripts/validate-release.sh --all` green (dual-runner parity)
- **Max feedback latency:** 90 s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 0 | REL-01 | — | Helpers lib exists, sourceable by both runners | integration | `bash -c 'source scripts/tests/matrix/lib/helpers.bash && type assert_eq'` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | REL-01 | — | Bash runner still green after helper extraction | regression | `bash scripts/validate-release.sh --self-test` exits 0 | ✅ (existing) | ⬜ pending |
| 08-01-03 | 01 | 1 | REL-01 | — | Bash full matrix still passes 63 assertions | regression | `bash scripts/validate-release.sh --all` exits 0, counts 63 `✓` | ✅ (existing) | ⬜ pending |
| 08-01-04 | 01 | 2 | REL-01 | — | standalone.bats file has 3 @test with 19 asserts | unit | `bats scripts/tests/matrix/standalone.bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-05 | 01 | 2 | REL-01 | — | complement-sp.bats has 3 @test with 15 asserts | unit | `bats scripts/tests/matrix/complement-sp.bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-06 | 01 | 2 | REL-01 | — | complement-gsd.bats has 3 @test with 13 asserts | unit | `bats scripts/tests/matrix/complement-gsd.bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-07 | 01 | 2 | REL-01 | — | complement-full.bats has 3 @test with 15 asserts | unit | `bats scripts/tests/matrix/complement-full.bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-08 | 01 | 2 | REL-01 | — | translation-sync.bats has 1 @test with 1 assert | unit | `bats scripts/tests/matrix/translation-sync.bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-09 | 01 | 3 | REL-01 | — | make test-matrix-bats green | integration | `make test-matrix-bats` exits 0 | ❌ W0 | ⬜ pending |
| 08-01-10 | 01 | 3 | REL-01 | — | Parity audit: bash PASS count == bats PASS count | unit (shell) | `diff <(bash scripts/validate-release.sh --all 2>&1 \| grep -c '^  ✓') <(echo 63)` and same for bats tap output | ❌ W0 | ⬜ pending |
| 08-01-11 | 01 | 3 | REL-01 | — | CI test-matrix-bats job added to quality.yml | integration | `grep 'test-matrix-bats' .github/workflows/quality.yml` | ✅ (existing modified) | ⬜ pending |
| 08-02-01 | 02 | 0 | REL-02 | — | scripts/cell-parity.sh exists + executable | unit | `test -x scripts/cell-parity.sh` | ❌ W0 | ⬜ pending |
| 08-02-02 | 02 | 1 | REL-02 | — | cell-parity detects all 13 cells in 3 surfaces | unit | `bash scripts/cell-parity.sh` exits 0 after INSTALL.md has --cell added | ❌ W0 | ⬜ pending |
| 08-02-03 | 02 | 1 | REL-02 | — | cell-parity fails on injected drift | unit | remove one `--cell` from INSTALL.md, `bash scripts/cell-parity.sh` exits 1, restore | ❌ manual | ⬜ pending |
| 08-02-04 | 02 | 1 | REL-02 | — | INSTALL.md carries 13 `--cell <name>` commands | unit | `grep -c -- '--cell [a-z]' docs/INSTALL.md` ≥ 13 | ✅ (existing modified) | ⬜ pending |
| 08-02-05 | 02 | 1 | REL-02 | — | INSTALL.md intro states "13 cells" (not "12") | unit | `grep '13 cells' docs/INSTALL.md` returns match | ✅ (existing modified) | ⬜ pending |
| 08-02-06 | 02 | 2 | REL-02 | — | make check includes cell-parity | unit | `make -n check \| grep cell-parity` returns match | ✅ (existing modified) | ⬜ pending |
| 08-02-07 | 02 | 2 | REL-02 | — | CI runs cell-parity under validate-templates | unit | `grep -B2 'cell-parity' .github/workflows/quality.yml` returns match | ✅ (existing modified) | ⬜ pending |
| 08-03-01 | 03 | 0 | REL-03 | — | `--collect-all` flag parsed in dispatcher | unit | `bash scripts/validate-release.sh --collect-all --help 2>&1` recognizes flag | ✅ (existing modified) | ⬜ pending |
| 08-03-02 | 03 | 1 | REL-03 | — | `--collect-all` runs all 13 cells (no fail-fast) | integration | inject one cell failure, `bash scripts/validate-release.sh --collect-all` runs all 13 then reports | ❌ manual | ⬜ pending |
| 08-03-03 | 03 | 1 | REL-03 | — | `--collect-all` emits aggregated ASCII table | integration | `bash scripts/validate-release.sh --collect-all 2>&1 \| grep -E 'Cell[[:space:]]+\|[[:space:]]+Pass'` returns match | ❌ manual | ⬜ pending |
| 08-03-04 | 03 | 1 | REL-03 | — | `--collect-all` exit 0 when all pass, exit 1 on any fail | integration | green run exits 0; inject failure, exits 1 | ❌ manual | ⬜ pending |
| 08-03-05 | 03 | 1 | REL-03 | — | `--all` default still fail-fast (no regression) | regression | existing `--all` behavior unchanged, exits at first fail | ✅ (existing) | ⬜ pending |
| 08-03-06 | 03 | 1 | REL-03 | — | `--all --collect-all` together = arg error | unit | `bash scripts/validate-release.sh --all --collect-all` exits 2 | ❌ manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/matrix/lib/helpers.bash` — extracted from `validate-release.sh` (assert_eq, assert_contains, assert_state_schema, assert_settings_foreign_intact, assert_skiplist_clean, assert_no_agent_collision, sandbox_setup, stage_sp_cache, stage_gsd_cache, setup_v3x_worktree, compute_skip_set, sha256_file, PASS/FAIL counters, color constants). Sourced by both `validate-release.sh` and all `*.bats` files.
- [ ] `scripts/tests/matrix/standalone.bats` — 3 @test (standalone-fresh, standalone-upgrade, standalone-rerun), 19 assertions.
- [ ] `scripts/tests/matrix/complement-sp.bats` — 3 @test, 15 assertions.
- [ ] `scripts/tests/matrix/complement-gsd.bats` — 3 @test, 13 assertions.
- [ ] `scripts/tests/matrix/complement-full.bats` — 3 @test, 15 assertions.
- [ ] `scripts/tests/matrix/translation-sync.bats` — 1 @test, 1 assertion.
- [ ] `scripts/cell-parity.sh` — pure-shell REL-02 parity checker.
- [ ] `Makefile` — add `cell-parity` + `test-matrix-bats` targets, wire `cell-parity` into `check`.
- [ ] `docs/INSTALL.md` — add 13 `--cell <name>` commands to tables; fix "12 cells" → "13 cells" intro.
- [ ] `.github/workflows/quality.yml` — add `test-matrix-bats` CI job; wire `cell-parity` step into `validate-templates`; pin `bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43 # v4.0.0`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| cell-parity detects injected drift | REL-02 | Destructive test needs manual revert | Remove one `--cell <name>` line from `docs/INSTALL.md`, run `bash scripts/cell-parity.sh`, confirm exit 1 with the cell name in output, `git checkout docs/INSTALL.md` to restore. |
| `--collect-all` exit 1 on mixed pass/fail | REL-03 | Requires synthetic failure injection | Temporarily modify one cell body (e.g., `assert_eq "0" "1" "force-fail"`), run `bash scripts/validate-release.sh --collect-all`, confirm all 13 cells ran, aggregated table shows 12 PASS / 1 FAIL, exit code 1. Revert change. |
| `--collect-all` aggregated table format | REL-03 | Visual output; ASCII layout is reviewer-judgeable | Read stdout against fixture in plan. Columns: `Cell` left-aligned ~25 chars, `Pass`/`Fail` right-aligned 5 chars, `Status` 6 chars. Summary line: `Matrix: X/13 cells passed, Y assertions passed, Z assertions failed`. |
| `--all --collect-all` mutex error | REL-03 | Error-path test — non-failure case already covered | Run `bash scripts/validate-release.sh --all --collect-all`, confirm exit 2 with error message `--all and --collect-all are mutually exclusive`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (helpers.bash, 5 bats files, cell-parity.sh)
- [ ] No watch-mode flags (bats and validate-release.sh both single-shot)
- [ ] Feedback latency < 90 s
- [ ] `nyquist_compliant: true` set in frontmatter after planner confirms test map completeness

**Approval:** pending
