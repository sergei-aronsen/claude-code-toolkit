#!/bin/bash
# Claude Code Toolkit — Skills Mirror Sync (Maintainer Tool)
#
# v6.46.0 closed-loop redesign. Pulls skill content from the upstream
# repository at the commit declared in `manifest.json:skills_pins[name]` and
# writes it into `templates/skills-marketplace/<name>/`. Recomputes the
# reproducible sha256 (via scripts/lib/skill-checksum.sh) and surfaces
# manifest-vs-mirror drift.
#
# Before v6.46.0, sync pulled from the maintainer's laptop
# (~/.claude/skills/) so the mirror state was unverifiable against any
# canonical source. The `--from-local` mode preserves that legacy path
# for maintainers who hand-curate a skill before publishing it upstream.
#
# Usage:
#   bash scripts/sync-skills-mirror.sh --check                # diff report, no writes
#   bash scripts/sync-skills-mirror.sh --apply                # pull all active pins
#   bash scripts/sync-skills-mirror.sh --apply <skill-name>   # sync one skill
#   bash scripts/sync-skills-mirror.sh --from-local           # legacy: ~/.claude/skills → mirror
#   bash scripts/sync-skills-mirror.sh --dry-run              # alias for --check
#
# Test seams:
#   TK_SKILLS_SRC      — override source skills home for --from-local
#                        (default: $HOME/.claude/skills)
#   TK_SKILLS_DEST     — override dest mirror path
#                        (default: <repo>/templates/skills-marketplace)
#   TK_SKILL_TMPDIR    — override scratch dir for upstream clones
#                        (default: $(mktemp -d))
#
# Exit codes:
#   0 success (or --check with no drift)
#   1 sync failure / mirror dir missing / fetch failure
#   2 invalid argument
#   3 --check found drift (callable from CI)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Color helpers
# ─────────────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'
if [[ -n "${NO_COLOR+x}" ]] || ! [ -t 1 ]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${REPO_ROOT}/manifest.json"
CHECKSUM_SH="${SCRIPT_DIR}/lib/skill-checksum.sh"
SKILLS_DEST_DEFAULT="${REPO_ROOT}/templates/skills-marketplace"
SKILLS_DEST="${TK_SKILLS_DEST:-$SKILLS_DEST_DEFAULT}"
SKILLS_SRC="${TK_SKILLS_SRC:-$HOME/.claude/skills}"
TMPDIR_ROOT="${TK_SKILL_TMPDIR:-}"

# ─────────────────────────────────────────────────────────────────────────────
# Modes + argument parsing
# ─────────────────────────────────────────────────────────────────────────────
MODE="check"           # check (default, no writes) | apply | from-local
SINGLE_SKILL=""
APPLY_MANIFEST=1       # under --apply, also rewrite manifest.json:.skills_pins.*.sha256
STRICT=0               # under --check --strict, drift exits 3 (CI gate)

_usage() {
    cat <<EOF
Usage: bash scripts/sync-skills-mirror.sh [MODE] [skill-name]

MODES:
  --check (default)       Diff report only — never writes. Exit 0 even
                          on drift (info mode, safe to run in CI).
  --strict                With --check, exit 3 if any mirror differs from
                          upstream-at-pinned-commit. Use for explicit
                          re-pinning gates.
  --dry-run               Alias for --check.
  --apply                 Pull every active skills_pins entry from upstream,
                          write to templates/skills-marketplace/, update the
                          manifest sha256.
  --from-local            Legacy maintainer path: sync from \$HOME/.claude/skills/
                          (or TK_SKILLS_SRC) to mirror. Kept for skills authored
                          locally before they have an upstream URL.

  --skip-manifest         With --apply, do not rewrite manifest sha256
                          (manual review afterward).

  -h, --help              Show this help.

ARGUMENTS:
  skill-name              Process only this one skill (must be a key under
                          manifest.json:.skills_pins).

EXIT CODES:
  0  Success.
  1  Sync failure (fetch, mirror dir, checksum tool, ...).
  2  Invalid argument.
  3  --check found mirror↔upstream drift (suitable for CI gating).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check|--dry-run) MODE="check";       shift ;;
        --apply)           MODE="apply";       shift ;;
        --from-local)      MODE="from-local";  shift ;;
        --strict)          STRICT=1;           shift ;;
        --skip-manifest)   APPLY_MANIFEST=0;   shift ;;
        -h|--help)         _usage; exit 0 ;;
        -*)
            echo "${RED}✗${NC} Unknown option: $1" >&2
            _usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$SINGLE_SKILL" ]]; then
                echo "${RED}✗${NC} Too many positional arguments" >&2
                exit 2
            fi
            SINGLE_SKILL="$1"; shift ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Sanity guards
# ─────────────────────────────────────────────────────────────────────────────
[ -f "$MANIFEST" ] || { echo "${RED}✗${NC} manifest.json not found: $MANIFEST" >&2; exit 1; }
[ -x "$CHECKSUM_SH" ] || { echo "${RED}✗${NC} skill-checksum.sh missing or not executable: $CHECKSUM_SH" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "${RED}✗${NC} jq required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "${RED}✗${NC} git required" >&2; exit 1; }

# Destructive-op guard — same as legacy: refuse if dest is not a
# skills-marketplace path.
if [[ "$SKILLS_DEST" != */skills-marketplace && "$SKILLS_DEST" != */skills-marketplace/* ]]; then
    echo "${RED}✗${NC} TK_SKILLS_DEST does not contain '/skills-marketplace': '$SKILLS_DEST'" >&2
    exit 2
fi

if [[ -z "$TMPDIR_ROOT" ]]; then
    TMPDIR_ROOT="$(mktemp -d -t tk-skills-sync.XXXXXX)"
    trap 'rm -rf "$TMPDIR_ROOT"' EXIT
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

# pin_field <name> <field> — read a field from manifest.json:.skills_pins[name].
# Returns empty string on null/missing.
pin_field() {
    local name="$1" field="$2"
    jq -r --arg n "$name" --arg f "$field" '
        (.skills_pins[$n][$f] // "") | tostring
    ' "$MANIFEST"
}

# list_active_pins — print active pin names, one per line.
list_active_pins() {
    jq -r '.skills_pins | to_entries[] | select(.value._status == "active") | .key' "$MANIFEST"
}

# compute_sha <dir> — wrap skill-checksum.sh.
compute_sha() {
    bash "$CHECKSUM_SH" "$1"
}

# fetch_upstream <name> <repo_url> <commit> <path?> → writes content to
# $TMPDIR_ROOT/staging/<name>/. Returns 0 on success.
#
# Strategy: shallow-clone repo, fetch the specific commit, checkout, then
# copy <path>/ (or the repo root) to staging. Works for both monorepo
# subpath pins and whole-repo pins.
fetch_upstream() {
    local name="$1" repo="$2" commit="$3" path="$4"
    local clone="$TMPDIR_ROOT/clone/$name"
    local stage="$TMPDIR_ROOT/staging/$name"

    rm -rf "$clone" "$stage"
    mkdir -p "$(dirname "$clone")"

    # Shallow init + fetch the specific commit. GitHub allows
    # `git fetch <sha>` even for non-default-branch SHAs.
    git init --quiet "$clone"
    (
        cd "$clone"
        git remote add origin "$repo"
        if ! git fetch --quiet --depth 1 origin "$commit" 2>/dev/null; then
            # Some hosts don't allow SHA fetch on shallow init; fall back
            # to a deeper fetch.
            git fetch --quiet --depth 200 origin 2>/dev/null || \
                git fetch --quiet origin 2>/dev/null
        fi
        git checkout --quiet "$commit"
    )

    mkdir -p "$(dirname "$stage")"
    if [[ -n "$path" && "$path" != "null" ]]; then
        local subdir="$clone/$path"
        if [[ ! -d "$subdir" ]]; then
            echo "${RED}✗${NC} $name: upstream path '$path' missing at commit $commit" >&2
            return 1
        fi
        cp -R "$subdir" "$stage"
    else
        # Whole repo. Strip the .git directory; copy everything else.
        mkdir -p "$stage"
        # macOS BSD cp doesn't preserve trailing-slash semantics the same
        # way GNU cp does — enumerate with find for portability.
        ( cd "$clone" && tar --exclude='.git' -cf - . ) | ( cd "$stage" && tar -xf - )
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────────────────

# Resolve the list of skills to process.
declare -a names=()
if [[ -n "$SINGLE_SKILL" ]]; then
    if ! jq -e --arg n "$SINGLE_SKILL" '.skills_pins[$n]' "$MANIFEST" >/dev/null; then
        echo "${RED}✗${NC} '$SINGLE_SKILL' not in skills_pins" >&2
        exit 2
    fi
    names=("$SINGLE_SKILL")
else
    while IFS= read -r line; do
        names+=("$line")
    done < <(list_active_pins)
fi

if [[ "${#names[@]}" -eq 0 ]]; then
    echo "${YELLOW}!${NC} No active skills_pins to process" >&2
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Mode: from-local (legacy)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$MODE" == "from-local" ]]; then
    echo "${CYAN}Skills Mirror Sync (legacy --from-local)${NC}"
    echo "  Source : ${SKILLS_SRC}"
    echo "  Dest   : ${SKILLS_DEST}"
    echo ""
    SYNCED=0; MISSING=0
    for name in "${names[@]}"; do
        src="${SKILLS_SRC}/${name}"
        dest="${SKILLS_DEST}/${name}"
        if [[ ! -d "$src" ]]; then
            echo "${YELLOW}!${NC} ${name}: source missing at ${src} (skip)"
            MISSING=$((MISSING + 1))
            continue
        fi
        rm -rf "$dest"
        mkdir -p "$(dirname "$dest")"
        cp -R "$src" "$dest"
        new_sha=$(compute_sha "$dest")
        echo "${GREEN}✓${NC} synced: ${name}  sha256=${new_sha:0:16}…"
        SYNCED=$((SYNCED + 1))
    done
    printf '\nSynced: %d · Missing: %d · Total: %d\n' "$SYNCED" "$MISSING" "${#names[@]}"
    [[ "$MISSING" -gt 0 ]] && exit 1
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Mode: check / apply (closed-loop upstream pull)
# ─────────────────────────────────────────────────────────────────────────────
echo "${CYAN}Skills Mirror Sync (mode: ${MODE})${NC}"
echo "  Manifest: $(jq -r .version "$MANIFEST")"
echo "  Dest    : ${SKILLS_DEST}"
echo "  Scratch : ${TMPDIR_ROOT}"
echo ""

CLEAN=0; DRIFT=0; FAILED=0
declare -a drift_lines=()

for name in "${names[@]}"; do
    repo=$(pin_field "$name" repo)
    commit=$(pin_field "$name" commit)
    path=$(pin_field "$name" path)
    declared_sha=$(pin_field "$name" sha256)
    status=$(pin_field "$name" _status)

    if [[ "$status" == "no-upstream-found" ]]; then
        # memo-skill case — no upstream to pull from. Verify mirror sha
        # still matches manifest declaration.
        mdir="${SKILLS_DEST}/${name}"
        if [[ ! -d "$mdir" ]]; then
            echo "${RED}✗${NC} $name: no-upstream-found AND mirror missing"
            FAILED=$((FAILED + 1))
            continue
        fi
        actual_sha=$(compute_sha "$mdir")
        if [[ -n "$declared_sha" && "$actual_sha" != "$declared_sha" ]]; then
            echo "${RED}✗${NC} $name: no-upstream-found mirror sha drift  declared=${declared_sha:0:12}… actual=${actual_sha:0:12}…"
            DRIFT=$((DRIFT + 1))
            drift_lines+=("$name no-upstream local-drift")
        else
            echo "${GREEN}✓${NC} $name: no-upstream-found (mirror sha intact)"
            CLEAN=$((CLEAN + 1))
        fi
        continue
    fi

    if [[ -z "$repo" || -z "$commit" ]]; then
        echo "${YELLOW}!${NC} $name: missing repo or commit; skip"
        FAILED=$((FAILED + 1))
        continue
    fi

    if ! fetch_upstream "$name" "$repo" "$commit" "$path" 2>/dev/null; then
        echo "${RED}✗${NC} $name: fetch failed (repo=$repo commit=${commit:0:12}…)"
        FAILED=$((FAILED + 1))
        continue
    fi

    upstream_sha=$(compute_sha "$TMPDIR_ROOT/staging/$name")
    mdir="${SKILLS_DEST}/${name}"
    mirror_sha=""
    if [[ -d "$mdir" ]]; then
        mirror_sha=$(compute_sha "$mdir")
    fi

    if [[ "$upstream_sha" == "$mirror_sha" ]]; then
        echo "${GREEN}✓${NC} $name: mirror == upstream@${commit:0:12}  (sha ${upstream_sha:0:12}…)"
        CLEAN=$((CLEAN + 1))
        continue
    fi

    DRIFT=$((DRIFT + 1))
    drift_lines+=("$name mirror=${mirror_sha:0:12}… upstream=${upstream_sha:0:12}… commit=${commit:0:12}")
    if [[ "$MODE" == "check" ]]; then
        echo "${YELLOW}~${NC} $name: drift  mirror=${mirror_sha:0:12}… upstream=${upstream_sha:0:12}…"
        continue
    fi

    # Mode = apply. Replace mirror, then optionally rewrite manifest.
    rm -rf "$mdir"
    mkdir -p "$(dirname "$mdir")"
    cp -R "$TMPDIR_ROOT/staging/$name" "$mdir"

    if [[ "$APPLY_MANIFEST" -eq 1 ]]; then
        # Use python rather than jq -i (jq lacks --in-place on older versions).
        python3 - "$MANIFEST" "$name" "$upstream_sha" <<'PY'
import json, sys
mp, name, sha = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(mp))
m['skills_pins'][name]['sha256'] = sha
json.dump(m, open(mp,'w'), indent=2)
PY
        echo "${GREEN}✓${NC} $name: synced + manifest sha256 updated to ${upstream_sha:0:12}…"
    else
        echo "${GREEN}✓${NC} $name: synced  (manifest unchanged — rerun without --skip-manifest to update sha256)"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
printf '\nClean: %d · Drift: %d · Failed: %d · Total: %d\n' \
    "$CLEAN" "$DRIFT" "$FAILED" "${#names[@]}"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi

if [[ "$MODE" == "check" && "$DRIFT" -gt 0 ]]; then
    echo ""
    echo "Run \`bash scripts/sync-skills-mirror.sh --apply\` to pull from upstream."
    echo "(Drift between mirror and upstream is often benign — markdownlint"
    echo "auto-fix applied at ingestion may produce a few-line diff. Inspect"
    echo "before --apply.)"
    if [[ "$STRICT" -eq 1 ]]; then
        exit 3
    fi
fi

exit 0
