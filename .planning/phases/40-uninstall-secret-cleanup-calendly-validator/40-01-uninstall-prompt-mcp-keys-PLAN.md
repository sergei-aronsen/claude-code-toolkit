---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/uninstall.sh
autonomous: true
requirements:
  - UN-SEC-01
  - UN-SEC-02

must_haves:
  truths:
    - "uninstall.sh sources scripts/lib/mcp.sh (so mcp_secrets_load, _mcp_config_path, mcp_catalog_names, _mcp_list_cache_init are callable)"
    - "uninstall.sh defines uninstall_prompt_mcp_keys <name> [<key>...] that prompts via /dev/tty (or TK_UNINSTALL_TTY_FROM_STDIN seam) with [y/N], default N, fail-closed N on no-TTY"
    - "On Y, uninstall_prompt_mcp_keys atomically rewrites ~/.claude/mcp-config.env via mktemp+mv+chmod 0600, dropping ONLY the named MCP's keys; other MCPs' entries are preserved byte-identical"
    - "uninstall.sh has a per-MCP loop that recovers MCP names by intersecting `claude mcp list` output with mcp_catalog_names() (fallback path because installed_mcps[] is absent from toolkit-install.json today), runs `claude mcp remove --scope user <name>` for each, then calls uninstall_prompt_mcp_keys with that MCP's env_var_keys"
    - "When called with zero keys (e.g., Calendly OAuth-only), the helper returns 0 with no prompt and no rewrite (defensive empty-array handling per CONTEXT D-03)"
    - "Helper is idempotent — re-running after a successful prune emits zero matches in the skip set, so the file is unchanged"
    - "The new MCP loop is silently skipped when `claude` CLI is absent (matches v4.4 LIB-01 D-09 fail-soft contract)"
  artifacts:
    - path: "scripts/uninstall.sh"
      provides: "uninstall_prompt_mcp_keys function + first claude-mcp-remove loop in uninstall.sh + lib/mcp.sh added to sourcing loop"
      contains: "uninstall_prompt_mcp_keys"
  key_links:
    - from: "uninstall.sh sourcing loop (~line 122)"
      to: "scripts/lib/mcp.sh"
      via: "TK_UNINSTALL_LIB_DIR test-seam pattern, mirrors existing state.sh / backup.sh / dry-run-output.sh / bridges.sh entries"
      pattern: 'mcp\.sh:'
    - from: "uninstall_prompt_mcp_keys"
      to: "/dev/tty"
      via: "tty_target=/dev/tty default; TK_UNINSTALL_TTY_FROM_STDIN=1 redirects to /dev/stdin (test seam, D-13)"
      pattern: 'TK_UNINSTALL_TTY_FROM_STDIN'
    - from: "uninstall_prompt_mcp_keys"
      to: "mcp-config.env atomic rewrite"
      via: "mktemp \"${cfg}.XXXXXX\" → printf loop with skip-set membership → mv → chmod 0600"
      pattern: 'mktemp.*\.XXXXXX'
    - from: "new MCP loop"
      to: "uninstall_prompt_mcp_keys"
      via: "per-iteration `claude mcp remove --scope user <name>` then helper call with env_var_keys word-split"
      pattern: 'claude.*mcp.*remove'
---

<objective>
Add the `uninstall_prompt_mcp_keys` helper and the FIRST `claude mcp remove` loop to `scripts/uninstall.sh`, satisfying UN-SEC-01 (per-MCP key cleanup prompt) and UN-SEC-02 (call-site wiring after each `claude mcp remove`).

Purpose: Today `scripts/uninstall.sh` has zero MCP-aware logic — there are no `claude mcp remove` invocations, and `~/.claude/mcp-config.env` is never touched on uninstall. That is a secrets-leak: when a user removes the toolkit, every API key they ever entered for any MCP stays plaintext on disk forever. This plan closes the per-MCP half of that gap. The helper prompts the user `[y/N] also remove keys K1, K2 from ~/.claude/mcp-config.env?` immediately after each `claude mcp remove <name>`, defaults to N, fails closed on no-TTY, and on Y atomically rewrites `mcp-config.env` excluding ONLY the named MCP's keys (other MCPs' entries preserved). Mode 0600 maintained before and after rewrite. Empty-keys case (e.g., Calendly OAuth-only) is a no-op.

Output: `scripts/uninstall.sh` modified with (a) `lib/mcp.sh` added to sourcing loop, (b) new `uninstall_prompt_mcp_keys` function, (c) new per-MCP loop that recovers MCP names from `claude mcp list` ∩ `mcp_catalog_names`, runs `claude mcp remove --scope user <name>` per MCP, and calls the helper with that MCP's `env_var_keys` from the catalog.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-CONTEXT.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-PATTERNS.md
@scripts/uninstall.sh
@scripts/lib/mcp.sh
@scripts/lib/integrations-catalog.json

<interfaces>
<!-- Key contracts the executor needs. Embedded here to avoid scavenger-hunt. -->

From scripts/uninstall.sh (existing — DO NOT modify these symbols):

- KEEP_STATE: int (0|1) — pre-existing flag, read at line ~25 from TK_UNINSTALL_KEEP_STATE
- DRY_RUN: int (0|1) — pre-existing flag
- STATE_FILE: string path — pre-existing variable
- log_info / log_success / log_warning / log_error — pre-existing logger functions
- prompt_modified_for_uninstall (line ~300) — TTY-prompt analog with TK_UNINSTALL_TTY_FROM_STDIN seam at lines 353-356, fail-closed N pattern at lines 362-371

Existing sourcing loop (around line 122):
```bash
for lib_pair in "state.sh:..." "backup.sh:..." "dry-run-output.sh:..." "bridges.sh:..."; do
    # source from "${TK_UNINSTALL_LIB_DIR:-$DEFAULT_LIB_DIR}/$lib_name"
done
```
This plan ADDS `mcp.sh:...` to that list (Phase 40 PATTERNS.md "No Analog Found" #3).

From scripts/lib/mcp.sh (sourceable, side-effect-free at source time):

- mcp_secrets_load() — populates global parallel arrays MCP_SECRET_KEYS[] and MCP_SECRET_VALUES[] from `${TK_MCP_CONFIG_HOME:-$HOME}/.claude/mcp-config.env`
- _mcp_config_path() — echoes the resolved mcp-config.env path; honors TK_MCP_CONFIG_HOME / TK_UNINSTALL_HOME
- mcp_catalog_names() — echoes one MCP name per line from integrations-catalog.json
- _mcp_list_cache_init() — populates an internal cache from `claude mcp list`; returns "__no_cli__" sentinel when claude CLI is absent
- is_mcp_installed <name> — returns 0 if MCP is registered with claude CLI

From scripts/install.sh (line 686-687) — the only existing `claude mcp remove` call site, copied verbatim:
```bash
_scope_for_rm="${TK_MCP_SCOPE:-user}"
"$_claude_bin" mcp remove --scope "$_scope_for_rm" "$local_name" >/dev/null 2>&1 || true
```

Catalog field used:
- jq path: `.components.mcp[$name].env_var_keys[]` — newline-separated list of env var names for an MCP (may be empty array, e.g., Calendly/Notion OAuth-only)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Source lib/mcp.sh from uninstall.sh + add uninstall_prompt_mcp_keys helper</name>
  <files>scripts/uninstall.sh</files>
  <action>
Two edits in `scripts/uninstall.sh`:

**Edit A — add `mcp.sh` to the existing sourcing loop (~line 122):**
The current loop sources `state.sh`, `backup.sh`, `dry-run-output.sh`, `bridges.sh`. Append `mcp.sh:<short-purpose>` to that list using the EXACT same `lib_pair` tuple shape and `TK_UNINSTALL_LIB_DIR` test-seam already used. Do not touch other sourcing entries; do not reorder; do not change error handling. Verify by grep that `lib/mcp.sh` is now sourced exactly once after the change.

**Edit B — define `uninstall_prompt_mcp_keys` near the existing `prompt_modified_for_uninstall` (after that function, same file):**

Function signature: `uninstall_prompt_mcp_keys <name> [<key1> <key2> ...]`

Behavior (verbatim contract per CONTEXT D-01..D-03 + D-08):

1. Argument guard: `if [[ $# -lt 2 ]]; then return 0; fi` — name only, zero keys (Calendly/OAuth-only) → no-op (per D-03 defensive empty-array handling).
2. Capture name and shift; remaining `$@` is the key list. Build `local skip_keys=" $* "` (space-padded for word-boundary `case` match — Bash 3.2-safe; no associative array per CONTEXT D-16).
3. Resolve `cfg="$(_mcp_config_path)"`. If `[[ ! -f "$cfg" ]]` → `return 0` (nothing to clean up).
4. **Dry-run gate (D-08):** `if [[ ${DRY_RUN:-0} -eq 1 ]]; then echo "[dry-run] would prompt: also remove keys ${*} from $cfg?"; return 0; fi` — plain `echo`, no prompt, no rewrite (matches `[dry-run]` convention from `propagate-audit-pipeline-v42.sh:396` and `migrate-to-complement.sh:245`).
5. **TTY resolution (mirrors prompt_modified_for_uninstall:353-356):**
   ```bash
   local tty_target="/dev/tty"
   [[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && tty_target="/dev/stdin"
   ```
6. **Prompt + fail-closed-N read (mirrors prompt_modified_for_uninstall:362-371, 5-attempt cap):**
   - Format the human-readable key list (comma-separated): build `local key_csv` by iterating positional args once.
   - `read -r -p "[y/N] also remove keys ${key_csv} from mcp-config.env? " choice < "$tty_target" 2>/dev/null` — on read failure, set `choice="N"`, increment fail counter, return 0 after 5 failures.
   - `case "${choice:-N}" in y|Y) ...rewrite path... ;; *) return 0 ;; esac` — default N is the only side-effect-free path.
7. **Rewrite path (Y branch, mirrors mcp_secrets_set:553-583 with skip-set inversion per CONTEXT D-02):**
   ```bash
   mcp_secrets_load                              # populates MCP_SECRET_KEYS[] / MCP_SECRET_VALUES[]
   chmod 0600 "$cfg" 2>/dev/null || true        # pre-write 0600 (defensive; file might be missing perms)
   local tmp
   tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
   local i any_drop=0
   if [[ ${#MCP_SECRET_KEYS[@]} -gt 0 ]]; then
       for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
           case "$skip_keys" in
               *" ${MCP_SECRET_KEYS[$i]} "*) any_drop=1; continue ;;
               *) printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp" ;;
           esac
       done
   fi
   mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
   chmod 0600 "$cfg" || return 1
   ```
   Note: `any_drop` is informational (used for the `log_success` line); idempotent re-run prints "no matching keys found" and still rewrites the file byte-identically.
8. Final `log_success "Removed ${name} keys from ${cfg}"` on Y, no log on N.

Bash 3.2 / macOS BSD invariants (CONTEXT D-16): no `mapfile`, no `${var,,}`, no `realpath -f`, no `declare -A`, no `read -N`, no `read -t`. Use `[[ ${#ARRAY[@]} -gt 0 ]]` guard before any `for x in "${ARRAY[@]}"`.

Per D-04 / SC-3: `set -euo pipefail` is already at script top — do not duplicate. Do not introduce subshells around the rewrite (atomic mv would be defeated).

Per CLAUDE.md global security rules: never log key values; the helper logs only key NAMES, never their values. The `printf '%s=%s\n'` line writes pre-existing values back unchanged — no new value derivation, no echo of values to stdout/stderr.
  </action>
  <verify>
    <automated>bash -n scripts/uninstall.sh && shellcheck -S warning scripts/uninstall.sh && grep -q 'uninstall_prompt_mcp_keys' scripts/uninstall.sh && grep -c '"mcp.sh:' scripts/uninstall.sh | grep -q '^1$'</automated>
  </verify>
  <done>
    - `bash -n scripts/uninstall.sh` exits 0
    - `shellcheck -S warning scripts/uninstall.sh` exits 0
    - `grep -n 'uninstall_prompt_mcp_keys' scripts/uninstall.sh` shows the function definition exactly once
    - `lib/mcp.sh` appears exactly once in the sourcing loop
    - `grep -n 'TK_UNINSTALL_TTY_FROM_STDIN' scripts/uninstall.sh` shows the helper reuses the existing seam (no new env var introduced)
    - `grep -n 'mktemp.*\.XXXXXX' scripts/uninstall.sh` shows the atomic-rewrite pattern present
  </done>
</task>

<task type="auto">
  <name>Task 2: Add per-MCP loop (claude mcp remove + uninstall_prompt_mcp_keys call)</name>
  <files>scripts/uninstall.sh</files>
  <action>
Insert a new MCP-cleanup block in `scripts/uninstall.sh`. Placement: AFTER all current per-row file processing (`MODIFIED_LIST` loop, etc.), BEFORE the eventual `STATE_FILE` removal block at line ~824. The block sits in the same final-stage region as the upcoming Plan 40-02 full-toolkit prompt — Plan 40-02 will add its block immediately downstream of this one.

Block shape (per PATTERNS.md "Per-MCP `claude mcp remove` loop" section):

```bash
# ───────── Phase 40 UN-SEC-01/02: per-MCP cleanup loop ─────────
# Recover MCP names from `claude mcp list` ∩ mcp_catalog_names (installed_mcps[]
# does not exist in toolkit-install.json today — see PATTERNS.md "No Analog Found" #2).
INSTALLED_MCPS=()
if command -v "${TK_MCP_CLAUDE_BIN:-claude}" >/dev/null 2>&1; then
    # Initialize cache (returns "__no_cli__" sentinel on error — silently skip then)
    _list_init_rc=0
    _mcp_list_cache_init >/dev/null 2>&1 || _list_init_rc=$?
    if [[ $_list_init_rc -eq 0 ]]; then
        # Iterate catalog names; keep only those is_mcp_installed reports as registered
        while IFS= read -r _cat_name; do
            [[ -z "$_cat_name" ]] && continue
            if is_mcp_installed "$_cat_name"; then
                INSTALLED_MCPS+=("$_cat_name")
            fi
        done <<EOF
$(mcp_catalog_names)
EOF
    fi
fi

if [[ ${#INSTALLED_MCPS[@]} -gt 0 ]]; then
    echo ""
    log_info "${#INSTALLED_MCPS[@]} MCP(s) registered by toolkit. Removing…"
    _catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path 2>/dev/null || echo "")}"
    for _mcp_name in "${INSTALLED_MCPS[@]}"; do
        # Step 1: claude mcp remove (mirrors install.sh:687)
        if [[ ${DRY_RUN:-0} -eq 1 ]]; then
            echo "[dry-run] would run: claude mcp remove --scope user $_mcp_name"
        else
            "${TK_MCP_CLAUDE_BIN:-claude}" mcp remove --scope user "$_mcp_name" >/dev/null 2>&1 || true
        fi
        # Step 2: per-MCP key cleanup prompt (D-04 — call uninstall_prompt_mcp_keys)
        # Read env_var_keys from catalog as whitespace-separated list. Empty list →
        # helper short-circuits at `[[ $# -lt 2 ]]` (Calendly/OAuth-only no-op per D-03).
        _keys=""
        if [[ -n "$_catalog_path" && -f "$_catalog_path" ]]; then
            _keys="$(jq -r --arg n "$_mcp_name" \
                '.components.mcp[$n].env_var_keys // [] | join(" ")' \
                "$_catalog_path" 2>/dev/null || echo "")"
        fi
        # shellcheck disable=SC2086 -- intentional whitespace word-split on key list
        uninstall_prompt_mcp_keys "$_mcp_name" $_keys
    done
fi
```

**Critical placement constraints:**
- This block goes BEFORE the `STATE_FILE` removal at line ~824 — UN-05 D-06 ordering invariant (STATE_FILE removal stays LAST).
- Do NOT wrap this block in `KEEP_STATE` gate yet — Plan 40-03 adds that gate (UN-SEC-05). For this plan, the loop runs whenever there are installed MCPs.
- Use `if [[ ${#INSTALLED_MCPS[@]} -gt 0 ]]` guard — Bash 3.2 array-length pattern (uninstall.sh:708, 723, 752 precedent).
- All temp/iteration variables prefixed with `_` to avoid colliding with the surrounding script's globals.

**Bash 3.2 invariants (CONTEXT D-16):**
- No `mapfile`. The `while IFS= read -r ... <<EOF` pattern reads `mcp_catalog_names` line-by-line into the array.
- No `declare -A`. The skip-set in helper Task 1 used a string. This loop uses a plain indexed array `INSTALLED_MCPS`.
- The heredoc terminator `EOF` is unindented — required by Bash 3.2 (no `<<-` indent stripping unless tab-indented; safer to just leave column 0).
- `command -v` is POSIX, present on macOS BSD.

**Graceful degradation (D-04 + PATTERNS.md "No Analog Found" #2):**
- `claude` CLI absent → `command -v` false → `INSTALLED_MCPS` stays empty → outer guard skips the block → no error, no log noise. Matches v4.4 LIB-01 D-09 fail-soft contract.
- Catalog unreadable → `_keys=""` → helper called with name only → helper short-circuits at `$# -lt 2`.

**Security review (CLAUDE.md §3 doubt protocol):**
- `jq -r --arg n "$_mcp_name"` — name passed via `--arg`, not interpolated into the filter. Prevents jq injection if a malicious catalog entry contained shell metacharacters in its name.
- `"$_mcp_name"` is sourced from `mcp_catalog_names()` (toolkit-controlled, not user input), then validated by `is_mcp_installed`. No untrusted-input concern.
- `claude mcp remove --scope user "$_mcp_name"` — name quoted; no shell injection.
- No file operations against paths outside `~/.claude/` (UN-SEC-04 boundary preserved).
  </action>
  <verify>
    <automated>bash -n scripts/uninstall.sh && shellcheck -S warning scripts/uninstall.sh && grep -q 'INSTALLED_MCPS' scripts/uninstall.sh && grep -q 'claude.*mcp.*remove.*--scope.*user' scripts/uninstall.sh && grep -q 'uninstall_prompt_mcp_keys "\$_mcp_name"' scripts/uninstall.sh</automated>
  </verify>
  <done>
    - `bash -n scripts/uninstall.sh` clean
    - `shellcheck -S warning scripts/uninstall.sh` clean
    - The new loop appears BEFORE the `STATE_FILE` removal block (verify via line numbers — `grep -n INSTALLED_MCPS scripts/uninstall.sh` < `grep -n 'rm -f "$STATE_FILE"' scripts/uninstall.sh`)
    - `grep -n 'is_mcp_installed' scripts/uninstall.sh` shows the recovery path uses the existing helper
    - With `claude` CLI absent (mock by setting `TK_MCP_CLAUDE_BIN=/nonexistent`), running `bash scripts/uninstall.sh --dry-run` does not error and does not print any MCP-loop output
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → uninstall.sh stdin (TTY) | Untrusted single-char input (`y`/`Y`/anything else) crosses here; routed through `read -r` with case-match — no eval, no shell expansion |
| catalog file (`integrations-catalog.json`) → jq → shell word-split | MCP names + env_var_keys are toolkit-controlled (committed to repo) but theoretically attacker-mutable on user disk; mitigated via `jq -r --arg` (no filter interpolation) and quoted shell expansion |
| `claude mcp list` output → bash array | External CLI output crossing in; only used for membership intersection with toolkit catalog (never executed) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-01-01 | Tampering | mcp-config.env atomic rewrite | mitigate | mktemp+mv+chmod 0600 (pre & post); permission preserved across rewrite. Rules out partial-write race because `mv` is atomic on same filesystem |
| T-40-01-02 | Information Disclosure | helper log lines | mitigate | Helper logs only KEY NAMES, never VALUES. `printf '%s=%s\n' "$key" "$value" >> "$tmp"` writes value to disk file (mode 0600) — never to stdout/stderr |
| T-40-01-03 | Denial of Service | TTY read fail-loop | mitigate | 5-attempt cap then `return 0` (mirrors prompt_modified_for_uninstall:362-371). No infinite loop possible |
| T-40-01-04 | Elevation of Privilege | jq filter injection | mitigate | `jq --arg n "$_mcp_name"` (name as JSON variable, not interpolated into filter string). Defense-in-depth even though name source is toolkit catalog |
| T-40-01-05 | Spoofing | Fake `claude` binary on PATH | accept | Acceptable risk: if attacker has write access to user's PATH directories, they can already exfiltrate `mcp-config.env` directly. The `claude mcp remove` call uses `>/dev/null 2>&1 || true` which contains stdout/stderr leakage |
| T-40-01-06 | Repudiation | Lost audit log of removed keys | accept | Solo-developer tool — no audit-log requirement. `log_success` line records the action; sufficient for ad-hoc debugging |
</threat_model>

<verification>
- `bash -n scripts/uninstall.sh` parses clean
- `shellcheck -S warning scripts/uninstall.sh` reports no warnings (project baseline)
- `make shellcheck` (project root) stays green
- `grep -n 'uninstall_prompt_mcp_keys' scripts/uninstall.sh` shows: 1 definition + 1 call site
- `grep -n 'mcp.sh:' scripts/uninstall.sh` shows 1 line in sourcing loop
- Re-running `bash scripts/uninstall.sh --dry-run` is idempotent: prints `[dry-run] would prompt: ...` lines, makes zero filesystem writes
- Helper signature: `uninstall_prompt_mcp_keys <name> [<key>...]` — name-only call returns 0 silently (Calendly/OAuth-only contract)
</verification>

<success_criteria>
- `lib/mcp.sh` sourced from `uninstall.sh` (verified by grep)
- New helper `uninstall_prompt_mcp_keys` defined exactly once
- Helper honors `TK_UNINSTALL_TTY_FROM_STDIN` test seam (no new seam introduced)
- Helper rewrites `mcp-config.env` atomically (mktemp + mv + chmod 0600, both pre and post)
- Helper drops only the named MCP's keys; preserves all other MCPs' keys byte-identically (verified later in Plan 40-05 tests)
- Helper short-circuits cleanly when called with zero keys (Calendly/OAuth-only path)
- Helper short-circuits cleanly under `--dry-run` (prints `[dry-run] would prompt: ...`, no filesystem writes)
- New per-MCP loop recovers names via `claude mcp list` ∩ `mcp_catalog_names`
- Loop calls `claude mcp remove --scope user <name>` then `uninstall_prompt_mcp_keys <name> <keys>` per MCP
- Loop is silently skipped when `claude` CLI is absent
- Loop placement: AFTER MODIFIED_LIST block, BEFORE STATE_FILE removal (UN-05 D-06 ordering preserved)
- Bash 3.2 / macOS BSD invariants: no `mapfile`, no `${var,,}`, no `realpath -f`, no `declare -A`, no `read -N`, no `read -t`
- `set -euo pipefail` already at script top — no duplicate added
</success_criteria>

<output>
After completion, create `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-01-SUMMARY.md` summarizing:
- Final line numbers of the new helper and the new loop in `uninstall.sh`
- Confirmation that `lib/mcp.sh` is in the sourcing loop
- Confirmation that helper passes `bash -n` + `shellcheck -S warning`
- Confirmation that idempotent re-run leaves `mcp-config.env` unchanged when no keys match
- Note that UN-SEC-03 (full-toolkit prompt) lands in Plan 40-02 immediately downstream of this loop
</output>
