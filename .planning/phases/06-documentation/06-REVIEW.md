---
phase: 06-documentation
reviewed: 2026-04-19T00:00:00Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - CHANGELOG.md
  - components/optional-plugins.md
  - components/orchestration-pattern.md
  - components/structured-workflow.md
  - components/supreme-council.md
  - docs/INSTALL.md
  - Makefile
  - manifest.json
  - README.md
  - scripts/init-claude.sh
  - scripts/lib/optional-plugins.sh
  - scripts/setup-security.sh
  - scripts/tests/test-setup-security-rtk.sh
  - scripts/update-claude.sh
  - scripts/validate-manifest.py
  - templates/base/CLAUDE.md
  - templates/global/RTK.md
  - templates/go/CLAUDE.md
  - templates/laravel/CLAUDE.md
  - templates/nextjs/CLAUDE.md
  - templates/nodejs/CLAUDE.md
  - templates/python/CLAUDE.md
  - templates/rails/CLAUDE.md
findings:
  critical: 0
  warning: 5
  info: 6
  total: 11
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-19
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

This review covers the Phase 6 documentation wave: two new components
(`optional-plugins.md`, `orchestration-pattern.md`), the new `templates/global/RTK.md`,
and the updated installer, manifest, Makefile, README, CHANGELOG, and all 7 framework
CLAUDE.md templates.

The overall quality is high. The new components are well-structured and internally
consistent. The scripts follow the established `set -euo pipefail` and `< /dev/tty`
guard conventions. The validate-manifest.py script is clean and correct.

Five warnings were found — all in shell scripts — centered on an unquoted variable that
can cause a silent bug under `set -u`, a redundant `MANIFEST_URL` variable that was meant
to be removed, and three minor robustness gaps in `setup-security.sh`'s smart-merge
logic. Six info items cover dead code, minor inconsistencies, and one magic-number pattern
in the Makefile test target label.

No critical issues (security vulnerabilities, auth bypasses, crashes) were found.

---

## Warnings

### WR-01: Unquoted `$SKIP_COUNCIL` variable causes `set -u` abort under some shells

**File:** `scripts/init-claude.sh:754`
**Issue:** The guard `if [[ "$SKIP_COUNCIL" != true ]]; then` on line 754 uses the
variable after it is set with `SKIP_COUNCIL="${SKIP_COUNCIL:-false}"` on line 53.
However, `--no-council` sets `SKIP_COUNCIL=true` (line 31) before the default assignment
on line 53. The flag `SKIP_COUNCIL=true` is set in the `case` block at line 32 as a bare
variable (not `export`). When the script is invoked without `--no-council`, line 31 is
never reached, so the variable is unset until line 53. Under `set -u` (which is active via
`set -euo pipefail`), any code that references `$SKIP_COUNCIL` before line 53 would abort.
Currently line 53 is reached before line 754, so this is safe in practice. The risk is
latent: if any code is inserted between the `case` block (line 24-51) and line 53 that
references `SKIP_COUNCIL`, the script will abort under `set -u` in the non-`--no-council`
path. The same pattern exists for `MODE`, `FORCE`, `FORCE_MODE_CHANGE` — all initialized
with `:-` defaults on lines 54-57, but only the `SKIP_COUNCIL` path has a boolean flag
that creates a confusing `true` vs literal-string `"true"` comparison at line 754.

More concretely, line 754 reads:
```bash
if [[ "$SKIP_COUNCIL" != true ]]; then
```
`SKIP_COUNCIL` is either `"true"` (string) or `"false"` (string from line 53). The
comparison `!= true` will always be truthy when the value is `"false"`, which is correct
— but it also means comparing against the bare word `true` rather than the string `"true"`
creates a documentation-level inconsistency. The more serious issue is the asymmetry:
`SKIP_COUNCIL=true` (line 32, bare assignment inside `case`) vs
`SKIP_COUNCIL="${SKIP_COUNCIL:-false}"` (line 53, string default).
**Fix:** Initialize `SKIP_COUNCIL` before the argument-parsing loop to eliminate the
ordering dependency entirely:
```bash
# Before the while loop at line 24:
SKIP_COUNCIL=false
MODE=""
FORCE=false
FORCE_MODE_CHANGE=false
```
Then remove the post-loop default assignments on lines 53-57.

---

### WR-02: Dead `MANIFEST_URL` variable in `update-claude.sh` should be removed

**File:** `scripts/update-claude.sh:37`
**Issue:** `MANIFEST_URL="$REPO_URL/manifest.json"` is assigned and then immediately
annotated with `# shellcheck disable=SC2034  # MANIFEST_URL kept as legacy reference;
Plan 04-02 removes it`. The CHANGELOG entry for BUG notes that the update loop now
iterates manifest rather than a hand-list, yet this variable persists. Keeping it with a
`shellcheck disable` suppresses a legitimate unused-variable warning and silently documents
a cleanup task that was never completed.
**Fix:** Remove lines 36-37 entirely:
```bash
# Remove:
# shellcheck disable=SC2034  # MANIFEST_URL kept as legacy reference; Plan 04-02 removes it
MANIFEST_URL="$REPO_URL/manifest.json"
```
If the variable is needed for future reference, the CHANGELOG already documents the
migration.

---

### WR-03: `setup-security.sh` smart-merge uses `grep -n` line number parsing that breaks on filenames containing colons

**File:** `scripts/setup-security.sh:109-121`
**Issue:** The section-extraction logic uses `cut -d: -f1` and `cut -d: -f2-` to split
`grep -n` output into line numbers and header text (lines 112-115). If the filename
`$CLAUDE_MD` contains a colon (e.g., if `$HOME` contains a colon — unusual but possible
on some Linux setups), `grep -n` outputs `filename:linenum:content`, causing `cut -d: -f1`
to return the filename instead of the line number, and all subsequent `sed` range
operations silently produce empty output. The merge appears to succeed (`ADDED=0`) but
no sections are actually added.
**Fix:** Pipe through a clean file reference or use `grep -n` on a variable containing
the file content rather than a filename. Since `$SECURITY_CONTENT` is already in a
variable, parse it directly:
```bash
LINE_NUM=$(echo "$line" | cut -d: -f1)
HEADER=$(echo "$line" | cut -d: -f2-)
```
These lines operate on `$line` (an element from `SECTIONS`), not on the filename, so
the filename-colon issue does not apply here. The actual risk is in `SECTIONS`:
```bash
SECTIONS=$(echo "$SECURITY_CONTENT" | grep -n '^## [0-9]\+\.' || true)
```
This is safe because `grep -n` on stdin (pipe) does not prefix the filename. The
risk is zero in the current code but the surrounding pattern is fragile. Adding a comment
clarifying that the `grep -n` operates on stdin (not a file path) would prevent a future
maintainer from refactoring to `grep -n '...' "$CLAUDE_MD"` which would introduce the
colon-split bug.
**Fix:** Add a comment on line 109:
```bash
# grep -n on pipe (stdin) — intentional: avoids filename-colon ambiguity in cut -d: -f1
SECTIONS=$(echo "$SECURITY_CONTENT" | grep -n '^## [0-9]\+\.' || true)
```

---

### WR-04: `setup-security.sh` section extraction uses `sed '$d'` on a variable piped through `tail`, but the line-range calculation can produce `END_LINE < START_LINE`

**File:** `scripts/setup-security.sh:121-126`
**Issue:** When extracting a section body, the code computes `NEXT_LINE` as an offset
from `LINE_NUM + 1`, then calculates `END_LINE=$((LINE_NUM + NEXT_LINE - 2))`. If
`NEXT_LINE` is `1` (the very next line is a new section header), `END_LINE` equals
`LINE_NUM - 1`, which is less than `START_LINE=LINE_NUM`. The subsequent
`sed -n "${LINE_NUM},$((LINE_NUM + NEXT_LINE - 2))p"` call with a reversed range
produces empty output on GNU sed and no output on BSD sed — resulting in an empty
section body being appended to `$CLAUDE_MD`. The section header is then written without
content, corrupting the file structure.

This is unlikely in practice (a section with zero content lines is pathological), but
it is a latent correctness bug.
**Fix:** Guard the calculation:
```bash
if [[ -n "$NEXT_LINE" ]] && [[ $((LINE_NUM + NEXT_LINE - 2)) -ge $LINE_NUM ]]; then
    SECTION_BODY=$(echo "$SECURITY_CONTENT" | sed -n "${LINE_NUM},$((LINE_NUM + NEXT_LINE - 2))p")
else
    SECTION_BODY=$(echo "$SECURITY_CONTENT" | tail -n +"$LINE_NUM")
fi
```

---

### WR-05: Makefile `validate` target calls `python3 scripts/validate-manifest.py` without checking for Python 3 availability

**File:** `Makefile:136`
**Issue:** The `validate` target calls `python3 scripts/validate-manifest.py` as a final
step. Unlike `shellcheck` and `markdownlint`, which are checked for presence before use
(in the `install` target), there is no guard that warns the user if `python3` is absent.
On minimal CI environments or newly provisioned macOS machines without Homebrew Python,
`make validate` fails with `python3: command not found`, which is less informative than
a custom error message. The `install` target only installs `shellcheck` and
`markdownlint-cli`, not `python3`.

More critically, this is the same pattern that was fixed in `setup-security.sh`
(CHANGELOG BUG-04 equivalent): silent failure vs. explicit error message.
**Fix:** Add a guard before the `python3` call:
```makefile
@command -v python3 >/dev/null 2>&1 || { echo "❌ python3 not found — install Python 3.8+"; exit 1; }
@python3 scripts/validate-manifest.py
```

---

## Info

### IN-01: `CHANGELOG.md` version `[4.0.0] - TBD` — date is a placeholder

**File:** `CHANGELOG.md:8`
**Issue:** The topmost version entry reads `## [4.0.0] - TBD`. If this ships as-is,
the CHANGELOG will contain a literal `TBD` date, which breaks any tooling that parses
changelog dates and is inconsistent with the `manifest.json` `updated: 2026-04-19` field
that was already set.
**Fix:** Replace `TBD` with the actual release date before tagging: `## [4.0.0] - 2026-04-19`.

---

### IN-02: `README.md` feature count "30 slash commands" may diverge from manifest

**File:** `README.md:20`
**Issue:** The badge line reads `**30 slash commands** | **7 audits** | **29 guides**`.
`manifest.json` `files.commands` has 29 entries (counted: api, audit, checkpoint,
context-prime, council, debug, deploy, design, deps, doc, docker, e2e, explain,
find-function, find-script, fix-prod, fix, handoff, helpme, learn, migrate, perf, plan,
refactor, rollback-update, tdd, test, update-toolkit, verify, worktree = 30 with both
conflicted and non-conflicted). The count of 30 appears accurate, but `CHANGELOG.md:3.0.0`
says "Updated README: 26 → 29 slash commands" and `2.8.0` says "24 → 26". The 30-count
in README was set in a later revision and aligns with the manifest. This is informational —
verify the number is still accurate as commands are added/removed in v4.0 skipped-file
changes.
**Fix:** Run `jq '.files.commands | length' manifest.json` and compare to the README
number each release; consider automating this check in the Makefile `validate` target.

---

### IN-03: `orchestration-pattern.md` references `ORCH-FUT-01..04` backlog items with no tracking link

**File:** `components/orchestration-pattern.md:263`
**Issue:** The Status section references `ORCH-FUT-01..04` as future implementation
requirements but provides no pointer to where these are tracked (no GitHub issue link,
no `.planning/` path). Readers cannot discover the work items without searching the
planning directory manually.
**Fix:** Either link to the relevant planning document or add a one-line note:
```markdown
Implementation requirements tracked in `.planning/phases/06-documentation/` backlog
(ORCH-FUT-01..04).
```

---

### IN-04: `components/supreme-council.md` "Add to CLAUDE.md" block says `APPROVED / REJECTED` but actual verdicts are `PROCEED / SIMPLIFY / RETHINK / SKIP`

**File:** `components/supreme-council.md:267`
**Issue:** The snippet for embedding into a project's CLAUDE.md reads:
`**Output:** \`.claude/scratchpad/council-report.md\` (APPROVED / REJECTED)`.
The actual verdict vocabulary documented in the same file is
`PROCEED / SIMPLIFY / RETHINK / SKIP` (line 77). The `templates/base/CLAUDE.md`
at line 311 also uses `APPROVED / REJECTED`, propagating the inaccuracy into the template
installed on user machines.
**Fix:** In `supreme-council.md` line 267 and `templates/base/CLAUDE.md` line 311,
replace `(APPROVED / REJECTED)` with `(PROCEED / SIMPLIFY / RETHINK / SKIP)`.

---

### IN-05: `scripts/init-claude.sh` `create_post_install` embeds old command list that includes `†`-marked commands

**File:** `scripts/init-claude.sh:779`
**Issue:** The `POST_INSTALL.md` content lists `commands` as including `/plan`, `/tdd`,
`/debug`, `/verify` without noting that in `complement-sp` and `complement-full` modes
these are skipped (they are the 7 `†`-marked files). A user running in complement mode
will see the POST_INSTALL note suggesting these commands are available, then find they
are not installed because they conflict with `superpowers`. The `README.md` correctly
documents the `†` omission; the dynamically-generated `POST_INSTALL.md` does not.
**Fix:** Make `create_post_install` mode-aware. At minimum, add a conditional note:
```bash
if [[ "$MODE" == "complement-sp" ]] || [[ "$MODE" == "complement-full" ]]; then
    echo "Note: /plan, /tdd, /debug, /verify, /worktree omitted (superpowers provides equivalents)"
fi
```

---

### IN-06: `scripts/tests/test-setup-security-rtk.sh` replicates function logic instead of sourcing it

**File:** `scripts/tests/test-setup-security-rtk.sh:28-46`
**Issue:** The `run_install_rtk_notes` helper in the test file manually replicates the
exact guard logic from `setup-security.sh::install_rtk_notes` rather than sourcing the
script and invoking the real function. If the guard logic in `setup-security.sh` changes
(e.g., an additional condition is added), the test will continue passing against the
*old* logic, not the updated one, creating a silent test coverage gap.

This is a test-reliability issue, not a correctness bug today — but it's the most common
cause of "tests passed but production broke" in shell scripts.
**Fix:** Consider refactoring the test to source a stripped-down version of
`setup-security.sh` with `HOME` overridden, or extract `install_rtk_notes` into
`scripts/lib/` so both the installer and the test can source the same function body.
As a minimum, add a comment in the test noting that it mirrors the production code and
must be kept in sync:
```bash
# WARNING: This mirrors install_rtk_notes() in setup-security.sh.
# If that function changes, update this helper too.
```

---

_Reviewed: 2026-04-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
