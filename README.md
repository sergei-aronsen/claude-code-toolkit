# Claude Code Toolkit

[![Quality Check](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml/badge.svg)](https://github.com/sergei-aronsen/claude-code-toolkit/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.2.0-blue.svg)](CHANGELOG.md)

**[English](README.md)** | **[Русский](docs/readme/ru.md)** | **[Español](docs/readme/es.md)** | **[Deutsch](docs/readme/de.md)** | **[Français](docs/readme/fr.md)** | **[中文](docs/readme/zh.md)** | **[日本語](docs/readme/ja.md)** | **[Português](docs/readme/pt.md)** | **[한국어](docs/readme/ko.md)**

---

## What this is

A thin overlay that stacks on top of [**Superpowers**](https://github.com/obra/superpowers) (brainstorming, subagents, TDD, debugging) and [**Get Shit Done**](https://github.com/gsd-build/get-shit-done) (Spec → Plan → Execute) and closes the gaps those plugins leave open for solo product builders.

**For:** solo founders and one-person engineering teams shipping real products with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

**Stacks supported:** Laravel · Rails · Next.js · Node.js · Python · Go.

## Gaps it closes

| Gap                                  | What the toolkit adds                                                                                                                                |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Multi-AI plan validation**         | `/council` — sends plans to Gemini 3 Pro + GPT 5.2 in parallel for independent review (persona overlays, content-hash cache, cost gate, ru locale).  |
| **Framework-specific context**       | 7 ready-made `CLAUDE.md` templates (base + 6 stacks) auto-detected from `artisan` / `next.config` / `go.mod` / `pyproject.toml` / `package.json`.    |
| **Production safety net**            | `cc-safety-net` blocks destructive commands (`rm -rf /`, `git reset --hard`, etc.) at PreToolUse — even through obfuscation. Wired into the installer. |
| **Token cost discipline**            | RTK rewrites verbose dev-command output (`git status`, test runners) to cut 60-90% tokens. Combined hook with `cc-safety-net` so neither blocks the other. |
| **Cost routing**                     | `better-model` routes simple tasks to cheaper models. Auto-installed and wired into the lifecycle.                                                    |
| **Symbol-aware code retrieval**      | [Serena](https://github.com/oraios/serena) (LSP-driven, MIT, local) + ripgrep + claude-context (semantic vector). The default Layer-3 search stack.   |
| **Multi-CLI bridges**                | Auto-sync `CLAUDE.md` to Gemini CLI's `GEMINI.md` and OpenAI Codex's `AGENTS.md`. Drift-detected on every install.                                    |
| **Integrations catalog**             | TUI installer for 23 MCP servers + 8 companion CLIs across 10 categories (Backend / Payments / Workspace / Project Management / …). Per-row scope.   |
| **Self-learning rules**              | `/learn` saves recurring fixes as scoped rule files with `globs:` — auto-loaded only for relevant files. No prompt bloat.                            |
| **Knowledge persistence**            | Project facts in `.claude/rules/` — auto-loaded each session, committed to git, follow you across machines.                                          |
| **Rate-limit visibility (Pro/Max)**  | Statusline shows session and weekly usage so you know when you're about to hit the wall.                                                              |
| **Dependency dashboard (v6.2)**      | `/update-deps` — interactive TUI listing every tracked dep across all 3 layers with installed-vs-latest version. You pick what to upgrade.            |

The unique value is the curation. Everything is opt-in via TUI checkbox at install time — nothing is forced on you.

## Install

One command. Run in your project folder, in a regular terminal (**not** inside Claude Code):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

The installer presents a TUI checklist (Toolkit, Security, RTK, Statusline, Council, Bridges, Integrations) and auto-detects whether `superpowers` and `get-shit-done` are already installed — if so, it skips the files those plugins already provide and installs only the unique ~47 toolkit contributions.

For Claude Desktop users, install via the marketplace instead:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

Full step-by-step walkthrough (with screenshots): [docs/howto/en.md](docs/howto/en.md).

## After install

| Command | What it does |
|---------|--------------|
| `/update-toolkit`  | Pull latest toolkit content into `.claude/`, preserving your local edits. |
| `/update-deps`     | Open the dependency dashboard (Layer 1/2/3 + MCPs). Pick what to upgrade. |
| `/council`         | Send a plan to Gemini + ChatGPT for independent review.                     |
| `/learn`           | Save the current solution as a scoped rule for future sessions.             |
| `/audit`           | Run one of 7 framework-aware audits (security, performance, etc.).          |
| `/debug`           | 4-phase systematic debugger: root-cause → pattern → hypothesis → fix.       |

Full command list: [docs/features.md](docs/features.md).

## Architecture

Toolkit v6.2 is a **thin overlay** organized in three layers:

- **Layer 1** — toolkit content (templates, slash commands, components, skills, agents)
- **Layer 2** — free base plugins (Superpowers, Get Shit Done, ru-text)
- **Layer 3** — optional external tools (cc-safety-net, RTK, Serena, claude-context, better-model)

Full diagram: [docs/architecture.md](docs/architecture.md).
For solo founders / non-developer product builders: [docs/non-programmer-mode.md](docs/non-programmer-mode.md).

## Migrating from v3.x or earlier

If you have an older toolkit install pre-dating Superpowers / GSD support, run the migration helper to remove duplicates with per-file confirmation and a full backup:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/migrate-to-complement.sh)
```

Full migration matrix: [docs/INSTALL.md](docs/INSTALL.md).

## Recommended MCP servers

The integrations catalog (`/integrations` after install) covers 23 servers. Minimum baseline:

| Server                  | Purpose                                       |
|-------------------------|-----------------------------------------------|
| `context7`              | Always-fresh library docs                     |
| `playwright`            | Browser automation, UI testing                |
| `sequential-thinking`   | Step-by-step problem solving                  |
| `sentry`                | Error monitoring                              |
| `dbhub` (per-project)   | Universal DB access — **read-only user only** |

> **Security note on `dbhub`** — always connect with a read-only database user. Do not rely on DBHub's app-level `--readonly` flag ([known bypasses](https://github.com/bytebase/dbhub/issues/271)). Per-project credentials go in `.claude/settings.local.json` (gitignored).

## License

MIT — see [LICENSE](LICENSE).
