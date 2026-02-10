# CLAUDE.md — Global vs Project Guide

How to structure your CLAUDE.md files to minimize token usage and avoid duplication.

---

## How Claude Code Loads Instructions

Claude Code reads CLAUDE.md files at **every message** — they go into the system prompt and consume context tokens.

| File | Scope | Loaded when |
|------|-------|-------------|
| `~/.claude/CLAUDE.md` | Global | Every session, every project |
| `project/.claude/CLAUDE.md` | Project | Only in this project |

Both files are loaded simultaneously. Duplication between them wastes tokens on every message.

---

## What Goes Where

### Global (`~/.claude/CLAUDE.md`) — keep under 50 lines

Universal rules that apply to **every project** on this machine:

- Security rules (forbidden patterns, required patterns, doubt protocol)
- Personal preferences (language, communication style)
- Universal workflow rules (Plan Mode, KISS/YAGNI)
- Git conventions (Conventional Commits, don't push to main)

### Project (`project/.claude/CLAUDE.md`) — keep under 400 lines

Rules specific to **this project only**:

- Project overview (stack, description, key directories)
- Project-specific commands and scripts
- Architecture rules and conventions
- Deploy procedures (IPs, URLs, specific steps)
- i18n rules, database conventions
- Memory sync instructions
- Worktree workflow (if using parallel sessions)
- Compact instructions (survive context compression)

---

## Anti-Patterns

### Do not use project template as global file

The base template (`templates/base/CLAUDE.md`) is designed for **project-level** use. It contains placeholders like `[PROJECT_NAME]`, `[Framework]`, `[command]` that make no sense globally. Copying it to `~/.claude/CLAUDE.md` wastes ~300+ lines of tokens in every project.

### Do not duplicate rules in both files

If a rule is in the global file, do not repeat it in the project file. Common duplicates:

- Security rules (already in global security pack)
- "Don't push to main" (already in Claude Code defaults)
- Plan Mode instructions (put in one place only)
- Knowledge persistence protocol (put in project file only)

### Do not put reference tables in CLAUDE.md

Slash commands, skills, audits, and MCP tools are discoverable at runtime. Claude sees available commands in system-reminder and finds tools via ToolSearch. Tables like these waste ~50-100 lines:

```markdown
<!-- DON'T put these in CLAUDE.md -->
| /verify | Pre-commit check |
| /debug  | Systematic debugging |
| /audit  | Security audit |
...
```

Instead, one line is enough:

```markdown
Skills and commands: `.claude/commands/`, `.claude/skills/*/SKILL.md`
```

---

## Size Guidelines

| File | Target | Max |
|------|--------|-----|
| Global CLAUDE.md | 20-50 lines | 100 lines |
| Project CLAUDE.md | 150-300 lines | 400 lines |
| Combined | 200-350 lines | 500 lines |

Every 100 lines in CLAUDE.md costs ~1,500 tokens per message. At 500 combined lines, you spend ~7,500 tokens before the conversation even starts.

---

## Example: Minimal Global File

```markdown
# Global Rules

## Communication
- Respond in Russian unless project requires otherwise
- All code, commits, and documentation in English

## Architecture
- KISS: simplest working solution
- YAGNI: no features "for the future"
- Do not create files without confirmation

## Workflow
- Plan Mode before code for non-trivial tasks
- 3 phases: Research (read-only) -> Plan (scratchpad) -> Execute

## Git
- Conventional Commits (feat:, fix:, refactor:)
- Never push directly to main
- Run linters before commit
```

This is ~20 lines. Combined with the security pack from `setup-security.sh`, the global file stays focused and useful.

---

## Example: Lean Project File

```markdown
# MyApp — Claude Code Instructions

## Compact Instructions
> 1. Security: validate input, parameterized queries
> 2. Stay in current directory, do not cd to siblings
> 3. All translations via lang files, never hardcode strings

## Project Overview
**Stack:** Laravel 12 + Vue 3 + MySQL
**Deploy:** user@192.168.1.100, rsync + pull + build

## Key Commands
composer serve     # dev server
npm run dev        # frontend
php artisan test   # tests

## Project Rules
1. Controllers use Form Requests for validation
2. Money stored in cents (integer)
3. API returns JSON via Resources
4. Queue jobs implement ShouldBeUnique

## Deploy Procedure
1. git fetch origin main && git merge origin/main
2. rsync to server
3. php artisan migrate --force
4. php artisan config:cache && queue:restart

## Memory Sync
- Before commit: cp ~/.claude/memory-bank/myapp/*.md .claude/memory/
- Knowledge Graph is in-memory only — import from JSON each session
```

This is ~40 lines. Add i18n rules, worktree workflow, etc. as needed — but keep each section concise.

---

## Migration from Bloated Setup

If your CLAUDE.md files are already large:

1. **Identify duplicates** — find rules that appear in both global and project files
2. **Delete from global** — keep only universal rules there
3. **Remove reference tables** — slash commands, skills, audits, MCP tools
4. **Compress verbose sections** — replace bash scripts with one-liners, replace long explanations with bullet points
5. **Test** — run a session, verify Claude still follows the important rules

---

## See Also

- [Structured Workflow](./structured-workflow.md) — 3-phase approach
- [Skills System](./skills-system.md) — skill accumulation and activation
- [Git Worktrees Guide](./git-worktrees-guide.md) — parallel sessions
