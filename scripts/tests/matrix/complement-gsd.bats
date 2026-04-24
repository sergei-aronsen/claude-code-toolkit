#!/usr/bin/env bash
# scripts/tests/matrix/complement-gsd.bats
# REL-01: bats port of complement-gsd mode cells (3 cells, 13 assertions).
# Cells: complement-gsd-fresh (6 asserts), complement-gsd-upgrade (2), complement-gsd-rerun (5).

setup() {
    BATS_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    # shellcheck source=/dev/null
    source "${BATS_FILE_DIR}/lib/helpers.bash"
}

@test "complement-gsd-fresh" {
    cell_complement_gsd_fresh
    [ "$FAIL" -eq 0 ]
}

@test "complement-gsd-upgrade" {
    cell_complement_gsd_upgrade
    [ "$FAIL" -eq 0 ]
}

@test "complement-gsd-rerun" {
    cell_complement_gsd_rerun
    [ "$FAIL" -eq 0 ]
}
