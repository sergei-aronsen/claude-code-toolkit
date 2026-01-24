# /plan — Create Implementation Plan

## Purpose

Create a detailed implementation plan BEFORE writing any code.

---

## Usage

```text
/plan <feature description>
```text

**Examples:**

- `/plan add OAuth login with Google`
- `/plan refactor payment service to use Stripe SDK v3`
- `/plan migrate database from MySQL to PostgreSQL`

---

## When to Use

| Situation | Use /plan? |
|-----------|-----------|
| New feature | ✅ Yes |
| Multi-file refactoring | ✅ Yes |
| Database changes | ✅ Yes |
| Complex bug fix | ✅ Yes |
| One-line fix | ❌ No |
| Simple typo | ❌ No |

---

## Process

### 1. Understand Requirements

- What is the user asking for?
- What are the acceptance criteria?
- What questions need clarification?

### 2. Research Existing Code

- What files are relevant?
- What patterns does this project use?
- Are there similar implementations to reference?

### 3. Design Solution

- How will this fit into existing architecture?
- What new files/components are needed?
- What existing code needs modification?

### 4. Identify Risks

- What could go wrong?
- What are the edge cases?
- What security considerations exist?

### 5. Break Into Phases

- Small, testable chunks
- Clear dependencies between phases
- Complexity estimates

---

## Output Format

```markdown
# Plan: [Feature Name]

## Summary
[1-2 sentence description]

## Requirements
| # | Requirement | Priority |
|---|-------------|----------|
| 1 | [Requirement] | Must |
| 2 | [Requirement] | Should |

## Questions
- [ ] [Clarifying question]

## Files

### New
| File | Purpose |
|------|---------|
| `path/to/file.php` | [Purpose] |

### Modified
| File | Changes |
|------|---------|
| `existing/file.php` | [Changes] |

## Database Changes
- [ ] New migration?
- [ ] Data migration?

## Phases

### Phase 1: [Name] — Complexity: Low
**Steps:**
1. [ ] Step 1
2. [ ] Step 2

**Tests:**
- [ ] Test 1

### Phase 2: [Name] — Complexity: Medium
...

## Edge Cases
| Case | Handling |
|------|----------|
| [Case] | [Solution] |

## Security Checklist
- [ ] Input validation
- [ ] Authorization
- [ ] Rate limiting

## Risks
| Risk | Mitigation |
|------|------------|
| [Risk] | [Solution] |

## Estimate
- **Complexity:** Medium
- **Time:** 2-4 hours
```text

---

## Save Location

Plans are saved to: `.claude/scratchpad/plan-[feature-slug].md`

---

## Rules

✅ DO:

- Research existing code thoroughly
- Ask clarifying questions if unclear
- Identify ALL affected files
- Consider edge cases and errors
- Estimate complexity realistically

❌ DON'T:

- Write implementation code
- Skip security considerations
- Make assumptions — ask questions
- Rush through planning

---

## Next Steps

After plan is approved:

1. Create feature branch: `git checkout -b feature/[name]`
2. Implement Phase 1
3. Test Phase 1
4. Commit: `git commit -m "feat: [description]"`
5. Repeat for each phase
