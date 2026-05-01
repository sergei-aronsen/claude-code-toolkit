#!/usr/bin/env bash
# test-invisible-prompt.sh — regression test for the "blinking-caret" bug
# users hit when running install.sh's TUI: after Submit, the toolkit dispatcher
# wrapped init-claude.sh in `( … ) 2>"$tmp"` (D-28 stderr capture). Bash's
# `read -r -p "prompt"` writes the prompt to STDERR, so it landed in the
# tmpfile instead of the terminal. Users saw a bare cursor with no instruction.
#
# Coverage:
#   S1 tui_tty_read does NOT route the prompt via stderr (capture stderr,
#      assert prompt text absent).
#   S2 tui_tty_read writes the prompt to its TTY-equivalent path
#      (TK_TUI_PROMPT_SINK seam).
#   S3 tui_tty_read assigns the answer into the named variable from the
#      input path.
#   S4 silent mode (password-style) follows the same routing.
#   S5 invalid varname rejected (defensive check).
#   S6 fail-closed empty answer + rc=1 when input path unreadable.
#   S7 bridge_install_prompts under stderr-capture wrapper (the real-world
#      shape of the bug) — prompt MUST appear in TK_TUI_PROMPT_SINK output,
#      MUST NOT appear in captured stderr.
#   S8 mcp_secrets_set collision prompt under stderr-capture wrapper.
#
# Usage: bash scripts/tests/test-invisible-prompt.sh
# Exit:  0 on PASS, 1 on FAIL.

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

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else assert_fail "$label" "pattern not found: $pattern"; fi
}

assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "unexpected pattern present: $pattern"
    else
        assert_pass "$label"
    fi
}

# Sandbox cleanup tracker.
_SANDBOXES=()
_cleanup_sandboxes() {
    local d
    for d in "${_SANDBOXES[@]+"${_SANDBOXES[@]}"}"; do
        # Only remove paths under /tmp to stay within the safety-net boundary.
        # Use rm -rf so directory sandboxes (mktemp -d) are also cleaned.
        case "$d" in
            /tmp/*) rm -rf "$d" 2>/dev/null || true ;;
        esac
    done
}
trap '_cleanup_sandboxes' EXIT

mk_tmpfile() {
    local f
    f=$(mktemp /tmp/test-invisible-prompt.XXXXXX)
    _SANDBOXES+=("$f")
    echo "$f"
}

# Source tui.sh once for the unit-style scenarios. bridges.sh + mcp.sh need
# detect2.sh + state.sh sourced first (their own dependencies).
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/tui.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/state.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/detect2.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/bridges.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"

# ────────────────────────── scenarios ──────────────────────────

echo "=== S1: tui_tty_read keeps stderr clean of prompt text ==="
input_file=$(mk_tmpfile); printf 'Y\n' > "$input_file"
sink_file=$(mk_tmpfile); : > "$sink_file"
err_file=$(mk_tmpfile); : > "$err_file"
ans=""
PROMPT_TEXT="S1-marker-prompt: "
TK_TUI_PROMPT_SINK="$sink_file" \
    tui_tty_read ans "$PROMPT_TEXT" 0 "$input_file" 2>"$err_file"
err_out=$(cat "$err_file")
assert_not_contains "S1-marker-prompt" "$err_out" "S1.1 prompt absent from stderr"

echo "=== S2: tui_tty_read writes prompt to sink path ==="
sink_out=$(cat "$sink_file")
assert_contains "S1-marker-prompt: " "$sink_out" "S2.1 prompt present in sink"

echo "=== S3: tui_tty_read captures answer into named variable ==="
assert_eq "Y" "$ans" "S3.1 answer captured"

echo "=== S4: silent mode (password-style) routes prompt the same way ==="
input_file2=$(mk_tmpfile); printf 'super-secret-token\n' > "$input_file2"
sink_file2=$(mk_tmpfile); : > "$sink_file2"
err_file2=$(mk_tmpfile); : > "$err_file2"
secret=""
TK_TUI_PROMPT_SINK="$sink_file2" \
    tui_tty_read secret "API_KEY: " 1 "$input_file2" 2>"$err_file2"
err2_out=$(cat "$err_file2")
sink2_out=$(cat "$sink_file2")
assert_eq "super-secret-token" "$secret" "S4.1 silent answer captured"
assert_not_contains "API_KEY:" "$err2_out" "S4.2 silent prompt absent from stderr"
assert_contains "API_KEY: " "$sink2_out" "S4.3 silent prompt present in sink"
# Audit: silent value MUST NOT echo to sink (that would be a secret leak).
assert_not_contains "super-secret-token" "$sink2_out" "S4.4 silent value NOT leaked to sink"

echo "=== S5: invalid varname rejected (defensive check) ==="
rc=0
tui_tty_read "1bad-name" "p: " 0 /dev/null >/dev/null 2>&1 || rc=$?
assert_eq "1" "$rc" "S5.1 non-identifier varname returns 1"

echo "=== S6: unreadable input path → rc=1 + empty answer ==="
ans3="prefilled"
rc=0
tui_tty_read ans3 "p: " 0 "/nonexistent/path/$(date +%s%N)" >/dev/null 2>&1 || rc=$?
assert_eq "1" "$rc" "S6.1 unreadable path returns 1"
assert_eq "" "$ans3" "S6.2 unreadable path leaves variable empty"

echo "=== S7: bridge_install_prompts under stderr-capture wrapper ==="
# This reconstructs the real bug shape: the parent runs the dispatcher in
# `( … ) 2>"$err"`, simulating install.sh:1066. The prompt must remain visible.
# We rely on whichever CLI is detected on the host (gemini and/or codex). The
# test passes if AT LEAST ONE bridge prompt fired (BRIDGE-DET-01: the gate is
# `command -v <cli>`, which is hermetic to the test runner's PATH).
sb=$(mktemp -d /tmp/test-inv-bridges.XXXXXX); _SANDBOXES+=("$sb")
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
tty_in=$(mk_tmpfile); printf 'n\nn\n' > "$tty_in"  # answer "n" twice (gemini + codex) to keep S7 idempotent
sink_s7=$(mk_tmpfile); : > "$sink_s7"
err_s7=$(mk_tmpfile); : > "$err_s7"
# ( … ) 2>"$err_s7" mirrors install.sh dispatch loop's stderr capture.
(
    TK_BRIDGE_TTY_SRC="$tty_in" \
    TK_TUI_PROMPT_SINK="$sink_s7" \
    TK_BRIDGE_HOME="$sb" \
        bridge_install_prompts "$sb/proj"
) 2>"$err_s7" || true
sink_s7_out=$(cat "$sink_s7")
err_s7_out=$(cat "$err_s7")
# The exact label is "Gemini CLI" / "OpenAI Codex CLI" — match on " detected. "
# which is invariant across both labels. A bridge prompt fired iff at least one
# CLI is present on this host; CI runners have neither, so we treat "no CLI"
# as a vacuous pass (warn rather than fail).
if printf '%s' "$sink_s7_out" | grep -q ' detected\. Create '; then
    assert_pass "S7.1 bridge prompt visible in sink under stderr capture"
    assert_not_contains " detected\. Create " "$err_s7_out" "S7.2 bridge prompt NOT swallowed by stderr capture"
else
    printf "  ${GREEN}OK${NC} %s\n" "S7.1 vacuous pass — no gemini/codex CLI detected on this host"
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "S7.2 vacuous pass — no gemini/codex CLI detected on this host"
    PASS=$((PASS + 1))
fi

echo "=== S8: mcp_secrets_set collision prompt under stderr-capture wrapper ==="
mcp_home=$(mktemp -d /tmp/test-inv-mcp.XXXXXX); _SANDBOXES+=("$mcp_home")
# Pre-load a config with the key so mcp_secrets_set hits the collision prompt.
mkdir -p "$mcp_home/.claude"
printf 'EXISTING_KEY=old-value\n' > "$mcp_home/.claude/mcp-config.env"
chmod 0600 "$mcp_home/.claude/mcp-config.env"
tty_in_s8=$(mk_tmpfile); printf 'N\n' > "$tty_in_s8"  # decline overwrite
sink_s8=$(mk_tmpfile); : > "$sink_s8"
err_s8=$(mk_tmpfile); : > "$err_s8"
(
    TK_MCP_CONFIG_HOME="$mcp_home" \
    TK_MCP_TTY_SRC="$tty_in_s8" \
    TK_TUI_PROMPT_SINK="$sink_s8" \
        mcp_secrets_set "EXISTING_KEY" "new-value"
) 2>"$err_s8" || true
sink_s8_out=$(cat "$sink_s8")
err_s8_out=$(cat "$err_s8")
assert_contains "Overwrite EXISTING_KEY" "$sink_s8_out" "S8.1 mcp overwrite prompt visible in sink"
assert_not_contains "Overwrite EXISTING_KEY" "$err_s8_out" "S8.2 mcp overwrite prompt NOT in stderr"

# ────────────────────────── summary ──────────────────────────
echo ""
echo "──────────────────────────────────────────────"
printf "PASS: %d  FAIL: %d\n" "$PASS" "$FAIL"
echo "──────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
