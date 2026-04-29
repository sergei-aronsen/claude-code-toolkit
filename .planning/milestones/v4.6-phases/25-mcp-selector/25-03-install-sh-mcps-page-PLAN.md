---
phase: 25
plan: "03"
type: execute
wave: 3
depends_on:
  - "25-01"
  - "25-02"
files_modified:
  - scripts/install.sh
  - scripts/lib/mcp.sh
autonomous: true
requirements:
  - MCP-03
tags: [bash, install, tui, dispatch, phase-25]

must_haves:
  truths:
    - "scripts/install.sh learns a --mcps flag that routes to a NEW second TUI page rendering the 9-MCP catalog (NOT the Phase 24 components page)"
    - "When --mcps is the only flag, the components TUI page is NOT rendered (mutex routing — components and MCPs are separate pages, run separate flows)"
    - "The MCP TUI page reuses tui_checklist by populating TUI_LABELS/TUI_GROUPS/TUI_INSTALLED/TUI_DESCS with the 9 catalog entries (per-MCP detected status from is_mcp_installed)"
    - "is_mcp_installed return code 2 (CLI absent) renders the row with '[?]' status glyph and the install action is DISABLED (the per-row entry shows [unavailable]; pressing space is no-op)"
    - "When CLI is absent, install.sh --mcps prints a banner 'claude CLI not found — see docs/MCP-SETUP.md' BEFORE rendering the catalog, and exits 0 after rendering (read-only browse mode)"
    - "After tui_confirm_prompt returns y, install.sh iterates selected MCPs and calls mcp_wizard_run for each; per-MCP status (installed ✓ / skipped / failed: <stderr>) accumulates in parallel arrays just like the Phase 24 components dispatch loop"
    - "Failure of one MCP wizard does NOT abort the rest (continue-on-error per Phase 24 D-08; --fail-fast inherited from Phase 24 still applies if user passes it)"
    - "--yes --mcps installs all uninstalled MCPs from the catalog non-interactively, BUT skips OAuth-only MCPs unless --force (because OAuth needs user interaction)"
    - "--dry-run --mcps prints would-install rows for selected MCPs, no claude invocations, exit 0"
    - "Existing Phase 24 default flow (no --mcps flag) is byte-identical: same components page, same TK_DISPATCH_ORDER, same exit codes — BACKCOMPAT-01 invariant preserved"
    - "test-bootstrap.sh 26 assertions stay green — no changes to init-claude.sh, no changes to bootstrap.sh"
  artifacts:
    - path: "scripts/install.sh"
      provides: "--mcps flag + MCP page routing"
      contains: "--mcps mcp_catalog_load mcp_wizard_run"
    - path: "scripts/lib/mcp.sh"
      provides: "Helper to drive the catalog-page status array assembly (mcp_status_array)"
      contains: "mcp_status_array"
  key_links:
    - from: "scripts/install.sh --mcps"
      to: "scripts/lib/mcp.sh"
      via: "_source_lib mcp"
      pattern: "_source_lib mcp"
    - from: "scripts/install.sh --mcps"
      to: "scripts/lib/tui.sh tui_checklist"
      via: "TUI_LABELS/INSTALLED/GROUPS/DESCS populated from MCP_NAMES/MCP_DISPLAY"
      pattern: "TUI_LABELS=.*MCP_DISPLAY"
    - from: "selected MCPs"
      to: "mcp_wizard_run"
      via: "for-loop over TUI_RESULTS"
      pattern: "mcp_wizard_run"
---

<objective>
Wire the `--mcps` flag into `scripts/install.sh` so a developer running `bash <(curl -sSL .../install.sh) --mcps` sees a TUI catalog page of all 9 MCPs with per-MCP detected status, can select one or more, and the wizard from Plan 02 runs for each. This delivers MCP-03 (the install.sh integration point).

Key design decisions made for executors:

1. **Mutex routing, not stacked pages.** When `--mcps` is passed, the components page is NOT shown. Conversely, the default invocation (no `--mcps`) preserves the Phase 24 components page byte-identically. This keeps each install run focused on one concern. Future-Phase 26 `--skills` will follow the same pattern.

2. **Reuse `tui_checklist`, do not write a parallel renderer.** The MCP page populates the same `TUI_LABELS / TUI_GROUPS / TUI_INSTALLED / TUI_DESCS` arrays that the components page used. The `tui_checklist` function is generic — it doesn't care what the items represent.

3. **Three-state detection rendering.** `is_mcp_installed` returns 0/1/2. `tui.sh` only knows binary 0/1 for `TUI_INSTALLED[]`. Solution: when state=2 (CLI absent), set `TUI_INSTALLED[i]=0` AND populate `TUI_DESCS[i]` with a warning glyph "[unavailable] " prefix. The wizard short-circuits on state=2 anyway, so toggling is harmless.

4. **CLI-absent banner THEN render.** Per CONTEXT.md "Claude CLI absent" decision: render the catalog so the user can browse, but emit a banner before the menu and exit 0 after the user dismisses it (or after dispatch which will return 2 for every wizard).

Output: `scripts/install.sh` modified to add the `--mcps` flag and routing branch; `scripts/lib/mcp.sh` gains a `mcp_status_array` helper to populate the parallel arrays for the TUI. ZERO modifications to `tui.sh`, `detect2.sh`, `dispatch.sh`, `bootstrap.sh`, `init-claude.sh`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/25-mcp-selector/25-CONTEXT.md
@.planning/phases/25-mcp-selector/25-01-mcp-catalog-and-loader-SUMMARY.md
@.planning/phases/25-mcp-selector/25-02-wizard-and-secrets-SUMMARY.md
@scripts/install.sh
@scripts/lib/mcp.sh
@scripts/lib/tui.sh
@scripts/lib/detect2.sh

<interfaces>
<!-- From scripts/install.sh (Phase 24, lines 44-75) — flag-parsing pattern -->

```bash
# Existing flag parser (preserve unchanged):
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)       YES=1;       shift ;;
        --no-color)  NO_COLOR=1;  export NO_COLOR; shift ;;
        --dry-run)   DRY_RUN=1;   shift ;;
        --force)     FORCE=1;     shift ;;
        --fail-fast) FAIL_FAST=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
        # NEW (this plan): --mcps adds MCPS=1 mode
        # ...existing -h|--help and *) catch-all...
    esac
done
```

<!-- From scripts/install.sh (lines 142-156) — TUI array population pattern -->

```bash
# Components page populates these arrays (preserve unchanged for default flow):
TUI_LABELS=("superpowers" "get-shit-done" "toolkit" "security" "rtk" "statusline")
TUI_GROUPS=("Bootstrap"   "Bootstrap"      "Core"    "Optional" "Optional" "Optional")
TUI_INSTALLED=("$IS_SP" "$IS_GSD" "$IS_TK" "$IS_SEC" "$IS_RTK" "$IS_SL")
TUI_DESCS=( "..." "..." )
```

The MCP branch populates the SAME array names with the 9 MCP entries, then calls `tui_checklist` exactly like the components branch.

<!-- From scripts/lib/mcp.sh (Plans 01/02) -->

```bash
mcp_catalog_load          # populates MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH
is_mcp_installed <name>   # 0=installed, 1=not installed, 2=CLI absent
mcp_wizard_run <name> [--dry-run]   # 0=ok, 1=error, 2=CLI absent
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add mcp_status_array helper to scripts/lib/mcp.sh</name>
  <files>scripts/lib/mcp.sh</files>
  <read_first>
    - scripts/lib/mcp.sh (existing functions from Plans 01 + 02)
    - scripts/install.sh:142-156 (Phase 24 components TUI array population — mirror the structure)
    - scripts/lib/tui.sh:100-160 (_tui_render — what TUI_INSTALLED/TUI_DESCS expect)
  </read_first>
  <behavior>
    - mcp_status_array populates TUI_LABELS / TUI_GROUPS / TUI_INSTALLED / TUI_DESCS as 9-element parallel arrays
    - TUI_LABELS contains the 9 names from MCP_NAMES (alpha-sorted)
    - TUI_GROUPS contains "MCP" for all 9 entries (single group — TUI renders one section header)
    - For each MCP, calls is_mcp_installed and maps the return: 0→TUI_INSTALLED=1, 1→TUI_INSTALLED=0, 2→TUI_INSTALLED=0 AND prepends "[unavailable] " to the description
    - TUI_DESCS contains the description string from MCP_DESCS, optionally prefixed with "[unavailable] " when CLI is absent
    - After mcp_status_array runs, MCP_CLI_PRESENT=1 if at least one probe returned 0 or 1 (CLI was reachable); MCP_CLI_PRESENT=0 if ALL 9 probes returned 2
    - Function is idempotent — calling it twice produces the same arrays
  </behavior>
  <action>
APPEND to `scripts/lib/mcp.sh` (after the wizard from Plan 02):

```bash
# ─────────────────────────────────────────────────
# TUI page assembly helper (MCP-03)
# ─────────────────────────────────────────────────

# mcp_status_array — populate TUI_LABELS/GROUPS/INSTALLED/DESCS for the MCP page.
# Side effects: writes to global arrays consumed by tui_checklist (from lib/tui.sh).
# Globals (write):
#   TUI_LABELS[]      — 9 names (alpha)
#   TUI_GROUPS[]      — all "MCP" (single section)
#   TUI_INSTALLED[]   — 0/1 per probe (state=2 maps to 0 with [unavailable] in desc)
#   TUI_DESCS[]       — description strings (prefixed when CLI absent)
#   MCP_CLI_PRESENT   — 0 if all 9 probes returned 2 (no CLI), 1 otherwise
mcp_status_array() {
    if [[ "${#MCP_NAMES[@]}" -eq 0 ]]; then
        mcp_catalog_load || return 1
    fi
    TUI_LABELS=()
    TUI_GROUPS=()
    TUI_INSTALLED=()
    TUI_DESCS=()
    MCP_CLI_PRESENT=0
    local i name desc rc=0
    for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
        name="${MCP_NAMES[$i]}"
        desc="${MCP_DESCS[$i]}"
        TUI_LABELS+=("${MCP_DISPLAY[$i]}")
        TUI_GROUPS+=("MCP")
        rc=0
        is_mcp_installed "$name" || rc=$?
        case "$rc" in
            0)
                TUI_INSTALLED+=(1)
                MCP_CLI_PRESENT=1
                ;;
            1)
                TUI_INSTALLED+=(0)
                MCP_CLI_PRESENT=1
                ;;
            *)
                # rc=2 (CLI absent or list failed) — render row but mark unavailable.
                TUI_INSTALLED+=(0)
                desc="[unavailable] ${desc}"
                ;;
        esac
        TUI_DESCS+=("$desc")
    done
    export MCP_CLI_PRESENT
}
```

Note the case statement uses `*)` for the default branch instead of explicit `2)` — this is intentional because `is_mcp_installed` could theoretically return any non-zero status if jq fails or the catalog is corrupted; treating "anything not 0 or 1" as "unavailable" is the safest fail-soft posture.

The `_MCP_CLI_WARNED` global guard from Plan 01 means that even though we call `is_mcp_installed` 9 times in this loop, the user sees the "claude CLI not found" warning AT MOST ONCE. That guarantees a clean catalog render.

shellcheck `-S warning` must pass.
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/lib/mcp.sh && bash -c '
set -euo pipefail
SANDBOX=$(mktemp -d /tmp/mcp-status.XXXXXX)
trap "rm -rf $SANDBOX" EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"

# CLI-absent path: TK_MCP_CLAUDE_BIN unset, PATH stripped of claude
source scripts/lib/mcp.sh
PATH=/usr/bin:/bin
unset TK_MCP_CLAUDE_BIN
mcp_catalog_load
mcp_status_array 2>/dev/null
[[ "${#TUI_LABELS[@]}" -eq 9 ]] || { echo "FAIL: expected 9 labels, got ${#TUI_LABELS[@]}"; exit 1; }
[[ "${#TUI_INSTALLED[@]}" -eq 9 ]] || { echo "FAIL: expected 9 installed flags"; exit 1; }
[[ "${MCP_CLI_PRESENT}" -eq 0 ]] || { echo "FAIL: expected MCP_CLI_PRESENT=0 with no CLI"; exit 1; }
echo "${TUI_DESCS[0]}" | grep -q "^\[unavailable\] " || { echo "FAIL: expected [unavailable] prefix when CLI absent"; exit 1; }

# CLI-present path: mock claude that lists context7 only
cat > "$SANDBOX/claude" <<MOCK
#!/bin/bash
if [[ "\$1" == "mcp" && "\$2" == "list" ]]; then
    echo "context7    sse    https://mcp.context7.com"
fi
exit 0
MOCK
chmod +x "$SANDBOX/claude"
unset _MCP_CLI_WARNED
TK_MCP_CLAUDE_BIN="$SANDBOX/claude" mcp_status_array
[[ "${MCP_CLI_PRESENT}" -eq 1 ]] || { echo "FAIL: expected MCP_CLI_PRESENT=1 with mock CLI"; exit 1; }
# context7 is alpha-first, so index 0 should be installed
[[ "${TUI_INSTALLED[0]}" -eq 1 ]] || { echo "FAIL: context7 should be installed (idx 0)"; exit 1; }
# firecrawl is alpha-third, should NOT be installed
# Actually the order is context7, firecrawl, magic, notion, openrouter, playwright, resend, sentry, sequential-thinking
[[ "${TUI_INSTALLED[1]}" -eq 0 ]] || { echo "FAIL: firecrawl should NOT be installed (idx 1)"; exit 1; }
echo OK
'</automated>
  </verify>
  <done>scripts/lib/mcp.sh contains mcp_status_array; both CLI-absent and CLI-present test scenarios pass; MCP_CLI_PRESENT global correctly distinguishes the two states; shellcheck warning-clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add --mcps flag and routing branch to scripts/install.sh</name>
  <files>scripts/install.sh</files>
  <read_first>
    - scripts/install.sh (full file — understand existing flag parser, components branch, dispatch loop, summary)
    - scripts/lib/mcp.sh (functions added in Plans 01 + 02 + Task 1 above)
    - scripts/tests/test-install-tui.sh (test scenarios — your changes must not break the 9 existing scenarios S1-S9)
  </read_first>
  <behavior>
    - `bash scripts/install.sh --mcps` triggers the MCP branch (does NOT render components page)
    - `bash scripts/install.sh` (no flag) preserves the Phase 24 components flow byte-identically — S1-S9 of test-install-tui.sh stay green
    - When --mcps is set: install.sh sources lib/mcp.sh, calls mcp_status_array, renders tui_checklist, runs tui_confirm_prompt, then iterates selected MCPs calling mcp_wizard_run
    - When --mcps and CLI is absent: prints "claude CLI not found — install it from https://docs.anthropic.com/... or see docs/MCP-SETUP.md" banner BEFORE the menu, then renders catalog read-only (selecting and confirming results in 9 wizard returns of 2 → all rows marked "skipped: claude unavailable")
    - When --mcps --yes: skips TUI, selects all not-installed MCPs (excluding OAuth-only unless --force), runs wizard for each
    - When --mcps --dry-run: passes --dry-run to each mcp_wizard_run; no claude invocations; summary prints "would-install" rows
    - Per-MCP failure is captured in COMPONENT_STATUS array using existing Phase 24 D-28 stderr-tail pattern (last 5 lines under failure row)
    - Exit code: 0 if no failures (or --dry-run), 1 if any failure (or --fail-fast triggered)
    - test-bootstrap.sh 26 assertions stay green (no changes to init-claude.sh, no changes to bootstrap.sh)
    - test-install-tui.sh 55 assertions stay green (S1-S9 unchanged behavior)
  </behavior>
  <action>
Modify `scripts/install.sh` with these surgical edits:

**Edit 1 — Flag parser (around line 44-75):** Add `--mcps` case BEFORE the `-h|--help` block:

```bash
        --mcps)      MCPS=1;      shift ;;
```

And add `MCPS=0` to the flag defaults block at the top of the file (around line 37-41):

```bash
# Flags (defaults)
YES=0
DRY_RUN=0
FORCE=0
FAIL_FAST=0
MCPS=0
```

Update the `--help` text in the cat<<USAGE block to add a row:
```
  --mcps        Install curated MCP servers via TUI catalog (Phase 25)
```

**Edit 2 — Add mcp.sh sourcing (after `_source_lib dispatch` at line 129):**

```bash
# MCPS=1 path needs the MCP catalog + wizard library.
if [[ "$MCPS" -eq 1 ]]; then
    _source_lib mcp
fi
```

**Edit 3 — Add the MCP routing branch.** At line 137 (after `detect2_cache`) but BEFORE the components TUI array population (line 142), insert a routing gate:

```bash
# ─────────────────────────────────────────────────
# Routing gate: --mcps takes the MCP page; default is the Phase 24 components page.
# Mutex — never both in the same invocation. Future Phase 26 will add --skills as a
# third sibling branch. Keeping each branch self-contained simplifies the test surface.
# ─────────────────────────────────────────────────
if [[ "$MCPS" -eq 1 ]]; then
    # MCP catalog page — populate TUI_* arrays from the 9-MCP catalog.
    mcp_catalog_load || {
        echo -e "${RED}✗${NC} Failed to load MCP catalog" >&2
        exit 1
    }
    mcp_status_array

    # CLI-absent banner per CONTEXT.md "Failure & Degradation" — render but warn.
    if [[ "${MCP_CLI_PRESENT:-0}" -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}!${NC} claude CLI not found — MCPs cannot be installed from here."
        echo "  See docs/MCP-SETUP.md for the install path."
        echo ""
    fi

    # Selection: --yes default-set OR TUI page.
    TUI_RESULTS=()
    if [[ "$YES" -eq 1 ]]; then
        # Default-set: select all not-installed; skip OAuth-only unless --force
        # (OAuth needs interactive browser flow — incompatible with --yes).
        local_count=${#MCP_NAMES[@]}
        for ((i=0; i<local_count; i++)); do
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
                continue
            fi
            if [[ "${MCP_OAUTH[$i]}" -eq 1 && "$FORCE" -ne 1 ]]; then
                TUI_RESULTS[$i]=0
                continue
            fi
            TUI_RESULTS[$i]=1
        done
    else
        # TTY check (mirrors Phase 24 _install_tty_src gate).
        _install_tty_src="${TK_TUI_TTY_SRC:-/dev/tty}"
        if [[ ! -r "$_install_tty_src" ]]; then
            echo "No TTY available for MCP TUI; pass --yes for non-interactive install."
            exit 0
        fi
        if ! tui_checklist; then
            echo "MCP install cancelled."
            exit 0
        fi
        # Count selected.
        local_selected=0
        for ((i=0; i<${#TUI_RESULTS[@]}; i++)); do
            [[ "${TUI_RESULTS[$i]:-0}" -eq 1 ]] && local_selected=$((local_selected + 1))
        done
        if ! tui_confirm_prompt "Install ${local_selected} MCP(s)? [y/N] "; then
            echo "MCP install cancelled."
            exit 0
        fi
    fi

    # ─────────────────────────────────────────────
    # MCP dispatch loop (mirrors Phase 24 D-08 continue-on-error pattern).
    # ─────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}Installing selected MCP(s)...${NC}"
    echo ""
    INSTALLED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0
    COMPONENT_STATUS=()
    COMPONENT_NAMES=()
    COMPONENT_STDERR_TAIL=()
    local_mcp_count=${#MCP_NAMES[@]}
    for ((i=0; i<local_mcp_count; i++)); do
        local_name="${MCP_NAMES[$i]}"
        COMPONENT_NAMES+=("$local_name")
        if [[ "${TUI_RESULTS[$i]:-0}" -ne 1 ]]; then
            if [[ "${TUI_INSTALLED[$i]}" -eq 1 ]]; then
                COMPONENT_STATUS+=("installed ✓")
                INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            else
                COMPONENT_STATUS+=("skipped")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            fi
            COMPONENT_STDERR_TAIL+=("")
            continue
        fi

        # Capture stderr to a per-MCP tmpfile (D-28).
        stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-mcp-${local_name}-XXXXXX") || stderr_tmp=""
        [[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")

        local_flags=()
        [[ "$DRY_RUN" -eq 1 ]] && local_flags+=("--dry-run")

        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" ) 2>"$stderr_tmp" || local_rc=$?
        else
            mcp_wizard_run "$local_name" "${local_flags[@]+"${local_flags[@]}"}" || local_rc=$?
        fi

        case "$local_rc" in
            0)
                if [[ "$DRY_RUN" -eq 1 ]]; then
                    COMPONENT_STATUS+=("would-install")
                else
                    COMPONENT_STATUS+=("installed ✓")
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                fi
                COMPONENT_STDERR_TAIL+=("")
                ;;
            2)
                COMPONENT_STATUS+=("skipped: claude unavailable")
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                COMPONENT_STDERR_TAIL+=("")
                ;;
            *)
                COMPONENT_STATUS+=("failed (exit $local_rc)")
                FAILED_COUNT=$((FAILED_COUNT + 1))
                local_tail=""
                if [[ -n "$stderr_tmp" && -s "$stderr_tmp" ]]; then
                    local_tail=$(tail -5 "$stderr_tmp")
                fi
                COMPONENT_STDERR_TAIL+=("$local_tail")
                if [[ "$FAIL_FAST" -eq 1 ]]; then
                    for ((j=i+1; j<local_mcp_count; j++)); do
                        COMPONENT_NAMES+=("${MCP_NAMES[$j]}")
                        COMPONENT_STATUS+=("skipped")
                        COMPONENT_STDERR_TAIL+=("")
                        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    done
                    break
                fi
                ;;
        esac
    done

    # Reuse the existing print_install_status function from line 277.
    echo ""
    echo -e "${BLUE}MCP install summary:${NC}"
    echo ""
    for ((i=0; i<${#COMPONENT_NAMES[@]}; i++)); do
        local_name="${COMPONENT_NAMES[$i]}"
        local_state="${COMPONENT_STATUS[$i]:-unknown}"
        print_install_status "$local_name" "$local_state"
        case "$local_state" in
            failed*)
                local_tail="${COMPONENT_STDERR_TAIL[$i]:-}"
                if [[ -n "$local_tail" ]]; then
                    while IFS= read -r tail_line; do
                        printf '      %s\n' "$tail_line"
                    done <<< "$local_tail"
                fi
                ;;
        esac
    done
    echo ""
    printf 'Installed: %d · Skipped: %d · Failed: %d\n' \
        "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
    if [[ "${NO_BANNER:-0}" != "1" ]]; then
        echo ""
        echo "To remove an MCP: claude mcp remove <name>"
    fi
    if [[ $FAILED_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi
# ─────────────────────────────────────────────────
# (End of MCP routing branch — components page continues below unchanged.)
# ─────────────────────────────────────────────────
```

**CRITICAL — placement of the MCP branch.** The branch ends with `exit 0` or `exit 1`, so the components page logic below it is naturally unreachable when `--mcps` is set. Make sure the branch lands AFTER `_source_lib mcp` (Edit 2) and AFTER `detect2_cache` (already there) but BEFORE `TUI_LABELS=("superpowers" ...)` so the components arrays are not clobbered.

`print_install_status` is defined later in install.sh (around line 277). Bash defers function-name resolution until call-time, so it's safe to reference before its definition AS LONG AS we're already past the function's `}` when the MCP branch executes. We're NOT — the function is defined AFTER our branch. Solution: also reference it via the existing `dro_*` family OR move the `print_install_status` definition UP. Easiest fix: move the `print_install_status` function definition from line ~277 to above the MCP routing branch (after `_source_lib mcp`). This is a pure refactor — no behavior change for the components flow.

shellcheck must pass `-S warning` on the modified `scripts/install.sh`. The `${local_flags[@]+"${local_flags[@]}"}` nounset-safe expansion is mandatory (Phase 24 commit 5f22652 fixed exactly this issue).
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/install.sh && bash scripts/tests/test-install-tui.sh 2>&1 | tail -3 | grep -q "PASS=" && bash scripts/tests/test-bootstrap.sh 2>&1 | tail -3 | grep -q "PASS=" && bash -c '
set -euo pipefail
SANDBOX=$(mktemp -d /tmp/mcps-flag.XXXXXX)
trap "rm -rf $SANDBOX" EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# Test 1: --mcps --dry-run --yes (no CLI, mocked) prints would-install rows
cat > "$SANDBOX/claude" <<MOCK
#!/bin/bash
exit 0
MOCK
chmod +x "$SANDBOX/claude"

OUT=$(HOME="$SANDBOX" TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_CLAUDE_BIN="$SANDBOX/claude" NO_COLOR=1 bash scripts/install.sh --mcps --yes --dry-run 2>&1)
echo "$OUT" | grep -q "MCP install summary" || { echo "FAIL: missing MCP summary header"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "would-install" || { echo "FAIL: --dry-run should produce would-install rows"; echo "$OUT"; exit 1; }

# Test 2: --mcps without CLI prints unavailable banner
unset TK_MCP_CLAUDE_BIN
OUT=$(HOME="$SANDBOX" TK_MCP_CONFIG_HOME="$SANDBOX" PATH=/usr/bin:/bin NO_COLOR=1 bash scripts/install.sh --mcps --yes 2>&1) || true
echo "$OUT" | grep -qi "claude CLI not found" || { echo "FAIL: missing CLI-absent banner"; echo "$OUT"; exit 1; }

# Test 3: default flow (no --mcps) renders components page (BACKCOMPAT preserved)
OUT=$(HOME="$SANDBOX" PATH=/usr/bin:/bin NO_COLOR=1 bash scripts/install.sh --yes --dry-run 2>&1) || true
echo "$OUT" | grep -q "Install summary" || { echo "FAIL: default flow components summary missing"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "MCP install summary" && { echo "FAIL: default flow should NOT render MCP summary"; echo "$OUT"; exit 1; }

echo OK
'</automated>
  </verify>
  <done>scripts/install.sh learns --mcps flag; CLI-absent path emits banner and exits cleanly; --mcps --dry-run --yes invokes the wizard with --dry-run for selected items; default (no flag) flow byte-identically preserves Phase 24 behavior; test-install-tui.sh + test-bootstrap.sh stay green; shellcheck warning-clean.</done>
</task>

</tasks>

<verification>
- `shellcheck -S warning scripts/install.sh scripts/lib/mcp.sh` → 0 warnings
- `bash scripts/tests/test-install-tui.sh` → PASS=55+ FAIL=0 (Phase 24 invariant)
- `bash scripts/tests/test-bootstrap.sh` → PASS=26+ FAIL=0 (BACKCOMPAT-01 invariant)
- All 3 inline test assertions in Task 2 verify block pass
</verification>

<success_criteria>
1. `scripts/install.sh --mcps` routes to a new MCP page using tui_checklist with the 9-MCP catalog.
2. CLI-absent path renders a banner before the menu and degrades gracefully (no errors).
3. `--mcps --yes` default-set respects OAuth-only skip (unless --force).
4. `--mcps --dry-run` runs the dispatch loop with no claude invocations and no file writes.
5. Per-MCP failures surface stderr tail (last 5 lines) under failure rows — Phase 24 D-28 pattern.
6. Default invocation (no `--mcps`) is byte-identical to Phase 24 components flow — test-install-tui.sh stays green.
7. test-bootstrap.sh 26 assertions stay green — BACKCOMPAT-01 invariant preserved.
</success_criteria>

<output>
After completion, create `.planning/phases/25-mcp-selector/25-03-install-sh-mcps-page-SUMMARY.md` documenting:
- The exact insertion point of the `--mcps` routing branch in install.sh (line numbers before/after)
- Whether `print_install_status` had to be moved up (refactor) or referenced as-is
- Final line count of install.sh (Phase 24 baseline 440 → after Plan 03 ___)
- Any deviation from the plan (e.g., if the OAuth-only skip in --yes mode caused a test issue)
</output>
