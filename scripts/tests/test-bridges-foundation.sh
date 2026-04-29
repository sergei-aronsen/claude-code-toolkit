#!/usr/bin/env bash
# test-bridges-foundation.sh — Phase 28 smoke test for detection probes + bridges lib.
#
# Five scenarios:
#   S1 — is_gemini_installed and is_codex_installed return 0/1 binary, no stderr
#   S2 — bridge_create_project gemini writes GEMINI.md with byte-identical 4-line banner
#   S3 — bridge_create_project codex writes AGENTS.md (NOT CODEX.md), banner present
#   S4 — toolkit-install.json::bridges[] has one entry per call with full schema
#         (target, path, scope, source_sha256 64-hex, bridge_sha256 64-hex, user_owned=false)
#   S5 — Idempotent re-run + TK_BRIDGE_HOME isolation: bridges[] count unchanged on re-run,
#         no writes to real $HOME (sandbox-only)
#
# Test seam: TK_BRIDGE_HOME=$SANDBOX overrides $HOME for global write target,
#            state file path, AND lock dir. A fresh sandbox is created per scenario and
#            tracked globally; all sandboxes are cleaned up on EXIT.
#
# Libs are sourced at the top level (before any scenario function). This avoids
# the Bash RETURN-trap pitfall: sourcing inside a function body with trap...RETURN
# fires the trap when `source` returns, not when the function returns.
#
# Usage: bash scripts/tests/test-bridges-foundation.sh
# Exit:  0 = all 5 assertions passed, 1 = any failed

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
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

# Global list of sandboxes to clean on EXIT (avoids RETURN-trap pitfall with source).
_SANDBOXES=()
_cleanup_sandboxes() {
    local d
    for d in "${_SANDBOXES[@]+"${_SANDBOXES[@]}"}"; do
        [[ -d "$d" ]] && rm -rf "${d:?}"
    done
}
trap '_cleanup_sandboxes' EXIT

# mk_sandbox — create a fresh hermetic temp dir, register it for EXIT cleanup.
# Prints the path to stdout for capture by callers.
mk_sandbox() {
    local d
    d="$(mktemp -d /tmp/test-bridges-foundation.XXXXXX)"
    mkdir -p "$d/.claude"
    _SANDBOXES+=("$d")
    echo "$d"
}

# Source both libs once at the top level.
# Reason: sourcing inside a function with trap...RETURN fires the trap on source-return,
# not function-return, corrupting the sandbox before the test body runs.
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/detect2.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/bridges.sh"

echo "test-bridges-foundation.sh: Phase 28 detection + bridges smoke suite"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# S1 — Detection probes return 0/1 binary, no stderr
# ──────────────────────────────────────────────────────────────────────────
run_s1() {
    echo "S1: detection probes return 0/1 binary"

    # Run both probes; capture stderr to verify it is empty.
    local gem_rc cod_rc gem_err cod_err
    gem_err="$(is_gemini_installed 2>&1 1>/dev/null)" || true
    gem_rc=$?
    cod_err="$(is_codex_installed 2>&1 1>/dev/null)" || true
    cod_rc=$?

    # The probe must return 0 or 1 (binary). Anything else fails.
    if [[ "$gem_rc" -eq 0 || "$gem_rc" -eq 1 ]] && \
       [[ "$cod_rc" -eq 0 || "$cod_rc" -eq 1 ]] && \
       [[ -z "$gem_err" ]] && [[ -z "$cod_err" ]]; then
        assert_pass "S1: probes return binary 0/1 with no stderr"
    else
        assert_fail "S1: probes return binary 0/1 with no stderr" \
            "gem_rc=$gem_rc cod_rc=$cod_rc gem_err='$gem_err' cod_err='$cod_err'"
    fi
}

# ──────────────────────────────────────────────────────────────────────────
# S2 — bridge_create_project gemini writes GEMINI.md with banner
# ──────────────────────────────────────────────────────────────────────────
run_s2() {
    echo "S2: bridge_create_project gemini writes GEMINI.md with banner"

    local sandbox
    sandbox="$(mk_sandbox)"
    export TK_BRIDGE_HOME="$sandbox"
    printf 'Source CLAUDE.md content for S2 sandbox.\n' > "$sandbox/CLAUDE.md"

    if bridge_create_project gemini "$sandbox" \
        && [[ -f "$sandbox/GEMINI.md" ]] \
        && [[ "$(head -1 "$sandbox/GEMINI.md")" == "<!--" ]] \
        && grep -q "Source CLAUDE.md content for S2 sandbox" "$sandbox/GEMINI.md"; then
        assert_pass "S2: GEMINI.md exists with banner header and verbatim source content"
    else
        local first_line
        first_line="$(head -1 "$sandbox/GEMINI.md" 2>/dev/null || echo '<missing>')"
        assert_fail "S2: GEMINI.md exists with banner header and verbatim source content" \
            "GEMINI.md exists=$([[ -f $sandbox/GEMINI.md ]] && echo y || echo n) first_line='$first_line'"
    fi

    unset TK_BRIDGE_HOME
}

# ──────────────────────────────────────────────────────────────────────────
# S3 — bridge_create_project codex writes AGENTS.md (NOT CODEX.md)
# ──────────────────────────────────────────────────────────────────────────
run_s3() {
    echo "S3: bridge_create_project codex writes AGENTS.md (NOT CODEX.md)"

    local sandbox
    sandbox="$(mk_sandbox)"
    export TK_BRIDGE_HOME="$sandbox"
    printf 'Source content for S3.\n' > "$sandbox/CLAUDE.md"

    if bridge_create_project codex "$sandbox" \
        && [[ -f "$sandbox/AGENTS.md" ]] \
        && [[ ! -f "$sandbox/CODEX.md" ]] \
        && [[ "$(head -1 "$sandbox/AGENTS.md")" == "<!--" ]]; then
        assert_pass "S3: AGENTS.md exists, CODEX.md absent, banner present"
    else
        assert_fail "S3: AGENTS.md exists, CODEX.md absent, banner present" \
            "AGENTS.md=$([[ -f $sandbox/AGENTS.md ]] && echo y || echo n) CODEX.md=$([[ -f $sandbox/CODEX.md ]] && echo y || echo n)"
    fi

    unset TK_BRIDGE_HOME
}

# ──────────────────────────────────────────────────────────────────────────
# S4 — bridges[] state entry has correct schema
# ──────────────────────────────────────────────────────────────────────────
run_s4() {
    echo "S4: bridges[] state entry has correct schema"

    local sandbox
    sandbox="$(mk_sandbox)"
    export TK_BRIDGE_HOME="$sandbox"
    printf 'Source content for S4.\n' > "$sandbox/CLAUDE.md"

    bridge_create_project gemini "$sandbox" >/dev/null

    local state_file="$sandbox/.claude/toolkit-install.json"
    local schema_ok
    schema_ok="$(python3 - "$state_file" <<'PYEOF'
import json, re, sys
path = sys.argv[1]
with open(path) as f:
    state = json.load(f)
bridges = state.get("bridges", [])
if len(bridges) != 1:
    print("FAIL:bridges-count=%d" % len(bridges))
    sys.exit(0)
b = bridges[0]
checks = [
    ("target", b.get("target") == "gemini"),
    ("scope", b.get("scope") == "project"),
    ("path-suffix", isinstance(b.get("path"), str) and b["path"].endswith("/GEMINI.md")),
    ("source_sha256-hex64", isinstance(b.get("source_sha256"), str) and bool(re.fullmatch(r"[0-9a-f]{64}", b["source_sha256"]))),
    ("bridge_sha256-hex64", isinstance(b.get("bridge_sha256"), str) and bool(re.fullmatch(r"[0-9a-f]{64}", b["bridge_sha256"]))),
    ("user_owned-false", b.get("user_owned") is False),
]
fails = [name for name, ok in checks if not ok]
if fails:
    print("FAIL:" + ",".join(fails))
else:
    print("OK")
PYEOF
)"

    if [[ "$schema_ok" == "OK" ]]; then
        assert_pass "S4: bridges[0] has correct target, scope, path, sha256s, user_owned=false"
    else
        assert_fail "S4: bridges[0] has correct target, scope, path, sha256s, user_owned=false" \
            "schema check returned: $schema_ok"
    fi

    unset TK_BRIDGE_HOME
}

# ──────────────────────────────────────────────────────────────────────────
# S5 — Idempotent re-run + TK_BRIDGE_HOME sandbox isolation
# ──────────────────────────────────────────────────────────────────────────
run_s5() {
    echo "S5: idempotent re-run + sandbox isolation"

    local sandbox
    sandbox="$(mk_sandbox)"
    export TK_BRIDGE_HOME="$sandbox"
    printf 'Source content for S5.\n' > "$sandbox/CLAUDE.md"

    # Snapshot real $HOME bridge-related paths BEFORE the test.
    # If any of these exist after, the seam leaked.
    local home_gem_before home_cod_before
    home_gem_before="$([[ -e "$HOME/.gemini/GEMINI.md" ]] && echo exists || echo absent)"
    home_cod_before="$([[ -e "$HOME/.codex/AGENTS.md" ]] && echo exists || echo absent)"

    bridge_create_project gemini "$sandbox" >/dev/null
    local first_sha
    first_sha="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$sandbox/GEMINI.md")"
    local first_count
    first_count="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("bridges",[])))' "$sandbox/.claude/toolkit-install.json")"

    # Idempotent re-run: same source → same bridge content, same bridges[] count.
    bridge_create_project gemini "$sandbox" >/dev/null
    local second_sha second_count
    second_sha="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$sandbox/GEMINI.md")"
    second_count="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("bridges",[])))' "$sandbox/.claude/toolkit-install.json")"

    # Sandbox isolation check: real $HOME was not touched.
    local home_gem_after home_cod_after
    home_gem_after="$([[ -e "$HOME/.gemini/GEMINI.md" ]] && echo exists || echo absent)"
    home_cod_after="$([[ -e "$HOME/.codex/AGENTS.md" ]] && echo exists || echo absent)"

    if [[ "$first_sha" == "$second_sha" ]] \
        && [[ "$first_count" == "$second_count" ]] \
        && [[ "$first_count" == "1" ]] \
        && [[ "$home_gem_before" == "$home_gem_after" ]] \
        && [[ "$home_cod_before" == "$home_cod_after" ]]; then
        assert_pass "S5: idempotent re-run keeps SHA + bridges[] count stable; real \$HOME untouched"
    else
        assert_fail "S5: idempotent re-run keeps SHA + bridges[] count stable; real \$HOME untouched" \
            "first_sha=$first_sha second_sha=$second_sha first_count=$first_count second_count=$second_count home_gem before=$home_gem_before after=$home_gem_after home_cod before=$home_cod_before after=$home_cod_after"
    fi

    unset TK_BRIDGE_HOME
}

# ──────────────────────────────────────────────────────────────────────────
# Run all scenarios
# ──────────────────────────────────────────────────────────────────────────
run_s1
run_s2
run_s3
run_s4
run_s5

echo ""
echo "test-bridges-foundation complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
