---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 4
subsystem: integrations-catalog
tags: [calendly, mcp, oauth, http-transport, dcr, validator, scope-01, regression-test, int-13, int-14, test-06]

requires:
  - phase: 36-catalog-schema-backward-compat
    provides: SCOPE-01 default_scope schema + validator implementation at validate-integrations-catalog.py:254-272
  - phase: 33
    provides: integrations-catalog.json baseline schema (20 MCP entries pre-Phase-40)
provides:
  - Calendly MCP catalog entry (alpha-ordered, OAuth-only shape, HTTP transport)
  - INT-14 negative-lock test (no google-* entries) — defense in depth
  - SCOPE-01 negative regression test (validator catches missing default_scope)
  - test-integrations-catalog.sh PASS floor lifted from 17 -> 20 (target was ≥13)
affects:
  - 40-05 (test-uninstall-state-cleanup) — Calendly entry available for cleanup-helper edge cases when env_var_keys=[]
  - 41-DIST-03 (CHANGELOG v5.0.0) — CHANGELOG entry for INT-13 + INT-14 still pending
  - 41-DOCS-01 (INTEGRATIONS.md) — Calendly entry needs a row in the integrations table

tech-stack:
  added:
    - Calendly MCP (hosted HTTPS at https://mcp.calendly.com/, OAuth 2.1 + PKCE + DCR)
  patterns:
    - "HTTP-transport MCP entry: install_args = [--transport, http, <name>, <url>] — first non-stdio MCP in catalog"
    - "Negative-regression test pattern: mutate copy of CATALOG via mktemp + python3 heredoc, run validator, assert rc != 0 + grep stderr for diagnostic"
    - "pipefail-safe subprocess assertion: capture output to var + capture rc separately; never use `cmd | grep -q` when cmd is expected to exit non-zero"

key-files:
  created:
    - .planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-04-SUMMARY.md
    - .planning/phases/40-uninstall-secret-cleanup-calendly-validator/deferred-items.md
  modified:
    - scripts/lib/integrations-catalog.json (added calendly entry, MCP count 20 -> 21)
    - scripts/tests/test-integrations-catalog.sh (A5 21-count + A18/A19/A20 new assertions; PASS 17 -> 20)
    - scripts/tests/test-mcp-selector.sh (S1 magic 20 -> 21 — Rule 1 auto-fix downstream of Calendly add)

key-decisions:
  - "Calendly MCP is HTTP-hosted (DCR), not npm-stdio. Verified via developer.calendly.com/calendly-mcp-server: server lives at https://mcp.calendly.com/ with OAuth 2.1 + PKCE + Dynamic Client Registration. NO npm package is published officially by Calendly. The `calendly-mcp-server` unscoped npm package (publisher: Amit Patil, github.com/meAmitPatil) is a community wrapper, NOT an official Calendly publication — rejected per CLAUDE.md §7 typosquatting/dependency-security stance."
  - "install_args shape uses `[--transport, http, calendly, https://mcp.calendly.com/]` — the first HTTP-transport MCP in the catalog. Pattern follows `claude mcp add --help`: `claude mcp add --transport http <name> <url>`. The mcp.sh:710 dispatcher prepends `--scope <scope>` so the resulting invocation is `claude mcp add --scope user --transport http calendly https://mcp.calendly.com/`."
  - "category=workspace mirrors notion (closest OAuth-only analog). NO new `scheduling` category introduced (YAGNI per CONTEXT D-09)."
  - "Validator (validate-integrations-catalog.py) is BYTE-IDENTICAL — Phase 36 already implemented SCOPE-01 at lines 254-272 with the diagnostic 'default_scope is required' that A20 greps for. Phase 40 adds a regression test only, never re-implements."
  - "A20 uses captured-string + explicit rc check, NOT a `python3 ... | grep -q` pipeline. Reason: pipefail bubbles python3's expected non-zero rc past grep's success — caught during execution (Rule 1 deviation)."

patterns-established:
  - "HTTP-transport MCP entry shape: catalog install_args[0]=--transport, install_args[1]=http, install_args[2]=<friendly-name>, install_args[3]=<https-url>. Different from stdio shape `[<name>, --, npx/uvx, ...args]`."
  - "Negative-regression test for catalog validator: write mutated catalog via single-quoted heredoc to mktemp, invoke validator, capture stderr+rc. Useful template for future schema-rule regression tests."
  - "OAuth-DCR MCPs use `requires_oauth: true` + `env_var_keys: []` — same shape as Notion. The OAuth flow is fully delegated to `claude mcp add` and Calendly's authorization server; the toolkit only registers the URL."

requirements-completed: [INT-13, INT-14, TEST-06]

duration: 7m
completed: 2026-05-05
---

# Phase 40 Plan 4: Calendly Catalog + Google Workspace Negative Lock + SCOPE-01 Regression Summary

**Added Calendly MCP entry (HTTP transport, OAuth DCR) to integrations-catalog.json, locked the INT-14 Google Workspace non-add via assertion, and pinned the SCOPE-01 default_scope contract with a validator-mutation regression test — without modifying the validator itself (Phase 36 work, byte-identical).**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-05-05T20:35:32Z
- **Completed:** 2026-05-05T20:42:30Z
- **Tasks:** 2 (plus 1 Rule-1 auto-fix carry-over)
- **Files modified:** 3 (catalog + 2 test files)
- **Files created:** 2 (SUMMARY + deferred-items)
- **New commits (excluding final docs commit):** 3

## Accomplishments

- **INT-13 — Calendly catalog entry shipped.** Alpha-ordered between `aws-cost-explorer` (line 36-54) and `cloudflare` (line 70+). OAuth-only shape mirrors Notion verbatim with HTTP-transport install_args.
- **Canonical install pattern verified against developer.calendly.com.** Calendly's MCP is hosted HTTP at `https://mcp.calendly.com/` with OAuth 2.1 + PKCE + Dynamic Client Registration (DCR) — no client_id, no client_secret, no npm package. Plan's `@calendly/mcp-server` placeholder was correctly flagged for verification, and verification revealed the package does not exist (community lookalike `calendly-mcp-server` rejected).
- **INT-14 — Google Workspace negative lock asserted.** A19 in test suite enforces `^google-(workspace|drive|gmail|calendar)$` is empty; defense in depth against future drift.
- **TEST-06 — SCOPE-01 regression test wired.** A20 mutates a copy of the catalog (drops `default_scope` from the alpha-first MCP entry), invokes validator, asserts rc != 0 AND stderr contains `default_scope is required`. Locks the Phase 36 contract.
- **Validator left byte-identical** — Phase 36 already shipped SCOPE-01; Plan 40-04 verified by `git diff --quiet HEAD scripts/validate-integrations-catalog.py`.
- **PASS floor exceeded.** Plan target ≥13; final 20 PASS / 0 FAIL.
- **`make check` green** end-to-end (manifest + version-align + integrations-catalog + markdownlint + skills audit).

## Task Commits

Each task was committed atomically:

1. **Task 1: Insert Calendly entry in integrations-catalog.json (alpha-ordered, OAuth-only)** — `eae7b89` (feat)
2. **Task 2: Bump A5 + add A18/A19/A20 in test-integrations-catalog.sh** — `1be1ed4` (test)
3. **Rule-1 carry-over: Bump test-mcp-selector.sh S1 magic 20 -> 21** — `0f45ddc` (test)

**Plan metadata commit:** _to follow this SUMMARY (final docs commit)_

## Files Created/Modified

- `scripts/lib/integrations-catalog.json` — Added 15-line `calendly` entry between `aws-cost-explorer` and `cloudflare`. MCP count 20 -> 21. JSON valid; jq accepts; validator passes.
- `scripts/tests/test-integrations-catalog.sh` — Bumped A5 entry-count assertion 20 -> 21 (and updated header docstring math note). Added A18 (Calendly shape positive), A19 (no google-* entries), A20 (SCOPE-01 negative regression). Final 20 PASS / 0 FAIL.
- `scripts/tests/test-mcp-selector.sh` — Bumped S1 magic-number assertion 20 -> 21 (Rule 1 auto-fix carry-over from Plan 40-01 deferred-items hand-off). Restored PASS=36 FAIL=0.
- `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-04-SUMMARY.md` — this file.
- `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/deferred-items.md` — logged the test-mcp-selector S1 stale magic number from Plan 40-01 (now resolved here). Plan 40-01's earlier addendum about uninstall.sh uncommitted code is also no longer outstanding (was committed externally as `71ba883` during this plan's run).

## Decisions Made

### D-1 — Calendly install_args shape (HTTP, not npm-stdio)

**Issue:** Plan's `<interfaces>` block speculated about `@calendly/mcp-server` as the npm package; CONTEXT D-09 said "fetch developer.calendly.com/calendly-mcp-server to extract canonical npx invocation."

**Investigation:** Fetched the developer docs page (Gatsby SPA — static HTML didn't render the body, but textual content was extractable). Then queried npm registry for several plausible names. Findings:

- `https://developer.calendly.com/calendly-mcp-server` documents a **hosted HTTPS MCP server at `https://mcp.calendly.com/`** with OAuth 2.1 + PKCE + Dynamic Client Registration (RFC 7591). Quote: *"Calendly MCP uses Dynamic Client Registration (DCR), which means you do not need to pre-register an OAuth application or put any OAuth secrets into your MCP client configuration. After setting the server URL, the client and server navigate the auth flow automatically."*
- `npm registry @calendly/mcp-server` → **404 Not Found**.
- `npm registry calendly-mcp-server` (unscoped) → exists (1.0.0), but the publisher is `amitpatil010` (Amit Patil), repository `github.com/meAmitPatil/calendly-mcp-server`. **NOT an official Calendly publication.** Rejected per CLAUDE.md §7 typosquatting/dependency-security stance.
- Calendly GitHub org (`github.com/calendly`) has no MCP-related repositories (verified via search API, total_count=0).

**Conclusion:** Calendly publishes the MCP server **only as a hosted HTTPS endpoint**, not as an npm package. The toolkit's `claude mcp add` wrapper supports HTTP transport via `--transport http <name> <url>` (verified via `claude mcp add --help`).

**Resolution:** install_args = `["--transport", "http", "calendly", "https://mcp.calendly.com/"]`. The mcp.sh:710 dispatcher prepends `--scope <_scope>` so the production invocation is `claude mcp add --scope user --transport http calendly https://mcp.calendly.com/`. OAuth flow runs at first MCP call (browser opens, user grants access, DCR auto-registers a client_id).

**Field rationale:**
- `category: "workspace"` — matches Notion (closest OAuth-only analog); no new `scheduling` category (YAGNI per CONTEXT D-09).
- `env_var_keys: []` — DCR means zero secrets at install time; the helper at Plan 40-01 short-circuits cleanly (D-03).
- `requires_oauth: true` — triggers Claude Code's built-in OAuth flow.
- `default_scope: "user"` — personal scheduling tool, used across projects (CONTEXT D-09 + REQUIREMENTS SCOPE-02).
- **No `unofficial` field** — Calendly publishes the MCP server officially; matches Notion (also omits the field). PATTERNS surprise #5.
- No CLI block — no companion `calendly` CLI tool the toolkit knows about; matches Notion.

### D-2 — A20 must not use `cmd | grep -q` under pipefail

**Issue:** Initial A20 implementation used `python3 .../validate-integrations-catalog.py "$tmp" 2>&1 | grep -q 'default_scope is required'`. **Test failed** even though the validator's stderr clearly contained the diagnostic. Root cause: `set -o pipefail` (line 23) bubbles the rightmost non-zero exit through the pipeline. The validator exits 1 (which is exactly what we are asserting), grep exits 0 (match found), but the pipeline returns 1 — the if-test falls into the else branch.

**Fix (Rule 1 — auto-fix bug):** Capture validator output to `_a20_out` (with `|| true` to absorb the rc), capture rc separately into `_a20_rc`, then assert `_a20_rc != 0` AND `printf '%s\n' "$_a20_out" | grep -q '...'`. Now both halves are checked explicitly without pipefail interactions.

This is a reusable pattern for validator-negative tests across the project.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] A20 pipefail interaction broke the negative-regression assertion**

- **Found during:** Task 2 first run of `bash scripts/tests/test-integrations-catalog.sh`
- **Issue:** `set -euo pipefail` is enabled at line 23 of the test file; the canonical pattern in the plan (`if cmd 2>&1 | grep -q 'pattern'`) silently breaks when `cmd` is expected to exit non-zero — pipefail bubbles cmd's rc=1 past grep's rc=0, the if branch evaluates false even on a successful match.
- **Fix:** Replaced the `cmd | grep -q` if-test with: (a) capture the validator's stdout+stderr into `_a20_out` (with `|| true` to absorb the non-zero rc), (b) re-run the validator into `/dev/null` capturing rc into `_a20_rc`, (c) assert `_a20_rc -ne 0` AND `printf '%s\n' "$_a20_out" | grep -q '...'`. Both halves of the contract are now checked explicitly.
- **Files modified:** scripts/tests/test-integrations-catalog.sh (within Task 2's own edit scope)
- **Verification:** A20 went from FAIL to OK on next run; total PASS=20 FAIL=0; shellcheck -S warning clean; bash -n clean.
- **Committed in:** 1be1ed4 (Task 2 commit — single edit covered both the original A20 block and its pipefail fix)

**2. [Rule 2 - Missing critical] Calendly install_args defaulted to a community npm package; corrected to canonical hosted HTTPS form**

- **Found during:** Task 1 pre-write WebFetch verification (before committing)
- **Issue:** Plan's interface block speculated `@calendly/mcp-server` (an npm package) was the canonical install path. WebFetch + npm registry verification revealed: (a) `@calendly/mcp-server` does not exist on npm; (b) Calendly publishes the MCP **only** as a hosted HTTPS server at `https://mcp.calendly.com/` with OAuth 2.1 + DCR; (c) the unscoped `calendly-mcp-server` npm package is a community wrapper by Amit Patil (NOT Calendly's official publication) — using it would be a typosquat-equivalent risk per CLAUDE.md §7.
- **Fix:** install_args set to `["--transport", "http", "calendly", "https://mcp.calendly.com/"]` (canonical `claude mcp add --transport http <name> <url>` form per `claude mcp add --help`). Description updated to "Scheduling — events, availability, links (OAuth DCR)" to surface the auth model.
- **Files modified:** scripts/lib/integrations-catalog.json
- **Verification:** Plan task 1's automated check passes (jq + python3 schema check); validator accepts the entry (21 mcp entries / 10 categories); A14 still passes (install_args is non-empty list of strings).
- **Committed in:** eae7b89 (Task 1 commit)

---

**3. [Rule 1 - Bug] test-mcp-selector.sh S1 magic-number stale after Calendly add**

- **Found during:** Post-Task-2 verification (deferred-items.md hand-off from Plan 40-01)
- **Issue:** `scripts/tests/test-mcp-selector.sh:79` asserted `assert_eq "20" "${#MCP_NAMES[@]}" "S1: catalog contains 20 entries"`. Task 1's catalog change (20 -> 21 entries) flipped this assertion from PASS to FAIL. Plan 40-01's executor flagged this in deferred-items.md with explicit owner=Plan 40-04 (consistent with PATTERNS.md, which already noted the same magic number bump in two test files).
- **Fix:** Bumped magic from `20` -> `21` and updated the local echo banner + the inline comment to reflect the Phase 40 INT-13 addition.
- **Files modified:** scripts/tests/test-mcp-selector.sh
- **Verification:** `bash scripts/tests/test-mcp-selector.sh` → PASS=36 FAIL=0 (was 35/1). Other catalog/validator tests still green.
- **Committed in:** 0f45ddc (separate commit — outside Task 1/Task 2's own file scope but directly caused by Task 1's catalog change, so Rule 1 applies)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing-critical/security)
**Impact on plan:** All three auto-fixes were essential. (1) corrected an actual test-runtime failure inside Task 2's own file; (2) prevented committing a non-existent or community-impostor npm package as if it were official; (3) restored an unrelated test file that became stale solely as a downstream effect of Task 1's catalog change (test-mcp-selector S1 has the same magic-number contract as test-integrations-catalog A5). No scope creep — (3) only touched the broken assertion + its echo banner, no behavioral changes.

## Issues Encountered

- **Calendly developer docs page is a Gatsby SPA.** Initial WebFetch returned only the static HTML shell; the article body was rendered client-side. Worked around by stripping `<script>` and `<style>` tags then extracting text content, which surfaced the canonical install steps and confirmed the HTTPS hosted endpoint URL.
- **Out-of-scope discovery in `scripts/uninstall.sh`** (89 lines uncommitted, UN-SEC-01/02 per-MCP cleanup loop). Logged in `deferred-items.md` per execution rules SCOPE BOUNDARY. Belongs to Plan 40-01 (continuation of `48a661d`) or Plan 40-02. Did NOT include in this plan's commits.

## User Setup Required

None — no external service configuration required. Users who later install Calendly MCP via the toolkit will go through the standard OAuth browser flow; no API keys, no manual config, no `mcp-config.env` rows.

## Threat Flags

None — Plan 40-04 introduces no new trust boundaries beyond the catalog file itself (which is already a toolkit-controlled JSON literal). The A20 mutated-catalog temp file lives in `/tmp` with mktemp's random suffix; no path-traversal or symlink-race surface. Validator subprocess is committed code with no user-input flow per `<threat_model>` T-40-04-05.

## Next Phase Readiness

- **Plan 40-05 (test-uninstall-state-cleanup) is unblocked.** Calendly entry available in catalog for testing the empty-`env_var_keys` short-circuit path of `uninstall_prompt_mcp_keys` (Plan 40-01).
- **Phase 41 DOCS-03 needs to add Calendly to docs/INTEGRATIONS.md** (per CONTEXT D-20 — docs deferred). Cross-reference: Calendly = hosted-HTTPS + OAuth DCR, not the standard stdio/npx pattern. The docs writer should call this out explicitly so users know there's no API-key prompt at install time.
- **Phase 41 DIST-03 (CHANGELOG v5.0.0)** must include INT-13 (Calendly add) and INT-14 (Google Workspace explicit non-add) entries. Locked decisions already in PROJECT.md per CONTEXT D-10.
- **No blockers** for the rest of the milestone.

## Self-Check: PASSED

Verified after writing this SUMMARY:

- `[ -f scripts/lib/integrations-catalog.json ]` → FOUND
- `[ -f scripts/tests/test-integrations-catalog.sh ]` → FOUND
- `[ -f scripts/tests/test-mcp-selector.sh ]` → FOUND
- `git log --oneline --all | grep -q eae7b89` → FOUND (Task 1 — Calendly entry)
- `git log --oneline --all | grep -q 1be1ed4` → FOUND (Task 2 — A5/A18/A19/A20)
- `git log --oneline --all | grep -q 0f45ddc` → FOUND (Rule-1 carry-over — selector S1 magic)
- `python3 scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json` → exit 0, "21 mcp entries / 10 categories"
- `bash scripts/tests/test-integrations-catalog.sh` → exit 0, PASS=20 FAIL=0
- `bash scripts/tests/test-mcp-selector.sh` → exit 0, PASS=36 FAIL=0
- `git diff --quiet HEAD scripts/validate-integrations-catalog.py` → exit 0 (validator BYTE-IDENTICAL ✓)
- `make check` → exit 0

---
*Phase: 40-uninstall-secret-cleanup-calendly-validator*
*Plan: 40-04*
*Completed: 2026-05-05*
