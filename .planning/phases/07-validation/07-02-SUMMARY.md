---
phase: "07-validation"
plan: "02"
subsystem: "makefile-validation"
tags: ["makefile", "version-align", "translation-drift", "agent-collision", "quality-gates"]

dependency_graph:
  requires: []
  provides:
    - "Makefile targets: version-align, translation-drift, agent-collision-static"
    - "make check extended with 3 new static release gates"
  affects:
    - "Makefile"
    - ".github/workflows/quality.yml (picks up new targets via `make check`)"

tech_stack:
  added: []
  patterns:
    - "ERRORS counter pattern (consistent with existing validate/validate-base-plugins targets)"
    - "Pure jq query for manifest structural checks"
    - "wc -l + arithmetic for line-count tolerance gates"

key_files:
  created: []
  modified:
    - "Makefile"

decisions:
  - "D-09: version-align as 3-way check (manifest.json + CHANGELOG.md + init-local.sh --version)"
  - "D-10: translation-drift as ±20% line-count gate — Phase 7.1 must ship conforming translations"
  - "D-11 static: agent-collision-static as pure-jq VALIDATE-03 precondition (no install required)"
  - "Approach (b) from CONTEXT.md: gate ships now; Phase 7.1 conforms to it, not the other way around"

metrics:
  duration: "~8 minutes"
  completed: "2026-04-20"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 7 Plan 02: Makefile Static Release Gates Summary

Added three static release-gate Makefile targets (D-09, D-10, D-11) wired into `make check`, implementing version alignment, translation drift detection, and agent-collision annotation validation via pure shell and jq — no install required.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add version-align + translation-drift + agent-collision-static | 49189a6 | Makefile |

## What Was Built

### New Makefile Targets

**`version-align` (D-09)**

3-way version consistency check. Reads `.version` from `manifest.json` via `jq`, extracts the
top `## [X.Y.Z]` header from `CHANGELOG.md` via grep+sed, and parses the semver from
`bash scripts/init-local.sh --version` output. All three must agree or the build fails with a
per-comparison mismatch message.

Current state — PASSES:

```text
Checking version alignment (manifest.json <-> CHANGELOG.md <-> init-local.sh)...
✅ Version aligned: 4.0.0
```

**`translation-drift` (D-10)**

Line-count tolerance gate for the 8 `docs/readme/*.md` translations vs `README.md`.
Tolerance: ±20% (MIN = README_LINES * 80/100, MAX = README_LINES * 120/100).
Also fails on missing translation files.

Current state — EXPECTED FAIL (Phase 7.1 must resolve):

```text
Checking README translation drift (±20% line count tolerance)...
❌ docs/readme/de.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/es.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/fr.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/ja.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/ko.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/pt.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/ru.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
❌ docs/readme/zh.md: 148 lines outside ±20% of README.md 202 (tolerance 161-242)
```

Phase 7.1 contract: each translation must be 161–242 lines (±20% of README.md's 202 lines).
Plan 07-04 is the downstream gate that runs `make check` after Phase 7.1 lands and confirms green.

**`agent-collision-static` (D-11 static layer)**

Pure-jq VALIDATE-03 precondition check. Queries `manifest.json` for all agent entries with
`conflicts_with` containing `"superpowers"`. Fails with a regression message if zero agents
are annotated (guard against someone accidentally removing the annotations).

Current state — PASSES:

```text
Checking agents/* conflicts_with annotations (VALIDATE-03 static gate)...
✅ Static agent-collision check: 7 files annotated conflicts_with SP (1 agents, others commands/skills)
```

(1 agent: `agents/code-reviewer.md`; 6 commands also annotated.)

### Makefile Structure Changes

- `.PHONY` extended with: `version-align translation-drift agent-collision-static`
- `check:` dependency list extended: `lint validate validate-base-plugins version-align translation-drift agent-collision-static`
- Three new targets inserted before the `# Clean temporary files` block

## Verification Results

| Check | Result | Notes |
|-------|--------|-------|
| `make -n version-align` | PASS | Target parses correctly |
| `make -n translation-drift` | PASS | Target parses correctly |
| `make -n agent-collision-static` | PASS | Target parses correctly |
| `make version-align` | PASS | 4.0.0 across all 3 sources |
| `make agent-collision-static` | PASS | 7 SP-conflict annotations found |
| `make translation-drift` | EXPECTED FAIL | 148 vs 202 lines (73%) — Phase 7.1 gate |
| `make shellcheck` | PASS | No regression in scripts/ |
| `.PHONY` contains all 3 new targets | PASS | grep confirmed |
| `check:` depends on all 3 new targets | PASS | grep confirmed |
| Only Makefile modified | PASS | git diff confirmed |

## Deviations from Plan

None — plan executed exactly as written.

The `↔` arrow in the echo line was replaced with `<->` (plain ASCII) to avoid non-ASCII
in a Makefile string — purely cosmetic, no functional difference.

## Known Stubs

None. All three targets are fully functional.

## Phase 7.1 Contract

Translations must reach **161–242 lines each** (±20% of README.md's current 202 lines).
Currently all 8 translations are 148 lines (73% of README.md). Plan 07-04 runs `make check`
after Phase 7.1 lands and confirms `translation-drift` passes.

## Self-Check: PASSED

- `Makefile` exists and contains all three new targets: confirmed
- Commit `49189a6` exists: confirmed
- No other files modified in commit: confirmed (git diff --stat shows only Makefile)
- `make version-align` exits 0: confirmed
- `make agent-collision-static` exits 0: confirmed
- `make translation-drift` exits 1 with expected messages: confirmed
