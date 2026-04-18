#!/usr/bin/env bash
# test-update-diff.sh — Phase 4 Plan 04-02 file-diff assertions (new/removed/modified).
#
# Scenarios (Plan 04-02 turns these GREEN):
# - new-file-auto-install         (D-54)
# - removed-file-accept           (D-55)
# - modified-file-keep            (D-56)
# - new-file-filtered-by-skip-set (D-54 + skip-set)
# - removed-file-decline          (D-55)
# - modified-file-overwrite       (D-56)
# - modified-file-diff            (D-56 diff output)
#
# Exit 0 on all pass, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # REPO_ROOT consumed by Plan 04-02 when scenarios are implemented
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}

TMPDIR_ROOT="$(mktemp -d -t tk-update-diff.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

scenario_new_file_auto_install() {
    echo ""
    echo "Scenario: new-file-auto-install (D-54)"
    echo "---"
    # Plan 04-02 will turn this green
    assert_eq "pending-plan-04-02" "" "D-54 new-file-auto-install — Plan 04-02 will turn this green"
}

scenario_removed_file_accept() {
    echo ""
    echo "Scenario: removed-file-accept (D-55)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-55 removed-file-accept — Plan 04-02 will turn this green"
}

scenario_modified_file_keep() {
    echo ""
    echo "Scenario: modified-file-keep (D-56)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-56 modified-file-keep — Plan 04-02 will turn this green"
}

scenario_new_file_filtered_by_skip_set() {
    echo ""
    echo "Scenario: new-file-filtered-by-skip-set (D-54 + skip-set)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-54 new-file-filtered-by-skip-set — Plan 04-02 will turn this green"
}

scenario_removed_file_decline() {
    echo ""
    echo "Scenario: removed-file-decline (D-55)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-55 removed-file-decline — Plan 04-02 will turn this green"
}

scenario_modified_file_overwrite() {
    echo ""
    echo "Scenario: modified-file-overwrite (D-56)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-56 modified-file-overwrite — Plan 04-02 will turn this green"
}

scenario_modified_file_diff() {
    echo ""
    echo "Scenario: modified-file-diff (D-56 diff output)"
    echo "---"
    assert_eq "pending-plan-04-02" "" "D-56 modified-file-diff — Plan 04-02 will turn this green"
}

scenario_new_file_auto_install
scenario_removed_file_accept
scenario_modified_file_keep
scenario_new_file_filtered_by_skip_set
scenario_removed_file_decline
scenario_modified_file_overwrite
scenario_modified_file_diff

echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
