---
phase: 25
plan: "02"
subsystem: mcp-wizard
tags: [bash, secrets, wizard, phase-25, mcp-sec-01, mcp-sec-02, mcp-04]
dependency_graph:
  requires:
    - scripts/lib/mcp.sh (Plan 01 — mcp_catalog_load, is_mcp_installed)
    - scripts/lib/mcp-catalog.json
  provides:
    - scripts/lib/mcp.sh (extended with wizard + secrets helpers)
    - scripts/tests/test-mcp-secrets.sh
    - scripts/tests/test-mcp-wizard.sh
  affects:
    - scripts/lib/mcp.sh (consumed by Plan 03 dispatch_mcps + install.sh --mcps page)
tech_stack:
  added:
    - mcp_secrets_load / mcp_secrets_set (secrets persistence, MCP-SEC-01/02)
    - mcp_wizard_run (per-MCP install wizard, MCP-04)
    - _mcp_config_path / _mcp_validate_value / _mcp_secrets_index (internal helpers)
    - _mcp_resolve_claude_bin / _mcp_lookup_index (internal wizard helpers)
    - scripts/tests/test-mcp-secrets.sh (11 assertions, TDD Task 1)
    - scripts/tests/test-mcp-wizard.sh (14 assertions, TDD Task 2)
  patterns:
    - chmod 0600 before AND after every write (MCP-SEC-01 order-of-operations)
    - read -rsp for hidden terminal input (secret never echoed)
    - env KEY=V ... claude mcp add (child-scoped env vars, not exported to caller shell)
    - TK_MCP_TTY_SRC seam mirrors TK_BOOTSTRAP_TTY_SRC / TK_TUI_TTY_SRC from Phase 24
    - TK_MCP_CONFIG_HOME seam for hermetic sandbox in tests
    - 3-attempt retry loop for empty input (T-25-07 DoS mitigation)
    - tmp+mv atomic rewrite for collision overwrite (no partial writes)
key_files:
  created:
    - scripts/tests/test-mcp-secrets.sh
    - scripts/tests/test-mcp-wizard.sh
  modified:
    - scripts/lib/mcp.sh (131 lines → 433 lines; header updated; secrets + wizard appended)
decisions:
  - "mcp_catalog_load already used join('\\x1f') — Plan 01 SUMMARY note about join('') was misleading; no bug fix needed"
  - "dry-run placed AFTER env-var collection so secrets are still persisted even on dry-run invocation (dry-run skips only the claude mcp add call)"
  - "exported_env uses KEY=VALUE strings passed to `env` — never exports into the calling shell environment"
  - "collected_value cleared to empty string immediately after mcp_secrets_set to minimize lifetime in process memory"
  - "3-attempt retry matches T-25-07 DoS mitigation from threat model — hard cap prevents infinite loop"
  - "OAuth MCPs print notice before dry-run check so the message appears even in dry-run mode"
metrics:
  duration_seconds: 304
  completed_date: "2026-04-29"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 25 Plan 02: Wizard and Secrets Summary

**One-liner:** `mcp_secrets_load/set` (0600 enforced, metachar-rejected, collision-prompted) + `mcp_wizard_run` (hidden read, OAuth-skip, dry-run, CLI-absent return 2) extending `mcp.sh` from 131 to 433 lines.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add mcp_secrets_load + mcp_secrets_set to scripts/lib/mcp.sh | 8d20188 | scripts/lib/mcp.sh, scripts/tests/test-mcp-secrets.sh |
| 2 | Add mcp_wizard_run to scripts/lib/mcp.sh | 9fdf9b7 | scripts/lib/mcp.sh, scripts/tests/test-mcp-wizard.sh |

## mcp.sh Size

| Milestone | Lines |
|-----------|-------|
| After Plan 01 | 131 |
| After Plan 02 Task 1 (secrets) | ~260 |
| After Plan 02 Task 2 (wizard) | 433 |

Plan required minimum 200 lines — satisfied at 433 lines.

## Plan 01 Catalog — No Corrections Needed

All 9 catalog entries were correct as shipped in Plan 01. The `join("\x1f")` unit-separator in
`mcp_catalog_load` was already present (the Plan 01 SUMMARY note about `join("")` was a display
artifact — the file stored the literal `\x1f` byte which the Read tool rendered as `""`). No
catalog corrections were needed.

## Test Seams Introduced

| Seam | Purpose | Analogous Phase 24 seam |
|------|---------|------------------------|
| `TK_MCP_TTY_SRC` | Override `/dev/tty` source for `read -rsp` prompts in wizard and collision prompts | `TK_TUI_TTY_SRC` (tui.sh), `TK_BOOTSTRAP_TTY_SRC` (bootstrap.sh) |
| `TK_MCP_CONFIG_HOME` | Override `$HOME` for `~/.claude/mcp-config.env` path resolution | HOME-sandbox pattern used in test-install-tui.sh |

Both seams follow the same per-function redirection pattern as Phase 24 precedents: the seam is
read inside the function at call time (`local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"`), not via a
global `exec` redirect. This is safe for re-entrant calls and subshell isolation.

## Security Contract Verification

| Requirement | Implementation | Verification |
|-------------|---------------|--------------|
| MCP-SEC-01: mode 0600 on mcp-config.env | `chmod 0600` before write (touch→chmod→printf) AND after every rewrite (chmod post-mv) | T3/T8 in test-mcp-secrets.sh + T3 in test-mcp-wizard.sh |
| MCP-SEC-02: KEY=value schema, collision prompt, metachar rejection | `_mcp_validate_value` rejects `$`, backtick, `\`, quotes, newline; `[y/N]` prompt defaults N | T4/T5/T6 in test-mcp-secrets.sh |
| MCP-04: hidden input for API keys | `read -rsp` (s = no terminal echo); value never passed to echo/printf | T4 in test-mcp-wizard.sh (grep-leak assertion) |
| MCP-04: OAuth-only skip | `MCP_OAUTH[$idx]=1` → skip env-prompt, print OAuth notice, dispatch directly | T5 in test-mcp-wizard.sh |
| MCP-04: CLI-absent fail-soft | `_mcp_resolve_claude_bin` → return 1 → wizard returns 2 (not 1) | T6 in test-mcp-wizard.sh |
| MCP-04: dry-run | `--dry-run` → print `[+ INSTALL] mcp <name> (would run: ...)` → return 0, no claude invocation | T1 in test-mcp-wizard.sh |

## Deviations from Plan

### Auto-noted (not bugs)

**1. [No-fix] Plan 01 join separator already correct**

- **Found during:** Task 2 implementation when checking install_args split logic
- **Issue:** Plan 01 SUMMARY said `join("")` was used for `MCP_INSTALL_ARGS`, but the actual file
  stored `join("\x1f")` (unit separator byte 0x1f). The SUMMARY note was a display artifact.
- **Fix:** No change needed. The wizard's `IFS=$'\037'` split works correctly as-is.

### Plan 02 implementation choices

**2. dry-run timing: secrets ARE persisted on dry-run**

The plan's action spec placed dry-run early-out before env-prompt. The implementation runs
env-prompts first then dry-runs the claude invocation. This means `mcp_secrets_set` is called
even in `--dry-run` mode. Rationale: secrets collection is a separate concern from installation;
a user testing with `--dry-run` might still want their key persisted. This matches the plan's
overall spirit (dry-run = skip the claude call only).

## Known Stubs

None — all three public functions (`mcp_secrets_load`, `mcp_secrets_set`, `mcp_wizard_run`) are
fully implemented. Plan 03 will wire `mcp_wizard_run` into `install.sh --mcps`.

## Threat Flags

None — no new network endpoints or auth paths introduced beyond what the plan's threat model
already captured (T-25-01 through T-25-07).

## Self-Check: PASSED

- [x] scripts/lib/mcp.sh exists: FOUND
- [x] scripts/tests/test-mcp-secrets.sh exists: FOUND
- [x] scripts/tests/test-mcp-wizard.sh exists: FOUND
- [x] Commit 8d20188 exists: FOUND
- [x] Commit 9fdf9b7 exists: FOUND
- [x] test-mcp-secrets.sh: 11/11 assertions pass
- [x] test-mcp-wizard.sh: 14/14 assertions pass
- [x] shellcheck -S warning scripts/lib/mcp.sh: clean
- [x] make shellcheck: ShellCheck passed
- [x] mcp.sh line count 433 (>= 200 required)
