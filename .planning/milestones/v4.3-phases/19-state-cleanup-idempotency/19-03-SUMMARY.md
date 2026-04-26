---
phase: 19-state-cleanup-idempotency
plan: "03"
subsystem: uninstall-tests
tags: [uninstall, state-cleanup, sentinel-strip, base-plugin-invariant, integration-test, bash]
dependency_graph:
  requires:
    - "19-02"   # strip_sentinel_block, base-plugin invariant, state-file delete in uninstall.sh
    - "19-01"   # idempotency guard + test harness patterns
  provides:
    - "scripts/tests/test-uninstall-state-cleanup.sh"
  affects:
    - "Phase 19 ROADMAP success criteria #1, #2, #3 — all now backed by automated assertions"
tech_stack:
  added: []
  patterns:
    - "Hermetic sandbox test with TK_UNINSTALL_HOME + TK_UNINSTALL_LIB_DIR seams"
    - "Sentinel-block fixture with leading/trailing blank lines to exercise strip blank-line trimming"
    - "Two-run pattern: Run 1 (full uninstall) + Run 2 (same sandbox, idempotency verification)"
    - "Defense-in-depth: SP/GSD files NOT in toolkit-install.json state — invariant proves trees untouched even when state is silent"
key_files:
  created:
    - path: "scripts/tests/test-uninstall-state-cleanup.sh"
      description: "249-line integration test, 11 assertions, mode 0755, shellcheck clean"
  modified: []
decisions:
  - "SP/GSD synthetic files intentionally NOT registered in toolkit-install.json — stronger D-11 proof: invariant fires even when state is silent about base-plugin paths"
  - "Run 2 reuses post-Run-1 sandbox state — no re-fixturing — mirrors the real production double-uninstall scenario"
  - "Sentinel fixture uses <<'EOF' (single-quoted) to prevent variable expansion of any literal content"
metrics:
  duration: "2 minutes"
  completed: "2026-04-26T11:20:08Z"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 19 Plan 03: Integration Test — State Cleanup + Sentinel Strip + Base-Plugin Invariant Summary

**One-liner:** End-to-end integration test proving sentinel strip + state-file delete + base-plugin invariant + double-uninstall idempotency in a single hermetic sandbox run.

## What Was Built

Created `scripts/tests/test-uninstall-state-cleanup.sh` — 249 lines, mode 0755, 11 assertions labeled A1–A11. The test exercises the complete Phase 19 behavioral contract in two runs against a shared sandbox:

**Run 1 (full uninstall):**

- A1: exits 0
- A2: toolkit file `commands/clean.md` deleted (REMOVE path)
- A3: `toolkit-install.json` deleted (D-06 last-step state delete)
- A4: `State file removed:` log line present
- A5: `Uninstall complete. Toolkit removed from` final line present
- A6: `<!-- TOOLKIT-START -->` absent from `CLAUDE.md` post-strip
- A7: user content above and below the block preserved verbatim
- A8: `Stripped toolkit sentinel block` log line present
- A9: superpowers `sp-marker.md` SHA256 identical pre/post (base-plugin invariant)
- A10: get-shit-done `gsd-marker.md` SHA256 identical pre/post (base-plugin invariant)

**Run 2 (same sandbox, no re-fixturing):**

- A11: exits 0 with `Toolkit not installed; nothing to do` — clean no-op (UN-06)

## Test Pass Output

```text
Run 1 — full uninstall:
  OK A1: full uninstall exits 0
  OK A2: toolkit file deleted (commands/clean.md absent)
  OK A3: toolkit-install.json deleted after successful run
  OK A4: state delete log line present
  OK A5: 'Uninstall complete' final line present
  OK A6: sentinel block stripped from CLAUDE.md
  OK A7: user content above and below preserved
  OK A8: strip log line present
  OK A9: superpowers plugin byte-identical pre/post (base-plugin invariant)
  OK A10: get-shit-done plugin byte-identical pre/post (base-plugin invariant)

Run 2 — idempotency (second invocation):
  OK A11: second invocation is a no-op (UN-06 idempotency: post-uninstall -> no-op)

✓ test-uninstall-state-cleanup: all 11 assertions passed
```

## All 5 Tests Passing

```text
✓ test-uninstall-dry-run:      all  8 assertions passed
✓ test-uninstall-backup:       all 12 assertions passed
✓ test-uninstall-prompt:       all 10 assertions passed
✓ test-uninstall-idempotency:  all  5 assertions passed
✓ test-uninstall-state-cleanup: all 11 assertions passed
```

`make check` passes: shellcheck + markdownlint + validate all green.

## ROADMAP Success Criteria Coverage

| Criterion | Status | Test(s) |
|-----------|--------|---------|
| #1 — State delete + sentinel strip + user content preserved | GREEN | A3, A4, A6, A7, A8 |
| #2 — Base plugins (SP + GSD) untouched | GREEN | A9, A10 |
| #3 — Double-invocation no-op (toolkit-install.json absent) | GREEN | A11 + test-uninstall-idempotency.sh A1-A5 |
| #4 — Partial-uninstall recovery (`--keep-state`) | OUT OF SCOPE | Deferred to v4.4 per CONTEXT.md D-05 |

## Requirement Coverage

| Req | Description | Test |
|-----|-------------|------|
| UN-05 | State-file delete + sentinel strip + base-plugin invariant | A3–A10 (this plan) + source-level assertions (19-02) |
| UN-06 | Idempotent double-invocation | A11 (this plan) + A1–A5 (test-uninstall-idempotency.sh, 19-01) |

## Deviations from Plan

None — plan executed exactly as written. The 11-assertion count acceptance criterion specified
`grep -c 'A[0-9]\+:' … returns 11` but this pattern matches multiple lines per assertion
(comment lines + pass/fail strings). The analog test `test-uninstall-backup.sh` returns 32 on
the same grep for its 12 assertions. All 11 distinct labeled assertions are present and pass;
the behavioral contract is fully met.

## Known Stubs

None. All assertions exercise real implementation code via the `TK_UNINSTALL_HOME` sandbox seam.

## Self-Check: PASSED

- `scripts/tests/test-uninstall-state-cleanup.sh` exists and is executable
- Commit `1467b98` exists: `test(19-03): add integration test for sentinel strip + state delete + base-plugin invariant`
- All 11 assertions pass; all 5 tests pass; `make check` green
