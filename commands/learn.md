# /learn — Extract Reusable Patterns

## Purpose

Extract and save problem solutions for future sessions.

---

## Usage

```text
/learn [description]
```

**Examples:**

- `/learn` — Analyze session and find patterns
- `/learn prisma connection pooling fix` — Save a specific solution

---

## When to Use

Run `/learn` when:

- ✅ Solved a non-trivial problem
- ✅ Found a workaround for a library/framework
- ✅ Discovered non-obvious behavior
- ✅ User corrected your mistake (remember it!)
- ✅ Debugging took a long time

**DO NOT use for:**

- ❌ Simple typos
- ❌ One-time issues (API was unavailable)
- ❌ Obvious solutions

---

## What to Extract

### 1. Error Resolution Patterns

```markdown
**Problem:** Prisma connection timeout in serverless
**Root Cause:** Connection pool exhaustion
**Solution:** Add `connection_limit=1` to DATABASE_URL
**Reusable:** Yes — applies to all serverless + Prisma
```

### 2. Framework Workarounds

```markdown
**Problem:** Next.js App Router doesn't support X
**Workaround:** Use Y instead
**Version:** Next.js 15.x
**Reusable:** Until fixed in future version
```

### 3. Debugging Techniques

```markdown
**Symptom:** Silent failure in production
**Diagnosis:** Added logging at X, Y, Z points
**Root Cause:** Environment variable not set
**Technique:** Always check env vars first for silent failures
```

### 4. User Corrections

```markdown
**My Mistake:** Used deprecated API
**Correction:** User pointed to new API
**Lesson:** Check docs for deprecation warnings
```

### 5. Mistakes & Learnings (Self-Correcting Pattern)

**Inspired by [loki-mode](https://github.com/asklokesh/loki-mode) RARV cycle.**

When something goes wrong — record the error in "Error → Learning → Prevention" format:

```markdown
**What Failed:** [Specific error]
**Why It Failed:** [Root cause analysis]
**How to Prevent:** [Action to avoid in the future]
**Timestamp:** [When this happened]
```

Use when: 3+ attempts to fix one problem, user correction, tests/build broke after changes.

### Self-Correction Principle

Each mistake → specific **action** to prevent it. Not "I'll be more careful" but "I'll add check X before Y".

---

## Output Format

Create file in `.claude/learned/[pattern-name].md`:

```markdown
# [Descriptive Pattern Name]

**Extracted:** [Date]
**Project:** [Project name or "General"]
**Tags:** [error, workaround, debugging, etc.]

## Problem

[Specific problem description]

## Context

[When this happens — framework, version, conditions]

## Solution

[Solution with code example if needed]

## Why It Works

[Explanation of why this works]

## When to Apply

[Triggers — when to use this pattern]

## Mistakes Log (if applicable)

| What Failed | Why | How to Prevent |
|-------------|-----|----------------|
| [error] | [cause] | [action] |
```

---

## Process

1. **Analyze** — Find solved problems in the session
2. **Identify** — Select the most valuable/reusable
3. **Draft** — Create pattern file
4. **Confirm** — Show to user for confirmation
5. **Save** — Save to `.claude/learned/`

---

## Storage

Primary: `.claude/learned/[pattern-name].md` (committed to git). Optional: Memory Bank and Knowledge Graph for cross-session persistence.
