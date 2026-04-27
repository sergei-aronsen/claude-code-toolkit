---
gsd_state_version: 1.0
milestone: v4.4
milestone_name: Bootstrap & Polish
status: verifying
stopped_at: Completed 23-03-PLAN.md
last_updated: "2026-04-27T11:02:03.570Z"
last_activity: 2026-04-27
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 8
  completed_plans: 8
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-27)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** Phase 23 — Installer Symmetry & Recovery

## Current Position

Phase: 23
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-04-27

Progress: 0% (0 / 3 phases)

```text
Phase 21 [ ] SP/GSD Bootstrap Installer
Phase 22 [ ] Smart-Update Coverage for scripts/lib/*.sh
Phase 23 [ ] Installer Symmetry & Recovery
```

## Plan Count Estimate

Total plans estimated at ~8 across 3 phases:

- Phase 21 — 3 plans (bootstrap prompt + canonical installer invocation + detection re-run; test harness)
- Phase 22 — 2 plans (manifest registration; update-claude.sh iteration + test)
- Phase 23 — 3 plans (--no-banner symmetry + test extension; --keep-state flag; keep-state test harness)

Actual plan count will be set by `/gsd-plan-phase` for each phase.

## Performance Metrics

**v4.3 totals (2026-04-26, single day):**

- Phases: 3 (18–20)
- Plans: 10
- Tasks: 12
- Commits: 50+ (`v4.2.0 → v4.3.0`)
- Diff: 129 files changed (+11307 / −307)
- New tests: 7 uninstall-suite files, 67 assertions
- New CI gate: quality.yml mirrors full uninstall suite

**v4.2 totals (2026-04-25 → 2026-04-26):**

- Phases: 5 (13–17)
- Plans: 22
- Tasks: 23
- Commits: 82 (`v4.1.1 → v4.2.0`)
- Diff: 207 files changed (+39997 / −18884)

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions table. Recent v4.2 highlights:

- Council `audit-review` MUST NOT reclassify severity (COUNCIL-02) — auditor owns severity, Council confirms REAL/FALSE_POSITIVE only
- No `--no-council` flag for `/audit` in v4.2 — mandatory pass enforces FP discipline; revisit in v4.3 if pain emerges
- Verbatim ±10 lines code block per finding (AUDIT-03) — Council reasons from code, not labels
- 49 prompt files spliced in one atomic commit `33be0b1` — single auditable changeset across 7 frameworks × 7 prompt types
- D-12: `/audit` never auto-writes `audit-exceptions.md`; nudges user to invoke `/audit-skip` after FALSE_POSITIVE verdict
- D-13: disputed verdicts surface three-option prompt (R/F/N), no default
- [Phase 18-core-uninstall-script-dry-run-backup]: Re-apply color gate after lib-source: lib/state.sh unconditionally overwrites RED/YELLOW/NC; second gate block after sourcing restores NO_COLOR compliance
- [Phase 18-core-uninstall-script-dry-run-backup]: classify_file PROTECTED-first ordering: is_protected_path checked before file existence before SHA compare — UN-01 invariant enforced at helper layer before any downstream delete logic
- [Phase 18-core-uninstall-script-dry-run-backup]: classify_file resolves paths against PROJECT_DIR not CLAUDE_DIR — installed_files[].path is project-root-relative; using CLAUDE_DIR caused double-.claude path bug
- [Phase 18-core-uninstall-script-dry-run-backup]: DRY_RUN early-exit is a permanent gate after classification — 18-03/18-04 must add backup+delete AFTER this block, never before (UN-02 zero-mutation invariant)
- [Phase 18-core-uninstall-script-dry-run-backup]: LOCK_DIR override added to TK_UNINSTALL_HOME test seam block — acquire_lock must use sandbox path during tests to avoid real-home lock interference
- [Phase 18-core-uninstall-script-dry-run-backup]: Execution order: trap → source libs → LOCK_DIR override → acquire_lock → backup → snapshot → delete loop → summary; backup ALWAYS precedes rm
- [Phase 18-core-uninstall-script-dry-run-backup]: TK_UNINSTALL_FILE_SRC must point to parent of .claude/ — state paths include .claude/ prefix so seam dir resolves /$rel correctly
- [Phase 18-core-uninstall-script-dry-run-backup]: prompt_modified_for_uninstall uses while:;do re-entrant loop — d branch renders diff and continues loop iteration; no return between d|D) and ;; to preserve re-entrancy
- [Phase 19-state-cleanup-idempotency]: assert_contains uses plain grep -q so ✓ glyph needs no escaping in idempotency test
- [Phase 19-state-cleanup-idempotency]: Trap uses parameter-length guards (SANDBOX:? / MARKER_FILE:?) per T-19-01-01 threat model
- [Phase 19-state-cleanup-idempotency]: A2 asserts Toolkit not installed; nothing to do without trailing period to survive cosmetic punctuation changes
- [Phase 19-state-cleanup-idempotency]: D-06 order: backup → strip → file-delete → state-delete (LAST); state-delete is final atomic step so earlier failures leave state intact for re-run
- [Phase 19-state-cleanup-idempotency]: D-10 fail-loud: base-plugin tree mutation during uninstall → log_error + exit 1 with STATE_FILE preserved; defense-in-depth invariant via diff -q on sorted find output
- [Phase 19-state-cleanup-idempotency]: SP/GSD synthetic files NOT in toolkit-install.json state — D-11 invariant fires even when state is silent about base-plugin paths (stronger defense-in-depth proof)
- [Phase 20-distribution-tests]: D-12: init-local.sh reads version from manifest.json at runtime — no init-local.sh edit needed for version-align
- [Phase 20-distribution-tests]: D-15: YYYY-MM-DD placeholder locked literal in manifest.json and CHANGELOG.md until v4.3.0 tag commit
- [Phase 20-distribution-tests]: D-06: banner string is byte-identical across all 3 installers — single BANNER= variable in test is the canonical source-of-truth
- [Phase 20-distribution-tests]: D-09: test uses grep -cF count-mode (exactly 1) not grep -q — catches accidental duplication
- [Phase 20-distribution-tests]: Canary selection uses jq .installed_files[].path | grep -E '.(md|json)' | head -1 for resilience to future install-set changes
- [Phase 20-distribution-tests]: Backup path strips .claude/ prefix to match cp -R CLAUDE_DIR layout in .claude-backup-pre-uninstall-* dirs
- [Phase 20-distribution-tests]: Rule 1 fix: init-local.sh now tracks 13 previously-untracked files (cheatsheets, seed files, CLAUDE.md, settings.json) in INSTALLED_PATHS[] so uninstall can cleanly remove all
- [Phase 21-01]: Use guarded [[ -z ... ]] && form for TK_SP_INSTALL_CMD / TK_GSD_INSTALL_CMD — allows test-seam override and matches color-guard idiom in optional-plugins.sh
- [Phase 21-01]: Define _bootstrap_log_info / _bootstrap_log_warning locally in bootstrap.sh — lib/install.sh does not export log_* helpers (RESEARCH.md correction confirmed 2026-04-27)
- [Phase 21]: init-local.sh now sources lib/optional-plugins.sh (new dependency) before lib/bootstrap.sh so TK_SP/GSD_INSTALL_CMD constants are available when bootstrap.sh loads
- [Phase 21]: Color re-gate in init-local.sh post-bootstrap block checks both [ -t 1 ] AND [ -z NO_COLOR+x ] — stricter than original gate but correct per uninstall.sh pattern
- [Phase 21-03]: Use --dry-run base as test driver flags so init-local.sh exits cleanly without writes or framework detection
- [Phase 21-03]: S3 invokes init-local.sh twice to prove D-16 CLI/env-var equivalence without extra scenario functions
- [Phase 21-03]: S4 uses PATH=/usr/bin:/bin to exclude real claude binary — avoids test interference in CI
- [Phase 22]: files.libs[] omits description field — matches files.scripts[] convention; descriptions live in lib file headers (D-01)
- [Phase 22]: No update-claude.sh code changes needed — existing jq .files | to_entries[] | .value[] | .path auto-discovers libs key (D-01 / D-07 zero-special-casing invariant)
- [Phase 22]: Phase 21 + Phase 22 consolidated into single [4.4.0] CHANGELOG entry — Phase 21 was never separately released
- [Phase 22]: S1 setup uses empty installed_files[] state file to force stale lib through new-files install path (synthesize_v3_state would record stale SHA, blocking refresh)
- [Phase 22]: TK_UPDATE_FILE_SRC=REPO_ROOT (not REPO_ROOT/scripts/lib) — seam resolves paths as TK_UPDATE_FILE_SRC/rel where rel=scripts/lib/backup.sh
- [Phase 22]: S5 asserts file-level removal (backup.sh absent), not directory removal — uninstall.sh removes files but does not rmdir empty parent dirs
- [Phase 23-01]: Single-line --no-banner) NO_BANNER=1; shift ;; clause form used so grep pattern in A5 assertion matches; SC2016 disable added for intentional single-quoted $NO_BANNER grep patterns in A6/A7
- [Phase 23-01]: D-06 assumption wrong: init-local.sh already has --help block at HEAD; --no-banner added to both Usage line and options block per R-05
- [Phase 23-installer-symmetry-recovery]: KEEP-01: gate existing rm -f STATE_FILE at D-06 LAST-step position behind KEEP_STATE boolean; inner rm-or-warn block preserved byte-identical; env-var TK_UNINSTALL_KEEP_STATE seeds default, CLI flag overrides
- [Phase 23-installer-symmetry-recovery]: KEEP-02: 11 assertions across S1+S2+S3; 'Backup created:' as A2 not-a-no-op marker; control assertion confirms UN-05 default unchanged

### Roadmap Evolution

- 2026-04-21: v4.0 shipped (Phases 1–7 + 6.1)
- 2026-04-25: v4.1 shipped (Phases 8–12); v4.2 roadmap created (Phases 13–17, 22 REQ-IDs)
- 2026-04-26: v4.2 shipped — tagged `v4.2.0` + GitHub Release published
- 2026-04-26: Phase 19 (state-cleanup-idempotency) verified PASSED — UN-05 + UN-06 complete
- 2026-04-26: Phase 20 (distribution-tests) verified PASSED — UN-07 + UN-08 complete; v4.3 milestone ready for tag
- 2026-04-27: v4.4 roadmap created — 3 phases (21–23), 9 REQ-IDs, 100% coverage

### Pending Todos

None.

### Blockers/Concerns

None.

## Deferred Items

Carry-overs available for next milestone scoping:

| Category | Item | Status |
|----------|------|--------|
| Locked out | Docker-per-cell isolation | Permanently out (conflicts with POSIX invariant) |
| Locked out | Auto-cut `git tag` from phase execution | Permanently out (CLAUDE.md "never push main") |
| Closed | HARDEN-C-04 — uninstall script | Done in v4.3 (`scripts/uninstall.sh`, UN-01..UN-08) |
| Closed | AUDIT-10 collision detection | Done — already covered by idempotent install + SHA256 manifest diff (closed 2026-04-26) |
| Closed | AUDIT-12 command markdown linting | Done by HARDEN-A-01 (`scripts/validate-commands.py`) |
| Closed | AUDIT-14 uninstall semantics | Done by v4.3 Uninstall (closed 2026-04-26) |
| Closed | AUDIT-15 provenance metadata | Done — already covered by `~/.claude/toolkit-install.json` (closed 2026-04-26) |
| WONTFIX | AUDIT-02 compat matrix | KISS — install-time picks 1 framework, no overlay scenario (closed 2026-04-26) |
| WONTFIX | AUDIT-04 merge-strategy | KISS — no multi-template overlay; per-file fallback in installers is sufficient (closed 2026-04-26) |
| WONTFIX | AUDIT-06 template version pinning | Already covered — `manifest.json` `version` + `~/.claude/.toolkit-version` + smart-update diff (closed 2026-04-26) |
| Closed | DETECT-FUT-01 CLI detection | Done by DETECT-06 in v4.1 Phase 9 (`claude plugin list --json` cross-check) |
| WONTFIX | Council `audit-review` → Sentry/Linear ticket creation | User direction 2026-04-27: Sentry reserved for error monitoring (not tracking); project tracking lives in a separate system. Toolkit stays at the report-artefact boundary (`.claude/audits/<report>.md`) |
| Deferred to v4.5 | `--no-council` flag for `/audit` | Was mandatory in v4.2; revisit in v4.3 if pain points emerge |
| In v4.4 Phase 23 | `--keep-state` flag (partial-uninstall recovery) | Phase 19 D-05: deferred to v4.4 — now KEEP-01/KEEP-02 |
| In v4.4 Phase 23 | `--no-banner` flag for init-claude.sh / init-local.sh | Phase 20 D-08: deferred to v4.4 — now BANNER-01 |
| In v4.4 Phase 22 | Register scripts/lib/*.sh in manifest | Phase 20 D-11: deferred to v4.4 — now LIB-01/LIB-02 |
| Phase 21-sp-gsd-bootstrap-installer P01 | 3m | 2 tasks | 2 files |
| Phase 21 P02 | 8m | 2 tasks | 2 files |
| Phase 21-sp-gsd-bootstrap-installer P03 | 12m | 3 tasks | 4 files |
| Phase 22 P01 | 8 | 2 tasks | 2 files |
| Phase 22 P02 | 25 | 3 tasks | 3 files |
| Phase 23-installer-symmetry-recovery P01 | 15 | 3 tasks | 3 files |
| Phase 23-installer-symmetry-recovery P02 | 5 | 2 tasks | 1 files |
| Phase 23-installer-symmetry-recovery P03 | 3 | 3 tasks | 5 files |

## Session Continuity

Last session: 2026-04-27T10:46:33.798Z
Stopped at: Completed 23-03-PLAN.md
Resume file: None

**To start v4.4 implementation:**

- `/gsd-discuss-phase 21` — discuss Phase 21 (SP/GSD Bootstrap Installer) before planning
