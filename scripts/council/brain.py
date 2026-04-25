#!/usr/bin/env python3
"""
Supreme Council — Multi-AI Hypothesis Validation Orchestrator

Runs a sequential review pipeline:
  1. Gemini reads project context and lists files relevant to the plan.
  2. Gemini (The Skeptic) renders a verdict on whether the plan is justified.
  3. ChatGPT (The Pragmatist) evaluates production readiness, given the
     plan AND the Skeptic's verdict.

Phases run in series (each call may take up to 120s). The Pragmatist depends
on the Skeptic's output, so full parallelism is not possible without changing
the prompt design.

Usage:
    python3 brain.py "Your implementation plan"
    brain "Your implementation plan"  (if alias configured)

Config: ~/.claude/council/config.json
"""

import re
import shutil
import subprocess
import sys
import os
import json
import tempfile
from pathlib import Path

# ─────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────

CONFIG_PATH = Path.home() / ".claude" / "council" / "config.json"

TREE_EXCLUDE = "node_modules|dist|.git|__pycache__|env|venv|vendor|.next|.nuxt|tmp|log"

MAX_TOTAL_CONTEXT = 200000  # 200K characters total file context limit
MAX_GIT_DIFF = 30000        # 30K characters git diff limit
MAX_PROJECT_RULES = 10000   # 10K characters CLAUDE.md limit

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/135.0.0.0 Safari/537.36"
)

GEMINI_SYSTEM = (
    "You are The Skeptic — a senior engineer who questions whether things "
    "should be built at all. Your job is NOT to find bugs or SOLID violations — "
    "Claude Code already does that. Your job is to challenge whether the proposed "
    "approach is justified, whether it's overengineered, and whether a simpler "
    "solution exists. Be brief and direct."
)

GPT_SYSTEM = (
    "You are The Pragmatist — a battle-scarred production engineer. Your job is "
    "NOT to find bugs or security issues — Claude Code already does that. Your job "
    "is to evaluate whether this plan will actually work in production, what the "
    "long-term maintenance cost is, and whether there's proven prior art that "
    "solves this better. Be brief and direct."
)

VERDICTS = {
    "PROCEED": "Plan is justified and well-scoped. Go ahead.",
    "SIMPLIFY": "Core idea is valid, but the approach is overcomplicated. Reduce scope.",
    "RETHINK": "The problem is real, but the solution is wrong. Try a different approach.",
    "SKIP": "This doesn't need to be done. The cost outweighs the benefit.",
}

VERDICT_PRIORITY = ["SKIP", "RETHINK", "SIMPLIFY", "PROCEED"]


ERROR_PREFIXES = (
    "Error:",
    "Error (exit",
    "Gemini API error",
    "OpenAI API error",
)


def is_error_response(text):
    """True when the reviewer call returned an error string instead of a real verdict."""
    if not text:
        return True
    return any(text.startswith(p) for p in ERROR_PREFIXES)


def extract_verdict(text):
    """Extract verdict from reviewer response.

    Audit BRAIN-M1: the original full-text fallback would scan every word for
    `SKIP|RETHINK|SIMPLIFY|PROCEED` in priority order. If the model echoed the
    prompt (which contains "- SKIP — this doesn't need to be done"), the
    fallback latched onto `SKIP` and returned the wrong verdict. Restrict the
    fallback to the last 500 characters where the verdict line normally lives.
    """
    if not text:
        return "RETHINK"
    upper = text.upper()
    # First: look for explicit "VERDICT: <word>" pattern.
    match = re.search(r"VERDICT:\s*(PROCEED|SIMPLIFY|RETHINK|SKIP)", upper)
    if match:
        return match.group(1)
    # Fallback: scan only the last 500 chars (verdict line typically at end).
    tail = upper[-500:]
    for verdict in VERDICT_PRIORITY:
        if verdict in tail:
            return verdict
    return "RETHINK"


def sanitize_error(text, config):
    """Remove API keys from error output to prevent leaks."""
    for provider in ("gemini", "openai"):
        key = config.get(provider, {}).get("api_key", "")
        if key and len(key) >= 4:
            text = text.replace(key, key[:4] + "***")
    return text


def load_config():
    """Load config from file with env var overrides."""
    if not CONFIG_PATH.exists():
        print(f"\n\u274c Config not found: {CONFIG_PATH}")
        print("Run setup first:")
        print("  curl -sSL https://raw.githubusercontent.com/sergei-aronsen/"
              "claude-code-toolkit/main/scripts/setup-council.sh | bash")
        sys.exit(1)

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        config = json.load(f)

    # Validate required config structure
    for key in ("gemini", "openai"):
        if key not in config or "model" not in config.get(key, {}):
            print(f"\n\u274c Invalid config: missing '{key}.model' in {CONFIG_PATH}")
            sys.exit(1)

    # Environment variables override config file
    if os.getenv("OPENAI_API_KEY"):
        config["openai"]["api_key"] = os.getenv("OPENAI_API_KEY")
    if os.getenv("GEMINI_API_KEY"):
        config["gemini"]["api_key"] = os.getenv("GEMINI_API_KEY")

    # Audit BRAIN-M5: when the user picked CLI mode for Gemini, fail fast
    # with an actionable error instead of letting the missing binary
    # surface ~120s later as a phantom "RETHINK" verdict.
    if config["gemini"].get("mode", "cli") == "cli" and shutil.which("gemini") is None:
        print("\n\u274c Gemini CLI mode selected but 'gemini' is not in PATH.")
        print("   Install: npm install -g @google/gemini-cli")
        print(f"   Or switch to API mode by editing {CONFIG_PATH}")
        sys.exit(1)

    if not config["openai"].get("api_key"):
        print("\n\u274c OpenAI API key not configured.")
        print(f"   Set OPENAI_API_KEY env var or edit {CONFIG_PATH}")
        sys.exit(1)

    return config


def validate_plan(plan):
    """Validate plan input."""
    if not plan or len(plan.strip()) < 10:
        print("\n\u274c Plan too short (minimum 10 characters)")
        print("Usage: brain \"Your detailed implementation plan\"")
        sys.exit(1)
    if len(plan) > 100000:
        print("\n\u274c Plan too long (maximum 100K characters)")
        sys.exit(1)


# ─────────────────────────────────────────────────
# Safe command execution
# ─────────────────────────────────────────────────

def run_command(cmd_list, input_text=None, timeout=60):
    """Execute a command safely (no shell=True)."""
    try:
        process = subprocess.run(
            cmd_list,
            input=input_text,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=timeout
        )
        if process.returncode != 0:
            return f"Error (exit {process.returncode}): {process.stderr.strip()}"
        return process.stdout.strip()
    except subprocess.TimeoutExpired:
        return "Error: command timed out"
    except FileNotFoundError:
        return f"Error: command not found: {cmd_list[0]}"
    except Exception as e:
        return f"Error: {e}"


# ─────────────────────────────────────────────────
# Project context
# ─────────────────────────────────────────────────

def get_project_structure():
    """Get project structure using tree command."""
    result = run_command(
        ["tree", "-L", "3", "-I", TREE_EXCLUDE],
        timeout=10
    )
    if result.startswith("Error: command not found"):
        print("\u26a0\ufe0f  tree not found. Install: brew install tree")
        return "(tree not available)"
    return result


def validate_file_path(file_path):
    """Validate and resolve a file path safely. Returns resolved Path or None.

    Audit BRAIN-H2: previous implementation rejected bare filenames like
    `Makefile` (no `/`) and the project root itself (string-prefix check
    excluded `cwd` exactly). Path.relative_to() handles both correctly.
    """
    file_path = file_path.strip().strip("'\"`)>")
    if not file_path:
        return None
    cwd = Path.cwd().resolve()
    try:
        resolved = (cwd / file_path).resolve()
        resolved.relative_to(cwd)
    except (ValueError, OSError):
        print(f"\u26a0\ufe0f  Skipping path outside project: {file_path}")
        return None
    if not resolved.is_file():
        print(f"\u26a0\ufe0f  File not found: {file_path}")
        return None
    return resolved


def read_files(file_list):
    """Read requested files safely with total context limit."""
    content = ""
    total_size = 0
    for file_path in file_list:
        resolved = validate_file_path(file_path)
        if not resolved:
            continue
        if total_size >= MAX_TOTAL_CONTEXT:
            print(f"\u26a0\ufe0f  Context limit reached ({MAX_TOTAL_CONTEXT} chars), skipping remaining files")
            break
        try:
            text = resolved.read_text(encoding="utf-8", errors="replace")
            if len(text) > 20000:
                text = text[:20000] + "\n... (truncated)"
            remaining = MAX_TOTAL_CONTEXT - total_size
            if len(text) > remaining:
                text = text[:remaining] + "\n... (context limit reached)"
            content += f"\n--- FILE: {file_path} ---\n{text}\n"
            total_size += len(text)
        except Exception as e:
            print(f"\u26a0\ufe0f  Could not read {file_path}: {e}")
    return content


def get_validated_paths(file_list):
    """Get list of validated file paths for @file usage."""
    paths = []
    for file_path in file_list:
        resolved = validate_file_path(file_path)
        if resolved:
            paths.append(str(resolved))
    return paths


def get_git_diff():
    """Get git diff (staged + unstaged) for context."""
    result = run_command(["git", "diff", "HEAD"], timeout=10)
    if result.startswith("Error") or not result:
        return ""
    if len(result) > MAX_GIT_DIFF:
        result = result[:MAX_GIT_DIFF] + "\n... (diff truncated)"
    return result


def get_project_rules():
    """Read CLAUDE.md from project root if it exists."""
    claude_md = Path.cwd() / "CLAUDE.md"
    if not claude_md.exists():
        return ""
    try:
        text = claude_md.read_text(encoding="utf-8", errors="replace")
        if len(text) > MAX_PROJECT_RULES:
            text = text[:MAX_PROJECT_RULES] + "\n... (truncated)"
        return text
    except Exception:
        return ""


# ─────────────────────────────────────────────────
# Gemini integration
# ─────────────────────────────────────────────────

def ask_gemini_cli(prompt, model, file_paths=None):
    """Query Gemini via CLI (stdin pipe). Supports @file for native file reading."""
    if file_paths:
        file_refs = "\n".join(f"@{p}" for p in file_paths)
        prompt = f"{file_refs}\n\n{prompt}"
    return run_command(
        ["gemini", "--model", model],
        input_text=prompt,
        timeout=120
    )


def ask_gemini_api(prompt, model, api_key, config=None):
    """Query Gemini via REST API using curl."""
    if not api_key:
        return "Error: Gemini API key not set (check config or GEMINI_API_KEY env)"

    # Note: Gemini API requires key in URL query parameter (Google API design).
    # The key may appear in server/proxy logs. Use env vars and rotate keys regularly.
    url = (f"https://generativelanguage.googleapis.com/v1beta/"
           f"models/{model}:generateContent?key={api_key}")

    payload = {
        "contents": [{
            "parts": [{"text": prompt}]
        }],
        "generationConfig": {
            "temperature": 0.2
        }
    }

    # Audit BRAIN-H3: pass JSON via stdin instead of a tempfile so the full
    # prompt (which can include 200K chars of project source) doesn't sit on
    # disk between processes — `finally` doesn't run on SIGKILL, so a hard
    # interrupt would leak tempfiles in /tmp.
    body = json.dumps(payload, ensure_ascii=False)
    result = run_command([
        "curl", "-s",
        "-H", "Content-Type: application/json",
        "-H", f"User-Agent: {USER_AGENT}",
        "--data-binary", "@-",
        url
    ], input_text=body, timeout=120)

    try:
        data = json.loads(result)
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (json.JSONDecodeError, KeyError, IndexError):
        error = f"Gemini API error: {result[:500]}"
        return sanitize_error(error, config) if config else error


def ask_gemini(prompt, config, file_paths=None):
    """Route to CLI or API based on config."""
    mode = config["gemini"].get("mode", "cli")
    model = config["gemini"]["model"]

    if mode == "cli":
        return ask_gemini_cli(prompt, model, file_paths=file_paths)
    return ask_gemini_api(prompt, model, config["gemini"].get("api_key", ""), config=config)


# ─────────────────────────────────────────────────
# ChatGPT integration (curl-only, no pip deps)
# ─────────────────────────────────────────────────

def ask_chatgpt(prompt, config):
    """Query ChatGPT via OpenAI API using curl."""
    api_key = config["openai"].get("api_key", "")
    model = config["openai"]["model"]

    if not api_key:
        return "Error: OpenAI API key not set (check config or OPENAI_API_KEY env)"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": GPT_SYSTEM},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.2
    }

    # Audit BRAIN-H4: write the Authorization header to a 0600 tempfile and
    # pass via `-H @file` so the API key never appears in `ps`/argv. Audit
    # BRAIN-H3: send the body via stdin so the full prompt isn't persisted.
    hdr = tempfile.NamedTemporaryFile(
        mode="w", delete=False, prefix="council_hdr_", suffix=".txt"
    )
    try:
        os.chmod(hdr.name, 0o600)
        hdr.write(
            f"Authorization: Bearer {api_key}\n"
            f"Content-Type: application/json\n"
            f"User-Agent: {USER_AGENT}\n"
        )
        hdr.close()

        body = json.dumps(payload, ensure_ascii=False)
        result = run_command([
            "curl", "-s",
            "https://api.openai.com/v1/chat/completions",
            "-H", f"@{hdr.name}",
            "--data-binary", "@-"
        ], input_text=body, timeout=120)

        try:
            data = json.loads(result)
            return data["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError):
            return sanitize_error(f"OpenAI API error: {result[:500]}", config)
    finally:
        if os.path.exists(hdr.name):
            os.unlink(hdr.name)


# ─────────────────────────────────────────────────
# Main orchestration
# ─────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 brain.py \"Your implementation plan\"")
        print("       brain \"Your implementation plan\"")
        sys.exit(1)

    plan = sys.argv[1]
    validate_plan(plan)
    config = load_config()

    project_map = get_project_structure()
    git_diff = get_git_diff()
    project_rules = get_project_rules()

    # Build shared context blocks
    diff_block = f"\nGIT CHANGES:\n{git_diff}" if git_diff else ""
    rules_block = f"\nPROJECT RULES (CLAUDE.md):\n{project_rules}" if project_rules else ""

    # ── Phase 1: Context Discovery ──
    print("\n\U0001f9e0 [Gemini]: Analyzing project structure...")

    context_prompt = f"""{GEMINI_SYSTEM}

Review the project structure and the implementation plan.

PROJECT STRUCTURE:
{project_map}

PLAN: {plan}

List the file paths (comma-separated) that are critical to review for this plan.
Reply ONLY with the comma-separated list of file paths. No explanations."""

    files_to_read = ask_gemini(context_prompt, config)

    files_content = ""
    file_paths = []
    if files_to_read and "/" in files_to_read and not files_to_read.startswith("Error"):
        file_list = [f.strip() for f in files_to_read.replace("\n", ",").split(",")]
        print(f"\U0001f4c2 Reading {len(file_list)} file(s)...")
        file_paths = get_validated_paths(file_list)
        files_content = read_files(file_list)

    # ── Phase 2: The Skeptic (Gemini) ──
    print("\U0001f9d0 [The Skeptic]: Challenging plan justification...")

    # In CLI mode, Gemini reads files natively via @file (no content in prompt)
    use_native_files = config["gemini"].get("mode", "cli") == "cli" and file_paths
    files_in_prompt = "" if use_native_files else (files_content if files_content else "(no files read)")

    skeptic_prompt = f"""{GEMINI_SYSTEM}
{rules_block}

FILES CONTEXT:
{files_in_prompt}
{diff_block}

IMPLEMENTATION PLAN:
{plan}

Evaluate this plan using the following structure:

## Problem Assessment
Is this solving a real problem? What evidence supports the need for this change?

## Simplicity Check
What is the simplest thing that could work? Is the proposed approach the simplest, or is it overengineered?

## Do-Nothing Analysis
What happens if we don't do this at all? What's the actual cost of inaction?

## Concerns (max 3)
List up to 3 concerns, ranked by impact. Skip trivial issues — Claude Code handles linting, SOLID, and basic security.

## Verdict
End with exactly one of: VERDICT: PROCEED / SIMPLIFY / RETHINK / SKIP
- PROCEED — plan is justified and well-scoped
- SIMPLIFY — core idea is valid, but approach is overcomplicated
- RETHINK — the problem is real, but the solution is wrong
- SKIP — this doesn't need to be done"""

    gemini_verdict = ask_gemini(
        skeptic_prompt, config,
        file_paths=file_paths if use_native_files else None
    )

    # ── Phase 3: The Pragmatist (ChatGPT) ──
    print("\U0001f528 [The Pragmatist]: Evaluating production readiness...")

    pragmatist_prompt = f"""Review this implementation plan and The Skeptic's assessment.
Do NOT repeat The Skeptic's points. Focus on what they missed or got wrong.
{rules_block}

FILES CONTEXT:
{files_content if files_content else "(no files read)"}
{diff_block}

PLAN:
{plan}

THE SKEPTIC'S ASSESSMENT:
{gemini_verdict}

Evaluate using this structure:

## Production Readiness
Will this actually work in production? What operational risks exist?

## Maintenance Forecast
What's the long-term maintenance cost? Will the next developer understand this?

## Alternative Approaches
Is there proven prior art that solves this better? A library, pattern, or simpler architecture?

## Agreement with Skeptic
Where do you agree/disagree with The Skeptic's assessment? Be specific.

## Verdict
End with exactly one of: VERDICT: PROCEED / SIMPLIFY / RETHINK / SKIP
- PROCEED — plan is justified and well-scoped
- SIMPLIFY — core idea is valid, but approach is overcomplicated
- RETHINK — the problem is real, but the solution is wrong
- SKIP — this doesn't need to be done"""

    gpt_verdict = ask_chatgpt(pragmatist_prompt, config)

    # ── Phase 4: Final Report ──
    # Audit BRAIN-M2: surface infrastructure failures explicitly. Previously,
    # an API timeout / missing CLI / 5xx response would degrade silently to
    # a phantom "RETHINK" verdict via extract_verdict's fallback. The user
    # had no signal whether the model rendered an opinion or the call failed.
    skeptic_failed = is_error_response(gemini_verdict)
    pragmatist_failed = is_error_response(gpt_verdict)
    if skeptic_failed and pragmatist_failed:
        print("\n\u274c Both reviewers failed — cannot render a verdict:")
        print(f"   Skeptic (Gemini):    {gemini_verdict}")
        print(f"   Pragmatist (ChatGPT): {gpt_verdict}")
        sys.exit(2)
    if skeptic_failed:
        print(f"\n\u26a0\ufe0f  Skeptic (Gemini) call failed: {gemini_verdict}")
        print("   Continuing with Pragmatist verdict only.")
    if pragmatist_failed:
        print(f"\n\u26a0\ufe0f  Pragmatist (ChatGPT) call failed: {gpt_verdict}")
        print("   Continuing with Skeptic verdict only.")

    skeptic_decision = extract_verdict(gemini_verdict)
    pragmatist_decision = extract_verdict(gpt_verdict)

    # More conservative verdict wins. When one reviewer failed, fall back to
    # the surviving reviewer's verdict instead of letting the failure's
    # "RETHINK" fallback bias the result.
    if skeptic_failed and not pragmatist_failed:
        final_verdict = pragmatist_decision
    elif pragmatist_failed and not skeptic_failed:
        final_verdict = skeptic_decision
    else:
        skeptic_rank = VERDICT_PRIORITY.index(skeptic_decision)
        pragmatist_rank = VERDICT_PRIORITY.index(pragmatist_decision)
        final_verdict = VERDICT_PRIORITY[min(skeptic_rank, pragmatist_rank)]

    print("\n" + "=" * 60)
    print("\U0001f4cb SUPREME COUNCIL REPORT")
    print("=" * 60)
    print(f"\n\U0001f9d0 THE SKEPTIC (Gemini {config['gemini']['model']}):")
    print(gemini_verdict)
    print(f"\n\U0001f528 THE PRAGMATIST (ChatGPT {config['openai']['model']}):")
    print(gpt_verdict)
    print("\n" + "-" * 60)
    print(f"  Skeptic:    {skeptic_decision}")
    print(f"  Pragmatist: {pragmatist_decision}")
    print(f"  Final:      {final_verdict} — {VERDICTS[final_verdict]}")
    print("-" * 60)

    verdict_icons = {
        "PROCEED": "\u2705",
        "SIMPLIFY": "\U0001f4a1",
        "RETHINK": "\U0001f504",
        "SKIP": "\u26d4",
    }
    print(f"\n{verdict_icons[final_verdict]} VERDICT: {final_verdict}")
    print("=" * 60 + "\n")

    # Save report to scratchpad
    scratchpad = Path.cwd() / ".claude" / "scratchpad"
    scratchpad.mkdir(parents=True, exist_ok=True)
    report_path = scratchpad / "council-report.md"

    report = f"""# Supreme Council Review Report

## Verdict: {final_verdict}

> {VERDICTS[final_verdict]}

| Reviewer | Verdict |
|----------|---------|
| Skeptic (Gemini) | {skeptic_decision} |
| Pragmatist (ChatGPT) | {pragmatist_decision} |
| **Final** | **{final_verdict}** |

---

## The Skeptic (Gemini {config['gemini']['model']})

{gemini_verdict}

---

## The Pragmatist (ChatGPT {config['openai']['model']})

{gpt_verdict}

---

## What To Do Next

- **PROCEED** — plan is justified. Start implementation.
- **SIMPLIFY** — reduce scope or complexity, then re-run `/council`.
- **RETHINK** — try a different approach entirely, then re-run `/council`.
- **SKIP** — don't do this. Move on to something else.
"""

    report_path.write_text(report, encoding="utf-8")
    print(f"Report saved: {report_path}")


if __name__ == "__main__":
    main()
