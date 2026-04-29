---
phase: 30-install-time-ux
verified: 2026-04-29T21:00:00Z
status: passed
score: 5/5
overrides_applied: 0
---

# Phase 30: Install-time UX — Verification Report

**Phase Goal:** From the very first install, users see bridge options as part of the unified TUI (`scripts/install.sh`) and as inline prompts in `init-claude.sh` / `init-local.sh`. Non-interactive installs honour `--no-bridges` / `TK_NO_BRIDGES=1` to skip and `--bridges gemini,codex` to force-create. CLI-absent rows never appear.

**Verified:** 2026-04-29T21:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | With `gemini` on PATH, `install.sh` shows a `gemini-bridge` TUI row; with `codex` on PATH an analogous row appears; CLI absent → row hidden | VERIFIED | `install.sh:619-638` conditionally appends to `TUI_LABELS`/`TUI_GROUPS`/`TUI_DESCS` gated on `IS_GEM`/`IS_COD`; `--no-bridges` suppresses both; test S1 confirms row appears, S2/S3 confirm absence |
| 2 | After `init-claude.sh` / `init-local.sh` populates `.claude/`, every detected CLI triggers a per-CLI prompt defaulting Y; no-TTY fail-closes to N | VERIFIED | `bridges.sh:558-631` `bridge_install_prompts` iterates targets, calls `is_gemini_installed`/`is_codex_installed`, reads from `TK_BRIDGE_TTY_SRC:-/dev/tty`, fail-closes N on `read` failure; wired at `init-claude.sh:969` and `init-local.sh:500`; test S8 (Y→bridge created), S9 (n→not created) |
| 3 | `--no-bridges` and `TK_NO_BRIDGES=1` skip every bridge prompt on all 3 entry points, creating zero bridges | VERIFIED | `install.sh:57,98-110` parses `--no-bridges`; `init-claude.sh:46,82-92`; `init-local.sh:109,160-168`; `bridges.sh:563-564` checks both env and flag; test S2/S3 (install.sh), S10 (env var), S4 (env var) |
| 4 | `--bridges gemini,codex` forces non-interactive creation; absent CLI under `--fail-fast` exits 1; without `--fail-fast` warns and continues | VERIFIED | `bridges.sh:578-582` (force path), `bridges.sh:610-629` (fail-fast second pass with `return 1`); test S11 (fail-fast→return 1), S12 (no fail-fast→return 0 + warning) |
| 5 | BACKCOMPAT-01 holds: `test-bootstrap.sh` PASS=26 and `test-install-tui.sh` PASS=43 unchanged; 4 baseline suites green throughout | VERIFIED | Live run: `test-bootstrap.sh` PASS=26 FAIL=0; `test-install-tui.sh` PASS=43 FAIL=0; `test-bridges-foundation.sh` PASS=5 FAIL=0; `test-bridges-sync.sh` PASS=25 FAIL=0; `test-bridges-install-ux.sh` PASS=20 FAIL=0 |

**Score:** 5/5 truths verified

---

## REQ-ID Coverage

| REQ-ID | Description | Status | Evidence |
|--------|-------------|--------|----------|
| BRIDGE-UX-01 | `install.sh` gains conditional `gemini-bridge` / `codex-bridge` TUI rows; rows hidden when CLI absent | COVERED | `install.sh:619-638` conditional array append gated on `IS_GEM`/`IS_COD`; dispatch shim at `install.sh:874`; TUI group label `Bridges`; description format `[detected: gemini@<version>]` via `_bridge_cli_version` |
| BRIDGE-UX-02 | `init-claude.sh` + `init-local.sh` post-install per-CLI prompt defaulting Y, fail-closed N on no-TTY | COVERED | `bridge_install_prompts` at `bridges.sh:558-631`; wired at `init-claude.sh:969`, `init-local.sh:500`; `TK_BRIDGE_TTY_SRC` seam; fail-closed `choice="N"` on `read` failure |
| BRIDGE-UX-03 | `--no-bridges` + `TK_NO_BRIDGES=1` skip all bridges on all 3 entry points | COVERED | Flag parsed in all 3 scripts; env-var coalesce in all 3; `bridge_install_prompts` short-circuits on both; mutex with `--bridges` enforced (exit 2) in all 3 |
| BRIDGE-UX-04 | `--bridges <list>` forces creation; `--fail-fast` exit 1 on absent CLI; without `--fail-fast` warns + continues | COVERED | `BRIDGES_FORCE` parsed in all 3 scripts; `_bridge_match` membership test; fail-fast second pass in `bridge_install_prompts`; test S11/S12 confirm |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/lib/bridges.sh` | 4 new helpers: `bridge_install_prompts`, `_bridge_cli_version`, `_bridge_cli_label`, `_bridge_match` | VERIFIED | All 4 found at lines 114, 128, 141, 558 respectively; substantive implementations (not stubs) |
| `scripts/lib/dispatch.sh` | `TK_DISPATCH_ORDER` includes `gemini-bridge codex-bridge` | VERIFIED | Line 56: `TK_DISPATCH_ORDER=(superpowers gsd toolkit security rtk statusline gemini-bridge codex-bridge)` |
| `scripts/install.sh` | Conditional TUI rows, `--no-bridges`/`--bridges` flags, mutex, dispatch shim | VERIFIED | Lines 57-58 (argv), 98-110 (mutex+env), 619-638 (TUI rows), 759-795 (`--bridges` force-select), 874-886 (dispatch shim) |
| `scripts/init-claude.sh` | `--no-bridges`/`--bridges`/`--fail-fast` flags + `bridge_install_prompts` call | VERIFIED | Lines 46-52 (argv), 82-92 (mutex), 87-91 (env coalesce), 969 (bridge_install_prompts call) |
| `scripts/init-local.sh` | Same as init-claude.sh | VERIFIED | Lines 109-115 (argv), 160-168 (mutex+env), 500 (bridge_install_prompts call) |
| `scripts/tests/test-bridges-install-ux.sh` | 20-assertion hermetic test suite (13 scenarios) | VERIFIED | 278 lines; live run confirms PASS=20 FAIL=0 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `install.sh` TUI arrays | `_bridge_cli_version` | `bridges.sh` (sourced via `_source_lib bridges`) | WIRED | `install.sh:142` sources bridges; `install.sh:621,631` calls `_bridge_cli_version` |
| `install.sh` dispatch loop | `bridge_create_global` | Dispatch shim at `install.sh:874-886` | WIRED | Case block strips `-bridge` suffix, calls `bridge_create_global "$_bridge_target"` |
| `init-claude.sh` main() | `bridge_install_prompts` | bridges.sh downloaded to tmpfile at `init-claude.sh:167` | WIRED | `init-claude.sh:969`: `bridge_install_prompts "$PWD"` |
| `init-local.sh` main flow | `bridge_install_prompts` | `$SCRIPT_DIR/lib/bridges.sh` sourced | WIRED | `init-local.sh:500`: `bridge_install_prompts "$PWD"` |
| `bridges.sh` `bridge_install_prompts` | `is_gemini_installed`/`is_codex_installed` | `detect2.sh` (already sourced in all entry points) | WIRED | `bridges.sh:571-574` case block calls these per-target |
| `install.sh` TUI rows conditional | `IS_GEM`/`IS_COD` | `detect2.sh:108` exports both | WIRED | `install.sh:619,629` checks `${IS_GEM:-0}` and `${IS_COD:-0}` |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `test-bridges-install-ux.sh` 20 assertions | `bash scripts/tests/test-bridges-install-ux.sh` | PASS=20 FAIL=0 | PASS |
| `test-bootstrap.sh` BACKCOMPAT | `bash scripts/tests/test-bootstrap.sh` | PASS=26 FAIL=0 | PASS |
| `test-install-tui.sh` BACKCOMPAT | `bash scripts/tests/test-install-tui.sh` | PASS=43 FAIL=0 | PASS |
| `test-bridges-foundation.sh` BACKCOMPAT | `bash scripts/tests/test-bridges-foundation.sh` | PASS=5 FAIL=0 | PASS |
| `test-bridges-sync.sh` BACKCOMPAT | `bash scripts/tests/test-bridges-sync.sh` | PASS=25 FAIL=0 | PASS |
| Mutex error on `--no-bridges --bridges gemini` | `bash scripts/init-claude.sh --no-bridges --bridges gemini 2>&1` | Prints `Error: --no-bridges and --bridges are mutually exclusive` | PASS |
| shellcheck clean | `shellcheck -S warning scripts/lib/bridges.sh scripts/lib/dispatch.sh scripts/install.sh scripts/init-claude.sh scripts/init-local.sh scripts/tests/test-bridges-install-ux.sh` | No warnings | PASS |
| No `set -euo pipefail` in sourced libs | `grep -c "set -euo pipefail" bridges.sh dispatch.sh` | 0, 0 | PASS |
| No Bash 4+ patterns in code | grep for `declare -A`, `declare -n`, `read -N`, `mapfile` | Comment-only reference to `mapfile` in bridges.sh:140 (not code) — CLEAN | PASS |

---

## Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| None | — | — | No TODO/FIXME/PLACEHOLDER/stub patterns found in any of the 6 audited files |

---

## Human Verification Required

None. All success criteria are verifiable through automated tests and static code inspection. The `test-bridges-install-ux.sh` suite covers TTY-interactive paths via the `TK_BRIDGE_TTY_SRC` test seam.

---

## Gaps Summary

No gaps. All 5 ROADMAP success criteria and all 4 BRIDGE-UX REQ-IDs are covered.

---

_Verified: 2026-04-29T21:00:00Z_
_Verifier: Claude (gsd-verifier)_

---

## VERIFICATION PASSED
