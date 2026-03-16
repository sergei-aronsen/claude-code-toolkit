# /design — Architecture Design for Complex Features

## Purpose

Create an architectural design BEFORE planning implementation.
Use for complex features that touch multiple layers, services, or require new abstractions.

---

## Usage

```text
/design <feature description>
```

**Examples:**

- `/design add OAuth login with Google and Apple`
- `/design real-time notifications via WebSocket`
- `/design multi-tenant data isolation`

---

## When to Use

| Situation | Use /design? |
|-----------|-------------|
| New feature touching 3+ layers | Yes |
| New external integration | Yes |
| New data model or domain concept | Yes |
| Architecture decision with trade-offs | Yes |
| Simple CRUD endpoint | No, use /plan |
| Bug fix | No, use /fix or /debug |
| One-file change | No |

**Rule of thumb:** if you need to explain the approach to a colleague before coding, you need `/design`.

---

## Process

### 1. Research (Facts Only)

Investigate the codebase. Record ONLY facts:

- File paths, function signatures, data flow
- Existing patterns and conventions
- Current state of relevant modules

**Do NOT include opinions or suggestions. Facts with references, zero advice.**

Save to: `.claude/scratchpad/design-[name]-research.md`

### 2. Architecture Design

Based on research, design the solution:

**Components:**

- What new components/modules are needed?
- How do they fit into existing architecture?
- What are the boundaries and responsibilities?

**Data Flow:**

- How does data move through the system?
- What transformations happen at each step?
- What are the inputs/outputs of each component?

**Contracts:**

- API endpoints (method, path, request/response)
- Internal interfaces between components
- Database schema changes

### 3. Decisions and Risks

**Decisions (with reasoning):**

- What approach was chosen and WHY
- What alternatives were considered and WHY rejected

**Risks:**

- What could go wrong?
- What are the performance implications?
- What are the security considerations?

### 4. Test Strategy

- What needs unit tests?
- What needs integration tests?
- What are the critical paths to test?

---

## Output Format

Save to: `.claude/scratchpad/design-[name].md`

```markdown
# Design: [Feature Name]

## Summary
[2-3 sentences: what this feature does and the chosen approach]

## Research Summary
[Key findings from codebase research — facts only]

## Architecture

### Components
| Component | Layer | Responsibility |
|-----------|-------|----------------|
| [Name] | [Domain/App/Infra] | [What it does] |

### Data Flow
[Describe how data moves through components, step by step]

### Contracts

#### API Endpoints
| Method | Path | Request | Response |
|--------|------|---------|----------|
| POST | /api/... | `{...}` | `{...}` |

#### Database Changes
| Table/Collection | Change | Fields |
|-----------------|--------|--------|
| [name] | Add/Modify | [fields] |

## Decisions
| Decision | Chosen | Why | Alternatives Rejected |
|----------|--------|-----|----------------------|
| [What] | [Option A] | [Reason] | [Option B: reason] |

## Risks
| Risk | Severity | Mitigation |
|------|----------|------------|
| [Risk] | High/Med/Low | [How to handle] |

## Test Strategy
| What | Type | Priority |
|------|------|----------|
| [Component] | Unit/Integration | Must/Should |

## Open Questions
- [ ] [Question needing clarification]
```

---

## Rules

DO:

- Research the codebase thoroughly before designing
- Separate facts (research) from decisions (design)
- Document WHY, not just WHAT
- Identify risks and trade-offs honestly
- Keep it focused — only what's needed for this feature

DON'T:

- Write implementation code
- Design more than what's requested
- Skip the research phase
- Mix opinions into research findings
- Over-engineer — KISS and YAGNI still apply

---

## Next Steps

After design is approved:

1. Run `/plan <feature>` — reference the design document
2. Plan will use design as input for implementation phases
3. During code review, `code-reviewer` agent will verify plan compliance
