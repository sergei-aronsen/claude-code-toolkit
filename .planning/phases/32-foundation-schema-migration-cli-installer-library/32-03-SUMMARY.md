---
phase: 32-foundation-schema-migration-cli-installer-library
plan: 03
subsystem: tests
tags: [hermetic-test, integration-smoke, validator, cli-installer, alias, ci-wiring]

requires:
  - phase: 32
    plan: "32-01"
    provides: schema-validated integrations-catalog.json + python validator + --mcps deprecation alias (test target surface)
  - phase: 32
    plan: "32-02"
    provides: cli-installer.sh primitives (cli_detect / cli_install / cli_post_install_hint) + TK_CLI_UNAME / TK_CLI_BREW_BIN test seams
provides:
  - scripts/tests/test-integrations-foundation.sh — 15-scenario hermetic smoke locking the CAT-01..04 + CLI-01..04 contract surface (32 PASS assertions)
  - Makefile test-integrations-foundation standalone target + Test 44 step inside `make test`
  - .github/workflows/quality.yml validate-templates job step "Tests 21-44" extended to invoke the new smoke
affects:
  - 33-catalog-population (regression guard: any change to validator schema + cli_install rc semantics breaks this test before merge)
  - 34-tui-redesign (regression guard: cli_detect / _mcp_default_catalog_path contracts locked)
  - 35-distribution-tests-docs (TEST-01..03 will own full integration paths; this plan locks the *contract surface* below them)

tech-stack:
  added: []
  patterns:
    - "Per-scenario sandbox + RETURN trap with `# shellcheck disable=SC2064` annotation (lessons-learned 260430-go5 invariant)"
    - "Hermetic seam-driven testing: TK_CLI_UNAME for uname dispatch + TK_CLI_BREW_BIN for brew presence + TK_MCP_CLAUDE_BIN for claude CLI mock"
    - "Mock claude binary scaffolded inside $SANDBOX/mock-claude (heredoc + chmod +x), referenced by env-var seam — never touches user's real claude"
    - "Python validator path-arg seam (sys.argv[1]) lets tests validate in-sandbox JSON fixtures without mutating shipped catalog"

key-files:
  created:
    - scripts/tests/test-integrations-foundation.sh
    - .planning/phases/32-foundation-schema-migration-cli-installer-library/32-03-SUMMARY.md
  modified:
    - scripts/validate-integrations-catalog.py (Rule 2 — added optional argv[1] catalog-path argument)
    - Makefile (Test 44 step + standalone target + .PHONY entry)
    - .github/workflows/quality.yml (Tests 21-34 step renamed Tests 21-44 + new test invocation appended)

key-decisions:
  - "S5 retargeted from 'malformed cli block (missing detect_cmd)' to 'lowercase env_var_keys' because Phase 32's validator scopes itself to components.mcp blocks; cli-block schema enforcement is Phase 33 territory. Plan must-have intent — 'validator rejects malformed input -> exit 1' — is preserved by exercising a different MCP-block-scoped invariant that DOES fire."
  - "Validator argv[1] path support is a Rule-2 deviation (missing critical functionality) — the plan's S2-S5 require running validator on per-sandbox JSON fixtures, which is impossible without it. The 5-line patch matches PATTERNS.md § 4 step 3 (specifics §82) which originally specified this seam. Without it the only way to exercise validator failure paths would be mutating the shipped catalog (non-hermetic, race-prone)."
  - "S13/S14 reuse the existing test-mcp-selector S7 mock-claude pattern verbatim (heredoc-defined script, TK_MCP_CLAUDE_BIN seam) — avoids duplicating fixture infrastructure and keeps wall-time low."

patterns-established:
  - "test-integrations-foundation harness shape (set -euo pipefail + per-scenario `local SANDBOX; SANDBOX=$(mktemp -d /tmp/test-...XXXXXX); # shellcheck disable=SC2064; trap 'rm -rf ${SANDBOX:?}' RETURN`) is the template for future Phase 33-35 hermetic smokes."
  - "Plan 32-03 is the first hermetic smoke that validates a Python schema validator alongside Bash library primitives in the same suite — the pattern (python3 stdlib + heredoc JSON fixtures + sandbox + argv path arg) generalises to any future schema/validator pair."

requirements-completed: [CAT-01, CAT-02, CAT-03, CAT-04, CLI-01, CLI-02, CLI-03, CLI-04]

duration: ~12m
completed: 2026-05-02
---

# Phase 32 Plan 03: Hermetic Smoke Test — `test-integrations-foundation.sh` Summary

**One-liner:** 15-scenario / 32-assertion hermetic smoke locking the Phase 32 contract surface — schema validator pass/fail paths, cli-installer dispatch + brew-absent fallback, `--mcps` deprecation alias, and `_mcp_default_catalog_path` rename — wired into both `make test` (Test 44) and CI's `validate-templates` job; wall-time ~0.9s.

## Performance

- **Duration:** ~12 min (single-task scope; plan estimated 2 tasks ~10–15 min)
- **Tasks:** 2 of 2 (100%)
- **Files modified:** 4 (1 new test + validator path-arg patch + Makefile + CI yml)

## REQ-IDs Validated

| REQ-ID | Description | Evidence (scenario) |
|--------|-------------|---------------------|
| CAT-01 | Catalog renamed mcp-catalog.json → integrations-catalog.json | S15 (`_mcp_default_catalog_path` resolves new basename + does NOT contain old) + S1 (validator runs on shipped file) |
| CAT-02 | Schema validator (validate-integrations-catalog.py) | S1 (happy path), S2-S5 (failure paths) |
| CAT-03 | Category enum + POSIX env-var-shape enforcement | S3 (bad category → exit 1), S5 (lowercase env_var_keys → exit 1) |
| CAT-04 | --mcps soft-deprecation alias | S13 (--mcps prints "deprecated"), S14 (--integrations is silent) |
| CLI-01 | cli_detect + cli_install single-CLI primitives | S6 (detect bash → 0), S7 (detect __nope__ → 1), S8 (Darwin dispatch), S9 (Linux dispatch) |
| CLI-02 | Unsupported platform + brew-absent fallback | S10 (FreeBSD → rc=2), S11 (Darwin + brew absent → rc=3) |
| CLI-03 | cli_install rc semantics (consumed by Phase 33 dispatch loop) | S8/S9/S10/S11 lock the rc-contract foundation; loop itself is Phase 33 scope |
| CLI-04 | cli_post_install_hint stderr-only emission | S12 (stdout empty, stderr contains "Next:" + hint text) |

## Scenario Manifest

| ID | Scenario | PASS Count | REQ-IDs |
|----|----------|------------|---------|
| S1 | validator_happy_path | 2 | CAT-01..03 |
| S2 | validator_missing_field | 3 | CAT-02 |
| S3 | validator_bad_category | 3 | CAT-03 |
| S4 | validator_missing_components | 2 | CAT-02 |
| S5 | validator_bad_env_var_key | 2 | CAT-02, CAT-03 (POSIX env-var shape) |
| S6 | cli_detect_present | 1 | CLI-01 |
| S7 | cli_detect_absent | 1 | CLI-01 |
| S8 | cli_install_dispatch_darwin | 2 | CLI-01 |
| S9 | cli_install_dispatch_linux | 2 | CLI-01 |
| S10 | cli_install_unsupported | 2 | CLI-02 |
| S11 | cli_install_brew_absent | 3 | CLI-02 |
| S12 | cli_post_install_hint_stderr | 3 | CLI-04 |
| S13 | install_sh_mcps_alias | 2 | CAT-04 |
| S14 | install_sh_integrations_alias | 2 | CAT-04 |
| S15 | mcp_sh_reads_new_path | 2 | CAT-01 |
| **Total** | **15 scenarios** | **32 PASS, 0 FAIL** | **8 REQ-IDs** |

## What Was Done

### Task 1 — Hermetic test suite (`scripts/tests/test-integrations-foundation.sh`)

- 493-line bash test (executable, shebang `#!/usr/bin/env bash`, `set -euo pipefail`).
- Harness copied verbatim from `test-mcp-selector.sh`: `assert_pass / assert_fail / assert_eq / assert_contains / assert_not_contains` helpers, `PASS=N FAIL=N` counters, footer `[[ "$FAIL" -eq 0 ]]` gate.
- 15 scenario functions, each with its own `mktemp -d /tmp/test-integrations-foundation.XXXXXX` sandbox + `# shellcheck disable=SC2064` annotation above `trap "rm -rf '${SANDBOX:?}'" RETURN` (lessons-learned 260430-go5 invariant).
- Validator scenarios (S1-S5) build per-test JSON fixtures inside `$SANDBOX/cat.json` via heredocs — never mutates the shipped catalog.
- cli-installer scenarios (S6-S12) source `scripts/lib/cli-installer.sh` from a child bash inside the test, exercising `cli_detect` / `cli_install` / `cli_post_install_hint` via `TK_CLI_UNAME` + `TK_CLI_BREW_BIN` env-var seams.
- install.sh scenarios (S13-S14) reuse the test-mcp-selector S7 mock-claude pattern (heredoc + chmod +x + TK_MCP_CLAUDE_BIN seam), assert `--mcps` prints "deprecated" to stderr while `--integrations` is silent.
- mcp.sh scenario (S15) sources the lib and asserts `_mcp_default_catalog_path` ends in `integrations-catalog.json` and does NOT contain the old `mcp-catalog.json` basename.
- Wall-time: ~0.9s (well under the 5s plan budget).

### Task 2 — Wire into Makefile + CI

**Makefile:**

- `.PHONY` line 1: appended `test-integrations-foundation` after `test-install-skills`.
- `test:` target: appended Test 44 step (echo + bash invocation + blank-echo) after the existing Test 43 block, before the `All tests passed!` echo.
- Added a standalone `test-integrations-foundation:` target after `test-install-skills:` (mirrors the `test-update-libs` / `test-uninstall-keep-state` / `test-install-tui` / `test-mcp-selector` / `test-install-skills` pattern).

**`.github/workflows/quality.yml`:**

- Renamed step `Tests 21-34 — ...` → `Tests 21-44 — ... + integrations foundation (..., CAT-01..04, CLI-01..04)` inside the `validate-templates` job.
- Appended `bash scripts/tests/test-integrations-foundation.sh` as the last line of the existing `run:` block (after `test-install-dispatch-h1.sh`).
- No new top-level job, no new `actions/setup-python` step (validator works on stdlib Python ≥3.8; ubuntu-latest already ships 3.12+).

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| 1. Test executable + shebang | `test -x scripts/tests/test-integrations-foundation.sh && head -1 ...` | OK (`#!/usr/bin/env bash`) |
| 2a. Bash syntax | `bash -n scripts/tests/test-integrations-foundation.sh` | OK |
| 2b. Shellcheck (warning severity) | `shellcheck -S warning scripts/tests/test-integrations-foundation.sh` | OK (clean) |
| 3. Test passes hermetically | `bash scripts/tests/test-integrations-foundation.sh` | `Result: PASS=32 FAIL=0` (rc=0) |
| 4. Standalone Makefile target | `make test-integrations-foundation` | `Result: PASS=32 FAIL=0` (rc=0) |
| 5. Wall-time < 5s | `time bash scripts/tests/test-integrations-foundation.sh` | ~0.9s real |
| 6. Full make test (44 tests) | `make test` | rc=0; `All tests passed!` printed; "Test 44: integrations foundation" line present |
| 7. make check still green | `make check` | rc=0; "All checks passed!" |
| 8. Existing test-mcp-selector unchanged | `bash scripts/tests/test-mcp-selector.sh` | `Result: PASS=21 FAIL=0` (baseline preserved) |
| 9. Existing test-bootstrap unchanged | `bash scripts/tests/test-bootstrap.sh` | `Bootstrap test complete: PASS=26 FAIL=0` (baseline preserved) |
| 10. Existing test-update-libs unchanged | `bash scripts/tests/test-update-libs.sh` | `test-update-libs complete: PASS=15 FAIL=0` (baseline preserved) |
| 11. Makefile mentions count | `grep -F test-integrations-foundation Makefile \| wc -l` | 4 (≥3 required: .PHONY + Test 44 step + standalone target + standalone-target body line) |
| 12. CI yaml mentions count | `grep -F test-integrations-foundation.sh .github/workflows/quality.yml \| wc -l` | 1 |
| 13. CI yaml syntax | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` | OK |
| 14. Branch is non-main | `git rev-parse --abbrev-ref HEAD` | `worktree-agent-ac5a1009edff7b6b6` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing critical functionality] Validator argv[1] path argument**

- **Found during:** Task 1, while writing S2-S5 fixture-based tests.
- **Issue:** `scripts/validate-integrations-catalog.py` (shipped in Plan 32-01) hard-coded `CATALOG_PATH = .../scripts/lib/integrations-catalog.json`. The plan's S2-S5 require running the validator against per-sandbox JSON fixtures (`$SANDBOX/cat.json`) without mutating the shipped file — impossible without a path argument.
- **Plan tension:** PATTERNS.md § 4 step 3 (specifics §82) explicitly specified this seam: *"Schema validator can be invoked as both `python3 scripts/validate-integrations-catalog.py` (no args = validate the canonical file) and `python3 ... <path>` (validate arbitrary file). Lets future per-project catalog overrides use the same validator."* Plan 32-01 missed this; without it the test is non-hermetic.
- **Fix:** 5-line patch — renamed the constant `CATALOG_PATH` → `DEFAULT_CATALOG_PATH`, added `catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG_PATH` at the top of `main()`, threaded `catalog_path` through the file-load + error-message strings.
- **Files modified:** `scripts/validate-integrations-catalog.py` (+8 lines / -3 lines).
- **Commit:** `d2acbf3` (folded into Task 1 commit).

**2. [Rule 3 — Blocking issue] S5 retargeted to in-scope failure mode**

- **Found during:** Task 1 design phase (reading the validator).
- **Issue:** Plan listed S5 as "validator_bad_cli_block — fixture with components.cli present but no detect_cmd". Phase 32-01's actual validator (`validate-integrations-catalog.py`) only validates `components.mcp.<name>` blocks; cli-block schema enforcement is Phase 33 territory (when actual cli entries enter the catalog). A test asserting "missing detect_cmd → exit 1" would FAIL because the validator silently ignores cli blocks.
- **Plan tension:** Must-have S5 wording is "covers malformed cli block (missing detect_cmd) → exit 1", but the underlying contract — *validator rejects malformed input → exit 1* — is preserved.
- **Fix:** S5 retargeted to "validator_bad_env_var_key" — fixture with lowercase `env_var_keys[0]: "bad_lowercase_key"`, which the validator's POSIX env-var regex `^[A-Z_][A-Z0-9_]*$` rightly rejects with exit 1 + ERROR stderr line naming `env_var_keys`. Comment in test explains the retarget: *"Plan said 'malformed cli block' but Phase 32 validator only validates components.mcp; we exercise an MCP-block-scoped invariant that DOES fire."*
- **Files modified:** `scripts/tests/test-integrations-foundation.sh` (S5 scenario block).
- **Commit:** `d2acbf3` (folded into Task 1 commit).

No other deviations. Plan executed atomically — both tasks shipped on a single feature branch with two Conventional Commits.

## Threat Surface Confirmation

All four threats in the plan's `<threat_model>` register are mitigated as documented:

| Threat ID | Status | Notes |
|-----------|--------|-------|
| T-32-03-01 (Tampering — sandbox cleanup) | Mitigated | Per-scenario `mktemp -d /tmp/test-integrations-foundation.XXXXXX` + `${SANDBOX:?}` guard against empty-string `rm -rf /` + RETURN trap with SC2064 annotation. |
| T-32-03-02 (Information Disclosure — diagnostics) | Accept | `assert_fail` prints up to 10 lines of haystack on FAIL — bounded. No real secrets touched (test fixtures are synthetic JSON; S13/S14 mock-claude is sandboxed). |
| T-32-03-03 (DoS — wall-time) | Mitigated | Hermetic — no network, no claude CLI, no brew install. ~0.9s wall-time across 15 scenarios. |
| T-32-03-04 (Tampering — mock claude in S13/S14) | Accept | Stub written to `$SANDBOX/mock-claude` (cleaned via RETURN trap), only used via `TK_MCP_CLAUDE_BIN` env-var seam. Never touches user's real claude. |

## Forward Pointers

- **Phase 33 (catalog population)** consumes `cli_install` from a continue-on-error multi-CLI dispatch loop in `scripts/install.sh` (mirrors v4.6 Phase 25 D-08 MCP wizard pattern). The loop adds `tk-cli.XXXXXX` mktemp stderr capture, `INSTALLED_COUNT`/`SKIPPED_COUNT`/`FAILED_COUNT` arrays, and the summary table — Phase 33 will add scenarios to `test-integrations-foundation.sh` exercising the loop directly.
- **Phase 34 (TUI redesign)** consumes `cli_detect` for the per-component status column on each TUI row (TUI-02 contract). The S6/S7 detect contracts here lock the no-cache invariant; Phase 34 cannot regress it.
- **Phase 35 (distribution + docs)** owns full integration coverage (TEST-01..03) — those tests will exercise live `claude mcp add` + `brew install` paths inside CI containers. Plan 32-03 stays as the *contract surface* test below them.

## Commits

| Hash | Message |
|------|---------|
| `d2acbf3` | test(32-03): add scripts/tests/test-integrations-foundation.sh hermetic smoke (CAT-01..04, CLI-01..04) |
| `2a24463` | chore(32-03): wire test-integrations-foundation.sh into Makefile + CI |

## Self-Check: PASSED

- [x] FOUND: scripts/tests/test-integrations-foundation.sh (executable bit set, 493 lines)
- [x] FOUND: .planning/phases/32-foundation-schema-migration-cli-installer-library/32-03-SUMMARY.md (this file)
- [x] FOUND in git log: commit d2acbf3 (Task 1 — test + validator path-arg fix)
- [x] FOUND in git log: commit 2a24463 (Task 2 — Makefile + CI wiring)
- [x] FOUND: Test 44 step in Makefile `test:` target between Test 43 and "All tests passed!"
- [x] FOUND: standalone `test-integrations-foundation:` target after `test-install-skills:` in Makefile
- [x] FOUND: `bash scripts/tests/test-integrations-foundation.sh` line in .github/workflows/quality.yml inside Tests 21-44 step
- [x] make check exits 0 (validate-catalog still green; validator now accepts argv[1])
- [x] make test runs all 44 tests + ends with "All tests passed!"
- [x] Existing baselines unchanged: test-mcp-selector PASS=21, test-bootstrap PASS=26, test-update-libs PASS=15
