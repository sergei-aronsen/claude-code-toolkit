# Integrations Catalog

The toolkit ships a curated catalog of **20 MCP servers** + **8 companion CLIs** across **10 categories**, installable via a single TUI page.

This page is the reference for what's in the catalog, how install works, what `unofficial` means, where the toolkit's responsibilities end, and where to file your own SDKs.

## Overview

- **Catalog source of truth:** `scripts/lib/integrations-catalog.json` (schema_version 2).
- **Validator:** `python3 scripts/validate-integrations-catalog.py` (Python stdlib only).
- **Library entry points:** `scripts/lib/mcp.sh` (catalog reader, status detection, summary table) and `scripts/lib/cli-installer.sh` (`cli_detect`, `cli_install`, `cli_post_install_hint`).
- **Test contracts:** `scripts/tests/test-integrations-catalog.sh` (schema), `test-cli-installer.sh` (primitives), `test-integrations-tui.sh` (page behavior).

## Catalog

Each row is one MCP entry. Some entries also ship a companion CLI (the official command-line tool for the same vendor) — installable separately or together via TUI checkbox selection.

### Docs Research

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Context7 | `@upstash/context7-mcp` | — | `CONTEXT7_API_KEY` | — |
| Firecrawl | `firecrawl-mcp` | `firecrawl` | `FIRECRAWL_API_KEY` | — |
| NotebookLM | `notebooklm-mcp` | — | OAuth (browser) | unofficial |

### Backend

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| AWS CloudWatch Logs | `awslabs.cloudwatch-logs-mcp-server@latest` | `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | shares `aws` CLI with Cost Explorer |
| AWS Cost Explorer | `awslabs.cost-explorer-mcp-server@latest` | `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | shares `aws` CLI with CloudWatch Logs |
| Cloudflare | `@cloudflare/mcp-server-cloudflare` | `wrangler` | `CLOUDFLARE_API_TOKEN` | — |
| Supabase | `@supabase/mcp-server-supabase` | `supabase` | `SUPABASE_ACCESS_TOKEN` | — |

### Payments

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Stripe | `@stripe/mcp` | `stripe` | `STRIPE_SECRET_KEY` | — |

### Email

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Resend | `@resend/mcp-send-email` | — | `RESEND_API_KEY` | — |

### Workspace

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Notion | `@notionhq/notion-mcp-server` | — | OAuth (browser) | — |

### Project Management

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Jira (Atlassian Cloud) | `@aashari/mcp-server-atlassian-jira` | — | `ATLASSIAN_SITE_NAME`, `ATLASSIAN_USER_EMAIL`, `ATLASSIAN_API_TOKEN` | — |
| Linear | `@tacticlaunch/mcp-linear` | — | `LINEAR_API_KEY` | — |
| YouTrack | `youtrack-mcp` | — | `YOUTRACK_URL`, `YOUTRACK_TOKEN` | — |

### Communication

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Slack | `slack-mcp-server` | — | `SLACK_MCP_XOXC_TOKEN`, `SLACK_MCP_XOXD_TOKEN` | community fork (no admin install needed) |
| Telegram | `@chaindead/telegram-mcp` | — | `TG_APP_ID`, `TG_API_HASH` | unofficial |

### Design

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Figma | `figma-developer-mcp` | — | `FIGMA_API_KEY` | — |

### Dev Tools

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Magic | `@21st-dev/magic` | — | `MAGIC_API_KEY` | — |
| OpenRouter | `openrouter-mcp` | — | `OPENROUTER_API_KEY` | — |
| Playwright | `@playwright/mcp` | `playwright` | — | — |

### Monitoring

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Sentry | `@sentry/mcp-server` | `sentry-cli` | `SENTRY_AUTH_TOKEN` | — |

## Installing integrations

Run the TUI:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --integrations
```

Or with the legacy alias `--mcps` (works but prints a one-line deprecation note):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --mcps
```

Flags:

- `--integrations` — open the catalog TUI (canonical name, v4.9+).
- `--mcps` — deprecated alias for `--integrations`. Will be removed in v6.0.
- `--mcp-only` — install MCP servers only; skip companion CLIs.
- `--cli-only` — install companion CLIs only; skip MCP server registration.
- `--mcp-only` and `--cli-only` are **mutually exclusive** (`--integrations --mcp-only --cli-only` exits with rc=2).
- `--yes` — non-interactive: install all uninstalled components in canonical order. Still respects the `unofficial` confirm gate (see below).
- `--dry-run` — print what would run without invoking installers.

The TUI groups entries by category in canonical order (Docs Research, Backend, Payments, Email, Workspace, Project Management, Communication, Design, Dev Tools, Monitoring). Categories with zero selectable entries are silently skipped.

After install, a per-component summary table renders:

```text
━━━ Integrations Install Summary ━━━
Entry                        MCP            CLI            Notes
────────────────────────────  ──────────────  ──────────────  ─────
supabase                     ✓              ✓              —
stripe                       ✓              ⊘ already      —
notebooklm                   ⊘ skipped      —              user declined unofficial
sentry                       ✓              ✗              brew not found

Installed: 2 MCPs, 1 CLIs · Skipped: 1 · Failed: 1
```

Glyphs: `✓` installed, `⊘` already / skipped, `✗` failed, `—` n/a, `·` would-install (dry-run).

## Unofficial entries

Two entries carry an `unofficial: true` flag in the catalog: **NotebookLM** and **Telegram**.

Why the flag:

- **NotebookLM** uses browser automation (the `nlm` CLI / Patchright stack). It works today but is fragile against Google UI changes and can break without notice.
- **Telegram** is a community implementation, not officially published by Telegram. Quality is good but support is community-only.

Behavior:

- TUI renders these rows with a leading `!` glyph (yellow under color, `[!]` under `NO_COLOR`).
- Before installing each unofficial entry, the toolkit prompts to stderr:

  ```text
  ! NotebookLM is community-maintained / browser-automation.
  Install anyway? [y/N]
  ```

  Reply `y` / `Y` / `yes` to proceed; anything else (including empty Enter) declines. Default is **N** (fail-closed) — matches the v4.3 UN-03 contract.

- `--yes` does **not** bypass this prompt (security boundary). Reply Y per row explicitly.
- If you decline, the entry is skipped from this install pass but stays visible in future TUI runs.

If you need to script unofficial-confirm in CI, set `ALWAYS_YES=1` in the environment — that bypasses the prompt for that single shell. Use only in trusted automation.

## OAuth / auth setup

Most integrations need credentials. The toolkit prints `→ Next: <hint>` to stderr after each CLI install — follow the hint per entry.

- **Cloudflare**: `wrangler login` (browser OAuth)
- **Supabase**: `supabase login` (token-based)
- **Stripe**: `stripe login` (browser, then test-mode key)
- **AWS** (CloudWatch Logs / Cost Explorer): `aws configure` (paste keys from IAM console)
- **NotebookLM**: `nlm login` (browser, Google account)
- **Notion**: OAuth flow during MCP install (Claude Code prompts in-session)
- **Slack**: bot token from `api.slack.com/apps` → set `SLACK_MCP_XOXC_TOKEN` and `SLACK_MCP_XOXD_TOKEN` env
- **Linear**: API key from `linear.app/settings/api` → `LINEAR_API_KEY`
- **YouTrack**: permanent token from profile → `YOUTRACK_URL` + `YOUTRACK_TOKEN`
- **Jira**: API token from `id.atlassian.com` → `ATLASSIAN_SITE_NAME` + `ATLASSIAN_USER_EMAIL` + `ATLASSIAN_API_TOKEN`
- **Figma**: personal access token → `FIGMA_API_KEY`
- **Sentry**: `sentry-cli login` or `SENTRY_AUTH_TOKEN` env
- **OpenRouter**: API key from openrouter.ai → `OPENROUTER_API_KEY`
- **Resend**: API key from resend.com → `RESEND_API_KEY`
- **Telegram**: app credentials from `my.telegram.org/apps` → `TG_APP_ID` + `TG_API_HASH`

The toolkit writes API keys to `~/.claude/mcp-config.env` (mode 0600) and adds a one-line `set -a; . ~/.claude/mcp-config.env; set +a` to your shell rc on first install. After install, edit `~/.claude/mcp-config.env`, fill in the placeholders, and reload your shell.

## Global vs per-project

This catalog installs **dev-machine globals** — stuff Claude Code needs to call mid-conversation:

- MCP servers register globally with Claude (`claude mcp add`)
- CLI tools land in `/usr/local/bin` (brew) or `~/.local/bin` (user-space)
- API keys live in `~/.claude/mcp-config.env`

The toolkit does **not** install per-project SDKs. Examples of what stays in your project's package manifest:

- `@supabase/supabase-js` — your project's `package.json`
- `stripe-node` — your project's `package.json`
- `@aws-sdk/client-s3` — your project's `package.json`
- `@notionhq/client` — your project's `package.json`

These are **dependencies of the application you're building**, not of Claude Code. Add them with `npm install` / `composer require` / `pip install` / `go get` per project — not via this toolkit.

Rule of thumb:

| Layer | Where | Example |
| ----- | ----- | ------- |
| MCP server | global (`~/.claude/mcp/`) | `claude mcp add supabase ...` |
| CLI dev tool | global (`/usr/local/bin`, `~/.local/bin`) | `wrangler`, `supabase`, `stripe` |
| API keys | global (`~/.claude/mcp-config.env`) | `SUPABASE_ACCESS_TOKEN=...` |
| SDK | per-project (`node_modules/`) | `@supabase/supabase-js` |
| Project config | per-project (`.env`, app config) | `SUPABASE_URL`, `SUPABASE_KEY` |

If you find yourself wanting to install an SDK via this toolkit, the answer is no — that's your project's concern. The toolkit's contract is **"globals only"** so updates and uninstalls are predictable across all your projects.

## Troubleshooting

### `brew: command not found` on macOS

Some entries install via Homebrew. The toolkit does **not** auto-install brew (`cli-installer.sh` D-18 invariant). When brew is required and absent, you'll see:

```text
cli-installer: brew not found — install from https://brew.sh, then re-run
```

Install Homebrew yourself:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then re-run the integrations install.

### Linux without `brew` and system Node

Some entries need `npm install -g <tool>`. With system Node (`/usr/bin/node`), `npm i -g` typically requires `sudo`. The toolkit refuses to elevate (`cli-installer.sh` D-17 — no `sudo` auto-prefix, ever). Solutions:

- Use `nvm` or `asdf` for user-space Node — `npm i -g` then writes to `~/.nvm/...` without root.
- Install via the vendor's user-space tarball if listed (Stripe and Sentry do this on Linux).
- Skip the CLI; use just the MCP. Most workflows don't need the companion CLI.

### AWS shared CLI

Both `aws-cost-explorer` and `aws-cloudwatch-logs` reference the same `aws` CLI binary. The dispatch loop detects this — running both selected entries triggers the `aws` install only once per session.

### Post-install hints don't auto-execute

By design (`cli-installer.sh` boundary). The toolkit prints `→ Next: aws configure` etc. but never opens browsers, runs auth flows, or persists tokens for you. Run them yourself when convenient.

### `--mcps is deprecated`

Phase 32 (v4.9) renamed `--mcps` to `--integrations`. The old flag still works but prints a one-line deprecation note to stderr. Switch when convenient — alias removal is post-v5.0.

### MCP registered but no API key — what now?

If you select an MCP that needs an env var and don't fill it during install, the toolkit registers the server with `claude mcp add` and queues the key for deferred fill-in. After install, you'll see:

```text
Some MCPs registered without API keys — finish setup:

  1) Open ~/.claude/mcp-config.env (already stubbed; mode 0600) and fill in:
       SUPABASE_ACCESS_TOKEN=<your-key>

  2) Shell rc updated: auto-source line added to ~/.zshrc.

  3) Reload shell env (open a fresh terminal, or run: exec $SHELL) and start claude.
```

Edit the file, reload your shell, and the MCP picks up the key on next claude launch — no re-registration needed.

## Adding new entries

To propose a new entry, edit `scripts/lib/integrations-catalog.json` and add an MCP block (and optionally a CLI block). Required MCP fields:

- `name` (string, must equal the entry key)
- `display_name` (string)
- `category` (must be in the top-level `categories[]` enum)
- `env_var_keys` (array of POSIX env var names; empty for OAuth)
- `install_args` (array — `[<name>, "--", <runner>, <args>...]`)
- `description` (one-line string)
- `requires_oauth` (boolean)
- Optionally `unofficial: true` for community / browser-automation entries.

Optional CLI block under `components.cli.<name>`:

- `detect_cmd` (binary name for `command -v`)
- `install.darwin` (string, runs verbatim — `brew install ...` or `curl ... | tar ...`)
- `install.linux` (string, same)
- `post_install_hint` (one-line `→ Next:` hint)

After editing, run:

```bash
python3 scripts/validate-integrations-catalog.py   # rc=0
bash scripts/tests/test-integrations-catalog.sh    # PASS≥10
make check                                          # rc=0
```

The validator enforces schema shape; the test enforces 20-entry count and category invariants. Bumping the count needs a deliberate test edit — that's the contract.

## See also

- [INSTALL.md](./INSTALL.md) — top-level installer flag reference
- [MCP-SETUP.md](./MCP-SETUP.md) — MCP setup deep dive (pre-v4.9, partially superseded by this page)
- [CHANGELOG.md](../CHANGELOG.md) — `[4.9.0]` entry summarises Phases 32-35
- `scripts/lib/integrations-catalog.json` — canonical catalog data
