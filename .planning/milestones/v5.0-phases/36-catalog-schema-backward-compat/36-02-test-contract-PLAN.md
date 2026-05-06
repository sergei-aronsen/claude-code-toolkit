---
phase: 36
plan: 02
type: execute
wave: 2
depends_on:
  - "36-01"
files_modified:
  - scripts/tests/test-integrations-catalog.sh
  - scripts/tests/test-catalog-scope-fallback.sh
  - Makefile
autonomous: true
requirements:
  - SCOPE-03
  - TEST-06

must_haves:
  truths:
    - "Catalog validator's SCOPE-01 enforcement is locked behind both positive (shipped catalog passes) and negative (synthetic catalog fails) test assertions"
    - "Backward-compat loader fallback (D-09 / D-11 silent contract) is locked behind a hermetic test that asserts MCP_DEFAULT_SCOPE='user' on missing field AND zero bytes on stderr"
    - "Existing v4.9 baselines stay green: test-mcp-selector.sh PASS=21 unchanged; test-integrations-catalog.sh PASS rises from 14 to 17 with A15/A16/A17 (still satisfies the D-12 PASS≥10 floor)"
    - "make check invokes both the extended validator and the new tests via the existing Makefile chain — schema violations and fallback regressions both fail the build"
  artifacts:
    - path: "scripts/tests/test-integrations-catalog.sh"
      provides: "Three new _pyq assertions A15/A16/A17 that lock SCOPE-01 + SCOPE-02 grid spot-checks"
      contains: "A15: every MCP entry has default_scope"
    - path: "scripts/tests/test-catalog-scope-fallback.sh"
      provides: "Hermetic Bash test exercising D-09/D-11 silent-fallback contract + TEST-06 negative validator cases"
      contains: "BC1: catalog missing default_scope"
    - path: "Makefile"
      provides: "Wires test-catalog-scope-fallback.sh into the test: target chain"
      contains: "test-catalog-scope-fallback.sh"
  key_links:
    - from: "scripts/tests/test-integrations-catalog.sh"
      to: "scripts/lib/integrations-catalog.json"
      via: "_pyq helper (lines 67-86) — Python json.load on shipped catalog"
      pattern: '_pyq "A1[5-7]:'
    - from: "scripts/tests/test-catalog-scope-fallback.sh"
      to: "scripts/lib/mcp.sh::mcp_catalog_load"
      via: "subshell `bash -c` with TK_MCP_CATALOG_PATH override + 2>stderr capture"
      pattern: 'TK_MCP_CATALOG_PATH=.*mcp_catalog_load'
    - from: "scripts/tests/test-catalog-scope-fallback.sh"
      to: "scripts/validate-integrations-catalog.py"
      via: "python3 path-override seam (validator lines 81-85)"
      pattern: 'validate-integrations-catalog.py.*\.json'
    - from: "Makefile"
      to: "scripts/tests/test-catalog-scope-fallback.sh"
      via: "test: target + standalone test-catalog-scope-fallback target"
      pattern: 'Test 48: catalog default_scope fallback'
---

<objective>
Lock the Plan 01 contracts behind hermetic, idempotent test assertions: extend `test-integrations-catalog.sh` with three new `_pyq` assertions (A15: every MCP has `default_scope` ∈ {user,project} — TEST-06 positive enforcement; A16/A17: SCOPE-02 grid spot-checks for the personal/infra split), create a new sibling `test-catalog-scope-fallback.sh` covering the D-09/D-11 silent-fallback loader contract plus the TEST-06 negative validator cases, and wire the new test into `Makefile`'s `test:` target.

Purpose: Plan 01 ships the schema, validator extension, and loader fallback in a single commit (D-10). Plan 02 makes the contract regression-locked. Without these tests, Phase 38 (wizard dispatch) and Phase 39 (TUI per-row toggle) would have no way to detect a future regression where someone reverts the silent-fallback or the SCOPE-02 grid drifts. With these tests, `make check && make test` becomes the gate.

Output: 3 new `_pyq` assertions in an existing file + 1 new ~150-line hermetic Bash test file + 2 new Makefile lines (test entry + standalone target). No new Python deps, no `bats`/`shunit2`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/36-catalog-schema-backward-compat/36-CONTEXT.md
@.planning/phases/36-catalog-schema-backward-compat/36-RESEARCH.md
@.planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md
@.planning/phases/36-catalog-schema-backward-compat/36-VALIDATION.md
@.planning/phases/36-catalog-schema-backward-compat/36-01-foundation-PLAN.md
@scripts/tests/test-integrations-catalog.sh
@scripts/tests/test-mcp-selector.sh
@scripts/lib/mcp.sh
@scripts/validate-integrations-catalog.py
@scripts/lib/integrations-catalog.json
@Makefile

<interfaces>
<!-- Key contracts the executor needs. Extracted from PATTERNS.md. -->

### `_pyq` helper (test-integrations-catalog.sh lines 67-86, verbatim)

```bash
_pyq() {
    local label="$1"
    shift
    local script="$1"
    local out
    out=$(python3 - "$CATALOG" <<PY 2>&1
import json, sys
catalog_path = sys.argv[1]
with open(catalog_path, "r", encoding="utf-8") as fh:
    catalog = json.load(fh)
$script
PY
    ) || true
    if [[ "$out" == "OK" ]]; then
        assert_pass "$label"
    else
        assert_fail "$label" "$out"
    fi
}
```

`$CATALOG` is set at line 27 to `${REPO_ROOT}/scripts/lib/integrations-catalog.json`. The helper's stdout-`OK` contract is what every `_pyq` invocation must satisfy.

### Assertion counters + exit pattern (test-integrations-catalog.sh lines 33-42 + 274-276)

```bash
PASS=0
FAIL=0
assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
# ... at end:
echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

### Synthetic-catalog harness pattern (test-mcp-selector.sh lines 64-86 + 111-117)

```bash
run_s1_catalog_correctness() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    ...
}

# Subshell + stderr capture pattern:
local rc=0
TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" bash -c "
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    is_mcp_installed context7
    exit \$?
" 2>/dev/null || rc=$?
```

### Validator path-override seam (validate-integrations-catalog.py lines 81-85)

```python
catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG_PATH
```

→ Negative-case tests pass `python3 scripts/validate-integrations-catalog.py "$SANDBOX/bad.json"` and assert non-zero exit + stderr containing `default_scope`.

### Loader test seam (mcp.sh line 33 + line 79)

```bash
#   TK_MCP_CATALOG_PATH        — override path to mcp-catalog.json (mocked in tests)
local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
```

### Makefile test target (lines 215-222 — verbatim)

```makefile
	@echo "Test 47: integrations TUI redesign (TEST-03 — Phase 35)"
	@bash scripts/tests/test-integrations-tui.sh
	@echo ""
	@echo "All tests passed!"
```

`@echo "All tests passed!"` is the LAST line of the recipe. New "Test 48:" entries must be inserted IMMEDIATELY BEFORE the trailing `@echo ""` + `@echo "All tests passed!"` lines.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add A15/A16/A17 _pyq assertions to test-integrations-catalog.sh (TEST-06 positive + SCOPE-02 grid)</name>
  <files>scripts/tests/test-integrations-catalog.sh</files>
  <read_first>
    - scripts/tests/test-integrations-catalog.sh (the file being modified — read all 276 lines: boilerplate at lines 23-42, `_pyq` helper at lines 67-86, A6 "every MCP entry has all required keys" at lines 130-143 as the analog, A14 last existing assertion, exit pattern at lines 274-276)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog: A15/A16/A17 verbatim diffs at lines 368-410)
    - scripts/lib/integrations-catalog.json (the catalog `_pyq` reads — confirm post-Plan-01 state has all 20 entries with `default_scope`)
  </read_first>
  <behavior>
    - Running `bash scripts/tests/test-integrations-catalog.sh` against the post-Plan-01 catalog MUST exit 0 with PASS=17 and FAIL=0 (existing 14 + new A15+A16+A17).
    - A15 MUST iterate every entry in `components.mcp.*` and fail if any entry's `default_scope` is not in the set `{"user", "project"}` (catches missing field via `entry.get("default_scope")` returning `None`, AND catches invalid enums).
    - A16 MUST assert that `aws-cloudwatch-logs.default_scope == "project"` (D-07 grid spot-check).
    - A17 MUST assert that `context7.default_scope == "user"` (D-06 grid spot-check).
    - All three new assertions follow the `_pyq` contract: stdout exactly `OK` on pass; on fail, stdout contains a diagnostic message that is shown via `assert_fail`.
  </behavior>
  <action>
    Edit `scripts/tests/test-integrations-catalog.sh` to insert three new `_pyq` blocks AFTER the existing A14 assertion (find it by `grep -n 'A14' scripts/tests/test-integrations-catalog.sh`) and BEFORE the trailing `echo ""` + `Result: PASS=$PASS FAIL=$FAIL` lines (currently around lines 273-276).

    Mirror the A6 style verbatim (lines 130-143 — the closest analog because A6 is also "every MCP entry must have <key>"). Use `# ─────...─────` separators identical to existing assertions.

    Insert exactly this block (verbatim from PATTERNS.md lines 368-410):

    ```bash
    # ─────────────────────────────────────────────────
    # A15 — every MCP entry has default_scope ∈ {"user","project"} (SCOPE-01 / TEST-06)
    # ─────────────────────────────────────────────────
    _pyq "A15: every MCP entry has default_scope in {user, project}" '
    mcp = catalog.get("components", {}).get("mcp", {})
    errors = []
    for name, entry in mcp.items():
        ds = entry.get("default_scope")
        if ds not in ("user", "project"):
            errors.append((name, ds))
    if not errors:
        print("OK")
    else:
        print("entries with bad default_scope: " + repr(errors))
    '

    # ─────────────────────────────────────────────────
    # A16 — SCOPE-02 grid spot-check: known infra MCP defaults to project (D-07)
    # ─────────────────────────────────────────────────
    _pyq "A16: aws-cloudwatch-logs default_scope is project (D-07)" '
    ds = catalog.get("components", {}).get("mcp", {}).get("aws-cloudwatch-logs", {}).get("default_scope")
    if ds == "project":
        print("OK")
    else:
        print("aws-cloudwatch-logs default_scope is " + repr(ds) + ", expected project")
    '

    # ─────────────────────────────────────────────────
    # A17 — SCOPE-02 grid spot-check: known personal MCP defaults to user (D-06)
    # ─────────────────────────────────────────────────
    _pyq "A17: context7 default_scope is user (D-06)" '
    ds = catalog.get("components", {}).get("mcp", {}).get("context7", {}).get("default_scope")
    if ds == "user":
        print("OK")
    else:
        print("context7 default_scope is " + repr(ds) + ", expected user")
    '
    ```

    Do NOT modify any of the existing A1-A14 assertions. Do NOT modify the `_pyq` helper or the boilerplate. Do NOT add the standalone `Result: PASS=...` echo more than once (it should still be only at the bottom of the file).

    Indentation: NO leading indent on the `_pyq "..." '...'` block (these are top-level shell statements, matching A1-A14 verbatim).
  </action>
  <verify>
    <automated>
      bash -n scripts/tests/test-integrations-catalog.sh
      shellcheck -S warning scripts/tests/test-integrations-catalog.sh
      OUT=$(bash scripts/tests/test-integrations-catalog.sh)
      echo "$OUT" | tail -3
      echo "$OUT" | grep -q '^Result: PASS=17 FAIL=0$'
    </automated>
  </verify>
  <acceptance_criteria>
    - `bash -n scripts/tests/test-integrations-catalog.sh` exits 0.
    - `shellcheck -S warning scripts/tests/test-integrations-catalog.sh` exits 0.
    - `bash scripts/tests/test-integrations-catalog.sh` exits 0.
    - The final line of stdout is exactly `Result: PASS=17 FAIL=0` (was `PASS=14 FAIL=0` pre-Plan-02).
    - `grep -c 'A15:' scripts/tests/test-integrations-catalog.sh` returns exactly `1`.
    - `grep -c 'A16:' scripts/tests/test-integrations-catalog.sh` returns exactly `1`.
    - `grep -c 'A17:' scripts/tests/test-integrations-catalog.sh` returns exactly `1`.
    - `grep -n 'A1[5-7]:' scripts/tests/test-integrations-catalog.sh` shows all three after the A14 line.
    - D-12 invariant: PASS count is `17 ≥ 10` (the documented floor).
    - The PASS=21 baseline of `bash scripts/tests/test-mcp-selector.sh` is verified as unchanged in Task 4 of this plan.
  </acceptance_criteria>
  <done>
    A15 (universal SCOPE-01 enforcement on shipped catalog), A16 (project-side grid spot-check), A17 (user-side grid spot-check) are wired and green; PASS=17 FAIL=0; no other assertion regressed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create scripts/tests/test-catalog-scope-fallback.sh (D-14 silent-fallback + TEST-06 negative cases)</name>
  <files>scripts/tests/test-catalog-scope-fallback.sh</files>
  <read_first>
    - scripts/tests/test-mcp-selector.sh (the synthetic-catalog harness analog — read lines 1-170 paying attention to: boilerplate at lines 1-50, `run_s1_catalog_correctness` synthetic-sandbox at lines 64-86, `bash -c "source ...; ..."` subshell + stderr-capture at lines 111-117, heredoc usage at lines 101-108)
    - scripts/tests/test-integrations-catalog.sh (assertion counter pattern at lines 33-42, exit pattern at lines 274-276)
    - scripts/lib/mcp.sh (line 33 — `TK_MCP_CATALOG_PATH` test-seam declaration; line 79 — resolution; lines 78-161 — `mcp_catalog_load` body)
    - scripts/validate-integrations-catalog.py (lines 81-85 — path-override seam used by negative-case tests)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog excerpts at lines 422-718)
    - .planning/phases/36-catalog-schema-backward-compat/36-RESEARCH.md (Wave 0 Gaps at lines 881-885)
  </read_first>
  <behavior>
    - The new test file is hermetic: zero shell-out to `claude`, `brew`, network, or any external service. Every catalog used is written to a `mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX` sandbox and torn down on RETURN.
    - The file MUST cover four scenarios:
      1. **BC1 — silent-fallback contract (D-09 + D-11):** synthetic catalog with one entry having `default_scope: "project"` AND another entry omitting `default_scope` entirely. Loader returns 0; `MCP_DEFAULT_SCOPE[<missing entry idx>] == "user"`; `MCP_DEFAULT_SCOPE[<present entry idx>] == "project"`; captured stderr is byte-zero.
      2. **BC2 — validator rejects missing field (TEST-06 negative):** synthetic catalog where every MCP entry omits `default_scope`. Validator exits non-zero; stderr contains the substring `default_scope`.
      3. **BC3 — validator accepts valid enum values (TEST-06 positive on synthetic):** synthetic catalog where two MCP entries have `default_scope: "user"` and `default_scope: "project"` respectively. Validator exits 0.
      4. **BC4 — validator rejects invalid enum values:** synthetic catalog with `default_scope: "global"`. Validator exits non-zero; stderr contains `default_scope` (and the invalid value's repr).
    - All four scenarios use the patterns from PATTERNS.md verbatim (lines 422-718). Use `<<'JSON'` (single-quoted heredoc) to avoid `$` expansion inside synthetic catalog literals.
    - Bash 3.2 compat: NO `mapfile`, NO `declare -A`, NO `${var,,}`, NO `read -N`, NO `read -t` with floats, NO `declare -n`.
    - File MUST be executable (`chmod +x` after creation) — matches the existing test files (`test-integrations-catalog.sh` and `test-mcp-selector.sh` are executable per `ls -l scripts/tests/`).
  </behavior>
  <action>
    Create `scripts/tests/test-catalog-scope-fallback.sh` from scratch using the PATTERNS.md proposal at lines 422-718 verbatim as the starting point. Specifically write the following structure (full file content — substitute REPO_ROOT properly):

    1. Shebang + comment header (lines 1-15 of the proposed body in PATTERNS.md):
       - `#!/usr/bin/env bash`
       - Description block referencing Phase 36 / SCOPE-03 / D-14 contract
       - `set -euo pipefail` (Bash safety per CLAUDE.md)

    2. Globals block:
       - `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
       - `REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"`
       - Color constants (RED, GREEN, NC) and `PASS=0 FAIL=0` matching test-integrations-catalog.sh:23-42 verbatim.
       - The same `assert_pass`, `assert_fail`, `assert_eq` helpers verbatim.

    3. Four scenario functions (verbatim from PATTERNS.md lines 489-693):
       - `run_bc1_silent_fallback_to_user` — synthetic catalog with `withscope` (default_scope=project) + `noscope` (no default_scope). Use `mktemp -d` + `trap "rm -rf '${SANDBOX:?}'" RETURN`. `bash -c "source '${REPO_ROOT}/scripts/lib/mcp.sh'; mcp_catalog_load; ..."` with `TK_MCP_CATALOG_PATH=$SANDBOX/synth-catalog.json`. Capture stdout AND stderr separately. Assert (a) rc=0, (b) `noscope=user` in stdout, (c) `withscope=project` in stdout, (d) `wc -c < $stderr_tmp` returns 0.
       - `run_bc2_validator_rejects_missing_field` — synthetic catalog with one entry lacking `default_scope`. `python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/bad-catalog.json"` with stderr capture. Assert (a) rc != 0, (b) stderr contains literal `default_scope` (use `grep -q "default_scope"`).
       - `run_bc3_validator_accepts_valid_enum` — synthetic catalog with both `user` and `project` values. Assert validator rc=0.
       - `run_bc4_validator_rejects_invalid_enum` — synthetic catalog with `default_scope: "global"`. Assert (a) rc != 0, (b) stderr contains literal `default_scope`.

    4. Driver:
       - `echo "test-catalog-scope-fallback.sh: Phase 36 D-14 silent-fallback contract"` then blank line.
       - Call all four functions in order: `run_bc1_silent_fallback_to_user; run_bc2_validator_rejects_missing_field; run_bc3_validator_accepts_valid_enum; run_bc4_validator_rejects_invalid_enum`.

    5. Exit pattern (lines 700-702 of PATTERNS.md proposal):
       - `echo ""`
       - `echo "Result: PASS=$PASS FAIL=$FAIL"`
       - `[[ "$FAIL" -eq 0 ]]`

    Critical mechanics:
    - Use `<<'JSON'` (with single quotes) for every synthetic JSON heredoc — prevents `$KEY` expansion inside the JSON literal.
    - Use `bash -c "source '${REPO_ROOT}/scripts/lib/mcp.sh'; ..."` for each scenario so each gets a fresh subshell (Bash 3.2 has no easy way to clear MCP_* arrays in-process).
    - Inside the `bash -c` string, escape inner double-quotes as `\"` and inner `${var}` as `\${var}` to defer expansion to the subshell.
    - Wrap the loader call so `set -euo pipefail` doesn't kill the test on legitimate failures: capture rc with `|| rc=$?` after the closing fence.
    - For BC1 stdout parsing, use `grep '^noscope=' "$stdout_tmp" | head -1 | cut -d= -f2` (POSIX-portable; works on BSD `head`/`grep`).
    - For BC1 stderr-byte-zero check, use `wc -c < "$stderr_tmp" | tr -d ' '` (avoids variable filename in `wc` output across BSD/GNU differences).

    After creating the file: `chmod +x scripts/tests/test-catalog-scope-fallback.sh`.

    Do NOT extend `test-integrations-catalog.sh` with the synthetic-catalog harness — discretion D-14 is resolved in favor of a sibling file (PATTERNS.md "Match Quality: exact (synthetic-catalog harness pattern)" — keeps the `_pyq`-only style of test-integrations-catalog.sh intact).
  </action>
  <verify>
    <automated>
      bash -n scripts/tests/test-catalog-scope-fallback.sh
      shellcheck -S warning scripts/tests/test-catalog-scope-fallback.sh
      [ -x scripts/tests/test-catalog-scope-fallback.sh ] || { echo "not executable"; exit 1; }
      OUT=$(bash scripts/tests/test-catalog-scope-fallback.sh)
      RC=$?
      echo "$OUT" | tail -3
      [ "$RC" = "0" ] || { echo "rc=$RC"; exit 1; }
      echo "$OUT" | grep -q '^Result: PASS=' || { echo "no Result line"; exit 1; }
      echo "$OUT" | grep -q 'FAIL=0$' || { echo "FAIL!=0"; exit 1; }
      # Spot-check assertion labels are present.
      echo "$OUT" | grep -q 'BC1.*missing default_scope' || { echo "BC1 label missing"; exit 1; }
      echo "$OUT" | grep -q 'BC2.*validator exits non-zero on catalog missing default_scope' || { echo "BC2 label missing"; exit 1; }
      echo "$OUT" | grep -q 'BC3.*validator exits 0 on synthetic catalog with valid default_scope' || { echo "BC3 label missing"; exit 1; }
      echo "$OUT" | grep -q 'BC4.*validator exits non-zero on invalid enum value' || { echo "BC4 label missing"; exit 1; }
    </automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/tests/test-catalog-scope-fallback.sh` exists and is executable (`-rwxr-xr-x` mode).
    - `bash -n scripts/tests/test-catalog-scope-fallback.sh` exits 0.
    - `shellcheck -S warning scripts/tests/test-catalog-scope-fallback.sh` exits 0.
    - `bash scripts/tests/test-catalog-scope-fallback.sh` exits 0.
    - Final stdout line matches `Result: PASS=N FAIL=0` where N ≥ 7 (BC1 has 4 assertions; BC2 has 2; BC3 has 1; BC4 has 2 → minimum PASS=9, but the planner-floor is N ≥ 7 to permit minor wording adjustments while preserving coverage).
    - Output includes labels "BC1", "BC2", "BC3", "BC4" matching the four scenarios.
    - `grep -c 'mktemp -d /tmp/test-catalog-scope-fallback' scripts/tests/test-catalog-scope-fallback.sh` returns at least 4 (one per scenario, all using sandboxed temp dirs).
    - `grep -c 'TK_MCP_CATALOG_PATH=' scripts/tests/test-catalog-scope-fallback.sh` returns at least 1 (BC1 uses the loader test seam).
    - `grep -c '<<'\''JSON'\''' scripts/tests/test-catalog-scope-fallback.sh` returns at least 4 (single-quoted heredocs prevent `$` expansion).
    - `grep -E 'mapfile|declare -A|\$\{[a-zA-Z_]+,,\}|read -N |declare -n' scripts/tests/test-catalog-scope-fallback.sh` returns no matches (Bash 3.2 compat invariant).
    - `set -euo pipefail` appears within the first 25 lines of the file.
    - Stderr-empty assertion exists for BC1 (search for `wc -c.*stderr` or `[ ! -s.*stderr` patterns).
  </acceptance_criteria>
  <done>
    Sibling test file lands; all four scenarios green; D-09 silent contract + D-11 zero-stderr + TEST-06 missing/valid/invalid enum negative cases all locked.
  </done>
</task>

<task type="auto">
  <name>Task 3: Wire test-catalog-scope-fallback.sh into Makefile (test target + standalone target + .PHONY)</name>
  <files>Makefile</files>
  <read_first>
    - Makefile (the file being modified — read all 450 lines, paying attention to: `.PHONY` declaration at line 1; `check:` target chain at line 19; `test:` target body around lines 71-224 with each "Test NN:" entry; the trailing `@echo "All tests passed!"` line; existing standalone test targets like `test-integrations-catalog`, `test-mcp-selector`, `test-integrations-tui` around lines 250-260; `validate-catalog` target at lines 415-417)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog: Makefile-wiring excerpts at lines 720-769)
  </read_first>
  <action>
    Make three edits to `Makefile`. All edits are surgical insertions; no removal of existing lines.

    Edit 1 — extend `test:` target with a "Test 48:" entry. Find the existing "Test 47:" block (around lines 219-222) which currently looks exactly like:

    ```makefile
    	@echo "Test 47: integrations TUI redesign (TEST-03 — Phase 35)"
    	@bash scripts/tests/test-integrations-tui.sh
    	@echo ""
    	@echo "All tests passed!"
    ```

    Insert the following two lines IMMEDIATELY BEFORE the `@echo ""` line (the one that precedes `All tests passed!`):

    ```makefile
    	@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"
    	@bash scripts/tests/test-catalog-scope-fallback.sh
    ```

    Result after edit:

    ```makefile
    	@echo "Test 47: integrations TUI redesign (TEST-03 — Phase 35)"
    	@bash scripts/tests/test-integrations-tui.sh
    	@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"
    	@bash scripts/tests/test-catalog-scope-fallback.sh
    	@echo ""
    	@echo "All tests passed!"
    ```

    Use TAB (not spaces) for the recipe indent — Makefile syntax requires it. Match the indent of the existing lines exactly (read them first to confirm the leading character is a literal tab).

    Edit 2 — add a standalone target near the existing per-test standalone targets (around lines 250-260, after the `test-integrations-tui` target if it exists; otherwise append after the last `test-*` standalone target). Insert:

    ```makefile
    # Test 48 — catalog default_scope fallback (Phase 36 / SCOPE-03), invokable standalone.
    test-catalog-scope-fallback:
    	@bash scripts/tests/test-catalog-scope-fallback.sh
    ```

    Edit 3 — add `test-catalog-scope-fallback` to the `.PHONY` declaration at line 1 (or wherever the master `.PHONY` line lives — confirm by `grep -n '^.PHONY:' Makefile`). Append the new name to the existing space-separated list. Do NOT introduce a second `.PHONY` line.

    Do NOT modify `check:` (line 19). Do NOT touch `validate-catalog` (line 415-417). Do NOT bump the manifest version. Do NOT alter any other test target.
  </action>
  <verify>
    <automated>
      # Syntax check — Makefile must still parse.
      make -n test >/dev/null
      # Test 48 entry must appear in the test target's recipe.
      grep -q 'Test 48: catalog default_scope fallback' Makefile
      grep -q 'bash scripts/tests/test-catalog-scope-fallback.sh' Makefile
      # Standalone target must be invokable.
      make -n test-catalog-scope-fallback >/dev/null
      # .PHONY must list the new name.
      grep -E '^\.PHONY:.*test-catalog-scope-fallback' Makefile
      # The "All tests passed!" line must still be the LAST line of the test recipe.
      awk '/^test:/,/^[a-zA-Z]/' Makefile | grep -q 'All tests passed!'
    </automated>
  </verify>
  <acceptance_criteria>
    - `make -n test` exits 0 (syntactic dry-run shows the test recipe is valid).
    - `make -n test-catalog-scope-fallback` exits 0 (standalone target exists and parses).
    - `grep -c 'test-catalog-scope-fallback.sh' Makefile` returns exactly `2` (one in the `test:` recipe, one in the standalone target body).
    - `grep -c 'Test 48: catalog default_scope fallback' Makefile` returns exactly `1`.
    - `grep -E '^\.PHONY:' Makefile` line includes the literal token `test-catalog-scope-fallback`.
    - The `check:` target body (Makefile line 19) is byte-identical to the pre-edit state — no new entries added (Plan 02 only wires `test:`, not `check:`).
    - The `version-align` target stays green: `make version-align` exits 0 (we did NOT bump manifest.json — D-08).
    - Recipe indentation uses literal TAB characters (verify with `cat -A Makefile | grep -A1 'Test 48' | head -2` showing `^I` prefix on the recipe lines).
    - No existing `Test 1:` through `Test 47:` echo line was reordered or removed (verify with `grep -c 'Test [0-9]' Makefile` returning the pre-edit count + 1).
  </acceptance_criteria>
  <done>
    Makefile wires the new sibling test into both `make test` (via Test 48 entry) and standalone invocation (`make test-catalog-scope-fallback`); `.PHONY` declares the new target; no regression on `make check` chain.
  </done>
</task>

<task type="auto">
  <name>Task 4: Verify v4.9 baselines stay green and full quality gate passes (D-12 invariant)</name>
  <files></files>
  <read_first>
    - .planning/phases/36-catalog-schema-backward-compat/36-CONTEXT.md (D-12 baseline contract: test-mcp-selector.sh PASS=21, test-integrations-catalog.sh PASS≥10)
    - .planning/phases/36-catalog-schema-backward-compat/36-VALIDATION.md (Sampling Rate at lines 28-34)
  </read_first>
  <action>
    No file edits. This is a verification-only task that ensures the Plan 01 + Plan 02 changes did not regress the v4.9 baselines.

    Steps:

    1. Run `bash scripts/tests/test-mcp-selector.sh` and confirm final line is exactly `Result: PASS=21 FAIL=0` (D-12 baseline — must be UNCHANGED, not just ≥21). Phase 36 makes no changes to selector behavior; if PASS drifts, something in Plan 01's loader edits broke an unrelated assertion.

    2. Run `bash scripts/tests/test-integrations-catalog.sh` and confirm final line is exactly `Result: PASS=17 FAIL=0` (was 14 pre-Plan-02; gained A15+A16+A17). Confirm 17 ≥ 10 (D-12 floor satisfied).

    3. Run `bash scripts/tests/test-catalog-scope-fallback.sh` and confirm final line matches `Result: PASS=N FAIL=0` for N ≥ 7.

    4. Run `python3 scripts/validate-integrations-catalog.py` and confirm exit 0 with empty stdout/stderr against the shipped catalog.

    5. Run `make check` and confirm exit 0. This invokes the full quality gate: shellcheck + markdownlint + validate + validate-base-plugins + version-align + translation-drift + agent-collision-static + validate-commands + validate-catalog + validate-mdlint-config-sync + validate-skills-desktop + validate-marketplace + cell-parity. The `version-align` target is the canary — if `manifest.json` was accidentally bumped to 5.0.0 in either plan, this fails (D-08 deferred to Phase 41).

    6. Run `make test` and confirm exit 0. This invokes all 48 numbered tests including the new Test 48.

    If any step fails, the failure is a regression introduced by Plan 01 or Plan 02; fix the regression in the relevant prior task before re-attempting Task 4.

    Do NOT introduce any additional commits, file edits, or workarounds in this task. Its sole purpose is to gate the phase on the D-12 invariant and the full `make check && make test` chain.
  </action>
  <verify>
    <automated>
      # 1. Selector baseline UNCHANGED.
      OUT=$(bash scripts/tests/test-mcp-selector.sh) && echo "$OUT" | grep -q '^Result: PASS=21 FAIL=0$' || { echo "selector baseline drifted"; exit 1; }
      # 2. Catalog tests gained 3 assertions, FAIL=0.
      OUT=$(bash scripts/tests/test-integrations-catalog.sh) && echo "$OUT" | grep -q '^Result: PASS=17 FAIL=0$' || { echo "integrations-catalog test count drifted"; exit 1; }
      # 3. New fallback test green.
      OUT=$(bash scripts/tests/test-catalog-scope-fallback.sh) && echo "$OUT" | grep -E '^Result: PASS=[0-9]+ FAIL=0$' || { echo "fallback test red"; exit 1; }
      # 4. Validator exits 0 on shipped catalog.
      python3 scripts/validate-integrations-catalog.py
      # 5. Full quality gate.
      make check
      # 6. Full test chain.
      make test
    </automated>
  </verify>
  <acceptance_criteria>
    - `bash scripts/tests/test-mcp-selector.sh` ends with literal line `Result: PASS=21 FAIL=0` (D-12 — exact match, not just ≥21; this is the canary that detects loader-induced regression).
    - `bash scripts/tests/test-integrations-catalog.sh` ends with literal line `Result: PASS=17 FAIL=0` (was 14, gained A15/A16/A17 = +3).
    - `bash scripts/tests/test-catalog-scope-fallback.sh` ends with `Result: PASS=N FAIL=0` for N ≥ 7.
    - `python3 scripts/validate-integrations-catalog.py` exits 0 with empty stderr.
    - `make check` exits 0 (full quality gate: lint, validate, version-align, etc.).
    - `make test` exits 0 (48-numbered test chain green end-to-end).
    - `manifest.json` `"version"` field is UNCHANGED from its pre-Phase-36 value (D-08 — version bump deferred to Phase 41); confirm with `grep '"version":' manifest.json | head -1`.
    - `CHANGELOG.md` is UNCHANGED in this phase (D-08 — Phase 41 owns the [5.0.0] consolidated entry).
  </acceptance_criteria>
  <done>
    All D-12 baselines hold; full `make check && make test` chain green; Phase 36 ready for `/gsd-verify-work`.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| developer machine → /tmp sandbox | Each test scenario writes synthetic JSON to a `mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX` directory. Tests do NOT touch repo-tracked files. |
| test → loader subshell | Each scenario uses `bash -c` with `TK_MCP_CATALOG_PATH=$SANDBOX/...` to point the loader at synthetic catalogs — fresh shell per scenario, no shared state. |
| test → validator subprocess | Each negative-case scenario invokes `python3 scripts/validate-integrations-catalog.py "$SANDBOX/bad.json"` via the validator's path-override seam (validator lines 81-85). |

**Note (per planning_context):** No external input surface — tests are repo-owned, run on developer/CI machines, ingest no untrusted data. Synthetic catalogs are written by the tests themselves to /tmp sandboxes.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-36-05 | Denial of Service | scripts/tests/test-catalog-scope-fallback.sh | mitigate | `mktemp -d` + `trap "rm -rf '${SANDBOX:?}'" RETURN` ensures every sandbox is cleaned up even if `set -euo pipefail` aborts mid-scenario. The `${SANDBOX:?}` expansion fails the trap rather than running `rm -rf ''` if SANDBOX is unset. Severity: low. |
| T-36-06 | Tampering | /tmp synthetic catalogs | accept | Synthetic catalogs are written by the test itself with `cat <<'JSON' > "$SANDBOX/synth.json"`; single-quoted heredoc prevents shell expansion of `$VARS` inside the JSON literal. The sandbox lives <1s; threat window is negligible on a developer machine. Severity: none. |
| T-36-07 | Elevation of Privilege | Makefile recipes | accept | New Makefile recipes invoke `bash scripts/tests/test-catalog-scope-fallback.sh` — no `sudo`, no curl-pipe-bash, no `eval`. Severity: none. |
| T-36-08 | Information Disclosure | test stderr/stdout | accept | Test output prints scenario labels and bad-value reprs (e.g., `'global'`); the test catalogs never contain secrets — only test-only public service metadata. Severity: none. |

**Aggregate:** No external input surface — catalog is repo-owned, validator runs on repo files, loader sources `mcp.sh` from a trusted location. Threat: malformed catalog corrupts loader behavior — mitigated by validator-fail-loud + silent-fallback-to-user. The new tests close the regression-detection gap. Severity: low.
</threat_model>

<verification>
- `bash scripts/tests/test-integrations-catalog.sh` exits 0 with `Result: PASS=17 FAIL=0`.
- `bash scripts/tests/test-catalog-scope-fallback.sh` exits 0 with `Result: PASS=N FAIL=0` for N ≥ 7.
- `bash scripts/tests/test-mcp-selector.sh` continues to exit 0 with `Result: PASS=21 FAIL=0` (D-12 invariant — UNCHANGED from v4.9 baseline).
- `python3 scripts/validate-integrations-catalog.py` exits 0 against the shipped catalog (post Plan 01).
- `make check` exits 0 (full lint + validate + version-align chain).
- `make test` exits 0 (48-numbered chain including the new Test 48).
- `make test-catalog-scope-fallback` exits 0 (new standalone target).
- `manifest.json` and `CHANGELOG.md` are byte-identical to their pre-Phase-36 state.
- `shellcheck -S warning scripts/tests/test-catalog-scope-fallback.sh` exits 0.
- `markdownlint-cli` rules for any new `.md` (none authored in this plan — only test scripts and Makefile).
</verification>

<success_criteria>
1. `scripts/tests/test-integrations-catalog.sh` gains exactly 3 new `_pyq` assertions (A15: every-MCP `default_scope` ∈ enum; A16: `aws-cloudwatch-logs == "project"`; A17: `context7 == "user"`) and now reports `PASS=17 FAIL=0` (TEST-06 positive enforcement satisfied at the meta-test layer).
2. `scripts/tests/test-catalog-scope-fallback.sh` is a new ~150-line hermetic Bash test file that runs four scenarios (BC1 silent-fallback, BC2 validator-rejects-missing, BC3 validator-accepts-valid, BC4 validator-rejects-invalid) and reports `PASS=N FAIL=0` for N ≥ 7. The file is executable, shellcheck-clean, Bash 3.2-compatible, and uses `mktemp -d` sandboxes that clean up on RETURN (D-09 + D-11 + TEST-06 negative all locked).
3. `Makefile` gains exactly two new test wiring sites: a "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)" entry inside the `test:` recipe (immediately before the trailing `@echo "All tests passed!"` line) AND a standalone `test-catalog-scope-fallback` target near the existing per-test standalones, with the new target name appended to `.PHONY`.
4. `bash scripts/tests/test-mcp-selector.sh` continues to report `Result: PASS=21 FAIL=0` (D-12 baseline — must be UNCHANGED, not just ≥21; canary for loader regressions).
5. `make check && make test` exits 0 end-to-end. The `version-align` sub-target stays green because neither plan touches `manifest.json` or `CHANGELOG.md` (D-08 — both deferred to Phase 41).
6. No deviation from the locked CONTEXT.md decisions: the sibling test file (D-14 discretion) is chosen over extending `test-integrations-catalog.sh`; the validator's enum-enforcement check (TEST-06) ships in Plan 01's validator extension and is now meta-tested at three layers (validator self-check, meta-test in `_pyq` assertion A15, hermetic synthetic-catalog test in BC2/BC3/BC4); silent-fallback contract (D-09/D-11) is locked behind BC1's stderr-byte-zero assertion.
</success_criteria>

<output>
After completion, create `.planning/phases/36-catalog-schema-backward-compat/36-02-SUMMARY.md` documenting:
- Final PASS counts for all three relevant test files (selector PASS=21 unchanged; integrations-catalog PASS=17; catalog-scope-fallback PASS=N for N≥7)
- The two Makefile insertion sites (Test 48 entry + standalone target + `.PHONY` extension)
- Confirmation that `make check && make test` exits 0
- Confirmation that `manifest.json` and `CHANGELOG.md` are UNCHANGED (D-08 invariant)
- Pointer to phase-close: `/gsd-verify-work 36`
</output>
