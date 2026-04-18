# Phase 3: Install Flow - Research

**Researched:** 2026-04-18
**Domain:** Bash install-flow orchestration — mode selection, jq skip-list, python3 JSON merge, atomic backup, sourced library design
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-30:** `init-claude.sh` and `init-local.sh` source `scripts/detect.sh` after arg parsing, before any filesystem write. Local: `source "$(dirname "$0")/detect.sh"`. Remote: `DETECT_TMP=$(mktemp "${TMPDIR:-/tmp}/detect.XXXXXX") && curl -sSLf "$REPO_URL/scripts/detect.sh" -o "$DETECT_TMP" && source "$DETECT_TMP" && trap 'rm -f "$DETECT_TMP"' EXIT`.
- **D-31:** `update-claude.sh` sources `detect.sh` same pattern as `init-claude.sh`. Phase 3 wires only the source call; full drift logic is Phase 4.
- **D-32:** Interactive mode prompt after `detect.sh`: print detected state, recommended mode, numbered menu `[1=standalone, 2=complement-sp, 3=complement-gsd, 4=complement-full]`. Reuses `read -r -p "..." choice < /dev/tty 2>/dev/null` pattern.
- **D-33:** `--mode <name>` bypasses interactive prompt. Valid values: `standalone`, `complement-sp`, `complement-gsd`, `complement-full`.
- **D-34:** `--mode` mismatch with auto-recommendation → warn and proceed. User flag wins, no `--force` needed for initial install.
- **D-35:** `--dry-run` grouped by manifest bucket with totals footer. Exit 0, no filesystem writes.
- **D-36:** ANSI colors auto-disabled with `[ -t 1 ]`. `[INSTALL]` = `${GREEN}`, `[SKIP — ...]` = `${YELLOW}`.
- **D-37:** `setup-security.sh` python3 block at `:202-237` — EXTEND, do not rewrite from scratch. `mktemp` + `os.replace` atomic write.
- **D-38:** TK-owned subtree strict: only `permissions.deny` TK authored, `hooks.PreToolUse[*]` TK authored, TK `env` block. All other keys read-only.
- **D-39:** Hook collision = append both. Never overwrite SP/GSD hooks.
- **D-40:** One atomic backup per install run before first mutation. Restore on failure.
- **D-41:** Re-run with `~/.claude/toolkit-install.json` present → delegate to `update-claude.sh`. `--force` bypasses.
- **D-42:** Mode change requires interactive prompt (or `--force-mode-change` under `curl|bash`).
- **D-43:** `init-local.sh` writes `.claude/toolkit-install.json` (per-project). Re-detects per project.
- **D-44:** Skip-list via single `jq` filter over `manifest.json`. No parallel arrays in shell.
- **D-45:** `compute_skip_set`, `print_dry_run_grouped` live in `scripts/lib/install.sh` (sourced, NOT executed — NO `set -euo pipefail`, zero stdout during source).
- **D-46:** Three plan clusters: (a) DETECT-05 + lib/install.sh skeleton, (b) MODE-01..06, (c) SAFETY-01..04.
- **D-47:** Tests: `test-modes.sh` (Test 6), `test-dry-run.sh` (Test 7), `test-safe-merge.sh` (Test 8). Wired into `make test`.
- **D-48:** One PR, three `feat(03-0N):` commits.

### Claude's Discretion

- Exact wording of warning strings (D-34 mismatch, D-42 mode-change prompt, D-39 hook collision warning).
- Exact filename of shared library (`scripts/lib/install.sh` preferred, matches Phase 2 pattern).
- Exact `jq` expression syntax for D-44.
- TK-owned hook identification mechanism for D-38 (marker field, prefix convention, or content-fingerprint heuristic).
- Whether `init-local.sh` reuses the mode-selection prompt verbatim or has a simpler flow.
- Whether `scripts/lib/` dir is created in Phase 3 or `scripts/install-lib.sh` at root (`lib/` preferred).

### Deferred Ideas (OUT OF SCOPE)

- Full update-flow drift detection (Phase 4 UPDATE-01..06).
- Migration script for v3.x users (Phase 5).
- Backup pruning (v4.1).
- Timeout auto-accept for menu.
- Configurable TK-owned subtree via `manifest.json`.
- Styled diff for dry-run (v4.1).

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DETECT-05 | Both `init-claude.sh` and `update-claude.sh` source `detect.sh` from canonical path; remote callers download to `mktemp` | Insertion points identified in both scripts; D-03/D-04 patterns confirmed in detect.sh |
| MODE-01 | `init-claude.sh` recognizes 4 modes: `standalone`, `complement-sp`, `complement-gsd`, `complement-full` | Arg parsing location in init-claude.sh:24-44 identified; new `--mode` case needed |
| MODE-02 | At install time, reads detection results and recommends matching mode | detect.sh exports `HAS_SP`/`HAS_GSD`; recommendation logic is a simple 2-flag if/elif |
| MODE-03 | User can override via interactive prompt or `--mode <name>` CLI flag | `read -r -p "..." < /dev/tty 2>/dev/null` at :84 is the template |
| MODE-04 | Skip-list computed by `jq` filtering `manifest.json` `conflicts_with` | Exact working expression verified against current manifest; 7 SP conflicts confirmed |
| MODE-05 | `init-local.sh` respects same mode + skip-list | `init-local.sh` currently has no mode; needs same arg parsing + lib/install.sh sourcing |
| MODE-06 | `--dry-run` prints per-file `[INSTALL]`/`[SKIP — ...]` without filesystem writes | Current `--dry-run` in init-local.sh exits early (line 128-144); init-claude.sh has inline DRY_RUN checks; both need grouped jq-driven output |
| SAFETY-01 | `setup-security.sh` reads settings via `json.load`, merges only owned keys, writes via `json.dump`+atomic `mv` | Existing python3 block at :202-237 is the template; `os.replace` already used |
| SAFETY-02 | Never overwrites hooks from other plugins — merges per-key, preserving foreign entries | Current code at :228-230 REPLACES all Bash entries — this is the bug to fix |
| SAFETY-03 | Backup with timestamp before every mutation; restore from backup on failure | `cp ... .bak.$(date +%s)` pattern confirmed; restoration pattern at :252-254 is template |
| SAFETY-04 | Documented invariant: TK never edits keys outside its own subtree | TK-owned hook identification mechanism needs decision (see Open Questions) |

</phase_requirements>

---

## Domain Overview

Phase 3 wires three Phase 2 primitives (`detect.sh`, `lib/state.sh`, manifest v2) into the user-facing install flow across `init-claude.sh`, `init-local.sh`, and `update-claude.sh`. The end-to-end flow for a fresh install is: (1) parse CLI flags including `--mode`/`--force`/`--force-mode-change`/`--dry-run`, (2) source `detect.sh` to populate `HAS_SP`/`HAS_GSD`, (3) check `~/.claude/toolkit-install.json` for re-run delegation (D-41), (4) recommend a mode and optionally prompt the user, (5) call `compute_skip_set` from the new `scripts/lib/install.sh` to produce a `jq`-derived skip-list from `manifest.json`, (6) either print the `--dry-run` preview grouped by manifest bucket and exit 0, or proceed with filtered file installation, (7) write install state via `state.sh write_state`, and (8) release the lock. `setup-security.sh` is independently refactored to replace its current destructive hook-replacement logic with an append-both, TK-owned-subtree-strict python3 atomic merge. A new `scripts/lib/install.sh` sourced library holds all shared logic so `init-claude.sh`, `init-local.sh`, and Phase 4's `update-claude.sh` share one implementation.

---

## Best Practices

### Detection wiring (DETECT-05)

Both init scripts must source `detect.sh` after argument parsing and before the first filesystem write. The insertion point in `init-claude.sh` is after line 46 (`SKIP_COUNCIL` default) and before line 106 (framework selection). For the remote caller, the `mktemp`+`trap` pattern prevents temp-file leaks even on `set -e` exit paths.

Key requirement: the `trap 'rm -f "$DETECT_TMP"' EXIT` must be registered before the `curl` download, so that a download failure still cleans up the empty temp file.

`update-claude.sh` gets only the source call plus variable exposure (D-31). No branching on those variables in Phase 3.

### Mode selection UX (MODE-02, MODE-03)

The recommendation function is a pure mapping from `HAS_SP`/`HAS_GSD` booleans:

```bash
recommend_mode() {
    if [[ "$HAS_SP" == "true" && "$HAS_GSD" == "true" ]]; then echo "complement-full"
    elif [[ "$HAS_SP" == "true" ]]; then echo "complement-sp"
    elif [[ "$HAS_GSD" == "true" ]]; then echo "complement-gsd"
    else echo "standalone"
    fi
}
```

The interactive prompt (D-32) must follow the `< /dev/tty 2>/dev/null` invariant. Under `curl | bash` where `/dev/tty` is unavailable, the `read` silently fails and the default (recommended mode) is used — correct behavior.

For `--mode` vs recommendation mismatch (D-34): print the warning to stderr, not stdout, so `--dry-run | grep` pipelines do not consume it.

The mode-change prompt (D-42) must fail-closed when `/dev/tty` is unavailable (`read` fails → `configure` stays empty → treated as `n` → exit 0). This is the same as the existing Council setup prompt pattern at `init-claude.sh:430-434`.

### Dry-run output format (MODE-06)

The grouped output requires two passes over the `jq` output: one per bucket, one for totals. The cleanest approach is to emit jq JSON with `{bucket, path, skip, reason}` objects, then have the shell formatter iterate over them. Using `jq --argjson` with an array of skip-set strings avoids passing shell variables into jq unsafely.

```bash
# In lib/install.sh: print_dry_run_grouped
print_dry_run_grouped() {
    local manifest_path="$1" mode="$2" install_count=0 skip_count=0
    local skip_json
    skip_json=$(compute_skip_set "$mode")  # returns JSON array string

    # jq produces one JSON object per line
    while IFS= read -r line; do
        local bucket path skip
        bucket=$(printf '%s' "$line" | jq -r '.bucket')
        path=$(printf '%s' "$line" | jq -r '.path')
        skip=$(printf '%s' "$line" | jq -r '.skip')
        # ... print colored line, accumulate counters
    done < <(jq -c --argjson skip "$skip_json" '
        .files | to_entries[] |
        .key as $b |
        .value[] |
        {bucket: $b, path: .path,
         skip: ((.conflicts_with // []) as $cw | ($skip | any(. as $s | $cw | contains([$s])))),
         reason: ((.conflicts_with // []) | join(","))}
    ' "$manifest_path")
}
```

Note: the ANSI disable check (`[ -t 1 ]`) should happen at the start of `print_dry_run_grouped`, setting local `_INSTALL_COLOR`/`_SKIP_COLOR` to empty strings when stdout is not a terminal.

### Safe settings.json merge (SAFETY-01..04)

The existing python3 block at `setup-security.sh:201-255` contains the correct scaffolding (`json.load`, `tempfile.mkstemp`, `os.replace`) but has one critical bug for SAFETY-02: line 228-230 **replaces** all `Bash` matcher entries rather than appending. The refactor must change that to the append-both policy (D-39).

The TK-owned hook identification mechanism (left to planner per D-38 discretion) — see Open Questions below for the research finding on recommended approach.

The backup (D-40) must happen exactly once per install run. The cleanest place is a `merge_settings_begin()` shell function in `lib/install.sh` that is called before the first python3 invocation and sets a global `SETTINGS_BACKUP_PATH`. Subsequent calls within the same run skip the backup (check `[ -n "${SETTINGS_BACKUP_PATH:-}" ]`). On failure, restore via `cp "$SETTINGS_BACKUP_PATH" "$SETTINGS_JSON"` before exiting.

### Re-run and mode change (D-41, D-42)

The re-run check in `init-claude.sh` fires after `detect.sh` is sourced but before the mode prompt. State file path: `$HOME/.claude/toolkit-install.json` (from `scripts/lib/state.sh`'s `STATE_FILE`).

```bash
if [[ -f "$HOME/.claude/toolkit-install.json" ]] && [[ "${FORCE:-false}" != "true" ]]; then
    echo "Install already present at ~/.claude/. Use 'update-claude.sh' to refresh or 'init-claude.sh --force' to reinstall."
    exit 0
fi
```

`--force` must be parsed BEFORE this check. The argument parser needs three new cases: `--mode`, `--force`, `--force-mode-change`.

### init-local.sh parity (MODE-05)

`init-local.sh` sources `detect.sh` from the script's own directory (D-04 pattern: `source "$(dirname "$0")/detect.sh"`). The per-project state file is `.claude/toolkit-install.json` — a relative path, not `$HOME/.claude/...`. The `lib/install.sh` shared library must be sourced from `$(dirname "$0")/lib/install.sh`. The re-run check uses the relative path.

Currently, `init-local.sh`'s `--dry-run` branch (lines 128-144) exits immediately with a static text summary — this must be replaced with the `print_dry_run_grouped` call.

---

## Code Patterns To Mirror

### Pattern 1: Sourced library invariants (`scripts/lib/state.sh:1-11`)

```bash
#!/bin/bash
# IMPORTANT: No errexit/pipefail — sourced libraries must not alter caller error mode.
```

`scripts/lib/install.sh` MUST follow this exact invariant. No `set -euo pipefail` inside the library. Functions silently inherit the caller's error mode. This is different from executable scripts.

### Pattern 2: Interactive read with `/dev/tty` guard (`init-claude.sh:84`, `:430`)

```bash
if ! read -r -p "  Enter choice [1-8] (default: 1): " choice < /dev/tty 2>/dev/null; then
    choice="1"
fi
choice="${choice:-1}"
```

The `if !` form is critical: it handles both `/dev/tty` absence (read fails) AND the user pressing Enter with no input (returns 0 but `choice` is empty, covered by `:-1`).

### Pattern 3: python3 atomic JSON write (`setup-security.sh:238-247`)

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

This is the correct pattern: `mkstemp` on the same filesystem as the target (same `dir=`), then `os.replace` (atomic on POSIX). The `\n` trailing newline makes the file git-friendly.

### Pattern 4: Single-backup sentinel (`install-statusline.sh:104`)

```bash
cp "$file" "$file.bak.$(date +%s)"
```

For Phase 3's ONE-backup-per-run requirement (D-40), wrap this with a guard:

```bash
# In lib/install.sh
backup_settings_once() {
    local settings_path="$1"
    [[ -n "${TK_SETTINGS_BACKUP:-}" ]] && return 0  # already done this run
    [[ ! -f "$settings_path" ]] && return 0
    TK_SETTINGS_BACKUP="${settings_path}.bak.$(date +%s)"
    cp "$settings_path" "$TK_SETTINGS_BACKUP"
}
```

### Pattern 5: Verified jq skip-list expression

Tested against `manifest.json` (jq 1.7.1-apple, also compatible with jq 1.6+):

```bash
# Returns JSON array of paths to SKIP
skip_list=$(jq --argjson skip "$skip_json" \
  '[.files | to_entries[] | .value[] |
    select((.conflicts_with // []) as $cw |
           ($skip | any(. as $s | $cw | contains([$s])))) |
    .path]' \
  "$manifest_path")
```

Where `$skip_json` is one of:
- `standalone`: `'[]'` (nothing skipped)
- `complement-sp`: `'["superpowers"]'`
- `complement-gsd`: `'["get-shit-done"]'`
- `complement-full`: `'["superpowers","get-shit-done"]'`

Confirmed results for `complement-sp` against current manifest:
`["agents/code-reviewer.md","commands/debug.md","commands/plan.md","commands/tdd.md","commands/verify.md","commands/worktree.md","skills/debugging/SKILL.md"]` — 7 entries, all correct.

Empty `conflicts_with` (absent key) is treated as `[]` via `// []` — never skipped, correct.

### Pattern 6: Argument parser shape for new flags

The current `init-claude.sh` catch-all at line 38-43 exits on unknown args with an error message listing frameworks. The new flags must be added BEFORE the `*)` catch-all, as new `--mode`, `--force`, `--force-mode-change` cases in the while/case block:

```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --no-council) SKIP_COUNCIL=true; shift ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --force) FORCE=true; shift ;;
        --force-mode-change) FORCE_MODE_CHANGE=true; shift ;;
        laravel|nextjs|nodejs|python|go|rails|base)
            FRAMEWORK="$1"; shift ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            exit 1
            ;;
    esac
done
```

`--mode` requires `shift 2` (consumes both flag and value). Add validation after parsing:

```bash
VALID_MODES=("standalone" "complement-sp" "complement-gsd" "complement-full")
if [[ -n "${MODE:-}" ]]; then
    valid=false
    for m in "${VALID_MODES[@]}"; do [[ "$m" == "$MODE" ]] && valid=true; done
    if [[ "$valid" != "true" ]]; then
        echo -e "${RED}Invalid --mode value: $MODE${NC}"
        echo "Valid modes: standalone, complement-sp, complement-gsd, complement-full"
        exit 1
    fi
fi
```

---

## TK-Owned Hook Identification — Research Finding

**Question (D-38 discretion):** How does the python3 merge function identify which `PreToolUse` hook entries TK authored, so it can update-in-place without touching SP/GSD entries?

**Three options investigated:**

**Option A: `_tk_owned: true` JSON marker field**
Add `"_tk_owned": true` to the hook entry object when TK writes it. The merge reads `entry.get("_tk_owned", False)` to identify TK entries. Survives python3 round-trips (json.load/dump preserves unknown keys). Claude Code ignores unknown keys in hook entries (the schema is open — only `matcher`, `hooks`, `type`, `command` are consumed). This is the most reliable approach.

Concern: if Claude Code validates hook entries strictly in a future version, unknown keys may cause warnings. Mitigation: use a comment-like key `"#_tk"` — Claude Code ignores it, python3 preserves it, visually obvious in the JSON file.

**Option B: Matcher prefix convention (e.g., `matcher: "TK_Bash"`)**
Would require Claude Code to recognize `TK_Bash` as a valid matcher (or sub-matcher) for Bash tool calls. This does NOT work — `matcher` is a regex/glob matched against the tool name, so `TK_Bash` would never match any tool.

**Option C: Content fingerprint (hash of command string)**
TK maintains a side file listing known TK command hashes. Fragile — changes if the hook script is updated, requires the side file to stay in sync, breaks after manual user edits.

**Recommendation:** Option A — `_tk_owned: true` marker field. It is the only approach that survives: python3 round-trips, hook path changes (user moving `pre-bash.sh`), and future re-installs without losing the identity. The field is invisible to Claude Code's hook execution.

**Implementation:** When TK writes a hook entry, include `"_tk_owned": true` in the dict. When merging, filter `PreToolUse` entries into two buckets:

```python
tk_entries   = [e for e in existing if e.get('_tk_owned')]
foreign_entries = [e for e in existing if not e.get('_tk_owned')]
# TK's new entry replaces the old TK entry (update in place)
# Foreign entries are never touched
new_tk_entry = {"matcher": "Bash", "hooks": [...], "_tk_owned": True}
config['hooks']['PreToolUse'] = foreign_entries + [new_tk_entry]
```

This satisfies SAFETY-02 (never overwrite foreign hooks) and SAFETY-04 (TK only writes its own entries). On first install (no existing TK entry), `tk_entries` is empty and the new entry is appended to `foreign_entries`. On re-install, the old TK entry is replaced. Foreign entries (SP, GSD) are never modified. [VERIFIED: inspected actual `~/.claude/settings.json` — SP has `matcher: "Bash"` with `pre-bash.sh` command, GSD has `matcher: "Bash"` with `gsd-validate-commands.sh` — both must be preserved unchanged]

---

## Pitfalls

### 1. BSD vs GNU `date` for backup timestamps

Both `date +%s` and `date -u +%s` work on macOS BSD and GNU Linux. **Verified on macOS:** `date +%s` produces a unix timestamp. The `install-statusline.sh:104` pattern (`cp "$file" "$file.bak.$(date +%s)"`) is safe to copy verbatim.

**Mitigation:** Use `$(date +%s)` (no `-u` needed for a monotonic unix timestamp used only as a suffix).

### 2. `jq` version skew — `any/2` vs `any/1`

`any(condition)` (1-argument form) is available in jq 1.5+. The `any(generator; condition)` 2-argument form is jq 1.6+. **Verified:** jq 1.7.1 on this machine. However, the safer expression using `any(. as $s | $cw | contains([$s]))` (generator form) works on jq 1.6+. jq 1.5 users would see a parse error.

**Mitigation:** The confirmed working expression uses `any(. as $s | ...)` which is the generator form requiring jq 1.6+. Add a jq version check in `compute_skip_set`:

```bash
compute_skip_set() {
    local mode="$1"
    if ! jq --version &>/dev/null; then
        echo "${RED}ERROR: jq not found — required for install mode filtering${NC}" >&2
        return 1
    fi
    # jq is available; proceed
}
```

Since the project already uses `jq` in `install-statusline.sh` (existing dependency), this is not a new constraint.

### 3. Settings.json `PreToolUse` current destructive pattern

`setup-security.sh:228-230` **currently does**:

```python
config['hooks']['PreToolUse'] = [
    entry for entry in config['hooks']['PreToolUse']
    if entry.get('matcher') != 'Bash'
]
```

This removes ALL `Bash` matcher entries from other plugins (SP's `pre-bash.sh`, GSD's `gsd-validate-commands.sh`). This is the exact bug SAFETY-02 fixes. The refactor must NOT preserve this logic.

**Mitigation:** Replace the entire `PreToolUse` section with the `_tk_owned` bucket approach. The new code never touches entries where `_tk_owned` is falsy/absent.

### 4. Argument parsing: `--mode` requires `shift 2`, not `shift 1`

The current arg parser uses `shift` (consumes current arg). `--mode standalone` requires `shift 2`. If the user passes `--mode` without a value, `$2` will be the next positional arg (e.g., a framework name), silently corrupting FRAMEWORK. Add a guard:

```bash
--mode)
    if [[ -z "${2:-}" ]]; then
        echo -e "${RED}--mode requires a value${NC}"; exit 1
    fi
    MODE="$2"; shift 2 ;;
```

### 5. `lib/install.sh` zero-stdout invariant during source

If `lib/install.sh` prints anything during source (e.g., a `echo "loaded"` debug line), that output will appear in the middle of the calling script's output. **The Phase 2 precedent** (`lib/state.sh`) has zero stdout on source — verified by reading the file. `lib/install.sh` must follow the same rule. Only function definitions and variable assignments at source time.

### 6. `[ -t 1 ]` vs `tput colors` for color detection

Both work on this machine. `[ -t 1 ]` is POSIX-portable and requires no external dependency. `tput colors` requires `tput` which is not guaranteed on minimal CI images. **Recommendation:** Use `[ -t 1 ]`. The `print_dry_run_grouped` function should set empty strings for color variables when `! [ -t 1 ]`.

### 7. Re-run state check path difference: global vs per-project

`init-claude.sh` checks `$HOME/.claude/toolkit-install.json` (global). `init-local.sh` checks `.claude/toolkit-install.json` (relative to CWD). These are different files — the shared library must accept the state file path as a parameter rather than hardcoding either.

Actually, `lib/state.sh` exports `STATE_FILE="$HOME/.claude/toolkit-install.json"`. For `init-local.sh`, the per-project path `.claude/toolkit-install.json` is different. The install flow must override `STATE_FILE` before calling `write_state`:

```bash
# In init-local.sh:
STATE_FILE=".claude/toolkit-install.json"
# Then source state.sh which will use this path
```

Wait — `lib/state.sh` sets `STATE_FILE` at source time. If `init-local.sh` sets `STATE_FILE` AFTER sourcing, it will override. If BEFORE, `state.sh` overwrites it. **Mitigation:** The init-local.sh pattern must: source state.sh, then reassign `STATE_FILE=".claude/toolkit-install.json"`. Because `state.sh` sets it at source time, reassigning after source works correctly (functions close over the variable at call time, not definition time in bash).

Verify: `write_state` in `lib/state.sh` uses `"$STATE_FILE"` at call time — confirmed (line 47, 102). So reassigning `STATE_FILE` after source is safe.

### 8. `manifest_version` vs `manifest.version` field name mismatch

The CONTEXT.md and Phase 2 decisions refer to `manifest.version: 2`. The actual `manifest.json` uses the key `manifest_version` (not `version`). The `version` key holds the product version (`"3.0.0"`). Any script reading the manifest schema version must use `.manifest_version`, not `.version`.

**Verified:** `jq '.manifest_version' manifest.json` returns `2`. The Phase 2 init D-01 check must use this key:

```bash
manifest_ver=$(jq -r '.manifest_version' "$MANIFEST_FILE")
if [[ "$manifest_ver" != "2" ]]; then
    echo "ERROR: manifest.json is v${manifest_ver}; expected v2" >&2; exit 1
fi
```

### 9. `--force-mode-change` flag name

This flag needs to be valid bash identifier when stored in a variable (`FORCE_MODE_CHANGE`). The flag name `--force-mode-change` is fine as a CLI flag — bash parses it as a string in the case statement.

### 10. `compute_skip_set` stdout vs return value

Shell functions cannot return strings via `return` (only integer exit codes). The standard idiom is `echo` to stdout and capture with `$(compute_skip_set "$mode")`. This means `compute_skip_set` may NOT print any diagnostic messages to stdout — all diagnostics go to stderr. This is consistent with the lib/state.sh zero-stdout-on-source rule but applies to function execution too.

---

## Open Questions

1. **`lib/state.sh` `STATE_FILE` override for init-local.sh**

   - What we know: `STATE_FILE` is set at source time in `lib/state.sh`. Reassigning after source works in bash (functions use current variable value at call time).
   - What's unclear: Should `lib/install.sh` or `lib/state.sh` support an explicit `STATE_FILE` parameter to `write_state`? Or is the global-reassignment approach acceptable?
   - Recommendation: Keep the reassignment approach (lowest surface area). Document in `lib/install.sh` as a usage note for `init-local.sh`.

2. **`manifest_version` key vs CONTEXT.md reference to `manifest.version`**

   - What we know: The actual field is `manifest_version` in `manifest.json`. CONTEXT.md D-01 says "manifest.version: 2".
   - What's unclear: Should D-44's version check use `.manifest_version` or `.version`?
   - Recommendation: Use `.manifest_version` — this is what the file contains. The CONTEXT.md reference is a description, not a jq path.

3. **`--dry-run` + `--mode` interaction: which wins for recommendation display?**

   - What we know: D-35 says `--dry-run` prints grouped output and exits 0. D-33 says `--mode` bypasses interactive prompt.
   - What's unclear: When `--dry-run --mode complement-sp` is passed, should the script still print the detection banner ("SP detected...") or skip straight to the file list?
   - Recommendation: Print the detection banner (it's informative in dry-run context), then the file list. No interactive prompt when `--mode` is given.

---

## Validation Architecture

### Test harness design

Tests 6/7/8 follow the same structure as `test-detect.sh` and `test-state.sh`: scratch `HOME` via `SCRATCH=$(mktemp -d)`, `trap 'rm -rf "$SCRATCH"' EXIT`, pass/fail counters, exit 1 if any fail.

### Test 6: `test-modes.sh` — skip-set correctness (MODE-04)

Source `lib/install.sh` against a fixture `manifest.json` copy in SCRATCH. Assert each of 4 modes produces the exact expected skip-list:

| Mode | Expected skip count | Expected paths |
|------|--------------------|-|
| `standalone` | 0 | `[]` |
| `complement-sp` | 7 | `agents/code-reviewer.md`, `commands/debug.md`, `commands/plan.md`, `commands/tdd.md`, `commands/verify.md`, `commands/worktree.md`, `skills/debugging/SKILL.md` |
| `complement-gsd` | 0 | `[]` (current manifest has no `get-shit-done` conflicts) |
| `complement-full` | 7 | same as complement-sp |

The test can assert via: `result=$(compute_skip_set "complement-sp" "$SCRATCH/manifest.json")` then `jq length <<< "$result"`.

**Requirement mapping:** MODE-04 (skip-list from manifest). Covers success criteria 3 ("does not install any file whose conflicts_with includes superpowers").

### Test 7: `test-dry-run.sh` — output format + zero filesystem touches (MODE-06)

Approach:

1. Set up SCRATCH with a synthetic `manifest.json` and dummy files.
2. Run `init-local.sh --dry-run --mode complement-sp` against SCRATCH as CWD.
3. Capture stdout.
4. Assert: output contains `[INSTALL]` lines, `[SKIP` lines, totals footer, no ANSI when piped.
5. Assert: no files were created under `SCRATCH/.claude/` (filesystem invariance).

```bash
# Filesystem invariance assertion
snapshot_before=$(find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5sum || echo "empty")
run_dry_run ...
snapshot_after=$(find "$SCRATCH/.claude" -type f 2>/dev/null | sort | md5sum || echo "empty")
[ "$snapshot_before" = "$snapshot_after" ] || fail "dry-run wrote files"
```

**Requirement mapping:** MODE-06. Covers success criteria 2 ("prints per-file [INSTALL] / [SKIP] list and exits 0 without touching the filesystem").

### Test 8: `test-safe-merge.sh` — python3 merge round-trip (SAFETY-01..04)

Three sub-scenarios:

**8a: Foreign keys preserved**
Create a `settings.json` with known foreign `hooks.PreToolUse` entries (simulating SP/GSD hooks, no `_tk_owned` marker). Run the TK merge function. Assert the foreign entries are unchanged after merge. Assert TK's own entry was added.

**8b: Backup created before mutation**
Assert `settings.json.bak.<ts>` exists immediately after merge. Assert it is a valid JSON file equal to the pre-merge content.

**8c: Restore on simulated failure**
Write a known `settings.json`. Patch the python3 merge script to raise an exception mid-write. Assert the backup is restored and the original content is intact.

Simulating failure: use a temp dir on a different filesystem OR patch the function to `raise RuntimeError("injected failure")` via a `INJECT_FAILURE` env var.

```python
# In the merge block (for testing only):
import os
if os.environ.get('TK_TEST_INJECT_FAILURE'):
    raise RuntimeError("injected failure for test")
```

**Requirement mapping:** SAFETY-01 (atomic merge), SAFETY-02 (foreign hook preservation), SAFETY-03 (backup + restore), SAFETY-04 (TK subtree invariant).

---

## Recommended Plan Split

D-46 specifies three clusters. Research confirms this split is correct:

### Plan 03-01: DETECT-05 wiring + lib/install.sh skeleton

**Scope:** (a) Add `source detect.sh` to `init-claude.sh` (remote mktemp pattern) and `init-local.sh` (local path pattern). (b) Add `source detect.sh` stub to `update-claude.sh` (D-31 — variables exposed, no branching). (c) Create `scripts/lib/install.sh` with: mode constants `MODES`, `compute_skip_set()`, `recommend_mode()`, `backup_settings_once()`, and `print_dry_run_grouped()` stubs (stubs that print TODO or echo the args, so Plan 03-02 fills them in). (d) Add manifest version guard to both init scripts. (e) Wire `lib/install.sh` into `make shellcheck` (all `.sh` files).

**Why first:** All of 03-02 and 03-03 depend on both detect.sh being sourced AND the lib/install.sh skeleton existing. Detection wiring is a zero-behavior-change change in Phase 3 context.

**Risk:** Low. No user-visible behavior change. detect.sh is already tested via Test 4.

### Plan 03-02: MODE-01..06 — mode selection, skip-list, dry-run, init-local parity

**Scope:** (a) Add `--mode`, `--force`, `--force-mode-change` flag parsing to `init-claude.sh`. (b) Implement `compute_skip_set()` and `recommend_mode()` in `lib/install.sh`. (c) Interactive mode prompt in `init-claude.sh` (D-32) and mode-change prompt (D-42). (d) Skip-list filter in install loop — replace the static `FILES=()` array population with manifest-driven jq filter. (e) `--dry-run` grouped output via `print_dry_run_grouped()`. (f) Init-local.sh parity: add same flag parsing, source lib/install.sh, replace static dry-run exit with grouped output, per-project state at `.claude/toolkit-install.json`. (g) State write via `state.sh write_state` at end of install (Mode-01 success: state file records mode). (h) Add Tests 6 and 7.

**Why second:** Depends on lib/install.sh skeleton from 03-01. The MODE cluster is the largest chunk and changes the most user-visible behavior.

**Risk:** Medium. The transition from static `FILES=()` array to manifest-driven install loop is a significant refactor of `init-claude.sh:128-207`. Must preserve framework-specific file additions (laravel-expert.md etc.) — those are NOT in the manifest's `files.*` section (they're in `templates`). The skip-list only applies to `files.*` entries; framework-specific template files are always installed.

**Note for planner:** The `FILES=()` array in `init-claude.sh` includes files from both `files.*` (commands, agents, skills, rules) and `templates/$FRAMEWORK/` (CLAUDE.md, settings.json, prompts). The skip-list only applies to `files.*` entries. Framework-specific template files (CLAUDE.md, settings.json) are never in `conflicts_with` — always install.

### Plan 03-03: SAFETY-01..04 — settings.json safe merge

**Scope:** (a) Refactor `setup-security.sh:194-287` (Step 3: hook configuration) to use `backup_settings_once()` from lib/install.sh and the new append-both `_tk_owned`-aware python3 merge block. (b) Refactor `setup-security.sh:304-416` (Step 4: plugin merge) similarly — already correct in spirit but should use the shared backup sentinel. (c) Add `_tk_owned: true` to all TK-authored hook entries on write. (d) Add round-trip test to verify foreign keys preserved. (e) Add Test 8.

**Why third:** Depends only on `backup_settings_once()` from lib/install.sh (03-01). Can run in parallel with 03-02 if needed, but sequential is safer since 03-02 may discover issues with lib/install.sh that affect 03-03.

**Risk:** Low-Medium. The python3 block is self-contained and well-tested by Test 8. The main risk is the `_tk_owned` marker approach working correctly on re-install (existing TK entry replaced, not duplicated). Test 8a covers this.

---

## Validation Architecture (Nyquist)

> `workflow.nyquist_validation` is not explicitly `false` in `.planning/config.json` (file absent) — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash inline harness (no bats — TEST-01 deferred to v4.1) |
| Config file | None (scripts self-contained) |
| Quick run command | `bash scripts/tests/test-modes.sh && bash scripts/tests/test-dry-run.sh` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DETECT-05 | detect.sh sourced in init-claude.sh and update-claude.sh | Integration | `make test` (Tests 1-3 verify init works; Test 4 covers detect.sh) | Partial — init tests exist; update not covered |
| MODE-01 | 4 modes recognized | Unit | `bash scripts/tests/test-modes.sh` | Wave 0 |
| MODE-02 | Recommendation logic | Unit | `bash scripts/tests/test-modes.sh` (case: recommendation output) | Wave 0 |
| MODE-03 | `--mode` flag bypasses prompt | Integration | `bash scripts/tests/test-modes.sh` (non-interactive invocation) | Wave 0 |
| MODE-04 | Skip-list from manifest | Unit | `bash scripts/tests/test-modes.sh` (skip-list assertions) | Wave 0 |
| MODE-05 | init-local.sh parity | Integration | `make test` (extend Tests 1-3 to verify skip-list applied) | Partial |
| MODE-06 | dry-run format + zero writes | Integration | `bash scripts/tests/test-dry-run.sh` | Wave 0 |
| SAFETY-01 | Atomic merge | Unit | `bash scripts/tests/test-safe-merge.sh` (sub-scenario 8c) | Wave 0 |
| SAFETY-02 | Foreign hook preservation | Unit | `bash scripts/tests/test-safe-merge.sh` (sub-scenario 8a) | Wave 0 |
| SAFETY-03 | Backup + restore | Unit | `bash scripts/tests/test-safe-merge.sh` (sub-scenario 8b, 8c) | Wave 0 |
| SAFETY-04 | TK subtree invariant | Unit | `bash scripts/tests/test-safe-merge.sh` (round-trip foreign keys) | Wave 0 |

### Wave 0 Gaps

- [ ] `scripts/tests/test-modes.sh` — covers MODE-01..04, DETECT-05 wiring
- [ ] `scripts/tests/test-dry-run.sh` — covers MODE-06
- [ ] `scripts/tests/test-safe-merge.sh` — covers SAFETY-01..04
- [ ] Extend existing Tests 1-3 in `Makefile` to assert skip-list applied (MODE-05)

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `jq` | MODE-04 skip-list | Yes | 1.7.1-apple | No — required by existing statusline scripts |
| `python3` | SAFETY-01..04 JSON merge | Yes | 3.14.4 | No — required by existing setup-security.sh |
| `bash` | All scripts | Yes | (BSD Bash 3.2+ on macOS) | None needed |
| `curl` | remote detect.sh download (D-30) | Yes | (standard macOS curl) | None needed |
| `mktemp` | temp file creation | Yes | BSD mktemp on macOS | None needed |
| `date` (unix ts) | backup suffix | Yes | BSD date supports `+%s` | None needed |

No missing dependencies with blocking implications.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | n/a (install script, no auth) |
| V3 Session Management | No | n/a |
| V4 Access Control | No | n/a |
| V5 Input Validation | Yes | Mode value validated against allowlist; `--mode` value not interpolated into SQL/shell commands |
| V6 Cryptography | No | No crypto in install flow |

### Known Threat Patterns for install scripts

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shell injection via `--mode` value | Tampering | Validate against `VALID_MODES` allowlist before use; never interpolate into unquoted shell expansion |
| JSON injection via API keys (BUG-03, already fixed) | Tampering | python3 `json.dumps()` for all string values in JSON output |
| Path traversal via user-supplied paths | Tampering | `STATE_FILE` and `BACKUP_PATH` are derived from `$HOME` and `CWD` — not user-supplied |
| Symlink attack on backup file | Elevation | `cp` to a new timestamped path — not replacing existing file; low risk |
| Race condition between backup and concurrent Claude Code writes | Tampering | `cp` is not atomic for reads, but settings.json is small and writes are rare; `os.replace` atomicity covers the write path |

---

## Sources

### Primary (HIGH confidence)

- `scripts/detect.sh` — Phase 2 deliverable, inspected directly [VERIFIED: codebase]
- `scripts/lib/state.sh` — Phase 2 deliverable, inspected directly [VERIFIED: codebase]
- `scripts/init-claude.sh` — existing, inspected lines 1-668 [VERIFIED: codebase]
- `scripts/init-local.sh` — existing, inspected lines 1-299 [VERIFIED: codebase]
- `scripts/update-claude.sh` — existing, inspected lines 1-302 [VERIFIED: codebase]
- `scripts/setup-security.sh` — existing, inspected lines 1-536 [VERIFIED: codebase]
- `manifest.json` — inspected, field `manifest_version: 2` confirmed [VERIFIED: codebase]
- `scripts/tests/test-detect.sh`, `test-state.sh` — test harness patterns confirmed [VERIFIED: codebase]
- `$HOME/.claude/settings.json` — hook schema confirmed, SP/GSD entries identified [VERIFIED: live machine]
- jq expression — tested against real `manifest.json` with jq 1.7.1 [VERIFIED: Bash tool]

### Secondary (MEDIUM confidence)

- Phase 2 CONTEXT.md decisions D-03/D-04/D-12/D-18/D-19/D-20/D-22 [VERIFIED: planning docs]
- Phase 3 CONTEXT.md decisions D-30..D-48 [VERIFIED: planning docs]

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all tools verified on machine (jq 1.7.1, python3 3.14.4, bash, curl)
- Architecture: HIGH — all code read directly, insertion points confirmed with line numbers
- Pitfalls: HIGH — 8 of 10 pitfalls verified empirically (jq expression tested, settings.json inspected, argument parser read)
- Test design: HIGH — follows existing test-detect.sh/test-state.sh patterns exactly

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable toolchain — 30 days)
