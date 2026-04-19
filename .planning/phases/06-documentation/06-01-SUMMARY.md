---
phase: 06-documentation
plan: "01"
subsystem: documentation
tags: [changelog, readme, templates, install-matrix, makefile, drift-guard]
dependency_graph:
  requires: []
  provides:
    - CHANGELOG [4.0.0] entry with BREAKING CHANGES block
    - README complement-first install section (DOCS-01)
    - Required Base Plugins block in all 7 templates (DOCS-02)
    - manifest.json version 4.0.0
    - docs/INSTALL.md 12-cell matrix (DOCS-04)
    - Makefile validate-base-plugins drift guard
  affects:
    - README.md
    - CHANGELOG.md
    - manifest.json
    - templates/*/CLAUDE.md (x7)
    - docs/INSTALL.md
    - Makefile
tech_stack:
  added: []
  patterns:
    - Keep-a-Changelog 1.0.0 BREAKING CHANGES-first entry shape
    - Verbatim canonical block across 7 template files (drift mitigated by Makefile guard)
    - 12-cell install matrix (4 modes x 3 scenarios)
key_files:
  created:
    - docs/INSTALL.md
  modified:
    - README.md
    - CHANGELOG.md
    - manifest.json
    - templates/base/CLAUDE.md
    - templates/laravel/CLAUDE.md
    - templates/rails/CLAUDE.md
    - templates/nextjs/CLAUDE.md
    - templates/nodejs/CLAUDE.md
    - templates/python/CLAUDE.md
    - templates/go/CLAUDE.md
    - Makefile
decisions:
  - CHANGELOG [4.0.0] entry uses BREAKING CHANGES block before Added/Changed/Fixed per Keep-a-Changelog + D-CHG-01 from CONTEXT.md
  - Required Base Plugins block copied verbatim across 7 templates (Option A from research §5) — single canonical block per CONTEXT.md with Makefile drift guard
  - docs/INSTALL.md is standalone file not inline README section — 12-cell matrix too dense for landing README
  - SP install string locked to superpowers@claude-plugins-official; GSD install string locked to raw.githubusercontent.com/gsd-build/get-shit-done per CONTEXT.md decisions lines 62-66
metrics:
  duration_minutes: 8
  completed_date: "2026-04-19"
  tasks_completed: 5
  tasks_total: 5
  files_modified: 11
---

# Phase 06 Plan 01: Core Documentation and Templates Summary

**One-liner:** CHANGELOG [4.0.0] with 8 BREAKING CHANGES, README complement-first positioning, verbatim Required Base Plugins block in all 7 templates, 12-cell install matrix in docs/INSTALL.md, and Makefile drift guard — all passing `make check`.

## Requirements Satisfied

- **DOCS-01:** README repositions TK as complement to superpowers + get-shit-done; install section shows both standalone and complement modes with one paragraph of guidance per mode.
- **DOCS-02:** All 7 `templates/*/CLAUDE.md` files contain `## Required Base Plugins` section with CONTEXT.md-locked SP/GSD install strings.
- **DOCS-03:** CHANGELOG `[4.0.0]` entry with BREAKING CHANGES block (8 items); `manifest.json` version bumped to `4.0.0`; version alignment verified.
- **DOCS-04:** `docs/INSTALL.md` exists with full 12-cell matrix (4 modes x 3 scenarios) plus Migration from v3.x section.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | CHANGELOG [4.0.0] entry + manifest version bump | c5c8cbc | CHANGELOG.md, manifest.json |
| 2 | README complement-first install section (DOCS-01) | b3a79f8 | README.md |
| 3 | Required Base Plugins block in all 7 templates (DOCS-02) | edc6bf1 | templates/*/CLAUDE.md (x7) |
| 4 | docs/INSTALL.md 12-cell install matrix (DOCS-04) | 7eebc33 | docs/INSTALL.md |
| 5 | Makefile validate-base-plugins drift guard | a16d6b5 | Makefile |

## Verification Results

### make check (final run)

```text
Running ShellCheck...
✅ ShellCheck passed
Running markdownlint...
✅ Markdownlint passed
All checks passed!
Validating templates...
✅ All templates valid
Validating Required Base Plugins section across 7 templates...
✅ All 7 templates carry ## Required Base Plugins
All checks passed!
```

### Additional sanity checks

- `grep -c 'complement' README.md` = 8 (>= 3 required)
- `grep -c 'BREAKING CHANGES' CHANGELOG.md` = 1
- `grep -rl '## Required Base Plugins' templates/*/CLAUDE.md | wc -l` = 7
- `test -f docs/INSTALL.md` = true
- `grep -q 'superpowers@claude-plugins-official' templates/base/CLAUDE.md` = true
- `grep -q 'raw.githubusercontent.com/gsd-build/get-shit-done' templates/base/CLAUDE.md` = true
- Version alignment: manifest.json = `4.0.0`, CHANGELOG first versioned entry = `4.0.0`

## Canonical Required Base Plugins Block

The following block was inserted verbatim into all 7 templates immediately after `## Project Overview`
(or `## 🎯 Project Overview`) and before `## 📌 Compact Instructions` (or `## Compact Instructions`):

```markdown
## Required Base Plugins

This toolkit is designed to **complement** two Claude Code plugins. Install them first for
the full experience; TK will auto-detect them and skip duplicate files.

| Plugin | Purpose | Install |
|--------|---------|---------|
| `superpowers` (obra) | Skills (debugging, plans, TDD, verification, worktrees), `code-reviewer` agent | `claude plugin install superpowers@claude-plugins-official` |
| `get-shit-done` (gsd-build) | Phase-based workflow: `/gsd-plan-phase`, `/gsd-execute-phase`, and more | `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)` |

> **Without these plugins** TK still installs in `standalone` mode — you get every TK file,
> but you'll miss SP's systematic debugging and GSD's phase workflow. See
> [optional-plugins.md](https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/components/optional-plugins.md)
> for the full rationale (components are repo-root assets — they are NOT installed into
> `.claude/`, so use the absolute GitHub blob URL).
```

SP install string: `claude plugin install superpowers@claude-plugins-official` (CONTEXT.md-locked, matches `scripts/detect.sh:54` and `scripts/verify-install.sh:197-200`)

GSD install string: `bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)` (CONTEXT.md-locked, matches `scripts/detect.sh:29`)

## Deviations from Plan

None — plan executed exactly as written.

The base template in the worktree used `---` separator between Project Overview and Compact Instructions while framework templates varied (laravel/rails/nextjs used `---`, nodejs/python/go used `---`). The canonical block was inserted before the `---` separator in all cases, maintaining the `## Project Overview` → `## Required Base Plugins` → `---` → `## Compact Instructions` ordering as intended.

## Known Stubs

None. All deliverables are fully wired content.

## Threat Flags

No new security-relevant surface introduced. All files are documentation/Markdown — no network endpoints, auth paths, or file access patterns added.

## Self-Check: PASSED

- SUMMARY.md exists at `.planning/phases/06-documentation/06-01-SUMMARY.md` — FOUND
- Commit c5c8cbc (Task 1: CHANGELOG + manifest) — FOUND
- Commit b3a79f8 (Task 2: README) — FOUND
- Commit edc6bf1 (Task 3: 7 templates) — FOUND
- Commit 7eebc33 (Task 4: docs/INSTALL.md) — FOUND
- Commit a16d6b5 (Task 5: Makefile drift guard) — FOUND
