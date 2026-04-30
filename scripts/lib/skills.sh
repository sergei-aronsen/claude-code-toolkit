#!/bin/bash

# Claude Code Toolkit — Skills Catalog Loader + Detection + Install Helper (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   skills_catalog_names           — prints 22 skill names one-per-line (alpha sorted)
#   is_skill_installed <name>      — returns 0 (installed) / 1 (not installed)
#   skills_status_array            — populates TUI_INSTALLED[] for install.sh --skills branch
#   skills_install <name> [--force] — copies skill from mirror to target via cp -R
# Globals (write):
#   SKILLS_CATALOG[]   — 22 curated skill names (alpha order); populated at source time
#   TUI_INSTALLED[]    — populated by skills_status_array (parallel to SKILLS_CATALOG)
# Test seams:
#   TK_SKILLS_HOME          — override $HOME/.claude/skills/ probe path (used by is_skill_installed)
#   TK_SKILLS_MIRROR_PATH   — override templates/skills-marketplace/ source path (used by skills_install)
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
# shellcheck disable=SC2034
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
# shellcheck disable=SC2034
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
# shellcheck disable=SC2034
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'

# Curated 22-skill catalog — SKILL-01 source of truth.
# Alphabetical order. Do NOT add or remove without updating REQUIREMENTS.md SKILL-01.
# shellcheck disable=SC2034
SKILLS_CATALOG=(
  ai-models
  analytics-tracking
  chrome-extension-development
  copywriting
  docx
  find-skills
  firecrawl
  i18n-localization
  memo-skill
  next-best-practices
  notebooklm
  pdf
  resend
  seo-audit
  shadcn
  stripe-best-practices
  tailwind-design-system
  typescript-advanced-types
  ui-ux-pro-max
  vercel-composition-patterns
  vercel-react-best-practices
  webapp-testing
)

# Internal helper — resolves probe target directory honoring TK_SKILLS_HOME seam.
_skills_default_home() {
    echo "${TK_SKILLS_HOME:-$HOME/.claude/skills}"
}

# Internal helper — resolves source mirror path honoring TK_SKILLS_MIRROR_PATH seam.
# Mirrors _mcp_default_catalog_path pattern from mcp.sh: BASH_SOURCE-relative resolution.
_skills_default_mirror_path() {
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
    echo "${TK_SKILLS_MIRROR_PATH:-${d}/../../templates/skills-marketplace}"
}

# skills_catalog_names — print all 22 skill names from SKILLS_CATALOG, one per line.
skills_catalog_names() {
    printf '%s\n' "${SKILLS_CATALOG[@]}"
}

# is_skill_installed <name> — directory probe.
# Returns 0 when ~/.claude/skills/<name>/ exists, 1 when absent.
# Two-state return (no CLI dependency — skills have no binary requirement).
# Override probe root with TK_SKILLS_HOME for hermetic tests.
is_skill_installed() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} is_skill_installed: missing argument" >&2
        return 1
    fi
    local home
    home="$(_skills_default_home)"
    [[ -d "${home}/${name}" ]]
}

# skills_status_array — populate TUI_INSTALLED[] for the install.sh --skills branch.
# Mirrors mcp_status_array pattern from mcp.sh.
# Side effects: writes TUI_INSTALLED[] (parallel to SKILLS_CATALOG order).
# Globals (write):
#   TUI_INSTALLED[]  — 1 if installed, 0 if not; indexed by SKILLS_CATALOG position
# shellcheck disable=SC2034
skills_status_array() {
    TUI_INSTALLED=()
    local count=${#SKILLS_CATALOG[@]}
    local i name
    for ((i=0; i<count; i++)); do
        name="${SKILLS_CATALOG[$i]}"
        if is_skill_installed "$name"; then
            TUI_INSTALLED+=(1)
        else
            TUI_INSTALLED+=(0)
        fi
    done
}

# skills_install <name> [--force] — copy one skill from mirror to target directory.
# Source: TK_SKILLS_MIRROR_PATH (default: <repo>/templates/skills-marketplace/<name>/)
# Target: TK_SKILLS_HOME (default: ~/.claude/skills/<name>/)
# Copy method: cp -R (NOT rsync — SKILL-03 explicit choice).
# Returns:
#   0  success
#   1  missing source dir, mkdir failure, or cp failure
#   2  target already exists and --force not passed
skills_install() {
    local name="${1:-}"
    local force=0
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force=1; shift ;;
            *) shift ;;
        esac
    done
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} skills_install: missing skill name" >&2
        return 1
    fi
    local mirror src target home
    mirror="$(_skills_default_mirror_path)"
    src="${mirror}/${name}"
    home="$(_skills_default_home)"
    target="${home}/${name}"
    if [[ ! -d "$src" ]]; then
        echo -e "${RED}✗${NC} skills_install: source missing: $src" >&2
        return 1
    fi
    if [[ -d "$target" && "$force" -ne 1 ]]; then
        return 2
    fi
    if [[ -d "$target" && "$force" -eq 1 ]]; then
        # Audit L3: defense in depth — refuse to recurse-delete `/`,
        # empty string, or any single-slash variant before invoking
        # `rm -rf`. Mirrors the guard pattern in scripts/lib/state.sh.
        if [[ -z "$target" || "$target" == "/" || "$target" == "//" ]]; then
            echo -e "${RED}✗${NC} skills_install: refusing rm -rf on suspicious target: ${target@Q}" >&2
            return 1
        fi
        rm -rf "$target" || return 1
    fi
    mkdir -p "$home" || return 1
    cp -R "$src" "$target" || return 1
    return 0
}
