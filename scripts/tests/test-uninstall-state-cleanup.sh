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

# ═══════════════════════════════════════════════════════════════════
# Phase 40 (TEST-05) extension — UN-SEC-01..05 hermetic scenarios
# ═══════════════════════════════════════════════════════════════════
#
# Each scenario uses its OWN mktemp'd $SCENARIO_HOME, isolated from the
# file-level $SANDBOX above (which is for A1..A11 and is already torn down
# logically — but the trap at line 81 still owns its rm -rf). Per-scenario
# rm -rf at end keeps /tmp tidy; the file-level trap catches anything that
# escapes.
#
# All scenarios reuse the TK_UNINSTALL_TTY_FROM_STDIN seam (CONTEXT D-13;
# PATTERNS.md "Hermetic sandbox + TK_UNINSTALL_HOME seam"). NO new env-var.
#
# Seed values are clearly placeholder strings ("-redacted" / "placeholder").
# NO real secrets touch this test (T-40-05-02 mitigation).
#
# Mock `claude` CLI: a stub script in $SCENARIO_HOME that emits a known
# `claude mcp list` so the per-MCP loop has work to do. Without it, the
# loop short-circuits at the outer `command -v` guard (uninstall.sh:916)
# and the per-MCP helper never fires.
#
# Catalog path seam: `uninstall.sh` copies `lib/mcp.sh` to a mktemp'd
# `$LIB_MCP_TMP` and sources THAT — so `_mcp_default_catalog_path`
# resolves via `BASH_SOURCE[0]` to `/tmp/integrations-catalog.json`
# (which doesn't exist). Pass `TK_MCP_CATALOG_PATH` explicitly to point
# back at the real catalog under `scripts/lib/`. Without this seam, the
# per-MCP loop appears to fire (`command -v $TK_MCP_CLAUDE_BIN` succeeds)
# but `mcp_catalog_names` returns empty (jq: file not found) — so
# `INSTALLED_MCPS` stays empty and the per-MCP firecrawl prompt is never
# surfaced, regardless of stdin input.
TK_CATALOG_PATH="$REPO_ROOT/scripts/lib/integrations-catalog.json"

# macOS extended attributes (com.apple.provenance) appended to /tmp files
# render `ls -l` output as `-rw-------@ 1 user wheel ...`. The trailing `@`
# is metadata, not a permission bit — strip it before mode-string compare.
# Bash 3.2 / macOS BSD safe: `cut -c1-10` reads exactly the 10 mode chars
# (drops the `@` and any other ACL/xattr indicator).
mode_bits() {
    ls -l "$1" | awk '{print $1}' | cut -c1-10
}

# Helper: build a mock claude CLI inside $1 (a sandbox dir) that reports
# the MCPs named in $2 (space-separated list) as installed via `mcp list`.
# Returns the absolute path of the mock.
build_mock_claude() {
    local sandbox="$1"
    local mcp_names="$2"
    local mock_bin="$sandbox/mock-claude"
    cat > "$mock_bin" <<'MOCK_HEAD'
#!/usr/bin/env bash
# Mock `claude` CLI for hermetic Phase 40 tests.
# Recognizes only `mcp list` (returns installed MCP rows in old whitespace
# format) and `mcp remove --scope user <name>` (returns 0 silently).
# All other invocations are silent no-ops.
MOCK_HEAD
    {
        printf 'if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then\n'
        local n
        for n in $mcp_names; do
            printf '    echo "%s    cmd    placeholder"\n' "$n"
        done
        printf '    exit 0\nfi\n'
        printf 'if [[ "${1:-}" == "mcp" && "${2:-}" == "remove" ]]; then\n'
        printf '    exit 0\nfi\n'
        printf 'exit 0\n'
    } >> "$mock_bin"
    chmod +x "$mock_bin"
    echo "$mock_bin"
}

# Helper: seed a $SCENARIO_HOME with .claude/, mcp-config.env (mode 0600),
# toolkit-install.json (STATE_FILE), and a minimal CLAUDE.md so the
# uninstall flow doesn't choke on missing fixtures. Two MCPs' keys land in
# mcp-config.env: $1's keys (named MCP — to be removed) and a sibling MCP's
# key (CLOUDFLARE_API_TOKEN — preserved across all per-MCP scenarios).
# $1 = scenario sandbox dir
# $2 = primary MCP name to be exercised (e.g., "firecrawl")
# $3 = primary MCP env-var key to seed (e.g., "FIRECRAWL_API_KEY")
seed_scenario() {
    local sb="$1"
    local prim_name="$2"
    local prim_key="$3"
    mkdir -p "$sb/.claude/commands"

    # mcp-config.env with two MCPs' worth of keys.
    # Format matches mcp_secrets_set output (no MCP_<NAME>_ prefix; just KEY=VALUE).
    {
        printf '%s=%s\n' "$prim_key" "${prim_name}-secret-redacted"
        printf 'CLOUDFLARE_API_TOKEN=cf-secret-placeholder\n'
    } > "$sb/.claude/mcp-config.env"
    chmod 0600 "$sb/.claude/mcp-config.env"

    # toolkit-install.json — minimal STATE_FILE so uninstall.sh doesn't bail
    # at the early no-toolkit guard (uninstall.sh:631).
    cat > "$sb/.claude/toolkit-install.json" <<EOF
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
  "installed_at": "2026-05-05T00:00:00Z"
}
EOF

    # Minimal CLAUDE.md with no sentinel block (skip-strip path) — keeps
    # the uninstall flow uneventful around our actual assertions.
    printf '# Sandbox CLAUDE.md\nNo toolkit sentinel block.\n' > "$sb/.claude/CLAUDE.md"
}

# ─────────────────────────────────────────────────
# UN-SEC-01-Y: per-MCP keys cleanup, user answers Y
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-01-Y: single-MCP cleanup, user answers Y ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-01-y.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
MOCK_BIN="$(build_mock_claude "$SCN_HOME" "firecrawl")"

# stdin: y\n (per-MCP firecrawl yes) + \n (full-toolkit no, default N).
# After firecrawl YES: FIRECRAWL_API_KEY dropped, CLOUDFLARE_API_TOKEN kept,
# mcp-config.env still exists (full-toolkit prompt N).
OUTPUT=$(printf 'y\n\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CATALOG_PATH="$TK_CATALOG_PATH" \
    TK_MCP_CLAUDE_BIN="$MOCK_BIN" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || true

if [[ ! -f "$SCN_HOME/.claude/mcp-config.env" ]]; then
    assert_fail "UN-SEC-01-Y: mcp-config.env preserved after firecrawl Y" \
        "file removed; full-toolkit prompt may have been answered Y unexpectedly. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
elif grep -q '^FIRECRAWL_API_KEY=' "$SCN_HOME/.claude/mcp-config.env"; then
    assert_fail "UN-SEC-01-Y: firecrawl key dropped from mcp-config.env" \
        "FIRECRAWL_API_KEY still present after Y answer. File contents: $(cat "$SCN_HOME/.claude/mcp-config.env")"
elif ! grep -q '^CLOUDFLARE_API_TOKEN=cf-secret-placeholder$' "$SCN_HOME/.claude/mcp-config.env"; then
    assert_fail "UN-SEC-01-Y: cloudflare key preserved (other MCPs not affected)" \
        "CLOUDFLARE_API_TOKEN missing or modified. File contents: $(cat "$SCN_HOME/.claude/mcp-config.env")"
elif [[ "$(mode_bits "$SCN_HOME/.claude/mcp-config.env")" != "-rw-------" ]]; then
    assert_fail "UN-SEC-01-Y: mode 0600 preserved after rewrite" \
        "mode is $(mode_bits "$SCN_HOME/.claude/mcp-config.env")"
else
    assert_pass "UN-SEC-01-Y: firecrawl key dropped, cloudflare preserved, mode 0600 intact"
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# UN-SEC-01-N: per-MCP keys cleanup, user answers N (default)
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-01-N: single-MCP cleanup, default N ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-01-n.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
MOCK_BIN="$(build_mock_claude "$SCN_HOME" "firecrawl")"
PRE_HASH="$(sha256_any "$SCN_HOME/.claude/mcp-config.env")"

# stdin: \n (per-MCP firecrawl default N) + \n (full-toolkit default N).
# Both prompts default-N → file byte-identical, mode preserved.
OUTPUT=$(printf '\n\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CATALOG_PATH="$TK_CATALOG_PATH" \
    TK_MCP_CLAUDE_BIN="$MOCK_BIN" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || true

if [[ ! -f "$SCN_HOME/.claude/mcp-config.env" ]]; then
    assert_fail "UN-SEC-01-N: mcp-config.env preserved under default N" \
        "file removed despite default-N answers. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
else
    POST_HASH="$(sha256_any "$SCN_HOME/.claude/mcp-config.env")"
    if [[ "$PRE_HASH" != "$POST_HASH" ]]; then
        assert_fail "UN-SEC-01-N: mcp-config.env byte-identical under default N" \
            "sha256 changed: pre=$PRE_HASH post=$POST_HASH. File: $(cat "$SCN_HOME/.claude/mcp-config.env")"
    elif [[ "$(mode_bits "$SCN_HOME/.claude/mcp-config.env")" != "-rw-------" ]]; then
        assert_fail "UN-SEC-01-N: mode 0600 preserved" \
            "mode is $(mode_bits "$SCN_HOME/.claude/mcp-config.env")"
    else
        assert_pass "UN-SEC-01-N: mcp-config.env byte-identical under default N"
    fi
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# UN-SEC-03-Y: full-toolkit prompt, user answers Y
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-03-Y: full-toolkit prompt, user answers Y ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-03-y.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
MOCK_BIN="$(build_mock_claude "$SCN_HOME" "firecrawl")"

# stdin: \n (per-MCP firecrawl default N) + y\n (full-toolkit YES).
# After full-toolkit YES: mcp-config.env REMOVED. STATE_FILE removed AFTER
# (D-06 ordering: rm of mcp-config.env precedes rm of STATE_FILE).
OUTPUT=$(printf '\ny\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CATALOG_PATH="$TK_CATALOG_PATH" \
    TK_MCP_CLAUDE_BIN="$MOCK_BIN" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || true

if [[ -f "$SCN_HOME/.claude/mcp-config.env" ]]; then
    assert_fail "UN-SEC-03-Y: mcp-config.env removed after full-toolkit Y" \
        "file still present. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -15)"
elif [[ -f "$SCN_HOME/.claude/toolkit-install.json" ]]; then
    assert_fail "UN-SEC-03-Y: STATE_FILE removed after full-toolkit Y" \
        "STATE_FILE still present. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -15)"
else
    # Ordering check: in stdout, the "Removed: <mcp-config.env path>" line must
    # appear BEFORE the "State file removed:" line (D-06 invariant). awk -v
    # passes the path so awk doesn't have to escape special chars in the regex.
    if printf '%s\n' "$OUTPUT" | awk '
        /Removed: .*mcp-config\.env/ { a = NR }
        /State file removed:/        { b = NR }
        END { exit (a > 0 && b > 0 && a < b) ? 0 : 1 }
    '; then
        assert_pass "UN-SEC-03-Y: mcp-config.env removed BEFORE STATE_FILE (D-06 ordering)"
    else
        assert_fail "UN-SEC-03-Y: mcp-config.env removed BEFORE STATE_FILE (D-06 ordering)" \
            "stdout did not show mcp-config.env removed before STATE_FILE. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -15)"
    fi
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# UN-SEC-03-N: full-toolkit prompt, user answers N (default)
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-03-N: full-toolkit prompt, default N ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-03-n.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
MOCK_BIN="$(build_mock_claude "$SCN_HOME" "firecrawl")"
PRE_HASH="$(sha256_any "$SCN_HOME/.claude/mcp-config.env")"

# stdin: \n (per-MCP firecrawl default N) + \n (full-toolkit default N).
# mcp-config.env preserved byte-identically; STATE_FILE removed (toolkit gone).
OUTPUT=$(printf '\n\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CATALOG_PATH="$TK_CATALOG_PATH" \
    TK_MCP_CLAUDE_BIN="$MOCK_BIN" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || true

if [[ ! -f "$SCN_HOME/.claude/mcp-config.env" ]]; then
    assert_fail "UN-SEC-03-N: mcp-config.env preserved under default N" \
        "file removed despite default-N answers. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
elif [[ -f "$SCN_HOME/.claude/toolkit-install.json" ]]; then
    assert_fail "UN-SEC-03-N: STATE_FILE removed (toolkit gone, secrets preserved)" \
        "STATE_FILE still present. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
else
    POST_HASH="$(sha256_any "$SCN_HOME/.claude/mcp-config.env")"
    if [[ "$PRE_HASH" != "$POST_HASH" ]]; then
        assert_fail "UN-SEC-03-N: mcp-config.env byte-identical under default N" \
            "sha256 changed: pre=$PRE_HASH post=$POST_HASH"
    else
        assert_pass "UN-SEC-03-N: mcp-config.env byte-identical, STATE_FILE removed"
    fi
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# UN-SEC-04: project .env files outside ~/.claude/ NEVER touched
# (fingerprint diff under both --dry-run and live runs)
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-04: project .env files outside ~/.claude/ untouched (fingerprint diff) ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-04.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
mkdir -p "$SCN_HOME/projects/alpha" "$SCN_HOME/projects/beta" "$SCN_HOME/projects/gamma"

# Seed several "project" .env files at various depths to prove that a
# breadth-first traversal (find depth 1..N) plus a root-level .env are all
# byte-identical pre/post.
echo "DATABASE_URL=postgres://placeholder" > "$SCN_HOME/projects/alpha/.env"
echo "API_KEY=placeholder-1"               > "$SCN_HOME/projects/beta/.env"
echo "STRIPE_KEY=placeholder-2"            > "$SCN_HOME/projects/gamma/.env"
echo "ROOT_VAR=placeholder"                > "$SCN_HOME/.env"

# Fingerprint helper: list all .env files under $SCN_HOME EXCLUDING those
# inside the .claude/ subtree (mcp-config.env stays out of this set), one
# per line as `<sha256>  <relative-path>`. Stable across runs (sort).
fingerprint() {
    # `-not -path '*/.claude/*'` is BSD-find compatible and excludes ANY
    # path with /.claude/ in it (depth-independent).
    find "$SCN_HOME" -name '.env' -not -path '*/.claude/*' -type f 2>/dev/null \
        | LC_ALL=C sort \
        | while IFS= read -r f; do
            printf '%s  %s\n' "$(sha256_any "$f")" "${f#"$SCN_HOME"/}"
        done
}

PRE_FP="$(fingerprint)"

# Run #1: dry-run. Under --dry-run, uninstall.sh:757 short-circuits before
# the per-MCP loop and full-toolkit prompt fire — so even if the prompts
# WOULD have touched .env (they don't), the path isn't reached. Either way:
# the negative invariant holds. Output captured to /dev/null because the
# fingerprint diff (not stdout) is the contract under test.
#
# Note: TK_MCP_CATALOG_PATH is intentionally NOT exported for the dry-run
# leg — per-MCP loop is short-circuited by --dry-run early-exit anyway, and
# leaving the catalog seam off proves the negative invariant even when the
# per-MCP loop is fully bypassed.
printf '\n\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run >/dev/null 2>&1 || true
POST_FP_DRYRUN="$(fingerprint)"

# Run #2: live. Need to RE-SEED STATE_FILE because dry-run does not remove
# it — but this scenario already runs dry-run BEFORE live, and dry-run
# exits early at uninstall.sh:759 without removing STATE_FILE. Verify by
# inspection, then proceed with live run on the remaining state.
#
# Live run DOES export TK_MCP_CATALOG_PATH so the per-MCP loop actually
# fires (mock claude reports firecrawl as installed). This proves the
# negative invariant under the FULL uninstall path — including the secret-
# cleanup helper and full-toolkit prompt — not just the short-circuit case.
if [[ ! -f "$SCN_HOME/.claude/toolkit-install.json" ]]; then
    # Defensive: if some future change makes dry-run remove STATE_FILE, we
    # need to re-seed before the live run. Today this branch is unreachable.
    seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
fi
MOCK_BIN_04="$(build_mock_claude "$SCN_HOME" "firecrawl")"

printf '\n\n' | \
    HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_MCP_CATALOG_PATH="$TK_CATALOG_PATH" \
    TK_MCP_CLAUDE_BIN="$MOCK_BIN_04" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" >/dev/null 2>&1 || true
POST_FP_LIVE="$(fingerprint)"

if [[ "$PRE_FP" != "$POST_FP_DRYRUN" ]]; then
    assert_fail "UN-SEC-04: project .env fingerprint byte-identical under --dry-run" \
        "$(diff <(printf '%s\n' "$PRE_FP") <(printf '%s\n' "$POST_FP_DRYRUN") || true)"
elif [[ "$PRE_FP" != "$POST_FP_LIVE" ]]; then
    assert_fail "UN-SEC-04: project .env fingerprint byte-identical under live run" \
        "$(diff <(printf '%s\n' "$PRE_FP") <(printf '%s\n' "$POST_FP_LIVE") || true)"
else
    assert_pass "UN-SEC-04: 4 project .env files byte-identical under --dry-run AND live"
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# UN-SEC-05: --keep-state preserves mcp-config.env + STATE_FILE
# (and surfaces no [y/N] prompt in stdout)
# ─────────────────────────────────────────────────
echo ""
echo "── UN-SEC-05: --keep-state preserves all secret-bearing files; no [y/N] in stdout ──"
SCN_HOME="$(mktemp -d /tmp/uninstall-un-sec-05.XXXXXX)"
seed_scenario "$SCN_HOME" "firecrawl" "FIRECRAWL_API_KEY"
PRE_MCP_HASH="$(sha256_any "$SCN_HOME/.claude/mcp-config.env")"
PRE_STATE_HASH="$(sha256_any "$SCN_HOME/.claude/toolkit-install.json")"

# No mock claude needed: KEEP_STATE skips the per-MCP helper and the
# full-toolkit prompt regardless of whether the per-MCP loop fires. No
# stdin needed: no prompts surface.
OUTPUT=$(HOME="$SCN_HOME" \
    TK_UNINSTALL_HOME="$SCN_HOME" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/uninstall.sh" --keep-state 2>&1) || true

if [[ ! -f "$SCN_HOME/.claude/mcp-config.env" ]]; then
    assert_fail "UN-SEC-05: --keep-state preserves mcp-config.env" \
        "file removed under --keep-state. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
elif [[ "$(sha256_any "$SCN_HOME/.claude/mcp-config.env")" != "$PRE_MCP_HASH" ]]; then
    assert_fail "UN-SEC-05: --keep-state leaves mcp-config.env byte-identical" \
        "sha256 changed under --keep-state"
elif [[ ! -f "$SCN_HOME/.claude/toolkit-install.json" ]]; then
    assert_fail "UN-SEC-05: --keep-state preserves STATE_FILE" \
        "STATE_FILE removed under --keep-state. Output excerpt: $(printf '%s\n' "$OUTPUT" | tail -10)"
elif [[ "$(sha256_any "$SCN_HOME/.claude/toolkit-install.json")" != "$PRE_STATE_HASH" ]]; then
    assert_fail "UN-SEC-05: --keep-state leaves STATE_FILE byte-identical" \
        "STATE_FILE sha256 changed under --keep-state"
elif printf '%s\n' "$OUTPUT" | grep -qF '[y/N]'; then
    assert_fail "UN-SEC-05: no [y/N] prompt surfaces under --keep-state" \
        "stdout contained '[y/N]'. Output excerpt: $(printf '%s\n' "$OUTPUT" | grep -F '[y/N]' | head -3)"
else
    assert_pass "UN-SEC-05: --keep-state preserves both files byte-identically; no [y/N] in stdout"
fi
rm -rf "$SCN_HOME"

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall-state-cleanup: all %d assertions passed${NC}\n" "$PASS"
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
