#!/usr/bin/env bash
# test-integrations-foundation.sh — Phase 32 hermetic integration smoke.
#
# Locks the contract surface for Phase 32 (CAT-01..04, CLI-01..04). Does NOT
# exercise full integration paths (Phase 35 TEST-01..03 own those). Hermetic:
# no claude CLI, no brew, no network. >=10 PASS assertions across 15 scenarios.
#
# Scenarios:
#   S1  validator_happy_path        — shipped integrations-catalog.json passes (CAT-01..03)
#   S2  validator_missing_field     — fixture without display_name -> exit 1 + ERROR
#   S3  validator_bad_category      — fixture with category=frobnicate -> exit 1 + ERROR
#   S4  validator_missing_components — fixture without components -> exit 1 + ERROR
#   S5  validator_bad_env_var_key   — fixture with lowercase env_var_keys[0] -> exit 1
#   S6  cli_detect_present          — cli_detect bash returns 0 (CLI-01)
#   S7  cli_detect_absent           — cli_detect __nope__ returns 1 (CLI-01)
#   S8  cli_install_dispatch_darwin — TK_CLI_UNAME=Darwin runs darwin_cmd only (CLI-01)
#   S9  cli_install_dispatch_linux  — TK_CLI_UNAME=Linux runs linux_cmd only (CLI-01)
#   S10 cli_install_unsupported     — TK_CLI_UNAME=FreeBSD -> rc=2 + stderr (CLI-02)
#   S11 cli_install_brew_absent     — Darwin + brew-prefix + TK_CLI_BREW_BIN="" -> rc=3 (CLI-02)
#   S12 cli_post_install_hint_stderr — stderr only, stdout empty (CLI-04)
#   S13 install_sh_mcps_alias       — install.sh --mcps prints "deprecated" to stderr (CAT-04)
#   S14 install_sh_integrations_alias — install.sh --integrations works without deprecation (CAT-04)
#   S15 mcp_sh_reads_new_path       — _mcp_default_catalog_path returns *integrations-catalog.json
#
# Test seams: TK_CLI_UNAME, TK_CLI_BREW_BIN, TK_MCP_CATALOG_PATH, TK_MCP_CLAUDE_BIN,
#             TK_MCP_CONFIG_HOME
#
# Usage: bash scripts/tests/test-integrations-foundation.sh
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
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
    fi
}

echo "test-integrations-foundation.sh: CAT-01..04 + CLI-01..04 contract suite"
echo ""

# ─────────────────────────────────────────────────
# S1 — validator_happy_path: shipped catalog passes (CAT-01..03)
# ─────────────────────────────────────────────────
run_s1_validator_happy_path() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_validator_happy_path: shipped catalog passes validator --"

    local rc=0 out=""
    out=$(cd "$REPO_ROOT" && python3 scripts/validate-integrations-catalog.py 2>&1) || rc=$?
    assert_eq "0" "$rc" "S1: validator exits 0 on shipped catalog"
    assert_contains "PASSED" "$out" "S1: stdout contains PASSED line"
}

# ─────────────────────────────────────────────────
# S2 — validator_missing_field: fixture without display_name -> exit 1
# ─────────────────────────────────────────────────
run_s2_validator_missing_field() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_validator_missing_field: missing display_name -> exit 1 --"

    cat > "$SANDBOX/cat.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["docs-research"],
  "components": {
    "mcp": {
      "broken": {
        "name": "broken",
        "category": "docs-research",
        "env_var_keys": [],
        "install_args": ["broken", "--", "npx", "-y", "broken-mcp"],
        "description": "no display_name on purpose",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local rc=0 out=""
    out=$(cd "$REPO_ROOT" && python3 scripts/validate-integrations-catalog.py "$SANDBOX/cat.json" 2>&1) || rc=$?
    assert_eq "1" "$rc" "S2: validator exits 1 on missing display_name"
    assert_contains "broken" "$out" "S2: stderr names broken entry"
    assert_contains "display_name" "$out" "S2: stderr mentions display_name field"
}

# ─────────────────────────────────────────────────
# S3 — validator_bad_category: fixture with category=frobnicate -> exit 1
# ─────────────────────────────────────────────────
run_s3_validator_bad_category() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_validator_bad_category: category=frobnicate -> exit 1 --"

    cat > "$SANDBOX/cat.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["docs-research", "dev-tools"],
  "components": {
    "mcp": {
      "evil": {
        "name": "evil",
        "display_name": "Evil",
        "category": "frobnicate",
        "env_var_keys": [],
        "install_args": ["evil", "--", "npx", "-y", "evil-mcp"],
        "description": "Bad category on purpose",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local rc=0 out=""
    out=$(cd "$REPO_ROOT" && python3 scripts/validate-integrations-catalog.py "$SANDBOX/cat.json" 2>&1) || rc=$?
    assert_eq "1" "$rc" "S3: validator exits 1 on invalid category"
    assert_contains "evil" "$out" "S3: stderr names offending entry"
    assert_contains "frobnicate" "$out" "S3: stderr names invalid category"
}

# ─────────────────────────────────────────────────
# S4 — validator_missing_components: fixture without components -> exit 1
# ─────────────────────────────────────────────────
run_s4_validator_missing_components() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_validator_missing_components: no components -> exit 1 --"

    cat > "$SANDBOX/cat.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["docs-research"]
}
JSON

    local rc=0 out=""
    out=$(cd "$REPO_ROOT" && python3 scripts/validate-integrations-catalog.py "$SANDBOX/cat.json" 2>&1) || rc=$?
    assert_eq "1" "$rc" "S4: validator exits 1 on missing components"
    assert_contains "components" "$out" "S4: stderr mentions components field"
}

# ─────────────────────────────────────────────────
# S5 — validator_bad_env_var_key: lowercase env_var_keys[0] -> exit 1
#       (Plan said "malformed cli block" but Phase 32 validator only
#        validates components.mcp; we exercise an MCP-block-scoped
#        invalid-shape check that DOES fire — keeping the must-have
#        intent: validator rejects malformed input -> exit 1.)
# ─────────────────────────────────────────────────
run_s5_validator_bad_env_var_key() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_validator_bad_env_var_key: lowercase env var -> exit 1 --"

    cat > "$SANDBOX/cat.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["docs-research"],
  "components": {
    "mcp": {
      "lowercase_env": {
        "name": "lowercase_env",
        "display_name": "Lowercase Env",
        "category": "docs-research",
        "env_var_keys": ["bad_lowercase_key"],
        "install_args": ["lowercase_env", "--", "npx", "-y", "lowercase-mcp"],
        "description": "Lowercase env var names rejected by POSIX shape",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local rc=0 out=""
    out=$(cd "$REPO_ROOT" && python3 scripts/validate-integrations-catalog.py "$SANDBOX/cat.json" 2>&1) || rc=$?
    assert_eq "1" "$rc" "S5: validator exits 1 on lowercase env_var_key"
    assert_contains "env_var_keys" "$out" "S5: stderr mentions env_var_keys field"
}

# ─────────────────────────────────────────────────
# S6 — cli_detect_present: cli_detect bash -> 0 (CLI-01)
# ─────────────────────────────────────────────────
run_s6_cli_detect_present() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_cli_detect_present: cli_detect bash -> 0 --"

    local rc=0
    bash -c "
        set -euo pipefail
        # shellcheck disable=SC1091
        source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
        cli_detect bash
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S6: cli_detect bash returns 0"
}

# ─────────────────────────────────────────────────
# S7 — cli_detect_absent: cli_detect __nope__ -> 1 (CLI-01)
# ─────────────────────────────────────────────────
run_s7_cli_detect_absent() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S7_cli_detect_absent: cli_detect __nope__ -> 1 --"

    local rc=0
    bash -c "
        # shellcheck disable=SC1091
        source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
        cli_detect __no_such_binary_xyz_pdq__ && exit 99 || exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "1" "$rc" "S7: cli_detect on absent binary returns 1"
}

# ─────────────────────────────────────────────────
# S8 — cli_install_dispatch_darwin: TK_CLI_UNAME=Darwin runs darwin_cmd only
# ─────────────────────────────────────────────────
run_s8_cli_install_dispatch_darwin() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S8_cli_install_dispatch_darwin: TK_CLI_UNAME=Darwin -> darwin_cmd only --"

    local out=""
    out=$(
        TK_CLI_UNAME=Darwin bash -c "
            # shellcheck disable=SC1091
            source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
            cli_install fake-cli 'echo darwin-stub-ran' 'echo linux-stub-ran'
        " 2>&1
    ) || true
    assert_contains "darwin-stub-ran" "$out" "S8: darwin command ran"
    assert_not_contains "linux-stub-ran" "$out" "S8: linux command did NOT run on Darwin"
}

# ─────────────────────────────────────────────────
# S9 — cli_install_dispatch_linux: TK_CLI_UNAME=Linux runs linux_cmd only
# ─────────────────────────────────────────────────
run_s9_cli_install_dispatch_linux() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S9_cli_install_dispatch_linux: TK_CLI_UNAME=Linux -> linux_cmd only --"

    local out=""
    out=$(
        TK_CLI_UNAME=Linux bash -c "
            # shellcheck disable=SC1091
            source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
            cli_install fake-cli 'echo darwin-stub-ran' 'echo linux-stub-ran'
        " 2>&1
    ) || true
    assert_contains "linux-stub-ran" "$out" "S9: linux command ran"
    assert_not_contains "darwin-stub-ran" "$out" "S9: darwin command did NOT run on Linux"
}

# ─────────────────────────────────────────────────
# S10 — cli_install_unsupported: TK_CLI_UNAME=FreeBSD -> rc=2 + stderr (CLI-02)
# ─────────────────────────────────────────────────
run_s10_cli_install_unsupported() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S10_cli_install_unsupported: TK_CLI_UNAME=FreeBSD -> rc=2 --"

    local rc=0 out=""
    out=$(
        TK_CLI_UNAME=FreeBSD bash -c "
            # shellcheck disable=SC1091
            source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
            cli_install some-cli 'echo unused' 'echo unused' 2>&1
        "
    ) || rc=$?
    assert_eq "2" "$rc" "S10: cli_install on unsupported platform returns 2"
    assert_contains "unsupported platform" "$out" "S10: stderr mentions unsupported platform"
}

# ─────────────────────────────────────────────────
# S11 — cli_install_brew_absent: Darwin + brew prefix + TK_CLI_BREW_BIN="" -> rc=3
# ─────────────────────────────────────────────────
run_s11_cli_install_brew_absent() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S11_cli_install_brew_absent: Darwin + brew prefix + brew absent -> rc=3 --"

    local rc=0 out=""
    out=$(
        TK_CLI_UNAME=Darwin TK_CLI_BREW_BIN="" bash -c "
            # shellcheck disable=SC1091
            source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
            cli_install supabase 'brew install supabase/tap/supabase' 'echo unused' 2>&1
        "
    ) || rc=$?
    assert_eq "3" "$rc" "S11: brew-absent fallback returns 3"
    assert_contains "brew not found" "$out" "S11: stderr emits brew-not-found hint"
    assert_contains "https://brew.sh" "$out" "S11: stderr includes brew install URL"
}

# ─────────────────────────────────────────────────
# S12 — cli_post_install_hint_stderr: hint goes to stderr only (CLI-04)
# ─────────────────────────────────────────────────
run_s12_cli_post_install_hint_stderr() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S12_cli_post_install_hint_stderr: hint goes to stderr only --"

    local stdout_file="$SANDBOX/out" stderr_file="$SANDBOX/err"
    bash -c "
        # shellcheck disable=SC1091
        source '${REPO_ROOT}/scripts/lib/cli-installer.sh'
        cli_post_install_hint 'wrangler login'
    " >"$stdout_file" 2>"$stderr_file" || true

    local stdout_size=0 stderr_content=""
    [[ -f "$stdout_file" ]] && stdout_size=$(wc -c < "$stdout_file" | tr -d ' ')
    [[ -f "$stderr_file" ]] && stderr_content=$(cat "$stderr_file")

    assert_eq "0" "$stdout_size" "S12: stdout is empty (parseable)"
    assert_contains "wrangler login" "$stderr_content" "S12: stderr contains hint text"
    assert_contains "Next:" "$stderr_content" "S12: stderr contains Next: prefix"
}

# ─────────────────────────────────────────────────
# S13 — install_sh_mcps_alias: --mcps prints "deprecated" to stderr, exit 0
# ─────────────────────────────────────────────────
run_s13_install_sh_mcps_alias() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S13_install_sh_mcps_alias: --mcps prints deprecation to stderr, exit 0 --"

    mkdir -p "$SANDBOX/.claude"

    local MOCK_CLAUDE="$SANDBOX/mock-claude"
    cat > "$MOCK_CLAUDE" <<'MOCK'
#!/bin/bash
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    echo ""
    exit 0
fi
exit 0
MOCK
    chmod +x "$MOCK_CLAUDE"

    local stderr_file="$SANDBOX/err" rc=0
    HOME="$SANDBOX" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
        NO_COLOR=1 \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes --dry-run \
        >/dev/null 2>"$stderr_file" || rc=$?

    local stderr_content
    stderr_content=$(cat "$stderr_file")

    assert_eq "0" "$rc" "S13: --mcps --dry-run exits 0"
    assert_contains "deprecated" "$stderr_content" "S13: stderr contains deprecation note"
}

# ─────────────────────────────────────────────────
# S14 — install_sh_integrations_alias: --integrations works WITHOUT deprecation
# ─────────────────────────────────────────────────
run_s14_install_sh_integrations_alias() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S14_install_sh_integrations_alias: --integrations works without deprecation --"

    mkdir -p "$SANDBOX/.claude"

    local MOCK_CLAUDE="$SANDBOX/mock-claude"
    cat > "$MOCK_CLAUDE" <<'MOCK'
#!/bin/bash
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    echo ""
    exit 0
fi
exit 0
MOCK
    chmod +x "$MOCK_CLAUDE"

    local stderr_file="$SANDBOX/err" rc=0
    HOME="$SANDBOX" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
        NO_COLOR=1 \
        bash "${REPO_ROOT}/scripts/install.sh" --integrations --yes --dry-run \
        >/dev/null 2>"$stderr_file" || rc=$?

    local stderr_content
    stderr_content=$(cat "$stderr_file")

    assert_eq "0" "$rc" "S14: --integrations --dry-run exits 0"
    assert_not_contains "deprecated" "$stderr_content" "S14: stderr does NOT contain deprecation note"
}

# ─────────────────────────────────────────────────
# S15 — mcp_sh_reads_new_path: _mcp_default_catalog_path -> integrations-catalog.json
# ─────────────────────────────────────────────────
run_s15_mcp_sh_reads_new_path() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S15_mcp_sh_reads_new_path: _mcp_default_catalog_path -> integrations-catalog.json --"

    local resolved=""
    resolved=$(bash -c "
        # shellcheck disable=SC1091
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        _mcp_default_catalog_path
    " 2>/dev/null)

    assert_contains "integrations-catalog.json" "$resolved" "S15: default path basename is integrations-catalog.json"
    assert_not_contains "mcp-catalog.json" "$resolved" "S15: default path does NOT contain old basename mcp-catalog.json"
}

run_s1_validator_happy_path
run_s2_validator_missing_field
run_s3_validator_bad_category
run_s4_validator_missing_components
run_s5_validator_bad_env_var_key
run_s6_cli_detect_present
run_s7_cli_detect_absent
run_s8_cli_install_dispatch_darwin
run_s9_cli_install_dispatch_linux
run_s10_cli_install_unsupported
run_s11_cli_install_brew_absent
run_s12_cli_post_install_hint_stderr
run_s13_install_sh_mcps_alias
run_s14_install_sh_integrations_alias
run_s15_mcp_sh_reads_new_path

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
