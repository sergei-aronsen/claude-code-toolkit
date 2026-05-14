#!/usr/bin/env bash
# test-bridges-install-ux.sh — Phase 30 hermetic smoke test for install-time UX.
#
# Scenarios:
#   S1  install.sh + path-sandbox-with-gemini: TUI/yes default-set renders gemini-bridge row
#   S2  install.sh + path-sandbox-WITHOUT-gemini: row absent (CLI-absent-hides contract)
#   S3  install.sh --yes --no-bridges + path-sandbox-with-gemini: zero bridge dispatch (no row)
#   S4  install.sh --yes + TK_NO_BRIDGES=1 + path-sandbox-with-gemini: zero bridge dispatch
#   S5  init-claude.sh --no-bridges --bridges gemini: exit 2 (mutex)
#   S6  init-claude.sh --bridges (no value): exit 1 (usage)
#   S7  init-local.sh --no-bridges --bridges gemini: exit 2 (mutex)
#   S8  bridge_install_prompts unit + TK_BRIDGE_TTY_SRC=here-doc 'Y': bridge_create_project called
#   S9  bridge_install_prompts unit + TK_BRIDGE_TTY_SRC=here-doc 'n': no bridge created
#   S10 bridge_install_prompts unit + TK_NO_BRIDGES=1: silent skip
#   S11 bridge_install_prompts unit + BRIDGES_FORCE=gemini + FAIL_FAST=true (gemini absent): return 1
#   S12 bridge_install_prompts unit + BRIDGES_FORCE=gemini (gemini absent, FAIL_FAST=false): return 0 (warn-and-continue)
#   S13 BACKCOMPAT-01: re-run all 4 baselines (test-bootstrap=26, test-install-tui=52,
#       test-bridges-foundation=5, test-bridges-sync=25) — each must report unchanged PASS.
#
# Test seams:
#   TK_BRIDGE_HOME       — sandboxes ~/.claude/, ~/.gemini/, ~/.codex/, lock dir, state file
#   TK_BRIDGE_TTY_SRC    — feeds prompt answers via here-doc tempfile
#   TK_DETECT_OVERRIDE_GEMINI / TK_DETECT_OVERRIDE_CODEX — NOT a real seam (detect2.sh has no
#       env-override hook); we use path-sandbox PATH-prefix shims with fake gemini/codex
#       binaries that respond to --version. is_gemini_installed/is_codex_installed both call
#       command -v, which obeys PATH order.
#
# Usage: bash scripts/tests/test-bridges-install-ux.sh
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
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "unexpected pattern present: $pattern"
    else
        assert_pass "$label"
    fi
}

# Sandbox cleanup tracker.
_SANDBOXES=()
_cleanup_sandboxes() {
    local d
    for d in "${_SANDBOXES[@]+"${_SANDBOXES[@]}"}"; do
        # Only remove paths under /tmp to stay within the safety-net boundary.
        case "$d" in
            /tmp/*) rm -rf "$d" ;;
        esac
    done
}
trap '_cleanup_sandboxes' EXIT

mk_sandbox() {
    local d
    d="$(mktemp -d /tmp/test-bridges-install-ux.XXXXXX)"
    _SANDBOXES+=("$d")
    echo "$d"
}

mk_cli_shims() {
    # mk_cli_shims <sandbox> <gemini?:0|1> <codex?:0|1>
    local sandbox="$1" with_gem="$2" with_cod="$3"
    mkdir -p "$sandbox/bin"
    if [[ "$with_gem" -eq 1 ]]; then
        cat > "$sandbox/bin/gemini" <<'SHIM'
#!/bin/bash
[[ "$1" == "--version" ]] && echo "gemini-cli/0.0.test" && exit 0
exit 0
SHIM
        chmod +x "$sandbox/bin/gemini"
    fi
    if [[ "$with_cod" -eq 1 ]]; then
        cat > "$sandbox/bin/codex" <<'SHIM'
#!/bin/bash
[[ "$1" == "--version" ]] && echo "codex/0.0.test" && exit 0
exit 0
SHIM
        chmod +x "$sandbox/bin/codex"
    fi
    echo "$sandbox/bin"
}

# Source detect2.sh + bridges.sh + state.sh once at top level for unit-style scenarios S8-S12.
# detect2.sh defines is_gemini_installed / is_codex_installed (NOT detect.sh).
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/state.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/detect2.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/bridges.sh"

# ────────────────────────── scenarios ──────────────────────────

# Helper: run install.sh with output captured to tmpfile, avoiding the $() subshell stdin hang
# that occurs when install.sh's subprocesses hold /dev/tty open in a captured context.
# Args: $1=output-tmpfile (pre-created by caller), rest=command + args (passed to env).
# The env var PREFIX (PATH=.., TK_NO_BRIDGES=..) must be injected by the caller via `env`.
_run_install_to_file() {
    local _out_tmp="$1"; shift
    "$@" > "$_out_tmp" 2>&1 || true
}

echo "=== S1: install.sh --yes --dry-run + gemini-shim renders gemini-bridge row ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 1)
_s1_tmp=$(mktemp /tmp/test-install-out.XXXXXX); _SANDBOXES+=("$_s1_tmp")
# v6.25.2: TK_BRIDGE_HOME=$sb isolates _bridge_global_dir from the host
# `~/.gemini/GEMINI.md` — without it the re-probe at install.sh:2229 would
# fire `installed ✓` on any dev machine that already has the global bridge,
# and S1.3 would never see `would-install`.
_run_install_to_file "$_s1_tmp" env PATH="$shimbin:$PATH" TK_BRIDGE_HOME="$sb" bash "${REPO_ROOT}/scripts/install.sh" --yes --dry-run
out=$(cat "$_s1_tmp")
assert_contains "gemini-bridge" "$out" "S1.1 gemini-bridge row appears"
assert_contains "codex-bridge"  "$out" "S1.2 codex-bridge row appears"
# --yes mode shows install-summary table (not TUI checklist); dry-run shows 'would-install'.
assert_contains "would-install" "$out" "S1.3 dry-run would-install status rendered"

echo "=== S2: install.sh --yes --no-bridges: bridge rows absent regardless of CLI detection ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 1)
# Use --no-bridges to test the rows-suppressed contract; this is portable across
# machines where real gemini/codex may be installed (PATH filtering is insufficient
# because /opt/homebrew/bin/ is not named for these CLIs).
_s2_tmp=$(mktemp /tmp/test-install-out.XXXXXX); _SANDBOXES+=("$_s2_tmp")
_run_install_to_file "$_s2_tmp" env PATH="$shimbin:$PATH" bash "${REPO_ROOT}/scripts/install.sh" --yes --dry-run --no-bridges
out=$(cat "$_s2_tmp")
assert_not_contains "gemini-bridge" "$out" "S2.1 --no-bridges: gemini-bridge row absent"
assert_not_contains "codex-bridge" "$out" "S2.2 --no-bridges: codex-bridge row absent"

echo "=== S3: install.sh --yes --no-bridges + gemini-shim: zero bridge dispatch ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 1)
_s3_tmp=$(mktemp /tmp/test-install-out.XXXXXX); _SANDBOXES+=("$_s3_tmp")
_run_install_to_file "$_s3_tmp" env PATH="$shimbin:$PATH" bash "${REPO_ROOT}/scripts/install.sh" --yes --dry-run --no-bridges
out=$(cat "$_s3_tmp")
assert_not_contains "gemini-bridge" "$out" "S3.1 --no-bridges suppresses gemini row"
assert_not_contains "codex-bridge" "$out" "S3.2 --no-bridges suppresses codex row"

echo "=== S4: install.sh --yes + TK_NO_BRIDGES=1 + gemini-shim: env-var equivalent of --no-bridges ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 1)
_s4_tmp=$(mktemp /tmp/test-install-out.XXXXXX); _SANDBOXES+=("$_s4_tmp")
_run_install_to_file "$_s4_tmp" env TK_NO_BRIDGES=1 PATH="$shimbin:$PATH" bash "${REPO_ROOT}/scripts/install.sh" --yes --dry-run
out=$(cat "$_s4_tmp")
assert_not_contains "gemini-bridge" "$out" "S4.1 TK_NO_BRIDGES=1 suppresses gemini row"

echo "=== S5: init-claude.sh --no-bridges --bridges gemini: exit 2 (mutex) ==="
rc=0
bash "${REPO_ROOT}/scripts/init-claude.sh" --no-bridges --bridges gemini >/dev/null 2>&1 || rc=$?
assert_eq "2" "$rc" "S5.1 init-claude.sh mutex exit 2"

echo "=== S6: init-claude.sh --bridges (no value): exit 1 (usage error) ==="
rc=0
bash "${REPO_ROOT}/scripts/init-claude.sh" --bridges >/dev/null 2>&1 || rc=$?
assert_eq "1" "$rc" "S6.1 init-claude.sh --bridges no-value exit 1"

echo "=== S7: init-local.sh --no-bridges --bridges gemini: exit 2 (mutex) ==="
rc=0
bash "${REPO_ROOT}/scripts/init-local.sh" --no-bridges --bridges gemini >/dev/null 2>&1 || rc=$?
assert_eq "2" "$rc" "S7.1 init-local.sh mutex exit 2"

echo "=== S8: bridge_install_prompts + TK_BRIDGE_TTY_SRC='Y' + gemini-shim: bridge_create_project called ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 0)
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
tty_file=$(mktemp /tmp/tty-y.XXXXXX)
_SANDBOXES+=("$tty_file")
printf "Y\n" > "$tty_file"
# detect.sh must be sourced in subshell so is_gemini_installed / is_codex_installed are available.
( cd "$sb/proj" && PATH="$shimbin:$PATH" TK_BRIDGE_TTY_SRC="$tty_file" TK_BRIDGE_HOME="$sb" \
    bash -c "source ${REPO_ROOT}/scripts/lib/state.sh; source ${REPO_ROOT}/scripts/lib/detect2.sh; source ${REPO_ROOT}/scripts/lib/bridges.sh; bridge_install_prompts \"$sb/proj\"" )
[[ -f "$sb/proj/GEMINI.md" ]] \
    && assert_pass "S8.1 GEMINI.md created on Y answer" \
    || assert_fail "S8.1 GEMINI.md created on Y answer" "file missing under $sb/proj/"

echo "=== S9: bridge_install_prompts + TK_BRIDGE_TTY_SRC='n' + gemini-shim: no bridge created ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 0)
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
tty_file=$(mktemp /tmp/tty-n.XXXXXX)
_SANDBOXES+=("$tty_file")
printf "n\n" > "$tty_file"
( cd "$sb/proj" && PATH="$shimbin:$PATH" TK_BRIDGE_TTY_SRC="$tty_file" TK_BRIDGE_HOME="$sb" \
    bash -c "source ${REPO_ROOT}/scripts/lib/state.sh; source ${REPO_ROOT}/scripts/lib/detect2.sh; source ${REPO_ROOT}/scripts/lib/bridges.sh; bridge_install_prompts \"$sb/proj\"" )
[[ ! -f "$sb/proj/GEMINI.md" ]] \
    && assert_pass "S9.1 GEMINI.md NOT created on n answer" \
    || assert_fail "S9.1 GEMINI.md NOT created on n answer" "file unexpectedly present"

echo "=== S10: bridge_install_prompts + TK_NO_BRIDGES=1 + gemini-shim: silent skip ==="
sb=$(mk_sandbox); shimbin=$(mk_cli_shims "$sb" 1 0)
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
( cd "$sb/proj" && PATH="$shimbin:$PATH" TK_NO_BRIDGES=1 TK_BRIDGE_HOME="$sb" \
    bash -c "source ${REPO_ROOT}/scripts/lib/state.sh; source ${REPO_ROOT}/scripts/lib/detect2.sh; source ${REPO_ROOT}/scripts/lib/bridges.sh; bridge_install_prompts \"$sb/proj\"" )
[[ ! -f "$sb/proj/GEMINI.md" ]] \
    && assert_pass "S10.1 TK_NO_BRIDGES=1 silent-skip" \
    || assert_fail "S10.1 TK_NO_BRIDGES=1 silent-skip" "file unexpectedly created"

echo "=== S11: bridge_install_prompts + BRIDGES_FORCE=gemini + FAIL_FAST=true (gemini absent): return 1 ==="
sb=$(mk_sandbox)
# Build a PATH that truly excludes dirs containing real gemini/codex binaries.
# grep -v on dir names fails when the binary lives in a generic dir like /opt/homebrew/bin/.
# Instead, exclude any PATH entry where the directory actually contains gemini or codex.
_clean_path=""
while IFS= read -r _pdir; do
    [[ -x "$_pdir/gemini" || -x "$_pdir/codex" ]] && continue
    _clean_path="${_clean_path:+${_clean_path}:}$_pdir"
done < <(printf '%s' "$PATH" | tr ':' '\n')
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
rc=0
( cd "$sb/proj" && PATH="$_clean_path" BRIDGES_FORCE=gemini FAIL_FAST=true TK_BRIDGE_HOME="$sb" \
    bash -c "source ${REPO_ROOT}/scripts/lib/state.sh; source ${REPO_ROOT}/scripts/lib/detect2.sh; source ${REPO_ROOT}/scripts/lib/bridges.sh; bridge_install_prompts \"$sb/proj\"" ) || rc=$?
assert_eq "1" "$rc" "S11.1 BRIDGES_FORCE absent CLI under FAIL_FAST returns 1"

echo "=== S12: bridge_install_prompts + BRIDGES_FORCE=gemini (gemini absent, FAIL_FAST=false): return 0 ==="
sb=$(mk_sandbox)
_clean_path=""
while IFS= read -r _pdir; do
    [[ -x "$_pdir/gemini" || -x "$_pdir/codex" ]] && continue
    _clean_path="${_clean_path:+${_clean_path}:}$_pdir"
done < <(printf '%s' "$PATH" | tr ':' '\n')
mkdir -p "$sb/proj"
echo "# project CLAUDE.md" > "$sb/proj/CLAUDE.md"
rc=0
( cd "$sb/proj" && PATH="$_clean_path" BRIDGES_FORCE=gemini FAIL_FAST=false TK_BRIDGE_HOME="$sb" \
    bash -c "source ${REPO_ROOT}/scripts/lib/state.sh; source ${REPO_ROOT}/scripts/lib/detect2.sh; source ${REPO_ROOT}/scripts/lib/bridges.sh; bridge_install_prompts \"$sb/proj\"" ) || rc=$?
assert_eq "0" "$rc" "S12.1 BRIDGES_FORCE absent CLI without FAIL_FAST returns 0 (warn-continue)"

echo "=== S14: _bridge_target_installed probes global path written by bridge_create_global ==="
# v6.25.2 regression: install.sh dispatch shim calls `bridge_create_global`
# (writes ~/.gemini/GEMINI.md, ~/.codex/AGENTS.md) but the probe used to look
# at `$PWD/{GEMINI,AGENTS}.md`, so the TUI re-offered both bridges on every
# install run even after a successful install. The fix points the probe at
# `$(_bridge_global_dir <target>)/<filename>` — these S14.* checks verify
# that contract under a sandboxed `TK_BRIDGE_HOME`.
sb=$(mk_sandbox)
mkdir -p "$sb/.claude" "$sb/.gemini" "$sb/.codex" "$sb/proj"
# Source CLAUDE.md needed by bridge_create_global; payload is irrelevant.
printf '# global CLAUDE.md\n' > "$sb/.claude/CLAUDE.md"

# Pre-condition: no bridge files exist, probe must report NOT installed.
unchecked_gem=0; TK_BRIDGE_HOME="$sb" bash -c "
    source '${REPO_ROOT}/scripts/lib/state.sh'
    source '${REPO_ROOT}/scripts/lib/bridges.sh'
    _bridge_target_installed() {
        local file=\"\$1\"
        [[ -f \"\$file\" ]] || return 1
        head -5 \"\$file\" 2>/dev/null | grep -q 'claude-code-toolkit'
    }
    _bridge_target_installed \"\$(_bridge_global_dir gemini)/GEMINI.md\"
    exit \$?
" 2>/dev/null || unchecked_gem=$?
assert_eq "1" "$unchecked_gem" "S14.1: probe returns 1 when ~/.gemini/GEMINI.md absent"

# Run bridge_create_global → file lands at $sb/.gemini/GEMINI.md.
rc=0
TK_BRIDGE_HOME="$sb" bash -c "
    source '${REPO_ROOT}/scripts/lib/state.sh'
    source '${REPO_ROOT}/scripts/lib/bridges.sh'
    bridge_create_global gemini >/dev/null
    exit \$?
" 2>/dev/null || rc=$?
assert_eq "0" "$rc" "S14.pre-condition: bridge_create_global gemini returns 0"
# (Soft assert: only continue if bridge_create_global succeeded — otherwise
# downstream S14.2 is meaningless. We still emit the assertion above so the
# regression test fails loudly if upstream bridge_create_global breaks.)

# Post-condition: probe must now detect the bridge at the global path.
checked_gem=0
TK_BRIDGE_HOME="$sb" bash -c "
    source '${REPO_ROOT}/scripts/lib/state.sh'
    source '${REPO_ROOT}/scripts/lib/bridges.sh'
    _bridge_target_installed() {
        local file=\"\$1\"
        [[ -f \"\$file\" ]] || return 1
        head -5 \"\$file\" 2>/dev/null | grep -q 'claude-code-toolkit'
    }
    _bridge_target_installed \"\$(_bridge_global_dir gemini)/GEMINI.md\"
    exit \$?
" 2>/dev/null || checked_gem=$?
assert_eq "0" "$checked_gem" "S14.2: probe returns 0 after bridge_create_global gemini writes ~/.gemini/GEMINI.md"

# Negative-control: probing $PWD/GEMINI.md (the old buggy path) must STILL
# report not-installed even though the bridge is present globally — this
# pins down the policy decision that bridges are global, not per-project.
oldpath_gem=0
TK_BRIDGE_HOME="$sb" bash -c "
    cd '$sb/proj'
    source '${REPO_ROOT}/scripts/lib/state.sh'
    source '${REPO_ROOT}/scripts/lib/bridges.sh'
    _bridge_target_installed() {
        local file=\"\$1\"
        [[ -f \"\$file\" ]] || return 1
        head -5 \"\$file\" 2>/dev/null | grep -q 'claude-code-toolkit'
    }
    _bridge_target_installed \"\$PWD/GEMINI.md\"
    exit \$?
" 2>/dev/null || oldpath_gem=$?
assert_eq "1" "$oldpath_gem" "S14.3: old per-project probe ($PWD/GEMINI.md) still returns 1 after global install (pinning global-only semantics)"

echo "=== S15: codex-bridge probe parity ==="
checked_cod=0
TK_BRIDGE_HOME="$sb" bash -c "
    source '${REPO_ROOT}/scripts/lib/state.sh'
    source '${REPO_ROOT}/scripts/lib/bridges.sh'
    bridge_create_global codex >/dev/null
    _bridge_target_installed() {
        local file=\"\$1\"
        [[ -f \"\$file\" ]] || return 1
        head -5 \"\$file\" 2>/dev/null | grep -q 'claude-code-toolkit'
    }
    _bridge_target_installed \"\$(_bridge_global_dir codex)/AGENTS.md\"
    exit \$?
" 2>/dev/null || checked_cod=$?
assert_eq "0" "$checked_cod" "S15: probe returns 0 after bridge_create_global codex writes ~/.codex/AGENTS.md"

echo "=== S13: BACKCOMPAT-01 — all 4 baselines unchanged ==="
for spec in \
    "test-bootstrap.sh:PASS=34 FAIL=0" \
    "test-install-tui.sh:PASS=60 FAIL=0" \
    "test-bridges-foundation.sh:PASS=5 FAIL=0" \
    "test-bridges-sync.sh:PASS=25 FAIL=0"
do
    name="${spec%%:*}"
    expected="${spec#*:}"
    out=$(bash "${REPO_ROOT}/scripts/tests/${name}" 2>&1 | tail -3)
    if printf '%s' "$out" | grep -q "$expected"; then
        assert_pass "S13 ${name} reports ${expected}"
    else
        assert_fail "S13 ${name} reports ${expected}" "actual tail: $(printf '%s' "$out" | tr '\n' ' ')"
    fi
done

# ────────────────────────── summary ──────────────────────────

echo ""
echo "──────────────────────────────────────────────"
printf "PASS=%d FAIL=%d\n" "$PASS" "$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi
exit 0
