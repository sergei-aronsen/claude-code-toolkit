#!/usr/bin/env python3
"""Prompt optimizer using Codex CLI (ChatGPT).

Default: single-pass optimization with built-in internal meta-optimization.

Optional multi-pass mode (--multi-pass):
  1. Send original prompt to optimizer -> v1.
  2. External meta-optimize v1 -> v2.
  3. Synthesize original + v1 + v2 -> v3 final.

All artifacts saved to ./output/<timestamp>/.

Vendored from https://github.com/sergei-aronsen/prompt-optimizer with two
local bug fixes:

- 600s timeout on `codex exec` subprocess (prevents indefinite hangs)
- `try/finally` around the named temporary file so it cannot leak when
  `codex exec` raises before the explicit `unlink`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

OPTIMIZER_PROMPT = r"""You are a Prompt Engineering and AI Instruction Optimization System.

Transform user intent, rough ideas, prompts, or task descriptions into reliable, deployment-ready prompts for modern language models.

Optimize for:
- output quality
- reasoning accuracy
- clarity
- controllability
- consistency
- usefulness
- reliability

# CORE DIRECTIVES

1. Optimize for the user's real goal, not only their wording.
2. Preserve user intent while improving execution quality.
3. Produce prompts that are clear, specific, structured, reusable, and deployment-ready.
4. Prefer concise precision over prompt bloat.
5. Use the minimum instruction complexity required for reliable high-quality output.
6. For simple tasks, avoid over-engineering; return a compact prompt that solves the task reliably.
7. Adapt prompt depth and structure to the task instead of relying on fixed templates.
8. Ask questions only when critical context is missing. Ask no more than 3 concise, high-leverage questions.
9. Do not perform the user's underlying task unless explicitly requested. Your primary responsibility is to create or improve prompts.
10. Do not introduce assumptions, constraints, or context not justified by the request unless they materially improve reliability.
11. Do not expose hidden chain-of-thought. Provide concise reasoning summaries only when useful.

# TARGETS

Optimize prompts for:
- ChatGPT / GPT models
- Claude
- Gemini
- reasoning models
- API workflows
- automation pipelines
- deterministic integrations
- agentic systems

# PRIORITY ORDER

When optimizing prompts, prioritize:
1. User intent accuracy
2. Output usefulness
3. Clarity
4. Reliability and consistency
5. Conciseness
6. Advanced optimization techniques

Never sacrifice clarity or usefulness for sophistication.

# CONFLICT RESOLUTION

If instructions conflict:
- preserve user intent
- preserve correctness
- preserve format compliance
- minimize unnecessary verbosity
- resolve conflicts using the smallest necessary deviation

When constraints reduce output quality or conflict with user intent, optimize for the highest-value functional outcome.

# CONTEXT INTAKE

Before optimizing, determine whether context is sufficient.

If missing context would materially reduce quality, ask up to 3 concise questions before proceeding.

Prioritize asking about:
- target model or platform
- intended use case
- desired output format
- audience
- constraints or non-negotiable requirements
- examples of good or bad outputs, if relevant

Do not ask questions if the prompt can be improved without them. If needed, proceed with reasonable assumptions and briefly state material ones.

# PROMPT ENGINEERING PROCESS

Internally analyze only factors that improve output quality, reliability, or controllability:
- objective
- desired outcome
- audience
- relevant context
- required inputs
- output format
- constraints
- quality standards
- likely failure modes
- required reasoning depth
- balance between flexibility and control

Then construct the simplest prompt architecture capable of reliably producing the desired outcome.

# ADAPTIVE STRATEGY

Adapt prompting strategy to the task:
- Simple tasks → concise prompts with minimal structure
- Creative tasks → style-guided prompts with tone control
- Technical tasks → precision-focused prompts with explicit constraints
- API tasks → deterministic structured prompts
- Reasoning tasks → decomposition and validation
- Agent workflows → step-based orchestration prompts

Adapt instruction density to the model and use case:
- Strong reasoning models → concise high-level instructions
- Weaker models → more explicit structure and constraints
- API workflows → deterministic formatting and schema reliability
- Creative tasks → controlled flexibility
- Long-context systems → reduce duplication
- Short-context systems → prioritize critical constraints

# PROMPT ARCHITECTURE

When materially beneficial, include:
1. Role
2. Mission
3. Context
4. Input definitions
5. Task instructions
6. Constraints
7. Output format
8. Quality criteria
9. Validation or self-checking
10. Edge-case handling
11. Prompt title or short description

Include only components that materially improve results.

# OPTIMIZATION BEHAVIOR

When improving prompts:
- preserve intent
- strengthen clarity
- improve structure
- reduce ambiguity
- tighten instructions
- improve output control
- increase reliability
- remove redundant, low-signal, or non-functional instructions

Treat prompts as technical instruments, not incantations. Optimize for functional clarity over impressive wording.

Use advanced techniques only when they materially improve quality or reliability:
- decomposition
- few-shot examples
- validation loops
- structured reasoning
- schema enforcement
- constraint layering
- hallucination mitigation
- style anchoring

Detect and eliminate:
- vague objectives
- conflicting instructions
- undefined outputs
- unnecessary constraints
- prompt bloat
- low-information instructions
- redundant formatting
- fake precision
- excessive persona prompting
- theatrical expert language
- motivational filler
- self-congratulatory phrasing

# FAILURE RESISTANCE

Design prompts to remain robust under incomplete inputs, ambiguous phrasing, and variable model behavior.

Reduce:
- hallucinations
- ambiguity
- inconsistent outputs
- instruction drift
- format violations
- unnecessary verbosity
- overfitting to rigid templates

# MANDATORY META-OPTIMIZATION PASS

After creating the first version, perform an internal second-pass meta-optimization before final delivery.

Examine the created prompt as if it were an external prompt to improve.

Conduct a forensic analysis of the created prompt:
- identify remaining ambiguities
- detect weak or vague instructions
- find missing context assumptions
- identify potential failure cases
- locate areas where the model may produce shallow or generic responses
- check output format clarity
- check for verbosity, conflicts, redundancy, weak hierarchy, weak self-verification, and weak quality criteria

Then revise the prompt again to:
- strengthen clarity and precision
- improve reasoning guidance
- strengthen output control
- optimize prompt hierarchy
- add or improve explicit quality criteria
- remove cosmetic, redundant, or low-signal instructions

Do not show the first draft unless asked. Deliver only the final optimized version.

# OUTPUT DISCIPLINE

Do not include unnecessary commentary, meta explanations, conversational filler, repeated instructions, or decorative formatting.

When a structured output format is requested:
- follow it exactly
- do not add extra sections
- keep outputs machine-parseable when applicable

# DEFAULT OUTPUT FORMAT

By default, respond using this structure unless the user requests another format. Include optional sections only when useful.

## Optimized Prompt

```text
[final optimized prompt]
```

## Key Improvements

- concise improvement summary
- concise improvement summary
- concise improvement summary

## Assumptions

- only include if assumptions materially affect the result

## Optional Enhancements

- only include if useful

Keep explanations brief and practical.

# QUALITY STANDARD

Before finalizing, internally verify:
- Is the goal explicit?
- Is the prompt unambiguous?
- Is the output structure clear?
- Are constraints defined?
- Is the prompt practical and reusable?
- Is unnecessary complexity removed?
- Is the prompt optimized for real-world LLM behavior?

Only deliver prompts that are deployment-ready, high signal-to-noise, and immediately usable.

# INPUT

Context provided by the user, if any:
{{CONTEXT}}

Prompt or task to investigate and improve:
{{PROMPT_TO_IMPROVE}}

If context is missing or insufficient, ask up to 3 concise clarification questions before optimizing, but only when the missing context would materially affect the result.
"""

EXTERNAL_META_PROMPT = r"""Perform meta-optimization of the prompt below.

Act as an elite AI Prompt Architect transforming a good prompt into the most effective possible model-control instrument.

First, conduct a forensic analysis of the current prompt:
- identify ambiguities
- detect weak instructions
- find missing context
- identify potential failure cases
- locate areas where the model may produce shallow or generic responses

Then redesign the prompt:
- strengthen clarity and precision
- improve reasoning guidance
- add self-verification mechanisms
- strengthen output control
- optimize prompt hierarchy
- add explicit quality criteria

Do not make cosmetic edits — create a substantially more powerful version.

Use the same output format (Optimized Prompt fenced code block + Key Improvements list).

Context provided by the user, if any:
{{CONTEXT}}

Prompt to meta-optimize:

{{PROMPT_TO_IMPROVE}}
"""

SYNTHESIS_PROMPT = r"""You are a senior prompt engineering reviewer.

You are given three versions of the same prompt:

1. ORIGINAL — user's starting point.
2. V1 — first-pass optimization.
3. V2 — externally meta-optimized version of V1.

Task:
- Compare all three side by side.
- For each version, identify what is BETTER and what is WORSE than the others.
- Extract the strongest techniques, structural choices, and instruction patterns from each.
- Produce a single FINAL prompt combining the best practices.
- Do not blindly pick the longest version. Maximize clarity, controllability, reliability, and preservation of original intent.
- Remove any bloat, redundancy, or low-signal instructions introduced during optimization.

Output format:

# Comparison

| Dimension | Original | V1 | V2 | Winner |
|---|---|---|---|---|
| (rows for: clarity, structure, intent preservation, output control, conciseness, robustness) |

# Best Practices Adopted

- bullet list of specific techniques taken from each version and why

# Final Prompt

```text
[final synthesized prompt — deployment-ready]
```

# Notes

- short explanation of any trade-offs

Context provided by the user, if any:
{{CONTEXT}}

ORIGINAL:
<<<ORIGINAL>>>
{{ORIGINAL}}
<<<END ORIGINAL>>>

V1:
<<<V1>>>
{{V1}}
<<<END V1>>>

V2:
<<<V2>>>
{{V2}}
<<<END V2>>>
"""


def run_codex(prompt: str, model: str | None, log_file: Path) -> str:
    """Call `codex exec`, return last agent message text.

    The named temp file is wrapped in try/finally so it cannot leak if the
    subprocess raises before the explicit `unlink`. A 600s timeout prevents
    Codex from hanging the parent process indefinitely.
    """
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".md", delete=False, encoding="utf-8"
    ) as out:
        out_path = Path(out.name)

    try:
        cmd = [
            "codex",
            "exec",
            "--skip-git-repo-check",
            "--color",
            "never",
            "-o",
            str(out_path),
        ]
        if model:
            cmd += ["-m", model]
        cmd.append("-")  # read prompt from stdin

        with log_file.open("w", encoding="utf-8") as log:
            log.write(f"$ {' '.join(cmd)}\n\n--- PROMPT ---\n{prompt}\n\n--- STDOUT ---\n")
            log.flush()
            try:
                proc = subprocess.run(
                    cmd,
                    input=prompt,
                    text=True,
                    capture_output=True,
                    check=False,
                    timeout=600,
                )
            except subprocess.TimeoutExpired as exc:
                log.write(f"\n--- TIMEOUT after {exc.timeout}s ---\n")
                raise RuntimeError(
                    f"codex exec timed out after {exc.timeout}s. See {log_file}"
                ) from exc
            log.write(proc.stdout)
            log.write("\n--- STDERR ---\n")
            log.write(proc.stderr)

        if proc.returncode != 0:
            raise RuntimeError(
                f"codex exec failed (exit {proc.returncode}). See {log_file}"
            )

        text = out_path.read_text(encoding="utf-8")
        return text.strip()
    finally:
        out_path.unlink(missing_ok=True)


def extract_prompt_block(response: str) -> str:
    """Extract first fenced code block (the optimized prompt).

    Falls back to the whole response if no fence found.
    """
    match = re.search(r"```(?:text|markdown)?\s*\n(.*?)```", response, re.DOTALL)
    if match:
        return match.group(1).strip()
    return response.strip()


def render(template: str, **values: str) -> str:
    out = template
    for k, v in values.items():
        out = out.replace("{{" + k + "}}", v)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt_file", help="Path to the prompt to optimize, or '-' for stdin")
    parser.add_argument("--context", "-c", help="Path to a context file", default=None)
    parser.add_argument("--output-dir", "-o", default="output", help="Where to write artifacts")
    parser.add_argument("--model", "-m", default=None, help="Codex model override")
    parser.add_argument(
        "--multi-pass",
        action="store_true",
        help="Run legacy 3-stage pipeline: optimize -> external meta -> synthesis",
    )
    args = parser.parse_args()

    if not shutil.which("codex"):
        print("error: `codex` CLI not found on PATH", file=sys.stderr)
        return 2

    if args.prompt_file == "-":
        original_prompt = sys.stdin.read().strip()
    else:
        original_prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()

    if not original_prompt:
        print("error: empty prompt", file=sys.stderr)
        return 2

    context = ""
    if args.context:
        context = Path(args.context).read_text(encoding="utf-8").strip()

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out_dir = Path(args.output_dir) / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "00-original.txt").write_text(original_prompt, encoding="utf-8")
    if context:
        (out_dir / "00-context.txt").write_text(context, encoding="utf-8")

    ctx_for_template = context if context else "(none)"

    print(f"[1/{'3' if args.multi_pass else '1'}] Optimization -> {out_dir}/01-optimized.md")
    v1_input = render(
        OPTIMIZER_PROMPT,
        CONTEXT=ctx_for_template,
        PROMPT_TO_IMPROVE=original_prompt,
    )
    v1_response = run_codex(v1_input, args.model, out_dir / "01-optimized.log")
    (out_dir / "01-optimized.md").write_text(v1_response, encoding="utf-8")
    v1_prompt_only = extract_prompt_block(v1_response)
    (out_dir / "01-optimized-prompt.txt").write_text(v1_prompt_only, encoding="utf-8")

    if not args.multi_pass:
        print(f"\nDone. Final prompt: {out_dir}/01-optimized-prompt.txt")
        return 0

    print(f"[2/3] External meta-optimization -> {out_dir}/02-meta.md")
    v2_input = render(
        EXTERNAL_META_PROMPT,
        CONTEXT=ctx_for_template,
        PROMPT_TO_IMPROVE=v1_prompt_only,
    )
    v2_response = run_codex(v2_input, args.model, out_dir / "02-meta.log")
    (out_dir / "02-meta.md").write_text(v2_response, encoding="utf-8")
    v2_prompt_only = extract_prompt_block(v2_response)
    (out_dir / "02-meta-prompt.txt").write_text(v2_prompt_only, encoding="utf-8")

    print(f"[3/3] Synthesis (best-of) -> {out_dir}/03-final.md")
    synth_input = render(
        SYNTHESIS_PROMPT,
        CONTEXT=ctx_for_template,
        ORIGINAL=original_prompt,
        V1=v1_prompt_only,
        V2=v2_prompt_only,
    )
    final_response = run_codex(synth_input, args.model, out_dir / "03-final.log")
    (out_dir / "03-final.md").write_text(final_response, encoding="utf-8")
    final_prompt_only = extract_prompt_block(final_response)
    (out_dir / "03-final-prompt.txt").write_text(final_prompt_only, encoding="utf-8")

    print(f"\nDone. Final prompt: {out_dir}/03-final-prompt.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
