#!/usr/bin/env python3
"""
save_raw_log.py — Stage 1 of the two-stage auto-memo pipeline.

Runs at SessionEnd. Fast, no API calls. Just saves the last 30 messages
from the transcript as a raw daily log in markdown format.

The compile step (compile_logs.py) runs later via cron and turns
these raw logs into structured wiki/memo articles.

Why two stages:
- SessionEnd has 1.5s timeout — can't do API calls reliably
- Even with nohup, keeping the fast path fast is better
- Raw logs capture EVERYTHING, compile can be selective
- If compile fails, raw logs are still there as backup
"""

import json
import os
import sys
from datetime import datetime


def read_last_messages(transcript_path: str, max_messages: int = 30) -> list[dict]:
    """Read the last N messages from a JSONL transcript."""
    messages = []
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        for line in lines[-(max_messages * 3) :]:  # Read extra lines, filter
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if not isinstance(entry, dict):
                    continue
                # Handle Claude Code nested format: {"type": "user", "message": {"role": "user", "content": "..."}}
                if "message" in entry and isinstance(entry["message"], dict):
                    entry = entry["message"]
                role = entry.get("role", "")
                content = entry.get("content", "")
                if isinstance(content, list):
                    content = " ".join(
                        b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"
                    )
                if role in ("user", "assistant") and content and content.strip():
                    messages.append({"role": role, "content": content})
            except json.JSONDecodeError:
                continue
    except Exception:
        return []
    return messages[-max_messages:]


def save_daily_log(messages: list[dict], vault_path: str, session_id: str):
    """Append messages to today's daily log file."""
    logs_dir = os.path.join(vault_path, "daily-logs")
    os.makedirs(logs_dir, exist_ok=True)

    today = datetime.now().strftime("%Y-%m-%d")
    timestamp = datetime.now().strftime("%H:%M:%S")
    log_file = os.path.join(logs_dir, f"{today}.md")

    # Create file header if new
    if not os.path.exists(log_file):
        header = f"---\ndate: {today}\ntype: daily-log\n---\n\n# Daily Log — {today}\n\n"
        with open(log_file, "w", encoding="utf-8") as f:
            f.write(header)

    # Append session log
    entry = f"\n## Session {session_id[:8]} ({timestamp})\n\n"
    for msg in messages:
        role = msg["role"].upper()
        content = msg["content"]
        # Truncate very long messages but keep enough for context
        if len(content) > 1500:
            content = content[:1500] + "\n\n*[truncated]*"
        entry += f"**{role}:** {content}\n\n"
    entry += "---\n"

    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(entry)
        return log_file
    except Exception:
        return None


def main():
    vault_path = os.environ.get("MEMO_VAULT_PATH", "")

    # Also accept --vault argument
    if not vault_path:
        for i, arg in enumerate(sys.argv):
            if arg == "--vault" and i + 1 < len(sys.argv):
                vault_path = os.path.expanduser(sys.argv[i + 1])

    if not vault_path:
        default = os.path.expanduser("~/memo-vault")
        if os.path.exists(default):
            vault_path = default
        else:
            print(
                "Error: MEMO_VAULT_PATH is not set and ~/memo-vault does not exist.\n"
                "Set the environment variable: export MEMO_VAULT_PATH=/path/to/your/vault\n"
                "Or pass --vault /path/to/your/vault",
                file=sys.stderr,
            )
            sys.exit(1)

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    session_id = hook_input.get("session_id", "unknown")

    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    messages = read_last_messages(transcript_path)
    if len(messages) < 4:
        sys.exit(0)

    log_file = save_daily_log(messages, vault_path, session_id)

    # Log what we did
    if log_file:
        memo_log = os.path.join(vault_path, ".memo", "auto_memo.log")
        os.makedirs(os.path.dirname(memo_log), exist_ok=True)
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(memo_log, "a") as f:
            f.write(f"[{ts}] Raw log saved: {os.path.basename(log_file)} ({len(messages)} messages)\n")


if __name__ == "__main__":
    main()
