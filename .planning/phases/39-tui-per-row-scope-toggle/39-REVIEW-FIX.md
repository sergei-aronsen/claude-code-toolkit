---
phase: 39-tui-per-row-scope-toggle
fixed_at: 2026-05-05T00:00:00Z
review_path: .planning/phases/39-tui-per-row-scope-toggle/39-REVIEW.md
iteration: 3
findings_in_scope: 5
fixed: 6
skipped: 0
status: all_fixed
baselines:
  shellcheck: pass
  test_mcp_selector: 36/36
  test_mcp_wizard: 53/53
---

# Phase 39 — Code Review Fix Report

**Fixed at:** 2026-05-05T00:00:00Z
**Source review:** `.planning/phases/39-tui-per-row-scope-toggle/39-REVIEW.md`
**Iteration:** 3 (final)

**Summary:**

- Iteration 1 findings (HIGH + MEDIUM): 4 in scope, 4 fixed + 1 bonus LOW-03 = 5 total
- Iteration 3 follow-on (MEDIUM regression introduced by HIGH-02): 1 in scope, 1 fixed
- Cumulative findings in scope: 5
- Cumulative fixed: 6
- Skipped: 0

INFO-02 (`TK_MCP_SCOPE_CLI` exported as env signal) excluded by orchestrator
scope (info findings out of `critical_warning` scope).
LOW-01, LOW-02, INFO-01 deferred per orchestrator instruction (cosmetic /
out of phase).

**Baselines (post-iteration-3, all green):**

- `make shellcheck`: pass
- `bash scripts/tests/test-mcp-selector.sh`: 36 passed, 0 failed
- `bash scripts/tests/test-mcp-wizard.sh`: 53 passed, 0 failed

## Fixed Issues

### HIGH-01: pre-collection MCP sub-picker corrupts `TK_MCP_PRE_SELECTED` CSV when user presses `s`

**Files modified:** `scripts/install.sh`
**Commit:** 77e3240
**Iteration:** 1
**Applied fix:** Removed `TUI_HEADER_KEY="s"` / `TUI_HEADER_FN="mcp_toggle_scope"` wiring (and the matching pre-render `TK_MCP_SCOPE` export + `mcp_render_scope_header` call) from the sub-picker `mcp)` arm in install.sh's pre-collection loop. Tightened the trailing `unset` to drop only `TUI_HEADER_TEXT` (the wiring vars are no longer set on this code path). Added a comment block explaining why scope toggle was removed (sub-picker contract: produce raw-name CSV; per-row scope choice happens in the main TUI). Net: `mcp_toggle_scope` no longer rewrites `TUI_LABELS[]` slots with scope-glyph prefix on this picker, so the downstream CSV builder + lookback restore both see raw `MCP_NAMES` exactly as before — main-TUI exact-match against `MCP_NAMES` survives.

### HIGH-02: `--mcp-scope=<scope>` silently ignored in `--yes` and `TK_MCP_PRE_SELECTED` paths

**Files modified:** `scripts/install.sh`
**Commit:** caa4754
**Iteration:** 1
**Applied fix:** Two-part change.

1. Argument parser at install.sh:104-127 now captures the explicit CLI value into a separate `TK_MCP_SCOPE_CLI` variable in addition to setting `TK_MCP_SCOPE` (so headless dispatch can distinguish "user supplied --mcp-scope" from "default fallback to user").
2. Right after `mcp_status_array` runs (install.sh:398), broadcast `TK_MCP_SCOPE_CLI` (when set and validated as `user|local|project`) to every `MCP_SELECTED_SCOPE[$_si]` slot. Guarded with `${MCP_SELECTED_SCOPE[*]+x}` for `set -u` safety.

The dispatcher loop at install.sh:615 then unconditionally writes `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"` per iteration, so the CLI flag now wins in `--yes` and `TK_MCP_PRE_SELECTED` paths (they never run Tab/`s` mutations, so the broadcast values stand). Per-row interactive Tab/`s` mutations still override per-iteration because they overwrite `MCP_SELECTED_SCOPE` before the dispatcher reads it.

(Iteration 2 review identified a residual UX bug — TUI labels lagged the broadcast — addressed by MED-03 below.)

### MED-01: `mcp_cycle_row_scope` lacks `${var[*]+x}` existence guard for `MCP_SELECTED_SCOPE`

**Files modified:** `scripts/lib/mcp.sh`
**Commit:** 730d72f
**Iteration:** 1
**Applied fix:** Mirrored sibling `mcp_toggle_scope`'s guard (mcp.sh:1030-1033) in `mcp_cycle_row_scope` (mcp.sh:1085-1098). `_len` initializes to 0; populated from `${#MCP_SELECTED_SCOPE[@]}` only when `${MCP_SELECTED_SCOPE[*]+x}` proves the array exists. Bash 3.2 + nounset safe; preserves existing out-of-bounds short-circuit.

### MED-02: `tui_checklist` Tab inner-gate `"$TUI_ROW_KEY" == $'\t'` is redundant and contradicts comment

**Files modified:** `scripts/lib/tui.sh`
**Commit:** b350f87
**Iteration:** 1
**Applied fix:** Dropped the dead `&& "$TUI_ROW_KEY" == $'\t'` clause from the row dispatcher condition at tui.sh:459-462. Updated the comment block to state Tab is hardcoded in this case-arm and that future D-05 reconfigurability would require moving dispatch into the `*)` arm with a positional check (deferred). The case-arm `$'\t')` itself already enforces Tab — the inner equality check could never be reached on any other byte.

### LOW-03: `_MCP_SETALL_SCOPE` seeded from `TK_MCP_SCOPE` without scope-range validation

**Files modified:** `scripts/install.sh`
**Commit:** 34c6b8e
**Iteration:** 1
**Applied fix:** After `_MCP_SETALL_SCOPE="${TK_MCP_SCOPE:-user}"` (install.sh:502), added a `case` validator that resets the value to `user` if it doesn't match `user|local|project`. Defense-in-depth — a malformed `TK_MCP_SCOPE` (caller bypassed argument-parser validation, or env from another tool) no longer produces inconsistent banner state where `mcp_render_scope_header` shows `[U]` (default fallback) while `mcp_toggle_scope`'s first cycle silently drops the malformed value.

### MED-03: HIGH-02 broadcast updates `MCP_SELECTED_SCOPE[]` but leaves `TUI_LABELS[]` glyphs stale on interactive `--mcp-scope` path

**Files modified:** `scripts/lib/mcp.sh`, `scripts/install.sh`
**Commit:** 71d7a8b
**Iteration:** 3
**Applied fix:** Extracted the all-rows label-rebuild loop from `mcp_toggle_scope` (`mcp.sh:1039-1066`, the post-slot-write block that re-renders every `TUI_LABELS[$_j]` with the new scope glyph) into a new private helper `_mcp_rebuild_row_labels` placed immediately after `mcp_toggle_scope` (`mcp.sh:1052-1095`). Helper reads `MCP_SELECTED_SCOPE[$_j]` per-row instead of a single set-all value, so it works for both the broadcast case (every slot already equals `TK_MCP_SCOPE_CLI`) and the toggle case (every slot already equals `_MCP_SETALL_SCOPE`); behaviour is byte-identical to the prior inline block. `_mcp_render_scope_glyph` remains the single source of truth for the green active bracket.

`mcp_toggle_scope` now ends with `_mcp_rebuild_row_labels` + `mcp_render_scope_header` (slot-write loop unchanged). `install.sh:414` calls `_mcp_rebuild_row_labels` after the `unset _si` inside the validated `user|local|project` case-arm, scoped under the existing `${MCP_SELECTED_SCOPE[*]+x}` existence guard. Headless paths (`--yes`, `TK_MCP_PRE_SELECTED`) skip the TUI render so the helper's string-rebuild cost is invisible there; on the interactive `--mcp-scope` path the row labels now agree with the banner and dispatch on first paint (no `s`-press dance required).

Bash 3.2 + nounset safe via the same `${MCP_SELECTED_SCOPE[*]+x}` guard pattern as MED-01. Helper-internal locals (`_len`, `_c_*`, `_g_bang`, `_j`, `_mcp_idx`, `_scope_glyph`, `_name_part`) all `local`-declared.

## Skipped Issues

None — all in-scope findings across iterations 1 and 3 (HIGH + MEDIUM) plus the bonus LOW-03 (orchestrator-included defense-in-depth, iteration 1) applied cleanly. INFO-02, LOW-01, LOW-02, INFO-01 were excluded by orchestrator scope (info / cosmetic / out of phase).

## Phase 39 critical invariants (post-iteration-3)

| Invariant | Iteration 1 | Iteration 2 | Iteration 3 |
|-----------|-------------|-------------|-------------|
| Per-row Tab cycles user → project → local → user | PASS | PASS | PASS |
| Set-all `s` writes every `MCP_SELECTED_SCOPE[]` slot | PASS | PASS | PASS |
| CLI-only rows skipped (no `MCP_SELECTED_SCOPE` slot) | PASS | PASS | PASS |
| Banner + glyphs use single source `_mcp_render_scope_glyph` | PASS | PASS | PASS |
| CLI `--mcp-scope` wins over catalog defaults (dispatch) | FAIL (HIGH-02) | PASS | PASS |
| CLI `--mcp-scope` reflected in row labels (visual) | n/a (pre-Phase 39) | FAIL (MED-03) | **PASS** |
| Pre-collection sub-picker preserves CSV exact-match contract | FAIL (HIGH-01) | PASS | PASS |
| `set -u` safe (Bash 3.2) on all scope mutators | PARTIAL (MED-01) | PASS | PASS |
| Tab dispatch `==$'\t'` redundancy | PARTIAL (MED-02) | PASS | PASS |
| `_MCP_SETALL_SCOPE` validated `user\|local\|project` | n/a (pre-fix) | PASS | PASS |
| `_TUI_COLOR` default `:-0` for headless callers | PASS | PASS | PASS |
| 36/36 `test-mcp-selector.sh` + 53/53 `test-mcp-wizard.sh` green | PASS | PASS | PASS |
| Phase 38 + 37 baselines unchanged | PASS | PASS | PASS |

---

_Fixed: 2026-05-05T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iterations: 1 + 3 (final)_
