# Phase 19: State Cleanup + Idempotency — Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 3 (1 modified, 2 new)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/uninstall.sh` (modified) | utility/main-script | CRUD + file-I/O | `scripts/uninstall.sh` (Phase 18 baseline) | exact — extending same file |
| `scripts/tests/test-uninstall-state-cleanup.sh` | test | file-I/O + event-driven | `scripts/tests/test-uninstall-backup.sh` | exact |
| `scripts/tests/test-uninstall-idempotency.sh` | test | event-driven | `scripts/tests/test-uninstall-dry-run.sh` | exact |

---

## Pattern Assignments

### `scripts/uninstall.sh` (modified — idempotency guard + sentinel strip + state delete + base-plugin invariant)

**Analog:** `scripts/uninstall.sh` Phase 18 baseline (current file on disk)

---

#### Pattern 1 — Idempotency guard (D-07, D-09)

Place IMMEDIATELY after argparse (after line 44, before color constants). No lock, no backup, no tempfile
creation occurs before this block.

**Source:** `scripts/uninstall.sh` lines 296-299 (Phase 18 already has partial guard; Phase 19 moves
it to the correct pre-color position and locks the exact log wording):

```bash
# ───────── UN-06: idempotency guard — BEFORE lock, BEFORE backup, BEFORE any mktemp ─────────
if [[ ! -f "$STATE_FILE" ]]; then
    log_success "Toolkit not installed; nothing to do."
    exit 0
fi
```

**Critical constraints:**
- Must use `log_success` (not `log_info`) — ROADMAP success criterion #3 specifies the `✓` prefix
- Exact wording locked: `Toolkit not installed; nothing to do.`
- The check uses `STATE_FILE` which is set at source time in `lib/state.sh` to
  `$HOME/.claude/toolkit-install.json` and overridden post-source via `TK_UNINSTALL_HOME` seam.
  Therefore this guard must come AFTER the lib-source block (lines 89-99) that sets `STATE_FILE`,
  but BEFORE lock acquisition at line 406. The current Phase 18 placement at line 296 is already
  post-source; Phase 19 confirms the guard stays in that position (it is already correct).

**Note:** Phase 18's guard at lines 296-299 uses `log_success "Toolkit not installed; nothing to do."`
which already matches the required wording. Phase 19 verifies and keeps it unchanged. The guard already
fires before backup (line 409), lock (line 406), and any mktemp beyond the three lib tmps registered
at lines 80-82 (those are cleaned by the EXIT trap regardless).

---

#### Pattern 2 — Base-plugin invariant snapshot + check (D-10, D-11)

**Source for snapshot pattern:** `scripts/tests/test-uninstall-backup.sh` lines 100-104
(pre-run hash capture idiom); `scripts/lib/state.sh` lines 32-53 (`sha256_file`).

**Snapshot at script start** (before lock, before backup — pure read):

```bash
# ───────── UN-05: base-plugin invariant — snapshot BEFORE any mutation ─────────
SP_SNAP_TMP=$(mktemp "${TMPDIR:-/tmp}/sp-snap.XXXXXX")
GSD_SNAP_TMP=$(mktemp "${TMPDIR:-/tmp}/gsd-snap.XXXXXX")
# Register temps with EXIT trap (extend the existing trap registration pattern)
trap 'release_lock 2>/dev/null || true; rm -f "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$SP_SNAP_TMP" "$GSD_SNAP_TMP"' EXIT

SP_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"

# Snapshots: sorted file lists (empty if dir absent — not an error, base plugins may not be installed)
find "$SP_DIR"  -type f 2>/dev/null | sort > "$SP_SNAP_TMP"  || true
find "$GSD_DIR" -type f 2>/dev/null | sort > "$GSD_SNAP_TMP" || true
```

**Check at end of flow** (after file-delete loop, before state delete):

```bash
# ───────── UN-05: base-plugin invariant — verify no mutation occurred ─────────
SP_AFTER_TMP=$(mktemp "${TMPDIR:-/tmp}/sp-after.XXXXXX")
GSD_AFTER_TMP=$(mktemp "${TMPDIR:-/tmp}/gsd-after.XXXXXX")
trap 'release_lock 2>/dev/null || true; rm -f ... "$SP_AFTER_TMP" "$GSD_AFTER_TMP"' EXIT

find "$SP_DIR"  -type f 2>/dev/null | sort > "$SP_AFTER_TMP"  || true
find "$GSD_DIR" -type f 2>/dev/null | sort > "$GSD_AFTER_TMP" || true

if ! diff -q "$SP_SNAP_TMP" "$SP_AFTER_TMP" >/dev/null 2>&1; then
    log_error "BUG: superpowers plugin tree was modified during uninstall — aborting"
    exit 1
fi
if ! diff -q "$GSD_SNAP_TMP" "$GSD_AFTER_TMP" >/dev/null 2>&1; then
    log_error "BUG: get-shit-done plugin tree was modified during uninstall — aborting"
    exit 1
fi
```

**Analog for diff-q idiom:** `scripts/tests/test-uninstall-backup.sh` lines 186-197 (SHA pre/post
comparison). The invariant check uses `diff -q` (file-list comparison) rather than SHA because the
unit of integrity is the set of files, not individual content.

**TK_UNINSTALL_HOME redirect:** When `TK_UNINSTALL_HOME` is set, SP_DIR and GSD_DIR must be
redirected to `$TK_UNINSTALL_HOME/.claude/plugins/...` and `$TK_UNINSTALL_HOME/.claude/get-shit-done/`
respectively (parallel to the CLAUDE_DIR / STATE_FILE / LOCK_DIR override block at lines 121-129).

---

#### Pattern 3 — Sentinel block strip (D-01, D-02, D-03)

**No direct analog in codebase** for the exact `<!-- TOOLKIT-START --> … <!-- TOOLKIT-END -->` strip.
Closest analogs for awk block-deletion:

- `scripts/tests/test-template-propagation.sh` line 177: single-sentinel line deletion via awk:

  ```bash
  awk '!/<!-- v42-splice: council-handoff -->/' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
  ```

- `scripts/propagate-audit-pipeline-v42.sh` lines 102-116: awk start/end block detection pattern
  (finds block boundaries by NR and section headings — the logic structure to adapt for TOOLKIT-START/END).

**Implementation per D-02 (pure bash + awk, no python on this path):**

```bash
# strip_sentinel_block <file>
# Strips all <!-- TOOLKIT-START --> ... <!-- TOOLKIT-END --> pairs from <file>
# plus exactly ONE leading/trailing blank line around each pair (D-02).
# Unmatched markers → log warning, leave file untouched (D-02 graceful abort).
# Empty result → leave empty file on disk, do NOT delete (D-03).
strip_sentinel_block() {
    local file="$1"
    [[ -f "$file" ]] || return 0   # absent — nothing to strip

    # Count markers to detect unmatched pairs (D-02 guard)
    local starts ends
    starts=$(grep -cF '<!-- TOOLKIT-START -->' "$file" || true)
    ends=$(grep -cF '<!-- TOOLKIT-END -->' "$file" || true)

    if [[ "$starts" -ne "$ends" ]]; then
        log_warning "Unmatched TOOLKIT-START/END markers in $file (starts=$starts, ends=$ends) — skipping sentinel strip"
        return 0
    fi
    if [[ "$starts" -eq 0 ]]; then
        return 0   # no sentinels — no-op (D-01: strip only if present)
    fi

    # awk strip: for each START/END pair, remove the pair and surrounding blank lines.
    # Uses a temp file + atomic mv (same pattern as propagate-audit-pipeline-v42.sh).
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/sentinel-strip.XXXXXX")
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN

    awk '
        /<!-- TOOLKIT-START -->/ { in_block=1; skip_prev_blank=1; next }
        /<!-- TOOLKIT-END -->/   { in_block=0; skip_next_blank=1; next }
        in_block                 { next }
        skip_prev_blank && /^[[:space:]]*$/ { skip_prev_blank=0; next }
        skip_next_blank && /^[[:space:]]*$/ { skip_next_blank=0; next }
        { skip_prev_blank=0; skip_next_blank=0; print }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}
```

**Invocation position in uninstall.sh:** After backup (UN-04 has a copy), before state delete (D-06 order):

```bash
# ───────── UN-05: strip toolkit sentinel block from ~/.claude/CLAUDE.md ─────────
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    GLOBAL_CLAUDE_MD="$TK_UNINSTALL_HOME/.claude/CLAUDE.md"
fi
strip_sentinel_block "$GLOBAL_CLAUDE_MD"
```

**Temp file pattern:** Same `mktemp … RETURN trap` idiom as `prompt_modified_for_uninstall`
(lines 233-235 of uninstall.sh — the only other function that uses a RETURN-scoped trap).

---

#### Pattern 4 — State file deletion (D-04, D-06)

**Analog:** `scripts/lib/state.sh` `write_state` uses `os.replace(tmp_path, state_path)` (atomic write).
The deletion is simpler — plain `rm -f` with a warning on failure:

```bash
# ───────── UN-05: delete toolkit-install.json (LAST step, D-06) ─────────
if rm -f "$STATE_FILE"; then
    log_success "State file removed: $STATE_FILE"
else
    log_warning "Failed to remove $STATE_FILE — uninstall is complete but state file is orphaned. Remove manually: rm '$STATE_FILE'"
    # Do NOT exit 1: all files are already removed (D-06 warning-and-continue)
fi
```

**Position:** After sentinel strip, after base-plugin invariant check, as the absolute last statement
before `exit 0`. Matches D-06 order: backup → strip → file-delete → state-delete.

---

### `scripts/tests/test-uninstall-state-cleanup.sh` (new test)

**Analog:** `scripts/tests/test-uninstall-backup.sh` (exact match — same sandbox pattern, same seams)

**Sandbox + seam pattern** (lines 76-133 of test-uninstall-backup.sh):

```bash
SANDBOX="$(mktemp -d /tmp/uninstall-state.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude/commands"
# ... fixture files ...

cat > "$SANDBOX/.claude/toolkit-install.json" <<EOF
{ ... }
EOF
```

**Invocation pattern** (lines 131-132 of test-uninstall-backup.sh):

```bash
OUTPUT=""
RC=0
OUTPUT=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

**Assertion pattern** (lines 33-62 of test-uninstall-backup.sh):

```bash
assert_pass() { PASS=$((PASS+1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL+1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq()   { [ "$1" = "$2" ] && assert_pass "$3" || assert_fail "$3" "expected='$1' actual='$2'"; }
```

**Assertions specific to Phase 19 state cleanup test:**

- State file deleted after successful run: `[ ! -f "$SANDBOX/.claude/toolkit-install.json" ]`
- Sentinel block stripped from CLAUDE.md when present:
  `! grep -qF '<!-- TOOLKIT-START -->' "$SANDBOX/.claude/CLAUDE.md"`
- No-strip no-op when no sentinels: CLAUDE.md content byte-identical before/after
- Base-plugin invariant: SP and GSD dirs (synthetic) byte-identical pre/post via SHA comparison
  (modeled on test-uninstall-backup.sh A7, lines 186-197)
- Backup still created (regression guard for UN-04): A2 from test-uninstall-backup.sh pattern

**Sentinel fixture setup:**

```bash
# Create synthetic ~/.claude/CLAUDE.md with sentinel block in sandbox
mkdir -p "$SANDBOX/.claude"
cat > "$SANDBOX/.claude/CLAUDE.md" <<'EOF'
# My Project CLAUDE.md

User content above.

<!-- TOOLKIT-START -->
## Toolkit Section
Some toolkit content.
<!-- TOOLKIT-END -->

User content below.
EOF
```

---

### `scripts/tests/test-uninstall-idempotency.sh` (new test)

**Analog:** `scripts/tests/test-uninstall-dry-run.sh` (exact match — zero-mutation assertion pattern)

**Core idempotency test structure** (modeled on dry-run test lines 66-175):

```bash
SANDBOX="$(mktemp -d /tmp/uninstall-idempotency.XXXXXX)"
MARKER_FILE="/tmp/uninstall-idempotency-marker.$$"
touch "$MARKER_FILE"
trap 'rm -f "$MARKER_FILE"; rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

# No toolkit-install.json — simulate post-uninstall state
mkdir -p "$SANDBOX/.claude"
# (do NOT create toolkit-install.json)

OUTPUT=""
RC=0
OUTPUT=$(bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

**Key assertions for idempotency test:**

- Exits 0: `assert_eq "0" "$RC" "no-op exits 0"`
- Correct message: `assert_contains 'Toolkit not installed; nothing to do' "$OUTPUT" "no-op message"`
- No backup created: `find "$SANDBOX" -maxdepth 2 -name '.claude-backup-pre-uninstall-*' | wc -l` equals 0
- Zero new files: `find "$SANDBOX" -newer "$MARKER_FILE" -type f | wc -l` equals 0
- Log prefix is `✓` (green success): `assert_contains '✓ Toolkit not installed' "$OUTPUT" "✓ prefix"`

**No-op backup assertion** (ROADMAP success criterion #3 — exact phrasing from CONTEXT.md):

```bash
BACKUP_COUNT="$(find "$SANDBOX" -maxdepth 2 \
    \( -name '.claude-backup-*' -o -name '.claude-backup-pre-uninstall-*' \) \
    -type d 2>/dev/null | wc -l | tr -d '[:space:]')"
assert_eq "0" "$BACKUP_COUNT" "no .claude-backup-pre-uninstall-* created on no-op"
```

(Mirrors test-uninstall-dry-run.sh lines 160-166.)

---

## Shared Patterns

### EXIT Trap Registration (apply to all modifications to `scripts/uninstall.sh`)

**Source:** `scripts/uninstall.sh` lines 86 (Phase 18 baseline) and `scripts/migrate-to-complement.sh`

Every new `mktemp` call in Phase 19 (snapshot tmps, sentinel-strip tmp) must be registered in the
EXIT trap at line 86. The trap is declared before lib sourcing so it fires on any SIGINT. Pattern:

```bash
trap 'release_lock 2>/dev/null || true; rm -f "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$SP_SNAP_TMP" "$GSD_SNAP_TMP"' EXIT
```

Phase 19 extends the existing trap string — do not add a second `trap ... EXIT` (that overwrites the
first). Consolidate all cleanup into a single trap declaration at the mktemp block (lines 80-86).

### MAIN-block `local`-free / bash 3.2-safe arrays (apply to all additions in MAIN block)

**Source:** `scripts/uninstall.sh` lines 429-462, comments at lines 436-441 and 462

Every loop and variable declared at the top-level (MAIN) block of `uninstall.sh` — including new
Phase 19 code — must follow two invariants:

1. NO `local` keyword (only inside function bodies like `strip_sentinel_block` and
   `prompt_modified_for_uninstall`). `local` at top level triggers shellcheck SC2168.

2. Array iterations use the length-guard pattern:
   ```bash
   if [[ ${#ARRAY[@]} -gt 0 ]]; then
       for item in "${ARRAY[@]}"; do : ; done
   fi
   ```

### Color + NO_COLOR gating (apply to all new log calls)

**Source:** `scripts/uninstall.sh` lines 52-66 and 104-118

All output uses `log_info`, `log_success`, `log_warning`, `log_error` helpers defined at lines 71-74.
Never raw `echo -e "\033[..."` in new code — always go through the helpers.

### TK_UNINSTALL_HOME seam (apply to all new path references to `~/.claude/`)

**Source:** `scripts/uninstall.sh` lines 121-129

Any new reference to a `$HOME/.claude/...` path must respect the sandbox override:

```bash
# Example: redirect base-plugin snapshot dirs to sandbox in tests
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    SP_DIR="$TK_UNINSTALL_HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
    GSD_DIR="$TK_UNINSTALL_HOME/.claude/get-shit-done"
fi
```

### Test sha256 cross-platform helper (apply to all new test files)

**Source:** `scripts/tests/test-uninstall-dry-run.sh` lines 54-61

```bash
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
```

### Test summary footer (apply to all new test files)

**Source:** `scripts/tests/test-uninstall-dry-run.sh` lines 181-189

```bash
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-NAME: all N assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-NAME: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output:"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
```

---

## No Analog Found

No files are fully without analog. All patterns have close matches. The sentinel-strip awk logic
(Pattern 3) is the only net-new pattern — it adapts the `awk '!/.../' file > tmp && mv tmp file`
idiom from `scripts/tests/test-template-propagation.sh` line 177 and the start/end block detection
from `scripts/propagate-audit-pipeline-v42.sh` lines 102-116.

| Pattern | Closest Analog | Gap |
|---|---|---|
| Sentinel strip (`<!-- TOOLKIT-START --> … <!-- TOOLKIT-END -->`) | `test-template-propagation.sh:177` (single-sentinel awk deletion) + `propagate-audit-pipeline-v42.sh:102-116` (start/end block detection) | No existing script strips a START/END pair with blank-line trimming; Phase 19 is first consumer |

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/lib/`, `scripts/tests/`, `.planning/phases/18-*/`
**Files read:** 10 (uninstall.sh, lib/state.sh, lib/backup.sh, lib/dry-run-output.sh,
test-uninstall-dry-run.sh, test-uninstall-backup.sh, test-uninstall-prompt.sh,
propagate-audit-pipeline-v42.sh, test-template-propagation.sh, 18-VERIFICATION.md)
**Pattern extraction date:** 2026-04-26
