---
phase: 23
slug: installer-symmetry-recovery
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from `23-RESEARCH.md §8 Validation Architecture` (HIGH confidence).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (no external test runner) |
| **Config file** | none |
| **Quick run command** | `bash scripts/tests/test-install-banner.sh` |
| **Full suite command** | `make test` (runs all 30 tests after Phase 23 ships) |
| **Estimated runtime** | banner test < 1s · keep-state test ~3-8s (sandbox install + 2 uninstall runs) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (`test-install-banner.sh` for BANNER tasks; `test-uninstall-keep-state.sh` for KEEP tasks once it exists)
- **After every plan wave:** Run all Phase 23 tests (`bash scripts/tests/test-install-banner.sh && bash scripts/tests/test-uninstall-keep-state.sh`)
- **Before `/gsd-verify-work`:** `make test` must be green (all 30 tests including the new Test 30)
- **Max feedback latency:** ~10 seconds for full Phase 23 suite

---

## Per-Task Verification Map

> Filled in fully by planner / executor. Scaffold below shows the contract per REQ-ID.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-XX-XX | XX | X | BANNER-01 | — | banner suppression flag/env behaviour matches `update-claude.sh` | source-grep | `bash scripts/tests/test-install-banner.sh` | ✅ (extended) | ⬜ pending |
| 23-XX-XX | XX | X | KEEP-01 | — | state file preserved on `--keep-state`; deleted otherwise (UN-05 D-06 invariant respected) | integration | `bash scripts/tests/test-uninstall-keep-state.sh` | ❌ Wave 0 | ⬜ pending |
| 23-XX-XX | XX | X | KEEP-02 | — | second `uninstall.sh` after `--keep-state` re-classifies remaining files; base-plugin diff-q invariant holds | integration | `bash scripts/tests/test-uninstall-keep-state.sh` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Observable Signals per Requirement

### BANNER-01

Static source-grep signals (executed by `test-install-banner.sh` extended assertions A4-A7):

1. `grep -q '^NO_BANNER=0' scripts/init-claude.sh` → exit 0 (default-zero present)
2. `grep -q -- '--no-banner) NO_BANNER=1' scripts/init-claude.sh` → exit 0 (argparse clause present)
3. `grep -q 'if \[\[ \$NO_BANNER -eq 0 \]\]' scripts/init-claude.sh` → exit 0 (gate present, correct direction)
4. Same three patterns in `scripts/init-local.sh`
5. `grep -cF "$BANNER" scripts/init-claude.sh` returns `1` (banner string count unchanged — D-02 invariant)
6. `grep -cF "$BANNER" scripts/init-local.sh` returns `1`

### KEEP-01

Integration signals (executed by `test-uninstall-keep-state.sh` S1):

1. After `uninstall.sh --keep-state` run with stdin-driven `N` answers to every `[y/N/d]` prompt:
   `[ -f "$SANDBOX/.claude/toolkit-install.json" ]` → exit 0 (file exists)
2. After a control `uninstall.sh` run WITHOUT `--keep-state` against fresh sandbox:
   `[ ! -f "$SANDBOX/.claude/toolkit-install.json" ]` → exit 0 (file absent — confirms default-delete invariant unchanged)
3. `TK_UNINSTALL_KEEP_STATE=1 uninstall.sh` (env-only path, no flag) → state file present → asserts D-09 env precedence

### KEEP-02

Integration signals (executed by `test-uninstall-keep-state.sh` S1 second-invocation phase):

1. Second `uninstall.sh` (no `--keep-state`) STDOUT contains backup-creation marker (e.g. `Created backup directory:`) → proves script did NOT exit at idempotency guard line 389
2. Second invocation STDOUT contains a MODIFIED classification marker (e.g. `MODIFIED`) → proves classification ran on still-present files
3. Second invocation exit code is `0` → proves base-plugin `diff -q` invariant (UN-05 D-10) still holds (any mutation would `exit 1`)
4. After second invocation (with `y` answers), `[ ! -f "$SANDBOX/.claude/toolkit-install.json" ]` → exit 0 (state file deleted as LAST step on default branch)

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-uninstall-keep-state.sh` — new file covering KEEP-01 and KEEP-02; shape mirrors `scripts/tests/test-uninstall-idempotency.sh`
- [ ] `Makefile` Test 30 target — appends `bash scripts/tests/test-uninstall-keep-state.sh` after existing Test 29
- [ ] `.github/workflows/quality.yml` — rename `Tests 21-29` step → `Tests 21-30`, append the new test invocation
- [ ] No framework install needed — existing bash + standard GNU/BSD tools sufficient

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `--no-banner` documented in `--help` output of `init-local.sh` | BANNER-01 D-06 | source-grep covers presence of clause; visual check confirms phrasing matches existing flag style | Run `bash scripts/init-local.sh --help` and confirm a `--no-banner` row appears alongside other flags |
| `--keep-state` documented in `--help` of `uninstall.sh` | KEEP-01 D-08 | same — phrasing not source-greppable beyond presence | Run `bash scripts/uninstall.sh --help` and confirm `--keep-state` row reads naturally |
| `docs/INSTALL.md` Installer Flags section mentions `--no-banner` and `--keep-state` (Claude's Discretion) | BANNER-01, KEEP-01 | doc audit — wording / placement | Read `docs/INSTALL.md` after merge; confirm both flags appear in the Installer Flags table |

*If none above ship: manual block can be removed when all phase tasks complete.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (BANNER tasks → existing test extension; KEEP tasks → Wave 0 new test)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`test-uninstall-keep-state.sh` is the only Wave 0 artifact)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner confirms map is complete)

**Approval:** pending
