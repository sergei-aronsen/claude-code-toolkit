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
    # Prefer the standard CLI tools — `shasum` ships with macOS, `sha256sum`
    # is GNU coreutils (Linux). Both run in ~5–10ms vs ~80–120ms for a
    # cold python3 fork, which dominates wallclock when the diff loop hashes
    # 80+ files per update (audit PERF-02). Fall back to python only as a
    # last resort so we still work in minimal environments.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],"rb") as f:
    for c in iter(lambda: f.read(65536), b""): h.update(c)
print(h.hexdigest())' "$path"
    else
        return 1
    fi
}

read_state() {
    [[ -f "$STATE_FILE" ]] || return 1
    python3 -c 'import json,sys; json.load(open(sys.argv[1])); sys.stdout.write(open(sys.argv[1]).read())' "$STATE_FILE"
}

write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7" synth_flag="${8:-false}"
    # Audit C-04: manifest_hash is an explicit, optional 9th argument so the
    # field is always written atomically together with installed_files.
    # Previously it was spliced in by a separate jq call after write_state
    # returned — if the script was interrupted between the two, the state
    # was left without manifest_hash and is_update_noop never fired again.
    local manifest_hash="${9:-}"
    # Phase 29 BRIDGE-SYNC-02: optional 10th arg carries the .bridges[] array
    # forward across rebuilds. Default '[]' is treated as "preserve existing"
    # so a 9-arg caller (init-local.sh / migrate-to-complement.sh / Phase 28
    # tests) does NOT clobber bridges that were created by previous runs.
    # When the caller wants to overwrite, pass a non-default JSON string
    # (e.g. '[]' from an explicit `jq -c '.bridges // []'` capture).
    local bridges_json="${10:-[]}"
    mkdir -p "$(dirname "$STATE_FILE")"
    python3 - "$mode" "$has_sp" "$sp_ver" "$has_gsd" "$gsd_ver" \
             "$installed_csv" "$skipped_csv" "$synth_flag" "$manifest_hash" \
             "$bridges_json" "$STATE_FILE" <<'PYEOF'
import json, os, sys, tempfile, hashlib
from datetime import datetime, timezone

mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv, synth_flag, manifest_hash, bridges_json, state_path = sys.argv[1:12]

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
    "version": 2,
    "mode": mode,
    "synthesized_from_filesystem": synth_flag == "true",
    "detected": {
        "superpowers": {"present": has_sp == "true", "version": sp_ver},
        "gsd":         {"present": has_gsd == "true", "version": gsd_ver},
    },
    "installed_files": installed,
    "skipped_files": skipped,
    "manifest_hash": manifest_hash,
    "installed_at": now,
}

# Phase 29 BRIDGE-SYNC-02: bridges[] preservation.
# bridges_json default '[]' means "preserve whatever is already on disk".
# A non-default JSON string overrides whatever is on disk (used by Phase 29
# update-claude.sh which captures bridges_json with jq before calling).
if bridges_json == "[]" and os.path.exists(state_path):
    try:
        with open(state_path) as _f:
            _existing = json.load(_f)
        state["bridges"] = _existing.get("bridges", [])
    except Exception:
        state["bridges"] = []
else:
    try:
        state["bridges"] = json.loads(bridges_json) if bridges_json else []
    except Exception:
        state["bridges"] = []

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
        # Audit C-02: there is a TOCTOU window between mkdir(LOCK_DIR) and
        # the holder writing `pid`. Wait briefly for the file to appear so
        # we don't reclaim a live lock whose PID hasn't been written yet.
        local pid_wait=0
        while [[ ! -s "$LOCK_DIR/pid" && $pid_wait -lt 5 ]]; do
            sleep 0.1
            pid_wait=$((pid_wait + 1))
        done
        # Audit M-State: a hostile or corrupt pid file (e.g. multi-GB) would
        # blow memory if read whole. Cap at 16 bytes — a 64-bit PID never
        # exceeds 19 decimal digits.
        old_pid=$(head -c 16 "$LOCK_DIR/pid" 2>/dev/null || echo "")

        # If the holder still hasn't written its pid, treat as a live race
        # and retry — never `rm -rf` a lock with no PID, that's how two
        # processes end up thinking they hold the lock simultaneously.
        if [[ -z "$old_pid" ]]; then
            retries=$((retries + 1))
            if [[ $retries -ge 5 ]]; then
                echo -e "${RED}✗${NC} Another install is starting up (no PID written yet). Exiting." >&2
                return 1
            fi
            sleep 1
            continue
        fi

        # Validate pid is integer before any further use (audit Sec-L3).
        [[ "$old_pid" =~ ^[0-9]+$ ]] || old_pid=""

        # Signal 1+2 combined (audit I2 fix): PID liveness alone is unsafe
        # because the kernel recycles PIDs on busy machines — kill -0 returning
        # non-zero could mean "the holder exited" OR "the holder's PID was
        # reassigned to a wrapping live process and we're testing the wrong
        # one". Require BOTH `kill -0` failure AND lock age > 60s before
        # reclaiming. A genuinely dead lock will satisfy both within a
        # minute; a freshly-PID-recycled lock will still pass age < 60s and
        # we'll wait or fail the install.
        local lock_mtime now age
        lock_mtime=$(get_mtime "$LOCK_DIR")
        now=$(date +%s)
        age=$((now - lock_mtime))
        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            if [[ $age -gt 60 ]]; then
                echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID $old_pid (process gone, age ${age}s)"
                # rm -rf is intentional; LOCK_DIR is set at the top of state.sh
                # to a known absolute path under ~/.claude — never empty.
                [[ -n "$LOCK_DIR" && "$LOCK_DIR" != "/" ]] && rm -rf "$LOCK_DIR"
                continue
            fi
            # PID gone but lock too young to trust the kill -0 result —
            # treat as "still warming up", loop with a short sleep.
            retries=$((retries + 1))
            if [[ $retries -ge 5 ]]; then
                echo -e "${RED}✗${NC} Lock holder PID $old_pid recently exited; refusing to race. Exiting." >&2
                return 1
            fi
            sleep 1
            continue
        fi

        # Hard ceiling: 3600s — assume nothing legitimate runs that long.
        if [[ $age -gt 3600 ]]; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID ${old_pid:-unknown} (lock age: ${age}s)"
            [[ -n "$LOCK_DIR" && "$LOCK_DIR" != "/" ]] && rm -rf "$LOCK_DIR"
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
    # Audit H1: must only release the lock we own. If acquire_lock's
    # stale-reclaim path (line 211-217) gave a different PID our slot,
    # that PID is now mid-mutation; deleting unconditionally would let a
    # third process barge in. Compare $LOCK_DIR/pid against $$ first.
    [[ -d "$LOCK_DIR" ]] || return 0
    local lock_pid=""
    lock_pid=$(head -c 16 "$LOCK_DIR/pid" 2>/dev/null || echo "")
    [[ "$lock_pid" =~ ^[0-9]+$ ]] || lock_pid=""
    if [[ "$lock_pid" == "$$" ]]; then
        [[ -n "$LOCK_DIR" && "$LOCK_DIR" != "/" ]] && rm -rf "$LOCK_DIR"
    fi
    return 0
}
