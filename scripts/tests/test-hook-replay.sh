#!/usr/bin/env bash
# test-hook-replay.sh — fixture-based stdin replay against the 4 v6.1 advisory
# hooks (audit F-15 item 1). Each hook is invoked with synthesized JSON stdin;
# we assert advisory mode produces (a) exit 0, (b) the expected reminder text
# in the right stream (stdout for UserPromptSubmit, stderr for Stop /
# PreToolUse), (c) no permissionDecision payload, and (d) the negative case
# yields zero output. Final test verifies TK_HOOKS_DISABLE=1 silences all four.
#
# Usage: bash scripts/tests/test-hook-replay.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOKS="$REPO_ROOT/templates/global/hooks"

PRE_PLAN="$HOOKS/tk-pre-gsd-plan-council.sh"
POST_AUDIT="$HOOKS/tk-post-gsd-phase-audit.sh"
COST_WARN="$HOOKS/tk-cost-warning.sh"
PRE_SHIP="$HOOKS/tk-pre-ship-reality-check.sh"
for f in "$PRE_PLAN" "$POST_AUDIT" "$COST_WARN" "$PRE_SHIP"; do
    [ -x "$f" ] || { echo "ERROR: hook not executable at $f"; exit 1; }
done

PASS=0
FAIL=0
SKIP=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }
report_skip() { echo "SKIP: $1 — $2"; SKIP=$((SKIP+1)); }

if ! command -v jq >/dev/null 2>&1; then
    report_skip "all hook-replay tests" "jq missing"
    echo ""; echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi

# Sandbox HOME so stamp files don't pollute ~/.claude/scratchpad.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hook-replay.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"

# Helper: capture stdout, stderr, rc separately from a hook invocation.
# Usage: run_hook <hook-path> <stdin-json>; sets RC, STDOUT, STDERR
run_hook() {
    local hook="$1" payload="$2"
    local out_file err_file
    out_file=$(mktemp "${TMPDIR:-/tmp}/hookrun.XXXXXX")
    err_file=$(mktemp "${TMPDIR:-/tmp}/hookrun.XXXXXX")
    RC=0
    printf '%s' "$payload" | bash "$hook" >"$out_file" 2>"$err_file" || RC=$?
    STDOUT=$(cat "$out_file")
    STDERR=$(cat "$err_file")
    rm -f "$out_file" "$err_file"
}

# ─────────────────────────────────────────────────
# 1. tk-pre-gsd-plan-council.sh — high-stakes keyword fires advisory
# ─────────────────────────────────────────────────
run_hook "$PRE_PLAN" '{"prompt":"/gsd-plan-phase add OAuth authentication","session_id":"s1"}'
if [ "$RC" -eq 0 ] && \
   echo "$STDOUT" | grep -q "TK advisory" && \
   echo "$STDOUT" | grep -qi "auth"; then
    report_pass "pre-gsd-plan-council fires on OAuth/authentication keyword"
else
    report_fail "pre-gsd-plan-council positive" "rc=$RC stdout='${STDOUT:0:160}' stderr='${STDERR:0:160}'"
fi
# Reality check — never emits permissionDecision (UserPromptSubmit hooks shouldn't)
if echo "$STDOUT" | grep -q "permissionDecision"; then
    report_fail "pre-gsd-plan-council no deny payload" "stdout contains permissionDecision marker"
else
    report_pass "pre-gsd-plan-council emits no permissionDecision payload"
fi

# Negative — bland prompt, no /gsd-plan-phase
run_hook "$PRE_PLAN" '{"prompt":"hello world"}'
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "pre-gsd-plan-council silent on non-/gsd-plan-phase prompt"
else
    report_fail "pre-gsd-plan-council negative" "rc=$RC stdout='${STDOUT:0:120}' stderr='${STDERR:0:120}'"
fi

# /gsd-plan-phase invocation but no high-stakes keyword
run_hook "$PRE_PLAN" '{"prompt":"/gsd-plan-phase rename helper.py"}'
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "pre-gsd-plan-council silent without trigger keyword"
else
    report_fail "pre-gsd-plan-council mild prompt" "rc=$RC stdout='${STDOUT:0:120}'"
fi

# ─────────────────────────────────────────────────
# 2. tk-post-gsd-phase-audit.sh — transcript with phase-complete marker fires
# ─────────────────────────────────────────────────
TRANSCRIPT="$SANDBOX/transcript.jsonl"
{
    echo '{"role":"user","content":"/gsd-execute-phase auth"}'
    echo '{"role":"assistant","content":"Phase complete. VERIFICATION.md written."}'
} > "$TRANSCRIPT"

payload=$(jq -nc --arg t "$TRANSCRIPT" '{transcript_path:$t,session_id:"sess-positive",stop_hook_active:false}')
run_hook "$POST_AUDIT" "$payload"
if [ "$RC" -eq 0 ] && \
   echo "$STDERR" | grep -q "phase just completed" && \
   echo "$STDERR" | grep -q "/audit security"; then
    report_pass "post-gsd-phase-audit fires on /gsd-execute-phase + VERIFICATION.md"
else
    report_fail "post-gsd-phase-audit positive" "rc=$RC stdout='${STDOUT:0:160}' stderr='${STDERR:0:160}'"
fi
# Negative — transcript without execute-phase
{
    echo '{"role":"user","content":"hi"}'
    echo '{"role":"assistant","content":"hello"}'
} > "$TRANSCRIPT"
payload=$(jq -nc --arg t "$TRANSCRIPT" '{transcript_path:$t,session_id:"sess-negative",stop_hook_active:false}')
run_hook "$POST_AUDIT" "$payload"
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "post-gsd-phase-audit silent without phase markers"
else
    report_fail "post-gsd-phase-audit negative" "rc=$RC stderr='${STDERR:0:120}'"
fi
# stop_hook_active=true short-circuits even with markers
{
    echo '{"role":"user","content":"/gsd-execute-phase auth"}'
    echo '{"role":"assistant","content":"Phase complete. VERIFICATION.md written."}'
} > "$TRANSCRIPT"
payload=$(jq -nc --arg t "$TRANSCRIPT" '{transcript_path:$t,session_id:"sess-recursion-guard",stop_hook_active:true}')
run_hook "$POST_AUDIT" "$payload"
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "post-gsd-phase-audit silent when stop_hook_active=true (recursion guard)"
else
    report_fail "post-gsd-phase-audit recursion guard" "rc=$RC stderr='${STDERR:0:120}'"
fi

# ─────────────────────────────────────────────────
# 3. tk-cost-warning.sh — large transcript trips threshold
# ─────────────────────────────────────────────────
# Default threshold 200 ktok = 800000 bytes. Use override TK_COST_WARN_KTOK=1
# (4000 bytes) so the test transcript stays small.
SMALL_TRANSCRIPT="$SANDBOX/cost-small.jsonl"
LARGE_TRANSCRIPT="$SANDBOX/cost-large.jsonl"
echo '{"hi":1}' > "$SMALL_TRANSCRIPT"
# Generate ~5000 bytes
python3 -c "import sys; sys.stdout.write('x'*5000)" > "$LARGE_TRANSCRIPT"

payload=$(jq -nc --arg t "$LARGE_TRANSCRIPT" '{transcript_path:$t,session_id:"sess-cost-large",stop_hook_active:false}')
TK_COST_WARN_KTOK=1 run_hook "$COST_WARN" "$payload"
if [ "$RC" -eq 0 ] && \
   echo "$STDERR" | grep -q "session has consumed" && \
   echo "$STDERR" | grep -q "TK_COST_WARN_KTOK"; then
    report_pass "cost-warning fires when transcript > threshold"
else
    report_fail "cost-warning positive" "rc=$RC stderr='${STDERR:0:200}'"
fi

# Negative — small transcript well under threshold
payload=$(jq -nc --arg t "$SMALL_TRANSCRIPT" '{transcript_path:$t,session_id:"sess-cost-small",stop_hook_active:false}')
TK_COST_WARN_KTOK=200 run_hook "$COST_WARN" "$payload"
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "cost-warning silent under threshold"
else
    report_fail "cost-warning negative" "rc=$RC stderr='${STDERR:0:120}'"
fi

# Idempotence — second invocation with same session_id silenced by stamp file
payload=$(jq -nc --arg t "$LARGE_TRANSCRIPT" '{transcript_path:$t,session_id:"sess-cost-stamp",stop_hook_active:false}')
TK_COST_WARN_KTOK=1 run_hook "$COST_WARN" "$payload"
first_warned=$([ -n "$STDERR" ] && echo "1" || echo "0")
TK_COST_WARN_KTOK=1 run_hook "$COST_WARN" "$payload"
second_silent=$([ -z "$STDERR" ] && echo "1" || echo "0")
if [ "$first_warned" = "1" ] && [ "$second_silent" = "1" ]; then
    report_pass "cost-warning is once-per-session (stamp file gates re-fire)"
else
    report_fail "cost-warning stamp idempotence" "first=$first_warned second_silent=$second_silent"
fi

# ─────────────────────────────────────────────────
# 4. tk-pre-ship-reality-check.sh — git push to main fires advisory
# ─────────────────────────────────────────────────
run_hook "$PRE_SHIP" '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
if [ "$RC" -eq 0 ] && \
   echo "$STDERR" | grep -q "ship operation detected" && \
   echo "$STDERR" | grep -q "git push to main"; then
    report_pass "pre-ship-reality-check fires on 'git push origin main'"
else
    report_fail "pre-ship advisory positive" "rc=$RC stderr='${STDERR:0:200}'"
fi
# Default mode: never emit permissionDecision JSON
if echo "$STDOUT" | grep -q "permissionDecision"; then
    report_fail "pre-ship advisory mode no deny" "stdout contains permissionDecision JSON"
else
    report_pass "pre-ship advisory mode emits no permissionDecision (default)"
fi

# Negative — bland Bash command
run_hook "$PRE_SHIP" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "pre-ship silent on non-ship Bash command"
else
    report_fail "pre-ship negative" "rc=$RC stderr='${STDERR:0:120}'"
fi

# Non-Bash tool short-circuits
run_hook "$PRE_SHIP" '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
if [ "$RC" -eq 0 ] && [ -z "$STDOUT" ] && [ -z "$STDERR" ]; then
    report_pass "pre-ship silent for non-Bash tool"
else
    report_fail "pre-ship non-Bash" "rc=$RC stderr='${STDERR:0:120}'"
fi

# Block-mode opt-in: TK_HOOKS_BLOCK_SHIP=1 emits permissionDecision JSON to stdout, exit 0
TK_HOOKS_BLOCK_SHIP=1 run_hook "$PRE_SHIP" '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
if [ "$RC" -eq 0 ] && \
   echo "$STDOUT" | grep -q '"permissionDecision": *"deny"'; then
    report_pass "pre-ship block-mode emits permissionDecision=deny when TK_HOOKS_BLOCK_SHIP=1"
else
    report_fail "pre-ship block-mode opt-in" "rc=$RC stdout='${STDOUT:0:200}'"
fi

# ─────────────────────────────────────────────────
# 5. TK_HOOKS_DISABLE=1 silences every hook
# ─────────────────────────────────────────────────
all_silent=1
TK_HOOKS_DISABLE=1 run_hook "$PRE_PLAN" '{"prompt":"/gsd-plan-phase add OAuth"}'
[ -z "$STDOUT" ] && [ -z "$STDERR" ] && [ "$RC" -eq 0 ] || all_silent=0

payload=$(jq -nc --arg t "$LARGE_TRANSCRIPT" '{transcript_path:$t,session_id:"sess-disable-cost",stop_hook_active:false}')
TK_HOOKS_DISABLE=1 TK_COST_WARN_KTOK=1 run_hook "$COST_WARN" "$payload"
[ -z "$STDOUT" ] && [ -z "$STDERR" ] && [ "$RC" -eq 0 ] || all_silent=0

{
    echo '{"role":"user","content":"/gsd-execute-phase auth"}'
    echo '{"role":"assistant","content":"Phase complete. VERIFICATION.md written."}'
} > "$TRANSCRIPT"
payload=$(jq -nc --arg t "$TRANSCRIPT" '{transcript_path:$t,session_id:"sess-disable-audit",stop_hook_active:false}')
TK_HOOKS_DISABLE=1 run_hook "$POST_AUDIT" "$payload"
[ -z "$STDOUT" ] && [ -z "$STDERR" ] && [ "$RC" -eq 0 ] || all_silent=0

TK_HOOKS_DISABLE=1 run_hook "$PRE_SHIP" '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
[ -z "$STDOUT" ] && [ -z "$STDERR" ] && [ "$RC" -eq 0 ] || all_silent=0

if [ "$all_silent" -eq 1 ]; then
    report_pass "TK_HOOKS_DISABLE=1 silences all 4 hooks"
else
    report_fail "TK_HOOKS_DISABLE master switch" "one or more hooks emitted output despite TK_HOOKS_DISABLE=1"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
