# Requirements: claude-code-toolkit v4.2 — Audit System v2

**Defined:** 2026-04-25
**Core Value:** Make `/audit` reliable across re-runs (no false-positive churn) and trustworthy (every finding cross-checked against verbatim code by a second AI council). The Council's job is to confirm REAL vs FALSE_POSITIVE — never reclassify severity.

## v1 Requirements

Requirements for the v4.2 release. Each maps to exactly one roadmap phase.

### Persistent FP Allowlist

A repo-local list of known false-positive findings that auditors must respect on every re-run.

- [x] **EXC-01**: User can run `/audit-skip <file:line> <rule> <reason>` to add an entry to `.claude/rules/audit-exceptions.md` after confirming the finding is not exploitable. Command appends a structured block (location, rule, reason, date, council status).
- [x] **EXC-02**: User can run `/audit-restore <file:line> <rule>` to remove an entry from `audit-exceptions.md` when an exception turns out to be a real bug. Requires confirmation prompt.
- [x] **EXC-03**: `audit-exceptions.md` carries `globs: ["**/*"]` frontmatter so it auto-loads into every Claude Code session. Schema-aligned with existing `.claude/rules/` files.
- [x] **EXC-04**: `/audit-skip` validates that `<file:line>` exists in the working tree (`git ls-files` + line count) before writing. Refuses duplicates of `path:line + rule` and shows the existing record.
- [ ] **EXC-05**: Installers (`init-claude.sh`, `init-local.sh`, `update-claude.sh`) seed `audit-exceptions.md` only when missing — never overwrite a user-modified file.

### Audit Pipeline FP Recheck + Structured Reports

Force every audit to re-validate findings against the actual code and produce reports the Council can reason from.

- [ ] **AUDIT-01**: `/audit` reads `.claude/rules/audit-exceptions.md` in Phase 0. Findings whose `path:line + rule` matches an existing entry are dropped from the report and counted in a `Skipped (allowlist)` table.
- [ ] **AUDIT-02**: Every audit prompt enforces a 6-step FP-recheck on each candidate finding before it is reported: (1) read file with ±20 lines context, (2) trace data flow from input, (3) check execution context (test/prod/worker/SW), (4) cross-reference exceptions, (5) apply platform-constraint rule, (6) severity sanity check. Findings dropped at this stage land in a `Skipped (FP recheck)` table with one-line reason.
- [ ] **AUDIT-03**: Audit reports include a verbatim ±10 lines code block (with language fence) for every reported finding. Block is copied directly from the source file — Council reasons from the code, not the rule label.
- [ ] **AUDIT-04**: Audit reports are written to `.claude/audits/<type>-<YYYY-MM-DD-HHMM>.md` (directory created if missing). The exact section structure (Summary table, Findings, Skipped tables, Council verdict slot) is fixed and parser-friendly.
- [ ] **AUDIT-05**: Each finding entry contains: ID, severity, rule, location range, claim, verbatim code block, data-flow narrative, "why it is real" reasoning, suggested fix.

### Mandatory Supreme Council Audit-Review

Every `/audit` run terminates in a Council pass that confirms or rejects each finding using the embedded code.

- [ ] **COUNCIL-01**: `/audit` MUST invoke `/council audit-review --report <path>` after writing the report. The audit is incomplete until the Council pass returns. No `--no-council` flag in v4.2.
- [ ] **COUNCIL-02**: Council prompt explicitly forbids severity reclassification. CRITICAL→HIGH, MEDIUM→LOW, etc. are never allowed. Severity disagreements may be logged as comments only.
- [ ] **COUNCIL-03**: Council outputs a per-finding verdict table with `REAL | FALSE_POSITIVE | NEEDS_MORE_CONTEXT`, a confidence score (0.0-1.0), and a one-line justification grounded in the embedded code.
- [ ] **COUNCIL-04**: Council also returns a "Missed findings" section listing any real issues visible in the embedded code that the auditor did not report. Each missed finding includes location, rule, code excerpt, claim, suggested severity (auditor accepts or rejects).
- [ ] **COUNCIL-05**: When the Council marks a finding `FALSE_POSITIVE`, `/audit` displays the verdict and prompts the user to run `/audit-skip` to persist it. The audit never auto-writes exceptions on the user's behalf.
- [ ] **COUNCIL-06**: The Council orchestrator (`scripts/council/brain.py`) runs Gemini and ChatGPT in parallel for `audit-review` mode and collates per-finding verdicts. Disagreements (one says REAL, one says FALSE_POSITIVE) are flagged as `disputed` and surfaced to the user without auto-resolution.

### Template Propagation Across All 7 Frameworks

Every framework's audit prompt set picks up the new behavior consistently.

- [ ] **TEMPLATE-01**: Every `templates/{base,laravel,rails,nextjs,nodejs,python,go}/prompts/{SECURITY_AUDIT,CODE_REVIEW,PERFORMANCE_AUDIT,MYSQL_PERFORMANCE_AUDIT,POSTGRES_PERFORMANCE_AUDIT,DEPLOY_CHECKLIST,DESIGN_REVIEW}.md` file is updated to include: (a) top-of-file callout pointing to `audit-exceptions.md`, (b) the 6-step FP-recheck SELF-CHECK section, (c) the new structured OUTPUT FORMAT, (d) "Council handoff" footer.
- [ ] **TEMPLATE-02**: Existing language in each prompt is preserved — Russian sections stay Russian, English sections stay English. No translation drift introduced.
- [ ] **TEMPLATE-03**: `make validate` (and CI mirror in `.github/workflows/quality.yml`) asserts each updated prompt file contains the literal markers `Council handoff` and the six numbered FP-recheck steps. Missing markers fail the build.

### Distribution + Tooling

Wire the new files through manifest, installers, and CI.

- [ ] **DIST-01**: `manifest.json` registers `templates/base/rules/audit-exceptions.md`, `commands/audit-skip.md`, `commands/audit-restore.md`. Version bumped to `4.2.0`. `updated:` field set to release date.
- [ ] **DIST-02**: `commands/council.md` adds an `audit-review` mode section documenting input format (path to structured audit report), expected Council prompt verbatim, and output schema. `commands/audit.md` updated with the new 6-phase workflow (load context → quick check → deep analysis → FP recheck → structured report → Council pass).
- [ ] **DIST-03**: `CHANGELOG.md` `[4.2.0]` entry covers all v4.2 features with ship date set when the milestone closes.

## Future Requirements (Deferred)

- HARDEN-C-04 — uninstall script (deferred from v4.1 audit; not part of v4.2 scope)
- AUDIT-02/04/06/10/15 — Wave B/C hardening from v4.1 audit (compat matrix, merge strategy, version pinning, collision detection policy, provenance metadata) — separate milestone
- Installable GSD CLI wrapper in toolkit (crosses repo boundary)
- Council `audit-review` integration with cloud Sentry/Linear (auto-create issue per Council-confirmed REAL finding) — only after v4.2 ships and behavior is stable

## Out of Scope

- Reclassifying severity via Council — explicitly forbidden by COUNCIL-02. Severity stays with the auditor.
- Auto-writing exceptions on user's behalf — every FP entry requires explicit `/audit-skip` invocation per COUNCIL-05.
- A `--no-council` flag for `/audit` in v4.2 — Council pass is mandatory; flag may be revisited in v4.3 if pain points emerge.
- Replacing the existing audit prompts wholesale — we extend SELF-CHECK + OUTPUT FORMAT, preserving prompt language and structure.
- Cross-repo automation (Sentry/Linear ticket creation) — deferred to a later milestone.
- Migrating prior audit reports to the new structured format — only new audits use the new format; old reports stay as-is.

## Traceability

| REQ-ID | Phase | Plan |
|--------|-------|------|
| EXC-01 | Phase 13 — Foundation | TBD |
| EXC-02 | Phase 13 — Foundation | TBD |
| EXC-03 | Phase 13 — Foundation | TBD |
| EXC-04 | Phase 13 — Foundation | TBD |
| EXC-05 | Phase 13 — Foundation | TBD |
| AUDIT-01 | Phase 14 — Audit Pipeline | TBD |
| AUDIT-02 | Phase 14 — Audit Pipeline | TBD |
| AUDIT-03 | Phase 14 — Audit Pipeline | TBD |
| AUDIT-04 | Phase 14 — Audit Pipeline | TBD |
| AUDIT-05 | Phase 14 — Audit Pipeline | TBD |
| COUNCIL-01 | Phase 15 — Council Integration | TBD |
| COUNCIL-02 | Phase 15 — Council Integration | TBD |
| COUNCIL-03 | Phase 15 — Council Integration | TBD |
| COUNCIL-04 | Phase 15 — Council Integration | TBD |
| COUNCIL-05 | Phase 15 — Council Integration | TBD |
| COUNCIL-06 | Phase 15 — Council Integration | TBD |
| TEMPLATE-01 | Phase 16 — Template Propagation | TBD |
| TEMPLATE-02 | Phase 16 — Template Propagation | TBD |
| TEMPLATE-03 | Phase 16 — Template Propagation | TBD |
| DIST-01 | Phase 17 — Distribution | TBD |
| DIST-02 | Phase 17 — Distribution | TBD |
| DIST-03 | Phase 17 — Distribution | TBD |

**Coverage:** 22/22 REQ-IDs mapped to exactly one phase. No orphans, no duplicates.

---

*v4.2 roadmap created 2026-04-25 — 5 phases (13–17), 22 REQ-IDs.*
