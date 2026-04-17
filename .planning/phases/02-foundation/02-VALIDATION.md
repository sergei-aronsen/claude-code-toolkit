---
phase: 2
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core (bash test framework) + shellcheck + markdownlint |
| **Config file** | `tests/bats/` directory; `.markdownlint.json`; `.shellcheckrc` (if needed) |
| **Quick run command** | `bats tests/bats/02-*.bats` |
| **Full suite command** | `make check && bats tests/bats/` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats tests/bats/02-*.bats` (phase-scoped tests)
- **After every plan wave:** Run `make check && bats tests/bats/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-00-01 | 00 | 0 | — | — | bats + jq installed | infra | `command -v bats && command -v jq` | ❌ W0 | ⬜ pending |
| 2-01-01 | 01 | 1 | DETECT-01 | — | detect.sh sourceable without altering caller errexit | unit | `bats tests/bats/02-detect-sourcing.bats` | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | DETECT-02 | — | HAS_SP=true iff settings.json has enabledPlugins superpowers AND cache dir exists | unit | `bats tests/bats/02-detect-sp.bats` | ❌ W0 | ⬜ pending |
| 2-01-03 | 01 | 1 | DETECT-03 | — | HAS_GSD=true iff ~/.claude/get-shit-done/bin/gsd-tools.cjs exists | unit | `bats tests/bats/02-detect-gsd.bats` | ❌ W0 | ⬜ pending |
| 2-01-04 | 01 | 1 | DETECT-04 | — | Stale cache + disabled in settings → HAS_SP=false (no false positive) | unit | `bats tests/bats/02-detect-disabled.bats` | ❌ W0 | ⬜ pending |
| 2-01-05 | 01 | 1 | DETECT-05 | — | All four combos (neither/SP-only/GSD-only/both) produce correct vars | unit | `bats tests/bats/02-detect-matrix.bats` | ❌ W0 | ⬜ pending |
| 2-02-01 | 02 | 2 | MANIFEST-01 | — | manifest.json parses as valid JSON with required top-level keys | unit | `jq -e '.manifest_version and .files' manifest.json` | ❌ W0 | ⬜ pending |
| 2-02-02 | 02 | 2 | MANIFEST-02 | — | Every duplicate file has conflicts_with annotation | unit | `bats tests/bats/02-manifest-conflicts.bats` | ❌ W0 | ⬜ pending |
| 2-02-03 | 02 | 2 | MANIFEST-03 | — | ≥7 conflict entries (scoped down from ≥10 after live scan) | unit | `bats tests/bats/02-manifest-count.bats` | ❌ W0 | ⬜ pending |
| 2-02-04 | 02 | 2 | MANIFEST-04 | — | `make validate` fails if any manifest path missing on disk | integration | `make validate` (negative test via fixture) | ❌ W0 | ⬜ pending |
| 2-03-01 | 03 | 3 | STATE-01 | T-2-03 | toolkit-install.json atomic write via temp+rename | unit | `bats tests/bats/02-state-atomic.bats` | ❌ W0 | ⬜ pending |
| 2-03-02 | 03 | 3 | STATE-02 | T-2-03 | kill -9 mid-write does not truncate existing file | integration | `bats tests/bats/02-state-kill9.bats` | ❌ W0 | ⬜ pending |
| 2-03-03 | 03 | 3 | STATE-03 | — | schema has install_version, installed_files[], toolkit_version | unit | `bats tests/bats/02-state-schema.bats` | ❌ W0 | ⬜ pending |
| 2-03-04 | 03 | 3 | STATE-04 | T-2-04 | mkdir lock blocks second concurrent run | integration | `bats tests/bats/02-lock-concurrent.bats` | ❌ W0 | ⬜ pending |
| 2-03-05 | 03 | 3 | STATE-05 | T-2-04 | Lock older than 1h reclaimed with warning | integration | `bats tests/bats/02-lock-stale.bats` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/bats/helpers.bash` — shared fixtures (mock $HOME, fake settings.json, fake plugin dirs)
- [ ] `tests/bats/02-detect-sourcing.bats` — detect.sh sourcing contract stubs
- [ ] `tests/bats/02-detect-sp.bats` — SP detection stubs
- [ ] `tests/bats/02-detect-gsd.bats` — GSD detection stubs
- [ ] `tests/bats/02-detect-disabled.bats` — disabled-plugin stubs
- [ ] `tests/bats/02-detect-matrix.bats` — four-combo matrix stubs
- [ ] `tests/bats/02-manifest-conflicts.bats` — manifest conflict annotation stubs
- [ ] `tests/bats/02-manifest-count.bats` — manifest count stubs
- [ ] `tests/bats/02-state-atomic.bats` — atomic write stubs
- [ ] `tests/bats/02-state-kill9.bats` — kill -9 durability stubs
- [ ] `tests/bats/02-state-schema.bats` — schema validation stubs
- [ ] `tests/bats/02-lock-concurrent.bats` — concurrent lock stubs
- [ ] `tests/bats/02-lock-stale.bats` — stale lock reclaim stubs
- [ ] `brew install bats-core` — install if not present (macOS); `apt install bats` (Linux CI)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SP/GSD detection against live user installs | DETECT-02, DETECT-03 | Live plugin state varies per machine; CI fixtures simulate only | Run `source scripts/lib/detect.sh` in a real user shell with SP+GSD installed; assert `$HAS_SP=true $HAS_GSD=true` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
