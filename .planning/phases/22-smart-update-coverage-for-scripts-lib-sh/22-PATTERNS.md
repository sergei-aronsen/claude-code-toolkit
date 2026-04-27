# Phase 22: Smart-Update Coverage for `scripts/lib/*.sh` - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 5 (2 modified, 1 new, 2 modified)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `manifest.json` | config | batch | `manifest.json` §`files.scripts[]` (lines 216-220) | exact |
| `CHANGELOG.md` | config | batch | `CHANGELOG.md` §`[4.3.0]` (lines 8-41) | exact |
| `scripts/tests/test-update-libs.sh` | test | request-response | `scripts/tests/test-bootstrap.sh` (261 lines) + `scripts/tests/test-uninstall.sh` (375 lines) | exact |
| `Makefile` | config | batch | `Makefile` Test 28 block (lines 144-145) | exact |
| `.github/workflows/quality.yml` | config | batch | `.github/workflows/quality.yml` `Tests 21-28` step (lines 109-118) | exact |

---

## Pattern Assignments

### `manifest.json` (config, batch)

**Analog:** `manifest.json` §`files.scripts[]`, lines 216-220

**Core pattern** — add `"libs"` key after `"scripts"` under `.files`, same structure, no `description` field:

```json
"scripts": [
  {
    "path": "scripts/uninstall.sh"
  }
],
"libs": [
  {
    "path": "scripts/lib/backup.sh"
  },
  {
    "path": "scripts/lib/bootstrap.sh"
  },
  {
    "path": "scripts/lib/dry-run-output.sh"
  },
  {
    "path": "scripts/lib/install.sh"
  },
  {
    "path": "scripts/lib/optional-plugins.sh"
  },
  {
    "path": "scripts/lib/state.sh"
  }
]
```

**Version bump pattern** — lines 2-4 (the only field to change for the bump):

```json
{
  "manifest_version": 2,
  "version": "4.4.0",
  "updated": "2026-04-27",
```

**Why zero code changes to update loop:** `jq -c '[.files | to_entries[] | .value[] | .path]'`
at `scripts/update-claude.sh:637` auto-discovers any new top-level key under `.files`. Adding
`"libs"` produces the same JSON array elements as `"scripts"`. Verified: `update-claude.sh:637-638`.

---

### `CHANGELOG.md` (config, batch)

**Analog:** `CHANGELOG.md` §`[4.3.0]` (lines 8-41)

**Header format pattern** (lines 8-10):

```markdown
## [4.3.0] - 2026-04-26

### Added
```

**New section to prepend** — insert before the existing `## [4.3.0]` block. Consolidates Phase 21
(BOOTSTRAP-01..04) + Phase 22 (LIB-01..02) into a single release entry because Phase 21 was
never released as its own version:

```markdown
## [4.4.0] - 2026-04-27

### Added

- **SP/GSD bootstrap prompts** (`scripts/lib/bootstrap.sh`, `scripts/lib/optional-plugins.sh`) —
  BOOTSTRAP-01..04: `init-local.sh` and `init-claude.sh` now offer to install `superpowers` and
  `get-shit-done` base plugins when not already present; `--no-bootstrap` / `TK_NO_BOOTSTRAP=1`
  suppresses all prompts byte-quietly (D-17).

- **Smart-update coverage for `scripts/lib/*.sh`** — LIB-01: all six sourced helper libraries
  (`backup.sh`, `bootstrap.sh`, `dry-run-output.sh`, `install.sh`, `optional-plugins.sh`,
  `state.sh`) registered in `manifest.json` under new `files.libs[]` array; LIB-02: stale lib
  files on disk are now refreshed by `update-claude.sh` with the same diff/backup/safe-write
  contract as top-level scripts — zero code changes to the update loop required.

- **Hermetic regression test** — `scripts/tests/test-update-libs.sh` (Test 29): five scenarios
  proving stale-refresh (S1), clean-untouched (S2), fresh-install of all six libs (S3),
  modified-file fail-closed behaviour (S4), and uninstall round-trip (S5).
```

---

### `scripts/tests/test-update-libs.sh` (test, request-response)

**Analog:** `scripts/tests/test-bootstrap.sh` (primary — five-scenario shape, seam pattern)
and `scripts/tests/test-uninstall.sh` (S5 round-trip pattern)

**File header + boilerplate pattern** (test-bootstrap.sh lines 1-27):

```bash
#!/usr/bin/env bash
# test-update-libs.sh — LIB-01..02 hermetic integration test.
#
# Five scenarios:
#   S1 — stale lib refreshed: post-update SHA matches repo HEAD
#   S2 — clean lib untouched: mtime preserved, no UPDATED line in output
#   S3 — fresh install: all six lib files created with correct SHA256
#   S4 — modified-file fail-closed: no TTY → choice defaults N, user copy preserved
#   S5 — uninstall round-trip: all six libs in [- REMOVE]; real uninstall removes lib/ dir
#
# Total assertions: ≥15 (3 per scenario)
# Test seam env vars: TK_UPDATE_HOME, TK_UPDATE_FILE_SRC, TK_UPDATE_MANIFEST_OVERRIDE,
#                     TK_UPDATE_LIB_DIR
#
# Usage: bash scripts/tests/test-update-libs.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
```

**Assertion helpers pattern** (test-bootstrap.sh lines 31-55) — copy verbatim:

```bash
assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then assert_pass "$label"
    else assert_fail "$label" "expected='$expected' actual='$actual'"; fi
}
assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
assert_not_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if ! printf '%s\n' "$haystack" | grep -q -- "$pattern"; then assert_pass "$label"
    else
        assert_fail "$label" "unexpected pattern present: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
```

**Cross-platform sha256 helper** (test-uninstall.sh lines 62-68):

```bash
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
```

**Scenario function shape** (test-bootstrap.sh lines 70-105) — one function per scenario,
local SANDBOX, trap RETURN for cleanup:

```bash
run_s1() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1: stale lib refreshed → post-update SHA matches repo --"

    # Seed stale lib (mutate backup.sh content so SHA differs)
    mkdir -p "$SANDBOX/.claude/scripts/lib"
    printf '# stale-canary\n' > "$SANDBOX/.claude/scripts/lib/backup.sh"
    STALE_SHA="$(sha256_any "$SANDBOX/.claude/scripts/lib/backup.sh")"
    REPO_SHA="$(sha256_any "$REPO_ROOT/scripts/lib/backup.sh")"

    # Build manifest fixture with files.libs[] registered
    local MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
    jq '.version = "4.4.0" | .files.libs = [
        {"path":"scripts/lib/backup.sh"},
        {"path":"scripts/lib/bootstrap.sh"},
        {"path":"scripts/lib/dry-run-output.sh"},
        {"path":"scripts/lib/install.sh"},
        {"path":"scripts/lib/optional-plugins.sh"},
        {"path":"scripts/lib/state.sh"}
    ]' "$REPO_ROOT/manifest.json" > "$MANIFEST_FIXTURE"

    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S1: update-claude exits 0"
    local POST_SHA
    POST_SHA="$(sha256_any "$SANDBOX/.claude/scripts/lib/backup.sh")"
    assert_eq "$REPO_SHA" "$POST_SHA" "S1: post-update SHA of backup.sh matches repo HEAD"
    # stale SHA must no longer be present
    if [ "$STALE_SHA" != "$POST_SHA" ]; then
        assert_pass "S1: stale SHA replaced (file was rewritten)"
    else
        assert_fail "S1: stale SHA replaced" "SHA unchanged — file was NOT refreshed"
    fi
}
```

**S4 fail-closed pattern** (derived from RESEARCH.md Q2 — no new seam needed):

```bash
run_s4() {
    local SANDBOX RC OUTPUT
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S4: modified lib, no TTY → fail-closed to N, user copy preserved --"

    # ... seed state file with backup.sh in installed_files[] ...
    # Mutate backup.sh to trigger MODIFIED_ACTUAL path
    printf '\n# user-local modification\n' >> "$SANDBOX/.claude/scripts/lib/backup.sh"
    local MODIFIED_CONTENT
    MODIFIED_CONTENT="$(cat "$SANDBOX/.claude/scripts/lib/backup.sh")"

    # Invoke update without a TTY (subshell via $(...)) — read < /dev/tty fails,
    # update-claude.sh:804 falls through to choice="N" (fail-closed).
    RC=0
    OUTPUT=$(
        TK_UPDATE_HOME="$SANDBOX" \
        TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib" \
        TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
        TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
    ) || RC=$?

    assert_eq "0" "$RC" "S4: update exits 0 (N is non-fatal)"
    # User copy preserved — content unchanged
    assert_eq "$MODIFIED_CONTENT" "$(cat "$SANDBOX/.claude/scripts/lib/backup.sh")" \
        "S4: user-modified backup.sh preserved (fail-closed to N)"
    assert_not_contains "scripts/lib/backup.sh" "$(printf '%s\n' "$OUTPUT" | grep -i 'updated' || true)" \
        "S4: backup.sh not in UPDATED output"
}
```

**S5 uninstall round-trip pattern** (test-uninstall.sh lines 278-348 — adapted):

```bash
run_s5() {
    local SANDBOX RC_DRY RC_REAL OUTPUT_DRY OUTPUT_REAL
    SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S5: uninstall round-trip — all six libs in [- REMOVE]; lib/ dir gone --"

    # Run real update first so STATE_JSON contains the six lib paths
    TK_UPDATE_HOME="$SANDBOX" \
    TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner >/dev/null 2>&1 || true

    # --dry-run: assert all six lib paths in [- REMOVE] group
    RC_DRY=0
    OUTPUT_DRY=$(
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" --dry-run 2>&1
    ) || RC_DRY=$?
    assert_eq "0" "$RC_DRY" "S5: --dry-run exits 0"
    assert_contains "scripts/lib/backup.sh" "$OUTPUT_DRY" "S5: backup.sh in dry-run REMOVE group"

    # Real uninstall: assert lib/ dir gone
    RC_REAL=0
    OUTPUT_REAL=$(
        HOME="$SANDBOX" \
        TK_UNINSTALL_HOME="$SANDBOX" \
        TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1
    ) || RC_REAL=$?
    assert_eq "0" "$RC_REAL" "S5: real uninstall exits 0"
    if [ ! -d "$SANDBOX/.claude/scripts/lib" ]; then
        assert_pass "S5: scripts/lib/ directory removed by uninstall"
    else
        assert_fail "S5: scripts/lib/ removed" "directory still exists"
    fi
}
```

**Main runner + exit pattern** (test-bootstrap.sh lines 247-262):

```bash
echo "test-update-libs.sh: LIB-01..02 integration suite"
echo ""

run_s1
echo ""
run_s2
echo ""
run_s3
echo ""
run_s4
echo ""
run_s5

echo ""
echo "test-update-libs complete: PASS=$PASS FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

---

### `Makefile` (config, batch)

**Analog:** `Makefile` Test 28 block (lines 144-145)

**.PHONY line pattern** (line 1) — append `test-update-libs` to the existing list:

```makefile
.PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install
```

Becomes:

```makefile
.PHONY: help check check-full lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands test-matrix-bats cell-parity clean install test-update-libs
```

**Test 28 block pattern** (lines 144-145) — copy structure for Test 29. Must use TAB, not spaces:

```makefile
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "All tests passed!"
```

New Test 29 block inserted before `@echo "All tests passed!"`:

```makefile
	@echo "Test 28: bootstrap SP/GSD pre-install prompts (BOOTSTRAP-01..04)"
	@bash scripts/tests/test-bootstrap.sh
	@echo ""
	@echo "Test 29: smart-update coverage for scripts/lib/*.sh (LIB-01..02)"
	@bash scripts/tests/test-update-libs.sh
	@echo ""
	@echo "All tests passed!"
```

**`test-update-libs` standalone target pattern** — mirrors Test 28 inline; add after the `test`
target block or as a separate target for direct invocation:

```makefile
test-update-libs:
	@bash scripts/tests/test-update-libs.sh
```

---

### `.github/workflows/quality.yml` (config, batch)

**Analog:** `.github/workflows/quality.yml` `Tests 21-28` step (lines 109-118)

**Current step** (lines 109-118):

```yaml
      - name: Tests 21-28 — uninstall + banner suite + bootstrap (UN-01..UN-08, BOOTSTRAP-01..04)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
```

**Target state after Phase 22** — rename step and append one line:

```yaml
      - name: Tests 21-29 — uninstall + banner suite + bootstrap + lib coverage (UN-01..UN-08, BOOTSTRAP-01..04, LIB-01..02)
        run: |
          bash scripts/tests/test-uninstall-dry-run.sh
          bash scripts/tests/test-uninstall-backup.sh
          bash scripts/tests/test-uninstall-prompt.sh
          bash scripts/tests/test-uninstall.sh
          bash scripts/tests/test-install-banner.sh
          bash scripts/tests/test-uninstall-idempotency.sh
          bash scripts/tests/test-uninstall-state-cleanup.sh
          bash scripts/tests/test-bootstrap.sh
          bash scripts/tests/test-update-libs.sh
```

Changes: rename `Tests 21-28` → `Tests 21-29` in the `name:` field; update the tag list in
the name; append `bash scripts/tests/test-update-libs.sh` as the last line of `run:`.

---

## Shared Patterns

### Test Seam Invocation
**Source:** `scripts/tests/test-uninstall.sh` lines 94-97
**Apply to:** `scripts/tests/test-update-libs.sh` all scenarios

```bash
OUTPUT=$(HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

The analogous update-claude.sh invocation replaces `TK_UNINSTALL_*` with `TK_UPDATE_*`:

```bash
OUTPUT=$(
    TK_UPDATE_HOME="$SANDBOX" \
    TK_UPDATE_FILE_SRC="$REPO_ROOT/scripts/lib" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_LIB_DIR="$REPO_ROOT/scripts/lib" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner 2>&1
) || RC=$?
```

### Sandbox Lifecycle (trap RETURN)
**Source:** `scripts/tests/test-bootstrap.sh` lines 72-74
**Apply to:** Every `run_sN()` function in `test-update-libs.sh`

```bash
SANDBOX="$(mktemp -d /tmp/test-update-libs.XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '${SANDBOX:?}'" RETURN
```

### PASS/FAIL Exit Gate
**Source:** `scripts/tests/test-bootstrap.sh` lines 258-261
**Apply to:** `test-update-libs.sh` main block

```bash
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
```

### Manifest Fixture Construction
**Source:** RESEARCH.md §Q1 (verified pattern from `test-update-diff.sh` via TK_UPDATE_MANIFEST_OVERRIDE)
**Apply to:** All scenarios in `test-update-libs.sh` that invoke `update-claude.sh`

```bash
local MANIFEST_FIXTURE="$SANDBOX/manifest-fixture.json"
jq '.version = "4.4.0" | .files.libs = [
    {"path":"scripts/lib/backup.sh"},
    {"path":"scripts/lib/bootstrap.sh"},
    {"path":"scripts/lib/dry-run-output.sh"},
    {"path":"scripts/lib/install.sh"},
    {"path":"scripts/lib/optional-plugins.sh"},
    {"path":"scripts/lib/state.sh"}
]' "$REPO_ROOT/manifest.json" > "$MANIFEST_FIXTURE"
```

The manifest fixture must include `files.libs[]` or `update-claude.sh` fetches the remote
manifest (which on 4.3.0 does not have the new key). `TK_UPDATE_MANIFEST_OVERRIDE` routes
the update loop to use this local fixture instead.

---

## No Analog Found

All five files have close analogs. No file in this phase requires falling back to RESEARCH.md
patterns for its primary structure.

---

## Metadata

**Analog search scope:** `/Users/sergeiarutiunian/Projects/claude-code-toolkit/scripts/tests/`,
`manifest.json`, `CHANGELOG.md`, `Makefile`, `.github/workflows/quality.yml`

**Files scanned:** 7 (test-bootstrap.sh, test-uninstall.sh, manifest.json, CHANGELOG.md,
Makefile, quality.yml, test-uninstall-idempotency.sh referenced but not read — shape inferred)

**Pattern extraction date:** 2026-04-27
