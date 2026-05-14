#!/usr/bin/env python3
"""Multi-provider prompt optimizer.

Drives one of: Claude Code (`claude -p`), Codex (`codex exec`), or
Gemini (`gemini -p ""`) via subprocess + stdin. Selected with
`--provider {claude|codex|gemini|all|ask}` (default: `ask`).

Modes:
  - single-pass (default): one provider call with built-in internal
    meta-optimization pass.
  - `--multi-pass`: legacy 3-stage pipeline (optimize -> external meta
    -> synthesis), single provider only.
  - `--provider all`: fan-out to every available provider in parallel,
    then synthesize a best-of final via one extra call. Synthesizer
    preference: claude > codex > gemini.

Optional `--log` writes a human-readable timeline log of every stage
(rendered prompts, durations, responses, decisions) to
`logs/prompt-engineer-<timestamp>.log`.

All artifacts saved to `./output/<timestamp>/`.

Vendored from https://github.com/sergei-aronsen/prompt-optimizer with
local fixes:

- 600s timeout on every provider subprocess (prevents indefinite hangs)
- `try/finally` around the Codex named temporary file so it cannot leak
  when `codex exec` raises before the explicit `unlink`.
- Generic `run_provider()` abstraction over the original single-provider
  `run_codex()`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Optional


def _open_0600(path: Path, mode: str = "w"):
    """Open `path` for writing with file mode 0600. Mirror of brain.py:191-205.

    Audit 2026-05-14 M-2: every artifact this script writes contains user
    prompt content (potentially including secrets). Default umask 0022
    leaks them at 0644. Force 0600 at open time so a same-host actor
    (other unix user, container side-car, dev box guest account) cannot
    read the bytes between write and explicit delete.
    """
    flags = os.O_CREAT | os.O_WRONLY
    if mode == "a":
        flags |= os.O_APPEND
    elif mode == "w":
        flags |= os.O_TRUNC
    else:
        raise ValueError(f"_open_0600: unsupported mode {mode!r}")
    fd = os.open(str(path), flags, 0o600)
    try:
        os.fchmod(fd, 0o600)
    except OSError:
        pass
    return os.fdopen(fd, mode, encoding="utf-8")


def _write_text_0600(path: Path, content: str) -> None:
    """Path.write_text equivalent that creates the file with mode 0600."""
    with _open_0600(path, "w") as fh:
        fh.write(content)

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

SYNTHESIS_MULTI_PROVIDER_PROMPT = r"""You are a senior prompt engineering reviewer.

You are given the SAME source prompt, optimized independently by three
different model providers. Your task is to produce ONE final prompt that
combines the strongest patterns from each, without bloat.

Rules:
- Compare side by side along: clarity, structure, intent preservation,
  output control, conciseness, robustness.
- Extract the strongest techniques, structural choices, and instruction
  patterns from each provider.
- Produce a single FINAL prompt combining the best practices.
- Do not blindly pick the longest version. Maximize clarity,
  controllability, reliability, and preservation of original intent.
- Remove any bloat, redundancy, or low-signal instructions any provider
  introduced.

Output format:

# Comparison

| Dimension | Claude | Codex | Gemini | Winner |
|---|---|---|---|---|
| clarity |  |  |  |  |
| structure |  |  |  |  |
| intent preservation |  |  |  |  |
| output control |  |  |  |  |
| conciseness |  |  |  |  |
| robustness |  |  |  |  |

# Best Practices Adopted

- bullet list of specific techniques taken from each provider and why

# Final Prompt

```text
[final synthesized prompt — deployment-ready]
```

# Notes

- short explanation of any trade-offs

Context provided by the user, if any:
{{CONTEXT}}

ORIGINAL source prompt (user's starting point):
<<<ORIGINAL>>>
{{ORIGINAL}}
<<<END ORIGINAL>>>

CLAUDE optimization:
<<<CLAUDE>>>
{{CLAUDE}}
<<<END CLAUDE>>>

CODEX optimization:
<<<CODEX>>>
{{CODEX}}
<<<END CODEX>>>

GEMINI optimization:
<<<GEMINI>>>
{{GEMINI}}
<<<END GEMINI>>>
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


class TimelineLogger:
    """Human-readable per-step timeline log for --log mode.

    Writes a single file showing each pipeline stage with timestamps,
    elapsed time, rendered prompt/response previews, and Codex CLI
    invocations. Disabled when path is None (no I/O cost).
    """

    PREVIEW_CHARS = 4000

    def __init__(self, path: Optional[Path]):
        self.path = path
        self.fh = None
        self.start = time.monotonic()
        # Audit 2026-05-14 M-4: --provider all fans out to 3 threads
        # (ThreadPoolExecutor). Without a lock, multi-line writers
        # (step/section/block) interleave with each other and produce
        # corrupt logs. Lock guards every public writer so each record
        # lands atomically.
        self._lock = threading.Lock()
        if path:
            path.parent.mkdir(parents=True, exist_ok=True)
            # Audit 2026-05-14 M-2: log file may contain rendered prompts
            # with user secrets — force 0600 instead of umask-default 0644.
            self.fh = _open_0600(path, "w")
            self._banner()

    def _banner(self) -> None:
        ts = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self._lock:
            self._w("=" * 78)
            self._w(" PROMPT ENGINEER — OPTIMIZATION TIMELINE")
            self._w(f" Started: {ts}")
            self._w("=" * 78)

    def _w(self, line: str = "") -> None:
        # Internal-only; callers hold self._lock for multi-line records.
        if self.fh:
            self.fh.write(line + "\n")

    def _stamp(self) -> str:
        elapsed = time.monotonic() - self.start
        ts = dt.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        return f"[{ts}] (+{elapsed:7.2f}s)"

    def step(self, title: str) -> None:
        with self._lock:
            self._w()
            self._w("#" * 78)
            self._w(f"# {self._stamp()} STEP — {title}")
            self._w("#" * 78)

    def section(self, title: str) -> None:
        with self._lock:
            self._w()
            self._w(f"--- {self._stamp()} {title} ---")

    def kv(self, key: str, value: object) -> None:
        with self._lock:
            self._w(f"  {key}: {value}")

    def block(self, title: str, body: str, max_chars: Optional[int] = None) -> None:
        cap = self.PREVIEW_CHARS if max_chars is None else max_chars
        with self._lock:
            self._w()
            self._w(f">>> {title} ({len(body)} chars) >>>")
            if len(body) > cap > 0:
                self._w(body[:cap])
                self._w(f"... [truncated {len(body) - cap} chars] ...")
            else:
                self._w(body)
            self._w(f"<<< END {title} <<<")

    def event(self, message: str) -> None:
        with self._lock:
            self._w(f"{self._stamp()} {message}")

    def close(self, summary: dict | None = None) -> None:
        with self._lock:
            if not self.fh:
                return
            elapsed = time.monotonic() - self.start
            self._w()
            self._w("=" * 78)
            self._w(f" DONE — total elapsed {elapsed:.2f}s")
            if summary:
                for k, v in summary.items():
                    self._w(f"   {k}: {v}")
            self._w("=" * 78)
            self.fh.close()
            self.fh = None


PROVIDERS = ("claude", "codex", "gemini")
SUBPROCESS_TIMEOUT = 600


def _provider_cmd(provider: str, model: str | None, out_path: Path | None) -> list[str]:
    """Construct the CLI command for a provider. `out_path` only used by Codex."""
    if provider == "codex":
        cmd = [
            "codex", "exec", "--skip-git-repo-check", "--color", "never",
            "-o", str(out_path), "-",
        ]
        if model:
            cmd[-1:-1] = ["-m", model]
        return cmd
    if provider == "claude":
        cmd = ["claude", "-p"]
        if model:
            cmd += ["--model", model]
        return cmd
    if provider == "gemini":
        cmd = ["gemini", "-p", ""]
        if model:
            cmd[2:2] = ["-m", model]  # insert before empty -p arg
        return cmd
    raise ValueError(f"unknown provider: {provider}")


def run_provider(
    provider: str,
    prompt: str,
    model: str | None,
    log_file: Path,
    timeline: Optional[TimelineLogger] = None,
    stage_label: str | None = None,
) -> str:
    """Call a provider CLI, return last agent message text.

    Codex writes its response to a temp file via `-o`. Claude and Gemini
    print to stdout. All three accept the rendered prompt via stdin.

    Wrapped in try/finally for temp-file cleanup. 600s timeout prevents
    indefinite hangs. When `timeline` is provided, records command,
    prompt preview, duration, response preview, and stderr.
    """
    if provider not in PROVIDERS:
        raise ValueError(f"unknown provider: {provider}")
    if stage_label is None:
        stage_label = f"{provider} exec"

    out_path: Path | None = None
    if provider == "codex":
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".md", delete=False, encoding="utf-8"
        ) as out:
            out_path = Path(out.name)

    try:
        cmd = _provider_cmd(provider, model, out_path)

        if timeline:
            timeline.section(f"{stage_label} — invoke {provider.upper()} CLI")
            timeline.kv("command", " ".join(cmd))
            timeline.kv("model", model or "(provider default)")
            timeline.kv("stdin bytes", len(prompt.encode("utf-8")))
            timeline.kv("raw log", str(log_file))
            timeline.block(
                f"{stage_label} — RENDERED PROMPT SENT TO {provider.upper()}", prompt
            )

        t0 = time.monotonic()
        # Audit 2026-05-14 M-2: subprocess raw-log contains the rendered
        # prompt + stdout + stderr — wrap with 0600 instead of default 0644.
        with _open_0600(log_file, "w") as log:
            log.write(f"$ {' '.join(cmd)}\n\n--- PROMPT ---\n{prompt}\n\n--- STDOUT ---\n")
            log.flush()
            try:
                proc = subprocess.run(
                    cmd,
                    input=prompt,
                    text=True,
                    capture_output=True,
                    check=False,
                    timeout=SUBPROCESS_TIMEOUT,
                )
            except subprocess.TimeoutExpired as exc:
                log.write(f"\n--- TIMEOUT after {exc.timeout}s ---\n")
                if timeline:
                    timeline.event(f"{stage_label} — TIMEOUT after {exc.timeout}s")
                raise RuntimeError(
                    f"{provider} timed out after {exc.timeout}s. See {log_file}"
                ) from exc
            log.write(proc.stdout)
            log.write("\n--- STDERR ---\n")
            log.write(proc.stderr)

        duration = time.monotonic() - t0

        if proc.returncode != 0:
            if timeline:
                timeline.event(
                    f"{stage_label} — FAILED exit={proc.returncode} duration={duration:.2f}s"
                )
                timeline.block(f"{stage_label} — STDERR", proc.stderr or "(empty)")
            raise RuntimeError(
                f"{provider} failed (exit {proc.returncode}). See {log_file}"
            )

        if provider == "codex":
            text = out_path.read_text(encoding="utf-8").strip()
        else:
            text = proc.stdout.strip()

        if timeline:
            timeline.event(
                f"{stage_label} — OK exit=0 duration={duration:.2f}s response={len(text)} chars"
            )
            if proc.stderr.strip():
                timeline.block(f"{stage_label} — STDERR (non-empty)", proc.stderr.strip(), 1500)
            timeline.block(f"{stage_label} — RESPONSE FROM {provider.upper()}", text)

        return text
    finally:
        if out_path is not None:
            out_path.unlink(missing_ok=True)


def run_codex(
    prompt: str,
    model: str | None,
    log_file: Path,
    timeline: Optional[TimelineLogger] = None,
    stage_label: str = "codex exec",
) -> str:
    """Backward-compatible wrapper preserved for any external caller."""
    return run_provider("codex", prompt, model, log_file, timeline, stage_label)


def detect_providers() -> dict[str, bool]:
    """Return {provider: bool_available} for each provider CLI on PATH."""
    return {p: shutil.which(p) is not None for p in PROVIDERS}


def pick_provider_interactive(available: dict[str, bool]) -> str:
    """TTY menu to pick provider. Falls back to claude when not a TTY."""
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        return "claude"

    options: list[tuple[str, str]] = []
    for p in PROVIDERS:
        suffix = "" if available[p] else " (NOT INSTALLED)"
        options.append((p, f"{p}{suffix}"))
    all_installed = all(available.values())
    options.append((
        "all",
        "all" + ("" if all_installed else " (skips missing CLIs)"),
    ))

    print("\nPick provider for prompt optimization:", file=sys.stderr)
    for i, (_, label) in enumerate(options, start=1):
        print(f"  {i}) {label}", file=sys.stderr)
    print(file=sys.stderr)

    while True:
        try:
            choice = input("Choice [1]: ").strip() or "1"
        except (EOFError, KeyboardInterrupt):
            print("\naborted", file=sys.stderr)
            raise SystemExit(130)
        if choice.isdigit() and 1 <= int(choice) <= len(options):
            picked = options[int(choice) - 1][0]
            if picked in PROVIDERS and not available[picked]:
                print(
                    f"error: {picked} CLI not installed. Pick again.",
                    file=sys.stderr,
                )
                continue
            return picked
        print(f"error: invalid choice {choice!r}", file=sys.stderr)


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


def run_all_mode(
    *,
    original_prompt: str,
    ctx_for_template: str,
    model: str | None,
    out_dir: Path,
    timeline: TimelineLogger,
    available: dict[str, bool],
) -> int:
    """Fan out the first optimization pass to every available provider in
    parallel, then synthesize a single best-of final prompt via one extra
    call. Synthesizer preference: claude > codex > gemini.
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed

    runnable = [p for p in PROVIDERS if available[p]]
    missing = [p for p in PROVIDERS if not available[p]]
    if not runnable:
        print("error: no provider CLIs found on PATH", file=sys.stderr)
        timeline.close()
        return 2
    if missing:
        timeline.event(f"--provider all: skipping unavailable: {missing}")
        print(f"warning: skipping unavailable: {', '.join(missing)}", file=sys.stderr)

    rendered = render(
        OPTIMIZER_PROMPT,
        CONTEXT=ctx_for_template,
        PROMPT_TO_IMPROVE=original_prompt,
    )

    timeline.step(f"1/2 — FAN-OUT to {len(runnable)} provider(s) in parallel")
    print(f"[1/2] Fan-out -> {', '.join(runnable)}")
    timeline.kv("providers", ", ".join(runnable))
    timeline.kv("rendered input chars", len(rendered))

    results: dict[str, str] = {}
    errors: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=len(runnable)) as pool:
        futures = {
            pool.submit(
                run_provider,
                p,
                rendered,
                model,
                out_dir / f"01-{p}.log",
                timeline,
                f"STAGE 1 ({p})",
            ): p
            for p in runnable
        }
        for fut in as_completed(futures):
            p = futures[fut]
            try:
                results[p] = fut.result()
            except Exception as exc:
                errors[p] = str(exc)
                timeline.event(f"STAGE 1 ({p}) — ABORTED: {exc}")
                print(f"warning: {p} failed: {exc}", file=sys.stderr)

    if not results:
        print("error: all providers failed", file=sys.stderr)
        timeline.close({"failed providers": ", ".join(errors)})
        return 1

    extracted: dict[str, str] = {}
    for p, resp in results.items():
        _write_text_0600(out_dir / f"01-{p}.md", resp)
        extracted[p] = extract_prompt_block(resp)
        _write_text_0600(out_dir / f"01-{p}-prompt.txt", extracted[p])
        timeline.event(
            f"STAGE 1 ({p}) — saved 01-{p}.md + 01-{p}-prompt.txt "
            f"(extracted {len(extracted[p])} chars)"
        )

    synth_provider = next(
        (p for p in ("claude", "codex", "gemini") if p in results), None
    )
    if synth_provider is None:
        print("error: no provider available to synthesize", file=sys.stderr)
        timeline.close()
        return 1

    timeline.step(f"2/2 — SYNTHESIS via {synth_provider} (best-of)")
    print(f"[2/2] Synthesis via {synth_provider} -> {out_dir}/02-synthesis.md")
    synth_input = render(
        SYNTHESIS_MULTI_PROVIDER_PROMPT,
        CONTEXT=ctx_for_template,
        ORIGINAL=original_prompt,
        CLAUDE=extracted.get("claude", "(provider not run)"),
        CODEX=extracted.get("codex", "(provider not run)"),
        GEMINI=extracted.get("gemini", "(provider not run)"),
    )
    present = [p for p in PROVIDERS if p in extracted]
    timeline.event(
        f"template SYNTHESIS_MULTI_PROVIDER_PROMPT rendered "
        f"(present: {present}, missing: {[p for p in PROVIDERS if p not in present]})"
    )
    timeline.kv("rendered input chars", len(synth_input))

    try:
        synth_response = run_provider(
            synth_provider,
            synth_input,
            model,
            out_dir / "02-synthesis.log",
            timeline=timeline,
            stage_label=f"STAGE 2 (synthesis via {synth_provider})",
        )
    except Exception as exc:
        timeline.event(f"STAGE 2 — ABORTED: {exc}")
        timeline.close()
        raise

    _write_text_0600(out_dir / "02-synthesis.md", synth_response)
    final_prompt = extract_prompt_block(synth_response)
    _write_text_0600(out_dir / "02-synthesis-prompt.txt", final_prompt)
    timeline.event(
        f"STAGE 2 — saved 02-synthesis.md + 02-synthesis-prompt.txt "
        f"({len(final_prompt)} chars)"
    )
    timeline.block("STAGE 2 — FINAL SYNTHESIZED PROMPT", final_prompt)

    print(f"\nDone. Final prompt: {out_dir}/02-synthesis-prompt.txt")
    timeline.close({
        "final prompt": str(out_dir / "02-synthesis-prompt.txt"),
        "mode": "all (fan-out + synthesis)",
        "synthesizer": synth_provider,
        "providers used": ", ".join(results),
        "providers failed": ", ".join(errors) or "(none)",
    })
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt_file", help="Path to the prompt to optimize, or '-' for stdin")
    parser.add_argument("--context", "-c", help="Path to a context file", default=None)
    parser.add_argument("--output-dir", "-o", default="output", help="Where to write artifacts")
    parser.add_argument(
        "--model", "-m", default=None,
        help="Model override for the chosen provider (passed as -m to codex, "
             "--model to claude, -m to gemini).",
    )
    parser.add_argument(
        "--provider", "-p",
        choices=list(PROVIDERS) + ["all", "ask"],
        default="ask",
        help="Which CLI to drive: claude, codex, gemini, all (parallel + "
             "synthesis), or ask (interactive menu on TTY; falls back to "
             "claude when stdin is not a TTY). Default: ask.",
    )
    parser.add_argument(
        "--multi-pass",
        action="store_true",
        help="Run legacy 3-stage pipeline (optimize -> external meta -> "
             "synthesis). Single-provider only; rejected with --provider all.",
    )
    parser.add_argument(
        "--log",
        action="store_true",
        help="Write a human-readable timeline log of every stage to "
             "logs/prompt-engineer-<timestamp>.log",
    )
    parser.add_argument(
        "--log-file",
        default=None,
        help="Explicit path for the --log timeline file. Implies --log.",
    )
    parser.add_argument(
        "--log-dir",
        default="logs",
        help="Directory for --log timeline files (default: ./logs).",
    )
    args = parser.parse_args()

    available = detect_providers()

    # Resolve provider
    provider = args.provider
    if provider == "ask":
        provider = pick_provider_interactive(available)

    if provider != "all" and provider in PROVIDERS and not available[provider]:
        print(
            f"error: `{provider}` CLI not found on PATH. "
            f"Install it or pass --provider {{claude|codex|gemini|all}}.",
            file=sys.stderr,
        )
        return 2
    if provider == "all" and not any(available.values()):
        print(
            "error: no provider CLIs found on PATH "
            "(need at least one of claude/codex/gemini).",
            file=sys.stderr,
        )
        return 2

    if args.multi_pass and provider == "all":
        print(
            "error: --multi-pass is incompatible with --provider all. "
            "Use --multi-pass with a single provider.",
            file=sys.stderr,
        )
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

    _write_text_0600(out_dir / "00-original.txt", original_prompt)
    if context:
        _write_text_0600(out_dir / "00-context.txt", context)

    ctx_for_template = context if context else "(none)"

    log_path: Optional[Path] = None
    if args.log_file:
        log_path = Path(args.log_file)
    elif args.log:
        log_path = Path(args.log_dir) / f"prompt-engineer-{stamp}.log"

    timeline = TimelineLogger(log_path)
    if provider == "all":
        mode = "all (fan-out + synthesis)"
    elif args.multi_pass:
        mode = f"multi-pass via {provider} (3 stages)"
    else:
        mode = f"single-pass via {provider} (1 stage)"

    if log_path:
        print(f"Timeline log -> {log_path}")
    timeline.section("CONFIGURATION")
    timeline.kv("mode", mode)
    timeline.kv("provider", provider)
    timeline.kv("provider availability", available)
    timeline.kv("prompt source", args.prompt_file)
    timeline.kv("prompt chars", len(original_prompt))
    timeline.kv("context source", args.context or "(none)")
    timeline.kv("context chars", len(context))
    timeline.kv("model override", args.model or "(provider default)")
    timeline.kv("output dir", str(out_dir))
    timeline.block("ORIGINAL PROMPT", original_prompt)
    if context:
        timeline.block("CONTEXT", context)

    if provider == "all":
        return run_all_mode(
            original_prompt=original_prompt,
            ctx_for_template=ctx_for_template,
            model=args.model,
            out_dir=out_dir,
            timeline=timeline,
            available=available,
        )

    # Single-provider path
    total_stages = 3 if args.multi_pass else 1
    label_prefix = f"STAGE 1 ({provider} optimize)"

    timeline.step(f"1/{total_stages} — OPTIMIZE via {provider} (built-in meta-pass)")
    print(f"[1/{total_stages}] Optimization via {provider} -> {out_dir}/01-optimized.md")
    v1_input = render(
        OPTIMIZER_PROMPT,
        CONTEXT=ctx_for_template,
        PROMPT_TO_IMPROVE=original_prompt,
    )
    timeline.event("template OPTIMIZER_PROMPT rendered with CONTEXT + PROMPT_TO_IMPROVE")
    timeline.kv("rendered input chars", len(v1_input))

    try:
        v1_response = run_provider(
            provider, v1_input, args.model, out_dir / "01-optimized.log",
            timeline=timeline, stage_label=label_prefix,
        )
    except Exception as exc:
        timeline.event(f"STAGE 1 — ABORTED: {exc}")
        timeline.close()
        raise

    _write_text_0600(out_dir / "01-optimized.md", v1_response)
    v1_prompt_only = extract_prompt_block(v1_response)
    _write_text_0600(out_dir / "01-optimized-prompt.txt", v1_prompt_only)
    timeline.event(
        f"STAGE 1 — extracted optimized prompt block ({len(v1_prompt_only)} chars) "
        f"-> 01-optimized-prompt.txt"
    )
    timeline.block("STAGE 1 — EXTRACTED OPTIMIZED PROMPT", v1_prompt_only)

    if not args.multi_pass:
        print(f"\nDone. Final prompt: {out_dir}/01-optimized-prompt.txt")
        timeline.close({
            "final prompt": str(out_dir / "01-optimized-prompt.txt"),
            "mode": mode,
        })
        return 0

    timeline.step(f"2/3 — EXTERNAL META-OPTIMIZATION via {provider}")
    print(f"[2/3] External meta-optimization via {provider} -> {out_dir}/02-meta.md")
    v2_input = render(
        EXTERNAL_META_PROMPT,
        CONTEXT=ctx_for_template,
        PROMPT_TO_IMPROVE=v1_prompt_only,
    )
    timeline.event("template EXTERNAL_META_PROMPT rendered with CONTEXT + V1")
    timeline.kv("rendered input chars", len(v2_input))

    try:
        v2_response = run_provider(
            provider, v2_input, args.model, out_dir / "02-meta.log",
            timeline=timeline, stage_label=f"STAGE 2 ({provider} meta)",
        )
    except Exception as exc:
        timeline.event(f"STAGE 2 — ABORTED: {exc}")
        timeline.close()
        raise

    _write_text_0600(out_dir / "02-meta.md", v2_response)
    v2_prompt_only = extract_prompt_block(v2_response)
    _write_text_0600(out_dir / "02-meta-prompt.txt", v2_prompt_only)
    timeline.event(
        f"STAGE 2 — extracted meta-optimized prompt ({len(v2_prompt_only)} chars) "
        f"-> 02-meta-prompt.txt"
    )
    timeline.block("STAGE 2 — EXTRACTED META-OPTIMIZED PROMPT", v2_prompt_only)

    timeline.step(f"3/3 — SYNTHESIS via {provider} (best-of original + V1 + V2)")
    print(f"[3/3] Synthesis via {provider} -> {out_dir}/03-final.md")
    synth_input = render(
        SYNTHESIS_PROMPT,
        CONTEXT=ctx_for_template,
        ORIGINAL=original_prompt,
        V1=v1_prompt_only,
        V2=v2_prompt_only,
    )
    timeline.event("template SYNTHESIS_PROMPT rendered with CONTEXT + ORIGINAL + V1 + V2")
    timeline.kv("rendered input chars", len(synth_input))

    try:
        final_response = run_provider(
            provider, synth_input, args.model, out_dir / "03-final.log",
            timeline=timeline, stage_label=f"STAGE 3 ({provider} synthesis)",
        )
    except Exception as exc:
        timeline.event(f"STAGE 3 — ABORTED: {exc}")
        timeline.close()
        raise

    _write_text_0600(out_dir / "03-final.md", final_response)
    final_prompt_only = extract_prompt_block(final_response)
    _write_text_0600(out_dir / "03-final-prompt.txt", final_prompt_only)
    timeline.event(
        f"STAGE 3 — extracted final synthesized prompt ({len(final_prompt_only)} chars) "
        f"-> 03-final-prompt.txt"
    )
    timeline.block("STAGE 3 — FINAL SYNTHESIZED PROMPT", final_prompt_only)

    print(f"\nDone. Final prompt: {out_dir}/03-final-prompt.txt")
    timeline.close({
        "final prompt": str(out_dir / "03-final-prompt.txt"),
        "mode": mode,
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
