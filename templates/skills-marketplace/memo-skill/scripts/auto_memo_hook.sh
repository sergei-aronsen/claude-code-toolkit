#!/usr/bin/env bash
# auto_memo_hook.sh — SessionEnd hook (two-stage pipeline).
#
# Stage 1 (inline, fast): Save raw daily log. No API calls.
#   → Captures last 30 messages as markdown in daily-logs/
#   → Runs in <1s, safe within SessionEnd timeout
#
# Stage 2 (detached, background): Classify and create structured memos.
#   → nohup + disown so it survives Claude Code exit
#   → Calls Haiku API to classify transcript
#   → Creates structured memo articles in vault
#
# The compile_logs.py cron job also processes daily logs → articles.
# Stage 2 here is optional extra — catches things immediately.
# If it fails, compile_logs.py will pick them up later.
#
# Usage in settings.json:
#   "SessionEnd": [{
#     "matcher": "*",
#     "hooks": [{
#       "type": "command",
#       "command": "bash ~/.claude/skills/memo-skill/scripts/auto_memo_hook.sh ~/engineering-brain"
#     }]
#   }]

set -euo pipefail

VAULT_PATH="${1:-$HOME/engineering-brain}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Stage 1: Save raw log (fast, inline) ───
# Read stdin, save to temp, pipe to save_raw_log.py
TMPFILE=$(mktemp /tmp/auto_memo_input.XXXXXX.json)
cat > "$TMPFILE"

python3 "$SCRIPT_DIR/save_raw_log.py" --vault "$VAULT_PATH" < "$TMPFILE" 2>/dev/null || true

# ─── Stage 2: Classify (detached, background) ───
# nohup + disown: survives Claude Code exit
nohup python3 "$SCRIPT_DIR/auto_memo.py" --vault "$VAULT_PATH" < "$TMPFILE" \
    >> "${VAULT_PATH}/.memo/auto_memo.log" 2>&1 &
disown

# Clean up temp file after delay
(sleep 120 && rm -f "$TMPFILE") &
disown

exit 0
