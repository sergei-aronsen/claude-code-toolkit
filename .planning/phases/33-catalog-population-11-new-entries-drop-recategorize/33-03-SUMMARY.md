---
plan_id: 33-03
phase: 33
title: Communication + Research with unofficial flags — notebooklm, slack, telegram
status: complete
commit: a2d3326
req_ids: [INT-06, INT-11, INT-12]
executed_on: 2026-05-02
---

# Plan 33-03 Summary

## Overview

Added 3 entries spanning `docs-research` (notebooklm) and `communication` (slack, telegram). Two carry `unofficial: true` (notebooklm, telegram) — Phase 34 TUI will render these with a yellow `!` glyph + per-row confirm prompt. Catalog count: 18 → 21.

## Verified Packages — extra scrutiny on `unofficial: true`

| Entry | Package | Stewardship | Version | Last modified | Weekly DL | Notes |
|-------|---------|-------------|---------|---------------|-----------|-------|
| notebooklm | `notebooklm-mcp` | community (PleasePrompto) | 2.0.0 | 2026-05-01 | 7519 | >100 DL, <12mo — passes |
| slack | `slack-mcp-server` | community (korotovsky) | 1.2.3 | 2026-03-03 | 17388 | replaces the deprecated official package |
| telegram | `@chaindead/telegram-mcp` | community (chaindead) | 0.2.0 | 2026-02-27 | 458 | >100 DL, <12mo — passes |

### Alternatives ruled out

- **notebooklm**:
  - `mcp-server-notebooklm` (404, doesn't exist)
  - `nlm-mcp` (404)
  - `notebooklm-mcp` selected — actively maintained (released today 2026-05-01) with strong adoption (7519 weekly DL).
- **slack**:
  - `@modelcontextprotocol/server-slack` officially deprecated by Anthropic (npm `view ... deprecated` returns "Package no longer supported"). Despite 50826 weekly DL, NOT shippable as the catalog default — would lock users into an unmaintained binary.
  - `slack-mcp-server` (korotovsky) is the highest-adoption fork (17388 weekly), active maintenance, and supports both Stealth (browser cookies) and OAuth modes.
  - `@thlee/slack-mcp` (low-stewardship), `@mseep/slack-mcp-server` (mseep wrapper), and other forks have far lower adoption.
- **telegram**:
  - `telegram-mcp` v0.1.20 (2025-04-08, 13mo old, only 32 weekly) — fails currency + DL threshold.
  - `mcp-telegram` v0.0.1 (2025-03-30, 14mo, 34 weekly) — fails both.
  - `telegram-mcp-bot` v1.0.4 (2026-04-13, 60 weekly) — fails DL threshold.
  - `@zhigang1992/telegram-mcp` v1.2.1 (2026-04-07, 31 weekly) — fails DL threshold.
  - `@chaindead/telegram-mcp` chosen as the only candidate passing all three gates.

## Linux install strategy per entry

| Entry | Strategy | Detail |
|-------|----------|--------|
| notebooklm | hint-only (no `cli` block) | The MCP package handles browser auth via Patchright stealth Chrome on first run. There is no companion `nlm` CLI on npm or PyPI under the same project — only an unrelated `nlm` (semantic versioning tool) on npm. CONTEXT.md D-13 explicitly allows hint-only fallback. |
| slack | n/a (MCP-only) | Auth is API-side via env-vars (Stealth-mode XOXC/XOXD cookies). |
| telegram | n/a (MCP-only) | Auth is API-side via TG_APP_ID/TG_API_HASH from my.telegram.org. The package's own auth subcommand can be invoked via `npx -y @chaindead/telegram-mcp auth ...` if needed — surfaced via post-install docs, not a catalog CLI block. |

## Schema notes

- `unofficial: true` set to `{notebooklm, telegram}` per the plan and CONTEXT.md INT-06 / INT-12.
- Slack env-var keys updated to match the chosen package's documented Option 1 (Stealth mode): `SLACK_MCP_XOXC_TOKEN` + `SLACK_MCP_XOXD_TOKEN`. The CONTEXT.md draft listed `SLACK_BOT_TOKEN` + `SLACK_TEAM_ID` (the deprecated official package's keys) — switching the package required switching the env vars.
- Telegram env-var keys set to `TG_APP_ID` + `TG_API_HASH` per the chosen `@chaindead/telegram-mcp` README. CONTEXT.md draft listed `TELEGRAM_BOT_TOKEN`, but chaindead's MCP uses MTProto user-API IDs (not Bot API tokens) — package-faithful per D-03.

## Self-test results

- `python3 scripts/validate-integrations-catalog.py` → PASSED (21 mcp entries, 10 categories)
- `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0 (S1 updated: count=21)
- `bash scripts/tests/test-integrations-foundation.sh` → PASS=32 FAIL=0
- `make check` → All checks passed
- Unofficial-set assertion: `unofficial: true` set = `{notebooklm, telegram}` ✓

## Deviations

- **Rule 2 (auto-add missing critical functionality):** Chose `slack-mcp-server` (korotovsky fork) over CONTEXT.md's deprecated suggestion `@modelcontextprotocol/server-slack`. The original is officially deprecated and shipping it as the catalog default would expose users to an unmaintained dependency — a security/correctness concern. Documented above; same Slack capability is delivered via the maintained fork.
- **Rule 1 (auto-fix bug):** Telegram env-vars CONTEXT.md draft were `TELEGRAM_BOT_TOKEN` (Bot API), but the chosen `@chaindead/telegram-mcp` uses MTProto **user-account** API (not Bot API). Switched to the package's documented `TG_APP_ID` + `TG_API_HASH`. Same for Slack.
- **Rule 3 (auto-fix blocking issue):** `test-mcp-selector.sh` S1 count assertion updated from 18 to 21.
- **Hint-only fallback:** notebooklm CLI block omitted (Rule 3 + CONTEXT.md D-13). No verifiable installable `nlm` CLI on npm/PyPI; the MCP package is self-sufficient.

No entries deferred — all 3 verified and committed.

## Acceptance criteria

- [x] Catalog count = 21 (transient; will become 19 after 33-04)
- [x] `unofficial: true` set = {notebooklm, telegram}
- [x] Validator exit 0
- [x] Baselines preserved (mcp-selector 21/21, foundation 32/32)
- [x] make check rc=0
- [x] No unofficial entry skipped (all 3 verified)
- [x] Single conventional commit (a2d3326)
