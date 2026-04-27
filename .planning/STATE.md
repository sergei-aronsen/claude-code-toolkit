---
gsd_state_version: 1.0
milestone: v4.3
milestone_name: Uninstall
status: shipped
stopped_at: v4.3.0 tagged — 2026-04-26
last_updated: "2026-04-26T19:00:00.000Z"
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 10
  completed_plans: 10
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-26)

**Core value:** Install only what adds value over `superpowers` + `get-shit-done`. No duplicates, no name collisions.
**Current focus:** Planning next milestone — v4.3 Uninstall shipped 2026-04-26

## Current Position

Last shipped: v4.3 Uninstall (Phases 18–20) — tagged v4.3.0 on 2026-04-26
Next: Run `/gsd-new-milestone` to define next milestone scope

Progress: idle (between milestones)

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

### Roadmap Evolution

- 2026-04-21: v4.0 shipped (Phases 1–7 + 6.1)
- 2026-04-25: v4.1 shipped (Phases 8–12); v4.2 roadmap created (Phases 13–17, 22 REQ-IDs)
- 2026-04-26: v4.2 shipped — tagged `v4.2.0` + GitHub Release published
- 2026-04-26: Phase 19 (state-cleanup-idempotency) verified PASSED — UN-05 + UN-06 complete
- 2026-04-26: Phase 20 (distribution-tests) verified PASSED — UN-07 + UN-08 complete; v4.3 milestone ready for tag

### Pending Todos

None.

### Blockers/Concerns

None. v4.3 awaiting tag commit: replace YYYY-MM-DD placeholder in manifest.json + CHANGELOG.md with real ISO date, then cut `v4.3.0` tag.

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
| v4.4 candidate | SP/GSD bootstrap installer | Interactive `[y/N]` prompts in `init-claude.sh` invoking the canonical install commands directly — `claude plugin install superpowers@claude-plugins-official` for SP and `bash <(curl -sSL .../get-shit-done/main/scripts/install.sh)` for GSD. No forks, no vendoring; toolkit only orchestrates the original installers (re-scoped 2026-04-27 per user direction) |
| WONTFIX | Council `audit-review` → Sentry/Linear ticket creation | User direction 2026-04-27: Sentry reserved for error monitoring (not tracking); project tracking lives in a separate system. Toolkit stays at the report-artefact boundary (`.claude/audits/<report>.md`) |
| Deferred | `--no-council` flag for `/audit` | Was mandatory in v4.2; revisit in v4.3 if pain points emerge |
| Deferred | `--keep-state` flag (partial-uninstall recovery) | Phase 19 D-05: explicitly deferred to v4.4 |
| Deferred | `--no-banner` flag for init-claude.sh / init-local.sh | Phase 20 D-08: deferred to v4.4 if demand emerges |
| Deferred | Register scripts/lib/*.sh in manifest | Phase 20 D-11: deferred to v4.4 if update-claude.sh learns files.scripts iteration |

## Session Continuity

Last session: 2026-04-26T16:33:00.000Z
Stopped at: Phase 20 verified PASSED — v4.3 milestone complete
Resume file: None

**To complete milestone:**

- Cut `v4.3.0` tag: replace `YYYY-MM-DD` in `manifest.json` and `CHANGELOG.md` with real ISO date, then `git tag v4.3.0`
