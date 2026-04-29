---
phase: 25
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/mcp-catalog.json
  - scripts/lib/mcp.sh
autonomous: true
requirements:
  - MCP-01
  - MCP-02
tags: [bash, json, catalog, detection, phase-25]

must_haves:
  truths:
    - "scripts/lib/mcp-catalog.json contains exactly 9 curated MCP entries (context7, sentry, sequential-thinking, playwright, notion, magic, firecrawl, resend, openrouter)"
    - "Each catalog entry is a JSON object with required keys: name, display_name, env_var_keys (array, may be empty), install_args (array), description, requires_oauth (bool)"
    - "scripts/lib/mcp.sh sources cleanly under set -euo pipefail with no errors and exposes mcp_catalog_load + is_mcp_installed + mcp_catalog_names"
    - "is_mcp_installed <name> returns 0 (installed), 1 (not installed), or 2 (claude CLI absent — fail-soft per MCP-02)"
    - "mcp_catalog_load reads the JSON catalog into parallel arrays MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS (semicolon-joined) MCP_INSTALL_ARGS (space-joined) MCP_DESCS MCP_OAUTH (0/1)"
    - "When claude CLI is absent, is_mcp_installed prints a single warning to stderr and returns 2 (DOES NOT exit/error the caller)"
    - "When claude CLI is present, is_mcp_installed parses 'claude mcp list' output and matches the requested name (case-sensitive) row prefix"
    - "Catalog JSON validates: jq -e '.context7 and .sentry and .openrouter' returns 0; entries count == 9 via 'jq -r \"keys | length\"'"
  artifacts:
    - path: "scripts/lib/mcp-catalog.json"
      provides: "9-entry MCP catalog (D-01 from CONTEXT.md)"
      contains: "context7 sentry sequential-thinking playwright notion magic firecrawl resend openrouter"
    - path: "scripts/lib/mcp.sh"
      provides: "Catalog loader + is_mcp_installed probe + mcp_catalog_names helper"
      contains: "mcp_catalog_load is_mcp_installed mcp_catalog_names"
      min_lines: 100
  key_links:
    - from: "scripts/lib/mcp.sh"
      to: "scripts/lib/mcp-catalog.json"
      via: "jq read at mcp_catalog_load time"
      pattern: "jq.*mcp-catalog.json"
    - from: "is_mcp_installed"
      to: "claude mcp list"
      via: "command substitution + grep, fail-soft on missing CLI"
      pattern: "claude mcp list"
    - from: "test seam"
      to: "mocked claude binary"
      via: "TK_MCP_CLAUDE_BIN env-var override"
      pattern: "TK_MCP_CLAUDE_BIN"
---

<objective>
Build the MCP catalog data file (`scripts/lib/mcp-catalog.json`) with all 9 curated MCP entries (per CONTEXT.md D-01) and the foundation library `scripts/lib/mcp.sh` that exposes a JSON-to-bash-arrays loader plus the `is_mcp_installed` detection probe.

Why: every downstream plan in Phase 25 (wizard, install.sh wiring, tests) consumes this catalog and the loader. Building this first as Wave 1 keeps Plans 02-04 unblocked and gives executors a stable contract to import.

Output: 2 files created (mcp-catalog.json, mcp.sh), 0 modified. No install.sh wiring, no wizard, no secrets handling — those land in Plans 02 and 03.

Per MCP-02 fail-soft contract: when `claude` CLI is unavailable, `is_mcp_installed` returns exit code 2 (NOT 1) so callers can distinguish "absent CLI" from "MCP not installed." This three-state return is required by Plan 03 (install.sh page) which renders "?" for state 2 and disables the install action.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/25-mcp-selector/25-CONTEXT.md
@.planning/phases/24-unified-tui-installer-centralized-detection/24-01-detect2-centralized-detection-SUMMARY.md
@scripts/lib/detect2.sh
@scripts/lib/dispatch.sh
@scripts/install.sh

<interfaces>
<!-- Reference patterns from Phase 24 — DO NOT modify these files; mirror the conventions. -->

From scripts/lib/detect2.sh:
```bash
# Pattern: source-safe library with no errexit/nounset alteration
# Pattern: color guards `[[ -z "${RED:-}" ]] && RED='\033[0;31m'`
# Pattern: is_<name>_installed returns 0/1 (Phase 24 binary contract)
# Pattern: detect2_cache populates IS_* exported globals
```

From scripts/lib/dispatch.sh:
```bash
# Pattern: optional global guards `[[ -z "${TK_DISPATCH_ORDER[*]:-}" ]] && TK_DISPATCH_ORDER=(...)`
# Pattern: test seam env-vars `TK_DISPATCH_OVERRIDE_<UPPERCASE_NAME>`
# Pattern: internal helpers `_dispatch_<name>` (underscore prefix to avoid collisions)
```

The catalog entry contract (consumed by Plans 02 and 03):
```json
{
  "context7": {
    "name": "context7",
    "display_name": "Context7",
    "env_var_keys": ["CONTEXT7_API_KEY"],
    "install_args": ["context7", "--", "npx", "-y", "@upstash/context7-mcp"],
    "description": "Up-to-date library docs (React, Next.js, Tailwind, etc.)",
    "requires_oauth": false
  }
}
```
- `name` mirrors the JSON key (used for case-sensitive matching against `claude mcp list` output)
- `display_name` is the human-readable label rendered in the TUI page
- `env_var_keys[]` is the list of env-var names the wizard will prompt for (empty = zero-config MCP like sequential-thinking)
- `install_args[]` is the literal argv passed to `claude mcp add` (first arg is name, rest is the transport+command)
- `description` is the one-liner shown under the focused row
- `requires_oauth` skips the wizard env-prompt step and routes straight to `claude mcp add` (deferred OAuth-flow MCPs — Notion in v1)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Author scripts/lib/mcp-catalog.json with 9 curated entries</name>
  <files>scripts/lib/mcp-catalog.json</files>
  <read_first>
    - .planning/phases/25-mcp-selector/25-CONTEXT.md (read the 9-name list and per-MCP metadata schema)
    - scripts/lib/dispatch.sh (color guard pattern + comment header convention)
    - manifest.json (note files.libs[] alphabetical sort — mcp.sh and mcp-catalog.json land between detect2 and optional-plugins later)
  </read_first>
  <behavior>
    - jq '.context7.name' returns "context7" (string match)
    - jq '. | length' returns 9
    - jq '.openrouter.env_var_keys | length' returns 1 (OPENROUTER_API_KEY)
    - jq '.["sequential-thinking"].env_var_keys | length' returns 0 (zero-config)
    - jq '.notion.requires_oauth' returns true
    - jq '. | keys | sort == ["context7","firecrawl","magic","notion","openrouter","playwright","resend","sentry","sequential-thinking"]' returns true
  </behavior>
  <action>
Create `scripts/lib/mcp-catalog.json` as a flat JSON object keyed by MCP name. EXACT 9 keys (lowercase, hyphens for `sequential-thinking`):

`context7`, `sentry`, `sequential-thinking`, `playwright`, `notion`, `magic`, `firecrawl`, `resend`, `openrouter`

Each value is an object with these REQUIRED fields (in this order for diff stability):
- `name` (string, mirrors the key) — used for case-sensitive grep match against `claude mcp list` output rows
- `display_name` (string) — title-cased label for TUI rendering
- `env_var_keys` (array of strings) — env-var names the wizard prompts for; empty array for zero-config
- `install_args` (array of strings) — passed verbatim to `claude mcp add`; FIRST element is the MCP name, REMAINDER is the transport spec
- `description` (string) — one-liner for the description line
- `requires_oauth` (boolean) — `true` skips wizard env prompts and routes straight to `claude mcp add` (Notion in v1)

CRITICAL field values per CONTEXT.md "Specific Ideas":

| Name | env_var_keys | requires_oauth | description hint |
|------|--------------|----------------|------------------|
| context7 | `["CONTEXT7_API_KEY"]` | false | Up-to-date library docs |
| sentry | `["SENTRY_AUTH_TOKEN"]` | false | Error monitoring + issue triage |
| sequential-thinking | `[]` | false | Structured step-by-step reasoning (zero-config) |
| playwright | `[]` | false | Browser automation + screenshot |
| notion | `[]` | true | Workspace pages + databases (OAuth) |
| magic | `["MAGIC_API_KEY"]` | false | UI component generation (21st.dev) |
| firecrawl | `["FIRECRAWL_API_KEY"]` | false | Website scraping + crawling |
| resend | `["RESEND_API_KEY"]` | false | Transactional email send |
| openrouter | `["OPENROUTER_API_KEY"]` | false | Multi-model LLM routing |

For `install_args[]` use canonical npx forms (executors should use the actual upstream package names from public docs — research with `npx --yes ctx7@latest library <name>` or check public registries):
- context7: `["context7", "--", "npx", "-y", "@upstash/context7-mcp"]`
- sentry: `["sentry", "--", "npx", "-y", "@sentry/mcp-server"]`
- sequential-thinking: `["sequential-thinking", "--", "npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]`
- playwright: `["playwright", "--", "npx", "-y", "@playwright/mcp"]`
- notion: `["notion", "--", "npx", "-y", "@notionhq/notion-mcp-server"]`
- magic: `["magic", "--", "npx", "-y", "@21st-dev/magic"]`
- firecrawl: `["firecrawl", "--", "npx", "-y", "firecrawl-mcp"]`
- resend: `["resend", "--", "npx", "-y", "@resend/mcp-send-email"]`
- openrouter: `["openrouter", "--", "npx", "-y", "openrouter-mcp"]`

If any package name above does not match the actual published npm package, FIX IT before writing — verify via Context7 MCP (mcp__context7__resolve-library-id then resolve to the right package) or `npm view <pkg> name` if available. Do NOT invent names.

JSON formatting: 2-space indent, trailing newline, alphabetical key order at the TOP level (matches manifest.json convention from Phase 24 D-31). Use `python3 -m json.tool < /tmp/draft.json` to normalize before writing.
  </action>
  <verify>
    <automated>jq -e '. | length == 9' scripts/lib/mcp-catalog.json && jq -e '.context7.requires_oauth == false' scripts/lib/mcp-catalog.json && jq -e '.notion.requires_oauth == true' scripts/lib/mcp-catalog.json && jq -e '.["sequential-thinking"].env_var_keys | length == 0' scripts/lib/mcp-catalog.json && jq -e '.openrouter.env_var_keys[0] == "OPENROUTER_API_KEY"' scripts/lib/mcp-catalog.json && jq -e '. | keys | sort == ["context7","firecrawl","magic","notion","openrouter","playwright","resend","sentry","sequential-thinking"]' scripts/lib/mcp-catalog.json</automated>
  </verify>
  <done>scripts/lib/mcp-catalog.json contains exactly 9 entries; all 6 jq assertions above pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Author scripts/lib/mcp.sh — catalog loader + is_mcp_installed</name>
  <files>scripts/lib/mcp.sh</files>
  <read_first>
    - scripts/lib/mcp-catalog.json (must exist from Task 1)
    - scripts/lib/detect2.sh (color guards, source-safe pattern, is_<name>_installed contract)
    - scripts/lib/dispatch.sh (test seam env-var pattern: TK_DISPATCH_OVERRIDE_*)
    - scripts/install.sh:115-130 (curl-pipe lib loading — mcp.sh must work both local and via curl)
  </read_first>
  <behavior>
    - Sourcing mcp.sh under `set -euo pipefail` does not exit/error
    - `mcp_catalog_load` populates 6 parallel arrays: MCP_NAMES MCP_DISPLAY MCP_ENV_KEYS MCP_INSTALL_ARGS MCP_DESCS MCP_OAUTH (length 9 each)
    - `mcp_catalog_names` echoes 9 names, one per line, alphabetically sorted
    - `is_mcp_installed context7` returns 2 (CLI absent) when PATH has no `claude` binary
    - `is_mcp_installed context7` with TK_MCP_CLAUDE_BIN set to a mock script that prints "context7   transport=...\n" to stdout → returns 0
    - `is_mcp_installed missing-name` with TK_MCP_CLAUDE_BIN set to mock script that prints "context7\n" → returns 1
    - When CLI is absent, exactly ONE warning line is written to stderr (not multiple, not stdout)
    - Sourcing mcp.sh from inside install.sh does NOT change `set -e` mode of caller
  </behavior>
  <action>
Create `scripts/lib/mcp.sh` as a sourced library (NOT executed standalone). Header block must follow Phase 24 convention from `scripts/lib/dispatch.sh:1-24`. Required structure:

```bash
#!/bin/bash

# Claude Code Toolkit — MCP Catalog Loader + Detection (v4.6+)
# Source this file. Do NOT execute it directly.
# Exposes:
#   mcp_catalog_load           — parses scripts/lib/mcp-catalog.json into MCP_* arrays
#   mcp_catalog_names          — prints 9 names one-per-line (alpha sorted)
#   is_mcp_installed <name>    — returns 0 (installed) / 1 (not installed) / 2 (claude CLI absent)
# Globals (write):
#   MCP_NAMES[]            — 9 catalog keys (alpha order)
#   MCP_DISPLAY[]          — display_name strings (parallel to MCP_NAMES)
#   MCP_ENV_KEYS[]         — env-var names joined with ';' (empty string = zero-config)
#   MCP_INSTALL_ARGS[]     — install_args[] joined with $'\037' (unit-separator) for safe split
#   MCP_DESCS[]            — description strings (parallel)
#   MCP_OAUTH[]            — 0/1 ints (parallel)
# Test seams:
#   TK_MCP_CLAUDE_BIN     — override path to claude binary (mocked in tests)
#   TK_MCP_CATALOG_PATH   — override path to mcp-catalog.json (mocked in tests)
#
# IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.
```

Implementation requirements:

1. **Color guards** — copy the 5-color-guard block from `scripts/lib/detect2.sh:18-28` verbatim (RED/GREEN/YELLOW/BLUE/NC with `[[ -z "${VAR:-}" ]] &&`).

2. **Catalog path resolution:**
   - Honor `TK_MCP_CATALOG_PATH` env if set (test seam)
   - Otherwise resolve to `$(dirname "${BASH_SOURCE[0]}")/mcp-catalog.json` (sibling file)
   - Use the same `cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd` pattern as detect2.sh:34

3. **mcp_catalog_load function:**
   ```bash
   mcp_catalog_load() {
       local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
       if [[ ! -f "$catalog_path" ]]; then
           echo -e "${RED}✗${NC} mcp-catalog.json not found at $catalog_path" >&2
           return 1
       fi
       if ! command -v jq >/dev/null 2>&1; then
           echo -e "${RED}✗${NC} jq required for mcp_catalog_load" >&2
           return 1
       fi
       MCP_NAMES=()
       MCP_DISPLAY=()
       MCP_ENV_KEYS=()
       MCP_INSTALL_ARGS=()
       MCP_DESCS=()
       MCP_OAUTH=()
       local name
       while IFS= read -r name; do
           MCP_NAMES+=("$name")
           MCP_DISPLAY+=("$(jq -r --arg n "$name" '.[$n].display_name' "$catalog_path")")
           MCP_ENV_KEYS+=("$(jq -r --arg n "$name" '.[$n].env_var_keys | join(";")' "$catalog_path")")
           # Use $'\037' (unit separator) to join install_args[] — survives spaces in args.
           MCP_INSTALL_ARGS+=("$(jq -r --arg n "$name" '.[$n].install_args | join("")' "$catalog_path")")
           MCP_DESCS+=("$(jq -r --arg n "$name" '.[$n].description' "$catalog_path")")
           if [[ "$(jq -r --arg n "$name" '.[$n].requires_oauth' "$catalog_path")" == "true" ]]; then
               MCP_OAUTH+=(1)
           else
               MCP_OAUTH+=(0)
           fi
       done < <(jq -r 'keys | sort | .[]' "$catalog_path")
   }
   ```

4. **mcp_catalog_names function:**
   ```bash
   mcp_catalog_names() {
       local catalog_path="${TK_MCP_CATALOG_PATH:-$(_mcp_default_catalog_path)}"
       jq -r 'keys | sort | .[]' "$catalog_path"
   }
   ```

5. **is_mcp_installed function — CRITICAL three-state return contract (MCP-02):**
   ```bash
   is_mcp_installed() {
       local name="$1"
       if [[ -z "$name" ]]; then
           echo -e "${RED}✗${NC} is_mcp_installed: missing argument" >&2
           return 1
       fi
       local claude_bin="${TK_MCP_CLAUDE_BIN:-}"
       if [[ -z "$claude_bin" ]]; then
           if command -v claude >/dev/null 2>&1; then
               claude_bin="claude"
           fi
       fi
       if [[ -z "$claude_bin" ]]; then
           # MCP-02 fail-soft: warn (single line) and return 2 — caller distinguishes from 1.
           # Use a global guard so we only warn ONCE per shell to avoid spam during catalog scan.
           if [[ -z "${_MCP_CLI_WARNED:-}" ]]; then
               echo -e "${YELLOW}!${NC} claude CLI not found — MCP detection unavailable" >&2
               _MCP_CLI_WARNED=1
           fi
           return 2
       fi
       local list_out
       if ! list_out=$("$claude_bin" mcp list 2>/dev/null); then
           # CLI present but list failed (e.g., not authenticated). Treat as state 2 (unknown).
           return 2
       fi
       # Match a row that begins with "<name>" followed by whitespace OR end-of-line.
       # `claude mcp list` rows look like "context7    sse    https://..."
       if printf '%s\n' "$list_out" | grep -E "^${name}([[:space:]]|$)" >/dev/null 2>&1; then
           return 0
       fi
       return 1
   }
   ```

6. **Internal helper:**
   ```bash
   _mcp_default_catalog_path() {
       local d
       d="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
       echo "${d}/mcp-catalog.json"
   }
   ```

Do NOT add: wizard logic, secrets writing, dispatch_mcps. Those land in Plans 02 and 03.

shellcheck must pass with `-S warning`. Use `# shellcheck disable=SC2034` directives only on the parallel-array writes if shellcheck flags them as unused (caller in Plan 03 will consume).
  </action>
  <verify>
    <automated>shellcheck -S warning scripts/lib/mcp.sh && bash -c 'set -euo pipefail; source scripts/lib/mcp.sh; mcp_catalog_load; [[ ${#MCP_NAMES[@]} -eq 9 ]] || exit 1; [[ "${MCP_NAMES[0]}" == "context7" ]] || exit 1; mcp_catalog_names | wc -l | tr -d " " | grep -q "^9$" || exit 1; rc=0; (PATH=/usr/bin:/bin is_mcp_installed context7) || rc=$?; [[ $rc -eq 2 ]] || { echo "expected rc=2 (CLI absent), got $rc"; exit 1; }; echo OK'</automated>
  </verify>
  <done>scripts/lib/mcp.sh sources cleanly under set -euo pipefail; mcp_catalog_load populates 9-element arrays; mcp_catalog_names prints 9 alpha-sorted names; is_mcp_installed returns 2 when claude binary is absent (PATH stripped); shellcheck warning-level passes with zero issues.</done>
</task>

</tasks>

<verification>
- `jq -e '. | length == 9' scripts/lib/mcp-catalog.json` → 0
- `bash -c 'set -euo pipefail; source scripts/lib/mcp.sh; mcp_catalog_load && echo OK'` → prints OK
- `shellcheck -S warning scripts/lib/mcp.sh` → 0 warnings
- `make shellcheck` → unchanged (Phase 24 scripts still pass; new scripts/lib/mcp.sh joins clean)
- `make check` → unchanged (mcp.sh / mcp-catalog.json not yet in manifest.json — Plan 04 wires that)
</verification>

<success_criteria>
1. `scripts/lib/mcp-catalog.json` exists, is valid JSON, contains exactly 9 keys matching D-01 names.
2. `scripts/lib/mcp.sh` sources cleanly, exposes `mcp_catalog_load`, `mcp_catalog_names`, `is_mcp_installed` per the interfaces above.
3. `is_mcp_installed` returns 2 when claude CLI is absent (MCP-02 fail-soft contract).
4. All jq + bash + shellcheck assertions in `<verify>` blocks above pass.
5. No modifications to existing files — Plans 02-04 do that wiring.
</success_criteria>

<output>
After completion, create `.planning/phases/25-mcp-selector/25-01-mcp-catalog-and-loader-SUMMARY.md` documenting:
- The 9 catalog entries written
- Verified npm package names for each (so Plan 02 wizard knows install commands are real)
- Any deviations from CONTEXT.md D-01 (e.g., if a package name had to change because the upstream package didn't exist)
- The exact return code semantics of `is_mcp_installed` (0/1/2)
</output>
