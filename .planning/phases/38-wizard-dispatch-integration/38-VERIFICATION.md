---
phase: 38-wizard-dispatch-integration
verified: 2026-05-05T18:23:16Z
status: passed
score: 14/14 must-haves verified
must_haves_total: 14
must_haves_passed: 14
requirements_total: 6
requirements_passed: 6
overrides_applied: 0
---

# Phase 38: Wizard Dispatch Integration — Verification Report

**Phase Goal:** `mcp_wizard_run` learns per-MCP scope routing — when caller exports `TK_MCP_SCOPE=project`, wizard collects keys via existing v4.6 hidden-input prompt loop, writes real values to `<project>/.env` via `project_secrets_write_env`, ensures `.env` is in `.gitignore` once, and invokes `claude mcp add --scope project ...` with env block as `${VAR}` substitution form (NEVER literal values). When `TK_MCP_SCOPE=user` (or unset), v4.6/v4.9 behavior preserved verbatim. Defer-secrets path extended for project scope.

**Verified:** 2026-05-05T18:23:16Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria + PLAN must_haves)

| #   | Truth                                                                                                                          | Status     | Evidence                                                                                                                                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------ | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Project-scope wizard writes real values to `<project>/.env` (mode 0600), never to `~/.claude/mcp-config.env`                   | VERIFIED   | Smoke test confirmed: `.env` contained `CONTEXT7_API_KEY=tk_real_secret`, mode `0600`. mcp.sh:891 calls `project_secrets_write_env "$_project_root"`. T7 in test-mcp-wizard.sh asserts both invariants. |
| 2   | Project-scope wizard appends `.env` to `<project>/.gitignore` once via `project_secrets_ensure_gitignore` (sentinel `_gi_done`) | VERIFIED   | Smoke test: `.gitignore` contains exact `.env` line plus toolkit comment. mcp.sh:773 + mcp.sh:886 gated by `_gi_done` sentinel (mcp.sh:708, 776, 889).                                              |
| 3   | Project-scope `claude mcp add` carries `-e KEY=${KEY}` substitution form — never literal values                                | VERIFIED   | Smoke test argv: `mcp add -e CONTEXT7_API_KEY=${CONTEXT7_API_KEY} --scope project ...` (literal `tk_real_secret` absent). mcp.sh:943 builds `_env_flags+=( "-e" "${_ek}=\${${_ek}}" )`.            |
| 4   | User-scope (TK_MCP_SCOPE=user/unset): wizard byte-identical to v4.6/v4.9 — keys to `mcp-config.env`, `env KEY=V claude mcp add` exec wrapper, no `<project>/.env` created | VERIFIED   | Smoke test: `mcp-config.env=CONTEXT7_API_KEY=user_secret`, argv contains `--scope user` + `env_CTX=user_secret`, `<project>/.env` absent. mcp.sh:899 + mcp.sh:947 preserved. T8 asserts.            |
| 5   | Defer-secrets + project-scope pre-creates blank stub entries in `<project>/.env` (not mcp-config.env), `.gitignore` guard fires once | VERIFIED   | mcp.sh:766-799: project-scope mirror. T9 in test-mcp-wizard.sh asserts `CONTEXT7_API_KEY=` blank stub + .gitignore guard + mode 0600.                                                              |
| 6   | TK_MCP_DEFERRED_QUEUE rows have 4 tab-separated fields (name, keys, install_args, scope) so install.sh dispatches per-scope    | VERIFIED   | mcp.sh:752 `printf '%s\t%s\t%s\t%s\n' ...`. T9 asserts `NF==4` and `$4==project`. install.sh:809 reads exactly 4 fields.                                                                          |
| 7   | Defense-in-depth: `project_secrets_validate_mcp_env_block` called BEFORE every `claude mcp add` in project-scope branch — refusal returns rc=1 | VERIFIED   | mcp.sh:929 calls validate before claude invocation at mcp.sh:945. T12 mocks render to emit literal value, asserts rc=1 + stderr `refusing to write literal value` + claude.argv NEVER created.    |
| 8   | Lazy sibling-source guard for project-secrets.sh in mcp.sh — if lib missing, wizard fails distinctly (no silent fallback)      | VERIFIED   | mcp.sh:88-95 lazy guard with `_MCP_SOURCING_PROJECT_SECRETS` re-entrancy sentinel. mcp.sh:713-715 emits `✗ mcp_wizard_run: project-scope requested but scripts/lib/project-secrets.sh not loaded`. |
| 9   | install.sh post-install summary reads 4-field deferred queue tuple (name, keys, install_args, scope)                           | VERIFIED   | install.sh:809 `while IFS=$'\t' read -r d_name d_keys d_args d_scope`.                                                                                                                              |
| 10  | Pre-v5.0 3-field rows fall back to scope=user via empty-field guard                                                            | VERIFIED   | install.sh:812 `[[ -z "${d_scope:-}" ]] && d_scope="user"` (mirrors mcp.sh:674 default).                                                                                                            |
| 11  | User-scope-only queue prints existing v4.9 summary block byte-identically (Open `~/.claude/mcp-config.env`, shell-rc auto-source) | VERIFIED   | install.sh:852 user-scope step 1 phrase preserved. install.sh:826-878 shell-rc block confined inside `if [[ "${#_user_rows[@]}" -gt 0 ]]`. S1 smoke confirmed in 38-02-SUMMARY.                  |
| 12  | Project-scope-only queue prints D-14 copy block ("Some project-scope MCPs need API keys finished:", "Open `<project>/.env`...", ".gitignore already includes .env...", "Reload shell env from the project dir...") | VERIFIED | install.sh:890, 892, 915, 917 carry the four exact phrases. T11 in test-mcp-wizard.sh greps each verbatim. S2 smoke confirmed.                                                                |
| 13  | Mixed-scope queue: user block prints first, project block prints second (D-16 ordering)                                        | VERIFIED   | install.sh:820-878 (user pass) → install.sh:881-918 (project pass). T11 asserts `USER_POS < PROJ_POS` via line-numbered grep.                                                                       |
| 14  | Project-scope summary path does NOT touch `~/.zshrc` / `~/.bash_profile` (D-15)                                                | VERIFIED   | Shell-rc auto-source block lives entirely inside the user-scope branch (install.sh:820-878, marker `# claude-code-toolkit: source ~/.claude/mcp-config.env into shell env` at install.sh:849).      |

**Score:** 14/14 truths verified

### Required Artifacts

| Artifact                              | Expected                                                                                          | Status     | Details                                                                                                                                                                       |
| ------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/lib/mcp.sh`                  | Project-scope branch + 4-tuple writer + lazy source guard with re-entrancy sentinel               | VERIFIED   | 1154 lines. Contains all 4 Phase 37 lib calls (lines 773, 886, 891, 926, 929), 4-tuple printf at line 752, lazy source guard at 88-95, missing-lib guard at 713-715.        |
| `scripts/install.sh`                  | 4-field reader + two-block per-scope dispatch                                                     | VERIFIED   | 4-field read at line 809, empty-field fallback at 812, case dispatch at 813-816, user-scope block 820-878, project-scope block 881-918.                                    |
| `scripts/tests/test-mcp-wizard.sh`    | PASS≥20 with DISP-01..04 + defense-in-depth assertions                                            | VERIFIED   | Actual PASS=53 (after REVIEW-FIX added INFO-02 positive assertion). T7-T12 cover DISP-01/02/03/04 + Defense-in-depth. Hermetic, double-run safe.                          |

### Key Link Verification

| From                                              | To                                                                | Via                                                                       | Status | Details                                                                                                  |
| ------------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------- |
| mcp.sh::mcp_wizard_run                            | project-secrets.sh::project_secrets_write_env                     | lazy `command -v` source guard (mcp.sh:88-95) + sentinel re-entrancy break | WIRED  | Smoke test confirmed real value lands in `<project>/.env`. mcp.sh:891 call site.                       |
| mcp.sh::mcp_wizard_run (project branch)           | claude mcp add --scope project -e KEY=${KEY} ...                  | exec without env wrapper — substitution-form argv only                    | WIRED  | Smoke argv: `mcp add -e CONTEXT7_API_KEY=${CONTEXT7_API_KEY} --scope project ...`. Literal absent.       |
| mcp.sh deferred-queue writer                      | TK_MCP_DEFERRED_QUEUE                                             | printf with 4-field tab-separated tuple                                   | WIRED  | mcp.sh:752 `printf '%s\t%s\t%s\t%s\n' "$name" "$_deferred_keys" "${install_args[*]}" "$_scope"`.       |
| install.sh:809 4-field reader                     | TK_MCP_DEFERRED_QUEUE 4-field producer (mcp.sh)                   | tab-separated 4-field tuple                                               | WIRED  | install.sh:809 reader matches mcp.sh:752 producer. T9 + T11 cover full round-trip.                   |
| install.sh project-scope block                    | user instruction "Open `<project>/.env` to fill in: KEY=<your-key>" | echo + per-row printf                                                     | WIRED  | install.sh:890-917. T11 asserts presence + D-16 ordering.                                              |

### Data-Flow Trace (Level 4)

| Artifact          | Data Variable          | Source                                  | Produces Real Data | Status     |
| ----------------- | ---------------------- | --------------------------------------- | ------------------ | ---------- |
| mcp.sh project branch | `collected_value`      | tui_tty_read from `$tty_src` (silent=1) | Yes                | FLOWING    |
| mcp.sh queue write    | `_deferred_keys`/`name`/`install_args`/`_scope` | wizard locals + scope case-block | Yes                | FLOWING    |
| install.sh reader     | `d_name`/`d_keys`/`d_args`/`d_scope`    | `<` redirect from `TK_MCP_DEFERRED_QUEUE` | Yes              | FLOWING    |

### Behavioral Spot-Checks

| Behavior                                                                                          | Command                                                                              | Result                                                                                            | Status |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | ------ |
| test-mcp-wizard.sh PASS≥20 (TEST-02 floor)                                                        | `bash scripts/tests/test-mcp-wizard.sh`                                              | `Results: 53 passed, 0 failed`                                                                    | PASS   |
| test-mcp-secrets.sh PASS=11 baseline preserved (TEST-03)                                          | `bash scripts/tests/test-mcp-secrets.sh`                                             | `Results: 11 passed, 0 failed`                                                                    | PASS   |
| test-project-secrets.sh PASS=42 (Phase 37 cross-impact gate)                                      | `bash scripts/tests/test-project-secrets.sh`                                         | `Results: 42 passed, 0 failed`                                                                    | PASS   |
| make shellcheck green                                                                             | `make shellcheck`                                                                    | `✅ ShellCheck passed`                                                                            | PASS   |
| Project-scope happy path: `.env` real value, `.gitignore` guard, argv `${VAR}` form, no leak      | hermetic smoke (mock claude, TTY fixture)                                            | `.env=CONTEXT7_API_KEY=tk_real_secret`, `.gitignore` has `.env`, mode `0600`, argv has `${VAR}` form, literal absent | PASS   |
| User-scope no-regression: keys to `mcp-config.env`, argv carries literal via env wrapper, no `<project>/.env` | hermetic smoke (TK_MCP_SCOPE=user)                                          | `mcp-config.env=CONTEXT7_API_KEY=user_secret`, argv has `--scope user` + `env_CTX=user_secret`, `<project>/.env` absent | PASS   |

### Requirements Coverage

| Requirement | Source Plan         | Description                                                               | Status     | Evidence                                                                                                                                |
| ----------- | ------------------- | ------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| DISP-01     | 38-01-PLAN          | `mcp_wizard_run` reads `TK_MCP_SCOPE`, project-scope branch persists to `<project>/.env` and uses `${VAR}` form | SATISFIED  | mcp.sh:707-708 (locals), 766-810 (defer mirror), 881-906 (env-collection branch), 916-945 (claude invocation). Smoke + T7 confirm.   |
| DISP-02     | 38-01-PLAN          | User/local scope behavior byte-identical to v4.6/v4.9                     | SATISFIED  | mcp.sh:899 `mcp_secrets_set` preserved; mcp.sh:947 `env "${exported_env[@]}" "$claude_bin" mcp add` preserved. T8 + smoke confirm.    |
| DISP-03     | 38-01-PLAN + 38-02-PLAN | Defer-secrets path extended for project scope; queue tuple grows to 4 fields | SATISFIED | mcp.sh:752 4-field printf; mcp.sh:766-799 project-scope stub branch; install.sh:809 4-field reader. T9 + T10 + T11 cover.            |
| DISP-04     | 38-02-PLAN          | Post-install summary printer prints scope-correct hints                   | SATISFIED  | install.sh:881-918 project-scope block with 4 D-14 phrases. install.sh:820-878 user-scope block. T11 covers single + mixed + ordering. |
| TEST-02     | 38-03-PLAN          | Extend test-mcp-wizard.sh from PASS=14 to PASS≥20                         | SATISFIED  | Actual PASS=53 (far exceeds floor). T7-T12 cover DISP-01/02/03/04 + Defense-in-depth + cross-store fingerprint negatives.           |
| TEST-03     | 38-03-PLAN          | Extend test-mcp-secrets.sh with shared `_mcp_validate_value` boundary scenarios | SATISFIED | Closed per D-18: shared validator boundary preserved without new file changes; PASS=11 baseline byte-identical (no regressions in the boundary). |

### Anti-Patterns Found

None. Code review (38-REVIEW.md) and follow-up fix pass (38-REVIEW-FIX.md) closed all findings:

| Severity | Finding                                                                                          | Resolution                                                                                                              |
| -------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| HIGH-01  | Load-bearing `_project_secrets_load_env`-per-iteration invariant in defer block needs comment    | Fixed (commit a7da36b) — inline cycle-breaker comment added                                                            |
| MED-01   | install.sh `set -- $_row` mutates script's positional params at top-level (latent time-bomb)     | Fixed (commit 480be76) — wrapped both blocks in `( ... )` subshells                                                   |
| MED-02   | `tail -c 1` newline-detection mis-handles NUL-byte trailing                                      | Deferred — pre-existing Phase 37 code, not regressed by Phase 38                                                       |
| MED-03   | T12 function override leaks into parent shell namespace                                          | Fixed (commit 6b46c6d) — wrapped in subshell, dropped `unset -f` + re-source dance                                   |
| LOW-01   | User-scope defer branch bypasses `^[A-Z_][A-Z0-9_]*$` key validation                             | Fixed (commit e553a61) — added shape check matching audit L1 guard                                                    |
| LOW-02   | rc-write path untested by Phase 38 harness                                                       | Deferred — pre-existing v4.9 code, out of phase scope                                                                  |
| INFO-01  | Comment drift `mcp.sh:749` references wrong line number                                          | Fixed (commit a7da36b) — corrected to `install.sh:809`                                                                 |
| INFO-02  | T9 missing positive assertion that `claude.argv` was written under defer+project                 | Fixed (commit bdfab01) — added positive assertion; PASS count grew 52→53                                              |

The two deferred findings (MED-02, LOW-02) are pre-existing pre-Phase-38 code paths flagged for future-phase awareness. They do not affect Phase 38 goal achievement.

### Human Verification Required

None — all goal-critical behavior is mechanically verified via the test suite, hermetic smoke tests, and documented behavioral spot-checks. No visual/UX/external-service surface was added in this phase.

### Gaps Summary

No gaps. Every observable truth maps to substantive, wired implementation; data flows correctly through all four levels (exists → substantive → wired → flows real data); all six requirement IDs are satisfied with concrete evidence; the regression nets (test-mcp-wizard PASS=53, test-mcp-secrets PASS=11, test-project-secrets PASS=42, make shellcheck) all green. The code review found 8 issues — 6 fixed, 2 deferred as out-of-scope pre-existing code; no Phase 38 regressions remain.

**Notable strengths beyond the must-haves:**

- Re-entrancy sentinel `_MCP_SOURCING_PROJECT_SECRETS` (mcp.sh:88-95) discovered and added during execution to break the symmetric mutual-source cycle between mcp.sh and project-secrets.sh — without this, sourcing mcp.sh from a clean shell segfaults. Documented in 38-01-SUMMARY Deviations.
- Defense-in-depth call site (`project_secrets_validate_mcp_env_block` at mcp.sh:929 BEFORE `claude mcp add` at mcp.sh:945) is a second barrier after Phase 37 lib's own SEC-05 check — confirmed effective by T12 (mock render returns poisoned literal → wizard rc=1 + claude never invoked).
- Test PASS count exceeded floor by a wide margin: TEST-02 floor was PASS≥20, actual PASS=53 (+33 over floor).

---

_Verified: 2026-05-05T18:23:16Z_
_Verifier: Claude (gsd-verifier)_
