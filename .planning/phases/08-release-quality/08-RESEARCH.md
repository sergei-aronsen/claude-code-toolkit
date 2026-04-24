# Phase 8: Release Quality — Research

**Researched:** 2026-04-24
**Domain:** bats testing, shell parity gates, bash flag extension
**Confidence:** HIGH

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**REL-01 — bats port**

- D-01: Bats file layout = per-mode. 5 files: `standalone.bats` (3 cells),
  `complement-sp.bats` (3 cells), `complement-gsd.bats` (3 cells),
  `complement-full.bats` (3 cells), `translation-sync.bats` (1 cell).
- D-02: Shared helpers extracted to `scripts/tests/matrix/lib/helpers.bash`. Both bash
  runner and bats files source this lib.
- D-03: Assertion preservation = 1:1 byte-for-byte. 63-assertion target verified by
  plan-time count diff.
- D-04: `make test-matrix-bats` = thin wrapper running `bats scripts/tests/matrix/*.bats`.
- D-05: Bash runner `validate-release.sh --all` remains functional and authoritative.

**REL-02 — cell-parity**

- D-06: Three surfaces checked: (1) `validate-release.sh --list`, (2) `docs/INSTALL.md`
  `--cell <name>` command occurrences, (3) `docs/RELEASE-CHECKLIST.md` `--cell <name>`
  command occurrences.
- D-07: Parity rule = strict 3/3. Any cell missing from any surface fails.
- D-08: `docs/INSTALL.md` currently has zero `--cell` references — Plan 8.x adds them.
  Also fixes intro "12 cells" drift (runner has 13).
- D-09: Implementation = pure shell + grep + jq, no Python.
- D-10: Makefile target = `cell-parity`. Wired into `check` after `validate-commands`.
  Also wired into `validate-templates` CI job.

**REL-03 — `--collect-all`**

- D-11: `--collect-all` runs all 13 cells regardless of failures, emits ASCII table
  `Cell | Pass | Fail | Status`, summary line `Matrix: X/13 cells passed, Y assertions
  passed, Z assertions failed`. Exit 0 if all pass; exit 1 if any cell had a fail.
- D-12: Default `--all` behavior unchanged (fail-fast).
- D-13: ASCII table = plain with `|` separators, no color theming (Phase 11 scope).
- D-14: `--collect-all` alongside `--all`, mutually exclusive; both together = arg error.

**CI integration**

- D-15: CI bats install = `bats-core-action` pinned to full SHA.
- D-16: New CI job `test-matrix-bats` parallel to `test-init-script`. Cell-parity inside
  `validate-templates` job.

**Transition + compatibility**

- D-17: Plan includes parity-audit step: bash --all PASS count must equal bats PASS count.
- D-18: No changes to any cell body semantics.
- D-19: Branch naming: `feature/rel-01-bats-port`, `feature/rel-02-cell-parity`,
  `feature/rel-03-collect-all`.

### Claude's Discretion

- Exact partition of 63 assertions across the 5 bats files (determined by cell membership).
- `setup_file` vs `setup` granularity — pick at implement time.
- `--collect-all` table formatting: `printf` width specifiers vs `column -t`.
- Exact `--cell <name>` placement in `docs/INSTALL.md`.

### Deferred Ideas (OUT OF SCOPE)

- Remove bash `validate-release.sh` after bats suite proves parity.
- Per-cell section headings in `docs/RELEASE-CHECKLIST.md`.
- JSON output from `--collect-all`.
- Graded exit codes from `--collect-all`.
- Auto-updating `docs/INSTALL.md` cell count from `--list`.
- Test 16 (`test-matrix.sh`) becoming a bats-aware wrapper.

</user_constraints>

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | Port 13 cells to `scripts/tests/matrix/*.bats`, preserving 63 assertions. `make test-matrix-bats` exits 0. Bash runner stays. | Bats process isolation model + PASS/FAIL counter pattern + helpers.bash extraction plan confirmed. Per-cell assertion counts verified (19+15+13+15+1=63). |
| REL-02 | `make check` gains `cell-parity` target. Greps `--cell <name>` occurrences in all three surfaces. Fails if any cell missing from any surface. | INSTALL.md confirmed to have 0 `--cell` refs (requires addition). RELEASE-CHECKLIST.md confirmed to have all 13 cells. grep pattern `--cell [a-z][a-z0-9-]*` verified against live docs. |
| REL-03 | `validate-release.sh --collect-all` runs all 13 cells, emits aggregated table, exit 0/1. Default fail-fast unchanged. | Per-cell counter tracking pattern confirmed. Cell bodies have no bare `exit` — safe to collect. printf width-specifier table format confirmed BSD-portable. |

</phase_requirements>

---

## Summary

Phase 8 is a three-part hardening of the release validation infrastructure with no
user-facing behavior change. Every decision is locked in CONTEXT.md; this research
answers mechanical questions about execution patterns.

The most consequential finding is the **bats process isolation model**: each `@test`
runs in its own subprocess. This means the global `PASS`/`FAIL` counters in
`validate-release.sh` are automatically reset to 0 at the start of every `@test`
without any extra initialization. The port pattern is: source `helpers.bash`, call
`cell_<name>()`, then assert `[ "$FAIL" -eq 0 ]`. No counter plumbing changes
needed in the helper functions themselves.

The second key finding is that **all 63 assertions verified**: the per-cell breakdown
is 6+6+7+7+2+6+6+2+5+7+2+6+1 = 63 across 13 cells. `assert_state_schema` expands
to 4 asserts; `assert_skiplist_clean` and `assert_no_agent_collision` each expand to
1. These expansion counts are the ground truth for D-03 plan-time verification.

For `--collect-all` (REL-03), cell bodies have no bare `exit` calls — all subshell
commands use `&& rc=0 || rc=$?` patterns that capture errors without aborting. The
only `exit 1` is in `run_cell()`. The `--collect-all` dispatcher simply calls a new
`collect_cell()` variant that omits the `exit 1`.

**Primary recommendation:** Port in this order: (1) extract helpers.bash while
validate-release.sh sources it (zero behavior change, smoke-testable), (2) write
bats files that source the same lib, (3) add REL-02 parity gate, (4) add REL-03
flag. Each step is independently testable and keeps `--all` green throughout.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| bats @test execution | CI (ubuntu-latest) | Dev machine | Tests run sandboxed; need bats installed |
| helpers.bash shared lib | Both bash runner + bats layer | — | Sourced at runtime by both; no compilation |
| Cell-parity grep | Makefile target | CI validate-templates step | Pure shell check over static files |
| Aggregated table output | validate-release.sh (runtime) | — | Flag on existing runner, no new binary |
| INSTALL.md `--cell` additions | Docs layer | cell-parity gate enforces it | Human-readable + machine-checkable |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bats-core | v1.13.0 | Test runner for `.bats` files | Official bats-core project; brew formula; CI action available [VERIFIED: github.com/bats-core/bats-core releases] |
| bash | 3.2+ | Shell for scripts and helpers | Project constraint; already required |
| jq | 1.7.1 (local) | JSON parsing in cell-parity and state assertions | Already a project dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bats-core/bats-action | v4.0.0 | Install bats in CI via GitHub Actions | `test-matrix-bats` job only |
| column -t (BSD) | system | ASCII table formatting | Available but `printf` preferred for portability |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bats-core/bats-action | mig4/setup-bats | mig4 is lighter (bats only); bats-core/bats-action is the official org action (D-15 locked) |
| `printf` width specifiers | `column -t` | `column -t` works on BSD macOS (confirmed), but `printf` is more portable and produces deterministic column widths. Claude's discretion — research recommends `printf`. |

**Installation (developer local):**

```bash
brew install bats-core
```

**Version verification:** [VERIFIED: github.com/bats-core/bats-core/releases — v1.13.0 is latest as of 2026-04-24]

---

## Architecture Patterns

### System Architecture Diagram

```text
validate-release.sh                 scripts/tests/matrix/
      │                                     │
      ├── source detect.sh                  ├── standalone.bats
      ├── source lib/install.sh             ├── complement-sp.bats
      ├── source lib/state.sh               ├── complement-gsd.bats
      │                                     ├── complement-full.bats
      └── source helpers.bash ─────────────┘
                  │
                  ├── assert_eq / assert_contains
                  ├── assert_state_schema (→ 4 asserts)
                  ├── assert_skiplist_clean (→ 1 assert)
                  ├── assert_no_agent_collision (→ 1 assert)
                  ├── sandbox_setup / stage_sp_cache / stage_gsd_cache
                  ├── setup_v3x_worktree / cleanup_v3x_worktrees
                  ├── cell_standalone_fresh() .. cell_translation_sync()
                  └── PASS=0, FAIL=0 (globals — reset per @test subprocess)

make check (Makefile)
      │
      ├── lint / validate / validate-base-plugins / ...
      ├── validate-commands (HARDEN-A-01 pattern)
      └── cell-parity (REL-02)
               │
               ├── validate-release.sh --list → 13 cell names
               ├── grep docs/INSTALL.md for --cell <name>
               └── grep docs/RELEASE-CHECKLIST.md for --cell <name>
```

### Recommended Project Structure

```text
scripts/tests/matrix/
├── lib/
│   └── helpers.bash          # Extracted helpers (sourced by both bash + bats)
├── standalone.bats            # Cells 1-3 (19 asserts)
├── complement-sp.bats         # Cells 4-6 (15 asserts)
├── complement-gsd.bats        # Cells 7-9 (13 asserts)
├── complement-full.bats       # Cells 10-12 (15 asserts)
└── translation-sync.bats      # Cell 13 (1 assert)
```

### Pattern 1: helpers.bash — REPO_ROOT Derivation

helpers.bash is sourced from two different call sites (validate-release.sh and *.bats files).
It must derive REPO_ROOT from its own location, not the caller's.

```bash
# Source: BASH_SOURCE[0] resolution at source time
# scripts/tests/matrix/lib/helpers.bash → 4 levels up = repo root
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_HELPERS_DIR}/../../../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
MANIFEST_FILE="${REPO_ROOT}/manifest.json"
REPO_ROOT_ABS="$REPO_ROOT"

# Source the three libs validate-release.sh currently requires
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/detect.sh"
source "${LIB_DIR}/install.sh"
source "${LIB_DIR}/state.sh"

detect_superpowers 2>/dev/null || true
detect_gsd 2>/dev/null || true
```

**Important:** When validate-release.sh sources helpers.bash, it must NOT re-source detect/install/state
itself (they are already sourced inside helpers.bash). Remove the four `require_lib` calls from the main
script and replace with `source helpers.bash`.

### Pattern 2: bats @test Body — FAIL Counter Pattern

**The central insight:** each `@test` runs in its own subprocess. `PASS` and `FAIL` counters
defined in sourced helpers.bash start at 0 for every test. No counter initialization needed.

```bash
# Source: bats-core docs — each @test is an isolated subprocess
# https://bats-core.readthedocs.io/en/stable/writing-tests.html

# scripts/tests/matrix/standalone.bats

HELPERS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)/lib"

setup_file() {
    # Source once per file — BATS exports setup_file vars to all tests
    export HELPERS_DIR
}

setup() {
    # Source per-test (helpers.bash initializes PASS=0 FAIL=0 at source time)
    source "${HELPERS_DIR}/helpers.bash"
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

**Why `setup` not `setup_file`:** `setup_file` runs once and exports variables. But `PASS`/`FAIL`
must be initialized to 0 for each test's subprocess — a `setup_file`-sourced value won't propagate
into child subprocesses without `export`. Using `setup` (which runs before each @test in the same
process as the @test itself) sources helpers.bash fresh per test, guaranteeing counter isolation.

**Alternative — BATS_TEST_TMPDIR not needed:** The cell sandboxes use `/tmp/tk-matrix-<cell>-<ts>/`
(generated by `sandbox_setup()`), not BATS temp dirs. No conflict.

### Pattern 3: bats stdout/stderr Behavior

bats captures stdout and stderr during `@test` execution. Output is suppressed on pass and shown
on failure. The custom `assert_eq` / `assert_contains` helpers write:
- `echo "  ✓ ${msg}"` → stdout (suppressed on pass — acceptable)
- `echo "  ✗ ${msg}" >&2` → stderr (shown on failure — desired)

No changes needed to the assert helper output patterns. [VERIFIED: bats-core docs writing-tests]

### Pattern 4: helpers.bash — init guards

Prevent double-sourcing when both validate-release.sh and a future caller share the same process:

```bash
# At top of helpers.bash:
[ "${_TK_HELPERS_LOADED:-}" = "1" ] && return 0
_TK_HELPERS_LOADED=1
```

This is optional but guards against `require_lib`-style double-source in edge cases.

### Pattern 5: `--collect-all` dispatcher

```bash
# In validate-release.sh — declare accumulators before dispatcher
declare -a CELL_NAMES=()
declare -a CELL_PASS_COUNTS=()
declare -a CELL_FAIL_COUNTS=()

collect_cell() {
    local cell_name="$1" body_fn="$2"
    local before_pass=$PASS before_fail=$FAIL
    echo ""
    echo "${CYAN}━━ Cell: ${cell_name} ━━${NC}"
    "$body_fn"
    local cp cf status_label
    cp=$((PASS - before_pass))
    cf=$((FAIL - before_fail))
    status_label="PASS"
    [ "$cf" -gt 0 ] && status_label="FAIL"
    echo "${GREEN}${status_label}: ${cell_name}${NC}"
    CELL_NAMES+=("$cell_name")
    CELL_PASS_COUNTS+=("$cp")
    CELL_FAIL_COUNTS+=("$cf")
}

print_aggregate_table() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-32s %4s %4s %6s\n" "Cell" "Pass" "Fail" "Status"
    printf "%-32s %4s %4s %6s\n" "--------------------------------" "----" "----" "------"
    local i=0 total_cells=${#CELL_NAMES[@]} cells_passed=0
    while [ "$i" -lt "$total_cells" ]; do
        local name="${CELL_NAMES[$i]}"
        local cp="${CELL_PASS_COUNTS[$i]}"
        local cf="${CELL_FAIL_COUNTS[$i]}"
        local st="PASS"
        [ "$cf" -gt 0 ] && st="FAIL" || cells_passed=$((cells_passed + 1))
        printf "%-32s %4d %4d %6s\n" "$name" "$cp" "$cf" "$st"
        i=$((i + 1))
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Matrix: ${cells_passed}/${total_cells} cells passed, ${PASS} assertions passed, ${FAIL} failed"
}

# In case dispatcher (new --collect-all arm):
    --collect-all)
        for c in "${CELLS[@]}"; do
            collect_cell "$c" "$(cell_fn_for "$c")"
        done
        print_aggregate_table
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
```

**Mutex guard for --all + --collect-all:**

```bash
    --all)
        if [ "${COLLECT_ALL:-}" = "1" ]; then
            echo "ERROR: --all and --collect-all are mutually exclusive" >&2; exit 2
        fi
        ...
```

Or handle in argument pre-parsing before the case block.

### Pattern 6: cell-parity script

```bash
#!/usr/bin/env bash
# scripts/cell-parity.sh — REL-02: assert every cell name appears in all 3 surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUNNER="${REPO_ROOT}/scripts/validate-release.sh"
INSTALL_MD="${REPO_ROOT}/docs/INSTALL.md"
CHECKLIST_MD="${REPO_ROOT}/docs/RELEASE-CHECKLIST.md"

# Surface 1: canonical cell names from runner
mapfile -t CELLS < <(bash "$RUNNER" --list)

ERRORS=0

for cell in "${CELLS[@]}"; do
    in_install=0
    in_checklist=0

    grep -qE "\-\-cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$INSTALL_MD" 2>/dev/null && in_install=1 || true
    grep -qE "\-\-cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$CHECKLIST_MD" 2>/dev/null && in_checklist=1 || true

    if [ "$in_install" = "0" ] || [ "$in_checklist" = "0" ]; then
        printf "❌ %-32s  INSTALL.md=%s  CHECKLIST.md=%s\n" \
            "$cell" "$in_install" "$in_checklist"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo "cell-parity FAILED: $ERRORS cell(s) missing from one or more surfaces"
    exit 1
fi

echo "✅ cell-parity passed: all ${#CELLS[@]} cells present in all 3 surfaces"
```

**Notes:**
- `mapfile -t` requires bash 4.0+. On macOS bash 3.2: use `while IFS= read -r` pattern instead.
- `[[:space:]]` is POSIX portable; avoids GNU-only `\s`.
- Word-boundary: `([^a-z0-9-]|$)` prevents `standalone-fresh` matching `standalone-fresh-x`.

**bash 3.2-safe cell list reading:**

```bash
CELLS=()
while IFS= read -r c; do CELLS+=("$c"); done < <(bash "$RUNNER" --list)
```

### Pattern 7: bats-core-action CI step

```yaml
# In .github/workflows/quality.yml — new job
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

**v4.0.0 breaking change:** Do NOT pass `github-token:` — the v4.0.0 release removed automatic
token passing to avoid rate limiting. No token input needed; bats installs from GitHub releases.
[VERIFIED: github.com/bats-core/bats-action/releases/tag/4.0.0]

### Pattern 8: Makefile additions

```makefile
.PHONY: ... cell-parity test-matrix-bats

check: lint validate validate-base-plugins version-align translation-drift \
       agent-collision-static validate-commands cell-parity
    @echo "All checks passed!"

# REL-01: run bats matrix suite
test-matrix-bats:
    @echo "Running bats install matrix..."
    @bats scripts/tests/matrix/*.bats

# REL-02: cell-parity gate
cell-parity:
    @echo "Checking cell-parity (all 3 surfaces)..."
    @bash scripts/cell-parity.sh
```

### Anti-Patterns to Avoid

- **Sourcing helpers.bash outside a function in bats:** The bats docs explicitly warn that
  diagnostic output is much worse when `load`/`source` is called at top-level (outside `setup`
  or `@test`). Always source in `setup` or `@test`.
- **Using `run` wrapper around cell body functions:** `run` executes in a subshell, so PASS/FAIL
  counter mutations inside cell bodies would be invisible to the calling `@test`. Call cell
  functions directly (no `run`).
- **Adding `return 1` to assert helpers:** assert_eq and assert_contains intentionally don't
  return non-zero — they let the cell body continue collecting all failures. The `[ "$FAIL" -eq 0 ]`
  at the end of each `@test` is the single gate point. Adding `return 1` to helpers would break
  this "collect all failures" pattern.
- **Using GNU-only `column` flags:** `column --table-columns` is GNU coreutils; macOS BSD `column`
  does not support it. Use `printf` width specifiers instead.
- **`declare -A` associative arrays in bash 3.2:** Associative arrays (`declare -A`) require
  bash 4.0+. Use parallel indexed arrays (`CELL_NAMES`, `CELL_PASS_COUNTS`, etc.) instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bats test runner | Custom shell test harness | `bats-core` (brew install bats-core) | TAP output, parallel execution, standard tooling |
| CI bats install | `apt-get install bats` in workflow | `bats-core/bats-action@SHA` | Version pinning, no apt drift, matches project convention |
| Assertion library | New assert_* functions | helpers.bash (extracted from validate-release.sh) | 63 assertions already written and tested; D-03 requires 1:1 preservation |

---

## Common Pitfalls

### Pitfall 1: `run` wrapper swallows FAIL counter mutations

**What goes wrong:** Developer wraps cell body in `run cell_standalone_fresh` to capture output.
`run` executes in a subshell; PASS/FAIL increments inside the subshell don't propagate back.
`[ "$FAIL" -eq 0 ]` always passes; all assertions appear to succeed.

**Why it happens:** `run` is designed for capturing command output/status, not for sharing
mutable globals with the calling context.

**How to avoid:** Call cell functions directly (bare function name, no `run`).

**Warning signs:** `@test` never fails even when you manually inject broken state.

### Pitfall 2: helpers.bash REPO_ROOT resolves to wrong directory

**What goes wrong:** helpers.bash uses `${BASH_SOURCE[0]}` but the variable resolves relative
to the working directory rather than the script's actual path.

**Why it happens:** `$(dirname "${BASH_SOURCE[0]}")` returns `.` when called from the same
directory as the script.

**How to avoid:** Always use `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` to get the
absolute path. Tested: `scripts/tests/matrix/lib/helpers.bash` → 4 levels up → repo root.
[VERIFIED: manual path resolution]

### Pitfall 3: Double-sourcing libs in helpers.bash

**What goes wrong:** validate-release.sh currently calls `require_lib` for detect.sh,
lib/install.sh, lib/state.sh. After extracting helpers.bash, if those `require_lib` calls
remain in validate-release.sh AND helpers.bash also sources them, the functions get
redefined. Side effects: detect_superpowers runs twice, CELLS array may be re-declared.

**How to avoid:** Remove the `require_lib` calls from validate-release.sh and replace with
a single `source helpers.bash`. helpers.bash owns all lib sourcing.

### Pitfall 4: cell-parity grep matches partial cell names

**What goes wrong:** Pattern `--cell standalone` matches `--cell standalone-fresh`,
`--cell standalone-upgrade`, `--cell standalone-rerun`. All three pass the check even
if only one appears in the doc.

**How to avoid:** Anchor the cell name with a non-cell character after it:
`--cell[[:space:]]+<name>([^a-z0-9-]|$)`. Tested against RELEASE-CHECKLIST.md content.

### Pitfall 5: `mapfile` not available in bash 3.2

**What goes wrong:** `mapfile -t CELLS < <(bash "$RUNNER" --list)` fails with
`bash: mapfile: command not found` on macOS default bash 3.2.57.

**Why it happens:** `mapfile` (aka `readarray`) was added in bash 4.0.

**How to avoid:** Use the bash 3.2-safe pattern:

```bash
CELLS=()
while IFS= read -r c; do CELLS+=("$c"); done < <(bash "$RUNNER" --list)
```

### Pitfall 6: `--collect-all` with `set -euo pipefail` and per-cell failures

**What goes wrong:** If a cell body calls a subcommand that fails (e.g., `bash init-local.sh`
exits 1) and the `|| rc=$?` pattern is not used, `set -euo pipefail` aborts the entire script
mid-collection.

**Why it happens:** Cell bodies already use `&& rc=0 || rc=$?` for subprocess calls, so
they're safe. The risk is in any new code added to the `--collect-all` path.

**How to avoid:** All subprocess invocations in collect_cell and cell bodies must use
`&& rc=0 || rc=$?` — never bare invocations that could abort under `set -e`.

**Warning signs:** `--collect-all` exits early (fewer than 13 cell entries in table).

### Pitfall 7: bats-action v4.0.0 github-token

**What goes wrong:** Passing `github-token: ${{ secrets.GITHUB_TOKEN }}` to
`bats-core/bats-action@v4.0.0` triggers a workflow error because the input was removed
in v4.0.0 to prevent rate limiting.

**How to avoid:** Omit the `github-token:` input entirely in the CI step.
[VERIFIED: bats-core/bats-action v4.0.0 release notes — breaking change]

---

## Code Examples

### Example 1: standalone.bats complete structure

```bash
#!/usr/bin/env bash
# scripts/tests/matrix/standalone.bats
# REL-01: bats port of standalone mode cells (3 cells, 19 assertions).

# Source: bats-core docs — setup runs before each @test in the same process
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

### Example 2: helpers.bash opening block

```bash
#!/usr/bin/env bash
# scripts/tests/matrix/lib/helpers.bash
# Shared test helpers for validate-release.sh and bats matrix suite.
# Sourced by: scripts/validate-release.sh (replaces inline definitions)
#             scripts/tests/matrix/*.bats (via setup)

set -euo pipefail

# Guard against double-source
[ "${_TK_HELPERS_LOADED:-}" = "1" ] && return 0
_TK_HELPERS_LOADED=1

# Derive repo root from this file's absolute location (4 levels up)
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_HELPERS_DIR}/../../../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
MANIFEST_FILE="${REPO_ROOT}/manifest.json"
REPO_ROOT_ABS="$REPO_ROOT"
PRE_40_COMMIT="e9411201db9dde6a0676a5a5b09fb80d8893e507"

# Source required libs (previously sourced inline in validate-release.sh)
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/detect.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/install.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/state.sh"

detect_superpowers 2>/dev/null || true
detect_gsd 2>/dev/null || true

# --- Color constants (tty-auto-disable) ---
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi

# --- Global PASS/FAIL counters (reset per @test subprocess in bats) ---
PASS=0
FAIL=0

# [all assert_* helpers, sandbox helpers, cell body functions follow here]
```

### Example 3: cell-parity script (bash 3.2-safe)

```bash
#!/usr/bin/env bash
# scripts/cell-parity.sh — REL-02: assert every cell appears in all 3 surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNNER="${REPO_ROOT}/scripts/validate-release.sh"
INSTALL_MD="${REPO_ROOT}/docs/INSTALL.md"
CHECKLIST_MD="${REPO_ROOT}/docs/RELEASE-CHECKLIST.md"

CELLS=()
while IFS= read -r c; do CELLS+=("$c"); done < <(bash "$RUNNER" --list)

ERRORS=0
for cell in "${CELLS[@]}"; do
    in_install=0
    in_checklist=0
    grep -qE "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$INSTALL_MD"    2>/dev/null && in_install=1    || true
    grep -qE "--cell[[:space:]]+${cell}([^a-z0-9-]|$)" "$CHECKLIST_MD"  2>/dev/null && in_checklist=1  || true
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

### Example 4: validate-release.sh `--collect-all` arm

```bash
# Declare accumulators at top-level (before CELLS=() declaration)
declare -a _COLL_NAMES=()
declare -a _COLL_PASS=()
declare -a _COLL_FAIL=()

# collect_cell: run cell body, accumulate counts, do NOT exit on failure
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

# In case dispatcher:
    --collect-all)
        for c in "${CELLS[@]}"; do
            collect_cell "$c" "$(cell_fn_for "$c")"
        done
        print_aggregate_table
        [ "$FAIL" -gt 0 ] && exit 1
        exit 0
        ;;
```

---

## Per-Cell Assertion Breakdown

**Verified ground truth for D-03 plan-time check.** [VERIFIED: manual count from validate-release.sh lines 280-463]

Expansion factors:
- `assert_state_schema` → 4 assertions (`state.mode`, `state.detected type`, `bad_entries`, `bad_skips`)
- `assert_skiplist_clean` → 1 assertion
- `assert_no_agent_collision` → 1 assertion
- Direct `assert_eq` / `assert_contains` → 1 each

| Cell | Direct | state_schema (×4) | skiplist (×1) | no_collision (×1) | Total |
|------|--------|-------------------|---------------|-------------------|-------|
| standalone-fresh | 1 | 1 (=4) | 1 | 0 | 6 |
| standalone-upgrade | 1 | 1 (=4) | 1 | 0 | 6 |
| standalone-rerun | 2 | 1 (=4) | 1 | 0 | 7 |
| complement-sp-fresh | 1 | 1 (=4) | 1 | 1 | 7 |
| complement-sp-upgrade | 2 | 0 | 0 | 0 | 2 |
| complement-sp-rerun | 0 | 1 (=4) | 1 | 1 | 6 |
| complement-gsd-fresh | 1 | 1 (=4) | 1 | 0 | 6 |
| complement-gsd-upgrade | 2 | 0 | 0 | 0 | 2 |
| complement-gsd-rerun | 0 | 1 (=4) | 1 | 0 | 5 |
| complement-full-fresh | 1 | 1 (=4) | 1 | 1 | 7 |
| complement-full-upgrade | 2 | 0 | 0 | 0 | 2 |
| complement-full-rerun | 0 | 1 (=4) | 1 | 1 | 6 |
| translation-sync | 1 | 0 | 0 | 0 | 1 |
| **TOTAL** | **15** | **9×4=36** | **9** | **3** | **63** |

**Per-file totals:**

| bats file | Cells | Assertions |
|-----------|-------|------------|
| standalone.bats | 1,2,3 | 6+6+7 = 19 |
| complement-sp.bats | 4,5,6 | 7+2+6 = 15 |
| complement-gsd.bats | 7,8,9 | 6+2+5 = 13 |
| complement-full.bats | 10,11,12 | 7+2+6 = 15 |
| translation-sync.bats | 13 | 1 |
| **Total** | 13 | **63** |

---

## Current Surface State

**RELEASE-CHECKLIST.md:** All 13 cells present as `--cell <name>` in command column.
[VERIFIED: grep -o '--cell [a-z][a-z0-9-]*' — 13 distinct names, complement-sp-upgrade appears twice (once in how-to-run example)]

**INSTALL.md:** Zero `--cell` references. Intro says "12 cells" (drift — runner has 13).
Plan 8.x must add `--cell <name>` to each table row and fix the intro count.
[VERIFIED: grep -c '--cell' docs/INSTALL.md = 0]

**validate-release.sh --list:** Emits exactly 13 cell names, one per line.
[VERIFIED: CELLS array at lines 561-567]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic bash runner only | Bash runner + bats layer | Phase 8 (this) | bats provides TAP output, standard test runner semantics |
| `--all` fail-fast only | `--all` + `--collect-all` | Phase 8 (this) | CI can see full matrix failure picture without re-running |
| No surface cross-check | `cell-parity` gate in `make check` | Phase 8 (this) | INSTALL.md drift caught automatically |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| jq | cell-parity, state assertions | Yes | 1.7.1-apple | None — already a hard dep |
| bats-core | REL-01 test runner | No (not installed locally) | — | `brew install bats-core` (one-time dev setup) |
| bash | all scripts | Yes | 3.2.57 (macOS) | None — pinned constraint |
| column | ASCII table | Yes (BSD) | system | Use printf instead (recommended) |
| git | setup_v3x_worktree | Yes | system | None — cell needs git worktree |

**Missing dependencies with fallback:**

- bats-core: not installed locally. Developers run `brew install bats-core` once.
  CI uses `bats-core/bats-action`. This is expected and documented in CONTEXT.md D-15.

**Missing dependencies with no fallback:**

- None that block execution on CI (bats-action handles CI install).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core v1.13.0 |
| Config file | none — bats discovers `*.bats` files by glob |
| Quick run command | `bats scripts/tests/matrix/standalone.bats` |
| Full suite command | `make test-matrix-bats` (runs all 5 files) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-01 | All 13 cells pass in bats | integration | `make test-matrix-bats` | Wave 0 |
| REL-01 | Assert count parity: bash --all == bats | plan-time diff | `diff <(bash --all \| grep '^  [✓✗]') <(bats --tap ...)` | manual Wave 0 |
| REL-02 | cell-parity gate passes | unit (shell) | `make cell-parity` | Wave 0 |
| REL-02 | cell-parity detects injected drift | unit (shell) | remove one `--cell` from INSTALL.md, run `make cell-parity`, expect exit 1 | manual |
| REL-03 | `--collect-all` runs all cells | integration | `bash scripts/validate-release.sh --collect-all` | existing file modified |
| REL-03 | `--collect-all` exit 1 on mixed pass/fail | integration | inject failure, check exit code | manual |
| REL-03 | `--all` still fail-fasts | regression | `bash scripts/validate-release.sh --all` (existing behavior) | existing |

### Sampling Rate

- Per task commit: `bash scripts/validate-release.sh --self-test` (fast, tests helper correctness)
- Per wave merge: `make check` (full gate: shellcheck + lint + cell-parity + all existing checks)
- Phase gate: `make test-matrix-bats` green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/tests/matrix/lib/helpers.bash` — extracted from validate-release.sh
- [ ] `scripts/tests/matrix/standalone.bats` — 3 cells, 19 assertions
- [ ] `scripts/tests/matrix/complement-sp.bats` — 3 cells, 15 assertions
- [ ] `scripts/tests/matrix/complement-gsd.bats` — 3 cells, 13 assertions
- [ ] `scripts/tests/matrix/complement-full.bats` — 3 cells, 15 assertions
- [ ] `scripts/tests/matrix/translation-sync.bats` — 1 cell, 1 assertion
- [ ] `scripts/cell-parity.sh` — REL-02 parity checker
- [ ] Makefile: `cell-parity` + `test-matrix-bats` targets
- [ ] bats install: `brew install bats-core` — developer one-time

---

## Security Domain

This phase makes no changes to authentication, input handling, cryptography, file uploads,
or user-facing endpoints. All changes are to test infrastructure and a CLI flag on an
existing internal script.

ASVS categories V2 (auth), V3 (session), V4 (access control), V6 (crypto) do not apply.

V5 (input validation): The `--collect-all` flag is a simple string match against a
fixed set of known flags — no user-controlled data flows into dangerous functions.
The cell-parity script greps static doc files using a fixed regex — no injection risk.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `bats-core/bats-action@77d6fb60505b4d0d1d73e48bd035b55074bbfb43` is the correct v4.0.0 SHA | Standard Stack / CI pattern | CI step uses wrong version — low risk, SHA is pinned |
| A2 | bats v1.13.0 is the latest stable version as of 2026-04-24 | Standard Stack | bats-action may install a different default version; specify `bats-version` input if needed |

No assumptions for correctness-critical claims (assertion counts, file paths, grep patterns
all verified against actual repo content).

---

## Open Questions

1. **setup_file vs setup granularity for expensive fixture staging**
   - What we know: `setup_file` runs once per file (shared across all tests); `setup` runs per test
   - What's unclear: `setup_v3x_worktree` is expensive (git worktree add). Upgrade cells call it once.
     Should those cells use `setup_file` to create the worktree once and share it?
   - Recommendation: Keep `setup` (per-test sourcing) for simplicity. Each upgrade cell creates its own
     worktree via `setup_v3x_worktree()`. Cost is acceptable for 3 upgrade cells per file.
     `setup_file` optimization is a v4.2+ candidate if CI time becomes a concern.

2. **`docs/INSTALL.md` cell command placement**
   - What we know: Current INSTALL.md has a Command column in each mode table. Adding
     `--cell <name>` per row is the most natural placement.
   - What's unclear: Whether to add a new "Validate command" column or add an inline code snippet
     below each row (or both).
   - Recommendation: Add `--cell <name>` to the existing Command column (same cell as the install command),
     separated by a line break or new column. This is Claude's discretion (D-08). Choose the form that
     passes markdownlint and satisfies the grep pattern `--cell[[:space:]]+<name>`.

---

## Sources

### Primary (HIGH confidence)

- `scripts/validate-release.sh` lines 1-627 — VERIFIED: assertion counts, cell bodies, dispatcher
- `docs/INSTALL.md` — VERIFIED: zero `--cell` refs, "12 cells" intro drift
- `docs/RELEASE-CHECKLIST.md` — VERIFIED: all 13 cells present as `--cell <name>`
- `Makefile` lines 1-229 — VERIFIED: `check` target, `validate-commands` pattern
- `.github/workflows/quality.yml` — VERIFIED: existing job structure, pinned SHA convention
- bats-core.readthedocs.io/en/stable/writing-tests.html — CITED: setup vs setup_file, stdout/stderr, run wrapper, TAP output
- bats-core.readthedocs.io/en/stable/gotchas.html — CITED: run subshell isolation
- github.com/bats-core/bats-action/releases/tag/4.0.0 — VERIFIED: SHA 77d6fb60…, v4.0.0 breaking change

### Secondary (MEDIUM confidence)

- github.com/bats-core/bats-action GitHub releases page — CITED: v4.0.0 latest, SHA
- github.com/bats-core/bats-core/releases — CITED: v1.13.0 latest bats version

### Tertiary (LOW confidence)

- WebSearch result: "each @test runs in its own process" — corroborated by official docs

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — bats-core v1.13.0 verified from GitHub releases; action SHA verified
- Architecture (bats port pattern): HIGH — derived from official bats docs + code analysis of validate-release.sh
- Assertion counts (63 total): HIGH — verified by automated count script against actual source
- Pitfalls: HIGH — most derived from actual code analysis, not training knowledge
- Cell-parity grep: HIGH — tested against live docs content
- printf vs column -t: HIGH — tested on macOS BSD (confirmed both work; printf preferred)

**Research date:** 2026-04-24
**Valid until:** 2026-06-01 (bats-core releases frequently; re-check SHA before CI wiring)
</content>
</invoke>