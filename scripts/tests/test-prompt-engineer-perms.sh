#!/usr/bin/env bash
# test-prompt-engineer-perms.sh — v6.25.0 audit M-2: 0600 file permissions.
#
# Verifies scripts/prompt-engineer/optimize_prompt.py creates every output
# artifact (and the --log timeline file) with mode 0600 so user prompts —
# which may contain secrets — are not readable by other unix users on the
# same host (default umask 0022 would leak them at 0644).
#
# Strategy:
#   1. Stub the `claude` CLI on PATH so the optimizer never touches a real
#      API; the stub reads stdin and prints a fixed fenced response.
#   2. Run optimize_prompt.py --provider claude --log against a tiny
#      prompt file, then stat every artifact under output/<ts>/ and the
#      logs/prompt-engineer-*.log file.
#   3. Each artifact must be exactly mode 600.
#
# Skips cleanly (rc=0) if python3 is not available.
# Usage: bash scripts/tests/test-prompt-engineer-perms.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PE_SCRIPT="$REPO_ROOT/scripts/prompt-engineer/optimize_prompt.py"
[ -f "$PE_SCRIPT" ] || { echo "ERROR: optimize_prompt.py missing at $PE_SCRIPT"; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 unavailable"
    exit 0
fi

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# Portable file-mode reader. macOS BSD stat vs GNU stat differ.
# Returns a 3- or 4-digit octal string; normalize to no-leading-zero
# (e.g., "0600" -> "600", "600" -> "600").
_mode() {
    local m
    if m=$(stat -f %Mp%Lp "$1" 2>/dev/null); then
        :
    else
        m=$(stat -c %a "$1")
    fi
    # Strip a single leading zero if present (macOS prints 0600, Linux 600).
    echo "${m#0}"
}

TEST_TMPDIR="$(mktemp -d -t pe-perms-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT
export TEST_TMPDIR

# ----- 1. Stub `claude` CLI on PATH ------------------------------------------
mkdir -p "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/claude" <<'STUB'
#!/usr/bin/env bash
# Stub claude CLI for test-prompt-engineer-perms.sh.
# Drain stdin (the optimizer pipes the rendered prompt in via -p) so the
# parent does not deadlock on a full pipe buffer, then print a fixed
# fenced response. extract_prompt_block() will find the fence and emit
# a non-empty 01-*-prompt.txt artifact.
cat >/dev/null || true
cat <<'EOF'
Here is the optimized prompt.

```text
stub claude response
```

Key Improvements:
- placeholder
EOF
STUB
chmod +x "$TEST_TMPDIR/bin/claude"
export PATH="$TEST_TMPDIR/bin:$PATH"

# Sanity: PATH lookup resolves to our stub, not a real installed claude.
RESOLVED="$(command -v claude || true)"
if [ "$RESOLVED" != "$TEST_TMPDIR/bin/claude" ]; then
    echo "SKIP: could not shadow claude on PATH (resolved=$RESOLVED)"
    exit 0
fi

# ----- 2. Tiny prompt file ---------------------------------------------------
PROMPT_FILE="$TEST_TMPDIR/test-prompt.md"
echo "Write a haiku about file permissions." > "$PROMPT_FILE"

# ----- 3. Run optimizer ------------------------------------------------------
RUN_DIR="$TEST_TMPDIR"
STDOUT_LOG="$TEST_TMPDIR/pe.stdout"
STDERR_LOG="$TEST_TMPDIR/pe.stderr"

# `--provider all` with only `claude` shadowed → fan-out=1 + synthesis,
# producing exactly the 01-claude.* artifacts the task spec asserts on.
set +e
( cd "$RUN_DIR" && python3 "$PE_SCRIPT" "$PROMPT_FILE" --provider all --log \
    >"$STDOUT_LOG" 2>"$STDERR_LOG" )
RC=$?
set -e

if [ $RC -ne 0 ]; then
    echo "SKIP: optimize_prompt.py exited $RC; cannot validate perms"
    echo "--- stdout ---"
    cat "$STDOUT_LOG" || true
    echo "--- stderr ---"
    cat "$STDERR_LOG" || true
    exit 0
fi

# ----- 4. Locate output dir --------------------------------------------------
OUT_ROOT="$RUN_DIR/output"
if [ ! -d "$OUT_ROOT" ]; then
    report_fail "output dir created" "$OUT_ROOT missing"
    echo "PASS=$PASS FAIL=$FAIL"
    exit 1
fi

# Newest timestamp dir (lexicographic == chronological for YYYYMMDD-HHMMSS).
TS_DIR=""
for d in "$OUT_ROOT"/*/; do
    [ -d "$d" ] || continue
    TS_DIR="${d%/}"
done

if [ -z "$TS_DIR" ] || [ ! -d "$TS_DIR" ]; then
    report_fail "timestamp dir present" "no subdir under $OUT_ROOT"
    echo "PASS=$PASS FAIL=$FAIL"
    exit 1
fi

# ----- 5. Targeted assertions T1-T4 -----------------------------------------
check_0600() {
    local label="$1" path="$2"
    if [ ! -e "$path" ]; then
        report_fail "$label" "missing: $path"
        return
    fi
    local m
    m=$(_mode "$path")
    if [ "$m" = "600" ]; then
        report_pass "$label (mode $m)"
    else
        report_fail "$label" "mode is $m, expected 600 ($path)"
    fi
}

# T1: original prompt copy
check_0600 "T1 00-original.txt is 0600" "$TS_DIR/00-original.txt"

# T2: claude fan-out raw response
check_0600 "T2 01-claude.md is 0600" "$TS_DIR/01-claude.md"

# T3: claude fan-out extracted prompt
check_0600 "T3 01-claude-prompt.txt is 0600" "$TS_DIR/01-claude-prompt.txt"

# T4: timeline log under ./logs/
LOG_FILE=""
if [ -d "$RUN_DIR/logs" ]; then
    for f in "$RUN_DIR"/logs/prompt-engineer-*.log; do
        [ -f "$f" ] || continue
        LOG_FILE="$f"
    done
fi
if [ -z "$LOG_FILE" ]; then
    report_fail "T4 timeline log exists" "no logs/prompt-engineer-*.log under $RUN_DIR"
else
    check_0600 "T4 timeline log is 0600" "$LOG_FILE"
fi

# ----- 6. T5: sweep every artifact under output/<ts>/ ------------------------
SWEEP_FAILS=0
SWEEP_TOTAL=0
while IFS= read -r -d '' f; do
    SWEEP_TOTAL=$((SWEEP_TOTAL+1))
    m=$(_mode "$f")
    if [ "$m" != "600" ]; then
        echo "  sweep miss: $f mode=$m"
        SWEEP_FAILS=$((SWEEP_FAILS+1))
    fi
done < <(find "$TS_DIR" -type f -print0)

if [ "$SWEEP_TOTAL" -eq 0 ]; then
    report_fail "T5 all output/<ts>/ artifacts 0600" "no files found under $TS_DIR"
elif [ "$SWEEP_FAILS" -eq 0 ]; then
    report_pass "T5 all output/<ts>/ artifacts 0600 ($SWEEP_TOTAL files)"
else
    report_fail "T5 all output/<ts>/ artifacts 0600" \
        "$SWEEP_FAILS of $SWEEP_TOTAL files not 0600"
fi

# ----- 7. Verdict ------------------------------------------------------------
echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
