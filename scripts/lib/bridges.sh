#!/bin/bash

# Claude Code Toolkit — Multi-CLI Bridge Library (v4.7+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   bridge_create_project <target> [project_root]  — write GEMINI.md/AGENTS.md
#                                                    next to <project_root>/CLAUDE.md
#   bridge_create_global  <target>                 — write under ~/.gemini/ or ~/.codex/
#                                                    using ~/.claude/CLAUDE.md as source
# Where <target> is one of: gemini | codex
# Returns: 0 = success, 1 = missing source, 2 = mkdir/write blocked, 3 = bad target
#
# Side effect: registers each created bridge in
#   ${TK_BRIDGE_HOME:-$HOME}/.claude/toolkit-install.json under the .bridges[] array
#   via an atomic python3 tempfile.mkstemp+os.replace patch. Dedup by (target,scope,path).
#
# Test seams:
#   TK_BRIDGE_HOME — override $HOME for global write target and state file path
#                    (default: $HOME). Mirrors TK_MCP_CONFIG_HOME from v4.6 Phase 25.
#
# IMPORTANT: No errexit/nounset/pipefail here — sourced libraries must not alter caller error mode.
#            _bridge_write_state_entry calls acquire_lock then release_lock inline so callers do
#            NOT need to register a trap themselves (the function uses inline release rather than
#            EXIT trap to avoid clobbering caller-registered traps).
#
# Codex reads AGENTS.md (NOT CODEX.md) — this is the OpenAI standard.
# Gemini reads GEMINI.md.

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

# Source sibling libs only if not already available.
# Guards against the case where bridges.sh is sourced from a tmpfile by
# update-claude.sh (which already sourced state.sh + dry-run-output.sh
# into the current shell from their own tmpfiles — BASH_SOURCE[0] would
# resolve to the tmpdir, not scripts/lib/, causing a "No such file" error).
if ! command -v write_state >/dev/null 2>&1; then
    # BASH_SOURCE[0]:- guards against unset under set -u (Bash 3.2 portability).
    _BRIDGES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    # shellcheck source=/dev/null
    source "${_BRIDGES_LIB_DIR}/state.sh"
    # shellcheck source=/dev/null
    source "${_BRIDGES_LIB_DIR}/dry-run-output.sh"
fi

# ──────────────────────────────────────────────────────────────────────────
# Internal helpers (prefixed with _bridge_, not part of public API)
# ──────────────────────────────────────────────────────────────────────────

# _bridge_home — return $HOME or the TK_BRIDGE_HOME override (test seam).
_bridge_home() {
    echo "${TK_BRIDGE_HOME:-$HOME}"
}

# _bridge_state_file — resolve toolkit-install.json path:
#   1. TK_BRIDGE_HOME set → ${TK_BRIDGE_HOME}/.claude/toolkit-install.json (sandbox)
#   2. STATE_FILE inherited from caller (init-claude.sh / update-claude.sh / install.sh
#      override it to project-local "$CLAUDE_DIR/toolkit-install.json")
#   3. Default: $HOME/.claude/toolkit-install.json (state.sh default for standalone use)
_bridge_state_file() {
    if [[ -n "${TK_BRIDGE_HOME:-}" ]]; then
        echo "${TK_BRIDGE_HOME}/.claude/toolkit-install.json"
    else
        echo "${STATE_FILE:-$HOME/.claude/toolkit-install.json}"
    fi
}

# _bridge_lock_dir — companion to _bridge_state_file for lock dir resolution.
_bridge_lock_dir() {
    if [[ -n "${TK_BRIDGE_HOME:-}" ]]; then
        echo "${TK_BRIDGE_HOME}/.claude/.toolkit-install.lock"
    else
        echo "${LOCK_DIR:-$HOME/.claude/.toolkit-install.lock}"
    fi
}

# _bridge_filename — map target name to its conventional bridge filename.
# gemini → GEMINI.md, codex → AGENTS.md (OpenAI standard, NOT CODEX.md).
_bridge_filename() {
    local target="$1"
    case "$target" in
        gemini) echo "GEMINI.md" ;;
        codex)  echo "AGENTS.md" ;;
        *)      return 1 ;;
    esac
}

# _bridge_global_dir — directory under TK_BRIDGE_HOME for global bridge writes.
# gemini → $home/.gemini, codex → $home/.codex.
_bridge_global_dir() {
    local target="$1"
    local home
    home="$(_bridge_home)"
    case "$target" in
        gemini) echo "${home}/.gemini" ;;
        codex)  echo "${home}/.codex"  ;;
        *)      return 1 ;;
    esac
}

# _bridge_write_file — atomic-ish file write with banner heredoc + verbatim source.
# Args: $1=source-path (must exist), $2=target-abs-path
# Returns: 0=success, 1=missing source, 2=mkdir/write blocked.
# Banner is byte-identical across all bridges (BRIDGE-GEN-03 contract).
_bridge_write_file() {
    local source="$1" target_path="$2"
    [[ -f "$source" ]] || return 1
    mkdir -p "$(dirname "$target_path")" 2>/dev/null || return 2
    {
        cat <<'BANNER'
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
BANNER
        echo ""
        cat "$source"
    } > "$target_path" 2>/dev/null || return 2
    return 0
}

# _bridge_write_state_entry — register / replace one entry under .bridges[] in
# toolkit-install.json. Atomic via python3 tempfile.mkstemp + os.replace.
# Args: $1=target (gemini|codex), $2=path (abs), $3=scope (project|global),
#       $4=source_sha256, $5=bridge_sha256
# Returns: 0=success, 1=python failure / lock failure
#
# Why not write_state? state.sh::write_state rebuilds the entire JSON document
# from positional args (mode, has_sp, sp_ver, ...) and would clobber
# installed_files[]. Bridges need a surgical patch of one top-level key.
_bridge_write_state_entry() {
    local target="$1" path="$2" scope="$3" source_sha="$4" bridge_sha="$5"
    local state_file
    state_file="$(_bridge_state_file)"

    # Honour the resolved state file's parent for the lock dir so
    # hermetic tests / project-local installs share the same scope.
    local saved_lock_dir="${LOCK_DIR:-}"
    LOCK_DIR="$(_bridge_lock_dir)"

    # Self-deadlock guard: if the caller (e.g. update-claude.sh sync_bridges path)
    # already holds the lock under this PID, skip acquire/release to avoid a 3-retry
    # spin that would silently drop the state write.
    local _caller_holds_lock=0
    local _existing_pid
    _existing_pid=$(cat "${LOCK_DIR}/pid" 2>/dev/null || echo "")
    if [[ "$_existing_pid" == "$$" ]]; then
        _caller_holds_lock=1
    fi

    if [[ $_caller_holds_lock -eq 0 ]] && ! acquire_lock; then
        LOCK_DIR="$saved_lock_dir"
        return 1
    fi

    local rc=0
    python3 - "$target" "$path" "$scope" "$source_sha" "$bridge_sha" \
              "$state_file" <<'PYEOF' || rc=1
import json, os, sys, tempfile

target, path, scope, src_sha, br_sha, state_path = sys.argv[1:7]

if os.path.exists(state_path):
    with open(state_path) as f:
        state = json.load(f)
else:
    state = {}

bridges = state.get("bridges", [])

entry = {
    "target": target,
    "path": path,
    "scope": scope,
    "source_sha256": src_sha,
    "bridge_sha256": br_sha,
    "user_owned": False,
}

idx = next(
    (i for i, e in enumerate(bridges)
     if e.get("target") == target
        and e.get("scope") == scope
        and e.get("path") == path),
    None,
)
if idx is not None:
    bridges[idx] = entry
else:
    bridges.append(entry)

state["bridges"] = bridges

out_dir = os.path.dirname(os.path.abspath(state_path))
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF

    [[ $_caller_holds_lock -eq 0 ]] && release_lock
    LOCK_DIR="$saved_lock_dir"
    return $rc
}

# bridge_create_project — write GEMINI.md/AGENTS.md next to <project_root>/CLAUDE.md.
# Args: $1=target (gemini|codex), $2=project_root (optional, defaults to $PWD)
# Returns: 0=success, 1=missing source, 2=mkdir/write blocked, 3=bad target.
bridge_create_project() {
    local target="$1"
    local project_root="${2:-$PWD}"

    local filename
    filename="$(_bridge_filename "$target")" || return 3

    local source target_path
    source="${project_root}/CLAUDE.md"
    target_path="${project_root}/${filename}"

    [[ -f "$source" ]] || return 1

    _bridge_write_file "$source" "$target_path"
    local rc=$?
    [[ $rc -eq 0 ]] || return $rc

    # Hash AFTER the write completes (Pitfall 4: redirect must be closed).
    local source_sha bridge_sha
    source_sha="$(sha256_file "$source" 2>/dev/null || echo '')"
    bridge_sha="$(sha256_file "$target_path" 2>/dev/null || echo '')"

    _bridge_write_state_entry "$target" "$target_path" "project" \
        "$source_sha" "$bridge_sha" || return 1

    return 0
}

# bridge_create_global — write under ~/.gemini/ or ~/.codex/ using ~/.claude/CLAUDE.md.
# NEVER modifies ~/.claude/CLAUDE.md (the canonical source).
# Args: $1=target (gemini|codex)
# Returns: 0=success, 1=missing source, 2=mkdir/write blocked, 3=bad target.
bridge_create_global() {
    local target="$1"

    local filename global_dir
    filename="$(_bridge_filename "$target")" || return 3
    global_dir="$(_bridge_global_dir "$target")" || return 3

    local home source target_path
    home="$(_bridge_home)"
    source="${home}/.claude/CLAUDE.md"
    target_path="${global_dir}/${filename}"

    [[ -f "$source" ]] || return 1

    _bridge_write_file "$source" "$target_path"
    local rc=$?
    [[ $rc -eq 0 ]] || return $rc

    local source_sha bridge_sha
    source_sha="$(sha256_file "$source" 2>/dev/null || echo '')"
    bridge_sha="$(sha256_file "$target_path" 2>/dev/null || echo '')"

    _bridge_write_state_entry "$target" "$target_path" "global" \
        "$source_sha" "$bridge_sha" || return 1

    return 0
}

# ──────────────────────────────────────────────────────────────────────────
# Phase 29 helpers — bridges[] state-only mutations + drift prompt
# ──────────────────────────────────────────────────────────────────────────

# _bridge_set_user_owned — flip user_owned on every bridges[] entry whose
# target matches. Single-flag-many-rows resolution: --break-bridge gemini
# affects both project and global gemini bridges (per CONTEXT.md decision).
# Args: $1=target (gemini|codex), $2=value (true|false)
# Returns: 0=success, 1=python failure / lock failure, 3=bad args
_bridge_set_user_owned() {
    local target="$1" value="$2"
    case "$target" in gemini|codex) : ;; *) return 3 ;; esac
    case "$value"  in true|false)   : ;; *) return 3 ;; esac

    local state_file
    state_file="$(_bridge_state_file)"

    # No state file means there is nothing to mutate — treat as success no-op.
    [[ -f "$state_file" ]] || return 0

    local saved_lock_dir="${LOCK_DIR:-}"
    LOCK_DIR="$(_bridge_lock_dir)"

    local _caller_holds_lock=0
    local _existing_pid
    _existing_pid=$(cat "${LOCK_DIR}/pid" 2>/dev/null || echo "")
    if [[ "$_existing_pid" == "$$" ]]; then
        _caller_holds_lock=1
    fi

    if [[ $_caller_holds_lock -eq 0 ]] && ! acquire_lock; then
        LOCK_DIR="$saved_lock_dir"
        return 1
    fi

    local rc=0
    python3 - "$target" "$value" "$state_file" <<'PYEOF' || rc=1
import json, os, sys, tempfile

target, value, state_path = sys.argv[1:4]
new_user_owned = (value == "true")

with open(state_path) as f:
    state = json.load(f)

bridges = state.get("bridges", [])
for e in bridges:
    if e.get("target") == target:
        e["user_owned"] = new_user_owned
state["bridges"] = bridges

out_dir = os.path.dirname(os.path.abspath(state_path))
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF

    [[ $_caller_holds_lock -eq 0 ]] && release_lock
    LOCK_DIR="$saved_lock_dir"
    return $rc
}

# _bridge_remove_state_entry — remove one bridges[] entry matching the
# (target, scope, path) triple. Atomic patch via tempfile + os.replace.
# Args: $1=target (gemini|codex), $2=scope (project|global), $3=path (abs)
# Returns: 0=success (or no-op if not found / no state file), 1=python failure
_bridge_remove_state_entry() {
    local target="$1" scope="$2" path="$3"

    local state_file
    state_file="$(_bridge_state_file)"

    [[ -f "$state_file" ]] || return 0   # no state = nothing to remove

    local saved_lock_dir="${LOCK_DIR:-}"
    LOCK_DIR="$(_bridge_lock_dir)"

    local _caller_holds_lock=0
    local _existing_pid
    _existing_pid=$(cat "${LOCK_DIR}/pid" 2>/dev/null || echo "")
    if [[ "$_existing_pid" == "$$" ]]; then
        _caller_holds_lock=1
    fi

    if [[ $_caller_holds_lock -eq 0 ]] && ! acquire_lock; then
        LOCK_DIR="$saved_lock_dir"
        return 1
    fi

    local rc=0
    python3 - "$target" "$scope" "$path" "$state_file" <<'PYEOF' || rc=1
import json, os, sys, tempfile

target, scope, path, state_path = sys.argv[1:5]

with open(state_path) as f:
    state = json.load(f)

bridges = state.get("bridges", [])
filtered = [
    e for e in bridges
    if not (
        e.get("target") == target
        and e.get("scope")  == scope
        and e.get("path")   == path
    )
]
state["bridges"] = filtered

out_dir = os.path.dirname(os.path.abspath(state_path))
os.makedirs(out_dir, exist_ok=True)
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, prefix="toolkit-install.", suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
    os.replace(tmp_path, state_path)
except Exception:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
    raise
PYEOF

    [[ $_caller_holds_lock -eq 0 ]] && release_lock
    LOCK_DIR="$saved_lock_dir"
    return $rc
}

# bridge_prompt_drift — interactive [y/N/d] for a drifted bridge file.
# Returns: 0 = overwrite, 1 = keep (default; covers EOF / unknown / N).
# 'd' shows a diff between the bridge file on disk and the would-be-rewritten
# content (banner + verbatim source) and re-prompts.
# Args: $1=bridge_path (the on-disk drifted bridge), $2=source_path (the
#       canonical CLAUDE.md the rewrite would copy from)
#
# TTY source: < /dev/tty by default. TK_BRIDGE_TTY_SRC overrides — when set
# (non-empty), reads from that path instead. Mirrors
# scripts/uninstall.sh:233 TK_UNINSTALL_TTY_FROM_STDIN convention.
bridge_prompt_drift() {
    local bridge_path="$1" source_path="$2"

    local tty_target="/dev/tty"
    if [[ -n "${TK_BRIDGE_TTY_SRC:-}" ]]; then
        tty_target="$TK_BRIDGE_TTY_SRC"
    fi

    # Build the would-be-rewritten content into a tempfile so 'd' can diff.
    local tmp_new
    tmp_new=$(mktemp "${TMPDIR:-/tmp}/bridge-drift.XXXXXX")
    # shellcheck disable=SC2064  # capture path at trap-registration time
    trap "rm -f '$tmp_new'" RETURN
    if [[ -f "$source_path" ]]; then
        {
            cat <<'BANNER'
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
BANNER
            echo ""
            cat "$source_path"
        } > "$tmp_new" 2>/dev/null || true
    fi

    while :; do
        local choice=""
        if ! read -r -p "Bridge ${bridge_path} modified locally. Overwrite? [y/N/d]: " choice < "$tty_target" 2>/dev/null; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                return 0 ;;
            d|D)
                if [[ -s "$tmp_new" ]]; then
                    echo "── diff: bridge vs would-be-rewrite ──"
                    diff -u "$bridge_path" "$tmp_new" || true
                    echo "── end diff ──"
                else
                    echo "Reference unavailable (source missing) — diff cannot be shown."
                fi
                ;;
            *)
                return 1 ;;
        esac
    done
}
