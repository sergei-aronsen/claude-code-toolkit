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
COMMANDS_DIR="$CLAUDE_DIR/commands"

# Guard: exit cleanly when stdin is not a terminal (CI / curl | bash without pty)
if [[ ! -r /dev/tty ]]; then
    echo -e "${RED}✗${NC} This script requires an interactive terminal."
    echo -e "  Run it directly (or via \`bash <(curl -sSL ...)\`), not \`curl | bash\`."
    exit 1
fi

# Source cli-recommendations helper (Phase 24 Sub-Phase 1).
# Test seam: TK_COUNCIL_LIB_DIR=<path> uses local copies (init-local.sh / hermetic tests).
LIB_CLI_TMP=$(mktemp "${TMPDIR:-/tmp}/cli-recommendations.XXXXXX")
LIB_PROMPTS_TMP=$(mktemp "${TMPDIR:-/tmp}/council-prompts.XXXXXX")
trap 'rm -f "$LIB_CLI_TMP" "$LIB_PROMPTS_TMP"' EXIT

if [[ -n "${TK_COUNCIL_LIB_DIR:-}" && -f "$TK_COUNCIL_LIB_DIR/cli-recommendations.sh" ]]; then
    cp "$TK_COUNCIL_LIB_DIR/cli-recommendations.sh" "$LIB_CLI_TMP"
    # shellcheck source=/dev/null
    source "$LIB_CLI_TMP"
elif curl -sSLf "$REPO_URL/scripts/lib/cli-recommendations.sh" -o "$LIB_CLI_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$LIB_CLI_TMP"
else
    echo -e "${YELLOW}⚠${NC} Could not fetch cli-recommendations.sh — skipping CLI hints"
    recommend_clis() { :; }
fi

# Source council-prompts helper (Phase 24 Sub-Phase 2).
if [[ -n "${TK_COUNCIL_LIB_DIR:-}" && -f "$TK_COUNCIL_LIB_DIR/council-prompts.sh" ]]; then
    cp "$TK_COUNCIL_LIB_DIR/council-prompts.sh" "$LIB_PROMPTS_TMP"
    # shellcheck source=/dev/null
    source "$LIB_PROMPTS_TMP"
elif curl -sSLf "$REPO_URL/scripts/lib/council-prompts.sh" -o "$LIB_PROMPTS_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$LIB_PROMPTS_TMP"
else
    echo -e "${YELLOW}⚠${NC} Could not fetch council-prompts.sh — skipping system-prompt install"
    install_council_system_prompts() { :; }
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
        echo -e "  ${YELLOW}⚠${NC} tree not found. Install it manually if you want project structure analysis:"
        echo -e "      sudo apt-get install tree"
        echo -e "  Supreme Council will work without it — structure analysis will be skipped."
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
# Step 1b: Provider CLI recommendations (informational)
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 1b: Provider CLI availability${NC}"
recommend_clis
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
echo ""
echo -e "  Choose OpenAI access method:"
echo -e "    ${GREEN}1)${NC} Codex CLI — free with ChatGPT Plus/Pro subscription (recommended)"
echo -e "    ${YELLOW}2)${NC} OpenAI API — requires API key from platform.openai.com"
echo ""

OPENAI_MODE="api"
OPENAI_KEY=""

if ! read -r -p "  Enter choice [1/2] (default: 1 if codex on PATH, else 2): " OPENAI_CHOICE < /dev/tty 2>/dev/null; then
    OPENAI_CHOICE=""
fi
if [[ -z "$OPENAI_CHOICE" ]]; then
    OPENAI_CHOICE=$(command -v codex >/dev/null 2>&1 && echo "1" || echo "2")
fi

if [[ "$OPENAI_CHOICE" == "1" ]]; then
    OPENAI_MODE="cli"
    if ! command -v codex &>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Codex CLI not found. Install:"
        echo -e "      npm install -g @openai/codex   # or: brew install --cask codex"
        echo -e "      codex login"
    else
        echo -e "  ${GREEN}✓${NC} Codex CLI found"
    fi
elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
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
# Step 3b: OpenRouter fallback (optional)
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 3b: OpenRouter free-tier fallback (optional)${NC}"
echo -e "  When the primary backend fails (quota / 5xx / network), Council can"
echo -e "  retry through a free-model chain on OpenRouter. Skip if you only want"
echo -e "  to use the primary providers configured above."
echo ""

OPENROUTER_KEY=""
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    OPENROUTER_KEY="$OPENROUTER_API_KEY"
    echo -e "  ${GREEN}✓${NC} OPENROUTER_API_KEY found in environment"
else
    read -rs -p "  Enter OpenRouter API key (or press Enter to skip): " OPENROUTER_KEY < /dev/tty 2>/dev/null || true
    echo ""
    if [[ -z "$OPENROUTER_KEY" ]]; then
        echo -e "  ${YELLOW}⚠${NC} OpenRouter fallback disabled — Council still works with primary only."
    else
        echo -e "  ${GREEN}✓${NC} OpenRouter fallback configured"
    fi
fi

echo ""

# ─────────────────────────────────────────────────
# Step 4: Install files
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 4: Installing Supreme Council${NC}"

mkdir -p "$COUNCIL_DIR"

# Download brain.py
if curl -sSLf "$REPO_URL/scripts/council/brain.py" -o "$COUNCIL_DIR/brain.py" 2>/dev/null; then
    chmod +x "$COUNCIL_DIR/brain.py"
    echo -e "  ${GREEN}✓${NC} brain.py"
else
    rm -f "$COUNCIL_DIR/brain.py"
    echo -e "  ${RED}✗${NC} Failed to download brain.py"
    exit 1
fi

# Download README
if curl -sSLf "$REPO_URL/scripts/council/README.md" -o "$COUNCIL_DIR/README.md" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} README.md"
else
    rm -f "$COUNCIL_DIR/README.md"
    echo -e "  ${YELLOW}⚠${NC} README.md (not critical)"
fi

# Download audit-review.md prompt (Phase 17 — DIST-01 / D-04)
# Idempotent + mtime-aware: only overwrites if upstream is newer than local copy.
# NOTE: --force flag (to unconditionally overwrite) is deferred to a future hardening pass.
mkdir -p "$COUNCIL_DIR/prompts"
if curl -sSLf "$REPO_URL/scripts/council/prompts/audit-review.md" \
        -o "$COUNCIL_DIR/prompts/audit-review.md.tmp" 2>/dev/null; then
    if [ ! -f "$COUNCIL_DIR/prompts/audit-review.md" ]; then
        mv "$COUNCIL_DIR/prompts/audit-review.md.tmp" "$COUNCIL_DIR/prompts/audit-review.md"
        echo -e "  ${GREEN}✓${NC} prompts/audit-review.md"
    elif [ "$COUNCIL_DIR/prompts/audit-review.md.tmp" -nt "$COUNCIL_DIR/prompts/audit-review.md" ]; then
        mv "$COUNCIL_DIR/prompts/audit-review.md.tmp" "$COUNCIL_DIR/prompts/audit-review.md"
        echo -e "  ${GREEN}✓${NC} prompts/audit-review.md (refreshed)"
    else
        rm -f "$COUNCIL_DIR/prompts/audit-review.md.tmp"
        echo -e "  ${GREEN}✓${NC} prompts/audit-review.md (already current)"
    fi
else
    rm -f "$COUNCIL_DIR/prompts/audit-review.md.tmp"
    echo -e "  ${YELLOW}⚠${NC} audit-review.md (not critical)"
fi

# Install editable system prompts (Phase 24 Sub-Phase 2).
# Skeptic / Pragmatist / audit-review pair land in ~/.claude/council/prompts/.
# brain.py reads them via load_prompt() and falls back to embedded constants
# when files are missing.
install_council_system_prompts

# Install redaction-patterns.txt (Phase 24 Sub-Phase 3) so brain.py can
# augment its built-in DEFAULT_REDACTION_PATTERNS with project-specific
# secret shapes. User edits preserved via .upstream-new.txt sidecar.
install_council_redaction_patterns

# Install pricing.json (Phase 24 Sub-Phase 4) so brain.py can compute
# accurate $ cost per call for /council stats. User edits preserved via
# .upstream-new.json sidecar.
install_council_pricing

# Install /council slash command globally (Phase 24 Sub-Phase 1).
# Same idempotent + mtime-aware pattern as audit-review.md above. Council is
# a global feature — its slash command lives in ~/.claude/commands/, not in
# per-project ./.claude/commands/ (where it duplicated effort across every
# project that ran init-claude.sh).
mkdir -p "$COMMANDS_DIR"
if curl -sSLf "$REPO_URL/commands/council.md" \
        -o "$COMMANDS_DIR/council.md.tmp" 2>/dev/null; then
    if [ ! -f "$COMMANDS_DIR/council.md" ]; then
        mv "$COMMANDS_DIR/council.md.tmp" "$COMMANDS_DIR/council.md"
        echo -e "  ${GREEN}✓${NC} commands/council.md installed (global)"
    elif [ "$COMMANDS_DIR/council.md.tmp" -nt "$COMMANDS_DIR/council.md" ]; then
        mv "$COMMANDS_DIR/council.md.tmp" "$COMMANDS_DIR/council.md"
        echo -e "  ${GREEN}✓${NC} commands/council.md (refreshed)"
    else
        rm -f "$COMMANDS_DIR/council.md.tmp"
        echo -e "  ${GREEN}✓${NC} commands/council.md (already current)"
    fi
else
    rm -f "$COMMANDS_DIR/council.md.tmp"
    echo -e "  ${YELLOW}⚠${NC} commands/council.md (not critical)"
fi

# Install /council-stats slash command globally (Phase 24 Sub-Phase 4).
if curl -sSLf "$REPO_URL/commands/council-stats.md" \
        -o "$COMMANDS_DIR/council-stats.md.tmp" 2>/dev/null; then
    if [ ! -f "$COMMANDS_DIR/council-stats.md" ]; then
        mv "$COMMANDS_DIR/council-stats.md.tmp" "$COMMANDS_DIR/council-stats.md"
        echo -e "  ${GREEN}✓${NC} commands/council-stats.md installed (global)"
    elif [ "$COMMANDS_DIR/council-stats.md.tmp" -nt "$COMMANDS_DIR/council-stats.md" ]; then
        mv "$COMMANDS_DIR/council-stats.md.tmp" "$COMMANDS_DIR/council-stats.md"
        echo -e "  ${GREEN}✓${NC} commands/council-stats.md (refreshed)"
    else
        rm -f "$COMMANDS_DIR/council-stats.md.tmp"
        echo -e "  ${GREEN}✓${NC} commands/council-stats.md (already current)"
    fi
else
    rm -f "$COMMANDS_DIR/council-stats.md.tmp"
    echo -e "  ${YELLOW}⚠${NC} commands/council-stats.md (not critical)"
fi

# Install /council clear-cache slash command globally (Phase 24 Sub-Phase 6).
if curl -sSLf "$REPO_URL/commands/council-clear-cache.md" \
        -o "$COMMANDS_DIR/council-clear-cache.md.tmp" 2>/dev/null; then
    if [ ! -f "$COMMANDS_DIR/council-clear-cache.md" ]; then
        mv "$COMMANDS_DIR/council-clear-cache.md.tmp" "$COMMANDS_DIR/council-clear-cache.md"
        echo -e "  ${GREEN}✓${NC} commands/council-clear-cache.md installed (global)"
    elif [ "$COMMANDS_DIR/council-clear-cache.md.tmp" -nt "$COMMANDS_DIR/council-clear-cache.md" ]; then
        mv "$COMMANDS_DIR/council-clear-cache.md.tmp" "$COMMANDS_DIR/council-clear-cache.md"
        echo -e "  ${GREEN}✓${NC} commands/council-clear-cache.md (refreshed)"
    else
        rm -f "$COMMANDS_DIR/council-clear-cache.md.tmp"
        echo -e "  ${GREEN}✓${NC} commands/council-clear-cache.md (already current)"
    fi
else
    rm -f "$COMMANDS_DIR/council-clear-cache.md.tmp"
    echo -e "  ${YELLOW}⚠${NC} commands/council-clear-cache.md (not critical)"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 5: Create config
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 5: Creating configuration${NC}"

CONFIG_FILE="$COUNCIL_DIR/config.json"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  ${YELLOW}⚠${NC} config.json already exists, preserving"
else
    # BUG-03: JSON-escape key values so literal `"`, `\`, newline in keys do not break JSON
    # shellcheck disable=SC2016
    GEMINI_MODE_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GEMINI_MODE")
    # shellcheck disable=SC2016
    GEMINI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GEMINI_KEY")
    # shellcheck disable=SC2016
    OPENAI_MODE_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$OPENAI_MODE")
    # shellcheck disable=SC2016
    OPENAI_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$OPENAI_KEY")
    # shellcheck disable=SC2016
    OPENROUTER_KEY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$OPENROUTER_KEY")

    cat > "$CONFIG_FILE" << CONFIGEOF
{
  "gemini": {
    "mode": $GEMINI_MODE_JSON,
    "api_key": $GEMINI_KEY_JSON,
    "model": "gemini-3-pro-preview",
    "thinking_budget": 32768
  },
  "openai": {
    "mode": $OPENAI_MODE_JSON,
    "api_key": $OPENAI_KEY_JSON,
    "model": "gpt-5.2",
    "reasoning_effort": "high",
    "cli_reasoning_effort": "high"
  },
  "fallback": {
    "openrouter": {
      "api_key": $OPENROUTER_KEY_JSON,
      "models": [
        "tencent/hy3-preview:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "inclusionai/ling-2.6-1t:free",
        "openrouter/free"
      ]
    }
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

# Check global slash command (Phase 24 Sub-Phase 1)
if [[ -f "$COMMANDS_DIR/council.md" ]]; then
    echo -e "  ${GREEN}✓${NC} commands/council.md installed (global)"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} commands/council.md missing"
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
# shellcheck disable=SC2016
if python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' \
    "$COUNCIL_DIR/brain.py" 2>/dev/null; then
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
echo -e "  3. ${GREEN}Slash command${NC} — ~/.claude/commands/council.md (global)"
echo -e "  4. ${GREEN}Shell alias${NC}   — brain → python3 ~/.claude/council/brain.py"
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
