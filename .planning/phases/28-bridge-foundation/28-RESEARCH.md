# Phase 28: Bridge Foundation — Research

**Researched:** 2026-04-29
**Domain:** Bash lib authoring — detection probes, file copy with banner, atomic JSON state mutation
**Confidence:** HIGH (pure codebase investigation; no web lookups needed)

---

## Summary

Phase 28 is entirely additive: two functions appended to an existing lib (`detect2.sh`) and one new
sourced lib (`bridges.sh`). Every pattern it needs already exists in the v4.4–v4.6 codebase. The
research below maps each REQ-ID to the exact file:line anchors the planner must reference, flags one
important discrepancy between the CONTEXT.md's function-name expectations and the actual state.sh
API, and proposes a 3-plan split that keeps each plan shippable in isolation.

**Primary recommendation:** Write `bridges.sh` as a standalone sourced lib that calls `sha256_file`
(already in `state.sh:32`), `acquire_lock` / `release_lock` / `write_state` lookalikes via a
**new Python helper inside bridges.sh** (see §3 — the state.sh `write_state` function rebuilds the
entire JSON document and is not surgically extensible for a new top-level key). The bridges array
mutation must be its own atomic python3 tempfile+os.replace block, mirroring `write_state`'s pattern
but scoped to patching `.bridges[]` only.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Detection probe pattern: identical to v4.6 Phase 24 `is_*_installed` siblings — single-purpose
  function returning 0/1, no 3-state.
- Primary signal: `command -v gemini` / `command -v codex` (binary on PATH).
- Soft cross-check: `[ -d ~/.gemini/ ]` / `[ -d ~/.codex/ ]` — confirmation only; CLI-PATH wins.
- Fail-soft: absent CLI returns 1 (not-installed). No errors, no warnings.
- Registration: add probes to existing `detect2.sh` under the `is_*_installed` block.
  Alphabetize: codex before gemini (lex order).
- New library: `scripts/lib/bridges.sh` — separate file, NOT extending an existing lib.
- API shape: `bridge_create_project <target> [project_root]` and `bridge_create_global <target>`.
  Returns 0 (success), 1 (missing source), 2 (write/mkdir blocked).
  `project_root` defaults to `$PWD` if omitted.
- Source resolution: project = `<project_root>/CLAUDE.md`, global = `~/.claude/CLAUDE.md`.
  NEVER touch the canonical source.
- Target paths:
  - Gemini project: `<project_root>/GEMINI.md`
  - Gemini global: `~/.gemini/GEMINI.md` (with `mkdir -p ~/.gemini/` first)
  - Codex project: `<project_root>/AGENTS.md`
  - Codex global: `~/.codex/AGENTS.md` (with `mkdir -p ~/.codex/` first)
- `AGENTS.md` for Codex (NOT `CODEX.md`) — locked as top-level domain fact per BRIDGE-DOCS-01.
- Header banner: byte-identical across all bridges (single-quoted heredoc, no variable expansion).
- Header generation: inline `cat <<'EOF'` inside `bridges.sh`. No external template file.
- Idempotency: re-running overwrites with same content if source unchanged.
- State schema: new top-level `bridges[]` array in `~/.claude/toolkit-install.json`. Per-entry:
  `{ "target", "path", "scope", "source_sha256", "bridge_sha256", "user_owned": false }`.
- Atomic update: use existing helpers from `scripts/lib/state.sh`.
- Dedup: if `(target, scope, path)` triple exists, replace in-place (update SHAs).
- `user_owned: false` default — never written `true` in Phase 28.
- `bridges.sh` sources `state.sh`, `dry-run-output.sh`; reads `detect2.sh` probes.
- No `declare -A`, no `read -N`, no `${var^^}`, no `declare -n` — Bash 3.2+ only.
- `set -euo pipefail` at top of `bridges.sh`. `local` for all function-scoped variables.
- Test seam: `TK_BRIDGE_HOME` env var (defaults to `$HOME`) overrides global write target.
  Mirrors `TK_MCP_CONFIG_HOME` from v4.6 Phase 25.

### Claude's Discretion

- Internal helper function names inside `bridges.sh` (e.g., `_bridge_target_path`,
  `_bridge_compute_sha256`, `_bridge_write_state_entry`).
- Exact `sha256sum` invocation form (use `shasum -a 256` fallback for macOS BSD compat).
- Exact `cat <<'EOF'` quoting style for header heredoc.
- Whether `bridge_create_project` is public API or library-internal — public is recommended.

### Deferred Ideas (OUT OF SCOPE)

- Branding substitution layer (BRIDGE-FUT-01)
- Per-CLI tone overlay (BRIDGE-FUT-02)
- Cursor `.cursorrules` support (BRIDGE-FUT-03)
- Aider `CONVENTIONS.md` support (BRIDGE-FUT-04)
- `update-claude.sh --bridges-only` mode (BRIDGE-FUT-05)
- Install-time UX wiring (Phase 30)
- Update sync logic / uninstall removal (Phase 29)
- Distribution / tests / docs (Phase 31)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRIDGE-DET-01 | `is_gemini_installed` — `command -v gemini` returns 0/1, soft cross-check `~/.gemini/` | §2: exact body shape from detect2.sh:70-71 |
| BRIDGE-DET-02 | `is_codex_installed` — `command -v codex`, soft cross-check `~/.codex/` | §2: same pattern; codex alphabetically first |
| BRIDGE-DET-03 | Registered in detect2.sh alongside existing 6 probes; 0/1 contract | §2: alphabetization rule, existing cache pattern |
| BRIDGE-GEN-01 | `bridge_create_project <target>` — reads `CLAUDE.md`, writes `GEMINI.md` / `AGENTS.md` with banner | §5: heredoc form; §4: sha256_file from state.sh |
| BRIDGE-GEN-02 | `bridge_create_global <target>` — reads `~/.claude/CLAUDE.md`, writes under `~/.gemini/` or `~/.codex/` | §6: TK_BRIDGE_HOME seam form |
| BRIDGE-GEN-03 | Auto-generated header banner byte-identical across all bridges | §5: single-quoted heredoc, 4-line HTML comment |
| BRIDGE-GEN-04 | Register bridge in `bridges[]` array in toolkit-install.json; dedup by `(target,scope,path)` | §3: correct API names (write_state, acquire_lock); python3 atomic-patch shape |
</phase_requirements>

---

## 1. Reusable Assets

### 1a. `is_*_installed` probe anchor

**File:** `scripts/lib/detect2.sh:70–71`

```bash
# DET-04: PATH-agnostic RTK probe (covers brew /opt/homebrew/bin AND /usr/local/bin).
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}
```

This is the minimum viable probe body — a single `command -v` call.
The `is_security_installed` (lines 54–67) shows the two-condition variant (CLI + grep) for reference;
bridges use the simpler single-condition form like `is_rtk_installed`.

`detect2_cache` (lines 84–92) shows how probes are cached:

```bash
detect2_cache() {
    IS_SP=0;  is_superpowers_installed && IS_SP=1  || true
    IS_GSD=0; is_gsd_installed         && IS_GSD=1 || true
    IS_TK=0;  is_toolkit_installed     && IS_TK=1  || true
    IS_SEC=0; is_security_installed    && IS_SEC=1 || true
    IS_RTK=0; is_rtk_installed         && IS_RTK=1 || true
    IS_SL=0;  is_statusline_installed  && IS_SL=1  || true
    export IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL
}
```

Two new vars (`IS_GEM`, `IS_COD`) must be added here when the probes are registered.

### 1b. `acquire_lock` / `release_lock` (the actual lock API in state.sh)

**File:** `scripts/lib/state.sh:140–202`

```bash
acquire_lock() {
    mkdir -p "$(dirname "$LOCK_DIR")"
    local retries=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        ...
    done
    echo $$ > "$LOCK_DIR/pid"
    return 0
}

release_lock() {
    [[ -d "$LOCK_DIR" ]] && rm -rf "$LOCK_DIR"
    return 0
}
```

**Critical note:** The CONTEXT.md mentions `_state_lock` and `_atomic_json_write`. These names do NOT
exist in the codebase. The actual public API exposed by `state.sh` (line 5–8) is:
`write_state`, `read_state`, `sha256_file`, `get_mtime`, `iso8601_utc_now`, `acquire_lock`,
`release_lock`. The planner must use `acquire_lock` / `release_lock` (not `_state_lock`), and the
atomic-write pattern is the Python `tempfile.mkstemp + os.replace` block inside `write_state`
(lines 71–137). Bridges cannot call `write_state` directly because it rebuilds the ENTIRE JSON
document (overwriting `installed_files[]`, `mode`, `detected`, etc.) from its fixed argument set.
The bridges array mutation requires its own Python block that patch-merges only `bridges[]`.

### 1c. `sha256_file` — already in state.sh

**File:** `scripts/lib/state.sh:32–53`

```bash
sha256_file() {
    local path="$1"
    [[ -f "$path" ]] || return 1
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
```

`bridges.sh` sources `state.sh` and can call `sha256_file` directly — it does NOT need to
inline its own helper. This supersedes the CONTEXT.md claim that "bridges.sh inlines its own
helper": that claim referenced `uninstall.sh::classify_file` which uses `sha256_file` by calling the
function (line 211: `current=$(sha256_file "$abs" 2>/dev/null || echo "")`), not by inlining
`shasum`. The function already covers the macOS BSD fallback chain.

### 1d. `dro_print_file` / `dro_print_header` — UX-01 helpers

**File:** `scripts/lib/dry-run-output.sh:57–63`

```bash
# dro_print_file — print one indented file line under a section header.
# Args: $1=filepath (or "filepath  (annotation)")
# Format: "  <filepath>" (2-space indent, no color, no marker).
dro_print_file() {
    local filepath="$1"
    printf '  %s\n' "$filepath"
}
```

The `dro_print_header` function (lines 48–55) is the section-opener.
Bridge create logging calls `dro_print_header "+" "INSTALL" 1 _DRO_G` then `dro_print_file <path>`.

### 1e. `classify_file` — uninstall.sh SHA256 consumer (Phase 29 reference, not Phase 28)

**File:** `scripts/uninstall.sh:195–221`

```bash
classify_file() {
    local path="$1" recorded="$2"
    ...
    local current
    current=$(sha256_file "$abs" 2>/dev/null || echo "")
    if [[ "$current" == "$recorded" ]]; then
        printf 'REMOVE'
    else
        printf 'MODIFIED'
    fi
}
```

This is the consumer pattern for Phase 29 — uninstall reads `bridges[]` paths into the same
classify loop. Phase 28 only writes the `bridges[]` entries; it does not consume `classify_file`.

### 1f. TK_BOOTSTRAP_TTY_SRC pattern (bootstrap.sh:43–46)

**File:** `scripts/lib/bootstrap.sh:40–46`

```bash
_bootstrap_prompt_and_run() {
    local plugin_name="$1" prompt_text="$2" cmd="$3"
    local tty_target="/dev/tty"
    [[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"

    local choice=""
    if ! read -r -p "$prompt_text" choice < "$tty_target" 2>/dev/null; then
```

The `TK_BRIDGE_HOME` test seam mirrors this pattern but for filesystem paths rather than TTY.
In `bridges.sh`: `local bridge_home="${TK_BRIDGE_HOME:-$HOME}"` then `"${bridge_home}/.gemini/"`.

---

## 2. Detection Pattern (BRIDGE-DET-01..03)

### Existing probe body shape

Every probe in `detect2.sh` follows one of two shapes:

**Shape A — single `command -v` test (lines 70–71, 73–79):**

```bash
is_rtk_installed() {
    command -v rtk >/dev/null 2>&1
}

is_statusline_installed() {
    [[ -f "$HOME/.claude/statusline.sh" ]] || return 1
    grep -q '"statusLine"' "$HOME/.claude/settings.json" 2>/dev/null
}
```

**Shape B — two-condition (lines 54–67):** CLI presence AND grep in a config file.

Bridges use Shape A extended with a soft cross-check (filesystem dir) that is advisory only.
The CONTEXT.md decision is: CLI-PATH wins; dir presence is confirmation only, NOT a second gate.
This means the function body is still a single `return 0 / return 1` with the dir check
logged internally if needed, but NOT blocking the return:

```bash
# BRIDGE-DET-01: Gemini CLI presence (binary on PATH).
# Soft cross-check: ~/.gemini/ dir as confirmation (CLI-PATH wins on conflict).
is_gemini_installed() {
    command -v gemini >/dev/null 2>&1
}

# BRIDGE-DET-02: OpenAI Codex CLI presence (binary on PATH).
# Soft cross-check: ~/.codex/ dir as confirmation (CLI-PATH wins on conflict).
is_codex_installed() {
    command -v codex >/dev/null 2>&1
}
```

The filesystem cross-check is available if the caller wants it (`[ -d "${HOME}/.gemini" ]`) but is
NOT embedded in the probe itself — the probe must remain binary 0/1 with no side effects (D-22).

### Alphabetization rule

Existing probes in `detect2.sh` appear in this order (alphabetical by CLI name):
`is_gsd_installed`, `is_rtk_installed`, `is_security_installed`, `is_statusline_installed`,
`is_superpowers_installed`, `is_toolkit_installed`.

New additions alphabetically: `is_codex_installed` (before `is_gsd_installed`) and
`is_gemini_installed` (between `is_gsd_installed` and `is_rtk_installed`).

The `detect2_cache` function at the end of the file must also receive two new lines:

```bash
IS_GEM=0; is_gemini_installed && IS_GEM=1 || true
IS_COD=0; is_codex_installed  && IS_COD=1 || true
export IS_GEM IS_COD  # append to existing export line or add new export line
```

The header comment block (lines 6–14) listing probe names must be updated to include both new
functions.

---

## 3. Atomic JSON Mutation (BRIDGE-GEN-04)

### Corrected API names

The CONTEXT.md refers to `_state_lock` and `_atomic_json_write`. The actual exported names in
`state.sh` are `acquire_lock`, `release_lock`, and `write_state`. There is no `state_get` or
`state_set` function — state reads use `read_state` which emits raw JSON to stdout.

### Why `write_state` cannot be reused directly

`write_state` (state.sh:60–138) rebuilds the ENTIRE JSON document from positional arguments
(`mode`, `has_sp`, `sp_ver`, `has_gsd`, `gsd_ver`, `installed_csv`, `skipped_csv`, `synth_flag`,
`manifest_hash`). Calling it would overwrite the existing `installed_files[]`, `mode`, and
`detected` fields with whatever values are passed in — and `bridges.sh` does not have access to
those values at bridge-create time.

### Correct pattern: surgical Python patch inside bridges.sh

`bridges.sh` must implement its own Python `tempfile.mkstemp + os.replace` block that patch-merges
only `.bridges[]`. The shape mirrors `write_state` (lines 71–137) but scoped to one key:

```bash
_bridge_write_state_entry() {
    local target="$1" path="$2" scope="$3" source_sha="$4" bridge_sha="$5"
    local state_file="${TK_BRIDGE_HOME:-$HOME}/.claude/toolkit-install.json"

    acquire_lock || return 1
    # Ensure release_lock is called on any exit from this function.
    # Caller must have registered trap 'release_lock' EXIT before calling.

    python3 - "$target" "$path" "$scope" "$source_sha" "$bridge_sha" \
              "$state_file" <<'PYEOF'
import json, os, sys, tempfile

target, path, scope, src_sha, br_sha, state_path = sys.argv[1:7]

# Load existing state (create stub if missing)
if os.path.exists(state_path):
    with open(state_path) as f:
        state = json.load(f)
else:
    state = {}

bridges = state.get("bridges", [])

# Dedup: replace existing (target, scope, path) triple in-place
entry = {"target": target, "path": path, "scope": scope,
         "source_sha256": src_sha, "bridge_sha256": br_sha,
         "user_owned": False}
idx = next((i for i, e in enumerate(bridges)
            if e.get("target") == target and
               e.get("scope") == scope and
               e.get("path") == path), None)
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
    try: os.unlink(tmp_path)
    except FileNotFoundError: pass
    raise
PYEOF

    release_lock
}
```

The `acquire_lock` / `release_lock` calls require that the caller (or `bridges.sh` global init)
has registered `trap 'release_lock' EXIT` BEFORE calling `acquire_lock` — this is the state.sh
caller contract (line 10: "Callers MUST register `trap 'release_lock' EXIT` BEFORE calling
`acquire_lock`").

In `bridges.sh`, the `trap` should be registered at function entry inside
`_bridge_write_state_entry` using a subshell or inline, NOT globally, to avoid clobbering the
caller's own EXIT trap. Pattern: wrap the lock-acquire in a subshell if needed, or accept that
`bridges.sh` is only called from top-level contexts (scripts with their own trap registrations).

### jq dedup shape alternative (jq-only, no python3)

If python3 is unavailable (edge case — state.sh already requires it for `write_state`), jq can
patch in-place via a tmpfile:

```bash
jq --arg t "$target" --arg p "$path" --arg s "$scope" \
   --arg src "$source_sha" --arg br "$bridge_sha" '
   .bridges = ((.bridges // []) |
               map(select(.target != $t or .scope != $s or .path != $p)) +
               [{"target":$t,"path":$p,"scope":$s,
                 "source_sha256":$src,"bridge_sha256":$br,"user_owned":false}])
' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
```

However, since `write_state` already requires python3 and `state.sh` is sourced by `bridges.sh`,
the python3 approach is preferred for consistency. The jq shape above is documented for reference
if the planner chooses the simpler form.

---

## 4. SHA256 Helper (BRIDGE-GEN-04)

### Definitive finding: use `sha256_file` from state.sh (already sourced)

`state.sh:32–53` exports `sha256_file` with a full three-way fallback:
1. `sha256sum` (GNU coreutils, Linux)
2. `shasum -a 256` (macOS BSD built-in)
3. `python3` inline hashlib (minimal env fallback)

Since `bridges.sh` sources `state.sh`, it calls `sha256_file "$path"` directly — no need to
inline anything. The CONTEXT.md note that "bridges.sh inlines the same helper" was based on
`uninstall.sh::classify_file:211` (`current=$(sha256_file "$abs" 2>/dev/null || echo "")`).
That line is calling `sha256_file`, not inlining shasum — the function is defined in state.sh
and sourced into uninstall.sh at line 99.

**The inline reference in CONTEXT.md is a red herring** — everything uses `sha256_file` from
`state.sh`. `bridges.sh` follows the same pattern.

---

## 5. Heredoc Banner Pattern (BRIDGE-GEN-03)

### Single-quoted delimiter suppresses all variable expansion

`cat <<'EOF'` with single-quoted delimiter: every `$`, `` ` ``, and `\` is treated literally.
This is the correct form for the 4-line HTML comment banner that must be byte-identical.

In-repo example — `scripts/tests/fixtures/council/stub-gemini.sh:9-20`:

```bash
cat <<'EOF'
<verdict-table>
| ID | verdict | confidence | justification |
|----|---------|------------|---------------|
| F-001 | REAL | 0.9 | req.params.id concatenated into SQL ...
...
</verdict-table>
EOF
```

For `bridges.sh` banner generation inside `bridge_create_project` / `bridge_create_global`:

```bash
{
    cat <<'BANNER'
<!--
  Auto-generated from CLAUDE.md by claude-code-toolkit (v4.7+).
  Edit CLAUDE.md (canonical source). This file regenerates on update-claude.sh.
  To stop sync: run `update-claude.sh --break-bridge <name>`.
-->
BANNER
    echo ""          # exactly one blank line separator
    cat "$source"    # verbatim CLAUDE.md content
} > "$target_path"
```

The `cat <<'BANNER'` form with non-EOF delimiter is conventional for embedded blocks inside
functions — avoids collision with outer `<<'EOF'` in test harnesses.

The `python3 - ... <<'PYEOF'` pattern (state.sh:71, install.sh:169, install.sh:223) shows the
same single-quoted convention is already well-established in this codebase.

---

## 6. Test Seam Convention (TK_BRIDGE_HOME)

### How TK_* seams work in the codebase

Every Phase 24–26 seam follows the `${VAR:-default}` form:

- `bootstrap.sh:43` — `TK_BOOTSTRAP_TTY_SRC`:

  ```bash
  local tty_target="/dev/tty"
  [[ -n "${TK_BOOTSTRAP_TTY_SRC:-}" ]] && tty_target="$TK_BOOTSTRAP_TTY_SRC"
  ```

- `mcp.sh:147-149` — `TK_MCP_CONFIG_HOME`:

  ```bash
  _mcp_config_path() {
      echo "${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env"
  }
  ```

- `mcp.sh:378` — `TK_MCP_TTY_SRC`:

  ```bash
  local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"
  ```

`TK_BRIDGE_HOME` follows the `TK_MCP_CONFIG_HOME` pattern exactly — a `$HOME` substitute, not a
TTY substitute. The correct inline form for `bridges.sh`:

```bash
_bridge_home() {
    echo "${TK_BRIDGE_HOME:-$HOME}"
}
```

Then target path resolution:

```bash
_bridge_global_dir() {
    local target="$1"
    local home
    home="$(_bridge_home)"
    case "$target" in
        gemini) echo "${home}/.gemini" ;;
        codex)  echo "${home}/.codex"  ;;
        *)      return 1               ;;
    esac
}
```

Tests set `TK_BRIDGE_HOME="$SANDBOX"` so `bridge_create_global gemini` writes to
`"$SANDBOX/.gemini/GEMINI.md"` instead of `"$HOME/.gemini/GEMINI.md"`.

State file path must also honor the seam:
`STATE_FILE="${TK_BRIDGE_HOME:-$HOME}/.claude/toolkit-install.json"` — mirrors how
`update-claude.sh:126` overrides `STATE_FILE` for the `TK_UPDATE_HOME` test seam.

---

## 7. Bash 3.2+ Constraints Reminders

From Phase 24 SUMMARY (24-01-detect2-centralized-detection-SUMMARY.md) and STATE.md `Key v4.6
Constraints` section:

| Forbidden pattern | Bash version required | Safe alternative |
|-------------------|-----------------------|------------------|
| `declare -A` (associative arrays) | Bash 4.0+ | Parallel indexed arrays `KEY_ARR[]` + `VAL_ARR[]` |
| `read -N` (read exactly N chars) | Bash 4.1+ | `read -rsn1` (lowercase n) |
| `${var^^}` (uppercase expansion) | Bash 4.0+ | `echo "$var" | tr '[:lower:]' '[:upper:]'` |
| `declare -n` (nameref) | Bash 4.3+ | Indirect expansion via `eval "local val=\${$varname}"` |
| `mapfile` / `readarray` | Bash 4.0+ | `while IFS= read -r line; do arr+=("$line"); done` |

`bridges.sh` specifically: the `case "$target" in gemini) ... codex) ...` pattern is Bash 3.2
safe and is the idiomatic Bash 3.2 dispatch for the two bridge targets. No associative maps needed.

The Phase 24 tui.sh header carries this reminder as a comment paraphrase (not exact text) to
avoid shellcheck grep false-positives in acceptance criteria — `bridges.sh` should follow the
same practice.

---

## 8. Manifest Auto-Discovery (LIB-01 D-07)

### The jq path in update-claude.sh

`update-claude.sh:279`:

```bash
done < <(jq -r '.files | to_entries[] | .value[] | .path' "$manifest_file")
```

And `update-claude.sh:653`:

```bash
MANIFEST_FILES_JSON=$(jq -c '[.files | to_entries[] | .value[] | .path]' "$MANIFEST_TMP")
```

`to_entries[]` iterates ALL top-level keys of `.files` (agents, commands, skills, rules, scripts,
libs, skills_marketplace). Adding `bridges.sh` to `manifest.json:files.libs[]` makes it appear
in both the diff computation and the download loop without any code changes in `update-claude.sh`.

### Current `files.libs[]` in manifest.json (lines 228–268)

Alphabetical ordering is not enforced for libs (they appear in insertion order), but inserting
`bridges.sh` before `cli-recommendations.sh` would maintain rough alpha order:

```json
"libs": [
  { "path": "scripts/lib/backup.sh" },
  { "path": "scripts/lib/bootstrap.sh" },
  { "path": "scripts/lib/bridges.sh" },      ← insert here (Phase 31 per traceability)
  { "path": "scripts/lib/cli-recommendations.sh" },
  ...
]
```

**Phase 28 does NOT add `bridges.sh` to manifest.json** — per REQUIREMENTS.md traceability,
`BRIDGE-DIST-01` is a Phase 31 task. Phase 28 only creates the file; registration is deferred.
The planner must not include a manifest.json edit in Phase 28 plans.

---

## 9. Plan Splitting Recommendations

Given 7 REQ-IDs and the two-file nature of Phase 28 (one modified, one created), a 3-plan split is natural:

### Plan 28-01: Detection probes (`detect2.sh` extension)

**REQ-IDs:** BRIDGE-DET-01, BRIDGE-DET-02, BRIDGE-DET-03

**Files:** `scripts/lib/detect2.sh` (edit), `scripts/tests/test-install-tui.sh` (extend)

**Tasks:**
1. Add `is_codex_installed` before `is_gemini_installed` in alphabetical position in detect2.sh.
   Add both functions and `IS_GEM` / `IS_COD` to `detect2_cache`. Update header comment.
2. Extend `test-install-tui.sh` with S_bridge_detect scenario: sandbox has no gemini/codex on
   PATH → both probes return 1. Assert count rises to ≥ N+2 (current assertion count + 2).
3. `shellcheck scripts/lib/detect2.sh` must pass.

**Cross-cutting concern:** Do NOT modify the `detect2_cache` export line in a way that breaks
the existing `IS_SP IS_GSD IS_TK IS_SEC IS_RTK IS_SL` export contract — append the new vars to
the same `export` statement or add a second `export IS_GEM IS_COD` after the existing one.

### Plan 28-02: Bridge library (`bridges.sh` new file)

**REQ-IDs:** BRIDGE-GEN-01, BRIDGE-GEN-02, BRIDGE-GEN-03, BRIDGE-GEN-04 (state mutation)

**Files:** `scripts/lib/bridges.sh` (create)

**Tasks:**
1. Create `bridges.sh` with sourcing block, color guards, helper functions
   (`_bridge_home`, `_bridge_target_path`, `_bridge_target_filename`, `_bridge_write_state_entry`).
2. Implement `bridge_create_project` and `bridge_create_global` using the heredoc banner +
   `cat "$source"` pattern and calling `sha256_file` (from sourced state.sh).
3. Wire `_bridge_write_state_entry` python3 patch block for `bridges[]` array mutation.
4. `shellcheck scripts/lib/bridges.sh` must pass.

**Cross-cutting concern:** The `trap 'release_lock' EXIT` must be established before
`acquire_lock` is called. The recommended approach is to scope the lock inside
`_bridge_write_state_entry` only — acquire at function start, release at function end via a
`local` trap that restores to prior state, or accept that calling scripts are expected to have
registered the trap (same contract as `state.sh` line 10). Planner must decide and document.

### Plan 28-03: Smoke / hermetic test scaffold

**REQ-IDs:** (all 7, acceptance-gate only)

**Files:** `scripts/tests/test-bridges.sh` (create, minimal scaffold — full suite is Phase 31)

**Tasks:**
1. Create `test-bridges.sh` with ≥ 5 smoke assertions covering:
   - `bridge_create_project gemini` produces `GEMINI.md` with banner at top.
   - `bridge_create_project codex` produces `AGENTS.md`.
   - Re-run is idempotent (same SHA256 before and after).
   - `toolkit-install.json::bridges[]` has one entry with correct `target`, `path`, `scope`.
   - `TK_BRIDGE_HOME` seam keeps all writes inside sandbox (no real `$HOME` pollution).
2. Run `make shellcheck` on new file.
3. BACKCOMPAT-01 gate: `test-bootstrap.sh PASS=26 FAIL=0` and existing `test-install-tui.sh`
   assertion count unchanged.

**Cross-cutting concern:** Phase 31's `BRIDGE-TEST-01` requires ≥15 assertions. Phase 28's
scaffold should be structured so Phase 31 can extend with `assert_equals` style helpers without
rewriting. Use the same `PASS`/`FAIL` counter idiom as `test-install-tui.sh`.

---

## 10. Risk Register

### Risk 1: CONTEXT.md's `_state_lock` / `_atomic_json_write` names don't exist

**Likelihood:** Certain (verified — these names are absent from the entire codebase).
**Impact:** HIGH — executor writes calls to non-existent functions; immediate runtime failure.
**Mitigation:** Plans must explicitly specify `acquire_lock` / `release_lock` (from state.sh)
and a new Python tempfile+os.replace block inside `_bridge_write_state_entry`. The planner must
name-correct the CONTEXT.md before passing plan text to the executor.

### Risk 2: `write_state` overwrites full JSON — cannot be reused for bridges patch

**Likelihood:** Certain (verified — write_state rebuilds entire document from fixed args).
**Impact:** HIGH — calling write_state from bridges.sh would clobber `installed_files[]`.
**Mitigation:** Bridge state mutation is a new Python block (see §3). Plans must NOT reference
`write_state` for the `bridges[]` registration step.

### Risk 3: macOS BSD `shasum -a 256` flag drift

**Likelihood:** LOW (macOS has shipped shasum with `-a 256` since macOS 10.x).
**Impact:** LOW — sha256_file already has a three-way fallback including python3.
**Mitigation:** `sha256_file` from state.sh handles this; bridges don't call shasum directly.

### Risk 4: `trap 'release_lock' EXIT` clobbering caller's trap

**Likelihood:** MEDIUM — if `bridge_create_project` is called inside a script that has its own
EXIT trap (e.g., test harness cleanup), the `release_lock` pattern in state.sh's contract
("Callers MUST register trap before calling acquire_lock") could conflict.
**Impact:** MEDIUM — lock may not be released cleanly if caller's EXIT trap replaces ours.
**Mitigation:** Use `( acquire_lock; ...; release_lock )` subshell pattern inside
`_bridge_write_state_entry`, OR scope the trap carefully: `local _old_exit=$(trap -p EXIT)`.
The subshell approach is simpler and used in v4.4 tests; Bash 3.2 supports subshells.

### Risk 5: `TK_BRIDGE_HOME` shadowed by `$HOME` in tests that don't set it

**Likelihood:** LOW — tests explicitly set seams in this codebase (pattern from Phase 24-25).
**Impact:** MEDIUM — if a test forgets `TK_BRIDGE_HOME`, `bridge_create_global` writes to real
`~/.gemini/` polluting the developer's machine.
**Mitigation:** In `test-bridges.sh`, always `export TK_BRIDGE_HOME="$SANDBOX"` at the top of
every test function, just as `TK_MCP_CONFIG_HOME="$SANDBOX"` is set in MCP tests. Include an
assertion that `$HOME/.gemini/GEMINI.md` does NOT exist after the test run (guards against
seam-bypass).

---

## Common Pitfalls

### Pitfall 1: Using `BASH_SOURCE[0]` instead of `${BASH_SOURCE[0]:-}`

**What goes wrong:** Under Bash 3.2 with `set -u`, `BASH_SOURCE` is unset when script is
sourced via process substitution or stdin. `detect2.sh:34` and `mcp.sh:45` both use
`"${BASH_SOURCE[0]:-.}"` (note the `:-` default).
**How to avoid:** All `BASH_SOURCE` references in `bridges.sh` must use `${BASH_SOURCE[0]:-}`.

### Pitfall 2: Not quoting target arg in `case` dispatch

**What goes wrong:** `case "$target" in gemini)` is correct. `case $target in` without quotes
causes word splitting if `$target` contains spaces (impossible in practice but shellcheck flags it).
**How to avoid:** Always quote: `case "$target" in`.

### Pitfall 3: Bridge file written before directory is created

**What goes wrong:** `bridge_create_global gemini` writes to `~/.gemini/GEMINI.md` but
`~/.gemini/` may not exist. Without `mkdir -p`, the write fails silently if output is redirected.
**How to avoid:** `mkdir -p "$(dirname "$target_path")" || return 2` before the `{...} > "$target_path"` block.

### Pitfall 4: sha256 computed before file is fully written

**What goes wrong:** Computing `bridge_sha256` from the file on disk requires the write to
complete and the file descriptor to be closed. If `sha256_file` is called on `$target_path`
before the `{cat <<'BANNER'; echo; cat "$source"} > "$target_path"` block has closed,
the hash is of a partial file.
**How to avoid:** Call `sha256_file "$target_path"` AFTER the `{...} > "$target_path"` block,
not inside it.

---

## Code Examples

### New probe pair for detect2.sh

```bash
# BRIDGE-DET-02: OpenAI Codex CLI presence (binary on PATH).
# Soft cross-check: ~/.codex/ dir as confirmation (CLI-PATH wins).
is_codex_installed() {
    command -v codex >/dev/null 2>&1
}

# BRIDGE-DET-01: Gemini CLI presence (binary on PATH).
# Soft cross-check: ~/.gemini/ dir as confirmation (CLI-PATH wins).
is_gemini_installed() {
    command -v gemini >/dev/null 2>&1
}
```

Insert codex before gsd (lex order), gemini between gsd and rtk.

### Bridge file write block (BRIDGE-GEN-01..03)

```bash
_bridge_write_file() {
    local source="$1" target_path="$2"
    [[ -f "$source" ]] || return 1
    mkdir -p "$(dirname "$target_path")" || return 2
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
    } > "$target_path"
}
```

### Target filename resolver

```bash
_bridge_filename() {
    local target="$1"
    case "$target" in
        gemini) echo "GEMINI.md" ;;
        codex)  echo "AGENTS.md" ;;
        *)      return 1 ;;
    esac
}
```

---

## Sources

### Primary (HIGH confidence — direct file inspection)

- `scripts/lib/detect2.sh` — all 6 existing probe functions; detect2_cache; color guard pattern
- `scripts/lib/state.sh` — `acquire_lock`, `release_lock`, `sha256_file`, `write_state` (actual API)
- `scripts/lib/dry-run-output.sh` — `dro_print_header`, `dro_print_file`
- `scripts/lib/bootstrap.sh:40–46` — `TK_BOOTSTRAP_TTY_SRC` seam pattern
- `scripts/lib/mcp.sh:147–149, 378` — `TK_MCP_CONFIG_HOME`, `TK_MCP_TTY_SRC` seam pattern
- `scripts/uninstall.sh:195–221` — `classify_file` (Phase 29 reference consumer)
- `scripts/tests/fixtures/council/stub-gemini.sh:9–20` — `cat <<'EOF'` heredoc in-repo example
- `manifest.json:228–268` — `files.libs[]` current array, alphabetical ordering reference
- `scripts/update-claude.sh:279, 653` — `.files | to_entries[] | .value[] | .path` jq path
- `.planning/milestones/v4.6-phases/24-unified-tui-installer-centralized-detection/24-01-detect2-centralized-detection-SUMMARY.md` — D-21/D-22/D-23 decisions; Bash 3.2 invariants
- `.planning/phases/28-bridge-foundation/28-CONTEXT.md` — locked decisions, API shape, test seam
- `.planning/REQUIREMENTS.md` — v4.7 full REQ-ID list; Phase 28 traceability

### Secondary (MEDIUM — inferred from pattern consistency)

- Phase 24 decisions in STATE.md `Key v4.6 Constraints` — Bash 3.2 forbidden patterns list
- state.sh line 10 comment — `trap 'release_lock' EXIT` caller contract

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_state_lock` and `_atomic_json_write` do not exist; actual names are `acquire_lock`/`release_lock` | §1b, §3 | LOW (verified by reading all exported function names in state.sh) |
| A2 | `sha256_file` in state.sh is available to bridges.sh via sourcing; no inline needed | §4 | LOW (verified — state.sh:5 explicitly lists `sha256_file` in its Exposes comment) |
| A3 | manifest.json `files.libs[]` insertion is Phase 31 (BRIDGE-DIST-01), NOT Phase 28 | §8 | LOW (verified against REQUIREMENTS.md traceability table) |
| A4 | The directory probe (`~/.gemini/` / `~/.codex/`) does NOT gate the probe return value — CLI-PATH wins | §2 | LOW (verified against CONTEXT.md decisions verbatim: "CLI-PATH wins on conflict") |

**All four assumptions are confirmed by codebase evidence above. No items require user confirmation.**

---

## Metadata

**Confidence breakdown:**

- Detection pattern: HIGH — direct file:line evidence from detect2.sh
- bridges.sh API shape: HIGH — all components verified in existing libs
- State mutation: HIGH — write_state and acquire_lock confirmed; Python block pattern verified
- SHA256 helper: HIGH — sha256_file function verified in state.sh:32
- Bash 3.2 constraints: HIGH — sourced from Phase 24 decisions + STATE.md

**Research date:** 2026-04-29
**Valid until:** Stable (no external dependencies; pure codebase investigation)
