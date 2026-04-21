---
phase: 6
slug: documentation
status: ratified
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-19
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `make` + markdownlint-cli + shellcheck + custom `validate-manifest.py` + 14 bash test groups in `scripts/tests/` |
| **Config files** | `.markdownlint.json`, `Makefile`, `.github/workflows/quality.yml`, `.pre-commit-config.yaml` |
| **Quick run command** | `make mdlint` (markdownlint only — covers 7 of 8 DOCS-* targets; ~3s) |
| **Full suite command** | `make check` (mdlint + shellcheck + `make validate`; ~5-10s) |
| **Phase gate command** | `make check && make test` (full 14 test-groups + lint + validate; ~60s) |

---

## Sampling Rate

- **After every task commit:** `make mdlint` (fastest — markdown-only; 3s)
- **After every plan wave:** `make check` (lint + validate full suite; 5-10s)
- **Before `/gsd-verify-work`:** `make check` green + `make test` green + visual GitHub-render confirmation for README and CHANGELOG
- **Max feedback latency:** 10 seconds for `make check`, 60 seconds for full `make test`

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | DOCS-03 | N/A | mdlint + manifest version alignment | `npx markdownlint-cli CHANGELOG.md && make validate` | ✅ (modify) | ⬜ pending |
| 06-01-02 | 01 | 1 | DOCS-01 | N/A (docs-only) | mdlint + grep | `npx markdownlint-cli README.md && grep -q 'Standalone install' README.md` | ✅ (modify) | ⬜ pending |
| 06-01-03 | 01 | 1 | DOCS-02 (×7 templates) | N/A | grep + mdlint + CONTEXT-locked install string check | `for f in templates/*/CLAUDE.md; do grep -q '^## Required Base Plugins' "$f" && grep -q 'superpowers@claude-plugins-official' "$f" && grep -q 'raw.githubusercontent.com/gsd-build/get-shit-done' "$f"; done` | ✅ (7 templates) | ⬜ pending |
| 06-01-04 | 01 | 1 | DOCS-04 | N/A | mdlint + mode-name grep | `npx markdownlint-cli docs/INSTALL.md && grep -q complement-full docs/INSTALL.md` | ❌ new | ⬜ pending |
| 06-01-05 | 01 | 1 | DOCS-02 (drift guard) | N/A | Makefile target | `make validate-base-plugins` | ✅ (modify) | ⬜ pending |
| 06-02-01 | 02 | 1 | DOCS-05-asset | Upstream facts verified 2026-04-18 | mdlint + grep | `npx markdownlint-cli components/optional-plugins.md && grep -q 'verified_upstream: 2026-04-18' components/optional-plugins.md && grep -q 'wenyan' components/optional-plugins.md` | ❌ new | ⬜ pending |
| 06-02-02 | 02 | 1 | DOCS-07-asset | N/A | mdlint + grep | `npx markdownlint-cli templates/global/RTK.md && grep -q 'rtk-ai/rtk#1276' templates/global/RTK.md` | ❌ new | ⬜ pending |
| 06-03-01 | 03 | 2 | DOCS-05-register / DOCS-08 (manifest) | N/A | manifest schema validate | `jq -e '.inventory.components \| length == 2' manifest.json && python3 scripts/validate-manifest.py` | ✅ (modify) | ⬜ pending |
| 06-03-02 | 03 | 2 | N/A (plan hygiene) | N/A | VALIDATION.md self-consistency | `grep -q 'nyquist_compliant: true' .planning/phases/06-documentation/06-VALIDATION.md` | ✅ (modify) | ⬜ pending |
| 06-03-03 | 03 | 2 | DOCS-08 (content polish + cross-refs) | N/A | mdlint + grep | `npx markdownlint-cli components/orchestration-pattern.md && grep -q 'orchestration-pattern' components/supreme-council.md components/structured-workflow.md README.md` | ✅ (modify) | ⬜ pending |
| 06-03-04 | 03 | 2 | DOCS-06 | No auto-install; informational stdout only | shellcheck + function-availability + stdout capture | `bash -c 'source scripts/lib/optional-plugins.sh && recommend_optional_plugins 2>&1 \| grep -q "Recommended optional plugins"'` | ✅ (modify) | ⬜ pending |
| 06-03-05 | 03 | 2 | DOCS-07-install | Guard: never clobber existing RTK.md | shellcheck + integration test + Makefile Test 15 | `bash scripts/tests/test-setup-security-rtk.sh && make test` | ❌ new test | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All wave-0 infrastructure already exists: markdownlint + shellcheck + `make validate` + 14 test groups in `scripts/tests/` cover every DOCS-* requirement without new framework installs.

One new test helper recommended by research (NOT a Wave 0 blocker):

- [x] `scripts/tests/test-setup-security-rtk.sh` — validates RTK.md install guard (DOCS-07); authored inside Plan 06-03 Task 5.
- [x] `make validate-base-plugins` target — greps all 7 templates for `## Required Base Plugins` section (Pitfall 10 prevention); added inside Plan 06-01 Task 5.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README prose positions TK as "complement" not "replacement"; both install paths documented; one paragraph per mode | DOCS-01 | Prose quality is subjective | Read rendered README on GitHub; confirm the two install paths are visually distinct and each mode has ≥1 guidance paragraph |
| CHANGELOG 4.0.0 BREAKING CHANGES are complete and accurate | DOCS-03 | Requires cross-referencing all 5 phase SUMMARY files; automated CI cannot judge completeness | Read `[4.0.0]` entry; confirm every item from `06-CONTEXT.md` § CHANGELOG content catalog is present |
| `docs/INSTALL.md` 12-cell install matrix renders correctly on GitHub | DOCS-04 | Markdown table rendering varies across viewers | Open `docs/INSTALL.md` on GitHub; confirm all 12 rows render with preconditions / commands / expected output per cell |
| "Recommended optional plugins" stdout block is readable and aligned (colors + box-drawing unicode) | DOCS-06 | Terminal rendering is platform-sensitive | Run `bash scripts/init-claude.sh` in a real terminal (light + dark theme); confirm the block renders without mojibake and does not interleave with preceding output |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify OR manual-verification row OR Wave 0 dependencies mapped
- [x] Sampling continuity: every task in the Per-Task Verification Map carries an automated command — no 3-task gaps
- [x] Wave 0 covers all MISSING references (existing `make` infrastructure + one net-new test script inside Plan 06-03)
- [x] No watch-mode flags (docs phase — static lint, not reactive)
- [x] Feedback latency < 60s for full phase gate
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved after BLOCKING-3 resolution by 06-03-02 (2026-04-19).
