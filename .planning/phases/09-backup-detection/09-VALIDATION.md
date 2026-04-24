---
phase: 9
slug: backup-detection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See `09-RESEARCH.md §Validation Architecture` for source test matrix.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash unit tests (primary) + optional bats via Phase 8 `scripts/tests/matrix/lib/helpers.bash` |
| **Config file** | None — each test file is self-contained, runs via `bash path/to/test.sh` |
| **Quick run command** | `bash scripts/tests/test-clean-backups.sh && bash scripts/tests/test-detect-cli.sh && bash scripts/tests/test-detect-skew.sh` |
| **Full suite command** | `make test` (existing target; new test files picked up automatically) |
| **Estimated runtime** | ~8 seconds (3 unit test files, no network, isolated `$HOME` sandboxes) |

---

## Sampling Rate

- **After every task commit:** Run affected unit test file (`test-clean-backups.sh` for BACKUP-*, `test-detect-*.sh` for DETECT-*)
- **After every plan wave:** Run all 3 new unit test files in series
- **Before `/gsd-verify-work`:** Full `make test` + `make check` must be green
- **Max feedback latency:** 8 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 9-01-01 | 01 | 1 | BACKUP-01 | — | N/A | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-01-02 | 01 | 1 | BACKUP-01 | — | `--keep N` preserves N newest by parsed epoch | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-01-03 | 01 | 1 | BACKUP-01 | — | `--dry-run` composes: list only, no delete | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-01-04 | 01 | 1 | BACKUP-01 | V5 | Exit 2 on non-numeric / negative `--keep` | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-01-05 | 01 | 1 | BACKUP-01 | — | Empty-set: print message, exit 0 | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-01-06 | 01 | 1 | BACKUP-01 | V5 | `rm -rf` only on paths matching `.claude-backup-*` / `.claude-backup-pre-migrate-*` name patterns | unit | `bash scripts/tests/test-clean-backups.sh` | ❌ W0 | ⬜ pending |
| 9-02-01 | 02 | 2 | BACKUP-02 | — | Warn emitted when combined count > 10 | unit | `bash scripts/tests/test-backup-threshold.sh` (or folded into clean-backups suite) | ❌ W0 | ⬜ pending |
| 9-02-02 | 02 | 2 | BACKUP-02 | — | Silent when count ≤ 10 (boundary 10) | unit | `bash scripts/tests/test-backup-threshold.sh` | ❌ W0 | ⬜ pending |
| 9-02-03 | 02 | 2 | BACKUP-02 | — | Warning non-fatal: creator script still exits 0 | unit | `bash scripts/tests/test-backup-threshold.sh` | ❌ W0 | ⬜ pending |
| 9-03-01 | 03 | 3 | DETECT-06 | — | CLI present + `.enabled=false` → `HAS_SP=false` (FS override) | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-03-02 | 03 | 3 | DETECT-06 | — | CLI absent → silent skip, FS wins | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-03-03 | 03 | 3 | DETECT-06 | — | CLI non-zero exit → soft-fail, FS wins | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-03-04 | 03 | 3 | DETECT-06 | — | CLI non-JSON → jq fails gracefully → FS wins | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-03-05 | 03 | 3 | DETECT-06 | — | CLI enabled + version populated → `SP_VERSION` sourced from CLI (D-18) | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-03-06 | 03 | 3 | DETECT-06 | — | SP absent from CLI list (empty jq) → FS truth wins (not "disabled") | unit | `bash scripts/tests/test-detect-cli.sh` | ❌ W0 | ⬜ pending |
| 9-04-01 | 04 | 4 | DETECT-07 | — | Stored version differs from detected → one-line ⚠ warning per plugin | unit | `bash scripts/tests/test-detect-skew.sh` | ❌ W0 | ⬜ pending |
| 9-04-02 | 04 | 4 | DETECT-07 | — | Stored version matches → silent | unit | `bash scripts/tests/test-detect-skew.sh` | ❌ W0 | ⬜ pending |
| 9-04-03 | 04 | 4 | DETECT-07 | — | Stored version empty (first-ever state or pre-v4.1) → silent | unit | `bash scripts/tests/test-detect-skew.sh` | ❌ W0 | ⬜ pending |
| 9-04-04 | 04 | 4 | DETECT-07 | — | No `toolkit-install.json` present → silent (jq null fallback) | unit | `bash scripts/tests/test-detect-skew.sh` | ❌ W0 | ⬜ pending |
| 9-04-05 | 04 | 4 | DETECT-07 | — | Non-fatal: `update-claude.sh` continues normal summary flow | unit | `bash scripts/tests/test-detect-skew.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-clean-backups.sh` — covers BACKUP-01 rows 9-01-01..06
- [ ] `scripts/tests/test-backup-threshold.sh` — covers BACKUP-02 rows 9-02-01..03 (may merge into clean-backups at planner's discretion)
- [ ] `scripts/tests/test-detect-cli.sh` — covers DETECT-06 rows 9-03-01..06 (stubs `claude` via `PATH`-prepended mock)
- [ ] `scripts/tests/test-detect-skew.sh` — covers DETECT-07 rows 9-04-01..05 (seeds fake `toolkit-install.json` via `TK_UPDATE_HOME` seam)
- [ ] `scripts/lib/backup.sh` — library under test; exist before tests run (Plan 9.1 creates it)
- [ ] `scripts/lib/install.sh` — gains `warn_version_skew()` helper (Plan 9.4 adds it)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Interactive per-dir `[y/N]` UX under real `curl \| bash` invocation | BACKUP-01 | FIFO simulation covers the read contract but not terminal-line rendering | After merge: `curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh \| bash -s -- --clean-backups` on a machine with ≥2 backup dirs; confirm prompt appears one-per-dir, `n` skips, `y` deletes |
| macOS BSD `du -sh` output formatting in size column | BACKUP-01 | BSD/GNU divergence in human-readable output | Run `--clean-backups --dry-run` on macOS and Linux; size column format should be visually identical (e.g., `1.2M`, `540K`) |
| Live SP/GSD version-skew banner during an actual SP upgrade | DETECT-07 | Requires upstream plugin release cadence | After next SP release: run `update-claude.sh`; confirm one-line `⚠ Base plugin version changed:` warning appears exactly once, BEFORE summary |

---

## Validation Sign-Off

- [ ] All 19 tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (verified: each plan's tasks are covered by the plan's test file)
- [ ] Wave 0 covers all ❌ references (4 new test files + 1 new lib file + 1 extended lib file listed above)
- [ ] No watch-mode flags (plain `bash` invocation, no `--watch`)
- [ ] Feedback latency < 8s
- [ ] `nyquist_compliant: true` set in frontmatter after all tests land

**Approval:** pending
