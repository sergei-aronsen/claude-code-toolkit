# Getting Started with Claude Code Toolkit

> Complete beginner guide: from zero to productive development with Claude Code

**[English](en.md)** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Prerequisites

Make sure you have installed:

- **Node.js** (check: `node --version`)
- **Claude Code** (check: `claude --version`)

If Claude Code is not installed yet:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Two Levels of Setup

| Level | What | When |
|-------|------|------|
| **Global** | Security rules + hooks + plugins | Once per machine |
| **Per-project** | Commands, skills, templates | Once per project |

---

## Step 1: Global Setup (once per machine)

This installs security rules, combined hook (safety-net + RTK support), and official Anthropic plugins. Done **once**, works for **all** projects.

Open your regular terminal (not Claude Code):

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

**What happens:**

- `~/.claude/CLAUDE.md` is created — global security rules. Claude Code reads this file **at every launch in any project**. It's an instruction like "never do SQL injection, don't use eval(), ask before dangerous operations"
- `cc-safety-net` is installed — blocks destructive commands (`rm -rf /`, `git push --force`, etc.)
- A combined hook is configured in `~/.claude/settings.json` — runs safety-net and RTK (if installed) sequentially, avoiding parallel hook conflicts
- Official Anthropic plugins are enabled — code-review, commit-commands, security-guidance, frontend-design

**Verify everything is working:**

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh | bash
```

That's it. The global part is done. You **never need to repeat this**.

---

## Step 2: Create Your Project

For example, a Laravel project:

```bash
cd ~/Projects
composer create-project laravel/laravel my-app
cd my-app
git init
```

Or Next.js:

```bash
cd ~/Projects
npx create-next-app@latest my-app
cd my-app
```

Or if you already have a project — just navigate to its folder:

```bash
cd ~/Projects/my-app
```

---

## Step 3: Install Toolkit into Project

While **inside the project folder**, run:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

The script **automatically detects** your framework (Laravel, Next.js, Python, Go, etc.) and creates:

```text
my-app/
└── .claude/
    ├── CLAUDE.md              ← Instructions for Claude (FOR YOUR PROJECT)
    ├── settings.json          ← Settings, hooks
    ├── commands/              ← 29 slash commands
    │   ├── debug.md           ← /debug — systematic debugging
    │   ├── plan.md            ← /plan — planning before coding
    │   ├── verify.md          ← /verify — pre-commit check
    │   ├── audit.md           ← /audit — security/performance audit
    │   ├── test.md            ← /test — writing tests
    │   └── ...                ← ~19 more commands
    ├── prompts/               ← Audit templates
    ├── agents/                ← Sub-agents (code-reviewer, test-writer)
    ├── skills/                ← Framework expertise
    ├── cheatsheets/           ← Cheatsheets (9 languages)
    ├── memory/                ← Memory between sessions
    └── scratchpad/            ← Working notes
```

**To specify framework explicitly:**

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash -s -- laravel
```

---

## Step 4: Configure CLAUDE.md for Your Project

This is the most important file. Open `.claude/CLAUDE.md` in your editor and fill it in:

```markdown
# My App — Claude Code Instructions

## Project Overview
**Framework:** Laravel 12
**Description:** Online electronics store

## Key Directories
app/Services/    — business logic
app/Models/      — Eloquent models
resources/js/    — Vue components

## Development Workflow
### Running Locally
composer serve    — start server
npm run dev       — frontend

### Testing
php artisan test

## Project-Specific Rules
1. All controllers use Form Requests
2. Money is stored in cents (integer)
3. API returns JSON via Resources
```

Claude **reads this file at every launch** in this project. The better you fill it in — the smarter Claude will be.

> **Do not copy this file to `~/.claude/CLAUDE.md`!** The global file (from Step 1) should only contain security rules and personal preferences — under 50 lines. Both files load into every message, so duplication wastes tokens. See [components/claude-md-guide.md](../../components/claude-md-guide.md) for guidelines.

---

## Step 5: Commit .claude to Git

```bash
git add .claude/
git commit -m "feat: add Claude Code toolkit configuration"
```

Now the configuration is saved in the repository. If you clone the project on another machine — the toolkit will already be there.

---

## Step 6: Launch Claude Code and Work

```bash
claude
```

Claude Code starts and automatically loads:

1. **Global** `~/.claude/CLAUDE.md` (security rules — from Step 1)
2. **Project** `.claude/CLAUDE.md` (your instructions — from Step 4)
3. All commands from `.claude/commands/`

Now you can work:

```text
> Create a REST API for product management: CRUD, pagination, search
```

---

## Useful Commands Inside Claude Code

| Command | What It Does |
|---------|--------------|
| `/plan` | Think first, code second (Research → Plan → Execute) |
| `/debug problem` | Systematic debugging in 4 phases |
| `/audit security` | Security audit |
| `/audit` | Code review |
| `/verify` | Pre-commit check (build + lint + tests) |
| `/test` | Write tests |
| `/learn` | Save problem solution for future reference |
| `/helpme` | Cheatsheet of all commands |

---

## Visual Overview — The Complete Path

```text
┌─────────────────────────────────────────────────────┐
│  ONCE PER MACHINE (Step 1)                          │
│                                                     │
│  Terminal:                                          │
│  $ curl ... setup-security.sh | bash                │
│                                                     │
│  Result:                                            │
│  ~/.claude/CLAUDE.md      ← security rules          │
│  ~/.claude/settings.json  ← combined hook + plugins │
│  ~/.claude/hooks/pre-bash.sh ← safety-net + RTK    │
│  cc-safety-net            ← npm package             │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  FOR EACH PROJECT (Steps 2-5)                       │
│                                                     │
│  Terminal:                                          │
│  $ cd ~/Projects/my-app                             │
│  $ curl ... init-claude.sh | bash                   │
│  $ # edit .claude/CLAUDE.md                         │
│  $ git add .claude/ && git commit                   │
│                                                     │
│  Result:                                            │
│  .claude/                 ← commands, skills,       │
│                              prompts, agents        │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  WORK (Step 6)                                      │
│                                                     │
│  $ claude                                           │
│  > /plan add authentication                         │
│  > /debug why 500 on /api/users                     │
│  > /verify                                          │
│  > /audit security                                  │
└─────────────────────────────────────────────────────┘
```

---

## Updating the Toolkit

When new commands or templates are released:

```bash
cd ~/Projects/my-app
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/update-claude.sh | bash
```

Or inside Claude Code:

```text
> /install
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `cc-safety-net: command not found` | Run `npm install -g cc-safety-net` |
| RTK not rewriting commands | Ensure single combined hook in settings.json, not separate hooks |
| Toolkit not detected by Claude | Check that `.claude/CLAUDE.md` exists in project root |
| Commands not available | Re-run `init-claude.sh` or check `.claude/commands/` folder |
| Safety-net blocks a legitimate command | Run the command manually in terminal outside Claude Code |
