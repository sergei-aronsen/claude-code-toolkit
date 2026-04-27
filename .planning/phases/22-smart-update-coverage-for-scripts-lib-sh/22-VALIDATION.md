---
phase: 22
slug: smart-update-coverage-for-scripts-lib-sh
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + shellcheck + markdownlint + custom validate (`make check`) |
| **Config file** | `Makefile`, `.markdownlint.json`, `.github/workflows/quality.yml` |
| **Quick run command** | `make shellcheck && make mdlint` |
| **Full suite command** | `make check && make test` |
| **Estimated runtime** | ~30s for `make check`; ~90s for `make test` (28 tests including new Test 29) |

---

## Sampling Rate

- **After every task commit:** Run `make shellcheck` (touches scripts/) or `make mdlint` (touches docs/markdown)
- **After every plan wave:** Run `make check`
- **Before `/gsd-verify-work`:** `make check && make test` must be green; `bash scripts/tests/test-update-libs.sh` exits 0
- **Max feedback latency:** 30 seconds (per-task), 90 seconds (per-wave)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | LIB-01 | — | manifest.json registers all 6 lib paths under `files.libs[]` with version 4.4.0 | structural | `jq '.files.libs \| length' manifest.json` (expect 6); `make version-align` | ✅ | ⬜ pending |
| 22-01-02 | 01 | 1 | LIB-01 | — | CHANGELOG.md `[4.4.0]` exists with Phase 21+22 consolidated entries | structural | `grep -m1 '^## \[' CHANGELOG.md` (expect `[4.4.0]`); `make version-align` | ✅ | ⬜ pending |
| 22-02-01 | 02 | 2 | LIB-02 | — | hermetic test exercises stale-refresh, clean-untouched, fresh-install, modified-prompt-N, uninstall round-trip across all 6 lib files | integration | `bash scripts/tests/test-update-libs.sh` (PASS=N FAIL=0) | ❌ W0 | ⬜ pending |
| 22-02-02 | 02 | 2 | LIB-02 | — | Makefile Test 29 invokes test-update-libs.sh; CI step renamed `Tests 21-29` runs same script | structural | `grep 'test-update-libs.sh' Makefile`; `grep 'Tests 21-29\|test-update-libs' .github/workflows/quality.yml` | ❌ W0 | ⬜ pending |
| 22-02-03 | 02 | 2 | LIB-02 | — | `make check` (markdownlint + shellcheck + validate + version-align) stays green after all changes | regression | `make check` (exit 0) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-update-libs.sh` — new file with 5 hermetic scenarios (S1-S5), shellcheck-clean, exits non-zero on failure
- [ ] Makefile Test 29 block (mirrors Test 28 inline pattern)
- [ ] `.github/workflows/quality.yml` step renamed `Tests 21-28` → `Tests 21-29` with new test invocation appended
- [ ] CHANGELOG.md `[4.4.0]` Added section consolidating Phase 21 (BOOTSTRAP-01..04) and Phase 22 (LIB-01, LIB-02)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real `update-claude.sh` against published 4.4.0 release in clean `$HOME` refreshes all 6 lib files | LIB-02 | Requires actual GitHub raw-content fetch + clean user environment (cannot reproduce hermetically before release) | After tagging v4.4.0: in clean `$HOME`, run `init-local.sh` (any older version), then `bash <(curl ... update-claude.sh)`, verify `~/.claude/scripts/lib/*.sh` all match repo SHA256 |
| Stale lib detection prompt (S4 modified-file `[y/N/d]` path) under real TTY | LIB-02 | Hermetic test exercises N-default path only; visual confirmation of prompt + diff display needs real terminal | Manually mutate one installed lib file, run `update-claude.sh`, verify prompt appears with correct file name and diff |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (test-update-libs.sh + Makefile + CI)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter once all tasks land

**Approval:** pending
