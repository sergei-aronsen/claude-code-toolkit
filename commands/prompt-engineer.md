# /prompt-engineer — Single-Prompt Optimizer (multi-provider)

## Purpose

Rewrite a single prompt file into a deployment-ready version. Companion
to `/council` — where the Council validates a plan with Skeptic +
Pragmatist review, the Prompt Engineer rewrites one prompt for clarity,
controllability, reliability, and reusability. Drives one of three
provider CLIs: **Claude Code** (`claude -p`), **Codex** (`codex exec`),
or **Gemini** (`gemini -p`). `--provider all` runs all three in
parallel and synthesizes a best-of final.

---

## Usage

```text
/prompt-engineer <path-to-prompt-file>
/prompt-engineer <path-to-prompt-file> --provider claude
/prompt-engineer <path-to-prompt-file> --provider all
/prompt-engineer <path-to-prompt-file> --context <context-file>
/prompt-engineer <path-to-prompt-file> --multi-pass
/prompt-engineer <path-to-prompt-file> --log
```

**Examples:**

- `/prompt-engineer prompts/code-review.md --provider claude`
- `/prompt-engineer agents/security-auditor.md --context project-context.md --provider all`
- `/prompt-engineer my-prompt.md --multi-pass --provider codex`

Or use the installed shell alias directly:

```bash
pe path/to/prompt.md                              # interactive menu
pe path/to/prompt.md --provider claude
pe path/to/prompt.md --provider all --log
pe path/to/prompt.md --context path/to/context.md
echo "Write me a tone-control prompt" | pe - --provider claude
```

---

## Provider (`--provider`)

| Value | CLI invoked | Notes |
|-------|-------------|-------|
| `claude` | `claude -p` (stdin) | Best instruction-following on long system prompts. |
| `codex` | `codex exec --skip-git-repo-check -o tmp -` | Tight, terse rewrites. |
| `gemini` | `gemini -p ""` (stdin) | Fast. Output sometimes lacks fenced block. |
| `all` | claude + codex + gemini in parallel, then 1 synthesis call | 4 calls total. Synthesizer preference: claude > codex > gemini. |
| `ask` | Interactive menu on TTY; falls back to `claude` when stdin is not a TTY | **Default**. |

Missing CLIs are skipped in `all` mode. Explicit `--provider claude`
on a system without `claude` installed exits with code 2.

---

## Modes

The optimizer (`scripts/prompt-engineer/optimize_prompt.py`) supports
two pipeline modes (orthogonal to provider).

### single-pass (default)

One call to the chosen provider runs the optimizer system prompt,
which performs first-pass optimization **and** a built-in
meta-optimization pass internally. Output:
`01-optimized-prompt.txt` under the run's `output/<timestamp>/`
directory.

Recommended for most prompts. Faster, cheaper, and the
meta-optimization pass produces near-best-of-three quality on
well-defined source prompts.

### multi-pass (`--multi-pass`)

Three-stage pipeline on a single provider: optimization → external
meta-optimization → synthesis comparing the three versions. Final:
`03-final-prompt.txt`.

Use when the single-pass result is under-cooked — typically very short
or ambiguous source prompts, or when comparing the original against
two optimized variants is itself useful.

Rejected with `--provider all` (use one or the other).

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
       (synthesizer: claude > codex > gemini)
                ▼
       02-synthesis-prompt.txt  (final)
```

---

## Output Artifacts

All runs land under `output/<YYYYMMDD-HHMMSS>/`.

Single-provider modes:

| File | Mode | Purpose |
|------|------|---------|
| `00-original.txt` | both | Input prompt verbatim |
| `00-context.txt` | both | Optional context file (if supplied) |
| `01-optimized.md` | both | Full provider response (single-pass) |
| `01-optimized-prompt.txt` | both | Extracted final prompt (single-pass) |
| `01-optimized.log` | both | Provider CLI invocation log |
| `02-meta.md`, `02-meta-prompt.txt` | multi-pass | External meta-optimization stage |
| `03-final.md`, `03-final-prompt.txt` | multi-pass | Synthesis stage (the deliverable) |

`--provider all` mode:

| File | Purpose |
|------|---------|
| `00-original.txt` | Input prompt verbatim |
| `01-{claude,codex,gemini}.md` | Full response per provider |
| `01-{claude,codex,gemini}-prompt.txt` | Extracted prompt per provider |
| `01-{claude,codex,gemini}.log` | Per-provider CLI invocation log |
| `02-synthesis.md` | Synthesizer full response |
| `02-synthesis-prompt.txt` | **Final synthesized prompt (the deliverable)** |
| `02-synthesis.log` | Synthesizer CLI invocation log |

---

## Flags

| Flag | What it does |
|------|--------------|
| `--provider {claude,codex,gemini,all,ask}` | Pick provider. Default `ask` (TTY menu, claude fallback). |
| `--context <path>` | Pass an extra context file appended to the optimizer prompt under `{{CONTEXT}}`. Use for codebase conventions, target model constraints, audience description, etc. |
| `--multi-pass` | Run the legacy 3-stage pipeline instead of single-pass. Single-provider only. |
| `--output-dir <path>` | Override the default `output/` parent directory. |
| `--model <name>` | Override the default model for the chosen provider (e.g. `claude-opus-4-7`, `gpt-5.2`). |
| `--log` | Write a human-readable timeline log of every stage to `logs/prompt-engineer-<timestamp>.log`. |
| `--log-file <path>` | Explicit timeline log path (implies `--log`). |
| `--log-dir <dir>` | Directory for `--log` files (default `./logs`). |

---

## When to Use

| Situation | Use this | Use /council |
|-----------|----------|--------------|
| Tightening a Claude system prompt | yes | no |
| Polishing an agent persona / role prompt | yes | no |
| Rewriting an audit / review prompt | yes | no |
| Validating an implementation plan | no | yes |
| Domain-specific risk review (security / perf / UX / migration) | no | yes |
| Multi-AI verdict (PROCEED / SIMPLIFY / RETHINK / SKIP) | no | yes |

The two commands are independent — they share no state and can be
chained: optimize a prompt, then run `/council` on the plan that
references it.

---

## Prerequisites

```bash
bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/setup-prompt-engineer.sh)
```

Check:

```bash
test -f ~/.claude/prompt-engineer/optimize_prompt.py && echo "Installed" || echo "Not installed"
which claude codex gemini    # at least one required on PATH
```

At least one provider CLI is required. None are mandatory individually:

```bash
# Claude Code is itself the default provider (already installed if you
# are using this slash command).
# Optional:
npm install -g @openai/codex          # for --provider codex
npm install -g @google/gemini-cli     # for --provider gemini
```

The standalone installer also writes a `pe` shell alias into
`~/.zshrc` or `~/.bash_profile`.

---

## Cost / Time

| Mode | Calls | Typical wall clock |
|------|-------|--------------------|
| Single-pass (any provider) | 1 | 15–60 s |
| Multi-pass single provider | 3 | 45–180 s |
| `--provider all` | 3 parallel + 1 synthesis = 4 sequential-equivalent | 30–90 s |

A 600 s timeout is applied per provider call. If a provider hangs the
script raises a `RuntimeError` and writes a `--- TIMEOUT after Ns ---`
marker into the per-stage log file. In `--provider all`, a single
provider failure is recorded but the run continues with the remaining
successful outputs.

---

## Reading the output

Always start with the **extracted** prompt file:

- Single-pass: `output/<ts>/01-optimized-prompt.txt`
- Multi-pass: `output/<ts>/03-final-prompt.txt`
- `--provider all`: `output/<ts>/02-synthesis-prompt.txt`

The `.md` siblings contain the provider's full response including
`## Key Improvements` and `## Assumptions` sections — useful for
reviewing what changed and why, but not the artifact you ship.

In `all` mode, also diff the per-provider extracts to see where each
model contributed:

```bash
diff output/<ts>/01-claude-prompt.txt output/<ts>/01-codex-prompt.txt
diff output/<ts>/01-claude-prompt.txt output/<ts>/01-gemini-prompt.txt
```

Then do a **manual merge** if needed. The optimizer is excellent at
structure, hierarchy, and removing bloat, but it sometimes drops
memorable / punchy framings that worked well in the original. Restore
those during review.

Use `--log` to inspect the full pipeline (rendered prompts sent,
durations, raw responses, decisions) in one human-readable file under
`./logs/`.

---

## Examples

### Optimize a base Council persona overlay via Claude Code

```bash
pe templates/council-prompts/personas/security-skeptic.md \
   --provider claude \
   --context /tmp/council-overlay-context.md
```

### Fan-out to all three providers + best-of synthesis + timeline log

```bash
pe agents/security-auditor.md --provider all --log
```

### Optimize an agent prompt with the legacy 3-stage pipeline on Codex

```bash
pe templates/base/agents/security-auditor.md --provider codex --multi-pass
```

### Optimize a stdin prompt with a context file via Gemini

```bash
cat my-prompt.md | pe - --provider gemini --context project-context.md
```
