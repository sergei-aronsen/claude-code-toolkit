# Installing and using Claude Code Toolkit

> The full path from zero to productive development with Claude Code, in one place.

**English** | **[Русский](ru.md)** | **[Español](es.md)** | **[Deutsch](de.md)** | **[Français](fr.md)** | **[中文](zh.md)** | **[日本語](ja.md)** | **[Português](pt.md)** | **[한국어](ko.md)**

---

## Prerequisites

Make sure you have:

- **Node.js** — `node --version` (20.x or newer recommended)
- **Claude Code** — `claude --version`
- **git** — to commit `.claude/` to your repo
- **jq** — required by the installer to merge `settings.json` (`brew install jq` / `apt install jq`)

If Claude Code isn't installed yet:

```bash
npm install -g @anthropic-ai/claude-code
```

---

## Install

`cd` into your project folder in a **regular terminal** (not inside Claude Code) and run:

```bash
cd ~/Projects/my-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

The installer opens a TUI checklist with every component:

```text
[x] toolkit              ← toolkit content (.claude/ in the project)
[x] security             ← global security pack + cc-safety-net
[ ] rtk                  ← rewrite verbose dev-command output (-60-90% tokens)
[ ] statusline           ← session/weekly usage in the status bar
[ ] council              ← /council = Gemini + ChatGPT plan validation
[ ] gemini-bridge        ← auto-sync CLAUDE.md → GEMINI.md
[ ] codex-bridge         ← auto-sync CLAUDE.md → AGENTS.md
[ ] mcp-servers (24)     ← TUI checklist for integrations (Stripe, Sentry, dbhub, …)
[ ] skills (22)          ← marketplace skills (i18n, shadcn, stripe, …)
```

`Space` to toggle, `↑/↓` to move, `Enter` to install what you've checked.

The installer detects your framework (Laravel, Next.js, Python, Go, …) by signature files and ships the matching `CLAUDE.md` template. If `superpowers` and `get-shit-done` are already installed, the toolkit skips the files those plugins already provide and only installs the ~47 unique contributions.

When it finishes, a local HTML page opens at `.claude/setup-guide.html` with step-by-step instructions for every installed MCP (where to get the API key, which env var to set, how to test).

---

## Commit and start working

```bash
git add .claude/ CLAUDE.md
git commit -m "chore: add Claude Code toolkit configuration"
claude
```

Claude Code starts and automatically loads:

1. The global `~/.claude/CLAUDE.md` (security rules — installed by the script)
2. The project `CLAUDE.md` (matched to your stack — you can extend with project-specific facts)
3. Every command from `.claude/commands/` and skill from the marketplace

---

## Useful commands

| Command            | What it does                                                                  |
|--------------------|-------------------------------------------------------------------------------|
| `/update-toolkit`  | Pull fresh toolkit content while preserving local `CLAUDE.md` edits.           |
| `/update-deps`     | Dependency dashboard (Layer 1/2/3 + MCP). Pick what to update.                 |
| `/council plan`    | Send a plan to Gemini + ChatGPT for independent review.                        |
| `/learn`           | Save the current decision as a scoped rule for future sessions.                |
| `/audit security`  | One of 7 framework-aware audits.                                              |
| `/debug problem`   | 4-phase systematic debugger.                                                  |
| `/setup-guide`     | Regenerate the local HTML setup walkthrough.                                   |
| `/helpme`          | Full command cheatsheet.                                                      |

---

## Visual flow

```text
┌────────────────────────────────────────────────────────┐
│  INSTALL (once per project)                            │
│                                                        │
│  $ cd ~/Projects/my-app                                │
│  $ bash <(curl -sSL …/install.sh)                      │
│  → TUI checklist → Space/Enter                         │
│                                                        │
│  Result:                                               │
│   ~/.claude/CLAUDE.md       ← security rules           │
│   .claude/                  ← commands, skills, agents │
│   CLAUDE.md                 ← stack-matched template   │
│   .claude/setup-guide.html  ← MCP-API setup guide      │
└────────────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│  DAILY WORK                                            │
│                                                        │
│  $ claude                                              │
│  > /plan add authentication                            │
│  > /debug 500 on /api/users                            │
│  > /audit security                                     │
│  > /council my DB migration plan                       │
└────────────────────────────────────────────────────────┘
```

---

## Updating

```bash
cd ~/Projects/my-app
# Inside Claude Code:
> /update-toolkit   # toolkit content
> /update-deps      # all dependencies (TUI with checkboxes)
```

`/update-deps` shows the full TUI list with installed-vs-latest. You pick which components to bump; everything else stays as-is.

---

## Claude Desktop

Desktop users install via marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

You get three sub-plugins: `tk-skills` (22 skills), `tk-commands` (29 commands), `tk-framework-rules` (7 CLAUDE.md fragments). Details: [docs/CLAUDE_DESKTOP.md](../CLAUDE_DESKTOP.md).

---

## Troubleshooting

| Problem                                            | Fix                                                                                       |
|----------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cc-safety-net: command not found` after install   | `npm install -g cc-safety-net`, then `bash <(curl …/scripts/install-hooks.sh)`            |
| RTK doesn't rewrite commands                       | `~/.claude/settings.json` must have **one combined** hook, not two separate ones          |
| Claude doesn't see project commands                | Restart `claude` from the same folder where `.claude/` lives                              |
| safety-net blocks a command you actually need      | Run it manually in a regular terminal (or temporarily set `TK_NO_SAFETY=1`)               |
| Installer hangs in the TUI                         | `Ctrl-C`, restart; on macOS `bash` 3.2 `↑/↓` may need `--no-tui-fallback`                 |
| `setup-guide.html` doesn't open                    | `open .claude/setup-guide.html` (macOS) / `xdg-open` (Linux). Or run `/setup-guide`.      |
