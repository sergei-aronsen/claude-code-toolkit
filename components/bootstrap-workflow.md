# Bootstrap Workflow — How to Start a New Project with Claude Guides

Step-by-step instructions for initializing a new project using Claude Guides.

## Principle

```text
IDEA → STACK → INSTRUCTIONS → ADAPTATION
```

**Why this order:**

1. Claude must understand **WHAT** we're doing (idea)
2. And **ON WHAT** (stack)
3. Only then can it choose the right template
4. And adapt it to project specifics

---

## Scenario 1: Project from Scratch

### First Prompt

```text
I want to create [project description].
Stack: [Laravel + Vue / Next.js + TypeScript / etc.]

1. Create project structure
2. Download Claude Code instructions from https://github.com/sergei-aronsen/claude-code-toolkit
   using init-claude.sh script for my stack
3. Adapt CLAUDE.md for this project:
   - Update Project Overview (name, description, stack)
   - Add project-specific commands
   - Add known gotchas if any
```

### Example for Laravel SaaS

```text
I want to create a SaaS platform for subscription management.
Stack: Laravel 11 + Vue 3 + Inertia.js + Tailwind CSS + PostgreSQL

1. Create Laravel project structure with Breeze (Inertia + Vue)
2. Download instructions from https://github.com/sergei-aronsen/claude-code-toolkit for Laravel
3. Adapt CLAUDE.md:
   - Name: SubscriptionHub
   - Add commands for Stripe integration
   - Add commands for multi-tenancy
```

### Example for Next.js Dashboard

```text
I want to create an analytics dashboard for tracking metrics.
Stack: Next.js 15 + TypeScript + Tailwind + Prisma + PostgreSQL

1. Create Next.js project with App Router
2. Download instructions from https://github.com/sergei-aronsen/claude-code-toolkit for Next.js
3. Adapt CLAUDE.md:
   - Name: MetricsDash
   - Add commands for working with charts (Recharts)
   - Add commands for real-time updates
```

---

## Scenario 2: Existing Project

If project is already created and you want to add Claude Code instructions:

### Short Prompt

```text
Initialize Claude Code from https://github.com/sergei-aronsen/claude-code-toolkit
Project: [name] — [brief description]
```

### Or via Terminal

```bash
cd your-project
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

The script automatically detects the stack:

- `artisan` → Laravel template
- `next.config.js/mjs/ts` → Next.js template
- otherwise → base (universal)

---

## What Claude Does After Initialization

### 1. Downloads Template

```text
.claude/
├── CLAUDE.md              # Main instructions
├── settings.json          # Hooks and permissions
├── prompts/               # Audits
├── agents/                # Subagents
├── skills/                # Framework expertise
└── scratchpad/            # Working notes
```

### 2. Adapts CLAUDE.md

Claude should update:

| Section | What to update |
|---------|----------------|
| Project Overview | Name, description, stack |
| Essential Commands | Commands for this project |
| Project Structure | Current structure |
| Security Rules | Project-specific rules |
| Known Gotchas | Project peculiarities |

### 3. Saves Context (optional)

Update `.claude/rules/project-context.md` with key project facts:

```text
Update rules/project-context.md with servers, architecture, conventions
```

---

## After Initialization

### Check Everything is in Place

```bash
ls -la .claude/
cat .claude/CLAUDE.md | head -50
```

### First Command in Project

```text
/context-prime
```

This loads project context and prepares Claude for work.

### Or Get Straight to Work

```text
/plan [first task description]
```

---

## Frequently Asked Questions

### Can I modify CLAUDE.md after initialization?

**Yes, and you should!** CLAUDE.md is a living document. Update it when:

- Adding new patterns
- Finding gotchas
- Project structure changes

### How to update instructions to new version?

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

The script updates common parts while preserving your customizations.

### What if my stack is not Laravel or Next.js?

Use the base template — it's universal and works with any stack:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash -s -- base
```

Then adapt it to your stack.

---

## Successful Initialization Checklist

- [ ] `.claude/CLAUDE.md` exists and is adapted to project
- [ ] Project Overview contains current information
- [ ] Essential Commands match the project
- [ ] `.claude/settings.json` is configured (hooks, permissions)
- [ ] Audits in `.claude/prompts/` are in place
- [ ] (Optional) Project context saved to `.claude/rules/project-context.md`
