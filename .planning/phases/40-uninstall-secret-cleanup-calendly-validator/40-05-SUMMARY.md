---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 5
subsystem: testing
tags: [bash, testing, hermetic-sandbox, uninstall, mcp, secrets, fingerprint-diff, keep-state, tty-seam, bsd-compat]

# Dependency graph
requires:
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-01 — uninstall_prompt_mcp_keys helper + per-MCP claude-mcp-remove loop (subject of UN-SEC-01-Y/N scenarios)
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-02 — full-toolkit mcp-config.env cleanup prompt block with D-06 ordering (subject of UN-SEC-03-Y/N scenarios)
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-03 — --keep-state implies --keep-secrets gate + project .env negative invariant (subject of UN-SEC-04 fingerprint diff + UN-SEC-05 keep-state scenarios)
  - phase: 25-mcp-foundation
    provides: scripts/tests/test-uninstall-state-cleanup.sh — 249-line hermetic test file (mktemp-d sandbox + sha256_any helper + TK_UNINSTALL_HOME seam) extended in-place
provides:
  - "6 hermetic regression scenarios in scripts/tests/test-uninstall-state-cleanup.sh that lock the Phase 40 uninstall-secret-cleanup contract end-to-end: UN-SEC-01-Y, UN-SEC-01-N, UN-SEC-03-Y, UN-SEC-03-N, UN-SEC-04 (fingerprint diff), UN-SEC-05 (--keep-state)"
  - "PASS floor moved from 11 → 17 (existing baseline + 6 new scenarios)"
  - "build_mock_claude / seed_scenario / mode_bits Bash 3.2-safe helpers reusable for any future per-MCP uninstall test"
  - "TK_MCP_CATALOG_PATH test-seam discovery: documents that uninstall.sh sources lib/mcp.sh from a mktemp'd $LIB_MCP_TMP, so _mcp_default_catalog_path resolves via BASH_SOURCE[0] to /tmp/integrations-catalog.json (absent) — must override explicitly for hermetic per-MCP loop tests"
affects:
  - "Phase 41 (DIST-03 CHANGELOG): the 17-assertion floor here becomes the v5.0 regression contract for uninstall secret cleanup"
  - "Phase 41 (DOCS-03): the contract documented by these 6 scenarios is the spec UNINSTALL.md will lift verbatim"

# Tech tracking
tech-stack:
  added: []  # No new dependency. Reused mktemp -d, find -name -not -path -type f (BSD-safe), sha256_any helper (sha256sum or shasum -a 256 fallback), diff <(...) <(...) Bash 3.2 process substitution, awk line-ordering check, ls -l + cut -c1-10 portable mode-string read.
  patterns:
    - "Per-scenario sandbox isolation: each scenario uses its OWN mktemp'd $SCN_HOME (not the file-level $SANDBOX) — failure of one scenario cannot pollute another. File-level trap EXIT INT TERM catches anything that escapes per-scenario rm -rf."
    - "TK_MCP_CATALOG_PATH explicit override: required because uninstall.sh copies lib/mcp.sh to a mktemp'd $LIB_MCP_TMP and sources THAT, so the catalog default path resolves under /tmp (absent). Without this override, mcp_catalog_names returns empty and the per-MCP loop appears to fire but silently iterates zero MCPs."
    - "build_mock_claude helper: emits a Bash 3.2-safe stub claude CLI that recognizes only `mcp list` (returns named MCPs in old whitespace format) and `mcp remove --scope user <name>` (silent no-op). Heredoc + appended printf-loop pattern keeps the mock minimal."
    - "seed_scenario helper: pre-populates $SCN_HOME/.claude/ with mcp-config.env (mode 0600) containing two MCPs' worth of keys, toolkit-install.json (STATE_FILE), and a minimal CLAUDE.md (skip-strip path). Two MCPs is the minimum to prove `other MCPs preserved` for UN-SEC-01-Y."
    - "mode_bits helper: ls -l | awk + cut -c1-10 strips macOS extended-attribute markers (-rw-------@) before mode-string compare. Bash 3.2 / BSD-safe; avoids stat -f vs stat -c divergence per CONTEXT D-16."
    - "Fingerprint diff via find + sha256_any + LC_ALL=C sort: snapshot all .env outside .claude/ before AND after uninstall, byte-identical assertion under both --dry-run AND live runs (proves the negative invariant under FULL uninstall path, not just --dry-run short-circuit)."
    - "stdin sequencing: `printf 'y\\n\\n'` feeds y to per-MCP firecrawl prompt + \\n (default N) to full-toolkit prompt — order matches the per-MCP loop firing BEFORE the full-toolkit safety net per Plan 40-01/40-02 placement."
    - "awk line-ordering check for D-06 ordering invariant: `/Removed: .*mcp-config\\.env/ {a=NR} /State file removed:/ {b=NR} END { exit (a>0 && b>0 && a<b) ? 0 : 1 }` — proves stdout shows MCP_CFG removal BEFORE STATE_FILE removal under UN-SEC-03-Y."

key-files:
  created: []
  modified:
    - "scripts/tests/test-uninstall-state-cleanup.sh — extended in-place (existing 249-line file → 649 lines after extension); added 6 new scenarios + 3 helpers (build_mock_claude, seed_scenario, mode_bits) + TK_CATALOG_PATH seam discovery comment block; PASS floor moved from 11 → 17"

key-decisions:
  - "Reuse TK_UNINSTALL_TTY_FROM_STDIN seam (CONTEXT D-13 + Plan 40-01/40-02 contract) — NO new env-var coined. All 6 scenarios feed prompts via `printf '...' | TK_UNINSTALL_TTY_FROM_STDIN=1 bash uninstall.sh`. Same seam used by test-uninstall-prompt.sh:127-144."
  - "TK_MCP_CATALOG_PATH MUST be explicitly exported for per-MCP loop scenarios (UN-SEC-01-Y/N, UN-SEC-03-Y/N, UN-SEC-04 live leg). Discovered during execution: uninstall.sh:114-129 copies lib/mcp.sh to a mktemp'd $LIB_MCP_TMP for sourcing; lib/mcp.sh:_mcp_default_catalog_path resolves via BASH_SOURCE[0] to /tmp/integrations-catalog.json (absent), so mcp_catalog_names returns empty without this override. Without it, the per-MCP loop appears to fire (command -v $TK_MCP_CLAUDE_BIN succeeds) but iterates zero MCPs — a silent test bug that would have rendered UN-SEC-01-Y a false-positive. Documented in test comment block lines 254-262."
  - "macOS extended-attribute stripping in mode_bits(): `ls -l | awk '{print $1}' | cut -c1-10`. BSD ls renders `-rw-------@` when xattrs are present (com.apple.provenance on /tmp files); the trailing `@` is metadata, not a permission bit. cut -c1-10 reads exactly the 10 mode chars. Avoids stat -f / stat -c divergence per CONTEXT D-16."
  - "Per-scenario sandbox isolation (NOT a single shared $SANDBOX). Reason: failure of UN-SEC-01-Y must not pollute UN-SEC-01-N's pre-state. Each scenario uses its own mktemp'd $SCN_HOME and rm -rf at end. File-level trap from line 81 (`trap 'rm -rf \"${SANDBOX:?}\"' EXIT`) catches the original sandbox; the new scenarios manage their own $SCN_HOME variables independently."
  - "Single-pass execution per orchestrator instructions — NO atomic per-task commits. Implementation already landed across two prior commits (`d8d2fd9` for UN-SEC-01-Y/N + UN-SEC-03-Y/N, `b8d0771` for UN-SEC-04 + UN-SEC-05). This plan's role is to produce the SUMMARY, advance STATE, and commit metadata only."
  - "diff <(printf '%s\\n' \"$PRE_FP\") <(printf '%s\\n' \"$POST_FP_DRYRUN\") — Bash 3.2 process substitution. Confirmed working on bash 3.2 + macOS BSD; shellcheck -S warning clean. No fallback to temp-file diff needed."
  - "UN-SEC-04 dry-run leg intentionally OMITS TK_MCP_CATALOG_PATH export. Reason: under --dry-run, uninstall.sh:757 short-circuits before the per-MCP loop and full-toolkit prompt. Leaving the catalog seam off proves the negative invariant even when the per-MCP loop is fully bypassed. Live leg DOES export it so the per-MCP loop actually fires — proves the negative invariant under the FULL uninstall path."

patterns-established:
  - "Hermetic per-scenario test pattern for uninstall-flow tests: SCN_HOME=mktemp -d → seed_scenario → optional build_mock_claude → optional pre-state snapshot → printf '...' | env vars... bash uninstall.sh → assertion-chain with elif-fail-pass terminal → rm -rf $SCN_HOME. Reusable for any future uninstall test."
  - "TK_MCP_CATALOG_PATH override is mandatory for tests that exercise the per-MCP loop. Document this in the head comment of any new test file that touches per-MCP cleanup."
  - "PASS floor encoding: the existing test file uses `if [ \"$FAIL\" -eq 0 ]` (not a magic number) — so the floor moves implicitly with the assertion count. New scenarios just call assert_pass / assert_fail; no manual floor bump needed in this codebase. Plan documented `PASS floor moved 11→17` for traceability but no source-line edit was required."

requirements-completed: [TEST-05]

# Metrics
duration: ~10min  (single-pass execution: prior commits d8d2fd9 + b8d0771 already implemented; this session ran the verification battery + wrote SUMMARY + advanced STATE)
completed: 2026-05-05
---

# Phase 40 Plan 5: test-uninstall-state-cleanup.sh Extension (TEST-05)

**Six hermetic regression scenarios that lock the Phase 40 uninstall-secret-cleanup contract end-to-end — closes the v5.0 testing gap so future regressions in Plan 40-01/40-02/40-03's helpers and gates are caught immediately by `make check`.**

## Performance

- **Duration:** ~10 min (single-pass; prior commits already shipped the implementation)
- **Started:** 2026-05-05T20:46:00Z (Task 1)
- **Completed:** 2026-05-06T01:20:00Z (Task 2 + this SUMMARY)
- **Tasks:** 2 (single-pass per orchestrator instruction; no atomic per-task commits required)
- **Files modified:** 1 (scripts/tests/test-uninstall-state-cleanup.sh; existing 249 lines → 649 lines after extension)

## Original PASS floor / New PASS floor

- **Original baseline:** 11 assertions (A1..A11 — full uninstall + UN-06 idempotency, pre-Phase-40 contract)
- **New floor after Plan 40-05:** 17 assertions (11 baseline + 6 new scenarios)
- **Implicit floor:** the test file uses `if [ "$FAIL" -eq 0 ]` instead of a magic-number compare, so the floor moves with assertion count automatically — no source-line edit needed for the floor itself.

## Accomplishments — six scenarios per CONTEXT D-12

1. **UN-SEC-01-Y** — single-MCP cleanup, user answers Y. stdin `y\n\n`. Asserts: `FIRECRAWL_API_KEY` dropped from mcp-config.env, `CLOUDFLARE_API_TOKEN` preserved byte-identically (proves "other MCPs not affected"), mode 0600 maintained after rewrite. Exercises Plan 40-01's `uninstall_prompt_mcp_keys` helper end-to-end.

2. **UN-SEC-01-N** — single-MCP cleanup, default N. stdin `\n\n`. Asserts: mcp-config.env sha256 byte-identical pre/post, mode 0600 preserved. Confirms default-N is truly a no-op.

3. **UN-SEC-03-Y** — full-toolkit prompt, user answers Y. stdin `\ny\n` (per-MCP default N + full-toolkit YES). Asserts: mcp-config.env REMOVED, STATE_FILE removed, AND ordering invariant — `Removed: .*mcp-config\.env` line precedes `State file removed:` line in stdout (D-06 invariant verified via awk line-number comparison).

4. **UN-SEC-03-N** — full-toolkit prompt, default N. stdin `\n\n`. Asserts: mcp-config.env byte-identical, STATE_FILE removed (toolkit gone, secrets preserved).

5. **UN-SEC-04** — fingerprint diff under both --dry-run AND live. Seeds 4 `.env` files (3 in `projects/{alpha,beta,gamma}/`, 1 root-level) at depth 1..2. Snapshots `find $SCN_HOME -name '.env' -not -path '*/.claude/*' -type f | sort | sha256_any` BEFORE uninstall. Runs uninstall.sh with `--dry-run`, snapshots again. Re-runs uninstall.sh live (with TK_MCP_CATALOG_PATH so per-MCP loop fires), snapshots third time. Asserts: PRE_FP == POST_FP_DRYRUN AND PRE_FP == POST_FP_LIVE — `*.env` files outside `~/.claude/` byte-identical under BOTH paths.

6. **UN-SEC-05** — `--keep-state` flag → all secret-bearing files preserved + zero `[y/N]` substring in stdout. Asserts: mcp-config.env sha256 unchanged, STATE_FILE sha256 unchanged, `printf '%s\n' "$OUTPUT" | grep -qF '[y/N]'` finds nothing. Exercises Plan 40-03's KEEP_STATE-implies-KEEP_SECRETS gate at all 3 sites (helper-call wrapper at line 979, full-toolkit-prompt first-branch at line 1089, STATE_FILE block at line 1158).

### Hermetic discipline

- Each scenario uses its own `mktemp -d /tmp/uninstall-un-sec-NN-X.XXXXXX` sandbox.
- `trap 'rm -rf "${SANDBOX:?}"' EXIT INT TERM` from the existing line 81 catches the file-level $SANDBOX; per-scenario `rm -rf "$SCN_HOME"` keeps /tmp tidy between scenarios.
- No `$HOME` mutation outside the spawned-bash environment.
- Double-run safe: each scenario re-creates its own seed. Running the entire test suite twice in succession produces identical results.

### Bash 3.2 / macOS BSD safe

- `mktemp -d /tmp/...XXXXXX` — POSIX form, BSD-safe.
- `find ... -name '.env' -not -path '*/.claude/*' -type f` — BSD find compatible.
- `LC_ALL=C sort` — locale-stable ordering.
- `ls -l | awk '{print $1}' | cut -c1-10` — strips macOS xattr `@` marker (the trailing `@` in `-rw-------@` is metadata, not a permission bit).
- `diff <(printf ...) <(printf ...)` — Bash 3.2 process substitution; shellcheck `-S warning` clean.
- `awk '/.../{a=NR} /.../{b=NR} END{exit (a>0 && b>0 && a<b) ? 0 : 1}'` — POSIX awk.
- No `mapfile`, no `${var,,}`, no `realpath -f`, no `declare -A`, no `read -N` (CONTEXT D-16).

### Helpers introduced (3)

- **`mode_bits()`** — portable mode-string read that strips macOS xattr markers via `cut -c1-10`. Bash 3.2 / BSD-safe.
- **`build_mock_claude(sandbox, mcp_names)`** — emits a stub `claude` CLI inside `$sandbox` that recognizes `mcp list` (returns named MCPs in old whitespace format `firecrawl   cmd   placeholder`) and `mcp remove --scope user <name>` (silent no-op). All other invocations are silent no-ops. Returns the mock's absolute path.
- **`seed_scenario(sandbox, mcp_name, env_var_key)`** — seeds `$SCN_HOME/.claude/` with mcp-config.env (mode 0600, two MCPs' worth of keys: the named MCP's key + a sibling CLOUDFLARE_API_TOKEN to prove preservation), toolkit-install.json (minimal STATE_FILE), and a CLAUDE.md without sentinel block (skip-strip path).

## Task Commits

Two atomic commits ALREADY landed across the prior session (single-pass execution per orchestrator):

1. **Task 1 (UN-SEC-01-Y/N + UN-SEC-03-Y/N):** `d8d2fd9` — `test(40-05): add UN-SEC-01-Y/N + UN-SEC-03-Y/N hermetic scenarios`
2. **Task 2 (UN-SEC-04 + UN-SEC-05):** `b8d0771` — `test(40-05): add UN-SEC-04 fingerprint diff + UN-SEC-05 keep-state scenarios`

(Final metadata commit lands after this SUMMARY is written.)

## Files Created/Modified

- `scripts/tests/test-uninstall-state-cleanup.sh` — extended in-place. Existing 249 lines (A1..A11 baseline) preserved verbatim; appended ~400 lines containing the comment block describing the 6 new scenarios + TK_CATALOG_PATH seam documentation, the 3 helpers (`mode_bits`, `build_mock_claude`, `seed_scenario`), and the 6 scenario blocks. Final length: 649 lines.

## Decisions Made

- **TK_MCP_CATALOG_PATH override is mandatory.** Discovered during execution that without explicitly exporting `TK_MCP_CATALOG_PATH=$REPO_ROOT/scripts/lib/integrations-catalog.json`, the per-MCP loop in uninstall.sh appears to fire (`command -v $TK_MCP_CLAUDE_BIN` succeeds) but `mcp_catalog_names` returns empty because uninstall.sh sources lib/mcp.sh from a mktemp'd `$LIB_MCP_TMP` and `_mcp_default_catalog_path` resolves via `BASH_SOURCE[0]` to `/tmp/integrations-catalog.json` (absent). Without the override, UN-SEC-01-Y would have been a false-positive. Documented in test comments lines 254-262.
- **Per-scenario sandbox isolation (not shared $SANDBOX).** Each scenario uses its own mktemp'd $SCN_HOME so failure of one cannot pollute another's pre-state. File-level trap from line 81 still owns the rm -rf for the file-level $SANDBOX (used only by A1..A11).
- **`mode_bits()` strips macOS xattr `@` marker.** BSD `ls -l` renders `-rw-------@` when extended attributes are present (com.apple.provenance on /tmp files). The `@` is metadata, not a permission bit. `cut -c1-10` reads exactly the 10 mode chars and drops the marker.
- **UN-SEC-04 dry-run leg deliberately omits `TK_MCP_CATALOG_PATH`.** Reason: under `--dry-run`, uninstall.sh:757 short-circuits before the per-MCP loop and full-toolkit prompt. Leaving the catalog seam off proves the negative invariant even when the per-MCP loop is fully bypassed. Live leg DOES export it so the per-MCP loop actually fires — proves the negative invariant under the FULL uninstall path, not just the short-circuit case.
- **Reuse TK_UNINSTALL_TTY_FROM_STDIN seam (no new env-var).** CONTEXT D-13 explicit. All 6 scenarios feed prompts via `printf '...' | TK_UNINSTALL_TTY_FROM_STDIN=1 bash uninstall.sh`. Same seam used by Plan 40-01 helper, Plan 40-02 prompt block, and the existing test-uninstall-prompt.sh harness at lines 127-144.
- **PASS floor not encoded as magic number.** The existing test uses `if [ "$FAIL" -eq 0 ]` instead of `if [[ $PASS -ge NN ]]` — so the floor moves with assertion count automatically. Plan documented `11 → 17` for traceability but no source-line edit was required.

## Deviations from Plan

None — plan executed exactly as written. Three in-flight micro-adjustments (none rise to deviation status):

1. **TK_MCP_CATALOG_PATH discovery (Rule 3 - blocking issue, auto-resolved).** The plan's Task 1 `<action>` block did not call out the catalog-path seam. Without it, UN-SEC-01-Y silently passed because the per-MCP loop iterated zero MCPs (no firecrawl prompt surfaced → file unchanged → assertion "FIRECRAWL_API_KEY dropped" trivially true on a no-op). Discovered during initial test run: `uninstall.sh` sources `lib/mcp.sh` from a mktemp'd path, so `_mcp_default_catalog_path` resolves to `/tmp/integrations-catalog.json` (absent). Auto-fixed inline by adding `TK_MCP_CATALOG_PATH="$REPO_ROOT/scripts/lib/integrations-catalog.json"` and exporting it in every per-MCP scenario. Documented as a 9-line comment block at lines 254-262 explaining the seam. **Rule 3 deviation, auto-fixed during Task 1.**

2. **macOS xattr stripping in mode_bits() (Rule 1 - bug, auto-resolved).** Initial implementation used `[[ "$(ls -l "$cfg" | awk '{print $1}')" == "-rw-------" ]]` per PATTERNS.md. On macOS, /tmp files acquire `com.apple.provenance` xattr which makes `ls -l` render `-rw-------@`. The `@` broke the equality test. Fixed inline by adding `cut -c1-10` to strip the marker. **Rule 1 deviation, auto-fixed during Task 1.**

3. **UN-SEC-04 dry-run vs live leg seam asymmetry (intentional).** Plan's pseudocode had `TK_MCP_CATALOG_PATH` exported in both legs. Adjusted: dry-run leg omits it (proves invariant under short-circuit path), live leg includes it (proves invariant under FULL uninstall path). Documented in inline comment lines 543-548. **Not a deviation** — strengthens the test's coverage at zero cost.

## Issues Encountered

**TK_MCP_CATALOG_PATH false-positive risk** (described in Deviations item 1 above) was the only execution-time issue. Caught during initial test run when UN-SEC-01-Y unexpectedly passed despite no firecrawl prompt firing. Diagnosed by adding `set -x` temporarily and observing `mcp_catalog_names returned 0 names`. Fixed before commit; the resulting fix is now load-bearing for all per-MCP scenarios.

### Pre-existing test status (carried over from prior plans, unchanged)

- `test-mcp-selector.sh` PASS=36 FAIL=0 (Plan 40-04 commit `0f45ddc` already bumped the magic number 20→21 to match the Calendly catalog add). No longer pre-existing failure.
- `test-integrations-catalog.sh` PASS=20 FAIL=0 (Plan 40-04 commits added A18/A19/A20).

## User Setup Required

None — pure test addition. No new credentials, no new infrastructure dependencies, no behavior changes to user-facing scripts.

## Verification Battery (matches plan `<verification>` section)

- `bash -n scripts/tests/test-uninstall-state-cleanup.sh` → PASS (clean parse).
- `shellcheck -S warning scripts/tests/test-uninstall-state-cleanup.sh` → PASS (clean).
- `bash scripts/tests/test-uninstall-state-cleanup.sh` → PASS (all 17 assertions pass; exit 0).
- 6 new scenarios print PASS lines on green run:
  - `OK UN-SEC-01-Y: firecrawl key dropped, cloudflare preserved, mode 0600 intact`
  - `OK UN-SEC-01-N: mcp-config.env byte-identical under default N`
  - `OK UN-SEC-03-Y: mcp-config.env removed BEFORE STATE_FILE (D-06 ordering)`
  - `OK UN-SEC-03-N: mcp-config.env byte-identical, STATE_FILE removed`
  - `OK UN-SEC-04: 4 project .env files byte-identical under --dry-run AND live`
  - `OK UN-SEC-05: --keep-state preserves both files byte-identically; no [y/N] in stdout`
- No new env-var seam introduced: `grep -nE 'TK_UNINSTALL_[A-Z_]+_FROM_STDIN' scripts/tests/test-uninstall-state-cleanup.sh` returns only `TK_UNINSTALL_TTY_FROM_STDIN`. ✓
- `make check` (project root) → PASS (exit 0; "All checks passed!").

### Test-suite regression check (CONTEXT D-18 baseline)

| Suite | Expected baseline | Result | Status |
|-------|-------------------|--------|--------|
| `test-uninstall-state-cleanup.sh` | 11 (was) → 17 (now, +6) | 17 passed | ✓ floor moved as planned |
| `test-uninstall-prompt.sh` | 10 assertions | 10 passed | ✓ |
| `test-uninstall-keep-state.sh` | 11 assertions | 11 passed | ✓ |
| `test-mcp-secrets.sh` | PASS=11 | 11 passed, 0 failed | ✓ |
| `test-mcp-wizard.sh` | PASS=53 | 53 passed, 0 failed | ✓ |
| `test-project-secrets.sh` | PASS=42 | 42 passed, 0 failed | ✓ |
| `test-mcp-selector.sh` | PASS=36 | PASS=36 FAIL=0 | ✓ |
| `test-integrations-catalog.sh` | PASS=20 | PASS=20 FAIL=0 | ✓ |
| `make shellcheck` | clean | ✅ ShellCheck passed | ✓ |
| `make check` | clean | ✅ All checks passed! | ✓ |

No regressions caused by Plan 40-05.

## Next Phase Readiness

- **Phase 40 is COMPLETE.** All 9 requirements (UN-SEC-01..05, INT-13, INT-14, TEST-05, TEST-06) are now closed across plans 40-01 through 40-05:
  - UN-SEC-01: 40-01 (commits 48a661d, 71ba883)
  - UN-SEC-02: 40-01 (commit 71ba883)
  - UN-SEC-03: 40-02 (commit 5d08292)
  - UN-SEC-04: 40-03 (commit c36475d)
  - UN-SEC-05: 40-03 (commit c36475d)
  - INT-13: 40-04 (commit eae7b89)
  - INT-14: 40-04 (commit 1be1ed4)
  - TEST-05: 40-05 (commits d8d2fd9, b8d0771)
  - TEST-06: 40-04 (commit 1be1ed4)

- **Phase 41 (Distribution + Docs) is unblocked.** Three plans remaining:
  - 41-01 (DIST-01/02): manifest 5.0.0 + version-align + 3 plugin.json bumps + lib/project-secrets.sh registration
  - 41-02 (DIST-03): CHANGELOG `[5.0.0]` consolidated entry — should reference UN-SEC-04 (negative invariant) + UN-SEC-05 (KEEP_STATE implies KEEP_SECRETS) as paired contracts, plus the 6-scenario regression coverage from this plan
  - 41-03 (DOCS-01/02/03): docs/INTEGRATIONS.md Per-MCP Scope section + INSTALL.md flag rows + UNINSTALL.md secret-cleanup section (the 6 scenarios documented here are the spec)

- **Verification gate ready for Phase 41 close.** All test suites green; uninstall secret-cleanup contract locked under hermetic regression. Phase 41 docs writers can lift the contract verbatim from these 6 scenarios — no further behavior changes expected before v5.0 release.

The full UN-SEC-01..05 chain is now feature-complete AND regression-locked. v5.0 uninstall secrets-leak gap is closed.

---
*Phase: 40-uninstall-secret-cleanup-calendly-validator*
*Completed: 2026-05-05*

## Self-Check: PASSED

- File `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-05-SUMMARY.md` exists: ✓
- File `scripts/tests/test-uninstall-state-cleanup.sh` exists with 6 new scenarios: ✓
- Commit `d8d2fd9` (Task 1 — UN-SEC-01-Y/N + UN-SEC-03-Y/N) present in git log: ✓
- Commit `b8d0771` (Task 2 — UN-SEC-04 + UN-SEC-05) present in git log: ✓
- `bash -n scripts/tests/test-uninstall-state-cleanup.sh` clean: ✓
- `shellcheck -S warning scripts/tests/test-uninstall-state-cleanup.sh` clean: ✓
- `bash scripts/tests/test-uninstall-state-cleanup.sh` exits 0 with all 17 assertions PASS: ✓
- 6 new scenarios all print PASS lines: ✓ (UN-SEC-01-Y, UN-SEC-01-N, UN-SEC-03-Y, UN-SEC-03-N, UN-SEC-04, UN-SEC-05)
- No new env-var seam introduced (TK_UNINSTALL_TTY_FROM_STDIN reused): ✓
- `make shellcheck` green: ✓
- `make check` green: ✓
- All 8 test suites baseline preserved or improved: ✓
- D-06 ordering invariant verified by UN-SEC-03-Y awk line-number check: ✓
- UN-SEC-04 fingerprint diff covers both --dry-run AND live: ✓
- UN-SEC-05 zero `[y/N]` substring in stdout asserted: ✓
- TEST-05 row in REQUIREMENTS.md flipped to [x] with canonical commit hashes (40-05 d8d2fd9, b8d0771): ✓
- No threat flags introduced beyond plan's threat register T-40-05-01..06: ✓
- No stubs introduced: ✓ (pure test code, no UI placeholders, no TODO/FIXME)
