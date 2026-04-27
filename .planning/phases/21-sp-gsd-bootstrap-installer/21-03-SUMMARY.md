---
phase: 21-sp-gsd-bootstrap-installer
plan: "03"
subsystem: bootstrap
tags: [bootstrap, tests, ci, docs, makefile, quality-gates, shell]
dependency_graph:
  requires:
    - scripts/lib/bootstrap.sh (plan 21-01)
    - scripts/init-local.sh --no-bootstrap wiring (plan 21-02)
    - scripts/init-claude.sh --no-bootstrap wiring (plan 21-02)
  provides:
    - scripts/tests/test-bootstrap.sh (5-scenario hermetic integration test, 26 assertions)
    - Makefile Test 28 invocation block
    - .github/workflows/quality.yml Tests 21-28 CI step
    - docs/INSTALL.md ## Installer Flags section + ### --no-bootstrap (v4.4+) subsection
  affects:
    - Phase 21 complete (all 3 plans shipped)
tech_stack:
  added: []
  patterns:
    - sandbox-HOME + seam-env-var test idiom (Phase 18/19 uninstall suite pattern)
    - mk_mock helper for mock script creation (printf '%q' for safe quoting)
    - SANDBOX parameter-length guard (${SANDBOX:?}) in trap RETURN (T-21-07 defense-in-depth)
    - assert_eq / assert_contains / assert_not_contains helper suite
    - --dry-run base flag to skip interactive framework selection in test driver
key_files:
  created:
    - scripts/tests/test-bootstrap.sh
  modified:
    - Makefile
    - .github/workflows/quality.yml
    - docs/INSTALL.md
decisions:
  - "Use --dry-run base as test driver flags so init-local.sh exits cleanly without writing files or needing framework detection"
  - "S3 invokes init-local.sh twice (CLI flag form + env-var form) to prove D-16 equivalence without extra scenario functions"
  - "S4 uses PATH=/usr/bin:/bin to exclude any system claude binary — avoids real-claude interference in CI"
  - "S1 assertion 'standalone' checks dry-run output's Install mode line — mocks don't create SP/GSD dirs so post-bootstrap detect resolves standalone"
  - "Assertion count 26 (not target 25) due to the extra TK_NO_BOOTSTRAP=1 assertion in S3 second invocation"
metrics:
  duration: 12m
  completed: "2026-04-27T08:00:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 3
---

# Phase 21 Plan 03: Tests, CI Wiring, and Docs Summary

**One-liner:** Hermetic 5-scenario bootstrap integration test (26 assertions) wired into Makefile Test 28 and CI quality.yml Tests 21-28 step; `--no-bootstrap` documented in docs/INSTALL.md with flag table and subsection.

## What Was Built

### Task 1 — Create `scripts/tests/test-bootstrap.sh`

New 261-line hermetic integration test file covering all 5 scenarios from CONTEXT.md D-20:

| Scenario | Coverage | Assertions |
|----------|----------|-----------|
| S1 — y/y → mocks invoked | SP + GSD mocks run, exit 0, mode=standalone | 5 |
| S2 — N/N → no mocks | Neither mock invoked, exit 0, no failure warning | 5 |
| S3 — --no-bootstrap byte-quiet + TK_NO_BOOTSTRAP=1 | No prompts in output, D-16/D-17 byte-quiet, env-var equivalence | 6 |
| S4 — claude CLI missing | SP prompt suppressed with warn, GSD still runs | 5 |
| S5 — SP fails (exit 1) | Non-fatal, failure warning + exit code shown, GSD independent | 5 |

Total: 26 assertions (target was ~25).

Key implementation choices:
- Driver: `bash init-local.sh --dry-run base` — no GitHub curl, no file writes, no interactive framework selection
- Seam env vars: `TK_BOOTSTRAP_SP_CMD`, `TK_BOOTSTRAP_GSD_CMD`, `TK_BOOTSTRAP_TTY_SRC`, `TK_NO_BOOTSTRAP`
- Each scenario: `mktemp -d` sandbox, `trap "rm -rf '${SANDBOX:?}'" RETURN` cleanup, isolated `HOME`
- `mk_mock` helper uses `printf '%q'` to safely quote message strings
- S4 uses `PATH="/usr/bin:/bin"` to deliberately exclude any real `claude` binary

Lint results:
- `bash -n scripts/tests/test-bootstrap.sh` — exits 0
- `shellcheck -S warning scripts/tests/test-bootstrap.sh` — exits 0
- End-to-end: `bash scripts/tests/test-bootstrap.sh` — PASS=26 FAIL=0

### Task 2 — Wire into Makefile and CI

**Makefile edit:** Inserted Test 28 block between Test 27 and the final `All tests passed!` line:

```makefile
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "All tests passed!"
```

TAB-indented recipe verified (od -c shows `\t` as first character). `make -n test` parses cleanly. `make test` exits 0.

**quality.yml edit:** Step renamed from `Tests 21-27 — uninstall + banner suite (UN-01..UN-08)` to `Tests 21-28 — uninstall + banner suite + bootstrap (UN-01..UN-08, BOOTSTRAP-01..04)`. `bash scripts/tests/test-bootstrap.sh` appended as the last command in the `run:` block. YAML validates via `python3 -c 'import yaml; yaml.safe_load(...)'`.

`make test` runtime: ~90 seconds for all 28 tests (all pass).

### Task 3 — Document `--no-bootstrap` in `docs/INSTALL.md`

Added a new `## Installer Flags` section (line 29, between `---` after Modes Overview and `## Mode: standalone`):

- Flag table covering `--dry-run`, `--mode`, `--force`, `--force-mode-change`, `--no-bootstrap`, `--no-council`
- `### --no-bootstrap (v4.4+)` subsection explaining: default behavior, CLI flag form, `TK_NO_BOOTSTRAP=1` env-var form, non-interactive note about piped installs

File grew from 91 to 119 lines (+28 lines). `make mdlint` passes. MD026/MD031/MD032/MD040 all clean.

D-18 three-surface coverage confirmed:

| Surface | Evidence |
|---------|---------|
| `init-claude.sh` unknown-arg flag list | `--no-bootstrap` listed in error message echo (plan 21-02) |
| `init-local.sh --help` | `bash scripts/init-local.sh --help \| grep -- '--no-bootstrap'` prints 2 matches |
| `docs/INSTALL.md` | 4 occurrences of `--no-bootstrap` in the new section |

## Verification Results

### Final Phase Verification (all 5 blocks)

```text
Block 1 — Lint and structural:
PASS: make shellcheck
PASS: make mdlint
PASS: bash -n scripts/tests/test-bootstrap.sh
PASS: make -n test

Block 2 — Bootstrap test in isolation:
PASS: bash scripts/tests/test-bootstrap.sh → Bootstrap test complete: PASS=26 FAIL=0

Block 3 — Full make test:
PASS: make test → exit 0 (28 tests total, ~90s)

Block 4 — Documentation reachability:
PASS: init-local.sh --help | grep -- '--no-bootstrap' → 2 matches
PASS: grep -- '--no-bootstrap' docs/INSTALL.md → 4 matches

Block 5 — CI mirror simulation (8 tests sequentially):
PASS: test-uninstall-dry-run.sh
PASS: test-uninstall-backup.sh
PASS: test-uninstall-prompt.sh
PASS: test-uninstall.sh
PASS: test-install-banner.sh
PASS: test-uninstall-idempotency.sh
PASS: test-uninstall-state-cleanup.sh
PASS: test-bootstrap.sh
```

### make check

```text
PASS: make check → All checks passed!
(shellcheck + markdownlint + validate + validate-base-plugins + version-align +
 translation-drift + agent-collision-static + validate-commands + cell-parity)
```

## Deviations from Plan

### Minor — Assertion count 26 instead of target 25

The plan spec said "~25 assertions (5 per scenario)". S3 invokes `init-local.sh` twice (CLI flag form + env-var form) and has 6 assertions (5 for the first invocation + 1 for the TK_NO_BOOTSTRAP=1 equivalence check). This is within the plan's acceptance criteria range (23-28 inclusive) and was explicitly planned in the task description ("6 assertions" for S3). No behavioral deviation.

No other deviations. Plan executed as written.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data flows introduced.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The test file operates entirely within `mktemp -d` sandboxes cleaned up via `trap RETURN`. The `mk_mock` / `printf '%q'` pattern is T-21-08 accepted (static literal strings only). No new trust boundaries beyond what the plan's `<threat_model>` documents.

## Self-Check: PASSED

All artifacts confirmed present and committed:

- `scripts/tests/test-bootstrap.sh` exists (commit bc4d011, 261 lines, PASS=26 FAIL=0)
- `Makefile` modified — Test 28 block present (commit 57cb03a)
- `.github/workflows/quality.yml` modified — Tests 21-28 step present (commit 57cb03a)
- `docs/INSTALL.md` modified — ## Installer Flags + ### --no-bootstrap sections present (commit c12b671)
- `make check` exits 0
- `make test` exits 0 (28 tests)
- All five phase-verification blocks pass
