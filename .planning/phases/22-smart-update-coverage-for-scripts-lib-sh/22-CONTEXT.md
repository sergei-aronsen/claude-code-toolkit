# Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning
**Mode:** `--auto --chain` (Claude auto-selected recommended defaults)

<domain>
## Phase Boundary

Close the silent gap where `scripts/lib/*.sh` files (sourced helpers) live outside `manifest.json` and so are silently skipped by `scripts/update-claude.sh`. After this phase, every sourced lib file is refreshed on update with the same diff/backup/safe-write contract as top-level scripts. Scope is limited to: manifest registration, smart-update behaviour parity, hermetic regression test, version bump and CI mirror. NOT in scope: changes to lib API, refactoring lib internals, install-time changes to `init-claude.sh` / `init-local.sh` (those source from local repo, not `~/.claude/`).

</domain>

<decisions>
## Implementation Decisions

### Manifest Structure

- **D-01:** Introduce a new top-level array `files.libs[]` in `manifest.json` (parallel to existing `files.scripts[]`). Rationale: semantic split — `files.scripts[]` holds top-level entry points (`uninstall.sh`); `files.libs[]` holds sourced helpers (`scripts/lib/*.sh`). Matches the existing per-domain split (`agents`, `skills`, `commands`, `templates`, `components`, `scripts`). `update-claude.sh:266` and `:637` iterate `.files | to_entries[] | .value[] | .path` — any new top-level key under `files` is auto-discovered. Zero code changes to `update-claude.sh` for the iteration loop.

- **D-02:** Cover ALL six lib files: `backup.sh`, `bootstrap.sh` (added Phase 21), `dry-run-output.sh`, `install.sh`, `optional-plugins.sh` (added Phase 21), `state.sh`. Phase 22 REQ originally named four (LIB-01 was written before Phase 21 shipped). The two libs added in Phase 21 share the exact same gap symptom and must be covered by the same fix to keep `make check` honest. Treating "all sourced libs" as the unit of coverage avoids re-opening this work as a Phase 22.1 follow-up.

### Install Paths

- **D-03:** Mirror source layout — `scripts/lib/X.sh` installs to `~/.claude/scripts/lib/X.sh`. Identical to how `scripts/uninstall.sh` is registered (`files.scripts[].path = "scripts/uninstall.sh"`). `update-claude.sh` line 262 prepends `$CLAUDE_DIR/$path` literally, so no path translation needed. `scripts/uninstall.sh` already handles this layout via SHA256-classified safe-delete.

### Test Strategy

- **D-04:** Hermetic test `scripts/tests/test-update-libs.sh` (Test 29). Pattern: copy of `test-bootstrap.sh` / `test-uninstall.sh` shape — uses `TK_UPDATE_HOME` test seam (line 123 in `update-claude.sh`) to point at a temp `~/.claude/`. Scenarios:
  - **S1 — stale lib refreshed:** seed `$TK_UPDATE_HOME/.claude/scripts/lib/backup.sh` with a deliberately mutated copy (SHA differs from repo HEAD). Run `update-claude.sh`. Assert post-update SHA256 of installed file matches repo `scripts/lib/backup.sh` SHA256.
  - **S2 — clean lib left untouched:** seed identical-SHA lib, run update, assert no rewrite (stat mtime preserved).
  - **S3 — fresh install path:** start with no `lib/` dir, run update, assert all six lib files appear with correct SHA256.
  - **S4 — modified-file `[y/N/d]` prompt path:** mutate a lib file with user-flavoured changes, drive update via `TK_UPDATE_TTY_FROM_STDIN=1` (or equivalent existing seam), assert prompt fires and `N` keeps user copy intact.
  - **S5 — uninstall round-trip:** after install, run `uninstall.sh --dry-run`, assert all six lib files appear in `[- REMOVE]` group; run real uninstall, assert `lib/` dir gone.

  Test must be shellcheck-clean and exit non-zero on any assertion failure (same convention as existing 28 tests).

### Version & Release Surface

- **D-05:** Bump `manifest.json` `4.3.0` → `4.4.0`. Add `## [4.4.0]` section to `CHANGELOG.md` covering BOOTSTRAP-01..04 (Phase 21) + LIB-01..02 (this phase). `make version-align` (Makefile:225) gate enforces three-way match (manifest ↔ CHANGELOG top header ↔ `init-local.sh --version`). Single atomic bump per D-09.

### CI / Quality Gates

- **D-06:** Wire `make test-update-libs` (or extend Test 28 → Test 29 pattern) into `Makefile` Test 29 target. Extend `.github/workflows/quality.yml` step `Tests 21-28` → `Tests 21-29` and append `bash scripts/tests/test-update-libs.sh`. Mirrors the Phase 21 wiring exactly.

### Backward Compatibility

- **D-07:** No migration logic for users on STATE_JSON written before 4.4.0. `update-claude.sh:262` uses `if [[ -f "$CLAUDE_DIR/$path" ]]` guard — first update after 4.4.0 simply installs the new lib paths fresh and appends them to `installed_files[]`. Existing `synthesize_v3_state()` (line 256) already iterates `.files | to_entries[] | .value[]`, so it picks up the new section automatically for v3.x users mid-flight. Zero special-casing.

### Symmetric Uninstall Coverage

- **D-08:** Adding libs to `manifest.json` automatically extends `uninstall.sh` reach (it reads STATE_JSON paths). Verify in S5 of the new test that `uninstall.sh --dry-run` lists all six lib files in `[- REMOVE]` group, then real uninstall removes the `lib/` directory cleanly. No `is_protected_path` change needed (libs are toolkit-owned, not third-party).

### Claude's Discretion

- Exact file ordering inside `files.libs[]` array — alphabetical by basename (matches existing array conventions).
- Whether to include a `description:` field per lib entry (existing `files.scripts[]` does not; existing `inventory.components[]` does). Default: omit description for libs to keep manifest lean — descriptions live in lib file headers.
- TAB vs space indentation in new Makefile target — TAB (Make requirement, established convention).

### Folded Todos

None — no pending todos matched this phase scope at planning time.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Manifest & Update Loop
- `manifest.json` §`files.scripts` — analog structure for new `files.libs[]` (D-01)
- `scripts/update-claude.sh` lines 262-266 — install loop (`if [[ -f "$CLAUDE_DIR/$path" ]]`)
- `scripts/update-claude.sh` lines 637-638 — `MANIFEST_FILES_JSON` extraction
- `scripts/update-claude.sh` lines 256-269 — `synthesize_v3_state()` v3.x mid-flight handling
- `scripts/update-claude.sh` lines 280-300 — `compute_modified_actual()` SHA256 diff path
- `scripts/update-claude.sh` line 123 — `TK_UPDATE_HOME` test seam for hermetic tests

### Test Patterns
- `scripts/tests/test-bootstrap.sh` — closest analog: 5-scenario hermetic shape, env-var test seams, PASS/FAIL counter, shellcheck-clean
- `scripts/tests/test-uninstall.sh` — round-trip integration test (5 scenarios, 18 assertions); install→uninstall contract
- `scripts/tests/test-install-banner.sh` — source-grep gate pattern (3 assertions)

### Lib Files Under Coverage
- `scripts/lib/backup.sh` — list_backup_dirs / warn_if_too_many_backups
- `scripts/lib/bootstrap.sh` — bootstrap_base_plugins (Phase 21)
- `scripts/lib/dry-run-output.sh` — dro_init_colors / dro_print_header / dro_print_file / dro_print_total
- `scripts/lib/install.sh` — warn_version_skew + manifest helpers
- `scripts/lib/optional-plugins.sh` — TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD constants (Phase 21)
- `scripts/lib/state.sh` — write_state / state I/O

### Quality Gates
- `Makefile` lines 225-247 — `version-align` target (D-05)
- `Makefile` line 1 — `.PHONY` declarations (add `test-update-libs` if separate target)
- `Makefile` Test 28 block (around line 145) — closest analog for new Test 29 wiring
- `.github/workflows/quality.yml` — `Tests 21-28` step (Phase 21 wiring; rename + extend to `Tests 21-29`)

### Specs / Requirements
- `.planning/REQUIREMENTS.md` §`Smart-Update Coverage for scripts/lib/*.sh` — LIB-01, LIB-02 acceptance criteria
- `.planning/ROADMAP.md` §`Phase 22` — three success criteria

### Prior CONTEXT
- `.planning/phases/21-sp-gsd-bootstrap-installer/21-CONTEXT.md` — Phase 21 added 2 of the 6 covered libs; D-08/D-19 conventions (idempotency probes, test seams) carry forward

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/update-claude.sh` install loop already iterates `.files | to_entries[] | .value[] | .path` — adding `files.libs[]` requires zero changes to the loop.
- `synthesize_v3_state()` (line 256) — uses the same iteration; v3.x mid-flight upgraders get lib files synthesized into STATE_JSON automatically.
- `TK_UPDATE_HOME` test seam (line 123) — already exists; the new test reuses it identically to existing update-flow tests.
- `lib/state.sh::write_state` — handles STATE_JSON writes including `installed_files[]` appends; no extension needed.

### Established Patterns
- Manifest version bump pattern: 2-file atomic — `manifest.json .version` + `CHANGELOG.md ## [X.Y.Z]` header. Enforced by `make version-align`. Established in v4.0.
- Hermetic test pattern: `scripts/tests/test-*.sh` — env-var seams (`TK_*`), PASS/FAIL counter, scenario sub-functions, exit non-zero on any failure. Established by Phases 18, 20, 21.
- CI mirror pattern: every new test file gets a `bash scripts/tests/test-X.sh` line in `.github/workflows/quality.yml` `validate-templates` job. Established by Phase 20.

### Integration Points
- `manifest.json` — new top-level key `files.libs[]`. Alphabetical sort by basename.
- `Makefile` — new target `test-update-libs` OR inline into existing Test 29 block (consistent with Test 28 inline pattern).
- `.github/workflows/quality.yml` — extend existing step (do not add a new job — keeps CI matrix flat).
- `CHANGELOG.md` — new `## [4.4.0]` Added section consolidating Phase 21 + 22 changes.

</code_context>

<specifics>
## Specific Ideas

- Test 29 follows the exact shape of Test 28 (Phase 21 inline Makefile block, TAB-indented `@bash scripts/tests/...`).
- New manifest section name: `libs` (singular noun, matches `scripts`/`agents`/`skills` plural-naming style — wait: those are plural. Use `libs` plural for consistency).
- `CHANGELOG.md [4.4.0]` consolidates Phase 21 (BOOTSTRAP-01..04) and Phase 22 (LIB-01..02) into a single release entry, since Phase 21 has not been released yet.
- Test 29 must run AFTER Test 28 (bootstrap) — bootstrap test exercises the install path; lib coverage builds on top of an installed `lib/` dir.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 22 scope. Phase 23 already covers banner consistency (BANNER-01) and uninstall recovery (KEEP-01, KEEP-02). Future polish on lib registration UX (e.g., per-lib description in dry-run output) deferred to post-v4.4 ideation if user demand surfaces.

</deferred>

---

*Phase: 22-smart-update-coverage-for-scripts-lib-sh*
*Context gathered: 2026-04-27 (auto-selected via --auto --chain)*
