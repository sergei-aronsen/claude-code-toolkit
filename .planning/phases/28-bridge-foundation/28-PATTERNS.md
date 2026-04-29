# Phase 28: Bridge Foundation — Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 3 new/modified files (detect2.sh modify, bridges.sh new, test-bridges.sh new)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/lib/detect2.sh` | lib / detection probe | request-response (0/1 exit code) | `scripts/lib/detect2.sh` (existing `is_rtk_installed` body, lines 70-72) | exact |
| `scripts/lib/bridges.sh` | lib / file-I/O + state mutation | file-I/O + CRUD (write bridge file + patch JSON) | `scripts/lib/mcp.sh` (header, color guards, TK_* seam) + `scripts/lib/state.sh` (Python atomic patch) | role-match |
| `scripts/tests/test-bridges.sh` | test | request-response (source lib, assert) | `scripts/tests/test-bootstrap.sh` + `scripts/tests/test-mcp-secrets.sh` | exact |

---

## Pattern Assignments

### `scripts/lib/detect2.sh` (detection probe extension)

**Analog:** `scripts/lib/detect2.sh` itself — lines 69-92

**Context: existing probe body Shape A** (lines 69-72):

```bash
# DET-04: PATH-agnostic RTK probe (covers brew /opt/homebrew/bin AND /usr/local/bin).
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}
```

**Context: two-condition Shape B for reference** (lines 54-67):

```bash
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
```

**New probes to insert** — use Shape A (single `command -v`, CLI-PATH wins):

- `is_codex_installed` inserts BEFORE `is_gsd_installed` (lex: codex < gsd)
- `is_gemini_installed` inserts BETWEEN `is_gsd_installed` and `is_rtk_installed` (lex: gsd < gemini < rtk)

**Header comment block to extend** (lines 6-14 of detect2.sh) — add both new function names to the `# Exposes:` list.

**detect2_cache extension** (lines 84-92) — existing pattern to mirror:

```bash
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

Append two new lines and extend the `export` statement:

```bash
    IS_COD=0; is_codex_installed   && IS_COD=1 || true
    IS_GEM=0; is_gemini_installed  && IS_GEM=1 || true
    export IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL IS_COD IS_GEM
```

**Critical note:** `detect2.sh` does NOT use `set -euo pipefail` (line 16: "No errexit/nounset/pipefail here — sourced files must not alter caller error mode"). Do NOT add it.

---

### `scripts/lib/bridges.sh` (new file, file-I/O + JSON CRUD)

**Primary analog:** `scripts/lib/mcp.sh` (header block, color guards, TK_* seam pattern)
**Secondary analog:** `scripts/lib/state.sh` (Python atomic tempfile+os.replace pattern, lines 71-137)

**File header pattern** (copy from `scripts/lib/mcp.sh` lines 1-29):

```bash
#!/bin/bash

# Claude Code Toolkit — Multi-CLI Bridge Library (v4.7+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   bridge_create_project <target> [project_root]  — write GEMINI.md/AGENTS.md in project
#   bridge_create_global <target>                  — write under ~/.gemini/ or ~/.codex/
# Returns: 0 = success, 1 = missing source, 2 = mkdir/write blocked
# Test seams:
#   TK_BRIDGE_HOME  — override $HOME for global write path and state file (default: $HOME)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
```

**Color guards pattern** (copy from `scripts/lib/mcp.sh` lines 31-41 OR `scripts/lib/detect2.sh` lines 19-28 — identical idiom):

```bash
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

**Source block** — source sibling libs using `BASH_SOURCE` with `:-` fallback (from `scripts/lib/detect2.sh` line 34):

```bash
# shellcheck source=/dev/null
_BRIDGES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
source "${_BRIDGES_LIB_DIR}/state.sh"
source "${_BRIDGES_LIB_DIR}/dry-run-output.sh"
```

**TK_BRIDGE_HOME seam** — mirror `scripts/lib/mcp.sh` lines 147-149 (`_mcp_config_path`):

```bash
_bridge_home() {
    echo "${TK_BRIDGE_HOME:-$HOME}"
}
```

**Target filename resolver** — `case` dispatch (Bash 3.2 safe):

```bash
_bridge_filename() {
    local target="$1"
    case "$target" in
        gemini) echo "GEMINI.md" ;;
        codex)  echo "AGENTS.md" ;;
        *)      return 1 ;;
    esac
}
```

**Global dir resolver** using the seam:

```bash
_bridge_global_dir() {
    local target="$1"
    local home
    home="$(_bridge_home)"
    case "$target" in
        gemini) echo "${home}/.gemini" ;;
        codex)  echo "${home}/.codex"  ;;
        *)      return 1               ;;
    esac
}
```

**Header banner heredoc pattern** — single-quoted delimiter to suppress variable expansion (from `scripts/tests/fixtures/council/stub-gemini.sh` lines 9-20 and RESEARCH.md §5):

```bash
_bridge_write_file() {
    local source="$1" target_path="$2"
    [[ -f "$source" ]] || return 1
    mkdir -p "$(dirname "$target_path")" || return 2
    {
        cat <<'BANNER'
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
BANNER
        echo ""
        cat "$source"
    } > "$target_path"
}
```

Note: use `BANNER` not `EOF` as delimiter to avoid collision with outer Python `<<'PYEOF'` blocks.

**SHA256 usage** — do NOT inline; call `sha256_file` from sourced `state.sh` (state.sh lines 32-53 exposes it). Mirror `scripts/uninstall.sh` line 219:

```bash
local source_sha bridge_sha
source_sha=$(sha256_file "$source" 2>/dev/null || echo "")
bridge_sha=$(sha256_file "$target_path" 2>/dev/null || echo "")
```

**Atomic JSON state mutation** — new Python block (NOT `write_state`, which would overwrite full document). Copy `tempfile.mkstemp + os.replace` shape from `scripts/lib/state.sh` lines 125-136:

```bash
_bridge_write_state_entry() {
    local target="$1" path="$2" scope="$3" source_sha="$4" bridge_sha="$5"
    local state_file
    state_file="$(_bridge_home)/.claude/toolkit-install.json"

    acquire_lock || return 1
    python3 - "$target" "$path" "$scope" "$source_sha" "$bridge_sha" \
              "$state_file" <<'PYEOF'
import json, os, sys, tempfile

target, path, scope, src_sha, br_sha, state_path = sys.argv[1:7]

if os.path.exists(state_path):
    with open(state_path) as f:
        state = json.load(f)
else:
    state = {}

bridges = state.get("bridges", [])

entry = {"target": target, "path": path, "scope": scope,
         "source_sha256": src_sha, "bridge_sha256": br_sha,
         "user_owned": False}
idx = next((i for i, e in enumerate(bridges)
            if e.get("target") == target and
               e.get("scope") == scope and
               e.get("path") == path), None)
if idx is not None:
    bridges[idx] = entry
else:
    bridges.append(entry)

state["bridges"] = bridges

out_dir = os.path.dirname(os.path.abspath(state_path))
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try: os.unlink(tmp_path)
    except FileNotFoundError: pass
    raise
PYEOF
    release_lock
}
```

**Caller contract for acquire_lock** — from `scripts/lib/state.sh` line 10: callers MUST register `trap 'release_lock' EXIT` before calling `acquire_lock`. Use a subshell inside `_bridge_write_state_entry` to isolate the trap, or ensure the calling function registers the trap first. The subshell approach is simpler for bridges since the function does one atomic operation.

**dro_print_header / dro_print_file usage** (from `scripts/lib/dry-run-output.sh` lines 48-63):

```bash
dro_init_colors
dro_print_header "+" "INSTALL" 1 _DRO_G
dro_print_file "$target_path"
```

---

### `scripts/tests/test-bridges.sh` (new test file)

**Primary analog:** `scripts/tests/test-bootstrap.sh` (lines 1-65, scenario structure, summary footer)
**Secondary analog:** `scripts/tests/test-mcp-secrets.sh` (TK_* seam setup at top, source pattern)

**File header + boilerplate** (copy from `scripts/tests/test-bootstrap.sh` lines 1-62):

```bash
#!/usr/bin/env bash
# test-bridges.sh — Phase 28 smoke test for scripts/lib/bridges.sh.
#
# Scenarios:
#   S1 — bridge_create_project gemini writes GEMINI.md with correct banner
#   S2 — bridge_create_project codex writes AGENTS.md
#   S3 — re-run is idempotent (SHA256 unchanged when source unchanged)
#   S4 — toolkit-install.json bridges[] has one entry with correct fields
#   S5 — TK_BRIDGE_HOME seam keeps all writes inside sandbox (no $HOME pollution)
#
# Usage: bash scripts/tests/test-bridges.sh
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

**SANDBOX setup with TK_BRIDGE_HOME** — always set at test function entry (from `test-mcp-secrets.sh` lines 41-43, adapted for bridges):

```bash
run_s1() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-bridges.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    export TK_BRIDGE_HOME="$SANDBOX"
    mkdir -p "$SANDBOX/.claude"
    # ... test body
}
```

**Source lib pattern** (from `test-mcp-secrets.sh` lines 45-46):

```bash
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/bridges.sh"
```

**Scenario assertion for banner content** — verify `<!--` and canonical source text appear in output file. Use `assert_contains` with `grep -q` pattern against file contents captured to a variable.

**State file inspection** — use `python3 -c 'import json,sys; ...' "$SANDBOX/.claude/toolkit-install.json"` (pattern from `test-state.sh` lines 46-47):

```bash
local entry_count
entry_count=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("bridges",[])))' "$SANDBOX/.claude/toolkit-install.json")
assert_eq "1" "$entry_count" "S4: bridges[] has exactly one entry"
```

**Final summary footer** (from `test-bootstrap.sh` lines 257-261):

```bash
echo ""
echo "test-bridges complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

## Shared Patterns

### Color guard (all lib files)

**Source:** `scripts/lib/detect2.sh` lines 19-28 (identical in `mcp.sh` lines 31-41, `bootstrap.sh` lines 22-31)
**Apply to:** `scripts/lib/bridges.sh`

```bash
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

### No-errexit lib header comment

**Source:** `scripts/lib/detect2.sh` line 16 / `scripts/lib/state.sh` line 9
**Apply to:** `scripts/lib/bridges.sh`

```bash
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
```

### BASH_SOURCE safe reference

**Source:** `scripts/lib/detect2.sh` line 34 / `scripts/lib/mcp.sh` line 46
**Apply to:** Any `BASH_SOURCE` use in `bridges.sh`

```bash
"$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
```

Note the `:-` fallback (not bare `BASH_SOURCE[0]`) to guard against `set -u` when sourced via process substitution.

### TK_* test seam form

**Source:** `scripts/lib/mcp.sh` lines 147-149 (`TK_MCP_CONFIG_HOME`)
**Apply to:** `TK_BRIDGE_HOME` in `bridges.sh`

```bash
_bridge_home() {
    echo "${TK_BRIDGE_HOME:-$HOME}"
}
```

### Python tempfile+os.replace atomic write

**Source:** `scripts/lib/state.sh` lines 125-136
**Apply to:** `_bridge_write_state_entry` Python block

```python
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try: os.unlink(tmp_path)
    except FileNotFoundError: pass
    raise
```

### Single-quoted heredoc delimiter

**Source:** RESEARCH.md §5 citing `scripts/tests/fixtures/council/stub-gemini.sh` lines 9-20
**Apply to:** banner block in `bridges.sh`

Use `<<'BANNER'` (not `<<BANNER`) so `$`, backtick, and backslash are literal. Use `BANNER` as delimiter name (not `EOF`) to avoid collision with Python `<<'PYEOF'` blocks in the same file.

### Test PASS/FAIL counter idiom

**Source:** `scripts/tests/test-bootstrap.sh` lines 31-55, 257-261
**Apply to:** `scripts/tests/test-bridges.sh`

Shared `assert_pass` / `assert_fail` / `assert_eq` / `assert_contains` helpers defined at top, `PASS` and `FAIL` counters, `exit 1` when `$FAIL -gt 0`.

---

## Critical Naming Corrections

The CONTEXT.md uses incorrect function names that do not exist in state.sh. Plans MUST use the actual names:

| CONTEXT.md incorrect name | Actual name in state.sh | Location |
|---------------------------|-------------------------|----------|
| `_state_lock` | `acquire_lock` | state.sh line 140 |
| `_atomic_json_write` | (no direct equivalent) | Python block inside `write_state`, lines 125-136 |
| `state_get` | `read_state` | state.sh line 55 |
| `state_set` | `write_state` | state.sh line 60 — but NOT reusable for bridges (see below) |

`write_state` CANNOT be reused for bridges because it rebuilds the entire JSON document from fixed positional arguments (mode, has_sp, sp_ver, etc.) and would clobber existing `installed_files[]`. The bridges array mutation requires its own Python block that patch-merges only `.bridges[]`.

---

## No Analog Found

None. All three files have close analogs in the codebase.

---

## Manifest Note

**manifest.json is NOT modified in Phase 28.** Per RESEARCH.md §8 and REQUIREMENTS.md traceability, `BRIDGE-DIST-01` (registering `scripts/lib/bridges.sh` in `files.libs[]`) is a Phase 31 task. The planner must not include a manifest.json edit in any Phase 28 plan.

When Phase 31 inserts the entry, the target position is between `bootstrap.sh` and `cli-recommendations.sh` (manifest.json lines 232-238) to maintain rough alphabetical order:

```json
{ "path": "scripts/lib/bridges.sh" }
```

---

## Metadata

**Analog search scope:** `scripts/lib/`, `scripts/tests/`, `manifest.json`
**Files scanned:** detect2.sh, state.sh, mcp.sh, bootstrap.sh, dry-run-output.sh, test-install-tui.sh, test-bootstrap.sh, test-mcp-secrets.sh, test-state.sh, manifest.json
**Pattern extraction date:** 2026-04-29
