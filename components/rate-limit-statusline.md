# Rate Limit Statusline

> Monitor your Claude API session and weekly usage limits directly in the Claude Code status bar.

---

## What It Does

Displays real-time rate limit usage in the Claude Code status bar:

```text
25% | 5h:23% (2h57m) | 7d:80% (1d18h)
 │      │      │          │       │
 │      │      │          │       └─ time until weekly reset
 │      │      │          └─ weekly usage (7-day window)
 │      │      └─ time until session reset
 │      └─ session usage (5-hour window)
 └─ context window usage
```

## Color Coding

| Usage     | Color        | ANSI Code |
|-----------|--------------|-----------|
| 0-59%     | No color     | Default   |
| 60-79%    | Mustard      | 136       |
| 80-89%    | Dark red     | 1         |
| 90-100%   | Bright red   | 197       |

## How It Works

Two scripts work together:

### rate-limit-probe.sh (background)

1. Reads OAuth token from macOS Keychain (`Claude Code-credentials`)
2. Sends minimal API request to `claude-haiku-4-5` (1 token, cheapest model)
3. Retries up to 2 times with 5s pause on 529/overloaded responses
4. Parses undocumented `anthropic-ratelimit-unified-*` response headers
5. Caches results in `/tmp/claude-rate-limits.json`
6. Preserves valid cache on transient errors (does not overwrite good data)
7. Skips if cache is fresh (less than 60 seconds old)
8. Uses lock file to prevent concurrent runs

### statusline.sh (display)

1. Receives Claude Code session data via stdin (JSON)
2. Reads cached rate limit data from `/tmp/claude-rate-limits.json`
3. Triggers background probe if cache is stale
4. Formats output with color coding and time-until-reset
5. Returns single line for the status bar

## Prerequisites

- **macOS** (token stored in Keychain; Linux not yet supported)
- **jq** (`brew install jq`)
- **Claude Code** with OAuth authentication (Max or Pro subscription)
- **curl** (pre-installed on macOS)

## Installation

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/install-statusline.sh)
```

The installer:

1. Checks all prerequisites
2. Downloads `statusline.sh` and `rate-limit-probe.sh` to `~/.claude/`
3. Configures `statusLine` in `~/.claude/settings.json`
4. Runs initial probe to verify everything works

## Security

- OAuth token is read **locally** from macOS Keychain
- API calls go **directly** to `https://api.anthropic.com` (no proxies or third-party servers)
- No tokens, credentials, or usage data are sent anywhere except Anthropic
- Cache file (`/tmp/claude-rate-limits.json`) contains only percentage values and timestamps

## API Headers Used

These headers are returned by Anthropic API when using OAuth with beta flag:

| Header                                        | Description                    |
|-----------------------------------------------|--------------------------------|
| `anthropic-ratelimit-unified-5h-utilization`  | Session usage (0.0 to 1.0+)   |
| `anthropic-ratelimit-unified-5h-reset`        | Session reset (epoch seconds)  |
| `anthropic-ratelimit-unified-5h-status`       | Session status (active/warning)|
| `anthropic-ratelimit-unified-7d-utilization`  | Weekly usage (0.0 to 1.0+)    |
| `anthropic-ratelimit-unified-7d-reset`        | Weekly reset (epoch seconds)   |
| `anthropic-ratelimit-unified-7d-status`       | Weekly status (active/warning) |
| `anthropic-ratelimit-unified-status`          | Overall status                 |

## Customization

### Change Colors

Edit `~/.claude/statusline.sh`, find the `colorize()` function:

```bash
colorize() {
    local pct=$1
    local text=$2
    if [ "$pct" -ge 90 ]; then
        echo "\033[38;5;197m${text}\033[0m"  # bright red
    elif [ "$pct" -ge 80 ]; then
        echo "\033[38;5;1m${text}\033[0m"    # dark red
    elif [ "$pct" -ge 60 ]; then
        echo "\033[38;5;136m${text}\033[0m"  # mustard
    else
        echo "$text"                          # no color
    fi
}
```

To see all 256 available colors:

```bash
for i in $(seq 0 255); do printf "\033[38;5;${i}m%3d 7d:80%%\033[0m\n" $i; done
```

### Change Thresholds

Edit the same `colorize()` function. Change `90`, `80`, `60` to your preferred thresholds.

### Change Probe Interval

Edit `~/.claude/rate-limit-probe.sh`, change `60` in the cache age check:

```bash
if [ "$CACHE_AGE" -lt 60 ]; then  # seconds
```

And in `~/.claude/statusline.sh`:

```bash
if [ ... ] || [ $(( ... )) -gt 60 ]; then  # seconds
```

### Add Model Name

Edit `~/.claude/statusline.sh`, add model to the output:

```bash
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"' 2>/dev/null)
OUT="${MODEL} | ${OUT}"
```

## Uninstall

```bash
rm ~/.claude/statusline.sh ~/.claude/rate-limit-probe.sh /tmp/claude-rate-limits.json
```

Remove the `statusLine` key from `~/.claude/settings.json`.

## Troubleshooting

### Status bar shows "limits: loading..."

The probe has not completed yet. Wait a few seconds. If it persists:

```bash
bash ~/.claude/rate-limit-probe.sh
cat /tmp/claude-rate-limits.json
```

### Error: no_token

Claude Code OAuth token not found. Make sure you are logged in:

```bash
claude
```

### Error: no_headers

API responded but without rate limit headers. This can happen if:

- The API returned 529 (overloaded) — the probe retries automatically, wait a minute
- The OAuth token has expired (restart Claude Code to refresh)
- The `anthropic-beta` header is outdated (currently requires `interleaved-thinking-2025-05-14,oauth-2025-04-20`)
- Network issues

To force a fresh probe:

```bash
rm -f /tmp/claude-rate-limits.json /tmp/claude-rate-limit-probe.lock
bash ~/.claude/rate-limit-probe.sh
cat /tmp/claude-rate-limits.json
```

### Cache not updating

Check if the lock file is stuck:

```bash
rm -f /tmp/claude-rate-limit-probe.lock
bash ~/.claude/rate-limit-probe.sh
```
