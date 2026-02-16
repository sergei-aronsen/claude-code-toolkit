#!/usr/bin/env python3
"""
Supreme Council — Multi-AI Code Review Orchestrator

Sends implementation plans to Gemini and ChatGPT for independent review
before Claude Code starts coding.

Usage:
    python3 brain.py "Your implementation plan"
    brain "Your implementation plan"  (if alias configured)

Config: ~/.claude/council/config.json
"""

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

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/135.0.0.0 Safari/537.36"
)

GEMINI_SYSTEM = (
    "You are a ruthless senior architect. Review implementation plans "
    "for critical flaws, SOLID/DRY violations, security risks, and "
    "performance issues. Be brief and direct."
)

GPT_SYSTEM = (
    "You are a ruthless security and logic auditor. Find flaws that "
    "others miss. Focus on edge cases, race conditions, injection "
    "vectors, and logic errors. Be brief and direct."
)


def load_config():
    """Load config from file with env var overrides."""
    if not CONFIG_PATH.exists():
        print(f"\n\u274c Config not found: {CONFIG_PATH}")
        print("Run setup first:")
        print("  curl -sSL https://raw.githubusercontent.com/digitalplanetno/"
              "claude-code-toolkit/main/scripts/setup-council.sh | bash")
        sys.exit(1)

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        config = json.load(f)

    # Environment variables override config file
    if os.getenv("OPENAI_API_KEY"):
        config["openai"]["api_key"] = os.getenv("OPENAI_API_KEY")
    if os.getenv("GEMINI_API_KEY"):
        config["gemini"]["api_key"] = os.getenv("GEMINI_API_KEY")

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


def read_files(file_list):
    """Read requested files safely."""
    content = ""
    for file_path in file_list:
        file_path = file_path.strip().strip("'\"`)>")
        if not file_path or "/" not in file_path:
            continue
        # Basic path traversal protection
        resolved = Path(file_path).resolve()
        cwd = Path.cwd().resolve()
        if not str(resolved).startswith(str(cwd)):
            print(f"\u26a0\ufe0f  Skipping path outside project: {file_path}")
            continue
        if resolved.exists() and resolved.is_file():
            try:
                text = resolved.read_text(encoding="utf-8", errors="replace")
                # Limit per-file size to avoid token explosion
                if len(text) > 20000:
                    text = text[:20000] + "\n... (truncated)"
                content += f"\n--- FILE: {file_path} ---\n{text}\n"
            except Exception as e:
                print(f"\u26a0\ufe0f  Could not read {file_path}: {e}")
        else:
            print(f"\u26a0\ufe0f  File not found: {file_path}")
    return content


# ─────────────────────────────────────────────────
# Gemini integration
# ─────────────────────────────────────────────────

def ask_gemini_cli(prompt, model):
    """Query Gemini via CLI (stdin pipe)."""
    return run_command(
        ["gemini", "--model", model],
        input_text=prompt,
        timeout=120
    )


def ask_gemini_api(prompt, model, api_key):
    """Query Gemini via REST API using curl."""
    if not api_key:
        return "Error: Gemini API key not set (check config or GEMINI_API_KEY env)"

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

    tmp = None
    try:
        tmp = tempfile.NamedTemporaryFile(
            mode="w", delete=False, suffix=".json", prefix="council_"
        )
        json.dump(payload, tmp, ensure_ascii=False)
        tmp.close()

        result = run_command([
            "curl", "-s",
            "-H", "Content-Type: application/json",
            "-H", f"User-Agent: {USER_AGENT}",
            "-d", f"@{tmp.name}",
            url
        ], timeout=120)

        try:
            data = json.loads(result)
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (json.JSONDecodeError, KeyError, IndexError):
            return f"Gemini API error: {result[:500]}"
    finally:
        if tmp and os.path.exists(tmp.name):
            os.unlink(tmp.name)


def ask_gemini(prompt, config):
    """Route to CLI or API based on config."""
    mode = config["gemini"].get("mode", "cli")
    model = config["gemini"]["model"]

    if mode == "cli":
        return ask_gemini_cli(prompt, model)
    return ask_gemini_api(prompt, model, config["gemini"].get("api_key", ""))


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

    tmp = None
    try:
        tmp = tempfile.NamedTemporaryFile(
            mode="w", delete=False, suffix=".json", prefix="council_"
        )
        json.dump(payload, tmp, ensure_ascii=False)
        tmp.close()

        result = run_command([
            "curl", "-s",
            "https://api.openai.com/v1/chat/completions",
            "-H", "Content-Type: application/json",
            "-H", f"Authorization: Bearer {api_key}",
            "-H", f"User-Agent: {USER_AGENT}",
            "-d", f"@{tmp.name}"
        ], timeout=120)

        try:
            data = json.loads(result)
            return data["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError):
            return f"OpenAI API error: {result[:500]}"
    finally:
        if tmp and os.path.exists(tmp.name):
            os.unlink(tmp.name)


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
    if files_to_read and "/" in files_to_read and not files_to_read.startswith("Error"):
        file_list = [f.strip() for f in files_to_read.replace("\n", ",").split(",")]
        print(f"\U0001f4c2 Reading {len(file_list)} file(s)...")
        files_content = read_files(file_list)

    # ── Phase 2: Architectural Audit (Gemini) ──
    print("\U0001f9e8 [Gemini]: Deep architectural audit...")

    audit_prompt = f"""{GEMINI_SYSTEM}

FILES CONTEXT:
{files_content if files_content else "(no files read)"}

IMPLEMENTATION PLAN:
{plan}

Perform a thorough architectural review:
1. SOLID/DRY violations
2. Security risks (injection, auth bypass, data exposure)
3. Performance concerns (N+1 queries, missing indexes, memory leaks)
4. Edge cases and race conditions
5. Missing error handling

End with: VERDICT: APPROVED or REJECTED with specific reasons."""

    gemini_verdict = ask_gemini(audit_prompt, config)

    # ── Phase 3: Second Opinion (ChatGPT) ──
    print("\U0001f6e1\ufe0f  [ChatGPT]: Security and logic audit...")

    gpt_prompt = f"""Verify this implementation plan and Gemini's architectural critique.
Find what the architect missed. Focus on:
1. Security vulnerabilities
2. Logic errors and edge cases
3. Race conditions
4. Missing validation
5. Alternative approaches

PLAN:
{plan}

GEMINI'S CRITIQUE:
{gemini_verdict}

End with: VERDICT: APPROVED or REJECTED with specific reasons."""

    gpt_verdict = ask_chatgpt(gpt_prompt, config)

    # ── Phase 4: Final Report ──
    print("\n" + "=" * 60)
    print("\U0001f4cb SUPREME COUNCIL FINAL REPORT")
    print("=" * 60)
    print(f"\n\U0001f3db\ufe0f  ARCHITECT (Gemini {config['gemini']['model']}):")
    print(gemini_verdict)
    print(f"\n\U0001f575\ufe0f  CRITIC (ChatGPT {config['openai']['model']}):")
    print(gpt_verdict)
    print("\n" + "=" * 60)

    # Determine overall status
    gemini_rejected = "REJECTED" in gemini_verdict.upper() if gemini_verdict else False
    gpt_rejected = "REJECTED" in gpt_verdict.upper() if gpt_verdict else False

    if gemini_rejected or gpt_rejected:
        print("\u274c STATUS: PLAN REJECTED. Fix the issues before coding.")
        status = "REJECTED"
    else:
        print("\u2705 STATUS: PLAN APPROVED. Proceed with implementation.")
        status = "APPROVED"

    print("=" * 60 + "\n")

    # Save report to scratchpad
    scratchpad = Path.cwd() / ".claude" / "scratchpad"
    scratchpad.mkdir(parents=True, exist_ok=True)
    report_path = scratchpad / "council-report.md"

    report = f"""# Supreme Council Review Report

## Decision: {status}

---

## Architect Review (Gemini {config['gemini']['model']})

{gemini_verdict}

---

## Critic Review (ChatGPT {config['openai']['model']})

{gpt_verdict}

---

## Next Steps

- **APPROVED** — proceed with implementation
- **REJECTED** — fix the issues listed above, then re-run `/council`
"""

    report_path.write_text(report, encoding="utf-8")
    print(f"Report saved: {report_path}")


if __name__ == "__main__":
    main()
