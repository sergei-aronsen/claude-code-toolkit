---
phase: 36-catalog-schema-backward-compat
verified: 2026-05-04T19:30:00Z
status: passed
score: 11/11 must-haves verified
overrides_applied: 0
re_verification: false
requirements_satisfied:
  - SCOPE-01
  - SCOPE-02
  - SCOPE-03
  - TEST-06
---

# Phase 36: Catalog Schema + Backward Compat — Verification Report

**Phase Goal:** Every MCP entry in `integrations-catalog.json` carries a `default_scope: "user"|"project"` field with sensible per-MCP defaults baked in, the validator enforces the field, and pre-v5.0 catalogs (or pre-v5.0 user installs that re-source an old catalog) keep working via a silent fallback to `user` in `mcp_catalog_load`.

**Verified:** 2026-05-04T19:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from PLAN frontmatter must_haves + ROADMAP success criteria)

| #  | Truth                                                                                                           | Status     | Evidence                                                                                                                            |
| -- | --------------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 1  | All 20 MCP entries in `integrations-catalog.json` carry `default_scope` with valid enum value (`user`/`project`) | VERIFIED | Python load: 20 MCPs, all 20 have `default_scope`; 10 `user` + 10 `project`; `grep -c '"default_scope"'` returns 20                |
| 2  | Personal-tooling MCPs default `user` (10 entries — D-06 grid)                                                    | VERIFIED | All 10 names match: `context7, figma, firecrawl, magic, notebooklm, notion, openrouter, playwright, sentry, youtrack`              |
| 3  | Per-app infra MCPs default `project` (10 entries — D-07 grid)                                                    | VERIFIED | All 10 names match: `aws-cloudwatch-logs, aws-cost-explorer, cloudflare, jira, linear, resend, slack, stripe, supabase, telegram` |
| 4  | Validator fails loudly on missing `default_scope` field or invalid enum value                                    | VERIFIED | BC2 (synthetic catalog missing field): validator exits non-zero, stderr mentions `default_scope`. BC4 (invalid enum `"global"`): same. Validator code at lines 71, 250-256. |
| 5  | `mcp_catalog_load` silently treats missing field as `user`, no stderr emission                                   | VERIFIED | `scripts/lib/mcp.sh:169` uses `jq -r ... '.default_scope // "user"'`. BC1.4 asserts loader stderr is byte-zero. BC1.2 asserts `MCP_DEFAULT_SCOPE='user'` for missing entry. |
| 6  | `make check` passes (markdownlint + shellcheck + validate)                                                       | VERIFIED | `make check` exits 0; full quality gate green (`All checks passed!`)                                                                |
| 7  | Baseline `test-mcp-selector.sh` PASS count unchanged (D-12 canary)                                               | VERIFIED | `Result: PASS=23 FAIL=0` — UNCHANGED from pre-Phase-36 baseline (note: actual baseline was 23, not 21 as plan literal stated; SUMMARY-01/02 documented drift) |
| 8  | `test-integrations-catalog.sh` gains TEST-06 enforcement assertions                                              | VERIFIED | A15/A16/A17 present (lines 277, 293, 304); `Result: PASS=17 FAIL=0` (was 14, +3); A15 walks every MCP entry; A16/A17 spot-check D-07/D-06 grid |
| 9  | New `test-catalog-scope-fallback.sh` covers D-09/D-11 contract (silent fallback + stderr-byte-zero)              | VERIFIED | File exists, executable (`-rwxr-xr-x`); 4 BC scenarios; `Result: PASS=9 FAIL=0`; BC1 covers silent fallback; BC2/BC3/BC4 cover validator |
| 10 | Calendly NOT added (deferred to Phase 40 per D-08)                                                               | VERIFIED | `grep calendly scripts/lib/integrations-catalog.json` returns empty; Python catalog load shows `Has calendly: False` |
| 11 | `manifest.json` version unchanged (deferred to Phase 41)                                                         | VERIFIED | `manifest.json` version stays `4.9.0` — D-08 / Phase 41 owns the bump                                                              |

**Score:** 11/11 truths verified.

### Required Artifacts

| Artifact                                          | Expected                                                                            | Status   | Details                                                                                                                                            |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/lib/integrations-catalog.json`           | 20 MCP entries each carrying `default_scope` per the locked SCOPE-02 grid          | VERIFIED | 20 `"default_scope"` entries; 10 `user` + 10 `project`; matches D-06/D-07 grid exactly. JSON valid. CLI-only entries untouched (D-03).             |
| `scripts/validate-integrations-catalog.py`        | Schema enforcement for `default_scope` (presence + enum)                            | VERIFIED | `REQUIRED_ENTRY_KEYS` extended at line 71; Check 11 enum block at lines 250-256; docstring updated lines 21, 33, 41. Exits 0 on shipped catalog.   |
| `scripts/lib/mcp.sh`                              | `MCP_DEFAULT_SCOPE[]` parallel array + jq `// "user"` silent fallback              | VERIFIED | Docstring at line 29; declaration at line 113; populate at line 169 (`jq -r ... '.default_scope // "user"'`); shellcheck-clean at warning severity |
| `scripts/tests/test-integrations-catalog.sh`      | Three new `_pyq` assertions A15/A16/A17 locking SCOPE-01 + SCOPE-02 grid           | VERIFIED | A15/A16/A17 at lines 277/293/304; PASS=17 FAIL=0 end-to-end                                                                                        |
| `scripts/tests/test-catalog-scope-fallback.sh`    | Hermetic Bash test exercising D-09/D-11 silent-fallback + TEST-06 negative cases   | VERIFIED | 4 BC scenarios (BC1 silent fallback, BC2 reject-missing, BC3 accept-valid, BC4 reject-invalid); 9 assertions PASS; mktemp sandboxes; Bash 3.2 compat |
| `Makefile`                                        | Wires `test-catalog-scope-fallback.sh` into `test:` target chain (Test 48)         | VERIFIED | 4 references in Makefile: `.PHONY` line 1, Test 48 entry line 225, standalone target line 266-267                                                  |

### Key Link Verification

| From                                              | To                                                          | Via                                                                              | Status | Details                                                                              |
| ------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------ |
| `scripts/lib/integrations-catalog.json`           | `scripts/validate-integrations-catalog.py`                 | Make target `validate-catalog` (Makefile lines 415-417)                           | WIRED  | `REQUIRED_ENTRY_KEYS` includes `"default_scope"` at line 71; per-entry walk includes Check 11 enum check |
| `scripts/lib/integrations-catalog.json`           | `scripts/lib/mcp.sh::mcp_catalog_load`                     | jq read inside `while IFS= read -r name; do … done` loop                          | WIRED  | Line 169: `MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")` |
| `scripts/tests/test-integrations-catalog.sh`      | `scripts/lib/integrations-catalog.json`                    | `_pyq` helper (lines 67-86) — Python `json.load` on shipped catalog              | WIRED  | A15/A16/A17 use `catalog.get("components", {}).get("mcp", ...)` to read shipped catalog            |
| `scripts/tests/test-catalog-scope-fallback.sh`    | `scripts/lib/mcp.sh::mcp_catalog_load`                     | subshell `bash -c` with `TK_MCP_CATALOG_PATH` override + `2>stderr` capture       | WIRED  | BC1 sets `TK_MCP_CATALOG_PATH="$SANDBOX/synth-catalog.json"` then sources `mcp.sh` and calls `mcp_catalog_load` |
| `scripts/tests/test-catalog-scope-fallback.sh`    | `scripts/validate-integrations-catalog.py`                 | python3 path-override seam (validator's `sys.argv[1]` at line 89)                | WIRED  | BC2/BC3/BC4 invoke `python3 scripts/validate-integrations-catalog.py "$SANDBOX/<synthetic>.json"` |
| `Makefile`                                        | `scripts/tests/test-catalog-scope-fallback.sh`             | `test:` target Test 48 entry + standalone `test-catalog-scope-fallback` target   | WIRED  | `make -n test` shows Test 48 line; `make -n test-catalog-scope-fallback` parses     |

### Data-Flow Trace (Level 4)

| Artifact                                          | Data Variable          | Source                                                                          | Produces Real Data                                                | Status   |
| ------------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------- | -------- |
| `mcp_catalog_load`                                | `MCP_DEFAULT_SCOPE[]`  | `jq -r ... '.components.mcp[$n].default_scope // "user"'` against catalog file | Yes — populated with 20 values from shipped catalog (10 user + 10 project) | FLOWING  |
| Validator Check 11                                | `default_scope` (entry) | `entry.get("default_scope")` from JSON catalog walk                            | Yes — reads real values per-entry; rejects missing/invalid       | FLOWING  |
| `_pyq` A15/A16/A17                                | `catalog`              | `json.load(open(catalog_path))` against shipped catalog                        | Yes — verifies live catalog passes the contract                   | FLOWING  |
| `test-catalog-scope-fallback.sh` BC1              | `MCP_DEFAULT_SCOPE`    | Loader executed in subshell against synthetic catalog written to mktemp dir    | Yes — subshell stdout shows `noscope=user` and `withscope=project`; stderr file is byte-zero | FLOWING  |

All Level 4 traces confirm real data flows through the wiring — no static fallbacks, no hardcoded empty values, no disconnected props.

### Behavioral Spot-Checks

| Behavior                                                                                  | Command                                                          | Result                                              | Status |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------- | ------ |
| Validator passes against shipped catalog                                                  | `python3 scripts/validate-integrations-catalog.py`              | exit 0; "validation PASSED (20 mcp entries...)"    | PASS   |
| Catalog has all 20 entries with `default_scope` per grid                                  | Python `json.load` + grid assertions                            | 20/20; 10 user / 10 project; matches grid          | PASS   |
| `test-mcp-selector.sh` baseline canary unchanged                                          | `bash scripts/tests/test-mcp-selector.sh`                       | `Result: PASS=23 FAIL=0`                            | PASS   |
| `test-integrations-catalog.sh` gains 3 new assertions                                     | `bash scripts/tests/test-integrations-catalog.sh`               | `Result: PASS=17 FAIL=0`                            | PASS   |
| New fallback test passes all 4 scenarios                                                  | `bash scripts/tests/test-catalog-scope-fallback.sh`             | `Result: PASS=9 FAIL=0`                             | PASS   |
| Full quality gate                                                                         | `make check`                                                     | exit 0 — `All checks passed!`                       | PASS   |
| Full test chain (48 numbered tests)                                                       | `make test`                                                      | exit 0 across all 48 tests                          | PASS   |

### Requirements Coverage

| Requirement | Source Plan         | Description                                                                                   | Status     | Evidence                                                                                                              |
| ----------- | ------------------- | --------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------- |
| SCOPE-01    | 36-01-foundation    | `default_scope` field on every MCP entry; validator enforces presence + enum                 | SATISFIED | All 20 MCPs have field; validator Check 11 enforces enum (lines 71, 250-256); shipped catalog passes; synthetic-missing fails |
| SCOPE-02    | 36-01-foundation    | Default-scope assignments per personal/infra grid                                              | SATISFIED | Grid verified by Python script: 10/10 user, 10/10 project, matches D-06/D-07 names exactly                            |
| SCOPE-03    | 36-01-foundation, 36-02-test-contract | Backward-compat fallback in `mcp_catalog_load`; silent (no stderr); pre-v5.0 catalogs work | SATISFIED | `jq // "user"` at mcp.sh:169; BC1 confirms loader returns 0, populates user, emits zero stderr bytes                  |
| TEST-06     | 36-02-test-contract | Catalog validator gains assertion for SCOPE-01: every MCP entry has `default_scope`           | SATISFIED | Validator Check 11 (Plan 01); meta-test A15 in `test-integrations-catalog.sh`; synthetic-catalog negative-case tests BC2/BC3/BC4 in fallback test |

**Note on REQUIREMENTS.md traceability table drift:** The traceability table at lines 118-156 of `REQUIREMENTS.md` lists ALL requirements as `not-started`, including SCOPE-01..03 (which are implemented). The table also maps TEST-06 to "Phase 40" while it was actually delivered in Phase 36 Plan 02. The source-of-truth checkbox state at lines 13-15 and 86 correctly shows SCOPE-01/02/03/TEST-06 all checked. This is project-wide documentation drift in the traceability table, not a Phase 36 implementation gap. Recommendation: stale traceability table should be updated as part of Phase 41 (DOCS) or a maintenance pass; it is informational only and does not affect Phase 36 closure.

### Anti-Patterns Found

| File                                              | Line | Pattern                | Severity | Impact                                                                                              |
| ------------------------------------------------- | ---- | ---------------------- | -------- | --------------------------------------------------------------------------------------------------- |
| _none in Phase 36 modified files_                 | -    | -                      | -        | -                                                                                                   |

`grep -nE "TODO\|FIXME\|XXX\|HACK\|PLACEHOLDER"` matches in modified files were all `mktemp ...XXXXXX` template patterns (false positives — `X` is the literal pattern char for mktemp suffix randomization, not a TODO marker). The three "placeholder" hits in `scripts/lib/mcp.sh` (lines 724, 861, 908) are pre-existing comments unrelated to Phase 36's `default_scope` work — they describe `mcp_secrets_set` and `MCP_TO_TUI_IDX` initialization patterns from Phase 34/35.

### Behavioral / Threat Spot-Checks (additional)

- `bash -n scripts/lib/mcp.sh` exits 0 (no syntax error).
- `shellcheck -S warning scripts/lib/mcp.sh` exits 0.
- `shellcheck -S warning scripts/tests/test-catalog-scope-fallback.sh` exits 0.
- `make -n test-catalog-scope-fallback` parses — standalone target works.
- `bash scripts/tests/test-integrations-foundation.sh` exits 0 (foundation fixtures gained `default_scope` per Plan 02 Task 4 deviation auto-fix); 3 fixtures updated.
- No `// null` + string-equality on `"null"` introduced (forbidden anti-pattern at mcp.sh:146).
- Bash 3.2 compat: `grep -E 'mapfile|declare -A|\$\{[a-zA-Z_]+,,\}|read -N |declare -n' scripts/tests/test-catalog-scope-fallback.sh` returns no matches.

### Human Verification Required

None. All must-haves are programmatically verifiable and verified. Phase 36 is purely data + validator + loader — no UI, no real-time behavior, no external service integration, no visual rendering. Full test coverage at three layers (validator self-check, meta-test on shipped catalog via `_pyq` A15, hermetic synthetic-catalog test on validator + loader) closes the regression-detection gap; Phase 38/39 consumers can rely on the contract.

### Gaps Summary

No gaps. All 11 must-haves verified, all 4 requirements (SCOPE-01, SCOPE-02, SCOPE-03, TEST-06) satisfied, all key links wired, all data flowing, all anti-pattern scans clean, and all D-12 baselines preserved (selector PASS=23 unchanged, integrations-catalog PASS=17 = 14+3, fallback PASS=9 ≥ 7 floor).

The single non-blocking note is documentation drift in `REQUIREMENTS.md` traceability table (lines 120-150) that lists implemented requirements as "not-started" — orthogonal to Phase 36's contract; the source-of-truth checkbox state at lines 13-15, 86 correctly shows all four Phase 36 requirements checked.

### D-08 / D-10 Invariants (verified)

- D-08 Calendly deferred to Phase 40: `Has calendly: False` confirmed.
- D-08 manifest.json version unchanged: `"version": "4.9.0"` — Phase 41 owns the v5.0.0 bump.
- D-08 CHANGELOG.md unchanged: Phase 41 owns the consolidated `[5.0.0]` entry.
- D-10 single-landing invariant: catalog data, validator schema enforcement, and loader fallback all shipped together (commits `cb79920`, `796f282`, `a5fa7c5` on the same plan; the loader's silent fallback means there is never a window where the catalog was stricter than the loader).

---

_Verified: 2026-05-04T19:30:00Z_
_Verifier: Claude (gsd-verifier)_
