#!/bin/bash

# optional-plugins.sh — Print the end-of-run recommended-optional-plugins block (DOCS-06)
# Source this file. Do NOT execute it directly.
# Usage: source "$SCRIPT_DIR/lib/optional-plugins.sh" && recommend_optional_plugins
#
# IMPORTANT: No set -euo pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
[[ -z "${CYAN:-}" ]]   && CYAN='\033[0;36m'
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[0;33m'
[[ -z "${RED:-}" ]]    && RED='\033[0;31m'
[[ -z "${BLUE:-}" ]]   && BLUE='\033[0;34m'
[[ -z "${NC:-}" ]]     && NC='\033[0m'

recommend_optional_plugins() {
    echo ""
    echo -e "${CYAN}🧩 Recommended optional plugins:${NC}"
    echo ""
    echo -e "  ${YELLOW}rtk${NC} — 60-90% token savings on dev commands"
    echo -e "    Install: ${YELLOW}brew install rtk && rtk init -g${NC}"
    echo -e "    ${RED}Known issue${NC}: rtk ls broken on non-English locales (rtk-ai/rtk#1276)"
    echo -e "    Workaround: add exclude_commands = [\"ls\"] to ~/Library/Application Support/rtk/config.toml"
    echo ""
    echo -e "  ${YELLOW}caveman${NC} — ~46% fewer input tokens per session"
    echo -e "    Install: ${YELLOW}claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman${NC}"
    echo -e "    ${YELLOW}⚠${NC} caveman-compress auto-backs up CLAUDE.md to CLAUDE.original.md; commit CLAUDE.md to git before running compress"
    echo -e "    Languages: en + wenyan (Classical Chinese)"
    echo ""
    echo -e "  ${YELLOW}superpowers${NC} (obra) — skills + code-reviewer agent (TK complements)"
    echo -e "    Install: ${YELLOW}claude plugin install superpowers@claude-plugins-official${NC}"
    echo ""
    echo -e "  ${YELLOW}get-shit-done${NC} (gsd-build) — phase-based workflow (TK complements)"
    echo -e "    Install: ${YELLOW}bash <(curl -sSL https://raw.githubusercontent.com/gsd-build/get-shit-done/main/scripts/install.sh)${NC}"
    echo ""
    echo -e "  ${BLUE}Details:${NC} see components/optional-plugins.md in the TK repo"
}
