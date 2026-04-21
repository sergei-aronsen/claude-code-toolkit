# Phase 3: Install Flow - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 8
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/lib/install.sh` | sourced library | transform (skip-list computation, dry-run formatting) | `scripts/lib/state.sh` | exact |
| `scripts/init-claude.sh` | entrypoint script | request-response (install orchestration) | `scripts/init-claude.sh` itself (extend) | exact |
| `scripts/init-local.sh` | entrypoint script | request-response (install orchestration) | `scripts/init-local.sh` itself (extend) | exact |
| `scripts/update-claude.sh` | entrypoint script | request-response (detect wiring only) | `scripts/init-claude.sh` (same detect pattern) | role-match |
| `scripts/setup-security.sh` | entrypoint script | transform (settings.json merge) | `scripts/setup-security.sh` itself (refactor) | exact |
| `scripts/tests/test-modes.sh` | test harness | batch (4 mode assertions) | `scripts/tests/test-detect.sh` | exact |
| `scripts/tests/test-dry-run.sh` | test harness | batch (output + filesystem assertions) | `scripts/tests/test-detect.sh` | exact |
| `scripts/tests/test-safe-merge.sh` | test harness | batch (round-trip JSON merge assertions) | `scripts/tests/test-state.sh` | exact |
| `Makefile` | config (test target) | batch | `Makefile` itself (extend) | exact |

---

## Pattern Assignments

### `scripts/lib/install.sh` (NEW — sourced library, transform)

**Analog:** `scripts/lib/state.sh`

**Header + sourced-library invariant** (`scripts/lib/state.sh` lines 1-11):

```bash
#!/bin/bash

# Claude Code Toolkit — Install State Library
# Source this file. Do NOT execute it directly.
# Exposes: write_state, read_state, sha256_file, get_mtime, iso8601_utc_now,
#          acquire_lock, release_lock
# Globals: STATE_FILE, LOCK_DIR (absolute paths, set based on $HOME at source time)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock.
```

Key rule: NO `set -euo pipefail`, zero stdout during source, only function definitions and variable assignments at source time. `scripts/lib/install.sh` must replicate this header invariant verbatim.

**Color constants** (`scripts/lib/state.sh` lines 12-14) — same block reused in install.sh:

```bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
```

Full color set from `scripts/init-claude.sh` lines 10-15:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
```

**Verified jq skip-list expression** (from RESEARCH.md Pattern 5 — tested against real manifest):

```bash
# compute_skip_set <mode> <manifest_path>
# Returns JSON array of paths to SKIP. Outputs to stdout; all diagnostics to stderr.
compute_skip_set() {
    local mode="$1" manifest_path="$2"
    local skip_json
    case "$mode" in
        standalone)         skip_json='[]' ;;
        complement-sp)      skip_json='["superpowers"]' ;;
        complement-gsd)     skip_json='["get-shit-done"]' ;;
        complement-full)    skip_json='["superpowers","get-shit-done"]' ;;
        *)
            echo "ERROR: unknown mode: $mode" >&2
            return 1 ;;
    esac
    if ! jq --version &>/dev/null; then
        echo "ERROR: jq not found — required for install mode filtering" >&2
        return 1
    fi
    jq --argjson skip "$skip_json" \
      '[.files | to_entries[] | .value[] |
        select((.conflicts_with // []) as $cw |
               ($skip | any(. as $s | $cw | contains([$s])))) |
        .path]' \
      "$manifest_path"
}
```

**One-backup-per-run sentinel** (RESEARCH.md Pattern 4, from `scripts/install-statusline.sh` line 104):

```bash
# backup_settings_once <settings_path>
# Sets TK_SETTINGS_BACKUP global. Safe to call multiple times — only acts once per run.
backup_settings_once() {
    local settings_path="$1"
    [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && return 0  # already done this run
    [[ ! -f "$settings_path" ]] && return 0
    TK_SETTINGS_BACKUP="${settings_path}.bak.$(date +%s)"
    cp "$settings_path" "$TK_SETTINGS_BACKUP"
}
```

**`recommend_mode` pure function** (RESEARCH.md Mode Selection):

```bash
recommend_mode() {
    if   [[ "$HAS_SP" == "true" && "$HAS_GSD" == "true" ]]; then echo "complement-full"
    elif [[ "$HAS_SP" == "true" ]];                           then echo "complement-sp"
    elif [[ "$HAS_GSD" == "true" ]];                          then echo "complement-gsd"
    else                                                           echo "standalone"
    fi
}
```

**`print_dry_run_grouped` skeleton** (RESEARCH.md Dry-run section) — stdout only, no filesystem writes, honors `[ -t 1 ]` for colors:

```bash
print_dry_run_grouped() {
    local manifest_path="$1" mode="$2"
    local _GREEN _YELLOW _NC
    if [ -t 1 ]; then
        _GREEN='\033[0;32m' _YELLOW='\033[1;33m' _NC='\033[0m'
    else
        _GREEN='' _YELLOW='' _NC=''
    fi
    local skip_json
    skip_json=$(compute_skip_set "$mode" "$manifest_path")
    local install_count=0 skip_count=0
    # jq emits one JSON object per line: {bucket, path, skip, reason}
    while IFS= read -r line; do
        local bucket path skip reason
        bucket=$(printf '%s' "$line" | jq -r '.bucket')
        path=$(printf '%s'   "$line" | jq -r '.path')
        skip=$(printf '%s'   "$line" | jq -r '.skip')
        reason=$(printf '%s' "$line" | jq -r '.reason')
        if [[ "$skip" == "true" ]]; then
            echo -e "${_YELLOW}[SKIP — conflicts_with:${reason}]${_NC} $bucket/$path"
            skip_count=$((skip_count + 1))
        else
            echo -e "${_GREEN}[INSTALL]${_NC} $bucket/$path"
            install_count=$((install_count + 1))
        fi
    done < <(jq -c --argjson skip "$skip_json" '
        .files | to_entries[] |
        .key as $b | .value[] |
        { bucket: $b, path: .path,
          skip: ((.conflicts_with // []) as $cw |
                 ($skip | any(. as $s | $cw | contains([$s])))),
          reason: ((.conflicts_with // []) | join(",")) }
    ' "$manifest_path")
    echo ""
    echo "Total: $install_count install, $skip_count skip"
}
```

---

### `scripts/init-claude.sh` (EXTEND — entrypoint script, request-response)

**Analog:** `scripts/init-claude.sh` itself (extend existing)

**Current argument parser** (`scripts/init-claude.sh` lines 24-44) — new flags must be inserted BEFORE the `*)` catch-all:

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
        laravel|nextjs|nodejs|python|go|rails|base)
            FRAMEWORK="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo -e "Available frameworks: laravel, nextjs, nodejs, python, go, rails, base"
            exit 1
            ;;
    esac
done
```

New flags to insert before `*)` (RESEARCH.md Pattern 6):

```bash
        --mode)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}--mode requires a value${NC}"; exit 1
            fi
            MODE="$2"; shift 2 ;;
        --force)         FORCE=true;             shift ;;
        --force-mode-change) FORCE_MODE_CHANGE=true; shift ;;
```

Mode validation after parsing (RESEARCH.md Pattern 6):

```bash
VALID_MODES=("standalone" "complement-sp" "complement-gsd" "complement-full")
if [[ -n "${MODE:-}" ]]; then
    valid=false
    for m in "${VALID_MODES[@]}"; do [[ "$m" == "$MODE" ]] && valid=true; done
    if [[ "$valid" != "true" ]]; then
        echo -e "${RED}Invalid --mode value: $MODE${NC}"
        echo "Valid modes: standalone, complement-sp, complement-gsd, complement-full"
        exit 1
    fi
fi
```

**Remote detect.sh source pattern** (D-30, RESEARCH.md Pattern 1 + CONTEXT.md line 27):

```bash
# Source detect.sh — remote mktemp+trap pattern (D-30)
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
trap 'rm -f "$DETECT_TMP"' EXIT
curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP"
# shellcheck source=/dev/null
source "$DETECT_TMP"
```

The `trap` must be registered BEFORE the curl call so a failed download still cleans up the empty temp file (RESEARCH.md Pitfall 1 equivalent note on trap ordering).

**lib/install.sh source + STATE_FILE defaults** (sourced after arg parse, before any write):

```bash
# Source shared install helpers
LIB_TMP=$(mktemp "${TMPDIR:-/tmp}/install-lib.XXXXXX")
trap 'rm -f "$LIB_TMP"' EXIT
curl -sSLf "$REPO_URL/scripts/lib/install.sh" -o "$LIB_TMP"
# shellcheck source=/dev/null
source "$LIB_TMP"
```

**Re-run delegation check** (D-41, RESEARCH.md Re-run section) — placed after detect.sh source, before mode prompt:

```bash
if [[ -f "$HOME/.claude/toolkit-install.json" ]] && [[ "${FORCE:-false}" != "true" ]]; then
    echo "Install already present at ~/.claude/. Use 'update-claude.sh' to refresh or 'init-claude.sh --force' to reinstall."
    exit 0
fi
```

**Interactive mode prompt** (D-32) — mirrors `init-claude.sh:84` `/dev/tty` pattern exactly:

```bash
select_mode() {
    local recommended
    recommended=$(recommend_mode)
    echo -e "${BLUE}Detected plugins:${NC}"
    [[ "$HAS_SP"  == "true" ]] && echo -e "  ${GREEN}✓${NC} superpowers ($SP_VERSION)" \
                                || echo -e "  ${YELLOW}–${NC} superpowers not detected"
    [[ "$HAS_GSD" == "true" ]] && echo -e "  ${GREEN}✓${NC} get-shit-done ($GSD_VERSION)" \
                                || echo -e "  ${YELLOW}–${NC} get-shit-done not detected"
    echo ""
    echo -e "  Recommended: ${GREEN}$recommended${NC}"
    echo -e "  1) standalone  2) complement-sp  3) complement-gsd  4) complement-full"
    echo ""
    local choice
    if ! read -r -p "  Install mode (default: $recommended): " choice < /dev/tty 2>/dev/null; then
        choice=""
    fi
    case "${choice:-}" in
        1) MODE="standalone" ;;
        2) MODE="complement-sp" ;;
        3) MODE="complement-gsd" ;;
        4) MODE="complement-full" ;;
        *) MODE="$recommended" ;;
    esac
}
```

---

### `scripts/init-local.sh` (EXTEND — entrypoint script, request-response)

**Analog:** `scripts/init-local.sh` itself, plus `scripts/init-claude.sh` for mode additions

**Local detect.sh source pattern** (D-04/D-30) — insert after existing `SCRIPT_DIR` derivation (current line 12):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect.sh"
source "$SCRIPT_DIR/lib/install.sh"
```

**Per-project state file override** (D-43, RESEARCH.md Pitfall 7) — set AFTER sourcing state.sh:

```bash
# Override global STATE_FILE for per-project scope (D-43)
STATE_FILE=".claude/toolkit-install.json"
```

**Current dry-run block to REPLACE** (`scripts/init-local.sh` lines 128-144) — this static block must be replaced with `print_dry_run_grouped`:

```bash
# REPLACE THIS:
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}DRY RUN MODE — No changes will be made${NC}"
    echo ""
    echo "Would create:"
    echo "  $CLAUDE_DIR/"
    ...
    exit 0
fi
# WITH: print_dry_run_grouped "$MANIFEST_FILE" "$MODE" && exit 0
```

**Re-run check for per-project scope** (D-41 equivalent):

```bash
if [[ -f ".claude/toolkit-install.json" ]] && [[ "${FORCE:-false}" != "true" ]]; then
    echo "Install already present at .claude/. Use 'update-claude.sh' to refresh or 'init-local.sh --force' to reinstall."
    exit 0
fi
```

---

### `scripts/update-claude.sh` (MINIMAL EXTEND — source detect.sh only)

**Analog:** `scripts/init-claude.sh` (same remote-source pattern for detect.sh)

**Insertion point:** After the existing color constants block (lines 8-13) and `REPO_URL` definition (line 15), before the `MAIN` section (line 48). Add:

```bash
# Source detect.sh — expose HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION for Phase 4 consumption (D-31)
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
trap 'rm -f "$DETECT_TMP"' EXIT
curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null || {
    echo -e "${YELLOW}⚠${NC} Could not fetch detect.sh — plugin detection unavailable"
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION=""
}
if [[ -f "$DETECT_TMP" ]]; then
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
fi
```

Phase 3 adds no branching on `HAS_SP`/`HAS_GSD` in `update-claude.sh` — those variables are made available only.

---

### `scripts/setup-security.sh` (REFACTOR — fix hook-deletion bug at lines 228-230)

**Analog:** `scripts/setup-security.sh` lines 201-255 (existing python3 block — extend, don't rewrite)

**Bug to fix** (`scripts/setup-security.sh` lines 226-232 — the destructive replacement):

```python
# CURRENT — BROKEN (SAFETY-02 violation: removes SP/GSD hooks):
if 'PreToolUse' in config.get('hooks', {}):
    config['hooks']['PreToolUse'] = [
        entry for entry in config['hooks']['PreToolUse']
        if entry.get('matcher') != 'Bash'
    ]
else:
    config['hooks']['PreToolUse'] = []
config['hooks']['PreToolUse'].append(hook_entry)
```

**Replacement pattern** (RESEARCH.md TK-Owned Hook Identification, Option A — `_tk_owned: true`):

```python
# NEW — append-both policy (D-39), _tk_owned marker (D-38):
existing_hooks = config.get('hooks', {}).get('PreToolUse', [])
foreign_entries = [e for e in existing_hooks if not e.get('_tk_owned')]
# TK's new entry always includes the marker:
new_tk_entry = {
    'matcher': 'Bash',
    '_tk_owned': True,
    'hooks': [{'type': 'command', 'command': hook_command}]
}
config.setdefault('hooks', {})['PreToolUse'] = foreign_entries + [new_tk_entry]
```

**Existing atomic write pattern to preserve** (`scripts/setup-security.sh` lines 238-248 — already correct):

```python
import tempfile, os
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(settings_path))
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    os.unlink(tmp_path)
    raise
```

**Backup before mutation** (lines 202-204 — already present, shape to replicate for other mutation sites):

```bash
SETTINGS_BACKUP="${SETTINGS_JSON}.bak.$(date +%s)"
cp "$SETTINGS_JSON" "$SETTINGS_BACKUP"
```

For Phase 3 the `backup_settings_once()` from `lib/install.sh` replaces this inline pattern. Call `backup_settings_once "$SETTINGS_JSON"` at the start of the mutation function and use `$TK_SETTINGS_BACKUP` for the restore path.

**Failure restore pattern** (`scripts/setup-security.sh` line 252-254 — already correct, keep as-is):

```bash
cp "$SETTINGS_BACKUP" "$SETTINGS_JSON"
echo -e "  ${RED}✗${NC} JSON merge failed — restored from backup: $SETTINGS_BACKUP"
exit 1
```

---

### `scripts/tests/test-modes.sh` (NEW — test harness, batch)

**Analog:** `scripts/tests/test-detect.sh` (exact structural match)

**Harness skeleton** (`scripts/tests/test-detect.sh` lines 1-20):

```bash
#!/bin/bash
# Claude Code Toolkit — test-modes.sh test harness
# Usage: bash scripts/tests/test-modes.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

INSTALL_LIB="$(cd "$(dirname "$0")/../lib" && pwd)/install.sh"
[ -f "$INSTALL_LIB" ] || { echo "ERROR: install.sh not found at $INSTALL_LIB"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-modes.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

report_pass() { echo "✅ PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "❌ FAIL: $1"; FAIL=$((FAIL+1)); }
```

**Fixture manifest approach** (RESEARCH.md Test 6) — copy real manifest into SCRATCH, source lib, assert:

```bash
# Copy real manifest as fixture
cp "$(cd "$(dirname "$0")/../.." && pwd)/manifest.json" "$SCRATCH/manifest.json"
# shellcheck source=/dev/null
source "$INSTALL_LIB"

# Assert complement-sp → 7 skips
result=$(compute_skip_set "complement-sp" "$SCRATCH/manifest.json")
count=$(jq length <<< "$result")
[ "$count" -eq 7 ] && report_pass "complement-sp: 7 skips" \
                    || report_fail "complement-sp: expected 7, got $count"
```

**Results footer** (`scripts/tests/test-detect.sh` lines 83-85):

```bash
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

---

### `scripts/tests/test-dry-run.sh` (NEW — test harness, batch)

**Analog:** `scripts/tests/test-detect.sh` (scratch HOME, trap, pass/fail counters)

**Key assertions** (RESEARCH.md Test 7):

```bash
# Filesystem invariance before/after dry-run
snapshot_before=$(find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5 -q 2>/dev/null \
                  || find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5sum || echo "empty")
bash "$SCRIPT_DIR/init-local.sh" --dry-run --mode complement-sp > "$SCRATCH/dry_output.txt"
snapshot_after=$(find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5 -q 2>/dev/null \
                 || find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5sum || echo "empty")

[ "$snapshot_before" = "$snapshot_after" ] \
    && report_pass "dry-run: zero filesystem writes" \
    || report_fail "dry-run: wrote files"

grep -q '\[INSTALL\]'  "$SCRATCH/dry_output.txt" && report_pass "dry-run: [INSTALL] lines present" \
                                                  || report_fail "dry-run: no [INSTALL] lines"
grep -q '\[SKIP'       "$SCRATCH/dry_output.txt" && report_pass "dry-run: [SKIP] lines present" \
                                                  || report_fail "dry-run: no [SKIP] lines"
grep -q '^Total:'      "$SCRATCH/dry_output.txt" && report_pass "dry-run: totals footer present" \
                                                  || report_fail "dry-run: no totals footer"
```

Note: use `md5 -q` on macOS (BSD) and fall back to `md5sum` on Linux (RESEARCH.md confirms BSD compatibility).

---

### `scripts/tests/test-safe-merge.sh` (NEW — test harness, batch)

**Analog:** `scripts/tests/test-state.sh` (scenario-per-function structure, reset_home helper)

**Scenario function structure** (`scripts/tests/test-state.sh` lines 26-54):

```bash
reset_home() {
    HOME="$SCRATCH"
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"
}

scenario_a_foreign_keys_preserved() {
    reset_home
    SETTINGS_JSON="$SCRATCH/.claude/settings.json"
    # Seed with SP and GSD foreign hooks (no _tk_owned)
    python3 - "$SETTINGS_JSON" <<'PYEOF'
import json
settings = {"hooks": {"PreToolUse": [
    {"matcher": "Bash", "hooks": [{"type": "command", "command": "/sp/pre-bash.sh"}]},
    {"matcher": "Bash", "hooks": [{"type": "command", "command": "/gsd/gsd-validate.sh"}]}
]}}
open(sys.argv[1], 'w').write(json.dumps(settings, indent=2))
PYEOF
    # Run TK merge (calls setup-security.sh merge function or direct python3 block)
    # Assert foreign entries unchanged, TK entry added
    ...
}
```

**Failure injection approach** (RESEARCH.md Test 8c):

```python
# In the python3 merge block (for test use only):
import os
if os.environ.get('TK_TEST_INJECT_FAILURE'):
    raise RuntimeError("injected failure for test")
```

Set `TK_TEST_INJECT_FAILURE=1` before calling the merge, then assert backup file equals original content.

---

### `Makefile` (EXTEND test target with Tests 6/7/8)

**Analog:** `Makefile` lines 62-68 (Tests 4 and 5 pattern)

**Current Tests 4 and 5** (`Makefile` lines 63-68):

```makefile
	@echo "Test 4: detect.sh plugin detection harness"
	@bash scripts/tests/test-detect.sh
	@echo ""
	@echo "Test 5: state.sh install-state + lock harness"
	@bash scripts/tests/test-state.sh
	@echo ""
```

**New Tests 6/7/8** to append immediately after line 68, before `@echo "All tests passed!"`:

```makefile
	@echo "Test 6: lib/install.sh — mode skip-set correctness"
	@bash scripts/tests/test-modes.sh
	@echo ""
	@echo "Test 7: --dry-run grouped output + zero filesystem writes"
	@bash scripts/tests/test-dry-run.sh
	@echo ""
	@echo "Test 8: settings.json safe merge — foreign keys, backup, restore"
	@bash scripts/tests/test-safe-merge.sh
	@echo ""
```

---

## Shared Patterns

### Sourced-library invariant

**Source:** `scripts/lib/state.sh` lines 1-11
**Apply to:** `scripts/lib/install.sh`

- NO `set -euo pipefail` inside the library file
- Zero stdout during source (only function definitions and `readonly` variable assignments)
- All diagnostic messages go to stderr (`>&2`)
- Functions that return values use stdout; callers capture with `$(fn)` — no intermediate echoes

### `/dev/tty` guard for interactive reads

**Source:** `scripts/init-claude.sh` lines 83-87 and 430-433
**Apply to:** `init-claude.sh` mode prompt (D-32), mode-change prompt (D-42)

```bash
if ! read -r -p "  Enter choice [1-8] (default: 1): " choice < /dev/tty 2>/dev/null; then
    choice="1"
fi
choice="${choice:-1}"
```

The `if !` form handles both: (a) `/dev/tty` absence (read fails → default used), and (b) user presses Enter with no input (returns 0 but empty → `:-default` kicks in). Both branches produce the correct default. Required for `curl | bash` safety.

### python3 atomic JSON write

**Source:** `scripts/setup-security.sh` lines 238-247
**Apply to:** `scripts/setup-security.sh` refactor (SAFETY-01), `scripts/lib/state.sh` (existing reference)

```python
import tempfile, os
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(settings_path))
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    os.unlink(tmp_path)
    raise
```

`mkstemp(dir=same_filesystem)` + `os.replace` = atomic on POSIX. Trailing `\n` keeps file git-friendly.

### BSD-compatible timestamp

**Source:** `scripts/install-statusline.sh` line 104
**Apply to:** `backup_settings_once()` in `lib/install.sh`, any new backup call in `setup-security.sh`

```bash
cp "$file" "$file.bak.$(date +%s)"
```

`date +%s` (without `-u`) is safe on both macOS BSD and GNU Linux (confirmed). Produces monotonic unix timestamp suffix.

### Test harness scaffold

**Source:** `scripts/tests/test-detect.sh` lines 1-20 and 83-85
**Apply to:** All three new test harnesses (`test-modes.sh`, `test-dry-run.sh`, `test-safe-merge.sh`)

```bash
#!/bin/bash
# ... header comment

set -euo pipefail

TARGET_SH="$(cd "$(dirname "$0")/.." && pwd)/lib/install.sh"  # adjust per harness
[ -f "$TARGET_SH" ] || { echo "ERROR: file not found at $TARGET_SH"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-<name>.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

report_pass() { echo "✅ PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "❌ FAIL: $1"; FAIL=$((FAIL+1)); }

# ... scenarios ...

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

### ANSI color constants

**Source:** `scripts/init-claude.sh` lines 10-15
**Apply to:** All new executable scripts; `lib/install.sh` for dry-run formatter (local vars `_GREEN`/`_YELLOW`/`_NC` checked via `[ -t 1 ]`)

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

In `print_dry_run_grouped`, set to empty strings when `! [ -t 1 ]` (stdout not a terminal — e.g., piped to grep).

---

## Data Flow Links

```
init-claude.sh (extended)
  ├── sources detect.sh          → exports HAS_SP / HAS_GSD / SP_VERSION / GSD_VERSION
  ├── sources lib/install.sh     → calls compute_skip_set, recommend_mode, print_dry_run_grouped, backup_settings_once
  ├── sources lib/state.sh       → calls write_state (STATE_FILE = $HOME/.claude/toolkit-install.json)
  └── reads manifest.json        → jq filter for skip-list (inside compute_skip_set)

init-local.sh (extended)
  ├── sources detect.sh          → same exports
  ├── sources lib/install.sh     → same helpers
  ├── sources lib/state.sh       → calls write_state (STATE_FILE overridden to .claude/toolkit-install.json)
  └── reads manifest.json        → same jq filter

update-claude.sh (minimal extend)
  └── sources detect.sh          → exposes HAS_SP/HAS_GSD for Phase 4 (no branching in Phase 3)

setup-security.sh (refactor)
  ├── calls backup_settings_once → sets TK_SETTINGS_BACKUP
  └── python3 merge block        → reads ~/.claude/settings.json, separates _tk_owned vs foreign,
                                   appends TK entry, atomic write via os.replace

lib/install.sh (new)
  └── reads manifest.json        → jq expression for skip-list (called via compute_skip_set)
```

---

## No Analog Found

All files have close analogs in the codebase. No files require falling back to RESEARCH.md external patterns.

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/lib/`, `scripts/tests/`, `Makefile`
**Files scanned:** 9 (init-claude.sh, init-local.sh, update-claude.sh, setup-security.sh, install-statusline.sh, lib/state.sh, detect.sh, tests/test-detect.sh, tests/test-state.sh)
**Pattern extraction date:** 2026-04-18
