---
name: memo
description: >
  Persistent engineering knowledge vault with semantic search. Save decisions,
  patterns, debug solutions, and insights as Zettelkasten notes in Obsidian
  with automatic embedding indexing for semantic retrieval. Use this skill
  whenever the user says "/memo", "запомни это", "сохрани в базу", "save this",
  "remember this", "добавь в базу знаний", "log this pattern", or any variation
  of wanting to persist knowledge. Also trigger for "/memo find", "/memo search",
  "что я решал по X", "find in vault", "search vault", "найди в базе" to search
  notes — both keyword and semantic. Trigger for "/memo dedup", "/memo stats",
  "/memo project", "/memo reindex". This is the bridge between Claude Code
  sessions and long-term engineering memory across all projects.
---

# Memo — Engineering Knowledge Vault

You are managing the user's persistent engineering knowledge base — an Obsidian
vault with a semantic search index. This system works at any scale: 5 notes or
5000 notes.

## Architecture Overview

```
Claude Code session
  ↓ /memo
Obsidian vault (markdown, human-readable, git-friendly)
  ↓ auto-index
SQLite + embeddings (.memo/index.db)
  ↓ /memo find
Semantic search → ranked results → context for Claude
```

Three layers, each serving a purpose:

1. **Obsidian vault** — human interface, git-versioned, portable
2. **SQLite index** — fast metadata queries, dedup, stats
3. **Embeddings** — semantic search when keywords fail

The vault is the source of truth. The index is derived and can always be
rebuilt from the vault with `/memo reindex`.

---

## Setup

The vault path is configurable. Default: `~/engineering-brain`

### Step 1: Initialize vault

```bash
bash scripts/init_vault.sh <vault_path>
```

### Step 2: Install Python dependencies (one-time)

```bash
pip install sentence-transformers --break-system-packages
```

### Step 3: Download the embedding model (one-time, ~1.1GB)

```bash
python scripts/memo_engine.py warm-up
```

Model: `intfloat/multilingual-e5-large` — 1024 dims, 50+ languages.
Runs locally, no API calls, no cost. Excellent Russian + English quality.
On M4 MacBook or 128GB server: loads in ~3s, uses ~1.1GB RAM.

### Step 4: Set up automation

```bash
bash scripts/setup_automation.sh <vault_path>
```

This installs: cron reindex every 30 min, git auto-push every hour,
model warm-up at terminal login.

### Step 5: Configure Claude Code hooks

Add to `~/.claude/settings.json` (or use `/hooks` command):

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
        "command": "bash ~/.claude/skills/memo-skill/scripts/auto_memo_hook.sh $MEMO_VAULT_PATH"
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

What each hook does:

- **SessionStart** → loads project note + recent decisions into context
- **SessionEnd** → saves raw daily log (fast) + classifies transcript (background)
- **PreCompact** → saves context before Claude compresses it mid-session
- **Stop** → nudges Claude to suggest /memo when decisions detected

---

## Commands

### `/memo` — Save a new note

**Step 1: Determine note type**

Infer from context. Ask only if genuinely ambiguous.

| Type | Folder | When to use |
|------|--------|-------------|
| `decision` | `decisions/` | Architecture choices, tech stack picks, tradeoffs |
| `pattern` | `patterns/` | Reusable code patterns, approaches, techniques |
| `debug` | `debug-logs/` | Bug fixes, error solutions, workarounds |
| `insight` | `insights/` | Learnings, observations, "aha" moments |
| `tool` | `tools/` | Tool configs, CLI commands, setup procedures |
| `project` | `projects/` | Project overviews and status snapshots |
| `reference` | `references/` | External knowledge, article summaries, API docs |

**Step 2: Deduplication check**

Before creating a note, run the semantic similarity check:

```bash
python scripts/memo_engine.py search "<topic summary>" --vault <vault_path> --limit 5 --threshold 0.4
```

This returns existing notes that are semantically similar. If any results
come back with similarity > 0.6, ask the user:

> "Found a related note: **<title>** (similarity: 0.78).
> Should I: (1) update it, (2) create new and link, or (3) create separate?"

If similarity is 0.4–0.6, mention it but proceed with creation, adding a
`[[wikilink]]` to the related note.

If no results or all < 0.4, create freely.

**Step 3: Generate the note**

```markdown
---
type: {note_type}
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
project: {current_project_name}
tags:
  - {tag1}
  - {tag2}
aliases:
  - {alternative_name_1}
  - {alternative_name_2}
---

# {Clear, Searchable Title}

## Context

{Why this came up. What problem were we solving. 2-3 sentences max.}

## Decision / Solution / Pattern

{The actual knowledge. Be specific. Include code snippets with comments.}

## Alternatives Considered

{What else was on the table and why it was rejected. Skip for debug/tool notes.}

## Consequences

{What this means going forward. Trade-offs accepted. Skip for simple debug.}

## Related

- [[link-to-related-note]]
```

**Aliases matter.** Populate generously — think of all ways someone might
refer to this concept. "JWT auth", "JWT authentication", "bearer token auth",
"token-based authentication" should all be aliases on the same note.

**Step 4: Write the file**

Filename format: `{YYYY-MM-DD}-{slug}.md`

Write to `{vault_path}/{type_folder}/{filename}`. Create folder if needed.

**Step 5: Index the note**

```bash
python scripts/memo_engine.py index-file "<file_path>" --vault <vault_path>
```

This adds the note to the SQLite index with its embedding.

**Step 6: Update INDEX.md**

Append:

```markdown
- [{date}] [[{type_folder}/{slug}]] — {one-line summary}
```

**Step 7: Confirm**

Show: file path, title, tags, wikilinks created, and any related notes found.

---

### `/memo find {query}` — Search the vault

Two-stage search for best results:

```bash
python scripts/memo_engine.py search "{query}" --vault <vault_path> --limit 10
```

This runs:

1. **Semantic search** — embeddings cosine similarity (finds conceptually
   related notes even with different wording)
2. **Keyword search** — SQLite FTS5 full-text search on title, content, tags,
   aliases (finds exact matches)
3. **Merged ranking** — combines both scores, deduplicates, returns top results

Read the top 3 results and present a summary to the user with:

- Title and type
- Relevance score
- Key excerpt (first 2-3 lines of "## Decision / Solution / Pattern")
- File path for direct access

If the query is in Russian, search still works — embeddings handle
multilingual similarity, and FTS handles Russian keyword matching.

---

### `/memo list` — Recent notes

```bash
python scripts/memo_engine.py list --vault <vault_path> --limit 10
```

Shows last N notes sorted by creation date with type and summary.

---

### `/memo link {note1} {note2}` — Connect notes

Add `[[wikilink]]` references between two existing notes. Update the
`## Related` section in both files. Update the index.

---

### `/memo project` — Project snapshot

Create or update a project overview in `projects/`. Captures:

- Project name and purpose
- Current architecture (high level)
- Key decisions made (with `[[links]]` to decision notes)
- Current status and next steps
- Tech stack

This is the "entry point" for a project. When starting a new Claude Code
session on a project, read its project note first to get full context.

---

### `/memo dedup` — Find and resolve duplicates

```bash
python scripts/memo_engine.py dedup --vault <vault_path> --threshold 0.7
```

Finds notes with semantic similarity > threshold. Presents pairs to user:

> "Potential duplicates:
>
> 1. **JWT refresh token strategy** ↔ **Token rotation pattern** (0.82)
> 2. **Redis caching for sessions** ↔ **Session cache layer** (0.74)
> Merge, link, or skip each?"

On merge: combine content, keep the newer filename, create redirect stub
in old location, update all `[[wikilinks]]` across vault, reindex.

---

### `/memo stats` — Vault statistics

```bash
python scripts/memo_engine.py stats --vault <vault_path>
```

Shows: total notes by type, notes per project, most connected notes (highest
wikilink count), orphan notes (no links), tag frequency, vault age.

---

### `/memo reindex` — Rebuild the entire index

```bash
python scripts/memo_engine.py reindex --vault <vault_path>
```

Drops and rebuilds SQLite + embeddings from all markdown files.
Use after manual edits in Obsidian, or if index gets corrupted.
Takes ~1 second per 100 notes.

---

### `/memo lint` — Health check

```bash
python scripts/memo_engine.py lint --vault <vault_path>
```

Runs 7 checks: broken wikilinks, orphan notes (no incoming links),
missing backlinks (A→B but B→A is absent), empty notes (<200 chars),
uncompiled daily logs, notes without tags, notes without aliases.

Run weekly to keep the vault clean. Pairs well with `/memo dedup`.

---

### `/memo query {question}` — Ask your vault (LLM-synthesized)

```bash
python scripts/memo_engine.py query "how did I solve the CORS issue" --vault <vault_path>
```

Finds relevant notes via semantic + keyword search, then sends them
to Claude Haiku to synthesize a direct answer. One command, full answer
from your knowledge base — no need to open Claude Code.

Works from any terminal. Cost: ~$0.001 per query.

---

### `/memo compile` — Turn daily logs into wiki articles

```bash
python scripts/compile_logs.py --vault <vault_path>
```

Takes unprocessed daily logs from `daily-logs/`, sends them to
Claude Haiku in batch, and creates structured wiki articles with
frontmatter, tags, aliases, and wikilinks. From one day of work,
3-7 articles may be generated. Best run via cron at end of workday.

---

### `/memo obsidian-info` — Obsidian CLI status and graph data

```bash
python scripts/memo_engine.py obsidian-info --vault <vault_path>
```

Checks if Obsidian CLI is available and pulls graph data: orphans,
dead-end links, tag counts. When CLI is available, `/memo lint` uses
it for more accurate orphan and broken-link detection (Obsidian resolves
aliases and partial matches that regex parsing misses).

Obsidian CLI is **optional**. Memo works fully without it. To enable:
Obsidian → Settings → General → Command Line Interface → ON.

---

## Auto-Memo: Automatic Knowledge Capture

Four hooks + a compile step ensure nothing falls through the cracks.

### Layer 1: SessionEnd — two-stage capture

**Stage 1 (inline, fast):** `save_raw_log.py` dumps the last 30 messages
into `daily-logs/{date}.md` as raw markdown. No API calls. Runs within
SessionEnd timeout.

**Stage 2 (detached, background):** `auto_memo.py` classifies the full
transcript via Haiku and creates structured memo articles immediately.
If it fails, the raw log is still safe — `compile_logs.py` picks it up.

### Layer 2: PreCompact — insurance for long sessions

When Claude Code auto-compacts the context window mid-session, it discards
details. `pre_compact_save.py` fires BEFORE compaction and saves the last
30 messages to the daily log. Decisions from hour 1 survive compaction at
hour 3.

### Layer 3: Stop hook — mid-session nudge

`should_suggest_memo.py` runs after each Claude response. Detects
decision-making language, debug breakthroughs, or pattern establishment.
Injects a system message nudging Claude to suggest `/memo`. No API cost.

### Layer 4: Manual suggestion (Claude's judgment)

Beyond hooks, suggest saving when you notice non-obvious debug sessions,
architecture decisions, new patterns, or tool discoveries.

### Compile — daily logs → wiki articles

`compile_logs.py` runs via cron (e.g. daily at 18:00). Takes all
uncompiled daily logs, sends them to Haiku, creates structured wiki
articles with frontmatter, tags, aliases, and wikilinks. From one
day of work, 3-7 articles. Marks processed logs with `<!-- compiled -->`.

### How it all works together

```
During session:
  Stop hook → keyword detection → Claude suggests /memo
  User runs /memo → high-quality manual note

Mid-session (long sessions):
  PreCompact → saves context before compression → daily log

Session ends:
  Stage 1: save_raw_log.py → raw daily log (instant)
  Stage 2: auto_memo.py → Haiku → structured memos (background)

Evening (cron):
  compile_logs.py → batch-processes all daily logs → wiki articles

Weekly review:
  /memo lint → broken links, orphans, empty notes
  /memo dedup → merge duplicates
  /memo list → review auto-generated notes, improve titles
```

Result: nothing falls through the cracks. Manual notes are best quality.
Auto-notes are the safety net. Compile catches what auto-memo missed.
Lint keeps the vault clean.

---

## Vault Structure

```
engineering-brain/
├── INDEX.md                    ← chronological log
├── decisions/                  ← architecture and tech choices
├── patterns/                   ← reusable approaches
├── debug-logs/                 ← solved problems
├── insights/                   ← learnings and observations
├── tools/                      ← tool configs and commands
├── references/                 ← external knowledge summaries
├── projects/                   ← project overviews
│   ├── jobhunter-no.md
│   └── digital-planet.md
├── daily-logs/                 ← raw session logs (auto-captured)
│   ├── 2026-04-11.md           ← compiled → wiki articles
│   └── 2026-04-12.md           ← uncompiled (pending)
├── .memo/                      ← index database (gitignored)
│   ├── index.db                ← SQLite with FTS5 + metadata
│   ├── embeddings.npy          ← numpy vectors (1024 dims)
│   └── auto_memo.log           ← log of auto-captured memos
└── .obsidian/                  ← Obsidian config
    ├── app.json
    └── graph.json
```

Add to `.gitignore`:

```
.memo/
```

The `.memo/` directory is derived data — always rebuildable from vault
content via `/memo reindex`.

---

## Quality Guidelines

- **Titles are search queries.** Write them as you'd search in 6 months.
  Good: "PostgreSQL jsonb vs separate tables for job metadata"
  Bad: "Database decision"

- **Context is mandatory.** Without it, a decision note is useless later.

- **Code snippets need comments.** A raw block without explanation is noise.

- **Tags are cross-cutting concerns:** `performance`, `security`,
  `norwegian-locale`, `ai-integration` — concepts spanning projects.

- **Links create value.** More `[[wikilinks]]` = better Obsidian graph view.
  Always check if existing notes should be linked.

- **Aliases prevent fragmentation.** Every note should list alternative names
  for its core concept in the YAML `aliases` field.

- **Updated field tracks evolution.** When appending to an existing note,
  update the `updated:` date in frontmatter.

---

## Language

Write notes in the user's current language. Russian session → Russian notes
(technical terms stay English: `PostgreSQL`, `API`, etc.). English session →
English notes. Tags and aliases are always in English for cross-language search.

---

## Cross-Project Intelligence

The vault is global by design. Notes from different projects coexist and
link to each other. This is how cross-project intelligence works:

- The `project:` field in frontmatter filters per-project when needed
- Tags like `auth`, `caching`, `deployment` connect patterns across projects
- Project notes in `projects/` serve as navigational hubs
- Semantic search finds relevant decisions from other projects automatically

When creating a note for project A, always search the vault first — there
might be a relevant pattern from project B that should be linked.

### Quick access from any project via CLAUDE.md

Add this line to `CLAUDE.md` (or `.claude/settings.md`) in any project:

```markdown
## Knowledge Base

When answering architecture or implementation questions, first check the
engineering knowledge vault at $MEMO_VAULT_PATH (or ~/engineering-brain)
Read INDEX.md first, then navigate to relevant wiki articles.
Use /memo to save new decisions and patterns.
```

This gives Claude Code access to your vault from any project without
needing hooks. Works as a simple fallback alongside the SessionStart hook.

---

## MCP Server — Use Memo from any IDE

`memo_mcp_server.py` exposes vault tools via the Model Context Protocol.
Any MCP-compatible client can connect: Claude Desktop, Claude.ai Projects,
Cursor, Windsurf, Cline.

### Setup (Claude Desktop)

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "memo": {
      "command": "python3",
      "args": ["~/.claude/skills/memo-skill/scripts/memo_mcp_server.py"],
      "env": {
        "MEMO_VAULT_PATH": "~/engineering-brain"
      }
    }
  }
}
```

### Setup (Claude Code)

```json
// In Claude Code settings → MCP Servers
{
  "mcpServers": {
    "memo": {
      "command": "python3",
      "args": ["~/.claude/skills/memo-skill/scripts/memo_mcp_server.py"],
      "env": {
        "MEMO_VAULT_PATH": "~/engineering-brain"
      }
    }
  }
}
```

### Available tools

| Tool | Description |
|------|-------------|
| `memo_search` | Semantic + keyword search across all projects |
| `memo_query` | AI-synthesized answer from vault (uses Haiku) |
| `memo_save` | Save a new note (decision, pattern, debug, insight, tool) |
| `memo_list` | List recent notes |
| `memo_stats` | Vault statistics |
| `memo_lint` | 7 health checks on vault |
| `memo_trace` | Evolution of a concept over time (chronological) |
| `memo_find_duplicates` | Find semantically similar notes |

### Install dependency

```bash
pip install "mcp[cli]>=1.2.0"
```

MCP Server runs locally on your machine. No cloud, no SaaS,
no data leaves your computer. Vault stays on disk.
