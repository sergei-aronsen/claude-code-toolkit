---
name: Systematic Debugging
description: Systematic debugging and root cause analysis. Triggers on debug/bug/crash/exception/stack-trace keywords.
---

# Systematic Debugging Skill

> Debugging methodology: understand the cause, don't guess the fix.

## Iron Law

**DON'T FIX WITHOUT UNDERSTANDING THE CAUSE.**

Trial and error ("what if I try X?") is the path to tech debt and context overflow.

---

## 4 Debugging Phases

### Phase 1: Root Cause Investigation

**Goal:** Understand WHAT is happening and WHY.

```text
1. Read the error carefully (entire stack trace)
2. Reproduce consistently (when exactly does it fail?)
3. Check recent changes (git log, git diff)
4. Trace data flow (where does data come from, where does it go)
```

**Questions:**

- When did this last work?
- What changed since then?
- Does it always fail or only under certain conditions?

**Tools:**

```bash
# Laravel
tail -100 storage/logs/laravel.log
php artisan tinker  # check data

# Git
git log --oneline -10
git diff HEAD~3 -- path/to/file.php

# Database
SELECT * FROM table WHERE id = X;
```

### Phase 2: Pattern Analysis

**Goal:** Find a working example for comparison.

```text
1. Find similar code that WORKS
2. Compare: what's different?
3. Check documentation/tests
```

**Examples:**

- Bug in new Job -> look at existing working Job
- Error in API endpoint -> compare with similar endpoint
- Issue with Vue component -> find analogous working component

### Phase 3: Hypothesis

**Goal:** Formulate a testable hypothesis.

**Format:**

```text
"I think the problem is [X] because [Y].
If I'm right, then [Z] should confirm this."
```

**Examples:**

- "I think the problem is that `$user` = null because auth middleware is not applied. If I add dd($user), I'll see null."
- "I think timeout is due to N+1 query because 1000 records. If I add eager loading, time will drop."

**Rule:** One hypothesis at a time. Don't change multiple things simultaneously.

### Phase 4: Fix & Verify

**Goal:** Minimal fix + verification.

```text
1. Make ONE minimal fix
2. Verify the bug is fixed
3. Verify nothing else broke (quality gates)
4. If it didn't help -> return to Phase 1
```

**Quality Gates (mandatory):**

```bash
# PHP/Laravel
php artisan test --filter=RelatedTest
./vendor/bin/phpstan analyse  # if available

# Frontend
npm run build
npm run type-check  # if TypeScript
```

---

## 3-Fix Rule

> If 3 fix attempts didn't work - this is NOT a bug, it's an architectural problem.

**After 3 failed attempts:**

1. STOP
2. Tell user: "This looks like an architectural problem, not a simple bug"
3. Suggest: refactoring / rethinking approach / code review

**Signs of architectural problem:**

- Need to change 3+ files for one fix
- Fix breaks something else
- Same error returns in different place

---

## Anti-patterns

**DON'T:**

- "I'll try adding try-catch, maybe it'll help"
- "I'll comment out this line and see"
- "I'll add sleep(), maybe race condition"
- "I'll restart the service, maybe it'll work"

**DO:**

- "I see NullPointerException on line 45. I'll check where $user comes from."
- "Query timeout. I'll look at EXPLAIN and add index."
- "Race condition. I'll add lock with specific key."

---

## Checklist Before Fix

- [ ] I understand the root cause (can explain in one sentence)
- [ ] I found a working example for comparison
- [ ] My hypothesis is testable
- [ ] Fix is minimal (not touching extra things)
- [ ] I know how to verify the fix works

---

## Workflow Integration

### When receiving bug report

```text
1. DON'T jump into code immediately
2. Read description + reproduce
3. Go through 4 phases
4. Make fix + quality gates
5. Commit with root cause description
```

### Commit format for bugfixes

```text
fix: brief description

Root cause: why this was happening
Fix: what exactly was fixed
```

**Example:**

```text
fix: screenshot job timeout on large sites

Root cause: scroll_to_bottom without limit on pages with infinite scroll
Fix: added max_scroll_count=10 in FirecrawlScreenshotService
```

---

## When to Use This Skill

- Production bug
- Test fails and unclear why
- "Worked yesterday, doesn't work today"
- Error that can't be reproduced
- Fix broke something else
