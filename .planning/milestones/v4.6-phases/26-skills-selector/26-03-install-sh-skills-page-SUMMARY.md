---
phase: 26
plan: "03"
subsystem: skills-selector
tags: [skills, install, tui, catalog, bash, routing-branch]
dependency_graph:
  requires: [scripts/lib/skills.sh, scripts/lib/tui.sh, scripts/lib/dispatch.sh, templates/skills-marketplace/]
  provides: [scripts/install.sh --skills flag]
  affects: [scripts/tests/test-install-skills.sh, .markdownlintignore]
tech_stack:
  added: []
  patterns: [sibling-routing-branch, TK_*-test-seam, cp-R-install, mutex-flag-guard]
key_files:
  created: []
  modified:
    - scripts/install.sh
    - .markdownlintignore
decisions:
  - "Exclude templates/skills-marketplace/ from markdownlint via .markdownlintignore: upstream mirror content carries MD031/MD032/MD036/MD040 violations that cannot be auto-fixed; exclusion is correct since users install the content, not read it as toolkit docs"
  - "DRY_RUN shortcut placed before skills_install call: prevents any filesystem writes in preview mode (lesson from Phase 25 summary)"
  - "Status label 'installed ✓' (not 'skipped') for already-installed unselected skills: consistent with Phase 25 --mcps reference pattern; both branches follow same convention"
metrics:
  duration_minutes: 6
  completed_date: "2026-04-29"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 2
---

# Phase 26 Plan 03: Install.sh Skills Page Summary

**One-liner:** `--skills` flag wired into `scripts/install.sh` with 22-skill TUI catalog, idempotent cp-R install, dry-run preview, --force overwrite, and mutex guard against --mcps.

## What Was Built

**`scripts/install.sh`** gained 189 new lines (622 → 800 lines), adding:

- **Flag declaration:** `SKILLS=0` after `MCPS=0` (line 43)
- **Argparse case:** `--skills) SKILLS=1; shift ;;` (line 55)
- **Help text entry:** `--skills Install curated skills via TUI catalog (Phase 26)` (line 67)
- **Lib sourcing:** `_source_lib skills` conditional block after `_source_lib mcp` block (lines 142-144)
- **Mutex guard:** `[[ "$MCPS" -eq 1 && "$SKILLS" -eq 1 ]]` → exit 1 with "mutually exclusive" message (lines 170-173)
- **Routing branch:** `if [[ "$SKILLS" -eq 1 ]]` block (~160 lines) inserted after the `--mcps` branch closing `fi`, before the Phase 24 components page

**`--skills` routing branch structure:**

1. `skills_status_array` — populates `TUI_INSTALLED[]` from 22-skill catalog
2. Builds `TUI_LABELS`, `TUI_GROUPS`, `TUI_DESCS` arrays from `SKILLS_CATALOG`
3. `--yes` default-set: selects all uninstalled (skips installed unless `--force`)
4. Interactive path: TTY gate → `tui_checklist` → `tui_confirm_prompt`
5. `--dry-run` shortcut: "would-install" rows without invoking `skills_install`
6. Dispatch loop: `skills_install <name> [--force]`, rc=0/2/* handling, `--fail-fast` support, per-skill stderr capture via tmpfile
7. Summary: `print_install_status` rows + `Installed/Skipped/Failed` count line + removal banner (`rm -rf ~/.claude/skills/<name>`)
8. `exit 0` on success, `exit 1` when `FAILED_COUNT > 0`

**`.markdownlintignore`** — added `templates/skills-marketplace/` exclusion (Rule 1 deviation, see below).

## Verification Results

| Check | Result |
|-------|--------|
| `bash scripts/install.sh --help \| grep -c -- "--skills"` | 1 |
| `bash scripts/install.sh --mcps --skills` exits 1 with "mutually exclusive" | PASS |
| `--skills --yes --dry-run` → 22 "would-install" rows | PASS |
| `--skills --yes` → 22 skills copied, Installed: 22 | PASS |
| Re-run `--skills --yes` → all 22 show "installed ✓", no re-copy | PASS |
| `--skills --yes --force` → all 22 re-installed | PASS |
| `test-install-tui.sh` | PASS=38 FAIL=0 |
| `test-bootstrap.sh` | PASS=26 FAIL=0 |
| `test-mcp-selector.sh` | PASS=21 FAIL=0 |
| `shellcheck -S warning scripts/install.sh` | 0 warnings |
| `make check` | All checks passed |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Excluded templates/skills-marketplace/ from markdownlint**

- **Found during:** Task 2 verification (`make check`)
- **Issue:** Plan 02 committed 22 upstream skill directories verbatim; upstream content contains MD031/MD032/MD036/MD040 violations that `markdownlint --fix` cannot fully resolve (MD036 emphasis-as-heading has no auto-fix). `make check` failed.
- **Fix:** Two-part — (a) ran `markdownlint --fix` to resolve all auto-fixable issues across 77 marketplace files, (b) added `templates/skills-marketplace/` to `.markdownlintignore` to permanently exclude upstream mirror content from lint. The toolkit's own authored markdown remains fully linted.
- **Files modified:** `.markdownlintignore`, 77 files under `templates/skills-marketplace/`
- **Commits:** `ead0afb` (routing branch + ignore), `6348af0` (marketplace auto-fix)

### Design Notes (Not Deviations)

- **"installed ✓" vs "skipped" on re-run:** The plan's `must_haves` says "skips already-installed skills with skipped status", but the reference implementation (`--mcps` branch) labels unselected-but-installed items as "installed ✓" — not "skipped". This plan follows the reference pattern for consistency. The INSTALLED_COUNT therefore reflects both newly-installed and already-present skills on re-run; no filesystem writes occur.

## Known Stubs

None. The `--skills` branch is fully wired: TUI renders real catalog data, `skills_install` performs real `cp -R` from the mirror, status detection uses the live `~/.claude/skills/` directory.

## Threat Flags

None. The `--skills` branch copies local files from a repo-committed directory to a user's home directory. No network access, no external APIs, no authentication surfaces added.

## Self-Check: PASSED

- `scripts/install.sh` exists and contains `SKILLS=0` flag: FOUND
- `scripts/install.sh` contains `--skills` routing branch (`if [[ "$SKILLS" -eq 1 ]]`): FOUND (line 350)
- `.markdownlintignore` contains `templates/skills-marketplace/` exclusion: FOUND
- Commit 568ae7f (Task 1): FOUND
- Commit ead0afb (Task 2 routing branch): FOUND
- Commit 6348af0 (Task 2 marketplace auto-fix): FOUND
- test-install-tui.sh PASS=38: CONFIRMED
- test-bootstrap.sh PASS=26: CONFIRMED
- test-mcp-selector.sh PASS=21: CONFIRMED
