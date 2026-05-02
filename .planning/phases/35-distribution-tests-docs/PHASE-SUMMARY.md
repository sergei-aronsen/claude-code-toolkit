---
phase: 35
title: Distribution + Tests + Docs
status: complete
completed: 2026-05-02
plans: 4
req_ids: [DIST-01, DIST-02, TEST-01, TEST-02, TEST-03, TEST-04, DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05]
---

# Phase 35 Summary: Distribution + Tests + Docs

## One-liner

Closed v4.9 at code level: manifest 4.9.0 + version-align (Plan 35-01), three new hermetic test suites locking the v4.9 contract surface (Plan 35-02), `docs/INTEGRATIONS.md` with 20-entry table + Global-vs-per-project boundary (Plan 35-03), and INSTALL.md flag rows + README Killer Features bullet + CHANGELOG `[4.9.0]` consolidated entry (Plan 35-04).

## Plans executed (sequential on `main`)

| Plan | Title | REQ-IDs | Commit |
| ---- | ----- | ------- | ------ |
| 35-01 | Manifest 4.9.0 + version-align | DIST-01, DIST-02 | `17f3ace` |
| 35-02 | Three hermetic test suites + Makefile/CI wiring | TEST-01..04 | `dd5b486` |
| 35-03 | docs/INTEGRATIONS.md NEW + Global-vs-per-project boundary | DOCS-01, DOCS-02 | `235099e` |
| 35-04 | INSTALL.md flag rows + README + CHANGELOG (close) | DOCS-03..05 | this commit |

## Highlights per plan

### Plan 35-01 — Manifest + version-align

- `manifest.json` `version` already `4.9.0` from Phase 32 — re-verified, no change.
- `files.libs[]` already carries `cli-installer.sh` + `integrations-catalog.json` — re-verified.
- Added `scripts/validate-integrations-catalog.py` to `files.scripts[]`.
- Added `--version` / `-v` flag to `scripts/init-claude.sh` (parity with `init-local.sh`); derives from manifest at runtime, supports both local-clone and `curl | bash` invocation modes.

### Plan 35-02 — Three new hermetic test suites

| Test | PASS / floor | Coverage |
| ---- | ------------ | -------- |
| `test-integrations-catalog.sh` | 14 / 10 | catalog schema (count=20, 10 categories, required fields, unofficial set, no `sequential-thinking`, no sudo) |
| `test-cli-installer.sh` | 24 / 8 | `cli_detect` / `cli_install` / `cli_post_install_hint` primitives via `TK_CLI_UNAME` + `TK_CLI_BREW_BIN` seams |
| `test-integrations-tui.sh` | 36 / 15 | TUI redesign — categories, unofficial glyph, mocked claude flow, `unofficial_confirm` paths, mutex flags, summary table |

Wired into `Makefile` (Tests 45-47 + standalone targets) and `.github/workflows/quality.yml` (step `Tests 21-47`). All 4 baselines preserved (21 / 26 / 52 / 32).

### Plan 35-03 — docs/INTEGRATIONS.md

NEW 208-line reference doc:

- 10 H3 category sections × varying row counts = 20 MCP rows total
- Real package names sourced from `scripts/lib/integrations-catalog.json` (e.g. `@stripe/mcp` not `@stripe/mcp-server`)
- Install flow + flag reference + dry-run summary table mock-up
- Unofficial entries semantics + `[y/N]` confirm gate (default N, fail-closed; `--yes` does NOT bypass)
- Per-entry OAuth / env-var setup links (15 entries)
- Global vs per-project boundary (DOCS-02): toolkit installs globals only, never per-project SDKs; Layer × Where × Example reference table
- Troubleshooting: brew-absent, Linux no-brew/system-Node + no-sudo invariant, AWS shared CLI, post-install hints don't auto-execute, `--mcps` deprecation, MCP-registered-without-key recovery
- Adding new entries section with required fields + validator + test commands

### Plan 35-04 — Final close

- INSTALL.md gains 4 flag rows (`--integrations`, `--mcps`, `--mcp-only`, `--cli-only`)
- README.md gains 1 Killer Features bullet for Integrations Catalog
- CHANGELOG.md `[4.9.0]` extended with consolidated Integrations Catalog content (preserving prior install-UX-overhaul content from earlier work and all 22 prior version blocks)
- STATE.md status `ready_to_ship`, completed_phases 4, completed_plans 14, percent 100
- PROJECT.md Current State gains v4.9 shipped entry; Current Milestone marked shipped

## Final close gates

```text
make check                                       rc=0
markdownlint <all 4 modified docs>               rc=0
python3 scripts/validate-integrations-catalog.py rc=0  (20 entries × 10 categories)
bash scripts/init-claude.sh --version            "claude-code-toolkit v4.9.0"
bash scripts/init-local.sh --version             "claude-code-toolkit v4.9.0 (local)"

Tests (4 baselines + 3 new, all hermetic):
  test-mcp-selector             PASS=21
  test-bootstrap                PASS=26
  test-install-tui              PASS=52
  test-integrations-foundation  PASS=32
  test-integrations-catalog     PASS=14  (NEW)
  test-cli-installer            PASS=24  (NEW)
  test-integrations-tui         PASS=36  (NEW)
```

## Aggregate diff

- 5 files modified: `manifest.json`, `scripts/init-claude.sh`, `Makefile`, `.github/workflows/quality.yml`, `docs/INSTALL.md`, `README.md`, `CHANGELOG.md`, `.planning/STATE.md`, `.planning/PROJECT.md`
- 4 files NEW: `scripts/tests/test-integrations-catalog.sh`, `scripts/tests/test-cli-installer.sh`, `scripts/tests/test-integrations-tui.sh`, `docs/INTEGRATIONS.md`
- ~1700 lines added, ~5 lines removed (replacements only)

## Deviations across the phase

- **Plan 35-01:** Most of Tasks 1-2 already done by Phase 32 (manifest already at 4.9.0, libs already correct) — anticipated by CONTEXT D-08/D-10/D-11. Reduced to verification + validator-script registration + `init-claude.sh --version` add.
- **Plan 35-02 (Rule 1 bug):** Initial mock `claude mcp list` row format (`name: stdio command`) didn't match `is_mcp_installed`'s regex (`^name[[:space:]]`). Fixed mock to `name    stdio    URL`.
- **Plan 35-04 (Rule 1 bug):** Markdownlint MD004/MD032 in CHANGELOG migration paragraph (line started with `+ script`). Reflowed text.
- **Plan 35-04 (Plan-vs-reality alignment):** A `[4.9.0]` block already existed in CHANGELOG from prior UX-overhaul work. Extended the existing block instead of creating a duplicate (per orchestrator's "preserve all prior version blocks" reminder). All other version blocks unchanged.

## Acceptance criteria (phase-level)

- [x] All 4 plans executed sequentially with green baselines
- [x] manifest.json version 4.9.0
- [x] init-claude.sh + init-local.sh `--version` both print 4.9.0
- [x] python3 scripts/validate-integrations-catalog.py rc=0
- [x] All 4 baselines + 3 new tests green
- [x] make check rc=0
- [x] markdown lint clean on all new/modified docs
- [x] STATE.md status = ready_to_ship; completed_phases = 4; completed_plans = 14; percent = 100

## Self-Check: PASSED

All claims verifiable via the gate commands listed in "Final close gates" above.
