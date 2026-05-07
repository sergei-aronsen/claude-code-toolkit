#!/bin/bash
# product-gate.sh — UserPromptSubmit hook for product-thinking skill
#
# Scans user prompt for product-related keywords. If detected, injects a
# context reminder suggesting product validation BEFORE technical work.
#
# This is SOFT enforcement — the hook suggests, it does not block. To make
# it a hard block, route through PreToolUse instead.
#
# Contract:
#   - Reads JSON from stdin
#   - Writes optional context to stdout (Claude appends to system context)
#   - Always exits 0 (must not break the prompt pipeline)
#
# Configuration:
#   Disable by setting CLAUDE_PRODUCT_GATE=0 in environment or settings.json env.

set +e

# Allow user to disable
[ "${CLAUDE_PRODUCT_GATE:-1}" = "0" ] && exit 0

# Need jq
command -v jq >/dev/null 2>&1 || exit 0

# Read prompt from stdin JSON
PROMPT=$(jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Lowercase for matching
PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Trigger keywords
TRIGGERS='build|ship|let.s add|new feature|mvp|launch|pivot|pricing|billing|monetiz|subscript|paywall'

# Anti-trigger keywords (skip if these appear — likely a fix/refactor not a feature)
ANTI_TRIGGERS='bug|fix|refactor|typo|lint|format|update.dep|patch|hotfix|test.coverage|docs only'

# Skip if anti-trigger present
echo "$PROMPT_LC" | grep -qE "$ANTI_TRIGGERS" && exit 0

# Check trigger
if echo "$PROMPT_LC" | grep -qE "$TRIGGERS"; then
  # Derive a feature slug from first 6 words of prompt
  SLUG=$(printf '%s' "$PROMPT" | head -c 200 | tr '[:upper:]' '[:lower:]' | \
    tr -cs 'a-z0-9' '-' | sed 's/^-*//' | cut -d'-' -f1-6 | sed 's/-*$//')

  # Check if validation file already exists
  if [ -n "$SLUG" ] && [ -f ".planning/product/${SLUG}.md" ]; then
    cat <<EOF
[product-gate] Existing product validation detected: .planning/product/${SLUG}.md
Read this file BEFORE proceeding. Do not re-interview.
EOF
  else
    cat <<EOF
[product-gate] Product-related prompt detected. Recommended workflow:

1. Run product-thinking skill FIRST (validates target user, metric, channel, economics)
2. Skill writes .planning/product/<slug>.md with status (validated/needs-experiment/rejected/risk-accepted)
3. THEN proceed to /gsd-discuss-phase or /plan

If this is a bug fix, refactor, or non-feature work, add "(no-product-gate)" to your prompt to skip this reminder.

To disable globally: export CLAUDE_PRODUCT_GATE=0
EOF
  fi
fi

exit 0
