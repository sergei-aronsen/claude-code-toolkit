---
phase: 38
plan: 03
subsystem: wizard-dispatch
tags: [tests, hermetic, wizard, scope-routing, project-secrets, defer-secrets, summary-printer, defense-in-depth, disp-01, disp-02, disp-03, disp-04, test-02]
requires:
  - mcp_wizard_run-project-scope-branch (plan 38-01)
  - deferred-queue-4-tuple (plan 38-01)
  - install.sh-per-scope-summary (plan 38-02)
  - install.sh-two-block-dispatch (plan 38-02)
  - scripts/lib/project-secrets.sh API (Phase 37)
provides:
  - test-mcp-wizard-dispatch-coverage
  - tk-project-root-test-seam-validation
  - mock-claude-scope-parser
  - awk-extracted-summary-block-harness
affects:
  - phase 39 (TUI per-row scope toggle test extension — same harness pattern)
  - regression net for the entire Phase 38 wizard dispatch contract
tech-stack:
  added: []
  patterns:
    - "Cross-platform 0600 mode check (BSD `stat -f %Mp%Lp` + GNU `stat -c %a` fallback) — copied verbatim from test-project-secrets.sh:52-60"
    - "Filesystem fingerprint negative-assertion idiom (PRE_HASH/POST_HASH via `shasum`) for `X UNTOUCHED` cross-store claims"
    - "TK_PROJECT_ROOT test seam under SANDBOX (mktemp absolute path, hermetic — no $HOME mutation)"
    - "Mock claude binary `--scope` parser — emits dedicated `scope:<value>` line for grep-friendly assertions"
    - "awk-extracted install.sh summary `if`-block run inside hermetic harness (color vars + FAILED_COUNT pre-set; SHELL/_VERSION cleared so rc-write cannot fire)"
    - "Bash 3.2-compat `&& rc=0 || rc=$?` capture pattern for non-zero exit codes under `set -euo pipefail`"
    - "`unset -f` + re-source pattern to swap a sibling-lib function and restore for downstream tests"
key-files:
  created: []
  modified:
    - scripts/tests/test-mcp-wizard.sh
decisions:
  - "D-17 honored verbatim — existing test-mcp-wizard.sh extended IN PLACE (no new test files); PASS 21 → 52 (+31 assertions, far exceeding the ≥6 floor)"
  - "D-18 honored — TEST-03 closed with no file changes; test-mcp-secrets.sh PASS=11 stayed green throughout (shared `_mcp_validate_value` boundary preserved per Phase 37 D-16). Marked complete as `shared validator boundary preserved; no new file changes`."
  - "D-19 honored — three existing seams reused (TK_MCP_TTY_SRC, TK_MCP_CLAUDE_BIN, TK_MCP_DEFERRED_QUEUE); ONE new seam exercised (TK_PROJECT_ROOT) — always set to a `$SANDBOX/myproj` mktemp absolute path"
  - "D-20 honored — mock claude binary extended to emit a dedicated `scope:<value>` line; existing assertions that matched `scope user`/`scope local` against the `argv:` line stay green (both `argv:` and `scope:` lines coexist)"
  - "Bash 3.2 compat: T9/T10/T12 use `&& rc=0 || rc=$?` capture (the plan's prose used the simpler `rc=$?` form which fails under `set -euo pipefail` for non-zero exits — Rule 3 auto-fix during execution)"
  - "T11 awk extraction wraps the install.sh block inside a `_summary_block` function so the `exit 0` at the original line ~917 cannot terminate the test harness; `unset ZSH_VERSION BASH_VERSION SHELL` prevents the user-scope shell-rc auto-source from mutating the user's $HOME during the harness run (defense-in-depth on the test side)"
  - "T7 happy-path also serves as the substitution-form positive assertion — `assert_contains 'CONTEXT7_API_KEY=${CONTEXT7_API_KEY}'` literal `$/{/}` characters present, paired with `assert_not_contains \"tk_proj_secret_ctx7\"` against the same argv content (call-site contract from plan 38-01 D-07)"
metrics:
  duration: ~30 minutes
  completed: 2026-05-04T00:00:00Z
  tasks_completed: 3
  files_created: 0
  files_modified: 1
  commits: 3
---

# Phase 38 Plan 03: Test Extension Summary

**One-liner:** `scripts/tests/test-mcp-wizard.sh` extended in place from PASS=21 to PASS=52 (+31 net new assertions across DISP-01/02/03/04 and Defense-in-depth) — closes TEST-02 with cross-store negative assertions (filesystem-fingerprint idiom), 4-field deferred-queue tuple verification, awk-extracted install.sh summary harness with D-16 ordering check, and a mocked-render call-site refusal test that proves `mcp_wizard_run` aborts BEFORE invoking claude when a literal value somehow lands in the env block. test-mcp-secrets.sh PASS=11 + test-project-secrets.sh PASS=42 baselines stay byte-identical (TEST-03 boundary preserved without source changes — D-18 closure).

## Final PASS / FAIL Counts

| Test file | Before plan | After plan | FAIL | Notes |
|---|---|---|---|---|
| `scripts/tests/test-mcp-wizard.sh` | 21 | **52** | 0 | +31 assertions across T7-T12; double-run safe |
| `scripts/tests/test-mcp-secrets.sh` | 11 | **11** | 0 | TEST-03 boundary preserved (no source changes — D-18) |
| `scripts/tests/test-project-secrets.sh` | 42 | **42** | 0 | Phase 37 cross-impact gate: untouched |
| `make shellcheck` | green | **green** | 0 | No new SC warnings |

The plan's `<success_criteria>` PASS≥20 floor is exceeded by +32 (52 ≥ 20).
The plan's `<acceptance_criteria>` PASS≥30 stretch target is also met (52 ≥ 30).

## Output

Modified exactly one file: `scripts/tests/test-mcp-wizard.sh` (186 → 525 lines). 341 insertions, 1 deletion across 3 atomic commits. No new files. The Phase 37 lib API + Phase 38 plans 01/02 contracts are exercised but not modified.

## Files Modified

### `scripts/tests/test-mcp-wizard.sh`

| Region | Before | After | Purpose |
|---|---|---|---|
| Helpers (lines 47-58) | n/a | `mode_is_0600()` cross-platform mode check | Copied verbatim from test-project-secrets.sh:52-60 — DISP-01/03 mode-0600 assertions |
| Sandbox setup (lines 67-72) | n/a | `PROJECT="$SANDBOX/myproj"; mkdir -p "$PROJECT"` | TK_PROJECT_ROOT seam target — hermetic project dir under SANDBOX |
| Mock claude binary (lines 78-97) | argv + env capture | + `scope:<value>` parsed line | DISP-01/02 grep-friendly scope assertions; existing T2/T2b/T2c `scope user/local` matchers unchanged (`argv:` line still carries them) |
| Project-secrets explicit source (lines 232-235) | n/a | `command -v project_secrets_write_env \|\| source ...` guard | Defends against Bash startup ordering — guarantees the four Phase 37 fns are visible before T7+ |
| T7 (DISP-01) (lines 237-285) | n/a | 8 assertions | Project-scope happy path: real value → `<project>/.env` (mode 0600), `.gitignore` guard, `${VAR}` form in argv (literal absent), mcp-config.env BYTE-IDENTICAL fingerprint, mock parsed `--scope project` |
| T8 (DISP-02) (lines 287-330) | n/a | 5 assertions | User-scope no-regression: real value → `mcp-config.env`, `env KEY=V` exec wrapper carries literal value (v4.9 contract), `<project>/.env` UNTOUCHED |
| T9 (DISP-03) (lines 334-381) | n/a | 6 assertions | defer+project: rc=3, 4-field tuple, `project` as 4th, blank stub in `<project>/.env`, `.gitignore` guard fired, stub mode 0600 |
| T10 (DISP-03 user-scope back-compat) (lines 385-410) | n/a | 3 assertions | defer+user: rc=3, 4-field tuple with `user` as 4th, stub in `mcp-config.env` (v4.9 path UNCHANGED) |
| T11 (DISP-04) (lines 414-471) | n/a | 6 assertions | awk-extracted install.sh summary block; single project row → 4 D-14 phrases + user-copy ABSENT; mixed user+project → D-16 ordering via `grep -n` line-number comparison |
| T12 (Defense-in-depth) (lines 474-510) | n/a | 3 assertions | mocked `project_secrets_render_mcp_env_block` returns poisoned literal-value JSON → wizard rc=1, exact-phrase `refusing to write literal value` stderr, claude.argv NEVER created |

### Public Test Contract (extended)

| Scenario | Returned Behavior |
|---|---|
| `TK_MCP_SCOPE=project + TK_PROJECT_ROOT + TK_MCP_TTY_SRC` (real value) | T7: `<project>/.env` 0600 + `.gitignore` + claude argv `${VAR}` form (literal absent) + mcp-config.env fingerprint identical |
| `TK_MCP_SCOPE=user + TK_MCP_TTY_SRC` (real value) | T8: `mcp-config.env` real value + `env:CTX=<literal>` argv line (env-exec wrapper) + `<project>/.env` does not exist |
| `TK_MCP_DEFER_SECRETS=1 + TK_MCP_SCOPE=project + TK_PROJECT_ROOT + TK_MCP_DEFERRED_QUEUE` | T9: rc=3 + queue 4-tuple `name\tkeys\targs\tproject` + blank `KEY=` stub in `<project>/.env` + `.gitignore` guard fired + stub mode 0600 |
| `TK_MCP_DEFER_SECRETS=1 + TK_MCP_SCOPE=user + TK_MCP_DEFERRED_QUEUE` | T10: rc=3 + queue 4-tuple with `user` as 4th + blank stub in `mcp-config.env` (v4.9 path UNCHANGED) |
| Synthetic queue with project-scope row → install.sh summary `if`-block (awk-extracted) | T11: yellow heading `Some project-scope MCPs need API keys finished:` + step 1 `Open <project>/.env` + step 2 `.gitignore already includes .env` + per-key `CONTEXT7_API_KEY=<your-key>` line; user-scope copy ABSENT |
| Synthetic queue with mixed user+project rows → same harness | T11 D-16: user-scope heading line-number < project-scope heading line-number (ordering invariant) |
| Mocked render emits poisoned literal-value JSON | T12: rc=1 + stderr `refusing to write literal value` + `$SANDBOX/claude.argv` absent (claude never invoked) |

## Verification Performed

### Automated regression (all gates green)

```text
test-mcp-wizard.sh:    Results: 52 passed, 0 failed   (was 21)
test-mcp-secrets.sh:   Results: 11 passed, 0 failed   (TEST-03 boundary preserved)
test-project-secrets.sh: Results: 42 passed, 0 failed (Phase 37 cross-impact gate)
make shellcheck:       ✅ ShellCheck passed
make check:            EXIT=0 (lint + validate clean)
```

### Double-run hermetic invariant

```bash
$ bash scripts/tests/test-mcp-wizard.sh > /dev/null 2>&1 && bash scripts/tests/test-mcp-wizard.sh 2>&1 | tail -2
=== Results: 52 passed, 0 failed ===
```

Both consecutive runs exit 0 — the SANDBOX trap, mock claude binary, and `unset -f` + re-source restoration of `project_secrets_render_mcp_env_block` (T12) leave no state behind.

### Acceptance-criteria substring greps (all PASS)

```text
$ grep -F 'mode_is_0600()' scripts/tests/test-mcp-wizard.sh                                # FOUND
$ grep -F 'PROJECT="$SANDBOX/myproj"' scripts/tests/test-mcp-wizard.sh                     # FOUND
$ grep -F "printf 'scope:%s\\n'" scripts/tests/test-mcp-wizard.sh                          # FOUND
$ grep -F 'T7 (DISP-01)' scripts/tests/test-mcp-wizard.sh                                  # FOUND
$ grep -F 'T8 (DISP-02)' scripts/tests/test-mcp-wizard.sh                                  # FOUND
$ grep -F 'T9 (DISP-03)' scripts/tests/test-mcp-wizard.sh                                  # FOUND
$ grep -F 'CONTEXT7_API_KEY=${CONTEXT7_API_KEY}' scripts/tests/test-mcp-wizard.sh          # FOUND
$ grep -F 'UNTOUCHED in project-scope flow' scripts/tests/test-mcp-wizard.sh               # FOUND
$ grep -F 'UNTOUCHED in user-scope flow' scripts/tests/test-mcp-wizard.sh                  # FOUND
$ grep -F '4 tab-separated fields' scripts/tests/test-mcp-wizard.sh                        # FOUND
$ grep -F 'T11 (DISP-04)' scripts/tests/test-mcp-wizard.sh                                 # FOUND
$ grep -F 'T12 (Defense-in-depth)' scripts/tests/test-mcp-wizard.sh                        # FOUND
$ grep -F 'Some project-scope MCPs need API keys finished:' scripts/tests/test-mcp-wizard.sh # FOUND
$ grep -F '.gitignore already includes .env' scripts/tests/test-mcp-wizard.sh              # FOUND
$ grep -F 'D-16' scripts/tests/test-mcp-wizard.sh                                          # FOUND
$ grep -F 'BEFORE project-scope' scripts/tests/test-mcp-wizard.sh                          # FOUND
$ grep -F 'plain-literal-not-substitution' scripts/tests/test-mcp-wizard.sh                # FOUND
$ grep -F 'refusing to write literal value' scripts/tests/test-mcp-wizard.sh               # FOUND
$ grep -F 'unset -f project_secrets_render_mcp_env_block' scripts/tests/test-mcp-wizard.sh # FOUND
```

## Threat Mitigations (T-38-09..T-38-12)

| Threat ID | Disposition | Test ID | Assertion phrase |
|---|---|---|---|
| T-38-09 (test contamination — hermetic SANDBOX) | mitigate | harness setup (lines 62-72) | `mktemp -d /tmp/mcp-wizard.XXXXXX` + `trap 'rm -rf "$SANDBOX"' EXIT` + per-test `rm -f "$SANDBOX/claude.argv"` and `rm -rf "$PROJECT"` boundaries before each project-scope test. No `$HOME` mutation under any test path (T11 harness explicitly `unset SHELL ZSH_VERSION BASH_VERSION` to disable the install.sh shell-rc auto-source). |
| T-38-10 (defense-in-depth bypass at wizard call site) | mitigate | T12 | mocked render returns poisoned literal-value JSON → asserts `DEF_RC == 1` AND stderr contains `refusing to write literal value` AND `[[ -f "$SANDBOX/claude.argv" ]]` is false (claude was NEVER invoked — call-site validate ran BEFORE claude). Restoration via `unset -f` + re-source for double-run safety. |
| T-38-11 (information disclosure — secret leak to stdout) | mitigate | T7 + existing T4 | T7's `assert_not_contains "tk_proj_secret_ctx7" "$ARGV_CONTENT"` covers the project-scope wizard exec wrapper (no literal in argv); existing T4 covers the generic stdout/stderr hidden-input contract for both wizard exec wrappers. |
| T-38-12 (phrase drift in install.sh summary) | mitigate | T11 | greps four exact phrases verbatim against the awk-extracted block: `Some project-scope MCPs need API keys finished:`, `Open <project>/.env`, `.gitignore already includes .env`, `CONTEXT7_API_KEY=<your-key>`. Plus `assert_not_contains "Open ~/.claude/mcp-config.env"` for negative coverage. Any future drift in plan 38-02's install.sh edits breaks T11 — cross-plan regression gate. |

## Decisions Honored Verbatim (D-17..D-20)

| Decision | Status | Evidence |
|---|---|---|
| D-17 (extend test-mcp-wizard.sh by ≥6 assertions covering DISP-01/02/03/defense-in-depth) | honored — far exceeded | +31 net new assertions (DISP-01: 8, DISP-02: 5, DISP-03 project: 6, DISP-03 user: 3, DISP-04: 6, Defense-in-depth: 3) |
| D-18 (TEST-03 SEC-06 — shared validator boundary; no refactor needed) | honored | test-mcp-secrets.sh PASS=11 stayed byte-identical; no source changes to scripts/lib/mcp.sh or scripts/lib/project-secrets.sh from this plan; closed as "shared validator boundary preserved; no new file changes" |
| D-19 (test seams: TK_MCP_TTY_SRC, TK_MCP_CLAUDE_BIN, TK_PROJECT_ROOT) | honored | All three seams set hermetically: TTY fixtures via `printf > $SANDBOX/tty.fix.*`; CLAUDE_BIN points at the SANDBOX-controlled mock; TK_PROJECT_ROOT always set to `$SANDBOX/myproj` (absolute path under mktemp) |
| D-20 (mock claude binary captures `--scope`, `--env`, install_args distinctly) | honored | Mock at lines 78-97 parses `--scope <value>` via a `_prev`-tracking loop and emits a dedicated `scope:<value>` line. The original `argv:` line and `env:CTX=...` / `env:SENTRY=...` lines coexist for backward compatibility with T1-T6 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `set -euo pipefail` rc-capture pattern**

- **Found during:** Task 2 (T9 silently aborted the script when `mcp_wizard_run` returned rc=3)
- **Issue:** The plan's prose for T9/T10 used the simpler form `mcp_wizard_run ... ; DEFER_RC=$?`. Under `set -euo pipefail` (line 9), the non-zero exit aborted the script BEFORE the `DEFER_RC=$?` assignment ran — Summary block never reached, `Results:` line missing from output.
- **Fix:** Switched both T9 and T10 to the Bash 3.2-compat capture idiom `DEFER_RC=0; cmd ... || DEFER_RC=$?`. The same pattern was already used in T6 (line 211 `(...) || rc=$?`) so this is project-established convention. T12 also uses the idiom (`DEF_RC=0; ERR=$(...) || DEF_RC=$?`).
- **Files modified:** `scripts/tests/test-mcp-wizard.sh` (Tasks 2 + 3)
- **Commits:** 92bd530 + 9ac4469

This deviation is mechanical (Rule 3 — blocking issue prevented the script from completing). The plan's `<read_first>` references the existing T6 idiom but T6's outer `(...)` subshell-with-`|| rc=$?` is what makes that pattern work; the plan's prose for T9/T10 dropped the `|| rc=$?` half. Auto-fixed during execution.

**2. [Rule 3 - Blocking] T11 awk-extracted block needed harness-side hardening**

- **Found during:** Task 3 verification
- **Issue:** The install.sh `if`-block (lines 801-912) ends with `unset _user_rows _project_rows` followed by an `if [[ $FAILED_COUNT -gt 0 ]]; then exit 1; fi; exit 0` cleanup tail (lines 914-917 outside the awk-captured region — but the block also references shell-rc-write helpers (`_shell_rc`, `_rc_added`) that fire when `SHELL=*zsh*` matches, which would mutate `$HOME/.zshrc` under the test harness if a real shell var leaked through.
- **Fix:** The harness wrapper script (a) wraps the awk-extracted body inside a `_summary_block()` function so any future `exit` inside the block is contained; (b) prepends `unset ZSH_VERSION BASH_VERSION SHELL` so neither the zsh nor bash branch matches → `_shell_rc` stays empty → the rc-write `>>` cannot fire (HOME mutation impossible under T11); (c) sets `FAILED_COUNT=0` defensively. Plan prose covered (a) and (b) but the explicit `FAILED_COUNT` reset was added during execution as belt-and-braces against any future install.sh edit landing inside the awk-captured region.
- **Files modified:** `scripts/tests/test-mcp-wizard.sh` (Task 3 — T11 harness setup)
- **Commit:** 9ac4469

### No Other Deviations

D-17..D-20 honored verbatim. All threat-model phrase contracts (`refusing to write literal value`, `Some project-scope MCPs need API keys finished:`, `.gitignore already includes .env`, `Open <project>/.env`, `CONTEXT7_API_KEY=<your-key>`) preserved.

## Self-Check: PASSED

- File `scripts/tests/test-mcp-wizard.sh` exists (525 lines after changes — was 186).
- Three commits exist in git log:
  - `71c6d57` test(38-03): extend test-mcp-wizard.sh harness with mode_is_0600 + TK_PROJECT_ROOT seam
  - `92bd530` test(38-03): add DISP-01/02/03 wizard dispatch assertions (T7-T10)
  - `9ac4469` test(38-03): add DISP-04 summary printer + defense-in-depth assertions (T11-T12)
- `bash scripts/tests/test-mcp-wizard.sh` exits 0 with `=== Results: 52 passed, 0 failed ===`
- Double-run safe: two consecutive runs both exit 0 with PASS=52
- `bash scripts/tests/test-mcp-secrets.sh` exits 0 with `=== Results: 11 passed, 0 failed ===` (TEST-03 boundary preserved)
- `bash scripts/tests/test-project-secrets.sh` exits 0 with `=== Results: 42 passed, 0 failed ===` (Phase 37 cross-impact gate)
- `make shellcheck` exits 0 with `✅ ShellCheck passed`
- `make check` exits 0 (lint + validate clean)
- All 19 acceptance-criteria substring greps return matches (Tasks 1, 2, 3 combined)

## Threat Flags

None. The new test surface stays inside the documented SANDBOX-rooted boundary (`mktemp -d /tmp/mcp-wizard.XXXXXX` + EXIT trap cleanup). T11's awk-extracted summary harness defensively `unset SHELL ZSH_VERSION BASH_VERSION` to prevent any rc-write leak to `$HOME` (T-38-09 mitigation honored on the test side). T12's `unset -f` + re-source restoration ensures the mocked function does not persist across tests or runs (double-run safety + cross-test isolation).

## Deferred Items

- **Phase 39:** TUI per-row scope toggle (TUI-SCOPE-01..05) — will export `TK_MCP_SCOPE` per row before invoking `mcp_wizard_run`, exercising the same project-scope branch this plan's T7-T10 cover. The mock claude binary's `scope:<value>` parser line will likely be reused as-is.
- **Phase 40:** Uninstall secret-cleanup prompts — orthogonal to this plan; tests will use a different harness.
- **Phase 41:** Distribution / docs — manifest.json bump, CHANGELOG entry; no test changes.
