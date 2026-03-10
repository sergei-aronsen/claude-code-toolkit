# /learn — Extract Reusable Patterns

## Purpose

Extract and save problem solutions for future sessions — auto-loaded every session.

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

- Solved a non-trivial problem
- Found a workaround for a library/framework
- Discovered non-obvious behavior
- User corrected your mistake (remember it!)
- Debugging took a long time

**DO NOT use for:**

- Simple typos
- One-time issues (API was unavailable)
- Obvious solutions

---

## What to Extract

### 1. Error Resolution Patterns

```markdown
### [Error Name] — [Date]
**Problem:** Prisma connection timeout in serverless
**Solution:** Add `connection_limit=1` to DATABASE_URL
**Apply when:** Using Prisma with serverless (Lambda, Vercel)
```

### 2. Framework Workarounds

```markdown
### [Workaround Name] — [Date]
**Problem:** Next.js App Router doesn't support X
**Solution:** Use Y instead (works in Next.js 15.x)
**Apply when:** App Router + feature X needed
```

### 3. Debugging Techniques

```markdown
### [Technique Name] — [Date]
**Problem:** Silent failure in production
**Solution:** Check env vars first — most common cause of silent failures
**Apply when:** Service starts but doesn't process requests
```

### 4. User Corrections

```markdown
### [Correction Name] — [Date]
**Problem:** Used deprecated API method
**Solution:** Use newMethod() instead of oldMethod()
**Apply when:** Working with LibraryX v3+
```

### 5. Mistakes and Learnings (Self-Correcting Pattern)

**Inspired by [loki-mode](https://github.com/asklokesh/loki-mode) RARV cycle.**

```markdown
### [Mistake Name] — [Date]
**Problem:** Did X which caused Y failure
**Solution:** Always do Z before X
**Apply when:** Modifying [area] code
```

Use when: 3+ attempts to fix one problem, user correction, tests/build broke after changes.

### Self-Correction Principle

Each mistake becomes a specific **action** to prevent it. Not "I'll be more careful" but "I'll add check X before Y".

---

## Entry Format

Each lesson is compact — 4 lines max:

```markdown
### [Short Title] — [Date]
**Problem:** one-line description
**Solution:** one-line solution
**Apply when:** trigger condition
```

---

## Storage

**Location:** `.claude/rules/lessons-learned.md` (auto-loaded every session via `.claude/rules/` mechanism)

**File structure:**

```yaml
---
description: Lessons learned from debugging, fixes, and corrections
globs:
  - "**/*"
---
# Lessons Learned
<!-- Added by /learn command. Auto-loaded every session. -->
```

Each new lesson is **appended** to this file.

---

## Process

1. **Analyze** — Find solved problems in the session
2. **Identify** — Select the most valuable/reusable
3. **Draft** — Create compact entry (4 lines per lesson)
4. **Confirm** — Show to user for confirmation
5. **Save** — Append to `.claude/rules/lessons-learned.md`

---

## Pruning

When `lessons-learned.md` exceeds ~50 entries:

1. Archive old/outdated lessons to `.claude/docs/lessons-archive.md`
2. Keep only currently relevant lessons in `rules/`
3. Inform user what was archived
