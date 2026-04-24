# Phase 10: Upstream GSD Issues — Research

**Researched:** 2026-04-24
**Domain:** GitHub issue filing — `gsd-build/get-shit-done` upstream repo
**Confidence:** HIGH

## Summary

Phase 10 produces exactly three GitHub issues filed in `gsd-build/get-shit-done` — no code changes in
this repo. All three bugs were discovered during v4.0 execution and documented in the retrospective.
This phase is pure documentation/issue-filing work.

The research confirmed two of the three bugs are definitively reproducible in the currently installed
GSD v1.36.0 on this machine. All three have no exact duplicate in the upstream issue tracker, though
related issues exist for adjacent problems. Issue #2236 (audit-open) was filed and closed as
`COMPLETED` but the fix PR #2239 was closed without merging — the bug persists in v1.36.0.

**Primary recommendation:** File all three as structured `bug_report.yml` issues. Match the format
of high-quality closed issues (#2005, #2236, #1572) which include GSD version, runtime, OS, Node.js
version, exact reproduction steps, error output, and a root-cause analysis block.

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPSTREAM-01 | File issue for `gsd-tools audit-open` `ReferenceError: output is not defined` at `gsd-tools.cjs:786` | Reproduced live; stack trace captured; source located at lines 779–789; root cause confirmed: bare `output()` vs `core.output()` |
| UPSTREAM-02 | File issue for `milestone complete` emitting noise into MILESTONES.md accomplishments | Root cause traced to `extractOneLinerFromBody()` in `core.cjs:1384`; reproduced with test node script returning `"One-liner:"` instead of prose; v4.0 artifacts are the repro |
| UPSTREAM-03 | File issue for missing auto-sync of ROADMAP.md plan checkboxes on plan-complete | Observed during v4.0 (retrospective: 5 manual calls needed); current workflow has partial mitigations but the structural hook path remains incomplete; related closed issues confirm this is a known pattern |

</phase_requirements>

---

## 1. Upstream Repo Baseline

### Issue Templates Available

[VERIFIED: gh api] The repo has a structured YAML template set at `.github/ISSUE_TEMPLATE/`:

| Template | File | When to Use |
|----------|------|-------------|
| Bug Report | `bug_report.yml` | Crashes, wrong output, broken behavior — use for all three issues |
| Enhancement | `enhancement.yml` | Improves existing feature |
| Feature Request | `feature_request.yml` | New command/workflow/concept |
| Docs Issue | `docs_issue.yml` | Documentation only |
| Chore | `chore.yml` | Maintenance |

All three issues (UPSTREAM-01/02/03) are bugs. Use `bug_report.yml` template for all three.

### Required Bug Report Fields

The `bug_report.yml` template requires these fields (validated, `required: true`):

- **GSD Version** — `1.36.0` (from `~/.claude/get-shit-done/VERSION`)
- **Runtime** — `Claude Code`
- **Operating System** — `macOS`
- **Node.js Version** — `v25.9.0`
- **Shell** — `/bin/zsh`
- **Installation Method** — one of the template dropdown options
- **What happened** — description of the bug
- **What did you expect** — expected behavior
- **Steps to reproduce** — numbered steps

Optional but strongly valued by maintainers (seen in accepted issues):

- Error output/logs
- GSD Configuration (`.planning/config.json`)
- GSD State (`.planning/STATE.md` snippet)
- Root cause analysis
- Suggested fix

### Labels to Apply

[VERIFIED: gh label list] The repo has structured labels. Recommended for all three issues:

- `bug` — primary type label (auto-applied by `bug_report.yml`)
- `needs-triage` — auto-applied by template
- `runtime: claude-code` — these occurred in Claude Code
- `area: workflow` — all three affect workflow behavior

Priority labels (apply after filing):

- UPSTREAM-01: `priority: high` — crashes on invocation, blocks milestone close audit
- UPSTREAM-02: `priority: medium` — data quality issue, corrupts MILESTONES.md artifacts
- UPSTREAM-03: `priority: medium` — UX annoyance, requires manual workaround

### Repo Conventions (from well-accepted closed issues)

Based on #2005, #2236, #1572:

- Title format: `verb(area): description` — e.g., `fix(cli): audit-open command crashes with ReferenceError`
- Body: structured markdown with `## Summary`, `## Reproduction`, `## Expected Behavior`, `## Root Cause`, `## Suggested Fix`
- Root cause analysis with code line references earns faster maintainer response
- Suggested fix as a code diff (not just prose) is expected for CLI-layer bugs
- English only — the maintainer enforces this (see #2236 thread)

---

## 2. Existing Issues Scan — Duplicate Check

### UPSTREAM-01 (audit-open ReferenceError)

**Issue #2236** — `fix(cli): audit-open command crashes with ReferenceError: output is not defined`

- Status: CLOSED (`stateReason: COMPLETED`) on 2026-04-15
- Fix PR #2239 was submitted but **closed without merging** (`mergedAt: null`)
- The bug **persists in v1.36.0** (reproduced live — see stack trace in Section 3)
- Latest npm release is `1.38.3`; unclear if fixed there

**Decision:** Issue #2236 is closed but unresolved in `v1.36.0`. File a new issue referencing
#2236, noting the fix was not merged and the bug regressed/persists. Link to PR #2239.
Do NOT reopen #2236 (closed issues in this repo are not reopened per convention).

### UPSTREAM-02 (milestone accomplishment noise)

Searched with multiple queries:
- "milestone complete accomplishment one-liner" → no match
- "extractOneLinerFromBody frontmatter label" → no match
- "MILESTONES.md accomplishment noise" → no match
- "milestone-complete summary extract" → no match for this specific bug

**No existing issue found.** [VERIFIED: gh issue list --state all]

### UPSTREAM-03 (ROADMAP checkbox auto-sync)

Related closed issues:
- **#536** — `execute-phase never calls phase complete — ROADMAP checkboxes stay unchecked` — CLOSED 2026-02-15
- **#1572** — `phase complete does not update plan checkboxes in ROADMAP.md` — CLOSED 2026-04-03
- **#1446** — `cmdPhaseComplete doesn't update Plans column or plan checkboxes` — CLOSED
- **#2005** — `phase complete silently skips roadmap updates... when wrapped in <details>` — CLOSED

All four are closed. The retrospective documents that the issue persisted in v4.0 (April 2026) for
a different reason than the closed issues: `execute-plan.md` skipped `update-plan-progress` in
parallel mode (`parallelization: true` but `use_worktrees: false`), leaving the per-plan checkbox
step to the phase-level orchestrator — which also did not reliably fire.

**Decision:** File a new issue specifically about the v1.36.0 regression in execute-phase's
`update_roadmap` step. Reference #536 and #1572 as prior art, document the parallel-mode
interaction, and include the manual workaround.

---

## 3. UPSTREAM-01 Evidence — audit-open ReferenceError

### Summary

`gsd-tools.cjs audit-open` crashes immediately with `ReferenceError: output is not defined`.
The command was previously filed as #2236 but the fix PR was not merged and the bug persists
in the installed v1.36.0.

### Reproduction

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" audit-open
```

Any project directory; the crash happens before any I/O.

### Confirmed Stack Trace (live, v1.36.0)

```
/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:786
        output(formatAuditReport(result), raw);
        ^

ReferenceError: output is not defined
    at runCommand (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:786:9)
    at main (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:388:11)
    at Object.<anonymous> (/Users/REDACTED/.claude/get-shit-done/bin/gsd-tools.cjs:1158:1)
    at Module._compile (node:internal/modules/cjs/loader:1829:14)
    ...
```

### Root Cause (confirmed in source)

**File:** `bin/gsd-tools.cjs`, lines 779–789:

```javascript
// Lines 779–789 — audit-open case handler
case 'audit-open': {
  const { auditOpenArtifacts, formatAuditReport } = require('./lib/audit.cjs');
  const includeRaw = args.includes('--json');
  const result = auditOpenArtifacts(cwd);
  if (includeRaw) {
    output(JSON.stringify(result, null, 2), raw);  // BUG: bare `output`
  } else {
    output(formatAuditReport(result), raw);         // BUG: bare `output`
  }
  break;
}
```

**The problem:** The module-level `core` object is loaded at line 168:
`const core = require('./lib/core.cjs');`

No destructuring of `output` from `core` occurs in scope. All other callers in the same file
use `core.output()` (lines 1045, 1056, 1059, 1062, etc.). The `audit-open` handler uses bare
`output()`, which is undefined in this scope.

**Suggested fix (2-line diff):**

```diff
- output(JSON.stringify(result, null, 2), raw);
+ core.output(JSON.stringify(result, null, 2), raw);
  } else {
- output(formatAuditReport(result), raw);
+ core.output(formatAuditReport(result), raw);
```

### Impact

Blocks `complete-milestone.md` workflow Step 1 (`pre_close_artifact_audit`), which calls
`audit-open` before archiving a milestone. The crash is unhandled — it surfaces to the agent
as an uncaught exception, and the milestone close workflow falls back to manual skip.

---

## 4. UPSTREAM-02 Evidence — milestone complete Accomplishment Noise

### Summary

`gsd-tools milestone complete <version>` writes an entry to `MILESTONES.md` with a
`**Key accomplishments:**` bullet list. The one-liner extraction from SUMMARY.md files
returns the label text `One-liner:` instead of the actual prose description.

### Root Cause (confirmed in source)

**File 1:** `bin/lib/milestone.cjs`, lines 131–136 — extraction logic:

```javascript
for (const s of summaries) {
  const content = fs.readFileSync(path.join(phasesDir, dir, s), 'utf-8');
  const fm = extractFrontmatter(content);
  const oneLiner = fm['one-liner'] || extractOneLinerFromBody(content);
  if (oneLiner) accomplishments.push(oneLiner);
}
```

**File 2:** `bin/lib/core.cjs`, lines 1384–1391 — `extractOneLinerFromBody`:

```javascript
function extractOneLinerFromBody(content) {
  if (!content) return null;
  const body = content.replace(/^---\n[\s\S]*?\n---\n*/, '');
  const match = body.match(/^#[^\n]*\n+\*\*([^*]+)\*\*/m);
  return match ? match[1].trim() : null;
}
```

**The mismatch:** The v4.0 SUMMARY template produced bodies like:

```markdown
# Phase 2 Plan 01: Foundation Summary

**One-liner:** Filesystem-based superpowers/GSD detection library via sourced shell script...
```

The regex `\*\*([^*]+)\*\*` matches the shortest `**...**` span. In `**One-liner:** text`,
the first `**...**` pair wraps only the label `One-liner:` — because the colon, space, and
text that follow are OUTSIDE the closing `**`. The regex captures `One-liner:` and discards
the actual content.

**Reproduced programmatically:**

```javascript
// Test against real v4.0 SUMMARY file
extractOneLinerFromBody(content)
// Returns: "One-liner:"   ← the label, not the content
```

### What MILESTONES.md actually received at v4.0 close

The accomplishments list in `MILESTONES.md` section `## v4.0 Complement Mode` was written
manually (the CLI output was discarded after the crash/noise was discovered). The v4.0
MILESTONES.md `**Key accomplishments:**` block represents what it SHOULD look like —
it was hand-authored after the CLI produced garbage.

### What the CLI would produce (noise example)

For any SUMMARY using the `**One-liner:** prose` template pattern:

```markdown
**Key accomplishments:**
- One-liner:
- One-liner:
- One-liner:
```

For SUMMARYs with no bold line after the H1 (e.g., early v4.0 phases with different
structure): nothing is extracted at all.

### Affected v4.0 SUMMARY files

All 29 v4.0 SUMMARY files used `**One-liner:** prose` format. None had `one-liner:` in
YAML frontmatter. The `fm['one-liner']` path always misses; `extractOneLinerFromBody` always
returns the label.

### Suggested Fix

Option A — strip the label prefix in `extractOneLinerFromBody`:

```javascript
function extractOneLinerFromBody(content) {
  if (!content) return null;
  const body = content.replace(/^---\n[\s\S]*?\n---\n*/, '');
  // Match "**Label:** prose" or "**prose**" patterns
  const match = body.match(/^#[^\n]*\n+\*\*(?:[A-Za-z -]+:\s*)?([^*]+)\*\*/m);
  return match ? match[1].trim() : null;
}
```

Option B — match the full bold line including text outside `**`:

```javascript
const match = body.match(/^#[^\n]*\n+\*\*[^*]+\*\*[^\n]*/m);
// Then strip the "**Label:** " prefix from the result
```

Option C — add `one-liner:` as a YAML frontmatter field in the SUMMARY template (already
the preferred path per template docs; make extraction more robust by also documenting the
fallback regex pattern expected by `extractOneLinerFromBody`).

---

## 5. UPSTREAM-03 Evidence — ROADMAP Auto-Sync on Plan Completion

### Summary

After completing all plans in a phase via `/gsd-execute-phase N --auto`, plan-level checkboxes
in `ROADMAP.md` (`- [ ] 09-01-PLAN.md`) remain unchecked until the user manually runs:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress N
```

The v4.0 execution required 5 such manual calls after phases 2–5 completed.

### Workflow Execution Path (v1.36.0)

The `execute-phase.md` workflow has two checkpoints where plan checkboxes SHOULD be updated:

**Checkpoint A (per-plan, sequential mode):** `execute-plan.md` line ~418:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE}"
```

This is guarded: `# Skip in parallel mode — orchestrator handles ROADMAP.md centrally`.
With `parallelization: true` and `use_worktrees: false`, the per-plan agent is in
"parallel scheduling mode" but NOT in worktree mode — the guard condition is ambiguous
about whether this step runs.

**Checkpoint B (post-wave orchestrator):** `execute-phase.md` line ~738:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE_NUMBER}" "${plan_id}" "complete"
```

This runs only when `TEST_EXIT=0` and only in the worktree merge post-step.
With `use_worktrees: false`, this block is explicitly skipped.

**Checkpoint C (phase complete):** `execute-phase.md` line ~1353:

```bash
COMPLETION=$(node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" phase complete "${PHASE_NUMBER}")
```

`phase complete` in `phase.cjs` lines 843–854 includes a safety-net checkbox loop.
However, this only fires at the very end of phase execution — and only if the phase is
not already partially broken.

### The Gap

With `parallelization: true, use_worktrees: false` (the config in this project):

- Checkpoint A fires ambiguously — the agent may or may not call `update-plan-progress`
  depending on how it interprets the "skip in parallel mode" guard
- Checkpoint B is explicitly skipped (`use_worktrees: false`)
- Checkpoint C fires reliably at phase end

This means per-plan ROADMAP updates depend entirely on Checkpoint A's agent interpretation.
When the LLM agent skips it (as happened in v4.0 phases 2–5), no checkbox update occurs
until the final `phase complete` call — which works only if `phase complete` is reached.
If a phase ends with partial completion or the agent stops before `phase complete`, no
checkboxes are ever updated.

### Workaround Observed in v4.0

Manual invocation after each phase:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress 2
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress 3
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress 4
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress 5
```

(5 calls total per retrospective)

### Related Closed Issues

- **#536** (2026-02-15) — `execute-phase never calls phase complete` — CLOSED. Different root
  cause: no `phase complete` call at all in older workflow versions.
- **#1572** (2026-04-03) — `phase complete does not update plan checkboxes` — CLOSED. Fixed
  by adding the safety-net loop in `phase.cjs:843`. Does not address the ambiguous Checkpoint A.
- **#2005** (2026-04-22) — `phase complete silently skips roadmap updates... in <details>` —
  CLOSED. Different root cause: `<details>` layout parsing.

### Suggested Fix

Make `execute-plan.md`'s `update-plan-progress` call unconditional for `use_worktrees: false`
mode. Currently the guard reads `# Skip in parallel mode` — but "parallel scheduling"
(`parallelization: true`) and "worktree isolation" (`use_worktrees: true`) are orthogonal.
The ROADMAP update should run whenever `use_worktrees: false`, regardless of `parallelization`.

```markdown
# In execute-plan.md, replace the conditional guard:

# Skip only in worktree isolation mode — orchestrator handles ROADMAP.md centrally
if [ "${GSD_WORKTREE_MODE:-false}" != "true" ]; then
  node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" roadmap update-plan-progress "${PHASE}"
fi
```

---

## 6. Issue Body Template

All three issues should use the `bug_report.yml` template structure, which produces this
rendered markdown body. The planner should use this skeleton for each issue:

```markdown
### GSD Version
1.36.0

### Runtime
Claude Code

### Operating System
macOS

### Node.js Version
v25.9.0

### Shell
/bin/zsh

### Installation Method
[appropriate option from dropdown]

### What happened?
[bug description — be specific about which command]

### What did you expect?
[expected behavior]

### Steps to reproduce
1. [step]
2. [step]
3. [step]

### Error output / logs
```
[paste error or wrong output]
```

### GSD Configuration
```json
[relevant config.json excerpt]
```

### Root cause analysis
[file:line, code snippet, explanation]

### Suggested fix
[diff or prose]
```

The `gh issue create` command does NOT support YAML templates directly from CLI — it creates
a free-form issue. The planner should use `--body` with the above structure, referencing the
template fields. The template is enforced by the GitHub web UI only.

---

## 7. Cross-Reference Strategy

**Success Criterion #4** requires zero code changes in this repo; only `.planning/` notes
documenting the filed issue URLs.

**Recommended artifact:** `.planning/phases/10-upstream-gsd-issues/SUMMARY.md` (the standard
GSD plan completion artifact). After all three issues are filed, the SUMMARY should contain:

```markdown
| Bug | Issue URL | Status |
|-----|-----------|--------|
| UPSTREAM-01: audit-open ReferenceError | https://github.com/gsd-build/get-shit-done/issues/XXXX | Filed |
| UPSTREAM-02: milestone accomplishment noise | https://github.com/gsd-build/get-shit-done/issues/XXXX | Filed |
| UPSTREAM-03: ROADMAP auto-sync | https://github.com/gsd-build/get-shit-done/issues/XXXX | Filed |
```

The SUMMARY.md is the cross-reference document. No separate `SUMMARY.md` file is needed beyond
the standard plan completion artifact.

---

## 8. Validation Architecture

This phase has no code to test. `nyquist_validation` does not apply.

**Validation = 3 GitHub issue URLs captured in artifacts.**

Phase gate: `/gsd-verify-work 10` should check:

1. Three GitHub issue URLs exist in the phase artifact (SUMMARY.md or dedicated notes file)
2. Each URL is reachable (`gh issue view <url>` returns `state: OPEN`)
3. No files outside `.planning/` were modified
4. `make check` still passes (no regressions from doc edits)

---

## 9. Planner Implications

### Recommended Plan Structure

**One plan with three sequential tasks** (not three separate plans).

Rationale:
- All three issues require the same environment (gh CLI, GSD version, this repo context)
- Filing order: UPSTREAM-01 first (simplest), then UPSTREAM-02 (needs artifact context),
  then UPSTREAM-03 (needs workflow knowledge)
- Combined SUMMARY.md is cleaner than three separate SUMMARYs for a "file 3 issues" phase
- Risk of plan-checker overhead exceeds value for a 3-task filing phase

If the user prefers separation (e.g., expects issues to be filed on different days), three
plans are also valid. But one plan is more efficient.

### Pre-filing Checklist (planner should include as verification steps)

For each issue:
1. Run the duplicate search query to confirm no newer duplicate since this research
2. Verify GSD version in the issue body matches actual installed version
3. Redact usernames from stack traces (replace `/Users/REDACTED/` per repo privacy notice)
4. Confirm `gh issue create` succeeded and URL is captured

### gh CLI Command Pattern

```bash
gh issue create \
  --repo gsd-build/get-shit-done \
  --title "fix(cli): audit-open crashes with ReferenceError: output is not defined in v1.36.0 (regression from #2236)" \
  --label "bug,runtime: claude-code,area: workflow" \
  --body "$(cat <<'EOF'
[issue body here]
EOF
)"
```

Labels must be comma-separated exact matches. Use only labels confirmed in Section 1.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | audit-open bug persists in latest npm release (1.38.3) | Section 3 | If 1.38.3 fixed it, UPSTREAM-01 should note the installed version is 1.36.0 and request a patch release |
| A2 | No exact duplicate of UPSTREAM-02 exists in the upstream tracker | Section 2 | Could create a duplicate; mitigated by running fresh search before filing |
| A3 | The UPSTREAM-03 gap affects `parallelization: true, use_worktrees: false` config specifically | Section 5 | The ambiguous guard may behave differently in other config combos |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gh CLI | Filing issues | Yes | (system gh) | None — required |
| Node.js | Reproducing UPSTREAM-01/02 | Yes | v25.9.0 | — |
| GSD v1.36.0 | Stack trace evidence | Yes | 1.36.0 | Use archived trace |
| gsd-build/get-shit-done repo access | Issue filing | Yes | public repo | — |

---

## Sources

### Primary (HIGH confidence)

- `~/.claude/get-shit-done/bin/gsd-tools.cjs` — direct source inspection, lines 779–789
- `~/.claude/get-shit-done/bin/lib/milestone.cjs` — direct source inspection, lines 130–136
- `~/.claude/get-shit-done/bin/lib/core.cjs` — direct source inspection, lines 1384–1391
- `~/.claude/get-shit-done/bin/lib/roadmap.cjs` — direct source inspection, lines 257–354
- `~/.claude/get-shit-done/workflows/execute-phase.md` — direct workflow inspection, lines 738, 1353
- `gh api repos/gsd-build/get-shit-done/contents/.github/ISSUE_TEMPLATE/` — repo template list
- `gh label list --repo gsd-build/get-shit-done` — complete label set
- Node.js execution of `gsd-tools.cjs audit-open` — live crash reproduction
- Node.js test of `extractOneLinerFromBody` against v4.0 SUMMARY — returns `"One-liner:"`
- `.planning/RETROSPECTIVE.md` — documents v4.0 workarounds for all three bugs

### Secondary (MEDIUM confidence)

- `gh issue list` searches — duplicate checks for all three issues
- `gh issue view 2236, 536, 1572, 2005` — prior art and related issue review
- `gh pr view 2239` — confirmed fix PR not merged (`mergedAt: null`)

---

## Metadata

**Confidence breakdown:**

- Bug reproduction (UPSTREAM-01): HIGH — live crash confirmed, source located
- Bug root cause (UPSTREAM-02): HIGH — test-confirmed, source traced
- Bug gap analysis (UPSTREAM-03): MEDIUM — workflow analysis, not live-reproduced (would require clean v4.0 execution)
- Duplicate check: HIGH — multiple search queries, no matches for UPSTREAM-02/03
- Issue filing process: HIGH — template structure confirmed, labels confirmed

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (issue tracker state changes; re-check duplicates before filing)
