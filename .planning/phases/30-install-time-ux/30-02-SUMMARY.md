---
phase: 30-install-time-ux
plan: "02"
subsystem: install-ux
tags: [bridges, install, tui, dispatch, flags, ux]
dependency_graph:
  requires: [30-01]
  provides: [bridge-tui-rows, bridge-dispatch-shim, no-bridges-flag, bridges-flag]
  affects: [scripts/install.sh]
tech_stack:
  added: []
  patterns: [array-length-driven-loops, dispatch-shim, flag-mutex-check, path-sandbox-smoke]
key_files:
  modified:
    - scripts/install.sh
decisions:
  - "Bridge dispatch shim inlined in install.sh (not a separate bridges-dispatch.sh) — fewer files, consistent with v4.7 scope"
  - "TUI_INSTALLED+=(0) for bridge rows — bridges always re-write on dispatch (idempotent), no filesystem-existence probe"
  - "Force-select block placed after the if/elif/else gate so it applies to both --yes and TUI paths uniformly"
  - "fail-fast CLIs-absent check uses separate second pass so partial bridge set is created before exit-1"
metrics:
  duration_minutes: 30
  completed_date: "2026-04-29"
  tasks_completed: 4
  tasks_total: 4
  files_modified: 1
  assertions_passed: 99
  assertions_failed: 0
---

# Phase 30 Plan 02: Bridge TUI Rows + Dispatch + Flag Plumbing Summary

Wired Phase 28/30-01 bridge primitives into `scripts/install.sh`: 2 conditional TUI rows (gemini-bridge / codex-bridge), array-length-driven dispatch loop, `--no-bridges` / `--bridges <list>` flags with mutex exit 2, and `bridge_create_global` dispatch shim. All 99 BACKCOMPAT-01 assertions remain green.

## Edit Touch-points (post-modification line numbers approximate)

| Edit | Location | Change |
|---|---|---|
| 1 | Flags block (~line 44) | `NO_BRIDGES=false` + `BRIDGES_FORCE=""` defaults |
| 2 | argv case-block (~line 54) | `--no-bridges` + `--bridges <list>` cases |
| 3 | --help heredoc (~line 70) | `--no-bridges` + `--bridges LIST` rows |
| 4 | Post-argv-loop (~line 87) | Mutex check (exit 2) + TK_NO_BRIDGES env coalesce + second mutex re-check |
| 5 | lib-source block (~line 142) | `_source_lib bridges` after `_source_lib dispatch` |
| 6 | TUI arrays block (~line 613) | Conditional `TUI_LABELS+= / TUI_GROUPS+= / TUI_INSTALLED+= / TUI_DESCS+=` for gemini-bridge + codex-bridge |
| 7 | --yes default-set loop (~line 663) | `for i in 0 1 2 3 4 5` → `_tui_count=${#TUI_LABELS[@]}; for ((i=0;i<_tui_count;i++))` |
| 8 | TUI selected-counter loop (~line 683) | Same generalization |
| 9 | No-TTY fallback loop (~line 751) | Same generalization |
| 10 | Post-selection block (~line 756) | `--bridges` force-select + fail-fast absent-CLI check |
| 11 | Dispatch loop header (~line 818) | `_disp_count=${#TUI_LABELS[@]}; for ((i=0;i<_disp_count;i++))` |
| 12 | Re-probe case-block (~line 840) | `gemini-bridge) : ;;` + `codex-bridge) : ;;` no-op branches |
| 13 | Dispatch invocation (~line 868) | Bridge dispatch shim (case-block with `bridge_create_global`) wrapping original `dispatch_${local_name}` fallthrough |
| 14 | Fail-fast remainder loop (~line 904) | `j<=5` → `j<_ff_count` (array-length-driven) |
| 15 | Post-install summary loop (~line 921) | `for i in 0 1 2 3 4 5` → `_sum_count=${#TUI_LABELS[@]}; for ((i=0;i<_sum_count;i++))` |

## Verbatim Dispatch Shim (gemini-bridge / codex-bridge branch)

```bash
# BRIDGE-UX-01 dispatch shim: bridge labels do not have a dispatch_<name> function;
# we call bridge_create_global directly. Other components flow through dispatch_*.
case "$local_name" in
    gemini-bridge|codex-bridge)
        _bridge_target="${local_name%-bridge}"
        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( bridge_create_global "$_bridge_target" ) 2>"$stderr_tmp" || local_rc=$?
        else
            bridge_create_global "$_bridge_target" || local_rc=$?
        fi
        unset _bridge_target
        ;;
    *)
        local_rc=0
        if [[ -n "$stderr_tmp" ]]; then
            ( "dispatch_${local_name}" "${local_flags[@]}" ) 2>"$stderr_tmp" || local_rc=$?
        else
            "dispatch_${local_name}" "${local_flags[@]}" || local_rc=$?
        fi
        ;;
esac
```

## Sandbox Smoke Test

Commands and expected outputs:

```bash
# Sandbox setup
sandbox=$(mktemp -d /tmp/30-02-smoke-XXXXXX)
mkdir -p "$sandbox/bin"
printf '#!/bin/bash\n[[ "$1" == "--version" ]] && echo "gemini 1.2.3-test" && exit 0\nexit 0\n' > "$sandbox/bin/gemini"
printf '#!/bin/bash\n[[ "$1" == "--version" ]] && echo "codex 0.5-test" && exit 0\nexit 0\n' > "$sandbox/bin/codex"
chmod +x "$sandbox/bin/gemini" "$sandbox/bin/codex"

# Test 1: --no-bridges suppresses bridge rows
out=$(PATH="$sandbox/bin:$PATH" bash scripts/install.sh --yes --dry-run --no-bridges 2>&1 || true)
echo "$out" | grep -q "gemini-bridge"  # must NOT match
# => no match (OK: --no-bridges suppresses gemini-bridge in summary)

# Test 2: without --no-bridges, bridge rows appear
out=$(PATH="$sandbox/bin:$PATH" bash scripts/install.sh --yes --dry-run 2>&1 || true)
echo "$out" | grep -q "gemini-bridge"  # must match
echo "$out" | grep -q "codex-bridge"   # must match
# => OK: gemini-bridge row appears with detected CLI
# => OK: codex-bridge row appears with detected CLI
```

Actual output confirmed both assertions pass.

## BACKCOMPAT-01 Evidence

All four hermetic test suites re-run after all 3 tasks with zero regressions:

| Suite | Expected | Actual | Result |
|---|---|---|---|
| `test-bootstrap.sh` | PASS=26 FAIL=0 | PASS=26 FAIL=0 | PASS |
| `test-install-tui.sh` | PASS=43 FAIL=0 | PASS=43 FAIL=0 | PASS |
| `test-bridges-foundation.sh` | PASS=5 FAIL=0 | PASS=5 FAIL=0 | PASS |
| `test-bridges-sync.sh` | PASS=25 FAIL=0 | PASS=25 FAIL=0 | PASS |

**Combined: 99 PASS, 0 FAIL.**

## File Ownership Statement

This plan owns **only** `scripts/install.sh`. Zero overlap with Plan 30-03:

- `scripts/init-claude.sh` — untouched (Plan 30-03 owns argv parsing + bridge_install_prompts call)
- `scripts/init-local.sh` — untouched (Plan 30-03 owns argv parsing + bridge_install_prompts call)
- `scripts/tests/test-bridges-install-ux.sh` — untouched (Plan 30-03 owns the new test)
- `scripts/lib/bridges.sh` — untouched (already shipped in Plan 30-01)
- `scripts/lib/dispatch.sh` — untouched (already shipped in Plan 30-01)

## Commits

| Hash | Message |
|---|---|
| `b18e1de` | feat(30-02): source bridges.sh + --no-bridges/--bridges flag plumbing |
| `8b87a99` | feat(30-02): conditional gemini-bridge / codex-bridge TUI rows (BRIDGE-UX-01) |
| `cb77823` | feat(30-02): generalize TUI/dispatch loops + bridge dispatch shim (BRIDGE-UX-01/04) |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `scripts/install.sh` exists and contains all required patterns: FOUND
- `grep -c "for i in 0 1 2 3 4 5" scripts/install.sh` returns 0: CONFIRMED
- `grep -c "j<=5" scripts/install.sh` returns 0: CONFIRMED
- `grep -q "bridge_create_global" scripts/install.sh`: FOUND
- `grep -q "_bridge_match gemini" scripts/install.sh`: FOUND
- `grep -q "mutually exclusive" scripts/install.sh`: FOUND
- `grep -q "_source_lib bridges" scripts/install.sh`: FOUND
- Commits b18e1de, 8b87a99, cb77823: FOUND
- shellcheck -S warning scripts/install.sh: CLEAN
- All 99 BACKCOMPAT-01 assertions green: CONFIRMED
- Sandbox smoke: --no-bridges suppresses rows, --yes with detected CLIs shows rows: CONFIRMED
