# Phase 40 — Uninstall Secret Cleanup + Calendly + Validator — PATTERNS

**Mapped:** 2026-05-05
**Files analyzed:** 7 modified files (1 helper-add: `uninstall_prompt_mcp_keys` added in `uninstall.sh`)
**Analogs found:** 7 / 7 (all locked decisions have an in-repo analog)

## File Classification

| File (modified) | Role | Data Flow | Closest Analog | Match Quality |
|-----------------|------|-----------|----------------|---------------|
| `scripts/uninstall.sh` (new helper `uninstall_prompt_mcp_keys`) | uninstall-script function | request-response (TTY prompt + atomic file rewrite) | `scripts/uninstall.sh:300 prompt_modified_for_uninstall` + `scripts/lib/mcp.sh:542 mcp_secrets_set` (rewrite path) | exact (TTY contract + rewrite contract are the two halves of this helper) |
| `scripts/uninstall.sh` (new MCP loop) | uninstall-script main-block loop | request-response | `scripts/uninstall.sh:708 MODIFIED_LIST loop` (per-row prompt loop) | role-match (per-name iteration with prompt) |
| `scripts/uninstall.sh` (full-toolkit `mcp-config.env` prompt + ordering) | uninstall-script gate | request-response | `scripts/uninstall.sh:826 KEEP_STATE/state-file gate` (final-step gate) | exact (lives directly upstream of state-delete; same dry-run + KEEP_STATE shape) |
| `scripts/uninstall.sh` (`--keep-state` extension to imply `--keep-secrets`) | flag handler | gate | `scripts/uninstall.sh:824 KEEP_STATE check` | exact (extend existing gate, same env-var seam) |
| `scripts/uninstall.sh` (`--help` block + `--dry-run` print) | usage text | n/a | `scripts/uninstall.sh:8-12 + 35` (`sed -n '3,19p'`) | exact (pre-existing self-documenting `--help` block) |
| `scripts/lib/integrations-catalog.json` (Calendly entry) | data | n/a | `notion` entry at `scripts/lib/integrations-catalog.json:200-215` (OAuth-only `env_var_keys=[]`) | exact (closest existing OAuth-only `requires_oauth=true` shape) |
| `scripts/validate-integrations-catalog.py` (SCOPE-01 assertion) | validator check | transform | `scripts/validate-integrations-catalog.py:254-272` (existing SCOPE-01 default_scope check) | **already implemented** (see "No Analog Found / Already-Implemented" below — Phase 40 only adds the regression test) |
| `scripts/tests/test-uninstall-state-cleanup.sh` (6 new scenarios) | test suite | n/a | `scripts/tests/test-uninstall-state-cleanup.sh:79-150` (sandbox+TK_UNINSTALL_HOME+state-file fixture) + `scripts/tests/test-uninstall-prompt.sh:127-144` (STDIN prompt-injection harness) | exact (extend pattern in same file) |
| `scripts/tests/test-integrations-catalog.sh` (Calendly + SCOPE-01 + Google Workspace negative) | test suite | n/a | `scripts/tests/test-integrations-catalog.sh:275-310 (A15/A16/A17)` SCOPE-01 grid + `A10` (notebooklm/telegram unofficial-set assertion) | exact (extend `_pyq` block; same shape) |

---

## Pattern Assignments

### `uninstall_prompt_mcp_keys <name> <key1> <key2>...` — new function in `scripts/uninstall.sh`

**Two analogs combined: TTY prompt half + atomic-rewrite half.**

#### TTY-prompt half — copy from `scripts/uninstall.sh:300-372 prompt_modified_for_uninstall`

```bash
# scripts/uninstall.sh:353-356 — TTY source resolution (test seam: TK_UNINSTALL_TTY_FROM_STDIN)
local tty_target="/dev/tty"
[[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && tty_target="/dev/stdin"

# scripts/uninstall.sh:362-371 — fail-closed N read pattern (5-attempt cap)
local _read_fail=0
while :; do
    local choice=""
    if ! read -r -p "PROMPT [y/N]: " choice < "$tty_target" 2>/dev/null; then
        choice="N"   # fail-closed: tty source unreachable
        _read_fail=$((_read_fail + 1))
        if [[ $_read_fail -ge 5 ]]; then
            return 0
        fi
    fi
    case "${choice:-N}" in
        y|Y) ...; return 0 ;;
        *)   return 0 ;;   # default N
    esac
done
```

D-01 contract maps cleanly: `tty_target` defaulting to `/dev/tty` + `TK_UNINSTALL_TTY_FROM_STDIN` test seam = the v4.3 UN-03 invariant. Phase 40 reuses the **same** seam name (D-13 — no new seam coined).

Prompt text per D-01: `"[y/N] also remove keys K1, K2 from mcp-config.env? "` (mirrors `mcp_secrets_set:566` `[y/N] Overwrite ${key}? ` shape).

#### Key list source — copy from `scripts/lib/mcp.sh:152`

```bash
# scripts/lib/mcp.sh:152 — env_var_keys extraction (jq, semicolon-joined)
MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.components.mcp[$n].env_var_keys | join(";")' "$catalog_path")")
```

For the helper (single-name, no array population): use the simpler

```bash
# Phase 40 helper signature uses keys passed as positional args (caller resolves
# via jq once per name). Defensive empty-array handling per D-03:
#   if [[ $# -lt 2 ]]; then return 0; fi   # name + zero keys (e.g., Calendly OAuth-only) → no-op
```

Resolution path in catalog: `${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}` (same seam as `mcp_catalog_load:112`). Catalog already required by toolkit (CLAUDE.md tech stack); `jq` already required (CLAUDE.md key dependencies).

#### Atomic-rewrite half — copy from `scripts/lib/mcp.sh:553-595 mcp_secrets_set`

```bash
# scripts/lib/mcp.sh:553-558 — order-of-operations setup
local cfg
cfg="$(_mcp_config_path)"      # honors TK_MCP_CONFIG_HOME (set by uninstall: $TK_UNINSTALL_HOME)
mkdir -p "$(dirname "$cfg")" || return 1
touch "$cfg" || return 1
chmod 0600 "$cfg" || return 1
mcp_secrets_load              # populates MCP_SECRET_KEYS[] / MCP_SECRET_VALUES[]

# scripts/lib/mcp.sh:572-583 — atomic rewrite via mktemp + mv + chmod 0600 (post-write)
local tmp
tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
local i
for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
    if [[ "$i" -eq "$idx" ]]; then       # ← Phase 40 inverts this: SKIP keys to remove
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
    else
        printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp"
    fi
done
mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
chmod 0600 "$cfg" || return 1
```

D-02 inversion: instead of overwriting one key, the helper **drops** any key whose name appears in the caller-supplied list. Implementation pseudocode:

```bash
# Build a "skip set" via a string membership test (Bash 3.2 — no associative arrays per D-16).
local skip_keys=" $* "   # space-padded for word-boundary match: " AWS_ACCESS_KEY_ID ..."
mcp_secrets_load
tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
    case "$skip_keys" in
        *" ${MCP_SECRET_KEYS[$i]} "*) continue ;;   # drop this key
        *) printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp" ;;
    esac
done
mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
chmod 0600 "$cfg" || return 1
```

Same idempotency property: re-running the helper after a successful prune is a no-op (loop emits zero matches in `skip_keys` → file unchanged). D-02 idempotency assertion lands here.

#### Dry-run gate — copy from `scripts/uninstall.sh:615-618`

```bash
# scripts/uninstall.sh:615-618 — pattern: short-circuit print before any writes
if [[ $DRY_RUN -eq 1 ]]; then
    print_uninstall_dry_run
    exit 0
fi
```

D-08 dry-run print (helper-internal, no `exit`): `echo "[dry-run] would prompt: also remove keys K1, K2 from mcp-config.env?"` then `return 0`. Format mirrors the only two `[dry-run]` strings already in the codebase:
- `scripts/propagate-audit-pipeline-v42.sh:396` — `echo "[dry-run] would splice: ${f#"$REPO_ROOT/"}"`
- `scripts/migrate-to-complement.sh:245` — `echo "    [dry-run] would offer interactive removal."`

Note: there is no `[dry-run] would …` convention library function — it is plain `echo` in both existing call sites. Phase 40 uses the same plain-`echo` style.

---

### Per-MCP `claude mcp remove` loop — new code in `scripts/uninstall.sh`

**Analog:** `scripts/uninstall.sh:708-714` (existing per-row MODIFIED_LIST loop)

```bash
# scripts/uninstall.sh:708-714 — bash 3.2-safe array-length guard, per-row helper call
if [[ ${#MODIFIED_LIST[@]} -gt 0 ]]; then
    echo ""
    log_info "${#MODIFIED_LIST[@]} file(s) modified since install. Per-file decision required."
    for rel in "${MODIFIED_LIST[@]}"; do
        prompt_modified_for_uninstall "$rel"
    done
fi
```

**Phase 40 mirrors this shape verbatim** for the new MCP-cleanup loop:

```bash
# Recover MCP names from state (toolkit-install.json) OR from `claude mcp list` parse (D-04)
INSTALLED_MCPS=( ... )   # populated from one of the two sources
if [[ ${#INSTALLED_MCPS[@]} -gt 0 ]]; then
    echo ""
    log_info "${#INSTALLED_MCPS[@]} MCP(s) registered by toolkit. Removing…"
    for mcp_name in "${INSTALLED_MCPS[@]}"; do
        # Step 1: claude mcp remove --scope user (mirrors install.sh:687 reinstall pattern)
        "${TK_MCP_CLAUDE_BIN:-claude}" mcp remove --scope user "$mcp_name" >/dev/null 2>&1 || true
        # Step 2: prompt + per-MCP key cleanup (D-01 helper)
        keys=$(jq -r --arg n "$mcp_name" '.components.mcp[$n].env_var_keys[]' "$catalog_path" 2>/dev/null)
        # shellcheck disable=SC2086 — intentional word-split on whitespace key list
        uninstall_prompt_mcp_keys "$mcp_name" $keys
    done
fi
```

`claude mcp remove` invocation pattern is borrowed verbatim from `scripts/install.sh:687`:

```bash
# scripts/install.sh:686-687 — the only existing `claude mcp remove` call site in the codebase
_scope_for_rm="${TK_MCP_SCOPE:-user}"
"$_claude_bin" mcp remove --scope "$_scope_for_rm" "$local_name" >/dev/null 2>&1 || true
```

Phase 40 is the **first** `claude mcp remove` call in `uninstall.sh` (verified — zero matches for `mcp` keyword in uninstall.sh outside doc/state-file references). Per CONTEXT.md D-04, this loop also represents the first MCP-aware logic in uninstall.sh.

#### MCP recovery source — D-04 graceful degradation

`STATE_JSON` is already loaded at `scripts/uninstall.sh:494` via `read_state`. But the state file (per `lib/state.sh:117-129`) does **not** carry an `installed_mcps[]` field today — it has only `installed_files[]` and `bridges[]`. Two options for recovery, per D-04:

1. **Preferred:** `claude mcp list` parse using the existing cache machinery (`lib/mcp.sh:384-402 _mcp_list_cache_init`). The first column of each row is the MCP name (`is_mcp_installed:431` already does this parse).
2. **Fallback:** intersect `claude mcp list` output with catalog names (`mcp_catalog_names` at `lib/mcp.sh:360`) — only toolkit-known MCPs are removed.

Skip silently if `claude` CLI absent (returns `__no_cli__` per `_mcp_list_cache_init`) — matches v4.4 LIB-01 D-09 fail-soft contract.

---

### Full-toolkit `mcp-config.env` cleanup prompt — new block in `scripts/uninstall.sh`

**Analog:** `scripts/uninstall.sh:824-834` (existing KEEP_STATE / STATE_FILE-removal block)

```bash
# scripts/uninstall.sh:820-834 — the LAST-step state-file deletion gate (D-06 ordering invariant)
# ───────── UN-05: delete toolkit-install.json (LAST step, D-06) ─────────
if [[ $KEEP_STATE -eq 0 ]]; then
    if rm -f "$STATE_FILE"; then
        log_success "State file removed: $STATE_FILE"
    else
        log_warning "Failed to remove $STATE_FILE — uninstall is complete but state file is orphaned. Remove manually: rm '$STATE_FILE'"
    fi
else
    log_info "State file preserved (--keep-state): $STATE_FILE"
fi
```

**D-05 + D-07 placement:** the new full-toolkit prompt + `rm -f mcp-config.env` block sits **immediately upstream** of this STATE_FILE block (D-06 ordering: `... → mcp-config.env removal (NEW) → STATE_FILE removal (LAST, unchanged)`).

Block shape:

```bash
# Phase 40 D-05/D-07 — full-toolkit mcp-config.env cleanup prompt (sits BEFORE STATE_FILE block)
MCP_CFG="${TK_MCP_CONFIG_HOME:-${TK_UNINSTALL_HOME:-$HOME}}/.claude/mcp-config.env"
if [[ $KEEP_STATE -eq 0 && -f "$MCP_CFG" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] would prompt: also remove $MCP_CFG?"
    else
        # Count keys + MCPs (D-05 — surface in prompt label)
        mcp_secrets_load                              # populates MCP_SECRET_KEYS[]
        n_keys=${#MCP_SECRET_KEYS[@]}
        # n_mcps: distinct MCP_<NAME>_ prefix count (defensive — empty file → 0)
        # Skip silently when file absent (already gated by [[ -f "$MCP_CFG" ]] above).
        tty_target="/dev/tty"
        [[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && tty_target="/dev/stdin"
        choice=""
        if ! read -r -p "[y/N] also remove $MCP_CFG ($n_keys keys for $n_mcps MCPs)? " choice < "$tty_target" 2>/dev/null; then
            choice="N"   # fail-closed N on no-TTY
        fi
        case "${choice:-N}" in
            y|Y) rm -f "$MCP_CFG" && log_success "Removed: $MCP_CFG" ;;
            *)   log_info "Preserved: $MCP_CFG" ;;
        esac
    fi
fi

# ───────── UN-05: delete toolkit-install.json (LAST step, D-06 — unchanged) ─────────
if [[ $KEEP_STATE -eq 0 ]]; then
    ...   # existing block at line 826-834, unchanged
fi
```

**Critical invariant (D-06):** the new block must NOT change the STATE_FILE block; it just inserts upstream. Test A11 (`uninstall.sh:213` STATE_FILE removed AFTER assertion) and the new UN-SEC-03-Y scenario (D-12) lock this ordering.

`mcp_secrets_load` is sourceable: Phase 40 sources `scripts/lib/mcp.sh` (not currently sourced by uninstall.sh — see line 122 `for lib_pair in "state.sh:..." "backup.sh:..." "dry-run-output.sh:..." "bridges.sh:..."`). **Add `mcp.sh` to that loop**, mirroring the same `TK_UNINSTALL_LIB_DIR` test-seam pattern at line 124.

---

### `--keep-state` implies `--keep-secrets` — extension at `scripts/uninstall.sh:824+`

**Analog:** `scripts/uninstall.sh:25-32 + 826` (existing flag wiring + gate)

```bash
# scripts/uninstall.sh:25 — env-var precedence (KEEP-01 D-09)
KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}

# scripts/uninstall.sh:31-33 — flag set
--keep-state)
    KEEP_STATE=1
    ;;

# scripts/uninstall.sh:826 — the gate Phase 40 extends
if [[ $KEEP_STATE -eq 0 ]]; then
    # state-file removal — Phase 40 ALSO gates: per-MCP cleanup + full-toolkit prompt
fi
```

**D-07 implementation:** the existing `KEEP_STATE -eq 0` gate is reused **as-is** at THREE points — the new MCP loop's `uninstall_prompt_mcp_keys` call, the new full-toolkit `mcp-config.env` block, and the existing STATE_FILE block. No new flag, no new env-var (D-07 explicit YAGNI).

---

### `--help` text update — extend `scripts/uninstall.sh:8-12`

**Analog:** existing self-documenting block at `scripts/uninstall.sh:3-19` rendered via `sed -n '3,19p'` (line 35).

```bash
# scripts/uninstall.sh:8-12 — existing usage block (rendered by --help)
# Usage:
#   bash scripts/uninstall.sh               # interactive default
#   bash scripts/uninstall.sh --dry-run     # preview only, no changes
#   bash scripts/uninstall.sh --keep-state  # preserve toolkit-install.json for re-run recovery
#   bash scripts/uninstall.sh --help        # show this usage block
```

**D-19 extension:** add (under the `--keep-state` line) `(implies --keep-secrets)` and a new "Secret cleanup" section block in the same comment header. The `sed -n '3,19p'` range at line 35 must extend to cover the new lines (e.g., `'3,28p'`).

---

### Calendly catalog entry — alpha-ordered insert in `scripts/lib/integrations-catalog.json`

**Insertion site (verified):** between `aws-cost-explorer` (lines 36-54) and `cloudflare` (lines 55-72). Insert at line 55 — push existing `cloudflare` block down by ~18 lines. Alphabetic order: `aws-cost-explorer` < `calendly` < `cloudflare`.

**Analog (OAuth-only shape):** `notion` entry at `scripts/lib/integrations-catalog.json:200-215`

```json
"notion": {
  "name": "notion",
  "display_name": "Notion",
  "category": "workspace",
  "env_var_keys": [],
  "install_args": [
    "notion",
    "--",
    "npx",
    "-y",
    "@notionhq/notion-mcp-server"
  ],
  "description": "Workspace pages + databases (OAuth)",
  "requires_oauth": true,
  "default_scope": "user"
}
```

**Calendly entry copies this verbatim with substitutions** (per D-09):

```json
"calendly": {
  "name": "calendly",
  "display_name": "Calendly",
  "category": "workspace",
  "env_var_keys": [],
  "install_args": [
    "calendly",
    "--",
    "<canonical from developer.calendly.com/calendly-mcp-server>"
  ],
  "description": "Scheduling — events, availability, links (OAuth)",
  "requires_oauth": true,
  "default_scope": "user"
}
```

**Field-by-field rationale anchored to existing catalog entries:**
- `category: "workspace"` — already populated by `notion` (line 203). `slack` uses `"communication"`, `jira`/`linear` use `"project-management"`. `workspace` is the closest fit per D-09 (no `scheduling` category exists; CONTEXT D-09 confirms reusing `workspace`).
- `env_var_keys: []` — same as `notion:204`, `playwright:238`. Helper `uninstall_prompt_mcp_keys` D-03 path: empty array → no-op (no prompt).
- `unofficial: false` — **omitted entirely** (matches `notion` at line 200-215, which has no `unofficial` key — official MCPs simply omit the field; only `notebooklm:197` and `telegram:358` set `unofficial: true`).
- `default_scope: "user"` — matches `notion:214`, `slack:303` (per-user OAuth). CONTEXT D-09 explicit.
- `requires_oauth: true` — matches `notion:213`, `notebooklm:196`.
- CLI block omitted — matches `notion` (no entry under `components.cli`); only 8 entries have CLI blocks (per `test-integrations-catalog.sh:163` A8).

**Schema-version impact:** none. Adding an entry does not bump `schema_version` (still 2). Existing test `A5: components.mcp has exactly 20 entries` (`test-integrations-catalog.sh:119`) — **WILL FAIL** after Calendly add (becomes 21). Phase 40 D-14 update bumps the magic number from 20 to 21 in that assertion.

---

### SCOPE-01 validator assertion — already in `scripts/validate-integrations-catalog.py:254-272`

**Already implemented** — verified:

```python
# scripts/validate-integrations-catalog.py:254-272
# Check 11: default_scope must be "user" or "project" (Phase 36 / SCOPE-01).
default_scope = entry.get("default_scope")
if default_scope is None:
    fail(
        location
        + ": .default_scope is required (must be 'user' or 'project')"
    )
    errors += 1
elif default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1
```

Also lines 60-67 explain the deliberate exclusion of `default_scope` from `REQUIRED_ENTRY_KEYS` so that Check 11 always fires its dedicated diagnostic.

**D-11 Phase 40 action:** add the *regression test* in `test-integrations-catalog.sh` (D-14), NOT a re-implementation. Per CONTEXT D-11: "Phase 40 adds the regression test in `test-integrations-catalog.sh` instead of re-implementing."

The closest analog regression assertion is already present at `test-integrations-catalog.sh:275-310` — A15/A16/A17 (default_scope grid). Phase 40 augments by adding a NEGATIVE test (mutated copy missing `default_scope` → validator exits non-zero with the line-pointer message at lines 261-265).

---

### Test extensions in `scripts/tests/test-uninstall-state-cleanup.sh`

**Analog (file structure):** the file itself (`test-uninstall-state-cleanup.sh`, lines 1-249) is the canonical hermetic-sandbox shape. Extend in place per D-12.

```bash
# scripts/tests/test-uninstall-state-cleanup.sh:79-83 — sandbox + seam exports
SANDBOX="$(mktemp -d /tmp/uninstall-state.XXXXXX)"
trap 'rm -rf "${SANDBOX:?}"' EXIT
export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"
```

**Prompt-injection analog:** `scripts/tests/test-uninstall-prompt.sh:127-144`

```bash
# scripts/tests/test-uninstall-prompt.sh:127-144 — STDIN prompt-injection harness
STDIN_INPUT=$(printf 'y\nd\nN\n\n')
OUTPUT=$(printf '%s' "$STDIN_INPUT" | \
    HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    TK_UNINSTALL_FILE_SRC="$SANDBOX/.reference" \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

**D-13 reuse:** Phase 40 does NOT introduce a new TTY seam. `TK_UNINSTALL_TTY_FROM_STDIN=1` is the same seam the new helper reads (per uninstall.sh:354-356). Test scenarios feed `y\n` or `\n` (default-N) on stdin.

**Filesystem-fingerprint analog (D-12 UN-SEC-04):** `scripts/tests/test-uninstall-state-cleanup.sh:67-74` `sha256_any` cross-platform helper:

```bash
# scripts/tests/test-uninstall-state-cleanup.sh:67-74
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
```

**Mode-0600-preservation analog:** none in tests today. Inline new check using `stat`. macOS BSD vs Linux GNU stat is split via `stat -f %p` (BSD) vs `stat -c %a` (GNU); existing `cell-parity.sh` at top-level repo handles this — but the simpler portable check is `[[ "$(ls -l "$cfg" | awk '{print $1}')" == "-rw-------" ]]` which works on both BSD and GNU `ls`.

---

### Test extensions in `scripts/tests/test-integrations-catalog.sh`

**Analog (file structure):** the file itself (lines 1-315) is the canonical schema-test shape. Extend via the `_pyq` helper at line 67.

**Calendly-shape positive assertion analog:** `test-integrations-catalog.sh:200-208` (A10 unofficial-set assertion):

```bash
# scripts/tests/test-integrations-catalog.sh:200-208 — set-membership assertion via python3
_pyq "A10: unofficial set == {notebooklm, telegram}" '
mcp = catalog.get("components", {}).get("mcp", {})
unofficial = sorted([n for n, e in mcp.items() if e.get("unofficial") is True])
expected = ["notebooklm", "telegram"]
if unofficial == expected:
    print("OK")
else:
    print("unofficial set is " + repr(unofficial) + ", expected " + repr(expected))
'
```

**Phase 40 lifts this shape** for both the Calendly positive shape assertion and the Google Workspace negative assertion (D-14):

```bash
# A18 (Phase 40 D-14 — positive Calendly shape)
_pyq "A18: calendly entry has expected shape" '
mcp = catalog.get("components", {}).get("mcp", {})
e = mcp.get("calendly", {})
if (e.get("requires_oauth") is True
    and e.get("default_scope") == "user"
    and e.get("env_var_keys") == []
    and e.get("unofficial") is not True
    and e.get("category") == "workspace"):
    print("OK")
else:
    print("calendly shape mismatch: " + repr(e))
'

# A19 (Phase 40 D-14 — Google Workspace negative)
_pyq "A19: no google-* MCP entries (INT-14 lock)" '
import re
mcp = catalog.get("components", {}).get("mcp", {})
pat = re.compile(r"^google-(workspace|drive|gmail|calendar)$")
hits = [n for n in mcp if pat.match(n)]
if not hits:
    print("OK")
else:
    print("forbidden google-* entries present: " + repr(hits))
'
```

**SCOPE-01 negative analog:** there is no negative-mutated-copy pattern in `test-integrations-catalog.sh` today. Closest pattern is `_pyq` itself (always reads the on-disk catalog). For D-14 missing-`default_scope` negative, Phase 40 must:

1. Copy `$CATALOG` to a temp file (`mktemp -t catalog-mut.XXXXXX`).
2. Use python3 to delete the `default_scope` field from one entry.
3. Run `python3 scripts/validate-integrations-catalog.py "$tmp_catalog"` (the validator already accepts a positional path arg per validator line 93).
4. Assert exit code == 1 AND stderr contains `default_scope is required`.

---

## Shared Patterns

### TTY read with fail-closed N
**Source:** `scripts/uninstall.sh:353-371` (with `TK_UNINSTALL_TTY_FROM_STDIN` seam)
**Apply to:** `uninstall_prompt_mcp_keys` (per-MCP) AND full-toolkit `mcp-config.env` prompt (D-01, D-05).
**Defining excerpt at line 354-356 + 362-371 (above).**

### Atomic mode-0600-preserving rewrite via mktemp+mv+chmod
**Source:** `scripts/lib/mcp.sh:553-583 mcp_secrets_set` (5-step write→mv→chmod)
**Apply to:** the `uninstall_prompt_mcp_keys` rewrite half (D-02).
**Excerpt above.** Same contract: `mkdir -p` → `touch` → `chmod 0600` (pre) → `mktemp` → loop+`printf` → `mv` → `chmod 0600` (post).

### KEEP_STATE gate as a triple-purpose skip
**Source:** `scripts/uninstall.sh:25 + 826`
**Apply to:** D-07 — the same `[[ $KEEP_STATE -eq 0 ]]` gate now wraps:
1. The new MCP-loop `uninstall_prompt_mcp_keys` call.
2. The new full-toolkit `mcp-config.env` block.
3. The existing STATE_FILE block (unchanged).

### `[dry-run] would …` print convention
**Source:** `scripts/propagate-audit-pipeline-v42.sh:396` + `scripts/migrate-to-complement.sh:245`
**Apply to:** Phase 40 D-08 dry-run prints (helper-internal + full-toolkit prompt).
**Format:** `echo "[dry-run] would prompt: ..."` — plain `echo`, no log_helper, no special function. Matches existing two call sites verbatim.

### bash 3.2-safe array-length guard
**Source:** `scripts/uninstall.sh:663, 708, 723, 752, 762, 769, ...` — the project-wide invariant per CONTEXT D-16
**Apply to:** every new `for ... in "${ARRAY[@]}"` in Phase 40.
**Pattern:** `if [[ ${#ARRAY[@]} -gt 0 ]]; then for x in "${ARRAY[@]}"; do ...; done; fi` — NEVER inline `${ARRAY[@]:-}` default modifier (CLAUDE.md project invariant + uninstall.sh:708 explicit comment).

### Catalog `_pyq` schema test
**Source:** `scripts/tests/test-integrations-catalog.sh:67-86`
**Apply to:** all D-14 catalog test additions (A18 Calendly shape, A19 Google Workspace negative). Inline python3 heredoc returns "OK" or a diagnostic string.

### Hermetic sandbox + `TK_UNINSTALL_HOME` seam
**Source:** `scripts/tests/test-uninstall-state-cleanup.sh:79-150`
**Apply to:** all D-12 new scenarios (UN-SEC-01-Y/N, UN-SEC-03-Y/N, UN-SEC-04, UN-SEC-05). `mktemp -d` + `trap 'rm -rf' EXIT` + `export TK_UNINSTALL_HOME="$SANDBOX"` + state file fixture.

---

## No Analog Found / Already-Implemented

| Item | Status | Resolution |
|------|--------|------------|
| `scripts/validate-integrations-catalog.py` SCOPE-01 assertion | **Already implemented** at lines 254-272 (Phase 36 work) | Phase 40 D-11: skip implementation, add regression test in `test-integrations-catalog.sh` per D-14 (A18-style negative scenario) |
| `installed_mcps[]` field in `toolkit-install.json` | **Does not exist** in v5.0 state shape (verified in `lib/state.sh:117-129`) | Phase 40 D-04 fallback: parse `claude mcp list` output via `_mcp_list_cache_init` (`lib/mcp.sh:384-402`); intersect with `mcp_catalog_names` (`lib/mcp.sh:360`). Skip silently when `claude` CLI absent. |
| `mcp.sh` sourcing in `uninstall.sh` | **Not currently sourced** (only state.sh, backup.sh, dry-run-output.sh, bridges.sh per `uninstall.sh:122`) | Phase 40 must add `mcp.sh` to the sourcing loop, copying the `TK_UNINSTALL_LIB_DIR` test-seam pattern verbatim. Required to call `mcp_secrets_load`, `_mcp_config_path`, `_mcp_list_cache_init`, `mcp_catalog_names`. |
| Mode-0600 stat assertion in tests | **No prior test** asserts file mode | Use portable `[[ "$(ls -l "$cfg" | awk '{print $1}')" == "-rw-------" ]]` (works on macOS BSD and GNU `ls`). Avoid `stat -f` / `stat -c` divergence (D-16 BSD compat). |
| Filesystem-fingerprint diff for `*.env` outside `~/.claude/` (D-12 UN-SEC-04) | **No prior test** does this | Implement inline using `find "$SANDBOX" -name '.env' -not -path "*.claude/*" -exec sha256_any {} \;` snapshotted before/after, then `diff` the two snapshots. Reuse `sha256_any` helper at `test-uninstall-state-cleanup.sh:67`. |

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/lib/`, `scripts/tests/`
**Files scanned:** uninstall.sh (838 lines), install.sh (~970 lines), lib/mcp.sh (1387 lines), lib/project-secrets.sh (315 lines), lib/state.sh (~150 lines), lib/tui.sh (relevant tui_tty_read), lib/dry-run-output.sh (75 lines), lib/integrations-catalog.json (448 lines), validate-integrations-catalog.py (294 lines), tests/test-uninstall-state-cleanup.sh (249 lines), tests/test-uninstall-prompt.sh (220+ lines), tests/test-uninstall-keep-state.sh, tests/test-integrations-catalog.sh (314 lines)
**Pattern extraction date:** 2026-05-05
