---
phase: 32-foundation-schema-migration-cli-installer-library
plan: 02
subsystem: infra
tags: [bash, cli-installer, uname-dispatch, library, posix, integrations-catalog]

requires:
  - phase: 25-mcp-selector
    provides: continue-on-error dispatch loop pattern (D-08), per-component stderr capture pattern (D-28), `mcp_*`/`_mcp_*` public/private function naming convention (mirrored as `cli_*`/`_cli_*`)
  - phase: 28-bridge-foundation
    provides: 3-plan foundation shape (probes + library + smoke test) — Phase 32 mirrors this layout
provides:
  - scripts/lib/cli-installer.sh — single-CLI primitive library (cli_detect / cli_install / cli_post_install_hint) with uname -s dispatch, brew-absent fallback, no auto-elevation, stderr-only post-install hints
  - TK_CLI_UNAME and TK_CLI_BREW_BIN test seams (test-only env-var contract for Plan 32-03 hermetic smoke)
  - cli-installer.sh registered in manifest.json files.libs[] (auto-discovered by update-claude.sh)
affects:
  - 32-03 (smoke test consumes cli-installer.sh + the two test seams)
  - 33-catalog-population (continue-on-error multi-CLI dispatch loop in install.sh consumes cli_install)
  - 34-tui-redesign (TUI page invokes cli_detect for per-component status detection)
  - 35-distribution-tests-docs (DOCS-02 hardens "no auto-elevation" boundary; manifest version bump)

tech-stack:
  added: []  # Pure POSIX bash — no new runtime dependency
  patterns:
    - "Test seams via TK_<MODULE>_<RESOURCE> env vars (TK_CLI_UNAME / TK_CLI_BREW_BIN), mirroring TK_MCP_CLAUDE_BIN / TK_MCP_CATALOG_PATH from mcp.sh:24-27"
    - "uname -s case dispatch with positive Darwin/Linux branches and explicit `*) return 2` reject (vs install-statusline.sh's negative-rejection model)"
    - "Eval inside trust boundary documented inline above each eval — catalog strings are schema-validated, never user input"
    - "Stderr-only emission for diagnostic/hint output (D-21) keeps stdout parseable for future --format json"
    - "Dual-state seam contract: TK_CLI_BREW_BIN unset = use real `command -v brew`; set+empty = simulate absent; set+non-empty = simulate present (uses `${VAR+x}` parameter expansion to disambiguate unset-vs-empty)"

key-files:
  created:
    - scripts/lib/cli-installer.sh
    - .planning/phases/32-foundation-schema-migration-cli-installer-library/32-02-SUMMARY.md
  modified:
    - manifest.json (added scripts/lib/cli-installer.sh to files.libs[] — Rule 3 deviation)

key-decisions:
  - "ASCII '->' over Unicode '→' in cli_post_install_hint output for grep-portability — cites lessons-learned 260430-go5 (invisible bytes broke MCP wizard regression test). Explicit comment in code documents the choice."
  - "TK_CLI_BREW_BIN seam uses `${VAR+x}` parameter expansion to disambiguate unset (real `command -v brew`) from set-and-empty (simulate brew-absent). Equivalent semantics to ${VAR:+...} would conflate empty-string-set with unset, breaking the test-only seam contract."
  - "Library does NOT implement the multi-CLI continue-on-error dispatch loop. The `tk-cli.XXXXXX` mktemp + INSTALLED/SKIPPED/FAILED accumulation is install.sh's job (Phase 33). Plan 32-02 ships the single-CLI primitive only — keeps the library leaf-shaped and easier to unit-test."
  - "Eval is the only choice: catalog strings are full shell command lines (e.g. 'brew install supabase/tap/supabase', 'curl -fsSL ... | tar'). Splitting into argv arrays is impossible without a shell parser. Trust boundary documented inline."
  - "Manifest registration is part of this plan (Rule 3 deviation) — Phase 32 explicitly defers version bump to Phase 35 DIST-01, but `validate-manifest.py` Audit M1 drift check rightly blocks `make check` until the file is registered. Registering the path (without bumping version) is the minimal correct fix and preserves Phase 35's DIST-01 scope."

patterns-established:
  - "Sourced library invariant — no `set -e/-u/-o pipefail` at top of file (mcp.sh:29 invariant). Verified by grep gate in Plan 32-03."
  - "Color-guard idiom `[[ -z \"${RED:-}\" ]] && RED=...` with `# shellcheck disable=SC2034` annotations — copied verbatim from mcp.sh:32-41 to keep callers (e.g., install.sh) able to override color palettes without library re-init."
  - "Three-rc convention for cli_install — 0=success (or installer rc), 1=usage, 2=unsupported platform, 3=brew-absent (Darwin only); other rc values come from underlying eval and propagate verbatim."

requirements-completed: [CLI-01, CLI-02, CLI-03, CLI-04]

duration: 4m
completed: 2026-05-02
---

# Phase 32 Plan 02: cli-installer.sh — Cross-Platform CLI Installer Library Summary

**Single-CLI primitive library exposing `cli_detect` / `cli_install` / `cli_post_install_hint` with uname-dispatched install, brew-absent fallback, no auto-elevation, and stderr-only hints — ready for Phase 33 multi-CLI dispatch in install.sh.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-01T23:44:39Z
- **Completed:** 2026-05-01T23:48:44Z
- **Tasks:** 2 of 2 (100%)
- **Files modified:** 2 (1 created + 1 manifest registration)

## Accomplishments

- Shipped `scripts/lib/cli-installer.sh` (157 lines, executable, sourceable, Bash 3.2 compatible) with three documented public primitives covering all four REQ-IDs (CLI-01..04).
- Implemented two test seams (`TK_CLI_UNAME`, `TK_CLI_BREW_BIN`) using `${VAR+x}` parameter expansion to disambiguate unset-vs-empty — enables Plan 32-03 hermetic test scenarios for both Darwin-only / Linux-only / unsupported / brew-absent / brew-present paths.
- Registered the new library in `manifest.json` `files.libs[]` so `update-claude.sh` auto-propagates it to existing installations (Rule 3 deviation — see below).
- Verified all 13 plan-level integration checks pass: `bash -n`, `shellcheck -S warning`, source-under-`set -e`, both happy-path dispatches, FreeBSD reject (rc=2), brew-absent reject (rc=3), brew-present run-through, hint-stderr-only, no-sudo-in-code grep gate, no-errexit grep gate, full `make check` green.

## Task Commits

Each task was committed atomically:

1. **Task 1: scaffold cli-installer.sh with header + cli_detect** — `0d5f4af` (feat)
2. **Task 2: cli_install + cli_post_install_hint with uname dispatch + brew fallback** — `b41336a` (feat) — also includes Rule 3 deviation: manifest.json files.libs[] registration

_Note: This plan is `type: execute` (not `tdd`), so each task ships a single feat commit — no separate test/refactor commits._

## Files Created/Modified

- `scripts/lib/cli-installer.sh` — NEW; 157 lines; the cross-platform CLI installer library with three public primitives.
- `manifest.json` — MODIFIED; +3 lines to register `scripts/lib/cli-installer.sh` under `files.libs[]` (alphabetical between `cli-recommendations.sh` and `council-prompts.sh`).

## Public API

| Function | Args | Returns | Side Effects |
|----------|------|---------|--------------|
| `cli_detect <name>` | `name` (required, non-empty) | `0` if `command -v <name>` succeeds, `1` otherwise (or missing-arg) | None — read-only `command -v` probe. NO caching (D-15). |
| `cli_install <name> <darwin_cmd> <linux_cmd>` | three required strings | `0` (success or installer rc); `1` (usage); `2` (unsupported platform); `3` (brew-absent on Darwin); `N` (eval rc verbatim) | Runs `eval "$darwin_cmd"` on Darwin OR `eval "$linux_cmd"` on Linux. Stderr error message on rc=1/2/3. NEVER auto-prefixes sudo. NEVER auto-installs Homebrew. |
| `cli_post_install_hint <hint>` | optional `hint` string | `0` always | Writes `-> Next: <hint>\n` to stderr if hint is non-empty; otherwise no-op. stdout always empty. |

## Test Seams (for Plan 32-03 + Phase 33 dispatch loop)

| Env var | Effect | Plan 32-03 scenarios |
|---------|--------|----------------------|
| `TK_CLI_UNAME` | Replaces `uname -s` resolution inside `cli_install` | S6/S7 (Darwin happy path / Linux happy path), S8 (unsupported FreeBSD reject) |
| `TK_CLI_BREW_BIN` | Replaces `command -v brew` check inside Darwin branch. Unset = use real `command -v brew`; set+empty = simulate brew-absent (rc=3); set+non-empty = simulate brew-present (proceed to eval) | S9 (brew-absent fallback rc=3), S5/equivalent (brew-present runs cmd) |

These seams are documented in the file header (lines 27-32) and intended for tests only — production install paths must NOT export them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Register cli-installer.sh in manifest.json files.libs[]**

- **Found during:** End-of-Task-2 verification step 13 (`make check`).
- **Issue:** `make check` failed with `drift: scripts/lib/cli-installer.sh exists on disk but is not in manifest files.libs`. The drift gate is `validate-manifest.py` Audit M1 (lines 230-246): every file under `scripts/lib/` ending in `.sh` or `.json` must be registered in `manifest.json` `files.libs[]`, otherwise `update-claude.sh` (which is manifest-driven) silently never propagates the file to existing users.
- **Plan tension:** PATTERNS.md "Shared Pattern D" defers manifest changes to Phase 35 DIST-01. However, that defers the **version bump + version-align gate** — the path-registration drift check is a per-PR CI invariant that cannot wait without breaking every PR on main.
- **Fix:** Inserted `{ "path": "scripts/lib/cli-installer.sh" }` into `manifest.json` `files.libs[]` alphabetically between `cli-recommendations.sh` and `council-prompts.sh`. NO version field touched (manifest already at 4.9.0 from ROADMAP planning, separate from DIST-01's bump).
- **Phase 35 implications:** Phase 35 DIST-01 still owns: (a) bumping `version: 4.8.0 -> 4.9.0` (already at 4.9.0 in this commit — verify in Phase 35), (b) renaming `mcp-catalog.json -> integrations-catalog.json` in `files.libs[]` (Phase 32 Plan 32-01 lands the rename), (c) registering `validate-integrations-catalog.py` under `files.scripts[]`.
- **Files modified:** `manifest.json` (+3 lines).
- **Commit:** `b41336a` (folded into Task 2 commit).

### Test Smoke-Check Self-Correction

The Task 2 inline smoke check S7 ("`cli_install` does NOT inject sudo") originally used a naive `! grep -q "sudo" /tmp/cli.$$` test which produced a false positive because the test fixture string `"echo no-sudo-here"` contains the substring `sudo`. Resolved by switching the source-grep to `grep -nE "^[^#]*\bsudo\b" scripts/lib/cli-installer.sh` which excludes commented lines. The actual library code has zero `sudo` invocations; only three documentation comments mention `sudo` in the context of D-17 ("NO sudo auto-prefix"). This is a test-only correction; no library-code change was needed.

## Forward Pointers

- **Phase 33 (catalog population) consumes `cli_install`** from a continue-on-error multi-CLI dispatch loop in `scripts/install.sh` (mirrors v4.6 Phase 25 D-08 MCP wizard pattern at `install.sh:445-499`). That loop adds `tk-cli.XXXXXX` mktemp stderr capture, `INSTALLED_COUNT`/`SKIPPED_COUNT`/`FAILED_COUNT` arrays, and the summary table — none of which are in scope for Plan 32-02.
- **Phase 34 (TUI redesign) consumes `cli_detect`** for the per-component status column on each TUI row (TUI-02 contract — re-detect on every TUI launch, no cache).
- **Phase 35 (distribution + docs)** hardens the no-auto-elevation boundary in `docs/INTEGRATIONS.md` (DOCS-02), bumps manifest version, adds version-align gate, registers the new validator from Plan 32-01.

## Threat Surface Confirmation

All six threats in the plan's `<threat_model>` register are mitigated as documented:

| Threat ID | Status | Notes |
|-----------|--------|-------|
| T-32-02-01 (Tampering — eval) | Mitigated | Trust-boundary comments above both `eval` calls. Eval-ed strings come from schema-validated catalog (Plan 32-01 validator), not user input. |
| T-32-02-02 (Elevation — Linux apt) | Mitigated | No `sudo` token anywhere in code (only in `# IMPORTANT:` comments documenting D-17). Verified by `grep -nE "^[^#]*\bsudo\b"` returning nothing. |
| T-32-02-03 (Tampering — Darwin brew fallback) | Mitigated | `command -v brew` is read-only. TK_CLI_BREW_BIN seam header comment marks it test-only. |
| T-32-02-04 (Info Disclosure — hint) | Accept | Hints are static catalog strings; stderr-only emission. |
| T-32-02-05 (DoS — long-running install) | Accept | No timeout/retry inside primitive — vendor (brew/npm/apt) owns its own progress. |
| T-32-02-06 (Spoofing — TK_CLI_UNAME seam) | Accept | Test-only env var, header-documented. |

## Self-Check: PASSED

- FOUND: `scripts/lib/cli-installer.sh` (executable bit set)
- FOUND: `.planning/phases/32-foundation-schema-migration-cli-installer-library/32-02-SUMMARY.md`
- FOUND commit `0d5f4af` (Task 1: scaffold + cli_detect)
- FOUND commit `b41336a` (Task 2: cli_install + cli_post_install_hint + manifest registration)
- FOUND `scripts/lib/cli-installer.sh` registered in `manifest.json` `files.libs[]`
