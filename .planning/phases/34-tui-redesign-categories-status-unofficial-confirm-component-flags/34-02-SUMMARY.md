---
phase: 34
plan: 02
plan_id: 34-02
title: Unofficial confirm gate + --mcp-only / --cli-only mutex flags
subsystem: scripts/lib + scripts/install.sh
tags: [tui, integrations, flags, mutex, unofficial, cli-installer]
req_ids: [TUI-03, TUI-04]
dependency_graph:
  requires:
    - "Plan 34-01 — MCP_UNOFFICIAL[] / MCP_HAS_CLI[] / MCP_CLI_DETECT[] / MCP_STATUS[] / CLI_STATUS[] populated"
    - "Phase 32 — cli-installer.sh primitives (cli_install / cli_detect / cli_post_install_hint)"
    - "v4.3 Phase 18 UN-03 — < /dev/tty + fail-closed N prompt contract"
    - "v4.8 Phase 30 — --bridges/--no-bridges mutex precedent"
  provides:
    - "unofficial_confirm() function in scripts/lib/mcp.sh"
    - "--mcp-only and --cli-only flags with mutex enforcement"
    - "RESULT_NAMES[] / RESULT_MCP_STATE[] / RESULT_CLI_STATE[] per-entry × per-component result tracking"
    - "TK_INTEGRATIONS_TTY_SRC test seam (mirrors Phase 28 TK_BRIDGE_TTY_SRC)"
  affects:
    - "scripts/install.sh argument parser + dispatch loop"
    - "scripts/lib/mcp.sh — adds unofficial_confirm public function"
tech_stack:
  added:
    - "cli-installer.sh sourced unconditionally when MCPS=1 (sub-ms cost on uncalled path)"
  patterns:
    - "Mutex flag check after argv parse, exit 2 with stderr error (BOOTSTRAP-04 precedent)"
    - "TTY seam for prompts (TK_INTEGRATIONS_TTY_SRC) — fail-closed N on no readable TTY"
    - "Browse-mode preservation: when claude is absent (MCP rc=2), CLI install also skips by default"
key_files:
  created: []
  modified:
    - scripts/install.sh
    - scripts/lib/mcp.sh
decisions:
  - "Mutex check at the top-level argv block (alongside --no-bridges/--bridges check) — fail fast with exit 2 before any work."
  - "ALWAYS_YES env-var as the bypass signal (decoupled from install.sh's $YES so the function is unit-testable in isolation)."
  - "Read fixture via plain `read -r reply <\"$tty_src\"` — matches existing UN-03 contract; no need for `tui_tty_read` here since unofficial_confirm prints its own prompt to stderr (always visible under capture wrappers)."
  - "Pre-flight gate ordering: unofficial_confirm runs BEFORE --cli-only branch — declined unofficial entries are skipped even if --cli-only would have side-stepped the MCP step. User intent is consistent: 'I don't want this one at all.'"
  - "Browse-mode preservation (Rule 1 fix): when MCP install reports rc=2 (claude absent), CLI install ALSO skips with the same reason. Without this guard, --yes browse-mode runs would surprise the user with eager brew/npm activity. --cli-only still overrides to force CLI install regardless."
  - "RESULT_* arrays added now (Plan 34-02) so the dispatch loop produces structured output Plan 34-03 can render. Legacy COMPONENT_STATUS[] kept intact so existing 'MCP install summary' block + test-mcp-selector S7/S8/S13 keep passing."
metrics:
  completed_date: 2026-05-02
  scripts_install_sh_lines_delta: "+~210"
  scripts_lib_mcp_sh_lines_delta: "+~53"
  baselines_preserved:
    test-mcp-selector: 21/21 PASS
    test-integrations-foundation: 32/32 PASS
    make_check: rc=0
  manual_smoke_tests:
    mutex_flag_exit_code: 2
    unofficial_confirm_N: rc=1 (skip)
    unofficial_confirm_y: rc=0 (allow)
    unofficial_confirm_always_yes: rc=0 (bypass)
    unofficial_confirm_no_tty: rc=1 (fail-closed)
    mcp_only_dry_run_skips_cli: PASS
    cli_only_dry_run_skips_mcp: PASS
---

# Phase 34 Plan 02: Unofficial confirm gate + Component-only flags

## One-liner

Adds `--mcp-only` / `--cli-only` mutex flags to `install.sh` and a `unofficial_confirm` `[y/N]` prompt that gates installs of community-maintained / browser-automation entries (notebooklm, telegram), reading from the `TK_INTEGRATIONS_TTY_SRC` test seam with fail-closed N — wires both into the MCP dispatch loop alongside per-entry × per-component `RESULT_*` tracking arrays Plan 34-03 will render.

## What Changed

### `scripts/install.sh`

**Argument parsing (lines 59-66):** Added `MCP_ONLY=0` / `CLI_ONLY=0` defaults next to the existing component flags. Added `--mcp-only` and `--cli-only` `case` branches in the parse loop. Added two help-text rows documenting the mutex.

**Mutex enforcement (after the existing --no-bridges/--bridges check):**

```bash
if [[ "$MCP_ONLY" -eq 1 && "$CLI_ONLY" -eq 1 ]]; then
    echo -e "${RED}Error:${NC} --mcp-only and --cli-only are mutually exclusive" >&2
    exit 2
fi
```

Mirrors the v4.8 Phase 30 BRIDGE-UX-03 precedent (exit 2 on user-error).

**Library sourcing (line ~225):** When `MCPS=1`, `cli-installer.sh` is now sourced alongside `mcp.sh` so `cli_install`, `cli_detect`, `cli_post_install_hint` are available in the dispatch loop.

**MCP dispatch loop (lines ~439-650):** Rewritten to:

1. Initialize parallel `RESULT_NAMES[]` / `RESULT_MCP_STATE[]` / `RESULT_CLI_STATE[]` arrays.
2. Export `ALWAYS_YES=1` when `--yes` is set (so `unofficial_confirm` honors the bypass).
3. Per entry, before any install action:
   - If unselected → record `skipped:unselected` for both halves.
   - If unofficial → call `unofficial_confirm "${MCP_DISPLAY[$i]}"`; on rc=1 record `skipped:unofficial-declined` + skip both halves.
4. MCP install branch: if `--cli-only` set → record `skipped:cli-only`. Otherwise run `mcp_wizard_run` and map exit codes to `installed` / `would-install` / `installed:needs-key` / `skipped:claude-unavailable` / `failed:exit-N: <reason>`.
5. CLI install branch (new):
   - No CLI block → `na`
   - `--mcp-only` set → `skipped:mcp-only`
   - MCP just reported `skipped:claude-unavailable` AND `--cli-only` not set → `skipped:claude-unavailable` (browse-mode preservation, Rule 1 fix)
   - Already installed AND no `--force` → `already`
   - `--dry-run` → `would-install`
   - Otherwise: read `install.darwin` / `install.linux` / `post_install_hint` from catalog via jq, run `cli_install`, map rc to `installed` / `skipped:unsupported-platform` / `skipped:brew-absent` / `failed:exit-N: <reason>`. Print post-install hint on success.
6. Fail-fast handling pads remaining slots in all three RESULT_* arrays so they stay aligned with COMPONENT_* arrays.

The legacy `COMPONENT_STATUS[]` / `COMPONENT_NAMES[]` / `COMPONENT_STDERR_TAIL[]` arrays still drive the existing per-row `MCP install summary:` block (line ~536-560) — keeps test-mcp-selector S7/S8/S13 contracts intact.

### `scripts/lib/mcp.sh`

**Added `unofficial_confirm()` public function (~50 lines):**

```bash
unofficial_confirm <display_name>
  - reads from ${TK_INTEGRATIONS_TTY_SRC:-/dev/tty}
  - rc=0 on y/Y/yes (or ALWAYS_YES=1 bypass)
  - rc=1 on n/empty/EOF/no-readable-TTY (fail-closed)
  - prints prompt to stderr so install.sh's `( wizard ) 2>"$tmp"` capture wrappers
    don't swallow it silently
  - yellow `!` glyph under color, plain `[!]` under NO_COLOR (mirror of TUI-03 badge)
```

Documented `TK_INTEGRATIONS_TTY_SRC` test seam in the file header alongside the existing `TK_MCP_TTY_SRC` (Phase 25) seam — keeps the test-seam taxonomy consistent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Eager CLI install in browse-mode `--yes` runs**

- **Found during:** Task 5 self-test (test-mcp-selector S8 regressed from PASS to FAIL: exit 1 instead of 0)
- **Issue:** When `claude` CLI is absent, MCP-side correctly returned rc=2 ("skipped: claude unavailable"), but the new CLI install branch still ran `cli_install` for entries with `components.cli` blocks. With brew present locally, `aws-cloudwatch-logs` would attempt a real `brew install awscli` — surprise behaviour that broke the existing browse-only contract.
- **Fix:** Added a pre-check that reads the just-set `RESULT_MCP_STATE[]` slot. When the MCP step reported `skipped:claude-unavailable` AND the user did NOT pass `--cli-only`, the CLI step also skips with the same reason. `--cli-only` still forces CLI install regardless (explicit user opt-in).
- **Files modified:** scripts/install.sh
- **Caught by:** test-mcp-selector S8 baseline regression (caught before commit)

**2. [Rule 1 - Bug] Dead variable `local_mcp_state`**

- **Found during:** Task 5 shellcheck pass
- **Issue:** Initial draft tracked `local_mcp_state="skipped"` but nothing read it (`RESULT_MCP_STATE[]` slot is what the CLI branch reads).
- **Fix:** Removed the unused assignment.
- **Files modified:** scripts/install.sh

### Rule 2 - Auto-added (browse-mode preservation)

The Rule 1 fix above doubles as a Rule 2 mitigation: the plan didn't explicitly say "preserve browse-only mode when claude is absent", but doing so is a correctness requirement (avoids surprising the user with brew activity in an environment where they cannot install MCPs anyway). Documented under Decisions above.

## Threat Flags

None. No new network endpoints, auth surfaces, or schema mutations introduced. The new `cli_install` invocation runs catalog-curated commands through `eval` — same trust boundary already audited in Phase 32 Plan 32-02 (commit boundary: schema validator at `scripts/validate-integrations-catalog.py`). The new TTY-read prompt uses `read -r reply <"$tty_src"` with no shell-metachar interpretation of `$reply` (only checked against literal y/Y/yes/YES/Yes patterns).

## Self-Check: PASSED

- scripts/install.sh: present, +210 lines (flag block + mutex check + dispatch-loop rewrite + lib source line)
- scripts/lib/mcp.sh: present, +53 lines (unofficial_confirm + header docstring update)
- test-mcp-selector.sh: PASS=21 FAIL=0 (preserved after Rule 1 fix)
- test-integrations-foundation.sh: PASS=32 FAIL=0 (preserved)
- shellcheck scripts/install.sh scripts/lib/mcp.sh: clean (no warnings; dead-code removed)
- make check: rc=0 (lint + validate + parity all green)
- Manual smoke: mutex flag rejects with exit 2; unofficial_confirm 4-state matrix (N=skip, y=allow, ALWAYS_YES=bypass, no-TTY=skip) verified.
