#!/usr/bin/env bash
# test-mcp-wizard.sh — Task 2 (Plan 25-02) TDD RED phase.
# Tests mcp_wizard_run (to be added to scripts/lib/mcp.sh).
# All assertions here FAIL before implementation (TDD RED gate).
#
# Usage: bash scripts/tests/test-mcp-wizard.sh
# Exit:  0 = all assertions passed, 1 = any failed

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
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "pattern unexpectedly found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    else
        assert_pass "$label"
    fi
}

# Cross-platform 0600 mode check — copied verbatim from test-project-secrets.sh:52-60
# (Phase 38 plan 38-03). Echoes "1" when mode is exactly 0600, "0" otherwise.
mode_is_0600() {
    local f="$1"
    if stat -f %Mp%Lp "$f" 2>/dev/null | grep -q "^0600$"; then
        echo "1"; return 0
    elif [ "$(stat -c %a "$f" 2>/dev/null)" = "600" ]; then
        echo "1"; return 0
    fi
    echo "0"
}

printf "=== mcp-wizard tests (Plan 25-02 Task 2) ===\n"

SANDBOX="$(mktemp -d /tmp/mcp-wizard.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# Phase 38 (TK_PROJECT_ROOT seam — plan 38-03): hermetic project dir for
# project-scope tests. Each project-scope test rm -rf + mkdir -p $PROJECT before
# running so each assertion sees a clean directory (no carry-over from a
# previous test's .env / .gitignore).
PROJECT="$SANDBOX/myproj"
mkdir -p "$PROJECT"

# Build a mock claude binary that records argv + env to a file. Phase 38
# extension: parses --scope <value> distinctly (writes a `scope:<value>` line
# to claude.argv) so DISP-01/02/03 tests can grep `scope:project` /
# `scope:user` directly without scanning the full argv string.
cat > "$SANDBOX/claude" <<'MOCK'
#!/bin/bash
# Mock claude binary — records argv + env + parsed scope to $SANDBOX/claude.argv.
printf 'argv:' > "$SANDBOX/claude.argv"
for a in "$@"; do printf ' %s' "$a"; done >> "$SANDBOX/claude.argv"
printf '\n' >> "$SANDBOX/claude.argv"
# Parse --scope <value> distinctly — emit a `scope:<value>` line.
_scope_seen=""
_prev=""
for a in "$@"; do
    if [[ "$_prev" == "--scope" || "$_prev" == "-s" ]]; then
        _scope_seen="$a"
    fi
    _prev="$a"
done
printf 'scope:%s\n' "$_scope_seen" >> "$SANDBOX/claude.argv"
printf 'env:CTX=%s\n' "${CONTEXT7_API_KEY:-}" >> "$SANDBOX/claude.argv"
printf 'env:SENTRY=%s\n' "${SENTRY_AUTH_TOKEN:-}" >> "$SANDBOX/claude.argv"
exit 0
MOCK
# Inject SANDBOX into the mock at write time (heredoc can't expand inside MOCK quotes).
sed -i.bak "s|\\\$SANDBOX|${SANDBOX}|g" "$SANDBOX/claude"
chmod +x "$SANDBOX/claude"
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"
mcp_catalog_load

# ── Test 1: --dry-run with zero-config MCP — no claude invocation, prints "would run" ──
# Note: zero-config = no env_var_keys + no requires_oauth. After 33-04 dropped
# sequential-thinking, `playwright` is the only catalog entry that fits.
OUTPUT=$(mcp_wizard_run playwright --dry-run 2>&1)
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_fail "T1: dry-run must not invoke claude" "claude.argv exists"
else
    assert_pass "T1: dry-run must not invoke claude"
fi
assert_contains "would run" "$OUTPUT" "T1: dry-run output contains 'would run'"

# ── Test 2: zero-config MCP invocation populates argv correctly ───────────────
rm -f "$SANDBOX/claude.argv"
mcp_wizard_run playwright
if [[ -f "$SANDBOX/claude.argv" ]]; then
    assert_pass "T2: claude was invoked for playwright"
else
    assert_fail "T2: claude was invoked for playwright" "claude.argv missing"
fi
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "argv:" "$ARGV_CONTENT" "T2: argv line present"
assert_contains "mcp" "$ARGV_CONTENT" "T2: argv contains 'mcp'"
assert_contains "add" "$ARGV_CONTENT" "T2: argv contains 'add'"
assert_contains "playwright" "$ARGV_CONTENT" "T2: argv contains 'playwright'"
# Phase 37: default scope is `user` (global) — must appear before the MCP name.
assert_contains "scope user" "$ARGV_CONTENT" "T2: argv contains default '--scope user'"
rm -f "$SANDBOX/claude.argv"

# ── Test 2b: TK_MCP_SCOPE=local override emits '--scope local' ────────────────
TK_MCP_SCOPE=local mcp_wizard_run playwright
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "scope local" "$ARGV_CONTENT" "T2b: TK_MCP_SCOPE=local emits '--scope local'"
rm -f "$SANDBOX/claude.argv"

# ── Test 2c: invalid TK_MCP_SCOPE falls back to default 'user' ───────────────
TK_MCP_SCOPE=bogus mcp_wizard_run playwright
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "scope user" "$ARGV_CONTENT" "T2c: invalid scope falls back to 'user'"
rm -f "$SANDBOX/claude.argv"

# ── Test 2d: --dry-run output advertises the scope flag ──────────────────────
DRY_OUTPUT=$(mcp_wizard_run playwright --dry-run 2>&1)
assert_contains "scope user" "$DRY_OUTPUT" "T2d: dry-run preview shows '--scope user'"

# ── Test 2e: scope helpers — toggle flips state and refreshes header ─────────
TK_MCP_SCOPE=user
mcp_render_scope_header
HDR_BEFORE="${TUI_HEADER_TEXT:-}"
mcp_toggle_scope
assert_eq "local" "${TK_MCP_SCOPE}" "T2e: mcp_toggle_scope flips user → local"
mcp_toggle_scope
assert_eq "user" "${TK_MCP_SCOPE}" "T2e: mcp_toggle_scope flips local → user"
HDR_AFTER="${TUI_HEADER_TEXT:-}"
if [[ "$HDR_BEFORE" == "$HDR_AFTER" && -n "$HDR_BEFORE" ]]; then
    assert_pass "T2e: render_scope_header repopulated TUI_HEADER_TEXT after toggle round-trip"
else
    assert_fail "T2e: render_scope_header repopulated TUI_HEADER_TEXT after toggle round-trip" \
                "before='${HDR_BEFORE}' after='${HDR_AFTER}'"
fi
unset TK_MCP_SCOPE TUI_HEADER_TEXT HDR_BEFORE HDR_AFTER

# ── Test 3: keyed MCP (context7) — env var plumbed to claude + secret persisted ──
printf 'test_secret_ctx7\n' > "$SANDBOX/tty.fix"
TK_MCP_TTY_SRC="$SANDBOX/tty.fix" mcp_wizard_run context7
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "env:CTX=test_secret_ctx7" "$ARGV_CONTENT" "T3: CONTEXT7_API_KEY plumbed to claude"
# Secret persisted to mcp-config.env
cfg_file="$SANDBOX/.claude/mcp-config.env"
if [[ -f "$cfg_file" ]] && grep -q "^CONTEXT7_API_KEY=test_secret_ctx7$" "$cfg_file"; then
    assert_pass "T3: secret persisted to mcp-config.env"
else
    assert_fail "T3: secret persisted to mcp-config.env" "key not found in $(cat "$cfg_file" 2>/dev/null || echo 'file missing')"
fi
# File mode 0600
mode_ok=0
if stat -f %Mp%Lp "$cfg_file" 2>/dev/null | grep -q "^0600$"; then mode_ok=1
elif [ "$(stat -c %a "$cfg_file" 2>/dev/null)" = "600" ]; then mode_ok=1; fi
assert_eq "1" "$mode_ok" "T3: mcp-config.env mode is 0600 after wizard"
rm -f "$SANDBOX/claude.argv"

# ── Test 4: secret value must NOT appear in stdout/stderr ─────────────────────
printf 'leaked_secret_zzz\n' > "$SANDBOX/tty.fix2"
rm -f "$SANDBOX/.claude/mcp-config.env"
OUTPUT=$(TK_MCP_TTY_SRC="$SANDBOX/tty.fix2" mcp_wizard_run context7 2>&1 || true)
assert_not_contains "leaked_secret_zzz" "$OUTPUT" "T4: secret value not in stdout/stderr (hidden-input contract)"
rm -f "$SANDBOX/claude.argv"

# ── Test 5: OAuth-only MCP (notion) skips env prompts, invokes claude directly ──
rm -f "$SANDBOX/claude.argv"
mcp_wizard_run notion
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "argv:" "$ARGV_CONTENT" "T5: claude invoked for notion"
assert_contains "notion" "$ARGV_CONTENT" "T5: argv contains 'notion'"
rm -f "$SANDBOX/claude.argv"

# ── Test 6: CLI absent → return 2 (fail-soft, MCP-02 contract) ───────────────
unset TK_MCP_CLAUDE_BIN
rc=0
# Restrict PATH so 'claude' cannot be found
(
    export PATH="/usr/bin:/bin"
    source "${REPO_ROOT}/scripts/lib/mcp.sh"
    mcp_catalog_load
    mcp_wizard_run playwright 2>/dev/null
) || rc=$?
assert_eq "2" "$rc" "T6: CLI absent returns exit code 2"
# Restore for any further tests
export TK_MCP_CLAUDE_BIN="$SANDBOX/claude"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 38 — wizard dispatch integration (DISP-01..04 + Defense-in-depth)
# Extended in plan 38-03 to close TEST-02. Tests appended in three groups:
#   T7  — DISP-01 happy path (project-scope writes real value to <project>/.env)
#   T8  — DISP-02 no-regression (user-scope keeps v4.9 contract verbatim)
#   T9  — DISP-03 defer-secrets + project-scope (4-field queue, blank stub)
#   T10 — DISP-03 defer-secrets + user-scope back-compat
#   T11 — DISP-04 install.sh post-install summary printer (single + mixed scope)
#   T12 — Defense-in-depth (T1 mitigation): wizard refuses literal env block
# ─────────────────────────────────────────────────────────────────────────────

# Ensure project-secrets.sh is sourced (mcp.sh's lazy guard fires once on load,
# but explicit guard here guarantees the four functions are visible regardless
# of source order in the running shell).
if ! command -v project_secrets_write_env >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/project-secrets.sh"
fi

# ── Test 7 (DISP-01): TK_MCP_SCOPE=project writes real value to <project>/.env ──
# Asserts the project-scope happy path: secret lands in <project>/.env (mode
# 0600), .gitignore guard fires (exact `.env` line), claude argv carries the
# `${VAR}` substitution form (NOT the literal value), and ~/.claude/mcp-config.env
# stays BYTE-IDENTICAL (negative cross-store assertion via filesystem fingerprint).
rm -f "$SANDBOX/claude.argv"
rm -rf "$PROJECT"
mkdir -p "$PROJECT"

# Snapshot mcp-config.env (or its absence) BEFORE the project-scope call.
USER_CFG="$SANDBOX/.claude/mcp-config.env"
PRE_HASH_USER="$([ -f "$USER_CFG" ] && shasum "$USER_CFG" | awk '{print $1}' || echo 'MISSING')"

printf 'tk_proj_secret_ctx7\n' > "$SANDBOX/tty.fix.proj"
TK_MCP_SCOPE=project TK_PROJECT_ROOT="$PROJECT" \
TK_MCP_TTY_SRC="$SANDBOX/tty.fix.proj" \
    mcp_wizard_run context7 >/dev/null 2>&1
PROJ_RC=$?

assert_eq "0" "$PROJ_RC" "T7 (DISP-01): wizard returns 0 on project-scope happy path"

# Real value lands in <project>/.env (positive assertion).
if [[ -f "$PROJECT/.env" ]] && grep -q "^CONTEXT7_API_KEY=tk_proj_secret_ctx7$" "$PROJECT/.env"; then
    assert_pass "T7 (DISP-01): real value written to <project>/.env"
else
    assert_fail "T7 (DISP-01): real value written to <project>/.env" \
                "expected line not found in $(cat "$PROJECT/.env" 2>/dev/null || echo 'file missing')"
fi

# Mode 0600 on <project>/.env.
assert_eq "1" "$(mode_is_0600 "$PROJECT/.env")" "T7 (DISP-01): <project>/.env mode is 0600"

# .gitignore guard fired — exact `.env` line present.
if [[ -f "$PROJECT/.gitignore" ]] && grep -Fxq '.env' "$PROJECT/.gitignore"; then
    assert_pass "T7 (DISP-01): <project>/.gitignore contains exact .env line"
else
    assert_fail "T7 (DISP-01): <project>/.gitignore contains exact .env line" \
                "$(cat "$PROJECT/.gitignore" 2>/dev/null || echo 'file missing')"
fi

# claude argv carries `${VAR}` substitution form — the literal `${CONTEXT7_API_KEY}`
# substring (with $/{/} characters) must appear; the secret value MUST NOT.
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains 'CONTEXT7_API_KEY=${CONTEXT7_API_KEY}' "$ARGV_CONTENT" \
    "T7 (DISP-01): argv contains \${VAR} substitution form for CONTEXT7_API_KEY"
assert_not_contains "tk_proj_secret_ctx7" "$ARGV_CONTENT" \
    "T7 (DISP-01): literal secret value does NOT appear in claude argv"
assert_contains "scope:project" "$ARGV_CONTENT" \
    "T7 (DISP-01): mock parsed --scope project"

# Negative cross-store assertion: ~/.claude/mcp-config.env UNTOUCHED in project flow.
POST_HASH_USER="$([ -f "$USER_CFG" ] && shasum "$USER_CFG" | awk '{print $1}' || echo 'MISSING')"
assert_eq "$PRE_HASH_USER" "$POST_HASH_USER" \
    "T7 (DISP-01 negative): ~/.claude/mcp-config.env UNTOUCHED in project-scope flow"

rm -f "$SANDBOX/claude.argv"

# ── Test 8 (DISP-02): TK_MCP_SCOPE=user no-regression — keys to mcp-config.env ──
# Real values land in ~/.claude/mcp-config.env, claude argv carries literal env
# value via the `env KEY=V` exec wrapper (v4.9 contract preserved), and
# <project>/.env UNTOUCHED (negative cross-store assertion).
rm -rf "$PROJECT"
mkdir -p "$PROJECT"
# Wipe mcp-config.env to a clean baseline for this test.
rm -f "$USER_CFG"

printf 'tk_user_secret_ctx7\n' > "$SANDBOX/tty.fix.user"
TK_MCP_SCOPE=user \
TK_MCP_TTY_SRC="$SANDBOX/tty.fix.user" \
    mcp_wizard_run context7 >/dev/null 2>&1
USER_RC=$?

assert_eq "0" "$USER_RC" "T8 (DISP-02): wizard returns 0 on user-scope flow"

# Real value in ~/.claude/mcp-config.env (v4.9 contract).
if [[ -f "$USER_CFG" ]] && grep -q "^CONTEXT7_API_KEY=tk_user_secret_ctx7$" "$USER_CFG"; then
    assert_pass "T8 (DISP-02): real value in ~/.claude/mcp-config.env (v4.9 contract)"
else
    assert_fail "T8 (DISP-02): real value in ~/.claude/mcp-config.env" \
                "$(cat "$USER_CFG" 2>/dev/null || echo 'file missing')"
fi

# claude argv received the literal env value via the `env KEY=V` exec wrapper.
ARGV_CONTENT="$(cat "$SANDBOX/claude.argv" 2>/dev/null || echo '')"
assert_contains "env:CTX=tk_user_secret_ctx7" "$ARGV_CONTENT" \
    "T8 (DISP-02): user-scope passes literal value via env-exec wrapper (v4.9 contract)"
assert_contains "scope:user" "$ARGV_CONTENT" \
    "T8 (DISP-02): mock parsed --scope user"

# Negative cross-store assertion: <project>/.env UNTOUCHED in user-scope flow.
if [[ ! -f "$PROJECT/.env" ]]; then
    assert_pass "T8 (DISP-02 negative): <project>/.env UNTOUCHED in user-scope flow"
else
    assert_fail "T8 (DISP-02 negative): <project>/.env UNTOUCHED in user-scope flow" \
                "found: $(cat "$PROJECT/.env")"
fi

rm -f "$SANDBOX/claude.argv"

# ── Test 9 (DISP-03): defer-secrets + TK_MCP_SCOPE=project — blank stub + 4-field queue ──
# When TK_MCP_DEFER_SECRETS=1 and scope=project, the wizard must:
#   - leave a blank stub `KEY=` in <project>/.env (not in mcp-config.env)
#   - run the .gitignore guard once (idempotent across env-collection / defer paths)
#   - write a queue tuple with 4 tab-separated fields, scope=project as the 4th
#   - return rc=3 (registered-without-env contract, D-12)
rm -rf "$PROJECT"
mkdir -p "$PROJECT"
QUEUE9="$(mktemp "$SANDBOX/queue9.XXXXXX")"

DEFER_RC=0
TK_MCP_DEFERRED_QUEUE="$QUEUE9" \
TK_MCP_DEFER_SECRETS=1 \
TK_MCP_SCOPE=project \
TK_PROJECT_ROOT="$PROJECT" \
    mcp_wizard_run context7 >/dev/null 2>&1 || DEFER_RC=$?

# rc=3 = registered-without-env (mcp.sh defer branch contract).
assert_eq "3" "$DEFER_RC" "T9 (DISP-03): defer+project returns rc=3 (registered-without-env)"

# 4-field tuple.
FIELDS_COUNT="$(awk -F'\t' 'NR==1{print NF; exit}' "$QUEUE9")"
assert_eq "4" "$FIELDS_COUNT" "T9 (DISP-03): deferred queue tuple has 4 tab-separated fields"

# 4th field is `project`.
SCOPE_FIELD="$(awk -F'\t' 'NR==1{print $4; exit}' "$QUEUE9")"
assert_eq "project" "$SCOPE_FIELD" "T9 (DISP-03): 4th field is scope=project"

# Blank stub in <project>/.env.
if [[ -f "$PROJECT/.env" ]] && grep -q "^CONTEXT7_API_KEY=$" "$PROJECT/.env"; then
    assert_pass "T9 (DISP-03): blank stub CONTEXT7_API_KEY= in <project>/.env"
else
    assert_fail "T9 (DISP-03): blank stub CONTEXT7_API_KEY= in <project>/.env" \
                "$(cat "$PROJECT/.env" 2>/dev/null || echo 'file missing')"
fi

# .gitignore guard fired in defer path too.
if [[ -f "$PROJECT/.gitignore" ]] && grep -Fxq '.env' "$PROJECT/.gitignore"; then
    assert_pass "T9 (DISP-03): <project>/.gitignore guard fired in defer path"
else
    assert_fail "T9 (DISP-03): <project>/.gitignore guard fired in defer path" \
                "$(cat "$PROJECT/.gitignore" 2>/dev/null || echo 'file missing')"
fi

# Mode 0600 on stub file (defense in depth — defer path must not widen perms).
assert_eq "1" "$(mode_is_0600 "$PROJECT/.env")" "T9 (DISP-03): stub file mode is 0600"

rm -f "$SANDBOX/claude.argv"

# ── Test 10 (DISP-03 user-scope back-compat): defer + scope=user → mcp-config.env stub ──
# The 4-tuple growth must NOT regress the user-scope defer path. Stub still
# lands in ~/.claude/mcp-config.env, queue tuple has 4 fields with `user` as
# the 4th (UNCHANGED v4.9 destination + new schema field).
rm -f "$USER_CFG"
QUEUE10="$(mktemp "$SANDBOX/queue10.XXXXXX")"

USER_DEFER_RC=0
TK_MCP_DEFERRED_QUEUE="$QUEUE10" \
TK_MCP_DEFER_SECRETS=1 \
TK_MCP_SCOPE=user \
    mcp_wizard_run context7 >/dev/null 2>&1 || USER_DEFER_RC=$?

assert_eq "3" "$USER_DEFER_RC" "T10 (DISP-03): defer+user returns rc=3 (v4.9 contract preserved)"

# 4-field tuple with `user` as the 4th.
USER_SCOPE_FIELD="$(awk -F'\t' 'NR==1{print $4; exit}' "$QUEUE10")"
assert_eq "user" "$USER_SCOPE_FIELD" "T10 (DISP-03): 4th field is scope=user"

# Blank stub in ~/.claude/mcp-config.env (v4.9 path UNCHANGED).
if [[ -f "$USER_CFG" ]] && grep -q "^CONTEXT7_API_KEY=$" "$USER_CFG"; then
    assert_pass "T10 (DISP-03): blank stub in ~/.claude/mcp-config.env (v4.9 path)"
else
    assert_fail "T10 (DISP-03): blank stub in ~/.claude/mcp-config.env" \
                "$(cat "$USER_CFG" 2>/dev/null || echo 'file missing')"
fi

rm -f "$SANDBOX/claude.argv"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
