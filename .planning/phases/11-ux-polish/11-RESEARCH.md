# Phase 11: UX Polish - Research

**Researched:** 2026-04-24
**Domain:** Bash output formatting / ANSI color / chezmoi-grade diff UI
**Confidence:** HIGH

## Summary

Phase 11 introduces chezmoi-grade styled `--dry-run` output across three scripts.
The existing code base already has a partial dry-run output implementation in
`scripts/lib/install.sh:print_dry_run_grouped` (init flow only). The update and migrate
scripts have no grouped dry-run output — `update-claude.sh --dry-run` only applies to the
`--clean-backups` subcommand (not the main update flow), and `migrate-to-complement.sh --dry-run`
exits with a one-liner message after printing the plain three-column hash table. Both scripts need
net-new dry-run output functions.

The project already owns the correct TTY detection pattern (`[ -t 1 ]` in lib/install.sh and
matrix/lib/helpers.bash). What is missing is: (1) NO_COLOR env-var support, (2) grouped
output with right-aligned counts, (3) chezmoi-style `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` /
`[- REMOVE]` section headers, and (4) a shared `scripts/lib/dry-run-output.sh` library that all
three scripts can source.

**Primary recommendation:** Implement a single `scripts/lib/dry-run-output.sh` shared library
that encapsulates color gating and all four section printers. Wire it into all three scripts.
Update `test-dry-run.sh` assertions to match the new format; add parallel tests for update and
migrate dry-run output.

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UX-01 | init/update/migrate `--dry-run` produces chezmoi-grade grouped diff with colored `+/-/~` markers, right-aligned counts, NO_COLOR + non-TTY safe | Section 3 (shared lib design), Section 5 (NO_COLOR gate), Section 7 (backwards compat) |

</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Color gating (NO_COLOR + TTY) | Shared lib (`dry-run-output.sh`) | Caller scripts | Single gate, sourced once |
| Section header printing | Shared lib | — | Same format across all three scripts |
| File list collection | Each script | — | Each script knows its own file lists |
| Right-aligned count printf | Shared lib | — | `printf %-Xs %d` logic centralized |
| Init dry-run output | `init-claude.sh` + `lib/install.sh` | `dry-run-output.sh` | install.sh already owns this path |
| Update dry-run output | `update-claude.sh` | `dry-run-output.sh` | currently missing — new code |
| Migrate dry-run output | `migrate-to-complement.sh` | `dry-run-output.sh` | currently missing — new code |

## Current State Audit

### 1. `scripts/init-claude.sh --dry-run`

**Flag parsed:** Line 26-27 — `--dry-run) DRY_RUN=true`

**Execution path:** `download_files()` at line 394 checks `DRY_RUN == "true"` and calls
`print_dry_run_grouped "$MANIFEST_FILE" "$MODE"` then `exit 0`. The function is defined in
`scripts/lib/install.sh` lines 74-125. [VERIFIED: codebase read]

**Current output format (per lib/install.sh lines 107-113):**

```text
[SKIP - conflicts_with:superpowers]  superpowers/commands/debug.md
[INSTALL] commands/plan.md
[INSTALL] commands/tdd.md
...
Total: 42 install, 8 skip
```

Color: `[INSTALL]` is GREEN, `[SKIP...]` is YELLOW. No right-alignment, no section grouping (per-line interleaved). TTY detection uses `[ -t 1 ]` (line 77). NO_COLOR is NOT checked. [VERIFIED: codebase read]

**Existing tests:** `scripts/tests/test-dry-run.sh` greps for:
- `\[INSTALL\]` — exact bracket pattern
- `\[SKIP` — prefix match (accommodates `[SKIP - conflicts_with:...]`)
- `^Total:` — footer presence
- No ANSI escapes when stdout not a TTY [VERIFIED: test-dry-run.sh lines 62-86]

**CRITICAL:** Changing `[INSTALL]` to `[+ INSTALL]` or moving to grouped output **breaks all three
existing test assertions**. The test file must be updated as part of this phase.

### 2. `scripts/update-claude.sh --dry-run`

**Flag parsed:** Line 29 — `--dry-run) DRY_RUN_CLEAN=1`

**CRITICAL FINDING:** `--dry-run` on `update-claude.sh` currently ONLY affects the
`--clean-backups` subcommand path. When `--clean-backups` is NOT passed, `--dry-run` has no
effect on the main update flow. There is no `print_update_dry_run` or equivalent function.
[VERIFIED: codebase read — `DRY_RUN_CLEAN` is only consumed at line 379 inside
`run_clean_backups` dispatch block]

**What exists for post-run summary:** `print_update_summary()` at lines 315-356 prints four
groups (INSTALLED / UPDATED / SKIPPED / REMOVED) with color using `[ -t 1 ]` TTY detection.
NO_COLOR is NOT checked.

**Pre-existing accumulators:** `INSTALLED_PATHS`, `UPDATED_PATHS`, `SKIPPED_PATHS`,
`REMOVED_PATHS` arrays are already populated during the update loop. A dry-run output function
can consume these same arrays after populating them without writing files.

**Scope decision required:** Should `update-claude.sh --dry-run` (standalone, without
`--clean-backups`) trigger a diff preview of what would be installed/updated/removed? Per
UX-01 requirement: "shows the same color-coded grouped style for INSTALL / UPDATE / SKIP / REMOVE
groups." This implies YES — `--dry-run` must be a global flag for the full update flow, not just
cleanup. The plan must add a new `DRY_RUN` variable separate from `DRY_RUN_CLEAN`.

### 3. `scripts/migrate-to-complement.sh --dry-run`

**Flag parsed:** Line 27 — `--dry-run) DRY_RUN=1`

**Current behavior:** Runs the full detect + enumerate + three-column hash table display, then
at line 259-261 exits with `log_info "--dry-run: the files above would be removed."` The existing
three-column hash table is printed before the dry-run exit — this is useful context to preserve.

**What needs to change:** The `log_info` one-liner exit message should be replaced with (or
preceded by) a grouped `[- REMOVE]` block showing what files would be removed, followed by a
count. The three-column hash table can remain as-is above the new section.

**Current migrate output before dry-run exit:**

```text
  path                                      TK tmpl    on-disk    SP equiv
  ────────────────────────────────────────  ────────   ────────   ────────
  commands/debug.md                         abc12345   abc12345   def67890
  ...
```

The new dry-run section should follow this table with a styled `[- REMOVE]` group.

## chezmoi Format Reference

chezmoi's `chezmoi apply --dry-run` produces unified diff output per-file — it delegates to
`diff` and is file-content-focused, not action-grouped. The relevant "chezmoi-grade" comparison
in the ROADMAP context refers to its **visual quality standard**: clean structure, grouped actions,
right-aligned counts, color markers. [ASSUMED — based on chezmoi docs and UX-01 description]

The target format per UX-01 Success Criteria and ROADMAP.md:

```text
[+ INSTALL]                              5 files
  commands/plan.md
  commands/tdd.md
  commands/debug.md
  agents/code-reviewer.md
  agents/planner.md

[~ UPDATE]                               2 files
  commands/audit.md
  rules/README.md

[- SKIP]                                12 files
  (conflicts_with:superpowers — 12 files)

Total: 19 files
```

For update flow, groups are: `[+ INSTALL]`, `[~ UPDATE]`, `[- SKIP]`, `[- REMOVE]`.
For migrate flow, single group: `[- REMOVE]`.

**Right-alignment:** Fixed 80-column layout is recommended over `tput cols` — simpler, no TTY
dependency for the width calculation itself, works universally. The count is right-aligned within
the section header line using `printf`. [ASSUMED — no canonical standard, fixed 80-col is
conventional]

**Concrete `printf` pattern for aligned header:**

```bash
# Fixed 80-col: label is ~12 chars, count is right-padded to fill to col 44, then " N files"
printf '%b%-42s%6d files%b\n' "$_GREEN" "[+ INSTALL]" "$install_count" "$_NC"
```

Or using fixed-width column at position 48:

```bash
printf '%b[+ INSTALL]%b%*s%d files\n' "$_GREEN" "$_NC" $((48 - ${#label})) "" "$count"
```

Simpler: just printf with fixed field widths confirmed to align at 80 cols:

```bash
printf '%b%-44s %4d files%b\n' "$COLOR" "[+ INSTALL]" "$count" "$NC"
```

## Shared Library Decision

**Recommendation: single `scripts/lib/dry-run-output.sh`** sourced by all three scripts.
[VERIFIED: precedent established — `scripts/lib/backup.sh` was created in Phase 9 for
`warn_if_too_many_backups` shared across update and migrate scripts]

**Rationale:**
1. All three scripts need identical color gating logic (NO_COLOR + TTY)
2. All three scripts need identical section header formatting with right-aligned counts
3. `print_dry_run_grouped` in `install.sh` already lives in a lib — it should migrate to
   `dry-run-output.sh` or be refactored there
4. Avoids three-way drift when format is tweaked later

**Functions to define in `scripts/lib/dry-run-output.sh`:**

```bash
# Color gating — sets _DRO_G, _DRO_C, _DRO_Y, _DRO_R, _DRO_NC
dro_init_colors()

# Print one section header with right-aligned count
# Args: $1=marker ("+" | "-" | "~"), $2=label ("INSTALL"), $3=count, $4=color-var-name
dro_print_header()

# Print one file line (2-space indent)
# Args: $1=filepath
dro_print_file()

# Print total footer
# Args: $1=total-count  (or variadic key:count pairs)
dro_print_total()
```

**Sourcing:** Init-claude.sh and update-claude.sh already download lib files from remote via
`curl`. The shared lib must be downloaded the same way as `lib/install.sh` and `lib/backup.sh`.
Migrate already downloads `lib/backup.sh`. Adding `dry-run-output.sh` to the same download
pattern. [VERIFIED: scripts download lib files via `curl -sSLf "$REPO_URL/scripts/lib/..."` into
a mktemp file then source it]

**Alternative: Keep inline per-script:** Avoids adding a new curl fetch for a dry-run-only path,
but creates three divergent implementations. Given that `install.sh` already has
`print_dry_run_grouped` as precedent, a shared lib is the correct call.

**Decision on `print_dry_run_grouped` in `lib/install.sh`:** The function can remain in
`install.sh` for backward compat (it is sourced by `init-claude.sh`), but should be refactored
to call `dro_*` functions from `dry-run-output.sh`. Alternatively, keep it in `install.sh` and
only put the new update/migrate variants in `dry-run-output.sh`. The simplest path: put all
dry-run output functions in `dry-run-output.sh`, have `install.sh` source it (or duplicate
remains, since both are downloaded). The planner will decide — document both options.

## NO_COLOR + TTY Detection Pattern

**Standard:** The [no-color.org](https://no-color.org) standard specifies that when `NO_COLOR`
environment variable is present (any value, including empty string), ANSI colors must be
disabled. `[ -z "${NO_COLOR+x}" ]` tests for presence (not value). [CITED: no-color.org]

**Combined gate (project-consistent):**

The project currently uses `[ -t 1 ]` alone (in `lib/install.sh:77`, `lib/helpers.bash:31`,
`update-claude.sh:print_update_summary:318`). None check `NO_COLOR`. The new shared lib should
add NO_COLOR support while staying backward compatible. [VERIFIED: codebase grep]

**Recommended pattern for `dro_init_colors()`:**

```bash
dro_init_colors() {
    # NO_COLOR: disable if env var is present (any value, per no-color.org)
    # TTY: disable if stdout is not a terminal
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _DRO_G='\033[0;32m'   # green  — + INSTALL
        _DRO_C='\033[0;36m'   # cyan   — ~ UPDATE
        _DRO_Y='\033[1;33m'   # yellow — - SKIP
        _DRO_R='\033[0;31m'   # red    — - REMOVE
        _DRO_NC='\033[0m'
    else
        _DRO_G=''
        _DRO_C=''
        _DRO_Y=''
        _DRO_R=''
        _DRO_NC=''
    fi
}
```

**Note on `${NO_COLOR+x}` vs `${NO_COLOR:-}`:**
- `${NO_COLOR+x}` — non-empty when variable is SET (even if empty string) — correct per spec
- `${NO_COLOR:-}` — expands to empty when unset OR empty — does not distinguish `NO_COLOR=` from
  unset — incorrect for strict no-color compliance

Use `${NO_COLOR+x}` with `set -u` safety because bare `$NO_COLOR` in an unset state fails under
`set -euo pipefail`. [VERIFIED: bash 3.2 behavior]

## Width and Alignment Approach

**Recommendation: Fixed 44-column label field + 6-column count field = ~52 chars total.**

```bash
# Section header: "[+ INSTALL]" padded to 44 chars, then count right-aligned in 6 chars
printf '%b%-44s%6d files%b\n' "$_DRO_G" "[+ INSTALL]" "$install_count" "$_DRO_NC"
```

Sample output (color removed for display):

```text
[+ INSTALL]                               5 files
[~ UPDATE]                                2 files
[- SKIP]                                 12 files
[- REMOVE]                                0 files
```

This is legible at 80-col and 120-col terminals. Avoids `tput cols` complexity (requires
terminal, fails in non-TTY). [ASSUMED — no canonical standard, practical choice]

## Marker Semantics Table

| Action | Marker | Color | When |
|--------|--------|-------|------|
| Install new file | `[+ INSTALL]` | GREEN | Init: file in manifest, not on disk |
| Skip (conflict) | `[- SKIP]` | YELLOW | Init: file conflicts with SP/GSD bucket |
| Update existing | `[~ UPDATE]` | CYAN | Update: file changed in manifest |
| Install new | `[+ INSTALL]` | GREEN | Update: new file added to manifest |
| Remove stale | `[- REMOVE]` | RED | Update: file removed from manifest |
| Skip (unchanged) | `[- SKIP]` | YELLOW | Update: file in manifest, no changes |
| Remove duplicate | `[- REMOVE]` | RED | Migrate: duplicate file to be deleted |

Chezmoi uses `+` for create, `-` for delete, `~` for modify. Mapping is consistent with that
convention. [CITED: chezmoi.io/user-guide/tools/diff/]

## Backwards Compatibility Scan

**Test assertions that grep current dry-run output:**

`scripts/tests/test-dry-run.sh` (runs via `make check` → `Makefile:72-73`):

```bash
grep -qE '\[INSTALL\]'    # line 62 — BREAKS if changed to [+ INSTALL]
grep -qE '\[SKIP'         # line 68 — SURVIVES [- SKIP] (prefix match)
grep -qE '^Total:'        # line 74 — SURVIVES if Total: footer kept
```

[VERIFIED: test-dry-run.sh lines 62-86]

**CI:** `.github/workflows/quality.yml` does NOT grep dry-run output format patterns. The
`test-dry-run.sh` is invoked via `make test` (Makefile:73), not the CI quality workflow. The CI
`test-init-script` job runs `init-local.sh` against synthetic projects but does not capture or
assert on dry-run format. [VERIFIED: .github/workflows/quality.yml scan — no `[INSTALL]` grep]

**README / docs:** No grep for `[INSTALL]` or `[SKIP` format patterns. [VERIFIED: grep on
docs/ and README.md]

**Impact summary:**

| Location | Pattern | Impact | Action |
|----------|---------|--------|--------|
| `test-dry-run.sh:62` | `\[INSTALL\]` | BREAKS | Update to `\[+ INSTALL\]` |
| `test-dry-run.sh:68` | `\[SKIP` | Survives | `[- SKIP]` still matches prefix |
| `test-dry-run.sh:74` | `^Total:` | Survives | Keep `Total:` footer |
| CI quality.yml | none | No impact | No action needed |
| README / docs | none | No impact | No action needed |

**One test assertion must be updated.** The planner should include this in the plan for the
init dry-run output task.

## Validation Architecture

**nyquist_validation is enabled** (`config.json:19: "nyquist_validation": true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Plain bash test scripts (no bats for these tests) |
| Config file | None — scripts in `scripts/tests/`, run via Makefile |
| Quick run command | `bash scripts/tests/test-dry-run.sh` |
| Full suite command | `make check` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 (init) | `[+ INSTALL]` / `[- SKIP]` grouped with counts | unit | `bash scripts/tests/test-dry-run.sh` | ✅ (needs update) |
| UX-01 (update) | `[+ INSTALL]` / `[~ UPDATE]` / `[- SKIP]` / `[- REMOVE]` grouped | unit | `bash scripts/tests/test-update-dry-run.sh` | ❌ Wave 0 |
| UX-01 (migrate) | `[- REMOVE]` grouped output replaces one-liner | unit | `bash scripts/tests/test-migrate-dry-run.sh` | ❌ Wave 0 |
| UX-01 (NO_COLOR) | `NO_COLOR=1` suppresses ANSI escapes in all scripts | unit | inline in above tests | ❌ Wave 0 |
| UX-01 (non-TTY) | piped stdout suppresses ANSI (already tested in test-dry-run.sh) | unit | `bash scripts/tests/test-dry-run.sh` | ✅ line 82-86 |

### Wave 0 Gaps

- [ ] `scripts/tests/test-update-dry-run.sh` — covers update dry-run grouped output
- [ ] `scripts/tests/test-migrate-dry-run.sh` — covers migrate `[- REMOVE]` grouped output
- [ ] NO_COLOR assertions in all three test files
- [ ] `scripts/lib/dry-run-output.sh` — new shared library

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-dry-run.sh`
- **Per wave merge:** `make check`
- **Phase gate:** Full `make check` green before `/gsd-verify-work`

## Common Pitfalls

### Pitfall 1: `set -u` with `${NO_COLOR}`

**What goes wrong:** `NO_COLOR` is typically unset. Under `set -euo pipefail`, bare `$NO_COLOR`
causes an unbound variable error.
**How to avoid:** Use `${NO_COLOR+x}` to test presence, or `${NO_COLOR:-}` for value (but see
semantics note in Section 5). The `+x` pattern is safe under `set -u`.
**Warning signs:** Script dies with `NO_COLOR: unbound variable` when NO_COLOR not exported.

### Pitfall 2: Sourced library altering caller error mode

**What goes wrong:** `lib/install.sh` header says "No errexit/pipefail — sourced libraries must
not alter caller error mode." The new `dry-run-output.sh` must follow the same rule.
**How to avoid:** Do NOT put `set -euo pipefail` in `dry-run-output.sh`.
**Warning signs:** shellcheck may flag missing `set -e` — that is intentional for sourced libs.

### Pitfall 3: `update-claude.sh` — `DRY_RUN_CLEAN` vs new `DRY_RUN`

**What goes wrong:** The existing flag variable `DRY_RUN_CLEAN` controls `--clean-backups` dry
preview. Adding a general update dry-run needs a separate variable (`DRY_RUN=0`). Reusing
`DRY_RUN_CLEAN` would conflate the two behaviors.
**How to avoid:** Add `DRY_RUN=0` alongside `DRY_RUN_CLEAN=0`. The `--dry-run` parser line
(currently `--dry-run) DRY_RUN_CLEAN=1`) must set BOTH when `--clean-backups` is not passed,
OR set only `DRY_RUN=1` and refactor. Cleanest: `--dry-run` sets `DRY_RUN=1`; `--clean-backups
--dry-run` sets both `CLEAN_BACKUPS=1` and `DRY_RUN_CLEAN=1`. Need to check current arg parsing
for compound flags. [VERIFIED: update-claude.sh args are flat positional, not compound — can add
`DRY_RUN=0` as separate var without conflict]

### Pitfall 4: `update-claude.sh --dry-run` still downloads manifest + runs detect

**What goes wrong:** The update dry-run must show what WOULD happen, which requires: fetching the
remote manifest, running detect.sh, computing diffs. These are read-only operations and are safe.
The plan must NOT short-circuit before diff computation.
**How to avoid:** Insert dry-run exit AFTER `DIFFS_JSON` and accumulator computation, BEFORE the
backup creation and actual file writes.

### Pitfall 5: Breaking existing `test-dry-run.sh` assertions

**What goes wrong:** `grep -qE '\[INSTALL\]'` fails after rename to `[+ INSTALL]`.
**How to avoid:** Update the assertion regex to `\[+ INSTALL\]` or `\[.* INSTALL\]` as part of
the same commit that changes the output format.

### Pitfall 6: `printf` with color codes breaks `%s` padding

**What goes wrong:** `printf '%-44s'` counts bytes, not visible characters. ANSI codes add
invisible bytes that throw off padding when mixed into the format string.
**How to avoid:** Apply color to the ENTIRE formatted line, not around the label inside
`printf`. Pattern: `printf '%b%-44s%6d files%b\n' "$_DRO_G" "[+ INSTALL]" "$count" "$_DRO_NC"`.
The `%b` specifier expands escape sequences; color codes surround (not interleave) the padded
content. [VERIFIED: bash printf behavior]

## Planner Implications

### Recommended Plan Structure: 3 Plans

**Why not 1 plan:** The three scripts have different complexity levels (init is already 80%
done; update needs net-new update dry-run logic; migrate needs one new section). Separating
into 3 plans allows safer incremental delivery with test coverage per plan.

**Why not 4 plans:** A separate "shared lib only" plan with no script wiring is impractical —
the lib is small and can be created alongside its first consumer.

**Recommended plans:**

| Plan | Scope | Complexity |
|------|-------|------------|
| 11-01 | `scripts/lib/dry-run-output.sh` + refactor `init-claude.sh` dry-run output to use it. Update `test-dry-run.sh` assertions. | Medium |
| 11-02 | `update-claude.sh` — add `DRY_RUN` flag for full update flow; wire `dro_*` printers; add `test-update-dry-run.sh`. | High |
| 11-03 | `migrate-to-complement.sh` — replace one-liner dry-run exit with `[- REMOVE]` group; add `test-migrate-dry-run.sh`. | Low |

**Plan 11-01 must be completed before 11-02 and 11-03** (shared lib dependency).

**Task breakdown within 11-01:**

1. Create `scripts/lib/dry-run-output.sh` with `dro_init_colors`, `dro_print_header`,
   `dro_print_file`, `dro_print_total`
2. Refactor `lib/install.sh:print_dry_run_grouped` to call `dro_*` functions (or inline-replace)
3. Update `test-dry-run.sh` to match new `[+ INSTALL]` format
4. `shellcheck` + `make check` green

**Task breakdown within 11-02:**

1. Add `DRY_RUN=0` to `update-claude.sh` arg parsing (distinct from `DRY_RUN_CLEAN`)
2. Source `dry-run-output.sh` in update-claude.sh (same mktemp + curl pattern)
3. After `DIFFS_JSON` computed, insert dry-run exit with grouped output (before backup)
4. Create `scripts/tests/test-update-dry-run.sh` with assertions

**Task breakdown within 11-03:**

1. In `migrate-to-complement.sh`, source `dry-run-output.sh`
2. Replace `log_info "--dry-run: the files above..."` with `[- REMOVE]` group using
   `${DUPLICATES[@]}`
3. Create `scripts/tests/test-migrate-dry-run.sh` with assertions

## Environment Availability

Step 2.6: SKIPPED — Phase is purely code/config changes. No external tools beyond `bash`,
`jq`, and `curl` are needed. All are already required by the scripts this phase modifies.

## Sources

### Primary (HIGH confidence)

- Codebase read: `scripts/lib/install.sh` — current `print_dry_run_grouped` implementation
- Codebase read: `scripts/update-claude.sh` — current flag parsing and `print_update_summary`
- Codebase read: `scripts/migrate-to-complement.sh` — current dry-run exit path
- Codebase read: `scripts/tests/test-dry-run.sh` — existing test assertions (backwards compat)
- Codebase read: `scripts/tests/matrix/lib/helpers.bash` — TTY detection pattern
- Codebase read: `.github/workflows/quality.yml` — CI does not parse dry-run output format

### Secondary (MEDIUM confidence)

- [no-color.org](https://no-color.org) — NO_COLOR standard specification
- [chezmoi.io diff guide](https://www.chezmoi.io/user-guide/tools/diff/) — chezmoi diff UX
  reference (visual quality bar, not output format to replicate exactly)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Fixed 44-col label / 6-col count layout aligns at 80-col terminals | Width section | Minor: cosmetic only, trivially adjustable |
| A2 | "chezmoi-grade" means visual quality bar (grouped, colored, counted), not exact output format replication | chezmoi Format Reference | Low: UX-01 spec says "matches chezmoi's diff presentation quality" not "identical format" |
| A3 | `update-claude.sh --dry-run` (without `--clean-backups`) should preview full update diff | Current State Audit §2 | Medium: if wrong, UX-01 SC2 means something else. Planner should clarify |

## Metadata

**Confidence breakdown:**

- Current state audit: HIGH — direct codebase reads, no assumptions
- Standard stack: HIGH — same libraries already in use
- Backwards compat: HIGH — verified test assertions and CI
- Architecture: HIGH — precedent from lib/backup.sh
- Pitfalls: HIGH — derived from existing code patterns

**Research date:** 2026-04-24
**Valid until:** Stable — no external dependencies; valid until codebase changes
