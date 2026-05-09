#!/usr/bin/env bash
# test-install-hooks.sh — v6.1 install-hooks.sh contract (audit F-15).
#
# All tests run against a sandbox CLAUDE_DIR with TK_HOOKS_SOURCE pointing at
# the repo's templates/global/hooks/ — never touches the real ~/.claude/.
#
# Coverage:
#   1. --help exits 0 with banner
#   2. Unknown flag exits 2 with "unknown arg"
#   3. Fresh install:
#        - 4 hook files copied to $CLAUDE_DIR/hooks/, all executable
#        - settings.json contains 4 _tk_hook_id entries
#        - each entry has _tk_owned: true and a matching command path
#   4. Idempotence: re-running install does not duplicate entries
#   5. Foreign-hook preservation: a pre-existing UserPromptSubmit hook with
#      no _tk_owned marker survives install verbatim
#   6. --uninstall: every _tk_hook_id entry stripped, foreign hook intact
#   7. --dry-run on fresh install: no settings.json created, no hook files copied
#
# Usage: bash scripts/tests/test-install-hooks.sh
# Exit:  0 = all pass / skipped, 1 = any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/install-hooks.sh"
HOOKS_SRC="$REPO_ROOT/templates/global/hooks"
[ -f "$SCRIPT" ]    || { echo "ERROR: install-hooks.sh missing"; exit 1; }
[ -d "$HOOKS_SRC" ] || { echo "ERROR: hooks source missing at $HOOKS_SRC"; exit 1; }

PASS=0
FAIL=0
SKIP=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }
report_skip() { echo "SKIP: $1 — $2"; SKIP=$((SKIP+1)); }

# Pre-flight: python3 + jq required by install-hooks.sh itself.
if ! command -v python3 >/dev/null 2>&1; then
    report_skip "all install-hooks tests" "python3 missing"
    echo ""; echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
    report_skip "all install-hooks tests" "jq missing"
    echo ""; echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi

# ─────────────────────────────────────────────────
# 1+2. Help / unknown-flag (no sandbox needed)
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" --help 2>&1)
if echo "$out" | grep -q "install Toolkit advisory hooks"; then
    report_pass "--help prints banner"
else
    report_fail "--help banner" "missing 'install Toolkit advisory hooks' marker in help output"
fi

out=$(bash "$SCRIPT" --bogus 2>&1 || true)
if echo "$out" | grep -q "unknown arg"; then
    report_pass "unknown flag rejected"
else
    report_fail "unknown flag" "expected 'unknown arg', got: ${out:0:120}"
fi

# ─────────────────────────────────────────────────
# Sandbox setup for the rest
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/install-hooks.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export CLAUDE_DIR="$SANDBOX/.claude"
export TK_HOOKS_SOURCE="$HOOKS_SRC"
mkdir -p "$CLAUDE_DIR"

EXPECTED_HOOKS=(
    "tk-pre-gsd-plan-council.sh"
    "tk-pre-gsd-plan-factcheck.sh"
    "tk-post-gsd-phase-audit.sh"
    "tk-cost-warning.sh"
    "tk-pre-ship-reality-check.sh"
)

# ─────────────────────────────────────────────────
# 3. Fresh install
# ─────────────────────────────────────────────────
out=$(bash "$SCRIPT" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
    report_pass "fresh install exits 0"
else
    report_fail "fresh install exit" "rc=$rc, output tail: ${out: -300}"
fi

all_present=1
for hk in "${EXPECTED_HOOKS[@]}"; do
    if [ -x "$CLAUDE_DIR/hooks/$hk" ]; then
        :
    else
        report_fail "hook file installed: $hk" "missing or not executable at $CLAUDE_DIR/hooks/$hk"
        all_present=0
    fi
done
[ $all_present -eq 1 ] && report_pass "all 5 hook files copied + executable"

# Settings.json structure
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
    report_pass "settings.json created"
else
    report_fail "settings.json created" "$SETTINGS missing"
fi

# Count _tk_hook_id entries via jq
hook_id_count=$(jq '[.. | objects | select(has("_tk_hook_id"))] | length' "$SETTINGS" 2>/dev/null || echo 0)
if [ "$hook_id_count" -eq 5 ]; then
    report_pass "settings.json contains exactly 5 _tk_hook_id entries"
else
    report_fail "_tk_hook_id count" "expected 5, got $hook_id_count"
fi

# Each entry has _tk_owned: true and a nested hooks[].command pointing at $CLAUDE_DIR/hooks/<id>.
# Claude Code hook shape: { "_tk_owned": true, "_tk_hook_id": "...", "hooks": [{"type": "command", "command": "..."}] }
all_marked=1
for hk in "${EXPECTED_HOOKS[@]}"; do
    entry=$(jq --arg id "$hk" '[.. | objects | select(.["_tk_hook_id"]==$id)] | .[0] // empty' "$SETTINGS")
    if [ -z "$entry" ]; then
        report_fail "entry for $hk" "no _tk_hook_id matching '$hk' in settings.json"
        all_marked=0
        continue
    fi
    owned=$(echo "$entry" | jq -r '._tk_owned // false')
    cmd=$(echo "$entry" | jq -r '.hooks[0].command // ""')
    if [ "$owned" != "true" ]; then
        report_fail "_tk_owned for $hk" "expected true, got '$owned'"
        all_marked=0
    fi
    if [[ "$cmd" != *"hooks/$hk" ]]; then
        report_fail "command path for $hk" "expected to end with 'hooks/$hk', got '$cmd'"
        all_marked=0
    fi
done
[ $all_marked -eq 1 ] && report_pass "every TK entry carries _tk_owned + correct hooks[].command path"

# ─────────────────────────────────────────────────
# 4. Idempotence — re-run install, count must stay 5
# ─────────────────────────────────────────────────
bash "$SCRIPT" >/dev/null 2>&1
hook_id_count=$(jq '[.. | objects | select(has("_tk_hook_id"))] | length' "$SETTINGS")
if [ "$hook_id_count" -eq 5 ]; then
    report_pass "second install: still exactly 5 _tk_hook_id entries (idempotent)"
else
    report_fail "idempotence" "second install yielded $hook_id_count entries (expected 5)"
fi

# ─────────────────────────────────────────────────
# 5. Foreign-hook preservation: inject an unrelated entry, install, verify intact
# ─────────────────────────────────────────────────
# Inject a foreign UserPromptSubmit hook (no _tk_owned marker)
python3 - "$SETTINGS" <<'PYEOF'
import json, sys
p = sys.argv[1]
with open(p) as f: cfg = json.load(f)
cfg.setdefault("hooks", {}).setdefault("UserPromptSubmit", []).append({
    "command": "/usr/local/bin/foreign-hook.sh",
    "_foreign_marker": "preserve-me"
})
with open(p, "w") as f: json.dump(cfg, f, indent=2)
PYEOF

# Re-run install
bash "$SCRIPT" >/dev/null 2>&1
foreign_kept=$(jq '[.. | objects | select(.["_foreign_marker"]=="preserve-me")] | length' "$SETTINGS")
if [ "$foreign_kept" -eq 1 ]; then
    report_pass "foreign hook preserved across re-install"
else
    report_fail "foreign hook preservation" "expected 1 entry with _foreign_marker, got $foreign_kept"
fi

# ─────────────────────────────────────────────────
# 6. --uninstall: drops all TK entries, foreign survives
# ─────────────────────────────────────────────────
bash "$SCRIPT" --uninstall >/dev/null 2>&1
remaining_tk=$(jq '[.. | objects | select(has("_tk_hook_id"))] | length' "$SETTINGS")
if [ "$remaining_tk" -eq 0 ]; then
    report_pass "--uninstall: zero _tk_hook_id entries remain"
else
    report_fail "--uninstall TK removal" "$remaining_tk _tk_hook_id entries still present"
fi
foreign_after=$(jq '[.. | objects | select(.["_foreign_marker"]=="preserve-me")] | length' "$SETTINGS")
if [ "$foreign_after" -eq 1 ]; then
    report_pass "--uninstall: foreign hook still intact"
else
    report_fail "--uninstall foreign preservation" "expected 1 foreign entry, got $foreign_after"
fi

# ─────────────────────────────────────────────────
# 7. --dry-run on fresh sandbox: no settings.json, no hook files
# ─────────────────────────────────────────────────
SANDBOX2="$(mktemp -d "${TMPDIR:-/tmp}/install-hooks-dry.XXXXXX")"
# shellcheck disable=SC2064
trap "rm -rf '$SANDBOX' '$SANDBOX2'" EXIT
export CLAUDE_DIR="$SANDBOX2/.claude"
mkdir -p "$CLAUDE_DIR"

out=$(bash "$SCRIPT" --dry-run 2>&1)
if echo "$out" | grep -q "dry-run"; then
    report_pass "--dry-run prints preview lines"
else
    report_fail "--dry-run preview" "no '[dry-run]' marker in output"
fi
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    report_fail "--dry-run no settings.json mutation" "settings.json was created"
else
    report_pass "--dry-run did not create settings.json"
fi
if [ -d "$CLAUDE_DIR/hooks" ]; then
    hooks_count=$(find "$CLAUDE_DIR/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
else
    hooks_count=0
fi
if [ "$hooks_count" -eq 0 ]; then
    report_pass "--dry-run did not copy any hook files"
else
    report_fail "--dry-run no file copy" "$hooks_count hook files were copied"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ]
