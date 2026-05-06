---
phase: 40-uninstall-secret-cleanup-calendly-validator
plan: 4
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/integrations-catalog.json
  - scripts/tests/test-integrations-catalog.sh
autonomous: true
requirements:
  - INT-13
  - INT-14
  - TEST-06

must_haves:
  truths:
    - "integrations-catalog.json contains a `calendly` MCP entry, alpha-ordered between `aws-cost-explorer` and `cloudflare`"
    - "Calendly entry shape mirrors notion (OAuth-only): no `unofficial` field, env_var_keys=[], requires_oauth=true, default_scope=user, category=workspace"
    - "Calendly install_args populated per official MCP spec at developer.calendly.com/calendly-mcp-server"
    - "test-integrations-catalog.sh A5 assertion bumped from 20 to 21 entries (was 20 before Calendly add)"
    - "test-integrations-catalog.sh has new A18 positive assertion: calendly entry shape matches expected (Notion-mirrored)"
    - "test-integrations-catalog.sh has new A19 negative assertion: no MCP entry name matches ^google-(workspace|drive|gmail|calendar)$ (INT-14 lock)"
    - "test-integrations-catalog.sh has new SCOPE-01 regression test: validator catches a mutated catalog copy missing default_scope on one entry, exits non-zero with line-pointer message"
    - "validate-integrations-catalog.py is NOT modified — SCOPE-01 implementation already exists at lines 254-272 (Phase 36 work, per PATTERNS.md surprise #3); Phase 40 only adds the regression test"
  artifacts:
    - path: "scripts/lib/integrations-catalog.json"
      provides: "Calendly MCP entry, alpha-ordered, OAuth-only shape mirrored from notion"
      contains: '"calendly"'
    - path: "scripts/tests/test-integrations-catalog.sh"
      provides: "Updated A5 (entry count 21), new A18 (calendly shape), new A19 (no google-*), new A20 (SCOPE-01 negative regression)"
      contains: "calendly entry has expected shape"
  key_links:
    - from: "integrations-catalog.json calendly entry"
      to: "notion entry shape (lines 200-215)"
      via: "Verbatim shape mirror with name/install_args substitutions; NO unofficial field (notion analog has none either)"
      pattern: '"calendly":'
    - from: "test-integrations-catalog.sh A18"
      to: "calendly entry"
      via: "_pyq python3 heredoc asserting requires_oauth=true, default_scope=user, env_var_keys=[], category=workspace, no unofficial field"
      pattern: 'calendly.*shape'
    - from: "test-integrations-catalog.sh A19"
      to: "INT-14 Google Workspace lock"
      via: "regex assertion: no entry name matches ^google-(workspace|drive|gmail|calendar)$"
      pattern: 'google-.*entries'
    - from: "test-integrations-catalog.sh SCOPE-01 regression"
      to: "validate-integrations-catalog.py:254-272"
      via: "Mutated catalog temp file with one entry missing default_scope; assert validator exits non-zero with line-pointer error"
      pattern: 'default_scope is required'
---

<objective>
Add the Calendly entry to `scripts/lib/integrations-catalog.json` (INT-13), document the Google Workspace non-add via test (INT-14), and add the SCOPE-01 regression test in `scripts/tests/test-integrations-catalog.sh` (TEST-06). The validator code itself is already implemented at `scripts/validate-integrations-catalog.py:254-272` (Phase 36 work — verified per PATTERNS.md surprise #3); Phase 40 adds the regression test only, NOT a re-implementation.

Purpose: Calendly is the v5.0 catalog growth — an OAuth-only personal scheduling MCP, perfect alpha-fit between `aws-cost-explorer` and `cloudflare`. Its entry must mirror the existing `notion` entry shape verbatim (the closest OAuth-only analog: no `unofficial` field, `env_var_keys=[]`, `requires_oauth=true`, `default_scope=user`). INT-14 is a negative requirement — the catalog must NEVER contain a `google-workspace` (or `gmail`/`drive`/`calendar`) entry because claude.ai's built-in connectors already cover that surface. The validator regression test plugs the SCOPE-01 contract: if a future hand-edit accidentally drops `default_scope` from any MCP entry, the validator must catch it.

Output: One new entry in `integrations-catalog.json` (Calendly), one updated assertion in `test-integrations-catalog.sh` (A5 count 20→21), three new assertions (A18 calendly shape, A19 no google-*, A20 SCOPE-01 negative regression). PASS floor moves from ≥10 to ≥13.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-CONTEXT.md
@.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-PATTERNS.md
@scripts/lib/integrations-catalog.json
@scripts/validate-integrations-catalog.py
@scripts/tests/test-integrations-catalog.sh

<interfaces>
<!-- Reference shape (read-only — DO NOT modify notion entry) -->

From scripts/lib/integrations-catalog.json (lines 200-215, the Notion entry):
```json
"notion": {
  "name": "notion",
  "display_name": "Notion",
  "category": "workspace",
  "env_var_keys": [],
  "install_args": [
    "notion",
    "--",
    "npx",
    "-y",
    "@notionhq/notion-mcp-server"
  ],
  "description": "Workspace pages + databases (OAuth)",
  "requires_oauth": true,
  "default_scope": "user"
}
```

Note (PATTERNS.md surprise #5): Notion has NO `unofficial` field at all. Only `notebooklm` and `telegram` (community wrappers) carry `unofficial: true`. Official MCPs simply omit the field. Calendly is official → omits the field.

From scripts/validate-integrations-catalog.py (lines 254-272, ALREADY IMPLEMENTED — DO NOT modify):
```python
default_scope = entry.get("default_scope")
if default_scope is None:
    fail(location + ": .default_scope is required (must be 'user' or 'project')")
    errors += 1
elif default_scope not in ("user", "project"):
    fail(location + ": .default_scope must be 'user' or 'project', got " + repr(default_scope))
    errors += 1
```

Validator is invoked with positional path arg per validator line 93 — accepts `python3 scripts/validate-integrations-catalog.py <catalog-path>`.

From scripts/tests/test-integrations-catalog.sh:
- Line 67-86: `_pyq` helper — runs python3 heredoc against the loaded catalog, prints OK or diagnostic
- Line 119: `A5: components.mcp has exactly 20 entries` — Phase 40 bumps to 21
- Line 200-208: `A10: unofficial set == {notebooklm, telegram}` — analog for new A18/A19 set assertions
- PASS counter at end-of-file — bumps from ≥10 to ≥13 (4 changes: 1 modify A5, 3 new tests)

Calendly install_args canonical reference: `https://developer.calendly.com/calendly-mcp-server`
The Calendly MCP is published officially. The implementer fetches the official docs at execute-time (via WebFetch or Context7) to extract the canonical npx invocation. Best-known shape (mirrors Notion's npx pattern):
```json
"install_args": [
  "calendly",
  "--",
  "npx",
  "-y",
  "@calendly/mcp-server"
]
```
The implementer MUST verify the package name `@calendly/mcp-server` and any required `--transport` or oauth-callback args from the official docs before committing.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Insert Calendly entry in integrations-catalog.json (alpha-ordered, Notion-mirrored shape)</name>
  <files>scripts/lib/integrations-catalog.json</files>
  <action>
Open `scripts/lib/integrations-catalog.json`. Locate the alpha-ordered MCP entries. Identify the boundary between `aws-cost-explorer` (lines 36-54 per PATTERNS.md) and `cloudflare` (lines 55-72). Calendly fits alphabetically between them: `aws-cost-explorer` < `calendly` < `cloudflare`.

**Step 1: Verify install_args canonical shape from official docs.**

Before writing the entry, fetch `https://developer.calendly.com/calendly-mcp-server` (or `npm view @calendly/mcp-server`, whichever resolves) to confirm:
- Exact npm package name (likely `@calendly/mcp-server` based on Calendly's npm org `@calendly`)
- Whether the server needs `--transport stdio` or any other CLI flag
- Whether the OAuth callback is configured externally (Calendly dashboard) or via CLI flag

If the official docs reference a different invocation pattern (e.g., `npx -y calendly-mcp` rather than `@calendly/mcp-server`), use the documented form. The Notion analog uses `["notion", "--", "npx", "-y", "@notionhq/notion-mcp-server"]` — Calendly should follow the same `[name, "--", "npx", "-y", <package>]` shape.

**Step 2: Insert the new entry (verbatim shape, mirroring Notion lines 200-215):**

```json
"calendly": {
  "name": "calendly",
  "display_name": "Calendly",
  "category": "workspace",
  "env_var_keys": [],
  "install_args": [
    "calendly",
    "--",
    "npx",
    "-y",
    "<CANONICAL_PACKAGE_FROM_OFFICIAL_DOCS>"
  ],
  "description": "Scheduling — events, availability, links (OAuth)",
  "requires_oauth": true,
  "default_scope": "user"
}
```

**Field-by-field rationale (anchored to existing entries per PATTERNS.md):**

- `name: "calendly"` — required by SCOPE-01 schema; matches all entries.
- `display_name: "Calendly"` — title-cased per convention (`Notion`, `Slack`).
- `category: "workspace"` — Calendly is personal scheduling tooling. CONTEXT D-09 confirms reusing existing `workspace` category (not introducing a new `scheduling` category — YAGNI). Notion uses `workspace`; consistent.
- `env_var_keys: []` — OAuth-only; no API key prompts needed. Matches `notion:204`, `playwright:238`. The Plan 40-01 helper short-circuits cleanly on empty array (D-03).
- `install_args` — `[<name>, "--", "npx", "-y", <package>]` mirrors Notion's shape verbatim. The toolkit's `claude mcp add` wrapper splits on `--` to separate friendly-name from invocation.
- `description` — one-liner, OAuth notation in parens (matches Notion `"Workspace pages + databases (OAuth)"`).
- `requires_oauth: true` — matches Notion, Notebooklm. Triggers OAuth callback flow at install time.
- `default_scope: "user"` — personal scheduling tool, used across projects (per CONTEXT D-09 + REQUIREMENTS.md SCOPE-02).

**Field-by-field omissions (deliberate per PATTERNS.md surprise #5):**
- NO `unofficial` field — Calendly publishes the MCP officially; only `notebooklm`/`telegram` (community wrappers) carry `unofficial: true`. Official MCPs simply omit the field. Notion at lines 200-215 has no `unofficial` key — this is the analog.
- NO `components.cli` block — there is no companion Calendly CLI tool the toolkit knows about. Matches Notion (no CLI block).

**JSON validity contract:**
- Insertion must preserve overall JSON validity. Verify with `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"`.
- Comma placement: the entry preceding Calendly (`aws-cost-explorer`) gets a trailing comma; Calendly itself gets a trailing comma; `cloudflare` block is unchanged.
- Indentation matches existing entries (likely 4 spaces, confirm by reading file).

**Schema-version impact (PATTERNS.md):**
- `schema_version` field stays at `2` (no schema change; just data growth).
- Entry count bumps from 20 to 21 — captured in Task 2 below.

**Security review (CLAUDE.md global):**
- No external service calls during install — `requires_oauth: true` triggers Claude Code's built-in OAuth flow, which Calendly handles via its own OAuth dashboard. Toolkit just sets the install arguments.
- The `<CANONICAL_PACKAGE_FROM_OFFICIAL_DOCS>` placeholder MUST be resolved before commit. Do NOT commit a placeholder string. If unable to resolve via WebFetch/Context7, use the most-likely package name (`@calendly/mcp-server`) and document the assumption in the SUMMARY.
  </action>
  <verify>
    <automated>python3 -c "import json; c=json.load(open('scripts/lib/integrations-catalog.json')); e=c['components']['mcp']['calendly']; assert e['name']=='calendly' and e['display_name']=='Calendly' and e['category']=='workspace' and e['env_var_keys']==[] and e['requires_oauth'] is True and e['default_scope']=='user' and 'unofficial' not in e and len(c['components']['mcp'])==21, 'shape mismatch'"</automated>
  </verify>
  <done>
    - `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"` succeeds (JSON valid)
    - `jq '.components.mcp.calendly' scripts/lib/integrations-catalog.json` returns the entry
    - `jq '.components.mcp | keys | length' scripts/lib/integrations-catalog.json` returns 21
    - `jq '.components.mcp | keys' scripts/lib/integrations-catalog.json` shows `calendly` between `aws-cost-explorer` and `cloudflare` alphabetically (NOTE: jq sorts keys lexicographically by default — visual ordering in the file matters here; verify by `grep -n '"calendly"\|"aws-cost-explorer"\|"cloudflare"' scripts/lib/integrations-catalog.json` shows aws < calendly < cloudflare line numbers)
    - `python3 scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json` exits 0 (validator accepts the new entry per its existing SCOPE-01 check)
    - `make shellcheck` not affected (no shell change); `make check` (or local equivalent) green
  </done>
</task>

<task type="auto">
  <name>Task 2: Bump A5 entry count + add A18 (calendly shape) + A19 (no google-*) + A20 (SCOPE-01 negative regression) in test-integrations-catalog.sh</name>
  <files>scripts/tests/test-integrations-catalog.sh</files>
  <action>
Three additions and one modification to `scripts/tests/test-integrations-catalog.sh`:

**Edit A — bump A5 entry count from 20 to 21 (PATTERNS.md surprise #4):**

Locate line 119: `A5: components.mcp has exactly 20 entries`. Change the literal `20` to `21`. The assertion's underlying check (likely `len(mcp) == 20`) must be updated in lockstep.

Verify post-edit: `grep -nE '== ?20|"20 ?entries"|exactly 20' scripts/tests/test-integrations-catalog.sh` returns no matches; `grep -nE '== ?21|exactly 21' scripts/tests/test-integrations-catalog.sh` returns the updated line.

**Edit B — add A18 positive Calendly shape assertion (mirrors A10 unofficial-set pattern):**

Insert after the existing A17 (or at the end of the assertion block, before PASS counter logic), using the `_pyq` helper:

```bash
_pyq "A18: calendly entry has expected shape" '
mcp = catalog.get("components", {}).get("mcp", {})
e = mcp.get("calendly", {})
if (e.get("name") == "calendly"
    and e.get("display_name") == "Calendly"
    and e.get("category") == "workspace"
    and e.get("requires_oauth") is True
    and e.get("default_scope") == "user"
    and e.get("env_var_keys") == []
    and "unofficial" not in e):
    print("OK")
else:
    print("calendly shape mismatch: " + repr(e))
'
```

This asserts CONTEXT D-09 contract: name/display_name/category/oauth/scope/empty-keys/no-unofficial. The `"unofficial" not in e` check enforces PATTERNS.md surprise #5 (official MCPs omit the field rather than setting it to false).

**Edit C — add A19 negative Google Workspace assertion (INT-14 lock per CONTEXT D-10):**

Append after A18:

```bash
_pyq "A19: no google-* MCP entries (INT-14 lock)" '
import re
mcp = catalog.get("components", {}).get("mcp", {})
pat = re.compile(r"^google-(workspace|drive|gmail|calendar)$")
hits = [n for n in mcp if pat.match(n)]
if not hits:
    print("OK")
else:
    print("forbidden google-* entries present: " + repr(hits))
'
```

This locks INT-14: the catalog must never contain `google-workspace`, `google-drive`, `google-gmail`, or `google-calendar` MCP entries. claude.ai's built-in connectors are the documented surface (CONTEXT D-10 cross-reference to PROJECT.md + Phase 41 CHANGELOG).

**Edit D — add A20 SCOPE-01 negative regression test (per CONTEXT D-11 + D-14, PATTERNS.md "SCOPE-01 negative analog"):**

This requires creating a mutated copy of the catalog (one entry missing `default_scope`), running the validator against it, and asserting non-zero exit + expected error message. Insert as a new test block (NOT inside `_pyq` because it shells out to the validator):

```bash
echo ""
echo "── A20: validator catches missing default_scope (SCOPE-01 regression) ──"
_a20_tmp="$(mktemp -t catalog-mut.XXXXXX)"
trap 'rm -f "$_a20_tmp"' RETURN
# Strip default_scope from one entry (e.g., the first MCP) — produces an invalid catalog
python3 - <<PYEOF > "$_a20_tmp"
import json, sys
c = json.load(open("$CATALOG"))
mcp = c["components"]["mcp"]
first_name = sorted(mcp.keys())[0]
del c["components"]["mcp"][first_name]["default_scope"]
print(json.dumps(c, indent=2))
PYEOF

if python3 "$REPO_ROOT/scripts/validate-integrations-catalog.py" "$_a20_tmp" 2>&1 | grep -q 'default_scope is required'; then
    PASS=$((PASS + 1))
    echo "  ✓ A20 PASS"
else
    FAIL=$((FAIL + 1))
    echo "  ✗ A20 FAIL: validator did not catch missing default_scope"
fi
rm -f "$_a20_tmp"
trap - RETURN
```

**IMPORTANT:** Read the existing `_pyq` helper and the surrounding test-runner shape (PASS counter, REPO_ROOT, CATALOG variable) before writing this block. Adapt variable names to match exactly. The block above uses `$CATALOG` (existing variable in the test) and `$REPO_ROOT` (existing variable). If the test file uses different names, substitute accordingly.

The mutation strategy: pick the first MCP entry alphabetically, delete its `default_scope` key, write the result to a temp file. The validator then must fail on that entry. Using `sorted(mcp.keys())[0]` ensures the test is deterministic across runs (no dependency on dict ordering).

**Edit E — bump PASS floor:**

If the test file has a final assertion like `if [[ $PASS -ge 10 ]]; then echo "✓ catalog tests OK"; else echo "✗ catalog tests below floor"; fi`, bump `10` to `13` (4 changes: A5 modified is +0 net; A18, A19, A20 are +3 net; original was 17 assertions → 20 assertions; floor was 10 → bump to 13 per CONTEXT D-14).

If the floor is expressed as `(( PASS >= NN ))` or similar, update consistently. Verify by `grep -nE 'PASS.*>=|PASS.*-ge' scripts/tests/test-integrations-catalog.sh`.

**Bash 3.2 / macOS BSD invariants (CONTEXT D-16):**
- `mktemp -t catalog-mut.XXXXXX` — BSD-friendly form (template at end). Verify with macOS `mktemp` semantics: BSD mktemp accepts `-t prefix` for prefix mode.
- `trap '... rm -f ...' RETURN` is bash-3.2-safe but `RETURN` trap inside a script (not a function) is not standard; safer to use explicit `rm -f "$_a20_tmp"` after the assertion + drop the `trap RETURN` and rely on the `set -euo pipefail` at script top. Alternative: use a single `EXIT` trap for the whole test file (already standard) and add the temp file path to a cleanup list.

**Cleaner cleanup pattern:**

```bash
echo ""
echo "── A20: validator catches missing default_scope (SCOPE-01 regression) ──"
_a20_tmp="$(mktemp -t catalog-mut.XXXXXX)"
python3 - <<PYEOF > "$_a20_tmp"
import json
c = json.load(open("$CATALOG"))
mcp = c["components"]["mcp"]
first_name = sorted(mcp.keys())[0]
del c["components"]["mcp"][first_name]["default_scope"]
print(json.dumps(c, indent=2))
PYEOF
if python3 "$REPO_ROOT/scripts/validate-integrations-catalog.py" "$_a20_tmp" 2>&1 | grep -q 'default_scope is required'; then
    PASS=$((PASS + 1))
    echo "  ✓ A20 PASS"
else
    FAIL=$((FAIL + 1))
    echo "  ✗ A20 FAIL: validator did not catch missing default_scope"
fi
rm -f "$_a20_tmp"
```

(Drop the RETURN trap; rely on the script-level EXIT trap if present, or just rm -f explicitly.)

**Security review (CLAUDE.md):**
- `mktemp -t catalog-mut.XXXXXX` creates a temp file in `/tmp` with a random suffix — no path traversal, no symlink race (mktemp is atomic).
- `python3 - <<PYEOF > "$_a20_tmp"` writes JSON to the temp file via heredoc. The `$CATALOG` env var is interpolated INTO the heredoc string — but `$CATALOG` is set by the test (`scripts/lib/integrations-catalog.json` path), not user input. No injection risk.
- `python3 "$REPO_ROOT/scripts/validate-integrations-catalog.py" "$_a20_tmp"` — quoted arg, no shell expansion.
- `grep -q 'default_scope is required'` — fixed-string search on validator stderr.
  </action>
  <verify>
    <automated>bash -n scripts/tests/test-integrations-catalog.sh && shellcheck -S warning scripts/tests/test-integrations-catalog.sh && bash scripts/tests/test-integrations-catalog.sh 2>&1 | grep -q 'A18.*PASS\|✓ A18' && bash scripts/tests/test-integrations-catalog.sh 2>&1 | grep -q 'A19.*PASS\|✓ A19' && bash scripts/tests/test-integrations-catalog.sh 2>&1 | grep -q 'A20.*PASS\|✓ A20' && bash scripts/tests/test-integrations-catalog.sh 2>&1 | grep -qE 'exactly 21|== ?21'</automated>
  </verify>
  <done>
    - `bash -n scripts/tests/test-integrations-catalog.sh` clean
    - `shellcheck -S warning scripts/tests/test-integrations-catalog.sh` clean
    - `bash scripts/tests/test-integrations-catalog.sh` exits 0 with PASS ≥ 13
    - A5 assertion mentions 21 entries (no leftover `20`)
    - A18 (calendly shape) passes
    - A19 (no google-*) passes
    - A20 (SCOPE-01 negative) passes — validator was caught failing on a mutated copy
    - PASS floor in the test script bumped to 13
    - `make check` (project root) green
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| catalog file (committed JSON) → jq / python3 readers | Toolkit-controlled data; new Calendly entry is a static JSON literal — no untrusted input |
| mutated catalog temp file (A20 test) → validator subprocess | Test-internal; the mutation is deterministic and the file lives in `/tmp` with mktemp's random suffix |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-04-01 | Tampering | Calendly install_args package name | mitigate | Implementer fetches official Calendly MCP docs at execute-time; no placeholder committed |
| T-40-04-02 | Information Disclosure | Calendly entry adds `requires_oauth: true` flag | accept | Field is metadata only; OAuth flow itself is handled by Calendly's dashboard, not by the toolkit |
| T-40-04-03 | Denial of Service | A20 test creates /tmp file | mitigate | mktemp + rm -f at end; even if rm fails, /tmp cleanup eventually evicts |
| T-40-04-04 | Spoofing | Adversarial @calendly/mcp-server impersonator on npm | mitigate | Implementer verifies package name against official Calendly developer docs; CLAUDE.md §7 typosquatting check applies |
| T-40-04-05 | Elevation of Privilege | Validator subprocess runs python3 | accept | Validator is committed code; no user input flows to it |
| T-40-04-06 | Repudiation | Test failures logged to stdout | mitigate | Existing test runner captures stdout; PASS/FAIL counters provide audit trail |
</threat_model>

<verification>
- `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"` succeeds
- `jq '.components.mcp.calendly' scripts/lib/integrations-catalog.json` returns the new entry
- `jq '.components.mcp | keys | length' scripts/lib/integrations-catalog.json` returns 21
- File-order alpha check: `grep -n '"calendly"\|"aws-cost-explorer"\|"cloudflare"' scripts/lib/integrations-catalog.json` shows aws < calendly < cloudflare in line numbers
- Calendly entry has NO `unofficial` field: `jq '.components.mcp.calendly | has("unofficial")' scripts/lib/integrations-catalog.json` returns `false`
- `python3 scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json` exits 0
- `bash scripts/tests/test-integrations-catalog.sh` exits 0 with PASS ≥ 13
- A18, A19, A20 all PASS
- A5 references 21 entries (not 20)
- `make check` green
</verification>

<success_criteria>
- Calendly entry present in `integrations-catalog.json`, alpha-ordered between `aws-cost-explorer` and `cloudflare`
- Entry shape: `name`, `display_name`, `category=workspace`, `env_var_keys=[]`, `install_args` (canonical from official docs), `description`, `requires_oauth=true`, `default_scope=user`
- Entry has NO `unofficial` field (mirrors Notion)
- A5 entry-count assertion bumped from 20 to 21
- A18 positive Calendly shape assertion exists and passes
- A19 negative Google Workspace assertion exists and passes (INT-14 lock)
- A20 SCOPE-01 negative regression test exists and passes
- PASS floor in test-integrations-catalog.sh bumped from ≥10 to ≥13
- `validate-integrations-catalog.py` is NOT modified (already implements SCOPE-01 per PATTERNS.md surprise #3)
- `python3 scripts/validate-integrations-catalog.py scripts/lib/integrations-catalog.json` exits 0
- `bash scripts/tests/test-integrations-catalog.sh` passes
- `make check` green
</success_criteria>

<output>
After completion, create `.planning/phases/40-uninstall-secret-cleanup-calendly-validator/40-04-SUMMARY.md` summarizing:
- Final canonical Calendly install_args (the resolved package name from official docs)
- Total MCP entry count after add (21)
- New PASS floor for test-integrations-catalog.sh (13)
- Confirmation: validate-integrations-catalog.py byte-identical (no modification)
- Confirmation: A20 SCOPE-01 negative test catches mutated copy and validator exits non-zero with `default_scope is required` message
- Note that INT-14 documentation cross-reference (PROJECT.md + CHANGELOG) is deferred to Phase 41 DIST-03 per CONTEXT D-10
</output>
