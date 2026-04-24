#!/usr/bin/env bash
# scripts/tests/matrix/complement-sp.bats
# REL-01: bats port of complement-sp mode cells (3 cells, 15 assertions).
# Cells: complement-sp-fresh (7 asserts), complement-sp-upgrade (2), complement-sp-rerun (6).

setup() {
    BATS_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    # shellcheck source=/dev/null
    source "${BATS_FILE_DIR}/lib/helpers.bash"
}

@test "complement-sp-fresh" {
    cell_complement_sp_fresh
    [ "$FAIL" -eq 0 ]
}

@test "complement-sp-upgrade" {
    cell_complement_sp_upgrade
    [ "$FAIL" -eq 0 ]
}

@test "complement-sp-rerun" {
    cell_complement_sp_rerun
    [ "$FAIL" -eq 0 ]
}
