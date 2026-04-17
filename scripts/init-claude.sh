#!/bin/bash

# Claude Code Toolkit Initialization Script
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)
# Or: bash <(curl -sSL ...) laravel
# Or: bash <(curl -sSL ...) --dry-run

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR=".claude"
DRY_RUN=false
FRAMEWORK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-council)
            SKIP_COUNCIL=true
            shift
            ;;
        laravel|nextjs|nodejs|python|go|rails|base)
            FRAMEWORK="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo -e "Available frameworks: laravel, nextjs, nodejs, python, go, rails, base"
            exit 1
            ;;
    esac
done

SKIP_COUNCIL="${SKIP_COUNCIL:-false}"

# Detect framework automatically
detect_framework() {
    if [[ -f "artisan" ]]; then
        echo "laravel"
    elif [[ -f "bin/rails" ]] || [[ -f "config/application.rb" ]]; then
        echo "rails"
    elif [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "next.config.ts" ]]; then
        echo "nextjs"
    elif [[ -f "package.json" ]]; then
        echo "nodejs"
    elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        echo "python"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    else
        echo "base"
    fi
}

# Interactive stack selection menu
select_framework() {
    local detected
    detected=$(detect_framework)

    echo -e "${BLUE}Select your stack:${NC}"
    echo -e "  ${GREEN}1)${NC} Auto-detect (Recommended) — detected: ${GREEN}$detected${NC}"
    echo -e "  2) Laravel"
    echo -e "  3) Ruby on Rails"
    echo -e "  4) Next.js"
    echo -e "  5) Node.js"
    echo -e "  6) Python"
    echo -e "  7) Go"
    echo -e "  8) Base (generic)"
    echo ""

    local choice
    if ! read -r -p "  Enter choice [1-8] (default: 1): " choice < /dev/tty 2>/dev/null; then
        choice="1"
    fi
    choice="${choice:-1}"

    case "$choice" in
        1) FRAMEWORK="$detected" ;;
        2) FRAMEWORK="laravel" ;;
        3) FRAMEWORK="rails" ;;
        4) FRAMEWORK="nextjs" ;;
        5) FRAMEWORK="nodejs" ;;
        6) FRAMEWORK="python" ;;
        7) FRAMEWORK="go" ;;
        8) FRAMEWORK="base" ;;
        *)
            echo -e "${YELLOW}Invalid choice, using auto-detect${NC}"
            FRAMEWORK="$detected"
            ;;
    esac
}

# Select framework: CLI arg > interactive menu > auto-detect fallback
if [[ -z "$FRAMEWORK" ]]; then
    if [[ -e /dev/tty ]]; then
        select_framework
    else
        FRAMEWORK=$(detect_framework)
    fi
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Claude Code Toolkit — Initialization     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📁 Framework detected: ${GREEN}$FRAMEWORK${NC}"
echo -e "📂 Target directory: ${GREEN}$CLAUDE_DIR${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN - No files will be created${NC}"
    echo ""
fi

# Files to download
declare -a FILES=(
    # Core
    "templates/$FRAMEWORK/CLAUDE.md:CLAUDE.md"
    "templates/$FRAMEWORK/settings.json:settings.json"

    # Prompts (from template's prompts folder)
    "templates/$FRAMEWORK/prompts/SECURITY_AUDIT.md:prompts/SECURITY_AUDIT.md"
    "templates/$FRAMEWORK/prompts/PERFORMANCE_AUDIT.md:prompts/PERFORMANCE_AUDIT.md"
    "templates/$FRAMEWORK/prompts/CODE_REVIEW.md:prompts/CODE_REVIEW.md"
    "templates/$FRAMEWORK/prompts/DEPLOY_CHECKLIST.md:prompts/DEPLOY_CHECKLIST.md"
    "templates/$FRAMEWORK/prompts/DESIGN_REVIEW.md:prompts/DESIGN_REVIEW.md"
    "templates/$FRAMEWORK/prompts/MYSQL_PERFORMANCE_AUDIT.md:prompts/MYSQL_PERFORMANCE_AUDIT.md"
    "templates/$FRAMEWORK/prompts/POSTGRES_PERFORMANCE_AUDIT.md:prompts/POSTGRES_PERFORMANCE_AUDIT.md"

    # Agents (from template)
    "templates/$FRAMEWORK/agents/code-reviewer.md:agents/code-reviewer.md"
    "templates/$FRAMEWORK/agents/test-writer.md:agents/test-writer.md"
    "templates/$FRAMEWORK/agents/planner.md:agents/planner.md"
    "templates/$FRAMEWORK/agents/security-auditor.md:agents/security-auditor.md"

    # Skills
    "templates/$FRAMEWORK/skills/skill-rules.json:skills/skill-rules.json"
    "templates/$FRAMEWORK/skills/ai-models/SKILL.md:skills/ai-models/SKILL.md"
    "templates/$FRAMEWORK/skills/api-design/SKILL.md:skills/api-design/SKILL.md"
    "templates/$FRAMEWORK/skills/database/SKILL.md:skills/database/SKILL.md"
    "templates/$FRAMEWORK/skills/debugging/SKILL.md:skills/debugging/SKILL.md"
    "templates/$FRAMEWORK/skills/docker/SKILL.md:skills/docker/SKILL.md"
    "templates/$FRAMEWORK/skills/i18n/SKILL.md:skills/i18n/SKILL.md"
    "templates/$FRAMEWORK/skills/llm-patterns/SKILL.md:skills/llm-patterns/SKILL.md"
    "templates/$FRAMEWORK/skills/observability/SKILL.md:skills/observability/SKILL.md"
    "templates/$FRAMEWORK/skills/tailwind/SKILL.md:skills/tailwind/SKILL.md"
    "templates/$FRAMEWORK/skills/testing/SKILL.md:skills/testing/SKILL.md"

    # Rules (auto-loaded project context)
    "templates/$FRAMEWORK/rules/README.md:rules/README.md"
    "templates/$FRAMEWORK/rules/project-context.md:rules/project-context.md"

    # Commands
    "commands/plan.md:commands/plan.md"
    "commands/design.md:commands/design.md"
    "commands/tdd.md:commands/tdd.md"
    "commands/context-prime.md:commands/context-prime.md"
    "commands/checkpoint.md:commands/checkpoint.md"
    "commands/handoff.md:commands/handoff.md"
    "commands/audit.md:commands/audit.md"
    "commands/test.md:commands/test.md"
    "commands/refactor.md:commands/refactor.md"
    "commands/doc.md:commands/doc.md"
    "commands/fix.md:commands/fix.md"
    "commands/explain.md:commands/explain.md"
    "commands/helpme.md:commands/helpme.md"
    "commands/verify.md:commands/verify.md"
    "commands/debug.md:commands/debug.md"
    "commands/learn.md:commands/learn.md"
    "commands/update-toolkit.md:commands/update-toolkit.md"
    "commands/worktree.md:commands/worktree.md"
    "commands/migrate.md:commands/migrate.md"
    "commands/find-function.md:commands/find-function.md"
    "commands/find-script.md:commands/find-script.md"
    "commands/docker.md:commands/docker.md"
    "commands/api.md:commands/api.md"
    "commands/e2e.md:commands/e2e.md"
    "commands/perf.md:commands/perf.md"
    "commands/deps.md:commands/deps.md"
    "commands/council.md:commands/council.md"
    "commands/deploy.md:commands/deploy.md"
    "commands/fix-prod.md:commands/fix-prod.md"
    "commands/rollback-update.md:commands/rollback-update.md"

    # Cheatsheets
    "cheatsheets/en.md:cheatsheets/en.md"
    "cheatsheets/ru.md:cheatsheets/ru.md"
    "cheatsheets/es.md:cheatsheets/es.md"
    "cheatsheets/de.md:cheatsheets/de.md"
    "cheatsheets/fr.md:cheatsheets/fr.md"
    "cheatsheets/zh.md:cheatsheets/zh.md"
    "cheatsheets/ja.md:cheatsheets/ja.md"
    "cheatsheets/pt.md:cheatsheets/pt.md"
    "cheatsheets/ko.md:cheatsheets/ko.md"
)

# Add framework-specific files
if [[ "$FRAMEWORK" == "laravel" ]]; then
    FILES+=(
        "templates/laravel/agents/laravel-expert.md:agents/laravel-expert.md"
        "templates/laravel/skills/laravel/SKILL.md:skills/laravel/SKILL.md"
    )
elif [[ "$FRAMEWORK" == "nextjs" ]]; then
    FILES+=(
        "templates/nextjs/agents/nextjs-expert.md:agents/nextjs-expert.md"
        "templates/nextjs/skills/nextjs/SKILL.md:skills/nextjs/SKILL.md"
    )
elif [[ "$FRAMEWORK" == "nodejs" ]]; then
    FILES+=(
        "templates/nodejs/agents/nodejs-expert.md:agents/nodejs-expert.md"
        "templates/nodejs/skills/nodejs/SKILL.md:skills/nodejs/SKILL.md"
    )
elif [[ "$FRAMEWORK" == "python" ]]; then
    FILES+=(
        "templates/python/agents/python-expert.md:agents/python-expert.md"
        "templates/python/skills/python/SKILL.md:skills/python/SKILL.md"
    )
elif [[ "$FRAMEWORK" == "go" ]]; then
    FILES+=(
        "templates/go/agents/go-expert.md:agents/go-expert.md"
        "templates/go/skills/go/SKILL.md:skills/go/SKILL.md"
    )
elif [[ "$FRAMEWORK" == "rails" ]]; then
    FILES+=(
        "templates/rails/agents/rails-expert.md:agents/rails-expert.md"
        "templates/rails/skills/rails/SKILL.md:skills/rails/SKILL.md"
    )
fi

# Create directory structure
create_structure() {
    echo -e "${BLUE}📁 Creating directory structure...${NC}"

    local dirs=(
        "$CLAUDE_DIR"
        "$CLAUDE_DIR/prompts"
        "$CLAUDE_DIR/agents"
        "$CLAUDE_DIR/commands"
        "$CLAUDE_DIR/skills"
        "$CLAUDE_DIR/skills/ai-models"
        "$CLAUDE_DIR/rules"
        "$CLAUDE_DIR/docs"
        "$CLAUDE_DIR/cheatsheets"
        "$CLAUDE_DIR/scratchpad"
    )

    for dir in "${dirs[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would create: $dir"
        else
            mkdir -p "$dir"
            echo -e "  ${GREEN}✓${NC} $dir"
        fi
    done
}

# Download files
download_files() {
    echo ""
    echo -e "${BLUE}📥 Downloading files...${NC}"

    for file_spec in "${FILES[@]}"; do
        IFS=':' read -r src dest <<< "$file_spec"
        local full_dest="$CLAUDE_DIR/$dest"
        local full_url="$REPO_URL/$src"

        # Create parent directory
        local parent_dir
        parent_dir=$(dirname "$full_dest")

        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would download: $src → $full_dest"
        else
            mkdir -p "$parent_dir"
            if curl -sSL "$full_url" -o "$full_dest" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $dest"
            else
                echo -e "  ${YELLOW}⚠${NC} $dest (using base template)"
                # Try base template as fallback
                local base_src="${src/templates\/$FRAMEWORK/templates\/base}"
                curl -sSL "$REPO_URL/$base_src" -o "$full_dest" 2>/dev/null || true
            fi
        fi
    done
}

# Create .gitignore
create_gitignore() {
    echo ""
    echo -e "${BLUE}📝 Creating .gitignore...${NC}"

    local gitignore="$CLAUDE_DIR/.gitignore"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create: $gitignore"
    else
        cat > "$gitignore" << 'GITIGNORE'
# Claude Code local files
scratchpad/
activity.log
audit.log
*.local.md
POST_INSTALL.md
GITIGNORE
        echo -e "  ${GREEN}✓${NC} .gitignore"
    fi
}

# Create initial scratchpad
create_scratchpad() {
    echo ""
    echo -e "${BLUE}📋 Creating scratchpad template...${NC}"

    local scratchpad="$CLAUDE_DIR/scratchpad/current-task.md"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create: $scratchpad"
    else
        cat > "$scratchpad" << 'SCRATCHPAD'
# Current Task

## Description
[What are you working on?]

## Progress
- [ ] Phase 1
- [ ] Phase 2
- [ ] Phase 3

## Notes
[Any relevant notes]

## Blockers
- None
SCRATCHPAD
        echo -e "  ${GREEN}✓${NC} scratchpad/current-task.md"
    fi
}

# Create lessons-learned seed file
create_lessons_learned() {
    local lessons_file="$CLAUDE_DIR/rules/lessons-learned.md"

    if [[ -f "$lessons_file" ]]; then
        return
    fi

    echo ""
    echo -e "${BLUE}📝 Creating lessons-learned seed file...${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create: $lessons_file"
    else
        cat > "$lessons_file" << 'LESSONS'
---
description: Audit log of all lessons learned (history only, not auto-loaded)
globs: []
---
# Lessons Learned — Audit Log
<!-- History of lessons saved by /learn. Actual rules are in scoped files (e.g., rules/database.md). -->
LESSONS
        echo -e "  ${GREEN}✓${NC} rules/lessons-learned.md"
    fi
}

# Show security setup recommendation
recommend_security() {
    echo ""
    echo -e "${YELLOW}🔒 Strongly recommended: Global Security Setup${NC}"
    echo -e "  Adds security rules, safety-net plugin, and official Anthropic plugins"
    echo -e "  (code-review, commit-commands, security-guidance, frontend-design)."
    echo -e "  Install: ${YELLOW}bash <(curl -sSL ${REPO_URL}/scripts/setup-security.sh)${NC}"
}

# Show rate limit statusline recommendation
recommend_statusline() {
    echo ""
    echo -e "${BLUE}📊 Rate Limit Statusline (optional):${NC}"
    echo -e "  See session/weekly usage in the status bar."
    echo -e "  Install: ${YELLOW}bash <(curl -sSL ${REPO_URL}/scripts/install-statusline.sh)${NC}"
    echo -e "  Requires: macOS, jq, Claude Max/Pro"
}

# Setup Supreme Council (integrated)
setup_council() {
    local council_dir="$HOME/.claude/council"

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Supreme Council Setup                    ║${NC}"
    echo -e "${BLUE}║   Multi-AI Review (Gemini + ChatGPT)       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""

    # Check Python
    if ! command -v python3 &>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Python 3 not found — skipping Supreme Council"
        echo -e "  Install Python 3.8+ and run: ${YELLOW}bash <(curl -sSL ${REPO_URL}/scripts/setup-council.sh)${NC}"
        return
    fi

    # Download brain.py
    mkdir -p "$council_dir"
    if curl -sSL "$REPO_URL/scripts/council/brain.py" -o "$council_dir/brain.py" 2>/dev/null; then
        chmod +x "$council_dir/brain.py"
        echo -e "  ${GREEN}✓${NC} brain.py installed"
    else
        echo -e "  ${RED}✗${NC} Failed to download brain.py"
        return
    fi

    # Download README
    curl -sSL "$REPO_URL/scripts/council/README.md" -o "$council_dir/README.md" 2>/dev/null || true

    # Ask to configure now (skip in non-interactive environments)
    echo ""
    local configure
    if ! read -r -p "  Configure Supreme Council now? [Y/n]: " configure < /dev/tty 2>/dev/null; then
        configure="N"
    fi
    configure="${configure:-Y}"

    if [[ "$configure" =~ ^[Nn]$ ]]; then
        echo -e "  ${YELLOW}→${NC} Skipped. Run later: ${YELLOW}bash <(curl -sSL ${REPO_URL}/scripts/setup-council.sh)${NC}"

        # Create empty config
        if [[ ! -f "$council_dir/config.json" ]]; then
            cat > "$council_dir/config.json" << 'CONFIGEOF'
{
  "gemini": {
    "mode": "cli",
    "api_key": "",
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": "",
    "model": "gpt-5.2"
  }
}
CONFIGEOF
            chmod 600 "$council_dir/config.json"
        fi
        return
    fi

    # Gemini setup
    echo ""
    echo -e "  ${BLUE}Gemini configuration:${NC}"
    echo -e "    ${GREEN}1)${NC} Gemini CLI — free with Google subscription (recommended)"
    echo -e "    ${YELLOW}2)${NC} Gemini API — requires API key from AI Studio"
    echo ""

    local gemini_mode="cli"
    local gemini_key=""
    local gemini_choice
    if ! read -r -p "    Enter choice [1/2] (default: 1): " gemini_choice < /dev/tty 2>/dev/null; then
        gemini_choice="1"
    fi
    gemini_choice="${gemini_choice:-1}"

    if [[ "$gemini_choice" == "2" ]]; then
        gemini_mode="api"
        if [[ -n "${GEMINI_API_KEY:-}" ]]; then
            gemini_key="$GEMINI_API_KEY"
            echo -e "    ${GREEN}✓${NC} GEMINI_API_KEY found in environment"
        else
            read -r -p "    Enter Gemini API key (or press Enter to skip): " gemini_key < /dev/tty 2>/dev/null || true
            if [[ -z "$gemini_key" ]]; then
                echo -e "    ${YELLOW}⚠${NC} Add it later to ~/.claude/council/config.json"
            fi
        fi
    else
        echo -e "    ${BLUE}→${NC} Gemini CLI selected"
        if ! command -v gemini &>/dev/null; then
            echo -e "    ${YELLOW}⚠${NC} Gemini CLI not found. Install:"
            echo -e "      npm install -g @google/gemini-cli"
            echo -e "      Then run: gemini login"
        else
            echo -e "    ${GREEN}✓${NC} Gemini CLI found"
        fi
    fi

    # OpenAI setup
    echo ""
    echo -e "  ${BLUE}OpenAI (ChatGPT) configuration:${NC}"

    local openai_key=""
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        openai_key="$OPENAI_API_KEY"
        echo -e "    ${GREEN}✓${NC} OPENAI_API_KEY found in environment"
    else
        read -r -p "    Enter OpenAI API key (or press Enter to skip): " openai_key < /dev/tty 2>/dev/null || true
        if [[ -z "$openai_key" ]]; then
            echo -e "    ${YELLOW}⚠${NC} Add it later to ~/.claude/council/config.json"
            echo -e "    Get key: https://platform.openai.com/api-keys"
        fi
    fi

    # Create config
    if [[ ! -f "$council_dir/config.json" ]]; then
        # BUG-03: JSON-escape key values so literal `"`, `\`, newline in keys do not break JSON
        local gemini_mode_json gemini_key_json openai_key_json
        # shellcheck disable=SC2016
        gemini_mode_json=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$gemini_mode")
        # shellcheck disable=SC2016
        gemini_key_json=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$gemini_key")
        # shellcheck disable=SC2016
        openai_key_json=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$openai_key")

        cat > "$council_dir/config.json" << CONFIGEOF
{
  "gemini": {
    "mode": $gemini_mode_json,
    "api_key": $gemini_key_json,
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": $openai_key_json,
    "model": "gpt-5.2"
  }
}
CONFIGEOF
        chmod 600 "$council_dir/config.json"
        echo -e "  ${GREEN}✓${NC} config.json created"
    else
        echo -e "  ${YELLOW}⚠${NC} config.json already exists, preserving"
    fi

    # Shell alias
    local alias_line="alias brain='python3 $council_dir/brain.py'"
    local shell_rc

    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc="$HOME/.bash_profile"
    else
        shell_rc="$HOME/.bashrc"
    fi

    if [[ -f "$shell_rc" ]] && grep -q "alias brain=" "$shell_rc" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Alias 'brain' already exists"
    else
        {
            echo ""
            echo "# Supreme Council — multi-AI code review"
            echo "$alias_line"
        } >> "$shell_rc"
        echo -e "  ${GREEN}✓${NC} Added alias 'brain' to $shell_rc"
    fi

    echo -e "  ${GREEN}✓${NC} Supreme Council configured"
    echo -e "  Usage: ${YELLOW}/council add OAuth login with Google${NC}"
}

# Main
main() {
    create_structure
    download_files
    create_gitignore
    create_scratchpad
    create_lessons_learned

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Review and customize ${BLUE}$CLAUDE_DIR/CLAUDE.md${NC}"
    echo -e "  2. Commit the ${BLUE}$CLAUDE_DIR${NC} directory"
    echo -e ""
    echo -e "Installed:"
    echo -e "  ${GREEN}✓${NC} Toolkit — commands, agents, prompts, skills, rules"
    echo ""
    echo -e "Available commands:"
    echo -e "  ${YELLOW}/plan${NC}     — Create implementation plan"
    echo -e "  ${YELLOW}/tdd${NC}      — Test-driven development"
    echo -e "  ${YELLOW}/audit${NC}    — Run security/performance audit"
    echo -e "  ${YELLOW}/helpme${NC}   — Quick reference cheatsheet (9 languages)"

    recommend_security
    recommend_statusline

    # Supreme Council setup (integrated)
    if [[ "$SKIP_COUNCIL" != true ]]; then
        setup_council
    fi

    echo ""
    echo -e "${BLUE}🔍 Verify installation:${NC}"
    echo -e "  ${YELLOW}bash <(curl -sSL ${REPO_URL}/scripts/verify-install.sh)${NC}"
    echo ""
    echo -e "${YELLOW}⚠  Restart Claude Code in this project directory for commands to become available.${NC}"
    echo ""

    # Create POST_INSTALL.md for Claude to read and relay to user
    create_post_install
}

# Create post-install notes file for Claude to read
create_post_install() {
    cat > "$CLAUDE_DIR/POST_INSTALL.md" << POSTINSTALL
# Post-Install Notes

IMPORTANT: Show the following recommendations to the user after installation.

## What was installed

- **commands** — /plan, /tdd, /audit, /debug, /verify, /helpme, /fix and others
- **agents** — code-reviewer, test-writer, planner, security-auditor
- **prompts** — security audit, performance audit, code review, deploy checklist
- **skills** — skill accumulation system
- **rules** — auto-loaded project context (servers, architecture, conventions)
- **cheatsheets** — quick reference in 9 languages

## Action required

⚠️ **Restart Claude Code** (exit and reopen in this project directory) for slash commands to become available.

## Strongly recommended

🔒 **Global Security Setup** — adds security rules to ~/.claude/CLAUDE.md, safety-net plugin (blocks destructive commands), and official Anthropic plugins (code-review, commit-commands, security-guidance, frontend-design).
Safe to re-run — merges only new sections, preserves your customizations.

\`\`\`bash
bash <(curl -sSL $REPO_URL/scripts/setup-security.sh)
\`\`\`

## Optional

📊 **Rate Limit Statusline** — see session/weekly usage in the Claude Code status bar.
Requires: macOS, jq, Claude Max/Pro.

\`\`\`bash
bash <(curl -sSL $REPO_URL/scripts/install-statusline.sh)
\`\`\`

## Supreme Council

🧠 If you skipped council configuration during installation, set it up later:

\`\`\`bash
bash <(curl -sSL $REPO_URL/scripts/setup-council.sh)
\`\`\`

## Next step

Review and customize \`.claude/CLAUDE.md\` for your project.
POSTINSTALL
}

main

echo ""
echo "Read .claude/POST_INSTALL.md and show its contents to the user."
