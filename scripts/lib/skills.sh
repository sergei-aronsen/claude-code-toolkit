#!/bin/bash

# Claude Code Toolkit — Skills Catalog Loader + Detection + Install Helper (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   skills_catalog_names           — prints 24 skill names one-per-line (alpha sorted)
#   is_skill_installed <name>      — returns 0 (installed) / 1 (not installed)
#   skills_status_array            — populates TUI_INSTALLED[] for install.sh --skills branch
#   skills_install <name> [--force] — copies skill from mirror to target via cp -R
# Globals (write):
#   SKILLS_CATALOG[]   — 24 curated skill names (alpha order); populated at source time
#   TUI_INSTALLED[]    — populated by skills_status_array (parallel to SKILLS_CATALOG)
# Test seams:
#   TK_SKILLS_HOME                    — override $HOME/.claude/skills/ probe path (used by is_skill_installed)
#   TK_SKILLS_MIRROR_PATH             — override templates/skills-marketplace/ source path (used by skills_install)
#   TK_SKILLS_INSTALL_IMPECCABLE_CMD  — override resolved install-impeccable.sh path (used by skills_install for `impeccable`)
#   TK_SKILLS_TARBALL_CMD             — stub command for skills_fetch_mirror_via_tarball; takes (dest_tgz_path, tar_url),
#                                       writes a tarball to dest. Used by hermetic tests in lieu of real curl.
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

# Curated 24-skill catalog — SKILL-01 source of truth.
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
  huashu-design
  i18n-localization
  impeccable
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

# skills_catalog_names — print all 24 skill names from SKILLS_CATALOG, one per line.
skills_catalog_names() {
    printf '%s\n' "${SKILLS_CATALOG[@]}"
}

# _skills_description <name> — extract one-line description from SKILL.md frontmatter.
# Reads `description:` from the YAML frontmatter block (between `---` markers).
# Handles inline string + YAML block scalars (`|`, `>`, `>-`, `>+`).
# Returns first sentence (truncated at ". "), capped at 95 chars on word boundary.
# Empty output when SKILL.md missing or no description field — caller renders no line.
# impeccable is special-cased: not vendored under templates/skills-marketplace/, so
# we hardcode a short blurb. Other skills read from the mirror dir.
_skills_description() {
    local name="${1:-}"
    [[ -z "$name" ]] && return 0
    if [[ "$name" == "impeccable" ]]; then
        echo "Senior-engineer planning + execution workflow (installed via npx)"
        return 0
    fi
    # ai-models SKILL.md has no YAML frontmatter — use hardcoded blurb.
    if [[ "$name" == "ai-models" ]]; then
        echo "Current AI model IDs and pricing for Anthropic / OpenAI / Google APIs"
        return 0
    fi
    local mirror f
    mirror="$(_skills_default_mirror_path)"
    f="${mirror}/${name}/SKILL.md"
    [[ ! -f "$f" ]] && return 0

    local in_fm=0 cont=0 line val desc=""
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---" ]]; then
            if [[ $in_fm -eq 0 ]]; then in_fm=1; continue; else break; fi
        fi
        [[ $in_fm -eq 0 ]] && continue
        if [[ $cont -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]+ ]]; then
                local trimmed="${line#"${line%%[![:space:]]*}"}"
                desc="${desc:+${desc} }${trimmed}"
                continue
            else
                cont=0
            fi
        fi
        if [[ "$line" =~ ^description:[[:space:]]*(.*)$ ]]; then
            val="${BASH_REMATCH[1]}"
            # YAML block scalar marker (`|`, `>`, `>-`, `>+`) → continuation
            if [[ "$val" =~ ^[\|\>][-+]?$ ]]; then
                cont=1
                continue
            fi
            # Empty inline value → implicit multi-line plain scalar (indented next lines)
            if [[ -z "$val" ]]; then
                cont=1
                continue
            fi
            val="${val#\"}"; val="${val%\"}"
            val="${val#\'}"; val="${val%\'}"
            desc="$val"
        fi
    done < "$f"

    [[ -z "$desc" ]] && return 0

    if [[ "$desc" == *". "* ]]; then
        desc="${desc%%. *}."
    fi
    if [[ ${#desc} -gt 95 ]]; then
        desc="${desc:0:95}"
        if [[ "$desc" == *" "* ]]; then
            desc="${desc% *}…"
        else
            desc+="…"
        fi
    fi

    echo "$desc"
}

# is_skill_installed <name> — directory probe.
# Returns 0 when ~/.claude/skills/<name>/ OR ~/.claude/skills/?-<name>/
# exists (single-char-prefix form covers skills-marketplace's `i-<name>/`
# layout and any other 1-char prefix scheme — `p-`, `m-`, etc.). Returns
# 1 when absent. Two-state return (no CLI dependency — skills have no
# binary requirement). Override probe root with TK_SKILLS_HOME for
# hermetic tests.
is_skill_installed() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} is_skill_installed: missing argument" >&2
        return 1
    fi
    local home
    home="$(_skills_default_home)"
    # Toolkit's own layout (no prefix).
    [[ -d "${home}/${name}" ]] && return 0
    # Marketplace layout: single-char prefix + dash + name.
    local d
    for d in "${home}/"?-"${name}"; do
        [[ -d "$d" ]] && return 0
    done
    return 1
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

    # impeccable carries ~250KB of payload + ~25 .mjs scripts that need
    # node at runtime, so it's not vendored under templates/skills-marketplace/.
    # Delegate to install-impeccable.sh which wraps the upstream
    # `npx impeccable@latest skills install` CLI and writes
    # ~/.claude/skills/impeccable/ from a $HOME cwd. Test seam
    # TK_SKILLS_INSTALL_IMPECCABLE_CMD lets hermetic tests stub the wrapper.
    if [[ "$name" == "impeccable" ]]; then
        local impeccable_cmd="${TK_SKILLS_INSTALL_IMPECCABLE_CMD:-}"
        if [[ -z "$impeccable_cmd" ]]; then
            local skills_dir
            skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
            impeccable_cmd="${skills_dir}/../install-impeccable.sh"
        fi
        if [[ ! -f "$impeccable_cmd" ]]; then
            echo -e "${RED}✗${NC} skills_install: install-impeccable.sh not found at $impeccable_cmd" >&2
            return 1
        fi
        local impeccable_args=()
        [[ "$force" -eq 1 ]] && impeccable_args+=("--yes")
        bash "$impeccable_cmd" "${impeccable_args[@]+"${impeccable_args[@]}"}" || return 1
        return 0
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
    # Refuse to write ${target} when a marketplace-prefixed install
    # (e.g. i-<name>/) already provides the skill. Without this guard,
    # `--force` reinstall would create a duplicate <name>/ alongside
    # the existing ?-<name>/ and Claude Code would load both as
    # separate skills (different `name:` frontmatter). Toolkit does
    # not own marketplace-managed dirs — leave them untouched.
    local prefixed
    for prefixed in "${home}/"?-"${name}"; do
        if [[ -d "$prefixed" ]]; then
            return 2
        fi
    done
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

# skills_fetch_mirror_via_tarball — download the toolkit tarball and export
# TK_SKILLS_MIRROR_PATH + TK_SKILLS_INSTALL_IMPECCABLE_CMD so subsequent
# skills_install calls resolve sources from the extracted tree instead of
# the BASH_SOURCE-relative path (which is wrong under curl-pipe because
# install.sh sources scripts/lib/skills.sh from /tmp/skills-XXXXXX).
#
# Reads env:
#   TK_TOOLKIT_REF        — branch/tag/SHA passed to the GitHub archive URL.
#                           Defaults to "main". Allowlisted by install.sh
#                           before this function runs (regex [A-Za-z0-9._/-]+,
#                           no `..`).
#   TK_USER_AGENT         — curl User-Agent. Defaults to a placeholder so a
#                           non-toolkit caller can still invoke this directly.
#   TK_SKILLS_TARBALL_CMD — test seam. When set, invoked as
#                             "$TK_SKILLS_TARBALL_CMD <dest_tgz> <tar_url>"
#                           and expected to write a tarball to dest. Skips
#                           the curl call entirely. Production callers leave
#                           this unset.
#   TMPDIR                — base for mktemp; macOS default $TMPDIR honored.
#
# Writes env:
#   TK_SKILLS_MIRROR_PATH               — extracted templates/skills-marketplace
#   TK_SKILLS_INSTALL_IMPECCABLE_CMD    — extracted scripts/install-impeccable.sh
#
# Returns 0 on success, 1 on any failure (mktemp, fetch, tar extract, or a
# missing path inside the tarball). On failure neither env var is exported.
skills_fetch_mirror_via_tarball() {
    local ref="${TK_TOOLKIT_REF:-main}"
    local tar_url="https://github.com/sergei-aronsen/claude-code-toolkit/archive/${ref}.tar.gz"
    local tar_tmp tar_dir
    tar_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-skills-tar-XXXXXX.tgz") || return 1
    tar_dir=$(mktemp -d "${TMPDIR:-/tmp}/tk-skills-extract-XXXXXX") || {
        rm -f "$tar_tmp"
        return 1
    }
    if [[ -n "${TK_SKILLS_TARBALL_CMD:-}" ]]; then
        "$TK_SKILLS_TARBALL_CMD" "$tar_tmp" "$tar_url" || {
            rm -rf "$tar_dir"; rm -f "$tar_tmp"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -sSLf \
            -A "${TK_USER_AGENT:-claude-code-toolkit-installer}" \
            --max-time 120 --connect-timeout 10 \
            --retry 2 --retry-delay 2 \
            "$tar_url" -o "$tar_tmp" || {
            rm -rf "$tar_dir"; rm -f "$tar_tmp"
            return 1
        }
    else
        rm -rf "$tar_dir"; rm -f "$tar_tmp"
        return 1
    fi
    # --strip-components=1 peels the GitHub-injected `<owner>-<repo>-<sha>/`
    # prefix so paths inside $tar_dir start at `templates/`, `scripts/`, etc.
    tar -xzf "$tar_tmp" -C "$tar_dir" --strip-components=1 2>/dev/null || {
        rm -rf "$tar_dir"; rm -f "$tar_tmp"
        return 1
    }
    rm -f "$tar_tmp"
    if [[ ! -d "$tar_dir/templates/skills-marketplace" ]]; then
        rm -rf "$tar_dir"
        return 1
    fi
    if [[ ! -f "$tar_dir/scripts/install-impeccable.sh" ]]; then
        rm -rf "$tar_dir"
        return 1
    fi
    export TK_SKILLS_MIRROR_PATH="$tar_dir/templates/skills-marketplace"
    export TK_SKILLS_INSTALL_IMPECCABLE_CMD="$tar_dir/scripts/install-impeccable.sh"
    return 0
}
