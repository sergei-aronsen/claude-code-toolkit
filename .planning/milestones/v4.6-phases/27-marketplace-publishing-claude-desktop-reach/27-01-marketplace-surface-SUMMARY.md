---
phase: 27
plan: "01"
subsystem: marketplace
requirements_addressed: [MKT-01, MKT-02]
tags: [marketplace, plugins, symlinks, distribution]
dependency_graph:
  requires: []
  provides: [.claude-plugin/marketplace.json, plugins/tk-skills, plugins/tk-commands, plugins/tk-framework-rules]
  affects: [make check, .markdownlintignore]
tech_stack:
  added: []
  patterns: [relative-symlinks, plugin-manifest-schema]
key_files:
  created:
    - .claude-plugin/marketplace.json
    - plugins/tk-skills/.claude-plugin/plugin.json
    - plugins/tk-commands/.claude-plugin/plugin.json
    - plugins/tk-framework-rules/.claude-plugin/plugin.json
  modified:
    - .markdownlintignore
symlinks_created:
  - path: plugins/tk-skills/skills
    target: ../../templates/skills-marketplace
  - path: plugins/tk-skills/LICENSE
    target: ../../LICENSE
  - path: plugins/tk-commands/commands
    target: ../../commands
  - path: plugins/tk-framework-rules/templates
    target: ../../templates
decisions:
  - "Version declared once in plugin.json (4.6.0) — not duplicated in marketplace.json (per MKT-02 single-source-of-truth)"
  - "Symlinks use relative paths (../../) for portability across clones and CI worktrees"
  - "plugins/ excluded from markdownlint to prevent double-scanning third-party content through symlinks"
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_created: 4
  symlinks_created: 4
  completed_date: "2026-04-29"
---

# Phase 27 Plan 01: Marketplace Surface Summary

**One-liner:** Marketplace plugin manifest + 3 sub-plugin trees with relative symlinks
enabling `claude plugin marketplace add sergei-aronsen/claude-code-toolkit` discovery.

## What Was Built

- `.claude-plugin/marketplace.json` — repo-root marketplace manifest declaring 3 sub-plugins
  (`tk-skills`, `tk-commands`, `tk-framework-rules`) with `name` + `source` only (no embedded versions)
- `plugins/tk-skills/.claude-plugin/plugin.json` — v4.6.0, category `skills`, tags `[mirror, marketplace, desktop-compatible]`
- `plugins/tk-commands/.claude-plugin/plugin.json` — v4.6.0, category `commands`, tags `[slash-commands, code-only]`
- `plugins/tk-framework-rules/.claude-plugin/plugin.json` — v4.6.0, category `rules`, tags `[framework-templates, code-only]`
- 4 relative symlinks connecting sub-plugin trees to canonical repo content

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | ed35008 | feat(27-01): add marketplace.json + 3 sub-plugin manifests |
| Task 2 | 3d168c8 | feat(27-01): add symlink trees for marketplace sub-plugins |
| Fix | 0307b57 | fix(27-01): exclude plugins/ from markdownlint |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Add plugins/ to .markdownlintignore**

- **Found during:** Task 2 verification (`make check`)
- **Issue:** The `plugins/tk-framework-rules/templates` symlink resolves to `../../templates`,
  which includes `templates/skills-marketplace/`. Markdownlint followed the symlink and reported
  hundreds of third-party content violations — the same content already excluded via
  `templates/skills-marketplace/` in `.markdownlintignore`. The exclusion pattern did not match
  the symlinked path `plugins/tk-framework-rules/templates/skills-marketplace/`.
- **Fix:** Added `plugins/` blanket exclusion to `.markdownlintignore` with comment explaining
  that plugins/ is distribution-artifact tree (symlinks), not authored markdown.
- **Files modified:** `.markdownlintignore`
- **Commit:** 0307b57

## Known Stubs

None. All plugin.json manifests declare real version, category, tags, and description.
Symlinks resolve to existing content (22 skills, 29 commands, 7 framework templates).

## Threat Flags

None. This plan creates JSON manifests and filesystem symlinks — no network endpoints,
auth paths, or trust boundaries introduced.

## Marketplace Smoke Validation

`claude plugin marketplace add ./` validation is gated to Plan 02 (requires `claude` CLI
on PATH; CI runner does not have it). Plan 02 adds `make validate-marketplace` with
`TK_HAS_CLAUDE_CLI=1` guard and skip notice for CI.

## Self-Check

- [x] `.claude-plugin/marketplace.json` exists, `jq '.plugins | length'` = 3
- [x] All 3 `plugin.json` files have `"version": "4.6.0"` and correct category/tags
- [x] `jq -e '.plugins[] | has("version")' .claude-plugin/marketplace.json` exits non-zero (no embedded versions)
- [x] 4 symlinks: `plugins/tk-skills/skills`, `plugins/tk-skills/LICENSE`, `plugins/tk-commands/commands`, `plugins/tk-framework-rules/templates`
- [x] All symlinks use relative paths (verified with `readlink`)
- [x] Git records symlinks as mode `120000`
- [x] `ls plugins/tk-skills/skills/ | wc -l` = 22 (all skills accessible)
- [x] `find plugins -name plugin.json | wc -l` = 3
- [x] `find plugins -type l | wc -l` = 4
- [x] `make check` passes (ShellCheck + Markdownlint + validate)
- [x] Commits ed35008, 3d168c8, 0307b57 exist in git log

## Self-Check: PASSED
