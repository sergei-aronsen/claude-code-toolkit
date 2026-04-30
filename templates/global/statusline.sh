#!/bin/bash

# Claude Code Rate Limit Statusline
# Displays session (5h) and weekly (7d) API usage in the status bar.
# Reads cached data from /tmp/claude-rate-limits.json (updated by rate-limit-probe.sh).
#
# Output format: 25% | 5h:23% (2h57m) | 7d:80% (1d18h)
# Colors: none (<60%), mustard (60-79%), dark red (80-89%), bright red (90-100%)

input=$(cat)

# Read cached rate limits
CACHE="${TMPDIR:-/tmp}/claude-rate-limits.json"

# Trigger background probe if cache is stale (>60s) or missing
# Note: stat -f %m is macOS-only; this script is designed for macOS
if [ ! -f "$CACHE" ] || [ $(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) )) -gt 60 ]; then
    bash ~/.claude/rate-limit-probe.sh &>/dev/null &
fi

# Format time remaining from epoch
time_remaining() {
    local reset_epoch=$1
    # Audit M2: bash arithmetic context recursively expands $(...) inside
    # array-index brackets. A poisoned cache (possible on Linux shared /tmp)
    # like {"session_reset_epoch":"x[$(touch /tmp/pwn)]"} would otherwise
    # execute commands as the statusline owner. Force numeric.
    [[ "$reset_epoch" =~ ^[0-9]+$ ]] || reset_epoch=0
    local now
    now=$(date +%s)
    local diff=$(( reset_epoch - now ))
    if [ "$diff" -le 0 ]; then
        echo "now"
    elif [ "$diff" -lt 3600 ]; then
        echo "$(( diff / 60 ))m"
    elif [ "$diff" -lt 86400 ]; then
        local h=$(( diff / 3600 ))
        local m=$(( (diff % 3600) / 60 ))
        echo "${h}h${m}m"
    else
        local d=$(( diff / 86400 ))
        local h=$(( (diff % 86400) / 3600 ))
        echo "${d}d${h}h"
    fi
}

# Color based on percentage
colorize() {
    local pct=$1
    local text=$2
    # Audit M2: same bash-arith RCE guard as time_remaining(). pct may be
    # negative-prefixed by future probe; allow optional minus.
    [[ "$pct" =~ ^-?[0-9]+$ ]] || pct=0
    if [ "$pct" -ge 90 ]; then
        printf '\033[38;5;197m%s\033[0m' "$text"
    elif [ "$pct" -ge 80 ]; then
        printf '\033[38;5;1m%s\033[0m' "$text"
    elif [ "$pct" -ge 60 ]; then
        printf '\033[38;5;136m%s\033[0m' "$text"
    else
        printf '%s' "$text"
    fi
}

# Context window
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)

if [ -f "$CACHE" ]; then
    ERR=$(jq -r '.error // empty' "$CACHE" 2>/dev/null)
    if [ -z "$ERR" ]; then
        S_PCT=$(jq -r '.session_pct' "$CACHE" 2>/dev/null)
        W_PCT=$(jq -r '.weekly_pct' "$CACHE" 2>/dev/null)
        S_RESET=$(jq -r '.session_reset_epoch' "$CACHE" 2>/dev/null)
        W_RESET=$(jq -r '.weekly_reset_epoch' "$CACHE" 2>/dev/null)

        S_TIME=$(time_remaining "$S_RESET")
        W_TIME=$(time_remaining "$W_RESET")

        S_COLORED=$(colorize "$S_PCT" "5h:${S_PCT}%")
        W_COLORED=$(colorize "$W_PCT" "7d:${W_PCT}%")

        # Build output
        OUT=""
        if [ -n "$CTX_PCT" ]; then
            OUT="${CTX_PCT}% | "
        fi
        OUT="${OUT}${S_COLORED} (${S_TIME}) | ${W_COLORED} (${W_TIME})"
        printf '%s\n' "$OUT"
        exit 0
    fi
fi

# Fallback: no rate limit data yet
printf '%s\n' "limits: loading..."
