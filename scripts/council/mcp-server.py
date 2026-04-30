#!/usr/bin/env python3
"""
Supreme Council — Minimal MCP server for Claude Desktop.

Phase 24 Sub-Phase 11. Wraps `brain.py::_run_validate_plan`,
`run_audit_review`, and `cmd_stats` as Model Context Protocol tools so
Claude Desktop can invoke `/council` without dropping to the terminal.

Transport: stdio JSON-RPC 2.0 (per MCP spec). No pip dependencies; uses
only the Python stdlib + `brain.py` already on disk at
~/.claude/council/brain.py.

Usage (Claude Desktop reads this from claude_desktop_config.json):
    "mcpServers": {
      "supreme-council": {
        "command": "python3",
        "args": ["~/.claude/council/mcp-server.py"]
      }
    }

Manual smoke test:
    python3 ~/.claude/council/mcp-server.py < /dev/null  # exits cleanly
"""

import io
import json
import os
import sys
import contextlib
import importlib.util
from pathlib import Path

# ─────────────────────────────────────────────────
# Brain loader — reuse the orchestrator already on disk
# ─────────────────────────────────────────────────

BRAIN_PATH = Path(__file__).parent / "brain.py"
PROTOCOL_VERSION = "2024-11-05"
SERVER_NAME = "supreme-council"
SERVER_VERSION = "0.1.0"


def _load_brain():
    """Import scripts/council/brain.py as a module without requiring it
    to live on sys.path. Falls back to None when the file is missing —
    we still serve initialize / tools/list so Claude Desktop can render
    the integration without crashing.
    """
    if not BRAIN_PATH.is_file():
        return None
    spec = importlib.util.spec_from_file_location("brain", str(BRAIN_PATH))
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception:  # noqa: BLE001 — surface failures via tool errors, not server crash
        return None
    return mod


_BRAIN = _load_brain()


# ─────────────────────────────────────────────────
# Tool implementations — wrap brain.py callables
# ─────────────────────────────────────────────────

TOOLS = [
    {
        "name": "council_validate",
        "description": (
            "Run the Skeptic + Pragmatist over an implementation plan and "
            "return the markdown report. Use BEFORE coding for non-trivial "
            "tasks (auth, payments, refactors, schema migrations)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "plan": {
                    "type": "string",
                    "description": "Plain-text implementation plan to validate.",
                },
                "lang": {
                    "type": "string",
                    "enum": ["en", "ru", "auto"],
                    "default": "auto",
                    "description": "Council prompt language. `auto` reads ~/.claude/CLAUDE.md.",
                },
                "no_cache": {
                    "type": "boolean",
                    "default": False,
                    "description": "Bypass the content-hash cache.",
                },
                "format": {
                    "type": "string",
                    "enum": ["markdown", "json"],
                    "default": "markdown",
                },
            },
            "required": ["plan"],
        },
    },
    {
        "name": "council_audit_review",
        "description": (
            "Run audit-review on a Phase-4 audit report. Mutates the report "
            "in place — Council fills the verdict slot and rewrites the "
            "council_pass YAML key. Returns the report path."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "report_path": {
                    "type": "string",
                    "description": "Absolute or repo-relative path to .claude/audits/<type>-<TIMESTAMP>.md",
                },
            },
            "required": ["report_path"],
        },
    },
    {
        "name": "council_stats",
        "description": (
            "Render usage.jsonl as a human or CSV summary. Use to verify "
            "spend, see cache hit rate, or pull a billing report."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "period": {
                    "type": "string",
                    "enum": ["day", "week", "month", "total"],
                    "default": "total",
                },
                "csv": {"type": "boolean", "default": False},
            },
        },
    },
]


def _capture_stdout(callable_):
    """Run a callable that prints to stdout and return the captured text.

    brain.py's _run_validate_plan / cmd_stats / run_audit_review write
    success output to stdout AND status/error lines to stderr (e.g.
    `print(..., file=sys.stderr)` for failed Council runs). MCP clients
    only see the returned `text` payload, so capture both streams and
    concatenate stderr into the response — otherwise a failed run looks
    like an empty success to Claude Desktop.

    Audit L7.
    """
    buf_out = io.StringIO()
    buf_err = io.StringIO()
    with contextlib.redirect_stdout(buf_out), contextlib.redirect_stderr(buf_err):
        try:
            rc = callable_()
        except SystemExit as exc:
            rc = exc.code
    text = buf_out.getvalue()
    err_text = buf_err.getvalue().strip()
    if err_text:
        # Append stderr only if it's non-empty so the success path is unchanged.
        text = (text.rstrip() + "\n\n[stderr]\n" + err_text).strip() + "\n"
    return rc, text


def tool_council_validate(args):
    if _BRAIN is None:
        raise RuntimeError("brain.py not loaded — install Council via setup-council.sh")
    plan = args.get("plan", "").strip()
    if not plan:
        raise ValueError("plan is required")
    lang = args.get("lang") or "auto"
    if lang == "auto":
        lang = _BRAIN.detect_council_lang(default="en")
    _BRAIN.set_council_lang(lang)

    config = _BRAIN.load_config()
    config["_no_cache"] = bool(args.get("no_cache", False))
    config["_format"] = args.get("format", "markdown")
    rc, out = _capture_stdout(lambda: _BRAIN._run_validate_plan(plan, config))
    return {"text": out.strip() or "(no output)", "rc": rc}


def tool_council_audit_review(args):
    if _BRAIN is None:
        raise RuntimeError("brain.py not loaded — install Council via setup-council.sh")
    report_path = args.get("report_path", "").strip()
    if not report_path:
        raise ValueError("report_path is required")
    config = _BRAIN.load_config()
    config["_format"] = "markdown"
    rc, out = _capture_stdout(lambda: _BRAIN.run_audit_review(report_path, config))
    return {"text": out.strip() or "(no output)", "rc": rc, "report_path": report_path}


def tool_council_stats(args):
    if _BRAIN is None:
        raise RuntimeError("brain.py not loaded — install Council via setup-council.sh")
    period = args.get("period", "total")
    argv = [f"--{period}"]
    if args.get("csv"):
        argv.append("--csv")
    rc, out = _capture_stdout(lambda: _BRAIN.cmd_stats(argv))
    return {"text": out.strip() or "(no output)", "rc": rc}


TOOL_DISPATCH = {
    "council_validate": tool_council_validate,
    "council_audit_review": tool_council_audit_review,
    "council_stats": tool_council_stats,
}


# ─────────────────────────────────────────────────
# JSON-RPC 2.0 over stdio
# ─────────────────────────────────────────────────

def _send(response):
    sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _error(rid, code, message):
    return {
        "jsonrpc": "2.0",
        "id": rid,
        "error": {"code": code, "message": message},
    }


def _ok(rid, result):
    return {"jsonrpc": "2.0", "id": rid, "result": result}


def handle_initialize(rid, params):
    return _ok(rid, {
        "protocolVersion": PROTOCOL_VERSION,
        "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
        "capabilities": {"tools": {}},
    })


def handle_tools_list(rid, params):
    return _ok(rid, {"tools": TOOLS})


def handle_tools_call(rid, params):
    name = (params or {}).get("name")
    arguments = (params or {}).get("arguments") or {}
    fn = TOOL_DISPATCH.get(name)
    if fn is None:
        return _error(rid, -32601, f"Unknown tool: {name}")
    try:
        result = fn(arguments)
    except Exception as exc:  # noqa: BLE001 — JSON-RPC needs a structured failure
        return _ok(rid, {
            "content": [{"type": "text", "text": f"Error: {exc}"}],
            "isError": True,
        })
    return _ok(rid, {
        "content": [{"type": "text", "text": result.get("text", "")}],
        "isError": False,
    })


HANDLERS = {
    "initialize": handle_initialize,
    "tools/list": handle_tools_list,
    "tools/call": handle_tools_call,
}


def main():
    # MCP host writes line-delimited JSON-RPC to stdin.
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError as exc:
            _send(_error(None, -32700, f"Parse error: {exc}"))
            continue
        rid = msg.get("id")
        method = msg.get("method", "")
        params = msg.get("params")
        # Notifications (no id) are fire-and-forget; we only respond to requests.
        if rid is None and method.startswith("notifications/"):
            continue
        handler = HANDLERS.get(method)
        if handler is None:
            _send(_error(rid, -32601, f"Method not found: {method}"))
            continue
        try:
            response = handler(rid, params)
        except Exception as exc:  # noqa: BLE001
            response = _error(rid, -32603, f"Internal error: {exc}")
        _send(response)


if __name__ == "__main__":
    main()
