---
phase: 39-tui-per-row-scope-toggle
reviewed: 2026-05-04T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - scripts/lib/mcp.sh
  - scripts/lib/tui.sh
  - scripts/install.sh
  - scripts/tests/test-mcp-selector.sh
findings:
  blocker: 0
  high: 2
  medium: 2
  low: 3
  info: 1
  total: 8
status: findings
---

# Phase 39 — TUI Per-Row Scope Toggle — Code Review

## Summary

Phase 39 delivers per-row Tab cycle + 3-state set-all `s` correctly on the happy path: Tab/`s` mutate `MCP_SELECTED_SCOPE[]`; dispatcher loop at install.sh:615 reads per-row scope and exports `TK_MCP_SCOPE` per iteration; CLI-only rows skipped via parallel-array length guard; banner + glyphs single-source-of-truth via `_mcp_render_scope_glyph`. 36/36 selector tests + 53/53 wizard tests pass.

Two real defects the test suite does not cover:

1. **HIGH-01:** Pre-collection MCP sub-picker (install.sh:1773-1775) wires `TUI_HEADER_KEY=s → mcp_toggle_scope`. `mcp_toggle_scope` rewrites every `TUI_LABELS[]` slot with a scope-glyph prefix (`"[U] context7"`). The sub-picker's CSV builder at line 1782-1788 reads `TUI_LABELS[$_mcp_i]` directly — so pressing `s` once corrupts `TK_MCP_PRE_SELECTED` with glyph-prefixed names. Downstream main-TUI exact-match against `MCP_NAMES` then silently drops every row.
2. **HIGH-02:** `--mcp-scope=<scope>` CLI flag is silently ignored by `--yes` and `TK_MCP_PRE_SELECTED` headless paths. Argument parser sets `TK_MCP_SCOPE`, but `mcp_status_array` seeds `MCP_SELECTED_SCOPE[]` from `MCP_DEFAULT_SCOPE[i]` (catalog defaults) without reading `TK_MCP_SCOPE`. The dispatcher at install.sh:615 then unconditionally overwrites `TK_MCP_SCOPE` from `MCP_SELECTED_SCOPE[$tui_i]`. Net: CLI flag wins only in the inline 1-MCP path, not in --yes / pre-selected paths. Violates D-18 "CLI flag wins" intent.

---

## High

### HIGH-01: pre-collection MCP sub-picker corrupts `TK_MCP_PRE_SELECTED` CSV when user presses `s`

**File:** `scripts/install.sh:1668-1791` (sub-picker `mcp)` arm)

**Issue:**
At lines 1772-1775 the sub-picker wires:

```bash
TUI_HEADER_KEY="s"
TUI_HEADER_FN="mcp_toggle_scope"
```

`mcp_toggle_scope` (mcp.sh:1004-1069) rewrites every `TUI_LABELS[]` slot with a scope-glyph prefix:

```bash
TUI_LABELS[$_j]="${_scope_glyph} ${_name_part}"   # mcp.sh:1065
```

After one `s` press, `TUI_LABELS[0]` becomes `"\033[1;32m[U]\033[0m context7"` (or plain `"[U] context7"` under NO_COLOR). The CSV builder at line 1782-1788 then reads:

```bash
_mcp_pre_csv="${_mcp_pre_csv}${_mcp_pre_csv:+,}${TUI_LABELS[$_mcp_i]}"
```

…producing `TK_MCP_PRE_SELECTED="[U] context7,[U] supabase"`. The main TUI's pre-selection match at install.sh:413+ is exact-match against `MCP_NAMES` (raw, no glyph). Every match fails → all rows silently deselected on main-TUI re-entry.

The sub-picker's lookback restore at lines 1750-1765 also breaks the same way (compares `TUI_LABELS[$_mcp_i]` containing glyph prefix against the previous CSV with raw names).

**Reproduce:**

```text
$ ./install.sh
[Submit on first MCP screen → main TUI shows MCP rows]
[Toggle some rows on, navigate to MCP sub-picker, press s once, Submit]
[main TUI now shows zero MCP rows selected; the install plan drops them]
```

This is in addition to the per-row Tab-cycle path on the same picker which would also rewrite a single label slot.

**Fix:** Remove the `TUI_HEADER_KEY/FN` wiring from the sub-picker entirely (it is a pre-collection picker; scope choice happens in the main TUI). The simplest delta:

```bash
# DROP these lines (1769-1775):
TK_MCP_SCOPE="${TK_MCP_SCOPE:-user}"
export TK_MCP_SCOPE
mcp_render_scope_header
TUI_HEADER_KEY="s"
TUI_HEADER_FN="mcp_toggle_scope"
```

…and the matching `unset` at line 1778. Sub-picker reverts to the v4.9 pure-name CSV contract; per-row scope still works in the main TUI exactly as Plan 02 designed.

If we want to KEEP the visual indicator in the sub-picker, both label-mutation sites (`mcp_status_array` initial render + `mcp_toggle_scope` rebuild) need to push to a separate `MCP_DISPLAY_LABEL[]` array, and the CSV builder + lookback need to switch to a parallel `MCP_NAMES`-indexed array (`TUI_TO_MCP_IDX[$_mcp_i]` → `MCP_NAMES[…]`). That's a 4-site change vs. the 1-site delete above. Recommend the delete.

---

### HIGH-02: `--mcp-scope=<scope>` silently ignored in `--yes` and `TK_MCP_PRE_SELECTED` paths — violates D-18

**File:** `scripts/install.sh:107-108` (set), `scripts/lib/mcp.sh:1303-1306` (overwrite via seed), `scripts/install.sh:615-616` (per-row export)

**Issue:**
Argument parser at install.sh:104-114 sets `TK_MCP_SCOPE` from `--mcp-scope=<scope>` and exports it. But:

- `mcp_status_array` at mcp.sh:1303-1306 seeds `MCP_SELECTED_SCOPE+=("${MCP_DEFAULT_SCOPE[$i]:-user}")` — reads catalog default, NOT `TK_MCP_SCOPE`.
- The dispatcher loop at install.sh:615 then unconditionally writes `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"` per iteration.

In headless paths (`--yes` and `TK_MCP_PRE_SELECTED`), no Tab/`s` mutation runs, so `MCP_SELECTED_SCOPE[]` stays at catalog defaults and the CLI flag is silently lost for every MCP whose default scope ≠ flag value.

The argument parser comment at install.sh:103 explicitly promises `# the CLI flag wins (TK_MCP_SCOPE is read by mcp_wizard_run)`. Phase 39 broke that promise.

**Reproduce:**

```text
$ TK_MCP_PRE_SELECTED=context7 ./install.sh --yes --mcp-scope=project
[Phase 38 wizard sees TK_MCP_SCOPE=user (catalog default), not project]
```

Wizard then writes `~/.claude.json` user-scope entry instead of `<project>/.mcp.json` — silent data placement bug.

**Fix:** After `mcp_status_array` populates `MCP_SELECTED_SCOPE[]` and BEFORE the dispatcher loop, if a CLI `TK_MCP_SCOPE` was explicitly set AND matches `user|local|project`, broadcast it to every slot:

```bash
# CLI --mcp-scope wins over catalog defaults in headless paths.
# Per-row Tab/`s` mutations during the TUI still override per-iteration
# (writes land in MCP_SELECTED_SCOPE before the dispatcher reads it).
if [[ -n "${TK_MCP_SCOPE_CLI:-}" ]]; then
    case "$TK_MCP_SCOPE_CLI" in
        user|local|project)
            for ((_si=0; _si<${#MCP_SELECTED_SCOPE[@]}; _si++)); do
                MCP_SELECTED_SCOPE[$_si]="$TK_MCP_SCOPE_CLI"
            done
            unset _si
            ;;
    esac
fi
```

Argument parser change: rename the assignment to a side variable so the dispatch logic can detect "user supplied a flag" vs. "default fallback":

```bash
# install.sh:104-108 — capture the explicit CLI value separately
_scope_arg="${1#--mcp-scope=}"
case "$_scope_arg" in
    user|local|project)
        TK_MCP_SCOPE_CLI="$_scope_arg"
        export TK_MCP_SCOPE_CLI
        TK_MCP_SCOPE="$_scope_arg"
        export TK_MCP_SCOPE
        ;;
    ...
```

(Keep `TK_MCP_SCOPE` export for the inline 1-MCP path; the dispatcher uses `TK_MCP_SCOPE_CLI` only.)

Add a regression test under `test-mcp-selector.sh`: set `TK_MCP_PRE_SELECTED=context7` + `--mcp-scope=project` + headless mocks, assert `MCP_SELECTED_SCOPE[*]` is all-`project`.

---

## Medium

### MED-01: `mcp_cycle_row_scope` lacks `${var[*]+x}` existence guard for `MCP_SELECTED_SCOPE`

**File:** `scripts/lib/mcp.sh:1085-1102`

**Issue:**
Sibling function `mcp_toggle_scope` (mcp.sh:1030-1033) correctly guards under `set -u`:

```bash
local _len=0
if [[ -n "${MCP_SELECTED_SCOPE[*]+x}" ]]; then
    _len="${#MCP_SELECTED_SCOPE[@]}"
fi
```

`mcp_cycle_row_scope` at line 1087 does not:

```bash
local _len="${#MCP_SELECTED_SCOPE[@]}"
```

Today every code path that wires `TUI_ROW_FN=mcp_cycle_row_scope` runs after `mcp_status_array` (which initializes the array), so the gap is latent. But the sibling has the guard for a documented reason (Plan 01's "Bash 3.2 + nounset safety") and one of two should not. A future caller — or refactor that swaps the two function names — surfaces the bug.

**Fix:** Mirror the sibling guard:

```bash
local _len=0
if [[ -n "${MCP_SELECTED_SCOPE[*]+x}" ]]; then
    _len="${#MCP_SELECTED_SCOPE[@]}"
fi
local _idx="${FOCUS_IDX:-0}"
```

---

### MED-02: `tui_checklist` Tab inner-gate `"$TUI_ROW_KEY" == $'\t'` is redundant and contradicts comment

**File:** `scripts/lib/tui.sh:439-462`

**Issue:**
Case-arm at line 439 hardcodes `$'\t')` so the arm only fires on Tab. The inner gate at line 459-460:

```bash
if [[ -n "${TUI_ROW_KEY:-}" && -n "${TUI_ROW_FN:-}" \
      && "$TUI_ROW_KEY" == $'\t' ]]; then
```

…rejects callers that set `TUI_ROW_KEY` to anything other than Tab — but those callers can never reach this arm anyway (their key would land in `*)` instead). The `$'\t'` equality check is dead.

The block comment at lines 455-457 says:

> The strict gate `"$TUI_ROW_KEY" == $'\t'` lets future callers swap to a different byte (e.g. lowercase `t`) per CONTEXT D-05 without forcing a code change here.

The comment is wrong: the case-arm itself is hardcoded to Tab, so a future swap to lowercase `t` would require moving the dispatch, not relying on the inner gate. The "configurability" the comment promises is not delivered.

**Fix:** Drop the `&& "$TUI_ROW_KEY" == $'\t'` clause; update the comment to state Tab is hardcoded for now. If the project later decides to make the row key configurable (D-05 hook), revisit by moving dispatch into the `*)` arm with a positional check.

```bash
# Tab is ASCII 0x09 — single byte, no multi-byte ambiguity. Position
# BEFORE the catch-all *) so the header-fn dispatch doesn't shadow Tab.
# Caller opt-in via TUI_ROW_KEY+TUI_ROW_FN; key is hardcoded to Tab here.
if [[ -n "${TUI_ROW_KEY:-}" && -n "${TUI_ROW_FN:-}" ]]; then
    "${TUI_ROW_FN}" || true
fi
```

---

## Low

### LOW-01: Footer hint approaches 100-col under all flags active

**File:** `scripts/lib/tui.sh:296-300`

**Issue:**
With `_row_hint=" · Tab row-scope"`, `_header_hint=" · s set-all-scope"`, and `_back_hint=" · b back"` all active, the rendered hint plain-text is:

```text
  ↑↓ navigate · Space toggle · Enter install · Tab row-scope · s set-all-scope · b back · Ctrl+C abort
```

~100 chars visual width including the 2-char indent. The Plan 01 comment at line 281 says "combined width was checked at planning (~95 chars under 100-col terminals)" — accurate, but the cushion is small. 80-col terminals (still common in `screen`/`tmux` defaults) wrap.

**Fix (optional, cosmetic):** Drop ` · Ctrl+C abort` (universally known) or shorten `set-all-scope` → `set-all`. Out of phase scope; flagged for future polish.

---

### LOW-02: `mcp_toggle_scope` and `mcp_cycle_row_scope` assume sibling parallel arrays populated when `MCP_SELECTED_SCOPE` is

**File:** `scripts/lib/mcp.sh:1051-1066, 1093-1101`

**Issue:**
Both functions read `TUI_TO_MCP_IDX[$_j]`, `MCP_DISPLAY[$_mcp_idx]`, `MCP_UNOFFICIAL[$_mcp_idx]` without existence guards. `mcp_status_array` populates all three together with `MCP_SELECTED_SCOPE`, so today they're always in sync. But the contract is implicit — a future regression that initializes only `MCP_SELECTED_SCOPE` (e.g., a test that injects a fake state) would crash under `set -u` with a confusing error pointing at the wrong line.

**Fix:** Add a single composite guard at function entry:

```bash
mcp_toggle_scope() {
    if [[ -z "${TUI_TO_MCP_IDX[*]+x}" || -z "${MCP_DISPLAY[*]+x}" ]]; then
        return 0
    fi
    ...
```

Out-of-scope for Phase 39; flagged for awareness.

---

### LOW-03: `_MCP_SETALL_SCOPE` seeded from `TK_MCP_SCOPE` without scope-range validation

**File:** `scripts/install.sh:467` (and any other seeder)

**Issue:**

```bash
_MCP_SETALL_SCOPE="${TK_MCP_SCOPE:-user}"
```

If a malformed `TK_MCP_SCOPE` ever leaks into the env (e.g., set by a caller that bypassed the argument-parser validator), the banner shows `[U]` (default-fallback in `mcp_render_scope_header` case-match) but `mcp_toggle_scope`'s first call cycles from the malformed value to "user" with no warning. Cosmetic and bounded by Phase 38's `mcp_wizard_run` already validating `TK_MCP_SCOPE`, but defense-in-depth should refuse outright.

**Fix:**

```bash
_MCP_SETALL_SCOPE="${TK_MCP_SCOPE:-user}"
case "$_MCP_SETALL_SCOPE" in
    user|local|project) ;;
    *) _MCP_SETALL_SCOPE="user" ;;
esac
```

---

## Info

### INFO-01: Test S13's "strong-signal" arm is dead code under --dry-run

**File:** `scripts/tests/test-mcp-selector.sh` (S13 section)

**Issue:**
Plan 39-03 dropped the live-mode fallback (--dry-run only) per planner deviation. The S13 assertion that probes for `<project>/.mcp.json` content under live-mode invocation is now unreachable. Dead-code maintenance hazard.

**Fix:** Remove the dead arm or replace with a comment pointer to the dry-run-only test invariant.

---

## Verification of Phase 39 critical invariants

| Invariant | Status |
|-----------|--------|
| Per-row Tab cycles user → project → local → user | **PASS** |
| Set-all `s` writes every `MCP_SELECTED_SCOPE[]` slot | **PASS** |
| CLI-only rows skipped (no `MCP_SELECTED_SCOPE` slot) | **PASS** |
| Banner + glyphs use single source `_mcp_render_scope_glyph` | **PASS** |
| CLI `--mcp-scope` wins over catalog defaults | **FAIL (HIGH-02)** |
| Pre-collection sub-picker preserves CSV exact-match contract | **FAIL (HIGH-01)** |
| `set -u` safe (Bash 3.2) on all scope mutators | **PARTIAL (MED-01)** |
| `_TUI_COLOR` default `:-0` for headless callers | **PASS** |
| 36/36 `test-mcp-selector.sh` + 53/53 `test-mcp-wizard.sh` green | **PASS** |
| Phase 38 + 37 baselines unchanged | **PASS** |

---

**Recommendation to merge:** Address HIGH-01 (one-line delete in install.sh sub-picker) + HIGH-02 (~15-line dispatch + arg-parser change) + MED-01 (3-line guard) + MED-02 (1-line + comment). LOW-03 is a cheap defense-in-depth add (3 lines). LOW-01/LOW-02/INFO-01 deferred — cosmetic / out of scope. Total fix surface: ~25 lines of code.
