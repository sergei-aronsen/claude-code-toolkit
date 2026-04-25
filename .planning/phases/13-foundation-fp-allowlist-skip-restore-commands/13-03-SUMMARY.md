---
phase: 13-foundation-fp-allowlist-skip-restore-commands
plan: 03
subsystem: commands
tags: [audit, allowlist, false-positive, commands, confirmation, markdownlint]

requires:
  - 13-02-audit-skip-command

provides:
  - "Slash command spec commands/audit-restore.md: arg parsing, display-before-delete, [y/N] confirmation, awk block-delete, atomic mv"
  - "EXC-02 maintenance path: /audit-restore <file:line> <rule> → removes matching block from .claude/rules/audit-exceptions.md after confirmation"
  - "D-08 confirmation flow: mandatory [y/N] defaults-to-N gate before any deletion"

affects:
  - 14-audit-pipeline-integration
  - 15-council-audit-review

tech-stack:
  added: []
  patterns:
    - "Slash command spec: markdown document Claude reads and executes as Bash steps"
    - "Default-N confirmation: y|Y proceeds; Enter/anything-else aborts (D-08)"
    - "Sentinel-blank awk deletion: pending_blank buffers blank lines, drops the one preceding the heading"
    - "Post-write sanity check: grep -Fxq verifies heading absent from NEW_TMP before mv"
    - "Atomic write: mktemp NEW_TMP → awk output → mv (single-temp pattern for deletion)"
    - "< /dev/tty fallback: read from TTY if available, stdin otherwise"

key-files:
  created:
    - commands/audit-restore.md
  modified: []

key-decisions:
  - "[y/N] prompt reads from /dev/tty when available, falls back to stdin for CI contexts"
  - "Sentinel-blank awk logic: pending_blank variable buffers each blank line so the blank preceding the deleted heading is also dropped"
  - "Post-write sanity check uses grep -Fxq on NEW_TMP before mv — if heading still present, exit 1 (deletion bug detected)"
  - "No --force flag and no -y flag per D-08 mandate — the confirmation gate is unconditional"
  - "awk stop conditions for block deletion: /^### / (next entry), /^## / (H2 boundary, defensive), or EOF"
  - "MD038 fix: prose references to awk stop patterns use backtick-only `###` and `##` (no trailing space inside code span)"

requirements-completed:
  - EXC-02

duration: 2min
completed: 2026-04-25
---

# Phase 13 Plan 03: /audit-restore Command Spec Summary

**Markdownlint-clean slash command spec implementing the inverse of /audit-skip — display, confirm, and atomically delete an exception block from audit-exceptions.md with mandatory default-N confirmation gate**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-25T14:30:17Z
- **Completed:** 2026-04-25T14:32:30Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `commands/audit-restore.md` (218 lines) with all 7 Process steps as executable Bash blocks
- All acceptance criteria pass: file, H1, 6 H2 sections in order, 7 steps, arg-count check, grep -Fxq exact-triple, no-match error, [y/N] prompt, < /dev/tty, y|Y case, pending_blank, sanity check, atomic mv, NOT staged notice, no --force, em-dash count
- `markdownlint` exits 0; `make lint` exits 0 (ShellCheck + markdownlint both pass)
- Fixed MD038 violation: prose references to awk stop conditions `### ` and `## ` (trailing space in code span) reworded to use `###` and `##` without trailing spaces

## Task Commits

Each task was committed atomically:

1. **Task 1: Author commands/audit-restore.md spec** — `34416db` (feat)

## Files Created/Modified

- `commands/audit-restore.md` — Slash command spec: parse args, find entry (grep -Fxq exact-triple), display block (awk), [y/N] confirm (< /dev/tty), awk sentinel-blank block delete, post-write sanity check, atomic mv, confirm without staging. 218 lines. Markdownlint-clean.

## Confirmation Flow Shipped (D-08)

Step 4 implements:

```bash
printf '\nRemove this entry? [y/N]: '
ANSWER=""
if [ -r /dev/tty ]; then
    read -r ANSWER < /dev/tty
else
    read -r ANSWER
fi

case "$ANSWER" in
    y|Y) ;;
    *)
        printf 'Aborted. No changes.\n'
        exit 0
        ;;
esac
```

Only `y` or `Y` proceeds. Pressing Enter triggers the `*)` default → abort. No bypass flags.

## awk Block-Deletion Stop Conditions

Step 5 awk exits the block on:

1. `/^### /` — next `###`-level heading (next allowlist entry)
2. `/^## /` — `##`-level heading (H2 boundary — defensive, should not occur in normal schema)
3. EOF — end of file (last entry case)

The `pending_blank` sentinel variable ensures the blank line immediately preceding the deleted
heading is also dropped — preventing a double-blank gap in the remaining file.

## Post-Write Sanity Check

Step 5 includes a verification after the awk rewrite:

```bash
if grep -Fxq -- "$HEADING" "$NEW_TMP"; then
    printf 'audit-restore: deletion failed — heading still present in output\n' >&2
    exit 1
fi
```

This catches any awk logic error before the atomic `mv` commits the broken output.

## No --force / -y Flags

`grep -v '\-\-force' commands/audit-restore.md` returns no matches. There is no way to bypass
the `[y/N]` prompt. This satisfies D-08 and T-13-10 (unconfirmed deletion threat mitigation).

## Markdownlint Compliance

- `markdownlint commands/audit-restore.md` → exit 0
- `make lint` → exit 0 (ShellCheck + markdownlint both pass)
- MD040 (language fences): all bash blocks tagged `bash`; usage block tagged `text`
- MD031/MD032 (blank lines around code/lists): blank lines present before and after all fenced blocks and lists
- MD026 (no trailing punct on headings): all headings clean
- MD038 (no spaces inside code spans): prose references to awk stop patterns use `###` and `##` without trailing spaces
- File length: 218 lines (minimum 100 per plan spec)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed MD038 lint errors in prose descriptions of awk stop conditions**

- **Found during:** Task 1 verification (markdownlint run)
- **Issue:** Prose text referenced `` `### ` `` and `` `## ` `` (trailing space inside code spans) which trigger MD038/no-space-in-code
- **Fix:** Reworded to `` `###` heading `` and `` `##` heading `` — preserves the meaning, eliminates the trailing space inside the span
- **Files modified:** `commands/audit-restore.md` (lines 136, 175)
- **Commit:** `34416db` (same task commit — caught and fixed before commit)

## Known Stubs

None — this is a slash command spec, not a UI component. All 7 Process steps are complete executable Bash. No data sources wired to empty values.

## Threat Flags

None — `commands/audit-restore.md` is a markdown spec file. It introduces no new network endpoints, auth paths, or schema changes. The threat model for unconfirmed deletion (T-13-10), collateral damage (T-13-11), spoofing via wrong triple (T-13-12), and path traversal (T-13-14) were all addressed inline per the plan's STRIDE register.

## Self-Check

### Files created exist

- `commands/audit-restore.md` → FOUND (218 lines)

### Commits exist

- `34416db` → FOUND (`feat(13-03): add /audit-restore slash command spec`)

## Self-Check: PASSED
