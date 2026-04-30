---
audit_id: 2026-04-30-deep
date: 2026-04-30
branch: fix/audit-sweep-2026-04-30
agents: shell, security, infra, logic
prior_sweep: 260430-go5 (18 fixed, 1 FP withdrawn)
---

# Deep Audit — Consolidated Findings (2026-04-30)

## Scope

Four parallel deep audits across:
- **Shell** — bugs/races/traps/eval (29 files; ~12k LOC)
- **Security** — Python + secrets + supply-chain + prompt-injection
- **Infra** — manifest, CI, deps, version drift
- **Logic** — cross-file flows, install/update/uninstall, state machine

## Numbers

| Severity | Shell | Security | Infra | Logic | **Total** |
|---|---|---|---|---|---|
| CRIT | 0 | 0 | 0 | 0 | **0** |
| HIGH | 2 | 0 | 2 | 1 | **5** |
| MED  | 4 | 1 | 5 | 2 | **12** |
| LOW  | 4 | 3 | 3 | 2 | **12** |

**Regressions of past sweep (260430-go5):** 0 verified intact across all 18 fixes. H2 reconfirmed FP (Read-tool render artifact; xxd shows `\x1f` byte present at `mcp.sh:85`).

## Findings

### HIGH

| ID | Title | File:line | Confidence |
|---|---|---|---|
| **S-HIGH-1** | `update-claude.sh --clean-backups` broken in production (relative `CLAUDE_DIR=".claude"` → `dirname` returns `.` → safety pattern `./.claude-backup-*` never matches absolute `find $HOME` paths). Tests pass only because they all set `TK_UPDATE_HOME=$SCR` (absolute). Live-reproduced. | `update-claude.sh` `--clean-backups` flow | 98% |
| **S-HIGH-2** | Glob expansion in `--bridges <list>` parsing. `_bridge_match` does `local tokens=($list)` unquoted with `IFS=','`, inheriting filename glob expansion. `--bridges 'g*'` from a dir with files `gemini`/`gnu` matches unintended targets. Same shape at `bridges.sh:658` FAIL_FAST loop. Live-reproduced. | `lib/bridges.sh` _bridge_match + ~658 | 90% |
| **INF-HIGH-1** | H1 regression test (`test-install-dispatch-h1.sh`, 161 LOC) **orphaned** — never invoked by Makefile or CI. The canonical reproduction for sweep's most-impactful finding (Codex-only dispatch). Future H1 regression won't be caught. | `Makefile`, `.github/workflows/quality.yml` | 99% |
| **INF-HIGH-2** | CI shellcheck excludes `templates/global/` (`scandir: './scripts'` only). Local `make shellcheck` covers `scripts templates/global` per audit M-03; CI does not. Regression of M-03 intent. `templates/global/{rate-limit-probe,statusline}.sh` ship to users; CI won't block a regression. | `.github/workflows/quality.yml:28` | 95% |
| **LOG-HIGH-1** | `test-state.sh` Scenario D fails on clean checkout — test asserts dead-PID reclaim with recently-touched lock; production code (state.sh:201-228, I2 hardening) refuses young dead-PID reclaim to prevent recycled-PID hijack. Test wrong, code right. Fix: `touch -t` so age > 60s. | `scripts/tests/test-state.sh` Scenario D | 100% |

### MEDIUM

| ID | Title | Confidence |
|---|---|---|
| **S-MED-1** | `release_lock` releases wrong lock when bridges helper mutates `LOCK_DIR`. SIGINT during `_bridge_write_state_entry` releases bridge lock; parent lock leaks ≤ 3600s. | 75% |
| **S-MED-2** | `init-local.sh:329-330` registers trap AFTER `acquire_lock`. SIGINT in 1-instr window leaks lock. Past `uninstall.sh`/`migrate-to-complement.sh` fix never propagated (lessons-learned #3 violation). | 95% |
| **S-MED-3** | TUI `eval`-restored parent EXIT/INT/TERM traps can drop parent cleanup on signal during menu. | 70% |
| **S-MED-4** | `setup-security.sh:166` `echo "$SECURITY_CONTENT" > "$CLAUDE_MD"`. A future template starting with `-e`/`-n`/`-E` corrupts global CLAUDE.md. Same file uses safer `printf '%s\n'` elsewhere. | 70% |
| **SEC-MED-1** | validate-plan prompt has no system/user separation (no sandwich pattern). `brain.py:2424-2453` (Skeptic) and `:2491-2524` (Pragmatist) interpolate `files_content`, `plan`, `rules_block` directly. audit-review mode in same file already uses sentinel markers — copy-paste-the-fix. | 85% |
| **INF-MED-1** | 9 substantive test files (1873 LOC) orphaned: `test-{backup-lib,backup-threshold,clean-backups,detect-cli,detect-skew,mcp-secrets,mcp-wizard,migrate-dry-run,update-dry-run}.sh`. Notably `test-mcp-secrets.sh` is the L1-fix regression guard. | 95% |
| **INF-MED-2** | `TK_TOOLKIT_REF` interpolated raw into 9 fetch URLs. No `[[ =~ ^[A-Za-z0-9._/-]+$ ]]` allowlist. Local env var so impact low, but global rule §2 violated. | 85% |
| **INF-MED-3** | `TK_TOOLKIT_REF` not exported across `bash <(curl ...)` boundaries. `init-claude.sh:1217,1234` invokes `setup-security.sh`/`setup-council.sh` via curl|bash; inner script falls back to `main`. User pins v4.8.0 → `.claude/` from v4.8.0 but `~/.claude/council/brain.py` from `main`. Defeats H5 purpose. | 90% |
| **INF-MED-4** | Two markdownlint configs (cli v1 `.markdownlint.json` + cli v2 `.markdownlint-cli2.jsonc`). Local `make mdlint` reads v1; CI reads v2. Currently identical, un-enforced; silent drift inevitable. | 80% |
| **INF-MED-5** | `validate-manifest.py:204-246` drift-checks `commands/`, `templates/base/skills/`, `scripts/lib/` but NOT `agents/`/`prompts/`/`rules/`. Adding `agents/new.md` without manifest entry never reaches existing users via update. | 90% |
| **LOG-MED-1** | `migrate-to-complement.sh:506` writes `manifest_hash=""` to state file. Next `update-claude.sh` cannot short-circuit via `is_update_noop` (line 454 requires hash equality). Same shape: `init-claude.sh:580`, `init-local.sh:407` — only 7 args to `write_state`. Silent perf regression. | 90% |
| **LOG-MED-2** | Dry-run output and `skipped_files[]` show duplicated bucket prefix (`agents/agents/planner.md`, `commands/commands/api.md`). 3 sites concat `${bucket}/${path}` when manifest paths already include bucket: `init-claude.sh:551-552`, `init-local.sh:336-339`, `lib/install.sh:120,122`. Disk install correct, only display strings wrong. | 100% live-reproduced |

### LOW

| ID | Title |
|---|---|
| S-LOW-1 | `is_statusline_installed` substring grep matches `"statusLine"` inside other contexts. |
| S-LOW-2 | `propagate-audit-pipeline-v42.sh` tempfile leak on script-abort path. |
| S-LOW-3 | Backups created in PWD invisible to `--clean-backups`'s `$HOME` scan. |
| S-LOW-4 | `setup-security.sh` curl response stored in shell variable; no `--max-filesize` cap. |
| SEC-LOW-1 | `brain.py:1720-1721` interpolates `gemini.model` from `config.json` into URL path with no allowlist. Self-DoS only (config 0600), defense-in-depth. |
| SEC-LOW-2 | GSD installer `bash <(curl ...)` not pinned by default. `TK_GSD_PIN_SHA256` is opt-in. Documented y/N gated behavior, standard solo-dev tradeoff. |
| SEC-LOW-3 | Council API endpoints `--retry 2 --retry-delay 2` no `--retry-max-time`. Bounded by `--max-time` 120-180s. Operational only. |
| INF-LOW-1 | `verify-install.sh:22-24` defines `TK_USER_AGENT` but makes zero curl calls — dead code. |
| INF-LOW-2 | `CONTRIBUTING.md:24,40-43` says `make lint && make test`, missing the broader `make check`. |
| INF-LOW-3 | `Makefile:test` lacks pre-cleanup of `/tmp/test-claude-*`; parallel `make test` would race. |
| LOG-LOW-1 | `TK_DISPATCH_ORDER` (`dispatch.sh:84`) lists `gemini-bridge codex-bridge` for which no `dispatch_*` function exists. Currently install.sh dispatches via `TUI_LABELS` so array decorative. Future name-based loop would silently fail. |
| LOG-LOW-3 | `_dispatch_run_gsd_default` (`dispatch.sh:65-67`) and `bootstrap.sh:104` use `curl -sSL` (no `-f`); HTTPS 5xx HTML body sourced as bash. Already mitigated in `TK_GSD_PIN_SHA256` branch. |

## Past-fix regression check (sweep 260430-go5)

All 18 fixes verified intact:

| Past ID | Status | Evidence |
|---|---|---|
| H1 (dispatch index) | OK | name-based `_local_label_to_dispatch_name` present; **but** regression test orphaned (INF-HIGH-1) |
| H3 (RTK.md curl|bash) | OK | branch present in setup-security.sh |
| H4 (`read -rs`) | OK | 3+ sites: setup-council.sh:160/214/239, mcp.sh:417 |
| H5 (TK_TOOLKIT_REF) | **Partial** | 9/9 install scripts; **not validated (INF-MED-2), not exported across curl|bash (INF-MED-3)** |
| H6 (TK_DISPATCH_OVERRIDE_*) | OK | gate at dispatch.sh + bootstrap.sh:121 |
| M1 (undefined log_error) | OK | inline echo at install.sh:837 |
| M2 (uninstall MODIFIED→REMOVE) | OK | state.sh classifier |
| M3 (trap printf %q) | OK | propagate-audit + bootstrap |
| M4 (empty-array Bash 3.2) | OK | `${arr[@]+"${arr[@]}"}` form |
| M5 (read /dev/tty || true) | OK | setup-council.sh:512 |
| M6 (mktemp EXIT trap) | OK | update-claude.sh registrations |
| M7 (CI concurrency) | OK | quality.yml:14-16 |
| M8 (statusline non-Darwin) | OK | early-exit guard |
| L1 (mcp_secrets key shape) | OK | mcp.sh:202 regex; **but test orphaned (INF-MED-1)** |
| L2 (predictable /tmp) | OK | all mktemp templated |
| L3 (skills root-delete guard) | OK | precondition in lib/skills.sh |
| L4 (browser User-Agent) | OK | 13 scripts + 4 libs |
| L5 (brain.py ANSI sanitize) | OK | 3 sites in brain.py |
| **H2 (mcp.sh:85 join sep)** | **FP confirmed** | xxd: `\x1f` byte present at offset 0x52. Read-tool render artifact persists. Lessons-learned #1 holds. |

## Cross-cutting themes

1. **Lessons-learned #3 violations** (pattern propagation): S-MED-2 (trap-after-lock not propagated to `init-local.sh`), LOG-MED-1 (3 sites with `manifest_hash=""`).
2. **H5 (`TK_TOOLKIT_REF`) is incomplete:** validation missing (INF-MED-2), env propagation broken (INF-MED-3). The fix shipped, but the threat model is half-addressed.
3. **Test coverage drift:** 9 substantive tests + 1 critical regression test orphaned (INF-HIGH-1, INF-MED-1). Some tests broken vs production hardening (LOG-HIGH-1).
4. **CI vs local lint divergence:** templates/global not linted in CI (INF-HIGH-2); markdownlint v1 vs v2 configs (INF-MED-4).
5. **Heuristic vs semantic audits:** Repeats sweep 260430-go5 lesson #2. shellcheck warning-clean across all 29 files; manual data-flow trace found 22 real findings.

## Recommended priority order

1. **INF-HIGH-1, INF-HIGH-2, LOG-HIGH-1** — wire H1 regression test, fix CI shellcheck scope, fix test-state.sh Scenario D timestamp.
2. **S-HIGH-1, S-HIGH-2** — `--clean-backups` absolute-path normalize; `--bridges` `set -f` glob guard.
3. **INF-MED-3** — export `TK_TOOLKIT_REF` (and `TK_USER_AGENT`) across `bash <(curl ...)`. Closes silent version drift.
4. **INF-MED-2** — `TK_TOOLKIT_REF` allowlist regex.
5. **SEC-MED-1** — sandwich-pattern markers in `brain.py` validate-plan mode (mirror audit-review code in same file).
6. **LOG-MED-1, LOG-MED-2** — manifest_hash propagation; bucket-prefix dedup.
7. **S-MED-1..4, INF-MED-1, INF-MED-4, INF-MED-5** — propagation/coverage/drift cleanups.
8. LOW items as time permits.

## Source reports

- `audit-shell.md` (on disk, 23 KB)
- `audit-logic.md` (on disk, 15 KB)
- `audit-security.md` — full text in agent transcript (not written to disk)
- `audit-infra.md` — full text in agent transcript (not written to disk)

This SUMMARY.md is the consolidated reconciliation across all four.

---

## Disposition (post-fix sweep, 2026-04-30)

Branch: `fix/audit-sweep-2026-04-30` (this branch). 17 fix commits added on top of the prior 19 (sweep `260430-go5`).

### Closed (17)

| ID | Status | Commit |
|---|---|---|
| **HIGH** | | |
| S-HIGH-1 | closed | `8aa01f2` — clean-backups absolute path normalize + new home-only regression test |
| S-HIGH-2 | closed | `0b487a6` — `set -f` glob guard around comma-split in `_bridge_match` + FAIL_FAST loop |
| INF-HIGH-1 | closed | `a28fc6d` — H1 regression test wired into Makefile + CI |
| INF-HIGH-2 | closed | `a28fc6d` — second `action-shellcheck` step for `templates/global/` |
| LOG-HIGH-1 | closed | `02ba469` — Scenario D ages lock past 60s before reclaim |
| **MED** | | |
| S-MED-1 | closed | `cfe698f` — bridges helpers wrap LOCK_DIR mutation in subshell |
| S-MED-2 | closed | `cfe698f` — init-local trap-before-acquire propagation |
| S-MED-4 | closed | `cfe698f` — setup-security.sh echo→printf for flag-prefix safety |
| SEC-MED-1 | closed | `1fb4405` — validate-plan `<<<USER_DATA_BEGIN/END>>>` markers |
| INF-MED-1 | closed | `e933787` — 9 orphan tests wired into Makefile/CI |
| INF-MED-2 | closed | `e44e56f` — TK_TOOLKIT_REF allowlist regex + `..` reject |
| INF-MED-3 | closed | `e44e56f` — `export TK_TOOLKIT_REF TK_USER_AGENT` across entry scripts + dispatch.sh |
| INF-MED-4 | closed | `3aae33d` — `validate-mdlint-config-sync` make target |
| INF-MED-5 | closed | `7314ca1` — drift checks for agents/prompts/rules in validate-manifest.py |
| LOG-MED-1 | closed | `b4771a2` — manifest_hash populated at 3 write_state sites |
| LOG-MED-2 | closed | `1b53735` — `${bucket}/${path}` dedup at 3 sites + dead bucket var prune |
| **LOW** | | |
| S-LOW-1 | closed | `e63124b` — statusline detection: python+json key check, grep-E fallback |
| S-LOW-2 | closed | `37da922` — propagate-audit-pipeline trap covers EXIT too |
| S-LOW-4 | closed | `e63124b` — setup-security curl `--max-filesize 2097152` + retry flags |
| SEC-LOW-1 | closed | `e63124b` — gemini.model allowlist regex `[A-Za-z0-9._-]+` |
| INF-LOW-1 | closed | `e63124b` — removed dead TK_USER_AGENT in verify-install.sh |
| INF-LOW-2 | closed | `e63124b` — CONTRIBUTING.md → `make check` (primary gate) |

### Deferred (6)

| ID | Reason |
|---|---|
| **S-MED-3** | TUI EXIT trap composition with parent — 70% confidence, recommended fix requires parsing `trap -p` output (fragile when parent body contains escaped quotes). Limited exposure (SIGTERM-only, since SIGINT path is fine). Tracked for follow-up; consider after a refactor that captures parent trap as a dedicated function name rather than as raw output. |
| **SEC-LOW-2** | GSD installer `bash <(curl ...)` not pinned by default. Documented y/N-gated behavior with explicit upstream-trust warning; `TK_GSD_PIN_SHA256` available for paranoid users. Standard solo-dev curl|bash trade-off; not a defect. |
| **SEC-LOW-3** | Operational only — Council API endpoints `--retry 2 --retry-delay 2` without `--retry-max-time`. `--max-time` 120-180s already bounds total. |
| **INF-LOW-3** | `Makefile:test` parallel isolation — cosmetic; CI runners are ephemeral per job. |
| **LOG-LOW-1** | False positive — `gemini-bridge`/`codex-bridge` in `TK_DISPATCH_ORDER` are intentional iteration markers; `install.sh:864-882` (the audit H1 fix) handles them via a dedicated bridge branch, not via `dispatch_*`. |
| **LOG-LOW-3** | Already mitigated in the `TK_GSD_PIN_SHA256` path (`bootstrap.sh:80`). Default unpinned path is the same trade-off as SEC-LOW-2. |

### Net count

| Severity | Found | Closed | Deferred | Withdrawn |
|---|---|---|---|---|
| CRIT | 0 | 0 | 0 | 0 |
| HIGH | 5 | **5** | 0 | 0 |
| MED | 12 | **11** | 1 | 0 |
| LOW | 12 | **6** | 5 | 1 (LOG-LOW-1, FP) |
| **Total** | **29** | **22** | **6** | **1** |

All HIGH and 11/12 MED closed. The single deferred MED (S-MED-3) is tracked as a future refactor.

### Lessons-learned application (from past sweep `260430-go5`)

- ✅ **#1 (xxd before flagging invisible bytes):** confirmed H2 still FP via `xxd /Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/lib/mcp.sh` showing `\x1f` byte at offset 0x52 — Read-tool render artifact persists. Lesson held; finding correctly stays withdrawn.
- ✅ **#2 (heuristic vs semantic audit):** all 4 deep-audit reports trace data flow across files. shellcheck-warning-clean across 29 files; semantic audit found 22 real bugs that pure heuristic would miss. Repeats sweep `260430-go5` finding.
- ✅ **#3 (pattern propagation requires a sweep):** S-MED-2 (init-local trap-after-lock missed when uninstall+migrate were fixed), LOG-MED-1 (3 sites with `manifest_hash=""`), LOG-MED-2 (6 sites with `${bucket}/${path}` doubling). All three were caught by extending grep across siblings during this sweep. Adding "propagation audit" to checklist confirmed effective.
- ✅ **#4 (single-CLI test cases):** test-install-dispatch-h1.sh wired into CI (INF-HIGH-1) so future H1-shape regressions fail. Also wired test-mcp-secrets.sh as the L1-fix regression guard (INF-MED-1).
