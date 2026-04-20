# Phase 7: Validation - Pattern Map

**Mapped:** 2026-04-20
**Files analyzed:** 5 (3 new, 2 modified)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/validate-release.sh` | executable test runner | batch (per-cell sandbox → PASS/FAIL log) | `scripts/tests/test-migrate-flow.sh` | exact |
| `scripts/tests/test-matrix.sh` | test helper / cell wrapper | batch (compose 14 existing tests per cell) | `scripts/tests/test-update-drift.sh` | exact |
| `docs/RELEASE-CHECKLIST.md` | documentation checklist | reference doc with per-cell tables | `docs/INSTALL.md` | exact |
| `Makefile` (add targets) | config / task runner | transform (lint → assert) | `Makefile` `validate` target (lines 102-137) | exact |
| `CHANGELOG.md` (flip TBD) | changelog entry | single line edit | `CHANGELOG.md` line 8 | exact |

---

## Pattern Assignments

### `scripts/validate-release.sh` (batch runner, PASS/FAIL)

**Analog:** `scripts/tests/test-migrate-flow.sh`

**Header block** (lines 1-12 of analog):

```bash
#!/usr/bin/env bash
# validate-release.sh — Phase 7 v4.0.0 release validation matrix runner.
# Executes 13 cells (4 modes × 3 scenarios + 1 translation-sync) in sandboxed $HOME.
# Asserts 4 invariants per cell. Fail-fast on first red cell.
# Usage: bash scripts/validate-release.sh
# Exit: 0 = all cells PASS, 1 = first FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
```

**Color constants** (detect.sh lines 15-25, used verbatim in every script):

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

**PASS/FAIL counters + reporter functions** (test-migrate-flow.sh lines 24-32):

```bash
PASS=0
FAIL=0

assert_eq() {
    local expected="$1" actual="$2" msg="$3"
    if [ "${expected}" = "${actual}" ]; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
    fi
}
```

**Per-cell sandbox setup** (test-migrate-flow.sh lines 46-47 + Makefile lines 46-48):

```bash
# Sandbox per cell: rm-rf on ENTRY (idempotent), NOT on exit (post-mortem survives)
CELL_HOME="/tmp/tk-matrix-${CELL_NAME}-$(date +%s)"
rm -rf "${CELL_HOME}"
mkdir -p "${CELL_HOME}/.claude"
```

Pattern from Makefile test target (exact shape to replicate per cell):

```makefile
@rm -rf /tmp/test-claude-laravel
@mkdir -p /tmp/test-claude-laravel
@cd /tmp/test-claude-laravel && touch artisan && bash $(PWD)/scripts/init-local.sh >/dev/null
@test -f /tmp/test-claude-laravel/.claude/prompts/SECURITY_AUDIT.md && echo "✅ Laravel init works"
```

**Sourcing lib/ inside runner** (test-modes.sh lines 9-10, 23):

```bash
INSTALL_LIB="$(cd "$(dirname "$0")/../lib" && pwd)/install.sh"
[ -f "$INSTALL_LIB" ] || { echo "ERROR: lib/install.sh not found at $INSTALL_LIB"; exit 1; }
# shellcheck source=/dev/null
source "$INSTALL_LIB"
```

**Invariant 2 — toolkit-install.json jq schema check** (test-migrate-flow.sh lines 125-129):

```bash
assert_eq "complement-sp" "$(jq -r .mode "$SCR/.claude/toolkit-install.json")" \
    "state.mode = complement-sp after migration"
assert_eq "0" "$(jq -r '.skipped_files | length' "$SCR/.claude/toolkit-install.json")" \
    "skipped_files is empty under accept-all"
```

Full required fields per D-03 (compose into a `assert_state_schema` helper):

```bash
assert_state_schema() {
    local state_file="$1" expected_mode="$2"
    # mode
    assert_eq "$expected_mode" "$(jq -r .mode "$state_file")" "state.mode = $expected_mode"
    # detected present
    assert_eq "object" "$(jq -r '.detected | type' "$state_file")" "state.detected is object"
    # installed_files[].{path,sha256,installed_at} all present
    local bad_entries
    bad_entries=$(jq '[.installed_files[] | select(.path == null or .sha256 == null or .installed_at == null)] | length' "$state_file")
    assert_eq "0" "$bad_entries" "all installed_files entries have path+sha256+installed_at"
    # skipped_files[].{path,reason} present
    local bad_skips
    bad_skips=$(jq '[.skipped_files[] | select(.path == null or .reason == null)] | length' "$state_file")
    assert_eq "0" "$bad_skips" "all skipped_files entries have path+reason"
}
```

**Invariant 3 — settings.json foreign-key preservation** (test-safe-merge.sh lines 43-59 pattern):

```bash
# Before: snapshot keys outside TK ownership (hooks.PreToolUse, enabledPlugins, user_setting_unrelated)
BEFORE_FOREIGN=$(jq '{hooks: .hooks, enabledPlugins: .enabledPlugins, user_setting_unrelated: .user_setting_unrelated}' \
    "${CELL_HOME}/.claude/settings.json" 2>/dev/null || echo '{}')
# ... run installer ...
AFTER_FOREIGN=$(jq '{hooks: .hooks, enabledPlugins: .enabledPlugins, user_setting_unrelated: .user_setting_unrelated}' \
    "${CELL_HOME}/.claude/settings.json" 2>/dev/null || echo '{}')
assert_eq "$BEFORE_FOREIGN" "$AFTER_FOREIGN" "settings.json foreign keys byte-identical pre/post"
```

**Invariant 4 — skip-list / no-conflict-file check** (test-modes.sh lines 29-35):

```bash
# Source lib/install.sh for compute_skip_set
skip_set=$(compute_skip_set "$MODE" "$MANIFEST")
# Assert no file in skip_set landed in CELL_HOME/.claude/
while IFS= read -r skip_path; do
    assert_eq "false" \
        "$( [ -f "${CELL_HOME}/.claude/${skip_path}" ] && echo true || echo false )" \
        "complement mode: skipped file ${skip_path} not installed"
done < <(jq -r '.[]' <<<"$skip_set")
```

**VALIDATE-03 agent collision check** (test-update-drift.sh lines 255-263 pattern):

```bash
# complement-sp / complement-full cells only
local SP_AGENTS="${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers"
local TK_AGENTS="${CELL_HOME}/.claude/agents"
if [ -d "$SP_AGENTS" ] && [ -d "$TK_AGENTS" ]; then
    while IFS= read -r sp_agent; do
        basename="$(basename "$sp_agent")"
        assert_eq "false" \
            "$( [ -f "${TK_AGENTS}/${basename}" ] && echo true || echo false )" \
            "no TK agent collides with SP agent: $basename"
    done < <(find "$SP_AGENTS" -name '*.md' -mindepth 3 -maxdepth 3)
fi
```

**Backup verification pattern** (test-migrate-flow.sh lines 120-123):

```bash
local BACKUPS
BACKUPS=$(find "$SCR" -maxdepth 1 -type d -name ".claude-backup-pre-migrate-*" | wc -l | tr -d " ")
assert_eq "1" "$BACKUPS" "1 pre-migrate backup dir created"
```

**Final summary + exit** (test-migrate-flow.sh lines 424-429):

```bash
echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================"
[ "${FAIL}" -gt 0 ] && exit 1
exit 0
```

**v3.x upgrade simulation** (test-update-drift.sh lines 42-75 pattern):

```bash
scenario_v3x_upgrade_path() {
    local SCR="${TMPDIR_ROOT}/s1"
    mkdir -p "$SCR/.claude/commands" "$SCR/.claude/rules"
    echo "PLAN-CONTENT" > "$SCR/.claude/commands/plan.md"
    # Run update-claude.sh with no pre-existing state.
    local EMPTY_SRC="$SCR/.empty-src"; mkdir -p "$EMPTY_SRC"
    TK_UPDATE_HOME="$SCR" \
    TK_UPDATE_LIB_DIR="$LIB_DIR" \
    TK_UPDATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
    TK_UPDATE_FILE_SRC="$EMPTY_SRC" \
    HAS_SP=false HAS_GSD=false SP_VERSION="" GSD_VERSION="" \
    bash "$REPO_ROOT/scripts/update-claude.sh" --no-banner --no-offer-mode-switch 2>&1 || true
    assert_eq "true" "$( [ -f "$SCR/.claude/toolkit-install.json" ] && echo true || echo false )" \
        "synthesized state file exists"
}
```

**Env-override pattern for sandbox isolation** (test-migrate-flow.sh lines 103-110):

```bash
HOME="$SCR" \
TK_MIGRATE_HOME="$SCR" \
TK_MIGRATE_LIB_DIR="$LIB_DIR" \
TK_MIGRATE_MANIFEST_OVERRIDE="$MANIFEST_FIXTURE" \
TK_MIGRATE_FILE_SRC="$FILE_SRC" \
TK_MIGRATE_SP_CACHE_DIR="$SP_CACHE_FIXTURE_FULL" \
HAS_SP=true HAS_GSD=false SP_VERSION="5.0.7" GSD_VERSION="" \
bash "$REPO_ROOT/scripts/migrate-to-complement.sh" --yes >/dev/null 2>&1 || true
```

Same pattern for `init-claude.sh` cells: use `HOME=`, `TK_INSTALL_HOME=`, `TK_INSTALL_LIB_DIR=`, `TK_INSTALL_MANIFEST_OVERRIDE=`, `TK_INSTALL_FILE_SRC=` overrides (verify exact env-var names against the script before implementing).

---

### `scripts/tests/test-matrix.sh` (test helper / cell wrapper)

**Analog:** `scripts/tests/test-update-drift.sh`

This file acts as the 15th entry in the Makefile `test:` target. It composes the existing 14 test scripts rather than re-implementing their assertions. Its own value is:

1. Providing the full install-matrix sandbox (HOME isolation per cell).
2. Running the 4 D-03 invariants across all 13 cells.
3. Calling existing test scripts for per-feature atomic checks where appropriate.

**Script skeleton** (adapt from test-update-drift.sh lines 14-48):

```bash
#!/usr/bin/env bash
# test-matrix.sh — Phase 7 full install matrix (Test 15).
# Runs 13 cells (4 modes × 3 scenarios + 1 translation-sync).
# Composes existing test scripts for per-feature assertions.
# Usage: bash scripts/tests/test-matrix.sh
# Exit: 0 = all cells PASS, 1 = first FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB_DIR="${REPO_ROOT}/scripts/lib"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

TMPDIR_ROOT="$(mktemp -d -t tk-matrix.XXXXXX)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT
```

**Composing existing tests per cell** (logical pattern — not in any single analog but implied by D-03 + CONTEXT.md §Reusable Assets):

```bash
run_cell_invariants() {
    local cell_name="$1" cell_home="$2" mode="$3"
    # Invariant 1: exit 0 already asserted inline before this call
    # Invariant 2: toolkit-install.json schema
    assert_state_schema "${cell_home}/.claude/toolkit-install.json" "$mode"
    # Invariant 3: settings.json foreign-key preservation (only if settings.json exists)
    # Invariant 4: skip-list none landed
    assert_skiplist_clean "${cell_home}" "$mode"
}
```

---

### `docs/RELEASE-CHECKLIST.md` (documentation checklist)

**Analog:** `docs/INSTALL.md`

**Document header pattern** (INSTALL.md lines 1-8):

```markdown
# Release Checklist — v4.0.0

This document is the human sign-off surface for the v4.0.0 release.
Each cell maps 1:1 to a cell in `docs/INSTALL.md` and to an assertion
in `scripts/validate-release.sh`. Run the runner, then tick each checkbox.

---
```

**Per-cell table format** (INSTALL.md lines 31-35 — use same pipe-table with a Checkbox column added):

```markdown
## Mode: standalone

| Scenario | Precondition | Command | Expected output | Auto-checked | Human sign-off |
|----------|-------------|---------|-----------------|--------------|----------------|
| **Fresh install** | No SP, no GSD; no prior TK. | `bash scripts/validate-release.sh --cell standalone-fresh` | `PASS: standalone-fresh` | `validate-release.sh` | `[ ]` |
| **Upgrade from v3.x** | v3.x TK present, no state file. | `bash scripts/validate-release.sh --cell standalone-upgrade` | `PASS: standalone-upgrade` | `validate-release.sh` | `[ ]` |
| **Re-run / idempotent** | TK installed, manifest unchanged. | `bash scripts/validate-release.sh --cell standalone-rerun` | `PASS: standalone-rerun` | `validate-release.sh` | `[ ]` |
```

**Translation-sync cell** (13th cell, no equivalent in INSTALL.md):

```markdown
## Translation Sync

| Check | Command | Expected | Auto-checked | Human sign-off |
|-------|---------|----------|--------------|----------------|
| **README translations line-count drift** | `make translation-drift` | All 8 translation files within ±20% of README.md line count | `make check` | `[ ]` |
```

**Style rules from INSTALL.md (copy verbatim):**

- All fenced code blocks declare language (`bash`, `text`, etc.) — MD040 rule
- Blank lines before and after fenced code blocks — MD031 rule
- Blank lines before and after lists — MD032 rule
- No trailing punctuation in headings — MD026 rule

---

### `Makefile` — add `version-align` and `translation-drift` targets

**Analog:** Makefile `validate` target (lines 102-137)

**Existing `validate` target structure to match** (lines 102-128):

```makefile
validate:
	@echo "Validating templates..."
	@ERRORS=0; \
	for f in $$(find templates -path '*/prompts/*.md' ...); do \
		if ! grep -q "QUICK CHECK" "$$f" 2>/dev/null; then \
			echo "❌ Missing QUICK CHECK: $$f"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS errors"; \
		exit 1; \
	fi
	@MANIFEST_VER=$$(grep -m1 '"version"' manifest.json | sed 's/.*"version": *"\([^"]*\)".*/\1/'); \
		CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
		if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
			echo "❌ Version mismatch: manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; \
			exit 1; \
		fi; \
		echo "✅ Version aligned: $$MANIFEST_VER"
```

**`version-align` target** — reads 3 sources (manifest.json, CHANGELOG.md, init-local.sh --version):

```makefile
version-align:
	@echo "Checking version alignment..."
	@MANIFEST_VER=$$(jq -r '.version' manifest.json); \
	CHANGELOG_VER=$$(grep -m1 '^## \[[0-9]' CHANGELOG.md | sed 's/.*\[\([^]]*\)\].*/\1/'); \
	SCRIPT_VER=$$(bash scripts/init-local.sh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	ERRORS=0; \
	if [ "$$MANIFEST_VER" != "$$CHANGELOG_VER" ]; then \
		echo "❌ manifest.json=$$MANIFEST_VER, CHANGELOG.md=$$CHANGELOG_VER"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ "$$MANIFEST_VER" != "$$SCRIPT_VER" ]; then \
		echo "❌ manifest.json=$$MANIFEST_VER, init-local.sh --version=$$SCRIPT_VER"; ERRORS=$$((ERRORS+1)); \
	fi; \
	if [ "$$ERRORS" -gt 0 ]; then exit 1; fi; \
	echo "✅ Version aligned: $$MANIFEST_VER"
```

**`translation-drift` target** — line-count within ±20%:

```makefile
translation-drift:
	@echo "Checking translation drift..."
	@README_LINES=$$(wc -l < README.md); \
	ERRORS=0; \
	for f in docs/readme/de.md docs/readme/es.md docs/readme/fr.md docs/readme/ja.md \
	          docs/readme/ko.md docs/readme/pt.md docs/readme/ru.md docs/readme/zh.md; do \
		if [ ! -f "$$f" ]; then \
			echo "❌ Missing translation: $$f"; ERRORS=$$((ERRORS+1)); continue; \
		fi; \
		LINES=$$(wc -l < "$$f"); \
		MIN=$$(( README_LINES * 80 / 100 )); \
		MAX=$$(( README_LINES * 120 / 100 )); \
		if [ "$$LINES" -lt "$$MIN" ] || [ "$$LINES" -gt "$$MAX" ]; then \
			echo "❌ $$f: $$LINES lines outside ±20% of README.md $$README_LINES"; ERRORS=$$((ERRORS+1)); \
		fi; \
	done; \
	if [ "$$ERRORS" -gt 0 ]; then exit 1; fi; \
	echo "✅ All translation files within ±20% of README.md"
```

**Wire both into `check` target** — existing line 17:

```makefile
# BEFORE:
check: lint validate validate-base-plugins

# AFTER:
check: lint validate validate-base-plugins version-align translation-drift
```

**`.PHONY` declaration** — extend existing line 1:

```makefile
.PHONY: help check lint shellcheck mdlint test validate validate-base-plugins version-align translation-drift clean install
```

**Makefile `test:` target — add Test 15** (after line 97, before final echo):

```makefile
	@echo "Test 15: full install matrix"
	@bash scripts/tests/test-matrix.sh
	@echo ""
```

---

### `CHANGELOG.md` — flip `[4.0.0] - TBD`

**Single-line edit** — line 8:

```markdown
# BEFORE:
## [4.0.0] - TBD

# AFTER (fill date at phase-completion commit time):
## [4.0.0] - 2026-MM-DD
```

No analog needed — this is a mechanical substitution. The version string `4.0.0` is already validated by `validate` / `version-align` to match `manifest.json`.

---

## Shared Patterns

### `set -euo pipefail` + POSIX header

**Source:** every script in `scripts/` and `scripts/tests/`
**Apply to:** `validate-release.sh`, `test-matrix.sh`

```bash
set -euo pipefail
```

Note: sourced libraries (`scripts/lib/*.sh`, `scripts/detect.sh`) deliberately omit this — do NOT add it there.

### Color constants

**Source:** `scripts/detect.sh` lines 15-25, `scripts/lib/install.sh` lines 13-17, `scripts/init-claude.sh` lines 11-15
**Apply to:** `validate-release.sh`

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
```

`test-matrix.sh` may omit `BLUE`/`CYAN` — pattern varies per test file; match `test-migrate-flow.sh` (no color constants, plain `echo` output).

### Idempotent file-existence guard

**Source:** throughout install scripts
**Apply to:** any cell setup in `validate-release.sh` / `test-matrix.sh`

```bash
[ -f "$file" ] || cp "$src" "$file"
mkdir -p "$(dirname "$target")"
```

### Backup naming convention

**Source:** established in Phase 4, used in `test-migrate-flow.sh` lines 120-123
**Apply to:** any backup existence assertion in matrix cells

```bash
# Pattern: .claude-backup-<ts>-<pid>/ or .claude-backup-pre-migrate-<ts>/
find "$CELL_HOME" -maxdepth 1 -type d -name ".claude-backup-*"
```

### `jq` for all JSON assertions

**Source:** `scripts/lib/install.sh` `compute_skip_set`, `scripts/lib/state.sh` `write_state`, test scripts throughout
**Apply to:** all 4 D-03 invariant checks in `validate-release.sh`

`jq` is a hard dependency — do NOT add python3 fallback for JSON assertions in test scripts.

### macOS BSD compatibility

**Source:** `scripts/lib/state.sh` lines 25-29 (`get_mtime`), `scripts/tests/test-dry-run.sh` lines 22-28 (`md5_any`)
**Apply to:** any `wc`, `stat`, `date`, `find`, `sed` call in new scripts

```bash
# Cross-platform stat mtime:
if [[ "$(uname)" == "Darwin" ]]; then
    stat -f %m "$path" 2>/dev/null || echo 0
else
    stat -c %Y "$path" 2>/dev/null || echo 0
fi

# Use TMPDIR:-/tmp workaround for mktemp:
mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"
# OR use -t flag (works on both):
mktemp -d -t name.XXXXXX
```

Avoid `find -printf`, `sed -i ''` vs `sed -i`, `wc -l` with leading spaces (use `tr -d ' '`).

### ANSI auto-disable when stdout is not a tty

**Source:** `scripts/lib/install.sh` lines 77-80 (`print_dry_run_grouped`)
**Apply to:** `validate-release.sh` output (runner may be piped into CI logs)

```bash
if [ -t 1 ]; then
    _GREEN='\033[0;32m'; _RED='\033[0;31m'; _NC='\033[0m'
else
    _GREEN=''; _RED=''; _NC=''
fi
```

### `assert_contains` helper

**Source:** `scripts/tests/test-migrate-flow.sh` lines 36-44
**Apply to:** `validate-release.sh` / `test-matrix.sh` for stdout content checks

```bash
assert_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if echo "$haystack" | grep -q -- "$needle"; then
        PASS=$((PASS + 1)); echo "  ✓ ${msg}"
    else
        FAIL=$((FAIL + 1)); echo "  ✗ ${msg}"
        echo "    expected substring: ${needle}"
    fi
}
```

### Fail-fast pattern (D-02)

Existing test scripts exit 1 if any `FAIL > 0` at the end. `validate-release.sh` must exit at the **first** red cell (fail-fast semantics match `make check`). Use:

```bash
run_cell() {
    local cell_name="$1"
    local CELL_PASS=0 CELL_FAIL=0
    # ... assertions update CELL_PASS/CELL_FAIL ...
    if [ "$CELL_FAIL" -gt 0 ]; then
        echo "FAIL: ${cell_name}: ${CELL_FAIL} assertion(s) failed"
        exit 1   # fail-fast — no --collect-all in v4.0
    fi
    echo "PASS: ${cell_name}"
    PASS=$((PASS + CELL_PASS))
}
```

---

## No Analog Found

All files have close analogs. No entries in this section.

---

## Integration Points

### `validate-release.sh` sources

```text
scripts/detect.sh          → source for HAS_SP / HAS_GSD detection
scripts/lib/install.sh     → source for compute_skip_set (Invariant 4)
scripts/lib/state.sh       → source for sha256_file (Invariant 2 hash verification)
```

Guard pattern from `test-modes.sh` lines 9-11:

```bash
INSTALL_LIB="$(cd "$(dirname "$0")/../lib" && pwd)/install.sh"
[ -f "$INSTALL_LIB" ] || { echo "ERROR: lib/install.sh not found at $INSTALL_LIB"; exit 1; }
```

### `test-matrix.sh` composes existing tests

`test-matrix.sh` invokes the 14 existing test scripts for their specific feature assertions. Do NOT re-implement what they already cover. Only add the 4 D-03 cross-cell invariants as new assertions.

Composition call pattern:

```bash
echo "Running atomic feature tests..."
bash "${SCRIPT_DIR}/test-detect.sh"
bash "${SCRIPT_DIR}/test-state.sh"
# ... etc for all 14 ...
echo "Running install matrix cells..."
run_cell "standalone-fresh"
# ... etc for 13 cells ...
```

### New Makefile targets slot into `check`

Current: `check: lint validate validate-base-plugins`
After phase 7: `check: lint validate validate-base-plugins version-align translation-drift`

Both new targets follow the exact same `@ERRORS=0; ...; if [ $$ERRORS -gt 0 ]; then exit 1; fi; @echo "✅ ..."` shape already used in `validate` (lines 104-128).

### `.github/workflows/quality.yml`

No changes needed — CI already runs `make check`. New targets ride the existing workflow.

---

## Metadata

**Analog search scope:** `scripts/tests/`, `scripts/lib/`, `scripts/`, `Makefile`, `docs/`
**Key files scanned:** 10
**Pattern extraction date:** 2026-04-20
