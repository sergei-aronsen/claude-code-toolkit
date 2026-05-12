#!/usr/bin/env bash
# test-council-pack.sh — v6.23 Repomix pack integration test for Supreme Council.
#
# Scenarios:
#   P1_pack_module_loads       — pack.py imports cleanly, exposes expected functions
#   P2_should_use_pack_gating  — gating respects --no-pack and REPOMIX_PACK_DISABLE
#   P3_pack_freshness          — pack_is_fresh returns False after touching a tracked file
#   P4_brain_help_flags        — brain.py --help mentions all 4 new pack flags
#   P5_pack_cache_hash_stable  — pack_cache_hash returns deterministic 16-char hex
#   P6_no_node_fallback        — should_use_pack returns False with empty PATH
#
# Smoke tests only — does NOT call providers, does NOT pack the live repo.
# Live pack generation is exercised manually via `python3 scripts/council/pack.py`.
#
# Usage: bash scripts/tests/test-council-pack.sh
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
    else assert_fail "$label" "pattern not found: $pattern"; fi
}

echo "test-council-pack.sh: v6.23 Repomix pack integration"
echo ""

echo "-- P1_pack_module_loads --"
out=$(cd "$REPO_ROOT" && python3 -c "
import sys
sys.path.insert(0, 'scripts/council')
import pack
required = ['should_use_pack', 'build_pack_block', 'pack_cache_hash', 'pack_is_fresh']
missing = [f for f in required if not hasattr(pack, f)]
print('missing:' + ','.join(missing) if missing else 'all_present')
" 2>&1)
assert_eq "all_present" "$out" "P1: pack.py exposes all public functions"

echo "-- P2_should_use_pack_gating --"
out=$(cd "$REPO_ROOT" && python3 -c "
import sys, types
sys.path.insert(0, 'scripts/council')
import pack
args_default = types.SimpleNamespace(no_pack=False, pack_force=False, pack_fresh=False, pack_remote=None)
args_no_pack = types.SimpleNamespace(no_pack=True, pack_force=False, pack_fresh=False, pack_remote=None)
default = pack.should_use_pack(args_default, env={'PATH': '/usr/bin:/bin'})
disabled_flag = pack.should_use_pack(args_no_pack, env={'PATH': '/usr/bin:/bin'})
disabled_env = pack.should_use_pack(args_default, env={'PATH': '/usr/bin:/bin', 'REPOMIX_PACK_DISABLE': '1'})
print(f'default={default} flag={disabled_flag} env={disabled_env}')
" 2>&1)
assert_contains "flag=False" "$out" "P2: --no-pack disables pack"
assert_contains "env=False" "$out" "P2: REPOMIX_PACK_DISABLE=1 disables pack"

echo "-- P3_pack_freshness --"
# Build a tiny git repo, create a fake pack, touch a tracked file, expect not-fresh
tmp_repo=$(mktemp -d "/tmp/test-pack-XXXXXX")
trap 'rm -rf "$tmp_repo"' EXIT
(
    cd "$tmp_repo"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test"
    echo "hello" > tracked.txt
    git add tracked.txt
    git commit --quiet -m "init"
    mkdir -p .claude/scratchpad
    : > .claude/scratchpad/repomix-pack.xml
    # Ensure the pack mtime is older than the tracked file mtime so the
    # freshness check returns False deterministically across platforms.
    sleep 1
    touch tracked.txt
)
out=$(cd "$REPO_ROOT" && python3 -c "
import sys
sys.path.insert(0, 'scripts/council')
import pack
from pathlib import Path
repo = Path('$tmp_repo')
print(pack.pack_is_fresh(repo / '.claude/scratchpad/repomix-pack.xml', repo))
" 2>&1)
assert_eq "False" "$out" "P3: pack_is_fresh returns False when tracked file is newer"

echo "-- P4_brain_help_flags --"
help_out=$(cd "$REPO_ROOT" && python3 scripts/council/brain.py --help 2>&1)
assert_contains "\-\-no-pack" "$help_out" "P4: --help mentions --no-pack"
assert_contains "\-\-pack-force" "$help_out" "P4: --help mentions --pack-force"
assert_contains "\-\-pack-fresh" "$help_out" "P4: --help mentions --pack-fresh"
assert_contains "\-\-pack-remote" "$help_out" "P4: --help mentions --pack-remote"

echo "-- P5_pack_cache_hash_stable --"
out=$(cd "$REPO_ROOT" && python3 -c "
import sys
sys.path.insert(0, 'scripts/council')
import pack
h1 = pack.pack_cache_hash('hello world')
h2 = pack.pack_cache_hash('hello world')
h_other = pack.pack_cache_hash('different')
print(f'len={len(h1)} stable={h1==h2} differs={h1!=h_other}')
" 2>&1)
assert_contains "len=16" "$out" "P5: pack_cache_hash returns 16-char digest"
assert_contains "stable=True" "$out" "P5: pack_cache_hash is deterministic for same input"
assert_contains "differs=True" "$out" "P5: pack_cache_hash differs for different input"

echo "-- P6_no_node_fallback --"
out=$(cd "$REPO_ROOT" && python3 -c "
import sys, types
sys.path.insert(0, 'scripts/council')
import pack
args = types.SimpleNamespace(no_pack=False, pack_force=False, pack_fresh=False, pack_remote=None)
print(pack.should_use_pack(args, env={'PATH': '/nonexistent'}))
" 2>&1)
assert_eq "False" "$out" "P6: should_use_pack returns False when node/npx absent"

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
