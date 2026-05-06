---
phase: 37-project-secrets-library
plan: 02
type: execute
wave: 2
depends_on:
  - 37-01-secrets-lib-PLAN
files_modified:
  - scripts/tests/test-project-secrets.sh
  - Makefile
  - .github/workflows/quality.yml
autonomous: true
requirements:
  - TEST-01
must_haves:
  truths:
    - "scripts/tests/test-project-secrets.sh exists and is executable via `bash`"
    - "Running the test exits 0 and prints `=== Results: N passed, 0 failed ===` with N ≥ 18"
    - "Test exercises 0600 mode (BSD + GNU stat dual-check) on first write and after collision rewrite"
    - "Test exercises collision N preserves existing value and collision Y overwrites via TK_MCP_TTY_SRC seam"
    - "Test exercises SEC-06 metacharacter rejection on $, backtick, backslash, double-quote, single-quote, newline (≥ 6 assertions)"
    - "Test exercises gitignore append + idempotent no-op + false-negative on *.env + false-negative on `# .env`"
    - "Test exercises render: empty args → {} (no trailing newline), two keys → exact `{\"K1\":\"${K1}\",\"K2\":\"${K2}\"}` form, invalid key → rc=1"
    - "Test exercises validate: literal value → rc=1 with stderr phrase, ${VAR} form → rc=0, TK_PROJECT_SECRETS_ALLOW_LITERAL=1 → rc=0 + stderr warning"
    - "make test runs the new test row and passes"
    - "CI quality.yml orphan-triage step invokes test-project-secrets.sh and the step name range is updated"
  artifacts:
    - path: "scripts/tests/test-project-secrets.sh"
      provides: "≥18-assertion hermetic, idempotent, double-run-safe test contract for SEC-01..06"
      contains: "assert_pass, assert_eq, assert_contains, mktemp -d /tmp/project-secrets.XXXXXX, source scripts/lib/project-secrets.sh"
    - path: "Makefile"
      provides: "Test 49 row in `test` target + standalone `test-project-secrets` target + .PHONY entry"
      contains: "test-project-secrets:"
    - path: ".github/workflows/quality.yml"
      provides: "CI invocation in the orphan-triage step + step-name range bump"
      contains: "bash scripts/tests/test-project-secrets.sh"
  key_links:
    - from: "scripts/tests/test-project-secrets.sh"
      to: "scripts/lib/project-secrets.sh"
      via: "source from REPO_ROOT"
      pattern: "source.*scripts/lib/project-secrets.sh"
    - from: "Makefile (test target)"
      to: "scripts/tests/test-project-secrets.sh"
      via: "@bash invocation"
      pattern: "bash scripts/tests/test-project-secrets.sh"
    - from: ".github/workflows/quality.yml (Tests 35-XX step)"
      to: "scripts/tests/test-project-secrets.sh"
      via: "bash invocation in step run block"
      pattern: "bash scripts/tests/test-project-secrets.sh"
---

<objective>
Lock the secrets boundary contract from plan 37-01 with a hermetic test suite of ≥ 18 assertions and wire it into both the local `make test` row and the CI `quality.yml` orphan-triage step. Without this plan, the lib is unverified and a regression to any of SEC-01..06 would ship silently.

Purpose: Make every clause of CONTEXT.md D-01..D-17 (and REQUIREMENTS.md SEC-01..06) grep-verifiable from a deterministic test that runs in < 5 seconds, idempotent + double-run-safe, with no `$HOME` mutation.

Output: Three modified files — one new test file plus surgical edits to `Makefile` and `.github/workflows/quality.yml`. After this plan lands, `make check` is the green gate Phase 38 inherits.
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
@.planning/phases/37-project-secrets-library/37-CONTEXT.md
@.planning/phases/37-project-secrets-library/37-PATTERNS.md
@.planning/phases/37-project-secrets-library/37-01-SUMMARY.md
@scripts/lib/project-secrets.sh
@scripts/tests/test-mcp-secrets.sh
@scripts/tests/test-mcp-wizard.sh
@Makefile
@.github/workflows/quality.yml

<interfaces>
<!-- Reusable test-harness contracts. Extracted from codebase. -->

From scripts/tests/test-mcp-secrets.sh:9-46 (hermetic preamble — copy verbatim, adjust prefix):
```bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq()       { ... }
assert_contains() { ... }
SANDBOX="$(mktemp -d /tmp/<prefix>.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
```

From scripts/tests/test-mcp-wizard.sh:37-46 (assert_not_contains — copy for negative assertions):
```bash
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_fail "$label" "pattern unexpectedly found: $pattern"
    else
        assert_pass "$label"
    fi
}
```

From scripts/tests/test-mcp-secrets.sh:60-68 (cross-platform mode-0600 check — copy verbatim):
```bash
mode_ok=0
if stat -f %Mp%Lp "$file" 2>/dev/null | grep -q "^0600$"; then mode_ok=1
elif [ "$(stat -c %a "$file" 2>/dev/null)" = "600" ]; then mode_ok=1; fi
assert_eq "1" "$mode_ok" "label"
```

From scripts/tests/test-mcp-secrets.sh:77-85 (TTY collision-prompt seam — copy + adapt):
```bash
TK_MCP_TTY_SRC=<(printf 'N\n') project_secrets_write_env "$PROJECT" KEY value 2>/dev/null || true
TK_MCP_TTY_SRC=<(printf 'y\n') project_secrets_write_env "$PROJECT" KEY value 2>/dev/null || true
```

From Makefile:200-204 (existing test row pattern — line 224 is currently `Test 48`, the new row becomes `Test 49`):
```makefile
@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"
@bash scripts/tests/test-catalog-scope-fallback.sh
@echo ""
```

From Makefile:241-243 (standalone target pattern):
```makefile
# Test 32 — MCP catalog + wizard + secrets (...), invokable standalone
test-mcp-selector:
    @bash scripts/tests/test-mcp-selector.sh
```

From .github/workflows/quality.yml:146-156 (orphan-triage step — extend in place):
```yaml
- name: Tests 35-43 — orphan triage (audit INF-MED-1) — backup/detect/mcp/dry-run suites previously absent from CI
  run: |
    bash scripts/tests/test-backup-lib.sh
    ...
    bash scripts/tests/test-update-dry-run.sh
```

From PATTERNS.md §"Required test coverage to hit ≥18 PASS" (lines 437-465 — 25-assertion menu; pick ≥ 18 + double-run wrapper):
- T01..T08 — write_env basics (existence, mode 0600, KEY=VALUE present, mode after rewrite, collision N, collision Y, key order preserved)
- T08..T13 — SEC-06 metacharacter rejection (`$`, backtick, backslash, double-quote, single-quote, newline)
- T14..T18 — gitignore (creates+0644, comment+`.env` lines, idempotent no-op, false-negative on `*.env`, false-negative on `# .env`)
- T19..T21 — render (empty→`{}`, two-key form, invalid-key rc=1)
- T22..T24 — validate (literal→rc=1+stderr, `${VAR}`→rc=0, `TK_PROJECT_SECRETS_ALLOW_LITERAL=1`→rc=0+warning)
- T25 — double-run idempotence wrapper
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Author scripts/tests/test-project-secrets.sh — ≥ 18 hermetic assertions</name>
  <files>scripts/tests/test-project-secrets.sh</files>

  <read_first>
    - scripts/lib/project-secrets.sh (the lib produced by 37-01 — confirm function names + stderr message strings before authoring matching assertions)
    - scripts/tests/test-mcp-secrets.sh (full file — lines 1-46 preamble, 60-68 stat dual-check, 70-75 metacharacter rejection, 77-85 TTY seam, 102-104 results footer)
    - scripts/tests/test-mcp-wizard.sh (lines 37-46 for `assert_not_contains`, lines 136-138 for tmpfile-vs-process-substitution TTY seam)
    - .planning/phases/37-project-secrets-library/37-CONTEXT.md (D-18..D-21 — test invariants: hermetic, idempotent, double-run-safe, mktemp -d, no $HOME mutation, trap cleanup)
    - .planning/phases/37-project-secrets-library/37-PATTERNS.md (lines 309-465 — the full test-harness adaptation guide including the 25-assertion menu)
  </read_first>

  <behavior>
    The test file is hermetic (no `$HOME` mutation, no real `~/.claude` touch), idempotent on re-run, and double-run-safe inside the same `$SANDBOX` (D-18, D-20). It sources `scripts/lib/project-secrets.sh` (which transitively sources `mcp.sh` and `tui.sh`) and exercises every clause of SEC-01..06 with concrete asserts that fail loudly when the contract drifts.

    Final stdout ends with the line `=== Results: <PASS> passed, 0 failed ===` and exits 0 when all assertions pass. Any failed assertion sets exit 1 and prints a `FAIL` line that names the assertion plus the expected vs actual values.

    Pass floor is 18 (D-18). Recommended target is ≥ 24 covering the full menu in PATTERNS.md lines 437-465.
  </behavior>

  <action>
    Create `scripts/tests/test-project-secrets.sh` (mode 0644 — bash invokes via `bash`, not via shebang execution):

    Section 1 — preamble. Copy `test-mcp-secrets.sh:1-46` verbatim with these surgical edits:
    - Line 2 header: `# test-project-secrets.sh — Phase 37 / TEST-01 contract (≥18 hermetic assertions covering SEC-01..06).`
    - `mktemp -d` prefix: `/tmp/project-secrets.XXXXXX` (not `/tmp/mcp-secrets.XXXXXX` — avoid collision under parallel `make test`).
    - DROP the `export TK_MCP_CONFIG_HOME="$SANDBOX"` line — this lib doesn't touch `~/.claude/mcp-config.env`. Setting `TK_MCP_CONFIG_HOME` would mask a regression where the lib accidentally writes outside `<project>/.env` (per PATTERNS.md §"Test-seam env-var naming" row 3).
    - DROP `mkdir -p "$SANDBOX/.claude"` (irrelevant for a project-root test).
    - ADD `PROJECT="$SANDBOX/myproj"` then `mkdir -p "$PROJECT"` so each test passes an absolute project root (D-06).
    - `source` line: `source "${REPO_ROOT}/scripts/lib/project-secrets.sh"` (transitively pulls in `mcp.sh` + `tui.sh`).
    - ADD `assert_not_contains` helper (copy from `test-mcp-wizard.sh:37-46`).

    Section 2 — assertions. Implement at minimum the following 24 (going past the 18-floor for safety):

    Block A — `project_secrets_write_env` basics (T1–T6, 6 asserts):
    ```bash
    # T1: write_env creates .env when absent
    project_secrets_write_env "$PROJECT" FOO bar
    [ -f "$PROJECT/.env" ] && assert_pass "T1: write_env creates .env" || assert_fail "T1: write_env creates .env" "missing"

    # T2: contents include exact KEY=VALUE line
    if grep -Fxq 'FOO=bar' "$PROJECT/.env"; then assert_pass "T2: KEY=VALUE line present"
    else assert_fail "T2: KEY=VALUE line present" "$(cat "$PROJECT/.env")"; fi

    # T3: mode 0600 (BSD+GNU stat dual-check) — copy from test-mcp-secrets.sh:60-68
    env_file="$PROJECT/.env"
    mode_ok=0
    if stat -f %Mp%Lp "$env_file" 2>/dev/null | grep -q "^0600$"; then mode_ok=1
    elif [ "$(stat -c %a "$env_file" 2>/dev/null)" = "600" ]; then mode_ok=1; fi
    assert_eq "1" "$mode_ok" "T3: .env mode is 0600 after first write"

    # T4: collision N preserves existing
    TK_MCP_TTY_SRC=<(printf 'N\n') project_secrets_write_env "$PROJECT" FOO new_value 2>/dev/null || true
    if grep -Fxq 'FOO=bar' "$PROJECT/.env"; then assert_pass "T4: collision N preserves existing"
    else assert_fail "T4: collision N preserves existing" "$(cat "$PROJECT/.env")"; fi

    # T5: collision Y overwrites
    TK_MCP_TTY_SRC=<(printf 'y\n') project_secrets_write_env "$PROJECT" FOO updated 2>/dev/null || true
    if grep -Fxq 'FOO=updated' "$PROJECT/.env"; then assert_pass "T5: collision Y overwrites"
    else assert_fail "T5: collision Y overwrites" "$(cat "$PROJECT/.env")"; fi

    # T6: mode 0600 still preserved after rewrite (D-04 step 8)
    mode_ok2=0
    if stat -f %Mp%Lp "$env_file" 2>/dev/null | grep -q "^0600$"; then mode_ok2=1
    elif [ "$(stat -c %a "$env_file" 2>/dev/null)" = "600" ]; then mode_ok2=1; fi
    assert_eq "1" "$mode_ok2" "T6: mode 0600 preserved after rewrite path"
    ```

    Block B — SEC-06 metacharacter rejection (T7–T12, 6 asserts). Each invocation must return non-zero AND emit the refusal phrase to stderr:
    ```bash
    # T7..T12: reject $, backtick, backslash, double-quote, single-quote, newline
    for pair in 'DOLLAR:val$inj' 'BTICK:val`inj' 'BSLASH:val\inj' 'DQUOTE:val"inj' "SQUOTE:val'inj"; do
        key="${pair%%:*}"; val="${pair#*:}"
        ERR="$(project_secrets_write_env "$PROJECT" "$key" "$val" 2>&1 1>/dev/null)" && \
            assert_fail "T?: reject $key metachar" "expected rc=1, got rc=0" || \
            assert_pass "T?: reject $key metachar"
        assert_contains "shell metacharacters" "$ERR" "T?: $key refusal stderr phrase"
    done
    # Newline rejection (separate — bash literal newline)
    ERR="$(project_secrets_write_env "$PROJECT" NL "$(printf 'a\nb')" 2>&1 1>/dev/null)" && \
        assert_fail "Tnl: reject newline" "expected rc=1" || assert_pass "Tnl: reject newline"
    ```
    Use distinct key names (`DOLLAR`, `BTICK`, `BSLASH`, `DQUOTE`, `SQUOTE`, `NL`) to avoid silent collisions with prior asserts. Number the asserts in the test labels accordingly (T7..T12 across 6 assertions; the stderr-phrase assertions can share numbers via `T7a/T7b` style or just be counted separately to push PASS over 18).

    Block C — `project_secrets_ensure_gitignore` (T13–T17, 5 asserts):
    ```bash
    # T13: creates .gitignore when absent
    GP="$SANDBOX/giproj"; mkdir -p "$GP"
    project_secrets_ensure_gitignore "$GP"
    [ -f "$GP/.gitignore" ] && assert_pass "T13: creates .gitignore" || assert_fail "T13: creates .gitignore" "missing"

    # T14: contains both the comment and .env line
    grep -Fxq '.env' "$GP/.gitignore" && assert_pass "T14: .env line present" || assert_fail "T14: .env line present" "$(cat "$GP/.gitignore")"
    grep -Fq 'claude-code-toolkit: never commit project-scope MCP secrets' "$GP/.gitignore" \
        && assert_pass "T14b: comment line present" || assert_fail "T14b: comment line present" "$(cat "$GP/.gitignore")"

    # T15: idempotent — second invocation does not duplicate the .env line
    project_secrets_ensure_gitignore "$GP"
    COUNT="$(grep -cFx '.env' "$GP/.gitignore")"
    assert_eq "1" "$COUNT" "T15: idempotent — exactly one .env line after re-run"

    # T16: false-negative on *.env — pre-seed *.env, ensure still appends .env
    GP2="$SANDBOX/giproj2"; mkdir -p "$GP2"; printf '*.env\n' > "$GP2/.gitignore"
    project_secrets_ensure_gitignore "$GP2"
    grep -Fxq '.env' "$GP2/.gitignore" && assert_pass "T16: *.env does not match exact .env" \
        || assert_fail "T16: *.env does not match exact .env" "$(cat "$GP2/.gitignore")"

    # T17: false-negative on `# .env` (comment) — pre-seed `# .env`, ensure still appends
    GP3="$SANDBOX/giproj3"; mkdir -p "$GP3"; printf '# .env\n' > "$GP3/.gitignore"
    project_secrets_ensure_gitignore "$GP3"
    grep -Fxq '.env' "$GP3/.gitignore" && assert_pass "T17: comment .env does not match exact .env" \
        || assert_fail "T17: comment .env does not match exact .env" "$(cat "$GP3/.gitignore")"
    ```

    Block D — `project_secrets_render_mcp_env_block` (T18–T20, 3 asserts):
    ```bash
    # T18: empty args → {} with no trailing newline
    OUT="$(project_secrets_render_mcp_env_block)"
    assert_eq '{}' "$OUT" "T18: empty render → {}"

    # T19: two keys → exact JSON form
    OUT="$(project_secrets_render_mcp_env_block FOO BAR)"
    assert_eq '{"FOO":"${FOO}","BAR":"${BAR}"}' "$OUT" "T19: two-key render exact form"

    # T20: invalid key (lowercase) → rc=1
    if project_secrets_render_mcp_env_block badkey 2>/dev/null; then
        assert_fail "T20: invalid key rc=1" "got rc=0"
    else
        assert_pass "T20: invalid key rc=1"
    fi
    ```

    Block E — `project_secrets_validate_mcp_env_block` (T21–T24, 4 asserts):
    ```bash
    # T21: literal value → rc=1 with refusal phrase
    ERR="$(project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>&1 1>/dev/null)" && \
        assert_fail "T21: literal → rc=1" "expected rc=1" || assert_pass "T21: literal → rc=1"
    assert_contains 'refusing to write literal value into .mcp.json' "$ERR" "T21b: refusal phrase in stderr"

    # T22: ${VAR} form → rc=0
    if project_secrets_validate_mcp_env_block '{"K":"${K}"}' 2>/dev/null; then
        assert_pass "T22: \${VAR} form rc=0"
    else
        assert_fail "T22: \${VAR} form rc=0" "expected rc=0"
    fi

    # T23: TK_PROJECT_SECRETS_ALLOW_LITERAL=1 bypasses → rc=0 with warning
    ERR="$(TK_PROJECT_SECRETS_ALLOW_LITERAL=1 project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>&1 1>/dev/null)"
    if TK_PROJECT_SECRETS_ALLOW_LITERAL=1 project_secrets_validate_mcp_env_block '{"K":"literal"}' 2>/dev/null; then
        assert_pass "T23: ALLOW_LITERAL bypass rc=0"
    else
        assert_fail "T23: ALLOW_LITERAL bypass rc=0" "expected rc=0"
    fi
    assert_contains 'test seam only' "$ERR" "T23b: ALLOW_LITERAL warning phrase in stderr"
    ```

    Section 3 — results footer. Copy `test-mcp-secrets.sh:103-104` verbatim:
    ```bash
    printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
    ```

    Counting: Block A=6, Block B=6 (the rc-checks; stderr-phrase asserts add another 5–6 if numbered separately = 11–12 in B), Block C=6 (T13, T14, T14b, T15, T16, T17), Block D=3, Block E=4 (T21, T21b, T22, T23, T23b = 5). Total ≥ 24, comfortably over the 18 floor.

    Section 4 — double-run idempotence (D-20). The whole script is naturally idempotent because `mktemp -d` allocates a fresh `$SANDBOX` per run. To prove double-run-safety inside ONE run, no extra wrapper is needed beyond the explicit T15 idempotent-no-op assertion on `ensure_gitignore`.

    Final shellcheck pass: `shellcheck -S warning scripts/tests/test-project-secrets.sh` must exit 0. Common gotchas:
    - SC2086: quote `"$ERR"` and `"$OUT"` everywhere.
    - SC2155: don't combine `local` declaration and command substitution on the same line if the command's exit status matters (this test is at script scope, not inside functions, so SC2155 is unlikely).
  </action>

  <verify>
    <automated>
      bash -c '
        set -e
        # 1. file exists
        [ -f scripts/tests/test-project-secrets.sh ]
        # 2. shellcheck clean
        shellcheck -S warning scripts/tests/test-project-secrets.sh
        # 3. test runs and reports ≥ 18 passed, 0 failed, exit 0
        OUT=$(bash scripts/tests/test-project-secrets.sh 2>&1)
        echo "$OUT" | tail -3
        echo "$OUT" | grep -E "=== Results: ([0-9]+) passed, 0 failed ===" >/dev/null
        N=$(echo "$OUT" | grep -oE "=== Results: ([0-9]+) passed" | grep -oE "[0-9]+")
        [ "$N" -ge 18 ] || { echo "FAIL: PASS count $N < 18"; exit 1; }
        # 4. double-run safety — running twice in a row does not regress
        bash scripts/tests/test-project-secrets.sh >/dev/null 2>&1
        bash scripts/tests/test-project-secrets.sh >/dev/null 2>&1
        echo OK
      '
    </automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/tests/test-project-secrets.sh` exists.
    - `shellcheck -S warning scripts/tests/test-project-secrets.sh` exits 0.
    - `bash scripts/tests/test-project-secrets.sh` exits 0.
    - Final stdout line matches the regex `=== Results: ([0-9]+) passed, 0 failed ===` with the captured number ≥ 18.
    - `grep -q 'mktemp -d /tmp/project-secrets' scripts/tests/test-project-secrets.sh` succeeds (D-18 hermetic prefix per PATTERNS.md).
    - `grep -q "trap 'rm -rf \"\$SANDBOX\"' EXIT" scripts/tests/test-project-secrets.sh` succeeds (D-20 cleanup trap).
    - `! grep -q 'TK_MCP_CONFIG_HOME' scripts/tests/test-project-secrets.sh` succeeds (PATTERNS.md §"Test-seam naming" — do not reuse this seam in this test).
    - `grep -q "source.*scripts/lib/project-secrets.sh" scripts/tests/test-project-secrets.sh` succeeds.
    - Running the test twice back-to-back both exit 0 (double-run safe — D-20).
    - The test file references all of: `TK_MCP_TTY_SRC`, `TK_PROJECT_SECRETS_ALLOW_LITERAL`, `project_secrets_write_env`, `project_secrets_ensure_gitignore`, `project_secrets_render_mcp_env_block`, `project_secrets_validate_mcp_env_block` (verifiable via 6 separate greps).
    - SEC-06 coverage: at minimum 6 distinct rc-rejection assertions for `$`, backtick, backslash, double-quote, single-quote, newline (verifiable via `grep -cE "metachar|reject.*(DOLLAR|BTICK|BSLASH|DQUOTE|SQUOTE|NL|newline)" scripts/tests/test-project-secrets.sh` returning ≥ 6).
  </acceptance_criteria>

  <done>
    `scripts/tests/test-project-secrets.sh` exists, runs hermetically against a `mktemp -d` sandbox, and asserts every clause of SEC-01..06 with ≥ 18 PASS / 0 FAIL. Double-run safe. Shellcheck clean. The test sources the lib from plan 37-01 and exercises both happy-path and refusal-path contracts.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Wire test into Makefile (test target row + standalone target + .PHONY)</name>
  <files>Makefile</files>

  <read_first>
    - Makefile (lines 1-2 for `.PHONY` line; lines 200-204 for the existing `test-mcp-secrets.sh` row pattern; lines 224-227 for the current `Test 48` end of the test ladder + `All tests passed!` footer; lines 241-243 for the standalone-target shape; lines 265-267 for the most recent standalone target `test-catalog-scope-fallback`)
    - .planning/phases/37-project-secrets-library/37-PATTERNS.md (lines 467-507 for the exact Makefile insertion points)
    - .planning/phases/37-project-secrets-library/37-CONTEXT.md (D-21 — wire into Makefile + CI)
  </read_first>

  <action>
    Three surgical edits to `Makefile`:

    Edit 1 — `.PHONY` line (Makefile:1). Append `test-project-secrets` to the space-separated list. The line currently terminates at `validate-marketplace`. Final segment becomes:

    ```text
    ... validate-skills-desktop validate-marketplace test-project-secrets
    ```

    Edit 2 — append a `Test 49` row inside the `test:` target, between the current last row (`Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)` at lines 224-225) and the `@echo "All tests passed!"` footer (line 227). Add three lines BEFORE line 227:

    ```makefile
    	@echo "Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)"
    	@bash scripts/tests/test-project-secrets.sh
    	@echo ""
    ```

    Use TAB indentation (Makefile recipe convention). The `@echo ""` blank-line separator matches every prior row.

    Edit 3 — append a standalone target after the existing `test-catalog-scope-fallback` block (Makefile:265-267):

    ```makefile

    # Test 49 — project secrets library (Phase 37 / SEC-01..06, TEST-01), invokable standalone
    test-project-secrets:
    	@bash scripts/tests/test-project-secrets.sh
    ```

    Leave a single blank line above the comment (matches prior standalone targets). TAB-indent the recipe line.

    Do NOT touch any other line of `Makefile`. Specifically: do NOT renumber prior tests, do NOT alter unrelated targets, do NOT change `.PHONY` ordering of pre-existing entries — only append the new entry.
  </action>

  <verify>
    <automated>
      bash -c '
        set -e
        # 1. .PHONY contains test-project-secrets
        grep -E "^\.PHONY:.*test-project-secrets" Makefile
        # 2. Test 49 row present in test target
        grep -F "Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)" Makefile
        # 3. Standalone target present
        grep -E "^test-project-secrets:" Makefile
        # 4. Body of standalone target invokes the test
        awk "/^test-project-secrets:/{getline; print; exit}" Makefile | grep -F "bash scripts/tests/test-project-secrets.sh"
        # 5. make test runs the new row successfully (this also exercises ALL prior rows — slow path; if too slow gate it via make test-project-secrets standalone)
        make test-project-secrets
        # 6. shellcheck Makefile rules indirectly via running shellcheck on the test it spawns
        shellcheck -S warning scripts/tests/test-project-secrets.sh
        echo OK
      '
    </automated>
  </verify>

  <acceptance_criteria>
    - `grep -E "^\.PHONY:.*test-project-secrets" Makefile` succeeds.
    - `grep -F "Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)" Makefile` succeeds.
    - `grep -E "^test-project-secrets:" Makefile` succeeds (standalone target).
    - The standalone target's recipe line contains `bash scripts/tests/test-project-secrets.sh`.
    - `make test-project-secrets` exits 0.
    - No prior test row was renumbered or removed (verifiable: `grep -cE "^\s*@echo \"Test [0-9]+:" Makefile` returns 49 — was 48 before, +1 new row).
    - `make check` still passes (no shellcheck regression, no markdownlint regression — Makefile is not linted by markdownlint, but the implicit invariant is no orphaned recipes).
  </acceptance_criteria>

  <done>
    `Makefile` `.PHONY` line includes `test-project-secrets`. The `test:` target includes a `Test 49` row that runs `scripts/tests/test-project-secrets.sh`. A standalone `test-project-secrets:` target exists at the bottom of the standalone-target block. `make test-project-secrets` exits 0. No unrelated lines touched.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Wire test into CI quality.yml (orphan-triage step + step-name range update)</name>
  <files>.github/workflows/quality.yml</files>

  <read_first>
    - .github/workflows/quality.yml (lines 146-156 — the orphan-triage step that currently invokes `test-mcp-secrets.sh` and `test-mcp-wizard.sh`)
    - .planning/phases/37-project-secrets-library/37-PATTERNS.md (lines 511-548 — exact CI extension recipe, including the step-name convention for the range bump)
    - .planning/phases/37-project-secrets-library/37-CONTEXT.md (D-21 — extend the existing range cap; do NOT add a new step)
  </read_first>

  <action>
    Two surgical edits inside the existing `Tests 35-43 — orphan triage` step (.github/workflows/quality.yml:146-156).

    Edit 1 — step name. Replace line 146:

    ```yaml
          - name: Tests 35-43 — orphan triage (audit INF-MED-1) — backup/detect/mcp/dry-run suites previously absent from CI
    ```

    with:

    ```yaml
          - name: Tests 35-49 — orphan triage + Phase 37 project secrets library (audit INF-MED-1, SEC-01..06, TEST-01)
    ```

    Edit 2 — append the new test invocation as the last line of the step's `run: |` block. Currently the block ends at line 156 with `bash scripts/tests/test-update-dry-run.sh`. Add ONE line immediately after, preserving the same indentation (10 spaces — matches `bash scripts/tests/test-update-dry-run.sh`):

    ```yaml
              bash scripts/tests/test-project-secrets.sh
    ```

    Do NOT touch the line-124 step (`Tests 21-47 — uninstall + banner suite + …`). It is a separate range and must remain unchanged. Do NOT add a new step. Do NOT touch any other job (`shellcheck`, `markdownlint`, `test-init-script`, `test-matrix-bats`).
  </action>

  <verify>
    <automated>
      bash -c '
        set -e
        # 1. step name was updated to the new range
        grep -F "Tests 35-49 — orphan triage + Phase 37 project secrets library (audit INF-MED-1, SEC-01..06, TEST-01)" .github/workflows/quality.yml
        # 2. old step-name line (Tests 35-43) is gone
        ! grep -F "Tests 35-43 — orphan triage (audit INF-MED-1) — backup/detect/mcp/dry-run suites previously absent from CI" .github/workflows/quality.yml
        # 3. test invocation present in the orphan-triage step
        grep -F "bash scripts/tests/test-project-secrets.sh" .github/workflows/quality.yml
        # 4. line-124 step is untouched (Tests 21-47 still present verbatim)
        grep -F "Tests 21-47 — uninstall + banner suite" .github/workflows/quality.yml
        # 5. YAML syntactically valid (python3 yaml load — pre-installed on macOS via system python)
        python3 -c "import yaml; yaml.safe_load(open(\".github/workflows/quality.yml\"))"
        echo OK
      '
    </automated>
  </verify>

  <acceptance_criteria>
    - `.github/workflows/quality.yml` contains the exact step-name string `Tests 35-49 — orphan triage + Phase 37 project secrets library (audit INF-MED-1, SEC-01..06, TEST-01)`.
    - The old step-name string `Tests 35-43 — orphan triage (audit INF-MED-1)` is no longer present.
    - The string `bash scripts/tests/test-project-secrets.sh` appears at least once in the file.
    - The line-124 step name `Tests 21-47 — uninstall + banner suite` is still present (untouched — separate range).
    - `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` exits 0 (YAML structurally valid).
    - No other workflow file was modified.
  </acceptance_criteria>

  <done>
    `.github/workflows/quality.yml` orphan-triage step name is bumped to `Tests 35-49 — …` and the step's `run:` block invokes `bash scripts/tests/test-project-secrets.sh` as its last command. YAML still parses. Line-124 step is untouched.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Test sandbox (`mktemp -d`) → real filesystem | The test creates a hermetic sandbox; a buggy test or buggy lib could write outside the sandbox. The negative assertion in plan 40 (UN-SEC-04) will independently verify the lib never opens any `.env` outside the supplied root. |
| CI runner → repo files | CI runs the test as part of the orphan-triage step. A regression in the lib (a literal secret slipping into `.mcp.json` env validation) causes CI to fail before merge. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-37-07 | Tampering | Lib regression in production silently breaks SEC-05 literal-refusal | mitigate | Test asserts `project_secrets_validate_mcp_env_block '{"K":"literal"}'` returns rc=1 AND emits the exact phrase `refusing to write literal value into .mcp.json` to stderr. CI runs this on every PR via the orphan-triage step. |
| T-37-08 | Tampering | Lib regression breaks SEC-06 metacharacter rejection (any of 6 chars) | mitigate | Test asserts rc=1 for each of `$`, backtick, backslash, double-quote, single-quote, newline — six distinct invocations with distinct keys. Any single regression fails the test. |
| T-37-09 | Information Disclosure | `.env` mode regresses to non-0600 on rewrite path | mitigate | T6 in the test re-checks mode after the collision-Y rewrite path, catching umask widening or mktemp+mv permission drift on either macOS or Linux runners (CI runs both via `os: [ubuntu-latest, macos-latest]` matrix in the `test-init-script` job; the orphan-triage step runs on `ubuntu-latest` only — sufficient for this contract since the BSD/GNU stat fork is exercised at the test layer). |
| T-37-10 | Repudiation | Test seam `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` could leak into production via copy-paste from a test fixture | accept | The seam emits a stderr warning every time it is honored (D-15). Naming convention `TK_*` and word `ALLOW_LITERAL` make accidental production use grep-detectable. Test for stderr warning is included so the warning itself cannot regress. |
| T-37-11 | Denial of Service | Pathological JSON input to `validate_mcp_env_block` (e.g. multi-MB payload) hangs CI | accept | `jq -r '.[] | tostring'` is bounded by the input size; production callers pass the env block constructed by `project_secrets_render_mcp_env_block` from a small key list (≤ 10 keys per MCP). No untrusted external JSON enters this validator. |
</threat_model>

<verification>
End-to-end phase verification (after both plans complete):

```bash
# 1. lib exists with public API
grep -c "^project_secrets_" scripts/lib/project-secrets.sh   # ≥ 4

# 2. test exists and passes ≥ 18 assertions
bash scripts/tests/test-project-secrets.sh
echo $?  # 0

# 3. Makefile wires test
make test-project-secrets
echo $?  # 0

# 4. CI step references the test
grep -F "bash scripts/tests/test-project-secrets.sh" .github/workflows/quality.yml

# 5. Full quality gate green
make check  # PASS

# 6. Run the entire test ladder including new Test 49
make test  # PASS — Tests 1..49 all green
```

Phase is verified when all six commands exit 0 and the test reports `=== Results: N passed, 0 failed ===` with N ≥ 18.
</verification>

<success_criteria>
- [ ] `scripts/tests/test-project-secrets.sh` exists, exits 0 with PASS ≥ 18, FAIL = 0.
- [ ] Test is hermetic (`mktemp -d /tmp/project-secrets.XXXXXX`, no `$HOME` mutation, trap cleanup).
- [ ] Test is double-run safe (running twice back-to-back both exit 0).
- [ ] `Makefile` `.PHONY` includes `test-project-secrets`; `test:` target has Test 49 row; standalone `test-project-secrets:` target exists.
- [ ] `make test-project-secrets` exits 0.
- [ ] `.github/workflows/quality.yml` orphan-triage step name updated to `Tests 35-49 — …` and step body invokes `test-project-secrets.sh`.
- [ ] `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` exits 0.
- [ ] `make check` passes (no shellcheck/markdownlint/version-align regressions).
- [ ] Threat model T-37-07..T-37-11 dispositions documented; mitigations land via specific test assertions, not generic advice.
</success_criteria>

<output>
After completion, create `.planning/phases/37-project-secrets-library/37-02-SUMMARY.md` summarizing:
- Files created: `scripts/tests/test-project-secrets.sh`
- Files modified: `Makefile` (1 .PHONY entry, 1 test-row, 1 standalone target), `.github/workflows/quality.yml` (1 step-name bump, 1 invocation line)
- Test contract: PASS ≥ 18 covering SEC-01..06 + the `TK_PROJECT_SECRETS_ALLOW_LITERAL` test seam
- Phase 37 closes: SEC-01..06 + TEST-01 all locked (7/7 requirement IDs delivered)
- Downstream consumers: Phase 38 `mcp_wizard_run` will call all four public functions when `TK_MCP_SCOPE=project`; Phase 40 will assert the negative contract that uninstall.sh never opens `<project>/.env`
- Open follow-ups (NOT this phase): manifest.json `files.libs[]` insertion of `scripts/lib/project-secrets.sh` between `optional-plugins.sh` and `skills.sh` lands in Phase 41 / DIST-01
</output>
</content>
</invoke>