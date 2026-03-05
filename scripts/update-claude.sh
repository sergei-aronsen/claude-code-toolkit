#!/bin/bash

# Claude Code Toolkit — Smart Update Script
# Updates toolkit files while preserving user customizations in CLAUDE.md

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR=".claude"
MANIFEST_URL="$REPO_URL/manifest.json"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

detect_framework() {
    if [[ -f "artisan" ]]; then
        echo "laravel"
    elif [[ -f "bin/rails" ]] || [[ -f "config/application.rb" ]]; then
        echo "rails"
    elif [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "next.config.ts" ]]; then
        echo "nextjs"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
        echo "python"
    elif [[ -f "package.json" ]]; then
        echo "nodejs"
    else
        echo "base"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Claude Code Toolkit — Smart Update                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if .claude exists
if [[ ! -d "$CLAUDE_DIR" ]]; then
    log_error "$CLAUDE_DIR not found. Run init-claude.sh first:"
    echo "  curl -sSL $REPO_URL/scripts/init-claude.sh | bash"
    exit 1
fi

# Detect framework
FRAMEWORK=$(detect_framework)
log_info "Detected framework: ${CYAN}$FRAMEWORK${NC}"

# Download manifest
log_info "Fetching manifest..."
MANIFEST=$(curl -sSL "$MANIFEST_URL" 2>/dev/null)
if [[ -z "$MANIFEST" ]]; then
    log_error "Failed to fetch manifest"
    exit 1
fi

REMOTE_VERSION=$(echo "$MANIFEST" | grep -o '"version": "[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Remote version: ${CYAN}$REMOTE_VERSION${NC}"

# Check local version
LOCAL_VERSION="unknown"
if [[ -f "$CLAUDE_DIR/.toolkit-version" ]]; then
    LOCAL_VERSION=$(cat "$CLAUDE_DIR/.toolkit-version")
fi
log_info "Local version: ${CYAN}$LOCAL_VERSION${NC}"

# Backup
BACKUP_DIR=".claude-backup-$(date +%Y%m%d-%H%M%S)"
cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
log_success "Backup created: $BACKUP_DIR"

TEMPLATE_URL="$REPO_URL/templates/$FRAMEWORK"

# ============================================================================
# UPDATE FILES (agents, prompts, skills, memory)
# ============================================================================

echo ""
log_info "Updating toolkit files..."

# Agents
for file in agents/code-reviewer.md agents/planner.md agents/security-auditor.md agents/test-writer.md; do
    mkdir -p "$CLAUDE_DIR/$(dirname "$file")"
    if curl -sSL "$TEMPLATE_URL/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null; then
        log_success "Updated: $file"
    else
        # Try base template
        if curl -sSL "$REPO_URL/templates/base/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null; then
            log_success "Updated: $file (from base)"
        else
            log_warning "Skipped: $file"
        fi
    fi
done

# Prompts
for file in prompts/CODE_REVIEW.md prompts/DEPLOY_CHECKLIST.md prompts/DESIGN_REVIEW.md \
            prompts/MYSQL_PERFORMANCE_AUDIT.md prompts/PERFORMANCE_AUDIT.md \
            prompts/POSTGRES_PERFORMANCE_AUDIT.md prompts/SECURITY_AUDIT.md; do
    mkdir -p "$CLAUDE_DIR/$(dirname "$file")"
    if curl -sSL "$TEMPLATE_URL/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null; then
        log_success "Updated: $file"
    else
        if curl -sSL "$REPO_URL/templates/base/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null; then
            log_success "Updated: $file (from base)"
        else
            log_warning "Skipped: $file"
        fi
    fi
done

# Skills
mkdir -p "$CLAUDE_DIR/skills/ai-models"
if curl -sSL "$REPO_URL/templates/base/skills/ai-models/SKILL.md" -o "$CLAUDE_DIR/skills/ai-models/SKILL.md" 2>/dev/null; then
    log_success "Updated: skills/ai-models/SKILL.md"
else
    log_warning "Skipped: skills/ai-models/SKILL.md"
fi

# Don't overwrite skill-rules.json if exists (user customizations)
if [[ ! -f "$CLAUDE_DIR/skills/skill-rules.json" ]]; then
    curl -sSL "$REPO_URL/templates/base/skills/skill-rules.json" -o "$CLAUDE_DIR/skills/skill-rules.json" 2>/dev/null && \
        log_success "Created: skills/skill-rules.json"
fi

# Rules templates (don't overwrite if exists)
mkdir -p "$CLAUDE_DIR/rules"
for file in rules/README.md rules/project-context.md; do
    if [[ ! -f "$CLAUDE_DIR/$file" ]]; then
        curl -sSL "$REPO_URL/templates/base/$file" -o "$CLAUDE_DIR/$file" 2>/dev/null && \
            log_success "Created: $file"
    fi
done

# ============================================================================
# SMART MERGE CLAUDE.md
# ============================================================================

echo ""
log_info "Updating CLAUDE.md (preserving user sections)..."

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD_NEW=$(mktemp)

# Download new template
if ! curl -sSL "$TEMPLATE_URL/CLAUDE.md" -o "$CLAUDE_MD_NEW" 2>/dev/null; then
    curl -sSL "$REPO_URL/templates/base/CLAUDE.md" -o "$CLAUDE_MD_NEW" 2>/dev/null
fi

if [[ -f "$CLAUDE_MD" ]] && [[ -f "$CLAUDE_MD_NEW" ]]; then
    # Extract user sections from current CLAUDE.md
    # These sections contain project-specific customizations

    USER_SECTIONS_FILE=$(mktemp)

    # Extract Project Overview section
    sed -n '/^## 🎯 Project Overview/,/^## [^P]/p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.overview" 2>/dev/null || true

    # Extract Project Structure section
    sed -n '/^## 📁 Project Structure/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.structure" 2>/dev/null || true

    # Extract Essential Commands section
    sed -n '/^## ⚡ Essential Commands/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.commands" 2>/dev/null || true

    # Extract Project-Specific Notes section
    sed -n '/^## ⚠️ Project-Specific Notes/,/^## /p' "$CLAUDE_MD" | head -n -1 > "$USER_SECTIONS_FILE.notes" 2>/dev/null || true

    # If no user sections extracted, this might be first install or different format
    # In that case, just use the new template

    HAS_USER_CONTENT=false
    for section in overview structure commands notes; do
        if [[ -s "$USER_SECTIONS_FILE.$section" ]]; then
            # Check if it's not just placeholder text
            if ! grep -q '\[Project Name\]\|\[Framework\]\|\[command\]\|\[List project' "$USER_SECTIONS_FILE.$section" 2>/dev/null; then
                HAS_USER_CONTENT=true
                break
            fi
        fi
    done

    if [[ "$HAS_USER_CONTENT" == "true" ]]; then
        log_info "Found user customizations, merging..."

        # Start with new template
        cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"

        # Replace placeholder sections with user content
        # This is a simplified approach - for each user section, replace the placeholder in new template

        for section in overview structure commands notes; do
            if [[ -s "$USER_SECTIONS_FILE.$section" ]]; then
                # Get the section header pattern
                case $section in
                    overview)  PATTERN="## 🎯 Project Overview" ;;
                    structure) PATTERN="## 📁 Project Structure" ;;
                    commands)  PATTERN="## ⚡ Essential Commands" ;;
                    notes)     PATTERN="## ⚠️ Project-Specific Notes" ;;
                esac

                # Find line numbers for replacement
                START_LINE=$(grep -n "^$PATTERN" "$CLAUDE_MD" | head -1 | cut -d: -f1)
                if [[ -n "$START_LINE" ]]; then
                    # Find next section
                    END_LINE=$(tail -n +$((START_LINE + 1)) "$CLAUDE_MD" | grep -n "^## " | head -1 | cut -d: -f1)
                    if [[ -n "$END_LINE" ]]; then
                        END_LINE=$((START_LINE + END_LINE - 1))
                    else
                        END_LINE=$(wc -l < "$CLAUDE_MD")
                    fi

                    # Replace section
                    {
                        head -n $((START_LINE - 1)) "$CLAUDE_MD"
                        cat "$USER_SECTIONS_FILE.$section"
                        tail -n +$((END_LINE + 1)) "$CLAUDE_MD"
                    } > "$CLAUDE_MD.tmp"
                    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
                fi
            fi
        done

        log_success "CLAUDE.md merged (user sections preserved)"
    else
        log_info "No user customizations found, using new template"
        cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"
        log_success "CLAUDE.md updated"
    fi

    # Cleanup temp files
    rm -f "$USER_SECTIONS_FILE"* "$CLAUDE_MD_NEW"
else
    # No existing CLAUDE.md, just copy new one
    cp "$CLAUDE_MD_NEW" "$CLAUDE_MD"
    log_success "CLAUDE.md created"
    rm -f "$CLAUDE_MD_NEW"
fi

# ============================================================================
# SAVE VERSION
# ============================================================================

echo "$REMOTE_VERSION" > "$CLAUDE_DIR/.toolkit-version"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Update Complete!                                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Version: ${CYAN}$LOCAL_VERSION${NC} → ${CYAN}$REMOTE_VERSION${NC}"
echo -e "Backup:  ${CYAN}$BACKUP_DIR${NC}"
echo ""
echo -e "${YELLOW}What was updated:${NC}"
echo "  • agents/       — subagent definitions"
echo "  • prompts/      — audit templates"
echo "  • skills/       — AI models skill"
echo "  • CLAUDE.md     — system sections (user sections preserved)"
echo ""
echo -e "${YELLOW}What was preserved:${NC}"
echo "  • Project Overview, Structure, Commands"
echo "  • Project-Specific Notes, Known Gotchas"
echo "  • settings.json, settings.local.json"
echo "  • rules/ content (if existed)"
echo "  • skills/skill-rules.json (if existed)"
echo ""
echo -e "${CYAN}Changelog:${NC} https://github.com/sergei-aronsen/claude-code-toolkit/blob/main/CHANGELOG.md"
echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
