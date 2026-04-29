---
phase: 31-distribution-tests-docs
plan: "03"
subsystem: docs
tags: [documentation, bridges, multi-cli, install-flags]
dependency_graph:
  requires: []
  provides: [BRIDGE-DOCS-01, BRIDGE-DOCS-02]
  affects: [docs/BRIDGES.md, docs/INSTALL.md, README.md]
tech_stack:
  added: []
  patterns: [9-section docs structure, verbatim interface block]
key_files:
  created:
    - docs/BRIDGES.md
  modified:
    - docs/INSTALL.md
    - README.md
decisions:
  - Plain copy over symlink rationale documented in Why No Symlink section
  - AGENTS.md (not CODEX.md) emphasized per OpenAI upstream convention
  - Single Killer Features row chosen (compactness per CONTEXT.md line 133)
metrics:
  duration: "~8 minutes"
  completed: "2026-04-29"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 2
---

# Phase 31 Plan 03: Docs — BRIDGES.md + INSTALL.md + README Summary

One-liner: Multi-CLI bridge user documentation — 9-section BRIDGES.md, 4 new
INSTALL.md flag rows with sub-section, and a Killer Features row in README.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create docs/BRIDGES.md | f42924b | docs/BRIDGES.md (167 lines, NEW) |
| 2 | Extend docs/INSTALL.md flag table + sub-section | dd55bd3 | docs/INSTALL.md (+23 lines) |
| 3 | Add Multi-CLI Bridges row to README.md Killer Features grid | b306a46 | README.md (+1 line) |

## Artifact Details

### docs/BRIDGES.md (NEW — 167 lines)

9 required sections present (verified by grep):

1. `## Overview` — what bridges do, single-source-of-truth invariant
2. `## Supported CLIs` — table (Gemini → GEMINI.md, OpenAI Codex → AGENTS.md) plus explicit note: AGENTS.md is the OpenAI standard, NOT CODEX.md
3. `## How it Works` — plain-copy semantics, verbatim 4-line banner heredoc in fenced `text` block
4. `## Drift Handling` — three log states: `[~ UPDATE]`, `[y/N/d]` prompt, `[? ORPHANED]`
5. `## Opt-Out Mechanics` — `--no-bridges`, `TK_NO_BRIDGES=1`, `--break-bridge`, `--restore-bridge` with bash examples
6. `## Force-Create (Non-Interactive)` — `--bridges gemini,codex` CI usage, `--fail-fast` behavior
7. `## Why No Symlink` — three rationale bullets (per-CLI customization, future tone overlays, transparent SHA256 drift)
8. `## Uninstall` — `classify_bridge_file` routing, REMOVE_LIST/MODIFIED_LIST, `--keep-state` semantics
9. `## Future Scope` — BRIDGE-FUT-01 deferred to v4.8; BRIDGE-FUT-03/04 Cursor/Aider out of scope

Verification counts:
- `AGENTS.md` appearances: 3 (table row + note + sub-section) — requirement was ≥2
- `grep -c '^## ' docs/BRIDGES.md` = 9 (all required sections)
- No `##` heading ends with `?`, `:`, `!`, or `.` (MD026 clean)
- `markdownlint docs/BRIDGES.md` exits 0

### docs/INSTALL.md (MODIFIED — 331 → 354 lines, +23)

4 new flag rows inserted between `--keep-state` and `--no-council`:

```text
Lines ~71-75 (new):
  | `--no-bridges` | init-claude.sh, init-local.sh, install.sh | ... TK_NO_BRIDGES=1 ... |
  | `--bridges <list>` | init-claude.sh, init-local.sh, install.sh | ... --fail-fast ... |
  | `--break-bridge <target>` | update-claude.sh | ... user_owned: true ... |
  | `--restore-bridge <target>` | update-claude.sh | ... reverses --break-bridge ... |
```

New `### Multi-CLI Bridges (v4.7+)` sub-section inserted after the `--keep-state for
uninstall.sh (v4.4+)` block, before the `---` separator. Contains:
- 3-paragraph prose explaining bridge creation, opt-out flags, and update-claude.sh sync
- Link to `BRIDGES.md` (relative path, both files in `docs/`)
- `TK_NO_BRIDGES` env var referenced

Existing v4.4 sub-sections (`--no-bootstrap`, `--no-banner`, `--keep-state for
uninstall.sh`) preserved verbatim. `## install.sh (unified entry, v4.5+)` block
at line 129 (post-insert) unchanged.

### README.md (MODIFIED — 233 → 234 lines, +1)

One row appended after `**Structured Workflow**` in the Killer Features table:

```text
| **Multi-CLI Bridges** | Auto-sync `CLAUDE.md` to Gemini CLI's `GEMINI.md` and
  OpenAI Codex's `AGENTS.md`. Drift-detected, opt-out via `--no-bridges`.
  See [docs/BRIDGES.md](docs/BRIDGES.md) |
```

## make check Result

Exit code: 0

Full pipeline green:
- ShellCheck passed
- Markdownlint passed (all *.md including BRIDGES.md, INSTALL.md, README.md)
- Template validation passed (49 audit files, version 4.7.0 aligned)
- Manifest schema valid
- All 7 templates carry `## Required Base Plugins`
- README translation drift within ±20%
- Skills Desktop-safety audit passed
- validate-marketplace skipped (TK_HAS_CLAUDE_CLI not set — expected in local env)
- cell-parity passed: all 13 cells present in all 3 surfaces

## Requirements Coverage

- **BRIDGE-DOCS-01** — COVERED. `docs/BRIDGES.md` created with all 9 required sections,
  AGENTS.md (not CODEX.md) emphasized ≥2 times, verbatim banner heredoc present.
- **BRIDGE-DOCS-02** — COVERED. `docs/INSTALL.md` Installer Flags table extended with 4
  bridge flag rows + `### Multi-CLI Bridges (v4.7+)` sub-section; `README.md` Killer
  Features grid has multi-CLI bridge row linking to `docs/BRIDGES.md`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all documentation content is complete and self-contained.

## Self-Check: PASSED

Files exist:

- `docs/BRIDGES.md` — FOUND (167 lines)
- `docs/INSTALL.md` — FOUND (354 lines)
- `README.md` — FOUND (234 lines)

Commits exist:

- `f42924b` — FOUND (`docs: add docs/BRIDGES.md`)
- `dd55bd3` — FOUND (`docs(install): document bridge flags`)
- `b306a46` — FOUND (`docs(readme): mention multi-CLI bridge support`)
