#!/usr/bin/env bash
# test-mcp-lock-screen-glyph.sh — regression test for the double scope-glyph
# bug in install.sh's TUI lock-screen (user report 2026-05-12, screenshot).
#
# Bug: install.sh's lock-screen shadow-build loop copies labels verbatim from
# the parent TUI (where labels already contain a `[U] `/`[P] `/`[L] ` scope
# glyph set by `_mcp_rebuild_row_labels` during MCP catalog load), and then
# prepends ANOTHER scope glyph in the manual loop at install.sh:446-455. The
# result on screen is `[U] [U] Cloudflare` / `[P] [P] Stripe`, etc. Pressing
# Tab fires `mcp_cycle_row_scope_locked` which rebuilds the row from
# `MCP_DISPLAY[]`, masking the bug for that single row only.
#
# Fix: delegate the label rebuild in the lock-screen init to the canonical
# `_mcp_rebuild_row_labels` helper in mcp.sh (which writes `TUI_LABELS[$_j]`
# from scratch using `MCP_DISPLAY[]` + a SINGLE `_mcp_render_scope_glyph`).
#
# Scenarios:
#   LG1_canonical_helper_single_glyph — _mcp_rebuild_row_labels produces
#                                       labels containing exactly ONE scope
#                                       bracket regardless of the prior
#                                       state of TUI_LABELS[i] (idempotency
#                                       contract the fix relies on).
#   LG2_install_sh_delegates_rebuild  — install.sh's lock-screen init block
#                                       calls _mcp_rebuild_row_labels and
#                                       does NOT carry the legacy manual
#                                       glyph-prepend loop (structural
#                                       regression guard).
#
# Usage: bash scripts/tests/test-mcp-lock-screen-glyph.sh
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
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n      %s\n" "$1" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_contains() {
    local pat="$1" hay="$2" label="$3"
    if printf '%s\n' "$hay" | grep -Fq -- "$pat"; then assert_pass "$label"
    else assert_fail "$label" "pattern not found: $pat"; fi
}
assert_not_contains() {
    local pat="$1" hay="$2" label="$3"
    if ! printf '%s\n' "$hay" | grep -Fq -- "$pat"; then assert_pass "$label"
    else assert_fail "$label" "unexpected pattern present: $pat"; fi
}

echo "test-mcp-lock-screen-glyph.sh: lock-screen double-glyph regression"
echo ""

# ─────────────────────────────────────────────────
# LG1 — _mcp_rebuild_row_labels produces single glyph regardless of prior
#       TUI_LABELS state. Documents the contract the fix relies on.
# ─────────────────────────────────────────────────
run_lg1_canonical_helper_single_glyph() {
    echo "  -- LG1_canonical_helper_single_glyph --"
    local out rc=0
    out=$(NO_COLOR=1 bash -c "
        set -u
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        # Mimic the shadow-build state just before the lock-screen render:
        # TUI_LABELS[i] already carries a scope glyph copied from the parent
        # _SAVE_LABELS array. The canonical rebuild must replace each entry
        # with a single-glyph version derived from MCP_DISPLAY[].
        TUI_LABELS=('[U] Cloudflare' '[P] Stripe' '[L] DBHub')
        TUI_TO_MCP_IDX=(0 1 2)
        MCP_NAMES=(cloudflare stripe dbhub)
        MCP_DISPLAY=('Cloudflare' 'Stripe' 'DBHub')
        MCP_UNOFFICIAL=(0 0 0)
        MCP_SELECTED_SCOPE=(user project local)
        _mcp_rebuild_row_labels
        printf 'L0=%s\n' \"\${TUI_LABELS[0]}\"
        printf 'L1=%s\n' \"\${TUI_LABELS[1]}\"
        printf 'L2=%s\n' \"\${TUI_LABELS[2]}\"
    " 2>&1) || rc=$?

    assert_eq "0" "$rc" "LG1: helper exits clean"
    assert_contains "L0=[U] Cloudflare" "$out" "LG1: row 0 single [U] glyph + display name"
    assert_contains "L1=[P] Stripe"     "$out" "LG1: row 1 single [P] glyph + display name"
    assert_contains "L2=[L] DBHub"      "$out" "LG1: row 2 single [L] glyph + display name"
    assert_not_contains "[U] [U]" "$out" "LG1: no double [U] glyph"
    assert_not_contains "[P] [P]" "$out" "LG1: no double [P] glyph"
    assert_not_contains "[L] [L]" "$out" "LG1: no double [L] glyph"
}

# ─────────────────────────────────────────────────
# LG2 — install.sh's lock-screen init delegates label rebuild to the
#       canonical helper. Structural regression guard against the legacy
#       manual prepend loop returning.
# ─────────────────────────────────────────────────
run_lg2_install_sh_delegates_rebuild() {
    echo "  -- LG2_install_sh_delegates_rebuild --"
    local install_sh="${REPO_ROOT}/scripts/install.sh"

    # The lock-screen init lives roughly between the "v6.16.0 (T-05/06/07)"
    # banner and the `tui_checklist || _lock_rc=$?` call. Carve out that
    # block by line range so structural assertions don't trip on similar
    # patterns elsewhere in the file.
    local start_line end_line
    start_line=$(grep -n '# v6.16.0 (T-05/06/07)' "$install_sh" | head -1 | cut -d: -f1)
    if [[ -z "$start_line" ]]; then
        assert_fail "LG2: locate lock-screen banner" "marker '# v6.16.0 (T-05/06/07)' not found"
        return
    fi
    # Take a generous window — the block sits inside a single function;
    # 200 lines covers the shadow build + label rebuild + tui_checklist.
    end_line=$((start_line + 200))

    local block
    block=$(sed -n "${start_line},${end_line}p" "$install_sh")

    # The fix MUST call the canonical helper inside the lock-screen block.
    assert_contains "_mcp_rebuild_row_labels" "$block" \
        "LG2: lock-screen block calls _mcp_rebuild_row_labels"

    # The fix MUST NOT carry the legacy inline case-on-scope + manual
    # TUI_LABELS[_i]="${_g} ${_name}" prepend. That construct was the bug
    # source — its presence means the manual loop is still there.
    assert_not_contains 'TUI_LABELS[_i]="${_g} ${_name}"' "$block" \
        "LG2: lock-screen block dropped manual TUI_LABELS[_i]=\${_g} \${_name} prepend"
    assert_not_contains '_g="[U]"' "$block" \
        "LG2: lock-screen block dropped hardcoded _g=[U] glyph assignment"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
run_lg1_canonical_helper_single_glyph
run_lg2_install_sh_delegates_rebuild

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
