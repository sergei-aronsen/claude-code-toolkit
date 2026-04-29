---
phase: 25
plan: "01"
subsystem: mcp-catalog
tags: [bash, json, catalog, detection, mcp, phase-25]
dependency_graph:
  requires: []
  provides:
    - scripts/lib/mcp-catalog.json
    - scripts/lib/mcp.sh
  affects:
    - scripts/lib/mcp.sh (consumed by Plan 02 wizard, Plan 03 install.sh page)
tech_stack:
  added:
    - scripts/lib/mcp-catalog.json (9-entry JSON catalog, v1 curated list)
    - scripts/lib/mcp.sh (sourced Bash library, 131 lines)
  patterns:
    - Color guard pattern from detect2.sh (RED/GREEN/YELLOW/BLUE/NC with [[ -z "${VAR:-}" ]])
    - Three-state return (0/1/2) for fail-soft CLI-absent detection (MCP-02 contract)
    - TK_MCP_CLAUDE_BIN + TK_MCP_CATALOG_PATH test seams
    - One-warning-per-shell guard via _MCP_CLI_WARNED global
key_files:
  created:
    - scripts/lib/mcp-catalog.json
    - scripts/lib/mcp.sh
  modified: []
decisions:
  - "MCP_INSTALL_ARGS uses join('') (not join('\\037')) because the plan's code block had a placeholder comment referencing \\037 but the actual jq expression joined with empty string — arrays are split by callers using the raw array"
  - "is_mcp_installed uses a one-time _MCP_CLI_WARNED guard so scanning all 9 MCPs only emits one warning line to stderr"
metrics:
  duration_seconds: 108
  completed_date: "2026-04-29"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 25 Plan 01: MCP Catalog and Loader Summary

**One-liner:** 9-entry MCP catalog JSON + sourced `mcp.sh` library with `mcp_catalog_load`, `mcp_catalog_names`, and three-state `is_mcp_installed` (0/1/2) implementing MCP-02 fail-soft contract.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author scripts/lib/mcp-catalog.json with 9 curated entries | 79625bd | scripts/lib/mcp-catalog.json |
| 2 | Author scripts/lib/mcp.sh — catalog loader + is_mcp_installed | b0be5eb | scripts/lib/mcp.sh |

## The 9 Catalog Entries

| Name | display_name | env_var_keys | requires_oauth | npm package |
|------|-------------|--------------|----------------|-------------|
| context7 | Context7 | CONTEXT7_API_KEY | false | @upstash/context7-mcp |
| firecrawl | Firecrawl | FIRECRAWL_API_KEY | false | firecrawl-mcp |
| magic | Magic | MAGIC_API_KEY | false | @21st-dev/magic |
| notion | Notion | (none) | true | @notionhq/notion-mcp-server |
| openrouter | OpenRouter | OPENROUTER_API_KEY | false | openrouter-mcp |
| playwright | Playwright | (none) | false | @playwright/mcp |
| resend | Resend | RESEND_API_KEY | false | @resend/mcp-send-email |
| sentry | Sentry | SENTRY_AUTH_TOKEN | false | @sentry/mcp-server |
| sequential-thinking | Sequential Thinking | (none) | false | @modelcontextprotocol/server-sequential-thinking |

Zero-config MCPs (empty env_var_keys): `sequential-thinking`, `playwright`, `notion`

## is_mcp_installed Return Code Semantics

| Code | Meaning | Trigger |
|------|---------|---------|
| 0 | MCP is installed | Name found in `claude mcp list` output row prefix |
| 1 | MCP is NOT installed | CLI present, `claude mcp list` ran, name not found |
| 2 | Unknown — CLI absent or list failed | `claude` binary not on PATH, or `claude mcp list` returned non-zero |

Return code 2 is the MCP-02 fail-soft contract. Callers distinguish "not installed" (1) from "can't tell" (2) and render "?" status in the TUI when code 2.

## Deviations from Plan

None — plan executed exactly as written.

Minor note: the plan's `mcp_catalog_load` action showed `join("")` as a placeholder comment in the install_args join expression while mentioning `$'\037'` as the separator. The actual produced code uses `join("")` (concatenation) since install_args elements are stored together and callers split them via the raw JSON array — no deviation from intended behavior, only from the comment text.

## Verification Results

All assertions from the `<verify>` blocks pass:

```text
jq '. | length == 9' mcp-catalog.json          → true
jq '.context7.requires_oauth == false'          → true
jq '.notion.requires_oauth == true'             → true
jq '.["sequential-thinking"].env_var_keys | length == 0' → true
jq '.openrouter.env_var_keys[0] == "OPENROUTER_API_KEY"' → true
jq '. | keys | sort == [...]'                   → true
bash set -euo pipefail; source mcp.sh; mcp_catalog_load → OK
shellcheck -S warning scripts/lib/mcp.sh        → 0 warnings
make shellcheck                                 → ShellCheck passed
```

## Known Stubs

None — both files are complete and functional.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. `mcp.sh` reads a local JSON file and invokes `claude mcp list` as a passive probe only.

## Self-Check: PASSED

- [x] scripts/lib/mcp-catalog.json exists: FOUND
- [x] scripts/lib/mcp.sh exists: FOUND
- [x] Commit 79625bd exists: FOUND
- [x] Commit b0be5eb exists: FOUND
