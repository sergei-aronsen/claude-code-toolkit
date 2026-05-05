#!/usr/bin/env bash
# test-project-secrets.sh — Phase 37 / TEST-01 contract
# (>=18 hermetic assertions covering SEC-01..06).
#
# Hermetic: mktemp -d sandbox, no $HOME mutation, trap cleanup.
# Idempotent + double-run-safe: all state is namespaced under $SANDBOX.
#
# Usage: bash scripts/tests/test-project-secrets.sh
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

# Cross-platform 0600 mode check (BSD `stat -f` first, GNU `stat -c` fallback).
# Echoes "1" when mode is 0600, "0" otherwise — matches test-mcp-secrets.sh:62-67.
mode_is_0600() {
    local f="$1"
    if stat -f %Mp%Lp "$f" 2>/dev/null | grep -q "^0600$"; then
        echo "1"; return 0
    elif [ "$(stat -c %a "$f" 2>/dev/null)" = "600" ]; then
        echo "1"; return 0
    fi
    echo "0"
}

printf "=== project-secrets tests (Phase 37 / TEST-01) ===\n"

SANDBOX="$(mktemp -d /tmp/project-secrets.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

# Per-test project root (D-06: caller-supplied absolute path).
PROJECT="$SANDBOX/myproj"
mkdir -p "$PROJECT"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/project-secrets.sh"

# ── Block A: project_secrets_write_env basics (SEC-02 / D-04) ─────────────────

# T1: write_env creates .env when absent.
project_secrets_write_env "$PROJECT" FOO bar
if [ -f "$PROJECT/.env" ]; then
    assert_pass "T1: write_env creates .env when absent"
else
    assert_fail "T1: write_env creates .env when absent" "missing $PROJECT/.env"
fi

# T2: contents include exact KEY=VALUE line.
if grep -Fxq 'FOO=bar' "$PROJECT/.env"; then
    assert_pass "T2: KEY=VALUE line present after first write"
else
    assert_fail "T2: KEY=VALUE line present after first write" "$(cat "$PROJECT/.env")"
fi

# T3: mode 0600 (BSD + GNU stat dual-check) on first write — SEC-02 D-04 step 3.
ENV_FILE="$PROJECT/.env"
assert_eq "1" "$(mode_is_0600 "$ENV_FILE")" "T3: .env mode is 0600 after first write"

# T4: collision N preserves existing value (D-04 step 5 fail-closed).
TK_MCP_TTY_SRC=<(printf 'N\n') project_secrets_write_env "$PROJECT" FOO new_value 2>/dev/null || true
if grep -Fxq 'FOO=bar' "$PROJECT/.env"; then
    assert_pass "T4: collision N preserves existing value"
else
    assert_fail "T4: collision N preserves existing value" "$(cat "$PROJECT/.env")"
fi

# T5: collision Y overwrites value via mktemp+mv rewrite path.
TK_MCP_TTY_SRC=<(printf 'y\n') project_secrets_write_env "$PROJECT" FOO updated 2>/dev/null || true
if grep -Fxq 'FOO=updated' "$PROJECT/.env"; then
    assert_pass "T5: collision Y overwrites value"
else
    assert_fail "T5: collision Y overwrites value" "$(cat "$PROJECT/.env")"
fi

# T6: mode 0600 preserved after rewrite path — SEC-02 D-04 step 7.
assert_eq "1" "$(mode_is_0600 "$ENV_FILE")" "T6: mode 0600 preserved after rewrite"

# ── Block B: SEC-06 metacharacter rejection (D-17, reuses _mcp_validate_value) ─

# Use distinct keys to avoid silent collisions with prior assertions.
# Each metacharacter gets two assertions: rc=1 + exact stderr phrase.

# T7: $ rejected.
ERR="$(project_secrets_write_env "$PROJECT" DOLLAR 'val$inj' 2>&1 1>/dev/null)" \
    && { assert_fail "T7: \$ in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T7: \$ in value rejected"
assert_contains "shell metacharacters" "$ERR" "T7b: \$ refusal stderr phrase"

# T8: backtick rejected.
ERR="$(project_secrets_write_env "$PROJECT" BTICK 'val`inj' 2>&1 1>/dev/null)" \
    && { assert_fail "T8: backtick in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T8: backtick in value rejected"
assert_contains "shell metacharacters" "$ERR" "T8b: backtick refusal stderr phrase"

# T9: backslash rejected.
ERR="$(project_secrets_write_env "$PROJECT" BSLASH 'val\inj' 2>&1 1>/dev/null)" \
    && { assert_fail "T9: backslash in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T9: backslash in value rejected"
assert_contains "shell metacharacters" "$ERR" "T9b: backslash refusal stderr phrase"

# T10: double-quote rejected.
ERR="$(project_secrets_write_env "$PROJECT" DQUOTE 'val"inj' 2>&1 1>/dev/null)" \
    && { assert_fail "T10: double-quote in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T10: double-quote in value rejected"
assert_contains "shell metacharacters" "$ERR" "T10b: double-quote refusal stderr phrase"

# T11: single-quote rejected.
ERR="$(project_secrets_write_env "$PROJECT" SQUOTE "val'inj" 2>&1 1>/dev/null)" \
    && { assert_fail "T11: single-quote in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T11: single-quote in value rejected"
assert_contains "shell metacharacters" "$ERR" "T11b: single-quote refusal stderr phrase"

# T12: newline rejected.
NL_VAL="$(printf 'a\nb')"
ERR="$(project_secrets_write_env "$PROJECT" NL "$NL_VAL" 2>&1 1>/dev/null)" \
    && { assert_fail "T12: newline in value rejected" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T12: newline in value rejected"

# ── Block C: project_secrets_ensure_gitignore (SEC-03 / D-07..D-09) ───────────

# T13: creates .gitignore when absent.
GP="$SANDBOX/giproj"
mkdir -p "$GP"
project_secrets_ensure_gitignore "$GP"
if [ -f "$GP/.gitignore" ]; then
    assert_pass "T13: ensure_gitignore creates .gitignore when absent"
else
    assert_fail "T13: ensure_gitignore creates .gitignore when absent" "missing $GP/.gitignore"
fi

# T14: contains exact .env line.
if grep -Fxq '.env' "$GP/.gitignore"; then
    assert_pass "T14: .env line present in .gitignore"
else
    assert_fail "T14: .env line present in .gitignore" "$(cat "$GP/.gitignore")"
fi

# T14b: contains the leading comment line (D-08).
if grep -Fq 'claude-code-toolkit: never commit project-scope MCP secrets' "$GP/.gitignore"; then
    assert_pass "T14b: comment line present in .gitignore"
else
    assert_fail "T14b: comment line present in .gitignore" "$(cat "$GP/.gitignore")"
fi

# T15: idempotent — second invocation does not duplicate the line (D-09).
project_secrets_ensure_gitignore "$GP"
COUNT="$(grep -cFx '.env' "$GP/.gitignore")"
assert_eq "1" "$COUNT" "T15: idempotent — exactly one .env line after re-run"

# T16: false-negative on `*.env` (D-07 exact-fixed-line).
GP2="$SANDBOX/giproj2"
mkdir -p "$GP2"
printf '*.env\n' > "$GP2/.gitignore"
project_secrets_ensure_gitignore "$GP2"
if grep -Fxq '.env' "$GP2/.gitignore"; then
    assert_pass "T16: pre-seeded *.env does not match — .env line still appended"
else
    assert_fail "T16: pre-seeded *.env does not match — .env line still appended" "$(cat "$GP2/.gitignore")"
fi

# T17: false-negative on `# .env` comment line (D-07 exact-fixed-line).
GP3="$SANDBOX/giproj3"
mkdir -p "$GP3"
printf '# .env\n' > "$GP3/.gitignore"
project_secrets_ensure_gitignore "$GP3"
if grep -Fxq '.env' "$GP3/.gitignore"; then
    assert_pass "T17: pre-seeded '# .env' comment does not match — .env line still appended"
else
    assert_fail "T17: pre-seeded '# .env' comment does not match — .env line still appended" "$(cat "$GP3/.gitignore")"
fi

# ── Block D: project_secrets_render_mcp_env_block (SEC-04 / D-10..D-12) ───────

# T18: empty args → {} with no trailing newline (D-11).
OUT="$(project_secrets_render_mcp_env_block)"
assert_eq '{}' "$OUT" "T18: empty render → {}"

# T19: two keys → exact JSON object form (D-10).
OUT="$(project_secrets_render_mcp_env_block FOO BAR)"
assert_eq '{"FOO":"${FOO}","BAR":"${BAR}"}' "$OUT" "T19: two-key render exact form"

# T20: invalid key (lowercase) → rc=1 (D-12).
if project_secrets_render_mcp_env_block badkey 2>/dev/null; then
    assert_fail "T20: invalid key rc=1" "got rc=0"
else
    assert_pass "T20: invalid key rc=1"
fi

# ── Block E: project_secrets_validate_mcp_env_block (SEC-05 / D-13..D-15) ─────

# T21: literal value → rc=1.
ERR="$(project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>&1 1>/dev/null)" \
    && { assert_fail "T21: literal value rc=1" "expected rc=1, got rc=0"; ERR=""; } \
    || assert_pass "T21: literal value rc=1"

# T21b: refusal stderr phrase (D-14 exact phrase, $ escaped in source).
assert_contains 'refusing to write literal value into .mcp.json' "$ERR" \
    "T21b: SEC-05 refusal stderr phrase"

# T22: ${VAR} substitution form → rc=0 (D-13).
if project_secrets_validate_mcp_env_block '{"K":"${K}"}' 2>/dev/null; then
    assert_pass "T22: \${VAR} substitution form rc=0"
else
    assert_fail "T22: \${VAR} substitution form rc=0" "expected rc=0"
fi

# T23: TK_PROJECT_SECRETS_ALLOW_LITERAL=1 bypasses → rc=0 (D-15).
ERR="$(TK_PROJECT_SECRETS_ALLOW_LITERAL=1 \
    project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>&1 1>/dev/null)" || true
if TK_PROJECT_SECRETS_ALLOW_LITERAL=1 \
    project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>/dev/null; then
    assert_pass "T23: TK_PROJECT_SECRETS_ALLOW_LITERAL bypass rc=0"
else
    assert_fail "T23: TK_PROJECT_SECRETS_ALLOW_LITERAL bypass rc=0" "expected rc=0"
fi

# T23b: ALLOW_LITERAL emits "test seam only" warning to stderr (D-15).
assert_contains 'test seam only' "$ERR" \
    "T23b: ALLOW_LITERAL warning stderr phrase"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
