#!/bin/bash
# init-local.sh — Initialize Claude Code configuration from local claude-guides
#
# Usage:
#   /path/to/claude-guides/scripts/init-local.sh [--dry-run] [framework]
#
# Frameworks: laravel, nextjs, django, rails, golang, rust, auto (default)

set -e

VERSION="1.1.0"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLAUDE_DIR=".claude"
PROMPTS_DIR="$CLAUDE_DIR/prompts"

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
            echo "claude-guides v$VERSION"
            exit 0
            ;;
        --help|-h)
            echo "Usage: init-local.sh [--dry-run] [framework]"
            echo ""
            echo "Frameworks: laravel, nextjs, django, rails, golang, rust, nodejs, generic"
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

echo -e "${BLUE}Claude Code Configuration Initializer v$VERSION (Local)${NC}"
echo "======================================================"
echo -e "Source: ${YELLOW}$GUIDES_DIR${NC}"
echo ""

# Detect framework
detect_framework() {
    if [ -f "artisan" ]; then
        echo "laravel"
    elif [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
        echo "nextjs"
    elif [ -f "manage.py" ] && grep -q "django" requirements.txt 2>/dev/null; then
        echo "django"
    elif [ -f "Gemfile" ] && grep -q "rails" Gemfile 2>/dev/null; then
        echo "rails"
    elif [ -f "go.mod" ]; then
        echo "golang"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    elif [ -f "package.json" ]; then
        echo "nodejs"
    else
        echo "generic"
    fi
}

# Use provided framework or detect
if [ -z "$FRAMEWORK" ]; then
    FRAMEWORK=$(detect_framework)
fi

echo -e "Detected framework: ${GREEN}$FRAMEWORK${NC}"

# Determine template path based on framework
case $FRAMEWORK in
    laravel)
        TEMPLATE_PATH="$GUIDES_DIR/templates/laravel"
        ;;
    nextjs)
        TEMPLATE_PATH="$GUIDES_DIR/templates/nextjs"
        ;;
    django|rails|golang|rust)
        TEMPLATE_PATH="$GUIDES_DIR/templates/base"
        echo -e "${YELLOW}Note: Using base templates. Framework-specific templates coming soon.${NC}"
        ;;
    *)
        TEMPLATE_PATH="$GUIDES_DIR/templates/base"
        ;;
esac

# Templates to copy
TEMPLATES=(
    "SECURITY_AUDIT.md"
    "PERFORMANCE_AUDIT.md"
    "CODE_REVIEW.md"
    "DEPLOY_CHECKLIST.md"
)

echo ""

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}DRY RUN MODE — No changes will be made${NC}"
    echo ""
    echo "Would create:"
    echo "  $CLAUDE_DIR/"
    echo "  ├── prompts/"
    for template in "${TEMPLATES[@]}"; do
        echo "  │   └── $template"
    done
    echo "  ├── commands/"
    for cmd in "$GUIDES_DIR/commands"/*.md; do
        if [ -f "$cmd" ]; then
            echo "  │   └── $(basename "$cmd")"
        fi
    done
    echo "  ├── cheatsheets/"
    for cs in "$GUIDES_DIR/cheatsheets"/*.md; do
        if [ -f "$cs" ]; then
            echo "  │   └── $(basename "$cs")"
        fi
    done
    echo "  └── reports/"
    if [ ! -f "CLAUDE.md" ]; then
        echo "  CLAUDE.md"
    else
        echo "  CLAUDE.md (already exists, would skip)"
    fi
    echo ""
    echo "Source: $TEMPLATE_PATH/"
    echo ""
    echo -e "Run without ${CYAN}--dry-run${NC} to apply changes."
    exit 0
fi

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$PROMPTS_DIR"
mkdir -p "$CLAUDE_DIR/reports"

echo -e "${YELLOW}Copying templates from $TEMPLATE_PATH...${NC}"

# Copy templates
COPIED=0
FAILED=0

for template in "${TEMPLATES[@]}"; do
    echo -n "  - $template... "

    if [ -f "$TEMPLATE_PATH/prompts/$template" ]; then
        cp "$TEMPLATE_PATH/prompts/$template" "$PROMPTS_DIR/$template"
        echo -e "${GREEN}OK${NC}"
        COPIED=$((COPIED + 1))
    elif [ -f "$GUIDES_DIR/templates/base/prompts/$template" ]; then
        cp "$GUIDES_DIR/templates/base/prompts/$template" "$PROMPTS_DIR/$template"
        echo -e "${YELLOW}OK (base)${NC}"
        COPIED=$((COPIED + 1))
    else
        echo -e "${RED}NOT FOUND${NC}"
        FAILED=$((FAILED + 1))
    fi
done

# Copy commands if they exist
if [ -d "$GUIDES_DIR/commands" ]; then
    echo ""
    echo -e "${YELLOW}Copying commands...${NC}"
    mkdir -p "$CLAUDE_DIR/commands"

    for cmd in "$GUIDES_DIR/commands"/*.md; do
        if [ -f "$cmd" ]; then
            filename=$(basename "$cmd")
            cp "$cmd" "$CLAUDE_DIR/commands/$filename"
            echo -e "  - $filename... ${GREEN}OK${NC}"
        fi
    done
fi

# Copy cheatsheets if they exist
if [ -d "$GUIDES_DIR/cheatsheets" ]; then
    echo ""
    echo -e "${YELLOW}Copying cheatsheets...${NC}"
    mkdir -p "$CLAUDE_DIR/cheatsheets"

    for cs in "$GUIDES_DIR/cheatsheets"/*.md; do
        if [ -f "$cs" ]; then
            filename=$(basename "$cs")
            cp "$cs" "$CLAUDE_DIR/cheatsheets/$filename"
            echo -e "  - $filename... ${GREEN}OK${NC}"
        fi
    done
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "CLAUDE.md" ]; then
    echo ""
    echo -e "${YELLOW}Creating CLAUDE.md...${NC}"

    PROJECT_NAME=$(basename "$(pwd)")

    cat > CLAUDE.md << EOF
# $PROJECT_NAME — Claude Code Instructions

## Project Overview

**Framework:** $FRAMEWORK
**Description:** [Brief description of the project]

---

## Key Directories

\`\`\`
[List your main directories and what they contain]
\`\`\`

---

## Development Workflow

### Running Locally
\`\`\`bash
# Add your local development commands
\`\`\`

### Testing
\`\`\`bash
# Add your test commands
\`\`\`

### Building
\`\`\`bash
# Add your build commands
\`\`\`

---

## Project-Specific Rules

1. [Add project-specific coding rules]
2. [Add architecture decisions]
3. [Add naming conventions]

---

## Available Prompts

Run audits and reviews using the prompts in \`.claude/prompts/\`:

- **Security Audit:** Read \`.claude/prompts/SECURITY_AUDIT.md\`
- **Performance Audit:** Read \`.claude/prompts/PERFORMANCE_AUDIT.md\`
- **Code Review:** Read \`.claude/prompts/CODE_REVIEW.md\`
- **Deploy Checklist:** Read \`.claude/prompts/DEPLOY_CHECKLIST.md\`

---

## Contacts

- **Maintainer:** [Your name]
- **Documentation:** [Link to docs]
EOF

    echo -e "  ${GREEN}Created CLAUDE.md${NC}"
else
    echo ""
    echo -e "${YELLOW}CLAUDE.md already exists, skipping...${NC}"
fi

# Add to .gitignore if needed
if [ -f ".gitignore" ]; then
    if ! grep -q ".claude/reports" .gitignore 2>/dev/null; then
        {
            echo ""
            echo "# Claude Code reports"
            echo ".claude/reports/"
        } >> .gitignore
        echo -e "${YELLOW}Added .claude/reports/ to .gitignore${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Summary:"
echo "  - Copied: $COPIED templates"
if [ $FAILED -gt 0 ]; then
    echo -e "  - Failed: ${RED}$FAILED${NC}"
fi
echo ""
echo "Created structure:"
echo "  .claude/"
echo "  ├── prompts/"
for template in "${TEMPLATES[@]}"; do
    echo "  │   └── $template"
done
if [ -d "$CLAUDE_DIR/commands" ]; then
    echo "  ├── commands/"
    echo "  │   └── ..."
fi
if [ -d "$CLAUDE_DIR/cheatsheets" ]; then
    echo "  ├── cheatsheets/"
    echo "  │   └── ..."
fi
echo "  └── reports/"
echo "  CLAUDE.md"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Edit CLAUDE.md to add project-specific instructions"
echo "2. Customize templates in .claude/prompts/ for your project"
echo "3. Run audits: read the prompt file and follow instructions"
echo ""
