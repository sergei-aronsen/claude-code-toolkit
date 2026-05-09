#!/bin/bash

# Comet Research Bridge Setup
# One-shot installer for the optional Perplexity Pro research backend.
# Installs Comet browser, creates an isolated profile, registers the
# `comet-bridge` MCP project-scope, and prints the security checklist.
#
# Idempotent — safe to re-run. Use --dry-run to preview without changes.
#
# Usage:
#   bash scripts/setup-comet.sh [--dry-run] [--scope project|user]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

DRY_RUN=0
SCOPE="project"
PROFILE_DIR="$HOME/comet-profiles/mcp-only"
TOOLS_DIR="$HOME/comet-mcp"
CDP_PORT=9223

# After upstream PR is merged this will switch to "perplexity-comet-mcp".
# Until then the i18n completion-detector fix lives only on the fork branch.
MCP_PACKAGE="github:sergei-aronsen/Perplexity-Comet-MCP#feat/i18n-completion-detection"

# ============================================================================
# Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Helpers
# ============================================================================

usage() {
    cat <<EOF
Usage: bash scripts/setup-comet.sh [options]

Options:
  --dry-run           Preview actions without changing anything.
  --scope SCOPE       'project' (default) or 'user'. 'user' = global; not
                      recommended unless you understand the threat model.
  -h, --help          Show this message.

This script:
  1. Installs Comet via Homebrew if missing
  2. Creates ~/comet-profiles/mcp-only with mode 0700
  3. Generates ~/comet-mcp/launch.sh and ~/comet-mcp/stop.sh
  4. Registers the comet-bridge MCP with Claude Code (project-scope)
  5. Prints the operational security checklist

It does not log you in. Login is a manual step (email + OTP) after the
first launch via ~/comet-mcp/launch.sh.
EOF
}

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [dry-run] $*"
    else
        # shellcheck disable=SC2294
        # We accept eval here: callers pass single-string commands with proper
        # quoting (e.g. "mkdir -p \"$DIR\""), and we want shell expansion of
        # those quoted strings. Splitting into an array would require redoing
        # quoting at every call site.
        eval "$@"
    fi
}

require_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}Error:${NC} this script targets macOS only (Comet ships as .dmg / Homebrew cask)." >&2
        exit 1
    fi
}

# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --scope)
            SCOPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ "$SCOPE" != "project" && "$SCOPE" != "user" ]]; then
    echo -e "${RED}Error:${NC} --scope must be 'project' or 'user' (got: $SCOPE)" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    echo -e "${YELLOW}Warning:${NC} user-scope means every Claude Code session on this machine"
    echo -e "         can drive Comet. Project-scope is strongly recommended."
    printf "Continue with user-scope? [y/N] "
    read -r answer < /dev/tty
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

# ============================================================================
# Pre-flight
# ============================================================================

require_macos

echo -e "${CYAN}Comet Research Bridge — setup${NC}"
if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}Dry-run mode. No changes will be made.${NC}"
fi
echo ""

# ============================================================================
# Step 1 — Install Comet
# ============================================================================

echo -e "${CYAN}[1/5]${NC} Comet browser..."
if [[ -d "/Applications/Comet.app" ]]; then
    echo -e "  ${GREEN}✓${NC} already installed at /Applications/Comet.app"
else
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "  ${RED}✗${NC} Homebrew not found. Install Homebrew first:"
        echo "      /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  Or download Comet manually: https://www.perplexity.ai/comet"
        exit 1
    fi
    echo "  Installing via 'brew install --cask comet' ..."
    run "brew install --cask comet"
    echo -e "  ${GREEN}✓${NC} installed"
fi

# ============================================================================
# Step 2 — Create isolated profile
# ============================================================================

echo -e "${CYAN}[2/5]${NC} Isolated Comet profile..."
if [[ -d "$PROFILE_DIR" ]]; then
    echo -e "  ${GREEN}✓${NC} $PROFILE_DIR exists"
else
    run "mkdir -p \"$PROFILE_DIR\""
    echo -e "  ${GREEN}✓${NC} $PROFILE_DIR created"
fi
run "chmod 700 \"$PROFILE_DIR\""

# ============================================================================
# Step 3 — launch.sh / stop.sh
# ============================================================================

echo -e "${CYAN}[3/5]${NC} Wrapper scripts..."
run "mkdir -p \"$TOOLS_DIR\""
run "chmod 700 \"$TOOLS_DIR\""

LAUNCH_SCRIPT="$TOOLS_DIR/launch.sh"
STOP_SCRIPT="$TOOLS_DIR/stop.sh"

if [[ $DRY_RUN -eq 0 ]]; then
    cat > "$LAUNCH_SCRIPT" <<LAUNCH_EOF
#!/bin/bash
# Launch isolated Comet profile for the comet-bridge MCP.
# Generated by scripts/setup-comet.sh — re-run setup to regenerate.

set -euo pipefail

PROFILE_DIR="$PROFILE_DIR"
CDP_PORT="\${COMET_PORT:-$CDP_PORT}"
COMET_BIN="/Applications/Comet.app/Contents/MacOS/Comet"

RED=\$'\033[0;31m'
GREEN=\$'\033[0;32m'
YELLOW=\$'\033[1;33m'
CYAN=\$'\033[0;36m'
NC=\$'\033[0m'

if [ ! -x "\$COMET_BIN" ]; then
  echo "\${RED}Error:\${NC} Comet not found at \$COMET_BIN"
  echo "Re-run scripts/setup-comet.sh or download from https://www.perplexity.ai/comet"
  exit 1
fi

if [ ! -d "\$PROFILE_DIR" ]; then
  mkdir -p "\$PROFILE_DIR"
  chmod 700 "\$PROFILE_DIR"
fi

if lsof -nP -iTCP:"\$CDP_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "\${RED}Error:\${NC} port \$CDP_PORT already in use."
  echo "Run: $TOOLS_DIR/stop.sh"
  exit 1
fi

echo "\${CYAN}Launching isolated Comet\${NC}"
echo "  profile: \$PROFILE_DIR"
echo "  CDP port: \$CDP_PORT (localhost only)"
echo ""
echo "\${YELLOW}Security reminders:\${NC}"
echo "  - Sign in ONLY to Perplexity Pro (email OTP, never Google SSO)"
echo "  - Do NOT log into Gmail / GitHub / banking in this profile"
echo "  - Disable Password Manager + Autofill + Sync in Settings"
echo "  - Run $TOOLS_DIR/stop.sh after work"
echo ""

exec "\$COMET_BIN" \\
  --user-data-dir="\$PROFILE_DIR" \\
  --remote-debugging-port="\$CDP_PORT" \\
  --remote-debugging-address=127.0.0.1 \\
  --no-first-run \\
  --no-default-browser-check \\
  >/dev/null 2>&1 &

sleep 1
echo "\${GREEN}Comet launched.\${NC} CDP listening on 127.0.0.1:\$CDP_PORT"
LAUNCH_EOF
    chmod 700 "$LAUNCH_SCRIPT"

    cat > "$STOP_SCRIPT" <<STOP_EOF
#!/bin/bash
# Kill the isolated Comet (port $CDP_PORT only). Personal Comet windows
# launched without --remote-debugging-port are not affected.

set -euo pipefail

CDP_PORT="\${COMET_PORT:-$CDP_PORT}"

YELLOW=\$'\033[1;33m'
GREEN=\$'\033[0;32m'
NC=\$'\033[0m'

PIDS=\$(pgrep -f "Comet.*--remote-debugging-port=\$CDP_PORT" || true)

if [ -z "\$PIDS" ]; then
  echo "\${YELLOW}No isolated Comet (port \$CDP_PORT) running.\${NC}"
  exit 0
fi

# shellcheck disable=SC2086
kill \$PIDS 2>/dev/null || true
sleep 1
PIDS_LEFT=\$(pgrep -f "Comet.*--remote-debugging-port=\$CDP_PORT" || true)
if [ -n "\$PIDS_LEFT" ]; then
  # shellcheck disable=SC2086
  kill -9 \$PIDS_LEFT 2>/dev/null || true
fi

echo "\${GREEN}Comet MCP profile stopped.\${NC}"
STOP_EOF
    chmod 700 "$STOP_SCRIPT"
fi

echo -e "  ${GREEN}✓${NC} $LAUNCH_SCRIPT"
echo -e "  ${GREEN}✓${NC} $STOP_SCRIPT"

# ============================================================================
# Step 4 — Register MCP
# ============================================================================

echo -e "${CYAN}[4/5]${NC} Registering comet-bridge MCP (scope=$SCOPE)..."

if ! command -v claude >/dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} 'claude' CLI not found. Install Claude Code first:"
    echo "      https://docs.claude.com/en/docs/claude-code/quickstart"
    exit 1
fi

# Detect existing registration to keep idempotent
EXISTING=""
if claude mcp list 2>/dev/null | grep -q "^comet-bridge"; then
    EXISTING="yes"
fi

if [[ -n "$EXISTING" && $DRY_RUN -eq 0 ]]; then
    echo -e "  ${YELLOW}~${NC} comet-bridge already registered. Removing first to re-add cleanly..."
    run "claude mcp remove comet-bridge >/dev/null 2>&1 || true"
fi

run "claude mcp add comet-bridge --scope $SCOPE --env COMET_PORT=$CDP_PORT -- npx -y \"$MCP_PACKAGE\""
echo -e "  ${GREEN}✓${NC} registered (scope=$SCOPE)"

# ============================================================================
# Step 5 — Final checklist
# ============================================================================

echo ""
echo -e "${CYAN}[5/5]${NC} Setup complete. Next steps:"
echo ""
echo "  1. Launch isolated Comet:"
echo "       $LAUNCH_SCRIPT"
echo ""
echo "  2. In the Comet window:"
echo "       - DO NOT click 'Import settings' on first run — pick 'Сделать это позже'"
echo "       - Open https://www.perplexity.ai/"
echo "       - Sign in with email + OTP (NOT Google SSO)"
echo "       - Settings → Privacy → disable Password Manager, Autofill, Sync"
echo "       - Close all extra tabs"
echo ""
echo "  3. Restart Claude Code in this project to pick up the new MCP:"
echo "       /mcp   # should show: comet-bridge ✔ connected · 8 tools"
echo ""
echo "  4. Try it:"
echo "       /lookup current Node.js LTS version"
echo ""
echo "  5. After your research session, stop Comet:"
echo "       $STOP_SCRIPT"
echo ""
echo -e "${YELLOW}Security model:${NC} components/comet-research.md"
echo -e "${YELLOW}Slash commands:${NC} /research, /lookup, /factcheck"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}Dry-run complete. No changes were made.${NC}"
fi
