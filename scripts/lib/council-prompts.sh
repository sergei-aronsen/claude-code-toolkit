#!/bin/bash

# scripts/lib/council-prompts.sh
#
# Phase 24 Sub-Phase 2 — install editable system prompts for Supreme Council.
#
# Council exposes four system prompts as files under ~/.claude/council/prompts/:
#   - skeptic-system.md
#   - pragmatist-system.md
#   - audit-review-skeptic.md
#   - audit-review-pragmatist.md
#
# scripts/council/brain.py reads these at runtime via load_prompt() and falls
# back to embedded constants when a file is missing. The installer writes
# upstream contents on first run and preserves user customizations on update
# via the `.upstream-new.md` sidecar pattern (mirroring scripts/setup-security.sh
# CLAUDE.md.security.new behavior).
#
# Usage:
#   source scripts/lib/council-prompts.sh
#   install_council_system_prompts
#
# Required globals (set by caller):
#   REPO_URL          — raw.githubusercontent base for downloads
#   COUNCIL_DIR or council_dir — install target (e.g. $HOME/.claude/council)
#                        (function reads $COUNCIL_DIR first, then $council_dir)
#
# Optional test seam:
#   TK_COUNCIL_PROMPTS_DIR=<path> — read upstream files from a local checkout
#                        instead of fetching via curl (used by hermetic tests
#                        and init-local.sh). Path should point to the
#                        `templates/council-prompts` directory.

# Resolve color constants with safe fallbacks (only set if unset).
: "${RED:=}"
: "${GREEN:=}"
: "${YELLOW:=}"
: "${NC:=}"

# Names of prompt files we ship.
COUNCIL_SYSTEM_PROMPTS=(
    "skeptic-system"
    "pragmatist-system"
    "audit-review-skeptic"
    "audit-review-pragmatist"
)

# _fetch_council_prompt <name> <dest>
# Returns 0 if a fresh upstream copy is now at <dest>, 1 on fetch failure.
_fetch_council_prompt() {
    local name="$1"
    local dest="$2"

    if [[ -n "${TK_COUNCIL_PROMPTS_DIR:-}" && -f "$TK_COUNCIL_PROMPTS_DIR/${name}.md" ]]; then
        cp "$TK_COUNCIL_PROMPTS_DIR/${name}.md" "$dest"
        return 0
    fi
    if curl -sSLf "$REPO_URL/templates/council-prompts/${name}.md" -o "$dest" 2>/dev/null; then
        return 0
    fi
    rm -f "$dest"
    return 1
}

# install_council_pricing
# Installs the default pricing.json into ~/.claude/council/, preserving any
# local customizations via the .upstream-new.json sidecar pattern.
# Phase 24 Sub-Phase 4.
install_council_pricing() {
    local target="${COUNCIL_DIR:-${council_dir:-$HOME/.claude/council}}"
    mkdir -p "$target"
    local installed_path="$target/pricing.json"
    local tmp_path
    tmp_path="$(mktemp "${TMPDIR:-/tmp}/council-pricing.XXXXXX")"

    if [[ -n "${TK_COUNCIL_PROMPTS_DIR:-}" && -f "$TK_COUNCIL_PROMPTS_DIR/../council-pricing.json" ]]; then
        cp "$TK_COUNCIL_PROMPTS_DIR/../council-pricing.json" "$tmp_path"
    elif [[ -n "${TK_COUNCIL_PRICING_FILE:-}" && -f "$TK_COUNCIL_PRICING_FILE" ]]; then
        cp "$TK_COUNCIL_PRICING_FILE" "$tmp_path"
    elif curl -sSLf "$REPO_URL/templates/council-pricing.json" -o "$tmp_path" 2>/dev/null; then
        :
    else
        rm -f "$tmp_path"
        echo -e "  ${YELLOW}⚠${NC} pricing.json (download failed — skipping)"
        return 0
    fi

    if [[ ! -f "$installed_path" ]]; then
        mv "$tmp_path" "$installed_path"
        echo -e "  ${GREEN}✓${NC} pricing.json installed"
        return 0
    fi

    if cmp -s "$tmp_path" "$installed_path" 2>/dev/null; then
        rm -f "$tmp_path"
        echo -e "  ${GREEN}✓${NC} pricing.json (already current)"
        return 0
    fi

    local new_path="${installed_path}.upstream-new.json"
    local stamp
    if [[ -f "$new_path" ]] && ! cmp -s "$new_path" "$tmp_path" 2>/dev/null; then
        stamp=$(date -u +%s)
        mv "$new_path" "${new_path}.${stamp}"
        echo -e "  ${YELLOW}⚠${NC} pricing.json: preserved prior reconciliation as .upstream-new.json.${stamp}"
    fi
    mv "$tmp_path" "$new_path"
    echo -e "  ${YELLOW}⚠${NC} pricing.json differs from upstream — wrote ${new_path}"
    echo -e "       Diff:  diff -u \"$installed_path\" \"$new_path\""
    echo -e "       Apply: mv \"$new_path\" \"$installed_path\""
}


# install_council_redaction_patterns
# Installs the default redaction-patterns.txt into ~/.claude/council/, preserving
# any local customizations via the same .upstream-new.md sidecar pattern.
# Phase 24 Sub-Phase 3.
install_council_redaction_patterns() {
    local target="${COUNCIL_DIR:-${council_dir:-$HOME/.claude/council}}"
    mkdir -p "$target"
    local installed_path="$target/redaction-patterns.txt"
    local tmp_path
    tmp_path="$(mktemp "${TMPDIR:-/tmp}/council-redaction.XXXXXX")"

    if [[ -n "${TK_COUNCIL_PROMPTS_DIR:-}" && -f "$TK_COUNCIL_PROMPTS_DIR/../council-redaction-patterns.txt" ]]; then
        cp "$TK_COUNCIL_PROMPTS_DIR/../council-redaction-patterns.txt" "$tmp_path"
    elif [[ -n "${TK_COUNCIL_PATTERNS_FILE:-}" && -f "$TK_COUNCIL_PATTERNS_FILE" ]]; then
        cp "$TK_COUNCIL_PATTERNS_FILE" "$tmp_path"
    elif curl -sSLf "$REPO_URL/templates/council-redaction-patterns.txt" -o "$tmp_path" 2>/dev/null; then
        :
    else
        rm -f "$tmp_path"
        echo -e "  ${YELLOW}⚠${NC} redaction-patterns.txt (download failed — skipping)"
        return 0
    fi

    if [[ ! -f "$installed_path" ]]; then
        mv "$tmp_path" "$installed_path"
        echo -e "  ${GREEN}✓${NC} redaction-patterns.txt installed"
        return 0
    fi

    if cmp -s "$tmp_path" "$installed_path" 2>/dev/null; then
        rm -f "$tmp_path"
        echo -e "  ${GREEN}✓${NC} redaction-patterns.txt (already current)"
        return 0
    fi

    local new_path="${installed_path}.upstream-new.txt"
    local stamp
    if [[ -f "$new_path" ]] && ! cmp -s "$new_path" "$tmp_path" 2>/dev/null; then
        stamp=$(date -u +%s)
        mv "$new_path" "${new_path}.${stamp}"
        echo -e "  ${YELLOW}⚠${NC} redaction-patterns.txt: preserved prior reconciliation as .upstream-new.txt.${stamp}"
    fi
    mv "$tmp_path" "$new_path"
    echo -e "  ${YELLOW}⚠${NC} redaction-patterns.txt differs from upstream — wrote ${new_path}"
    echo -e "       Diff:  diff -u \"$installed_path\" \"$new_path\""
    echo -e "       Apply: mv \"$new_path\" \"$installed_path\""
}


# install_council_system_prompts
# Installs all four system prompts into <target>/prompts/, preserving any
# local customizations.
install_council_system_prompts() {
    local target="${COUNCIL_DIR:-${council_dir:-$HOME/.claude/council}}"
    local prompts_dir="$target/prompts"
    mkdir -p "$prompts_dir"

    local name installed_path tmp_path new_path stamp
    for name in "${COUNCIL_SYSTEM_PROMPTS[@]}"; do
        installed_path="$prompts_dir/${name}.md"
        tmp_path="$(mktemp "${TMPDIR:-/tmp}/council-prompt-${name}.XXXXXX")"

        if ! _fetch_council_prompt "$name" "$tmp_path"; then
            echo -e "  ${YELLOW}⚠${NC} prompts/${name}.md (download failed — skipping)"
            rm -f "$tmp_path"
            continue
        fi

        if [[ ! -f "$installed_path" ]]; then
            mv "$tmp_path" "$installed_path"
            echo -e "  ${GREEN}✓${NC} prompts/${name}.md installed"
            continue
        fi

        if cmp -s "$tmp_path" "$installed_path" 2>/dev/null; then
            rm -f "$tmp_path"
            echo -e "  ${GREEN}✓${NC} prompts/${name}.md (already current)"
            continue
        fi

        # Local copy differs from upstream — preserve user edits, write
        # the new upstream content alongside as `.upstream-new.md`.
        new_path="${installed_path}.upstream-new.md"
        if [[ -f "$new_path" ]] && ! cmp -s "$new_path" "$tmp_path" 2>/dev/null; then
            stamp=$(date -u +%s)
            mv "$new_path" "${new_path}.${stamp}"
            echo -e "  ${YELLOW}⚠${NC} prompts/${name}.md: preserved prior reconciliation as .upstream-new.md.${stamp}"
        fi
        mv "$tmp_path" "$new_path"
        echo -e "  ${YELLOW}⚠${NC} prompts/${name}.md differs from upstream — wrote ${new_path}"
        echo -e "       Diff:  diff -u \"$installed_path\" \"$new_path\""
        echo -e "       Apply: mv \"$new_path\" \"$installed_path\""
    done
}
