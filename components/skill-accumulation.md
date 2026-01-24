# Skill Accumulation — Self-Learning System

Instructions for Claude on automatic skill accumulation and evolution.

**Inspired by [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)**

---

## Concept

Skills are accumulated knowledge about the project. Claude learns from user corrections and saves patterns for future sessions.

```text
Correction → Pattern → Skill → Auto-activation → Better result
```

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

```text
Noticed pattern: [brief description]

Examples from this session:
- [specific example 1]
- [specific example 2]

Save as skill '[suggested-name]'?
Will activate on: [triggers]
```

### When to UPDATE an existing skill

Suggest updating a skill when:

- Used skill, but user corrected the result
- User added a new rule to an existing topic
- Discovered an exception to a rule in the skill

**Suggestion format:**

```text
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
```

### When NOT to suggest a skill

- One-time correction (typo, one-off error)
- Obvious things (standard language/framework practices)
- Temporary solutions ("for now do it this way")
- User already declined a similar skill

### Skill file structure

Use this template when creating:

```markdown
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
```

### Updating skill-rules.json

After creating/updating a skill, update `.claude/skills/skill-rules.json`:

```json
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
```

### Skill priorities

| Priority | When to use |
|----------|-------------|
| `critical` | Security, auth, payments — always show |
| `high` | Core business logic — show on match |
| `medium` | Standard practices — show on explicit match |
| `low` | Nice-to-have — show only on exact match |

---

## Example Dialogs

### Creating a new skill

```text
User: make an endpoint for users

Claude: [creates endpoint]

User: no, we always use Zod for input validation,
      and errors through AppError class

Claude: Got it, fixing...

[fixes code]

Claude: Noticed pattern: endpoints use Zod + AppError

Examples from this session:
- Validation: z.object({ email: z.string().email() })
- Errors: throw new AppError('Not found', 404)

Save as skill 'backend-endpoints'?
Will activate on: creating endpoint, api, route

User: yes

Claude: Created skill:
- .claude/skills/backend-endpoints/SKILL.md
- Added to skill-rules.json

Now when working with endpoints I'll automatically use
Zod for validation and AppError for errors.
```

### Updating an existing skill

```text
User: make an endpoint for orders

Claude: Using skill 'backend-endpoints'...

[creates with Zod + AppError]

User: also add checkAuth middleware — all protected routes
      should use it

Claude: [adds middleware]

Claude: New information for skill 'backend-endpoints':

Current rules:
- Validation via Zod
- Errors via AppError

Addition:
- Protected routes use checkAuth middleware

Update skill?
- [A] Add as additional rule
- [B] Replace old rule
- [C] Add as exception
- [D] Don't update

User: A

Claude: Updated skill 'backend-endpoints':
- Added rule: "Protected routes → checkAuth middleware"
- History: 2026-01-23 — Added checkAuth middleware rule
```

### Adding an exception

```text
User: make a public endpoint /api/health

Claude: Using skill 'backend-endpoints'...

[creates with checkAuth]

User: no, health check should be without authorization

Claude: [removes checkAuth]

Claude: New information for skill 'backend-endpoints':

Current rule:
- Protected routes use checkAuth middleware

Exception:
- /api/health — public, without checkAuth

Update skill?
- [A] Add as additional rule
- [B] Replace old rule
- [C] Add as exception ← recommended
- [D] Don't update

User: C

Claude: Updated skill 'backend-endpoints':
- Added exception: "/api/health — no authorization"
```

---

## Integration with Other Components

### With /learn command

`/learn` saves one-time problem solutions.
Skills — for repeating patterns.

```text
/learn → "How I solved problem X" (one-time)
skill  → "How we always do Y" (pattern)
```

### With auto-activation hooks

Skills are auto-activated through `skill-rules.json`.
See [hooks-auto-activation.md](hooks-auto-activation.md).

### With modular skills

Split large skills into modules.
See [modular-skills.md](modular-skills.md).

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
│       ├── SKILL.md               # Navigation
│       └── resources/             # Details (if skill is large)
│           ├── unit-tests.md
│           └── e2e-tests.md
└── learned/                       # One-time solutions (/learn)
    └── prisma-connection-fix.md
```

---

## Templates for templates/

### skill-rules.json (empty template)

```json
{
  "version": "1.0",
  "description": "Skill activation rules for this project",
  "skills": {
    "_example": {
      "_comment": "This is an example - delete or modify",
      "type": "domain",
      "enforcement": "suggest",
      "priority": "medium",
      "description": "Example skill",
      "promptTriggers": {
        "keywords": ["example", "sample"],
        "intentPatterns": ["(create|make).*?example"]
      }
    }
  }
}
```

### SKILL.md (empty template)

File structure:

- `# [Skill Name]` — header
- `**Created/Updated/Trigger**` — metadata
- `## Core Rules` — numbered list of rules
- `## Examples` — sections Correct and Incorrect with code examples
- `## Exceptions` — list of exceptions
- `## History` — changelog

See example in `templates/base/skills/_example/SKILL.md`

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
