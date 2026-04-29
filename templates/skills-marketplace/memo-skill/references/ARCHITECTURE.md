# Memo Skill — Architecture Reference

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Claude Code Lifecycle                           │
│                                                                     │
│  SessionStart hook                                                  │
│  → session_context.py                                               │
│  → detects project (git remote) → loads project note + decisions    │
│  → injects into additionalContext (Claude starts informed)          │
│                                                                     │
│  During session:                                                    │
│  → Stop hook → should_suggest_memo.py → keyword heuristic          │
│  → nudges Claude to suggest /memo when decisions detected           │
│                                                                     │
│  /memo commands:                                                    │
│  → memo_engine.py → SQLite + embeddings → vault read/write         │
│                                                                     │
│  SessionEnd hook                                                    │
│  → auto_memo_hook.sh → nohup auto_memo.py (detached)               │
│  → Haiku classifies transcript → auto-saves memo-worthy content     │
└─────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────┐
│              Obsidian Vault (source of truth)      │
│                                                    │
│  decisions/ patterns/ debug-logs/ insights/        │
│  tools/ references/ projects/ INDEX.md             │
│  .obsidian/ (graph config, color-coded by type)    │
└───────────────────────┬───────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────┐
│              .memo/ (derived, gitignored)           │
│                                                    │
│  index.db        ← SQLite + FTS5 (keyword search)  │
│  embeddings.npy  ← numpy vectors (1024 dims)       │
│  id_map.json     ← note ID ↔ embedding index       │
│  write.lock      ← fcntl file lock (race safety)   │
│  auto_memo.log   ← log of auto-captured memos      │
│  reindex.log     ← cron reindex log                 │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│              Automation (cron + shell)              │
│                                                    │
│  */30 * * * *  → reindex (catches Obsidian edits)  │
│  0 * * * *     → git commit + push (backup)        │
│  shell login   → model warm-up (background)        │
└────────────────────────────────────────────────────┘
```

## Files

| File | Purpose | Runs when |
|------|---------|-----------|
| `SKILL.md` | Skill definition for Claude Code | Claude triggers /memo |
| `memo_engine.py` | Core engine: index, search, dedup, stats | Every /memo command |
| `auto_memo.py` | Classify transcript, auto-save memos | SessionEnd (detached) |
| `auto_memo_hook.sh` | Wrapper: nohup+disown to survive exit | SessionEnd hook |
| `session_context.py` | Load project context from vault | SessionStart hook |
| `should_suggest_memo.py` | Keyword heuristic for /memo nudge | Stop hook |
| `init_vault.sh` | Create vault structure + Obsidian config | First run |
| `setup_automation.sh` | Install cron + warm-up + git push | First run |

## Dependencies

- Python 3.10+
- sentence-transformers (`pip install sentence-transformers`)
- numpy (installed as dependency)
- SQLite3 (built into Python)

## Embedding Model

**Model:** `intfloat/multilingual-e5-large`
- Size: ~1.1GB download, ~1.5GB RAM when loaded
- Dimensions: 1024
- Languages: 50+ including Russian and English
- Protocol: requires "query: " prefix for searches, "passage: " prefix for indexing

**Why this model:**
- `all-MiniLM-L6-v2` (previous): 80MB, 384 dims, English-focused.
  Russian semantic search quality is poor.
- `multilingual-e5-large`: 1.1GB, 1024 dims, top-tier multilingual.
  Handles Russian/English mixed vaults natively.
  On M4 MacBook: loads in ~3s, searches in <100ms.

## Search Algorithm

```
query
  ├── encode_query("query: {text}")
  │     └── cosine similarity vs all passage embeddings
  │           → semantic results (scored 0-1)
  │
  ├── SQLite FTS5 MATCH
  │     └── keyword results (scored 0-1 normalized)
  │
  └── merge: 60% semantic + 40% keyword
        → deduplicate → sort → return top N
```

## Concurrency Safety

All write operations (index-file, reindex) acquire an exclusive file lock
via `fcntl.flock` on `.memo/write.lock`. Concurrent reads (search, list,
stats) proceed without locking. If two processes try to write simultaneously,
the second waits for the first to finish.

## Auto-Memo Pipeline

```
SessionEnd fires → auto_memo_hook.sh
  → reads stdin (hook JSON) → saves to /tmp/auto_memo_input.XXXXX.json
  → nohup python3 auto_memo.py < tmpfile &
  → disown → exit 0 (Claude Code exits immediately)

auto_memo.py (runs independently):
  → reads transcript JSONL
  → truncates to 15K chars
  → sends to Claude Haiku API for classification
  → if memo-worthy: generates markdown notes
  → saves to vault folders
  → indexes in SQLite + embeddings
  → appends to INDEX.md
  → logs to .memo/auto_memo.log
```

## Scaling Notes

| Notes | reindex time | search time | dedup time | model RAM |
|-------|-------------|-------------|------------|-----------|
| 50    | ~10s        | <100ms      | <200ms     | ~1.5GB    |
| 500   | ~90s        | <100ms      | ~2s        | ~1.5GB    |
| 5000  | ~15min      | <200ms      | ~45s       | ~1.5GB    |

Search stays fast at any scale. Reindex is the only slow operation.
RAM usage is constant (model size, not vault size).
