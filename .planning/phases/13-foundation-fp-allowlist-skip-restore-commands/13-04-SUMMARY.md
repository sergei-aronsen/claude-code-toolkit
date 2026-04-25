---
phase: 13-foundation-fp-allowlist-skip-restore-commands
plan: 04
subsystem: installers
tags: [installers, shell, idempotency, audit, allowlist, false-positive]

requires:
  - 13-01-audit-exceptions-seed-template

provides:
  - "init-claude.sh seeds .claude/rules/audit-exceptions.md on first install (create_audit_exceptions function)"
  - "init-local.sh seeds .claude/rules/audit-exceptions.md on first local install (inline block)"
  - "update-claude.sh seeds .claude/rules/audit-exceptions.md when missing during update (idempotent guard)"
  - "All three heredoc bodies byte-identical to templates/base/rules/audit-exceptions.md"

affects:
  - 14-audit-pipeline-integration
  - 15-council-audit-review
  - 16-template-propagation

tech-stack:
  added: []
  patterns:
    - "Installer seed function: create_audit_exceptions() mirrors create_lessons_learned() style in init-claude.sh"
    - "Inline seed block: EXCEPTIONS_FILE= + [ ! -f ] guard mirrors LESSONS_FILE= block style in init-local.sh"
    - "Update script idempotency: [[ ! -f ]] double-bracket guard near EOF of update-claude.sh"
    - "DRY_RUN string form (== true) in init-claude.sh; integer form ([[ $DRY_RUN -eq 1 ]]) in update-claude.sh"

key-files:
  created: []
  modified:
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - scripts/update-claude.sh
    - manifest.json

key-decisions:
  - "Function create_audit_exceptions() placed immediately after create_lessons_learned() in init-claude.sh for adjacency"
  - "No per-block DRY_RUN handling added to init-local.sh — script-level early-exit DRY_RUN covers it by construction"
  - "mkdir -p added in update-claude.sh before seed write — defensive against projects without rules/ dir"
  - "manifest.json: registered audit-skip.md and audit-restore.md (Wave 1 drift fix) to restore make check to green"

requirements-completed:
  - EXC-05

duration: 15min
completed: 2026-04-25
---

# Phase 13 Plan 04: Installer Seeding for audit-exceptions.md Summary

**Three installers seeded with byte-identical audit-exceptions.md heredocs; idempotent guards prevent overwriting user-modified allowlist files; make check passes after Wave 1 manifest drift fix**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-25T14:35:00Z
- **Completed:** 2026-04-25T14:50:00Z
- **Tasks:** 4
- **Files modified:** 4

## Accomplishments

- Added `create_audit_exceptions()` function to `scripts/init-claude.sh` (46 lines, mirrors `create_lessons_learned`)
- Added inline `EXCEPTIONS_FILE` seed block to `scripts/init-local.sh` (33 lines, mirrors `LESSONS_FILE` block)
- Added idempotent seed guard to `scripts/update-claude.sh` (40 lines, after `print_update_summary`)
- Verified all three heredoc bodies byte-identical to `templates/base/rules/audit-exceptions.md`
- Fixed pre-existing Wave 1 manifest drift: registered `commands/audit-restore.md` and `commands/audit-skip.md`
- `make check` exits 0 (shellcheck + markdownlint + validate-templates + manifest schema)

## Task Commits

Each task was committed atomically:

1. **Task 1: create_audit_exceptions in init-claude.sh** — `dc2b73a` (feat)
2. **Task 2: inline seed block in init-local.sh** — `14ad13c` (feat)
3. **Task 3: seed-when-missing guard in update-claude.sh** — `48b93d8` (feat)
4. **Task 4 + manifest drift fix** — `a2d1153` (fix)

## Per-Installer Change Summary

### scripts/init-claude.sh

- **What:** New function `create_audit_exceptions()` inserted immediately after `create_lessons_learned()` (line 541)
- **Style:** double-bracket `[[ ]]`, `local var=`, DRY_RUN string form (`== true`), heredoc sentinel `EXCEPTIONS`
- **Idempotency:** `if [[ -f "$exceptions_file" ]]; then return; fi` — returns immediately if file exists
- **Invocation:** `create_audit_exceptions` added to `main()` on the line following `create_lessons_learned` (line 782)
- **Lines added:** 46

### scripts/init-local.sh

- **What:** Inline seed block inserted after `lessons-learned.md` block (line 317)
- **Style:** POSIX single-bracket `[ ]`, uppercase variable `EXCEPTIONS_FILE`, no function wrapper
- **Idempotency:** `if [ ! -f "$EXCEPTIONS_FILE" ]` POSIX guard
- **DRY_RUN:** No per-block handling added — script-level early-exit covers this block by construction
- **Success message:** `rules/audit-exceptions.md (seed)` — matches `(seed)` suffix of lessons-learned style
- **Lines added:** 33

### scripts/update-claude.sh

- **What:** Inline guard block inserted after `print_update_summary "$BACKUP_DIR"`, before `recommend_optional_plugins` (line 972)
- **Style:** double-bracket `[[ ]]` matching update-claude.sh convention
- **Idempotency:** `if [[ ! -f "$EXCEPTIONS_FILE" ]]` double-bracket guard
- **DRY_RUN:** Integer form `[[ $DRY_RUN -eq 1 ]]` — matches `DRY_RUN=0` integer flag at top of file
- **mkdir -p:** `mkdir -p "$CLAUDE_DIR/rules"` before write — defensive for projects without rules/ dir
- **Lines added:** 40

## Heredoc Body Consistency Verification

All three scripts embed byte-identical seed bodies. Verified via line-number-anchored awk extraction + diff:

```text
scripts/init-claude.sh  (heredoc open: line 554) → diff vs template: empty (PASS)
scripts/init-local.sh   (heredoc open: line 320) → diff vs template: empty (PASS)
scripts/update-claude.sh (heredoc open: line 980) → diff vs template: empty (PASS)
```

Em-dash U+2014 characters preserved literally in all three files (single-quoted heredoc sentinel
`<< 'EXCEPTIONS'` prevents variable expansion and preserves byte content).

## DRY_RUN Behavior Confirmation

| Script | DRY_RUN form | Behavior when DRY_RUN active |
|--------|-------------|------------------------------|
| `init-claude.sh` | String: `DRY_RUN=false` / `== true` | Prints "Would create: $exceptions_file", does NOT write file |
| `init-local.sh` | Script-level early-exit | Exits before seed block is reached — no per-block change needed |
| `update-claude.sh` | Integer: `DRY_RUN=0` / `-eq 1` | Prints "Would seed: $EXCEPTIONS_FILE", does NOT write file |

## Idempotency Smoke Test

Verified via extraction of seed block to standalone script:

1. **Run 1 (file absent):** File created, MD5 hash recorded
2. **Run 2 (file present):** Guard fires, file unchanged — hash identical to run 1
3. **DRY_RUN=1 (file absent):** "Would seed" message printed, no file written

Content hash preserved on re-run confirms T-13-15 (tamper prevention) is mitigated.

## Deviation from Plan

### Auto-fixed Issue

**[Rule 1 - Bug] Fixed Wave 1 manifest drift blocking make check**

- **Found during:** Task 4 (cross-installer consistency check + `make check`)
- **Issue:** `commands/audit-restore.md` and `commands/audit-skip.md` added in Plans 13-02/13-03
  were not registered in `manifest.json`, causing `make validate` to report drift errors and
  `make check` to exit non-zero — directly blocking Task 4's acceptance criteria.
- **Fix:** Added two entries to `manifest.json` `files.commands[]` array in alphabetical order:
  `{ "path": "commands/audit-restore.md" }` and `{ "path": "commands/audit-skip.md" }`
- **Files modified:** `manifest.json`
- **Commit:** `a2d1153`

## make check Result

```text
Running ShellCheck...         ✅ ShellCheck passed
Running markdownlint...       ✅ Markdownlint passed
Validating templates...       ✅ All templates valid
Validating manifest.json...   ✅ Manifest schema valid
Validating Required Base Plugins... ✅ All 7 templates carry ## Required Base Plugins
Checking version alignment... ✅ Version aligned: 4.0.0
commands/ validation PASSED (32 files checked)
cell-parity passed: all 13 cells present in all 3 surfaces
All checks passed!
```

## Known Stubs

None — all three installers produce real seed content. No hardcoded empty values or placeholder data.

## Threat Flags

None — no new network endpoints or auth paths introduced. The installer writes are local filesystem
operations behind `[ ! -f ]` guards (T-13-15 mitigated). Heredoc single-quoted sentinel prevents
expansion of any dollar signs in seed body (T-13-17 accepted).

---

*Phase: 13-foundation-fp-allowlist-skip-restore-commands*
*Completed: 2026-04-25*
