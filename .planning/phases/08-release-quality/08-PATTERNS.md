# Phase 8: Release Quality - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 9 (7 new, 2 modified; docs/INSTALL.md and quality.yml also modified)
**Analogs found:** 8 / 9 (helpers.bash is first-of-its-kind as shared lib)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/tests/matrix/lib/helpers.bash` | utility/shared-lib | batch | `scripts/validate-release.sh` lines 48-257 | extraction (exact source) |
| `scripts/tests/matrix/standalone.bats` | test | batch | `scripts/tests/test-matrix.sh` + `validate-release.sh` cell bodies | role-match |
| `scripts/tests/matrix/complement-sp.bats` | test | batch | `scripts/tests/test-matrix.sh` + `validate-release.sh` cell bodies | role-match |
| `scripts/tests/matrix/complement-gsd.bats` | test | batch | `scripts/tests/test-matrix.sh` + `validate-release.sh` cell bodies | role-match |
| `scripts/tests/matrix/complement-full.bats` | test | batch | `scripts/tests/test-matrix.sh` + `validate-release.sh` cell bodies | role-match |
| `scripts/tests/matrix/translation-sync.bats` | test | batch | `scripts/tests/test-matrix.sh` + cell_translation_sync | role-match |
| `scripts/cell-parity.sh` | utility/gate | batch | `Makefile` target `agent-collision-static` (lines 199-215) | partial-match |
| `scripts/validate-release.sh` (modified) | runner | batch | self (dispatcher lines 573-627, run_cell lines 259-276) | self |
| `Makefile` (modified) | config | batch | `Makefile` lines 217-220 (`validate-commands`) | exact |
| `docs/INSTALL.md` (modified) | docs | — | self (4 mode tables) | self |
| `.github/workflows/quality.yml` (modified) | CI config | batch | quality.yml lines 73-94 (`test-init-script` job) | exact |

---

## Pattern Assignments

### `scripts/tests/matrix/lib/helpers.bash` (utility, shared-lib)

**Analog:** `scripts/validate-release.sh` lines 1-257 (extraction source — move, not copy)

**NO EXISTING ANALOG for the shared-lib pattern itself.** This is the first file in the
repo that is sourced from two separate call sites (the bash runner and bats files). The
double-source guard and REPO_ROOT derivation from BASH_SOURCE[0] are novel patterns.

**Shebang + set + double-source guard** (copy verbatim, add guard):

```bash
#!/usr/bin/env bash
# scripts/tests/matrix/lib/helpers.bash
# Shared test helpers sourced by validate-release.sh and scripts/tests/matrix/*.bats.
set -euo pipefail

# Double-source guard — safe when validate-release.sh sources this AND bats setup() sources it
[ "${_TK_HELPERS_LOADED:-}" = "1" ] && return 0
_TK_HELPERS_LOADED=1
```

**REPO_ROOT derivation from BASH_SOURCE[0]** (4 levels up from lib/):

```bash
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_HELPERS_DIR}/../../../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
MANIFEST_FILE="${REPO_ROOT}/manifest.json"
REPO_ROOT_ABS="$REPO_ROOT"
PRE_40_COMMIT="e9411201db9dde6a0676a5a5b09fb80d8893e507"
```

**Lib sourcing block** — replaces the `require_lib` calls in validate-release.sh (lines 75-91):

```bash
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/detect.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/install.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/state.sh"

detect_superpowers 2>/dev/null || true
detect_gsd 2>/dev/null || true
```

**Color constants pattern** (from `validate-release.sh` lines 23-40 — copy verbatim):

```bash
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    # shellcheck disable=SC2034
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    # shellcheck disable=SC2034
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi
```

**Global counters** (from `validate-release.sh` lines 42-44):

```bash
# Reset per @test subprocess in bats; reset once per --cell/--all call in bash runner
PASS=0
FAIL=0
```

**Content to move verbatim from validate-release.sh into helpers.bash:**

- `assert_eq()` — lines 48-59
- `assert_contains()` — lines 61-71
- `sandbox_setup()` — lines 98-105
- `stage_sp_cache()` — lines 107-114
- `stage_gsd_cache()` — lines 116-124
- `snapshot_foreign_settings()` — lines 126-134
- `seed_foreign_settings()` — lines 136-154
- `CELL_WT_PATH=""` and `setup_v3x_worktree()` — lines 158-167
- `cleanup_v3x_worktrees()` and `trap` — lines 169-176
- `assert_state_schema()` — lines 179-200
- `assert_settings_foreign_intact()` — lines 202-209
- `assert_skiplist_clean()` — lines 211-230
- `assert_no_agent_collision()` — lines 232-257
- All 13 `cell_*` functions — lines 280-463

After extraction, `validate-release.sh` must:
1. Remove the `require_lib` calls (lines 75-91)
2. Remove all helpers/cell bodies (lines 48-463)
3. Add a single `source` call in their place:

```bash
# Single source replaces all require_lib + inline helpers:
# shellcheck source=scripts/tests/matrix/lib/helpers.bash
source "${SCRIPT_DIR}/tests/matrix/lib/helpers.bash"
```

**Critical:** `CELL_WORKTREES` array declaration at line 96 moves into helpers.bash as well:

```bash
declare -a CELL_WORKTREES=()
```

---

### `scripts/tests/matrix/standalone.bats` (test, batch — 3 @test, 19 assertions)

**Analog:** `scripts/tests/test-matrix.sh` (wrapper pattern) + cell bodies from `validate-release.sh`

**Complete file structure** (copy this pattern for all 5 .bats files):

```bash
#!/usr/bin/env bash
# scripts/tests/matrix/standalone.bats
# REL-01: bats port of standalone mode cells (3 cells, 19 assertions).
# Cells: standalone-fresh (6), standalone-upgrade (6), standalone-rerun (7).

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
```

**Why `setup()` not `setup_file()`:** Each `@test` runs in its own subprocess; PASS/FAIL counters
defined in helpers.bash reset to 0 at subprocess start. Using `setup()` (runs before each @test
in the same process) guarantees counter initialization. `setup_file()` would not propagate
mutable counter changes into the @test subprocess.

**Why no `run` wrapper:** `run` executes in a subshell — PASS/FAIL mutations inside cell bodies
would be invisible. Call cell functions directly (bare function name).

**The single gate point:** `[ "$FAIL" -eq 0 ]` at the end of each `@test`. Do NOT add
`return 1` to assert helpers — they intentionally let the cell body continue after each failure
(collect-all semantics within a cell).

---

### `scripts/tests/matrix/complement-sp.bats` (test, batch — 3 @test, 15 assertions)

**Analog:** Same pattern as `standalone.bats`

**Cells and assertion counts:**

- `complement-sp-fresh` → `cell_complement_sp_fresh` (7 assertions: 1 direct + 4 state_schema + 1 skiplist + 1 no_collision)
- `complement-sp-upgrade` → `cell_complement_sp_upgrade` (2 assertions: 2 direct)
- `complement-sp-rerun` → `cell_complement_sp_rerun` (6 assertions: 4 state_schema + 1 skiplist + 1 no_collision)

**File structure:** Identical to `standalone.bats` — replace cell function names.

---

### `scripts/tests/matrix/complement-gsd.bats` (test, batch — 3 @test, 13 assertions)

**Analog:** Same pattern as `standalone.bats`

**Cells and assertion counts:**

- `complement-gsd-fresh` → `cell_complement_gsd_fresh` (6 assertions)
- `complement-gsd-upgrade` → `cell_complement_gsd_upgrade` (2 assertions)
- `complement-gsd-rerun` → `cell_complement_gsd_rerun` (5 assertions)

---

### `scripts/tests/matrix/complement-full.bats` (test, batch — 3 @test, 15 assertions)

**Analog:** Same pattern as `standalone.bats`

**Cells and assertion counts:**

- `complement-full-fresh` → `cell_complement_full_fresh` (7 assertions)
- `complement-full-upgrade` → `cell_complement_full_upgrade` (2 assertions)
- `complement-full-rerun` → `cell_complement_full_rerun` (6 assertions)

---

### `scripts/tests/matrix/translation-sync.bats` (test, batch — 1 @test, 1 assertion)

**Analog:** Same pattern as `standalone.bats` — degenerate case with single cell.

```bash
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
```

---

### `scripts/cell-parity.sh` (utility/gate, batch)

**Analog:** `Makefile` target `agent-collision-static` (lines 199-215) — same pattern: loop
over a set, check presence, accumulate ERRORS, exit 1 on non-zero. Translated to standalone
script because it needs to run `validate-release.sh --list` as a subprocess.

Also closest to `version-align` target (lines 151-174) — ERRORS counter + final exit 1.

**Complete file pattern** (bash 3.2-safe — no `mapfile`):

```bash
#!/usr/bin/env bash
# scripts/cell-parity.sh — REL-02: assert every cell name appears in all 3 surfaces.
# Surfaces: (1) validate-release.sh --list, (2) docs/INSTALL.md, (3) docs/RELEASE-CHECKLIST.md.
# Exit: 0 = all 3 surfaces carry all cell names; 1 = drift detected.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUNNER="${REPO_ROOT}/scripts/validate-release.sh"
INSTALL_MD="${REPO_ROOT}/docs/INSTALL.md"
CHECKLIST_MD="${REPO_ROOT}/docs/RELEASE-CHECKLIST.md"

# bash 3.2-safe cell list (mapfile requires bash 4.0+)
CELLS=()
while IFS= read -r c; do CELLS+=("$c"); done < <(bash "$RUNNER" --list)

ERRORS=0
for cell in "${CELLS[@]}"; do
    in_install=0
    in_checklist=0
    grep -qE "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$INSTALL_MD"   2>/dev/null && in_install=1   || true
    grep -qE "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$CHECKLIST_MD" 2>/dev/null && in_checklist=1 || true
    if [ "$in_install" = "0" ] || [ "$in_checklist" = "0" ]; then
        printf "❌ %-32s  INSTALL.md=%s  CHECKLIST.md=%s\n" "$cell" "$in_install" "$in_checklist"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo "cell-parity FAILED: ${ERRORS} cell(s) missing from ≥1 surface"
    exit 1
fi
echo "✅ cell-parity passed: all ${#CELLS[@]} cells present in all 3 surfaces"
```

**Word-boundary note:** `([^a-z0-9-]|$)` prevents `standalone` matching `standalone-fresh`.
Pattern uses `[[:space:]]` (POSIX portable) not `\s` (GNU-only).

---

### `scripts/validate-release.sh` (modified — add `--collect-all`)

**Analog:** Self — dispatcher block lines 573-627 and `run_cell()` lines 259-276.

**Accumulator declarations** (add at top-level alongside `CELLS=()`, line 561):

```bash
# REL-03 accumulators — populated only during --collect-all run
declare -a _COLL_NAMES=()
declare -a _COLL_PASS=()
declare -a _COLL_FAIL=()
```

**`collect_cell()` function** (sibling to `run_cell()` at lines 259-276 — add immediately after):

```bash
# collect_cell: run cell body, accumulate per-cell counts, do NOT exit on failure
# Analog: run_cell() at lines 259-276 — same structure but omits exit 1
collect_cell() {
    local cell_name="$1" body_fn="$2"
    local bp=$PASS bf=$FAIL
    echo ""
    echo "${CYAN}━━ Cell: ${cell_name} ━━${NC}"
    "$body_fn"
    local cp cf
    cp=$((PASS - bp))
    cf=$((FAIL - bf))
    if [ "$cf" -gt 0 ]; then
        echo "${RED}FAIL: ${cell_name}: ${cf} assertion(s) failed${NC}" >&2
    else
        echo "${GREEN}PASS: ${cell_name}${NC}"
    fi
    _COLL_NAMES+=("$cell_name")
    _COLL_PASS+=("$cp")
    _COLL_FAIL+=("$cf")
}
```

**`print_aggregate_table()` function** (add after `collect_cell()`):

```bash
# print_aggregate_table: emit ASCII table after --collect-all run
# Uses printf width specifiers (BSD-portable — avoids GNU column --table-columns)
print_aggregate_table() {
    local i=0 total=${#_COLL_NAMES[@]} cells_ok=0
    echo ""
    printf "%-32s %4s %4s %6s\n" "Cell" "Pass" "Fail" "Status"
    printf "%-32s %4s %4s %6s\n" "--------------------------------" "----" "----" "------"
    while [ "$i" -lt "$total" ]; do
        local n="${_COLL_NAMES[$i]}" cp="${_COLL_PASS[$i]}" cf="${_COLL_FAIL[$i]}" st="PASS"
        [ "$cf" -gt 0 ] && st="FAIL" || cells_ok=$((cells_ok + 1))
        printf "%-32s %4d %4d %6s\n" "$n" "$cp" "$cf" "$st"
        i=$((i + 1))
    done
    echo ""
    echo "Matrix: ${cells_ok}/${total} cells passed, ${PASS} assertions passed, ${FAIL} failed"
}
```

**Dispatcher addition** (add `--collect-all)` arm alongside `--all)` at lines 598-608):

```bash
    --collect-all)
        for c in "${CELLS[@]}"; do
            collect_cell "$c" "$(cell_fn_for "$c")"
        done
        print_aggregate_table
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
```

**Mutex guard pattern** (add to argument pre-parsing before the `case` block, or at top of `--all)` arm):

```bash
    --all)
        if [ "${1:-}" = "--collect-all" ] || [ "${2:-}" = "--collect-all" ]; then
            echo "ERROR: --all and --collect-all are mutually exclusive" >&2; exit 2
        fi
        # existing --all body unchanged...
```

**Simpler alternative:** Pre-parse flags before the case block:

```bash
COLLECT_ALL=0
for arg in "$@"; do
    [ "$arg" = "--collect-all" ] && COLLECT_ALL=1
done
if [ "$COLLECT_ALL" = "1" ] && echo "$*" | grep -q -- "--all"; then
    echo "ERROR: --all and --collect-all are mutually exclusive" >&2; exit 2
fi
```

**After helpers extraction:** Remove `require_lib` lines 75-91, all inline helpers lines 48-257,
all cell body functions lines 280-463. Add single source line:

```bash
# shellcheck source=scripts/tests/matrix/lib/helpers.bash
source "${SCRIPT_DIR}/tests/matrix/lib/helpers.bash"
```

---

### `Makefile` (modified — add `cell-parity` and `test-matrix-bats` targets)

**Analog:** `validate-commands` target (lines 217-220) — exact pattern for a target that
delegates to an external script. Also `version-align` (lines 151-174) for multi-step shell
inline with ERRORS counter.

**`.PHONY` addition** (line 1 — append to existing list):

```makefile
.PHONY: help check lint shellcheck mdlint test validate validate-base-plugins \
        version-align translation-drift agent-collision-static validate-commands \
        cell-parity test-matrix-bats clean install
```

**`check` target modification** (line 17 — add `cell-parity` after `validate-commands`):

```makefile
check: lint validate validate-base-plugins version-align translation-drift \
       agent-collision-static validate-commands cell-parity
	@echo "All checks passed!"
```

**New `cell-parity` target** (append after `validate-commands` at line 220):

```makefile
# REL-02: cell-parity gate — all 3 surfaces must carry all 13 cell names
cell-parity:
	@echo "Checking cell-parity (all 3 surfaces)..."
	@bash scripts/cell-parity.sh
```

**New `test-matrix-bats` target** (append after `cell-parity`):

```makefile
# REL-01: run bats matrix suite (requires: brew install bats-core)
test-matrix-bats:
	@echo "Running bats install matrix..."
	@bats scripts/tests/matrix/*.bats
```

**Pattern origin:** `validate-commands` at lines 217-220:

```makefile
# Validate commands/*.md for required ## Purpose and ## Usage headings (HARDEN-A-01 — derived from AUDIT-12)
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py
```

---

### `docs/INSTALL.md` (modified — add `--cell <name>` references)

**Analog:** Self (lines 29-65 — 4 mode tables). No structural change; add `--cell <name>` to
Command column of each row so cell names appear as grep-matchable text.

**Current state:** Zero `--cell` references. Intro says "12 cells" (drift — runner has 13).

**Required changes:**
1. Line 1: Change "12 cells" to "13 cells"
2. Each table row: Add `--cell <cell-name>` to the Command column

**Pattern for adding cell validate commands** — augment Command column inline (confirmed
grep-able by cell-parity.sh):

For the standalone mode table (lines 31-36), the Command column cells become:

```markdown
| **Fresh install** | ... | `bash <(curl -sSL .../scripts/init-claude.sh)` <br> `bash scripts/validate-release.sh --cell standalone-fresh` | ...
```

Or as a new validate column appended to each table. The exact placement is Claude's discretion
(D-08) — any form that makes `--cell standalone-fresh` appear as text in INSTALL.md satisfies
the grep pattern `--cell[[:space:]]+standalone-fresh([^a-z0-9-]|$)`.

**13 cell names to add (one per table row):**

| Mode | Cells |
|---|---|
| standalone | `standalone-fresh`, `standalone-upgrade`, `standalone-rerun` |
| complement-sp | `complement-sp-fresh`, `complement-sp-upgrade`, `complement-sp-rerun` |
| complement-gsd | `complement-gsd-fresh`, `complement-gsd-upgrade`, `complement-gsd-rerun` |
| complement-full | `complement-full-fresh`, `complement-full-upgrade`, `complement-full-rerun` |
| (separate) | `translation-sync` |

---

### `.github/workflows/quality.yml` (modified — add `test-matrix-bats` job + `cell-parity` step)

**Analog 1 (new job):** `test-init-script` job (lines 73-94) — exact sibling pattern.

**Analog 2 (new step in validate-templates):** `HARDEN-A-01` step at lines 70-71:

```yaml
      - name: HARDEN-A-01 — validate commands/*.md required headings
        run: make validate-commands
```

**New `test-matrix-bats` job** — copy `test-init-script` job shape, replace steps:

```yaml
  test-matrix-bats:
    name: Test Matrix (bats)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Install bats-core
        uses: bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43 # v4.0.0

      - name: Run matrix bats suite
        run: make test-matrix-bats
```

**CRITICAL:** Do NOT pass `github-token:` input to `bats-action@v4.0.0` — the input was
removed in v4.0.0 as a breaking change.

**New `cell-parity` step in `validate-templates` job** — add after the HARDEN-A-01 step (line 71):

```yaml
      - name: REL-02 — cell-parity (all 3 surfaces carry all 13 cell names)
        run: make cell-parity
```

**Pinned SHA convention** (from existing actions — must match):

```yaml
# Pattern from existing quality.yml:
uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
uses: ludeeus/action-shellcheck@00b27aa7cb85167568cb48a3838b75f4265f2bca # v2.0.0
uses: DavidAnson/markdownlint-cli2-action@455b6612a7b7a80f28be9e019b70abdd11696e4e # v14

# New bats action (same convention — SHA then tag comment):
uses: bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43 # v4.0.0
```

---

## Shared Patterns

### set -euo pipefail

**Source:** Every script in `scripts/` (e.g., `validate-release.sh` line 16, `test-matrix.sh` line 3)
**Apply to:** `scripts/cell-parity.sh`, `scripts/tests/matrix/lib/helpers.bash`

```bash
set -euo pipefail
```

### SCRIPT_DIR + REPO_ROOT derivation

**Source:** `scripts/test-matrix.sh` lines 8-9 (2-level); `scripts/validate-release.sh` lines 18-19

```bash
# test-matrix.sh pattern (2 levels up from scripts/tests/):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# validate-release.sh pattern (1 level up from scripts/):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# helpers.bash pattern (4 levels up from scripts/tests/matrix/lib/):
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_HELPERS_DIR}/../../../.." && pwd)"
```

### ERRORS counter accumulator + exit 1

**Source:** `Makefile` `validate` target (lines 106-124), `validate-base-plugins` (lines 143-149),
`version-align` (lines 151-174), `agent-collision-static` (lines 199-215)

```bash
ERRORS=0
# ... check loop ...
if [ "$ERRORS" -gt 0 ]; then
    echo "Found $ERRORS errors"
    exit 1
fi
echo "✅ All checks passed"
```

**Apply to:** `scripts/cell-parity.sh`

### TTY-auto-disable color constants

**Source:** `scripts/validate-release.sh` lines 23-40

```bash
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi
```

**Apply to:** `scripts/tests/matrix/lib/helpers.bash` (carries these constants for cell body output)

### Subprocess invocation with error capture (NOT bare invocation)

**Source:** `scripts/validate-release.sh` cell bodies (e.g., lines 284, 314-316)

```bash
( cd "$CH" && HOME="$CH" bash "$REPO_ROOT_ABS/scripts/init-local.sh" ... ) && rc=0 || rc=$?
assert_eq "0" "$rc" "init-local.sh exits 0"
```

**Apply to:** Any new subprocess calls in `collect_cell()` or the `--collect-all` dispatcher.
Under `set -euo pipefail`, bare subprocess calls that fail will abort the script. The
`&& rc=0 || rc=$?` pattern is mandatory in all cell bodies and the new collect paths.

### Makefile inline check target pattern

**Source:** `Makefile` `validate-commands` lines 217-220

```makefile
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py
```

**Apply to:** `cell-parity` and `test-matrix-bats` targets (same 2-line shape: echo + delegate)

### CI pinned-SHA action convention

**Source:** `.github/workflows/quality.yml` lines 17, 21, 29, 32

```yaml
uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
```

**Apply to:** `bats-core/bats-action` reference in new `test-matrix-bats` job

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `scripts/tests/matrix/lib/helpers.bash` | shared-lib | batch | First file in the repo designed to be sourced from two different call sites (bash runner + bats). The double-source guard pattern and BASH_SOURCE-based REPO_ROOT derivation are novel. Content comes entirely from validate-release.sh, but the shared-lib wrapper is first-of-its-kind. |

---

## Critical Implementation Notes for Planner

### Note 1: helpers.bash extraction is a prerequisite for all other REL-01 work

The extraction order must be: (1) create helpers.bash containing moved content, (2) modify
validate-release.sh to source helpers.bash in place of inline definitions, (3) smoke-test
`bash scripts/validate-release.sh --self-test` to confirm zero behavior change, (4) write
bats files that source the same lib. Steps 1-3 are a single atomic plan action.

### Note 2: CELL_WORKTREES array and trap

The `declare -a CELL_WORKTREES=()` at line 96 and the `trap cleanup_v3x_worktrees EXIT` at
line 176 must move to helpers.bash. In bats, the trap fires at the end of each @test subprocess
(correct behavior — worktrees created by upgrade cells are cleaned up per test).

### Note 3: bash 3.2 constraint on cell-parity.sh

macOS ships bash 3.2.57. The cell-parity script must avoid:
- `mapfile` / `readarray` (bash 4.0+) — use `while IFS= read -r` loop
- `declare -A` associative arrays (bash 4.0+) — not needed here
- GNU-only flags (`[[:space:]]` vs `\s` in grep patterns)

### Note 4: assertion count verification (D-03)

Plan must include a count diff step before declaring REL-01 complete:

```bash
assert_count_bats=$(grep -r 'assert_' scripts/tests/matrix/*.bats | grep -c 'assert_')
assert_count_bash=$(grep -c 'assert_' scripts/validate-release.sh)
# These must match after accounting for helpers.bash extraction
```

More precisely: count `assert_` calls inside `@test` bodies in all .bats files must equal
63 (verified ground truth per RESEARCH.md per-cell breakdown table).

### Note 5: `--collect-all` and `set -euo pipefail`

Cell bodies already use `&& rc=0 || rc=$?` for all subprocess calls. The new `collect_cell()`
function must NOT call cell body functions with `run` (bats subshell) and must NOT use bare
subprocess calls. The pattern from existing cell bodies is the model.

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/tests/`, `Makefile`, `.github/workflows/quality.yml`, `docs/`
**Files scanned:** 11 files read in full; validate-release.sh read in 3 passes (lines 1-300, 300-500, 540-627)
**Pattern extraction date:** 2026-04-24
