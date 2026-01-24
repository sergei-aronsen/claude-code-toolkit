# /install — Install Claude Code from Claude Guides

## Description

Automatic installation of Claude Code instructions from the claude-guides repository.

## Usage

```text
/install
/install laravel
/install nextjs
```

## Process

### 1. Detect framework (if not specified)

```bash
# Check files in current directory
ls -la
```

- `artisan` → Laravel
- `next.config.js/mjs/ts` → Next.js
- otherwise → base

### 2. Run initialization

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-guides/main/scripts/init-claude.sh | bash -s -- [framework]
```

### 3. Adapt CLAUDE.md

After initialization, open `.claude/CLAUDE.md` and update:

- **Project Overview:** name, description, stack
- **Essential Commands:** current project commands
- **Project Structure:** actual structure
- **Known Gotchas:** project specifics (if any)

### 4. Report completion

```text
✅ Claude Code initialized!

Created:
- .claude/CLAUDE.md — main instructions
- .claude/prompts/ — audits
- .claude/agents/ — subagents
- .claude/commands/ — commands

Next step: review and adapt .claude/CLAUDE.md for your project.
```

## Example

**User:** `/install`

**Claude:**

1. Detects that this is a Laravel project (artisan exists)
2. Runs `curl ... | bash -s -- laravel`
3. Opens CLAUDE.md and updates Project Overview
4. Reports completion
