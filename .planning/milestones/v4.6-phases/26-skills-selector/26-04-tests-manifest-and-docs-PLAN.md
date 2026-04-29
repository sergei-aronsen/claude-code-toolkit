---
phase: 26
plan: "04"
type: execute
wave: 3
depends_on: ["01", "02", "03"]
files_modified:
  - scripts/tests/test-install-skills.sh
  - manifest.json
  - Makefile
  - .github/workflows/quality.yml
  - docs/SKILLS-MIRROR.md
  - docs/INSTALL.md
autonomous: true
requirements: [SKILL-04, SKILL-05]
must_haves:
  truths:
    - "scripts/tests/test-install-skills.sh runs hermetically with sandbox $HOME, ≥12 assertions across cp-R correctness / idempotency / --force overwrite / refusal-without-force"
    - "manifest.json registers all 22 templates/skills-marketplace/<name>/ entries under files.skills_marketplace[] (alphabetical) so update-claude.sh ships skill updates via existing jq path with zero new code (LIB-01 D-07)"
    - "Makefile gains Test 33 target invoking test-install-skills.sh + standalone make test-install-skills target"
    - "make sync-skills-mirror standalone Makefile target invokes scripts/sync-skills-mirror.sh"
    - "CI step Tests 21-32 renamed to Tests 21-33 with bash scripts/tests/test-install-skills.sh appended"
    - "docs/SKILLS-MIRROR.md exists, lists all 22 skills with mirror-date, upstream URL placeholder, license type column, and re-sync procedure"
    - "docs/INSTALL.md gains a `### --skills flag` subsection under `## install.sh` documenting --skills behavior + --force semantics"
  artifacts:
    - path: "scripts/tests/test-install-skills.sh"
      provides: "Hermetic SKILL-04 test with ≥12 assertions"
      contains: "is_skill_installed"
    - path: "manifest.json"
      provides: "files.skills_marketplace[] array with 22 entries (alphabetical)"
      contains: "skills_marketplace"
    - path: "docs/SKILLS-MIRROR.md"
      provides: "License + upstream URL + mirror-date documentation per SKILL-02"
      contains: "Mirror date"
    - path: "docs/INSTALL.md"
      provides: "--skills flag subsection per docs/INSTALL.md `## install.sh` convention"
      contains: "--skills"
  key_links:
    - from: "Makefile test target"
      to: "scripts/tests/test-install-skills.sh"
      via: "Test 33 line + standalone make test-install-skills target"
      pattern: "test-install-skills"
    - from: ".github/workflows/quality.yml"
      to: "scripts/tests/test-install-skills.sh"
      via: "appended bash invocation in Tests 21-33 step"
      pattern: "test-install-skills.sh"
    - from: "manifest.json files.skills_marketplace[]"
      to: "templates/skills-marketplace/<name>/"
      via: "update-claude.sh existing jq .files | to_entries[] | .value[] | .path path"
      pattern: "skills_marketplace"
---

<objective>
Wire Phase 26 deliverables into the toolkit's test, distribution, and documentation surfaces. The hermetic test (≥12 assertions) covers the SKILL-04 contract: cp-R correctness, idempotency, --force overwrite, refusal-without-force. The manifest entry (22 skill mirror dirs under `files.skills_marketplace[]`) closes SKILL-05 — `update-claude.sh` auto-discovers via the existing LIB-01 D-07 jq path. CI integration mirrors the Phase 25 Test 32 wiring style (Tests 21-32 → Tests 21-33). Documentation closes SKILL-02 (SKILLS-MIRROR.md) and adds the user-facing `--skills` flag explanation in INSTALL.md.

Purpose: Ships Phase 26 to the user. Without this plan, the install branch (Plan 03) and content (Plan 02) exist but are not tested in CI, not registered for smart-update, and not documented.

Output: One new test file, one new doc file, plus surgical edits to manifest.json, Makefile, CI workflow, and docs/INSTALL.md.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/26-skills-selector/26-CONTEXT.md
@.planning/phases/26-skills-selector/26-01-skills-lib-and-sync-script-PLAN.md
@.planning/phases/26-skills-selector/26-03-install-sh-skills-page-PLAN.md
@.planning/phases/25-mcp-selector/25-04-tests-manifest-and-docs-SUMMARY.md
@scripts/tests/test-mcp-selector.sh
@scripts/tests/test-install-tui.sh
@scripts/lib/skills.sh
@scripts/install.sh
@manifest.json
@Makefile
@docs/INSTALL.md

<interfaces>
<!-- Phase 25 reference: Makefile Tests 31/32 wiring style -->

Makefile current state (lines ~150-176):
```makefile
@echo "Test 31: TUI install orchestrator + dispatch scenarios (TUI-01..09)"
@bash scripts/tests/test-install-tui.sh
@echo "Test 32: MCP catalog + wizard + secrets handling (MCP-01..05, MCP-SEC-01..02)"
@bash scripts/tests/test-mcp-selector.sh

# Standalone targets:
test-install-tui:
	@bash scripts/tests/test-install-tui.sh
test-mcp-selector:
	@bash scripts/tests/test-mcp-selector.sh
```

CI quality.yml current state (line ~109):
```yaml
- name: Tests 21-32 — uninstall + banner suite + bootstrap + lib coverage + TUI + MCP
  run: |
    ...
    bash scripts/tests/test-install-tui.sh
    bash scripts/tests/test-mcp-selector.sh
```

manifest.json current state (lines ~225-260):
```json
"libs": [
  { "path": "scripts/lib/backup.sh" },
  ...
  { "path": "scripts/lib/tui.sh" }
]
```

The `files.skills_marketplace[]` is a NEW top-level files key — NOT an entry in libs. Insertion order in `manifest.json` follows alphabetical key order in the `files` object: should be inserted between `scripts` and (potentially future) other keys. Current `files` keys: agents, prompts, commands, skills, rules, scripts, libs. The new key `skills_marketplace` sits alphabetically between `skills` and (no entry currently — `libs` doesn't sort alphabetically here as the existing schema uses logical ordering). Per LIB-01 D-07 invariant: `update-claude.sh` uses `.files | to_entries[] | .value[] | .path` — the order does NOT matter for auto-discovery, but for human review consistency we add `skills_marketplace` AFTER the `libs` array, near the bottom of `files`. Verify by reading actual manifest before editing.

<!-- Test pattern: scripts/tests/test-mcp-selector.sh hermetic structure -->

Standard hermetic test layout used by Phase 25:
1. set -euo pipefail
2. PASS=0 / FAIL=0 / assert_pass / assert_fail / assert_eq / assert_contains / assert_not_contains helpers
3. Per-scenario function with `local SANDBOX="$(mktemp -d ...)"` + `trap "rm -rf '${SANDBOX:?}'" RETURN`
4. Each function calls assert_* helpers; final tally `[[ $FAIL -eq 0 ]] && exit 0 || exit 1`

<!-- Existing INSTALL.md structure (relevant excerpt) -->

```text
## install.sh (unified entry, v4.6+)
### Quick start
### Flags
### TUI controls
### --mcps flag       ← Phase 25
### Backwards compatibility
```

Phase 26 will insert `### --skills flag` AFTER `### --mcps flag` and BEFORE `### Backwards compatibility`.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author scripts/tests/test-install-skills.sh hermetic test (≥12 assertions)</name>
  <read_first>
    - scripts/tests/test-mcp-selector.sh (full file — structural template, helper definitions, sandbox/trap pattern)
    - scripts/lib/skills.sh (skills_install / is_skill_installed contracts)
    - scripts/install.sh (--skills routing branch — what behavior the integration scenario covers)
    - .planning/phases/26-skills-selector/26-CONTEXT.md (Test Strategy section: 3 sample skills + ≥12 assertions target)
  </read_first>
  <files>scripts/tests/test-install-skills.sh</files>
  <action>
Create new file `scripts/tests/test-install-skills.sh`. Mirror the structural template from `test-mcp-selector.sh`.

Header:
```bash
#!/usr/bin/env bash
# test-install-skills.sh — Phase 26 hermetic integration test.
#
# Scenarios (target ≥12 assertions across 6 scenarios):
#   S1_catalog_correctness   — SKILLS_CATALOG has 22 entries; alphabetical order
#   S2_detection_two_state   — is_skill_installed returns 0 (installed) / 1 (not installed)
#   S3_skills_install_basic  — skills_install copies one skill from mirror to TK_SKILLS_HOME via cp -R
#   S4_idempotency_no_force  — re-running skills_install on installed skill returns rc=2 (refused, no overwrite)
#   S5_force_overwrite       — skills_install --force on installed skill returns rc=0 (overwritten)
#   S6_install_sh_dry_run    — install.sh --skills --yes --dry-run produces 22 would-install rows; zero filesystem mutations
#
# Test seam env vars: TK_SKILLS_HOME, TK_SKILLS_MIRROR_PATH, TK_TUI_TTY_SRC
#
# Sample skills used in scenarios (3 of 22, per CONTEXT.md test strategy):
#   ai-models, pdf, tailwind-design-system
#
# Usage: bash scripts/tests/test-install-skills.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

Helper functions (copy verbatim from test-mcp-selector.sh):
- `assert_pass`, `assert_fail`, `assert_eq`, `assert_contains`, `assert_not_contains`

Test scenarios (each as a function):

**S1_catalog_correctness** (3 assertions):
```bash
run_s1_catalog_correctness() {
    echo "  -- S1_catalog_correctness: 22 entries, alphabetical order, last is webapp-testing --"
    SKILLS_CATALOG=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/skills.sh"
    assert_eq "22" "${#SKILLS_CATALOG[@]}" "S1: catalog contains 22 entries"
    assert_eq "ai-models" "${SKILLS_CATALOG[0]}" "S1: alphabetical first entry is ai-models"
    assert_eq "webapp-testing" "${SKILLS_CATALOG[21]}" "S1: alphabetical last entry is webapp-testing"
}
```

**S2_detection_two_state** (2 assertions):
```bash
run_s2_detection_two_state() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S2_detection_two_state: is_skill_installed 0/1 contract --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME/ai-models"
    touch "$SKILLS_HOME/ai-models/SKILL.md"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        is_skill_installed ai-models
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S2: is_skill_installed ai-models returns 0 when dir exists"

    rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        is_skill_installed pdf
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "1" "$rc" "S2: is_skill_installed pdf returns 1 when dir absent"
}
```

**S3_skills_install_basic** (3 assertions):
```bash
run_s3_skills_install_basic() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S3_skills_install_basic: cp -R correctness for sample skill --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install ai-models
        exit \$?
    " || rc=$?
    assert_eq "0" "$rc" "S3: skills_install ai-models returns 0 on success"

    if [[ -d "$SKILLS_HOME/ai-models" ]]; then
        assert_pass "S3: ~/.claude/skills/ai-models/ directory exists post-install"
    else
        assert_fail "S3: ~/.claude/skills/ai-models/ directory exists post-install" "directory missing"
    fi

    if [[ -f "$SKILLS_HOME/ai-models/SKILL.md" ]]; then
        assert_pass "S3: SKILL.md copied to target dir"
    else
        assert_fail "S3: SKILL.md copied to target dir" "SKILL.md missing"
    fi
}
```

**S4_idempotency_no_force** (2 assertions):
```bash
run_s4_idempotency_no_force() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4_idempotency_no_force: re-install without --force returns rc=2 --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    # First install
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "source '${REPO_ROOT}/scripts/lib/skills.sh'; skills_install pdf" >/dev/null 2>&1

    # Marker: write a sentinel file inside the installed skill to confirm no overwrite
    echo "user-edit" > "$SKILLS_HOME/pdf/USER_EDIT.txt"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install pdf
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "2" "$rc" "S4: skills_install pdf returns 2 on already-installed (no --force)"

    # Sentinel preserved → no overwrite occurred
    if [[ -f "$SKILLS_HOME/pdf/USER_EDIT.txt" ]]; then
        assert_pass "S4: user sentinel file preserved (no overwrite)"
    else
        assert_fail "S4: user sentinel file preserved (no overwrite)" "USER_EDIT.txt was destroyed"
    fi
}
```

**S5_force_overwrite** (2 assertions):
```bash
run_s5_force_overwrite() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5_force_overwrite: --force re-installs over existing dir --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "source '${REPO_ROOT}/scripts/lib/skills.sh'; skills_install tailwind-design-system" >/dev/null 2>&1

    echo "stale" > "$SKILLS_HOME/tailwind-design-system/STALE_USER_FILE.txt"

    local rc=0
    TK_SKILLS_HOME="$SKILLS_HOME" \
    TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
    bash -c "
        source '${REPO_ROOT}/scripts/lib/skills.sh'
        skills_install tailwind-design-system --force
        exit \$?
    " 2>/dev/null || rc=$?
    assert_eq "0" "$rc" "S5: skills_install tailwind-design-system --force returns 0"

    # Stale file destroyed → overwrite occurred
    if [[ ! -f "$SKILLS_HOME/tailwind-design-system/STALE_USER_FILE.txt" ]]; then
        assert_pass "S5: stale user file destroyed (--force overwrote)"
    else
        assert_fail "S5: stale user file destroyed (--force overwrote)" "STALE_USER_FILE.txt still present"
    fi
}
```

**S6_install_sh_dry_run** (3 assertions):
```bash
run_s6_install_sh_dry_run() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-install-skills.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S6_install_sh_dry_run: --skills --yes --dry-run preview, zero mutations --"

    local SKILLS_HOME="$SANDBOX/skills"
    mkdir -p "$SKILLS_HOME"

    local output rc=0
    output="$(
        TK_SKILLS_HOME="$SKILLS_HOME" \
        TK_SKILLS_MIRROR_PATH="${REPO_ROOT}/templates/skills-marketplace" \
        TK_TUI_TTY_SRC="$SANDBOX/no-tty-device" \
        bash "${REPO_ROOT}/scripts/install.sh" --skills --yes --dry-run 2>&1
    )" || rc=$?
    assert_eq "0" "$rc" "S6: install.sh --skills --yes --dry-run exits 0"

    local would_count
    would_count=$(printf '%s\n' "$output" | grep -c "would-install" || true)
    assert_eq "22" "$would_count" "S6: dry-run prints 22 would-install rows"

    # Zero filesystem mutations: SKILLS_HOME should still be empty.
    local file_count
    file_count=$(find "$SKILLS_HOME" -mindepth 1 | wc -l | tr -d ' ')
    assert_eq "0" "$file_count" "S6: TK_SKILLS_HOME has zero entries post-dry-run"
}
```

Main runner (final block):
```bash
echo "test-install-skills.sh: SKILL-03..05 hermetic suite"
echo ""
run_s1_catalog_correctness
run_s2_detection_two_state
run_s3_skills_install_basic
run_s4_idempotency_no_force
run_s5_force_overwrite
run_s6_install_sh_dry_run
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

Total assertion count: 3 + 2 + 3 + 2 + 2 + 3 = **15** (target ≥12 ✓).

Make file executable: `chmod +x scripts/tests/test-install-skills.sh`.

Run the test to confirm green:
```bash
bash scripts/tests/test-install-skills.sh
# Expected: PASS=15 FAIL=0
```

Run shellcheck:
```bash
shellcheck -S warning scripts/tests/test-install-skills.sh
# Expected: 0 warnings
```
  </action>
  <verify>
    <automated>
      bash scripts/tests/test-install-skills.sh 2>&1 | tail -1 | grep -E "PASS=15.*FAIL=0"
      # MUST match — total assertion count = 15

      shellcheck -S warning scripts/tests/test-install-skills.sh
      # MUST exit 0

      grep -c "^run_s" scripts/tests/test-install-skills.sh
      # Expected: 7 (6 function definitions + 1 main runner block — actually count function declarations)

      grep -cE "^run_s[0-9]_[a-z_]+\(\)" scripts/tests/test-install-skills.sh
      # MUST output: 6

      grep -c "TK_SKILLS_HOME" scripts/tests/test-install-skills.sh
      # MUST output: ≥6 (each scenario uses the seam)

      grep -c "TK_SKILLS_MIRROR_PATH" scripts/tests/test-install-skills.sh
      # MUST output: ≥4 (S3, S4, S5, S6 use mirror path seam)

      [[ -x scripts/tests/test-install-skills.sh ]] && echo "executable"
      # MUST output: executable
    </automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/tests/test-install-skills.sh` exists and is executable.
    - File defines 6 scenario functions: run_s1_catalog_correctness, run_s2_detection_two_state, run_s3_skills_install_basic, run_s4_idempotency_no_force, run_s5_force_overwrite, run_s6_install_sh_dry_run.
    - Test passes: `PASS=15 FAIL=0`.
    - shellcheck -S warning passes.
    - Sandbox uses mktemp + trap RETURN cleanup pattern (no leftover /tmp dirs after run).
    - Each scenario uses TK_SKILLS_HOME and TK_SKILLS_MIRROR_PATH seams.
    - S3 verifies cp-R correctness (target dir + SKILL.md exist).
    - S4 verifies refusal-to-overwrite-without-force AND user sentinel preservation.
    - S5 verifies --force overwrite AND stale user file destruction.
    - S6 verifies dry-run zero-mutation contract.
  </acceptance_criteria>
  <done>scripts/tests/test-install-skills.sh exists with 15 assertions across 6 scenarios. Tests SKILL-04 contract: cp-R, idempotency, --force, refusal, dry-run zero-mutation. Sandbox-isolated. shellcheck clean.</done>
</task>

<task type="auto">
  <name>Task 2: Wire manifest.json files.skills_marketplace[] + Makefile Test 33 + sync-skills-mirror target + CI Tests 21-33</name>
  <read_first>
    - manifest.json (lines 200-260 — files.libs[] alphabetical entry style; placement of new files keys)
    - Makefile (lines 145-180 — Test 30/31/32 wiring style + standalone target convention)
    - .github/workflows/quality.yml (line ~109 — Tests 21-32 step layout)
  </read_first>
  <files>manifest.json, Makefile, .github/workflows/quality.yml</files>
  <action>
**Edit 1 — manifest.json:** Add `files.skills_marketplace[]` array with 22 entries (alphabetical) after `files.libs[]`. Each entry is an object with a single `path` key pointing to the mirror directory.

Insertion point: after the `libs` array closing `]` (around line 259) and BEFORE `}` that closes `files`.

```json
    "skills_marketplace": [
      { "path": "templates/skills-marketplace/ai-models" },
      { "path": "templates/skills-marketplace/analytics-tracking" },
      { "path": "templates/skills-marketplace/chrome-extension-development" },
      { "path": "templates/skills-marketplace/copywriting" },
      { "path": "templates/skills-marketplace/docx" },
      { "path": "templates/skills-marketplace/find-skills" },
      { "path": "templates/skills-marketplace/firecrawl" },
      { "path": "templates/skills-marketplace/i18n-localization" },
      { "path": "templates/skills-marketplace/memo-skill" },
      { "path": "templates/skills-marketplace/next-best-practices" },
      { "path": "templates/skills-marketplace/notebooklm" },
      { "path": "templates/skills-marketplace/pdf" },
      { "path": "templates/skills-marketplace/resend" },
      { "path": "templates/skills-marketplace/seo-audit" },
      { "path": "templates/skills-marketplace/shadcn" },
      { "path": "templates/skills-marketplace/stripe-best-practices" },
      { "path": "templates/skills-marketplace/tailwind-design-system" },
      { "path": "templates/skills-marketplace/typescript-advanced-types" },
      { "path": "templates/skills-marketplace/ui-ux-pro-max" },
      { "path": "templates/skills-marketplace/vercel-composition-patterns" },
      { "path": "templates/skills-marketplace/vercel-react-best-practices" },
      { "path": "templates/skills-marketplace/webapp-testing" }
    ]
```

NOTE: scripts/lib/skills.sh is a sourced library — add it to `files.libs[]` (alphabetically between `optional-plugins.sh` and `state.sh`):
```json
      { "path": "scripts/lib/optional-plugins.sh" },
      { "path": "scripts/lib/skills.sh" },
      { "path": "scripts/lib/state.sh" },
```

Also add scripts/sync-skills-mirror.sh to `files.scripts[]` (alphabetically — Phase 25 SUMMARY noted that test files do NOT go in manifest, but maintainer scripts that ship with the install do go in `scripts[]`):

Wait — re-check. Per CONTEXT.md "scripts/sync-skills-mirror.sh standalone script (not test-wired) for manual upstream re-sync." Is it shipped to users or only used by maintainers? Per Phase 25 04 SUMMARY, hermetic test files are NOT added to manifest because they "ship via repo, not curl-bash install." sync-skills-mirror.sh is similar — it's a maintainer tool, not part of the user install path. **Decision: do NOT add sync-skills-mirror.sh to manifest.json.** It lives in `scripts/` but is invoked manually by maintainers from a clone, never via curl|bash. Document this decision in the SUMMARY.

Verify the manifest still parses:
```bash
jq . manifest.json > /dev/null
# Expected: exit 0 (valid JSON)
```

Run the manifest validator:
```bash
python3 scripts/validate-manifest.py
# Expected: PASSED
```

Verify the LIB-01 D-07 invariant test still passes (this proves update-claude.sh auto-discovers the new array via the existing jq path):
```bash
bash scripts/tests/test-update-libs.sh
# Expected: PASS=15 FAIL=0
```

**Edit 2 — Makefile:** Add Test 33 line after Test 32 in the `test:` target. Insertion point around line 158:
```makefile
	@echo "Test 33: Skills selector + cp-R install + idempotency + --force (SKILL-03..05)"
	@bash scripts/tests/test-install-skills.sh
```

Add a standalone `test-install-skills:` target after the `test-mcp-selector:` target (around line 176):
```makefile
# Test 33 — Skills selector + cp-R install + idempotency + --force (SKILL-03..05)
test-install-skills:
	@bash scripts/tests/test-install-skills.sh
```

Add a `sync-skills-mirror:` standalone target near the `test-install-skills:` target. This is a convenience for maintainers who want `make sync-skills-mirror` instead of remembering the script path:
```makefile
# Skills mirror re-sync (maintainer-only) — re-syncs templates/skills-marketplace/
# from local $HOME/.claude/skills/. Not run by CI.
sync-skills-mirror:
	@bash scripts/sync-skills-mirror.sh
```

Update `.PHONY` line (line 1) to include both new targets: append ` test-install-skills sync-skills-mirror`.

**Edit 3 — .github/workflows/quality.yml:** Rename step `Tests 21-32 — uninstall + banner suite + bootstrap + lib coverage + TUI + MCP` to `Tests 21-33 — uninstall + banner suite + bootstrap + lib coverage + TUI + MCP + Skills`. Append `bash scripts/tests/test-install-skills.sh` after the `bash scripts/tests/test-mcp-selector.sh` line (around line 122).

Verify CI YAML still parses:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"
# Expected: no exception
```

Run the new test from Makefile to confirm wiring:
```bash
make test-install-skills
# Expected: PASS=15 FAIL=0
```

Confirm BACKCOMPAT-01 invariants still hold:
```bash
bash scripts/tests/test-bootstrap.sh        # PASS=26 FAIL=0
bash scripts/tests/test-install-tui.sh      # PASS=38 FAIL=0
bash scripts/tests/test-mcp-selector.sh     # PASS=21 FAIL=0
bash scripts/tests/test-update-libs.sh      # PASS=15 FAIL=0 (LIB-01 D-07 — proves update auto-discovers skills_marketplace[])
```

Run the full check gate:
```bash
make check
# Expected: All checks passed!
```
  </action>
  <verify>
    <automated>
      jq . manifest.json > /dev/null && echo "valid"
      # MUST output: valid

      jq '.files.skills_marketplace | length' manifest.json
      # MUST output: 22

      jq -r '.files.skills_marketplace[0].path' manifest.json
      # MUST output: templates/skills-marketplace/ai-models

      jq -r '.files.skills_marketplace[21].path' manifest.json
      # MUST output: templates/skills-marketplace/webapp-testing

      jq -r '.files.libs[] | .path' manifest.json | grep -c "skills.sh"
      # MUST output: 1

      grep -c "Test 33" Makefile
      # MUST output: ≥1

      grep -c "^test-install-skills:" Makefile
      # MUST output: 1

      grep -c "^sync-skills-mirror:" Makefile
      # MUST output: 1

      grep -c "Tests 21-33" .github/workflows/quality.yml
      # MUST output: ≥1

      grep -c "test-install-skills.sh" .github/workflows/quality.yml
      # MUST output: 1

      python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"
      # MUST exit 0

      bash scripts/tests/test-update-libs.sh 2>&1 | tail -1 | grep -E "PASS=15.*FAIL=0"
      # MUST match — proves LIB-01 D-07 invariant holds for new files.skills_marketplace[]

      bash scripts/tests/test-bootstrap.sh 2>&1 | tail -3 | grep -E "PASS=26.*FAIL=0"
      # MUST match

      bash scripts/tests/test-install-tui.sh 2>&1 | tail -3 | grep -E "PASS=38.*FAIL=0"
      # MUST match

      bash scripts/tests/test-mcp-selector.sh 2>&1 | tail -3 | grep -E "PASS=21.*FAIL=0"
      # MUST match

      make test-install-skills 2>&1 | tail -1 | grep -E "PASS=15.*FAIL=0"
      # MUST match
    </automated>
  </verify>
  <acceptance_criteria>
    - manifest.json passes `jq . manifest.json > /dev/null`.
    - manifest.json has `files.skills_marketplace[]` with exactly 22 alphabetically-sorted entries.
    - manifest.json `files.libs[]` includes `scripts/lib/skills.sh` alphabetically.
    - manifest.json does NOT include scripts/sync-skills-mirror.sh (maintainer tool, not user-shipped).
    - Makefile has Test 33 wiring inside `test:` target.
    - Makefile has standalone `test-install-skills:` target.
    - Makefile has standalone `sync-skills-mirror:` target.
    - Makefile `.PHONY` line includes both new targets.
    - CI step renamed `Tests 21-33` and appends `bash scripts/tests/test-install-skills.sh`.
    - test-update-libs.sh PASS=15 (LIB-01 D-07 invariant — update-claude.sh auto-picks skills_marketplace via jq path).
    - test-bootstrap.sh PASS=26 (BOOTSTRAP-01..04).
    - test-install-tui.sh PASS=38 (TUI-01..09 BACKCOMPAT-01).
    - test-mcp-selector.sh PASS=21 (MCP-01..05 / MCP-SEC-01..02).
    - `make check` exits 0.
  </acceptance_criteria>
  <done>manifest.json registers all 22 skill mirror dirs in files.skills_marketplace[] (alphabetical) and skills.sh in files.libs[]. update-claude.sh auto-discovers via existing LIB-01 D-07 jq path (proven by test-update-libs.sh PASS=15). Makefile Test 33 + standalone targets + .PHONY entries added. CI step renamed and appended. All four BACKCOMPAT invariants green.</done>
</task>

<task type="auto">
  <name>Task 3: Author docs/SKILLS-MIRROR.md + add --skills flag subsection to docs/INSTALL.md</name>
  <read_first>
    - docs/INSTALL.md (lines 80-170 — install.sh subsections, --mcps flag formatting style)
    - .planning/phases/26-skills-selector/26-CONTEXT.md (License Preservation section + Distribution section)
    - templates/skills-marketplace/ (verify which skills have upstream LICENSE vs SKILL-LICENSE.md fallback for the License column in SKILLS-MIRROR.md)
    - docs/MCP-SETUP.md (Phase 25 reference for tone, headers, code-block style)
  </read_first>
  <files>docs/SKILLS-MIRROR.md, docs/INSTALL.md</files>
  <action>
**Edit 1 — Create docs/SKILLS-MIRROR.md (new file):**

Document structure:

```markdown
# Skills Mirror

The Claude Code Toolkit ships a curated mirror of 22 skills under `templates/skills-marketplace/`. Each skill is a static snapshot — committed bytes, version-pinned, offline-installable. `scripts/install.sh --skills` copies selected skills to `~/.claude/skills/<name>/`.

## Mirror date

Snapshot taken: <YYYY-MM-DD>  (use today's date)

The mirror is a frozen point-in-time copy. Re-sync via `scripts/sync-skills-mirror.sh` before each milestone where upstream skill content has changed.

## Re-sync procedure

For maintainers:

1. Ensure your local `~/.claude/skills/` contains the canonical upstream snapshot.
2. Run the standalone re-sync script:

   ```bash
   bash scripts/sync-skills-mirror.sh        # all 22 skills
   bash scripts/sync-skills-mirror.sh ai-models   # single skill
   bash scripts/sync-skills-mirror.sh --dry-run   # preview without writes
   ```

3. Verify the diff: `git diff templates/skills-marketplace/`.
4. Update the "Mirror date" above to today's date.
5. Update entries in the table below if upstream URLs changed.
6. Commit with message `docs(26): re-sync skills mirror to <YYYY-MM-DD>`.

The script is also exposed via `make sync-skills-mirror`.

## Skill catalog

| Skill | License | Upstream URL | Companion files |
|-------|---------|--------------|-----------------|
| ai-models | (TBD upstream) | https://skills.sh/ai-models | SKILL.md |
| analytics-tracking | (TBD upstream) | https://skills.sh/analytics-tracking | SKILL.md + companions |
| chrome-extension-development | (TBD upstream) | https://skills.sh/chrome-extension-development | SKILL.md + companions |
| copywriting | (TBD upstream) | https://skills.sh/copywriting | SKILL.md |
| docx | (TBD upstream) | https://skills.sh/docx | SKILL.md |
| find-skills | (TBD upstream) | https://skills.sh/find-skills | SKILL.md |
| firecrawl | (TBD upstream) | https://skills.sh/firecrawl | SKILL.md + rules/ |
| i18n-localization | (TBD upstream) | https://skills.sh/i18n-localization | SKILL.md |
| memo-skill | (TBD upstream) | https://skills.sh/memo-skill | SKILL.md |
| next-best-practices | (TBD upstream) | https://skills.sh/next-best-practices | SKILL.md |
| notebooklm | (TBD upstream) | https://skills.sh/notebooklm | SKILL.md |
| pdf | (Upstream LICENSE.txt) | https://skills.sh/pdf | SKILL.md + scripts/ + reference.md + forms.md |
| resend | (TBD upstream) | https://skills.sh/resend | SKILL.md |
| seo-audit | (TBD upstream) | https://skills.sh/seo-audit | SKILL.md |
| shadcn | (TBD upstream) | https://skills.sh/shadcn | SKILL.md + agents/ + assets/ + cli.md + customization.md + evals/ + mcp.md + rules/ |
| stripe-best-practices | (TBD upstream) | https://skills.sh/stripe-best-practices | SKILL.md |
| tailwind-design-system | (TBD upstream) | https://skills.sh/tailwind-design-system | SKILL.md + references/ |
| typescript-advanced-types | (TBD upstream) | https://skills.sh/typescript-advanced-types | SKILL.md |
| ui-ux-pro-max | (TBD upstream) | https://skills.sh/ui-ux-pro-max | SKILL.md |
| vercel-composition-patterns | (TBD upstream) | https://skills.sh/vercel-composition-patterns | SKILL.md |
| vercel-react-best-practices | (TBD upstream) | https://skills.sh/vercel-react-best-practices | SKILL.md |
| webapp-testing | (TBD upstream) | https://skills.sh/webapp-testing | SKILL.md |

License column values:
- `Upstream LICENSE.txt` (or `LICENSE` / `LICENSE.md`) — preserved verbatim from source
- `SKILL-LICENSE.md fallback` — upstream did not ship a license; fair-use mirror exception per Plan 02
- `(TBD upstream)` — placeholder; refresh on next re-sync

## Verifying the License column

Run:

```bash
for d in templates/skills-marketplace/*/; do
    name="$(basename "$d")"
    if ls "${d}"LICENSE* 2>/dev/null | grep -q .; then
        echo "$name: upstream LICENSE"
    elif [[ -f "${d}SKILL-LICENSE.md" ]]; then
        echo "$name: SKILL-LICENSE.md fallback"
    else
        echo "$name: MISSING LICENSE"
    fi
done
```

Update the License column whenever the audit output changes.

## License-audit policy

Per SKILL-02:
- Every mirrored skill MUST have at least one license artifact (upstream `LICENSE*` OR `SKILL-LICENSE.md` fallback).
- The audit runs manually; CI does NOT enforce license correctness automatically (out of scope per CONTEXT.md Deferred Ideas).
- If upstream changes a skill's license, update the License column on the next re-sync.
```

NOTES on Task 3 Edit 1:
- The "TBD upstream" placeholders are honest — the planning context does not pin the canonical upstream URL for each skill. The maintainer fills these in during the first real re-sync. Better to ship honest placeholders than guess URLs.
- After Plan 02 runs, the actual License column values can be derived from disk. Run the audit script in the action above to populate the real column values when authoring this file.
- Use TODAY's date in the "Mirror date" line — read from `date +%Y-%m-%d` at write time.

**Edit 2 — Add `### --skills flag` subsection to docs/INSTALL.md:**

Insertion point: AFTER the `### --mcps flag` section (which ends just before `### Backwards compatibility`).

New subsection content:

```markdown
### --skills flag

Install curated skills from the toolkit's marketplace mirror.

```bash
# TUI mode — interactive 22-skill catalog with detect status
bash scripts/install.sh --skills

# Non-interactive — install all uninstalled skills (default-set)
bash scripts/install.sh --skills --yes

# Re-install (overwrite existing skills)
bash scripts/install.sh --skills --yes --force

# Dry-run preview (no filesystem writes)
bash scripts/install.sh --skills --yes --dry-run
```

Skills install to `~/.claude/skills/<name>/`. Skills are detected via directory presence (`[ -d ~/.claude/skills/<name>/ ]`).

**Idempotent semantics:**
- Without `--force`: already-installed skills are skipped (status `skipped: already installed`).
- With `--force`: existing target directory is removed before re-copy.

**Failure handling:** A failed skill copy does not block the rest. Per-skill status appears in the post-install summary as `installed ✓`, `skipped`, `would-install`, or `failed (exit N)`.

**Removing a skill:** `rm -rf ~/.claude/skills/<name>` (no dedicated `--skills-remove` flag — manual deletion is sufficient).

**Mirror provenance:** All 22 skills are sourced from upstream and committed to `templates/skills-marketplace/` as a static snapshot. Re-sync via `scripts/sync-skills-mirror.sh` (maintainer tool). See `docs/SKILLS-MIRROR.md` for license + upstream URL per skill.

**Mutex with `--mcps`:** `--mcps` and `--skills` cannot be combined in the same invocation. Run two separate commands.
```

Verify markdown lints clean:
```bash
markdownlint docs/SKILLS-MIRROR.md docs/INSTALL.md
# Expected: 0 errors
```

If markdownlint flags issues:
- MD040: ensure all fenced code blocks declare a language
- MD031/MD032: ensure blank lines before/after code blocks and lists
- MD026: ensure no trailing punctuation in headings
- MD024: enable siblings_only (already configured in .markdownlint.json)

Run the full check gate:
```bash
make check
# Expected: All checks passed!
```
  </action>
  <verify>
    <automated>
      [[ -f docs/SKILLS-MIRROR.md ]] && echo "exists"
      # MUST output: exists

      grep -c "^| " docs/SKILLS-MIRROR.md
      # MUST output ≥23 (header row + separator + 22 skill rows)

      grep -c "Mirror date" docs/SKILLS-MIRROR.md
      # MUST output ≥1

      grep -c "sync-skills-mirror.sh" docs/SKILLS-MIRROR.md
      # MUST output ≥1

      grep -c "^### --skills flag$" docs/INSTALL.md
      # MUST output: 1

      grep -c "TK_SKILLS_HOME\|skills_install\|--skills" docs/INSTALL.md
      # MUST output ≥1 (must mention --skills explicitly in the new section)

      markdownlint docs/SKILLS-MIRROR.md docs/INSTALL.md 2>&1 | tail -5
      # MUST exit 0 with no errors

      make check 2>&1 | tail -3 | grep -E "passed|All checks"
      # MUST match (full repo gate)
    </automated>
  </verify>
  <acceptance_criteria>
    - docs/SKILLS-MIRROR.md exists.
    - docs/SKILLS-MIRROR.md has a "Mirror date" line with a valid YYYY-MM-DD value.
    - docs/SKILLS-MIRROR.md has a 22-row skill catalog table (one row per skill, alphabetical).
    - docs/SKILLS-MIRROR.md documents the re-sync procedure including `bash scripts/sync-skills-mirror.sh` invocation.
    - docs/INSTALL.md gains a `### --skills flag` subsection.
    - The new INSTALL.md subsection documents all four invocation modes (TUI / --yes / --force / --dry-run).
    - The new subsection notes the `--mcps` mutex.
    - markdownlint passes both files (MD040 / MD031 / MD032 / MD026 clean).
    - `make check` succeeds (all repo gates).
  </acceptance_criteria>
  <done>docs/SKILLS-MIRROR.md ships with mirror-date, 22-row license + URL catalog, re-sync procedure. docs/INSTALL.md gains --skills subsection covering TUI/--yes/--force/--dry-run/mutex. markdownlint clean. make check green.</done>
</task>

</tasks>

<verification>
After all three tasks:

1. `bash scripts/tests/test-install-skills.sh` → PASS=15 FAIL=0
2. `bash scripts/tests/test-update-libs.sh` → PASS=15 FAIL=0 (LIB-01 D-07 — proves update-claude.sh auto-discovers files.skills_marketplace[])
3. `bash scripts/tests/test-bootstrap.sh` → PASS=26 FAIL=0 (BACKCOMPAT-01)
4. `bash scripts/tests/test-install-tui.sh` → PASS=38 FAIL=0 (BACKCOMPAT-01)
5. `bash scripts/tests/test-mcp-selector.sh` → PASS=21 FAIL=0 (Phase 25 invariant)
6. `jq '.files.skills_marketplace | length' manifest.json` → 22
7. `python3 scripts/validate-manifest.py` → PASSED
8. `make test-install-skills` → PASS=15 FAIL=0
9. `make test` → all 33 tests pass
10. `make check` → all checks passed
11. `markdownlint docs/SKILLS-MIRROR.md docs/INSTALL.md` → 0 errors
12. `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality.yml'))"` → exit 0
</verification>

<success_criteria>
- scripts/tests/test-install-skills.sh: 15 assertions across 6 hermetic scenarios. PASS=15 FAIL=0.
- manifest.json: files.skills_marketplace[] (22 entries) + files.libs[] entry for skills.sh — both alphabetical.
- Makefile: Test 33 wiring inside `test:` target + standalone `test-install-skills:` + standalone `sync-skills-mirror:` + .PHONY updated.
- CI: step renamed Tests 21-33; bash scripts/tests/test-install-skills.sh appended.
- docs/SKILLS-MIRROR.md: 22-row license/URL/mirror-date catalog + re-sync procedure.
- docs/INSTALL.md: --skills flag subsection covering all four modes + --mcps mutex note.
- BACKCOMPAT invariants preserved: bootstrap=26, install-tui=38, mcp-selector=21, update-libs=15.
- make check passes. markdownlint passes. shellcheck passes.
- All 5 SKILL-* requirements covered across Phase 26: SKILL-01 (Plan 02 mirror), SKILL-02 (Plan 02 license + Plan 04 SKILLS-MIRROR.md), SKILL-03 (Plans 01+03), SKILL-04 (Plan 04 test), SKILL-05 (Plan 04 manifest).
</success_criteria>

<output>
After completion, create `.planning/phases/26-skills-selector/26-04-tests-manifest-and-docs-SUMMARY.md`. Include:
- Final assertion count (PASS=15 baseline, +/- if scenarios were extended)
- manifest.json diff summary (22 + 1 = 23 new entries)
- Whether sync-skills-mirror.sh was added to manifest (decision: NO, maintainer-only)
- Any markdownlint adjustments made (e.g., if templates/skills-marketplace/ was added to .markdownlintignore in Plan 02 — note carry-over)
- BACKCOMPAT invariant test results (4 tests, all PASS)
</output>
