---
phase: 03-install-flow
verified: 2026-04-18T13:21:23Z
status: human_needed
score: 21/21 must-haves verified
overrides_applied: 0
---

# Phase 3: Install Flow — Verification Report

**Phase Goal:** Users can install the toolkit in any of four modes via init-claude.sh and init-local.sh, with dry-run preview, mode auto-recommendation, and settings.json merged safely.

**Verified:** 2026-04-18T13:21:23Z
**Status:** human_needed (all automated checks pass; real-world install paths need human confirmation)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP success criteria + merged plan truths)

| #   | Truth                                                                                                                                                    | Status     | Evidence                                                                                                                                                                                                   |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Fresh install on a machine with SP+GSD detected recommends complement-full; user can override to any other mode before any file is written (ROADMAP #1) | ✓ VERIFIED | `HAS_SP=true HAS_GSD=true recommend_mode` → `complement-full`; `select_mode()` presents 1..4 prompt with recommendation as empty-input default; `--mode` flag overrides with allowlist validation          |
| 2   | `init-claude.sh --dry-run` prints per-file [INSTALL] / [SKIP - conflicts_with:superpowers] list and exits 0 without touching the filesystem (ROADMAP #2) | ✓ VERIFIED | `bash init-local.sh --dry-run --mode complement-sp` → 47 [INSTALL] + 7 [SKIP - conflicts_with:superpowers] + `Total: 47 install, 7 skip` footer; exit 0; `.claude/` directory not created after run        |
| 3   | Running init-claude.sh with SP present does not install any file whose conflicts_with includes superpowers (ROADMAP #3)                                  | ✓ VERIFIED | Manual install under `--mode complement-sp` leaves 7 SP-conflict files absent from `.claude/` (commands/{plan,debug,tdd,verify,worktree}.md, agents/code-reviewer.md, skills/debugging/SKILL.md)           |
| 4   | After install, settings.json retains all hooks previously installed by SP or GSD; only TK-owned entries are added or replaced (ROADMAP #4)               | ✓ VERIFIED | `merge_settings_python` partitions by `_tk_owned` marker; foreign entries preserved verbatim; TK entry APPENDED at end (Test 8a: `[0]=/sp/...`, `[1]=/gsd/...`, `[2]={_tk_owned:true, /tk/...}`)           |
| 5   | settings.json backup with unix-ts suffix exists on disk before any mutation; failed merge restores from backup before exiting non-zero (ROADMAP #5)      | ✓ VERIFIED | `backup_settings_once` creates `.bak.$(date +%s)` via `cp`; Test 8b asserts backup filename matches `.bak.[0-9]+`, MD5 equals pre-merge; Test 8c: `TK_TEST_INJECT_FAILURE=1` returns non-zero, file intact |
| 6   | init-claude.sh sources detect.sh + lib/install.sh via remote mktemp+curl+trap pattern before any filesystem write                                        | ✓ VERIFIED | init-claude.sh:63 `DETECT_TMP=$(mktemp ...)`, :65 `trap 'rm -f ...' EXIT`, :67 `curl -sSLf $REPO_URL/scripts/detect.sh`, :76 `source $DETECT_TMP` — all before any filesystem write                        |
| 7   | init-local.sh sources detect.sh + lib/install.sh from script-relative paths before any filesystem write                                                  | ✓ VERIFIED | init-local.sh:32 `source "$SCRIPT_DIR/detect.sh"`, :34 `source "$SCRIPT_DIR/lib/install.sh"`, :36 `source "$SCRIPT_DIR/lib/state.sh"` — before directory creation at :239                                  |
| 8   | update-claude.sh sources detect.sh via remote mktemp+trap pattern with soft-fail fallback (HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION exposed)                | ✓ VERIFIED | update-claude.sh:26 `DETECT_TMP=$(mktemp ...)`, :28 soft-fail `if curl ...; then source; else HAS_SP=false ... fi` (lines 36-42)                                                                           |
| 9   | scripts/lib/install.sh exists as sourced library exposing MODES, recommend_mode, compute_skip_set, backup_settings_once, print_dry_run_grouped           | ✓ VERIFIED | 226 lines; `MODES=("standalone" "complement-sp" "complement-gsd" "complement-full")`; all 5 functions defined; zero stdout on source; no `set -euo pipefail`                                               |
| 10  | manifest_version guard in init scripts hard-fails when manifest.json manifest_version != 2                                                               | ✓ VERIFIED | init-claude.sh:89-93 `jq -r '.manifest_version'` + exit 1 on mismatch; init-local.sh:65-69 same pattern                                                                                                    |
| 11  | Auto-recommendation matches detected plugins per recommend_mode (SP+GSD→complement-full; SP→complement-sp; GSD→complement-gsd; neither→standalone)       | ✓ VERIFIED | Test 6: all 4 combinations of HAS_SP/HAS_GSD produce correct recommend_mode output (4/4 PASS)                                                                                                              |
| 12  | --mode <name> bypasses interactive prompt; invalid mode strings exit non-zero with allowlist message                                                     | ✓ VERIFIED | `init-local.sh --mode bogus` → `ERROR: invalid --mode value: bogus\nValid modes: standalone complement-sp complement-gsd complement-full`, exit 1                                                          |
| 13  | --mode mismatch with auto-recommendation prints WARNING to stderr and proceeds                                                                           | ✓ VERIFIED | init-claude.sh:232-238 `warn_mode_mismatch()` function; invoked at :258 when `[[ -n "$MODE" ]] && [[ "$MODE" != "$recommended" ]]`                                                                         |
| 14  | init-local.sh respects same --mode + skip-list semantics; per-project state at .claude/toolkit-install.json                                              | ✓ VERIFIED | init-local.sh:62 `STATE_FILE=".claude/toolkit-install.json"` reassigned AFTER `source lib/state.sh`; state file confirmed written to `.claude/toolkit-install.json` after manual install                   |
| 15  | --dry-run prints grouped output with [INSTALL] green and [SKIP - conflicts_with:<plugin>] yellow + Total: footer; ANSI auto-disables when not a tty       | ✓ VERIFIED | Test 7 asserts all 6 conditions including ANSI-clean output when redirected to file (6/6 PASS)                                                                                                             |
| 16  | Skip-list computed via single jq filter over manifest.json; no parallel skip-list arrays in shell                                                        | ✓ VERIFIED | `compute_skip_set` in lib/install.sh uses single `jq --argjson skip ...` filter; both init scripts consume `$SKIP_LIST_JSON` via `jq -c --argjson skip` in the install loop                                |
| 17  | Re-run delegation: init-claude.sh exits 0 with delegation message when ~/.claude/toolkit-install.json exists and --force is absent                       | ✓ VERIFIED | init-claude.sh:110-113 explicit check + message + exit 0; init-local.sh:135-138 per-project equivalent                                                                                                     |
| 18  | Mode-change prompt fires when --mode <X> conflicts with recorded mode <Y>; --force-mode-change bypasses; under curl\|bash with no /dev/tty fails closed   | ✓ VERIFIED | init-claude.sh:118-140 and init-local.sh:143-165 complete block: jq reads recorded mode, compares, y/N prompt via `< /dev/tty 2>/dev/null` with fallback to `N` → `Aborted. ... exit 0`                    |
| 19  | setup-security.sh reads/merges/writes via python3 json.load + tempfile.mkstemp + os.replace (SAFETY-01)                                                  | ✓ VERIFIED | lib/install.sh:168-182 `tempfile.mkstemp(dir=...)` + `os.replace(tmp_path, settings_path)`; consumed by setup-security.sh:231                                                                              |
| 20  | setup-security.sh NEVER overwrites SP/GSD hook entries; destructive `matcher != 'Bash'` filter is removed (SAFETY-02)                                    | ✓ VERIFIED | `grep -cE "entry.get..matcher.. ?!= ?.Bash" scripts/setup-security.sh` → 0; `grep -cF "config['hooks']['PreToolUse'] = [" scripts/setup-security.sh` → 0; append-both policy via `foreign_entries + [tk]`  |
| 21  | SAFETY-04 invariant documented in setup-security.sh header                                                                                               | ✓ VERIFIED | setup-security.sh:9-14 full `SAFETY-04 INVARIANT:` comment block covering the 3 TK-owned subtrees                                                                                                          |

**Score:** 21/21 truths verified

### Required Artifacts

| Artifact                                        | Expected                                                                                                                                          | Status     | Details                                                                                        |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------- |
| `scripts/lib/install.sh`                        | Sourced library with MODES, recommend_mode, compute_skip_set, backup_settings_once, print_dry_run_grouped, merge_settings_python, merge_plugins_python | ✓ VERIFIED | 226 lines; all 7 functions defined; no `set -euo pipefail`; zero stdout on source              |
| `scripts/init-claude.sh`                        | Remote DETECT_TMP+LIB_INSTALL_TMP+MANIFEST_TMP block, flag parsing, select_mode, re-run delegation, mode-change prompt, manifest-driven install   | ✓ VERIFIED | 600+ lines; all wiring present at expected locations (lines 63-140, 200-259, 379-445)          |
| `scripts/init-local.sh`                         | SCRIPT_DIR-relative source, STATE_FILE override, mode flags, dry-run invocation, manifest-driven install loop, mode-change prompt                 | ✓ VERIFIED | 391 lines; STATE_FILE override at :62 AFTER `source lib/state.sh` at :36                       |
| `scripts/update-claude.sh`                      | Remote DETECT_TMP block with soft-fail fallback                                                                                                   | ✓ VERIFIED | Block at lines 26-43; HAS_SP/HAS_GSD/SP_VERSION/GSD_VERSION fallbacks present                  |
| `scripts/setup-security.sh`                     | SAFETY-04 header, source lib/install.sh, backup_settings_once + merge_*_python + restore-on-failure in Step 3/4, `_tk_owned: true` in JSON template | ✓ VERIFIED | Header :9-14; lib source :32-47; Step 3 refactored :218-247; Step 4 refactored :292-347        |
| `scripts/tests/test-modes.sh`                   | ≥60 lines; asserts 0/7/1/8 skip-counts + 4 recommend_mode combinations + bogus mode stderr                                                        | ✓ VERIFIED | 75 lines; 9/9 assertions PASS; Makefile Test 6                                                 |
| `scripts/tests/test-dry-run.sh`                 | ≥60 lines; md5 snapshot + grouped output + ANSI-clean assertions                                                                                  | ✓ VERIFIED | 90 lines; 6/6 assertions PASS; Makefile Test 7                                                 |
| `scripts/tests/test-safe-merge.sh`              | ≥100 lines; 3 scenarios 8a/8b/8c covering SAFETY-01..04                                                                                           | ✓ VERIFIED | 162 lines; 11/11 assertions PASS across 3 scenarios; Makefile Test 8                           |
| `scripts/tests/fixtures/manifest-v2.json`       | Fixture mirroring manifest v2 schema with 7 SP-conflict + 1 GSD-conflict                                                                          | ✓ VERIFIED | Present; yields deterministic 0/7/1/8 skip counts                                              |
| `Makefile`                                      | Tests 6, 7, 8 invocations after Test 5                                                                                                            | ✓ VERIFIED | Lines 69-77 contain all 3 test invocations in order                                            |

### Key Link Verification

| From                                          | To                                               | Via                                                                                                 | Status    |
| --------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- | --------- |
| scripts/init-claude.sh                        | scripts/detect.sh (remote)                       | `mktemp` + `curl -sSLf` + `source` + `trap rm`                                                      | ✓ WIRED   |
| scripts/init-claude.sh                        | scripts/lib/install.sh (remote)                  | `mktemp` + `curl -sSLf $REPO_URL/scripts/lib/install.sh` + `source`                                  | ✓ WIRED   |
| scripts/init-local.sh                         | scripts/detect.sh (local)                        | `source "$SCRIPT_DIR/detect.sh"` (line 32)                                                          | ✓ WIRED   |
| scripts/init-local.sh                         | scripts/lib/install.sh (local)                   | `source "$SCRIPT_DIR/lib/install.sh"` (line 34)                                                     | ✓ WIRED   |
| scripts/init-local.sh                         | scripts/lib/state.sh (local, with STATE_FILE override) | `source $SCRIPT_DIR/lib/state.sh` (line 36) then `STATE_FILE=".claude/toolkit-install.json"` (line 62) | ✓ WIRED   |
| scripts/update-claude.sh                      | scripts/detect.sh (remote, soft-fail)            | `curl -sSLf` with soft-fail fallback                                                                | ✓ WIRED   |
| scripts/init-claude.sh                        | compute_skip_set $MODE $MANIFEST_FILE            | Line 384 drives install loop                                                                        | ✓ WIRED   |
| scripts/init-claude.sh                        | print_dry_run_grouped                            | Line 388 in download_files() before exit 0                                                          | ✓ WIRED   |
| scripts/init-claude.sh                        | acquire_lock → write_state → release_lock        | Lines 402, 443, 444                                                                                 | ✓ WIRED   |
| scripts/init-local.sh                         | compute_skip_set / print_dry_run_grouped / acquire_lock / write_state / release_lock | Lines 246, 233, 247, 362, 363                                                                       | ✓ WIRED   |
| scripts/setup-security.sh                     | backup_settings_once → merge_settings_python → restore-on-failure | Step 3 lines 227-242; Step 4 lines 309-319 and 328-338                                              | ✓ WIRED   |
| scripts/lib/install.sh merge_settings_python  | settings.json                                    | `tempfile.mkstemp(dir=os.path.dirname(...))` + `os.replace` (atomic)                                 | ✓ WIRED   |

### Data-Flow Trace (Level 4)

| Artifact                    | Data Variable         | Source                                                    | Produces Real Data | Status     |
| --------------------------- | --------------------- | --------------------------------------------------------- | ------------------ | ---------- |
| init-local.sh install loop  | `$SKIP_LIST_JSON`     | `compute_skip_set $MODE $MANIFEST_FILE` (lib/install.sh)  | Yes (jq filter over manifest.json) | ✓ FLOWING  |
| init-local.sh install loop  | `$entry` (jq stream)  | `jq -c --argjson skip ... $MANIFEST_FILE`                 | Yes (real manifest paths)          | ✓ FLOWING  |
| init-claude.sh install loop | Same                  | Same, plus `$MANIFEST_FILE=$MANIFEST_TMP` from curl       | Yes                                | ✓ FLOWING  |
| print_dry_run_grouped       | `$line` (jq stream)   | `jq -c --argjson skip ... $manifest_path`                 | Yes — produces [INSTALL]/[SKIP] for all 54 manifest entries | ✓ FLOWING  |
| write_state in init-local   | `$INSTALLED_CSV / $SKIPPED_CSV` | Array populated during install loop                 | Yes — confirmed by reading `.claude/toolkit-install.json` after manual install | ✓ FLOWING  |
| merge_settings_python       | `config` (python)     | `json.load(open(settings_path))`                          | Yes — proven by Test 8a round-trip                         | ✓ FLOWING  |

### Behavioral Spot-Checks

| Behavior                                               | Command                                                                                                                 | Result                                        | Status   |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | -------- |
| Lint gate                                              | `make shellcheck`                                                                                                       | `✅ ShellCheck passed`                         | ✓ PASS   |
| Validate gate                                          | `make validate`                                                                                                         | `✅ All templates valid` + `✅ Manifest schema valid` | ✓ PASS   |
| Full test suite                                        | `make test`                                                                                                             | Tests 1–8 all pass (37 assertions total)       | ✓ PASS   |
| recommend_mode SP+GSD                                  | `HAS_SP=true HAS_GSD=true recommend_mode`                                                                                | `complement-full`                              | ✓ PASS   |
| compute_skip_set complement-sp / standalone           | `compute_skip_set complement-sp manifest.json \| jq length` / `compute_skip_set standalone manifest.json \| jq length`  | `7` / `0`                                      | ✓ PASS   |
| Zero stdout on source                                  | `out=$(source scripts/lib/install.sh 2>&1); [ -z "$out" ]`                                                              | OK                                             | ✓ PASS   |
| Errexit not altered                                    | `grep -c "set -euo pipefail" scripts/lib/install.sh`                                                                    | `0`                                            | ✓ PASS   |
| init-local.sh --dry-run complement-sp                  | `bash init-local.sh --dry-run --mode complement-sp` in empty dir                                                        | 47 INSTALL / 7 SKIP / 1 Total; exit 0; no `.claude/` created | ✓ PASS   |
| init-local.sh --dry-run complement-full                | `bash init-local.sh --dry-run --mode complement-full`                                                                   | `Total: 47 install, 7 skip`                    | ✓ PASS   |
| init-local.sh --dry-run standalone                     | `bash init-local.sh --dry-run --mode standalone`                                                                        | `Total: 54 install, 0 skip`                    | ✓ PASS   |
| Invalid mode rejection                                 | `bash init-local.sh --mode bogus`                                                                                       | `ERROR: invalid --mode value: bogus` + exit 1  | ✓ PASS   |
| Real install complement-sp skips SP-conflict files     | Manual run; check files on disk                                                                                         | 7/7 SP-conflict files correctly NOT installed  | ✓ PASS   |
| Real install standalone installs SP-conflict files     | Manual run; check files on disk                                                                                         | All checked SP-conflict files installed        | ✓ PASS   |
| State file written per-project                         | `cat .claude/toolkit-install.json` after install                                                                        | Valid JSON with `mode: "standalone"`, `detected.superpowers.present: true` | ✓ PASS   |
| merge_settings_python preserves foreign hook           | Manual: seed settings.json with `/sp/pre-bash.sh`, merge TK hook                                                        | `[0]=/sp/...`, `[1]={_tk_owned, /tk/...}`      | ✓ PASS   |
| TK_TEST_INJECT_FAILURE leaves file unchanged           | Manual: backup, merge with failure flag, compare MD5                                                                    | MD5 unchanged (atomic write never reached)     | ✓ PASS   |

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                                    | Status      | Evidence                                                                   |
| ----------- | ----------- | -------------------------------------------------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------- |
| DETECT-05   | 03-01       | Both init-claude.sh and update-claude.sh source detect.sh; remote via mktemp                                    | ✓ SATISFIED | init-claude.sh:63, init-local.sh:32, update-claude.sh:26 all source detect.sh |
| MODE-01     | 03-02       | init-claude.sh recognizes 4 modes                                                                              | ✓ SATISFIED | MODES array + --mode flag case + allowlist + select_mode prompt            |
| MODE-02     | 03-02       | Reads detection results and recommends matching mode                                                           | ✓ SATISFIED | recommend_mode() over HAS_SP/HAS_GSD; Test 6 covers 4/4 combinations       |
| MODE-03     | 03-02       | User can override via prompt or `--mode <name>`                                                                | ✓ SATISFIED | select_mode() interactive + `--mode` flag with allowlist validation        |
| MODE-04     | 03-02       | Skip-list computed by jq filtering manifest.json conflicts_with                                                | ✓ SATISFIED | compute_skip_set uses single jq filter; Test 6 asserts 0/7/1/8 counts      |
| MODE-05     | 03-02       | init-local.sh respects same mode + skip-list                                                                   | ✓ SATISFIED | init-local.sh sources same lib + STATE_FILE override; skip loop identical  |
| MODE-06     | 03-02       | --dry-run prints [INSTALL]/[SKIP] preview without filesystem touch                                             | ✓ SATISFIED | print_dry_run_grouped + Test 7 md5 snapshot proves zero writes             |
| SAFETY-01   | 03-03       | python3 json.load + json.dump to temp file + atomic mv                                                         | ✓ SATISFIED | tempfile.mkstemp + os.replace in merge_settings_python                     |
| SAFETY-02   | 03-03       | Never overwrites foreign hooks; merges per-key                                                                 | ✓ SATISFIED | foreign_entries partition by _tk_owned; destructive filter removed         |
| SAFETY-03   | 03-03       | Backup with timestamp before mutation; restore from backup on failure                                          | ✓ SATISFIED | backup_settings_once + Step 3/4 restore-on-failure wrap; Test 8b/8c        |
| SAFETY-04   | 03-03       | Documented invariant: TK only edits its own permissions.deny / hooks.PreToolUse[*] / env block                 | ✓ SATISFIED | Header comment block at setup-security.sh:9-14                             |

All 11 declared requirement IDs SATISFIED. No orphaned requirements (REQUIREMENTS.md lists exactly these 11 IDs for Phase 3).

### Anti-Patterns Found

No blockers or warnings introduced by Phase 3. Scanned setup-security.sh, init-claude.sh, init-local.sh, update-claude.sh, lib/install.sh, tests/*.sh for TODO/FIXME/placeholder/stub patterns in Phase 3 changes. The historical destructive pattern (`entry.get('matcher') != 'Bash'`) at setup-security.sh:228-230 is removed (grep count = 0). Only remaining TODO marker in lib/install.sh was the "TODO: Plan 03-02" stub line, which was deleted in Plan 03-02 Task 2.

| File                    | Line    | Pattern                 | Severity | Impact                                                                                      |
| ----------------------- | ------- | ----------------------- | -------- | ------------------------------------------------------------------------------------------- |
| —                       | —       | None                    | —        | None                                                                                        |

### Human Verification Required

Automated checks confirm the code paths are wired correctly. These items still need human testing because they depend on real network/plugin/tty interactions that the test harness cannot reproduce end-to-end:

#### 1. Remote curl|bash install against actual github.com

**Test:** On a clean machine with `superpowers` installed at `~/.claude/plugins/cache/superpowers`, run:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/init-claude.sh) --dry-run
```

**Expected:** Installer downloads detect.sh + lib/install.sh + manifest.json into mktemp files, prints `Detected plugins: OK superpowers (<ver>)`, recommends `complement-sp`, produces grouped dry-run output, exits 0 without writing `~/.claude/`.

**Why human:** Needs real GitHub raw content + real SP plugin directory on disk. The test harness runs locally against the working tree.

#### 2. Interactive mode prompt under a real tty

**Test:** On a machine with SP+GSD detected, run:
```bash
bash scripts/init-claude.sh
```
…from a regular terminal (NOT piped to file or redirected). Accept the recommendation, then re-run and override with choice `1` (standalone).

**Expected:** First run: `Detected plugins: OK superpowers (...) OK get-shit-done (...)` → `Recommended: complement-full` → empty input defaults to complement-full. Second run: typing `1` selects standalone and `warn_mode_mismatch` does NOT fire (the prompt itself sets MODE, so it's not a "mismatch" path).

**Why human:** `select_mode()` calls `read -r < /dev/tty`. Test 7 already verifies the non-tty fallback to `recommend_mode`, but interactive keypress behavior cannot be exercised non-interactively without a pty emulator. ROADMAP success criterion #1 hinges on this.

#### 3. Mode-change prompt (D-42) under a real tty

**Test:** With `~/.claude/toolkit-install.json` recording mode=standalone, run:
```bash
bash scripts/init-claude.sh --force --mode complement-sp
```
from a real terminal. Press `y`. Then run again and press ENTER (empty → N).

**Expected:**
- First run: `Switching standalone -> complement-sp will rewrite the install. Backup current state and proceed? [y/N]:` → `y` → creates `.bak.<ts>` of toolkit-install.json, proceeds with install.
- Second run: same prompt → ENTER → `Aborted. Pass --force-mode-change to bypass the prompt under curl|bash.` → exit 0, no changes.

**Why human:** Reads from `/dev/tty`; automated tests cannot press keys.

#### 4. Real setup-security.sh against a settings.json with SP+GSD hooks

**Test:** On a dev machine where `~/.claude/settings.json` already contains SP's and GSD's Bash hooks, run:
```bash
bash scripts/setup-security.sh
```

**Expected:** After completion, `jq '.hooks.PreToolUse | length' ~/.claude/settings.json` == 3 (SP at [0], GSD at [1], TK at [2] with `_tk_owned: true`). A `.bak.<ts>` file exists next to settings.json. Running `jq '.hooks.PreToolUse[0].hooks[0].command' ~/.claude/settings.json` returns SP's unchanged command. This proves ROADMAP success criterion #4 end-to-end.

**Why human:** Test 8a uses a seeded scratch settings.json. On the actual dev machine, the SP/GSD hook entries may have additional fields (e.g., extra matchers) that only manual inspection can confirm are preserved.

#### 5. Visual inspection of ANSI colors in real terminal

**Test:** Run `bash scripts/init-local.sh --dry-run --mode complement-sp` from a real terminal (no redirection).

**Expected:** `[INSTALL]` lines appear in green, `[SKIP - conflicts_with:superpowers]` lines appear in yellow. Test 7 proves the ANSI auto-disable path; the positive-colors path is not asserted by tests.

**Why human:** Visual color perception; terminal-specific rendering.

### Gaps Summary

None. All automated verification passes 21/21 must-haves. Five items remain that require human validation — these are the real-world integration paths (remote curl|bash, interactive prompts under a real tty, dev-machine co-existence with SP+GSD) that cannot be exercised in the test harness. They are not gaps in the code; they are verification coverage gaps that a human must close before the phase is considered fully validated.

---

_Verified: 2026-04-18T13:21:23Z_
_Verifier: Claude (gsd-verifier)_
