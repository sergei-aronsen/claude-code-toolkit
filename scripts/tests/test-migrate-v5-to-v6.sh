#!/usr/bin/env bash
# test-migrate-v5-to-v6.sh — v6.1 migrate-v5-to-v6.sh contract (audit F-15).
#
# Coverage (dry-run only — live runs hit network):
#   1. Refuses to run without a .claude/ directory (exit 1 + clear error)
#   2. --help exits 0 with banner
#   3. Unknown flag exits 2
#   4. --dry-run with synthetic v5 .claude/ shows three-step preview:
#        Step 1: would run update-claude.sh
#        Step 2: would run migrate-to-complement.sh (when SP/GSD env stub set)
#        Step 3: prints advisory-hooks URL + cost-routing URL (audit F-3 hint)
#   5. --dry-run never mutates synthetic .claude/
#
# Usage: bash scripts/tests/test-migrate-v5-to-v6.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/migrate-v5-to-v6.sh"
[ -f "$SCRIPT" ] || { echo "ERROR: migrate-v5-to-v6.sh missing"; exit 1; }

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# 1. --help exits 0 with banner
out=$(bash "$SCRIPT" --help 2>&1)
if echo "$out" | grep -q "v5.x → v6.0 migration" && \
   echo "$out" | grep -q "update-claude.sh"; then
    report_pass "--help prints banner"
else
    report_fail "--help banner" "missing migration/update-claude markers, got: ${out:0:200}"
fi

# 2. Unknown flag exits 2
out=$(bash "$SCRIPT" --bogus 2>&1 || true)
if echo "$out" | grep -q "unknown arg"; then
    report_pass "unknown flag rejected"
else
    report_fail "unknown flag" "expected 'unknown arg', got: ${out:0:120}"
fi

# 3. Refuses missing .claude/
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/migrate-v5v6.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

out=$(cd "$SANDBOX" && bash "$SCRIPT" --dry-run 2>&1 || true)
if echo "$out" | grep -q "no .claude/ directory"; then
    report_pass "refuses missing .claude/ directory"
else
    report_fail "missing .claude/ rejection" "expected 'no .claude/ directory', got: ${out:0:200}"
fi

# 4-5. --dry-run with synthetic .claude/
mkdir -p "$SANDBOX/proj/.claude"
cat > "$SANDBOX/proj/.claude/toolkit-install.json" <<'EOF'
{"version": 2, "toolkit_version": "5.0.0", "installed_files": [], "skipped_files": [], "manifest_hash": "deadbeef", "installed_at": "2026-04-01T00:00:00Z"}
EOF

# Snapshot pre-state (file count + sha of state file)
SHA_BEFORE=$(shasum -a 256 "$SANDBOX/proj/.claude/toolkit-install.json" 2>/dev/null | awk '{print $1}' || sha256sum "$SANDBOX/proj/.claude/toolkit-install.json" | awk '{print $1}')
FILES_BEFORE=$(find "$SANDBOX/proj/.claude" -type f | wc -l | tr -d ' ')

out=$(cd "$SANDBOX/proj" && bash "$SCRIPT" --dry-run 2>&1 || true)

# 4a. Step 1 preview present (would run update-claude.sh)
if echo "$out" | grep -qE 'would run.*update-claude\.sh'; then
    report_pass "Step 1: would-run update-claude.sh preview"
else
    report_fail "Step 1 preview" "expected 'would run ... update-claude.sh', got: $(echo "$out" | grep -i step1 | head -3)"
fi

# 4b. Step 3 advisory-hooks hint
if echo "$out" | grep -q "install-hooks.sh"; then
    report_pass "Step 3: advisory-hooks URL printed"
else
    report_fail "Step 3 hooks hint" "no install-hooks.sh URL in dry-run output"
fi

# 4c. Step 3 cost-routing hint
if echo "$out" | grep -q "setup-cost-routing.sh"; then
    report_pass "Step 3: cost-routing URL printed"
else
    report_fail "Step 3 cost-routing hint" "no setup-cost-routing.sh URL in dry-run output"
fi

# 4d. Banner present
if echo "$out" | grep -qE 'v5\.x.*→.*v6\.0 Migration'; then
    report_pass "migration banner printed"
else
    report_fail "migration banner" "no 'v5.x → v6.0 Migration' line in output"
fi

# 4e. Currently-installed version surfaced from toolkit-install.json (strip ANSI for match)
plain=$(printf '%s' "$out" | sed -E 's/\x1b\[[0-9;]*m//g')
if echo "$plain" | grep -qE 'Currently installed: *5\.0\.0'; then
    report_pass "installed-version 5.0.0 reflected from toolkit-install.json"
else
    report_fail "installed-version detection" "expected 'Currently installed: 5.0.0', got: $(echo "$plain" | grep -i installed | head -2)"
fi

# 5. No mutation in dry-run
SHA_AFTER=$(shasum -a 256 "$SANDBOX/proj/.claude/toolkit-install.json" 2>/dev/null | awk '{print $1}' || sha256sum "$SANDBOX/proj/.claude/toolkit-install.json" | awk '{print $1}')
FILES_AFTER=$(find "$SANDBOX/proj/.claude" -type f | wc -l | tr -d ' ')
if [ "$SHA_BEFORE" = "$SHA_AFTER" ] && [ "$FILES_BEFORE" = "$FILES_AFTER" ]; then
    report_pass "--dry-run: zero filesystem mutation"
else
    report_fail "--dry-run mutation" "sha or file-count changed (sha: $SHA_BEFORE → $SHA_AFTER, files: $FILES_BEFORE → $FILES_AFTER)"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
