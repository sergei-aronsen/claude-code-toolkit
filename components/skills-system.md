# Skills System — Accumulation and Modular Structure

Self-learning system for Claude: accumulate project knowledge from corrections,
organize into modular skills with progressive disclosure.

**Inspired by [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)**

---

## Concept

```text
Correction → Pattern → Skill → Auto-activation → Better result
```

Skills are accumulated knowledge about the project. Claude learns from user corrections
and saves patterns for future sessions. Large skills use progressive disclosure
to save context tokens.

---

## Add to CLAUDE.md

```markdown
## Skill Accumulation (Self-Learning)

**IMPORTANT:** You can learn from corrections and accumulate project knowledge.

### When to CREATE a new skill

Suggest creating a skill when:

- User corrected you 2+ times on the same topic
- Discovered project-specific convention (naming, structure, patterns)
- Solved a complex problem with non-obvious solution
- User explicitly said "remember this" or "always do it this way"

**Suggestion format:**

\`\`\`text
Noticed pattern: [brief description]

Examples from this session:
- [specific example 1]
- [specific example 2]

Save as skill '[suggested-name]'?
Will activate on: [triggers]
\`\`\`

### When to UPDATE an existing skill

Suggest updating a skill when:

- Used skill, but user corrected the result
- User added a new rule to an existing topic
- Discovered an exception to a rule in the skill

**Suggestion format:**

\`\`\`text
New information for skill '[name]':

Current rule:
  [what's currently in the skill]

Addition/change:
  [what was learned]

Update skill?
- [A] Add as additional rule
- [B] Replace old rule
- [C] Add as exception
- [D] Don't update
\`\`\`

### When NOT to suggest a skill

- One-time correction (typo, one-off error)
- Obvious things (standard language/framework practices)
- Temporary solutions ("for now do it this way")
- User already declined a similar skill

### Skill file structure

\`\`\`markdown
# [Skill Name]

**Created:** [date]
**Last Updated:** [date]
**Trigger:** [when to activate]

## Core Rules

1. [Rule 1]
2. [Rule 2]

## Examples

### Correct

[example of correct code/approach]

### Incorrect

[example of incorrect — to avoid repeating]

## Exceptions

- [Exception 1]: [when rule doesn't apply]

## History

- [date]: Created — [reason]
- [date]: Updated — [what changed]
\`\`\`

### Updating skill-rules.json

After creating/updating a skill, update `.claude/skills/skill-rules.json`:

\`\`\`json
{
  "skills": {
    "[skill-name]": {
      "type": "domain",
      "enforcement": "suggest",
      "priority": "high",
      "description": "[description]",
      "promptTriggers": {
        "keywords": ["keyword1", "keyword2"],
        "intentPatterns": ["pattern1", "pattern2"]
      }
    }
  }
}
\`\`\`

### Skill priorities

| Priority | When to use |
|----------|-------------|
| `critical` | Security, auth, payments — always show |
| `high` | Core business logic — show on match |
| `medium` | Standard practices — show on explicit match |
| `low` | Nice-to-have — show only on exact match |
```

---

## Modular Skills: Progressive Disclosure

### Problem

Large guidelines document (2000+ lines) loaded at once:

- **Consumes context** — less room for code
- **Information lost** — middle content gets ignored
- **Expensive** — more tokens = more $

### Solution

Main file has navigation + core rules. Details in separate resources loaded **on demand**.

```text
SKILL.md (~300 lines)          <- Always loaded
├── resources/architecture.md   <- On demand
├── resources/endpoints.md      <- On demand
├── resources/error-handling.md  <- On demand
└── resources/testing.md         <- On demand
```

### SKILL.md Template (Modular)

```markdown
# Backend Development Guidelines

## Quick Navigation

| Task | Resource |
|------|----------|
| Understand architecture | [architecture.md](resources/architecture.md) |
| Create endpoint | [endpoints.md](resources/endpoints.md) |
| Handle errors | [error-handling.md](resources/error-handling.md) |
| Work with database | [database.md](resources/database.md) |
| Write tests | [testing.md](resources/testing.md) |

## Core Rules (ALWAYS follow)

### 1. TypeScript

- Strict mode is mandatory
- Explicit types for public API

### 2. Validation

- Input validation via Zod
- Validate at system boundary (controllers)

### 3. Error Handling

- Use `AppError` class
- Always log via Winston

### 4. Security

- No secrets in code
- Use parameterized queries

## When to Load Resources

- Creating an endpoint? → Read [endpoints.md](resources/endpoints.md)
- Writing error handling? → Read [error-handling.md](resources/error-handling.md)
- Working with database? → Read [database.md](resources/database.md)
```

### How Claude Uses This

```text
Scenario: "create registration endpoint"
1. Claude loads SKILL.md (~300 tokens)
2. Sees: "Creating endpoint? -> Read endpoints.md"
3. Loads resources/endpoints.md (~500 tokens)
4. Does NOT load testing.md, database.md
5. Total: ~800 tokens instead of 2000+
```

Savings: **60-85% tokens**.

### File Size Guidelines

| File | Recommended size |
|------|------------------|
| SKILL.md | 200-500 lines |
| Resource file | 200-800 lines |
| Total per skill | up to 3000 lines |

### When to Use Modular Structure

- Guidelines over 500 lines
- Different parts needed for different tasks
- Large and complex project

Not needed for guidelines under 300 lines or simple projects.

---

## File Structure

```text
.claude/
├── skills/
│   ├── skill-rules.json           # Activation rules
│   ├── backend-endpoints/
│   │   └── SKILL.md               # Accumulated knowledge
│   ├── database-patterns/
│   │   └── SKILL.md
│   └── testing-conventions/
│       ├── SKILL.md               # Navigation (modular)
│       └── resources/             # Details (on demand)
│           ├── unit-tests.md
│           └── e2e-tests.md
└── learned/                       # One-time solutions (/learn)
    └── prisma-connection-fix.md
```

---

## Integration with Other Components

### With /learn command

`/learn` saves one-time problem solutions. Skills — for repeating patterns.

```text
/learn → "How I solved problem X" (one-time)
skill  → "How we always do Y" (pattern)
```

### With auto-activation hooks

Skills are auto-activated through `skill-rules.json`.
See [hooks-auto-activation.md](hooks-auto-activation.md).

---

## Best Practices

### For the user

1. **Respond to suggestions** — "yes/no/A/B/C" helps Claude learn
2. **Be specific in corrections** — "use X" is better than "do it differently"
3. **Review skills periodically** — remove outdated ones

### For Claude

1. **Don't spam suggestions** — only significant patterns
2. **Group related rules** — one skill per topic, not per rule
3. **Keep history** — to understand skill evolution
4. **Suggest specific options** — A/B/C is better than an open question
