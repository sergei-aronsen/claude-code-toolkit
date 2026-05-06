#!/bin/bash
#
# tk-cost-warning.sh
# Stop hook — emits an advisory once per session when transcript size suggests
# the session has consumed >TK_COST_WARN_KTOK tokens (default 200k).
#
# Token estimate: transcript_path file size / 4 (rough chars→token ratio).
# Not exact, just enough to nudge non-programmer profile away from running
# /gsd-plan-phase repeatedly when /gsd-quick or /gsd-fast would suffice.
#
# Advisory only — never blocks. Prints to stderr.
#
# Hook contract:
#   - stdin: JSON with { "transcript_path": "...", "session_id": "...", "stop_hook_active": bool }
#   - exit 0 always.
#
# Toolkit-owned hook. Marked via _tk_owned in settings.json.

set -euo pipefail

HOOK_INPUT=$(cat)

if [ "${TK_HOOKS_DISABLE:-0}" = "1" ]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

STOP_ACTIVE=$(printf '%s' "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$STOP_ACTIVE" = "true" ]; then
    exit 0
fi

TRANSCRIPT=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    exit 0
fi

# Threshold in thousands of tokens (k tokens). Default 200k.
THRESHOLD_KTOK="${TK_COST_WARN_KTOK:-200}"
case "$THRESHOLD_KTOK" in
    ''|*[!0-9]*)
        # Invalid input → fall back to default
        THRESHOLD_KTOK=200
        ;;
esac

# stat -c (GNU) vs stat -f (BSD/macOS). Try both.
if BYTES=$(stat -f%z "$TRANSCRIPT" 2>/dev/null); then
    :
elif BYTES=$(stat -c%s "$TRANSCRIPT" 2>/dev/null); then
    :
else
    exit 0
fi

# Sanity check: stat output should be numeric
case "$BYTES" in
    ''|*[!0-9]*) exit 0 ;;
esac

# 1 token ≈ 4 chars (English). Threshold in bytes = ktok * 1000 * 4.
THRESHOLD_BYTES=$((THRESHOLD_KTOK * 4000))

if [ "$BYTES" -lt "$THRESHOLD_BYTES" ]; then
    exit 0
fi

# Avoid duplicate warnings within a session
STAMP_DIR="${HOME}/.claude/scratchpad"
mkdir -p "$STAMP_DIR" 2>/dev/null || true
SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9-' | head -c 64)
STAMP_FILE="${STAMP_DIR}/.tk-cost-stamp-${SAFE_SID}"

if [ -f "$STAMP_FILE" ]; then
    exit 0
fi
: > "$STAMP_FILE" 2>/dev/null || true

EST_KTOK=$((BYTES / 4000))

cat >&2 <<EOF
💰 TK advisory: session has consumed ~${EST_KTOK}k tokens (threshold: ${THRESHOLD_KTOK}k).
    Recommendations:
      - /compact to free context
      - For new tasks, prefer /gsd-quick or /gsd-fast over /gsd-plan-phase
      - Or open a fresh session
    Cost-routing guide: ~/.claude/skills/cost-routing-discipline/SKILL.md
    Tune threshold: export TK_COST_WARN_KTOK=300
    Disable advisories: export TK_HOOKS_DISABLE=1
EOF

exit 0
