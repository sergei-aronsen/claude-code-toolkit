#!/usr/bin/env python3
"""
pre_compact_save.py — PreCompact hook.

When Claude Code auto-compacts the context window mid-session,
it discards details. This hook fires BEFORE compaction, grabs the
last N messages, and saves them as a raw daily log — same logic
as session_end, but triggered by compaction instead of exit.

This is the "insurance policy" for long sessions where important
decisions from the first hour get lost when Claude compacts at hour 3.

Runs synchronously (PreCompact waits for hooks), so keep it fast.
No API calls — just dump messages to a raw log file.
"""

import json
import os
import sys
from datetime import datetime


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    session_id = hook_input.get("session_id", "unknown")

    vault_path = os.environ.get("MEMO_VAULT_PATH", os.path.expanduser("~/engineering-brain"))
    logs_dir = os.path.join(vault_path, "daily-logs")
    os.makedirs(logs_dir, exist_ok=True)

    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    # Read last 30 messages from transcript
    messages = []
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        for line in lines[-60:]:  # Read more lines, filter to 30 messages
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if isinstance(entry, dict):
                    role = entry.get("role", "")
                    content = entry.get("content", "")
                    if isinstance(content, list):
                        content = " ".join(
                            b.get("text", "") for b in content
                            if isinstance(b, dict) and b.get("type") == "text"
                        )
                    if role in ("user", "assistant") and content and content.strip():
                        messages.append({"role": role, "content": content[:2000]})
            except json.JSONDecodeError:
                continue
    except Exception:
        sys.exit(0)

    if len(messages) < 3:
        sys.exit(0)

    # Save as raw daily log
    today = datetime.now().strftime("%Y-%m-%d")
    timestamp = datetime.now().strftime("%H:%M:%S")
    log_file = os.path.join(logs_dir, f"{today}.md")

    log_entry = f"\n## Pre-compact save ({timestamp}, session {session_id[:8]})\n\n"
    for msg in messages[-30:]:
        role = msg["role"].upper()
        content = msg["content"]
        if len(content) > 500:
            content = content[:500] + "..."
        log_entry += f"**{role}:** {content}\n\n"

    log_entry += "---\n"

    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(log_entry)
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
