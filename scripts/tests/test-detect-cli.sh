#!/bin/bash
# test-detect-cli.sh — DETECT-06 CLI cross-check assertions.
#
# Exercises scripts/detect.sh `detect_superpowers()` step 4 under 6 scenarios:
#   1. CLI enabled + version → SP_VERSION uses CLI version (D-18)
#   2. CLI disabled → HAS_SP=false (CLI overrides FS) (D-16 false branch)
#   3. CLI absent (no binary on PATH) → FS wins (D-15)
#   4. CLI error (non-zero exit) → FS wins (D-17)
#   5. CLI non-JSON output → jq fails → FS wins (D-17)
#   6. CLI empty array (SP missing from list) → FS wins (D-16 empty branch, NOT false)
#
# Usage: bash scripts/tests/test-detect-cli.sh
# Exit: 0 all pass, 1 any fail

set -euo pipefail

DETECT_SH="$(cd "$(dirname "$0")/.." && pwd)/detect.sh"
[ -f "$DETECT_SH" ] || { echo "ERROR: detect.sh not found at $DETECT_SH"; exit 1; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/test-detect-cli.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

setup_mock_claude() {
    # setup_mock_claude <mock_bin_dir> <scenario>
    # scenario: "enabled" | "disabled" | "error" | "nonjson" | "empty" | "absent"
    local bin_dir="$1" scenario="$2"
    mkdir -p "$bin_dir"
    case "$scenario" in
        enabled)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo '[{"id":"superpowers@claude-plugins-official","version":"5.1.0","enabled":true}]'
MOCK
            ;;
        disabled)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo '[{"id":"superpowers@claude-plugins-official","version":"5.0.7","enabled":false}]'
MOCK
            ;;
        error)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
exit 1
MOCK
            ;;
        nonjson)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo "Error: could not connect to daemon"
MOCK
            ;;
        empty)
            cat > "$bin_dir/claude" <<'MOCK'
#!/bin/bash
echo '[]'
MOCK
            ;;
        absent)
            # No file created — command -v claude returns non-zero
            ;;
    esac
    if [[ "$scenario" != "absent" ]]; then chmod +x "$bin_dir/claude"; fi
}

seed_sp_fs() {
    # seed_sp_fs <home> <version>
    local home="$1" ver="$2"
    mkdir -p "$home/.claude/plugins/cache/claude-plugins-official/superpowers/$ver"
    mkdir -p "$home/.claude"
    printf '{"enabledPlugins":{"superpowers@claude-plugins-official":true}}' \
        > "$home/.claude/settings.json"
}

run_cli_case() {
    local label="$1" mock_scenario="$2" fs_version="$3" expect_has_sp="$4" expect_sp_version="$5"
    local case_home="$SCRATCH/case-$PASS-$FAIL"
    rm -rf "$case_home"
    mkdir -p "$case_home"
    local mock_bin="$case_home/.mockbin"
    setup_mock_claude "$mock_bin" "$mock_scenario"
    seed_sp_fs "$case_home" "$fs_version"

    # Source detect.sh in a controlled subshell; emit HAS_SP and SP_VERSION
    local result
    result=$(HOME="$case_home" PATH="$mock_bin:$PATH" bash -c '
        source "$1" 2>/dev/null
        echo "HAS_SP=$HAS_SP SP_VERSION=$SP_VERSION"
    ' -- "$DETECT_SH" 2>/dev/null || echo "HAS_SP=error SP_VERSION=")

    local has_sp sp_version
    has_sp=$(echo "$result"  | sed -n 's/^HAS_SP=\([^ ]*\).*/\1/p')
    sp_version=$(echo "$result" | sed -n 's/.*SP_VERSION=\(.*\)$/\1/p')

    local ok=true
    [ "$has_sp" = "$expect_has_sp" ]         || ok=false
    [ "$sp_version" = "$expect_sp_version" ] || ok=false

    if $ok; then
        echo "  ✓ $label"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $label"
        echo "      result:   HAS_SP=$has_sp SP_VERSION=$sp_version"
        echo "      expected: HAS_SP=$expect_has_sp SP_VERSION=$expect_sp_version"
        FAIL=$((FAIL + 1))
    fi
}

echo "DETECT-06 CLI cross-check scenarios"
echo "---"
run_cli_case "CLI enabled + version → SP_VERSION=5.1.0 (CLI wins, D-18)" \
    "enabled"  "5.0.7" "true"  "5.1.0"
run_cli_case "CLI disabled → HAS_SP=false (CLI overrides FS, D-16)" \
    "disabled" "5.0.7" "false" ""
run_cli_case "CLI absent → FS wins, SP_VERSION=5.0.7 (D-15)" \
    "absent"   "5.0.7" "true"  "5.0.7"
run_cli_case "CLI error → soft-fail, FS wins (D-17)" \
    "error"    "5.0.7" "true"  "5.0.7"
run_cli_case "CLI non-JSON → jq fails → FS wins (D-17)" \
    "nonjson"  "5.0.7" "true"  "5.0.7"
run_cli_case "CLI empty [] → FS wins, NOT treated as false (D-16 empty branch)" \
    "empty"    "5.0.7" "true"  "5.0.7"

echo ""
echo "---"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
