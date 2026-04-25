# /council — Multi-AI Plan Validation (Supreme Council)

## Purpose

Challenge your implementation plan with Gemini (The Skeptic) and ChatGPT (The Pragmatist) before coding. Not a linter — validates whether the approach is justified.

---

## Usage

```text
/council <feature description>
```

**Examples:**

- `/council add OAuth login with Google`
- `/council refactor payment service to Stripe SDK v3`
- `/council implement role-based permissions`

---

## Modes

The Council orchestrator (`scripts/council/brain.py`) supports two modes. Pick the one that matches your task.

### validate-plan (default)

**Invocation:**

```text
/council <feature description>
```

**Produces:** Per-reviewer assessment (Problem Assessment, Simplicity Check, Concerns) plus a
final consolidated verdict — `PROCEED / SIMPLIFY / RETHINK / SKIP`.

**When to use:** Before implementing any non-trivial feature or architectural change. Run this
BEFORE writing code so the Council's verdict influences scope.

**Prompt:** Built into `brain.py` (`GEMINI_SYSTEM` and `GPT_SYSTEM` constants in
`scripts/council/brain.py`).

**Output:** `.claude/scratchpad/council-report.md`

---

### audit-review

**Invocation:**

```text
/council audit-review --report <path-to-audit-report>
```

**Produces:** Per-finding verdict table with columns `| ID | verdict | confidence | justification |`.
Each row carries one of `REAL / FALSE_POSITIVE / NEEDS_MORE_CONTEXT`. Plus a `## Missed findings`
section listing real issues visible in the embedded code blocks that the auditor did not report.
Plus in-place rewrite of the report's `## Council verdict` slot and the YAML `council_pass:`
frontmatter key (mutates `pending` to `passed`, `failed`, or `disputed`).

**When to use:** After every `/audit` run (Phase 5 of the audit workflow — mandatory).
The audit run is incomplete until Council returns. There is no `--no-council` flag in v4.2.

**Constraints:** The Council MUST NOT reclassify severity (COUNCIL-02). Severity stays with
the auditor. Disagreements between Gemini and ChatGPT are flagged `disputed` with confidence
`min(g_conf, c_conf)` and surfaced to the user without auto-resolution (COUNCIL-06).

**Prompt:** `scripts/council/prompts/audit-review.md`

**Output:** Mutates the input report file in place; prints a collated stdout summary.

---

## When to Use

| Situation | Use /council |
|-----------|--------------|
| New feature (payments, auth) | Yes |
| Security-related changes | Yes |
| Architectural refactoring | Yes |
| Breaking API changes | Yes |
| Plan feels overcomplicated | Yes |
| Simple bug fix | No |
| UI tweaks | No |
| Time-critical hotfix | No |

---

## Prerequisites

Supreme Council must be installed:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh)
```

**Check:**

```bash
test -f ~/.claude/council/brain.py && echo "Installed" || echo "Not installed"
```

---

## Process

### Step 1 — Create Plan

First, formulate a detailed implementation plan for the task.
Use `/plan` or write the plan directly.

### Step 2 — Run Council Review

```bash
python3 ~/.claude/council/brain.py "<detailed implementation plan>"
```

Or if alias is configured:

```bash
brain "<detailed implementation plan>"
```

The orchestrator automatically collects context:

- Project files (Gemini CLI reads natively via `@file`)
- Git diff (uncommitted changes)
- CLAUDE.md project rules

### Step 3 — Read Report

Read `.claude/scratchpad/council-report.md` and analyze the verdict:

- **PROCEED** — plan is justified, start implementation
- **SIMPLIFY** — reduce scope or complexity, then re-run
- **RETHINK** — try a different approach, then re-run
- **SKIP** — don't do this, move on

### Step 4 — Report to User

Before writing code, output:

```text
Council review completed. Verdict: [PROCEED/SIMPLIFY/RETHINK/SKIP].
Key findings: [brief summary].
[Commencing implementation / Adjusting plan / Skipping task].
```

---

## Iron Rules

1. **DO** run `/plan` before `/council`
2. **DO** wait for PROCEED before coding
3. **DO** address concerns in SIMPLIFY/RETHINK verdicts
4. **DO** re-run council after major plan changes
5. **DO NOT** use for simple bug fixes (overhead)
6. **DO NOT** implement non-PROCEED plans without rework
7. **DO NOT** use for time-critical hotfixes (too slow)

---

## Output Format

Report saved to `.claude/scratchpad/council-report.md`:

```text
SUPREME COUNCIL REPORT
============================================================

THE SKEPTIC (Gemini):
  [Problem assessment, simplicity check, do-nothing analysis]
  VERDICT: PROCEED/SIMPLIFY/RETHINK/SKIP

THE PRAGMATIST (ChatGPT):
  [Production readiness, maintenance forecast, alternatives]
  VERDICT: PROCEED/SIMPLIFY/RETHINK/SKIP

------------------------------------------------------------
  Skeptic:    [verdict]
  Pragmatist: [verdict]
  Final:      [most conservative verdict]
------------------------------------------------------------
```

---

## Integration

- Run `/plan` first to create detailed implementation plan
- After implementation, run `/audit security` for post-implementation review
- Use `/verify` before committing to check code quality
- For production deploys after council-approved changes, use `/deploy`

Full guide: `components/supreme-council.md`
