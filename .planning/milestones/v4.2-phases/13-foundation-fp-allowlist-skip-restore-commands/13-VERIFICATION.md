---
phase: 13-foundation-fp-allowlist-skip-restore-commands
verified: 2026-04-25T16:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "CR-01: `/audit-restore` Step 2 grep matched the seeded HTML-comment example heading, enabling corruption of freshly-seeded audit-exceptions.md"
  gaps_remaining: []
  regressions: []
---

# Phase 13: Foundation — FP Allowlist + Skip/Restore Commands — Verification Report

**Phase Goal:** Users have a persistent, auto-loaded false-positive allowlist plus the commands to maintain it
**Verified:** 2026-04-25T16:00:00Z
**Status:** passed
**Re-verification:** Yes — after CR-01 gap closure (plan 13-05, commits f932407 + bbf9f5a)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can run `/audit-skip <file:line> <rule> <reason>` and see a structured block (location, rule, reason, date, council status) appended to `.claude/rules/audit-exceptions.md` | VERIFIED | `commands/audit-skip.md` exists, 241 lines. All 7 process steps substantive. Validation order: arg-count → git ls-files → awk line-count → grep -Fxq duplicate. Atomic two-temp write. Council enum with `unreviewed` default. markdownlint exits 0. No regression from initial verification. |
| 2 | User can run `/audit-restore <file:line> <rule>` and, after a `[y/N]` confirmation, see the matching entry removed from `audit-exceptions.md` | VERIFIED | CR-01 closed. `commands/audit-restore.md` exists, 263 lines. Step 2 now strips HTML comment blocks via `sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"` before `grep -Fxq` match. Step 3 display awk reads `$STRIPPED_TMP`. Step 5 delete awk gains `in_comment` state machine reading `$EXC_FILE` verbatim (preserves the comment block). Step 6 `mv "$NEW_TMP" "$EXC_FILE"` still atomic. Reproduction test passes: fresh-seed invocation exits 1 with `no entry found for scripts/setup-security.sh:142:SEC-RAW-EXEC`, file byte-identical. markdownlint exits 0. `make check` exits 0. |
| 3 | `/audit-skip` refuses to write when `<file:line>` is missing from `git ls-files` or beyond the file's line count, and refuses duplicates of `path:line + rule` (showing the existing record instead) | VERIFIED | Step 2: `git ls-files --error-unmatch -- "$PATH_PART"`. Step 3: `awk 'END{print NR}'` line-count check. Step 4: `grep -Fxq -- "$HEADING" "$EXC_FILE"` duplicate check + `grep -A 5 -F` to display full block. All three hard-refusal (no `--force`). No regression. |
| 4 | `audit-exceptions.md` ships with `globs: ["**/*"]` frontmatter so Claude auto-loads it in every session, schema-aligned with existing `.claude/rules/` files | VERIFIED | `templates/base/rules/audit-exceptions.md` exists. Frontmatter: `description:` first, then `globs:` with list-form `  - "**/*"`. `## Entries` H2 present. Example inside HTML comment (not a parseable entry). markdownlint exits 0. File unchanged from initial verification. |
| 5 | Running `init-claude.sh`, `init-local.sh`, or `update-claude.sh` against a project that already has a user-modified `audit-exceptions.md` leaves the file untouched; only first-time installs seed the empty template | VERIFIED | `init-claude.sh`: `create_audit_exceptions()` function at line 541 with `[[ -f "$exceptions_file" ]]; then return` guard, invoked at line 782. `init-local.sh`: POSIX `[ ! -f "$EXCEPTIONS_FILE" ]` guard at line 319. `update-claude.sh`: `[[ ! -f "$EXCEPTIONS_FILE" ]]` guard at line 975, `[[ $DRY_RUN -eq 1 ]]` integer form at 976. `make check` (shellcheck) exits 0 on all three. No regression. |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `templates/base/rules/audit-exceptions.md` | Seed allowlist template, `globs: ["**/*"]`, schema reference | VERIFIED | Exists. Frontmatter correct (list form). `## Entries` H2. Example inside `<!-- -->`. markdownlint clean. Unchanged from initial verification. |
| `commands/audit-skip.md` | Slash command spec with validation logic (EXC-01, EXC-04) | VERIFIED | Exists, 241 lines. All 7 process steps substantive. `git ls-files --error-unmatch`, `awk 'END{print NR}'`, `grep -Fxq`, `grep -A 5 -F`, atomic write. markdownlint clean. |
| `commands/audit-restore.md` | Slash command spec with [y/N] confirmation and HTML-comment safety (EXC-02) | VERIFIED | Exists, 263 lines (increased from 218 post-patch). CR-01 fix applied: `STRIPPED_TMP` + `sed` strip in Step 2, display awk reads `$STRIPPED_TMP` (Step 3), delete awk has `in_comment` state machine reading `$EXC_FILE` (Step 5). Consolidated trap covers both temps. Stale single-temp trap removed. Sanity check preserved. All 7 steps intact. markdownlint clean. |
| `scripts/init-claude.sh` | `create_audit_exceptions` function + invocation | VERIFIED | Function at line 541, idempotency guard at 544, DRY_RUN string form at 551, heredoc sentinel `EXCEPTIONS`. Invoked at line 782. shellcheck clean. |
| `scripts/init-local.sh` | Inline seed block `EXCEPTIONS_FILE` | VERIFIED | Block at line 317. POSIX single-bracket guard at 319. Heredoc sentinel `EXCEPTIONS`. shellcheck clean. |
| `scripts/update-claude.sh` | Idempotent seed guard near EOF, DRY_RUN integer-form | VERIFIED | Block at line 972. Double-bracket guard at 975. `[[ $DRY_RUN -eq 1 ]]` integer form at 976. shellcheck clean. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `templates/base/rules/audit-exceptions.md` | Claude session auto-load | `globs: ["**/*"]` frontmatter | VERIFIED | List form confirmed: `  - "**/*"` on its own line |
| `commands/audit-skip.md` (Process steps) | `.claude/rules/audit-exceptions.md` | Atomic append (BLOCK_TMP + NEW_TMP + mv) under `## Entries` H2 | VERIFIED | Confirmed unchanged |
| `commands/audit-skip.md` (validation) | git ls-files + line-count + duplicate-triple | Three hard-refusal checks | VERIFIED | All three present in Steps 2, 3, 4 |
| `commands/audit-restore.md` (Step 2) | `$STRIPPED_TMP` (HTML-comment-stripped copy) | `sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"` then `grep -Fxq -- "$HEADING" "$STRIPPED_TMP"` | VERIFIED | CR-01 fix: seeded example heading inside `<!-- -->` can never satisfy the search |
| `commands/audit-restore.md` (Step 3 display awk) | `$STRIPPED_TMP` | `awk ... ' "$STRIPPED_TMP"` | VERIFIED | Display awk reads comment-stripped copy; no comment-internal text reaches the user's screen |
| `commands/audit-restore.md` (Step 5 delete awk) | `$EXC_FILE` with `in_comment` guard | `awk ... in_comment` state machine; `' "$EXC_FILE" > "$NEW_TMP"` | VERIFIED | Reads original file; `in_comment` guard makes heading-match rule unreachable inside `<!-- -->` blocks; comment block preserved verbatim |
| `commands/audit-restore.md` (Step 6) | `$EXC_FILE` (original path) | `mv "$NEW_TMP" "$EXC_FILE"` | VERIFIED | Atomic mv to original path confirmed; `$STRIPPED_TMP` never replaces the file |
| `commands/audit-restore.md` (Step 4) | Interactive [y/N] confirmation | `read -r ANSWER < /dev/tty` | VERIFIED | `[y/N]` prompt text and `< /dev/tty` fallback present. Only `y|Y` proceeds. `Aborted` message on any other input. |
| `scripts/init-claude.sh:create_audit_exceptions` | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[[ ! -f ]]` guard | VERIFIED | Pattern `<< 'EXCEPTIONS'` and closing `EXCEPTIONS` sentinel confirmed |
| `scripts/init-local.sh` (rules block) | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[ ! -f ]` POSIX guard | VERIFIED | POSIX guard + heredoc confirmed |
| `scripts/update-claude.sh` (guard block near EOF) | `.claude/rules/audit-exceptions.md` | Heredoc `EXCEPTIONS` inside `[[ ! -f ]]` guard | VERIFIED | Block after `print_update_summary`. DRY_RUN integer form. |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase delivers markdown spec files (slash command documents) and shell installer scripts. There are no React/Vue/Svelte components or data-fetching layers. The "data" is the `audit-exceptions.md` file written at runtime when users invoke the commands.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Seed file has correct frontmatter | `grep -A 2 '^globs:' templates/base/rules/audit-exceptions.md` | `globs:\n  - "**/*"` | PASS |
| Step 2 sed strip present | `grep -Fc "sed '/^<!--/,/^-->/d'" commands/audit-restore.md` | 1 | PASS |
| STRIPPED_TMP count (≥4 uses) | `grep -c STRIPPED_TMP commands/audit-restore.md` | 7 | PASS |
| in_comment state machine present | `grep -c 'in_comment' commands/audit-restore.md` | 9 | PASS |
| 7 H3 steps preserved | `grep -cE '^### Step [1-7] ' commands/audit-restore.md` | 7 | PASS |
| Step 5 awk reads $EXC_FILE not $STRIPPED_TMP | `awk '/^### Step 5/,/^### Step 6/' commands/audit-restore.md \| grep -F "' \"$EXC_FILE\" > \"$NEW_TMP\""` | match | PASS |
| Stale single-temp trap removed | `grep -Ec "trap 'rm -f \"\\\$NEW_TMP\"' EXIT" commands/audit-restore.md` | 0 | PASS |
| Consolidated trap present | `grep -F "trap 'rm -f \"$STRIPPED_TMP\" \"$NEW_TMP\"' EXIT" commands/audit-restore.md` | match | PASS |
| Sanity check preserved | `grep -F 'audit-restore: deletion failed' commands/audit-restore.md` | match | PASS |
| [y/N] default-N gate | `grep -F '[y/N]' commands/audit-restore.md` | match | PASS |
| `< /dev/tty` fallback | `grep -F '< /dev/tty' commands/audit-restore.md` | match | PASS |
| Atomic mv to $EXC_FILE | `grep -F 'mv "$NEW_TMP" "$EXC_FILE"' commands/audit-restore.md` | match | PASS |
| No --force/-y flag | `grep -E -- '--force\|-y\b' commands/audit-restore.md` (filtered) | none | PASS |
| HTML-comment safe bullet in Key Principles | `grep -F 'HTML-comment safe' commands/audit-restore.md` | match | PASS |
| NOT staged reminder | `grep -F 'NOT staged' commands/audit-restore.md` | match | PASS |
| CR-01 repro: fresh-seed exits 1, file byte-identical | scratch fixture + Steps 1-2 with `scripts/setup-security.sh:142 SEC-RAW-EXEC` | exit 1, stderr = `no entry found for scripts/setup-security.sh:142:SEC-RAW-EXEC`, `diff -q` exit 0 | PASS |
| markdownlint on audit-restore.md | `markdownlint commands/audit-restore.md` | exit 0 | PASS |
| make check (full gate) | `make check` | exit 0, all checks passed | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EXC-01 | 13-02 | `/audit-skip` appends structured block (location, rule, reason, date, council status) | SATISFIED | `commands/audit-skip.md` delivers full 7-step spec. Entry block includes `**Date:**`, `**Council:**`, `**Reason:**` bullets. Atomic write confirmed. No regression. |
| EXC-02 | 13-03, 13-05 | `/audit-restore` removes entry after confirmation prompt; HTML-comment safe | SATISFIED | `commands/audit-restore.md` delivers restore spec with [y/N] confirmation and CR-01 fix. Step 2 strips comments before grep. Step 3 display reads stripped copy. Step 5 uses `in_comment` state machine preserving comment block verbatim. Reproduction test confirms fresh-seed corruption is impossible. |
| EXC-03 | 13-01 | `audit-exceptions.md` carries `globs: ["**/*"]` frontmatter, schema-aligned | SATISFIED | File exists with correct list-form frontmatter, `## Entries` H2, example inside HTML comment. markdownlint clean. |
| EXC-04 | 13-02 | `/audit-skip` validates `<file:line>` via `git ls-files` + line count; refuses duplicates | SATISFIED | Steps 2, 3, 4 confirm git-tracked check, line-count check, exact-triple duplicate check — all hard-refusal. No regression. |
| EXC-05 | 13-04 | Installers seed only when missing, never overwrite | SATISFIED | All three installer guards confirmed. `[[ -f ]]` / `[ ! -f ]` / `[[ ! -f ]]` guards present. DRY_RUN behavior correct per-script. shellcheck clean. |

---

### Anti-Patterns Found

None. CR-01 (the sole blocker from the initial verification) was closed by plan 13-05. The fix is surgical: single-file edit to `commands/audit-restore.md`, no side effects on other deliverables.

Note: WR-01 (awk `-v` failing silently for paths with backslashes in `audit-restore`) and WR-02 (EXIT trap coverage in `update-claude.sh`) remain as documented warnings from 13-REVIEW.md. WR-01 has a non-silent failure path (Step 5 sanity check catches it). WR-02 affects only temp files with no secrets. Neither rises to blocker for the Phase 13 goal. Both are out of scope for this gap-closure per 13-VERIFICATION.md lines 109-110.

---

### Human Verification Required

None — all success criteria are verifiable programmatically from the codebase state.

---

### Gap Closure Summary

**CR-01 closed** by plan 13-05 (commits f932407 + bbf9f5a).

The fix applied four edits to `commands/audit-restore.md`:

1. **Step 2:** Added `STRIPPED_TMP="$(mktemp)"` and `sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"` before the `grep -Fxq` search. The search target changed from `$EXC_FILE` to `$STRIPPED_TMP`. The consolidated `trap 'rm -f "$STRIPPED_TMP" "$NEW_TMP"' EXIT` was placed here (moved `NEW_TMP` creation up from Step 5).

2. **Step 3:** Display awk input changed from `"$EXC_FILE"` to `"$STRIPPED_TMP"`. Comment-internal text can never reach the user's confirmation screen.

3. **Step 5:** Delete awk gained an `in_comment` state machine. The `in_comment { ... print; next }` rule consumes every line between `^<!--` and `^-->` before the heading-match rule can fire. The awk still reads `$EXC_FILE` (not the stripped copy), so the seeded `<!-- Example entry -->` block is preserved verbatim in the rebuilt file. Stale single-temp trap removed.

4. **Key Principles:** New "HTML-comment safe" bullet added documenting the protection.

Reproduction confirms: on a project where `audit-exceptions.md` contains only the seeded template, running `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC` now prints `audit-restore: no entry found for scripts/setup-security.sh:142:SEC-RAW-EXEC` to stderr, exits 1, and leaves the file byte-identical to its pre-invocation state.

---

_Verified: 2026-04-25T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
