---
phase: 13-foundation-fp-allowlist-skip-restore-commands
plan: 05
subsystem: commands
tags: [audit, allowlist, false-positive, gap-closure, commands, markdownlint, data-corruption-fix]

requires:
  - 13-03-audit-restore-command

provides:
  - "commands/audit-restore.md: comment-aware find, display, confirm, delete entry from audit-exceptions.md"
  - "EXC-02 fully satisfied: /audit-restore cannot corrupt audit-exceptions.md on fresh-seeded projects"
  - "CR-01 closed: HTML comment stripping before grep + in_comment state machine in delete awk"

affects:
  - 14-audit-pipeline-integration
  - 15-council-audit-review

tech-stack:
  added: []
  patterns:
    - "sed '/^<!--/,/^-->/d' strip: removes HTML comment blocks into STRIPPED_TMP before grep/display"
    - "Consolidated trap: single trap 'rm -f STRIPPED_TMP NEW_TMP' EXIT covers both temps from Step 2"
    - "in_comment state machine: awk /^<!--/ sets in_comment=1; /^-->/ resets; heading-match unreachable while in_comment==1"
    - "STRIPPED_TMP for read-only path (Step 2 grep + Step 3 display); EXC_FILE for rebuild path (Step 5 awk)"

key-files:
  created: []
  modified:
    - commands/audit-restore.md

key-decisions:
  - "Approach A locked: STRIPPED_TMP for grep/display, in_comment guard for rebuild — Approach B (split-and-restitch) rejected"
  - "Step 5 awk still reads EXC_FILE (not STRIPPED_TMP) so comment block is preserved verbatim in the rebuilt file"
  - "Consolidated trap in Step 2 replaces stale single-temp trap that was in Step 5"
  - "Sanity check in Step 5 (grep -Fxq on NEW_TMP) preserved verbatim — still defends against awk logic errors on real entries"
  - "WR-01 (awk -v backslash paths) and WR-02 (update-claude.sh trap coverage) confirmed out of scope per 13-VERIFICATION.md lines 109-110"

requirements-completed:
  - EXC-02

duration: 2min
completed: 2026-04-25
---

# Phase 13 Plan 05: /audit-restore HTML-Comment Gap Closure Summary

**Comment-aware fix to commands/audit-restore.md: sed strip into STRIPPED_TMP before grep/display + in_comment awk state machine in rebuild — prevents CR-01 corruption of freshly-seeded audit-exceptions.md**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-25T15:36:12Z
- **Completed:** 2026-04-25T15:38:22Z
- **Tasks:** 2 (1 file edit + 1 inline regression repro)
- **Files modified:** 1 (`commands/audit-restore.md`)

## Accomplishments

- Patched `commands/audit-restore.md` (218 → 263 lines) with four targeted edits closing CR-01
- Task 2 regression repro printed `PASS`: fresh-seed restore exits 1 with `no entry found`, file byte-identical
- `markdownlint commands/audit-restore.md` exits 0; `make lint` exits 0 (shellcheck + markdownlint both pass)
- EXC-02 status: PARTIALLY SATISFIED → FULLY SATISFIED

## The Four Edits Applied

### Edit 1 — Step 2: STRIPPED_TMP + consolidated trap + sed strip + grep target switch

**Before (Step 2 body):**

```bash
if ! grep -Fxq -- "$HEADING" "$EXC_FILE"; then
    printf 'audit-restore: no entry found for %s:%s:%s\n' "$PATH_PART" "$LINE_PART" "$RULE" >&2
    exit 1
fi
```

**After (Step 2 body — key additions):**

```bash
STRIPPED_TMP="$(mktemp)"
NEW_TMP="$(mktemp)"
trap 'rm -f "$STRIPPED_TMP" "$NEW_TMP"' EXIT

sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"

if ! grep -Fxq -- "$HEADING" "$STRIPPED_TMP"; then
    printf 'audit-restore: no entry found for %s:%s:%s\n' "$PATH_PART" "$LINE_PART" "$RULE" >&2
    exit 1
fi
```

The sed expression `'/^<!--/,/^-->/'` uses anchored column-0 patterns matching the exact
delimiter lines in the seeded template. `NEW_TMP` is declared here (moved from Step 5) so a
single EXIT trap covers both temps for the remainder of the script.

### Edit 2 — Step 3: display awk reads STRIPPED_TMP not EXC_FILE

Only the trailing filename changed. Awk body is identical to the 13-03 delivery.

**Before:** `' "$EXC_FILE"` (last line of awk block)

**After:** `' "$STRIPPED_TMP"`

### Edit 3 — Step 5: in_comment state machine + remove stale trap

The `mktemp`/`trap` declarations were removed from Step 5 (consolidated into Step 2). The awk
body gained three new rules at the top, before all existing rules:

```bash
BEGIN { skip = 0; pending_blank = 0; in_comment = 0 }
/^<!--/ {
    in_comment = 1
    if (pending_blank) { print prev_blank; pending_blank = 0 }
    print
    next
}
in_comment {
    if (/^-->/) { in_comment = 0 }
    print
    next
}
```

The `in_comment { ... next }` rule consumes every line while inside a comment block — the
heading-match rule `$0 == h { skip = 1 }` is unreachable while `in_comment == 1`. The awk
still reads from `$EXC_FILE` (NOT `$STRIPPED_TMP`) and writes to `$NEW_TMP`, so the comment
block in the seeded template is preserved verbatim across the rebuild.

### Edit 4 — Key Principles: HTML-comment safe bullet

Added after the "Block-only removal" bullet:

```markdown
- **HTML-comment safe** — example blocks inside `<!-- -->` are never matched, displayed, or
  deleted. Step 2 and Step 3 read a comment-stripped copy of the file; Step 5 rebuilds with
  an `in_comment` guard so the seeded `<!-- Example entry -->` block is preserved verbatim
  across every restore.
```

## Consolidated Trap Confirmed

- `grep -F "trap 'rm -f \"\$STRIPPED_TMP\" \"\$NEW_TMP\"' EXIT" commands/audit-restore.md` — 1 match (Step 2)
- `grep -F "trap 'rm -f \"\$NEW_TMP\"' EXIT" commands/audit-restore.md` — 0 matches (stale trap removed)

Both `$STRIPPED_TMP` and `$NEW_TMP` are cleaned on EXIT by the single consolidated trap.

## Step 5 Reads EXC_FILE Confirmed

```bash
awk '/^### Step 5/,/^### Step 6/' commands/audit-restore.md \
    | grep -F "' \"\$EXC_FILE\" > \"\$NEW_TMP\""
# Returns: ' "$EXC_FILE" > "$NEW_TMP"
```

Step 5 awk reads the ORIGINAL file (with comment block intact), not the stripped copy. This
is the mechanism that preserves the seeded example byte-for-byte through every rebuild.

## Exact Sed Expression and Awk in_comment Rules

**sed expression:** `sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"`

- `/^<!--/` — anchor: line starting at column 0 with `<!--`
- `/^-->/` — anchor: line starting at column 0 with `-->`
- `,` — range between these two delimiters
- `d` — delete matched lines (the entire comment block)

**awk in_comment rules:**

```text
/^<!--/ { in_comment = 1; flush pending_blank; print; next }
in_comment { if (/^-->/) in_comment = 0; print; next }
```

Every line between `^<!--` and `^-->` is consumed by the `in_comment { ... next }` rule
before the heading-match rule `$0 == h` can see it.

## Task 2 Regression Repro Evidence

Inline bash repro against a scratch fixture (copy of `templates/base/rules/audit-exceptions.md`):

- Exit code from `bash -s`: **1** (expected 1 — no-match path)
- Stderr: `audit-restore: no entry found for scripts/setup-security.sh:142:SEC-RAW-EXEC`
- `diff -q .before .claude/rules/audit-exceptions.md`: **0 differences** (file byte-identical)
- Result: **PASS**

The CR-01 row in the next verification pass flips from FAIL to PASS.

## Lint Evidence

- `markdownlint commands/audit-restore.md` → exit 0, no output
- `make lint` → "All checks passed!" (shellcheck + markdownlint)

## File Statistics

- **Before:** 218 lines (13-03 delivery)
- **After:** 263 lines (+45 lines: 4 prose notes, expanded Step 2 body, expanded Step 5 body, new Key Principles bullet)
- **Floor check:** 263 ≥ 100 — PASS

## Items NOT Changed (Scope Boundary Confirmation)

- `templates/base/rules/audit-exceptions.md` — NOT modified (seed template unchanged)
- `scripts/init-claude.sh` — NOT modified
- `scripts/init-local.sh` — NOT modified
- `scripts/update-claude.sh` — NOT modified
- `manifest.json` — NOT modified

The fix is single-file targeted: only `commands/audit-restore.md` was changed.

## WR-01 / WR-02 Out of Scope

- **WR-01** (`awk -v` fails silently for paths with backslashes): non-silent failure path
  (Step 5 sanity check catches it: "deletion failed — heading still present"). Confirmed out
  of scope per 13-VERIFICATION.md lines 109-110. The `in_comment` guard does not change this
  surface.
- **WR-02** (EXIT trap coverage in `update-claude.sh`): affects temp files with no secrets.
  Confirmed out of scope per 13-VERIFICATION.md line 110.

## No-Regression Markers (13-03 Must-Haves Preserved)

All five no-regression markers confirmed present:

- 7 H3 steps (`grep -cE '^### Step [1-7] '` returns 7)
- `[y/N]` default-N gate
- `< /dev/tty` fallback
- `case y|Y) ;;` (only y/Y proceeds)
- Post-write sanity check (`grep -Fxq -- "$HEADING" "$NEW_TMP"`)
- Atomic `mv "$NEW_TMP" "$EXC_FILE"`
- "NOT staged" notice in Step 7
- No `--force` / `-y` flag

## Task Commits

1. **Task 1: Patch commands/audit-restore.md** — `f932407` (fix)
2. **Task 2: Regression repro** — inline bash, no file changes, no separate commit needed

## Deviations from Plan

None — plan executed exactly as written. All four edits applied verbatim from the plan's
`<action>` blocks. The fix recipe from 13-REVIEW.md was used without modification.

## Known Stubs

None — this is a slash command spec, not a UI component. The fix is complete and functional.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes
introduced. The threat model entries T-13-15 and T-13-16 are now mitigated as designed.

## Self-Check

### Files modified exist

- `commands/audit-restore.md` → FOUND (263 lines)

### Commits exist

- `f932407` → FOUND (`fix(13-05): strip HTML comments before audit-restore search`)

## Self-Check: PASSED
