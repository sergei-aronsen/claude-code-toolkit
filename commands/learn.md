# /learn — Extract Reusable Patterns

## Purpose

Extract problem solutions and save them as **scoped rule files** that auto-load only for relevant files.

---

## Usage

```text
/learn [description]
```

**Examples:**

- `/learn` — Analyze session and find patterns
- `/learn prisma connection pooling fix` — Save a specific solution
- `/learn always use UUID for public IDs` — Save an explicit instruction

---

## When to Use

Run `/learn` when:

- Solved a non-trivial problem
- Found a workaround for a library/framework
- Discovered non-obvious behavior
- User corrected your mistake (remember it!)
- Debugging took a long time
- 3+ attempts to fix one problem

**DO NOT use for:**

- Simple typos
- One-time issues (API was unavailable)
- Obvious solutions

---

## Process

### Step 1 — Analyze

Identify what was learned. Look at:

- Recent fixes and their root causes
- User corrections during the session
- Non-obvious behaviors discovered
- Patterns that took multiple attempts

### Step 2 — Scope the Rule

Determine which files this rule applies to. Pick the **narrowest matching scope**:

| Scope | globs example | Rule file name |
|-------|---------------|----------------|
| Language-specific | `["**/*.ts", "**/*.tsx"]` | `rules/typescript.md` |
| Framework-specific | `["app/**", "routes/**"]` | `rules/laravel.md` or `rules/nextjs.md` |
| Database/ORM | `["models/**", "prisma/**", "migrations/**"]` | `rules/database.md` |
| UI/Components | `["components/**", "pages/**"]` | `rules/ui-components.md` |
| API/Backend | `["api/**", "controllers/**", "routes/**"]` | `rules/api.md` |
| Testing | `["tests/**", "**/*.test.*", "**/*.spec.*"]` | `rules/testing.md` |
| Infrastructure | `["docker*", "*.yml", "Makefile"]` | `rules/infrastructure.md` |
| Global (last resort) | `["**/*"]` | `rules/project-lessons.md` |

Use **Global** only if the rule genuinely applies everywhere. Most rules have a narrower scope.

### Step 3 — Write the Rule

Each rule is compact — 3-4 lines max:

```markdown
### [Short Title] — [Date]
**Problem:** one-line description
**Solution:** one-line solution
**Apply when:** trigger condition
```

### Step 4 — Save to Scoped Rule File

**Target:** `.claude/rules/[scope].md`

If the file already exists — **append** the new rule at the end.
If the file does not exist — **create** it with frontmatter:

```yaml
---
description: Lessons learned — [scope description]
globs:
  - "[glob pattern]"
---
```

Example — new TypeScript rule file:

```yaml
---
description: Lessons learned — TypeScript patterns and gotchas
globs:
  - "**/*.ts"
  - "**/*.tsx"
---
```

### Step 5 — Log to Audit Trail

Append a one-line summary to `.claude/rules/lessons-learned.md`:

```markdown
- [Date] [scope] — [Short title]. Rule saved to rules/[scope].md
```

This file is the **history log** — a human-readable record of all lessons.
Its frontmatter:

```yaml
---
description: Audit log of all lessons learned (history only)
globs: []
---
```

Note: `globs: []` means this file is **never auto-loaded** into context. It exists purely for human review.

### Step 6 — Confirm

Show the user:

1. The rule you wrote
2. The target file and globs
3. Ask for confirmation before saving

---

## Deduplication

Before writing a new rule, **read the target rule file** and check:

- Is this rule already captured? If yes — skip or update
- Does an existing rule contradict? If yes — replace with the newer one
- Is the scope correct? A rule about Prisma should not be in `rules/typescript.md`

---

## Example Session

User fixed a Prisma connection timeout in serverless:

```text
> /learn prisma connection pooling fix
```

Agent creates `.claude/rules/database.md`:

```yaml
---
description: Lessons learned — Database and ORM patterns
globs:
  - "prisma/**"
  - "models/**"
  - "lib/db*"
---

### Prisma Connection Timeout in Serverless — 2026-03-11
**Problem:** Prisma connection pool exhaustion in Lambda/Vercel
**Solution:** Add `connection_limit=1` to DATABASE_URL for serverless
**Apply when:** Using Prisma with serverless runtime
```

Agent appends to `.claude/rules/lessons-learned.md`:

```markdown
- 2026-03-11 database — Prisma connection timeout in serverless. Rule saved to rules/database.md
```

---

## Migration from Old Format

If `.claude/rules/lessons-learned.md` contains old-style rules with `globs: ["**/*"]`:

1. Read existing lessons
2. Re-scope each one to the appropriate rule file
3. Move rules to scoped files
4. Update `lessons-learned.md` to audit-only format (`globs: []`)
5. Confirm with user before making changes

---

## Key Principles

- **Narrowest scope wins** — never use `globs: ["**/*"]` unless truly global
- **One rule file per domain** — not per lesson (avoid file explosion)
- **Append, don't rewrite** — add to existing rule files
- **Deduplicate** — check before adding
- **Confirm** — always show user before saving
- **Native mechanism** — `.claude/rules/` with `globs:` is Claude Code's built-in context routing
