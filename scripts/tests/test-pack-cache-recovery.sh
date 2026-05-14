#!/usr/bin/env bash
# test-pack-cache-recovery.sh — v6.25.0 audit M-6 regression guard
#
# Audit 2026-05-14 M-6: `scripts/council/pack.py::build_pack_block` previously
# left an oversize first-pass repomix artifact at `cache_path` on disk after
# the auto-ignore retry failed. The next Council invocation's
# `pack_is_fresh()` mtime check would then return True and serve the stale
# oversize pack forever (without ever re-running repomix).
#
# Fix: after retry-fail, `output_path.unlink()` the stale artifact so the
# next call has nothing to mtime-cache against and regenerates from scratch.
#
# This test monkey-patches `_generate_one_shot` via `unittest.mock` to
# simulate the exact retry-fail path without spawning a real `repomix`
# subprocess, then asserts (a) the artifact is unlinked, and (b) a second
# `build_pack_block()` call invokes `_generate_one_shot` again.

set -euo pipefail

PASS=0
FAIL=0

_p() { PASS=$((PASS + 1)); echo "PASS $*"; }
_f() { FAIL=$((FAIL + 1)); echo "FAIL $*" >&2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 unavailable"
    exit 0
fi

# Resolve repo root so the test can be invoked from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PYTHON_OUT="$(cd "$REPO_ROOT" && python3 <<'PY' 2>/dev/null
import sys
import tempfile
import types
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, "scripts/council")
import pack  # noqa: E402


def run() -> str:
    with tempfile.TemporaryDirectory() as d:
        repo_root = Path(d).resolve()
        # build_pack_block computes cache_path as
        #     repo_root / DEFAULT_CACHE_RELPATH
        # i.e. <repo_root>/.claude/scratchpad/repomix-pack.xml
        cache = repo_root / pack.DEFAULT_CACHE_RELPATH

        # Sentinel payloads. `big` exceeds the patched 1000-token budget;
        # `small` fits comfortably.
        big = "x" * 5_000_000
        small = "y" * 100

        calls: list[str | None] = []

        def fake_one_shot(output_path, repo, url, extra_ignore=None):
            # Mirror real _generate_one_shot: ensure parent dir exists.
            output_path.parent.mkdir(parents=True, exist_ok=True)
            calls.append(extra_ignore)
            if len(calls) == 1:
                # First-pass: succeed but write oversize content.
                output_path.write_text(big, encoding="utf-8")
                return True, ""
            if len(calls) == 2:
                # Auto-ignore retry: fail. Per the M-6 fix, build_pack_block
                # must now unlink output_path before returning.
                return False, "simulated repomix timeout"
            if len(calls) == 3:
                # Second outer call regenerates and fits the budget.
                output_path.write_text(small, encoding="utf-8")
                return True, ""
            return False, f"unexpected call #{len(calls)}"

        # Minimal args namespace satisfying build_pack_block's attr lookups.
        args = types.SimpleNamespace(
            pack_remote=None,
            pack_fresh=False,
            pack_force=False,
        )

        with patch.object(pack, "_generate_one_shot", side_effect=fake_one_shot), \
             patch.object(pack, "_budget", return_value=1000), \
             patch.object(pack, "pack_is_fresh", return_value=False):

            # ── Call 1: oversize + retry-fail. M-6 fix should unlink cache.
            result1 = pack.build_pack_block(repo_root, args)
            if not result1["oversize"]:
                return (
                    "call-1 should report oversize=True, "
                    f"got oversize={result1['oversize']} tokens={result1['tokens']}"
                )
            if cache.exists():
                return (
                    "M-6 REGRESSION: cache_path still present after "
                    f"retry-fail: {cache}"
                )
            if len(calls) != 2:
                return (
                    "expected 2 _generate_one_shot invocations on call-1 "
                    f"(first-pass + retry), got {len(calls)}"
                )

            # ── Call 2: cache is gone, so build_pack_block must regenerate.
            result2 = pack.build_pack_block(repo_root, args)
            if result2["oversize"]:
                return (
                    "call-2 should fit budget (small payload), "
                    f"got oversize=True tokens={result2['tokens']}"
                )
            if len(calls) != 3:
                return (
                    "call-2 should trigger a 3rd _generate_one_shot "
                    f"(regenerate from scratch), got total calls={len(calls)}"
                )
            if result2["error"] is not None:
                return f"call-2 returned unexpected error: {result2['error']!r}"

    return "OK"


print(run())
PY
)" || true

if [[ "$PYTHON_OUT" == "OK" ]]; then
    _p "M-6: oversize cache unlinked after retry-fail + regenerated on next call"
else
    _f "M-6: $PYTHON_OUT"
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
