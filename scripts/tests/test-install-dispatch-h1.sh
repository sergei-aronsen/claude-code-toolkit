#!/usr/bin/env bash
# test-install-dispatch-h1.sh — regression test for audit H1 (dispatch index mismatch).
#
# Bug: scripts/install.sh dispatch loop indexed both TK_DISPATCH_ORDER (8 fixed
# entries) and TUI_LABELS (6/7/8 dynamic — bridges are conditional) by the same
# $i. With only Codex CLI detected (IS_GEM=0, IS_COD=1), TUI_LABELS[6] was
# "codex-bridge" but TK_DISPATCH_ORDER[6] was "gemini-bridge", so the user got
# a Gemini bridge written despite no Gemini CLI and the Codex bridge silently
# never installed.
#
# This test is the canonical reproduction. It runs install.sh --yes with:
#   - PATH containing only a fake `codex` binary (no `gemini`)
#   - TK_TEST=1 + TK_DISPATCH_OVERRIDE_* no-op mocks for the 6 standard
#     components, so we don't actually invoke superpowers/gsd/etc.
#   - TK_BRIDGE_HOME sandboxed under $sandbox
#   - Pre-created $sandbox/.claude/CLAUDE.md (source bridge_create_global needs)
#
# Asserts:
#   1. install exits 0
#   2. $sandbox/.codex/AGENTS.md exists       — Codex bridge installed
#   3. $sandbox/.gemini/ does NOT exist       — Gemini bridge NOT mistakenly installed
#   4. install summary mentions codex-bridge, not gemini-bridge
#
# Usage: bash scripts/tests/test-install-dispatch-h1.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}

assert_file_exists() {
    local path="$1" label="$2"
    if [[ -f "$path" ]]; then assert_pass "$label"
    else assert_fail "$label" "missing file: $path"; fi
}

assert_dir_absent() {
    local path="$1" label="$2"
    if [[ ! -e "$path" ]]; then assert_pass "$label"
    else assert_fail "$label" "unexpected path exists: $path"; fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else assert_fail "$label" "pattern not found: $pattern"; fi
}

assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "unexpected pattern present: $pattern"
    else
        assert_pass "$label"
    fi
}

# ─────────────────────────────────────────────────
# Sandbox: $HOME, fake-bin (codex only), CLAUDE.md source
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/test-install-dispatch-h1.XXXXXX)"
trap 'rm -rf "${SANDBOX:?}"' EXIT

mkdir -p "$SANDBOX/.claude" "$SANDBOX/bin"
echo "# Sandboxed CLAUDE.md for H1 regression" > "$SANDBOX/.claude/CLAUDE.md"

# Codex shim (no gemini shim — that's the whole point).
cat > "$SANDBOX/bin/codex" <<'SHIM'
#!/bin/bash
[[ "$1" == "--version" ]] && echo "codex/0.0.test" && exit 0
exit 0
SHIM
chmod +x "$SANDBOX/bin/codex"

# No-op mock for the 6 standard dispatchers.
NOOP="$SANDBOX/noop.sh"
cat > "$NOOP" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$NOOP"

# Toolkit mock that creates a sentinel so we know the dispatch slot ran.
MOCK_TK="$SANDBOX/mock-tk.sh"
cat > "$MOCK_TK" <<EOF
#!/bin/bash
touch "$SANDBOX/.tk-sentinel"
exit 0
EOF
chmod +x "$MOCK_TK"

# Do NOT pre-create toolkit-install.json — its presence makes
# is_toolkit_installed() return true, which causes the dispatch loop
# to mark toolkit as already-installed and skip the dispatch slot.
# bridge_create_global creates the state file lazily when needed.

echo "=== H1: only codex CLI detected → install codex-bridge, NOT gemini-bridge ==="

# Filter the host PATH so install.sh's `command -v gemini` cannot find a real
# gemini installed at /opt/homebrew/bin or similar. We provide ONLY codex via
# the sandbox bin. Standard utilities (bash, grep, jq, sha256sum, etc.) come
# from /usr/bin and /bin.
SANDBOXED_PATH="$SANDBOX/bin:/usr/bin:/bin"

OUTPUT_FILE="$SANDBOX/install-output.txt"
RC=0
HOME="$SANDBOX" \
PATH="$SANDBOXED_PATH" \
TK_TEST=1 \
TK_BRIDGE_HOME="$SANDBOX" \
TK_DISPATCH_OVERRIDE_SUPERPOWERS="$NOOP" \
TK_DISPATCH_OVERRIDE_GSD="$NOOP" \
TK_DISPATCH_OVERRIDE_TOOLKIT="$MOCK_TK" \
TK_DISPATCH_OVERRIDE_SECURITY="$NOOP" \
TK_DISPATCH_OVERRIDE_RTK="$NOOP" \
TK_DISPATCH_OVERRIDE_STATUSLINE="$NOOP" \
NO_COLOR=1 \
bash "$REPO_ROOT/scripts/install.sh" --yes >"$OUTPUT_FILE" 2>&1 || RC=$?

OUTPUT="$(cat "$OUTPUT_FILE")"

assert_eq "0" "$RC" "H1.1: install.sh --yes exits 0 with codex-only PATH"

# Sentinel proves the toolkit dispatcher slot got translated correctly.
assert_file_exists "$SANDBOX/.tk-sentinel" "H1.2: toolkit dispatcher slot ran (label→name mapping survived)"

# ── Core regression assertions ──
assert_file_exists "$SANDBOX/.codex/AGENTS.md" \
    "H1.3 (REGRESSION): codex-bridge installed AGENTS.md when only codex CLI is present"

assert_dir_absent "$SANDBOX/.gemini" \
    "H1.4 (REGRESSION): gemini-bridge NOT installed (no gemini CLI on PATH)"

# Output should mention codex-bridge in the summary, not gemini-bridge.
assert_contains    "codex-bridge"  "$OUTPUT" "H1.5: summary lists codex-bridge"
assert_not_contains "gemini-bridge" "$OUTPUT" "H1.6: summary does NOT list gemini-bridge"

# ─────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────
echo ""
echo "test-install-dispatch-h1 complete: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
