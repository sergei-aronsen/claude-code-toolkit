# MCP Servers Guide

Recommended MCP (Model Context Protocol) servers to extend Claude Code capabilities.

## What is MCP

MCP servers add new tools for Claude Code:

- Access to library documentation
- Browser automation
- Context preservation between sessions
- Improved code search

## Installation

### Via Claude Code CLI

```bash
# Add MCP server
claude mcp add <server-name>

# List servers
claude mcp list

# Remove server
claude mcp remove <server-name>
```

### Via Configuration

File: `~/.claude.json` (global) or `.claude/settings.local.json` (project)

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

### 3. Memory Bank — Memory Between Sessions

Saving project context for future sessions.

```json
{
  "memory-bank": {
    "command": "npx",
    "args": ["-y", "@allpepper/memory-bank-mcp@latest"],
    "env": {
      "MEMORY_BANK_ROOT": "~/.claude/memory-bank"
    }
  }
}
```

**When to use:**

- Save important architectural decision
- Record "why we did it this way"
- Pass context to new session

**Examples:**

```text
"Save to memory-bank why we chose Redis over Memcached"
"What's recorded in memory-bank about this project?"
```

---

### 4. Sequential Thinking — Complex Tasks

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

### 5. Morph Fast Tools — Fast Editing

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

### 6. Knowledge Graph Memory — Knowledge Graph (for Opus)

> **WARNING:** In-memory only — data lost on restart. Import from `.claude/memory/knowledge-graph.json` at session start. See [memory-persistence.md](memory-persistence.md).

Builds a graph of relationships between project entities. Unlike Memory Bank (key-value facts), this stores how entities relate to each other.

```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"],
    "env": {}
  }
}
```

---

## Syncing Memory with Git

**Problem:** MCP servers store data locally. When transferring project to another computer — memory is lost.

**Solution:** Export memory to `.claude/memory/` inside repository.

### Structure

```text
.claude/
├── CLAUDE.md
└── memory/                    # Memory export for git
    ├── README.md
    ├── knowledge-graph.json   # Knowledge Graph export
    ├── project-context.md     # Memory Bank files
    └── decisions-log.md
```

### Workflow

1. **At session start** — check sync (file dates)
2. **After MCP changes** — immediately copy to `.claude/memory/`
3. **Before commit** — ensure memory is synced

### Details

See component **[memory-persistence.md](memory-persistence.md)** for complete instructions.

---

## Full Configuration

Add to `~/.claude.json`:

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
    "memory-bank": {
      "command": "npx",
      "args": ["-y", "@allpepper/memory-bank-mcp@latest"],
      "env": {
        "MEMORY_BANK_ROOT": "~/.claude/memory-bank"
      }
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "env": {}
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
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

### memory-bank — Project Memory
**When:** Save or read important context between sessions.
Example: Record "Why we chose RDAP over WHOIS scraping"

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
| Memory Bank "directory not found" | `mkdir -p ~/.claude/memory-bank` |
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

## Useful Resources

- [MCP Specification](https://modelcontextprotocol.io/)
- [Claude Code MCP Docs](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)
