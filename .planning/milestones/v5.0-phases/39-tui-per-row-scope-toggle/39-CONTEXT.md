# Phase 39: TUI Per-Row Scope Toggle - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning
**Mode:** Auto-resolved (decisions locked in REQUIREMENTS.md TUI-SCOPE-01..05 + TEST-04)

<domain>
## Phase Boundary

Each MCP row in the integrations TUI carries its own scope indicator (`[U]`/`[P]`/`[L]`) immediately after the existing checkbox glyph, with a per-row hotkey to flip a single row's scope. The existing global header `s` keypress (currently flips `TK_MCP_SCOPE` globally between `user` and `local`) is repurposed as a "set ALL visible MCP rows to scope X" convenience shortcut. Per-row state lives in a new parallel array `MCP_SELECTED_SCOPE[]` initialized from the catalog `default_scope` field at TUI launch via `mcp_status_array`. The dispatcher in `install.sh` exports `TK_MCP_SCOPE=<scope>` per-row before invoking `mcp_wizard_run` (Phase 38 contract), retiring the pre-v5.0 single-shell `TK_MCP_SCOPE` global in favor of per-call injection.

CLI-only rows in the integrations TUI (no MCP block) carry no scope indicator — the scope concept is meaningless for `command -v` checks. Tests cover the per-row indicator, single-row hotkey, global "set all", initialization from `default_scope`, and dispatcher export.

</domain>

<decisions>
## Implementation Decisions

### Per-row scope indicator render (TUI-SCOPE-01)

- **D-01:** Each MCP row's label gains a `[U]`/`[P]`/`[L]` glyph immediately after the checkbox, BEFORE the row label text. Format: `<arrow>N. [box] [U] label_text`.
- **D-02:** Active scope glyph is colored green (`\e[32m`) under TTY+color; inactive is plain. Under `NO_COLOR=1` or non-TTY, the bracket form is plain on all rows. Mirrors the existing `[reinstall ↻]` color discipline (tui.sh:234).
- **D-03:** CLI-only rows (no MCP block) render WITHOUT the indicator — TUI_LABELS for those rows stays untouched. Detection seam: caller (`install.sh` integrations dispatcher) builds TUI_LABELS with the scope glyph injected only for rows where MCP_NAMES has a corresponding entry.
- **D-04:** Indicator is built into TUI_LABELS at array-build time, NOT computed inside `_tui_render`. tui.sh stays scope-agnostic; only mcp.sh + install.sh know about scope. Mirrors how the existing `[installed ✓]` / `[reinstall ↻]` boxes are populated by the caller (`mcp_status_array` in mcp.sh).

### Per-row hotkey (TUI-SCOPE-02)

- **D-05:** Per-row hotkey: `Tab` cycles the focused row's scope `U → P → L → U`. Rationale: Tab is unmapped in the current `tui_checklist` case match (verified by grep at tui.sh:341+); does not collide with arrow nav, Space, Enter, `s`, `b`, `q`. Final binding subject to `tui_checklist` case-block extension at the planner's discretion if Tab parsing fails on macOS BSD bash 3.2.
- **D-06:** Hotkey is a no-op on CLI-only rows (no MCP_NAMES entry) and on the synthetic Submit row (FOCUS_IDX == total).
- **D-07:** Hotkey re-renders the TUI immediately to reflect the new indicator. The new value is captured in `MCP_SELECTED_SCOPE[$FOCUS_IDX]` before the next `_tui_render` call.
- **D-08:** TUI footer hint updated to advertise the per-row binding alongside the existing `s scope` hint. New copy: `Tab row-scope · s set-all-scope`. Final wording subject to width budget (must fit on one line under 80-col).

### Global "set all" repurpose (TUI-SCOPE-03)

- **D-09:** Existing `s` keypress logic (mcp.sh:957+ TUI_HEADER_FN binding) is repurposed: instead of flipping `TK_MCP_SCOPE` between `user`/`local`, it now writes the chosen scope into EVERY MCP row's `MCP_SELECTED_SCOPE[$i]` slot.
- **D-10:** Global toggle cycles through `user → project → local → user` (3 states matching the per-row enum). The header banner reflects the current "global pending" value.
- **D-11:** Header banner copy updated from `Scope: ◉ user (global)  ◯ local (this project) · press s to toggle` to `Set all to: <U|P|L> · press s to cycle`. Banner remains under 80-col.
- **D-12:** Global "set all" overwrites per-row state set by Tab hotkey — by design (the user explicitly asked for "set all"). User can re-apply per-row Tab after a global set-all.

### Per-row state array (TUI-SCOPE-04)

- **D-13:** New parallel array `MCP_SELECTED_SCOPE[]` populated by `mcp_status_array` (mcp.sh:269) from the catalog `default_scope` field per index. Length matches `MCP_NAMES[]`. Bash 3.2 compatible (no associative arrays).
- **D-14:** Initialization order at TUI launch: `mcp_catalog_load` → `mcp_status_array` (which now ALSO populates `MCP_SELECTED_SCOPE[]`) → install.sh integrations dispatcher reads `MCP_SELECTED_SCOPE[$i]` per row to build TUI_LABELS with scope glyph and to export `TK_MCP_SCOPE=<scope>` per `mcp_wizard_run` call.
- **D-15:** `default_scope` consumption in `mcp_status_array`: extract via existing `mcp_catalog_load` jq path. The field is already in the catalog as of Phase 36 (SCOPE-01..03). Backward-compat fallback to `user` when missing already lives in `mcp_catalog_load` (Phase 36 D-09).
- **D-16:** Array name reserved: `MCP_SELECTED_SCOPE[]`. Do NOT reuse `TK_MCP_SCOPE` for per-row state — that env var is now strictly the per-call wizard input (Phase 38 contract).

### Dispatcher per-row export (TUI-SCOPE-05)

- **D-17:** `install.sh` integrations dispatcher (the loop that calls `mcp_wizard_run` for each selected MCP) exports `TK_MCP_SCOPE=<MCP_SELECTED_SCOPE[$i]>` for that single invocation, then unsets/resets afterward (or uses the bash `local` scoping inside a function — planner picks).
- **D-18:** Pre-v5.0 single-shell `TK_MCP_SCOPE` global is RETIRED for the TUI dispatcher path. Honored ONLY at the CLI level for `--mcp-scope <scope>` non-interactive force-set (existing v4.9 behavior preserved for non-TUI scripted invocations).
- **D-19:** Project-scope MCPs flow through Phase 38's `TK_MCP_SCOPE=project` branch in `mcp_wizard_run` automatically — no new wizard work this phase. Test seam discipline: TUI tests do NOT need to mock the wizard; they only need to verify the per-row export.

### Tests (TEST-04)

- **D-20:** Extend `scripts/tests/test-mcp-selector.sh` (current PASS=21, must stay floor) by ≥5 assertions:
  - TUI-SCOPE-01: per-row indicator renders in default state — for each MCP row, the label contains `[U]` or `[P]` matching `default_scope` from catalog
  - TUI-SCOPE-02: single-row hotkey flips ONLY focused row — synthetic key press cycles `MCP_SELECTED_SCOPE[$FOCUS_IDX]`, leaves siblings untouched (fingerprint diff of array state before/after)
  - TUI-SCOPE-03: global `s` flips ALL visible rows — synthetic `s` press writes the new scope into every MCP_SELECTED_SCOPE slot, header banner updated
  - TUI-SCOPE-04: `MCP_SELECTED_SCOPE[]` initialized from `default_scope` — assert array length matches MCP_NAMES, values match catalog field per index
  - TUI-SCOPE-05: dispatcher exports per-row TK_MCP_SCOPE — fake mcp_wizard_run captures TK_MCP_SCOPE env at call time, asserts it matches MCP_SELECTED_SCOPE[$i] for each invocation
- **D-21:** Hermetic invariants per Phase 37 contract: `mktemp -d`, trap EXIT INT TERM, no $HOME mutation, double-run-safe.
- **D-22:** Test seams: `TK_TUI_TTY_SRC` (existing — synthetic TTY for TUI), `TK_MCP_CLAUDE_BIN` (existing — fake claude), `TK_MCP_TTY_SRC` (existing). NO new env-var seams introduced.
- **D-23:** Phase 38 baselines must stay green: `test-mcp-wizard.sh` PASS=53, `test-mcp-secrets.sh` PASS=11, `test-project-secrets.sh` PASS=42.

### Claude's Discretion

- Exact hotkey for per-row flip: Tab vs Shift-S vs `t`. Tab is preferred per D-05 but planner verifies bash 3.2 ANSI parsing for the Tab byte (`\t` = 0x09) doesn't conflict with macOS BSD terminal sequences.
- Whether `mcp_status_array` gains a new arg or a new global. Planner mirrors existing pattern at mcp.sh:269 (currently no args, populates globals).
- Footer hint copy under 80-col — planner picks final wording.
- Whether the per-row indicator goes BEFORE or AFTER the existing `[installed ✓]` glyph in the label string. D-01 says AFTER the checkbox; visual layout test in TEST-04 will confirm.
- 4th-state handling: if a future scope value is added (e.g., `enterprise`), the cycle in D-10 + D-05 must be extensible. For now hard-coded U/P/L as 3-state cycle.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §"TUI per-row scope toggle" — TUI-SCOPE-01..05 acceptance criteria
- `.planning/REQUIREMENTS.md` §"Tests" — TEST-04 (test-mcp-selector.sh extension)

### Existing code (read before editing)
- `scripts/lib/tui.sh:127-288` — `_tui_render` (label string composition) + `tui_checklist` case match (key handling)
- `scripts/lib/tui.sh:294+` — `tui_checklist` (where new Tab handler lands)
- `scripts/lib/tui.sh:425-440` — TUI_HEADER_KEY/FN existing dispatch (reused for `s` repurpose)
- `scripts/lib/mcp.sh:269+` — `mcp_status_array` (where MCP_SELECTED_SCOPE[] populates)
- `scripts/lib/mcp.sh:957+` — TUI_HEADER_TEXT/KEY/FN binding (the `s` global toggle to repurpose)
- `scripts/lib/mcp.sh::mcp_catalog_load` — already loads `default_scope` per Phase 36 SCOPE-01..03
- `scripts/install.sh` — integrations dispatcher loop (the per-row export site for TUI-SCOPE-05)
- `scripts/tests/test-mcp-selector.sh` (PASS=21) — TEST-04 extension target
- `scripts/lib/integrations-catalog.json` — read-only; `default_scope` field already present

### Phase 38 contracts (consumed by this phase)
- `.planning/phases/38-wizard-dispatch-integration/38-VERIFICATION.md` — Phase 38 boundary locked: `TK_MCP_SCOPE=project` flow works, `TK_MCP_SCOPE=user|local` preserves v4.6/v4.9 behavior. Phase 39 just needs to set the env var per row before calling the wizard; the wizard does the rest.

### Project conventions
- `.planning/codebase/CONVENTIONS.md` — bash style, hermetic test patterns
- `.planning/codebase/STACK.md` — Bash 3.2 compat invariants
- `CLAUDE.md` — quality gate, commit conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_tui_render` (`tui.sh:127`) — atomic frame composition; the focal-row arrow + checkbox + label pattern is exactly what new scope glyph follows
- `tui_checklist` (`tui.sh:294`) case-match key dispatcher — extension target for Tab key
- TUI_HEADER_KEY / TUI_HEADER_FN globals (`tui.sh:277-288`, `mcp.sh:957+`) — already wire `s` to a caller-supplied function; rebinding to "set all" is a single function-body change
- `mcp_catalog_load` (`mcp.sh`) — already loads `default_scope` per Phase 36; add a parallel-array population call inside or alongside `mcp_status_array`
- `mcp_status_array` (`mcp.sh:269`) — pattern source for new `MCP_SELECTED_SCOPE[]` population (parallel to MCP_STATUS, MCP_HAS_CLI)
- `test-mcp-selector.sh` (PASS=21) — hermetic harness with synthetic TTY input; extension target

### Established Patterns
- Parallel arrays for Bash 3.2 compat (no associative arrays). MCP_SELECTED_SCOPE joins existing MCP_NAMES, MCP_STATUS, MCP_HAS_CLI, MCP_REINSTALLABLE family.
- Caller-builds-TUI_LABELS pattern: tui.sh stays domain-agnostic, mcp.sh injects scope glyph into the label text before passing arrays into `tui_checklist`. Exactly mirrors how `[installed ✓]` / `[reinstall ↻]` are caller-injected today.
- Color discipline: `\e[32m` green for active scope (matches `[installed ✓]` color in tui.sh:225-228); `\e[0m` reset; NO_COLOR-aware via `_TUI_COLOR` flag.
- Test seam discipline: `TK_TUI_TTY_SRC` for synthetic input, no new env vars introduced when existing seams suffice.

### Integration Points
- Phase 38 wizard (`mcp_wizard_run`) consumes per-call `TK_MCP_SCOPE` — Phase 39's dispatcher exports it per row. Zero changes to mcp_wizard_run this phase.
- Phase 40 (uninstall + Calendly + validator) is INDEPENDENT of Phase 39 — different files, different surfaces. Can run in parallel.
- Phase 41 (distribution + docs) bumps manifest 5.0.0 + plugin.json + docs — Phase 39 does NOT touch manifest. Docs section "Per-MCP Scope" in INTEGRATIONS.md (DOCS-01) describes the per-row TUI behavior shipped here, but the docs land in Phase 41.

</code_context>

<specifics>
## Specific Ideas

- "The pre-v5.0 single-shell `TK_MCP_SCOPE` global is retired in favor of per-call injection" — this means the integrations dispatcher must NOT set `TK_MCP_SCOPE` once at start-of-loop and rely on it for all iterations. Each iteration's invocation gets its own export. The CLI-level `--mcp-scope` non-interactive flag (existing v4.9) is preserved.
- "Set ALL visible rows to scope X" — "visible" means MCP rows currently in the TUI viewport; CLI-only rows are excluded by D-03/D-06. If the catalog grows past viewport height, scrolling is unchanged from v4.9 — set-all still applies to all MCP rows regardless of scroll position.
- Hotkey choice constraint: Tab is the strong default per D-05. If macOS BSD bash 3.2 cannot reliably distinguish Tab from other inputs in the current `_tui_read_key` byte parser, planner falls back to `t` (lowercase) which is unmapped today. Test the binding before locking it.
- Global cycle U → P → L (D-10) intentionally omits a "back to default" reset state. If user wants per-MCP defaults again, they restart the TUI. KISS.

</specifics>

<deferred>
## Deferred Ideas

- Uninstall secret-cleanup prompts (UN-SEC-01..05) + Calendly + validator SCOPE-01 assertion — Phase 40
- Documentation updates (INTEGRATIONS.md Per-MCP Scope section, INSTALL.md flag rows) — Phase 41
- CHANGELOG `[5.0.0]` consolidated entry — Phase 41
- Manifest version bump — Phase 41
- `SCOPE-FUT-02` TUI `--preset minimal|full|dev` with per-preset scope assignments — REQUIREMENTS.md Future
- 4th-state handling beyond U/P/L (e.g., `enterprise`) — out of v5.0 scope; revisit when a 4th scope value is requested

</deferred>

---

*Phase: 39-tui-per-row-scope-toggle*
*Context gathered: 2026-05-05*
