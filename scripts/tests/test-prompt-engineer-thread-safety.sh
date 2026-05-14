#!/usr/bin/env bash
# test-prompt-engineer-thread-safety.sh
#
# Audit 2026-05-14 M-4 regression test.
#
# scripts/prompt-engineer/optimize_prompt.py:TimelineLogger is shared
# across 3 ThreadPoolExecutor workers in the --provider all run-all
# path. Each public writer (step/section/kv/block/event/close) emits
# multiple _w() lines per call; without an internal threading.Lock
# the records from different threads interleave and the resulting
# timeline log is corrupt (e.g. ">>> open A" lines from worker A
# appear between ">>> open B" / "<<< close B" lines from worker B).
#
# This test spawns 3 threads x 30 block() calls against a single
# TimelineLogger and asserts that every ">>> W_X_NN (... chars) >>>"
# open marker is closed by its matching "<<< END W_X_NN <<<" line
# BEFORE the next open marker appears.
#
# This test would FAIL on a pre-M-4 TimelineLogger without the
# threading.Lock — proof of fix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }

# Skip cleanly if python3 is unavailable on this host.
if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not available"
    exit 0
fi

echo "=== M-4: TimelineLogger thread safety ==="

cd "${REPO_ROOT}"

# Capture python output so the bash layer can assert on it.
PY_OUT="$(mktemp)"
PY_ERR="$(mktemp)"
trap 'rm -f "${PY_OUT}" "${PY_ERR}"' EXIT

set +e
python3 - >"${PY_OUT}" 2>"${PY_ERR}" <<'PY'
import sys
import tempfile
import threading
import time
import re
from pathlib import Path

sys.path.insert(0, "scripts/prompt-engineer")
from optimize_prompt import TimelineLogger

with tempfile.TemporaryDirectory() as d:
    log = Path(d) / "concurrent.log"
    tl = TimelineLogger(log)

    def worker(name, jitter):
        time.sleep(jitter)
        for i in range(30):
            tl.block(
                f"W_{name}_{i:02d}",
                f"body for {name}#{i}\nl2\nl3\nl4\nl5",
                max_chars=4000,
            )

    threads = [
        threading.Thread(target=worker, args=("A", 0.0)),
        threading.Thread(target=worker, args=("B", 0.005)),
        threading.Thread(target=worker, args=("C", 0.002)),
    ]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    tl.close()
    content = log.read_text()

# Parse for interleave: every ">>> W_X_NN (... chars) >>>" must be
# closed by "<<< END W_X_NN <<<" BEFORE the next ">>> W_..." opens.
open_block = None
errors = 0
for ln in content.split("\n"):
    m_o = re.match(r">>> (W_\S+) \(\d+ chars\) >>>", ln)
    m_c = re.match(r"<<< END (W_\S+) <<<", ln)
    if m_o:
        if open_block is not None:
            print(
                f"INTERLEAVE: opened {m_o.group(1)} while {open_block} "
                f"still open",
                file=sys.stderr,
            )
            errors += 1
        open_block = m_o.group(1)
    elif m_c:
        if open_block != m_c.group(1):
            print(
                f"MISMATCH: close {m_c.group(1)} != open {open_block}",
                file=sys.stderr,
            )
            errors += 1
        open_block = None

if errors:
    sys.exit(1)

# 3 threads x 30 blocks = 90 blocks total.
opens = len(re.findall(r">>> W_\S+ \(\d+ chars\) >>>", content))
if opens != 90:
    print(f"expected 90 blocks, found {opens}", file=sys.stderr)
    sys.exit(2)

print("ok")
PY
PY_RC=$?
set -e

if [ "${PY_RC}" -eq 0 ] && grep -q '^ok$' "${PY_OUT}"; then
    pass "90 block() records from 3 threads landed atomically (no interleave, no mismatch)"
else
    fail "TimelineLogger concurrent writes corrupted (rc=${PY_RC})"
    if [ -s "${PY_ERR}" ]; then
        echo "  --- python stderr ---" >&2
        sed 's/^/    /' "${PY_ERR}" >&2
    fi
    if [ -s "${PY_OUT}" ]; then
        echo "  --- python stdout ---" >&2
        sed 's/^/    /' "${PY_OUT}" >&2
    fi
fi

echo ""
echo "PASS=${PASS} FAIL=${FAIL}"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
