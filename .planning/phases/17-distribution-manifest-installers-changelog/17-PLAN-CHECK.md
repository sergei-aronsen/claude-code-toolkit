---
phase: 17
checker: gsd-plan-checker
status: CONCERNS
checked: 2026-04-26
plans: [17-01, 17-02, 17-03]
---

# Phase 17 — Plan Check

## Verdict: CONCERNS (1 blocker, 1 warning)

---

## Dimension 1: Requirement Coverage — PASS

| Requirement | Plan(s) | Status |
|-------------|---------|--------|
| DIST-01 | 17-01 (T1: version + rules entry), 17-02 (T1/T2: council prompt install), 17-03 (T3/T5) | Covered |
| DIST-02 | 17-03 (T1/T2: verify-only grep, no edits) | Covered |
| DIST-03 | 17-01 (T2: [4.2.0] CHANGELOG body), 17-03 (T5: date stamp) | Covered |

All three DIST-* requirements map to tasks. DIST-02 is correctly verify-only — 17-03 Tasks 1–2 grep the markers and `STOP` on failure with explicit `git diff` empty check. No re-write risk.

---

## Dimension 2: Task Completeness — PASS

All tasks have `<files>`, `<action>`, `<verify>`, `<done>`. The `checkpoint:decision` gate in 17-03 Task 4 is correctly typed; it has `<decision>`, `<context>`, `<options>`, `<resume-signal>` — structurally complete. No gaps.

---

## Dimension 3: Dependency Correctness — PASS

- 17-01: `depends_on: []`, wave 1
- 17-02: `depends_on: []`, wave 1
- 17-03: `depends_on: [17-01, 17-02]`, wave 2

No cycles. 17-01 and 17-02 touch disjoint files (`manifest.json`/`CHANGELOG.md` vs `scripts/setup-council.sh`/`scripts/init-claude.sh`). Parallel-safe. Wave numbering consistent.

---

## Dimension 4: Key Links Planned — PASS

`must_haves.key_links` in each plan:
- 17-01: `manifest.json version → CHANGELOG [4.2.0]` via `make version-align`. `files.rules → templates/base/rules/audit-exceptions.md` via path entry. Both wired in 17-03 T6.
- 17-02: `setup-council.sh Step 4 → $COUNCIL_DIR/prompts/audit-review.md` and `init-claude.sh setup_council() → $council_dir/prompts/audit-review.md` via curl. Both wired in 17-02 T1/T2 actions.
- 17-03: `manifest version → CHANGELOG heading → init-local.sh --version` via `make version-align`. Tested in T6.

---

## Dimension 5: Scope Sanity — PASS

| Plan | Tasks | Files | Wave |
|------|-------|-------|------|
| 17-01 | 2 | 2 | 1 |
| 17-02 | 3 | 2 | 1 |
| 17-03 | 7 | 4 (reads-only for 3 tasks) | 2 |

17-03 has 7 tasks but 4 of them are read-only verifications (T1, T2, T3, T6, T7) or a checkpoint gate (T4). Only T3 and T5 write files. Effective mutation scope is 2 files × 2 character edits. Within budget despite task count.

---

## Dimension 6: Verification Derivation — PASS

Truths are user-observable: "manifest.json `version` reads `4.2.0`", "CHANGELOG top entry is `[4.2.0]`", "make version-align exits 0". Not implementation-focused. Artifacts and key_links are explicit and connected.

---

## Dimension 7: Context Compliance — PASS

Checked against all 8 CONTEXT.md decisions:

| Decision | Coverage |
|----------|----------|
| D-01 (audit-exceptions.md in manifest) | 17-01 T1 |
| D-02 (version bump to 4.2.0) | 17-01 T1 |
| D-03 (DIST-02 verify-only) | 17-03 T1/T2 |
| D-04 (council prompt install, mtime-aware) | 17-02 T1/T2 |
| D-05 (CHANGELOG structure + coverage) | 17-01 T2 |
| D-06 (version-align gate) | 17-03 T6 |
| D-07 (Test 16, no new tests) | 17-03 T7 |
| D-08 (ship-date placeholder protocol) | 17-01 T1/T2 + 17-03 T5 |

No deferred ideas included. No installer refactor introduced.

---

## BLOCKER — Dimension 7c / DIST-02: `council.md` severity-reclassification grep will fail at runtime

**Plan:** 17-03, Task 2, check 5

**The check:**
```bash
grep -qE 'severity reclassif|never reclassif|severity.*forbid|forbid.*severity' commands/council.md
```

**Actual text in `commands/council.md` line 65:**
```
**Constraints:** The Council MUST NOT reclassify severity (COUNCIL-02). Severity stays with the auditor.
```

The phrase is `MUST NOT reclassify severity` — none of the four regex branches in 17-03 Task 2 check 5 match this:

- `severity reclassif` — word order reversed (actual: `reclassify severity`)
- `never reclassif` — uses "MUST NOT", not "never"
- `severity.*forbid` — no "forbid" anywhere
- `forbid.*severity` — no "forbid" anywhere

**Impact:** If this grep runs as written, it exits 1 and the plan's `<verify>` fails. The plan would halt at 17-03 Task 2 check 5, treating a Phase 15 regression as having occurred when none exists.

**Fix:** Replace check 5 regex with a pattern that matches the actual text. One option:
```bash
grep -qE 'MUST NOT reclassify|reclassify severity|must not reclassif' commands/council.md
```
Or simply:
```bash
grep -qF 'MUST NOT reclassify severity' commands/council.md
```

---

## WARNING — Dimension 2 / 17-02 Task 3: Fixture verify command does not test the actual installer code paths

**Plan:** 17-02, Task 3

**The `<verify>` command:**
```bash
SCRATCH=$(mktemp -d) && mkdir -p "$SCRATCH/.claude/council/prompts" && \
cp scripts/council/prompts/audit-review.md "$SCRATCH/.claude/council/prompts/audit-review.md" && \
cmp -s scripts/council/prompts/audit-review.md "$SCRATCH/.claude/council/prompts/audit-review.md" && \
rm -rf "$SCRATCH" && echo OK
```

This verify just does `mkdir + cp + cmp` — it does not execute the new installer block at all. It does not exercise the mtime-aware logic from T1/T2, does not confirm the `if [ "$tmp" -nt "$dest" ]` branch works, and does not verify idempotency. The action text describes a more thorough fixture procedure, but the `<automated>` verify is a stub that will always pass regardless of whether T1/T2 were implemented correctly.

**Impact:** Low severity — T1/T2 have their own shellcheck + grep verify commands that confirm the install block exists. But the Task 3 verify gives false confidence about end-to-end behavior. If the mtime logic contains a bug, this check won't surface it.

**Fix:** Either expand the `<automated>` block to source and invoke the relevant function, or retitle Task 3 as "Fixture documentation (manual)" and mark `<verify>` as the shellcheck that already passed in T1/T2.

---

## Dimension 8: Nyquist — SKIPPED (no VALIDATION.md for phase 17)

## Dimension 9: Cross-Plan Data Contracts — PASS

17-01 and 17-02 write to disjoint files. 17-03 reads both sets. No shared data pipeline.

## Dimension 10: CLAUDE.md Compliance — PASS

- Shell scripts: `set -euo pipefail` already present in both targets. New blocks follow existing color-code patterns (GREEN/YELLOW/NC). `shellcheck -S warning` required in verify for both T1/T2.
- Markdown lint: CHANGELOG.md edits follow `MD040` (no fenced blocks without language tags), `MD031/MD032` (blank lines around lists and code blocks).
- No forbidden patterns introduced.

## Dimension 11: Research Resolution — SKIPPED (no RESEARCH.md for phase 17)

## Dimension 12: Pattern Compliance — SKIPPED (no PATTERNS.md for phase 17)

---

## Summary

| Check | Result |
|-------|--------|
| Requirement coverage (DIST-01/02/03) | PASS |
| Task completeness | PASS |
| Dependency graph | PASS |
| Key links | PASS |
| Scope | PASS |
| Context compliance (D-01..D-08) | PASS |
| DIST-02 verify-only (no re-write) | PASS |
| CHANGELOG coverage (all 8 features) | PASS |
| Wave assignment / parallel-safe | PASS |
| Scope discipline (no installer refactor, no new tests, placeholder protocol) | PASS |
| **BLOCKER: 17-03 T2 check 5 regex mismatch** | FAIL |
| **WARNING: 17-02 T3 fixture verify is a stub** | WARN |

**Required action before execution:** Fix the regex in 17-03 Task 2 check 5. The warning in 17-02 Task 3 can be addressed at executor discretion but does not block execution.
