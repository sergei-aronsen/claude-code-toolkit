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
    local has_keys=0

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
            has_keys=1
            while IFS= read -r k; do
                env_list+="<li><code>${k}</code> — required env var, see official docs for the value format.</li>"
            done <<< "$keys"
        fi
    fi
    [[ -z "$env_list" ]] && env_list="<li>No env vars required.</li>"

    # WHERE_BLOCK: only render the "where to put the value" guidance when the
    # MCP actually consumes env vars. OAuth-only and no-key MCPs (Serena, the
    # Anthropic-hosted ones) get an empty block so the card stays compact.
    #
    # v6.4+ default: ALL secrets — user-scope and project-scope alike — live
    # in ~/.claude/mcp-config.env (auto-loaded from shell rc). Project-scope
    # entries are suffixed with the project slug (KEY_<SLUG>) so multiple
    # projects can hold different restricted keys without colliding. The
    # block embeds a clickable `file://` link to that single file so a user
    # never has to remember the path.
    local where_block=""
    if [[ "$has_keys" -eq 1 ]]; then
        local _home="${TK_GUIDE_HOME:-$HOME}"
        local _user_env="${_home}/.claude/mcp-config.env"
        local _user_disp="${_user_env/#$_home/~}"
        where_block="<h3>Where to put the value</h3><p>One file, mode 0600, auto-loaded by your shell rc — open <a href=\"file://${_user_env}\"><code>${_user_disp}</code></a> and add lines.</p><p><strong>User scope (single global key, used everywhere):</strong> add <code>KEY=value</code> with the plain catalog name (e.g. <code>CONTEXT7_API_KEY=ctx_…</code>). Best for personal-tooling MCPs that follow you across all projects.</p><p><strong>Project scope (per-app restricted keys):</strong> add <code>KEY_&lt;PROJECT_SLUG&gt;=value</code> — e.g. <code>STRIPE_SECRET_KEY_MY_APP=sk_restricted_…</code>. The toolkit's installer registers <code>&lt;project&gt;/.mcp.json</code> with <code>\${KEY_&lt;PROJECT_SLUG&gt;}</code> substitution so the right key reaches the right project. Slug = uppercased project folder name with dashes replaced by underscores.</p><p>After editing, reload your shell (<code>exec \$SHELL</code>, or open a new terminal tab) and restart Claude Code.</p>"
    fi

    # Substitute via python3: WHERE_BLOCK can contain almost any HTML and the
    # other fields (display_name, description) are catalog-driven, so a literal
    # str.replace pass is safer than chained sed (which would need each value
    # escaped for `s` semantics).
    PI_TPL="$generic_tpl" \
    PI_NAME="$name" \
    PI_DISPLAY="$display_name" \
    PI_DESC="$description" \
    PI_ENV_LIST="$env_list" \
    PI_OAUTH="$oauth_note" \
    PI_DOC="$doc_url" \
    PI_WHERE="$where_block" \
    python3 -c '
import os
with open(os.environ["PI_TPL"], "r", encoding="utf-8") as f:
    out = f.read()
for tok, key in (
    ("{{NAME}}",         "PI_NAME"),
    ("{{DISPLAY_NAME}}", "PI_DISPLAY"),
    ("{{DESCRIPTION}}",  "PI_DESC"),
    ("{{ENV_LIST}}",     "PI_ENV_LIST"),
    ("{{OAUTH_NOTE}}",   "PI_OAUTH"),
    ("{{DOC_URL}}",      "PI_DOC"),
    ("{{WHERE_BLOCK}}",  "PI_WHERE"),
):
    out = out.replace(tok, os.environ.get(key, ""))
print(out, end="")
'
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

    # Build TOC entries + section blocks. The new layout drops the "Contents"
    # wrapper header and per-item icons; group headers (Components, MCP Servers)
    # carry the icons and items render as plain disc bullets.
    local components_items=""
    local mcps_items=""
    local sections_html=""
    local label tpl

    if [[ -n "$installed" ]]; then
        for label in $installed; do
            tpl="$templates_dir/components/${label}.html"
            if [[ "$label" == "gemini-bridge" || "$label" == "codex-bridge" ]]; then
                tpl="$templates_dir/components/bridges.html"
                if echo "$sections_html" | grep -q 'id="bridges"'; then
                    continue
                fi
                label="bridges"
            fi
            if [[ ! -f "$tpl" ]]; then
                continue
            fi
            local title
            title=$(post_install_guide_titleize "$label")
            components_items+="<li><a href=\"#${label}\">${title}</a></li>"
            sections_html+=$'\n'
            sections_html+=$(cat "$tpl")
        done
    fi

    # Track MCPs that need API keys so we can build an "Action required"
    # banner at the top of the guide. The banner is the first thing a user
    # sees after install — it answers "wait, do I need to do anything?"
    # without forcing them to scroll the whole document.
    local action_items=""
    if [[ -n "$mcps" ]]; then
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
            local needs_keys=0
            if [[ -f "$catalog" ]] && command -v jq >/dev/null 2>&1; then
                display=$(jq -r --arg n "$name" '.components.mcp[$n].display_name // $n' "$catalog" 2>/dev/null)
                local _keycount
                _keycount=$(jq -r --arg n "$name" '(.components.mcp[$n].env_var_keys // []) | length' "$catalog" 2>/dev/null)
                local _oauth
                _oauth=$(jq -r --arg n "$name" '.components.mcp[$n].requires_oauth // false' "$catalog" 2>/dev/null)
                # OAuth-only MCPs technically have no keys to fill; skip them.
                if [[ "${_keycount:-0}" -gt 0 && "$_oauth" != "true" ]]; then
                    needs_keys=1
                fi
            fi
            # Trim parenthetical disambiguators ("Serena (semantic code IDE)" →
            # "Serena") to keep TOC entries scannable. Section subtitles still
            # carry the full description.
            display="${display%% (*}"
            mcps_items+="<li><a href=\"#mcp-${name}\">${display}</a></li>"
            if [[ "$needs_keys" -eq 1 ]]; then
                action_items+="<li><a href=\"#mcp-${name}\">${display}</a></li>"
            fi
            sections_html+=$'\n'
            sections_html+="$body"
        done
    fi

    # Prepend the action-required banner to the section stream so it renders
    # ABOVE every component card. Linked items jump to the relevant MCP's
    # WHERE_BLOCK section so the user sees the exact file path.
    if [[ -n "$action_items" ]]; then
        local _home="${TK_GUIDE_HOME:-$HOME}"
        local _user_env="${_home}/.claude/mcp-config.env"
        local _user_env_disp="${_user_env/#$_home/~}"
        local action_banner
        action_banner=$(printf '<section class="action-required"><h2>🔑 You need to add API keys</h2><p>Some MCPs you just installed are wired up but inert until you add their API keys. The toolkit prepared <a href="file://%s"><code>%s</code></a> (chmod 0600) — open it, paste the keys, save, then run <code>exec $SHELL</code> and restart Claude Code.</p><p>Click any item below to jump to its setup card with copy-pastable keys:</p><ul>%s</ul></section>' \
            "$_user_env" "$_user_env_disp" "$action_items")
        sections_html="$action_banner$sections_html"
    fi

    local toc_html=""
    if [[ -n "$components_items" ]]; then
        toc_html+="<div class=\"toc-group\"><div class=\"toc-group-title\"><span class=\"toc-group-icon\">🧰</span>Components</div><ul>${components_items}</ul></div>"
    fi
    if [[ -n "$mcps_items" ]]; then
        toc_html+="<div class=\"toc-group\"><div class=\"toc-group-title\"><span class=\"toc-group-icon\">🔌</span>MCP Servers</div><ul>${mcps_items}</ul></div>"
    fi

    if [[ -z "$toc_html" ]]; then
        toc_html='<div class="toc-group"><div class="toc-group-title">Nothing to set up</div></div>'
        sections_html='<section><h2>👍 No additional setup needed</h2><p>You did not install any component that requires post-install configuration. Run <code>/update-toolkit</code> or <code>/update-deps</code> from inside Claude Code to manage dependencies.</p></section>'
    fi

    local generated_at
    generated_at=$(date '+%Y-%m-%d %H:%M %Z')
    local hostname_str="${HOSTNAME:-$(hostname 2>/dev/null || echo localhost)}"

    # Project name: prefer caller-provided TK_GUIDE_PROJECT_NAME; fall back to
    # the basename of the project root (where install.sh / init-claude.sh ran
    # from). The fallback intentionally uses $PWD because TK_GUIDE_PROJECT_ROOT
    # is the project directory passed by install.sh; for ad-hoc CLI runs we
    # take the current dir.
    local project_name="${TK_GUIDE_PROJECT_NAME:-}"
    if [[ -z "$project_name" ]]; then
        local _pr="${TK_GUIDE_PROJECT_ROOT:-$PWD}"
        project_name="$(basename "$_pr" 2>/dev/null || echo project)"
    fi

    # Version block: only render the Toolkit-version badge when we have a real
    # version string. Empty / "unknown" → omit the badge so the header doesn't
    # advertise "Toolkit vunknown".
    local version_block=""
    if [[ -n "$toolkit_ver" && "$toolkit_ver" != "unknown" ]]; then
        version_block="<span class=\"meta-sep\">·</span><span class=\"badge\">Toolkit v${toolkit_ver}</span>"
    fi

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
    PI_VERSION_BLOCK="$version_block" \
    PI_PROJECT_NAME="$project_name" \
    PI_GENERATED_AT="$generated_at" \
    PI_HOSTNAME="$hostname_str" \
    PI_OUTPUT="$output" \
    python3 - <<'PYEOF' || { echo "post-install-guide: substitution failed" >&2; return 2; }
import html, os, sys

def read(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

skeleton = read(os.environ['PI_SKELETON'])
project_raw = os.environ.get('PI_PROJECT_NAME', '')
project_html = '<code>{}</code>'.format(html.escape(project_raw)) if project_raw else ''
substitutions = {
    '{{STYLES}}':        read(os.environ['PI_STYLES_FILE']),
    '{{SCRIPT}}':        read(os.environ['PI_SCRIPT_FILE']),
    '{{TOC}}':           os.environ.get('PI_TOC', ''),
    '{{SECTIONS}}':      os.environ.get('PI_SECTIONS', ''),
    '{{VERSION_BLOCK}}': os.environ.get('PI_VERSION_BLOCK', ''),
    '{{PROJECT_NAME}}':  project_html,
    '{{GENERATED_AT}}':  os.environ.get('PI_GENERATED_AT', ''),
    '{{HOSTNAME}}':      os.environ.get('PI_HOSTNAME', ''),
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
