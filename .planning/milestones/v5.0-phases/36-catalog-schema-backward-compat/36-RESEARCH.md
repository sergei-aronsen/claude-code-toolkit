# Phase 36: Catalog Schema + Backward Compat — Research

**Researched:** 2026-05-04
**Domain:** JSON schema migration (additive field) + Python validator extension + Bash/jq loader fallback in a documentation/templates repo (Bash 3.2 + POSIX shell only).
**Confidence:** HIGH (every claim is verified directly against repo files at known line ranges; no library docs needed because the entire scope is in-repo code)

## Summary

Phase 36 is a small, self-contained foundation phase in a v4.9 catalog system that already has all the wiring it needs. The catalog is a single JSON file (`scripts/lib/integrations-catalog.json`, schema_version 2, 20 MCP entries), the validator is a single zero-dep Python file (`scripts/validate-integrations-catalog.py`, 267 lines, walks `components.mcp.*`), the loader is a single Bash function (`mcp_catalog_load` in `scripts/lib/mcp.sh`, lines 78–161, jq-driven), and the test harness pattern is already in place (`scripts/tests/test-integrations-catalog.sh`, 14 inline-Python assertions; `scripts/tests/test-mcp-selector.sh`, 21 assertions across 8 scenarios using `TK_MCP_CATALOG_PATH` test seam).

Three deltas land in one commit:

1. **Catalog (data):** Insert `"default_scope": "user"|"project"` after `requires_oauth` on every one of the 20 `components.mcp.<name>` blocks (per the SCOPE-02 grid baked into CONTEXT.md D-06/D-07).
2. **Validator (enforcement):** Append a `default_scope` key to `REQUIRED_ENTRY_KEYS` (line 60–68) and add an enum check (`{"user","project"}`) inside the existing per-entry walk (lines 147–244).
3. **Loader (backward compat):** Inside the existing `while IFS= read -r name; do … done` block (lines 110–160), add one more `MCP_*` parallel array populated via `jq -r '.components.mcp[$n].default_scope // "user"'` — silent fallback, no stderr, matches the prevailing `// "default"` form already used on lines 133 (`.category // ""`) and 136 (`.unofficial // false`).

`make check` already invokes the validator unconditionally via the `validate-catalog` target (Makefile line 19 chain → line 415–417). Test baselines (`test-mcp-selector.sh` PASS=21, `test-integrations-catalog.sh` PASS≥10) stay green because the new field is additive and the loader fallback handles entries missing it.

**Primary recommendation:** Single-commit landing of catalog edits + validator extension + loader fallback + new TEST-06 assertion (in `test-integrations-catalog.sh`) + a hermetic backward-compat test (extension preferred over new sibling — keeps assertions discoverable per D-14 discretion). Match existing patterns verbatim. No new libraries, no schema_version bump, no new make target.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Schema (SCOPE-01)
- **D-01:** Add `default_scope` field to every `components.mcp.<name>` block in `integrations-catalog.json`.
- **D-02:** Enum: `"user"` or `"project"` only. No third value, no nullable, no default at validator level.
- **D-03:** CLI-only entries (no MCP block) untouched — no scope concept for `command -v` checks.
- **D-04:** Validator (`scripts/validate-integrations-catalog.py`) fails loudly when an MCP entry lacks `default_scope` or carries an invalid enum value.
- **D-05:** `make check` invokes the validator and fails the build on schema violations (existing wiring — no new make target needed).

#### Default-scope assignments (SCOPE-02)
- **D-06:** Personal-tooling MCPs default `user`: `firecrawl`, `notebooklm`, `notion`, `youtrack`, `context7`, `openrouter`, `figma`, `playwright`, `magic`, `sentry`.
- **D-07:** Per-app infra MCPs default `project`: `supabase`, `cloudflare`, `stripe`, `slack`, `resend`, `aws-cost-explorer`, `aws-cloudwatch-logs`, `jira`, `linear`, `telegram`.
- **D-08:** Calendly is NOT added in this phase (lands in Phase 40 alongside uninstall work). Phase 36 only seeds defaults for catalog entries that already exist.

#### Backward-compat fallback (SCOPE-03)
- **D-09:** `mcp_catalog_load` in `scripts/lib/mcp.sh` treats a missing `default_scope` as `"user"` and emits NO warning on stderr.
- **D-10:** Fallback ships in the SAME plan/commit as the schema field — no intermediate window where the loader is stricter than the catalog.
- **D-11:** Fallback is silent intentionally — pre-v5.0 user installs that re-source an old catalog must not surface noise.

#### Test contract
- **D-12:** Existing v4.9 baselines must stay green: `test-mcp-selector.sh` PASS=21, `test-integrations-catalog.sh` PASS≥10.
- **D-13:** Validator gets a new SCOPE-01 assertion (TEST-06) — extends the existing `validate-integrations-catalog.py`, no new file. Negative test: synthetic catalog missing `default_scope` → validator fails.
- **D-14:** Backward-compat assertion: synthetic catalog where one MCP omits `default_scope` → `mcp_catalog_load` succeeds, treats entry as `user`, no stderr emission. Implemented as a hermetic test (new or extension of existing — planning decides).

### Claude's Discretion
- Validator implementation detail (jsonschema-lite vs hand-rolled jq vs Python dict walk) — pick the simplest that fits existing validator style.
- Fallback implementation in `mcp_catalog_load` (jq `// "user"` vs explicit branch) — match existing patterns in the file.
- Whether the backward-compat hermetic test extends `test-integrations-catalog.sh` or lands as `test-catalog-scope-fallback.sh` — pick whichever keeps assertions discoverable.
- Internal helper naming for the validator's enum check.

### Deferred Ideas (OUT OF SCOPE)
- Calendly catalog entry — Phase 40 (INT-13).
- TUI per-row scope state (`MCP_SELECTED_SCOPE[]`) — Phase 39.
- Wizard scope routing on `TK_MCP_SCOPE=project` — Phase 38.
- Project `.env` writer (`project-secrets.sh`) — Phase 37.
- Documentation updates (INTEGRATIONS.md, INSTALL.md, UNINSTALL.md) — Phase 41.
- CHANGELOG `[5.0.0]` consolidated entry — Phase 41.
- Manifest version bump to `5.0.0` — Phase 41.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCOPE-01 | New `default_scope: "user"\|"project"` field on every MCP entry; validator enforces presence + enum on every MCP. CLI-only entries unaffected. | Insertion site for catalog: `components.mcp.<name>` block — exact JSON shape captured in §"JSON Shape: Existing MCP Entry". Validator extension site: `REQUIRED_ENTRY_KEYS` tuple at lines 60–68 + the per-entry walk at lines 147–244 of `scripts/validate-integrations-catalog.py`. CLI-only entries (`components.cli.*`, lines 361–426 of catalog) are not walked by the MCP enforcement loop and stay untouched. |
| SCOPE-02 | Default-scope assignments baked into the catalog per the personal-vs-infra grid. | Grid copied verbatim from CONTEXT.md D-06/D-07: 10 default `user`, 10 default `project`. All 20 names verified present in current catalog (see §"Catalog Inventory"). Calendly not present (D-08 honored). |
| SCOPE-03 | `mcp_catalog_load` silent fallback to `user` on missing `default_scope`; pre-v5.0 catalogs continue to work. | Loader function at `scripts/lib/mcp.sh:78–161`. Existing fallback patterns: `// ""` (line 133, `.category`), `// false` (line 136, `.unofficial`), `// empty` (line 148, `.cli[$n].detect_cmd`; line 184, `.categories[]?`). Recommended implementation matches line 133 form: `jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path"`. No stderr emission — matches D-11 silent-fallback contract. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Catalog data shape (`default_scope` presence + values) | Data file (`integrations-catalog.json`) | — | Source of truth lives in the JSON; everything else reads from it. |
| Schema enforcement (`default_scope` required + enum) | Validator (`validate-integrations-catalog.py`) | CI gate (`Makefile :: validate-catalog` invoked by `make check`) | Validator is the contract enforcer; Make wires it into the quality gate. |
| Backward-compat fallback (missing field → "user") | Loader (`mcp.sh::mcp_catalog_load`) | — | Consumers of the loader (TUI, wizard) get a populated `MCP_DEFAULT_SCOPE[]` regardless of catalog age. |
| Test contract (positive + negative + fallback) | Hermetic test (`test-integrations-catalog.sh` + extension) | — | Synthetic-JSON-in-tmp pattern; no shell-out to claude/brew/network. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `jq` | 1.6+ (1.7.x in dev) [VERIFIED: `jq --version` → `jq-1.7.1-apple`] | Catalog reads in `mcp.sh` | Already a hard dep of the toolkit per `STACK.md` Key Dependencies; brew-installed on macOS, apt on Linux. |
| Python 3.8+ stdlib (`json`, `re`, `sys`, `os`) | 3.8+ [VERIFIED: validator header line 44–45, `python3 --version` → 3.14.4] | Validator implementation | Validator already imports exactly these modules (lines 48–51); zero pip dependency is a CLAUDE.md non-negotiable. |
| Bash 3.2+ | 3.2+ [CITED: STACK.md line 9, CLAUDE.md "POSIX-compatible Bash 3.2+"] | Loader + tests | Toolkit invariant — tests run on macOS BSD which ships Bash 3.2. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `markdownlint-cli` | per `.markdownlint.json` | Lint RESEARCH.md & PLAN.md | Already in `make mdlint` chain. |
| `shellcheck` | warning severity | Static analysis on any new test helper | Already in `make shellcheck` chain. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled enum check in Python validator | `jsonschema` library | REJECTED — adds pip dependency; STACK.md line 26–27 forbids "no Node/Python runtime dependency for installers"; existing validator pattern (line 43 docstring "Python stdlib only") makes the rejection explicit. |
| `jq // "user"` fallback in loader | Explicit `if/else` branch on `null` string output | REJECTED — the file's `// null` warning at line 146 ("brittle 'null' string from `// null`") explicitly endorses `// "default"` over branching on string output. The line 133 (`.category // ""`) and line 136 (`.unofficial // false`) sites are direct precedent. |
| New sibling test file `test-catalog-scope-fallback.sh` | Extending `test-integrations-catalog.sh` | RECOMMEND extension — D-14 leaves it to discretion; the existing file already has 14 inline-`_pyq` assertions and a `_pyq` helper that reads the SHIPPED catalog. The fallback test needs a **synthetic** catalog written to a tmp dir + `TK_MCP_CATALOG_PATH` override + Bash sourcing of `mcp.sh`, which is a different harness pattern than `_pyq`. → Lean toward sibling file `test-catalog-scope-fallback.sh` for this single concern, OR add a new section to `test-integrations-catalog.sh` that wraps the synthetic-catalog setup in a function. Planning decides; both are ≤30 lines of code.

**Installation:** No new packages. All deps already pinned in repo.

**Version verification:** Tools verified on this machine via `jq --version` (1.7.1-apple), `python3 --version` (3.14.4), `bash --version` (5.3.9 — note: dev machine has 5.x but **all code MUST stay Bash 3.2 compatible** per STACK.md and `lessons-learned.md` audit findings; CI runs on `ubuntu-latest` per STACK.md). [VERIFIED: 2026-05-04]

## Architecture Patterns

### System Architecture Diagram

```text
                                       Phase 36 data flow
                                       ─────────────────────

   integrations-catalog.json ── (Python json.load) ──> validate-integrations-catalog.py
   (20 MCP entries +                                     │
    new default_scope                                    │ enforces:
    field per entry)                                     │   - REQUIRED_ENTRY_KEYS includes default_scope
        │                                                │   - default_scope ∈ {"user","project"}
        │                                                ▼
        │                                         exit 0 / exit 1
        │                                                │
        │                                                ▼
        │                                       Makefile :: validate-catalog
        │                                                │
        │                                                ▼
        │                                          make check
        │
        │
        ▼
   jq read pipeline (mcp.sh:110–160)
        │
        ▼
   mcp_catalog_load — populates parallel arrays
        │   MCP_NAMES[]
        │   MCP_DISPLAY[]
        │   MCP_ENV_KEYS[]
        │   MCP_INSTALL_ARGS[]
        │   MCP_DESCS[]
        │   MCP_OAUTH[]
        │   MCP_CATEGORY[]
        │   MCP_HAS_CLI[]
        │   MCP_UNOFFICIAL[]
        │   MCP_CLI_DETECT[]
        │   MCP_DEFAULT_SCOPE[]   ← NEW (this phase)
        │
        │   missing field → silent fallback to "user"
        │   via jq '.default_scope // "user"'
        │
        ▼
   Downstream consumers (Phase 38 wizard, Phase 39 TUI):
        - read MCP_DEFAULT_SCOPE[$i] to seed initial scope
        - never see a missing field thanks to loader fallback
```

### Recommended Project Structure

No structural changes. All three edits are in-place modifications to existing files:

```text
scripts/
├── lib/
│   ├── integrations-catalog.json     # EDIT: add default_scope to 20 mcp.<name> blocks
│   └── mcp.sh                        # EDIT: extend mcp_catalog_load (lines 78–161)
├── validate-integrations-catalog.py  # EDIT: add SCOPE-01 enforcement
└── tests/
    ├── test-integrations-catalog.sh  # EDIT: add TEST-06 assertion (positive + negative)
    └── test-catalog-scope-fallback.sh  # NEW (optional — D-14 discretion): hermetic loader fallback test
```

### Pattern 1: Additive JSON field with jq `// default` fallback

**What:** Add a new optional-from-the-loader's-perspective field to the JSON, but keep the validator strict (required + enum). The loader's `// default` keeps pre-v5.0 catalogs working; the validator's strict check guarantees forward correctness on the shipped catalog.

**When to use:** Foundation phases where downstream code starts consuming a new field. Schema must land with both ends (writer + reader fallback) in the same commit.

**Example (loader side, matches existing line 133 pattern):**

```bash
# Source: scripts/lib/mcp.sh:133 (existing precedent — .category // "")
MCP_CATEGORY+=("$(jq -r --arg n "$name" '.components.mcp[$n].category // ""' "$catalog_path")")

# NEW (this phase) — same form, default "user" per D-09:
MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")
```

**Example (validator side, matches existing pattern at lines 60–68 + 162–168):**

```python
# Source: scripts/validate-integrations-catalog.py:60–68 (existing tuple)
REQUIRED_ENTRY_KEYS = (
    "name",
    "display_name",
    "category",
    "env_var_keys",
    "install_args",
    "description",
    "requires_oauth",
    "default_scope",   # NEW (this phase)
)

# Plus a new per-entry enum check inside the existing loop, mirroring the
# style of the requires_oauth bool check at lines 237–244:
default_scope = entry.get("default_scope")
if default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1
```

### Anti-Patterns to Avoid

- **Schema_version bump:** REJECTED. The change is purely additive; the existing `EXPECTED_SCHEMA_VERSION = 2` (validator line 57) and the `_pyq "A3: schema_version == 2"` test (test-integrations-catalog.sh:91–97) stay valid. Bumping would force migration logic in every downstream reader for zero gain.
- **Loud stderr warning on missing field:** EXPLICITLY FORBIDDEN by D-11. Pre-v5.0 user installs re-sourcing an old catalog must not surface noise.
- **`// null` followed by string-equality branch:** ALREADY DOCUMENTED as anti-pattern in `mcp.sh:146` ("brittle 'null' string from `// null`"). Use `// "default"` form.
- **Touching CLI-only entries:** D-03 forbids. The validator's MCP-block walk (lines 147–244) only iterates `components.mcp.*`; CLI entries (`components.cli.*`, lines 361–426 of catalog) are read separately by tests, not by the validator's per-entry loop. No code change needed to honor D-03 — it's automatic.
- **Adding a `default_scope` field to Calendly:** Calendly is not in the catalog (verified — `grep calendly` returns nothing in `integrations-catalog.json`). D-08 confirms it lands in Phase 40.
- **Two-commit split (schema lands first, fallback later):** EXPLICITLY FORBIDDEN by D-10.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON schema enforcement | `jsonschema` library install | Hand-rolled Python dict walk in existing `validate-integrations-catalog.py` | Stdlib-only is a CLAUDE.md non-negotiable; existing validator pattern works for 9 checks already, adding a 10th is trivial. |
| jq fallback for missing field | Explicit Bash branch on `[[ "$x" == "null" ]]` | `jq … // "user"` | Existing pattern (3 sites in mcp.sh); branch-on-null is documented anti-pattern at line 146. |
| Test for missing field | New full test framework | Extension of `test-integrations-catalog.sh` `_pyq` helper for validator side, plus a synthetic-catalog harness in tests dir for loader side | The harness pattern is already in place (see §"Test Harness Pattern"); reuse beats invent. |
| Bash 3.2 lowercase enum normalization | `${var,,}` (Bash 4+) | Plain literals `"user"` and `"project"` (no normalization needed) | Enum is already lowercase; no transformation required. The `_mcp_category_display` function at mcp.sh:191–213 shows the project's pattern for Bash 3.2 case-folding when needed. |
| Detecting OS (BSD vs GNU `stat`) | Cross-platform stat handling for new files | N/A — Phase 36 writes no new files at runtime | Pure JSON edit + Python validator + jq read. No `stat`, no `sed -i`, no `find -mtime`, no `mktemp` outside test sandboxes (which already have the pattern). |

**Key insight:** Phase 36 is **schema additive**. The hardest engineering decision is the discretion choice between extending an existing test file vs. landing a new sibling — everything else has a single obvious match-the-existing-pattern answer.

## JSON Shape: Existing MCP Entry (verbatim)

Field-insertion point for `default_scope`. **Insert immediately after `requires_oauth`** to match the docstring order at validator line 60–68.

### Representative block 1: simple MCP, no `unofficial` flag (lines 17–34)

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
}
```

After Phase 36 edit (default `project` per D-07):

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
  "requires_oauth": false,
  "default_scope": "project"
}
```

### Representative block 2: MCP with `unofficial: true` (lines 174–189)

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
}
```

After Phase 36 edit (default `user` per D-06):

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
  "unofficial": true,
  "default_scope": "user"
}
```

**Key shape facts (verified by reading the catalog):**

- Indent: 2 spaces.
- Quote style: `"` only (jq-canonical).
- Trailing newline at file EOF (line 429 = blank — `wc -l` reports 428 content lines + final newline).
- No comments — `integrations-catalog.json` is jq-canonical JSON.
- 20 MCP entries (verified by `_pyq` assertion A5 in `test-integrations-catalog.sh:119–125` ("components.mcp count is " + str(len(mcp))).
- Field order in the existing entries: `name`, `display_name`, `category`, `env_var_keys`, `install_args`, `description`, `requires_oauth`, then optionally `unofficial`. **Recommendation:** insert `default_scope` AFTER `requires_oauth` and AFTER `unofficial` when present (i.e., last in each block). This keeps unofficial-block diffs minimal.

### Catalog Inventory (verified — every name in CONTEXT.md grid is present)

| MCP name | Catalog line | CONTEXT.md grid | Default scope to assign |
|----------|-------------:|-----------------|-------------------------|
| `aws-cloudwatch-logs` | 17 | D-07 (infra) | `project` |
| `aws-cost-explorer` | 35 | D-07 (infra) | `project` |
| `cloudflare` | 53 | D-07 (infra) | `project` |
| `context7` | 70 | D-06 (personal) | `user` |
| `figma` | 87 | D-06 (personal) | `user` |
| `firecrawl` | 104 | D-06 (personal) | `user` |
| `jira` | 121 | D-07 (infra) | `project` |
| `linear` | 140 | D-07 (infra) | `project` |
| `magic` | 157 | D-06 (personal) | `user` |
| `notebooklm` | 174 | D-06 (personal) | `user` |
| `notion` | 190 | D-06 (personal) | `user` |
| `openrouter` | 205 | D-06 (personal) | `user` |
| `playwright` | 222 | D-06 (personal) | `user` |
| `resend` | 237 | D-07 (infra) | `project` |
| `sentry` | 254 | D-06 (personal) | `user` |
| `slack` | 271 | D-07 (infra) | `project` |
| `stripe` | 289 | D-07 (infra) | `project` |
| `supabase` | 306 | D-07 (infra) | `project` |
| `telegram` | 323 | D-07 (infra) | `project` |
| `youtrack` | 342 | D-06 (personal) | `user` |

Total: 10 default `user` + 10 default `project` = 20 — matches D-06 + D-07 grid exactly. No omissions, no extras. `calendly` is correctly absent (D-08).

## Validator Walk: Insertion Point (verbatim excerpt)

**File:** `scripts/validate-integrations-catalog.py`
**Walk location:** lines 145–244 (per-entry validation block)
**Critical insertion sites:**

### Site 1: `REQUIRED_ENTRY_KEYS` tuple (lines 60–68)

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

→ **Action:** Append `"default_scope",` to this tuple. Existing per-entry walk at lines 162–167 (`missing = [k for k in REQUIRED_ENTRY_KEYS if k not in entry]`) automatically picks up the new requirement.

### Site 2: per-entry enum check (insert near the bool check on line 237–244)

The existing bool-shape pattern shown verbatim:

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

→ **Action:** Add a parallel block after this one:

```python
# Check 11: default_scope must be "user" or "project" (SCOPE-01)
default_scope = entry.get("default_scope")
if default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1
```

The check number "11" matches the existing comment-numbered cadence (the docstring lists checks 1–10 at lines 26–38).

### Site 3: docstring update (lines 7–24)

The schema docstring at lines 7–24 includes a key list — append `default_scope` between `requires_oauth` and the closing brace, and bump check 11 in the "Checks performed" list at lines 26–38.

## Loader Walk: Insertion Point (verbatim excerpt)

**File:** `scripts/lib/mcp.sh`
**Function:** `mcp_catalog_load`
**Range:** lines 78–161
**Insertion site:** inside the `while IFS= read -r name; do … done` block (lines 110–160), after the existing `MCP_CLI_DETECT` populate at line 158.

### Existing prevailing pattern (lines 130–142) — verbatim

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

### Recommended insertion (matches `.category` form on line 133)

```bash
# Phase 36 (SCOPE-03): default_scope with silent fallback to "user" for pre-v5.0
# catalogs that lack the field. Matches the .category // "" form on line 133.
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")
```

### Companion array declaration (insert near lines 100–108 with the other Phase 34-01 declarations)

```bash
# Phase 36 (SCOPE-01/03): per-entry default scope ("user"|"project").
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE=()
```

### Companion docstring update (lines 13–27)

The function-header docstring lists every parallel array. Add to the "Phase 34-01" Globals block at lines 20–27 (or open a new "Phase 36 (SCOPE-01/03)" block):

```text
# Globals (write, Phase 36 (SCOPE-01/03)):
#   MCP_DEFAULT_SCOPE[]    — "user"|"project" (parallel; missing field → "user" fallback)
```

**Verified:** No other site in `mcp.sh` reads `default_scope` today (`grep -n default_scope scripts/lib/mcp.sh` returns nothing as of 2026-05-04). Phase 38 will add the first consumer.

## Makefile Wiring: D-05 Verified

**Question:** Does `make check` invoke the validator today?

**Answer:** YES. Verified by reading the Makefile.

```makefile
# Source: Makefile:19 (check target chain)
check: lint validate validate-base-plugins version-align translation-drift agent-collision-static \
       validate-commands validate-catalog validate-mdlint-config-sync validate-skills-desktop \
       validate-marketplace cell-parity
    @echo "All checks passed!"

# Source: Makefile:413–417
validate-catalog:
    @echo "Validating integrations-catalog.json schema (CAT-03)..."
    @python3 scripts/validate-integrations-catalog.py
```

`make check` → `validate-catalog` → `python3 scripts/validate-integrations-catalog.py`. After Phase 36 edits, this exact same chain enforces SCOPE-01 with no Make changes required. **D-05 confirmed: no new make target needed.**

The chain also includes `version-align` (line 343–365 — checks `manifest.json` ↔ `CHANGELOG.md` ↔ `init-local.sh --version`). Phase 36 must NOT bump the manifest version (D-08 / deferred to Phase 41), so this gate stays green only if the manifest stays at its current version. **Verified:** `manifest.json` version is currently NOT 5.0.0 (CONTEXT.md "Manifest version bump to 5.0.0 — Phase 41" deferred). The plan must NOT touch `manifest.json` or `CHANGELOG.md` in this phase, otherwise `version-align` will fail.

## Test Harness Pattern (verbatim excerpts)

### Pattern A: existing `test-integrations-catalog.sh` `_pyq` helper

This is the cleanest pattern for **validator-side TEST-06 positive assertion** (every entry has `default_scope` ∈ enum). It runs inline Python against the SHIPPED catalog.

```bash
# Source: scripts/tests/test-integrations-catalog.sh:67–86 (verbatim)
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

**Mirror this style for TEST-06 positive assertion (proposed addition to `test-integrations-catalog.sh`):**

```bash
# A15 — every MCP entry has default_scope in {"user","project"} (SCOPE-01 / TEST-06)
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

# A16 — SCOPE-02 grid spot-check: known infra MCP defaults to project
_pyq "A16: aws-cloudwatch-logs default_scope is project (SCOPE-02 D-07)" '
ds = catalog.get("components", {}).get("mcp", {}).get("aws-cloudwatch-logs", {}).get("default_scope")
if ds == "project":
    print("OK")
else:
    print("aws-cloudwatch-logs default_scope is " + repr(ds) + ", expected project")
'

# A17 — SCOPE-02 grid spot-check: known personal MCP defaults to user
_pyq "A17: context7 default_scope is user (SCOPE-02 D-06)" '
ds = catalog.get("components", {}).get("mcp", {}).get("context7", {}).get("default_scope")
if ds == "user":
    print("OK")
else:
    print("context7 default_scope is " + repr(ds) + ", expected user")
'
```

### Pattern B: `test-mcp-selector.sh` synthetic-catalog + `TK_MCP_CATALOG_PATH` test seam

This is the cleanest pattern for **TEST-06 negative validator test** (synthetic catalog missing `default_scope` → validator fails) AND **D-14 backward-compat loader test** (synthetic catalog missing `default_scope` → loader populates `MCP_DEFAULT_SCOPE` with `"user"`, no stderr).

```bash
# Source: scripts/tests/test-mcp-selector.sh:64–86 (verbatim sandbox setup)
run_s1_catalog_correctness() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-mcp-selector.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN
    echo "  -- S1_catalog_correctness: 20 entries, alpha order, notion OAuth --"

    MCP_NAMES=()
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/lib/mcp.sh"
    mcp_catalog_load
    ...
}
```

The mcp.sh test seam — line 33 (verbatim):

```bash
#   TK_MCP_CATALOG_PATH        — override path to mcp-catalog.json (mocked in tests)
```

Resolved at line 79 of `mcp.sh`:

```bash
local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
```

**Recommended hermetic test for D-14 (backward-compat loader fallback)** — write a synthetic catalog into `$SANDBOX` that mirrors the real schema but omits `default_scope` on one entry, set `TK_MCP_CATALOG_PATH=$SANDBOX/synth-catalog.json`, source `mcp.sh`, call `mcp_catalog_load`, assert:

1. `mcp_catalog_load` returns 0.
2. `MCP_DEFAULT_SCOPE[<idx of omitted entry>]` equals `"user"`.
3. Captured stderr from the call is empty (D-11 silent).

Sketch (≤30 lines of Bash):

```bash
run_s_backcompat_default_scope() {
    local SANDBOX
    SANDBOX="$(mktemp -d /tmp/test-catalog-backcompat.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX:?}'" RETURN

    # Write synthetic catalog: 1 MCP entry WITH default_scope, 1 WITHOUT.
    cat > "$SANDBOX/synth-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "categories": ["dev-tools"],
  "components": {
    "mcp": {
      "withscope": {
        "name": "withscope", "display_name": "With", "category": "dev-tools",
        "env_var_keys": [], "install_args": ["withscope", "--", "echo"],
        "description": "with", "requires_oauth": false, "default_scope": "project"
      },
      "noscope": {
        "name": "noscope", "display_name": "Without", "category": "dev-tools",
        "env_var_keys": [], "install_args": ["noscope", "--", "echo"],
        "description": "without", "requires_oauth": false
      }
    }
  }
}
JSON

    # Source loader, capture stderr, run.
    local stderr_tmp="$SANDBOX/stderr"
    local rc=0
    TK_MCP_CATALOG_PATH="$SANDBOX/synth-catalog.json" \
      bash -c "source '${REPO_ROOT}/scripts/lib/mcp.sh'
               mcp_catalog_load
               # Find the index of 'noscope' and print its default scope.
               for i in \"\${!MCP_NAMES[@]}\"; do
                   if [[ \"\${MCP_NAMES[\$i]}\" == 'noscope' ]]; then
                       printf 'NOSCOPE_DS=%s\n' \"\${MCP_DEFAULT_SCOPE[\$i]}\"
                   fi
                   if [[ \"\${MCP_NAMES[\$i]}\" == 'withscope' ]]; then
                       printf 'WITHSCOPE_DS=%s\n' \"\${MCP_DEFAULT_SCOPE[\$i]}\"
                   fi
               done" 2>"$stderr_tmp" || rc=$?

    assert_eq "0" "$rc" "BC1: mcp_catalog_load returns 0 on catalog missing default_scope"
    # ... (parse stdout for NOSCOPE_DS=user and WITHSCOPE_DS=project)
    # ... (assert stderr file is empty)
}
```

### Pattern C: assertion counter + exit semantics (verbatim from both test files)

Both files use the same boilerplate (verbatim from `test-integrations-catalog.sh:33–42`):

```bash
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

And the exit pattern (verbatim from `test-integrations-catalog.sh:274–276`):

```bash
echo ""
echo "Result: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

A new test file or extension MUST mirror this style for D-12 baseline arithmetic to remain trivially auditable.

## Common Pitfalls

### Pitfall 1: BSD vs GNU `sed -i` portability

**What goes wrong:** A planner reaching for `sed -i 's/.../.../' integrations-catalog.json` to insert `default_scope` lines will produce code that works on Linux GNU `sed` but fails on macOS BSD `sed` (BSD requires an explicit empty-string backup arg: `sed -i '' '...'`).

**Why it happens:** STACK.md line 95 ("Compatibility: install scripts must work under `curl ... | bash`; macOS BSD `head`/`sed`/`tail` (no GNU-only flags)").

**How to avoid:** Don't script the JSON edit. Phase 36 is **20 entries, 1 line each, hand-edited and committed**. The catalog is jq-canonical — reviewers will catch a malformed key trivially. If the planner insists on automation, use `python3 -c 'import json; ...; json.dump(..., indent=2)'` (which the validator already imports), NOT `sed`.

**Warning signs:** Any plan task that reaches for `sed -i` on a JSON file.

### Pitfall 2: jq version 1.5 vs 1.6+ behavior on `// "default"`

**What goes wrong:** jq 1.5 (very old) had subtly different `//` short-circuit semantics; jq 1.6+ behaves as expected.

**Why it happens:** Some long-life Linux distros ship jq 1.5 (e.g., Ubuntu 18.04 — but `ubuntu-latest` in CI is now 22.04+, jq 1.6+).

**How to avoid:** STACK.md line 53 lists `jq` as a hard dep but doesn't pin a version. v4.6 Phase 25 introduced jq into the toolkit's hot path and the catalog has shipped on jq 1.6+ since then with no incident. The `// "default"` form is used 5 times in `mcp.sh` already — adding a 6th is ABI-stable.

**Warning signs:** Test on dev machine with `jq --version` ≥ 1.6 before committing. Verified locally: `jq-1.7.1-apple` (HIGH confidence).

### Pitfall 3: Trailing-comma injection during hand-edit

**What goes wrong:** Inserting `"default_scope": "user"` after a block that ends with `"unofficial": true` (no trailing comma) produces invalid JSON if the comma is forgotten. Inserting after `"requires_oauth": false` (when the block has no `unofficial` field) requires the inserter to flip `false` → `false,` and add the new line.

**Why it happens:** JSON is comma-strict; jq-canonical output never has trailing commas.

**How to avoid:** Run `python3 -c "import json; json.load(open('scripts/lib/integrations-catalog.json'))"` after every edit, OR run `python3 scripts/validate-integrations-catalog.py` (which also catches structural breakage at line 88–96 with `json.JSONDecodeError`).

**Warning signs:** Validator emits `integrations-catalog.json is not valid JSON: ...` (validator line 95).

### Pitfall 4: Test PASS-count baseline drift

**What goes wrong:** Adding an assertion to `test-integrations-catalog.sh` increases its `PASS` count from 14 to 15+, but the planning-locked baseline in CONTEXT.md says PASS≥10 (D-12) — that's a floor, not a ceiling. However, a downstream phase-checker that hard-codes the post-edit number could trip up.

**Why it happens:** v4.9 baseline tracking quotes a specific PASS number (`test-mcp-selector.sh PASS=21`) but D-12 explicitly says `PASS≥10` for `test-integrations-catalog.sh` — an inequality.

**How to avoid:** Phrase the success criteria as "≥10" (matches D-12 exactly) and "PASS=21 for `test-mcp-selector.sh`" (because Phase 36 makes ZERO changes to selector behavior — only to mcp.sh array shape; if `test-mcp-selector.sh` is properly hermetic it will not even notice the new array).

**Warning signs:** A PLAN.md verification step that asserts `PASS = exactly 14` on `test-integrations-catalog.sh`.

### Pitfall 5: `echo` and `set -e` interactions in tests

**What goes wrong:** Test files use `set -euo pipefail` (line 23 of `test-integrations-catalog.sh`), and any command in a test that emits non-zero accidentally aborts the whole run. The lessons-learned audit (260430-go5) flagged this category.

**How to avoid:** Use the `|| rc=$?` capture pattern shown in `test-mcp-selector.sh:113–117` for any subprocess that may legitimately return non-zero.

**Warning signs:** Test output stops mid-run with no PASS/FAIL summary printed.

## Code Examples

### Validator extension — full delta for SCOPE-01 (verified pattern)

```python
# scripts/validate-integrations-catalog.py — diff sketch

# Site 1: extend REQUIRED_ENTRY_KEYS (lines 60–68 → add one line):
REQUIRED_ENTRY_KEYS = (
    "name",
    "display_name",
    "category",
    "env_var_keys",
    "install_args",
    "description",
    "requires_oauth",
    "default_scope",   # NEW (Phase 36 / SCOPE-01)
)

# Site 2: enum check (insert immediately after the requires_oauth bool check
# at line 244, before the closing of the for-loop):
default_scope = entry.get("default_scope")
if default_scope not in ("user", "project"):
    fail(
        location + ": .default_scope must be 'user' or 'project', got "
        + repr(default_scope)
    )
    errors += 1

# Site 3: docstring (lines 7–24) — insert default_scope between requires_oauth
# and the closing brace; bump checks-performed count from 10 to 11.
```

### Loader extension — full delta for SCOPE-03 (verified pattern)

```bash
# scripts/lib/mcp.sh — diff sketch

# Site 1: declare new array near other Phase 34-01 declarations (line 100–108):
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE=()

# Site 2: populate inside the per-name while loop (insert at line 159, after
# MCP_CLI_DETECT populate, before `done`):
# shellcheck disable=SC2034
MCP_DEFAULT_SCOPE+=("$(jq -r --arg n "$name" '.components.mcp[$n].default_scope // "user"' "$catalog_path")")

# Site 3: docstring at lines 13–27 — add Globals entry:
#   MCP_DEFAULT_SCOPE[]    — "user"|"project" (parallel; missing → "user" fallback per Phase 36 SCOPE-03)
```

### Catalog edit — pattern for one entry (verified shape)

```diff
       "description": "Live log streams + filter patterns + insights queries",
-      "requires_oauth": false
+      "requires_oauth": false,
+      "default_scope": "project"
     },
```

For entries with `unofficial: true` (notebooklm, telegram), insert after `unofficial`:

```diff
       "requires_oauth": true,
-      "unofficial": true
+      "unofficial": true,
+      "default_scope": "user"
     },
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Schema v1 (`mcp-catalog.json` w/o `unofficial`/`category`/`schema_version`) | Schema v2 (`integrations-catalog.json`, the file we're editing) | Phase 32-01 (v4.9, 2026-05-02) | The current catalog already evolved through one schema migration; the pattern of additive fields with `// default` jq fallback is established (lines 130–142 of `mcp.sh`). Phase 36 reuses that exact migration playbook, just with `default_scope` instead of `category`/`unofficial`. |
| Implicit JSON shape contract (only enforced by jq queries in `mcp.sh`) | Explicit Python validator enforced via `make check` | Phase 32-01 (CAT-03) | The validator IS the schema contract. Phase 36 extends it; Phase 36 does NOT replace it. |
| Single global TUI scope toggle (`TK_MCP_SCOPE` + `s` keypress) | Per-row scope state in `MCP_SELECTED_SCOPE[]`, initialized from `default_scope` | Phase 39 (UPCOMING — not this phase) | Phase 36 ships the data layer; Phase 39 ships the UI consumption. CONTEXT.md `<deferred>` block correctly defers UI work. |

**Deprecated/outdated within toolkit history:**

- `mcp-catalog.json` filename — renamed to `integrations-catalog.json` in Phase 32-01. `mcp.sh` line 53–56 documents the rename. Public function name `mcp_catalog_load` was kept stable.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| (none) | All claims in this research were verified against the current state of files in the repo on 2026-05-04. Every line range was confirmed by reading the file. Every grid name was confirmed present in the catalog. The make-target chain was confirmed by reading the Makefile. The fallback pattern was confirmed by `grep -n '// '` against `mcp.sh`. | — | — |

**Assumption-free verdict:** Phase 36 is small enough and the codebase is stable enough that no `[ASSUMED]` claims are needed. If the catalog or validator is edited between research and planning, the planner should re-verify line ranges (cheap — one `wc -l` and one `grep`).

## Open Questions (RESOLVED)

1. **Should the backward-compat loader test go in `test-integrations-catalog.sh` or in a sibling `test-catalog-scope-fallback.sh`?**
   - What we know: D-14 leaves it to discretion. `test-integrations-catalog.sh` uses a `_pyq` helper that reads the SHIPPED catalog and runs inline Python — it does NOT have a synthetic-catalog harness today. Adding one means adding `mktemp` + sourcing `mcp.sh` + the `TK_MCP_CATALOG_PATH` seam, which is a Bash-test idiom (matches `test-mcp-selector.sh`), not a Python-against-shipped-catalog idiom.
   - What's unclear: whether mixing the two idioms in one file hurts discoverability more than splitting into two files.
   - Recommendation: **New sibling file `test-catalog-scope-fallback.sh`** (matches the test-mcp-selector.sh harness pattern, adds 1 line to the Makefile `test:` block — line 215–217 — for a new test entry "Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)"). Keeps `test-integrations-catalog.sh` purely-`_pyq`-shaped, which is its current style, while gaining the synthetic-catalog test discoverable via the standard "Test N:" echo in `make test`.

2. **Should the validator's positive SCOPE-01 assertion live in `test-integrations-catalog.sh` (per D-13 "validator gets a new SCOPE-01 assertion") or also in a separate file?**
   - What we know: D-13 says "extends `validate-integrations-catalog.py`, no new file" — that points at the validator itself. TEST-06 in REQUIREMENTS.md says "Catalog validator gains assertion for SCOPE-01: every MCP entry has `default_scope` field with valid enum value. Existing `scripts/validate-integrations-catalog.py` extended (no new file)."
   - What's unclear: TEST-06 conflates "validator gains an enforcement check" (the runtime check at line 244 area) with "test-integrations-catalog.sh gains an assertion that the shipped catalog passes SCOPE-01" (the meta-test at A15+).
   - Recommendation: **Both.** The validator gets the enforcement check (the actual D-04 contract). `test-integrations-catalog.sh` gets 3 new `_pyq` assertions (A15: every entry has `default_scope` ∈ enum; A16: aws-cloudwatch-logs is `project`; A17: context7 is `user`) as the regression-locked baseline of SCOPE-02 grid assignments. This way TEST-06 is satisfied at both layers.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `jq` | Loader (`mcp.sh::mcp_catalog_load`) + Makefile gates | ✓ | 1.7.1-apple [VERIFIED 2026-05-04] | None — hard dep per STACK.md |
| `python3` | Validator + inline test harness `_pyq` | ✓ | 3.14.4 [VERIFIED 2026-05-04] | None — hard dep per STACK.md (≥ 3.8 minimum) |
| `bash` | All scripts + tests | ✓ | 5.3.9 (dev) [VERIFIED]; targeting 3.2 compat per CLAUDE.md | None — hard dep |
| `markdownlint-cli` | RESEARCH.md / PLAN.md lint via `make mdlint` | ✓ (assumed installed via `make install`) | per `.markdownlint.json` | None |
| `shellcheck` | Lint of any new test helper via `make shellcheck` | ✓ (assumed installed via `make install`) | warning severity | None |
| `make` | Quality gate runner | ✓ | GNU make on dev/CI | None |

**Missing dependencies with no fallback:** None. All deps confirmed present on the target machine.

**Missing dependencies with fallback:** None.

## Validation Architecture

> `.planning/config.json` was not located in the repo at standard paths; defaulting to nyquist_validation enabled (per agent spec: absent key = enabled). If the project later disables it, this section can be deleted from RESEARCH.md without affecting the implementation.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Plain Bash test scripts using assertion counters; Python stdlib for inline validation. No `bats`/`shunit2` for this phase. |
| Config file | None — tests are standalone Bash scripts that source `mcp.sh` and the catalog directly. |
| Quick run command | `bash scripts/tests/test-integrations-catalog.sh` (≈100ms hermetic) and `python3 scripts/validate-integrations-catalog.py` (≈50ms) |
| Full suite command | `make check` (full quality gate: shellcheck + markdownlint + validate + validate-base-plugins + version-align + translation-drift + agent-collision-static + validate-commands + validate-catalog + validate-mdlint-config-sync + validate-skills-desktop + validate-marketplace + cell-parity) — Makefile line 19 |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCOPE-01 (enforcement) | Validator fails on missing or non-enum `default_scope` | unit (Python) | `python3 scripts/validate-integrations-catalog.py` (positive — runs on shipped catalog) + new negative test that runs validator against a synthetic catalog with the field missing | ✅ existing validator; ❌ Wave 0 needs negative-case harness — see below |
| SCOPE-01 (positive contract) | Shipped catalog passes the new check | integration | `bash scripts/tests/test-integrations-catalog.sh` (gains A15) | ✅ existing; gains 1+ assertion |
| SCOPE-02 (data) | Every entry in the SCOPE-02 grid has the correct value | integration | `bash scripts/tests/test-integrations-catalog.sh` (gains A16/A17 spot checks) | ✅ existing; gains 2+ assertions |
| SCOPE-03 (loader fallback) | Loader populates `MCP_DEFAULT_SCOPE` to "user" on missing field, no stderr | integration (Bash) | `bash scripts/tests/test-catalog-scope-fallback.sh` (NEW) — synthetic catalog + `TK_MCP_CATALOG_PATH` + `mcp_catalog_load` + assert `MCP_DEFAULT_SCOPE` and stderr | ❌ Wave 0 — new file |
| D-12 (baseline guard) | `test-mcp-selector.sh` PASS=21 unchanged | integration | `bash scripts/tests/test-mcp-selector.sh` | ✅ existing — should not need any edits |

### Sampling Rate

- **Per task commit:** `python3 scripts/validate-integrations-catalog.py && bash scripts/tests/test-integrations-catalog.sh && bash scripts/tests/test-catalog-scope-fallback.sh` (≈300ms total — fast enough to run on every save)
- **Per wave merge:** `make check` (full gate — ≈10–30s on dev box per v4.9 baseline)
- **Phase gate:** Full `make check` green + `bash scripts/tests/test-mcp-selector.sh` PASS=21 + new fallback test PASS=N (N ≥ 3 — load returns 0, MCP_DEFAULT_SCOPE[noscope]=user, stderr empty) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] **Negative-case test for validator:** `test-integrations-catalog.sh` (or sibling) needs a `_pyq`-style assertion that runs `python3 scripts/validate-integrations-catalog.py <synthetic-catalog-path>` against a synthetic catalog with `default_scope` missing on one entry, expects exit 1 and stderr containing the failure string. The validator already supports a path-override argument (lines 81–85: "Optional path argument lets future per-project overrides reuse the same validator"). This is the cheapest seam — write synthetic JSON to `$SANDBOX/bad.json`, run `python3 scripts/validate-integrations-catalog.py "$SANDBOX/bad.json"`, assert non-zero exit + assert stderr contains "default_scope".
- [ ] **`scripts/tests/test-catalog-scope-fallback.sh`** (new, ~80 lines) — covers D-14 backward-compat loader test. Pattern source: `test-mcp-selector.sh:64–86` (synthetic-catalog harness) + `test-mcp-selector.sh:113–117` (subshell + stderr capture pattern).
- [ ] **Makefile `test:` target line** (Makefile lines 71–224) — gains a new `Test 48: catalog default_scope fallback (Phase 36 / SCOPE-03)` echo + `bash scripts/tests/test-catalog-scope-fallback.sh` invocation, mirroring lines 215–222.
- Framework install: not needed — every dep is already present.

## Project Constraints (from CLAUDE.md)

CLAUDE.md is read directly by every session in this project. Phase 36 must honor:

- **`make check` MUST PASS.** Includes shellcheck on any modified `.sh` file, markdownlint on any modified `.md` file, and the `validate-catalog` target running the (extended) validator. (CLAUDE.md "Quality Checks (MUST PASS)")
- **`set -euo pipefail` at top of any new shell script.** New `test-catalog-scope-fallback.sh` must follow `test-integrations-catalog.sh:23` exactly. (CLAUDE.md "Code Style — Shell Scripts" via CONVENTIONS.md)
- **Bash 3.2 compat.** No `declare -A`, no `mapfile`, no `${var,,}`, no `read -N`, no `read -t` with floats, no `declare -n`. (CLAUDE.md / STATE.md "Bash 3.2 compatibility")
- **POSIX shell, no GNU-only flags.** No `sed -i` without empty-string arg, no `head -c` (BSD has it but `head -c` semantics differ), no `tail -n +N` reliance on certain flags. (CLAUDE.md / STACK.md)
- **No new pip dependencies.** Validator stays Python stdlib only. (CLAUDE.md / STACK.md "no Node/Python runtime dependency for installers")
- **Conventional Commits.** Commit message form: `feat: phase 36 — default_scope schema + validator + backward-compat loader (SCOPE-01..03)` (CLAUDE.md "Git Workflow", CONVENTIONS.md "Commit Conventions")
- **Never push directly to main.** Phase 36 work lands on a branch; merge happens through review. (CLAUDE.md "Git Workflow")
- **Idempotent installs / no overwrites without confirmation.** N/A for this phase (no install-script changes), but flagged because the toolkit invariant applies project-wide.
- **Knowledge persistence rule:** "When making significant changes — save to three places: CLAUDE.md or templates, README.md/docs, .claude/rules/" — CLAUDE.md says this is for SIGNIFICANT changes. Phase 36 is internal foundation; SCOPE-01..03 visible to users only via Phase 41 docs. **Phase 36 itself does NOT need to update CLAUDE.md/README.md/rules.** That's Phase 41's job (DOCS-01..03 deferred).
- **No untouched markdown lint:** Any RESEARCH.md or PLAN.md authored MUST pass `markdownlint-cli` rules per `.markdownlint.json` (MD040 lang on every code fence — already satisfied below; MD031/MD032 blanks around code/lists; MD026 no trailing punct in headings).
- **Hermetic tests with assertion counters.** Match `test-integrations-catalog.sh` style. (User additional context: "Hermetic tests with assertion counters.")
- **Lessons-learned (260430-go5):** "Single-CLI scenarios are first-class test cases" → not directly relevant here, but the disposition ("always test asymmetric scenarios") informs the recommendation to test BOTH "missing field" and "field present with valid value" in the fallback test.

## Sources

### Primary (HIGH confidence — verified by direct file read on 2026-05-04)

- `scripts/lib/integrations-catalog.json` (lines 1–428) — exact JSON shape of all 20 MCP entries verified.
- `scripts/validate-integrations-catalog.py` (lines 1–267) — REQUIRED_ENTRY_KEYS at lines 60–68; per-entry walk at lines 145–244; path-override seam at lines 81–85.
- `scripts/lib/mcp.sh` (lines 1–185) — `mcp_catalog_load` at lines 78–161; existing `// "default"` patterns at lines 133, 136, 148, 184.
- `Makefile` (lines 1–450) — `check` target chain at line 19; `validate-catalog` target at lines 415–417; `version-align` at lines 343–365.
- `scripts/tests/test-integrations-catalog.sh` (lines 1–276) — `_pyq` helper at lines 67–86; assertion counters at lines 33–42; exit pattern at lines 274–276.
- `scripts/tests/test-mcp-selector.sh` (lines 1–150) — sandbox harness at lines 64–86; stderr capture pattern at lines 113–117.
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/STACK.md`, `.planning/phases/36-catalog-schema-backward-compat/36-CONTEXT.md`, `CLAUDE.md` (project root), `.claude/rules/lessons-learned.md` — all read in full at research time.

### Secondary (MEDIUM confidence)

- jq behavior on `// "default"` (verified locally with `jq --version` → 1.7.1-apple; matches existing 3 sites in `mcp.sh`; no Context7 entry needed for trivially-stable jq operator).

### Tertiary (LOW confidence)

- (none) — all claims verified directly against repo state.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — every dep (jq, python3, bash) verified locally; toolkit has shipped on this stack for 8 milestones.
- Architecture: HIGH — every line range, function name, and pattern excerpt verified by direct file read.
- Pitfalls: HIGH — Pitfalls 1–3 derive from STACK.md hard constraints + lessons-learned.md audit history; Pitfall 4 from D-12 wording; Pitfall 5 from `set -e` interaction documented in lessons-learned.md.
- D-05 confirmation (`make check` invokes validator): HIGH — verified by reading Makefile lines 19 + 415–417.

**Research date:** 2026-05-04
**Valid until:** 2026-06-04 (30 days — stable foundation phase, file structure has been stable for 5 weeks since Phase 32 v4.9 ship; only invalidated if catalog file structure changes or validator is rewritten in the interim, both unlikely).

## RESEARCH COMPLETE
