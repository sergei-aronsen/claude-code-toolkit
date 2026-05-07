#!/bin/bash
# templates/base/hooks/format-file.sh
#
# PostToolUse hook for Edit|Write|MultiEdit. Routes the modified file to the
# appropriate per-stack formatter+linter. Silent on missing tools, never blocks
# the Claude Code flow.
#
# Wiring (settings.json):
#
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "matcher": "Edit|Write|MultiEdit",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "command -v jq >/dev/null 2>&1 || exit 0; f=$(jq -r '.tool_input.file_path // empty'); [ -n \"$f\" ] && [ -x .claude/hooks/format-file.sh ] && .claude/hooks/format-file.sh \"$f\""
#             }
#           ]
#         }
#       ]
#     }
#   }
#
# Why a separate dispatcher script vs inline in settings.json: monorepos with
# mixed languages need per-extension routing, the matrix grows, and inlining
# 80 lines of bash into JSON is unmaintainable.
#
# Idempotency: every supported formatter is idempotent — running twice
# produces the same result.
#
# IDE conflict avoidance: a per-file lock prevents dual-format storms when
# the user's IDE has format-on-save enabled on the same file.
#
# Disable globally: export CLAUDE_FORMAT_HOOK=0 in shell or settings.json env.
#
# Performance: each call is bounded by the slowest enabled formatter
# (typically eslint at ~500ms-2s). For a 50-edit session that is 25-100s of
# cumulative formatter time. To skip slow linters and run only fast
# formatters, export CLAUDE_FORMAT_FAST=1.

# Never set -e — formatter failures must not break Claude.
set +e

# Allow user to disable
[ "${CLAUDE_FORMAT_HOOK:-1}" = "0" ] && exit 0

FILE="${1:-}"
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Skip files in dependency / vendor / build directories — formatters often
# fail noisily there and the output is not human-edited code anyway.
case "$FILE" in
    */node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.next/*|*/.nuxt/*|*/coverage/*|*/__pycache__/*|*/.venv/*|*/venv/*)
        exit 0 ;;
esac

# Per-file lock — prevents dual-format storm with IDE format-on-save.
# Lock key is the file's path hash so concurrent edits to different files
# can run in parallel.
if command -v shasum >/dev/null 2>&1; then
    LOCK_KEY=$(printf '%s' "$FILE" | shasum 2>/dev/null | cut -d' ' -f1)
elif command -v sha1sum >/dev/null 2>&1; then
    LOCK_KEY=$(printf '%s' "$FILE" | sha1sum 2>/dev/null | cut -d' ' -f1)
else
    LOCK_KEY=$(printf '%s' "$FILE" | tr '/' '_')
fi
LOCK="${TMPDIR:-/tmp}/claude-format-${LOCK_KEY}.lock"

# Skip if a formatter is already running on this file (race avoidance).
[ -f "$LOCK" ] && exit 0
trap 'rm -f "$LOCK"' EXIT
: > "$LOCK"

# Fast mode toggle
FAST="${CLAUDE_FORMAT_FAST:-0}"

case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
        command -v prettier >/dev/null 2>&1 && prettier --write --log-level error "$FILE" >/dev/null 2>&1
        if [ "$FAST" = "0" ]; then
            command -v eslint >/dev/null 2>&1 && eslint --fix "$FILE" >/dev/null 2>&1
        fi
        ;;
    *.json|*.md|*.yml|*.yaml|*.css|*.scss|*.html)
        command -v prettier >/dev/null 2>&1 && prettier --write --log-level error "$FILE" >/dev/null 2>&1
        ;;
    *.php)
        if [ -x "vendor/bin/pint" ]; then
            vendor/bin/pint "$FILE" >/dev/null 2>&1
        elif command -v pint >/dev/null 2>&1; then
            pint "$FILE" >/dev/null 2>&1
        fi
        ;;
    *.rb)
        command -v rubocop >/dev/null 2>&1 && rubocop -a --format=quiet "$FILE" >/dev/null 2>&1
        ;;
    *.py)
        if command -v ruff >/dev/null 2>&1; then
            ruff format --quiet "$FILE" >/dev/null 2>&1
            if [ "$FAST" = "0" ]; then
                ruff check --fix --quiet "$FILE" >/dev/null 2>&1
            fi
        elif command -v black >/dev/null 2>&1; then
            black --quiet "$FILE" >/dev/null 2>&1
        fi
        ;;
    *.go)
        command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" >/dev/null 2>&1
        if [ "$FAST" = "0" ]; then
            command -v goimports >/dev/null 2>&1 && goimports -w "$FILE" >/dev/null 2>&1
        fi
        ;;
    *.rs)
        command -v rustfmt >/dev/null 2>&1 && rustfmt --quiet "$FILE" >/dev/null 2>&1
        ;;
    *.sh|*.bash)
        if command -v shfmt >/dev/null 2>&1; then
            shfmt -w -i 4 -bn "$FILE" >/dev/null 2>&1
        fi
        ;;
    *.sql)
        if command -v sql-formatter >/dev/null 2>&1; then
            sql-formatter --fix "$FILE" >/dev/null 2>&1
        fi
        ;;
esac

exit 0
