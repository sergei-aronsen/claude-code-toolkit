---
phase: 5
slug: migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash integration tests + `assert_eq` helper (in-repo, no external deps) |
| **Config file** | `Makefile` test target (lines 42-87) |
| **Quick run command** | `bash scripts/tests/test-migrate-diff.sh` |
| **Full suite command** | `make test` |
| **Estimated runtime** | ~45 seconds (14 tests after Phase 5 adds 3) |

---

## Sampling Rate

- **After every task commit:** Run `make check` (shellcheck + markdownlint + validate)
- **After every plan wave:** Run `make test` (all 14 tests)
- **Before `/gsd-verify-work`:** `make test && make check` both green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-XX | 01 | 1 | D-75 | — | `write_state` v2 serializes `synthesized_from_filesystem` | unit | `bash scripts/tests/test-migrate-diff.sh` (fixture seed asserts) | ❌ W0 | ⬜ pending |
| 05-01-XX | 01 | 1 | D-76 / D-77 | — | `update-claude.sh` emits single-line CYAN hint when triple-AND holds | integration | extend `scripts/tests/test-update-drift.sh` | ✅ existing | ⬜ pending |
| 05-01-XX | 01 | 1 | D-71 / sp_equivalent | — | `manifest.json` carries `sp_equivalent` for 6 of 7 TK→SP mismatches | smoke | `jq '.files[].entries[] \| select(.conflicts_with) \| .sp_equivalent' manifest.json` | ✅ existing | ⬜ pending |
| 05-02-XX | 02 | 2 | MIGRATE-01 | — | `scripts/migrate-to-complement.sh` exists and is standalone (not a flag) | smoke | `test -f scripts/migrate-to-complement.sh && test -x scripts/migrate-to-complement.sh` | ❌ W0 | ⬜ pending |
| 05-02-XX | 02 | 2 | MIGRATE-02 | — | Three-column hash diff (TK/on-disk/SP) printed before any prompt | functional | `bash scripts/tests/test-migrate-diff.sh` | ❌ W0 | ⬜ pending |
| 05-02-XX | 02 | 2 | MIGRATE-03 / D-73 / D-74 | T-05-PROMPT-BYPASS | `[y/N/d]` default-deny; modified-file extra warning; `< /dev/tty` guard | functional | `bash scripts/tests/test-migrate-flow.sh` (scenarios: clean, modified, no-tty) | ❌ W0 | ⬜ pending |
| 05-02-XX | 02 | 2 | MIGRATE-04 | T-05-NO-BACKUP | Full `cp -R ~/.claude/` backup completes BEFORE any removal; path echoed | functional | `bash scripts/tests/test-migrate-flow.sh` (accept-all asserts backup dir exists) | ❌ W0 | ⬜ pending |
| 05-03-XX | 03 | 3 | MIGRATE-05 | — | `toolkit-install.json` rewritten with new mode + `skipped_files[]` for kept files | functional | `bash scripts/tests/test-migrate-flow.sh` (state JSON assertions) | ❌ W0 | ⬜ pending |
| 05-03-XX | 03 | 3 | MIGRATE-06 / D-78 | — | Second run prints `Already migrated to <mode>. Nothing to do.` + exit 0 | functional | `bash scripts/tests/test-migrate-idempotent.sh` (scenario 1) | ❌ W0 | ⬜ pending |
| 05-03-XX | 03 | 3 | D-78 self-heal | — | Manual state rollback + duplicates gone → still exits 0 without re-removal | functional | `bash scripts/tests/test-migrate-idempotent.sh` (scenario 2) | ❌ W0 | ⬜ pending |
| 05-03-XX | 03 | 3 | D-79 partial | — | Decline-one run writes `mode=complement-sp` + `skipped_files[].reason="kept_by_user"` | functional | `bash scripts/tests/test-migrate-flow.sh` (decline-one scenario) | ❌ W0 | ⬜ pending |
| 05-03-XX | 03 | 3 | lock | T-05-RACE | `acquire_lock` held for whole migrate run; second concurrent invocation blocks or aborts | functional | `bash scripts/tests/test-migrate-flow.sh` (concurrent-lock scenario) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-migrate-diff.sh` — Test 12, stubs for MIGRATE-02 + D-73 + D-75
- [ ] `scripts/tests/test-migrate-flow.sh` — Test 13, stubs for MIGRATE-03/04/05 + D-74 + D-79 + lock
- [ ] `scripts/tests/test-migrate-idempotent.sh` — Test 14, stubs for MIGRATE-06 + D-78
- [ ] `scripts/tests/fixtures/manifest-migrate-v2.json` — fixture manifest with `sp_equivalent`
- [ ] `scripts/tests/fixtures/sp-cache/` — fixture SP plugin cache tree (mirrors live SP 5.0.7 layout per D-71 research)
- [ ] `Makefile` — `test` target extended with Tests 12/13/14 (after existing Tests 9/10/11)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real `curl \| bash` install path survives prompts | MIGRATE-03 | `/dev/tty` semantics differ between test FIFO and real terminal | On a machine with SP 5.0.7 installed + TK v3.x state: run `curl -sSLf .../migrate-to-complement.sh \| bash` — verify three-way diff renders, prompts respond to tty, backup created, no abort |
| SP plugin-cache layout drift | D-71 / A1 | Live SP version may upgrade between Phase 5 ship and user install; skill directory names may change | Quarterly: re-run dev-machine grep against latest SP release, confirm 7 `sp_equivalent` paths still resolve; if drift, patch manifest + cut v4.0.x |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (3 new test harnesses + 2 fixtures)
- [ ] No watch-mode flags (all tests exit cleanly)
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
