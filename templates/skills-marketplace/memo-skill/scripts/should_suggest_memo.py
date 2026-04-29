#!/usr/bin/env python3
"""
should_suggest_memo.py — Lightweight heuristic for Stop hook.

Reads the last few messages from the transcript and checks if they
contain patterns that suggest a memo-worthy moment. If yes, injects
a system message nudging Claude to suggest /memo.

No API calls. No cost. Runs in <100ms.
"""

import json
import os
import sys

# Patterns that suggest memo-worthy content
DECISION_SIGNALS = [
    "let's go with", "decided to use", "выбрали", "решили использовать",
    "tradeoff", "trade-off", "compromise", "instead of", "вместо",
    "better approach", "лучший подход", "the reason we",
    "chose", "picked", "switched to", "migrated to",
    "pros and cons", "плюсы и минусы",
]

DEBUG_SIGNALS = [
    "finally fixed", "the issue was", "root cause", "проблема была в",
    "turns out", "оказалось", "the bug was", "workaround",
    "after debugging", "took a while", "tricky", "нашли баг",
    "solution:", "fix:", "resolved by",
]

PATTERN_SIGNALS = [
    "pattern", "reusable", "паттерн", "можно переиспользовать",
    "boilerplate", "template", "шаблон", "helper",
    "utility", "abstraction", "wrapper",
]

TOOL_SIGNALS = [
    "discovered", "found this tool", "нашёл инструмент",
    "TIL", "til:", "useful command", "полезная команда",
    "config trick", "трюк с конфигом",
]

ALL_SIGNALS = DECISION_SIGNALS + DEBUG_SIGNALS + PATTERN_SIGNALS + TOOL_SIGNALS
MIN_MESSAGES_FOR_SUGGESTION = 6  # Don't suggest on short sessions


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    # Don't interfere if stop_hook_active (prevents loops)
    if hook_input.get("stop_hook_active"):
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    # Read last N lines of transcript (don't read entire file)
    messages = []
    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Only look at last 20 lines
        for line in lines[-20:]:
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
                    if role in ("user", "assistant") and content:
                        messages.append(content.lower())
            except json.JSONDecodeError:
                continue
    except Exception:
        sys.exit(0)

    if len(messages) < MIN_MESSAGES_FOR_SUGGESTION:
        sys.exit(0)

    # Check last 5 messages for signals
    recent_text = " ".join(messages[-5:])
    matches = [s for s in ALL_SIGNALS if s.lower() in recent_text]

    if len(matches) >= 2:
        # Strong signal — suggest memo
        output = {
            "systemMessage": (
                "This conversation contains knowledge worth saving. "
                "Consider suggesting the user run /memo to capture "
                "the key decision, pattern, or solution for future reference. "
                "Keep the suggestion brief and natural — one line at the end of your response."
            )
        }
        print(json.dumps(output))
        sys.exit(0)

    # No strong signal
    sys.exit(0)


if __name__ == "__main__":
    main()
