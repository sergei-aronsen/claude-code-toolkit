---
description: (Re)generate the local HTML post-install setup guide for installed components and MCPs, then open it in the browser.
---

# /setup-guide

Regenerate `~/.claude/setup-guide.html` (or `.claude/setup-guide.html` if a project-local copy already exists) from the **current** state of installed toolkit components + MCP servers, then open it in the default browser.

## Why

The post-install guide is what an end user sees right after running `bash <(curl -sSL .../scripts/install.sh)`. It only lists sections for things they actually installed — but their setup drifts after the first install (they enable a new MCP, install claude-memo later, etc.). This command rebuilds the guide so the page reflects the **current** machine.

## What you should do

1. Locate the generator. In priority order:
   - `~/.claude/scripts/lib/post-install-guide.sh` (installed by `update-toolkit`)
   - `<repo>/scripts/lib/post-install-guide.sh` (developer mode — running from inside a clone)

2. Run it. The script auto-detects:
   - Components from filesystem probes (`~/.claude/CLAUDE.md`, `~/.claude/cc-safety-net.json`, `~/.claude/statusline-refresh.sh`, `rtk` on PATH, `~/.claude/council/brain.py`, `~/.claude/skills/memo-skill/.git`, project `GEMINI.md`/`AGENTS.md`).
   - MCPs from `~/.claude.json` `.mcpServers` keys.

3. Run with: `bash ~/.claude/scripts/lib/post-install-guide.sh`. Default output is `~/.claude/setup-guide.html`. The script prints the path on success.

4. Open the output:
   - macOS: `open <path>`
   - Linux: `xdg-open <path>`

5. If the generator emits `templates dir not found`, the user is missing the `templates/post-install/` payload. Tell them to run `/update-toolkit` (or `bash <(curl -sSL .../scripts/install.sh)`) so the templates land under `~/.claude/templates/post-install/`.

## Output

A short confirmation: which components + which MCPs ended up in the guide, plus the absolute path of the generated HTML file. Do **not** dump the HTML.

## When NOT to use

- Right after `install.sh` finishes — it already generates the guide and prints the path.
- If the user just wants a list of installed MCPs — that's `claude mcp list`.
