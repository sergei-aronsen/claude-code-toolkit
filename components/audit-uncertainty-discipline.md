# Audit Uncertainty Discipline

Canonical UNCERTAINTY DISCIPLINE block for audit prompts. Closes wave-2
findings F-204 (uncertainty discipline drift), F-301 (SECURITY_AUDIT
missing this block), and F-327 (DESIGN_REVIEW phrasing inconsistency).

Audit prompts inject this block (or splice it in via
`scripts/propagate-audit-pipeline-v42.sh`) so that every audit applies
the same discipline when evidence is incomplete.

## UNCERTAINTY DISCIPLINE

If evidence is incomplete: lower confidence, reduce severity, move the
observation into Non-Blocking Observations, and explicitly state the
uncertainty. Do not present assumptions as facts. Do not use weasel
words ("could potentially", "might allow", "in theory") to inflate
report length — either the finding is grounded or it isn't.

When you cannot confirm exploitability / a failure path / a regression
from the embedded code:

- **Lower confidence first.** HIGH → MEDIUM → LOW. State the assumptions
  required for the finding to hold in the finding's "Why it is real"
  field.
- **Lower severity second.** A finding that depends on three unverified
  assumptions does not get to claim CRITICAL. Apply the Severity Ceiling
  Table from `components/audit-severity-anchor.md` against the realistic
  preconditions, not the worst-case imagined scenario.
- **Move to Non-Blocking Observations** if you still can't ground the
  finding. The "Skipped (FP recheck)" or "Non-Blocking Observations"
  section exists for observations the reviewer wants to surface but
  cannot stand behind as a blocker.
- **Drop entirely** if the observation is pure speculation — three
  weak speculations are worse than one verified finding.

## Anti-Patterns

- **Weasel words.** "could potentially", "might allow", "in theory",
  "may be vulnerable to", "could lead to". Either the finding is
  grounded in observable code paths or it is not. If you must hedge,
  the finding belongs in Non-Blocking Observations, not Findings.
- **Padding.** Inflating the report with low-confidence findings to
  appear thorough. Reviewer tooling and downstream Council review
  weight findings by severity × confidence — padding lowers the average
  signal of the entire report.
- **Hidden assumptions.** Stating a finding as fact when it relies on
  unverified runtime behavior, undocumented integrations, hypothetical
  future usage, or external dependencies not present in the diff.
  Surface the assumption explicitly or drop the finding.
- **Confidence inflation.** Marking a finding HIGH-confidence because
  the *category* is well-known (e.g., SQL injection) without grounding
  the *specific instance* in the embedded code. Categories don't make
  findings real; reachable code paths do.
