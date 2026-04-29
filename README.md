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

**30 slash commands** | **7 audits** | **29 guides** | See [full list of commands, templates, audits, and components](docs/features.md#slash-commands-30-total).

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

## Install Modes

TK auto-detects whether `superpowers` (obra) and `get-shit-done` (gsd-build) are installed and
chooses one of four modes: `standalone`, `complement-sp`, `complement-gsd`, or `complement-full`.
Each framework template documents its required base plugins in `## Required Base Plugins` — see
e.g. [templates/base/CLAUDE.md](templates/base/CLAUDE.md). For the full 12-cell install matrix
and step-by-step guidance, see [docs/INSTALL.md](docs/INSTALL.md).

### Standalone install

You don't have `superpowers` or `get-shit-done` installed (or you've explicitly opted out).
TK installs all 54 files — the full-fat default. Run in your regular terminal (not inside
Claude Code!) in the project folder:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
```

Then start Claude Code in that project directory. For future updates use `/update-toolkit`.

### Complement install

You have one or both of `superpowers` (obra) and `get-shit-done` (gsd-build) installed. TK
auto-detects them and skips the 7 files that would duplicate SP functionality, keeping the ~47
unique TK contributions (Council, framework CLAUDE.md templates, components library, cheatsheets,
framework-specific skills). Use the same install command — TK auto-selects the `complement-*`
mode. To override, pass `--mode standalone` (or any other mode name):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --mode complement-full
```

> **Mode behavior today.** `manifest.json` currently catalogues 7 SP overlaps and 0 GSD
> overlaps. `complement-sp` and `complement-full` skip the same 7 files; `complement-gsd`
> skips none — i.e. it is functionally equivalent to `standalone` until GSD-specific
> conflicts are catalogued. The 4-mode UX is preserved so the manifest can mark GSD
> overlaps incrementally without an installer rewrite.

### Install via marketplace

For Claude Desktop users, the toolkit is available as a Claude Code plugin
marketplace listing. From the Desktop Code tab, use the slash command:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Or from a terminal with the `claude` CLI:

```bash
claude plugin marketplace add sergei-aronsen/claude-code-toolkit
```

You will get three sub-plugins:

- `tk-skills` — 22 curated skills (Desktop-compatible)
- `tk-commands` — 29 slash commands (terminal Code only)
- `tk-framework-rules` — 7 framework CLAUDE.md fragments (terminal Code only)

The marketplace install is **equivalent** to the curl-bash install for terminal
Code users. For Desktop users, marketplace is the **only** install path — see
[docs/CLAUDE_DESKTOP.md](docs/CLAUDE_DESKTOP.md) for the full capability matrix.

### Upgrading from v3.x

v3.x users who installed SP or GSD after TK should run `scripts/migrate-to-complement.sh` to
remove duplicate files with per-file confirmation and a full pre-migration backup. See
[docs/INSTALL.md](docs/INSTALL.md) for the full 12-cell matrix and step-by-step guidance.

> **Important:** The project template is for `project/.claude/CLAUDE.md` only. Do not copy it
> to `~/.claude/CLAUDE.md` — that file should contain only global security rules and personal
> preferences (under 50 lines). See [components/claude-md-guide.md](components/claude-md-guide.md)
> for details.

---

## Killer Features

| Feature | Description |
|---------|-------------|
| **Self-Learning** | `/learn` saves solutions as scoped rule files with `globs:` — auto-loaded only for relevant files |
| **Auto-Activation Hooks** | Hook intercepts prompts, scores context (keywords, intent, file paths), recommends relevant skills |
| **Knowledge Persistence** | Project facts in `.claude/rules/` — auto-loaded every session, committed to git, available on any machine |
| **Systematic Debugging** | `/debug` enforces 4 phases: root cause → pattern → hypothesis → fix. No guessing |
| **Production Safety** | `/deploy` with pre/post checks, `/fix-prod` for hotfixes, incremental deploys, worker safety |
| **Supreme Council** | `/council` (installed globally to `~/.claude/commands/`) sends plans to Gemini + ChatGPT for independent review before coding |
| **Structured Workflow** | 3 mandatory phases: RESEARCH (read-only) → PLAN (scratchpad) → EXECUTE (after confirmation) |
| **Multi-CLI Bridges** | Auto-sync `CLAUDE.md` to Gemini CLI's `GEMINI.md` and OpenAI Codex's `AGENTS.md`. Drift-detected, opt-out via `--no-bridges`. See [docs/BRIDGES.md](docs/BRIDGES.md) |

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

Files marked † conflict with `superpowers` — omitted in `complement-sp` and `complement-full` modes.

```text
your-project/
└── .claude/
    ├── CLAUDE.md              # Main instructions (adapt for your project)
    ├── settings.json          # Hooks, permissions
    ├── commands/              # Slash commands
    │   ├── verify.md          # † omitted in complement-sp/full
    │   ├── debug.md           # † omitted in complement-sp/full
    │   └── ...
    ├── prompts/               # Audits
    │   ├── SECURITY_AUDIT.md
    │   ├── PERFORMANCE_AUDIT.md
    │   ├── CODE_REVIEW.md
    │   ├── DESIGN_REVIEW.md
    │   ├── MYSQL_PERFORMANCE_AUDIT.md
    │   └── POSTGRES_PERFORMANCE_AUDIT.md
    ├── agents/                # Subagents
    │   ├── code-reviewer.md   # † omitted in complement-sp/full
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

---

## Components

Reusable Markdown sections for composing custom `CLAUDE.md` files. Components are repo-root
assets — they are **not** installed into `.claude/`; reference them by absolute GitHub URL.

**Orchestration pattern** — see [components/orchestration-pattern.md](components/orchestration-pattern.md)
for the lean-orchestrator + fat-subagents design Council and GSD workflows both use.
Helps any custom slash command scale beyond a single context window.
