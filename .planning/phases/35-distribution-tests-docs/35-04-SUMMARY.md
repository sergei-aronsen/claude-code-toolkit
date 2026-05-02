---
phase: 35
plan: 35-04
title: INSTALL.md flag rows + README + CHANGELOG — milestone close
req_ids: [DOCS-03, DOCS-04, DOCS-05]
status: complete
completed: 2026-05-02
---

# Phase 35-04 Summary: INSTALL.md + README + CHANGELOG

## One-liner

Closed v4.9 docs surface — `docs/INSTALL.md` gains 4 new flag rows (`--integrations`, `--mcps` deprecated, `--mcp-only`, `--cli-only`), `README.md` Killer Features grid gains an Integrations Catalog bullet, `CHANGELOG.md [4.9.0]` extended with consolidated Integrations Catalog sections (Added/Changed/Removed/Migration notes) preserving all prior 4.9.0 UX-overhaul content.

## Changes

### `docs/INSTALL.md`

Added 4 rows to the Installer Flags table after `--bridges <list>`:

- `--integrations` (`install.sh`): open the Integrations Catalog TUI; cross-link to `INTEGRATIONS.md`
- `--mcps` (`install.sh`): DEPRECATED alias for `--integrations`
- `--mcp-only` (`install.sh`): MCP-only install when used with `--integrations`
- `--cli-only` (`install.sh`): CLI-only install; mutex with `--mcp-only`, exits rc=2 on conflict

### `README.md`

Added one row to the `## Killer Features` table:

```markdown
| **Integrations Catalog** | `--integrations` opens a TUI for 20 MCP servers + 8 companion CLIs across 10 categories (Backend, Payments, Workspace, Project Management, etc.). Per-component install with `--mcp-only` / `--cli-only`. See [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md) |
```

### `CHANGELOG.md`

Inserted comprehensive Integrations Catalog content into the existing `[4.9.0]` block (which already carried the install-UX overhaul from earlier work). Sections added:

- **Added — Integrations Catalog (Phases 32-35)** — describes the unified TUI page, 20 MCPs + 10 categories, 8 companion CLIs, per-component status detection, unofficial confirm gate, mutex flags, summary table.
- **Added — 12 new integrations (INT-01..12)** — itemizes new entries grouped by category.
- **Added — CLI installer library** — describes `cli_detect` / `cli_install` / `cli_post_install_hint` primitives and their boundaries (no sudo, brew-absent fallback, hint-stderr-only, never auto-runs auth flows).
- **Added — Schema validator + 3 hermetic test suites** — names the validator + Tests 45/46/47 with PASS counts.
- **Added — `docs/INTEGRATIONS.md`** — DOCS-01/02 reference.
- **Changed — Schema migration (CAT-01..03)** — `mcp-catalog.json` → `integrations-catalog.json` rename, schema_version 2, 8 surviving entries tagged with category.
- **Changed — `--mcps` flag deprecated** — alias retained until v6.0.
- **Changed — `manifest.json` 4.8.0 → 4.9.0** — new libs/scripts entries, smart-update auto-discovery via v4.4 LIB-01 D-07 jq path.
- **Changed — `init-claude.sh --version` parity** — DIST-02.
- **Removed — `sequential-thinking` (DROP-01)** — boundary preserved, no auto-uninstall.
- **Migration notes** — re-run `update-claude.sh` to pick up the new lib/script/JSON.

All 22 prior CHANGELOG version blocks ([4.8.0] back to [1.0.0]) preserved verbatim.

## Verification (final close gates)

```text
make check                                      rc=0
markdownlint docs/INSTALL.md README.md
  CHANGELOG.md docs/INTEGRATIONS.md             rc=0
python3 scripts/validate-integrations-catalog.py rc=0
                                                "PASSED (20 mcp entries
                                                checked across 10 categories)"
bash scripts/init-claude.sh --version            "claude-code-toolkit v4.9.0"
bash scripts/init-local.sh --version             "claude-code-toolkit v4.9.0 (local)"

Test results (4 baselines + 3 new):
  test-mcp-selector.sh                          PASS=21 FAIL=0
  test-bootstrap.sh                             PASS=26 FAIL=0
  test-install-tui.sh                           PASS=52 FAIL=0
  test-integrations-foundation.sh               PASS=32 FAIL=0
  test-integrations-catalog.sh                  PASS=14 FAIL=0  (NEW; floor 10)
  test-cli-installer.sh                         PASS=24 FAIL=0  (NEW; floor 8)
  test-integrations-tui.sh                      PASS=36 FAIL=0  (NEW; floor 15)
```

## Acceptance criteria

- [x] INSTALL.md has 4 new flag rows
- [x] README has Killer Features bullet
- [x] CHANGELOG `[4.9.0]` extended with Integrations Catalog content (preserving prior content)
- [x] All 4 baselines + 3 new tests green
- [x] `make check` rc=0
- [x] markdownlint clean
- [x] v4.9 ready to tag (manual user action per CLAUDE.md never-push-main invariant)

## Deviations

### Auto-fixed Issues

**1. [Rule 1 - Bug] Markdownlint MD004/MD032 in CHANGELOG migration paragraph**

- **Found during:** Task 4 (markdownlint sweep)
- **Issue:** Migration-notes paragraph wrapped onto a line starting with `+ script + JSON catalog.` — markdownlint parsed `+ script` as a list-item marker, triggering MD004 (ul-style: expected dash) and MD032 (blanks around lists).
- **Fix:** Reflowed the paragraph to `the new lib, script, and JSON catalog` so no line starts with `+`.
- **Files modified:** `CHANGELOG.md`
- **Commit:** captured in this plan's commit.

### Plan-vs-reality alignment

The plan template said *"Above existing `[4.8.0]`, add..."*. Reality: a `[4.9.0]` block already existed (from earlier UX-overhaul work captured by the user's prior workflow). Per the orchestrator's reminder *"preserve all prior version blocks; insert above [4.8.0]"*, I extended the existing `[4.9.0]` block rather than creating a duplicate — the integrations catalog content lives at the top of `[4.9.0]` followed by the prior install-UX-overhaul content. All other version blocks unchanged.

## Files changed

- `docs/INSTALL.md` (+4 rows in Installer Flags table)
- `README.md` (+1 row in Killer Features table)
- `CHANGELOG.md` (+~120 lines under `[4.9.0]` for Integrations Catalog sections)
- `.planning/STATE.md` (frontmatter + Current Position updated to ready_to_ship)
- `.planning/PROJECT.md` (Current State adds v4.9 entry; Current Milestone marked shipped)

## Commit

`docs(35-04): INSTALL.md flag rows + README Killer Features + CHANGELOG [4.9.0] integrations`

## Self-Check: PASSED

- All 4 modified files have intended changes
- `make check` rc=0
- markdownlint rc=0 across all 4 docs
- All 7 tests green
- `init-claude.sh --version` and `init-local.sh --version` both print 4.9.0
- validator rc=0 with 20-entry confirmation
