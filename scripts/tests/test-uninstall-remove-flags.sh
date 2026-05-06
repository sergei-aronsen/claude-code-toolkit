#!/usr/bin/env bash
# test-uninstall-remove-flags.sh — v6.1 opt-in global tear-down flags (audit F-3 / F-15).
#
# Verifies scripts/uninstall.sh:
#   1. --remove-hooks / --remove-cost-routing are accepted (no "unknown flag" exit 1)
#   2. TK_UNINSTALL_REMOVE_HOOKS=1 / TK_UNINSTALL_REMOVE_COST_ROUTING=1 env vars work
#   3. Dry-run + --remove-hooks emits the expected install-hooks.sh --uninstall preview
#   4. Dry-run + --remove-cost-routing emits the expected setup-cost-routing.sh --uninstall preview
#   5. Without the flags, the trailing hint mentioning manual --uninstall URLs is printed
#   6. With BOTH flags, the trailing "preserved" hint block is suppressed
#
# Usage: bash scripts/tests/test-uninstall-remove-flags.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UNINSTALL="$REPO_ROOT/scripts/uninstall.sh"
[ -f "$UNINSTALL" ] || { echo "ERROR: uninstall.sh missing at $UNINSTALL"; exit 1; }

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# ─────────────────────────────────────────────────
# Sandbox: minimal seeded toolkit-install.json so uninstall.sh proceeds past
# the "no state" early-exit. We only care about the trailing tear-down block.
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-removeflags.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude"
cat > "$SANDBOX/.claude/toolkit-install.json" <<'EOF'
{
  "version": 2,
  "mode": "standalone",
  "synthesized_from_filesystem": false,
  "detected": {
    "superpowers": {"present": false, "version": ""},
    "gsd":         {"present": false, "version": ""}
  },
  "installed_files": [],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF

# Helper — run uninstall in dry-run with the given args, capture combined output.
run_uninstall() {
    bash "$UNINSTALL" --dry-run "$@" 2>&1 || true
}

# 1. Unknown-flag rejection check first — confirm we DO reject typos so test 2/3
#    is meaningful (a script that accepts everything trivially passes).
typo_out=$(bash "$UNINSTALL" --remove-hookz 2>&1 || true)
if echo "$typo_out" | grep -q "unknown flag"; then
    report_pass "uninstall.sh rejects unknown flags (smoke check)"
else
    report_fail "uninstall.sh unknown-flag rejection" "expected 'unknown flag' for --remove-hookz, got: ${typo_out:0:200}"
fi

# 2. --remove-hooks accepted (no rejection)
out=$(run_uninstall --remove-hooks)
if echo "$out" | grep -q "unknown flag"; then
    report_fail "--remove-hooks accepted" "uninstall.sh rejected the flag"
else
    report_pass "--remove-hooks accepted"
fi

# 3. --remove-cost-routing accepted
out=$(run_uninstall --remove-cost-routing)
if echo "$out" | grep -q "unknown flag"; then
    report_fail "--remove-cost-routing accepted" "uninstall.sh rejected the flag"
else
    report_pass "--remove-cost-routing accepted"
fi

# 4. Dry-run + --remove-hooks emits install-hooks.sh --uninstall preview
out=$(run_uninstall --remove-hooks)
if echo "$out" | grep -q "would invoke.*install-hooks.sh.*--uninstall"; then
    report_pass "dry-run --remove-hooks emits install-hooks.sh --uninstall preview"
else
    report_fail "dry-run --remove-hooks preview" "expected 'would invoke ... install-hooks.sh ... --uninstall', got: $(echo "$out" | grep -i hook | head -3)"
fi

# 5. Dry-run + --remove-cost-routing emits setup-cost-routing.sh --uninstall preview
out=$(run_uninstall --remove-cost-routing)
if echo "$out" | grep -q "would invoke.*setup-cost-routing.sh.*--uninstall"; then
    report_pass "dry-run --remove-cost-routing emits setup-cost-routing.sh --uninstall preview"
else
    report_fail "dry-run --remove-cost-routing preview" "expected 'would invoke ... setup-cost-routing.sh ... --uninstall', got: $(echo "$out" | grep -i routing | head -3)"
fi

# 6. Env-var equivalents — TK_UNINSTALL_REMOVE_HOOKS=1 same effect as --remove-hooks
out=$(TK_UNINSTALL_REMOVE_HOOKS=1 run_uninstall)
if echo "$out" | grep -q "would invoke.*install-hooks.sh.*--uninstall"; then
    report_pass "TK_UNINSTALL_REMOVE_HOOKS=1 triggers same path as --remove-hooks"
else
    report_fail "TK_UNINSTALL_REMOVE_HOOKS=1" "env var did not trigger hook tear-down"
fi
out=$(TK_UNINSTALL_REMOVE_COST_ROUTING=1 run_uninstall)
if echo "$out" | grep -q "would invoke.*setup-cost-routing.sh.*--uninstall"; then
    report_pass "TK_UNINSTALL_REMOVE_COST_ROUTING=1 triggers same path as --remove-cost-routing"
else
    report_fail "TK_UNINSTALL_REMOVE_COST_ROUTING=1" "env var did not trigger cost-routing tear-down"
fi

# 7. Without flags: trailing "preserved" hint references both manual --uninstall URLs
out=$(run_uninstall)
if echo "$out" | grep -q "Global v6.1 helpers preserved"; then
    report_pass "default uninstall prints preserved-helpers hint"
else
    report_fail "preserved-helpers hint" "expected 'Global v6.1 helpers preserved' line in default uninstall output"
fi
if echo "$out" | grep -q "install-hooks.sh.*--uninstall" && \
   echo "$out" | grep -q "setup-cost-routing.sh.*--uninstall"; then
    report_pass "preserved-helpers hint includes both manual --uninstall URLs"
else
    report_fail "manual URLs in hint" "expected both install-hooks.sh and setup-cost-routing.sh URLs in hint block"
fi

# 8. With BOTH flags: the "preserved" hint block must be suppressed (we removed both,
#    so there's nothing to recommend manually).
out=$(run_uninstall --remove-hooks --remove-cost-routing)
if echo "$out" | grep -q "Global v6.1 helpers preserved"; then
    report_fail "hint suppressed when both flags set" "preserved-helpers hint still printed"
else
    report_pass "hint suppressed when --remove-hooks AND --remove-cost-routing both set"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
