#!/usr/bin/env bash
# scripts/tests/matrix/standalone.bats
# REL-01: bats port of standalone mode cells (3 cells, 19 assertions).
# Cells: standalone-fresh (6 asserts), standalone-upgrade (6), standalone-rerun (7).

setup() {
    BATS_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    # shellcheck source=/dev/null
    source "${BATS_FILE_DIR}/lib/helpers.bash"
}

@test "standalone-fresh" {
    cell_standalone_fresh
    [ "$FAIL" -eq 0 ]
}

@test "standalone-upgrade" {
    cell_standalone_upgrade
    [ "$FAIL" -eq 0 ]
}

@test "standalone-rerun" {
    cell_standalone_rerun
    [ "$FAIL" -eq 0 ]
}
