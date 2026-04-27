# Phase 21: SP/GSD Bootstrap Installer - Research

**Researched:** 2026-04-27
**Domain:** Bash shared library, interactive prompt, TTY/piped-stdin, test seam env vars
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- D-01: Bootstrap logic in `scripts/lib/bootstrap.sh`, single entry point `bootstrap_base_plugins()`
- D-02: Fires BEFORE `detect.sh` in both installers; after CLI flag parsing and lib sourcing
- D-03: NOT wired into `update-claude.sh`, `migrate-to-complement.sh`, `uninstall.sh`
- D-04: Two sequential `[y/N]` prompts; SP first, GSD second
- D-05: Default N; pressing Enter skips
- D-06: Reads `< /dev/tty`; if TTY unavailable → behave as N + single info line; fail-closed
- D-07: Prompt text: `Install superpowers via plugin marketplace? [y/N]` / `Install get-shit-done via curl install script? [y/N]`
- D-08: Idempotency — check filesystem before each prompt; suppress if already installed
- D-09: Missing `claude` CLI → suppress SP prompt with warn; GSD prompt is independent
- D-10: Upstream failure is non-fatal; log warning, continue
- D-11: Installer output streams verbatim — no capture, no redirection
- D-12: Canonical commands extracted as constants in `optional-plugins.sh`; bootstrap reads from there
- D-13: No new fields in `toolkit-install.json` for v4.4
- D-14: After bootstrap, `detect.sh` is re-sourced, mode recomputed via `lib/install.sh`
- D-15: No `bootstrap_run` flag in state
- D-16: `--no-bootstrap` flag + `TK_NO_BOOTSTRAP=1` skip entirely; CLI flag wins over env
- D-17: Skipping is byte-quiet (no log line)
- D-18: `--no-bootstrap` documented in `--help` output of both installers and `docs/INSTALL.md`
- D-19: Test seam — `TK_BOOTSTRAP_SP_CMD` and `TK_BOOTSTRAP_GSD_CMD` override real commands
- D-20: Hermetic test `scripts/tests/test-bootstrap.sh` — 5 scenarios (S1..S5)
- D-21: Test 28 added to Makefile + quality.yml
- D-22: `bootstrap.sh` NOT registered in `manifest.json` — Phase 22 owns that
- D-23: Manifest version stays `4.3.0`; version bump to `4.4.0` in Phase 23

### Claude's Discretion

- Exact log-line wording (researcher/planner choose consistent with `log_warning`/`log_info` from `lib/install.sh`)
- One entry point vs split SP/GSD helpers — based on testability
- GSD invoked via `bash <(curl …)` directly or via temp-file wrapper

### Deferred Ideas (OUT OF SCOPE)

- Selective plugin presets (`--bootstrap=sp`, `--bootstrap=gsd`, `--bootstrap=both`)
- Bootstrap during `update-claude.sh`
- Auto-install rtk/caveman
- Dependency-aware install order (e.g., installing `claude` itself)

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOTSTRAP-01 | Prompts via `< /dev/tty`, fail-closed N if no TTY, default N, before detect.sh | Verified in insertion site analysis; fail-closed pattern from uninstall.sh confirmed |
| BOOTSTRAP-02 | On y: run canonical commands verbatim; non-fatal on failure | Confirmed canonical strings in optional-plugins.sh:31,34; streaming pattern verified |
| BOOTSTRAP-03 | After bootstrap, re-source detect.sh and recompute mode | detect.sh analysis: re-sourcing is clean — sets HAS_SP/HAS_GSD atomically |
| BOOTSTRAP-04 | --no-bootstrap + TK_NO_BOOTSTRAP=1 skip; documented; hermetic test 5 scenarios | Precedent from TK_UNINSTALL_HOME/TK_UNINSTALL_FILE_SRC pattern fully verified |

</phase_requirements>

---

## Summary

Phase 21 adds `scripts/lib/bootstrap.sh` — a sourced library that fires one interactive
"do you want to install SP and/or GSD?" step before `detect.sh` runs in both installers.
The research confirms all 23 locked decisions are internally consistent with existing code.
The four focus areas below each resolve to a concrete implementation shape.

**Primary recommendation:** Implement `bootstrap_base_plugins()` as a single function in
`bootstrap.sh` with the same structural invariants as `backup.sh` (no `set -euo pipefail`,
color guards, `< /dev/tty` fail-closed). Extract the two canonical command strings as
`readonly`-style guarded constants in `optional-plugins.sh`, then source them from `bootstrap.sh`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Bootstrap prompt UX | CLI / shell entry-point | Shared lib | Prompt reads stdin; must happen in a running terminal context |
| Canonical install command constants | `scripts/lib/optional-plugins.sh` | — | Single source of truth; D-12 invariant |
| Plugin installation (SP) | `claude` CLI (upstream) | — | Not ours to own; invoke only |
| Plugin installation (GSD) | curl + bash pipe (upstream) | — | Same — invoke only |
| Re-detection after bootstrap | `scripts/detect.sh` | `scripts/lib/install.sh` | Re-source produces clean HAS_SP/HAS_GSD state |
| Test seam override | `TK_BOOTSTRAP_SP_CMD` / `TK_BOOTSTRAP_GSD_CMD` env vars | bootstrap.sh | Same pattern as TK_UNINSTALL_* |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 3.2+ (macOS) | Script runtime | Existing project constraint |
| `scripts/lib/optional-plugins.sh` | project internal | Canonical command strings | D-12: single source of truth |
| `scripts/detect.sh` | project internal | SP/GSD filesystem detection | Called before and after bootstrap |
| `scripts/lib/install.sh` | project internal | `recommend_mode()`, `log_*` helpers | Mode recompute after bootstrap |

No new npm/pip/brew dependencies are introduced. [VERIFIED: codebase grep]

---

## Architecture Patterns

### System Architecture Diagram

```text
User runs init-claude.sh or init-local.sh
       │
       ▼
[1] CLI flag parsing (--dry-run, --no-bootstrap, frameworks)
       │
       ▼  TK_NO_BOOTSTRAP=1 or --no-bootstrap?  ──yes──▶ silent skip
       │ no
       ▼
[2] source lib/bootstrap.sh → call bootstrap_base_plugins()
       │
       ├─ probe SP filesystem ─▶ already installed? → suppress SP prompt
       │
       ├─ claude on PATH? ───── no → suppress SP prompt + log_warning
       │
       ├─ [y/N] prompt via /dev/tty ── no TTY → log_info "bootstrap skipped"
       │   │                                     (both treated as N)
       │   ├─ y → eval $TK_BOOTSTRAP_SP_CMD  (or TK_SP_INSTALL_CMD)
       │   │       output streams verbatim to stdout/stderr
       │   │       non-zero exit → log_warning, continue
       │   └─ N → skip
       │
       ├─ probe GSD filesystem ─▶ already installed? → suppress GSD prompt
       │
       ├─ [y/N] prompt via /dev/tty (independent of SP result)
       │   ├─ y → eval $TK_BOOTSTRAP_GSD_CMD (or TK_GSD_INSTALL_CMD)
       │   │       output streams verbatim
       │   │       non-zero exit → log_warning, continue
       │   └─ N → skip
       │
       ▼
[3] re-source detect.sh → fresh HAS_SP / HAS_GSD
       │
       ▼
[4] MODE=$(recommend_mode)  ← or interactive select_mode if TTY
       │
       ▼
[5] Normal install loop (existing code, unchanged)
```

### Recommended Project Structure

```text
scripts/
├── lib/
│   ├── backup.sh           # existing pattern — bootstrap mirrors this shape
│   ├── optional-plugins.sh # ADD: TK_SP_INSTALL_CMD + TK_GSD_INSTALL_CMD constants
│   ├── bootstrap.sh        # NEW: bootstrap_base_plugins() entry point
│   └── install.sh          # existing — log_info/log_warning used by bootstrap
├── tests/
│   └── test-bootstrap.sh   # NEW: 5-scenario hermetic test
├── init-claude.sh          # EDIT: source bootstrap.sh + call bootstrap_base_plugins() + --no-bootstrap
└── init-local.sh           # EDIT: mirror same insertion point
docs/
└── INSTALL.md              # EDIT: add --no-bootstrap docs
```

### Pattern 1: Shared Library Shape (mirrors backup.sh)

```bash
#!/bin/bash
# bootstrap.sh — SP/GSD pre-install bootstrap
# Source this file. Do NOT execute directly.
# IMPORTANT: No set -euo pipefail — sourced libraries must not alter caller error mode.

# Color guards (same pattern as backup.sh and optional-plugins.sh)
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
[[ -z "${NC:-}"     ]] && NC='\033[0m'

bootstrap_base_plugins() {
    # Skip entirely if opted out (D-16/D-17: byte-quiet)
    [[ "${TK_NO_BOOTSTRAP:-}" == "1" ]] && return 0

    # --- SP idempotency (D-08) ---
    local sp_dir="${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers"
    local gsd_dir="${HOME}/.claude/get-shit-done"

    local sp_cmd="${TK_BOOTSTRAP_SP_CMD:-${TK_SP_INSTALL_CMD}}"
    local gsd_cmd="${TK_BOOTSTRAP_GSD_CMD:-${TK_GSD_INSTALL_CMD}}"

    # SP prompt block
    if [[ -d "$sp_dir" ]]; then
        log_info "superpowers already installed — skipping."
    elif ! command -v claude &>/dev/null; then
        log_warning "claude CLI not on PATH — superpowers bootstrap skipped (install Claude Code first)."
    else
        _bootstrap_prompt_and_run "superpowers" \
            "Install superpowers via plugin marketplace? [y/N] " \
            "$sp_cmd"
    fi

    # GSD prompt block (independent)
    if [[ -d "$gsd_dir" && -f "$gsd_dir/bin/gsd-tools.cjs" ]]; then
        log_info "get-shit-done already installed — skipping."
    else
        _bootstrap_prompt_and_run "get-shit-done" \
            "Install get-shit-done via curl install script? [y/N] " \
            "$gsd_cmd"
    fi
}

_bootstrap_prompt_and_run() {
    local plugin_name="$1" prompt_text="$2" cmd="$3"
    local choice=""
    if ! read -r -p "$prompt_text" choice < /dev/tty 2>/dev/null; then
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
}
```

[VERIFIED: codebase — mirrors exact pattern from backup.sh and optional-plugins.sh]

### Pattern 2: Constant Extraction in optional-plugins.sh

```bash
# Add at TOP of optional-plugins.sh, before recommend_optional_plugins()
# Guards match existing color-constant pattern in this file.
[[ -z "${TK_SP_INSTALL_CMD:-}"  ]] && TK_SP_INSTALL_CMD='claude plugin install superpowers@claude-plugins-official'
[[ -z "${TK_GSD_INSTALL_CMD:-}" ]] && TK_GSD_INSTALL_CMD='bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)'
```

[VERIFIED: optional-plugins.sh lines 31,34 hold the raw strings; extraction is a mechanical refactor]

### Pattern 3: Insertion Site in init-claude.sh

Exact insertion after line 92 (the last `source "$LIB_OPTIONAL_PLUGINS_TMP"` call) and
before line 103 (the `MANIFEST_VER` check / detect logic).

```bash
# ─────────────────────────────────────────────────
# Phase 21 — BOOTSTRAP-01..04
# source bootstrap.sh, then call bootstrap_base_plugins() before first detect run.
# ─────────────────────────────────────────────────
NO_BOOTSTRAP=false
# (--no-bootstrap is parsed in the argparse while-loop above)

LIB_BOOTSTRAP_TMP=$(mktemp "${TMPDIR:-/tmp}/bootstrap-lib.XXXXXX")
trap 'rm -f "$DETECT_TMP" ... "$LIB_BOOTSTRAP_TMP"' EXIT
if ! curl -sSLf "$REPO_URL/scripts/lib/bootstrap.sh" -o "$LIB_BOOTSTRAP_TMP"; then
    echo -e "${RED}✗${NC} Failed to download lib/bootstrap.sh — aborting"
    exit 1
fi
# shellcheck source=/dev/null
source "$LIB_BOOTSTRAP_TMP"

if [[ "$NO_BOOTSTRAP" != "true" && "${TK_NO_BOOTSTRAP:-}" != "1" ]]; then
    bootstrap_base_plugins
fi
```

[VERIFIED: init-claude.sh lines 63-92 are the lib-source block; lines 94-108 are detect+manifest; insertion goes between them]

### Pattern 4: Insertion Site in init-local.sh

In `init-local.sh` the libs are sourced at lines 32-38 (before argparse). The `detect.sh`
re-source after bootstrap must happen after argparse (line ~122) where `--no-bootstrap`
would be parsed. Structure:

```bash
# After argparse loop and MODE validation (around line 134), before re-run delegation (line 137):
# Source bootstrap lib (local path)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/bootstrap.sh"

if [[ "$NO_BOOTSTRAP" != "true" && "${TK_NO_BOOTSTRAP:-}" != "1" ]]; then
    bootstrap_base_plugins
    # Re-source detect to refresh HAS_SP / HAS_GSD (D-14)
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/detect.sh"
    if [[ -z "$MODE" ]]; then
        MODE=$(recommend_mode)
    fi
fi
```

**Note:** In `init-claude.sh` the `source "$DETECT_TMP"` at line 86 already runs before
argparse completes (the argparse while-loop is at lines 24-51, but the lib-source block is
at lines 63-92 — AFTER argparse). This means bootstrap fires after flag parsing, which is
correct for D-02. [VERIFIED: init-claude.sh line-by-line read]

**init-local.sh asymmetry:** libs are sourced at lines 32-38 BEFORE argparse (lines 81-122).
This means `bootstrap.sh` is sourced early but `bootstrap_base_plugins()` must be called
after argparse. The call site should be immediately after argparse + MODE validation,
before the re-run delegation check (line 137). [VERIFIED: init-local.sh line-by-line read]

### Pattern 5: Re-sourcing detect.sh

`detect.sh` when re-sourced calls `detect_superpowers || true` and `detect_gsd` at the
bottom of the file (lines 125-126). Both functions unconditionally set `HAS_SP`, `SP_VERSION`,
`HAS_GSD`, `GSD_VERSION` and export them. Re-sourcing is safe — no accumulated state, no
function-registration collision (bash redefines functions on re-source silently).

The only side effect of re-sourcing is that the color constants `RED/GREEN/YELLOW/BLUE/CYAN/NC`
get overwritten with the hard-coded ANSI values from `detect.sh` (lines 15-25). In
`init-claude.sh` this is not a problem because colors are set before lib-sourcing. In
`init-local.sh` the color-gate block at lines 43-59 must be re-applied after re-sourcing
(same pattern as uninstall.sh lines 109-123). [VERIFIED: detect.sh lines 15-25, 125-126;
init-local.sh lines 43-59]

### Pattern 6: `bash <(curl …)` Test Mockability (GSD_INSTALL_CMD)

`bash <(curl -sSL https://…/install.sh)` uses process substitution. It CANNOT be
mocked by partial string replacement if the test needs to intercept it — the shell evaluates
the process substitution before the variable is read.

**Solution** (Claude's Discretion area): Store the GSD command in `TK_GSD_INSTALL_CMD`
and `TK_BOOTSTRAP_GSD_CMD` as a full shell string, then invoke via `eval "$cmd"` (or
`bash -c "$cmd"`). The test seam sets `TK_BOOTSTRAP_GSD_CMD` to a mock script path that
exits 0 or 1 controllably:

```bash
# Test mock setup
MOCK_GSD="$SANDBOX/mock-gsd-install.sh"
printf '#!/bin/bash\necho mock-gsd-ran\nexit 0\n' > "$MOCK_GSD"
chmod +x "$MOCK_GSD"
export TK_BOOTSTRAP_GSD_CMD="$MOCK_GSD"
```

`eval "$TK_BOOTSTRAP_GSD_CMD"` executes the mock script. The real command `bash <(curl …)`
never runs in test mode. Same mechanism for SP: `TK_BOOTSTRAP_SP_CMD="$MOCK_SP"`.

[ASSUMED: `eval` with a trusted-source env var is the standard pattern for this kind of
test seam; no security concern because env vars are set by the test harness only, never
from user input]

**Security note:** `eval` on an env var is acceptable here ONLY because `TK_BOOTSTRAP_*_CMD`
is a developer/test-only seam documented as NEVER set in production. The production code
falls through to the `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` constants, which are
hardcoded readonly strings sourced from `optional-plugins.sh`. [VERIFIED: CONTEXT.md D-19]

### Pattern 7: TTY in `bash <(curl …)` piped context

When the user runs `bash <(curl -sSL …/init-claude.sh)`, bash's stdin IS the curl pipe.
`/dev/tty` is still available as a direct terminal device as long as the user's session has
a controlling terminal. This is exactly what `select_framework`, `select_mode`, and
`prompt_modified_for_uninstall` rely on in the existing codebase:

```bash
# From init-claude.sh line 192:
if ! read -r -p "..." choice < /dev/tty 2>/dev/null; then
    choice="1"
fi
```

The `2>/dev/null` suppresses the "cannot open /dev/tty" error in pure-CI environments.
The `if !` pattern treats a failed read (no TTY) as "use default". Bootstrap uses the
same idiom. [VERIFIED: init-claude.sh line 192, 233; uninstall.sh line 270]

**TTY seam for tests:** The uninstall suite uses `TK_UNINSTALL_TTY_FROM_STDIN=1` to
redirect reads from `/dev/tty` to `/dev/stdin`. Bootstrap test `test-bootstrap.sh` must
define an equivalent seam: `TK_BOOTSTRAP_TTY_SRC` (or inline in `_bootstrap_prompt_and_run`):

```bash
local tty_target="/dev/tty"
[[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"
if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
    log_info "bootstrap skipped — no TTY"
    return 0
fi
```

[VERIFIED: uninstall.sh lines 265-270 — exact precedent]

### Pattern 8: `recommend_optional_plugins()` Interaction (D-12)

After bootstrap, `recommend_optional_plugins()` at the end of `init-claude.sh` (called from
`main()` at line 832) will still print the SP and GSD install lines even if the user just
installed them. This is intentional (idempotency — user who runs again still sees reference).
D-12 does not require suppression; the end-of-run text is advisory.

**No code change needed** to `recommend_optional_plugins()`. The duplication is safe and
consistent with the existing "recommend then let user decide" UX. [VERIFIED: init-claude.sh
lines 831-832; optional-plugins.sh full read]

### Anti-Patterns to Avoid

- **Capturing upstream installer output** — D-11 forbids this; use direct invocation, not `$(...)`
- **`set -euo pipefail` in bootstrap.sh** — shared libs MUST NOT set error modes; would
  alter caller's error behavior (`init-claude.sh` and `init-local.sh` both have `set -euo pipefail`)
- **Touching `manifest.json`** — D-22: Phase 22 owns this; Phase 21 must not pre-register
- **Adding `bootstrap_run` to `toolkit-install.json`** — D-15 explicitly forbids this
- **Re-defining color constants unconditionally** — use `[[ -z "${VAR:-}" ]] &&` guards

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Plugin installation | Custom downloader | `claude plugin install …` | Upstream owns install contract |
| GSD installation | Custom fetch | `bash <(curl -sSL …)` verbatim | D-12 invariant; upstream owns |
| Mode computation | Custom logic | `recommend_mode()` from lib/install.sh | Already correct and tested |
| SP detection | Custom probe | `detect_superpowers()` in detect.sh | Already handles settings.json + CLI cross-check |
| GSD detection | Custom probe | `detect_gsd()` in detect.sh | Already handles filesystem check |

---

## Common Pitfalls

### Pitfall 1: init-local.sh lib-source order

**What goes wrong:** In `init-local.sh`, `detect.sh` is sourced at line 32 — BEFORE argparse.
If bootstrap.sh is also sourced at line 32 and `bootstrap_base_plugins()` is called there,
`--no-bootstrap` will not have been parsed yet, and the flag has no effect.

**Why it happens:** `init-local.sh` sources libs before parsing arguments (unlike
`init-claude.sh` which parses first at lines 24-51, then sources libs at 63-92).

**How to avoid:** Source `bootstrap.sh` early (with the other libs), but call
`bootstrap_base_plugins()` only AFTER the argparse while-loop completes. The function call
site must be after line 122 (end of argparse), before line 137 (re-run delegation).

**Warning signs:** `--no-bootstrap` flag parsed but bootstrap still runs; TK_NO_BOOTSTRAP=1
in env but prompts appear anyway.

### Pitfall 2: Re-source color overwrite

**What goes wrong:** After `source "$SCRIPT_DIR/detect.sh"` is called the second time (post-
bootstrap), `detect.sh` lines 15-25 overwrite `RED/GREEN/YELLOW/BLUE/CYAN/NC` with unconditional
ANSI escapes. In `init-local.sh` this breaks the NO_COLOR gating (lines 43-59).

**How to avoid:** Add a color-gate re-application block after the re-source call, identical
to `uninstall.sh` lines 109-123.

**Warning signs:** Output has unexpected color in CI or when `NO_COLOR` is set.

### Pitfall 3: `eval` with `bash <(curl …)` and no error propagation

**What goes wrong:** `eval "$TK_GSD_INSTALL_CMD"` where the command is `bash <(curl …)` —
if curl fails, `bash <(…)` gets an empty pipe and exits non-zero. Without `|| rc=$?` capture,
`set -euo pipefail` in the caller aborts the entire install.

**How to avoid:** Always capture exit code explicitly:

```bash
local rc=0
eval "$cmd" || rc=$?
if [[ $rc -ne 0 ]]; then
    log_warning "${plugin_name} install failed (exit code ${rc}) — continuing toolkit install"
fi
```

This is D-10 enforced at code level. [VERIFIED: CONTEXT.md D-10]

### Pitfall 4: `--no-bootstrap` not wired into argparse of both installers

**What goes wrong:** Flag is documented in `--help` but not added to the `case $1 in` argparse
block, so passing `--no-bootstrap` hits the `*) echo Unknown argument; exit 1` branch.

**How to avoid:** Add `--no-bootstrap) NO_BOOTSTRAP=true; shift ;;` to BOTH installers'
argparse loops. Also add it to the `--help` output block in `init-local.sh` (lines 99-110).

---

## Code Examples

### Test Scenario Structure (mirrors test-uninstall.sh)

```bash
# Source: scripts/tests/test-uninstall.sh lines 73-111 (S1 pattern)
run_s1_bootstrap_both_y() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-bootstrap.XXXXXX)"
    trap "rm -rf '${SANDBOX:?}'" RETURN

    # Mock SP: records invocation, exits 0
    MOCK_SP="$SANDBOX/mock-sp.sh"
    printf '#!/bin/bash\necho mock-sp-ran\nexit 0\n' > "$MOCK_SP"
    chmod +x "$MOCK_SP"

    # Mock GSD: records invocation, exits 0
    MOCK_GSD="$SANDBOX/mock-gsd.sh"
    printf '#!/bin/bash\necho mock-gsd-ran\nexit 0\n' > "$MOCK_GSD"
    chmod +x "$MOCK_GSD"

    # Run install; inject y/y via TTY seam; inject mocked HOME (no pre-existing plugins)
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
    assert_contains "mock-sp-ran" "$OUTPUT" "S1: SP mock was invoked"
    assert_contains "mock-gsd-ran" "$OUTPUT" "S1: GSD mock was invoked"
    # Post-detect mode: both mocks don't actually install, so mode is standalone
    assert_contains "standalone" "$OUTPUT" "S1: post-bootstrap mode resolves correctly"
    assert_contains "complement-full" "$(jq -r '.mode' "$SANDBOX/.claude/toolkit-install.json")" \
        "S1: state.json mode is complement-full" || true  # only if mock actually installs
}
```

### S3: `--no-bootstrap` produces zero output from bootstrap

```bash
run_s3_no_bootstrap() {
    OUTPUT=$(cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" --no-bootstrap 2>&1)
    # D-17: byte-quiet — no "bootstrap" word in output
    if printf '%s\n' "$OUTPUT" | grep -q "bootstrap"; then
        assert_fail "S3: --no-bootstrap is byte-quiet" "found 'bootstrap' in output"
    else
        assert_pass "S3: --no-bootstrap produces no bootstrap output"
    fi
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline install strings in recommend_optional_plugins() | Extracted constants `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` | Phase 21 | Bootstrap can source them; single source of truth |
| No bootstrap step | `bootstrap_base_plugins()` before detect.sh | Phase 21 | First-run UX improvement |

---

## File-Creation List

| File | Action | Notes |
|------|--------|-------|
| `scripts/lib/bootstrap.sh` | CREATE | New shared lib; sourced by both installers |
| `scripts/lib/optional-plugins.sh` | EDIT | Add `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` constants at top |
| `scripts/init-claude.sh` | EDIT | Source bootstrap.sh; add `--no-bootstrap` to argparse; call `bootstrap_base_plugins()`; re-source detect after |
| `scripts/init-local.sh` | EDIT | Source bootstrap.sh; add `--no-bootstrap` to argparse + `--help`; call after argparse; re-source detect after |
| `scripts/tests/test-bootstrap.sh` | CREATE | 5-scenario hermetic test (S1..S5) |
| `Makefile` | EDIT | Add Test 28 block after Test 27 |
| `.github/workflows/quality.yml` | EDIT | Add `test-bootstrap.sh` to Tests 21-27 step (rename to 21-28) |
| `docs/INSTALL.md` | EDIT | Document `--no-bootstrap` flag |

Manifest.json: NOT touched (D-22). Version: NOT bumped (D-23).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `eval "$cmd"` is the correct approach for making `bash <(curl …)` mockable via a seam env var | Pattern 6 | GSD install mock would not intercept; tests would invoke real curl |
| A2 | Re-sourcing detect.sh a second time is safe (no global state accumulation) | Pattern 5 | Re-source could produce double-export side effects; mitigated by reading detect.sh source |

Both A1 and A2 have been assessed as LOW risk — A2 is directly confirmed by reading detect.sh
lines 125-126 (functions set and export atomically, no append behavior).

---

## Open Questions

1. **TTY seam variable name for bootstrap**
   - What we know: uninstall uses `TK_UNINSTALL_TTY_FROM_STDIN`
   - What's unclear: whether bootstrap should use the same mechanism (stdin redirect) or a
     named file path (like `TK_BOOTSTRAP_TTY_SRC=/path/to/answers`)
   - Recommendation: Use file path (`TK_BOOTSTRAP_TTY_SRC`) — cleaner for multi-prompt
     scenarios where S1 needs two `y` answers; stdin redirect only works for sequential reads
     if the test pipes both lines together.

2. **SP mock actually installing files vs mode post-detect**
   - What we know: mock exits 0 but doesn't create the plugin directory
   - What's unclear: S1 expects `complement-full` mode after bootstrap, but if mock doesn't
     install, re-detect sees no SP → mode stays `standalone`
   - Recommendation: S1 test assertion should only check that mock was invoked + installer
     continued; mode assertion should be against `standalone` (mock didn't actually install).
     A separate sub-scenario can create the plugin dir stub before running to test mode upgrade.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All scripts | ✓ | 3.2+ (macOS), 5.x (Linux) | — |
| jq | init-claude.sh manifest guard | ✓ (assumed from prior phases) | any | Test skips jq-using assertions |
| /dev/tty | Bootstrap prompts | ✓ on macOS/Linux interactive | — | Fail-closed N (D-06) |
| curl | init-claude.sh remote lib fetch | ✓ | any | Hard-fail on download |

Step 2.6 SKIPPED for `bootstrap.sh` itself — it's a pure shell library with no new external
dependencies beyond what the existing installers already require.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes — user answers [y/N] | `case "${choice:-N}" in y|Y)` — safe |
| V6 Cryptography | no | — |

### Threat Model Considerations

**Arbitrary code execution risk of `bash <(curl …)` / `claude plugin install …`:**
This is the upstream installer's contract, not ours. The toolkit invokes these commands
verbatim (D-12). The threat model for MITM or supply-chain compromise against these
commands is owned by `gsd-build/get-shit-done` and `obra/superpowers` respectively.
Our responsibility stops at: (1) not modifying the canonical strings, (2) not capturing
or modifying the commands' output, (3) not making the invocation conditional on user-
supplied input beyond the `[y/N]` gate.

**eval safety:** `eval "$TK_BOOTSTRAP_SP_CMD"` / `eval "$TK_BOOTSTRAP_GSD_CMD"` is
acceptable because these variables are either (a) set by the test harness to trusted mock
paths, or (b) fall through to hardcoded constants from `optional-plugins.sh`. They are
never populated from user input. Planner should add a shellcheck disable comment and
an inline explanation to prevent future contributors from misidentifying this as a risk.

**[y/N] input:** `case "${choice:-N}"` handles all values safely — unrecognized input
falls through to the `*` branch (no-op), same as "N".

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (plain test scripts, same as test-uninstall.sh) |
| Config file | none |
| Quick run command | `bash scripts/tests/test-bootstrap.sh` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOOTSTRAP-01 | Prompts appear before detect; default N | integration | `bash scripts/tests/test-bootstrap.sh` | No — Wave 0 |
| BOOTSTRAP-01 | No TTY → behave as N + info line | integration | same | No — Wave 0 |
| BOOTSTRAP-02 | y → mock invoked; output streams; failure non-fatal | integration | same | No — Wave 0 |
| BOOTSTRAP-03 | detect.sh re-sourced; mode reflects post-bootstrap state | integration | same | No — Wave 0 |
| BOOTSTRAP-04 | --no-bootstrap produces zero bootstrap output | integration | same | No — Wave 0 |
| BOOTSTRAP-04 | TK_NO_BOOTSTRAP=1 same effect as --no-bootstrap | integration | same | No — Wave 0 |

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-bootstrap.sh`
- **Per wave merge:** `make test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/test-bootstrap.sh` — covers all 5 scenarios (S1..S5, ~25 assertions)

---

## Sources

### Primary (HIGH confidence)

- `scripts/init-claude.sh` — insertion site verified by line-by-line read
- `scripts/init-local.sh` — insertion site verified; argparse/lib-source asymmetry documented
- `scripts/detect.sh` — re-source behavior confirmed; color overwrite risk documented
- `scripts/lib/optional-plugins.sh` — canonical strings at lines 31,34 verified
- `scripts/lib/backup.sh` — lib shape (no set -euo, color guards) confirmed
- `scripts/lib/install.sh` — log_info/log_warning helpers confirmed; recommend_mode confirmed
- `scripts/uninstall.sh` lines 265-270 — TTY/fail-closed pattern extracted
- `scripts/uninstall.sh` lines 109-123 — color re-gate after lib-source documented
- `scripts/tests/test-uninstall.sh` — test structure (sandbox HOME, seam env vars) verified
- `Makefile` lines 132-144 — Test 27 block structure for Test 28 confirmed
- `.github/workflows/quality.yml` lines 109-117 — CI mirror pattern confirmed

### Secondary (MEDIUM confidence)

- CONTEXT.md D-01..D-23 — all 23 locked decisions reviewed; no contradictions found

---

## Metadata

**Confidence breakdown:**

- Insertion sites: HIGH — line-by-line read of both installers completed
- Test seam pattern: HIGH — direct read of uninstall.sh/test-uninstall.sh precedents
- `eval` for GSD mock: MEDIUM — sound approach; minor risk if future shellcheck
  rules change (mitigated by inline comment)
- Re-source safety: HIGH — detect.sh source confirmed idempotent

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (stable, POSIX shell — no fast-moving dependencies)
