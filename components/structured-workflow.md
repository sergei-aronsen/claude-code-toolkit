# Structured Workflow — 3-Phase Development

Structured approach to development with explicit phases and restrictions.

**Inspired by:** [RIPER-5 Workflow](https://github.com/tony/claude-code-riper-5)

---

## Problem

Claude often "codes right away" instead of first understanding the task. This leads to:

- Wrong solutions
- Rework
- Context loss

## Solution

Three explicit phases with tool restrictions:

```text
RESEARCH (read-only) → PLAN (scratchpad-only) → EXECUTE (full access)
```

---

## Phase 1: RESEARCH (Read-Only)

**Goal:** Understand existing code and task context.

### Allowed Tools

| Tool | Usage |
|------|-------|
| `Glob` | Find files by pattern |
| `Grep` | Search by content |
| `Read` | Read files |
| `WebFetch` | Library documentation |
| `WebSearch` | Search for solutions |
| `mcp__context7__*` | Library documentation |

### Forbidden Tools

| Tool | Why not allowed |
|------|-----------------|
| `Write` | Don't understand task yet |
| `Edit` | Don't understand task yet |
| `Bash` (except git status/log) | May change state |

### What to Do in This Phase

1. Find all relevant files
2. Understand current architecture
3. Find similar patterns in code
4. Study dependencies
5. Check tests (if any)

### Exit Criteria

When you can answer these questions:

- [ ] What files will the change affect?
- [ ] What patterns are already used?
- [ ] Is there similar code that can be reused?
- [ ] What edge cases need to be considered?

---

## Phase 2: PLAN (Scratchpad-Only)

**Goal:** Create detailed plan before implementation.

### Allowed Tools

| Tool | Usage |
|------|-------|
| All from Phase 1 | Additional research |
| `Write` | **Only** to `.claude/scratchpad/` |
| `Edit` | **Only** to `.claude/scratchpad/` |

### Forbidden Changes

- Project code (src/, app/, lib/, etc.)
- Configuration files
- Tests

### Plan Structure

Create `.claude/scratchpad/current-task.md`:

```markdown
# Task: [Task name]

## Context (from Research phase)

- Affected files: [list]
- Existing patterns: [description]
- Dependencies: [list]

## Approach

[Description of chosen approach and why]

## Implementation Steps

- [ ] Step 1: [Specific action]
  - File: `path/to/file.ts`
  - Change: [what exactly to change]
  - Verify: [how to verify — test command, curl, screenshot]

- [ ] Step 2: [Specific action]
  - File: `path/to/another.ts`
  - Change: [what exactly to change]
  - Verify: [how to verify]

- [ ] Step 3: Write tests
  - File: `path/to/file.test.ts`
  - Cases: [what cases to cover]
  - Verify: `npm test path/to/file.test.ts`

## Edge Cases

- [ ] [Edge case 1]: [how to handle]
- [ ] [Edge case 2]: [how to handle]

## Risks

- [Risk 1]: [mitigation]
```

### Exit Criteria

**Wait for user confirmation!**

```text
Claude: Plan is ready in .claude/scratchpad/current-task.md
        Please review and confirm to start implementation.

User: ok / looks good / go ahead
```

---

## Phase 3: EXECUTE (Full Access)

**Goal:** Implementation according to plan.

### Allowed Tools

All tools without restrictions.

### Execution Rules

1. **Follow the plan** — don't deviate without reason
2. **One step at a time** — mark completed ones
3. **Verify immediately** — after each change (see below)
4. **Commit atomically** — one commit per logical unit

### Verification (MANDATORY!)

> "Give Claude a way to verify its work. This is the single highest-leverage thing you can do." — Anthropic Best Practices

**EVERY implementation step must have explicit verification:**

| Change Type | Verification Method |
|-------------|---------------------|
| Logic/function | Write failing test FIRST, then implement |
| UI component | Screenshot before/after, compare |
| API endpoint | curl/httpie test, check response |
| Bug fix | Reproduce → Fix → Verify not reproducible |
| Refactoring | All existing tests must pass |
| Database | Run migration, verify schema |

**Pattern for each step:**

```text
Step N: [What to do]
- File: path/to/file
- Change: [specific change]
- Verify: [HOW to verify this works]
```

**If verification fails:**

1. Don't proceed to next step
2. Debug current step
3. Fix and re-verify
4. Only then continue

### Track Progress

Update `.claude/scratchpad/current-task.md`:

```markdown
## Implementation Steps

- [x] Step 1: Add validation function
- [x] Step 2: Update API endpoint
- [ ] Step 3: Write tests ← CURRENT
```

### If Plan Needs to Change

If during execution you realize the plan is wrong:

1. **Stop** execution
2. **Explain** what's wrong
3. **Go back** to Phase 2 for plan correction
4. **Wait** for confirmation

---

## Quick Reference

```text
┌─────────────────────────────────────────────────────────┐
│  RESEARCH (read-only)                                   │
│  ─────────────────────                                  │
│  Allowed: Glob, Grep, Read, WebFetch, WebSearch         │
│  Forbidden: Write, Edit, Bash                           │
│                                                         │
│  Exit: Understood context and dependencies              │
├─────────────────────────────────────────────────────────┤
│  PLAN (scratchpad-only)                                 │
│  ─────────────────────                                  │
│  Allowed: Read + Write ONLY to .claude/scratchpad/      │
│  Forbidden: Changes to project code                     │
│                                                         │
│  Exit: Plan ready + user confirmation                   │
├─────────────────────────────────────────────────────────┤
│  EXECUTE (full access)                                  │
│  ─────────────────────                                  │
│  Allowed: All tools                                     │
│  Follow plan, track progress                            │
│                                                         │
│  Exit: All steps completed                              │
└─────────────────────────────────────────────────────────┘
```

---

## When to Use

### Use Structured Workflow for

- New features (more than 50 lines of code)
- Refactoring
- Changes affecting multiple files
- Unfamiliar codebase
- Critical code (auth, payments, security)

### Skip for

- Simple bug fixes (obvious cause)
- Text/copy changes
- Adding comments
- Code formatting

---

## Integration with Plan Mode

Structured Workflow **extends** existing Plan Mode:

```text
Plan Mode (Shift+Tab x 2)
    │
    ├── Phase 1: RESEARCH
    │   └── "think" / "think hard" for analysis
    │
    ├── Phase 2: PLAN
    │   └── "think harder" / "ultrathink" for complex decisions
    │
    └── Phase 3: EXECUTE
        └── After confirmation
```

---

## Add to CLAUDE.md

```markdown
## Structured Workflow

For complex tasks use 3-phase approach:

1. **RESEARCH** (read-only) — understand context
   - Only Glob, Grep, Read, WebFetch
   - No code changes

2. **PLAN** (scratchpad-only) — create plan
   - Write to `.claude/scratchpad/current-task.md`
   - Wait for confirmation

3. **EXECUTE** (full access) — implement
   - Follow the plan
   - Track progress

**When:** new features, refactoring, multiple files, critical code
```

---

## Example Session

```text
User: Add email validation to registration form

Claude: Starting Phase 1: RESEARCH

[Uses Glob to search for form files]
[Uses Read to study current validation]
[Uses Grep to search for validation patterns]

Found:
- Form in `src/components/RegisterForm.tsx`
- Validation via Zod in `src/lib/validation.ts`
- Similar pattern in `src/components/LoginForm.tsx`

Moving to Phase 2: PLAN

[Creates plan in .claude/scratchpad/current-task.md]

Plan includes verification for each step:
- Step 1: Add schema → Verify: unit test
- Step 2: Integrate → Verify: npm run typecheck
- Step 3: Tests → Verify: npm test

Plan is ready. Please review `.claude/scratchpad/current-task.md` and confirm.

User: ok

Claude: Phase 3: EXECUTE

Step 1: Adding email schema to validation.ts...
[Edit file]
Verifying: Running unit test...
✅ Test passes. Step 1 done.

Step 2: Integrating into RegisterForm...
[Edit file]
Verifying: npm run typecheck...
✅ No type errors. Step 2 done.

Step 3: Adding tests...
[Write test file]
Verifying: npm test src/lib/validation.test.ts...
✅ All tests pass. Step 3 done.

All steps completed and verified.
```
