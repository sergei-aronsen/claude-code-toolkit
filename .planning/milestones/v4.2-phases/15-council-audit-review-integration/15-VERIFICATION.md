---
phase: 15-council-audit-review-integration
verified: 2026-04-26
verifier: inline (gsd-verifier hit Sonnet rate-limit)
status: PASS
score: 6/6 truths verified
---

# Phase 15 Verification — Council Audit-Review Integration

**Phase goal (ROADMAP.md):** Every audit terminates in a mandatory Council pass that confirms or rejects each finding using the embedded code.

**Verdict:** PASS — all 6 success criteria met; regression test exits 0 (81/81 PASS); make check green; code review warnings (WR-01/WR-02) fixed in commit `3a2bcb6` (post-review).

---

## Per-Requirement Status

| Req | Status | Evidence |
|-----|--------|----------|
| **COUNCIL-01** — `/audit` invokes `/council audit-review --report <path>`; mandatory; no `--no-council` | PASS | `commands/audit.md:165-167` Phase 5 mandates handoff; `commands/audit.md:194` "Council is mandatory: the audit run is reported as incomplete until the Council pass returns"; `grep "no \`--no-council\` flag in v4.2"` returns 1 hit; `commands/council.md` `## Modes` documents the new audit-review mode (`grep "audit-review"` → 19 hits) |
| **COUNCIL-02** — Council prompt forbids severity reclassification | PASS | `scripts/council/prompts/audit-review.md` contains literal `DO NOT reclassify severity` (byte-exact, capitals); regression test Group 1 asserts presence (`grep -F 'DO NOT reclassify severity'`) |
| **COUNCIL-03** — Per-finding verdict table with REAL/FALSE_POSITIVE/NEEDS_MORE_CONTEXT, confidence [0.0-1.0], one-line justification | PASS | Prompt encodes byte-exact column header `\| ID \| verdict \| confidence \| justification \|`; `brain.py:resolve_council_status` parses verdict + confidence + justification per row; regression Group 6 verifies parser end-to-end against `stub-gemini.sh` + `stub-chatgpt.sh` |
| **COUNCIL-04** — "Missed findings" section listing real issues auditor missed | PASS | Prompt requires `## Missed findings` H2 with location/rule/code/claim/suggested-severity columns; `brain.py:extract_block(..., "missed-findings")` parses the bracketed block; regression Group 5 asserts both backends emit the marker pair |
| **COUNCIL-05** — FALSE_POSITIVE → user-prompted /audit-skip; never auto-write | PASS | `commands/audit.md` `### FALSE_POSITIVE Nudge (COUNCIL-05)` section explicitly states "NEVER writes" to audit-exceptions.md; brain.py contains no write to `.claude/rules/audit-exceptions.md` (`grep "audit-exceptions" scripts/council/brain.py` → 0 hits); regression Group 9 asserts post-Council fixture verdict slot mutated but no auto-skip path exercised |
| **COUNCIL-06** — Gemini + ChatGPT in parallel; per-finding disagreements → `disputed` | PASS | `brain.py` uses `concurrent.futures.ThreadPoolExecutor(max_workers=2)` for parallel dispatch; `resolve_council_status` returns `disputed` when verdicts disagree; regression Group 7 (disagreement test): stub-gemini F-003=REAL, stub-chatgpt F-003=FALSE_POSITIVE → fixture's `council_pass:` mutates to `disputed`, F-003 row marked `disputed` with `min(0.9, 0.7)=0.7` confidence |

## Files Verified Present

| File | Origin | Status |
|------|--------|--------|
| `scripts/council/prompts/audit-review.md` | Plan 15-01 | exists, 164 lines, markdownlint clean |
| `scripts/council/brain.py` | Plan 15-04 (modified) | 1150 lines, contains `--mode audit-review`, ThreadPoolExecutor, in-place rewrite, system_prompt parameter (post-WR-01 fix) |
| `commands/audit.md` `## Council Handoff` | Plan 15-03 (modified) | extended with FP nudge + disputed UX subsections |
| `commands/council.md` `## Modes` | Plan 15-05 (modified) | 196 lines (was 144), `## Modes` H2 with validate-plan + audit-review subsections |
| `scripts/tests/test-council-audit-review.sh` | Plan 15-06 | exists, executable, 10 test groups, 81/81 PASS |
| `scripts/tests/fixtures/council/audit-report.md` | Plan 15-02 | exists, 221 lines, 7 frontmatter keys, 3 findings |
| `scripts/tests/fixtures/council/stub-gemini.sh` | Plan 15-02 | exists, executable, deterministic verdict-table output |
| `scripts/tests/fixtures/council/stub-chatgpt.sh` | Plan 15-02 | exists, executable, F-003 disagreement seed |
| `scripts/tests/fixtures/council/stub-malformed.sh` | Plan 15-02 | exists, executable, no `<verdict-table>` markers |
| `Makefile` Test 19 | Plan 15-06 | wired between Test 18 and `All tests passed!`; literal TAB indentation |

## Goal-Backward Analysis

**Could a future PR ship a `--no-council` escape hatch?**
NO — `commands/audit.md` text explicitly forbids it ("There is no `--no-council` flag in v4.2"). A future PR adding the flag would either need to remove that line (caught by code review) or add a flag that the docs forbid (caught by regression test if exercised). Test Group 5 asserts the byte-exact "no `--no-council`" sentence is preserved.

**Could a future PR auto-write to audit-exceptions.md on FALSE_POSITIVE?**
NO — brain.py has zero references to `audit-exceptions.md`; any future PR adding such a write would diff against an empty baseline (greppable). The regression test Group 9 verifies post-Council the allowlist file is untouched.

**Could a future PR drift the verdict-slot byte-exact contract?**
PARTIAL — the regression test Groups 1-3 assert byte-exact contract strings (`DO NOT reclassify severity`, verdict-table column header, `_pending — run /council audit-review_` em-dash U+2014). A drift in any of these would fail Test 19 before merge.

**Could a future PR drift the disputed-detection logic?**
PARTIAL — Group 7 exercises only one disagreement scenario (F-003 REAL vs FALSE_POSITIVE). Other permutations (REAL vs NEEDS_MORE_CONTEXT, NEEDS_MORE_CONTEXT vs FALSE_POSITIVE) are not directly exercised. IN-02 from the code review notes this corner case (agreed NEEDS_MORE_CONTEXT maps to `failed`, not `needs_more_context`) — tracked but not blocking for v4.2.

## Code Review Cross-Reference

`15-REVIEW.md` flagged 2 warnings + 2 info:
- **WR-01:** `ask_chatgpt` hardcoded GPT_SYSTEM, ignoring `AUDIT_REVIEW_GPT_SYSTEM` — **FIXED** in `3a2bcb6`
- **WR-02:** Dead pre-set availability bypass overwritten by future.result() — **FIXED** in `3a2bcb6`
- **IN-01:** Test Groups 6/9 silently require `~/.claude/council/config.json` — accepted, contributors without Council setup get the misleading message but `make test` is not in CI; tracked as future cleanup
- **IN-02:** Agreed `NEEDS_MORE_CONTEXT` maps to `failed` — D-04 underspecified; tracked for v4.3 schema-extension consideration

Post-fix verification: `bash scripts/tests/test-council-audit-review.sh` exits 0 (81 PASS); `make check` exits 0; `make test` runs all 19 tests.

## Final Verdict

**PASS** — Phase 15 goal achieved. The Council audit-review pipeline is operational, tested, and contract-locked. The two real bugs from code review are fixed; remaining info items are out of scope for v4.2 ship.
