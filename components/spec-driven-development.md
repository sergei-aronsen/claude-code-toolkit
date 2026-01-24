# Spec-Driven Development

Practice of writing specifications before code. Especially effective with Claude Opus 4.5.

## Principle

> **Opus is an architect, not a coder.**
>
> Use Opus for design, Sonnet/Haiku for implementation.

## When to Use

- New feature (not bug fix)
- Refactoring existing module
- Integration with external service
- Architecture change
- Any task where "think first" is more important than "do quickly"

## Workflow

```text
1. "Write a specification for [feature]"
   ↓
2. Claude creates .spec.md in .claude/specs/
   ↓
3. Review and discuss spec
   ↓
4. "Implement according to spec [name]"
   ↓
5. Claude reads spec and implements
```

## Directory Structure

```text
.claude/specs/
├── README.md              # Template and instructions
├── auth-oauth.spec.md     # OAuth integration spec
├── caching-system.spec.md # Caching system spec
└── api-v2.spec.md         # API v2 spec
```

## Specification Template

````markdown
# Spec: [Feature Name]
*Created: [date]*
*Status: Draft | In Review | Approved | Implemented*

## Problem

What problem are we solving? Why is it important?

## Solution

High-level description of solution (2-3 sentences).

## Technical Design

### Components

- [ ] **ComponentA** — what it does, why needed
- [ ] **ComponentB** — what it does, why needed

### Data Flow

```text
1. User action →
2. Frontend validation →
3. API call →
4. Backend processing →
5. Database update →
6. Response to user
```

### Database Changes

| Table | Change | Migration |
|-------|--------|-----------|
| users | Add column `oauth_provider` | Required |

### API Changes

| Endpoint | Method | Change |
|----------|--------|--------|
| /api/auth/oauth | POST | New endpoint |

## Edge Cases

- [ ] What if user already exists?
- [ ] What if OAuth provider is unavailable?
- [ ] What if token expires during request?

## Security Considerations

- [ ] Input validation — what we validate
- [ ] Auth requirements — who has access
- [ ] Rate limiting — is it needed
- [ ] Sensitive data — what we log, what we don't

## Performance Considerations

- [ ] Expected load
- [ ] Is cache needed
- [ ] Impact on existing queries

## Testing Strategy

- [ ] Unit tests: what we test in isolation
- [ ] Integration tests: which scenarios
- [ ] E2E tests: are they needed

## Rollback Plan

How to rollback if something goes wrong?

## Open Questions

- [ ] Question 1 — waiting for answer from...
- [ ] Question 2 — needs research...

## References

- [Link to related docs]
- [Link to similar implementation]
````

## Instructions for CLAUDE.md

Add to your `CLAUDE.md`:

```markdown
## Spec-Driven Development

**Principle:** Before writing code — write specification.

### When to use
- New feature (not bug fix)
- Module refactoring
- Integration with external service

### Commands
- `"Write a specification for [feature]"` → creates .claude/specs/feature.spec.md
- `"Implement according to spec [name]"` → reads spec and implements

### Where to store
`.claude/specs/feature-name.spec.md`
```

## Benefits

1. **Less rework** — problems are found at design stage
2. **Better documentation** — spec remains as document
3. **Easier code review** — reviewer compares code with spec
4. **Savings on Opus** — architecture on Opus, code on Sonnet

## Example Usage with Models

```text
# Phase 1: Opus designs
User: "Think harder. Write a specification for notification system."
Opus: [creates detailed spec with edge cases]

# Phase 2: Sonnet implements
User: [switches to Sonnet]
User: "Implement step 1 from spec notification-system.spec.md"
Sonnet: [writes code according to spec]

# Phase 3: Opus reviews
User: [switches to Opus]
User: "Check implementation for compliance with spec. Find deviations."
Opus: [deep code review]
```

## Anti-patterns

**DO NOT use for:**

- One-line fixes
- Simple bugs with obvious solution
- Tasks like "add console.log"
- Urgent production hotfixes

**Sign that spec is not needed:** If you can describe the solution in one sentence — just do it.
