---
name: update-deps
description: Open the dependency update dashboard — shows installed vs latest versions for every tracked toolkit dependency (Layer 1/2/3) in an aligned table. User picks what to upgrade via a one-keystroke prompt (a/o/c/n) plus a comma-list custom mode. Manual control, no auto-update.
---

# /update-deps — Dependency Update Dashboard

## Purpose

`/update-toolkit` only refreshes the toolkit itself. `/update-deps` shows the
full picture — every dependency the toolkit composes with — and lets the user
manually pick which ones to upgrade.

User feedback (2026-05-06): "I want a table dashboard. Show installed vs
latest, let me pick what to upgrade. Manual, not automatic."

## Usage

```bash
bash scripts/update-deps.sh                  # table + interactive picker (default)
bash scripts/update-deps.sh --dry-run        # table only, exit 0
bash scripts/update-deps.sh --yes            # update every outdated dep, no prompt
bash scripts/update-deps.sh --check <name>   # probe a single dep, print TSV
```

## Output Format

```text
Claude Code Toolkit — Dependency Update Dashboard
Toolkit build date: 2026-05-06 · CC: 2.1.131 (Claude Code)

  DEP                INSTALLED      LATEST   STATUS
  ────────────────────────────────────────────────────────────────
  Toolkit
  toolkit            6.1.0          6.1.0    ✓ up-to-date  Run /update-toolkit inside Claude Code

  Bootstrap
  superpowers        5.1.0          —        ? rolling     Anthropic plugin marketplace
  get-shit-done      1.40.0         1.40.0   ✓ up-to-date  Standalone curl installer
  ru-text            1.4.0          —        ? rolling

  Optional
  caveman            c2ed24b3e5d4   —        ? rolling

  External
  cc-safety-net      0.7.1          0.8.2    ↑ update      PreToolUse danger blocker
  rtk                0.38.0         0.38.0   ✓ up-to-date  Token optimizer (brew)
  get-shit-done-cc   1.40.0         1.40.0   ✓ up-to-date  GSD SDK CLI helper

Update which?
  o = outdated only (default, 1 row)
  a = all rows (force-refresh)
  c = custom (comma-separated names)
  n = none, exit
Choice [o]:
```

### Status legend

- `↑ update` (yellow) — installed != latest, upgrade available
- `✓ up-to-date` (green) — installed == latest
- `? rolling` (dim) — no upstream version metadata; rolling-update upstream
  (e.g. plugin marketplaces don't yet expose latest tag via API)

### Pick keys

- `o` (default) — upgrade all rows currently flagged `↑ update`
- `a` — force-refresh every row, including up-to-date ones (useful for plugins
  marked `? rolling` where upstream may have advanced)
- `c` — type a comma-separated list of dep names (e.g. `cc-safety-net,rtk`)
- `n` — exit without changes

## What It Tracks

Every dep is registered via `register_dep` inside `scripts/update-deps.sh`.
Adding a new one = a `probe_*` returning `installed<TAB>latest`, an
`upgrade_*` running the actual command, and one `register_dep` line.

### Layer 1 — Toolkit

| Dep | Installed source | Latest source | Upgrade |
|-----|------------------|---------------|---------|
| toolkit | `manifest.json` `.version` | `gh api repos/sergei-aronsen/claude-code-toolkit/releases/latest` | hint to run `/update-toolkit` inside CC |

### Layer 2 — Free base plugins

| Dep | Installed | Latest | Upgrade |
|-----|-----------|--------|---------|
| superpowers | `claude plugin list --json` | (no public API → `—`) | `claude plugin update superpowers@claude-plugins-official` |
| get-shit-done | `~/.claude/get-shit-done/VERSION` | `gh api repos/gsd-build/get-shit-done/releases/latest` | curl install.sh |
| ru-text | `claude plugin list` | `—` | `claude plugin update` |

### Layer 3 — Optional / External

| Dep | Installed | Latest | Upgrade |
|-----|-----------|--------|---------|
| caveman | `claude plugin list` | `—` | `claude plugin update caveman@caveman` |
| cc-safety-net | `npm ls -g --json` | `npm view cc-safety-net version` | `npm install -g cc-safety-net@latest` |
| rtk | `rtk --version` | `brew info rtk --json` | `brew upgrade rtk` |
| serena | `uv tool list` | `pypi.org/pypi/serena-agent/json` | `uv tool upgrade serena-agent` |
| better-model | `npm ls -g` | `npm view` | `npm install -g better-model@latest` |
| get-shit-done-cc | `npm ls -g` | `npm view` | `npm install -g get-shit-done-cc@latest` |

### Intentionally NOT tracked

The four Anthropic-shipped helper plugins (`code-review`, `commit-commands`,
`security-guidance`, `frontend-design`) are intentionally excluded. They have
no public version metadata (rolling main-branch tracking, `claude plugin list`
reports `version: unknown`), and Claude Code refreshes them automatically on
plugin sync. Showing them in the dashboard would be noise.

A row is also auto-hidden when:

- The dep is not installed locally (`installed: ?` or `—`).
- `installed: unknown` (rolling-update with no version field).

## Caveats

1. **Plugin marketplaces have no public version-query API today.** Layer 2
   rows show `latest: —` and the `? rolling` status. To force-refresh anyway,
   pick `a` (all) or `c` (custom) and include the row name.
2. **`caveman` reports a commit SHA**, not a semver tag — same `? rolling`
   treatment.
3. **No semver comparison.** Equality check only — `1.10.0` vs `1.2.0` would
   show as `↑ update` (different strings). For the tracked deps this is
   acceptable since their tags are monotonic.
4. **Toolkit row** — its upgrade prints a hint and returns 0; the actual
   refresh happens via `/update-toolkit` from inside Claude Code.

## See Also

- `scripts/update-deps.sh` — the script
- `commands/update-toolkit.md` — `/update-toolkit` (toolkit-only smart update)
- `commands/vendor-audit.md` — `/vendor-audit` (quarterly maintainer-drift audit)
- `docs/dependency-map.md` — canonical source-of-truth dep list
