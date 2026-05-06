#!/bin/bash
#
# tk-post-gsd-phase-audit.sh
# Stop hook — when Claude finishes a /gsd-execute-phase turn, suggest running
# /audit security && /audit code on the freshly-implemented phase.
#
# Detection: scans last assistant turn in transcript for phase-completion markers
# emitted by GSD (e.g., "Phase * complete", "VERIFICATION.md").
#
# Advisory only — never blocks. Prints reminder to stderr (visible to user).
#
# Hook contract:
#   - stdin: JSON with { "transcript_path": "...", "session_id": "...", "stop_hook_active": bool, ... }
#   - exit 0: allow stop. exit 2: prevent stop with feedback. We always exit 0.
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

# stop_hook_active prevents recursion when this hook itself triggered the stop
STOP_ACTIVE=$(printf '%s' "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$STOP_ACTIVE" = "true" ]; then
    exit 0
fi

TRANSCRIPT=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    exit 0
fi

# Read last 200 lines (transcripts are JSONL, one record per line). Bound for speed.
TAIL_BUF=$(tail -n 200 "$TRANSCRIPT" 2>/dev/null || echo "")
if [ -z "$TAIL_BUF" ]; then
    exit 0
fi

# Look for /gsd-execute-phase in recent turns AND completion markers
EXECUTED=0
COMPLETED=0

if printf '%s' "$TAIL_BUF" | grep -q -- '/gsd-execute-phase'; then
    EXECUTED=1
fi

# Phase-completion markers GSD emits
for MARKER in \
    "VERIFICATION.md" \
    "Phase complete" \
    "phase-complete" \
    "Phase status: complete" \
    "All tasks complete"
do
    if printf '%s' "$TAIL_BUF" | grep -q -F "$MARKER"; then
        COMPLETED=1
        break
    fi
done

if [ "$EXECUTED" -ne 1 ] || [ "$COMPLETED" -ne 1 ]; then
    exit 0
fi

# Avoid duplicate reminders within the same session — touch a stamp file.
STAMP_DIR="${HOME}/.claude/scratchpad"
mkdir -p "$STAMP_DIR" 2>/dev/null || true
SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
# Sanitize session id (alphanumerics + dashes only) before path concatenation.
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9-' | head -c 64)
STAMP_FILE="${STAMP_DIR}/.tk-audit-stamp-${SAFE_SID}"

if [ -f "$STAMP_FILE" ]; then
    exit 0
fi
: > "$STAMP_FILE" 2>/dev/null || true

# stderr is shown to user in transcript mode (Ctrl-R)
cat >&2 <<'EOF'
🔍 TK advisory: GSD phase just completed.
    Recommended next steps:
      /audit security   — security pass on phase code
      /audit code       — code-quality pass on phase code
    Skip if phase is doc-only or a refactor with no behavior change.
    Disable advisories: export TK_HOOKS_DISABLE=1
EOF

exit 0
