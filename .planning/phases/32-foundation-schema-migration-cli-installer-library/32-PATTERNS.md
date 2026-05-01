# Phase 32: Foundation — Schema Migration + CLI Installer Library — Pattern Map

**Mapped:** 2026-05-02
**Files analyzed:** 8 (4 new + 4 modified)
**Analogs found:** 8/8 (all matched, exact analog for each)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/lib/integrations-catalog.json` (rename) | data / config | static lookup table | `scripts/lib/mcp-catalog.json` | exact (literal git mv + schema wrap) |
| `scripts/lib/cli-installer.sh` | shared library | request-response (per-CLI dispatch) + continue-on-error loop | `scripts/lib/mcp.sh` (wizard loop) + `scripts/lib/cli-recommendations.sh` (detect probes) | role+flow match |
| `scripts/validate-integrations-catalog.py` | validator script | batch / read-only check | `scripts/validate-commands.py` | exact (same exit-code contract) |
| `scripts/tests/test-integrations-foundation.sh` | hermetic integration test | event-driven (scenario-based) | `scripts/tests/test-mcp-selector.sh` + `scripts/tests/test-update-libs.sh` | exact (same harness) |
| `scripts/lib/mcp.sh` (modify) | shared library | request-response | itself (extend, do not rewrite) | self-extend |
| `scripts/install.sh` (modify) | orchestrator | flag-parser → dispatch | itself (extend `--mcps` block at lines 65-113) | self-extend |
| `Makefile` (modify) | build / task runner | rule chain | `Makefile:381-383` (`validate-commands` target) | exact |
| `.github/workflows/quality.yml` (modify) | CI workflow | pipeline step | `.github/workflows/quality.yml:154-155` (`HARDEN-A-01` step) | exact |

---

## Pattern Assignments

### 1. `scripts/lib/integrations-catalog.json` (NEW — rename of `mcp-catalog.json`)

**Analog:** `scripts/lib/mcp-catalog.json` (lines 1-74) — flat top-level dict, one entry per integration, alpha-keyed.

**Pattern to copy verbatim:**

- Same flat-dict outer shape `{ "<entry-name>": { ...entry } }` (no nested `entries[]` array — preserves D-04).
- Same field naming style: `display_name`, `description`, `requires_oauth` (snake_case, lowercase booleans).
- Same indentation (2 spaces, trailing newline at EOF).
- Same alphabetical key order (`context7` first, `sequential-thinking` last) for the existing 9 entries.

**What to wrap (the schema upgrade — D-04..D-09):**

For each existing entry, move the four MCP-specific fields (`install_args`, `env_var_keys`, `requires_oauth`, `description`) under `components.mcp`, and add the new top-level fields `category` + (optional) `unofficial`.

Example transformation of `context7` entry:

```json
"context7": {
  "display_name": "Context7",
  "category": "docs-research",
  "components": {
    "mcp": {
      "install_args": ["context7", "--", "npx", "-y", "@upstash/context7-mcp"],
      "env_var_keys": ["CONTEXT7_API_KEY"],
      "requires_oauth": false,
      "description": "Up-to-date library docs (React, Next.js, Tailwind, etc.)"
    }
  }
}
```

**What to deviate from:**

- DROP the legacy `"name": "context7"` redundant key (lines 3, 11, 19, 27, 35, 43, 51, 59, 67 of current file). The outer key already encodes the name; reader uses outer key.
- DO NOT keep `description` at top level — it belongs to `components.mcp` per D-06. Top-level `description?` is reserved for a future entry-summary that crosses MCP+CLI (deferred).
- DO NOT add `components.cli` to any of the 9 existing entries — Phase 32 is **infrastructure only**; entry-data mutations are Phase 33. The 9 entries stay MCP-only.
- DO NOT pre-emptively populate `unofficial: false` — the field defaults to false when absent (D-09). Omit it; never write the default.

**Anti-pattern to avoid:**

- Adding a `$schema` URL pointing to a JSON Schema file. Toolkit's zero-dep posture forbids `jsonschema` package (D-10). Validator is a hand-written Python checker, not a schema-driven one.
- Adding comments via a fake `//` key — JSON does not support comments and `mcp.sh:107` parses with strict `jq`.

---

### 2. `scripts/lib/cli-installer.sh` (NEW)

**Analog (primary):** `scripts/lib/mcp.sh` — overall library shape, color guards, public/private function naming, no-errexit posture.
**Analog (secondary):** `scripts/lib/cli-recommendations.sh` — single-binary `command -v` detection style (lines 42-62).
**Analog (tertiary):** `scripts/install.sh:445-503` — continue-on-error dispatch loop with stderr capture (referenced as "Phase 25 D-08" / D-20).

**Pattern to copy verbatim from `mcp.sh`:**

**Header block** (lines 1-29 of `mcp.sh`):

```bash
#!/bin/bash

# Claude Code Toolkit — CLI Installer Library (v4.9+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   cli_detect <name>                          — 0/1 if `command -v <name>` succeeds
#   cli_install <name> <darwin_cmd> <linux_cmd> — uname -s dispatch (D-16)
# Test seams:
#   TK_CLI_UNAME           — override `uname -s` output (mocked in tests)
#   TK_CLI_BREW_BIN        — override path to brew binary (mocked in tests)
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter
#            caller error mode (mcp.sh:29 invariant).
# IMPORTANT: No `sudo` auto-prefix. Ever. (D-17). If install needs root, the
#            user gets a transparent error from brew/apt and decides.
```

**Color guard block** (lines 32-41 of `mcp.sh`) — copy verbatim with the same `[[ -z "${RED:-}" ]] && RED=...` idiom and `# shellcheck disable=SC2034` annotations. CLI installer summary uses RED/GREEN/YELLOW + NC; reuse `dro_*` colors only when sourced under `install.sh` (which calls `dro_init_colors` first).

**Function-name convention** (D-26): `cli_*` for public, `_cli_*` for private. Mirror `mcp.sh`'s `mcp_*` / `_mcp_*` split (e.g., `_mcp_default_catalog_path` → `_cli_resolve_brew_bin`).

**Pattern to copy verbatim from `cli-recommendations.sh:42-44`:**

```bash
if command -v gemini >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Gemini CLI found on PATH"
```

→ becomes the body of `cli_detect`:

```bash
# cli_detect <name> — 0 if `command -v <name>` succeeds, 1 otherwise.
# Single-line implementation; idempotent; NO caching (D-15 / CAT-04 / TUI-02 contract).
# Re-run on every TUI launch — tools the user installs out-of-band must be picked up.
cli_detect() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗${NC} cli_detect: missing argument" >&2
        return 1
    fi
    command -v "$name" >/dev/null 2>&1
}
```

**Pattern to copy verbatim from `install-statusline.sh:77-81` (uname dispatch — referenced as the model for D-16):**

```bash
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: ...${NC}"
    exit 1
fi
```

→ becomes the dispatch core of `cli_install`:

```bash
cli_install() {
    local name="${1:-}" darwin_cmd="${2:-}" linux_cmd="${3:-}"
    if [[ -z "$name" || -z "$darwin_cmd" || -z "$linux_cmd" ]]; then
        echo -e "${RED}✗${NC} cli_install: usage: cli_install <name> <darwin_cmd> <linux_cmd>" >&2
        return 1
    fi
    local platform="${TK_CLI_UNAME:-$(uname -s)}"
    case "$platform" in
        Darwin)
            # D-18 brew-absent fallback
            if [[ "$darwin_cmd" == brew\ * ]] && ! command -v brew >/dev/null 2>&1; then
                echo "cli-installer: brew not found — install from https://brew.sh, then re-run" >&2
                return 3
            fi
            eval "$darwin_cmd"
            ;;
        Linux)
            eval "$linux_cmd"
            ;;
        *)
            echo "cli-installer: unsupported platform '$platform' for CLI '$name'" >&2
            return 2
            ;;
    esac
}
```

**Pattern to copy verbatim from `mcp.sh:401-409` / `install.sh:448-449` (per-component stderr capture — D-20):**

If `cli-installer.sh` ever exposes a multi-CLI dispatch loop helper (deferred to Phase 33 for the actual loop callers), the `mktemp` template MUST be:

```bash
stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-cli.XXXXXX") || stderr_tmp=""
```

with `tk-cli` prefix (mirrors `tk-mcp` / `tk-skill` from `install.sh:448, 712`). **Audit L2 invariant:** never embed the CLI name in the path so shared `/tmp` on Linux can't enumerate which CLIs the user installs.

**What to deviate from:**

- DO NOT `set -euo pipefail` at the top — sourced libraries must not alter caller error mode (`mcp.sh:29` invariant). Errexit lives only in `scripts/install.sh` and standalone executables.
- DO NOT auto-elevate `sudo` (D-17). If `apt install` returns 100 because of missing root, return that rc and let the user decide. Documented in the header.
- DO NOT cache `cli_detect` results (D-15). `mcp.sh:135-153` caches `claude mcp list` because the call is ~4s slow; `command -v <bin>` is sub-millisecond and caching across TUI launches WILL stale-out when the user installs the missing tool out-of-band between launches.
- DO NOT auto-install Homebrew on macOS (D-18). The brew-absent fallback returns 3 with a single-line stderr hint; never runs `curl -fsSL https://brew.sh/install.sh | bash`.
- DO NOT distro-detect on Linux (D-19). The catalog `install.linux` string is vendor-recommended and toolkit just runs it. No `if [[ -f /etc/debian_version ]]` branches.
- DO NOT emit post-install hints to stdout (D-21). All hints `→ Next: <hint>` go to **stderr only** so stdout stays parseable for `--format json` (deferred).
- DO NOT execute `<tool> login` (`wrangler login`, `supabase login`). Boundary is "config + hints", not "auth flows" (D-21).
- DO NOT name the temp-file template `tk-cli-<name>.XXXXXX` — the audit L2 reason holds.

**Anti-patterns to flag:**

- `set -e` inside the library — would break callers under `set +e`.
- `read -p "Install $name? [y/N]" answer` — Phase 32 has zero prompts (TUI confirm prompts are Phase 34 TUI-03). `cli_install` runs the command unconditionally; the TUI is the gate.
- Hardcoded `/usr/local/bin` paths or `which` (use `command -v`).

---

### 3. `scripts/validate-integrations-catalog.py` (NEW)

**Analog:** `scripts/validate-commands.py` (full file, lines 1-79) — exact template per D-10/D-11.

**Pattern to copy verbatim:**

**Shebang + module docstring** (lines 1-11 of `validate-commands.py`):

```python
#!/usr/bin/env python3
"""validate-integrations-catalog.py — Validate integrations-catalog.json schema (CAT-02).

Derived from D-10/D-11 (Phase 32 — REQ-IDs CAT-02..03).

Checks performed:
  1. Top-level value is a JSON object.
  2. Each entry has display_name (str), category (str), components (object).
  3. category ∈ {docs-research, backend, payments, email, workspace,
                 project-management, communication, design, dev-tools, monitoring}.
  4. At least one of components.mcp / components.cli present.
  5. components.mcp (if present) has install_args (list[str]),
     env_var_keys (list[str]), requires_oauth (bool).
  6. components.cli (if present) has detect_cmd (str), install.darwin (str),
     install.linux (str).
  7. unofficial (if present) is bool.

Exit 0 on pass. Exit 1 with stderr messages on any failure.
"""
```

**Imports — `json` stdlib only** (line 13 of `validate-commands.py` uses `os, re, sys`; this validator uses `json, os, sys`):

```python
import json
import os
import sys
```

**Same `fail()` helper** (lines 24-25 of `validate-commands.py`) — copy verbatim:

```python
def fail(message):
    print("ERROR: " + message, file=sys.stderr)
```

**Same `SCRIPT_DIR` / `REPO_ROOT` resolution** (lines 17-19):

```python
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_CATALOG = os.path.join(REPO_ROOT, "scripts", "lib", "integrations-catalog.json")
```

**Same exit-code contract** (lines 63-75):

- Exit 0 + success line on stdout: `"integrations-catalog.json validation PASSED (N entries checked)"`.
- Exit 1 + N error lines on stderr (one per failure, prefix `"ERROR: "`).
- Last stderr line: summary `"integrations-catalog.json validation FAILED (N error(s))"`.

**Same `if __name__ == "__main__": main()` footer** (lines 78-79).

**CLI argument shape** — model after `validate-commands.py:28-43`, but accept an optional path argument per "specifics" §82 (allows future per-project overrides to reuse the same validator):

```python
def main():
    catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG
    if not os.path.isfile(catalog_path):
        fail("catalog not found at: " + catalog_path)
        sys.exit(1)
    try:
        with open(catalog_path, "r", encoding="utf-8") as fh:
            catalog = json.load(fh)
    except json.JSONDecodeError as exc:
        fail("catalog is not valid JSON: " + str(exc))
        sys.exit(1)
    # ... validation loop ...
```

**What to deviate from:**

- DO NOT `import jsonschema` (D-10). Validator is hand-written `dict.get()` checks. The "no jsonschema" decision was explicit — `validate-commands.py:13` imports only `os, re, sys`; `validate-manifest.py:25-27` imports only `json, os, sys`. Match that posture.
- DO NOT `import re` — no regex needed (category enum is membership check; no path-prefix matching like `validate-manifest.py`). Strip the import.
- DO NOT use `pathlib.Path` — `validate-commands.py` and `validate-manifest.py` both use `os.path` for backward-compat with very old Python. Match.
- DO NOT silently pass on the first error (`validate-commands.py:62-67` — accumulate and report ALL errors before exit). Same accumulation pattern here: `errors += 1` per failure, exit 1 only at end.
- DO NOT accept `--strict` / `--fix` flags. Validator is read-only; toolkit fixers are separate scripts.
- DO NOT pretty-print Unicode markers (✓/✗) in success/failure — `validate-commands.py:64,71` uses plain ASCII (`"FAILED"`, `"PASSED"`). Markdownlint hooks are unaffected, and CI logs render cleanly without color guards.

**Anti-patterns to flag:**

- `assert` statements for validation — Python `-O` mode strips them; use explicit `if not ...: errors += 1`.
- `sys.exit(0)` mid-loop on first success — must check ALL entries.
- `print()` to stdout for errors — errors go to **stderr** (`file=sys.stderr` per `fail()` helper).
- Hardcoding the 10-element category enum inside the validation loop — define once at module top:

  ```python
  ALLOWED_CATEGORIES = {
      "docs-research", "backend", "payments", "email", "workspace",
      "project-management", "communication", "design", "dev-tools", "monitoring",
  }
  ```

  (Mirrors `validate-manifest.py:29` `ALLOWED_CONFLICTS = {"superpowers", "get-shit-done"}`.)

---

### 4. `scripts/tests/test-integrations-foundation.sh` (NEW)

**Analog (primary):** `scripts/tests/test-mcp-selector.sh` (lines 1-200) — assertion harness, scenario layout, mock CLI fixtures.
**Analog (secondary):** `scripts/tests/test-update-libs.sh` (lines 1-150) — `sha256_any` / `mtime_any` cross-platform helpers, manifest-fixture build, sandbox+trap.

**Pattern to copy verbatim from `test-mcp-selector.sh`:**

**Header + shebang** (lines 1-19):

```bash
#!/usr/bin/env bash
# test-integrations-foundation.sh — Phase 32 hermetic integration test.
#
# Scenarios (≥10 assertions across N scenarios):
#   S1_validator_happy_path  — validate-integrations-catalog.py exits 0 on shipped file
#   S2_validator_missing_field — entry without `category` → exit 1, stderr names entry
#   S3_validator_bad_category — category="frobnicate" → exit 1
#   S4_cli_detect_present — cli_detect bash → 0
#   S5_cli_detect_absent — cli_detect __nope__ → 1
#   S6_cli_install_dispatch_darwin — TK_CLI_UNAME=Darwin runs darwin_cmd
#   S7_cli_install_dispatch_linux — TK_CLI_UNAME=Linux runs linux_cmd
#   S8_cli_install_unsupported — TK_CLI_UNAME=FreeBSD → exit 2 + stderr hint
#   S9_cli_install_brew_absent — Darwin + brew-prefix cmd + no brew → exit 3
#   S10_install_sh_mcps_alias — install.sh --mcps prints deprecation note to stderr, exits 0
#   S11_mcp_sh_reads_new_path — _mcp_default_catalog_path resolves integrations-catalog.json
#
# Test seams: TK_CLI_UNAME, TK_CLI_BREW_BIN, TK_MCP_CATALOG_PATH
#
# Usage: bash scripts/tests/test-integrations-foundation.sh
# Exit:  0 = all assertions passed, 1 = any failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

**Assertion harness** (lines 24-55) — copy verbatim:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

assert_pass() { PASS=$((PASS + 1)); printf "  ${GREEN}OK${NC} %s\n" "$1"; }
assert_fail() { FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} %s\n" "$1"; printf "      %s\n" "$2"; }
assert_eq()       { ... }
assert_contains() { ... }
assert_not_contains() { ... }
```

**Per-scenario sandbox + trap pattern** (lines 65-68 — repeated in every `run_sN`):

```bash
run_s1_validator_happy_path() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-integrations-foundation.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_validator_happy_path: shipped catalog passes validator --"
    # ... assertions ...
}
```

**Footer pattern** (lines 380-391):

```bash
run_s1_validator_happy_path
run_s2_validator_missing_field
# ... all scenarios ...

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

**Pattern to copy verbatim from `test-update-libs.sh`:**

**Cross-platform sha256/mtime helpers** (lines 56-72) — needed if the test ever computes catalog hashes; copy verbatim if used. For Phase 32 likely NOT needed (validator is the source of truth, not hash diffs).

**Sandbox-isolated mock-CLI scaffolding** — pattern from `test-mcp-selector.sh:97-106`:

```bash
local MOCK_CLI="$SANDBOX/mock-tool"
cat > "$MOCK_CLI" <<'MOCK'
#!/bin/bash
echo "ran-darwin-stub"
exit 0
MOCK
chmod +x "$MOCK_CLI"
```

→ Use this pattern for S6/S7 to stub the `darwin_cmd` / `linux_cmd` shell strings: build a fake script in `$SANDBOX`, pass its path as the install command, assert it ran.

**What to deviate from:**

- DO NOT use `claude mcp list` mocking patterns from `test-mcp-selector.sh:S2`. The new test does not exercise the MCP detection three-state contract — that's already covered by `test-mcp-selector.sh`. Phase 32's smoke test is scoped to **validator + cli-installer + alias**.
- DO NOT register the new test in `Makefile:71-212` (the long sequential `test:` target) in Phase 32. The `make check` chain wires the validator (not the smoke test). The smoke test is invoked manually via `bash scripts/tests/test-integrations-foundation.sh` and via a single-line CI step under `validate-templates`. Pattern follows v4.8 Phase 28 `test-bridges-foundation.sh` registration model.
- DO NOT depend on `claude` CLI being on PATH (test-mcp-selector S2 strips PATH and relies on `is_mcp_installed` returning 2). Phase 32's `cli_install` does not call `claude`; mock by overriding `TK_CLI_UNAME` and using local script paths.
- DO NOT exceed assertion count budget — task says ≥10. test-mcp-selector has 18 across 8 scenarios; aim for 10-15 across ~11 scenarios to keep test wall-time under 5s.
- DO NOT load the real shipped catalog with mutations in-place. Build a fixture under `$SANDBOX/integrations-catalog.json` and pass via `python3 scripts/validate-integrations-catalog.py "$SANDBOX/integrations-catalog.json"` to exercise the optional-path argument.

**Anti-patterns to flag:**

- `cd $SANDBOX` without `cd "$REPO_ROOT"` before invoking `bash scripts/...` — relative paths break under sandbox cwd.
- Forgetting the `# shellcheck disable=SC2064` annotation above each `trap "..." RETURN` (RETURN trap with variable expansion; Phase 25 closed an audit on this same line).
- Using `mapfile` to read assertion lists — Bash 3.2 invariant rules it out (BACKCOMPAT-01).
- Using `read -N` (bash 4+ only) — Phase 24 audit closed this.
- Test-output bleeding through to `make check` summary — wrap noisy commands with `2>/dev/null` selectively, never `>/dev/null 2>&1` blanket-suppression (must preserve assert-fail diagnostics).

---

### 5. `scripts/lib/mcp.sh` (MODIFY)

**Self-extend, do not rewrite.** The public function names `mcp_catalog_load`, `mcp_status_array`, `mcp_wizard_run`, `is_mcp_installed`, `mcp_secrets_load`, `mcp_secrets_set` MUST stay (D-25). Internal helpers are free to evolve.

**Two changes only — both narrow:**

**Change 1 — `_mcp_default_catalog_path` basename (line 47):**

```diff
 _mcp_default_catalog_path() {
     local d
     d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
-    echo "${d}/mcp-catalog.json"
+    echo "${d}/integrations-catalog.json"
 }
```

This is the **two-line diff for D-25** called out in CONTEXT § Integration Points.

**Change 2 — schema-aware reader inside `mcp_catalog_load` (lines 86-107):**

The current loop reads top-level fields:

```bash
MCP_DISPLAY+=("$(jq -r --arg n "$name" '.[$n].display_name' "$catalog_path")")
MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.[$n].env_var_keys | join(";")' "$catalog_path")")
MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '[.[$n].install_args[] ] | join("")' "$catalog_path")")
```

After the rename + schema upgrade, MCP-specific fields live under `.[$n].components.mcp`:

```bash
MCP_DISPLAY+=("$(jq -r --arg n "$name" '.[$n].display_name' "$catalog_path")")
MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.[$n].components.mcp.env_var_keys // [] | join(";")' "$catalog_path")")
MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '[.[$n].components.mcp.install_args[]?] | join("")' "$catalog_path")")
MCP_DESCS+=("$(jq -r --arg n "$name" '.[$n].components.mcp.description // ""' "$catalog_path")")
local oauth_field
oauth_field=$(jq -r --arg n "$name" '.[$n].components.mcp.requires_oauth // false' "$catalog_path")
[[ "$oauth_field" == "true" ]] && MCP_OAUTH+=(1) || MCP_OAUTH+=(0)
```

**Pattern to copy verbatim:**

- Same six parallel arrays — no rename.
- Same `$'\037'` (ASCII 31 unit-separator) packing for `install_args[]` (line 95 reasoning preserved).
- Same `is_mcp_installed` three-state contract (0/1/2) — untouched.
- Same `_mcp_list_cache_init` memoisation (lines 116-153) — untouched.

**What to deviate from:**

- For Phase 32 only the new shape exists in the renamed file (per CONTEXT.md "Integration Points" §144). The reader can **hard-require** the new shape — no detect-old-shape branch. If `.components.mcp` is missing for a given entry the entry is CLI-only (Phase 33 reality) and `mcp_catalog_load` must skip the row but keep the parallel arrays length-aligned (use `// []` and `// false` defaults; OAuth defaults to 0 when MCP block absent so `MCP_NAMES[i]` still resolves).
- DO NOT skip/filter entries based on presence of `components.mcp`. The whole loop must walk all 9 alpha-sorted keys (Phase 33 introduces CLI-only entries; the test in `test-mcp-selector.sh:S1` asserts `${#MCP_NAMES[@]}` length, which is alpha-key-count, not MCP-block-count). Use `// []` + `// false` defaults so CLI-only entries collapse cleanly to "no env keys, no oauth, empty install_args".
- DO NOT add a parallel `MCP_CATEGORY[]` array in Phase 32. TUI category headers are Phase 34 (TUI-01). Out of scope here.
- DO NOT add a `MCP_UNOFFICIAL[]` array in Phase 32. Unofficial-badge rendering is Phase 34 (TUI-03). Out of scope here.
- DO NOT touch `mcp_status_array` (lines 573-610) — its contract (`TUI_LABELS[]`, `TUI_GROUPS[]`, etc.) is consumed by the TUI page; Phase 32 leaves it alone.
- DO NOT add a new env-var name `TK_INTEGRATIONS_CATALOG_PATH` (specifics §82 explicitly defers it to Phase 35 docs). Keep `TK_MCP_CATALOG_PATH` only.

**Anti-patterns to flag:**

- Renaming any of the six globals (`MCP_NAMES`, `MCP_DISPLAY`, etc.) — `install.sh:430-431` and `mcp_status_array` both reference them by exact name. Rename = breakage.
- Splitting the loader into `mcp_catalog_load` + `cli_catalog_load` two-function design. Phase 32 has ONE catalog file with ONE loader; the loader knows about `components.mcp` and `components.cli` but populates only MCP arrays in this phase. CLI arrays come in Phase 33 when entry data needs them.
- Adding a `jq --version` runtime check — `mcp.sh:71-74` already gates on `command -v jq`. Don't duplicate.

---

### 6. `scripts/install.sh` (MODIFY)

**Analog (self-extend):** `scripts/install.sh:65-113` (existing argparse `case` block).

**Pattern to copy verbatim:**

The existing `--mcps` case at line 81:

```bash
--mcps)        MCPS=1;                shift ;;
```

becomes (D-22 + D-23):

```bash
--mcps)
    # D-22: --mcps is the legacy flag, kept working with deprecation note.
    echo "--mcps is deprecated; use --integrations instead. (still works, will continue working in v4.x)" >&2
    MCPS=1
    shift ;;
--integrations)
    # D-23: new preferred name; sets the same MCPS=1 internal var (no rename).
    MCPS=1
    shift ;;
```

**Help text update at line 98** — copy the existing `--mcps` line styling verbatim, add the new line:

```bash
  --integrations  Install curated MCPs + CLIs via TUI catalog (Phase 32+; preferred over --mcps)
  --mcps          [DEPRECATED] Alias for --integrations (still works in v4.x)
```

**What to deviate from:**

- DO NOT rename the internal variable `MCPS` to `INTEGRATIONS`. D-23 explicitly preserves the var name to keep blast radius low. Every existing branch (lines 213, 274, 280, 410-504, 597) reads `MCPS`; renaming = 50+ line diff with no behavior gain. The variable is internal-only; the user-facing flag is what matters.
- DO NOT echo the deprecation note to **stdout** — the audit-L4 invariant for downstream piping (and the existing `_DRO_*` summary table consumers) requires stdout to stay parseable. Use `>&2` (D-22).
- DO NOT make the deprecation note repeat per dispatch invocation. It fires once at flag-parse time (lines 66-113), never again later.
- DO NOT escalate to exit 1 / exit 2 on `--mcps`. CONTEXT specifics §80 says deprecation note must NOT block. Print + continue.
- DO NOT add a `--no-deprecation-warnings` flag to silence it. Out of scope; users edit their alias if they care.
- DO NOT extend the catalog download block at lines 225-233 to fetch `integrations-catalog.json` AND `mcp-catalog.json`. The rename is hard (D-01); only fetch the new basename. The line 228 path becomes:

  ```bash
  if ! _tk_curl_safe "$TK_REPO_URL/scripts/lib/integrations-catalog.json" -o "$MCP_CATALOG_TMP"; then
      echo -e "${RED}✗${NC} Failed to download integrations-catalog.json — aborting" >&2
      exit 1
  fi
  ```

  The mktemp suffix `mcp-catalog-XXXXXX.json` (line 226) MAY stay (the tmpfile basename is internal; `TK_MCP_CATALOG_PATH` already points to whatever path `mcp.sh` reads). Renaming the tmpfile basename is optional polish.

**Anti-patterns to flag:**

- Defining `INTEGRATIONS=0` as a parallel flag (would force every downstream branch to check `[[ MCPS=1 || INTEGRATIONS=1 ]]` — D-23 explicitly avoids this).
- Making `--mcps` and `--integrations` mutually exclusive (lines 274-277 model). They map to the same path; user can pass either; both can't be passed at once because argparse processes left-to-right and both set `MCPS=1` (last-wins, no conflict).
- Putting the deprecation echo AFTER `_source_lib mcp` (line 214) — must fire at argparse time so users see it before any other output.

---

### 7. `Makefile` (MODIFY)

**Analog:** `Makefile:381-383` — `validate-commands` target wired into `check` chain at line 19.

**Pattern to copy verbatim:**

Line 381-383 of the existing Makefile:

```makefile
# Validate commands/*.md for required ## Purpose and ## Usage headings (HARDEN-A-01 — derived from AUDIT-12)
validate-commands:
	@echo "Validating commands/*.md for required headings (HARDEN-A-01)..."
	@python3 scripts/validate-commands.py
```

→ Phase 32 adds beside it:

```makefile
# Validate scripts/lib/integrations-catalog.json schema (CAT-02 / CAT-03 — Phase 32)
validate-catalog: scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json
	@echo "Validating integrations-catalog.json schema (CAT-02 / CAT-03)..."
	@python3 scripts/validate-integrations-catalog.py
```

**Wire into the `check` chain at line 19:**

```diff
-check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-mdlint-config-sync validate-skills-desktop validate-marketplace cell-parity
+check: lint validate validate-base-plugins version-align translation-drift agent-collision-static validate-commands validate-catalog validate-mdlint-config-sync validate-skills-desktop validate-marketplace cell-parity
```

**Add the target name to the `.PHONY` declaration (line 1):**

```diff
-.PHONY: help check check-full lint shellcheck mdlint test validate ... validate-commands validate-mdlint-config-sync ...
+.PHONY: help check check-full lint shellcheck mdlint test validate ... validate-commands validate-catalog validate-mdlint-config-sync ...
```

**What to deviate from:**

- DO use prerequisites (`validate-catalog: scripts/...`). The `validate-commands` target at line 381 has none — the script's own `os.path.isdir(COMMANDS_DIR)` check handles missing-input. Phase 32 explicitly lists prereqs because if either the script OR the catalog is missing, we want make to fail fast with a clear "no rule to make target" error (one-line vs. python traceback).
- DO NOT add `validate-catalog` to the `validate:` target (line 240). `validate:` is template-content lint (audit-prompt sections, version alignment). Catalog schema validation is a peer-level concern; sits beside `validate-commands` in the `check:` chain.
- DO NOT add a sub-step that runs the new smoke test (`test-integrations-foundation.sh`) inside `make check`. Smoke tests live under `make test` (lines 71-212) and CI invokes them in the `validate-templates` job. Adding to `check` doubles wall-time.
- DO NOT use `&&` to chain commands inside the recipe (the existing recipes use `@command \`-newline-`other-command \`-newline-`...`). Stay consistent with the `validate-commands:` 2-line shape.

**Anti-patterns to flag:**

- Using `python` instead of `python3` (CI runners may have `python` aliased to Python 2; explicit `python3` matches every other Python invocation in the file: lines 58, 302, 383).
- Forgetting the leading `@` on each command line — Makefile recipes echo by default; the existing pattern silences echo on success (`@echo` and `@python3`).
- Putting the prerequisite files on the wrong side of the colon — Make syntax: `target: prereqs`, not `target prereqs:`.

---

### 8. `.github/workflows/quality.yml` (MODIFY)

**Analog:** Lines 154-155 — the `HARDEN-A-01 — validate commands/*.md required headings` step inside the `validate-templates` job.

**Pattern to copy verbatim:**

```yaml
- name: HARDEN-A-01 — validate commands/*.md required headings
  run: make validate-commands
```

→ Phase 32 adds beside it (insert after line 155):

```yaml
- name: CAT-02 / CAT-03 — validate integrations-catalog.json schema
  run: make validate-catalog
```

**Per-job placement:** the `validate-templates` job (line 52). Same job already runs `make validate-commands`, `make validate-skills-desktop`, `make validate-marketplace`, `make cell-parity` (lines 154-164). The new step joins this cluster.

**What to deviate from:**

- DO use `make validate-catalog` rather than calling `python3 scripts/validate-integrations-catalog.py` directly. Mirrors lines 154-164 — every validator step calls `make`, never raw scripts. Single source of truth = the Makefile recipe.
- DO NOT add a separate top-level job. The existing `validate-templates` job (line 52) is the right home — it already groups schema/structural validators on `ubuntu-latest`.
- DO NOT add a matrix axis for macOS — the validator is pure Python stdlib and platform-independent. The 4-job matrix (`shellcheck`, `markdownlint`, `validate-templates`, `test-init-script`) already runs `validate-templates` on Linux only and `test-init-script` on the Linux+macOS matrix. Don't duplicate.
- DO NOT pin a Python version via `actions/setup-python` step. Ubuntu-latest ships Python 3.12+ already; the validator works on 3.8+ (compatible with `scripts/council/brain.py` constraint).
- DO NOT add a `Tests 35-43` step entry for the new smoke test in this PR. The smoke test will be added to the existing `Tests 35-43` cluster (lines 142-152) in Phase 35 alongside the manifest bump (DIST-01). Phase 32 wires only the validator into CI; the smoke test is invokable manually + via Makefile `test-integrations-foundation` target (deferred).

**Anti-patterns to flag:**

- Using `uses: ` external action — this is a one-liner shell call; `run: ` is correct. Don't pull in a `actions/python-validator@v1` style action for a 30-line validator.
- Forgetting to leave the `permissions: contents: read` declaration alone (line 9-10 — workflow-level least-privilege). The new step is read-only; no permission bump needed.
- Adding `if: github.event_name == 'pull_request'` — the workflow already runs on `push` to main and PRs (lines 4-7). The new validator should run on both; no conditional.

---

## Shared Patterns (cross-cutting)

### A. Shell library scaffolding (applied to `cli-installer.sh`)

**Source:** `scripts/lib/mcp.sh:1-41` + `scripts/lib/dry-run-output.sh:1-11`

| Element | Required |
|---|---|
| `#!/bin/bash` shebang | Yes |
| Comment header: name + purpose + sourcing rule + exposed functions + globals + test seams | Yes |
| `IMPORTANT: No errexit/nounset/pipefail` warning | Yes — must not alter caller error mode |
| Color guards `[[ -z "${RED:-}" ]] && RED=...` with `# shellcheck disable=SC2034` | Yes |
| Public functions in `<prefix>_<verb>` form (`cli_detect`, `cli_install`) | Yes |
| Private helpers in `_<prefix>_<verb>` form (`_cli_resolve_brew_bin`) | Yes |

### B. Test seam env-var convention

**Source:** `scripts/lib/mcp.sh:24-27` (`TK_MCP_CLAUDE_BIN`, `TK_MCP_CATALOG_PATH`, `TK_MCP_TTY_SRC`, `TK_MCP_CONFIG_HOME`)

Naming: `TK_<MODULE>_<RESOURCE>` (uppercase, underscore-separated). Phase 32 introduces:

- `TK_CLI_UNAME` — override `uname -s` output for `cli_install` dispatch tests.
- `TK_CLI_BREW_BIN` — override `command -v brew` for D-18 brew-absent tests (set to empty string to simulate absence; set to a stub path to simulate presence).

Existing seams unchanged:

- `TK_MCP_CATALOG_PATH` — preserved (specifics §82); points to `integrations-catalog.json` after rename. NO new `TK_INTEGRATIONS_CATALOG_PATH` env var in Phase 32.

### C. Continue-on-error dispatch loop (D-20 contract)

**Source:** `scripts/install.sh:445-503` (MCP wizard dispatch) — the canonical Phase 25 D-08 pattern.

Five required elements per loop iteration:

1. `stderr_tmp=$(mktemp "${TMPDIR:-/tmp}/tk-cli.XXXXXX") || stderr_tmp=""` (Audit L2 — no name in path).
2. `[[ -n "$stderr_tmp" ]] && CLEANUP_PATHS+=("$stderr_tmp")` — register for trap-EXIT cleanup.
3. Subshell wrap: `( cli_install ... ) 2>"$stderr_tmp" || local_rc=$?` — preserves caller errexit mode AND captures rc.
4. Case on `local_rc`: `0`/`1`/`2`/`3`/`*` → maps to `INSTALLED_COUNT` / `SKIPPED_COUNT` / `FAILED_COUNT`.
5. `if [[ "$FAIL_FAST" -eq 1 ]]; then ... break; fi` on failure case (lines 493-501).

**Phase 32 scope:** `cli-installer.sh` exposes `cli_install` as a single-CLI primitive. The dispatch loop that consumes it lives in `install.sh` and is built in Phase 33 (per CONTEXT § Phase Boundary). Phase 32 ships the primitive + smoke test only.

### D. Manifest `files.libs[]` registration

**Out of scope for Phase 32.** Per D-03 / D-13, the manifest bump (`mcp-catalog.json` → `integrations-catalog.json` entry, plus new `cli-installer.sh` and `validate-integrations-catalog.py` registrations) is deferred to Phase 35 DIST-01. Phase 32 commits the new files; Phase 35 makes `update-claude.sh` aware of them.

**Reference pattern (for Phase 35 use, not Phase 32):** `manifest.json` `files.libs[]` array, registered in v4.4 LIB-01 — `update-claude.sh` auto-discovers via existing `jq` path.

---

## No Analog Found

| File | Reason | Resolution |
|---|---|---|
| _none_ | All 8 new/modified files have direct analogs in the repo. | N/A |

The Phase 32 scope is intentionally narrow (foundation only — no new UX paradigms). Every file follows an existing template; every behavior follows an existing convention. The analog table is dense by design.

---

## Anti-Patterns Identified (consolidated)

| Anti-pattern | Where it would creep in | Why forbidden |
|---|---|---|
| `import jsonschema` | `validate-integrations-catalog.py` | Zero-dep posture (D-10); `validate-commands.py` and `validate-manifest.py` use `json` stdlib only. |
| `sudo` auto-prefix in `cli_install` | `cli-installer.sh` `Linux)` branch | D-17 — toolkit never elevates; brew/apt error message goes straight to user. |
| Caching `cli_detect` results | Across TUI launches | D-15 / CAT-04 — out-of-band installs would stale-out. `command -v` is sub-millisecond; no perf justification. |
| Auto-installing Homebrew | macOS brew-absent fallback | D-18 — return rc=3 + stderr hint, never `curl https://brew.sh/install.sh \| bash`. |
| Distro detection on Linux | `cli_install` Linux branch | D-19 — vendors own their install instructions; toolkit just runs the catalog string. |
| Renaming `MCPS` internal var | `install.sh` argparse | D-23 — preserves blast radius; flag is user-facing, var is internal. |
| Renaming `mcp_*` public functions | `mcp.sh` API surface | D-25 — `install.sh` callers are stable; renames are v5.0 concern. |
| Adding `TK_INTEGRATIONS_CATALOG_PATH` env | Test seams | Specifics §82 explicitly defers to Phase 35 docs. |
| `set -e` inside `cli-installer.sh` | Library top-of-file | `mcp.sh:29` invariant — sourced libraries must not alter caller error mode. |
| Embedding CLI name in mktemp basename | `cli_install` / dispatch loop | Audit L2 (resolved 2026 in MCP loop) — `/tmp` enumeration leaks user's tooling choices. |
| `mapfile` / `read -N` / `declare -A` | Anywhere in cli-installer.sh or test | Bash 3.2 invariant (BACKCOMPAT-01). |
| Pre-commit deprecation note for `--mcps` | `install.sh` argparse | D-22 / specifics §80 — print + continue; never block. |
| Comments in `integrations-catalog.json` (`//` keys) | Catalog file | JSON spec forbids; `mcp.sh:107` jq parser is strict. |
| `description` at entry top level | `integrations-catalog.json` | D-06 — description belongs to `components.mcp.description`. |
| Adding `MCP_CATEGORY[]` / `MCP_UNOFFICIAL[]` arrays | `mcp.sh` loader | Phase 34 concern (TUI-01 / TUI-03), not Phase 32. |

---

## Metadata

**Analog search scope:** `scripts/`, `scripts/lib/`, `scripts/tests/`, `Makefile`, `.github/workflows/`
**Files scanned:** 18 (9 lib files, 4 install/util scripts, 2 Python validators, 2 test fixtures, 1 Makefile, 1 workflow YAML)
**Pattern extraction date:** 2026-05-02
**Pinned constraints from CONTEXT:** D-01 through D-27 (catalog rename, schema shape, validator design, CLI installer semantics, alias backward-compat, function-naming preservation)
**Cross-cutting from CLAUDE.md:** POSIX bash 3.2+, set -euo pipefail in scripts (not libraries), markdownlint MD040/MD031/MD032/MD026, `make check` must pass.
**Cross-cutting from `.claude/rules/lessons-learned.md`:** TK_TOOLKIT_REF allowlist regex `[A-Za-z0-9._/-]+` + reject `..` (audit pattern; mirrors `install.sh:47-50`); single-CLI scenarios are first-class test cases (apply to S6-Darwin-only / S7-Linux-only assertions).
