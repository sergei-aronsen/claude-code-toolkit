---
phase: 21-sp-gsd-bootstrap-installer
verified: 2026-04-27T08:30:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
human_verification:
  - test: "Real upstream installers succeed end-to-end"
    expected: "In a clean $HOME, run init-claude.sh (no --no-bootstrap), answer y to both prompts; ~/.claude/plugins/cache/claude-plugins-official/superpowers/ and ~/.claude/get-shit-done/ both exist after"
    why_human: "Hits real Claude marketplace + GitHub raw content; not deterministic from CI; depends on upstream availability (BOOTSTRAP-02 contract) — also flagged as Manual-Only in 21-VALIDATION.md"
  - test: "curl|bash install path exercises /dev/tty correctly"
    expected: "Pipe init-claude.sh from raw URL after Phase 21 ships; user can answer prompts via real /dev/tty; behaviour matches local invocation"
    why_human: "curl-piped install consumes stdin for the script body; only a real TTY can exercise the prompt path (BOOTSTRAP-01 contract) — flagged as Manual-Only in 21-VALIDATION.md"
  - test: "Visual review of two-prompt UX flow"
    expected: "User sees SP prompt first, then GSD prompt; default N is clear; upstream installer output streams verbatim to stdout/stderr (D-11)"
    why_human: "UX quality / output formatting / progress feel cannot be asserted with grep"
---

# Phase 21: SP/GSD Bootstrap Installer Verification Report

**Phase Goal:** Users running `init-claude.sh` or `init-local.sh` for the first time can install `superpowers` and/or `get-shit-done` before the toolkit detection logic runs, without leaving the installer or issuing additional commands.

**Verified:** 2026-04-27T08:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| #   | Truth                                                                                                                                                                                                                                              | Status     | Evidence                                                                                                                                                                                                                                                                                                                       |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | User runs `init-claude.sh`; before detection fires, two prompts appear (SP + GSD); answering `y` to SP triggers `claude plugin install superpowers@claude-plugins-official` with output streaming verbatim (BOOTSTRAP-01, BOOTSTRAP-02)            | VERIFIED   | `bootstrap_base_plugins()` defined in `scripts/lib/bootstrap.sh:68` reads two `[y/N]` prompts from `/dev/tty` (override: `TK_BOOTSTRAP_TTY_SRC`); `eval "$cmd"` executes canonical command from `TK_SP_INSTALL_CMD` (`scripts/lib/optional-plugins.sh:18`). S1 of `test-bootstrap.sh` proves both prompts render and mock runs. |
| 2   | After bootstrap, toolkit proceeds with detection and installs in correct mode — answering `y` to SP causes `toolkit-install.json` to record `complement-sp` rather than `standalone` (BOOTSTRAP-03)                                                | VERIFIED   | `init-claude.sh:113-117` and `init-local.sh:154-176` call `bootstrap_base_plugins` then re-source `detect.sh`. `init-claude.sh` shows `source "$DETECT_TMP"` twice (lines 93, 116); `init-local.sh` shows `source "$SCRIPT_DIR/detect.sh"` twice (lines 32, 157). HAS_SP/HAS_GSD recomputed before mode resolution.             |
| 3   | `init-claude.sh --no-bootstrap` (or `TK_NO_BOOTSTRAP=1`) produces zero bootstrap prompts and unchanged v4.3 install behaviour; `--help` lists the flag; `docs/INSTALL.md` documents it (BOOTSTRAP-04)                                              | VERIFIED   | Both installers parse `--no-bootstrap`; `init-local.sh --help` outputs `--no-bootstrap        Skip the SP/GSD install prompts (env: TK_NO_BOOTSTRAP=1)`; `init-claude.sh` unknown-arg branch lists the flag; `docs/INSTALL.md` has `## Installer Flags` section + `### --no-bootstrap (v4.4+)` subsection (4 occurrences).      |
| 4   | `scripts/tests/test-bootstrap.sh` passes all three branches — prompt-y, prompt-N, `--no-bootstrap` skip — with no stdin/TTY assumption failures in piped mode (BOOTSTRAP-04)                                                                       | VERIFIED   | Live execution: `bash scripts/tests/test-bootstrap.sh` → `Bootstrap test complete: PASS=26 FAIL=0`. Covers S1 (y/y), S2 (N/N), S3 (--no-bootstrap + TK_NO_BOOTSTRAP=1), S4 (claude missing), S5 (SP exit 1 non-fatal). Driver is `init-local.sh --dry-run base` — no real TTY needed; uses `TK_BOOTSTRAP_TTY_SRC` file seam.    |

**Score:** 4/4 truths verified

---

### Required Artifacts

| Artifact                                | Expected                                                                                       | Status      | Details                                                                                                                                                                                                                                                                                              |
| --------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/lib/bootstrap.sh`              | Exposes `bootstrap_base_plugins()` + `_bootstrap_prompt_and_run()`; honours D-04..D-19          | VERIFIED    | 99 lines; `bootstrap_base_plugins()` at L68; `_bootstrap_prompt_and_run()` at L40; no `set -e`/`set -u`/`set -o pipefail`; SC2294 disable comment present above `eval`; SP+GSD fallback chains `${TK_BOOTSTRAP_*_CMD:-${TK_*_INSTALL_CMD:-}}`; idempotency probes (`[[ -d ... ]]`) at L79 / L90.       |
| `scripts/lib/optional-plugins.sh`       | Exports `TK_SP_INSTALL_CMD` + `TK_GSD_INSTALL_CMD` constants (single source of truth — D-12)   | VERIFIED    | Guarded constants at L18-19; `recommend_optional_plugins()` references `${TK_SP_INSTALL_CMD}` / `${TK_GSD_INSTALL_CMD}` at L36 / L39. Canonical strings appear once each (no duplication).                                                                                                            |
| `scripts/init-claude.sh`                | `--no-bootstrap` argparse + curl-fetch bootstrap.sh + bootstrap_base_plugins call + detect re-source | VERIFIED    | `--no-bootstrap)` case at L41-44; `NO_BOOTSTRAP="${NO_BOOTSTRAP:-false}"` default at L62; `LIB_BOOTSTRAP_TMP` mktemp at L73; curl fetch at L100-103; `source "$LIB_BOOTSTRAP_TMP"` at L105; call block at L113-117 with `bootstrap_base_plugins` + `source "$DETECT_TMP"` re-source.                  |
| `scripts/init-local.sh`                 | Same as above + `--help` line + color re-gate                                                  | VERIFIED    | Sources `lib/optional-plugins.sh` (L40) + `lib/bootstrap.sh` (L42) early; `--no-bootstrap)` case at L99-102; `--help` Usage + Options describe flag (L108, L118); `NO_BOOTSTRAP=false` default at L83; call block at L154-176 with `bootstrap_base_plugins`, `source detect.sh`, color re-gate.       |
| `scripts/tests/test-bootstrap.sh`       | 5-scenario hermetic test (~25 assertions); covers S1..S5 + TK_NO_BOOTSTRAP env-var form        | VERIFIED    | 261 lines; first line `#!/usr/bin/env bash`; `set -euo pipefail`; 5 `run_s*()` functions; 26 assertions total; uses `TK_BOOTSTRAP_SP_CMD` / `TK_BOOTSTRAP_GSD_CMD` / `TK_BOOTSTRAP_TTY_SRC` seams; sandbox via `mktemp -d` + `trap "rm -rf '${SANDBOX:?}'" RETURN`; PASS=26 FAIL=0 on live run.        |
| `Makefile`                              | Test 28 invocation block invoking test-bootstrap.sh                                             | VERIFIED    | Lines 144-145: `@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"` + `@bash scripts/tests/test-bootstrap.sh`. Appears AFTER Test 27 (uninstall) and BEFORE `All tests passed!` final line.                                                                                     |
| `.github/workflows/quality.yml`         | Step renamed "Tests 21-28" + appends test-bootstrap.sh                                          | VERIFIED    | Line 109 step name `Tests 21-28 — uninstall + banner suite + bootstrap (UN-01..UN-08, BOOTSTRAP-01..04)`; line 118 invokes `bash scripts/tests/test-bootstrap.sh` as last command in the run block.                                                                                                  |
| `docs/INSTALL.md`                       | `--no-bootstrap` documented (CLI flag + TK_NO_BOOTSTRAP=1 env-var form)                         | VERIFIED    | `## Installer Flags` section at L29 + `### --no-bootstrap (v4.4+)` subsection at L43; `TK_NO_BOOTSTRAP=1` mentioned twice (L40, L48); `--no-bootstrap` mentioned 4 times.                                                                                                                              |

---

### Key Link Verification

| From                              | To                                                                       | Via                                                                                            | Status   | Details                                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------ |
| `bootstrap.sh`                    | `optional-plugins.sh`                                                     | reads `TK_SP_INSTALL_CMD` / `TK_GSD_INSTALL_CMD` via fallback chain                            | WIRED    | bootstrap.sh:75-76 — `sp_cmd="${TK_BOOTSTRAP_SP_CMD:-${TK_SP_INSTALL_CMD:-}}"`; gsd_cmd same. Caller must source optional-plugins.sh first (init-claude.sh:99, init-local.sh:40) — confirmed. |
| `bootstrap.sh`                    | `/dev/tty` (or `TK_BOOTSTRAP_TTY_SRC`)                                   | `read -r -p ... < "$tty_target" 2>/dev/null`                                                   | WIRED    | bootstrap.sh:42-43 + L46. TTY override env var honoured; fail-closed via `if ! read ... ; then return 0` (L46-49). |
| `init-claude.sh`                  | `lib/bootstrap.sh` (curl-fetched)                                         | `curl -sSLf $REPO_URL/scripts/lib/bootstrap.sh -o $LIB_BOOTSTRAP_TMP; source $LIB_BOOTSTRAP_TMP` | WIRED    | init-claude.sh:100-105. Trap registered at L74 + L123 includes `$LIB_BOOTSTRAP_TMP`.                                |
| `init-local.sh`                   | `lib/bootstrap.sh` (local)                                                | `source "$SCRIPT_DIR/lib/bootstrap.sh"`                                                        | WIRED    | init-local.sh:42. Sourced AFTER `lib/optional-plugins.sh` at L40 (correct order — bootstrap needs the constants).   |
| post-bootstrap call               | `detect.sh` (re-source)                                                   | second source so HAS_SP/HAS_GSD reflect post-bootstrap reality (D-14)                          | WIRED    | init-claude.sh: 2× `source "$DETECT_TMP"` at L93 + L116. init-local.sh: 2× `source "$SCRIPT_DIR/detect.sh"` at L32 + L157. |
| `Makefile` Test 28                | `scripts/tests/test-bootstrap.sh`                                         | `@bash scripts/tests/test-bootstrap.sh` recipe                                                  | WIRED    | Makefile L145 (TAB-indented recipe).                                                                                |
| CI quality.yml `Tests 21-28` step | `scripts/tests/test-bootstrap.sh`                                         | `bash scripts/tests/test-bootstrap.sh` in `run:` block                                          | WIRED    | quality.yml L118 — last command in the composite-test run block.                                                    |
| `test-bootstrap.sh`               | `init-local.sh` + `lib/bootstrap.sh` + `TK_BOOTSTRAP_*_CMD` seam          | subshell exec with seam env vars                                                                | WIRED    | All 5 scenarios use `TK_BOOTSTRAP_SP_CMD`, `TK_BOOTSTRAP_GSD_CMD`, `TK_BOOTSTRAP_TTY_SRC`; S3 also covers `TK_NO_BOOTSTRAP=1`. |

---

### Behavioral Spot-Checks

| Behavior                                                                                          | Command                                                                              | Result                                              | Status |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | --------------------------------------------------- | ------ |
| Hermetic bootstrap test passes end-to-end                                                         | `bash scripts/tests/test-bootstrap.sh`                                              | `Bootstrap test complete: PASS=26 FAIL=0`           | PASS   |
| All target shell files pass `bash -n`                                                             | `bash -n` on bootstrap.sh, optional-plugins.sh, init-claude.sh, init-local.sh        | `ALL_SYNTAX_OK`                                     | PASS   |
| Shellcheck clean at warning severity for all 5 phase-touched shell files                          | `shellcheck -S warning ...` (5 files)                                                | exit 0                                              | PASS   |
| `init-local.sh --help` lists `--no-bootstrap`                                                     | `bash scripts/init-local.sh --help \| grep -- '--no-bootstrap'`                      | 2 matches (Usage + Options)                         | PASS   |
| `init-claude.sh` unknown-arg path lists `--no-bootstrap`                                          | `bash scripts/init-claude.sh --invalid-flag 2>&1 \| grep -- '--no-bootstrap'`        | 1 match                                             | PASS   |
| Project markdownlint clean (covers docs/INSTALL.md + summary/plan markdown)                       | `make mdlint`                                                                        | `Markdownlint passed`                               | PASS   |
| Project shellcheck clean across `scripts/` and `templates/global/`                                | `make shellcheck`                                                                    | `ShellCheck passed`                                 | PASS   |
| `bootstrap.sh` does NOT contain `set -e`/`set -u`/`set -o pipefail` (shared-lib invariant)        | `! grep -E '^set -[eu]\|^set -o pipefail\|^set -euo pipefail' scripts/lib/bootstrap.sh` | exit 0 (no matches)                                 | PASS   |
| `bootstrap_base_plugins` order in init-claude.sh: optional-plugins source < bootstrap call < manifest | awk line-number ordering check                                                       | opt-plug-source: 99, bootstrap_call: 114, manifest: 128 → order OK | PASS   |

---

### Requirements Coverage

| Requirement | Source Plan(s)        | Description                                                                                                       | Status     | Evidence                                                                                                                                                                                                                                                                                                       |
| ----------- | --------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BOOTSTRAP-01 | 21-01, 21-02, 21-03   | Two `[y/N]` prompts before detect.sh; default N; fail-closed on no TTY; skipped under non-interactive contexts    | SATISFIED  | `bootstrap.sh:46-49` reads `< /dev/tty`, returns 0 if read fails; D-04/D-05 (default N via `case "${choice:-N}"`); init-claude.sh L113-117 + init-local.sh L154 fire BEFORE manifest+mode resolution. S1/S2 of test-bootstrap.sh cover prompt-y and prompt-N branches.                                            |
| BOOTSTRAP-02 | 21-01, 21-02, 21-03   | On `y` for SP, run canonical `claude plugin install superpowers@...`; on `y` for GSD, run canonical curl install; non-fatal on failure | SATISFIED  | `optional-plugins.sh:18-19` defines canonical strings literally; `bootstrap.sh:55` evals via `${TK_BOOTSTRAP_*_CMD:-${TK_*_INSTALL_CMD:-}}` chain; `bootstrap.sh:56-58` captures non-zero rc and emits warning instead of aborting (D-10). S5 of test-bootstrap.sh proves SP exit-1 is non-fatal and GSD still runs. |
| BOOTSTRAP-03 | 21-02, 21-03          | After bootstrap, detect.sh runs again so toolkit installs in correct mode; state in toolkit-install.json reflects post-bootstrap | SATISFIED  | init-claude.sh:116 + init-local.sh:157 re-source detect.sh post-bootstrap. `recommend_mode` (lib/install.sh) reads HAS_SP/HAS_GSD which are now fresh. Test S1 asserts post-bootstrap mode reflects mocks (mocks don't write SP/GSD dirs → mode stays `standalone` — proves detect ran fresh).                  |
| BOOTSTRAP-04 | 21-02, 21-03          | `--no-bootstrap` flag and `TK_NO_BOOTSTRAP=1` env var skip prompts; documented in --help and docs/INSTALL.md; hermetic test in test-bootstrap.sh | SATISFIED  | Both installers parse `--no-bootstrap`; `init-local.sh --help` shows flag; `init-claude.sh` unknown-arg branch lists flag; `docs/INSTALL.md` `## Installer Flags` + `### --no-bootstrap` subsection (4 occurrences); S3 of test-bootstrap.sh proves both flag and env-var forms produce byte-quiet output.        |

**Coverage:** 4/4 requirements satisfied. No orphaned IDs (REQUIREMENTS.md `Phase 21` row in traceability table maps exactly BOOTSTRAP-01..04, all four claimed by phase plans).

---

### Anti-Patterns Found

| File                                  | Line  | Pattern                                                                                                                                                                  | Severity   | Impact                                                                                                                                                                                                                                |
| ------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/init-claude.sh`              | 113-117 | Color re-gate missing after post-bootstrap `source "$DETECT_TMP"` (REVIEW.md WR-02 — latent bug; no-op today because init-claude.sh sets colors unconditionally at L11-15) | Info       | Latent — only fires if a future change adds `[ -t 1 ]` gate to init-claude.sh for parity with init-local.sh. Documented in REVIEW.md. NOT blocking goal.                                                                              |
| `scripts/lib/optional-plugins.sh`    | 19    | `TK_GSD_INSTALL_CMD` is `bash <(curl \| bash)` from third-party repo with no integrity check (REVIEW.md WR-03)                                                          | Info       | Supply-chain trust boundary. The canonical command is mandated by REQ BOOTSTRAP-02 ("no forks") and PROJECT.md user direction 2026-04-27. Acceptable per project policy. Documented in REVIEW.md.                                       |
| `scripts/init-claude.sh`              | 69-74 | Trap registered AFTER 5x `mktemp` calls — if mktemp fails mid-batch, earlier tmp files leak (REVIEW.md WR-01)                                                            | Info       | Pre-existing pattern (predates Phase 21). All 5 mktemp calls are well-tested in v4.3 paths. Phase 21 inherited the pattern when adding `LIB_BOOTSTRAP_TMP` between L72 and L74. NOT introduced by this phase. Recommended cleanup in future. |
| `scripts/tests/test-bootstrap.sh`     | 60    | `printf '%q'` Bash-3.2 BSD vs Bash-4+ GNU divergence risk (REVIEW.md IN-04)                                                                                              | Info       | Not exercised today (mock messages are ASCII-only). Future maintainers warned. NOT blocking.                                                                                                                                          |
| `scripts/lib/bootstrap.sh`            | 47    | `_bootstrap_prompt_and_run` swallows EOF as silent N — no log line distinguishes EOF from explicit N for specific plugin (REVIEW.md IN-03)                                | Info       | Functional contract preserved (D-06 fail-closed). Cosmetic — log line says "bootstrap skipped — no TTY" without plugin name. NOT blocking.                                                                                            |
| `scripts/tests/test-bootstrap.sh`     | 163-166 | S3 byte-quiet assertion is substring-only — would not catch a NEW INFO line being added in a future change (REVIEW.md WR-04)                                            | Warning    | Test is over-permissive. Current code passes; test still proves byte-quiet today. Recommended hardening: byte-equivalent diff between `--no-bootstrap` and `TK_NO_BOOTSTRAP=1` outputs (REVIEW.md provides the patch). NOT blocking goal — D-17 contract met by current code. |

No critical or blocking anti-patterns found. None introduce stubs or hollow data flows.

---

### Locked-Decision Compliance Spot-Check

| Decision | Description                                                              | Status                                                                                                                                              |
| -------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| D-06     | TTY fail-closed                                                          | HONORED — `bootstrap.sh:46-49` `if ! read ... < "$tty_target" 2>/dev/null; then return 0` (silent, no prompt rendered)                              |
| D-08     | Idempotency probes (filesystem only)                                     | HONORED — `bootstrap.sh:79` checks SP cache dir; `bootstrap.sh:90` checks GSD dir; both with `[[ -d ... ]]` short-circuit                            |
| D-10     | Non-fatal upstream eval                                                  | HONORED — `bootstrap.sh:55` `eval "$cmd" \|\| rc=$?` + L56-58 emits warning, does not exit                                                          |
| D-12     | Single source of truth for install commands                              | HONORED — canonical strings ONLY in `optional-plugins.sh:18-19`; `bootstrap.sh` reads via fallback chain `${TK_BOOTSTRAP_*_CMD:-${TK_*_INSTALL_CMD:-}}` |
| D-17     | TK_NO_BOOTSTRAP byte-quiet                                               | HONORED — `bootstrap.sh:70` early `return 0` with no log line (test S3 confirms zero bootstrap output)                                              |
| D-19     | Test seam (`TK_BOOTSTRAP_SP_CMD`, `TK_BOOTSTRAP_GSD_CMD`, `TK_BOOTSTRAP_TTY_SRC`) | HONORED — all three env vars consumed by `bootstrap.sh`; test-bootstrap.sh sets all three for hermetic scenarios                                    |

---

### Human Verification Required

The 4 must-have truths are PASS via automated checks, but Phase 21 has interactive UX surfaces that grep + sandbox tests cannot fully exercise. Three items need human eyeballs.

#### 1. Real upstream installers succeed end-to-end

**Test:** In a clean `$HOME` sandbox: `mktemp -d` → set `HOME=` to that dir → run `bash scripts/init-claude.sh` (no `--no-bootstrap`) → answer `y` to both prompts.
**Expected:** `~/.claude/plugins/cache/claude-plugins-official/superpowers/` exists; `~/.claude/get-shit-done/` exists; toolkit install proceeds and `~/.claude/toolkit-install.json` records `complement-full` (or `complement-sp`/`complement-gsd` if either upstream installer failed).
**Why human:** Hits live Claude marketplace + GitHub raw content — non-deterministic and depends on upstream availability. Already pre-flagged as Manual-Only in 21-VALIDATION.md.

#### 2. curl|bash piped install path

**Test:** From a fresh shell on the developer machine after Phase 21 ships to main: `bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh)` → confirm both prompts render via `< /dev/tty` and accept `y` answers.
**Expected:** Both prompts visible; user can answer; behaviour matches local invocation. No "stdin already consumed by curl" failure.
**Why human:** Curl-piped install consumes process stdin for the script body itself — only a real controlling terminal exercises the `< /dev/tty` redirect. Already pre-flagged as Manual-Only in 21-VALIDATION.md.

#### 3. Visual review of the two-prompt UX flow

**Test:** Run `bash scripts/init-local.sh --dry-run base` in a real terminal with both upstream commands available; observe SP prompt first, then GSD prompt; verify upstream installer output streams verbatim to terminal (no buffering/wrapping).
**Expected:** Prompt order SP → GSD; default N visually clear; on `y`, upstream output is verbatim (D-11). No banner noise from the toolkit obscuring upstream output.
**Why human:** UX quality (prompt phrasing, default-visibility, stream interleaving) is subjective and not amenable to grep assertions.

---

### Gaps Summary

No automated gaps found. All 4 ROADMAP success criteria pass automated verification. All 4 BOOTSTRAP-0X requirements satisfied with concrete code evidence. All 8 declared artifacts exist with correct content. All 7 key links wired correctly. The hermetic test passes 26/26 assertions. `make shellcheck` and `make mdlint` pass.

The Phase 21 REVIEW.md (10 findings: 0 critical, 4 warning, 6 info) flagged 4 warnings — none of them blocks Phase 21's goal:

- **WR-01** (trap-after-mktemp ordering in init-claude.sh) — pre-existing pattern; NOT introduced by Phase 21
- **WR-02** (color re-gate missing after detect.sh re-source in init-claude.sh) — latent bug only; today a no-op because init-claude.sh sets colors unconditionally
- **WR-03** (third-party repo trust boundary on `bash <(curl | bash)`) — mandated by REQ BOOTSTRAP-02 "no forks" invariant
- **WR-04** (S3 byte-quiet assertion is substring-only, not byte-equivalent) — current code passes the contract; test could be stricter

The 3 `human_verification` items above cover behaviours that no grep/sandbox test can validate (live upstream installers, real `/dev/tty` under `curl|bash`, UX flow). Per Step 9 of the verification process, the presence of any human-required items forces `status: human_needed` even when automated score is N/N.

---

_Verified: 2026-04-27T08:30:00Z_
_Verifier: Claude (gsd-verifier)_
