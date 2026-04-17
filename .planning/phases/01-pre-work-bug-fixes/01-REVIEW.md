---
phase: 01-pre-work-bug-fixes
reviewed: 2026-04-17T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - CHANGELOG.md
  - Makefile
  - scripts/init-claude.sh
  - scripts/init-local.sh
  - scripts/setup-council.sh
  - scripts/setup-security.sh
  - scripts/update-claude.sh
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-17
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 01 addressed 7 bugs across installer scripts and CI tooling. The fixes are
generally sound: POSIX `sed '$d'` portability (BUG-01), `/dev/tty` guards (BUG-02),
`python3 json.dumps` escaping (BUG-03), removal of silent `sudo` (BUG-04),
timestamped backup/restore in security setup (BUG-05), runtime version from
`manifest.json` (BUG-06), and manifest/loop drift check in Makefile (BUG-07).

Three warning-level issues were found:

1. **BUG-04 implementation leaves both `if` branches identical** — the `tree`
   install prompt in `setup-council.sh` asks "Proceed?" but neither branch actually
   installs tree or behaves differently. The Y branch prints one extra advisory line.
   The prompt is misleading and the `if` test has a dead `else` body.

2. **`setup-security.sh` writes `settings.json` in-place** — if the Python process is
   killed (SIGKILL, OOM) after `open('w')` truncates the file but before `json.dump`
   completes, the backup exists but is not restored automatically (no `trap`). The
   backup/restore only fires on a non-zero Python exit code.

3. **`setup-council.sh` verification uses an unquoted path in a `python3 -c` string** —
   `$COUNCIL_DIR` is interpolated directly into a double-quoted Python string literal
   (`open('$COUNCIL_DIR/brain.py')`). If `HOME` or the council path contains a
   single-quote or backslash, the Python one-liner will produce a syntax error.
   Low-exploitability in practice (HOME is user-controlled, not attacker-controlled)
   but a latent correctness bug.

No critical security vulnerabilities were found. All BUG-0x fixes are correctly
applied where they were targeted.

## Warnings

### WR-01: Misleading prompt and dead else-branch in apt-get tree flow (BUG-04)

**File:** `scripts/setup-council.sh:76-84`
**Issue:** The `read` prompt says "Proceed?" implying the script will run
`sudo apt-get install tree` if the user answers `y`. It does not. Both the `y` and
`n` branches print the same "tree not found — brain.py structure analysis will be
skipped" message. The only difference is an extra advisory line in the `y` branch.
The `else` body is functionally dead code and the prompt is misleading.

```diff
-        if [[ "${INSTALL_TREE:-N}" =~ ^[Yy]$ ]]; then
-            echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
-            echo -e "  Run the command above in a separate terminal, then re-run setup-council.sh if you want tree support."
-        else
-            echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
-        fi
+        # User acknowledged — print the skip notice regardless
+        echo -e "  ${YELLOW}⚠${NC} tree not found — brain.py structure analysis will be skipped"
+        if [[ "${INSTALL_TREE:-N}" =~ ^[Yy]$ ]]; then
+            echo -e "  Run the command above in a separate terminal, then re-run setup-council.sh if you want tree support."
+        fi
```

Also consider rewording the prompt to: `"  Acknowledge and continue? [Y/n]: "` so
users do not expect the script to run `sudo` on their behalf.

---

### WR-02: Non-atomic write to settings.json without trap-based restore

**File:** `scripts/setup-security.sh:203-248`, `:317-349`, `:359-387`
**Issue:** All three Python merge blocks back up `settings.json` and restore from
backup if Python exits non-zero. However, the Python script opens the file with `'w'`
(which truncates it immediately) and then calls `json.dump`. If the process is killed
between truncation and the write completing (SIGKILL, OOM kill, `Ctrl+C` mid-write),
the file is left empty/corrupt and the backup is never restored because no `trap`
is registered.

**Fix:** Register a `trap` for `EXIT`/`INT`/`TERM` that restores the backup if the
file is corrupt, or write to a temp file first and `mv` atomically:

```python
# Inside each PYEOF block — replace direct write with atomic write
import json, sys, os, tempfile

settings_path = sys.argv[1]
# ... build config ...

tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(settings_path))
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)   # atomic on same filesystem
except Exception:
    os.unlink(tmp_path)
    raise
```

Alternatively, add a shell `trap` to restore on unexpected exit:

```bash
SETTINGS_BACKUP="${SETTINGS_JSON}.bak.$(date +%s)"
cp "$SETTINGS_JSON" "$SETTINGS_BACKUP"
trap 'cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"' ERR EXIT
python3 - ... << 'PYEOF'
...
PYEOF
trap - ERR EXIT   # clear trap after success
```

---

### WR-03: Path injection in python3 -c verification one-liner

**File:** `scripts/setup-council.sh:285`
**Issue:** The brain.py syntax check expands `$COUNCIL_DIR` directly inside a
double-quoted shell string that becomes the Python one-liner:

```bash
python3 -c "import ast; ast.parse(open('$COUNCIL_DIR/brain.py').read())" 2>/dev/null
```

If `$COUNCIL_DIR` (derived from `$HOME`) contains a single-quote or backslash, the
Python literal breaks. Example: `HOME="/Users/o'brien"` → produces invalid Python
`open('/Users/o'brien/.claude/council/brain.py')`. While `HOME` is developer-set
and not directly attacker-controlled, this is still a latent correctness bug on
non-standard home directory paths.

**Fix:** Pass the path as an argument instead of embedding it in the code string:

```bash
# shellcheck disable=SC2016
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' \
    "$COUNCIL_DIR/brain.py" 2>/dev/null
```

## Info

### IN-01: Makefile BUG-07 awk line-match is fragile to format changes

**File:** `Makefile:95`
**Issue:** The drift check extracts the commands loop from `update-claude.sh` using:

```makefile
LOOP_LINE=$$(awk '/mkdir -p "\$$CLAUDE_DIR\/commands"/{getline; print; exit}' scripts/update-claude.sh)
```

This works because `mkdir -p "$CLAUDE_DIR/commands"` and the `for file in ...` loop
happen to be on consecutive lines. If someone inserts a blank line or a comment
between the `mkdir -p` and the `for` loop for readability, the awk `getline` would
print the wrong line, the drift check would silently pass or fail incorrectly, and
the CI gate would give false confidence.

**Fix:** Use a more robust awk pattern that searches for the `for file in` line
within the commands block explicitly:

```makefile
LOOP_CMDS=$$(awk '/^for file in.*\.md.*; do$$/{gsub(/for file in |; do$$/,""); print; exit}' scripts/update-claude.sh)
```

---

### IN-02: setup-council.sh "Proceed?" prompt skips installation regardless of answer

**File:** `scripts/setup-council.sh:73-74`
**Issue:** The script prints "tree not installed. To install manually, run:" followed
by the `sudo apt-get install tree` command, then asks "Proceed?" — but it never
executes that command regardless of the answer (BUG-04 intentionally removed the
`sudo` call). The `[y/N]` prompt now has no actionable effect beyond showing one
extra advisory line (covered in WR-01 above as a warning). This info item flags only
the misleading help text that should be updated to reflect the new behavior.

**Fix:** Rewrite the message to be accurate:

```bash
echo -e "  ${YELLOW}⚠${NC} tree not found. Install it manually if you want project structure analysis:"
echo -e "      sudo apt-get install tree"
echo -e "  Supreme Council will work without it — structure analysis will be skipped."
```

No prompt needed since the script is not performing the installation.

---

_Reviewed: 2026-04-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
