# /council — Multi-AI Code Review (Supreme Council)

## Purpose

Get pre-implementation review from Gemini (Architect) and ChatGPT (Critic) before coding high-stakes features.

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

## When to Use

| Situation | Use /council |
|-----------|--------------|
| New feature (payments, auth) | Yes |
| Security-related changes | Yes |
| Architectural refactoring | Yes |
| Breaking API changes | Yes |
| Simple bug fix | No |
| UI tweaks | No |
| Time-critical hotfix | No |

---

## Prerequisites

Supreme Council must be installed:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh | bash
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

### Step 3 — Read Report

Read `.claude/scratchpad/council-report.md` and analyze:

- **APPROVED** — proceed with implementation
- **REJECTED** — fix issues listed in the report, then re-run

### Step 4 — Report to User

Before writing code, output:

```text
Council review completed. Status: [APPROVED/REJECTED].
Key findings: [brief summary].
[Commencing implementation / Awaiting plan revision].
```

---

## Iron Rules

1. **DO** run `/plan` before `/council`
2. **DO** wait for APPROVED before coding
3. **DO** address concerns in REJECTED reports
4. **DO** re-run council after major plan changes
5. **DO NOT** use for simple bug fixes (overhead)
6. **DO NOT** implement REJECTED plans without rework
7. **DO NOT** use for time-critical hotfixes (too slow)

---

## Output Format

Report saved to `.claude/scratchpad/council-report.md`:

```text
SUPREME COUNCIL FINAL REPORT
=============================

ARCHITECT (Gemini):
  [Architectural review, SOLID/DRY violations, risks]
  VERDICT: APPROVED/REJECTED

CRITIC (ChatGPT):
  [Security review, edge cases, alternative approaches]
  VERDICT: APPROVED/REJECTED

STATUS: PLAN APPROVED / PLAN REJECTED
```

---

## Integration

- Run `/plan` first to create detailed implementation plan
- After implementation, run `/audit security` for post-implementation review
- Use `/verify` before committing to check code quality
- For production deploys after council-approved changes, use `/deploy`

Full guide: `components/supreme-council.md`
