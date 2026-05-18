# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/github/v/release/sergei-aronsen/claude-code-toolkit?label=version&color=blue)](CHANGELOG.md)

**English** | **[Русский](docs/readme/ru.md)** | **[Español](docs/readme/es.md)** | **[Deutsch](docs/readme/de.md)** | **[Français](docs/readme/fr.md)** | **[中文](docs/readme/zh.md)** | **[日本語](docs/readme/ja.md)** | **[Português](docs/readme/pt.md)** | **[한국어](docs/readme/ko.md)**

---

## What this is

A thin overlay on top of [**Superpowers**](https://github.com/obra/superpowers) (brainstorm, subagents, TDD, debug) and [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute) that closes the gaps those plugins leave for solo product builders.

**For:** solo founders and one-person engineering teams shipping real products with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Supported stacks:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Gaps it closes

| Gap                                  | What the toolkit adds                                                                                                                              |
|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Multi-AI plan validation**         | `/council` — sends your plan to Gemini and ChatGPT in parallel for independent review. Works through CLI (`gemini`, `codex`) or direct API keys. Persona overlays, content-hash cache, cost gate, ru locale. |
| **Product validation gate**          | `product-thinking` skill + `/product-review` — RIGID gate before code: target user, JTBD, pain intensity, success metric, distribution channel, structural advantage, unit economics with SaaS-graveyard floor, cheapest experiment with decision rule, top risk. Domain-configurable via `~/.claude/product-config.json`. |
| **Framework context**                | 7 ready-made `CLAUDE.md` templates (base + 6 stacks), auto-detected via `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`. |
| **Production safety net**            | `cc-safety-net` blocks destructive commands (`rm -rf /`, `git reset --hard`, etc.) at PreToolUse — even through obfuscation. Wired into the installer. |
| **Token-cost control**               | RTK rewrites verbose dev-command output (`git status`, test runners) — 60-90% token savings. Combined hook with `cc-safety-net`.                  |
| **Cost routing**                     | `better-model` routes simple tasks to cheaper models. Auto-installed and integrated into the install lifecycle.                                   |
| **Symbol-aware code search**         | [Serena](https://github.com/oraios/serena) (LSP, MIT, local) + ripgrep + claude-context (semantic vector). Default Layer-3 search stack.          |
| **Multi-CLI bridges**                | Auto-sync `CLAUDE.md` to `GEMINI.md` (Gemini CLI) and `AGENTS.md` (OpenAI Codex). Drift-detection at every install.                                |
| **Integrations catalog**             | TUI installer for 24 MCP servers + 8 companion CLIs across 10 categories (Backend / Payments / Workspace / Project Management / …). Per-row scope. |
| **Limit visibility (Pro/Max)**       | Statusline shows session/weekly usage — you can see when you're about to hit the wall.                                                              |
| **Dependency dashboard (v6.2)**      | `/update-deps` — interactive TUI listing every tracked dependency (Layer 1/2/3) with installed-vs-latest. You pick what to update.                |
| **Post-install setup guide (v6.3)**  | Generates a local HTML page (`/.claude/setup-guide.html`) with per-MCP API-key walkthroughs and per-component config — only sections for what you actually installed. |
| **Vendor functional changelog (v6.3)** | `/vendor-changelog` — pins external vendors (Superpowers, GSD, Serena, RTK, …) at every release; diffs HEAD vs pin; classifies changes BREAKING/ADOPT/IGNORE/DEPRECATE. Auto-pin on release via `.github/workflows/auto-pin-vendors-on-release.yml`. |

The headline value is curation. Everything is opt-in via TUI checkboxes — nothing is forced.

## Install

One command. Run it in a regular terminal **inside** your project folder (not inside Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

The installer shows a TUI checklist (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) and detects whether `superpowers` and `get-shit-done` are already installed. If they are, it skips the files those plugins already provide and only ships the ~47 unique toolkit contributions.

For Claude Desktop users — install via marketplace:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Full step-by-step guide (with the install TUI walkthrough): [docs/howto/en.md](docs/howto/en.md).

## Slash commands

Use these from inside Claude Code after `/plugin marketplace add`:

| Command            | What it does                                                                  |
|--------------------|-------------------------------------------------------------------------------|
| `/update-toolkit`  | Pull fresh toolkit content into `.claude/` while preserving local edits.       |
| `/update-deps`     | Open the dependency dashboard (Layer 1/2/3 + MCP). Pick what to update.        |
| `/council`         | Send a plan to Gemini + ChatGPT for independent review.                        |
| `/product-review`  | 4-persona business review (skeptic + marketer + CFO + user-empath) — runs **before** technical planning.|
| `/vendor-changelog`| Diff pinned external vendors against HEAD; classify changes BREAKING/ADOPT/IGNORE/DEPRECATE.        |
| `/learn`           | Save the current decision as a scoped rule for future sessions.                |
| `/audit`           | Run one of the 7 framework-aware audits (security, performance, etc.).        |
| `/debug`           | 4-phase systematic debugger: root-cause → pattern → hypothesis → fix.         |
| `/setup-guide`     | Regenerate the local HTML setup walkthrough for installed MCPs/components.    |

Full command list: [docs/features.md](docs/features.md).

## Architecture

The toolkit is a **thin overlay** organized in three layers:

- **Layer 1** — toolkit content (templates, slash commands, components, skills, agents)
- **Layer 2** — free base plugins (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — optional external tools (cc-safety-net, RTK, Serena, claude-context, better-model)

Full diagram: [docs/architecture.md](docs/architecture.md).
For solo founders / non-developer product builders: [docs/non-programmer-mode.md](docs/non-programmer-mode.md).

## MCP server catalog

The `--integrations` flag (or `/integrations` after the first install) opens a TUI checklist with 27 servers across 10 categories. Pick only what your project needs — the rest stays untouched.

| Category               | Servers                                                                                |
|------------------------|----------------------------------------------------------------------------------------|
| **docs-research**      | `context7` · `firecrawl` · `notebooklm`                                                |
| **backend**            | `aws-cloudwatch-logs` · `aws-cost-explorer` · `cloudflare` · `dbhub` · `supabase`      |
| **payments**           | `stripe`                                                                               |
| **email**              | `resend` · `mailgun`                                                                   |
| **workspace**          | `calendly` · `notion`                                                                  |
| **project-management** | `jira` · `linear` · `youtrack`                                                         |
| **communication**      | `slack` · `telegram`                                                                   |
| **design**             | `figma`                                                                                |
| **dev-tools**          | `magic` · `openrouter` · `serena` · `claude-context` · `playwright`                    |
| **monitoring**         | `sentry` · `datadog` · `posthog`                                                       |

Each server installs with per-row scope choice (`[U]` user / `[P]` project / `[L]` local). Project-scope writes credentials to `<project>/.env` (mode 0600) with auto-`.gitignore`; `.mcp.json` carries only `${VAR}` substitution form. More: [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md).

## License

MIT — see [LICENSE](LICENSE).
