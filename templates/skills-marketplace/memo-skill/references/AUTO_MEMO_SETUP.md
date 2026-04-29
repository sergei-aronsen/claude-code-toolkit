# Auto-Memo Hook — Installation Guide

## How it works

```
Claude Code session ends (exit, Ctrl+D, Ctrl+C, close terminal)
  → SessionEnd hook fires
  → auto_memo_hook.sh reads stdin, saves to temp file
  → launches auto_memo.py as DETACHED process (nohup + disown)
  → hook exits immediately (0) → Claude Code exits cleanly
  → auto_memo.py continues running independently:
    → reads transcript → sends to Haiku (~$0.002) → saves to vault
```

### Why the wrapper script?

SessionEnd hooks have a 1.5-second default timeout, and Claude Code
may kill child processes before they finish. API calls to Haiku take
3-10 seconds. The solution: `auto_memo_hook.sh` detaches `auto_memo.py`
from the Claude Code process tree entirely. It runs as an independent
background process that survives Claude Code exit.

## Installation

### Step 1: Ensure ANTHROPIC_API_KEY is set

```bash
# Add to ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Step 2: Add the hook to Claude Code settings

Open `/hooks` in Claude Code, or edit `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/skills/memo-skill/scripts/auto_memo_hook.sh ~/engineering-brain"
          }
        ]
      }
    ]
  }
}
```

No need for `"timeout"` or `"async"` — the hook exits instantly
and the real work runs detached.

### Step 3: (Optional) Add the Stop hook for mid-session nudges

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/skills/memo-skill/scripts/auto_memo_hook.sh ~/engineering-brain"
        }]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "python3 ~/.claude/skills/memo-skill/scripts/should_suggest_memo.py",
          "timeout": 5
        }]
      }
    ]
  }
}
```

### Step 4: Verify

After your next Claude Code session, check the log:

```bash
cat ~/engineering-brain/.memo/auto_memo.log
```

## When does SessionEnd fire?

| What you do | SessionEnd fires? | reason field |
|---|---|---|
| Type `/exit` or `exit` | Yes | `prompt_input_exit` |
| Press Ctrl+D | Yes | `prompt_input_exit` |
| Press Ctrl+C | Yes | `other` |
| Close the terminal window | Yes | `other` |
| Terminal crashes | Depends | May not fire |
| Machine loses power | No | — |

In the rare case where SessionEnd doesn't fire, the transcript file
still exists on disk. Recover manually:

```bash
echo '{"transcript_path": "<path>", "session_id": "manual"}' \
  | python3 ~/.claude/skills/memo-skill/scripts/auto_memo.py --vault ~/engineering-brain
```

## Cost

~$0.001-0.005 per session (Claude Haiku).
5 sessions/day = $0.50-1.50/month.
