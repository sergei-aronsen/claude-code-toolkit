---
phase: 14
slug: audit-pipeline-fp-recheck-structured-reports
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test scripts under `scripts/tests/` (PASS/FAIL counter idiom) |
| **Config file** | `Makefile` (Test 17 entry) |
| **Quick run command** | `bash scripts/tests/test-audit-pipeline.sh` |
| **Full suite command** | `make test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make check` (lint + shellcheck + validate)
- **After every plan wave:** Run `bash scripts/tests/test-audit-pipeline.sh`
- **Before `/gsd-verify-work`:** Full `make test` must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | AUDIT-02, AUDIT-03 | — | New `components/audit-fp-recheck.md` ships verbatim 6-step procedure | content | `grep -E '^[0-9]+\\.' components/audit-fp-recheck.md \| wc -l` returns 6 | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 1 | AUDIT-04, AUDIT-05 | — | New `components/audit-output-format.md` ships report schema with all required fields | content | `grep -F 'Council verdict' components/audit-output-format.md` matches | ❌ W0 | ⬜ pending |
| 14-03-01 | 03 | 2 | AUDIT-01..05 | — | `commands/audit.md` extended with 6-phase workflow contract | content | `grep -F 'Phase 0' commands/audit.md && grep -F '/council audit-review' commands/audit.md` | ✅ (modify) | ⬜ pending |
| 14-04-01 | 04 | 2 | AUDIT-01..05 | — | `scripts/tests/test-audit-pipeline.sh` runs end-to-end, exits 0 on canned fixture | integration | `bash scripts/tests/test-audit-pipeline.sh` exit 0 | ❌ W0 | ⬜ pending |
| 14-04-02 | 04 | 2 | AUDIT-04 | — | Makefile Test 17 wired, `make test` includes audit pipeline test | integration | `make test 2>&1 \| grep -F 'Test 17'` matches | ✅ (modify) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/tests/fixtures/audit/` — canned source files with 1 allowlisted finding (lib/utils.py), 1 FP-recheck-droppable finding (src/legacy.js, build-time-only eval), 1 surviving finding (src/auth.ts, SQL-injection)
- [ ] `scripts/tests/fixtures/audit/allowlist-populated.md` — populated allowlist (flat sibling of allowlist-empty.md, NOT nested under .claude/rules/)
- [ ] `scripts/tests/test-audit-pipeline.sh` — Bash test runner (PASS/FAIL counter)

*Wave 0 = the test fixture + script must exist before Wave 2's verification asserts pass.*

---

## Coverage Dimensions (per RESEARCH.md Validation Architecture)

| Dimension | What's checked | Asserted in test |
|-----------|----------------|------------------|
| **Allowlist match** | Findings in `audit-exceptions.md` land in `## Skipped (allowlist)` | grep `\| <path>:<line> \|` in skipped table |
| **FP recheck drop** | Findings dropped at any of 6 steps land in `## Skipped (FP recheck)` with reason | grep `dropped_at_step` column populated |
| **Surviving finding** | Findings that survive all gates render full schema (D-14) | grep `### Finding F-` heading |
| **Code block fence** | Verbatim ±10 lines with language fence | grep `<!-- File: .* Lines: .* -->` + matching ``` block |
| **Report path schema** | Output at `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` | `ls` matches glob; `date` regex on filename |
| **Council verdict slot** | Literal `_pending — run /council audit-review_` present | grep -F exact string |
| **Frontmatter YAML** | YAML parses; required keys present | `awk` extract + `grep` keys |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end audit on a real project | AUDIT-01..05 | Real project drift not capturable in Bash fixture (different language mix, custom rules) | Run `/audit security` on toolkit repo itself; verify report renders correctly in Claude session |

*All schema-level behaviors have automated verification via the fixture-driven test.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fixture + test script)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter (set by planner once tasks have automated verify)

**Approval:** pending
