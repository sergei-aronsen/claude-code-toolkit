---
plan_id: 33-02
phase: 33
title: Payments + Project Management + Design — stripe, youtrack, linear, jira, figma
status: complete
commit: f29bc80
req_ids: [INT-03, INT-07, INT-08, INT-09, INT-10]
executed_on: 2026-05-02
---

# Plan 33-02 Summary

## Overview

Added 5 new entries spanning 3 categories: `payments` (stripe), `project-management` (youtrack, linear, jira), `design` (figma). One CLI block (stripe). Catalog count: 13 → 18.

## Verified Packages

| Entry | Package | Stewardship | Version | Last modified | Weekly DL |
|-------|---------|-------------|---------|---------------|-----------|
| stripe | `@stripe/mcp` | Stripe official | 0.3.3 | 2026-04-28 | n/a |
| youtrack | `youtrack-mcp` | community | 1.0.2 | 2025-07-11 | n/a |
| linear | `@tacticlaunch/mcp-linear` | community | 1.0.14 | 2026-04-28 | 6747 |
| jira | `@aashari/mcp-server-atlassian-jira` | community | 3.3.0 | 2025-12-03 | 6985 |
| figma | `figma-developer-mcp` | community (Framelink) | 0.11.0 | 2026-04-20 | n/a |

### Alternatives ruled out

- **stripe**: `@stripe/agent-toolkit` exists (v0.9.0, 2026-04-28) but is the broader toolkit; `@stripe/mcp` is the dedicated MCP server (preferred). `mcp-stripe` is a stale community fork (0.0.1).
- **youtrack**: `@jetbrains/mcp-server-youtrack` (404 — JetBrains has not published a YouTrack MCP on npm under their scope), `mcp-youtrack` (404). `youtrack-mcp` v1.0.2 is the only community package; while ~10mo old, it stays within the 12-month currency rule.
- **linear**: `@linear/mcp` (404 — Linear's official offering is a hosted Remote MCP server, not an npm package). `linear-mcp` v1.2.0 (2025-03-08, 14mo) is stale and only 572 weekly DL. `mcp-linear` (16mo stale). `@hatcloud/linear-mcp` is fresh but has only 315 weekly DL. `@tacticlaunch/mcp-linear` chosen for freshness (2026-04-28) AND adoption (6747 weekly DL — far ahead of alternatives).
- **jira**: `@atlassian/mcp-server` (404), `atlassian-mcp` (low DL), `mcp-atlassian` (3855 weekly but 9mo stale). `@aashari/mcp-server-atlassian-jira` chosen for highest weekly DL (6985) and recent maintenance.
- **figma**: `@figma/mcp-server` (404). Figma's official "Dev Mode MCP" is desktop-app-bundled (not npm-distributable). `figma-developer-mcp` (Framelink) is the de-facto standard headless option.

## Linux install strategy per entry

| Entry | Strategy | Detail |
|-------|----------|--------|
| stripe CLI | user-space tarball | `mkdir -p ~/.local/bin && curl -fsSL https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_x86_64.tar.gz \| tar -xz -C ~/.local/bin/ stripe` — extracts only the `stripe` binary, no sudo. |
| youtrack/linear/jira/figma | n/a (MCP-only) | No CLI block; auth happens via env vars passed to the MCP. |

stripe darwin install uses `brew install stripe/stripe-cli/stripe`.

## Schema notes

- youtrack/linear/jira/figma carry no `cli` block (MCP-only entries) — these tools authenticate via API token env vars; no companion CLI is needed for the catalog default flow.
- `ATLASSIAN_SITE_NAME` / `ATLASSIAN_USER_EMAIL` / `ATLASSIAN_API_TOKEN` chosen as the env var triplet — matches the @aashari/mcp-server-atlassian-jira documented env layout (closer to Atlassian's docs than the original CONTEXT.md draft `ATLASSIAN_URL/EMAIL/TOKEN`). The catalog's job is to surface the right keys for the chosen package.

## Self-test results

- `python3 scripts/validate-integrations-catalog.py` → PASSED (18 mcp entries, 10 categories)
- `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0 (S1 updated: count=18, alpha-first still `aws-cloudwatch-logs`)
- `bash scripts/tests/test-integrations-foundation.sh` → PASS=32 FAIL=0
- `make check` → All checks passed

## Deviations

- **Rule 3 (auto-fix blocking issue):** `test-mcp-selector.sh` S1 count assertion bumped from 13 (post-33-01) to 18. Same one-line update pattern as 33-01. Comment refreshed to reflect Phase 33-02's contribution.
- **Documentation consistency:** Atlassian env var triplet renamed (`ATLASSIAN_URL` → `ATLASSIAN_SITE_NAME`, `ATLASSIAN_EMAIL` → `ATLASSIAN_USER_EMAIL`, `ATLASSIAN_TOKEN` → `ATLASSIAN_API_TOKEN`) to match the chosen package's documented env-var layout. CONTEXT.md INT-09 listed best-guess names; the executor's job is package-faithful per D-03.

No deferred entries.

## Acceptance criteria

- [x] Catalog count = 18
- [x] Validator exit 0
- [x] Baselines preserved (mcp-selector 21/21, foundation 32/32)
- [x] make check rc=0
- [x] No sudo
- [x] Single conventional commit (f29bc80)
