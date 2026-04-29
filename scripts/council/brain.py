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

import argparse
import re
import shutil
import subprocess
import sys
import os
import json
import tempfile
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from pathlib import Path

# ─────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────

CONFIG_PATH = Path.home() / ".claude" / "council" / "config.json"

TREE_EXCLUDE = "node_modules|dist|.git|__pycache__|env|venv|vendor|.next|.nuxt|tmp|log"

MAX_TOTAL_CONTEXT = 200000  # 200K characters total file context limit
MAX_GIT_DIFF = 30000        # 30K characters git diff limit
MAX_PROJECT_RULES = 10000   # 10K characters CLAUDE.md limit
MAX_README = 10000          # 10K characters README.md limit (Phase 24 SP3)
MAX_RECENT_LOG = 5000       # 5K characters git log -20 limit (SP3)
MAX_TODOS = 5000            # 5K characters TODO/FIXME grep limit (SP3)
MAX_PLANNING = 10000        # 10K characters .planning/PROJECT.md limit (SP3)


def _debug(msg):
    """Emit a stderr trace line when COUNCIL_DEBUG=1 is set.

    Used by SP3 context-enrichment helpers so users running
    `COUNCIL_DEBUG=1 brain "..."` can verify which blocks fed into the
    Skeptic / Pragmatist prompts and see redaction counts.
    """
    if os.environ.get("COUNCIL_DEBUG") == "1":
        print(f"[council:debug] {msg}", file=sys.stderr)

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

AUDIT_REVIEW_GEMINI_SYSTEM = (
    "You are a senior code reviewer evaluating a structured audit report. "
    "Your job is to confirm whether each reported finding is REAL, "
    "FALSE_POSITIVE, or NEEDS_MORE_CONTEXT — using only the verbatim code "
    "embedded in the report. DO NOT reclassify severity. Cite tokens from "
    "the embedded code blocks in every justification. Output exactly the "
    "bracketed <verdict-table> and <missed-findings> blocks per the prompt."
)

AUDIT_REVIEW_GPT_SYSTEM = (
    "You are a battle-scarred production engineer reviewing a structured "
    "audit report. Your job is to confirm whether each reported finding is "
    "REAL, FALSE_POSITIVE, or NEEDS_MORE_CONTEXT — using only the verbatim "
    "code embedded in the report. DO NOT reclassify severity. Cite tokens "
    "from the embedded code blocks in every justification. Output exactly "
    "the bracketed <verdict-table> and <missed-findings> blocks per the prompt."
)

# ─────────────────────────────────────────────────
# Externalized system prompts (Phase 24 Sub-Phase 2)
# ─────────────────────────────────────────────────
#
# The four system prompts above (GEMINI_SYSTEM, GPT_SYSTEM, AUDIT_REVIEW_*) are
# editable as files under ~/.claude/council/prompts/. load_prompt() reads them
# at first use and caches the contents per process. The embedded constants act
# as a self-contained fallback so brain.py keeps working before any installer
# has populated the prompts directory (first-run case).

PROMPTS_DIR = Path.home() / ".claude" / "council" / "prompts"

PROMPT_FALLBACKS = {
    "skeptic-system": GEMINI_SYSTEM,
    "pragmatist-system": GPT_SYSTEM,
    "audit-review-skeptic": AUDIT_REVIEW_GEMINI_SYSTEM,
    "audit-review-pragmatist": AUDIT_REVIEW_GPT_SYSTEM,
}

_PROMPT_CACHE = {}


def load_prompt(name):
    """Return the system prompt body for `name`.

    Looks for `~/.claude/council/prompts/<name>.md` first; falls back to the
    embedded constant when the file is missing or unreadable. Cached per process
    so repeated `_run_validate_plan` phases don't re-read the file from disk.
    """
    if name in _PROMPT_CACHE:
        return _PROMPT_CACHE[name]
    path = PROMPTS_DIR / f"{name}.md"
    text = None
    try:
        if path.is_file():
            text = path.read_text(encoding="utf-8").strip()
    except OSError:
        text = None
    if not text:
        text = PROMPT_FALLBACKS.get(name, "")
    _PROMPT_CACHE[name] = text
    return text


# Council audit-review constants
COUNCIL_SLOT_PLACEHOLDER = "_pending — run /council audit-review_"  # U+2014 em-dash
COUNCIL_VERDICT_HEADER = "| ID | verdict | confidence | justification |"

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


# ─────────────────────────────────────────────────
# Council audit-review helpers (Phase 15)
# ─────────────────────────────────────────────────


def extract_block(text, tag):
    """Extract content between literal <tag> ... </tag> markers.

    Returns the stripped inner content, or None if the markers are absent.
    Used to parse <verdict-table> and <missed-findings> sections from
    backend output (D-10 — no fuzzy parsing).
    """
    if not text:
        return None
    pattern = rf'<{re.escape(tag)}>(.*?)</{re.escape(tag)}>'
    match = re.search(pattern, text, re.DOTALL)
    if match:
        return match.group(1).strip()
    return None


def parse_verdict_table(block_text):
    """Parse a markdown verdict table.

    Returns dict: { "F-001": {"verdict": "REAL", "confidence": 0.9,
                              "justification": "..."}, ... }

    Skips rows that fail to parse (header / separator rows / malformed).
    Does NOT raise — returns whatever rows parsed cleanly.
    """
    rows = {}
    if not block_text:
        return rows
    for line in block_text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")]
        # Pipe-delimited rows yield N+2 cells (leading/trailing empties)
        # Expected: ["", "F-001", "REAL", "0.9", "...", ""]
        if len(cells) < 6:
            continue
        finding_id = cells[1]
        if not finding_id.startswith("F-"):
            continue
        verdict = cells[2].upper()
        if verdict not in ("REAL", "FALSE_POSITIVE", "NEEDS_MORE_CONTEXT"):
            continue
        try:
            confidence = float(cells[3])
        except (ValueError, TypeError):
            confidence = 0.0
        justification = cells[4]
        rows[finding_id] = {
            "verdict": verdict,
            "confidence": confidence,
            "justification": justification,
        }
    return rows


def resolve_council_status(verdicts_g, verdicts_c):
    """Resolve per-finding agreements/disagreements into (status, rows).

    status in {"passed", "failed", "disputed"}.
    rows is a list of dicts with keys: id, verdict, confidence, justification.

    Per-finding rules (D-09):
      - both agree REAL              -> REAL,            confidence max(g,c)
      - both agree FALSE_POSITIVE    -> FALSE_POSITIVE,  confidence max(g,c)
      - both agree NEEDS_MORE_CONTEXT -> NEEDS_MORE_CONTEXT, confidence max(g,c)
      - any other combination        -> disputed,        confidence min(g,c),
                                        justification cites both backends

    Status rules:
      - "passed":   every row is REAL
      - "disputed": >=1 row is disputed
      - "failed":   else (>=1 FALSE_POSITIVE or NEEDS_MORE_CONTEXT, no disputes)
    """
    rows = []
    has_disputed = False
    has_non_real = False

    all_ids = sorted(set(verdicts_g.keys()) | set(verdicts_c.keys()))

    for fid in all_ids:
        g = verdicts_g.get(fid)
        c = verdicts_c.get(fid)

        if g is None and c is None:
            continue  # impossible by set construction; defensive
        if g is None or c is None:
            # One backend missing this finding ID -> disputed, low confidence
            present = g if g else c
            rows.append({
                "id": fid,
                "verdict": "disputed",
                "confidence": round(present["confidence"] / 2.0, 2),
                "justification": (
                    f"Only one backend produced a verdict for {fid}: "
                    f"{present['verdict']} ({present['confidence']}) — "
                    f"{present['justification']}"
                ),
            })
            has_disputed = True
            continue

        if g["verdict"] == c["verdict"]:
            verdict = g["verdict"]
            confidence = max(g["confidence"], c["confidence"])
            justification = (
                g["justification"]
                if len(g["justification"]) >= len(c["justification"])
                else c["justification"]
            )
            rows.append({
                "id": fid,
                "verdict": verdict,
                "confidence": round(confidence, 2),
                "justification": justification,
            })
            if verdict != "REAL":
                has_non_real = True
        else:
            confidence = min(g["confidence"], c["confidence"])
            justification = (
                f"Gemini: {g['verdict']} ({g['confidence']}) — {g['justification']}; "
                f"ChatGPT: {c['verdict']} ({c['confidence']}) — {c['justification']}"
            )
            # Truncate to <= 320 chars to avoid runaway justifications
            if len(justification) > 320:
                justification = justification[:317] + "..."
            rows.append({
                "id": fid,
                "verdict": "disputed",
                "confidence": round(confidence, 2),
                "justification": justification,
            })
            has_disputed = True

    if has_disputed:
        status = "disputed"
    elif has_non_real:
        status = "failed"
    elif rows:
        status = "passed"
    else:
        status = "failed"  # no rows — defensive

    return status, rows


def atomic_write_text(path, content):
    """Atomic file write: tempfile in same dir + os.replace.

    Atomic on POSIX same-filesystem (Python 3.3+). Pattern mirrors the
    header-tempfile precedent in ask_chatgpt() to keep brain.py's atomicity
    discipline consistent (BRAIN-H3/H4).
    """
    parent = Path(path).resolve().parent
    with tempfile.NamedTemporaryFile(
        mode="w",
        delete=False,
        dir=str(parent),
        suffix=".tmp",
        prefix=".council_",
        encoding="utf-8",
    ) as tmp:
        tmp.write(content)
        tmp_path = tmp.name
    os.replace(tmp_path, str(path))


def rewrite_report(report_path, status, verdict_text, missed_text):
    """Rewrite the audit report's Council slot + council_pass frontmatter in place.

    Locates the byte-exact slot string and replaces it with the assembled
    verdict block. Mutates council_pass: pending -> status (D-04, count=1,
    MULTILINE). Atomic via atomic_write_text. Other report sections are
    byte-identical post-rewrite.
    """
    path = Path(report_path)
    content = path.read_text(encoding="utf-8")

    # 1. Frontmatter mutation (anchored, single occurrence)
    content = re.sub(
        r'^council_pass: pending$',
        f'council_pass: {status}',
        content,
        count=1,
        flags=re.MULTILINE,
    )

    # 2. Slot rewrite (byte-exact str.replace)
    old_slot = f"## Council verdict\n\n{COUNCIL_SLOT_PLACEHOLDER}"
    if missed_text is None or missed_text.strip() == "":
        missed_block = "(none)"
    else:
        missed_block = missed_text
    new_slot = (
        "## Council verdict\n\n"
        + verdict_text.rstrip()
        + "\n\n"
        + "## Missed findings\n\n"
        + missed_block.rstrip()
    )
    if old_slot not in content:
        # Defensive: slot already replaced or report malformed — patch via regex
        new_slot_fallback = (
            "## Council verdict\n\n_Council parse error: slot placeholder not found in report._"
        )
        content = re.sub(
            r'^## Council verdict\b.*$',
            new_slot_fallback,
            content,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        content = content.replace(old_slot, new_slot, 1)

    atomic_write_text(path, content)


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

    # Audit BRAIN-M5 + Council pass C: pre-flight WARN per provider, fail
    # only if BOTH providers are unavailable. Single-reviewer Council is a
    # legitimate use case (e.g. user with only a Gemini CLI install).
    config["_gemini_available"] = True
    config["_openai_available"] = True

    if config["gemini"].get("mode", "cli") == "cli":
        if shutil.which("gemini") is None:
            print("\u26a0\ufe0f  Gemini CLI mode selected but 'gemini' is not in PATH.")
            print("   Install: npm install -g @google/gemini-cli")
            print(f"   Or switch to API mode by editing {CONFIG_PATH}")
            config["_gemini_available"] = False
    else:
        if not config["gemini"].get("api_key"):
            print("\u26a0\ufe0f  Gemini API mode selected but no api_key configured.")
            print(f"   Set GEMINI_API_KEY env var or edit {CONFIG_PATH}")
            config["_gemini_available"] = False

    if not config["openai"].get("api_key"):
        print("\u26a0\ufe0f  OpenAI API key not configured.")
        print(f"   Set OPENAI_API_KEY env var or edit {CONFIG_PATH}")
        config["_openai_available"] = False

    if not config["_gemini_available"] and not config["_openai_available"]:
        print("\n\u274c No reviewers available — aborting.")
        sys.exit(1)
    if not config["_gemini_available"]:
        print("   Continuing with Pragmatist (ChatGPT) only.\n")
    if not config["_openai_available"]:
        print("   Continuing with Skeptic (Gemini) only.\n")

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


def find_project_root():
    """Resolve the project root: nearest ancestor containing .git/, falling back to cwd.

    Council was previously fixed at Path.cwd() so running `brain "..."` from
    a subdirectory (e.g. ./src/components/) silently missed the project's
    CLAUDE.md. Walking up to .git/ finds the same root that git tools use,
    which is what users expect when they think "project rules".
    """
    cwd = Path.cwd().resolve()
    for candidate in [cwd, *cwd.parents]:
        if (candidate / ".git").exists():
            return candidate
    return cwd


def get_project_rules():
    """Read CLAUDE.md from project root if it exists."""
    claude_md = find_project_root() / "CLAUDE.md"
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
# Phase 24 Sub-Phase 3 — context enrichment helpers
# ─────────────────────────────────────────────────
#
# Each helper returns a string capped to its dedicated MAX_* constant so the
# total context budget stays predictable. _truncate() appends a visible marker
# that downstream readers (Skeptic, Pragmatist) can tell apart from real EOF.

def _truncate(text, limit, marker="(context truncated)"):
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n... {marker}"


def get_readme():
    """Read project README.md (capped at MAX_README)."""
    path = find_project_root() / "README.md"
    if not path.is_file():
        _debug("README.md: not found")
        return ""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        _debug(f"README.md: read failed ({exc})")
        return ""
    out = _truncate(text, MAX_README)
    _debug(f"README.md: {len(out)} chars (capped at {MAX_README})")
    return out


def get_recent_log():
    """Last 20 commits (`git log --oneline -20`), capped at MAX_RECENT_LOG."""
    result = run_command(
        ["git", "log", "--oneline", "-20"], timeout=10
    )
    if not result or result.startswith("Error"):
        _debug("git log: empty or error")
        return ""
    out = _truncate(result, MAX_RECENT_LOG)
    _debug(f"git log: {len(out)} chars (capped at {MAX_RECENT_LOG})")
    return out


def get_todos():
    """Grep TODO|FIXME|HACK|XXX markers across top-level source dirs.

    Skips vendored / generated paths. Uses git ls-files when available for an
    accurate file list (respects .gitignore); falls back to a recursive walk
    bounded by TREE_EXCLUDE.
    """
    root = find_project_root()
    skip_dirs = {
        "node_modules", "dist", ".git", "__pycache__", "env", "venv",
        "vendor", ".next", ".nuxt", "tmp", "log", ".planning",
    }
    pattern = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b")

    files = []
    listing = run_command(["git", "ls-files"], timeout=10)
    if listing and not listing.startswith("Error"):
        for rel in listing.splitlines():
            if not rel:
                continue
            parts = rel.split("/")
            if any(p in skip_dirs for p in parts):
                continue
            files.append(root / rel)
    else:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if any(p in skip_dirs for p in path.parts):
                continue
            files.append(path)

    hits = []
    total = 0
    for path in files:
        try:
            with path.open("r", encoding="utf-8", errors="replace") as fh:
                for lineno, line in enumerate(fh, start=1):
                    if pattern.search(line):
                        rel = path.relative_to(root)
                        snippet = line.rstrip()[:200]
                        hits.append(f"{rel}:{lineno}: {snippet}")
                        total += len(hits[-1]) + 1
                        if total >= MAX_TODOS:
                            break
        except (OSError, UnicodeDecodeError):
            continue
        if total >= MAX_TODOS:
            break

    if not hits:
        _debug("TODOs: 0 hits")
        return ""
    out = _truncate("\n".join(hits), MAX_TODOS)
    _debug(f"TODOs: {len(hits)} hits, {len(out)} chars")
    return out


def get_planning_context():
    """Read .planning/PROJECT.md if present (capped at MAX_PLANNING)."""
    path = find_project_root() / ".planning" / "PROJECT.md"
    if not path.is_file():
        _debug(".planning/PROJECT.md: not found")
        return ""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        _debug(f".planning/PROJECT.md: read failed ({exc})")
        return ""
    out = _truncate(text, MAX_PLANNING)
    _debug(f".planning/PROJECT.md: {len(out)} chars (capped at {MAX_PLANNING})")
    return out


def apply_context_budget(blocks, hard_limit=MAX_TOTAL_CONTEXT):
    """Truncate a list of (label, body) blocks proportionally to fit hard_limit.

    Returns the same list with `body` shrunk so the sum of len(body) <= hard_limit.
    Each shrunk block keeps a visible "(context truncated)" marker.
    """
    total = sum(len(body) for _, body in blocks)
    if total <= hard_limit:
        return blocks
    scale = hard_limit / total
    out = []
    for label, body in blocks:
        if not body:
            out.append((label, body))
            continue
        target = max(0, int(len(body) * scale) - 32)
        out.append((label, _truncate(body, target)))
    _debug(
        f"budget: total={total} > limit={hard_limit}; scaled by {scale:.2f}"
    )
    return out


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

    # Audit BRAIN-H4 (Gemini parity, 2026-04-28): write the API key to a 0600
    # tempfile and pass via `-H @file` so it never appears in `ps aux` /
    # /proc/<pid>/cmdline. Previously the key was inlined into the URL query
    # (?key=...) per Google's older docs — that exposed it in the curl argv to
    # any other user on a multi-user box or shared CI runner. The v1beta API
    # also accepts the `x-goog-api-key` header, which keeps the key off the
    # process command line. The ChatGPT path already uses this pattern.
    url = (f"https://generativelanguage.googleapis.com/v1beta/"
           f"models/{model}:generateContent")

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

    hdr = tempfile.NamedTemporaryFile(
        mode="w", delete=False, prefix="council_gemini_hdr_", suffix=".txt"
    )
    try:
        os.chmod(hdr.name, 0o600)
        hdr.write(
            f"Content-Type: application/json\n"
            f"User-Agent: {USER_AGENT}\n"
            f"x-goog-api-key: {api_key}\n"
        )
        hdr.close()

        result = run_command([
            "curl", "-s",
            "-H", f"@{hdr.name}",
            "--data-binary", "@-",
            url
        ], input_text=body, timeout=120)

        try:
            data = json.loads(result)
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (json.JSONDecodeError, KeyError, IndexError):
            error = f"Gemini API error: {result[:500]}"
            return sanitize_error(error, config) if config else error
    finally:
        if os.path.exists(hdr.name):
            os.unlink(hdr.name)


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

def ask_chatgpt(prompt, config, system_prompt=None):
    """Query ChatGPT via OpenAI API using curl.

    `system_prompt` overrides the default Pragmatist persona — used by
    audit-review mode to swap in AUDIT_REVIEW_GPT_SYSTEM (WR-01 fix).
    """
    api_key = config["openai"].get("api_key", "")
    model = config["openai"]["model"]

    if not api_key:
        return "Error: OpenAI API key not set (check config or OPENAI_API_KEY env)"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt or load_prompt("pragmatist-system")},
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
        # Council pass D: -f makes curl exit non-zero on HTTP 4xx/5xx so we
        # don't try to JSON-parse an HTML error page or empty body. Also -S
        # so we still get the status reason in the captured stderr.
        result = run_command([
            "curl", "-sSf",
            "https://api.openai.com/v1/chat/completions",
            "-H", f"@{hdr.name}",
            "--data-binary", "@-"
        ], input_text=body, timeout=120)

        if is_error_response(result):
            return sanitize_error(result, config)
        try:
            data = json.loads(result)
            return data["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError):
            return sanitize_error(f"OpenAI API error: {result[:500]}", config)
    finally:
        if os.path.exists(hdr.name):
            os.unlink(hdr.name)


# ─────────────────────────────────────────────────
# Council audit-review dispatch (Phase 15)
# ─────────────────────────────────────────────────


def dispatch_audit_review_gemini(prompt, config):
    """Gemini dispatch for audit-review mode.

    Honors COUNCIL_STUB_GEMINI env var (RESEARCH.md §5) — when set, the value
    is treated as a path to an executable script that emits canned <verdict-table>
    output on stdout. Used by scripts/tests/test-council-audit-review.sh.
    """
    stub = os.getenv("COUNCIL_STUB_GEMINI")
    if stub:
        return run_command([stub], timeout=30)
    return ask_gemini(prompt, config)


def dispatch_audit_review_chatgpt(prompt, config):
    """ChatGPT dispatch for audit-review mode.

    Honors COUNCIL_STUB_CHATGPT env var (RESEARCH.md §5).
    """
    stub = os.getenv("COUNCIL_STUB_CHATGPT")
    if stub:
        return run_command([stub], timeout=30)
    return ask_chatgpt(prompt, config, system_prompt=load_prompt("audit-review-pragmatist"))


def run_audit_review(report_path_str, config):
    """Run the Council audit-review mode against a structured audit report.

    Phase 15 entry point invoked by `--mode audit-review --report <path>`.
    Returns: 0 on success, 1 on malformed backend output / both backends failed.
    """
    # 1. Validate report path
    report_path = validate_file_path(report_path_str)
    if not report_path:
        print(f"\n❌ Audit report not found or outside project: {report_path_str}",
              file=sys.stderr)
        return 1

    report_content = report_path.read_text(encoding="utf-8")
    if COUNCIL_SLOT_PLACEHOLDER not in report_content:
        print(
            f"\n❌ Report does not contain the Council slot placeholder. "
            f"Either it has already been reviewed or the report is malformed: {report_path}",
            file=sys.stderr,
        )
        return 1

    # 2. Resolve and load the prompt template
    prompt_path = Path(__file__).resolve().parent / "prompts" / "audit-review.md"
    if not prompt_path.is_file():
        print(f"\n❌ Council audit-review prompt missing: {prompt_path}", file=sys.stderr)
        return 1
    prompt_template = prompt_path.read_text(encoding="utf-8")
    if "{REPORT_CONTENT}" not in prompt_template:
        print(
            f"\n❌ Council audit-review prompt is missing {{REPORT_CONTENT}} token: {prompt_path}",
            file=sys.stderr,
        )
        return 1

    prompt = prompt_template.replace("{REPORT_CONTENT}", report_content)

    # 3. Parallel dispatch (D-08, COUNCIL-06)
    stub_gemini = os.getenv("COUNCIL_STUB_GEMINI")
    stub_chatgpt = os.getenv("COUNCIL_STUB_CHATGPT")

    # Fail fast when neither backend is reachable and no stubs override them
    # (WR-02 fix — replaces the dead pre-set bypass that was unconditionally
    # overwritten by future.result() below).
    if (not stub_gemini and not config.get("_gemini_available", True) and
            not stub_chatgpt and not config.get("_openai_available", True)):
        print(
            "\n❌ No Council backends available and no stubs configured.",
            file=sys.stderr,
        )
        return 1

    gemini_raw = None
    chatgpt_raw = None

    print("\n\U0001f9e0 Council audit-review: dispatching Gemini and ChatGPT in parallel...")

    with ThreadPoolExecutor(max_workers=2) as executor:
        future_g = executor.submit(dispatch_audit_review_gemini, prompt, config)
        future_c = executor.submit(dispatch_audit_review_chatgpt, prompt, config)
        try:
            gemini_raw = future_g.result(timeout=90)
        except FuturesTimeoutError:
            gemini_raw = "Error: Gemini backend timed out after 90s"
        except Exception as exc:
            gemini_raw = f"Error: Gemini dispatch failed: {exc}"
        try:
            chatgpt_raw = future_c.result(timeout=90)
        except FuturesTimeoutError:
            chatgpt_raw = "Error: ChatGPT backend timed out after 90s"
        except Exception as exc:
            chatgpt_raw = f"Error: ChatGPT dispatch failed: {exc}"

    # 4. Extract bracketed blocks (D-10)
    g_verdict_block = extract_block(gemini_raw, "verdict-table")
    g_missed_block = extract_block(gemini_raw, "missed-findings")
    c_verdict_block = extract_block(chatgpt_raw, "verdict-table")
    c_missed_block = extract_block(chatgpt_raw, "missed-findings")

    # 5. Malformed-output guard
    if g_verdict_block is None and c_verdict_block is None:
        # Both backends produced unparseable output -> council_pass: failed, exit 1
        msg = "Council parse error: neither backend returned a <verdict-table> marker."
        print(f"\n❌ {msg}", file=sys.stderr)
        rewrite_report(
            report_path,
            status="failed",
            verdict_text=f"_{msg}_",
            missed_text=None,
        )
        return 1

    # 6. Parse verdict tables
    verdicts_g = parse_verdict_table(g_verdict_block) if g_verdict_block else {}
    verdicts_c = parse_verdict_table(c_verdict_block) if c_verdict_block else {}

    if not verdicts_g and not verdicts_c:
        msg = "Council parse error: backends emitted markers but no parseable verdict rows."
        print(f"\n❌ {msg}", file=sys.stderr)
        rewrite_report(
            report_path,
            status="failed",
            verdict_text=f"_{msg}_",
            missed_text=None,
        )
        return 1

    # 7. Resolve consolidated status
    status, rows = resolve_council_status(verdicts_g, verdicts_c)

    # 8. Build verdict_text — markdown table with byte-exact column header
    verdict_lines = [
        COUNCIL_VERDICT_HEADER,
        "|----|---------|------------|---------------|",
    ]
    for row in rows:
        # Sanitize pipe characters in justification to avoid breaking the table
        just = row["justification"].replace("|", "\\|")
        verdict_lines.append(
            f"| {row['id']} | {row['verdict']} | {row['confidence']} | {just} |"
        )
    verdict_text = "\n".join(verdict_lines)

    # 9. Build missed_text — prefer Gemini, fall back to ChatGPT
    missed_text = g_missed_block or c_missed_block or "(none)"
    # Normalise common empty representations
    if missed_text.strip().lower() in ("(none)", "none", ""):
        missed_text = "(none)"

    # 10. Rewrite report (atomic, in-place)
    rewrite_report(report_path, status, verdict_text, missed_text)

    # 11. Print collated verdict to stdout
    print("\n" + "=" * 60)
    print("\U0001f4cb COUNCIL AUDIT-REVIEW REPORT")
    print("=" * 60)
    print(f"  Report:       {report_path}")
    print(f"  council_pass: {status}")
    print(f"  Findings:     {len(rows)}")
    print("-" * 60)
    for row in rows:
        marker = {
            "REAL": "✅",
            "FALSE_POSITIVE": "⛔",
            "NEEDS_MORE_CONTEXT": "❓",
            "disputed": "⚠️",
        }.get(row["verdict"], "?")
        print(f"  {marker} {row['id']}: {row['verdict']} ({row['confidence']})")
    print("=" * 60 + "\n")

    return 0


# ─────────────────────────────────────────────────
# Main orchestration
# ─────────────────────────────────────────────────

def _run_validate_plan(plan, config):
    """Existing Phase 1-4 validate-plan flow. Behavior is byte-identical
    to the v3.0.0 brain.py main() body — no logic changes here.
    """
    validate_plan(plan)

    project_map = get_project_structure()
    git_diff = get_git_diff()
    project_rules = get_project_rules()

    # Phase 24 SP3 — extra context blocks for Skeptic + Pragmatist.
    # Each fetch is capped to its own MAX_* limit; the budget pass below scales
    # them down proportionally if their sum threatens MAX_TOTAL_CONTEXT.
    readme = get_readme()
    planning_md = get_planning_context()
    recent_log = get_recent_log()
    todos = get_todos()

    # Build shared context blocks
    diff_block = f"\nGIT CHANGES:\n{git_diff}" if git_diff else ""
    rules_block = f"\nPROJECT RULES (CLAUDE.md):\n{project_rules}" if project_rules else ""

    enrichment_pairs = [
        ("README", readme),
        ("PLANNING CONTEXT", planning_md),
        ("RECENT COMMITS", recent_log),
        ("TODOS / FIXMES", todos),
    ]
    # Reserve ~20% of the budget for files_content + diff and let the
    # enrichment blocks share the rest (4/5ths of the cap).
    enrichment_budget = (MAX_TOTAL_CONTEXT * 4) // 5
    enrichment_pairs = apply_context_budget(enrichment_pairs, hard_limit=enrichment_budget)
    enrichment_block = "".join(
        f"\n{label}:\n{body}\n"
        for label, body in enrichment_pairs
        if body
    )

    # ── Phase 1: Context Discovery (skip if Gemini unavailable) ──
    files_content = ""
    file_paths = []
    if config.get("_gemini_available", True):
        print("\n\U0001f9e0 [Gemini]: Analyzing project structure...")

        context_prompt = f"""{load_prompt("skeptic-system")}

Review the project structure and the implementation plan.

PROJECT STRUCTURE:
{project_map}

PLAN: {plan}

List the file paths (comma-separated) that are critical to review for this plan.
Reply ONLY with the comma-separated list of file paths. No explanations."""

        files_to_read = ask_gemini(context_prompt, config)

        if files_to_read and "/" in files_to_read and not is_error_response(files_to_read):
            file_list = [f.strip() for f in files_to_read.replace("\n", ",").split(",")]
            print(f"\U0001f4c2 Reading {len(file_list)} file(s)...")
            file_paths = get_validated_paths(file_list)
            files_content = read_files(file_list)

    # ── Phase 2: The Skeptic (Gemini) ──
    print("\U0001f9d0 [The Skeptic]: Challenging plan justification...")

    # In CLI mode, Gemini reads files natively via @file (no content in prompt)
    use_native_files = config["gemini"].get("mode", "cli") == "cli" and file_paths
    files_in_prompt = "" if use_native_files else (files_content if files_content else "(no files read)")

    skeptic_prompt = f"""{load_prompt("skeptic-system")}
{rules_block}{enrichment_block}

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

    if config.get("_gemini_available", True):
        gemini_verdict = ask_gemini(
            skeptic_prompt, config,
            file_paths=file_paths if use_native_files else None
        )
    else:
        gemini_verdict = "Error: Gemini not configured (skipped per --allow-partial flow)"

    # ── Phase 3: The Pragmatist (ChatGPT) ──
    print("\U0001f528 [The Pragmatist]: Evaluating production readiness...")

    pragmatist_prompt = f"""Review this implementation plan and The Skeptic's assessment.
Do NOT repeat The Skeptic's points. Focus on what they missed or got wrong.
{rules_block}{enrichment_block}

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

    if config.get("_openai_available", True):
        gpt_verdict = ask_chatgpt(pragmatist_prompt, config)
    else:
        gpt_verdict = "Error: OpenAI not configured (skipped per --allow-partial flow)"

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
    vp_report_path = scratchpad / "council-report.md"

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

    vp_report_path.write_text(report, encoding="utf-8")
    print(f"Report saved: {vp_report_path}")


def main():
    parser = argparse.ArgumentParser(
        prog="brain",
        description=(
            "Supreme Council orchestrator. "
            "Two modes: validate-plan (default) and audit-review."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["validate-plan", "audit-review"],
        default=None,
        help="Council mode (default: validate-plan when a positional plan is given)",
    )
    parser.add_argument(
        "--report",
        default=None,
        help="Path to audit report (required when --mode audit-review)",
    )
    parser.add_argument(
        "plan",
        nargs="?",
        default=None,
        help="Implementation plan text (validate-plan mode)",
    )
    args = parser.parse_args()

    # Backward-compat: positional plan with no --mode -> validate-plan
    if args.mode is None:
        if args.plan:
            args.mode = "validate-plan"
        else:
            parser.print_help()
            sys.exit(1)

    config = load_config()

    if args.mode == "audit-review":
        if not args.report:
            parser.error("--report is required with --mode audit-review")
        rc = run_audit_review(args.report, config)
        sys.exit(rc)
    else:
        if not args.plan:
            print("\n❌ validate-plan mode requires a positional plan argument",
                  file=sys.stderr)
            print("Usage: python3 brain.py \"Your implementation plan\"", file=sys.stderr)
            sys.exit(1)
        _run_validate_plan(args.plan, config)


if __name__ == "__main__":
    main()
