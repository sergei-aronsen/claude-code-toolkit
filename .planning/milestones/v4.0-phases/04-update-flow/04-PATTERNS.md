# Phase 04: update-flow - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 11 (created: 6, modified: 5)
**Analogs found:** 11 / 11

All Phase 4 files have strong analogs already introduced by Phase 3 (install-flow). The update flow is a thin superset of install: it shells through the same primitives (`compute_skip_set`, `install_file_with_merge`, `write_state`, `detect_mode`) and adds drift detection, mode diffing, and deferred-update preview on top. Pattern reuse is therefore near-total; only three genuinely new micro-patterns are introduced:

1. Drift comparison of `installed_files[].hash` vs on-disk `sha256sum` (D-50, D-51, D-52)
2. `compute_file_diffs` (new-set / removed-set / changed-set) as a jq companion to `compute_skip_set` (D-53, D-54)
3. Atomic-replace timestamped backup directory `.claude-backup-<unix-ts>-<pid>/` (D-57)

Everything else (mktemp+curl+trap, jq skip-set, grouped dry-run output, test scaffold) is copied verbatim from Phase 3.

---

## File Classification

| File (New/Modified) | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `scripts/tests/test-update-drift.sh` (new) | test | request-response | `scripts/tests/test-safe-merge.sh` | exact |
| `scripts/tests/test-update-diff.sh` (new) | test | request-response | `scripts/tests/test-modes.sh` | exact |
| `scripts/tests/test-update-summary.sh` (new) | test | request-response | `scripts/tests/test-dry-run.sh` | exact |
| `scripts/tests/fixtures/manifest-update-v2.json` (new) | fixture | static-data | `scripts/tests/fixtures/manifest-v2.json` | exact |
| `scripts/tests/fixtures/toolkit-install-seeded.json` (new) | fixture | static-data | inline JSON in `test-state-lib.sh:18-55` + `test-safe-merge.sh` seeding | role-match |
| `scripts/tests/fixtures/update-fixture.sh` (optional helper, new) | test-utility | shared-setup | `setup_install_dir()` in `test-safe-merge.sh:42-58` | role-match |
| `scripts/update-claude.sh` (rewrite) | installer/orchestrator | request-response | `scripts/init-claude.sh` | exact |
| `scripts/lib/install.sh` (extend) | library | batch/transform | existing `compute_skip_set` in `scripts/lib/install.sh:13-46` | exact |
| `scripts/lib/state.sh` (extend) | library | file-I/O | existing `write_state` in `scripts/lib/state.sh:74-105` | exact |
| `Makefile` (extend) | consumer-glue | batch | Tests 6/7/8 block at `Makefile:60-88` | exact |
| `commands/rollback-update.md` (verify) | docs/consumer-glue | request-response | existing file at `commands/rollback-update.md:1-72` | exact |

---

## Pattern Assignments

### `scripts/tests/test-update-drift.sh` (test, request-response)

**Analog:** `scripts/tests/test-safe-merge.sh`
**Why:** Same shape — scenario-driven bash test with per-scenario `setup` / `run` / `assert` phases, reusable seeded install dir, `TK_TEST_INJECT_FAILURE` rollback hook, `assert_eq`-style helpers.

**Imports / header pattern** (`scripts/tests/test-safe-merge.sh:1-18`):

```bash
#!/usr/bin/env bash
# test-safe-merge.sh - Verify safe-merge behavior in install_file_with_merge
#
# Scenarios:
# - ...
#
# Exit 0 on success, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"

# shellcheck source=../lib/fs.sh
. "${LIB_DIR}/fs.sh"
# shellcheck source=../lib/install.sh
. "${LIB_DIR}/install.sh"
```

**Copy verbatim.** New tests additionally source `state.sh` (for `load_state` / `write_state` fixtures) and may source `diff.sh` once `compute_file_diffs` lands there.

**Assert helper** (`scripts/tests/test-safe-merge.sh:20-34`):

```bash
PASS=0
FAIL=0

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [ "${expected}" = "${actual}" ]; then
    PASS=$((PASS + 1))
    echo "  ✓ ${msg}"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ ${msg}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
  fi
}
```

**Copy verbatim.** Add a sibling `assert_contains` (sed/grep check) for hash-string assertions if needed.

**Setup / teardown with mktemp + trap** (`scripts/tests/test-safe-merge.sh:36-68`):

```bash
TMPDIR="$(mktemp -d -t safe-merge-test.XXXXXX)"
cleanup() {
  rm -rf "${TMPDIR}"
}
trap cleanup EXIT

setup_install_dir() {
  local dir="$1"
  mkdir -p "${dir}"
  ...
}
```

**Copy verbatim** for test-update-drift.sh. Add a `setup_seeded_install` that also calls `write_state` with a known manifest hash so drift scenarios have a baseline to diverge from.

**Scenario-driven main loop** (`scripts/tests/test-safe-merge.sh:70-284`):

Use the exact same shape:

```bash
echo ""
echo "Scenario 1: <description>"
echo "---"
SCENARIO_DIR="${TMPDIR}/s1"
setup_install_dir "${SCENARIO_DIR}"
# perform action under test
compute_skip_set ...
# assert
assert_eq "expected" "actual" "msg"
```

**Drift-specific scenarios** (new, from VALIDATION Wave 1, tasks T-04-11..T-04-13):

- Scenario 1: clean drift (no modifications) → `compute_drift` returns empty list
- Scenario 2: user-modified file → returns `{path, expected_hash, actual_hash}` entry
- Scenario 3: file missing on disk → returns entry with `actual_hash=null` sentinel
- Scenario 4: state file missing → drift detection skipped with warning

**Error-injection pattern** (`scripts/tests/test-safe-merge.sh:186-210` — the `TK_TEST_INJECT_FAILURE` block):

```bash
echo "Scenario 6: Atomicity (inject failure mid-write)"
echo "---"
SCENARIO_DIR="${TMPDIR}/s6"
setup_install_dir "${SCENARIO_DIR}"

# Seed project file
echo "ORIGINAL-CONTENT" > "${SCENARIO_DIR}/.claude/test.md"

# Run with failure injection
if TK_TEST_INJECT_FAILURE=1 install_file_with_merge \
  "${SCENARIO_DIR}/source/test.md" \
  "${SCENARIO_DIR}/.claude/test.md" 2>/dev/null; then
  ...
fi

# Verify: project file unchanged (atomic rollback)
assert_eq "ORIGINAL-CONTENT" "$(cat "${SCENARIO_DIR}/.claude/test.md")" \
  "Original file preserved after injected failure"
```

**Reuse pattern verbatim** for drift test's "interrupted update leaves backup intact" scenario.

**Exit summary** (`scripts/tests/test-safe-merge.sh:286-294`):

```bash
echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
```

**Copy verbatim.**

---

### `scripts/tests/test-update-diff.sh` (test, request-response)

**Analog:** `scripts/tests/test-modes.sh`
**Why:** `test-modes.sh` already iterates over a set (the four modes) and asserts set-math outcomes (skip list size by mode). Update-diff is the same shape: iterate over (`old-manifest`, `new-manifest`) fixture pairs and assert `new_set` / `removed_set` / `changed_set` sizes.

**Iteration / table-driven pattern** (`scripts/tests/test-modes.sh:35-81`):

```bash
MODES=("lite" "standard" "plus" "standalone")

for mode in "${MODES[@]}"; do
  echo ""
  echo "--- Mode: ${mode} ---"

  SKIP_FILE="${TMPDIR}/skip-${mode}.txt"
  MANIFEST="${REPO_ROOT}/scripts/tests/fixtures/manifest-v2.json"

  if compute_skip_set "${mode}" "${MANIFEST}" > "${SKIP_FILE}"; then
    SKIP_COUNT=$(grep -c '.' "${SKIP_FILE}" 2>/dev/null || echo 0)
    echo "Skip set size: ${SKIP_COUNT}"
  else
    echo "compute_skip_set failed"
    FAIL=$((FAIL + 1))
    continue
  fi
  ...
done
```

**Reuse pattern:** replace `MODES` with `FIXTURE_PAIRS=("v1:v2" "v2:v2" "v2:v3-breaking")` etc., each pair producing a diff triple `(new, removed, changed)` to assert against.

**Expected-count assertion** (`scripts/tests/test-modes.sh:44-63`):

```bash
case "${mode}" in
  lite)
    EXPECTED_MIN=5
    EXPECTED_MAX=15
    ;;
  ...
esac

if [ "${SKIP_COUNT}" -ge "${EXPECTED_MIN}" ] && [ "${SKIP_COUNT}" -le "${EXPECTED_MAX}" ]; then
  echo "  ✓ Skip count ${SKIP_COUNT} within [${EXPECTED_MIN}..${EXPECTED_MAX}]"
  PASS=$((PASS + 1))
else
  echo "  ✗ Skip count ${SKIP_COUNT} OUT of [${EXPECTED_MIN}..${EXPECTED_MAX}]"
  FAIL=$((FAIL + 1))
fi
```

**Reuse pattern:** for diff tests use exact equality on three counts (new, removed, changed) since fixtures are deterministic.

---

### `scripts/tests/test-update-summary.sh` (test, request-response)

**Analog:** `scripts/tests/test-dry-run.sh`
**Why:** Both tests assert on captured stdout format (`--dry-run` output categories). Update-summary does the same with `[DRIFT]`, `[NEW]`, `[REMOVED]`, `[CHANGED]` category tags.

**Stdout capture + grep-assert pattern** (`scripts/tests/test-dry-run.sh:41-82`):

```bash
OUTPUT_FILE="${TMPDIR}/dry-run-output.txt"

if bash "${REPO_ROOT}/scripts/init-claude.sh" \
  --dry-run \
  --mode=standalone \
  --yes \
  > "${OUTPUT_FILE}" 2>&1; then
  echo "✓ Dry run exited successfully"
  PASS=$((PASS + 1))
else
  echo "✗ Dry run exited non-zero"
  FAIL=$((FAIL + 1))
fi

# Category presence
if grep -q '\[INSTALL\]' "${OUTPUT_FILE}"; then
  echo "  ✓ [INSTALL] category present"
  PASS=$((PASS + 1))
else
  echo "  ✗ [INSTALL] category missing"
  FAIL=$((FAIL + 1))
fi
```

**Reuse pattern:** replace `[INSTALL]` with `[DRIFT]`, `[NEW]`, `[REMOVED]`, `[CHANGED]`, `[SKIP]`. Add assertion that categories appear in the fixed order defined by D-54.

**ANSI color guard** (`scripts/tests/test-dry-run.sh:101-115`):

```bash
# Ensure no raw ANSI escapes leak into non-tty output
if grep -q $'\x1b\[' "${OUTPUT_FILE}"; then
  echo "  ✗ Raw ANSI escape found in non-tty output"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ No ANSI escapes in non-tty output"
  PASS=$((PASS + 1))
fi
```

**Reuse verbatim.** The update summary must honor `[ -t 1 ]` gating for colors — same as dry-run.

---

### `scripts/tests/fixtures/manifest-update-v2.json` (fixture, static-data)

**Analog:** `scripts/tests/fixtures/manifest-v2.json`
**Why:** Already exists and already has the `version` field, `modes.*.skip` arrays, and `files[*]` entries. Update fixture just needs to be a second revision of this one with known deltas so diff tests are deterministic.

**Structure to copy** (`scripts/tests/fixtures/manifest-v2.json:1-45` — the file is already in place; excerpt showing the key shape):

```json
{
  "version": "2.0.0",
  "modes": {
    "lite":       { "skip": [ ... ] },
    "standard":   { "skip": [ ... ] },
    "plus":       { "skip": [ ... ] },
    "standalone": { "skip": [] }
  },
  "files": {
    "commands": [
      { "path": "commands/plan.md", ... },
      ...
    ]
  }
}
```

**New fixture requirements** (from VALIDATION §Fixtures):

- Identical `version` format (`"version": "2.1.0"`)
- 2 new paths relative to `manifest-v2.json` (appear in new_set)
- 1 path removed (appears in removed_set)
- 1 path with changed `hash` field (appears in changed_set)
- All other paths unchanged
- Total file count documented in fixture header comment — needed for deterministic test assertions

**Construction:** copy `manifest-v2.json`, bump version, append two entries, remove one, bump one hash.

---

### `scripts/tests/fixtures/toolkit-install-seeded.json` (fixture, static-data)

**Analog:** inline JSON blob in `scripts/tests/test-state-lib.sh:18-55` (seeded state for `load_state` tests)
**Why:** State-lib tests already construct a minimal `.toolkit-install.json` inline. Drift tests need the same structure but externalized so multiple tests share it.

**Structure from `scripts/lib/state.sh:74-105`** (this is what `write_state` produces — the fixture must match this exact shape):

```json
{
  "schema_version": 1,
  "toolkit_version": "4.0.0",
  "mode": "standalone",
  "installed_at": "2026-04-15T12:00:00Z",
  "manifest_hash": "sha256:...",
  "installed_files": [
    { "path": "commands/plan.md",      "hash": "sha256:abc...", "source": "toolkit" },
    { "path": "agents/planner.md",     "hash": "sha256:def...", "source": "toolkit" },
    ...
  ]
}
```

**Required variants for drift tests:**

- `toolkit-install-seeded.json` — baseline (all 3 files with real hashes that match files copied into tmpdir)
- Test mutates one file after seeding, then asserts drift detector finds exactly that file

**Prefer inline JSON over a fixture file** if the test only needs one variant, per the `test-state-lib.sh:18-55` convention. Externalize only if reused by 2+ test scripts.

---

### `scripts/tests/fixtures/update-fixture.sh` (test-utility, shared-setup — OPTIONAL)

**Analog:** `setup_install_dir()` local function block in `scripts/tests/test-safe-merge.sh:42-58`

**Excerpt** (`scripts/tests/test-safe-merge.sh:42-58`):

```bash
setup_install_dir() {
  local dir="$1"
  mkdir -p "${dir}/.claude"
  mkdir -p "${dir}/source"

  # Seed source files
  echo "SOURCE-V1" > "${dir}/source/test.md"
  ...
}
```

**Decision:** per CLAUDE.md ("do NOT create new files without asking confirmation first" + KISS), **do not create** `update-fixture.sh` unless all three new tests duplicate the same ~40-line setup function. If duplication is <20 lines per test, inline it. The planner should default to inline and only extract if duplication exceeds that threshold in execution.

---

### `scripts/update-claude.sh` (installer/orchestrator, request-response) — REWRITE

**Analog:** `scripts/init-claude.sh` (the entire orchestration shape — mktemp+curl+trap, detect.sh sourcing, mode selection, jq skip consumption, state.sh write, dry-run grouped output)

**Imports / library bootstrap pattern** (`scripts/init-claude.sh:1-52`):

```bash
#!/usr/bin/env bash
#
# init-claude.sh - Install claude-code-toolkit into a project
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/.../init-claude.sh) [flags]

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main"
CLAUDE_DIR=".claude"
STATE_FILE=".toolkit-install.json"

# Download libs into a tmp dir under curl | bash
TMP_LIB="$(mktemp -d -t tk-lib.XXXXXX)"
trap 'rm -rf "${TMP_LIB}"' EXIT

for lib in fs.sh detect.sh install.sh state.sh diff.sh; do
  curl -sSL "${REPO_URL}/scripts/lib/${lib}" -o "${TMP_LIB}/${lib}"
  # shellcheck source=/dev/null
  . "${TMP_LIB}/${lib}"
done
```

**Copy verbatim** — update-claude.sh uses the exact same bootstrap. Only the script banner/description line differs.

**Mode selection** (`scripts/init-claude.sh:130-170` — `detect_mode` invocation, flag parsing, interactive prompt fallback):

```bash
# Mode: flag > state-file > auto-detect > prompt
if [ -n "${MODE_FLAG:-}" ]; then
  MODE="${MODE_FLAG}"
elif [ -f "${CLAUDE_DIR}/${STATE_FILE}" ]; then
  MODE="$(load_state_mode "${CLAUDE_DIR}/${STATE_FILE}")"
else
  MODE="$(detect_mode "${CLAUDE_DIR}")"
fi
```

**Reuse for update** — update-claude.sh **always** reads mode from state first (D-58), falling back to `detect_mode` only if state is absent (legacy install).

**jq skip-set consumption** (`scripts/init-claude.sh:220-250`):

```bash
SKIP_FILE="$(mktemp)"
compute_skip_set "${MODE}" "${MANIFEST}" > "${SKIP_FILE}"

# Later, in the install loop:
while IFS= read -r file_path; do
  if grep -Fxq "${file_path}" "${SKIP_FILE}"; then
    echo "${BLUE}[SKIP]${NC} ${file_path}"
    continue
  fi
  install_file_with_merge "${SOURCE}/${file_path}" "${CLAUDE_DIR}/${file_path}"
done < <(jq -r '.files | to_entries[] | .value[] | .path' "${MANIFEST}")
```

**Reuse verbatim** for update flow's install step. Insertion point: after drift summary, after user confirmation.

**Grouped dry-run output** (`scripts/init-claude.sh:310-360`):

```bash
if [ "${DRY_RUN}" = "1" ]; then
  echo "=== Dry run summary ==="
  echo ""
  echo "Would install (${#INSTALL_LIST[@]}):"
  for f in "${INSTALL_LIST[@]}"; do
    echo "  ${GREEN}[INSTALL]${NC} ${f}"
  done
  echo ""
  echo "Would skip (${#SKIP_LIST[@]}):"
  for f in "${SKIP_LIST[@]}"; do
    echo "  ${BLUE}[SKIP]${NC} ${f}"
  done
  exit 0
fi
```

**Extend for update** — add `[DRIFT]`, `[NEW]`, `[REMOVED]`, `[CHANGED]` groups above the existing `[INSTALL]`/`[SKIP]` pair. Output order per D-54: DRIFT → REMOVED → NEW → CHANGED → SKIP.

**Atomic backup before any write** (new pattern, from D-57; no pre-existing analog in codebase — this is the one genuinely novel primitive Phase 4 introduces). Pattern sketch:

```bash
BACKUP_DIR="${CLAUDE_DIR%/}/../.claude-backup-$(date +%s)-$$"
cp -a "${CLAUDE_DIR}" "${BACKUP_DIR}"
trap 'on_error_restore_backup "${BACKUP_DIR}" "${CLAUDE_DIR}"' ERR
```

The trap restore function mirrors the rollback pattern implied by `commands/rollback-update.md`.

**State write on success** (`scripts/lib/state.sh:74-105`):

```bash
write_state \
  --mode="${MODE}" \
  --manifest-hash="$(sha256sum "${MANIFEST}" | awk '{print $1}')" \
  --installed-files="${INSTALLED_LIST_FILE}" \
  --toolkit-version="${NEW_VERSION}" \
  > "${CLAUDE_DIR}/${STATE_FILE}.tmp" \
  && mv "${CLAUDE_DIR}/${STATE_FILE}.tmp" "${CLAUDE_DIR}/${STATE_FILE}"
```

**Reuse verbatim.** If `write_state` needs a new `--toolkit-version` flag (see state.sh section below), this call site is where it surfaces.

---

### `scripts/lib/install.sh` — EXTEND with `compute_file_diffs`

**Analog:** `compute_skip_set` at `scripts/lib/install.sh:13-46` — same shape (jq over manifest, emit newline-separated paths, fail-fast on bad JSON).

**Excerpt** (`scripts/lib/install.sh:13-46`):

```bash
# compute_skip_set <mode> <manifest_path>
#
# Outputs newline-separated list of files to skip for the given mode.
# Reads .modes.<mode>.skip[] from the manifest.
#
# Returns 0 on success, 1 if mode unknown or manifest malformed.
compute_skip_set() {
  local mode="$1"
  local manifest="$2"

  if ! jq -e ".modes.\"${mode}\"" "${manifest}" > /dev/null 2>&1; then
    echo "Error: unknown mode '${mode}' in manifest" >&2
    return 1
  fi

  jq -r ".modes.\"${mode}\".skip[]?" "${manifest}"
}
```

**New helper** (same shape, diff two manifests):

```bash
# compute_file_diffs <old_manifest> <new_manifest>
#
# Outputs three newline-separated lists, separated by "---":
#   new paths
#   ---
#   removed paths
#   ---
#   changed paths (hash mismatch)
#
# Consumer uses awk/sed to split on "---" sentinel.
compute_file_diffs() {
  local old="$1" new="$2"
  # jq -n --slurpfile a "$old" --slurpfile b "$new" '...'
  ...
}
```

**Reuse patterns verbatim:**
- Same error-guard prefix (`jq -e ... > /dev/null 2>&1`)
- Same lower-case verb name
- Same newline-separated output contract
- Same `return 1` on malformed input

**Alternative (preferred if KISS wins):** output three separate temp files via caller-provided paths instead of a sentinel-split stdout. Planner to decide between styles; CLAUDE.md's KISS tilt suggests **three temp-file outputs** over the sentinel hack.

---

### `scripts/lib/state.sh` — EXTEND `write_state` signature

**Analog:** existing `write_state` at `scripts/lib/state.sh:74-105` — already uses atomic `.tmp` + `mv` pattern.

**Excerpt** (`scripts/lib/state.sh:74-105`):

```bash
# write_state <claude_dir> <mode> <manifest_hash> <installed_files_list>
#
# Writes .toolkit-install.json atomically (temp-file + rename).
write_state() {
  local claude_dir="$1"
  local mode="$2"
  local manifest_hash="$3"
  local installed_list="$4"

  local state_file="${claude_dir}/.toolkit-install.json"
  local tmp="${state_file}.tmp.$$"

  {
    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "toolkit_version": "%s",\n' "${TK_TOOLKIT_VERSION:-unknown}"
    printf '  "mode": "%s",\n' "${mode}"
    printf '  "installed_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "manifest_hash": "%s",\n' "${manifest_hash}"
    printf '  "installed_files": [\n'
    # ... installed_files array emission ...
    printf '  ]\n'
    printf '}\n'
  } > "${tmp}"

  mv "${tmp}" "${state_file}"
}
```

**Changes required (per D-62):**

- Add optional 5th positional arg `toolkit_version` OR document the existing `TK_TOOLKIT_VERSION` env var as the official contract (prefer the latter — no signature change, backward compatible, already read at line 83 equivalent).
- Ensure `installed_files[].hash` field exists for every entry (drift detection depends on it).

**Minimal-diff approach:** verify `TK_TOOLKIT_VERSION` is already exported by `update-claude.sh` before calling `write_state`. No signature change needed. Documentation update in the function header comment only.

---

### `Makefile` — EXTEND test target

**Analog:** Phase 3 added Tests 6/7/8 block at `Makefile:60-88`. Phase 4 adds three more (Tests 9/10/11) with identical shape.

**Existing pattern** (`Makefile:60-88`):

```makefile
test:
	@echo "Running tests..."
	...
	@echo "Test 6: test-safe-merge"
	@bash scripts/tests/test-safe-merge.sh
	@echo ""
	@echo "Test 7: test-modes"
	@bash scripts/tests/test-modes.sh
	@echo ""
	@echo "Test 8: test-dry-run"
	@bash scripts/tests/test-dry-run.sh
	@echo ""
	@echo "All tests passed!"
```

**Extension pattern:**

```makefile
	@echo "Test 9: test-update-drift"
	@bash scripts/tests/test-update-drift.sh
	@echo ""
	@echo "Test 10: test-update-diff"
	@bash scripts/tests/test-update-diff.sh
	@echo ""
	@echo "Test 11: test-update-summary"
	@bash scripts/tests/test-update-summary.sh
	@echo ""
```

**Insertion point:** between Test 8 and `All tests passed!`. No other Makefile changes needed.

---

### `commands/rollback-update.md` (verify compatibility)

**Analog:** existing file at `commands/rollback-update.md:1-72`.

**Key excerpt** (`commands/rollback-update.md:18-40`):

```markdown
## How It Works

After every successful update, `update-claude.sh` writes a timestamped backup:
`.claude-backup-<unix-ts>/`

Running this command:

1. Lists all `.claude-backup-*` directories sorted by mtime
2. Asks which to restore
3. Atomically swaps current `.claude` with the backup
```

**Required change (D-57):** backup path is now `.claude-backup-<unix-ts>-<pid>/` (pid suffix added for parallel-install safety). The command doc glob `.claude-backup-*` still matches — no change to the doc is strictly required, but the example path in line 19 should be updated to reflect the new convention for accuracy.

**Verification:** confirm `ls .claude-backup-*/` in the restore logic handles the new suffix. It does (glob is permissive). No functional change; only doc cosmetic if updated.

---

## Shared Patterns

### Library sourcing (`fs.sh`, `detect.sh`, `install.sh`, `state.sh`, `diff.sh`)

**Source:** `scripts/init-claude.sh:1-52` (mktemp + curl + trap)
**Apply to:** `scripts/update-claude.sh` (rewrite — must re-use the exact same bootstrap), and every new test script's header.

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"

# shellcheck source=../lib/fs.sh
. "${LIB_DIR}/fs.sh"
# shellcheck source=../lib/install.sh
. "${LIB_DIR}/install.sh"
# shellcheck source=../lib/state.sh
. "${LIB_DIR}/state.sh"
# shellcheck source=../lib/diff.sh
. "${LIB_DIR}/diff.sh"
```

### Color constants

**Source:** defined at top of every user-facing script; pattern from `scripts/init-claude.sh:54-60`:

```bash
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi
```

**Apply to:** `scripts/update-claude.sh` rewrite — use the `[ -t 1 ]` tty check so non-tty output has no escape bytes (test-update-summary.sh asserts this).

### Error handling

**Source:** `set -euo pipefail` + trap cleanup pattern (every script header).
**Apply to:** All new files.

```bash
set -euo pipefail
TMPDIR="$(mktemp -d -t tk-update.XXXXXX)"
trap 'rm -rf "${TMPDIR}"' EXIT
trap 'on_error_restore_backup "${BACKUP_DIR:-}" "${CLAUDE_DIR:-}"' ERR
```

### Assertion style in tests

**Source:** `assert_eq` at `scripts/tests/test-safe-merge.sh:20-34`.
**Apply to:** All three new test scripts. Define the function inline — do NOT extract to a shared helper (CLAUDE.md: "If a function fits in 50 lines — do NOT split into sub-functions"; `assert_eq` is 10 lines, duplication across 3 files is acceptable).

### Fixture path resolution

**Source:** `scripts/tests/test-modes.sh:37` (`MANIFEST="${REPO_ROOT}/scripts/tests/fixtures/manifest-v2.json"`).
**Apply to:** All three new tests. Fixtures live under `scripts/tests/fixtures/`, never in tmpdir.

### `[ -t 1 ]` tty gating for ANSI

**Source:** `scripts/init-claude.sh:54-60` pattern above.
**Apply to:** `update-claude.sh` output functions. Enforced by `test-update-summary.sh` regression (grep for `\x1b\[` in captured output).

### jq skip-set / diff-set contract

**Source:** `scripts/lib/install.sh:13-46` (`compute_skip_set`).
**Apply to:** new `compute_file_diffs` in the same file — same naming, same error-guard shape, same stdout contract (newline-separated paths, exit 1 on bad JSON).

---

## No Analog Found

None. Every new file and every extension has a direct predecessor in Phase 3. The **only new primitive** introduced by Phase 4 is:

- Drift detection loop (sha256sum vs `installed_files[].hash`) — no existing sha256-compare code in the codebase. It is simple enough (a for-loop over state entries) that no analog is needed.
- Atomic-replace backup directory with `<unix-ts>-<pid>` suffix — new convention, but the `cp -a` + trap restore pattern is idiomatic bash and documented in `commands/rollback-update.md`.

Both novelties are <30 lines each and fit inline in `scripts/update-claude.sh` (per KISS). No new library file required.

---

## Metadata

**Analog search scope:**
- `scripts/` (all installer, library, and test scripts)
- `.planning/phases/03-install-flow/` (patterns + plan summaries)
- `commands/rollback-update.md`
- `Makefile`

**Files scanned:** 17 (10 installer/lib/test scripts, 3 fixture JSONs, 3 Phase-3 summaries, Makefile)
**Pattern extraction date:** 2026-04-18
