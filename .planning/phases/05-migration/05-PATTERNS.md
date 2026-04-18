# Phase 5: Migration - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 10 (4 new, 4 extended, 1 fixture-dir, 1 fixture-json)
**Analogs found:** 9 / 10 (fixture SP-cache dir has no prior analog)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/migrate-to-complement.sh` | executable script | request-response (interactive) | `scripts/update-claude.sh:1-99,415-440` | exact |
| `scripts/lib/state.sh` | library (extend) | transform (JSON write) | self (lines 43-111) | self-extend |
| `scripts/update-claude.sh` | executable script (extend) | request-response | self (lines 146-158, 270-295) | self-extend |
| `manifest.json` | config (extend) | data source | `scripts/tests/fixtures/manifest-update-v2.json` | role-match |
| `scripts/tests/test-migrate-diff.sh` | test harness | batch (fixture seed + assert) | `scripts/tests/test-update-diff.sh` | exact |
| `scripts/tests/test-migrate-flow.sh` | test harness | batch + event-driven (FIFO) | `scripts/tests/test-update-diff.sh:255-334` | exact |
| `scripts/tests/test-migrate-idempotent.sh` | test harness | batch | `scripts/tests/test-update-drift.sh:42-76` | role-match |
| `scripts/tests/fixtures/manifest-migrate-v2.json` | fixture / config | data source | `scripts/tests/fixtures/manifest-update-v2.json` | exact |
| `scripts/tests/fixtures/sp-cache/` | fixture directory tree | file I/O (read-only in tests) | no prior analog — novel fixture tree | none |
| `Makefile` (extend test target) | build config (extend) | batch | self (lines 78-87) | self-extend |

---

## Pattern Assignments

### `scripts/migrate-to-complement.sh` (executable script, interactive request-response)

**Analog:** `scripts/update-claude.sh`

**Shebang + flag parsing + ANSI color constants** (`update-claude.sh` lines 1-34):

```bash
#!/bin/bash

# Claude Code Toolkit — Smart Update Script
# ...

set -euo pipefail

# flag parsing block (before color constants)
NO_BANNER=0
for arg in "$@"; do
    case "$arg" in
        --no-banner) NO_BANNER=1 ;;
        *) ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
```

Migrate uses the same header shape. Flag surface: `--yes`, `--dry-run`, `--verbose`,
`--no-backup` (must hard-fail; backup is non-negotiable). Swap `CLAUDE_DIR` for
`CLAUDE_DIR="$HOME/.claude"` (migrate operates on `~/.claude`, not the project-local
`.claude`).

**mktemp + trap EXIT cleanup pattern** (`update-claude.sh` lines 43-47):

```bash
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install.XXXXXX")
LIB_STATE_TMP=$(mktemp "${TMPDIR:-/tmp}/state.XXXXXX")
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
trap 'rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$MANIFEST_TMP"' EXIT
```

Migrate adds `TK_TMPL_TMP` and includes `release_lock` in the trap (RESEARCH §Lock
Semantics). Trap MUST be registered before `acquire_lock` (state.sh header comment
mandate). Pattern per RESEARCH:

```bash
trap 'release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" \
      "$MANIFEST_TMP" "$TK_TMPL_TMP"' EXIT
acquire_lock || exit 1
```

**detect.sh soft-fail with test seam** (`update-claude.sh` lines 51-66):

```bash
if [[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]; then
    : # env vars already set by caller (test seam)
elif curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
else
    echo -e "${YELLOW}⚠${NC} Could not fetch detect.sh — plugin detection unavailable"
    HAS_SP=false
    HAS_GSD=false
    SP_VERSION=""
    GSD_VERSION=""
fi
```

Phase 5 seam variable is `TK_MIGRATE_HOME` (replaces `TK_UPDATE_HOME`). All seam
variables follow the naming convention: `TK_MIGRATE_*`.

**lib/install.sh + lib/state.sh hard-fail fetch** (`update-claude.sh` lines 69-80):

```bash
for lib_pair in "install.sh:$LIB_INSTALL_TMP" "state.sh:$LIB_STATE_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_UPDATE_LIB_DIR:-}" && -f "$TK_UPDATE_LIB_DIR/$lib_name" ]]; then
        cp "$TK_UPDATE_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
        echo -e "${RED}✗${NC} Failed to fetch scripts/lib/$lib_name — update cannot proceed"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
done
```

Mirror verbatim in migrate; replace `TK_UPDATE_LIB_DIR` with `TK_MIGRATE_LIB_DIR`.

**Remote manifest fetch + schema version check** (`update-claude.sh` lines 82-96):

```bash
MANIFEST_SRC="${TK_UPDATE_MANIFEST_OVERRIDE:-}"
if [[ -n "$MANIFEST_SRC" && -f "$MANIFEST_SRC" ]]; then
    cp "$MANIFEST_SRC" "$MANIFEST_TMP"
else
    if ! curl -sSLf "$REPO_URL/manifest.json" -o "$MANIFEST_TMP"; then
        echo -e "${RED}✗${NC} Failed to fetch manifest.json — update cannot proceed"
        exit 1
    fi
fi
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP" 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    echo -e "${RED}✗${NC} manifest.json has manifest_version=${MANIFEST_VER:-unknown}; update-claude.sh expects v2"
    exit 1
fi
```

Mirror verbatim; replace seam var name to `TK_MIGRATE_MANIFEST_OVERRIDE`.

**STATE_FILE / LOCK_DIR override for test seam** (`update-claude.sh` lines 108-114):

```bash
if [[ -n "${TK_UPDATE_HOME:-}" ]]; then
    CLAUDE_DIR="$TK_UPDATE_HOME/.claude"
fi
STATE_FILE="$CLAUDE_DIR/toolkit-install.json"
LOCK_DIR="$CLAUDE_DIR/.toolkit-install.lock"
```

Mirror verbatim; swap to `TK_MIGRATE_HOME`.

**Lock acquire + backup** (`update-claude.sh` lines 435-440):

```bash
trap 'release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" "$MANIFEST_TMP"' EXIT
acquire_lock || exit 1

BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-$(date -u +%s)-$$"
cp -R "$CLAUDE_DIR" "$BACKUP_DIR"
log_success "Backup created: $BACKUP_DIR"
```

Migrate adapts the backup path to `~/.claude-backup-pre-migrate-<unix-ts>/` (no `$$`
suffix — migration is single-run interactive). Backup failure must abort before any
`rm -f`:

```bash
BACKUP_DIR="$HOME/.claude-backup-pre-migrate-$(date -u +%s)"
if ! cp -R "$HOME/.claude" "$BACKUP_DIR"; then
    echo -e "${RED}✗${NC} Backup failed — aborting migration without removing any files"
    exit 1
fi
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR"
```

**Per-file `[y/N/d]` prompt loop** (`update-claude.sh` lines 577-593):

```bash
while :; do
    local choice=""
    if ! read -r -p "File $rel modified locally. Overwrite? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
        choice="N"
    fi
    case "${choice:-N}" in
        y|Y)
            cp "$remote_tmp" "$local_path"
            UPDATED_PATHS+=("$rel")
            return 0 ;;
        d|D)
            diff -u "$local_path" "$remote_tmp" || true ;;
        *)
            SKIPPED_PATHS+=("$rel:locally_modified")
            return 0 ;;
    esac
done
```

Migrate adapts to `rm -f` on `y` (delete, not overwrite), with `MIGRATED_PATHS` and
`KEPT_PATHS` arrays. The `|| true` after `diff -u` is mandatory under `set -euo pipefail`
because diff exits 1 when files differ. For `--yes` flag, bypass the prompt entirely and
default to `y`.

**Per-file TK template hash fetch** (RESEARCH §Remote Manifest Fetch Pattern):

```bash
fetch_tk_template_hash() {
    local rel="$1"
    local out=""
    if [[ -n "${TK_MIGRATE_FILE_SRC:-}" ]]; then
        if [[ -f "$TK_MIGRATE_FILE_SRC/$rel" ]]; then
            out=$(sha256_file "$TK_MIGRATE_FILE_SRC/$rel")
        fi
    else
        if curl -sSLf "$REPO_URL/$rel" -o "$TK_TMPL_TMP" 2>/dev/null; then
            out=$(sha256_file "$TK_TMPL_TMP")
        fi
    fi
    printf '%s' "$out"
}
```

**SP equivalent path resolution** (RESEARCH §D-71 Verification + §sp_equivalent field):

```bash
sp_equiv=$(jq -r --arg p "$rel" \
    '.files | to_entries[] | .value[] | select(.path == $p) | .sp_equivalent // ""' \
    "$MANIFEST_TMP")
if [[ -z "$sp_equiv" ]]; then
    sp_equiv="$rel"   # same-basename fallback (agents/code-reviewer.md)
fi
SP_PATH="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/$SP_VERSION/$sp_equiv"

if [[ -n "$SP_VERSION" && -f "$SP_PATH" ]]; then
    sp_hash=$(sha256_file "$SP_PATH")
else
    sp_hash=""   # triggers D-72 two-column fallback
fi
```

**Idempotence two-signal AND check** (RESEARCH §Idempotence Two-Signal AND):

```bash
STATE_MODE=$(jq -r '.mode' <<<"$STATE_JSON")
if [[ "$STATE_MODE" != "standalone" ]]; then
    SKIP_SET_JSON=$(compute_skip_set "$STATE_MODE" "$MANIFEST_TMP")
    INTERSECTION_HIT=false
    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        if [[ -f "$HOME/.claude/$rel" ]]; then
            INTERSECTION_HIT=true
            break
        fi
    done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")
    if [[ "$INTERSECTION_HIT" == "false" ]]; then
        echo "Already migrated to $STATE_MODE. Nothing to do."
        exit 0
    fi
fi
```

**Log helper convention** (`update-claude.sh` lines 120-123):

```bash
log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
```

Mirror identically in `migrate-to-complement.sh`.

---

### `scripts/lib/state.sh` — EXTEND (library, transform)

**Analog:** Self — `scripts/lib/state.sh:43-111`

**Current `write_state` signature** (lines 43-47):

```bash
write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7"
    mkdir -p "$(dirname "$STATE_FILE")"
    python3 - "$mode" "$has_sp" "$sp_ver" "$has_gsd" "$gsd_ver" "$installed_csv" "$skipped_csv" "$STATE_FILE" <<'PYEOF'
```

**Extended signature** (D-75 — add 8th positional arg with default):

```bash
write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7" synth_flag="${8:-false}"
    mkdir -p "$(dirname "$STATE_FILE")"
    python3 - "$mode" "$has_sp" "$sp_ver" "$has_gsd" "$gsd_ver" \
             "$installed_csv" "$skipped_csv" "$synth_flag" "$STATE_FILE" <<'PYEOF'
```

Inside the Python heredoc, the argv unpack changes from `sys.argv[1:9]` to `sys.argv[1:10]`:

```python
mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv, synth_flag, state_path = sys.argv[1:10]
```

The `state` dict gains two changes:

```python
state = {
    "version": 2,                                           # bumped from 1
    "mode": mode,
    "synthesized_from_filesystem": synth_flag == "true",   # NEW field
    # ... rest of keys unchanged ...
}
```

**Read-path backward compat for v1 state files** (add to `read_state` call sites or
wherever `synthesized_from_filesystem` is consumed):

```bash
synth=$(jq -r '.synthesized_from_filesystem // false' <<<"$STATE_JSON")
```

No change to the `read_state` function itself — callers use the `// false` jq default.

**Library invariant** (`lib/state.sh` lines 1-11 header comment):

```bash
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock.
```

This invariant is non-negotiable. The state.sh file must NOT gain `set -euo pipefail`.

**`acquire_lock` / `release_lock`** (lines 114-153) — copy verbatim, no changes needed.

---

### `scripts/update-claude.sh` — EXTEND (two retrofits)

**Retrofit A — D-50 synthesis path** (`update-claude.sh` lines 146-158):

```bash
synthesize_v3_state() {
    local manifest_file="$1"
    local mode installed_csv=""
    mode=$(recommend_mode)
    while IFS= read -r path; do
        if [[ -f "$CLAUDE_DIR/$path" ]]; then
            if [[ -n "$installed_csv" ]]; then installed_csv+=","; fi
            installed_csv+="$CLAUDE_DIR/$path"
        fi
    done < <(jq -r '.files | to_entries[] | .value[] | .path' "$manifest_file")
    log_info "First update after v3.x — synthesized install state from filesystem (mode=$mode)."
    write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" ""
}
```

Change: append `"true"` as the 8th argument to `write_state`. Also applies to the
error-recovery call site at line ~282 (grep for all `write_state` calls in
`synthesize_v3_state` before editing — RESEARCH Pitfall 7 warns there are exactly 2 call
sites inside `synthesize_v3_state`):

```bash
write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" "" "true"
```

Normal Phase 3 install path (in `init-claude.sh`, untouched) omits the 8th arg, defaulting
to `false`.

**Retrofit B — D-77 hint emission** (insert after state-load + detect block,
`update-claude.sh` lines 285-295, after `STATE_MODE` and `RECOMMENDED` are set):

```bash
# D-77 migrate hint (Phase 5 retrofit)
if [[ "$STATE_MODE" == "standalone" && \
      ("$HAS_SP" == "true" || "$HAS_GSD" == "true") ]]; then
    _HINT_HIT=false
    _HINT_SKIP_JSON=$(compute_skip_set "$(recommend_mode)" "$MANIFEST_TMP")
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        if [[ -f "$CLAUDE_DIR/$_rel" ]]; then _HINT_HIT=true; break; fi
    done < <(jq -r '.[]' <<<"$_HINT_SKIP_JSON")
    if [[ "$_HINT_HIT" == "true" ]]; then
        echo -e "${CYAN}ℹ${NC} Legacy duplicates detected (SP/GSD installed, mode=standalone). Run: ./scripts/migrate-to-complement.sh"
    fi
    unset _HINT_HIT _HINT_SKIP_JSON _rel
fi
```

This block is read-only (no state mutation, no exit). Insert after line 295 in current
source. Underscore-prefixed locals (`_HINT_HIT`, `_HINT_SKIP_JSON`, `_rel`) avoid
colliding with existing variable names in the surrounding scope.

---

### `manifest.json` — EXTEND (add `sp_equivalent` to 6 entries)

**Analog:** `scripts/tests/fixtures/manifest-update-v2.json` for field shape.

**Current entry shape** (`manifest-update-v2.json` lines 14-18):

```json
{ "path": "commands/debug.md",   "conflicts_with": ["superpowers"] },
```

**Extended entry shape** (D-71 escape hatch — add `sp_equivalent` field):

```json
{ "path": "commands/debug.md",   "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/systematic-debugging/SKILL.md" },
```

**Complete mapping for all 7 SP duplicates** (RESEARCH §D-71 Verification):

| Manifest path | `sp_equivalent` field needed? | Value |
|---|---|---|
| `commands/debug.md` | yes | `skills/systematic-debugging/SKILL.md` |
| `commands/plan.md` | yes | `skills/writing-plans/SKILL.md` |
| `commands/tdd.md` | yes | `skills/test-driven-development/SKILL.md` |
| `commands/verify.md` | yes | `skills/verification-before-completion/SKILL.md` |
| `commands/worktree.md` | yes | `skills/using-git-worktrees/SKILL.md` |
| `agents/code-reviewer.md` | no | same-basename holds |
| `skills/debugging/SKILL.md` | yes | `skills/systematic-debugging/SKILL.md` |

No `manifest_version` bump — `sp_equivalent` is an optional additive field. `validate-manifest.py`
does NOT currently check `sp_equivalent` values (acceptable; CI can't reach the SP plugin
cache). Add a comment above the field in the JSON explaining it points to the SP plugin
cache relative path.

---

### `scripts/tests/test-migrate-diff.sh` (test harness, batch assertions)

**Analog:** `scripts/tests/test-update-diff.sh`

**File header + constants** (lines 1-21):

```bash
#!/usr/bin/env bash
# test-migrate-diff.sh — Phase 5 Plan 05-02 three-way diff + user-mod detection assertions.
#
# Scenarios:
# - signal-a-only-flagged         (D-73 signal a: on-disk != state sha256)
# - signal-b-only-flagged         (D-73 signal b: on-disk != TK template)
# - both-signals-flagged          (D-73: both differ)
# - clean-file-no-warning         (no modification, no warning)
# - sp-missing-two-column         (D-72: SP file not found → two-column fallback)
#
# Exit 0 on all pass, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
MANIFEST_FIXTURE="${FIXTURES_DIR}/manifest-migrate-v2.json"
LIB_DIR="${REPO_ROOT}/scripts/lib"
```

**`assert_eq` helper** (lines 26-35, copy verbatim from `test-update-diff.sh`):

```bash
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
```

**TMPDIR + EXIT trap** (lines 37-38):

```bash
TMPDIR_ROOT="$(mktemp -d -t tk-migrate-diff.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT
```

**`sha256_of` helper** (lines 40-42, copy verbatim from `test-update-diff.sh`):

```bash
sha256_of() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}
```

**`seed_state_file` helper** (lines 46-65 of `test-update-diff.sh`) — copy verbatim but
bump `"version": 1` to `"version": 2` and add `"synthesized_from_filesystem": true` to
test that read-path treats the field correctly:

```bash
seed_state_file() {
    local state_path="$1" mode="$2" synth_flag="${3:-false}"
    shift 3
    local entries="[]"
    while [[ $# -ge 2 ]]; do
        local p="$1" h="$2"; shift 2
        entries=$(jq --arg p "$p" --arg h "$h" \
            '. + [{"path": $p, "sha256": $h, "installed_at": "2026-04-15T12:00:00Z"}]' \
            <<<"$entries")
    done
    jq -n --arg mode "$mode" --argjson synth "$synth_flag" --argjson files "$entries" \
        '{"version": 2, "mode": $mode,
          "synthesized_from_filesystem": $synth,
          "detected": {"superpowers": {"present": false, "version": ""},
                       "gsd": {"present": false, "version": ""}},
          "installed_files": $files,
          "skipped_files": [],
          "installed_at": "2026-04-15T12:00:00Z"}' \
        > "$state_path"
}
```

**Scenario invocation with test seam variables**:

```bash
TK_MIGRATE_HOME="$SCR" \
  TK_MIGRATE_LIB_DIR="$LIB_DIR" \
  TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
  TK_MIGRATE_FILE_SRC="$FILE_SRC" \
  TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE" \
  HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
  bash "$REPO_ROOT/scripts/migrate-to-complement.sh" \
      --dry-run 2>&1 || true
```

**Results footer** (lines 468-473 of `test-update-diff.sh`, copy verbatim):

```bash
echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
```

---

### `scripts/tests/test-migrate-flow.sh` (test harness, FIFO-based interactive flow)

**Analog:** `scripts/tests/test-update-diff.sh` Scenario 5 (lines 255-334) for the
FIFO + dual-outcome pattern.

**FIFO approach for simulating `/dev/tty`** (lines 295-333 of `test-update-diff.sh`):

```bash
local FIFO_DIR="$SCR/.fifo"
mkdir -p "$FIFO_DIR"
local FIFO="$FIFO_DIR/tty"
mkfifo "$FIFO"

# Feed 'y\n' to the FIFO in a background process
(echo "y" > "$FIFO") &
local BG_PID=$!

local OUT
OUT=$(TK_UPDATE_HOME="$SCR" \
      TK_UPDATE_LIB_DIR="$LIB_DIR" \
      TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
      TK_UPDATE_FILE_SRC="$FILE_SRC" \
      HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
      bash "$REPO_ROOT/scripts/update-claude.sh" \
          --no-banner --no-offer-mode-switch --no-prune \
          0<"$FIFO" 2>&1 || true)

wait "$BG_PID" 2>/dev/null || true

# Either FIFO reached /dev/tty (REMOTE-PLAN applied) or fail-closed (MUTATED-PLAN unchanged)
if [[ "$actual_content" == "REMOTE-PLAN" ]]; then
    assert_eq "REMOTE-PLAN" "$actual_content" "file overwritten with remote content (y path)"
else
    assert_eq "MUTATED-PLAN" "$actual_content" "file preserved (fail-closed, no /dev/tty)"
fi
```

For `--yes` flag scenario (bypass all prompts), use the flag instead of FIFO and assert
deterministic outcomes.

**Four test scenarios**:

1. `scenario_accept_all` — `--yes` flag; assert all duplicates removed from disk; state
   rewritten to `complement-sp`; `MIGRATED` count = total duplicates.
2. `scenario_decline_all` — FIFO feeding `N` for each file or `</dev/null` (fail-closed);
   assert no files removed; state records all in `skipped_files`.
3. `scenario_partial` — FIFO feeding `y\nN\n`; assert first file removed, second kept.
4. `scenario_dry_run` — `--dry-run` flag; assert exit 0; no files removed; no state
   rewrite; stdout lists would-remove paths.

---

### `scripts/tests/test-migrate-idempotent.sh` (test harness, second-run assertions)

**Analog:** `scripts/tests/test-update-drift.sh` Scenario 1 (lines 42-76) for the
"no pre-existing state" / synthesize path pattern.

**Scenario structure pattern** (`test-update-drift.sh` lines 42-76):

```bash
scenario_v3x_upgrade_path() {
    echo ""
    echo "Scenario 1: v3.x upgrade — synthesize state from filesystem"
    echo "---"
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT"   > "$SCR/.claude/commands/plan.md"

    local OUT
    OUT=$(TK_UPDATE_HOME="$SCR" \
          TK_UPDATE_LIB_DIR="$LIB_DIR" \
          TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
          TK_UPDATE_FILE_SRC="$EMPTY_SRC" \
          HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
          bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch 2>&1 || true)

    assert_eq "true" "$( [ -f "$SCR/.claude/toolkit-install.json" ] && echo true || echo false)" \
        "synthesized state file exists"
}
```

**Three idempotence scenarios**:

1. `scenario_normal_second_run` — seed state with `mode=complement-sp`, no duplicates on
   disk; run migrate; assert output contains `"Already migrated"` and exit code 0.
2. `scenario_manual_state_rollback_files_gone` — seed state with `mode=standalone`
   (manual rollback), but duplicates are NOT on disk; D-78 signal (b) is empty; assert
   `"Already migrated"` and exit 0 (self-heal).
3. `scenario_user_recreated_duplicate` — seed state with `mode=complement-sp`, but
   manually place one duplicate back on disk; D-78 signal (b) fires; assert script
   re-runs full flow (does NOT exit early).

**Exit code assertion pattern** (adapt from `assert_eq` — capture exit code explicitly):

```bash
local EXIT_CODE=0
bash "$REPO_ROOT/scripts/migrate-to-complement.sh" ... 2>&1 || EXIT_CODE=$?
assert_eq "0" "$EXIT_CODE" "second run exits 0"
```

---

### `scripts/tests/fixtures/manifest-migrate-v2.json` (fixture, data source)

**Analog:** `scripts/tests/fixtures/manifest-update-v2.json` for the schema shape.

**Must contain** (subset of real manifest, trimmed to the 7 SP duplicate paths plus
a non-conflicting path for control):

```json
{
  "manifest_version": 2,
  "version": "test-migrate",
  "updated": "2026-04-18",
  "description": "Phase 5 fixture — 7 SP duplicate entries with sp_equivalent fields. DO NOT install from this.",
  "files": {
    "agents": [
      { "path": "agents/code-reviewer.md", "conflicts_with": ["superpowers"] }
    ],
    "commands": [
      { "path": "commands/debug.md",    "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/systematic-debugging/SKILL.md" },
      { "path": "commands/plan.md",     "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/writing-plans/SKILL.md" },
      { "path": "commands/tdd.md",      "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/test-driven-development/SKILL.md" },
      { "path": "commands/verify.md",   "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/verification-before-completion/SKILL.md" },
      { "path": "commands/worktree.md", "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/using-git-worktrees/SKILL.md" },
      { "path": "commands/learn.md",    "conflicts_with": ["get-shit-done"] }
    ],
    "skills": [
      { "path": "skills/debugging/SKILL.md", "conflicts_with": ["superpowers"],
        "sp_equivalent": "skills/systematic-debugging/SKILL.md" }
    ]
  },
  "templates": {
    "base": { "path": "templates/base" }
  }
}
```

---

### `scripts/tests/fixtures/sp-cache/` (fixture directory tree, no analog)

**No prior analog exists.** This is a novel fixture that mirrors the SP 5.0.7 plugin cache
layout.

**Required structure** (RESEARCH §SP Plugin Cache Path):

```text
scripts/tests/fixtures/sp-cache/
└── superpowers/
    └── 5.0.7/
        ├── agents/
        │   └── code-reviewer.md        # same-basename match for agents/code-reviewer.md
        └── skills/
            ├── systematic-debugging/
            │   └── SKILL.md            # sp_equivalent for commands/debug.md + skills/debugging/SKILL.md
            ├── writing-plans/
            │   └── SKILL.md            # sp_equivalent for commands/plan.md
            ├── test-driven-development/
            │   └── SKILL.md            # sp_equivalent for commands/tdd.md
            ├── verification-before-completion/
            │   └── SKILL.md            # sp_equivalent for commands/verify.md
            └── using-git-worktrees/
                └── SKILL.md            # sp_equivalent for commands/worktree.md
```

Each `SKILL.md` contains a short known-content string (e.g., `SP-SKILL-CONTENT-<name>`)
so tests can assert on the SP hash column value.

**Test seam usage** — `TK_MIGRATE_SP_CACHE_DIR` points to
`scripts/tests/fixtures/sp-cache/`. The migrate script constructs the full SP file path as:

```bash
SP_PATH="${TK_MIGRATE_SP_CACHE_DIR:-$HOME/.claude/plugins/cache/claude-plugins-official}/superpowers/$SP_VERSION/$sp_equiv"
```

---

### `Makefile` — EXTEND test target (lines 78-87)

**Analog:** Self — `Makefile` lines 78-87.

**Current Tests 9/10/11 pattern** (lines 78-85):

```makefile
@echo "Test 9: update drift + v3.x synthesis + mode-switch"
@bash scripts/tests/test-update-drift.sh
@echo ""
@echo "Test 10: update file-diff (new/removed/modified)"
@bash scripts/tests/test-update-diff.sh
@echo ""
@echo "Test 11: update summary + no-op + backup path"
@bash scripts/tests/test-update-summary.sh
@echo ""
```

**Add Tests 12/13/14 immediately after** (before the `@echo "All tests passed!"` line):

```makefile
@echo "Test 12: migrate three-way diff + user-mod detection"
@bash scripts/tests/test-migrate-diff.sh
@echo ""
@echo "Test 13: migrate full flow (accept/decline/partial/dry-run)"
@bash scripts/tests/test-migrate-flow.sh
@echo ""
@echo "Test 14: migrate idempotence + self-heal"
@bash scripts/tests/test-migrate-idempotent.sh
@echo ""
```

---

## Shared Patterns

### `set -euo pipefail` — Executables Only

**Source:** `scripts/update-claude.sh:6` (and every other `scripts/*.sh`)
**Apply to:** `scripts/migrate-to-complement.sh`, all three test harnesses
**NOT apply to:** `scripts/lib/state.sh`, `scripts/lib/install.sh` (sourced libraries)

```bash
set -euo pipefail
```

### ANSI Color Constants

**Source:** `scripts/update-claude.sh:27-32`
**Apply to:** `scripts/migrate-to-complement.sh`

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

### `/dev/tty` Guard on Every Interactive `read`

**Source:** `scripts/update-claude.sh:579`
**Apply to:** All interactive `read -r -p "..."` calls in `migrate-to-complement.sh`

```bash
if ! read -r -p "Remove $rel? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
    choice="N"   # fail-closed: no /dev/tty (curl|bash context)
fi
```

Default must be `N` for all destructive operations (PROJECT.md Constraints).

### `diff -u` with `|| true`

**Source:** `scripts/update-claude.sh:588`
**Apply to:** `d` option in every `[y/N/d]` prompt loop

```bash
diff -u "$local_path" "$tk_tmpl_tmp" || true
```

Required under `set -euo pipefail` because `diff` exits 1 when files differ.

### Test Seam Variable Naming Convention

**Source:** `scripts/tests/test-update-drift.sh` (established Phase 4)
**Apply to:** All three new test harnesses and the migrate script itself

| Phase 4 seam | Phase 5 mirror |
|---|---|
| `TK_UPDATE_HOME` | `TK_MIGRATE_HOME` |
| `TK_UPDATE_LIB_DIR` | `TK_MIGRATE_LIB_DIR` |
| `TK_UPDATE_MANIFEST_OVERRIDE` | `TK_MIGRATE_MANIFEST_OVERRIDE` |
| `TK_UPDATE_FILE_SRC` | `TK_MIGRATE_FILE_SRC` |
| (none) | `TK_MIGRATE_SP_CACHE_DIR` (new) |

### `jq -r '.[]'` Loop with Empty-String Guard

**Source:** `scripts/update-claude.sh:596-599`
**Apply to:** Any loop over a jq-produced JSON array in migrate script

```bash
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    # ... process $rel ...
done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")
```

### Atomic JSON Write via `python3` + `os.replace`

**Source:** `scripts/lib/state.sh:99-110`
**Apply to:** `write_state` extension (change is inside the existing Python heredoc)

```python
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `scripts/tests/fixtures/sp-cache/` | fixture directory tree | file I/O (read-only) | No SP plugin cache fixture existed in prior phases; novel shape mirroring live SP 5.0.7 layout verified in RESEARCH §SP Plugin Cache Path |

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/tests/`, `scripts/tests/fixtures/`, `scripts/lib/`
**Files read for excerpts:** `update-claude.sh`, `lib/state.sh`, `tests/test-update-diff.sh`, `tests/test-update-drift.sh`, `tests/test-update-summary.sh`, `tests/fixtures/manifest-update-v2.json`, `Makefile`, `install-statusline.sh`
**Pattern extraction date:** 2026-04-18
