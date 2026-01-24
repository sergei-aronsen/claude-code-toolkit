# /explain — Explain Code or Architecture

## Purpose

Explain how code works, architectural decisions, or system behavior.

---

## Usage

```text
/explain <target>
```text

**Examples:**

- `/explain app/Services/PaymentService.php` — Explain entire service
- `/explain authentication flow` — Explain system flow
- `/explain this function` — Explain selected code
- `/explain why we use Redis here` — Explain decision

---

## Explanation Levels

### 1. High-Level (Architecture)

- What does this system/module do?
- How does it fit in the overall architecture?
- What are the main components?

### 2. Mid-Level (Flow)

- What's the sequence of operations?
- How do components interact?
- What's the data flow?

### 3. Low-Level (Code)

- What does this specific code do?
- Why is it written this way?
- What are the edge cases?

---

## Output Format

### For Code

```markdown
## Explanation: [target]

### Purpose
[What this code does in 1-2 sentences]

### How It Works

1. **Step 1:** [description]
   \`\`\`php
   // relevant code snippet
   \`\`\`

2. **Step 2:** [description]
   ...

### Key Concepts
- **[Concept 1]:** [explanation]
- **[Concept 2]:** [explanation]

### Why This Approach?
[Reasoning behind the implementation]

### Gotchas / Edge Cases
- [Edge case 1]
- [Edge case 2]
```text

### For Architecture

```markdown
## Architecture: [system/module]

### Overview
[High-level description]

### Components

\`\`\`
┌─────────────┐     ┌─────────────┐
│  Component  │────▶│  Component  │
└─────────────┘     └─────────────┘
        │
        ▼
┌─────────────┐
│  Component  │
└─────────────┘
\`\`\`

### Data Flow
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Key Files
| File | Purpose |
|------|---------|
| file1.php | Does X |
| file2.ts | Does Y |

### Design Decisions
- **Decision 1:** [why]
- **Decision 2:** [why]
```text

---

## Best Practices

1. **Start simple** — Begin with the big picture
2. **Use diagrams** — ASCII art for flows
3. **Show code** — Include relevant snippets
4. **Explain "why"** — Not just "what"
5. **Mention alternatives** — What else could be done

---

## Actions

1. Identify what needs explanation
2. Determine the appropriate level (high/mid/low)
3. Read relevant code and documentation
4. Structure the explanation
5. Include code examples and diagrams
6. Explain the reasoning, not just the mechanics
