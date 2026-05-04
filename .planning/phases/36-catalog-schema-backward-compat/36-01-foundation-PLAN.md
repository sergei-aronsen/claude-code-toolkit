---
phase: 36
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/integrations-catalog.json
  - scripts/validate-integrations-catalog.py
  - scripts/lib/mcp.sh
autonomous: true
requirements:
  - SCOPE-01
  - SCOPE-02
  - SCOPE-03

must_haves:
  truths:
    - "Every MCP entry in scripts/lib/integrations-catalog.json carries default_scope with value 'user' or 'project'"
    - "Validator (scripts/validate-integrations-catalog.py) fails loudly when any MCP entry lacks default_scope or has an invalid enum value"
    - "Loader (mcp_catalog_load in scripts/lib/mcp.sh) populates a new MCP_DEFAULT_SCOPE[] parallel array from the catalog"
    - "Loader silently treats a missing default_scope as 'user' (no stderr emission) — preserves pre-v5.0 catalogs (D-09/D-11)"
    - "make check runs the extended validator and stays green on the shipped catalog"
  artifacts:
    - path: "scripts/lib/integrations-catalog.json"
      provides: "20 MCP entries each carrying default_scope per the locked SCOPE-02 grid"
      contains: '"default_scope":'
    - path: "scripts/validate-integrations-catalog.py"
      provides: "Schema enforcement for default_scope (presence + enum)"
      contains: 'default_scope'
    - path: "scripts/lib/mcp.sh"
      provides: "MCP_DEFAULT_SCOPE[] parallel array + jq // \"user\" silent fallback"
      contains: 'MCP_DEFAULT_SCOPE'
  key_links:
    - from: "scripts/lib/integrations-catalog.json"
      to: "scripts/validate-integrations-catalog.py"
      via: "Make target validate-catalog (Makefile lines 415-417)"
      pattern: "REQUIRED_ENTRY_KEYS.*default_scope"
    - from: "scripts/lib/integrations-catalog.json"
      to: "scripts/lib/mcp.sh::mcp_catalog_load"
      via: "jq read inside while loop"
      pattern: 'jq -r.*default_scope.*// "user"'
---

<objective>
Land the v5.0 per-MCP scope foundation in a single commit (D-10 single-landing invariant): seed `default_scope` on all 20 MCP entries in `scripts/lib/integrations-catalog.json` per the locked SCOPE-02 grid, extend the existing validator to enforce presence + enum on every MCP entry (SCOPE-01), and add a silent `// "user"` jq fallback in `mcp_catalog_load` so pre-v5.0 catalogs continue to work without stderr noise (SCOPE-03 / D-09 / D-11).

Purpose: This is the foundation phase for v5.0. Every downstream phase (37 secrets lib, 38 wizard dispatch, 39 TUI per-row toggle, 40 uninstall + Calendly) reads `default_scope` from the catalog. The schema field, validator enforcement, and loader fallback ship together (D-10) so there is never a window where the catalog is stricter than the loader.

Output: 20-entry catalog edit + 2-site Python validator extension + 3-site Bash loader extension. No new files in this plan. Tests land in Plan 02.
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
@scripts/lib/integrations-catalog.json
@scripts/validate-integrations-catalog.py
@scripts/lib/mcp.sh

<interfaces>
<!-- Key contracts the executor needs. Extracted from RESEARCH.md + PATTERNS.md. -->

### Catalog field-order rule (verified from existing entries)

Existing canonical order per `components.mcp.<name>` block:
`name`, `display_name`, `category`, `env_var_keys`, `install_args`, `description`, `requires_oauth`, then optionally `unofficial`.

Phase 36 appends `default_scope` LAST in each block (after `unofficial` when present, otherwise after `requires_oauth`).

### Validator extension sites (scripts/validate-integrations-catalog.py)

Site 1 — REQUIRED_ENTRY_KEYS tuple at lines 60-68:

```python
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

Site 2 — per-entry walk at lines 145-244 (loops `mcp_section.items()`); enum check goes after the `requires_oauth` bool check at lines 237-244:

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

Site 3 — docstring at lines 7-24 + checks-performed list at lines 26-38.

Path-override seam at lines 81-85 (used by Plan 02 negative tests): `catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG_PATH`.

### Loader extension sites (scripts/lib/mcp.sh)

Site 1 — array declaration block at lines 100-108 (Phase 34-01 declarations):

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

Site 2 — per-name populate inside `while IFS= read -r name; do … done` loop (lines 110-160), insert after `MCP_CLI_DETECT+=` at line 158. Existing precedent (line 133):

```bash
MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // ""' "$catalog_path")")
```

Site 3 — function-header docstring at lines 13-27 (Globals (write, Phase 34-01) block).

Iteration source (line 160, unchanged):
```bash
done < <(jq -r '.components.mcp | keys | sort | .[]' "$catalog_path")
```

### SCOPE-02 grid (locked, copied verbatim from CONTEXT.md D-06/D-07)

Personal-tooling MCPs default `user` (10 entries):
`firecrawl`, `notebooklm`, `notion`, `youtrack`, `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`

Per-app infra MCPs default `project` (10 entries):
`supabase`, `cloudflare`, `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `jira`, `linear`, `telegram`

NOT in catalog (D-08 — Phase 40): `calendly`. Do NOT add it here.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Seed default_scope on all 20 MCP entries (SCOPE-02)</name>
  <files>scripts/lib/integrations-catalog.json</files>
  <read_first>
    - scripts/lib/integrations-catalog.json (the file being modified — read all 428 lines to confirm current shape and the 20 mcp.<name> blocks)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog: existing block shapes, diff sketches at lines 28-87, field-order rule)
    - .planning/phases/36-catalog-schema-backward-compat/36-RESEARCH.md (Catalog Inventory table at lines 339-364 — locks each name → scope mapping)
  </read_first>
  <action>
    Append a `"default_scope": "<scope>"` field (per D-01 — add to every MCP block; D-02 — enum is `"user"` or `"project"` only) as the LAST key inside each of the 20 `components.mcp.<name>` blocks in `scripts/lib/integrations-catalog.json`. Follow the field-order rule: insert AFTER `requires_oauth` when no `unofficial` field exists; AFTER `unofficial` when it does.

    Insert `"default_scope": "user"` (per D-06) in these 10 MCP blocks:
    - `context7` (line 70)
    - `figma` (line 87)
    - `firecrawl` (line 104)
    - `magic` (line 157)
    - `notebooklm` (line 174 — has `unofficial: true`, insert after `unofficial`)
    - `notion` (line 190)
    - `openrouter` (line 205)
    - `playwright` (line 222)
    - `sentry` (line 254)
    - `youtrack` (line 342)

    Insert `"default_scope": "project"` (per D-07) in these 10 MCP blocks:
    - `aws-cloudwatch-logs` (line 17)
    - `aws-cost-explorer` (line 35)
    - `cloudflare` (line 53)
    - `jira` (line 121)
    - `linear` (line 140)
    - `resend` (line 237)
    - `slack` (line 271)
    - `stripe` (line 289)
    - `supabase` (line 306)
    - `telegram` (line 323 — check whether it has `unofficial`; if so, insert after it)

    Mechanics:
    - Hand-edit only — do NOT use `sed -i` (BSD vs GNU portability — Pitfall 1 in RESEARCH.md).
    - When the previous line was `"requires_oauth": false` (no `unofficial`), change it to `"requires_oauth": false,` and add `  "default_scope": "<scope>"` on the next line at the same indent (2 spaces × 3 = 6 columns inside the block).
    - When the previous line was `"unofficial": true` (block has unofficial), change it to `"unofficial": true,` and add `  "default_scope": "<scope>"` after.
    - Preserve 2-space indent, jq-canonical quote style (`"` only), no trailing commas, trailing newline at EOF.
    - Do NOT touch `components.cli.*` entries (D-03 invariant — CLI-only entries have no scope concept).
    - Do NOT add a `calendly` entry (D-08 — lands in Phase 40).

    After editing, run `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"` to confirm the file is still valid JSON before declaring done (catches Pitfall 3 trailing-comma injection).
  </action>
  <verify>
    <automated>
      python3 -c "
      import json, sys
      with open('scripts/lib/integrations-catalog.json') as fh:
          c = json.load(fh)
      mcp = c['components']['mcp']
      assert len(mcp) == 20, f'expected 20 MCP entries, got {len(mcp)}'
      user_set = {'firecrawl','notebooklm','notion','youtrack','context7','openrouter','figma','playwright','magic','sentry'}
      project_set = {'supabase','cloudflare','stripe','slack','resend','aws-cost-explorer','aws-cloudwatch-logs','jira','linear','telegram'}
      assert user_set | project_set == set(mcp.keys()), 'grid does not match catalog keys'
      for name, entry in mcp.items():
          assert 'default_scope' in entry, f'{name} missing default_scope'
          want = 'user' if name in user_set else 'project'
          assert entry['default_scope'] == want, f'{name}: got {entry[\"default_scope\"]!r}, want {want!r}'
      print('OK')
      "
    </automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/lib/integrations-catalog.json` parses as valid JSON via `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"` (exit 0, no output).
    - Verification command above prints `OK` and exits 0.
    - `grep -c '"default_scope":' scripts/lib/integrations-catalog.json` returns exactly `20`.
    - `grep -c '"default_scope": "user"' scripts/lib/integrations-catalog.json` returns exactly `10`.
    - `grep -c '"default_scope": "project"' scripts/lib/integrations-catalog.json` returns exactly `10`.
    - `grep -E '"calendly"|"google-workspace"' scripts/lib/integrations-catalog.json` returns no matches (D-08 — Calendly deferred to Phase 40; D-14/INT-14 — Google Workspace deliberately absent).
    - Field-order rule respected: `python3 -c "import json,sys; c=json.load(open('scripts/lib/integrations-catalog.json')); [print(name, list(e.keys())[-1]) for name,e in c['components']['mcp'].items()]"` shows `default_scope` is the LAST key in every block.
    - `git diff --stat scripts/lib/integrations-catalog.json` shows additions only (no removed lines except the requires_oauth/unofficial lines that gained a trailing comma).
  </acceptance_criteria>
  <done>
    All 20 MCP entries carry the correct `default_scope` value per the locked SCOPE-02 grid; JSON is structurally valid; CLI-only entries untouched; no Calendly entry added.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Extend validator to enforce default_scope (SCOPE-01)</name>
  <files>scripts/validate-integrations-catalog.py</files>
  <read_first>
    - scripts/validate-integrations-catalog.py (the file being modified — read all 267 lines to confirm REQUIRED_ENTRY_KEYS at lines 60-68, the per-entry walk at lines 145-244, the requires_oauth bool check at lines 237-244 as the analog, the docstring at lines 7-38, and the path-override seam at lines 81-85)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog: validator-extension pattern at lines 105-198 with verbatim diff sketches)
    - .planning/phases/36-catalog-schema-backward-compat/36-RESEARCH.md (Validator Walk excerpts at lines 366-422)
  </read_first>
  <behavior>
    - Per D-04 (validator fails loudly on missing/invalid) + D-05 (make check invokes the validator).
    - When the validator runs against the shipped catalog (post-Task-1 edits), it MUST pass with exit 0 and zero error output.
    - When the validator runs against a synthetic catalog where one MCP entry omits `default_scope`, it MUST exit non-zero AND print an error to stderr containing the substring `default_scope` AND the entry's location (e.g., `components.mcp.<name>`).
    - When the validator runs against a synthetic catalog where one MCP entry has `default_scope` set to anything other than `"user"` or `"project"` (e.g., `"global"`, `null`, `42`), it MUST exit non-zero AND the stderr message MUST contain `default_scope` AND the literal repr of the bad value (so `'global'` for the string case, `None` for null).
    - The check is logically check #11 (existing checks 1-10 documented at lines 26-38).
    - CLI-only entries (`components.cli.*`) MUST NOT be touched by the new check (D-03).
  </behavior>
  <action>
    Make three edits to `scripts/validate-integrations-catalog.py`, all in-place, no new file (per D-13):

    Site 1 — extend `REQUIRED_ENTRY_KEYS` (lines 60-68): add `"default_scope",` as the 8th element of the tuple. The existing missing-keys check at lines 162-167 will then automatically catch entries lacking the field.

    Final tuple should read exactly:

    ```python
    REQUIRED_ENTRY_KEYS = (
        "name",
        "display_name",
        "category",
        "env_var_keys",
        "install_args",
        "description",
        "requires_oauth",
        "default_scope",
    )
    ```

    Site 2 — add an enum check immediately AFTER the `requires_oauth` bool check (currently at lines 237-244, ending with `errors += 1`). Mirror the bool-check style verbatim. Insert this block:

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

    The check stays inside the existing `for name, entry in mcp_section.items():` loop (the loop that defines `location` for each MCP entry — verify by reading the surrounding lines). Use `entry.get("default_scope")` (not `entry["default_scope"]`) so that when the key is missing the existing missing-keys check at line 162-167 emits the required-key error on its own and the enum check sees `None` (which is also `not in ("user","project")` — defense in depth, but the missing-keys check fires first via the `continue` at line 167).

    Site 3 — update the docstring at lines 7-38:
    - In the inline schema example (lines 7-24), add `"default_scope": "user"|"project"` between the existing `"requires_oauth"` line and the closing brace of the entry shape.
    - In the "Checks performed:" list (lines 26-38, currently 10 items), add `11. default_scope must equal "user" or "project" (Phase 36 SCOPE-01).` as the 11th bullet.

    Do NOT add new imports (the check uses only `not in` against a tuple literal — already-imported `repr` is a builtin). Do NOT touch `EXPECTED_SCHEMA_VERSION` (still 2 — additive change per RESEARCH.md anti-pattern note). Do NOT add any other check beyond the SCOPE-01 enum.
  </action>
  <verify>
    <automated>
      python3 scripts/validate-integrations-catalog.py
      # Positive: exits 0 against shipped catalog (post-Task-1).
      # Then negative on a synthetic catalog:
      TMP=$(mktemp -d /tmp/p36-validator-test.XXXXXX)
      trap "rm -rf '$TMP'" EXIT
      cat > "$TMP/missing.json" <<'JSON'
      {"schema_version":2,"categories":["dev-tools"],"components":{"mcp":{"x":{"name":"x","display_name":"X","category":"dev-tools","env_var_keys":[],"install_args":["x","--","echo"],"description":"x","requires_oauth":false}}}}
      JSON
      cat > "$TMP/bad-enum.json" <<'JSON'
      {"schema_version":2,"categories":["dev-tools"],"components":{"mcp":{"x":{"name":"x","display_name":"X","category":"dev-tools","env_var_keys":[],"install_args":["x","--","echo"],"description":"x","requires_oauth":false,"default_scope":"global"}}}}
      JSON
      ! python3 scripts/validate-integrations-catalog.py "$TMP/missing.json" 2>&1 | grep -q default_scope && echo "MISSING TEST FAILED" && exit 1
      ! python3 scripts/validate-integrations-catalog.py "$TMP/bad-enum.json" 2>&1 | grep -q "default_scope.*'global'" && echo "BAD-ENUM TEST FAILED" && exit 1
      echo "OK"
    </automated>
  </verify>
  <acceptance_criteria>
    - `python3 scripts/validate-integrations-catalog.py` (default catalog path) exits 0 with empty stderr against the shipped catalog (post Task 1).
    - `grep -n '"default_scope",' scripts/validate-integrations-catalog.py` returns exactly one match — the new line inside `REQUIRED_ENTRY_KEYS` between `"requires_oauth",` and the closing `)`.
    - `grep -n 'default_scope must be' scripts/validate-integrations-catalog.py` returns exactly one match — the new fail-message line inside Check 11.
    - `python3 -c "import ast,sys; src=open('scripts/validate-integrations-catalog.py').read(); ast.parse(src); print('parses')"` prints `parses` (no Python syntax errors).
    - `make validate-catalog` (Makefile target line 415-417) exits 0.
    - Negative test (synthetic catalog missing the field): `python3 scripts/validate-integrations-catalog.py /tmp/synth-missing.json` exits non-zero AND its combined output contains the literal string `default_scope`.
    - Negative test (synthetic catalog with `default_scope: "global"`): same script exits non-zero AND combined output contains the substring `default_scope` AND contains `'global'` (the repr of the bad value).
    - `EXPECTED_SCHEMA_VERSION` constant in the validator is still `2` (no schema bump).
    - shellcheck-equivalent for Python: `make check` continues to invoke validate-catalog with no syntax/runtime regression.
  </acceptance_criteria>
  <done>
    Validator extension lands in place; positive path is green against the shipped catalog; both negative paths (missing field, invalid enum) fail loudly with `default_scope` in the error message.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Add MCP_DEFAULT_SCOPE[] parallel array + silent fallback in mcp_catalog_load (SCOPE-03)</name>
  <files>scripts/lib/mcp.sh</files>
  <read_first>
    - scripts/lib/mcp.sh (the file being modified — read lines 1-185, paying attention to: docstring at lines 13-27 listing every parallel array; array-declaration block at lines 100-108; `while IFS= read -r name; do … done` body at lines 110-160; the `MCP_CATEGORY+=` precedent at line 133 with `// ""` fallback; the `MCP_UNOFFICIAL` precedent at lines 135-142; the iteration source at line 160; the catalog-missing hard error at line 81; the jq-missing hard error at line 85; the test seam declaration at line 33)
    - .planning/phases/36-catalog-schema-backward-compat/36-PATTERNS.md (analog: loader-extension excerpts at lines 200-289)
    - .planning/phases/36-catalog-schema-backward-compat/36-RESEARCH.md (Loader Walk excerpts at lines 423-475)
  </read_first>
  <behavior>
    - Sourcing `scripts/lib/mcp.sh` and calling `mcp_catalog_load` against the (post-Task-1) shipped catalog populates a new `MCP_DEFAULT_SCOPE[]` array parallel to `MCP_NAMES[]`, with values exactly matching the SCOPE-02 grid (10 `user`, 10 `project`).
    - Calling `mcp_catalog_load` against a synthetic catalog where one MCP omits `default_scope` returns 0, populates `MCP_DEFAULT_SCOPE[<idx of missing entry>]` with `"user"`, populates other entries verbatim, and emits ZERO bytes on stderr (D-09 / D-11 silent contract).
    - The new array is `# shellcheck disable=SC2034` annotated (consumed by Phase 38 wizard, not in this file).
    - Phase 36 changes do NOT alter the iteration source at line 160 (alphabetical-by-key) — `MCP_DEFAULT_SCOPE` order MUST stay parallel to `MCP_NAMES`.
  </behavior>
  <action>
    Make three edits to `scripts/lib/mcp.sh`. All edits are inside `mcp_catalog_load` and its docstring; no new function.

    Site 1 — docstring update at lines 13-27: add a "Phase 36 (SCOPE-01/03)" Globals subsection. Insert it directly after the existing "Phase 34-01" Globals block (the existing block ends near line 27). The new lines:

    ```bash
    # Globals (write, Phase 36 (SCOPE-01/03)):
    #   MCP_DEFAULT_SCOPE[]    — "user"|"project" (parallel; missing field → "user" fallback per D-09)
    ```

    Site 2 — array declaration: add a new declaration block immediately after the existing Phase 34-01 declaration block at lines 100-108. The exact text to add (preserving the surrounding `# shellcheck disable=SC2034` style — match the precedent verbatim):

    ```bash
    # Phase 36 (SCOPE-01/03): per-entry default scope ("user"|"project").
    # shellcheck disable=SC2034
    MCP_DEFAULT_SCOPE=()
    ```

    Site 3 — per-name populate: inside the `while IFS= read -r name; do … done` loop body (lines 110-160), append a new line AFTER the existing `MCP_CLI_DETECT+=` populate at line 158, BEFORE the `done` at line 160. The exact line (matches the `MCP_CATEGORY` precedent at line 133 verbatim — same `// "default"` form, same `--arg n "$name"` flag, same `# shellcheck disable=SC2034` annotation):

    ```bash
    # Phase 36 (SCOPE-03): default_scope with silent fallback to "user" for pre-v5.0
    # catalogs that lack the field. Matches the .category // "" form on line 133.
    # shellcheck disable=SC2034
    MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")
    ```

    Do NOT use `// null` followed by string-equality branch on `"null"` — explicit anti-pattern documented at line 146 of the same file. Do NOT emit any stderr line on missing field (D-11). Do NOT touch the iteration source at line 160 (alphabetical by-key — MCP_DEFAULT_SCOPE inherits this order). Do NOT use Bash 4+ constructs (`mapfile`, `declare -A`, `${var,,}`).
  </action>
  <verify>
    <automated>
      shellcheck -S warning scripts/lib/mcp.sh
      # Positive: source loader, dump MCP_DEFAULT_SCOPE in order against shipped catalog.
      bash -c "
        set -euo pipefail
        source scripts/lib/mcp.sh
        mcp_catalog_load
        # Build expected arrays in sorted order matching iteration source.
        names=\$(printf '%s\n' \"\${MCP_NAMES[@]}\" | tr '\n' ' ')
        scopes=\$(printf '%s\n' \"\${MCP_DEFAULT_SCOPE[@]}\" | tr '\n' ' ')
        [ \"\${#MCP_NAMES[@]}\" = '20' ] || { echo \"NAMES count: \${#MCP_NAMES[@]}\"; exit 1; }
        [ \"\${#MCP_DEFAULT_SCOPE[@]}\" = '20' ] || { echo \"SCOPE count: \${#MCP_DEFAULT_SCOPE[@]}\"; exit 1; }
        for i in \"\${!MCP_NAMES[@]}\"; do
          n=\"\${MCP_NAMES[\$i]}\"
          s=\"\${MCP_DEFAULT_SCOPE[\$i]}\"
          case \"\$n\" in
            firecrawl|notebooklm|notion|youtrack|context7|openrouter|figma|playwright|magic|sentry)
              [ \"\$s\" = 'user' ] || { echo \"\$n: got \$s, want user\"; exit 1; } ;;
            supabase|cloudflare|stripe|slack|resend|aws-cost-explorer|aws-cloudwatch-logs|jira|linear|telegram)
              [ \"\$s\" = 'project' ] || { echo \"\$n: got \$s, want project\"; exit 1; } ;;
            *) echo \"unexpected MCP name: \$n\"; exit 1 ;;
          esac
        done
        echo OK
      "
      # Silent-fallback synthetic test (D-11: stderr empty when default_scope is missing).
      TMP=$(mktemp -d /tmp/p36-loader-test.XXXXXX)
      trap "rm -rf '$TMP'" EXIT
      cat > "$TMP/synth.json" <<'JSON'
      {"schema_version":2,"categories":["dev-tools"],"components":{"mcp":{"alpha":{"name":"alpha","display_name":"A","category":"dev-tools","env_var_keys":[],"install_args":["alpha","--","echo"],"description":"a","requires_oauth":false,"default_scope":"project"},"beta":{"name":"beta","display_name":"B","category":"dev-tools","env_var_keys":[],"install_args":["beta","--","echo"],"description":"b","requires_oauth":false}}}}
      JSON
      OUT=$(TK_MCP_CATALOG_PATH="$TMP/synth.json" bash -c '
        set -euo pipefail
        source scripts/lib/mcp.sh
        mcp_catalog_load
        for i in "${!MCP_NAMES[@]}"; do printf "%s=%s\n" "${MCP_NAMES[$i]}" "${MCP_DEFAULT_SCOPE[$i]}"; done
      ' 2>"$TMP/stderr")
      RC=$?
      [ "$RC" = '0' ] || { echo "loader rc=$RC"; exit 1; }
      echo "$OUT" | grep -q '^alpha=project$' || { echo "alpha missing"; exit 1; }
      echo "$OUT" | grep -q '^beta=user$' || { echo "beta fallback wrong"; exit 1; }
      [ ! -s "$TMP/stderr" ] || { echo "stderr not empty: $(cat "$TMP/stderr")"; exit 1; }
      echo "FALLBACK OK"
    </automated>
  </verify>
  <acceptance_criteria>
    - `bash -n scripts/lib/mcp.sh` exits 0 (no syntax error).
    - `shellcheck -S warning scripts/lib/mcp.sh` exits 0 (no warnings or errors at warning severity).
    - `grep -n 'MCP_DEFAULT_SCOPE' scripts/lib/mcp.sh` returns at least 3 matches (declaration, populate, docstring) — and each populate-or-declare match is preceded by `# shellcheck disable=SC2034`.
    - `grep -n 'default_scope // "user"' scripts/lib/mcp.sh` returns exactly 1 match (the populate line).
    - Sourcing the loader against the shipped catalog yields `${#MCP_NAMES[@]}` == `${#MCP_DEFAULT_SCOPE[@]}` == 20, and the 10/10 split matches the SCOPE-02 grid (verified by the case statement above).
    - Sourcing the loader against the synthetic catalog where `beta` lacks `default_scope` yields rc=0, `MCP_DEFAULT_SCOPE` for `beta` equals `user`, `MCP_DEFAULT_SCOPE` for `alpha` equals `project`, and the captured stderr file is byte-zero (D-11 silent contract).
    - `MCP_NAMES` order remains alphabetical (no change to line 160 iteration source).
    - No `// null` or string-equality branch on `"null"` introduced (anti-pattern explicitly forbidden by RESEARCH.md and the file's line-146 comment).
  </acceptance_criteria>
  <done>
    Loader populates `MCP_DEFAULT_SCOPE[]` parallel to other arrays; missing field falls back to `user` silently (no stderr); shellcheck clean; downstream Phase 38 wizard can read the array without further loader changes.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| repo → developer machine | Catalog file ships in the repo; consumed by validator and loader on developer/CI machines. No network, no user input. |
| catalog → validator | Validator reads JSON from a path passed via `sys.argv[1]` or default. No untrusted JSON ingestion at runtime. |
| catalog → loader | Loader reads JSON via jq. The catalog path is configurable via `TK_MCP_CATALOG_PATH` (test-only seam). |

**Note (per planning_context):** No external input surface — catalog is repo-owned, validator runs on repo files, loader sources `mcp.sh` from a trusted location. Phase 36 introduces no auth, no file uploads, no shell execution from user data, no SQL, no crypto.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-36-01 | Tampering | scripts/lib/integrations-catalog.json | accept | Catalog is repo-owned and ships in version control; tampering protection is git-history-based. Validator-fail-loud (Task 2) detects malformed `default_scope` if a malicious commit lands. Severity: low. |
| T-36-02 | Denial of Service | mcp_catalog_load | mitigate | Silent-fallback-to-user (D-09) means a malformed catalog (missing field) does not abort the loader; downstream wizards still function. The validator catches the bad shape at `make check` time. Severity: low. |
| T-36-03 | Information Disclosure | scripts/validate-integrations-catalog.py | accept | Validator stderr surfaces the location and the literal repr of the bad value (e.g., `'global'`). The catalog never contains secrets — only public service metadata (display names, install args, OAuth flags). Disclosing a bad enum value to stderr is acceptable. Severity: none. |
| T-36-04 | Information Disclosure (developer machine) | mcp_catalog_load + jq subshell | accept | The `--arg n "$name"` flag passes the entry name (already a controlled key from `keys | sort`) — no shell-metacharacter injection surface. Severity: none. |

**Aggregate:** No external input surface — catalog is repo-owned, validator runs on repo files, loader sources `mcp.sh` from a trusted location. Threat: malformed catalog corrupts loader behavior — mitigated by validator-fail-loud + silent-fallback-to-user. Severity: low.
</threat_model>

<verification>
- `python3 scripts/validate-integrations-catalog.py` exits 0 against the post-Task-1 shipped catalog (Tasks 1+2 integrated).
- `make validate-catalog` exits 0 (Makefile target line 415-417 wraps the same validator invocation).
- `make check` exits 0 (the full quality gate — includes `validate-catalog` per Makefile line 19).
- `bash -n scripts/lib/mcp.sh` exits 0 (no syntax errors).
- `shellcheck -S warning scripts/lib/mcp.sh` exits 0 (no warnings).
- `grep -c '"default_scope":' scripts/lib/integrations-catalog.json` returns `20`.
- Sourcing `mcp.sh` and calling `mcp_catalog_load` populates `MCP_DEFAULT_SCOPE[]` with 20 entries matching the locked grid.
- Synthetic catalog with one MCP missing `default_scope` causes `mcp_catalog_load` to fall back silently to `user` with byte-zero stderr.
- `manifest.json` and `CHANGELOG.md` are NOT touched in this plan (D-08 — version bump deferred to Phase 41; otherwise the `version-align` Makefile target would fail).

NOTE: existing baselines `bash scripts/tests/test-mcp-selector.sh` (PASS=21) and `bash scripts/tests/test-integrations-catalog.sh` (PASS≥10) are validated in Plan 02 (the test-contract plan). Plan 01 only verifies that no syntax error or schema regression occurred.
</verification>

<success_criteria>
1. All 20 `components.mcp.<name>` blocks in `scripts/lib/integrations-catalog.json` carry `"default_scope": "user"` or `"default_scope": "project"` per the locked SCOPE-02 grid (D-06/D-07).
2. `scripts/validate-integrations-catalog.py` REQUIRED_ENTRY_KEYS contains `"default_scope"`; the validator's per-entry walk includes a Check 11 enum check that rejects any value other than `"user"` or `"project"`; the docstring lists the new check.
3. `scripts/lib/mcp.sh::mcp_catalog_load` declares and populates a new `MCP_DEFAULT_SCOPE[]` array parallel to `MCP_NAMES[]`, with `// "user"` jq fallback for the missing-field case; the populate line is `# shellcheck disable=SC2034` annotated; the function-header docstring lists the new global.
4. `python3 scripts/validate-integrations-catalog.py` exits 0; `make check` exits 0; `bash -n scripts/lib/mcp.sh` and `shellcheck -S warning scripts/lib/mcp.sh` exit 0.
5. Synthetic catalog with one MCP omitting `default_scope` causes `mcp_catalog_load` to populate that entry's `MCP_DEFAULT_SCOPE` slot with `"user"` and emit zero bytes on stderr (D-09/D-11 silent contract).
6. No Calendly entry added (D-08 — Phase 40); no `manifest.json` or `CHANGELOG.md` edits (D-08 — Phase 41); no schema_version bump (additive change).
7. CLI-only entries (`components.cli.*`) untouched (D-03).
8. Single landing — all three sites (catalog, validator, loader) ship in the same commit (D-10 invariant).
</success_criteria>

<output>
After completion, create `.planning/phases/36-catalog-schema-backward-compat/36-01-SUMMARY.md` documenting:
- Diff sites and line counts per file
- Confirmation that all 8 success criteria are met
- Any deviations (none expected) with rationale
- Pointer to Plan 02 for the test contract
</output>
