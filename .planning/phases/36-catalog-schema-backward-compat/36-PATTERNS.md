# Phase 36: Catalog Schema + Backward Compat — Pattern Map

**Mapped:** 2026-05-04
**Files analyzed:** 6 (5 modified, 1 new)
**Analogs found:** 6 / 6 (every file has an exact in-repo precedent)

## File Classification

| File | Op | Role | Data Flow | Closest Analog | Match Quality |
|------|----|----|-----------|----------------|---------------|
| `scripts/lib/integrations-catalog.json` | modify | data / catalog | static-data | self (existing fields per entry) | exact (additive field) |
| `scripts/validate-integrations-catalog.py` | modify | validator / schema-enforcer | batch transform (json -> exit code) | self (REQUIRED_ENTRY_KEYS + per-entry walk) | exact (extension) |
| `scripts/lib/mcp.sh` | modify | library / loader | request-response (jq read -> bash arrays) | self (`MCP_CATEGORY+=` line 133, `MCP_UNOFFICIAL+=` line 136) | exact (parallel-array clone) |
| `scripts/tests/test-integrations-catalog.sh` | modify | test (hermetic, validator side) | request-response (python read -> assert) | self (`_pyq` helper at lines 67–86, A1–A14) | exact (add A15/A16/A17) |
| `scripts/tests/test-catalog-scope-fallback.sh` | create | test (hermetic, loader side) | request-response (synthetic JSON -> sourced bash) | `scripts/tests/test-mcp-selector.sh::run_s1_catalog_correctness` (lines 64–86) + `run_s2_detection_three_state` (lines 92–169) | exact (synthetic-catalog harness pattern) |
| `Makefile` | modify | build / orchestrator | sequential | self (test target lines 215–222 — "Test 47: integrations TUI redesign") | exact (add "Test 48:" line) |

## Pattern Assignments

### `scripts/lib/integrations-catalog.json` (data / additive field)

**Analog:** self — every existing block already shows the canonical 2-space-indent jq-canonical form.

**Insertion site (simple block, e.g. `aws-cloudwatch-logs`, lines 17–34):**

Verified verbatim from the file:

```json
"aws-cloudwatch-logs": {
  "name": "aws-cloudwatch-logs",
  "display_name": "AWS CloudWatch Logs",
  "category": "backend",
  "env_var_keys": [
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_REGION"
  ],
  "install_args": [
    "aws-cloudwatch-logs",
    "--",
    "uvx",
    "awslabs.cloudwatch-logs-mcp-server@latest"
  ],
  "description": "Live log streams + filter patterns + insights queries",
  "requires_oauth": false
},
```

**Diff for Phase 36 (default `project` per D-07):**

```diff
       "description": "Live log streams + filter patterns + insights queries",
-      "requires_oauth": false
+      "requires_oauth": false,
+      "default_scope": "project"
     },
```

**Insertion site (unofficial block, e.g. `notebooklm`, lines 174–189):**

```json
"notebooklm": {
  "name": "notebooklm",
  "display_name": "NotebookLM",
  "category": "docs-research",
  "env_var_keys": [],
  "install_args": [
    "notebooklm",
    "--",
    "npx",
    "-y",
    "notebooklm-mcp"
  ],
  "description": "Google NotebookLM — source-grounded answers from your docs (browser auth)",
  "requires_oauth": true,
  "unofficial": true
},
```

**Diff for Phase 36 (insert after `unofficial`, default `user` per D-06):**

```diff
       "requires_oauth": true,
-      "unofficial": true
+      "unofficial": true,
+      "default_scope": "user"
     },
```

**Field-order rule** (verified by reading 5 entries spanning lines 17, 174, 323, 342):

Existing canonical order per block: `name`, `display_name`, `category`, `env_var_keys`, `install_args`, `description`, `requires_oauth`, then optionally `unofficial`. Phase 36 appends `default_scope` LAST (after `unofficial` when present, otherwise after `requires_oauth`). Keeps diffs minimal and matches the docstring order in the validator (lines 60–68).

**Edit method:** hand-edit (20 entries × 1 line). DO NOT use `sed -i` (BSD vs GNU portability — Pitfall 1 in RESEARCH.md). If automation is needed, use `python3 -c 'import json; ...; json.dump(..., indent=2)'`.

**Style facts (verified from file):**
- 2-space indent
- `"`-only quotes (jq-canonical)
- Trailing newline at EOF
- No comments
- No trailing commas

---

### `scripts/validate-integrations-catalog.py` (validator extension)

**Analog:** self — `REQUIRED_ENTRY_KEYS` tuple + the existing `requires_oauth` bool check.

**Imports pattern** (lines 48–51, verbatim):

```python
import json
import os
import re
import sys
```

→ No new imports needed (enum check uses Python `not in` operator on a tuple literal).

**REQUIRED_ENTRY_KEYS extension** (lines 60–68, verbatim):

```python
# Required keys on every components.mcp[<name>] entry.
REQUIRED_ENTRY_KEYS = (
    "name",
    "display_name",
    "category",
    "env_var_keys",
    "install_args",
    "description",
    "requires_oauth",
)
```

**Phase 36 edit:** append `"default_scope",` as the 8th tuple element. The existing `missing` check at lines 162–167 (verbatim below) will then catch missing fields automatically:

```python
# Check 4: required keys
missing = [k for k in REQUIRED_ENTRY_KEYS if k not in entry]
if missing:
    fail(location + " missing required keys: " + ", ".join(missing))
    errors += 1
    continue
```

**Enum-check pattern to mirror** — the existing `requires_oauth` bool check at lines 237–244 (verbatim):

```python
# Check 9: requires_oauth must be a boolean
requires_oauth = entry.get("requires_oauth")
if not isinstance(requires_oauth, bool):
    fail(
        location + ": .requires_oauth must be a boolean, got "
        + type(requires_oauth).__name__
    )
    errors += 1
```

**Phase 36 enum check (insert immediately after the `requires_oauth` block at line 244, before the for-loop ends):**

```python
# Check 11: default_scope must be "user" or "project" (Phase 36 / SCOPE-01)
default_scope = entry.get("default_scope")
if default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1
```

The check number `11` matches the existing comment-numbered cadence in the docstring (checks 1–10 listed at lines 26–38).

**Failure formatting** — the `fail()` helper at lines 74–75 (verbatim):

```python
def fail(message):
    print("ERROR: " + message, file=sys.stderr)
```

→ Match by passing the existing `location` variable + `repr(default_scope)` so error output is grep-able by tests (e.g., `default_scope` substring, `'user'` / `'project'` substrings).

**Docstring update** — the schema block at lines 7–24 lists every required key inline. Append `"default_scope": "user"|"project"` between `"requires_oauth"` and the closing brace. Then bump the "Checks performed" list at lines 26–38 from 10 to 11 entries, adding:

```text
  11. default_scope must equal "user" or "project" (Phase 36 SCOPE-01).
```

**CLI-only entries are NOT touched (D-03 invariant):** the per-entry walk iterates `mcp_section.items()` (line 147) which is `components.mcp` only. CLI entries (`components.cli.*`) are read separately by tests, never by this loop. No code change required to honor D-03 — it's automatic from the existing iteration shape.

**Path-override seam** — verified at lines 81–85:

```python
catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG_PATH
```

→ Negative-case test for TEST-06 reuses this seam by passing a path to a synthetic catalog: `python3 scripts/validate-integrations-catalog.py "$SANDBOX/bad.json"` and asserting non-zero exit + stderr containing `default_scope`.

---

### `scripts/lib/mcp.sh` (loader fallback)

**Analog:** self — three existing `// "default"` jq fallback sites in `mcp_catalog_load`.

**Function signature (line 78):**

```bash
mcp_catalog_load() {
    local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
```

→ The `TK_MCP_CATALOG_PATH` test seam (declared at line 33) is the path the new sibling test uses to point the loader at a synthetic catalog.

**Array-declaration pattern** (lines 100–108, verbatim — the Phase 34-01 block):

```bash
# Phase 34-01: parallel arrays for category grouping + component metadata.
# shellcheck disable=SC2034
MCP_CATEGORY=()
# shellcheck disable=SC2034
MCP_HAS_CLI=()
# shellcheck disable=SC2034
MCP_UNOFFICIAL=()
# shellcheck disable=SC2034
MCP_CLI_DETECT=()
```

**Phase 36 addition (mirror the block, insert after line 108):**

```bash
# Phase 36 (SCOPE-01/03): per-entry default scope ("user"|"project").
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE=()
```

**Per-entry populate pattern** — the closest precedent is `MCP_CATEGORY` at line 133 (verbatim, defaults string when missing):

```bash
# Phase 34-01: category (default empty string when missing for back-compat
# with v4.6 schema-v1 catalogs that lack the `category` field).
# shellcheck disable=SC2034
MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // ""' "$catalog_path")")
```

**Phase 36 populate (insert inside the `while IFS= read -r name; do … done` block at lines 110–160, after `MCP_CLI_DETECT+=` at line 158):**

```bash
# Phase 36 (SCOPE-03): default_scope with silent fallback to "user" for pre-v5.0
# catalogs that lack the field. Matches the .category // "" form on line 133.
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")
```

**Why `// "user"` and not branching on a string** — explicitly documented anti-pattern at line 146 (verbatim):

```bash
# Phase 34-01: CLI presence + detect_cmd. components.cli.<name> may be absent.
# `// empty` exits jq with no output when the path doesn't exist; capture and
# branch instead of relying on the brittle "null" string from `// null`.
```

→ For a string-typed field with a specific default like Phase 36's `"user"`, the `// "default"` form (matching line 133) is the established pattern. NOT `// null` + branch.

**Why no stderr emission** — D-11 (silent fallback). Existing precedent: `MCP_CATEGORY` and `MCP_UNOFFICIAL` populate silently. Loud stderr emissions in the file are reserved for hard errors (catalog missing — line 81; jq missing — line 85), NOT missing optional fields.

**Globals docstring** — at lines 13–27, the function header lists every parallel array. Phase 34-01 added a "Globals (write, Phase 34-01):" subsection (lines 20–27). Phase 36 should add a parallel subsection:

```bash
# Globals (write, Phase 36 (SCOPE-01/03)):
#   MCP_DEFAULT_SCOPE[]    — "user"|"project" (parallel; missing field → "user" fallback per D-09)
```

**Iteration source unchanged** — the `done < <(jq -r ...)` at line 160 (verbatim):

```bash
done < <(jq -r '.components.mcp | keys | sort | .[]' "$catalog_path")
```

→ Order = alphabetical-by-key; Phase 36 appends `MCP_DEFAULT_SCOPE` parallel to the other arrays in that exact order. No re-sort needed.

**Verified absent today:**

```bash
$ grep -n default_scope scripts/lib/mcp.sh
# (no matches as of 2026-05-04 — Phase 38 is the first consumer)
```

---

### `scripts/tests/test-integrations-catalog.sh` (validator-side meta-tests)

**Analog:** self — `_pyq` helper + 14 existing `_pyq` invocations (A1–A14).

**Test-file boilerplate** (lines 23–42, verbatim):

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CATALOG="${REPO_ROOT}/scripts/lib/integrations-catalog.json"

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
```

→ Already in place; A15/A16/A17 reuse `_pyq` and `assert_pass/assert_fail`. No boilerplate changes.

**`_pyq` helper** (lines 67–86, verbatim):

```bash
# Helper: run python3 inline against the catalog and emit OK / FAIL <msg>.
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

**Existing assertion shape** (A6, lines 130–143, verbatim — closest match for "every entry must have <key>"):

```bash
# ─────────────────────────────────────────────────
# A6 — every MCP entry has the required keys
# ─────────────────────────────────────────────────
_pyq "A6: every MCP entry has all required keys" '
required = ("name", "display_name", "category", "install_args", "env_var_keys",
            "requires_oauth", "description")
mcp = catalog.get("components", {}).get("mcp", {})
missing = []
for name, entry in mcp.items():
    miss = [k for k in required if k not in entry]
    if miss:
        missing.append((name, miss))
if not missing:
    print("OK")
else:
    print("entries missing required keys: " + repr(missing))
'
```

**Phase 36 additions — A15/A16/A17** (insert after A14 at line 273, before the result echo at line 274–276):

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

**Exit pattern** (lines 274–276, verbatim — UNCHANGED):

```bash
echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

**Baseline arithmetic:** existing PASS = 14 (A1–A14). After Phase 36: PASS = 17. D-12 says `PASS ≥ 10` (a floor), so the increase is non-breaking.

---

### `scripts/tests/test-catalog-scope-fallback.sh` (NEW — loader-side hermetic test)

**Analog:** `scripts/tests/test-mcp-selector.sh::run_s1_catalog_correctness` (lines 64–86) for the synthetic-sandbox harness, plus `run_s2_detection_three_state` (lines 92–169) for the `bash -c "source ...; ..."` subshell + stderr capture pattern.

**Header / boilerplate pattern** (mirror `test-integrations-catalog.sh:1–42` exactly):

```bash
#!/usr/bin/env bash
# test-catalog-scope-fallback.sh — Phase 36 (SCOPE-03 / D-14) hermetic backward-compat test.
#
# Locks the v5.0 contract for `mcp_catalog_load` against pre-v5.0 catalogs:
#   - Synthetic catalog with one MCP entry missing `default_scope` loads cleanly.
#   - MCP_DEFAULT_SCOPE[<missing entry idx>] equals "user" (silent fallback per D-09).
#   - MCP_DEFAULT_SCOPE[<present entry idx>] equals the catalog value verbatim.
#   - Loader emits NO stderr for the missing-field case (D-11 silent contract).
#
# Hermetic — does NOT shell out to claude/brew/network. Sources mcp.sh + jq + bash.
#
# Usage: bash scripts/tests/test-catalog-scope-fallback.sh
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
```

**Synthetic-catalog harness pattern** — verbatim from `test-mcp-selector.sh:64–69`:

```bash
run_s1_catalog_correctness() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_catalog_correctness: 20 entries, alpha order, notion OAuth --"
```

**Subshell + stderr capture pattern** — verbatim from `test-mcp-selector.sh:111–117`:

```bash
local rc=0
TK_MCP_CLAUDE_BIN="$MOCK_CLAUDE" bash -c "
    source '${REPO_ROOT}/scripts/lib/mcp.sh'
    is_mcp_installed context7
    exit \$?
" 2>/dev/null || rc=$?
assert_eq "0" "$rc" "S2: is_mcp_installed context7 returns 0 (installed)"
```

**Phase 36 fallback test (composed from the two patterns above):**

```bash
echo "test-catalog-scope-fallback.sh: Phase 36 D-14 silent-fallback contract"
echo ""

run_bc1_silent_fallback_to_user() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC1: catalog missing default_scope → loader fallback to 'user', no stderr --"

    # Synthetic catalog: 1 entry WITH default_scope, 1 WITHOUT.
    cat > "$SANDBOX/synth-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "withscope": {
        "name": "withscope",
        "display_name": "With",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["withscope", "--", "echo"],
        "description": "with",
        "requires_oauth": false,
        "default_scope": "project"
      },
      "noscope": {
        "name": "noscope",
        "display_name": "Without",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["noscope", "--", "echo"],
        "description": "without",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local stdout_tmp="$SANDBOX/stdout"
    local rc=0
    TK_MCP_CATALOG_PATH="$SANDBOX/synth-catalog.json" bash -c "
        source '${REPO_ROOT}/scripts/lib/mcp.sh'
        mcp_catalog_load
        for i in \"\${!MCP_NAMES[@]}\"; do
            printf '%s=%s\n' \"\${MCP_NAMES[\$i]}\" \"\${MCP_DEFAULT_SCOPE[\$i]}\"
        done
    " >"$stdout_tmp" 2>"$stderr_tmp" || rc=$?

    assert_eq "0" "$rc" "BC1.1: mcp_catalog_load returns 0 on catalog missing default_scope"

    # Parse stdout for the two entries.
    local noscope_ds withscope_ds
    noscope_ds=$(grep '^noscope=' "$stdout_tmp" | head -1 | cut -d= -f2)
    withscope_ds=$(grep '^withscope=' "$stdout_tmp" | head -1 | cut -d= -f2)
    assert_eq "user"    "$noscope_ds"    "BC1.2: missing default_scope → MCP_DEFAULT_SCOPE='user'"
    assert_eq "project" "$withscope_ds"  "BC1.3: present default_scope='project' preserved verbatim"

    # D-11 silent contract — stderr must be empty.
    local stderr_size
    stderr_size=$(wc -c < "$stderr_tmp" | tr -d ' ')
    assert_eq "0" "$stderr_size" "BC1.4: loader emits no stderr on missing default_scope (D-11 silent)"
}

# Negative-case validator test (TEST-06 negative: synthetic catalog must fail validation).
run_bc2_validator_rejects_missing_field() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC2: validator rejects synthetic catalog missing default_scope --"

    cat > "$SANDBOX/bad-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "noscope": {
        "name": "noscope",
        "display_name": "Without",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["noscope", "--", "echo"],
        "description": "without",
        "requires_oauth": false
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/bad-catalog.json" \
        >/dev/null 2>"$stderr_tmp" || rc=$?

    # Validator must fail (non-zero exit).
    if [[ "$rc" -ne 0 ]]; then
        assert_pass "BC2.1: validator exits non-zero on catalog missing default_scope"
    else
        assert_fail "BC2.1: validator exits non-zero on catalog missing default_scope" "rc=0 (expected non-zero)"
    fi

    # Error message must reference default_scope so users can locate the field.
    if grep -q "default_scope" "$stderr_tmp"; then
        assert_pass "BC2.2: validator stderr mentions default_scope"
    else
        assert_fail "BC2.2: validator stderr mentions default_scope" "stderr did not contain 'default_scope'"
    fi
}

# Positive-case validator test — synthetic catalog with valid default_scope passes.
run_bc3_validator_accepts_valid_enum() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC3: validator accepts catalog with valid default_scope enum --"

    cat > "$SANDBOX/good-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "alpha": {
        "name": "alpha",
        "display_name": "Alpha",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["alpha", "--", "echo"],
        "description": "alpha",
        "requires_oauth": false,
        "default_scope": "user"
      },
      "beta": {
        "name": "beta",
        "display_name": "Beta",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["beta", "--", "echo"],
        "description": "beta",
        "requires_oauth": false,
        "default_scope": "project"
      }
    }
  }
}
JSON

    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/good-catalog.json" \
        >/dev/null 2>&1 || rc=$?
    assert_eq "0" "$rc" "BC3.1: validator exits 0 on synthetic catalog with valid default_scope values"
}

# Negative-case validator test — invalid enum value must fail.
run_bc4_validator_rejects_invalid_enum() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-scope-fallback.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- BC4: validator rejects invalid default_scope enum value --"

    cat > "$SANDBOX/invalid-enum-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "alpha": {
        "name": "alpha",
        "display_name": "Alpha",
        "category": "dev-tools",
        "env_var_keys": [],
        "install_args": ["alpha", "--", "echo"],
        "description": "alpha",
        "requires_oauth": false,
        "default_scope": "global"
      }
    }
  }
}
JSON

    local stderr_tmp="$SANDBOX/stderr"
    local rc=0
    python3 "${REPO_ROOT}/scripts/validate-integrations-catalog.py" "$SANDBOX/invalid-enum-catalog.json" \
        >/dev/null 2>"$stderr_tmp" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        assert_pass "BC4.1: validator exits non-zero on invalid enum value"
    else
        assert_fail "BC4.1: validator exits non-zero on invalid enum value" "rc=0 (expected non-zero)"
    fi
    if grep -q "default_scope" "$stderr_tmp"; then
        assert_pass "BC4.2: validator stderr mentions default_scope"
    else
        assert_fail "BC4.2: validator stderr mentions default_scope" "stderr missing 'default_scope'"
    fi
}

run_bc1_silent_fallback_to_user
run_bc2_validator_rejects_missing_field
run_bc3_validator_accepts_valid_enum
run_bc4_validator_rejects_invalid_enum

echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

**Why subshell `bash -c "..."` and not direct sourcing** (matches `test-mcp-selector.sh:113–117` and `155–161`):

- Isolates `MCP_*` global state per scenario (no cross-scenario contamination).
- `2>"$stderr_tmp"` captures the loader's stderr cleanly so D-11 silent-contract assertions can verify byte-zero stderr.
- Reset between scenarios is automatic (each `bash -c` is a fresh shell).
- Bash 3.2 compatible — no `mapfile`/`declare -n`/process substitution required (only `<( )` for jq is in `mcp.sh` itself, untouched).

**Heredoc caveats** (avoids Pitfall 5 from RESEARCH.md):
- Use `<<'JSON'` (single-quoted delimiter) to disable `$` expansion inside the synthetic catalog literal.
- Use `<<'MOCK'` style is the established precedent at `test-mcp-selector.sh:101–108`.

**Lessons-learned guard (260430-go5):** "Single-CLI scenarios are first-class test cases" — BC1 covers BOTH a present `default_scope` (`withscope`) AND an absent `default_scope` (`noscope`) in the same synthetic catalog. Asymmetric coverage prevents an "all-present" or "all-absent" accidental green.

---

### `Makefile` (test target wiring)

**Analog:** existing "Test 47:" entry at lines 219–222 (verbatim):

```makefile
	@echo "Test 47: integrations TUI redesign (TEST-03 — Phase 35)"
	@bash scripts/tests/test-integrations-tui.sh
	@echo ""
	@echo "All tests passed!"
```

**Phase 36 addition (insert immediately before the `@echo "All tests passed!"` line — line 223 currently):**

```makefile
	@echo "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"
	@bash scripts/tests/test-catalog-scope-fallback.sh
	@echo ""
	@echo "All tests passed!"
```

**Optional — add invokable standalone target** (mirrors the lines 250–260 pattern for tests 45/46/47):

```makefile
# Test 48 — catalog default_scope fallback (Phase 36 / SCOPE-03), invokable standalone
test-catalog-scope-fallback:
	@bash scripts/tests/test-catalog-scope-fallback.sh
```

Add the corresponding target name to the `.PHONY` line at the top of the Makefile (line 1):

```makefile
.PHONY: ... test-catalog-scope-fallback ...
```

**`make check` is unchanged** — D-05 confirmed at Makefile lines 19 + 415–417:

```makefile
# Line 19
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static \
       validate-commands validate-catalog validate-mdlint-config-sync validate-skills-desktop \
       validate-marketplace cell-parity

# Lines 415–417
validate-catalog:
	@echo "Validating integrations-catalog.json schema (CAT-03)..."
	@python3 scripts/validate-integrations-catalog.py
```

→ The new SCOPE-01 enforcement check inside the validator runs through `make check` automatically. NO Makefile changes for the validator.

---

## Shared Patterns

### Silent-fallback semantics (D-11 contract)

**Source:** `scripts/lib/mcp.sh:130–142` (the `MCP_CATEGORY` and `MCP_UNOFFICIAL` precedent — both are silent on missing fields).

**Apply to:** `scripts/lib/mcp.sh` Phase 36 `MCP_DEFAULT_SCOPE` populate.

**Concrete excerpt** (lines 130–142, verbatim):

```bash
# Phase 34-01: category (default empty string when missing for back-compat
# with v4.6 schema-v1 catalogs that lack the `category` field).
# shellcheck disable=SC2034
MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // ""' "$catalog_path")")

# Phase 34-01: unofficial flag (default 0; 1 only when set true).
if [[ "$(jq -r --arg n "$name" '.components.mcp[$n].unofficial // false' "$catalog_path")" == "true" ]]; then
    # shellcheck disable=SC2034
    MCP_UNOFFICIAL+=(1)
else
    # shellcheck disable=SC2034
    MCP_UNOFFICIAL+=(0)
fi
```

**Rule:** silent fallback for OPTIONAL fields. Loud stderr is reserved for HARD errors (lines 81 + 85 — catalog missing or jq missing). Phase 36 follows the optional-field pattern.

### `# shellcheck disable=SC2034` annotation

**Source:** every parallel-array declaration and append in `mcp.sh:88–108` and `110–160`.

**Apply to:** every new line that touches `MCP_DEFAULT_SCOPE` in `mcp.sh`. SC2034 = "var appears unused" (correct: array is consumed by Phase 38 wizard, not in this file).

### Bash 3.2 compatibility

**Source:** `STACK.md` line 9, `CLAUDE.md` "POSIX-compatible Bash 3.2+", lessons-learned 260430-go5.

**Apply to:** `scripts/tests/test-catalog-scope-fallback.sh`.

**Forbidden constructs** (do NOT use in the new test file):
- `declare -A` (associative arrays — Bash 4+)
- `mapfile` / `readarray` (Bash 4+)
- `${var,,}` / `${var^^}` (Bash 4+ case folding)
- `read -N <count>` (Bash 4+; `read -n` is fine)
- `read -t <float>` (Bash 4+ accepts floats; 3.2 only integer)
- `declare -n` nameref (Bash 4.3+)

**Approved constructs** (verified in existing test files):
- Plain `[[ "$a" == "$b" ]]`
- `for ((i=0; i<${#arr[@]}; i++))`
- `${arr[@]+"${arr[@]}"}` empty-array guard (mcp.sh:200)
- `local IFS_SAVED="$IFS"; IFS=':' ; ... ; IFS="$IFS_SAVED"` for split

### Conventional Commits commit message

**Source:** CLAUDE.md "Commit Conventions", `.planning/codebase/CONVENTIONS.md`.

**Apply to:** the single Phase 36 commit (D-10 — no two-commit split).

**Recommended message** (matches RESEARCH.md proposal at line 896):

```text
feat: phase 36 — default_scope schema + validator + backward-compat loader (SCOPE-01..03)
```

### `set -euo pipefail` on every new test script

**Source:** `scripts/tests/test-integrations-catalog.sh:23`, `scripts/tests/test-mcp-selector.sh:19`.

**Apply to:** `scripts/tests/test-catalog-scope-fallback.sh` (line 16 of the proposed body).

### Markdown lint compliance for any new `.md` (PLAN.md, etc.)

**Source:** `.markdownlint.json`, `CLAUDE.md` "Markdown Formatting (CRITICAL)".

**Apply to:** PLAN.md or any other doc Phase 36 produces. Rules to honor: MD040 (lang on every fence), MD031/MD032 (blanks around fences/lists), MD026 (no trailing punctuation in headings).

---

## No Analog Found

(none)

Every file Phase 36 modifies or creates has at least one direct in-repo precedent. The only "new" file is `scripts/tests/test-catalog-scope-fallback.sh`, but its harness pattern is verbatim from `test-mcp-selector.sh:64–169`.

## Metadata

**Analog search scope:**
- `scripts/lib/mcp.sh` (1008 lines)
- `scripts/validate-integrations-catalog.py` (267 lines)
- `scripts/lib/integrations-catalog.json` (428 lines)
- `scripts/tests/test-integrations-catalog.sh` (276 lines)
- `scripts/tests/test-mcp-selector.sh` (425 lines)
- `Makefile` (450 lines)

**Files scanned:** 6 (in-scope) + cross-references via Grep `default_scope`, `// "default"`, `_pyq`, `mktemp -d`.

**Pattern extraction date:** 2026-05-04

**Verification method:** every line-range cited has been read directly from the working tree on 2026-05-04 (post-RESEARCH). Zero claims rely on memory or grep-only output.
