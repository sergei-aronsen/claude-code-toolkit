---
phase: 01-pre-work-bug-fixes
fixed_at: 2026-04-17T00:00:00Z
review_path: .planning/phases/01-pre-work-bug-fixes/01-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-17
**Source review:** .planning/phases/01-pre-work-bug-fixes/01-REVIEW.md
**Iteration:** 1

**Summary:**

- Findings in scope: 3 (WR-01, WR-02, WR-03 — critical_warning scope)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: Misleading prompt and dead else-branch in apt-get tree flow

**Files modified:** `scripts/setup-council.sh`
**Commit:** 1087c73
**Applied fix:** Replaced the `read` prompt + dead if/else block in the apt-get branch
with a simple three-line advisory message. The misleading "Proceed? [y/N]" prompt
(which never actually ran apt-get) was removed along with the duplicate
`echo -e "tree not found"` lines. The new text matches the advisory-only semantics
required by D-09/BUG-04: it prints the manual install command as informational text
and states Supreme Council will work without tree. No `sudo apt-get` execution was
introduced; `grep -cE "^[[:space:]]*sudo apt-get"` stays 0.

### WR-02: Non-atomic write to settings.json without trap-based restore

**Files modified:** `scripts/setup-security.sh`
**Commit:** 99057c1
**Applied fix:** Added `tempfile.mkstemp` + `os.replace` atomic-write pattern to all
three Python JSON-merge blocks (hook merge at line ~238, plugins merge at line ~338,
plugins-add-missing at line ~391). Each block now writes to a temp file in the same
directory, then renames it atomically via `os.replace`. If mkstemp or the write
fails, the temp file is unlinked and the exception is re-raised so Python exits
non-zero, triggering the existing shell-level `cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"`
restore. The original `.bak.$(date +%s)` backup-and-restore logic is preserved as a
second safety layer.

### WR-03: Path injection in python3 -c verification one-liner

**Files modified:** `scripts/setup-council.sh`
**Commit:** 27469b9
**Applied fix:** Replaced the double-quoted `python3 -c "... open('$COUNCIL_DIR/brain.py') ..."` 
one-liner with a single-quoted form that reads the path from `sys.argv[1]`:
`python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$COUNCIL_DIR/brain.py"`.
Added `# shellcheck disable=SC2016` comment above the line to suppress the
intentional single-quote shellcheck note. `$COUNCIL_DIR` is now safely passed as a
shell argument, so paths containing single-quotes or backslashes cannot break the
Python literal.

## Skipped Issues

None — all findings were fixed.

---

**Post-fix verification:**

- `bash -n scripts/setup-council.sh` — syntax OK
- `bash -n scripts/setup-security.sh` — syntax OK
- `make shellcheck` — ShellCheck passed (0 issues)
- `grep -cE "^[[:space:]]*sudo apt-get" scripts/setup-council.sh` — 0 (constraint honored)
- Markdown lint failures in `CLAUDE.md` and `components/orchestration-pattern.md` are
  pre-existing and out of scope for this phase.

---

_Fixed: 2026-04-17_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
