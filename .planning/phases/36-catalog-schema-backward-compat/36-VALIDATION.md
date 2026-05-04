---
phase: 36
slug: catalog-schema-backward-compat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-04
---

# Phase 36 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | hermetic bash + python3 (no test runner — `set -euo pipefail` + assertion counter) |
| **Config file** | none — toolkit ships test scripts directly under `scripts/tests/` |
| **Quick run command** | `python3 scripts/validate-integrations-catalog.py` |
| **Full suite command** | `make check && bash scripts/tests/test-integrations-catalog.sh && bash scripts/tests/test-mcp-selector.sh && bash scripts/tests/test-catalog-scope-fallback.sh` |
| **Estimated runtime** | ~10–15 seconds |

---

## Sampling Rate

- **After every task commit:** `python3 scripts/validate-integrations-catalog.py` (catches schema drift in <1s)
- **After every plan wave:** `make check && bash scripts/tests/test-integrations-catalog.sh && bash scripts/tests/test-mcp-selector.sh`
- **Before `/gsd-verify-work`:** Full suite must be green; baselines must hold (`test-mcp-selector.sh` PASS=21, `test-integrations-catalog.sh` PASS≥10)
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | SCOPE-02 | — | All 20 MCP entries carry `default_scope` with the correct enum value per the locked grid | unit | `python3 scripts/validate-integrations-catalog.py` | ✅ | ⬜ pending |
| 36-01-02 | 01 | 1 | SCOPE-01 | — | Validator rejects missing field and invalid enum on synthetic catalogs | unit | `python3 scripts/validate-integrations-catalog.py` (with `TK_VALIDATOR_CATALOG_PATH=/tmp/synth.json`) | ✅ | ⬜ pending |
| 36-01-03 | 01 | 1 | SCOPE-03 | — | `mcp_catalog_load` silently treats missing `default_scope` as `user`, no stderr emission | unit | `bash scripts/tests/test-catalog-scope-fallback.sh` | ❌ W0 | ⬜ pending |
| 36-02-01 | 02 | 2 | TEST-06 | — | Validator gains the SCOPE-01 assertion (positive + negative cases pass) | unit | `python3 scripts/validate-integrations-catalog.py` against synthetic fixtures | ✅ | ⬜ pending |
| 36-02-02 | 02 | 2 | SCOPE-02 (regression baseline) | — | `test-integrations-catalog.sh` PASS≥10 with new A15/A16/A17 assertions on the locked grid | unit | `bash scripts/tests/test-integrations-catalog.sh` | ✅ | ⬜ pending |
| 36-02-03 | 02 | 2 | SCOPE-03 | — | `test-catalog-scope-fallback.sh` exercises the silent-fallback contract with stderr-empty assertion | unit | `bash scripts/tests/test-catalog-scope-fallback.sh` | ❌ W0 | ⬜ pending |
| 36-02-04 | 02 | 2 | regression | — | Existing baseline `test-mcp-selector.sh` PASS=21 unchanged | unit | `bash scripts/tests/test-mcp-selector.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/test-catalog-scope-fallback.sh` — new sibling test exercising D-09/D-11 silent fallback in `mcp_catalog_load` with stderr-empty assertion
- [ ] `Makefile` — add new `Test NN:` line invoking the new sibling test in the `test:` chain near lines 215–222

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
