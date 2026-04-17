#!/bin/bash

# Claude Code Toolkit — Install State Library
# Source this file. Do NOT execute it directly.
# Exposes: write_state, read_state, sha256_file, get_mtime, iso8601_utc_now,
#          acquire_lock, release_lock
# Globals: STATE_FILE, LOCK_DIR (absolute paths, set based on $HOME at source time)
#
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
#            Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock.

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

STATE_FILE="$HOME/.claude/toolkit-install.json"
LOCK_DIR="$HOME/.claude/.toolkit-install.lock"

iso8601_utc_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

get_mtime() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}

sha256_file() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$path"
}

read_state() {
    [[ -f "$STATE_FILE" ]] || return 1
    python3 -c 'import json,sys; json.load(open(sys.argv[1])); sys.stdout.write(open(sys.argv[1]).read())' "$STATE_FILE"
}

write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7"
    mkdir -p "$(dirname "$STATE_FILE")"
    python3 - "$mode" "$has_sp" "$sp_ver" "$has_gsd" "$gsd_ver" "$installed_csv" "$skipped_csv" "$STATE_FILE" <<'PYEOF'
import json, os, sys, tempfile, hashlib
from datetime import datetime, timezone

mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv, state_path = sys.argv[1:9]

def sha256(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

installed = []
if installed_csv:
    for path in installed_csv.split(","):
        path = path.strip()
        if not path:
            continue
        if os.path.isfile(path):
            installed.append({"path": path, "sha256": sha256(path), "installed_at": now})
        else:
            # Record even when we can't hash — Phase 3 install may still be in progress
            installed.append({"path": path, "sha256": "", "installed_at": now})

skipped = []
if skipped_csv:
    for entry in skipped_csv.split(","):
        entry = entry.strip()
        if not entry:
            continue
        # Split on FIRST colon only: reason itself may contain colons
        # (e.g. "conflicts_with:superpowers")
        parts = entry.split(":", 1)
        if len(parts) == 2:
            skipped.append({"path": parts[0], "reason": parts[1]})
        else:
            skipped.append({"path": entry, "reason": ""})

state = {
    "version": 1,
    "mode": mode,
    "detected": {
        "superpowers": {"present": has_sp == "true", "version": sp_ver},
        "gsd":         {"present": has_gsd == "true", "version": gsd_ver},
    },
    "installed_files": installed,
    "skipped_files": skipped,
    "installed_at": now,
}

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
}

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_DIR")"   # Pitfall 6: ~/.claude/ may not exist on fresh machine
    local retries=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        local old_pid=""
        old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")

        # Signal 1: PID liveness (kill -0 sends no signal; returns 0 if process exists)
        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID $old_pid (process no longer running)"
            rm -rf "$LOCK_DIR"
            continue
        fi

        # Signal 2: mtime age > 3600s
        local lock_mtime now age
        lock_mtime=$(get_mtime "$LOCK_DIR")
        now=$(date +%s)
        age=$((now - lock_mtime))
        if [[ $age -gt 3600 ]]; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID ${old_pid:-unknown} (lock age: ${age}s)"
            rm -rf "$LOCK_DIR"
            continue
        fi

        retries=$((retries + 1))
        if [[ $retries -ge 3 ]]; then
            echo -e "${RED}✗${NC} Another install is in progress (PID ${old_pid:-unknown}). Exiting." >&2
            return 1
        fi
        sleep 1
    done
    echo $$ > "$LOCK_DIR/pid"
    return 0
}

release_lock() {
    [[ -d "$LOCK_DIR" ]] && rm -rf "$LOCK_DIR"
    return 0
}
