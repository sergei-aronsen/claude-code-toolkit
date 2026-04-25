# /audit-restore — Remove a False-Positive Exception from the Allowlist

## Purpose

Remove an entry from `.claude/rules/audit-exceptions.md` when an exception turns out to be a
real bug — for example, after a refactor changes the threat model or the Council
(`/council audit-review` — Phase 15) marks a previously-suppressed finding `disputed`.

Removal is guarded by an interactive `[y/N]` prompt that defaults to NO. The full entry block
is displayed before the prompt so the user sees exactly what will be deleted.

---

## Usage

```text
/audit-restore <file:line> <rule>
```

**Examples:**

- `/audit-restore src/foo.ts:42 SEC-XSS`
- `/audit-restore scripts/setup-security.sh:142 SEC-RAW-EXEC`

---

## When to Use

- After a refactor changes the data flow that justified the original exception.
- After a Council `audit-review` pass (Phase 15) returns `disputed` for a previously-suppressed entry.
- When the rule itself is removed from the auditor's rule set (the entry is now meaningless).
- DO NOT use to "shut up" a stale exception you don't understand — read the original Reason
  field first; if the Reason no longer applies, that's a sign you genuinely want to restore.

---

## Process

### Step 1 — Parse Arguments

Parse the two required positional tokens: `<file:line>` and `<rule>`. No reason argument, no
flags beyond the two positional tokens.

```bash
set -euo pipefail

ARGS=("$@")
if [ "${#ARGS[@]}" -ne 2 ]; then
    printf 'audit-restore: usage: /audit-restore <file:line> <rule>\n' >&2
    exit 2
fi

FILE_LINE="${ARGS[0]}"
RULE="${ARGS[1]}"

PATH_PART="${FILE_LINE%:*}"
LINE_PART="${FILE_LINE##*:}"

case "$LINE_PART" in
    ''|*[!0-9]*)
        printf 'audit-restore: <file:line> must end with :<positive integer>, got %q\n' "$FILE_LINE" >&2
        exit 2
        ;;
esac

EXC_FILE=".claude/rules/audit-exceptions.md"
HEADING="### ${PATH_PART}:${LINE_PART} — ${RULE}"
```

The em-dash in the `HEADING` string is a literal U+2014 character `—`. Type it directly — do
not escape as `&mdash;` or `&#8212;`.

### Step 2 — Find Entry

Confirm the target file exists and that the exact heading is present. Print a diagnostic to
stderr and exit non-zero if either check fails.

Before the grep match, strip HTML comment blocks into a temp copy so the seeded example
heading inside `<!-- -->` can never satisfy the search — even when the user types the example
heading verbatim. Both temp files are declared here so a single `trap` covers them for the
rest of the script.

```bash
if [ ! -f "$EXC_FILE" ]; then
    printf 'audit-restore: %s does not exist; nothing to restore\n' "$EXC_FILE" >&2
    exit 1
fi

# Strip HTML comment blocks before searching, so the seeded example heading
# inside <!-- --> in the freshly-seeded template can never match a real entry.
# We also create NEW_TMP up front so a single trap cleans both temps on exit.
STRIPPED_TMP="$(mktemp)"
NEW_TMP="$(mktemp)"
trap 'rm -f "$STRIPPED_TMP" "$NEW_TMP"' EXIT

sed '/^<!--/,/^-->/d' "$EXC_FILE" > "$STRIPPED_TMP"

if ! grep -Fxq -- "$HEADING" "$STRIPPED_TMP"; then
    printf 'audit-restore: no entry found for %s:%s:%s\n' "$PATH_PART" "$LINE_PART" "$RULE" >&2
    exit 1
fi
```

The `sed` strip and the `STRIPPED_TMP` copy guarantee that the seeded `<!-- Example entry -->`
block in the template can never satisfy the `grep -Fxq` match, even when the user types the
example heading verbatim. The original `$EXC_FILE` is left untouched on disk.

### Step 3 — Display Entry Block

Print the heading and its body block to stdout so the user can read exactly what will be
deleted before confirming. Use awk to extract lines from the heading until the next H3, H2, or
EOF.

The display awk reads `$STRIPPED_TMP` so it cannot dump comment-internal text to the user's
screen — there is no scenario where the user is asked to confirm deletion of a fake entry.

```bash
awk -v h="$HEADING" '
    BEGIN { in_block = 0 }
    $0 == h { in_block = 1; print; next }
    in_block && /^### / { exit }
    in_block && /^## /  { exit }
    in_block { print }
' "$STRIPPED_TMP"
```

### Step 4 — Confirm Deletion

Prompt the user for confirmation. Read from `/dev/tty` so the prompt works inside a
piped/curl context (per CONTEXT.md "Established Patterns"). Fall back to plain `read` from
stdin if `/dev/tty` is unreadable (e.g. in CI without a TTY). Only `y` or `Y` proceeds —
every other response (including pressing Enter) aborts.

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

### Step 5 — Build New File (block removed)

Use awk to rewrite the file with the matched block removed. A sentinel-blank variable buffers
each blank line so that the blank line immediately preceding the deleted heading is dropped
along with the block — leaving no double-blank residue. Stop conditions for the block are the
next `###` heading (another entry), `##` heading (another H2 — defensive), or EOF.

```bash
# NEW_TMP and the consolidated trap were already established in Step 2.
# This awk uses an in_comment state machine so the heading-match rule is
# never reachable while inside a <!-- ... --> block. The comment block in
# the seeded template is therefore preserved verbatim across the rebuild.
awk -v h="$HEADING" '
    BEGIN { skip = 0; pending_blank = 0; in_comment = 0 }
    # Enter a comment block. Flush any buffered blank, print the delimiter,
    # and switch into in_comment mode. Never enter skip mode while inside.
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
    # Buffer a blank line: if the next line is the heading, drop the blank too.
    /^$/ {
        if (skip) next
        if (pending_blank) print prev_blank
        prev_blank = $0
        pending_blank = 1
        next
    }
    $0 == h {
        skip = 1
        pending_blank = 0  # drop the blank we just buffered (the one before the heading)
        next
    }
    skip && /^### / { skip = 0 }
    skip && /^## /  { skip = 0 }
    skip { next }
    {
        if (pending_blank) { print prev_blank; pending_blank = 0 }
        print
    }
    END { if (pending_blank) print prev_blank }
' "$EXC_FILE" > "$NEW_TMP"

# Sanity check — the heading must no longer be present.
# Note: this still operates on $NEW_TMP, NOT on a stripped copy. If the
# seeded example heading is the only "match" (i.e. inside the comment),
# Step 2 already exited non-zero before reaching here, so this check
# remains a meaningful defense against awk logic errors on real entries.
if grep -Fxq -- "$HEADING" "$NEW_TMP"; then
    printf 'audit-restore: deletion failed — heading still present in output\n' >&2
    exit 1
fi
```

The sentinel-blank logic ensures a blank line that precedes the deleted heading is also
removed. The `in_comment` state machine ensures `<!-- -->` blocks (including the seeded
example) are passed through verbatim — the heading-match rule is unreachable while
`in_comment == 1`. The block is delimited by the next `###` heading (another entry), `##`
heading (another H2 — defensive), or EOF.

### Step 6 — Atomic Replace

Replace the original file with the rewritten temp file atomically. The `mv` operation is
atomic on the same filesystem and safe under `set -euo pipefail`.

```bash
mv "$NEW_TMP" "$EXC_FILE"
```

### Step 7 — Confirm to User

Print a success summary and remind the user that the change is NOT staged. Staging and commit
are the user's responsibility (CD-02).

```bash
printf '\033[0;32m✓\033[0m Removed exception: %s:%s — %s\n' "$PATH_PART" "$LINE_PART" "$RULE"
printf '\nFile updated: %s\n' "$EXC_FILE"
printf 'Note: changes are NOT staged. Run `git add %s` and commit when ready.\n' "$EXC_FILE"
```

---

## Key Principles

- **Default-N confirmation** — pressing Enter aborts. Only `y` or `Y` proceeds. (D-08)
- **Display before delete** — the user sees the full block (heading + Date/Council/Reason) before the prompt.
- **Exact triple match** — `<path>:<line>:<rule>` byte-for-byte. Same key as `/audit-skip`.
- **Block-only removal** — only the matched heading + its body bullets + the preceding blank
  line are deleted. Frontmatter, intro paragraph, `## Entries` H2, and other entries are
  untouched.
- **HTML-comment safe** — example blocks inside `<!-- -->` are never matched, displayed, or
  deleted. Step 2 and Step 3 read a comment-stripped copy of the file; Step 5 rebuilds with
  an `in_comment` guard so the seeded `<!-- Example entry -->` block is preserved verbatim
  across every restore.
- **Atomic write** — temp + `mv`, never partial.
- **No git side effects** — write the file only; staging is the user's call.

---

## Related Commands

- `/audit-skip <file:line> <rule> <reason...>` — add an exception. Inverse of this command.
- `/audit` — runs the audit pipeline that consults `audit-exceptions.md` (Phase 14).
- `/council audit-review` — confirms or rejects findings; can flag a stale exception as
  `disputed` (Phase 15).
