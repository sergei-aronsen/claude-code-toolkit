# Claude Code Toolkit

Comprehensive instructions for AI-assisted development with Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](docs/readme/ru.md)** | **[Español](docs/readme/es.md)** | **[Deutsch](docs/readme/de.md)** | **[Français](docs/readme/fr.md)** | **[中文](docs/readme/zh.md)** | **[日本語](docs/readme/ja.md)** | **[Português](docs/readme/pt.md)** | **[한국어](docs/readme/ko.md)**

> Read full [step-by-step installation guide](docs/howto/en.md) first.

---

## Who Is This For

**Solo developers** building products with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Supported stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**29 slash commands** | **7 audits** | **29 guides** | See [full list of commands, templates, audits, and components](docs/features.md#slash-commands-29-total).

---

## Quick Start

### 1. Global Setup (once)

#### a) Security Pack

Defense-in-depth security setup. See [components/security-hardening.md](components/security-hardening.md) for the full guide.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
```

#### b) RTK — Token Optimizer (recommended)

[RTK](https://github.com/rtk-ai/rtk) reduces token consumption by 60-90% on dev commands (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Note:** If RTK and cc-safety-net are separate hooks, their results conflict.
> The Security Pack (step 1a) already configures a combined hook that runs both sequentially.
> See [components/security-hardening.md](components/security-hardening.md) for details.

#### c) Rate Limit Statusline (Claude Max / Pro, optional)

Shows session/weekly limits in the Claude Code status bar. More: [components/rate-limit-statusline.md](components/rate-limit-statusline.md)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

### 2. Installation (per project)

The installer will:

- Ask you to **select your stack** (auto-detect recommended)
- Install toolkit (commands, agents, prompts, skills)
- Set up **Supreme Council** (Gemini + ChatGPT multi-AI review)
- Guide you through API key configuration

Run in terminal in the project folder:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

**Restart Claude!** For future updates use `/update-toolkit` command for reinstallation or updates.

> **Important:** The project template is for `project/.claude/CLAUDE.md` only. Do not copy it to `~/.claude/CLAUDE.md` — that file should contain only global security rules and personal preferences (under 50 lines). See [components/claude-md-guide.md](components/claude-md-guide.md) for details.

---

## Killer Features

| Feature | Description |
|---------|-------------|
| **Self-Learning** | `/learn` saves solutions as scoped rule files with `globs:` — auto-loaded only for relevant files |
| **Auto-Activation Hooks** | Hook intercepts prompts, scores context (keywords, intent, file paths), recommends relevant skills |
| **Knowledge Persistence** | Project facts in `.claude/rules/` — auto-loaded every session, committed to git, available on any machine |
| **Systematic Debugging** | `/debug` enforces 4 phases: root cause → pattern → hypothesis → fix. No guessing |
| **Production Safety** | `/deploy` with pre/post checks, `/fix-prod` for hotfixes, incremental deploys, worker safety |
| **Supreme Council** | `/council` sends plans to Gemini + ChatGPT for independent review before coding |
| **Structured Workflow** | 3 mandatory phases: RESEARCH (read-only) → PLAN (scratchpad) → EXECUTE (after confirmation) |

See [detailed descriptions and examples](docs/features.md).

---

## MCP Servers (recommended!)

### Global (all projects)

| Server | Purpose |
|--------|---------|
| `context7` | Library documentation |
| `playwright` | Browser automation, UI testing |
| `sequential-thinking` | Step-by-step problem solving |
| `sentry` | Error monitoring and issue investigation |

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Per-project (credentials)

| Server | Purpose |
|--------|---------|
| `dbhub` | Universal database access (PostgreSQL, MySQL, MariaDB, SQL Server, SQLite) |

```bash
claude mcp add dbhub -- npx -y @bytebase/dbhub --dsn "postgresql://user:pass@localhost:5432/dbname"
```

> **Security:** Always use a **read-only database user** — do not rely on DBHub's app-level `--readonly` flag ([known bypasses](https://github.com/bytebase/dbhub/issues/271)). Per-project servers go to `.claude/settings.local.json` (gitignored, safe for credentials). See [mcp-servers-guide.md](components/mcp-servers-guide.md) for full details.

---

## Structure After Installation

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Main instructions (adapt for your project)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Slash commands
    │   ├── verify.md
    │   ├── debug.md
    │   └── ...
    ├── prompts/               # Audits
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagents
    │   ├── code-reviewer.md
    │   ├── test-writer.md
    │   └── planner.md
    ├── skills/                # Framework expertise
    │   └── [framework]/SKILL.md
    ├── rules/                 # Auto-loaded project facts
    └── scratchpad/            # Working notes
```

---

## Supported Frameworks

| Framework | Template | Skills | Auto-detection |
|-----------|----------|--------|----------------|
| Laravel | ✅ | ✅ | `artisan` file |
| Ruby on Rails | ✅ | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ | ✅ | `next.config.*` |
| Node.js | ✅ | ✅ | `package.json` (without next.config) |
| Python | ✅ | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ | ✅ | `go.mod` |
