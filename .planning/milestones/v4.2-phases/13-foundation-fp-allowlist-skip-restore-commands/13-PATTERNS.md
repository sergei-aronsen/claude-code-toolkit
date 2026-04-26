# Phase 13: Foundation — FP Allowlist + Skip/Restore Commands — Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 6 (4 new, 2 modified installer sections + 1 update-claude.sh guard)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `templates/base/rules/audit-exceptions.md` | rule template | write-once seed, read-many by Claude | `templates/base/rules/project-context.md` | exact |
| `commands/audit-skip.md` | slash command spec | request → validate → append to rule file | `commands/learn.md` | exact |
| `commands/audit-restore.md` | slash command spec | request → confirm → delete from rule file | `commands/learn.md` + `commands/council.md` | role-match |
| `scripts/lib/audit-exceptions.sh` | shared lib (conditional) | sourced by callers, no I/O of its own | `scripts/lib/dry-run-output.sh` | exact |
| `scripts/init-claude.sh` lines ~539-560 | installer mutation | inline heredoc seed, written once | `scripts/init-claude.sh:514-538` (lessons-learned block) | exact |
| `scripts/init-local.sh` lines ~315-325 | installer mutation | inline heredoc seed, written once | `scripts/init-local.sh:303-315` (lessons-learned block) | exact |
| `scripts/update-claude.sh` (new guard block) | installer mutation | idempotency guard for mutable seed file | `scripts/update-claude.sh:457` (`[[ ! -f "$STATE_FILE" ]]`) | role-match |

---

## Pattern Assignments

### `templates/base/rules/audit-exceptions.md` (rule template, write-once seed)

**Analog:** `templates/base/rules/project-context.md`

**Frontmatter pattern** (lines 1-5):

```yaml
---
description: Core project facts — architecture, servers, services, recent changes
globs:
  - "**/*"
---
```

**Heading / body structure** (full file, lines 1-33):

```markdown
---
description: Core project facts — architecture, servers, services, recent changes
globs:
  - "**/*"
---

# [Project Name] — Project Context

## Architecture

- **Stack:** [Framework + Frontend + Database]
- **Type:** [SaaS/API/Dashboard/etc.]
```

**Notable deviations audit-exceptions.md must introduce:**

1. `description:` value: `"Audit false-positive allowlist — entries suppressed by /audit-skip"`
2. Body must include an intro paragraph explaining the file role and how `/audit-skip` writes to it (D-02).
3. A single `## Entries` H2 replaces the project-context sections.
4. One commented-out HTML example block under `## Entries` showing the entry schema — this is novel; no existing rule file has an HTML comment example inside the content body.
5. Entry heading anchor format `### <path>:<line> — <rule-id>` (em-dash U+2014) with three required bold-key bullets (`**Date:**`, `**Council:**`, `**Reason:**`) is entirely novel — no existing rule file has positional sub-entries.
6. The file is NOT installed via `manifest.json`'s `files.rules[]`; it is seeded inline (per CD-01).

---

### `commands/audit-skip.md` (slash command spec, request-response + append)

**Analog:** `commands/learn.md`

**Document structure pattern** (lines 1-18 of learn.md):

```markdown
# /learn — Extract Reusable Patterns

## Purpose

Extract problem solutions and save them as **scoped rule files** that auto-load only for relevant files.

---

## Usage

```text
/learn [description]
```

**Examples:**

- `/learn` — Analyze session and find patterns
- `/learn prisma connection pooling fix` — Save a specific solution
```

**Step-numbered Process pattern** (lines 43-133 of learn.md — the Process section):

```markdown
## Process

### Step 1 — Analyze

Identify what was learned. Look at:
...

### Step 4 — Save to Scoped Rule File

**Target:** `.claude/rules/[scope].md`

If the file already exists — **append** the new rule at the end.
```

**Key Principles / Iron Rules footer pattern** (lines 193-199 of learn.md):

```markdown
## Key Principles

- **Narrowest scope wins** — never use `globs: ["**/*"]` unless truly global
- **One rule file per domain** — not per lesson (avoid file explosion)
- **Append, don't rewrite** — add to existing rule files
- **Deduplicate** — check before adding
- **Confirm** — always show user before saving
```

**Audit trail step** (lines 107-125 of learn.md):

```markdown
### Step 5 — Log to Audit Trail

Append a one-line summary to `.claude/rules/lessons-learned.md`:

```markdown
- [Date] [scope] — [Short title]. Rule saved to rules/[scope].md
```

This file is the **history log** — a human-readable record of all lessons.
```

**Notable deviations audit-skip.md must introduce:**

1. **Argument signature section** (D-04): `<file:line> <rule> <reason...>` positional syntax, no quoting required, with a concrete invocation example.
2. **Pre-write Validation section** (D-05): three hard-refusal checks (git-tracked, line-count, duplicate) described as Bash steps Claude executes — no equivalent in learn.md.
3. **Duplicate check** (D-06): exact triple `<path>:<line>:<rule>` match; on collision, print the blocking entry and refuse.
4. **`--council=` optional flag** (D-09): sets `council_status` field; default is `unreviewed`.
5. **Post-write behavior** (CD-02): write only — no `git add`, no `git commit`; state this explicitly.
6. **Atomic write**: append to a temp file then `mv` to final path (per codebase constraints, not present in learn.md).
7. No Step 5 audit-trail log (audit-exceptions.md is itself the audit trail for exceptions; no secondary log needed).

---

### `commands/audit-restore.md` (slash command spec, request → confirm → delete)

**Analog:** `commands/learn.md` (structure) + `commands/council.md` (confirmation flow pattern)

**Confirmation flow pattern from council.md** (lines 56-97 — the Step 3/4 read-report block):

```markdown
### Step 3 — Read Report

Read `.claude/scratchpad/council-report.md` and analyze the verdict:

- **PROCEED** — plan is justified, start implementation
...

### Step 4 — Report to User

Before writing code, output:

```text
Council review completed. Verdict: [PROCEED/SIMPLIFY/RETHINK/SKIP].
Key findings: [brief summary].
[Commencing implementation / Adjusting plan / Skipping task].
```
```

**Step-numbered Process shell** (from learn.md Step 1-6 shape — copy heading / body cadence):

```markdown
## Process

### Step 1 — Find Entry

Search `.claude/rules/audit-exceptions.md` for the exact triple `<path>:<line>:<rule>`.

### Step 2 — Display

Print the full ATX-heading block to be deleted.

### Step 3 — Confirm

Prompt `[y/N]` (default N). Read via `< /dev/tty` inside curl|bash context.
```

**Notable deviations audit-restore.md must introduce:**

1. **Argument signature**: `<file:line> <rule>` only — no reason trailing tokens (D-07).
2. **Confirmation flow** (D-08): mandatory `[y/N]` before deletion; default N; print the full heading block being removed. No equivalent in learn.md (which always confirms before save, not delete).
3. **No-match case**: print `no entry found for <triple>` and exit non-zero.
4. **Block deletion semantics**: remove the heading AND its three bullet lines, leaving the `## Entries` H2 and surrounding entries intact.
5. **`< /dev/tty`** for the Y/N read in case command is run inside a piped context (per codebase constraint).

---

### `scripts/lib/audit-exceptions.sh` (shared lib, conditional — CD-03)

**Analog:** `scripts/lib/dry-run-output.sh`

**Library header + no-errexit contract** (lines 1-11 of dry-run-output.sh):

```bash
#!/bin/bash

# Claude Code Toolkit — Dry-Run Output Library (Phase 11 / UX-01)
# Source this file. Do NOT execute it directly.
# Exposes: dro_init_colors, dro_print_header, dro_print_file, dro_print_total
# Globals: _DRO_G _DRO_C _DRO_Y _DRO_R _DRO_NC (set by dro_init_colors)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
...

dro_init_colors() {
```

**Function signature style** (lines 48-54 of dry-run-output.sh):

```bash
dro_print_header() {
    local marker="$1" label="$2" count="$3" color_var="$4"
    local color_val=""
    eval "color_val=\${$color_var:-}"
    local header_text="[${marker} ${label}]"
    printf '%b%-44s%6d files%b\n' "$color_val" "$header_text" "$count" "${_DRO_NC:-}"
}
```

**Notable deviations audit-exceptions.sh must introduce** (only create if CD-03 dedup trigger met):

1. Expose functions: `ae_find_entry`, `ae_append_entry`, `ae_delete_entry`, `ae_check_duplicate`.
2. No color constants needed (all output is via callers); omit the `dro_init_colors` pattern.
3. All functions must be POSIX-compatible (no GNU flags, no `sed -i` without BSD handling).
4. Atomic write pattern: `ae_append_entry` writes to `mktemp` then `mv` to final path.

---

### `scripts/init-claude.sh` — new seed block (installer mutation)

**Analog:** `scripts/init-claude.sh:514-538` — the existing `create_lessons_learned` function

**Exact pattern to replicate** (lines 514-538 of init-claude.sh):

```bash
# Create lessons-learned seed file
create_lessons_learned() {
    local lessons_file="$CLAUDE_DIR/rules/lessons-learned.md"

    if [[ -f "$lessons_file" ]]; then
        return
    fi

    echo ""
    echo -e "${BLUE}📝 Creating lessons-learned seed file...${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create: $lessons_file"
    else
        cat > "$lessons_file" << 'LESSONS'
---
description: Audit log of all lessons learned (history only, not auto-loaded)
globs: []
---
# Lessons Learned — Audit Log
<!-- History of lessons saved by /learn. Actual rules are in scoped files (e.g., rules/database.md). -->
LESSONS
        echo -e "  ${GREEN}✓${NC} rules/lessons-learned.md"
    fi
}
```

**Notable deviations for the new `create_audit_exceptions` function:**

1. `local file="$CLAUDE_DIR/rules/audit-exceptions.md"` (different variable name).
2. Guard: `if [[ -f "$file" ]]; then return; fi` — identical guard, same idempotency contract.
3. Heredoc label: `'EXCEPTIONS'` (avoids collision with `'LESSONS'` sentinel).
4. Heredoc body: YAML frontmatter (`globs: ["**/*"]`, `description:`) + intro paragraph + `## Entries` H2 + HTML comment example block.
5. The new function must be called from the main install flow at approximately the same position as `create_lessons_learned` (after directory creation, before recommendations).

---

### `scripts/init-local.sh` — new seed block (installer mutation)

**Analog:** `scripts/init-local.sh:303-315` — inline lessons-learned seed

**Exact pattern to replicate** (lines 303-315 of init-local.sh):

```bash
# Create lessons-learned seed file
LESSONS_FILE="$CLAUDE_DIR/rules/lessons-learned.md"
if [ ! -f "$LESSONS_FILE" ]; then
    cat > "$LESSONS_FILE" << 'LESSONS'
---
description: Audit log of all lessons learned (history only, not auto-loaded)
globs: []
---
# Lessons Learned — Audit Log
<!-- History of lessons saved by /learn. Actual rules are in scoped files (e.g., rules/database.md). -->
LESSONS
    echo -e "  ${GREEN}✓${NC} rules/lessons-learned.md (seed)"
fi
```

**Notable deviations:**

1. Variable: `EXCEPTIONS_FILE="$CLAUDE_DIR/rules/audit-exceptions.md"`.
2. Guard: `if [ ! -f "$EXCEPTIONS_FILE" ]` — single-bracket POSIX form matches init-local.sh style (init-local.sh uses `[` while init-claude.sh uses `[[`; preserve each file's existing style).
3. Heredoc label: `'EXCEPTIONS'`.
4. Success message: `rules/audit-exceptions.md (seed)`.
5. Placement: immediately after the lessons-learned block (~line 316).

---

### `scripts/update-claude.sh` — new idempotency guard (installer mutation)

**Analog:** `scripts/update-claude.sh:457` — existing state-file idempotency guard

**Pattern to replicate** (lines 457-458 of update-claude.sh):

```bash
if [[ ! -f "$STATE_FILE" ]]; then
    synthesize_v3_state "$MANIFEST_TMP"
fi
```

**Broader seed-file guard shape** (from init-claude.sh create_lessons_learned, lines 518-520):

```bash
if [[ -f "$lessons_file" ]]; then
    return
fi
```

**Notable deviations for update-claude.sh:**

1. Guard placement: near the end of update-claude.sh, after the main manifest-driven update loop completes, so it runs on every `update-claude.sh` invocation but only seeds when missing.
2. No function wrapper needed — inline block matches update-claude.sh's inline style (the script uses inline `if [[ ! -f ... ]]` blocks, not named functions like init-claude.sh does).
3. Must write the same heredoc content as init-claude.sh / init-local.sh (identical seed body — single source of truth is the seed content defined in D-02).
4. `DRY_RUN` support: update-claude.sh already has `DRY_RUN` flag; the guard block must check `[[ "$DRY_RUN" -eq 1 ]]` (integer, matching update-claude.sh's `DRY_RUN=0` style) vs init-claude.sh's `[[ "$DRY_RUN" == true ]]` (string). Use the integer form.

---

## Shared Patterns

### YAML Frontmatter for Rule Files

**Source:** `templates/base/rules/project-context.md` lines 1-5
**Apply to:** `templates/base/rules/audit-exceptions.md`

```yaml
---
description: <one-line description>
globs:
  - "**/*"
---
```

`globs: ["**/*"]` means auto-loaded into every Claude session. Use for audit-exceptions.md because suppressions apply repo-wide.

---

### Inline Heredoc Seed (idempotent, never overwrites)

**Source:** `scripts/init-claude.sh:514-538`, `scripts/init-local.sh:303-315`
**Apply to:** Both installer mutations

Core contract:
- Check `[ ! -f "$FILE" ]` before writing — never clobber user edits.
- Write via `cat > "$file" << 'HEREDOC_SENTINEL'` with single-quoted sentinel (no variable expansion inside).
- Echo green checkmark after write.

---

### Slash Command Document Structure

**Source:** `commands/learn.md` (200 lines, full document)
**Apply to:** `commands/audit-skip.md`, `commands/audit-restore.md`

Required top-level sections in order:

```markdown
# /<command> — <tagline>

## Purpose
## Usage
## When to Use
## Process
  ### Step 1 — ...
  ### Step N — ...
## Key Principles   (or "Iron Rules")
```

Optional: `## Deduplication`, `## Related Commands`, `## Example Session`.

---

### Shell Script Library Contract

**Source:** `scripts/lib/dry-run-output.sh` lines 1-11
**Apply to:** `scripts/lib/audit-exceptions.sh` (if CD-03 triggers extraction)

```bash
#!/bin/bash
# <description>
# Source this file. Do NOT execute it directly.
# Exposes: <function list>
# Globals: <global vars if any>
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
```

---

### Atomic Write for Rule File Mutations

**Source:** `scripts/init-local.sh` / codebase constraints section of CONTEXT.md
**Apply to:** `commands/audit-skip.md` (append step), `commands/audit-restore.md` (delete step), `scripts/lib/audit-exceptions.sh` (if extracted)

Pattern (must be stated in slash command Process steps):

```bash
# Write to temp, then mv atomically
tmp=$(mktemp)
# ... build content ...
cat "$existing_file" >> "$tmp"   # or: write new block to tmp
mv "$tmp" "$existing_file"
```

---

## No Analog Found

No files in this phase lack a codebase analog. All six artifacts have close matches as documented above.

---

## Metadata

**Analog search scope:** `templates/base/rules/`, `commands/`, `scripts/`, `scripts/lib/`
**Files scanned:** 10 (project-context.md, README.md, lessons-learned.md, learn.md, audit.md, council.md, dry-run-output.sh, backup.sh, init-claude.sh, init-local.sh, update-claude.sh)
**Pattern extraction date:** 2026-04-25
