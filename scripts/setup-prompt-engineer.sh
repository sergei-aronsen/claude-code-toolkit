#!/bin/bash

# Prompt Engineer Setup Script
# Installs the single-prompt optimizer.
# Drives Claude Code / Codex / Gemini CLIs via --provider.
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-prompt-engineer.sh)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# TK_TOOLKIT_REF pins to a tag/SHA (default `main`). Mirrors setup-council.sh
# to keep allowlist + curl conventions identical.
TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-v6.47.8}"
if ! [[ "$TK_TOOLKIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$TK_TOOLKIT_REF" == *..* ]]; then
    echo "Error: TK_TOOLKIT_REF must match [A-Za-z0-9._/-]+ and must not contain '..' (got: $TK_TOOLKIT_REF)" >&2
    exit 1
fi
REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/${TK_TOOLKIT_REF}"
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"
export TK_TOOLKIT_REF TK_USER_AGENT

CLAUDE_DIR="$HOME/.claude"
PE_DIR="$CLAUDE_DIR/prompt-engineer"

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Prompt Engineer Setup                     ║${NC}"
echo -e "${CYAN}║     Multi-provider (Claude / Codex / Gemini)  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
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
    echo -e "  ${RED}✗${NC} curl not found"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} curl"

# Provider CLIs — at least one is required at runtime
PROVIDERS_FOUND=0
for cli in claude codex gemini; do
    if command -v "$cli" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $cli CLI found"
        PROVIDERS_FOUND=$((PROVIDERS_FOUND + 1))
    else
        case "$cli" in
            claude)
                echo -e "  ${YELLOW}⚠${NC} claude CLI not found (Claude Code itself)"
                echo -e "      Install: see https://docs.anthropic.com/en/docs/claude-code"
                ;;
            codex)
                echo -e "  ${YELLOW}⚠${NC} codex CLI not found (optional)"
                echo -e "      Install: npm install -g @openai/codex"
                ;;
            gemini)
                echo -e "  ${YELLOW}⚠${NC} gemini CLI not found (optional)"
                echo -e "      Install: npm install -g @google/gemini-cli"
                ;;
        esac
    fi
done

if [[ "$PROVIDERS_FOUND" -eq 0 ]]; then
    echo -e "  ${RED}✗${NC} No provider CLI found on PATH"
    echo -e "      Prompt Engineer cannot run until at least one of"
    echo -e "      claude / codex / gemini is installed."
    exit 1
fi
echo -e "  ${GREEN}✓${NC} $PROVIDERS_FOUND provider CLI(s) available"

echo ""

# ─────────────────────────────────────────────────
# Step 2: Install optimize_prompt.py
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 2: Installing optimize_prompt.py${NC}"

mkdir -p "$PE_DIR"

if curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/prompt-engineer/optimize_prompt.py" -o "$PE_DIR/optimize_prompt.py"; then
    chmod +x "$PE_DIR/optimize_prompt.py"
    echo -e "  ${GREEN}✓${NC} optimize_prompt.py installed at $PE_DIR/optimize_prompt.py"
else
    echo -e "  ${RED}✗${NC} Failed to download optimize_prompt.py from $REPO_URL"
    exit 1
fi

# Companion README (best-effort; failure non-fatal)
if curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/prompt-engineer/README.md" -o "$PE_DIR/README.md" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} README.md installed"
else
    echo -e "  ${YELLOW}⚠${NC} Could not fetch README.md (non-fatal)"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 3: Install `pe` shell alias
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 3: Installing 'pe' shell alias${NC}"

SHELL_RC=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == */bash ]]; then
    SHELL_RC="$HOME/.bash_profile"
    [[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc"
fi

if [[ -z "$SHELL_RC" ]]; then
    echo -e "  ${YELLOW}⚠${NC} Could not detect shell — add this alias manually:"
    echo -e "      alias pe='python3 $PE_DIR/optimize_prompt.py'"
else
    if ! grep -qE "alias pe=.*optimize_prompt\.py" "$SHELL_RC" 2>/dev/null; then
        {
            echo ""
            echo "# Prompt Engineer alias (installed by claude-code-toolkit)"
            echo "alias pe='python3 $PE_DIR/optimize_prompt.py'"
        } >> "$SHELL_RC"
        echo -e "  ${GREEN}✓${NC} Added 'pe' alias to $SHELL_RC"
        echo -e "      Reload: source $SHELL_RC"
    else
        echo -e "  ${GREEN}✓${NC} 'pe' alias already present in $SHELL_RC"
    fi
fi

echo ""

# ─────────────────────────────────────────────────
# Step 4: Smoke test
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 4: Verifying install${NC}"

if python3 "$PE_DIR/optimize_prompt.py" --help >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} optimize_prompt.py runs"
else
    echo -e "  ${RED}✗${NC} optimize_prompt.py failed --help check"
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation complete                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Try it (after reloading your shell):"
echo -e "  ${CYAN}pe path/to/prompt.md${NC}                          # interactive menu"
echo -e "  ${CYAN}pe path/to/prompt.md --provider claude${NC}         # explicit"
echo -e "  ${CYAN}pe path/to/prompt.md --provider all --log${NC}      # fan-out + timeline"
echo -e "  ${CYAN}pe path/to/prompt.md --multi-pass${NC}              # 3-stage pipeline"
echo -e "  ${CYAN}echo \"Rewrite as a tone-control prompt\" | pe -${NC}"
echo ""
echo -e "Docs: ${CYAN}$PE_DIR/README.md${NC}"
echo -e "Slash command (Claude Code): ${CYAN}/prompt-engineer <path>${NC}"
