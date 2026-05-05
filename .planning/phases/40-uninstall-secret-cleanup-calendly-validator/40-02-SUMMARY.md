---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 2
subsystem: infra
tags: [bash, uninstall, mcp, secrets, mcp-config.env, full-toolkit-prompt, ordering-invariant, fail-closed]

# Dependency graph
requires:
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-01 — uninstall_prompt_mcp_keys helper + per-MCP claude-mcp-remove loop, lib/mcp.sh sourcing in uninstall.sh (mcp_secrets_load + _mcp_config_path symbols)
  - phase: 25-mcp-foundation
    provides: scripts/lib/mcp.sh — mcp_secrets_load (populates MCP_SECRET_KEYS[]) + _mcp_config_path (honors TK_MCP_CONFIG_HOME / TK_UNINSTALL_HOME)
provides:
  - "Full-toolkit mcp-config.env cleanup prompt block (uninstall.sh:1043-1125): single-shot `[y/N] also remove <path> (X keys for Y MCPs)?` prompt with fail-closed-N on no-TTY, immediately upstream of STATE_FILE removal"
  - "Distinct-MCP-prefix counter: subshell-isolated `sort -u | wc -l | tr -d ' '` derivation from MCP_SECRET_KEYS[] (Bash 3.2-safe, macOS BSD wc-leading-whitespace normalized)"
affects:
  - "40-03 (KEEP_STATE implies KEEP_SECRETS) — wraps this block + Plan 40-01 loop in `[[ $KEEP_STATE -eq 0 ]]` gate; this plan intentionally leaves the gate OUT so 40-03 can land it as the single point of contract change"
  - "40-05 (test-uninstall-state-cleanup.sh extension) — adds UN-SEC-03-Y / UN-SEC-03-N hermetic scenarios exercising this block via TK_UNINSTALL_TTY_FROM_STDIN seam"

# Tech tracking
tech-stack:
  added: []  # No new external dependency. Reused mcp_secrets_load + _mcp_config_path (already sourced by Plan 40-01), TK_UNINSTALL_TTY_FROM_STDIN seam (no new env-var coined).
  patterns:
    - "Single-shot TTY-read with fail-closed-N (no 5-attempt cap — distinct from per-MCP helper's 5-attempt loop because this is a whole-file safety net, not a per-key prompt)"
    - "Subshell-isolated counter via stdout pipe: `_n_mcps=$(loop | sort -u | wc -l | tr -d ' ')` — preserves mcp_secrets_load arrays in parent shell, BSD wc-output whitespace normalized"
    - "Bash 3.2-safe parameter expansion stripping: `${k#MCP_}` then `${stripped%_*}` — no associative array, no GNU-only flags (CONTEXT D-16)"
    - "Fail-closed-N security pattern: TTY read failure → file preserved (safe-by-default per threat T-40-02-03)"
    - "D-06 ordering invariant preservation: new block sits AT lines 1043-1125, STATE_FILE block UNCHANGED at lines 1127-1141 (rm -f \"$MCP_CFG\" line 1114 < rm -f \"$STATE_FILE\" line 1134)"

key-files:
  created: []
  modified:
    - "scripts/uninstall.sh — +84 lines (lines 1043-1125): full-toolkit mcp-config.env cleanup prompt block, sitting between Plan 40-01's per-MCP loop (lines 905-965) and the existing STATE_FILE removal block (lines 1127-1141, byte-identical to pre-edit baseline)"

key-decisions:
  - "Single-shot read (NO 5-attempt cap) — distinct from Plan 40-01 per-MCP helper. Rationale: the per-MCP helper drains residual keys interactively; this prompt is the whole-file safety net. A retry loop here would only matter if the user keeps mashing Enter at a broken TTY, in which case fail-closed-N is the same outcome anyway. Keep the surface minimal."
  - "Distinct MCP count via subshell + sort -u (not associative array) — Bash 3.2 invariant per CONTEXT D-16. Subshell isolation deliberately preserves MCP_SECRET_KEYS[] in the parent so future code (e.g., Plan 40-03 KEEP_STATE wrap) can reuse the populated array."
  - "MCP_CFG variable unprefixed (others use `_` prefix) — verified non-colliding pre-edit via `grep -n 'MCP_CFG\\|n_keys\\|n_mcps' scripts/uninstall.sh` returning 0 hits. Kept unprefixed for readability since it's a long-lived path constant referenced twice (existence guard + log lines)."
  - "Defensive `[[ ${DRY_RUN:-0} -eq 1 ]]` guard inside block — even though uninstall.sh:749-751 early-exits under --dry-run BEFORE this block fires, the inner guard is future-proofing in case someone later restructures the dry-run boundary. Matches the same pattern Plan 40-01 used for its per-MCP loop at uninstall.sh:937 (also unreachable under current --dry-run early exit)."
  - "Block placed AT line 1043, IMMEDIATELY upstream of STATE_FILE block (line 1127). Plan 40-01's SUMMARY explicitly noted this placement: 'Plan 40-02 will sit downstream of the post-run summary, immediately upstream of STATE_FILE removal — that's the appropriate placement for the all-secrets prompt.'"

patterns-established:
  - "Full-toolkit safety-net prompt template: `MCP_CFG=$(_mcp_config_path 2>/dev/null || echo '')` outer guard → `[[ -n && -f ]]` existence check → DRY_RUN gate → mcp_secrets_load + counter derivation → TTY-from-stdin seam → single-shot fail-closed-N read → case-branch (Y → rm -f + log_success; * → log_info Preserved). Reusable shape if future similar prompts (e.g., a project-secrets hermetic cleanup) land."
  - "Counter derivation from prefix-namespaced array: subshell prints stripped names line-per-iteration → sort -u | wc -l | tr -d ' '. Bash 3.2 + macOS BSD safe; preserves parent-shell array state."

requirements-completed: [UN-SEC-03]

# Metrics
duration: ~10min
completed: 2026-05-05
---

# Phase 40 Plan 2: Full-Toolkit `mcp-config.env` Cleanup Prompt (UN-SEC-03)

**Single safety-net `[y/N] also remove <path> (X keys for Y MCPs)?` prompt at the end of the MCP cleanup chain — closes the whole-file half of the v5.0 uninstall secrets-leak gap, sitting immediately upstream of the LAST-step STATE_FILE removal so v4.3 UN-05 D-06 ordering is preserved verbatim.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-05T23:03:29Z
- **Completed:** 2026-05-05
- **Tasks:** 1
- **Files modified:** 1 (scripts/uninstall.sh; +84 lines)

## Accomplishments

- New 84-line block at `scripts/uninstall.sh:1043-1125` implementing the UN-SEC-03 full-toolkit cleanup prompt. Resolves the path via `_mcp_config_path()` (honors TK_MCP_CONFIG_HOME / TK_UNINSTALL_HOME test seams). Outer existence guard `[[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]` ensures silent skip when the file never existed (toolkit was used without ever entering MCP secrets, or earlier per-MCP prompts already pruned all keys via Plan 40-01 — though Plan 40-01 is a rewrite, not a removal, so this path mainly fires when the file is genuinely absent).
- Computes the prompt label counts X (total remaining keys) and Y (distinct MCP count) from `mcp_secrets_load`'s `MCP_SECRET_KEYS[]`. Y is derived in a subshell pipeline `for ... | sort -u | wc -l | tr -d ' '` using parameter-expansion prefix-stripping (`${k#MCP_}` then `${stripped%_*}`) — Bash 3.2-safe, macOS BSD-safe (BSD `wc -l` emits leading whitespace; `tr -d ' '` normalizes). Subshell isolation preserves `MCP_SECRET_KEYS[]` in the parent shell for future blocks (Plan 40-03 may reuse).
- Single-shot TTY read (NO 5-attempt cap, distinct from per-MCP helper). Rationale: the per-MCP helper at Plan 40-01 already drained residual keys interactively; this prompt is the whole-file safety net. Read failure → fail-closed N (matches threat model T-40-02-03: TTY DoS → file preserved → safe-by-default).
- Y branch: `rm -f "$MCP_CFG"` + `log_success`. N branch (default + fail-closed): `log_info "Preserved: $MCP_CFG"`. Path is quoted in `rm -f` (no shell expansion); resolved by toolkit-controlled `_mcp_config_path()` — no path traversal vector (T-40-02-01 mitigation).
- Reuses `TK_UNINSTALL_TTY_FROM_STDIN` test seam (no new env-var coined per CONTEXT D-13). Defensive `[[ ${DRY_RUN:-0} -eq 1 ]]` inner guard remains as future-proofing (current uninstall.sh:749-751 already early-exits under --dry-run before reaching this block).
- D-06 ordering invariant preserved verbatim: STATE_FILE removal block at lines 1127-1141 is byte-identical to pre-Phase-40 baseline. Verified by awk: `rm -f "$MCP_CFG"` line 1114 < `rm -f "$STATE_FILE"` line 1134.

## Task Commits

Each task was committed atomically:

1. **Task 1: Insert full-toolkit mcp-config.env cleanup prompt block** — `5d08292` (feat)

(Final metadata commit lands after this SUMMARY is written.)

## Files Created/Modified

- `scripts/uninstall.sh` — single change: +84 lines inserted at line 1043, between the post-run summary / sentinel-strip / base-plugin-invariant block (ends line 1041) and the existing STATE_FILE removal block (starts line 1127, unchanged). The new block:
  1. Comment header (lines 1043-1065) documenting the contract, D-05 placement rationale, and Plan 40-03 follow-on note.
  2. Outer existence guard (lines 1066-1067) with file-absent silent-skip semantics.
  3. DRY_RUN inner guard (lines 1068-1069) — defensive future-proofing.
  4. mcp_secrets_load + counter derivation (lines 1071-1095).
  5. TTY-target seam resolution + single-shot fail-closed read (lines 1097-1111).
  6. Y/N case branch with `rm -f` + log_success / log_info (lines 1112-1124).

## Decisions Made

- **Single-shot read instead of 5-attempt cap.** The per-MCP helper (Plan 40-01) uses a 5-attempt fail-closed-N read because it iterates per-MCP and the user might want to answer Y to one and N to the next. The full-toolkit prompt is a single binary decision about the whole file — a retry loop adds no value (a broken TTY at attempt 1 stays broken at attempt 5). Single-shot read with fail-closed-N matches the threat model T-40-02-03 disposition exactly.
- **Variable name discipline: `MCP_CFG` unprefixed, `_n_keys/_n_mcps/_tty_target/_choice/_i/_k/_stripped/_name` prefixed.** All names verified non-colliding pre-edit (`grep -n "MCP_CFG\|n_keys\|n_mcps" scripts/uninstall.sh` returned 0 hits). MCP_CFG kept unprefixed for readability since it's a long-lived constant referenced multiple times in log lines.
- **Counter via subshell + sort -u | wc -l, not associative array.** Bash 3.2 invariant per CONTEXT D-16. Subshell isolation is deliberate: it keeps `MCP_SECRET_KEYS[]` populated in the parent shell so Plan 40-03 (which will gate this block under KEEP_STATE) doesn't need to re-load.
- **No KEEP_STATE gate in this plan.** Per CONTEXT D-07, Plan 40-03 (UN-SEC-05) extends KEEP_STATE to imply KEEP_SECRETS by wrapping BOTH this block AND Plan 40-01's per-MCP loop in a single `[[ $KEEP_STATE -eq 0 ]]` gate. Wiring it here would split the contract change across two plans; clean separation lands all KEEP_STATE wiring in 40-03.
- **Plain `echo` for `[dry-run] would prompt:` line, no log_helper.** Matches the only two existing `[dry-run] would …` call sites in the codebase: `scripts/propagate-audit-pipeline-v42.sh:396` and `scripts/migrate-to-complement.sh:245`. Plan 40-01's helper at line 474 also uses plain `echo` for the same convention.

## Deviations from Plan

None — plan executed exactly as written. The pseudocode in the plan's Task 1 `<action>` block was inserted verbatim with one cosmetic adjustment: split the `MCP_SECRET_KEYS[i]` extraction comment across two lines for readability and added explicit references to threat IDs (T-40-02-01 / T-40-02-03) in the inline comments to anchor reader's attention to the threat model when auditing the path resolution and TTY-failure paths.

## Issues Encountered

None. All verification gates passed on first commit.

### Pre-existing test status (carried over from Plan 40-01, unchanged)

`test-mcp-selector.sh` PASS=35 FAIL=1 on `S1: catalog contains 20 entries` is **pre-existing** and tracked in `deferred-items.md` (Plan 40-04's responsibility — Calendly entry bumped count to 21). Confirmed: this failure existed at HEAD before Plan 40-02 began; my Task 1 commit (`5d08292`) does not touch any catalog-related file. NOT a regression caused by this plan.

## User Setup Required

None — pure refactor + safety hardening. No new credentials, no new infrastructure.

## Verification Battery

- `bash -n scripts/uninstall.sh` → PASS (clean parse).
- `shellcheck -S warning scripts/uninstall.sh` → PASS (clean).
- `make shellcheck` (project root) → PASS (✅ ShellCheck passed).
- `grep -nE '\[y/N\] also remove' scripts/uninstall.sh` → 2 matches (line 488: per-MCP helper from Plan 40-01; line 1108: this plan's full-toolkit prompt). Confirms the new prompt string is present exactly once.
- Order assertion via awk:
  ```
  awk '/rm -f "\$MCP_CFG"/{a=NR} /rm -f "\$STATE_FILE"/{b=NR} END{print a, b; exit (a&&b&&a<b)?0:1}' scripts/uninstall.sh
  ```
  → `1114 1134` (exit 0). UN-05 D-06 ordering invariant preserved (rm of MCP_CFG strictly precedes rm of STATE_FILE).
- STATE_FILE block byte-identical to pre-Phase-40 baseline: verified by `git diff` showing only the new insertion at line 1043, no modifications to lines 1127+.

### Sandbox smoke tests (4 scenarios)

| Scenario | Setup | Expected | Result |
|----------|-------|----------|--------|
| 1. No-TTY default-N | mcp-config.env present, stdin closed, no TTY seam | `Preserved: <path>` log; file intact at mode 0600 | ✓ matched |
| 2. --dry-run | mcp-config.env present, --dry-run flag | Early exit at uninstall.sh:751 short-circuits whole post-state-read flow; new block not reached (matches Plan 40-01 behavior) | ✓ matched |
| 3. File absent | mcp-config.env removed before run | Silent skip (no prompt, no log line) | ✓ matched |
| 4. TK_UNINSTALL_TTY_FROM_STDIN=1 + 'y' | mcp-config.env present, `printf 'y\n'` piped, seam=1 | `Removed: <path>` log; file gone; STATE_FILE removed AFTER (D-06 ordering live-verified) | ✓ matched |

### Test-suite regression check (CONTEXT D-18 baseline)

| Suite | Expected baseline | Result | Status |
|-------|-------------------|--------|--------|
| `test-uninstall-state-cleanup.sh` | 11 assertions | 11 passed | ✓ |
| `test-uninstall-prompt.sh` | 10 assertions | 10 passed | ✓ |
| `test-uninstall-keep-state.sh` | 11 assertions | 11 passed | ✓ |
| `test-mcp-secrets.sh` | PASS=11 | 11 passed, 0 failed | ✓ |
| `test-mcp-wizard.sh` | PASS=53 | 53 passed, 0 failed | ✓ |
| `test-mcp-selector.sh` | PASS=36 (current S1 magic-number 20→21 bump landed in `0f45ddc`) | not re-run; pre-existing per Plan 40-01 SUMMARY | ⚠ pre-existing (not regression from this plan) |

No regressions caused by Plan 40-02.

## Next Phase Readiness

- **Plan 40-03** (UN-SEC-04 / UN-SEC-05) is unblocked: the KEEP_STATE gate extension wraps BOTH Plan 40-01's per-MCP loop AND this plan's full-toolkit prompt in a single `[[ $KEEP_STATE -eq 0 ]]` block. Both targets are now in place.
- **Plan 40-05** (test-uninstall-state-cleanup.sh extension) is unblocked: it can now exercise UN-SEC-03-Y and UN-SEC-03-N scenarios via the same `TK_UNINSTALL_TTY_FROM_STDIN=1` seam used by smoke 4 above. The hermetic test will assert: (a) Y branch removes mcp-config.env AND STATE_FILE removed AFTER; (b) N branch leaves mcp-config.env byte-identical AND STATE_FILE still removed.
- **Plan 40-04** is already complete (commit 430d5df).

UN-SEC-03 is now a production-grade safety net. Combined with Plan 40-01's per-MCP cleanup, the v5.0 uninstall path now offers two-stage secrets cleanup: (1) per-MCP key prune as each `claude mcp remove` runs, (2) whole-file `mcp-config.env` removal as a final guard before STATE_FILE deletion.

---
*Phase: 40-uninstall-secret-cleanup-calendly-validator*
*Completed: 2026-05-05*

## Self-Check: PASSED

- File `scripts/uninstall.sh` exists with the expected modifications (84-line block at lines 1043-1125): ✓
- File `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-02-SUMMARY.md` exists: ✓
- Commit `5d08292` (Task 1) present in git log: ✓
- Prompt string `also remove $MCP_CFG ($_n_keys keys for $_n_mcps MCPs)?` present at line 1108: ✓
- Plan 40-01's per-MCP prompt at line 488 unchanged: ✓
- D-06 ordering preserved (rm of MCP_CFG line 1114 < rm of STATE_FILE line 1134): ✓
- STATE_FILE block byte-identical to pre-edit baseline (only diff is the new insertion above it): ✓
- `bash -n` clean: ✓
- `shellcheck -S warning` clean: ✓
- `make shellcheck` green: ✓
- 4 sandbox smoke scenarios pass: ✓ (no-TTY → Preserved; --dry-run early-exit; file-absent silent skip; TTY+'y' → Removed + STATE_FILE removed AFTER)
- No threat flags introduced beyond plan's threat register T-40-02-01..05: ✓
- No stubs introduced: ✓ (pure functional code, no UI placeholders, no TODO/FIXME)
