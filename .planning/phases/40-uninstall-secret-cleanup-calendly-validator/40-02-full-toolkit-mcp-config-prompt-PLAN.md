---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 2
type: execute
wave: 2
depends_on:
  - 40-01
files_modified:
  - scripts/uninstall.sh
autonomous: true
requirements:
  - UN-SEC-03

must_haves:
  truths:
    - "After the per-MCP loop (Plan 40-01) finishes, uninstall.sh prompts ONCE: `[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?`"
    - "Default N preserves the file; Y removes the file with `rm -f`"
    - "Prompt is fail-closed N on no-TTY (reuses TK_UNINSTALL_TTY_FROM_STDIN seam)"
    - "Prompt is silently skipped when ~/.claude/mcp-config.env does not exist"
    - "On Y, mcp-config.env removal happens BEFORE STATE_FILE removal (UN-05 D-06 ordering preserved — STATE_FILE stays LAST)"
    - "Under --dry-run, no prompt is shown; instead `[dry-run] would prompt: also remove ~/.claude/mcp-config.env?` is printed; no rm executed"
    - "X (key count) and Y (MCP count) are computed from mcp_secrets_load output — X = ${#MCP_SECRET_KEYS[@]}, Y = distinct MCP_<NAME>_ prefix count"
  artifacts:
    - path: "scripts/uninstall.sh"
      provides: "Full-toolkit mcp-config.env cleanup prompt block, sitting between the per-MCP loop and the STATE_FILE block"
      contains: "also remove .*mcp-config.env"
  key_links:
    - from: "Phase 40 full-toolkit prompt block"
      to: "_mcp_config_path()"
      via: "MCP_CFG=\"$(_mcp_config_path)\""
      pattern: '_mcp_config_path'
    - from: "Phase 40 full-toolkit prompt block"
      to: "mcp_secrets_load"
      via: "key + MCP count derivation for the human-readable label"
      pattern: 'mcp_secrets_load'
    - from: "Phase 40 full-toolkit prompt block"
      to: "STATE_FILE removal block"
      via: "Adjacent placement upstream (UN-05 D-06 ordering: rm mcp-config.env → rm STATE_FILE LAST)"
      pattern: 'STATE_FILE'
---

<objective>
Add the full-toolkit `mcp-config.env` cleanup prompt to `scripts/uninstall.sh`, satisfying UN-SEC-03.

Purpose: Plan 40-01 closes the per-MCP half of the secrets-leak (each MCP has its keys pruned at remove time). But there's a residual concern: even after every per-MCP prompt, the file `~/.claude/mcp-config.env` itself remains on disk, mode 0600, full of API keys for whichever MCPs the user said "N" to. UN-SEC-03 is a single safety-net prompt at the end of the MCP loop: `[y/N] also remove ~/.claude/mcp-config.env (X keys for Y MCPs)?` Default N (the user may legitimately keep the file independent of toolkit lifecycle — they can re-install later). Y removes the file. Critical ordering: this `rm` runs BEFORE the LAST-step `STATE_FILE` removal so that the v4.3 D-06 invariant (STATE_FILE removal LAST) stays intact.

Output: `scripts/uninstall.sh` modified with one new block (full-toolkit prompt + `rm -f mcp-config.env` on Y) inserted between the Plan 40-01 per-MCP loop and the existing `STATE_FILE` block at line ~824.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-CONTEXT.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-PATTERNS.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-01-SUMMARY.md
@scripts/uninstall.sh
@scripts/lib/mcp.sh

<interfaces>
<!-- Symbols already loaded by Plan 40-01 -->

From scripts/lib/mcp.sh (sourced by uninstall.sh after Plan 40-01):
- _mcp_config_path() — echoes resolved mcp-config.env path; honors TK_MCP_CONFIG_HOME / TK_UNINSTALL_HOME
- mcp_secrets_load — populates parallel arrays MCP_SECRET_KEYS[] and MCP_SECRET_VALUES[]
  (Note: keys are stored with full prefix `MCP_<NAME>_<KEYNAME>` — distinct MCP count = unique `MCP_<NAME>_` prefixes)

From scripts/uninstall.sh (existing):
- KEEP_STATE: int — pre-existing flag (Plan 40-03 will gate this block too)
- DRY_RUN: int — pre-existing flag (used here for dry-run print)
- STATE_FILE: string — LAST removal target (line ~824 block)
- log_success / log_info / log_warning — existing loggers
- TK_UNINSTALL_TTY_FROM_STDIN: test seam — same one Plan 40-01 helper uses

Catalog of `[dry-run] would …` prints (existing convention):
- scripts/propagate-audit-pipeline-v42.sh:396 — `echo "[dry-run] would splice: ..."`
- scripts/migrate-to-complement.sh:245 — `echo "    [dry-run] would offer ..."`
Plan 40-02 follows the same plain-`echo` style.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Insert full-toolkit mcp-config.env cleanup prompt block</name>
  <files>scripts/uninstall.sh</files>
  <action>
Insert one new block in `scripts/uninstall.sh`. Placement: IMMEDIATELY AFTER the Plan 40-01 per-MCP loop (`if [[ ${#INSTALLED_MCPS[@]} -gt 0 ]]; then ... fi`), and IMMEDIATELY BEFORE the existing `STATE_FILE` removal block (line ~824 `if [[ $KEEP_STATE -eq 0 ]]; then rm -f "$STATE_FILE" ...`).

UN-05 D-06 ordering invariant (REQUIRES PRESERVATION):
1. ... existing modified-files / bridges / state-driven removals
2. NEW (Plan 40-01): per-MCP loop with `claude mcp remove` + `uninstall_prompt_mcp_keys`
3. NEW (this plan): `mcp-config.env` removal prompt + `rm -f`
4. EXISTING (UNCHANGED): `STATE_FILE` removal — STAYS LAST per D-06

Block shape (per CONTEXT D-05 + PATTERNS.md "Full-toolkit `mcp-config.env` cleanup prompt"):

```bash
# ───────── Phase 40 UN-SEC-03: full-toolkit mcp-config.env cleanup prompt ─────────
# Sits BEFORE the STATE_FILE block to preserve v4.3 UN-05 D-06 ordering invariant.
# NOTE: KEEP_STATE gating for this block lands in Plan 40-03 (UN-SEC-05).
MCP_CFG="$(_mcp_config_path 2>/dev/null || echo "")"
if [[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]; then
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        echo "[dry-run] would prompt: also remove $MCP_CFG?"
    else
        # Compute X (total keys) and Y (distinct MCPs) for the prompt label
        mcp_secrets_load
        _n_keys=${#MCP_SECRET_KEYS[@]}
        # Y = distinct MCP_<NAME>_ prefix count from MCP_SECRET_KEYS[]
        # Bash 3.2: no associative array; sort -u over derived prefix list
        _n_mcps=0
        if [[ $_n_keys -gt 0 ]]; then
            _n_mcps=$(
                _i=0
                while [[ $_i -lt $_n_keys ]]; do
                    # Strip leading "MCP_" then the LAST "_<KEYNAME>" via parameter expansion
                    _k="${MCP_SECRET_KEYS[$_i]}"
                    # Match shape: MCP_<NAME>_<KEY>. Take everything between first "MCP_" and last "_".
                    _stripped="${_k#MCP_}"   # NAME_KEY
                    _name="${_stripped%_*}"  # NAME
                    echo "$_name"
                    _i=$((_i + 1))
                done | sort -u | wc -l | tr -d ' '
            )
        fi

        _tty_target="/dev/tty"
        [[ -n "${TK_UNINSTALL_TTY_FROM_STDIN:-}" ]] && _tty_target="/dev/stdin"
        _choice=""
        if ! read -r -p "[y/N] also remove $MCP_CFG ($_n_keys keys for $_n_mcps MCPs)? " \
                _choice < "$_tty_target" 2>/dev/null; then
            _choice="N"   # fail-closed N on no-TTY (mirrors UN-03)
        fi
        case "${_choice:-N}" in
            y|Y)
                if rm -f "$MCP_CFG"; then
                    log_success "Removed: $MCP_CFG"
                else
                    log_warning "Failed to remove $MCP_CFG"
                fi
                ;;
            *)
                log_info "Preserved: $MCP_CFG"
                ;;
        esac
    fi
fi

# ───────── (existing UN-05 D-06 STATE_FILE block follows — UNCHANGED) ─────────
```

**Critical placement rules:**
- This block must sit AFTER the Plan 40-01 `INSTALLED_MCPS` loop (so per-MCP prompts have already drained any "Y" keys before this final whole-file prompt fires).
- This block must sit BEFORE the existing `if [[ $KEEP_STATE -eq 0 ]]; then rm -f "$STATE_FILE" ...` block — the `mcp-config.env` removal is one step UPSTREAM of the LAST step (STATE_FILE).
- DO NOT modify the existing STATE_FILE block in any way. Verify post-edit: line number of `rm -f "$MCP_CFG"` < line number of `rm -f "$STATE_FILE"`.

**Bash 3.2 / macOS BSD invariants (CONTEXT D-16):**
- `sort -u | wc -l | tr -d ' '` — POSIX, present on macOS BSD. `wc -l` output has leading whitespace on BSD; `tr -d ' '` normalizes.
- Parameter expansions `${var#prefix}` and `${var%_*}` — Bash 3.2-safe.
- No `mapfile`, no `${var,,}`, no `read -N`, no `read -t` with float.
- The subshell `$(...)` for `_n_mcps` is a deliberate isolation — preserves `mcp_secrets_load` arrays in the parent.

**Variable name discipline:**
- All new variables prefixed with `_` (`_n_keys`, `_n_mcps`, `_tty_target`, `_choice`, `_i`, `_k`, `_stripped`, `_name`) to avoid colliding with existing globals.
- Exception: `MCP_CFG` is intentionally unprefixed because it's a long-lived path constant referenced once below — but does not collide with any existing uninstall.sh global (verified by grep before insertion).

**Skip-when-absent semantics:**
- The outer `[[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]` guard ensures this block is a no-op when:
  - `_mcp_config_path` returns empty (lib/mcp.sh sourcing failed)
  - File never existed (toolkit was used without ever entering MCP secrets)
- No log line on skip — silent (per CONTEXT D-05 "Skip the prompt entirely when mcp-config.env does not exist").

**Idempotency:**
- After Y, file is gone; re-run hits the `[[ -f ... ]]` guard and skips silently.
- After N (default), file is unchanged; re-run prompts again. This is correct — the user might change their mind on a later uninstall attempt.

**Security review (CLAUDE.md global rules):**
- `rm -f "$MCP_CFG"` — quoted, no shell expansion. Path is derived from `_mcp_config_path()` which honors `TK_MCP_CONFIG_HOME` (test seam, controlled by tests) or defaults to `${HOME}/.claude/mcp-config.env`. No path traversal possible.
- The derived `_name` values from `MCP_SECRET_KEYS[]` are echoed only for `sort -u | wc -l` counting — never to user-facing output, never to disk. No information disclosure beyond the existing `printf '%s=%s\n'` write contract Plan 40-01 already audited.
- The prompt label includes only counts (X, Y), not key NAMES or VALUES. Information disclosure minimized.
  </action>
  <verify>
    <automated>bash -n scripts/uninstall.sh && shellcheck -S warning scripts/uninstall.sh && grep -q 'also remove.*mcp-config.env' scripts/uninstall.sh && awk '/rm -f "\$MCP_CFG"/{a=NR} /rm -f "\$STATE_FILE"/{b=NR} END{exit (a&&b&&a<b)?0:1}' scripts/uninstall.sh</automated>
  </verify>
  <done>
    - `bash -n scripts/uninstall.sh` clean
    - `shellcheck -S warning scripts/uninstall.sh` clean
    - `grep -n 'also remove.*mcp-config.env' scripts/uninstall.sh` shows the prompt string exactly once
    - Order assertion: line of `rm -f "$MCP_CFG"` < line of `rm -f "$STATE_FILE"` (UN-05 D-06 ordering preserved)
    - With `mcp-config.env` absent in a sandbox `$HOME`, running `bash scripts/uninstall.sh` does not print the new prompt (silent skip)
    - With `--dry-run`, the prompt is replaced by `[dry-run] would prompt: also remove …` and no `rm` runs
    - `make shellcheck` (project root) green
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user → uninstall.sh stdin (TTY) | Single-char y/N input crosses here; routed through `read -r` + `case` — no eval |
| `_mcp_config_path()` output → `rm -f` | Path resolved by toolkit lib; honored test seam (`TK_MCP_CONFIG_HOME`) — no user input |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-02-01 | Tampering | rm -f path resolution | mitigate | Path derived from `_mcp_config_path()` (toolkit-controlled), quoted in `rm -f`. No path traversal vector |
| T-40-02-02 | Information Disclosure | prompt label | mitigate | Label includes only counts (X keys, Y MCPs) — never key names, never values |
| T-40-02-03 | Denial of Service | TTY read fail | mitigate | No retry loop here (single-shot prompt). Failure → fail-closed N → file preserved (safe-by-default) |
| T-40-02-04 | Repudiation | No log of N branch in interactive mode | accept | `log_info "Preserved: ..."` records the choice for ad-hoc debugging; sufficient for solo-developer tool |
| T-40-02-05 | Elevation of Privilege | rm -f as effective user | accept | uninstall.sh runs as user; `rm -f` cannot escalate. Removing a file the user owns is the user's right |
</threat_model>

<verification>
- `bash -n scripts/uninstall.sh` parses clean
- `shellcheck -S warning scripts/uninstall.sh` reports no warnings
- `grep -n '\[y/N\] also remove .*mcp-config.env' scripts/uninstall.sh` shows exactly one match
- Order assertion verifiable via awk: line of `rm -f "$MCP_CFG"` < line of `rm -f "$STATE_FILE"`
- Dry-run path prints `[dry-run] would prompt: also remove …` exactly once and runs no `rm`
- File-absent path: silent skip, no prompt, no log
</verification>

<success_criteria>
- New prompt block exists in uninstall.sh
- Block placement: AFTER Plan 40-01 INSTALLED_MCPS loop, BEFORE existing STATE_FILE block (UN-05 D-06 preserved)
- Default N preserves file; Y removes via `rm -f` with `log_success` / `log_warning` reporting
- Fail-closed N on TTY read failure (mirrors UN-03)
- TK_UNINSTALL_TTY_FROM_STDIN seam reused (no new seam introduced)
- File-absent: silent skip
- Dry-run: no prompt, no rm; prints `[dry-run] would prompt: also remove …`
- Bash 3.2 / macOS BSD safe (no GNU-only flags, no associative array)
- Pre-existing STATE_FILE block byte-identical (verify via diff if needed)
</success_criteria>

<output>
After completion, create `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-02-SUMMARY.md` summarizing:
- Final line numbers of the new prompt block (start, end) in uninstall.sh
- Confirmation: line of new `rm -f "$MCP_CFG"` < line of existing `rm -f "$STATE_FILE"` (D-06 ordering preserved)
- Confirmation: STATE_FILE block byte-identical to pre-Phase-40 baseline
- Note that Plan 40-03 will wrap both this block and Plan 40-01's loop in the existing KEEP_STATE gate (UN-SEC-05) and add `--help` text updates
</output>
