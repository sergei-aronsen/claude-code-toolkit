#!/usr/bin/env bash
# test-catalog-scope-fallback.sh — Phase 36 (SCOPE-03 / D-14) hermetic backward-compat test.
#
# Locks the v5.0 contract for `mcp_catalog_load` and validator TEST-06:
#   BC1 — synthetic catalog with one MCP entry missing `default_scope` loads
#         cleanly; MCP_DEFAULT_SCOPE[<missing>] == "user" (D-09 fallback);
#         MCP_DEFAULT_SCOPE[<present>] == catalog value verbatim;
#         loader emits ZERO bytes on stderr (D-11 silent contract).
#   BC2 — validator exits non-zero on catalog missing default_scope AND
#         stderr mentions `default_scope` (TEST-06 negative).
#   BC3 — validator exits 0 on synthetic catalog with valid enum {user,project}.
#   BC4 — validator exits non-zero on invalid enum value ("global") AND
#         stderr mentions `default_scope` (TEST-06 negative on enum).
#
# Hermetic — no shell-out to claude/brew/network. Each scenario uses its own
# /tmp/test-catalog-scope-fallback.* sandbox cleaned up on RETURN.
# Bash 3.2 compatible. Usage: bash scripts/tests/test-catalog-scope-fallback.sh
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

echo "test-catalog-scope-fallback.sh: Phase 36 D-14 silent-fallback contract"
echo ""

# ─────────────────────────────────────────────────
# BC1 — silent-fallback contract (D-09 + D-11)
#       synthetic catalog: 1 entry WITH default_scope=project, 1 WITHOUT;
#       loader returns 0; missing → "user"; present → "project"; stderr=0 bytes
# ─────────────────────────────────────────────────
run_bc1_silent_fallback_to_user() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC1: catalog missing default_scope -> loader fallback to 'user', no stderr --"

    cat > "$SANDBOX/synth-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "withscope": {
        "name": "withscope",
        "display_name": "With",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["withscope", "--", "echo"],
        "description": "with",
        "requires_oauth": false,
        "default_scope": "project"
      },
      "noscope": {
        "name": "noscope",
        "display_name": "Without",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["noscope", "--", "echo"],
        "description": "without",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local stdout_tmp="$SANDBOX/stdout"
    local rc=0
    TK_MCP_CATALOG_PATH="$SANDBOX/synth-catalog.json" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        mcp_catalog_load
        for i in \"\${!MCP_NAMES[@]}\"; do
            printf '%s=%s\n' \"\${MCP_NAMES[\$i]}\" \"\${MCP_DEFAULT_SCOPE[\$i]}\"
        done
    " >"$stdout_tmp" 2>"$stderr_tmp" || rc=$?

    assert_eq "0" "$rc" "BC1.1: mcp_catalog_load returns 0 on catalog missing default_scope"

    local noscope_ds withscope_ds
    noscope_ds=$(grep '^noscope=' "$stdout_tmp" | head -1 | cut -d= -f2)
    withscope_ds=$(grep '^withscope=' "$stdout_tmp" | head -1 | cut -d= -f2)
    assert_eq "user"    "$noscope_ds"   "BC1.2: missing default_scope -> MCP_DEFAULT_SCOPE='user'"
    assert_eq "project" "$withscope_ds" "BC1.3: present default_scope='project' preserved verbatim"

    # D-11 silent contract — stderr must be empty (zero bytes).
    # On regression, surface the first 5 lines of stderr in the failure message
    # so the operator can diagnose without re-running the test by hand.
    local stderr_size stderr_excerpt
    stderr_size=$(wc -c < "$stderr_tmp" | tr -d ' ')
    if [ "$stderr_size" = "0" ]; then
        assert_pass "BC1.4: loader emits no stderr on missing default_scope (D-11 silent)"
    else
        stderr_excerpt=$(head -5 "$stderr_tmp" | tr '\n' '|')
        assert_fail "BC1.4: loader emits no stderr on missing default_scope (D-11 silent)" \
            "stderr_size=$stderr_size, first-5-lines: $stderr_excerpt"
    fi
}

# ─────────────────────────────────────────────────
# BC2 — validator rejects synthetic catalog missing default_scope
# ─────────────────────────────────────────────────
run_bc2_validator_rejects_missing_field() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC2: validator exits non-zero on catalog missing default_scope --"

    cat > "$SANDBOX/bad-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "noscope": {
        "name": "noscope",
        "display_name": "Without",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["noscope", "--", "echo"],
        "description": "without",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/bad-catalog.json" \
        >/dev/null 2>"$stderr_tmp" || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        assert_pass "BC2.1: validator exits non-zero on catalog missing default_scope"
    else
        assert_fail "BC2.1: validator exits non-zero on catalog missing default_scope" "rc=0 (expected non-zero)"
    fi

    if grep -q "default_scope" "$stderr_tmp"; then
        assert_pass "BC2.2: validator stderr mentions default_scope"
    else
        assert_fail "BC2.2: validator stderr mentions default_scope" "stderr did not contain 'default_scope'"
    fi
}

# ─────────────────────────────────────────────────
# BC3 — validator accepts synthetic catalog with valid enum {user, project}
# ─────────────────────────────────────────────────
run_bc3_validator_accepts_valid_enum() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC3: validator exits 0 on synthetic catalog with valid default_scope --"

    cat > "$SANDBOX/good-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "alpha": {
        "name": "alpha",
        "display_name": "Alpha",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["alpha", "--", "echo"],
        "description": "alpha",
        "requires_oauth": false,
        "default_scope": "user"
      },
      "beta": {
        "name": "beta",
        "display_name": "Beta",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["beta", "--", "echo"],
        "description": "beta",
        "requires_oauth": false,
        "default_scope": "project"
      }
    }
  }
}
JSON

    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/good-catalog.json" \
        >/dev/null 2>&1 || rc=$?
    assert_eq "0" "$rc" "BC3.1: validator exits 0 on synthetic catalog with valid default_scope"
}

# ─────────────────────────────────────────────────
# BC4 — validator rejects invalid enum value
# ─────────────────────────────────────────────────
run_bc4_validator_rejects_invalid_enum() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC4: validator exits non-zero on invalid enum value --"

    cat > "$SANDBOX/invalid-enum-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "alpha": {
        "name": "alpha",
        "display_name": "Alpha",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["alpha", "--", "echo"],
        "description": "alpha",
        "requires_oauth": false,
        "default_scope": "global"
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/invalid-enum-catalog.json" \
        >/dev/null 2>"$stderr_tmp" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        assert_pass "BC4.1: validator exits non-zero on invalid enum value"
    else
        assert_fail "BC4.1: validator exits non-zero on invalid enum value" "rc=0 (expected non-zero)"
    fi
    if grep -q "default_scope" "$stderr_tmp"; then
        assert_pass "BC4.2: validator stderr mentions default_scope"
    else
        assert_fail "BC4.2: validator stderr mentions default_scope" "stderr missing 'default_scope'"
    fi
}

run_bc1_silent_fallback_to_user
run_bc2_validator_rejects_missing_field
run_bc3_validator_accepts_valid_enum
run_bc4_validator_rejects_invalid_enum

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
