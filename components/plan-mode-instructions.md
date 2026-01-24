# Plan Mode Instructions

Include this section in your CLAUDE.md.

---

## 🧠 Plan Before Code (MANDATORY)

### When to Use Plan Mode

- New features (more than trivial changes)
- Refactoring multiple files
- Complex bug fixes
- Database changes
- Architecture decisions

### How to Activate

1. Press `Shift+Tab` twice to enter Plan Mode
2. Or explicitly say "Plan this, don't write code yet"

### Thinking Levels

| Keyword | Use For | Example |
| --------- | --------- | --------- |
| `think` | Simple tasks | "think about how to rename this variable" |
| `think hard` | Medium complexity | "think hard about the best approach for this feature" |
| `think harder` | Complex decisions | "think harder about the architecture for this system" |
| `ultrathink` | Critical decisions | "ultrathink about security implications" |

### Example Workflow

```text
Step 1: Enter Plan Mode
"I need to add OAuth login. Think harder about the implementation.
Don't write any code yet — just create a plan."

Step 2: Review Plan
Claude creates plan in .claude/scratchpad/plan-oauth.md

Step 3: Approve
"The plan looks good. Proceed with Phase 1."

Step 4: Implement
Claude implements Phase 1, commits, then continues.
```

### Plan Output Location

All plans saved to: `.claude/scratchpad/plan-[name].md`

### Rules

- ✅ DO research existing code before planning
- ✅ DO ask clarifying questions
- ✅ DO identify risks and edge cases
- ❌ DON'T write implementation code during planning
- ❌ DON'T skip security considerations
- ❌ DON'T proceed without plan approval

### Scratchpad Usage

For complex multi-step tasks, maintain progress in scratchpad:

```markdown
# Current Task: [Name]

## Progress
- [x] Phase 1: Setup
- [ ] Phase 2: Implementation
- [ ] Phase 3: Testing

## Current Blockers
- None

## Notes
- Using approach X because Y
```
