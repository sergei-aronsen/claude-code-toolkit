#!/usr/bin/env bash
# test-open-design-tui.sh — regression test for OD-TUI-01 (v6.26.0).
#
# Validates:
#   1. detect2.sh exposes is_open_design_installed and IS_OD in detect2_cache.
#   2. install.sh seats `open-design` at the TOP of the Optional group
#      (TUI_LABELS index 3, immediately after `toolkit` at index 2).
#   3. TK_DISPATCH_ORDER places `open-design` between `toolkit` and `security`.
#   4. dispatch.sh exposes a `dispatch_open_design` function that honours the
#      standard contract (--dry-run prints would-run line and returns 0;
#      TK_DISPATCH_OVERRIDE_OPEN_DESIGN with TK_TEST=1 forwards to a no-op).
#   5. _local_label_to_dispatch_name maps `open-design` → `open_design`.
#
# Usage: bash scripts/tests/test-open-design-tui.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
    local want="$1" got="$2" label="$3"
    if [[ "$want" == "$got" ]]; then
        printf '  \033[0;32mOK\033[0m %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  \033[0;31mFAIL\033[0m %s\n      expected=%q actual=%q\n' "$label" "$want" "$got"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local needle="$1" hay="$2" label="$3"
    if [[ "$hay" == *"$needle"* ]]; then
        printf '  \033[0;32mOK\033[0m %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  \033[0;31mFAIL\033[0m %s\n      needle=%q\n      hay=%q\n' "$label" "$needle" "$hay"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== OD-TUI-01: open-design row pinned to top of Optional ==="

# ── S1: detect2.sh probe + cache ──────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/test-od-tui.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

# Positive: faked clone dir registers as installed.
mkdir -p "$SANDBOX/od-fake/.git"
PROBE_RC=0
(
    OPEN_DESIGN_DIR="$SANDBOX/od-fake" \
    bash -c "source '$REPO_ROOT/scripts/lib/detect2.sh' && is_open_design_installed"
) || PROBE_RC=$?
assert_eq "0" "$PROBE_RC" "S1.1: is_open_design_installed=0 when \$OPEN_DESIGN_DIR/.git exists"

# Negative: empty dir without .git rejects.
mkdir -p "$SANDBOX/od-no-git"
PROBE_RC=0
(
    OPEN_DESIGN_DIR="$SANDBOX/od-no-git" \
    bash -c "source '$REPO_ROOT/scripts/lib/detect2.sh' && is_open_design_installed"
) || PROBE_RC=$?
assert_eq "1" "$PROBE_RC" "S1.2: is_open_design_installed=1 when dir lacks .git (rejects)"

# detect2_cache sets IS_OD.
CACHE_OUT=$(
    OPEN_DESIGN_DIR="$SANDBOX/od-fake" \
    bash -c "source '$REPO_ROOT/scripts/lib/detect2.sh' && detect2_cache && echo \"IS_OD=\$IS_OD\""
)
assert_contains "IS_OD=1" "$CACHE_OUT" "S1.3: detect2_cache exports IS_OD=1 when clone present"

# ── S2: install.sh TUI ordering ──────────────────────────────────────────
LABELS_LINE=$(grep -E '^TUI_LABELS=\("superpowers"' "$REPO_ROOT/scripts/install.sh" | head -1)
assert_contains '"toolkit" "open-design" "security"' "$LABELS_LINE" \
    "S2.1: TUI_LABELS pins open-design between toolkit and security"

GROUPS_LINE=$(grep -E '^TUI_GROUPS=\("Bootstrap"' "$REPO_ROOT/scripts/install.sh" | head -1)
assert_contains '"Core"    "Optional"    "Optional"' "$GROUPS_LINE" \
    "S2.2: TUI_GROUPS marks open-design as first Optional row"

INSTALLED_LINE=$(grep -E '^TUI_INSTALLED=\("\$IS_SP"' "$REPO_ROOT/scripts/install.sh" | head -1)
assert_contains '"$IS_TK" "$IS_OD" "$IS_SEC"' "$INSTALLED_LINE" \
    "S2.3: TUI_INSTALLED slot for open-design wired to IS_OD"

REQUIRED_LINE=$(grep -E '^TUI_REQUIRED=\("0" "0" "1"' "$REPO_ROOT/scripts/install.sh" | head -1)
assert_eq 'TUI_REQUIRED=("0" "0" "1" "0" "0" "0" "0")' "$REQUIRED_LINE" \
    "S2.4: TUI_REQUIRED keeps open-design optional (0)"

# ── S3: TK_DISPATCH_ORDER ─────────────────────────────────────────────────
ORDER_OUT=$(bash -c "source '$REPO_ROOT/scripts/lib/dispatch.sh' && printf '%s ' \"\${TK_DISPATCH_ORDER[@]}\"")
assert_contains "toolkit open-design security" "$ORDER_OUT" \
    "S3.1: TK_DISPATCH_ORDER pins open-design between toolkit and security"

# ── S4: dispatch_open_design contract ─────────────────────────────────────
DRY_OUT=$(
    bash -c "
        source '$REPO_ROOT/scripts/lib/dispatch.sh'
        TK_REPO_URL='https://example.invalid' dispatch_open_design --dry-run
    " 2>&1
)
assert_contains "open-design (would run:" "$DRY_OUT" \
    "S4.1: dispatch_open_design --dry-run prints would-run preamble"
assert_contains "scripts/setup-open-design.sh" "$DRY_OUT" \
    "S4.2: dispatch_open_design --dry-run names setup-open-design.sh"

# Override path: TK_TEST=1 + TK_DISPATCH_OVERRIDE_OPEN_DESIGN → executes mock.
MOCK="$SANDBOX/mock-od.sh"
cat > "$MOCK" <<'EOF'
#!/usr/bin/env bash
touch "$1/.od-mock-ran"
EOF
chmod +x "$MOCK"

OVERRIDE_RC=0
(
    TK_TEST=1 \
    TK_DISPATCH_OVERRIDE_OPEN_DESIGN="$MOCK" \
    bash -c "
        source '$REPO_ROOT/scripts/lib/dispatch.sh'
        dispatch_open_design '$SANDBOX'
    "
) || OVERRIDE_RC=$?
assert_eq "0" "$OVERRIDE_RC" \
    "S4.3: TK_DISPATCH_OVERRIDE_OPEN_DESIGN under TK_TEST=1 returns 0"
assert_eq "0" "$(test -f "$SANDBOX/.od-mock-ran" && echo 0 || echo 1)" \
    "S4.4: override mock actually executed (sentinel file present)"

# ── S5: _local_label_to_dispatch_name mapping ─────────────────────────────
# The function is defined inline in install.sh — we extract via sed.
MAP_OUT=$(
    bash -c "
        $(sed -n '/^_local_label_to_dispatch_name() {/,/^}/p' "$REPO_ROOT/scripts/install.sh")
        _local_label_to_dispatch_name open-design
    "
)
assert_eq "open_design" "$MAP_OUT" \
    "S5.1: _local_label_to_dispatch_name maps open-design → open_design"

echo ""
echo "test-open-design-tui complete: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
