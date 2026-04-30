# Logic / Cross-file Audit — 2026-04-30 (deep)

## Numbers / scope

- Files traced (full read): `scripts/lib/{state,dispatch,install,bootstrap,bridges,skills,mcp,tui,detect2,cli-recommendations}.sh`,
  `scripts/{install,uninstall,update-claude,init-claude,init-local,migrate-to-complement,setup-council,verify-install}.sh`,
  `scripts/tests/{test-state,test-install-dispatch-h1,test-bootstrap,test-bridges-sync,test-uninstall,test-uninstall-state-cleanup,test-mcp-secrets,test-uninstall-keep-state,test-migrate-flow,test-update-libs}.sh`.
- Tests run: 10 of 48 (test-state, test-install-dispatch-h1, test-bootstrap, test-bridges, test-uninstall,
  test-mcp-secrets, test-uninstall-state-cleanup, test-bridges-sync, test-update-libs, test-uninstall-keep-state,
  test-migrate-flow). 9 PASS, 1 has 1/6 sub-test failure.
- Live reproductions: `init-local.sh --dry-run` on a fresh sandbox (LOG-MED-2 below).
- Past-fix regression checks: H1 (label→name dispatch), H6 (TK_TEST=1 gate on dispatcher overrides),
  M2 (uninstall empty installed-sha → REMOVE), C2 (eval gating), C-04 (manifest_hash atomic write),
  M6 (mktemp paths in EXIT trap).

## Findings

### LOG-HIGH-1 — `test-state.sh` Scenario D fails: production code intentionally refuses dead-PID reclaim with young lock; test asserts the *old* unsafe behavior

- **Files involved (call chain):**
  - `scripts/tests/test-state.sh:138-159` (scenario D)
  - `scripts/lib/state.sh:201-228` (dead-PID + young-lock → defensive retry, not reclaim)
- **Severity:** HIGH — every CI run on a clean checkout reports failure for a scenario that is now *correctly* handled.
- **Confidence:** 95%. Reproduced locally (`5 passed, 1 failed`).
- **Trigger input:**

  ```bash
  bash scripts/tests/test-state.sh
  ```

  Scenario D writes `99999` to `$LOCK_DIR/pid` and `touch`es the dir (recent mtime), then expects
  `acquire_lock` to print `Reclaimed stale lock from PID 99999`. The fix at state.sh:205-208
  ("Signal 1+2 combined") requires BOTH `kill -0` failure AND `age > 60s`. With a freshly-touched
  lock, `age <= 60s`, so acquire_lock prints `Lock holder PID 99999 recently exited; refusing to
  race. Exiting.` and returns 1.
- **Effect:** Test produces a hard-FAIL line. Anyone running `bash scripts/tests/test-state.sh`
  (including CI on PRs that touch state.sh) sees `Results: 5 passed, 1 failed` and exits non-zero.
- **Verification (literal reproduction):**

  ```text
  $ bash scripts/tests/test-state.sh
  …
  ❌ FAIL: D: dead PID reclaim (rc=1, out=...Lock holder PID 99999 recently exited; refusing to race. Exiting.)
  Results: 5 passed, 1 failed
  ```

- **Fix:** Update scenario D to also `touch -t` the lock dir to >60s in the past so the
  age branch is satisfied alongside dead PID. The defensive-retry behavior is the production
  contract documented in state.sh:202-208 — the test is wrong, not the code. Suggested patch
  (Darwin/Linux portable, mirrors scenario E):

  ```bash
  # In scenario_d_stale_dead_pid, after `echo "99999" > "$LOCK_DIR/pid"`:
  if [[ "$(uname)" == "Darwin" ]]; then
      ts=$(date -v-2m +%Y%m%d%H%M)
      touch -t "$ts" "$LOCK_DIR"
  else
      touch -d '2 minutes ago' "$LOCK_DIR"
  fi
  ```

---

### LOG-MED-1 — `migrate-to-complement.sh` writes `manifest_hash=""` to fresh state; the next `update-claude.sh` can never short-circuit via `is_update_noop`

- **Files involved:**
  - `scripts/migrate-to-complement.sh:506` (passes `""` as 9th positional arg)
  - `scripts/lib/state.sh:68` (`local manifest_hash="${9:-}"`)
  - `scripts/update-claude.sh:444-456` (`is_update_noop` / D-59)
- **Severity:** MEDIUM — silent perf regression, not a correctness break.
- **Confidence:** 90%.
- **Trigger input:** Any v3.x → v4.x user runs `migrate-to-complement.sh`. The post-migrate state
  has `"manifest_hash": ""`. Next `update-claude.sh` against an unchanged manifest:

  ```bash
  bash scripts/migrate-to-complement.sh --yes
  bash scripts/update-claude.sh   # MANIFEST_HASH = sha256(manifest.json), STATE_MANIFEST_HASH = ""
  ```

- **Effect:** `is_update_noop` always returns 1 because of `[[ "$STATE_MANIFEST_HASH" == "$MANIFEST_HASH" ]] || return 1`
  (line 454). The full update flow runs (acquire_lock, BACKUP_DIR creation, every per-file SHA pass,
  bridge sync) on every invocation even when nothing changed. Wallclock cost ~3-15s for a 91-file install
  + a tree backup; not catastrophic but defeats the purpose of D-59.
- **Verification:** Inspect state file produced by migrate:

  ```bash
  jq '.manifest_hash' .claude/toolkit-install.json   # "" after migrate
  ```

- **Fix:** Have migrate-to-complement.sh capture the manifest hash same as update-claude.sh:165
  (`MANIFEST_HASH=$(sha256_file "$MANIFEST_TMP")`) and pass it as the 9th arg to write_state at line 506.

---

### LOG-MED-2 — Cosmetic but persistent: dry-run, install summary and `skipped_files[]` strings show duplicated bucket prefix (`agents/agents/...`, `commands/commands/...`)

- **Files involved:**
  - `scripts/init-claude.sh:551-552` (log + SKIPPED_PATHS)
  - `scripts/init-local.sh:336-339` (same pattern)
  - `scripts/lib/install.sh:120,122` (print_dry_run_grouped builds `${bucket}/${path}` rows)
- **Severity:** MEDIUM — not a correctness bug (files install to the right disk paths via
  `full_dest="$CLAUDE_DIR/$path"` at init-claude.sh:555 which uses `$path` only). Cosmetic
  on the user-facing dry-run, install summary, and `skipped_files[]` state record.
- **Confidence:** 100%. Live-reproduced.
- **Trigger input:**

  ```bash
  cd "$(mktemp -d)" && bash /path/to/scripts/init-local.sh --dry-run
  ```

- **Effect (literal reproduction excerpt):**

  ```text
  [+ INSTALL]                                     91 files
    agents/agents/planner.md
    agents/agents/security-auditor.md
    prompts/prompts/CODE_REVIEW.md
    commands/commands/api.md
    commands/commands/audit.md
    …
  ```

  Root cause: every `manifest.files.<bucket>[].path` already contains the bucket as its leading
  segment (e.g. `commands/api.md`, `agents/code-reviewer.md`, `scripts/lib/backup.sh`). The print
  loop concatenates `${bucket}/${path}` → `commands/commands/api.md`. The actual install loop at
  init-local.sh:347/init-claude.sh:555 uses `$path` only, so files land at the right paths on
  disk. Only display strings + `skipped_files[]` are wrong.
- **Verification:**

  ```bash
  jq '.files.commands[0].path' manifest.json   # "commands/api.md"
  ```

- **Fix:** Drop the `${bucket}/` prefix in the three sites (init-claude.sh:551-552,
  init-local.sh:336-339, lib/install.sh:120/122). They print `${path}` directly.
  `skipped_files[]` then carries `commands/api.md:conflicts_with:superpowers` instead of
  `commands/commands/api.md:conflicts_with:superpowers`.

---

### LOG-LOW-1 — `dispatch.sh` declares 8-element `TK_DISPATCH_ORDER` including `gemini-bridge` / `codex-bridge` for which no `dispatch_*` function exists; the validation loop in install.sh:845-851 only sanity-checks names against a regex

- **Files involved:**
  - `scripts/lib/dispatch.sh:84` (canonical order)
  - `scripts/install.sh:845-851` (regex validation — passes any kebab-case)
  - `scripts/install.sh:875-961` (actual dispatch loop iterates `TUI_LABELS`, NOT `TK_DISPATCH_ORDER`)
- **Severity:** LOW — current install.sh dispatches via `TUI_LABELS` + bridge-specific case branch
  (line 931-944 calls `bridge_create_global` for bridges). `TK_DISPATCH_ORDER` is now decorative
  in install.sh.
- **Confidence:** 80%. The risk is that a future patch may iterate `TK_DISPATCH_ORDER` again (the
  contract banner at dispatch.sh:6 still lists it as an exposed array), expand `dispatch_${name}`
  for `gemini-bridge`, and silently fail because no `dispatch_gemini_bridge` exists (the function
  name produced after `${name//-/_}` substitution would be `dispatch_gemini-bridge` which is not a
  valid bash function name and would error with `command not found`).
- **Trigger input:** N/A today. Triggered by anyone who writes:

  ```bash
  for name in "${TK_DISPATCH_ORDER[@]}"; do
      dispatch_"${name//-/_}"
  done
  ```

  in a future verifier / orchestrator / migration script.
- **Fix (defensive):** Either remove `gemini-bridge codex-bridge` from `TK_DISPATCH_ORDER` and
  document the bridge dispatch as out-of-band (preferred — current reality), OR add stub
  `dispatch_gemini_bridge()` / `dispatch_codex_bridge()` wrappers around `bridge_create_global`
  so the symmetry holds even under a name-based loop.

---

### LOG-LOW-2 — `_is_bridge_path` boolean convention is inverted between `prompt_modified_for_uninstall` and the MAIN delete loop

- **Files involved:**
  - `scripts/uninstall.sh:301-310` (function: 1 = "NOT bridge", 0 = "IS bridge")
  - `scripts/uninstall.sh:671-680` (MAIN: 0 = "NOT bridge", 1 = "IS bridge")
- **Severity:** LOW — both call sites are individually correct because the conditions on
  lines 310 (`-ne 0`) and 680 (`-eq 0`) match their respective conventions. Audit risk only.
- **Confidence:** 100%.
- **Trigger input:** Anyone editing one site without reading the other.
- **Effect:** A future refactor that copies the test condition from one block to the other
  would silently invert it. is_protected_path would then run on bridges (skipping their
  removal) or skip the protection check on non-bridge paths inside CLAUDE_DIR.
- **Fix:** Pick one convention (recommend 1 = "is bridge"; matches "boolean true = match found")
  and align both sites. Mechanical change.

---

### LOG-LOW-3 — `_dispatch_run_gsd_default` runs `bash <(curl -sSL ...)` without `-f`, so any HTTPS 502 / 404 from raw.githubusercontent.com gets sourced as shell

- **Files involved:**
  - `scripts/lib/dispatch.sh:65-67` (`_dispatch_run_gsd_default`)
  - Compare with `scripts/lib/bootstrap.sh:104` (also missing -f) and `scripts/lib/bootstrap.sh:80`
    (HAS `-f` via `_tk_curl_safe`-shape inline call when TK_GSD_PIN_SHA256 is set)
- **Severity:** LOW — only fires under a transient HTTPS error and the user has to have
  consented to the bootstrap prompt. The downloaded HTML body would almost certainly fail to
  parse as bash and exit non-zero, but the failure mode is "execute attacker-controlled HTML
  as bash" if a CDN ever returns an attacker-controlled body.
- **Confidence:** 75%.
- **Trigger input:** GitHub raw returns a 5xx HTML body during an SP/GSD bootstrap. Reproducible
  locally:

  ```bash
  TK_USER_AGENT='x' bash -c 'bash <(curl -sSL https://httpbin.org/status/502)'
  # bash: line 1: syntax error near unexpected token `}'
  ```

- **Effect:** Process substitution `bash <(...)` doesn't propagate curl's exit code, so a 502
  with no `-f` flag silently feeds HTML to bash. With `-sSLf`, curl exits non-zero and `bash <()`
  receives an empty file → no execution.
- **Fix:** Replace the inline `curl -sSL` at dispatch.sh:65-67 and bootstrap.sh:104 with the
  `-f` flag (`-sSLf`). Already done at bootstrap.sh:80 in the `TK_GSD_PIN_SHA256` branch.

  ```bash
  bash <(curl -sSLf -A "$TK_USER_AGENT" --max-time 60 --connect-timeout 10 --retry 2 "$url")
  ```

---

### LOG-LOW-4 — `verify-install.sh:418` reports "All checks passed!" only when both FAIL=0 AND WARN=0

- **Files involved:** `scripts/verify-install.sh:418-424`.
- **Severity:** LOW — UX only.
- **Confidence:** 100%. Logic mismatch: the `$PASS/$PASS` token suggests "everything green",
  but the gate requires WARN=0 too. Users with valid setups that include a single warning (e.g.
  Council not installed → "skip" → still WARN-positive in some paths) won't see the friendly
  banner; they'll see the regular `$PASS passed, $WARN warnings` line. Not a defect, but the
  label is slightly misleading.
- **Fix (optional):** Reword "All checks passed!" → "No failures (all required checks passed)"
  or move the condition to `[[ $FAIL -eq 0 ]]` only.

## Past-fix regression check

| Past finding | Current state | Verification |
|---|---|---|
| H1 (dispatch label→name) | FIX HOLDS | `bash scripts/tests/test-install-dispatch-h1.sh` → 6/6 PASS |
| H6 (TK_TEST=1 gate on dispatcher overrides) | FIX HOLDS | dispatch.sh:125, 162, 199, 242, 280, 317 all gated. grep confirms 6/6 sites. |
| M2 (uninstall empty installed-sha → REMOVE) | FIX HOLDS | uninstall.sh:265-268, AFTER the file-readable gate (line 249-257). Verified by reading classify_file end-to-end. |
| M4 (install.sh empty-array Bash 3.2) | FIX HOLDS | install.sh:955, 958 use `"${local_flags[@]+"${local_flags[@]}"}"`. |
| M6 (update mktemp paths in EXIT trap) | FIX HOLDS | update-claude.sh:944-947 declares CLAUDE_MD_TMP/CMP_LOCAL_NORM/CMP_REMOTE_NORM as empty before the trap. |
| M1 (install.sh undefined log_error) | FIX HOLDS | grep `log_error` in install.sh — only inside print helper definitions / inline `echo`. |
| M-MCP (regex name escape) | FIX HOLDS | mcp.sh:139-141 sed-escapes regex metas. |
| H2 (mcp.sh `join("")`) | CONFIRMED FALSE POSITIVE (re-verified) | `xxd` of mcp.sh line 85 shows byte `0x1f` between the quote chars (`join("\x1f")`); the past lesson's xxd verification protocol re-applies. |
| M-bridge (atomic write + lock 16-byte cap) | FIX HOLDS | bridges.sh:227, 386, 452 all use `head -c 16`. |
| C-04 (manifest_hash atomic) | FIX HOLDS | state.sh:60-79 takes manifest_hash as 9th positional arg; update-claude.sh:1310-1312 passes it inline. |
| L3 (rm -rf guard in skills.sh) | FIX HOLDS | skills.sh:150 guard. |
| L1 (mcp key-shape regex) | FIX HOLDS | mcp.sh:202 `^[A-Z_][A-Z0-9_]*$`. |

## FP / skipped

- **mcp.sh:85 `join("")` (FALSE POSITIVE).** Re-verified via `xxd`. The byte 0x1f (US, ASCII 31)
  IS present between the two double quotes. The Read tool renders byte 31 as nothing visible.
  Per the 2026-04-30 lesson: every "invisible byte" claim must use `xxd` before flagging.
  Not flagged.

- **`local_switch_decision` in update-claude.sh:832** (NOT a `local` keyword in main block).
  The token starts with the literal letters "local_" and is just a variable naming convention.
  Verified by grepping the file for `^local ` (with trailing space) — none in main blocks.

- **Bootstrap's `TK_BOOTSTRAP_OVERRIDE_CMD` env-prefix to a bash function** — initially suspicious
  (`var=value func` syntax with bash functions), but POSIX behavior verified: the env vars ARE
  visible inside the function for the duration of its execution. test-bootstrap.sh:26/26 PASS.

- **`is_security_installed` python3 + grep fallback** — both branches checked; no FP risk
  observed beyond the documented audit M5 fix.

- **CLAUDE.md merge** — no longer a smart merge in update-claude.sh (chezmoi-style `.new` file
  strategy). No section markers. Sentinel-block strip lives only in uninstall.sh:402-468 for
  the global `~/.claude/CLAUDE.md`. Tested (test-uninstall-state-cleanup PASS).

- **`setup-council.sh` Claude Desktop MCP register** — the `mv "$CD_TMP" "$DESKTOP_CFG"` chain
  is guarded by `set -euo pipefail` so a python3 heredoc failure aborts before the mv. Path
  contains a space (`Application Support`) but is properly quoted at every site. Not flagged.

- **`init-claude.sh` lacks 9th `manifest_hash` arg in `write_state` (line 580)** — same shape as
  LOG-MED-1 but for fresh installs (no prior state). Effect is the SAME: first `update-claude.sh`
  cannot short-circuit. Not flagged separately because LOG-MED-1's fix would need to be applied
  symmetrically here AND in init-local.sh:407 (which has the same 7-arg form). Recommend treating
  as part of LOG-MED-1's remediation: ALL three callers (init-claude, init-local, migrate)
  should compute and pass the manifest hash so the noop check is reachable from day-1.
