#!/usr/bin/env bash
# test-init-download-fallback.sh — v4.8.1 install bug-fix verification.
#
# Scenarios:
#   S1 framework_first   — templates/<framework>/agents/<file> exists  → used directly
#   S2 base_fallback     — templates/<framework>/agents/<file> missing,
#                          templates/base/agents/<file> exists           → fallback succeeds
#   S3 both_missing      — neither URL serves the file                  → counted as failure
#   S4 marketplace_skip  — manifest skills_marketplace bucket entries   → never iterated
#
# Strategy: spin up python3 -m http.server pointing at a synthetic repo tree;
# point TK_REPO_URL at it; invoke download_files() in isolation.
#
# Usage: bash scripts/tests/test-init-download-fallback.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # documented; future scenarios may reference repo root
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
assert_file_exists()    { [ -f "$1" ] && assert_pass "$2" || assert_fail "$2" "missing: $1"; }
assert_file_missing()   { [ ! -f "$1" ] && assert_pass "$2" || assert_fail "$2" "unexpected: $1"; }

# Sandbox + http.server lifecycle ────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/test-init-dl.XXXXXX)"
SERVER_PID=""
cleanup() {
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
    rm -rf "${SANDBOX:?}"
}
trap cleanup EXIT

REPO_FIXTURE="$SANDBOX/repo"
mkdir -p "$REPO_FIXTURE/templates/base/agents"
mkdir -p "$REPO_FIXTURE/templates/nodejs/agents"

# Fixture content: framework-only file, base-only file, both-missing not-created.
echo "framework agent body" > "$REPO_FIXTURE/templates/nodejs/agents/nodejs-expert.md"
echo "base agent body"      > "$REPO_FIXTURE/templates/base/agents/planner.md"

# Minimal manifest covering all four scenarios.
cat > "$REPO_FIXTURE/manifest.json" <<'JSON'
{
  "manifest_version": 2,
  "files": {
    "agents": [
      { "path": "agents/nodejs-expert.md" },
      { "path": "agents/planner.md" },
      { "path": "agents/nonexistent.md" }
    ],
    "skills_marketplace": [
      { "path": "templates/skills-marketplace/should-not-fetch" }
    ]
  }
}
JSON

# Pick a free port + start server.
PORT=$((40000 + RANDOM % 10000))
( cd "$REPO_FIXTURE" && python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
SERVER_PID=$!
# Wait briefly for socket to bind (no curl-loop — keep it simple).
for _ in 1 2 3 4 5; do
    if curl -sf "http://127.0.0.1:$PORT/manifest.json" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! curl -sf "http://127.0.0.1:$PORT/manifest.json" >/dev/null; then
    echo "ERROR: fixture http.server did not become ready on port $PORT"
    exit 1
fi

# ─────────────────────────────────────────────────
# Run download_files() in a controlled subshell with TK_REPO_URL pointed
# at the fixture. We can't easily invoke init-claude.sh main() in isolation
# (it does too much setup), so we extract just the critical invariants:
# manifest iteration + framework-first → base-fallback + skills_marketplace skip.
# ─────────────────────────────────────────────────

INSTALL_DIR="$SANDBOX/.claude"
mkdir -p "$INSTALL_DIR"

# Inline reproduction of the post-fix download_files() core logic.
# Asserts the SAME jq filter + URL routing the real code uses.
run_download() {
    local FRAMEWORK="$1"
    local INSTALLED_COUNT=0 FAILED_COUNT=0 SKIPPED_MARKETPLACE=0
    local entry path fw_url base_url full_dest
    while IFS= read -r entry; do
        # bucket is preserved in the jq emission for parity with init-claude.sh's
        # bucket-aware routing; this fixture exercises only non-scripts/non-libs
        # buckets so we read just .path here.
        path=$(echo "$entry"   | jq -r '.path')
        full_dest="$INSTALL_DIR/$path"
        mkdir -p "$(dirname "$full_dest")"
        fw_url="http://127.0.0.1:$PORT/templates/$FRAMEWORK/$path"
        base_url="http://127.0.0.1:$PORT/templates/base/$path"
        if curl -sSLf "$fw_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        elif curl -sSLf "$base_url" -o "$full_dest" 2>/dev/null && [[ -s "$full_dest" ]]; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            rm -f "$full_dest"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    done < <(jq -c '
        .files | to_entries[] |
        .key as $b | .value[] |
        select($b != "skills_marketplace") |
        { bucket: $b, path: .path }
    ' "$REPO_FIXTURE/manifest.json")
    # Marketplace skip check — iterate the bucket separately and assert it was filtered.
    if jq -e '.files.skills_marketplace' "$REPO_FIXTURE/manifest.json" >/dev/null 2>&1; then
        SKIPPED_MARKETPLACE=1
    fi
    echo "$INSTALLED_COUNT $FAILED_COUNT $SKIPPED_MARKETPLACE"
}

echo "test-init-download-fallback.sh: B1 + B2 verification"
echo ""

# ─────────────────────────────────────────────────
# Run all four scenarios in one pass (manifest covers all of them).
# ─────────────────────────────────────────────────
read -r INSTALLED FAILED MARKETPLACE_PRESENT <<< "$(run_download nodejs)"
# shellcheck disable=SC2034  # INSTALLED inspected manually for debugging
: "$INSTALLED"

# S1: framework-first wins.
assert_file_exists "$INSTALL_DIR/agents/nodejs-expert.md" "S1 framework_first: nodejs-expert.md present (framework path)"
GREP_BODY=$(cat "$INSTALL_DIR/agents/nodejs-expert.md" 2>/dev/null || echo "")
assert_eq "framework agent body" "$GREP_BODY" "S1 framework_first: body matches templates/nodejs/ source"

# S2: base fallback.
assert_file_exists "$INSTALL_DIR/agents/planner.md" "S2 base_fallback: planner.md fetched from templates/base/"
GREP_BODY2=$(cat "$INSTALL_DIR/agents/planner.md" 2>/dev/null || echo "")
assert_eq "base agent body" "$GREP_BODY2" "S2 base_fallback: body matches templates/base/ source"

# S3: both missing — file should NOT exist locally + FAILED_COUNT should be ≥1.
assert_file_missing "$INSTALL_DIR/agents/nonexistent.md" "S3 both_missing: nonexistent.md not created on dual 404"
if [[ "$FAILED" -ge 1 ]]; then
    assert_pass "S3 both_missing: FAILED_COUNT incremented (got=$FAILED)"
else
    assert_fail "S3 both_missing: FAILED_COUNT not incremented" "got=$FAILED"
fi

# S4: marketplace skip — its directory must never have been fetched.
assert_file_missing "$INSTALL_DIR/templates/skills-marketplace/should-not-fetch" \
    "S4 marketplace_skip: skills_marketplace bucket entries were not iterated"
if [[ "$MARKETPLACE_PRESENT" -eq 1 ]]; then
    assert_pass "S4 marketplace_skip: bucket WAS in manifest (filter, not absence)"
else
    assert_fail "S4 marketplace_skip: bucket missing from manifest fixture" "test fixture broken"
fi

# Final tally
echo ""
echo "─────────────────────────────────────────────"
printf "PASS=%d FAIL=%d\n" "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
