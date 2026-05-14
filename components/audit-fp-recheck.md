# Audit FP Recheck — 6-Step Procedure

Single source of truth for the false-positive recheck every audit prompt MUST run before reporting a finding. Splice this body verbatim into the SELF-CHECK section of each `templates/*/prompts/*.md` file (Phase 16 fan-out).

---

## Procedure

For every candidate finding, execute these six steps in order BEFORE deciding whether to report or drop it. The step-by-step reasoning is an internal trace — perform it mentally per finding and do NOT emit the trace itself into the report. The only artifacts the report contains are: (a) `## Skipped (FP recheck)` rows for drops, with `dropped_at_step` and a one-line reason; and (b) `## Findings` entries for survivors. Each step has a fail-fast condition: if the finding fails any step, drop it and record the reason in `## Skipped (FP recheck)` (see schema below). Do not skip steps. Do not reorder.

1. **Read context** — Open the source file at `<path>:<line>` and load ±20 lines around the flagged line. Read the full surrounding function or block; do not reason from the rule label alone.
2. **Trace data flow** — Follow input from its origin to the flagged sink. Name each hop (≤ 6 hops). If input never reaches the sink, the finding is a false positive — drop with `dropped_at_step: 2`.
3. **Check execution context** — Identify whether the code runs in test / production / background worker / service worker / build script / CI. Patterns that look problematic in production may be required by the platform in another context (e.g. `eval` inside a build-time codegen script; an `if (!isPaid)` inverted-flag guard inside a unit-test mock).
4. **Cross-reference exceptions** — Re-read `.claude/rules/audit-exceptions.md`. Look for entries on the same file or neighbouring lines that change the failure surface (e.g. an upstream sanitizer or invariant documented in another exception). Match key is byte-exact: same path, same line, same rule, same U+2014 em-dash separator.
5. **Apply platform-constraint rule** — If the pattern is required by the platform or framework (MV3 service-worker MUST NOT use dynamic `importScripts`, OAuth `client_id` MUST be in `manifest.json`, CSP requires inline-style hashes, a transactional boundary the ORM enforces, etc.), the finding is a design trade-off, not a defect. Drop with the constraint named in the reason.
6. **Severity sanity check** — Re-rate severity using the actual failure scenario, not the rule label. A theoretical sink behind 3 unlikely preconditions and no realistic blast radius is not CRITICAL. If you cannot describe a concrete failure path that a user or the business would care about, drop or downgrade.

If a finding survives all six steps, it proceeds to `## Findings` in the structured report.

---

## Skipped (FP recheck) Entry Format

Findings dropped at any step are listed in the report's `## Skipped (FP recheck)` table with these columns in order. The `one_line_reason` MUST be ≤ 100 characters and grounded in concrete tokens from the code — never `looks fine`, `trusted code`, or `out of scope`.

| path:line | rule | dropped_at_step | one_line_reason |
|-----------|------|-----------------|-----------------|
| `src/auth.ts:42` | `SEC-XSS` | 2 | `value flows through escapeHtml() at line 38 before reaching innerHTML` |
| `src/orders.ts:88` | `LOG-INVERTED-COND` | 3 | `!isPaid guard runs inside the test-only mock at fixtures/orders.mock.ts:14; production path uses isPaid` |

`dropped_at_step` MUST be an integer in the range 1-6 matching the step where the finding was dropped.

---

## When a Finding Survives All Six Steps

Promote it to `## Findings` using the entry schema documented in `components/audit-output-format.md` (ID, Severity, Rule, Location, Claim, Code, Data flow, Why it is real, Suggested fix). The `Why it is real` field MUST cite concrete tokens visible in the verbatim code block — that is the artifact the Council reasons from in Phase 15.

---

## Anti-Patterns

These behaviors break the recheck and MUST NOT appear in any audit report:

- Dropping a finding without recording the step number and reason — every drop is auditable.
- Reasoning from the rule label instead of the code — the recheck exists because rule names are pattern-matched, not failure-verified.
- Reusing a generic `one_line_reason` across multiple findings — every reason MUST cite tokens from the specific code block.
- Emitting the internal recheck trace into the report (a `## SELF-CHECK` block per finding inside `## Findings`, a "step 1: …, step 2: …" walkthrough next to each finding, etc.) — the recheck is internal-only. Report ONLY the outcome: a row in `## Skipped (FP recheck)` if dropped, an entry in `## Findings` if survived.
- Skipping Step 4 because `audit-exceptions.md` is absent — when the file is missing, Step 4 is a no-op internally (a `cross-ref skipped: no allowlist file present` acknowledgement) but the step itself MUST be performed.
