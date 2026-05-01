---
phase: 32
plan: "32-01"
subsystem: lib/integrations
tags: [schema, validator, cli-flags, deprecation]
requires:
  - scripts/lib/mcp-catalog.json (renamed away — pre-condition)
provides:
  - scripts/lib/integrations-catalog.json (schema_version=2, components.mcp)
  - scripts/validate-integrations-catalog.py (Python stdlib validator)
  - scripts/install.sh --integrations flag
affects:
  - scripts/lib/mcp.sh (jq paths under .components.mcp)
  - manifest.json (catalog file rename)
  - Makefile (validate-catalog target wired into check)
  - .github/workflows/quality.yml (validate-templates job runs validate-catalog)
tech-stack:
  added: []
  patterns:
    - "JSON schema upgrade with components.<type> namespace for future skill/plugin registries"
    - "Python stdlib validator (no jsonschema dep) — mirrors validate-commands.py pattern"
    - "Soft-deprecation flag alias with stderr warning (non-blocking until v6.0)"
key-files:
  created:
    - scripts/lib/integrations-catalog.json
    - scripts/validate-integrations-catalog.py
  modified:
    - scripts/lib/mcp.sh
    - scripts/install.sh
    - manifest.json
    - Makefile
    - .github/workflows/quality.yml
  deleted:
    - scripts/lib/mcp-catalog.json (renamed via git mv to integrations-catalog.json)
decisions:
  - "Schema v2 wraps existing entries inside components.mcp.<name> instead of flat root keys, leaving room for components.skills.<name> / components.plugins.<name> in future phases without another rename"
  - "POSIX env-var shape (^[A-Z_][A-Z0-9_]*$) is enforced in the catalog validator (defense in depth alongside mcp.sh:249)"
  - "--mcps deprecation prints to stderr only; flag still sets MCPS=1 internally (D-22/D-23 — non-blocking until v6.0)"
  - "Per D-13: validator NOT registered in manifest.json files.* this phase — deferred to Phase 35 to avoid update-claude.sh churn"
  - "Manifest entry updated for the catalog file rename only (required to keep validate-manifest.py disk-existence + drift checks green — Rule 3 blocking issue)"
metrics:
  completed: "2026-05-01"
  duration: "~25 min"
  tasks: 6
  files_changed: 8
  insertions: 395
  deletions: 92
---

# Phase 32 Plan 01: Schema Migration + Python Validator + `--mcps` Alias Summary

CAT-01..04 implemented atomically: catalog renamed and re-shaped under components.<type>, install.sh learns `--integrations` as the canonical flag with a deprecated `--mcps` alias, and a stdlib-only Python validator (`validate-integrations-catalog.py`) is wired into both `make check` and CI.

## REQ-IDs Validated

| REQ-ID | Description | Evidence |
|--------|-------------|----------|
| CAT-01 | Schema migration mcp-catalog.json → integrations-catalog.json with components.mcp namespace | `git mv` + 9-entry rewrite under components.mcp; `mcp_catalog_load` reads `.components.mcp[$n].*` |
| CAT-02 | `--integrations` CLI flag added to install.sh | `scripts/install.sh:88` `--integrations) MCPS=1; shift ;;` |
| CAT-03 | Python validator with stdlib only (no jsonschema) | `scripts/validate-integrations-catalog.py` (270 lines, 9 checks) |
| CAT-04 | `--mcps` retained as soft-deprecated alias | `scripts/install.sh:81-87` emits one-line stderr warning, still sets MCPS=1 |

## What Was Done

### Task 1 — Catalog rename + schema upgrade (CAT-01)

- `git mv scripts/lib/mcp-catalog.json scripts/lib/integrations-catalog.json`
- Rewrote JSON shape:
  - top-level: `schema_version: 2`, `categories: [...]`, `components: { mcp: { ... } }`
  - per-entry: added `category` field with these mappings:
    - context7 / firecrawl → `docs-research`
    - magic / openrouter / playwright / sequential-thinking → `dev-tools`
    - notion → `workspace`
    - resend → `email`
    - sentry → `monitoring`

### Task 2 — `mcp.sh` jq paths updated (CAT-01)

- Default catalog path basename: `mcp-catalog.json` → `integrations-catalog.json`
- All five per-entry jq queries rewired from `.[$n].FIELD` to `.components.mcp[$n].FIELD`
- Both top-level enumerations rewired from `keys | sort | .[]` to `.components.mcp | keys | sort | .[]`
- The ASCII-31 (US) byte inside `install_args` `join(...)` was preserved during the rewrite (verified via `xxd` per the lessons-learned audit principle).
- Public function names unchanged (`mcp_catalog_load`, `mcp_catalog_names`, `is_mcp_installed`, `mcp_wizard_run`) per D-25.

### Task 3 — `install.sh` flag wiring (CAT-02 / CAT-04)

- Added `--integrations) MCPS=1; shift ;;` as the new canonical flag.
- `--mcps` retained, prints `⚠ --mcps is deprecated; use --integrations (alias retained until v6.0)` to stderr, then sets `MCPS=1` and continues.
- Updated `--help` text to advertise both flags with a deprecation note on `--mcps`.
- Updated curl-pipe download URL + tmpfile basename to match the rename (`integrations-catalog-XXXXXX.json`).

### Task 4 — manifest.json catalog path (Rule 3 — blocking issue)

- Updated `files.libs[]` entry from `scripts/lib/mcp-catalog.json` to `scripts/lib/integrations-catalog.json`. Without this, `validate-manifest.py`'s disk-existence check (line 141) and the `scripts/lib/` drift check (lines 233-246) would both fail under `make check`. The validator binary itself is intentionally NOT in manifest yet (D-13: deferred to Phase 35).

### Task 5 — Python validator (CAT-03)

- New `scripts/validate-integrations-catalog.py` (Python 3.8+, stdlib only).
- 10 checks: schema_version equality, categories[] non-empty array of strings, components.mcp object presence and non-empty, per-entry required-key set, name self-reference invariant, category membership in top-level set, POSIX env-var key shape (`^[A-Z_][A-Z0-9_]*$`), install_args non-empty array of strings, requires_oauth boolean type, and (defensive) duplicate-key check.
- Mirrors `validate-commands.py` style: ASCII-only output, `fail()` helper, accumulates errors before exit.

### Task 6 — Makefile + CI wiring

- Added `.PHONY: validate-catalog` and chained the new target into `check`.
- New `validate-catalog` target invokes `python3 scripts/validate-integrations-catalog.py`.
- Added a CI step in `.github/workflows/quality.yml` `validate-templates` job that runs `make validate-catalog`.

## Verification Results

| Check | Result |
|-------|--------|
| `make check` (full local quality gate) | PASS, exit 0 |
| `make validate-catalog` (standalone target) | PASS — 9 entries / 5 categories |
| `python3 scripts/validate-integrations-catalog.py` | PASS, exit 0 |
| `python3 -m py_compile scripts/validate-integrations-catalog.py` | PASS |
| `bash -n scripts/install.sh` | PASS |
| `bash -n scripts/lib/mcp.sh` | PASS |
| `bash scripts/install.sh --mcps --help 2>&1 \| grep deprecat` | matches the new banner |
| `bash scripts/install.sh --integrations --help 2>&1 \| grep deprecat` | no match (silent) |
| `bash scripts/tests/test-mcp-selector.sh` | 21/21 assertions PASS |
| `bash scripts/tests/test-mcp-wizard.sh` | 14/14 assertions PASS |
| `bash scripts/tests/test-mcp-secrets.sh` | 11/11 assertions PASS |
| `bash scripts/tests/test-install-tui.sh` | 52/52 assertions PASS |
| `bash scripts/tests/test-install-banner.sh` | 7/7 assertions PASS |
| `bash scripts/tests/test-install-dispatch-h1.sh` | 6/6 assertions PASS |

Negative tests of the new validator confirmed it rejects:
- Wrong `schema_version` (e.g. `1`)
- Missing required entry key (e.g. `category`)
- Lowercase env var key (e.g. `bad_key_lowercase`)

The catalog file was correctly restored after each negative test cycle.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 — Blocking issue] manifest.json catalog path entry**
   - **Found during:** Task 4 (manifest disk-existence check would fail)
   - **Issue:** `manifest.json:251` referenced `scripts/lib/mcp-catalog.json`. After the `git mv`, `validate-manifest.py` (run as part of `make check` via `make validate`) would have failed both check 5 (path-exists) and the disk drift check (the new file would appear unmanifested).
   - **Fix:** Updated the single `files.libs[]` path entry from `scripts/lib/mcp-catalog.json` to `scripts/lib/integrations-catalog.json`. The validator binary `scripts/validate-integrations-catalog.py` is intentionally **NOT** registered in the manifest per D-13 (deferred to Phase 35).
   - **Files modified:** `manifest.json`
   - **Commit:** `d81f77c`

No other deviations. Plan executed exactly as written.

## Backwards Compatibility

- `--mcps` flag still works — sets `MCPS=1` exactly as before, only adds a one-line stderr warning. Targeted removal in v6.0 (per D-22/D-23 schedule).
- All existing MCP tests (selector, wizard, secrets) pass without modification — they use the public `mcp_catalog_load` / `mcp_secrets_set` API which is unchanged.
- `update-claude.sh` smart-update users will pick up the catalog rename automatically: the manifest now lists `scripts/lib/integrations-catalog.json` (new download); the old `scripts/lib/mcp-catalog.json` is deleted from disk by git rename and update-claude.sh's diff routine treats it as a removed manifest entry.

## Commits

| Hash | Message |
|------|---------|
| `d81f77c` | feat(32-01): integrations-catalog schema migration + validator + --mcps alias |

## Self-Check: PASSED

- [x] FOUND: scripts/lib/integrations-catalog.json
- [x] FOUND: scripts/validate-integrations-catalog.py
- [x] MISSING (intentional rename): scripts/lib/mcp-catalog.json
- [x] FOUND in git log: commit d81f77c
- [x] make check exits 0
- [x] All four self-tests in plan PASS
