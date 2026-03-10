# Claude Toolkit

Comprehensive instructions for AI-assisted development with Claude Code.

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](docs/readme/ru.md)** | **[Español](docs/readme/es.md)** | **[Deutsch](docs/readme/de.md)** | **[Français](docs/readme/fr.md)** | **[中文](docs/readme/zh.md)** | **[日本語](docs/readme/ja.md)** | **[Português](docs/readme/pt.md)** | **[한국어](docs/readme/ko.md)**

> Read full [step-by-step installation guide](docs/howto/en.md) first.

---

## Who Is This For

**Solo developers** building products with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Supported stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**27 slash commands** | **7 audits** | **24+ guides** | See [full list of commands, templates, audits, and components](docs/features.md#slash-commands-27-total).

---

## Quick Start

### 1. Security Pack (global, once)

Includes a defense-in-depth security setup. See [components/security-hardening.md](components/security-hardening.md) for the full guide.

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh | bash
```

### 2. Installation (per project)

The script automatically detects framework and copies the appropriate template.

Run in terminal in the project folder:

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Restart Claude!** For future updates use `/update-toolkit` command for reinstallation or updates.

> **Important:** The project template is for `project/.claude/CLAUDE.md` only. Do not copy it to `~/.claude/CLAUDE.md` — that file should contain only global security rules and personal preferences (under 50 lines). See [components/claude-md-guide.md](components/claude-md-guide.md) for details.

### 3. Rate Limit Statusline (Claude Max / Pro)

Shows session/weekly limits in the Claude Code status bar. More: [components/rate-limit-statusline.md](components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

### 4. Supreme Council (multi-AI review, optional)

Gemini + ChatGPT review your plans before coding. More: [components/supreme-council.md](components/supreme-council.md)

```bash
curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh | bash
```

---

## Killer Features

| Feature | Description |
|---------|-------------|
| **Self-Learning** | `/learn` saves one-time solutions; Skill Accumulation captures recurring patterns automatically |
| **Auto-Activation Hooks** | Hook intercepts prompts, scores context (keywords, intent, file paths), recommends relevant skills |
| **Knowledge Persistence** | Project facts in `.claude/rules/` — auto-loaded every session, committed to git, available on any machine |
| **Systematic Debugging** | `/debug` enforces 4 phases: root cause → pattern → hypothesis → fix. No guessing |
| **Production Safety** | `/deploy` with pre/post checks, `/fix-prod` for hotfixes, incremental deploys, worker safety |
| **Supreme Council** | `/council` sends plans to Gemini + ChatGPT for independent review before coding |
| **Structured Workflow** | 3 mandatory phases: RESEARCH (read-only) → PLAN (scratchpad) → EXECUTE (after confirmation) |

See [detailed descriptions and examples](docs/features.md).

---

## MCP Servers (recommended!)

| Server | Purpose |
|--------|---------|
| `context7` | Library documentation |
| `playwright` | Browser automation, UI testing |
| `memory-bank` | Memory between sessions |
| `sequential-thinking` | Step-by-step problem solving |
| `memory` | Knowledge Graph (relationship graph) |

> **Install globally** with `-s user` so MCP servers are available in every project, not just the current one.

**Option A** — ask Claude to do it for you:

```text
Install these MCP servers globally (-s user):
context7, playwright, memory-bank, sequential-thinking, memory (Knowledge Graph)
```

**Option B** — run manually:

```bash
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx @playwright/mcp@latest --browser chromium
claude mcp add -s user memory-bank -- npx -y @allpepper/memory-bank-mcp@latest
claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add -s user memory -- npx -y @modelcontextprotocol/server-memory
```

---

## RTK — Token Optimizer (optional)

[RTK](https://github.com/rtk-ai/rtk) (Rust Token Killer) — CLI proxy that reduces token consumption by 60-90% on dev commands (`git status`, `cargo test`, etc.).

```bash
brew install rtk
rtk init -g
```

> **Known issue:** Multiple `PreToolUse` hooks with the same matcher run **in parallel**.
> If RTK and cc-safety-net are separate hooks, their results conflict and RTK's rewrite gets lost.
> **Fix:** Use a single combined hook that runs safety-net first, then RTK sequentially.
> See `components/security-hardening.md` for the combined hook setup.

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
