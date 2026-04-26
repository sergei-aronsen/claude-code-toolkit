#!/bin/bash

# Claude Code Toolkit — Uninstall Script
# Reads ~/.claude/toolkit-install.json and removes registered files whose
# SHA256 matches the recorded value. Base plugins (superpowers, get-shit-done)
# are NEVER touched. v4.3.0 (HARDEN-C-04 closure).
#
# Usage:
#   bash scripts/uninstall.sh               # interactive default
#   bash scripts/uninstall.sh --dry-run     # preview only, no changes
#   bash scripts/uninstall.sh --help        # show this usage block
#
# Safety invariants:
#   - --no-backup flag does not exist (UN-04): backup before uninstall is mandatory
#   - Never deletes files outside the project's .claude/ directory
#   - Never deletes files inside superpowers or get-shit-done plugin trees
#   - File list comes from installed_files[] in state, never from wildcard glob
#   - If toolkit-install.json is absent, exits 0 with no-op message (UN-06)

set -euo pipefail

# ───────── flag parsing (before color constants) ─────────
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        --help|-h)
            sed -n '3,18p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        --no-backup)
            echo -e "\033[0;31m✗\033[0m --no-backup is not allowed. Backup before uninstall is an invariant." >&2
            exit 1
            ;;
        *)
            echo -e "\033[1;33m⚠\033[0m unknown flag: $arg (ignoring)" >&2
            ;;
    esac
done
# DRY_RUN is consumed by plans 18-02/03/04 (dry-run output + delete guard); reference here
# satisfies shellcheck SC2034 so the flag is declared in argparse where it belongs.
: "$DRY_RUN"

# ───────── ANSI color constants — gated by TTY + NO_COLOR ─────────
# ANSI color gating: presence of NO_COLOR (any value, including empty string)
# disables color per no-color.org. `[ -z "${NO_COLOR+x}" ]` returns true ONLY
# when NO_COLOR is unset; this is the canonical bash 3.2-safe test that
# distinguishes "unset" from "set to empty string". `[ -t 1 ]` ensures we
# never emit ANSI to a non-TTY (pipes, redirects, CI logs).
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# ───────── constants + log helpers ─────────
REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"

log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# shellcheck disable=SC2034  # CYAN reserved for future colorized output in 18-02/03/04
: "${CYAN}"

# ───────── mktemp + trap EXIT cleanup ─────────
LIB_STATE_TMP=$(mktemp "${TMPDIR:-/tmp}/state.XXXXXX")
LIB_BACKUP_TMP=$(mktemp "${TMPDIR:-/tmp}/backup.XXXXXX")
LIB_DRO_TMP=$(mktemp "${TMPDIR:-/tmp}/dry-run-output.XXXXXX")
trap 'rm -f "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP"' EXIT

# ───────── source libs HARD-fail (with TK_UNINSTALL_LIB_DIR test seam) ─────────
for lib_pair in "state.sh:$LIB_STATE_TMP" "backup.sh:$LIB_BACKUP_TMP" "dry-run-output.sh:$LIB_DRO_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_UNINSTALL_LIB_DIR:-}" && -f "$TK_UNINSTALL_LIB_DIR/$lib_name" ]]; then
        cp "$TK_UNINSTALL_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
        log_error "Failed to fetch scripts/lib/$lib_name — uninstall cannot proceed"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
done

# Re-apply color gate after sourcing libs — lib/state.sh unconditionally defines
# RED/YELLOW/NC with hardcoded ANSI escapes, which would override our gated empty
# strings. Re-applying here re-establishes NO_COLOR + TTY correctness.
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# ───────── CLAUDE_DIR / STATE_FILE override for test seam ─────────
CLAUDE_DIR="$(pwd)/.claude"
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    CLAUDE_DIR="$TK_UNINSTALL_HOME/.claude"
    STATE_FILE="$TK_UNINSTALL_HOME/.claude/toolkit-install.json"
fi
# shellcheck disable=SC2034  # PROJECT_DIR referenced by helpers in 18-03/04
PROJECT_DIR="$(dirname "$CLAUDE_DIR")"

# ───────── is_protected_path <abs_or_rel_path> ─────────
# Exit 0 (TRUE — protected, do NOT delete) if path matches any of:
#   - outside CLAUDE_DIR (i.e. does not start with $CLAUDE_DIR/)
#   - inside ~/.claude/plugins/cache/claude-plugins-official/superpowers/
#   - inside ~/.claude/get-shit-done/
# Exit 1 (FALSE — safe to consider) otherwise.
is_protected_path() {
    local path="$1"
    # Resolve relative paths to absolute against CLAUDE_DIR for unambiguous comparison.
    local abs="$path"
    case "$path" in
        /*) abs="$path" ;;
        *)  abs="$CLAUDE_DIR/$path" ;;
    esac
    # Outside project .claude/ → protected.
    case "$abs" in
        "$CLAUDE_DIR"/*|"$CLAUDE_DIR") : ;;  # inside, continue checks
        *) return 0 ;;                       # outside → protected
    esac
    # Base-plugin trees inside ~/.claude/ → protected (defensive: state should
    # never list these, but guard against malformed state).
    case "$abs" in
        "$HOME"/.claude/plugins/cache/claude-plugins-official/superpowers/*) return 0 ;;
        "$HOME"/.claude/get-shit-done/*) return 0 ;;
    esac
    return 1
}

# ───────── classify_file <relative_or_absolute_path> <recorded_sha256> ─────────
# Stdout: one of: REMOVE | KEEP | MODIFIED | MISSING | PROTECTED
#   REMOVE     — file exists, current sha256 == recorded_sha256
#   MODIFIED   — file exists, current sha256 != recorded_sha256
#   MISSING    — file does not exist on disk
#   PROTECTED  — is_protected_path returned 0 (caller MUST skip)
# Never deletes. Pure read.
#
# NOTE: installed_files[].path entries are relative to PROJECT_DIR (the parent of
# .claude/), e.g. ".claude/commands/plan.md". Resolve against PROJECT_DIR, not
# CLAUDE_DIR, to avoid the double-.claude path .claude/.claude/commands/plan.md.
classify_file() {
    local path="$1" recorded="$2"
    local abs
    case "$path" in
        /*) abs="$path" ;;
        *)  abs="$PROJECT_DIR/$path" ;;
    esac
    if is_protected_path "$abs"; then
        printf 'PROTECTED'
        return 0
    fi
    if [[ ! -f "$abs" ]]; then
        printf 'MISSING'
        return 0
    fi
    local current
    current=$(sha256_file "$abs" 2>/dev/null || echo "")
    if [[ -z "$current" ]]; then
        printf 'MISSING'  # unreadable → treat as missing (caller skips)
        return 0
    fi
    if [[ "$current" == "$recorded" ]]; then
        printf 'REMOVE'
    else
        printf 'MODIFIED'
    fi
}

# ───────── MAIN ─────────

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Claude Code Toolkit — Uninstall                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ ! -f "$STATE_FILE" ]]; then
    log_success "Toolkit not installed; nothing to do."
    exit 0
fi

STATE_JSON=$(read_state) || { log_error "toolkit-install.json unreadable at $STATE_FILE"; exit 1; }

# print_uninstall_dry_run — UN-02 chezmoi-grade preview of removal plan.
# Reads from outer-scope arrays populated by the read-only classification phase:
#   REMOVE_LIST    — files whose current sha256 matches recorded sha256 (-)
#   MODIFIED_LIST  — files whose current sha256 differs (?, prompt-pending)
#   MISSING_LIST   — files registered but absent on disk (?, distinguished by label)
#   KEEP_LIST      — files user chose to keep (~) — empty in dry-run; populated by 18-04
# Color via dro_* helpers (TTY + NO_COLOR gated).
# Zero filesystem writes. No prompts. Returns 0.
#
# IMPORTANT: dro_print_header takes a SINGLE-CHAR marker. MODIFIED and MISSING both
# use "?" — they are distinguished by their LABEL ("MODIFIED" vs "MISSING"), not by
# the marker. The output reads as "[? MODIFIED]" and "[? MISSING]".
print_uninstall_dry_run() {
    if ! command -v dro_init_colors >/dev/null 2>&1; then
        log_error "dry-run-output.sh not sourced — print_uninstall_dry_run cannot render"
        return 1
    fi
    dro_init_colors

    local total=$((n_remove + n_keep + n_modified + n_missing))

    if [ "$n_remove" -gt 0 ]; then
        dro_print_header "-" "REMOVE" "$n_remove" _DRO_R
        for p in "${REMOVE_LIST[@]}"; do
            dro_print_file "$p"
        done
        echo ""
    fi

    if [ "$n_keep" -gt 0 ]; then
        dro_print_header "~" "KEEP" "$n_keep" _DRO_C
        for p in "${KEEP_LIST[@]}"; do
            dro_print_file "$p"
        done
        echo ""
    fi

    if [ "$n_modified" -gt 0 ]; then
        dro_print_header "?" "MODIFIED" "$n_modified" _DRO_Y
        for p in "${MODIFIED_LIST[@]}"; do
            dro_print_file "${p}  (will prompt: y=remove / N=keep / d=diff)"
        done
        echo ""
    fi

    if [ "$n_missing" -gt 0 ]; then
        # NOTE: single-char "?" marker (matches dro_print_header API). Distinguished
        # from MODIFIED group by the label column.
        dro_print_header "?" "MISSING" "$n_missing" _DRO_Y
        for p in "${MISSING_LIST[@]}"; do
            dro_print_file "${p}  (registered but absent on disk)"
        done
        echo ""
    fi

    dro_print_total "$total"
}

# ───────── classify all registered files ─────────
REMOVE_LIST=()
MODIFIED_LIST=()
MISSING_LIST=()
PROTECTED_LIST=()
KEEP_LIST=()   # populated by 18-04 [y/N/d] prompt; empty in 18-02

while IFS=$'\t' read -r path sha256; do
    [[ -z "$path" ]] && continue
    verdict=$(classify_file "$path" "$sha256")
    case "$verdict" in
        REMOVE)    REMOVE_LIST+=("$path") ;;
        MODIFIED)  MODIFIED_LIST+=("$path") ;;
        MISSING)   MISSING_LIST+=("$path") ;;
        PROTECTED) PROTECTED_LIST+=("$path") ;;
        KEEP)      KEEP_LIST+=("$path") ;;
    esac
done < <(jq -r '.installed_files[] | "\(.path)\t\(.sha256)"' <<<"$STATE_JSON")

# Derive counters from array lengths.
n_remove=${#REMOVE_LIST[@]}
n_modified=${#MODIFIED_LIST[@]}
n_missing=${#MISSING_LIST[@]}
n_protected=${#PROTECTED_LIST[@]}
n_keep=${#KEEP_LIST[@]}

# UN-02 dry-run early exit. Must run AFTER classification (read-only) and
# BEFORE any backup/lock/delete logic added by plans 18-03/18-04.
# Zero filesystem changes from this point if --dry-run was passed.
if [[ $DRY_RUN -eq 1 ]]; then
    print_uninstall_dry_run
    exit 0
fi

# Print the plain text classification summary (non-dry-run runs only).
echo ""
echo "Classification:"
echo -e "  ${GREEN}REMOVE${NC}:    $n_remove"
echo -e "  ${YELLOW}MODIFIED${NC}: $n_modified"
echo -e "  ${BLUE}MISSING${NC}:   $n_missing"
echo -e "  ${RED}PROTECTED${NC}: $n_protected (excluded from any action)"

# TODO(18-03): replace with backup + delete loop
exit 0
