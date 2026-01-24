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

**Examples:**

```markdown
**What Failed:** TypeScript compilation error — missing return type
**Why It Failed:** Express route handlers need explicit `: void` in strict mode
**How to Prevent:** Always add `: void` to route handlers: `(req, res): void =>`
**Timestamp:** 2026-01-23T10:30:00Z
```

```markdown
**What Failed:** Tests pass locally but fail in CI
**Why It Failed:** CI uses different Node version (18 vs 20)
**How to Prevent:** Add `.nvmrc` file and check Node version in CI setup
**Timestamp:** 2026-01-23T14:15:00Z
```

**When to use this format:**

- ❌ Made 3+ attempts to fix one problem
- ❌ User pointed out an error in my code
- ❌ Tests/build broke after my changes
- ❌ "Eyeball" solution didn't work

---

## Self-Correction Protocol

**Automatic learning from mistakes (from loki-mode):**

```text
ON_ERROR:
  1. Capture error details (stack trace, context)
  2. Analyze root cause (WHY, not just WHAT)
  3. Write learning in "Mistakes & Learnings" format
  4. Update approach based on learning
  5. Retry with corrected approach
```

**Key principle:** Each mistake should lead to a specific **action** to prevent it in the future.

| ❌ Bad | ✅ Good |
|--------|---------|
| "I'll be more careful" | "I'll add check X before Y" |
| "I'll remember for the future" | "I'll create helper function validateZ()" |
| "It was an edge case" | "I'll add a test for this edge case" |

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

## Storage Locations

### 1. Local file (primary)

```text
.claude/learned/[pattern-name].md
```

Committed to git — available to the whole team.

### 2. Memory Bank (optional)

```text
mcp__memory-bank__memory_bank_write:
  projectName: "[PROJECT]"
  fileName: "learned-[pattern].md"
```

### 3. Knowledge Graph (for relationships)

```text
mcp__memory__create_entities:
  name: "Pattern: [Name]"
  entityType: "LearnedPattern"
  observations: ["solves X", "applies when Y"]
```

---

## Example Session

**User:** `/learn`

**Claude:**

```markdown
Analyzing session...

Found 1 extractable pattern:

## Prisma Serverless Connection Fix

**Problem:** Connection timeout errors in Vercel Edge Functions
**Solution:** Add `?connection_limit=1&pool_timeout=20` to DATABASE_URL

Save to `.claude/learned/prisma-serverless-connection.md`?
```

**User:** yes

**Claude:** Saved! This pattern will help in future serverless + Prisma projects.

---

## Integration with Audits

Learned patterns are automatically considered during:

- `/audit` — checks for known gotchas
- `/verify` — warns about potential problems
- Code review — reminds about patterns

---

## Directory Structure

```text
.claude/
├── learned/                    # Extracted patterns
│   ├── prisma-serverless.md
│   ├── nextjs-cache-gotcha.md
│   └── laravel-queue-retry.md
├── scratchpad/                 # Temporary notes
└── memory/                     # MCP sync
```
