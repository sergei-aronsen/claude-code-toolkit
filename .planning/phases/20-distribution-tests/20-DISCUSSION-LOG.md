# Phase 20 — Discussion Log

**Mode:** `/gsd-discuss-phase 20 --auto` (auto-resolved)
**Date:** 2026-04-26

## Auto-Selected Decisions

All gray areas resolved with recommended defaults. No interactive Q&A.

### Area 1 — Test Architecture (UN-08)

| # | Question | Auto-Selected | Alternatives Considered |
|---|----------|--------------|--------------------------|
| 1 | One mega test or 5 split tests? | One integration test (`scripts/tests/test-uninstall.sh`) with 5 scenario blocks | 5 separate scenario tests (rejected: duplicates fixture cost; existing 5 unit tests already own per-requirement slices) |
| 2 | Real installer or synthetic state? | Real `init-local.sh` round-trip into `/tmp/test-uninstall-roundtrip.XXXXXX` | Synthetic `toolkit-install.json` fabrication (rejected: doesn't prove install↔uninstall contract end-to-end) |
| 3 | Test slot in Makefile? | Test 24 (Test 21-23 already taken by Phase 18 unit tests) | Renumber existing (rejected: breaks history; CI expectations) |
| 4 | y/N/d coverage layout? | Three scenario blocks (S2/S3/S4) inside the same test file, each re-fixturing | Three separate test files (rejected: see Q1) |
| 5 | Banner test = same file or separate? | Separate `scripts/tests/test-install-banner.sh` (Test 25) — different concern | Fold into round-trip test (rejected: source-grep is fast but conceptually distinct) |

### Area 2 — Banner Placement (UN-07)

| # | Question | Auto-Selected | Alternatives Considered |
|---|----------|--------------|--------------------------|
| 1 | Where to inject the "To remove" line? | Single dedicated `echo` immediately before each installer's existing final line | Inside POST_INSTALL.md heredoc (rejected: only init-claude.sh has POST_INSTALL.md; not symmetric across 3 installers) |
| 2 | Identical wording or per-installer? | Identical (single grep target) | Per-installer customization (rejected: no value; multiplies test surface) |
| 3 | Add `--no-banner` flag to init-claude/init-local? | No (KISS — only update-claude.sh has it today) | Add to all 3 (deferred to v4.4 if demanded) |
| 4 | Honor existing `update-claude.sh --no-banner`? | Yes — gate the new echo behind `[[ ${NO_BANNER:-0} -eq 0 ]]` in update-claude.sh only | Always print (rejected: breaks existing flag contract) |
| 5 | Test mechanism? | Source-grep (no install, no network, deterministic) | Runtime stdout capture (rejected: adds /tmp churn without catching anything new) |

### Area 3 — manifest.json Schema (UN-07)

| # | Question | Auto-Selected | Alternatives Considered |
|---|----------|--------------|--------------------------|
| 1 | Where does `scripts/uninstall.sh` register? | New `files.scripts: [{path: "scripts/uninstall.sh"}]` array | Existing `files.commands` (rejected: schema mismatch — `commands/` are slash-commands, not shell scripts) |
| 2 | Register `scripts/lib/*.sh` too? | No — internal sourced helpers, not user entry points | Register all (deferred to v4.4 if `update-claude.sh` ever iterates `files.scripts`) |
| 3 | Bump version now? | `4.2.0 → 4.3.0` + `updated: "YYYY-MM-DD"` placeholder | Wait until milestone close (rejected: breaks `make check version-align` gate during phase) |
| 4 | Bump CHANGELOG + init-local.sh in same plan? | Yes — atomic version-align bump | Stagger (rejected: gate fails between commits) |

### Area 4 — CHANGELOG Entry (UN-07)

| # | Question | Auto-Selected | Alternatives Considered |
|---|----------|--------------|--------------------------|
| 1 | Single `[4.3.0]` entry or per-phase? | Single `[4.3.0]` Added section, one bullet per UN-01..UN-08 | Three sub-entries (Phase 18/19/20) (rejected: not the Keep-a-Changelog convention; user reads release notes, not phase logs) |
| 2 | Include Changed/Fixed sub-sections? | No — milestone is purely additive | Empty sub-sections (rejected: violates Keep-a-Changelog) |
| 3 | Ship-date placeholder format? | `YYYY-MM-DD` literal | Today's date (rejected: changes during phase iterations) |

### Area 5 — CI Integration

| # | Question | Auto-Selected | Alternatives Considered |
|---|----------|--------------|--------------------------|
| 1 | Add new step to quality.yml? | No — `make test` auto-picks Test 24 + Test 25 | New workflow step (rejected: duplicates execution) |
| 2 | New CI gate for banner check? | No — falls under existing `make test` | Dedicated `banner-check` job (rejected: same — no duplication needed) |

## Scope Creep Redirects

None — `--auto` mode does not surface user input. All decisions stayed inside Phase 20 boundary.

## Deferred Ideas Captured

- `--no-banner` flag for `init-claude.sh` / `init-local.sh` (v4.4)
- `scripts/lib/*.sh` manifest registration (v4.4 if smart-update grows scripts iteration)
- Banner localization (v4.5+)
- Selective uninstall flags (`--keep-state`, `--only X/`) (v4.4+, per Phase 19 D-05)

## Canonical Refs Accumulated

- `.planning/ROADMAP.md` §"Phase 20: Distribution + Tests"
- `.planning/REQUIREMENTS.md` §"Distribution" (UN-07, UN-08)
- `manifest.json` (current schema for `files.{agents,prompts,...}` arrays)
- `Makefile` §`version-align`, §`test`
- `CHANGELOG.md` `[4.2.0]` (template for `[4.3.0]`)
- `scripts/init-claude.sh` line ~904, `scripts/init-local.sh` line ~424, `scripts/update-claude.sh` ending
- `.github/workflows/quality.yml` `test-init-script` job
- `scripts/tests/test-uninstall-{dry-run,backup,prompt,idempotency,state-cleanup}.sh` (5 unit-test analogs)

## Result

Phase 20 has 16 locked decisions (D-01..D-16) covering test architecture, banner placement, manifest schema, CHANGELOG entry, and CI integration. Ready for `/gsd-plan-phase 20`.
