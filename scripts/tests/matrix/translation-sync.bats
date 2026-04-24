#!/usr/bin/env bash
# scripts/tests/matrix/translation-sync.bats
# REL-01: bats port of translation-sync cell (1 cell, 1 assertion).

setup() {
    BATS_FILE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    # shellcheck source=/dev/null
    source "${BATS_FILE_DIR}/lib/helpers.bash"
}

@test "translation-sync" {
    cell_translation_sync
    [ "$FAIL" -eq 0 ]
}
