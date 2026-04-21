---
phase: 4
slug: update-flow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash scripts in `scripts/tests/*.sh`, orchestrated by `Makefile:test` target |
| **Config file** | none — tests self-contained; each sources `scripts/lib/install.sh` or `scripts/lib/state.sh` directly |
| **Quick run command** | `bash scripts/tests/test-update-drift.sh` (single file, <5s) |
| **Full suite command** | `make test` (Tests 1-11 after Phase 4 lands Tests 9/10/11) |
| **Estimated runtime** | ~30 seconds full suite, <5 seconds per file |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/tests/test-update-<area>.sh` for whichever area the task touches
- **After every plan wave:** Run `make test` (all Tests 1-11)
- **Before `/gsd-verify-work`:** `make check` must pass green (shellcheck + markdownlint + test + validate)
- **Max feedback latency:** 30 seconds

Tests 1-8 from Phases 1-3 MUST stay green throughout Phase 4 — any regression blocks the wave.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-00-01 | 00 | 0 | W0 | — | Test harness scaffolding compiles | scaffold | `bash scripts/tests/test-update-drift.sh` | ❌ W0 | ⬜ pending |
| 04-00-02 | 00 | 0 | W0 | — | Seeded fixtures present | scaffold | `ls scripts/tests/fixtures/manifest-update-v2.json scripts/tests/fixtures/toolkit-install-seeded.json` | ❌ W0 | ⬜ pending |
| 04-01-01 | 01 | 1 | UPDATE-01 (D-50) | V14 config | State load + v3.x synthesis writes synthesized toolkit-install.json | integration | `bash scripts/tests/test-update-drift.sh` (scenario v3x-upgrade) | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | UPDATE-01 (D-51) | V5 input | Mode-drift prompt `[y/N]` via `< /dev/tty`, curl\|bash fails closed | integration | `bash scripts/tests/test-update-drift.sh` (scenarios drift-accept, drift-decline, drift-curlbash) | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | UPDATE-01 (D-52) | V11 logic | Mode-switch in-place transaction: remove old-skip ∩ installed, install new-required | integration | `bash scripts/tests/test-update-drift.sh` (scenario mode-switch-transaction-integrity) | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | UPDATE-02 (D-53) | — | update-claude.sh iterates manifest.files.* + skip-set; hand-lists 125-179 deleted | structural | `grep -c 'for file in agents/\\|for file in prompts/\\|for skill in' scripts/update-claude.sh` → 0 + `make validate` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | UPDATE-03 (D-54) | V5 input | New-file detection via jq set-diff; skip-set filter applied before install | integration | `bash scripts/tests/test-update-diff.sh` (scenarios new-file-auto-install, new-file-filtered-by-skip-set) | ❌ W0 | ⬜ pending |
| 04-02-03 | 02 | 2 | UPDATE-04 (D-55) | V5 input | Removed-file detection + batch `[y/N]` prompt; decline logs removal_declined | integration | `bash scripts/tests/test-update-diff.sh` (scenarios removed-file-accept, removed-file-decline) | ❌ W0 | ⬜ pending |
| 04-02-04 | 02 | 2 | D-56 hash | V6 crypto | SHA-256 mismatch → `[y/N/d]` prompt; d prints `diff -u` and re-prompts | integration | `bash scripts/tests/test-update-diff.sh` (scenarios modified-file-overwrite, modified-file-keep, modified-file-diff) | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 3 | UPDATE-05 (D-57) | V14 config (symlink) | Backup dir = `~/.claude-backup-<unix-ts>-<pid>/`; mkdir-first to prevent symlink attack | integration | `bash scripts/tests/test-update-summary.sh` (scenarios backup-path-format, same-second-concurrent-runs) | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 3 | UPDATE-06 (D-58) | — | Summary prints 4 groups with ANSI auto-disable when `[ -t 1 ]` is false | integration | `bash scripts/tests/test-update-summary.sh` (scenario full-run-summary-all-four-groups) | ❌ W0 | ⬜ pending |
| 04-03-03 | 03 | 3 | D-59 no-op | — | 5-condition no-op exits 0 with one-line message, no backup created | integration | `bash scripts/tests/test-update-summary.sh` (scenarios no-op-exits-0-no-backup, noop-via-version-match) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Each Plan is one wave. Task IDs follow `{phase}-{plan}-{task}` convention consistent with Phase 3.

---

## Wave 0 Requirements

Wave 0 (scaffolding) MUST land before Plan 01 production code. Mirrors Phase 3 Plan 3 TDD cadence (test-first, then helpers, then consumer refactor).

- [ ] `scripts/tests/test-update-drift.sh` — covers D-50 (v3.x synthesis), D-51 (mode-drift prompt), D-52 (mode-switch transaction). Scenarios: v3x-upgrade-path, mode-drift-accept, mode-drift-decline, mode-drift-curlbash, mode-switch-transaction-integrity.
- [ ] `scripts/tests/test-update-diff.sh` — covers D-53 (manifest iteration), D-54 (new-file), D-55 (removed-file with `[y/N]`), D-56 (modified-file with `[y/N/d]`). Scenarios: new-file-auto-install, new-file-filtered-by-skip-set, removed-file-accept, removed-file-decline, modified-file-overwrite, modified-file-keep, modified-file-diff.
- [ ] `scripts/tests/test-update-summary.sh` — covers D-57 (backup path + collision-safety), D-58 (summary grouping + ANSI), D-59 (no-op). Scenarios: no-op-exits-0-no-backup, full-run-summary-all-four-groups, backup-path-format-matches-regex, same-second-concurrent-runs-no-collision, noop-via-version-match.
- [ ] `scripts/tests/fixtures/manifest-update-v2.json` — "manifest AFTER update" fixture with 2 added + 1 removed + 1 hash-bumped entries relative to the seeded state.
- [ ] `scripts/tests/fixtures/toolkit-install-seeded.json` — pre-seeded `toolkit-install.json` matching `manifest-v2.json` with known `sha256` values (SHA-256 of known content so tests are deterministic).
- [ ] `scripts/tests/fixtures/update-fixture.sh` (optional helper) — emits the two fixture files + deterministic test content, callable from each test file.
- [ ] `Makefile` — add Tests 9/10/11 invocations between Test 8 and the final `All tests passed!` line (`scripts/tests/test-update-drift.sh`, `test-update-diff.sh`, `test-update-summary.sh`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Remote curl\|bash update run against real GitHub raw | UPDATE-01, UPDATE-03, UPDATE-06 | Needs real network + real `raw.githubusercontent.com` content; harness runs against local working tree | Run `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh)` on a machine with an existing `~/.claude/` install; verify summary prints INSTALLED/UPDATED/SKIPPED/REMOVED groups and exits 0 |
| Mode-drift prompt under real tty keystroke | UPDATE-01 (D-51) | `read -r < /dev/tty` cannot be scripted without pty emulator; harness uses heredoc workaround that does not simulate keypress | On machine with TK installed as standalone, install SP after, then run `bash scripts/update-claude.sh` — type `y` to accept switch, confirm in-place transition completes |
| Modified-file `d=diff` prompt interactive re-prompt | D-56 | Requires interactive loop: prompt → d → show diff → re-prompt | Locally modify `~/.claude/commands/plan.md`, run `bash scripts/update-claude.sh`, press `d` at the modified-file prompt, verify diff renders, verify re-prompt appears, press `n` to keep local |
| Visual inspection of ANSI colors in summary groups | D-58 | Terminal-specific rendering; `[ -t 1 ]` auto-disable path asserted by test, but positive-colors path is not | From a real terminal run `bash scripts/update-claude.sh` against an install with pending changes; verify INSTALLED=green, UPDATED=cyan, SKIPPED=yellow, REMOVED=red |
| rollback-update.sh compatibility with new backup-path | D-57 | `commands/rollback-update.md` ships as a TK command; needs verification it recognizes new `<unix-ts>-<pid>` format | Run an update that creates a backup, then run `/rollback-update`; verify it lists the new backup dir and can restore from it |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies — ✓ mapped above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify — ✓ every production task has a scenario
- [ ] Wave 0 covers all MISSING references — ✓ 7 scaffolding items listed
- [ ] No watch-mode flags — ✓ tests run once-through; `make test` sequential
- [ ] Feedback latency < 30s — ✓ full suite ~30s, single file <5s
- [ ] `nyquist_compliant: true` set in frontmatter — pending Wave 0 completion

**Approval:** pending
