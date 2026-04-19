---
phase: 6
slug: documentation
status: draft
nyquist_compliant: false
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
| 06-01-01 | 01 | 1 | DOCS-01 | N/A (docs-only) | mdlint + manual review | `markdownlint README.md` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | DOCS-03 | N/A | mdlint + manifest version alignment | `markdownlint CHANGELOG.md && make validate` | ✅ | ⬜ pending |
| 06-01-03 | 01 | 1 | DOCS-02 (×7 templates) | N/A | grep + mdlint | `for f in templates/*/CLAUDE.md; do grep -q '^## Required Base Plugins' "$f" \|\| echo "MISSING: $f"; done` | ✅ (7 templates) | ⬜ pending |
| 06-01-04 | 01 | 1 | DOCS-04 | N/A | mdlint | `markdownlint docs/INSTALL.md` | ❌ new | ⬜ pending |
| 06-02-01 | 02 | 1 | DOCS-05 | Upstream facts verified 2026-04-18 | mdlint + manual fact-check | `markdownlint components/optional-plugins.md` | ❌ new | ⬜ pending |
| 06-02-02 | 02 | 1 | DOCS-07 | N/A | mdlint | `markdownlint templates/global/RTK.md` | ❌ new | ⬜ pending |
| 06-02-03 | 02 | 1 | DOCS-05 / DOCS-08 (manifest register) | N/A | manifest schema validate | `python3 scripts/validate-manifest.py` | ✅ (modify) | ⬜ pending |
| 06-03-01 | 03 | 2 | DOCS-08 (polish + cross-refs) | N/A | mdlint + grep | `markdownlint components/orchestration-pattern.md && grep -q orchestration-pattern components/supreme-council.md components/structured-workflow.md README.md` | ✅ (modify) | ⬜ pending |
| 06-03-02 | 03 | 2 | DOCS-06 | No auto-install; informational stdout only | shellcheck + stdout inspection | `bash scripts/init-claude.sh --dry-run 2>&1 \| grep -c "Recommended optional plugins"` | ✅ (modify) | ⬜ pending |
| 06-03-03 | 03 | 2 | DOCS-07 (RTK.md install wiring) | Guard: never clobber existing RTK.md | shellcheck + integration test | `bash scripts/tests/test-setup-security-rtk.sh` (net-new) | ❌ new test | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All wave-0 infrastructure already exists: markdownlint + shellcheck + `make validate` + 14 test groups in `scripts/tests/` cover every DOCS-* requirement without new framework installs.

One new test helper recommended by research (NOT a Wave 0 blocker):

- [ ] `scripts/tests/test-setup-security-rtk.sh` — validates RTK.md install guard (DOCS-07); authored inside Plan 06-03 Task 3.
- [ ] Optional `make validate-base-plugins` target — greps all 7 templates for `## Required Base Plugins` section (Pitfall 10 prevention); added inside Plan 06-01 Task 3 if implementer elects.

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
- [ ] `nyquist_compliant: true` set in frontmatter (pending planner confirmation that task IDs in Per-Task map align with the final PLAN.md files)

**Approval:** pending (planner to flip `nyquist_compliant: true` after task IDs are locked in `06-01-PLAN.md`, `06-02-PLAN.md`, `06-03-PLAN.md`).
