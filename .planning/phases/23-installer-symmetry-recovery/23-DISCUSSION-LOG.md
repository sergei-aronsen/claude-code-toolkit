# Phase 23: Installer Symmetry & Recovery - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 23-installer-symmetry-recovery
**Mode:** `--auto --chain` (Claude auto-selected recommended defaults; user retains revise-before-plan opportunity)
**Areas discussed:** BANNER-01 implementation strategy, BANNER-01 test scope, KEEP-01 gate point, KEEP-01 env-var precedence, KEEP-02 test scope, KEEP-02 scenario coverage, CHANGELOG / version handling, Plan-count split

---

## BANNER-01 — `--no-banner` implementation strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Inline copy of `update-claude.sh` pattern | `NO_BANNER=0` + `--no-banner) NO_BANNER=1; shift ;;` + `if [[ $NO_BANNER -eq 0 ]]; then echo "…"; fi` directly in `init-claude.sh` and `init-local.sh`. ~6 lines per installer. | ✓ |
| Shared `scripts/lib/banner.sh` helper | New lib file owns banner state + emit function; init scripts source and call. Symmetric reuse, but single literal echo. | |
| Inline + factored helper later | Phase 23 does inline; if BANNER-02 ever arrives, factor then. | (collapses to inline now) |

**Auto-selection rationale (per D-01):** Pattern is 4-6 lines per installer; `update-claude.sh:11,24,1009-1010` is the canonical reference. Shared lib for a single literal string violates KISS / YAGNI / Surgical Changes invariants (PROJECT.md surgical-changes Key Decision). Inline copy keeps the diff minimal and matches `update-claude.sh` byte-for-byte.

---

## BANNER-01 — Test extension scope

| Option | Description | Selected |
|--------|-------------|----------|
| Extend `test-install-banner.sh` (4 new assertions) | Reuse locked `BANNER=` constant, `check_banner` helper, source-grep style; adds NO_BANNER var presence + `--no-banner` clause + gated echo per installer. Total: 7 assertions in 1 file. | ✓ |
| New `test-install-banner-flag.sh` | Separate file scoped to flag behaviour; `test-install-banner.sh` keeps its 3-assertion source-grep gate. | |
| Skip — assertions duplicate update-claude.sh test | Argue the existing `update-claude.sh` test already covers the pattern; init-* installers don't need their own. | |

**Auto-selection rationale (per D-05):** Single test file matches Phase 22 D-04 hermetic-test discipline. BANNER-01 acceptance criterion literally calls for "extended assertions cover both `init-claude.sh` and `init-local.sh` in `--no-banner` mode and default mode" — most natural reading is extension, not split.

---

## KEEP-01 — `--keep-state` gate point

| Option | Description | Selected |
|--------|-------------|----------|
| Gate the existing `rm -f "$STATE_FILE"` at line 653 | Wrap with `if [[ $KEEP_STATE -eq 0 ]]; then rm -f …; else log_info …; fi`. Preserves D-06 ordering invariant (state-delete LAST). | ✓ |
| Short-circuit before the LAST-step block | Detect `KEEP_STATE=1` early and skip the entire cleanup block. Risks subtle bugs (skips other LAST-step logic). | |
| Add new "preserve" code path with snapshot duplication | Capture state-file copy somewhere else when `KEEP_STATE=1`. Extra disk I/O, no consumer. | |

**Auto-selection rationale (per D-07):** KEEP-01 spec literally says "preserves `~/.claude/toolkit-install.json` after the run instead of deleting it as the LAST step". Minimal-touch gate at line 653 is the literal interpretation. UN-05 D-06 ordering invariant remains intact.

---

## KEEP-01 — Env-var precedence model

| Option | Description | Selected |
|--------|-------------|----------|
| CLI flag > env > default (Phase 21 D-16 mirror) | `KEEP_STATE=${TK_UNINSTALL_KEEP_STATE:-0}` init at top; `--keep-state) KEEP_STATE=1` overrides. | ✓ |
| Env-only (no CLI flag) | Drop the flag, expose only `TK_UNINSTALL_KEEP_STATE=1`. Less discoverable. | |
| CLI flag only (no env) | Drop the env var. Loses test-seam ergonomics. | |

**Auto-selection rationale (per D-09):** Phase 21 D-16 already established the CLI > env > default precedence for `--no-bootstrap` / `TK_NO_BOOTSTRAP`. KEEP-01 spec lists both surfaces; mirroring the established idiom keeps the toolkit's flag/env contract uniform.

---

## KEEP-02 — New test file naming + shape

| Option | Description | Selected |
|--------|-------------|----------|
| New `test-uninstall-keep-state.sh` | Mirrors `test-uninstall-idempotency.sh` shape; new assertions; spec-literal name. | ✓ |
| Extend `test-uninstall.sh` (round-trip) | Add a 6th scenario to existing 5-scenario round-trip test. Couples KEEP-02 to UN-08 test surface. | |
| Extend `test-uninstall-idempotency.sh` | Same as above, narrower scope. | |

**Auto-selection rationale (per D-13):** REQUIREMENTS.md KEEP-02 and ROADMAP.md SC 5 both reference the literal filename `scripts/tests/test-uninstall-keep-state.sh`. New file isolates the contract surface; round-trip test stays scope-locked to UN-08.

---

## KEEP-02 — Scenario coverage

| Option | Description | Selected |
|--------|-------------|----------|
| S1 + S2 + S3 (all-N + all-y + env-var-only) | Full coverage: partial-N recovery, full-y branch, env-only invocation. | ✓ (recommended) |
| S1 only (partial-N recovery) | Minimum to satisfy KEEP-02 four assertions. | |
| S1 + S2 + S3 + S4 (back-to-back keep-state) | Add a fifth scenario for keep-state idempotency. | (D-15 leaves to planner) |

**Auto-selection rationale (per D-16):** S1 covers the four required assertions. S2 cheaply adds the all-y branch coverage. S3 locks the D-09 env precedence contract end-to-end. Three scenarios stay under the Phase 22 5-scenario test-runtime budget.

---

## CHANGELOG / version handling

| Option | Description | Selected |
|--------|-------------|----------|
| Append to existing `[4.4.0]` Added section | Phase 22 already created `[4.4.0]`; Phase 23 appends BANNER-01 + KEEP-01 + KEEP-02 bullets. No version bump. | ✓ |
| Cut a separate `[4.4.1]` patch entry | Treats Phase 23 as post-v4.4.0 polish. Adds a release row + version-align churn. | |
| Hold for `[4.5.0]` minor cut | Implies Phase 23 ships in a future milestone. Contradicts roadmap (v4.4 includes Phase 23). | |

**Auto-selection rationale (per D-18):** v4.4 milestone = Phases 21-23 per ROADMAP.md. All three phases ship in the single `4.4.0` release. Version-align stays a 2-file atomic gate (manifest + CHANGELOG).

---

## Plan-count split

| Option | Description | Selected |
|--------|-------------|----------|
| 3 plans (per STATE.md estimate) | Plan 1 = BANNER-01 impl + test ext; Plan 2 = KEEP-01 flag impl; Plan 3 = KEEP-02 test harness. | ✓ (recommended) |
| 2 plans (BANNER + KEEP combined) | Plan 1 = BANNER-01 (impl + test); Plan 2 = KEEP-01 + KEEP-02 (impl + test). | |
| 1 combined plan | All three REQs in a single plan. | |

**Auto-selection rationale:** STATE.md plan estimate (`Phase 23 — 3 plans (--no-banner symmetry + test extension; --keep-state flag; keep-state test harness)`) already aligns with the natural decomposition. Final split is `gsd-planner`'s call — captured here as recommendation, not lock.

---

## Claude's Discretion

Areas where the user has flexibility (recorded in CONTEXT.md `<decisions>` § Claude's Discretion):

- Exact `log_info` phrasing for `--keep-state` preservation message
- Whether D-15 fifth assertion (back-to-back keep-state) ships in Phase 23
- Whether D-16 S3 (env-only scenario) ships in Phase 23
- `case` clause ordering inside argparse (alphabetical preferred)
- `docs/INSTALL.md` flag documentation bundling vs splitting
- Makefile TAB indentation (Make requirement)

---

## Deferred Ideas

Captured during analysis but not in scope for Phase 23 (recorded in CONTEXT.md `<deferred>`):

- `--no-banner` for `uninstall.sh` (it IS the remove tool, prints no banner)
- `--keep-state` env-only invocation by production tooling
- State-file format migration on `--keep-state` re-runs (covered by `synthesize_v3_state()`)
- `--help` block bootstrap for `init-local.sh`
- `--no-banner` for `setup-security.sh` / `install-statusline.sh`
