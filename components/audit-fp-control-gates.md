# Audit FP-Control Gates

Canonical three-gate FALSE-POSITIVE CONTROL structure for audit prompts.
Closes wave-2 findings F-260 (CODE_REVIEW missing FP-control gates),
F-324 (DESIGN_REVIEW missing FP-control gates), and F-363 (PERFORMANCE
audits missing FP-control gates).

Pairs with `components/audit-fp-recheck.md` (the 6-step procedure that
Gate 2 calls into). This component defines the **outer wrapper** —
three sequential gates that every candidate finding must pass before
being promoted to `## Findings`.

## FALSE-POSITIVE CONTROL

Every candidate finding passes through three gates in this order. A
finding that fails any gate is dropped (record the drop step and reason
in `## Skipped (FP recheck)`); a finding that survives all three is
promoted to `## Findings`.

```text
1. Adversarial self-review  → intent check  (per finding, mandatory for HIGH / CRITICAL)
2. 6-step FP recheck        → procedure check  (per finding, every severity — see SELF-CHECK below)
3. Calibration              → severity + confidence sanity, anti-padding (per report)
```

The order is fixed: adversarial review first (cheap, kills bad
hypotheses), procedure recheck second (expensive, requires reading
±20 lines and tracing data flow), calibration third (applies to the
surviving set as a whole).

### Gate 1 — Adversarial self-review (intent check)

For every HIGH or CRITICAL finding, attempt to disprove it before
reporting. Search explicitly for:

- Upstream sanitization / validation that defangs the input
- Framework guarantees that block the path (escaping, ORM bindings,
  CSRF middleware, transaction isolation)
- Impossible execution paths (dead code, environment-gated branches,
  feature flags off in production, code never imported / called)
- Privilege constraints that prevent the required actor class from
  reaching the sink
- Environmental limitations (the function exists but is never wired
  into a route, command, scheduled job, or webhook)

A finding survives Gate 1 only if the failure mode (security:
exploitability; performance: realistic latency hit; code-review:
reachable regression) remains plausible after adversarial review.
Document in your scratchpad which counter-evidence you considered and
why it failed.

### Gate 2 — 6-step FP recheck (procedure check)

The 6-step procedure is defined in `## SELF-CHECK` of the audit prompt
(propagated from `components/audit-fp-recheck.md`). Each step has a
fail-fast condition; drops are recorded in `## Skipped (FP recheck)`
with the step number and a one-line reason citing concrete tokens from
the source.

### Gate 3 — Calibration (severity + confidence sanity, anti-padding)

After Gates 1 and 2, apply these rules to the surviving set. The
calibration discipline itself is canonicalized in
`components/audit-uncertainty-discipline.md` — apply that SOT in full
here; the rules below are pure cross-references that point its outputs
at the per-audit rubric anchors.

- **Confidence + severity calibration.** Apply UNCERTAINTY DISCIPLINE
  per `components/audit-uncertainty-discipline.md` (lower confidence,
  lower severity, then move to Non-Blocking Observations or drop). Then
  re-rate severity using the Severity Ceiling Table in
  `components/audit-severity-anchor.md` against the realistic
  preconditions. For SECURITY: cross-multiply with
  `## DATA CLASSIFICATION`. For PERFORMANCE: cross-reference
  `## SEVERITY THRESHOLDS`. For CODE_REVIEW: cross-reference
  `## SEVERITY AND CONFIDENCE`.
- **No padding.** Five weak speculative MEDIUMs are worse than one
  verified CRITICAL with a working failure scenario. The weasel-word
  ban (`could potentially`, `might allow`, `in theory`) and the
  hidden-assumptions ban are defined in
  `components/audit-uncertainty-discipline.md` `## Anti-Patterns`. Do
  not restate them inline — apply the SOT.

## Audit-Specific Customization

This three-gate structure is fixed. Audit-specific customization happens
inside the gates, not by adding / removing gates:

- **SECURITY_AUDIT** — Gate 1 specializes "failure mode" as
  "exploitability"; Gate 3 cross-multiplies with `## DATA CLASSIFICATION`.
- **PERFORMANCE_AUDIT** / **MYSQL_PERFORMANCE_AUDIT** /
  **POSTGRES_PERFORMANCE_AUDIT** — Gate 1 specializes "failure mode" as
  "realistic latency / resource hit under documented load profile";
  Gate 3 cross-references `## SEVERITY THRESHOLDS`.
- **CODE_REVIEW** — Gate 1 specializes "failure mode" as "reachable
  regression / correctness defect"; Gate 3 cross-references
  `## SEVERITY AND CONFIDENCE`.
- **DESIGN_REVIEW** — Gate 1 specializes "failure mode" as "user-visible
  UX defect grounded in screenshot or interaction trace"; Gate 3 maps
  the design label (Blocker / High / Medium / Nitpick) to the canonical
  rubric per `## Issue Triage Matrix`.

Adding a fourth gate, skipping a gate, or reordering them constitutes
a structural change and requires a new audit-specific rubric — not a
local tweak.
