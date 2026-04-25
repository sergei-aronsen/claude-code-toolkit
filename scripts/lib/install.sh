#!/bin/bash

# Claude Code Toolkit — Install Flow Library
# Source this file. Do NOT execute it directly.
# Exposes: MODES, recommend_mode, compute_skip_set, print_dry_run_grouped,
#          backup_settings_once, merge_settings_python, merge_plugins_python
# Globals: TK_SETTINGS_BACKUP (set by backup_settings_once on first call per run)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            All diagnostics go to stderr (>&2). Functions returning values use stdout.

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m'

# Mode constants (D-33). Order matches the interactive prompt 1..4 in init-claude.sh.
MODES=("standalone" "complement-sp" "complement-gsd" "complement-full")

# recommend_mode — pure function over $HAS_SP and $HAS_GSD (set by detect.sh).
# Stdout: one of the four mode strings.
recommend_mode() {
    if   [[ "${HAS_SP:-false}"  == "true" && "${HAS_GSD:-false}" == "true" ]]; then echo "complement-full"
    elif [[ "${HAS_SP:-false}"  == "true" ]];                                  then echo "complement-sp"
    elif [[ "${HAS_GSD:-false}" == "true" ]];                                  then echo "complement-gsd"
    else                                                                            echo "standalone"
    fi
}

# compute_skip_set <mode> <manifest_path>
# Stdout: JSON array of paths to SKIP. Errors go to stderr; returns 1 on bad mode or missing jq.
# (Verified against current manifest.json with jq 1.7.1 per RESEARCH.md Pattern 5.)
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
    if ! jq --version >/dev/null 2>&1; then
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

# print_dry_run_grouped <manifest_path> <mode>
# Prints chezmoi-grade grouped dry-run output:
#   [+ INSTALL]                                  N files
#     bucket/path
#     ...
#   [- SKIP]                                     N files
#     bucket/path  (conflicts_with:plugin)
#   Total: N files
# Color via dro_* helpers — caller MUST source scripts/lib/dry-run-output.sh first.
# ANSI auto-disable on non-TTY OR NO_COLOR (no-color.org).
# Zero filesystem writes. Returns 0 on success, 1 on bad mode / missing jq /
# missing dro_init_colors.
print_dry_run_grouped() {
    local manifest_path="$1" mode="$2"
    # Initialize dro_* color vars (TTY + NO_COLOR gated). Caller (init-claude.sh)
    # must have sourced scripts/lib/dry-run-output.sh BEFORE this function runs.
    if ! command -v dro_init_colors >/dev/null 2>&1; then
        echo "ERROR: dry-run-output.sh not sourced — print_dry_run_grouped cannot render" >&2
        return 1
    fi
    dro_init_colors

    # Build skip_json (case dispatch unchanged from original)
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
    if ! jq --version >/dev/null 2>&1; then
        echo "ERROR: jq not found - required for dry-run output" >&2
        return 1
    fi

    # First pass: collect into INSTALL_PATHS and SKIP_PATHS arrays.
    # SKIP entries are stored as "bucket/path  (conflicts_with:reason)" strings so
    # the per-file annotation survives into the grouped output.
    local -a INSTALL_PATHS=()
    local -a SKIP_PATHS=()
    while IFS= read -r line; do
        local bucket path skip reason
        bucket=$(printf '%s' "$line" | jq -r '.bucket')
        path=$(printf '%s'   "$line" | jq -r '.path')
        skip=$(printf '%s'   "$line" | jq -r '.skip')
        reason=$(printf '%s' "$line" | jq -r '.reason')
        if [ "$skip" = "true" ]; then
            SKIP_PATHS+=("${bucket}/${path}  (conflicts_with:${reason})")
        else
            INSTALL_PATHS+=("${bucket}/${path}")
        fi
    done < <(jq -c --argjson skip "$skip_json" '
        .files | to_entries[] |
        .key as $b | .value[] |
        { bucket: $b, path: .path,
          skip: ((.conflicts_with // []) as $cw |
                 ($skip | any(. as $s | $cw | contains([$s])))),
          reason: ((.conflicts_with // []) | join(",")) }
    ' "$manifest_path")

    local install_count="${#INSTALL_PATHS[@]}"
    local skip_count="${#SKIP_PATHS[@]}"
    local total=$((install_count + skip_count))

    # Second pass: print grouped sections (only render groups with count > 0)
    if [ "$install_count" -gt 0 ]; then
        dro_print_header "+" "INSTALL" "$install_count" _DRO_G
        local p
        for p in "${INSTALL_PATHS[@]}"; do
            dro_print_file "$p"
        done
        echo ""
    fi
    if [ "$skip_count" -gt 0 ]; then
        dro_print_header "-" "SKIP" "$skip_count" _DRO_Y
        local s
        for s in "${SKIP_PATHS[@]}"; do
            dro_print_file "$s"
        done
        echo ""
    fi

    dro_print_total "$total"
}

# merge_settings_python <settings_path> <hook_command>
# Atomic merge of a TK-owned PreToolUse Bash hook into settings.json.
# - Reads existing JSON via json.load
# - Partitions PreToolUse entries by _tk_owned marker (D-38)
# - Preserves foreign entries verbatim (SAFETY-02 / D-39 append-both)
# - Replaces existing TK entry in place on re-run (idempotent)
# - Atomic write via tempfile.mkstemp + os.replace (SAFETY-01 / D-37)
# - Honors TK_TEST_INJECT_FAILURE=1 for test 8c (raises RuntimeError before write)
# Returns: 0 on success, non-zero on python3 failure (caller should restore from $TK_SETTINGS_BACKUP).
merge_settings_python() {
    local settings_path="$1" hook_command="$2"
    python3 - "$settings_path" "$hook_command" <<'PYEOF'
import json, os, sys, tempfile

settings_path, hook_command = sys.argv[1], sys.argv[2]

# Test hook for SAFETY-03 / scenario 8c — fail BEFORE any write
if os.environ.get('TK_TEST_INJECT_FAILURE'):
    raise RuntimeError("injected failure for test 8c")

# Read existing settings; create skeleton if missing (TK invoked on a fresh ~/.claude/)
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        config = json.load(f)
else:
    config = {}

# Partition existing PreToolUse entries by _tk_owned marker (D-38)
existing = config.get('hooks', {}).get('PreToolUse', [])
foreign_entries = [e for e in existing if not e.get('_tk_owned')]

# Build the new TK entry; marker invisible to Claude Code hook execution (RESEARCH Option A)
new_tk_entry = {
    'matcher': 'Bash',
    '_tk_owned': True,
    'hooks': [{'type': 'command', 'command': hook_command}],
}

# Append-both policy (D-39): foreign entries first (fire first in array order), TK last
config.setdefault('hooks', {})['PreToolUse'] = foreign_entries + [new_tk_entry]

# Atomic write (D-37): mkstemp on same filesystem as target -> rename(2) is atomic on POSIX
out_dir = os.path.dirname(os.path.abspath(settings_path)) or '.'
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix='settings.', suffix='.tmp')
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF
}

# merge_plugins_python <settings_path> <plugin_csv>
# Same atomic merge for enabledPlugins; preserves existing entries; only ADDS missing plugins.
# plugin_csv format: "name1@scope,name2@scope,..."
# Honors TK_TEST_INJECT_FAILURE=1 for symmetry with merge_settings_python.
merge_plugins_python() {
    local settings_path="$1" plugin_csv="$2"
    python3 - "$settings_path" "$plugin_csv" <<'PYEOF'
import json, os, sys, tempfile

settings_path, plugin_csv = sys.argv[1], sys.argv[2]

if os.environ.get('TK_TEST_INJECT_FAILURE'):
    raise RuntimeError("injected failure for test 8c (plugins)")

if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        config = json.load(f)
else:
    config = {}

config.setdefault('enabledPlugins', {})
for plugin in [p.strip() for p in plugin_csv.split(',') if p.strip()]:
    if plugin not in config['enabledPlugins']:
        config['enabledPlugins'][plugin] = True

out_dir = os.path.dirname(os.path.abspath(settings_path)) or '.'
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix='settings.', suffix='.tmp')
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF
}

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

# compute_file_diffs_obj <state_json> <manifest_path> <mode>
# Stdout: ONE JSON object { new: [...], removed: [...], modified_candidates: [...] } describing:
#   new                 = (manifest.files.*.path - state.installed_files[].path) - compute_skip_set(mode)
#   removed             = state.installed_files[].path - manifest.files.*.path
#   modified_candidates = state.installed_files[].path ∩ manifest.files.*.path
# Returns 0 on success, 1 on unknown mode (compute_skip_set error forwarded).
# Consumers parse via jq -c '.new' / '.removed' / '.modified_candidates'.
# (Single-object form chosen over 3-line form per RESEARCH.md §Common Pitfalls: bash 3.2 safe, one fewer jq invocation.)
compute_file_diffs_obj() {
    local state_json="$1" manifest_path="$2" mode="$3"
    local mp ip sp
    mp=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$manifest_path") || return 1
    ip=$(jq -c '[.installed_files[].path]' <<<"$state_json")                  || return 1
    sp=$(compute_skip_set "$mode" "$manifest_path")                             || return 1
    jq -nc --argjson m "$mp" --argjson i "$ip" --argjson s "$sp" \
         '{ new: (($m - $i) - $s),
            removed: ($i - $m),
            modified_candidates: [$i[] | select(. as $x | $m | index($x) != null)] }'
}
