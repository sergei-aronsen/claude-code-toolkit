#!/usr/bin/env python3
"""
session_context.py — SessionStart hook.

Detects the current project (from git or cwd), loads the project note
and last 5 relevant decisions from the vault, and injects them as
additionalContext so Claude starts the session already knowing
your past decisions.

Runs in <2s (no embedding model needed — uses SQLite only).
"""

import json
import os
import sqlite3
import subprocess
import sys


def get_project_name(cwd: str) -> str | None:
    """Detect project name from git remote or directory name."""
    # Try git remote
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=3, cwd=cwd
        )
        if result.returncode == 0:
            url = result.stdout.strip()
            # Extract repo name from URL
            name = url.rstrip("/").split("/")[-1]
            name = name.replace(".git", "")
            return name.lower()
    except Exception:
        pass

    # Fall back to directory name
    return os.path.basename(cwd).lower()


def load_project_context(vault_path: str, project_name: str) -> str | None:
    """Load project note and recent decisions from SQLite."""
    db_path = os.path.join(vault_path, ".memo", "index.db")
    if not os.path.exists(db_path):
        return None

    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row

        context_parts = []

        # 1. Find the project note
        project_row = conn.execute(
            "SELECT filepath, title, body FROM notes WHERE type='project' AND "
            "(LOWER(project) = ? OR LOWER(title) LIKE ?)",
            (project_name, f"%{project_name}%")
        ).fetchone()

        if project_row:
            body = project_row["body"]
            # Truncate to first 800 chars
            if len(body) > 800:
                body = body[:800] + "..."
            context_parts.append(f"## Project: {project_row['title']}\n{body}")

        # 2. Find last 5 decisions for this project (fuzzy match)
        decisions = conn.execute(
            "SELECT title, body, created FROM notes "
            "WHERE type='decision' AND (LOWER(project) = ? OR LOWER(project) LIKE ?) "
            "ORDER BY created DESC LIMIT 5",
            (project_name, f"%{project_name}%")
        ).fetchall()

        if decisions:
            dec_lines = ["## Recent decisions:"]
            for d in decisions:
                # Extract just the first 200 chars of body for brevity
                snippet = d["body"][:200].replace("\n", " ").strip()
                dec_lines.append(f"- **{d['title']}** ({d['created']}): {snippet}")
            context_parts.append("\n".join(dec_lines))

        # 3. Find last 3 debug-logs (common gotchas)
        debugs = conn.execute(
            "SELECT title, created FROM notes "
            "WHERE type='debug' AND (LOWER(project) = ? OR LOWER(project) LIKE ?) "
            "ORDER BY created DESC LIMIT 3",
            (project_name, f"%{project_name}%")
        ).fetchall()

        if debugs:
            debug_lines = ["## Recent bugs solved:"]
            for d in debugs:
                debug_lines.append(f"- {d['title']} ({d['created']})")
            context_parts.append("\n".join(debug_lines))

        conn.close()

        if not context_parts:
            return None

        header = (
            f"[Engineering Brain] Context for project '{project_name}'. "
            "Use /memo find to search for details. Use /memo to save new knowledge.\n\n"
        )
        return header + "\n\n".join(context_parts)

    except Exception:
        return None


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    cwd = hook_input.get("cwd", os.getcwd())

    # Get vault path from environment or default
    vault_path = os.environ.get("MEMO_VAULT_PATH", os.path.expanduser("~/engineering-brain"))

    if not os.path.exists(vault_path):
        sys.exit(0)

    project_name = get_project_name(cwd)
    if not project_name:
        sys.exit(0)

    context = load_project_context(vault_path, project_name)
    if context:
        output = {"additionalContext": context}
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
