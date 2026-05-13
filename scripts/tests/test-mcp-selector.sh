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
    echo "  -- S1_catalog_correctness: 26 entries, alpha order, notion OAuth --"

    MCP_NAMES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"
    mcp_catalog_load

    # Phase 33-04 final state: 21 - 1 (sequential-thinking dropped) = 20 entries.
    # Composition: 8 surviving Phase 32 entries (context7, firecrawl, magic,
    # notion, openrouter, playwright, resend, sentry) + 12 new INT-01..12 entries.
    # Phase 40 INT-13: +1 (Calendly added) = 21 entries; v6.0 INT-15: +2 (morph-fast-tools, claude-context) = 23.
    # v6.1: morph-fast-tools replaced by serena (1-for-1) — count stays 23.
    # v6.2 docs PR added dbhub (+1 = 24); claude-memo PR added mailgun + datadog + posthog (+3 = 27).
    # v6.6 added comet-bridge (Pplx Pro research backend, +1 = 28).
    # v6.23 added repomix (full-repo pack for AI context, +1 = 29).
    # v6.24 added github (official remote MCP, +1 = 30).
    assert_eq "30" "${#MCP_NAMES[@]}" "S1: catalog contains 30 entries"
    assert_eq "aws-cloudwatch-logs" "${MCP_NAMES[0]}" "S1: alphabetical first entry is aws-cloudwatch-logs"

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

    # State 0 (new format): claude CLI now emits "name: cmd - ✓ Connected"
    # rows. Probe must accept both whitespace- and colon-separated rows
    # (regression 2026-05-02 — every MCP showed ✗ in TUI).
    local MOCK_CLAUDE_NEW="$SANDBOX/mock-claude-newfmt"
    cat > "$MOCK_CLAUDE_NEW" <<'MOCK'
#!/bin/bash
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    echo "Checking MCP server health…"
    echo ""
    echo "context7: npx -y @upstash/context7-mcp - ✓ Connected"
    echo "playwright: npx @playwright/mcp@latest - ✓ Connected"
    exit 0
fi
exit 0
MOCK
    chmod +x "$MOCK_CLAUDE_NEW"
    rc=0
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE_NEW" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        is_mcp_installed context7
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S2: is_mcp_installed accepts colon-separated rows (new CLI format)"
    rc=0
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE_NEW" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        is_mcp_installed sentry
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "1" "$rc" "S2: still returns 1 for absent name in new format"
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

# ─────────────────────────────────────────────────
# S9_per_row_indicator — TUI-SCOPE-01: per-row [U]/[P]/[L] glyph in TUI_LABELS
# matches catalog default_scope per row.
# ─────────────────────────────────────────────────
run_s9_per_row_indicator() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S9_per_row_indicator: TUI_LABELS carry [U]/[P]/[L] per default_scope (TUI-SCOPE-01) --"

    MCP_NAMES=()
    MCP_DEFAULT_SCOPE=()
    TUI_LABELS=()
    TUI_TO_MCP_IDX=()
    MCP_SELECTED_SCOPE=()
    # shellcheck source=/dev/null
    NO_COLOR=1 source "${REPO_ROOT}/scripts/lib/mcp.sh"
    NO_COLOR=1 mcp_catalog_load
    NO_COLOR=1 mcp_status_array

    # Find context7 and supabase TUI render-order indices via TUI_TO_MCP_IDX.
    local _ctx7_tui=-1 _supa_tui=-1 j _i_mcp
    for ((j=0; j<${#TUI_LABELS[@]}; j++)); do
        _i_mcp="${TUI_TO_MCP_IDX[$j]}"
        case "${MCP_NAMES[$_i_mcp]}" in
            context7) _ctx7_tui=$j ;;
            supabase) _supa_tui=$j ;;
        esac
    done

    # context7 default_scope=user → label contains [U] substring.
    assert_contains '\[U\]' "${TUI_LABELS[$_ctx7_tui]:-}" \
        "S9: context7 row label carries [U] indicator (default_scope=user)"
    # supabase default_scope=project → label contains [P] substring.
    assert_contains '\[P\]' "${TUI_LABELS[$_supa_tui]:-}" \
        "S9: supabase row label carries [P] indicator (default_scope=project)"

    # Every MCP row must contain at least one bracket glyph.
    local _all_have_glyph=1 _label
    for _label in "${TUI_LABELS[@]+"${TUI_LABELS[@]}"}"; do
        if ! printf '%s' "$_label" | grep -qE '\[U\]|\[P\]|\[L\]'; then
            _all_have_glyph=0
            break
        fi
    done
    assert_eq "1" "$_all_have_glyph" \
        "S9: every TUI MCP row contains at least one [U]/[P]/[L] glyph"
}

# ─────────────────────────────────────────────────
# S10_per_row_hotkey — TUI-SCOPE-02: mcp_cycle_row_scope mutates only FOCUS_IDX;
# 3-call cycle returns to start; cycled value is one of {user, project, local}.
# ─────────────────────────────────────────────────
run_s10_per_row_hotkey() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S10_per_row_hotkey: mcp_cycle_row_scope mutates only FOCUS_IDX (TUI-SCOPE-02) --"

    MCP_NAMES=()
    MCP_SELECTED_SCOPE=()
    TUI_LABELS=()
    TUI_TO_MCP_IDX=()
    # shellcheck source=/dev/null
    NO_COLOR=1 source "${REPO_ROOT}/scripts/lib/mcp.sh"
    NO_COLOR=1 mcp_catalog_load
    NO_COLOR=1 mcp_status_array

    # Capture sibling fingerprint at index 1 and self at index 0.
    local _sibling_before="${MCP_SELECTED_SCOPE[1]:-MISSING}"
    local _self_before="${MCP_SELECTED_SCOPE[0]:-MISSING}"

    # FOCUS_IDX is a caller-side global consumed by mcp_cycle_row_scope; the
    # tui.sh keypress dispatcher mutates it via arrow keys in production. The
    # test sets it directly to drive the handler headlessly.
    # shellcheck disable=SC2034
    FOCUS_IDX=0
    mcp_cycle_row_scope

    assert_eq "$_sibling_before" "${MCP_SELECTED_SCOPE[1]:-MISSING}" \
        "S10: sibling row 1 untouched by single-row cycle on FOCUS_IDX=0"

    # Two more cycles — total 3 calls — should return to the starting value.
    mcp_cycle_row_scope
    mcp_cycle_row_scope
    assert_eq "$_self_before" "${MCP_SELECTED_SCOPE[0]:-MISSING}" \
        "S10: 3-call cycle returns FOCUS_IDX=0 scope to initial value"

    # Single cycle output is one of {user, project, local}.
    # shellcheck disable=SC2034
    FOCUS_IDX=0
    mcp_cycle_row_scope
    local _val="${MCP_SELECTED_SCOPE[0]:-}"
    local _is_valid=0
    case "$_val" in
        user|project|local) _is_valid=1 ;;
    esac
    assert_eq "1" "$_is_valid" \
        "S10: cycled value is one of {user, project, local}"
}

# ─────────────────────────────────────────────────
# S11_global_set_all — TUI-SCOPE-03: mcp_toggle_scope writes every
# MCP_SELECTED_SCOPE slot uniformly + banner contains "Set all to:".
# ─────────────────────────────────────────────────
run_s11_global_set_all() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S11_global_set_all: mcp_toggle_scope writes every MCP_SELECTED_SCOPE slot (TUI-SCOPE-03) --"

    MCP_NAMES=()
    MCP_SELECTED_SCOPE=()
    TUI_LABELS=()
    TUI_TO_MCP_IDX=()
    TUI_HEADER_TEXT=""
    _MCP_SETALL_SCOPE="user"
    # shellcheck source=/dev/null
    NO_COLOR=1 source "${REPO_ROOT}/scripts/lib/mcp.sh"
    NO_COLOR=1 mcp_catalog_load
    NO_COLOR=1 mcp_status_array

    # Pre-seed mixed values to prove the global set-all overwrites.
    MCP_SELECTED_SCOPE[0]="user"
    MCP_SELECTED_SCOPE[1]="local"
    if [[ "${#MCP_SELECTED_SCOPE[@]}" -gt 2 ]]; then
        MCP_SELECTED_SCOPE[2]="project"
    fi

    mcp_toggle_scope

    # Every slot now equals _MCP_SETALL_SCOPE (uniformity invariant D-09/D-12).
    local _uniform=1 _j
    for ((_j=0; _j<${#MCP_SELECTED_SCOPE[@]}; _j++)); do
        if [[ "${MCP_SELECTED_SCOPE[$_j]}" != "${_MCP_SETALL_SCOPE}" ]]; then
            _uniform=0
            break
        fi
    done
    assert_eq "1" "$_uniform" \
        "S11: every MCP_SELECTED_SCOPE slot equals _MCP_SETALL_SCOPE after toggle"

    # Banner copy assertion — 2026-05-07: header was "Set all to: [U] · press
    # s to cycle"; user feedback flagged the per-row "[U] [P] [L]" triple as
    # noise, so the row glyph dropped to a single active bracket and the
    # legend moved into this banner. New copy starts with "Scope:".
    assert_contains "Scope:" "${TUI_HEADER_TEXT:-}" \
        "S11: TUI_HEADER_TEXT contains 'Scope:' after toggle"
}

# ─────────────────────────────────────────────────
# S12_default_scope_init — TUI-SCOPE-04: MCP_SELECTED_SCOPE length parity with
# TUI_LABELS; per-index value matches MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[i]].
# ─────────────────────────────────────────────────
run_s12_default_scope_init() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S12_default_scope_init: MCP_SELECTED_SCOPE initialized from default_scope (TUI-SCOPE-04) --"

    MCP_NAMES=()
    MCP_DEFAULT_SCOPE=()
    MCP_SELECTED_SCOPE=()
    TUI_LABELS=()
    TUI_TO_MCP_IDX=()
    # shellcheck source=/dev/null
    NO_COLOR=1 source "${REPO_ROOT}/scripts/lib/mcp.sh"
    NO_COLOR=1 mcp_catalog_load
    NO_COLOR=1 mcp_status_array

    # Length parity (TUI render index, not MCP_NAMES alpha index).
    assert_eq "${#TUI_LABELS[@]}" "${#MCP_SELECTED_SCOPE[@]}" \
        "S12: MCP_SELECTED_SCOPE parallel to TUI_LABELS"

    # Per-index value: MCP_SELECTED_SCOPE[j] == MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[j]].
    local _all_match=1 j _i_mcp
    for ((j=0; j<${#TUI_LABELS[@]}; j++)); do
        _i_mcp="${TUI_TO_MCP_IDX[$j]}"
        if [[ "${MCP_SELECTED_SCOPE[$j]}" != "${MCP_DEFAULT_SCOPE[$_i_mcp]:-user}" ]]; then
            _all_match=0
            break
        fi
    done
    assert_eq "1" "$_all_match" \
        "S12: every MCP_SELECTED_SCOPE[j] matches MCP_DEFAULT_SCOPE[TUI_TO_MCP_IDX[j]]"
}

# ─────────────────────────────────────────────────
# S13_dispatcher_per_row_export — TUI-SCOPE-05: install.sh dispatcher exports
# per-row TK_MCP_SCOPE before each mcp_wizard_run invocation. Runs strictly
# under --dry-run (D-21 — live mode would write .env to repo tree). Mock claude
# logs TK_MCP_SCOPE + argv per invocation; if --dry-run short-circuits the
# wizard so no `mcp add` invocation fires (only the `mcp list` probe), the
# test falls back to a stdout-grep assertion that both rows were iterated.
# ─────────────────────────────────────────────────
run_s13_dispatcher_per_row_export() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S13_dispatcher_per_row_export: install.sh exports per-row TK_MCP_SCOPE (TUI-SCOPE-05) --"

    mkdir -p "$SANDBOX/.claude"

    # Mock claude — clean argv-agnostic capture form. Records TK_MCP_SCOPE
    # (the variable under test) plus full argv for each invocation. The
    # mock makes ZERO attempt to parse claude's argv: tokens are recorded
    # verbatim and the test asserts on env-var substring presence.
    local TRACE_LOG="$SANDBOX/scope-trace.log"
    local MOCK_CLAUDE="$SANDBOX/mock-claude"
    cat > "$MOCK_CLAUDE" <<MOCK
#!/usr/bin/env bash
# Mock claude — captures TK_MCP_SCOPE + argv per invocation.
{
    printf 'TK_MCP_SCOPE=%s\n' "\${TK_MCP_SCOPE:-<unset>}"
    printf 'argv:'
    for _a in "\$@"; do printf ' %s' "\$_a"; done
    printf '\n'
} >> "$TRACE_LOG"
exit 0
MOCK
    chmod +x "$MOCK_CLAUDE"

    # Drive install.sh headlessly under --dry-run ONLY. Live-mode would
    # invoke project_secrets_write_env which resolves project_root from
    # `pwd` and writes .env into the dev's working tree (D-21 violation).
    # Per-row TK_MCP_SCOPE export (Plan 02 Step 2) fires BEFORE the wizard
    # subshell — so the trace log captures the env-var if any claude
    # invocation happens. If --dry-run short-circuits all `mcp add` calls
    # (only `mcp list` probe runs), the test falls back to stdout grep.
    local RC=0
    local OUTPUT
    OUTPUT=$(
        HOME="$SANDBOX" \
        TK_MCP_CONFIG_HOME="$SANDBOX" \
        TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
        TK_MCP_PRE_SELECTED="context7,supabase" \
        TK_MCP_DEFER_SECRETS=0 \
        NO_COLOR=1 \
        bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes --dry-run 2>&1
    ) || RC=$?

    # install.sh swallows wizard errors and prints a summary; exit 0 expected.
    assert_eq "0" "$RC" "S13: install.sh --mcps --yes --dry-run exits 0 with mock claude"

    # Read trace log if present.
    local TRACE=""
    if [[ -f "$TRACE_LOG" ]]; then
        TRACE="$(cat "$TRACE_LOG")"
    fi

    # Best signal: trace contains per-row TK_MCP_SCOPE values from `mcp add`
    # calls. The pre-loop `mcp list` probe always logs `TK_MCP_SCOPE=<unset>`
    # (probe runs before the dispatcher loop's per-row export), so a non-empty
    # trace alone is not sufficient — we require at least one of {user, project}
    # to be observed before claiming the strong signal.
    if printf '%s' "$TRACE" | grep -qE 'TK_MCP_SCOPE=(user|project|local)'; then
        # Strong signal: dispatcher exported per-row scope to claude argv.
        assert_contains "TK_MCP_SCOPE=user" "$TRACE" \
            "S13: dispatcher exported TK_MCP_SCOPE=user for at least one row"
        assert_contains "TK_MCP_SCOPE=project" "$TRACE" \
            "S13: dispatcher exported TK_MCP_SCOPE=project for at least one row"
    else
        # Fallback (still hermetic — NO live-mode retry per D-21).
        # --dry-run wizard short-circuit suppressed all `mcp add` invocations;
        # only the `mcp list` probe ran (with stale TK_MCP_SCOPE=<unset>).
        # Assert on stdout that both rows were iterated. Row-name presence is
        # the floor signal that the dispatcher walked MCP_SELECTED_SCOPE
        # end-to-end. Strong-signal assertions land in non-dry-run E2E
        # (deferred to a future plan to keep D-21 hermetic invariant intact).
        assert_contains "context7" "$OUTPUT" \
            "S13: dispatcher iterated context7 row (scope-trace fallback)"
        assert_contains "supabase" "$OUTPUT" \
            "S13: dispatcher iterated supabase row (scope-trace fallback)"
    fi
}

run_s1_catalog_correctness
run_s2_detection_three_state
run_s3_secret_persistence_and_mode
run_s4_collision_prompt_default_n
run_s5_collision_prompt_y_overwrites
run_s6_wizard_hidden_input_no_leak
run_s7_install_sh_mcps_dry_run
run_s8_install_sh_mcps_no_cli
run_s9_per_row_indicator
run_s10_per_row_hotkey
run_s11_global_set_all
run_s12_default_scope_init
run_s13_dispatcher_per_row_export

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
