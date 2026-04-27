# Phase 21: SP/GSD Bootstrap Installer - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 8 (2 created, 6 modified)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/lib/bootstrap.sh` | shared-lib | request-response (TTY prompt → shell exec) | `scripts/lib/backup.sh` | exact (same lib invariants) |
| `scripts/tests/test-bootstrap.sh` | test | batch | `scripts/tests/test-uninstall.sh` + `scripts/tests/test-uninstall-prompt.sh` | exact (same seam pattern) |
| `scripts/lib/optional-plugins.sh` | shared-lib | transform (add constants) | self (top-of-file guard block) | exact (same color-guard idiom) |
| `scripts/init-claude.sh` | entry-point | request-response | self (existing argparse + lib-source block lines 24–92) | exact |
| `scripts/init-local.sh` | entry-point | request-response | self (existing argparse + lib-source block lines 81–122) | exact |
| `Makefile` | config | batch | self (Test 27 block lines 141–143) | exact |
| `.github/workflows/quality.yml` | config | batch | self (Tests 21-27 step lines 109–117) | exact |
| `docs/INSTALL.md` | docs | — | self (existing flags table) | exact |

---

## Pattern Assignments

### `scripts/lib/bootstrap.sh` (shared-lib, TTY prompt → shell exec)

**Analog:** `scripts/lib/backup.sh`

**Header + color-guard pattern** (backup.sh lines 1–21):

```bash
#!/bin/bash

# Claude Code Toolkit — <description>
# Source this file. Do NOT execute it directly.
# Exposes: <functions>
# Globals: none — reads $HOME at call time
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m'
```

**Note:** `backup.sh` uses bare assignments (no guards) because it is always sourced first.
`optional-plugins.sh` shows the guarded form used when color vars may already be set. For
`bootstrap.sh`, use the guarded form from `optional-plugins.sh` lines 9–14 (see below) because
it is sourced AFTER `detect.sh`, `lib/install.sh`, and `lib/optional-plugins.sh` which all
define `RED/YELLOW/NC` unconditionally.

**Color-guard pattern to use** (optional-plugins.sh lines 9–14):

```bash
# Color constants with guards: do NOT redefine if caller already set them.
[[ -z "${CYAN:-}" ]]   && CYAN='\033[0;36m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[0;33m'
[[ -z "${RED:-}" ]]    && RED='\033[0;31m'
[[ -z "${BLUE:-}" ]]   && BLUE='\033[0;34m'
[[ -z "${NC:-}" ]]     && NC='\033[0m'
```

**TTY fail-closed prompt pattern** (uninstall.sh lines 263–298):

```bash
# TTY source. Default /dev/tty; test seam swaps to a file path.
local tty_target="/dev/tty"
[[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && tty_target="/dev/stdin"

while :; do
    local choice=""
    if ! read -r -p "File $rel modified locally. Remove? [y/N/d]: " choice < "$tty_target" 2>/dev/null; then
        choice="N"   # fail-closed: tty source unreachable
    fi
    case "${choice:-N}" in
        y|Y)
            ...
            return 0
            ;;
        *)
            ...
            return 0
            ;;
    esac
done
```

**Adapted for bootstrap** — single prompt, no loop, file-path seam (not stdin):

```bash
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

local choice=""
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    log_info "bootstrap skipped — no TTY"
    return 0
fi
case "${choice:-N}" in
    y|Y)
        local rc=0
        eval "$cmd" || rc=$?
        if [[ $rc -ne 0 ]]; then
            log_warning "${plugin_name} install failed (exit code ${rc}) — continuing toolkit install"
        fi
        ;;
    *)
        : # N / default — silently skip
        ;;
esac
```

**`log_info` / `log_warning` helpers** (lib/install.sh — search for these function names;
they are defined there and `bootstrap.sh` relies on the caller having sourced `lib/install.sh`):

```bash
# lib/install.sh defines log_info / log_warning / log_error / log_success.
# bootstrap.sh must call these rather than raw echo for output consistency.
# All diagnostics from lib functions go to stderr (>&2).
```

**`eval` + non-fatal exit capture** (from RESEARCH.md Pattern 3 — D-10 enforcement):

```bash
local rc=0
eval "$cmd" || rc=$?
if [[ $rc -ne 0 ]]; then
    log_warning "${plugin_name} install failed (exit code ${rc}) — continuing toolkit install"
fi
```

Add above each `eval` invocation:

```bash
# shellcheck disable=SC2294  # eval is intentional — test seam overrides production constant
```

---

### `scripts/lib/optional-plugins.sh` (shared-lib, constant extraction)

**Analog:** self (existing color-guard block at lines 9–14)

**Current inline strings to extract** (lines 30–34, verbatim):

```bash
echo -e "  ${YELLOW}superpowers${NC} (obra) — skills + code-reviewer agent (TK complements)"
echo -e "    Install: ${YELLOW}claude plugin install superpowers@claude-plugins-official${NC}"
echo ""
echo -e "  ${YELLOW}get-shit-done${NC} (gsd-build) — phase-based workflow (TK complements)"
echo -e "    Install: ${YELLOW}bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)${NC}"
```

**Constant declarations to INSERT at top of file** (after line 14, before `recommend_optional_plugins()`):

```bash
# Canonical install commands — single source of truth (D-12).
# Guards allow test seam or caller override before sourcing.
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'
```

**Exact strings extracted** so `recommend_optional_plugins()` can reference `$TK_SP_INSTALL_CMD`
and `$TK_GSD_INSTALL_CMD` instead of literal strings. This is a mechanical substitution —
the print lines change from literal to `${TK_SP_INSTALL_CMD}` / `${TK_GSD_INSTALL_CMD}`.

---

### `scripts/init-claude.sh` (entry-point, lib-source + argparse modification)

**Analog:** self — existing lib-source block (lines 63–92) and argparse (lines 24–51)

**Argparse block** (lines 24–51) — add new case branch. Current pattern:

```bash
while [[ $# -gt 0 ]]; do
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
        laravel|nextjs|nodejs|python|go|rails|base)
            FRAMEWORK="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            ...
            exit 1
            ;;
    esac
done
```

**INSERT before the `*)` catch-all** (after `--force-mode-change` line):

```bash
        --no-bootstrap)
            NO_BOOTSTRAP=true
            shift
            ;;
```

**Also add default after the while-loop** (after line 56, mirroring `SKIP_COUNCIL` pattern):

```bash
NO_BOOTSTRAP="${NO_BOOTSTRAP:-false}"
```

**Lib-source block** (lines 63–92) — current trap and last source call:

```bash
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install-lib.XXXXXX")
LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output-lib.XXXXXX")
LIB_OPTIONAL_PLUGINS_TMP=$(mktemp "${TMPDIR:-/tmp}/optional-plugins-lib.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_DRO_TMP" "$LIB_OPTIONAL_PLUGINS_TMP"' EXIT
...
# shellcheck source=/dev/null
source "$LIB_OPTIONAL_PLUGINS_TMP"   # ← line 92 — INSERT BELOW HERE
```

**INSERTION SITE** — between line 92 (last source) and line 94 (MANIFEST_TMP mktemp):

```bash
# ─────────────────────────────────────────────────
# Phase 21 — BOOTSTRAP-01..04
# Download and source bootstrap.sh, then call bootstrap_base_plugins()
# BEFORE the first detect.sh run (D-02).
# ─────────────────────────────────────────────────
LIB_BOOTSTRAP_TMP=$(mktemp "${TMPDIR:-/tmp}/bootstrap-lib.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_DRO_TMP" "$LIB_OPTIONAL_PLUGINS_TMP" "$LIB_BOOTSTRAP_TMP"' EXIT
if ! curl -sSLf "$REPO_URL/scripts/lib/bootstrap.sh" -o "$LIB_BOOTSTRAP_TMP"; then
    echo -e "${RED}✗${NC} Failed to download lib/bootstrap.sh — aborting"
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_BOOTSTRAP_TMP"

if [[ "${NO_BOOTSTRAP:-false}" != "true" && "${TK_NO_BOOTSTRAP:-}" != "1" ]]; then
    bootstrap_base_plugins
    # Re-source detect.sh to refresh HAS_SP / HAS_GSD after bootstrap (D-14).
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
fi
```

**Note on trap:** Each new `mktemp` in `init-claude.sh` requires the `trap` line to be
re-registered to include the new variable (lines 67 and 98 both do this — same pattern for
`$LIB_BOOTSTRAP_TMP`). The second `trap` on line 98 already re-registers with `$MANIFEST_TMP`
added; update THAT trap (not just line 67) to also carry `$LIB_BOOTSTRAP_TMP`.

---

### `scripts/init-local.sh` (entry-point, argparse + lib-source modification)

**Analog:** self — but asymmetric from `init-claude.sh` (libs sourced BEFORE argparse)

**KEY DIFFERENCE from init-claude.sh:**
- `init-claude.sh`: argparse (lines 24–51) → lib-source (lines 63–92) → bootstrap call
- `init-local.sh`: lib-source (lines 31–38) → argparse (lines 81–122) → bootstrap call

In `init-local.sh`, `source "$SCRIPT_DIR/lib/bootstrap.sh"` goes in the **existing lib-source block** (lines 31–38), but `bootstrap_base_plugins()` is called AFTER argparse ends at line 122.

**Lib-source block addition** (after line 38, current last source):

```bash
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/install.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/dry-run-output.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/state.sh"
# ADD:
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/bootstrap.sh"
```

**Argparse addition** — insert `--no-bootstrap` case in the `while [[ $# -gt 0 ]]` block
(lines 81–122), same position as `init-claude.sh`:

```bash
        --no-bootstrap)
            NO_BOOTSTRAP=true
            shift
            ;;
```

**`--help` block addition** (lines 98–111) — insert after `--force-mode-change` help line:

```bash
echo "  --no-bootstrap        Skip the SP/GSD install prompts (also: TK_NO_BOOTSTRAP=1)"
```

**Bootstrap call site** — after argparse ends (line 122) and after MODE validation (line 134),
BEFORE the re-run delegation check (line 137):

```bash
# Phase 21 — BOOTSTRAP-01..04: call after argparse (D-02), before re-run delegation.
NO_BOOTSTRAP="${NO_BOOTSTRAP:-false}"
if [[ "${NO_BOOTSTRAP:-false}" != "true" && "${TK_NO_BOOTSTRAP:-}" != "1" ]]; then
    bootstrap_base_plugins
    # Re-source detect.sh for fresh HAS_SP / HAS_GSD (D-14).
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/detect.sh"
    # Re-apply color gate after re-source (detect.sh overwrites RED/GREEN/etc unconditionally).
    # Pattern from uninstall.sh lines 109-123.
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
        BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
    fi
fi
```

**Color re-gate pattern** comes from `uninstall.sh` lines 109–123 (shown below for reference):

```bash
# uninstall.sh lines 109-123 — re-apply after lib-source overwrites color vars
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi
```

---

### `scripts/tests/test-bootstrap.sh` (test, hermetic sandbox)

**Analogs:** `scripts/tests/test-uninstall.sh` (S1 scenario structure) and
`scripts/tests/test-uninstall-prompt.sh` (TTY seam + assert helpers)

**File header + assert helpers** (test-uninstall-prompt.sh lines 1–66):

```bash
#!/usr/bin/env bash
# test-bootstrap.sh — BOOTSTRAP-01..04 hermetic integration test.
#
# Five scenario blocks:
#   S1 — prompt y/y for both → mocks invoked, install continues
#   S2 — prompt N/N for both → no mocks invoked
#   S3 — --no-bootstrap → no prompt, no mocks, byte-quiet (D-17)
#   S4 — claude CLI missing → SP prompt suppressed, GSD prompt renders
#   S5 — SP mock exits 1 (failure) → non-fatal, GSD prompt independent
#
# Total assertions: 25 (5 per scenario)
# Usage: bash scripts/tests/test-bootstrap.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
```

**S1 scenario structure** (adapted from test-uninstall.sh lines 73–111):

```bash
run_s1() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- S1: prompt y/y for both → mocks invoked --"

    local MOCK_SP="$SANDBOX/mock-sp.sh"
    printf '#!/bin/bash\necho mock-sp-ran\nexit 0\n' > "$MOCK_SP"
    chmod +x "$MOCK_SP"

    local MOCK_GSD="$SANDBOX/mock-gsd.sh"
    printf '#!/bin/bash\necho mock-gsd-ran\nexit 0\n' > "$MOCK_GSD"
    chmod +x "$MOCK_GSD"

    local ANSWER_FILE="$SANDBOX/answers"
    printf 'y\ny\n' > "$ANSWER_FILE"

    RC=0
    OUTPUT=$(cd "$SANDBOX" && \
        HOME="$SANDBOX" \
        TK_BOOTSTRAP_SP_CMD="$MOCK_SP" \
        TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
        TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
        bash "$REPO_ROOT/scripts/init-local.sh" 2>&1) || RC=$?

    assert_eq "0" "$RC" "S1: init-local exits 0"
    assert_contains "mock-sp-ran"  "$OUTPUT" "S1: SP mock was invoked"
    assert_contains "mock-gsd-ran" "$OUTPUT" "S1: GSD mock was invoked"
    assert_contains "standalone"   "$OUTPUT" "S1: post-bootstrap mode resolves (mocks don't install)"
    # 5th assertion: no 'install failed' warning
    if printf '%s\n' "$OUTPUT" | grep -q "install failed"; then
        assert_fail "S1: no install-failed warning" "found failure warning in output"
    else
        assert_pass "S1: no install-failed warning"
    fi
}
```

**S3 scenario** (byte-quiet --no-bootstrap, from RESEARCH.md):

```bash
run_s3() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    trap "rm -rf '${SANDBOX:?}'" RETURN

    echo "  -- S3: --no-bootstrap byte-quiet (D-17) --"

    RC=0
    OUTPUT=$(cd "$SANDBOX" && HOME="$SANDBOX" \
        bash "$REPO_ROOT/scripts/init-local.sh" --no-bootstrap 2>&1) || RC=$?

    assert_eq "0" "$RC" "S3: exits 0"
    if printf '%s\n' "$OUTPUT" | grep -q "bootstrap"; then
        assert_fail "S3: --no-bootstrap byte-quiet" "found 'bootstrap' in output"
    else
        assert_pass "S3: --no-bootstrap produces no bootstrap output"
    fi
}
```

**Summary/footer block** (test-uninstall.sh lines ~290–300 pattern):

```bash
echo ""
echo "Bootstrap test complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

### `Makefile` (config, new Test 28 block)

**Analog:** self — Test 27 block (lines 141–143)

**Current Test 27 block** (lines 141–143):

```makefile
	@echo "Test 27: uninstall state-cleanup + sentinel strip + base-plugin invariant (UN-05/UN-06)"
	@bash scripts/tests/test-uninstall-state-cleanup.sh
	@echo ""
	@echo "All tests passed!"
```

**Test 28 insertion** — replace the final `All tests passed!` line with:

```makefile
	@echo "Test 27: uninstall state-cleanup + sentinel strip + base-plugin invariant (UN-05/UN-06)"
	@bash scripts/tests/test-uninstall-state-cleanup.sh
	@echo ""
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "All tests passed!"
```

---

### `.github/workflows/quality.yml` (config, CI mirror)

**Analog:** self — Tests 21-27 step (lines 109–117)

**Current step** (lines 109–117):

```yaml
      - name: Tests 21-27 — uninstall + banner suite (UN-01..UN-08)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
```

**Updated step** — rename and append:

```yaml
      - name: Tests 21-28 — uninstall + banner suite + bootstrap (UN-01..UN-08, BOOTSTRAP-01..04)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
```

---

### `docs/INSTALL.md` (docs, flag documentation)

**Analog:** self — existing `--mode` / `--force` / `--dry-run` documentation style

Current install commands in the matrix cells (line 33 example):

```text
`bash <(curl -sSL .../scripts/init-claude.sh)`
```

**Add a Flags section** before or after the Mode Overview. Pattern from the INSTALL.md
style (plain markdown table, no code fence for flag names):

```markdown
## Installer Flags

| Flag | Applies To | Effect |
|------|-----------|--------|
| `--dry-run` | `init-claude.sh`, `init-local.sh` | Show what would be installed without writing files |
| `--mode <name>` | `init-claude.sh`, `init-local.sh` | Override auto-detected install mode |
| `--force` | `init-claude.sh`, `init-local.sh` | Re-install even if state file exists |
| `--force-mode-change` | `init-claude.sh`, `init-local.sh` | Bypass mode-change confirmation prompt |
| `--no-bootstrap` | `init-claude.sh`, `init-local.sh` | Skip SP/GSD install prompts (env: `TK_NO_BOOTSTRAP=1`) |
| `--no-council` | `init-claude.sh` | Skip Supreme Council setup |
```

---

## Shared Patterns

### No `set -euo pipefail` in Shared Libs

**Source:** `scripts/lib/backup.sh` line 13, `scripts/lib/optional-plugins.sh` line 7
**Apply to:** `scripts/lib/bootstrap.sh`

```bash
# IMPORTANT: No set -euo pipefail — sourced libraries must not alter caller error mode.
```

### Color Guard (guarded form for libs sourced after callers define colors)

**Source:** `scripts/lib/optional-plugins.sh` lines 9–14
**Apply to:** `scripts/lib/bootstrap.sh` (top of file)

```bash
[[ -z "${CYAN:-}" ]]   && CYAN='\033[0;36m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[0;33m'
[[ -z "${RED:-}" ]]    && RED='\033[0;31m'
[[ -z "${BLUE:-}" ]]   && BLUE='\033[0;34m'
[[ -z "${NC:-}" ]]     && NC='\033[0m'
```

### TTY Fail-Closed with File-Path Seam

**Source:** `scripts/uninstall.sh` lines 263–270
**Apply to:** `scripts/lib/bootstrap.sh` `_bootstrap_prompt_and_run()` function

```bash
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    log_info "bootstrap skipped — no TTY"
    return 0
fi
```

### Color Re-gate After Re-sourcing detect.sh

**Source:** `scripts/uninstall.sh` lines 109–123
**Apply to:** `scripts/init-local.sh` (after the post-bootstrap `source detect.sh` call)

```bash
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi
```

### Non-Fatal Exit Capture (D-10)

**Source:** RESEARCH.md Pattern 3 (derived from `init-local.sh` line 153 `mc_choice` pattern)
**Apply to:** `_bootstrap_prompt_and_run()` in `bootstrap.sh`

```bash
local rc=0
eval "$cmd" || rc=$?
if [[ $rc -ne 0 ]]; then
    log_warning "${plugin_name} install failed (exit code ${rc}) — continuing toolkit install"
fi
```

### Sandbox + Seam Env Var Test Structure

**Source:** `scripts/tests/test-uninstall.sh` lines 73–111
**Apply to:** Every scenario function in `scripts/tests/test-bootstrap.sh`

```bash
SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
trap "rm -rf '${SANDBOX:?}'" RETURN
# ... setup mocks ...
RC=0
OUTPUT=$(cd "$SANDBOX" && HOME="$SANDBOX" \
    TK_BOOTSTRAP_SP_CMD="$MOCK_SP" \
    TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD" \
    TK_BOOTSTRAP_TTY_SRC="$ANSWER_FILE" \
    bash "$REPO_ROOT/scripts/init-local.sh" 2>&1) || RC=$?
```

---

## No Analog Found

None — all 8 files have close analogs in the codebase.

---

## Metadata

**Analog search scope:** `scripts/lib/`, `scripts/tests/`, `scripts/init-*.sh`,
`scripts/uninstall.sh`, `Makefile`, `.github/workflows/quality.yml`, `docs/INSTALL.md`

**Files scanned:** 13 source files read in full or partial

**Pattern extraction date:** 2026-04-27

**Critical asymmetries documented:**
1. `init-claude.sh` sources libs AFTER argparse → bootstrap call immediately follows `source "$LIB_OPTIONAL_PLUGINS_TMP"` at line 92
2. `init-local.sh` sources libs BEFORE argparse → `source bootstrap.sh` at line ~38, but `bootstrap_base_plugins()` call AFTER argparse at line ~122
3. `init-local.sh` requires color re-gate after `source detect.sh`; `init-claude.sh` does NOT (colors are not gated in `init-claude.sh`)
4. `TK_BOOTSTRAP_TTY_SRC` uses a file path (not stdin) because S1 needs two sequential `y` answers fed from a file
5. `eval "$cmd"` requires `# shellcheck disable=SC2294` comment per line
