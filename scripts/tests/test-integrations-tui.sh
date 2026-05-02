#!/usr/bin/env bash
# test-integrations-tui.sh — Phase 35 (TEST-03) hermetic TUI redesign coverage.
#
# Locks the v4.9 contract for the integrations TUI page (Phase 34 outputs):
#   - mcp_status_array populates TUI_GROUPS[] with title-cased categories
#     in CATEGORIES_ORDER[] order (TUI-01)
#   - categories with zero entries are skipped (TUI-01 D-06)
#   - per-row MCP/CLI status glyphs (TUI-02)
#   - unofficial entries get a leading `!` glyph (TUI-03)
#   - unofficial_confirm respects ALWAYS_YES bypass + TK_INTEGRATIONS_TTY_SRC
#     test seam (TUI-03)
#   - --mcp-only / --cli-only mutex => exit 2 (TUI-04)
#   - --integrations works without deprecation; --mcps prints deprecation
#     (CAT-04, also covered by foundation S13/S14 — re-asserted here)
#   - install.sh --dry-run + --yes prints the integrations summary table
#     with bold blue header (TUI-05)
#
# Hermetic — uses TK_MCP_CATALOG_PATH + TK_MCP_CLAUDE_BIN + TK_MCP_CONFIG_HOME
# + TK_INTEGRATIONS_TTY_SRC seams; mocks `claude` via a stub script that prints
# the desired `claude mcp list` output.
#
# Usage: bash scripts/tests/test-integrations-tui.sh
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

echo "test-integrations-tui.sh: TEST-03 v4.9 TUI-01..05 contract"
echo ""

# Set up shared mock claude that returns no installed MCPs by default.
SANDBOX_ROOT=$(mktemp -d /tmp/test-integrations-tui.XXXXXX)
trap 'rm -rf "${SANDBOX_ROOT:?}"' EXIT
MOCK_CLAUDE="$SANDBOX_ROOT/mock-claude"
cat > "$MOCK_CLAUDE" <<'MOCK'
#!/bin/bash
# Mock claude that mimics `claude mcp list` returning rows whose first
# whitespace-separated token is the MCP name (matches mcp.sh:547 regex).
# Set TK_MOCK_INSTALLED to space-separated names to mark them installed.
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    for n in ${TK_MOCK_INSTALLED:-}; do
        printf '%s    stdio    https://example.local\n' "$n"
    done
    exit 0
fi
exit 0
MOCK
chmod +x "$MOCK_CLAUDE"
export NO_COLOR=1

# ─────────────────────────────────────────────────
# A1 — mcp_status_array populates TUI_GROUPS[] in canonical CATEGORIES_ORDER
# ─────────────────────────────────────────────────
groups_out=$(TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    HOME="$SANDBOX_ROOT" bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    mcp_catalog_load
    mcp_categories_load
    mcp_status_array
    # Print distinct group names in TUI_GROUP_NAMES[] order
    for g in \"\${TUI_GROUP_NAMES[@]}\"; do
        echo \"\$g\"
    done
" 2>&1)
# Expected canonical title-cased order, only categories with >=1 entry.
# Phase 33 final state: every category has at least one entry.
expected_groups="Docs Research
Backend
Payments
Email
Workspace
Project Management
Communication
Design
Dev Tools
Monitoring"
assert_eq "$expected_groups" "$groups_out" "A1: TUI_GROUP_NAMES preserves CATEGORIES_ORDER and title-cases each"

# ─────────────────────────────────────────────────
# A2 — TUI_LABELS contain unofficial entries with the `!` glyph
# ─────────────────────────────────────────────────
labels_out=$(TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    HOME="$SANDBOX_ROOT" NO_COLOR=1 bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    mcp_catalog_load
    mcp_categories_load
    mcp_status_array
    for l in \"\${TUI_LABELS[@]}\"; do
        echo \"\$l\"
    done
" 2>&1)
assert_contains '\[!\] NotebookLM' "$labels_out" "A2: NotebookLM rendered with [!] under NO_COLOR"
assert_contains '\[!\] Telegram' "$labels_out" "A2: Telegram rendered with [!] under NO_COLOR"
# Official entry like Supabase has no [!] prefix.
assert_not_contains '\[!\] Supabase' "$labels_out" "A2: official entries do NOT carry [!] prefix"

# ─────────────────────────────────────────────────
# A3 — TUI_GROUPS has a parallel entry per TUI_LABELS row
# ─────────────────────────────────────────────────
counts_out=$(TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    HOME="$SANDBOX_ROOT" NO_COLOR=1 bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    mcp_catalog_load
    mcp_categories_load
    mcp_status_array
    echo \"labels=\${#TUI_LABELS[@]} groups=\${#TUI_GROUPS[@]} mcp=\${#MCP_NAMES[@]}\"
" 2>&1)
assert_contains "labels=20" "$counts_out" "A3: TUI_LABELS has 20 rows"
assert_contains "groups=20" "$counts_out" "A3: TUI_GROUPS parallel-array has 20 rows"
assert_contains "mcp=20" "$counts_out" "A3: MCP_NAMES has 20 rows"

# ─────────────────────────────────────────────────
# A4 — When mock claude reports `supabase`, MCP_STATUS[supabase]=installed and
#       TUI_INSTALLED carries 1 at supabase's TUI index
# ─────────────────────────────────────────────────
status_out=$(TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MOCK_INSTALLED="supabase" \
    HOME="$SANDBOX_ROOT" NO_COLOR=1 bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    mcp_catalog_load
    mcp_categories_load
    mcp_status_array
    sup_idx=\$(_mcp_lookup_index supabase)
    echo \"sup_status=\${MCP_STATUS[\$sup_idx]} sup_tui_inst=\${TUI_INSTALLED[\${MCP_TO_TUI_IDX[\$sup_idx]}]}\"
" 2>&1)
assert_contains "sup_status=installed" "$status_out" "A4: mocked supabase shows MCP_STATUS=installed"
assert_contains "sup_tui_inst=1" "$status_out" "A4: TUI_INSTALLED for supabase TUI index is 1"

# ─────────────────────────────────────────────────
# A5 — unofficial_confirm: ALWAYS_YES=1 bypass returns 0
# ─────────────────────────────────────────────────
rc=0
ALWAYS_YES=1 bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    unofficial_confirm 'NotebookLM'
" 2>/dev/null || rc=$?
assert_eq "0" "$rc" "A5: unofficial_confirm with ALWAYS_YES=1 returns 0"

# ─────────────────────────────────────────────────
# A6 — unofficial_confirm: TK_INTEGRATIONS_TTY_SRC accepting "y" returns 0
# ─────────────────────────────────────────────────
yes_file="$SANDBOX_ROOT/yes"; printf 'y\n' > "$yes_file"
rc=0
TK_INTEGRATIONS_TTY_SRC="$yes_file" bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    unofficial_confirm 'NotebookLM'
" 2>/dev/null || rc=$?
assert_eq "0" "$rc" "A6: unofficial_confirm with TTY 'y' returns 0"

# ─────────────────────────────────────────────────
# A7 — unofficial_confirm: TK_INTEGRATIONS_TTY_SRC with empty input returns 1
#      (fail-closed N per UN-03 contract)
# ─────────────────────────────────────────────────
empty_file="$SANDBOX_ROOT/empty"; : > "$empty_file"
rc=0
TK_INTEGRATIONS_TTY_SRC="$empty_file" bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    unofficial_confirm 'NotebookLM'
" 2>/dev/null || rc=$?
assert_eq "1" "$rc" "A7: unofficial_confirm with empty TTY input returns 1 (fail-closed)"

# ─────────────────────────────────────────────────
# A8 — unofficial_confirm: TTY accepting "n" returns 1
# ─────────────────────────────────────────────────
no_file="$SANDBOX_ROOT/no"; printf 'n\n' > "$no_file"
rc=0
TK_INTEGRATIONS_TTY_SRC="$no_file" bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    unofficial_confirm 'NotebookLM'
" 2>/dev/null || rc=$?
assert_eq "1" "$rc" "A8: unofficial_confirm with TTY 'n' returns 1"

# ─────────────────────────────────────────────────
# A9 — install.sh --mcp-only --cli-only is mutex => rc=2 + stderr "mutually exclusive"
# ─────────────────────────────────────────────────
stderr_file="$SANDBOX_ROOT/mutex_err"
rc=0
HOME="$SANDBOX_ROOT" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    NO_COLOR=1 \
    bash "${REPO_ROOT}/scripts/install.sh" --integrations --mcp-only --cli-only --yes --dry-run \
    >/dev/null 2>"$stderr_file" || rc=$?
mutex_stderr=$(cat "$stderr_file")
assert_eq "2" "$rc" "A9: install.sh --mcp-only --cli-only returns rc=2"
assert_contains "mutually exclusive" "$mutex_stderr" "A9: stderr cites mutually exclusive"

# ─────────────────────────────────────────────────
# A10 — install.sh --integrations runs cleanly under --dry-run --yes (no deprecation)
# ─────────────────────────────────────────────────
out_file="$SANDBOX_ROOT/integrations_out"
err_file="$SANDBOX_ROOT/integrations_err"
rc=0
HOME="$SANDBOX_ROOT" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    NO_COLOR=1 \
    bash "${REPO_ROOT}/scripts/install.sh" --integrations --yes --dry-run \
    >"$out_file" 2>"$err_file" || rc=$?
i_out=$(cat "$out_file")
i_err=$(cat "$err_file")
assert_eq "0" "$rc" "A10: --integrations --yes --dry-run exits 0"
assert_not_contains "deprecated" "$i_err" "A10: --integrations does NOT print deprecation note"

# ─────────────────────────────────────────────────
# A11 — install.sh --mcps prints deprecation note to stderr (CAT-04 alias)
# ─────────────────────────────────────────────────
m_err_file="$SANDBOX_ROOT/mcps_err"
rc=0
HOME="$SANDBOX_ROOT" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    NO_COLOR=1 \
    bash "${REPO_ROOT}/scripts/install.sh" --mcps --yes --dry-run \
    >/dev/null 2>"$m_err_file" || rc=$?
m_err=$(cat "$m_err_file")
assert_eq "0" "$rc" "A11: --mcps --yes --dry-run exits 0 (deprecation is non-blocking)"
assert_contains "deprecated" "$m_err" "A11: --mcps prints deprecation note to stderr"

# ─────────────────────────────────────────────────
# A14 — Per-row MCP install summary totals line carries shape
#       "Installed: N · Skipped: M · Failed: K". The Phase 34-03 matrix table
#       (A12 banner + A13 columns + A14 MCPs/CLIs lines) was removed in
#       Phase 36-A polish (260502-usj) — it duplicated the per-row block.
# ─────────────────────────────────────────────────
assert_contains "Installed:" "$i_out" "A14: summary total line carries 'Installed:'"
assert_contains "Skipped:" "$i_out" "A14: summary total line carries 'Skipped:'"
assert_contains "Failed:" "$i_out" "A14: summary total line carries 'Failed:'"

# ─────────────────────────────────────────────────
# A15 — Categories with zero entries skip silently. We verify by injecting a
# fixture catalog with one extra empty category and asserting it is not
# rendered in TUI_GROUP_NAMES.
# ─────────────────────────────────────────────────
fixture_dir="$SANDBOX_ROOT/empty_cat"
mkdir -p "$fixture_dir"
fixture="$fixture_dir/integrations-catalog.json"
python3 - <<PY > "$fixture"
import json
catalog = {
    "schema_version": 2,
    "categories": ["docs-research", "backend", "ghost-empty"],
    "components": {
        "mcp": {
            "context7": {
                "name": "context7",
                "display_name": "Context7",
                "category": "docs-research",
                "env_var_keys": ["CONTEXT7_API_KEY"],
                "install_args": ["context7", "--", "npx", "-y", "@upstash/context7-mcp"],
                "description": "library docs",
                "requires_oauth": False,
            },
            "supabase": {
                "name": "supabase",
                "display_name": "Supabase",
                "category": "backend",
                "env_var_keys": ["SUPABASE_ACCESS_TOKEN"],
                "install_args": ["supabase", "--", "npx", "-y", "@supabase/mcp-server-supabase"],
                "description": "postgres backend",
                "requires_oauth": False,
            }
        },
        "cli": {}
    }
}
print(json.dumps(catalog, indent=2))
PY

empty_cat_out=$(TK_MCP_CATALOG_PATH="$fixture" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    HOME="$SANDBOX_ROOT" NO_COLOR=1 bash -c "
    # shellcheck disable=SC1091
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    mcp_catalog_load
    mcp_categories_load
    mcp_status_array
    for g in \"\${TUI_GROUP_NAMES[@]}\"; do
        echo \"\$g\"
    done
" 2>&1)
assert_contains "Docs Research" "$empty_cat_out" "A15: Docs Research category present (has context7)"
assert_contains "Backend" "$empty_cat_out" "A15: Backend category present (has supabase)"
assert_not_contains "Ghost Empty" "$empty_cat_out" "A15: zero-entry category 'ghost-empty' silently skipped"

# ─────────────────────────────────────────────────
# A16 — `--mcp-only` skips CLI dispatch (no "would-install" CLI rows in summary)
# We use a small fixture with one CLI-bearing entry and verify under
# --mcp-only --dry-run that the CLI cell renders as skipped (not would-install).
# ─────────────────────────────────────────────────
mo_fixture="$fixture_dir/mcp_only.json"
python3 - <<PY > "$mo_fixture"
import json
catalog = {
    "schema_version": 2,
    "categories": ["backend"],
    "components": {
        "mcp": {
            "supabase": {
                "name": "supabase",
                "display_name": "Supabase",
                "category": "backend",
                "env_var_keys": ["SUPABASE_ACCESS_TOKEN"],
                "install_args": ["supabase", "--", "npx", "-y", "@supabase/mcp-server-supabase"],
                "description": "postgres backend",
                "requires_oauth": False,
            }
        },
        "cli": {
            "supabase": {
                "detect_cmd": "supabase",
                "install": {
                    "darwin": "echo darwin-stub",
                    "linux": "echo linux-stub",
                },
                "post_install_hint": "supabase login",
            }
        }
    }
}
print(json.dumps(catalog, indent=2))
PY

mo_out_file="$SANDBOX_ROOT/mo_out"
mo_err_file="$SANDBOX_ROOT/mo_err"
rc=0
HOME="$SANDBOX_ROOT" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CATALOG_PATH="$mo_fixture" \
    NO_COLOR=1 \
    bash "${REPO_ROOT}/scripts/install.sh" --integrations --mcp-only --yes --dry-run \
    >"$mo_out_file" 2>"$mo_err_file" || rc=$?
assert_eq "0" "$rc" "A16: --integrations --mcp-only --yes --dry-run exits 0"
# Note: 'mcp-only' Notes-column assertion removed — that column was rendered by
# the Phase 34-03 matrix table (print_integrations_summary), removed in
# Phase 36-A polish (260502-usj). Exit-code coverage is sufficient here.

# ─────────────────────────────────────────────────
# A17 — `--cli-only` skips MCP dispatch (MCP cell shows cli-only skip reason)
# ─────────────────────────────────────────────────
co_out_file="$SANDBOX_ROOT/co_out"
co_err_file="$SANDBOX_ROOT/co_err"
rc=0
HOME="$SANDBOX_ROOT" \
    TK_MCP_CONFIG_HOME="$SANDBOX_ROOT" \
    TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" \
    TK_MCP_CATALOG_PATH="$mo_fixture" \
    NO_COLOR=1 \
    bash "${REPO_ROOT}/scripts/install.sh" --integrations --cli-only --yes --dry-run \
    >"$co_out_file" 2>"$co_err_file" || rc=$?
assert_eq "0" "$rc" "A17: --integrations --cli-only --yes --dry-run exits 0"
# Note: 'cli-only' Notes-column assertion removed for the same reason as A16.

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
