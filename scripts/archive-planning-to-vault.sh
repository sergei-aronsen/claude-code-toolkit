#!/usr/bin/env bash
# scripts/archive-planning-to-vault.sh
#
# One-shot migration: move historical .planning/ artifacts into the
# claude-memo vault under references/toolkit-history/, then trigger an
# incremental reindex so they become findable via /memo.
#
# Detection:
#   - Vault path resolves via the FIRST hit in this order:
#       1. $MEMO_VAULT_PATH env var
#       2. crontab grep for `memo_engine.py reindex --vault <path>`
#       3. ~/memo-vault (default)
#
# Migrated content (default set; override via --files PATTERN):
#   - .planning/v[0-9]*-*.md   (release notes, milestone audits)
#   - .planning/milestones/v[0-5].*  (pre-v6 milestone requirements/roadmaps)
#   - .planning/audits/*       (older audit artifacts)
#   - AUDIT-REPORT.md          (v4.1 deep audit at repo root)
#
# Each file becomes <vault>/references/toolkit-history/<kebab-filename>.md
# with claude-memo Zettelkasten frontmatter prepended:
#
#   ---
#   type: reference
#   created: <git-first-commit-date or today>
#   updated: <git-last-commit-date or today>
#   project: claude-code-toolkit
#   tags:
#     - toolkit-history
#     - <derived-from-version>
#   aliases:
#     - <original-filename-stem>
#   source: claude-code-toolkit/<original-relative-path>
#   ---
#
#   <original content>
#
# Flags:
#   --dry-run        Show what would happen, write nothing.
#   --vault PATH     Override auto-detected vault path.
#   --no-reindex     Skip the post-migration reindex.
#   --no-rm          Leave originals in place (write to vault only).
#   --yes            Skip confirmation.
#
# Exit codes:
#   0  success
#   1  prerequisite missing (jq, git, memo_engine.py)
#   2  vault not found
#   3  user cancelled
#   4  reindex failed (vault still received the files)

set -euo pipefail

# ───── colors ─────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

DRY_RUN=0
VAULT_OVERRIDE=""
NO_REINDEX=0
NO_RM=0
YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --vault)      shift; VAULT_OVERRIDE="${1:?--vault needs an arg}" ;;
        --no-reindex) NO_REINDEX=1 ;;
        --no-rm)      NO_RM=1 ;;
        --yes|-y)     YES=1 ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo -e "${RED}✗${NC} unknown flag: $1" >&2; exit 1 ;;
    esac
    shift
done

_log()  { printf '%b\n' "$*"; }
_step() { _log "${CYAN}▸${NC} $*"; }
_ok()   { _log "${GREEN}✓${NC} $*"; }
_warn() { _log "${YELLOW}!${NC} $*"; }
_err()  { _log "${RED}✗${NC} $*" >&2; }
_dry()  { _log "${DIM}[dry-run]${NC} $*"; }

# ───── prereqs ─────
for tool in jq git; do
    command -v "$tool" >/dev/null 2>&1 || { _err "$tool not on PATH"; exit 1; }
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ───── resolve vault ─────
resolve_vault() {
    local v
    if [[ -n "$VAULT_OVERRIDE" ]]; then
        echo "$VAULT_OVERRIDE"; return
    fi
    if [[ -n "${MEMO_VAULT_PATH:-}" ]]; then
        echo "$MEMO_VAULT_PATH"; return
    fi
    # Crontab is the most reliable signal — that's where claude-memo's
    # automation actually points the engine. macOS Dropbox vaults live in
    # /Users/<u>/Library/CloudStorage/... and won't be discovered by a
    # naive ~/memo-vault probe.
    v=$(crontab -l 2>/dev/null \
        | grep -oE '\-\-vault [^ ]+' \
        | awk '{print $2}' \
        | head -1)
    if [[ -n "$v" && -d "$v" ]]; then
        echo "$v"; return
    fi
    if [[ -d "$HOME/memo-vault/.memo" ]]; then
        echo "$HOME/memo-vault"; return
    fi
    return 1
}

VAULT=$(resolve_vault) || {
    _err "cannot find a claude-memo vault — pass --vault PATH or set \$MEMO_VAULT_PATH"
    exit 2
}

if [[ ! -d "$VAULT" ]]; then
    _err "vault path does not exist: $VAULT"
    exit 2
fi

DEST="$VAULT/references/toolkit-history"
MEMO_ENGINE="$HOME/.claude/skills/memo-skill/scripts/memo_engine.py"

_log "${CYAN}archive-planning-to-vault${NC}"
_log "  Vault:       $VAULT"
_log "  Destination: $DEST"
_log "  Repo:        $REPO_ROOT"
_log ""

# ───── candidate list ─────
CANDIDATES=()

# Top-level audit report
[[ -f "AUDIT-REPORT.md" ]] && CANDIDATES+=("AUDIT-REPORT.md")

# Versioned planning files at the .planning/ root.
while IFS= read -r f; do
    CANDIDATES+=("$f")
done < <(find .planning -maxdepth 1 -type f -name 'v[0-9]*-*.md' 2>/dev/null | sort)

# Pre-v6 milestone subdirs (v4.* and v5.*) — keep v6.* in the repo.
while IFS= read -r d; do
    while IFS= read -r f; do
        CANDIDATES+=("$f")
    done < <(find "$d" -type f -name '*.md' 2>/dev/null | sort)
done < <(find .planning/milestones -maxdepth 1 -type d \( -name 'v4*' -o -name 'v5*' \) 2>/dev/null | sort)

# Audit artifacts.
while IFS= read -r f; do
    CANDIDATES+=("$f")
done < <(find .planning/audits -type f -name '*.md' 2>/dev/null | sort)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    _ok "Nothing to migrate. Exiting."
    exit 0
fi

_step "Found ${#CANDIDATES[@]} files to migrate:"
for f in "${CANDIDATES[@]}"; do
    _log "  · $f"
done
_log ""

# ───── confirm ─────
if [[ $YES -eq 0 && $DRY_RUN -eq 0 ]]; then
    if [[ ! -e /dev/tty ]]; then
        _err "no /dev/tty — pass --yes or --dry-run"
        exit 3
    fi
    printf '%b ' "${YELLOW}?${NC} Migrate ${#CANDIDATES[@]} files to $DEST and remove originals from repo? [y/N]:" >&2
    IFS= read -r reply </dev/tty
    [[ "$reply" =~ ^[yY] ]] || { _err "Cancelled."; exit 3; }
fi

# ───── ensure destination ─────
if [[ $DRY_RUN -eq 1 ]]; then
    _dry "mkdir -p $DEST"
else
    mkdir -p "$DEST"
fi

# ───── per-file migration ─────
# Vault filename rule: replace `/` and spaces with `-`, lowercase the
# version-tag prefix to keep the folder grep-friendly.
_to_vault_name() {
    local rel="$1"
    local base
    # Strip leading .planning/ or anything before — keep last 2 path
    # components for context (e.g. milestones/v4.1-REQUIREMENTS.md →
    # milestones-v4.1-requirements.md).
    base=$(echo "$rel" \
        | sed 's#^\.planning/##' \
        | sed 's#^AUDIT-REPORT\.md#root-audit-report-v4.1.md#' \
        | tr '/' '-' \
        | tr '[:upper:]' '[:lower:]')
    printf '%s' "$base"
}

# Extract first version tag (vN.M) from path/filename for tags. The
# `|| true` keeps the pipeline exit-clean under set -euo pipefail when
# the path has no version (e.g. AUDIT-REPORT.md → empty result, caller
# falls back to "archived").
_extract_version_tag() {
    local rel="$1"
    echo "$rel" | grep -oE 'v[0-9]+\.[0-9]+' | head -1 || true
}

migrated=0
skipped=0

for src in "${CANDIDATES[@]}"; do
    vault_name=$(_to_vault_name "$src")
    dest_file="$DEST/$vault_name"

    if [[ -f "$dest_file" && $DRY_RUN -eq 0 ]]; then
        _warn "exists — skipping: $dest_file"
        skipped=$((skipped + 1))
        continue
    fi

    # Git-derived dates so the Zettelkasten timeline matches when the
    # decision was actually made, not when the migration ran.
    created=$(git log --diff-filter=A --follow --format='%ad' --date=short -- "$src" 2>/dev/null | tail -1)
    updated=$(git log -1 --format='%ad' --date=short -- "$src" 2>/dev/null)
    [[ -z "$created" ]] && created=$(date +%Y-%m-%d)
    [[ -z "$updated" ]] && updated="$created"

    version_tag=$(_extract_version_tag "$src")
    [[ -z "$version_tag" ]] && version_tag="archived"

    if [[ $DRY_RUN -eq 1 ]]; then
        _dry "write $dest_file (created=$created updated=$updated tag=$version_tag)"
        migrated=$((migrated + 1))
        continue
    fi

    # Rewrite the file with frontmatter on top. If the source already has
    # frontmatter, we still wrap with our own — claude-memo's parser
    # uses the FIRST `---` block, and downstream search wants `type` +
    # `tags`. The original frontmatter survives further down as content.
    {
        echo "---"
        echo "type: reference"
        echo "created: $created"
        echo "updated: $updated"
        echo "project: claude-code-toolkit"
        echo "tags:"
        echo "  - toolkit-history"
        echo "  - $version_tag"
        echo "aliases:"
        echo "  - $(basename "$src" .md)"
        echo "source: claude-code-toolkit/$src"
        echo "---"
        echo ""
        cat "$src"
    } > "$dest_file"

    migrated=$((migrated + 1))
done

_ok "Migrated: $migrated   Skipped (already in vault): $skipped"
_log ""

# ───── reindex ─────
if [[ $NO_REINDEX -eq 1 ]]; then
    _warn "Skipping reindex (--no-reindex). Files will be picked up on the next cron run (~30 min)."
elif [[ $DRY_RUN -eq 1 ]]; then
    _dry "would run: python3 $MEMO_ENGINE reindex --vault $VAULT --incremental"
elif [[ ! -f "$MEMO_ENGINE" ]]; then
    _warn "memo_engine.py not found at $MEMO_ENGINE — skipping reindex."
    _warn "Files in vault will be picked up on the next cron run."
else
    _step "Reindexing vault (incremental)..."
    if python3 "$MEMO_ENGINE" reindex --vault "$VAULT" --incremental 2>&1 | tail -10; then
        _ok "Reindex complete."
    else
        _warn "Reindex failed (often a Dropbox file-lock deadlock — see vault/.memo/reindex.log)."
        _warn "Files are in the vault; the next successful cron run will index them."
    fi
fi
_log ""

# ───── git rm ─────
if [[ $NO_RM -eq 1 ]]; then
    _warn "Originals left in place (--no-rm)."
elif [[ $DRY_RUN -eq 1 ]]; then
    _dry "would: git rm ${CANDIDATES[*]}"
else
    _step "Removing originals from the repo (history retains them)..."
    git rm -q "${CANDIDATES[@]}" || _warn "git rm reported errors — see status."
    _ok "Removed ${#CANDIDATES[@]} files from the working tree."
    _log ""
    _log "Next steps:"
    _log "  1. ${CYAN}git status${NC}            — review the deletions"
    _log "  2. ${CYAN}git diff --stat HEAD${NC}  — verify size reduction"
    _log "  3. ${CYAN}git commit -m \"chore: archive pre-v6 planning to claude-memo vault\"${NC}"
    _log ""
    _log "Verify findability:"
    _log "  ${CYAN}python3 $MEMO_ENGINE query \"toolkit v4.6 milestone\" --vault \"$VAULT\"${NC}"
fi
