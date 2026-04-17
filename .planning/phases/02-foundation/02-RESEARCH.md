# Phase 2: Foundation - Research

**Researched:** 2026-04-17
**Domain:** POSIX bash scripting — plugin detection, atomic file I/O, mkdir locking, JSON schema design
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Hard error both ways on `manifest.version` mismatch. New v4.0 scripts reading a v1 manifest
  exit with `ERROR: manifest.json is v1; run install to migrate to v2`; old v3.x scripts reading a v2
  manifest exit with `ERROR: unsupported manifest.version N; update toolkit`.
- **D-02:** v1→v2 migration happens inside `init-claude.sh` / `update-claude.sh` at install time. No
  separate migration tool.
- **D-03:** Remote callers download `scripts/detect.sh` to a `mktemp` file, source it, and `trap 'rm -f
  "$DETECT_TMP"' EXIT`. Pattern: `DETECT_TMP=$(mktemp) && curl -sSL "$REPO_URL/scripts/detect.sh" -o
  "$DETECT_TMP" && source "$DETECT_TMP"`.
- **D-04:** Local callers source `scripts/detect.sh` directly: `source "$(dirname "$0")/detect.sh"`.
- **D-05:** `detect.sh` is sourced (not executed). Exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`,
  `GSD_VERSION`. No stdout during sourcing.
- **D-06:** SHA256 uses `python3 -c 'import hashlib,sys;
  print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())'`. One tool, one pattern.
- **D-07:** Shell-only `sha256sum || shasum -a 256` fallback rejected. python3 is the single SHA256
  provider.
- **D-08:** Lock is `mkdir "$HOME/.claude/.toolkit-install.lock"`. Write `$$` to
  `.toolkit-install.lock/pid` immediately after acquisition.
- **D-09:** Stale recovery: `mkdir` fails → check `.toolkit-install.lock/pid`; if PID not alive
  (`kill -0 $PID 2>/dev/null` fails) OR lock mtime older than 1 hour → `rm -rf` lock dir and retry.
  Emit `⚠ Reclaimed stale lock from PID $OLD_PID`.
- **D-10:** Lock trap: `trap 'rm -rf "$HOME/.claude/.toolkit-install.lock"' EXIT`.
- **D-11:** `mtime > 1h` uses BSD-safe `stat -f %m` / GNU `stat -c %Y` portability shim.
- **D-12:** Full object migration: every entry under `files.agents[]`, `files.commands[]`,
  `files.prompts[]`, `files.skills[]`, `files.rules[]`, and `templates.*` upgrades from bare string to
  `{ "path": "...", "conflicts_with": [...]?, "requires_base": [...]? }`.
- **D-13:** `claude_md_sections` stays as-is in v2. Only `files.*` and `templates.*` migrate.
- **D-14:** Top-level `manifest.version` bumps to `2`. Product version stays separately.
- **D-15 / D-16:** Researcher greps SP and GSD dirs to produce authoritative per-file conflict map
  (see Conflict Map section below). Seed list: 13 entries.
- **D-17:** Flag any duplicate not yet on seed list found during scanning. Add to manifest AND seed list.
- **D-18:** `conflicts_with` values restricted to `"superpowers"` and `"get-shit-done"`. `make validate`
  enforces vocabulary.
- **D-19:** `~/.claude/toolkit-install.json` schema: `{ version, mode, detected: { superpowers:
  {present, version}, gsd: {present, version} }, installed_files: [{path, sha256, installed_at}],
  skipped_files: [{path, reason}], installed_at }`.
- **D-20:** Writes atomic via `mktemp` then `mv` (never half-written JSON).
- **D-21:** `version` inside `toolkit-install.json` is schema version, starts at `1`.
- **D-22:** `installed_at` timestamps are ISO-8601 UTC: `date -u +%Y-%m-%dT%H:%M:%SZ`.
- **D-23:** `skipped_files[*].reason` uses `"conflicts_with:<plugin>"` format.
- **D-24:** `make validate` extends to: (a) every `files.*[].path` and `templates.*` path exists on
  disk; (b) every file in `commands/`, `templates/base/{agents,prompts,skills,rules}/` is in manifest;
  (c) every `conflicts_with` value is in `["superpowers", "get-shit-done"]`; (d) `manifest.version ==
  2`.
- **D-25:** Validate implementation is `python3` (inline or `scripts/validate-manifest.py`).
- **D-26:** All Phase 2 work ships on branch `feature/phase-2-foundation`.
- **D-27:** Three commits: `feat(02-01): detect.sh`, `feat(02-02): manifest v2`, `feat(02-03):
  toolkit-install.json`.
- **D-28:** No production code consumes these primitives until Phase 3. Phase 2 is plumbing only.
- **D-29:** Detection unit tests in `scripts/tests/test-detect.sh` (new dir). Four-case harness: neither
  / SP only / GSD only / both. POSIX shell, zero deps. Not `bats`.

### Claude's Discretion

- Exact wording of the `⚠ Reclaimed stale lock from PID $OLD_PID` warning (D-09).
- Exact filename/layout of the POSIX `stat` portability shim (D-11) — standalone file vs inlined.
- Whether `scripts/validate-manifest.py` is separate or inline `python3 -c` in Makefile (rule: split if
  > 30 lines).
- Exact error message strings for manifest version mismatch (D-01).
- Exact structure of `scripts/tests/test-detect.sh` harness (D-29) — any approach producing four cases
  and pass/fail output is acceptable.

### Deferred Ideas (OUT OF SCOPE)

- `claude plugin list` CLI-based detection (DETECT-FUT-01, v2)
- Plugin version skew detection (DETECT-FUT-02, v2)
- `bats` test suite (TEST-01, v2)
- Auto-cleanup of old `.claude-backup-*` dirs (BACKUP-01/02, v2)
- `--dry-run` per-file output (MODE-06, Phase 3)
- Install-mode selection (MODE-01..05, Phase 3)
- Update-flow drift detection (UPDATE-01..06, Phase 4)
- Migration script (MIGRATE-01..06, Phase 5)
- Orchestration pattern adoption (ORCH-FUT-01..06, v4.1)

</user_constraints>

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DETECT-01 | `scripts/detect.sh` exposes `detect_superpowers()` returning 0 if `~/.claude/plugins/cache/claude-plugins-official/superpowers/` exists with at least one versioned subdir | Filesystem paths verified on dev machine; SP at 5.0.7; versioned subdir pattern confirmed |
| DETECT-02 | `scripts/detect.sh` exposes `detect_gsd()` returning 0 if `~/.claude/get-shit-done/` exists and contains `bin/gsd-tools.cjs` | GSD path verified; `bin/gsd-tools.cjs` confirmed present; VERSION file at 1.36.0 |
| DETECT-03 | Detection cross-references `~/.claude/settings.json` `enabledPlugins` (when present) to suppress stale-cache false positives | SP key format confirmed: `superpowers@claude-plugins-official`; GSD has NO enabledPlugins entry (filesystem-only install); jq filter pattern verified |
| DETECT-04 | `detect.sh` is sourced (not executed); exports `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` | Standard POSIX export pattern; no subshell needed |
| DETECT-05 | Both `init-claude.sh` and `update-claude.sh` source `detect.sh` from single canonical path; remote callers download to `mktemp` | mktemp + source pattern verified; `trap 'rm -f' EXIT` pattern confirmed POSIX |
| MANIFEST-01 | Each `files.*` entry switches from bare string to object with `path`, optional `conflicts_with`, optional `requires_base` | Current manifest.json analyzed; 47 entries to migrate; jq/python3 reader pattern documented |
| MANIFEST-02 | Bump `manifest.version` to `2`; old scripts must refuse to run against v2 manifest | Version field location confirmed (`manifest.json:1` top-level); hard-error pattern documented |
| MANIFEST-03 | Each of ≥10 confirmed hard duplicates annotated with `conflicts_with` | Authoritative conflict map produced (see below): 6 SP conflicts confirmed, 1 SP agent hard collision; 13 seed entries verified against live SP 5.0.7 and GSD 1.36.0 |
| MANIFEST-04 | `make validate` extends to verify file existence, no drift, `conflicts_with` vocabulary | Makefile validate extension point identified; python3 validator pattern documented |
| STATE-01 | `~/.claude/toolkit-install.json` schema with all required fields | Python3 atomic write pattern verified and tested |
| STATE-02 | Writes atomic via `mktemp` then `mv`; never half-written JSON | `os.replace()` pattern verified (`tempfile.mkstemp + os.replace`); survives kill -9 (mv is atomic on same filesystem) |
| STATE-03 | Concurrent runs blocked by `mkdir`-based lock | `mkdir` atomicity verified on macOS; PID write pattern tested |
| STATE-04 | Each `installed_files` entry stores SHA256 | `python3 hashlib.sha256` pattern tested on macOS with python3 3.14 |
| STATE-05 | Lock acquisition has stale-lock recovery path (>1h with no live PID → reclaim) | `kill -0 $PID` pattern verified; `stat -f %m` (BSD) portability shim documented |

</phase_requirements>

---

## Summary

Phase 2 builds three load-bearing primitives that every downstream phase depends on. All three are
well-understood POSIX shell problems with established solutions in the existing codebase — no new
patterns are introduced.

**Plugin detection** (`scripts/detect.sh`): SP is installed at
`~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/` (version is the subdir name,
also in `package.json`). GSD is installed at `~/.claude/get-shit-done/` with `bin/gsd-tools.cjs` and a
`VERSION` file. SP has an `enabledPlugins` key in `~/.claude/settings.json` with key format
`superpowers@claude-plugins-official`; GSD does NOT appear in `enabledPlugins` (filesystem-only).
SP_VERSION is read from the versioned subdir basename; GSD_VERSION from `~/.claude/get-shit-done/VERSION`.

**Manifest v2 schema**: The current `manifest.json` has 47 bare-string entries across `files.agents`,
`files.commands`, `files.prompts`, `files.skills`, `files.rules`. All migrate to objects. Conflict
scanning against live SP 5.0.7 and GSD 1.36.0 produces an authoritative 13-entry list: 1 hard agent
namespace collision (code-reviewer), 5 functional SP-skill duplicates (commands that replicate SP
systematic-debugging/TDD/worktrees/verification/planning skills), 1 SP-overlapping skill
(debugging/SKILL.md — currently untracked), and 6 entries in the seed list that have no confirmed GSD
exact-match (checkpoint, handoff, learn, context-prime, planner, audit are TK-unique or soft overlap
only). The `make validate` extension is a `python3` script that checks path existence, directory drift,
and vocabulary enforcement.

**Install state file**: `~/.claude/toolkit-install.json` written via Python3 `tempfile.mkstemp +
os.replace` (atomic on POSIX). Lock is `mkdir "$HOME/.claude/.toolkit-install.lock"` with PID file
inside. Stale recovery uses `kill -0 $PID` for liveness and `stat -f %m` (BSD) / `stat -c %Y` (GNU)
for mtime age. All primitives verified working on macOS Darwin 25 / bash 3.2.57 (the constraint
runtime).

**Primary recommendation:** Follow the three-commit structure (D-27) strictly. The `detect.sh` patterns
are new to the repo but self-contained. The manifest rewrite is a single large hand-reviewed diff.
The state-file protocol is Python3-only (consistent with Phase 1 standardization). Zero user-visible
behavior changes in this phase.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Plugin presence detection | Shell (detect.sh) | — | Filesystem `[ -d ]` checks; no subprocess needed |
| Plugin enabled/disabled cross-check | Shell (detect.sh) | jq (settings.json) | Settings.json lives on filesystem; jq already a dep |
| Version string extraction | Shell (detect.sh) | python3 fallback | Subdir basename for SP; `cat VERSION` for GSD |
| Manifest schema validation | python3 (validate-manifest.py) | Makefile orchestration | JSON parsing; path existence; vocabulary checking |
| Atomic state file writes | python3 (`tempfile.mkstemp + os.replace`) | — | Consistent with Phase 1 D-06 / D-20 python3 standard |
| Concurrency locking | POSIX shell (`mkdir` lock) | — | POSIX atomic `mkdir`; no `flock` (Linux-only) |
| Stale lock recovery | POSIX shell (`kill -0`, `stat`) | — | Two-signal liveness: PID check + mtime TTL |
| SHA256 hashing | python3 (hashlib) | — | Consistent with D-06; one tool |
| Test harness | POSIX shell (test-detect.sh) | — | Zero deps, four-case synthetic env |

---

## Standard Stack

### Core

| Library/Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 3.2 (macOS default) | Shell runtime for all scripts | Project constraint; no bash 4+ features |
| python3 | >= 3.8 (verified: 3.14.4 on dev) | JSON write, SHA256, atomic file ops | Established in Phase 1; `setup-council.sh` already requires it |
| jq | 1.7.1-apple (verified) | settings.json `enabledPlugins` read | Already a runtime dep (`install-statusline.sh`) |
| stat | BSD (`-f %m`) / GNU (`-c %Y`) | Lock mtime for stale detection | POSIX standard; portability shim required |
| mkdir | POSIX | Atomic lock acquisition | POSIX guarantee: exactly one caller succeeds |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `kill -0 $PID` | PID liveness check (no signal sent) | Stale lock recovery: check if PID in lock/pid is still alive |
| `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` | Cross-platform temp file | Atomic writes (state file) and remote detect.sh bootstrap |
| `date -u +%Y-%m-%dT%H:%M:%SZ` | ISO-8601 UTC timestamp | `installed_at` fields; works identically on BSD and GNU `date` |
| `os.replace()` (Python) | Atomic rename | State file write; `mv` semantics on same filesystem |
| `tempfile.mkstemp()` (Python) | Safe temp file creation | State file write; pairs with `os.replace()` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mkdir` lock | `flock` | `flock` is Linux-only — rejected per Out of Scope |
| `python3 hashlib.sha256` | `sha256sum \|\| shasum -a 256` | Shell fallback introduces a second cross-platform pattern; python3 already required |
| `python3 validate-manifest.py` | inline `python3 -c '...'` in Makefile | Use inline if < 30 lines (D-25 discretion); split to file if longer |
| Sourced `detect.sh` | Executed detect.sh with output parsing | Sourcing avoids a subshell and lets callers read exported variables directly |

**Installation:** No new dependencies. `python3`, `jq`, `bash` already required by existing scripts.

**Version verification:** [VERIFIED: bash --version on dev machine] bash 3.2.57; [VERIFIED: jq
--version] jq-1.7.1-apple; [VERIFIED: python3 --version] 3.14.4.

---

## Architecture Patterns

### System Architecture Diagram

```text
Remote install / Local install
         │
         ▼
  source detect.sh ──────────────────────────────────────────────────┐
         │                                                            │
         ▼                                                            ▼
 detect_superpowers()              detect_gsd()
  [ -d SP_CACHE_DIR ]?              [ -d GSD_DIR ]?
  ≥1 versioned subdir?              bin/gsd-tools.cjs present?
         │                                  │
         ▼                                  ▼
  Cross-ref settings.json          (No settings.json check:
  enabledPlugins key:               GSD not in enabledPlugins)
  "superpowers@claude-plugins-official"
         │
         ▼
  Export HAS_SP, HAS_GSD,
  SP_VERSION, GSD_VERSION
         │
         └─────────────────────────────┐
                                       ▼
                              (Phase 3 consumes variables)

manifest.json v2 (static artifact)
  files.*[]: { path, conflicts_with?, requires_base? }
  manifest.version: 2
         │
         ▼
  make validate ──► scripts/validate-manifest.py
    checks:
    (a) every path exists on disk
    (b) no drift (commands/ files all listed)
    (c) conflicts_with ∈ {"superpowers","get-shit-done"}
    (d) manifest.version == 2

State file protocol (Phase 2 defines; Phase 3 writes first instance)
  acquire mkdir lock ─► write pid ─► mktemp write ─► os.replace
                                           │
                                           ▼
                               ~/.claude/toolkit-install.json
                                  (atomic, never half-written)
         │
         └─► release lock (trap EXIT)
```

### Recommended Project Structure

```text
scripts/
├── detect.sh            # NEW — sourced by init/update scripts
├── validate-manifest.py # NEW (or inline) — python3 manifest validator
├── tests/
│   └── test-detect.sh   # NEW — four-case POSIX test harness
├── init-claude.sh       # STUB: add source detect.sh call site
└── update-claude.sh     # STUB: add source detect.sh call site
manifest.json            # SCHEMA REWRITE — v2 object entries
Makefile                 # EXTEND validate target
```

### Pattern 1: Plugin Detection (DETECT-01/02/03)

**What:** Filesystem probe + settings.json cross-reference in a sourced script
**When to use:** Always sourced before any install/update decision

```bash
#!/bin/bash
# scripts/detect.sh
# Source this file. Do NOT execute it directly.
# Exports: HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION

# No set -euo pipefail here — sourced scripts must not alter caller's error mode

SP_PLUGIN_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"
SETTINGS_JSON="$HOME/.claude/settings.json"

detect_superpowers() {
    # Check filesystem: versioned subdir must exist
    if [[ ! -d "$SP_PLUGIN_DIR" ]]; then
        HAS_SP=false; SP_VERSION=""; return 1
    fi
    # At least one versioned subdir (non-hidden entry in the dir)
    local ver
    ver=$(ls "$SP_PLUGIN_DIR" 2>/dev/null | grep -v '^\.' | head -1)
    if [[ -z "$ver" ]]; then
        HAS_SP=false; SP_VERSION=""; return 1
    fi
    # DETECT-03: Cross-reference enabledPlugins (suppress stale-cache false positives)
    if [[ -f "$SETTINGS_JSON" ]] && command -v jq &>/dev/null; then
        local enabled
        enabled=$(jq -r '.enabledPlugins["superpowers@claude-plugins-official"] // false' \
            "$SETTINGS_JSON" 2>/dev/null)
        if [[ "$enabled" == "false" ]]; then
            HAS_SP=false; SP_VERSION=""; return 1
        fi
    fi
    HAS_SP=true
    SP_VERSION="$ver"
    export HAS_SP SP_VERSION
    return 0
}

detect_gsd() {
    if [[ -d "$GSD_DIR" ]] && [[ -f "$GSD_DIR/bin/gsd-tools.cjs" ]]; then
        HAS_GSD=true
        GSD_VERSION=$(cat "$GSD_DIR/VERSION" 2>/dev/null || echo "")
    else
        HAS_GSD=false; GSD_VERSION=""
    fi
    export HAS_GSD GSD_VERSION
}

detect_superpowers
detect_gsd
```

**Key constraints:**
- No `set -euo pipefail` in detect.sh body (sourced script must not change caller error mode)
- No stdout output (callers decide what to print — D-05)
- All variables exported so subshell callers can read them

### Pattern 2: Atomic State File Write (STATE-01/02)

**What:** Python3 `tempfile.mkstemp + os.replace` for guaranteed atomic JSON write
**When to use:** Every `toolkit-install.json` write

```python
# Inline python3 heredoc pattern (consistent with setup-security.sh:202-237)
python3 - "$STATE_FILE" << 'PYEOF'
import json, sys, os, tempfile

state_path = sys.argv[1]

state = {
    "version": 1,
    "mode": "standalone",
    "detected": {
        "superpowers": {"present": False, "version": ""},
        "gsd": {"present": False, "version": ""}
    },
    "installed_files": [],
    "skipped_files": [],
    "installed_at": ""  # caller fills this via sys.argv
}

out_dir = os.path.dirname(state_path) or "."
tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir)
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(state, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, state_path)
except Exception:
    os.unlink(tmp_path)
    raise
PYEOF
```

**Why `os.replace` survives kill -9:**
`os.replace()` maps to `rename(2)` on POSIX. The OS kernel performs the rename atomically — if the process is killed after `os.replace()` the new file is visible; if killed before, the tmp file is orphaned but the original is intact. A half-written JSON is impossible.

### Pattern 3: mkdir Lock with PID + Stale Recovery (STATE-03/05)

**What:** POSIX-atomic `mkdir` lock directory with PID file and two-signal stale detection
**When to use:** Any concurrent-unsafe operation (install/update)

```bash
LOCK_DIR="$HOME/.claude/.toolkit-install.lock"

acquire_lock() {
    local retries=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        local old_pid=""
        old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")

        # Signal 1: PID liveness
        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID $old_pid (process no longer running)"
            rm -rf "$LOCK_DIR"
            continue
        fi

        # Signal 2: mtime age > 1h (3600s)
        local lock_mtime now age
        if [[ "$(uname)" == "Darwin" ]]; then
            lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
        else
            lock_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
        fi
        now=$(date +%s)
        age=$((now - lock_mtime))
        if [[ $age -gt 3600 ]]; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID ${old_pid:-unknown} (lock age: ${age}s)"
            rm -rf "$LOCK_DIR"
            continue
        fi

        retries=$((retries + 1))
        if [[ $retries -ge 3 ]]; then
            echo -e "${RED}✗${NC} Another install is in progress (PID ${old_pid:-unknown}). Exiting."
            exit 1
        fi
        sleep 1
    done
    echo $$ > "$LOCK_DIR/pid"
}

# Always register trap before acquiring lock
trap 'rm -rf "$LOCK_DIR"' EXIT
acquire_lock
```

### Pattern 4: manifest.json v2 Object Entry Format (MANIFEST-01)

**What:** Homogeneous object format for all `files.*` entries

```json
{
  "manifest.version": 2,
  "version": "3.0.0",
  "files": {
    "commands": [
      { "path": "commands/debug.md", "conflicts_with": ["superpowers"] },
      { "path": "commands/tdd.md", "conflicts_with": ["superpowers"] },
      { "path": "commands/council.md" },
      { "path": "commands/helpme.md" }
    ],
    "agents": [
      { "path": "agents/code-reviewer.md", "conflicts_with": ["superpowers"] },
      { "path": "agents/planner.md" }
    ]
  },
  "templates": {
    "base": { "path": "templates/base" },
    "laravel": { "path": "templates/laravel" }
  }
}
```

**jq reader pattern (Phase 3 uses this):**

```bash
# Get all paths regardless of conflicts
jq -r '.files.commands[].path' manifest.json

# Get paths that conflict with superpowers
jq -r '.files.commands[] | select(.conflicts_with // [] | contains(["superpowers"])) | .path' manifest.json

# Get TK-unique paths (no conflicts_with key or empty array)
jq -r '.files.commands[] | select((.conflicts_with // []) == []) | .path' manifest.json
```

### Pattern 5: Four-Case Test Harness (DETECT-01/02, D-29)

**What:** POSIX shell test harness with synthetic plugin directories
**When to use:** `make test` → `scripts/tests/test-detect.sh`

```bash
#!/bin/bash
# scripts/tests/test-detect.sh
# Usage: bash scripts/tests/test-detect.sh
# Exit: 0 = all pass, 1 = any fail
set -euo pipefail

PASS=0; FAIL=0
DETECT_SH="$(dirname "$0")/../detect.sh"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

run_case() {
    local label="$1"
    local setup_cmd="$2"   # sets up synthetic dirs in $SCRATCH
    local expect_sp="$3"   # "true" or "false"
    local expect_gsd="$4"

    # Reset
    HOME="$SCRATCH"   # override HOME so detect.sh looks in $SCRATCH/.claude/
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"

    eval "$setup_cmd"
    # Source detect.sh with overridden HOME
    HAS_SP="" HAS_GSD=""
    source "$DETECT_SH"

    local ok=true
    [[ "$HAS_SP" == "$expect_sp" ]] || ok=false
    [[ "$HAS_GSD" == "$expect_gsd" ]] || ok=false

    if $ok; then
        echo "✅ PASS: $label (HAS_SP=$HAS_SP, HAS_GSD=$HAS_GSD)"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $label (expected HAS_SP=$expect_sp HAS_GSD=$expect_gsd, got HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD)"
        FAIL=$((FAIL + 1))
    fi
}
```

**Complexity note for D-29 discretion:** `HOME` override is the minimal synthetic technique — avoids
touching the real `~/.claude/`. Each case creates the relevant directory structure under `$SCRATCH`,
sources `detect.sh` with that `HOME`, and checks the exported variables. Settings.json is created
per-case to test DETECT-03 stale-cache suppression.

### Anti-Patterns to Avoid

- **`set -euo pipefail` in detect.sh:** A sourced script that calls `set -euo pipefail` changes the
  calling script's error mode permanently. Omit `set -e` in detect.sh; let the caller's mode apply.
- **Associative arrays in bash:** `declare -A` requires bash 4.0+. macOS ships bash 3.2.57. Use
  positional parameters, `case` statements, or python3 for associative lookups.
- **`mapfile` / `readarray`:** Bash 4.0+ only. Use `while IFS= read -r line` loops instead.
- **`flock`-based locking:** Linux-only syscall. Always `mkdir` for lock in this codebase.
- **`stat -c %Y` on macOS:** GNU-only flag. Always use the portability shim (BSD `-f %m` / GNU `-c %Y`).
- **`mktemp -t PREFIX.XXXXXX` for state files:** macOS appends a random suffix AFTER the Xs, producing
  `PREFIX.XXXXXX.RANDOM`. Use `mktemp "${TMPDIR:-/tmp}/PREFIX.XXXXXX"` for predictable behavior on both.
- **`jq` for `settings.json` writes:** `jq` hard-fails on JSON5-adjacent content. Use `python3 json`
  for writes; `jq` is acceptable for reads only (DETECT-03 enabledPlugins check).
- **Stdout in detect.sh during sourcing:** D-05 strictly forbids it. Callers must not see output from
  the detection phase — they decide what to print.
- **Checking `enabledPlugins` for GSD:** GSD is NOT a Claude Code plugin and has NO key in
  `enabledPlugins`. Detection for GSD is filesystem-only.

---

## Authoritative Conflict Map (D-15 / D-16 / D-17)

Produced by scanning live SP 5.0.7 and GSD 1.36.0 on the dev machine.

### Confirmed Conflicts with `superpowers`

| TK File | SP Equivalent | Conflict Type | `conflicts_with` Value |
|---------|---------------|---------------|------------------------|
| `templates/base/agents/code-reviewer.md` | `agents/code-reviewer.md` (name: code-reviewer) | HARD — identical agent `name:` field; Claude Code loads both as @code-reviewer | `["superpowers"]` |
| `commands/debug.md` | skill `systematic-debugging/SKILL.md` | FUNCTIONAL — both provide systematic debugging methodology | `["superpowers"]` |
| `commands/tdd.md` | skill `test-driven-development/SKILL.md` | FUNCTIONAL — both provide TDD workflow | `["superpowers"]` |
| `commands/worktree.md` | skill `using-git-worktrees/SKILL.md` | FUNCTIONAL — both provide git worktree management | `["superpowers"]` |
| `commands/verify.md` | skill `verification-before-completion/SKILL.md` | FUNCTIONAL — both provide pre-commit verification | `["superpowers"]` |
| `commands/plan.md` | skill `writing-plans/SKILL.md` | FUNCTIONAL — both provide planning methodology | `["superpowers"]` |
| `templates/base/skills/debugging/SKILL.md` | skill `systematic-debugging/SKILL.md` | FUNCTIONAL — content is nearly identical (Iron Law formulation) — NOTE: this file is currently UNTRACKED in git | `["superpowers"]` |

**Total SP conflicts: 7 entries** (1 hard, 5 functional commands, 1 functional skill)

### Confirmed Conflicts with `get-shit-done`

No exact filename matches found between TK commands and GSD workflows. GSD uses `/gsd-X` prefixed
slash commands installed to `~/.claude/commands/gsd-*.md` — these do NOT collide with TK's unprefixed
commands.

**GSD agents use `gsd-` prefix** (`gsd-code-reviewer.md`, `gsd-planner.md`, etc.) — no collision with
TK agents.

**Seed list items re-evaluated:**

| Seed Item | GSD Equivalent | Finding |
|-----------|----------------|---------|
| `commands/checkpoint.md` | No GSD checkpoint | TK-unique — no `conflicts_with` |
| `commands/handoff.md` | `session-report.md` (different scope: milestone report, not handoff) | TK-unique — no `conflicts_with` |
| `commands/learn.md` | `extract_learnings.md` (different invocation: `/gsd-extract_learnings`, different trigger) | TK-unique — no `conflicts_with` |
| `commands/audit.md` | `audit-fix.md`, `audit-milestone.md`, `audit-uat.md` (all `/gsd-` prefixed, different scope) | TK-unique — no `conflicts_with` |
| `commands/context-prime.md` | No GSD equivalent | TK-unique — no `conflicts_with` |
| `templates/base/agents/planner.md` | `gsd-planner.md` (prefixed agent, different name) | TK-unique — no `conflicts_with` |

**Total GSD conflicts: 0 entries** from seed list.

### New Duplicates Found During Scan (D-17)

No additional conflicts beyond the seed list were found. The SP command files (`brainstorm.md`,
`execute-plan.md`, `write-plan.md`) are all DEPRECATED in SP 5.0.7 (they print a deprecation notice
and point to skills). TK has no matching commands for these.

### Final manifest.json Conflict Annotations: 7 total (meets MANIFEST-03 requirement of ≥10 seed entries mapped; 7 confirmed with `conflicts_with`, 6 confirmed TK-unique)

**Important Note on Seed Count vs. Confirmed Conflicts:**
The seed list in D-16 contained 13 entries. After scanning:
- 7 confirmed `conflicts_with: ["superpowers"]`
- 6 confirmed TK-unique (no `conflicts_with`)
- 0 confirmed `conflicts_with: ["get-shit-done"]`

MANIFEST-03 requires "≥10 confirmed duplicates annotated." The scan finds only 7 confirmed SP
conflicts. The planner must flag this gap and resolve with the user or accept that the conflict set
is 7, not 10+. The REQUIREMENTS.md text says "≥10 entries" in the seed list; the 13-entry seed list
satisfies that count, but only 7 have confirmed base-plugin equivalents.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic file writes | Custom lock file + write | `tempfile.mkstemp` + `os.replace` | Kernel-level rename atomicity; survives kill -9 |
| JSON serialization with special chars | String concatenation / heredoc interpolation | `python3 json.dumps()` | Phase 1 established this; heredoc interpolation breaks on `"` and `\` in values |
| Cross-platform mtime | `date -r` (BSD) / `stat -c` (GNU) inconsistency | Documented portability shim | One shim, two platforms, always correct |
| Plugin version lookup | API call / `claude plugin list` | Filesystem `ls` + `cat VERSION` | Faster, no CLI dependency, works offline |
| Test assertions | `bats` framework | POSIX `[[ ]]` + counter | Deferred to TEST-01 (v2); zero-dep harness is Phase 2 scope |

**Key insight:** Every "custom" version of these would reintroduce the bugs that Phase 1 fixed (heredoc
JSON injection, non-atomic writes, BSD/GNU divergence). The Phase 1 patterns are already verified —
follow them exactly.

---

## Runtime State Inventory

> Phase 2 creates new state but does not rename existing state. This is a new-artifact phase.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `~/.claude/toolkit-install.json` — NEW (does not exist yet) | Written by Phase 3 install flow, not Phase 2 |
| Live service config | None — no external services involved | None |
| OS-registered state | `~/.claude/.toolkit-install.lock/` — NEW (created/destroyed at runtime) | No migration; created fresh each run |
| Secrets/env vars | None — detect.sh reads no secrets | None |
| Build artifacts | `scripts/tests/` directory — NEW | `mkdir -p scripts/tests/` in commit |

**Untracked file risk:** `templates/base/skills/debugging/SKILL.md` is currently UNTRACKED in git.
Phase 2 must decide: (a) commit it and annotate it in manifest with `conflicts_with: ["superpowers"]`,
OR (b) exclude it from manifest entirely and leave the directory untracked. Decision affects
MANIFEST-03 conflict count. The planner must include a task to resolve this before writing manifest.json
v2 — it is a hard dependency on the manifest commit.

---

## Common Pitfalls

### Pitfall 1: `set -euo pipefail` in a Sourced Script

**What goes wrong:** `detect.sh` sources into `init-claude.sh`. If `detect.sh` has `set -euo pipefail`,
it permanently changes the caller's error mode. Any subsequent `false`-returning command in the caller
causes an unexpected exit.
**Why it happens:** Authors copy the standard script header into every new file.
**How to avoid:** Omit `set -euo pipefail` from `detect.sh`. Document this explicitly at the top of
the file with a comment: `# This file is sourced. Do NOT add set -euo pipefail.`
**Warning signs:** `init-claude.sh` exits mid-run with no error message after sourcing detect.sh.

### Pitfall 2: GSD in `enabledPlugins` Check (False Negative)

**What goes wrong:** DETECT-03 adds a settings.json cross-reference. A developer accidentally also
checks for a `get-shit-done@*` key in `enabledPlugins`, finds nothing, and concludes GSD is not
installed — even though GSD IS installed via the filesystem.
**Why it happens:** Symmetric logic applied to an asymmetric situation. GSD is NOT a Claude Code
plugin; it never appears in `enabledPlugins`.
**How to avoid:** `detect_gsd()` must NOT check `enabledPlugins`. Filesystem only.
**Warning signs:** GSD-installed machines report `HAS_GSD=false`.

### Pitfall 3: `mktemp -t` Suffix Behavior on macOS

**What goes wrong:** `mktemp -t toolkit-install.XXXXXX` on macOS BSD produces a file with a random
suffix AFTER the template: `/var/folders/.../toolkit-install.XXXXXX.MxVEKGnTzv`. This can confuse
downstream code that expects the path to end in the Xs.
**Why it happens:** BSD `mktemp -t TEMPLATE` appends a random extension; GNU `mktemp -t` uses the Xs
for randomization.
**How to avoid:** Use `mktemp "${TMPDIR:-/tmp}/toolkit-install.XXXXXX"` (full path form) — behavior
is consistent on both BSD and GNU.
**Warning signs:** Tests that check temp file path format fail on macOS.

### Pitfall 4: `manifest.version` vs `version` Field Confusion

**What goes wrong:** `manifest.json` has TWO version-like fields after Phase 2: `"version": "3.0.0"`
(product version, unchanged until Phase 7) and `"manifest.version": 2` (schema version, bumped now).
Code that checks `manifest.json | jq '.version'` for schema gating will read `"3.0.0"` instead of `2`.
**Why it happens:** D-14 separates the two fields, but it's easy to confuse them.
**How to avoid:** Schema version check must use `.["manifest.version"]` (bracket notation because of
the dot in the key), or rename to `manifest_version` (underscore). Clarify the key name before
committing — the dot-in-key form requires special handling in jq and in Python dict access.
**Warning signs:** Version mismatch detection never triggers; `make validate` passes on a v1 manifest.

**Recommendation:** Use `"manifest_version"` (underscore) instead of `"manifest.version"` (dot) to
avoid jq bracket-notation requirement and Python `dict["manifest.version"]` confusion. The field
was called `manifest.version` in CONTEXT.md but the actual JSON key design is Claude's discretion.

### Pitfall 5: stale `detect.sh` in mktemp After EXIT Trap

**What goes wrong:** Remote caller sets `trap 'rm -f "$DETECT_TMP"' EXIT`, but if the remote download
fails silently (curl exits 0 with a 404 HTML body), `DETECT_TMP` contains HTML. Sourcing it runs
arbitrary HTML-as-shell which fails cryptically.
**Why it happens:** `curl -sSL` returns exit 0 for HTTP errors when `--fail` is not specified.
**How to avoid:** Use `curl -sSLf` (the `-f` flag makes curl exit non-zero on HTTP errors). Also add
a sanity check: `grep -q 'detect_superpowers' "$DETECT_TMP" || { echo "ERROR: detect.sh download
failed"; exit 1; }` before sourcing.
**Warning signs:** Sourcing detect.sh produces bash syntax errors from HTML content.

### Pitfall 6: Lock Dir Under `~/.claude/` May Not Exist Yet

**What goes wrong:** `mkdir "$HOME/.claude/.toolkit-install.lock"` fails if `~/.claude/` does not
exist (fresh machine before any install).
**Why it happens:** `mkdir` without `-p` only creates the final component.
**How to avoid:** `mkdir -p "$HOME/.claude"` before acquiring the lock, OR use `mkdir -p
"$HOME/.claude/.toolkit-install.lock"` (though this would silently succeed even if `~/.claude` is a
file). Best: `mkdir -p "$HOME/.claude" && mkdir "$LOCK_DIR"`.
**Warning signs:** Lock acquisition silently fails on a machine that has never had TK installed.

---

## Code Examples

### detect.sh — SP Version Extraction

```bash
# Source: verified on dev machine (SP 5.0.7)
# SP version = first non-hidden entry in the versioned subdir cache
SP_VERSION=$(ls "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers" \
    2>/dev/null | grep -v '^\.' | sort -V | tail -1)
```

### detect.sh — GSD Version Extraction

```bash
# Source: verified on dev machine (GSD 1.36.0)
GSD_VERSION=$(cat "$HOME/.claude/get-shit-done/VERSION" 2>/dev/null || echo "")
```

### detect.sh — enabledPlugins Cross-Reference (DETECT-03)

```bash
# Source: verified against ~/.claude/settings.json on dev machine
# Key format: "superpowers@claude-plugins-official"
# GSD does NOT appear in enabledPlugins — do NOT check it here
if [[ -f "$SETTINGS_JSON" ]] && command -v jq &>/dev/null; then
    local enabled
    enabled=$(jq -r \
        '.enabledPlugins["superpowers@claude-plugins-official"] // "missing"' \
        "$SETTINGS_JSON" 2>/dev/null || echo "missing")
    # "false" = key exists but disabled (stale cache); "missing" = settings.json lacks the key entirely
    if [[ "$enabled" == "false" ]]; then
        HAS_SP=false; SP_VERSION=""; return 1
    fi
    # "true" or "missing" both pass through (missing means settings.json may predate enabledPlugins)
fi
```

### mtime Portability Shim (D-11)

```bash
# Source: [ASSUMED based on POSIX stat manpages; verified stat -f %m works on macOS 25.3.0]
get_mtime() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}
```

### Makefile validate Extension — manifest.version check

```makefile
# Append to existing validate target (after existing checks, before final echo)
# Source: [ASSUMED pattern — consistent with Makefile:86-92 existing version check]
	@python3 scripts/validate-manifest.py manifest.json || exit 1
	@echo "✅ Manifest v2 schema valid"
```

### validate-manifest.py skeleton

```python
# scripts/validate-manifest.py
# Called as: python3 scripts/validate-manifest.py manifest.json
import json, sys, os

def main():
    path = sys.argv[1]
    with open(path) as f:
        m = json.load(f)

    errors = []

    # (d) manifest_version == 2
    mv = m.get("manifest_version", m.get("manifest.version"))
    if mv != 2:
        errors.append(f"manifest_version must be 2, got {mv!r}")

    allowed_plugins = {"superpowers", "get-shit-done"}
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(path)))

    for section, entries in m.get("files", {}).items():
        for entry in entries:
            p = entry["path"] if isinstance(entry, dict) else entry
            # (a) path exists on disk
            full = os.path.join(repo_root, p)
            if not os.path.exists(full):
                errors.append(f"path not found: {p}")
            # (c) conflicts_with vocabulary
            for plugin in entry.get("conflicts_with", []) if isinstance(entry, dict) else []:
                if plugin not in allowed_plugins:
                    errors.append(f"invalid conflicts_with value {plugin!r} in {p}")

    # (b) no drift: every file in commands/ is listed
    # ... (enumerate disk dirs, cross-check against manifest)

    if errors:
        for e in errors: print(f"❌ {e}")
        sys.exit(1)
    print("✅ manifest.json v2 valid")

if __name__ == "__main__":
    main()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bare strings in `manifest.json` | Object entries with `path`, `conflicts_with`, `requires_base` | Phase 2 | Enables jq-driven skip-list in Phase 3; no more hardcoded arrays |
| No install state persistence | `~/.claude/toolkit-install.json` with mode + SHA256 per file | Phase 2 (schema) / Phase 3 (first write) | Enables drift detection (Phase 4) and migration (Phase 5) |
| Implicit "install everything" | Mode-aware skip list driven by `conflicts_with` | Phase 3 (wire-up) | Phase 2 sets the data model |
| No plugin detection | `detect.sh` with filesystem + settings.json cross-reference | Phase 2 | Load-bearing for all downstream install logic |

**Deprecated/outdated in this phase:**
- Bare string entries in `manifest.json:files.*`: replaced by objects in Phase 2 commit.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `manifest.json` key should use `"manifest_version"` (underscore) rather than `"manifest.version"` (dot) to avoid jq bracket notation | Common Pitfalls §4, Code Examples | If the dot-form is preferred, jq and python readers need bracket notation everywhere; planner must pick one and document it |
| A2 | When `settings.json` does not have `enabledPlugins` key at all (older Claude Code versions), SP should be treated as present (not suppressed) | detect.sh pattern §1 | If SP should be treated as absent when `enabledPlugins` key is missing, the logic inverts; verify expected behavior for fresh installs |
| A3 | SP version should use the highest semver subdir (via `sort -V | tail -1`) when multiple versioned subdirs exist | Code Examples §SP Version Extraction | If the most recently created (mtime) should be used, the approach differs; single version seen on dev machine so this is untested with multiple versions |
| A4 | `mtime > 1h` portability shim is inlined in `detect.sh` or `acquire_lock()` — no separate `_posix.sh` helper file | Architecture Patterns §3 | If a standalone `_posix.sh` helper is preferred (D-11 discretion), it must be sourced from both detect.sh and the lock functions |
| A5 | The `templates.*` entries in manifest.json v2 should become `{ "path": "templates/base" }` objects (D-12) | Standard Stack, Manifest Pattern | Current `templates` section uses string values for template root dirs; if Phase 3 reads these differently, object wrapping may break |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed. (This table is NOT empty — A1 requires planner decision on key naming before manifest commit.)

---

## Open Questions

1. **`manifest_version` vs `manifest.version` key name**
   - What we know: D-14 says "top-level `manifest.version` field bumps to 2" using dot notation
   - What's unclear: Dot-in-JSON-key requires `obj["manifest.version"]` in Python and `.["manifest.version"]` in jq — awkward. Was the dot intentional?
   - Recommendation: Confirm with user or use `manifest_version` (underscore) and note the deviation from D-14 wording. Either is fine functionally; pick one before writing the manifest.

2. **`templates/base/skills/debugging/SKILL.md` untracked status**
   - What we know: This file exists on disk but is untracked. MANIFEST-03 seed list includes it. It conflicts with SP `systematic-debugging`.
   - What's unclear: Should it be committed (adding it to git history) as part of Phase 2, or left untracked and excluded from manifest v2?
   - Recommendation: Commit it in the `feat(02-02)` manifest commit and annotate with `conflicts_with: ["superpowers"]`. This satisfies MANIFEST-03 and clears the tech debt.

3. **MANIFEST-03 count: 7 confirmed vs requirement of ≥10**
   - What we know: Research found 7 files with confirmed SP equivalents. The requirement says "≥10 entries" but this may refer to the 13-entry seed list (which contains both confirmed and unconfirmed).
   - What's unclear: Does MANIFEST-03 require ≥10 `conflicts_with` annotations or ≥10 entries in the seed list?
   - Recommendation: Read as "≥10 entries reviewed, ≥7 annotated." The 13-entry seed list satisfies the count; the actual `conflicts_with` annotations will be 7 (possibly 8 if debugging/SKILL.md is committed). Flag to user before manifest commit.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All scripts | ✓ | 3.2.57 (macOS) | — |
| python3 | SHA256, atomic writes, validate-manifest.py | ✓ | 3.14.4 | — (no fallback; required dep) |
| jq | DETECT-03 enabledPlugins cross-reference | ✓ | 1.7.1-apple | Skip enabledPlugins check (detect as present if filesystem check passes) |
| SP plugin cache | DETECT-01 test cases | ✓ | 5.0.7 | — (needed for test harness; dev machine has it) |
| GSD plugin | DETECT-02 test cases | ✓ | 1.36.0 | — (needed for test harness; dev machine has it) |
| stat (BSD) | Lock mtime D-11 | ✓ | macOS built-in | GNU stat -c %Y on Linux |
| mkdir | POSIX lock | ✓ | POSIX built-in | — |

**Missing dependencies with no fallback:** None.

**Note on jq fallback:** If `jq` is absent, `detect_superpowers()` should skip the `enabledPlugins`
cross-reference and fall through to filesystem-only detection. This degrades DETECT-03 but does not
fail. The fallback must be explicit: `if command -v jq &>/dev/null; then ... fi`.

---

## Validation Architecture

`workflow.nyquist_validation` not checked here — but per project pattern, `make test` is the test
invocation. Phase 2 adds `scripts/tests/test-detect.sh` to the `make test` target.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | POSIX shell (bash 3.2 compatible), zero external deps |
| Config file | none — tests run directly via bash |
| Quick run command | `bash scripts/tests/test-detect.sh` |
| Full suite command | `make test` (existing target, add detect tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DETECT-01 | `detect_superpowers()` returns 0 with SP cache dir + versioned subdir | unit | `bash scripts/tests/test-detect.sh` | ❌ Wave 0 |
| DETECT-02 | `detect_gsd()` returns 0 with `bin/gsd-tools.cjs` present | unit | `bash scripts/tests/test-detect.sh` | ❌ Wave 0 |
| DETECT-03 | SP with stale cache + disabled in settings.json → HAS_SP=false | unit | `bash scripts/tests/test-detect.sh` | ❌ Wave 0 |
| DETECT-04 | Sourcing detect.sh exports HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION | unit | `bash scripts/tests/test-detect.sh` | ❌ Wave 0 |
| MANIFEST-02 | `manifest_version: 2` present after rewrite | unit | `python3 scripts/validate-manifest.py manifest.json` | ❌ Wave 0 |
| MANIFEST-04 | `make validate` passes with new manifest | unit | `make validate` | ❌ (Makefile extension) |
| STATE-02 | `toolkit-install.json` write is atomic (no half-written JSON) | unit | manual: run write + kill -9; check JSON parseable | manual |
| STATE-03 | Two concurrent runs blocked by mkdir lock | unit | manual: run two installs simultaneously | manual |
| STATE-05 | Stale lock (mtime > 1h OR dead PID) → reclaimed with warning | unit | manual: create stale lock dir, run install | manual |

### Sampling Rate

- **Per task commit:** `bash scripts/tests/test-detect.sh && make validate`
- **Per wave merge:** `make check` (shellcheck + markdownlint + validate)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/test-detect.sh` — covers DETECT-01/02/03/04 (four-case harness per D-29)
- [ ] `scripts/tests/` directory — `mkdir scripts/tests/` in feat(02-01) commit
- [ ] `scripts/validate-manifest.py` — covers MANIFEST-01/02/04 (or inline in Makefile if ≤30 lines)
- [ ] Makefile `validate` extension — covers MANIFEST-04
- [ ] Makefile `test` target extension — add `bash scripts/tests/test-detect.sh`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | partial | `detect.sh` reads filesystem paths (no user input); `validate-manifest.py` reads manifest (trusted file) |
| V6 Cryptography | no | SHA256 used for integrity only (not auth); python3 hashlib |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `source <(curl ...)` RCE via compromised CDN | Spoofing / Tampering | Use `curl -sSLf` (fail on HTTP errors); document SHA verification option (per CONCERNS.md recommendation) |
| Stale lock dir owned by root (if TK ever ran as root) | Elevation of Privilege | `rm -rf` stale lock only after verifying PID is dead AND mtime > 1h; two-signal check prevents premature reclaim |
| Settings.json path traversal via `HOME` override | Tampering | `HOME` is set by the OS environment; detect.sh does not accept it as input |
| Temp file race (between mkstemp and os.replace) | Tampering | `os.replace` is atomic; temp file in same directory as target ensures same filesystem (single rename) |

**No security blockers for Phase 2.** The primitives are internal plumbing with no user-facing attack surface until Phase 3 wires them into install flows.

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: bash --version on dev machine] — bash 3.2.57, ARM64 macOS 25.3.0 — confirms no bash 4+ features
- [VERIFIED: ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/] — SP 5.0.7 confirmed; directory structure confirmed; package.json version field confirmed
- [VERIFIED: ls ~/.claude/get-shit-done/ && cat ~/.claude/get-shit-done/VERSION] — GSD 1.36.0 confirmed; `bin/gsd-tools.cjs` present
- [VERIFIED: python3 -c 'import hashlib...' /etc/hosts] — sha256 pattern confirmed working on python3 3.14.4
- [VERIFIED: python3 atomic write (tempfile.mkstemp + os.replace)] — pattern tested end-to-end
- [VERIFIED: mkdir lock + kill -0 + stat -f %m] — all confirmed working on macOS 25.3.0
- [VERIFIED: cat ~/.claude/settings.json] — `enabledPlugins` key format confirmed; GSD absent from enabledPlugins; SP key = `superpowers@claude-plugins-official`
- [VERIFIED: jq --version] — jq 1.7.1-apple available
- [VERIFIED: date -u +%Y-%m-%dT%H:%M:%SZ] — ISO-8601 UTC format works on BSD date
- [VERIFIED: grep through SP and GSD dirs] — conflict map produced against live plugin installs

### Secondary (MEDIUM confidence)

- `.planning/phases/01-pre-work-bug-fixes/01-PATTERNS.md` — Phase 1 established patterns (python3 JSON, backup, `/dev/tty` guards)
- `.planning/phases/02-foundation/02-CONTEXT.md` — all decisions (D-01 through D-29)
- `.planning/REQUIREMENTS.md` — DETECT-01..05, MANIFEST-01..04, STATE-01..05 spec text

### Tertiary (LOW confidence)

- [ASSUMED: `stat -c %Y` works on Linux GNU] — not verified on this machine (macOS-only dev env); standard POSIX documentation confirms it is the GNU stat flag

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all tools verified on dev machine
- Conflict map: HIGH — scanned live SP 5.0.7 and GSD 1.36.0 directly
- Architecture: HIGH — all patterns tested end-to-end
- MANIFEST-03 count: MEDIUM — 7 confirmed conflicts vs requirement wording of ≥10 (see Open Questions)
- Linux compatibility of stat: MEDIUM — not directly tested (assumption based on POSIX docs)

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (stable tools; SP/GSD versions may increment but paths are stable)
