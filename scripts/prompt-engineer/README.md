# Prompt Engineer — Technical Reference

Single-file Codex-CLI-backed prompt optimizer. Companion to the Supreme
Council: where the Council validates a plan via Skeptic + Pragmatist
review, the Prompt Engineer rewrites a single prompt file into a
deployment-ready version.

## Files

| File | Purpose |
|------|---------|
| `optimize_prompt.py` | One-shot optimizer (default) or 3-stage pipeline (`--multi-pass`) |
| `README.md` | This file |

## How it works

Default mode (single pass): one call to `codex exec` runs the
PROMETHEUS optimizer prompt, which performs both first-pass
optimization **and** a built-in meta-optimization pass internally.
Output is parsed for the first fenced code block and written to
`01-optimized-prompt.txt`.

`--multi-pass` mode keeps the legacy 3-stage pipeline (optimize →
external meta → synthesis) for cases where the single-pass result is
under-cooked — typically very short or ambiguous source prompts.

All run artifacts land under `output/<YYYYMMDD-HHMMSS>/`:

- `00-original.txt` — input prompt verbatim
- `00-context.txt` — optional context file
- `01-optimized.md` — full Codex response (single-pass mode)
- `01-optimized-prompt.txt` — extracted final prompt
- `01-optimized.log` — `codex exec` invocation log
- `02-*` / `03-*` — additional artifacts in `--multi-pass` mode

## Requirements

- Python 3.8+ (standard library only, no pip deps)
- `codex` CLI on `PATH` (`npm install -g @openai/codex`)
- An OpenAI account for Codex (free or paid tier)

The script exits with code 2 if `codex` is missing.

## Usage

```bash
# Default single-pass
python3 ~/.claude/prompt-engineer/optimize_prompt.py path/to/prompt.md

# Or via shell alias installed by setup-prompt-engineer.sh
pe path/to/prompt.md

# Stdin input
echo "Write me a tone-control prompt" | pe -

# With a context file
pe path/to/prompt.md --context path/to/context.md

# Legacy 3-stage mode (best-of synthesis)
pe path/to/prompt.md --multi-pass

# Override the Codex model
pe path/to/prompt.md --model gpt-5.2
```

The `pe` alias is installed by `scripts/setup-prompt-engineer.sh` and
also by `scripts/init-claude.sh` when the toolkit is set up via
`curl | bash`.

## Bug fixes vs upstream

Vendored from <https://github.com/sergei-aronsen/prompt-optimizer> with
two local fixes:

- **600 s timeout** on the `codex exec` subprocess. The upstream call
  used the default `subprocess.run` behaviour (no timeout), so a hung
  Codex session would block the script forever. The fix raises a
  `RuntimeError` and writes a `--- TIMEOUT after Ns ---` marker to the
  per-stage log file.
- **`try/finally` around `tempfile.NamedTemporaryFile`** so the
  temporary `.md` file used to capture Codex output is cleaned up even
  when the subprocess raises before the explicit `unlink`. Previously,
  any exception between `mktemp` and `unlink` leaked a file into
  `/tmp`.

Both fixes are local to `run_codex()`. The rest of the script is
unchanged; future upstream releases can be picked up with a routine
diff-and-merge.

## When to use this vs the Council

| Symptom | Tool |
|---------|------|
| You want a yes / no / simplify verdict on an implementation plan | `/council` |
| You want a rewritten prompt that survives production model usage | `/prompt-engineer` |
| You wrote a long Claude system prompt and want it tightened | `/prompt-engineer` |
| You're staging a feature decision with security / performance / UX overlay | `/council` |

The two tools are independent — they share no state.
