#!/usr/bin/env bash
# test-install-project-secrets-curl-pipe.sh — regression test for the
# project-secrets lazy-source path collapse under curl-pipe (user report
# 2026-05-12: cloudflare / stripe / mailgun MCPs failed with
# `mcp_wizard_run: project-scope requested but scripts/lib/project-`
# `secrets.sh not loaded`).
#
# Bug: scripts/lib/mcp.sh:97-106 lazy-sources scripts/lib/project-secrets.sh
# via a BASH_SOURCE-relative sibling path
# (`${dirname BASH_SOURCE[mcp.sh]}/project-secrets.sh`). Under `curl ... |
# bash` / `bash <(curl ...)`, install.sh's `_source_lib mcp` writes mcp.sh
# into /tmp/mcp-XXXXXX and sources from there. _MCP_LIB_DIR resolves to /tmp;
# /tmp/project-secrets.sh does not exist, so the guarded `if [[ -f ... ]]`
# silently skips the source. Later, mcp.sh:782 checks
# `command -v project_secrets_write_env` and aborts mcp_wizard_run when the
# user picked a project-scope MCP (cloudflare, stripe, mailgun, etc.).
#
# Symmetric to the v6.23.1 skills-curl-pipe fix: install.sh's curl-pipe path
# must explicitly source `project-secrets.sh` alongside `mcp.sh` so the
# functions are present before mcp.sh's guard checks `command -v`.
#
# Scenarios:
#   PS1_repro_curl_pipe_bug          — sourcing mcp.sh from a /tmp tmpfile
#                                      without explicit project-secrets.sh
#                                      source leaves project_secrets_write_env
#                                      undeclared (baseline / proof-of-bug).
#   PS2_explicit_source_works        — sourcing project-secrets.sh BEFORE
#                                      mcp.sh (mirroring the post-fix
#                                      install.sh order) declares both
#                                      function families.
#   PS3_install_sh_sources_lib_both  — install.sh contains a
#                                      `_source_lib project-secrets` call
#                                      paired with each `_source_lib mcp`
#                                      site (structural regression guard).
#
# Usage: bash scripts/tests/test-install-project-secrets-curl-pipe.sh
# Exit:  0 = pass, 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n      %s\n" "$1" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_contains() {
    local pat="$1" hay="$2" label="$3"
    if printf '%s\n' "$hay" | grep -Fq -- "$pat"; then assert_pass "$label"
    else assert_fail "$label" "pattern not found: $pat"; fi
}

echo "test-install-project-secrets-curl-pipe.sh: project-secrets curl-pipe regression"
echo ""

# Mimic the curl-pipe layout: install.sh's `_source_lib mcp` writes mcp.sh
# into /tmp/mcp-XXXXXX. project-secrets.sh is NOT placed alongside (that's
# the bug surface). Returns the path of the tmp-copied mcp.sh on stdout.
copy_mcp_to_tmpfile() {
    local dst
    dst="$(mktemp "${TMPDIR:-/tmp}/mcp-XXXXXX")"
    cp "${REPO_ROOT}/scripts/lib/mcp.sh" "$dst"
    printf '%s\n' "$dst"
}

# ─────────────────────────────────────────────────
# PS1 — reproduce: mcp.sh sourced alone from /tmp leaves project-secrets
#       functions undeclared (lazy-source sibling resolves to /tmp/project-
#       secrets.sh which doesn't exist; silently skipped).
# ─────────────────────────────────────────────────
run_ps1_repro_curl_pipe_bug() {
    echo "  -- PS1_repro_curl_pipe_bug --"
    local mcp_tmp
    mcp_tmp="$(copy_mcp_to_tmpfile)"

    local rc=0
    bash -c "
        set -u
        # NB: deliberately omit any project-secrets source so we observe
        # the curl-pipe baseline: mcp.sh tries the BASH_SOURCE-relative
        # lazy-source, fails (sibling missing in /tmp), silently moves on.
        source '$mcp_tmp' 2>/dev/null
        command -v project_secrets_write_env >/dev/null
    " || rc=$?

    assert_eq "1" "$rc" "PS1: project_secrets_write_env undeclared under curl-pipe baseline"
    rm -f "$mcp_tmp"
}

# ─────────────────────────────────────────────────
# PS2 — explicit source order (project-secrets BEFORE mcp) declares both
#       function families; mcp.sh's `command -v` guard at lines 97-106 then
#       short-circuits the lazy sibling-source path.
# ─────────────────────────────────────────────────
run_ps2_explicit_source_works() {
    echo "  -- PS2_explicit_source_works --"
    local mcp_tmp ps_tmp
    mcp_tmp="$(copy_mcp_to_tmpfile)"
    ps_tmp="$(mktemp "${TMPDIR:-/tmp}/project-secrets-XXXXXX")"
    cp "${REPO_ROOT}/scripts/lib/project-secrets.sh" "$ps_tmp"

    local rc=0
    bash -c "
        set -u
        # Mirror the post-fix install.sh order: project-secrets BEFORE mcp.
        source '$ps_tmp' 2>/dev/null
        source '$mcp_tmp' 2>/dev/null
        command -v project_secrets_write_env >/dev/null \
            && command -v mcp_wizard_run >/dev/null
    " || rc=$?

    assert_eq "0" "$rc" "PS2: both project_secrets_write_env + mcp_wizard_run declared"
    rm -f "$mcp_tmp" "$ps_tmp"
}

# ─────────────────────────────────────────────────
# PS3 — install.sh sources project-secrets next to each _source_lib mcp
#       call. Structural regression guard against the fix being removed.
# ─────────────────────────────────────────────────
run_ps3_install_sh_sources_lib_both() {
    echo "  -- PS3_install_sh_sources_lib_both --"
    local install_sh="${REPO_ROOT}/scripts/install.sh"

    # Count the _source_lib mcp sites (currently 2: top-level MCPS branch and
    # MCP sub-picker re-entry). Each MUST have a matching _source_lib project-
    # secrets within a 5-line window.
    local mcp_lines
    mcp_lines=$(grep -n '_source_lib mcp' "$install_sh" | cut -d: -f1)

    if [[ -z "$mcp_lines" ]]; then
        assert_fail "PS3: locate _source_lib mcp sites" "no _source_lib mcp lines found"
        return
    fi

    local site_count=0 ok_count=0 _line _block
    for _line in $mcp_lines; do
        site_count=$((site_count + 1))
        # Window: 5 lines before, 5 lines after each `_source_lib mcp` call.
        local _start=$((_line > 5 ? _line - 5 : 1))
        local _end=$((_line + 5))
        _block=$(sed -n "${_start},${_end}p" "$install_sh")
        if printf '%s\n' "$_block" | grep -Fq '_source_lib project-secrets'; then
            ok_count=$((ok_count + 1))
        fi
    done

    assert_eq "$site_count" "$ok_count" \
        "PS3: every _source_lib mcp site has a _source_lib project-secrets neighbor"
}

run_ps1_repro_curl_pipe_bug
run_ps2_explicit_source_works
run_ps3_install_sh_sources_lib_both

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
