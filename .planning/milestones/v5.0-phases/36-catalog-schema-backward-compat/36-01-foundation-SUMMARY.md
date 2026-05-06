---
phase: 36-catalog-schema-backward-compat
plan: 01-foundation
subsystem: catalog
tags: [json-schema, validator, bash-loader, jq, backward-compat, mcp, scope]

# Dependency graph
requires:
  - phase: 32-integrations-catalog-foundation
    provides: schema_version 2 catalog (`integrations-catalog.json`) + validator + `mcp_catalog_load` parallel-array loader (Phase 34-01 extended it).
provides:
  - "20 MCP entries each carrying `default_scope: \"user\"|\"project\"` per the locked SCOPE-02 grid (10 user + 10 project)."
  - "Validator (`scripts/validate-integrations-catalog.py`) enforces presence + enum on every MCP entry — fails loudly on missing/invalid (Check 11, SCOPE-01)."
  - "Loader (`mcp_catalog_load`) populates `MCP_DEFAULT_SCOPE[]` parallel array; missing field → silent fallback to `\"user\"` (D-09/D-11)."
affects:
  - 37-project-secrets-library
  - 38-wizard-dispatch-integration
  - 39-tui-per-row-scope-toggle
  - 40-uninstall-secret-cleanup-calendly
  - 41-distribution-docs

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive JSON field with jq `// \"default\"` silent fallback (matches `.category // \"\"` precedent on mcp.sh:133 and `.unofficial // false` on mcp.sh:136)."
    - "Validator-extension pattern: append to `REQUIRED_ENTRY_KEYS` tuple + add per-entry enum check mirroring the `requires_oauth` bool-check style with `repr(value)` in the failure message."
    - "Single-landing invariant (D-10): catalog data, validator schema enforcement, and loader fallback ship in three atomic commits within one plan — never a window where the catalog is stricter than the loader."

key-files:
  created: []
  modified:
    - "scripts/lib/integrations-catalog.json — 20 MCP entries gain `default_scope` (40 insertions / 20 deletions, additive)."
    - "scripts/validate-integrations-catalog.py — REQUIRED_ENTRY_KEYS tuple +1, new Check 11 enum block, docstring 1→11 checks (15 insertions / 2 deletions)."
    - "scripts/lib/mcp.sh — new `MCP_DEFAULT_SCOPE=()` declaration + populate inside `while IFS= read -r name` loop with `// \"user\"` jq fallback + docstring Globals subsection (10 insertions, 0 deletions)."

key-decisions:
  - "default_scope appended LAST in each catalog block (after `unofficial` when present, otherwise after `requires_oauth`) to match validator docstring order and keep diffs minimal."
  - "Silent fallback in loader (`jq '// \"user\"'`) over `// null` + string-equality branch — explicit anti-pattern documented at mcp.sh:146; matches the established pattern from mcp.sh:133 and 136."
  - "EXPECTED_SCHEMA_VERSION stays at 2 — additive change does not require migration logic in downstream readers (per RESEARCH.md state-of-the-art table)."
  - "Plan 02 (test contract) deferred per plan output: Plan 01 only ensures no syntax/schema regression; positive `_pyq` SCOPE-02 grid assertions + hermetic loader-fallback test land in Plan 02."

patterns-established:
  - "Schema additive field landing pattern: data + validator + loader fallback in one plan, three atomic commits, no two-commit split."
  - "Silent backward-compat fallback for optional fields — loud stderr reserved for HARD errors (catalog missing, jq missing) only."

requirements-completed:
  - SCOPE-01
  - SCOPE-02
  - SCOPE-03

# Metrics
duration: ~14 min
completed: 2026-05-04
---

# Phase 36 Plan 01: Foundation Summary

**Per-MCP `default_scope` schema landed across all 20 catalog entries, validator enforces presence + enum, loader silently falls back to `"user"` for pre-v5.0 catalogs — three atomic commits, no behavior change to selector/integrations baselines.**

## Performance

- **Duration:** ~14 min (3 sequential tasks + verification)
- **Started:** 2026-05-04T16:31:30Z
- **Completed:** 2026-05-04T16:45:35Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- **20 MCP entries seeded with `default_scope` per the locked SCOPE-02 grid** — 10 personal-tooling MCPs default `"user"` (context7, figma, firecrawl, magic, notebooklm, notion, openrouter, playwright, sentry, youtrack) and 10 per-app infra MCPs default `"project"` (aws-cloudwatch-logs, aws-cost-explorer, cloudflare, jira, linear, resend, slack, stripe, supabase, telegram).
- **Validator extended with Check 11** — `default_scope` required on every MCP entry, enum check rejects any value other than `"user"` or `"project"`. Mirrors the existing `requires_oauth` bool-check style; CLI-only entries untouched (D-03 invariant preserved automatically by the per-entry walk's iteration shape).
- **`mcp_catalog_load` populates `MCP_DEFAULT_SCOPE[]`** parallel to `MCP_NAMES[]` with silent `jq '// "user"'` fallback. No stderr emission on missing field (D-11). Iteration source unchanged — alphabetical order preserved.
- **Quality gate green:** `make check` exits 0 (validator + shellcheck + markdownlint + version-align + 11 other targets), `bash -n` + `shellcheck -S warning` clean on `mcp.sh`, baseline canaries unchanged (`test-mcp-selector.sh` PASS=23, `test-integrations-catalog.sh` PASS=14).

## Task Commits

Each task was committed atomically:

1. **Task 1: Seed default_scope on 20 MCP entries (SCOPE-02)** — `cb79920` (feat)
2. **Task 2: Enforce default_scope schema in validator (SCOPE-01)** — `796f282` (feat)
3. **Task 3: Add MCP_DEFAULT_SCOPE[] parallel array w/ silent fallback (SCOPE-03)** — `a5fa7c5` (feat)

_Note: Tasks 2 and 3 are tagged `tdd="true"` in the plan, but the project config has `tdd_mode: false` and the test contract is explicitly deferred to Plan 02 per the plan's verification block ("existing baselines `bash scripts/tests/test-mcp-selector.sh` (PASS=21) and `bash scripts/tests/test-integrations-catalog.sh` (PASS≥10) are validated in Plan 02"). Each task was verified inline against synthetic catalogs (negative validator tests, loader fallback test) before commit, but no `test(...)` commits were authored — those land in Plan 02. See `## TDD Gate Compliance` below._

## Files Created/Modified

- `scripts/lib/integrations-catalog.json` — All 20 `components.mcp.<name>` blocks gained `"default_scope": "user"|"project"` as the LAST key. Field-order rule: inserted after `requires_oauth` when no `unofficial` field exists, after `unofficial` when present (notebooklm, telegram). 40 insertions / 20 deletions (the 20 deletions are the `requires_oauth: false` / `unofficial: true` lines that gained a trailing comma). CLI-only entries (`components.cli.*`) untouched (D-03). No `calendly` or `google-workspace` entry added (D-08 / INT-14).
- `scripts/validate-integrations-catalog.py` — `REQUIRED_ENTRY_KEYS` tuple gained `"default_scope"` as the 8th element (line 71); existing missing-keys check at lines 162-167 auto-fires when the field is absent. New Check 11 enum block (lines 250-256) inserted immediately after the `requires_oauth` bool check, mirrors that block's style with `repr(value)` in the failure message. Docstring schema example (lines 7-25) and "Checks performed" list (lines 26-39) updated from 10 to 11 checks. `EXPECTED_SCHEMA_VERSION` unchanged at 2 (additive change).
- `scripts/lib/mcp.sh` — Function-header docstring (line 28-29) gained a new `Globals (write, Phase 36 (SCOPE-01/03)):` subsection listing `MCP_DEFAULT_SCOPE[]`. New `MCP_DEFAULT_SCOPE=()` declaration (line 113) added in the existing Phase 34-01 declaration block. New populate line inside the existing `while IFS= read -r name; do … done` loop (line 169) using `jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path"` — matches the `.category // ""` precedent at line 133 verbatim. All 3 sites carry `# shellcheck disable=SC2034` (consumed by Phase 38 wizard, not in this file). Iteration source at line 173 (`done < <(jq -r '.components.mcp | keys | sort | .[]' "$catalog_path")`) unchanged — alphabetical order preserved.

## Decisions Made

None beyond what was already locked in `36-CONTEXT.md` D-01..D-14. The only Claude's-discretion choice in this plan was "validator implementation detail (jsonschema-lite vs hand-rolled jq vs Python dict walk)" — picked the hand-rolled Python dict walk to match the existing validator style (no new pip dependency, `not in` against tuple literal). Other discretion items (test harness layout) are deferred to Plan 02.

## Deviations from Plan

**One non-blocking deviation: baseline arithmetic for `test-mcp-selector.sh`.**

The plan's `<deviation_handling>` block locks `test-mcp-selector.sh` PASS=21 as the D-12 canary. Actual baseline measured at the start of execution (before any Phase 36 edits) was PASS=23 — the test file evolved past the planning snapshot in earlier work (2 additional assertions). This is consistent with the deviation_handling rule's intent ("PASS=21 must stay UNCHANGED — not just ≥21"): the contract is _no shift_ during this plan, and `test-mcp-selector.sh` returned PASS=23 both before and after Phase 36 edits — unchanged. Treated as documentation drift in the plan, not as a regression. No code change needed.

No other deviations. All three tasks executed exactly per the plan's `<action>` blocks. No Rule 1 / 2 / 3 auto-fixes were necessary — the plan's analog-and-diff sketches were verbatim correct.

---

**Total deviations:** 0 auto-fixed, 1 documentation drift noted (no code impact).
**Impact on plan:** None. Plan executed exactly as written.

## Issues Encountered

None. Three small concerns surfaced and resolved without code changes:

1. **PreToolUse Read-before-Edit reminders** fired on every `Edit` despite the file being read earlier in the session. The runtime accepted all edits — they had been read at the top of the session. Hooks are advisory, not blocking, in this case.
2. **Plan's noted PASS=21 baseline for `test-mcp-selector.sh`** does not match the actual disk state (PASS=23). Documented in the Deviations section above; test file unchanged by this plan.
3. **Two large `<system-reminder>` blocks** for empty `.claude/rules/project-context.md` and a verbose `.claude/rules/lessons-learned.md` audit log. Read for context, no impact on Phase 36 work — Phase 36 is data + validator + loader, no auth/file-upload/shell-from-user-input surface.

## TDD Gate Compliance

Tasks 2 and 3 in the plan are tagged `tdd="true"`, but:

1. The project config has `workflow.tdd_mode: false` (`.planning/config.json`).
2. The plan's own `<verification>` block explicitly defers the test contract to Plan 02: _"existing baselines `bash scripts/tests/test-mcp-selector.sh` (PASS=21) and `bash scripts/tests/test-integrations-catalog.sh` (PASS≥10) are validated in Plan 02"_.
3. The plan's `<output>` block says: _"After completion, create `.planning/phases/36-catalog-schema-backward-compat/36-01-SUMMARY.md`"_ — Plan 02 explicitly carries the `test(...)` commits.

Therefore: no `test(...)` RED-gate commits were authored in Plan 01. Each task was verified inline against synthetic catalogs (negative validator tests for missing-field + bad-enum, loader-fallback test for D-11 silent contract) before commit, with `assert_eq`-style checks proving:

- Validator exit non-zero on synthetic catalog missing `default_scope` AND stderr mentions `default_scope`.
- Validator exit non-zero on synthetic catalog with `"default_scope": "global"` AND stderr mentions both `default_scope` and `'global'`.
- Loader returns 0 on synthetic catalog missing the field AND `MCP_DEFAULT_SCOPE` for that entry equals `"user"` AND captured stderr is byte-zero (D-11 silent contract).

Plan 02 will formalize these into hermetic `_pyq` and bash test assertions in `test-integrations-catalog.sh` and (per RESEARCH.md recommendation) a new sibling `test-catalog-scope-fallback.sh`.

## User Setup Required

None — no external service configuration required. Phase 36 is repo-internal: catalog data + validator + loader. No auth, no secrets, no network, no file uploads.

## Next Phase Readiness

- **Plan 02 (test contract):** Ready. Each delta in this plan has a known acceptance shape — `_pyq` A15/A16/A17 grid spot-checks for the catalog, sibling `test-catalog-scope-fallback.sh` for the synthetic-catalog hermetic loader test, validator negative-case extension for missing-field and invalid-enum.
- **Phase 37 (project-secrets library):** Ready. The `default_scope` semantics are now stable in both the catalog (always present, enum-enforced) and the loader (`MCP_DEFAULT_SCOPE[]` parallel array; pre-v5.0 catalogs handled silently).
- **Phase 38 (wizard dispatch):** Reads `MCP_DEFAULT_SCOPE[$idx]` to route per-MCP scope decisions. Loader contract is now in place — Phase 38 needs zero loader changes.
- **Phase 39 (TUI per-row scope toggle):** Initializes `MCP_SELECTED_SCOPE[]` from `MCP_DEFAULT_SCOPE[]` at TUI launch. Same as 38: zero loader changes needed.
- **Phase 40 (Calendly + uninstall + validator SCOPE-01 assertion):** When the Calendly entry lands in Phase 40, the validator's Check 11 will already enforce `default_scope` on it — no additional validator work needed.
- **Phase 41 (close):** No `manifest.json` or `CHANGELOG.md` edits in Plan 01 (D-08 — version bump deferred to Phase 41 to keep `version-align` Makefile gate green).

No blockers. No concerns.

## Self-Check

- ✅ `scripts/lib/integrations-catalog.json` modified — 60 lines changed (40 insertions / 20 deletions); `grep -c '"default_scope":'` returns 20.
- ✅ `scripts/validate-integrations-catalog.py` modified — 17 lines changed (15 insertions / 2 deletions); `grep -n '"default_scope",'` returns 1 match (line 71); `grep -n 'default_scope must be'` returns 1 match (line 254).
- ✅ `scripts/lib/mcp.sh` modified — 10 lines added; `grep -n 'MCP_DEFAULT_SCOPE'` returns 3 matches (docstring, declaration, populate); `grep -n 'default_scope // "user"'` returns 1 match (line 169).
- ✅ Commit `cb79920` exists in `git log` (`feat(36-01): seed default_scope on all 20 MCP entries (SCOPE-02)`).
- ✅ Commit `796f282` exists in `git log` (`feat(36-01): enforce default_scope schema in validator (SCOPE-01)`).
- ✅ Commit `a5fa7c5` exists in `git log` (`feat(36-01): add MCP_DEFAULT_SCOPE[] parallel array w/ silent fallback (SCOPE-03)`).
- ✅ `python3 scripts/validate-integrations-catalog.py` exits 0 with `validation PASSED (20 mcp entries checked across 10 categories)`.
- ✅ `make check` exits 0 (`All checks passed!`).
- ✅ `bash -n scripts/lib/mcp.sh` exits 0 (no syntax error).
- ✅ `shellcheck -S warning scripts/lib/mcp.sh` exits 0 (no warnings).
- ✅ `bash scripts/tests/test-mcp-selector.sh` returns PASS=23 unchanged from baseline (D-12 canary).
- ✅ `bash scripts/tests/test-integrations-catalog.sh` returns PASS=14 ≥10 (D-12 floor).

## Self-Check: PASSED

---
*Phase: 36-catalog-schema-backward-compat*
*Plan: 01-foundation*
*Completed: 2026-05-04*
