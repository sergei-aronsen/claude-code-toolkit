# Phase 20: Distribution + Tests — Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 8 (2 new, 6 modified)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/tests/test-uninstall.sh` | test | request-response (round-trip) | `scripts/tests/test-uninstall-state-cleanup.sh` | exact |
| `scripts/tests/test-install-banner.sh` | test | transform (source-grep) | `Makefile` validate target + `test-uninstall-idempotency.sh` | role-match |
| `manifest.json` | config | transform | `manifest.json` itself (existing `files.*` arrays) | exact |
| `CHANGELOG.md` | config | transform | `CHANGELOG.md` `[4.2.0]` entry (lines 8-57) | exact |
| `scripts/init-local.sh` | config | request-response | `scripts/update-claude.sh` (NO_BANNER + Restart echo) | role-match |
| `scripts/init-claude.sh` | config | request-response | `scripts/init-claude.sh` lines 904-905 (existing final echo) | exact |
| `scripts/update-claude.sh` | config | request-response | `scripts/update-claude.sh` lines 1006-1007 (existing Restart echo) | exact |
| `Makefile` | config | batch | `Makefile` lines 115-122 (Test 21-23 slot pattern) | exact |

---

## Pattern Assignments

### `scripts/tests/test-uninstall.sh` (test, round-trip integration)

**Primary Analog:** `scripts/tests/test-uninstall-state-cleanup.sh`
**Secondary Analog:** `scripts/tests/test-uninstall-prompt.sh` (for stdin injection pattern)

**File header comment** (analog: state-cleanup.sh lines 1-23):

```bash
#!/usr/bin/env bash
# test-uninstall.sh — UN-08 round-trip integration test.
#
# Runs the REAL init-local.sh against a /tmp/ sandbox, then runs the REAL
# uninstall.sh. No synthetic state-file fabrication — proves the install→uninstall
# contract end-to-end.
#
# Five scenario blocks:
#   S1 — clean round-trip (no modifications)
#   S2 — modified file, choice "y" (remove)
#   S3 — modified file, choice "N" (keep, default)
#   S4 — modified file, choice "d" then "N" (diff → keep)
#   S5 — --dry-run zero-mutation + double-uninstall idempotency
#
# Usage: bash scripts/tests/test-uninstall.sh
# Exit:  0 = all assertions passed, 1 = any failed
```

**Strict mode + repo root** (analog: state-cleanup.sh lines 24-27):

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

**Color constants** (identical in all 5 analogs — state-cleanup.sh lines 29-31):

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
```

**Counter variables** (all analogs):

```bash
PASS=0
FAIL=0
```

**Assert helpers — verbatim copy from state-cleanup.sh lines 36-65**:

```bash
assert_pass() {
    PASS=$((PASS + 1))
    printf "  ${GREEN}OK${NC} %s\n" "$1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$1"
    printf "      %s\n" "$2"
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_contains() {
    local pattern="$1" haystack="$2" label="$3"
    if printf '%s\n' "$haystack" | grep -q -- "$pattern"; then
        assert_pass "$label"
    else
        assert_fail "$label" "pattern not found: $pattern"
        printf '      output excerpt:\n'
        printf '%s\n' "$haystack" | head -15 | sed 's/^/        /'
    fi
}
```

**sha256_any helper — verbatim copy from state-cleanup.sh lines 68-74**:

```bash
sha256_any() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
```

**Sandbox naming convention** (D-04: disambiguates from 5 unit test prefixes):

```bash
# Sandbox prefix used in all scenarios: /tmp/test-uninstall-roundtrip.XXXXXX
# (compare: unit tests use uninstall-dryrun, uninstall-backup, uninstall-prompt,
#  uninstall-idempotency, uninstall-state — never "roundtrip")
SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
```

**Trap pattern with :? guard** (analog: state-cleanup.sh line 81 — safer than backup.sh line 77):

```bash
# PREFERRED — uses :? so trap fails fast if SANDBOX is somehow empty
trap 'rm -rf "${SANDBOX:?}"' EXIT
```

**Env-var seams — all three required** (analog: state-cleanup.sh lines 83-84, prompt.sh lines 85-86):

```bash
export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"
# For S2/S3/S4 only (MODIFIED-file scenarios need stdin injection):
export TK_UNINSTALL_TTY_FROM_STDIN=1
```

**Invoking init-local.sh against sandbox** (unique to round-trip test — D-02):

```bash
# init-local.sh is invoked by cd-ing into the sandbox then running it.
# Pattern mirrors Makefile Test 1-3 (lines 47-50 in Makefile).
(cd "$SANDBOX" && bash "$REPO_ROOT/scripts/init-local.sh" >/dev/null 2>&1)
```

**Invoking uninstall.sh with HOME override** (analog: state-cleanup.sh line 150):

```bash
OUTPUT_RUN1=""
RC_RUN1=0
OUTPUT_RUN1=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC_RUN1=$?
```

**Stdin injection for MODIFIED scenarios** (analog: prompt.sh lines 142-152):

```bash
STDIN_INPUT=$(printf 'y\n')   # S2: y branch
# or:
STDIN_INPUT=$(printf 'd\nN\n')  # S4: d then N branch

OUTPUT=$(printf '%s' "$STDIN_INPUT" | \
    HOME="$SANDBOX" \
    TK_UNINSTALL_HOME="$SANDBOX" \
    TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib" \
    TK_UNINSTALL_TTY_FROM_STDIN=1 \
    bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

**toolkit-install.json fixture shape** (analog: state-cleanup.sh lines 127-143):

```bash
cat > "$SANDBOX/.claude/toolkit-install.json" <<EOF
{
  "version": 2,
  "mode": "standalone",
  "synthesized_from_filesystem": false,
  "detected": {
    "superpowers": {"present": false, "version": ""},
    "gsd":         {"present": false, "version": ""}
  },
  "installed_files": [
    {"path": ".claude/commands/clean.md", "sha256": "$SHA_CLEAN", "installed_at": "2026-04-26T00:00:00Z"}
  ],
  "skipped_files": [],
  "manifest_hash": "deadbeef",
  "installed_at": "2026-04-26T00:00:00Z"
}
EOF
```

NOTE: For S1 (clean round-trip), the state file is produced by `init-local.sh` itself — no manual fixture needed. For S2-S4 (MODIFIED scenarios), the test modifies a tracked file after install, then re-runs uninstall.

**S1 key assertion — clean round-trip** (D-03 criterion):

```bash
# After install -> uninstall with no modifications:
FILE_COUNT="$(find "$SANDBOX/.claude" -type f | wc -l | tr -d '[:space:]')"
assert_eq "0" "$FILE_COUNT" "S1: find .claude -type f == 0 after clean round-trip"
# toolkit-install.json must also be absent (state cleanup)
if [ ! -f "$SANDBOX/.claude/toolkit-install.json" ]; then
    assert_pass "S1: toolkit-install.json absent after clean uninstall"
else
    assert_fail "S1: toolkit-install.json absent" "file still present"
fi
```

**S5 double-uninstall assertion** (analog: state-cleanup.sh lines 226-231, idempotency.sh lines 93-99):

```bash
# Second invocation on already-uninstalled sandbox:
if [ "$RC_RUN2" -eq 0 ] && printf '%s\n' "$OUTPUT_RUN2" | grep -qF 'Toolkit not installed; nothing to do'; then
    assert_pass "S5: second invocation is a no-op (UN-06 idempotency)"
else
    assert_fail "S5: second invocation is a no-op" \
        "RC=$RC_RUN2; output: $(printf '%s\n' "$OUTPUT_RUN2" | head -3)"
fi
```

**Summary block — copy from state-cleanup.sh lines 236-249**:

```bash
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✓ test-uninstall: all N assertions passed${NC}\n"
    exit 0
else
    printf "${RED}✗ test-uninstall: $FAIL of $((PASS + FAIL)) assertions FAILED${NC}\n"
    echo ""
    echo "Full output (last scenario run):"
    printf '%s\n' "$OUTPUT"
    exit 1
fi
```

**Critical pitfall — Makefile Test 1-3 only works with `cd`:**
`init-local.sh` uses relative `.claude/` path; it must be invoked from inside the sandbox dir. The `(cd "$SANDBOX" && bash ...)` subshell pattern is required.

**Critical pitfall — S1 file count:**
After a real `init-local.sh` run, `.claude/` contains many files. After `uninstall.sh`, the test asserts `find .claude -type f | wc -l = 0`. This will only pass if `init-local.sh` records every installed file in `toolkit-install.json` AND `uninstall.sh` removes them all. If any file is untracked, the count will be non-zero. Use `commands/clean.md` as the canary from Phase 19 convention.

---

### `scripts/tests/test-install-banner.sh` (test, source-grep)

**Primary Analog:** Makefile `validate` target (lines 129-146) — source-grep pattern with ERRORS counter
**Secondary Analog:** `scripts/tests/test-uninstall-idempotency.sh` — minimal test structure

**File header** (follow idempotency.sh style):

```bash
#!/usr/bin/env bash
# test-install-banner.sh — banner line presence gate (UN-07 / D-09).
#
# Source-greps each installer for the locked "To remove:" banner line.
# No network, no /tmp churn, runs in milliseconds.
#
# Assertions (3 total):
#   A1. scripts/init-claude.sh contains the locked banner line
#   A2. scripts/init-local.sh contains the locked banner line
#   A3. scripts/update-claude.sh contains the locked banner line
#
# Usage: bash scripts/tests/test-install-banner.sh
# Exit:  0 = all 3 assertions passed, 1 = any failed
```

**Core grep pattern** (D-09: grep -F for literal string match, -c for count):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BANNER='To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)'

check_banner() {
    local file="$1" label="$2"
    local count
    count=$(grep -cF "$BANNER" "$REPO_ROOT/$file" 2>/dev/null || true)
    if [ "$count" -eq 1 ]; then
        assert_pass "$label"
    else
        assert_fail "$label" "expected exactly 1 match, got $count in $file"
    fi
}
```

**Invocation** (D-09 — one grep three times):

```bash
check_banner "scripts/init-claude.sh"    "A1: init-claude.sh contains banner line (exactly once)"
check_banner "scripts/init-local.sh"     "A2: init-local.sh contains banner line (exactly once)"
check_banner "scripts/update-claude.sh"  "A3: update-claude.sh contains banner line (exactly once)"
```

**Critical pitfall — no shell color codes in banner string:**
The locked banner wording is `To remove: bash <(curl -sSL ...)` — no `echo -e`, no `${YELLOW}`, no `${NC}`. The `grep -cF` (fixed string, not regex) match will fail if the installer wraps the echo with ANSI codes embedded in the string being grepped.

**Critical pitfall — grep -c vs grep -q:**
Use `-c` (count), not `-q` (quiet), so the test can assert `count -eq 1` (exactly once, not zero-or-more). This catches accidental duplication.

---

### `manifest.json` (config, schema extension)

**Analog:** existing `files.rules` array at manifest.json lines 205-215 — simplest existing array (no `conflicts_with`, no `sp_equivalent`):

```json
"rules": [
  {
    "path": "rules/README.md"
  },
  {
    "path": "rules/project-context.md"
  },
  {
    "path": "rules/audit-exceptions.md"
  }
]
```

**New `files.scripts` array to add** (D-10 — after `"rules"` close bracket, before `"inventory"`):

```json
"scripts": [
  {
    "path": "scripts/uninstall.sh"
  }
]
```

**Version bump** (D-12 — two fields at top of file, lines 3-4):

```json
"version": "4.3.0",
"updated": "YYYY-MM-DD",
```

**Critical pitfall — version-align gate:**
`make check version-align` (Makefile lines 202-224) runs `jq -r '.version' manifest.json` and compares against `CHANGELOG.md` top `## [X.Y.Z]` header AND `bash scripts/init-local.sh --version`. All three must change to `4.3.0` in the same plan commit or the gate fails.

**Critical pitfall — validate-manifest.py:**
`make validate` calls `python3 scripts/validate-manifest.py` (Makefile line 189). If `files.scripts` is a new key, verify the validator does not enforce a closed schema. If it does, the validator script must also be updated to accept `scripts`.

---

### `CHANGELOG.md` (config, additive entry)

**Analog:** `CHANGELOG.md` lines 8-57 — the `[4.2.0]` entry:

```markdown
## [4.2.0] - 2026-04-26

### Added

- **Feature name** — description of capability covering REQ-IDs.
  Continues on next line with more detail if needed.
- **Another feature** — description.

### Changed

- **`filename`** — what changed and why.

### Fixed

- _None — this is an additive feature release. See [4.1.1] for the prior patch._
```

**New `[4.3.0]` entry structure** (D-13 — `Added` only, no `Changed`/`Fixed`/`Removed`):

```markdown
## [4.3.0] - YYYY-MM-DD

### Added

- **Uninstall script** (`scripts/uninstall.sh`) — ...
  - UN-01: removes registered files by SHA256 hash match; never touches base plugins
  - UN-02: `--dry-run` prints 4-group removal plan, exits 0, zero filesystem changes
  - UN-03: modified files trigger `[y/N/d]` prompt; `d` shows diff and re-prompts
  - UN-04: full `.claude/` backup written to `~/.claude-backup-pre-uninstall-<ts>/`
- **State cleanup + idempotency** — ...
  - UN-05: strips `<!-- TOOLKIT-START -->…<!-- TOOLKIT-END -->` from `~/.claude/CLAUDE.md`
  - UN-06: second invocation exits 0 with "Toolkit not installed; nothing to do"
- **Distribution** — `manifest.json` registers `scripts/uninstall.sh` under `files.scripts[]`;
  installer banners add `To remove: bash <(curl -sSL .../scripts/uninstall.sh)` (UN-07)
- **Round-trip test** — `scripts/tests/test-uninstall.sh` (Makefile Test 24) exercises full
  install→uninstall round-trip with 5 scenario blocks (UN-08);
  `scripts/tests/test-install-banner.sh` (Test 25) gates banner presence in all 3 installers
```

**Bullet style rules** (from `[4.2.0]` observation):

- Bold the feature name with backtick for file path: `**Feature name** (\`path\`)`
- Em dash separates name from description: `—`
- Sub-bullets use indented `  - ` (2 spaces + dash)
- No trailing period on bullets
- Blank line between top-level bullets

**Critical pitfall — placeholder date:**
D-15 locks `YYYY-MM-DD` as literal placeholder. `make check version-align` (Makefile lines 175-181) only checks `[4.2.0]` == `[4.3.0]` version number match, not the date format — so the placeholder is safe until tag commit.

---

### `scripts/init-local.sh` (modified — banner + version bump)

**Analog:** `scripts/update-claude.sh` lines 1006-1007 — existing final echo pattern:

```bash
echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
```

**Current end of init-local.sh** (lines 417-425 — exact anchor):

```bash
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit .claude/CLAUDE.md — add project-specific info"
echo "2. Edit .claude/rules/project-context.md — add architecture facts"
echo "3. Restart Claude Code to apply changes"
echo ""
echo -e "${BLUE}Security setup (recommended):${NC}"
echo "  $GUIDES_DIR/scripts/setup-security.sh"
echo ""
```

**New banner echo placement** (D-07: directly after last `echo ""` at line 425):

```bash
echo "To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)"
```

**Version source** (init-local.sh lines 17-23 — version is read dynamically from manifest.json):

```bash
MANIFEST_FILE="$GUIDES_DIR/manifest.json"
if command -v jq &>/dev/null && [[ -f "$MANIFEST_FILE" ]]; then
    VERSION=$(jq -r '.version' "$MANIFEST_FILE")
elif [[ -f "$MANIFEST_FILE" ]]; then
    VERSION=$(grep -m1 '"version"' "$MANIFEST_FILE" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
else
    VERSION="unknown"
fi
```

**Critical insight — no `--version` string literal to bump:**
`init-local.sh` reads its version from `manifest.json` at runtime (lines 17-23 above). There is NO hardcoded version string in `init-local.sh` itself. The `version-align` gate works because `bash scripts/init-local.sh --version` (Makefile line 206) triggers the runtime read. Therefore: bumping `manifest.json` `version` to `4.3.0` automatically makes `init-local.sh --version` return `4.3.0`. No separate edit to `init-local.sh` is needed for the version field.

**Critical pitfall — no color codes on banner echo:**
The banner line must use plain `echo` (no `-e`), no `${YELLOW}` / `${NC}` wrappers. The source-grep test uses `-F` (fixed string). Any ANSI escape codes embedded in the echo string would not appear in the source file text anyway, but `echo -e "${YELLOW}To remove...${NC}"` changes the source line structure and breaks the grep.

---

### `scripts/init-claude.sh` (modified — banner only)

**Analog:** `scripts/init-claude.sh` lines 904-905 (exact anchor):

```bash
main

echo ""
echo "Read .claude/POST_INSTALL.md and show its contents to the user."
```

**New banner echo placement** (D-07: directly above line 905):

```bash
echo "To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)"
echo ""
echo "Read .claude/POST_INSTALL.md and show its contents to the user."
```

**No `--no-banner` flag** (D-08): init-claude.sh has no `NO_BANNER` variable. The banner echo is unconditional. No guard needed.

---

### `scripts/update-claude.sh` (modified — banner with NO_BANNER guard)

**Analog:** `scripts/update-claude.sh` lines 1006-1007 (exact anchor — the current last lines):

```bash
echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
```

**NO_BANNER flag** (update-claude.sh lines 11, 24, 433-438):

```bash
# Line 11: declared
NO_BANNER=0
# Line 24: parsed
--no-banner) NO_BANNER=1 ;;
# Line 433: checked before banner block
if [[ $NO_BANNER -eq 0 ]]; then
    echo -e "${BLUE}╔...╗${NC}"
    ...
fi
```

**New banner echo placement** (D-07: after line 1007, the current last line of file):

```bash
echo ""
echo -e "${YELLOW}⚠ Restart Claude Code to apply changes${NC}"
echo "To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)"
```

**With NO_BANNER guard** (D-07: "honors existing `--no-banner` flag"):

```bash
if [[ $NO_BANNER -eq 0 ]]; then
    echo "To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)"
fi
```

**Decision point:** D-07 says "after the existing 'Restart Claude Code' line so it is the LAST line of normal-mode output. Honors the existing `--no-banner` flag." The Restart echo at line 1007 is NOT inside the `NO_BANNER` block (that block wraps only the header banner at lines 433-438). So: add the new echo after line 1007, wrapped in its own `if [[ $NO_BANNER -eq 0 ]]; then ... fi`.

---

### `Makefile` (modified — Test 24 + Test 25 slots)

**Analog:** Makefile lines 115-123 — existing Test 21-23 slot pattern:

```makefile
	@echo "Test 21: uninstall --dry-run zero-mutation contract (UN-02)"
	@bash scripts/tests/test-uninstall-dry-run.sh
	@echo ""
	@echo "Test 22: uninstall backup-before-delete + UN-01 hash-match delete (UN-04)"
	@bash scripts/tests/test-uninstall-backup.sh
	@echo ""
	@echo "Test 23: uninstall [y/N/d] prompt loop — UN-03 stdin-injected 3-branch proof"
	@bash scripts/tests/test-uninstall-prompt.sh
	@echo ""
	@echo "All tests passed!"
```

**New Test 24 + Test 25 slots** (insert before final `@echo "All tests passed!"`, after Test 23 block):

```makefile
	@echo "Test 24: uninstall round-trip integration (UN-08 — init→uninstall→clean state)"
	@bash scripts/tests/test-uninstall.sh
	@echo ""
	@echo "Test 25: installer banner gate (UN-07 — grep 'To remove:' in 3 installers)"
	@bash scripts/tests/test-install-banner.sh
	@echo ""
	@echo "All tests passed!"
```

**Indentation rule:** Makefile recipe lines use a single TAB character (not spaces). This is mandatory — Make will fail with "missing separator" if spaces are used.

**Note:** The Makefile currently shows Test 23 as the last test (line 122-123). Tests 21-23 are the Phase 18 uninstall unit tests (dry-run, backup, prompt). The Phase 19 tests (idempotency, state-cleanup) are NOT yet in the Makefile — they exist as files but are not wired. Phase 20 only adds Test 24 (round-trip) and Test 25 (banner). The Phase 19 tests may need to be wired as Test 24/25 instead, pushing Phase 20's tests to Test 26/27 — but CONTEXT.md D-05 explicitly says Test 24 = round-trip, Test 25 = banner, so follow that.

---

## Shared Patterns

### Sandbox Setup (all uninstall tests)

**Source:** `scripts/tests/test-uninstall-state-cleanup.sh` lines 79-89
**Apply to:** `scripts/tests/test-uninstall.sh`

```bash
SANDBOX="$(mktemp -d /tmp/test-uninstall-roundtrip.XXXXXX)"
# Use :? guard (T-19-03-01 lesson) — fails fast if SANDBOX is empty
trap 'rm -rf "${SANDBOX:?}"' EXIT

export TK_UNINSTALL_HOME="$SANDBOX"
export TK_UNINSTALL_LIB_DIR="$REPO_ROOT/scripts/lib"

mkdir -p "$SANDBOX/.claude/commands" \
         "$SANDBOX/.claude/agents" \
         "$SANDBOX/.claude/get-shit-done" \
         "$SANDBOX/.claude/plugins/cache/claude-plugins-official/superpowers"
```

### Locked Banner String

**Source:** CONTEXT.md §"Specific Ideas" + D-09
**Apply to:** `scripts/init-claude.sh`, `scripts/init-local.sh`, `scripts/update-claude.sh`, `scripts/tests/test-install-banner.sh`

The exact string — copy verbatim, no deviation:

```text
To remove: bash <(curl -sSL https://raw.githubusercontent.com/sergei-aronsen/claude-code-toolkit/main/scripts/uninstall.sh)
```

Rules:
- No leading prose ("You can also..." — forbidden)
- No trailing prose
- No shell color escape codes in the echo string
- No quotes around the URL
- Plain `echo` (not `echo -e`) since no escape sequences are needed

### Version-Align Triple Lock

**Source:** Makefile lines 202-224
**Apply to:** `manifest.json`, `CHANGELOG.md`, `scripts/init-local.sh` (via manifest)

Three sources must agree on `4.3.0` simultaneously:

```bash
MANIFEST_VER=$(jq -r '.version' manifest.json)           # must be 4.3.0
CHANGELOG_VER=$(grep -m1 '^## \[[0-9]' CHANGELOG.md …)  # must be 4.3.0
SCRIPT_VER=$(bash scripts/init-local.sh --version …)     # reads manifest → 4.3.0
```

Since `init-local.sh` reads from `manifest.json` at runtime, only TWO files need editing: `manifest.json` (version field) and `CHANGELOG.md` (top heading). The third leg (`init-local.sh --version`) is automatically satisfied.

### Uninstall Test Invocation Pattern

**Source:** `scripts/tests/test-uninstall-state-cleanup.sh` line 150
**Apply to:** `scripts/tests/test-uninstall.sh` (all scenario runs)

```bash
OUTPUT=$(HOME="$SANDBOX" bash "$REPO_ROOT/scripts/uninstall.sh" 2>&1) || RC=$?
```

`HOME` override is mandatory — `uninstall.sh` derives its `toolkit-install.json` path from `$HOME/.claude/`. Without the override, the test mutates the real user's home directory.

---

## No Analog Found

All 8 files have analogs. No files require falling back to RESEARCH.md patterns.

---

## Metadata

**Analog search scope:** `scripts/tests/`, `scripts/`, `Makefile`, `manifest.json`, `CHANGELOG.md`
**Files read:** 14 (5 test analogs + 3 installer scripts + Makefile + CHANGELOG + manifest + CONTEXT + REQUIREMENTS + ROADMAP)
**Pattern extraction date:** 2026-04-26
