#!/bin/bash
#
# install-hooks.sh
# Installer for Toolkit advisory hooks (v6.0).
#
# Copies templates/global/hooks/tk-*.sh into ~/.claude/hooks/ and registers them
# in ~/.claude/settings.json under the appropriate event types
# (UserPromptSubmit, Stop, PreToolUse Bash).
#
# Each registered entry carries:
#   _tk_owned: true       — generic TK-owned marker (compat with setup-security.sh)
#   _tk_hook_id: <name>   — granular id used for idempotent replacement
#
# Foreign entries are preserved verbatim (SAFETY-02 pattern). TK-owned entries
# with the same hook id are replaced in-place (SAFETY-01 atomic write via mkstemp).
#
# Idempotent: re-running the script replaces only TK-owned-with-matching-id
# entries; everything else is untouched.
#
# Usage:
#   bash scripts/install-hooks.sh            # install
#   bash scripts/install-hooks.sh --dry-run  # show what would change
#   bash scripts/install-hooks.sh --uninstall # remove TK hook entries

set -euo pipefail

# ─────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_JSON="$CLAUDE_DIR/settings.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"

REPO_URL="${TK_REPO_URL:-https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main}"
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"

# Resolve script-relative source for hook files. Three execution modes:
#   1) Local: scripts/install-hooks.sh inside repo → use ../templates/global/hooks
#   2) Override: TK_HOOKS_SOURCE env var points at downloaded staging dir
#   3) curl-pipe: no local source, no override → fetch from REPO_URL into a
#      tmp staging dir which is cleaned up at exit
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
LOCAL_SOURCE="$SCRIPT_DIR/../templates/global/hooks"
SOURCE_DIR="${TK_HOOKS_SOURCE:-}"
TMP_STAGING=""

# Hook registration table: hook_file:event:matcher
# - matcher used only for PreToolUse (Bash, Edit, etc.); empty for other events
HOOK_TABLE=(
    "tk-pre-gsd-plan-council.sh:UserPromptSubmit:"
    "tk-pre-gsd-plan-factcheck.sh:UserPromptSubmit:"
    "tk-post-gsd-phase-audit.sh:Stop:"
    "tk-cost-warning.sh:Stop:"
    "tk-pre-ship-reality-check.sh:PreToolUse:Bash"
)

DRY_RUN=0
UNINSTALL=0

# ─────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)
            cat <<EOF
install-hooks.sh — install Toolkit advisory hooks (v6.0)

Options:
  --dry-run    show what would change, write nothing
  --uninstall  remove TK-owned hook entries from settings.json
  -h, --help   show this help

Env vars:
  CLAUDE_DIR        override ~/.claude (default: \$HOME/.claude)
  TK_HOOKS_SOURCE   override source dir for hook files
  TK_HOOKS_DISABLE  set to 1 to disable runtime advisories (set in your shell rc)
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} unknown arg: $1" >&2
            exit 2
            ;;
    esac
    shift
done

# ─────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────

if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} python3 required for atomic JSON merge" >&2
    exit 1
fi

# Resolve SOURCE_DIR: explicit override > local repo > remote curl-pipe
if [ "$UNINSTALL" -eq 0 ]; then
    if [ -n "$SOURCE_DIR" ]; then
        if [ ! -d "$SOURCE_DIR" ]; then
            echo -e "${RED}Error:${NC} TK_HOOKS_SOURCE not a dir: $SOURCE_DIR" >&2
            exit 1
        fi
    elif [ -d "$LOCAL_SOURCE" ]; then
        SOURCE_DIR="$LOCAL_SOURCE"
    else
        # curl-pipe path: download hooks into a temp dir
        if ! command -v curl >/dev/null 2>&1; then
            echo -e "${RED}Error:${NC} curl required to fetch hooks remotely" >&2
            exit 1
        fi
        TMP_STAGING=$(mktemp -d "${TMPDIR:-/tmp}/tk-hooks.XXXXXX")
        # shellcheck disable=SC2064  # intentional: capture TMP_STAGING value at trap time
        trap "rm -rf '$TMP_STAGING'" EXIT
        SOURCE_DIR="$TMP_STAGING"
        for entry in "${HOOK_TABLE[@]}"; do
            local_file="${entry%%:*}"
            url="$REPO_URL/templates/global/hooks/$local_file"
            if ! curl -sSLf -A "$TK_USER_AGENT" "$url" -o "$SOURCE_DIR/$local_file" 2>/dev/null; then
                echo -e "${RED}Error:${NC} failed to download $url" >&2
                exit 1
            fi
            if [ ! -s "$SOURCE_DIR/$local_file" ]; then
                echo -e "${RED}Error:${NC} downloaded file is empty: $local_file" >&2
                exit 1
            fi
        done
    fi
fi

# ─────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────

# emit_dry "<message>"
emit_dry() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${YELLOW}[dry-run]${NC} $1"
    fi
}

# atomic_merge_hooks <settings_path> <hooks_json>
# hooks_json is a JSON object: { "<event>": [ { matcher, command, _tk_hook_id }, ... ] }
# Reads existing settings, partitions per-event entries by _tk_hook_id,
# replaces matching TK entries, preserves everything else, atomic-writes.
atomic_merge_hooks() {
    local settings_path="$1" hooks_json="$2"
    python3 - "$settings_path" "$hooks_json" <<'PYEOF'
import json, os, sys, tempfile

settings_path, hooks_json = sys.argv[1], sys.argv[2]
desired = json.loads(hooks_json)  # {event: [{matcher?, command, _tk_hook_id}, ...]}

if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        config = json.load(f)
else:
    config = {}

config.setdefault('hooks', {})

# Build set of TK hook ids we own per event
desired_ids_by_event = {ev: {h['_tk_hook_id'] for h in entries}
                        for ev, entries in desired.items()}

for event, new_entries in desired.items():
    existing = config['hooks'].get(event, []) or []

    # Partition existing entries:
    # - foreign: not _tk_owned → preserve verbatim
    # - tk_other: _tk_owned but different hook id (or no id, e.g. legacy combined hook) → preserve
    # - tk_replaceable: _tk_owned with id we are about to install → drop
    foreign = []
    tk_other = []
    for entry in existing:
        if not entry.get('_tk_owned'):
            foreign.append(entry)
            continue
        eid = entry.get('_tk_hook_id', '')
        if eid in desired_ids_by_event[event]:
            continue  # replaceable → drop
        tk_other.append(entry)

    # Build replacements
    fresh = []
    for h in new_entries:
        entry = {
            '_tk_owned': True,
            '_tk_hook_id': h['_tk_hook_id'],
            'hooks': [{'type': 'command', 'command': h['command']}],
        }
        if h.get('matcher'):
            entry['matcher'] = h['matcher']
        fresh.append(entry)

    config['hooks'][event] = foreign + tk_other + fresh

# Atomic write (D-37 pattern)
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

# atomic_remove_tk_hooks <settings_path>
# Drops all _tk_hook_id-marked entries (leaves the legacy combined hook with
# only _tk_owned: true intact, so safety-net keeps working).
atomic_remove_tk_hooks() {
    local settings_path="$1"
    python3 - "$settings_path" <<'PYEOF'
import json, os, sys, tempfile

path = sys.argv[1]
if not os.path.exists(path):
    sys.exit(0)
with open(path, 'r') as f:
    config = json.load(f)

hooks = config.get('hooks', {}) or {}
for event, entries in list(hooks.items()):
    kept = [e for e in (entries or []) if not e.get('_tk_hook_id')]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]

if hooks:
    config['hooks'] = hooks
elif 'hooks' in config:
    del config['hooks']

out_dir = os.path.dirname(os.path.abspath(path)) or '.'
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix='settings.', suffix='.tmp')
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF
}

# backup_settings <path>
# Single backup per run — emits a fresh suffix so concurrent invocations don't clobber.
backup_settings() {
    local path="$1"
    [ -f "$path" ] || return 0
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    local backup="${path}.tk-backup.${stamp}.$$"
    cp "$path" "$backup"
    echo -e "  ${GREEN}✓${NC} Backup: $backup"
}

# ─────────────────────────────────────────────────
# Uninstall path
# ─────────────────────────────────────────────────

if [ "$UNINSTALL" -eq 1 ]; then
    echo -e "${CYAN}Uninstalling Toolkit hooks${NC}"
    if [ ! -f "$SETTINGS_JSON" ]; then
        echo -e "  ${YELLOW}⚠${NC} No settings.json at $SETTINGS_JSON — nothing to do"
    else
        if [ "$DRY_RUN" -eq 1 ]; then
            emit_dry "would remove all _tk_hook_id entries from $SETTINGS_JSON"
        else
            backup_settings "$SETTINGS_JSON"
            atomic_remove_tk_hooks "$SETTINGS_JSON"
            echo -e "  ${GREEN}✓${NC} Removed TK hook entries from settings.json"
        fi
    fi

    # Remove copied hook files
    for entry in "${HOOK_TABLE[@]}"; do
        local_file="${entry%%:*}"
        target="$HOOKS_DIR/$local_file"
        if [ -f "$target" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                emit_dry "would remove $target"
            else
                rm -f "$target"
                echo -e "  ${GREEN}✓${NC} Removed $target"
            fi
        fi
    done
    echo ""
    echo -e "${GREEN}Done.${NC}"
    exit 0
fi

# ─────────────────────────────────────────────────
# Install path
# ─────────────────────────────────────────────────

echo -e "${CYAN}Installing Toolkit hooks${NC}"
echo "  CLAUDE_DIR: $CLAUDE_DIR"
echo "  SOURCE:     $SOURCE_DIR"
echo ""

# Step 1: Copy hook files
echo -e "${CYAN}Step 1: Copy hook scripts${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
    emit_dry "would mkdir -p $HOOKS_DIR"
else
    mkdir -p "$HOOKS_DIR"
fi

# Build desired registration JSON in parallel with copy step
HOOK_JSON='{}'
for entry in "${HOOK_TABLE[@]}"; do
    local_file="${entry%%:*}"
    rest="${entry#*:}"
    event="${rest%%:*}"
    matcher="${rest#*:}"

    src="$SOURCE_DIR/$local_file"
    dst="$HOOKS_DIR/$local_file"

    if [ ! -f "$src" ]; then
        echo -e "  ${RED}✗${NC} Missing source: $src" >&2
        exit 1
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        emit_dry "would copy $src → $dst (chmod +x)"
    else
        cp "$src" "$dst"
        chmod +x "$dst"
        echo -e "  ${GREEN}✓${NC} $dst"
    fi

    # Append to HOOK_JSON via jq
    if command -v jq >/dev/null 2>&1; then
        HOOK_JSON=$(printf '%s' "$HOOK_JSON" | jq \
            --arg event "$event" \
            --arg matcher "$matcher" \
            --arg cmd "$dst" \
            --arg id "$local_file" \
            '.[$event] = ((.[$event] // []) + [
                if $matcher == "" then
                    {command: $cmd, _tk_hook_id: $id}
                else
                    {command: $cmd, matcher: $matcher, _tk_hook_id: $id}
                end
            ])')
    else
        echo -e "  ${RED}✗${NC} jq required for hook registration" >&2
        exit 1
    fi
done
echo ""

# Step 2: Merge into settings.json
echo -e "${CYAN}Step 2: Register in settings.json${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
    emit_dry "would merge into $SETTINGS_JSON:"
    printf '%s\n' "$HOOK_JSON" | sed 's/^/    /'
else
    if [ -f "$SETTINGS_JSON" ]; then
        backup_settings "$SETTINGS_JSON"
    fi
    if atomic_merge_hooks "$SETTINGS_JSON" "$HOOK_JSON"; then
        echo -e "  ${GREEN}✓${NC} settings.json updated (foreign entries preserved)"
    else
        echo -e "  ${RED}✗${NC} JSON merge failed" >&2
        exit 1
    fi
fi
echo ""

# Step 3: Summary
echo -e "${CYAN}Done.${NC}"
echo ""
echo "Installed advisory hooks:"
for entry in "${HOOK_TABLE[@]}"; do
    local_file="${entry%%:*}"
    rest="${entry#*:}"
    event="${rest%%:*}"
    matcher="${rest#*:}"
    if [ -n "$matcher" ]; then
        echo "  • $local_file — $event ($matcher)"
    else
        echo "  • $local_file — $event"
    fi
done
echo ""
echo "Disable advisories at runtime: export TK_HOOKS_DISABLE=1"
echo "Uninstall:                      bash scripts/install-hooks.sh --uninstall"
