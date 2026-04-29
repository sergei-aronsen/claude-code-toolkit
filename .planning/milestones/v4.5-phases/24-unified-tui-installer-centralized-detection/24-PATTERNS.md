# Phase 24: Unified TUI Installer + Centralized Detection — Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 11 (5 new, 2 modified scripts, 1 new test, 3 config/docs)
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/lib/tui.sh` | lib (sourced) | request-response (TTY read/write) | `scripts/lib/bootstrap.sh` | role-match |
| `scripts/lib/detect2.sh` | lib (sourced) | transform (probe → bool) | `scripts/detect.sh` | exact |
| `scripts/lib/dispatch.sh` | lib (sourced) | request-response (subprocess dispatch) | `scripts/lib/optional-plugins.sh` | role-match |
| `scripts/install.sh` | entry point (executable) | request-response (orchestrate) | `scripts/init-claude.sh` | exact |
| `scripts/tests/test-install-tui.sh` | test | event-driven (fixture injection) | `scripts/tests/test-bootstrap.sh` | exact |
| `scripts/setup-security.sh` | script (modified) | request-response | `scripts/setup-security.sh` | self |
| `scripts/install-statusline.sh` | script (modified) | request-response | `scripts/install-statusline.sh` | self |
| `manifest.json` | config (modified) | N/A | `manifest.json` | self |
| `Makefile` | config (modified) | N/A | `Makefile` | self |
| `.github/workflows/quality.yml` | config (modified) | N/A | `.github/workflows/quality.yml` | self |
| `docs/INSTALL.md` | docs (modified) | N/A | `docs/INSTALL.md` | self |

---

## Pattern Assignments

### `scripts/lib/tui.sh` (new sourced lib, TTY read/write)

**Analog:** `scripts/lib/bootstrap.sh`

**Lib header + color guard pattern** (lines 1-36):

```bash
#!/bin/bash

# Claude Code Toolkit — TUI Checklist Library
# Source this file. Do NOT execute it directly.
# Exposes: tui_init, tui_checklist, tui_render, tui_quit
# Globals (read): TK_TUI_TTY_SRC, NO_COLOR, TERM
# Globals (write): TUI_RESULTS[]
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
# shellcheck disable=SC2034
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
# shellcheck disable=SC2034
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
# shellcheck disable=SC2034
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'
```

**TTY source test seam pattern** (bootstrap.sh lines 42-48):

```bash
# Canonical pattern: per-read redirection, NOT exec < /dev/tty.
# TK_TUI_TTY_SRC mirrors TK_BOOTSTRAP_TTY_SRC exactly (D-33).
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

local choice=""
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    _bootstrap_log_info "bootstrap skipped — no TTY"
    return 0
fi
```

For tui.sh, the seam variable is `TK_TUI_TTY_SRC` and the pattern for every `/dev/tty` access is:

```bash
# Per-read redirection (not exec) — safe under curl|bash.
# Applied to: stty -g, stty -icanon -echo, stty restore, read -rsn1, read -rsn2.
IFS= read -rsn1 k <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
```

**Terminal raw mode + EXIT trap pattern** (from RESEARCH.md §2, confirmed by bootstrap.sh trap structure):

```bash
# CRITICAL: trap registered BEFORE entering raw mode (TUI-03).
# || true on handler prevents compounding if restore itself fails.
_TUI_SAVED_STTY=""

_tui_save_stty() {
    _TUI_SAVED_STTY=$(stty -g <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || echo "")
}

_tui_restore() {
    if [[ -n "$_TUI_SAVED_STTY" ]]; then
        stty "$_TUI_SAVED_STTY" <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
    else
        stty sane <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
    fi
    printf '\e[?25h' >/dev/tty 2>/dev/null || true  # show cursor
    _TUI_SAVED_STTY=""
}

# Register trap BEFORE _tui_enter_raw:
trap '_tui_restore || true' EXIT INT TERM
```

**NO_COLOR gate pattern** (dry-run-output.sh lines 26-38 — exact idiom to copy):

```bash
# From scripts/lib/dry-run-output.sh:26-38 — copy this exact pattern.
# Add TERM=dumb gate per RESEARCH.md §3 recommendation.
_TUI_COLOR=""
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    _TUI_COLOR=1
fi
```

**Bash 3.2 keystroke read pattern** (RESEARCH.md §2 — no `read -N`, no float `-t`):

```bash
# Bash 3.2 compatible two-pass arrow key read.
# read -N (capital) is Bash 4.2+ only — NEVER use it.
# Float read -t (e.g. -t 0.1) is Bash 4.0+ only — integer only in 3.2.
_tui_read_key() {
    local k=""
    IFS= read -rsn1 k <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
    if [[ "$k" == $'\e' ]]; then
        local extra=""
        IFS= read -rsn2 extra <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
        k="${k}${extra}"
    fi
    printf '%s' "$k"
}
```

**Bash 3.2 state array pattern** (RESEARCH.md §2 — no `declare -A`, no `declare -n`):

```bash
# declare -A associative arrays require Bash 4.0+.
# declare -n namerefs require Bash 4.3+.
# Use parallel indexed arrays sharing the same index.
tui_labels=()     # display name per item
tui_groups=()     # group name per item ("Bootstrap" / "Core" / "Optional")
tui_installed=()  # 1=already installed, 0=not installed
tui_checked=()    # 1=selected, 0=unselected
tui_descs=()      # one-line description per item
TUI_RESULTS=()    # output: checked state per item after user confirms
FOCUS_IDX=0
ITEM_COUNT=0
```

---

### `scripts/lib/detect2.sh` (new sourced lib, detection wrapper)

**Analog:** `scripts/detect.sh`

**Lib header pattern** (detect.sh lines 1-11):

```bash
#!/bin/bash

# Claude Code Toolkit — Centralized Detection v2 Library
# Source this file. Do NOT execute it directly.
# Sources detect.sh first (do not duplicate SP/GSD logic — DET-01).
# Exports: IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL (cache vars)
# Adds: is_superpowers_installed is_gsd_installed is_toolkit_installed
#       is_security_installed is_rtk_installed is_statusline_installed
#
# IMPORTANT: No errexit/nounset/pipefail here — sourced files must not alter caller error mode.
```

**Source-safe detect.sh include pattern** (detect.sh lines 123-126):

```bash
# detect.sh calls both functions at source time with || true guard.
# detect2.sh sources detect.sh the same way — re-entrant is safe.
# The || true makes sourcing safe under set -e callers.
detect_superpowers || true
detect_gsd
```

For detect2.sh, the source line is:

```bash
# Source detect.sh — provides HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION.
# Guard: sourcing from detect2.sh is idempotent (detect.sh is re-entrant).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)/../detect.sh" 2>/dev/null || \
    source "$(dirname "${BASH_SOURCE[0]:-}")/../detect.sh"
```

**Detection function shape** (from detect.sh lines 32-50, 109-121):

```bash
# Pattern: return 0 (installed) or 1 (not installed). No third state.
# Always guard exports with || true so set -e callers are safe.

is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}

is_toolkit_installed() {
    [[ -f "$HOME/.claude/toolkit-install.json" ]]
}

is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    grep -q '"statusLine"' "$HOME/.claude/settings.json" 2>/dev/null
}
```

**Detection cache pattern** (D-23, from RESEARCH.md §5):

```bash
# Cache detection results at startup. || true guards set -e callers.
# Re-probe before each dispatch — cheap, catches mid-run drift.
IS_SP=0;  is_superpowers_installed && IS_SP=1  || true
IS_GSD=0; is_gsd_installed         && IS_GSD=1 || true
IS_TK=0;  is_toolkit_installed     && IS_TK=1  || true
IS_SEC=0; is_security_installed    && IS_SEC=1 || true
IS_RTK=0; is_rtk_installed         && IS_RTK=1 || true
IS_SL=0;  is_statusline_installed  && IS_SL=1  || true
```

---

### `scripts/lib/dispatch.sh` (new sourced lib, subprocess dispatcher)

**Analog:** `scripts/lib/optional-plugins.sh`

**Lib header + constant guard pattern** (optional-plugins.sh lines 1-19):

```bash
#!/bin/bash

# Claude Code Toolkit — Per-Component Dispatcher Library
# Source this file. Do NOT execute it directly.
# Exposes: dispatch_superpowers dispatch_gsd dispatch_toolkit
#          dispatch_security dispatch_rtk dispatch_statusline
# Each takes: [--force] [--dry-run] [--yes]. Returns dispatcher exit code.
#
# IMPORTANT: No set -euo pipefail — sourced libraries must not alter caller error mode.

# Reuse canonical install command constants from optional-plugins.sh.
# Guards allow caller / test seam to override before sourcing.
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'
```

**Flag parsing pattern per dispatcher** (from RESEARCH.md §6, modeled on uninstall.sh flag loop lines 26-46):

```bash
# Each dispatcher parses its own flags — same case pattern as every TK script.
dispatch_security() {
    local force=0 dry_run=0 yes=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)   force=1   ;;
            --dry-run) dry_run=1 ;;
            --yes)     yes=1     ;;
        esac
        shift
    done
    # ... invocation ...
}
```

**Curl-pipe vs local dispatch detection** (D-24, RESEARCH.md §4):

```bash
# D-24: BASH_SOURCE[0] detection for curl-pipe vs local invocation.
# curl|bash: BASH_SOURCE[0] is bare "bash" or absent.
# bash <(curl ...): BASH_SOURCE[0] is /dev/fd/N.
# local: BASH_SOURCE[0] is the script path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"

if [[ "${BASH_SOURCE[0]:-}" == /dev/fd/* || "${0:-}" == bash ]]; then
    _TK_IS_CURL_PIPE=1
else
    _TK_IS_CURL_PIPE=0
fi
```

**Idempotency skip pattern** (uninstall.sh ~line 399, idempotency guard shape):

```bash
# Before dispatching: re-probe and skip if already installed (unless --force).
# This is the per-dispatch guard that catches mid-run drift (D-23).
local still_installed=0
is_toolkit_installed && still_installed=1 || true
if [[ $still_installed -eq 1 && "${force:-0}" -ne 1 ]]; then
    return 0  # skipped — caller records status "skipped"
fi
```

---

### `scripts/install.sh` (new top-level orchestrator, executable)

**Analog:** `scripts/init-claude.sh`

**Shebang + errexit + color constants** (init-claude.sh lines 1-16):

```bash
#!/bin/bash

# Claude Code Toolkit — Unified Install Orchestrator (v4.5+)
# Usage: bash <(curl -sSL https://.../scripts/install.sh)
# Flags: --yes --no-color --dry-run --force --fail-fast --no-banner

set -euo pipefail

# Colors (always defined; gated at output time by _TUI_COLOR / NO_COLOR)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
```

**Flag parsing case block** (init-claude.sh lines 25-58):

```bash
# Canonical TK flag parsing pattern — copy and adapt.
# Unknown flags print usage and exit 1 (same as init-claude.sh).
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes)       YES=1;       shift ;;
        --no-color)  NO_COLOR=1;  shift ;;
        --dry-run)   DRY_RUN=1;   shift ;;
        --force)     FORCE=1;     shift ;;
        --fail-fast) FAIL_FAST=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Flags: --yes, --no-color, --dry-run, --force, --fail-fast, --no-banner"
            exit 1
            ;;
    esac
done
```

**CLEANUP_PATHS + trap EXIT pattern** (init-claude.sh lines 88-96):

```bash
# Centralized cleanup — accumulate tmp paths, single trap handles EXIT + INT.
# install.sh uses this for downloaded lib temp files.
CLEANUP_PATHS=()
run_cleanup() {
    [[ ${#CLEANUP_PATHS[@]} -gt 0 ]] && rm -f "${CLEANUP_PATHS[@]}"
}
trap 'run_cleanup' EXIT
```

**Remote lib download + source pattern** (init-claude.sh lines 98-133):

```bash
# Pattern for downloading each new lib (tui.sh, detect2.sh, dispatch.sh):
LIB_TUI_TMP=$(mktemp "${TMPDIR:-/tmp}/tui-lib.XXXXXX");         CLEANUP_PATHS+=("$LIB_TUI_TMP")
LIB_DETECT2_TMP=$(mktemp "${TMPDIR:-/tmp}/detect2-lib.XXXXXX"); CLEANUP_PATHS+=("$LIB_DETECT2_TMP")
LIB_DISPATCH_TMP=$(mktemp "${TMPDIR:-/tmp}/dispatch-lib.XXXXXX"); CLEANUP_PATHS+=("$LIB_DISPATCH_TMP")

if ! curl -sSLf "$REPO_URL/scripts/lib/tui.sh" -o "$LIB_TUI_TMP"; then
    echo -e "${RED}✗${NC} Failed to download lib/tui.sh — aborting"
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_TUI_TMP"
```

**NO_BANNER gate pattern** (init-claude.sh line 22 + CONTEXT.md D-31):

```bash
# Mirrors init-claude.sh NO_BANNER behavior exactly.
NO_BANNER=${NO_BANNER:-0}
# ... at end of script:
if [[ "${NO_BANNER:-0}" != "1" ]]; then
    echo ""
    echo "To remove: bash <(curl -sSL $REPO_URL/scripts/uninstall.sh)"
fi
```

---

### `scripts/tests/test-install-tui.sh` (new hermetic test, ≥15 assertions)

**Analog:** `scripts/tests/test-bootstrap.sh`

**File header + assertion counter pattern** (test-bootstrap.sh lines 1-56):

```bash
#!/usr/bin/env bash
# test-install-tui.sh — TUI-01..07, DET-01..05, DISPATCH-01..03 hermetic integration test.
#
# Scenarios: (list all ≥15 scenario names here)
# Total assertions: ≥15
# Test seam env vars: TK_TUI_TTY_SRC, TK_DISPATCH_OVERRIDE_<name>=:
#
# Usage: bash scripts/tests/test-install-tui.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
```

**Assertion helper functions** (test-bootstrap.sh lines 31-55 — copy verbatim):

```bash
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
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
```

**Mock script builder** (test-bootstrap.sh lines 57-62 — copy verbatim):

```bash
# Helper: build a mock script in $1 that prints $2 then exits with code $3.
mk_mock() {
    local path="$1" message="$2" exit_code="${3:-0}"
    printf '#!/bin/bash\necho %q\nexit %s\n' "$message" "$exit_code" > "$path"
    chmod +x "$path"
}
```

**Sandbox isolation pattern** (test-bootstrap.sh lines 71-74):

```bash
run_sN() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    # ...
}
```

**Fixture file injection patterns** (RESEARCH.md §8, D-33):

```bash
# TUI fixture: raw bytes, NO line separators between keystrokes.
# For printable keys (space, q): single byte.
# For arrow keys: 3-byte escape sequence written with printf '%b'.
# For Enter: $'\n' (the newline IS the enter keypress).

# Fixture: ↑ space enter (navigate up, toggle, confirm)
local TTY_FIXTURE="$SANDBOX/tty-fixture"
printf '%b %b' $'\e[A' $'\n' > "$TTY_FIXTURE"

# Fixture: q-quit
printf 'q' > "$SANDBOX/tty-quit"

# Fixture: Ctrl-C
printf '%b' $'\003' > "$SANDBOX/tty-ctrlc"

# Fixture: --yes mode — no TTY needed (TK_TUI_TTY_SRC unset)
# Inject via: YES=1 TK_TUI_TTY_SRC=/dev/null bash "$REPO_ROOT/scripts/install.sh" ...
```

**Mock dispatcher injection** (D-33, test-bootstrap.sh TK_BOOTSTRAP_SP_CMD pattern):

```bash
# Mock dispatchers via environment — mirrors TK_BOOTSTRAP_SP_CMD pattern.
# TK_DISPATCH_OVERRIDE_<NAME>=: makes the dispatcher a no-op.
# TK_DISPATCH_OVERRIDE_<NAME>="$MOCK_SCRIPT" makes it call a mock.
local MOCK_TOOLKIT="$SANDBOX/mock-toolkit.sh"
mk_mock "$MOCK_TOOLKIT" "mock-toolkit-ran" 0

RC=0
OUTPUT=$(
    HOME="$SANDBOX" \
    TK_TUI_TTY_SRC="$TTY_FIXTURE" \
    TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TOOLKIT" \
    NO_COLOR=1 \
    bash "$REPO_ROOT/scripts/install.sh" 2>&1
) || RC=$?
```

**Final counter + exit** (test-bootstrap.sh lines 334-351 — copy verbatim):

```bash
echo ""
echo "test-install-tui complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

### `scripts/setup-security.sh` (modified — add `--yes` flag)

**Self-analog:** `scripts/setup-security.sh`

**Existing flag parsing block to extend** (setup-security.sh — add `--yes` to the argument loop):

The existing script uses `set -euo pipefail` and downloads `lib/install.sh`. There are currently zero interactive `read` prompts (RESEARCH.md §5, DISPATCH-02 verification). The `--yes` flag is added as an accepted-but-no-op flag for symmetry and future-proofing.

Pattern to insert — add `--yes` case to any existing `while`/`case` arg parser, or add a new one if none exists:

```bash
# Add at top of setup-security.sh, after color constants:
YES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) YES=1 ;;
        # preserve all existing flags as-is
        *) echo -e "${YELLOW}⚠${NC} unknown flag: $1 (ignoring)" ;;
    esac
    shift
done
: "${YES}"  # satisfy shellcheck SC2034 — YES consumed by future read blocks
```

The script's four functional steps (CLAUDE.md write, cc-safety-net install, hook merge, plugin enable) are all non-interactive already — `YES=1` is a no-op on current code.

---

### `scripts/install-statusline.sh` (modified — add `--yes` no-op stub)

**Self-analog:** `scripts/install-statusline.sh`

**Current flag handling:** None — script processes no flags. The addition is minimal:

```bash
# Add after the color constants block (after line 14):
YES=0
for _arg in "$@"; do
    case "$_arg" in
        --yes) YES=1 ;;
        *) echo -e "${YELLOW}⚠${NC} unknown flag: $_arg (ignoring)" ;;
    esac
done
: "${YES}"  # no-op stub — statusline installer is already fully non-interactive
```

---

### `manifest.json` (modified — add 4 entries)

**Self-analog:** `manifest.json` lines 222-241 (existing `files.libs[]`) and lines 217-221 (`files.scripts[]`).

**Exact schema per entry** (manifest.json lines 222-241 — zero-special-casing, `{"path": "..."}` only):

```json
"libs": [
  {"path": "scripts/lib/backup.sh"},
  {"path": "scripts/lib/bootstrap.sh"},
  {"path": "scripts/lib/dry-run-output.sh"},
  {"path": "scripts/lib/install.sh"},
  {"path": "scripts/lib/optional-plugins.sh"},
  {"path": "scripts/lib/state.sh"},
  {"path": "scripts/lib/detect2.sh"},
  {"path": "scripts/lib/dispatch.sh"},
  {"path": "scripts/lib/tui.sh"}
]
```

```json
"scripts": [
  {"path": "scripts/uninstall.sh"},
  {"path": "scripts/install.sh"}
]
```

No extra fields. The auto-discovery jq path in `update-claude.sh:279` is `.files | to_entries[] | .value[] | .path` — these entries are discovered with zero code change.

---

### `Makefile` (modified — add Test 31)

**Self-analog:** `Makefile` lines 148-161.

**Test 30 pattern to copy** (Makefile lines 150-161):

```makefile
@echo ""
@echo "Test 30: --keep-state partial-uninstall recovery (KEEP-01..02)"
@bash scripts/tests/test-uninstall-keep-state.sh
@echo ""
@echo "All tests passed!"

# Test 30 — --keep-state partial-uninstall recovery (KEEP-01..02), invokable standalone
test-uninstall-keep-state:
	@bash scripts/tests/test-uninstall-keep-state.sh
```

New Test 31 follows the same shape:

```makefile
@echo ""
@echo "Test 31: TUI install checklist — TUI-01..07, DET-01..05, DISPATCH-01..03"
@bash scripts/tests/test-install-tui.sh
@echo ""
@echo "All tests passed!"

# Test 31 — TUI install checklist hermetic test, invokable standalone
test-install-tui:
	@bash scripts/tests/test-install-tui.sh
```

Also add `test-install-tui` to the `.PHONY` list on line 1.

---

### `.github/workflows/quality.yml` (modified — add Test 31 to CI step)

**Self-analog:** `.github/workflows/quality.yml` lines 109-120.

**Existing "Tests 21-30" step pattern** (lines 109-120):

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

New step follows the same pattern:

```yaml
- name: Test 31 — TUI install checklist (TUI-01..07, DET-01..05, DISPATCH-01..03)
  run: bash scripts/tests/test-install-tui.sh
```

---

### `docs/INSTALL.md` (modified — add `install.sh` section)

**Self-analog:** `docs/INSTALL.md` lines 29-60.

**Existing flag table pattern** (lines 34-44):

```markdown
| Flag | Applies To | Effect |
|------|-----------|--------|
| `--dry-run` | `init-claude.sh`, `init-local.sh` | Show what would be installed ... |
```

New section follows the same heading style and flag table format:

```markdown
## install.sh (unified entry, v4.5+)

`scripts/install.sh` is the single entry point for the full TUI installer flow
introduced in v4.5.

| Flag | Effect |
|------|--------|
| `--yes` | Skip TUI; install all uninstalled components in canonical order |
| `--yes --force` | Skip TUI; re-run all components regardless of detection |
| `--dry-run` | Show what would run without invoking any installer |
| `--force` | Re-run already-installed components |
| `--fail-fast` | Stop on first component failure (default: continue-on-error) |
| `--no-color` | Disable ANSI output (also honored via `NO_COLOR` env var) |
| `--no-banner` | Suppress the closing removal banner line |
```

---

## Shared Patterns

### Sourced lib contract (no errexit)

**Source:** `scripts/lib/bootstrap.sh` line 19 + `scripts/detect.sh` line 11

**Apply to:** `tui.sh`, `detect2.sh`, `dispatch.sh` (all three new libs)

```bash
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
# This comment MUST appear in the header of every sourced lib.
```

### Color guard idiom

**Source:** `scripts/lib/bootstrap.sh` lines 23-31

**Apply to:** `tui.sh`, `detect2.sh`, `dispatch.sh`

```bash
# Color constants with guards: do NOT redefine if caller already set them.
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
[[ -z "${NC:-}"     ]] && NC='\033[0m'
```

### NO_COLOR + TTY gate (no-color.org contract)

**Source:** `scripts/lib/dry-run-output.sh` lines 26-38

**Apply to:** `tui.sh` (color init), `scripts/install.sh` (summary output), `dro_print_install_status` helper

```bash
# Canonical NO_COLOR test — presence of the var (any value) disables color.
# ${NO_COLOR+x} expands to "x" when set (even empty), "" when unset.
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    # color enabled
else
    # plain text fallback
fi
```

### Per-read `/dev/tty` redirection (not exec)

**Source:** `scripts/lib/bootstrap.sh` lines 43-48

**Apply to:** `tui.sh` (every `read`, every `stty` call)

```bash
# Use per-read < "$tty_target" redirection, NOT exec < /dev/tty.
# exec closes the curl pipe stdin and can hang the parent bash.
# Per-read is isolated and safe under curl|bash.
IFS= read -rsn1 k <"${TK_TUI_TTY_SRC:-/dev/tty}" 2>/dev/null || true
```

### Test seam env var override

**Source:** `scripts/lib/bootstrap.sh` lines 43-44 (`TK_BOOTSTRAP_TTY_SRC`)

**Apply to:** `tui.sh` (`TK_TUI_TTY_SRC`), dispatch functions (`TK_DISPATCH_OVERRIDE_<NAME>`)

```bash
# Pattern: TK_<FEATURE>_<INPUT>_SRC overrides hardcoded path.
# Defaults to canonical path when unset.
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"
```

### Log helpers (`log_info` / `log_warning`)

**Source:** `scripts/uninstall.sh` lines 76-79

**Apply to:** `scripts/install.sh` (orchestrator log output)

```bash
log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
```

Private lib variants use `_<lib>_log_info` prefix (bootstrap.sh pattern lines 35-36):

```bash
# For sourced libs only — underscore prefix avoids name collision.
_tui_log_info()    { echo -e "${BLUE}ℹ${NC} $1" >&2; }
_tui_log_warning() { echo -e "${YELLOW}⚠${NC} $1" >&2; }
```

### `dro_*` post-install summary API

**Source:** `scripts/lib/dry-run-output.sh` (full file)

**Apply to:** `scripts/install.sh` (post-install summary)

New helper to add to `dry-run-output.sh` (D-27):

```bash
# dro_print_install_status <component> <state>
# state values: "installed ✓" | "skipped" | "failed (exit N)"
# Format mirrors dro_print_header column pattern: left-aligned label, right-aligned state.
dro_print_install_status() {
    local component="$1" state="$2"
    case "$state" in
        "installed ✓") printf '%b  %-30s %s%b\n' "${_DRO_G:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        "skipped")     printf '%b  %-30s %s%b\n' "${_DRO_Y:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        failed*)       printf '%b  %-30s %s%b\n' "${_DRO_R:-}" "$component" "$state" "${_DRO_NC:-}" ;;
        *)             printf '  %-30s %s\n' "$component" "$state" ;;
    esac
}
```

### `eval`-based indirect expansion (Bash 3.2, no namerefs)

**Source:** `scripts/lib/dry-run-output.sh` lines 51-53 (`dro_print_header` indirect var read)

**Apply to:** `tui.sh` (any case where caller passes a variable name to read from)

```bash
# Bash 3.2 compatible indirect expansion (declare -n is Bash 4.3+).
# From dry-run-output.sh:51-53:
eval "color_val=\${$color_var:-}"
```

---

## No Analog Found

All files have analogs or are self-modifications. No new file type is architecturally novel relative to the existing codebase.

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/lib/`, `scripts/tests/`, `manifest.json`, `Makefile`, `.github/workflows/`, `docs/`

**Files scanned:** 13 source files read directly

**Pattern extraction date:** 2026-04-29
