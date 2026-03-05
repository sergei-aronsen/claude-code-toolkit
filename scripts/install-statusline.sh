#!/bin/bash

# Claude Code Rate Limit Statusline — Installer
# Usage: curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh | bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR="$HOME/.claude"

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

if curl -sSL "$REPO_URL/templates/global/rate-limit-probe.sh" -o "$CLAUDE_DIR/rate-limit-probe.sh" 2>/dev/null; then
    chmod +x "$CLAUDE_DIR/rate-limit-probe.sh"
    echo -e "  ${GREEN}✓${NC} rate-limit-probe.sh"
else
    echo -e "  ${RED}✗${NC} Failed to download rate-limit-probe.sh"
    exit 1
fi

if curl -sSL "$REPO_URL/templates/global/statusline.sh" -o "$CLAUDE_DIR/statusline.sh" 2>/dev/null; then
    chmod +x "$CLAUDE_DIR/statusline.sh"
    echo -e "  ${GREEN}✓${NC} statusline.sh"
else
    echo -e "  ${RED}✗${NC} Failed to download statusline.sh"
    exit 1
fi

# Configure settings.json
echo ""
echo -e "${BLUE}Configuring statusLine in settings...${NC}"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Merge statusLine into existing settings
    UPDATED=$(jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS_FILE" 2>/dev/null)
    if [ -n "$UPDATED" ]; then
        echo "$UPDATED" > "$SETTINGS_FILE"
        echo -e "  ${GREEN}✓${NC} Updated existing settings.json"
    else
        echo -e "  ${YELLOW}⚠${NC} Could not parse settings.json, creating backup"
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
        echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' > "$SETTINGS_FILE"
        echo -e "  ${GREEN}✓${NC} Created new settings.json (backup: settings.json.bak)"
    fi
else
    echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' > "$SETTINGS_FILE"
    echo -e "  ${GREEN}✓${NC} Created settings.json"
fi

# Run initial probe
echo ""
echo -e "${BLUE}Running initial rate limit check...${NC}"

# Remove cache to force fresh probe
rm -f /tmp/claude-rate-limits.json

if bash "$CLAUDE_DIR/rate-limit-probe.sh" 2>/dev/null; then
    if [ -f /tmp/claude-rate-limits.json ]; then
        ERR=$(jq -r '.error // empty' /tmp/claude-rate-limits.json 2>/dev/null)
        if [ -z "$ERR" ]; then
            S_PCT=$(jq -r '.session_pct' /tmp/claude-rate-limits.json 2>/dev/null)
            W_PCT=$(jq -r '.weekly_pct' /tmp/claude-rate-limits.json 2>/dev/null)
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
