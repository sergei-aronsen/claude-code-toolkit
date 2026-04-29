---
description: Show Supreme Council usage and cost summary from ~/.claude/council/usage.jsonl
---

# /council-stats

Render Council token usage and cost from the local log
(`~/.claude/council/usage.jsonl`). No API calls — works offline.

## Usage

When the user types `/council-stats` (or any of the period variants below),
run the corresponding `brain stats` invocation and present the output verbatim.

| User asks for | Command |
|---------------|---------|
| Today / last 24h | `brain stats --day` |
| This week | `brain stats --week` |
| This month | `brain stats --month` |
| All time (default) | `brain stats --total` |
| Range | `brain stats --since 2026-04-01 --until 2026-04-30` |
| Machine-readable | append `--csv` to any of the above |

The output is grouped by `(provider, model, mode)` and totals tokens + cost
in USD. Cost comes from `~/.claude/council/pricing.json` overlaid on the
built-in `DEFAULT_PRICING` table. CLI calls (Gemini CLI, Codex CLI) are
priced at $0 per token because subscription covers them; their token counts
are estimated (`chars / 4`) and marked with `estimated: true` per record.

## Notes

- The log is append-only and never sent off-machine. Delete it with
  `rm ~/.claude/council/usage.jsonl` if you want to reset history.
- Update `~/.claude/council/pricing.json` when provider rates change. Local
  edits are preserved on toolkit update via the `.upstream-new.json` sidecar
  pattern.
- Phase 24 Sub-Phase 4.
