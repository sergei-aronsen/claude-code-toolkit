# Multi-CLI Bridges

## Overview

Multi-CLI bridges let you run multiple agentic CLI tools — Gemini CLI, OpenAI
Codex CLI, and others — without maintaining duplicate context files by hand.
When a bridge is active, `CLAUDE.md` is the single canonical source; every
other CLI's context file is a plain copy regenerated automatically on each
`update-claude.sh` run.

The invariant: **edit only `CLAUDE.md`**. Bridges are always regenerable from
that source. No manual sync needed.

## Supported CLIs

| CLI | Bridge file | Detection |
|-----|------------|-----------|
| Gemini CLI | `GEMINI.md` | `command -v gemini` |
| OpenAI Codex CLI | `AGENTS.md` | `command -v codex` |

> **Note:** OpenAI Codex CLI reads `AGENTS.md` (the OpenAI standard for agent
> context files), NOT `CODEX.md`. The toolkit follows the upstream convention.
> Using `AGENTS.md` ensures compatibility with the Codex CLI's built-in lookup
> path without any extra configuration.

## How it Works

At install time, `init-claude.sh` / `init-local.sh` / `install.sh` detect
which CLIs are present. For each detected CLI, the installer offers to create
a bridge: a plain copy of `CLAUDE.md` with an auto-generated header banner
prepended.

The banner is byte-identical across all bridges:

```text
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
```

One blank line separates the banner from the copied content. Bridge file path
and SHA256 checksums of both the source and the bridge are recorded in
`~/.claude/toolkit-install.json` under a `bridges[]` array for drift
detection.

## Drift Handling

`update-claude.sh` reads `bridges[]` from `toolkit-install.json` and computes
fresh SHA256 checksums of the source `CLAUDE.md` and the bridge file on every
run. Three outcomes are possible:

- **`[~ UPDATE] GEMINI.md`** — `CLAUDE.md` changed, bridge is still clean
  (SHA matches recorded bridge checksum). Toolkit re-copies automatically and
  updates both checksums in state.

- **`[y/N/d]` prompt** — the bridge file itself was edited by the user (bridge
  SHA differs from recorded). Default `N` keeps the user's edits. `y`
  overwrites with the current `CLAUDE.md`. `d` shows a diff and re-prompts.
  This mirrors the v4.3 UN-03 `[y/N/d]` contract used for modified tracked
  files during uninstall.

- **`[? ORPHANED] GEMINI.md (CLAUDE.md missing)`** — source `CLAUDE.md` was
  deleted. Toolkit preserves the bridge as-is, logs the orphan state, and
  auto-flips `user_owned: true` so subsequent runs skip it silently.

## Opt-Out Mechanics

Three escape hatches are available:

**Skip all bridge prompts at install time:**

```bash
# Flag form
bash <(curl -sSL .../scripts/init-claude.sh) --no-bridges

# Environment variable equivalent
TK_NO_BRIDGES=1 bash <(curl -sSL .../scripts/init-claude.sh)
```

Both `init-claude.sh`, `init-local.sh`, and `install.sh` honour `--no-bridges`
and `TK_NO_BRIDGES=1`. This mirrors the `--no-bootstrap` / `TK_NO_BOOTSTRAP`
symmetry from v4.4.

**Break an existing bridge (stop syncing one target):**

```bash
update-claude.sh --break-bridge gemini
update-claude.sh --break-bridge codex
```

Sets `user_owned: true` for the named bridge in `toolkit-install.json`.
Subsequent `update-claude.sh` runs skip that bridge silently with a
`[- SKIP] GEMINI.md (--break-bridge)` log line.

**Restore a broken bridge (resume syncing):**

```bash
update-claude.sh --restore-bridge gemini
update-claude.sh --restore-bridge codex
```

Reverses `--break-bridge`: clears `user_owned`, so the next `update-claude.sh`
run re-syncs the bridge.

## Force-Create (Non-Interactive)

For CI pipelines or scripted installs that need bridges without interactive
prompts, use `--bridges <comma-separated-list>`:

```bash
# Create both bridges non-interactively
init-claude.sh --bridges gemini,codex

# Only the Gemini bridge
install.sh --bridges gemini

# Force-create + fail if a named CLI is absent
install.sh --bridges gemini --fail-fast
```

`--bridges` is available on `init-claude.sh`, `init-local.sh`, and `install.sh`.
Without `--fail-fast`: if a named CLI is not installed, the toolkit logs a
warning and continues. With `--fail-fast`: absent CLI exits 1.

## Why No Symlink

Plain copy was chosen over a symlink for three reasons:

- **Per-CLI customization** — a symlink would lock all CLIs to byte-identical
  content. A plain copy lets users tweak the bridge (e.g., remove
  Claude-specific notes) without breaking the original `CLAUDE.md`.
- **Future tone overlays** — v4.8 will explore lightweight branding
  substitution per CLI (BRIDGE-FUT-01). That layer requires a real file to
  modify; a symlink is incompatible.
- **Transparent SHA256 drift detection** — the toolkit computes checksums of
  both the source and the bridge independently. A symlink would always report
  zero drift, hiding user edits and making the `[y/N/d]` prompt impossible.

See also: REQUIREMENTS.md "Out of Scope" for the full symlink-rejection
rationale, and PROJECT.md "Key context".

## Uninstall

`uninstall.sh` includes all bridges from `toolkit-install.json::bridges[]` in
its file classification pass. Each bridge is routed through `classify_bridge_file`:
unmodified bridges land on `REMOVE_LIST` and are deleted automatically;
user-edited bridges (SHA mismatch) land on `MODIFIED_LIST` and trigger a
`[y/N/d]` prompt before removal. The `--keep-state` flag (v4.4 KEEP-01)
preserves the `bridges[]` entries alongside the rest of `toolkit-install.json`
when set, enabling safe re-run of a partial-uninstall session.

## Future Scope

**BRIDGE-FUT-01 (branding substitution, deferred to v4.8):** a minimal opt-in
whitelist replacement applied during copy — for example, `Claude Code` →
`Gemini CLI`, `~/.claude/` → `~/.gemini/`. Disabled by default because false
replacements are a real risk (e.g., the `claude` CLI command name should NOT
be substituted). Revisit if users report that Gemini or Codex is confused by
`Claude` references in the bridge file.

**BRIDGE-FUT-03 / BRIDGE-FUT-04 (Cursor and Aider, out of v4.7 scope):**
Cursor reads `.cursorrules` (single-line rules, not Markdown context) and
Aider reads `CONVENTIONS.md` — both use different file formats and conventions
from the Gemini/Codex bridge pattern. They are explicitly deferred and will
not be included in v4.7.
