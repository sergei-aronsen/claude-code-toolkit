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
import threading
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
MAX_TEST_FILE = 20000       # 20K characters per matching test file (SP3)


def _debug(msg):
    """Emit a stderr trace line when COUNCIL_DEBUG=1 is set.

    Used by SP3 context-enrichment helpers so users running
    `COUNCIL_DEBUG=1 brain "..."` can verify which blocks fed into the
    Skeptic / Pragmatist prompts and see redaction counts.
    """
    if os.environ.get("COUNCIL_DEBUG") == "1":
        print(f"[council:debug] {msg}", file=sys.stderr)


# Audit BRAIN-MEM-01: read at most `limit_bytes` from `path`. Replaces the
# `path.read_text()[:N]` pattern that allocated the entire file before slicing
# and could OOM on multi-GB files (a 229GB ~/.claude/CLAUDE.md infinite-append
# loop hung Python at >50GB RSS). Reads `limit_bytes + 1` so the caller can
# detect truncation. Returns "" on any OSError. Decodes as UTF-8 with
# `errors="replace"` to preserve original Path.read_text() semantics.
def _read_capped(path, limit_bytes):
    try:
        with open(path, "rb") as fh:
            data = fh.read(limit_bytes + 1)
    except OSError:
        return ""
    return data.decode("utf-8", errors="replace")


# Audit B2/B3: secure-tempfile helper + at-exit registry. The previous pattern
# `NamedTemporaryFile(delete=False)` then `os.chmod(0o600)` left a TOCTOU
# window where the file briefly existed at default umask (often 0644) before
# the chmod executed — another local user could read the API-key headers in
# that window. mkstemp creates with mode 0600 atomically (POSIX
# O_CREAT|O_EXCL|0600). Files registered here are also unlinked on normal
# exit / SystemExit, so a SIGTERM mid-curl can't strand the secret in /tmp.
# (SIGKILL still leaks — Python cannot intercept it.)
import atexit  # noqa: E402  (placed near helper so refactors stay local)
import signal  # noqa: E402

_SECURE_TEMPFILES = set()


def _secure_tempfile_register(path):
    _SECURE_TEMPFILES.add(path)


def _secure_tempfile_unregister(path):
    _SECURE_TEMPFILES.discard(path)


def _secure_tempfile_cleanup_all():
    for path in list(_SECURE_TEMPFILES):
        try:
            os.unlink(path)
        except (FileNotFoundError, OSError):
            pass
        _SECURE_TEMPFILES.discard(path)


atexit.register(_secure_tempfile_cleanup_all)


def _secure_tempfile_signal_handler(signum, _frame):
    _secure_tempfile_cleanup_all()
    # Re-raise as default disposition so callers see the actual signal
    # (atexit will run before re-raise but we already cleaned up above).
    signal.signal(signum, signal.SIG_DFL)
    os.kill(os.getpid(), signum)


for _sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    try:
        signal.signal(_sig, _secure_tempfile_signal_handler)
    except (ValueError, OSError):
        # Signal not available on this platform / not on main thread — skip.
        pass


def _write_secure_tempfile(content, prefix):
    """Create a 0600 tempfile atomically and write `content` to it.

    Returns the path string. Caller MUST call os.unlink + the unregister
    helper when done; alternatively, _secure_tempfile_cleanup_all() runs at
    interpreter exit. mkstemp uses O_CREAT|O_EXCL|0600 so the file never
    exists in a world-readable state.
    """
    fd, path = tempfile.mkstemp(prefix=prefix, suffix=".txt")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
    except Exception:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        raise
    _secure_tempfile_register(path)
    return path


# Audit B6: world-readable JSONL / cache. Previous code wrote usage.jsonl,
# cached reports, and the validate-plan report under the default umask.
# _open_0600 opens for append/write with mode 0600 atomically; existing files
# are mode-fixed via fchmod after open so historical 0644 records are
# tightened on next write.
def _open_0600(path, mode_str):
    """Open `path` for `mode_str` ('a' or 'w'), enforcing 0600 perms."""
    flags = os.O_CREAT | os.O_WRONLY
    if mode_str == "a":
        flags |= os.O_APPEND
    elif mode_str == "w":
        flags |= os.O_TRUNC
    else:
        raise ValueError(f"unsupported mode: {mode_str}")
    fd = os.open(str(path), flags, 0o600)
    try:
        os.fchmod(fd, 0o600)
    except OSError:
        pass
    return os.fdopen(fd, mode_str, encoding="utf-8")

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


_COUNCIL_LANG = "en"  # Phase 24 SP9 — flipped to "ru" by --lang or auto-detect


def set_council_lang(lang):
    """Set the active language code (e.g. 'en', 'ru'). Clears the prompt cache
    so existing entries do not bleed across languages within a single process.
    """
    global _COUNCIL_LANG, _PROMPT_CACHE
    if not lang:
        return
    if lang == _COUNCIL_LANG:
        return
    _COUNCIL_LANG = lang
    _PROMPT_CACHE = {}


def detect_council_lang(default="en"):
    """Phase 24 SP9 — auto-detect Council language from ~/.claude/CLAUDE.md.

    Reads the first 500 chars of the global CLAUDE.md (if present) and
    classifies as Russian when the Cyrillic-character ratio exceeds 0.2.
    Returns the detected language code or `default`.
    """
    path = Path.home() / ".claude" / "CLAUDE.md"
    if not path.is_file():
        return default
    sample = _read_capped(path, 500)[:500]
    if not sample:
        return default
    cyrillic = sum(1 for ch in sample if "Ѐ" <= ch <= "ӿ")
    ratio = cyrillic / max(1, len(sample))
    return "ru" if ratio > 0.2 else default


def load_prompt(name):
    """Return the system prompt body for `name`.

    Lookup order (Phase 24 SP9):
      1. `~/.claude/council/prompts/<lang>/<name>.md` for the active language.
      2. `~/.claude/council/prompts/<name>.md` (English / default).
      3. Embedded `PROMPT_FALLBACKS` constant.

    Cached per (lang, name) within a process; set_council_lang() clears the
    cache when the language switches.
    """
    cache_key = f"{_COUNCIL_LANG}::{name}"
    if cache_key in _PROMPT_CACHE:
        return _PROMPT_CACHE[cache_key]
    candidates = []
    if _COUNCIL_LANG and _COUNCIL_LANG != "en":
        candidates.append(PROMPTS_DIR / _COUNCIL_LANG / f"{name}.md")
    candidates.append(PROMPTS_DIR / f"{name}.md")
    text = None
    for path in candidates:
        try:
            if path.is_file():
                text = path.read_text(encoding="utf-8").strip()
                if text:
                    break
        except OSError:
            text = None
    if not text:
        text = PROMPT_FALLBACKS.get(name, "")
    _PROMPT_CACHE[cache_key] = text
    return text


# ─────────────────────────────────────────────────
# Phase 24 Sub-Phase 8 — domain detection + persona overlays
# ─────────────────────────────────────────────────
# detect_domain() classifies the plan into one of {security, performance,
# ux, migration, general}. When non-general, the matching persona overlay
# under prompts/personas/<domain>-<role>.md is prepended to the base
# Skeptic / Pragmatist system prompt. Overlays are optional — missing
# files degrade gracefully to the base prompt.

DOMAIN_PATTERNS = (
    ("security", re.compile(r"\b(auth|password|crypto|JWT|token|session)\b", re.IGNORECASE)),
    ("performance", re.compile(r"\b(perf|latency|cache|N\+1|slow|optimi[sz]e)\b", re.IGNORECASE)),
    ("ux", re.compile(r"\b(UI|UX|accessibility|a11y|WCAG|screen reader)\b", re.IGNORECASE)),
    ("migration", re.compile(r"\b(?:migration|backwards|deprecat\w*)\b", re.IGNORECASE)),
)


def detect_domain(plan_text):
    """Classify a plan into a domain bucket. Returns 'general' on no match."""
    if not plan_text:
        return "general"
    for label, pat in DOMAIN_PATTERNS:
        if pat.search(plan_text):
            return label
    return "general"


def load_persona(domain, role):
    """Return the persona overlay text for (domain, role) or '' when none.

    role must be 'skeptic' or 'pragmatist'. domain 'general' always returns
    empty string. Lookup prefers the language-localized
    `personas/<lang>/<domain>-<role>.md` (SP9) before falling back to the
    canonical English overlay. Cached per (lang, domain, role).
    """
    if not domain or domain == "general":
        return ""
    if role not in ("skeptic", "pragmatist"):
        return ""
    cache_key = f"persona::{_COUNCIL_LANG}::{domain}-{role}"
    if cache_key in _PROMPT_CACHE:
        return _PROMPT_CACHE[cache_key]
    candidates = []
    if _COUNCIL_LANG and _COUNCIL_LANG != "en":
        candidates.append(PROMPTS_DIR / "personas" / _COUNCIL_LANG / f"{domain}-{role}.md")
    candidates.append(PROMPTS_DIR / "personas" / f"{domain}-{role}.md")
    text = ""
    for path in candidates:
        try:
            if path.is_file():
                text = path.read_text(encoding="utf-8").strip()
                if text:
                    break
        except OSError:
            text = ""
    _PROMPT_CACHE[cache_key] = text
    return text


def compose_system_prompt(role, plan, domain=None):
    """Build the full system prompt for `role`.

    Loads the base system prompt for the role and, when the plan classifies
    into a non-general domain, prepends the matching persona overlay
    separated by a `---` divider. Falls through to the base prompt when no
    overlay exists.
    """
    base = load_prompt(f"{role}-system")
    if domain is None:
        domain = detect_domain(plan)
    overlay = load_persona(domain, role)
    if not overlay:
        _debug(f"persona: role={role} domain={domain} overlay=none")
        return base
    _debug(f"persona: role={role} domain={domain} overlay=loaded ({len(overlay)} chars)")
    return f"{overlay}\n\n---\n\n{base}"


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


def _extract_concerns(text):
    """Phase 24 SP8 — pull bullet items from a `## Concerns` section.

    The Skeptic prompt asks for "max 3" concerns under that heading; the
    Pragmatist's "## Production Readiness" / "## Maintenance Forecast"
    sections may or may not use the same name. We scan for any `## Concerns`
    (case-insensitive) header and harvest list bullets up to the next
    heading. Returns up to 3 concise strings.
    """
    if not text:
        return []
    m = re.search(
        r"##\s*Concerns[^\n]*\n(.*?)(?=\n##\s|\Z)",
        text,
        re.DOTALL | re.IGNORECASE,
    )
    if not m:
        return []
    body = m.group(1)
    # Audit L-Council: `[\s>]*` matched \n in character classes even under
    # MULTILINE, so the `^...^` anchors could span lines and capture wrong
    # text. Restrict to horizontal whitespace.
    bullets = re.findall(r"^[ \t>]*[-*•]\s+(.+)$|^[ \t>]*\d+[.)]\s+(.+)$", body, re.MULTILINE)
    out = []
    for bullet_pair in bullets:
        for grp in bullet_pair:
            if grp and grp.strip():
                out.append(grp.strip())
                break
    return out[:3]


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
    # Audit L-Council: skip the full text.upper() — for 100K+ char reviewer
    # outputs that doubled the working set unnecessarily. Use re.IGNORECASE
    # over the original string and uppercase only the matched group.
    match = re.search(
        r"VERDICT:\s*(PROCEED|SIMPLIFY|RETHINK|SKIP)",
        text,
        re.IGNORECASE,
    )
    if match:
        return match.group(1).upper()
    # Fallback: scan only the last 500 chars (verdict line typically at end).
    tail = text[-500:].upper()
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

    # Phase 24 SP5 defaults \u2014 additive, do not require config.json rewrite.
    config["gemini"].setdefault("thinking_budget", 32768)
    # OpenAI mode: if not set, prefer codex CLI when available, else api.
    if "mode" not in config["openai"]:
        config["openai"]["mode"] = "cli" if shutil.which("codex") else "api"
    config["openai"].setdefault("reasoning_effort", "high")
    config["openai"].setdefault("cli_reasoning_effort", "high")
    fallback = config.setdefault("fallback", {})
    openrouter = fallback.setdefault("openrouter", {})
    openrouter.setdefault("api_key", os.getenv("OPENROUTER_API_KEY", ""))
    openrouter.setdefault("models", [
        "tencent/hy3-preview:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "inclusionai/ling-2.6-1t:free",
        "openrouter/free",
    ])

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

    if config["openai"].get("mode") == "cli":
        if shutil.which("codex") is None:
            print("\u26a0\ufe0f  OpenAI CLI mode selected but 'codex' is not in PATH.")
            print("   Install: npm install -g @openai/codex   # or: brew install --cask codex")
            print(f"   Or switch to API mode by editing {CONFIG_PATH}")
            config["_openai_available"] = False
    elif not config["openai"].get("api_key"):
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

    Audit B4: refuse symlinks. Path.resolve() follows symlinks transparently,
    so a hostile symlink at `node_modules/foo -> /Users/me/.ssh/id_rsa`
    would resolve to a path INSIDE cwd if the link target was placed inside
    cwd, but more dangerously could resolve to a path outside cwd while
    appearing to start inside (since the link itself sits inside cwd).
    Reject any path component that is a symlink \u2014 Council reviewers should
    not be able to coerce reading of files outside the explicit tree.
    """
    file_path = file_path.strip().strip("'\"`)>")
    if not file_path:
        return None
    cwd = Path.cwd().resolve()
    raw = cwd / file_path
    # Walk every component looking for symlinks BEFORE resolving \u2014 once we
    # call .resolve() the symlink chain is collapsed and we can't tell.
    cur = Path(cwd)
    try:
        rel_parts = (cwd / file_path).relative_to(cwd).parts
    except ValueError:
        try:
            rel_parts = Path(file_path).parts
        except (ValueError, OSError):
            print(f"\u26a0\ufe0f  Invalid path: {file_path}")
            return None
    for part in rel_parts:
        cur = cur / part
        if cur.is_symlink():
            print(f"\u26a0\ufe0f  Refusing symlink in path: {file_path}")
            return None
    try:
        resolved = raw.resolve()
        resolved.relative_to(cwd)
    except (ValueError, OSError):
        print(f"\u26a0\ufe0f  Skipping path outside project: {file_path}")
        return None
    if not resolved.is_file():
        print(f"\u26a0\ufe0f  File not found: {file_path}")
        return None
    return resolved


def read_files(file_list):
    """Read requested files safely with total context limit.

    Audit B5: dedup file_list. A reviewer that repeats the same path 10K
    times in its response previously triggered 10K stat() calls inside
    validate_file_path. Track resolved paths in a set and skip repeats.
    """
    content = ""
    total_size = 0
    seen_paths = set()
    for file_path in file_list:
        resolved = validate_file_path(file_path)
        if not resolved:
            continue
        resolved_str = str(resolved)
        if resolved_str in seen_paths:
            continue
        seen_paths.add(resolved_str)
        if total_size >= MAX_TOTAL_CONTEXT:
            print(f"\u26a0\ufe0f  Context limit reached ({MAX_TOTAL_CONTEXT} chars), skipping remaining files")
            break
        try:
            text = _read_capped(resolved, 20000)
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
    text = _read_capped(claude_md, MAX_PROJECT_RULES)
    if len(text) > MAX_PROJECT_RULES:
        text = text[:MAX_PROJECT_RULES] + "\n... (truncated)"
    return text


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
    text = _read_capped(path, MAX_README)
    if not text:
        _debug("README.md: empty or read failed")
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
    # Audit M-Council: skip per-file pathologies. Minified bundles, lockfiles,
    # and machine-generated SQL dumps can reach 10MB+ on a single line; running
    # the TODO regex over them is O(N²) on backtracking-prone shapes and gobbles
    # memory. 1MB cap and 5KB/line cap together bound worst-case work.
    MAX_TODO_FILE_BYTES = 1 * 1024 * 1024
    MAX_TODO_LINE_BYTES = 5 * 1024
    for path in files:
        try:
            stat = path.stat()
        except OSError:
            continue
        if stat.st_size > MAX_TODO_FILE_BYTES:
            continue
        try:
            with path.open("r", encoding="utf-8", errors="replace") as fh:
                for lineno, line in enumerate(fh, start=1):
                    if len(line) > MAX_TODO_LINE_BYTES:
                        continue
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
    text = _read_capped(path, MAX_PLANNING)
    if not text:
        _debug(".planning/PROJECT.md: empty or read failed")
        return ""
    out = _truncate(text, MAX_PLANNING)
    _debug(f".planning/PROJECT.md: {len(out)} chars (capped at {MAX_PLANNING})")
    return out


def get_tests_for(file_paths):
    """Locate test files matching each source path.

    For every input path, look for siblings under common test layouts:
      tests/<basename>*       __tests__/<basename>*       test_<basename>*
    Returns a concatenated string (file-marker headers) capped at
    MAX_TOTAL_CONTEXT to stay inside the global budget.
    """
    if not file_paths:
        return ""
    root = find_project_root()
    seen = set()
    blocks = []
    total = 0

    for raw in file_paths:
        try:
            src = Path(raw)
            if not src.is_absolute():
                src = (root / src).resolve()
            stem = src.stem
            parents = [src.parent] + list(src.parent.parents)
        except OSError:
            continue

        candidates = []
        for parent in parents:
            for sub in ("tests", "__tests__"):
                test_dir = parent / sub
                if test_dir.is_dir():
                    candidates.extend(test_dir.glob(f"{stem}*"))
                    candidates.extend(test_dir.glob(f"test_{stem}*"))
            candidates.extend(parent.glob(f"test_{stem}*"))
            candidates.extend(parent.glob(f"{stem}.test.*"))
            candidates.extend(parent.glob(f"{stem}.spec.*"))

        for cand in candidates:
            if not cand.is_file():
                continue
            try:
                rel = cand.resolve().relative_to(root)
            except (OSError, ValueError):
                continue
            key = str(rel)
            if key in seen:
                continue
            seen.add(key)
            text = _read_capped(cand, MAX_TEST_FILE)
            if not text:
                continue
            text = _truncate(text, MAX_TEST_FILE, marker="(test file truncated)")
            block = f"\n--- TEST FILE: {key} ---\n{text}\n"
            if total + len(block) > MAX_TOTAL_CONTEXT:
                break
            blocks.append(block)
            total += len(block)

    if not blocks:
        _debug("tests-for: 0 matches")
        return ""
    _debug(f"tests-for: {len(blocks)} files, {total} chars")
    return "".join(blocks)


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
# Phase 24 Sub-Phase 3 — privacy redaction
# ─────────────────────────────────────────────────
#
# Default patterns cover the most common secret shapes; users can append more
# via ~/.claude/council/redaction-patterns.txt (one Python regex per line, #
# comments allowed).

REDACTION_PATTERNS_PATH = Path.home() / ".claude" / "council" / "redaction-patterns.txt"

DEFAULT_REDACTION_PATTERNS = [
    # OpenAI-style API keys
    r"sk-[A-Za-z0-9_\-]{20,}",
    r"sk-proj-[A-Za-z0-9_\-]{20,}",
    # Audit M-Council: lower the generic key threshold from 16 → 12 chars so
    # short-token providers (legacy Heroku 11-char auth tokens, some internal
    # services) are still redacted. False-positive rate stays acceptable —
    # these patterns require an `api_key=` / `secret=` prefix.
    r"(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{12,}['\"]?",
    # Bearer tokens
    r"(?i)bearer\s+[A-Za-z0-9_\-\.=]{20,}",
    # JWT (three base64url segments)
    r"eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+",
    # AWS access key / secret access key
    r"AKIA[0-9A-Z]{16}",
    r"(?i)aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9/+=]{30,}['\"]?",
    # GitHub PATs (classic + fine-grained)
    r"ghp_[A-Za-z0-9]{30,}",
    r"github_pat_[A-Za-z0-9_]{40,}",
    # Google API keys
    r"AIza[0-9A-Za-z_\-]{30,}",
    # Slack tokens
    r"xox[baprs]-[A-Za-z0-9-]{10,}",
    # Heroku auth UUIDs (8-4-4-4-12 hex)
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",
]

_REDACTION_CACHE = None


def _load_redaction_patterns():
    """Compile default + user patterns once per process. Bad regexes warn but don't crash."""
    global _REDACTION_CACHE
    if _REDACTION_CACHE is not None:
        return _REDACTION_CACHE
    raw = list(DEFAULT_REDACTION_PATTERNS)
    if REDACTION_PATTERNS_PATH.is_file():
        try:
            for line in REDACTION_PATTERNS_PATH.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    raw.append(line)
        except OSError:
            pass
    compiled = []
    for pat in raw:
        try:
            compiled.append(re.compile(pat))
        except re.error as exc:
            print(f"⚠️  invalid redaction pattern {pat!r}: {exc}", file=sys.stderr)
    _REDACTION_CACHE = compiled
    _debug(f"redaction: loaded {len(compiled)} patterns")
    return compiled


def redact_context(text, label="<unlabeled>"):
    """Replace matches of every redaction pattern with ***REDACTED***.

    Logs the per-block redaction count to stderr (without revealing content).
    """
    if not text:
        return text
    patterns = _load_redaction_patterns()
    redacted = text
    count = 0
    for pat in patterns:
        new, n = pat.subn("***REDACTED***", redacted)
        count += n
        redacted = new
    if count:
        print(
            f"ℹ️  Redacted {count} secret(s) in {label} before sending to providers",
            file=sys.stderr,
        )
    return redacted


# ─────────────────────────────────────────────────
# Phase 24 Sub-Phase 4 — usage logging + pricing
# ─────────────────────────────────────────────────
#
# Every Council API call appends one JSON line to usage.jsonl. Token counts
# come from the provider's response when available (Gemini usageMetadata,
# OpenAI usage object); CLI calls fall back to a chars/4 estimate marked
# with `"estimated": true`. Cost is multiplied through pricing.json which
# users maintain (rates ship as DEFAULT_PRICING fallback).

import datetime
import hashlib

USAGE_LOG_PATH = Path.home() / ".claude" / "council" / "usage.jsonl"
PRICING_PATH = Path.home() / ".claude" / "council" / "pricing.json"

# $/1M tokens. Indicative rates as of Q1 2026 — users can override via
# ~/.claude/council/pricing.json. CLI calls (Gemini CLI / Codex CLI) cost
# zero per token under subscription, modeled with both rates = 0.
DEFAULT_PRICING = {
    "gemini-3-pro-preview": {"input_per_1m": 1.25, "output_per_1m": 10.0},
    "gemini-2.5-pro": {"input_per_1m": 1.25, "output_per_1m": 10.0},
    "gpt-5.2-pro": {"input_per_1m": 15.0, "output_per_1m": 60.0},
    "gpt-5.2": {"input_per_1m": 1.25, "output_per_1m": 10.0},
    "o3-pro": {"input_per_1m": 15.0, "output_per_1m": 60.0},
    "o3": {"input_per_1m": 2.0, "output_per_1m": 8.0},
    # CLI-driven calls — covered by subscription, no per-token cost
    "gemini-cli": {"input_per_1m": 0.0, "output_per_1m": 0.0},
    "codex-cli": {"input_per_1m": 0.0, "output_per_1m": 0.0},
    # OpenRouter free tier
    "openrouter-free": {"input_per_1m": 0.0, "output_per_1m": 0.0},
}

_PRICING_CACHE = None

# Audit BRAIN-T1: per-thread usage stash. The audit-review mode dispatches
# Gemini and ChatGPT in parallel via ThreadPoolExecutor (run_audit_review at
# ~line 1855). A module-level global was racy — both threads wrote, the loser
# was lost, and record_usage() could attribute one provider's tokens to the
# other's mode. threading.local() gives each worker its own stash so
# _set_last_usage and record_usage stay paired within the same thread.
_THREAD_LOCAL = threading.local()


def _load_pricing():
    """Merge user pricing.json on top of DEFAULT_PRICING. Cached per process."""
    global _PRICING_CACHE
    if _PRICING_CACHE is not None:
        return _PRICING_CACHE
    pricing = dict(DEFAULT_PRICING)
    if PRICING_PATH.is_file():
        try:
            user_pricing = json.loads(PRICING_PATH.read_text(encoding="utf-8"))
            if isinstance(user_pricing, dict):
                for model, rates in user_pricing.items():
                    if isinstance(rates, dict):
                        pricing[model] = rates
        except (OSError, json.JSONDecodeError) as exc:
            print(f"⚠️  pricing.json unreadable: {exc}", file=sys.stderr)
    _PRICING_CACHE = pricing
    return pricing


def _estimate_tokens(text):
    """Approximate token count when the provider doesn't report usage.

    Heuristic: 1 token ≈ 4 characters of English-like text. Conservative — over-
    counts for code-heavy prompts, which is the side users want for cost
    forecasting.
    """
    if not text:
        return 0
    return max(1, len(text) // 4)


def _compute_cost(model, tokens_in, tokens_out):
    """Return cost in USD for `tokens_in` input + `tokens_out` output of `model`.

    Falls back to zero when the model is missing from pricing — avoids fake cost
    spikes when DEFAULT_PRICING lags behind Council's configured model list.
    """
    pricing = _load_pricing()
    rates = pricing.get(model) or {}
    in_rate = float(rates.get("input_per_1m", 0.0))
    out_rate = float(rates.get("output_per_1m", 0.0))
    return round(
        (tokens_in / 1_000_000.0) * in_rate
        + (tokens_out / 1_000_000.0) * out_rate,
        6,
    )


def _set_last_usage(provider, model, tokens_in, tokens_out, estimated=False):
    """Stash the just-completed call's token usage for the next record_usage().

    Per-thread storage (threading.local) so audit-review's parallel Gemini +
    ChatGPT dispatch doesn't race; each worker thread reads back exactly the
    snapshot its own ask_* set.
    """
    _THREAD_LOCAL.last_usage = {
        "provider": provider,
        "model": model,
        "tokens_in": int(tokens_in or 0),
        "tokens_out": int(tokens_out or 0),
        "estimated": bool(estimated),
    }


def record_usage(mode, verdict=None, plan_hash=None, fallback_used=False):
    """Append one JSON line to usage.jsonl with the last call's tokens + cost.

    Silent when no preceding ask_* set _THREAD_LOCAL.last_usage (e.g. early
    error path) so failed calls never write half-formed records. Users opt out
    by setting COUNCIL_NO_USAGE_LOG=1 (rare — used by CI to keep the file
    clean). Per-thread storage; safe under audit-review parallel dispatch.
    """
    snapshot = getattr(_THREAD_LOCAL, "last_usage", None)
    if snapshot is None or os.environ.get("COUNCIL_NO_USAGE_LOG") == "1":
        return
    _THREAD_LOCAL.last_usage = None
    cost = _compute_cost(
        snapshot["model"], snapshot["tokens_in"], snapshot["tokens_out"]
    )
    record = {
        "ts": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": mode,
        "provider": snapshot["provider"],
        "model": snapshot["model"],
        "tokens_in": snapshot["tokens_in"],
        "tokens_out": snapshot["tokens_out"],
        "cost_usd": cost,
        "estimated": snapshot["estimated"],
        "verdict": verdict,
        "fallback_used": bool(fallback_used),
        "plan_hash": plan_hash,
    }
    try:
        USAGE_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        # Audit B6: 0600 — usage.jsonl records token usage and plan hashes;
        # multi-user boxes must not let other accounts read this billing data.
        with _open_0600(USAGE_LOG_PATH, "a") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError as exc:
        print(f"⚠️  could not append usage.jsonl: {exc}", file=sys.stderr)
    _debug(
        f"usage: {snapshot['provider']}/{snapshot['model']} "
        f"in={snapshot['tokens_in']} out={snapshot['tokens_out']} "
        f"cost=${cost:.6f} verdict={verdict}"
    )


def log_cache_hit(plan_hash, verdict):
    """Phase 24 SP6 — append a zero-token cache_hit record to usage.jsonl.

    A cache hit makes no provider call, so _THREAD_LOCAL.last_usage is empty. We still
    want one row per /council invocation so `brain stats` shows cache
    activity and confirms the user wasn't billed for the replay.
    """
    if os.environ.get("COUNCIL_NO_USAGE_LOG") == "1":
        return
    record = {
        "ts": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": "validate-plan-cache-hit",
        "provider": "cache",
        "model": "cache",
        "tokens_in": 0,
        "tokens_out": 0,
        "cost_usd": 0.0,
        "estimated": False,
        "verdict": verdict,
        "fallback_used": False,
        "plan_hash": plan_hash,
        "cache_hit": True,
    }
    try:
        USAGE_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with _open_0600(USAGE_LOG_PATH, "a") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError as exc:
        print(f"⚠️  could not append usage.jsonl: {exc}", file=sys.stderr)
    _debug(f"usage: cache_hit verdict={verdict}")


def _hash_plan(plan):
    """Stable 16-hex-char digest of the plan / report content. None on empty input."""
    if not plan:
        return None
    return hashlib.sha256(plan.encode("utf-8", errors="replace")).hexdigest()[:16]


# ─────────────────────────────────────────────────
# Phase 24 Sub-Phase 6 — Content-hash cache
# ─────────────────────────────────────────────────
# Two `/council "<same plan>"` calls within TTL share a cached report and skip
# all provider calls. Cache key combines plan text + git HEAD + cwd so that
# (a) different projects never collide, and (b) any new commit busts the
# cache even when the plan string is unchanged. CLI flag `--no-cache`
# forces a fresh call. TTL comes from config.cache.ttl_days (default 7).

CACHE_DIR = Path.home() / ".claude" / "council" / "cache"


def _git_head():
    """Current commit SHA for cache scoping. Empty string outside a repo."""
    try:
        out = run_command(["git", "rev-parse", "HEAD"], timeout=5)
        return (out or "").strip()
    except Exception:
        return ""


def _cache_key(plan, git_head, cwd):
    """sha256 of `plan|git_head|cwd` — the unit of cache identity."""
    blob = "|".join([plan or "", git_head or "", str(cwd or "")])
    return hashlib.sha256(blob.encode("utf-8", errors="replace")).hexdigest()


def _cache_path(key):
    return CACHE_DIR / f"{key}.json"


def _cache_ttl_days(config):
    cache_cfg = (config or {}).get("cache") or {}
    try:
        return float(cache_cfg.get("ttl_days", 7))
    except (TypeError, ValueError):
        return 7.0


def _get_cached(key, ttl_days):
    """Return cached payload dict if present and within TTL, else None."""
    if not key:
        return None
    p = _cache_path(key)
    if not p.is_file():
        return None
    try:
        age_seconds = datetime.datetime.now().timestamp() - p.stat().st_mtime
        if age_seconds > ttl_days * 86400:
            return None
        return json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        _debug(f"cache read failed: {e}")
        return None


def _set_cached(key, payload):
    if not key:
        return
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache_path = _cache_path(key)
        atomic_write_text(cache_path, json.dumps(payload, ensure_ascii=False, indent=2))
        # Audit B6: tighten perms after atomic_write_text. The cache holds full
        # Council reports including snippets of project source — same
        # confidentiality class as usage.jsonl.
        try:
            os.chmod(cache_path, 0o600)
        except OSError:
            pass
    except OSError as e:
        _debug(f"cache write failed: {e}")


def cost_confirm_gate(prompt_text, model, label="<call>"):
    """Phase 24 Sub-Phase 4 — optional pre-call cost prompt.

    When env COUNCIL_COST_CONFIRM_THRESHOLD is set to a positive float, estimate
    the prompt's input cost (tokens × input rate from pricing.json) and prompt
    the user to confirm before send when the estimate exceeds the threshold.

    Returns True when the call should proceed, False when the user declines.
    Always returns True when:
      - the env var is unset or zero (default disabled)
      - stdin is not a TTY (CI / piped-in runs — never block silently)
      - estimated cost is below the threshold
    """
    raw = os.environ.get("COUNCIL_COST_CONFIRM_THRESHOLD", "").strip()
    if not raw:
        return True
    try:
        threshold = float(raw)
    except ValueError:
        print(
            f"⚠️  COUNCIL_COST_CONFIRM_THRESHOLD={raw!r} is not a number — ignoring",
            file=sys.stderr,
        )
        return True
    if threshold <= 0:
        return True

    pricing = _load_pricing()
    rates = pricing.get(model) or {}
    in_rate = float(rates.get("input_per_1m", 0.0))
    if in_rate <= 0:
        return True  # CLI / free-tier models never trigger the gate.

    estimated_in = _estimate_tokens(prompt_text)
    estimated_cost = (estimated_in / 1_000_000.0) * in_rate
    if estimated_cost < threshold:
        return True

    if not sys.stdin.isatty():
        print(
            f"⚠️  Estimated input cost ${estimated_cost:.4f} for {label} ({model}, "
            f"~{estimated_in} tokens) exceeds COUNCIL_COST_CONFIRM_THRESHOLD=${threshold:.4f}, "
            "but stdin is not a TTY — proceeding anyway.",
            file=sys.stderr,
        )
        return True

    msg = (
        f"\n💰 Cost-confirm gate ({label}):\n"
        f"   model:           {model}\n"
        f"   estimated tokens (input): {estimated_in}\n"
        f"   estimated cost:  ${estimated_cost:.4f} input only\n"
        f"   threshold:       ${threshold:.4f} (COUNCIL_COST_CONFIRM_THRESHOLD)\n"
        f"\n   Proceed? [y/N]: "
    )
    print(msg, end="", file=sys.stderr, flush=True)
    try:
        with open("/dev/tty", "r") as tty:
            answer = tty.readline().strip().lower()
    except OSError:
        answer = ""
    return answer in ("y", "yes")


# ─────────────────────────────────────────────────
# Gemini integration
# ─────────────────────────────────────────────────

def ask_gemini_cli(prompt, model, file_paths=None):
    """Query Gemini via CLI (stdin pipe). Supports @file for native file reading."""
    if file_paths:
        file_refs = "\n".join(f"@{p}" for p in file_paths)
        prompt = f"{file_refs}\n\n{prompt}"
    result = run_command(
        ["gemini", "--model", model],
        input_text=prompt,
        timeout=120
    )
    # Gemini CLI does not surface token counts — estimate from chars/4.
    _set_last_usage(
        "gemini-cli", model,
        _estimate_tokens(prompt), _estimate_tokens(result),
        estimated=True,
    )
    return result


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
    # Phase 24 SP5 — pin Gemini thinking budget. Default 32768 (max public).
    thinking_budget = (config or {}).get("gemini", {}).get("thinking_budget", 32768) if config else 32768
    if thinking_budget:
        payload["generationConfig"]["thinkingConfig"] = {
            "includeThoughts": True,
            "thinkingBudget": int(thinking_budget),
        }

    # Audit BRAIN-H3: pass JSON via stdin instead of a tempfile so the full
    # prompt (which can include 200K chars of project source) doesn't sit on
    # disk between processes — `finally` doesn't run on SIGKILL, so a hard
    # interrupt would leak tempfiles in /tmp.
    body = json.dumps(payload, ensure_ascii=False)

    hdr_path = _write_secure_tempfile(
        f"Content-Type: application/json\n"
        f"User-Agent: {USER_AGENT}\n"
        f"x-goog-api-key: {api_key}\n",
        prefix="council_gemini_hdr_",
    )
    try:
        result = run_command([
            "curl", "-s",
            "--max-time", "120",
            "--connect-timeout", "10",
            "--retry", "2",
            "--retry-delay", "2",
            "-H", f"@{hdr_path}",
            "--data-binary", "@-",
            url
        ], input_text=body, timeout=120)

        try:
            data = json.loads(result)
            text = data["candidates"][0]["content"]["parts"][0]["text"]
        except (json.JSONDecodeError, KeyError, IndexError):
            # Audit M-Council: sanitize FIRST, then truncate. Truncating
            # before sanitize_error could split a key in the middle and
            # leak the head while the tail (mistakenly thought to contain
            # the key) was redacted.
            sanitized = sanitize_error(result, config) if config else result
            return f"Gemini API error: {sanitized[:500]}"
        usage = data.get("usageMetadata", {}) if isinstance(data, dict) else {}
        _set_last_usage(
            "gemini",
            model,
            usage.get("promptTokenCount", _estimate_tokens(prompt)),
            usage.get("candidatesTokenCount", _estimate_tokens(text)),
            estimated="promptTokenCount" not in usage,
        )
        return text
    finally:
        try:
            os.unlink(hdr_path)
        except FileNotFoundError:
            pass
        _secure_tempfile_unregister(hdr_path)


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

REASONING_MODELS = {
    "gpt-5.2", "gpt-5.2-pro",
    "o3", "o3-pro", "o3-mini",
}


def ask_chatgpt_cli(prompt, model, reasoning_effort="high", system_prompt=None):
    """Query ChatGPT via Codex CLI (non-interactive `codex exec`).

    Codex CLI ships under ChatGPT Plus/Pro subscriptions — no per-token cost
    when the user is signed in. Accepts the same prompt body as the API path;
    we prepend the system prompt because Codex CLI does not split system /
    user roles.

    Reasoning effort is pinned via `--config model_reasoning_effort=<level>`
    (Codex CLI accepts low | medium | high; default is medium). We default to
    high because Council runs are infrequent and we want the strongest review
    Codex can produce.

    Honors COUNCIL_STUB_CHATGPT for test harnesses (mirrors dispatch helpers).
    Stubs only fire when COUNCIL_ALLOW_STUBS=1 (audit M-Council opt-in) so a
    stray COUNCIL_STUB_* env in the user's shell can never silently shadow a
    real backend with canned data.
    """
    if os.getenv("COUNCIL_ALLOW_STUBS") == "1":
        stub = os.getenv("COUNCIL_STUB_CHATGPT")
        if stub:
            return run_command([stub], timeout=60)

    full_prompt = (
        f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
    )
    cmd = [
        "codex", "exec",
        "--model", model,
        "--config", f"model_reasoning_effort={reasoning_effort}",
        "-",  # read prompt from stdin
    ]
    result = run_command(cmd, input_text=full_prompt, timeout=180)
    if is_error_response(result):
        return result
    _set_last_usage(
        "codex-cli", "codex-cli",
        _estimate_tokens(full_prompt), _estimate_tokens(result),
        estimated=True,
    )
    return result


def ask_openrouter(prompt, api_key, models, system_prompt=None):
    """Try each model in `models` in order via OpenRouter chat-completions API.

    Returns the first successful text. Raises (returns the last error string)
    only when every model in the chain fails — so the caller can flag the
    record `fallback_used: true` regardless of which OpenRouter model
    eventually answered.

    Honors COUNCIL_STUB_OPENROUTER for test harnesses (mirror of the OpenAI /
    Gemini stubs). Stubs require COUNCIL_ALLOW_STUBS=1 (audit M-Council).
    """
    stub = (
        os.getenv("COUNCIL_STUB_OPENROUTER")
        if os.getenv("COUNCIL_ALLOW_STUBS") == "1"
        else None
    )
    if stub:
        result = run_command([stub], timeout=60)
        _set_last_usage(
            "openrouter", "openrouter-stub",
            _estimate_tokens(prompt), _estimate_tokens(result),
            estimated=True,
        )
        return result

    if not api_key:
        return "Error: OpenRouter API key not set (check config.fallback.openrouter.api_key)"

    last_error = "Error: OpenRouter chain exhausted (no models configured)"
    for model in models or []:
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt or ""},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.2,
        }
        if not payload["messages"][0]["content"]:
            payload["messages"] = payload["messages"][1:]

        hdr_path = _write_secure_tempfile(
            f"Authorization: Bearer {api_key}\n"
            f"Content-Type: application/json\n"
            f"User-Agent: {USER_AGENT}\n"
            f"HTTP-Referer: https://github.com/sergei-aronsen/claude-code-toolkit\n"
            f"X-Title: Supreme Council\n",
            prefix="council_or_hdr_",
        )
        try:
            body = json.dumps(payload, ensure_ascii=False)
            result = run_command([
                "curl", "-sSf",
                "--max-time", "180",
                "--connect-timeout", "10",
                "--retry", "2",
                "--retry-delay", "2",
                "https://openrouter.ai/api/v1/chat/completions",
                "-H", f"@{hdr_path}",
                "--data-binary", "@-",
            ], input_text=body, timeout=180)
        finally:
            try:
                os.unlink(hdr_path)
            except FileNotFoundError:
                pass
            _secure_tempfile_unregister(hdr_path)

        if is_error_response(result):
            last_error = result
            continue
        try:
            data = json.loads(result)
            text = data["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError):
            last_error = f"OpenRouter parse error ({model}): {result[:300]}"
            continue
        usage = data.get("usage", {}) if isinstance(data, dict) else {}
        _set_last_usage(
            "openrouter", model,
            usage.get("prompt_tokens", _estimate_tokens(prompt)),
            usage.get("completion_tokens", _estimate_tokens(text)),
            estimated="prompt_tokens" not in usage,
        )
        return text

    return last_error


def call_with_fallback(primary_callable, fallback_prompt, fallback_system, config, label):
    """Run `primary_callable()` and, on failure, fall through to OpenRouter chain.

    Returns (text, fallback_used). Caller decides what mode/verdict to record.
    OpenRouter is invoked only when the primary returns an error response AND
    config.fallback.openrouter.api_key (or COUNCIL_STUB_OPENROUTER stub) is set.
    """
    text = primary_callable()
    if not is_error_response(text):
        return text, False

    fb_cfg = (config.get("fallback", {}) or {}).get("openrouter", {}) or {}
    api_key = fb_cfg.get("api_key", "")
    models = fb_cfg.get("models", [])
    stub_or = (
        os.getenv("COUNCIL_STUB_OPENROUTER")
        if os.getenv("COUNCIL_ALLOW_STUBS") == "1"
        else None
    )
    if not (api_key or stub_or) or not models:
        _debug(f"fallback: {label} — primary failed, OpenRouter not configured")
        return text, False

    print(
        f"⚠️  {label} primary backend failed — retrying via OpenRouter free chain",
        file=sys.stderr,
    )
    fb_text = ask_openrouter(
        fallback_prompt, api_key, models, system_prompt=fallback_system
    )
    return fb_text, True


def ask_chatgpt(prompt, config, system_prompt=None):
    """Query ChatGPT via OpenAI API or Codex CLI based on config.openai.mode.

    `system_prompt` overrides the default Pragmatist persona — used by
    audit-review mode to swap in the audit-review-pragmatist file (WR-01 fix).
    Reasoning effort defaults to `high` and is configurable via
    config.openai.reasoning_effort (API) and config.openai.cli_reasoning_effort
    (Codex CLI).
    """
    mode = config["openai"].get("mode", "api")
    model = config["openai"]["model"]
    if mode == "cli":
        cli_effort = config["openai"].get("cli_reasoning_effort", "high")
        return ask_chatgpt_cli(
            prompt, model,
            reasoning_effort=cli_effort,
            system_prompt=system_prompt,
        )

    api_key = config["openai"].get("api_key", "")
    reasoning_effort = config["openai"].get("reasoning_effort", "high")

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
    # Phase 24 SP5 — pin reasoning effort to max for the gpt-5.2 / o3 family.
    # Older models that don't accept the field are silently skipped.
    if model in REASONING_MODELS:
        payload["reasoning"] = {"effort": reasoning_effort}

    # Audit BRAIN-H4: write the Authorization header to a 0600 tempfile and
    # pass via `-H @file` so the API key never appears in `ps`/argv. Audit
    # BRAIN-H3: send the body via stdin so the full prompt isn't persisted.
    # Audit B2: tempfile is created 0600 atomically (no chmod TOCTOU).
    hdr_path = _write_secure_tempfile(
        f"Authorization: Bearer {api_key}\n"
        f"Content-Type: application/json\n"
        f"User-Agent: {USER_AGENT}\n",
        prefix="council_hdr_",
    )
    try:
        body = json.dumps(payload, ensure_ascii=False)
        # Council pass D: -f makes curl exit non-zero on HTTP 4xx/5xx so we
        # don't try to JSON-parse an HTML error page or empty body. Also -S
        # so we still get the status reason in the captured stderr.
        result = run_command([
            "curl", "-sSf",
            "--max-time", "120",
            "--connect-timeout", "10",
            "--retry", "2",
            "--retry-delay", "2",
            "https://api.openai.com/v1/chat/completions",
            "-H", f"@{hdr_path}",
            "--data-binary", "@-"
        ], input_text=body, timeout=120)

        if is_error_response(result):
            return sanitize_error(result, config)
        try:
            data = json.loads(result)
            text = data["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError):
            # Audit M-Council: sanitize before truncate (see ask_gemini_api).
            sanitized = sanitize_error(result, config)
            return f"OpenAI API error: {sanitized[:500]}"
        usage = data.get("usage", {}) if isinstance(data, dict) else {}
        _set_last_usage(
            "openai",
            model,
            usage.get("prompt_tokens", _estimate_tokens(prompt)),
            usage.get("completion_tokens", _estimate_tokens(text)),
            estimated="prompt_tokens" not in usage,
        )
        return text
    finally:
        try:
            os.unlink(hdr_path)
        except FileNotFoundError:
            pass
        _secure_tempfile_unregister(hdr_path)


# ─────────────────────────────────────────────────
# Council audit-review dispatch (Phase 15)
# ─────────────────────────────────────────────────


def dispatch_audit_review_gemini(prompt, config, plan_hash=None):
    """Gemini dispatch for audit-review mode.

    Honors COUNCIL_STUB_GEMINI env var (RESEARCH.md §5) — when set AND
    COUNCIL_ALLOW_STUBS=1 (audit M-Council opt-in), the value is treated as
    a path to an executable script that emits canned <verdict-table> output
    on stdout. Used by scripts/tests/test-council-audit-review.sh.
    """
    if os.getenv("COUNCIL_ALLOW_STUBS") == "1":
        stub = os.getenv("COUNCIL_STUB_GEMINI")
        if stub:
            return run_command([stub], timeout=30)
    result = ask_gemini(prompt, config)
    record_usage("audit-review-skeptic", plan_hash=plan_hash)
    return result


def dispatch_audit_review_chatgpt(prompt, config, plan_hash=None):
    """ChatGPT dispatch for audit-review mode.

    Honors COUNCIL_STUB_CHATGPT env var (RESEARCH.md §5). Stubs only fire
    when COUNCIL_ALLOW_STUBS=1 (audit M-Council).
    """
    if os.getenv("COUNCIL_ALLOW_STUBS") == "1":
        stub = os.getenv("COUNCIL_STUB_CHATGPT")
        if stub:
            return run_command([stub], timeout=30)
    result = ask_chatgpt(prompt, config, system_prompt=load_prompt("audit-review-pragmatist"))
    record_usage("audit-review-pragmatist", plan_hash=plan_hash)
    return result


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

    # Audit M-Council: wrap report content in sentinel markers so a hostile
    # writer of the audit report (e.g. a contractor or compromised process
    # with write access to .planning/audits/) cannot inject directives that
    # mimic the surrounding prompt and flip a verdict. Strip any pre-existing
    # sentinel markers from the user-supplied content first so an attacker
    # can't pre-close the wrapper. The audit-review prompt template is
    # updated to read from this sentinel-bracketed block.
    safe_content = report_content.replace(
        "<<<COUNCIL_REPORT_BEGIN>>>", "<<<stripped>>>"
    ).replace(
        "<<<COUNCIL_REPORT_END>>>", "<<<stripped>>>"
    )
    wrapped = (
        "<<<COUNCIL_REPORT_BEGIN>>>\n"
        f"{safe_content}\n"
        "<<<COUNCIL_REPORT_END>>>"
    )
    prompt = prompt_template.replace("{REPORT_CONTENT}", wrapped)
    plan_hash = _hash_plan(report_content)

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
        future_g = executor.submit(dispatch_audit_review_gemini, prompt, config, plan_hash)
        future_c = executor.submit(dispatch_audit_review_chatgpt, prompt, config, plan_hash)
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
    """Existing Phase 1-4 validate-plan flow plus SP6 cache short-circuit.

    Cache key = sha256(plan|git_head|cwd). On hit within TTL we replay the
    cached display + report file and skip every provider call (Skeptic,
    Pragmatist, Discovery). `--no-cache` flag forces a fresh run.
    """
    validate_plan(plan)
    plan_hash = _hash_plan(plan)

    # ── Phase 24 SP8 — domain detection (used by persona overlays + JSON output) ──
    domain = detect_domain(plan)
    _debug(f"domain detected: {domain}")

    # ── Phase 24 SP6 — pre-call cache lookup ──
    no_cache = bool(config.get("_no_cache"))
    git_head = _git_head()
    cache_key = _cache_key(plan, git_head, Path.cwd()) if not no_cache else None
    cached = _get_cached(cache_key, _cache_ttl_days(config)) if cache_key else None
    if cached:
        ts = cached.get("ts", "?")
        if config.get("_format") == "json":
            json_payload = {
                "verdict": cached.get("final_verdict"),
                "skeptic": cached.get("skeptic_decision"),
                "pragmatist": cached.get("pragmatist_decision"),
                "skeptic_text": cached.get("skeptic_verdict", ""),
                "pragmatist_text": cached.get("pragmatist_verdict", ""),
                "concerns_skeptic": _extract_concerns(cached.get("skeptic_verdict", "")),
                "concerns_pragmatist": _extract_concerns(cached.get("pragmatist_verdict", "")),
                "domain": cached.get("domain", domain),
                "plan_hash": plan_hash,
                "git_head": git_head,
                "fallback_used": {
                    "skeptic": bool(cached.get("fallback_used_skeptic", False)),
                    "pragmatist": bool(cached.get("fallback_used_pragmatist", False)),
                },
                "cache_hit": True,
                "cached_ts": ts,
            }
            print(json.dumps(json_payload, ensure_ascii=False))
            log_cache_hit(plan_hash, cached.get("final_verdict"))
            return
        print(f"\n♻️  [cached {ts}] Returning previous Council report — no API calls.")
        print("   (use --no-cache to force a fresh run)")
        print(cached.get("display_text", ""))
        scratchpad = Path.cwd() / ".claude" / "scratchpad"
        scratchpad.mkdir(parents=True, exist_ok=True)
        vp_report_path = scratchpad / "council-report.md"
        vp_report_path.write_text(cached.get("report_md", ""), encoding="utf-8")
        print(f"Report saved: {vp_report_path}")
        log_cache_hit(plan_hash, cached.get("final_verdict"))
        return

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
        f"\n{label}:\n{redact_context(body, label=label)}\n"
        for label, body in enrichment_pairs
        if body
    )

    # ── Phase 1: Context Discovery (skip if Gemini unavailable) ──
    files_content = ""
    file_paths = []
    if config.get("_gemini_available", True):
        print("\n\U0001f9e0 [Gemini]: Analyzing project structure...")

        context_prompt = f"""{compose_system_prompt("skeptic", plan, domain=domain)}

Review the project structure and the implementation plan.

PROJECT STRUCTURE:
{project_map}

PLAN: {plan}

List the file paths (comma-separated) that are critical to review for this plan.
Reply ONLY with the comma-separated list of file paths. No explanations."""

        gemini_model_eff = (
            "gemini-cli" if config["gemini"].get("mode", "cli") == "cli"
            else config["gemini"].get("model", "gemini-3-pro-preview")
        )
        if not cost_confirm_gate(context_prompt, gemini_model_eff, label="discovery"):
            print("\n⏹  Council discovery aborted by cost-confirm gate.", file=sys.stderr)
            sys.exit(2)
        files_to_read = ask_gemini(context_prompt, config)
        record_usage("validate-plan-discovery", plan_hash=plan_hash)

        if files_to_read and "/" in files_to_read and not is_error_response(files_to_read):
            file_list = [f.strip() for f in files_to_read.replace("\n", ",").split(",")]
            print(f"\U0001f4c2 Reading {len(file_list)} file(s)...")
            file_paths = get_validated_paths(file_list)
            files_content = read_files(file_list)

    # SP3 — auto-include matching tests for whichever source files Gemini picked.
    tests_for_files = get_tests_for(file_paths) if file_paths else ""
    tests_block = (
        f"\nMATCHING TESTS:\n{redact_context(tests_for_files, label='MATCHING TESTS')}\n"
        if tests_for_files else ""
    )

    # SP3 — redact files_content + git diff before sending to providers.
    files_content_redacted = redact_context(files_content, label="FILES CONTEXT") if files_content else ""
    diff_block_redacted = (
        f"\nGIT CHANGES:\n{redact_context(git_diff, label='GIT CHANGES')}" if git_diff else ""
    )

    # ── Phase 2: The Skeptic (Gemini) ──
    print("\U0001f9d0 [The Skeptic]: Challenging plan justification...")

    # In CLI mode, Gemini reads files natively via @file (no content in prompt)
    use_native_files = config["gemini"].get("mode", "cli") == "cli" and file_paths
    files_in_prompt = "" if use_native_files else (files_content_redacted if files_content_redacted else "(no files read)")

    skeptic_prompt = f"""{compose_system_prompt("skeptic", plan, domain=domain)}
{rules_block}{enrichment_block}{tests_block}

FILES CONTEXT:
{files_in_prompt}
{diff_block_redacted}

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

    # SP8 — default fallback flags so JSON output (and cache writes) always
    # carry a known shape even when a reviewer was skipped at config time.
    fallback_used_skeptic = False
    fallback_used_pragmatist = False

    if config.get("_gemini_available", True):
        gemini_model_eff = (
            "gemini-cli" if config["gemini"].get("mode", "cli") == "cli"
            else config["gemini"].get("model", "gemini-3-pro-preview")
        )
        if not cost_confirm_gate(skeptic_prompt, gemini_model_eff, label="Skeptic"):
            gemini_verdict = "Error: Skeptic call declined by cost-confirm gate"
            fallback_used_skeptic = False
        else:
            gemini_verdict, fallback_used_skeptic = call_with_fallback(
                lambda: ask_gemini(
                    skeptic_prompt, config,
                    file_paths=file_paths if use_native_files else None,
                ),
                fallback_prompt=skeptic_prompt,
                fallback_system=compose_system_prompt("skeptic", plan, domain=domain),
                config=config,
                label="Skeptic",
            )
            record_usage(
                "validate-plan-skeptic",
                verdict=(extract_verdict(gemini_verdict) if not is_error_response(gemini_verdict) else None),
                plan_hash=plan_hash,
                fallback_used=fallback_used_skeptic,
            )
    else:
        gemini_verdict = "Error: Gemini not configured (skipped per --allow-partial flow)"

    # ── Phase 3: The Pragmatist (ChatGPT) ──
    print("\U0001f528 [The Pragmatist]: Evaluating production readiness...")

    pragmatist_prompt = f"""Review this implementation plan and The Skeptic's assessment.
Do NOT repeat The Skeptic's points. Focus on what they missed or got wrong.
{rules_block}{enrichment_block}{tests_block}

FILES CONTEXT:
{files_content_redacted if files_content_redacted else "(no files read)"}
{diff_block_redacted}

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
        openai_model_eff = (
            "codex-cli" if config["openai"].get("mode") == "cli"
            else config["openai"].get("model", "gpt-5.2")
        )
        if not cost_confirm_gate(pragmatist_prompt, openai_model_eff, label="Pragmatist"):
            gpt_verdict = "Error: Pragmatist call declined by cost-confirm gate"
            fallback_used_pragmatist = False
        else:
            pragmatist_system = compose_system_prompt("pragmatist", plan, domain=domain)
            gpt_verdict, fallback_used_pragmatist = call_with_fallback(
                lambda: ask_chatgpt(pragmatist_prompt, config, system_prompt=pragmatist_system),
                fallback_prompt=pragmatist_prompt,
                fallback_system=pragmatist_system,
                config=config,
                label="Pragmatist",
            )
            record_usage(
                "validate-plan-pragmatist",
                verdict=(extract_verdict(gpt_verdict) if not is_error_response(gpt_verdict) else None),
                plan_hash=plan_hash,
                fallback_used=fallback_used_pragmatist,
            )
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

    # ── Phase 24 SP8 — JSON output mode short-circuits the markdown report ──
    if config.get("_format") == "json":
        json_payload = {
            "verdict": final_verdict,
            "skeptic": skeptic_decision,
            "pragmatist": pragmatist_decision,
            "skeptic_text": gemini_verdict,
            "pragmatist_text": gpt_verdict,
            "concerns_skeptic": _extract_concerns(gemini_verdict),
            "concerns_pragmatist": _extract_concerns(gpt_verdict),
            "domain": domain,
            "plan_hash": plan_hash,
            "git_head": git_head,
            "fallback_used": {
                "skeptic": bool(fallback_used_skeptic),
                "pragmatist": bool(fallback_used_pragmatist),
            },
            "skeptic_failed": skeptic_failed,
            "pragmatist_failed": pragmatist_failed,
            "cache_hit": False,
        }
        print(json.dumps(json_payload, ensure_ascii=False))
        # Still cache the run so a later non-JSON call hits the same content
        # hash; we just store an empty display_text since JSON consumers don't
        # need the markdown block.
        if cache_key and not (skeptic_failed and pragmatist_failed):
            _set_cached(cache_key, {
                "ts": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "plan_hash": plan_hash,
                "git_head": git_head,
                "skeptic_verdict": gemini_verdict,
                "pragmatist_verdict": gpt_verdict,
                "skeptic_decision": skeptic_decision,
                "pragmatist_decision": pragmatist_decision,
                "final_verdict": final_verdict,
                "display_text": "",
                "report_md": "",
                "domain": domain,
                "fallback_used_skeptic": bool(fallback_used_skeptic),
                "fallback_used_pragmatist": bool(fallback_used_pragmatist),
            })
        return

    # SP6 — render display block as one string so cache replay reproduces
    # identical output on a hit.
    display_text = (
        "\n" + "=" * 60 + "\n"
        + "\U0001f4cb SUPREME COUNCIL REPORT\n"
        + "=" * 60 + "\n"
        + f"\n\U0001f9d0 THE SKEPTIC (Gemini {config['gemini']['model']}):\n"
        + gemini_verdict + "\n"
        + f"\n\U0001f528 THE PRAGMATIST (ChatGPT {config['openai']['model']}):\n"
        + gpt_verdict + "\n"
    )
    display_text += (
        "\n" + "-" * 60 + "\n"
        + f"  Skeptic:    {skeptic_decision}\n"
        + f"  Pragmatist: {pragmatist_decision}\n"
        + f"  Final:      {final_verdict} — {VERDICTS[final_verdict]}\n"
        + "-" * 60 + "\n"
    )

    verdict_icons = {
        "PROCEED": "\u2705",
        "SIMPLIFY": "\U0001f4a1",
        "RETHINK": "\U0001f504",
        "SKIP": "\u26d4",
    }
    display_text += (
        f"\n{verdict_icons[final_verdict]} VERDICT: {final_verdict}\n"
        + "=" * 60 + "\n"
    )
    print(display_text)

    # Save report to scratchpad
    scratchpad = Path.cwd() / ".claude" / "scratchpad"
    scratchpad.mkdir(parents=True, exist_ok=True)
    vp_report_path = scratchpad / "council-report.md"

    # ── Phase 24 SP8 — TL;DR auto-summary at the top of the report ──
    tldr_concerns = (_extract_concerns(gemini_verdict)
                     + _extract_concerns(gpt_verdict))[:3]
    tldr_lines = ["## TL;DR", "", f"- Verdict: **{final_verdict}** — {VERDICTS[final_verdict]}"]
    if tldr_concerns:
        tldr_lines.append("- Top concerns:")
        for c in tldr_concerns:
            tldr_lines.append(f"  - {c}")
    else:
        tldr_lines.append("- No concerns extracted — see full reviewer text below.")
    tldr_lines.append(f"- Domain: {domain}")
    tldr_block = "\n".join(tldr_lines)

    report = f"""# Supreme Council Review Report

{tldr_block}

---

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

    # ── Phase 24 SP6 — store cache snapshot for future identical calls ──
    if cache_key and not (skeptic_failed and pragmatist_failed):
        _set_cached(cache_key, {
            "ts": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "plan_hash": plan_hash,
            "git_head": git_head,
            "skeptic_verdict": gemini_verdict,
            "pragmatist_verdict": gpt_verdict,
            "skeptic_decision": skeptic_decision,
            "pragmatist_decision": pragmatist_decision,
            "final_verdict": final_verdict,
            "display_text": display_text,
            "report_md": report,
        })


def _run_dry_run(plan):
    """Phase 24 SP8 — preview prompts and estimated cost without API calls.

    Builds the same context blocks that _run_validate_plan would assemble
    (project rules, README, planning context, recent commits, todos, git
    diff, redacted), runs detect_domain, composes the Skeptic and
    Pragmatist system prompts (with persona overlays), prints both prompts
    plus a cost estimate. Never calls a provider.
    """
    validate_plan(plan)
    domain = detect_domain(plan)
    project_rules = get_project_rules()
    readme = get_readme()
    planning_md = get_planning_context()
    recent_log = get_recent_log()
    todos = get_todos()
    git_diff = get_git_diff()

    enrichment_pairs = [
        ("README", readme),
        ("PLANNING CONTEXT", planning_md),
        ("RECENT COMMITS", recent_log),
        ("TODOS / FIXMES", todos),
    ]
    enrichment_budget = (MAX_TOTAL_CONTEXT * 4) // 5
    enrichment_pairs = apply_context_budget(enrichment_pairs, hard_limit=enrichment_budget)
    enrichment_block = "".join(
        f"\n{label}:\n{redact_context(body, label=label)}\n"
        for label, body in enrichment_pairs
        if body
    )
    rules_block = f"\nPROJECT RULES (CLAUDE.md):\n{project_rules}" if project_rules else ""
    diff_block = f"\nGIT CHANGES:\n{redact_context(git_diff, label='GIT CHANGES')}" if git_diff else ""

    skeptic_system = compose_system_prompt("skeptic", plan, domain=domain)
    pragmatist_system = compose_system_prompt("pragmatist", plan, domain=domain)

    skeptic_prompt = f"""{skeptic_system}
{rules_block}{enrichment_block}

IMPLEMENTATION PLAN:
{plan}
"""
    pragmatist_prompt = f"""{pragmatist_system}

(In a real run the Pragmatist also receives the Skeptic's full verdict
appended after this point; dry-run substitutes a placeholder.)

PLAN:
{plan}
"""

    pricing = _load_pricing()
    skeptic_tokens = _estimate_tokens(skeptic_prompt)
    pragmatist_tokens = _estimate_tokens(pragmatist_prompt)

    def _estimate_cost(model_key, tokens_in):
        rate = float((pricing.get(model_key) or {}).get("input_per_1m", 0.0))
        return (tokens_in / 1_000_000.0) * rate, rate

    sk_cost, sk_rate = _estimate_cost("gemini-3-pro-preview", skeptic_tokens)
    pr_cost, pr_rate = _estimate_cost("gpt-5.2", pragmatist_tokens)

    print("=" * 60)
    print("🌵 SUPREME COUNCIL DRY-RUN — no API calls will be made")
    print("=" * 60)
    print(f"Plan length:  {len(plan)} chars")
    print(f"Domain:       {domain}")
    print(f"Skeptic ~tok: {skeptic_tokens}  (gemini-3-pro-preview @ ${sk_rate:.2f}/M in -> ~${sk_cost:.4f})")
    print(f"Pragmatist ~tok: {pragmatist_tokens}  (gpt-5.2 @ ${pr_rate:.2f}/M in -> ~${pr_cost:.4f})")
    print(f"Estimated input cost: ~${sk_cost + pr_cost:.4f} (output not estimated)")
    print("=" * 60)
    print("\n--- SKEPTIC PROMPT ---\n")
    print(skeptic_prompt)
    print("\n--- PRAGMATIST PROMPT ---\n")
    print(pragmatist_prompt)
    print("\n" + "=" * 60)
    print("Dry-run complete. Re-run without --dry-run to actually call providers.")
    return 0


def _run_retro(commit_sha, config):
    """Phase 24 SP8 — retrospective post-implementation review.

    Reads the commit's diff plus a prior Council report (if any), asks
    the Pragmatist to compare what shipped against what was approved,
    and prints an ALIGNED / DRIFT / UNCLEAR verdict.

    Lookups:
      - `git show <sha>`           — body of the commit (message + diff).
      - `.claude/scratchpad/council-report.md` at HEAD~1 of <sha>, if any.
        Falls back to current scratchpad copy when the historical version
        is not in tree.

    Output is markdown to stdout; exit codes:
      0  ALIGNED, no drift detected
      0  UNCLEAR, model could not decide (still informational)
      1  DRIFT, the implementation deviates from the approved plan
      2  Setup error (no commit, git missing, model failure)
    """
    if not commit_sha:
        print("\n❌ retro mode requires --commit <sha>", file=sys.stderr)
        return 2

    # Audit M-Council: validate commit_sha as a benign revspec BEFORE handing
    # it to git. Without validation `--commit "--upload-pack=evil-server"`
    # bypasses subprocess shell=False because git itself parses the leading
    # `--flag`. Reject anything that looks like a flag, contains whitespace,
    # or contains characters outside the conservative revspec alphabet, then
    # round-trip via `git rev-parse --verify` to resolve to a canonical SHA.
    if commit_sha.startswith("-") or not re.match(r"^[A-Za-z0-9_./~^@:-]+$", commit_sha):
        print(f"\n❌ Invalid commit revspec: {commit_sha!r}", file=sys.stderr)
        return 2
    resolved_sha = run_command(
        ["git", "rev-parse", "--verify", f"{commit_sha}^{{commit}}"], timeout=5
    )
    if not resolved_sha or resolved_sha.startswith("Error"):
        print(f"\n❌ Could not resolve commit {commit_sha!r}: {resolved_sha}", file=sys.stderr)
        return 2
    commit_sha = resolved_sha.strip()

    # Pull commit body (message + diff) within MAX_GIT_DIFF cap.
    git_show = run_command(["git", "show", commit_sha], timeout=30)
    if not git_show or git_show.startswith("Error"):
        print(f"\n❌ git show {commit_sha} failed: {git_show}", file=sys.stderr)
        return 2
    git_show = _truncate(git_show, MAX_GIT_DIFF)

    # Try to recover the Council report that existed just before this commit.
    prior_report = run_command(
        ["git", "show", f"{commit_sha}~1:.claude/scratchpad/council-report.md"],
        timeout=10,
    ) or ""
    if not prior_report or prior_report.startswith("Error"):
        report_path = Path.cwd() / ".claude" / "scratchpad" / "council-report.md"
        # Audit BRAIN-MEM-01: cap read so a huge scratchpad can't OOM the
        # process (mirrors the _read_capped wave applied to other helpers).
        prior_report = _read_capped(report_path, 30000) if report_path.is_file() else ""
    prior_report = _truncate(prior_report or "(no prior Council report on file)", 30000)

    pragmatist_system = compose_system_prompt("pragmatist", git_show)
    retro_prompt = f"""{pragmatist_system}

You are reviewing whether a shipped commit matches the implementation plan
that the Council approved BEFORE the commit was made. The two inputs are:

PRIOR COUNCIL REPORT (approved plan + verdict):
{redact_context(prior_report, label='PRIOR REPORT')}

---

COMMIT {commit_sha} (full diff + message):
{redact_context(git_show, label='COMMIT')}

---

Compare what shipped against what was approved. Use this structure:

## Alignment Summary
One paragraph: did the implementation match the approved plan?

## Specific Drift (if any)
- Bullet list of concrete deviations: feature added that wasn't approved,
  approved item missing, scope expanded, etc. Empty list when fully aligned.

## Verdict
End with exactly one line:
VERDICT: ALIGNED   — implementation matches what Council approved
VERDICT: DRIFT     — implementation deviates from approved plan
VERDICT: UNCLEAR   — insufficient context to decide
"""

    if not config.get("_openai_available", True):
        print("\n❌ Pragmatist (ChatGPT) unavailable — retro mode needs at least one reviewer.", file=sys.stderr)
        return 2

    print(f"\n🔁 Retrospective review of commit {commit_sha[:12]}...")
    response, fallback_used = call_with_fallback(
        lambda: ask_chatgpt(retro_prompt, config, system_prompt=pragmatist_system),
        fallback_prompt=retro_prompt,
        fallback_system=pragmatist_system,
        config=config,
        label="Retro",
    )
    record_usage("retro", verdict=None, plan_hash=_hash_plan(commit_sha),
                 fallback_used=fallback_used)

    if is_error_response(response):
        print(f"\n❌ Retro reviewer failed: {response}", file=sys.stderr)
        return 2

    text_upper = response.upper()
    m = re.search(r"VERDICT:\s*(ALIGNED|DRIFT|UNCLEAR)", text_upper)
    verdict = m.group(1) if m else "UNCLEAR"

    print("=" * 60)
    print("🔁 SUPREME COUNCIL — RETROSPECTIVE REPORT")
    print("=" * 60)
    print(f"Commit: {commit_sha}")
    print(response)
    print("=" * 60)
    print(f"VERDICT: {verdict}")
    print("=" * 60)

    if config.get("_format") == "json":
        print(json.dumps({
            "mode": "retro",
            "commit": commit_sha,
            "verdict": verdict,
            "review_text": response,
            "fallback_used": bool(fallback_used),
        }, ensure_ascii=False))

    return 1 if verdict == "DRIFT" else 0


def cmd_stats(argv):
    """Render usage.jsonl as a human or CSV summary.

    Phase 24 Sub-Phase 4. Reads ~/.claude/council/usage.jsonl, filters by
    --day / --week / --month / --total / --since / --until, groups by
    (provider, model, mode), totals tokens + cost. Returns 0 on success and
    a non-zero exit code only on argument errors.
    """
    parser = argparse.ArgumentParser(
        prog="brain stats",
        description="Summarize Council usage from ~/.claude/council/usage.jsonl",
    )
    period = parser.add_mutually_exclusive_group()
    period.add_argument("--day", action="store_true", help="last 24h")
    period.add_argument("--week", action="store_true", help="last 7 days")
    period.add_argument("--month", action="store_true", help="last 30 days")
    period.add_argument("--total", action="store_true", help="all time (default)")
    parser.add_argument("--since", help="ISO date (YYYY-MM-DD), inclusive")
    parser.add_argument("--until", help="ISO date (YYYY-MM-DD), inclusive")
    parser.add_argument("--csv", action="store_true", help="emit CSV instead of table")
    args = parser.parse_args(argv)

    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    since_dt = None
    until_dt = None
    if args.day:
        since_dt = now - datetime.timedelta(days=1)
    elif args.week:
        since_dt = now - datetime.timedelta(days=7)
    elif args.month:
        since_dt = now - datetime.timedelta(days=30)

    if args.since:
        try:
            since_dt = datetime.datetime.strptime(args.since, "%Y-%m-%d")
        except ValueError:
            parser.error(f"--since must be YYYY-MM-DD, got {args.since!r}")
    if args.until:
        try:
            # Inclusive: end of the requested day.
            until_dt = (
                datetime.datetime.strptime(args.until, "%Y-%m-%d")
                + datetime.timedelta(days=1)
            )
        except ValueError:
            parser.error(f"--until must be YYYY-MM-DD, got {args.until!r}")

    if not USAGE_LOG_PATH.is_file():
        if args.csv:
            print("provider,model,mode,calls,tokens_in,tokens_out,cost_usd")
        else:
            print(f"No usage data yet at {USAGE_LOG_PATH}")
        return 0

    groups = {}
    total_calls = 0
    total_in = 0
    total_out = 0
    total_cost = 0.0
    skipped = 0

    with USAGE_LOG_PATH.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                skipped += 1
                continue
            ts = rec.get("ts", "")
            try:
                rec_dt = datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")
            except ValueError:
                skipped += 1
                continue
            if since_dt and rec_dt < since_dt:
                continue
            if until_dt and rec_dt >= until_dt:
                continue
            key = (
                rec.get("provider", "?"),
                rec.get("model", "?"),
                rec.get("mode", "?"),
            )
            agg = groups.setdefault(
                key, {"calls": 0, "tokens_in": 0, "tokens_out": 0, "cost_usd": 0.0}
            )
            agg["calls"] += 1
            agg["tokens_in"] += int(rec.get("tokens_in", 0))
            agg["tokens_out"] += int(rec.get("tokens_out", 0))
            agg["cost_usd"] += float(rec.get("cost_usd", 0.0))
            total_calls += 1
            total_in += int(rec.get("tokens_in", 0))
            total_out += int(rec.get("tokens_out", 0))
            total_cost += float(rec.get("cost_usd", 0.0))

    rows = sorted(
        ((p, m, mo, agg) for (p, m, mo), agg in groups.items()),
        key=lambda r: (r[0], r[1], r[2]),
    )

    if args.csv:
        print("provider,model,mode,calls,tokens_in,tokens_out,cost_usd")
        for prov, model, mode, agg in rows:
            print(
                f"{prov},{model},{mode},{agg['calls']},"
                f"{agg['tokens_in']},{agg['tokens_out']},{agg['cost_usd']:.6f}"
            )
        return 0

    period_label = (
        "last 24h" if args.day
        else "last 7 days" if args.week
        else "last 30 days" if args.month
        else "all time"
    )
    if args.since or args.until:
        s = args.since or "—"
        u = args.until or "—"
        period_label = f"since {s} until {u}"

    print(f"Council usage — {period_label}")
    print(f"  calls={total_calls}  tokens_in={total_in}  tokens_out={total_out}  cost=${total_cost:.4f}")
    if skipped:
        print(f"  ({skipped} malformed line(s) skipped)")
    if not rows:
        return 0
    header = ("provider", "model", "mode", "calls", "in", "out", "$cost")
    widths = [
        max(len(header[i]), max((len(str(_row(r, i))) for r in rows), default=0))
        for i in range(7)
    ]
    fmt = "  " + "  ".join(f"{{:<{w}}}" for w in widths)
    print(fmt.format(*header))
    print(fmt.format(*("-" * w for w in widths)))
    for r in rows:
        print(fmt.format(*[_row(r, i) for i in range(7)]))
    return 0


def cmd_clear_cache(argv):
    """Phase 24 SP6 — empty the content-hash cache directory.

    Called via `brain clear-cache` (and the /council clear-cache slash
    command). Removes every <key>.json under ~/.claude/council/cache/
    but leaves the directory itself in place. Returns 0 even when the
    cache dir doesn't exist yet — first /council on a fresh install is
    not an error.
    """
    parser = argparse.ArgumentParser(
        prog="brain clear-cache",
        description="Remove all cached Council results.",
    )
    parser.parse_args(argv)
    if not CACHE_DIR.is_dir():
        print(f"No cache to clear at {CACHE_DIR}")
        return 0
    removed = 0
    for entry in CACHE_DIR.glob("*.json"):
        try:
            entry.unlink()
            removed += 1
        except OSError as exc:
            print(f"⚠️  could not remove {entry}: {exc}", file=sys.stderr)
    print(f"Cleared {removed} cached entr{'y' if removed == 1 else 'ies'} in {CACHE_DIR}")
    return 0


def _row(group_row, idx):
    """Helper for cmd_stats table formatting."""
    prov, model, mode, agg = group_row
    if idx == 0:
        return prov
    if idx == 1:
        return model
    if idx == 2:
        return mode
    if idx == 3:
        return str(agg["calls"])
    if idx == 4:
        return str(agg["tokens_in"])
    if idx == 5:
        return str(agg["tokens_out"])
    return f"${agg['cost_usd']:.4f}"


def main():
    # Phase 24 Sub-Phase 4 — split off the stats subcommand BEFORE argparse so
    # the existing positional `plan` argument keeps backwards-compat behavior.
    if len(sys.argv) >= 2 and sys.argv[1] == "stats":
        sys.exit(cmd_stats(sys.argv[2:]))

    # Phase 24 Sub-Phase 6 — same pattern for `clear-cache`. Empties the
    # SP6 content-hash cache so the next /council run starts fresh.
    if len(sys.argv) >= 2 and sys.argv[1] == "clear-cache":
        sys.exit(cmd_clear_cache(sys.argv[2:]))

    parser = argparse.ArgumentParser(
        prog="brain",
        description=(
            "Supreme Council orchestrator. "
            "Two modes: validate-plan (default) and audit-review."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["validate-plan", "audit-review", "retro"],
        default=None,
        help="Council mode (default: validate-plan when a positional plan is given)",
    )
    parser.add_argument(
        "--report",
        default=None,
        help="Path to audit report (required when --mode audit-review)",
    )
    parser.add_argument(
        "--commit",
        default=None,
        help=(
            "Phase 24 SP8 — commit SHA for --mode retro. Council reads the "
            "commit diff + the Council report saved before the commit, then "
            "renders an ALIGNED / DRIFT / UNCLEAR verdict on whether the "
            "implementation matches what was approved."
        ),
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help=(
            "Phase 24 SP6 — bypass the content-hash cache and force a fresh "
            "Council run even when an identical request is cached."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Phase 24 SP8 — build the full Skeptic + Pragmatist prompts, "
            "print them with an estimated cost, and exit 0 without calling "
            "any provider. Use to preview cost or audit redaction."
        ),
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help=(
            "Phase 24 SP8 — output shape for validate-plan. `markdown` (default) "
            "prints the human report; `json` emits a single-line JSON object "
            "{verdict, skeptic, pragmatist, concerns, fallback_used, ...} "
            "for tooling integration."
        ),
    )
    parser.add_argument(
        "--lang",
        choices=["en", "ru", "auto"],
        default="auto",
        help=(
            "Phase 24 SP9 — Council prompt language. `auto` (default) reads "
            "~/.claude/CLAUDE.md and switches to ru when Cyrillic ratio > 0.2. "
            "`en` and `ru` force the explicit language."
        ),
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

    # Phase 24 SP9 — resolve language BEFORE any prompt is loaded so the
    # very first load_prompt() call picks the right locale.
    chosen_lang = getattr(args, "lang", "auto") or "auto"
    if chosen_lang == "auto":
        chosen_lang = detect_council_lang(default="en")
    set_council_lang(chosen_lang)
    _debug(f"council lang: {chosen_lang}")

    # Phase 24 SP8 — short-circuit into the dry-run preview before
    # load_config() so users with no Council install yet can still
    # estimate cost. dry_run still needs config for pricing rates,
    # but tolerates missing API keys.
    if getattr(args, "dry_run", False):
        if args.mode == "audit-review":
            print("\n⚠️  --dry-run is only supported in validate-plan mode.", file=sys.stderr)
            sys.exit(2)
        if not args.plan:
            print("\n❌ --dry-run requires a positional plan argument.", file=sys.stderr)
            sys.exit(1)
        sys.exit(_run_dry_run(args.plan))

    config = load_config()
    config["_no_cache"] = bool(args.no_cache)
    config["_format"] = getattr(args, "format", "markdown")

    if args.mode == "audit-review":
        if not args.report:
            parser.error("--report is required with --mode audit-review")
        rc = run_audit_review(args.report, config)
        sys.exit(rc)
    elif args.mode == "retro":
        if not args.commit:
            parser.error("--commit <sha> is required with --mode retro")
        sys.exit(_run_retro(args.commit, config))
    else:
        if not args.plan:
            print("\n❌ validate-plan mode requires a positional plan argument",
                  file=sys.stderr)
            print("Usage: python3 brain.py \"Your implementation plan\"", file=sys.stderr)
            sys.exit(1)
        _run_validate_plan(args.plan, config)


if __name__ == "__main__":
    main()
