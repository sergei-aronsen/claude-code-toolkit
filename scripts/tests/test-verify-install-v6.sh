#!/usr/bin/env bash
# test-verify-install-v6.sh — verify-install.sh sections 7 + 8 (audit F-15 item 5).
#
# verify-install.sh sections 7 and 8 are the v6.1 additions for advisory hooks
# and cost routing. Both must:
#   - Render their header verbatim ("7. v6.1 Advisory Hooks (optional)" /
#     "8. v6.1 Cost Routing (optional)")
#   - Print "skip" lines when nothing v6.1 is installed (a fresh-install host)
#   - Promote to "pass" lines when matching settings.json markers /
#     CLAUDE.md routing block exist
#
# Test cases (sandboxed HOME + .claude/ + chdir):
#   A. Bare project + no global v6.1 state → both sections SKIP
#   B. Add ~/.claude/settings.json with _tk_hook_id markers + ~/.claude/hooks/<id>
#      executables → § 7 reports each hook PASS
#   C. Add ~/.claude/CLAUDE.md with BETTER-MODEL ROUTING START marker → § 8 PASS
#   D. settings.json has marker but hook file missing → § 7 reports FAIL line
#
# Usage: bash scripts/tests/test-verify-install-v6.sh
# Exit:  0 = all pass, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFY="$REPO_ROOT/scripts/verify-install.sh"
[ -f "$VERIFY" ] || { echo "ERROR: verify-install.sh missing at $VERIFY"; exit 1; }

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# Strip ANSI escapes from verify-install output for stable matching.
strip_ansi() { sed -E 's/\x1b\[[0-9;]*m//g'; }

# Build a sandbox project with the minimum directory layout verify-install.sh
# expects in sections 1-2 so it doesn't bail early. Sections 7/8 fire regardless
# of whether earlier sections pass; we just need the script to reach them.
make_sandbox() {
    local sb
    sb=$(mktemp -d "${TMPDIR:-/tmp}/verify-v6.XXXXXX")
    mkdir -p "$sb/proj/.claude/commands" "$sb/proj/.claude/agents" "$sb/.claude"
    : > "$sb/proj/CLAUDE.md"
    : > "$sb/proj/.claude/commands/dummy.md"
    : > "$sb/proj/.claude/agents/dummy.md"
    echo "$sb"
}

# Run verify-install in a sandbox, return its stripped output via stdout.
# Args: <sandbox dir>
run_verify() {
    local sb="$1"
    ( cd "$sb/proj" && HOME="$sb" bash "$VERIFY" 2>&1 ) | strip_ansi
}

# ─────────────────────────────────────────────────
# A. Bare host — both sections render and emit "skip" lines
# ─────────────────────────────────────────────────
SB=$(make_sandbox)
out=$(run_verify "$SB" || true)
if echo "$out" | grep -qE '^7\. v6\.1 Advisory Hooks \(optional\)$'; then
    report_pass "section 7 header rendered"
else
    report_fail "section 7 header" "no '7. v6.1 Advisory Hooks (optional)' line in output"
fi
if echo "$out" | grep -qE '^8\. v6\.1 Cost Routing \(optional\)$'; then
    report_pass "section 8 header rendered"
else
    report_fail "section 8 header" "no '8. v6.1 Cost Routing (optional)' line in output"
fi
if echo "$out" | grep -qE 'v6\.1 advisory hooks not installed.*install-hooks\.sh'; then
    report_pass "section 7 emits skip line on bare host"
else
    report_fail "section 7 skip" "expected 'v6.1 advisory hooks not installed' skip line, got: $(echo "$out" | grep -i hook | head -3)"
fi
if echo "$out" | grep -qE 'Cost-routing block not configured.*setup-cost-routing\.sh'; then
    report_pass "section 8 emits skip line on bare host"
else
    report_fail "section 8 skip" "expected 'Cost-routing block not configured' skip line"
fi
rm -rf "$SB"

# ─────────────────────────────────────────────────
# B. Settings.json with _tk_hook_id markers + matching executable hook files
# ─────────────────────────────────────────────────
SB=$(make_sandbox)
mkdir -p "$SB/.claude/hooks"
HOOKS=(
    "tk-pre-gsd-plan-council.sh"
    "tk-post-gsd-phase-audit.sh"
    "tk-cost-warning.sh"
    "tk-pre-ship-reality-check.sh"
)
for hk in "${HOOKS[@]}"; do
    printf '#!/bin/bash\nexit 0\n' > "$SB/.claude/hooks/$hk"
    chmod +x "$SB/.claude/hooks/$hk"
done
# Build a minimal settings.json containing each hook id
python3 - "$SB" <<'PYEOF'
import json, sys, os
sb = sys.argv[1]
ids = ["tk-pre-gsd-plan-council.sh","tk-post-gsd-phase-audit.sh","tk-cost-warning.sh","tk-pre-ship-reality-check.sh"]
hooks = {"PreToolUse": []}
for hid in ids:
    hooks["PreToolUse"].append({
        "_tk_owned": True,
        "_tk_hook_id": hid,
        "hooks": [{"type":"command","command": os.path.join(sb,".claude","hooks",hid)}]
    })
with open(os.path.join(sb,".claude","settings.json"), "w") as f:
    json.dump({"hooks": hooks}, f, indent=2)
PYEOF
out=$(run_verify "$SB" || true)
all_passed=1
for hk in "${HOOKS[@]}"; do
    if echo "$out" | grep -qF "$hk registered + executable"; then
        :
    else
        report_fail "section 7 hook $hk" "expected '$hk registered + executable' PASS line"
        all_passed=0
    fi
done
[ $all_passed -eq 1 ] && report_pass "section 7 reports all 4 hooks registered + executable"
rm -rf "$SB"

# ─────────────────────────────────────────────────
# C. Routing block in ~/.claude/CLAUDE.md → § 8 PASS
# ─────────────────────────────────────────────────
SB=$(make_sandbox)
cat > "$SB/.claude/CLAUDE.md" <<'EOF'
# Global

<!-- BETTER-MODEL ROUTING START -->
- /gsd-fast → Haiku 4.5
<!-- BETTER-MODEL ROUTING END -->
EOF
out=$(run_verify "$SB" || true)
if echo "$out" | grep -qE 'Routing block present'; then
    report_pass "section 8 reports routing block present"
else
    report_fail "section 8 routing PASS" "expected 'Routing block present' line, got: $(echo "$out" | grep -i routing | head -3)"
fi
rm -rf "$SB"

# ─────────────────────────────────────────────────
# D. settings.json marker but hook FILE missing → § 7 reports FAIL line
# ─────────────────────────────────────────────────
SB=$(make_sandbox)
python3 - "$SB" <<'PYEOF'
import json, sys, os
sb = sys.argv[1]
hooks = {"PreToolUse": [{
    "_tk_owned": True,
    "_tk_hook_id": "tk-cost-warning.sh",
    "hooks": [{"type":"command","command": os.path.join(sb,".claude","hooks","tk-cost-warning.sh")}]
}]}
with open(os.path.join(sb,".claude","settings.json"), "w") as f:
    json.dump({"hooks": hooks}, f, indent=2)
PYEOF
# no hook file copied — should produce FAIL "registered ... but missing"
out=$(run_verify "$SB" || true)
if echo "$out" | grep -qE 'tk-cost-warning\.sh registered in settings\.json but missing at'; then
    report_pass "section 7 detects registered-but-missing hook file"
else
    report_fail "section 7 missing-file detection" "expected 'registered in settings.json but missing at' for tk-cost-warning.sh"
fi
rm -rf "$SB"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
