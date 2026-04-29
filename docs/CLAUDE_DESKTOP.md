# Claude Desktop Capability Matrix

Plugins are a Claude Code feature. Some Code surfaces also exist in Claude
Desktop, others do not. This page tells you which toolkit capabilities are
available where, so you can decide what to install.

## Capability Matrix

| Capability | Desktop Code Tab | Desktop Chat Tab | Code Terminal |
|------------|:----------------:|:----------------:|:-------------:|
| Skills (`tk-skills`) | available | unavailable | available |
| Slash commands (`tk-commands`) | available | unavailable | available |
| MCPs (Model Context Protocol servers) | available | unavailable | available |
| Statusline (rate-limit + token usage) | unavailable | unavailable | available |
| Security pack (`cc-safety-net` + hooks) | unavailable | unavailable | available |
| Framework CLAUDE.md rules (`tk-framework-rules`) | available | unavailable | available |

Verdicts: **available** = works on this surface, **unavailable** = blocked by
the platform.

## Why the Chat Tab Has No Plugins

Claude Desktop's Chat tab does not run the plugin runtime. There is no
mechanism in the chat interface to load skills, commands, MCPs, or any other
plugin-system capability. This is a platform limitation set by Anthropic, not
something a marketplace listing can change.

The Desktop **Code** tab (the IDE-style surface) does run the plugin runtime
and reaches feature parity with terminal Claude Code for skills, slash
commands, MCPs, and rules.

## Why Remote Code Sessions Block Plugins

Cloud-hosted Claude Code sessions (the ones spawned from a browser, not from
your local terminal) explicitly block plugin loading per Anthropic's
documentation. Plugins run only on local Code sessions — terminal or Desktop
Code tab. This is also a platform constraint.

## Install Via Marketplace

Marketplace is the **only** way to install plugins on Claude Desktop. The
local-directory shortcut `/plugin marketplace add ./some-dir` does **not**
work in Desktop — only the upstream marketplace identifier resolves.

Open Claude Desktop, switch to the Code tab, and run:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

You will see three sub-plugins:

- `tk-skills` — 22 curated skills (Desktop-compatible)
- `tk-commands` — 29 slash commands (Code-only; appears greyed out on Chat tab)
- `tk-framework-rules` — 7 framework CLAUDE.md fragments (Code-only)

Pick `tk-skills` for the Desktop Code tab. The other two are visible but only
take effect in terminal Code sessions.

## Install Via Curl-Bash (Code Terminal Users)

If you run Claude Code in your terminal, the legacy curl-bash install is
equivalent to the marketplace install for the toolkit's content:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)
```

Choose the channel that matches your environment. Both work for terminal Code
users; marketplace is the only path for Desktop users.

## Skills-Only Auto-Route

If you run `scripts/install.sh` on a system without the `claude` CLI on PATH
(for example, a Desktop-only workstation), the installer auto-routes to
`--skills-only` mode and places skills under
`~/.claude/plugins/tk-skills/<name>/` so Claude Desktop's plugin runtime
discovers them. You will see a one-line banner explaining the routing.

## Limitations and Future Work

- **Statusline + security pack** are macOS Keychain / shell-hook based —
  there is no Desktop equivalent surface today.
- **Cross-platform Desktop reach beyond skills** (MCPs, statusline, etc.)
  needs Anthropic plugin-runtime expansion. Tracked as deferred.
- **Upstream registry submission** of `claude-code-toolkit` to the central
  Anthropic marketplace is a manual maintainer task post-merge.

## Related

- `docs/INSTALL.md` — full install matrix and flag reference
- `README.md` — install commands and feature overview
- `.claude-plugin/marketplace.json` — repo-side marketplace manifest
- `plugins/tk-skills/` — Desktop-compatible sub-plugin tree
