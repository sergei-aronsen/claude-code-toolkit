---
phase: 31-distribution-tests-docs
plan: "02"
subsystem: tests
tags: [bridge-tests, ci, aggregator, BRIDGE-TEST-01]
dependency_graph:
  requires: []
  provides: [BRIDGE-TEST-01]
  affects: [.github/workflows/quality.yml]
tech_stack:
  added: []
  patterns: [aggregator-meta-runner, tail-parse-pass-fail]
key_files:
  created:
    - scripts/tests/test-bridges.sh
  modified:
    - .github/workflows/quality.yml
decisions:
  - "Aggregator wraps 3 child suites rather than rewriting into one monolithic file — mirrors v4.4 test-update-libs.sh pattern"
  - "tail -1 | grep -oE 'PASS=[0-9]+' | tail -1 | cut -d= -f2 handles all 3 distinct output formats from child suites"
  - "Appended to validate-templates job Tests 21-33 run: block (not test-init-script) — same job as test-update-libs.sh and test-install-tui.sh"
metrics:
  duration: "< 5 minutes"
  completed: "2026-04-29"
  tasks_completed: 2
  files_changed: 2
---

# Phase 31 Plan 02: Bridge Aggregator Test + CI Summary

Thin aggregator `scripts/tests/test-bridges.sh` wraps the 3 existing hermetic bridge suites, reports combined `PASS=50 FAIL=0`, and is wired into the CI `validate-templates` job's `Tests 21-34` step.

## What Was Built

### scripts/tests/test-bridges.sh (25 lines)

New file — the BRIDGE-TEST-01 aggregator. Structure:

- `#!/bin/bash` + `set -euo pipefail`
- `cd "$(dirname "$0")/.."` to anchor to repo root regardless of invocation CWD
- `for suite in test-bridges-foundation.sh test-bridges-sync.sh test-bridges-install-ux.sh` — no arrays, Bash 3.2 compatible
- Each child is run with `bash "tests/$suite" >/tmp/bridges-out.$$ 2>&1` — PID-suffixed temp file avoids parallel collisions
- On success: parses last line with `grep -oE 'PASS=[0-9]+' | tail -1 | cut -d= -f2` to extract counts
- On failure: prints captured output and increments `FAIL` by 1 (child crash is visible AND counted)
- Final line: `test-bridges (aggregate) complete: PASS=$PASS FAIL=$FAIL`
- Exit 1 if `FAIL -ne 0`

### The parsing trick (key design decision)

The 3 child suites emit 3 different final-line formats:

| Suite | Final line format |
|-------|------------------|
| test-bridges-foundation.sh | `test-bridges-foundation complete: PASS=5 FAIL=0` |
| test-bridges-sync.sh | `Phase 29 sync test complete: PASS=25 FAIL=0` |
| test-bridges-install-ux.sh | `PASS=20 FAIL=0` |

The chain `grep -oE 'PASS=[0-9]+' | tail -1 | cut -d= -f2` handles all three:

- `grep -oE 'PASS=[0-9]+'` extracts the `PASS=N` token from anywhere in the line
- `| tail -1` guards against any internal PASS= strings in scenario output (takes only the last match)
- `| cut -d= -f2` strips the `PASS=` prefix, leaving just the integer

Identical chain for `FAIL=[0-9]+`.

### .github/workflows/quality.yml

Two-line change to the `validate-templates` job:

- Step name: `Tests 21-33` → `Tests 21-34`, appended `+ bridges aggregate` and `, BRIDGE-TEST-01` to parenthetical
- Final line of `run: |` block: `bash scripts/tests/test-bridges.sh` (10-space indentation matching the 13 preceding lines)

CI edit region: lines 109–124 (was 109–123). The bridge aggregator lives in the same job as `test-update-libs.sh` (LIB-01) and `test-install-tui.sh` (TUI-01..09) — not in `test-init-script` (which is a matrix job testing `init-local.sh` against synthetic Laravel/Next.js projects).

## Verification Results

```text
bash scripts/tests/test-bridges.sh | tail -1
→ test-bridges (aggregate) complete: PASS=50 FAIL=0

shellcheck -S warning scripts/tests/test-bridges.sh
→ (exit 0, no warnings)

test -x scripts/tests/test-bridges.sh
→ (exit 0)
```

BACKCOMPAT-01 — all 5 v4.6 baselines still green:

| Suite | Expected | Actual |
|-------|----------|--------|
| test-bridges-foundation.sh | PASS=5 FAIL=0 | PASS=5 FAIL=0 |
| test-bridges-sync.sh | PASS=25 FAIL=0 | PASS=25 FAIL=0 |
| test-bridges-install-ux.sh | PASS=20 FAIL=0 | PASS=20 FAIL=0 |
| test-bootstrap.sh | PASS=26 FAIL=0 | PASS=26 FAIL=0 |
| test-install-tui.sh | PASS=43 FAIL=0 | PASS=43 FAIL=0 |

CI YAML valid: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` exits 0.

## BRIDGE-TEST-01 Coverage

The aggregated 50 assertions cover:

- Plain-copy semantics on fresh install (foundation)
- Idempotency on re-run (foundation)
- Drift `[y/N/d]` prompt behavior (sync)
- `--break-bridge` persistence across update cycles (sync)
- `--no-bridges` / `TK_NO_BRIDGES=1` opt-out (install-ux)
- `--bridges gemini,codex` force-create (install-ux)
- `--fail-fast` on missing CLI (install-ux)
- Uninstall round-trip removes bridge artifacts (install-ux)

Total: 50 assertions — exceeds ROADMAP's ≥15 minimum by 3.3x.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Create aggregator | 4c6a6ce | scripts/tests/test-bridges.sh |
| Task 2: Wire into CI | 8b5c003 | .github/workflows/quality.yml |

## Self-Check: PASSED

- `scripts/tests/test-bridges.sh` — confirmed exists, executable, correct content
- `4c6a6ce` — confirmed in git log
- `8b5c003` — confirmed in git log
- YAML valid, PASS=50 FAIL=0 confirmed empirically
