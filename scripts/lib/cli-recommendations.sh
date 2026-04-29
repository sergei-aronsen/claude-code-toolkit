#!/bin/bash

# scripts/lib/cli-recommendations.sh
#
# Phase 24 Sub-Phase 1 — informational helper.
#
# Detects whether `gemini` (Gemini CLI) and `codex` (Codex CLI) are on
# $PATH and prints install hints for whichever is missing. Always runs
# during Supreme Council setup BEFORE the user picks providers, so the
# user learns that subscription-CLI mode is the cheaper path and can pick
# it knowingly. Detection is informational only — never blocks setup.
#
# Output is also appended to ~/.claude/council/setup.log for later
# auditing (decision trail when a user later wonders why they ended up
# paying for API tokens instead of using the subscription CLI).
#
# Usage:
#   source scripts/lib/cli-recommendations.sh
#   recommend_clis
#
# Caller is expected to have ANSI color constants RED/GREEN/YELLOW/NC
# defined. Falls back to plain output otherwise.

# Resolve color constants with safe fallbacks (only set if unset).
: "${YELLOW:=}"
: "${GREEN:=}"
: "${NC:=}"

recommend_clis() {
    local council_dir="$HOME/.claude/council"
    local log_file="$council_dir/setup.log"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    mkdir -p "$council_dir"

    # Header in setup.log so successive runs are distinguishable
    {
        printf '\n[%s] CLI recommendation pass\n' "$timestamp"
    } >> "$log_file" 2>/dev/null || true

    if command -v gemini >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Gemini CLI found on PATH"
        echo "[$timestamp] gemini: present" >> "$log_file" 2>/dev/null || true
    else
        echo -e "  ${YELLOW}⚠${NC} Gemini CLI not found. Install it and sign in with a"
        echo -e "    Google AI Pro/Ultra subscription to avoid API charges:"
        echo -e "      npm install -g @google/gemini-cli"
        echo -e "      gemini login"
        echo "[$timestamp] gemini: missing — recommended install" >> "$log_file" 2>/dev/null || true
    fi

    if command -v codex >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Codex CLI found on PATH"
        echo "[$timestamp] codex: present" >> "$log_file" 2>/dev/null || true
    else
        echo -e "  ${YELLOW}⚠${NC} Codex CLI not found. Install it and sign in with a"
        echo -e "    ChatGPT Plus/Team subscription to avoid API charges:"
        echo -e "      npm install -g @openai/codex   # or: brew install --cask codex"
        echo -e "      codex login"
        echo "[$timestamp] codex: missing — recommended install" >> "$log_file" 2>/dev/null || true
    fi
}
