#!/bin/bash
#
# tk-pre-ship-reality-check.sh
# PreToolUse Bash hook — when Claude is about to push to main / a release branch
# or run a deploy command, remind to run reality-check skill (Playwright e2e + Sentry).
#
# Advisory only — never blocks. Prints reminder to stderr (user sees in transcript).
# To enable enforcement, set TK_HOOKS_BLOCK_SHIP=1 — exit 2 with feedback so Claude
# pauses and surfaces the warning before retrying.
#
# Hook contract:
#   - stdin: JSON with { "tool_name": "Bash", "tool_input": {"command": "..."} }
#   - exit 0: allow tool. exit 2: block tool with feedback to Claude.
#
# Toolkit-owned hook. Coexists with TK's existing PreToolUse Bash hook chain
# (see scripts/lib/install.sh::merge_settings_python — _tk_owned marker).

set -euo pipefail

HOOK_INPUT=$(cat)

if [ "${TK_HOOKS_DISABLE:-0}" = "1" ]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

TOOL=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [ "$TOOL" != "Bash" ]; then
    exit 0
fi

CMD=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
if [ -z "$CMD" ]; then
    exit 0
fi

# Detect ship-class operations: git push to main/master/release, vercel/netlify deploy,
# fly deploy, kubectl apply -f production, /gsd-ship invocations.
TRIGGERED=""
case "$CMD" in
    *"git push"*"origin main"*|*"git push"*"origin master"*|*"git push"*"origin release"*)
        TRIGGERED="git push to main/master/release"
        ;;
    *"git push --force"*|*"git push -f"*)
        TRIGGERED="forced git push"
        ;;
    *"vercel --prod"*|*"vercel deploy --prod"*)
        TRIGGERED="vercel production deploy"
        ;;
    *"netlify deploy --prod"*)
        TRIGGERED="netlify production deploy"
        ;;
    *"fly deploy"*|*"flyctl deploy"*)
        TRIGGERED="fly.io deploy"
        ;;
    *"kubectl apply"*"production"*|*"kubectl apply"*"prod"*)
        TRIGGERED="kubectl production apply"
        ;;
    */gsd-ship*)
        TRIGGERED="/gsd-ship"
        ;;
esac

if [ -z "$TRIGGERED" ]; then
    exit 0
fi

# Block-mode: emit JSON with permissionDecision=deny so Claude pauses.
if [ "${TK_HOOKS_BLOCK_SHIP:-0}" = "1" ]; then
    cat <<EOF
{
  "permissionDecision": "deny",
  "permissionDecisionReason": "TK reality-check: ship operation '$TRIGGERED' detected. Run reality-check skill first (Playwright e2e against prod URL + Sentry baseline). Set TK_HOOKS_BLOCK_SHIP=0 to disable this gate."
}
EOF
    exit 0
fi

# Resolve skill path: TK installs reality-check skill into the *project's*
# .claude/skills/, not ~/.claude/skills/. Claude Code exposes the active project
# directory via CLAUDE_PROJECT_DIR — fall back to $PWD when running outside CC.
SKILL_REF=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.claude/skills/reality-check/SKILL.md" ]; then
    SKILL_REF="$CLAUDE_PROJECT_DIR/.claude/skills/reality-check/SKILL.md"
elif [ -f "$PWD/.claude/skills/reality-check/SKILL.md" ]; then
    SKILL_REF="$PWD/.claude/skills/reality-check/SKILL.md"
else
    SKILL_REF="<project>/.claude/skills/reality-check/SKILL.md (run init-claude.sh if missing)"
fi

# Advisory mode (default): print to stderr, allow command.
cat >&2 <<EOF
🚀 TK advisory: ship operation detected ($TRIGGERED).
    Before/after this push, run reality-check skill:
      1. Playwright e2e against PROD URL (not staging)
      2. Sentry error baseline (last 1h vs last 24h)
      3. Posthog conversion funnel (post-ship 6h window)
    See $SKILL_REF
    Enforce-mode: export TK_HOOKS_BLOCK_SHIP=1
    Disable advisories: export TK_HOOKS_DISABLE=1
EOF

exit 0
