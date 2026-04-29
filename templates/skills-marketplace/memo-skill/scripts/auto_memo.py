#!/usr/bin/env python3
"""
auto_memo.py — Automatic memo extraction from Claude Code session transcripts.

Runs as a SessionEnd hook. Reads the session transcript, detects memo-worthy
content (decisions, patterns, debug solutions, insights), and auto-saves
notes to the Obsidian vault.

Usage (called by Claude Code hook, not manually):
  echo '{"transcript_path": "...", "session_id": "..."}' | python auto_memo.py --vault ~/memo-vault

How it works:
  1. Reads the JSONL transcript file
  2. Extracts assistant + user messages
  3. Sends to Claude API (Haiku — fast and cheap) with a classification prompt
  4. If memo-worthy content found → generates structured notes
  5. Saves to vault, indexes in SQLite + embeddings
  6. Logs what was saved for transparency

Cost: ~$0.001-0.005 per session (Haiku). Runs async, doesn't block.
"""

import argparse
import json
import os
import sys
from datetime import datetime


def read_transcript(transcript_path: str) -> list[dict]:
    """Read JSONL transcript and extract conversation messages.

    Handles multiple transcript formats robustly:
    - Standard {role, content} messages
    - Content as list of typed blocks [{type: "text", text: "..."}]
    - Tool use/result blocks (extracted as context)
    - Unknown formats (logged, skipped gracefully)
    """
    messages = []
    unknown_formats = 0
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    # Not JSON — could be a log line or separator
                    continue

                if not isinstance(entry, dict):
                    continue

                # Handle Claude Code nested format: {"type": "user", "message": {"role": "user", "content": "..."}}
                if "message" in entry and isinstance(entry["message"], dict):
                    entry = entry["message"]

                role = entry.get("role", "")
                content = entry.get("content", "")

                # Handle content as list of blocks
                if isinstance(content, list):
                    text_parts = []
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        btype = block.get("type", "")
                        if btype == "text":
                            text_parts.append(block.get("text", ""))
                        elif btype == "tool_use":
                            # Include tool name for context
                            tool_name = block.get("name", "unknown_tool")
                            tool_input = json.dumps(block.get("input", {}))[:200]
                            text_parts.append(f"[Used tool: {tool_name}({tool_input})]")
                        elif btype == "tool_result":
                            # Include truncated result
                            result_content = block.get("content", "")
                            if isinstance(result_content, list):
                                result_content = " ".join(
                                    b.get("text", "") for b in result_content if isinstance(b, dict)
                                )
                            if result_content:
                                text_parts.append(f"[Tool result: {str(result_content)[:200]}]")
                    content = "\n".join(text_parts)

                # Handle content as string (simple format)
                elif isinstance(content, str):
                    pass  # Already a string
                else:
                    # Unknown content type
                    content = str(content)[:500] if content else ""
                    unknown_formats += 1

                if role in ("user", "assistant") and content and content.strip():
                    messages.append({"role": role, "content": content})

    except FileNotFoundError:
        return []
    except Exception:
        # Don't crash on any transcript format issue
        if messages:
            return messages  # Return what we got
        return []

    return messages


def truncate_conversation(messages: list[dict], max_chars: int = 15000) -> str:
    """Build a truncated conversation string for the classifier."""
    parts = []
    total = 0
    for msg in messages:
        role = msg["role"].upper()
        content = msg["content"]
        # Truncate individual messages
        if len(content) > 2000:
            content = content[:2000] + "... [truncated]"
        line = f"[{role}]: {content}"
        if total + len(line) > max_chars:
            parts.append("... [conversation truncated for analysis]")
            break
        parts.append(line)
        total += len(line)
    return "\n\n".join(parts)


def classify_and_extract(conversation: str, vault_path: str) -> list[dict]:
    """
    Send conversation to Claude Haiku for classification and extraction.
    Returns list of memo dicts ready to save.
    """
    prompt = f"""Analyze this Claude Code session transcript.
Extract any knowledge worth saving for long-term engineering memory.

Look for:
1. **Decisions** — architecture choices, tech stack picks, tradeoffs discussed
2. **Patterns** — reusable code approaches, techniques established
3. **Debug solutions** — non-trivial bugs solved (took multiple attempts)
4. **Insights** — learnings, "aha" moments, performance discoveries
5. **Tool discoveries** — new CLI tools, configs, workflow improvements

Rules:
- Only extract genuinely useful knowledge. Skip casual chat, simple questions, trivial fixes.
- If nothing is memo-worthy, return an empty array.
- Be concise. Each memo should be a distilled atomic note, not a transcript dump.
- Write in the same language as the conversation (Russian or English).
- Keep technical terms in English regardless of language.

Return ONLY a JSON array (no markdown, no backticks). Each item:
{{
  "type": "decision|pattern|debug|insight|tool",
  "title": "Clear searchable title (like a search query you'd use in 6 months)",
  "project": "project name if identifiable, or null",
  "tags": ["tag1", "tag2"],
  "aliases": ["alternative name 1"],
  "context": "Why this came up, 2-3 sentences",
  "content": "The actual knowledge, specific and concrete",
  "alternatives": "What else was considered (for decisions), or null",
  "consequences": "What this means going forward, or null"
}}

If nothing is worth saving, return: []

TRANSCRIPT:
{conversation}"""

    # Use secure API client (no curl, no API key in ps)
    from memo_utils import call_haiku, memo_log, parse_json_response

    text = call_haiku(prompt, max_tokens=4000)
    if not text:
        memo_log(vault_path, "API call failed or returned empty", "auto-memo")
        return []

    memos = parse_json_response(text)
    if not isinstance(memos, list):
        return []
    return memos


def _save_memo(memo: dict, vault_path: str, session_id: str) -> str | None:
    """Delegate to shared save_memo in memo_utils."""
    from memo_utils import save_memo

    return save_memo(memo, vault_path, session_id=session_id, source="auto-memo")


def main():
    from memo_utils import index_memo_file, memo_log

    parser = argparse.ArgumentParser(description="Auto-memo from Claude Code transcript")
    parser.add_argument("--vault", required=True, help="Path to vault root")
    args = parser.parse_args()
    vault_path = os.path.expanduser(args.vault)

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        memo_log(vault_path, "No valid JSON on stdin", "auto-memo")
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    session_id = hook_input.get("session_id", "unknown")

    if not transcript_path or not os.path.exists(transcript_path):
        memo_log(vault_path, f"Transcript not found: {transcript_path}", "auto-memo")
        sys.exit(0)

    memo_log(vault_path, f"Processing session {session_id[:12]}...", "auto-memo")

    # 1. Read transcript
    messages = read_transcript(transcript_path)
    if len(messages) < 4:
        memo_log(vault_path, f"Session too short ({len(messages)} messages), skipping", "auto-memo")
        sys.exit(0)

    # 2. Truncate and classify
    conversation = truncate_conversation(messages)
    memos = classify_and_extract(conversation, vault_path)

    if not memos:
        memo_log(vault_path, "No memo-worthy content found", "auto-memo")
        sys.exit(0)

    # 3. Save each memo
    saved = []
    for memo in memos:
        filepath = _save_memo(memo, vault_path, session_id)
        if filepath:
            saved.append(filepath)
            index_memo_file(filepath, vault_path)

    # 4. Mark today's daily log as auto-processed (prevents compile_logs duplication)
    if saved:
        today = datetime.now().strftime("%Y-%m-%d")
        daily_log = os.path.join(vault_path, "daily-logs", f"{today}.md")
        if os.path.exists(daily_log):
            try:
                with open(daily_log, "a", encoding="utf-8") as f:
                    f.write(f"\n<!-- auto-processed session={session_id[:12]} -->\n")
            except Exception:
                pass

    saved_names = ", ".join(os.path.basename(f) for f in saved)
    memo_log(vault_path, f"Auto-saved {len(saved)} memo(s): {saved_names}", "auto-memo")


if __name__ == "__main__":
    main()
