# Phase 39: TUI Per-Row Scope Toggle — Pattern Map

**Mapped:** 2026-05-04
**Files analyzed:** 4 (modified) / 0 (new)
**Analogs found:** 4 / 4 (all in-tree, exact)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `scripts/lib/tui.sh` | library / view-renderer | event-driven (keypress → state → render) | (self — `_tui_render` + `tui_checklist` case-match in same file) | exact (extension of existing API) |
| `scripts/lib/mcp.sh` | library / domain-state-builder | request-response (build TUI input arrays + handler fn) | `mcp_status_array` + `mcp_toggle_scope`/`mcp_render_scope_header` (same file) | exact (parallel-array pattern + TUI_HEADER_FN binding) |
| `scripts/install.sh` | controller / dispatcher loop | event-driven loop (per-row export → wizard call) | `install.sh:523-614` (existing TUI dispatch loop with TUI_TO_MCP_IDX translation) | exact (per-row export site already exists) |
| `scripts/tests/test-mcp-selector.sh` | test (hermetic integration) | request-response w/ mock TTY + mock claude | `test-mcp-selector.sh::run_s4_collision_prompt_default_n` + `run_s7_install_sh_mcps_dry_run` (same file) | exact (mktemp+trap RETURN harness + TK_*_TTY_SRC seam) |

## Pattern Assignments

### `scripts/lib/tui.sh` (library, event-driven render + key dispatch)

**Analog:** `scripts/lib/tui.sh` itself — three call sites need surgical extension:
1. `_tui_render` (lines 127-288): label-build is **caller-owned** today; new scope glyph
   piggybacks on the existing `[installed ✓]`/`[reinstall ↻]` color discipline.
2. `tui_checklist` case-match (lines 343-440): add a new `Tab`-byte arm BEFORE the
   catch-all `*)` that currently dispatches `TUI_HEADER_FN`.
3. Footer hint (lines 268-284): extend the `_header_hint` string to advertise the
   per-row binding alongside `s scope`.

**Read-first list (planner pastes into `<read_first>`):**
- `scripts/lib/tui.sh:127-288` (`_tui_render` — full frame composition)
- `scripts/lib/tui.sh:294-455` (`tui_checklist` — case-match dispatcher)

#### Color-discipline pattern for active scope glyph (lines 224-241)

The existing reinstall state shows EXACTLY the discipline new scope glyph follows:
caller injects color codes into `TUI_LABELS[i]` so `_tui_render` stays domain-agnostic.

```bash
# tui.sh:230-241 — render layer applies color modifier per ROW STATE,
# NOT per-glyph. Color choice is _tui_render's responsibility for the
# focal row chrome (numbered prefix + box + label); inline colored
# tokens INSIDE $label are caller-built and pass-through.
if [[ "${_TUI_COLOR:-0}" -eq 1 ]] && [[ "$_reinstall" -eq 1 ]]; then
    # \e[92m — bright (light) green. \e[0m resets all attrs.
    _frame+="$arrow"$'\e[92m'"${row_num}. ${box} ${label}"$'\e[0m\n'
elif [[ "${_TUI_COLOR:-0}" -eq 1 ]] && { [[ "$installed" -eq 1 ]] || [[ "$required" -eq 1 ]]; }; then
    _frame+="$arrow"$'\e[2m'"${row_num}. ${box} ${label}"$'\e[0m\n'
else
    _frame+="${arrow}${row_num}. ${box} ${label}"$'\n'
fi
```

**Pattern to copy:** scope glyph (`[U]`/`[P]`/`[L]`) gets injected into `$label` by
`mcp_status_array` / `install.sh` BEFORE `tui_checklist` is invoked. tui.sh stays
scope-agnostic. The active-glyph green (`\e[32m`) is wrapped + reset INSIDE the
label string by the caller, exactly like the unofficial-entry yellow `!` at
`mcp.sh:1119-1123`.

#### Tab key handler — extension target (case-match at lines 343-440)

The `Tab` byte (ASCII 0x09) is unmapped today. The case-match's catch-all `*)` arm
(line 423-439) currently routes any unrecognized key to `TUI_HEADER_FN` (the `s`
global). New Tab arm MUST land BEFORE the catch-all so it doesn't shadow the
header-fn dispatch.

```bash
# tui.sh:404-439 — exact insertion point. New Tab arm goes after b|B (line 409)
# and BEFORE the catch-all *) (line 423).
        q|Q)
            # Quit — cancel.
            rc=1
            break
            ;;
        b|B)
            # Back — return to previous step in a multi-step flow.
            if [[ "${TK_TUI_ALLOW_BACK:-0}" == "1" ]]; then
                rc=4
                break
            fi
            ;;
        *)
            # Header-toggle key (caller-defined, e.g. `s` for MCP scope).
            # Folded into the catch-all so the gate doesn't shadow b|B
            # above. The function is called with no args; it is expected
            # to mutate TUI_HEADER_TEXT (and any caller-side state) so
            # the next _tui_render shows the new value.
            if [[ -n "${TUI_HEADER_KEY:-}" && -n "${TUI_HEADER_FN:-}" ]]; then
                local _hk_lower="${TUI_HEADER_KEY}"
                local _hk_upper
                _hk_upper=$(printf '%s' "$_hk_lower" | tr '[:lower:]' '[:upper:]' 2>/dev/null || printf '%s' "$_hk_lower")
                if [[ "$key" == "$_hk_lower" || "$key" == "$_hk_upper" ]]; then
                    "${TUI_HEADER_FN}" || true
                fi
            fi
            ;;
```

**Pattern to copy:** mirror the `TUI_HEADER_KEY`/`TUI_HEADER_FN` indirection for the
per-row binding. Introduce parallel `TUI_ROW_KEY` + `TUI_ROW_FN` globals. The new
case arm matches `$'\t'` (Tab byte) and calls `"${TUI_ROW_FN}"` with `FOCUS_IDX`
already in scope (it's a global mutated by the up/down arrows above). The fn is
caller-supplied (mcp.sh) and mutates `MCP_SELECTED_SCOPE[$FOCUS_IDX]` in place,
THEN re-renders by falling through to the loop top (no `break`).

```bash
# Reference indirection pattern — repeat shape for Tab→TUI_ROW_FN dispatch.
# Bash 3.2 has no ${var^^}; use tr.
local _hk_lower="${TUI_HEADER_KEY}"
local _hk_upper
_hk_upper=$(printf '%s' "$_hk_lower" | tr '[:lower:]' '[:upper:]' 2>/dev/null || printf '%s' "$_hk_lower")
if [[ "$key" == "$_hk_lower" || "$key" == "$_hk_upper" ]]; then
    "${TUI_HEADER_FN}" || true
fi
```

#### Footer hint extension (lines 272-284)

```bash
# tui.sh:272-284 — current footer composition.
local _back_hint=""
if [[ "${TK_TUI_ALLOW_BACK:-0}" == "1" ]]; then
    _back_hint=" · b back"
fi
local _header_hint=""
if [[ -n "${TUI_HEADER_KEY:-}" && -n "${TUI_HEADER_FN:-}" ]]; then
    _header_hint=" · ${TUI_HEADER_KEY} scope"
fi
if [[ "${_TUI_COLOR:-0}" -eq 1 ]]; then
    _frame+=$'\n  \e[2m↑↓ navigate · Space toggle · Enter install'"${_header_hint}${_back_hint}"$' · Ctrl+C abort\e[0m\n'
else
    _frame+=$'\n  ↑↓ navigate · Space toggle · Enter install'"${_header_hint}${_back_hint}"$' · Ctrl+C abort\n'
fi
```

**Pattern to copy:** add a parallel `_row_hint` builder gated on `TUI_ROW_KEY`/`TUI_ROW_FN`
presence. Per D-08 the new copy is `Tab row-scope · s set-all-scope` — the existing
`${TUI_HEADER_KEY} scope` substring becomes `${TUI_HEADER_KEY} set-all-scope` (caller
controls TUI_HEADER_KEY=`s` so the substring stays width-budget-safe). Both hints
compose via string concat into the same single-line footer; verify under-80-col fit.

---

### `scripts/lib/mcp.sh` (library, parallel-array population + TUI_HEADER_FN binding)

**Analog:** `mcp_status_array` (lines 1031-1173) for the new `MCP_SELECTED_SCOPE[]`
population AND `mcp_toggle_scope`/`mcp_render_scope_header` (lines 973-1003) for the
repurposed "set all" header function.

**Read-first list (planner pastes into `<read_first>`):**
- `scripts/lib/mcp.sh:99-196` (`mcp_catalog_load` — already loads `default_scope` per Phase 36 SCOPE-03)
- `scripts/lib/mcp.sh:957-1003` (`mcp_render_scope_header` + `mcp_toggle_scope` — to repurpose)
- `scripts/lib/mcp.sh:1031-1173` (`mcp_status_array` — the population site)

#### Parallel-array population pattern (lines 1031-1115)

```bash
# mcp.sh:1031-1054 — mcp_status_array entry point + array reset.
mcp_status_array() {
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi
    if [[ -z "${CATEGORIES_ORDER[*]+x}" ]] || [[ "${#CATEGORIES_ORDER[@]}" -eq 0 ]]; then
        mcp_categories_load || return 1
    fi

    # Detect once per launch (D-11) — populates MCP_STATUS[] + CLI_STATUS[].
    mcp_status_detect

    TUI_LABELS=()
    TUI_GROUPS=()
    TUI_INSTALLED=()
    TUI_DESCS=()
    TUI_GROUP_NAMES=()
    TUI_GROUP_DESCS=()
    TUI_REINSTALLABLE=()
    TUI_TO_MCP_IDX=()
    MCP_TO_TUI_IDX=()
```

**Pattern to copy:** add `MCP_SELECTED_SCOPE=()` to the reset block. Inside the
emit loop (lines 1107-1169) push `MCP_SELECTED_SCOPE+=("${MCP_DEFAULT_SCOPE[$i]}")`
ALONGSIDE the existing `TUI_LABELS+=` push so the array stays parallel to the TUI
render index (NOT MCP_NAMES alphabetical index — D-04 + Phase 34-01 ordering rule).
The catalog already populates `MCP_DEFAULT_SCOPE[$i]` per `MCP_NAMES[$i]` index at
`mcp.sh:194`, so the reorder is mechanical: read by `$i` (MCP_NAMES idx, lines
1107-1108), push in TUI order alongside `TUI_TO_MCP_IDX+=("$i")` at line 1114.

#### Label injection — caller builds the scope glyph (lines 1107-1127)

```bash
# mcp.sh:1107-1127 — label string composition. Yellow `!` for unofficial entries
# is the EXACT shape new scope glyph follows.
for j in "${seen_idx[@]+"${seen_idx[@]}"}"; do
    i="$j"
    name="${MCP_NAMES[$i]}"
    desc="${MCP_DESCS[$i]}"

    TUI_TO_MCP_IDX+=("$i")
    MCP_TO_TUI_IDX[$i]="${#TUI_LABELS[@]}"

    # Yellow `!` for unofficial entries (TUI-03 badge).
    if [[ "${MCP_UNOFFICIAL[$i]:-0}" == "1" ]]; then
        if [[ -n "$_c_y" ]]; then
            label="${_c_y}${_g_bang}${_c_nc} ${MCP_DISPLAY[$i]}"
        else
            label="[!] ${MCP_DISPLAY[$i]}"
        fi
    else
        label="${MCP_DISPLAY[$i]}"
    fi
    TUI_LABELS+=("$label")
    TUI_GROUPS+=("$cat_display")
```

**Pattern to copy:** scope glyph injection mirrors `_c_y`/`_g_bang` (yellow `!`)
shape — but pulls from `MCP_DEFAULT_SCOPE[$i]`. Per D-01 the glyph goes BETWEEN
the box and the label text — but `_tui_render` owns the box, so `mcp_status_array`
prepends the bracketed scope token to `$label`. Final shape:
`label="[U] ${MCP_DISPLAY[$i]}"` (or with `\e[32m...\e[0m` wrap when active).

The active scope is `MCP_DEFAULT_SCOPE[$i]` at TUI launch; **only the active scope's
bracket** gets the green color. Use the same `_c_*`/`_g_*` resolver pattern at
mcp.sh:1076-1084:

```bash
# Reference: NO_COLOR-aware glyph resolver pattern from mcp.sh:1076-1084.
local _g_ok="✓" _g_no="✗" _g_unk="⊘" _g_na="—" _g_bang="!"
local _c_ok="" _c_no="" _c_unk="" _c_y="" _c_nc=""
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    _c_ok=$'\033[0;32m'
    _c_no=$'\033[0;31m'
    _c_unk=$'\033[0;36m'
    _c_y=$'\033[1;33m'
    _c_nc=$'\033[0m'
fi
```

**Pattern to copy:** add `_c_scope=$'\033[0;32m'` (mirror `_c_ok` — green active),
prefix the bracketed scope token with it when that bracket matches
`MCP_DEFAULT_SCOPE[$i]`, reset with `_c_nc`. Plain `[U]`/`[P]`/`[L]` under
NO_COLOR or non-TTY. **Per D-04, glyph is built ONCE at array-build time** — NOT
recomputed each frame.

#### TUI_HEADER_FN repurpose — `mcp_toggle_scope` (lines 995-1003)

```bash
# mcp.sh:995-1003 — current 2-state toggle, replaced by 3-state cycle that
# writes ALL MCP_SELECTED_SCOPE[$i] slots.
mcp_toggle_scope() {
    if [[ "${TK_MCP_SCOPE:-user}" == "user" ]]; then
        TK_MCP_SCOPE="local"
    else
        TK_MCP_SCOPE="user"
    fi
    export TK_MCP_SCOPE
    mcp_render_scope_header
}
```

**Pattern to copy:** repurpose to cycle a *local* "global pending" state through
`user → project → local → user` (D-10), then for-loop write the new value into
EVERY `MCP_SELECTED_SCOPE[$i]` slot. **Critical:** stop exporting `TK_MCP_SCOPE`
here (D-18) — the env var is now per-call from the dispatcher, not shell-global.
Re-render banner via the renamed `mcp_render_scope_header` (banner copy update
per D-11: `Set all to: <U|P|L> · press s to cycle`).

```bash
# mcp.sh:973-993 — current banner builder. Update copy per D-11.
mcp_render_scope_header() {
    local _cur="${TK_MCP_SCOPE:-user}"
    local _user_glyph="◯" _local_glyph="◯"
    case "$_cur" in
        local)  _local_glyph="◉" ;;
        *)      _user_glyph="◉"; _cur="user" ;;
    esac
    if [[ "${_TUI_COLOR:-1}" -eq 1 ]] && [[ -z "${NO_COLOR+x}" ]]; then
        TUI_HEADER_TEXT=$'\e[1mScope:\e[0m '
        ...
    else
        TUI_HEADER_TEXT="Scope: ${_user_glyph} user (global)  ${_local_glyph} local (this project)  · press s to toggle"
    fi
}
```

**Pattern to copy:** rebuild `TUI_HEADER_TEXT` to read `Set all to: U|P|L · press s to cycle`
(under 80-col, NO_COLOR-aware). Track the "global pending" value in a module-local
shell variable (e.g., `_MCP_SETALL_SCOPE`) — NOT in `TK_MCP_SCOPE` (which is now
strictly the per-call wizard input).

---

### `scripts/install.sh` (controller, dispatcher loop with per-row export)

**Analog:** `install.sh:382-471` (TUI launch + scope wiring) AND `install.sh:523-614`
(the existing dispatch loop with TUI_TO_MCP_IDX index translation — the per-row
export site).

**Read-first list (planner pastes into `<read_first>`):**
- `scripts/install.sh:382-479` (TUI launch + current `TK_MCP_SCOPE`/`TUI_HEADER_*` wiring)
- `scripts/install.sh:455-471` (existing scope wiring block — modification target)
- `scripts/install.sh:517-614` (dispatch loop with TUI_TO_MCP_IDX translation — export site)
- `scripts/install.sh:801-818` (4-field deferred-queue reader — Phase 38 contract; no change this phase)

#### Existing TUI launch + scope wiring (lines 455-471)

```bash
# install.sh:455-471 — current Phase 37 wiring. The block below is
# Phase 39's primary modification target.
        # Phase 37: wire up scope toggle banner. `s` cycles user ↔ local;
        # default = user (global) so MCPs land in ~/.claude.json regardless
        # of cwd. Refresh the header text first so the banner reflects any
        # value already set via --mcp-scope=… (env wins over default).
        TK_MCP_SCOPE="${TK_MCP_SCOPE:-user}"
        export TK_MCP_SCOPE
        mcp_render_scope_header
        # shellcheck disable=SC2034  # consumed by tui.sh _tui_render via TUI_HEADER_KEY/FN
        TUI_HEADER_KEY="s"
        # shellcheck disable=SC2034
        TUI_HEADER_FN="mcp_toggle_scope"
        if ! tui_checklist; then
            unset TUI_HEADER_TEXT TUI_HEADER_KEY TUI_HEADER_FN
            echo "MCP install cancelled."
            exit 0
        fi
        unset TUI_HEADER_TEXT TUI_HEADER_KEY TUI_HEADER_FN
```

**Pattern to copy:** add `TUI_ROW_KEY=$'\t'` (Tab byte) and `TUI_ROW_FN="mcp_cycle_row_scope"`
(new function the planner adds in mcp.sh) alongside the existing `TUI_HEADER_*`
exports. Add to the unset list on cancel + post-success path. Keep the existing
`TK_MCP_SCOPE="${TK_MCP_SCOPE:-user}"` line for the CLI `--mcp-scope` honor (D-18
preserves CLI level), but DROP the `mcp_render_scope_header` call here in favor of
the repurposed builder that reads `_MCP_SETALL_SCOPE` (or whatever module-local
the planner picks).

#### Per-row export site — dispatch loop (lines 523-614)

```bash
# install.sh:517-614 — dispatch loop. Key index translation already lives here.
# Phase 39 hooks the per-row TK_MCP_SCOPE export immediately BEFORE the
# `mcp_wizard_run` call at line 611-613.
local_mcp_count=${#TUI_LABELS[@]}
for ((tui_i=0; tui_i<local_mcp_count; tui_i++)); do
    i="${TUI_TO_MCP_IDX[$tui_i]:-$tui_i}"
    local_name="${MCP_NAMES[$i]}"
    COMPONENT_NAMES+=("$local_name")
    RESULT_NAMES+=("$local_name")
    if [[ "${TUI_RESULTS[$tui_i]:-0}" -ne 1 ]]; then
        ...continue
    fi
    ...
    local_flags=()
    [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")
    ...
    local_rc=0
    if [[ -n "$stderr_tmp" ]]; then
        ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) >"$stderr_tmp" 2>&1 || local_rc=$?
    else
        mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
    fi
```

**Pattern to copy (TUI-SCOPE-05):** before the `( mcp_wizard_run ... )` subshell at
line 611, set `TK_MCP_SCOPE="${MCP_SELECTED_SCOPE[$tui_i]:-user}"; export TK_MCP_SCOPE`.
Two key invariants:

1. **Index basis: `$tui_i`** — `MCP_SELECTED_SCOPE[]` is parallel to TUI render
   order (D-13/D-14). Use `$tui_i`, NOT `$i` (which is the MCP_NAMES alphabetical
   index — wrong frame).
2. **Per-call, not per-loop:** Phase 38's wizard reads `TK_MCP_SCOPE` fresh on each
   invocation; the export at line 459 (start of the loop) is preserved ONLY for the
   v4.9 CLI `--mcp-scope` non-interactive path. The TUI dispatcher path overwrites
   the env per iteration.

The Phase 38 reinstall removal at lines 596-606 already reads `_scope_for_rm="${TK_MCP_SCOPE:-user}"`,
so it picks up the per-row scope automatically once the export above it is in place
— no second change needed at the remove site (it's downstream of the export).

#### Reinstall path — scope-aware remove (lines 591-607, no change required this phase)

```bash
# install.sh:591-607 — Phase 37 wired this with --scope. Phase 39's per-row
# TK_MCP_SCOPE export above means this block now reads the row-correct scope
# automatically. Quoted here for the planner to verify, NOT to edit.
local_reinstall=0
if [[ "${TUI_INSTALLED[$tui_i]:-0}" -eq 1 ]]; then
    local_reinstall=1
    if [[ "$DRY_RUN" -ne 1 ]]; then
        _claude_bin="${TK_MCP_CLAUDE_BIN:-claude}"
        _scope_for_rm="${TK_MCP_SCOPE:-user}"
        "$_claude_bin" mcp remove --scope "$_scope_for_rm" "$local_name" >/dev/null 2>&1 || true
        unset _claude_bin _scope_for_rm
    fi
fi
```

**Pattern to verify (no edit):** the per-row export injected above this block makes
`_scope_for_rm` row-correct for free. The planner's smoke test must confirm a
project-scope reinstall removes from `--scope project` (not `--scope user`).

---

### `scripts/tests/test-mcp-selector.sh` (test, hermetic integration)

**Analog:** `run_s4_collision_prompt_default_n` (lines 223-257) for TTY-fixture
synthetic input AND `run_s7_install_sh_mcps_dry_run` (lines 351-385) for end-to-end
install.sh smoke with mock `claude` binary.

**Read-first list (planner pastes into `<read_first>`):**
- `scripts/tests/test-mcp-selector.sh:1-57` (file header + assert helpers)
- `scripts/tests/test-mcp-selector.sh:223-294` (S4/S5 — TTY-fixture pattern)
- `scripts/tests/test-mcp-selector.sh:351-412` (S7/S8 — install.sh end-to-end pattern)
- `scripts/tests/test-mcp-selector.sh:414-424` (test runner + result reporter)

#### Hermetic harness pattern (lines 223-257)

```bash
# test-mcp-selector.sh:223-257 — exact shape new TUI-SCOPE-* assertions copy.
run_s4_collision_prompt_default_n() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_collision_prompt_default_n: collision default N preserves existing --"

    mkdir -p "$SANDBOX/.claude"
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"

    # Write initial value
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_set FOO bar

    # Write fixture for TTY — answer "N"
    printf 'N\n' > "$SANDBOX/tty.fix"

    # Attempt overwrite with default-N fixture
    TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_TTY_SRC="$SANDBOX/tty.fix" \
        mcp_secrets_set FOO new_value 2>/dev/null || true

    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_load
    assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "S4: default-N preserves original FOO=bar"
    ...
}
```

**Pattern to copy:** every new `run_s9_*` / `run_s10_*` (etc.) function:
1. `mktemp -d /tmp/test-mcp-selector.XXXXXX` for sandbox.
2. `trap "rm -rf '${SANDBOX:?}'" RETURN` for cleanup (function-scoped, not EXIT —
   so multiple test fns don't stomp each other's traps).
3. Reset MCP_* arrays explicitly before sourcing mcp.sh (idempotency invariant).
4. Source `${REPO_ROOT}/scripts/lib/mcp.sh` — never mutate `$HOME`.
5. TTY fixture via `printf 'value\n' > "$SANDBOX/tty.fix"; TK_TUI_TTY_SRC=...`
   (same seam discipline as S4's `TK_MCP_TTY_SRC` — D-22 forbids new seams).

#### TUI-SCOPE assertion patterns

**TUI-SCOPE-01 (per-row indicator render in default state):**
```bash
# Use S1's pattern — load catalog, populate arrays, assert label content.
source "${REPO_ROOT}/scripts/lib/mcp.sh"
mcp_catalog_load
# Phase 39: trigger MCP_SELECTED_SCOPE[] population
# (planner picks: dedicated mcp_status_array call, or new helper).
mcp_status_array
# Per-row label must contain bracketed scope token.
# Find context7 in TUI render order via TUI_TO_MCP_IDX.
local _idx_ctx7=-1
for ((j=0; j<${#TUI_LABELS[@]}; j++)); do
    _i_mcp="${TUI_TO_MCP_IDX[$j]}"
    if [[ "${MCP_NAMES[$_i_mcp]}" == "context7" ]]; then
        _idx_ctx7=$j
        break
    fi
done
# context7 default_scope=user → label contains [U]
assert_contains '\[U\]' "${TUI_LABELS[$_idx_ctx7]}" "TUI-SCOPE-01: context7 row carries [U] indicator"
```

**TUI-SCOPE-04 (`MCP_SELECTED_SCOPE[]` initialized from `default_scope`):**
```bash
# Length parity + per-index value check.
assert_eq "${#TUI_LABELS[@]}" "${#MCP_SELECTED_SCOPE[@]}" "TUI-SCOPE-04: array parallel to TUI render index"
# Per-index: MCP_SELECTED_SCOPE[tui_i] matches MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[tui_i]]
for ((j=0; j<${#TUI_LABELS[@]}; j++)); do
    _i_mcp="${TUI_TO_MCP_IDX[$j]}"
    assert_eq "${MCP_DEFAULT_SCOPE[$_i_mcp]}" "${MCP_SELECTED_SCOPE[$j]}" \
        "TUI-SCOPE-04: row $j scope matches catalog default for ${MCP_NAMES[$_i_mcp]}"
done
```

**TUI-SCOPE-02/03 (single-row hotkey + global set-all):**
```bash
# Direct fn invocation — no need to mock the keypress dispatch (KISS).
# Test the state-mutation contract; tui.sh's case-match wiring is
# covered by the Tab→TUI_ROW_FN dispatch test (separate fn-existence check).

# TUI-SCOPE-02: single-row cycle.
FOCUS_IDX=2  # Pick a known row.
_before_other="${MCP_SELECTED_SCOPE[0]}"  # Sibling fingerprint.
mcp_cycle_row_scope  # planner-named fn that mutates MCP_SELECTED_SCOPE[$FOCUS_IDX]
assert_eq "$_before_other" "${MCP_SELECTED_SCOPE[0]}" "TUI-SCOPE-02: sibling row 0 untouched"
# Cycled row 2 changed (was user/project/local — assert it cycled to next).

# TUI-SCOPE-03: set-all overwrites every slot.
# (planner names the fn — likely the repurposed mcp_toggle_scope).
mcp_toggle_scope  # cycles _MCP_SETALL_SCOPE: user→project→local
for ((j=0; j<${#MCP_SELECTED_SCOPE[@]}; j++)); do
    assert_eq "$_MCP_SETALL_SCOPE" "${MCP_SELECTED_SCOPE[$j]}" "TUI-SCOPE-03: row $j cycled to set-all"
done
```

#### Mock claude pattern for end-to-end dispatch test (lines 309-345 + 360-369)

```bash
# test-mcp-selector.sh:309-312 — minimal mock claude binary.
local MOCK_CLAUDE="$SANDBOX/mock-claude"
printf '#!/bin/bash\nexit 0\n' > "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"
```

**Pattern to copy (TUI-SCOPE-05):** mock claude that LOGS its argv (per Phase 38
T7-T12 pattern — verifying exported env var presence). Capture `TK_MCP_SCOPE` at
call time:

```bash
# Mock claude that records env at invocation, mirrors Phase 38 T7 (test-mcp-wizard.sh).
cat > "$MOCK_CLAUDE" <<MOCK
#!/bin/bash
echo "TK_MCP_SCOPE=\${TK_MCP_SCOPE:-UNSET}" >> "$SANDBOX/scope-trace.log"
echo "argv=\$*" >> "$SANDBOX/scope-trace.log"
exit 0
MOCK
chmod +x "$MOCK_CLAUDE"
```

Then assert each row's invocation carried the expected scope. Use `TK_MCP_PRE_SELECTED`
to bypass the TUI (S7's pattern) so the dispatcher loop runs headlessly:

```bash
# install.sh:413 — TK_MCP_PRE_SELECTED bypasses TUI; dispatcher still exports per-row scope.
TK_MCP_PRE_SELECTED="context7,supabase" \
TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
TK_MCP_CONFIG_HOME="$SANDBOX" \
HOME="$SANDBOX" \
NO_COLOR=1 \
bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes 2>&1
```

For TUI-SCOPE-05, after the run, inspect `$SANDBOX/scope-trace.log` and assert two
distinct `TK_MCP_SCOPE` values appear (one per MCP, matching their `default_scope`).

#### Test runner extension (lines 414-424)

```bash
# test-mcp-selector.sh:414-424 — runner block. Append new test fns here.
run_s1_catalog_correctness
run_s2_detection_three_state
run_s3_secret_persistence_and_mode
run_s4_collision_prompt_default_n
run_s5_collision_prompt_y_overwrites
run_s6_wizard_hidden_input_no_leak
run_s7_install_sh_mcps_dry_run
run_s8_install_sh_mcps_no_cli

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
```

**Pattern to copy:** append `run_s9_per_row_indicator`, `run_s10_per_row_hotkey`,
`run_s11_global_set_all`, `run_s12_default_scope_init`, `run_s13_dispatcher_per_row_export`
(planner picks final names) BEFORE the `Result:` echo. Each fn adds ≥1 assertion;
collectively ≥5 (D-20). PASS=21 floor preserved (TEST-04 contract).

**Hermetic discipline checklist** (D-21):
- [ ] `mktemp -d` per scenario.
- [ ] `trap "rm -rf '${SANDBOX:?}'" RETURN` (NOT EXIT).
- [ ] No `$HOME` mutation outside `HOME="$SANDBOX"` env-wrapping.
- [ ] Double-run safe: assertions don't depend on prior scenario state.
- [ ] Existing seams only: `TK_TUI_TTY_SRC`, `TK_MCP_CLAUDE_BIN`, `TK_MCP_TTY_SRC`,
      `TK_MCP_CONFIG_HOME`, `TK_MCP_PRE_SELECTED`, `NO_COLOR=1`. **No new seams** (D-22).

---

## Shared Patterns

### Bash 3.2 parallel-array discipline

**Source:** `scripts/lib/mcp.sh:99-196` (`mcp_catalog_load`) and `mcp.sh:1031-1115`
(`mcp_status_array`). All Phase 39 array ops (esp. new `MCP_SELECTED_SCOPE[]`) follow
this discipline.

**Apply to:** all Phase 39 changes in mcp.sh.

```bash
# Pattern A — declare-and-reset block at fn entry (mcp.sh:1044-1049).
TUI_LABELS=()
TUI_GROUPS=()
TUI_INSTALLED=()
TUI_DESCS=()
TUI_GROUP_NAMES=()
TUI_GROUP_DESCS=()
# NEW: MCP_SELECTED_SCOPE=()  ← parallel to TUI_LABELS

# Pattern B — array-empty test (mcp.sh:1037, repeated at tui.sh:185).
# Bash 3.2 cannot do `${#var[@]:-0}` (rejected as bad-substitution).
# Use `${var[*]+x}` existence check.
if [[ -z "${CATEGORIES_ORDER[*]+x}" ]] || [[ "${#CATEGORIES_ORDER[@]}" -eq 0 ]]; then
    mcp_categories_load || return 1
fi

# Pattern C — safe array iteration with optional-empty guard
# (mcp.sh:1090, 1107, 1235, etc.).
for cat in "${CATEGORIES_ORDER[@]+"${CATEGORIES_ORDER[@]}"}"; do
    ...
done
```

### Color discipline (NO_COLOR-aware, TTY-gated)

**Source:** `scripts/lib/tui.sh:54-64` (`_tui_init_colors`) + `mcp.sh:1076-1084`
(per-fn glyph resolver).

**Apply to:** all Phase 39 user-visible color decisions.

```bash
# tui.sh:54-64 — color gating.
_tui_init_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [[ "${TERM:-dumb}" != "dumb" ]]; then
        _TUI_COLOR=1
    else
        _TUI_COLOR=0
    fi
}

# mcp.sh:1076-1084 — per-fn resolver. Resolve ONCE per array build, append into
# array values verbatim. _c_* are color codes, _g_* are glyphs.
local _g_ok="✓" _g_no="✗" _g_unk="⊘" _g_na="—" _g_bang="!"
local _c_ok="" _c_no="" _c_unk="" _c_y="" _c_nc=""
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    _c_ok=$'\033[0;32m'
    ...
    _c_nc=$'\033[0m'
fi
```

**Active-scope-glyph rule:** green (`\e[32m` / `\033[0;32m` — same code) wraps ONLY
the bracket of the active scope. Inactive brackets stay plain. Under NO_COLOR or
non-TTY, all three brackets are plain.

### Test seam discipline (D-22)

**Source:** `scripts/lib/tui.sh:6-13` (header) + `scripts/lib/mcp.sh::mcp_secrets_set`
contract.

**Apply to:** all Phase 39 test assertions.

| Seam | Purpose | Phase 39 use |
|------|---------|--------------|
| `TK_TUI_TTY_SRC` | Synthetic TTY for TUI keypress fixture | Tab/`s` keypress simulation |
| `TK_MCP_CLAUDE_BIN` | Mock claude binary path | TUI-SCOPE-05 argv/env capture |
| `TK_MCP_TTY_SRC` | Synthetic TTY for `mcp_secrets_set` | (no Phase 39 use; preserved baseline) |
| `TK_MCP_CONFIG_HOME` | Sandbox `~/.claude/` location | TUI-SCOPE-05 e2e isolation |
| `TK_MCP_PRE_SELECTED` | TUI bypass (headless) | TUI-SCOPE-05 dispatcher loop drive |
| `NO_COLOR=1` | Plain-bracket assertions | TUI-SCOPE-01 deterministic indicator |

**Forbidden:** new env vars introduced by Phase 39. D-22 explicitly forecloses.

---

## No Analog Found

None. All four modified files have exact in-tree analogs. Phase 39 is purely a
surgical extension of established patterns; no green-field code paths.

## Metadata

**Analog search scope:** `scripts/lib/`, `scripts/`, `scripts/tests/`
**Files scanned:** 4 (modified targets) + 12 reference files (Phase 36/37/38 verification reports + REQUIREMENTS.md)
**Pattern extraction date:** 2026-05-04
**Phase 38 boundary preserved:** verified — `mcp_wizard_run` reads `TK_MCP_SCOPE`
fresh per call (Phase 38 contract), so per-row export from install.sh dispatcher
flows through unchanged. No mcp_wizard_run modification this phase.
