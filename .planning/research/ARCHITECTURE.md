# Architecture Research

**Domain:** CLI toolkit installer / complement-mode install system
**Researched:** 2026-04-17
**Confidence:** HIGH (derived from direct codebase analysis, no external sources needed)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DETECTION LAYER (new)                           │
│  detect_plugin() checks filesystem paths, returns SP/GSD presence  │
│  Runs once per session; result drives all subsequent decisions      │
└─────────────────────┬───────────────────────────────────────────────┘
                      │  detection result: {mode, sp_present, gsd_present}
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   MANIFEST + SKIP-LIST LAYER                        │
│  manifest.json declares per-file metadata:                          │
│    conflicts_with: ["superpowers" | "get-shit-done"]                │
│    requires_base: [null]                                            │
│  Skip-list computed at runtime: filter FILES[] by detected mode     │
└─────────────────────┬───────────────────────────────────────────────┘
                      │  filtered file list
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    INSTALL / UPDATE LAYER                           │
│  init-claude.sh  — fresh install, reads filtered FILES[]           │
│  update-claude.sh — refresh install, re-evaluates skip-list        │
│  setup-security.sh — safe JSON merge (backup + python3 merge)      │
└─────────────────────┬───────────────────────────────────────────────┘
                      │  files written to ~/.claude/ or ./.claude/
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     STATE LAYER (new)                               │
│  ~/.claude/toolkit-install.json                                     │
│    { mode, sp_present, gsd_present, installed_files[],             │
│      skipped_files[], version, timestamp }                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Location |
|-----------|----------------|----------|
| Detection | Filesystem probe for SP/GSD; returns mode enum | `scripts/detect.sh` (sourced) |
| Manifest + metadata | Declares per-file `conflicts_with` / `requires_base`; canonical file list | `manifest.json` |
| Skip-list resolver | Filters FILES[] array using detected mode + manifest metadata | inline in `init-claude.sh` and `update-claude.sh`, sourcing `detect.sh` |
| Fresh installer | Downloads/copies toolkit files for new project, applies skip-list | `scripts/init-claude.sh` |
| Smart updater | Re-downloads toolkit files, re-runs detection, re-applies skip-list, smart-merges CLAUDE.md | `scripts/update-claude.sh` |
| Security setup | Safely merges hook + plugins into `~/.claude/settings.json` (backup + python3 JSON merge) | `scripts/setup-security.sh` |
| State persistence | Reads/writes `~/.claude/toolkit-install.json` | helper functions in `init-claude.sh` and `update-claude.sh` |
| Migration | Detects post-fact SP/GSD for existing v3.x users, offers to remove duplicates with backup | `scripts/migrate-to-complement.sh` |

## Recommended Project Structure

```text
scripts/
├── detect.sh                  # Sourced helper: detect_sp(), detect_gsd(), resolve_mode()
├── init-claude.sh             # Sources detect.sh; applies skip-list before install
├── update-claude.sh           # Sources detect.sh; re-evaluates skip-list on each run
├── setup-security.sh          # Backup + python3 JSON merge (no more blind overwrite)
├── migrate-to-complement.sh   # Standalone migration for v3.x users
├── install-statusline.sh      # Unchanged
├── setup-council.sh           # Unchanged
└── verify-install.sh          # Reads toolkit-install.json; adds mode to health report
manifest.json                  # Extended with per-file conflicts_with / requires_base
~/.claude/toolkit-install.json # State file (written by init + update, read by update + migrate)
```

### Structure Rationale

- **`detect.sh` as sourced helper (not inline):** Both `init-claude.sh` and `update-claude.sh` need identical detection logic. A sourced file eliminates the copy-paste duplication and is the single place to add the future `claude plugin list` enhancement.
- **Manifest carries skip-metadata (not a separate config file):** `manifest.json` is already the canonical file registry. Adding `conflicts_with` fields there keeps authority in one document; shell scripts filter from it at install time. A separate `install-modes.json` would create a second source of truth that drifts.
- **State at `~/.claude/toolkit-install.json` (not `~/.claude/toolkit/`):** Flat file in `~/.claude/` root mirrors the pattern of `~/.claude/settings.json`. No nested directory needed — the toolkit is a single product, not a plugin family.
- **Migration as a separate script (not a flag on update-claude.sh):** Migration is destructive (removes files with backup) and one-time-per-user. Mixing it with the routine update path increases accident risk. A named script makes the action explicit and auditable.

## Architectural Patterns

### Pattern 1: Source-before-execute (detect.sh)

**What:** `detect.sh` is not a standalone script but a library of functions sourced by callers with `source "$(dirname "$0")/detect.sh"` or the equivalent remote-curl variant.

**When to use:** Shared logic between two or more scripts that must behave identically.

**Trade-offs:** Requires callers to source before use; remote-curl install must download the file first or inline the functions as a fallback. Both `init-claude.sh` (curl entry point) and `update-claude.sh` need a download-then-source step when operating remotely.

**Example:**

```bash
# In init-claude.sh and update-claude.sh
DETECT_URL="$REPO_URL/scripts/detect.sh"
DETECT_TMP=$(mktemp)
curl -sSL "$DETECT_URL" -o "$DETECT_TMP"
# shellcheck source=/dev/null
source "$DETECT_TMP"
rm -f "$DETECT_TMP"

INSTALL_MODE=$(resolve_mode)   # standalone | complement-sp | complement-gsd | complement-full
```

### Pattern 2: Declarative skip-list via manifest metadata

**What:** Each entry in `manifest.json`'s file lists carries optional `conflicts_with` and `requires_base` fields. The shell resolver filters FILES[] at runtime: skip any file whose `conflicts_with` list intersects the detected plugins.

**When to use:** When the set of files to skip is large enough (7+ known hard duplicates today) to be impractical as a hardcoded shell array, or when the list needs to be audited by humans reading the manifest.

**Trade-offs:** Requires shell to parse JSON from manifest. Pure bash JSON parsing is fragile; the recommended approach is to pre-generate the skip-list in Python (which is already required by `setup-security.sh`) and export it as a shell array. This keeps shell logic simple.

**Example:**

```json
{
  "files": {
    "commands": [
      { "path": "commands/debug.md",        "conflicts_with": ["superpowers"] },
      { "path": "commands/tdd.md",          "conflicts_with": ["superpowers"] },
      { "path": "commands/worktree.md",     "conflicts_with": ["superpowers"] },
      { "path": "commands/verify.md",       "conflicts_with": ["superpowers"] },
      { "path": "commands/checkpoint.md",   "conflicts_with": ["get-shit-done"] },
      { "path": "commands/handoff.md",      "conflicts_with": ["get-shit-done"] },
      { "path": "commands/learn.md",        "conflicts_with": ["superpowers"] },
      { "path": "commands/council.md",      "conflicts_with": [] },
      { "path": "commands/helpme.md",       "conflicts_with": [] }
    ]
  }
}
```

```bash
# Shell: use python3 (already required) to build skip-set
SKIP_SET=$(python3 -c "
import json, sys
manifest = json.loads(sys.stdin.read())
mode = sys.argv[1]  # e.g. 'complement-full'
skip = []
for section in manifest['files'].values():
    for entry in (section if isinstance(section, list) else []):
        if isinstance(entry, dict):
            cw = entry.get('conflicts_with', [])
            if ('superpowers' in cw and 'sp' in mode) or \
               ('get-shit-done' in cw and 'gsd' in mode):
                skip.append(entry['path'])
print(' '.join(skip))
" <<< "$MANIFEST" "$INSTALL_MODE")
```

### Pattern 3: Atomic state write with temp-then-move

**What:** `toolkit-install.json` is written to a temp file first, then renamed to the final path. This prevents a partial write from leaving a corrupt state file.

**When to use:** Any time the state file is updated (after install, after update).

**Trade-offs:** Requires `mv` to be on the same filesystem as `~/.claude/` — always true in practice.

**Example:**

```bash
write_install_state() {
    local mode="$1" version="$2"
    local state_file="$HOME/.claude/toolkit-install.json"
    local tmp_file
    tmp_file=$(mktemp)

    python3 - "$mode" "$version" > "$tmp_file" << 'PYEOF'
import json, sys, datetime
mode, version = sys.argv[1], sys.argv[2]
state = {
    "version": version,
    "mode": mode,
    "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
    "sp_present": "sp" in mode,
    "gsd_present": "gsd" in mode,
}
print(json.dumps(state, indent=2))
PYEOF

    mv "$tmp_file" "$state_file"
}
```

## Data Flow

### Install Flow (v4.0)

```
User runs: bash <(curl -sSL .../init-claude.sh) [framework]
    |
    v
[1] Download + source detect.sh
    detect_sp()   → checks ~/.claude/plugins/cache/claude-plugins-official/superpowers/
    detect_gsd()  → checks ~/.claude/get-shit-done/
    resolve_mode() → returns one of: standalone | complement-sp | complement-gsd | complement-full
    |
    v
[2] Fetch manifest.json
    Parse per-file conflicts_with metadata
    Build SKIP_SET (python3, using mode from step 1)
    |
    v
[3] Filter FILES[] array
    Remove entries whose path is in SKIP_SET
    Remaining list = files to actually install
    |
    v
[4] Install filtered files
    (same curl-to-.claude/ logic as v3.0, unchanged)
    |
    v
[5] Write ~/.claude/toolkit-install.json
    { mode, version, sp_present, gsd_present, installed_files[], skipped_files[], timestamp }
    |
    v
[6] Report to user
    "Installed in complement-full mode. Skipped 7 commands (duplicated by SP/GSD)."
```

### Update Flow (v4.0)

```
User runs: bash <(curl -sSL .../update-claude.sh)
    |
    v
[1] Read ~/.claude/toolkit-install.json   (previous mode)
    Re-run detect_sp() + detect_gsd()     (current state)
    If mode changed: log diff + ask user to confirm
    |
    v
[2] Re-fetch manifest.json, rebuild SKIP_SET for current mode
    |
    v
[3] Backup .claude/ (unchanged from v3.0)
    |
    v
[4] Update non-skipped files
    Smart-merge CLAUDE.md (unchanged logic)
    |
    v
[5] Write updated toolkit-install.json (new version, current mode, current skip-list)
```

### setup-security.sh Safe Merge Flow

```
[1] Backup ~/.claude/settings.json  → ~/.claude/settings.json.bak-TIMESTAMP
    |
    v
[2] python3 JSON merge:
    load existing settings.json
    add/update hooks.PreToolUse  (never remove SP hooks — append-only for Bash hooks)
    add/update enabledPlugins    (additive only)
    |
    v
[3] Atomic write (temp + mv)
    |
    v
[4] Verify: re-read and confirm expected keys exist
```

### migrate-to-complement.sh Flow

```
[1] Read existing ~/.claude/toolkit-install.json (mode = standalone or absent)
    Re-run detection: finds SP and/or GSD now present
    |
    v
[2] Identify removable files:
    manifest entries with conflicts_with that match detected plugins
    cross-ref against installed_files[] in state JSON
    |
    v
[3] Prompt user: show list of files to remove, ask [y/N]
    |
    v
[4] If confirmed:
    Backup .claude/ (timestamped)
    Remove duplicate files
    Update toolkit-install.json with new mode + skipped_files[]
    |
    v
[5] Report: "Removed 7 files. Backup at .claude-backup-TIMESTAMP/"
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| v4.0 (current scope) | 4 install modes, 7 known skip files — python3 inline script sufficient |
| Future: more base plugins | `conflicts_with` array already supports N plugins; detection just needs more `detect_X()` functions in `detect.sh` |
| Future: per-file install state | Add `installed_files[]` map to `toolkit-install.json`; updater diffs against manifest |

## Anti-Patterns

### Anti-Pattern 1: Inline detection in each script

**What people do:** Copy-paste the `[ -d ~/.claude/get-shit-done/ ]` check into both `init-claude.sh` and `update-claude.sh`.

**Why it's wrong:** When the detection path changes (or `claude plugin list` support is added), you must update two places and they will inevitably drift.

**Do this instead:** Single `detect.sh` sourced by both. One place to update, one place to test.

### Anti-Pattern 2: Hardcoded skip arrays in shell

**What people do:** Maintain `SKIP_IF_SP=("commands/debug.md" "commands/tdd.md" ...)` as shell arrays in the installer.

**Why it's wrong:** The skip-list is already semantically part of the file manifest. Duplicating it in shell creates a second source of truth. When a new command is added to `manifest.json`, the developer must also remember to update the shell array.

**Do this instead:** `conflicts_with` fields in `manifest.json` + python3 resolver at install time.

### Anti-Pattern 3: Separate `install-modes.json` config file

**What people do:** Create `scripts/install-modes.json` or `scripts/complement-config.json` with the skip logic.

**Why it's wrong:** Yet another file to keep in sync with `manifest.json`. Every file addition requires two edits.

**Do this instead:** Embed metadata in `manifest.json` per-file entries. Single-file authority.

### Anti-Pattern 4: Blind overwrite of settings.json

**What people do:** `cat > ~/.claude/settings.json << SETTINGS ... SETTINGS` (current v3.0 behavior in `setup-security.sh:249-273`).

**Why it's wrong:** Destroys SP hooks, GSD hooks, or any user customization in that file.

**Do this instead:** Backup first (`cp settings.json settings.json.bak-$timestamp`), then python3 JSON merge that is additive-only for `PreToolUse` hooks.

### Anti-Pattern 5: Migration flag on update-claude.sh

**What people do:** Add `--migrate` flag to `update-claude.sh`.

**Why it's wrong:** Migration is destructive and one-time. Mixing destructive migration into the routine update path — even behind a flag — increases the chance of accidental trigger and complicates the update script's responsibility surface.

**Do this instead:** Standalone `migrate-to-complement.sh`. Name communicates intent. Audit trail is clear (`git log scripts/migrate-to-complement.sh`).

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| superpowers plugin | Filesystem probe: `[ -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/ ]` | Path confirmed in PROJECT.md |
| get-shit-done plugin | Filesystem probe: `[ -d ~/.claude/get-shit-done/ ]` | Path confirmed in PROJECT.md |
| `~/.claude/settings.json` | Read + python3 JSON merge + atomic write | python3 already used in `setup-security.sh` — no new dependency |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `detect.sh` -> `init-claude.sh` | Shell source + exported variables | `INSTALL_MODE`, `SP_PRESENT`, `GSD_PRESENT` |
| `detect.sh` -> `update-claude.sh` | Shell source + exported variables | Same variables; update also reads state file |
| `manifest.json` -> install scripts | python3 inline JSON parsing | Already a pattern in `setup-security.sh`; no new dep |
| `toolkit-install.json` -> `update-claude.sh` | `python3 -c json.load(...)` | Allows mode-change detection |
| `toolkit-install.json` -> `migrate-to-complement.sh` | `python3 -c json.load(...)` | Cross-ref installed_files[] against current skip-set |

## Build Order and Rationale

The six components have hard dependencies that dictate sequence:

```
[1] detect.sh
     |
     +---> [2] manifest.json schema extension
                  |
                  +---> [3] init-claude.sh refactor
                  |
                  +---> [4] update-claude.sh refactor
                               |
                               +---> [5] migrate-to-complement.sh
                                         (reads state written by update)

[parallel with any of 1-5]
[6] setup-security.sh safe merge  (independent; only dep is python3 already present)
```

**Rationale per step:**

1. **detect.sh first** — both init and update source it; must exist before either is touched. Lowest risk change (new file, no modification to existing scripts yet).

2. **manifest.json schema second** — defines which files get skipped and in which modes. The skip-list resolver in init and update both need this shape to be finalized before they can generate correct SKIP_SET.

3. **init-claude.sh refactor third** — sources detect.sh, reads manifest skip-list, writes toolkit-install.json. This is the primary install path; validate it against all 4 modes in manual smoke test before touching the update path.

4. **update-claude.sh refactor fourth** — sources detect.sh, reads state file, re-evaluates skip-list. Depends on state file format being stable (defined in step 3).

5. **migrate-to-complement.sh fifth** — depends on state file (written by step 3/4) and skip-list logic (defined in step 2). Can only be written and tested after the state file schema is stable.

6. **setup-security.sh safe merge can be parallelized** — it touches `~/.claude/settings.json` only and has no dependency on detect.sh, the manifest schema extension, or the state file. Its only requirement is python3 (already present in current `setup-security.sh`). The backup-before-merge and atomic-write patterns can be implemented in isolation from the complement-mode work.

## Sources

- Direct codebase analysis: `scripts/init-claude.sh`, `scripts/update-claude.sh`, `scripts/setup-security.sh`, `manifest.json`
- Project requirements: `.planning/PROJECT.md` (Active requirements section, Constraints section, Key Decisions section)
- Existing architecture: `.planning/codebase/ARCHITECTURE.md`
- Known conflicts enumerated in `.planning/PROJECT.md` Context section (7 hard duplicates, SP/GSD paths)

---

*Architecture research for: claude-code-toolkit complement-mode install system*
*Researched: 2026-04-17*
