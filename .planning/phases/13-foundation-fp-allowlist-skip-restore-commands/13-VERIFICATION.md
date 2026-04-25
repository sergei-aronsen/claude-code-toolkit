---
phase: 13-foundation-fp-allowlist-skip-restore-commands
verified: 2026-04-25T15:30:00Z
status: gaps_found
score: 4/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "User can run `/audit-restore <file:line> <rule>` and, after a `[y/N]` confirmation, see the matching entry removed from `audit-exceptions.md`"
    status: partial
    reason: "CR-01: `grep -Fxq` in Step 2 matches the example heading inside the seeded HTML comment block. Running `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` on any freshly-seeded project (which is the common case) deletes lines from inside the `<!-- -->` block, leaving an unclosed HTML comment in `audit-exceptions.md`. Claude then auto-loads this malformed file every session. The awk display (Step 3) and delete (Step 5) operate on the whole file with no comment-awareness, so the corruption is committed by Step 6 mv. The Step 5 sanity check passes because the heading is successfully removed — the error is not caught."
    artifacts:
      - path: "commands/audit-restore.md"
        issue: "Step 2 `grep -Fxq -- \"$HEADING\" \"$EXC_FILE\"` matches inside HTML comment blocks. No comment-stripping (e.g., `sed '/^<!--/,/^-->/d'`) applied before the match."
    missing:
      - "In Step 2 of `commands/audit-restore.md`, strip HTML comment blocks from the search file before the `grep -Fxq` match. Recommended fix from 13-REVIEW.md CR-01: `sed '/^<!--/,/^-->/d' \"$EXC_FILE\" > \"$STRIPPED_TMP\"` then grep against `$STRIPPED_TMP`. Apply the same strip to the display (Step 3) and delete (Step 5) awk passes, or verify they cannot reach comment lines via their existing stop conditions."
---

# Phase 13: Foundation — FP Allowlist + Skip/Restore Commands — Verification Report

**Phase Goal:** Users have a persistent, auto-loaded false-positive allowlist plus the commands to maintain it
**Verified:** 2026-04-25T15:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can run `/audit-skip <file:line> <rule> <reason>` and see a structured block (location, rule, reason, date, council status) appended to `.claude/rules/audit-exceptions.md` | VERIFIED | `commands/audit-skip.md` exists (241 lines). All 7 Process steps are substantive Bash. Validation order (arg-count → git ls-files → awk line-count → grep -Fxq duplicate), atomic two-temp write, council enum with `unreviewed` default. markdownlint exits 0. |
| 2 | User can run `/audit-restore <file:line> <rule>` and, after a `[y/N]` confirmation, see the matching entry removed from `audit-exceptions.md` | PARTIAL | `commands/audit-restore.md` exists (218 lines) with [y/N] prompt, `< /dev/tty` fallback, awk sentinel-blank deletion, atomic mv, no `--force`. However, CR-01 confirmed: `grep -Fxq` in Step 2 matches the example heading inside the seeded HTML comment. Reproducing: run `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` on any fresh-seeded project; the command displays the comment block, user confirms, awk deletes from heading to EOF (no following `###` or `##`), leaving an unclosed `<!--`. The Step 5 sanity check PASSES (heading gone) and `mv` commits the corrupted file. |
| 3 | `/audit-skip` refuses to write when `<file:line>` is missing from `git ls-files` or beyond the file's line count, and refuses duplicates of `path:line + rule` (showing the existing record instead) | VERIFIED | Step 2: `git ls-files --error-unmatch -- "$PATH_PART"`. Step 3: `awk 'END{print NR}'` line-count check. Step 4: `grep -Fxq -- "$HEADING" "$EXC_FILE"` duplicate check + `grep -A 5 -F` to display full block. All three are hard-refusal (no `--force`). |
| 4 | `audit-exceptions.md` ships with `globs: ["**/*"]` frontmatter so Claude auto-loads it in every session, schema-aligned with existing `.claude/rules/` files | VERIFIED | `templates/base/rules/audit-exceptions.md` exists. Frontmatter: `description:` first, then `globs:` in list form (`  - "**/*"`). `## Entries` H2 present. Example inside HTML comment (not a parseable entry). Not in `manifest.json` per CD-01. markdownlint exits 0. `grep -c $'—'` returns 3 (H1 separator + example H3 + example text). |
| 5 | Running `init-claude.sh`, `init-local.sh`, or `update-claude.sh` against a project that already has a user-modified `audit-exceptions.md` leaves the file untouched; only first-time installs seed the empty template | VERIFIED | `init-claude.sh`: `create_audit_exceptions()` function with `[[ -f "$exceptions_file" ]]; then return` guard + DRY_RUN string form. `init-local.sh`: `[ ! -f "$EXCEPTIONS_FILE" ]` POSIX guard, no per-block DRY_RUN. `update-claude.sh`: `[[ ! -f "$EXCEPTIONS_FILE" ]]` double-bracket guard, `[[ $DRY_RUN -eq 1 ]]` integer form. All three heredoc bodies diff-identical to `templates/base/rules/audit-exceptions.md`. shellcheck exits 0 on all three. |

**Score:** 4/5 truths verified (SC-2 partial due to CR-01)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `templates/base/rules/audit-exceptions.md` | Seed allowlist template, `globs: ["**/*"]`, schema reference | VERIFIED | Exists. Frontmatter correct (list form). `## Entries` H2. Example inside `<!-- -->`. 26 lines. markdownlint clean. |
| `commands/audit-skip.md` | Slash command spec with validation logic (EXC-01, EXC-04) | VERIFIED | Exists, 241 lines (min 120). All 7 process steps substantive. `git ls-files --error-unmatch`, `awk 'END{print NR}'`, `grep -Fxq`, `grep -A 5 -F`, atomic write. markdownlint clean. |
| `commands/audit-restore.md` | Slash command spec with [y/N] confirmation (EXC-02) | PARTIAL | Exists, 218 lines (min 100). All 7 process steps present. [y/N] prompt, `< /dev/tty`, awk deletion, atomic mv, no `--force`. CR-01 bug: comment-unaware grep matches seeded example heading, enabling corruption of fresh installs. |
| `scripts/init-claude.sh` | `create_audit_exceptions` function + invocation | VERIFIED | Function at line 541, idempotency guard at 544, DRY_RUN string form at 551, heredoc sentinel `EXCEPTIONS`. Invoked at line 782 (line after `create_lessons_learned`). shellcheck clean. |
| `scripts/init-local.sh` | Inline seed block `EXCEPTIONS_FILE` | VERIFIED | Block at line 317-348. POSIX single-bracket guard. No per-block DRY_RUN (script-level early exit covers it). `(seed)` suffix on success message. shellcheck clean. |
| `scripts/update-claude.sh` | Idempotent seed guard near EOF, DRY_RUN integer-form | VERIFIED | Block at line 972-1008. Double-bracket guard. `[[ $DRY_RUN -eq 1 ]]` integer form. `mkdir -p "$CLAUDE_DIR/rules"` defensive. shellcheck clean. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `templates/base/rules/audit-exceptions.md` | Claude session auto-load | `globs: ["**/*"]` frontmatter | VERIFIED | List form confirmed: `  - "**/*"` on its own line |
| `commands/audit-skip.md` (Process steps) | `.claude/rules/audit-exceptions.md` | Atomic append (temp + mv) under `## Entries` H2 | VERIFIED | `BLOCK_TMP` + `NEW_TMP` + `mv "$NEW_TMP" "$EXC_FILE"` confirmed |
| `commands/audit-skip.md` (validation) | git ls-files + line-count + duplicate-triple | Three hard-refusal checks | VERIFIED | All three present in Steps 2, 3, 4 |
| `commands/audit-restore.md` (Process steps) | `.claude/rules/audit-exceptions.md` | awk block deletion (atomic temp+mv) | PARTIAL | `mv "$NEW_TMP" "$EXC_FILE"` present and atomic. However Step 2 `grep -Fxq` does not distinguish real entries from HTML-commented examples — CR-01 bug. |
| `commands/audit-restore.md` (Step 4) | Interactive [y/N] confirmation | `read -r ANSWER < /dev/tty` | VERIFIED | Both `[y/N]` prompt text and `< /dev/tty` fallback present. Only `y|Y` proceeds. |
| `scripts/init-claude.sh:create_audit_exceptions` | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[[ ! -f ]]` guard | VERIFIED | Pattern `<< 'EXCEPTIONS'` and closing `EXCEPTIONS` sentinel confirmed. Body diff-identical to template. |
| `scripts/init-local.sh` (rules block) | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[ ! -f ]` POSIX guard | VERIFIED | `EXCEPTIONS_FILE=` variable + POSIX guard + heredoc confirmed. Body diff-identical. |
| `scripts/update-claude.sh` (guard block near EOF) | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[[ ! -f ]]` guard | VERIFIED | Block after `print_update_summary`, before `recommend_optional_plugins`. Body diff-identical. |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase delivers markdown spec files (slash command documents) and shell installer scripts. There are no React/Vue/Svelte components or data-fetching layers. The "data" is the `audit-exceptions.md` file written at runtime when users invoke the commands.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Seed file has correct frontmatter | `grep -A 2 '^globs:' templates/base/rules/audit-exceptions.md` | `globs:\n  - "**/*"` | PASS |
| Seed file not in manifest.json | `grep 'audit-exceptions' manifest.json` | no output | PASS |
| Heredoc bodies byte-identical (init-claude.sh) | `diff <(awk extraction) templates/base/rules/audit-exceptions.md` | empty diff | PASS |
| Heredoc bodies byte-identical (init-local.sh) | `diff <(awk extraction) templates/base/rules/audit-exceptions.md` | empty diff | PASS |
| Heredoc bodies byte-identical (update-claude.sh) | `diff <(awk extraction) templates/base/rules/audit-exceptions.md` | empty diff | PASS |
| CR-01 corruption reproducible | `grep -Fxq '### scripts/setup-security.sh:142 — SEC-RAW-EXEC' templates/base/rules/audit-exceptions.md` | MATCH | FAIL — confirms bug exists in seeded file |
| markdownlint on all three md deliverables | `npx markdownlint-cli "templates/base/rules/audit-exceptions.md" "commands/audit-skip.md" "commands/audit-restore.md"` | exit 0, no output | PASS |
| shellcheck on all three installer scripts | `shellcheck -S warning scripts/init-claude.sh scripts/init-local.sh scripts/update-claude.sh` | exit 0, no output | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EXC-01 | 13-02 | `/audit-skip` appends structured block (location, rule, reason, date, council status) | SATISFIED | `commands/audit-skip.md` delivers full 7-step spec. Entry block includes `**Date:**`, `**Council:**`, `**Reason:**` bullets. Atomic write confirmed. |
| EXC-02 | 13-03 | `/audit-restore` removes entry after confirmation prompt | PARTIALLY SATISFIED | `commands/audit-restore.md` delivers the restore spec with [y/N] confirmation, but CR-01 means the command can corrupt `audit-exceptions.md` when the example heading matches. The removal succeeds for real entries; only the comment-awareness gap is missing. |
| EXC-03 | 13-01 | `audit-exceptions.md` carries `globs: ["**/*"]` frontmatter, schema-aligned | SATISFIED | File exists with correct list-form frontmatter, `## Entries` H2, example inside HTML comment. markdownlint clean. |
| EXC-04 | 13-02 | `/audit-skip` validates `<file:line>` via `git ls-files` + line count; refuses duplicates | SATISFIED | Steps 2, 3, 4 confirm git-tracked check, line-count check, exact-triple duplicate check — all hard-refusal. |
| EXC-05 | 13-04 | Installers seed only when missing, never overwrite | SATISFIED | All three installer guards confirmed. Heredoc bodies byte-identical to template. DRY_RUN behavior correct per-script. shellcheck clean. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `commands/audit-restore.md` | Step 2 (lines 78-88) | `grep -Fxq -- "$HEADING" "$EXC_FILE"` with no HTML-comment stripping | Blocker | On any fresh-seeded project, running `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` matches inside the `<!-- -->` example block. Confirmed by `grep -Fxq` returning a match against the template file. The awk deletion then excises lines from inside the comment through EOF, leaving an unclosed `<!--` that corrupts every subsequent auto-loaded Claude session. |

Note: WR-01 (awk `-v` failing silently for paths with backslashes in `audit-restore`) and WR-02 (EXIT trap coverage in `update-claude.sh`) are warnings from 13-REVIEW.md. WR-01 has a confusing but non-silent failure path (Step 5 sanity check catches it with "deletion failed"). WR-02 affects temp files with no secrets. Neither rises to blocker for the Phase 13 goal; they are listed for awareness.

---

### Human Verification Required

None — all success criteria are verifiable programmatically from the codebase state.

---

### Gaps Summary

**1 gap blocking goal achievement.**

**CR-01: `/audit-restore` can corrupt `audit-exceptions.md` on fresh installs**

The freshly-seeded `audit-exceptions.md` contains an HTML comment block with an example entry:

```text
<!--
Example entry (this comment is intentionally not a real entry):

### scripts/setup-security.sh:142 — SEC-RAW-EXEC
...
-->
```

The `grep -Fxq` in Step 2 of `commands/audit-restore.md` operates on the raw file with no HTML-comment awareness. Running `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` on any project where `audit-exceptions.md` was just seeded (and contains only the template content):

1. Step 2 `grep -Fxq` MATCHES — confirms (incorrectly) that the heading is a real entry.
2. Step 3 awk DISPLAYS the comment block — user sees what looks like a real entry.
3. User confirms with `y`.
4. Step 5 awk DELETES from the heading to EOF (no following `###` or `##` to stop the block) — removes `Allowed Council values:` and the closing `-->`.
5. Step 5 sanity check PASSES — heading is gone, so the check sees no error.
6. Step 6 `mv` COMMITS the corrupted file.

Result: `audit-exceptions.md` has an unclosed `<!--`, which corrupts markdown rendering and Claude's auto-loaded context for every subsequent session.

**Fix:** Add HTML-comment stripping before the `grep -Fxq` match in Step 2 of `commands/audit-restore.md`:

```bash
STRIPPED_TMP="$(mktemp)"
trap 'rm -f "$STRIPPED_TMP"' EXIT
sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"

if ! grep -Fxq -- "$HEADING" "$STRIPPED_TMP"; then
    printf 'audit-restore: no entry found for %s:%s:%s\n' "$PATH_PART" "$LINE_PART" "$RULE" >&2
    exit 1
fi
```

Apply the same strip (or add `in_comment` tracking) to the display awk (Step 3) and the delete awk (Step 5) so they also cannot touch lines inside comment blocks.

The root cause is a single missing pre-processing step; the rest of the `audit-restore` spec is correct and complete.

---

_Verified: 2026-04-25T15:30:00Z_
_Verifier: Claude (gsd-verifier)_
