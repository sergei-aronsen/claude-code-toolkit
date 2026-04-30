#!/bin/bash

# Claude Code Rate Limit Statusline — Installer
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# DISPATCH-02 — accept --yes as no-op for symmetry with TUI dispatch contract.
# install-statusline.sh has zero interactive `read -r -p` blocks (it reads only
# from the macOS Keychain, which has no interactive prompt component). YES=1 is
# parse-and-store today; future-proof against any interactive prompt added later.
YES=0
for _arg in "$@"; do
    case "$_arg" in
        --yes) YES=1 ;;
        *)
            # Audit M4: fail-closed on unknown flag (matches uninstall.sh:42,
            # init-claude.sh:64, setup-security.sh:33). Typos like
            # `--dry-runn` previously warned-and-continued.
            echo -e "${RED}✗${NC} unknown flag: $_arg" >&2
            echo "Supported: --yes" >&2
            exit 1
            ;;
    esac
done
: "${YES}"  # silence shellcheck SC2034 — no-op stub today

# Audit H5: TK_TOOLKIT_REF pins to a tag/SHA (default `main`).
TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-main}"
# Audit INF-MED-2 (2026-04-30 deep): allowlist guard — TK_TOOLKIT_REF flows
# raw into curl URLs. Reject anything outside the tag/SHA charset, plus any
# `..` traversal sequence. Tags / branches / SHAs do not contain `..`.
if ! [[ "$TK_TOOLKIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$TK_TOOLKIT_REF" == *..* ]]; then
    echo "Error: TK_TOOLKIT_REF must match [A-Za-z0-9._/-]+ and must not contain '..' (got: $TK_TOOLKIT_REF)" >&2
    exit 1
fi
REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/${TK_TOOLKIT_REF}"
# Audit L4 — global rules §2: every outgoing curl gets a real browser UA.
# shellcheck disable=SC2034
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"
# Audit INF-MED-3 (2026-04-30 deep): export so child sub-installers spawned
# via `bash <(curl -sSL $REPO_URL/...)` inherit the pinned ref + UA instead
# of silently falling back to defaults (e.g., TK_TOOLKIT_REF=main).
export TK_TOOLKIT_REF TK_USER_AGENT
CLAUDE_DIR="$HOME/.claude"

# Audit M3: source lib/install.sh for backup_settings_once + atomic merge helpers.
# Remote curl|bash callers download to mktemp; local callers source from sibling dir.
LIB_INSTALL_TMP=""
if [[ -f "$(dirname "$0")/lib/install.sh" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/lib/install.sh"
else
    LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install-lib.XXXXXX")
    trap 'rm -f "$LIB_INSTALL_TMP"' EXIT
    if ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/lib/install.sh" -o "$LIB_INSTALL_TMP" 2>/dev/null; then
        # Non-fatal: only the atomic-merge path needs it. Statusline can still install.
        echo -e "${YELLOW}⚠${NC} Could not fetch lib/install.sh — settings.json merge will use fallback (non-atomic)"
    else
        # shellcheck source=/dev/null
        source "$LIB_INSTALL_TMP"
    fi
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Rate Limit Statusline — Installation     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This tool requires macOS (uses Keychain for OAuth token).${NC}"
    echo -e "Linux support is planned for a future release."
    exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
    echo -e "${YELLOW}jq is required but not installed.${NC}"
    if command -v brew &>/dev/null; then
        echo -e "Installing with Homebrew..."
        brew install jq
    else
        echo -e "${RED}Please install jq: https://jqlang.github.io/jq/download/${NC}"
        exit 1
    fi
fi

# Check curl
if ! command -v curl &>/dev/null; then
    echo -e "${RED}Error: curl is required but not found.${NC}"
    exit 1
fi

# Check Claude Code OAuth token
echo -e "${BLUE}Checking Claude Code credentials...${NC}"
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: No Claude Code OAuth token found in Keychain.${NC}"
    echo -e ""
    echo -e "Make sure you are logged into Claude Code:"
    echo -e "  ${YELLOW}claude${NC}   (then sign in if prompted)"
    echo -e ""
    echo -e "This tool works with Claude Max and Pro subscriptions."
    exit 1
fi
echo -e "  ${GREEN}✓${NC} OAuth token found"

# Check subscription type
SUB_TYPE=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.subscriptionType // "unknown"' 2>/dev/null)
echo -e "  ${GREEN}✓${NC} Subscription: ${GREEN}${SUB_TYPE}${NC}"

# Create .claude directory if needed
mkdir -p "$CLAUDE_DIR"

# Download scripts
echo ""
echo -e "${BLUE}Downloading scripts...${NC}"

# Audit L1: don't silently overwrite user-edited probe/statusline. If the local
# file exists and differs from the upstream version, write the upstream copy
# to a sidecar `.upstream-new` and let the user reconcile by hand. This mirrors
# the .new pattern used by setup-security.sh for ~/.claude/CLAUDE.md.
download_with_sidecar() {
    local rel_url="$1" dest="$2" label="$3"
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/$(basename "$dest").XXXXXX")
    if ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$rel_url" -o "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        echo -e "  ${RED}✗${NC} Failed to download $label"
        return 1
    fi
    if [ -f "$dest" ] && ! cmp -s "$dest" "$tmp"; then
        # User has edited (or older toolkit version differs) — preserve theirs.
        local sidecar="${dest}.upstream-new"
        # Stamp prior reconciliation if user has not yet merged a previous run.
        if [ -f "$sidecar" ] && ! cmp -s "$sidecar" "$tmp"; then
            mv "$sidecar" "${sidecar}.$(date -u +%s)" 2>/dev/null || true
        fi
        mv "$tmp" "$sidecar"
        chmod +x "$sidecar"
        echo -e "  ${YELLOW}⚠${NC} $label differs from your local copy"
        echo -e "       Upstream written to: $sidecar"
        echo -e "       Diff:  diff -u \"$dest\" \"$sidecar\""
        echo -e "       Apply: mv \"$sidecar\" \"$dest\""
        return 0
    fi
    mv "$tmp" "$dest"
    chmod +x "$dest"
    echo -e "  ${GREEN}✓${NC} $label"
}

if ! download_with_sidecar "templates/global/rate-limit-probe.sh" \
        "$CLAUDE_DIR/rate-limit-probe.sh" "rate-limit-probe.sh"; then
    exit 1
fi

if ! download_with_sidecar "templates/global/statusline.sh" \
        "$CLAUDE_DIR/statusline.sh" "statusline.sh"; then
    exit 1
fi

# Configure settings.json
echo ""
echo -e "${BLUE}Configuring statusLine in settings...${NC}"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Audit M3: atomic settings.json merge with one backup per run.
# Previous code did `UPDATED=$(jq ...); echo "$UPDATED" > "$SETTINGS_FILE"` — a SIGINT
# between the two could truncate settings.json to zero bytes, and no backup was taken
# before overwrite. Now: backup_settings_once + python3 mkstemp+os.replace (POSIX atomic).
merge_statusline_python() {
    local settings_path="$1"
    python3 - "$settings_path" <<'PYEOF'
import json, os, sys, tempfile
settings_path = sys.argv[1]
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError:
            sys.exit(2)
else:
    config = {}
config['statusLine'] = {'type': 'command', 'command': '~/.claude/statusline.sh'}
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

if [ -f "$SETTINGS_FILE" ]; then
    # backup_settings_once: one .bak.<epoch> per run (no-op if already taken).
    if command -v backup_settings_once >/dev/null 2>&1; then
        backup_settings_once "$SETTINGS_FILE"
    else
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak.$(date +%s)"
    fi

    if command -v python3 &>/dev/null; then
        if merge_statusline_python "$SETTINGS_FILE"; then
            echo -e "  ${GREEN}✓${NC} Updated existing settings.json (atomic merge, backup retained)"
        else
            rc=$?
            if [[ $rc -eq 2 ]]; then
                echo -e "  ${YELLOW}⚠${NC} settings.json was not valid JSON — leaving original; backup at .bak.<epoch>"
                exit 1
            fi
            echo -e "  ${RED}✗${NC} JSON merge failed — backup retained at ${SETTINGS_FILE}.bak.<epoch>"
            exit 1
        fi
    else
        # Fallback: jq-based merge using temp + atomic rename. No naked redirect.
        TMP_OUT=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")
        if jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS_FILE" > "$TMP_OUT" 2>/dev/null \
                && [ -s "$TMP_OUT" ]; then
            mv "$TMP_OUT" "$SETTINGS_FILE"
            echo -e "  ${GREEN}✓${NC} Updated existing settings.json (jq atomic, backup retained)"
        else
            rm -f "$TMP_OUT"
            echo -e "  ${RED}✗${NC} Could not parse settings.json — original preserved (backup at .bak.<epoch>)"
            exit 1
        fi
    fi
else
    # Atomic create via tempfile + rename to avoid partial-file race on SIGINT.
    TMP_NEW=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")
    printf '%s\n' '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' > "$TMP_NEW"
    mv "$TMP_NEW" "$SETTINGS_FILE"
    echo -e "  ${GREEN}✓${NC} Created settings.json"
fi

# Run initial probe
echo ""
echo -e "${BLUE}Running initial rate limit check...${NC}"

# Audit H3: probe + statusline use ${TMPDIR:-/tmp}; on macOS TMPDIR is per-user
# (/var/folders/.../T/). Hardcoded /tmp here always missed the file the probe
# just produced — installer always reported "Initial probe failed" on macOS.
CACHE_FILE="${TMPDIR:-/tmp}/claude-rate-limits.json"

# Remove cache to force fresh probe
rm -f "$CACHE_FILE"

if bash "$CLAUDE_DIR/rate-limit-probe.sh" 2>/dev/null; then
    if [ -f "$CACHE_FILE" ]; then
        ERR=$(jq -r '.error // empty' "$CACHE_FILE" 2>/dev/null)
        if [ -z "$ERR" ]; then
            S_PCT=$(jq -r '.session_pct' "$CACHE_FILE" 2>/dev/null)
            W_PCT=$(jq -r '.weekly_pct' "$CACHE_FILE" 2>/dev/null)
            echo -e "  ${GREEN}✓${NC} Session (5h): ${S_PCT}%"
            echo -e "  ${GREEN}✓${NC} Weekly  (7d): ${W_PCT}%"
        else
            echo -e "  ${YELLOW}⚠${NC} Probe returned error: ${ERR}"
            echo -e "  Rate limits will appear after first Claude Code session."
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Initial probe failed. Will retry automatically."
fi

# Done
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Statusline installed successfully!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Start or restart Claude Code to see your usage in the status bar:"
echo ""
echo -e "  ${YELLOW}25% | 5h:23% (2h57m) | 7d:16% (5d3h)${NC}"
echo -e "   │      │                  │"
echo -e "   │      │                  └─ weekly limit (7-day window)"
echo -e "   │      └─ session limit (5-hour window)"
echo -e "   └─ context window usage"
echo ""
echo -e "Colors: no color (<60%), ${YELLOW}yellow${NC} (60-79%), ${RED}red${NC} (80-100%)"
echo ""
