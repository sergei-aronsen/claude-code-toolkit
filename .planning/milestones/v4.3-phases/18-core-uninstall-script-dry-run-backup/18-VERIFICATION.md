---
phase: 18-core-uninstall-script-dry-run-backup
verified: 2026-04-26T10:15:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Run bash scripts/uninstall.sh in a real project with toolkit installed (not a test sandbox) and verify the interactive [y/N/d] prompt renders correctly on an actual TTY"
    expected: "Prompt reads from /dev/tty, diff renders against remote reference, user input correctly routes to remove/keep"
    why_human: "The test suite uses TK_UNINSTALL_TTY_FROM_STDIN=1 seam to inject stdin; actual /dev/tty behavior under bash <(curl -sSL ...) requires a real terminal session"
  - test: "Run bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh) --dry-run from a project directory to verify lib fetching via curl works end-to-end"
    expected: "Script fetches state.sh, backup.sh, dry-run-output.sh from GitHub, prints 4-group dry-run preview, exits 0"
    why_human: "Tests use TK_UNINSTALL_LIB_DIR to bypass curl — real curl fetch path not exercised by automated tests"
---

# Phase 18: Core Uninstall — Script + Dry-Run + Backup Verification Report

**Phase Goal:** Toolkit users can run a single command to safely remove every toolkit-installed file from their project's `.claude/` while preserving user modifications and base plugins.
**Verified:** 2026-04-26T10:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `bash scripts/uninstall.sh` reads `~/.claude/toolkit-install.json`, computes SHA256 for every file in `installed_files[]`, removes only hash-matched files; files outside `.claude/` and inside superpowers/get-shit-done never deleted | VERIFIED | `is_protected_path()` at line 139 guards superpowers + get-shit-done trees; `classify_file()` at line 172 uses SHA256 compare; test-uninstall-backup.sh A5/A7 pass — REMOVE-clean deleted, PROTECTED untouched |
| 2 | `--dry-run` prints 4-group preview using `dro_*` API, exits 0, zero filesystem changes | VERIFIED | `print_uninstall_dry_run()` at line 314 uses dro_print_header/dro_print_file/dro_print_total; DRY_RUN early exit at line 389; test-uninstall-dry-run.sh all 8 assertions pass |
| 3 | MODIFIED files trigger `[y/N/d]` from `< /dev/tty`, default N=keep, d shows diff and re-prompts, loop re-entrant | VERIFIED | `prompt_modified_for_uninstall()` at line 213; `while :; do` re-entrant loop at line 254; `read < "$tty_target"` with fail-closed `choice="N"` at lines 256-257; test-uninstall-prompt.sh all 10 assertions pass including A7 (non-trivial diff) |
| 4 | Before any delete: full backup via `cp -R` to `~/.claude-backup-pre-uninstall-<unix-ts>/` including toolkit-install.json snapshot | VERIFIED | `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"` at line 410 (before rm at line 450); snapshot copy at line 417; test-uninstall-backup.sh A2/A3/A4 pass |
| 5 | shellcheck -S warning clean; works under `bash <(curl -sSL ...)`; set -euo pipefail; NO_COLOR + `[ -t 1 ]` gates | VERIFIED | `shellcheck -S warning scripts/uninstall.sh` exits 0; `set -euo pipefail` at line 20; color gate at lines 52-66 and 104-118 (re-applied after lib source); NO_COLOR smoke passes; pipe smoke passes |

**Score:** 5/5 truths verified

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | `toolkit-install.json` is deleted after successful uninstall (UN-05 state cleanup) | Phase 19 | Phase 19 goal: "Strip toolkit-owned `~/.claude/CLAUDE.md` sections, delete `toolkit-install.json` after success, double-invocation is a no-op" |
| 2 | Double-invocation is idempotent — second run exits 0 with no-op message (UN-06) | Phase 19 | Phase 19 SC3: "Running `bash scripts/uninstall.sh` a second time detects missing `~/.claude/toolkit-install.json`, prints `✓ Toolkit not installed; nothing to do`, exits 0" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/uninstall.sh` | Uninstall script foundation + dry-run + backup + prompt | VERIFIED | 521 lines, mode 0755, shellcheck clean, all 4 plans integrated |
| `scripts/lib/backup.sh` | `list_backup_dirs` recognizes `.claude-backup-pre-uninstall-<ts>/` pattern | VERIFIED | Case branch at line 39; find glob extended at lines 45-51; `warn_if_too_many_backups` extended at lines 59-63 |
| `scripts/lib/dry-run-output.sh` | `dro_*` API (dro_init_colors, dro_print_header, dro_print_file, dro_print_total) | VERIFIED (pre-existing) | Exists from Phase 11; shellcheck clean; used by print_uninstall_dry_run |
| `scripts/tests/test-uninstall-dry-run.sh` | Hermetic 8-assertion zero-mutation test | VERIFIED | All 8 assertions pass; mode 0755; shellcheck clean |
| `scripts/tests/test-uninstall-backup.sh` | Hermetic 12-assertion backup + delete test | VERIFIED | All 12 assertions pass; mode 0755; shellcheck clean |
| `scripts/tests/test-uninstall-prompt.sh` | Hermetic 10-assertion [y/N/d] prompt test | VERIFIED | All 10 assertions pass; mode 0755; shellcheck clean |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/uninstall.sh` | `~/.claude/toolkit-install.json` | `read_state()` + `jq -r '.installed_files[] \| ...'` | WIRED | Lines 300, 377 |
| `scripts/uninstall.sh` | `scripts/lib/state.sh` | source loop at lines 89-99 | WIRED | `sha256_file`, `read_state`, `acquire_lock`, `release_lock` all sourced |
| `scripts/uninstall.sh` | `scripts/lib/backup.sh` | source loop at lines 89-99 | WIRED | `warn_if_too_many_backups` called at line 421 |
| `scripts/uninstall.sh` | `scripts/lib/dry-run-output.sh` | source loop at lines 89-99 | WIRED | `dro_init_colors`, `dro_print_header`, `dro_print_file`, `dro_print_total` called in `print_uninstall_dry_run()` |
| `scripts/uninstall.sh` | `~/.claude-backup-pre-uninstall-<ts>/` | `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"` | WIRED | Line 410; before any `rm` at line 450 |
| `scripts/uninstall.sh` | `REMOVE_LIST` array | `rm -f` delete loop at lines 433-458 | WIRED | `is_protected_path` defense-in-depth re-check at line 437 |
| `scripts/lib/backup.sh` | `.claude-backup-pre-uninstall-*` | case branch + find glob | WIRED | `list_backup_dirs` at line 39; `warn_if_too_many_backups` at lines 59-63 |
| `scripts/tests/test-uninstall-dry-run.sh` | `scripts/uninstall.sh` | `TK_UNINSTALL_HOME` + `TK_UNINSTALL_LIB_DIR` seam | WIRED | Line 119 |
| `scripts/tests/test-uninstall-backup.sh` | `scripts/uninstall.sh` | `TK_UNINSTALL_HOME` + `HOME` + `TK_UNINSTALL_LIB_DIR` seam | WIRED | Line 132 |
| `scripts/tests/test-uninstall-prompt.sh` | `scripts/uninstall.sh` | `TK_UNINSTALL_TTY_FROM_STDIN=1` + stdin injection | WIRED | Lines 146-152 |

### Data-Flow Trace (Level 4)

Phase 18 produces shell scripts, not React components or data-rendering UI. Data-flow applies to the state-to-classification pipeline:

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `scripts/uninstall.sh` | `installed_files[]` | `jq -r '.installed_files[] \| ...' <<< "$STATE_JSON"` at line 377 | Yes — reads actual state file entries | FLOWING |
| `scripts/uninstall.sh` | `REMOVE_LIST` / `MODIFIED_LIST` | `classify_file()` calling `sha256_file()` on actual disk files | Yes — live SHA256 computed per file | FLOWING |
| `scripts/uninstall.sh` | `BACKUP_DIR` | `date -u +%s` epoch at line 408 | Yes — real timestamp | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 8 dry-run assertions | `bash scripts/tests/test-uninstall-dry-run.sh` | `all 8 assertions passed` | PASS |
| All 12 backup assertions | `bash scripts/tests/test-uninstall-backup.sh` | `all 12 assertions passed` | PASS |
| All 10 prompt assertions | `bash scripts/tests/test-uninstall-prompt.sh` | `all 10 assertions passed` | PASS |
| Empty-state no-op | `TK_UNINSTALL_HOME=$(mktemp -d) TK_UNINSTALL_LIB_DIR=... bash scripts/uninstall.sh` | `Toolkit not installed; nothing to do.`, exit 0 | PASS |
| --no-backup rejected | `bash scripts/uninstall.sh --no-backup` | `--no-backup is not allowed`, exit 1 | PASS |
| --help exits 0 | `bash scripts/uninstall.sh --help` | Prints usage, exit 0 | PASS |
| NO_COLOR smoke | `NO_COLOR=1 ... bash scripts/uninstall.sh \| od -c \| grep '\\\\033' \| wc -l` | 0 ANSI bytes | PASS |
| Pipe smoke | `... bash scripts/uninstall.sh \| od -c \| grep '\\\\033' \| wc -l` | 0 ANSI bytes | PASS |
| shellcheck | `shellcheck -S warning scripts/uninstall.sh` | exit 0 | PASS |
| bash -n syntax | `bash -n scripts/uninstall.sh` | exit 0 | PASS |
| list_backup_dirs 3-pattern | Feed sandbox with all 3 patterns, count output lines | 3 lines (all patterns recognized) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| UN-01 | 18-01, 18-03 | Delete only hash-matched files from project `.claude/`; never touch base-plugin paths | SATISFIED | `classify_file()` + `is_protected_path()` + REMOVE_LIST delete loop; test-uninstall-backup.sh A5/A7 |
| UN-02 | 18-02 | `--dry-run` preview, exits 0, zero filesystem changes | SATISFIED | `print_uninstall_dry_run()` + DRY_RUN early exit; test-uninstall-dry-run.sh all 8 assertions |
| UN-03 | 18-04 | `[y/N/d]` prompt for MODIFIED files, default N, d diff re-prompts, reads /dev/tty | SATISFIED | `prompt_modified_for_uninstall()` + MODIFIED_LIST loop; test-uninstall-prompt.sh all 10 assertions |
| UN-04 | 18-03 | Backup `.claude/` before any delete, `--no-backup` flag does not exist | SATISFIED | `cp -R` backup at line 410; snapshot at line 417; --no-backup rejected at exit 1; test-uninstall-backup.sh A2/A3/A4 |
| UN-05 | (Phase 19) | Delete `toolkit-install.json` after successful uninstall | DEFERRED | Explicitly mapped to Phase 19 in REQUIREMENTS.md traceability table |
| UN-06 | (Phase 19) | Double-invocation idempotent — second run exits 0 with no-op message | DEFERRED | Explicitly mapped to Phase 19 in REQUIREMENTS.md traceability table |
| UN-07 | (Phase 20) | `manifest.json` registration + installer banners | DEFERRED | Explicitly mapped to Phase 20 in REQUIREMENTS.md traceability table |
| UN-08 | (Phase 20) | CI integration test | DEFERRED | Explicitly mapped to Phase 20 in REQUIREMENTS.md traceability table |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/uninstall.sh` | 437 | `is_protected_path "$rel"` called with relative path — double-`.claude` path produced by prepending `$CLAUDE_DIR`, causing base-plugin protection to silently misfire (WR-01 from code review) | Warning | Defense-in-depth secondary check fails for relative paths, but primary guard in `classify_file()` always passes absolute paths so PROTECTED files never reach REMOVE_LIST; no exploitable path exists through normal flow |
| `scripts/uninstall.sh` | 222 | `is_protected_path "$rel"` in `prompt_modified_for_uninstall` has same relative-path bug (WR-02 from code review) | Warning | Same root cause as WR-01; primary guard in `classify_file()` prevents PROTECTED files from reaching MODIFIED_LIST; defect is in unreachable defense layer |
| `scripts/uninstall.sh` | 162 | Comment documents `KEEP` as possible return value from `classify_file()` but function never returns it; `KEEP)` arm at line 375 is dead code (IN-01 from code review) | Info | Documentation inconsistency; stale comment; no behavioral impact |
| `scripts/tests/test-uninstall-dry-run.sh` | 119 | Invocation lacks `HOME="$SANDBOX"` override unlike backup and prompt tests (IN-02 from code review) | Info | Safe for current code since dry-run exits before any `$HOME`-relative code; inconsistency could silently fail if future code adds `$HOME` reads before DRY_RUN exit |

Note: WR-01 and WR-02 are warnings documented by the code reviewer at 2026-04-26T09:53:22Z. They describe a defense-in-depth layer that malfunctions for relative paths, but the primary protection is unaffected. No anti-pattern constitutes a blocker — the PROTECTED invariant is enforced by `classify_file()` before any file reaches REMOVE_LIST or MODIFIED_LIST.

### Human Verification Required

#### 1. Real /dev/tty prompt interaction

**Test:** In a project directory that has a real toolkit install (`~/.claude/toolkit-install.json` present), run `bash scripts/uninstall.sh` (or `bash scripts/uninstall.sh --dry-run` first). Intentionally modify one toolkit file, then run the full uninstall. Observe the `[y/N/d]` prompt.

**Expected:**
- Prompt reads `File <path> modified locally. Remove? [y/N/d]: ` interactively
- `d` shows a diff (or "Reference unavailable" if no network)
- `y` removes the file, `N` or empty keeps it
- Re-prompt works after `d`

**Why human:** The test suite uses `TK_UNINSTALL_TTY_FROM_STDIN=1` seam to bypass `/dev/tty` and inject stdin via pipe. The actual `read -r -p ... < /dev/tty` code path on a real terminal cannot be exercised by automated tests without a PTY harness.

#### 2. End-to-end curl pipe install

**Test:** From a clean project directory, run `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh) --dry-run`.

**Expected:**
- Script fetches `state.sh`, `backup.sh`, `dry-run-output.sh` from GitHub
- Dry-run preview renders with 4-group output (or no-op message if no state file)
- Exits 0

**Why human:** All automated tests use `TK_UNINSTALL_LIB_DIR` to bypass curl and load local lib files. The real curl fetch path (lines 93-95) is not exercised by the test suite. Network-dependent behavior requires human confirmation.

### Gaps Summary

No gaps found. All 5 success criteria are verified by code inspection and automated test results (30 assertions across 3 test scripts, all passing). The 2 warnings from the code review (WR-01, WR-02) describe a secondary defense-in-depth layer that has a relative-path bug but cannot be exploited through normal flow because the primary guard in `classify_file()` classifies PROTECTED paths before any file reaches the delete or prompt lists. These are known issues for follow-up, not blockers.

The 2 human verification items (real TTY interaction, curl pipe mode) cannot be satisfied programmatically and require a real terminal session with a real toolkit install.

---

_Verified: 2026-04-26T10:15:00Z_
_Verifier: Claude (gsd-verifier)_
