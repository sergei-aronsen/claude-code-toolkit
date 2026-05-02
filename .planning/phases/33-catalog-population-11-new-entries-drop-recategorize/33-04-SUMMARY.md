---
plan_id: 33-04
phase: 33
title: Drop sequential-thinking + Re-categorize 8 existing entries + add CLI blocks
status: complete
commit: 9481ee0
req_ids: [DROP-01, EXIST-01]
executed_on: 2026-05-02
phase_completion: true
---

# Plan 33-04 Summary

## Overview

DROP-01 removed `sequential-thinking`. EXIST-01 confirmed category assignments for all 8 Phase 32 survivors (no drift — Phase 32 already set them correctly) and added CLI blocks to firecrawl, playwright, sentry where companion CLIs add real value.

Catalog count: 21 → 20 (final Phase 33 state).

## Phase 33 final state

| Metric | Value |
|--------|-------|
| Total MCP entries | 20 |
| Total CLI blocks | 8 |
| Categories declared | 10 (CAT-03 canonical 10-list) |
| `unofficial: true` entries | `{notebooklm, telegram}` |
| `sequential-thinking` present? | NO (DROP-01) |
| Validator | PASSED |
| `make check` | All checks passed |
| `test-mcp-selector.sh` | PASS=21 FAIL=0 (S1 updated to count=20) |
| `test-integrations-foundation.sh` | PASS=32 FAIL=0 |

### Category distribution

| Category | Entries |
|----------|---------|
| backend | aws-cloudwatch-logs, aws-cost-explorer, cloudflare, supabase |
| communication | slack, telegram |
| design | figma |
| dev-tools | magic, openrouter, playwright |
| docs-research | context7, firecrawl, notebooklm |
| email | resend |
| monitoring | sentry |
| payments | stripe |
| project-management | jira, linear, youtrack |
| workspace | notion |

### CLI block coverage (8 of 20 entries)

aws-cloudwatch-logs (shared aws), aws-cost-explorer (shared aws), cloudflare (wrangler), firecrawl (firecrawl), playwright (playwright), sentry (sentry-cli), stripe (stripe), supabase (supabase).

12 entries are MCP-only (no companion CLI shipped with the catalog default): context7, figma, jira, linear, magic, notebooklm (hint-only fallback per 33-03), notion, openrouter, resend, slack, telegram, youtrack.

## Plan-by-plan commit log

| Plan | Commit | Description |
|------|--------|-------------|
| 33-01 | 08455ee | Backend cluster (supabase, cloudflare, aws-cost-explorer, aws-cloudwatch-logs) + 10-category list |
| 33-02 | f29bc80 | Payments + project-mgmt + design (stripe, youtrack, linear, jira, figma) |
| 33-03 | a2d3326 | Communication + research (notebooklm, slack, telegram) — 2 unofficial |
| 33-04 | 9481ee0 | DROP sequential-thinking + EXIST CLI blocks for firecrawl/playwright/sentry |

## Verified package: firecrawl-cli

| Aspect | Value |
|--------|-------|
| Package | `firecrawl-cli` (npm) |
| Version | 1.16.0 |
| Last modified | 2026-04-27 (fresh, <12mo) |

CONTEXT.md mentioned `@mendable/firecrawl-cli` first — that scoped name returns 404. The unscoped `firecrawl-cli` (Mendable-stewarded) is the real package. Documented and used.

## Linux install strategy per CLI block

| CLI block | Linux install | No-sudo? |
|-----------|---------------|----------|
| firecrawl | `npm install -g firecrawl-cli` | yes (assumes Node via nvm/asdf) |
| playwright | `npm install -g @playwright/test && npx playwright install` | yes |
| sentry-cli | `curl -sL https://sentry.io/get-cli/ \| INSTALL_DIR=$HOME/.local/bin bash` | yes (env-var override on vendor's installer) |

## Schema notes

- `EXIST-01 categories` mutations: all 8 entries already carried the correct category from Phase 32 — the loop verified each one and applied no changes. Documented as no-op.
- 3 new CLI blocks under `components.cli` (firecrawl, playwright, sentry); top-level keys re-sorted for deterministic ordering.

## Self-test results

- `python3 scripts/validate-integrations-catalog.py` → `PASSED (20 mcp entries checked across 10 categories)`
- `bash scripts/tests/test-mcp-selector.sh` → `PASS=21 FAIL=0`
- `bash scripts/tests/test-integrations-foundation.sh` → `PASS=32 FAIL=0`
- `make check` → `All checks passed!`
- DROP-01 assertion: `sequential-thinking not in c['components']['mcp']` ✓
- unofficial-set assertion: `{notebooklm, telegram}` ✓

## Deviations

### Final-count discrepancy (planning math)

The phase title says "11 new entries" but REQUIREMENTS.md INT-01..12 enumerates **12** distinct integrations (supabase, cloudflare, stripe, aws-cost-explorer, aws-cloudwatch-logs, notebooklm, youtrack, linear, jira, figma, slack, telegram). Plans 33-01/02/03 cumulatively add 4+5+3 = 12 entries (each plan's title and acceptance criteria match this).

Math: 9 (Phase 32 baseline) − 1 (sequential-thinking dropped) + 12 (INT-01..12) = **20**.

Plan 33-04 acceptance criteria stated "final count = 19 (allow 17-19 if some unofficial entries deferred)". The 19 target only resolves if exactly one of INT-01..12 is dropped, but no requirement supports that — INT-12 (telegram) is `unofficial: true` and verified, INT-06 (notebooklm) likewise.

**Resolution applied (Rule 1 — auto-fix):** kept all 12 verified packages; documented the math discrepancy here. The phase title's "11" should be read as "11 net new entries above the 9-entry baseline post-drop" but that arithmetic itself is wrong (12 − 1 = 11 net add only if we counted the drop as an offset against new adds, which is a category error — the drop targets a Phase-32 entry, not a Phase-33 one). Likely the phase title was authored before the requirements were finalized and never updated. None of the underlying decisions (which packages to ship, which categories to use, which to mark unofficial) are affected.

### Other deviations rolled up from prior plans

- **33-01 Rule 3:** test-mcp-selector.sh S1 hard-coded to 9 entries — updated per plan to track current state (13 → 18 → 21 → 20).
- **33-03 Rule 2:** Slack package switched from CONTEXT.md's `@modelcontextprotocol/server-slack` (officially deprecated) to `slack-mcp-server` (korotovsky community fork, 17388 weekly DL).
- **33-03 Rule 1:** Slack and Telegram env-var keys updated to match the chosen packages' actual documented env layouts (SLACK_MCP_XOXC/XOXD instead of SLACK_BOT_TOKEN; TG_APP_ID/TG_API_HASH instead of TELEGRAM_BOT_TOKEN). Package-faithful per CONTEXT.md D-03.
- **33-03 hint-only fallback:** notebooklm CLI block omitted (no installable `nlm` CLI on npm/PyPI; the MCP package handles browser auth itself via Patchright).

No entries deferred — all 12 INT-01..12 packages verified as fresh + adopted.

## Acceptance criteria

- [x] `sequential-thinking` not present (DROP-01 ✓)
- [x] All 20 entries pass validator
- [x] CLI blocks present on supabase, cloudflare, aws-cost-explorer, aws-cloudwatch-logs, stripe, firecrawl, playwright, sentry (8 of the 9 originally-targeted entries; notebooklm is hint-only per documented fallback)
- [x] `unofficial: true` set = {notebooklm, telegram}
- [x] No sudo in any CLI install command
- [x] `make check` rc=0
- [x] `test-mcp-selector.sh` PASS=21 baseline preserved
- [x] `test-integrations-foundation.sh` PASS=32 baseline preserved
- [x] Single conventional commit (9481ee0)
- [ ] Final catalog count = 19 — **landed at 20** instead, see Deviations above. All 12 INT requirements satisfied; the gap is in the planning-document math, not in execution.

## Phase 33 closure

All 4 plans (33-01..04) executed in sequence. All 14 covered REQ-IDs satisfied:
- INT-01 supabase, INT-02 cloudflare, INT-03 stripe, INT-04 aws-cost-explorer, INT-05 aws-cloudwatch-logs, INT-06 notebooklm, INT-07 youtrack, INT-08 linear, INT-09 jira, INT-10 figma, INT-11 slack, INT-12 telegram → all entries shipped, packages verified, fresh.
- DROP-01 sequential-thinking → removed.
- EXIST-01 → 8 categories confirmed; CLI blocks added for firecrawl, playwright, sentry.
