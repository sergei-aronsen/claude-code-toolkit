# Stack Research

**Domain:** POSIX Bash CLI installer — filesystem-based plugin detection and conditional install
**Researched:** 2026-04-17
**Confidence:** HIGH (codebase read directly; conclusions drawn from existing code patterns, not training data)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 3.2+ (BSD compat) | All install logic | Already the project runtime. Dropping BSD compat would break macOS users without any gain — bash 4+ associative arrays are NOT worth the compat break for this use case. |
| `jq` | any stable (1.6+) | JSON read/write for manifest.json and toolkit-install.json | Already a declared runtime dependency (install-statusline.sh, rate-limit-probe.sh). Elevating it to a hard dep for ALL scripts is a natural promotion, not a new dependency. |
| `python3` | 3.8+ | JSON mutation of `~/.claude/settings.json` only | Already used in setup-security.sh for this exact task. Keep it scoped to settings.json mutation because python3 handles edge cases (JSON5-adjacent trailing commas, Unicode, nested merge) that jq cannot do atomically in a one-liner. |

### Supporting Libraries / Tools

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `mktemp` | POSIX | Atomic write via temp-file + `mv` | Every JSON write. Write to `$(mktemp)` then `mv` to destination — the only safe atomic pattern on POSIX without a lock daemon. |
| `flock` | util-linux (Linux only) | Advisory file lock for concurrent installer runs | NOT recommended — unavailable on macOS BSD. Use a `.lock` file + PID check instead (see Patterns section). |
| `cp -p` | POSIX | Timestamped backup before any mutation | Mandatory before every write to user files (`settings.json`, `toolkit-install.json`). Pattern already exists in `install-statusline.sh:104`; must be ported to all mutating scripts. |

### Development Tools (unchanged from existing)

| Tool | Purpose | Notes |
|------|---------|-------|
| `shellcheck` | Static analysis for shell scripts | Already in CI. All new scripts must pass at `warning` severity. |
| `markdownlint-cli` | Markdown lint | Unchanged. Not relevant to new shell code. |
| `make` | Task runner | Add `make validate-consistency` target to diff manifest vs script lists. |

---

## Answers to Specific Research Questions

### Q1: `jq` as hard dependency vs. sed/awk hacks?

**Recommendation: Make `jq` a hard dependency. Eliminate sed/awk for JSON.**

Rationale:

- `jq` is already required by `install-statusline.sh` and the `rate-limit-probe.sh`/`statusline.sh` globals. The project already lists it as a "Critical (runtime tool)" in `.planning/codebase/STACK.md:53`.
- The primary pain point that motivated this question is `update-claude.sh:147` — a hand-maintained 29-element list that drifts from `manifest.json`. The fix is `jq -r '.files.commands[]' manifest.json`, which is the exact use case `jq` is designed for.
- sed/awk on JSON is brittle: it cannot handle multiline values, nested objects, or Unicode safely. The existing `grep -o '"version": "[^"]*"'` in `update-claude.sh:74` is already an example of a fragile JSON parse that will silently return wrong data if the key appears twice or the spacing changes.
- Fail-fast guard: add `command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required. Install: brew install jq / apt install jq"; exit 1; }` at the top of every script that uses it. This is better than silent wrong behavior from sed.

**Confidence: HIGH** — based on existing declared dependency and direct code evidence of sed fragility.

### Q2: Single `manifest.json` vs. per-mode manifests?

**Recommendation: Keep one `manifest.json`. Extend it with per-file metadata fields.**

Add two optional fields per file entry:

```json
"conflicts_with": ["superpowers", "get-shit-done"],
"requires_base": null
```

Where:

- `conflicts_with`: array of base plugin IDs whose presence means this file should be skipped
- `requires_base`: array of base plugin IDs required for this file to be useful (install only when present)
- Both default to `null`/`[]` = always install

Rationale:

- The codebase already has the "manifest as source of truth" principle stated in `.planning/codebase/CONCERNS.md:189`. Splitting into per-mode manifests creates a NEW version of the four-list-drift problem. The install scripts would need to know which manifest(s) to fetch.
- A single manifest with richer per-file metadata keeps the logic in data (declarative) rather than in shell code (imperative). Shell scripts read `jq -r --arg mode "$INSTALL_MODE" '[.files.commands[] | select(.conflicts_with | map(. == $mode) | any | not) | .path] | .[]' manifest.json`.
- Per-mode manifests would also require a manifest-manifest (a manifest of which manifests apply), which is exactly the recursive complexity YAGNI warns against.

**Confidence: HIGH** — directly follows from existing codebase architecture decision.

Schema for extended manifest entry:

```json
"commands": [
  {
    "path": "commands/debug.md",
    "conflicts_with": ["superpowers"],
    "requires_base": null
  },
  {
    "path": "commands/council.md",
    "conflicts_with": [],
    "requires_base": null
  }
]
```

Migration: entries that are currently bare strings (`"commands/plan.md"`) remain valid if scripts treat strings as `{ "path": "...", "conflicts_with": [], "requires_base": null }`. Use `jq` to normalize: `jq -r 'if type == "string" then . else .path end'`.

### Q3: Similar installers for this pattern?

**Finding: No standard library exists for this. Both Superpowers and GSD use the same POSIX-bash + curl pattern.**

Verified: Superpowers install path is `~/.claude/plugins/cache/claude-plugins-official/superpowers/` and GSD is `~/.claude/get-shit-done/`. Both are shell-script-only. Neither has a plugin registry or detection API.

The standard pattern in similar CLI installers (Homebrew formula installers, mise, asdf) for "detect installed component and skip if present" is:

```bash
if [ -d "$target_path" ]; then
  echo "Already installed: $name"
else
  install "$name"
fi
```

No external library is needed. This is a solved problem in 3 lines of shell. The complexity in this project comes from the JSON state file and skip-list logic, both of which `jq` handles cleanly.

**Confidence: MEDIUM** — SP and GSD install paths verified from `.planning/PROJECT.md:34-35`; their internal scripts not read directly.

### Q4: `~/.claude/toolkit-install.json` — schema, atomic write, lock file?

**Recommended schema:**

```json
{
  "version": "1",
  "installed_at": "2026-04-17T12:00:00Z",
  "updated_at": "2026-04-17T12:00:00Z",
  "toolkit_version": "4.0.0",
  "mode": "complement-full",
  "detected_bases": {
    "superpowers": true,
    "get-shit-done": true
  },
  "installed_files": [
    "commands/council.md",
    "commands/helpme.md"
  ],
  "skipped_files": [
    "commands/debug.md",
    "commands/tdd.md"
  ],
  "skipped_reason": {
    "commands/debug.md": "conflicts_with:superpowers",
    "commands/tdd.md": "conflicts_with:superpowers"
  }
}
```

**Atomic write pattern (POSIX-safe):**

```bash
INSTALL_JSON="$HOME/.claude/toolkit-install.json"
TMP=$(mktemp "${INSTALL_JSON}.tmp.XXXXXX")
# write to TMP...
mv -f "$TMP" "$INSTALL_JSON"
```

`mv` is atomic on the same filesystem (POSIX rename(2)). Never write directly to the destination file.

**Lock file pattern (BSD-compatible, no `flock`):**

```bash
LOCK_FILE="$HOME/.claude/toolkit-install.lock"
LOCK_PID_FILE="$HOME/.claude/toolkit-install.lock.pid"

acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
      echo "ERROR: Another install is running (PID $OLD_PID). Exiting."
      exit 1
    fi
    # Stale lock — previous run crashed
    rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
  fi
  touch "$LOCK_FILE"
  echo $$ > "$LOCK_PID_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
}
trap release_lock EXIT
```

`kill -0 $PID` is POSIX and works on macOS BSD. `flock` is Linux-only — do not use it.

**Backup on update:**

```bash
if [ -f "$INSTALL_JSON" ]; then
  cp -p "$INSTALL_JSON" "${INSTALL_JSON}.bak.$(date +%Y%m%d-%H%M%S)"
fi
```

**Confidence: HIGH** — standard POSIX patterns, no framework dependency.

### Q5: BSD-compatible shell vs. bash 4+ associative arrays?

**Recommendation: Stay on bash 3.2+ / POSIX. Do NOT require bash 4+.**

Rationale:

- macOS ships bash 3.2.57 as the default and will not change this due to GPL licensing. Users who upgrade to bash 5 via homebrew are a subset. The install scripts run under `curl | bash` where the system bash is invoked — that is 3.2 on macOS.
- Associative arrays are the only bash 4+ feature that would materially help (for skip-lists like `declare -A skip_map`). The same result is achievable with a pipe through `jq` or a `grep` over a flat string — neither requires bash 4.
- The skip-list problem is: given an install mode, which files to skip? With `jq` and extended manifest metadata (see Q2 answer), the skip-list is computed as: `jq -r --arg mode "$INSTALL_MODE" '...' manifest.json`. No associative array needed.
- Portable alternative if jq is unavailable mid-script: encode skip-list as a space-separated string `SKIP=" commands/debug.md commands/tdd.md "` and test with `case " $SKIP " in *" $file "*)`.

**Confidence: HIGH** — verified against existing constraint in `.planning/PROJECT.md:79` and `.planning/codebase/STACK.md:9`.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `jq` for all JSON | `python3 -c json` for all JSON | If jq is unavailable. python3 already required for settings.json mutation, so it is always present. Use as fallback only: `jq ... 2>/dev/null \|\| python3 -c "..."`. |
| Single extended `manifest.json` | Per-mode manifests (`manifest-standalone.json`, `manifest-complement.json`) | Never — creates the same four-list-drift problem at the manifest level. |
| `mv` atomic write | Direct write to destination | Never — partial writes are visible to concurrent readers and crash-interrupted writes corrupt the file. |
| `kill -0` PID lock | `flock` | Only on Linux-only tools where BSD compat is not needed. Never for this project. |
| bash 3.2+ POSIX | bash 4+ associative arrays | Only if you drop macOS as a target platform. Not justified here. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `jq` for `settings.json` mutation | `settings.json` may contain JSON5-adjacent syntax (trailing commas) or be malformed; `jq` will hard-fail and the user loses their settings | `python3` with `json.load` + `json.dump` + backup — already established in setup-security.sh |
| `sed`/`awk` for JSON parsing | Cannot handle nested structures, multiline values, Unicode; produces silent wrong output when format deviates; the existing `grep -o '"version"...'` in update-claude.sh:74 is an example of this fragility | `jq` for read, `python3` for write |
| `flock` for locking | Linux-only, not available on macOS BSD | PID-file lock with `kill -0` check |
| `head -n -1` for text processing | GNU-only; silent empty output on macOS BSD `head` — the bug documented in update-claude.sh:186 | Use `awk 'NR>1{print prev} {prev=$0}'` for "all but last line" or restructure to not need it |
| `bash 4+` associative arrays for skip-lists | Breaks macOS default bash (3.2) | `jq`-computed skip-list from manifest metadata |
| Separate `manifest-*.json` per mode | Recreates the four-list-drift problem at the manifest level | Single manifest with per-file `conflicts_with` metadata |
| Parsing manifest with `grep -o` | Fragile; breaks when key appears twice or whitespace changes | `jq -r '.version'` |
| `npm` or `node` for install-state logic | No Node runtime at install time; users may not have Node on PATH | Pure bash + jq |

---

## Stack Patterns by Mode

**If `standalone` mode (no SP, no GSD detected):**

- Install all files from manifest regardless of `conflicts_with`
- Write `toolkit-install.json` with `"mode": "standalone"`, `"detected_bases": {"superpowers": false, "get-shit-done": false}`

**If `complement-full` mode (both SP and GSD detected):**

- Read `conflicts_with` from each manifest entry; skip files that conflict with either base
- Write install state with full skip-list and skip reasons

**If partial complement mode (`complement-sp` or `complement-gsd`):**

- Same logic; filter only against the detected base's conflicts

**Detection logic (filesystem only, 2 checks, no CLI dependency):**

```bash
SP_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
GSD_DIR="$HOME/.claude/get-shit-done"

HAVE_SP=false
HAVE_GSD=false
[ -d "$SP_DIR" ] && HAVE_SP=true
[ -d "$GSD_DIR" ] && HAVE_GSD=true
```

---

## Sources

- `.planning/PROJECT.md` — filesystem detection paths, out-of-scope decisions, constraints (HIGH confidence, primary source)
- `.planning/codebase/STACK.md` — existing declared dependencies including `jq` as Critical runtime tool (HIGH confidence)
- `.planning/codebase/CONCERNS.md` — sed fragility evidence (`update-claude.sh:74`), GNU `head -n -1` bug (HIGH confidence, direct code evidence)
- `scripts/update-claude.sh:147` — hand-maintained command list vs manifest drift (HIGH confidence, direct code read)
- `scripts/setup-security.sh` — established `python3` + inline heredoc JSON mutation pattern (HIGH confidence, direct code read)
- `scripts/init-claude.sh` — `< /dev/tty` guard pattern for interactive reads under curl|bash (HIGH confidence)
- POSIX specification — `mv` atomicity, `kill -0`, `mktemp` (HIGH confidence, standard)

---

*Stack research for: claude-code-toolkit complement-mode refactor (v4.0)*
*Researched: 2026-04-17*
