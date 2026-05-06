#!/bin/bash
# test-init-skip-flags.sh — v6.1 init-claude.sh hooks/cost-routing skip-flag plumbing
# (audit F-3 / F-15). Static source-level assertions:
#   1. setup_hooks + setup_cost_routing function definitions exist
#   2. --skip-hooks / --skip-cost-routing CLI flags are parsed
#   3. TK_SKIP_HOOKS=1 / TK_SKIP_COST_ROUTING=1 env vars override SKIP_*
#   4. setup_hooks/setup_cost_routing are CALLED from the post-install summary
#   5. Functions early-return when SKIP_* is true (run a sourced harness)
# Usage: bash scripts/tests/test-init-skip-flags.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/init-claude.sh"
[ -f "$SCRIPT" ] || { echo "ERROR: init-claude.sh not found at $SCRIPT"; exit 1; }

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# 1. Function definitions
if grep -qE '^setup_hooks\(\) \{' "$SCRIPT"; then
    report_pass "setup_hooks() defined"
else
    report_fail "setup_hooks() definition missing"
fi
if grep -qE '^setup_cost_routing\(\) \{' "$SCRIPT"; then
    report_pass "setup_cost_routing() defined"
else
    report_fail "setup_cost_routing() definition missing"
fi

# 2. CLI flag parsing
if grep -qE -- '--skip-hooks\)' "$SCRIPT"; then
    report_pass "--skip-hooks flag parsed"
else
    report_fail "--skip-hooks flag missing from argparse"
fi
if grep -qE -- '--skip-cost-routing\)' "$SCRIPT"; then
    report_pass "--skip-cost-routing flag parsed"
else
    report_fail "--skip-cost-routing flag missing from argparse"
fi

# 3. Env-var equivalents
if grep -q 'TK_SKIP_HOOKS' "$SCRIPT"; then
    report_pass "TK_SKIP_HOOKS env var honoured"
else
    report_fail "TK_SKIP_HOOKS env var not referenced"
fi
if grep -q 'TK_SKIP_COST_ROUTING' "$SCRIPT"; then
    report_pass "TK_SKIP_COST_ROUTING env var honoured"
else
    report_fail "TK_SKIP_COST_ROUTING env var not referenced"
fi

# 4. Setup functions actually called from main flow
if grep -qE '^[[:space:]]+setup_hooks$' "$SCRIPT"; then
    report_pass "setup_hooks invoked from main flow"
else
    report_fail "setup_hooks defined but never called"
fi
if grep -qE '^[[:space:]]+setup_cost_routing$' "$SCRIPT"; then
    report_pass "setup_cost_routing invoked from main flow"
else
    report_fail "setup_cost_routing defined but never called"
fi

# 5. Early-return harness — extract the two functions and verify they exit 0
#    silently when SKIP_*=true. Avoids running the full installer (which needs
#    network + a real project tree). awk extracts each function definition.
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-init-skip.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

# Extract setup_hooks body via awk (start at "setup_hooks() {" line, count braces).
awk '
    /^setup_hooks\(\) \{/   { capture=1; depth=0 }
    capture {
        print
        for (i=1; i<=length($0); i++) {
            c = substr($0,i,1)
            if (c=="{") depth++
            else if (c=="}") { depth--; if (depth==0) { capture=0; exit } }
        }
    }
' "$SCRIPT" > "$SCRATCH/setup_hooks.sh"
awk '
    /^setup_cost_routing\(\) \{/ { capture=1; depth=0 }
    capture {
        print
        for (i=1; i<=length($0); i++) {
            c = substr($0,i,1)
            if (c=="{") depth++
            else if (c=="}") { depth--; if (depth==0) { capture=0; exit } }
        }
    }
' "$SCRIPT" > "$SCRATCH/setup_cost_routing.sh"

[ -s "$SCRATCH/setup_hooks.sh" ]        || { report_fail "could not extract setup_hooks body"; }
[ -s "$SCRATCH/setup_cost_routing.sh" ] || { report_fail "could not extract setup_cost_routing body"; }

# Build minimal harness with stub colour vars + REPO_URL + TK_USER_AGENT.
cat > "$SCRATCH/harness.sh" <<'EOF'
CYAN=""; GREEN=""; YELLOW=""; RED=""; NC=""
REPO_URL="https://example.invalid/test-stub"
TK_USER_AGENT="test"
EOF

# When SKIP_HOOKS=true: setup_hooks must produce zero stdout/stderr (early return).
output=$(SKIP_HOOKS=true bash -c "
    source '$SCRATCH/harness.sh'
    source '$SCRATCH/setup_hooks.sh'
    setup_hooks
" 2>&1)
if [ -z "$output" ]; then
    report_pass "setup_hooks silent when SKIP_HOOKS=true"
else
    report_fail "setup_hooks emitted output despite SKIP_HOOKS=true: $output"
fi

# When SKIP_COST_ROUTING=true: same.
output=$(SKIP_COST_ROUTING=true bash -c "
    source '$SCRATCH/harness.sh'
    source '$SCRATCH/setup_cost_routing.sh'
    setup_cost_routing
" 2>&1)
if [ -z "$output" ]; then
    report_pass "setup_cost_routing silent when SKIP_COST_ROUTING=true"
else
    report_fail "setup_cost_routing emitted output despite SKIP_COST_ROUTING=true: $output"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
