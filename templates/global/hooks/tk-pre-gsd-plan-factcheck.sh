#!/bin/bash
#
# tk-pre-gsd-plan-factcheck.sh
# UserPromptSubmit hook — when user invokes /gsd-discuss-phase or /gsd-plan-phase
# with external-dependency claims (versions, deprecations, "use library X",
# "upgrade to Y", "latest version of Z"), suggest running /factcheck or
# /research first so the plan is grounded in current web facts.
#
# Pairs with PR-2 (Council grounding): once the plan carries [VERIFIED] /
# [DISPUTED] / [UNVERIFIABLE] markers, brain.py picks them up automatically.
#
# Advisory only: never blocks execution. Prints reminder to stdout (Claude
# treats it as additional context).
#
# Hook contract:
#   - stdin: JSON with { "prompt": "...", "session_id": "...", ... }
#   - stdout: text injected as additional context for Claude
#   - exit 0: continue; exit 2: block submission (we never block)
#
# Toolkit-owned hook. Marked via _tk_owned + _tk_hook_id in settings.json.

set -euo pipefail

# Read JSON payload from Claude Code
HOOK_INPUT=$(cat)

# Honor the global TK hooks opt-out (matches sibling hooks)
if [ "${TK_HOOKS_DISABLE:-0}" = "1" ]; then
    exit 0
fi

# Per-hook opt-out (lets users keep council advisory but silence factcheck)
if [ "${TK_FACTCHECK_GATE:-1}" = "0" ]; then
    exit 0
fi

# Require jq for safe JSON parsing. If missing, fail open silently.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# Extract prompt; fall back to empty string on missing field
PROMPT=$(printf '%s' "$HOOK_INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")

# Only act on GSD planning entry points where external claims still cost
# nothing to verify. /gsd-execute-phase is too late — plan is already locked.
case "$PROMPT" in
    */gsd-discuss-phase*|*/gsd-plan-phase*|*/gsd-plan-review-convergence*) ;;
    *) exit 0 ;;
esac

# User opt-out per invocation — sibling pattern with /product-gate
case "$PROMPT" in
    *"(no-factcheck-gate)"*) exit 0 ;;
esac

# Lowercase for keyword scan (POSIX tr — works on BSD and GNU)
LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# External-dependency keyword set. Two buckets:
#   1. Verbs that imply choosing/upgrading a third-party thing
#   2. Common version-y nouns that drift fastest in real codebases
TRIGGERED=""
for KW in \
    "upgrade to" "migrate to" "switch to" "move to" \
    "latest version" "newest version" "new version" "current version" \
    "deprecated" "removed in" "breaking change" "no longer supported" \
    "use library" "use package" "use sdk" \
    "stripe sdk" "openai sdk" "anthropic sdk" \
    "next.js" "next js" "nuxt" "remix" "astro" \
    "react " "vue " "svelte" "angular " \
    "django" "rails" "laravel" "spring boot" "fastapi" \
    "node " "node.js" "deno" "bun " "python 3" \
    "обнови до" "обновить до" "перейти на" "перейдите на" "новая версия" "последняя версия" \
    "устарел" "устарела" "устарело" "устарели" "больше не поддерж"
do
    case "$LOWER" in
        *"$KW"*)
            TRIGGERED="$KW"
            break
            ;;
    esac
done

# Also trigger on any explicit semver-ish version reference: "v1.2", "2.10.1",
# "3.x", "v14". Cheap regex via grep -E so we stay POSIX. Liberal on purpose —
# false positives are advisory, the user can append "(no-factcheck-gate)".
if [ -z "$TRIGGERED" ]; then
    if printf '%s' "$LOWER" | grep -qE '(^|[^a-z0-9])v?[0-9]+\.[0-9x]+([.x][0-9]+)?'; then
        TRIGGERED="version reference"
    fi
fi

if [ -z "$TRIGGERED" ]; then
    exit 0
fi

# Print advisory to stdout — Claude sees as additional context
cat <<EOF
🔎 TK advisory: this GSD planning prompt mentions an external dependency
    ("$TRIGGERED"). Before locking the plan, consider:

      • /factcheck "<claim>"   — VERIFIED / DISPUTED / UNVERIFIABLE verdict
      • /research "<topic>"    — deeper sweep when claims compound
      • /lookup "<term>"       — quick lookup for a single fact

    Pasting the verdicts back into the plan lets /council pick up the
    [VERIFIED]/[DISPUTED]/[UNVERIFIABLE] markers and ground its review.

    Skip this advisory once: add "(no-factcheck-gate)" to your prompt.
    Disable per-hook:        export TK_FACTCHECK_GATE=0
    Disable all TK hooks:    export TK_HOOKS_DISABLE=1
EOF

exit 0
