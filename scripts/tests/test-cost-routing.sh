#!/usr/bin/env bash
# test-cost-routing.sh — v6.1 setup-cost-routing.sh contract (audit F-15).
#
# Verifies block insertion + removal + dry-run safety with a sandbox CLAUDE_DIR:
#   1. --help / unknown-flag handling
#   2. Pre-flight: node + npx required (skip test if absent on this box)
#   3. --uninstall on a CLAUDE.md containing the routing block:
#        - block (and its markers) stripped
#        - foreign content preserved verbatim
#        - .bak.<epoch> backup created with the original content
#   4. --uninstall + --dry-run: no mutation, preview message present
#   5. --dry-run install path: no npx invocation, preview message present
#   6. --uninstall when CLAUDE.md missing: exits 0 with warning, no file created
#
# Usage: bash scripts/tests/test-cost-routing.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/setup-cost-routing.sh"
[ -f "$SCRIPT" ] || { echo "ERROR: setup-cost-routing.sh missing at $SCRIPT"; exit 1; }

PASS=0
FAIL=0
SKIP=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }
report_skip() { echo "SKIP: $1 — $2"; SKIP=$((SKIP+1)); }

# 1a. Unknown flag -> exit 2 + "unknown arg" stderr
out=$(bash "$SCRIPT" --bogus-flag 2>&1 || true)
if echo "$out" | grep -q "unknown arg"; then
    report_pass "unknown flag rejected"
else
    report_fail "unknown flag handling" "expected 'unknown arg', got: ${out:0:120}"
fi

# 1b. --help exits 0 with usage banner
out=$(bash "$SCRIPT" --help 2>&1)
if echo "$out" | grep -q "better-model" && echo "$out" | grep -q "uninstall"; then
    report_pass "--help prints usage banner"
else
    report_fail "--help banner" "missing better-model/uninstall keywords in help output"
fi

# 2. Pre-flight check — every other test needs node + npx (the script aborts early
#    without them). Skip the rest of the suite gracefully if node missing.
if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
    report_skip "remaining cost-routing checks" "node/npx not installed"
    echo ""
    echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
    [ $FAIL -eq 0 ]
    exit $?
fi

# ─────────────────────────────────────────────────
# Sandbox: CLAUDE_DIR -> /tmp/cost-routing-XXXX/.claude
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/cost-routing.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export CLAUDE_DIR="$SANDBOX/.claude"
mkdir -p "$CLAUDE_DIR"
GLOBAL_MD="$CLAUDE_DIR/CLAUDE.md"

# ─────────────────────────────────────────────────
# 3. --uninstall on CLAUDE.md containing routing block
# ─────────────────────────────────────────────────
cat > "$GLOBAL_MD" <<'EOF'
# Global CLAUDE.md

## Foreign section A (must survive)

Foreign content line 1.
Foreign content line 2.

<!-- BETTER-MODEL ROUTING START -->
## Routing block
- /gsd-fast → Haiku 4.5
- /gsd-quick → Sonnet 4.6
- /gsd-plan-phase → Opus 4.7
<!-- BETTER-MODEL ROUTING END -->

## Foreign section B (must survive)

Foreign content line 3.
EOF
ORIGINAL_SHA=$(shasum -a 256 "$GLOBAL_MD" 2>/dev/null | awk '{print $1}' || sha256sum "$GLOBAL_MD" | awk '{print $1}')

out=$(bash "$SCRIPT" --uninstall 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
    report_pass "--uninstall exits 0"
else
    report_fail "--uninstall exit code" "got $rc, output: ${out:0:200}"
fi

# 3a. Markers stripped
if grep -q "BETTER-MODEL ROUTING" "$GLOBAL_MD"; then
    report_fail "routing markers stripped" "BETTER-MODEL ROUTING marker still present"
else
    report_pass "routing markers stripped"
fi
# 3b. Block content stripped
if grep -q "Routing block" "$GLOBAL_MD"; then
    report_fail "routing block stripped" "'Routing block' line still present"
else
    report_pass "routing block stripped"
fi
# 3c. Foreign content survived
if grep -q "Foreign section A" "$GLOBAL_MD" && \
   grep -q "Foreign section B" "$GLOBAL_MD" && \
   grep -q "Foreign content line 1" "$GLOBAL_MD" && \
   grep -q "Foreign content line 3" "$GLOBAL_MD"; then
    report_pass "foreign content preserved across uninstall"
else
    report_fail "foreign content preserved" "one of 'Foreign section A', 'Foreign section B', 'Foreign content line 1/3' is missing"
fi
# 3d. Backup created with original content
backup_files=("$GLOBAL_MD".bak.*)
if [ -f "${backup_files[0]}" ]; then
    BACKUP_SHA=$(shasum -a 256 "${backup_files[0]}" 2>/dev/null | awk '{print $1}' || sha256sum "${backup_files[0]}" | awk '{print $1}')
    if [ "$BACKUP_SHA" = "$ORIGINAL_SHA" ]; then
        report_pass "backup file matches pre-uninstall content (sha256)"
    else
        report_fail "backup content match" "backup sha differs from original"
    fi
else
    report_fail "backup file created" "no .bak.* file found next to CLAUDE.md"
fi

# ─────────────────────────────────────────────────
# 4. --uninstall --dry-run: no mutation
# ─────────────────────────────────────────────────
# Re-seed file
cat > "$GLOBAL_MD" <<'EOF'
foreign
<!-- BETTER-MODEL ROUTING START -->
routing
<!-- BETTER-MODEL ROUTING END -->
foreign
EOF
SHA_BEFORE=$(shasum -a 256 "$GLOBAL_MD" 2>/dev/null | awk '{print $1}' || sha256sum "$GLOBAL_MD" | awk '{print $1}')
out=$(bash "$SCRIPT" --uninstall --dry-run 2>&1)
SHA_AFTER=$(shasum -a 256 "$GLOBAL_MD" 2>/dev/null | awk '{print $1}' || sha256sum "$GLOBAL_MD" | awk '{print $1}')
if [ "$SHA_BEFORE" = "$SHA_AFTER" ]; then
    report_pass "--uninstall --dry-run: zero mutation"
else
    report_fail "--uninstall --dry-run mutation" "CLAUDE.md sha changed during dry-run"
fi
if echo "$out" | grep -qE 'dry-run.*would strip'; then
    report_pass "--uninstall --dry-run prints preview"
else
    report_fail "--uninstall --dry-run preview" "expected 'dry-run.*would strip', got: ${out:0:200}"
fi

# ─────────────────────────────────────────────────
# 5. --dry-run install path: no npx, preview line present
# ─────────────────────────────────────────────────
SHA_BEFORE=$(shasum -a 256 "$GLOBAL_MD" 2>/dev/null | awk '{print $1}' || sha256sum "$GLOBAL_MD" | awk '{print $1}')
out=$(bash "$SCRIPT" --dry-run 2>&1)
SHA_AFTER=$(shasum -a 256 "$GLOBAL_MD" 2>/dev/null | awk '{print $1}' || sha256sum "$GLOBAL_MD" | awk '{print $1}')
if [ "$SHA_BEFORE" = "$SHA_AFTER" ]; then
    report_pass "--dry-run install: zero mutation"
else
    report_fail "--dry-run install mutation" "CLAUDE.md sha changed during dry-run install"
fi
if echo "$out" | grep -q "would run: npx better-model init"; then
    report_pass "--dry-run install prints npx preview line"
else
    report_fail "--dry-run install preview" "expected 'would run: npx better-model init', got: ${out:0:200}"
fi

# ─────────────────────────────────────────────────
# 6. --uninstall when CLAUDE.md missing: exit 0 + warning
# ─────────────────────────────────────────────────
rm -f "$GLOBAL_MD"
out=$(bash "$SCRIPT" --uninstall 2>&1)
rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "nothing to remove"; then
    report_pass "--uninstall on missing CLAUDE.md: exit 0 + warning"
else
    report_fail "--uninstall missing CLAUDE.md" "rc=$rc output=${out:0:200}"
fi
if [ -e "$GLOBAL_MD" ]; then
    report_fail "no file created on missing-CLAUDE.md uninstall" "$GLOBAL_MD reappeared"
else
    report_pass "missing CLAUDE.md not created by --uninstall"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
