#!/bin/bash
# init-local.sh — Initialize Claude Code configuration from local claude-code-toolkit
#
# Usage:
#   /path/to/claude-code-toolkit/scripts/init-local.sh [--dry-run] [framework]
#
# Frameworks: laravel, nextjs, nodejs, python, go, rails, base, auto (default)

set -euo pipefail

VERSION="2.0.0"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLAUDE_DIR=".claude"

# Flags
DRY_RUN=false
FRAMEWORK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --version|-v)
            echo "claude-code-toolkit v$VERSION (local)"
            exit 0
            ;;
        --help|-h)
            echo "Usage: init-local.sh [--dry-run] [framework]"
            echo ""
            echo "Frameworks: laravel, nextjs, nodejs, python, go, rails, base"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be created"
            echo "  --version    Show version"
            echo "  --help       Show this help"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            FRAMEWORK="$1"
            shift
            ;;
    esac
done

echo -e "${BLUE}Claude Code Toolkit — Local Install v$VERSION${NC}"
echo "======================================================"
echo -e "Source: ${YELLOW}$GUIDES_DIR${NC}"
echo ""

# Detect framework
detect_framework() {
    if [ -f "artisan" ]; then
        echo "laravel"
    elif [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
        echo "nextjs"
    elif [ -f "bin/rails" ] || [ -f "config/application.rb" ]; then
        echo "rails"
    elif [ -f "go.mod" ]; then
        echo "go"
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
        echo "python"
    elif [ -f "package.json" ]; then
        echo "nodejs"
    else
        echo "base"
    fi
}

if [ -z "$FRAMEWORK" ]; then
    FRAMEWORK=$(detect_framework)
fi

TEMPLATE_PATH="$GUIDES_DIR/templates/$FRAMEWORK"
BASE_PATH="$GUIDES_DIR/templates/base"

echo -e "Detected framework: ${GREEN}$FRAMEWORK${NC}"
echo ""

# Helper: copy file with fallback to base template
copy_file() {
    local src="$1"
    local dest="$2"
    local label="${3:-$dest}"

    mkdir -p "$(dirname "$CLAUDE_DIR/$dest")"

    if [ -f "$TEMPLATE_PATH/$src" ]; then
        cp "$TEMPLATE_PATH/$src" "$CLAUDE_DIR/$dest"
        echo -e "  ${GREEN}✓${NC} $label"
    elif [ -f "$BASE_PATH/$src" ]; then
        cp "$BASE_PATH/$src" "$CLAUDE_DIR/$dest"
        echo -e "  ${GREEN}✓${NC} $label (base)"
    elif [ -f "$GUIDES_DIR/$src" ]; then
        cp "$GUIDES_DIR/$src" "$CLAUDE_DIR/$dest"
        echo -e "  ${GREEN}✓${NC} $label"
    else
        echo -e "  ${YELLOW}⚠${NC} $label (not found)"
    fi
}

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}DRY RUN MODE — No changes will be made${NC}"
    echo ""
    echo "Would create:"
    echo "  $CLAUDE_DIR/"
    echo "  ├── prompts/      (7 audit templates)"
    echo "  ├── commands/     (30 slash commands)"
    echo "  ├── agents/       (4 subagent definitions)"
    echo "  ├── skills/       (10 framework skills)"
    echo "  ├── rules/        (auto-loaded project context)"
    echo "  ├── cheatsheets/  (9 languages)"
    echo "  └── scratchpad/   (working notes)"
    echo ""
    echo "Source: $TEMPLATE_PATH/"
    echo -e "Run without ${CYAN}--dry-run${NC} to apply changes."
    exit 0
fi

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$CLAUDE_DIR"/{prompts,commands,agents,skills,rules,cheatsheets,scratchpad}

# ============================================================================
# PROMPTS
# ============================================================================
echo ""
echo -e "${BLUE}Copying prompts...${NC}"
for template in SECURITY_AUDIT.md PERFORMANCE_AUDIT.md CODE_REVIEW.md \
                DEPLOY_CHECKLIST.md DESIGN_REVIEW.md \
                MYSQL_PERFORMANCE_AUDIT.md POSTGRES_PERFORMANCE_AUDIT.md; do
    copy_file "prompts/$template" "prompts/$template"
done

# ============================================================================
# AGENTS
# ============================================================================
echo ""
echo -e "${BLUE}Copying agents...${NC}"
for agent in code-reviewer.md test-writer.md planner.md security-auditor.md; do
    copy_file "agents/$agent" "agents/$agent"
done

# ============================================================================
# SKILLS
# ============================================================================
echo ""
echo -e "${BLUE}Copying skills...${NC}"
copy_file "skills/skill-rules.json" "skills/skill-rules.json"
for skill in ai-models api-design database debugging docker i18n llm-patterns observability tailwind testing; do
    copy_file "skills/$skill/SKILL.md" "skills/$skill/SKILL.md"
done

# ============================================================================
# COMMANDS
# ============================================================================
echo ""
echo -e "${BLUE}Copying commands...${NC}"
for cmd in "$GUIDES_DIR/commands"/*.md; do
    if [ -f "$cmd" ]; then
        filename=$(basename "$cmd")
        cp "$cmd" "$CLAUDE_DIR/commands/$filename"
        echo -e "  ${GREEN}✓${NC} $filename"
    fi
done

# ============================================================================
# CHEATSHEETS
# ============================================================================
echo ""
echo -e "${BLUE}Copying cheatsheets...${NC}"
for cs in "$GUIDES_DIR/cheatsheets"/*.md; do
    if [ -f "$cs" ]; then
        filename=$(basename "$cs")
        cp "$cs" "$CLAUDE_DIR/cheatsheets/$filename"
        echo -e "  ${GREEN}✓${NC} $filename"
    fi
done

# ============================================================================
# RULES
# ============================================================================
echo ""
echo -e "${BLUE}Setting up rules...${NC}"
copy_file "rules/README.md" "rules/README.md"

if [ ! -f "$CLAUDE_DIR/rules/project-context.md" ]; then
    copy_file "rules/project-context.md" "rules/project-context.md"
fi

# Create lessons-learned seed file
LESSONS_FILE="$CLAUDE_DIR/rules/lessons-learned.md"
if [ ! -f "$LESSONS_FILE" ]; then
    cat > "$LESSONS_FILE" << 'LESSONS'
---
description: Audit log of all lessons learned (history only, not auto-loaded)
globs: []
---
# Lessons Learned — Audit Log
<!-- History of lessons saved by /learn. Actual rules are in scoped files (e.g., rules/database.md). -->
LESSONS
    echo -e "  ${GREEN}✓${NC} rules/lessons-learned.md (seed)"
fi

# ============================================================================
# SCRATCHPAD
# ============================================================================
if [ ! -f "$CLAUDE_DIR/scratchpad/current-task.md" ]; then
    cat > "$CLAUDE_DIR/scratchpad/current-task.md" << 'SCRATCHPAD'
# Current Task

<!-- Plan Mode scratchpad. Updated by /plan command. -->
SCRATCHPAD
    echo -e "  ${GREEN}✓${NC} scratchpad/current-task.md"
fi

# ============================================================================
# CLAUDE.md
# ============================================================================
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -f "CLAUDE.md" ]; then
    echo ""
    echo -e "${BLUE}Creating CLAUDE.md...${NC}"
    if [ -f "$TEMPLATE_PATH/CLAUDE.md" ]; then
        cp "$TEMPLATE_PATH/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    else
        cp "$BASE_PATH/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    fi
    echo -e "  ${GREEN}✓${NC} CLAUDE.md"
else
    echo ""
    echo -e "${YELLOW}CLAUDE.md already exists, skipping${NC}"
fi

# ============================================================================
# SETTINGS
# ============================================================================
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    if [ -f "$TEMPLATE_PATH/settings.json" ]; then
        cp "$TEMPLATE_PATH/settings.json" "$CLAUDE_DIR/settings.json"
        echo -e "  ${GREEN}✓${NC} settings.json"
    elif [ -f "$BASE_PATH/settings.json" ]; then
        cp "$BASE_PATH/settings.json" "$CLAUDE_DIR/settings.json"
        echo -e "  ${GREEN}✓${NC} settings.json (base)"
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation Complete!                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Framework: ${CYAN}$FRAMEWORK${NC}"
echo ""
echo "Installed:"
echo "  • prompts/      — 7 audit templates"
echo "  • commands/     — 30 slash commands"
echo "  • agents/       — 4 subagent definitions"
echo "  • skills/       — 10 framework skills"
echo "  • rules/        — auto-loaded project context"
echo "  • cheatsheets/  — 9 language references"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit .claude/CLAUDE.md — add project-specific info"
echo "2. Edit .claude/rules/project-context.md — add architecture facts"
echo "3. Restart Claude Code to apply changes"
echo ""
echo -e "${BLUE}Security setup (recommended):${NC}"
echo "  $GUIDES_DIR/scripts/setup-security.sh"
echo ""
