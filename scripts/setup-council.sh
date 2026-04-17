#!/bin/bash

# Supreme Council Setup Script
# Installs multi-AI code review system (Gemini + ChatGPT)
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR="$HOME/.claude"
COUNCIL_DIR="$CLAUDE_DIR/council"

# Guard: exit cleanly when stdin is not a terminal (CI / curl | bash without pty)
if [[ ! -r /dev/tty ]]; then
    echo -e "${RED}✗${NC} This script requires an interactive terminal."
    echo -e "  Run it directly (or via \`bash <(curl -sSL ...)\`), not \`curl | bash\`."
    exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Supreme Council Setup                     ║${NC}"
echo -e "${BLUE}║     Multi-AI Code Review (Gemini + ChatGPT)   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────
# Step 1: Check dependencies
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 1: Checking dependencies${NC}"

# Python 3.8+
if ! command -v python3 &>/dev/null; then
    echo -e "  ${RED}✗${NC} Python 3 not found"
    echo -e "  Install: brew install python3 (macOS) or sudo apt install python3 (Linux)"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [[ "$PYTHON_MAJOR" -lt 3 ]] || { [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -lt 8 ]]; }; then
    echo -e "  ${RED}✗${NC} Python 3.8+ required, found $PYTHON_VERSION"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Python $PYTHON_VERSION"

# curl
if ! command -v curl &>/dev/null; then
    echo -e "  ${RED}✗${NC} curl not found (required for API calls)"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} curl"

# tree (auto-install if missing)
if ! command -v tree &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} tree not found, installing..."
    if command -v brew &>/dev/null; then
        brew install tree 2>/dev/null
        echo -e "  ${GREEN}✓${NC} tree installed via Homebrew"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq tree 2>/dev/null
        echo -e "  ${GREEN}✓${NC} tree installed via apt"
    else
        echo -e "  ${YELLOW}⚠${NC} Could not install tree automatically"
        echo -e "  Install manually: https://mama.indstate.edu/users/ice/tree/"
        echo -e "  Supreme Council will work but without project structure analysis"
    fi
else
    echo -e "  ${GREEN}✓${NC} tree"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 2: Gemini setup
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 2: Gemini configuration${NC}"
echo ""
echo -e "  Choose Gemini access method:"
echo -e "    ${GREEN}1)${NC} Gemini CLI — free with Google subscription (recommended)"
echo -e "    ${YELLOW}2)${NC} Gemini API — requires API key from AI Studio"
echo ""

GEMINI_MODE="cli"
GEMINI_KEY=""

if ! read -r -p "  Enter choice [1/2] (default: 1): " GEMINI_CHOICE < /dev/tty 2>/dev/null; then
    GEMINI_CHOICE="1"
fi
GEMINI_CHOICE="${GEMINI_CHOICE:-1}"

if [[ "$GEMINI_CHOICE" == "2" ]]; then
    GEMINI_MODE="api"
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        GEMINI_KEY="$GEMINI_API_KEY"
        echo -e "  ${GREEN}✓${NC} GEMINI_API_KEY found in environment"
    else
        echo -e "  ${YELLOW}⚠${NC} GEMINI_API_KEY not set in environment"
        read -rs -p "  Enter Gemini API key (or press Enter to skip): " GEMINI_KEY < /dev/tty 2>/dev/null || true
        echo ""
        if [[ -z "$GEMINI_KEY" ]]; then
            echo -e "  ${YELLOW}⚠${NC} You'll need to add it later to config.json"
        fi
    fi
else
    echo -e "  ${BLUE}→${NC} Gemini CLI selected"
    if ! command -v gemini &>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Gemini CLI not found. Install:"
        echo -e "    npm install -g @google/gemini-cli"
        echo -e "    Then run: gemini login"
    else
        echo -e "  ${GREEN}✓${NC} Gemini CLI found"
    fi
fi

echo ""

# ─────────────────────────────────────────────────
# Step 3: OpenAI setup
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 3: OpenAI (ChatGPT) configuration${NC}"

OPENAI_KEY=""

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    OPENAI_KEY="$OPENAI_API_KEY"
    echo -e "  ${GREEN}✓${NC} OPENAI_API_KEY found in environment"
else
    echo -e "  ${YELLOW}⚠${NC} OPENAI_API_KEY not set in environment"
    read -rs -p "  Enter OpenAI API key (or press Enter to skip): " OPENAI_KEY < /dev/tty 2>/dev/null || true
    echo ""
    if [[ -z "$OPENAI_KEY" ]]; then
        echo -e "  ${YELLOW}⚠${NC} You'll need to add it later to config.json"
        echo -e "  Get key: https://platform.openai.com/api-keys"
    fi
fi

echo ""

# ─────────────────────────────────────────────────
# Step 4: Install files
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 4: Installing Supreme Council${NC}"

mkdir -p "$COUNCIL_DIR"

# Download brain.py
if curl -sSL "$REPO_URL/scripts/council/brain.py" -o "$COUNCIL_DIR/brain.py" 2>/dev/null; then
    chmod +x "$COUNCIL_DIR/brain.py"
    echo -e "  ${GREEN}✓${NC} brain.py"
else
    echo -e "  ${RED}✗${NC} Failed to download brain.py"
    exit 1
fi

# Download README
curl -sSL "$REPO_URL/scripts/council/README.md" -o "$COUNCIL_DIR/README.md" 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} README.md" || \
    echo -e "  ${YELLOW}⚠${NC} README.md (not critical)"

echo ""

# ─────────────────────────────────────────────────
# Step 5: Create config
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 5: Creating configuration${NC}"

CONFIG_FILE="$COUNCIL_DIR/config.json"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  ${YELLOW}⚠${NC} config.json already exists, preserving"
else
    cat > "$CONFIG_FILE" << CONFIGEOF
{
  "gemini": {
    "mode": "$GEMINI_MODE",
    "api_key": "$GEMINI_KEY",
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": "$OPENAI_KEY",
    "model": "gpt-5.2"
  }
}
CONFIGEOF
    chmod 600 "$CONFIG_FILE"
    echo -e "  ${GREEN}✓${NC} config.json created (permissions: owner-only)"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 6: Shell alias
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 6: Shell alias${NC}"

ALIAS_LINE="alias brain='python3 $COUNCIL_DIR/brain.py'"

# Detect shell config file
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -f "$SHELL_RC" ]] && grep -q "alias brain=" "$SHELL_RC" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Alias already exists in $SHELL_RC"
else
    {
        echo ""
        echo "# Supreme Council — multi-AI code review"
        echo "$ALIAS_LINE"
    } >> "$SHELL_RC"
    echo -e "  ${GREEN}✓${NC} Added alias 'brain' to $SHELL_RC"
    echo -e "  Run: ${YELLOW}source $SHELL_RC${NC} to activate"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 7: Verification
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 7: Verification${NC}"

PASS=0
FAIL=0

# Check brain.py
if [[ -f "$COUNCIL_DIR/brain.py" ]]; then
    echo -e "  ${GREEN}✓${NC} brain.py installed"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} brain.py missing"
    FAIL=$((FAIL + 1))
fi

# Check config
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  ${GREEN}✓${NC} config.json exists"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} config.json missing"
    FAIL=$((FAIL + 1))
fi

# Check Python can parse brain.py
if python3 -c "import ast; ast.parse(open('$COUNCIL_DIR/brain.py').read())" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} brain.py syntax valid"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} brain.py has syntax errors"
    FAIL=$((FAIL + 1))
fi

# Check tree
if command -v tree &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} tree available"
    PASS=$((PASS + 1))
else
    echo -e "  ${YELLOW}~${NC} tree not available (optional)"
fi

echo ""

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Supreme Council installed ($PASS/$PASS passed)      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     Partially installed ($PASS passed, $FAIL failed)    ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BLUE}What was installed:${NC}"
echo -e "  1. ${GREEN}Orchestrator${NC}  — ~/.claude/council/brain.py"
echo -e "  2. ${GREEN}Configuration${NC} — ~/.claude/council/config.json"
echo -e "  3. ${GREEN}Shell alias${NC}   — brain → python3 ~/.claude/council/brain.py"
echo ""

# Show next steps if keys are missing
NEEDS_SETUP=false
if [[ -z "$OPENAI_KEY" ]]; then
    NEEDS_SETUP=true
fi
if [[ "$GEMINI_MODE" == "api" ]] && [[ -z "$GEMINI_KEY" ]]; then
    NEEDS_SETUP=true
fi

if [[ "$NEEDS_SETUP" == true ]]; then
    echo -e "${YELLOW}Action required:${NC}"
    if [[ -z "$OPENAI_KEY" ]]; then
        echo -e "  Add OpenAI key to $CONFIG_FILE"
        echo -e "  Or: ${CYAN}export OPENAI_API_KEY=\"sk-...\"${NC}"
    fi
    if [[ "$GEMINI_MODE" == "api" ]] && [[ -z "$GEMINI_KEY" ]]; then
        echo -e "  Add Gemini key to $CONFIG_FILE"
        echo -e "  Or: ${CYAN}export GEMINI_API_KEY=\"...\"${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}Usage:${NC}"
echo -e "  ${YELLOW}brain \"add OAuth login with Google\"${NC}"
echo -e "  Or in Claude Code: ${YELLOW}/council add OAuth login with Google${NC}"
echo ""
