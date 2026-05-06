#!/bin/bash
#
# tk-pre-gsd-plan-council.sh
# UserPromptSubmit hook — when user invokes /gsd-plan-phase with high-stakes keywords
# (auth, payment, db migration, breaking change, security), suggest running /council first.
#
# Advisory only: never blocks execution. Prints reminder to stdout (Claude sees as context).
#
# Hook contract:
#   - stdin: JSON with { "prompt": "...", "session_id": "...", ... }
#   - stdout: text injected as additional context for Claude
#   - exit 0: continue; exit 2: block submission with feedback (we never block)
#
# Toolkit-owned hook. Marked via _tk_owned in settings.json.

set -euo pipefail

# Read JSON payload from Claude Code
HOOK_INPUT=$(cat)

# Honor opt-out via env var
if [ "${TK_HOOKS_DISABLE:-0}" = "1" ]; then
    exit 0
fi

# Require jq for safe JSON parsing. If missing, fail open silently.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# Extract prompt; fall back to empty string on missing field
PROMPT=$(printf '%s' "$HOOK_INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")

# Only act on /gsd-plan-phase invocations
case "$PROMPT" in
    */gsd-plan-phase*) ;;
    *) exit 0 ;;
esac

# Lowercase for keyword scan (POSIX tr — works on BSD and GNU)
LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# High-stakes keyword set: auth, payments, breaking change, security, db migration
TRIGGERED=""
for KW in \
    auth authentication authorization login password session token \
    payment billing subscription refund stripe paypal \
    "breaking change" "public api" \
    security encryption hash secret \
    "db migration" "schema change" "alter table" "drop table" \
    оплата биллинг подписк аутентифик авториз
do
    case "$LOWER" in
        *"$KW"*)
            TRIGGERED="$KW"
            break
            ;;
    esac
done

if [ -z "$TRIGGERED" ]; then
    exit 0
fi

# Print advisory to stdout — Claude sees as additional context
cat <<EOF
🛡️  TK advisory: this /gsd-plan-phase touches high-stakes area ("$TRIGGERED").
    Consider running /council on the plan before /gsd-execute-phase.
    Why: multi-AI review catches plan errors humans + single-LLM miss.
    Disable advisories: export TK_HOOKS_DISABLE=1
EOF

exit 0
