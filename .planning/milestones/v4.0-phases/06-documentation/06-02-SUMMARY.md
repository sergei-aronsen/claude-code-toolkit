---
phase: 06-documentation
plan: 02
subsystem: docs
tags: [rtk, caveman, superpowers, get-shit-done, optional-plugins, markdown]

requires:
  - phase: 06-documentation/06-01
    provides: "manifest.json bumped to 4.0.0 (no overlap — 06-02 touches different files)"

provides:
  - "components/optional-plugins.md — upstream-verified documentation for rtk, caveman, superpowers, get-shit-done with CONTEXT-locked install strings and caveats"
  - "templates/global/RTK.md — fallback RTK notes template with Known Issues section pointing to rtk-ai/rtk#1276"

affects:
  - "06-03 (manifest inventory registration of both new components; RTK.md install wiring into setup-security.sh; optional-plugins stdout block)"

tech-stack:
  added: []
  patterns:
    - "verified_upstream sentinel: <!-- verified_upstream: YYYY-MM-DD --> HTML comment header enables future doc-audit grep across components/ and templates/"

key-files:
  created:
    - components/optional-plugins.md
    - templates/global/RTK.md
  modified: []

key-decisions:
  - "caveman ships en + wenyan (Classical Chinese) — NOT en + ru (correction applied per commit 2444b40 / CONTEXT.md D-DOCS-05)"
  - "caveman auto-backup is single-generation — CLAUDE.original.md overwritten on re-compress; git commit is the durable backup"
  - "rtk #1276 user workaround (exclude_commands=[ls]) is NOT upstream's intended fix (LC_ALL=C); documented the distinction honestly"
  - "SP install string locked to claude plugin install superpowers@claude-plugins-official (matches detect.sh:54 + verify-install.sh:197-200)"
  - "GSD install string locked to bash <(curl -sSL .../gsd-build/get-shit-done/.../install.sh) (matches detect.sh:29 filesystem path)"
  - "No manifest.json edits in this plan — registration deferred to 06-03 Task 1 in NEW inventory.components section (not files.components) to avoid install-loop side-effect"

patterns-established:
  - "verified_upstream: YYYY-MM-DD comment header on all upstream-referencing components enables grep-based doc-audit"
  - "User-side workaround vs upstream fix distinction — document both honestly, never conflate"

requirements-completed:
  - DOCS-05-asset
  - DOCS-07-asset

duration: 15min
completed: 2026-04-19
---

# Phase 06 Plan 02: Optional Plugins Docs Summary

**Two net-new markdown assets: components/optional-plugins.md (rtk + caveman + SP + GSD with upstream-verified caveats) and templates/global/RTK.md (fallback RTK notes with Known Issues for rtk-ai/rtk#1276)**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-19T12:28:00Z
- **Completed:** 2026-04-19T12:43:00Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Created `components/optional-plugins.md` documenting all four recommended optional plugins with upstream-verified install commands, caveats, and CONTEXT-locked install strings
- Applied all DOCS-05 corrections: caveman en+wenyan (not ru), single-generation auto-backup warning, rtk #1276 workaround vs upstream fix distinction
- Created `templates/global/RTK.md` fallback template with Known Issues section, toml workaround fence, and Relationship to cc-safety-net section
- Both files pass markdownlint (0 errors)

## Task Commits

1. **Task 1: Create components/optional-plugins.md** - `5536c92` (feat)
2. **Task 2: Create templates/global/RTK.md** - `dc89875` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `components/optional-plugins.md` - Documents rtk, caveman, superpowers, get-shit-done with upstream-verified caveats and CONTEXT-locked install strings; carries `verified_upstream: 2026-04-18` sentinel
- `templates/global/RTK.md` - Fallback RTK notes for pre-`rtk init -g` state; Known Issues section with rtk-ai/rtk#1276 reference, toml workaround, upstream fix distinction

## Decisions Made

- `#### heading` used for the rtk#1276 Known Issues sub-entry (instead of bold-text paragraph intro) to satisfy MD036 (emphasis-as-heading rule)
- `SINGLE-GENERATION` changed to `single-generation` to match case-sensitive grep in plan verification spec

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MD036 markdownlint error on bold intro line**

- **Found during:** Task 1 (optional-plugins.md creation)
- **Issue:** `**rtk ls returns (empty)...**` as a standalone bold paragraph triggered MD036 (emphasis used instead of heading)
- **Fix:** Changed to `#### rtk ls returns (empty)...` proper heading — semantically correct and matches RTK.md's own use of a sub-heading for the same issue
- **Files modified:** components/optional-plugins.md
- **Verification:** markdownlint passes 0 errors
- **Committed in:** 5536c92

**2. [Rule 1 - Bug] Case mismatch on single-generation grep check**

- **Found during:** Task 1 verification (post-write grep check)
- **Issue:** Plan spec verifies `grep -q 'single-generation'` (lowercase); initial write used `SINGLE-GENERATION` (uppercase) in the WARNING line — grep -q is case-sensitive so verification failed
- **Fix:** Changed `SINGLE-GENERATION` to `single-generation` in the WARNING line
- **Files modified:** components/optional-plugins.md
- **Verification:** grep -q 'single-generation' passes
- **Committed in:** 5536c92

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bug)
**Impact on plan:** Both fixes purely cosmetic/format; no content invariant changed. No scope creep.

## Issues Encountered

None beyond the two auto-fixed markdownlint/grep issues above.

## Hand-off Notes to 06-03

1. Register `components/optional-plugins.md` + `components/orchestration-pattern.md` in NEW `manifest.json` `inventory.components` top-level section (NOT `files.components` — the latter triggers `scripts/lib/install.sh:239` to install them into `.claude/components/`, which is unwanted). See 06-03 Task 1 for schema + validate-manifest.py extension.
2. Fold RTK.md install into `scripts/setup-security.sh` with `[ ! -f "$HOME/.claude/RTK.md" ]` guard (06-03 Task 4) — DOCS-07 install wiring half.
3. Print end-of-run optional-plugins stdout block via `scripts/lib/optional-plugins.sh` sourced by `init-claude.sh` + `update-claude.sh` (06-03 Tasks 2-3) — DOCS-06.

## Next Phase Readiness

- Both markdown assets exist and pass markdownlint; 06-03 can safely register them in manifest inventory
- RTK.md template is at its final content state; 06-03 only needs to add the copy step to setup-security.sh
- `components/optional-plugins.md` cross-links to `templates/global/RTK.md` via relative mention ("See `templates/global/RTK.md` for additional detail") in the cc-safety-net subsection

---

*Phase: 06-documentation*
*Completed: 2026-04-19*
