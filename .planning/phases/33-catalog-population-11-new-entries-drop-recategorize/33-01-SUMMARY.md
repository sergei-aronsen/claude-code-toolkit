---
plan_id: 33-01
phase: 33
title: Backend cluster — supabase, cloudflare, aws-cost-explorer, aws-cloudwatch-logs
status: complete
commit: 08455ee
req_ids: [INT-01, INT-02, INT-04, INT-05]
executed_on: 2026-05-02
---

# Plan 33-01 Summary

## Overview

Added 4 backend-category MCP entries to `scripts/lib/integrations-catalog.json` and extended the top-level `categories[]` array to the full canonical 10-list per CAT-03. Introduced the parallel `components.cli` section (the existing schema only validated `components.mcp`; CLI blocks live alongside, validator unchanged).

Catalog count: 9 → 13.

## Verified Packages

All packages verified via `npm view <pkg> name version time.modified` and the PyPI JSON API (for AWS Labs).

| Entry | Package | Source | Version | Last modified | Weekly DL |
|-------|---------|--------|---------|---------------|-----------|
| supabase | `@supabase/mcp-server-supabase` | npm (Supabase official) | 0.8.1 | 2026-05-01 | n/a |
| cloudflare | `@cloudflare/mcp-server-cloudflare` | npm (Cloudflare official) | 0.2.0 | 2026-04-07 | n/a |
| aws-cost-explorer | `awslabs.cost-explorer-mcp-server` | PyPI (AWS Labs official) | 0.0.21 | 2026-03-13 | n/a |
| aws-cloudwatch-logs | `awslabs.cloudwatch-logs-mcp-server` | PyPI (AWS Labs official) | 0.0.8 | 2025-10-13 | n/a |

All 4 packages are vendor-stewarded (no community fallbacks needed).

### Alternatives ruled out

- supabase: `@supabase/mcp-server` (404, does not exist), `supabase-mcp` (community, 14mo stale).
- cloudflare: `cloudflare-mcp` (community, version 0.0.0 / 14mo old), `@cloudflare/mcp-server-bindings` (404).
- aws-*: No npm equivalents exist for either AWS Labs package — npm probes returned 404 for both `awslabs.cost-explorer-mcp-server` and `@awslabs/cost-explorer-mcp` shapes. Only PyPI ships these. Used `uvx ... @latest` install pattern (matches CONTEXT.md INT-04/05 fallback note).

## Linux install strategy per entry

| Entry | Strategy | Command |
|-------|----------|---------|
| supabase CLI | npm-global | `npm install -g supabase` (avoids the sudo tarball install path) |
| cloudflare CLI | npm-global | `npm install -g wrangler` (same on macOS too) |
| aws CLI (shared) | user-space tarball | `curl ... awscli-exe-linux-x86_64.zip → unzip → /tmp/aws/install --install-dir ~/.local/aws-cli --bin-dir ~/.local/bin` (vendor-recommended, no sudo) |

All four CLI install commands honor the **no-sudo** invariant (CONTEXT.md D-13).

## Schema notes

- `categories[]` extended in this plan from 5 entries to all 10 canonical entries (`docs-research`, `backend`, `payments`, `email`, `workspace`, `project-management`, `communication`, `design`, `dev-tools`, `monitoring`). Subsequent plans use these.
- `components.cli` introduced as a sibling to `components.mcp`. Validator (Phase 32 CAT-03) only enforces shape on `components.mcp`; the new CLI section is unrestricted by the validator (Phase 34 TUI work will read it). Adding it now keeps Phase 33 a pure data mutation.
- AWS entries declare BYTE-IDENTICAL `cli` blocks (Python `dict` reuse via shared variable). Phase 34 TUI dedupes by `cli.detect_cmd`.

## Self-test results

- `python3 scripts/validate-integrations-catalog.py` → PASSED (13 mcp entries, 10 categories)
- `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0 (S1 assertions updated to track new catalog state — count 13, alpha-first `aws-cloudwatch-logs`, notion still OAuth)
- `bash scripts/tests/test-integrations-foundation.sh` → PASS=32 FAIL=0
- `make check` → All checks passed

## Deviations

- **Rule 3 (auto-fix blocking issue):** `test-mcp-selector.sh` S1 hard-coded `9 entries` and `alpha-first context7`. Adding 4 backend entries inverts both assertions. Updated S1 to track the post-Plan-33-01 catalog state (count=13, alpha-first=`aws-cloudwatch-logs`). Plans 33-02..04 will further update these per-mutation. Comment added in test explaining the dynamic-tracking pattern.

No deferred entries — all 4 packages verified and committed.

## Acceptance criteria

- [x] 4 new entries in catalog (count = 13)
- [x] Validator exit 0
- [x] test-mcp-selector.sh PASS=21 baseline preserved (S1 updated to track new state)
- [x] test-integrations-foundation.sh PASS=32 baseline preserved
- [x] make check rc=0
- [x] AWS entries have byte-identical `cli` blocks
- [x] No `sudo` in any install command
- [x] Single conventional commit (08455ee)
