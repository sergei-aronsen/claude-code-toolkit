# Supreme Council — Technical Reference

Multi-AI code review orchestrator for Claude Code.

## Files

| File | Purpose |
|------|---------|
| `brain.py` | Orchestrator — calls Gemini + ChatGPT |
| `config.json` | API keys and model settings |
| `config.json.template` | Template for new installations |

## Config

```json
{
  "gemini": {
    "mode": "cli",
    "api_key": "",
    "model": "gemini-3-pro-preview"
  },
  "openai": {
    "api_key": "",
    "model": "gpt-5.2"
  }
}
```

### Gemini Modes

- `cli` — uses installed Gemini CLI (`gemini` command). Free with Google subscription.
- `api` — uses REST API with `api_key`. Requires API key from [AI Studio](https://aistudio.google.com/app/apikey).

### Environment Variable Overrides

Environment variables take priority over config file:

```bash
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="..."
```

## Usage

```bash
python3 ~/.claude/council/brain.py "Your implementation plan"
# or with alias:
brain "Your implementation plan"
```

## Output

Report saved to `.claude/scratchpad/council-report.md` in the current project.

## Dependencies

- Python 3.8+
- `curl` (pre-installed on macOS/Linux)
- `tree` (install: `brew install tree`)
- Gemini CLI or Gemini API key
- OpenAI API key
