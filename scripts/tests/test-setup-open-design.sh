#!/usr/bin/env bash
# test-setup-open-design.sh — argument parsing + dry-run guards for
# scripts/setup-open-design.sh.
#
# These tests never touch Docker, the network, or git remotes. They cover:
#   1. --help exits 0 with banner
#   2. Unknown flag rejected
#   3. Bad --mode rejected
#   4. Bad --port rejected (non-numeric AND out-of-range)
#   5. Path-traversal --dir rejected
#   6. --stop --mode docker against a non-existent INSTALL_DIR is a no-op
#      (warns but exits 0)
#   7. --dry-run honors $OPEN_DESIGN_DIR env override
#   8. Pre-flight catches missing docker (in --mode docker via PATH=)
#   9. --port 7456 default does NOT write deploy/.env (only non-default ports do)
#
# Usage: bash scripts/tests/test-setup-open-design.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/setup-open-design.sh"
[ -f "$SCRIPT" ] || { echo "ERROR: setup-open-design.sh missing"; exit 1; }

PASS=0
FAIL=0
SKIP=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }
report_skip() { echo "SKIP: $1 — $2"; SKIP=$((SKIP+1)); }

# Sandbox dir so --stop probes don't accidentally read a real $HOME/open-design.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/setup-od.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

# ─────────────────────────────────────────────────
# 1. --help exits 0 with banner
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --help 2>&1)
rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "Usage: bash scripts/setup-open-design.sh"; then
    report_pass "--help prints banner + exits 0"
else
    report_fail "--help banner" "rc=$rc, output: ${out:0:200}"
fi

# ─────────────────────────────────────────────────
# 2. Unknown flag rejected
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --bogus 2>&1 || true)
if echo "$out" | grep -q "unknown argument"; then
    report_pass "unknown flag rejected"
else
    report_fail "unknown flag" "expected 'unknown argument', got: ${out:0:160}"
fi

# ─────────────────────────────────────────────────
# 3. Bad --mode rejected
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --mode podman --dry-run 2>&1 || true)
if echo "$out" | grep -qF -- "--mode must be 'docker' or 'source'"; then
    report_pass "bad --mode rejected"
else
    report_fail "bad --mode" "expected mode validation error, got: ${out:0:160}"
fi

# ─────────────────────────────────────────────────
# 4. Bad --port rejected (non-numeric)
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --port abc --dry-run 2>&1 || true)
if echo "$out" | grep -q "port must be 1-65535"; then
    report_pass "non-numeric --port rejected"
else
    report_fail "bad --port (string)" "expected port validation error, got: ${out:0:160}"
fi

# Bad --port (out of range)
out=$(bash "$SCRIPT" --port 99999 --dry-run 2>&1 || true)
if echo "$out" | grep -q "port must be 1-65535"; then
    report_pass "out-of-range --port rejected"
else
    report_fail "bad --port (range)" "expected port validation error, got: ${out:0:160}"
fi

# ─────────────────────────────────────────────────
# 5. Path-traversal --dir rejected
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --dir "$SANDBOX/../escape" --dry-run 2>&1 || true)
if echo "$out" | grep -q "must not contain '..'"; then
    report_pass "path-traversal --dir rejected"
else
    report_fail "path traversal" "expected '..' rejection, got: ${out:0:160}"
fi

# ─────────────────────────────────────────────────
# 6. --stop --mode docker against missing INSTALL_DIR is a no-op
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --stop --mode docker --dir "$SANDBOX/no-such-clone" 2>&1)
rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "no deploy/ found"; then
    report_pass "--stop on missing dir warns + exits 0"
else
    report_fail "--stop missing-dir" "rc=$rc, out: ${out:0:200}"
fi

# ─────────────────────────────────────────────────
# 7. OPEN_DESIGN_DIR env override is honored
# ─────────────────────────────────────────────────
out=$(OPEN_DESIGN_DIR="$SANDBOX/env-override" bash "$SCRIPT" --stop --mode docker 2>&1)
if echo "$out" | grep -qF "$SANDBOX/env-override"; then
    report_pass "OPEN_DESIGN_DIR env override applies"
else
    report_fail "env override" "expected '$SANDBOX/env-override' in output, got: ${out:0:200}"
fi

# ─────────────────────────────────────────────────
# 8. --mode docker fails fast on missing docker
# ─────────────────────────────────────────────────
# Use PATH that contains only the bare minimum so 'docker' is missing.
# Keep coreutils + sh + git so pre-flight can read git.
MINIMAL_PATH="/usr/bin:/bin"
if ! PATH="$MINIMAL_PATH" command -v git >/dev/null 2>&1; then
    report_skip "missing-docker pre-flight" "git not present at $MINIMAL_PATH on this host"
else
    out=$(PATH="$MINIMAL_PATH" bash "$SCRIPT" --dry-run --mode docker --dir "$SANDBOX/probe-docker" 2>&1 || true)
    if echo "$out" | grep -q "docker not found"; then
        report_pass "missing-docker preflight error fires under --dry-run"
    else
        report_fail "missing-docker preflight" "expected 'docker not found', got: ${out:0:200}"
    fi
fi

# ─────────────────────────────────────────────────
# 9. Default --port 7456 does NOT write deploy/.env
# ─────────────────────────────────────────────────
# We only inspect the dry-run output: the script announces .env writes
# only when PORT differs from 7456. With default port the announcement
# string must NOT appear.
out=$(bash "$SCRIPT" --dry-run --mode docker --port 7456 --dir "$SANDBOX/default-port" 2>&1 || true)
if ! echo "$out" | grep -q "wrote .* OPEN_DESIGN_PORT="; then
    report_pass "default --port 7456 does not announce .env write"
else
    report_fail "default port .env" "unexpected .env announcement on default port: ${out:0:200}"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
