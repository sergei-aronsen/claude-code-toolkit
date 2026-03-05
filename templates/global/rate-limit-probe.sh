#!/bin/bash

# Claude Code Rate Limit Probe
# Probes Anthropic API for rate limit headers using OAuth token from macOS Keychain.
# Writes results to /tmp/claude-rate-limits.json
# Uses claude-haiku-4-5 (cheapest model) with max_tokens=1 to minimize usage impact.

CACHE_FILE="${TMPDIR:-/tmp}/claude-rate-limits.json"
LOCK_DIR="${TMPDIR:-/tmp}/claude-rate-limit-probe.lock"

# Prevent concurrent runs (mkdir is atomic)
if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rm -rf "$LOCK_DIR"' EXIT
else
    # Lock exists — check if stale (>30s)
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -lt 30 ]; then
        exit 0
    fi
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
    trap 'rm -rf "$LOCK_DIR"' EXIT
fi

# Skip if cache is fresh (less than 60 seconds old)
if [ -f "$CACHE_FILE" ]; then
    # Note: stat -f %m is macOS-only; this script is designed for macOS
    CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$CACHE_AGE" -lt 60 ]; then
        exit 0
    fi
fi

# Get OAuth token from macOS Keychain
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo '{"error":"no_token","ts":0}' > "$CACHE_FILE"
    exit 1
fi

# Probe API with minimal request (retry up to 2 times on 529/overloaded)
RESPONSE=""
for attempt in 1 2; do
    RESPONSE=$(curl -s -D - -o /dev/null \
        --max-time 15 \
        "https://api.anthropic.com/v1/messages" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-beta: interleaved-thinking-2025-05-14,oauth-2025-04-20" \
        -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"h"}]}' \
        2>/dev/null)

    # Break if we got rate limit headers
    if echo "$RESPONSE" | grep -qi "anthropic-ratelimit-unified-5h-utilization"; then
        break
    fi
    [ "$attempt" -lt 2 ] && sleep 5
done

# Parse rate limit headers
S_UTIL=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-5h-utilization" | tr -d '\r' | awk -F': ' '{print $2}')
S_RESET=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-5h-reset" | tr -d '\r' | awk -F': ' '{print $2}')
S_STATUS=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-5h-status" | tr -d '\r' | awk -F': ' '{print $2}')

W_UTIL=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-7d-utilization" | tr -d '\r' | awk -F': ' '{print $2}')
W_RESET=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-7d-reset" | tr -d '\r' | awk -F': ' '{print $2}')
W_STATUS=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-7d-status" | tr -d '\r' | awk -F': ' '{print $2}')

OVERALL_STATUS=$(echo "$RESPONSE" | grep -i "anthropic-ratelimit-unified-status:" | tr -d '\r' | awk -F': ' '{print $2}')

NOW=$(date +%s)

if [ -n "$S_UTIL" ]; then
    jq -n \
        --arg s_util "$S_UTIL" \
        --arg s_reset "$S_RESET" \
        --arg s_status "$S_STATUS" \
        --arg w_util "$W_UTIL" \
        --arg w_reset "$W_RESET" \
        --arg w_status "$W_STATUS" \
        --arg overall "$OVERALL_STATUS" \
        --arg ts "$NOW" \
        '{
            session_pct: (($s_util | tonumber) * 100 | round),
            session_reset_epoch: ($s_reset | tonumber),
            session_status: $s_status,
            weekly_pct: (($w_util | tonumber) * 100 | round),
            weekly_reset_epoch: ($w_reset | tonumber),
            weekly_status: $w_status,
            overall_status: $overall,
            ts: ($ts | tonumber)
        }' > "$CACHE_FILE"
else
    # Don't overwrite valid cache with error — only write error if no prior data
    if [ ! -f "$CACHE_FILE" ] || jq -e '.error' "$CACHE_FILE" >/dev/null 2>&1; then
        echo "{\"error\":\"no_headers\",\"ts\":$NOW}" > "$CACHE_FILE"
    fi
    # Touch cache to prevent immediate re-probe
    touch "$CACHE_FILE"
fi
