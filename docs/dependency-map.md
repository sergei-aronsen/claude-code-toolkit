# Dependency Map

> Source-of-truth for the toolkit's three-layer architecture (v6+).
> Last verified: 2026-05-06.

The toolkit (Layer 1) sits on top of two free Anthropic-ecosystem plugins (Layer 2)
and a set of optional paid/external tools (Layer 3). This document tracks every
dependency the toolkit either composes with, recommends, or knowingly works
around — including upstream URLs, installed versions, install paths, and
known interaction points.

## Layer 1 — Toolkit (this repo)

| Item | Source | Local install path |
|------|--------|--------------------|
| claude-code-toolkit | `https://github.com/sergei-aronsen/claude-code-toolkit` | repo working dir |

## Layer 2 — Free base plugins (Anthropic plugin marketplace)

| Item | Marketplace | Source repo | Installed version | Commit | Local path |
|------|-------------|-------------|-------------------|--------|------------|
| superpowers | `claude-plugins-official` | `https://github.com/anthropics/claude-plugins-official` (subdir `superpowers/`) | 5.1.0 | `b7a8f76985f1e93e75dd2f2a3b424dc731bd9d37` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0` |
| get-shit-done | standalone repo | `https://github.com/gsd-build/get-shit-done` | 1.40.0 (minimal) | (see `~/.claude/get-shit-done/VERSION`) | `~/.claude/get-shit-done/` (workflows, references, templates, sdk) |
| code-review | `claude-plugins-official` | same | unknown | `00f13a5f46419a78b5cc1a344e890cb404843881` | `~/.claude/plugins/cache/claude-plugins-official/code-review/unknown` |
| commit-commands | `claude-plugins-official` | same | unknown | same | `~/.claude/plugins/cache/claude-plugins-official/commit-commands/unknown` |
| security-guidance | `claude-plugins-official` | same | unknown | same | `~/.claude/plugins/cache/claude-plugins-official/security-guidance/unknown` |
| frontend-design | `claude-plugins-official` | same | unknown | same | `~/.claude/plugins/cache/claude-plugins-official/frontend-design/unknown` |
| ru-text | `claude-community` | `https://github.com/anthropics/claude-plugins-community` (subdir `ru-text/`) | 1.4.0 | `7932d7c3a6adf4035e565202bf8e22212da7d253` | `~/.claude/plugins/cache/claude-community/ru-text/1.4.0` |

GSD SDK (CLI helper) — npm `get-shit-done-cc` → binary `/opt/homebrew/bin/gsd-sdk`.

## Layer 3 — Optional paid / external tools

### Productivity / developer-experience plugins

| Item | Marketplace | Source repo | Installed version | Commit | Local path |
|------|-------------|-------------|-------------------|--------|------------|
| caveman | `caveman` | `https://github.com/JuliusBrussee/caveman` | (commit-pinned) | `c2ed24b3e5d412cd0c25197b2bc9af587621fd99` | `~/.claude/plugins/cache/caveman/caveman/c2ed24b3e5d4` |

### Recommended MCP servers (from toolkit catalog)

| Item | Source repo | License | Install |
|------|-------------|---------|---------|
| serena | `https://github.com/oraios/serena` | MIT | `uv tool install -p 3.13 serena-agent@latest --prerelease=allow` then `serena init`; toolkit MCP wizard registers it |
| claude-context | `https://github.com/zilliztech/claude-context` (and `@zilliz/claude-context-mcp` on npm) | Apache-2.0 | toolkit MCP wizard with Milvus + OpenAI/Voyage env vars |

**Removed in v6.1:** `morph-compact` plugin and `morph-fast-tools`
catalog entry (`https://github.com/morphllm/morph-claude-code-plugin`,
npm `@morphllm/morphmcp` / `@morphllm/morphsdk`). Closed-source SDK,
no public source repo for the runtime, paid SaaS with no published
privacy/retention policy. See
`docs/research/morph-deep-dive-2026-05-06.md`.

### CLI hook / wrapper layer

| Item | Distribution | Local install |
|------|--------------|---------------|
| cc-safety-net | npm global `cc-safety-net@0.7.1` | npm bin in PATH; integrated via `~/.claude/hooks/pre-bash.sh` |
| RTK (Rust Token Killer) | homebrew binary | `/opt/homebrew/bin/rtk`; hook `~/.claude/hooks/rtk-rewrite.sh`; doc `~/.claude/RTK.md` |
| better-model (cost routing) | npm `better-model` (planned) | not installed locally yet — toolkit ships `scripts/setup-cost-routing.sh` wrapper |

### MCP servers (catalog entries the toolkit can install)

Listed in `mcp-catalog.json` (or analogous integrations catalog). Examples relevant
to v6: claude-context, Sentry, PostHog, Playwright, Calendly, NotebookLM. These are
external services and out of scope for static code analysis.

## Hook composition order (single PreToolUse chain)

`~/.claude/hooks/pre-bash.sh` runs: **safety-net (block) → RTK (rewrite)**. Must
stay a single hook to avoid parallel-execution conflicts (see comment block at
top of `pre-bash.sh`).

GSD installs ~16 hooks under `~/.claude/hooks/gsd-*` (workflow guards, prompt
guards, read injection scanners, statusline, validate-commit, session-state).
Caveman installs `caveman-{activate,config,mode-tracker,statusline}.{js,sh}`.
Toolkit's v6 advisory hooks layer (council/audit/reality-check/cost) lives in
the toolkit and is wired by `scripts/install-hooks.sh` (or equivalent).

## Where each upstream can be cloned for offline reading

The toolkit reserves `_external/` (gitignored) for cloned vendor source used
during analysis. Recommended sparse-clone strategy:

```bash
mkdir -p _external && cd _external

# Superpowers — sparse to subdir only
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/anthropics/claude-plugins-official.git
git -C claude-plugins-official sparse-checkout set superpowers

# GSD — full
git clone --depth 1 https://github.com/gsd-build/get-shit-done.git

# Caveman, Morph plugin, ru-text marketplace — full / sparse as needed
git clone --depth 1 https://github.com/JuliusBrussee/caveman.git
git clone --depth 1 https://github.com/anthropics/claude-plugins-community.git
git clone --depth 1 https://github.com/oraios/serena.git
```

`_external/` is in `.gitignore`. Never bundle vendor code in the toolkit
distribution — refer to upstream sources only.

## Version freshness check

```bash
cat ~/.claude/get-shit-done/VERSION
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | to_entries[] | {p:.key, v:.value[0].version, sha:.value[0].gitCommitSha}'
npm ls -g --depth=0 | grep -E "cc-safety-net|better-model|get-shit-done-cc"
which rtk gsd-sdk
```

## Update history

- 2026-05-06 — initial map created post-v6.0.0 ship.
