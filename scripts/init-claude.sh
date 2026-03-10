#!/bin/bash

# Claude Code Toolkit Initialization Script
# Usage: curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh | bash
# Or: curl -sSL ... | bash -s -- laravel
# Or: curl -sSL ... | bash -s -- --dry-run

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

# Detect framework if not specified
detect_framework() {
    # Laravel
    if [[ -f "artisan" ]]; then
        echo "laravel"
    # Ruby on Rails
    elif [[ -f "bin/rails" ]] || [[ -f "config/application.rb" ]]; then
        echo "rails"
    # Next.js
    elif [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "next.config.ts" ]]; then
        echo "nextjs"
    # Node.js (package.json but not Next.js)
    elif [[ -f "package.json" ]]; then
        echo "nodejs"
    # Python
    elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        echo "python"
    # Go
    elif [[ -f "go.mod" ]]; then
        echo "go"
    else
        echo "base"
    fi
}

if [[ -z "$FRAMEWORK" ]]; then
    FRAMEWORK=$(detect_framework)
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

    # Rules (auto-loaded project context)
    "templates/$FRAMEWORK/rules/README.md:rules/README.md"
    "templates/$FRAMEWORK/rules/project-context.md:rules/project-context.md"

    # Commands
    "commands/plan.md:commands/plan.md"
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

# Show security setup recommendation
recommend_security() {
    echo ""
    echo -e "${YELLOW}🔒 Strongly recommended: Global Security Setup${NC}"
    echo -e "  Adds security rules, safety-net plugin, and official Anthropic plugins"
    echo -e "  (code-review, commit-commands, security-guidance, frontend-design)."
    echo -e "  Install: ${YELLOW}curl -sSL ${REPO_URL}/scripts/setup-security.sh | bash${NC}"
}

# Show rate limit statusline recommendation
recommend_statusline() {
    echo ""
    echo -e "${BLUE}📊 Rate Limit Statusline (optional):${NC}"
    echo -e "  See session/weekly usage in the status bar."
    echo -e "  Install: ${YELLOW}curl -sSL ${REPO_URL}/scripts/install-statusline.sh | bash${NC}"
    echo -e "  Requires: macOS, jq, Claude Max/Pro"
}

# Show Supreme Council recommendation
recommend_council() {
    echo ""
    echo -e "${BLUE}🧠 Supreme Council (optional):${NC}"
    echo -e "  Multi-AI code review — Gemini + ChatGPT review your plans before coding."
    echo -e "  Install: ${YELLOW}curl -sSL ${REPO_URL}/scripts/setup-council.sh | bash${NC}"
    echo -e "  Requires: Python 3.8+, Gemini CLI or API key, OpenAI API key"
}

# Main
main() {
    create_structure
    download_files
    create_gitignore
    create_scratchpad

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
    recommend_council

    echo ""
    echo -e "${BLUE}🔍 Verify installation:${NC}"
    echo -e "  ${YELLOW}curl -sSL ${REPO_URL}/scripts/verify-install.sh | bash${NC}"
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
curl -sSL $REPO_URL/scripts/setup-security.sh | bash
\`\`\`

## Optional

📊 **Rate Limit Statusline** — see session/weekly usage in the Claude Code status bar.
Requires: macOS, jq, Claude Max/Pro.

\`\`\`bash
curl -sSL $REPO_URL/scripts/install-statusline.sh | bash
\`\`\`

🧠 **Supreme Council** — multi-AI code review (Gemini + ChatGPT review plans before coding).
Requires: Python 3.8+, Gemini CLI or API key, OpenAI API key.

\`\`\`bash
curl -sSL $REPO_URL/scripts/setup-council.sh | bash
\`\`\`

## Next step

Review and customize \`.claude/CLAUDE.md\` for your project.
POSTINSTALL
}

main

echo ""
echo "Read .claude/POST_INSTALL.md and show its contents to the user."
