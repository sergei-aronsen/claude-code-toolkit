# /prompt-engineer — Single-Prompt Optimizer

## Purpose

Rewrite a single prompt file into a deployment-ready version. Companion
to `/council` — where the Council validates a plan with Skeptic +
Pragmatist review, the Prompt Engineer rewrites one prompt for clarity,
controllability, reliability, and reusability. Uses Codex CLI (ChatGPT)
to run the optimizer.

---

## Usage

```text
/prompt-engineer <path-to-prompt-file>
/prompt-engineer <path-to-prompt-file> --context <context-file>
/prompt-engineer <path-to-prompt-file> --multi-pass
```

**Examples:**

- `/prompt-engineer prompts/code-review.md`
- `/prompt-engineer agents/security-auditor.md --context project-context.md`
- `/prompt-engineer my-prompt.md --multi-pass`

Or use the installed shell alias directly:

```bash
pe path/to/prompt.md
pe path/to/prompt.md --context path/to/context.md
pe path/to/prompt.md --multi-pass
echo "Write me a tone-control prompt" | pe -
```

---

## Modes

The optimizer (`scripts/prompt-engineer/optimize_prompt.py`) supports
two modes.

### single-pass (default)

One call to `codex exec` runs the PROMETHEUS optimizer prompt, which
performs both first-pass optimization **and** a built-in
meta-optimization pass internally. Output: `01-optimized-prompt.txt`
under the run's `output/<timestamp>/` directory.

Recommended for most prompts. Faster, cheaper, and the
meta-optimization pass produces near-best-of-three quality on
well-defined source prompts.

### multi-pass (`--multi-pass`)

Three-stage pipeline: PROMETHEUS optimization → external
meta-optimization → synthesis comparing the three versions. Final:
`03-final-prompt.txt`.

Use when the single-pass result is under-cooked — typically very short
or ambiguous source prompts, or when comparing the original against
two optimized variants is itself useful.

---

## Output Artifacts

All runs land under `output/<YYYYMMDD-HHMMSS>/`:

| File | Mode | Purpose |
|------|------|---------|
| `00-original.txt` | both | Input prompt verbatim |
| `00-context.txt` | both | Optional context file (if supplied) |
| `01-optimized.md` | both | Full Codex response (single-pass) |
| `01-optimized-prompt.txt` | both | Extracted final prompt (single-pass) |
| `01-optimized.log` | both | `codex exec` invocation log |
| `02-meta.md`, `02-meta-prompt.txt` | multi-pass | External meta-optimization stage |
| `03-final.md`, `03-final-prompt.txt` | multi-pass | Synthesis stage (the deliverable) |

---

## Flags

| Flag | What it does |
|------|--------------|
| `--context <path>` | Pass an extra context file appended to the optimizer prompt under `{{CONTEXT}}`. Use for codebase conventions, target model constraints, audience description, etc. |
| `--multi-pass` | Run the legacy 3-stage pipeline instead of single-pass |
| `--output-dir <path>` | Override the default `output/` parent directory |
| `--model <name>` | Override the default Codex model (e.g. `--model gpt-5.2`) |

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
which codex   # required on PATH
```

The Codex CLI is the only runtime dependency:

```bash
npm install -g @openai/codex
```

You also need an OpenAI account for Codex. The standalone installer
also writes a `pe` shell alias into `~/.zshrc` or `~/.bash_profile`.

---

## Cost / Time

- Single-pass: 1 Codex call. Typically 15–60 s wall clock depending on
  the source prompt length.
- Multi-pass: 3 Codex calls. Typically 45–180 s wall clock. ~3× the
  cost of single-pass.

A 600 s timeout is applied per stage. If Codex hangs the script raises
a `RuntimeError` and writes a `--- TIMEOUT after Ns ---` marker into
the per-stage log file.

---

## Reading the output

Always start with the **extracted** prompt file:

- Single-pass: `output/<ts>/01-optimized-prompt.txt`
- Multi-pass: `output/<ts>/03-final-prompt.txt`

The `.md` siblings (`01-optimized.md` / `03-final.md`) contain Codex's
full response including the `## Key Improvements` and `## Assumptions`
sections — useful for reviewing what changed and why, but not the
artifact you ship.

Then do a **manual merge** if needed. The optimizer is excellent at
structure, hierarchy, and removing bloat, but it sometimes drops
memorable / punchy framings that worked well in the original. Restore
those during review.

---

## Examples

### Optimize a base Council persona overlay

```bash
pe templates/council-prompts/personas/security-skeptic.md \
   --context /tmp/council-overlay-context.md
```

### Optimize an agent prompt with the legacy 3-stage pipeline

```bash
pe templates/base/agents/security-auditor.md --multi-pass
```

### Optimize a stdin prompt with a context file

```bash
cat my-prompt.md | pe - --context project-context.md
```
