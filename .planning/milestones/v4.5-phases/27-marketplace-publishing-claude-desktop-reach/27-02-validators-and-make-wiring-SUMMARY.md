---
phase: 27
plan: "02"
subsystem: marketplace
requirements_completed: [MKT-03, DESK-02, DESK-04]
tags: [validation, shellcheck, makefile, ci, desktop-compatibility, marketplace]

dependency_graph:
  requires:
    - phase: "27-01"
      provides: ".claude-plugin/marketplace.json and 3 sub-plugin trees"
  provides:
    - scripts/validate-skills-desktop.sh (DESK-02 heuristic scanner + DESK-04 threshold gate)
    - scripts/validate-marketplace.sh (MKT-03 smoke; gated by TK_HAS_CLAUDE_CLI)
    - make validate-skills-desktop target wired into make check
    - make validate-marketplace target wired into make check
    - CI step in quality.yml for validate-skills-desktop
  affects: [make check, .github/workflows/quality.yml]

tech_stack:
  added: []
  patterns:
    - "Env-var-gated validator: TK_HAS_CLAUDE_CLI=1 enables smoke; unset = [skipped] + exit 0"
    - "Runtime artifact gitignored: .audit-skills-desktop.txt generated per run, excluded from repo"
    - "Heuristic FLAG regex: (Read|Write|Bash|Grep|Edit|Task)\\( | Use (the)? (Read|Bash|Write) tool"

key_files:
  created:
    - scripts/validate-skills-desktop.sh
    - scripts/validate-marketplace.sh
  modified:
    - Makefile
    - .github/workflows/quality.yml
    - .gitignore

key_decisions:
  - "validate-marketplace skips in CI (no claude CLI on runners) — TK_HAS_CLAUDE_CLI=1 guards the real smoke"
  - "validate-skills-desktop runs unconditionally in CI as the DESK-04 regression gate"
  - "DESK-04 threshold of >=4 PASS is intentionally conservative: current state is PASS=20, FLAG=2"
  - "Artifact .audit-skills-desktop.txt is gitignored to avoid noise in git status"

patterns_established:
  - "Env-var gate pattern for CI-incompatible tools: TK_HAS_CLAUDE_CLI=1 enables; unset = [skipped] + exit 0"
  - "Heuristic scanners write a per-run .audit-*.txt artifact (gitignored) for diffing"

metrics:
  duration_minutes: 4
  tasks_completed: 2
  files_created: 2
  files_modified: 3
  completed_date: "2026-04-29"
---

# Phase 27 Plan 02: Validators and Make Wiring Summary

**Desktop-safety heuristic scanner (DESK-02/DESK-04) and marketplace smoke validator (MKT-03)
wired into `make check` and CI, confirming 20/22 skills are Desktop-compatible.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-29T14:33:39Z
- **Completed:** 2026-04-29T14:37:49Z
- **Tasks:** 2
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- `scripts/validate-skills-desktop.sh` — DESK-02 heuristic scans every
  `templates/skills-marketplace/*/SKILL.md`; DESK-04 gate exits 1 if fewer than 4 PASS
- `scripts/validate-marketplace.sh` — MKT-03 smoke wraps `claude plugin marketplace add ./`;
  exits 0 with `[skipped]` notice when `TK_HAS_CLAUDE_CLI` is unset (CI-safe)
- Makefile extended: both targets added to `.PHONY` and to the `check:` dependency chain
- CI `quality.yml` extended: dedicated `DESK-02/DESK-04` step runs `make validate-skills-desktop`
- `make check` passes end-to-end with both new validators included

## Audit Results at Plan Completion

| Verdict | Count | Skills |
|---------|-------|--------|
| PASS (Desktop-safe) | 20 | ai-models, analytics-tracking, chrome-extension-development, copywriting, docx, find-skills, i18n-localization, memo-skill, next-best-practices, notebooklm, pdf, resend, seo-audit, stripe-best-practices, tailwind-design-system, typescript-advanced-types, ui-ux-pro-max, vercel-composition-patterns, vercel-react-best-practices, webapp-testing |
| FLAG (Code-only) | 2 | firecrawl, shadcn |

DESK-04 threshold: >= 4 PASS required. Current: 20 PASS — gate is green.

## Marketplace Smoke Status

`TK_HAS_CLAUDE_CLI=1 make validate-marketplace` — **not exercised locally** (claude CLI not
available in this environment). The validator's skip path (exit 0 with `[skipped]`) is confirmed
working. Full smoke deferred to maintainer run with claude CLI on PATH.

## Task Commits

1. **Task 1: Create validate-skills-desktop.sh + .gitignore** — `9993f7a` (feat)
2. **Task 2: Create validate-marketplace.sh + wire Makefile + CI** — `3ae5e94` (feat)

## Files Created/Modified

- `scripts/validate-skills-desktop.sh` — DESK-02 heuristic scanner; DESK-04 threshold gate (>=4 PASS)
- `scripts/validate-marketplace.sh` — MKT-03 smoke wrapper gated by TK_HAS_CLAUDE_CLI=1
- `Makefile` — Added validate-skills-desktop and validate-marketplace to .PHONY and check chain
- `.github/workflows/quality.yml` — Added DESK-02/DESK-04 step before REL-02 cell-parity step
- `.gitignore` — Added `.audit-skills-desktop.txt` exclusion

## Decisions Made

- validate-marketplace uses `TK_HAS_CLAUDE_CLI=1` guard so it remains in `make check` without
  breaking CI runners that lack the claude binary
- validate-skills-desktop runs unconditionally in CI as a regression gate for Desktop reach
- DESK-04 threshold kept at 4 (conservative) — well below current 20 PASS, designed to catch
  future regressions when new Code-only skills are added to the mirror

## Deviations from Plan

None — plan executed exactly as written. Both scripts shellcheck-clean on first attempt.
The FLAG_NAMES/PASS_NAMES empty-array handling used `${arr[@]+"${arr[@]}"}` idiom which
shellcheck accepted without SC2068 warnings.

## Known Stubs

None. Both validators are fully wired and produce correct output. The marketplace smoke
requires an external tool (claude CLI) which is documented as a maintainer-only step.

## Threat Flags

None. Both scripts are read-only validators that scan the local filesystem. No network
endpoints, auth paths, or trust boundaries introduced.

## Issues Encountered

ANSI escape codes in script output interfered with verification grep patterns during Task 1
verification. Resolution: used `grep -oE` pattern matching on unescaped substrings instead
of full-line matches with `^` anchors.

## Next Phase Readiness

Phase 27 Plan 02 complete. Both validators are wired. The marketplace surface (Plan 01) and
its validation gates (Plan 02) are in place. Phase 27 milestone deliverables fulfilled:

- MKT-01: marketplace.json with 3 sub-plugins (Plan 01)
- MKT-02: single version source-of-truth in plugin.json (Plan 01)
- MKT-03: validate-marketplace.sh gated smoke (Plan 02)
- DESK-02: validate-skills-desktop.sh heuristic scanner (Plan 02)
- DESK-04: DESK-04 threshold gate >= 4 PASS (Plan 02)

---

*Phase: 27-marketplace-publishing-claude-desktop-reach*
*Completed: 2026-04-29*

## Self-Check: PASSED

- [x] `scripts/validate-skills-desktop.sh` exists, executable, exits 0 (PASS=20 >= 4)
- [x] `scripts/validate-marketplace.sh` exists, executable, exits 0 with `[skipped]`
- [x] `shellcheck -S warning` passes on both scripts (zero warnings)
- [x] `.audit-skills-desktop.txt` in `.gitignore`
- [x] `grep -c validate-skills-desktop Makefile` = 4 (>= 3 required)
- [x] `grep validate-skills-desktop .github/workflows/quality.yml` = 1 match
- [x] `python3 -c "import yaml; yaml.safe_load(...)"` exits 0 on quality.yml
- [x] `make check` exits 0 with "All checks passed!"
- [x] Commits 9993f7a and 3ae5e94 exist in git log
