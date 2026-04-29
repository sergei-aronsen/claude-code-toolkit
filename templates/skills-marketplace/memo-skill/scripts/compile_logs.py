#!/usr/bin/env python3
"""
compile_logs.py — Batch compiler: daily logs → structured wiki articles.

Runs via cron (e.g., daily at 18:00). Takes all unprocessed daily logs,
sends them to Claude Haiku, and creates structured memo articles.

Skips logs already processed by auto_memo.py (Stage 2) to prevent
duplicate memo creation.

Usage:
  python compile_logs.py --vault ~/engineering-brain
  python compile_logs.py --vault ~/engineering-brain --date 2026-04-11

Cost: ~$0.005-0.02 per day (Haiku batch on all daily logs).
"""

import argparse
import os
import sys
from datetime import datetime

# Add scripts dir to path for memo_utils import
sys.path.insert(0, os.path.dirname(__file__))

from memo_utils import call_haiku, parse_json_response, save_memo, memo_log, index_memo_file


COMPILED_MARKER = "<!-- compiled -->"
AUTO_PROCESSED_MARKER = "<!-- auto-processed"


def find_uncompiled_logs(vault_path: str, target_date: str = None) -> list[str]:
    """Find daily log files that haven't been compiled yet.

    Skips logs that:
    - Already have the <!-- compiled --> marker
    - Were fully auto-processed by auto_memo.py (<!-- auto-processed --> marker)
    - Are too short to contain useful info (<200 chars)
    """
    logs_dir = os.path.join(vault_path, "daily-logs")
    if not os.path.exists(logs_dir):
        return []

    uncompiled = []
    for f in sorted(os.listdir(logs_dir)):
        if not f.endswith(".md"):
            continue
        if target_date and f != f"{target_date}.md":
            continue

        filepath = os.path.join(logs_dir, f)
        try:
            with open(filepath, "r", encoding="utf-8") as fh:
                content = fh.read()
            if COMPILED_MARKER in content:
                continue
            if AUTO_PROCESSED_MARKER in content:
                continue
            if len(content) < 200:
                continue
            uncompiled.append(filepath)
        except Exception:
            continue

    return uncompiled


def compile_log_to_memos(log_path: str, vault_path: str) -> list[dict]:
    """Send a daily log to Haiku for structured extraction."""
    with open(log_path, "r", encoding="utf-8") as f:
        content = f.read()

    if len(content) > 30000:
        content = content[:30000] + "\n\n... [truncated]"

    prompt = f"""Analyze this daily work log from a Claude Code session. Extract ALL knowledge worth preserving as structured notes.

For each piece of knowledge, create a separate memo. Look for:
1. Architecture decisions with tradeoffs
2. Bug fixes that took effort (root cause + solution)
3. Reusable patterns or approaches
4. Tool discoveries or configuration tricks
5. Important insights or learnings

Rules:
- Only extract genuinely useful knowledge. Skip casual chat and trivial stuff.
- If nothing is worth saving, return an empty array.
- Each memo must be atomic — one idea per memo.
- Write in the same language as the log (Russian or English).
- Technical terms stay in English always.
- Generate rich aliases — think of all ways someone might search for this concept.
- Suggest wikilinks to concepts that might exist in the vault.

Return ONLY a JSON array. Each item:
{{{{
  "type": "decision|pattern|debug|insight|tool",
  "title": "Clear searchable title",
  "project": "project name or null",
  "tags": ["tag1", "tag2"],
  "aliases": ["alt name 1", "alt name 2"],
  "context": "Why this came up, 2-3 sentences",
  "content": "The actual knowledge, specific and concrete",
  "alternatives": "What else was considered (decisions only), or null",
  "consequences": "What this means going forward, or null",
  "related": ["possible-wikilink-slug-1", "possible-wikilink-slug-2"]
}}}}

Return [] if nothing worth saving.

DAILY LOG:
{content}"""

    text = call_haiku(prompt, max_tokens=8000)
    if not text:
        return []

    memos = parse_json_response(text)
    return memos if isinstance(memos, list) else []


def mark_as_compiled(log_path: str):
    """Add compiled marker to a daily log."""
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"\n{COMPILED_MARKER}\n")
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(description="Compile daily logs into wiki articles")
    parser.add_argument("--vault", required=True, help="Path to vault root")
    parser.add_argument("--date", default=None, help="Specific date to compile (YYYY-MM-DD)")
    args = parser.parse_args()

    vault_path = os.path.expanduser(args.vault)

    def log(msg):
        memo_log(vault_path, msg, "compile")
        print(msg)

    uncompiled = find_uncompiled_logs(vault_path, args.date)
    if not uncompiled:
        log("No uncompiled logs found.")
        return

    log(f"Found {len(uncompiled)} uncompiled log(s).")

    total_saved = 0
    for lp in uncompiled:
        log_name = os.path.basename(lp)
        log(f"Compiling {log_name}...")

        memos = compile_log_to_memos(lp, vault_path)
        if not memos:
            log(f"  No memo-worthy content in {log_name}")
            mark_as_compiled(lp)
            continue

        for memo in memos:
            filepath = save_memo(memo, vault_path, source="auto-compile")
            if filepath:
                index_memo_file(filepath, vault_path)
                total_saved += 1
                log(f"  Saved: {os.path.basename(filepath)}")

        mark_as_compiled(lp)
        log(f"  Compiled {log_name}: {len(memos)} article(s)")

    log(f"Compile complete: {total_saved} article(s) from {len(uncompiled)} log(s).")


if __name__ == "__main__":
    main()
