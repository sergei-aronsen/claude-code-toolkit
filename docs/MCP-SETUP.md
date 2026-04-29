# MCP Setup

`scripts/install.sh --mcps` opens a TUI catalog of nine curated MCP servers, prompts for
required API keys (hidden input via `read -rs`), persists them to `~/.claude/mcp-config.env`
(mode 0600), and runs `claude mcp add` to register each selected MCP with the local Claude
Code installation.

## Quick install

Interactive TUI catalog — browse and select MCPs with arrow keys and space:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --mcps
```

Non-interactive — install all non-OAuth MCPs without prompts:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --mcps --yes
```

Dry-run preview — show what would be installed without writing anything:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --mcps --dry-run
```

## The 9 curated MCPs

| Name | Description | Required env vars |
|------|-------------|-------------------|
| context7 | Up-to-date library docs (React, Next.js, Tailwind, etc.) | `CONTEXT7_API_KEY` |
| sentry | Error monitoring + issue triage | `SENTRY_AUTH_TOKEN` |
| sequential-thinking | Structured step-by-step reasoning (zero-config) | none |
| playwright | Browser automation + screenshot | none |
| notion | Workspace pages + databases (OAuth) | OAuth flow |
| magic | UI component generation (21st.dev) | `MAGIC_API_KEY` |
| firecrawl | Website scraping + crawling | `FIRECRAWL_API_KEY` |
| resend | Transactional email send | `RESEND_API_KEY` |
| openrouter | Multi-model LLM routing | `OPENROUTER_API_KEY` |

When `--yes` is passed, OAuth-only MCPs (notion) are skipped automatically because OAuth
requires an interactive browser flow that is incompatible with non-interactive mode. Pass
`--yes --force` to attempt those MCPs anyway and follow the CLI prompts manually.

## Configuration file

Secrets collected during the wizard live at `~/.claude/mcp-config.env`. The file is created
with mode 0600 (owner-read/write only), and that permission is re-asserted after every write.
The schema is plain `KEY=value` lines, one per line, with no quoting:

```text
CONTEXT7_API_KEY=ctx7_abc123
SENTRY_AUTH_TOKEN=sntrys_xyz789
FIRECRAWL_API_KEY=fc-abc456
```

When you re-run the wizard for a key that already exists in the file, the installer prompts:

```text
[y/N] Overwrite CONTEXT7_API_KEY?
```

The default answer is `N`, which preserves the existing value without any write. Answer `y`
to replace it.

### Plaintext-on-disk caveat

The file is plaintext on disk. Mode 0600 protects against reads by other OS users on
multi-user machines, but root processes and backup tooling (Time Machine, rsync, cloud
sync) can still read it. This is the same security posture as `~/.aws/credentials`,
`~/.npmrc`, and `~/.docker/config.json`. If your threat model requires stronger isolation,
follow the rotation recipe below.

## Rotating to a secret manager

1. Move your existing secrets aside:

   ```bash
   mv ~/.claude/mcp-config.env ~/mcp-config.env.bak
   ```

2. Configure your shell (`~/.zshrc` or `~/.bashrc`) to load secrets from a secret manager
   before invoking `claude`. Example using the 1Password CLI:

   ```bash
   export CONTEXT7_API_KEY=$(op read 'op://Personal/context7/api_key')
   export SENTRY_AUTH_TOKEN=$(op read 'op://Personal/sentry/auth_token')
   export FIRECRAWL_API_KEY=$(op read 'op://Personal/firecrawl/api_key')
   ```

3. Re-run `claude mcp add` with the env vars now live in your shell. Skip the toolkit wizard
   for those MCPs going forward — the env vars supply the secrets at runtime.

Automated wizard integration with secret managers is tracked as MCP-FUT-01 (registry in
`.planning/STATE.md`).

## Troubleshooting

- **"claude CLI not found"** — install Claude CLI from the Anthropic documentation and re-run.
  When the CLI is absent, `--mcps` renders the catalog read-only; selecting an MCP has no
  effect until the CLI is present.

- **OAuth flow failure** — Notion uses `claude mcp add`'s built-in OAuth flow. If the
  browser does not open automatically, copy the redirect URL printed in the terminal back
  to your browser manually.

- **mcp-config.env mode incorrect** — re-run the wizard; `mcp_secrets_set` re-asserts
  mode 0600 after every write, so a subsequent write corrects any permission drift.

- **is_mcp_installed reports installed but `claude mcp list` disagrees** — the toolkit
  parses the first column of `claude mcp list` output. File an issue if your local Claude
  version emits a different column order.
