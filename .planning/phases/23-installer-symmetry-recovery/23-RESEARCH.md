# Phase 23: Installer Symmetry & Recovery — Research

**Researched:** 2026-04-27
**Domain:** POSIX bash install scripts — flag parity + state-file gating
**Confidence:** HIGH (all claims VERIFIED from source code; no net requests needed)

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Inline `NO_BANNER=0` / `--no-banner) NO_BANNER=1` / gate pattern verbatim in both
  init scripts. NO shared lib.
- **D-02:** Banner string byte-identical across all three installers; Phase 23 must NOT alter it.
- **D-03:** Argparse clause mirrors existing flag placement in both init scripts; `--no-banner`
  must appear in the help/error `Flags:` line.
- **D-04:** Env-var injection via shell-standard `NO_BANNER=1 bash init-claude.sh`; no in-script
  env-parse code needed.
- **D-05:** Extend existing `test-install-banner.sh` with 4 new assertions (A4–A7); do NOT
  create a new banner test file.
- **D-06:** `--no-banner` for `uninstall.sh` is out of scope.
- **D-07:** Gate the existing `rm -f "$STATE_FILE"` at uninstall.sh:653 — do NOT reorder the
  LAST-step block.
- **D-08:** `--keep-state) KEEP_STATE=1; shift ;;` added to uninstall.sh argparse; default
  `KEEP_STATE=0`.
- **D-09:** `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` at top; CLI flag overrides to 1.
- **D-10:** `--keep-state` does NOT change backup, snapshot, sentinel-strip, or diff-q
  behaviour.
- **D-11:** Idempotency guard at line 389 does NOT fire after a `--keep-state` run (state file
  still present → script proceeds normally).
- **D-13:** New file `scripts/tests/test-uninstall-keep-state.sh`; mirrors
  `test-uninstall-idempotency.sh` shape.
- **D-14:** Four required assertions: A1 state file exists post-run, A2 second invocation is
  not a no-op, A3 MODIFIED list non-empty on second run, A4 base-plugin invariant passes.
- **D-17:** Add `bash scripts/tests/test-uninstall-keep-state.sh` as Test 30 in Makefile;
  update quality.yml step name `Tests 21-29` → `Tests 21-30`.
- **D-18:** Manifest stays at `4.4.0`. CHANGELOG appends to existing `[4.4.0]` Added section.
- **D-19:** No `manifest.json` file-list changes; `uninstall.sh` stays as its single registered
  entry.

### Claude's Discretion

- Exact log-line phrasing for `log_info "State file preserved..."`.
- Whether A5 (D-15) and S3 (D-16) ship or defer.
- Order of `--keep-state` clause inside the `case` block (alphabetical preferred).
- Whether to update `docs/INSTALL.md`.

### Deferred Ideas (OUT OF SCOPE)

- `--no-banner` for `uninstall.sh`.
- `--keep-state` env-only in production scripts.
- State-file format migration on re-runs.
- Help-block bootstrap for `init-local.sh`.
- `--no-banner` for `setup-security.sh` / `install-statusline.sh`.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BANNER-01 | `init-claude.sh` and `init-local.sh` learn `--no-banner` (and `NO_BANNER=1` env) | Lines 11/24/1009-1010 in `update-claude.sh` verified as canonical reference; banner echoes at init-claude.sh:930 and init-local.sh:475 confirmed |
| KEEP-01 | `uninstall.sh --keep-state` preserves `toolkit-install.json` after run | `rm -f "$STATE_FILE"` confirmed at line 653; argparse case block at lines 23-41 confirmed as insertion site |
| KEEP-02 | Hermetic test `test-uninstall-keep-state.sh` proves four assertions | `test-uninstall-idempotency.sh` shape and all required seams (`TK_UNINSTALL_HOME`, `TK_UNINSTALL_FILE_SRC`, `TK_UNINSTALL_TTY_FROM_STDIN`) confirmed present in live code |

</phase_requirements>

---

## 1. Verified Line References

All CONTEXT.md canonical refs verified against HEAD. Results:

| CONTEXT.md Ref | File | Line Claimed | Actual | Status |
|----------------|------|-------------|--------|--------|
| `update-claude.sh:11` | `scripts/update-claude.sh` | `NO_BANNER=0` | Line 11: `NO_BANNER=0` | VERIFIED |
| `update-claude.sh:24` | `scripts/update-claude.sh` | `--no-banner) NO_BANNER=1` | Line 24: `--no-banner) NO_BANNER=1 ;;` | VERIFIED |
| `update-claude.sh:1009-1010` | `scripts/update-claude.sh` | `if [[ $NO_BANNER -eq 0 ]]; then echo "To remove: …"; fi` | Lines 1009-1010 exact match — two-line block | VERIFIED |
| `init-claude.sh:930` | `scripts/init-claude.sh` | banner echo | Line 930: `echo "To remove: bash <(curl -sSL …)"` | VERIFIED |
| `init-local.sh:475` | `scripts/init-local.sh` | banner echo | Line 475: `echo "To remove: bash <(curl -sSL …)"` — also last line of file | VERIFIED |
| `uninstall.sh:653` | `scripts/uninstall.sh` | `rm -f "$STATE_FILE"` | Line 653: `if rm -f "$STATE_FILE"; then` | VERIFIED |
| `uninstall.sh:649-656` | `scripts/uninstall.sh` | state-delete block | Lines 649-657 contain the full gate block | VERIFIED |
| `uninstall.sh:389` | `scripts/uninstall.sh` | idempotency guard | Line 389: `if [[ ! -f "$STATE_FILE" ]]; then` | VERIFIED |
| `uninstall.sh:125-129` | `scripts/uninstall.sh` | LOCK_DIR/STATE_FILE override | Lines 125-133: full seam block | VERIFIED (range is 125-133, not 125-129) |

**Range correction for D-XX canonical_refs:** CONTEXT.md says "lines 125-129" for the LOCK_DIR/STATE_FILE override seam. The actual seam block runs lines 125-134 (9 lines, not 5). This is cosmetic — the CONTEXT.md note is accurate in intent but the end bound is off by 5 lines. No redesign impact.

All other line references are exact. No drift detected that would require a redesign.

---

## 2. Argparse Insertion Site Analysis

### 2a. `scripts/init-claude.sh` — argparse block (lines 24-56)

```bash
# lines 23-56 (current HEAD)
while [[ $# -gt 0 ]]; do            # line 24
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-council)
            SKIP_COUNCIL=true
            shift
            ;;
        --mode)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}--mode requires a value${NC}"; exit 1
            fi
            MODE="$2"; shift 2 ;;
        --force)             FORCE=true;             shift ;;
        --force-mode-change) FORCE_MODE_CHANGE=true; shift ;;
        --no-bootstrap)
            NO_BOOTSTRAP=true
            shift
            ;;
        laravel|nextjs|nodejs|python|go|rails|base)
            FRAMEWORK="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo -e "Available frameworks: laravel, nextjs, nodejs, python, go, rails, base"
            echo -e "Flags: --dry-run, --no-council, --no-bootstrap, --mode <name>, --force, --force-mode-change"
            exit 1
            ;;
    esac                                # line 55
done                                    # line 56
```

**Insertion point:** After `--no-bootstrap)` clause (line 44), before the `laravel|…` framework clause (line 45). This keeps `--no-banner` near the other boolean flags and before the positional framework argument.

**Help/error string update:** Line 52 currently reads:

```text
Flags: --dry-run, --no-council, --no-bootstrap, --mode <name>, --force, --force-mode-change
```

Append `, --no-banner` to this string.

**Default declaration:** Insert `NO_BANNER=false` (or `NO_BANNER=0` to match `update-claude.sh` exactly) near line 20 alongside `DRY_RUN=false`. The `update-claude.sh` canonical uses integer `0` / `1` and `[[ $NO_BANNER -eq 0 ]]`. To stay byte-identical with D-01, use `NO_BANNER=0` / `NO_BANNER=1` (not `false`/`true`).

### 2b. `scripts/init-local.sh` — argparse block (lines 86-131)

```bash
# lines 85-131 (current HEAD)
while [[ $# -gt 0 ]]; do            # line 86 (actually line 86)
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --mode)
            …
        --force)             FORCE=true;             shift ;;
        --force-mode-change) FORCE_MODE_CHANGE=true; shift ;;
        --no-bootstrap)      # line 99
            NO_BOOTSTRAP=true
            shift
            ;;
        --version|-v)        # line 103
            echo "claude-code-toolkit v$VERSION (local)"
            exit 0
            ;;
        --help|-h)           # line 107
            echo "Usage: …"
            …
            echo "  --no-bootstrap        Skip the SP/GSD install prompts …"
            exit 0
            ;;
        -*)                  # line 123
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            FRAMEWORK="$1"
            shift
            ;;
    esac                     # line 131
done                         # line 132
```

**Insertion point:** After `--no-bootstrap)` clause (lines 99-102), before `--version|-v)` (line 103). Alphabetically `--no-banner` sorts before `--no-bootstrap`, but placing it after is fine and matches the surgical-change discipline (minimal context churn).

**Help block update:** `init-local.sh` HAS a `--help` block (unlike D-06 which says it might not). Add:

```text
echo "  --no-banner           Suppress closing 'To remove: …' banner"
```

after the `--no-bootstrap` help line (line 118).

**Default declaration:** Add `NO_BANNER=0` near line 78-83 alongside `DRY_RUN=false`, `FRAMEWORK=""`, etc.

**Note:** CONTEXT.md D-06 says "If `init-local.sh` lacks a `--help` block today, Phase 23 does NOT add one." At HEAD it already has a `--help` block (lines 107-121). Adding `--no-banner` documentation to the existing block is therefore required for surface parity, not deferred.

### 2c. `scripts/uninstall.sh` — argparse block (lines 22-41)

```bash
# lines 22-41 (current HEAD)
# ───────── flag parsing (before color constants) ─────────
DRY_RUN=0                              # line 23
for arg in "$@"; do                    # line 24
    case "$arg" in
        --dry-run)                     # line 26
            DRY_RUN=1
            ;;
        --help|-h)                     # line 29
            sed -n '3,18p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        --no-backup)                   # line 33
            echo -e "…" >&2
            exit 1
            ;;
        *)                             # line 37
            echo -e "…unknown flag…" >&2
            ;;
    esac                               # line 40
done                                   # line 41
```

**Insertion point:** After `--dry-run)` clause (lines 26-28), before `--help|-h)` (line 29). Alphabetically `--keep-state` sorts between `--help` and `--no-backup`; place it after `--dry-run` (the closest behavioral analog) for readability.

**KEEP_STATE default:** Insert `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` at line 23, immediately after or below `DRY_RUN=0`.

**Usage block update (lines 3-18):** The `--help` output is generated by `sed -n '3,18p'` on the script itself. The Usage comment block currently documents `--dry-run` and `--help`. Add `--keep-state` to that block:

```text
#   bash scripts/uninstall.sh --keep-state  # preserve state for re-run recovery
```

---

## 3. Banner Echo Wrapping Analysis

### `scripts/init-claude.sh` (lines 927-933)

```bash
main                                                                         # line 927
                                                                             # line 928 (blank)
echo ""                                                                      # line 929
echo "To remove: bash <(curl -sSL …/uninstall.sh)"                         # line 930
echo ""                                                                      # line 931
echo "Read .claude/POST_INSTALL.md and show its contents to the user."      # line 932
                                                                             # (EOF line 932)
```

**Wrap target:** Line 930 only. The adjacent blank echoes (929, 931) are cosmetically independent of the banner; they do NOT need to be inside the gate. The recommended wrap:

```bash
if [[ $NO_BANNER -eq 0 ]]; then
    echo "To remove: bash <(curl -sSL …/uninstall.sh)"
fi
```

This leaves `echo ""` at lines 929 and 931 always-emitted, which is consistent with `update-claude.sh:1009` where only the literal string line is gated.

**No adjacent logic disturbed.** `main` at line 927 has already returned; lines 931-932 are independent post-install instructions.

### `scripts/init-local.sh` (lines 469-476)

```bash
echo "3. Restart Claude Code to apply changes"                              # line 470
echo ""                                                                      # line 471
echo -e "${BLUE}Security setup (recommended):${NC}"                         # line 472
echo "  $GUIDES_DIR/scripts/setup-security.sh"                              # line 473
echo ""                                                                      # line 474
echo "To remove: bash <(curl -sSL …/uninstall.sh)"                         # line 475
                                                                             # (EOF — no line 476)
```

**Wrap target:** Line 475 only. This is the very last line of the file. The recommended wrap:

```bash
if [[ $NO_BANNER -eq 0 ]]; then
    echo "To remove: bash <(curl -sSL …/uninstall.sh)"
fi
```

**Important:** Line 475 is the final line — there is no trailing newline or following logic to worry about. Adding the `fi` closes the file cleanly.

---

## 4. Uninstall State-Delete Block Analysis

Lines 649-661 (verified at HEAD):

```bash
# ───────── UN-05: delete toolkit-install.json (LAST step, D-06) ─────────   # 649
# Failure logs warning but exits 0: …                                          # 650-652
if rm -f "$STATE_FILE"; then                                                  # 653
    log_success "State file removed: $STATE_FILE"                             # 654
else                                                                          # 655
    log_warning "Failed to remove $STATE_FILE — …"                           # 656
fi                                                                            # 657
                                                                              # 658 (blank)
echo ""                                                                       # 659
log_success "Uninstall complete. Toolkit removed from ${PROJECT_DIR}/.claude/" # 660
exit 0                                                                        # 661
```

**Single mutating site confirmed:** `rm -f "$STATE_FILE"` at line 653 is the only place the state file is deleted. The `log_success` at line 654 and `log_warning` at line 656 are result-of-deletion messages — they are NOT independent mutations.

**Gate shape (D-07):**

```bash
if [[ $KEEP_STATE -eq 0 ]]; then
    if rm -f "$STATE_FILE"; then
        log_success "State file removed: $STATE_FILE"
    else
        log_warning "Failed to remove $STATE_FILE — uninstall is complete but state file is orphaned. Remove manually: rm '$STATE_FILE'"
    fi
else
    log_info "State file preserved (--keep-state): $STATE_FILE"
fi
```

**Side-effects that remain reachable regardless of branch:**

- Lines 659-660: `echo ""` + `log_success "Uninstall complete."` — always printed; outside the gate. Both remain reachable on the `--keep-state` path.
- Line 661: `exit 0` — always reached. Correct.

**Conclusion:** Gating lines 653-657 inside `if [[ $KEEP_STATE -eq 0 ]]; then … fi` disturbs nothing downstream. The success/complete messages at 659-660 print in both branches.

---

## 5. Test Harness Patterns

### Seams used in `test-uninstall-idempotency.sh` (closest shape analog)

| Seam | How set | Purpose |
|------|---------|---------|
| `TK_UNINSTALL_HOME` | `export TK_UNINSTALL_HOME="$SANDBOX"` | Redirects `CLAUDE_DIR`, `STATE_FILE`, `LOCK_DIR` to sandbox |
| `TK_UNINSTALL_LIB_DIR` | `export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"` | Sources lib files from repo root, not installed path |
| `HOME="$SANDBOX"` | Env prefix on `bash` invocation | Ensures any `$HOME` references resolve to sandbox |

`test-uninstall-idempotency.sh` does NOT need `TK_UNINSTALL_TTY_FROM_STDIN` because the no-op path exits before any prompt is reached.

### Seams used in `test-uninstall.sh` (round-trip — provides stdin injection pattern)

```bash
RC=0
OUTPUT=$(printf 'y\n' | \
    HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

- `printf 'y\n'` piped into stdin.
- `TK_UNINSTALL_TTY_FROM_STDIN=1` tells `prompt_modified_for_uninstall()` to read from `/dev/stdin` instead of `/dev/tty` — this is the CI-safe seam.
- For "answer N to every prompt": `printf 'N\n'` or `printf '\n'` (empty = default N).
- For multiple modified files: `printf 'N\nN\nN\n'` (one per file).

### Pattern for `test-uninstall-keep-state.sh`

The new test mirrors `test-uninstall.sh`'s scenario-function shape:

1. Each scenario is a `run_sN()` function with a local `SANDBOX` and a `trap "rm -rf '${SANDBOX:?}'" RETURN`.
2. Setup: `(cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1)`.
3. Modify a canary file to ensure at least one MODIFIED entry exists on classification.
4. First uninstall: `printf 'N\n' | … TK_UNINSTALL_TTY_FROM_STDIN=1 bash uninstall.sh --keep-state`.
5. Assertion A1: `[ -f "$SANDBOX/.claude/toolkit-install.json" ]`.
6. Second uninstall (no `--keep-state`): `printf 'y\n' | … bash uninstall.sh`.
7. Assertions A2+A3: output contains backup-created message (proves not a no-op) and
   MODIFIED marker.
8. Assertion A4: base-plugin diff-q invariant — verify no SP/GSD files touched
   (these won't exist in a fresh sandbox, so the `diff -q` on empty find output trivially passes;
   this is equivalent to what `test-uninstall.sh` does).

**S3 env-var path (D-16):** Replace `bash uninstall.sh --keep-state` with
`TK_UNINSTALL_KEEP_STATE=1 bash uninstall.sh` — single A1 assertion sufficient.

---

## 6. CI / Makefile Wiring

### Makefile — insertion site for Test 30

Current last test entry (lines 147-150):

```makefile
	@echo "Test 29: smart-update coverage for scripts/lib/*.sh (LIB-01..02)"
	@bash scripts/tests/test-update-libs.sh
	@echo ""
	@echo "All tests passed!"
```

**Insertion:** Before `@echo "All tests passed!"`, add:

```makefile
	@echo "Test 30: --keep-state partial-uninstall recovery (KEEP-01..02)"
	@bash scripts/tests/test-uninstall-keep-state.sh
	@echo ""
```

**PHONY target** — add `test-uninstall-keep-state` to the `.PHONY` line at line 1, and add:

```makefile
test-uninstall-keep-state:
	@bash scripts/tests/test-uninstall-keep-state.sh
```

after the `test-update-libs` target at line 153-154.

### `quality.yml` — step rename + append

Current step at line 109:

```yaml
      - name: Tests 21-29 — uninstall + banner suite + bootstrap + lib coverage (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02)
```

**Updated step:**

```yaml
      - name: Tests 21-30 — uninstall + banner suite + bootstrap + lib coverage (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02, BANNER-01, KEEP-01..02)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
          bash scripts/tests/test-update-libs.sh
          bash scripts/tests/test-uninstall-keep-state.sh
```

---

## 7. Risks and Edge Cases

### R-01: `--keep-state` + missing state file (idempotency guard fires first)

**Scenario:** User runs `uninstall.sh --keep-state` when toolkit is not installed (state file absent).

**Behaviour:** The idempotency guard at line 389 fires first (`if [[ ! -f "$STATE_FILE" ]]; then log_success "Toolkit not installed; nothing to do."; exit 0; fi`). The script never reaches line 653. KEEP_STATE is parsed but has no effect. Exit 0, no state file created.

**This is correct.** There is nothing to preserve. The planner should document this expected no-op in comments but does not need special handling code.

### R-02: `--dry-run` and `--keep-state` combined

**Scenario:** `uninstall.sh --dry-run --keep-state`.

**Behaviour:** `DRY_RUN=1` triggers an early exit after the classification + dry-run preview output (this is the existing UN-02 contract). The script exits before reaching line 653. KEEP_STATE=1 is parsed but the gate at line 653 is never evaluated.

**This is correct.** Dry-run must not mutate anything — including preserving a state file would be a side effect. No special handling needed; the existing DRY_RUN early-exit already handles this.

### R-03: backup creation fails mid-run with `--keep-state` active

**Scenario:** Backup directory creation fails partway through (disk full, permissions). With `set -euo pipefail`, the script exits non-zero before reaching line 653.

**Behaviour at line 653 / KEEP_STATE gate:** Never reached. The trap at line 91 calls `release_lock 2>/dev/null || true` and then cleans up temp files. The state file is NOT deleted (the gate was not reached), so it remains on disk — which is the desired `--keep-state` behaviour, achieved for free by `set -e`.

**Net result:** After a mid-run failure with `--keep-state`, the state file survives regardless. This is a happy coincidence that aligns with user intent. No special code needed, but worth documenting in comments as an invariant.

### R-04: `test-install-banner.sh` — `--no-banner` assertions use source-grep, not execution

**Pattern concern:** The new assertions (A4-A7) use source-grep (`grep -cF`, `grep -q`), same as A1-A3. Source-grep confirms code is present but does NOT confirm it executes correctly. An inverted condition (`if [[ $NO_BANNER -eq 1 ]]`) would pass source-grep.

**Mitigation (within locked D-05 scope):** The assertions should be specific enough to catch common inversions. For A6:

```bash
grep -q 'if \[\[ $NO_BANNER -eq 0 \]\]' "$REPO_ROOT/scripts/init-claude.sh"
```

This pins the comparison direction. The planner should specify this exact grep pattern (not just `NO_BANNER` presence) to reduce false-pass risk.

### R-05: `init-local.sh` has a `--help` block (CONTEXT.md D-06 assumption incorrect)

CONTEXT.md D-06 says "If `init-local.sh` lacks a `--help` block today, Phase 23 does NOT add one." At HEAD, `init-local.sh` already has a full `--help` block at lines 107-121. The `--no-banner` flag must be documented in this block for surface parity. This is not a redesign risk — it means more lines to write, not fewer.

### R-06: `update-claude.sh` argparse uses `for arg in "$@"` (not `while [[ $# -gt 0 ]]`)

`update-claude.sh` uses `for arg in "$@"; do … done` (read-only iteration, no `shift`). Both `init-claude.sh` and `init-local.sh` use `while [[ $# -gt 0 ]]; do … shift … done`. The `--no-banner` clause in the init scripts must use `shift` after setting `NO_BANNER=1`, consistent with the existing clause pattern. Copy from `--no-bootstrap)` shape, not from `update-claude.sh:24`.

**Correct insertion for init scripts:**

```bash
        --no-banner)
            NO_BANNER=1
            shift
            ;;
```

### R-07: CRLF / line-ending hazards in source-grep tests on CI (Linux)

The existing `test-install-banner.sh` already runs on Linux CI (quality.yml `validate-templates` job is `ubuntu-latest`). The repo uses LF line endings. Source-grep with `-F` (fixed string) is not affected by CRLF. No additional risk for the new assertions.

### R-08: `init-local.sh` banner at line 475 is the LAST line of the file

When the `if [[ $NO_BANNER -eq 0 ]]; then … fi` wrapper is added, the file gains 2 lines (from 475 to 477). The file ends with `fi` — no trailing newline concerns beyond standard POSIX. shellcheck will pass if the `fi` is on its own line.

---

## 8. Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (no external test runner) |
| Config file | none |
| Quick run command | `bash scripts/tests/test-install-banner.sh` |
| Full suite command | `make test` (runs all 30 tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BANNER-01 | `init-claude.sh --no-banner` suppresses banner | source-grep (static) | `bash scripts/tests/test-install-banner.sh` | ✅ (extended) |
| BANNER-01 | `init-local.sh --no-banner` suppresses banner | source-grep (static) | `bash scripts/tests/test-install-banner.sh` | ✅ (extended) |
| BANNER-01 | `NO_BANNER=1` env sets flag | source-grep (static, A4 pattern) | `bash scripts/tests/test-install-banner.sh` | ✅ (extended) |
| KEEP-01 | `uninstall.sh --keep-state` leaves state file on disk | integration (real init + uninstall) | `bash scripts/tests/test-uninstall-keep-state.sh` | ❌ Wave 0 |
| KEEP-02 | Second invocation not a no-op; MODIFIED list non-empty | integration | `bash scripts/tests/test-uninstall-keep-state.sh` | ❌ Wave 0 |
| KEEP-02 | Base-plugin diff-q invariant holds | integration | `bash scripts/tests/test-uninstall-keep-state.sh` | ❌ Wave 0 |

### Observable Signals per Requirement

**BANNER-01 signals:**

1. `grep -q '^NO_BANNER=0' scripts/init-claude.sh` — default zero present
2. `grep -q -- '--no-banner) NO_BANNER=1' scripts/init-claude.sh` — argparse clause present
3. `grep -q 'if \[\[ \$NO_BANNER -eq 0 \]\]' scripts/init-claude.sh` — gate present (correct direction)
4. Same three patterns in `scripts/init-local.sh`
5. `grep -cF "$BANNER" scripts/init-claude.sh` equals 1 (banner string count unchanged — D-02)
6. `grep -cF "$BANNER" scripts/init-local.sh` equals 1

**KEEP-01 signals:**

1. After `uninstall.sh --keep-state` run answering N to all prompts: `[ -f "$SANDBOX/.claude/toolkit-install.json" ]` returns 0 (file exists)
2. After a `uninstall.sh` run WITHOUT `--keep-state`: `[ ! -f "$SANDBOX/.claude/toolkit-install.json" ]` returns 0 (file absent)

**KEEP-02 signals:**

1. Second `uninstall.sh` invocation output contains backup-creation marker (e.g. `Created backup directory:`) — proves script did not exit at line 389
2. Second invocation output contains a MODIFIED classification marker (e.g. `MODIFIED`) — proves classification ran on still-present files
3. Second invocation exit code 0 — proves base-plugin diff-q passed (exit 1 otherwise per lines 638-647)

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-install-banner.sh` (milliseconds, no /tmp)
- **Per wave merge:** `bash scripts/tests/test-uninstall-keep-state.sh`
- **Phase gate:** `make test` — all 30 tests green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/test-uninstall-keep-state.sh` — covers KEEP-01 and KEEP-02; mirrors `test-uninstall-idempotency.sh` shape
- [ ] No framework install needed — existing bash + standard GNU/BSD tools sufficient

---

## Sources

### Primary (HIGH confidence, VERIFIED)

- `scripts/update-claude.sh` lines 11, 24, 1009-1010 — canonical `NO_BANNER` pattern (read at HEAD)
- `scripts/init-claude.sh` lines 18-62, 927-933 — argparse block + banner echo (read at HEAD)
- `scripts/init-local.sh` lines 77-132, 469-476 — argparse block + banner echo (read at HEAD)
- `scripts/uninstall.sh` lines 22-41, 125-134, 383-394, 649-661 — argparse, seams, idempotency guard, state-delete block (read at HEAD)
- `scripts/tests/test-install-banner.sh` — full file (read at HEAD)
- `scripts/tests/test-uninstall-idempotency.sh` — full file (read at HEAD)
- `scripts/tests/test-uninstall.sh` lines 1-160 — stdin-injection pattern (read at HEAD)
- `Makefile` lines 1, 144-155 — PHONY list, Test 29 block, test-update-libs target (read at HEAD)
- `.github/workflows/quality.yml` lines 109-119 — `Tests 21-29` step (read at HEAD)
- `CHANGELOG.md` lines 8-29 — `[4.4.0]` Added section (read at HEAD)

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — POSIX bash, no external deps, existing patterns verified
- Architecture: HIGH — all line references confirmed, no drift
- Pitfalls: HIGH — derived directly from source code analysis, not training data

**Research date:** 2026-04-27
**Valid until:** indefinite (source-grounded; only invalidates if scripts are edited before execution)

**Assumptions log:** No ASSUMED claims in this document. All claims are VERIFIED from source code read in this session.
