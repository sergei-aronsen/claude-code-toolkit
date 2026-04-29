#!/usr/bin/env bash
# test-mcp-selector.sh — Phase 25 hermetic integration test.
#
# Scenarios (18 assertions across 8 scenarios):
#   S1_catalog_correctness    — catalog loads 9 entries; first alpha = context7; notion is OAuth
#   S2_detection_three_state  — installed / not-installed / CLI-absent three-state return
#   S3_secret_persistence     — mcp_secrets_set writes KEY=VALUE, mode 0600, idempotent
#   S4_collision_default_n    — collision prompt default N preserves existing value
#   S5_collision_y_overwrites — collision prompt y overwrites existing value, no duplicate
#   S6_wizard_hidden_input    — secret NOT in stdout/stderr; secret persisted to mcp-config.env
#   S7_install_sh_dry_run     — install.sh --mcps --yes --dry-run exits 0; shows would-install rows
#   S8_install_sh_no_cli      — install.sh --mcps --yes without CLI exits 0; shows CLI-absent banner
#
# Test seam env vars: TK_MCP_CLAUDE_BIN, TK_MCP_CONFIG_HOME, TK_MCP_TTY_SRC
#
# Usage: bash scripts/tests/test-mcp-selector.sh
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
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

echo "test-mcp-selector.sh: MCP-01..05 + MCP-SEC-01..02 integration suite"
echo ""

# ─────────────────────────────────────────────────
# S1_catalog_correctness — catalog loads 9 entries; alpha-first = context7; notion is OAuth
# MCP-01
# ─────────────────────────────────────────────────
run_s1_catalog_correctness() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_catalog_correctness: 9 entries, alpha order, notion OAuth --"

    MCP_NAMES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"
    mcp_catalog_load

    assert_eq "9" "${#MCP_NAMES[@]}" "S1: catalog contains 9 entries"
    assert_eq "context7" "${MCP_NAMES[0]}" "S1: alphabetical first entry is context7"

    # Find notion index and verify requires_oauth = 1
    local notion_idx
    notion_idx=$(_mcp_lookup_index "notion")
    assert_eq "1" "${MCP_OAUTH[$notion_idx]}" "S1: notion MCP_OAUTH is 1 (requires_oauth=true)"
}

# ─────────────────────────────────────────────────
# S2_detection_three_state — 0 (installed) / 1 (not-installed) / 2 (CLI absent)
# MCP-02
# ─────────────────────────────────────────────────
run_s2_detection_three_state() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_detection_three_state: three-state is_mcp_installed contract --"

    # Build mock claude that prints one MCP row for context7
    local MOCK_CLAUDE="$SANDBOX/mock-claude"
    cat > "$MOCK_CLAUDE" <<'MOCK'
#!/bin/bash
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    echo "context7    sse    https://mcp.context7.com"
    exit 0
fi
exit 0
MOCK
    chmod +x "$MOCK_CLAUDE"

    # State 0: context7 is installed (CLI present, row found)
    local rc=0
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        is_mcp_installed context7
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S2: is_mcp_installed context7 returns 0 (installed)"

    # State 1: firecrawl not in list output
    rc=0
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        is_mcp_installed firecrawl
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "1" "$rc" "S2: is_mcp_installed firecrawl returns 1 (not installed)"

    # State 2: CLI absent (PATH stripped, no TK_MCP_CLAUDE_BIN)
    rc=0
    PATH=/usr/bin:/bin bash -c "
        unset TK_MCP_CLAUDE_BIN _MCP_CLI_WARNED 2>/dev/null || true
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        is_mcp_installed context7
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "2" "$rc" "S2: is_mcp_installed returns 2 when CLI absent (fail-soft)"
}

# ─────────────────────────────────────────────────
# S3_secret_persistence_and_mode — write, read back, mode 0600
# MCP-SEC-01
# ─────────────────────────────────────────────────
run_s3_secret_persistence_and_mode() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_secret_persistence_and_mode: write + readback + 0600 mode --"

    mkdir -p "$SANDBOX/.claude"
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"

    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_set FOO bar

    local cfg_file="$SANDBOX/.claude/mcp-config.env"
    local file_content
    file_content="$(cat "$cfg_file")"
    assert_contains "FOO=bar" "$file_content" "S3: FOO=bar persisted to mcp-config.env"

    # Cross-platform mode check
    local mode_ok=0
    if stat -f '%Mp%Lp' "$cfg_file" 2>/dev/null | grep -q "^0600$"; then
        mode_ok=1
    elif [ "$(stat -c '%a' "$cfg_file" 2>/dev/null)" = "600" ]; then
        mode_ok=1
    fi
    assert_eq "1" "$mode_ok" "S3: mcp-config.env mode is 0600"

    # Second write — mode must still be 0600
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_set BAR baz

    file_content="$(cat "$cfg_file")"
    assert_contains "BAR=baz" "$file_content" "S3: BAR=baz persisted on second write"

    mode_ok=0
    if stat -f '%Mp%Lp' "$cfg_file" 2>/dev/null | grep -q "^0600$"; then
        mode_ok=1
    elif [ "$(stat -c '%a' "$cfg_file" 2>/dev/null)" = "600" ]; then
        mode_ok=1
    fi
    assert_eq "1" "$mode_ok" "S3: mode 0600 preserved after second write"
}

# ─────────────────────────────────────────────────
# S4_collision_prompt_default_n — default N preserves existing value
# MCP-SEC-02
# ─────────────────────────────────────────────────
run_s4_collision_prompt_default_n() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_collision_prompt_default_n: collision default N preserves existing --"

    mkdir -p "$SANDBOX/.claude"
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"

    # Write initial value
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_set FOO bar

    # Write fixture for TTY — answer "N"
    printf 'N\n' > "$SANDBOX/tty.fix"

    # Attempt overwrite with default-N fixture
    TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_TTY_SRC="$SANDBOX/tty.fix" \
        mcp_secrets_set FOO new_value 2>/dev/null || true

    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_load
    assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "S4: default-N preserves original FOO=bar"

    # Function should have returned 0 (no error, deliberate no-op)
    local rc=0
    printf 'N\n' > "$SANDBOX/tty.fix2"
    TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_TTY_SRC="$SANDBOX/tty.fix2" \
        mcp_secrets_set FOO another_value 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S4: collision N answer returns exit 0 (deliberate no-op)"
}

# ─────────────────────────────────────────────────
# S5_collision_prompt_y_overwrites — y overwrites, no duplicate key
# MCP-SEC-02
# ─────────────────────────────────────────────────
run_s5_collision_prompt_y_overwrites() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_collision_prompt_y_overwrites: y answer overwrites, no duplicate --"

    mkdir -p "$SANDBOX/.claude"
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"

    # Write initial value
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_set FOO bar

    # Answer "y" to overwrite
    printf 'y\n' > "$SANDBOX/tty.fix"
    TK_MCP_CONFIG_HOME="$SANDBOX" TK_MCP_TTY_SRC="$SANDBOX/tty.fix" \
        mcp_secrets_set FOO updated_value 2>/dev/null || true

    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    TK_MCP_CONFIG_HOME="$SANDBOX" mcp_secrets_load
    assert_eq "updated_value" "${MCP_SECRET_VALUES[0]}" "S5: y answer overwrites FOO with new value"

    # FOO must appear exactly once (no duplicate)
    local cfg_file="$SANDBOX/.claude/mcp-config.env"
    local count
    count=$(grep -c "^FOO=" "$cfg_file" || true)
    assert_eq "1" "$count" "S5: FOO appears exactly once after y-overwrite (no duplicate)"
}

# ─────────────────────────────────────────────────
# S6_wizard_hidden_input_no_leak — secret must NOT appear in stdout/stderr
# MCP-04 + MCP-SEC-01
# ─────────────────────────────────────────────────
run_s6_wizard_hidden_input_no_leak() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_wizard_hidden_input_no_leak: secret not in output, persisted to file --"

    mkdir -p "$SANDBOX/.claude"

    # Build mock claude that exits 0 silently
    local MOCK_CLAUDE="$SANDBOX/mock-claude"
    printf '#!/bin/bash\nexit 0\n' > "$MOCK_CLAUDE"
    chmod +x "$MOCK_CLAUDE"

    # Fixture TTY: the secret value
    printf 'secret_xyz\n' > "$SANDBOX/tty.fix"

    # Reset all MCP arrays before sourcing
    # shellcheck disable=SC2034
    MCP_NAMES=()
    # shellcheck disable=SC2034
    MCP_SECRET_KEYS=()
    # shellcheck disable=SC2034
    MCP_SECRET_VALUES=()

    local OUTPUT
    OUTPUT=$(
        TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        TK_MCP_TTY_SRC="$SANDBOX/tty.fix" \
        bash -c "
            source '${REPO_ROOT}/scripts/lib/mcp.sh'
            mcp_catalog_load
            mcp_wizard_run context7
        " 2>&1
    ) || true

    assert_not_contains "secret_xyz" "$OUTPUT" "S6: secret value MUST NOT appear in wizard output"

    local cfg_file="$SANDBOX/.claude/mcp-config.env"
    local file_content=""
    if [[ -f "$cfg_file" ]]; then
        file_content="$(cat "$cfg_file")"
    fi
    assert_contains "CONTEXT7_API_KEY=secret_xyz" "$file_content" "S6: secret persisted to mcp-config.env"
}

# ─────────────────────────────────────────────────
# S7_install_sh_mcps_dry_run — install.sh --mcps --yes --dry-run shows would-install
# MCP-05 + MCP-03
# ─────────────────────────────────────────────────
run_s7_install_sh_mcps_dry_run() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S7_install_sh_mcps_dry_run: --dry-run exits 0, shows would-install + summary --"

    mkdir -p "$SANDBOX/.claude"

    # Build mock claude that records 'mcp list' as empty output (all MCPs "not installed")
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

    local RC=0
    local OUTPUT
    OUTPUT=$(
        HOME="$SANDBOX" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
        NO_COLOR=1 \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes --dry-run 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S7: install.sh --mcps --yes --dry-run exits 0"
    assert_contains "would-install" "$OUTPUT" "S7: --dry-run summary shows would-install rows"
    assert_contains "MCP install summary" "$OUTPUT" "S7: MCP-branch summary header rendered"
}

# ─────────────────────────────────────────────────
# S8_install_sh_mcps_no_cli — CLI-absent banner, exits 0 (browse-only mode)
# MCP-03 CLI-absent degradation + MCP-05
# ─────────────────────────────────────────────────
run_s8_install_sh_mcps_no_cli() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S8_install_sh_mcps_no_cli: CLI absent → banner + exit 0 --"

    mkdir -p "$SANDBOX/.claude"

    local RC=0
    local OUTPUT
    OUTPUT=$(
        HOME="$SANDBOX" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        PATH=/usr/bin:/bin \
        NO_COLOR=1 \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes 2>&1
    ) || RC=$?

    assert_contains "claude CLI not found" "$OUTPUT" "S8: CLI-absent banner emitted"
    assert_eq "0" "$RC" "S8: --mcps without CLI exits 0 (read-only browse mode)"
}

run_s1_catalog_correctness
run_s2_detection_three_state
run_s3_secret_persistence_and_mode
run_s4_collision_prompt_default_n
run_s5_collision_prompt_y_overwrites
run_s6_wizard_hidden_input_no_leak
run_s7_install_sh_mcps_dry_run
run_s8_install_sh_mcps_no_cli

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
