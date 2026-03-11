# MCP Servers Guide

Recommended MCP (Model Context Protocol) servers to extend Claude Code capabilities.

## What is MCP

MCP servers add new tools for Claude Code:

- Access to library documentation
- Browser automation
- Multi-step problem solving

## Installation

### Global vs Project Scope

**Always install MCP servers globally** (`-s user`) so they are available across all projects:

```bash
claude mcp add -s user <server-name> -- <command>
```

Global servers are stored in `~/.claude/settings.json` and work in every project automatically. Project-level servers (`.claude/settings.local.json`) only work in that specific project and need to be set up again for each new project.

### Via Claude Code CLI

```bash
# Add MCP server globally (recommended)
claude mcp add -s user <server-name> -- <command>

# Add MCP server to current project only
claude mcp add <server-name> -- <command>

# List servers
claude mcp list

# Remove server
claude mcp remove <server-name>
```

### Via Configuration

File: `~/.claude/settings.json` (global, recommended) or `.claude/settings.local.json` (project)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["package-name"],
      "env": {}
    }
  }
}
```

---

## Recommended Servers

### 1. Context7 — Library Documentation

Up-to-date documentation for Laravel, Vue, React, Next.js and other libraries.

```json
{
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"],
    "env": {}
  }
}
```

**When to use:**

- Need documentation for library API
- Check current syntax
- Find usage examples

**Examples:**

```text
"How does Laravel Queue middleware work?" → uses context7
"Show useEffect with cleanup example" → uses context7
```

---

### 2. Playwright — Browser Automation

UI testing, screenshots, form filling.

**Recommended config (Chromium — avoids conflicts with system Chrome):**

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--browser", "chromium"],
    "env": {}
  }
}
```

Then install Chromium: `npx playwright install chromium`

> **Why Chromium?** System Chrome redirects new Playwright instances to the already-running window, causing failures. Chromium is a separate binary managed by Playwright — no conflicts.

**Alternative (system Chrome):**

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest"],
    "env": {}
  }
}
```

**When to use:**

- Check web interface
- Take page screenshot
- Test a form
- Automate browser actions

**Examples:**

```text
"Open localhost:3000 and check that form works"
"Take screenshot of /dashboard page"
```

**Important:** Always call `browser_close` after finishing tests. Multiple Claude sessions share the same browser profile — leaving it open blocks other sessions.

**Screenshot formats:**

- Supported: `png`, `jpeg`
- **Not supported:** `webp`

For WebP output, take screenshot in PNG first, then convert:

```bash
# Convert PNG to WebP
cwebp screenshot.png -o screenshot.webp

# Or with ImageMagick
convert screenshot.png screenshot.webp
```

---

### 3. Sequential Thinking — Complex Tasks

Multi-step problem solving with revision capability. Use for architectural decisions and complex analysis.

```json
{
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
    "env": {}
  }
}
```

### 4. Morph Fast Tools — Fast Editing

Smart code search (WarpGrep) and fast file editing. Requires API key from [morph.sh](https://morph.sh).

```json
{
  "morph-fast-tools": {
    "command": "npx",
    "args": ["@morphllm/morphmcp"],
    "env": {
      "MORPH_API_KEY": "your-api-key",
      "ALL_TOOLS": "true"
    }
  }
}
```

---

## Deprecated Servers

### Memory Bank (deprecated)

> **Use `.claude/rules/` instead.** See [memory-persistence.md](memory-persistence.md).

Memory Bank (`@allpepper/memory-bank-mcp`) stored project context in markdown files via MCP. Problems:

- Agent often forgot to call the memory tool at session start
- State drift: memory database lived separately from git
- Last significant commit: February 2025 (stalled development)
- `.claude/rules/` provides the same functionality natively with auto-loading and git tracking

**To remove:**

```bash
claude mcp remove memory-bank
```

### Knowledge Graph Memory (deprecated)

> **Use `.claude/rules/` instead.** See [memory-persistence.md](memory-persistence.md).

Knowledge Graph (`@modelcontextprotocol/server-memory`) stored entity relationships. Problems:

- **In-memory only** — all data lost on restart
- `read_graph` dumps entire graph into context (14k+ tokens for moderate use)
- No semantic search — only exact/substring matching
- No project isolation — single flat graph for everything
- `.claude/rules/` with `globs:` provides better context routing with zero overhead

**To remove:**

```bash
claude mcp remove memory
```

---

## Project Knowledge Persistence

**Use `.claude/rules/` for auto-loaded project context.** This is the industry-standard approach.

### Structure

```text
.claude/
├── CLAUDE.md              # Workflow rules (auto-loaded)
├── rules/                 # Project facts (auto-loaded)
│   ├── project-context.md # Servers, architecture, conventions
│   └── [domain].md        # Domain rules with globs: scope
└── docs/                  # Reference docs (read on demand)
    └── decisions-log.md
```

Files in `.claude/rules/` are automatically loaded into every session — no manual MCP reads needed.

### Details

See **[memory-persistence.md](memory-persistence.md)** for the complete guide.

---

## Full Configuration

Add to `~/.claude/settings.json` (global):

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {}
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--browser", "chromium"],
      "env": {}
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "env": {}
    }
  }
}
```

---

## Instructions for CLAUDE.md

Add to your `CLAUDE.md` so Claude knows when to use MCP tools:

```markdown
## MCP Tools — When to Use

### context7 — Library Documentation
**When:** Need current documentation for Laravel, Vue, React and others.
Example: "How does Laravel Queue middleware work?"

### playwright — UI Testing
**When:** Check web interface, take screenshot.
Example: "Check that form on /contact works"
**Important:** Always call `browser_close` after testing — sessions share the browser profile.

### sequential-thinking — Complex Tasks
**When:** Multi-step analysis, architectural decisions.
Example: "Design a notification system"
```

---

## Verification

```bash
# Check connected servers
claude mcp list

# Or in interactive mode
claude
# Then: /mcp
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Server doesn't connect | Check `npx --version`, try `claude --debug`, install globally if needed |
| Playwright "browser not installed" | `npx playwright install chromium` |
| Playwright won't start (parallel sessions) | `pkill -f 'user-data-dir=.*mcp-chrome'` then remove stale lock (see below) |

**Playwright stale lock removal:**

```bash
# macOS
rm -f ~/Library/Caches/ms-playwright/mcp-chrome-*/SingletonLock
# Linux
rm -f ~/.cache/ms-playwright/mcp-chrome-*/SingletonLock
```

**Permanent fix** — add stop hook to `~/.claude/settings.json` to auto-kill browser on session end. See [playwright-self-testing.md](playwright-self-testing.md) for details.

---

## RTK — Token Optimizer (optional)

[RTK](https://github.com/rtk-ai/rtk) (Rust Token Killer) is a CLI proxy that reduces LLM token consumption by 60-90% on common dev commands. It filters noise from outputs of `git status`, `cargo test`, `npm run build` and others before they reach Claude's context.

### Installation

```bash
# Homebrew (recommended)
brew install rtk

# Or via curl
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
```

### Setup

```bash
# Install global auto-rewrite hook
rtk init -g
```

This installs a Claude Code hook that transparently rewrites commands (e.g., `git status` → `rtk git status`), requiring zero changes to your workflow.

### Compatibility Note

Claude Code runs all `PreToolUse` hooks with the same matcher **in parallel**. If RTK and cc-safety-net are separate hooks, their results conflict and RTK's `updatedInput` gets lost.

**Fix:** Use a single combined hook (`~/.claude/hooks/pre-bash.sh`) that runs safety-net first, then RTK sequentially. See `components/security-hardening.md` for the full script.

Also remove broad patterns like `Bash(git *)` from `permissions.allow` — RTK's hook handles both rewriting and permission via `permissionDecision: "allow"`.

### Useful Commands

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
```

---

## Useful Resources

- [MCP Specification](https://modelcontextprotocol.io/)
- [Claude Code MCP Docs](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)
