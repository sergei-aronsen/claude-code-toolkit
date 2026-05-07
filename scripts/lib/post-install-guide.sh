#!/bin/bash
# scripts/lib/post-install-guide.sh
#
# Generator for the post-install setup guide HTML.
# Source this file. Do NOT execute it directly.
#
# Reads:
#   - templates/post-install/_skeleton.html  (outer page with placeholders)
#   - templates/post-install/_styles.css     (inlined into <style>)
#   - templates/post-install/_script.js      (inlined into <script>)
#   - templates/post-install/components/<name>.html  (per-component)
#   - templates/post-install/mcp/<name>.html         (per-MCP)
#   - templates/post-install/mcp/_generic.html       (fallback for unknown MCPs)
#
# Inputs (env / args to post_install_guide_generate):
#   - $TK_GUIDE_INSTALLED   space-separated installed top-level component
#                           labels (e.g. "toolkit security claude-memo")
#   - $TK_GUIDE_MCPS        space-separated MCP names installed (e.g.
#                           "dbhub posthog sentry"); blank if none
#   - $TK_GUIDE_OUTPUT      output path (default $HOME/.claude/setup-guide.html)
#   - $TK_GUIDE_TOOLKIT_VER toolkit version string for the badge
#
# Output: writes one HTML file. Returns 0 on success, 1 on missing
# templates dir, 2 on write failure.
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter
# caller error mode.

# Resolve templates directory — caller can override with TK_GUIDE_TEMPLATES.
post_install_guide_resolve_templates_dir() {
    if [[ -n "${TK_GUIDE_TEMPLATES:-}" ]]; then
        echo "$TK_GUIDE_TEMPLATES"; return
    fi
    # When sourced, BASH_SOURCE points to this lib file.
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [[ -d "$lib_dir/../../templates/post-install" ]]; then
        ( cd "$lib_dir/../../templates/post-install" && pwd )
    elif [[ -d "$HOME/.claude/templates/post-install" ]]; then
        echo "$HOME/.claude/templates/post-install"
    else
        echo ""
    fi
}

# Pretty title from kebab-case component label.
post_install_guide_titleize() {
    local raw="$1"
    case "$raw" in
        toolkit)         echo "Toolkit core" ;;
        security)        echo "Security Pack" ;;
        statusline)      echo "Statusline" ;;
        rtk)             echo "RTK" ;;
        council)         echo "Supreme Council" ;;
        claude-memo)     echo "claude-memo" ;;
        product-thinking) echo "Product Thinking" ;;
        auto-format)     echo "Auto-format on edit" ;;
        bridges|gemini-bridge|codex-bridge) echo "Multi-CLI Bridges" ;;
        *)
            # Default: kebab-to-Title-Case.
            echo "$raw" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
            ;;
    esac
}

# Section icon (single emoji) for the TOC + section header.
post_install_guide_icon() {
    case "$1" in
        toolkit)         echo "🧰" ;;
        security)        echo "🛡️" ;;
        statusline)      echo "📊" ;;
        rtk)             echo "⚡" ;;
        council)         echo "⚖️" ;;
        claude-memo)     echo "🧠" ;;
        product-thinking) echo "🧭" ;;
        auto-format)     echo "🪄" ;;
        bridges|gemini-bridge|codex-bridge) echo "🌉" ;;
        *)            echo "🔌" ;;
    esac
}

# Render a generic MCP fallback section. Used when there is no dedicated
# templates/post-install/mcp/<name>.html — the catalog still has metadata
# we can surface (env keys, description, install args).
post_install_guide_render_generic_mcp() {
    local name="$1"
    local generic_tpl="$2"          # path to _generic.html
    local catalog="$3"              # path to integrations-catalog.json
    [[ -f "$generic_tpl" ]] || return 1

    local display_name="$name"
    local description="No description in catalog."
    local env_list=""
    local oauth_note=""
    local doc_url="https://github.com/sergei-aronsen/claude-code-toolkit"

    if [[ -f "$catalog" ]] && command -v jq >/dev/null 2>&1; then
        display_name=$(jq -r --arg n "$name" '.components.mcp[$n].display_name // $n' "$catalog" 2>/dev/null)
        description=$(jq -r --arg n "$name" '.components.mcp[$n].description // ""' "$catalog" 2>/dev/null)
        local oauth
        oauth=$(jq -r --arg n "$name" '.components.mcp[$n].requires_oauth // false' "$catalog" 2>/dev/null)
        if [[ "$oauth" == "true" ]]; then
            oauth_note="<strong>OAuth flow:</strong> the first call to this MCP from inside Claude Code will open a browser tab to authenticate. No env var setup needed."
        fi
        local keys
        keys=$(jq -r --arg n "$name" '.components.mcp[$n].env_var_keys[]?' "$catalog" 2>/dev/null)
        if [[ -n "$keys" ]]; then
            while IFS= read -r k; do
                env_list+="<li><code>${k}</code> — required env var, see official docs for the value format.</li>"
            done <<< "$keys"
        fi
    fi
    [[ -z "$env_list" ]] && env_list="<li>No env vars required.</li>"

    sed \
        -e "s|{{NAME}}|$name|g" \
        -e "s|{{DISPLAY_NAME}}|$display_name|g" \
        -e "s|{{DESCRIPTION}}|$description|g" \
        -e "s|{{ENV_LIST}}|$env_list|g" \
        -e "s|{{OAUTH_NOTE}}|$oauth_note|g" \
        -e "s|{{DOC_URL}}|$doc_url|g" \
        "$generic_tpl"
}

# Main entry point.
post_install_guide_generate() {
    local templates_dir
    templates_dir=$(post_install_guide_resolve_templates_dir)
    if [[ -z "$templates_dir" || ! -d "$templates_dir" ]]; then
        echo "post-install-guide: templates dir not found" >&2
        return 1
    fi

    local skeleton="$templates_dir/_skeleton.html"
    local styles="$templates_dir/_styles.css"
    local scriptjs="$templates_dir/_script.js"
    local generic_tpl="$templates_dir/mcp/_generic.html"

    for f in "$skeleton" "$styles" "$scriptjs"; do
        [[ -f "$f" ]] || { echo "post-install-guide: missing $f" >&2; return 1; }
    done

    local installed="${TK_GUIDE_INSTALLED:-}"
    local mcps="${TK_GUIDE_MCPS:-}"
    local output="${TK_GUIDE_OUTPUT:-$HOME/.claude/setup-guide.html}"
    local toolkit_ver="${TK_GUIDE_TOOLKIT_VER:-unknown}"

    # Resolve catalog for generic-MCP fallback.
    local catalog="${TK_MCP_CATALOG_PATH:-}"
    if [[ -z "$catalog" || ! -f "$catalog" ]]; then
        if [[ -f "$templates_dir/../../scripts/lib/integrations-catalog.json" ]]; then
            catalog="$(cd "$templates_dir/../../scripts/lib" && pwd)/integrations-catalog.json"
        elif [[ -f "$HOME/.claude/integrations-catalog.json" ]]; then
            catalog="$HOME/.claude/integrations-catalog.json"
        fi
    fi

    # Build TOC entries + section blocks.
    local toc_html=""
    local sections_html=""
    local label icon tpl

    if [[ -n "$installed" ]]; then
        toc_html+="<li class=\"toc-section-title\">Components</li>"
        for label in $installed; do
            tpl="$templates_dir/components/${label}.html"
            # Bridges: collapse gemini-bridge/codex-bridge → bridges.html.
            if [[ "$label" == "gemini-bridge" || "$label" == "codex-bridge" ]]; then
                tpl="$templates_dir/components/bridges.html"
                # Avoid duplicate TOC entry if both bridges installed.
                if echo "$sections_html" | grep -q 'id="bridges"'; then
                    continue
                fi
                label="bridges"
            fi
            if [[ ! -f "$tpl" ]]; then
                continue
            fi
            icon=$(post_install_guide_icon "$label")
            local title
            title=$(post_install_guide_titleize "$label")
            toc_html+="<li><a href=\"#${label}\">${icon} ${title}</a></li>"
            sections_html+=$'\n'
            sections_html+=$(cat "$tpl")
        done
    fi

    if [[ -n "$mcps" ]]; then
        toc_html+="<li class=\"toc-section-title\">MCP Servers</li>"
        for name in $mcps; do
            tpl="$templates_dir/mcp/${name}.html"
            local body
            if [[ -f "$tpl" ]]; then
                body=$(cat "$tpl")
            else
                body=$(post_install_guide_render_generic_mcp "$name" "$generic_tpl" "$catalog")
            fi
            [[ -z "$body" ]] && continue
            local display="$name"
            if [[ -f "$catalog" ]] && command -v jq >/dev/null 2>&1; then
                display=$(jq -r --arg n "$name" '.components.mcp[$n].display_name // $n' "$catalog" 2>/dev/null)
            fi
            toc_html+="<li><a href=\"#mcp-${name}\">🔌 ${display}</a></li>"
            sections_html+=$'\n'
            sections_html+="$body"
        done
    fi

    if [[ -z "$toc_html" ]]; then
        toc_html='<li class="toc-section-title">Nothing to set up</li>'
        sections_html='<section><h2>👍 No additional setup needed</h2><p>You did not install any component that requires post-install configuration. Run <code>/update-toolkit</code> or <code>/update-deps</code> from inside Claude Code to manage dependencies.</p></section>'
    fi

    local generated_at
    generated_at=$(date '+%Y-%m-%d %H:%M %Z')
    local hostname_str="${HOSTNAME:-$(hostname 2>/dev/null || echo localhost)}"

    # Use python3 for substitution — multi-line CSS / JS would need
    # awk's `-v` to embed newlines, which BSD awk on macOS rejects.
    # python3 ships on every supported platform (also a hard dep for
    # claude-memo and council).
    mkdir -p "$(dirname "$output")"

    PI_SKELETON="$skeleton" \
    PI_STYLES_FILE="$styles" \
    PI_SCRIPT_FILE="$scriptjs" \
    PI_TOC="$toc_html" \
    PI_SECTIONS="$sections_html" \
    PI_VERSION="$toolkit_ver" \
    PI_GENERATED_AT="$generated_at" \
    PI_HOSTNAME="$hostname_str" \
    PI_OUTPUT="$output" \
    python3 - <<'PYEOF' || { echo "post-install-guide: substitution failed" >&2; return 2; }
import os, sys

def read(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

skeleton = read(os.environ['PI_SKELETON'])
substitutions = {
    '{{STYLES}}':       read(os.environ['PI_STYLES_FILE']),
    '{{SCRIPT}}':       read(os.environ['PI_SCRIPT_FILE']),
    '{{TOC}}':          os.environ.get('PI_TOC', ''),
    '{{SECTIONS}}':     os.environ.get('PI_SECTIONS', ''),
    '{{VERSION}}':      os.environ.get('PI_VERSION', ''),
    '{{GENERATED_AT}}': os.environ.get('PI_GENERATED_AT', ''),
    '{{HOSTNAME}}':     os.environ.get('PI_HOSTNAME', ''),
}
out = skeleton
for k, v in substitutions.items():
    out = out.replace(k, v)
with open(os.environ['PI_OUTPUT'], 'w', encoding='utf-8') as f:
    f.write(out)
PYEOF

    return 0
}

# CLI mode — `bash scripts/lib/post-install-guide.sh` runs end-to-end
# with auto-detection from the user's current state.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    # Auto-detect installed components from filesystem.
    detected=()
    [[ -f "$HOME/.claude/CLAUDE.md" ]] && detected+=("toolkit")
    [[ -f "$HOME/.claude/cc-safety-net.json" || -d "$HOME/.claude/safety-net" ]] && detected+=("security")
    [[ -f "$HOME/.claude/statusline-refresh.sh" ]] && detected+=("statusline")
    command -v rtk >/dev/null 2>&1 && detected+=("rtk")
    [[ -f "$HOME/.claude/council/brain.py" ]] && detected+=("council")
    [[ -d "$HOME/.claude/skills/memo-skill/.git" ]] && detected+=("claude-memo")
    [[ -f "$HOME/.claude/skills/product-thinking/SKILL.md" || -f ".claude/skills/product-thinking/SKILL.md" ]] && detected+=("product-thinking")
    [[ -x "$HOME/.claude/hooks/format-file.sh" || -x ".claude/hooks/format-file.sh" ]] && detected+=("auto-format")
    if [[ -f "GEMINI.md" || -f "AGENTS.md" ]]; then
        detected+=("bridges")
    fi
    export TK_GUIDE_INSTALLED="${detected[*]}"

    # MCPs — read from ~/.claude.json mcpServers.
    mcps_csv=""
    if [[ -f "$HOME/.claude.json" ]] && command -v jq >/dev/null 2>&1; then
        mcps_csv=$(jq -r '(.mcpServers // {}) | keys[]' "$HOME/.claude.json" 2>/dev/null | tr '\n' ' ')
    fi
    export TK_GUIDE_MCPS="${mcps_csv}"

    # Toolkit version. Declare + assign separately to satisfy SC2155
    # (otherwise `export $(...)` masks the cat/jq failure code).
    # Top-level scope here (not inside a function), so no `local`.
    _tk_ver=""
    if [[ -f "$HOME/.claude/.toolkit-version" ]]; then
        _tk_ver="$(cat "$HOME/.claude/.toolkit-version" 2>/dev/null)"
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../manifest.json" ]] && command -v jq >/dev/null 2>&1; then
        _tk_ver="$(jq -r '.version' "$(dirname "${BASH_SOURCE[0]}")/../../manifest.json" 2>/dev/null)"
    fi
    export TK_GUIDE_TOOLKIT_VER="$_tk_ver"
    unset _tk_ver

    : "${TK_GUIDE_OUTPUT:=$HOME/.claude/setup-guide.html}"

    if post_install_guide_generate; then
        echo "✓ Setup guide written to: $TK_GUIDE_OUTPUT"
        echo "  Open with: open '$TK_GUIDE_OUTPUT' (macOS) or xdg-open (Linux)"
    else
        exit $?
    fi
fi
