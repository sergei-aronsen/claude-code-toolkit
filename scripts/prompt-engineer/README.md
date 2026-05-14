# Prompt Engineer — Technical Reference

Single-file multi-provider prompt optimizer (Claude Code, Codex,
Gemini). Companion to the Supreme Council: where the Council validates
a plan via Skeptic + Pragmatist review, the Prompt Engineer rewrites a
single prompt file into a deployment-ready version.

## Files

| File | Purpose |
|------|---------|
| `optimize_prompt.py` | One-shot optimizer (default) or 3-stage pipeline (`--multi-pass`) |
| `README.md` | This file |

## How it works

The optimizer renders a system prompt (`OPTIMIZER_PROMPT`) with
`{{CONTEXT}}` + `{{PROMPT_TO_IMPROVE}}` substituted, pipes the result
into the chosen provider CLI via stdin, then extracts the first
fenced code block (` ```text` or ` ```markdown`) as the final
optimized prompt.

### Provider (`--provider`)

| Value | CLI invoked | Notes |
|---|---|---|
| `claude` | `claude -p` | Default for non-TTY usage. Best instruction following on long system prompts. |
| `codex` | `codex exec --skip-git-repo-check -o tmp -` | Tight, terse rewrites. |
| `gemini` | `gemini -p ""` | Fast. Output sometimes lacks fenced block (full response then used). |
| `all` | claude + codex + gemini in parallel → synthesis via 1 extra call | 4 total calls. Synthesizer preference: claude > codex > gemini. |
| `ask` | Interactive menu on TTY; falls back to `claude` when stdin is not a TTY | Default. |

Default mode (single pass): one call to the chosen provider runs the
optimizer prompt, which performs first-pass optimization **and** a
built-in meta-optimization pass internally.

`--multi-pass` mode keeps the legacy 3-stage pipeline (optimize →
external meta → synthesis) for cases where the single-pass result is
under-cooked — typically very short or ambiguous source prompts.
Single-provider only; rejected with `--provider all`.

### `--provider all` flow

```text
       rendered OPTIMIZER_PROMPT
                │
       ┌────────┼────────┐
       ▼        ▼        ▼
    claude    codex   gemini       (parallel, ThreadPoolExecutor)
       │        │        │
       └────────┼────────┘
                ▼
       SYNTHESIS_MULTI_PROVIDER_PROMPT
       (claude > codex > gemini synthesizer)
                ▼
       02-synthesis-prompt.txt  (final)
```

All run artifacts land under `output/<YYYYMMDD-HHMMSS>/`:

Single-provider modes:

- `00-original.txt` — input prompt verbatim
- `00-context.txt` — optional context file
- `01-optimized.md` — full provider response
- `01-optimized-prompt.txt` — extracted final prompt
- `01-optimized.log` — provider CLI invocation log
- `02-*` / `03-*` — additional artifacts in `--multi-pass` mode

`--provider all` mode:

- `00-original.txt` — input prompt verbatim
- `01-{claude,codex,gemini}.md` — full response per provider
- `01-{claude,codex,gemini}-prompt.txt` — extracted prompt per provider
- `01-{claude,codex,gemini}.log` — per-provider CLI invocation log
- `02-synthesis.md` — synthesizer full response
- `02-synthesis-prompt.txt` — **final synthesized prompt**
- `02-synthesis.log` — synthesizer CLI invocation log

## Timeline logging (`--log`)

`--log` adds a single human-readable timeline file at
`logs/prompt-engineer-<YYYYMMDD-HHMMSS>.log` showing every stage with
timestamps, elapsed time, the rendered system prompt that was sent to
Codex, the raw response, durations, and stage decisions. Use it to
audit how an optimization run unfolds.

```bash
# Default single-pass + timeline log to ./logs/
pe path/to/prompt.md --log

# Multi-pass + timeline log
pe path/to/prompt.md --multi-pass --log

# Custom log location
pe path/to/prompt.md --log-file /tmp/run.log
pe path/to/prompt.md --log --log-dir build/logs
```

Timeline log structure:

- Banner with start timestamp
- `CONFIGURATION` section (mode, source files, model, output dir)
- Original prompt + context blocks (full content)
- `STEP — N/M ...` headers for each pipeline stage
- Per-stage Codex CLI section: full command, model, rendered prompt
  sent, duration, response received, stderr (if non-empty)
- Final `DONE` footer with total elapsed time and final-prompt path

Long blocks are previewed up to 4000 chars with a `[truncated N chars]`
marker; the full per-stage `codex exec` raw log stays available under
`output/<stamp>/0X-*.log` as before.

## Requirements

- Python 3.8+ (standard library only, no pip deps)
- At least one of:
  - `claude` CLI on `PATH` (Claude Code itself; default)
  - `codex` CLI on `PATH` (`npm install -g @openai/codex`)
  - `gemini` CLI on `PATH` (`npm install -g @google/gemini-cli`)
- The corresponding logged-in account for the chosen provider

The script exits with code 2 if the requested provider's CLI is missing,
or if `--provider all` finds none of the three on PATH.

## Usage

```bash
# Interactive provider menu (default; falls back to claude on non-TTY)
pe path/to/prompt.md

# Explicit provider
pe path/to/prompt.md --provider claude
pe path/to/prompt.md --provider codex
pe path/to/prompt.md --provider gemini

# All three in parallel + best-of synthesis
pe path/to/prompt.md --provider all

# Stdin input
echo "Write me a tone-control prompt" | pe - --provider claude

# With a context file
pe path/to/prompt.md --provider claude --context path/to/context.md

# Legacy 3-stage mode (best-of synthesis on one provider)
pe path/to/prompt.md --provider claude --multi-pass

# Model override (passed to the chosen provider)
pe path/to/prompt.md --provider claude --model claude-opus-4-7
pe path/to/prompt.md --provider codex --model gpt-5.2

# Write a step-by-step timeline log to ./logs/
pe path/to/prompt.md --provider all --log
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
