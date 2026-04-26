---
phase: 17
plan: "02"
subsystem: distribution/council-installer
tags: [council, installer, setup-council, init-claude, audit-review, idempotent, mtime]
dependency_graph:
  requires: []
  provides: [council-prompt-install-path]
  affects: [scripts/setup-council.sh, scripts/init-claude.sh]
tech_stack:
  added: []
  patterns: [mtime-aware-copy, partial-write-safe-curl, idempotent-installer]
key_files:
  created: []
  modified:
    - scripts/setup-council.sh
    - scripts/init-claude.sh
decisions:
  - "mtime-aware refresh using POSIX [ -nt ] operator (portable macOS BSD + Linux)"
  - "curl failure on audit-review.md is non-fatal (matches README.md pattern — Council still works for validate-plan mode)"
  - "--force escape hatch deferred to future hardening pass (D-04 explicitly out of scope)"
  - "partial-write safety via .tmp file + mv (no partial destination on curl failure)"
metrics:
  duration: "~8 minutes"
  completed: "2026-04-26T00:08:26Z"
  tasks_completed: 3
  files_modified: 2
---

# Phase 17 Plan 02: Council Prompt Install Path Summary

Extends `setup-council.sh` and `init-claude.sh` `setup_council()` to copy
`scripts/council/prompts/audit-review.md` to `~/.claude/council/prompts/audit-review.md`,
idempotent and mtime-aware, closing the missing distribution link for `/audit` Phase 5 Council
dispatch (D-04, T-17-02 mitigation).

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Extend setup-council.sh Step 4 with mtime-aware audit-review prompt install | 977fc95 | scripts/setup-council.sh |
| 2 | Extend init-claude.sh setup_council() with same idempotent + mtime-aware block | 8ccd83b | scripts/init-claude.sh |
| 3 | Fixture test — first-run install, idempotent no-op, mtime-triggered refresh | (no commit — ephemeral) | scratch dir cleaned up |

## What Was Built

Both installer scripts now:

1. `mkdir -p $COUNCIL_DIR/prompts` (or `$council_dir/prompts` lowercase in init-claude.sh)
2. Download `scripts/council/prompts/audit-review.md` to a `.tmp` file via `curl -sSLf` (partial-write-safe)
3. On curl failure: remove `.tmp`, log `⚠ audit-review.md (not critical)`, continue (non-fatal)
4. If destination does not exist: `mv .tmp -> final`, log success
5. If destination exists and `.tmp -nt final` (upstream newer): `mv .tmp -> final`, log `(refreshed)`
6. If destination exists and `.tmp` is same age or older: `rm .tmp`, log `(already current)` — user's copy untouched

## Fixture Test Procedure (re-runnable for regression)

```bash
REPO_ROOT="/path/to/claude-code-toolkit"
SRC="$REPO_ROOT/scripts/council/prompts/audit-review.md"
SCRATCH=$(mktemp -d)
COUNCIL_DIR="$SCRATCH/.claude/council"
mkdir -p "$COUNCIL_DIR/prompts"

# --- Run 1: first install ---
cp "$SRC" "$COUNCIL_DIR/prompts/audit-review.md.tmp"
if [ ! -f "$COUNCIL_DIR/prompts/audit-review.md" ]; then
  mv "$COUNCIL_DIR/prompts/audit-review.md.tmp" "$COUNCIL_DIR/prompts/audit-review.md"
fi
[ -f "$COUNCIL_DIR/prompts/audit-review.md" ] && echo "PASS: file exists"
cmp -s "$COUNCIL_DIR/prompts/audit-review.md" "$SRC" && echo "PASS: byte-identical"

# --- Run 2: idempotent no-op (touch existing to be newer than tmp) ---
cp "$SRC" "$COUNCIL_DIR/prompts/audit-review.md.tmp"
touch "$COUNCIL_DIR/prompts/audit-review.md"          # make existing newer
if [ "$COUNCIL_DIR/prompts/audit-review.md.tmp" -nt "$COUNCIL_DIR/prompts/audit-review.md" ]; then
  mv "$COUNCIL_DIR/prompts/audit-review.md.tmp" "$COUNCIL_DIR/prompts/audit-review.md"
else
  rm -f "$COUNCIL_DIR/prompts/audit-review.md.tmp"
fi
[ ! -f "$COUNCIL_DIR/prompts/audit-review.md.tmp" ] && echo "PASS: no-op, no stale .tmp"

# --- Run 3: mtime refresh (touch tmp to be 1 hour in the future) ---
cp "$SRC" "$COUNCIL_DIR/prompts/audit-review.md.tmp"
touch -t "$(date -v+1H '+%Y%m%d%H%M.%S' 2>/dev/null || date -d '+1 hour' '+%Y%m%d%H%M.%S')" \
  "$COUNCIL_DIR/prompts/audit-review.md.tmp" 2>/dev/null || true
if [ "$COUNCIL_DIR/prompts/audit-review.md.tmp" -nt "$COUNCIL_DIR/prompts/audit-review.md" ]; then
  mv "$COUNCIL_DIR/prompts/audit-review.md.tmp" "$COUNCIL_DIR/prompts/audit-review.md"
  echo "PASS: refreshed"
fi
cmp -s "$COUNCIL_DIR/prompts/audit-review.md" "$SRC" && echo "PASS: byte-identical after refresh"

rm -rf "$SCRATCH"
```

**Observed output during execution:**
- First run: `PASS: file exists at expected path` / `PASS: byte-identical to source`
- Second run: `PASS no-op (already current)` / `PASS: byte-identical after second run` / `PASS: no stale .tmp file`
- Third run: `PASS refreshed (tmp was newer — mtime gate triggered)` / `PASS: byte-identical after refresh run` / `PASS: no stale .tmp after refresh run`

## Deviations from Plan

None — plan executed exactly as written. The `file://` URL approach for curl override was
considered but the standalone fixture with `cp` (explicitly allowed as simpler alternative
in Task 3) was used instead. All fixture assertions passed.

## Verification Results

| Check | Result |
|-------|--------|
| `shellcheck -S warning scripts/setup-council.sh` | PASS (exits 0) |
| `shellcheck -S warning scripts/init-claude.sh` | PASS (exits 0) |
| `make shellcheck` | PASS (exits 0) |
| `grep council/prompts/audit-review.md scripts/setup-council.sh` | PASS (present) |
| `grep council/prompts/audit-review.md` inside `setup_council()` | PASS (present) |
| `mkdir -p "$COUNCIL_DIR/prompts"` in setup-council.sh | PASS |
| `mkdir -p "$council_dir/prompts"` inside setup_council() | PASS |
| `-nt` mtime check in both scripts | PASS |
| Fixture: first-run install, byte-identical match | PASS |
| Fixture: second-run no-op, no stale .tmp | PASS |
| Fixture: mtime-triggered refresh | PASS |
| T-17-02 mitigation: mtime gate + partial-write-safe curl | IMPLEMENTED |

## Self-Check: PASSED

- `scripts/setup-council.sh` — modified, shellcheck clean, tokens verified
- `scripts/init-claude.sh` — modified, shellcheck clean, tokens inside setup_council() verified
- Commits 977fc95 and 8ccd83b exist in git log
