# Claude Toolkit

Comprehensive instructions for AI-assisted development with Claude Code.

[![Quality Check](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/digitalplanetno/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[English](README.md)** | **[Русский](README.ru.md)** | **[Español](README.es.md)** | **[Deutsch](README.de.md)** | **[Français](README.fr.md)** | **[中文](README.zh.md)** | **[日本語](README.ja.md)** | **[Português](README.pt.md)** | **[한국어](README.ko.md)**

> Read full [step-by-step installation guide](docs/en.md) first.

---

## Who Is This For

**Solo developers** building products with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Supported stacks: **Laravel/PHP**, **Ruby on Rails**, **Next.js**, **Node.js**, **Python**, **Go**.

**7 templates** (basic, Laravel, Rails, Next.js, Node.js, Python, Go) 

**24 slash commands** | **7 audits** | **23+ guides** See [full list of commands, templates, audits, and components](docs/features.md#slash-commands-24-total).

---

## Quick Start

### 1. Installation

The script automatically detects framework (Laravel, Next.js) and copies the appropriate template.

So just run in terminal in the project folder:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

**Restart Claude!** For future updates use `/update-toolkit` command for reinstallation or updates.


### 2. Security Pack

Includes a defense-in-depth security setup. See [components/security-hardening.md](components/security-hardening.md) for the full guide.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```


### 3. Rate Limit Statusline (Claude Max / Pro)

Shows session/weekly limits in the Claude Code status bar. More: [components/rate-limit-statusline.md](components/rate-limit-statusline.md)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

---

## Killer Features

| Feature | Description |
|---------|-------------|
| **Self-Learning** | `/learn` saves one-time solutions; Skill Accumulation captures recurring patterns automatically |
| **Auto-Activation Hooks** | Hook intercepts prompts, scores context (keywords, intent, file paths), recommends relevant skills |
| **Memory Persistence** | Export MCP memory to `.claude/memory/`, commit to git — available on any machine |
| **Systematic Debugging** | `/debug` enforces 4 phases: root cause → pattern → hypothesis → fix. No guessing |
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

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add memory-bank -- npx -y @anthropic/memory-bank-mcp
claude mcp add sequential-thinking -- npx -y @anthropic/sequential-thinking-mcp
claude mcp add memory -- npx -y @anthropic/memory-mcp
```

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
    ├── scratchpad/            # Working notes
    └── memory/                # MCP memory export
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
