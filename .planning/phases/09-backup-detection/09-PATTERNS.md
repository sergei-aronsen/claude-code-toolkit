# Phase 9: Backup & Detection — Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 9 (5 new, 4 modified + 1 spec patch)
**Analogs found:** 9 / 9

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `scripts/lib/backup.sh` (NEW) | library | batch / transform | `scripts/lib/state.sh` | exact — sourced lib, no errexit, color constants, single-responsibility helpers |
| `scripts/tests/test-clean-backups.sh` (NEW) | test | batch / transform | `scripts/tests/test-update-summary.sh` | exact — bash-only, sandbox isolation, backup dir assertions |
| `scripts/tests/test-backup-threshold.sh` (NEW) | test | batch | `scripts/tests/test-update-summary.sh` | role-match (can fold into test-clean-backups.sh) |
| `scripts/tests/test-detect-cli.sh` (NEW) | test | request-response | `scripts/tests/test-detect.sh` | exact — source detect.sh with fake HOME, assert HAS_SP/SP_VERSION |
| `scripts/tests/test-detect-skew.sh` (NEW) | test | request-response | `scripts/tests/test-update-summary.sh` | role-match — seeds state JSON, runs update-claude.sh via seam, asserts output |
| `scripts/update-claude.sh` (MOD) | dispatch / CLI | request-response | self (existing arg-parser at lines 14–25) | self-analog |
| `scripts/detect.sh` (MOD) | library | request-response | self (existing settings.json block lines 57–71) | self-analog — same jq-guard + early-return shape |
| `scripts/migrate-to-complement.sh` (MOD) | CLI | CRUD | self (backup block lines 270–278) | self-analog |
| `scripts/lib/install.sh` (MOD) | library | transform | self (existing `backup_settings_once`, `recommend_mode`) | self-analog |
| `.planning/REQUIREMENTS.md` (MOD) | spec-doc | — | — | single-line wording patch, no code pattern |

---

## Pattern Assignments

### `scripts/lib/backup.sh` (NEW — library, batch)

**Analog:** `scripts/lib/state.sh` (lines 1–14)

**File header / sourced-lib disclaimer** (`state.sh` lines 1–14):

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

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
```

Copy this verbatim for `backup.sh` — change the Exposes / Globals doc comment, keep the no-errexit disclaimer and the color block. The `# shellcheck disable=SC2034` decorators from `install.sh:12–17` are needed if YELLOW/NC are defined but not used within the lib itself.

**`warn_if_too_many_backups()` core pattern** (from RESEARCH.md §BACKUP-02 Caller Surface + Pattern 4):

```bash
# warn_if_too_many_backups — emit a single YELLOW ⚠ when combined backup dir count > 10.
# Threshold hard-coded at 10 per D-09.
# Call AFTER a successful backup creation (D-11).
warn_if_too_many_backups() {
    local count
    count=$(( $(find "$HOME" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null | wc -l) ))
    if [[ $count -gt 10 ]]; then
        echo -e "${YELLOW}⚠${NC} ${count} toolkit backup dirs under \$HOME — run \`update-claude.sh --clean-backups\` to prune"
    fi
}
```

Key: `$(( ... | wc -l ))` arithmetic expansion strips BSD macOS leading spaces.

**`list_backup_dirs()` optional helper** (from RESEARCH.md §Code Examples):

```bash
# list_backup_dirs — stdout: one absolute path per line, newest epoch first.
list_backup_dirs() {
    local home="${1:-$HOME}"
    while IFS= read -r dir; do
        local name epoch
        name="$(basename "$dir")"
        case "$name" in
            .claude-backup-[0-9]*-[0-9]*)
                epoch="${name#.claude-backup-}"
                epoch="${epoch%-*}"
                ;;
            .claude-backup-pre-migrate-[0-9]*)
                epoch="${name#.claude-backup-pre-migrate-}"
                ;;
            *) continue ;;
        esac
        printf '%s %s\n' "$epoch" "$dir"
    done < <(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null) \
    | sort -rn \
    | cut -d' ' -f2-
}
```

`sort -rn` on the epoch prefix is POSIX-safe; avoids BSD-incompatible `sort -V`.

---

### `scripts/tests/test-clean-backups.sh` (NEW — test, BACKUP-01)

**Analog:** `scripts/tests/test-update-summary.sh` (lines 1–45, 78–132, 244–254)

**File skeleton** (copy from `test-update-summary.sh` lines 1–34):

```bash
#!/usr/bin/env bash
# test-clean-backups.sh — BACKUP-01 --clean-backups flag assertions.
#
# Scenarios:
# - empty-set: no backup dirs → one-line message + exit 0
# - dry-run: prints list + [would remove] tag, no delete, exit 0
# - prompt-y: single dir, answer y → dir removed
# - keep-n: 5 dirs, --keep=3 → 3 newest kept, 2 oldest prompted
# - keep-negative: exit 2 on --keep=-1
# - threshold-warning: 11 dirs → warn line present in output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected substring: ${needle}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-clean-backups.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT
```

**Sandbox isolation + backup dir seeding pattern** (from `test-update-summary.sh` lines 244–254 + `test-migrate-flow.sh` lines 46–47):

```bash
scenario_empty_set() {
    echo ""
    echo "Scenario: empty-set (BACKUP-01 D-07)"
    echo "---"
    local SCR="${TMPDIR_ROOT}/empty"
    mkdir -p "$SCR"

    # No backup dirs seeded — HOME overridden via TK_UPDATE_HOME
    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --clean-backups 2>&1 || true)

    assert_contains "No toolkit backup directories found" "$OUT" \
        "empty-set: prints no-dirs message"
    # verify exit 0 separately
}
```

**Backup dir counting assertion** (add to the test file, not in helpers.bash):

```bash
assert_backup_count() {
    local home="$1" expected="$2" msg="$3"
    local actual
    actual=$(( $(find "$home" -maxdepth 1 -type d \
        \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
        2>/dev/null | wc -l) ))
    assert_eq "$expected" "$actual" "$msg"
}

assert_dir_absent() {
    local path="$1" msg="$2"
    if [[ ! -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir unexpectedly present: $path)" >&2
    fi
}

assert_dir_present() {
    local path="$1" msg="$2"
    if [[ -d "$path" ]]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg} (dir missing: $path)" >&2
    fi
}
```

**FIFO pattern for interactive-prompt tests** (`test-update-diff.sh` lines 295–314):

```bash
# Single-prompt "y" path:
local FIFO_DIR="$SCR/.fifo"
mkdir -p "$FIFO_DIR"
local FIFO="$FIFO_DIR/tty"
mkfifo "$FIFO"
(echo "y" > "$FIFO") &
local BG_PID=$!
OUT=$(TK_UPDATE_HOME="$SCR" ... bash "$REPO_ROOT/scripts/update-claude.sh" \
        --clean-backups 0<"$FIFO" 2>&1 || true)
wait "$BG_PID" 2>/dev/null || true

# Multi-prompt (N dirs) variant:
(printf 'y\ny\nn\n' > "$FIFO") &
```

Fail-closed path (no FIFO needed): omit the FIFO entirely; the `if ! read -r < /dev/tty` branch defaults to `"N"` automatically in a test subprocess that has no tty.

**Seeding N backup dirs for threshold/keep tests:**

```bash
seed_backup_dirs() {
    # seed_backup_dirs <home> <count>
    # Creates .claude-backup-<epoch>-<n> siblings under <home>
    local home="$1" count="$2"
    local base_epoch=1713974400  # fixed epoch for reproducibility
    local i
    for ((i = 0; i < count; i++)); do
        mkdir -p "$home/.claude-backup-$((base_epoch + i))-$((1000 + i))"
    done
}
```

---

### `scripts/tests/test-backup-threshold.sh` (NEW — test, BACKUP-02)

**Recommendation:** Fold into `test-clean-backups.sh` as two extra scenarios rather than a separate file. This matches how BACKUP-02 callers (`update-claude.sh`, `migrate-to-complement.sh`) are tested inline with their siblings.

If kept separate, use identical skeleton to `test-clean-backups.sh`. Test that `warn_if_too_many_backups()` from `backup.sh` emits the warning at count=11 and stays silent at count=10:

```bash
scenario_threshold_boundary() {
    # count=10 → no warning
    local SCR="${TMPDIR_ROOT}/thresh10"
    seed_backup_dirs "$SCR" 10
    local OUT
    OUT=$(HOME="$SCR" bash -c 'source "$1"; warn_if_too_many_backups' -- \
            "$REPO_ROOT/scripts/lib/backup.sh" 2>&1 || true)
    assert_eq "false" \
        "$(echo "$OUT" | grep -q 'toolkit backup dirs' && echo true || echo false)" \
        "count=10: no threshold warning"

    # count=11 → warning fires
    local SCR2="${TMPDIR_ROOT}/thresh11"
    seed_backup_dirs "$SCR2" 11
    OUT=$(HOME="$SCR2" bash -c 'source "$1"; warn_if_too_many_backups' -- \
            "$REPO_ROOT/scripts/lib/backup.sh" 2>&1 || true)
    assert_contains "11 toolkit backup dirs" "$OUT" "count=11: threshold warning emitted"
}
```

---

### `scripts/tests/test-detect-cli.sh` (NEW — test, DETECT-06)

**Analog:** `scripts/tests/test-detect.sh` (lines 1–52, 60–85)

**File skeleton** (copy from `test-detect.sh`):

```bash
#!/bin/bash
# test-detect-cli.sh — DETECT-06 CLI cross-check assertions.
# Usage: bash scripts/tests/test-detect-cli.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

DETECT_SH="$(cd "$(dirname "$0")/.." && pwd)/detect.sh"
[ -f "$DETECT_SH" ] || { echo "ERROR: detect.sh not found at $DETECT_SH"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-detect-cli.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
```

**Mock claude binary pattern** (from RESEARCH.md §Testing Strategy):

```bash
setup_mock_claude() {
    # setup_mock_claude <mock_bin_dir> <scenario>
    # scenario: "enabled" | "disabled" | "error" | "nonjson" | "absent"
    local bin_dir="$1" scenario="$2"
    mkdir -p "$bin_dir"
    case "$scenario" in
        enabled)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo '[{"id":"superpowers@claude-plugins-official","version":"5.1.0","enabled":true}]'
MOCK
            ;;
        disabled)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo '[{"id":"superpowers@claude-plugins-official","version":"5.0.7","enabled":false}]'
MOCK
            ;;
        error)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
exit 1
MOCK
            ;;
        nonjson)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo "Error: could not connect to daemon"
MOCK
            ;;
        absent)
            # No file created — command -v claude returns non-zero
            ;;
    esac
    [[ "$scenario" != "absent" ]] && chmod +x "$bin_dir/claude"
}
```

**Test case invocation** (mirrors `run_case` in `test-detect.sh`):

```bash
run_cli_case() {
    local label="$1" mock_scenario="$2" seed_sp_fs="$3"
    local expect_has_sp="$4" expect_sp_version="$5"

    # Fresh HOME per case
    rm -rf "$SCRATCH/.claude" "$SCRATCH/.mockbin"
    mkdir -p "$SCRATCH/.claude"

    local mock_bin="$SCRATCH/.mockbin"
    setup_mock_claude "$mock_bin" "$mock_scenario"

    if [[ "$seed_sp_fs" == "true" ]]; then
        mkdir -p "$SCRATCH/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7"
        printf '{"enabledPlugins":{"superpowers@claude-plugins-official":true}}' \
            > "$SCRATCH/.claude/settings.json"
    fi

    local has_sp sp_version
    # Prepend mock binary; source detect.sh with overridden HOME
    has_sp=$(HOME="$SCRATCH" PATH="$mock_bin:$PATH" bash -c \
        'source "$1"; echo "$HAS_SP"' -- "$DETECT_SH" 2>/dev/null || echo "false")
    sp_version=$(HOME="$SCRATCH" PATH="$mock_bin:$PATH" bash -c \
        'source "$1"; echo "$SP_VERSION"' -- "$DETECT_SH" 2>/dev/null || echo "")

    local ok=true
    [ "$has_sp" = "$expect_has_sp" ]     || ok=false
    # Only assert version when non-empty expected
    if [[ -n "$expect_sp_version" ]]; then
        [ "$sp_version" = "$expect_sp_version" ] || ok=false
    fi

    if $ok; then
        echo "✅ PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $label (HAS_SP=$has_sp SP_VERSION=$sp_version)"
        echo "   expected HAS_SP=$expect_has_sp SP_VERSION=${expect_sp_version:-<any>}"
        FAIL=$((FAIL + 1))
    fi
}
```

---

### `scripts/tests/test-detect-skew.sh` (NEW — test, DETECT-07)

**Analog:** `scripts/tests/test-update-summary.sh` (lines 185–199, 277–291) — uses `TK_UPDATE_HOME` seam, seeds `toolkit-install.json`, asserts output contains warning text.

**Skeleton + seeding pattern** (from RESEARCH.md §Testing Strategy + `test-update-summary.sh`):

```bash
#!/usr/bin/env bash
# test-detect-skew.sh — DETECT-07 version-skew warning assertions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-update-v2.json"

PASS=0; FAIL=0
TMPDIR_ROOT="$(mktemp -d -t tk-detect-skew.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT
```

**State seeding helper** (synthesized from RESEARCH.md §DETECT-07 test pattern):

```bash
seed_state_with_versions() {
    # seed_state_with_versions <state_path> <sp_version> <gsd_version>
    local state_path="$1" sp_ver="$2" gsd_ver="$3"
    mkdir -p "$(dirname "$state_path")"
    jq -n \
        --arg sp  "$sp_ver" \
        --arg gsd "$gsd_ver" \
        '{
          "version": 2,
          "mode": "standalone",
          "synthesized_from_filesystem": false,
          "detected": {
            "superpowers": {"present": true,  "version": $sp},
            "gsd":         {"present": false, "version": $gsd}
          },
          "installed_files": [],
          "skipped_files": [],
          "installed_at": "2026-01-01T00:00:00Z"
        }' > "$state_path"
}
```

**Test invocation via `TK_UPDATE_HOME` seam** (mirrors `test-update-summary.sh` lines 185–192):

```bash
scenario_skew_sp_only() {
    local SCR="${TMPDIR_ROOT}/skew-sp"
    mkdir -p "$SCR/.claude"
    seed_state_with_versions "$SCR/.claude/toolkit-install.json" "5.0.7" ""

    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$SCR/.src" \
          HAS_SP=true HAS_GSD=false SP_VERSION="5.1.0" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" \
              --no-banner --no-offer-mode-switch 2>&1 || true)

    assert_contains "superpowers 5.0.7 → 5.1.0" "$OUT" \
        "skew warning contains old → new SP version"
    assert_contains "review install matrix" "$OUT" \
        "skew warning contains guidance text"
}
```

---

### `scripts/update-claude.sh` — arg-parser extension (BACKUP-01 dispatch)

**Analog:** Self — existing arg parser at lines 11–25.

**Existing pattern to extend** (`update-claude.sh` lines 11–25):

```bash
NO_BANNER=0
OFFER_MODE_SWITCH="interactive"
PRUNE_MODE="interactive"
for arg in "$@"; do
    case "$arg" in
        --no-banner) NO_BANNER=1 ;;
        --offer-mode-switch=yes)                       OFFER_MODE_SWITCH="yes" ;;
        --offer-mode-switch=no|--no-offer-mode-switch) OFFER_MODE_SWITCH="no" ;;
        --offer-mode-switch=interactive)               OFFER_MODE_SWITCH="interactive" ;;
        --prune=yes)                                   PRUNE_MODE="yes" ;;
        --prune=no|--no-prune)                         PRUNE_MODE="no" ;;
        --prune=interactive)                           PRUNE_MODE="interactive" ;;
        *) ;;
    esac
done
```

**New flag additions** (insert initialization before loop, new cases inside loop):

```bash
# Initialize before the for loop:
CLEAN_BACKUPS=0
KEEP_N=""
DRY_RUN_CLEAN=0

# Inside the case block (follow --keep=N form, matches --offer-mode-switch=yes precedent):
--clean-backups)  CLEAN_BACKUPS=1 ;;
--keep=*)         KEEP_N="${arg#--keep=}" ;;
--dry-run)        DRY_RUN_CLEAN=1 ;;
```

**Dispatch insertion** — after the banner block and `.claude` existence check (after line 269), before state load (line 274):

```bash
if [[ $CLEAN_BACKUPS -eq 1 ]]; then
    run_clean_backups "${KEEP_N:-}" "$DRY_RUN_CLEAN"
    exit $?
fi
```

**BACKUP-02 hook insertion** — after `log_success "Backup created: $BACKUP_DIR"` at line 459:

```bash
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"
cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
log_success "Backup created: $BACKUP_DIR"
warn_if_too_many_backups   # ← INSERT HERE (D-11: after successful creation)
```

**DETECT-07 hook insertion** — after `STATE_MANIFEST_HASH` extraction (line 291), before migrate hint block (line 297):

```bash
STATE_MANIFEST_HASH=$(jq -r '.manifest_hash // "unknown"' <<<"$STATE_JSON")

warn_version_skew   # ← INSERT HERE (D-23: after read_state, before prompts/summary)

# Phase 5 Plan 05-01 — migrate hint ...
if [[ "$STATE_MODE" == "standalone" && ...
```

---

### `scripts/detect.sh` — DETECT-06 CLI cross-check

**Analog:** Self — existing `settings.json` gate block (`detect.sh` lines 57–71).

**Existing pattern to replicate** (lines 57–71):

```bash
if [[ -f "$SETTINGS_JSON" ]] && command -v jq &>/dev/null; then
    local enabled
    enabled=$(jq -r '
        if (.enabledPlugins | type) == "object" and (.enabledPlugins | has("superpowers@claude-plugins-official"))
        then .enabledPlugins["superpowers@claude-plugins-official"] | tostring
        else "missing"
        end
    ' "$SETTINGS_JSON" 2>/dev/null || echo "missing")
    if [[ "$enabled" == "false" ]]; then
        HAS_SP=false
        SP_VERSION=""
        export HAS_SP SP_VERSION
        return 1
    fi
fi
```

Key shape to copy: `command -v <tool> &>/dev/null` guard → `local var; var=$(... 2>/dev/null || echo "")` → `case`/`if` on variable value → early `return 1` on "disabled" branch.

**Step 4 insertion** (replaces lines 73–76 with the CLI cross-check between line 71 and the final `HAS_SP=true`):

```bash
# [STEP 4] DETECT-06: cross-check with `claude plugin list --json`.
# SP only — GSD is not a Claude Code plugin (no entry in `claude plugin list`).
# Silent skip when claude CLI absent or errors. FS result wins on any CLI failure (D-17).
if command -v claude &>/dev/null && command -v jq &>/dev/null; then
    local cli_json cli_enabled cli_ver
    cli_json=$(claude plugin list --json 2>/dev/null || echo "")
    cli_enabled=$(jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .enabled' \
        <<<"$cli_json" 2>/dev/null || echo "")
    cli_ver=$(jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version' \
        <<<"$cli_json" 2>/dev/null || echo "")
    case "$cli_enabled" in
        "false")
            # CLI explicitly disabled — override FS (D-16)
            HAS_SP=false; SP_VERSION=""; export HAS_SP SP_VERSION; return 1 ;;
        "true")
            # CLI confirms enabled; CLI version is authoritative (D-18)
            [[ -n "$cli_ver" ]] && ver="$cli_ver"
            ;;
        "")
            # CLI absent from list or CLI errored — FS result wins (D-16 empty branch)
            ;;
    esac
fi

HAS_SP=true
SP_VERSION="$ver"
export HAS_SP SP_VERSION
return 0
```

Note: Single subprocess call to `claude plugin list --json` captured into `cli_json`; both `cli_enabled` and `cli_ver` are parsed from the same variable (avoids two subprocess calls — fixes RESEARCH.md Pitfall 5).

---

### `scripts/migrate-to-complement.sh` — BACKUP-02 threshold call

**Analog:** Self — backup block at lines 270–278.

**Existing pattern** (`migrate-to-complement.sh` lines 270–278):

```bash
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-migrate-$(date -u +%s)"
log_info "Creating backup at $BACKUP_DIR (this may take a moment)…"
if ! cp -R "$CLAUDE_DIR" "$BACKUP_DIR"; then
    log_error "Backup failed — aborting migration without removing any files"
    [[ -d "$BACKUP_DIR" ]] && rm -rf "$BACKUP_DIR"
    exit 1
fi
log_success "Backup created: $BACKUP_DIR"
```

**Insert after `log_success`**:

```bash
log_success "Backup created: $BACKUP_DIR"
warn_if_too_many_backups   # ← INSERT (D-11, BACKUP-02)
```

`backup.sh` must be sourced earlier in the file (alongside the other lib sources). Follow the same sourcing pattern used for `install.sh` and `state.sh` in `update-claude.sh` lines 71–81.

---

### `scripts/lib/install.sh` — `warn_version_skew()` addition

**Analog:** Self — `backup_settings_once()` (lines 59–67) and `recommend_mode()` (lines 23–30) as helper function shape reference.

**Existing helper shape** (`install.sh` lines 59–67):

```bash
# backup_settings_once <settings_path>
# Sets TK_SETTINGS_BACKUP global on first successful call. No-op on subsequent calls in same run.
# No-op when settings file does not exist.
backup_settings_once() {
    local settings_path="$1"
    [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && return 0
    [[ ! -f "$settings_path" ]] && return 0
    TK_SETTINGS_BACKUP="${settings_path}.bak.$(date +%s)"
    cp "$settings_path" "$TK_SETTINGS_BACKUP"
}
```

**`warn_version_skew()` to append at end of file** (from RESEARCH.md §Code Examples):

```bash
# warn_version_skew — compare stored plugin versions against current detection.
# Emits one YELLOW ⚠ line per changed plugin. Non-fatal, no prompt (D-24/D-25).
# Caller must have already sourced detect.sh (SP_VERSION / GSD_VERSION in scope)
# and called read_state (STATE_FILE path available).
# jq path: .detected.superpowers.version / .detected.gsd.version (state schema v2).
warn_version_skew() {
    [[ -f "${STATE_FILE:-}" ]] || return 0
    command -v jq &>/dev/null || return 0
    local stored_sp stored_gsd
    stored_sp=$(jq -r '.detected.superpowers.version // ""' "$STATE_FILE" 2>/dev/null || echo "")
    stored_gsd=$(jq -r '.detected.gsd.version // ""'        "$STATE_FILE" 2>/dev/null || echo "")
    # Only fire when stored version is non-empty AND differs from current (D-23)
    if [[ -n "$stored_sp"  && "$stored_sp"  != "${SP_VERSION:-}"  ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: superpowers ${stored_sp} → ${SP_VERSION:-unknown} — review install matrix"
    fi
    if [[ -n "$stored_gsd" && "$stored_gsd" != "${GSD_VERSION:-}" ]]; then
        echo -e "${YELLOW}⚠${NC} Base plugin version changed: get-shit-done ${stored_gsd} → ${GSD_VERSION:-unknown} — review install matrix"
    fi
}
```

---

## Shared Patterns

### Sourced-lib file contract (no errexit)

**Source:** `scripts/lib/state.sh` lines 1–14 and `scripts/detect.sh` lines 1–12
**Apply to:** `scripts/lib/backup.sh` (new)

Every sourced library in this codebase carries the same disclaimer comment and MUST NOT contain `set -euo pipefail` at file level. The comment wording from `state.sh:9`:

```bash
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
```

`backup.sh` must carry identical language.

### ANSI color constant redeclaration

**Source:** `scripts/lib/state.sh` lines 12–14, `scripts/lib/install.sh` lines 12–17
**Apply to:** `scripts/lib/backup.sh` (new)

Sourced libs each redeclare `YELLOW` and `NC` locally. Callers that also declare them get the last write — value is identical everywhere. Pattern from `install.sh`:

```bash
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m'
```

The `# shellcheck disable=SC2034` decorators are required if the constants are defined but not referenced within the lib file itself.

### Log helper style

**Source:** `scripts/update-claude.sh` lines 121–124
**Apply to:** Any warning emitted from new code paths

```bash
log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
```

Threshold warning (D-11) and skew warning (D-23) follow `log_warning` tone but are inlined with `echo -e` (not calling `log_warning`) because the formatted string includes variable interpolation mid-message. Matches `state.sh:125–126` pattern for lock-reclaim warnings.

### `< /dev/tty` prompt idiom (fail-closed)

**Source:** `scripts/update-claude.sh` (referenced in RESEARCH.md Pattern 1 from lines 381, 525, 598)
**Apply to:** `--clean-backups` per-dir prompt in `scripts/lib/backup.sh` or inline in `update-claude.sh`

```bash
local decision=""
if ! read -r -p "Remove $dir? [y/N]: " decision < /dev/tty 2>/dev/null; then
    decision="N"   # fail-closed under curl | bash
fi
case "${decision:-N}" in
    y|Y) rm -rf "$dir" ;;
    *)   : ;;
esac
```

`2>/dev/null` suppresses "no such file" when `/dev/tty` unavailable; `if !` catches both unavailability and EOF; default `"N"` is fail-closed.

### Test seam: `TK_UPDATE_HOME` + `TK_UPDATE_LIB_DIR`

**Source:** `scripts/update-claude.sh` lines 109–115, `scripts/tests/test-update-summary.sh` lines 118–122
**Apply to:** All `update-claude.sh` integration tests (test-detect-skew.sh, test-clean-backups.sh)

```bash
OUT=$(TK_UPDATE_HOME="$SCR" \
      TK_UPDATE_LIB_DIR="$LIB_DIR" \
      TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
      TK_UPDATE_FILE_SRC="$FILE_SRC" \
      HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
      bash "$REPO_ROOT/scripts/update-claude.sh" \
          --no-banner --no-offer-mode-switch 2>&1 || true)
```

`TK_UPDATE_HOME` redirects all state/backup paths to `$SCR`. `HAS_SP`/`HAS_GSD` bypass `detect.sh` (line 52 seam).

### FIFO tty simulation

**Source:** `scripts/tests/test-update-diff.sh` lines 295–314
**Apply to:** `test-clean-backups.sh` prompt-exercising scenarios

```bash
mkfifo "$FIFO"
(printf 'y\ny\nn\n' > "$FIFO") &
BG_PID=$!
OUT=$(... bash "$SCRIPT" 0<"$FIFO" 2>&1 || true)
wait "$BG_PID" 2>/dev/null || true
```

For N prompts, write N newline-separated answers before the script runs. For fail-closed path tests, omit the FIFO entirely.

### `find -maxdepth 1` backup dir count (BSD/GNU portable)

**Source:** RESEARCH.md Pattern 4, D-12
**Apply to:** `scripts/lib/backup.sh`, any test asserting backup counts

```bash
count=$(( $(find "$HOME" -maxdepth 1 -type d \
    \( -name '.claude-backup-*' -o -name '.claude-backup-pre-migrate-*' \) \
    2>/dev/null | wc -l) ))
```

The arithmetic expansion `$(( ... ))` strips macOS BSD `wc -l` leading whitespace. Never use `ls -d glob | wc -l` — glob fails with exit 1 on 0 matches.

---

## No Analog Found

All files have close analogs in the codebase. No file requires fallback to RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:** `scripts/lib/`, `scripts/tests/`, `scripts/detect.sh`, `scripts/migrate-to-complement.sh`, `scripts/update-claude.sh`
**Files read:** 12 (state.sh, install.sh, detect.sh, update-claude.sh, migrate-to-complement.sh, test-detect.sh, test-update-summary.sh, test-update-diff.sh, test-migrate-flow.sh + CONTEXT.md + RESEARCH.md)
**Pattern extraction date:** 2026-04-24
