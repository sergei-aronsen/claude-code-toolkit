# Modular Skills: Progressive Disclosure

Breaking large guidelines into modules to save context.

**Inspired by [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase)**

---

## Problem

You have a large guidelines document (2000+ lines). If Claude loads everything at once:

- **Consumes context** — less room for your code
- **"Forgets" important things** — information in the middle gets lost
- **Expensive** — more tokens = more $
- **Slower** — more data to process

## Solution: Progressive Disclosure

The main file contains only navigation and core rules. Details are in separate resources that Claude loads **as needed**.

```text
SKILL.md (~300 lines)          <- Always loaded
|
+-- resources/architecture.md   <- On demand
+-- resources/endpoints.md      <- On demand
+-- resources/error-handling.md <- On demand
+-- resources/testing.md        <- On demand
```

---

## File Structure

```text
.claude/skills/
+-- backend-dev/
    +-- SKILL.md                 # Main file (navigation + core)
    +-- resources/
        +-- architecture.md      # Architecture details
        +-- endpoints.md         # Creating endpoints
        +-- error-handling.md    # Error handling
        +-- database.md          # Working with DB
        +-- testing.md           # Testing
```

---

## SKILL.md Template

```markdown
# Backend Development Guidelines

## Quick Navigation

| Task | Resource |
|------|----------|
| Understand project architecture | [architecture.md](resources/architecture.md) |
| Create new endpoint | [endpoints.md](resources/endpoints.md) |
| Handle errors | [error-handling.md](resources/error-handling.md) |
| Work with database | [database.md](resources/database.md) |
| Write tests | [testing.md](resources/testing.md) |

---

## Core Rules (ALWAYS follow)

These rules are always loaded — they're short and critical:

### 1. TypeScript

- Strict mode is mandatory
- Explicit types for public API
- No `any` without reason

### 2. Validation

- Input validation via Zod
- Validate at system boundary (controllers)

### 3. Error Handling

- Use `AppError` class
- Always log via Winston
- No `console.log` in production

### 4. Security

- No secrets in code
- Sanitize user input
- Use parameterized queries

---

## When to Load Resources

### Creating an endpoint?

-> Read [endpoints.md](resources/endpoints.md) before starting

### See an error or writing error handling?

-> Read [error-handling.md](resources/error-handling.md)

### Working with database?

-> Read [database.md](resources/database.md)

### Writing or fixing tests?

-> Read [testing.md](resources/testing.md)

---

## Project Structure

```text
src/
+-- controllers/    # HTTP handlers (thin, validation only)
+-- services/       # Business logic
+-- repositories/   # Data access
+-- models/         # TypeScript types/interfaces
+-- middleware/     # Express middleware
+-- utils/          # Helpers
```

Details in [architecture.md](resources/architecture.md).

---

## Resource File Example

**resources/endpoints.md** contains:

- `# Creating Endpoints` — header
- `## Controller Template` — with TypeScript code example
- `## Naming Conventions` — naming patterns table
- `## HTTP Methods` — methods and routes table
- `## Error Responses` — link to error-handling.md

**Example controller template from resource:**

```typescript
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { UserService } from '../services/user.service';

// 1. Define validation schema
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(['user', 'admin']).default('user'),
});

// 2. Controller function
export const createUser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const data = CreateUserSchema.parse(req.body);
    const user = await UserService.create(data);
    res.status(201).json({ data: user });
  } catch (error) {
    next(error);
  }
};
```

**Tables in resource:**

| Type | Pattern | Example |
|------|---------|---------|
| Controller file | `[entity].controller.ts` | `user.controller.ts` |
| Service file | `[entity].service.ts` | `user.service.ts` |

| Action | Method | Route | Response |
|--------|--------|-------|----------|
| List | GET | `/api/users` | 200 + array |
| Create | POST | `/api/users` | 201 + object |
| Update | PUT | `/api/users/:id` | 200 + object |
| Delete | DELETE | `/api/users/:id` | 204 no content |

---

## How Claude Uses This

### Scenario: "create registration endpoint"

```text
1. Claude loads SKILL.md (~300 tokens)
2. Sees: "Creating endpoint? -> Read endpoints.md"
3. Loads resources/endpoints.md (~500 tokens)
4. Does NOT load testing.md, database.md (not needed now)
5. Total: ~800 tokens instead of 2000+
```

### Scenario: "fix error in UserService"

```text
1. Claude loads SKILL.md (~300 tokens)
2. Sees: "See error? -> Read error-handling.md"
3. Loads resources/error-handling.md (~400 tokens)
4. Total: ~700 tokens
```

---

## Comparison of Approaches

| Approach | Tokens | Problems |
|----------|--------|----------|
| Single 2000-line file | 2000+ | Context, cost, information loss |
| Modular with resources | 300-800 | Only needed content loaded |

Savings: **60-85% tokens**

---

## Best Practices

### 1. Core Rules — short and critical

In SKILL.md only what's needed ALWAYS:

- Naming conventions
- Critical security rules
- Project structure (brief)

### 2. Resources — detailed and specific

In resources/ detailed guides:

- Code examples
- Templates
- Edge cases
- Troubleshooting

### 3. Cross-references

Link resources to each other:

```markdown
For error responses use format from [error-handling.md](error-handling.md).
```

### 4. Navigation table is mandatory

Always start SKILL.md with navigation table — Claude immediately sees what's where.

### 5. File sizes

| File | Recommended size |
|------|------------------|
| SKILL.md | 200-500 lines |
| resource file | 200-800 lines |
| Total in skill | up to 3000 lines |

---

## When to Use

### Use modular skills when

- Guidelines over 500 lines
- Different parts needed for different tasks
- Want to save tokens
- Large and complex project

### Not needed when

- Guidelines under 300 lines
- Everything always needed (security checklist)
- Simple project

---

## Migrating Existing Document

### Step 1: Identify sections

```text
Was: GUIDELINES.md (2000 lines)
+-- Architecture (400 lines)
+-- Endpoints (500 lines)
+-- Error Handling (300 lines)
+-- Database (400 lines)
+-- Testing (400 lines)
```

### Step 2: Extract core rules

From each section take 2-3 most important rules -> SKILL.md

### Step 3: Create resources

Each large section -> separate file in resources/

### Step 4: Add navigation

Create "Task -> Resource" table at the beginning of SKILL.md

---

## Full Structure Example

```text
.claude/skills/backend-dev/
+-- SKILL.md                      # 300 lines
+-- resources/
    +-- architecture.md           # 400 lines
    +-- endpoints.md              # 500 lines
    +-- error-handling.md         # 300 lines
    +-- database.md               # 400 lines
    +-- testing.md                # 400 lines
    +-- examples/
        +-- controller-example.ts
        +-- service-example.ts
```

**Total:** 2300 lines, but Claude loads only 300-800 at a time.
