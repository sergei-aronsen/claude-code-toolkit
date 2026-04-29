---
description: Empty the Supreme Council content-hash cache at ~/.claude/council/cache
---

# /council clear-cache

Remove every cached `/council` result from `~/.claude/council/cache/`.
Use it after editing your plan when the cache is masking your changes,
or when you want to force a fresh review.

## Purpose

The Council caches identical requests by content hash so repeated
`/council "<same plan>"` calls inside the TTL (default 7 days) replay
the previous result without making API calls. This is great for cost
control but can be confusing if you tweaked the plan slightly and want
the reviewers to see the new version. `clear-cache` is the escape hatch.

## When to Use

| Situation | Use /council clear-cache |
|-----------|--------------------------|
| Cached verdict feels stale after a rebase | yes — git HEAD changed but maybe not enough to invalidate |
| You want to A/B two prompt phrasings | yes — otherwise the second is a hit |
| You want a full re-review without `--no-cache` | yes |
| Disk usage on the cache dir matters | yes |

## Usage

When the user types `/council clear-cache` (or asks to clear the
Council cache), invoke:

```bash
brain clear-cache
```

This empties `~/.claude/council/cache/*.json` and prints the count of
removed entries. Show the output verbatim.

For a one-off bypass without clearing the cache, suggest the
`--no-cache` flag instead:

```bash
brain --no-cache "<plan>"
```

## Notes

- The cache directory is left in place; only the JSON files are removed.
- Cache TTL is configurable via `config.cache.ttl_days` in
  `~/.claude/council/config.json` (default 7 days).
- Phase 24 Sub-Phase 6.
