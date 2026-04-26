---
phase: 18-core-uninstall-script-dry-run-backup
plan: 01
subsystem: infra
tags: [uninstall, shell, bash, sha256, state-machine, no-color]

requires:
  - phase: 17-dist
    provides: scripts/lib/state.sh (sha256_file, read_state, STATE_FILE), scripts/lib/backup.sh, scripts/lib/dry-run-output.sh
provides:
  - scripts/uninstall.sh foundation: argparse, state load, classify_file, is_protected_path, classification counts
  - is_protected_path() — UN-01 safety invariant: never classifies files outside CLAUDE_DIR or inside base-plugin trees
  - classify_file() — PROTECTED checked before existence check before SHA compare; pure read, zero filesystem mutations
affects: [18-02, 18-03, 18-04]

tech-stack:
  added: []
  patterns:
    - "Re-apply color gate after sourcing libs to counteract state.sh hardcoded RED/YELLOW/NC overrides"
    - "TK_UNINSTALL_LIB_DIR + TK_UNINSTALL_HOME test seams (mirrors TK_MIGRATE_* / TK_UPDATE_* patterns)"
    - "classify_file PROTECTED-first ordering enforces UN-01 invariant before any downstream delete logic"

key-files:
  created:
    - scripts/uninstall.sh
  modified: []

key-decisions:
  - "Re-apply color gate after lib-source loop: lib/state.sh unconditionally overwrites RED/YELLOW/NC with hardcoded ANSI; a second application of the [ -t 1 ] && [ -z \"${NO_COLOR+x}\" ] block after sourcing re-establishes correct empty-string values"
  - "is_protected_path rejects absolute paths not starting with CLAUDE_DIR/ — catches crafted ../.. escapes without needing realpath"
  - "DRY_RUN declared in argparse block with : \"$DRY_RUN\" sentinel to satisfy shellcheck SC2034; plans 18-02/03/04 will consume it"

patterns-established:
  - "Color gate applied TWICE in scripts that source lib/state.sh: once before sourcing (for early log_error calls), once after (to restore gated empty strings)"
  - "classify_file helper order: is_protected_path → file existence → sha256 compare — PROTECTED always wins"

requirements-completed:
  - UN-01

duration: 10min
completed: 2026-04-26
---

# Phase 18 Plan 01: Uninstall Script Foundation Summary

**`scripts/uninstall.sh` skeleton with argparse, state-file load, SHA256 `classify_file` helper, and `is_protected_path` guard — pure read-only diagnostic, zero filesystem mutations, shellcheck-warning clean**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-26T09:16:59Z
- **Completed:** 2026-04-26T09:21:58Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- `scripts/uninstall.sh` (229 lines, mode 0755) created with full argparse: `--dry-run` (stored for 18-02/03/04), `--help` (sed-print usage header), `--no-backup` (hard-rejected with exit 1), unknown flags warned to stderr
- ANSI color gating via `[ -t 1 ] && [ -z "${NO_COLOR+x}" ]` per no-color.org; re-applied after lib-source loop to counteract `lib/state.sh` unconditional color constant overrides — verified zero ANSI bytes with `NO_COLOR=1` and with stdout piped
- `is_protected_path()` — rejects files outside `$CLAUDE_DIR/` and inside `superpowers/` and `get-shit-done/` trees; handles relative paths by resolving to absolute against `$CLAUDE_DIR` before comparison
- `classify_file()` — PROTECTED checked first (before existence check, before SHA compare), then MISSING, then SHA compare → REMOVE or MODIFIED
- MAIN block: banner, idempotent no-op on missing state file, `jq` classification loop, count summary (REMOVE / MODIFIED / MISSING / PROTECTED), exit 0
- `make check` (markdownlint + shellcheck + validate-templates) passes green

## Task Commits

1. **Task 1: Create scripts/uninstall.sh skeleton** - `649ebd9` (feat)

## Files Created/Modified

- `scripts/uninstall.sh` — Full foundation: argparse, color gate, lib-source loop, is_protected_path, classify_file, classification MAIN block (229 lines)

## Decisions Made

- **Color gate applied twice:** `lib/state.sh` hardcodes `RED='\033[0;31m'`, `YELLOW='\033[1;33m'`, `NC='\033[0m'` at lines 12–14, unconditionally overwriting the gated empty strings. Fix: re-apply the full `[ -t 1 ] && [ -z "${NO_COLOR+x}" ]` block immediately after the lib-source loop.
- **`is_protected_path` uses `case` matching not `realpath`:** The `case "$abs" in "$CLAUDE_DIR"/*)` pattern correctly rejects `$CLAUDE_DIR/../etc/passwd` (the literal `..` means the string doesn't match `$CLAUDE_DIR/*`), without needing `realpath` which is not POSIX.
- **`DRY_RUN` sentinel via `: "$DRY_RUN"`:** shellcheck SC2034 fires on variables set but not used in the same file. The `: "..."` no-op idiom (from `migrate-to-complement.sh`'s `VERBOSE` handling) suppresses it while keeping the variable declared in argparse where it belongs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Re-apply color gate after lib-source loop**

- **Found during:** Task 1 smoke testing (NO_COLOR=1 test)
- **Issue:** `lib/state.sh` unconditionally sets `RED`, `YELLOW`, `NC` to hardcoded ANSI escape strings at source time, overwriting the empty strings set by the color gate block. Output under `NO_COLOR=1` still contained `^[[0m` reset sequences.
- **Fix:** Added a second identical `if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then ... fi` block immediately after the lib-source loop, with an explanatory comment.
- **Files modified:** `scripts/uninstall.sh`
- **Verification:** `NO_COLOR=1 ... bash scripts/uninstall.sh 2>&1 | od -c | grep '\\033'` returns empty (zero ANSI bytes). Pipe-only test also confirms zero ANSI bytes.
- **Committed in:** `649ebd9` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug: state.sh color override)
**Impact on plan:** Required for correct NO_COLOR behavior per no-color.org spec. No scope creep. Plan's acceptance criterion `NO_COLOR runtime smoke: ... zero ANSI bytes` passes.

## Issues Encountered

None beyond the color gate override (documented as deviation above).

## Test Invocations Performed

| Scenario | Command | Result |
|----------|---------|--------|
| Empty-state no-op | `TK_UNINSTALL_HOME=$(mktemp -d) bash scripts/uninstall.sh` | exit 0, "Toolkit not installed; nothing to do." |
| Populated-state classification | 3-entry fixture (1 REMOVE, 1 MODIFIED, 1 MISSING) | REMOVE: 1, MODIFIED: 1, MISSING: 1 — 2 files on disk untouched |
| Protected-path guard | get-shit-done path in installed_files[] | PROTECTED: 1 — no deletion |
| NO_COLOR smoke | `NO_COLOR=1 ... bash scripts/uninstall.sh 2>&1 \| od -c \| grep '\\033'` | empty — zero ANSI bytes |
| TTY-pipe smoke | `bash scripts/uninstall.sh 2>&1 \| od -c \| grep '\\033'` | empty — zero ANSI bytes |
| --no-backup rejection | `bash scripts/uninstall.sh --no-backup` | exit 1, stderr: "--no-backup is not allowed" |
| --help | `bash scripts/uninstall.sh --help \| head -1` | exits 0, prints "# Claude Code Toolkit..." |
| shellcheck | `shellcheck -S warning scripts/uninstall.sh` | exit 0 — zero warnings |
| make check | `make check` | All checks passed |

## Hook Surface for Plans 18-02/03/04

Plans 18-02 (dry-run output), 18-03 (backup+delete), and 18-04 (prompts) can extend this file by consuming these exported hooks:

| Symbol | Type | Purpose |
|--------|------|---------|
| `classify_file <path> <sha256>` | function | Returns REMOVE/MODIFIED/MISSING/PROTECTED/KEEP to stdout |
| `is_protected_path <path>` | function | Returns 0 (protected) / 1 (safe); abs or rel |
| `n_remove` / `n_modified` / `n_missing` / `n_protected` / `n_keep` | integer vars | Classification counters (n_keep=0 now; 18-04 populates) |
| `DRY_RUN` | integer (0/1) | Argparse flag; 18-02 gates all output branches on this |
| `CLAUDE_DIR` / `STATE_FILE` / `PROJECT_DIR` | string vars | Path roots for all file operations |
| `STATE_JSON` | string | Validated JSON from read_state(); ready for jq consumption |

## Next Phase Readiness

- 18-02 (dry-run output): `DRY_RUN`, `classify_file`, classification counters, and `dro_*` library (already sourced) are all wired and ready
- 18-03 (backup+delete): `backup.sh` already sourced; `CLAUDE_DIR`, `STATE_JSON`, `n_remove` ready; add backup call before delete loop
- 18-04 (prompts+state-cleanup): `n_modified` counter and per-file path+sha data available via jq re-iteration of `STATE_JSON`

---
*Phase: 18-core-uninstall-script-dry-run-backup*
*Completed: 2026-04-26*
