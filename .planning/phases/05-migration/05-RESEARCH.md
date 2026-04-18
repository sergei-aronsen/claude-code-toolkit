# Phase 5: Migration — Research

**Researched:** 2026-04-18
**Domain:** Bash shell scripting — migration script, state schema extension, SP plugin cache layout
**Confidence:** HIGH (all critical claims verified against live filesystem and source code)

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-70:** TK template hash = remote manifest fetch via `curl -sSLf $REPO_URL/<path> -o $TMP_FILE`
  then `sha256_file`. 7 HTTP requests per run. Fallback: two-column diff + warning on fetch failure.
- **D-71:** SP equivalent path = same basename. **SEE BELOW — ESCAPE HATCH ACTIVATED.**
- **D-72:** SP path unreadable → two-column diff + `— (SP file not found at <path>)`, prompt still fires.
- **D-73:** User-mod detection = two-signal OR: (a) on-disk hash != state sha256, (b) on-disk hash != TK template hash.
- **D-74:** Prompt shape `[y/N/d]`, default `N`. `d` = `diff -u on-disk vs TK_template`, re-prompt loop.
- **D-75:** State schema v2: `synthesized_from_filesystem: true/false`, `version: 1 → 2`.
- **D-76:** Standalone script only; `update-claude.sh` emits a single-line CYAN hint when D-77 holds.
- **D-77:** Hint triple-AND: mode==standalone AND HAS_SP||HAS_GSD AND filesystem-intersection non-empty.
- **D-78:** Idempotence two-signal AND: mode!=standalone AND filesystem-intersection empty.
- **D-79:** Partial migration: mode = recommend_mode, declined files → skipped_files[reason=kept_by_user].
- **D-80:** Three plans: 05-01 (state v2 + hint), 05-02 (migrate core), 05-03 (state rewrite + lock + idempotence).
- **D-81:** Three test harnesses: test-migrate-diff.sh, test-migrate-flow.sh, test-migrate-idempotent.sh (Tests 12/13/14).
- **D-82:** One PR, branch feature/phase-5-migration, Conventional Commits.

### Claude's Discretion

- Exact flag surface for `migrate-to-complement.sh` (`--yes`, `--dry-run`, `--verbose`, `--no-backup` fails hard).
- Exact post-migration summary format (reuse Phase 4 D-58 four-group shape: MIGRATED/KEPT/BACKED UP/MODE).
- Exact diff command for `d` option (default `diff -u`, no git required).
- Exact warning text for D-73 locally-modified case.
- Exact hint wording emitted by `update-claude.sh` per D-76.
- Whether migrate fetches remote manifest itself or reuses update-claude.sh tempfile.
- Whether `--force-mode=<mode>` is accepted (likely NO for MVP).
- Exact field name for `synthesized_from_filesystem` (any JSON-safe name acceptable).

### Deferred Ideas (OUT OF SCOPE)

- `[y/N/d/s]` skip-to-custom-dir prompt variant.
- Auto-invoke migrate from update-claude.sh.
- `~/.claude-backup-pre-migrate-*/` cleanup / rotation (BACKUP-01/02 v4.1).
- Interactive side-by-side diff viewer.
- `--force-mode=<mode>` flag.
- Migration script documentation in README/CHANGELOG (Phase 6 DOCS-01..04).
- Release validation matrix smoke tests (Phase 7).

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIGRATE-01 | `scripts/migrate-to-complement.sh` is a separate file — destructive + one-time | D-76 confirmed; update-claude.sh hint path verified |
| MIGRATE-02 | Three-way diff per file: TK template hash vs on-disk hash vs SP/GSD equivalent | SP equivalent path mapping fully verified (see D-71 BLOCKER); diff mechanics confirmed |
| MIGRATE-03 | Per-file `[y/N]` confirmation; user-modified files get extra warning | Prompt pattern from Phase 4 D-56; `< /dev/tty` guard verified |
| MIGRATE-04 | Backup entire install to `~/.claude-backup-pre-migrate-<unix-ts>/` before any removal | `cp -R` preserves symlinks by default on macOS BSD; pattern confirmed |
| MIGRATE-05 | Rewrite `toolkit-install.json` to new complement-* mode after migration | `write_state` signature verified; v2 extension mechanism documented |
| MIGRATE-06 | Migration idempotent — second run reports "nothing to do" + exit 0 | D-78 two-signal AND fully specified and implementable |

</phase_requirements>

---

## Executive Summary

Phase 5 ships `scripts/migrate-to-complement.sh` — a one-time interactive script for v3.x users who have `superpowers` and/or `get-shit-done` installed. The script enumerates duplicate files, shows a three-column hash comparison, takes a full backup, prompts per-file `[y/N/d]`, then rewrites `toolkit-install.json` to the new complement mode. Two retrofits to `update-claude.sh` are also in scope: the D-50 synthesis path gains a `synthesized_from_filesystem: true` field, and a CYAN hint fires when the D-77 triple-AND condition holds.

**D-71 ESCAPE HATCH ACTIVATED — BLOCKER FOR PLANNER.** The same-basename SP equivalent path mapping is valid for **1 of 7 confirmed duplicates** (`agents/code-reviewer.md`). The other 6 use entirely different directory types and names in SP 5.0.7: TK commands map to SP skills (different bucket type), and TK `skills/debugging/` maps to SP `skills/systematic-debugging/` (different directory name). The conditional escape hatch in D-71 applies: the planner MUST add an explicit `sp_equivalent:` field to `manifest.json` for the 6 failing paths, and default to the one confirmed match. Without this manifest schema extension, the three-way diff third column will always be blank for 6/7 files, making the three-column diff feature useless for its primary use case. This is the highest-priority finding in this research document.

The remaining mechanics are well-understood: all library functions needed (`write_state`, `sha256_file`, `acquire_lock`, `recommend_mode`, `compute_skip_set`) exist in their final Phase 4 form and have been read. The `write_state` function accepts 7 positional args today; the v2 extension adds an 8th positional arg for `synthesized_from_filesystem`. The test harness pattern mirrors Phase 4's `TK_UPDATE_*` env-var seam approach. No new external dependencies are required.

**Primary recommendation:** Add `sp_equivalent` to manifest before planning 05-02. The field should contain the SP plugin-cache relative path (e.g., `skills/systematic-debugging/SKILL.md`) so the migrate script can compute the full absolute path as `~/.claude/plugins/cache/claude-plugins-official/superpowers/<SP_VERSION>/<sp_equivalent>`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SP/GSD plugin cache read | Filesystem (read-only) | — | detect.sh already pins `$SP_PLUGIN_DIR` constant |
| Duplicate enumeration | migrate script (runtime) | manifest.json (data source) | jq filter over conflicts_with, then filesystem intersection |
| Three-way hash comparison | migrate script | lib/state.sh (sha256_file) | hashes on-disk, TK template (remote), SP equivalent (local cache) |
| Per-file prompt loop | migrate script | lib/state.sh (< /dev/tty guard) | interactive, must survive curl|bash |
| Backup before mutation | migrate script | lib/state.sh (acquire_lock) | cp -R before any rm; lock serializes against concurrent update runs |
| State rewrite | lib/state.sh (write_state) | migrate script (caller) | extends existing atomic write path |
| D-77 hint emission | update-claude.sh (retrofit) | lib/install.sh (compute_skip_set) | single-line addition after existing state-load + detect block |
| Test harness seams | scripts/tests/ (new scripts) | Makefile (test target wiring) | mirrors Phase 4 TK_UPDATE_* env-var pattern |

---

## D-71 Verification (HIGHEST PRIORITY FINDING)

**Status: ESCAPE HATCH ACTIVATED — planner must add `sp_equivalent:` to manifest.json**

Verified against live SP 5.0.7 at `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`. [VERIFIED: live filesystem grep, 2026-04-18]

| TK Duplicate Path | Same-Basename SP Path Exists? | Actual SP Equivalent Path |
|-------------------|-------------------------------|--------------------------|
| `commands/debug.md` | NO | `skills/systematic-debugging/SKILL.md` |
| `commands/plan.md` | NO | `skills/writing-plans/SKILL.md` (commands/write-plan.md exists but is deprecated) |
| `commands/tdd.md` | NO | `skills/test-driven-development/SKILL.md` |
| `commands/verify.md` | NO | `skills/verification-before-completion/SKILL.md` |
| `commands/worktree.md` | NO | `skills/using-git-worktrees/SKILL.md` |
| `agents/code-reviewer.md` | **YES** | `agents/code-reviewer.md` |
| `skills/debugging/SKILL.md` | NO | `skills/systematic-debugging/SKILL.md` |

**Root cause:** TK commands are slash-command `.md` files; SP ships the same functionality as skill directories with `SKILL.md` inside them. The categories differ (command vs skill). The one exception (`agents/code-reviewer.md`) works because both TK and SP use the same `agents/` bucket and the same file name — this is also the namespace collision flagged in PROJECT.md.

**Impact on manifest.json:** 6 entries need a new `sp_equivalent` field. The one matching entry (`agents/code-reviewer.md`) does not need it (same-basename works). Proposed schema extension (no manifest_version bump needed — only adding an optional field):

```json
{
  "path": "commands/debug.md",
  "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/systematic-debugging/SKILL.md"
}
```

The migrate script then computes: `~/.claude/plugins/cache/claude-plugins-official/superpowers/$SP_VERSION/$sp_equivalent`

For the one same-basename match, the script can derive the path automatically or also use an explicit `sp_equivalent` field set to `agents/code-reviewer.md` (redundant but consistent).

**GSD equivalent check:** `manifest.json` contains 0 `conflicts_with: ["get-shit-done"]` entries. [VERIFIED: grep, 0 matches] GSD column in the three-way diff is not needed for Phase 5. `~/.claude/get-shit-done/` exists at version 1.36.0 but carries no TK duplicates.

---

## SP Plugin Cache Path (D-71 Path Pattern)

Verified path: `~/.claude/plugins/cache/claude-plugins-official/superpowers/<SP_VERSION>/` [VERIFIED: live filesystem, 2026-04-18]

- `<SP_VERSION>` is the string returned by `detect.sh` as `$SP_VERSION` (e.g., `5.0.7`).
- The `detect_superpowers()` function already resolves this via `find ... -maxdepth 1 -type d | sort -V | tail -1`.
- `migrate-to-complement.sh` sources `detect.sh` at the top (same as `update-claude.sh`) and uses `$SP_VERSION` directly.
- Full path construction: `"$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/$SP_VERSION/$sp_equivalent"`

SP 5.0.7 directory layout confirmed:

```text
~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/
├── agents/         — code-reviewer.md
├── commands/       — brainstorm.md, execute-plan.md, write-plan.md (all deprecated stubs)
├── skills/         — 14 skill directories, each containing SKILL.md + supporting files
├── AGENTS.md, CLAUDE.md, CHANGELOG.md, README.md, ...
└── hooks/, scripts/, tests/
```

---

## Remote Manifest Fetch Pattern (D-70)

The exact pattern from `update-claude.sh:43-99` to mirror verbatim in `migrate-to-complement.sh`: [VERIFIED: source read]

```bash
#!/bin/bash
set -euo pipefail

# Color constants (ANSI, same as all other scripts)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"

# mktemp + trap EXIT cleanup pattern
DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX")
LIB_INSTALL_TMP=$(mktemp "${TMPDIR:-/tmp}/install.XXXXXX")
LIB_STATE_TMP=$(mktemp "${TMPDIR:-/tmp}/state.XXXXXX")
MANIFEST_TMP=$(mktemp "${TMPDIR:-/tmp}/manifest.XXXXXX")
# Individual TK template fetches (7 files for SP duplicate set)
TK_TMPL_TMP=$(mktemp "${TMPDIR:-/tmp}/tk-tmpl.XXXXXX")

trap 'release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" \
      "$MANIFEST_TMP" "$TK_TMPL_TMP"' EXIT

# detect.sh — soft-fail (D-70's "skip diff column" fallback applies if absent)
if [[ -n "${HAS_SP+x}" && -n "${HAS_GSD+x}" ]]; then
    :  # test seam: env vars already set
elif curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$DETECT_TMP"
else
    echo -e "${YELLOW}⚠${NC} Could not fetch detect.sh — plugin detection unavailable"
    HAS_SP=false; HAS_GSD=false; SP_VERSION=""; GSD_VERSION=""
fi

# lib/install.sh + lib/state.sh — HARD-fail
for lib_pair in "install.sh:$LIB_INSTALL_TMP" "state.sh:$LIB_STATE_TMP"; do
    lib_name="${lib_pair%%:*}"; lib_path="${lib_pair##*:}"
    if [[ -n "${TK_MIGRATE_LIB_DIR:-}" && -f "$TK_MIGRATE_LIB_DIR/$lib_name" ]]; then
        cp "$TK_MIGRATE_LIB_DIR/$lib_name" "$lib_path"
    elif ! curl -sSLf "$REPO_URL/scripts/lib/$lib_name" -o "$lib_path"; then
        echo -e "${RED}✗${NC} Failed to fetch scripts/lib/$lib_name — migrate cannot proceed"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_path"
done

# Remote manifest — HARD-fail
MANIFEST_SRC="${TK_MIGRATE_MANIFEST_OVERRIDE:-}"
if [[ -n "$MANIFEST_SRC" && -f "$MANIFEST_SRC" ]]; then
    cp "$MANIFEST_SRC" "$MANIFEST_TMP"
elif ! curl -sSLf "$REPO_URL/manifest.json" -o "$MANIFEST_TMP"; then
    echo -e "${RED}✗${NC} Failed to fetch manifest.json — migrate cannot proceed"
    exit 1
fi
MANIFEST_VER=$(jq -r '.manifest_version' "$MANIFEST_TMP" 2>/dev/null || echo "")
if [[ "$MANIFEST_VER" != "2" ]]; then
    echo -e "${RED}✗${NC} manifest.json manifest_version=${MANIFEST_VER:-unknown}; expected 2"
    exit 1
fi
```

**Per-file TK template fetch loop** (for hashing — D-70):

```bash
fetch_tk_template_hash() {
    local rel="$1"   # e.g. "commands/debug.md"
    local out=""
    if [[ -n "${TK_MIGRATE_FILE_SRC:-}" ]]; then
        if [[ -f "$TK_MIGRATE_FILE_SRC/$rel" ]]; then
            out=$(sha256_file "$TK_MIGRATE_FILE_SRC/$rel")
        fi
    else
        if curl -sSLf "$REPO_URL/$rel" -o "$TK_TMPL_TMP" 2>/dev/null; then
            out=$(sha256_file "$TK_TMPL_TMP")
        fi
    fi
    printf '%s' "$out"
}
```

---

## State Schema v2 Extension (D-75)

Current `write_state` signature (7 positional args + state_path hardcoded to `$STATE_FILE`): [VERIFIED: source read]

```bash
write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7"
    # ... python3 inline script: sys.argv[1:9] = mode has_sp sp_ver has_gsd gsd_ver installed_csv skipped_csv state_path
}
```

The Python inline reads `sys.argv[1:9]` — 8 values total (7 args + state_path). Adding an 8th positional arg:

```bash
write_state() {
    local mode="$1" has_sp="$2" sp_ver="$3" has_gsd="$4" gsd_ver="$5"
    local installed_csv="$6" skipped_csv="$7" synth_flag="${8:-false}"
    python3 - "$mode" "$has_sp" "$sp_ver" "$has_gsd" "$gsd_ver" \
             "$installed_csv" "$skipped_csv" "$synth_flag" "$STATE_FILE" <<'PYEOF'
# sys.argv[1:10] = mode has_sp sp_ver has_gsd gsd_ver installed_csv skipped_csv synth_flag state_path
mode, has_sp, sp_ver, has_gsd, gsd_ver, installed_csv, skipped_csv, synth_flag, state_path = sys.argv[1:10]
# ... existing logic unchanged ...
state = {
    "version": 2,           # bumped from 1
    "mode": mode,
    "synthesized_from_filesystem": synth_flag == "true",   # NEW field
    # ... rest of existing keys unchanged ...
}
PYEOF
}
```

**Read-path backwards compat for v1 state files:**

```bash
# When reading v1 state, missing field defaults to false:
synth=$(jq -r '.synthesized_from_filesystem // false' <<<"$STATE_JSON")
```

**Phase 4 D-50 retrofit** (one-line change in `synthesize_v3_state` in `update-claude.sh:157`):

```bash
# Before (Phase 4):
write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" ""
# After (Phase 5 D-75 retrofit):
write_state "$mode" "$HAS_SP" "$SP_VERSION" "$HAS_GSD" "$GSD_VERSION" "$installed_csv" "" "true"
```

Normal Phase 3 install path omits the 8th arg → defaults to `false`. No change to `init-claude.sh`.

---

## D-74 Prompt Shape (`[y/N/d]`)

Exact pattern from Phase 4 `update-claude.sh:577-593` (the `prompt_modified_file` function): [VERIFIED: source read]

```bash
while :; do
    local choice=""
    if ! read -r -p "Remove $rel? [y/N/d]: " choice < /dev/tty 2>/dev/null; then
        choice="N"   # fail-closed: no /dev/tty (curl|bash context)
    fi
    case "${choice:-N}" in
        y|Y)
            rm -f "$CLAUDE_DIR/$rel"
            MIGRATED_PATHS+=("$rel")
            return 0 ;;
        d|D)
            diff -u "$local_path" "$tk_tmpl_tmp" || true ;;  # exit 1 = diffs exist, that's fine
        *)
            KEPT_PATHS+=("$rel:kept_by_user")
            return 0 ;;
    esac
done
```

Key details:
- `< /dev/tty 2>/dev/null` — mandatory for `curl | bash` survival. Fails closed to `N`.
- `diff -u` — available on macOS BSD and Linux without git. [VERIFIED: `which diff` + `diff --version` on this machine]
- `|| true` after diff — diff exits 1 when files differ; `set -euo pipefail` would abort without this.
- The `d` option shows the diff and re-enters the while loop (same pattern as update-claude.sh D-56).
- For the D-73 "locally modified" warning, print a warning line BEFORE entering this loop.

---

## Backup Mechanics (MIGRATE-04)

**Pattern:** `cp -R "$CLAUDE_DIR" "$BACKUP_DIR"` — mirrors Phase 4 D-57 exactly.

**Symlink behavior on macOS BSD:** `cp -R` with no `-H` or `-L` flag defaults to `-P` (no symlink follow). Symlinks are **preserved as symlinks** in the backup — they are NOT dereferenced. [VERIFIED: `man cp` on this machine — `-P` is the default when `-R` is specified]

This is the correct behavior for a backup: the backup mirrors the exact on-disk state including symlink structure. No need for `cp -RP` (redundant on BSD) or `cp -rL` (would dereference, potentially bloating the backup with duplicate content).

**Failure mode before first removal:**

```bash
BACKUP_DIR="$HOME/.claude-backup-pre-migrate-$(date -u +%s)"
if ! cp -R "$HOME/.claude" "$BACKUP_DIR"; then
    echo -e "${RED}✗${NC} Backup failed — aborting migration without removing any files"
    exit 1
fi
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR"
```

Note: naming differs from Phase 4 D-57's `~/.claude-backup-<ts>-<pid>/` — intentional, per CONTEXT.md "visually separable when a user lists `~/`". No `$$` suffix needed (migration is single-run interactive, not concurrent).

**Disk full edge case:** `cp -R` will fail mid-copy if disk is full. The partial backup directory may exist. The migrate script should detect non-zero exit from cp and abort before touching any files. If `--no-backup` is passed, print an error and exit 1 (backup is an invariant per PROJECT.md, cannot be disabled).

**Sockets and sparse files:** `~/.claude/` typically contains only regular files and directories. The `cp -R` on macOS BSD handles sparse files correctly (copies as regular files, not sparse — acceptable for a backup). Sockets are not expected in `~/.claude/` — `cp` would silently skip them on some systems or error on others, but this is not a realistic concern.

---

## Lock Semantics (Phase 2 D-08..D-11)

`acquire_lock` / `release_lock` in `scripts/lib/state.sh:114-153`: [VERIFIED: source read]

```bash
# acquire_lock: mkdir-based POSIX lock, 3 retries × 1s sleep
# Stale recovery: PID liveness check (kill -0) OR mtime age > 3600s
# On success: writes $$ to $LOCK_DIR/pid
# Returns 0 on lock acquired, 1 on failure (3 retries exhausted)
acquire_lock || exit 1  # caller pattern

# release_lock: rm -rf $LOCK_DIR
# Called in EXIT trap: trap 'release_lock; rm -f $TMP_FILES...' EXIT
```

**Calling convention for `migrate-to-complement.sh`:**

```bash
# Register EXIT trap BEFORE calling acquire_lock (lib invariant from state.sh header comment)
trap 'release_lock; rm -f "$DETECT_TMP" "$LIB_INSTALL_TMP" "$LIB_STATE_TMP" \
      "$MANIFEST_TMP" "$TK_TMPL_TMP"' EXIT
acquire_lock || exit 1
```

Lock must be acquired BEFORE the backup copy (same as Phase 4 D-57 ordering). This serializes against any concurrent `update-claude.sh` run that might also be writing to `~/.claude/`.

`LOCK_DIR` is set by `state.sh` at source time to `$HOME/.claude/.toolkit-install.lock`. When `TK_MIGRATE_HOME` test seam is active, the caller must re-set `LOCK_DIR` and `STATE_FILE` to the seamed path (same as `TK_UPDATE_HOME` pattern in update-claude.sh).

---

## Idempotence Two-Signal AND (D-78)

Signal (a) — `state.mode != "standalone"`:

```bash
STATE_MODE=$(jq -r '.mode' <<<"$STATE_JSON")
if [[ "$STATE_MODE" == "standalone" ]]; then
    # not migrated yet, proceed
    :
else
    # candidate for early exit — check signal (b)
    :
fi
```

Signal (b) — `compute_skip_set(state.mode, manifest) ∩ { actual files on disk }` is empty:

```bash
SKIP_SET_JSON=$(compute_skip_set "$STATE_MODE" "$MANIFEST_TMP")
# Check intersection: any path in skip_set that exists on disk?
INTERSECTION_HIT=false
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if [[ -f "$HOME/.claude/$rel" ]]; then
        INTERSECTION_HIT=true
        break
    fi
done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")

if [[ "$INTERSECTION_HIT" == "false" ]]; then
    echo "Already migrated to $STATE_MODE. Nothing to do."
    exit 0
fi
```

`compute_skip_set` returns a JSON array, already implemented in `lib/install.sh`. [VERIFIED: source read]

---

## D-77 Hint Emission in `update-claude.sh`

The hint fires when all three conditions hold: `state.mode == standalone` AND `HAS_SP || HAS_GSD` AND filesystem-intersection non-empty.

Insertion point: immediately after the existing state-load + detect block (around line 295 in the current `update-claude.sh`, after `STATE_MODE=$(jq -r '.mode' ...)` is set and `RECOMMENDED=$(recommend_mode)` is computed):

```bash
# D-77 migrate hint (Phase 5 retrofit)
if [[ "$STATE_MODE" == "standalone" && \
      ("$HAS_SP" == "true" || "$HAS_GSD" == "true") ]]; then
    _HINT_HIT=false
    _HINT_SKIP_JSON=$(compute_skip_set "$(recommend_mode)" "$MANIFEST_TMP")
    while IFS= read -r _rel; do
        [[ -z "$_rel" ]] && continue
        if [[ -f "$CLAUDE_DIR/$_rel" ]]; then _HINT_HIT=true; break; fi
    done < <(jq -r '.[]' <<<"$_HINT_SKIP_JSON")
    if [[ "$_HINT_HIT" == "true" ]]; then
        echo -e "${CYAN}ℹ${NC} Legacy duplicates detected (SP/GSD installed, mode=standalone). Run: ./scripts/migrate-to-complement.sh"
    fi
    unset _HINT_HIT _HINT_SKIP_JSON _rel
fi
```

This is a read-only probe — no state mutation, no exit, no prompt. Normal update flow continues after this block.

---

## Duplicate Enumeration

To enumerate "files that are in the duplicate set AND physically present on disk":

```bash
# Build the list of duplicates for the active complement mode
SKIP_SET_JSON=$(compute_skip_set "$(recommend_mode)" "$MANIFEST_TMP")

DUPLICATES=()
while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if [[ -f "$HOME/.claude/$rel" ]]; then
        DUPLICATES+=("$rel")
    fi
done < <(jq -r '.[]' <<<"$SKIP_SET_JSON")
```

If `${#DUPLICATES[@]} -eq 0`: print "No duplicate files found" + exit 0 (or trigger the D-78 early-exit path, since the filesystem-intersection is empty).

---

## `sp_equivalent` Field: Manifest Extension Required

The planner must add `sp_equivalent` to 6 manifest entries. The complete mapping: [VERIFIED: live filesystem]

```json
{ "path": "commands/debug.md",    "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/systematic-debugging/SKILL.md" },
{ "path": "commands/plan.md",     "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/writing-plans/SKILL.md" },
{ "path": "commands/tdd.md",      "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/test-driven-development/SKILL.md" },
{ "path": "commands/verify.md",   "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/verification-before-completion/SKILL.md" },
{ "path": "commands/worktree.md", "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/using-git-worktrees/SKILL.md" },
{ "path": "agents/code-reviewer.md", "conflicts_with": ["superpowers"] },
  /* no sp_equivalent needed — same-basename holds */
{ "path": "skills/debugging/SKILL.md", "conflicts_with": ["superpowers"],
  "sp_equivalent": "skills/systematic-debugging/SKILL.md" }
```

The migrate script reads the `sp_equivalent` field:

```bash
sp_equiv=$(jq -r --arg p "$rel" \
    '.files | to_entries[] | .value[] | select(.path == $p) | .sp_equivalent // ""' \
    "$MANIFEST_TMP")
if [[ -z "$sp_equiv" ]]; then
    # fall back to same-basename (handles agents/code-reviewer.md)
    sp_equiv="$rel"
fi
SP_PATH="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/$SP_VERSION/$sp_equiv"
```

`validate-manifest.py` does not currently validate `sp_equivalent` values. The planner should decide whether to extend Check 6 or leave it as a manual review item.

---

## Test Harness Patterns (D-81)

**Existing seam variables from Phase 3/4** (to mirror for Phase 5):

| Seam Variable | Used By | Purpose |
|---------------|---------|---------|
| `TK_UPDATE_HOME` | update-claude.sh | Redirect `$HOME/.claude` to a tmp dir |
| `TK_UPDATE_LIB_DIR` | update-claude.sh | Source lib files from local path instead of curl |
| `TK_UPDATE_MANIFEST_OVERRIDE` | update-claude.sh | Use a fixture manifest.json instead of remote |
| `TK_UPDATE_FILE_SRC` | update-claude.sh | Read file content from local dir instead of curl |
| `HAS_SP`, `HAS_GSD`, `SP_VERSION`, `GSD_VERSION` | detect.sh | Bypass detect.sh entirely |
| `TK_TEST_INJECT_FAILURE` | lib/install.sh merge functions | Simulate python3 failure |

**Phase 5 seam variables** (new, follow same naming convention):

| Seam Variable | Purpose |
|---------------|---------|
| `TK_MIGRATE_HOME` | Redirect `$HOME/.claude` to a tmp dir |
| `TK_MIGRATE_LIB_DIR` | Source lib files from local path |
| `TK_MIGRATE_MANIFEST_OVERRIDE` | Use fixture manifest |
| `TK_MIGRATE_FILE_SRC` | Read TK template content from local dir (for D-70 hash fetch) |
| `TK_MIGRATE_SP_CACHE_DIR` | Override SP plugin cache root (for D-71 SP hash fetch) |

**Test 12: `test-migrate-diff.sh`** — three-way diff + user-mod detection:

```bash
# Fixture: seeded state with known sha256 values
# Fixture: manifest with sp_equivalent fields
# Fixture: SP cache directory with fixture files
# TK_MIGRATE_SP_CACHE_DIR points to fixture SP cache
# Scenarios:
# - signal-a-only: on-disk hash != state sha256, == TK template → flagged
# - signal-b-only: on-disk hash == state sha256, != TK template → flagged
# - both-signals: both differ → flagged
# - clean-file: both hashes match → no warning
# - sp-missing: sp_equivalent path absent → two-column fallback (D-72)
```

**Test 13: `test-migrate-flow.sh`** — full interactive flow via FIFO (mirrors scenario 5/7 in test-update-diff.sh):

```bash
# Uses FIFO to simulate /dev/tty for y/N/d sequences
# Scenarios:
# - accept-all: all files accepted → all removed from disk, state rewritten
# - decline-all: all files declined → no files removed, state.skipped_files updated
# - partial: accept first, decline rest → mixed outcome
# - --dry-run flag: prints list, exits 0, no files removed, no state rewrite
```

**Test 14: `test-migrate-idempotent.sh`** — second run + self-heal:

```bash
# Scenario 1: normal second run — state.mode != standalone, no duplicates on disk → "Already migrated"
# Scenario 2: manual state rollback but files gone → signal (b) still empty → "Already migrated"
# Scenario 3: state says migrated but user manually re-created a duplicate → script re-runs
```

**Makefile extension:**

```makefile
@echo "Test 12: migrate three-way diff + user-mod detection"
@bash scripts/tests/test-migrate-diff.sh
@echo ""
@echo "Test 13: migrate full flow (accept/decline/partial/dry-run)"
@bash scripts/tests/test-migrate-flow.sh
@echo ""
@echo "Test 14: migrate idempotence + self-heal"
@bash scripts/tests/test-migrate-idempotent.sh
```

---

## Pitfalls and Gotchas

### Pitfall 1: `diff -u` Exit Code Under `set -euo pipefail`

**What goes wrong:** `diff` exits 1 when files differ (not an error, just "differences found"). Under `set -euo pipefail`, this aborts the script.

**How to avoid:** Always append `|| true` after diff calls used for display:

```bash
diff -u "$local_path" "$tk_tmpl_tmp" || true
```

**Warning signs:** Script aborts immediately after printing the diff output. [VERIFIED: `diff --version` on this machine — Apple diff based on FreeBSD diff, same exit-code semantics as GNU diff]

### Pitfall 2: `cp -R` Partial Backup on Disk Full

**What goes wrong:** `cp -R` runs out of disk space mid-copy. It exits non-zero, but a partial backup directory exists at `$BACKUP_DIR`. The script must NOT proceed with any file removal if the backup is incomplete.

**How to avoid:** Check the exit code of `cp -R` before proceeding. Use the `|| { ... ; exit 1; }` pattern — `set -euo pipefail` will catch this automatically if no `|| true` is added.

**Warning signs:** `$BACKUP_DIR` exists but is smaller than `~/.claude/`.

### Pitfall 3: BSD vs GNU `cp` Symlink Behavior

**What goes wrong (non-issue for this codebase):** On Linux GNU `cp`, `cp -R` may follow symlinks (depends on GNU version and flags). On macOS BSD, `cp -R` defaults to `-P` (preserve symlinks). The PROJECT.md constraint is "macOS BSD + GNU Linux" — behavior is consistent here because `~/.claude/` typically contains no symlinks.

**How to avoid:** Use `cp -R` without `-L` on both platforms. The default behavior is correct.

### Pitfall 4: SP Version String in Cache Path

**What goes wrong:** `SP_VERSION` might be empty string if `detect_superpowers()` failed. Then the SP cache path becomes `~/.claude/plugins/cache/claude-plugins-official/superpowers//skills/...` (double slash) and the file won't be found.

**How to avoid:** Guard the SP hash lookup:

```bash
if [[ -n "$SP_VERSION" && -f "$SP_PATH" ]]; then
    sp_hash=$(sha256_file "$SP_PATH")
else
    sp_hash=""  # triggers D-72 two-column fallback
fi
```

### Pitfall 5: State JSON Has Absolute vs Relative Paths

**What goes wrong:** `write_state` records absolute paths in `installed_files[].path` when called with absolute `installed_csv`. After Phase 4's normalization step (`update-claude.sh:391-395`), state is normalized to relative paths. Migration script must handle BOTH formats in v1 state (synthesized from Phase 4) and the post-migrate v2 state.

**How to avoid:** When reading installed paths from state, strip the `$HOME/.claude/` prefix:

```bash
rel=$(echo "$abs_path" | sed "s|^$HOME/.claude/||")
```

Or use `jq --arg base "$HOME/.claude/" '.installed_files[].path | ltrimstr($base)'`.

### Pitfall 6: `make validate` Check 6 and New Script Files

**What goes wrong:** `scripts/validate-manifest.py` Check 6 verifies that disk-tracked buckets (`commands/`, `templates/base/skills/*/SKILL.md`) are all listed in manifest. The new `scripts/migrate-to-complement.sh` and three test harnesses are in `scripts/` — a bucket NOT currently validated by Check 6. However, the spec (D-80 CONTEXT.md) says "ADD entries for `scripts/migrate-to-complement.sh` and the three new test harnesses so `make validate` Check 6 stays green." The planner must decide if `scripts/` becomes a validated manifest bucket or if these are exempted.

**How to avoid:** Examine whether `scripts/tests/*.sh` from prior phases are in manifest (they are not — manifest only tracks install-destination files, not repo scripts). The safest approach: add `scripts/migrate-to-complement.sh` to manifest under a new `files.scripts` bucket if Check 6 is extended, OR document that `scripts/*.sh` are not install-destination files and don't need manifest entries. Prior phase test scripts are not in manifest. Recommend the same exemption for Phase 5.

### Pitfall 7: `synthesize_v3_state` Call Sites

**What goes wrong:** `synthesize_v3_state` in `update-claude.sh` is called from two places (normal synthesis path AND the error-recovery path at line 283). Both must be updated for D-75 to pass `"true"` as the 8th arg.

**How to avoid:** Grep for all `write_state` calls in `update-claude.sh` before retrofitting. There are exactly 2 calls to `write_state` inside `synthesize_v3_state` and 1 at the bottom of the main update flow (which should NOT set `synthesized_from_filesystem=true`).

### Pitfall 8: Lock and Trap Registration Order

**What goes wrong:** If `trap ... EXIT` is registered AFTER `acquire_lock`, a SIGKILL between `acquire_lock` and `trap` registration leaves the lock permanently held. The `state.sh` header comment explicitly documents: "Callers MUST register `trap 'release_lock' EXIT` BEFORE calling acquire_lock."

**How to avoid:** Register the trap on the first mktemp call, include `release_lock` in it, then call `acquire_lock`. This is the exact pattern in `update-claude.sh:435`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| SHA256 hashing | Shell sha256sum/shasum wrapper | `sha256_file` in `lib/state.sh` |
| Atomic JSON writes | Direct `> file` write | `write_state` in `lib/state.sh` (uses mkstemp + os.replace) |
| Lock acquisition | Sleep loop + file test | `acquire_lock`/`release_lock` in `lib/state.sh` |
| Skip-set computation | Hardcoded file lists | `compute_skip_set` in `lib/install.sh` |
| Mode recommendation | if/else SP/GSD detection | `recommend_mode` in `lib/install.sh` |
| Plugin detection | `find` calls in migrate script | Source `detect.sh` (already exports `HAS_SP`, `SP_VERSION`) |
| Unified diff | Custom diff formatter | `diff -u` (POSIX, available on both macOS BSD and Linux) |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `bash` integration tests + `assert_eq` helper (in-repo, no external deps) |
| Config file | `Makefile` test target (lines 42-87) |
| Quick run command | `bash scripts/tests/test-migrate-diff.sh` |
| Full suite command | `make test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIGRATE-01 | migrate-to-complement.sh is a separate file, not a flag | smoke | `test -f scripts/migrate-to-complement.sh` | Wave 0 |
| MIGRATE-02 | Three-column hash diff shown before prompt | functional | `bash scripts/tests/test-migrate-diff.sh` | Wave 0 |
| MIGRATE-03 | Per-file `[y/N/d]` prompt; modified files get extra warning | functional | `bash scripts/tests/test-migrate-flow.sh` | Wave 0 |
| MIGRATE-04 | Backup created before any removal; path printed | functional | `bash scripts/tests/test-migrate-flow.sh` (accept-all scenario) | Wave 0 |
| MIGRATE-05 | `toolkit-install.json` rewritten to complement mode | functional | `bash scripts/tests/test-migrate-flow.sh` (state assertions) | Wave 0 |
| MIGRATE-06 | Second run → "Already migrated" + exit 0 | functional | `bash scripts/tests/test-migrate-idempotent.sh` | Wave 0 |
| D-75 | write_state v2 + synthesized_from_filesystem field | unit | embedded in test-migrate-diff.sh fixture seed | Wave 0 |
| D-77 | update-claude.sh emits CYAN hint when triple-AND holds | integration | extend `test-update-drift.sh` with new scenario | existing file |
| D-78 | Idempotence self-heal when state rolled back but files gone | functional | `bash scripts/tests/test-migrate-idempotent.sh` scenario 2 | Wave 0 |

### Sampling Rate

- **Per task commit:** `make check` (shellcheck + markdownlint + validate)
- **Per wave merge:** `make test` (all 14 tests)
- **Phase gate:** `make test && make check` both green before `/gsd-verify-work`

### Wave 0 Gaps

- `scripts/tests/test-migrate-diff.sh` — covers MIGRATE-02, D-73, D-75
- `scripts/tests/test-migrate-flow.sh` — covers MIGRATE-03, MIGRATE-04, MIGRATE-05, D-74
- `scripts/tests/test-migrate-idempotent.sh` — covers MIGRATE-06, D-78
- `scripts/tests/fixtures/manifest-migrate-v2.json` — fixture manifest with `sp_equivalent` fields
- `scripts/tests/fixtures/sp-cache/` — fixture SP plugin cache directory tree

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bash` | All scripts | Yes | 3.2+ (macOS ships 3.2) | — |
| `python3` | `sha256_file`, `write_state`, `read_state` | Yes | verified in Phase 2 | — |
| `jq` | `compute_skip_set`, manifest parsing | Yes | 1.7.1 verified Phase 3 | — |
| `curl` | Remote fetch (detect.sh, libs, manifest, TK templates) | Yes | standard | soft-fail for detect.sh; hard-fail for libs/manifest |
| `diff` | `[y/N/d]` `d` option | Yes | Apple diff (FreeBSD) | — |
| SP plugin cache | Three-way diff third column | Yes (SP 5.0.7) | 5.0.7 | D-72 two-column fallback |
| `/dev/tty` | Interactive prompts | Yes (terminal) | — | fail-closed to `N` |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** SP plugin cache — when absent, D-72 graceful degrade to two-column diff.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SP 5.0.7 layout represents current SP stable releases (not a pre-release layout change) | D-71 Verification | sp_equivalent paths wrong; needs re-verification on user machines |
| A2 | `~/.claude/` contains no sockets or device files on typical user machines | Backup Mechanics | `cp -R` might emit errors but backup still succeeds |
| A3 | manifest.json does not need a schema version bump for the new `sp_equivalent` optional field | sp_equivalent section | validate-manifest.py might reject unknown fields (it currently does not — verified by reading the script) |
| A4 | No GSD conflicts_with entries will be added to manifest before Phase 5 ships | GSD column | Would require adding GSD equivalent path mapping research |

---

## Open Questions

1. **Should `sp_equivalent` be added to manifest in plan 05-01 or 05-02?**
   - What we know: plan 05-02 is the migrate core that reads `sp_equivalent`. Plan 05-01 is the state v2 + hint retrofit.
   - What's unclear: the manifest change could go in 05-01 (foundation) so the fixture for test-migrate-diff.sh is available.
   - Recommendation: add `sp_equivalent` to manifest.json in plan 05-01 alongside the state v2 change, since both are foundational prerequisites for 05-02.

2. **Should `validate-manifest.py` be extended to validate `sp_equivalent` path existence?**
   - What we know: Check 6 currently validates that manifest paths exist on disk (in the repo's source directories). `sp_equivalent` paths point to the SP plugin cache, not the repo.
   - What's unclear: Checking SP plugin cache paths from CI is not possible (SP is not installed in CI).
   - Recommendation: Do NOT extend validate-manifest.py to check `sp_equivalent` paths. Add a comment in manifest.json explaining the field.

3. **Test 13 `/dev/tty` simulation via FIFO vs skip prompt testing entirely?**
   - What we know: Phase 4 test-update-diff.sh scenarios 5/7 use a FIFO approach that sometimes races (FIFO connects to fd 0 which may or may not be the `/dev/tty` that the script opens). The Phase 4 tests handle this by accepting either outcome.
   - What's unclear: Whether a more reliable approach exists for CI.
   - Recommendation: Mirror the Phase 4 FIFO + dual-outcome acceptance pattern. Add a `--yes` flag to `migrate-to-complement.sh` for use in automated tests (bypasses per-file prompts, accepts all).

4. **Does `write_state` need the 8th-arg extension OR a keyword env var approach?**
   - What we know: The Python inline already reads `sys.argv[1:9]` (exactly 8 values including state_path). Adding an 8th positional arg shifts state_path to position 9 — `sys.argv[1:10]`.
   - What's unclear: Whether any caller currently relies on the exact positional count.
   - Recommendation: Use 8th positional arg with default `${8:-false}`. Safer than env var (no pollution), consistent with existing pattern.

---

## Sources

### Primary (HIGH confidence)

- Live SP 5.0.7 plugin cache at `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/` — D-71 verification, all 7 path mappings [VERIFIED: filesystem grep 2026-04-18]
- `scripts/lib/state.sh` — `write_state` signature (7 args), `acquire_lock`/`release_lock` semantics [VERIFIED: source read]
- `scripts/lib/install.sh` — `recommend_mode`, `compute_skip_set`, `compute_file_diffs_obj` signatures [VERIFIED: source read]
- `scripts/update-claude.sh` — fetch pattern (lines 43-99), prompt pattern (lines 577-593), synthesize_v3_state (lines 146-158) [VERIFIED: source read]
- `scripts/detect.sh` — `detect_superpowers`, SP path constant [VERIFIED: source read]
- `manifest.json` — 7 conflicts_with entries, 0 GSD entries [VERIFIED: source read]
- `scripts/tests/test-update-diff.sh` — test seam pattern, assert_eq helper, FIFO approach [VERIFIED: source read]
- `Makefile` — test target structure, Tests 1-11 [VERIFIED: source read]
- `man cp` on macOS — `-P` is default with `-R` (symlinks preserved) [VERIFIED: man page output]
- `diff --version` — Apple diff (FreeBSD), exits 1 on diffs [VERIFIED: shell command]

### Secondary (MEDIUM confidence)

- Phase 4 04-CONTEXT.md D-56/D-57/D-58/D-59 — prompt patterns and backup conventions referenced [CITED: .planning/phases/04-update-flow/04-CONTEXT.md]
- Phase 5 05-CONTEXT.md — all decisions D-70..D-82 [CITED: .planning/phases/05-migration/05-CONTEXT.md]

---

## Metadata

**Confidence breakdown:**

- D-71 SP path mapping: HIGH — verified live against SP 5.0.7 on this machine
- write_state extension: HIGH — signature read from source, extension mechanism clear
- Backup mechanics: HIGH — `man cp` verified, existing Phase 4 pattern
- Lock semantics: HIGH — source read, comments explicit
- Test harness patterns: HIGH — Phase 4 test harnesses read in full
- Standard stack: HIGH — all libraries exist, versions verified in prior phases

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (SP version bump could change skill directory names)
