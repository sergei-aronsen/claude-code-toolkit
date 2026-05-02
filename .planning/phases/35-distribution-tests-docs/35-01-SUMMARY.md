---
phase: 35
plan: 35-01
title: Manifest 4.9.0 + version-align
req_ids: [DIST-01, DIST-02]
status: complete
completed: 2026-05-02
---

# Phase 35-01 Summary: Manifest 4.9.0 + version-align

## One-liner

Registered `validate-integrations-catalog.py` in `manifest.json` `files.scripts[]` and added `--version` / `-v` flag to `scripts/init-claude.sh` (parity with `init-local.sh` v4.3 D-22 contract).

## State at start

- `manifest.json` `version` already at `4.9.0` (set by Phase 32)
- `files.libs[]` already contained `cli-installer.sh` and `integrations-catalog.json` (Phase 32-33)
- `mcp-catalog.json` already removed from `files.libs[]` (Phase 32 deviation)
- `init-local.sh --version` already worked correctly (printed `4.9.0`)
- `init-claude.sh` had no `--version` handling — `bash scripts/init-claude.sh --version` failed with `Unknown argument`

## Changes

### `manifest.json`

- Added `scripts/validate-integrations-catalog.py` to `files.scripts[]` (alphabetically sorted between `uninstall.sh` and `validate-marketplace.sh`).
- Re-encoded with `ensure_ascii=False` to preserve original Unicode glyphs (📌, 🛡️, 🏗️, etc.) under `claude_md_sections` and the `sp_equivalent_note` / `mode_notes` strings.

### `scripts/init-claude.sh`

- Added `--version` / `-v` flag handler before all other case branches so it short-circuits before any download work.
- Resolution order: local manifest (when run from a checked-out repo) → curl `$REPO_URL/manifest.json` (when run via `curl | bash`).
- Uses `jq` if available, falls back to `grep -m1 '"version"' | sed`.
- Updated unknown-arg help text to list `--version`.

## Verification

```text
$ bash scripts/init-claude.sh --version
claude-code-toolkit v4.9.0

$ bash scripts/init-local.sh --version
claude-code-toolkit v4.9.0 (local)

$ bash scripts/init-claude.sh -v
claude-code-toolkit v4.9.0

$ python3 -c "import json; json.load(open('manifest.json'))"
(no error)

$ python3 scripts/validate-integrations-catalog.py
integrations-catalog.json validation PASSED (20 mcp entries checked across 10 categories)

$ make check
All checks passed!
```

`version-align` Makefile target (manifest.json ↔ CHANGELOG.md ↔ init-local.sh `--version`) green at `4.9.0`.

## Acceptance criteria

- [x] manifest.json version = 4.9.0 (already set by Phase 32; preserved)
- [x] files.libs[] correct (integrations-catalog.json, cli-installer.sh present; mcp-catalog.json absent)
- [x] files.scripts[] includes validate-integrations-catalog.py
- [x] `init-claude.sh --version` → `4.9.0`
- [x] `init-local.sh --version` → `4.9.0`
- [x] `make check` rc=0

## Deviations

None. Plan 35-01 executed exactly as written; the only nuance was that Tasks 1-2 were already done by Phase 32 (manifest already at 4.9.0 with renamed catalog and cli-installer.sh) so they reduced to verification only — anticipated by D-08 / D-10 / D-11 in CONTEXT.md.

## Files changed

- `manifest.json` (+3 lines for scripts entry)
- `scripts/init-claude.sh` (+22 -1, `--version` flag handler)

## Commit

`chore(35-01): bump manifest to 4.9.0 + register integrations-catalog + validator`

## Self-Check: PASSED

- `manifest.json` validates as JSON
- `bash scripts/init-claude.sh --version` exits 0 printing `claude-code-toolkit v4.9.0`
- `bash scripts/init-local.sh --version` exits 0 printing `claude-code-toolkit v4.9.0 (local)`
- `python3 scripts/validate-integrations-catalog.py` exits 0
- `make check` exits 0
