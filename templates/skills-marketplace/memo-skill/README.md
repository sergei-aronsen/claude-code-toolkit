# 🧠 Memo

**Persistent engineering memory for Claude Code.**

Every architecture decision, every debug breakthrough, every hard-won pattern — captured automatically, searchable semantically, connected across projects.

---

Claude Code forgets everything between sessions. You solve a tricky auth bug on Monday, and by Thursday you're solving it again. You choose PostgreSQL over MongoDB after careful analysis, but three months later you can't remember why.

Memo fixes this. It's a Claude Code skill that builds a persistent knowledge vault in Obsidian with semantic search, automatic capture, and cross-project intelligence.

## What it does

```
Session 1:  You debug a CORS issue for 20 minutes. Session ends.
            → Memo auto-captures the solution to your vault.

Session 14: Same CORS error in a different project.
            → Claude already knows the fix. It loaded it at session start.
```

## Features

**Semantic search** — Find notes by meaning, not just keywords. Search "авторизация" and find your note titled "JWT refresh token strategy". Powered by `multilingual-e5-large` (1024 dims, 50+ languages including Russian and English).

**Automatic capture** — SessionEnd hook classifies every conversation via Claude Haiku (~$0.002/session). Decisions, patterns, debug solutions saved automatically. You never need to remember to save.

**Smart context loading** — SessionStart hook detects your project and loads relevant decisions + recent debug fixes into Claude's context. Every session starts informed.

**Mid-session nudges** — Stop hook detects decision-making language ("chose X over Y", "the bug was in...") and gently suggests `/memo`. Zero API cost — pure keyword heuristic.

**Obsidian-native** — Vault is plain markdown with YAML frontmatter and `[[wikilinks]]`. Open in Obsidian, see the graph view, edit by hand. Git-versioned from day one.

**Deduplication** — Semantic similarity check before every save. "JWT auth", "JWT authentication", "bearer token auth" won't fragment into three disconnected notes.

**Cross-project intelligence** — One vault for all projects. Tags and wikilinks connect patterns across codebases. What you learned in project A helps you in project B.

**Race-safe** — File locking via `fcntl.flock` on all write operations. Multiple concurrent Claude Code sessions won't corrupt the index.

## Quick start

```bash
# Install
git clone https://github.com/your-user/memo.git ~/.claude/skills/memo-skill
pip install sentence-transformers

# Initialize vault
bash ~/.claude/skills/memo-skill/scripts/init_vault.sh ~/engineering-brain

# Download embedding model (~1.1GB, one-time)
python3 ~/.claude/skills/memo-skill/scripts/memo_engine.py warm-up

# Set up automation (cron reindex, git backup, model warm-up)
bash ~/.claude/skills/memo-skill/scripts/setup_automation.sh ~/engineering-brain
```

Then add hooks to Claude Code (via `/hooks` or `~/.claude/settings.json`):

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "python3 ~/.claude/skills/memo-skill/scripts/session_context.py"
      }]
    }],
    "SessionEnd": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/skills/memo-skill/scripts/auto_memo_hook.sh ~/engineering-brain"
      }]
    }],
    "PreCompact": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "python3 ~/.claude/skills/memo-skill/scripts/pre_compact_save.py"
      }]
    }],
    "Stop": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "python3 ~/.claude/skills/memo-skill/scripts/should_suggest_memo.py",
        "timeout": 5
      }]
    }]
  }
}
```

Done. Start working. Your vault fills itself.

## Usage

### Save knowledge

```
/memo
```

Claude infers the type (decision, pattern, debug fix, insight, tool) and creates a structured Zettelkasten note with frontmatter, context, and wikilinks.

### Search your vault

```
/memo find how did I solve the CORS issue
/memo find авторизация JWT
```

Combined semantic + keyword search. Finds related notes even with different wording.

### Other commands

| Command | What it does |
|---------|-------------|
| `/memo` | Save a new note (decision, pattern, debug, insight, tool) |
| `/memo find {query}` | Semantic + keyword search across all notes |
| `/memo query {question}` | Search + LLM-synthesized answer (works from terminal) |
| `/memo list` | Show last 10 notes with type and summary |
| `/memo project` | Create/update project overview note |
| `/memo dedup` | Find and resolve duplicate notes |
| `/memo lint` | 7 health checks: broken links, orphans, empty notes |
| `/memo stats` | Vault statistics: notes by type, tags, connections |
| `/memo link` | Connect two notes with wikilinks |
| `/memo reindex` | Rebuild search index from vault files |

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Claude Code                                          │
│                                                      │
│ SessionStart → load project context from vault       │
│ Stop hook → keyword nudge → suggest /memo            │
│ /memo commands → memo_engine.py → vault + index      │
│ SessionEnd → auto_memo.py → classify → auto-save     │
└────────────────────────┬─────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────┐
│ Obsidian Vault (source of truth)                     │
│                                                      │
│ decisions/ patterns/ debug-logs/ insights/            │
│ tools/ references/ projects/ INDEX.md                 │
└────────────────────────┬─────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────┐
│ .memo/ (derived index, gitignored)                   │
│                                                      │
│ index.db ← SQLite + FTS5 (keyword search)            │
│ embeddings.npy ← 1024-dim vectors (semantic search)  │
│ write.lock ← fcntl file lock (concurrency safety)    │
└──────────────────────────────────────────────────────┘
```

Three layers:

1. **Obsidian vault** — human-readable markdown, git-versioned, portable
2. **SQLite + FTS5** — instant keyword search on titles, tags, aliases, content
3. **Embeddings** — semantic search via `intfloat/multilingual-e5-large` (local, free)

The vault is the source of truth. The index is derived — always rebuildable via `/memo reindex`.

## Note format

Every note is an atomic Zettelkasten card:

```markdown
---
type: decision
created: 2026-04-11
updated: 2026-04-11
project: jobhunter-no
tags:
  - database
  - architecture
aliases:
  - PostgreSQL vs MongoDB
  - DB choice for job metadata
---

# PostgreSQL jsonb vs separate tables for job metadata

## Context

Choosing data model for JobHunter.no. Need flexible schema
for varying job posting formats across Finn.no, Webcruiter, Jobbnorge.

## Decision

PostgreSQL with jsonb columns. Keeps relational integrity for core
fields (job_id, company, date) while allowing flexible metadata
per source.

## Alternatives Considered

MongoDB — better for pure document storage, but we need relational
joins for the analytics dashboard. Two databases = operational overhead.

## Consequences

Schema migrations are simpler (jsonb is schema-on-read).
Trade-off: jsonb queries are slower than indexed columns for
complex filters. Acceptable for our scale (<100K records).

## Related

- [[decisions/2026-03-15-fastify-over-express]]
- [[projects/jobhunter-no]]
```

## Auto-capture: how it works

Five layers of protection against knowledge loss:

| Layer | When | How | Cost |
|-------|------|-----|------|
| **Stop hook** | Every Claude response | Keyword heuristic → nudges Claude to suggest `/memo` | $0 |
| **PreCompact hook** | Mid-session compression | Saves last 30 messages before Claude discards details | $0 |
| **SessionEnd Stage 1** | Session closes | Raw daily log saved instantly (no API) | $0 |
| **SessionEnd Stage 2** | After exit (background) | Transcript → Haiku → structured memos | ~$0.002 |
| **Compile (cron)** | Daily at 18:00 | Batch-processes all daily logs → wiki articles | ~$0.01/day |

Two-stage pipeline at SessionEnd: Stage 1 saves a raw daily log immediately (survives even if Stage 2 fails). Stage 2 runs detached via `nohup + disown`, calls Haiku to classify, creates structured memos. The `compile_logs.py` cron job catches anything both stages missed.

Weekly maintenance: `/memo lint` finds broken links, orphans, empty notes. `/memo dedup` merges duplicates.

## Vault structure

```
engineering-brain/
├── INDEX.md                    ← chronological log of all notes
├── decisions/                  ← architecture choices, tech stack picks
├── patterns/                   ← reusable code patterns and approaches
├── debug-logs/                 ← bug fixes, error solutions, workarounds
├── insights/                   ← learnings, observations, discoveries
├── tools/                      ← tool configs, CLI commands, setup procedures
├── references/                 ← external knowledge, article summaries
├── projects/                   ← project overviews (navigational hubs)
├── daily-logs/                 ← raw session logs (auto-captured)
│   ├── 2026-04-11.md           ← compiled → wiki articles
│   └── 2026-04-12.md           ← pending compilation
├── .memo/                      ← search index (gitignored, rebuildable)
│   ├── index.db                ← SQLite + FTS5
│   ├── embeddings.npy          ← numpy vectors (1024 dims)
│   └── auto_memo.log           ← auto-capture log
├── .obsidian/                  ← Obsidian config (color-coded graph)
└── .gitignore                  ← excludes .memo/
```

## Requirements

- **Python 3.10+**
- **sentence-transformers** (`pip install sentence-transformers`)
- **Claude Code** (for skill integration and hooks)
- **~1.5GB RAM** for the embedding model
- **~1.1GB disk** for model download (one-time)
- **Obsidian** (optional, for graph visualization and manual editing)
- **ANTHROPIC_API_KEY** (for auto-memo via Haiku, ~$0.002/session)

## How Memo fits with other tools

| Tool | What it stores | Memo's role |
|------|---------------|-------------|
| **Graphify** | Code structure graph (`graph.json`) | Memo stores *why* you built it that way |
| **MemPalace** | Verbatim conversation history | Memo stores *distilled* decisions and patterns |
| **Claude Memory** | User preferences, facts | Memo stores *engineering* knowledge with context |

Memo doesn't replace these — it fills the gap between "what the code does" (Graphify) and "what we discussed" (MemPalace). It answers: *what did we decide, why, and what were the alternatives?*

## Configuration

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MEMO_VAULT_PATH` | `~/engineering-brain` | Vault location |
| `MEMO_MODEL_CACHE` | `~/.cache/memo-models` | Embedding model cache |
| `ANTHROPIC_API_KEY` | — | Required for auto-memo (Haiku) |

### Automation (installed by `setup_automation.sh`)

- **Cron reindex** every 30 min — catches Obsidian edits
- **Cron git push** every hour — backup to remote
- **Model warm-up** at terminal login — eliminates cold start

## FAQ

**Does it send my code to the cloud?**
No. Embeddings run 100% locally via `multilingual-e5-large`. The only API call is auto-memo classification via Claude Haiku (just the conversation summary, not your code). You can disable auto-memo and use only manual `/memo`.

**What if I close the terminal accidentally?**
SessionEnd fires on Ctrl+C, Ctrl+D, window close, and `/exit`. The auto-memo hook detaches from the process and runs independently. Only a hard crash or power loss prevents capture — and even then, the transcript file remains on disk for manual recovery.

**How much does it cost?**
Embedding model is free (local). Auto-memo uses ~$0.002 of Haiku per session. At 5 sessions/day: ~$1/month.

**Can I use it without Obsidian?**
Yes. The vault is plain markdown — works with any text editor, VS Code, or just `grep`. Obsidian adds graph visualization and wikilink navigation, but isn't required.

**Does it work with non-Claude Code editors?**
The skill commands (`/memo`) are Claude Code specific. But the vault and search engine work standalone — `python memo_engine.py search "query" --vault ~/engineering-brain` runs anywhere.

**What about multilingual content?**
`multilingual-e5-large` supports 50+ languages. Search "авторизация" and find notes titled "JWT authentication". Tags are always in English for consistency; note content follows whatever language you're writing in.

## Ask your vault from terminal

No need to open Claude Code. One command, full answer:

```bash
python3 memo_engine.py query "how did I solve the CORS issue" --vault ~/engineering-brain
```

The engine finds relevant notes via semantic + keyword search, sends them to Haiku, and synthesizes a direct answer with sources. Cost: ~$0.001 per query.

## Cross-project access

Add this to `CLAUDE.md` in any project to give Claude Code access to your vault:

```markdown
## Knowledge Base
When answering architecture or implementation questions, first check the
engineering knowledge vault at ~/Dropbox/WORK/engineering-brain/
Read INDEX.md first, then navigate to relevant wiki articles.
Use /memo to save new decisions and patterns.
```

One line, no hooks needed. Works as a complement to the SessionStart hook.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill definition — triggers, commands, quality guidelines |
| `memo_engine.py` | Core engine: SQLite + FTS5 + e5 embeddings + lint + query |
| `auto_memo.py` | Auto-classify transcripts via Haiku |
| `auto_memo_hook.sh` | SessionEnd wrapper: Stage 1 (raw log) + Stage 2 (classify, detached) |
| `save_raw_log.py` | Stage 1: fast daily log dump, no API |
| `compile_logs.py` | Cron: batch-compile daily logs → structured wiki articles |
| `pre_compact_save.py` | PreCompact hook: saves context before mid-session compression |
| `session_context.py` | SessionStart: load project context from vault |
| `should_suggest_memo.py` | Stop hook: keyword nudge for `/memo` |
| `init_vault.sh` | Vault + Obsidian + git initialization |
| `setup_automation.sh` | Cron + warm-up + env var setup |

## Contributing

Issues and PRs welcome. The codebase is intentionally simple — no frameworks, no abstractions beyond what's needed.

If you're adding a feature, keep in mind:

- Vault markdown is the source of truth, index is always derived
- No external services required (except optional Haiku for auto-memo)
- Everything must work for a single developer with 5 notes or 5000

## License

MIT
