# Phase 35: Distribution + Tests + Docs — Context

**Gathered:** 2026-05-02
**Status:** Ready for planning
**Mode:** Auto-discuss

<domain>
## Phase Boundary

Ship v4.9 end-to-end:
- **Manifest 4.9.0** + `files.libs[]` cli-installer.sh + `files.libs[]` integrations-catalog.json (replacing mcp-catalog.json) + `files.scripts[]` validate-integrations-catalog.py
- **Version-align** — `init-claude.sh --version` + `init-local.sh --version` derive `4.9.0` from manifest at runtime (v4.3 D-22 contract)
- **Three hermetic test suites** (TEST-01..03) + Makefile + CI wiring (TEST-04)
- **Five docs deliverables** (DOCS-01..05): NEW `docs/INTEGRATIONS.md`, INSTALL.md flag rows, README Killer Features bullet, CHANGELOG `[4.9.0]` consolidated entry

REQ-IDs: DIST-01, DIST-02, TEST-01..04, DOCS-01..05 (11 of 36).

Mirrors v4.8 Phase 31 close-pattern: tests-first, then manifest, then docs-last.

</domain>

<decisions>
## Implementation Decisions

### Plan structure

- **D-01:** Plan 35-01: manifest 4.9.0 + version-align (DIST-01, DIST-02)
- **D-02:** Plan 35-02: 3 hermetic test suites + Makefile/CI wiring (TEST-01..04)
- **D-03:** Plan 35-03: NEW `docs/INTEGRATIONS.md` with 20-entry table + Global-vs-per-project boundary (DOCS-01, DOCS-02)
- **D-04:** Plan 35-04: INSTALL.md flags + README + CHANGELOG (DOCS-03..05) — milestone close

### Wave structure

- **D-05:** All 4 plans run sequentially. Most deltas are isolated to different files (manifest vs tests vs docs), but the order matters: manifest first (so tests can reference correct version), tests second, docs third+fourth.

### Manifest 4.9.0

- **D-06:** Bump `manifest.json` `version` 4.8.0 → 4.9.0.
- **D-07:** Replace `files.libs[]` entry `mcp-catalog.json` → `integrations-catalog.json`.
- **D-08:** `files.libs[]` already has `cli-installer.sh` (added by Phase 32 deviation). Verify present.
- **D-09:** Add `validate-integrations-catalog.py` to `files.scripts[]` array.
- **D-10:** Confirm `update-claude.sh` auto-discovers all three via existing v4.4 LIB-01 D-07 jq path — no script code changes.

### Version-align

- **D-11:** `init-claude.sh --version` already derives from manifest at runtime per v4.3 D-22. Verify.
- **D-12:** `init-local.sh --version` same. Verify.
- **D-13:** Catch any version drift via `scripts/cell-parity.sh` if relevant; if not, add a hermetic check.

### Tests

- **D-14:** TEST-01 (`test-integrations-catalog.sh`) — schema validation only. Hermetic. ≥10 assertions covering: total entry count = 20 (NOT 19, see Phase 33 SUMMARY math note), valid categories enum, every CLI block has `detect_cmd` + OS keys, every MCP block has `install_args`.
- **D-15:** TEST-02 (`test-cli-installer.sh`) — `cli_detect`/`cli_install`/`cli_post_install_hint` with mocks. ≥8 assertions covering: success/already-present/brew-absent/Windows-rejection/post-install hint.
- **D-16:** TEST-03 (`test-integrations-tui.sh`) — extends Phase 25 baseline. ≥15 NEW assertions on top of test-mcp-selector PASS=21. Covers: category headers render, unofficial confirm fires, --mcp-only skips CLI, --cli-only skips MCP, summary table shows per-component status. Some of this overlaps with test-integrations-foundation; coordinate to avoid duplicate assertion bookkeeping.
- **D-17:** Numbering — current state in `Makefile` after Phase 32 already has `Test 31` for `test-integrations-foundation`. Phase 35 adds Tests 32, 33, 34 (or whatever next free numbers). Update CI step name accordingly (e.g., `Tests 21-34`).

### Docs

- **D-18:** `docs/INTEGRATIONS.md` NEW. Sections: Overview, 20-entry catalog table grouped by category, install flow, `--mcp-only`/`--cli-only`, unofficial semantics, OAuth setup links, troubleshooting (missing brew, post-install hint), Global-vs-per-project boundary.
- **D-19:** Generate the 20-entry catalog table via small one-shot script `scripts/gen-integrations-table.py` IF this is faster than hand-writing. Otherwise hand-write — markdown table with 20 rows is manageable. Prefer hand-write for v4.9; revisit auto-gen in future phase.
- **D-20:** `docs/INSTALL.md` Installer Flags table gains 4 rows: `--integrations` (canonical), `--mcps` (deprecated alias), `--mcp-only`, `--cli-only`.
- **D-21:** `README.md` Killer Features grid gains 1 line: `🧰 Integrations Catalog — 20 MCP servers + 8 companion CLIs across 10 categories, install with one TUI`.
- **D-22:** `CHANGELOG.md [4.9.0]` consolidated entry. Sections: Added (CAT, CLI, TUI, INT-01..12 listed), Changed (EXIST-01, CAT-04 alias, schema migration), Removed (DROP-01 sequential-thinking).

### Final state checklist (close gates)

- **D-23:** All 4 baselines green: test-mcp-selector PASS=21, test-bootstrap PASS=26, test-install-tui PASS=43, test-integrations-foundation PASS=32.
- **D-24:** All 3 new tests green per their assertion floors.
- **D-25:** `make check` rc=0.
- **D-26:** `python3 scripts/validate-integrations-catalog.py` rc=0.
- **D-27:** `init-claude.sh --version` prints `4.9.0`.
- **D-28:** Markdown lint clean on all new docs.

### Claude's Discretion

- Exact assertion bookkeeping in TEST-03 to avoid duplication with test-integrations-foundation.
- Whether to auto-generate the catalog table in INTEGRATIONS.md or hand-write.
- Exact wording of Killer Features bullet (terse, factual).
- Layout of INTEGRATIONS.md table columns (entry / category / MCP-only? / CLI? / unofficial?).

</decisions>

<canonical_refs>
## Canonical References

### Milestone
- `.planning/PROJECT.md` § Current Milestone v4.9
- `.planning/REQUIREMENTS.md` — DIST-01..02, TEST-01..04, DOCS-01..05 verbatim
- `.planning/ROADMAP.md` Phase 35

### Phase 32-34 outputs (consolidated by Phase 35)
- `scripts/lib/integrations-catalog.json` (20 entries, Phase 33 final)
- `scripts/lib/cli-installer.sh` (Phase 32)
- `scripts/validate-integrations-catalog.py` (Phase 32)
- `scripts/lib/mcp.sh` (Phase 32 + Phase 34 extensions)
- `scripts/install.sh` (Phase 34 extensions)
- `scripts/tests/test-integrations-foundation.sh` (Phase 32 — 32 assertions)

### Reference patterns
- v4.8 Phase 31 close-pattern (tests + manifest + docs in one phase)
- v4.4 LIB-01 D-07 jq path
- v4.3 D-22 version-align contract
- v4.6 Phase 25 D-28 summary contract

### Existing test suites (must keep green)
- `scripts/tests/test-mcp-selector.sh` PASS=21
- `scripts/tests/test-bootstrap.sh` PASS=26
- `scripts/tests/test-install-tui.sh` PASS=43
- `scripts/tests/test-integrations-foundation.sh` PASS=32

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `manifest.json` schema with `files.libs[]`, `files.scripts[]` (v4.4 LIB-01 pattern)
- `scripts/cell-parity.sh` — release validation
- `scripts/validate-release.sh` — 13-cell validator
- Existing CHANGELOG.md `[4.8.0]` entry structure

### Established Patterns
- CHANGELOG uses Conventional Commits headings: Added, Changed, Removed, Fixed, Security
- INSTALL.md uses tables for flags
- README sections delimited by `<!-- BEGIN ... -->` markers (verify)
- Docs in `docs/` dir; lint via markdownlint

### Integration Points
- manifest.json bump triggers update-claude.sh smart-update for new files (auto-discover via jq path)
- CI `validate-templates` job runs `make check` + extra grep gates

</code_context>

<deferred>
## Deferred Ideas

- Auto-generated INTEGRATIONS.md catalog table — defer to Phase 36+ if hand-written drifts.
- Per-entry README links in catalog JSON (`docs_url` field) — Phase 36+.
- Tag `v4.9.0` — manual user action per CLAUDE.md "never push main" invariant. Phase 35 ends at ready-to-tag.

</deferred>

---

*Phase: 35-distribution-tests-docs*
*Context gathered: 2026-05-02*
