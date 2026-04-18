---
phase: 03
slug: install-flow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | POSIX bash test harnesses (no `bats` per Phase 1 D-27 — TEST-01 is v4.1) |
| **Config file** | none — harnesses are self-contained shell scripts |
| **Quick run command** | `make shellcheck` (~3s) |
| **Full suite command** | `make test` (~30s, runs Tests 1–8 after this phase adds 6/7/8) |
| **Estimated runtime** | ~30s full suite, ~3s shellcheck |

---

## Sampling Rate

- **After every task commit:** Run `make shellcheck` (catches script regressions immediately)
- **After every plan wave:** Run `make test` (full suite — Tests 1–8)
- **Before `/gsd-verify-work`:** `make check` must be green except pre-existing CLAUDE.md / components/orchestration-pattern.md mdlint errors carried from Phase 2
- **Max feedback latency:** 30s for full suite

---

## Per-Task Verification Map

> Filled by the planner during plan creation. Below is the framework only — the planner expands each task with its automated command. Skeleton:

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-* | 01 | 1 | DETECT-05 | — | detect.sh sourceable from init/update scripts | unit | `make test` Test 4 + new Test 6 | ✅ existing | ⬜ pending |
| 03-02-* | 02 | 2 | MODE-01..06 | — | 4 modes + skip-list + dry-run | unit | `bash scripts/tests/test-modes.sh`, `bash scripts/tests/test-dry-run.sh` | ❌ W0 | ⬜ pending |
| 03-03-* | 03 | 3 | SAFETY-01..04 | — | atomic merge, foreign keys preserved, backup, restore | unit | `bash scripts/tests/test-safe-merge.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> Files that MUST exist before per-task verification can run. Planner ensures these are created in Wave 1 (Plan 03-01) before later waves build on them.

- [ ] `scripts/tests/test-modes.sh` — fixture-driven harness asserting each of 4 modes computes correct skip-set against fixture manifest
- [ ] `scripts/tests/test-dry-run.sh` — asserts grouped output format + zero filesystem touches (compare working-tree state before/after)
- [ ] `scripts/tests/test-safe-merge.sh` — round-trip test: write known foreign keys to fixture settings.json, run TK merge, assert foreign keys unchanged + backup file present + simulated mid-merge failure restores from backup
- [ ] `Makefile` test target extended with Tests 6/7/8 (one bash invocation per harness, matches existing Test 4 / Test 5 pattern)

*Existing infrastructure (`make shellcheck`, `make validate`, `scripts/tests/test-detect.sh`, `scripts/tests/test-state.sh`) covers all detection + state-file requirements from Phase 2 — no Wave 0 additions needed there.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Interactive mode prompt under real `< /dev/tty` | MODE-02, MODE-03 | Stdin from automated test harness ≠ real tty; `< /dev/tty` may behave differently | (1) Run `bash scripts/init-claude.sh` in a real terminal with no `--mode` flag (2) Verify recommendation prints + prompt appears (3) Press 1–4 to override, confirm install proceeds with chosen mode |
| Mode-change prompt under `curl \| bash` (no /dev/tty) | D-42 | `curl \| bash` strips stdin; need to prove fail-closed behavior | (1) Pipe init script via curl (2) Pass `--mode complement-gsd` when state file records `standalone` (3) Verify script exits non-zero with "Pass --force-mode-change to bypass" |
| settings.json merge co-existence with real SP + GSD | SAFETY-02 | Requires SP and GSD actually installed on machine — fixture can simulate but ground truth needs live install | (1) Install SP + GSD on a clean machine (2) Run TK init in complement-full mode (3) Verify SP + GSD hooks still fire (test by triggering each plugin's known hook) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (3 new test harnesses + Makefile extension)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter (planner flips this when expanded matrix is filled in)

**Approval:** pending — flips to approved after planner expands per-task matrix
