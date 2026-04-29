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
