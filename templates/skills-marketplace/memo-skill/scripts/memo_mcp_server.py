#!/usr/bin/env python3
"""
memo_mcp_server.py — MCP Server for Memo engineering memory.

Exposes vault search, save, query, and analysis as MCP tools.
Any MCP-compatible client (Claude Desktop, Claude.ai, Cursor,
Windsurf, Cline) can connect and use engineering memory.

Usage (stdio, local):
  python memo_mcp_server.py

Configuration (Claude Desktop — claude_desktop_config.json):
  {
    "mcpServers": {
      "memo": {
        "command": "python3",
        "args": ["/path/to/memo_mcp_server.py"],
        "env": {
          "MEMO_VAULT_PATH": "~/engineering-brain"
        }
      }
    }
  }

Configuration (Claude Code — settings.json):
  {
    "mcpServers": {
      "memo": {
        "command": "python3",
        "args": ["/path/to/memo_mcp_server.py"],
        "env": {
          "MEMO_VAULT_PATH": "~/engineering-brain"
        }
      }
    }
  }

Requirements:
  pip install mcp sentence-transformers numpy PyYAML
"""

import json
import os
import sys

# Add scripts dir to path for memo imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

from mcp.server.fastmcp import FastMCP

# ─── Server setup ───

mcp = FastMCP(
    "Memo",
    description=(
        "Persistent engineering memory with semantic search. "
        "Search decisions, patterns, debug solutions, and insights "
        "across all projects from a single Obsidian vault."
    ),
)


def get_vault_path() -> str:
    """Get vault path from environment or default."""
    path = os.environ.get("MEMO_VAULT_PATH", "~/engineering-brain")
    return os.path.expanduser(path)


# ─── Tools ───


@mcp.tool()
def memo_search(query: str, limit: int = 10) -> str:
    """Search the engineering memory vault using semantic + keyword search.

    Use this to find past decisions, patterns, debug solutions,
    and insights across all projects. Works with both English and Russian.

    Args:
        query: What to search for (natural language).
        limit: Max results to return (default 10).
    """
    from memo_engine import search_vault

    vault = get_vault_path()
    results = search_vault(query, vault, limit=limit, threshold=0.3)

    if not results:
        return "No results found. Try different search terms or check /memo stats."

    lines = [f"Found {len(results)} result(s):\n"]
    for r in results:
        score = f"{r['score']:.2f}"
        tags = ", ".join(json.loads(r.get("tags", "[]"))) if r.get("tags") else ""
        lines.append(f"- **{r['title']}** (score: {score})")
        lines.append(f"  Path: {r['filepath']}")
        if r.get("project"):
            lines.append(f"  Project: {r['project']}")
        if tags:
            lines.append(f"  Tags: {tags}")
        if r.get("body"):
            snippet = r["body"][:200].replace("\n", " ").strip()
            lines.append(f"  {snippet}...")
        lines.append("")

    return "\n".join(lines)


@mcp.tool()
def memo_query(question: str) -> str:
    """Ask a question and get an AI-synthesized answer from the vault.

    Uses semantic search to find relevant notes, then Claude Haiku
    synthesizes a direct answer. Cost: ~$0.001 per query.

    Args:
        question: Natural language question about past work.
    """
    from memo_engine import query_vault

    vault = get_vault_path()
    return query_vault(question, vault)


@mcp.tool()
def memo_save(
    title: str,
    content: str,
    memo_type: str = "insight",
    project: str = None,
    tags: list[str] = None,
    aliases: list[str] = None,
    context: str = None,
    alternatives: str = None,
    consequences: str = None,
) -> str:
    """Save a new note to the engineering memory vault.

    Use this to capture decisions, patterns, debug solutions,
    insights, or tool discoveries worth remembering.

    Args:
        title: Clear, searchable title (like a search query you'd use in 6 months).
        content: The actual knowledge — specific and concrete.
        memo_type: One of: decision, pattern, debug, insight, tool.
        project: Project name (e.g. "jobhunter", "digital-planet") or None for cross-project.
        tags: List of tags for categorization.
        aliases: Alternative names someone might search for.
        context: Why this came up (2-3 sentences).
        alternatives: What else was considered (for decisions).
        consequences: What this means going forward.
    """
    from memo_utils import save_memo, index_memo_file

    vault = get_vault_path()

    memo = {
        "type": memo_type,
        "title": title,
        "content": content,
        "project": project,
        "tags": tags or [],
        "aliases": aliases or [],
        "context": context,
        "alternatives": alternatives,
        "consequences": consequences,
    }

    filepath = save_memo(memo, vault, source="mcp")
    if filepath:
        index_memo_file(filepath, vault)
        rel = os.path.relpath(filepath, vault)
        return f"Saved: {rel}\nTitle: {title}\nType: {memo_type}"
    return "Failed to save memo. Check vault path and permissions."


@mcp.tool()
def memo_list(limit: int = 20) -> str:
    """List recent notes from the vault, newest first.

    Args:
        limit: How many notes to show (default 20).
    """
    from memo_engine import list_notes

    vault = get_vault_path()
    notes = list_notes(vault, limit)

    if not notes:
        return "Vault is empty or not indexed. Run memo_stats to check."

    lines = [f"Last {len(notes)} notes:\n"]
    for n in notes:
        project = f" [{n['project']}]" if n.get("project") else ""
        lines.append(f"- {n.get('created', '?')} | {n['title']}{project} ({n['type']})")

    return "\n".join(lines)


@mcp.tool()
def memo_stats() -> str:
    """Get vault statistics: total notes, notes by type, by project, etc."""
    from memo_engine import vault_stats

    vault = get_vault_path()
    s = vault_stats(vault)
    return json.dumps(s, indent=2, ensure_ascii=False)


@mcp.tool()
def memo_lint() -> str:
    """Run 7 health checks on the vault. Reports broken links,
    orphan notes, missing backlinks, empty notes, and more.
    """
    from memo_engine import lint_vault

    vault = get_vault_path()
    issues = lint_vault(vault)
    summary = issues.pop("_summary", {})

    lines = [
        f"Vault lint: {summary.get('total_issues', 0)} issues "
        f"in {summary.get('total_notes', 0)} notes",
        f"Obsidian CLI: {'yes' if summary.get('obsidian_cli') else 'no (regex fallback)'}\n",
    ]

    for check, items in issues.items():
        if items:
            lines.append(f"{check}: {len(items)} issue(s)")
            for item in items[:5]:
                if isinstance(item, dict):
                    lines.append(
                        f"  - {item.get('title', item.get('filepath', str(item)))}"
                    )
                else:
                    lines.append(f"  - {item}")
            if len(items) > 5:
                lines.append(f"  ... and {len(items) - 5} more")

    return "\n".join(lines)


@mcp.tool()
def memo_trace(concept: str, limit: int = 10) -> str:
    """Trace the evolution of an idea over time.

    Finds all notes mentioning a concept, sorted chronologically,
    with excerpts. Shows how your understanding evolved.

    Args:
        concept: The idea to trace (e.g. "авторизация", "CORS", "caching").
        limit: Max notes to include.
    """
    from memo_engine import search_vault

    vault = get_vault_path()
    results = search_vault(concept, vault, limit=limit * 2, threshold=0.3)

    if not results:
        return f"No notes found about '{concept}'."

    # Sort chronologically
    results.sort(key=lambda r: r.get("created", ""))

    # Read actual content for top results
    lines = [f"## Evolution: {concept}\n"]

    for r in results[:limit]:
        filepath = os.path.join(vault, r["filepath"])
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            # Extract body (skip frontmatter)
            parts = content.split("---", 2)
            body = parts[2].strip() if len(parts) >= 3 else content
            # Take first 300 chars
            snippet = body[:300].replace("\n", " ").strip()
            if len(body) > 300:
                snippet += "..."
        except Exception:
            snippet = "(could not read file)"

        date = r.get("created", "unknown")
        note_type = r.get("type", "note")
        project = f" [{r.get('project')}]" if r.get("project") else ""

        lines.append(f"### {date} — {r['title']} ({note_type}){project}")
        lines.append(f"{snippet}\n")

    lines.append(
        f"→ {len(results)} notes found. "
        f"Showing {min(limit, len(results))} in chronological order."
    )

    return "\n".join(lines)


@mcp.tool()
def memo_find_duplicates(threshold: float = 0.85) -> str:
    """Find semantically similar notes that might be duplicates.

    Args:
        threshold: Similarity threshold (0.0-1.0). Default 0.85 = very similar.
    """
    from memo_engine import find_duplicates

    vault = get_vault_path()
    pairs = find_duplicates(vault, threshold)

    if not pairs:
        return f"No duplicates found above {threshold} similarity threshold."

    lines = [f"Found {len(pairs)} potential duplicate pair(s):\n"]
    for p in pairs[:10]:
        lines.append(
            f"- {p['title_a']} ↔ {p['title_b']} "
            f"(similarity: {p['similarity']:.2f})"
        )

    return "\n".join(lines)


# ─── Run ───

if __name__ == "__main__":
    mcp.run(transport="stdio")
