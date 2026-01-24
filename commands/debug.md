# /debug — Systematic Debugging

## Purpose

Systematic debugging process: find root cause BEFORE attempting to fix.

---

## Usage

```text
/debug <problem description>
```

**Examples:**

- `/debug tests failing after refactoring`
- `/debug 500 error in production`
- `/debug form not submitting`

---

## Iron Law

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If Phase 1 is not completed — cannot propose fixes.

---

## The Four Phases

### Phase 1: Root Cause Investigation

**BEFORE any fix:**

1. **Read Error Messages carefully**
   - Don't skip errors and warnings
   - Read stack traces completely
   - Write down file paths, line numbers, error codes

2. **Reproduce consistently**
   - Can you trigger the bug reliably?
   - What are the exact steps?
   - If not reproducible → gather more data, don't guess

3. **Check recent changes**
   - What changed? `git diff`, recent commits
   - New dependencies, config changes
   - Environment differences

4. **Trace Data Flow**
   - Where is the bad value coming from?
   - What called the function with the bad value?
   - Continue up until you find the source

**For Multi-Component systems:**

```bash
# Layer 1: Entry point
echo "=== Input data: ==="
echo "$INPUT"

# Layer 2: Processing
echo "=== After processing: ==="
echo "$PROCESSED"

# Layer 3: Output
echo "=== Final output: ==="
echo "$OUTPUT"
```

---

### Phase 2: Pattern Analysis

1. **Find working examples**
   - Is there similar code that works?
   - What's different?

2. **Compare with reference**
   - If implementing a pattern — read reference COMPLETELY
   - Don't skim — read every line

3. **List differences**
   - What's different between working and broken?
   - Don't assume "this can't affect it"

---

### Phase 3: Hypothesis & Testing

1. **Form hypothesis**
   - "I think X is the root cause because Y"
   - Write it down
   - Be specific

2. **Test minimally**
   - ONE change at a time
   - Don't fix multiple things at once

3. **Verify**
   - Worked? → Phase 4
   - Didn't work? → New hypothesis
   - DON'T add more fixes on top

---

### Phase 4: Implementation

1. **Create failing test**
   - Minimal bug reproduction
   - REQUIRED before fix

2. **One fix**
   - Fix the root cause
   - ONE change
   - No "while I'm here" improvements

3. **Verify**
   - Does the test pass?
   - Are other tests still passing?

4. **Rule of three fixes**

```text
If 3+ fixes didn't work — STOP!
This is not a bug. This is an architecture problem.
```

**Signs of architectural problem:**

- Each fix opens a new problem elsewhere
- Fix requires "massive refactoring"
- Fix creates new symptoms

**Action:** Discuss with a human whether architecture refactoring is needed.

---

## Red Flags — STOP and return to Phase 1

If you're thinking:

- "Quick fix now, I'll figure it out later"
- "Let me just try changing X"
- "I'll add several changes, run tests"
- "It's probably X, let me fix it"
- "Don't quite understand, but it might work"
- "One more try" (when 2+ already failed)

**ALL of this means: STOP. Return to Phase 1.**

---

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Simple bug, no process needed" | Simple bugs also have root cause |
| "Urgent, no time for process" | Systematic approach is FASTER than guessing |
| "Try first, figure out later" | First fix sets the pattern. Do it right from the start |
| "I'll write test after fix" | Untested fixes don't hold |
| "Multiple fixes at once saves time" | Can't tell what worked. Creates new bugs |
| "I see the problem, let me fix it" | Seeing symptom ≠ understanding root cause |
| "One more try" (after 2+ fails) | 3+ fails = architectural problem |

---

## Output Format

```markdown
# Debug Report: [Problem]

## Phase 1: Investigation

**Error Message:**
[Full error text]

**Reproduction Steps:**
1. ...
2. ...

**Recent Changes:**
- [commit/change that might be related]

**Data Flow Trace:**
[Source] → [Transform] → [Where it breaks]

## Phase 2: Pattern Analysis

**Working Example:**
[Similar code that works]

**Differences:**
- [Difference 1]
- [Difference 2]

## Phase 3: Hypothesis

**Hypothesis:** [X is root cause because Y]

**Test:** [Minimal change to verify]

**Result:** [Pass/Fail]

## Phase 4: Fix

**Root Cause:** [What was actually wrong]

**Fix:** [What was changed]

**Test Added:** [test name]

**Verification:** All tests pass ✅
```

---

## Quick Reference

| Phase | Actions | Success Criteria |
|-------|---------|------------------|
| **1. Root Cause** | Read errors, reproduce, trace | Understand WHAT and WHY |
| **2. Pattern** | Find working example, compare | Found differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug fixed, tests green |

---

## Integration

- After fix, use `/verify` for verification
- Use `/learn` to save the solution
- If you found a security issue — run `/audit security`
