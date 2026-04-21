# Phase 2: Foundation - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 6 (5 new + 1 schema rewrite + 1 Makefile extension)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/detect.sh` (new) | utility | file-I/O | `scripts/init-claude.sh:49-65` (`detect_framework`) | role-match |
| `scripts/tests/test-detect.sh` (new) | test | batch | `Makefile:42-63` (test target synthetic envs) | role-match |
| `manifest.json` (schema rewrite) | config | transform | `manifest.json` itself (v1 → v2 object migration) | exact |
| `Makefile` (extend `validate`) | build | batch | `Makefile:65-114` (existing `validate` target) | exact |
| `scripts/validate-manifest.py` (new) | utility | batch | `scripts/setup-security.sh:206-248` (python3 heredoc JSON block) | role-match |
| `scripts/init-claude.sh` + `scripts/update-claude.sh` (stubs only) | installer | request-response | themselves | exact |

---

## Pattern Assignments

### `scripts/detect.sh` (utility, file-I/O)

**Analog:** `scripts/init-claude.sh` lines 1-16 (header + colors) and lines 49-65 (`detect_framework`)

**Header pattern — copy verbatim, omit `set -euo pipefail`** (`scripts/init-claude.sh:1-16`):

```bash
#!/bin/bash

# Claude Code Toolkit — Plugin Detection Library
# Source this file. Do NOT execute it directly.
# Exports: HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION
#
# Remote callers: DETECT_TMP=$(mktemp) && curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" && source "$DETECT_TMP"
# Local callers:  source "$(dirname "$0")/detect.sh"
#
# IMPORTANT: No set -euo pipefail — sourced scripts must not alter caller's error mode.

# Colors (match every other script in this repo)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

**Detection function structure** — copy pattern from `scripts/init-claude.sh:49-65`:

```bash
# Existing analog: detect_framework uses [[ -f "file" ]] probes, returns string via echo.
# detect_superpowers / detect_gsd follow the same structure but:
#   (a) probe directories not files
#   (b) export variables instead of echoing
#   (c) return 0/1 explicitly

detect_framework() {
    if [[ -f "artisan" ]]; then
        echo "laravel"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    else
        echo "base"
    fi
}
```

**Adapt to** (D-05 + DETECT-01/02/03/04):

```bash
SP_PLUGIN_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"
SETTINGS_JSON="$HOME/.claude/settings.json"

detect_superpowers() {
    # DETECT-01: versioned subdir must exist
    if [[ ! -d "$SP_PLUGIN_DIR" ]]; then
        HAS_SP=false; SP_VERSION=""; export HAS_SP SP_VERSION; return 1
    fi
    local ver
    ver=$(ls "$SP_PLUGIN_DIR" 2>/dev/null | grep -v '^\.' | sort -V | tail -1)
    if [[ -z "$ver" ]]; then
        HAS_SP=false; SP_VERSION=""; export HAS_SP SP_VERSION; return 1
    fi
    # DETECT-03: cross-reference enabledPlugins (suppress stale-cache false positives)
    # GSD does NOT appear in enabledPlugins — do NOT add an equivalent check in detect_gsd
    if [[ -f "$SETTINGS_JSON" ]] && command -v jq &>/dev/null; then
        local enabled
        enabled=$(jq -r '.enabledPlugins["superpowers@claude-plugins-official"] // "missing"' \
            "$SETTINGS_JSON" 2>/dev/null || echo "missing")
        if [[ "$enabled" == "false" ]]; then
            HAS_SP=false; SP_VERSION=""; export HAS_SP SP_VERSION; return 1
        fi
    fi
    HAS_SP=true; SP_VERSION="$ver"
    export HAS_SP SP_VERSION
    return 0
}

detect_gsd() {
    # DETECT-02: filesystem-only — GSD has no enabledPlugins entry
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

**mtime portability shim** — inline in `acquire_lock` (D-11; no separate file per D-11 discretion):

```bash
# BSD (macOS) vs GNU (Linux) stat portability shim
get_mtime() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}
```

**jq usage analog** (`scripts/install-statusline.sh:50,64` and `scripts/install-statusline.sh:98`):

```bash
# Existing: jq reads Keychain JSON for token fields
TOKEN=$(security find-generic-password ... | jq -r '.claudeAiOauth.accessToken // empty' ...)
# Existing: jq merges settings.json statusLine key
UPDATED=$(jq '. + {"statusLine": {...}}' "$SETTINGS_FILE" 2>/dev/null)
```

DETECT-03 extends this to reading `enabledPlugins` — same tool, same `-r` flag, same `// "missing"` fallback idiom.

**stdout-silence constraint** (D-05): `detect.sh` body emits ZERO stdout. Colors are defined but used
only by callers who print detection results after sourcing. Do not add `echo` calls inside `detect_superpowers` or `detect_gsd`.

---

### `scripts/tests/test-detect.sh` (test, batch)

**Analog:** `Makefile:42-63` (test target — synthetic `/tmp` dirs, file presence assertions)

```makefile
# Existing test pattern (Makefile:46-61):
test:
    @rm -rf /tmp/test-claude-laravel
    @mkdir -p /tmp/test-claude-laravel
    @cd /tmp/test-claude-laravel && touch artisan && bash $(PWD)/scripts/init-local.sh >/dev/null
    @test -f /tmp/test-claude-laravel/.claude/prompts/SECURITY_AUDIT.md && echo "✅ Laravel init works"
```

**Adapt to** (D-29 — POSIX shell harness, four cases, `HOME` override):

```bash
#!/bin/bash
# scripts/tests/test-detect.sh
# Usage: bash scripts/tests/test-detect.sh
# Exit: 0 = all pass, 1 = any fail
set -euo pipefail

PASS=0; FAIL=0
DETECT_SH="$(cd "$(dirname "$0")/.." && pwd)/detect.sh"
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-detect.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

# Pattern: each case overrides HOME, creates synthetic .claude/ layout, sources detect.sh
run_case() {
    local label="$1" expect_sp="$3" expect_gsd="$4"
    HOME="$SCRATCH"
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"
    eval "$2"          # setup_cmd creates dirs under $SCRATCH/.claude/
    HAS_SP="" HAS_GSD=""
    # shellcheck source=/dev/null
    source "$DETECT_SH"
    local ok=true
    [[ "$HAS_SP" == "$expect_sp" ]] || ok=false
    [[ "$HAS_GSD" == "$expect_gsd" ]] || ok=false
    if $ok; then
        echo "✅ PASS: $label (HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD)"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $label  expected HAS_SP=$expect_sp HAS_GSD=$expect_gsd  got HAS_SP=$HAS_SP HAS_GSD=$HAS_GSD"
        FAIL=$((FAIL + 1))
    fi
}
```

Cases to implement (DETECT-01/02/03):

- Case 1 "neither" — no SP dir, no GSD dir → `HAS_SP=false HAS_GSD=false`
- Case 2 "SP only" — create `$SCRATCH/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`, write minimal `settings.json` with `enabledPlugins["superpowers@claude-plugins-official"]: true` → `HAS_SP=true HAS_GSD=false`
- Case 3 "GSD only" — create `$SCRATCH/.claude/get-shit-done/bin/gsd-tools.cjs`, write `VERSION` → `HAS_SP=false HAS_GSD=true`
- Case 4 "both" — combine Cases 2+3 → `HAS_SP=true HAS_GSD=true`

Additional case (DETECT-03): SP dirs present but `settings.json` has `enabledPlugins: false` → `HAS_SP=false` (stale-cache suppression).

**`mktemp` cross-platform form** (`scripts/tests/test-detect.sh`): use `mktemp "${TMPDIR:-/tmp}/test-detect.XXXXXX"` — never `mktemp -t PREFIX.XXXXXX` (macOS appends random suffix after Xs; RESEARCH.md Pitfall 3).

---

### `manifest.json` (config, schema rewrite)

**Analog:** `manifest.json` itself (lines 1-115 — full current v1 schema)

**Current v1 entry form** (`manifest.json:7-11`):

```json
"agents": [
  "agents/code-reviewer.md",
  "agents/planner.md",
  "agents/security-auditor.md",
  "agents/test-writer.md"
],
```

**Target v2 entry form** (D-12 + MANIFEST-01):

```json
"agents": [
  { "path": "templates/base/agents/code-reviewer.md", "conflicts_with": ["superpowers"] },
  { "path": "templates/base/agents/planner.md" },
  { "path": "templates/base/agents/security-auditor.md" },
  { "path": "templates/base/agents/test-writer.md" }
],
```

**Version field migration** (D-14 + MANIFEST-02) — top of file:

```json
{
  "manifest_version": 2,
  "version": "3.0.0",
  "updated": "2026-04-17",
```

Note: Use `manifest_version` (underscore) not `manifest.version` (dot) to avoid jq bracket-notation
requirement and Python `dict["manifest.version"]` confusion. This is the RESEARCH.md Pitfall 4
recommendation and supersedes D-14 literal wording.

**Conflict annotations for all 7 confirmed SP conflicts** (RESEARCH.md Conflict Map):

```json
{ "path": "templates/base/agents/code-reviewer.md", "conflicts_with": ["superpowers"] },
{ "path": "commands/debug.md", "conflicts_with": ["superpowers"] },
{ "path": "commands/tdd.md", "conflicts_with": ["superpowers"] },
{ "path": "commands/worktree.md", "conflicts_with": ["superpowers"] },
{ "path": "commands/verify.md", "conflicts_with": ["superpowers"] },
{ "path": "commands/plan.md", "conflicts_with": ["superpowers"] },
{ "path": "templates/base/skills/debugging/SKILL.md", "conflicts_with": ["superpowers"] },
```

**templates section migration** (D-12):

```json
"templates": {
  "base":    { "path": "templates/base" },
  "laravel": { "path": "templates/laravel" },
  "nextjs":  { "path": "templates/nextjs" },
  "nodejs":  { "path": "templates/nodejs" },
  "python":  { "path": "templates/python" },
  "go":      { "path": "templates/go" },
  "rails":   { "path": "templates/rails" }
}
```

**`claude_md_sections` stays untouched** (D-13) — no migration needed.

---

### `Makefile` (build, batch — extend `validate`)

**Analog:** `Makefile:65-114` — existing `validate` target

**Current validate hook** (`Makefile:86-92`):

```makefile
@MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/'); \
    CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
    if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
        echo "❌ Version mismatch: manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; \
        exit 1; \
    fi; \
    echo "✅ Version aligned: $$MANIFEST_VER"
```

**Extend pattern — append after the existing checks, before `@echo "✅ All templates valid"`** (`Makefile:114`):

```makefile
@python3 scripts/validate-manifest.py manifest.json
```

**Extend `test` target** (D-29 — `Makefile:42`):

```makefile
test: ...
    @echo "Test 4: detect.sh four-case harness"
    @bash scripts/tests/test-detect.sh
    @echo ""
    @echo "All tests passed!"
```

Add `scripts/tests/test-detect.sh` to the `.PHONY` dependencies if needed. Keep the three existing
test cases intact; add as Test 4.

**`.PHONY` line** (`Makefile:1`): no change needed — `test` is already declared `.PHONY`.

---

### `scripts/validate-manifest.py` (utility, batch)

**Analog:** `scripts/setup-security.sh:206-248` — python3 heredoc block reading + writing JSON via
`tempfile.mkstemp` + `os.replace`

**Exact atomic-write pattern to mirror** (`scripts/setup-security.sh:238-248`):

```python
import tempfile, os
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(settings_path))
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    os.unlink(tmp_path)
    raise
```

**validate-manifest.py does not write** — it only reads. But uses the same `json.load` idiom from
`scripts/setup-security.sh:209-212`:

```python
import json, sys, os

settings_path = sys.argv[1]
with open(settings_path, 'r') as f:
    config = json.load(f)
```

**Validator structure** (D-24 — four checks, D-25 — split to file if > 30 lines):

```python
#!/usr/bin/env python3
# scripts/validate-manifest.py
# Called as: python3 scripts/validate-manifest.py manifest.json
import json, sys, os

def main():
    path = sys.argv[1]
    with open(path) as f:
        m = json.load(f)

    errors = []

    # (d) manifest_version == 2
    mv = m.get("manifest_version")
    if mv != 2:
        errors.append(f"manifest_version must be 2, got {mv!r}")

    allowed_plugins = {"superpowers", "get-shit-done"}
    # repo root = two levels up from manifest.json (manifest.json is at repo root)
    repo_root = os.path.dirname(os.path.abspath(path))

    files = m.get("files", {})
    listed_paths = set()

    for section, entries in files.items():
        for entry in entries:
            if not isinstance(entry, dict):
                errors.append(f"files.{section} entry is not an object: {entry!r}")
                continue
            p = entry.get("path", "")
            listed_paths.add(p)
            # (a) path exists on disk
            full = os.path.join(repo_root, p)
            if not os.path.exists(full):
                errors.append(f"path not found on disk: {p}")
            # (c) conflicts_with vocabulary enforcement
            for plugin in entry.get("conflicts_with", []):
                if plugin not in allowed_plugins:
                    errors.append(f"invalid conflicts_with value {plugin!r} in {p}")

    # (b) drift check: every file under commands/ must be in manifest
    commands_dir = os.path.join(repo_root, "commands")
    if os.path.isdir(commands_dir):
        for fname in os.listdir(commands_dir):
            if fname.endswith(".md"):
                expected = f"commands/{fname}"
                if expected not in listed_paths:
                    errors.append(f"commands/{fname} on disk but not in manifest files.commands")

    if errors:
        for e in errors:
            print(f"❌ {e}")
        sys.exit(1)

    print("✅ manifest.json v2 valid")

if __name__ == "__main__":
    main()
```

This is ~45 lines → separate file justified (D-25 rule: split if > 30 lines).

---

### `scripts/init-claude.sh` + `scripts/update-claude.sh` — detect.sh stub call-site

**Analog:** themselves (D-05, DETECT-05 — stubs only, Phase 2 adds source call but no branching)

**Source call-site stub pattern** (D-04 + D-28):

```bash
# In init-claude.sh and update-claude.sh, after the color constants and REPO_URL config block,
# add the following stub BEFORE any logic that would consume HAS_SP/HAS_GSD.
# Phase 2: stub only — variables are exported but not yet consumed until Phase 3.

# Detect installed base plugins
# shellcheck source=scripts/detect.sh
source "$(dirname "$0")/detect.sh"
# HAS_SP, HAS_GSD, SP_VERSION, GSD_VERSION are now exported
# Phase 3 will branch on these variables; Phase 2 does not.
```

For remote `init-claude.sh` (D-03 + RESEARCH.md Pitfall 5):

```bash
# Remote callers bootstrap detect.sh via mktemp:
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
trap 'rm -f "$DETECT_TMP"' EXIT
curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP"
grep -q 'detect_superpowers' "$DETECT_TMP" || { echo -e "${RED}ERROR:${NC} detect.sh download failed"; exit 1; }
# shellcheck source=/dev/null
source "$DETECT_TMP"
```

---

## Shared Patterns

### Script Header (no `set -euo pipefail` for sourced scripts)

**Source:** `scripts/init-claude.sh:1-15`, `scripts/setup-security.sh:1-17`, `scripts/install-statusline.sh:1-14`

**Apply to:** All new executable scripts (`scripts/tests/test-detect.sh`, `scripts/validate-manifest.py` excluded — Python).

```bash
#!/bin/bash

# <Script Name> — <one-line purpose>
# Usage: <invocation pattern>

set -euo pipefail    # OMIT THIS LINE in detect.sh (sourced script — would alter caller error mode)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

**Apply to `detect.sh` with the header comment warning instead of `set -euo pipefail`.**

---

### Atomic JSON Write (python3 tempfile.mkstemp + os.replace)

**Source:** `scripts/setup-security.sh:202-254` (lines 238-248 are the exact atomic write block)

**Apply to:** State file writes in Phase 3's `toolkit-install.json` write function. Phase 2 only defines the protocol; the writer is implemented in Phase 3. Pattern is documented here for planner reference.

```python
# Atomic write — never leaves half-written JSON (consistent with setup-security.sh:238-248)
import tempfile, os, json

def atomic_write_json(path, data):
    out_dir = os.path.dirname(os.path.abspath(path))
    tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir)
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
        os.replace(tmp_path, path)
    except Exception:
        os.unlink(tmp_path)
        raise
```

---

### mkdir Lock + PID + Stale Recovery

**Source:** No existing analog in the codebase — this is a new pattern for Phase 2. Reference: RESEARCH.md Pattern 3.

**Apply to:** The `acquire_lock` / `release_lock` functions that Phase 3 will call. Phase 2 defines the schema and behavior contract; Phase 3 wires it into install flow.

```bash
LOCK_DIR="$HOME/.claude/.toolkit-install.lock"

# Always register trap before acquiring lock (D-10)
trap 'rm -rf "$LOCK_DIR"' EXIT

acquire_lock() {
    mkdir -p "$HOME/.claude"          # Pitfall 6: ~/.claude/ may not exist on fresh machine
    local retries=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        local old_pid=""
        old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")

        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID $old_pid (process no longer running)"
            rm -rf "$LOCK_DIR"; continue
        fi

        local lock_mtime now age
        lock_mtime=$(get_mtime "$LOCK_DIR")   # portability shim defined above
        now=$(date +%s)
        age=$((now - lock_mtime))
        if [[ $age -gt 3600 ]]; then
            echo -e "${YELLOW}⚠${NC} Reclaimed stale lock from PID ${old_pid:-unknown} (lock age: ${age}s)"
            rm -rf "$LOCK_DIR"; continue
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
```

---

### Backup Before Mutation

**Source:** `scripts/install-statusline.sh:104` and `scripts/setup-security.sh:203-204`

```bash
# install-statusline.sh:104 — used when settings.json cannot be parsed by jq
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

# setup-security.sh:203-204 — pre-mutation backup with unix timestamp (BUG-05 fix)
SETTINGS_BACKUP="${SETTINGS_JSON}.bak.$(date +%s)"
cp "$SETTINGS_JSON" "$SETTINGS_BACKUP"
```

**Apply to:** Phase 3 write of `toolkit-install.json` over an existing file: `cp "$STATE_FILE" "${STATE_FILE}.bak.$(date +%s)"` before overwrite.

---

### ISO-8601 UTC Timestamp

**Source:** Established pattern from CONTEXT.md D-22, consistent with Phase 1 D-05.

```bash
# BSD and GNU date both support this form (verified on macOS BSD date):
date -u +%Y-%m-%dT%H:%M:%SZ
```

**Apply to:** `installed_at` fields in `toolkit-install.json` (written in Phase 3).

---

### SHA256 via python3 hashlib (D-06)

**Source:** Pattern established in Phase 1 D-05 / BUG-03. No existing call-site in Phase 2 files, but defined here for Phase 3 planner reference.

```bash
# D-06: single consistent SHA256 provider across the toolkit
sha256_file() {
    python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}
```

**Apply to:** `installed_files[*].sha256` fields written in Phase 3.

---

## No Analog Found

All Phase 2 files have usable analogs. The following patterns are new to the repo but fully specified
in RESEARCH.md — the planner should use RESEARCH.md Pattern 3 (mkdir lock) and Pattern 2 (atomic
state file) as primary references since no existing codebase analog exercises them end-to-end.

| File | Role | Data Flow | Reason |
|---|---|---|---|
| State file write protocol (`toolkit-install.json`) | utility | file-I/O | Schema defined Phase 2, WRITTEN in Phase 3. Nearest analog is `setup-security.sh:238-248` (same atomic write idiom) but no existing `toolkit-install.json` call-site exists yet. |
| mkdir lock (`acquire_lock`) | utility | file-I/O | New pattern in this repo. Pattern 3 in RESEARCH.md is the authoritative reference; no existing script uses `mkdir`-based locks. |

---

## Metadata

**Analog search scope:** `scripts/`, `Makefile`, `manifest.json`
**Files scanned:** `scripts/init-claude.sh`, `scripts/update-claude.sh`, `scripts/setup-security.sh`,
`scripts/install-statusline.sh`, `manifest.json`, `Makefile`
**Key anti-patterns to guard against (RESEARCH.md):**
- No `set -euo pipefail` in `detect.sh` (Pitfall 1)
- No `enabledPlugins` check in `detect_gsd` (Pitfall 2)
- Use `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` not `mktemp -t` (Pitfall 3)
- Use `manifest_version` key (underscore), not `manifest.version` (dot) (Pitfall 4)
- Use `curl -sSLf` (with `-f`) for remote detect.sh download (Pitfall 5)
- `mkdir -p "$HOME/.claude"` before acquiring lock (Pitfall 6)
**Pattern extraction date:** 2026-04-17
