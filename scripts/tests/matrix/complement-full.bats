#!/usr/bin/env bash
# scripts/tests/matrix/complement-full.bats
# REL-01: bats port of complement-full mode cells (3 cells, 15 assertions).
# Cells: complement-full-fresh (7 asserts), complement-full-upgrade (2), complement-full-rerun (6).

setup() {
    BATS_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    # shellcheck source=/dev/null
    source "${BATS_FILE_DIR}/lib/helpers.bash"
}

@test "complement-full-fresh" {
    cell_complement_full_fresh
    [ "$FAIL" -eq 0 ]
}

@test "complement-full-upgrade" {
    cell_complement_full_upgrade
    [ "$FAIL" -eq 0 ]
}

@test "complement-full-rerun" {
    cell_complement_full_rerun
    [ "$FAIL" -eq 0 ]
}
