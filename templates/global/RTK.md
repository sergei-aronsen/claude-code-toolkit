# RTK — Toolkit Notes (Claude Code)

> Fallback notes when `rtk init -g` has not yet been run. If you installed rtk and ran
> `rtk init -g`, rtk's own `~/.claude/RTK.md` is authoritative. The Known Issues section
> below still applies regardless.

## What RTK Does

RTK is a CLI proxy that reduces Claude Code token consumption by 60-90% on common dev
commands (`git status`, `cargo test`, `ls`, `grep`). It installs as a shell hook that
transparently rewrites commands before they reach the Claude Code Bash tool, filtering
verbose output down to only the signal Claude needs.

## Quick Install

Install rtk and run the global init, which installs the shell hook and writes rtk's own
`~/.claude/RTK.md` (overwriting this fallback file).

```bash
brew install rtk
rtk init -g   # installs hook + real RTK.md (overwrites this fallback)
```

## Known Issues

### rtk ls returns (empty) on non-English locales — rtk-ai/rtk#1276 (open as of 2026-04)

**Symptom:** `rtk ls /tmp` prints `(empty)` even when the directory has files, if your
system locale is non-English (e.g., `LANG=es_ES.UTF-8`).

**Cause:** `rtk ls` parses `ls -la` output with an English-month regex; non-English locales
emit localized month names that miss the regex.

**User-side workaround** — add to your config file:

- macOS: `~/Library/Application Support/rtk/config.toml`
- Linux: `~/.config/rtk/config.toml`

```toml
exclude_commands = ["ls"]
```

**Upstream fix:** A one-line patch `cmd.env("LC_ALL", "C")` in the rtk Rust source. Track
status at <https://github.com/rtk-ai/rtk/issues/1276>.

> **Note:** The user-side workaround bypasses rtk's optimization for `ls` entirely;
> the upstream fix preserves the optimization. They are NOT the same — the workaround is a
> stopgap until the upstream patch lands.

## Relationship to Claude Code Safety Net

RTK and the `cc-safety-net` hook both register against the Claude Code PreToolUse event.
The Claude Code Toolkit's `setup-security.sh` installs a combined hook that sequences both
in the correct order. If you see duplicate rewrites or missed safety blocks, verify your
`~/.claude/settings.json` has the combined hook entry rather than two separate entries.
