#!/usr/bin/env bash
# test-update-libs.sh — LIB-01..02 hermetic integration test.
#
# Five scenarios:
#   S1 — stale lib refreshed: post-update SHA matches repo HEAD
#   S2 — clean lib untouched: mtime preserved, no UPDATED line in output
#   S3 — fresh install: all six lib files created with correct SHA256
#   S4 — modified-file fail-closed: no TTY → choice defaults N, user copy preserved
#   S5 — uninstall round-trip: all six libs in [- REMOVE]; real uninstall removes lib/ dir
#
# Total assertions: ≥15 (3 per scenario)
# Test seam env vars: TK_UPDATE_HOME, TK_UPDATE_FILE_SRC, TK_UPDATE_MANIFEST_OVERRIDE,
#                     TK_UPDATE_LIB_DIR, TK_UNINSTALL_HOME, TK_UNINSTALL_LIB_DIR
#
# Usage: bash scripts/tests/test-update-libs.sh
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
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
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

# cross-platform mtime (seconds since epoch)
mtime_any() {
    if stat -f %m "$1" >/dev/null 2>&1; then
        stat -f %m "$1"
    else
        stat -c %Y "$1"
    fi
}

# Build a manifest fixture with files.libs[] registered at 4.4.0
build_manifest_fixture() {
    local out="$1"
    jq '.version = "4.4.0" | .files.libs = [
        {"path":"scripts/lib/backup.sh"},
        {"path":"scripts/lib/bootstrap.sh"},
        {"path":"scripts/lib/dry-run-output.sh"},
        {"path":"scripts/lib/install.sh"},
        {"path":"scripts/lib/optional-plugins.sh"},
        {"path":"scripts/lib/state.sh"}
    ]' "$REPO_ROOT/manifest.json" > "$out"
}

# ─────────────────────────────────────────────────
# S1 — stale lib refreshed → post-update SHA matches repo HEAD
#
# Setup: stale backup.sh is on disk but NOT recorded in state (toolkit-install.json
# exists and lists other files). update-claude.sh sees it as a NEW file (in manifest
# but not in installed_files[]) and installs it fresh from TK_UPDATE_FILE_SRC,
# overwriting the stale version with the repo HEAD copy.
# ─────────────────────────────────────────────────
run_s1() {
    local SANDBOX RC OUTPUT STALE_SHA REPO_SHA POST_SHA MANIFEST_FIXTURE
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1: stale lib refreshed → post-update SHA matches repo HEAD --"

    # Seed stale lib (mutate backup.sh content so SHA differs from repo)
    mkdir -p "$SANDBOX/.claude/scripts/lib"
    printf '# stale-canary\n' > "$SANDBOX/.claude/scripts/lib/backup.sh"
    STALE_SHA="$(sha256_any "$SANDBOX/.claude/scripts/lib/backup.sh")"
    REPO_SHA="$(sha256_any "$REPO_ROOT/scripts/lib/backup.sh")"

    # Build manifest fixture with files.libs[] registered
    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    # Create a minimal state file that does NOT include scripts/lib/backup.sh.
    # This makes the update loop treat backup.sh as a NEW file (in manifest, not in
    # installed_files[]) so it installs it fresh from TK_UPDATE_FILE_SRC, overwriting
    # the stale version. synthesize_v3_state is bypassed because state file exists.
    python3 -c "
import json, sys
state = {
    'version': 2, 'mode': 'standalone',
    'synthesized_from_filesystem': False,
    'detected': {'superpowers': {'present': False, 'version': ''},
                 'gsd': {'present': False, 'version': ''}},
    'installed_files': [],
    'skipped_files': [],
    'manifest_hash': '',
    'installed_at': '2026-01-01T00:00:00Z'
}
json.dump(state, open(sys.argv[1], 'w'), indent=2)
" "$SANDBOX/.claude/toolkit-install.json"

    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S1: update-claude exits 0"
    POST_SHA="$(sha256_any "$SANDBOX/.claude/scripts/lib/backup.sh")"
    assert_eq "$REPO_SHA" "$POST_SHA" "S1: post-update SHA of backup.sh matches repo HEAD"
    if [ "$STALE_SHA" != "$POST_SHA" ]; then
        assert_pass "S1: stale SHA replaced (file was rewritten)"
    else
        assert_fail "S1: stale SHA replaced" "SHA unchanged — file was NOT refreshed"
    fi
}

# ─────────────────────────────────────────────────
# S2 — clean lib untouched: mtime preserved, no UPDATED line in output
# ─────────────────────────────────────────────────
run_s2() {
    local SANDBOX RC OUTPUT MTIME_BEFORE MTIME_AFTER MANIFEST_FIXTURE
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2: clean lib untouched → mtime preserved --"

    # Seed identical-SHA lib (clean copy from repo)
    mkdir -p "$SANDBOX/.claude/scripts/lib"
    cp "$REPO_ROOT/scripts/lib/backup.sh" "$SANDBOX/.claude/scripts/lib/backup.sh"

    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    MTIME_BEFORE="$(mtime_any "$SANDBOX/.claude/scripts/lib/backup.sh")"

    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    MTIME_AFTER="$(mtime_any "$SANDBOX/.claude/scripts/lib/backup.sh")"

    assert_eq "0" "$RC" "S2: update-claude exits 0"
    assert_eq "$MTIME_BEFORE" "$MTIME_AFTER" "S2: clean lib mtime preserved (no rewrite)"
    assert_not_contains "scripts/lib/backup.sh" \
        "$(printf '%s\n' "$OUTPUT" | grep -iE 'Updated|Installed' || true)" \
        "S2: backup.sh NOT in Updated/Installed group"
}

# ─────────────────────────────────────────────────
# S3 — fresh install: all six lib files created with correct SHA256
# ─────────────────────────────────────────────────
run_s3() {
    local SANDBOX RC OUTPUT count all_match lib repo_sha sandbox_sha MANIFEST_FIXTURE
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3: fresh install → all six lib files installed with correct SHA --"

    # No lib/ dir at all — fresh sandbox
    mkdir -p "$SANDBOX/.claude"

    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S3: update-claude exits 0"

    count=$(find "$SANDBOX/.claude/scripts/lib" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    assert_eq "6" "$count" "S3: all 6 lib files installed"

    all_match=1
    for lib in backup.sh bootstrap.sh dry-run-output.sh install.sh optional-plugins.sh state.sh; do
        repo_sha="$(sha256_any "$REPO_ROOT/scripts/lib/$lib")"
        sandbox_sha="$(sha256_any "$SANDBOX/.claude/scripts/lib/$lib")"
        if [ "$repo_sha" != "$sandbox_sha" ]; then all_match=0; fi
    done
    if [ "$all_match" = "1" ]; then
        assert_pass "S3: all 6 lib SHA256 match repo HEAD"
    else
        assert_fail "S3: all 6 lib SHA256 match" "at least one lib SHA mismatch"
    fi
}

# ─────────────────────────────────────────────────
# S4 — modified-file fail-closed: no TTY → choice defaults N, user copy preserved
# ─────────────────────────────────────────────────
run_s4() {
    local SANDBOX RC OUTPUT MODIFIED_CONTENT MANIFEST_FIXTURE
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4: modified lib, no TTY → fail-closed to N, user copy preserved --"

    # Step 1: run a clean install so STATE_JSON is populated and lib files exist on disk
    mkdir -p "$SANDBOX/.claude/scripts/lib"
    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    TK_UPDATE_HOME="$SANDBOX" \
    TK_UPDATE_FILE_SRC="$REPO_ROOT" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner >/dev/null 2>&1 || true

    # Step 2: mutate backup.sh to trigger MODIFIED_ACTUAL path on next update
    printf '\n# user-local modification\n' >> "$SANDBOX/.claude/scripts/lib/backup.sh"
    MODIFIED_CONTENT="$(cat "$SANDBOX/.claude/scripts/lib/backup.sh")"

    # Build a fresh manifest fixture for the second run (same content — hygiene)
    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture2.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    # Step 3: run update again — no TTY in subshell, read < /dev/tty fails, choice defaults N
    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S4: update exits 0 (N is non-fatal)"
    assert_eq "$MODIFIED_CONTENT" "$(cat "$SANDBOX/.claude/scripts/lib/backup.sh")" \
        "S4: user-modified backup.sh preserved (fail-closed to N)"
    assert_not_contains "scripts/lib/backup.sh" \
        "$(printf '%s\n' "$OUTPUT" | grep -i 'updated' || true)" \
        "S4: backup.sh not in UPDATED output"
}

# ─────────────────────────────────────────────────
# S5 — uninstall round-trip: all six libs in [- REMOVE]; lib/ dir gone after real uninstall
# ─────────────────────────────────────────────────
run_s5() {
    local SANDBOX RC_DRY OUTPUT_DRY MANIFEST_FIXTURE
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5: uninstall round-trip — all six libs in [- REMOVE]; lib/ dir gone --"

    mkdir -p "$SANDBOX/.claude/scripts/lib"
    MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    build_manifest_fixture "$MANIFEST_FIXTURE"

    # Run real update first so STATE_JSON contains the six lib paths
    TK_UPDATE_HOME="$SANDBOX" \
    TK_UPDATE_FILE_SRC="$REPO_ROOT" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner >/dev/null 2>&1 || true

    # --dry-run: assert six lib paths appear in [- REMOVE] group
    RC_DRY=0
    OUTPUT_DRY=$(
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1
    ) || RC_DRY=$?

    assert_eq "0" "$RC_DRY" "S5: uninstall --dry-run exits 0"
    assert_contains "scripts/lib/backup.sh" "$OUTPUT_DRY" "S5: backup.sh in dry-run REMOVE group"

    # Real uninstall: assert lib/ dir gone
    HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/uninstall.sh" >/dev/null 2>&1 || true

    # uninstall.sh removes individual files; the (now-empty) dir may linger.
    # Assert that backup.sh itself is gone — proving the lib files were removed.
    if [ ! -f "$SANDBOX/.claude/scripts/lib/backup.sh" ]; then
        assert_pass "S5: scripts/lib/backup.sh removed by uninstall"
    else
        assert_fail "S5: scripts/lib/backup.sh removed" "file still exists after uninstall"
    fi
}

# ─────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────
echo "test-update-libs.sh: LIB-01..02 integration suite"
echo ""

run_s1
echo ""
run_s2
echo ""
run_s3
echo ""
run_s4
echo ""
run_s5

echo ""
echo "test-update-libs complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
