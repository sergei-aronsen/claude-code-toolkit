---
phase: 39-tui-per-row-scope-toggle
reviewed: 2026-05-05T19:53:03Z
depth: standard
iteration: 2
files_reviewed: 4
files_reviewed_list:
  - scripts/lib/mcp.sh
  - scripts/lib/tui.sh
  - scripts/install.sh
  - scripts/tests/test-mcp-selector.sh
findings:
  blocker: 0
  high: 0
  medium: 1
  low: 0
  info: 1
  total: 2
status: findings
---

# Phase 39 — TUI Per-Row Scope Toggle — Code Review (iteration 2)

## Summary

Re-review of iteration 1 fix delta (commits 77e3240, caa4754, 730d72f, b350f87, 34c6b8e) against the same 4 files.

**Validation of iteration 1 fixes:**

- **HIGH-01 (sub-picker label corruption):** RESOLVED. `install.sh:1806-1814` no longer wires `TUI_HEADER_KEY=s` / `TUI_HEADER_FN=mcp_toggle_scope` / `mcp_render_scope_header` in the `mcp)` sub-picker arm. The CSV builder at line 1820-1827 and lookback restore at line 1788-1804 now safely read raw `MCP_NAMES`-format `TUI_LABELS[]`. Verified no other code path between sub-picker entry (line 1707) and `tui_checklist` invocation (line 1816) sets `TUI_ROW_KEY/FN` or `TUI_HEADER_KEY/FN`, so Tab and `s` are correctly no-ops on the sub-picker.
- **HIGH-02 (CLI flag ignored in headless paths):** RESOLVED for dispatch correctness. Argument parser at `install.sh:104-126` captures `TK_MCP_SCOPE_CLI` separately; broadcast loop at `install.sh:407-418` writes the validated CLI scope into every `MCP_SELECTED_SCOPE[]` slot after `mcp_status_array`. The dispatcher at `install.sh:654` reads `MCP_SELECTED_SCOPE[$tui_i]` per iteration, so headless `--yes` and `TK_MCP_PRE_SELECTED` paths now honour `--mcp-scope`. Existence guard `${MCP_SELECTED_SCOPE[*]+x}` is correct; case-validator restricts to `user|local|project`.
- **MED-01 (`mcp_cycle_row_scope` existence guard):** RESOLVED. `mcp.sh:1085-1098` mirrors `mcp_toggle_scope`'s `${MCP_SELECTED_SCOPE[*]+x}` pattern with `_len=0` initialization and bounds-check before the array dereference at line 1099.
- **MED-02 (redundant Tab inner-gate):** RESOLVED. `tui.sh:463` cleanly drops `&& "$TUI_ROW_KEY" == $'\t'` from the case-arm; the comment block at lines 453-462 now correctly states Tab is hardcoded.
- **LOW-03 (`_MCP_SETALL_SCOPE` validation):** RESOLVED. `install.sh:502-506` validates `TK_MCP_SCOPE` against `user|local|project` with `user` fallback before `mcp_render_scope_header` consumes it.

**Baselines (post-iteration-1):**

- `make shellcheck` → pass (warning severity).
- `bash scripts/tests/test-mcp-selector.sh` → 36/36 passed.
- `bash scripts/tests/test-mcp-wizard.sh` → 53/53 passed.

**New issues introduced by the fix delta:**

One MEDIUM finding: HIGH-02's broadcast updates `MCP_SELECTED_SCOPE[]` but does NOT rebuild `TUI_LABELS[]`, leaving row-label scope glyphs stale on the interactive TUI when `--mcp-scope` is passed. One INFO note about `TK_MCP_SCOPE_CLI` becoming an externally-settable signal.

No regressions in `MCP_SELECTED_SCOPE` flow, scope-glyph rendering during normal Tab/`s` mutations, or sub-picker CSV correctness.

---

## Medium

### MED-03: HIGH-02 broadcast updates `MCP_SELECTED_SCOPE[]` but leaves `TUI_LABELS[]` glyphs stale on interactive `--mcp-scope` path

**File:** `scripts/install.sh:398-418`

**Issue:**

The HIGH-02 fix at `install.sh:407-418` correctly broadcasts the CLI scope into every `MCP_SELECTED_SCOPE[]` slot after `mcp_status_array`. However, `mcp_status_array` (`mcp.sh:1305-1315`) builds `TUI_LABELS[]` with scope-glyph prefixes derived from `MCP_DEFAULT_SCOPE[i]` (catalog defaults), NOT from `MCP_SELECTED_SCOPE[i]`. The broadcast updates the dispatcher-side state but leaves the labels unchanged.

Result on the interactive TUI path (`install.sh --integrations --mcp-scope=local`):

- Banner header shows `Set all to: [L]` (correct — `_MCP_SETALL_SCOPE` reads `TK_MCP_SCOPE` at `install.sh:502`).
- Row labels display the catalog default `[U]`/`[P]`/`[L]` mix (e.g. `[U] context7`, `[P] supabase`).
- Internal `MCP_SELECTED_SCOPE[*]` is `("local" "local" ...)` — broadcast value.
- Dispatch is correct (every row installs to `local`).
- **But the user sees a screen where row glyphs disagree with the banner and with the actual install scope.**

The headless paths (`--yes`, `TK_MCP_PRE_SELECTED`) don't render the TUI, so this is purely a visual inconsistency on the interactive path. Pressing `s` once normalizes labels (rebuilds `TUI_LABELS[]` via `mcp_toggle_scope`'s loop at `mcp.sh:1051-1066`) but immediately cycles the scope away from the user's CLI choice (`local → user`) — the user must press `s` two more times to return to `local`.

**Reproduce:**

```bash
$ ./install.sh --integrations --mcp-scope=local
[TUI renders. Banner: "Set all to: [L]". Row labels show
 [U] context7, [P] supabase, etc. — the catalog-default mix, not [L].]
[Submit without pressing s. All rows install to local. User confused
 by banner-vs-label disagreement.]
```

The banner-vs-label inconsistency does not affect dispatch correctness (the iteration 1 HIGH-02 fix achieves D-18). It is a UX regression introduced by the broadcast, since pre-Phase 39 install.sh had no per-row scope concept and v4.9 always rendered a uniform display.

**Severity:** Medium. Visual inconsistency on a flag the user explicitly passed; recoverable by pressing `s` 3 times but unintuitive. Does not corrupt state or cause incorrect installs.

**Fix:** After the broadcast loop at `install.sh:418`, mirror `mcp_toggle_scope`'s label-rebuild block (`mcp.sh:1044-1066`) to re-render every `TUI_LABELS[$_si]` with the new scope glyph. Cleaner: extract the label-rebuild loop into a private helper `_mcp_rebuild_row_labels()` in `mcp.sh` and call it from `mcp_status_array` (or post-broadcast in `install.sh`), `mcp_toggle_scope`, and the new install.sh broadcast site.

Minimal-delta sketch:

```bash
# scripts/lib/mcp.sh — new private helper after mcp_toggle_scope
_mcp_rebuild_row_labels() {
    # Reads MCP_SELECTED_SCOPE[], TUI_TO_MCP_IDX[], MCP_UNOFFICIAL[],
    # MCP_DISPLAY[], NO_COLOR. Writes TUI_LABELS[].
    local _len=0
    if [[ -n "${MCP_SELECTED_SCOPE[*]+x}" ]]; then
        _len="${#MCP_SELECTED_SCOPE[@]}"
    fi
    local _c_scope_active="" _c_nc="" _c_y=""
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
        _c_scope_active=$'\033[0;32m'
        _c_nc=$'\033[0m'
        _c_y=$'\033[1;33m'
    fi
    local _g_bang="!"
    local _j _mcp_idx _scope_glyph _name_part
    for ((_j=0; _j<_len; _j++)); do
        _mcp_idx="${TUI_TO_MCP_IDX[$_j]:-0}"
        _scope_glyph=$(_mcp_render_scope_glyph "${MCP_SELECTED_SCOPE[$_j]:-user}")
        if [[ "${MCP_UNOFFICIAL[$_mcp_idx]:-0}" == "1" ]]; then
            if [[ -n "$_c_y" ]]; then
                _name_part="${_c_y}${_g_bang}${_c_nc} ${MCP_DISPLAY[$_mcp_idx]}"
            else
                _name_part="[!] ${MCP_DISPLAY[$_mcp_idx]}"
            fi
        else
            _name_part="${MCP_DISPLAY[$_mcp_idx]}"
        fi
        TUI_LABELS[$_j]="${_scope_glyph} ${_name_part}"
    done
}
```

```bash
# scripts/install.sh:418 — call the helper after the broadcast
if [[ -n "${TK_MCP_SCOPE_CLI:-}" ]]; then
    case "$TK_MCP_SCOPE_CLI" in
        user|local|project)
            if [[ -n "${MCP_SELECTED_SCOPE[*]+x}" ]]; then
                for ((_si=0; _si<${#MCP_SELECTED_SCOPE[@]}; _si++)); do
                    MCP_SELECTED_SCOPE[$_si]="$TK_MCP_SCOPE_CLI"
                done
                unset _si
                _mcp_rebuild_row_labels
            fi
            ;;
    esac
fi
```

(Optionally also refactor `mcp_toggle_scope:1044-1066` to call the helper, removing the duplication. That refactor is an Info-level cleanup; the bug fix is the new call site only.)

Add a regression test under `test-mcp-selector.sh`:

```bash
# S14_cli_scope_label_parity:
TK_MCP_SCOPE_CLI=local
mcp_status_array
for ((_si=0; _si<${#MCP_SELECTED_SCOPE[@]}; _si++)); do
    MCP_SELECTED_SCOPE[$_si]="local"
done
_mcp_rebuild_row_labels   # new helper call
# Every TUI_LABELS slot must carry the [L] active glyph; no [U]/[P]
# active leakage from catalog defaults.
for ((_j=0; _j<${#TUI_LABELS[@]}; _j++)); do
    case "${TUI_LABELS[$_j]}" in
        *$'\033[0;32m[L]'*) ;;          # color path
        "[U] [P] "*"[L]"*) ;;            # NO_COLOR path — [L] is the
                                          # only active token (3-token form)
        *) assert_fail "S14: TUI_LABELS[$_j] glyph != [L]: ${TUI_LABELS[$_j]}" ;;
    esac
done
```

---

## Info

### INFO-02: `TK_MCP_SCOPE_CLI` is now an externally-settable env signal (broadens trust surface)

**File:** `scripts/install.sh:115-116, 407`

**Issue:**

The HIGH-02 fix exports `TK_MCP_SCOPE_CLI` from the argument parser (line 116) and reads it at the broadcast site (line 407). This makes `TK_MCP_SCOPE_CLI` a documented control signal: **any** caller can set `TK_MCP_SCOPE_CLI=local` in the environment to force-broadcast, without passing `--mcp-scope=local` on the CLI.

This is consistent with iteration 1's intent ("CLI-supplied scope wins"), and the case-validator at `install.sh:408` caps damage to the `user|local|project` allowlist — so a malformed env value is silently ignored, not reflected. But it does change the trust boundary: pre-fix, only the argument parser at `install.sh:104-126` could set the broadcast signal. Post-fix, any sourced shell init / parent process / CI runner can set it.

**Severity:** Info. Bounded by the case-validator; consistent with how `TK_MCP_SCOPE` already worked pre-Phase 39 (also exported and consumed by `mcp_wizard_run`). Worth documenting in the install.sh `--help` block so users know the env-var equivalent exists.

**Fix (optional):** Either document the env-var equivalence in `--help` (preferred — formalize the contract) OR de-export `TK_MCP_SCOPE_CLI` (drop `export TK_MCP_SCOPE_CLI` at `install.sh:116`) so it's a private install.sh variable, not a published env signal. The de-export option is the more conservative choice — the broadcast loop is in the same shell process, so cross-process visibility is unnecessary.

```bash
# install.sh:115-116 — drop the export so TK_MCP_SCOPE_CLI is install.sh-private
TK_MCP_SCOPE_CLI="$_scope_arg"
# (no export — broadcast at line 407 is same-process)
```

---

## Verification of Phase 39 critical invariants (iteration 2)

| Invariant | Iteration 1 | Iteration 2 |
|-----------|-------------|-------------|
| Per-row Tab cycles user → project → local → user | PASS | PASS |
| Set-all `s` writes every `MCP_SELECTED_SCOPE[]` slot | PASS | PASS |
| CLI-only rows skipped (no `MCP_SELECTED_SCOPE` slot) | PASS | PASS |
| Banner + glyphs use single source `_mcp_render_scope_glyph` | PASS | PASS |
| CLI `--mcp-scope` wins over catalog defaults (dispatch) | FAIL (HIGH-02) | **PASS** |
| CLI `--mcp-scope` reflected in row labels (visual) | n/a (pre-Phase 39) | **FAIL (MED-03)** |
| Pre-collection sub-picker preserves CSV exact-match contract | FAIL (HIGH-01) | **PASS** |
| `set -u` safe (Bash 3.2) on all scope mutators | PARTIAL (MED-01) | **PASS** |
| Tab dispatch `==$'\t'` redundancy | PARTIAL (MED-02) | **PASS** |
| `_MCP_SETALL_SCOPE` validated `user\|local\|project` | n/a (pre-fix) | **PASS** |
| `_TUI_COLOR` default `:-0` for headless callers | PASS | PASS |
| 36/36 `test-mcp-selector.sh` + 53/53 `test-mcp-wizard.sh` green | PASS | PASS |
| Phase 38 + 37 baselines unchanged | PASS | PASS |

---

## Recommendation

The iteration 1 fix delta correctly resolves all 5 in-scope iteration-1 findings (HIGH-01, HIGH-02, MED-01, MED-02, LOW-03) without regressing tests, shellcheck baseline, or core dispatch correctness. One MEDIUM-severity follow-on issue (MED-03) was introduced as a side effect of the HIGH-02 fix: the CLI-scope broadcast updates per-row dispatch state but not per-row visual labels, producing a banner-vs-label disagreement on the interactive `--mcp-scope` path. The fix is small (~25 lines via a shared label-rebuild helper) and isolated to `install.sh` + `mcp.sh`.

**Recommend a third iteration to address MED-03** before merging Phase 39. INFO-02 is a documentation/scoping nit that can defer.

Pre-existing low/info items (LOW-01 footer width, LOW-02 composite array guard, INFO-01 dead test arm) remain deferred per orchestrator scope.

---

_Reviewed: 2026-05-05T19:53:03Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 2_
