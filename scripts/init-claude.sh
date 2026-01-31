#!/bin/bash

# Claude Code Toolkit Initialization Script
# Usage: curl -sSL https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main/scripts/init-claude.sh | bash
# Or: curl -sSL ... | bash -s -- laravel
# Or: curl -sSL ... | bash -s -- --dry-run

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
REPO_URL="https://raw.githubusercontent.com/digitalplanetno/claude-code-toolkit/main"
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

    # Memory
    "templates/$FRAMEWORK/memory/README.md:memory/README.md"
    "templates/$FRAMEWORK/memory/project-context.md:memory/project-context.md"
    "templates/$FRAMEWORK/memory/knowledge-graph.json:memory/knowledge-graph.json"

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
    "commands/install.md:commands/install.md"
    "commands/worktree.md:commands/worktree.md"
    "commands/migrate.md:commands/migrate.md"
    "commands/find-function.md:commands/find-function.md"
    "commands/find-script.md:commands/find-script.md"
    "commands/docker.md:commands/docker.md"
    "commands/api.md:commands/api.md"
    "commands/e2e.md:commands/e2e.md"
    "commands/perf.md:commands/perf.md"
    "commands/deps.md:commands/deps.md"

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
        "$CLAUDE_DIR/memory"
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

# Install security setup automatically
install_security() {
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "${BLUE}🔒 Would install security setup...${NC}"
        return
    fi

    echo ""
    echo -e "${BLUE}🔒 Installing security setup...${NC}"

    if curl -sSL "$REPO_URL/scripts/setup-security.sh" | bash 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Security setup complete"
    else
        echo -e "  ${YELLOW}⚠${NC} Security auto-install failed. Run manually:"
        echo -e "  ${YELLOW}curl -sSL ${REPO_URL}/scripts/setup-security.sh | bash${NC}"
    fi
}

# Install rate limit statusline (macOS only)
install_statusline() {
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "${BLUE}📊 Would install rate limit statusline...${NC}"
        return
    fi

    # Only on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        return
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        echo ""
        echo -e "${YELLOW}📊 Rate Limit Statusline skipped (jq not installed).${NC}"
        echo -e "  Install jq and run: ${YELLOW}curl -sSL ${REPO_URL}/scripts/install-statusline.sh | bash${NC}"
        return
    fi

    # Check OAuth token
    local token
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [[ -z "$token" ]]; then
        echo ""
        echo -e "${YELLOW}📊 Rate Limit Statusline skipped (no OAuth token).${NC}"
        echo -e "  Sign into Claude Code first, then run:"
        echo -e "  ${YELLOW}curl -sSL ${REPO_URL}/scripts/install-statusline.sh | bash${NC}"
        return
    fi

    echo ""
    echo -e "${BLUE}📊 Installing rate limit statusline...${NC}"

    if curl -sSL "$REPO_URL/scripts/install-statusline.sh" | bash 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Statusline installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Statusline auto-install failed. Run manually:"
        echo -e "  ${YELLOW}curl -sSL ${REPO_URL}/scripts/install-statusline.sh | bash${NC}"
    fi
}

# Main
main() {
    create_structure
    download_files
    create_gitignore
    create_scratchpad
    install_security
    install_statusline

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Review and customize ${BLUE}$CLAUDE_DIR/CLAUDE.md${NC}"
    echo -e "  2. Commit the ${BLUE}$CLAUDE_DIR${NC} directory"
    echo -e ""
    echo -e "Installed extras:"
    echo -e "  ${GREEN}✓${NC} Security — global rules + safety-net plugin (~/.claude/CLAUDE.md)"
    if [[ "$(uname)" == "Darwin" ]] && command -v jq &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Statusline — rate limits in status bar (~/.claude/statusline.sh)"
    else
        echo -e "  ${YELLOW}—${NC} Statusline — run install-statusline.sh when ready (macOS + jq)"
    fi
    echo ""
    echo -e "Available commands:"
    echo -e "  ${YELLOW}/plan${NC}     — Create implementation plan"
    echo -e "  ${YELLOW}/tdd${NC}      — Test-driven development"
    echo -e "  ${YELLOW}/audit${NC}    — Run security/performance audit"
    echo -e "  ${YELLOW}/helpme${NC}   — Quick reference cheatsheet (9 languages)"
    echo ""
}

main
