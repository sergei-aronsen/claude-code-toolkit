#!/bin/bash

# Security Setup Script for Claude Code
# Installs global security rules and safety-net plugin
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-security.sh)
#
# SAFETY-04 INVARIANT: TK only ever writes to (a) permissions.deny entries TK authored,
# (b) hooks.PreToolUse[*] entries marked with _tk_owned: true, and (c) TK's own env block.
# Every other key in ~/.claude/settings.json is read-only to TK - never created, never updated,
# never deleted. The merge_settings_python helper in scripts/lib/install.sh enforces this by
# partitioning existing hook entries into foreign_entries (preserved verbatim) and tk_entries
# (replaced in place). See .planning/phases/03-install-flow/03-CONTEXT.md decisions D-37..D-40.

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
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
SETTINGS_JSON="$CLAUDE_DIR/settings.json"
MARKER="# Global Security Rules"

# Source lib/install.sh for backup_settings_once + merge_settings_python helpers (Phase 3 D-37..D-40).
# Remote curl|bash callers download to mktemp; local callers source from a known path next to this script.
LIB_INSTALL_TMP=""
if [[ -f "$(dirname "$0")/lib/install.sh" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/lib/install.sh"
else
    LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install-lib.XXXXXX")
    trap 'rm -f "$LIB_INSTALL_TMP"' EXIT
    if ! curl -sSLf "$REPO_URL/scripts/lib/install.sh" -o "$LIB_INSTALL_TMP"; then
        echo -e "${RED}Failed to download lib/install.sh - aborting${NC}"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$LIB_INSTALL_TMP"
fi

# Install RTK.md fallback notes to ~/.claude/RTK.md (guard: never clobber existing)
install_rtk_notes() {
    local src_rtk
    src_rtk="$(dirname "$0")/../templates/global/RTK.md"
    local dst_rtk="$HOME/.claude/RTK.md"

    if [[ ! -f "$src_rtk" ]]; then
        echo "ℹ Skipping RTK.md install — source file not found (offline / partial install)"
        return 0
    fi

    if [[ -f "$dst_rtk" ]]; then
        echo -e "  ℹ ~/.claude/RTK.md already exists (rtk init -g or prior TK install); leaving untouched."
        echo -e "  See components/optional-plugins.md for the rtk-ai/rtk#1276 caveat."
        return 0
    fi

    cp "$src_rtk" "$dst_rtk"
    echo -e "  ${GREEN}✓${NC} Installed fallback ~/.claude/RTK.md (points to components/optional-plugins.md for rtk-ai/rtk#1276)"
}

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Code Security Setup                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────
# Step 1: Install global security rules
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 1: Global security rules (~/.claude/CLAUDE.md)${NC}"

mkdir -p "$CLAUDE_DIR"

# Download latest security rules
SECURITY_CONTENT=$(curl -sSLf "$REPO_URL/templates/global/CLAUDE.md" 2>/dev/null)
if [[ -z "$SECURITY_CONTENT" ]]; then
    echo -e "  ${RED}✗${NC} Failed to download security rules"
    echo -e "  Try manually: curl -sSL $REPO_URL/templates/global/CLAUDE.md >> ~/.claude/CLAUDE.md"
else
    if [[ ! -f "$CLAUDE_MD" ]]; then
        # No file — create from scratch
        echo "$SECURITY_CONTENT" > "$CLAUDE_MD"
        echo -e "  ${GREEN}✓${NC} Created ~/.claude/CLAUDE.md with security rules"
    elif ! grep -q "$MARKER" "$CLAUDE_MD" 2>/dev/null; then
        # File exists but no security rules — append all
        echo -e "  ${YELLOW}⚠${NC} ~/.claude/CLAUDE.md exists but lacks security rules"
        {
            echo ""
            echo "---"
            echo ""
            echo "$SECURITY_CONTENT"
        } >> "$CLAUDE_MD"
        echo -e "  ${GREEN}✓${NC} Security rules appended to existing CLAUDE.md"
    else
        # File exists with security rules — merge missing sections
        echo -e "  Checking for new sections..."
        ADDED=0

        # Extract section headers from the latest template (## N. TITLE).
        # ERE for portability: BSD grep doesn't reliably support \+ in BRE.
        SECTIONS=$(echo "$SECURITY_CONTENT" | grep -nE '^## [0-9]+\.' || true)

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            LINE_NUM=$(echo "$line" | cut -d: -f1)
            HEADER=$(echo "$line" | cut -d: -f2-)
            # Extract section number for matching (e.g., "## 12." from "## 12. API SECURITY")
            SECTION_NUM=$(echo "$HEADER" | grep -oE '## [0-9]+\.' || true)

            # Audit C-09: anchor with `^... ` — without anchoring, `## 1.`
            # matches inside `## 12.`, `## 13.`, etc., so sections 10-19
            # are wrongly reported "already present" and skipped.
            if [[ -n "$SECTION_NUM" ]] && ! grep -qE "^${SECTION_NUM} " "$CLAUDE_MD" 2>/dev/null; then
                # This section is missing — extract it from the template
                # Find the next section header or end of file
                NEXT_LINE=$(echo "$SECURITY_CONTENT" | tail -n +"$((LINE_NUM + 1))" | grep -nE '^## [0-9]+\.' | head -1 | cut -d: -f1)

                if [[ -n "$NEXT_LINE" ]]; then
                    SECTION_BODY=$(echo "$SECURITY_CONTENT" | sed -n "${LINE_NUM},$((LINE_NUM + NEXT_LINE - 2))p")
                else
                    SECTION_BODY=$(echo "$SECURITY_CONTENT" | tail -n +"$LINE_NUM")
                fi

                {
                    echo ""
                    echo "$SECTION_BODY"
                } >> "$CLAUDE_MD"
                SECTION_TITLE="${HEADER//## /}"
                echo -e "  ${GREEN}+${NC} Added: $SECTION_TITLE"
                ADDED=$((ADDED + 1))
            fi
        done <<< "$SECTIONS"

        if [[ $ADDED -eq 0 ]]; then
            echo -e "  ${GREEN}✓${NC} All sections up to date"
        else
            echo -e "  ${GREEN}✓${NC} Added $ADDED new section(s), existing sections preserved"
        fi
    fi
fi

echo ""
install_rtk_notes
echo ""

# ─────────────────────────────────────────────────
# Step 2: Install safety-net plugin
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 2: safety-net plugin (destructive command blocker)${NC}"

# Check if npm/npx available
if ! command -v npm &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} npm not found — skipping safety-net installation"
    echo -e "  Install Node.js first, then run:"
    echo -e "    npm install -g cc-safety-net"
    echo ""
else
    # Check if already installed
    if command -v cc-safety-net &>/dev/null; then
        CURRENT_VERSION=$(cc-safety-net --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} cc-safety-net already installed (v$CURRENT_VERSION)"
    else
        echo -e "  Installing cc-safety-net..."
        if npm install -g cc-safety-net 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} cc-safety-net installed globally"
        else
            echo -e "  ${YELLOW}⚠${NC} Global install failed, trying npx..."
            echo -e "  safety-net will work via npx (slower startup)"
        fi
    fi
fi

echo ""

# ─────────────────────────────────────────────────
# Step 3: Install combined PreToolUse hook
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 3: Configuring PreToolUse hook${NC}"

HOOKS_DIR="$CLAUDE_DIR/hooks"
COMBINED_HOOK="$HOOKS_DIR/pre-bash.sh"

# Create combined hook (safety-net → RTK, sequential, no parallel conflicts)
mkdir -p "$HOOKS_DIR"

cat > "$COMBINED_HOOK" << 'HOOKEOF'
#!/usr/bin/env bash
# Combined PreToolUse hook for Bash commands
# Runs safety-net first (block dangerous), then RTK (rewrite for token savings).
# Must be a SINGLE hook to avoid parallel execution conflicts.
# See: https://github.com/sergei-aronsen/claude-code-toolkit

INPUT=$(cat)

# Step 1: cc-safety-net — block destructive commands
if command -v cc-safety-net &>/dev/null; then
    SAFETY_RESULT=$(echo "$INPUT" | cc-safety-net --claude-code 2>/dev/null)
    if echo "$SAFETY_RESULT" | grep -q '"deny"' 2>/dev/null; then
        echo "$SAFETY_RESULT"
        exit 0
    fi
fi

# Step 2: RTK rewrite — optimize token usage
if command -v rtk &>/dev/null && command -v jq &>/dev/null; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    if [ -n "$CMD" ]; then
        REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || true
        if [ -n "$REWRITTEN" ] && [ "$CMD" != "$REWRITTEN" ]; then
            ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
            UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')
            jq -n --argjson updated "$UPDATED_INPUT" \
                '{ "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "permissionDecisionReason": "RTK auto-rewrite",
                    "updatedInput": $updated
                }}'
            exit 0
        fi
    fi
fi

# No rewrite needed, no block — pass through
exit 0
HOOKEOF

chmod +x "$COMBINED_HOOK"
echo -e "  ${GREEN}✓${NC} Combined hook installed: $COMBINED_HOOK"

# Configure settings.json to use combined hook
HOOK_COMMAND="$COMBINED_HOOK"

if [[ -f "$SETTINGS_JSON" ]]; then
    # Check if combined hook or safety-net already configured
    if grep -q "pre-bash.sh" "$SETTINGS_JSON" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Combined hook already configured in settings.json"
    else
        echo -e "  Configuring combined hook in settings.json..."

        if command -v python3 &>/dev/null; then
            # SAFETY-03 / D-40: one backup per run via shared sentinel
            backup_settings_once "$SETTINGS_JSON"

            # SAFETY-01 / SAFETY-02 / D-37 / D-38 / D-39: atomic merge with append-both,
            # _tk_owned marker, foreign-hook preservation
            if merge_settings_python "$SETTINGS_JSON" "$HOOK_COMMAND"; then
                echo -e "  ${GREEN}✓${NC} Combined hook configured (foreign hooks preserved per SAFETY-02)"
            else
                # SAFETY-03 restore-on-failure
                if [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && [[ -f "$TK_SETTINGS_BACKUP" ]]; then
                    cp "$TK_SETTINGS_BACKUP" "$SETTINGS_JSON"
                    echo -e "  ${RED}✗${NC} JSON merge failed - restored from backup: $TK_SETTINGS_BACKUP"
                else
                    echo -e "  ${RED}✗${NC} JSON merge failed and NO backup available"
                fi
                exit 1
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} python3 not found for JSON merge"
            echo -e "  Add the hook manually to ~/.claude/settings.json"
        fi
    fi
else
    echo -e "  Creating settings.json with combined hook..."
    cat > "$SETTINGS_JSON" << SETTINGS
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "_tk_owned": true,
        "hooks": [
          {
            "type": "command",
            "command": "$COMBINED_HOOK"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "code-review@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true
  }
}
SETTINGS
    echo -e "  ${GREEN}✓${NC} Created settings.json with combined hook and official plugins"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 4: Install official Anthropic plugins
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 4: Official Anthropic plugins${NC}"

PLUGINS=(
    "code-review@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "security-guidance@claude-plugins-official"
    "frontend-design@claude-plugins-official"
)

if [[ -f "$SETTINGS_JSON" ]]; then
    if grep -q "enabledPlugins" "$SETTINGS_JSON" 2>/dev/null; then
        # Audit C-10: substring grep for `code-review@...` matches inside
        # `_disabled_code-review@...` and other unrelated keys, falsely
        # reporting "all enabled" and skipping the merge. Use python+json
        # to check the actual `enabledPlugins[plugin] is true` shape.
        ALL_PRESENT=true
        if command -v python3 &>/dev/null; then
            for plugin in "${PLUGINS[@]}"; do
                if ! python3 -c "import json,sys
c=json.load(open(sys.argv[1]))
sys.exit(0 if c.get('enabledPlugins',{}).get(sys.argv[2]) is True else 1)" \
                    "$SETTINGS_JSON" "$plugin" 2>/dev/null; then
                    ALL_PRESENT=false
                    break
                fi
            done
        else
            # Fallback: anchor the grep so we don't accept partial keys.
            for plugin in "${PLUGINS[@]}"; do
                if ! grep -qE "\"${plugin}\"[[:space:]]*:[[:space:]]*true" "$SETTINGS_JSON" 2>/dev/null; then
                    ALL_PRESENT=false
                    break
                fi
            done
        fi

        if [[ "$ALL_PRESENT" == true ]]; then
            echo -e "  ${GREEN}✓${NC} All official plugins already enabled"
        else
            # Merge missing plugins via shared helper
            if command -v python3 &>/dev/null; then
                # SAFETY-03 / D-40: backup once per run (skipped if Step 3 already backed up)
                backup_settings_once "$SETTINGS_JSON"
                PLUGIN_CSV=$(IFS=,; echo "${PLUGINS[*]}")
                if merge_plugins_python "$SETTINGS_JSON" "$PLUGIN_CSV"; then
                    echo -e "  ${GREEN}✓${NC} Plugins merged into settings.json"
                else
                    if [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && [[ -f "$TK_SETTINGS_BACKUP" ]]; then
                        cp "$TK_SETTINGS_BACKUP" "$SETTINGS_JSON"
                        echo -e "  ${RED}✗${NC} JSON merge failed - restored from backup: $TK_SETTINGS_BACKUP"
                    fi
                    exit 1
                fi
            else
                echo -e "  ${YELLOW}⚠${NC} python3 not found — add plugins manually to ~/.claude/settings.json"
            fi
        fi
    else
        # enabledPlugins key missing - add it via shared helper
        if command -v python3 &>/dev/null; then
            # SAFETY-03 / D-40: backup once per run (skipped if Step 3 already backed up)
            backup_settings_once "$SETTINGS_JSON"
            PLUGIN_CSV=$(IFS=,; echo "${PLUGINS[*]}")
            if merge_plugins_python "$SETTINGS_JSON" "$PLUGIN_CSV"; then
                echo -e "  ${GREEN}✓${NC} Plugins added to settings.json"
            else
                if [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && [[ -f "$TK_SETTINGS_BACKUP" ]]; then
                    cp "$TK_SETTINGS_BACKUP" "$SETTINGS_JSON"
                    echo -e "  ${RED}✗${NC} JSON merge failed - restored from backup: $TK_SETTINGS_BACKUP"
                fi
                exit 1
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} python3 not found — add plugins manually"
        fi
    fi
else
    # settings.json doesn't exist yet — will be created in step 3
    # This shouldn't happen since step 3 runs first, but just in case
    echo -e "  ${YELLOW}⚠${NC} settings.json not found — plugins will be added after settings are created"
fi

echo ""

# ─────────────────────────────────────────────────
# Step 5: Verify
# ─────────────────────────────────────────────────

echo -e "${CYAN}Step 5: Verification${NC}"

PASS=0
FAIL=0

# Check CLAUDE.md
if [[ -f "$CLAUDE_MD" ]] && grep -q "$MARKER" "$CLAUDE_MD"; then
    echo -e "  ${GREEN}✓${NC} Security rules present in ~/.claude/CLAUDE.md"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} Security rules missing from ~/.claude/CLAUDE.md"
    FAIL=$((FAIL + 1))
fi

# Check safety-net
if command -v cc-safety-net &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} cc-safety-net is installed"
    PASS=$((PASS + 1))
else
    echo -e "  ${YELLOW}~${NC} cc-safety-net not globally installed (will use npx)"
    PASS=$((PASS + 1))
fi

# Check hook
if [[ -f "$SETTINGS_JSON" ]] && grep -q "pre-bash.sh" "$SETTINGS_JSON"; then
    echo -e "  ${GREEN}✓${NC} Combined PreToolUse hook configured (safety-net + RTK)"
    PASS=$((PASS + 1))
elif [[ -f "$SETTINGS_JSON" ]] && grep -q "cc-safety-net" "$SETTINGS_JSON"; then
    echo -e "  ${YELLOW}~${NC} Legacy safety-net hook (consider upgrading to combined hook)"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗${NC} PreToolUse hook not configured"
    FAIL=$((FAIL + 1))
fi

# Test safety-net blocking
if command -v cc-safety-net &>/dev/null; then
    TEST_RESULT=$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | cc-safety-net --claude-code 2>/dev/null)
    if echo "$TEST_RESULT" | grep -q "deny"; then
        echo -e "  ${GREEN}✓${NC} safety-net blocks destructive commands"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} safety-net did not block test command"
        FAIL=$((FAIL + 1))
    fi
fi

# Check official plugins
if [[ -f "$SETTINGS_JSON" ]] && grep -q "enabledPlugins" "$SETTINGS_JSON"; then
    PLUGIN_COUNT=0
    for plugin in "${PLUGINS[@]}"; do
        if grep -q "$plugin" "$SETTINGS_JSON" 2>/dev/null; then
            PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
        fi
    done
    if [[ $PLUGIN_COUNT -eq ${#PLUGINS[@]} ]]; then
        echo -e "  ${GREEN}✓${NC} All ${#PLUGINS[@]} official plugins enabled"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}~${NC} $PLUGIN_COUNT/${#PLUGINS[@]} official plugins enabled"
        PASS=$((PASS + 1))
    fi
else
    echo -e "  ${RED}✗${NC} Official plugins not configured"
    FAIL=$((FAIL + 1))
fi

echo ""

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Security setup complete ($PASS/$PASS checks passed)  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     Setup partially complete ($PASS passed, $FAIL failed)  ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BLUE}What was installed:${NC}"
echo -e "  1. ${GREEN}Global security rules${NC} — ~/.claude/CLAUDE.md"
echo -e "     14 sections: forbidden patterns, required patterns, doubt protocol,"
echo -e "     self-review checklist, anti-pattern learning, prompt injection defense,"
echo -e "     dependency security, security review protocol, recommended tooling,"
echo -e "     Docker/container, CI/CD, API, WebSocket, framework-specific notes"
echo ""
echo -e "  2. ${GREEN}safety-net plugin${NC} — blocks destructive commands"
echo -e "     Semantic analysis (not pattern matching) of shell commands"
echo -e "     Blocks: rm -rf, git push --force, git reset --hard, etc."
echo ""
echo -e "  3. ${GREEN}Combined PreToolUse hook${NC} — ~/.claude/hooks/pre-bash.sh"
echo -e "     safety-net (block dangerous) → RTK (rewrite for token savings)"
echo -e "     Single hook avoids parallel execution conflicts"
echo ""
echo -e "  4. ${GREEN}Official Anthropic plugins${NC} — ~/.claude/settings.json"
echo -e "     code-review: PR review with /code-review"
echo -e "     commit-commands: /commit, /commit-push-pr, /clean_gone"
echo -e "     security-guidance: PreToolUse warnings for security patterns"
echo -e "     frontend-design: auto-activates for frontend work"
echo ""
echo -e "${BLUE}Recommended next steps:${NC}"
echo -e "  1. Add ${CYAN}claude-code-security-review${NC} GitHub Action to your repos"
echo -e "     https://github.com/anthropics/claude-code-security-review"
echo -e "  2. Add ${CYAN}Semgrep${NC} to your CI pipeline for SAST analysis"
echo -e "     https://semgrep.dev"
echo -e "  3. Review and customize rules in ~/.claude/CLAUDE.md"
echo ""
