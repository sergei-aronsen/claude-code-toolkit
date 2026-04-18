#!/bin/bash
# Claude Code Toolkit - test-safe-merge.sh
# Asserts setup-security.sh settings.json merge preserves foreign keys, backs up, and restores on failure.
# Usage: bash scripts/tests/test-safe-merge.sh
# Exit: 0 = all pass, 1 = any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_LIB="$REPO_ROOT/scripts/lib/install.sh"
[ -f "$INSTALL_LIB" ] || { echo "ERROR: lib/install.sh not found at $INSTALL_LIB"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-safe-merge.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0
report_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
report_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# assert_eq LABEL EXPECTED ACTUAL -- passes if equal, fails otherwise.
# Uses if/else to avoid SC2015 (A && B || C) false positives from shellcheck.
assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        report_pass "$label"
    else
        report_fail "$label (expected: $expected, got: $actual)"
    fi
}

# Reset SCRATCH/.claude between scenarios
reset_scratch() {
    rm -rf "$SCRATCH/.claude"
    mkdir -p "$SCRATCH/.claude"
    unset TK_SETTINGS_BACKUP
}

# Source the merge helper from lib/install.sh
# shellcheck source=/dev/null
source "$INSTALL_LIB"

# Seed a settings.json with two foreign Bash hooks (simulating SP + GSD)
seed_foreign_settings() {
    local target="$1"
    python3 - "$target" <<'PYEOF'
import json, sys
settings = {
    "hooks": {
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "/sp/pre-bash.sh"}]},
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "/gsd/gsd-validate.sh"}]}
        ]
    },
    "enabledPlugins": {
        "code-review@claude-plugins-official": True,
        "user-custom@third-party": True
    },
    "user_setting_unrelated": "leave-me-alone"
}
with open(sys.argv[1], 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
PYEOF
}

# ─────────────────────────────────────────────────
# Scenario 8a: foreign keys preserved
# ─────────────────────────────────────────────────
scenario_a_foreign_keys_preserved() {
    reset_scratch
    local settings="$SCRATCH/.claude/settings.json"
    seed_foreign_settings "$settings"
    backup_settings_once "$settings"
    merge_settings_python "$settings" "/tk/pre-bash.sh"
    # Assert: 3 entries in PreToolUse (2 foreign + 1 TK)
    local count
    count=$(jq '.hooks.PreToolUse | length' "$settings")
    assert_eq "8a: PreToolUse count is 3 (2 foreign + 1 TK)" "3" "$count"
    # Assert: foreign command at index 0 unchanged
    local cmd0
    cmd0=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$settings")
    assert_eq "8a: foreign SP hook at index 0 unchanged" "/sp/pre-bash.sh" "$cmd0"
    # Assert: foreign command at index 1 unchanged
    local cmd1
    cmd1=$(jq -r '.hooks.PreToolUse[1].hooks[0].command' "$settings")
    assert_eq "8a: foreign GSD hook at index 1 unchanged" "/gsd/gsd-validate.sh" "$cmd1"
    # Assert: TK entry at index 2 has _tk_owned marker
    local tkmark
    tkmark=$(jq -r '.hooks.PreToolUse[2]._tk_owned // false' "$settings")
    assert_eq "8a: TK entry at index 2 carries _tk_owned: true" "true" "$tkmark"
    # Assert: unrelated user key untouched
    local unrelated
    unrelated=$(jq -r '.user_setting_unrelated' "$settings")
    assert_eq "8a: unrelated user key preserved" "leave-me-alone" "$unrelated"
    # Assert: enabledPlugins user-custom entry preserved
    local userplugin
    userplugin=$(jq -r '.enabledPlugins["user-custom@third-party"]' "$settings")
    assert_eq "8a: foreign enabledPlugins entry preserved" "true" "$userplugin"
}

# ─────────────────────────────────────────────────
# Scenario 8b: backup created before mutation
# ─────────────────────────────────────────────────
scenario_b_backup_created() {
    reset_scratch
    local settings="$SCRATCH/.claude/settings.json"
    seed_foreign_settings "$settings"
    local pre_md5
    pre_md5=$(python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$settings")
    backup_settings_once "$settings"
    merge_settings_python "$settings" "/tk/pre-bash.sh"
    # Backup file exists?
    if [ -n "${TK_SETTINGS_BACKUP:-}" ] && [ -f "$TK_SETTINGS_BACKUP" ]; then
        report_pass "8b: backup file exists at $TK_SETTINGS_BACKUP"
    else
        report_fail "8b: backup file missing (TK_SETTINGS_BACKUP=${TK_SETTINGS_BACKUP:-unset})"
        return
    fi
    # Backup matches pre-merge content?
    local backup_md5
    backup_md5=$(python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$TK_SETTINGS_BACKUP")
    assert_eq "8b: backup content equals pre-merge content" "$pre_md5" "$backup_md5"
    # Backup name matches the .bak.<unix-ts> pattern?
    case "$TK_SETTINGS_BACKUP" in
        "$settings".bak.[0-9]*) report_pass "8b: backup filename matches .bak.<unix-ts>" ;;
        *) report_fail "8b: backup filename pattern wrong (got: $TK_SETTINGS_BACKUP)" ;;
    esac
}

# ─────────────────────────────────────────────────
# Scenario 8c: restore on simulated failure
# ─────────────────────────────────────────────────
scenario_c_restore_on_failure() {
    reset_scratch
    local settings="$SCRATCH/.claude/settings.json"
    seed_foreign_settings "$settings"
    local pre_md5
    pre_md5=$(python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$settings")
    backup_settings_once "$settings"
    # Inject failure via TK_TEST_INJECT_FAILURE env var
    local rc=0
    TK_TEST_INJECT_FAILURE=1 merge_settings_python "$settings" "/tk/pre-bash.sh" || rc=$?
    if [ "$rc" -ne 0 ]; then
        report_pass "8c: merge_settings_python returns non-zero under TK_TEST_INJECT_FAILURE"
    else
        report_fail "8c: merge_settings_python should fail under TK_TEST_INJECT_FAILURE but returned 0"
    fi
    # Caller is expected to restore from backup; do that now and verify content equals pre-merge
    cp "$TK_SETTINGS_BACKUP" "$settings"
    local post_md5
    post_md5=$(python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$settings")
    assert_eq "8c: settings.json restored from backup matches pre-merge content" "$pre_md5" "$post_md5"
}

scenario_a_foreign_keys_preserved
scenario_b_backup_created
scenario_c_restore_on_failure

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
