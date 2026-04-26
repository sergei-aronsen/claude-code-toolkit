#!/usr/bin/env bash
# test-uninstall-state-cleanup.sh — UN-05 + UN-06 end-to-end integration test.
#
# Exercises the full Phase 19 flow in a single hermetic sandbox run:
#   sentinel block strip + user-content preservation + state-file delete +
#   base-plugin invariant (SP + GSD) + double-uninstall idempotency.
#
# Assertions (11 total):
#   A1.  Full uninstall exits 0
#   A2.  Toolkit file deleted (commands/clean.md absent post-run)
#   A3.  toolkit-install.json deleted after successful run
#   A4.  Output contains "State file removed:" log line
#   A5.  Output contains "Uninstall complete. Toolkit removed from" final line
#   A6.  Sentinel block stripped from CLAUDE.md (TOOLKIT-START absent post-run)
#   A7.  User content above and below the block preserved verbatim
#   A8.  Output contains "Stripped toolkit sentinel block" log line
#   A9.  Superpowers plugin file byte-identical pre/post (base-plugin invariant)
#   A10. get-shit-done plugin file byte-identical pre/post (base-plugin invariant)
#   A11. Second invocation on already-uninstalled sandbox is a clean no-op (UN-06)
#
# Usage: bash scripts/tests/test-uninstall-state-cleanup.sh
# Exit:  0 = all 11 assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() {
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "$1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    printf "      %s\n" "$2"
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}

# cross-platform sha256
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# ─────────────────────────────────────────────────
# Sandbox setup
# ─────────────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/uninstall-state.XXXXXX)"
# T-19-03-01: use :? expansion so trap fails fast if SANDBOX is somehow empty
trap 'rm -rf "${SANDBOX:?}"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude/commands" \
         "$SANDBOX/.claude/agents" \
         "$SANDBOX/.claude/get-shit-done" \
         "$SANDBOX/.claude/plugins/cache/claude-plugins-official/superpowers"

# Toolkit fixture — will be classified REMOVE and deleted
printf 'clean\n' > "$SANDBOX/.claude/commands/clean.md"
SHA_CLEAN="$(sha256_any "$SANDBOX/.claude/commands/clean.md")"

# Synthetic SP plugin file — must NOT be touched (base-plugin invariant)
printf 'superpowers content - DO NOT TOUCH\n' \
    > "$SANDBOX/.claude/plugins/cache/claude-plugins-official/superpowers/sp-marker.md"
PRE_SP_SHA="$(sha256_any "$SANDBOX/.claude/plugins/cache/claude-plugins-official/superpowers/sp-marker.md")"

# Synthetic GSD plugin file — must NOT be touched (base-plugin invariant)
printf 'gsd content - DO NOT TOUCH\n' > "$SANDBOX/.claude/get-shit-done/gsd-marker.md"
PRE_GSD_SHA="$(sha256_any "$SANDBOX/.claude/get-shit-done/gsd-marker.md")"

# Sentinel-block CLAUDE.md fixture.
# Leading blank line before <!-- TOOLKIT-START --> and trailing blank line after
# <!-- TOOLKIT-END --> exercise the strip helper's blank-line trimming (D-02).
# Single-quoted EOF prevents variable expansion of literal content.
cat > "$SANDBOX/.claude/CLAUDE.md" <<'EOF'
# My Project CLAUDE.md

User content above the toolkit block.
This line must be preserved verbatim.

<!-- TOOLKIT-START -->
## Toolkit Section
This block must be removed entirely.
Multiple lines.
<!-- TOOLKIT-END -->

User content below the toolkit block.
This trailing line must also be preserved.
EOF

# toolkit-install.json — registers only commands/clean.md (defense-in-depth:
# SP/GSD synthetic files are intentionally NOT in state; the base-plugin invariant
# must fire even when state is silent about those paths — D-11).
cat > "$SANDBOX/.claude/toolkit-install.json" <<EOF
{
  "version": 2,
  "mode": "standalone",
  "synthesized_from_filesystem": false,
  "detected": {
    "superpowers": {"present": false, "version": ""},
    "gsd":         {"present": false, "version": ""}
  },
  "installed_files": [
    {"path": ".claude/commands/clean.md", "sha256": "$SHA_CLEAN", "installed_at": "2026-04-26T00:00:00Z"}
  ],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF

# ─────────────────────────────────────────────────
# Run 1 — full uninstall
# ─────────────────────────────────────────────────
OUTPUT_RUN1=""
RC_RUN1=0
OUTPUT_RUN1=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC_RUN1=$?

# ─────────────────────────────────────────────────
# Run 1 assertions
# ─────────────────────────────────────────────────
echo ""
echo "Run 1 — full uninstall:"

# A1: exits 0
assert_eq "0" "$RC_RUN1" "A1: full uninstall exits 0"

# A2: toolkit file deleted
if [ ! -f "$SANDBOX/.claude/commands/clean.md" ]; then
    assert_pass "A2: toolkit file deleted (commands/clean.md absent)"
else
    assert_fail "A2: toolkit file deleted (commands/clean.md absent)" "file still present post-uninstall"
fi

# A3: toolkit-install.json deleted (state-file delete — D-06 last step)
if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
    assert_pass "A3: toolkit-install.json deleted after successful run"
else
    assert_fail "A3: toolkit-install.json deleted after successful run" "state file still present"
fi

# A4: state-delete log line present
assert_contains 'State file removed:' "$OUTPUT_RUN1" "A4: state delete log line present"

# A5: final success line present
assert_contains 'Uninstall complete. Toolkit removed from' "$OUTPUT_RUN1" \
    "A5: 'Uninstall complete' final line present"

# A6: sentinel block stripped (TOOLKIT-START absent post-run)
if grep -qF '<!-- TOOLKIT-START -->' "$SANDBOX/.claude/CLAUDE.md"; then
    assert_fail "A6: sentinel block stripped from CLAUDE.md" "TOOLKIT-START still present"
else
    assert_pass "A6: sentinel block stripped from CLAUDE.md"
fi

# A7: user content above and below the block preserved verbatim
if grep -qF 'User content above the toolkit block' "$SANDBOX/.claude/CLAUDE.md" \
   && grep -qF 'User content below the toolkit block' "$SANDBOX/.claude/CLAUDE.md"; then
    assert_pass "A7: user content above and below preserved"
else
    assert_fail "A7: user content above and below preserved" "user lines missing post-strip"
fi

# A8: strip log line present
assert_contains 'Stripped toolkit sentinel block' "$OUTPUT_RUN1" "A8: strip log line present"

# A9: superpowers plugin file byte-identical pre/post (base-plugin invariant)
POST_SP_SHA="$(sha256_any "$SANDBOX/.claude/plugins/cache/claude-plugins-official/superpowers/sp-marker.md")"
assert_eq "$PRE_SP_SHA" "$POST_SP_SHA" \
    "A9: superpowers plugin byte-identical pre/post (base-plugin invariant)"

# A10: get-shit-done plugin file byte-identical pre/post (base-plugin invariant)
POST_GSD_SHA="$(sha256_any "$SANDBOX/.claude/get-shit-done/gsd-marker.md")"
assert_eq "$PRE_GSD_SHA" "$POST_GSD_SHA" \
    "A10: get-shit-done plugin byte-identical pre/post (base-plugin invariant)"

# ─────────────────────────────────────────────────
# Run 2 — second invocation on already-uninstalled sandbox (no re-fixturing)
# This reuses the post-Run-1 sandbox state, which is the production scenario:
# "user runs uninstall.sh again on an already-uninstalled project" (UN-06).
# ─────────────────────────────────────────────────
OUTPUT_RUN2=""
RC_RUN2=0
OUTPUT_RUN2=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC_RUN2=$?

# ─────────────────────────────────────────────────
# Run 2 assertions
# ─────────────────────────────────────────────────
echo ""
echo "Run 2 — idempotency (second invocation):"

# A11: second invocation is a clean no-op (exits 0, correct no-op message)
if [ "$RC_RUN2" -eq 0 ] && printf '%s\n' "$OUTPUT_RUN2" | grep -qF 'Toolkit not installed; nothing to do'; then
    assert_pass "A11: second invocation is a no-op (UN-06 idempotency: post-uninstall -> no-op)"
else
    assert_fail "A11: second invocation is a no-op (UN-06 idempotency: post-uninstall -> no-op)" \
        "RC=$RC_RUN2; output excerpt: $(printf '%s\n' "$OUTPUT_RUN2" | head -3)"
fi

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-state-cleanup: all 11 assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall-state-cleanup: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output (Run 1):"
    printf '%s\n' "$OUTPUT_RUN1"
    echo ""
    echo "Full output (Run 2):"
    printf '%s\n' "$OUTPUT_RUN2"
    exit 1
fi
