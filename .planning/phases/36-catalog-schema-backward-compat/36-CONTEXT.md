# Phase 36: Catalog Schema + Backward Compat - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning
**Mode:** Auto-resolved (foundation phase — decisions locked in REQUIREMENTS.md)

<domain>
## Phase Boundary

Add `default_scope: "user"|"project"` field to every MCP entry in `scripts/lib/integrations-catalog.json`, enforce the field in `scripts/validate-integrations-catalog.py`, and add a silent backward-compat fallback in `mcp_catalog_load` (`scripts/lib/mcp.sh`) so pre-v5.0 catalogs continue to work. Foundation phase — every downstream phase reads `default_scope`. Backward-compat fallback ships in the same plan as the schema field so there is never a window where the catalog has the field but the loader does not tolerate its absence.

</domain>

<decisions>
## Implementation Decisions

### Schema (SCOPE-01)
- **D-01:** Add `default_scope` field to every `components.mcp.<name>` block in `integrations-catalog.json`.
- **D-02:** Enum: `"user"` or `"project"` only. No third value, no nullable, no default at validator level.
- **D-03:** CLI-only entries (no MCP block) untouched — no scope concept for `command -v` checks.
- **D-04:** Validator (`scripts/validate-integrations-catalog.py`) fails loudly when an MCP entry lacks `default_scope` or carries an invalid enum value.
- **D-05:** `make check` invokes the validator and fails the build on schema violations (existing wiring — no new make target needed).

### Default-scope assignments (SCOPE-02)
- **D-06:** Personal-tooling MCPs default `user`: `firecrawl`, `notebooklm`, `notion`, `youtrack`, `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`.
- **D-07:** Per-app infra MCPs default `project`: `supabase`, `cloudflare`, `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `jira`, `linear`, `telegram`.
- **D-08:** Calendly is NOT added in this phase (lands in Phase 40 alongside uninstall work). Phase 36 only seeds defaults for catalog entries that already exist.

### Backward-compat fallback (SCOPE-03)
- **D-09:** `mcp_catalog_load` in `scripts/lib/mcp.sh` treats a missing `default_scope` as `"user"` and emits NO warning on stderr.
- **D-10:** Fallback ships in the SAME plan/commit as the schema field — no intermediate window where the loader is stricter than the catalog.
- **D-11:** Fallback is silent intentionally — pre-v5.0 user installs that re-source an old catalog must not surface noise.

### Test contract
- **D-12:** Existing v4.9 baselines must stay green: `test-mcp-selector.sh` PASS=21, `test-integrations-catalog.sh` PASS≥10.
- **D-13:** Validator gets a new SCOPE-01 assertion (TEST-06) — extends the existing `validate-integrations-catalog.py`, no new file. Negative test: synthetic catalog missing `default_scope` → validator fails.
- **D-14:** Backward-compat assertion: synthetic catalog where one MCP omits `default_scope` → `mcp_catalog_load` succeeds, treats entry as `user`, no stderr emission. Implemented as a hermetic test (new or extension of existing — planning decides).

### Claude's Discretion
- Validator implementation detail (jsonschema-lite vs hand-rolled jq vs Python dict walk) — pick the simplest that fits existing validator style.
- Fallback implementation in `mcp_catalog_load` (jq `// "user"` vs explicit branch) — match existing patterns in the file.
- Whether the backward-compat hermetic test extends `test-integrations-catalog.sh` or lands as `test-catalog-scope-fallback.sh` — pick whichever keeps assertions discoverable.
- Internal helper naming for the validator's enum check.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §"Catalog schema (`scripts/lib/integrations-catalog.json` + validator)" — SCOPE-01, SCOPE-02, SCOPE-03 acceptance criteria
- `.planning/REQUIREMENTS.md` §"Tests (`scripts/tests/`)" — TEST-06 catalog-validator assertion

### Existing code (read before editing)
- `scripts/lib/integrations-catalog.json` — current MCP entries to seed `default_scope` on
- `scripts/validate-integrations-catalog.py` — current schema enforcement (extend, do not duplicate)
- `scripts/lib/mcp.sh` — `mcp_catalog_load` function is the fallback site
- `scripts/tests/test-mcp-selector.sh` — must stay PASS=21
- `scripts/tests/test-integrations-catalog.sh` — must stay PASS≥10
- `Makefile` — `make check` wiring (validator already invoked here per v4.9 — verify, do not duplicate)

### Project conventions
- `.planning/codebase/CONVENTIONS.md` — bash/JSON/Python style, hermetic test patterns
- `.planning/codebase/STACK.md` — Bash 3.2 compat, `set -euo pipefail`, BSD vs GNU caveats
- `.planning/PROJECT.md` — toolkit non-negotiables (POSIX shell, no Node/Python runtime dependency for installers, idempotent installs)
- `CLAUDE.md` (project root) — quality gate (`make check`), commit conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/validate-integrations-catalog.py` — existing JSON schema enforcer; extend in place per D-13.
- `scripts/lib/mcp.sh::mcp_catalog_load` — existing catalog loader; add fallback per D-09.
- `scripts/tests/test-integrations-catalog.sh` — existing hermetic test harness; extend or sibling per D-14.
- `Makefile` `check` target — already invokes the validator (v4.9 wiring); no new target.

### Established Patterns
- Validator pattern: Python 3.8+, no pip deps, walks `components.mcp.*` keys, prints errors with file+key path on failure.
- Fallback pattern in `mcp.sh`: jq-based reads with `// default` for missing fields (verify in source — match the prevailing form).
- Hermetic test pattern: `set -euo pipefail`, synthetic JSON in temp dir, assertion counter, exit non-zero on PASS count drop.
- JSON edits: 2-space indent, trailing newline, no comments (jq-canonical).

### Integration Points
- Phase 37 (`scripts/lib/project-secrets.sh`) consumes nothing from this phase directly — scope-agnostic library.
- Phase 38 (`mcp_wizard_run`) reads `default_scope` from the catalog via `mcp_catalog_load` — depends on D-09 fallback semantics.
- Phase 39 (TUI) initializes `MCP_SELECTED_SCOPE[]` from `default_scope` at TUI launch via `mcp_status_array` — depends on the field being present and a known enum.
- Phase 40 (Calendly entry) extends the catalog with a new MCP that already carries `default_scope` from day one.

</code_context>

<specifics>
## Specific Ideas

- "Backward-compat fallback ships in the same plan as the schema field" — explicit invariant from ROADMAP.md goal. No two-commit split.
- Personal-tooling vs per-app infra split is the user's mental model: personal MCPs travel with the user across projects, infra MCPs are scoped to a specific app's deployment context.
- Silent fallback (no stderr warning) chosen so re-sourcing an old catalog from a pre-v5.0 install does not flood the terminal with deprecation noise.

</specifics>

<deferred>
## Deferred Ideas

- Calendly catalog entry — Phase 40 (INT-13).
- TUI per-row scope state (`MCP_SELECTED_SCOPE[]`) — Phase 39.
- Wizard scope routing on `TK_MCP_SCOPE=project` — Phase 38.
- Project `.env` writer (`project-secrets.sh`) — Phase 37.
- Documentation updates (INTEGRATIONS.md, INSTALL.md, UNINSTALL.md) — Phase 41.
- CHANGELOG `[5.0.0]` consolidated entry — Phase 41.
- Manifest version bump to `5.0.0` — Phase 41.

</deferred>

---

*Phase: 36-catalog-schema-backward-compat*
*Context gathered: 2026-05-04*
