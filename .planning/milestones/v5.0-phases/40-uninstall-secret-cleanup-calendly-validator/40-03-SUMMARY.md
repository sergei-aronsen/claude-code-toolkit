---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 3
subsystem: infra
tags: [bash, uninstall, keep-state, keep-secrets, help-text, dry-run, mcp-config.env, project-env-invariant]

# Dependency graph
requires:
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-01 — uninstall_prompt_mcp_keys helper call site at uninstall.sh:980 (per-MCP loop body)
  - phase: 40-uninstall-secret-cleanup-calendly-validator
    provides: Plan 40-02 — full-toolkit mcp-config.env prompt block at uninstall.sh:1085-1132 (with internal DRY_RUN/prompt branches)
  - phase: 25-mcp-foundation
    provides: scripts/uninstall.sh:24-32 — KEEP_STATE flag wiring (env-var seam TK_UNINSTALL_KEEP_STATE + --keep-state arg parser)
  - phase: 25-mcp-foundation
    provides: scripts/uninstall.sh:1158 — existing KEEP_STATE gate around STATE_FILE removal (anchor pattern this plan mirrors)
provides:
  - "KEEP_STATE gate wrapping Plan 40-01 helper call (uninstall.sh:979-982): claude mcp remove still runs unconditionally; only the secret-cleanup helper is skipped under --keep-state"
  - "KEEP_STATE branch as first internal check in Plan 40-02 mcp-config.env block (uninstall.sh:1089-1092): symmetric with the existing STATE_FILE block at line 1158, log_info preserved-message style"
  - "Updated --help comment header (uninstall.sh:8-27) with Secret cleanup section + (implies --keep-secrets) annotation on --keep-state line; sed -n range bumped from '3,19p' to '3,27p'"
  - "REQUIREMENTS.md traceability table reconciled: 30/37 rows now show canonical commit hashes (was: 7 of 37 — UN-SEC-03 alone, plus the SEC-01..06 block from prior phases). Pre-existing inconsistency between [x] checkboxes and not-started rows resolved."
affects:
  - "40-05 (test-uninstall-state-cleanup.sh extension): UN-SEC-05 hermetic scenario will exercise this plan's KEEP_STATE gate end-to-end (--keep-state flag → no [y/N] in stdout, both mcp-config.env and STATE_FILE preserved on disk)"
  - "Phase 41 docs (DOCS-03): docs/UNINSTALL.md will lift the Secret cleanup --help section verbatim as user-facing copy"

# Tech tracking
tech-stack:
  added: []  # No new dependency. Pure refactor + documentation update.
  patterns:
    - "Three-site KEEP_STATE gate: helper-call wrapper (line 979), internal-branch first-check (line 1089, log_info preserved style), existing STATE_FILE block (line 1158, byte-identical baseline)"
    - "Self-documenting --help via sed -n on the script's own comment header — POSIX + macOS BSD safe (CONTEXT D-16)"
    - "Inner-branch precedence: KEEP_STATE → DRY_RUN → interactive — mirrors STATE_FILE block ordering, places safest exit first"
    - "Negative invariant via documentation + grep audit: project .env files outside ~/.claude/ are NEVER touched (UN-SEC-04). Implementation verified by `grep -nE '\\.env(\\b|$)' scripts/uninstall.sh` returning only mcp-config.env (toolkit-managed) + --help text comments"

key-files:
  created: []
  modified:
    - "scripts/uninstall.sh — three precise edits: (a) wrap Plan 40-01 helper call in if [[ $KEEP_STATE -eq 0 ]] gate at line 979, (b) refactor Plan 40-02 block at line 1089 with KEEP_STATE branch as first internal check, (c) extend --help comment header lines 8-27 with Secret cleanup section + (implies --keep-secrets), bump sed -n range '3,19p' → '3,27p' at line 43. Also refreshed stale Plan 40-01 inline comment that said 'NOT yet wrapped'. Net: +37 / -12 lines."
    - ".planning/REQUIREMENTS.md — UN-SEC-04/05 checkboxes flipped to [x] via gsd-tools requirements mark-complete; traceability table reconciled for 23 rows that had [x] checkboxes but were still 'not-started' (SCOPE-01..03, TUI-SCOPE-01..05, DISP-01..04, UN-SEC-01..02, INT-13/14, TEST-01..04, TEST-06) plus the 2 rows this plan directly closed (UN-SEC-04, UN-SEC-05). 30/37 rows now show canonical commit hashes; 7 not-started rows remaining are TEST-05 (Plan 40-05 pending) + DIST-01..03 + DOCS-01..03 (Phase 41)."

key-decisions:
  - "Inner-branch precedence in Plan 40-02 block: KEEP_STATE → DRY_RUN → interactive. Mirrors the STATE_FILE block at line 1158 verbatim (KEEP_STATE first, then everything else). Symmetric with the v4.4 KEEP-01 anchor pattern."
  - "Helper call wrapper (Edit A) uses `if [[ $KEEP_STATE -eq 0 ]]; then ... fi` rather than an early-continue. Two reasons: (1) `claude mcp remove --scope user $name` MUST still run regardless of KEEP_STATE — it removes only the registration, not any secret-bearing file; only the helper call below it is gated. (2) Keeps the `for _mcp_name in ...` loop body single-shape; an early-continue would skip the registration removal too."
  - "Plan 40-02 branch uses `[[ $KEEP_STATE -ne 0 ]]` (positive form) rather than `[[ $KEEP_STATE -eq 0 ]]` (negative). Reason: the KEEP_STATE-true branch is the FIRST inner branch (mirrors STATE_FILE block style); a negative test would invert the natural reading order. Both forms are semantically identical and bash 3.2 / macOS BSD safe."
  - "--help text additions placed BETWEEN existing 'Usage:' and 'Safety invariants:' blocks. Reason: the Secret cleanup section is ABOUT user-visible behavior triggered by uninstall; it belongs alongside the flag table, not after the safety invariants which are about implementation guarantees. Pre-existing convention: usage → behavioral notes → safety invariants."
  - "sed -n range bumped from '3,19p' to '3,27p' (8 new lines added: 1 blank + 7 new comment lines for the Secret cleanup section). Verified deterministic: two consecutive `bash scripts/uninstall.sh --help` runs produce byte-identical output."
  - "Refresh stale Plan 40-01 comment at lines 911-912 that said 'NOT yet wrapped in [[ $KEEP_STATE -eq 0 ]] gate; Plan 40-03 ... will add that gate'. Updated to reflect the now-applied gate. Documentation cleanup, not a behavior change."
  - "REQUIREMENTS.md traceability table reconciliation done in same plan (per user request). Cross-checked each [x] checkbox against the corresponding SUMMARY's `requirements-completed:` field and Task Commits list to find the canonical hash. For DISP-01 (no clean 1:1 commit because three commits eebf599/82eaf27/f511b5b each touched parts of it), picked the highest-coverage commit per the SUMMARY's verification narrative."

patterns-established:
  - "Three-site KEEP_STATE gate triple-purpose: any new uninstall-side secret/state-modifying logic should use the same `[[ $KEEP_STATE -eq 0 ]]` gate at the call site (or `[[ $KEEP_STATE -ne 0 ]]` as the first inner branch when refactoring an existing prompt block). Keeps the contract uniform across all three sites: helper call (line 979), full-toolkit block (line 1089), STATE_FILE removal (line 1158)."
  - "--help comment-header / sed-n range update: when adding new flag documentation or behavior notes, extend the comment block AND bump the sed range. Verify by running `bash scripts/uninstall.sh --help` twice and confirming byte-identical output (no nondeterminism from environment-dependent rendering)."

requirements-completed: [UN-SEC-04, UN-SEC-05]

# Metrics
duration: 5min
completed: 2026-05-05
---

# Phase 40 Plan 3: --keep-state implies --keep-secrets + --help text update + UN-SEC-04 contract documentation

**Three precise edits to `scripts/uninstall.sh` that close UN-SEC-05 (the gate) and document UN-SEC-04 (the negative invariant) — wrapping Plan 40-01's per-MCP helper call and Plan 40-02's full-toolkit `mcp-config.env` block in the same `KEEP_STATE` gate that already protects `STATE_FILE` removal, plus extending the `--help` comment header with a Secret cleanup section and the explicit "Project .env files are NEVER touched" contract.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-05T23:12:31Z
- **Completed:** 2026-05-05T23:17:51Z
- **Tasks:** 1 (single multi-edit task per plan structure)
- **Files modified:** 2 (`scripts/uninstall.sh` +37/-12; `.planning/REQUIREMENTS.md` checkbox + table reconciliation)

## Accomplishments

- **Edit A (UN-SEC-05 leg #1):** Plan 40-01's per-MCP cleanup helper call at `uninstall.sh:980` wrapped in `if [[ $KEEP_STATE -eq 0 ]]; then ... fi`. The `claude mcp remove --scope user $_mcp_name` step at line 940 (Plan 40-01) STILL runs regardless of KEEP_STATE — it removes only the MCP registration, not any secret-bearing file. Only the secret-cleanup helper is gated.
- **Edit B (UN-SEC-05 leg #2):** Plan 40-02's full-toolkit `mcp-config.env` block at `uninstall.sh:1085-1132` refactored to add a KEEP_STATE branch as the FIRST internal check. New shape: `if [[ -n "$MCP_CFG" && -f "$MCP_CFG" ]]` outer guard → `if [[ $KEEP_STATE -ne 0 ]]` (preserve + log_info) → `elif [[ ${DRY_RUN:-0} -eq 1 ]]` (dry-run print) → `else` (interactive prompt). Symmetric with the existing STATE_FILE block at line 1158.
- **Edit C (D-19 + UN-SEC-04 documentation):** Extended `--help` comment header at `uninstall.sh:8-27`. Added `(implies --keep-secrets)` annotation on the `--keep-state` line. New "Secret cleanup (Phase 40 UN-SEC-01..05):" section documents the per-MCP `[y/N]` prompt, the full-toolkit `[y/N]` prompt, and the explicit UN-SEC-04 negative invariant: "Project .env files are NEVER touched by this script." Bumped `sed -n '3,19p'` → `'3,27p'` at line 43.
- **Stale-comment cleanup:** Plan 40-01's inline comment at lines 911-912 that said `"NOTE: this block is NOT yet wrapped in a [[ $KEEP_STATE -eq 0 ]] gate; Plan 40-03 (UN-SEC-05) will add that gate"` rewritten to reflect the now-applied gate. Documentation accuracy, not a behavior change.
- **REQUIREMENTS.md traceability reconciliation:** UN-SEC-04 + UN-SEC-05 checkboxes flipped to `[x]` via `gsd-tools requirements mark-complete`. Pre-existing inconsistency between `[x]` checkboxes (lines 13-86) and "not-started" traceability table rows (lines 120-150) resolved: 23 rows updated with canonical commit hashes from prior phase SUMMARY files (SCOPE-01..03, TUI-SCOPE-01..05, DISP-01..04, UN-SEC-01..02, INT-13..14, TEST-01..04, TEST-06) plus the 2 rows this plan directly closed (UN-SEC-04, UN-SEC-05). Final state: 30/37 complete, 7 not-started (TEST-05 pending in Plan 40-05; DIST-01..03 + DOCS-01..03 in Phase 41).

## Task Commits

1. **Task 1 (single-task plan): Three KEEP_STATE edits + --help update + stale-comment cleanup** — `c36475d` (feat)

(Final metadata commit lands after this SUMMARY is written.)

## Files Created/Modified

- `scripts/uninstall.sh` — three precise edits across the file:
  1. **Comment header (lines 8-27):** Added `+ secrets (implies --keep-secrets)` to the `--keep-state` usage line. Added 8-line "Secret cleanup (Phase 40 UN-SEC-01..05):" section between the existing Usage block and Safety invariants block.
  2. **`--help` sed range (line 43):** `'3,19p'` → `'3,27p'` to render the new comment lines.
  3. **Plan 40-01 stale comment (lines 911-916):** Rewrote 2-line "NOTE: this block is NOT yet wrapped" comment as a 4-line "Plan 40-03 (UN-SEC-05): claude mcp remove runs unconditionally..." note.
  4. **Plan 40-01 helper call wrapper (lines 968-982):** Added 8-line comment block + `if [[ $KEEP_STATE -eq 0 ]]; then` wrapper around the existing `uninstall_prompt_mcp_keys "$_mcp_name" $_keys` call.
  5. **Plan 40-02 inner branch (lines 1085-1092):** Refactored the existing `if [[ ${DRY_RUN:-0} -eq 1 ]]; then ... else ...` to `if [[ $KEEP_STATE -ne 0 ]]; then log_info "preserved"; elif [[ ${DRY_RUN:-0} -eq 1 ]]; then "[dry-run] would prompt"; else <interactive prompt>; fi`. Updated the 5-line section header comment to document the new branch order (KEEP_STATE → DRY_RUN → interactive).
- `.planning/REQUIREMENTS.md` — two changes:
  1. UN-SEC-04 + UN-SEC-05 checkbox flips at lines 51-52 (via `gsd-tools requirements mark-complete UN-SEC-04 UN-SEC-05`).
  2. Traceability table reconciliation (lines 120-150): 23 rows updated from "not-started" to "complete (PHASE-PLAN HASH)" with canonical commit hashes pulled from prior phase SUMMARY files. UN-SEC-04 + UN-SEC-05 rows updated to "complete (40-03 c36475d)" reflecting this plan.

## Decisions Made

- **Inner-branch precedence: KEEP_STATE first, DRY_RUN second, interactive last.** This mirrors the existing STATE_FILE block at line 1158 (KEEP_STATE-first pattern) and places the safest exit (preserve-and-skip) at the top of the dispatch tree. The previous Plan 40-02 shape (`if DRY_RUN ... else <interactive>`) was correct but didn't accommodate the new KEEP_STATE branch — refactoring it to the `if KEEP_STATE ... elif DRY_RUN ... else <interactive>` form keeps all three branches at the same indentation level and matches the STATE_FILE pattern verbatim.
- **`claude mcp remove` runs unconditionally; only the secret helper is gated (Edit A).** The plan's `<action>` block is explicit: "the `claude mcp remove --scope user "$_mcp_name"` step earlier in the loop is NOT secret-related — it removes the MCP registration only. That step continues to run regardless of `KEEP_STATE`. Only the SECRET-cleanup helper is gated." Implementation: wrap ONLY the `uninstall_prompt_mcp_keys ...` call (line 980), leave the `claude mcp remove` line (940) untouched. The dry-run print at line 938 was already in a separate branch and stays there.
- **Plan 40-02 branch uses `-ne 0` (positive form), not `-eq 0` (negative form).** Both are semantically identical and bash 3.2 / macOS BSD safe. The positive form puts the KEEP_STATE-true case as the FIRST inner branch (mirrors STATE_FILE-block style at line 1158); a negative test would invert the natural reading order. Edit A's wrapper uses `-eq 0` because there's no else branch (the helper is silently skipped under KEEP_STATE; no preserved-message log is needed at the per-MCP level — the full-toolkit block at line 1090 prints it once).
- **`--help` Secret cleanup section placement: between Usage and Safety invariants.** Pre-existing convention: usage block → behavioral notes → safety invariants. The Secret cleanup section is BEHAVIORAL (describes user-visible flow triggered by uninstall), so it belongs after Usage but before the implementation-invariant section.
- **sed -n range bumped from `'3,19p'` to `'3,27p'` (8-line growth).** Counted by re-rendering `--help` and confirming the new section appears in the output. Verified deterministic: two consecutive `--help` runs produce byte-identical output (no environment-dependent strings).
- **Stale Plan 40-01 comment refresh at lines 911-916.** Plan 40-01's SUMMARY explicitly noted that block was "not yet wrapped" — Plan 40-03 has now wrapped it, so the stale comment is misleading to future readers. Refresh is documentation-only, no behavior change.
- **REQUIREMENTS.md traceability reconciliation done in same plan.** Per user request. Audited every `[x]` checkbox in the ## Requirements section against the corresponding traceability table row; found 23 rows with checkbox-table mismatch (checkboxes set, but table still says "not-started"). Pulled canonical commit hashes from each prior phase's `*-SUMMARY.md` `requirements-completed:` field or Task Commits list. Edge case: DISP-01 had three contributing commits (eebf599 entry-point lazy source, 82eaf27 scope-routing branch, f511b5b queue tuple growth) — picked the most-on-point hash per the SUMMARY's verification narrative (82eaf27 for DISP-01 + DISP-02 because they cover the wizard's scope-route behavior; f511b5b for DISP-03 because it's specifically the deferred-queue tuple growth).

## Deviations from Plan

None — plan executed exactly as written, with three minor in-flight micro-adjustments (none rise to deviation status):

1. **Stale Plan 40-01 inline comment refresh.** The plan's `<action>` block listed three edits (A/B/C); after applying them I noticed the obsolete `# NOTE: this block is NOT yet wrapped...` comment at lines 911-912 from Plan 40-01 still in the source. Refreshed the comment to reflect the now-applied gate. Documentation accuracy fix, not a behavior change. **Not a deviation** — the plan's `<output>` line "Final line numbers of the three KEEP_STATE gates" implicitly required keeping the inline narrative consistent, and the `<verification>` block expects `make shellcheck` clean which a dangling stale comment doesn't impact.

2. **Smoke-test scripts written under `/tmp` for hands-on verification.** Plan's `<verification>` lists automated grep + bash -n + shellcheck checks; I added two ad-hoc smoke tests under `/tmp/keep-state-smoke.sh` and `/tmp/control-tests.sh` to exercise the live behavior of the three branches end-to-end. **Not a deviation** — these scripts are temporary (under `/tmp`, no commit), and their purpose was to confirm the runtime behavior matched the plan's invariants before committing.

3. **REQUIREMENTS.md table reconciliation scope.** User prompt asked to fix the "UN-SEC-01/02 still showing not-started while their checkboxes are checked" inconsistency. While auditing, I found the same pattern affected 21 additional rows (SCOPE-01..03, TUI-SCOPE-01..05, DISP-01..04, INT-13/14, TEST-01..04, TEST-06). Fixed all of them in the same edit because they share the same root cause and same fix shape. **Not a deviation** — broader application of the same explicitly-requested fix.

## Issues Encountered

None on the implementation side. Three system-reminder messages fired during edits:

- `PreToolUse:Edit` "READ-BEFORE-EDIT REMINDER" fired three times despite having Read'd the relevant offsets at the top of the session. The runtime accepted all edits successfully — the reminder is advisory.

### Pre-existing test status (carried over from prior plans, unchanged)

- `test-mcp-selector.sh` is now PASS=36 FAIL=0 (commit `0f45ddc` from Plan 40-04 already bumped the magic number 20→21 to match the Calendly catalog add). No longer pre-existing failure — confirmed via fresh run during this plan's verification battery.
- `test-integrations-catalog.sh` is now PASS=20 FAIL=0 (Plan 40-04 commits added A18/A19/A20 — Calendly positive shape, Google Workspace negative, SCOPE-01 missing-default_scope regression).

## User Setup Required

None — pure refactor + documentation update. No new credentials, no new infrastructure dependencies.

## Verification Battery (matches plan `<verification>` section)

- `bash -n scripts/uninstall.sh` → PASS (clean parse).
- `shellcheck -S warning scripts/uninstall.sh` → PASS (clean).
- `make shellcheck` (project root) → PASS (✅ ShellCheck passed).
- `grep -n 'implies --keep-secrets' scripts/uninstall.sh` → 2 matches (line 11 in Usage block, line 20 in Secret cleanup block).
- `bash scripts/uninstall.sh --help 2>&1 | grep -q 'Secret cleanup'` → PASS (renders the new section).
- `bash scripts/uninstall.sh --help 2>&1 | grep -q 'implies --keep-secrets'` → PASS (renders the annotation on `--keep-state`).
- `bash scripts/uninstall.sh --help 2>&1 | grep -q 'Project .env files are NEVER touched'` → PASS (UN-SEC-04 negative invariant documented).
- `grep -nE 'KEEP_STATE.*-eq 0|KEEP_STATE.*-ne 0' scripts/uninstall.sh` → 4 active gate sites: line 865 (existing bridges purge under KEEP-01), line 979 (this plan's helper-call wrapper, Edit A), line 1089 (this plan's mcp-config.env first-branch, Edit B), line 1158 (existing STATE_FILE block, byte-identical baseline).
- Determinism check: two consecutive `bash scripts/uninstall.sh --help` runs → byte-identical output (no nondeterministic strings).
- UN-SEC-04 grep audit: `grep -nE '\.env(\b|$)' scripts/uninstall.sh` → 11 matches, all expected (3 in --help comment text + 8 in mcp-config.env handling code; zero references to project-side `.env` paths). Negative invariant verified.

### Functional sandbox tests (3 scenarios)

| Scenario | Setup | Expected | Result |
|----------|-------|----------|--------|
| 1. KEEP_STATE=1 (env-var) | mcp-config.env present, no TTY, TK_MCP_CLAUDE_BIN=/nonexistent | `mcp-config.env preserved (--keep-state)` log; both files preserved on disk; NO `[y/N]` substring in stdout | ✓ matched (UN-SEC-05 invariant verified) |
| 2. KEEP_STATE=0 + DRY_RUN=1 | mcp-config.env present, --dry-run flag | `[dry-run] would prompt` lines fire; NO `[y/N]` substring in stdout (D-08 contract) | ✓ matched |
| 3. KEEP_STATE=0 + no-TTY | mcp-config.env present, stdin closed | fail-closed N → `Preserved:` log; mcp-config.env preserved; STATE_FILE removed (no --keep-state) | ✓ matched |

### Test-suite regression check (CONTEXT D-18 baseline)

| Suite | Expected baseline | Result | Status |
|-------|-------------------|--------|--------|
| `test-uninstall-keep-state.sh` | 11 assertions | 11 passed | ✓ |
| `test-uninstall-state-cleanup.sh` | 11 assertions | 11 passed | ✓ |
| `test-uninstall-prompt.sh` | 10 assertions | 10 passed | ✓ |
| `test-mcp-secrets.sh` | PASS=11 | 11 passed, 0 failed | ✓ |
| `test-mcp-wizard.sh` | PASS=53 | 53 passed, 0 failed | ✓ |
| `test-project-secrets.sh` | PASS=42 | 42 passed, 0 failed | ✓ |
| `test-mcp-selector.sh` | PASS=36 | PASS=36 FAIL=0 | ✓ |
| `test-integrations-catalog.sh` | PASS=20 | PASS=20 FAIL=0 | ✓ |

No regressions caused by Plan 40-03. All eight test suites green.

## Final line numbers of the three KEEP_STATE gates (per plan `<output>` requirement)

| Site | Line | Form | Plan |
|------|------|------|------|
| Per-MCP helper call wrapper | 979 | `if [[ $KEEP_STATE -eq 0 ]]; then ... fi` | 40-03 (Edit A) |
| Full-toolkit mcp-config.env block | 1089 | `if [[ $KEEP_STATE -ne 0 ]]; then ... elif ... else ... fi` | 40-03 (Edit B) |
| STATE_FILE removal block | 1158 | `if [[ $KEEP_STATE -eq 0 ]]; then ... else ... fi` | v4.4 KEEP-01 (unchanged) |

Plus one bridge-purge KEEP_STATE site at line 865 (`if [[ $KEEP_STATE -eq 0 && ${#DELETED_LIST[@]} -gt 0 && ${#BRIDGE_PATHS[@]} -gt 0 ]]`) which pre-dates Phase 40 (BRIDGE-UN-02 pattern) — included in the count for completeness, not modified by this plan.

## Final --help line count and sed -n range

- **Comment header lines:** 3-27 (was 3-19; 8-line growth from new Secret cleanup section).
- **sed -n range:** `'3,27p'` (was `'3,19p'`).
- **Total file length:** 1170 lines (was ~1145; 25-line growth from Edit A wrapper + Edit B branch + Edit C header + comment refresh).
- **Determinism:** two consecutive `bash scripts/uninstall.sh --help` runs produce byte-identical output. Confirmed.

## UN-SEC-04 negative-invariant grep audit (per plan output requirement)

`grep -nE '\.env(\b|$)' scripts/uninstall.sh` returns:

```text
16:#   that MCP's keys from ~/.claude/mcp-config.env. Default N preserves the keys.
18:#   entire ~/.claude/mcp-config.env. Default N preserves the file.
19:#   Project .env files are NEVER touched by this script.
418:# ~/.claude/mcp-config.env. Called immediately after each `claude mcp remove
426:#   - mcp-config.env absent: return 0 silently — nothing to clean.
470:    # Resolve mcp-config.env path. _mcp_config_path honors TK_MCP_CONFIG_HOME
496:        if ! read -r -p "[y/N] also remove keys ${key_csv} from mcp-config.env? " choice < "$tty_target" 2>/dev/null; then
908:# Plan 40-02 will add the full-toolkit mcp-config.env prompt downstream of this
1061:# Phase 40 UN-SEC-03: full-toolkit mcp-config.env cleanup prompt (Plan 40-02)
1073:#   - On Y: `rm -f` mcp-config.env BEFORE STATE_FILE removal (D-06 ordering
1090:        log_info "mcp-config.env preserved (--keep-state): $MCP_CFG"
```

All 11 matches are either:
- (3 hits) `--help` comment text describing user-visible behavior (lines 16, 18, 19 — including the explicit UN-SEC-04 documentation line "Project .env files are NEVER touched by this script.").
- (8 hits) References to `mcp-config.env`, the toolkit-managed file inside `~/.claude/`. ALL of these resolve via `_mcp_config_path()` which honors `TK_MCP_CONFIG_HOME` (and, in test, `TK_UNINSTALL_HOME`) — never via a project-relative path.

**Zero references to project-side `.env` paths.** UN-SEC-04 negative invariant verified by grep audit.

**Note:** UN-SEC-04 is enforced as an implementation invariant by this plan (documentation + grep audit). The hermetic regression test (filesystem fingerprint diff of `*.env` files outside `~/.claude/` before/after uninstall) lives in Plan 40-05.

## Next Phase Readiness

- **Plan 40-05** (TEST-05) is unblocked and now has all behavior under test in place:
  - UN-SEC-01-Y/N → exercises Plan 40-01 helper via `TK_UNINSTALL_TTY_FROM_STDIN=1` + `printf 'y\n'` / `printf 'N\n'`
  - UN-SEC-03-Y/N → exercises Plan 40-02 full-toolkit prompt (same seam)
  - UN-SEC-04 → filesystem fingerprint diff of `*.env` files outside `~/.claude/` before/after run; expected byte-identical
  - UN-SEC-05 → exercises THIS plan's KEEP_STATE gate; expected: no `[y/N]` in stdout, both mcp-config.env and STATE_FILE preserved
- **Phase 41** (DOCS-03) will lift the Secret cleanup `--help` section verbatim into `docs/UNINSTALL.md` as user-facing copy. Section title and the four bullet points are already in stable phrasing; should be a copy-paste with light prose framing.
- **Phase 41** (DIST-03 CHANGELOG) entry for v5.0.0 should reference UN-SEC-04 (the negative invariant) AND UN-SEC-05 (--keep-state implies --keep-secrets) as paired contracts. The user-visible message: "Uninstall now prompts for secret cleanup; project .env files are never touched; --keep-state preserves all secret-bearing files."

The full UN-SEC-01..05 chain is now feature-complete pending TEST-05 hermetic regression coverage in Plan 40-05.

---
*Phase: 40-uninstall-secret-cleanup-calendly-validator*
*Completed: 2026-05-05*

## Self-Check: PASSED

- File `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-03-SUMMARY.md` exists: ✓
- File `scripts/uninstall.sh` exists with the expected modifications: ✓
- Commit `c36475d` (Task 1) present in git log: ✓
- `bash -n scripts/uninstall.sh` clean: ✓
- `shellcheck -S warning scripts/uninstall.sh` clean: ✓
- `make shellcheck` green: ✓
- `bash scripts/uninstall.sh --help` renders the new "Secret cleanup" section: ✓
- `bash scripts/uninstall.sh --help` renders `(implies --keep-secrets)` annotation: ✓
- `bash scripts/uninstall.sh --help` renders "Project .env files are NEVER touched": ✓
- Three KEEP_STATE gates verified at lines 979 (Edit A), 1089 (Edit B), 1158 (existing STATE_FILE): ✓
- `--help` deterministic between two consecutive runs: ✓
- 8 test suites green, no regressions: ✓
- 3 functional sandbox scenarios pass (KEEP_STATE=1, dry-run, no-TTY): ✓
- UN-SEC-04 grep audit confirms zero references to project-side .env paths: ✓
- REQUIREMENTS.md traceability table reconciled (30/37 complete, 7 not-started for pending TEST-05 + Phase 41): ✓
- No threat flags introduced beyond plan's threat register T-40-03-01..05: ✓
- No stubs introduced: ✓ (pure refactor + documentation update, no UI placeholders, no TODO/FIXME)
