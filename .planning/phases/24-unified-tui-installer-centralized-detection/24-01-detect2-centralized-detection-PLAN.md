---
phase: 24
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/detect2.sh
  - scripts/tests/test-install-tui.sh
autonomous: true
requirements:
  - DET-01
  - DET-02
  - DET-03
  - DET-04
  - DET-05
requirements_addressed:
  - DET-01
  - DET-02
  - DET-03
  - DET-04
  - DET-05
tags: bash,detection,lib,phase-24

must_haves:
  truths:
    - "detect2.sh sources detect.sh once at top — no duplicate SP/GSD detection logic"
    - "is_security_installed returns 0 when cc-safety-net is on PATH AND wired in pre-bash.sh OR settings.json (fixes v4.4 brew-install miss)"
    - "is_statusline_installed returns 0 when ~/.claude/statusline.sh exists AND grep '\"statusLine\"' on settings.json succeeds"
    - "is_rtk_installed returns 0 when command -v rtk resolves on PATH"
    - "is_toolkit_installed returns 0 when ~/.claude/toolkit-install.json exists"
    - "Sourcing detect2.sh under set -e does NOT abort the caller (|| true guards every export)"
  artifacts:
    - path: "scripts/lib/detect2.sh"
      provides: "Centralized is_<name>_installed detection wrapper"
      contains: "is_superpowers_installed is_gsd_installed is_toolkit_installed is_security_installed is_rtk_installed is_statusline_installed"
    - path: "scripts/tests/test-install-tui.sh"
      provides: "Hermetic detection-suite assertions (Wave 0 scaffold extended in Plan 04)"
      contains: "S1_detect S2_detect"
  key_links:
    - from: "scripts/lib/detect2.sh"
      to: "scripts/detect.sh"
      via: "source $(dirname $BASH_SOURCE)/../detect.sh"
      pattern: "source.*detect\\.sh"
    - from: "scripts/lib/detect2.sh"
      to: "$HOME/.claude/hooks/pre-bash.sh"
      via: "grep -q cc-safety-net"
      pattern: "grep.*cc-safety-net"
    - from: "scripts/lib/detect2.sh"
      to: "$HOME/.claude/settings.json"
      via: "grep -q '\"statusLine\"'"
      pattern: "grep.*statusLine"
---

<objective>
Create `scripts/lib/detect2.sh` — the centralized "is component installed" detection wrapper that sources `scripts/detect.sh` and adds six new probes (`is_superpowers_installed`, `is_gsd_installed`, `is_toolkit_installed`, `is_security_installed`, `is_rtk_installed`, `is_statusline_installed`). Each probe returns 0 (installed) or 1 (not installed) — no third state.

Also seed `scripts/tests/test-install-tui.sh` with the hermetic detection scenarios (S1_detect probes against a clean sandbox HOME; S2_detect probes against a populated sandbox HOME). The test file is extended by Plan 04; this plan delivers the detect-only assertions so the file exists for downstream waves.

Purpose: Phase 24's TUI, dispatcher, and install.sh all depend on these probes (D-21..D-23). Plan 02 (`lib/tui.sh`) and Plan 03 (`lib/dispatch.sh`) cannot proceed without them, so this plan runs in Wave 1 alongside Plan 02 (no file conflicts; `tui.sh` does NOT source `detect2.sh`).

Output: `scripts/lib/detect2.sh` (new sourced lib, no errexit) + initial detection assertions in `scripts/tests/test-install-tui.sh`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-CONTEXT.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-VALIDATION.md
@scripts/detect.sh
@scripts/lib/bootstrap.sh
@scripts/setup-security.sh
@scripts/install-statusline.sh

<canonical_refs>
- 24-PATTERNS.md §"`scripts/lib/detect2.sh` (new sourced lib, detection wrapper)" — exact lib header pattern, source-safe include, function shapes (lines 153-222 of PATTERNS.md)
- 24-RESEARCH.md §5 "Detection v2 Probes" — verified probe code per component (RESEARCH.md lines 387-499)
- 24-RESEARCH.md §10 "Risk Register" Risk 6 — `detect.sh` is source-safe under set -e (|| true guard at detect.sh:125)
- scripts/detect.sh:32-50, 109-121 — detection function shape (return 0/1, export HAS_* with || true)
- scripts/detect.sh:125-126 — `detect_superpowers || true` + `detect_gsd` source-time invocation pattern to mirror
- scripts/lib/bootstrap.sh:1-19 — sourced-lib header (no errexit, color guards)
</canonical_refs>

<interfaces>
<!-- Key contracts the executor needs. Extracted from codebase reads. -->
<!-- Executor MUST use these exact function names/signatures — no codebase exploration needed. -->

From scripts/detect.sh (sourced by detect2.sh):
```bash
# Sets HAS_SP=true|false, SP_VERSION, exports HAS_SP SP_VERSION
detect_superpowers
# Sets HAS_GSD=true|false, GSD_VERSION, exports HAS_GSD GSD_VERSION
detect_gsd
# Both called at file bottom (detect.sh:125-126):
detect_superpowers || true
detect_gsd
```

From scripts/lib/bootstrap.sh:1-31 (the lib header pattern to mirror):
```bash
#!/bin/bash

# Claude Code Toolkit — <Name> Library
# Source this file. Do NOT execute it directly.
# Exposes: <function names>
# Globals (read): <env vars>
# Globals (write): <none or list>
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
[[ -z "${NC:-}"     ]] && NC='\033[0m'
```

From scripts/tests/test-bootstrap.sh:21-62 (assertion helpers + mk_mock — copy verbatim):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RED='\033[0;31m' ; GREEN='\033[0;32m' ; NC='\033[0m'
PASS=0 ; FAIL=0
assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq() { local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
mk_mock() { local path="$1" message="$2" exit_code="${3:-0}"
    printf '#!/bin/bash\necho %q\nexit %s\n' "$message" "$exit_code" > "$path"
    chmod +x "$path"
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create scripts/lib/detect2.sh — centralized is_*_installed wrapper (DET-01..DET-05)</name>
  <files>scripts/lib/detect2.sh</files>

  <read_first>
    - scripts/detect.sh (lines 1-127) — analog file; the existing SP/GSD detection lib that detect2.sh sources
    - scripts/lib/bootstrap.sh (lines 1-99) — pattern reference for sourced-lib header, color guards, no-errexit comment
    - scripts/setup-security.sh (lines 192-232) — confirm cc-safety-net hook write site that DET-02 grep targets
    - scripts/install-statusline.sh (lines 1-60) — confirm `statusLine` JSON key that DET-03 grep targets
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-RESEARCH.md §5 "Detection v2 Probes" (lines 387-499) — verified probe code per component
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/lib/detect2.sh" (lines 153-222) — exact patterns to copy
  </read_first>

  <behavior>
    - is_superpowers_installed exits 0 when HAS_SP="true", exits 1 otherwise
    - is_gsd_installed exits 0 when HAS_GSD="true", exits 1 otherwise
    - is_toolkit_installed exits 0 when [[ -f "$HOME/.claude/toolkit-install.json" ]], exits 1 otherwise (DET-05)
    - is_security_installed exits 0 when both: command -v cc-safety-net resolves AND grep "cc-safety-net" succeeds in pre-bash.sh OR settings.json (DET-02)
    - is_rtk_installed exits 0 when command -v rtk resolves, exits 1 otherwise (DET-04)
    - is_statusline_installed exits 0 when both: [[ -f "$HOME/.claude/statusline.sh" ]] AND grep '"statusLine"' settings.json succeeds (DET-03)
    - Sourcing detect2.sh from a `set -euo pipefail` parent script does NOT abort the parent (|| true guards on every cache-var export)
  </behavior>

  <action>
Create `scripts/lib/detect2.sh` with this exact content (executor MUST match the function signatures and probe logic byte-for-byte; minor formatting permitted):

```bash
#!/bin/bash

# Claude Code Toolkit — Centralized Detection v2 Library
# Source this file. Do NOT execute it directly.
# Sources detect.sh first (do not duplicate SP/GSD logic — DET-01).
# Exposes:
#   is_superpowers_installed  — wraps HAS_SP from detect.sh (DET-01)
#   is_gsd_installed          — wraps HAS_GSD from detect.sh (DET-01)
#   is_toolkit_installed      — DET-05: ~/.claude/toolkit-install.json exists
#   is_security_installed     — DET-02: cc-safety-net on PATH AND hook wired
#   is_rtk_installed          — DET-04: command -v rtk
#   is_statusline_installed   — DET-03: ~/.claude/statusline.sh + statusLine key
# Globals (write, optional): IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL (cache vars,
# populated only if the caller invokes detect2_cache).
#
# IMPORTANT: No errexit/nounset/pipefail here — sourced files must not alter caller error mode.

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

# Source detect.sh — provides HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION.
# detect.sh ends with `detect_superpowers || true` + `detect_gsd`, so sourcing
# under set -e is safe (Risk 6 from RESEARCH.md §10).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)/../detect.sh"

# DET-01: SP/GSD wrappers — DO NOT re-implement filesystem probes; reuse detect.sh exports.
is_superpowers_installed() {
    [[ "${HAS_SP:-false}" == "true" ]]
}

is_gsd_installed() {
    [[ "${HAS_GSD:-false}" == "true" ]]
}

# DET-05: toolkit install state file (single source of truth, written by init-claude.sh).
is_toolkit_installed() {
    [[ -f "$HOME/.claude/toolkit-install.json" ]]
}

# DET-02: cc-safety-net hook AND wired into pre-bash.sh OR settings.json.
# Fixes v4.4 regression where brew-installed cc-safety-net was missed.
# Returns 0 only when binary exists AND a wiring grep succeeds — incomplete
# install (binary present, hook absent) returns 1.
is_security_installed() {
    if ! command -v cc-safety-net >/dev/null 2>&1; then
        return 1
    fi
    local hooks_file="$HOME/.claude/hooks/pre-bash.sh"
    local settings_file="$HOME/.claude/settings.json"
    if grep -q "cc-safety-net" "$hooks_file" 2>/dev/null; then
        return 0
    fi
    if grep -q "cc-safety-net" "$settings_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# DET-04: PATH-agnostic RTK probe (covers brew /opt/homebrew/bin AND /usr/local/bin).
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}

# DET-03: statusline.sh exists AND statusLine key wired in settings.json.
# Top-level "statusLine" key per install-statusline.sh — NOT ".statusLine.enabled".
is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    grep -q '"statusLine"' "$HOME/.claude/settings.json" 2>/dev/null
}

# Optional helper: cache all six probes into IS_* vars. Callers that need
# the cache pattern (D-23) call this once at startup, then re-probe before
# each dispatch.
detect2_cache() {
    IS_SP=0;  is_superpowers_installed && IS_SP=1  || true
    IS_GSD=0; is_gsd_installed         && IS_GSD=1 || true
    IS_TK=0;  is_toolkit_installed     && IS_TK=1  || true
    IS_SEC=0; is_security_installed    && IS_SEC=1 || true
    IS_RTK=0; is_rtk_installed         && IS_RTK=1 || true
    IS_SL=0;  is_statusline_installed  && IS_SL=1  || true
    export IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL
}
```

Critical rules:

1. NO `set -euo pipefail` anywhere in this file — sourced libs must not alter caller error mode (per CLAUDE.md project convention; verified in scripts/detect.sh:11 and scripts/lib/bootstrap.sh:19).
2. The `source "$(cd ... && pwd)/../detect.sh"` line MUST resolve to `scripts/detect.sh` from the `scripts/lib/` location (validated by Task 2 test).
3. Each `is_*_installed` MUST return 0 (installed) or 1 (not installed) — no third state per D-22.
4. `detect2_cache` is provided for D-23 cache pattern but NOT auto-invoked at source-time (callers decide). This avoids running 6 probes every time the lib is sourced for a single function call.
5. Implements decisions D-21 (sources detect.sh, not duplicating SP/GSD), D-22 (binary 0/1 return), D-23 (cache helper provided).
  </action>

  <verify>
    <automated>bash -c 'set -euo pipefail; source scripts/lib/detect2.sh && for f in is_superpowers_installed is_gsd_installed is_toolkit_installed is_security_installed is_rtk_installed is_statusline_installed detect2_cache; do [[ "$(type -t "$f")" == "function" ]] || { echo "MISSING: $f"; exit 1; }; done; echo "all-six-probes-defined"'</automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/lib/detect2.sh` exists
    - Sourcing it under `set -euo pipefail` exits 0 (no nounset/errexit cascade)
    - All six functions defined as `function` type: `is_superpowers_installed`, `is_gsd_installed`, `is_toolkit_installed`, `is_security_installed`, `is_rtk_installed`, `is_statusline_installed`
    - Helper `detect2_cache` defined as `function` type
    - File contains line `# IMPORTANT: No errexit/nounset/pipefail` (sourced-lib invariant marker per CLAUDE.md)
    - File does NOT contain `set -euo pipefail` (grep returns no match)
    - File contains exact string `command -v cc-safety-net` (DET-02 fix)
    - File contains exact string `grep -q '"statusLine"'` (DET-03 wiring probe)
    - File contains exact string `command -v rtk` (DET-04 PATH probe)
    - File contains exact string `[[ -f "$HOME/.claude/toolkit-install.json" ]]` (DET-05 state file probe)
    - `shellcheck -S warning scripts/lib/detect2.sh` exits 0
  </acceptance_criteria>

  <done>
    All acceptance criteria pass. Lib sourceable from any test or script. No errexit cascade.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Seed scripts/tests/test-install-tui.sh with detection scenarios S1_detect + S2_detect</name>
  <files>scripts/tests/test-install-tui.sh</files>

  <read_first>
    - scripts/tests/test-bootstrap.sh (lines 1-100) — analog file; copy assertion helpers, mk_mock, sandbox pattern verbatim
    - scripts/lib/detect2.sh (just created in Task 1) — the lib under test
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-PATTERNS.md §"scripts/tests/test-install-tui.sh (new hermetic test, ≥15 assertions)" (lines 384-516) — exact assertion helpers + mock builder + sandbox pattern
    - .planning/phases/24-unified-tui-installer-centralized-detection/24-VALIDATION.md "Per-Task Verification Map" rows for DET-01..DET-05 — what each detection assertion must prove
  </read_first>

  <behavior>
    - test-install-tui.sh exits 0 when all detection scenarios pass; exits 1 on any failure
    - S1_detect (clean HOME): all six is_*_installed probes return 1 (not installed) → cache vars all 0
    - S2_detect (populated HOME): each component's positive probe condition is satisfied via sandbox file creation; the corresponding probe returns 0
    - File contains assertion-counter pattern (PASS=0; FAIL=0) and prints final "test-install-tui complete: PASS=N FAIL=M"
    - Hermetic: each scenario uses isolated `mktemp -d` sandbox; HOME is overridden via env; no real `~/.claude` is touched
  </behavior>

  <action>
Create `scripts/tests/test-install-tui.sh` with the test scaffold + two detection scenarios. The file is extended in Plan 04 with TUI keystroke + dispatch scenarios (≥15 total assertions). This task delivers ONLY the detect-only scenarios (~10 assertions).

```bash
#!/usr/bin/env bash
# test-install-tui.sh — Phase 24 hermetic integration test.
#
# Scenarios (extended in Plan 04 to ≥15 total assertions):
#   S1_detect — clean HOME → all six is_*_installed return 1 (not installed)
#   S2_detect — populated HOME → each positive probe condition satisfied → 0
#   [Wave 3 / Plan 04 will add: S3_tui_keys, S4_yes_mode, S5_dry_run,
#    S6_force, S7_no_tty_fallback, S8_ctrlc_restore, S9_dispatch_order, etc.]
#
# Test seam env vars: TK_TUI_TTY_SRC (Plan 02), TK_DISPATCH_OVERRIDE_<NAME> (Plan 04)
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

# Helper: build a mock script in $1 that prints $2 then exits with code $3.
mk_mock() {
    local path="$1" message="$2" exit_code="${3:-0}"
    printf '#!/bin/bash\necho %q\nexit %s\n' "$message" "$exit_code" > "$path"
    chmod +x "$path"
}

echo "test-install-tui.sh: TUI-01..07, DET-01..05, DISPATCH-01..03 integration suite"
echo ""

# ─────────────────────────────────────────────────
# S1_detect — clean HOME → all six is_*_installed return 1 (not installed)
# DET-01..DET-05 negative path
# ─────────────────────────────────────────────────
run_s1_detect() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_detect: clean HOME → all probes return 1 --"

    # Empty $PATH override directory (no rtk, no cc-safety-net binary)
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    # No ~/.claude at all in the clean sandbox.

    local SP GSD TK SEC RTK SL
    SP=0; GSD=0; TK=0; SEC=0; RTK=0; SL=0
    HOME="$SANDBOX" PATH="$FAKE_BIN:/usr/bin:/bin" \
        bash -c "
            source '$REPO_ROOT/scripts/lib/detect2.sh'
            is_superpowers_installed && echo SP=1 || echo SP=0
            is_gsd_installed         && echo GSD=1 || echo GSD=0
            is_toolkit_installed     && echo TK=1 || echo TK=0
            is_security_installed    && echo SEC=1 || echo SEC=0
            is_rtk_installed         && echo RTK=1 || echo RTK=0
            is_statusline_installed  && echo SL=1 || echo SL=0
        " > "$SANDBOX/probe.out" 2>/dev/null

    SP=$(grep '^SP='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    GSD=$(grep '^GSD=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    TK=$(grep '^TK='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SEC=$(grep '^SEC=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    RTK=$(grep '^RTK=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SL=$(grep '^SL='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)

    assert_eq "0" "$SP"  "S1_detect: SP=0 in clean HOME (DET-01)"
    assert_eq "0" "$GSD" "S1_detect: GSD=0 in clean HOME (DET-01)"
    assert_eq "0" "$TK"  "S1_detect: TK=0 in clean HOME (DET-05)"
    assert_eq "0" "$SEC" "S1_detect: SEC=0 in clean HOME (DET-02)"
    assert_eq "0" "$RTK" "S1_detect: RTK=0 in clean HOME (DET-04)"
    assert_eq "0" "$SL"  "S1_detect: SL=0 in clean HOME (DET-03)"
}

# ─────────────────────────────────────────────────
# S2_detect — populated HOME → each component's positive condition satisfied
# DET-02..DET-05 positive path (DET-01 SP/GSD verified separately by test-detect.sh)
# ─────────────────────────────────────────────────
run_s2_detect() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-tui.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_detect: populated HOME → positive probes return 0 --"

    # DET-05: create toolkit-install.json
    mkdir -p "$SANDBOX/.claude"
    echo '{"version":"4.4.0"}' > "$SANDBOX/.claude/toolkit-install.json"

    # DET-03: create statusline.sh + settings.json with "statusLine" key
    echo '#!/bin/bash' > "$SANDBOX/.claude/statusline.sh"
    chmod +x "$SANDBOX/.claude/statusline.sh"
    printf '%s\n' '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}' \
        > "$SANDBOX/.claude/settings.json"

    # DET-02: mock cc-safety-net binary on PATH + write hook file referencing it
    local FAKE_BIN="$SANDBOX/bin"
    mkdir -p "$FAKE_BIN"
    mk_mock "$FAKE_BIN/cc-safety-net" "fake-cc-safety-net" 0
    mkdir -p "$SANDBOX/.claude/hooks"
    printf '%s\n' '#!/bin/bash' 'cc-safety-net "$@"' > "$SANDBOX/.claude/hooks/pre-bash.sh"

    # DET-04: mock rtk binary on PATH
    mk_mock "$FAKE_BIN/rtk" "fake-rtk" 0

    local TK SEC RTK SL
    TK=0; SEC=0; RTK=0; SL=0
    HOME="$SANDBOX" PATH="$FAKE_BIN:/usr/bin:/bin" \
        bash -c "
            source '$REPO_ROOT/scripts/lib/detect2.sh'
            is_toolkit_installed     && echo TK=1 || echo TK=0
            is_security_installed    && echo SEC=1 || echo SEC=0
            is_rtk_installed         && echo RTK=1 || echo RTK=0
            is_statusline_installed  && echo SL=1 || echo SL=0
        " > "$SANDBOX/probe.out" 2>/dev/null

    TK=$(grep '^TK='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SEC=$(grep '^SEC=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    RTK=$(grep '^RTK=' "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)
    SL=$(grep '^SL='   "$SANDBOX/probe.out" | tail -1 | cut -d= -f2)

    assert_eq "1" "$TK"  "S2_detect: TK=1 with toolkit-install.json (DET-05)"
    assert_eq "1" "$SEC" "S2_detect: SEC=1 with cc-safety-net + pre-bash.sh wired (DET-02)"
    assert_eq "1" "$RTK" "S2_detect: RTK=1 with rtk on PATH (DET-04)"
    assert_eq "1" "$SL"  "S2_detect: SL=1 with statusline.sh + settings.json wired (DET-03)"
}

run_s1_detect
run_s2_detect

echo ""
echo "test-install-tui complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

Critical rules:

1. The test file MUST start with `#!/usr/bin/env bash` and `set -euo pipefail` (top-level test script — NOT a sourced lib).
2. Use `mktemp -d /tmp/test-install-tui.XXXXXX` for sandbox isolation; trap RETURN cleans up per-scenario.
3. Run probes inside `bash -c '...'` subshells so `set -euo pipefail` from the outer test does NOT interfere with the lib's `|| true` guards.
4. Each assertion uses `assert_eq` helper that increments PASS/FAIL counters.
5. The S2_detect scenario REQUIRES a separate sandbox per probe is NOT necessary — one sandbox with all artifacts placed satisfies all four positive probes simultaneously. This keeps assertion count predictable.
6. Test count after this task: 10 assertions (6 in S1_detect + 4 in S2_detect). Plan 04 extends to ≥15 total (TUI-07 contract).
7. SP/GSD positive probe is INTENTIONALLY not tested here — `scripts/tests/test-detect.sh` already exhaustively covers HAS_SP/HAS_GSD population (DET-01 wraps those). Re-testing here would duplicate test-detect.sh.

Implements DET-01 (wrappers), DET-02 (cc-safety-net + hook grep), DET-03 (statusline + settings.json grep), DET-04 (command -v rtk), DET-05 (toolkit-install.json).
  </action>

  <verify>
    <automated>bash scripts/tests/test-install-tui.sh && grep -c '^assert' scripts/tests/test-install-tui.sh | awk '{ if ($1 < 5) { print "TOO_FEW_ASSERTIONS:", $1; exit 1 } else { print "OK assertions=" $1 } }'</automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/tests/test-install-tui.sh` exists
    - File starts with `#!/usr/bin/env bash` and contains `set -euo pipefail`
    - File defines functions `assert_pass`, `assert_fail`, `assert_eq`, `assert_contains`, `assert_not_contains`, `mk_mock` (verbatim from test-bootstrap.sh)
    - File defines `run_s1_detect` and `run_s2_detect` and invokes both
    - `bash scripts/tests/test-install-tui.sh` exits 0
    - Output contains line `test-install-tui complete: PASS=10 FAIL=0` (exactly 10 assertions in this plan; Plan 04 grows this number)
    - `grep -c '^assert' scripts/tests/test-install-tui.sh` returns ≥ 5 (definitions + invocations; 10 actual assert_eq calls inside scenarios — meta-count tolerates definition lines too)
    - `shellcheck -S warning scripts/tests/test-install-tui.sh` exits 0
    - `bash scripts/tests/test-bootstrap.sh` exits 0 (BACKCOMPAT-01 invariant: 26-assertion v4.4 contract still green)
  </acceptance_criteria>

  <done>
    Detection scenarios pass. test-bootstrap.sh stays green. The test scaffold is ready for Plan 04 to extend.
  </done>
</task>

<task type="auto">
  <name>Task 3: Run make check + commit detect2.sh + test scaffold</name>
  <files>scripts/lib/detect2.sh, scripts/tests/test-install-tui.sh</files>

  <read_first>
    - Makefile (lines 36-43) — make check / shellcheck targets to ensure local pass
    - .git/HEAD — confirm we are on the worktree branch (claude/heuristic-bassi-bb2f61)
  </read_first>

  <action>
1. Run `shellcheck -S warning scripts/lib/detect2.sh scripts/tests/test-install-tui.sh` — must exit 0.
2. Run `bash scripts/tests/test-install-tui.sh` — must exit 0 with `PASS=10 FAIL=0`.
3. Run `bash scripts/tests/test-bootstrap.sh` — must exit 0 (BACKCOMPAT-01 invariant; 26 assertions still green).
4. Commit ONLY these two files (do NOT use `git add -A`):
   - `scripts/lib/detect2.sh`
   - `scripts/tests/test-install-tui.sh`

Commit message via heredoc, exactly:

```
feat(24): add lib/detect2.sh centralized is_*_installed wrapper

DET-01..DET-05 implementation. Sources existing scripts/detect.sh once;
adds six is_<name>_installed probes (toolkit, security, rtk, statusline,
plus SP/GSD wrappers around HAS_SP/HAS_GSD). is_security_installed fixes
v4.4 brew-install miss by combining `command -v cc-safety-net` with a
hook-wiring grep across pre-bash.sh OR settings.json. Detection cache
helper `detect2_cache` provided for D-23 mid-run drift recheck pattern.

Test scaffold scripts/tests/test-install-tui.sh seeded with S1_detect
(clean HOME → all six probes return 1) and S2_detect (populated HOME →
positive probes return 0). 10 assertions; Plan 04 extends to ≥15 for
TUI-07. test-bootstrap.sh stays green (BACKCOMPAT-01 invariant).

Refs: 24-CONTEXT.md D-21..D-23, 24-RESEARCH.md §5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Use:
```bash
git add scripts/lib/detect2.sh scripts/tests/test-install-tui.sh
git commit -m "$(cat <<'EOF'
feat(24): add lib/detect2.sh centralized is_*_installed wrapper

DET-01..DET-05 implementation. Sources existing scripts/detect.sh once;
adds six is_<name>_installed probes (toolkit, security, rtk, statusline,
plus SP/GSD wrappers around HAS_SP/HAS_GSD). is_security_installed fixes
v4.4 brew-install miss by combining `command -v cc-safety-net` with a
hook-wiring grep across pre-bash.sh OR settings.json. Detection cache
helper `detect2_cache` provided for D-23 mid-run drift recheck pattern.

Test scaffold scripts/tests/test-install-tui.sh seeded with S1_detect
(clean HOME → all six probes return 1) and S2_detect (populated HOME →
positive probes return 0). 10 assertions; Plan 04 extends to ≥15 for
TUI-07. test-bootstrap.sh stays green (BACKCOMPAT-01 invariant).

Refs: 24-CONTEXT.md D-21..D-23, 24-RESEARCH.md §5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
  </action>

  <verify>
    <automated>shellcheck -S warning scripts/lib/detect2.sh scripts/tests/test-install-tui.sh && bash scripts/tests/test-install-tui.sh && bash scripts/tests/test-bootstrap.sh && git log -1 --pretty=%B | head -1 | grep -q '^feat(24): add lib/detect2.sh'</automated>
  </verify>

  <acceptance_criteria>
    - shellcheck passes on both files (exit 0, no warnings or errors)
    - test-install-tui.sh exits 0 with `PASS=10 FAIL=0`
    - test-bootstrap.sh exits 0 (26 assertions green)
    - Most recent commit subject matches `feat(24): add lib/detect2.sh centralized is_*_installed wrapper`
    - Most recent commit only modifies `scripts/lib/detect2.sh` and `scripts/tests/test-install-tui.sh` (no other files touched — verify with `git show --stat HEAD`)
  </acceptance_criteria>

  <done>
    Plan 01 lands as a single conventional commit. Wave 1 detection lib is ready for downstream plans.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user shell → install.sh | Untrusted env vars (HOME, PATH, NO_COLOR, TERM); detect2.sh reads but does not write to filesystem |
| sourced lib → caller | detect2.sh executed inside any caller's process; must not alter caller error mode |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-24-01 | Tampering | `is_security_installed` grep target paths | mitigate | Both probe paths (`$HOME/.claude/hooks/pre-bash.sh`, `$HOME/.claude/settings.json`) are user-owned; hardcoded — no user-controlled path interpolation |
| T-24-02 | Information disclosure | `is_*_installed` probes | accept | Probes only read existence/grep — no PII, no key material; output is binary 0/1 |
| T-24-04 | Denial of service | grep against arbitrarily large settings.json | accept | grep is bounded by file size; user-controlled file already on user's own filesystem; not a multi-tenant attack surface |
| T-24-05 | Tampering | sourcing detect.sh from a relative path | mitigate | Resolved via `$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)/../detect.sh` — relies on `$BASH_SOURCE[0]` which is bash-internal and not user-controllable through normal exec; same pattern in production scripts/init-claude.sh:121 |
</threat_model>

<verification>
After Task 3 completes:

```bash
# Sourced lib loads without errcascade
bash -c 'set -euo pipefail; source scripts/lib/detect2.sh; echo loaded-clean'

# All six probes defined
bash -c 'source scripts/lib/detect2.sh; for f in is_superpowers_installed is_gsd_installed is_toolkit_installed is_security_installed is_rtk_installed is_statusline_installed; do type -t "$f"; done'

# Hermetic detection test
bash scripts/tests/test-install-tui.sh

# BACKCOMPAT-01 regression: v4.4 26-assertion bootstrap test stays green
bash scripts/tests/test-bootstrap.sh

# Lint
shellcheck -S warning scripts/lib/detect2.sh scripts/tests/test-install-tui.sh
```
</verification>

<success_criteria>
- `scripts/lib/detect2.sh` exists with six `is_*_installed` functions and a `detect2_cache` helper
- All six probes return 0/1 binary state (DET-22)
- `is_security_installed` requires both binary on PATH AND hook wiring grep (DET-02 fix)
- Sourced under `set -euo pipefail` without aborting caller
- `scripts/tests/test-install-tui.sh` exists with detection scenarios; PASS=10 FAIL=0
- `test-bootstrap.sh` 26 assertions remain green (BACKCOMPAT-01)
- shellcheck clean
- Single conventional commit `feat(24): add lib/detect2.sh ...`
</success_criteria>

<output>
After Plan 01 completes, create `.planning/phases/24-unified-tui-installer-centralized-detection/24-01-SUMMARY.md` describing:
- Files created: `scripts/lib/detect2.sh`, `scripts/tests/test-install-tui.sh`
- 10 detection assertions confirmed green
- Functions exported (signatures)
- Decisions implemented: D-21, D-22, D-23
- Requirements addressed: DET-01, DET-02, DET-03, DET-04, DET-05
- Downstream contract: Plans 02 (tui.sh) and 03 (dispatch.sh) source this lib via `lib/detect2.sh`; Plan 04 extends test-install-tui.sh to ≥15 assertions
</output>
