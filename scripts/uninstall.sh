#!/bin/bash

# Claude Code Toolkit — Uninstall Script
# Reads ~/.claude/toolkit-install.json and removes registered files whose
# SHA256 matches the recorded value. Base plugins (superpowers, get-shit-done)
# are NEVER touched. v4.3.0 (HARDEN-C-04 closure).
#
# Usage:
#   bash scripts/uninstall.sh               # interactive default
#   bash scripts/uninstall.sh --dry-run     # preview only, no changes
#   bash scripts/uninstall.sh --keep-state  # preserve toolkit-install.json for re-run recovery
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
KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        --keep-state)
            KEEP_STATE=1
            ;;
        --help|-h)
            sed -n '3,19p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        --no-backup)
            echo -e "\033[0;31m✗\033[0m --no-backup is not allowed. Backup before uninstall is an invariant." >&2
            exit 1
            ;;
        *)
            # Audit L-Uninstall: unknown flag was previously a warn-and-ignore.
            # For a destructive command that's the wrong default — a typo'd
            # `--dry-runn` would have removed files instead of previewing.
            # Fail closed and tell the user what's supported.
            echo -e "\033[0;31m✗\033[0m unknown flag: $arg" >&2
            echo "Supported flags: --dry-run, --keep-state, --no-backup (rejected), --help" >&2
            exit 1
            ;;
    esac
done
# DRY_RUN and KEEP_STATE are consumed downstream (dry-run output + state-delete gate);
# reference here satisfies shellcheck SC2034 so flags are declared in argparse where they belong.
: "$DRY_RUN" "$KEEP_STATE"

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
# Audit H5: TK_TOOLKIT_REF pins to a tag/SHA (default `main`).
TK_TOOLKIT_REF="${TK_TOOLKIT_REF:-main}"
REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/${TK_TOOLKIT_REF}"

# Audit L4 — global rules §2: every outgoing curl gets a real browser UA.
# shellcheck disable=SC2034
TK_USER_AGENT="${TK_USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36}"
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
LIB_BRIDGES_TMP=$(mktemp "${TMPDIR:-/tmp}/bridges.XXXXXX")
# UN-05 base-plugin invariant snapshots (sorted file lists, pre/post)
SP_SNAP_TMP=$(mktemp "${TMPDIR:-/tmp}/sp-snap.XXXXXX")
GSD_SNAP_TMP=$(mktemp "${TMPDIR:-/tmp}/gsd-snap.XXXXXX")
SP_AFTER_TMP=$(mktemp "${TMPDIR:-/tmp}/sp-after.XXXXXX")
GSD_AFTER_TMP=$(mktemp "${TMPDIR:-/tmp}/gsd-after.XXXXXX")
# Trap registered BEFORE acquire_lock so SIGINT mid-acquire still releases cleanly.
# release_lock is defined in lib/state.sh (sourced below); the 2>/dev/null guard
# handles the case where the trap fires before sourcing completes.
trap 'release_lock 2>/dev/null || true; rm -f "$LIB_STATE_TMP" "$LIB_BACKUP_TMP" "$LIB_DRO_TMP" "$LIB_BRIDGES_TMP" "$SP_SNAP_TMP" "$GSD_SNAP_TMP" "$SP_AFTER_TMP" "$GSD_AFTER_TMP"' EXIT

# ───────── source libs HARD-fail (with TK_UNINSTALL_LIB_DIR test seam) ─────────
for lib_pair in "state.sh:$LIB_STATE_TMP" "backup.sh:$LIB_BACKUP_TMP" "dry-run-output.sh:$LIB_DRO_TMP" "bridges.sh:$LIB_BRIDGES_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_UNINSTALL_LIB_DIR:-}" && -f "$TK_UNINSTALL_LIB_DIR/$lib_name" ]]; then
        cp "$TK_UNINSTALL_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
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

# ───────── CLAUDE_DIR / STATE_FILE / LOCK_DIR (per-project, with test seam) ─────────
# Mirror update-claude.sh:126 / init-local.sh:68 pattern: STATE_FILE always points
# at the per-project location so a fresh `init-claude.sh` install (which now also
# writes per-project state) and a subsequent `uninstall.sh` agree on the path.
# Previously this block only overrode STATE_FILE/LOCK_DIR under TK_UNINSTALL_HOME
# (test seam) and otherwise inherited state.sh's $HOME defaults — leaving uninstall
# reading a global record that update-claude.sh never touches.
CLAUDE_DIR="$(pwd)/.claude"
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    CLAUDE_DIR="$TK_UNINSTALL_HOME/.claude"
fi
# shellcheck disable=SC2034  # STATE_FILE consumed by read_state in lib/state.sh
STATE_FILE="$CLAUDE_DIR/toolkit-install.json"
# shellcheck disable=SC2034  # LOCK_DIR consumed by acquire_lock in lib/state.sh
LOCK_DIR="$CLAUDE_DIR/.toolkit-install.lock"
# shellcheck disable=SC2034  # PROJECT_DIR referenced by helpers in 18-03/04
PROJECT_DIR="$(dirname "$CLAUDE_DIR")"

# ───────── UN-05: base-plugin paths + TK_UNINSTALL_HOME override ─────────
SP_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    SP_DIR="$TK_UNINSTALL_HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
    GSD_DIR="$TK_UNINSTALL_HOME/.claude/get-shit-done"
fi

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

# classify_bridge_file <abs_path> <recorded_bridge_sha256>
# Like classify_file but skips the is_protected_path guard. Bridges live
# OUTSIDE $CLAUDE_DIR/ by design (next to <project>/CLAUDE.md or in
# ~/.gemini/, ~/.codex/) so the path-outside-CLAUDE_DIR rule must NOT
# block them. Base-plugin trees (~/.claude/plugins/.../superpowers,
# ~/.claude/get-shit-done) are still protected via an inline check.
classify_bridge_file() {
    local path="$1" recorded="$2"
    # Defensive: no bridge should ever live inside SP/GSD trees, but guard
    # in case a corrupt state file claims otherwise.
    case "$path" in
        "$HOME"/.claude/plugins/cache/claude-plugins-official/superpowers/*) printf 'PROTECTED'; return 0 ;;
        "$HOME"/.claude/get-shit-done/*) printf 'PROTECTED'; return 0 ;;
    esac
    if [[ ! -f "$path" ]]; then
        printf 'MISSING'
        return 0
    fi
    local current
    current=$(sha256_file "$path" 2>/dev/null || echo "")
    if [[ -z "$current" ]]; then
        printf 'MISSING'
        return 0
    fi
    if [[ "$current" == "$recorded" ]]; then
        printf 'REMOVE'
    else
        printf 'MODIFIED'
    fi
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
    # Audit M2: state.sh records sha256="" when the file existed but was
    # unreadable at install time (Phase 3 install-still-in-progress race).
    # Without this guard, `current != ""` always → verdict MODIFIED →
    # user gets a [y/N/d] prompt for a file the toolkit owns and they
    # never edited. Treat empty recorded-sha as REMOVE (toolkit-owned,
    # safe to clean) so uninstall stays non-interactive for those rows.
    if [[ -z "$recorded" ]]; then
        printf 'REMOVE'
        return 0
    fi
    if [[ "$current" == "$recorded" ]]; then
        printf 'REMOVE'
    else
        printf 'MODIFIED'
    fi
}

# prompt_modified_for_uninstall <relative_path>
# UN-03 [y/N/d] interactive prompt for MODIFIED files.
# y → rm -f and append to DELETED_LIST
# N (default) or anything else → append to KEEP_LIST and keep the file
# d → show diff vs manifest reference (from backup snapshot or remote) and re-prompt
# Reads via /dev/tty so script works under bash <(curl -sSL ...). Fail-closed N on EOF.
#
# `local` is permitted here because we are INSIDE a function body (unlike the
# MAIN-block code from 18-03 which forbids `local`).
#
# TK_UNINSTALL_TTY_FROM_STDIN: CI/test-only seam. When set (non-empty), reads from
# /dev/stdin instead of /dev/tty. Matches the TK_UNINSTALL_LIB_DIR / TK_UNINSTALL_FILE_SRC
# convention. NEVER set this in production — it breaks interactive prompts.
prompt_modified_for_uninstall() {
    local rel="$1"
    local local_path="$rel"
    case "$rel" in
        /*) : ;;
        *)  local_path="$PROJECT_DIR/$rel" ;;
    esac

    # Defense-in-depth: never prompt on a protected path (use resolved abs path
    # to avoid double-.claude when rel already starts with .claude/).
    # Bridges (GEMINI.md / AGENTS.md) live OUTSIDE $CLAUDE_DIR so is_protected_path
    # would always return true and silently keep them. Bypass for tracked bridges.
    local _is_bridge_path=1
    if [[ -n "${BRIDGE_PATHS+set}" ]] && [[ ${#BRIDGE_PATHS[@]} -gt 0 ]]; then
        for _bp in "${BRIDGE_PATHS[@]}"; do
            if [[ "$_bp" == "$rel" || "$_bp" == "$local_path" ]]; then
                _is_bridge_path=0
                break
            fi
        done
    fi
    if [[ $_is_bridge_path -ne 0 ]] && is_protected_path "$local_path"; then
        log_warning "Skipping prompt for protected path: $rel"
        KEEP_LIST+=("$rel")
        return 0
    fi

    # Reference content for `d`: prefer the test seam (TK_UNINSTALL_FILE_SRC),
    # fall back to remote (curl from REPO_URL/<rel>). The `d` branch shows a
    # "reference unavailable" message if neither is available.
    local reference_tmp
    reference_tmp=$(mktemp "${TMPDIR:-/tmp}/uninstall-ref.XXXXXX")
    # Audit U2 + I4: shell-quote via printf '%q' so a TMPDIR with single
    # quotes doesn't break the trap; also note that this RETURN trap
    # overrides any caller-installed RETURN trap (bash limitation — only
    # one RETURN trap per scope). Callers that need their own RETURN
    # cleanup must register an EXIT trap instead.
    # shellcheck disable=SC2064
    trap "rm -f $(printf '%q' "$reference_tmp")" RETURN

    local reference_source=""
    # Try test seam first
    if [[ -n "${TK_UNINSTALL_FILE_SRC:-}" && -f "$TK_UNINSTALL_FILE_SRC/$rel" ]]; then
        cp "$TK_UNINSTALL_FILE_SRC/$rel" "$reference_tmp"
        reference_source="local seam"
    # Try remote
    elif curl -sSLf -A "$TK_USER_AGENT" "$REPO_URL/$rel" -o "$reference_tmp" 2>/dev/null; then
        reference_source="remote ($REPO_URL/$rel)"
    else
        rm -f "$reference_tmp"
        reference_tmp=""
    fi

    # TTY source. Default /dev/tty; test seam (TK_UNINSTALL_TTY_FROM_STDIN=1) swaps
    # to /dev/stdin so the test harness can inject answers via a here-document.
    local tty_target="/dev/tty"
    [[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && tty_target="/dev/stdin"

    # Audit M-Uninstall: cap on read attempts. If /dev/tty closes mid-loop
    # (e.g. user piped uninstall into `cat`), the previous code would tight-
    # loop on read failures forever. Bail out as 'keep' after 5 failures.
    local _read_fail=0
    while :; do
        local choice=""
        if ! read -r -p "File $rel modified locally. Remove? [y/N/d]: " choice < "$tty_target" 2>/dev/null; then
            choice="N"   # fail-closed: tty source unreachable
            _read_fail=$((_read_fail + 1))
            if [[ $_read_fail -ge 5 ]]; then
                KEEP_LIST+=("$rel")
                return 0
            fi
        fi
        case "${choice:-N}" in
            y|Y)
                if rm -f "$local_path"; then
                    DELETED_LIST+=("$rel")
                    log_success "Removed: $rel"
                else
                    DELETE_FAILED_LIST+=("$rel")
                    log_warning "Failed to remove: $rel"
                fi
                return 0
                ;;
            d|D)
                if [[ -n "$reference_tmp" && -f "$reference_tmp" ]]; then
                    echo "── diff: local vs reference ($reference_source) ──"
                    diff -u "$local_path" "$reference_tmp" || true
                    echo "── end diff ──"
                else
                    echo "Reference unavailable (no local seam, no network) — diff cannot be shown."
                fi
                # re-enter loop for another prompt iteration
                ;;
            *)
                KEEP_LIST+=("$rel")
                return 0
                ;;
        esac
    done
}

# strip_sentinel_block <file>
# UN-05 (D-01/D-02/D-03): strip <!-- TOOLKIT-START --> ... <!-- TOOLKIT-END --> blocks
# from <file>, plus exactly ONE leading and ONE trailing blank line around each pair.
# Behavior:
#   - File absent → no-op, return 0
#   - Zero markers (no sentinels) → no-op, return 0 (graceful when CLAUDE.md never had them)
#   - Unmatched markers (start count != end count) → log warning, return 0 (D-02: never partial-strip)
#   - Multiple START/END pairs → strip ALL pairs (D-02 defensive)
#   - Empty result after strip → leave empty file on disk, do NOT delete (D-03 least-destruction)
#
# `local` is permitted here because we are INSIDE a function body.
# RETURN-scoped trap cleans the temp file when the function returns by any path.
strip_sentinel_block() {
    local file="$1"
    [[ -f "$file" ]] || return 0   # absent — nothing to strip

    # Count markers to detect unmatched pairs (D-02 guard).
    # `grep -c` returns 1 with exit 1 on zero matches when -q-style; the `|| true`
    # plus `grep -cF` count form returns 0 with exit 0 cleanly under set -e.
    local starts ends
    starts=$(grep -cF '<!-- TOOLKIT-START -->' "$file" 2>/dev/null || true)
    ends=$(grep -cF '<!-- TOOLKIT-END -->' "$file" 2>/dev/null || true)
    starts="${starts:-0}"
    ends="${ends:-0}"

    if [[ "$starts" -ne "$ends" ]]; then
        log_warning "Unmatched TOOLKIT-START/END markers in $file (starts=$starts, ends=$ends) — leaving file untouched"
        return 0
    fi
    if [[ "$starts" -eq 0 ]]; then
        return 0   # no sentinels — graceful no-op (D-01 strip-only-if-present)
    fi

    # awk strip: for each START/END pair, remove the pair and the surrounding blank
    # line on each side (one before START, one after END). State machine:
    #   in_block         — currently inside a START..END pair → drop line
    #   skip_prev_blank  — just exited a START line; drop the trailing blank if any
    #                      (note: handled at exit-of-block, not entry; see flag swap below)
    #   skip_next_blank  — just exited an END line; drop the next blank if any
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/sentinel-strip.XXXXXX")
    # Audit U2 + I4: %q-quoted path safe under any TMPDIR.
    # shellcheck disable=SC2064
    trap "rm -f $(printf '%q' "$tmp")" RETURN

    awk '
        # END marker: leave block, arm trailing-blank skip
        /<!-- TOOLKIT-END -->/   { in_block=0; skip_next_blank=1; next }
        # Inside block: drop everything (including START line catch below)
        in_block                 { next }
        # START marker: enter block, arm leading-blank skip retroactively by
        # buffering the previous-line decision; simpler: just consume the blank
        # we already printed by deferring print one line. Implementation below
        # uses a one-line lookahead via "buf".
        /<!-- TOOLKIT-START -->/ {
            # Drop the previously printed blank if it was blank
            in_block=1
            if (last_was_blank && have_buf) { have_buf=0 }
            else if (have_buf) { print buf; have_buf=0 }
            next
        }
        # Trailing-blank skip after END
        skip_next_blank && /^[[:space:]]*$/ { skip_next_blank=0; next }
        # Otherwise: emit any buffered line, then buffer the current line.
        # last_was_blank tracks if the buffered line is blank (so START can drop it).
        {
            if (have_buf) { print buf }
            buf = $0
            have_buf = 1
            last_was_blank = ($0 ~ /^[[:space:]]*$/) ? 1 : 0
            skip_next_blank = 0
        }
        END {
            if (have_buf && !in_block) { print buf }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
    log_success "Stripped toolkit sentinel block from $file"
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

# UN-05 base-plugin invariant: snapshot sorted file lists BEFORE any mutation.
# Empty if dir absent — not an error, base plugins may not be installed.
# `|| true` keeps the script alive under set -e if `find` returns non-zero.
find "$SP_DIR"  -type f 2>/dev/null | sort > "$SP_SNAP_TMP"  || true
find "$GSD_DIR" -type f 2>/dev/null | sort > "$GSD_SNAP_TMP" || true

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

# Phase 29 BRIDGE-UN-01: classify bridges[] entries alongside installed_files[].
# Bridges are tracked files like any other — same classify_bridge_file helper, same
# REMOVE/MODIFIED/MISSING/PROTECTED buckets. Per-bridge metadata (target, scope)
# is stashed in BRIDGE_META_<n> arrays so the post-removal _bridge_remove_state_entry
# call can find the right (target, scope, path) triple.
#
# bash 3.2 invariant: NO associative arrays. We use parallel indexed arrays
# keyed by absolute path; a linear scan recovers (target, scope) on need.
BRIDGE_PATHS=()
BRIDGE_TARGETS=()
BRIDGE_SCOPES=()
while IFS=$'\t' read -r b_target b_path b_scope b_sha; do
    [[ -z "$b_path" ]] && continue
    BRIDGE_PATHS+=("$b_path")
    BRIDGE_TARGETS+=("$b_target")
    BRIDGE_SCOPES+=("$b_scope")
    verdict=$(classify_bridge_file "$b_path" "$b_sha")
    case "$verdict" in
        REMOVE)    REMOVE_LIST+=("$b_path") ;;
        MODIFIED)  MODIFIED_LIST+=("$b_path") ;;
        MISSING)   MISSING_LIST+=("$b_path") ;;
        PROTECTED) PROTECTED_LIST+=("$b_path") ;;
        KEEP)      KEEP_LIST+=("$b_path") ;;
    esac
done < <(jq -r '.bridges // [] | .[] | "\(.target)\t\(.path)\t\(.scope)\t\(.bridge_sha256)"' <<<"$STATE_JSON")

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

# ───────── Mutation lock: prevent concurrent install/update/uninstall ─────────
# Trap was already registered before sourcing libs (above) so SIGINT before
# acquire_lock completes will still invoke release_lock cleanly.
acquire_lock || { log_error "Another toolkit install/update/uninstall is in progress."; exit 1; }

# ───────── UN-04: backup CLAUDE_DIR before any rm ─────────
# Audit M-Uninstall: epoch-only suffix collided when two uninstalls fired in
# the same second; the second cp -R then layered into the first dir. Append
# $$ for per-process disambiguation. -P keeps symlinks as symlinks instead
# of dereferencing them (preserves user customisations / ACLs more honestly).
BACKUP_DIR="$(dirname "$CLAUDE_DIR")/.claude-backup-pre-uninstall-$(date -u +%s)-$$"
log_info "Creating backup at $BACKUP_DIR (this may take a moment)…"
if ! cp -RP "$CLAUDE_DIR" "$BACKUP_DIR"; then
    log_error "Backup failed — aborting uninstall without removing any files"
    [[ -d "$BACKUP_DIR" ]] && rm -rf "$BACKUP_DIR"
    exit 1
fi
# UN-04 snapshot clause: ensure toolkit-install.json is captured inside backup.
if [[ -f "$STATE_FILE" ]]; then
    cp "$STATE_FILE" "$BACKUP_DIR/toolkit-install.json.snapshot" || \
        log_warning "State file snapshot copy failed (backup proceeds without snapshot)"
fi
log_success "Backup created: $BACKUP_DIR"
warn_if_too_many_backups

# ───────── UN-01: delete only hash-matched files (REMOVE_LIST) ─────────
# PROTECTED_LIST is NEVER iterated here — base-plugin invariant.
# MODIFIED_LIST entries are kept and surfaced in post-run summary (deferred to 18-04).
#
# bash 3.2 + set -u safety: NO `local` keyword (this is the top-level MAIN block,
# not a function body — `local` triggers SC2168 + bash runtime error). NO inline
# [@]:- array-default guards — use explicit array-length guard before expansion.
DELETED_LIST=()
DELETE_FAILED_LIST=()

if [[ ${#REMOVE_LIST[@]} -gt 0 ]]; then
    log_info "Removing ${#REMOVE_LIST[@]} unmodified file(s)…"
    for rel in "${REMOVE_LIST[@]}"; do
        # NOTE: NO `local` — this loop runs at MAIN block (top-level), not inside
        # a function. Using `local` here triggers shellcheck SC2168 + a bash runtime
        # error. Plain assignment is correct.
        abs_path="$rel"
        case "$rel" in
            /*) : ;;   # absolute already
            *)  abs_path="$PROJECT_DIR/$rel" ;;
        esac
        # Defense-in-depth: re-check protection at delete time (UN-01 invariant).
        # Use the resolved absolute path to avoid double-.claude when rel already
        # starts with .claude/ (e.g. .claude/get-shit-done/plugin.md would resolve
        # to $CLAUDE_DIR/.claude/... inside is_protected_path if passed as-is).
        # Phase 29 BRIDGE-UN-01: bridges live OUTSIDE $CLAUDE_DIR/ by design
        # (e.g. <project>/GEMINI.md). is_protected_path would flag them as protected.
        # Skip the is_protected_path check for paths found in BRIDGE_PATHS — they were
        # already cleared by classify_bridge_file which has its own SP/GSD guard.
        _is_bridge_path=0
        if [[ ${#BRIDGE_PATHS[@]} -gt 0 ]]; then
            for _bp in "${BRIDGE_PATHS[@]}"; do
                if [[ "$_bp" == "$abs_path" ]]; then
                    _is_bridge_path=1
                    break
                fi
            done
        fi
        if [[ $_is_bridge_path -eq 0 ]] && is_protected_path "$abs_path"; then
            log_warning "Refusing to delete protected path: $rel"
            continue
        fi
        if [[ -f "$abs_path" ]]; then
            if rm -f "$abs_path"; then
                DELETED_LIST+=("$rel")
            else
                DELETE_FAILED_LIST+=("$rel")
                log_warning "Failed to remove: $rel"
            fi
        fi
    done
fi

# UN-03: per-modified-file [y/N/d] prompt loop. Runs after REMOVE_LIST delete,
# after backup, before summary. bash 3.2-safe array-length guard pattern.
if [[ ${#MODIFIED_LIST[@]} -gt 0 ]]; then
    echo ""
    log_info "${#MODIFIED_LIST[@]} file(s) modified since install. Per-file decision required."
    for rel in "${MODIFIED_LIST[@]}"; do
        prompt_modified_for_uninstall "$rel"
    done
fi

# Phase 29 BRIDGE-UN-01: purge bridges[] entries whose files were removed
# this run. Skip when --keep-state (BRIDGE-UN-02). Bridge metadata recovered
# by linear scan against BRIDGE_PATHS / BRIDGE_TARGETS / BRIDGE_SCOPES.
#
# This must run BEFORE the state-file deletion block at line ~659, otherwise
# the state file is gone and _bridge_remove_state_entry no-ops silently.
# Order: backup → strip → file-delete → bridges[] purge → state-delete (LAST).
if [[ $KEEP_STATE -eq 0 && ${#DELETED_LIST[@]} -gt 0 && ${#BRIDGE_PATHS[@]} -gt 0 ]]; then
    # Honor TK_UNINSTALL_HOME → TK_BRIDGE_HOME so the helper resolves the
    # same state file path we are operating on.
    export TK_BRIDGE_HOME="${TK_UNINSTALL_HOME:-${TK_BRIDGE_HOME:-$HOME}}"
    for deleted in "${DELETED_LIST[@]}"; do
        # Linear scan to find this deleted path in BRIDGE_PATHS.
        idx=0
        for bp in "${BRIDGE_PATHS[@]}"; do
            if [[ "$bp" == "$deleted" ]]; then
                _bridge_remove_state_entry \
                    "${BRIDGE_TARGETS[$idx]}" \
                    "${BRIDGE_SCOPES[$idx]}" \
                    "$bp" >/dev/null 2>&1 \
                    || log_warning "Failed to purge bridges[] entry for $bp"
                break
            fi
            idx=$((idx + 1))
        done
    done
fi

# ───────── Post-run summary (4-group) ─────────
# IMPORTANT: every array iteration uses the bash 3.2-safe array-length guard
# pattern — NEVER the inline `[@]:-` default modifier. Empty arrays under
# set -u raise "unbound variable" without the explicit length check.
echo ""
echo "Uninstall Summary"
echo "─────────────────"

if [[ ${#DELETED_LIST[@]} -gt 0 ]]; then
    printf '%bDELETED %d%b\n' "$GREEN" "${#DELETED_LIST[@]}" "$NC"
    for p in "${DELETED_LIST[@]}"; do
        echo "  $p"
    done
else
    printf '%bDELETED 0%b\n' "$GREEN" "$NC"
fi

# KEEP_LIST is the post-prompt result (files user chose N on, or default-kept).
if [[ ${#KEEP_LIST[@]} -gt 0 ]]; then
    printf '%bKEPT %d%b (locally modified, user chose N)\n' "$YELLOW" "${#KEEP_LIST[@]}" "$NC"
    for p in "${KEEP_LIST[@]}"; do
        echo "  $p"
    done
fi

if [[ ${#MISSING_LIST[@]} -gt 0 ]]; then
    printf '%bMISSING %d%b (registered but absent)\n' "$BLUE" "${#MISSING_LIST[@]}" "$NC"
    for p in "${MISSING_LIST[@]}"; do
        echo "  $p"
    done
fi

if [[ ${#PROTECTED_LIST[@]} -gt 0 ]]; then
    printf '%bPROTECTED %d%b (excluded by safety policy)\n' "$RED" "${#PROTECTED_LIST[@]}" "$NC"
    for p in "${PROTECTED_LIST[@]}"; do
        echo "  $p"
    done
fi

if [[ ${#DELETE_FAILED_LIST[@]} -gt 0 ]]; then
    printf '%bDELETE_FAILED %d%b\n' "$RED" "${#DELETE_FAILED_LIST[@]}" "$NC"
    for p in "${DELETE_FAILED_LIST[@]}"; do
        echo "  $p"
    done
fi

printf '%bBACKED UP%b to %s\n' "$CYAN" "$NC" "$BACKUP_DIR"

# ═════════════════════════════════════════════════════════════════════════════
# UN-05: Phase 19 finalization — sentinel strip + base-plugin invariant + state delete
# Order per CONTEXT.md D-06: backup (done) → strip → file-delete (done) → state-delete (LAST)
# ═════════════════════════════════════════════════════════════════════════════

# ───────── UN-05: strip toolkit sentinel block from ~/.claude/CLAUDE.md ─────────
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -n "${TK_UNINSTALL_HOME:-}" ]]; then
    GLOBAL_CLAUDE_MD="$TK_UNINSTALL_HOME/.claude/CLAUDE.md"
fi
strip_sentinel_block "$GLOBAL_CLAUDE_MD"

# ───────── UN-05: base-plugin invariant — verify no mutation occurred ─────────
# Snapshots taken post-state-read (before any mutation). Capture post-state now.
find "$SP_DIR"  -type f 2>/dev/null | sort > "$SP_AFTER_TMP"  || true
find "$GSD_DIR" -type f 2>/dev/null | sort > "$GSD_AFTER_TMP" || true

if ! diff -q "$SP_SNAP_TMP" "$SP_AFTER_TMP" >/dev/null 2>&1; then
    log_error "BUG: superpowers plugin tree was modified during uninstall — aborting"
    log_error "  expected: $(wc -l < "$SP_SNAP_TMP" | tr -d '[:space:]') files; got: $(wc -l < "$SP_AFTER_TMP" | tr -d '[:space:]') files"
    exit 1
fi
if ! diff -q "$GSD_SNAP_TMP" "$GSD_AFTER_TMP" >/dev/null 2>&1; then
    log_error "BUG: get-shit-done plugin tree was modified during uninstall — aborting"
    log_error "  expected: $(wc -l < "$GSD_SNAP_TMP" | tr -d '[:space:]') files; got: $(wc -l < "$GSD_AFTER_TMP" | tr -d '[:space:]') files"
    exit 1
fi

# ───────── UN-05: delete toolkit-install.json (LAST step, D-06) ─────────
# Failure logs warning but exits 0: files already removed; orphaned state is recoverable
# by manual `rm`. Hard-fail on state-delete failure would leave the user thinking the
# uninstall didn't work when in reality only the bookkeeping is stuck.
# When KEEP_STATE=1 (--keep-state or TK_UNINSTALL_KEEP_STATE=1, KEEP-01), the state
# file is preserved instead — see KEEP-02 test for the re-run recovery contract.
if [[ $KEEP_STATE -eq 0 ]]; then
    if rm -f "$STATE_FILE"; then
        log_success "State file removed: $STATE_FILE"
    else
        log_warning "Failed to remove $STATE_FILE — uninstall is complete but state file is orphaned. Remove manually: rm '$STATE_FILE'"
    fi
else
    log_info "State file preserved (--keep-state): $STATE_FILE"
fi

echo ""
log_success "Uninstall complete. Toolkit removed from ${PROJECT_DIR}/.claude/"
exit 0
