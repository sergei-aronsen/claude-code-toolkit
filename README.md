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

Without a team, you have no code review, no one to ask about architecture, no one to check security. This repository fills these gaps:

| Problem | Solution |
|---------|----------|
| Claude forgets rules every time | `CLAUDE.md` — instructions it reads at session start |
| No one to ask | `/debug` — systematic debugging instead of guessing |
| No code review | `/audit code` — Claude reviews against checklist |
| No security review | `/audit security` — SQL injection, XSS, CSRF, auth |
| Forget to check before deploy | `/verify` — build, types, lint, tests in one command |

**What's inside:** 24 commands, 7 audits, 23+ guides, templates for all major stacks.

---

## Quick Start

### 1. Installation

The script automatically detects framework (Laravel, Next.js) and copies the appropriate template.

So just run in terminal in the project folder:

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
```

For future updates use `/update-toolkit` command for reinstallation or updates.

### 2. Security Pack

This toolkit includes a defense-in-depth security setup.

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/setup-security.sh | bash
```
See [components/security-hardening.md](components/security-hardening.md) for the full guide.


### 3. Rate Limit Statusline (Claude Max / Pro)

Monitor your API usage limits directly in the Claude Code status bar.

**Requirements:** macOS, `jq`, Claude Code with OAuth (Max or Pro subscription)

```bash
curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/install-statusline.sh | bash
```

See [components/rate-limit-statusline.md](components/rate-limit-statusline.md) for customization and details.

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

## What's Inside

**7 templates** (base, Laravel, Rails, Next.js, Node.js, Python, Go) | **24 slash commands** | **7 audits** | **23+ guides**

See [full list of commands, templates, audits, and components](docs/features.md#slash-commands-24-total).

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
```

---

## Supported Frameworks

| Framework | Template | Skills | Auto-detection |
|-----------|----------|--------|----------------|
| Laravel | ✅ Dedicated | ✅ | `artisan` file |
| Ruby on Rails | ✅ Dedicated | ✅ | `bin/rails` / `config/application.rb` |
| Next.js | ✅ Dedicated | ✅ | `next.config.*` |
| Node.js | ✅ Dedicated | ✅ | `package.json` (without next.config) |
| Python | ✅ Dedicated | ✅ | `pyproject.toml` / `requirements.txt` |
| Go | ✅ Dedicated | ✅ | `go.mod` |
