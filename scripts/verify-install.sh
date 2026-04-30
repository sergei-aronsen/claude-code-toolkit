#!/bin/bash

# Claude Code Toolkit — Installation Verification
# Checks all components: toolkit, security, plugins, statusline, council
#
# Usage:
#   bash .claude/scripts/verify-install.sh
#   Or: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/verify-install.sh)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Helper functions
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "  ${YELLOW}~${NC} $1"
    WARN=$((WARN + 1))
}

skip() {
    echo -e "  ${DIM}-${NC} ${DIM}$1${NC}"
}

section() {
    echo ""
    echo -e "${CYAN}$1${NC}"
}

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Claude Code Toolkit — Verification          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"

# ─────────────────────────────────────────────────
# 1. Project Toolkit (.claude/ in current directory)
# ─────────────────────────────────────────────────

section "1. Project Toolkit (.claude/)"

CLAUDE_DIR=".claude"

if [[ -d "$CLAUDE_DIR" ]]; then
    pass "Directory .claude/ exists"
else
    fail "Directory .claude/ not found — run init-claude.sh first"
fi

if [[ -f "CLAUDE.md" ]] || [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    pass "CLAUDE.md found"
else
    fail "CLAUDE.md not found"
fi

# Commands
if [[ -d "$CLAUDE_DIR/commands" ]]; then
    CMD_COUNT=$(find "$CLAUDE_DIR/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$CMD_COUNT" -gt 0 ]]; then
        pass "Commands: $CMD_COUNT slash commands installed"
    else
        fail "Commands directory exists but empty"
    fi
else
    fail "Commands directory not found"
fi

# Agents
if [[ -d "$CLAUDE_DIR/agents" ]]; then
    AGENT_COUNT=$(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$AGENT_COUNT" -gt 0 ]]; then
        pass "Agents: $AGENT_COUNT agents installed"
    else
        fail "Agents directory exists but empty"
    fi
else
    fail "Agents directory not found"
fi

# Prompts
if [[ -d "$CLAUDE_DIR/prompts" ]]; then
    PROMPT_COUNT=$(find "$CLAUDE_DIR/prompts" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PROMPT_COUNT" -gt 0 ]]; then
        pass "Prompts: $PROMPT_COUNT prompts installed"
    else
        warn "Prompts directory exists but empty"
    fi
else
    warn "Prompts directory not found (optional)"
fi

# Skills
if [[ -d "$CLAUDE_DIR/skills" ]]; then
    SKILL_COUNT=$(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$SKILL_COUNT" -gt 0 ]]; then
        pass "Skills: $SKILL_COUNT skills installed"
    else
        warn "Skills directory exists but no SKILL.md files"
    fi
else
    warn "Skills directory not found (optional)"
fi

# Rules
if [[ -d "$CLAUDE_DIR/rules" ]]; then
    pass "Rules directory exists (auto-loaded context)"
else
    warn "Rules directory not found (optional)"
fi

# ─────────────────────────────────────────────────
# 2. Global Security (~/.claude/)
# ─────────────────────────────────────────────────

section "2. Global Security (~/.claude/)"

GLOBAL_DIR="$HOME/.claude"
GLOBAL_MD="$GLOBAL_DIR/CLAUDE.md"
SETTINGS_JSON="$GLOBAL_DIR/settings.json"

# Global CLAUDE.md
if [[ -f "$GLOBAL_MD" ]]; then
    if grep -q "Global Security Rules" "$GLOBAL_MD" 2>/dev/null; then
        pass "Global security rules installed"
    else
        warn "$GLOBAL_MD exists but no security rules section"
    fi
else
    fail "$GLOBAL_MD not found — run setup-security.sh"
fi

# safety-net
if command -v cc-safety-net &>/dev/null; then
    VERSION=$(cc-safety-net --version 2>/dev/null || echo "unknown")
    pass "cc-safety-net installed (v$VERSION)"

    # Test blocking
    TEST_RESULT=$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | cc-safety-net --claude-code 2>/dev/null || true)
    if echo "$TEST_RESULT" | grep -q "deny" 2>/dev/null; then
        pass "cc-safety-net blocks destructive commands"
    else
        warn "cc-safety-net did not block test command (may need update)"
    fi
else
    fail "cc-safety-net not installed — run: npm install -g cc-safety-net"
fi

# PreToolUse hook
if [[ -f "$SETTINGS_JSON" ]]; then
    if grep -q "pre-bash.sh" "$SETTINGS_JSON" 2>/dev/null; then
        pass "Combined PreToolUse hook configured (safety-net + RTK)"

        # Check if the hook file exists and is executable
        HOOK_PATH=$(grep -o '[^"]*pre-bash.sh' "$SETTINGS_JSON" 2>/dev/null | head -1)
        HOOK_PATH="${HOOK_PATH/#\~/$HOME}"
        if [[ -x "$HOOK_PATH" ]]; then
            pass "pre-bash.sh exists and is executable"
        elif [[ -f "$HOOK_PATH" ]]; then
            warn "pre-bash.sh exists but not executable — run: chmod +x $HOOK_PATH"
        else
            fail "pre-bash.sh not found at $HOOK_PATH"
        fi
    elif grep -q "cc-safety-net" "$SETTINGS_JSON" 2>/dev/null; then
        warn "Legacy safety-net hook (upgrade to combined hook with setup-security.sh)"
    else
        fail "PreToolUse hook missing in settings.json"
    fi
else
    fail "$SETTINGS_JSON not found — run setup-security.sh"
fi

# ─────────────────────────────────────────────────
# 3. Official Anthropic Plugins
# ─────────────────────────────────────────────────

section "3. Official Anthropic Plugins"

PLUGINS=(
    "code-review@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "security-guidance@claude-plugins-official"
    "frontend-design@claude-plugins-official"
)

PLUGIN_LABELS=(
    "code-review        — /code-review for PR review"
    "commit-commands     — /commit, /commit-push-pr, /clean_gone"
    "security-guidance   — PreToolUse security warnings"
    "frontend-design     — auto-activates for frontend work"
)

if [[ -f "$SETTINGS_JSON" ]] && grep -q "enabledPlugins" "$SETTINGS_JSON" 2>/dev/null; then
    for i in "${!PLUGINS[@]}"; do
        if grep -q "${PLUGINS[$i]}" "$SETTINGS_JSON" 2>/dev/null; then
            pass "${PLUGIN_LABELS[$i]}"
        else
            fail "${PLUGIN_LABELS[$i]} — not enabled"
        fi
    done
else
    fail "enabledPlugins not found in settings.json — run setup-security.sh"
fi

# ─────────────────────────────────────────────────
# 4. Rate Limit Statusline (optional)
# ─────────────────────────────────────────────────

section "4. Rate Limit Statusline (optional)"

if [[ -f "$SETTINGS_JSON" ]] && grep -q "statusLine" "$SETTINGS_JSON" 2>/dev/null; then
    pass "Statusline configured in settings.json"

    # Check if the script exists
    STATUSLINE_SCRIPT="$GLOBAL_DIR/statusline.sh"
    if [[ -f "$STATUSLINE_SCRIPT" ]]; then
        if [[ -x "$STATUSLINE_SCRIPT" ]]; then
            pass "statusline.sh exists and is executable"
        else
            warn "statusline.sh exists but not executable — run: chmod +x $STATUSLINE_SCRIPT"
        fi
    else
        warn "statusline.sh not found at $STATUSLINE_SCRIPT"
    fi

    # Check jq dependency
    if command -v jq &>/dev/null; then
        pass "jq installed (required for statusline)"
    else
        fail "jq not installed — run: brew install jq"
    fi
else
    skip "Statusline not configured (optional) — install with install-statusline.sh"
fi

# ─────────────────────────────────────────────────
# 5. Supreme Council (optional)
# ─────────────────────────────────────────────────

section "5. Supreme Council (optional)"

COUNCIL_DIR="$GLOBAL_DIR/council"
GLOBAL_COMMANDS_DIR="$GLOBAL_DIR/commands"

if [[ -f "$COUNCIL_DIR/brain.py" ]]; then
    pass "brain.py orchestrator installed"

    # Phase 24 Sub-Phase 1 — orchestrator should be executable so the `brain`
    # shell alias resolves. setup-council.sh chmod +x'es it; warn if drift.
    if [[ -x "$COUNCIL_DIR/brain.py" ]]; then
        pass "brain.py is executable"
    else
        warn "brain.py not executable — run: chmod +x $COUNCIL_DIR/brain.py"
    fi

    # Phase 24 Sub-Phase 1 — global slash command moved out of per-project
    # ./.claude/commands/ to ~/.claude/commands/ in v4.5. Verify it landed.
    if [[ -f "$GLOBAL_COMMANDS_DIR/council.md" ]]; then
        pass "Global /council slash command installed (~/.claude/commands/council.md)"
    else
        fail "Global /council command missing — run: bash <(curl -sSL .../scripts/setup-council.sh)"
    fi

    if [[ -f "$COUNCIL_DIR/config.json" ]]; then
        pass "config.json configured"

        # Verify owner-only permissions on config.json (holds API keys).
        # macOS BSD stat: -f %Lp; GNU stat: -c %a. Try BSD first, fall back.
        CONFIG_PERMS=$(stat -f %Lp "$COUNCIL_DIR/config.json" 2>/dev/null \
            || stat -c %a "$COUNCIL_DIR/config.json" 2>/dev/null \
            || echo "")
        if [[ "$CONFIG_PERMS" == "600" ]]; then
            pass "config.json permissions 0600 (owner-only)"
        elif [[ -n "$CONFIG_PERMS" ]]; then
            warn "config.json permissions are $CONFIG_PERMS (expected 600) — run: chmod 600 $COUNCIL_DIR/config.json"
        fi

        # Check API keys (just presence, not validity)
        if grep -q "gemini" "$COUNCIL_DIR/config.json" 2>/dev/null; then
            pass "Gemini configuration present"
        else
            warn "Gemini configuration missing in config.json"
        fi

        if grep -q "openai\|chatgpt" "$COUNCIL_DIR/config.json" 2>/dev/null; then
            pass "OpenAI/ChatGPT configuration present"
        else
            warn "OpenAI configuration missing in config.json"
        fi
    else
        warn "config.json not found — copy from config.json.template and add API keys"
    fi

    # `brain` shell alias — declared in user's .zshrc / .bash_profile / .bashrc.
    # Detection is lexical (alias declarations are not exported into our shell).
    BRAIN_ALIAS_FOUND=false
    for rc_file in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
        if [[ -f "$rc_file" ]] && grep -q "alias brain=" "$rc_file" 2>/dev/null; then
            BRAIN_ALIAS_FOUND=true
            break
        fi
    done
    if [[ "$BRAIN_ALIAS_FOUND" == "true" ]]; then
        pass "brain shell alias declared"
    else
        warn "brain shell alias not found in .zshrc/.bash_profile/.bashrc"
    fi

    if command -v python3 &>/dev/null; then
        pass "Python 3 available"
    else
        fail "Python 3 not found — required for Supreme Council"
    fi
else
    skip "Supreme Council not installed (optional) — install with setup-council.sh"
fi

# ─────────────────────────────────────────────────
# 6. MCP Servers (optional)
# ─────────────────────────────────────────────────

section "6. MCP Servers (optional)"

# Check global MCP config
MCP_GLOBAL="$GLOBAL_DIR/mcp.json"
MCP_PROJECT=".claude/mcp.json"

MCP_FOUND=false

if [[ -f "$MCP_GLOBAL" ]]; then
    MCP_FOUND=true
    if command -v python3 &>/dev/null; then
        # Audit H2: pass path via argv, not heredoc interpolation.
        # Apostrophes / backslashes in $HOME (e.g. /Users/o'brien) would
        # otherwise break the Python source.
        SERVER_COUNT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
servers = config.get('mcpServers', {})
print(len(servers))
for name in servers:
    print(f'  {name}')
" "$MCP_GLOBAL" 2>/dev/null || echo "0")
        COUNT=$(echo "$SERVER_COUNT" | head -1)
        if [[ "$COUNT" -gt 0 ]]; then
            pass "Global MCP: $COUNT server(s) configured"
            echo "$SERVER_COUNT" | tail -n +2 | while IFS= read -r line; do
                echo -e "    ${DIM}$line${NC}"
            done
        else
            skip "Global MCP config exists but no servers defined"
        fi
    else
        pass "Global MCP config found: $MCP_GLOBAL"
    fi
fi

if [[ -f "$MCP_PROJECT" ]]; then
    MCP_FOUND=true
    if command -v python3 &>/dev/null; then
        # Audit H2: pass path via argv (see MCP_GLOBAL above).
        SERVER_COUNT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
servers = config.get('mcpServers', {})
print(len(servers))
for name in servers:
    print(f'  {name}')
" "$MCP_PROJECT" 2>/dev/null || echo "0")
        COUNT=$(echo "$SERVER_COUNT" | head -1)
        if [[ "$COUNT" -gt 0 ]]; then
            pass "Project MCP: $COUNT server(s) configured"
            echo "$SERVER_COUNT" | tail -n +2 | while IFS= read -r line; do
                echo -e "    ${DIM}$line${NC}"
            done
        else
            skip "Project MCP config exists but no servers defined"
        fi
    else
        pass "Project MCP config found: $MCP_PROJECT"
    fi
fi

if [[ "$MCP_FOUND" == false ]]; then
    skip "No MCP servers configured (optional)"
fi

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [[ $FAIL -eq 0 ]] && [[ $WARN -eq 0 ]]; then
    echo -e "${GREEN}  All checks passed! ($PASS/$PASS)${NC}"
elif [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}  $PASS passed${NC}, ${YELLOW}$WARN warnings${NC}"
else
    echo -e "${GREEN}  $PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}To fix failed checks:${NC}"
    echo -e "  ${CYAN}Toolkit:${NC}    bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)"
    echo -e "  ${CYAN}Security:${NC}   bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)"
    echo -e "  ${CYAN}Statusline:${NC} bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)"
    echo -e "  ${CYAN}Council:${NC}    bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-council.sh)"
fi

echo ""

# Exit with failure if any critical checks failed
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
