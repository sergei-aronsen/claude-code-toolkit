"""
Repomix pack helper for Supreme Council (Phase v6.23.0).

Generates a compressed full-repo pack via `npx repomix` and exposes it as
ready-to-inject prompt context for brain.py. Designed as a soft dependency:
when `node`/`npx` are missing, every public function degrades to a no-op so
the Council falls back to the legacy targeted-file context unchanged.

Public surface used by brain.py:
    should_use_pack(args, env=None)        → bool
    build_pack_block(repo_root, args)      → dict
    pack_cache_hash(pack_text)             → str

The dict returned by build_pack_block contains:
    text         str   — XML pack contents (un-redacted; caller redacts)
    tokens       int   — estimated token count
    oversize     bool  — True if pack still > budget after auto-ignore fallback
    cached       bool  — True if reused existing artifact, False if regenerated
    path         Path  — on-disk artifact path
    error        str|None — failure reason if pack disabled / failed
"""

from __future__ import annotations

import hashlib
import ipaddress
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────

REPOMIX_VERSION = "1.14.0"

DEFAULT_CACHE_RELPATH = Path(".claude") / "scratchpad" / "repomix-pack.xml"

# Soft cap on prompt-side pack token budget. Picked to leave room for plan,
# persona overlay, system prompts, and provider response inside the smallest
# Council backend (GPT-5.x ~400k). Override via env REPOMIX_PACK_BUDGET.
BUDGET_SOFT_DEFAULT = 180_000

# Subprocess timeout for `npx repomix`. Cold npm cache fetch can take ~30s on
# slow links; 120s is generous without hanging the Council forever.
SUBPROCESS_TIMEOUT_SEC = 120

# Auto-ignore patterns applied when the first pass exceeds budget. Drops the
# usual suspects (vendor blobs, minified output, lockfiles). Layered onto
# repomix's built-in defaults via `--ignore`.
AUTO_IGNORE_OVERSIZE = ",".join([
    "**/*.lock",
    "**/*.min.*",
    "**/*.map",
    "**/dist/**",
    "**/build/**",
    "**/.next/**",
    "**/coverage/**",
    "**/__snapshots__/**",
    "**/_external/**",
    "**/vendor/**",
])

# Rough chars-per-token ratio for GPT tokenizers on English+XML text. Used
# only when repomix doesn't report a token total in its output. Empirically
# 3.6-4.2 on this toolkit; 4.0 is a safe over-estimate (errs toward
# triggering the budget gate one pass early).
CHARS_PER_TOKEN_ESTIMATE = 4

# ─────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────


def _stderr(msg: str) -> None:
    print(msg, file=sys.stderr)


def _has_node(env: dict | None = None) -> bool:
    """True when both `node` and `npx` resolve on PATH (env override-aware)."""
    if env is None:
        env = os.environ
    path = env.get("PATH", os.defpath)
    return bool(shutil.which("node", path=path) and shutil.which("npx", path=path))


def _git_tracked_files(repo_root: Path) -> list[Path]:
    """Return `git ls-files`-derived absolute paths. Empty list on failure."""
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=str(repo_root),
            capture_output=True,
            check=True,
            timeout=30,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return []
    paths = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        try:
            rel = raw.decode("utf-8")
        except UnicodeDecodeError:
            continue
        paths.append(repo_root / rel)
    return paths


def pack_is_fresh(pack_path: Path, repo_root: Path) -> bool:
    """True if pack exists and no tracked file is newer than it."""
    if not pack_path.is_file():
        return False
    try:
        pack_mtime = pack_path.stat().st_mtime
    except OSError:
        return False
    for fpath in _git_tracked_files(repo_root):
        try:
            if fpath.stat().st_mtime > pack_mtime:
                return False
        except OSError:
            continue
    return True


def _estimate_tokens(text: str) -> int:
    if not text:
        return 0
    return max(1, len(text) // CHARS_PER_TOKEN_ESTIMATE)


def _open_0600(path: Path) -> Any:
    """Open path for write with 0600 perms (atomic O_CREAT|O_EXCL semantics).

    Matches the pattern brain.py uses to keep cached LLM context out of
    other users' reach on shared machines.
    """
    flags = os.O_CREAT | os.O_WRONLY | os.O_TRUNC
    fd = os.open(str(path), flags, 0o600)
    try:
        os.fchmod(fd, 0o600)
    except OSError:
        pass
    return os.fdopen(fd, "w", encoding="utf-8")


def _run_repomix(
    argv: list[str],
    cwd: Path | None = None,
    timeout: int = SUBPROCESS_TIMEOUT_SEC,
) -> tuple[bool, str, str]:
    """Run repomix and return (ok, stdout, stderr).

    Never raises — failures land in the returned tuple with ok=False.
    """
    full_cmd = ["npx", "-y", f"repomix@{REPOMIX_VERSION}", *argv]
    try:
        proc = subprocess.run(
            full_cmd,
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return False, "", f"timeout after {timeout}s"
    except (OSError, FileNotFoundError) as exc:
        return False, "", f"subprocess failed: {exc}"
    if proc.returncode != 0:
        return False, proc.stdout, proc.stderr or f"exit code {proc.returncode}"
    return True, proc.stdout, proc.stderr


# ─────────────────────────────────────────────────
# Gating
# ─────────────────────────────────────────────────


def should_use_pack(args: Any, env: dict | None = None) -> bool:
    """Decide whether brain.py should attempt pack-augmented context.

    Default: ON. Disabled when:
      - args.no_pack is set
      - Node/npx not on PATH
      - REPOMIX_PACK_DISABLE=1 in env
    """
    if env is None:
        env = os.environ
    if getattr(args, "no_pack", False):
        return False
    if env.get("REPOMIX_PACK_DISABLE", "").strip() == "1":
        return False
    if not _has_node(env):
        return False
    return True


# ─────────────────────────────────────────────────
# Pack generation
# ─────────────────────────────────────────────────


def _budget(env: dict | None = None) -> int:
    if env is None:
        env = os.environ
    raw = env.get("REPOMIX_PACK_BUDGET", "").strip()
    if raw.isdigit():
        return int(raw)
    return BUDGET_SOFT_DEFAULT


_REMOTE_URL_ALLOWED_SCHEMES = ("https", "http")


def _validate_remote_url(url: str) -> tuple[bool, str]:
    """Gate the value passed to `repomix --remote VAL`.

    repomix forwards the value to `git clone`, which interprets any string
    starting with `-` as a flag (e.g., `--upload-pack=/bin/sh -c …`, a known
    RCE class). It also accepts non-HTTP schemes (ssh://, git+ssh://, file://)
    that we don't want to use as LLM input. This validator enforces:

      * non-empty
      * no leading `-` (defeats argv injection into git clone)
      * scheme ∈ {http, https} via urlparse
      * no embedded credentials (`user:pass@host`)
      * hostname is not localhost / private / link-local (defense in depth
        against accidental SSRF when running in a CI-like context)
    """
    if not url:
        return False, "empty remote URL"
    if url.startswith("-"):
        return False, "URL must not start with '-' (argv injection)"
    try:
        parsed = urllib.parse.urlparse(url)
    except ValueError:
        return False, "malformed URL"
    if parsed.scheme not in _REMOTE_URL_ALLOWED_SCHEMES:
        return False, f"scheme '{parsed.scheme}' not allowed (use https/http)"
    if "@" in (parsed.netloc or ""):
        return False, "URL contains embedded credentials — refuse to log"
    hostname = parsed.hostname or ""
    if not hostname:
        return False, "missing hostname"
    lowered = hostname.lower()
    if lowered in {"localhost", "0.0.0.0", "broadcasthost"}:
        return False, "localhost / broadcast addresses not allowed"
    # Reject literal private / link-local / loopback IPs. Hostnames that
    # resolve to such IPs are out of scope (repomix may itself follow a DNS
    # lookup; we don't pre-resolve to avoid TOCTOU surprises).
    try:
        ip = ipaddress.ip_address(lowered)
    except ValueError:
        ip = None
    if ip is not None and (
        ip.is_private or ip.is_loopback or ip.is_link_local
        or ip.is_multicast or ip.is_reserved or ip.is_unspecified
    ):
        return False, f"IP {lowered} is not a public address"
    return True, ""


def _generate_one_shot(
    output_path: Path,
    repo_root: Path,
    remote_url: str | None,
    extra_ignore: str | None,
) -> tuple[bool, str]:
    """Run a single repomix invocation; write stdout to output_path.

    Audit 2026-05-13 (supply-chain): when packing a local repo we used to set
    `cwd=repo_root`, which makes `npx` prefer a `node_modules/.bin/repomix`
    inside that repo over the pinned npm-registry build. A hostile project
    can ship that binary in its tree and hijack every Council invocation.
    To neutralize this, we now invoke `npx` from a directory that does NOT
    contain a node_modules tree (the system temp dir) and pass the repo path
    to repomix as a positional argument. If the repo carries its own
    `repomix.config.json`, we forward it explicitly via `--config` so
    config discovery still works.
    """
    argv = [
        "--stdout",
        "--compress",
        "--style", "xml",
        "--no-git-sort-by-changes",
    ]
    if remote_url:
        argv += ["--remote", remote_url]
    if extra_ignore:
        argv += ["--ignore", extra_ignore]

    # Per-call isolated tmpdir as cwd. This is the load-bearing defense:
    # `npx` resolves binaries from `<cwd>/node_modules/.bin/` first, so any
    # cwd that contains a hostile `node_modules/.bin/repomix` (planted in the
    # repo we are packing, or in `/tmp/node_modules/.bin/` by a same-UID
    # attacker) would hijack the call. A freshly-minted tmpdir has no
    # node_modules, forcing npx to fetch the pinned registry version.
    sandbox = tempfile.mkdtemp(prefix="council-repomix-")
    try:
        if not remote_url:
            # Local mode: pass repo_root positionally so repomix knows what
            # to pack. Forward repomix.config.json explicitly because config
            # discovery starts from cwd (now sandbox) and would otherwise
            # miss the repo's own config.
            argv.append(str(repo_root))
            cfg = repo_root / "repomix.config.json"
            if cfg.is_file():
                argv += ["--config", str(cfg)]
        ok, stdout, stderr = _run_repomix(argv, cwd=Path(sandbox))
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)
    if not ok:
        return False, stderr or "repomix invocation failed"
    if not stdout.strip():
        return False, "repomix produced empty output"
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with _open_0600(output_path) as fh:
            fh.write(stdout)
    except OSError as exc:
        return False, f"failed to write pack artifact: {exc}"
    return True, ""


def build_pack_block(repo_root: Path, args: Any) -> dict:
    """Generate or reuse the cached pack and return a brain.py-ready block.

    Caller is responsible for redaction and prompt wrapping. This module
    returns the raw XML pack plus metadata for budget gating and cache-key
    invalidation.
    """
    remote_url: str | None = getattr(args, "pack_remote", None)
    if remote_url:
        ok, reason = _validate_remote_url(remote_url)
        if not ok:
            return {
                "text": "",
                "tokens": 0,
                "oversize": False,
                "cached": False,
                "path": None,
                "error": f"--pack-remote rejected: {reason}",
            }

    cache_path = repo_root / DEFAULT_CACHE_RELPATH
    force_fresh = bool(getattr(args, "pack_fresh", False))

    # Remote packs always regenerate — local mtime check doesn't apply.
    use_cache = (
        not force_fresh
        and not remote_url
        and pack_is_fresh(cache_path, repo_root)
    )

    if use_cache:
        try:
            text = cache_path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            _stderr(f"⚠️  cached pack unreadable, regenerating: {exc}")
            use_cache = False
        else:
            tokens = _estimate_tokens(text)
            return {
                "text": text,
                "tokens": tokens,
                "oversize": tokens > _budget(),
                "cached": True,
                "path": cache_path,
                "error": None,
            }

    # Generate
    output_path = cache_path
    ok, err = _generate_one_shot(output_path, repo_root, remote_url, extra_ignore=None)
    if not ok:
        return {
            "text": "",
            "tokens": 0,
            "oversize": False,
            "cached": False,
            "path": None,
            "error": err,
        }

    text = output_path.read_text(encoding="utf-8", errors="replace")
    tokens = _estimate_tokens(text)
    budget = _budget()
    pack_force = bool(getattr(args, "pack_force", False))

    # Oversize fallback chain
    if tokens > budget and not pack_force:
        _stderr(
            f"⚠️  pack {tokens} tokens > budget {budget}, retrying with auto-ignore"
        )
        ok, err = _generate_one_shot(
            output_path, repo_root, remote_url, extra_ignore=AUTO_IGNORE_OVERSIZE
        )
        if ok:
            text = output_path.read_text(encoding="utf-8", errors="replace")
            tokens = _estimate_tokens(text)
        else:
            _stderr(f"⚠️  auto-ignore pack attempt failed: {err}")
            # Audit 2026-05-14 M-6: delete the oversize first-pass artifact
            # so the next Council call regenerates the pack instead of
            # serving the stale oversize file via pack_is_fresh() (which
            # only checks mtime, not token count).
            try:
                output_path.unlink()
            except FileNotFoundError:
                pass

    oversize = tokens > budget
    if oversize and not pack_force:
        _stderr(
            f"⚠️  pack {tokens} tokens > budget {budget} even after auto-ignore; "
            f"skipping pack injection (Council falls back to legacy context). "
            f"Pass --pack-force to send anyway, or add .repomixignore entries."
        )
        return {
            "text": "",
            "tokens": tokens,
            "oversize": True,
            "cached": False,
            "path": output_path,
            "error": f"oversize: {tokens} > {budget} tokens",
        }

    return {
        "text": text,
        "tokens": tokens,
        "oversize": oversize,
        "cached": False,
        "path": output_path,
        "error": None,
    }


def pack_cache_hash(pack_text: str) -> str:
    """Stable short hash of pack content for Council cache-key invalidation."""
    if not pack_text:
        return "no-pack"
    digest = hashlib.sha256(pack_text.encode("utf-8", errors="replace")).hexdigest()
    return digest[:16]


# ─────────────────────────────────────────────────
# CLI for smoke-testing (python3 pack.py [--remote URL])
# ─────────────────────────────────────────────────


def _cli_main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Standalone smoke-test for pack.py")
    parser.add_argument("--repo-root", default=".", help="Repo root (default: cwd)")
    parser.add_argument("--no-pack", action="store_true")
    parser.add_argument("--pack-force", action="store_true")
    parser.add_argument("--pack-fresh", action="store_true")
    parser.add_argument("--pack-remote", default=None)
    args = parser.parse_args()

    if not should_use_pack(args):
        _stderr("pack disabled (no Node or --no-pack)")
        return 1
    result = build_pack_block(Path(args.repo_root).resolve(), args)
    if result["error"]:
        _stderr(f"error: {result['error']}")
        return 2
    print(
        f"path={result['path']} tokens≈{result['tokens']} "
        f"cached={result['cached']} oversize={result['oversize']} "
        f"hash={pack_cache_hash(result['text'])}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(_cli_main())
