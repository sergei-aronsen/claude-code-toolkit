# Phase 40 — Deferred Items (out-of-scope discoveries during execution)

## 2026-05-05 — Plan 40-04 execution

### Uncommitted changes in `scripts/uninstall.sh` (89 lines, +0 deletions)

**Discovered during:** Plan 40-04 execution (post-task-1 git status check).

**Description:** A complete per-MCP cleanup loop (UN-SEC-01/02 plumbing — wires
the v4.3 UN-03 prompt pattern onto a `claude mcp list ∩ mcp_catalog_names`
intersection, calls `claude mcp remove --scope user`, then invokes
`uninstall_prompt_mcp_keys`) is sitting uncommitted in the working tree at
`scripts/uninstall.sh:875+`. It belongs to Plan 40-01 (continuation of
commit `48a661d` which only landed the helper + the `lib/mcp.sh` source line)
or to Plan 40-02 if the author was front-running.

**Why deferred:** Plan 40-04's `<files_modified>` frontmatter restricts the
plan to `scripts/lib/integrations-catalog.json` and
`scripts/tests/test-integrations-catalog.sh` only. The 89-line uninstall.sh
addition is out of scope for 40-04 and must not be silently swept into a
40-04 commit (would mis-attribute UN-SEC-01/02 work to a Calendly+validator
plan). Plan 40-01's executor (or whichever plan owns the work) needs to
review and commit it.

**Action item:** When Plan 40-01 or 40-02 executor resumes work, run
`git diff HEAD scripts/uninstall.sh` to inspect, then either commit under
the matching plan's tag (e.g. `feat(40-01): per-MCP cleanup loop`) or
revert if the work was experimental.

**No correctness/security risk identified by this scan** — the code path is
only reachable when run AS the uninstaller. The diff was not exercised by
Plan 40-04's test additions and does not touch the catalog or validator
contracts.

## Plan 40-01 discoveries

### test-mcp-selector.sh:79 S1 magic-number stale (PASS=35/FAIL=1)

**Discovered during:** Plan 40-01 final verification battery.
**Symptom:** `bash scripts/tests/test-mcp-selector.sh` reports
`Result: PASS=35 FAIL=1` with `FAIL S1: catalog contains 20 entries`.
**Root cause:** Plan 40-04 commit `eae7b89` added the Calendly entry to
`scripts/lib/integrations-catalog.json` (catalog now has 21 MCP entries),
but `test-mcp-selector.sh:79` still asserts the pre-Calendly count of 20.
**Pre-existing:** yes — failure was already present at HEAD before Plan
40-01 began. Confirmed via `git log --oneline -- scripts/lib/integrations-catalog.json`
showing `eae7b89` (Calendly entry) lands BEFORE Plan 40-01's two commits
(`48a661d`, `71ba883`).
**Owner:** Plan 40-04 (Calendly catalog entry + Google Workspace decision
log + validator SCOPE-01 regression). PATTERNS.md "Calendly catalog entry"
section already calls this out: "Existing test `A5: components.mcp has
exactly 20 entries` ... **WILL FAIL** after Calendly add (becomes 21).
Phase 40 D-14 update bumps the magic number from 20 to 21 in that
assertion." The same fix needs to be applied to `test-mcp-selector.sh:79`
(distinct from `test-integrations-catalog.sh` A5 — both files have the
same stale 20 magic number).
**Action:** none from Plan 40-01. Plan 40-04 is responsible for
updating `test-mcp-selector.sh:79` from `"20"` → `"21"`.
