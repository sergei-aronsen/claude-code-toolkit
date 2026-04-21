---
phase: 03-install-flow
plan: "02"
subsystem: install
tags: [install-modes, dry-run, skip-list, init-local-parity, jq, interactive-prompt, state-file, mode-change]

# Dependency graph
requires:
  - phase: 03-install-flow
    plan: "01"
    provides: scripts/lib/install.sh skeleton (MODES, recommend_mode, compute_skip_set, backup_settings_once, print_dry_run_grouped stub); detect.sh + lib/install.sh wiring in init-claude.sh and init-local.sh; manifest_version guard
  - phase: 02-foundation
    provides: scripts/lib/state.sh (write_state / read_state / acquire_lock / release_lock / STATE_FILE); manifest.json v2 schema with conflicts_with vocabulary
provides:
  - print_dry_run_grouped full implementation in scripts/lib/install.sh (grouped [INSTALL]/[SKIP]/Total output, ANSI auto-disable via [ -t 1 ])
  - --mode / --force / --force-mode-change flag parsing in init-claude.sh and init-local.sh with allowlist validation against MODES
  - Interactive select_mode() prompt in init-claude.sh with auto-recommendation via recommend_mode
  - Re-run delegation (D-41) in both installers: exit 0 with update-claude.sh hint when toolkit-install.json exists and --force is absent
  - Mode-change prompt (D-42) in both installers: --force + --mode conflict triggers y/N prompt via /dev/tty; --force-mode-change bypasses; fail-closed under curl|bash without /dev/tty
  - Per-project STATE_FILE override in init-local.sh (.claude/toolkit-install.json vs global $HOME/.claude/toolkit-install.json)
  - Manifest-driven install loop in both installers replacing static FILES=() arrays and hardcoded prompts/agents/skills/commands/rules loops
  - Test 6 (test-modes.sh) and Test 7 (test-dry-run.sh) wired into Makefile test target
  - scripts/tests/fixtures/manifest-v2.json fixture with deterministic 0/7/1/8 skip counts
affects: [03-03 (settings.json safe merge consumes the same skip-list contract), 04-update-flow (UPDATE-01 consumes $HAS_SP/$HAS_GSD and the same MODES vocabulary)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manifest-driven install loop: compute_skip_set -> jq --argjson -> while IFS= read -r entry < <(process substitution) to avoid subshell losing install counters"
    - "Interactive prompt with curl|bash fallback: [[ -e /dev/tty ]] guard + read -r < /dev/tty 2>/dev/null fallback to recommend_mode"
    - "Per-project STATE_FILE override: reassign STATE_FILE AFTER source lib/state.sh so functions read $STATE_FILE at call time (Pitfall 7)"
    - "Mode-change fail-closed under curl|bash: if read from /dev/tty fails, mc_choice defaults to N -> exit 0 without changes"
    - "ANSI auto-disable: conditional color assignment via [ -t 1 ] inside init-local.sh AFTER sourcing libs (because lib/state.sh defines RED/YELLOW/NC unconditionally)"
    - "EXTRA_FILES separation: files not in manifest.files.* (CLAUDE.md, settings.json, cheatsheets, framework-specific experts) handled via separate download_extras/cheatsheets loop"

key-files:
  created:
    - scripts/tests/fixtures/manifest-v2.json
    - scripts/tests/test-modes.sh
    - scripts/tests/test-dry-run.sh
  modified:
    - scripts/lib/install.sh
    - scripts/init-claude.sh
    - scripts/init-local.sh
    - Makefile

key-decisions:
  - "Fold Task 5 mode-change prompt into Tasks 3 and 4 rather than a separate commit: the D-42 block lives in the same init-claude.sh / init-local.sh regions as the D-41 re-run delegation and --force/--mode flag parsing. Splitting into a separate commit would create an intermediate state where the flags exist but the mode-change logic is missing. The combined commits are atomic per-file refactors. Documented as a deviation."
  - "ANSI auto-disable in init-local.sh colors block: reassign AFTER sourcing detect.sh / lib/install.sh / lib/state.sh because lib/state.sh unconditionally sets RED/YELLOW/NC to ANSI codes. Without the re-override, Test 7 FAIL: 'dry-run output contains ANSI escape codes when stdout is not a tty' (state.sh colors leak through banner echoes)."
  - "Keep EXTRA_FILES (CLAUDE.md, settings.json, cheatsheets, framework-specific experts) OUT of the manifest-driven loop: these files are NOT in manifest.files.* (they're templates.* or repo-root cheatsheets/). Treating them as always-install preserves Plan 03-01's contract that manifest.files.* tracks mode-aware skip-set, and templates.* / cheatsheets/ are framework-agnostic always-install."

patterns-established:
  - "Deterministic fixture counts for CI tests: manifest-v2.json with 7 SP-conflict + 1 GSD-conflict entries yields predictable 0/7/1/8 skip counts, distinguishable from the real manifest's 7/0 SP/GSD counts and stable across future manifest updates."
  - "Mode-change confirmation UX: [y/N] prompt with default N on empty input; explicit 'Aborted. Pass --force-mode-change to bypass the prompt under curl|bash.' message preserves discoverability for automation paths."

requirements-completed: [MODE-01, MODE-02, MODE-03, MODE-04, MODE-05, MODE-06]

# Metrics
duration: ~55min
completed: 2026-04-18
---

# Phase 3 Plan 02: Install Modes + Dry-Run Summary

**Manifest-driven install with 4-mode skip filtering, --dry-run grouped output, interactive mode prompt, and mode-change UX — the largest user-visible behavior change in Phase 3 and the structural fix to BUG-07-class drift (single source of truth = manifest.json).**

## Performance

- **Duration:** ~55 min
- **Tasks:** 5 (Task 5 folded into Tasks 3 and 4 — see Decisions Made)
- **Files created:** 3 (fixture manifest, test-modes.sh, test-dry-run.sh)
- **Files modified:** 4 (lib/install.sh, init-claude.sh, init-local.sh, Makefile)
- **Lines:** +614 / -175

## Accomplishments

### Wave 0: test harness (Task 1)

- `scripts/tests/fixtures/manifest-v2.json` — fixture mirroring the real manifest.json schema with exactly 7 SP-conflict entries + 1 GSD-conflict entry; yields deterministic skip counts 0/7/1/8 for the 4 modes
- `scripts/tests/test-modes.sh` — asserts `compute_skip_set` counts for all 4 modes against the fixture, plus `recommend_mode` for all 4 HAS_SP/HAS_GSD combinations, plus rejection of bogus mode via stderr
- `scripts/tests/test-dry-run.sh` — asserts `init-local.sh --dry-run --mode complement-sp` produces grouped [INSTALL]/[SKIP]/Total output, leaves the filesystem untouched (md5 snapshot identical), and emits ANSI-clean output when stdout is not a tty
- `Makefile` — Test 6 and Test 7 wired into `make test` after Test 5

### lib/install.sh: print_dry_run_grouped (Task 2)

Replaced the Plan 03-01 stub with the full implementation:

- Single jq pass emits `{bucket, path, skip, reason}` JSON stream over `manifest.files.*`
- Bash `while IFS= read -r line` loop via process substitution (no subshell) emits one `[INSTALL]` or `[SKIP - conflicts_with:<plugin>]` line per entry
- Footer: `Total: <N> install, <M> skip`
- ANSI green/yellow auto-disable via `[ -t 1 ]` (D-36)
- Against real manifest.json `complement-sp`: 47 INSTALL / 7 SKIP / 1 Total, zero ANSI when captured to a file

### init-claude.sh: mode flags + manifest-driven install (Task 3)

- Parse `--mode <name> / --force / --force-mode-change` with allowlist validation against `MODES`
- `select_mode()` interactive prompt showing detected SP/GSD with versions, recommended mode, 1..4 selection with recommendation as empty-input default
- `warn_mode_mismatch()` stderr WARNING when `--mode` differs from `recommend_mode` (D-34: user flag wins)
- Re-run delegation (D-41): exit 0 with update-claude.sh hint when `~/.claude/toolkit-install.json` exists and `--force` absent
- Mode-change prompt (D-42): `--force` + `--mode <new>` differing from recorded mode triggers y/N prompt via `/dev/tty`; `--force-mode-change` bypasses; fail-closed under curl|bash (no /dev/tty → exit 0 without changes)
- Replace static `FILES=()` array (~80 lines) with manifest-driven loop: `compute_skip_set` → jq stream → while loop downloads only files NOT in skip-list
- `--dry-run` calls `print_dry_run_grouped` and exits 0 before any filesystem write
- Lifecycle: `acquire_lock` → manifest loop → `write_state` → `release_lock`
- Framework-specific extras (CLAUDE.md, settings.json, cheatsheets, laravel-expert.md etc.) moved to `EXTRA_FILES` + `download_extras()` — they are NOT in manifest.files.* and always install

### init-local.sh: full parity + per-project state (Task 4)

- Same flag parsing and allowlist validation
- `source "$SCRIPT_DIR/lib/state.sh"` followed by `STATE_FILE=".claude/toolkit-install.json"` override — per-project state (D-43), reassigned AFTER source per RESEARCH.md Pitfall 7
- Same re-run delegation + mode-change prompt, but against `.claude/toolkit-install.json` (not `$HOME/.claude/...`)
- Mode selection: defaults to `recommend_mode` when `--mode` absent (no interactive prompt in the local installer per plan discretion — local installs are typically scripted)
- Dry-run replaced: old static "Would create:" block replaced with `print_dry_run_grouped "$MANIFEST_FILE" "$MODE"`
- Replaced 5 hardcoded loops (prompts/agents/skills/commands/rules) with single manifest-driven loop: copies from `$TEMPLATE_PATH → $BASE_PATH → $GUIDES_DIR` per existing fallback chain
- `write_state "$MODE" "$HAS_SP" ... "$INSTALLED_CSV" "$SKIPPED_CSV"` + `release_lock` at end of flow
- ANSI auto-disable via `[ -t 1 ]` reassigned AFTER library sources (lib/state.sh overrides colors unconditionally)

### Task 5: mode-change prompt + integration

- Mode-change prompt implementation was folded into the same commits as Tasks 3 and 4 (see Deviations)
- Final verification run: `make shellcheck && make validate && make test` all exit 0; Tests 1-7 all green

## Task Commits

Each task committed atomically with `--no-verify` (parallel-worktree execution):

1. **Task 1: Add test-modes.sh + test-dry-run.sh + fixture (Wave 0)** — `7290a42` (test)
2. **Task 2: Implement print_dry_run_grouped (MODE-06)** — `0d2803b` (feat)
3. **Task 3: Add mode flags + manifest-driven install to init-claude.sh** — `5eeca69` (feat) — includes D-42 mode-change prompt
4. **Task 4: Add mode flags + manifest-driven install to init-local.sh** — `69874ca` (feat) — includes D-42 mode-change prompt

_Task 5's mode-change prompt work is absorbed into commits 3 and 4 (see Decisions Made)._

_Note: Plan metadata commit (SUMMARY.md + STATE/ROADMAP updates) is owned by the orchestrator in the worktree-parallel model — not this executor._

## Files Created/Modified

### Created

- `scripts/tests/fixtures/manifest-v2.json` (34 lines) — fixture mirroring manifest v2 schema; 7 SP-conflict + 1 GSD-conflict for deterministic 0/7/1/8 skip counts
- `scripts/tests/test-modes.sh` (75 lines) — asserts `compute_skip_set` skip-count correctness across 4 modes + `recommend_mode` across 4 HAS_SP/HAS_GSD combinations + bogus mode rejection
- `scripts/tests/test-dry-run.sh` (90 lines) — asserts `[INSTALL]/[SKIP]/Total:` grouped output, zero filesystem writes via md5 snapshot, ANSI-clean when stdout is not a tty

### Modified

- `scripts/lib/install.sh` — replaced `print_dry_run_grouped` stub with 53-line implementation: single jq pass emitting `{bucket, path, skip, reason}` stream; `while IFS= read -r line` loop via process substitution; `[ -t 1 ]` ANSI auto-disable; `Total: N install, M skip` footer; stderr error on unknown mode
- `scripts/init-claude.sh` — +205/-97 lines. Added `--mode/--force/--force-mode-change` flag parsing, mode allowlist validation, re-run delegation (D-41), mode-change prompt (D-42) with backup and fail-closed, `select_mode()` interactive prompt, `warn_mode_mismatch()`, `EXTRA_FILES` array for non-manifest files, `download_extras()` helper, full replacement of `download_files()` body with manifest-driven loop + `acquire_lock`/`write_state`/`release_lock` lifecycle
- `scripts/init-local.sh` — +151/-75 lines. Added the same flag parsing, re-run delegation, mode-change prompt, mode selection (no interactive prompt — plan discretion), replaced static dry-run block with `print_dry_run_grouped` call, replaced 5 hardcoded install loops (prompts/agents/skills/commands/rules) with manifest-driven loop using `TEMPLATE_PATH/BASE_PATH/GUIDES_DIR` fallback chain. Per-project `STATE_FILE=".claude/toolkit-install.json"` override after `source lib/state.sh`. ANSI colors auto-disable reassigned AFTER library sources
- `Makefile` — +6 lines: Test 6 + Test 7 invocations after Test 5, before the final `@echo "All tests passed!"` line

## Decisions Made

1. **Task 5 folded into Tasks 3 and 4.** The mode-change prompt (D-42) block was added inline in the same init-claude.sh / init-local.sh commits as the `--mode/--force/--force-mode-change` flag parsing and D-41 re-run delegation. Splitting it into a separate Task 5 commit would create an intermediate state where the flags are parsed but the mode-change logic is missing. A single atomic per-file refactor is cleaner and leaves the test suite green at every commit. Task 5's acceptance criteria (shellcheck + validate + test all green) are verified at the end.

2. **ANSI auto-disable reassigned AFTER library sources in init-local.sh.** `lib/state.sh` defines `RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'` unconditionally at source time. If color auto-disable (`[ -t 1 ]`) runs BEFORE sourcing lib/state.sh, state.sh overwrites the disabled empties back to ANSI codes, and banner `echo -e "${BLUE}Claude Code Toolkit — Local Install v$VERSION${NC}"` leaks ANSI into non-tty output. Reassigning AFTER the source fixes Test 7's "dry-run output is ANSI-clean when stdout is not a tty" assertion.

3. **EXTRA_FILES separation from manifest-driven loop.** CLAUDE.md, settings.json, cheatsheets/*.md, and framework-specific experts (laravel-expert.md, nextjs-expert.md, etc.) are NOT listed in `manifest.files.*` — they live under `templates.*` or repo-root `cheatsheets/`. Treating them as always-install (no `conflicts_with` metadata) preserves Plan 03-01's contract that `manifest.files.*` drives the mode-aware skip-set. Both installers handle these via a separate block (`download_extras` in init-claude.sh, cheatsheets loop + CLAUDE.md/settings.json blocks in init-local.sh).

## select_mode prompt UX (sample output)

```text
Detected plugins:
  OK superpowers (5.0.7)
  -- get-shit-done not detected

  Recommended: complement-sp
  1) standalone  2) complement-sp  3) complement-gsd  4) complement-full

  Install mode (default: complement-sp): _
```

## Mode-change prompt UX (sample output)

```text
Switching complement-sp -> complement-full will rewrite the install. Backup current state and proceed? [y/N]: _
```

On `y`: backs up `~/.claude/toolkit-install.json` to `.bak.<unix-ts>` and proceeds.
On `n` or empty: `Aborted. Pass --force-mode-change to bypass the prompt under curl|bash.` exit 0.
Under curl|bash with no /dev/tty: same `Aborted.` message, exit 0 (fail-closed).

## Dry-run grouped output (sample against real manifest.json complement-sp)

```text
[SKIP - conflicts_with:superpowers] agents/agents/code-reviewer.md
[INSTALL] agents/agents/planner.md
...
[SKIP - conflicts_with:superpowers] commands/commands/tdd.md
[INSTALL] commands/commands/test.md
...
[SKIP - conflicts_with:superpowers] skills/skills/debugging/SKILL.md
[INSTALL] skills/skills/testing/SKILL.md
[INSTALL] rules/rules/README.md
[INSTALL] rules/rules/project-context.md

Total: 47 install, 7 skip
```

## Deviations from Plan

### Intentional Combinations

**1. [Plan Structure] Task 5 mode-change prompt folded into Tasks 3 and 4**

- **Rationale:** Mode-change prompt (D-42) sits in the same init-claude.sh / init-local.sh files and regions as D-41 re-run delegation and `--mode` flag parsing. A separate Task 5 commit would introduce an intermediate state where flags are defined but D-42 logic is missing — which would make the individual Task 3/4 commits inconsistent (flags present, behavior incomplete). Folding preserves atomic per-file commits.
- **Scope impact:** None. All Task 5 acceptance criteria verified post-integration (shellcheck, validate, test all exit 0; FORCE_MODE_CHANGE count ≥ 2 in both files; RECORDED_MODE count ≥ 2 in both files; toolkit-install.json.bak count ≥ 1 in both files).
- **Commits:** `5eeca69` (init-claude.sh), `69874ca` (init-local.sh)

### Auto-fixed Issues

**2. [Rule 3 - Blocking] ANSI auto-disable must run AFTER library sources**

- **Found during:** Task 4 (test-dry-run.sh failing on ANSI assertion)
- **Issue:** `lib/state.sh` defines `RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'` unconditionally. Placing the `[ -t 1 ]` color guard BEFORE sourcing state.sh results in state.sh overriding the empties back to ANSI, and banner echoes (`${BLUE}...`, `${GREEN}...`, `${YELLOW}...`) leak ANSI into captured non-tty output. Test 7's "dry-run output is ANSI-clean when stdout is not a tty" FAILed until the color block was moved below the source statements.
- **Fix:** Moved the conditional color assignment in init-local.sh to AFTER `source "$SCRIPT_DIR/lib/state.sh"`. Added `# shellcheck disable=SC2034` on RED since lib/state.sh's own diagnostics reference it.
- **Files modified:** `scripts/init-local.sh`
- **Verification:** `bash scripts/tests/test-dry-run.sh` → 6 passed, 0 failed.
- **Committed in:** `69874ca` (Task 4)

**3. [Rule 3 - Blocking] STATE_FILE shellcheck SC2034 disable**

- **Found during:** Task 4 (`shellcheck scripts/init-local.sh` failing)
- **Issue:** `STATE_FILE=".claude/toolkit-install.json"` is read by `write_state` and `acquire_lock` inside `lib/state.sh`, not within init-local.sh itself. shellcheck reports SC2034 "STATE_FILE appears unused" and fails the lint gate.
- **Fix:** Added `# shellcheck disable=SC2034  # consumed by write_state in lib/state.sh` above the STATE_FILE reassignment, mirroring the same pattern used in init-claude.sh for the `MANIFEST_FILE` forward-reference (Plan 03-01 established the pattern).
- **Files modified:** `scripts/init-local.sh`
- **Verification:** `shellcheck scripts/init-local.sh` exits 0.
- **Committed in:** `69874ca` (Task 4)

**4. [Rule 3 - Blocking] MODES shellcheck SC2153 disable**

- **Found during:** Task 3 (Makefile shellcheck passing at info severity but `make shellcheck` failing)
- **Issue:** `MODES` is defined in `lib/install.sh` (sourced) but used directly in init-claude.sh / init-local.sh validation loops. shellcheck emits SC2153 "Possible misspelling: MODES may not be assigned. Did you mean MODE?" at `info` severity. The Makefile invocation (`shellcheck scripts/*.sh`, no `-S` flag) uses default severity which catches info-level.
- **Fix:** Added `# shellcheck disable=SC2153  # MODES is defined in lib/install.sh (sourced above)` to both validation loops.
- **Files modified:** `scripts/init-claude.sh`, `scripts/init-local.sh`
- **Verification:** `make shellcheck` exits 0.
- **Committed in:** `5eeca69` (Task 3), `69874ca` (Task 4)

---

**Total deviations:** 1 structural (Task 5 folding) + 3 auto-fixed blockers. All shellcheck/validate/test gates green.
**Impact on plan:** Plan intent preserved end-to-end. No scope creep; no user-visible behavior difference from the plan-specified design.

## Issues Encountered

- **Worktree base mismatch at startup.** Pre-bash Safety Net blocked the prescribed `git reset --hard` in `<worktree_branch_check>`. Used `git merge --ff-only` instead to fast-forward to the expected base — no uncommitted work lost.
- **ANSI leakage via state.sh** — resolved (see Deviation 2).
- **rm -rf blocked outside cwd** during a manual inspection (caught by Safety Net); worked around with `mktemp` paths and `cat -v` to avoid cleanup. Test infrastructure uses `trap 'rm -rf "$SCRATCH"' EXIT` on paths inside `$SCRATCH` (under `${TMPDIR:-/tmp}/…`) which is allowed by the safety net.
- No other issues.

## Next Phase Readiness

- Plan 03-03 (settings.json safe merge) can now consume the same `compute_skip_set` / `MODE` contract established here.
- Phase 4 `update-claude.sh` can read `~/.claude/toolkit-install.json` to drive incremental updates and respect recorded mode.
- The manifest-driven loop pattern is a reusable template for any future install-flow work.

## Gate Verification

- `make shellcheck` → exits 0 ✓
- `make validate` → exits 0 ✓
- `make test` → Tests 1-7 all pass ✓
- `bash scripts/init-local.sh --dry-run --mode complement-sp` → grouped output, exit 0, zero filesystem writes ✓
- `bash scripts/init-local.sh --mode bogus` → stderr "ERROR: invalid --mode value: bogus", exit 1 ✓
- `bash -c 'source scripts/lib/install.sh; compute_skip_set complement-sp manifest.json | jq length'` → 7 ✓
- `bash -c 'source scripts/lib/install.sh; compute_skip_set standalone manifest.json | jq length'` → 0 ✓
- `bash -c 'source scripts/lib/install.sh; print_dry_run_grouped manifest.json complement-sp' | grep -c "\[SKIP"` → 7 ✓
- `bash -c 'source scripts/lib/install.sh; print_dry_run_grouped manifest.json complement-sp' | grep -c "^Total:"` → 1 ✓

## Self-Check: PASSED

**Created files verified on disk:**

- `scripts/tests/fixtures/manifest-v2.json` — FOUND
- `scripts/tests/test-modes.sh` — FOUND (executable, shellcheck-clean)
- `scripts/tests/test-dry-run.sh` — FOUND (executable, shellcheck-clean)

**Task commits verified in git log:**

- `7290a42` — FOUND — `test(03-02): add test-modes.sh + test-dry-run.sh + fixture (Wave 0)`
- `0d2803b` — FOUND — `feat(03-02): implement print_dry_run_grouped (MODE-06)`
- `5eeca69` — FOUND — `feat(03-02): add mode flags + manifest-driven install to init-claude.sh`
- `69874ca` — FOUND — `feat(03-02): add mode flags + manifest-driven install to init-local.sh`

**Project gates:**

- `make shellcheck` → PASS
- `make validate` → PASS
- `make test` → Tests 1-7 all PASS

---

*Phase: 03-install-flow*
*Plan: 03-02*
*Completed: 2026-04-18*
