---
phase: 13-foundation-fp-allowlist-skip-restore-commands
reviewed: 2026-04-25T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - commands/audit-restore.md
  - commands/audit-skip.md
  - manifest.json
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/update-claude.sh
  - templates/base/rules/audit-exceptions.md
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the Phase 13 deliverables: the `/audit-skip` and `/audit-restore` slash command specs,
the `audit-exceptions.md` template, and the three installer/updater scripts that seed it.

The seed heredoc bodies in all three scripts (`init-claude.sh`, `init-local.sh`,
`update-claude.sh`) are **byte-identical** to `templates/base/rules/audit-exceptions.md` — no drift.

The `audit-skip` command has solid validation (git ls-files, line-range, duplicate check,
quoted heredoc, printf-safe reason write). One concrete data-corruption bug exists in
`audit-restore` (it can match and delete the HTML comment example block), plus two warnings
around the `awk -v` quoting pattern and missing EXIT-trap coverage for temp files in
`update-claude.sh`.

---

## Critical Issues

### CR-01: `audit-restore` can corrupt `audit-exceptions.md` by deleting the example comment

**File:** `commands/audit-restore.md:79-88` and `commands/audit-restore.md:142-171`

**Issue:** The `grep -Fxq` search in Step 2 matches the literal heading inside the HTML comment
block in the template file:

```text
<!--
Example entry (this comment is intentionally not a real entry):

### scripts/setup-security.sh:142 — SEC-RAW-EXEC
```

If a user runs `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` against a freshly
seeded file (no real entries yet), the following happens:

1. Step 2: `grep -Fxq -- "$HEADING" "$EXC_FILE"` — **succeeds** (line 18 in the template is
   inside the comment but grep has no HTML awareness).
2. Step 3 (display awk): shows the comment block including the closing `-->` — the user sees
   what looks like a real entry with a `Date`, `Council`, and `Reason`.
3. User confirms with `y`.
4. Step 5 (delete awk): excises lines from the heading to EOF (no following `###` or `##`
   heading to stop the block) — deletes the `Allowed Council values:` line and the closing `-->`
   of the HTML comment.
5. Step 6: `mv` commits the corrupted file. The sanity check (`grep -Fxq -- "$HEADING" "$NEW_TMP"`)
   passes because the heading is removed — error is not caught.

Result: `audit-exceptions.md` has an **unclosed `<!--` HTML comment** that will confuse both
markdown renderers and Claude's context loading for every subsequent session.

This is reproducible on any fresh install where `audit-exceptions.md` still contains only the
seeded template content.

**Fix:** In Step 2 of `audit-restore`, filter out matches that fall inside an HTML comment.
The simplest guard is to require that the matched heading line is NOT preceded by an unclosed
`<!--` in the file. A targeted approach: check that no real entry exists before accepting the
match:

```bash
# After the grep -Fxq check, verify the heading is not inside an HTML comment.
if grep -Fxq -- "$HEADING" "$EXC_FILE"; then
    # Walk backwards from the heading; if we hit <!-- before -->, it's inside a comment.
    if awk -v h="$HEADING" '
        $0 == h { found_at = NR }
        END {
            if (!found_at) exit 1
            # not available in single-pass awk; use a two-pass approach below
        }
    ' "$EXC_FILE"; then : ; fi
fi
```

A simpler, more robust fix is to strip HTML comments from the search file before matching:

```bash
# Strip HTML comment blocks before checking for the heading.
STRIPPED_TMP="$(mktemp)"
trap 'rm -f "$STRIPPED_TMP"' EXIT
sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"
if ! grep -Fxq -- "$HEADING" "$STRIPPED_TMP"; then
    printf 'audit-restore: no entry found for %s:%s + %s\n' "$PATH_PART" "$LINE_PART" "$RULE" >&2
    exit 1
fi
```

Alternatively, re-use the same sed-stripped file for the display and delete awk passes so
they also cannot touch lines inside comment blocks. Apply the same strip to `$EXC_FILE`
before the awk display (Step 3) and modify the delete awk (Step 5) to explicitly skip
`<!-- ... -->` comment spans.

---

## Warnings

### WR-01: `awk -v h="$HEADING"` fails silently when PATH_PART contains a backslash

**File:** `commands/audit-restore.md:97-104` and `commands/audit-restore.md:142-165`

**Issue:** POSIX `awk` interprets escape sequences in `-v` assignments: `\n` → newline,
`\t` → tab, `\b` → backspace, `\u` → `u` (backslash dropped for unknown escapes), etc.
`HEADING` is built from user-supplied `PATH_PART`, so any file path containing a literal
backslash (e.g. `src\utils.ts` checked into a cross-platform repo) will cause both awk
calls to silently fail to match the heading:

```bash
# Demonstrates the problem:
$ printf '### src\utils.ts:42 — SEC-XSS\n' | \
    awk -v 'h=### src\utils.ts:42 — SEC-XSS' '$0 == h { print "MATCH" }'
# (no output — \u is consumed, string becomes "src utils.ts:42 — SEC-XSS")
```

**Impact in `audit-restore`:**
- Step 3 display awk: prints nothing — user is asked to confirm an invisible entry.
- Step 5 delete awk: produces a copy identical to the original — nothing is deleted.
- Step 5 sanity check (`grep -Fxq`): uses fixed-string and finds the heading correctly →
  exits with error `deletion failed — heading still present`. The error IS caught, so there
  is no silent data corruption, but the user experience is confusing.

**Impact in `audit-skip`:** No awk `-v` usage with `HEADING`; the duplicate check uses
`grep -Fxq` (safe). No impact.

**Fix:** Pass the heading to awk via a file or pipe rather than via `-v`:

```bash
# Replace: awk -v h="$HEADING" '...' "$EXC_FILE"
# With: passing heading as an extra argument and reading it as ARGV[1]:
awk 'NR==FNR { h=h $0; next } ...' <(printf '%s' "$HEADING") "$EXC_FILE"

# Or use a BEGINFILE/getline approach, or pipe the heading as the first "file":
HEADING_FILE="$(mktemp)"
trap 'rm -f "$HEADING_FILE"' EXIT
printf '%s\n' "$HEADING" > "$HEADING_FILE"
awk 'FNR==1 && FILENAME==hf { h=$0; next } $0==h { ... }' hf="$HEADING_FILE" "$HEADING_FILE" "$EXC_FILE"
```

The simplest portable fix for the common case is to check whether `PATH_PART` contains a
backslash and exit early with a clear error message, since Unix file paths containing
backslashes are a git edge case:

```bash
case "$PATH_PART" in
    *\\*)
        printf 'audit-restore: path %q contains a backslash; not supported\n' "$PATH_PART" >&2
        exit 2
        ;;
esac
```

---

### WR-02: `update-claude.sh` EXIT traps do not cover all mktemp temporaries

**File:** `scripts/update-claude.sh:834,845,966`

**Issue:** Three EXIT traps are registered at lines 61, 667, and 966. Each supersedes the
previous. The final trap (line 966) is missing two files:

| Variable | Created | Covered by trap |
|---|---|---|
| `LIB_OPTIONAL_PLUGINS_TMP` | line 57 | line 61 only — dropped at 667 and 966 |
| `LIB_BACKUP_TMP` | line 58 | lines 61 and 667 — dropped at 966 |
| `CLAUDE_MD_NEW` | line 834 | not in any EXIT trap |
| `USER_SECTIONS_FILE` | line 845 | not in any EXIT trap |

`LIB_OPTIONAL_PLUGINS_TMP` and `LIB_BACKUP_TMP` are sourced library scripts with no
secrets, so leaking them is not a security risk. `CLAUDE_MD_NEW` and `USER_SECTIONS_FILE`
contain downloaded template content (no secrets). However, if the script is killed between
their creation and the explicit `rm -f` at lines 922/927, these files persist in `/tmp`.

**Fix:** Consolidate all temporaries into the final EXIT trap at line 966:

```bash
trap 'rm -f "$STATE_TMP" "$CLAUDE_MD_NEW" "$USER_SECTIONS_FILE"* \
         "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" \
         "$LIB_OPTIONAL_PLUGINS_TMP" "$LIB_BACKUP_TMP" \
         "$LIB_DRO_TMP" "$MANIFEST_TMP"; \
      release_lock' EXIT
```

Register this trap early (before any mktemp call) and remove the intermediate traps at
lines 61 and 667 so there is a single source of truth for cleanup.

---

## Info

### IN-01: `audit-restore` does not validate PATH_PART against git-tracked files

**File:** `commands/audit-restore.md:39-68`

**Issue:** `audit-skip` validates `PATH_PART` with `git ls-files --error-unmatch` before
writing an exception. `audit-restore` has no corresponding check — it only verifies the
heading exists in `audit-exceptions.md`. This is intentional (removing an exception does
not require the file to exist in the repo anymore — it may have been deleted after the
exception was added). The asymmetry is correct by design but worth documenting explicitly
in the command spec to prevent future "fix" attempts that break the remove-after-delete
use case.

**Fix:** Add a comment in Step 1 or Step 2 of `audit-restore.md` explaining why the
git-tracked validation is intentionally absent:

```markdown
No `git ls-files` check here: the file may have been deleted or moved since the exception
was added, and we still want to be able to clean up stale entries. The heading key alone
is sufficient to identify and remove the record.
```

---

### IN-02: `audit-skip` Step 5 `BLOCK_TMP` trap is silently replaced by Step 6 trap

**File:** `commands/audit-skip.md:169-192`

**Issue:** Step 5 registers `trap 'rm -f "$BLOCK_TMP"' EXIT` at line 170. Step 6
immediately replaces it with `trap 'rm -f "$BLOCK_TMP" "$NEW_TMP"' EXIT` at line 192. The
second trap correctly covers both files, so there is no actual leak. However, the pattern
of registering two consecutive EXIT traps on the same signal can confuse readers into
thinking both are active simultaneously. In Bash, each `trap ... EXIT` replaces the
previous unconditionally.

**Fix:** Remove the Step 5 trap registration and keep only the Step 6 trap (which covers
both `BLOCK_TMP` and `NEW_TMP`):

```bash
# Step 5 — Build Entry Block
BLOCK_TMP="$(mktemp)"
# (no trap here — Step 6 will register the consolidated trap covering both temps)

# Step 6 — Append Atomically
NEW_TMP="$(mktemp)"
trap 'rm -f "$BLOCK_TMP" "$NEW_TMP"' EXIT
```

---

### IN-03: `manifest.json` version field (4.0.0) is stale relative to shipped v4.1

**File:** `manifest.json:3`

**Issue:** `manifest.json` carries `"version": "4.0.0"` and `"updated": "2026-04-19"`.
Project memory records v4.1 as shipped on 2026-04-25 with CI green. The `version` field
in `manifest.json` is the **product version** (distinct from `manifest_version` which is the
schema version). `update-claude.sh` reads `REMOTE_TOOLKIT_VERSION` from this field and
displays it to users during updates; a stale product version misleads users about which
release they are installing.

**Fix:** Bump `version` to `"4.1.0"` (or the correct release tag) and update `updated` to
the release date before tagging v4.1.0:

```json
{
  "manifest_version": 2,
  "version": "4.1.0",
  "updated": "2026-04-25",
  ...
}
```

---

## Heredoc Drift Check

All three seed heredocs were diffed byte-for-byte against `templates/base/rules/audit-exceptions.md`:

| Script | Match |
|---|---|
| `scripts/init-claude.sh` (lines 554–580) | identical |
| `scripts/init-local.sh` (lines 320–346) | identical |
| `scripts/update-claude.sh` (lines 980–1006) | identical |

No drift detected.

---

_Reviewed: 2026-04-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
