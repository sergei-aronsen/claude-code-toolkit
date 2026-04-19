<!-- verified_upstream: 2026-04-18 -->

# Optional Plugins

The claude-code-toolkit complements four plugins you can install alongside it. TK does NOT
auto-install any of them — this document lists them for manual installation. All install
commands were verified against upstream on 2026-04-18; re-verify before referencing in new
code.

## rtk (rtk-ai/rtk)

RTK is a token-optimized CLI proxy that reduces Claude Code token consumption by 60-90% on
common dev commands (`git status`, `cargo test`, `ls`, `grep`). It installs as a shell hook
that transparently rewrites commands before they reach the Claude Code Bash tool.

**Install (macOS):**

```bash
brew install rtk
rtk init -g
```

**Config file locations:**

- macOS: `~/Library/Application Support/rtk/config.toml`
- Linux: `~/.config/rtk/config.toml`

### Known Issues

#### rtk ls returns (empty) on non-English locales — rtk-ai/rtk#1276 (open as of 2026-04-18)

Symptom: `rtk ls /tmp` prints `(empty)` even when the directory has files, if your system
locale is non-English (e.g., `LANG=es_ES.UTF-8`). Cause: `rtk ls` parses `ls -la` output
with an English-month regex; non-English locales emit localized month names that miss the
regex.

Upstream's intended fix is an internal `cmd.env("LC_ALL", "C")` patch in the Rust source
(NOT user-configurable). Track status at <https://github.com/rtk-ai/rtk/issues/1276>.

User-side workaround (add to your config.toml):

```toml
exclude_commands = ["ls"]
```

> **Note:** The workaround bypasses rtk's optimization for `ls`; the upstream fix preserves
> optimization. They are NOT the same — the workaround is a stopgap until the upstream patch
> lands.

### Relationship to cc-safety-net

The Claude Code Toolkit's `setup-security.sh` installs a combined PreToolUse hook that
sequences RTK and `cc-safety-net`. Both register against the same Claude Code hook event;
the combined hook ensures they run in the correct order without conflicting entries in
`~/.claude/settings.json`. See `templates/global/RTK.md` for additional detail.

## caveman (JuliusBrussee/caveman)

Caveman is a Claude Code plugin for token compression. According to the upstream README it
achieves ~46% input token reduction on average by rewriting your CLAUDE.md into compressed
form before sending it to the model.

**Install:**

```bash
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
```

**Language modes:** `en` + `wenyan` (Classical Chinese, 文言文). Note: the language set is
English and Classical Chinese — it does NOT include Russian or any other modern language.

**Intensity levels:**

- English: Lite / Full (default) / Ultra
- Wenyan: Wenyan-Lite / Wenyan-Full / Wenyan-Ultra

### Caveats

- `caveman-compress` auto-creates `CLAUDE.original.md` as a backup — no manual backup
  required before running compress.
- **WARNING: The auto-backup is single-generation.** Re-running `caveman-compress` OVERWRITES
  the prior `CLAUDE.original.md`. Commit your `CLAUDE.md` to git BEFORE running compress so
  you can diff or revert from version control; the auto-backup alone is not sufficient for
  iterative compression workflows.

## superpowers (obra/superpowers)

Superpowers ships a curated set of skills, an agent, and commands that layer cleanly on top
of Claude Code's base capabilities.

**Skills:** systematic-debugging, writing-plans, test-driven-development,
verification-before-completion, using-git-worktrees

**Also includes:** code-reviewer agent, additional commands.

**Install:**

```bash
claude plugin install superpowers@claude-plugins-official
```

> **Install string is locked.** This exact form matches the `enabledPlugins` key verified in
> `scripts/detect.sh:54` and `scripts/verify-install.sh:197-200`. Do not substitute a
> `marketplace add` variant — the detection path would not match.

**Relationship to TK:** v4.0 TK is explicitly designed around superpowers. In
`complement-sp` and `complement-full` install modes, TK skips 7 duplicate files (6
commands/skills + 1 agent) to avoid collisions.

## get-shit-done (gsd-build/get-shit-done)

GSD adds a phase-based workflow to Claude Code: `/gsd-plan-phase`, `/gsd-execute-phase`,
`/gsd-discuss-phase`, `/gsd-verify-work`, and related commands. It layers over TK's framework
templates rather than replacing them.

**Install:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)
```

> **Install string is locked.** GSD distributes via its own curl-install script; the
> filesystem detection path is `~/.claude/get-shit-done/` (see `scripts/detect.sh:29`). A
> `claude plugin marketplace add gsd-build/get-shit-done` form does not produce the same
> layout and would break detection.

**Relationship to TK:** GSD currently has zero file conflicts with TK (per `manifest.json`).
The `complement-gsd` install mode exists for future composability.

## Source of Truth

Upstream facts re-verified 2026-04-18. See header `verified_upstream:` marker. Before
authoring new docs that reference these plugins, re-verify via WebFetch or the upstream
README.

- rtk: <https://github.com/rtk-ai/rtk>
- caveman: <https://github.com/JuliusBrussee/caveman>
- superpowers: <https://github.com/obra/superpowers>
- get-shit-done: <https://github.com/gsd-build/get-shit-done>
