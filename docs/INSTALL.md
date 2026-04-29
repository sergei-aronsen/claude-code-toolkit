# Install Matrix

This document lists the 13 cells of the v4.0 install matrix (12 mode×scenario cells + 1 translation-sync cell). Rows = 4 install modes;
columns = 3 scenarios (fresh install, upgrade from v3.x, re-run / idempotent behavior).
See the [README install section](../README.md#install-modes) for the entry-point overview.

---

## Modes Overview

v4.0 ships four install modes. The installer auto-detects which base plugins are present
and selects the appropriate mode; pass `--mode <name>` to override.

- **`standalone`** — no base plugins detected (or user override). All 54 TK files installed.
- **`complement-sp`** — `superpowers` (obra) detected, `get-shit-done` absent. 7 files skipped
  that duplicate SP functionality.
- **`complement-gsd`** — `get-shit-done` (gsd-build) detected, `superpowers` absent. Currently
  installs all 54 files (no GSD conflicts in manifest yet — see note below).
- **`complement-full`** — both `superpowers` and `get-shit-done` detected. Same 47 files as
  `complement-sp` (SP conflicts skipped; no GSD conflicts currently).

> **Note on `complement-gsd`:** This mode is currently functionally identical to `standalone`
> because no TK files have `conflicts_with: get-shit-done` in the current manifest. The mode
> exists to compose with `superpowers` into `complement-full` and to accommodate future GSD
> conflict entries. Documentation is explicit about this to avoid confusion.

---

## Install via marketplace

The toolkit ships a Claude Code plugin marketplace listing at the repository's
`.claude-plugin/marketplace.json`. Three sub-plugins are exposed:

| Sub-plugin | Reach | Content |
|------------|-------|---------|
| `tk-skills` | Desktop Code tab + terminal Code | 22 curated skills mirrored from skills.sh |
| `tk-commands` | Terminal Code only | 29 slash commands for Claude Code workflows |
| `tk-framework-rules` | Terminal Code only | 7 framework CLAUDE.md fragments (Laravel, Rails, Next.js, Node.js, Python, Go, base) |

Install all three via:

```text
/plugin marketplace add sergei-aronsen/claude-code-toolkit
```

This works in both Claude Desktop's Code tab and terminal Claude Code with plugin
support enabled. The marketplace channel is **equivalent** to curl-bash for terminal
Code users; for Desktop users it is the **only** install path.

### Claude Desktop users

Claude Desktop's Chat tab does not run the plugin runtime. The Code tab does and
has feature parity with terminal Code for skills, slash commands, MCPs, and rules.
See [CLAUDE_DESKTOP.md](CLAUDE_DESKTOP.md) for the full capability matrix.

---

## Installer Flags

Both `init-claude.sh` and `init-local.sh` accept the following flags. Run
`init-local.sh --help` for the full canonical list.

| Flag | Applies To | Effect |
|------|-----------|--------|
| `--dry-run` | `init-claude.sh`, `init-local.sh` | Show what would be installed without writing files |
| `--mode <name>` | `init-claude.sh`, `init-local.sh` | Override auto-detected install mode (`standalone`, `complement-sp`, `complement-gsd`, `complement-full`) |
| `--force` | `init-claude.sh`, `init-local.sh` | Re-install even if `toolkit-install.json` already exists |
| `--force-mode-change` | `init-claude.sh`, `init-local.sh` | Bypass the mode-change confirmation prompt |
| `--no-bootstrap` | `init-claude.sh`, `init-local.sh` | Skip the SP / GSD pre-install prompts. Equivalent env var: `TK_NO_BOOTSTRAP=1`. Use this in CI or scripted installs to keep behaviour identical to v4.3. |
| `--no-banner` | `init-claude.sh`, `init-local.sh` | Suppress the closing `To remove: bash <(curl …)` banner line. Equivalent env: `NO_BANNER=1`. Symmetric with `update-claude.sh` which already honoured this flag. |
| `--keep-state` | `scripts/uninstall.sh` | Preserve `toolkit-install.json` after uninstall, enabling re-run recovery after a partial-N session. Equivalent env: `TK_UNINSTALL_KEEP_STATE=1`. |
| `--no-bridges` | `init-claude.sh`, `init-local.sh`, `install.sh` | Skip all bridge prompts. Equivalent env: `TK_NO_BRIDGES=1`. Mirrors `--no-bootstrap` symmetry. |
| `--bridges <list>` | `init-claude.sh`, `init-local.sh`, `install.sh` | Force-create bridges for named CLIs (comma-separated, e.g. `gemini,codex`). Skips per-CLI prompt. With `--fail-fast`: absent CLI exits 1; otherwise warns and continues. |
| `--break-bridge <target>` | `update-claude.sh` | Flip `user_owned: true` for the named bridge target. Subsequent `update-claude.sh` runs skip that bridge silently. |
| `--restore-bridge <target>` | `update-claude.sh` | Reverse `--break-bridge`. Next `update-claude.sh` re-syncs the named bridge. |
| `--no-council` | `init-claude.sh` | Skip Supreme Council setup |

### `--no-bootstrap` (v4.4+)

By default, `init-claude.sh` and `init-local.sh` ask whether to install the two
base plugins they complement — `superpowers` and `get-shit-done` — before the
toolkit's own detection logic runs. Each prompt defaults to `N` and skipping is
silent. Pass `--no-bootstrap` (or set `TK_NO_BOOTSTRAP=1`) to suppress both
prompts entirely; downstream toolkit behaviour is byte-identical to v4.3.

The flag is non-interactive-friendly: when stdout is not a terminal (e.g. piped
install), the prompts already fail closed to `N` without `--no-bootstrap`. Use
the flag explicitly when you want to make the intent visible in CI logs.

### `--no-banner` (v4.4+)

Pass `--no-banner` (or set `NO_BANNER=1`) to suppress the closing
`To remove: bash <(curl …)` line that both installers print on success. Default behaviour
(flag absent, env unset) is byte-identical to v4.3. Use in CI pipelines or scripted
installs where the banner is redundant noise. Symmetric with `update-claude.sh`, which
has honoured this flag since v4.1 — Phase 23 closes the asymmetry gap.

### `--keep-state` for `uninstall.sh` (v4.4+)

Pass `--keep-state` (or set `TK_UNINSTALL_KEEP_STATE=1`) to preserve
`~/.claude/toolkit-install.json` after the uninstall run. This is a recovery flag
for partial-uninstall sessions: if you answered `N` to every modified-file prompt and
want to re-run the uninstaller to finish the job, the state file must still exist for
re-classification to work. A subsequent `uninstall.sh` run (with or without the flag)
proceeds normally — it is NOT a no-op, because the state file is present.

All other UN-01..UN-08 invariants stand: backup is still written to
`~/.claude-backup-pre-uninstall-<unix-ts>/`, the sentinel block is still stripped from
`~/.claude/CLAUDE.md`, and the base-plugin `diff -q` invariant still fires. The ONLY
behavioural delta is the LAST step (`rm -f $STATE_FILE`) — replaced with a `log_info`
message when `--keep-state` is set.

### Multi-CLI Bridges (v4.7+)

`init-claude.sh` and `init-local.sh` post-install (and `install.sh` via the unified
TUI) detect installed Gemini CLI and OpenAI Codex CLI binaries. For each detected CLI,
the installer offers to create a bridge file: `GEMINI.md` for Gemini, `AGENTS.md` for
OpenAI Codex (the OpenAI agent-context standard). Bridges are plain copies of
`CLAUDE.md` with an auto-generated header banner; `update-claude.sh` keeps them in
sync via SHA256 drift detection.

Pass `--no-bridges` (or set `TK_NO_BRIDGES=1`) to skip every bridge prompt; pass
`--bridges gemini,codex` (or any comma-separated subset) to force-create
non-interactively for CI / scripted installs. Use `update-claude.sh --break-bridge
<target>` to mark a bridge `user_owned: true` (skipped on subsequent updates) and
`--restore-bridge <target>` to undo.

See [docs/BRIDGES.md](BRIDGES.md) for the full multi-CLI bridge specification including
drift handling, the `[y/N/d]` prompt contract for user-edited bridges, and the
symlink-vs-copy rationale.

---

## install.sh (unified entry, v4.5+)

`scripts/install.sh` is the single entry point for the unified TUI installer flow
introduced in v4.5. It complements the per-component `init-claude.sh` /
`setup-security.sh` / `install-statusline.sh` URLs (which all continue to work
unchanged — BACKCOMPAT-01).

### Quick start

```bash
# Interactive — TUI checklist with arrow/space/enter navigation
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh)

# Non-interactive — install all uninstalled components in canonical order
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes

# Re-run everything regardless of detection
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install.sh) --yes --force
```

### Flags

| Flag | Effect |
|------|--------|
| `--yes` | Skip TUI; install all uninstalled components in canonical order (superpowers, get-shit-done, toolkit, security, rtk, statusline) |
| `--yes --force` | Skip TUI; re-run all components regardless of detection |
| `--dry-run` | Show what would run without invoking any installer |
| `--force` | Re-run already-installed components |
| `--fail-fast` | Stop on first component failure (default behaviour: continue-on-error) |
| `--no-color` | Disable ANSI output. Also honoured via `NO_COLOR` env per [no-color.org](https://no-color.org) |
| `--no-banner` | Suppress the closing `To remove: ...` banner line. Also honoured via `NO_BANNER=1` env |
| `--help` | Print usage and exit 0 |

### TUI controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move focus up/down |
| `space` | Toggle current item (already-installed items are immutable) |
| `enter` | Confirm selection |
| `q` or `Ctrl-C` | Cancel without installing |

After `enter`, a confirmation prompt asks `Install N component(s)? [y/N]` (default
`N` cancels). Already-installed components render as `[installed ✓]` and are
pre-unchecked; uninstalled components are pre-checked.

### --mcps flag

`scripts/install.sh --mcps` opens a separate TUI page listing nine curated MCP servers
(see [docs/MCP-SETUP.md](MCP-SETUP.md) for the full guide). Selecting an MCP triggers a
per-MCP wizard that prompts for required API keys with hidden input via `read -rs`, persists
them to `~/.claude/mcp-config.env` (mode 0600), and invokes `claude mcp add`.

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

When the `claude` CLI is not on `PATH`, `--mcps` prints a banner explaining that MCPs
cannot be installed and renders the catalog read-only — selecting MCPs has no effect.
Install the CLI first, then re-run.

The components page and the MCPs page are mutually exclusive within a single invocation.
To install components AND MCPs, run `install.sh` twice: once without `--mcps` for the
components checklist, and once with `--mcps` for the MCP catalog.

### --skills flag

Install curated skills from the toolkit's marketplace mirror.

```bash
# TUI mode — interactive 22-skill catalog with detect status
bash scripts/install.sh --skills

# Non-interactive — install all uninstalled skills (default-set)
bash scripts/install.sh --skills --yes

# Re-install (overwrite existing skills)
bash scripts/install.sh --skills --yes --force

# Dry-run preview (no filesystem writes)
bash scripts/install.sh --skills --yes --dry-run
```

Skills install to `~/.claude/skills/<name>/`. Skills are detected via directory
presence (`[ -d ~/.claude/skills/<name>/ ]`).

**Idempotent semantics:**

- Without `--force`: already-installed skills are skipped (status `skipped: already installed`).
- With `--force`: existing target directory is removed before re-copy.

**Failure handling:** A failed skill copy does not block the rest. Per-skill status
appears in the post-install summary as `installed ✓`, `skipped`, `would-install`,
or `failed (exit N)`.

**Removing a skill:** `rm -rf ~/.claude/skills/<name>` (no dedicated
`--skills-remove` flag — manual deletion is sufficient).

**Mirror provenance:** All 22 skills are sourced from upstream and committed to
`templates/skills-marketplace/` as a static snapshot. Re-sync via
`scripts/sync-skills-mirror.sh` (maintainer tool). See `docs/SKILLS-MIRROR.md`
for license + upstream URL per skill.

**Mutex with `--mcps`:** `--mcps` and `--skills` cannot be combined in the same
invocation. Run two separate commands.

### --skills-only flag

`--skills-only` redirects the install target so skills land at
`~/.claude/plugins/tk-skills/<name>/` (the Desktop plugin tree) instead of
`~/.claude/skills/<name>/`. Use this when you want the toolkit's skills
available in Claude Desktop's Code tab.

```bash
# Explicit Desktop install (works regardless of CLI presence)
bash scripts/install.sh --skills-only --yes
```

Auto-routing: when `claude` is not on PATH and no other page flag is passed,
`scripts/install.sh` automatically promotes to `--skills-only` mode and prints:

```text
! Claude CLI not detected — installing skills only.
  Skills available in Claude Desktop Code tab.
  See docs/CLAUDE_DESKTOP.md for full capability matrix.
```

This makes the installer Desktop-friendly out of the box. Pass any explicit
flag (`--mcps`, `--skills`, `--components`, `--yes`) to opt out of auto-routing.

### Backwards compatibility

All v4.4 flags on `init-claude.sh` (`--no-bootstrap`, `--no-banner`,
`TK_NO_BOOTSTRAP`, `NO_BANNER`) are preserved unchanged. The 26-assertion
`test-bootstrap.sh` regression test stays green throughout v4.5. Both entry
points coexist indefinitely; there is no deprecation schedule for
`init-claude.sh`.

When `/dev/tty` is unavailable (CI, piped install) and `--yes` is not passed,
`install.sh` exits 0 with a "no-TTY, run with `--yes` for non-interactive
install" message. This is the same fail-closed behaviour as v4.4 `bootstrap.sh`.

---

## Mode: standalone

| Scenario | Precondition | Command | Expected stdout headline | `toolkit-install.json` mode | Files landed vs skipped |
|----------|-------------|---------|--------------------------|----------------------------|------------------------|
| **Fresh install** | No SP, no GSD on disk (or `--mode standalone`). No prior TK install. | `bash <(curl -sSL .../scripts/init-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell standalone-fresh` | `[standalone] Installing 54 files...` | `standalone` | 54 installed, 0 skipped |
| **Upgrade from v3.x** | v3.x TK present; no `toolkit-install.json`; SP/GSD NOT detected. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell standalone-upgrade` | State synthesized from disk (`synthesized_from_filesystem: true`). No mode-switch offered. 4-group summary printed. Backup at `~/.claude-backup-<ts>-<pid>/`. | `standalone` | Manifest diff applied. New files installed, removed files confirmed. |
| **Re-run / idempotent** | Standalone TK installed; manifest unchanged. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell standalone-rerun` | `No-op — already up to date` | `standalone` (unchanged) | 0 changes. No backup written. |

---

## Mode: complement-sp

| Scenario | Precondition | Command | Expected stdout headline | `toolkit-install.json` mode | Files landed vs skipped |
|----------|-------------|---------|--------------------------|----------------------------|------------------------|
| **Fresh install** | `superpowers` present at `~/.claude/plugins/cache/.../superpowers/`. GSD absent. | `bash <(curl -sSL .../scripts/init-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-sp-fresh` | `[complement-sp] Installing 47 files, skipping 7 (SP conflicts)...` | `complement-sp` | 47 installed; 7 skipped: `agents/code-reviewer.md`, `commands/debug.md`, `commands/plan.md`, `commands/tdd.md`, `commands/verify.md`, `commands/worktree.md`, `skills/debugging/SKILL.md` |
| **Upgrade from v3.x** | v3.x TK on disk with SP/GSD duplicate files present. SP detected. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-sp-upgrade` | D-77 migrate hint fires (CYAN): `Run ./scripts/migrate-to-complement.sh to remove duplicate files.` User runs `migrate-to-complement.sh`: three-column hash diff shown, `cp -R` full backup to `~/.claude-backup-pre-migrate-<ts>/`, `[y/N/d]` per-file prompt. | `complement-sp` (after migration) | 7 SP-duplicate files removed (with confirmation); `toolkit-install.json` rewritten. |
| **Re-run / idempotent** | `complement-sp` state on disk; `migrate-to-complement.sh` re-run. | `bash <(curl -sSL .../scripts/migrate-to-complement.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-sp-rerun` | `Already migrated to complement-sp. Nothing to do.` | `complement-sp` (unchanged) | 0 changes. No backup. No prompts. |

---

## Mode: complement-gsd

| Scenario | Precondition | Command | Expected stdout headline | `toolkit-install.json` mode | Files landed vs skipped |
|----------|-------------|---------|--------------------------|----------------------------|------------------------|
| **Fresh install** | `get-shit-done` present at `~/.claude/get-shit-done/`. SP absent. | `bash <(curl -sSL .../scripts/init-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-gsd-fresh` | `[complement-gsd] Installing 54 files...` (no GSD conflicts) | `complement-gsd` | 54 installed, 0 skipped. `detected.gsd.present: true` recorded. |
| **Upgrade from v3.x** | v3.x TK on disk; GSD detected; SP NOT detected. No duplicate files to remove. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-gsd-upgrade` | State updated to `complement-gsd`. No migration hint (no duplicate files found). 4-group summary printed. | `complement-gsd` | No files removed. Manifest diff applied normally. |
| **Re-run / idempotent** | `complement-gsd` state; manifest unchanged. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-gsd-rerun` | `No-op — already up to date` | `complement-gsd` (unchanged) | 0 changes. `migrate-to-complement.sh` prints `No duplicate files found on disk. Nothing to migrate.` |

---

## Mode: complement-full

| Scenario | Precondition | Command | Expected stdout headline | `toolkit-install.json` mode | Files landed vs skipped |
|----------|-------------|---------|--------------------------|----------------------------|------------------------|
| **Fresh install** | Both SP and GSD present. | `bash <(curl -sSL .../scripts/init-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-full-fresh` | `[complement-full] Installing 47 files, skipping 7 (SP conflicts)...` | `complement-full` | Same 47 files as `complement-sp` (SP conflicts skipped; no GSD conflicts). Both `detected.superpowers.present` and `detected.gsd.present` recorded as `true`. |
| **Upgrade from v3.x** | v3.x TK on disk; both SP and GSD detected; SP-duplicate files present. | `bash <(curl -sSL .../scripts/update-claude.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-full-upgrade` | Same D-77 migrate hint as `complement-sp`. User runs `migrate-to-complement.sh`. | `complement-full` (after migration) | Same 7 SP duplicates removed (with confirmation). GSD detection recorded. |
| **Re-run / idempotent** | `complement-full` state; `migrate-to-complement.sh` re-run. | `bash <(curl -sSL .../scripts/migrate-to-complement.sh)` <br> Validate: `bash scripts/validate-release.sh --cell complement-full-rerun` | `Already migrated to complement-full. Nothing to do.` | `complement-full` (unchanged) | 0 changes. No backup. No prompts. |

---

## Migration from v3.x

Run `scripts/migrate-to-complement.sh` to migrate an existing v3.x TK install to a complement
mode. Safety invariants: full `cp -R` backup to `~/.claude-backup-pre-migrate-<unix-ts>/` before
any removal, three-column hash diff (TK template / on-disk copy / SP equivalent) shown per file,
`[y/N/d]` per-file prompt (`d` shows diff and re-prompts), idempotent (safe to re-run).

The script rewrites `toolkit-install.json` to the new mode on completion. If interrupted, re-run
is safe — already-removed files are detected as absent and skipped.

---

## Translation Sync Cell

The 13th install-matrix cell verifies that `docs/readme/*.md` translations
stay within ±20% of `README.md` line count (the `make translation-drift`
gate). Validate this cell directly:

```bash
bash scripts/validate-release.sh --cell translation-sync
```

Runs `make translation-drift` under a sandboxed `$HOME` and reports PASS/FAIL.
