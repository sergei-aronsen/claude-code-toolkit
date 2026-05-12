#!/usr/bin/env bash
# test-install-skills-curl-pipe.sh — regression test for the curl-pipe path-
# resolution bug in skills install (user report 2026-05-12).
#
# Bug: under `bash <(curl ...)` or `curl | bash`, install.sh's _source_lib
# writes scripts/lib/skills.sh into /tmp/skills-XXXXXX and sources it from
# there. skills.sh resolves the source mirror via BASH_SOURCE-relative path
# (`${dirname BASH_SOURCE}/../../templates/skills-marketplace`), which under
# tmpfile origin collapses to `/var/folders/.../templates/skills-marketplace`
# — a path that does not exist. Result: every NEW skill install fails with
# `source missing: /var/folders/.../T/../../templates/skills-marketplace/<name>`.
# Pre-installed skills mask the bug because install.sh's dispatch loop short-
# circuits to "installed ✓" without invoking skills_install when TUI_RESULTS=0.
# Equivalent bug for impeccable: install-impeccable.sh resolves to
# `/var/folders/.../T/../install-impeccable.sh` → "not found".
#
# Fix scope: install.sh, under _is_curl_pipe + SKILLS=1, must populate
# TK_SKILLS_MIRROR_PATH and TK_SKILLS_INSTALL_IMPECCABLE_CMD from a
# downloaded toolkit tarball. The new helper lives in scripts/lib/skills.sh
# (function `skills_fetch_mirror_via_tarball`) so the logic is unit-testable
# in isolation, and install.sh just calls it.
#
# Scenarios:
#   CP1_repro_curl_pipe_bug          — sourcing skills.sh from /tmp/<X> with
#                                      no override resolves mirror to a non-
#                                      existent path; skills_install fails
#                                      with "source missing" (baseline /
#                                      proof-of-bug)
#   CP2_fetch_helper_exists          — skills_fetch_mirror_via_tarball is a
#                                      defined function in skills.sh
#   CP3_fetch_helper_exports_paths   — with TK_SKILLS_TARBALL_CMD stub, the
#                                      helper extracts a fixture tarball and
#                                      exports both TK_SKILLS_MIRROR_PATH and
#                                      TK_SKILLS_INSTALL_IMPECCABLE_CMD
#   CP4_install_through_seam         — with helper-exported env vars set,
#                                      skills_install huashu-design succeeds
#                                      even when skills.sh is sourced from
#                                      a /tmp tmpfile (simulating curl-pipe)
#   CP5_impeccable_seam              — impeccable special-case picks up
#                                      TK_SKILLS_INSTALL_IMPECCABLE_CMD set
#                                      by the helper
#   CP6_fetch_helper_fails_clean     — stub returning non-zero leaves no
#                                      partial state and returns rc=1
#
# Test seam env vars: TK_SKILLS_HOME, TK_SKILLS_MIRROR_PATH,
#                     TK_SKILLS_INSTALL_IMPECCABLE_CMD, TK_SKILLS_TARBALL_CMD,
#                     TK_TOOLKIT_REF
#
# Usage: bash scripts/tests/test-install-skills-curl-pipe.sh
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
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    fi
}
assert_file() {
    local path="$1" label="$2"
    if [[ -f "$path" ]]; then assert_pass "$label"
    else assert_fail "$label" "file missing: $path"; fi
}
assert_dir() {
    local path="$1" label="$2"
    if [[ -d "$path" ]]; then assert_pass "$label"
    else assert_fail "$label" "dir missing: $path"; fi
}

echo "test-install-skills-curl-pipe.sh: SKILLS curl-pipe path-resolution regression"
echo ""

# ─────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────

# Build a fixture tarball from the live worktree. The tarball mimics the
# shape produced by https://github.com/<owner>/<repo>/archive/<ref>.tar.gz:
# top-level directory <prefix>/ containing the full tree. We include only
# `templates/skills-marketplace/` and `scripts/install-impeccable.sh` since
# those are the only paths the fix consumes — keeps the fixture small.
build_fixture_tarball() {
    local out="$1"
    local prefix="claude-code-toolkit-fixture"
    local stage
    stage="$(mktemp -d "${TMPDIR:-/tmp}/tk-fixture-stage-XXXXXX")"
    mkdir -p "$stage/$prefix/scripts" "$stage/$prefix/templates"
    cp -R "${REPO_ROOT}/templates/skills-marketplace" "$stage/$prefix/templates/"
    cp "${REPO_ROOT}/scripts/install-impeccable.sh" "$stage/$prefix/scripts/"
    (cd "$stage" && tar -czf "$out" "$prefix")
    rm -rf "$stage"
}

# Stub command for TK_SKILLS_TARBALL_CMD: copies a pre-built fixture tarball
# to $1 (the destination path passed by skills_fetch_mirror_via_tarball).
# Usage: TK_SKILLS_TARBALL_CMD=$STUB; export TK_SKILLS_TARBALL_FIXTURE=...
make_tarball_stub() {
    local stub="$1" fixture="$2"
    cat >"$stub" <<EOF
#!/usr/bin/env bash
cp "$fixture" "\$1"
EOF
    chmod +x "$stub"
}

make_failing_stub() {
    local stub="$1"
    cat >"$stub" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
    chmod +x "$stub"
}

# Simulate curl-pipe origin: copy skills.sh into a tmpfile then source from
# there. Returns the path of the tmpfile so callers can pass it to bash -c.
copy_skills_to_tmpfile() {
    local dst
    dst="$(mktemp "${TMPDIR:-/tmp}/skills-XXXXXX")"
    cp "${REPO_ROOT}/scripts/lib/skills.sh" "$dst"
    printf '%s\n' "$dst"
}

# ─────────────────────────────────────────────────
# CP1 — reproduce the curl-pipe bug
# ─────────────────────────────────────────────────
run_cp1_repro_curl_pipe_bug() {
    echo "  -- CP1_repro_curl_pipe_bug --"
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-skills-cp1.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    local skills_tmpfile
    skills_tmpfile="$(copy_skills_to_tmpfile)"

    local rc=0 out=""
    out=$(TK_SKILLS_HOME="$SANDBOX/skills" \
        bash -c "
            source '$skills_tmpfile'
            skills_install huashu-design
        " 2>&1) || rc=$?

    assert_eq "1" "$rc" "CP1: skills_install fails under curl-pipe origin (rc=1)"
    assert_contains "source missing" "$out" "CP1: stderr names 'source missing' (path-resolution bug)"
    rm -f "$skills_tmpfile"
}

# ─────────────────────────────────────────────────
# CP2 — helper function is defined
# ─────────────────────────────────────────────────
run_cp2_fetch_helper_exists() {
    echo "  -- CP2_fetch_helper_exists --"
    local rc=0
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        declare -F skills_fetch_mirror_via_tarball >/dev/null
    " >/dev/null 2>&1 || rc=$?
    assert_eq "0" "$rc" "CP2: skills_fetch_mirror_via_tarball is a declared function"
}

# ─────────────────────────────────────────────────
# CP3 — helper exports mirror + impeccable paths
# ─────────────────────────────────────────────────
run_cp3_fetch_helper_exports_paths() {
    echo "  -- CP3_fetch_helper_exports_paths --"
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-skills-cp3.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    local fixture="$SANDBOX/fixture.tgz"
    build_fixture_tarball "$fixture"

    local stub="$SANDBOX/tarball-stub.sh"
    make_tarball_stub "$stub" "$fixture"

    # Run helper in a subshell to observe env-var exports without polluting
    # the test process. Print final env values for assertion.
    local rc=0 out=""
    out=$(TMPDIR="$SANDBOX/tmp" TK_SKILLS_TARBALL_CMD="$stub" \
        bash -c "
            mkdir -p '$SANDBOX/tmp'
            source '${REPO_ROOT}/scripts/lib/skills.sh'
            skills_fetch_mirror_via_tarball || exit \$?
            printf 'MIRROR=%s\n' \"\$TK_SKILLS_MIRROR_PATH\"
            printf 'IMPECCABLE=%s\n' \"\$TK_SKILLS_INSTALL_IMPECCABLE_CMD\"
        " 2>&1) || rc=$?

    assert_eq "0" "$rc" "CP3: helper returns 0 with valid fixture tarball"

    local mirror impeccable
    # `|| true` defends the set -e gate when the helper didn't run (CP2 RED)
    # so subsequent assertions still report a clean FAIL instead of aborting.
    mirror=$(printf '%s\n' "$out" | grep '^MIRROR=' | head -1 | cut -d= -f2- || true)
    impeccable=$(printf '%s\n' "$out" | grep '^IMPECCABLE=' | head -1 | cut -d= -f2- || true)

    assert_dir "$mirror" "CP3: TK_SKILLS_MIRROR_PATH exported to existing dir"
    assert_dir "$mirror/huashu-design" "CP3: extracted mirror contains huashu-design"
    assert_file "$impeccable" "CP3: TK_SKILLS_INSTALL_IMPECCABLE_CMD exported to existing file"
}

# ─────────────────────────────────────────────────
# CP4 — full install path through the seam (curl-pipe + helper-set env vars)
# ─────────────────────────────────────────────────
run_cp4_install_through_seam() {
    echo "  -- CP4_install_through_seam --"
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-skills-cp4.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    local fixture="$SANDBOX/fixture.tgz"
    build_fixture_tarball "$fixture"

    local stub="$SANDBOX/tarball-stub.sh"
    make_tarball_stub "$stub" "$fixture"

    local skills_tmpfile
    skills_tmpfile="$(copy_skills_to_tmpfile)"

    local rc=0 out=""
    out=$(TMPDIR="$SANDBOX/tmp" TK_SKILLS_HOME="$SANDBOX/skills" \
          TK_SKILLS_TARBALL_CMD="$stub" \
        bash -c "
            mkdir -p '$SANDBOX/tmp'
            source '$skills_tmpfile'
            skills_fetch_mirror_via_tarball || exit \$?
            skills_install huashu-design
        " 2>&1) || rc=$?

    assert_eq "0" "$rc" "CP4: skills_install huashu-design succeeds under curl-pipe origin after helper"
    assert_dir "$SANDBOX/skills/huashu-design" "CP4: target dir created"
    assert_file "$SANDBOX/skills/huashu-design/SKILL.md" "CP4: SKILL.md copied"

    rm -f "$skills_tmpfile"
}

# ─────────────────────────────────────────────────
# CP5 — impeccable special-case picks up helper-exported env var
# ─────────────────────────────────────────────────
run_cp5_impeccable_seam() {
    echo "  -- CP5_impeccable_seam --"
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-skills-cp5.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    local fixture="$SANDBOX/fixture.tgz"
    build_fixture_tarball "$fixture"

    local stub="$SANDBOX/tarball-stub.sh"
    make_tarball_stub "$stub" "$fixture"

    # Wrapper for install-impeccable.sh: real script invokes `npx`; tests run
    # offline, so we replace the resolved impeccable cmd with a noop stub that
    # returns 0. The fix exports TK_SKILLS_INSTALL_IMPECCABLE_CMD pointing at
    # the EXTRACTED file from the tarball; we then override that env var to a
    # local stub to keep the test hermetic.
    local impeccable_stub="$SANDBOX/impeccable-noop.sh"
    cat >"$impeccable_stub" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$impeccable_stub"

    local skills_tmpfile
    skills_tmpfile="$(copy_skills_to_tmpfile)"

    local rc=0
    TMPDIR="$SANDBOX/tmp" TK_SKILLS_HOME="$SANDBOX/skills" \
    TK_SKILLS_TARBALL_CMD="$stub" \
        bash -c "
            mkdir -p '$SANDBOX/tmp'
            source '$skills_tmpfile'
            skills_fetch_mirror_via_tarball || exit \$?
            # Override the helper-set impeccable cmd with our offline stub to
            # avoid invoking real npx. The seam in skills.sh:218 reads this
            # env var directly.
            export TK_SKILLS_INSTALL_IMPECCABLE_CMD='$impeccable_stub'
            skills_install impeccable
        " >/dev/null 2>&1 || rc=$?

    assert_eq "0" "$rc" "CP5: skills_install impeccable succeeds via env-var seam"

    rm -f "$skills_tmpfile"
}

# ─────────────────────────────────────────────────
# CP6 — fetch failure surfaces as non-zero, leaves env unset
# ─────────────────────────────────────────────────
run_cp6_fetch_helper_fails_clean() {
    echo "  -- CP6_fetch_helper_fails_clean --"
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-skills-cp6.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    local stub="$SANDBOX/failing-stub.sh"
    make_failing_stub "$stub"

    local rc=0 out=""
    out=$(TMPDIR="$SANDBOX/tmp" TK_SKILLS_TARBALL_CMD="$stub" \
        bash -c "
            mkdir -p '$SANDBOX/tmp'
            source '${REPO_ROOT}/scripts/lib/skills.sh'
            skills_fetch_mirror_via_tarball
            rc=\$?
            printf 'rc=%s\n' \"\$rc\"
            printf 'MIRROR=%s\n' \"\${TK_SKILLS_MIRROR_PATH:-UNSET}\"
            printf 'IMPECCABLE=%s\n' \"\${TK_SKILLS_INSTALL_IMPECCABLE_CMD:-UNSET}\"
            exit \$rc
        " 2>&1) || rc=$?

    assert_eq "1" "$rc" "CP6: helper returns rc=1 when fetch stub fails"
    assert_contains "MIRROR=UNSET" "$out" "CP6: TK_SKILLS_MIRROR_PATH not exported on failure"
    assert_contains "IMPECCABLE=UNSET" "$out" "CP6: TK_SKILLS_INSTALL_IMPECCABLE_CMD not exported on failure"
}

# ─────────────────────────────────────────────────
# Run all scenarios
# ─────────────────────────────────────────────────
run_cp1_repro_curl_pipe_bug
run_cp2_fetch_helper_exists
run_cp3_fetch_helper_exports_paths
run_cp4_install_through_seam
run_cp5_impeccable_seam
run_cp6_fetch_helper_fails_clean

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
