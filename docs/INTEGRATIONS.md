# Integrations Catalog

The toolkit ships a curated catalog of **31 MCP servers** + **10 companion CLIs** across **10 categories**, installable via a single TUI page.

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
| Comet Research Bridge | `github:sergei-aronsen/Perplexity-Comet-MCP` | — | Perplexity Pro session | research via Perplexity Pro (no API cost); needs Comet browser — run `scripts/setup-comet.sh` first |

### Backend

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| AWS CloudWatch Logs | `awslabs.cloudwatch-logs-mcp-server@latest` | `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | shares `aws` CLI with Cost Explorer |
| AWS Cost Explorer | `awslabs.cost-explorer-mcp-server@latest` | `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | shares `aws` CLI with CloudWatch Logs |
| Cloudflare | `@cloudflare/mcp-server-cloudflare` | `wrangler` | `CLOUDFLARE_API_TOKEN` | — |
| Supabase | `@supabase/mcp-server-supabase` | `supabase` | `SUPABASE_ACCESS_TOKEN` | — |
| DBHub | `@bytebase/dbhub` | — | `DSN` | multi-DB — Postgres, MySQL, MariaDB, MSSQL, SQLite (read-only) |

### Payments

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Stripe | `@stripe/mcp` | `stripe` | `STRIPE_SECRET_KEY` | — |

### Email

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Resend | `@resend/mcp-send-email` | — | `RESEND_API_KEY` | — |
| Mailgun | `@mailgun/mcp-server` | — | `MAILGUN_API_KEY`, `MAILGUN_API_REGION` | send, validate, stats, suppressions |

### Workspace

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Calendly | HTTP `https://mcp.calendly.com/` | — | OAuth DCR (browser) | official; user scope |
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
| Higgsfield | HTTP `https://mcp.higgsfield.ai/mcp` | `higgsfield` | OAuth (browser) | official; image + video gen; user scope |

### Dev Tools

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Magic | `@21st-dev/magic` | — | `MAGIC_API_KEY` | — |
| OpenRouter | `openrouter-mcp` | — | `OPENROUTER_API_KEY` | — |
| Playwright | `@playwright/mcp` | `playwright` | — | — |
| GitHub | HTTP `https://api.githubcopilot.com/mcp/` | `gh` | OAuth or PAT | official remote — repos, PRs, issues, Actions, code search |
| Serena | `serena start-mcp-server` (uv tool) | — | — | LSP-driven symbol-aware code search/edit; needs `uv` |
| Claude Context | `@zilliz/claude-context-mcp@latest` | — | `MILVUS_TOKEN`, `OPENAI_API_KEY` | vector-DB semantic code search; for 100k+ LOC codebases |
| Repomix | `repomix@1.14.0` | — | — | pack local + remote repos into AI-friendly context |

### Monitoring

| Entry | MCP package | Companion CLI | Auth | Notes |
| ----- | ----------- | ------------- | ---- | ----- |
| Sentry | `@sentry/mcp-server` | `sentry-cli` | `SENTRY_AUTH_TOKEN` | — |
| Datadog | HTTP `https://app.datadoghq.com/api/v2/mcp/sse` | — | OAuth (browser) | official remote — APM, infra metrics, logs, dashboards, incidents |
| PostHog | `mcp-remote → https://mcp.posthog.com/sse` | — | `POSTHOG_AUTH_HEADER` | product analytics, error tracking, feature flags, A/B |

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

## Per-MCP scope

Each MCP row in the integrations TUI carries its own scope indicator immediately
after the checkbox. v5.0+ supports three scopes per MCP, configurable per row:

| Indicator | Scope | Where keys live (v6.4 default) | `claude mcp add` flag | Use when |
| --------- | ----- | --------------- | --------------------- | -------- |
| `[U]` | user | `~/.claude/mcp-config.env` (mode 0600), plain `KEY=value` | `--scope user` | Personal-tooling MCPs that follow you across all projects (e.g. `context7`, `notebooklm`, `figma`, `sentry`) |
| `[P]` | project | `~/.claude/mcp-config.env` under `KEY_<PROJECT_SLUG>=value`; `.mcp.json` references `${KEY_<SLUG>}` | `--scope project` | Per-app infra MCPs scoped to a single repository (e.g. `supabase`, `stripe`, `cloudflare`, `aws-*`) — restricted keys per project, single storage file |
| `[L]` | local | not persisted by toolkit | `--scope local` | Throw-away local-only experiments; the toolkit does not write a secrets file for `[L]` rows |

> **v6.4 change.** Project-scope `[P]` keys now live in the same
> `~/.claude/mcp-config.env` as user-scope keys, just under a suffixed
> slot name. The committed `<project>/.mcp.json` references the slot via
> `${KEY_<PROJECT_SLUG>}` substitution. `cd <project> && claude` works
> without direnv / dotenv because the shell rc auto-source line loads
> `mcp-config.env` into every shell. To opt back into the v6.3 behavior
> (keys in `<project>/.env`, requires direnv), export
> `TK_MCP_PROJECT_STORAGE=project-env` before `install.sh`.

The chosen scope renders green when color is enabled and falls back to plain
brackets under `NO_COLOR=1` per [no-color.org](https://no-color.org).

### Defaults

Every catalog entry ships a `default_scope` field. Personal-tooling MCPs default
to `user`; per-app infra MCPs default to `project`:

```text
user (default):    firecrawl, notebooklm, notion, youtrack, context7,
                   openrouter, figma, playwright, magic, sentry, calendly
project (default): supabase, cloudflare, stripe, slack, resend,
                   aws-cost-explorer, aws-cloudwatch-logs, jira, linear, telegram
```

Override the default per-row before submit, or pass
`--mcp-scope=user|project|local` for a non-interactive force-set across all
rows in a single invocation.

### TUI hotkeys

| Key | Effect |
| --- | ------ |
| `Tab` (or `Shift-S`, see footer) | Cycle the **highlighted row's** scope: `U → P → L → U`. Other rows untouched. |
| `s` | Cycle a **global** scope value and apply it to **every visible row** in one stroke. Banner reads `s: set all to <scope>`. |
| `Space` | Toggle the row's checkbox (independent of the scope indicator). |

### Project scope: where the secrets land (v6.4 default — global-slot)

When you submit a `[P]` row, the wizard:

1. Computes a project slug from `basename($PWD)`: uppercases, replaces any
   non-alphanumeric character with `_`, prefixes a leading-digit name with
   `P_` so the result is a valid POSIX identifier. `my-app` → `MY_APP`;
   `123-foo` → `P_123_FOO`.
2. Prompts for each env-var with hidden input (`read -rs`, masked display,
   3 attempts).
3. Writes `KEY_<PROJECT_SLUG>=value` to `~/.claude/mcp-config.env` via
   `mcp_secrets_set` (mode 0600, dedup with collision prompt). The shell rc
   auto-source line installed at first toolkit install already loads this
   file into every shell, so a fresh `claude` launch picks up the new
   value without direnv.
4. Invokes `claude mcp add --scope project ...` with the env block in
   `${KEY_<SLUG>}` substitution form — never literal values. Result:
   `<project>/.mcp.json` carries the suffixed slot reference and is safe
   to commit.
5. SEC-05 defense-in-depth still applies: the rendered env block is
   validated against `^\$\{[A-Z_][A-Z0-9_]*\}$` BEFORE invoking claude;
   any literal value in the substitution position triggers
   `✗ refusing to write literal value` and rc=1.

### Legacy: project-env mode

Set `TK_MCP_PROJECT_STORAGE=project-env` to revert to v6.3 behavior:
secrets land in `<project>/.env` under their plain name, `.mcp.json`
references `${KEY}` (no suffix), and the wizard adds `.env` to
`<project>/.gitignore`. This path requires direnv/dotenv to source
`<project>/.env` before launching claude.

### `${VAR}` substitution in `.mcp.json`

The `.mcp.json` file lives **inside the project repository** and is checked into
version control. It must therefore never contain literal secrets. The toolkit
writes `env` blocks in `${VAR}` form:

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
      }
    }
  }
}
```

`claude` resolves the variable at MCP launch time from the environment.
`<project>/.env` is sourced into the shell before launching `claude` (or via a
`direnv`/`dotenv` flow you already use). The toolkit's
`project_secrets_render_mcp_env_block` helper produces this exact shape.

If any code path attempts to write a literal value into a `.mcp.json` env block,
the SEC-05 validator returns rc=1 with `✗ refusing to write literal value into
.mcp.json (use ${VAR} substitution)` to stderr. The
`TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam exists for hermetic tests only
and prints a one-line warning when honored.

### Worked example: user scope (Context7)

Personal docs-research MCP — install once, use everywhere:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --integrations
```

In the TUI:

1. Highlight the `context7` row (defaults to `[U]`).
2. Press `Space` to check it.
3. Press `Submit`.
4. The wizard prompts: `Enter CONTEXT7_API_KEY (input hidden):`
5. Paste the key from `context7.com/dashboard`.
6. The toolkit:
   - Writes `MCP_CONTEXT7_CONTEXT7_API_KEY=<your-key>` to
     `~/.claude/mcp-config.env` (mode 0600).
   - Adds `set -a; . ~/.claude/mcp-config.env; set +a` to your shell rc (once).
   - Runs `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp`.
7. Reload your shell (or open a new terminal). `context7` is now available in
   every Claude session, every project.

### Worked example: project scope (Supabase)

Per-app database MCP — wire into one repo, keep secrets in the project:

```bash
cd ~/projects/my-saas-app
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --integrations
```

In the TUI:

1. Highlight the `supabase` row (defaults to `[P]`).
2. Press `Space` to check it.
3. (Optional) Press `Tab` to flip the row to `[U]` if you'd rather keep the
   token in `mcp-config.env` and use Supabase across all projects.
4. Press `Submit`.
5. The wizard prompts: `Enter SUPABASE_ACCESS_TOKEN (input hidden):`
6. Paste the token from `supabase.com/dashboard/account/tokens`.
7. The toolkit:
   - Writes `SUPABASE_ACCESS_TOKEN=<your-token>` to `~/projects/my-saas-app/.env`
     (creates the file mode 0600 if absent; idempotent merge prompt on
     collision).
   - Appends `.env` to `~/projects/my-saas-app/.gitignore` if not already
     present (with leading toolkit comment).
   - Writes `~/projects/my-saas-app/.mcp.json` with the
     `"SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"` env block (literal
     value refused by SEC-05).
   - Runs `claude mcp add --scope project supabase -- npx -y @supabase/mcp-server-supabase`.
8. Source the project's `.env` before launching `claude` (or use `direnv`).
   Inside this repo, `supabase` is now available; outside it, it is not
   registered. Different repos can keep different Supabase tokens without
   collisions in `mcp-config.env`.

### Project `.env` is never touched by uninstall

`scripts/uninstall.sh` is an explicit contract: project `.env` files outside
`~/.claude/` are **never** opened or modified by the toolkit, regardless of
flags or prompts. The user's project owns its `.env`. See
[INSTALL.md → Uninstall](INSTALL.md#uninstall) for the full secret-cleanup
behavior, including the per-MCP `[y/N]` prompt and full-toolkit `[y/N]` prompt
that target only `~/.claude/mcp-config.env`.

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
