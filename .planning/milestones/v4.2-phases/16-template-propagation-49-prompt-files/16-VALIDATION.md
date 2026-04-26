---
phase: 16
slug: template-propagation-49-prompt-files
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-26
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + shellcheck + markdownlint + GNU Make |
| **Config file** | `.markdownlint.json` (existing); no new framework |
| **Quick run command** | `bash scripts/tests/test-template-propagation.sh` (Test 20) |
| **Full suite command** | `make check && make test` |
| **Estimated runtime** | ~30 seconds (full suite ~3 minutes including all 19+1 tests) |

Phase 16 has zero pip/npm dependencies — it ships one Bash splice script and one Bash regression test. Existing `markdownlint-cli` (homebrew) and `shellcheck` (homebrew) cover all linting needs. Wave 0 is implicit: the Phase 14 SOTs (`components/audit-fp-recheck.md` + `components/audit-output-format.md`) already exist and pass markdownlint, so the splice script has a stable input contract from day one.

---

## Sampling Rate

- **After every task commit:** Run `markdownlint <changed-file>` and `shellcheck -S warning <changed-script>` as appropriate.
- **After Plan 16-01 commit:** Run `bash scripts/propagate-audit-pipeline-v42.sh --dry-run` (or equivalent no-op flag if implemented) against a scratch dir to confirm script syntax + sentinel logic before applying to live `templates/`.
- **After Plan 16-02 commit:** Run `bash scripts/tests/test-template-propagation.sh` against a scratch fixture (`SPLICE_TEMPLATES_DIR=/tmp/templates-fixture`) to confirm the test runs.
- **After Plan 16-03 commit:** Run `markdownlint 'templates/**/prompts/*.md' --ignore-path .markdownlintignore` to confirm 49 spliced files lint clean. Run `make validate` to confirm existing markers still found.
- **After Plan 16-04 commit:** Run `make check && make test` end-to-end. Confirm Test 20 fires and passes.
- **Before `/gsd-verify-work`:** `make check && make test` exit 0.
- **Max feedback latency:** 60 seconds for per-task quick check; 3 minutes for full suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | TEMPLATE-01, TEMPLATE-02 | T-16-01 (atomic write) | tempfile + mv prevents partial-state files | unit | `shellcheck -S warning scripts/propagate-audit-pipeline-v42.sh && [ -x scripts/propagate-audit-pipeline-v42.sh ]` | ✅ | ⬜ pending |
| 16-01-02 | 01 | 1 | TEMPLATE-01, TEMPLATE-02 | T-16-02 (idempotency) | sentinel-based detection prevents duplicate splices | integration | `SPLICE_TEMPLATES_DIR=/tmp/scratch-templates bash scripts/propagate-audit-pipeline-v42.sh; SPLICE_TEMPLATES_DIR=/tmp/scratch-templates bash scripts/propagate-audit-pipeline-v42.sh; diff -r /tmp/scratch-1 /tmp/scratch-2` | ✅ | ⬜ pending |
| 16-02-01 | 02 | 2 | TEMPLATE-03 | T-16-02 (idempotency regression) | Test 20 fails CI on any future drift | regression | `bash scripts/tests/test-template-propagation.sh` | ✅ | ⬜ pending |
| 16-03-01 | 03 | 2 | TEMPLATE-01, TEMPLATE-02 | T-16-03 (markdownlint compliance) | spliced files remain lint-clean | acceptance | `markdownlint 'templates/**/prompts/*.md' --ignore-path .markdownlintignore && grep -lF 'Council handoff' templates/*/prompts/*.md \| wc -l` | ✅ | ⬜ pending |
| 16-04-01 | 04 | 2 | TEMPLATE-03 | T-16-04 (CI gate enforcement) | missing markers fail build before merge | acceptance | `make validate` | ✅ | ⬜ pending |
| 16-04-02 | 04 | 2 | TEMPLATE-03 | T-16-04 (CI gate enforcement) | quality.yml mirrors local | acceptance | `grep -F 'Council handoff' .github/workflows/quality.yml && grep -F '1. **Read context**' .github/workflows/quality.yml && grep -F '6. **Severity sanity check**' .github/workflows/quality.yml` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. The Phase 14 SOTs (`components/audit-fp-recheck.md`, `components/audit-output-format.md`) are stable inputs to the splice script. The existing markdownlint + shellcheck toolchain covers the lint dimension. The existing `Makefile` `validate` and `test` targets are extension points, not greenfield.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Council Handoff footer reads naturally in each prompt's context | TEMPLATE-01 (4d) | Subjective prose quality | Spot-check 3 random prompts post-splice (e.g., `templates/laravel/prompts/SECURITY_AUDIT.md`, `templates/python/prompts/CODE_REVIEW.md`, `templates/go/prompts/DESIGN_REVIEW.md`); confirm the footer paragraph reads naturally and references audit.md Phase 5 + council.md Modes correctly |

All other phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — existing toolchain suffices)
- [x] No watch-mode flags (Bash + Make + grep are one-shot)
- [x] Feedback latency < 60s for per-task quick checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-26 (inline; gsd-verifier rate-limited)
