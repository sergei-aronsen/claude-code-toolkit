# Phase 37: Project Secrets Library — Pattern Map

**Mapped:** 2026-05-04
**Files analyzed:** 5 (2 NEW + 3 modified)
**Analogs found:** 5 / 5

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `scripts/lib/project-secrets.sh` (NEW) | library (sourced shell) | file-I/O + transform (KEY=VALUE writer + JSON renderer) | `scripts/lib/mcp.sh` (esp. `mcp_secrets_set`, `mcp_secrets_load`, `_mcp_validate_value`) | exact (same role, near-identical data flow on a different file path) |
| `scripts/tests/test-project-secrets.sh` (NEW) | hermetic test harness | request-response (run lib fn → assert side effect) | `scripts/tests/test-mcp-secrets.sh` (PASS=11) for body shape; `scripts/tests/test-mcp-wizard.sh` (PASS=14) for the `TK_*_TTY_SRC <(printf …)` seam | exact + role-match (compose patterns from both) |
| `Makefile` (modified — 1 echo+bash row + 1 standalone target) | build-tool config | event-driven (target invokes test) | `Makefile:200-201` (Test 40 row for `test-mcp-secrets.sh`) + `Makefile:241-243` standalone target | exact |
| `.github/workflows/quality.yml` (modified — extend existing CI step) | CI config | event-driven (push triggers test) | `.github/workflows/quality.yml:146-156` "Tests 35-43 — orphan triage" step (the bash list that already invokes `test-mcp-secrets.sh` + `test-mcp-wizard.sh`) | exact |
| `manifest.json` (Phase 41 only — note for downstream) | distribution manifest | data (declarative file list) | `manifest.json:225-274` `files.libs[]` array | exact (alpha-ordered insert between `optional-plugins.sh` and `skills.sh`) |

## Pattern Assignments

### `scripts/lib/project-secrets.sh` (library, file-I/O + transform)

**Analog:** `scripts/lib/mcp.sh` — same directory, same `source`-safe contract, same `_priv` / `pub_*` naming, same `tui_tty_read` collision-prompt flow, and the file already exposes the helper (`_mcp_validate_value`) that D-16 says to reuse via `source`.

#### Header pattern — sourced lib, no errexit, lazy-source siblings (lines 1-75)

The new lib must adopt the exact same `source`-safe header style: shebang, header comment block listing exposed functions / test seams, color-constant guards (do not redefine), and a lazy `source` of `mcp.sh` (since D-16 reuses `_mcp_validate_value`) — mirrors how `mcp.sh:65-75` lazy-sources `tui.sh`.

Excerpt to mirror — `scripts/lib/mcp.sh:1-75`:

```bash
#!/bin/bash

# Claude Code Toolkit — MCP Catalog Loader + Detection + Wizard (v4.5+)
# Source this file. Do NOT execute it directly.
# Exposes (Plan 01):
#   mcp_catalog_load           — parses scripts/lib/mcp-catalog.json into MCP_* arrays
#   ...
# Test seams:
#   TK_MCP_CLAUDE_BIN          — override path to claude binary (mocked in tests)
#   TK_MCP_TTY_SRC             — override /dev/tty for wizard read prompts (Plan 02)
#   ...
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.

# Color constants with guards: do NOT redefine if caller already set them.
# shellcheck disable=SC2034
[[ -z "${RED:-}"    ]] && RED='\033[0;31m'
# shellcheck disable=SC2034
[[ -z "${GREEN:-}"  ]] && GREEN='\033[0;32m'
# shellcheck disable=SC2034
[[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
# shellcheck disable=SC2034
[[ -z "${BLUE:-}"   ]] && BLUE='\033[0;34m'
# shellcheck disable=SC2034
[[ -z "${NC:-}"     ]] && NC='\033[0m'

# Lazy-source <sibling>.sh so <sibling_fn> is available …
if ! command -v tui_tty_read >/dev/null 2>&1; then
    _MCP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_MCP_LIB_DIR}/tui.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_MCP_LIB_DIR}/tui.sh"
    fi
fi
```

**Apply to `project-secrets.sh`:** Replicate this entire block, swapping the doc strings for the four `project_secrets_*` functions and the test seams (`TK_MCP_TTY_SRC`, `TK_PROJECT_SECRETS_ALLOW_LITERAL`). The lazy-source target becomes `mcp.sh` (and via `mcp.sh`'s own lazy-source, transitively `tui.sh`):

```bash
# Lazy-source mcp.sh so _mcp_validate_value (D-16) is available without duplicating the regex.
if ! command -v _mcp_validate_value >/dev/null 2>&1; then
    _PROJECT_SECRETS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
    if [[ -f "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh"
    fi
fi
```

#### `project_secrets_write_env` — copy `mcp_secrets_set` order-of-operations (lines 496-565)

**This is the spine of the lib.** D-04 says: replicate the eight-step order exactly, only the file path and error-message prefix change.

Excerpt to copy — `scripts/lib/mcp.sh:511-565`:

```bash
mcp_secrets_set() {
    local key="${1:-}"
    local value="${2:-}"
    if [[ -z "$key" ]]; then
        echo -e "${RED}✗${NC} mcp_secrets_set: missing KEY argument" >&2
        return 1
    fi
    if ! _mcp_validate_value "$value"; then
        echo -e "${RED}✗${NC} mcp_secrets_set: value for ${key} contains shell metacharacters (\$, backtick, backslash, quote, newline) — refusing to write" >&2
        return 1
    fi
    local cfg
    cfg="$(_mcp_config_path)"
    mkdir -p "$(dirname "$cfg")" || return 1
    touch "$cfg" || return 1
    chmod 0600 "$cfg" || return 1
    mcp_secrets_load
    local idx
    if idx=$(_mcp_secrets_index "$key"); then
        # Collision: key already present — prompt for confirmation.
        local tty_src="${TK_MCP_TTY_SRC:-/dev/tty}"
        local choice
        if ! tui_tty_read choice "[y/N] Overwrite ${key}? " 0 "$tty_src"; then
            choice="N"
        fi
        case "${choice:-N}" in
            y|Y)
                # Rewrite the file, substituting the updated value at the matching index.
                local tmp
                tmp="$(mktemp "${cfg}.XXXXXX")" || return 1
                local i
                for ((i=0; i<${#MCP_SECRET_KEYS[@]}; i++)); do
                    if [[ "$i" -eq "$idx" ]]; then
                        printf '%s=%s\n' "$key" "$value" >> "$tmp"
                    else
                        printf '%s=%s\n' "${MCP_SECRET_KEYS[$i]}" "${MCP_SECRET_VALUES[$i]}" >> "$tmp"
                    fi
                done
                mv "$tmp" "$cfg" || { rm -f "$tmp"; return 1; }
                chmod 0600 "$cfg" || return 1
                ;;
            *)
                # Default N: keep existing value, no write.
                return 0
                ;;
        esac
    else
        # Key is new: append entry.
        printf '%s=%s\n' "$key" "$value" >> "$cfg" || return 1
        chmod 0600 "$cfg" || return 1
    fi
    return 0
}
```

**Adapt to `project_secrets_write_env`:**

- Function signature changes to `project_secrets_write_env <project_root> <KEY> <VALUE>` (3 args, not 2).
- Replace `_mcp_config_path` lookup with `cfg="${project_root%/}/.env"` (D-06: caller pre-resolves the path; do not call `realpath`).
- Replace `mkdir -p "$(dirname "$cfg")"` with `mkdir -p "$project_root"` (D-04 step 1: do not create paths *above* the caller-supplied root).
- Replace `mcp_secrets_load` with a private `_project_secrets_load_env "$cfg"` that populates `_PROJECT_SECRETS_KEYS[]` / `_PROJECT_SECRETS_VALUES[]` (parallel arrays, namespaced to avoid collision with `mcp_*` arrays when the wizard sources both libs).
- Collision prompt text becomes `"[y/N] Overwrite ${key} in ${project_root}/.env? "` (per D-04 step 5).
- Error-message prefix changes from `mcp_secrets_set:` to `project_secrets_write_env:`.
- Reuse `tui_tty_read` and `TK_MCP_TTY_SRC` exactly as-is (D-05: no new env-var name).
- Reuse `_mcp_validate_value` exactly as-is — sourced from `mcp.sh` per D-16. Do NOT duplicate the regex.

#### `_project_secrets_load_env` — copy `mcp_secrets_load` line parser (lines 448-480)

D-04 step 4 reuses the same line-parser shape (skip `#`-comment + blank, split on first `=`, validate key with `^[A-Z_][A-Z0-9_]*$`). The only difference is which arrays it populates.

Excerpt to copy — `scripts/lib/mcp.sh:448-480`:

```bash
mcp_secrets_load() {
    MCP_SECRET_KEYS=()
    MCP_SECRET_VALUES=()
    local cfg
    cfg="$(_mcp_config_path)"
    if [[ ! -f "$cfg" ]]; then
        return 0
    fi
    local line key value
    while IFS= read -r line; do
        # Skip comments and blank lines.
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        # Require KEY=value form.
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        # Trim leading/trailing whitespace from key.
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        [[ -z "$key" ]] && continue
        # Audit L1: defense in depth — only accept keys shaped like real
        # POSIX env-var names (uppercase letter or underscore, then
        # alphanumeric/underscore). Rejects shell metacharacters and
        # leading digits that could later be reflected into env or
        # argv via `export "$key=..."` or `--header "$key:..."`.
        if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            continue
        fi
        MCP_SECRET_KEYS+=("$key")
        MCP_SECRET_VALUES+=("$value")
    done < "$cfg"
}
```

**Adapt as `_project_secrets_load_env "$cfg"`:** take `cfg` as $1 (not derived from `_mcp_config_path`), populate `_PROJECT_SECRETS_KEYS[]` / `_PROJECT_SECRETS_VALUES[]`. Keep the L1 audit guard verbatim — same threat model. Mark with `# shellcheck disable=SC2034` like `mcp.sh:447`.

Companion private helper `_project_secrets_index` — copy `_mcp_secrets_index` (`scripts/lib/mcp.sh:484-494`) verbatim, swap array names.

#### `project_secrets_ensure_gitignore` — net-new pattern (no analog)

No existing toolkit code touches `.gitignore`. **Pattern source:** project conventions + D-07/08/09 spec. Skeleton the planner should write:

```bash
# project_secrets_ensure_gitignore <project_root> — guarantees `.env` is in
# <project_root>/.gitignore. Idempotent: re-run is a no-op when the line
# already exists. Creates .gitignore (mode 0644) when absent. SEC-03.
project_secrets_ensure_gitignore() {
    local project_root="${1:-}"
    if [[ -z "$project_root" ]]; then
        echo -e "${RED}✗${NC} project_secrets_ensure_gitignore: missing project_root argument" >&2
        return 1
    fi
    mkdir -p "$project_root" || return 1
    local gi="${project_root%/}/.gitignore"
    if [[ -f "$gi" ]] && grep -Fxq '.env' "$gi"; then
        return 0  # already present — D-07 exact-fixed-line match
    fi
    if [[ ! -f "$gi" ]]; then
        : > "$gi"
        chmod 0644 "$gi" || return 1
    elif [[ -s "$gi" ]] && [[ -n "$(tail -c 1 "$gi" 2>/dev/null)" ]]; then
        # File has content and does not end with a newline → D-08 leading blank
        printf '\n' >> "$gi"
    fi
    {
        printf '# claude-code-toolkit: never commit project-scope MCP secrets\n'
        printf '.env\n'
    } >> "$gi"
    chmod 0644 "$gi" || return 1
    return 0
}
```

**Reasoning:** `grep -Fxq` (fixed-string + whole-line + quiet) is the exact-match check D-07 specifies — POSIX-portable on BSD/GNU. Bash 3.2-safe (no `mapfile`, no associative arrays). Caller responsibility for path resolution mirrors D-06.

#### `project_secrets_render_mcp_env_block` — jq object construction (analog `scripts/lib/install.sh:297`)

Project canonical for JSON output is `jq -n` (per CONTEXT.md "Claude's Discretion"). The challenge: the literal `${KEY}` substring must survive jq processing — using `--arg` injects the raw string.

Excerpt to mirror — `scripts/lib/install.sh:297-300`:

```bash
jq -nc --argjson m "$mp" --argjson i "$ip" --argjson s "$sp" \
     '{ new: (($m - $i) - $s),
        removed: ($i - $m),
        modified_candidates: [$i[] | select(. as $x | $m | index($x) != null)] }'
```

**Adapt to `project_secrets_render_mcp_env_block KEY1 KEY2 ...`:**

```bash
project_secrets_render_mcp_env_block() {
    if [[ $# -eq 0 ]]; then
        printf '{}'                         # D-11: empty arg list → {}
        return 0
    fi
    local k
    for k in "$@"; do
        if [[ ! "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            echo -e "${RED}✗${NC} project_secrets_render_mcp_env_block: invalid key '$k'" >&2
            return 1                        # D-12: invalid key → return 1
        fi
    done
    # D-10: produce {"K1":"${K1}","K2":"${K2}"} via jq, no trailing newline.
    # `--args` collects positionals into $ARGS.positional[]; reduce builds the object.
    jq -nc --args '
        reduce $ARGS.positional[] as $k ({}; . + {($k): ("${" + $k + "}")})
    ' -- "$@"
}
```

**Notes:** `printf '{}'` (no `\n`) honors D-10 "no trailing newline." `jq -nc` produces compact single-line output (also no trailing `\n` when piped). Verify on macOS jq 1.6 + jq 1.7 (`brew jq`); the `--args` form is supported since jq 1.5.

#### `project_secrets_validate_mcp_env_block` — jq value extraction + regex (no exact analog)

D-13: parse JSON via `jq -r '.[] | tostring'`, regex-test each value. D-15: `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` test seam bypasses the check. Skeleton:

```bash
# project_secrets_validate_mcp_env_block <json_string> — refuses any value
# that is not ${VAR} substitution form. SEC-05 / D-13..D-15.
project_secrets_validate_mcp_env_block() {
    local json="${1:-}"
    if [[ -z "$json" ]]; then
        echo -e "${RED}✗${NC} project_secrets_validate_mcp_env_block: missing json argument" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} project_secrets_validate_mcp_env_block: jq required" >&2
        return 1
    fi
    local v
    while IFS= read -r v; do
        if [[ ! "$v" =~ ^\$\{[A-Z_][A-Z0-9_]*\}$ ]]; then
            if [[ "${TK_PROJECT_SECRETS_ALLOW_LITERAL:-}" == "1" ]]; then
                echo -e "${YELLOW}⚠${NC} project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only" >&2
                continue
            fi
            echo -e "${RED}✗${NC} refusing to write literal value into .mcp.json (use \${VAR} substitution)" >&2
            return 1
        fi
    done < <(printf '%s' "$json" | jq -r '.[] | tostring' 2>/dev/null)
    return 0
}
```

**Notes:** Process substitution `< <(...)` is Bash 3.2-safe and matches the lib's existing patterns. `tostring` flattens any non-string value to a string before the regex test (defense-in-depth: a literal `42` is still a literal).

---

### `scripts/tests/test-project-secrets.sh` (test harness, request-response)

**Primary analog:** `scripts/tests/test-mcp-secrets.sh` (PASS=11) — closest body shape.
**Secondary analog:** `scripts/tests/test-mcp-wizard.sh` (PASS=14) — `TK_*_TTY_SRC=<(printf …)` seam usage.

#### Hermetic preamble — copy verbatim (lines 1-46)

Excerpt to copy — `scripts/tests/test-mcp-secrets.sh:1-46`:

```bash
#!/usr/bin/env bash
# test-mcp-secrets.sh — Task 1 (Plan 25-02) TDD RED phase.
# …
# Usage: bash scripts/tests/test-mcp-secrets.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

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
        printf '%s\n' "$haystack" | head -5 | sed 's/^/        /'
    fi
}

printf "=== mcp-secrets tests (Plan 25-02 Task 1) ===\n"

SANDBOX="$(mktemp -d /tmp/mcp-secrets.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
export TK_MCP_CONFIG_HOME="$SANDBOX"
mkdir -p "$SANDBOX/.claude"

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/mcp.sh"
```

**Adapt for `test-project-secrets.sh`:**

- Header comment: `# test-project-secrets.sh — Phase 37 / TEST-01 contract (≥18 assertions).`
- `mktemp -d /tmp/project-secrets.XXXXXX` (different prefix to avoid collision under parallel `make test`).
- Drop the `TK_MCP_CONFIG_HOME` export — the lib does not use it; this test exercises a *project root*, not `~/.claude/`. Still set the seam if any test imports `mcp_secrets_set` indirectly.
- `source "${REPO_ROOT}/scripts/lib/project-secrets.sh"` (the new lib transitively sources `mcp.sh` and `tui.sh`).
- Add `PROJECT="$SANDBOX/myproj"` + `mkdir -p "$PROJECT"` so each test passes an absolute project root (D-06).
- Reuse `assert_pass` / `assert_fail` / `assert_eq` / `assert_contains` verbatim. Add `assert_not_contains` (copy from `test-mcp-wizard.sh:37-46`).

#### Mode-0600 cross-platform check — copy verbatim (lines 60-68)

Excerpt to copy — `scripts/tests/test-mcp-secrets.sh:60-68`:

```bash
cfg_file="$SANDBOX/.claude/mcp-config.env"
mode_ok=0
if stat -f %Mp%Lp "$cfg_file" 2>/dev/null | grep -q "^0600$"; then
    mode_ok=1
elif [ "$(stat -c %a "$cfg_file" 2>/dev/null)" = "600" ]; then
    mode_ok=1
fi
assert_eq "1" "$mode_ok" "T3: file mode is 0600"
```

**Adapt:** Replace `cfg_file` with `env_file="$PROJECT/.env"`. Same dual-stat trick handles macOS BSD (`-f`) vs GNU (`-c`). Repeat after a second write to prove `chmod 0600` step 8 (D-04).

#### Collision prompt seam — copy verbatim (lines 77-85)

Excerpt to copy — `scripts/tests/test-mcp-secrets.sh:77-85`:

```bash
# ── Test 5: collision prompt — answer N keeps existing ────────────────────────
TK_MCP_TTY_SRC=<(printf 'N\n') mcp_secrets_set FOO new_value 2>/dev/null || true
mcp_secrets_load
assert_eq "bar" "${MCP_SECRET_VALUES[0]}" "T5: collision N preserves existing value"

# ── Test 6: collision prompt — answer y overwrites ────────────────────────────
TK_MCP_TTY_SRC=<(printf 'y\n') mcp_secrets_set FOO updated 2>/dev/null || true
mcp_secrets_load
assert_eq "updated" "${MCP_SECRET_VALUES[0]}" "T6: collision y overwrites value"
```

**Adapt:** swap to `project_secrets_write_env "$PROJECT" FOO new_value`. Reload via `_project_secrets_load_env "$PROJECT/.env"` then read `${_PROJECT_SECRETS_VALUES[0]}`. Same TTY seam name (`TK_MCP_TTY_SRC`) per D-05 — do not coin a new one.

#### Metacharacter rejection — copy verbatim (lines 70-75)

Excerpt to copy — `scripts/tests/test-mcp-secrets.sh:70-75`:

```bash
# ── Test 4: validation rejects $ in value ─────────────────────────────────────
if mcp_secrets_set BAD 'value$injection' 2>/dev/null; then
    assert_fail "T4: $ in value rejected" "mcp_secrets_set returned 0 — should have returned 1"
else
    assert_pass "T4: $ in value rejected"
fi
```

**Adapt:** swap function name. Add 5 sister tests for backtick / backslash / double-quote / single-quote / newline (D-17 list). That alone gets 6 assertions toward the ≥18 floor.

#### Hidden-input contract / mock claude — partial pattern from `test-mcp-wizard.sh`

Not directly applicable to the lib (no claude invocation), but the `TK_MCP_TTY_SRC=<(printf …)` pattern from `test-mcp-wizard.sh:136-138` is the canonical seam:

```bash
printf 'test_secret_ctx7\n' > "$SANDBOX/tty.fix"
TK_MCP_TTY_SRC="$SANDBOX/tty.fix" mcp_wizard_run context7
```

Pre-loading a tmpfile is preferred over `<(printf …)` for tests that need to feed >1 line — both forms are accepted by `tui_tty_read` per `tui.sh:485` (regular file OR pipe seam path).

#### Required test coverage to hit ≥18 PASS (TEST-01 / D-18)

| # | Assertion | REQ |
|---|-----------|-----|
| 1 | `project_secrets_write_env` creates `.env` (file exists after first call) | SEC-02 |
| 2 | New `.env` is mode 0600 (BSD + GNU stat dual-check) | SEC-02 |
| 3 | Write KEY=VALUE: file contains exact `KEY=VALUE\n` line | SEC-02 |
| 4 | Mode 0600 preserved after a second write (rewrite path) | SEC-02 D-04 step 8 |
| 5 | Collision N preserves existing value | SEC-02 D-04 |
| 6 | Collision y overwrites value, key order unchanged | SEC-02 D-04 |
| 7 | `_mcp_validate_value` reachable through `project-secrets.sh` source (D-16 — sourcing mcp.sh transitively works) | SEC-06 D-16 |
| 8 | Reject `$` in value → rc=1, stderr contains `refusing to write` | SEC-06 D-17 |
| 9 | Reject backtick in value → rc=1 | SEC-06 |
| 10 | Reject backslash in value → rc=1 | SEC-06 |
| 11 | Reject double-quote in value → rc=1 | SEC-06 |
| 12 | Reject single-quote in value → rc=1 | SEC-06 |
| 13 | Reject newline in value → rc=1 | SEC-06 |
| 14 | `project_secrets_ensure_gitignore` creates `.gitignore` when absent (mode 0644) | SEC-03 D-09 |
| 15 | Appends comment + `.env` line | SEC-03 D-08 |
| 16 | Idempotent: second invocation does not duplicate the line (assert `wc -l` stays equal; `grep -c '^\.env$'` == 1) | SEC-03 D-09 |
| 17 | Does NOT match `*.env` (write `*.env` to .gitignore beforehand → `ensure_gitignore` STILL appends `.env` line) | SEC-03 D-07 |
| 18 | Does NOT match `# .env` (comment line → ensure still appends) | SEC-03 D-07 |
| 19 | `project_secrets_render_mcp_env_block` with no args → `{}` (no trailing newline) | SEC-04 D-11 |
| 20 | With KEY1, KEY2 → exact string `{"KEY1":"${KEY1}","KEY2":"${KEY2}"}` | SEC-04 D-10 |
| 21 | Invalid key (lowercase / starts with digit / contains `-`) → rc=1, stderr `invalid key` | SEC-04 D-12 |
| 22 | `project_secrets_validate_mcp_env_block '{"K":"literal"}'` → rc=1, stderr `refusing to write literal` | SEC-05 D-13/D-14 |
| 23 | `project_secrets_validate_mcp_env_block '{"K":"${K}"}'` → rc=0 | SEC-05 |
| 24 | `TK_PROJECT_SECRETS_ALLOW_LITERAL=1 project_secrets_validate_mcp_env_block '{"K":"literal"}'` → rc=0, stderr contains `test seam only` warning | SEC-05 D-15 |
| 25 | Double-run safety: run the entire test body twice in a row inside the same `$SANDBOX` — assertions still pass | TEST-01 idempotence (D-20) |

Floor is 18; this menu yields 25 — planner picks ≥18 + the double-run idempotence wrapper.

---

### `Makefile` (modified — 1 echo+bash row + 1 standalone target)

**Analog:** `Makefile:200-204` (Test 40 wiring for `test-mcp-secrets.sh`) and `Makefile:241-243` (`test-mcp-selector` standalone target).

#### Existing test row pattern — copy verbatim shape (lines 200-204)

```makefile
	@echo "Test 40: MCP secrets store (MCP-SEC-T01..11, incl. L1 regression)"
	@bash scripts/tests/test-mcp-secrets.sh
	@echo ""
	@echo "Test 41: MCP wizard happy/error paths (MCP-WIZ-T01..14)"
	@bash scripts/tests/test-mcp-wizard.sh
```

**Add for Phase 37** — at the END of the Test list, before `@echo "All tests passed!"` (currently `Makefile:227`). Latest existing entry is "Test 48" (line 224), so:

```makefile
	@echo "Test 49: project secrets library (Phase 37 / SEC-01..06, TEST-01)"
	@bash scripts/tests/test-project-secrets.sh
	@echo ""
```

#### Existing standalone target pattern — copy verbatim shape (lines 241-243)

```makefile
# Test 32 — MCP catalog + wizard + secrets (MCP-01..05, MCP-SEC-01..02), invokable standalone
test-mcp-selector:
	@bash scripts/tests/test-mcp-selector.sh
```

**Add at the bottom of the standalone-target block (after `Makefile:266-267`'s `test-catalog-scope-fallback` target):**

```makefile
# Test 49 — project secrets library (Phase 37 / SEC-01..06, TEST-01), invokable standalone
test-project-secrets:
	@bash scripts/tests/test-project-secrets.sh
```

**Also add `test-project-secrets` to the `.PHONY` line at `Makefile:1`** (currently terminates at `validate-marketplace`). Mirror existing pattern: append `test-project-secrets` to the space-separated list.

---

### `.github/workflows/quality.yml` (modified — extend existing test step)

**Analog:** `.github/workflows/quality.yml:146-156` "Tests 35-43 — orphan triage" step (currently invokes `test-mcp-secrets.sh` and `test-mcp-wizard.sh` directly).

#### Existing CI step — extend, don't add new step (lines 146-156)

```yaml
      - name: Tests 35-43 — orphan triage (audit INF-MED-1) — backup/detect/mcp/dry-run suites previously absent from CI
        run: |
          bash scripts/tests/test-backup-lib.sh
          bash scripts/tests/test-backup-threshold.sh
          bash scripts/tests/test-clean-backups.sh
          bash scripts/tests/test-detect-cli.sh
          bash scripts/tests/test-detect-skew.sh
          bash scripts/tests/test-mcp-secrets.sh
          bash scripts/tests/test-mcp-wizard.sh
          bash scripts/tests/test-migrate-dry-run.sh
          bash scripts/tests/test-update-dry-run.sh
```

**Modification per D-21:** extend the range cap in the step name AND append the new test invocation. Concrete edit:

```yaml
      - name: Tests 35-49 — orphan triage + Phase 37 project secrets library (audit INF-MED-1, SEC-01..06, TEST-01)
        run: |
          bash scripts/tests/test-backup-lib.sh
          bash scripts/tests/test-backup-threshold.sh
          bash scripts/tests/test-clean-backups.sh
          bash scripts/tests/test-detect-cli.sh
          bash scripts/tests/test-detect-skew.sh
          bash scripts/tests/test-mcp-secrets.sh
          bash scripts/tests/test-mcp-wizard.sh
          bash scripts/tests/test-migrate-dry-run.sh
          bash scripts/tests/test-update-dry-run.sh
          bash scripts/tests/test-project-secrets.sh
```

**Note for planner:** CONTEXT.md D-21 says "extends the existing range; planning decides exact number based on current test count." Current count: Test 48 is the highest-numbered Makefile row. New row becomes Test 49. The CI step name "Tests 35-43" becomes "Tests 35-49" only if Phase 37 closes the gap to the new highest number; alternatively keep it as "Tests 35-43, 49" if the planner prefers — both are valid label conventions. The earlier CI step named "Tests 21-47" (`quality.yml:124`) is a separate range that does NOT include `test-project-secrets.sh` (it lives in the orphan-triage step). Do not touch the line-124 step.

---

### `manifest.json` (Phase 41 — note for downstream reference only)

**NOT modified in Phase 37.** CONTEXT.md callout says the planner should leave a comment in the Phase 37 plan that **Phase 41 / DIST-01** is responsible for inserting `scripts/lib/project-secrets.sh` into `manifest.json` `files.libs[]`.

#### Anchor for Phase 41 — alpha-ordered insertion point (lines 262-268)

Existing block — `manifest.json:262-268`:

```json
      {
        "path": "scripts/lib/optional-plugins.sh"
      },
      {
        "path": "scripts/lib/skills.sh"
      },
```

**Phase 41 inserts between `optional-plugins.sh` and `skills.sh` (alpha order — `o` < `p` < `s`):**

```json
      {
        "path": "scripts/lib/optional-plugins.sh"
      },
      {
        "path": "scripts/lib/project-secrets.sh"
      },
      {
        "path": "scripts/lib/skills.sh"
      },
```

`update-claude.sh` auto-discovers via the v4.4 LIB-01 D-07 jq path — zero code changes. (Logged for traceability only; not Phase 37's job.)

---

## Shared Patterns

### Source-safe library header (apply to `project-secrets.sh`)

**Source:** `scripts/lib/mcp.sh:1-75` (and `scripts/lib/skills.sh:1-16`, same convention).

| Rule | Why |
|------|-----|
| `#!/bin/bash` shebang BUT no `set -euo pipefail` | `mcp.sh:40` comment: "sourced libraries must not alter caller error mode." `install.sh` and tests source these libs and expect their own `set -e` semantics to remain intact. |
| Color constants behind `[[ -z "${RED:-}" ]] &&` guards | `mcp.sh:42-52` — caller may have already defined them; redefining with readonly would break re-source. |
| Header comment lists `Exposes` / `Globals` / `Test seams` blocks | Acts as the public API contract; downstream libs (mcp.sh, skills.sh, tui.sh) all do this. |
| Lazy `command -v <fn> >/dev/null 2>&1` source guard | `mcp.sh:69-75` — safe re-source from any caller order. |

### Error reporting (apply to all four functions in `project-secrets.sh`)

**Source:** `scripts/lib/mcp.sh:515,519` + project conventions in `CLAUDE.md`.

```bash
echo -e "${RED}✗${NC} <function_name>: <human message>" >&2
return 1
```

| Glyph | When | Source |
|-------|------|--------|
| `✗` (RED) | Refusal, validation failure | `mcp.sh:515,519,557` etc. |
| `⚠` (YELLOW) | Test-seam bypass warning (D-15) | Project convention; matches `mcp.sh` style for non-fatal. |
| `✓` (GREEN) | (NOT used in this lib — silent success per Unix convention.) | — |

All errors go to stderr (`>&2`); the lib never writes to stdout except for `project_secrets_render_mcp_env_block` (D-10) which echoes JSON for caller piping.

### Hermetic test scaffold (apply to `test-project-secrets.sh`)

**Source:** `scripts/tests/test-mcp-secrets.sh:9-46` (and `test-mcp-wizard.sh:50-72`).

| Pattern | Implementation |
|---------|----------------|
| `set -euo pipefail` at top | `test-mcp-secrets.sh:9` |
| `SANDBOX="$(mktemp -d /tmp/<name>.XXXXXX)"` + `trap 'rm -rf "$SANDBOX"' EXIT` | `test-mcp-secrets.sh:40-41` |
| Source REPO via `REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"` | `test-mcp-secrets.sh:11-12` |
| `assert_pass` / `assert_fail` / `assert_eq` / `assert_contains` helpers | `test-mcp-secrets.sh:21-36` |
| Test seam `TK_MCP_TTY_SRC=<(printf 'y\n')` for collision branches | `test-mcp-secrets.sh:78,83` |
| Final `printf "\n=== Results: %s passed, %s failed ===\n" "$PASS" "$FAIL"` + `[ "$FAIL" -eq 0 ] || exit 1` | `test-mcp-secrets.sh:103-104` |

### Test-seam env-var naming (apply to lib + tests)

**Source:** `scripts/lib/mcp.sh:34-37` test-seam header docs.

| Seam | Reuse vs new | Justification |
|------|--------------|---------------|
| `TK_MCP_TTY_SRC` | **Reuse** (D-05) | Single TTY-seam contract across the entire toolkit; tests already mock it. |
| `TK_PROJECT_SECRETS_ALLOW_LITERAL` | **New** (D-15) | Lib-specific bypass; never honored in non-test code paths; documented in code comment as test-only. |
| `TK_MCP_CONFIG_HOME` | **Do not reuse** | This lib does NOT touch `~/.claude/mcp-config.env`; project root is passed explicitly per D-06. Setting this in tests would mask a regression where the lib accidentally writes outside `<project>/.env`. |

### Bash 3.2 / BSD-compat invariants (apply to all new code)

**Source:** `.planning/codebase/STACK.md` + `scripts/tests/test-mcp-secrets.sh:62-67` (cross-platform stat).

| Forbidden | Allowed alternative |
|-----------|---------------------|
| `mapfile -t` / `readarray` | `while IFS= read -r line; do …; done < file` (`mcp.sh:457`) |
| Associative arrays `declare -A` | Parallel arrays + linear `for ((i=0; …))` lookup (`_mcp_secrets_index` `mcp.sh:484-494`) |
| `${var,,}` lowercase | `tr '[:upper:]' '[:lower:]'` |
| `realpath -f` / GNU-only `readlink -f` | Caller-supplied resolved paths (D-06) |
| `stat -c %a` (GNU only) | Dual-form check: `stat -f %Mp%Lp` (BSD) → fallback `stat -c %a` (GNU). See `test-mcp-secrets.sh:63-67`. |
| `grep -P` (Perl regex) | Bash `=~` regex or `grep -E` (POSIX ERE) |

## No Analog Found

| File / pattern | Reason | Pattern source |
|----------------|--------|----------------|
| `.gitignore` manipulation (`project_secrets_ensure_gitignore`) | No existing toolkit code writes to a project's `.gitignore`. Closest cousin: `init-claude.sh` writes a project `.claude/.toolkit-version` but never touches `.gitignore`. | Use D-07/08/09 spec verbatim. `grep -Fxq '.env'` is the POSIX-portable exact-fixed-line check. |
| jq object construction with embedded literal `${VAR}` substring | `install.sh:297` uses `jq -n` for diff objects but no toolkit call constructs JSON values that contain literal `${…}` substrings. | Use `jq -nc --args` with a `reduce $ARGS.positional[]` builder. Verify on jq 1.6 + 1.7. Skeleton in §`project_secrets_render_mcp_env_block`. |
| jq value extraction + per-value regex test (`project_secrets_validate_mcp_env_block`) | Toolkit jq usage is read-only / construction; no existing helper iterates JSON values for validation. | Use `jq -r '.[] | tostring'` piped into a `while` loop with bash `=~` regex. Skeleton above. |

## Metadata

**Analog search scope:**

- `scripts/lib/*.sh` — full directory scan (mcp.sh, tui.sh, skills.sh, install.sh)
- `scripts/tests/test-mcp-*.sh` — both files read in full (test-mcp-secrets.sh PASS=11; test-mcp-wizard.sh PASS=14)
- `Makefile` — full file (456 lines)
- `.github/workflows/quality.yml` — full file (217 lines)
- `manifest.json` — `files.libs[]` block (lines 225-274)

**Files scanned:** 7

**Pattern extraction date:** 2026-05-04
