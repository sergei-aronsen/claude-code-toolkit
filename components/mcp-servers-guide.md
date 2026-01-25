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

Step-by-step solving of complex problems with revision capability.

```json
{
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
    "env": {}
  }
}
```

**When to use:**

- Task requires multi-step analysis
- Many solution options
- Need to not miss details
- Architectural decisions

**Examples:**

```text
"Design a notification system with scaling in mind"
"Analyze all edge cases for payment system"
```

---

### 5. Morph Fast Tools — Fast Editing

Smart code search (WarpGrep) and fast file editing.

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

**Requires:** API key from [morph.sh](https://morph.sh)

**When to use:**

- Find code by functionality description
- Quickly edit large file
- Search for related code

**Examples:**

```text
"Find where authorization errors are handled"
"Find all places where Redis is used"
```

---

### 6. Knowledge Graph Memory — Knowledge Graph (for Opus)

Advanced memory that builds a graph of relationships between project entities.

```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"],
    "env": {}
  }
}
```

**Difference from Memory Bank:**

| Memory Bank | Knowledge Graph |
|-------------|-----------------|
| Stores facts | Stores relationships between facts |
| Key-value storage | Graph database |
| "Why we chose Redis" | "Redis is connected to cache, cache is connected to API, API depends on auth" |

**When to use:**

- Build project dependency graph
- Find circular dependencies
- Analyze architectural contradictions
- Track how decisions affect each other

**Examples:**

```text
"Build dependency graph of authorization module"
"Find components that depend on deprecated API"
"Analyze relationships between services and find bottlenecks"
```

**Recommended for:** Claude Opus 4.5 (requires deep analysis)

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
      "args": ["@playwright/mcp@latest"],
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

### Server doesn't connect

1. Check that `npx` works: `npx --version`
2. Check logs: `claude --debug`
3. Try installing package globally: `npm install -g @package/name`

### Memory Bank: "directory not found"

Create directory manually:

```bash
mkdir -p ~/.claude/memory-bank
```

### Playwright: "browser not installed"

Install Playwright browsers:

```bash
npx playwright install chromium
```

---

## Useful Resources

- [MCP Specification](https://modelcontextprotocol.io/)
- [Claude Code MCP Docs](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)
