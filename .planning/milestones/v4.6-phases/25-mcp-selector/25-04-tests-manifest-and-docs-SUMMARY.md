---
phase: 25
plan: "04"
subsystem: test-infra, manifest, docs
tags: [test, manifest, docs, ci, phase-25]
dependency_graph:
  requires: [25-01, 25-02, 25-03]
  provides: [MCP-05, MCP-SEC-02-doc, LIB-01-extended]
  affects: [manifest.json, Makefile, quality.yml, docs/]
tech_stack:
  added: []
  patterns: [hermetic-sandbox-test, makefile-test-target, ci-step-append]
key_files:
  created:
    - scripts/tests/test-mcp-selector.sh
    - docs/MCP-SETUP.md
  modified:
    - manifest.json
    - Makefile
    - .github/workflows/quality.yml
    - docs/INSTALL.md
decisions:
  - "S1–S8 scenarios use fresh per-function SANDBOX via mktemp + RETURN trap (identical to test-install-tui.sh pattern)"
  - "S4/S5 collision tests use real fixture files (printf 'N\\n' > file) — not process substitution — for portability"
  - "S6 wizard hidden-input test runs mcp_wizard_run in a subshell to isolate env from parent test state"
  - "S7 uses TK_MCP_CLAUDE_BIN mock returning empty mcp list so all 9 MCPs show as not-installed (drives would-install rows)"
  - "manifest.json version stays 4.4.0 — version bump deferred to Phase 27 per D-31 convention"
  - "test files (test-mcp-selector.sh, test-mcp-secrets.sh, test-mcp-wizard.sh) NOT added to manifest — they ship via repo, not curl-bash"
metrics:
  duration_minutes: 5
  completed_date: "2026-04-29"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 4
---

# Phase 25 Plan 04: Tests, Manifest, and Docs Summary

Wire Phase 25 deliverables (mcp.sh + mcp-catalog.json + install.sh --mcps) into the toolkit's test, distribution, and documentation surfaces. 21-assertion hermetic test, manifest auto-discovery registration, CI integration, and two doc files.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author test-mcp-selector.sh hermetic test | 145a191 | scripts/tests/test-mcp-selector.sh |
| 2 | Wire manifest + Makefile + CI | e8c0d29 | manifest.json, Makefile, .github/workflows/quality.yml |
| 3 | Create docs/MCP-SETUP.md + update docs/INSTALL.md | e50980e | docs/MCP-SETUP.md, docs/INSTALL.md |

## Assertion Count

`test-mcp-selector.sh` contains **32 `assert_*` invocations** across 8 scenarios, producing **21 runtime assertions** (target was ≥12, expected ~18):

| Scenario | Assertions | Requirements |
|----------|------------|--------------|
| S1: catalog correctness | 3 | MCP-01 |
| S2: three-state detection | 3 | MCP-02 |
| S3: secret persistence + mode 0600 | 4 | MCP-SEC-01 |
| S4: collision default-N | 2 | MCP-SEC-02 |
| S5: collision y-overwrites + no duplicate | 2 | MCP-SEC-02 |
| S6: wizard hidden-input no leak | 2 | MCP-04, MCP-SEC-01 |
| S7: install.sh --mcps --dry-run | 3 | MCP-05, MCP-03 |
| S8: install.sh --mcps no CLI | 2 | MCP-03, MCP-05 |

## manifest.json Insertion

Two entries inserted in alphabetical position between `scripts/lib/install.sh` and `scripts/lib/optional-plugins.sh`:

```text
+    { "path": "scripts/lib/mcp-catalog.json" },
+    { "path": "scripts/lib/mcp.sh" },
```

Final `files.libs[]` order: backup, bootstrap, detect2, dispatch, dry-run-output, install, **mcp-catalog.json**, **mcp.sh**, optional-plugins, state, tui.

## Git Diff Summary

| File | Changes |
|------|---------|
| scripts/tests/test-mcp-selector.sh | +391 −0 (new file) |
| manifest.json | +8 −0 |
| Makefile | +5 −1 |
| .github/workflows/quality.yml | +2 −1 |
| docs/MCP-SETUP.md | +131 −0 (new file) |
| docs/INSTALL.md | +35 −0 |

## Lint Notes

No unexpected markdownlint errors. Both `docs/MCP-SETUP.md` and `docs/INSTALL.md` passed on first attempt:

- MD040: all fenced code blocks tagged (`bash` or `text`)
- MD031/MD032: blank lines before/after all code blocks and lists
- MD026: no trailing punctuation in any heading

## Invariants Confirmed Green

| Test | Result | Requirement |
|------|--------|-------------|
| `bash scripts/tests/test-mcp-selector.sh` | PASS=21 FAIL=0 | MCP-05 |
| `python3 scripts/validate-manifest.py` | PASSED | manifest schema |
| `bash scripts/tests/test-update-libs.sh` | PASS=15 FAIL=0 | LIB-01 D-07 |
| `bash scripts/tests/test-bootstrap.sh` | PASS=26 FAIL=0 | BOOTSTRAP-01..04 |
| `bash scripts/tests/test-install-tui.sh` | PASS=38 FAIL=0 | TUI-01..09 |
| `make check` | All checks passed | CI gate |
| `markdownlint docs/MCP-SETUP.md docs/INSTALL.md` | 0 errors | markdown quality |

## Deviations from Plan

None — plan executed exactly as written. The only adjustment was that S4 and S5 each used their own fresh SANDBOX (per-function isolation) rather than sharing S3's SANDBOX, which is consistent with the hermetic test pattern from `test-install-tui.sh` and produces cleaner test isolation.

## Known Stubs

None. All 9 MCPs are wired from the real `mcp-catalog.json`; all test scenarios use actual `mcp.sh` function implementations.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns outside `~/.claude/mcp-config.env` (already documented in MCP-SEC-01), or schema changes introduced by this plan.

## Self-Check: PASSED

All created files exist on disk. All three task commits verified in git log:

- `145a191` test(25-04): add hermetic test-mcp-selector.sh
- `e8c0d29` chore(25-04): wire manifest + Makefile Test 32 + CI Tests 21-32
- `e50980e` docs(25-04): add MCP-SETUP.md and --mcps flag subsection in INSTALL.md
