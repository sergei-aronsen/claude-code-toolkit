---
phase: 37-project-secrets-library
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/lib/project-secrets.sh
autonomous: true
requirements:
  - SEC-01
  - SEC-02
  - SEC-03
  - SEC-04
  - SEC-05
  - SEC-06
must_haves:
  truths:
    - "Sourcing scripts/lib/project-secrets.sh produces zero filesystem side effects (function definitions only)"
    - "After sourcing, four functions exist: project_secrets_write_env, project_secrets_ensure_gitignore, project_secrets_render_mcp_env_block, project_secrets_validate_mcp_env_block"
    - "project_secrets_write_env <root> KEY value creates <root>/.env at mode 0600 and writes literal KEY=value"
    - "project_secrets_write_env on collision prompts via TK_MCP_TTY_SRC and fail-closes N"
    - "project_secrets_ensure_gitignore appends comment + .env line when absent and is a no-op when present (exact ^.env$ match)"
    - "project_secrets_render_mcp_env_block KEY1 KEY2 echoes {\"KEY1\":\"${KEY1}\",\"KEY2\":\"${KEY2}\"} with no trailing newline"
    - "project_secrets_validate_mcp_env_block returns rc=1 on any literal value, rc=0 on ${VAR} form, bypassed by TK_PROJECT_SECRETS_ALLOW_LITERAL=1 with stderr warning"
    - "project_secrets_write_env rejects values containing $, backtick, backslash, double-quote, single-quote, or newline via shared _mcp_validate_value (D-16)"
  artifacts:
    - path: "scripts/lib/project-secrets.sh"
      provides: "project secrets writer library — 4 public functions + private helpers, source-safe"
      contains: "project_secrets_write_env(), project_secrets_ensure_gitignore(), project_secrets_render_mcp_env_block(), project_secrets_validate_mcp_env_block()"
  key_links:
    - from: "scripts/lib/project-secrets.sh"
      to: "scripts/lib/mcp.sh::_mcp_validate_value"
      via: "lazy source guard (command -v _mcp_validate_value)"
      pattern: "command -v _mcp_validate_value"
    - from: "scripts/lib/project-secrets.sh::project_secrets_write_env"
      to: "scripts/lib/tui.sh::tui_tty_read"
      via: "transitive lazy source via mcp.sh"
      pattern: "tui_tty_read choice"
    - from: "scripts/lib/project-secrets.sh::project_secrets_validate_mcp_env_block"
      to: "stderr refusal message contract"
      via: "echo to >&2"
      pattern: "refusing to write literal value into .mcp.json"
---

<objective>
Ship `scripts/lib/project-secrets.sh` — a new source-safe library exposing four functions that own the project-scope secrets boundary end-to-end. The library writes `KEY=value` lines to `<project>/.env` (mode 0600, idempotent merge with collision prompt), guarantees `.env` is in `<project>/.gitignore`, renders `${VAR}` substitution form for `.mcp.json` env blocks, refuses any literal secret in `.mcp.json` env blocks (defense-in-depth), and rejects shell-metacharacter values by reusing `_mcp_validate_value` from `mcp.sh`.

Purpose: Lock the secrets boundary that Phase 38 (`mcp_wizard_run` per-MCP scope routing) and Phase 40 (uninstall negative-contract assertion) both depend on. Without this lib the entire v5.0 project-scope path has no place to write secrets without leaking them into `.mcp.json` (which lives in the repo).

Output: One new file — `scripts/lib/project-secrets.sh`. Library is scope-agnostic; consumers branch on scope. Tests for this lib ship in plan 37-02 (Wave 2). The lib must pass `make shellcheck` standalone before plan 02 runs, but `make check` end-to-end gating is deferred until 37-02 lands the tests + Makefile + CI wiring.
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
@.planning/phases/37-project-secrets-library/37-CONTEXT.md
@.planning/phases/37-project-secrets-library/37-PATTERNS.md
@scripts/lib/mcp.sh
@scripts/lib/tui.sh

<interfaces>
<!-- Existing reusable contracts the executor must build against. Extracted from codebase. -->
<!-- Do NOT explore the codebase for these — read directly from this section. -->

From scripts/lib/mcp.sh:431-441 (REUSE per D-16, do NOT duplicate the regex):
```bash
_mcp_validate_value() {
    local v="$1"
    if [[ "$v" == *'$'* || "$v" == *'`'* || "$v" == *'\'* || "$v" == *'"'* || "$v" == *"'"* ]]; then
        return 1
    fi
    if [[ "$v" == *$'\n'* ]]; then
        return 1
    fi
    return 0
}
```

From scripts/lib/tui.sh::tui_tty_read (signature):
```bash
# tui_tty_read <varname> <prompt> <hidden_flag> <tty_src>
# hidden_flag: 0 = visible, 1 = hidden (read -s)
# tty_src: file path or process-substitution path; default /dev/tty
# returns 0 on read success, 1 on read failure (caller fail-closes)
tui_tty_read choice "[y/N] Overwrite ${key}? " 0 "$tty_src"
```

From scripts/lib/mcp.sh:511-565 (mcp_secrets_set — order-of-operations template to mirror):
```bash
# 1. validate value via _mcp_validate_value (return 1 on rejection)
# 2. mkdir -p "$(dirname "$cfg")"
# 3. touch "$cfg"
# 4. chmod 0600 "$cfg"
# 5. mcp_secrets_load (parses existing entries)
# 6. if collision: tui_tty_read choice → y/Y rewrites via mktemp+mv, default N returns 0
# 7. else: append "KEY=VALUE\n" via printf
# 8. chmod 0600 "$cfg" (idempotent — defends umask widening)
```

From scripts/lib/mcp.sh:448-480 (mcp_secrets_load line parser — adapt as private _project_secrets_load_env <path>):
```bash
# - skip lines matching ^[[:space:]]*#
# - skip blank lines
# - skip lines without '='
# - split on first '=': key="${line%%=*}", value="${line#*=}"
# - validate key against ^[A-Z_][A-Z0-9_]*$ (audit L1 defense in depth)
```

From scripts/lib/mcp.sh:484-494 (_mcp_secrets_index — adapt as _project_secrets_index <key>):
```bash
# echo 0-based index of $1 in array; return 1 if absent
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Write scripts/lib/project-secrets.sh — header + four public functions + private helpers</name>
  <files>scripts/lib/project-secrets.sh</files>

  <read_first>
    - scripts/lib/mcp.sh (lines 1-75 for header pattern, 425-565 for `_mcp_validate_value`, `mcp_secrets_load`, `_mcp_secrets_index`, `mcp_secrets_set` order-of-operations)
    - scripts/lib/tui.sh (lines 457-510 for `tui_tty_read` signature + behavior)
    - .planning/phases/37-project-secrets-library/37-CONTEXT.md (D-01..D-17 — public API, write-env order, gitignore guard, render rules, validate rules, metacharacter rejection)
    - .planning/phases/37-project-secrets-library/37-PATTERNS.md (full file — header pattern excerpt at lines 27-77, write_env adaptation at lines 79-150, load_env at lines 152-196, ensure_gitignore at lines 198-233, render at lines 235-271, validate at lines 273-305, no-`set -euo` rule at lines 590-598, error glyphs at lines 600-616, Bash 3.2 invariants at lines 640-651)
  </read_first>

  <behavior>
    Sourcing `scripts/lib/project-secrets.sh` defines functions only — no filesystem writes, no exits, no environment mutations beyond defining color constants behind `[[ -z "${VAR:-}" ]]` guards. The four public functions and four private helpers below match the contracts in CONTEXT.md D-01..D-17 and PATTERNS.md §`scripts/lib/project-secrets.sh`.

    Function-level behaviors:
    - `project_secrets_write_env <project_root> <KEY> <VALUE>`: 8-step order from CONTEXT.md D-04. Reuses `_mcp_validate_value` for SEC-06 (D-16). Collision prompt via `tui_tty_read` with `TK_MCP_TTY_SRC` seam (D-05). Returns 0 on success or deliberate-N no-op; returns 1 on missing args, validation failure, or write error. Stderr message on metacharacter rejection: `✗ project_secrets_write_env: value for <KEY> contains shell metacharacters — refusing to write` (D-17).
    - `project_secrets_ensure_gitignore <project_root>`: D-07/D-08/D-09. `grep -Fxq '.env'` exact-fixed-line match. Creates `.gitignore` mode 0644 if absent. Appends two-line block (comment + `.env`) when absent. Idempotent on re-run.
    - `project_secrets_render_mcp_env_block KEY1 KEY2 …`: D-10/D-11/D-12. Empty args → echo `{}`. Validates each key against `^[A-Z_][A-Z0-9_]*$`; invalid key → rc=1 with `✗ project_secrets_render_mcp_env_block: invalid key '<k>'` to stderr. Otherwise echoes `{"K1":"${K1}","K2":"${K2}"}` via `jq -nc --args` with no trailing newline.
    - `project_secrets_validate_mcp_env_block <json_string>`: D-13/D-14/D-15. Parses values via `jq -r '.[] | tostring'`, regex-tests each against `^\$\{[A-Z_][A-Z0-9_]*\}$`. Refusal returns rc=1 with stderr `✗ refusing to write literal value into .mcp.json (use ${VAR} substitution)`. `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` bypass emits stderr warning `⚠ project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only` and returns rc=0.

    Private helpers (mirror `_mcp_*` shape per D-03):
    - `_project_secrets_load_env <env_path>`: copy of `mcp_secrets_load` parser (mcp.sh:448-480) populating `_PROJECT_SECRETS_KEYS[]` / `_PROJECT_SECRETS_VALUES[]` (namespaced arrays — do NOT collide with `MCP_SECRET_*`).
    - `_project_secrets_index <key>`: copy of `_mcp_secrets_index` (mcp.sh:484-494) operating on the namespaced arrays.
  </behavior>

  <action>
    Create file `scripts/lib/project-secrets.sh` with `#!/bin/bash` shebang and NO `set -euo pipefail` (PATTERNS.md §"Source-safe library header" — sourced libs must not alter caller error mode).

    Section 1 — Header comment block. Replicate `mcp.sh:1-40` shape but for this lib:
    ```
    # Claude Code Toolkit — Project Secrets Library (v5.0+)
    # Source this file. Do NOT execute it directly.
    # Exposes (Phase 37 / SEC-01..06):
    #   project_secrets_write_env <root> <KEY> <VALUE>      — write KEY=VALUE to <root>/.env (mode 0600, idempotent)
    #   project_secrets_ensure_gitignore <root>             — guarantee `.env` in <root>/.gitignore (D-07/08/09)
    #   project_secrets_render_mcp_env_block <KEY...>       — echo {"K":"${K}",…} JSON for .mcp.json env block
    #   project_secrets_validate_mcp_env_block <json>       — refuse literal values in .mcp.json env (defense in depth)
    # Globals (write):
    #   _PROJECT_SECRETS_KEYS[]                             — keys parsed from <root>/.env (private)
    #   _PROJECT_SECRETS_VALUES[]                           — values parsed from <root>/.env (private)
    # Test seams:
    #   TK_MCP_TTY_SRC                                      — REUSED (D-05) — TTY source for collision prompt
    #   TK_PROJECT_SECRETS_ALLOW_LITERAL                    — bypass SEC-05 literal refusal (test-only — D-15)
    #
    # IMPORTANT: No errexit/nounset/pipefail — sourced libraries must not alter caller error mode.
    ```

    Section 2 — Color guards. Copy `mcp.sh:42-52` verbatim (`RED`, `GREEN`, `YELLOW`, `BLUE`, `NC` behind `[[ -z "${VAR:-}" ]] &&` guards with `# shellcheck disable=SC2034`).

    Section 3 — Lazy source `mcp.sh` so `_mcp_validate_value` (D-16) and the transitive `tui_tty_read` are both available. Replicate `mcp.sh:65-75` adapted for this lib (PATTERNS.md lines 67-77):
    ```bash
    if ! command -v _mcp_validate_value >/dev/null 2>&1; then
        _PROJECT_SECRETS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || pwd)"
        if [[ -f "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh" ]]; then
            # shellcheck source=/dev/null
            source "${_PROJECT_SECRETS_LIB_DIR}/mcp.sh"
        fi
    fi
    ```

    Section 4 — `_project_secrets_load_env <env_path>` (private). Copy `mcp_secrets_load` (mcp.sh:448-480) verbatim with two changes:
    - Take `cfg` from `$1` (not from `_mcp_config_path`).
    - Populate `_PROJECT_SECRETS_KEYS[]` / `_PROJECT_SECRETS_VALUES[]` (NOT `MCP_SECRET_*`).
    Keep the `^[A-Z_][A-Z0-9_]*$` audit L1 guard verbatim. Mark function `# shellcheck disable=SC2034` like mcp.sh:447.

    Section 5 — `_project_secrets_index <key>` (private). Copy `_mcp_secrets_index` (mcp.sh:484-494) verbatim, swap arrays to `_PROJECT_SECRETS_KEYS[]`.

    Section 6 — `project_secrets_write_env <project_root> <KEY> <VALUE>`. Adapt `mcp_secrets_set` (mcp.sh:511-565) per PATTERNS.md lines 141-150:
    - Signature: 3 positional args. Validate `project_root` and `key` non-empty; emit `✗ project_secrets_write_env: missing project_root argument` or `✗ project_secrets_write_env: missing KEY argument` to stderr and `return 1`.
    - SEC-06 reuse: call `_mcp_validate_value "$value"`; on rejection emit `✗ project_secrets_write_env: value for ${key} contains shell metacharacters (\$, backtick, backslash, quote, newline) — refusing to write` to stderr and `return 1`.
    - Step 1: `mkdir -p "$project_root" || return 1` (NOT `dirname` — D-04 step 1 forbids creating paths above the root).
    - Step 2-4: `cfg="${project_root%/}/.env"`, `touch "$cfg" || return 1`, `chmod 0600 "$cfg" || return 1`.
    - Step 5: `_project_secrets_load_env "$cfg"`.
    - Step 6: collision branch via `_project_secrets_index "$key"`. Prompt text: `[y/N] Overwrite ${key} in ${project_root}/.env? `. Reuse `tui_tty_read` and `TK_MCP_TTY_SRC` (D-05 — do NOT coin a new seam). Fail-closed N when `tui_tty_read` returns non-zero.
    - On `y|Y`: rewrite via `mktemp "${cfg}.XXXXXX"` + loop substituting at matching `idx` + `mv tmp cfg` + `chmod 0600`. Mirrors mcp.sh:541-552 exactly.
    - On `*`: `return 0` (preserve existing).
    - Else (no collision): `printf '%s=%s\n' "$key" "$value" >> "$cfg" || return 1; chmod 0600 "$cfg" || return 1`.

    Section 7 — `project_secrets_ensure_gitignore <project_root>`. Use the skeleton from PATTERNS.md lines 202-230:
    - Validate `project_root` non-empty; emit `✗ project_secrets_ensure_gitignore: missing project_root argument` to stderr and `return 1` if missing.
    - `mkdir -p "$project_root" || return 1`.
    - `gi="${project_root%/}/.gitignore"`.
    - If file exists AND `grep -Fxq '.env' "$gi"` → `return 0` (D-07 idempotent).
    - If file does NOT exist: `: > "$gi" && chmod 0644 "$gi" || return 1`.
    - Else if file has content and last byte is non-newline: append a `\n` first (D-08 leading blank avoidance).
    - Append `# claude-code-toolkit: never commit project-scope MCP secrets\n.env\n` via a `{ printf …; printf …; } >> "$gi"` block.
    - `chmod 0644 "$gi" || return 1; return 0`.

    Section 8 — `project_secrets_render_mcp_env_block KEY1 KEY2 …`. Use the skeleton from PATTERNS.md lines 251-268:
    - If `$# -eq 0`: `printf '{}'` (no `\n` — D-10/D-11) and `return 0`.
    - Loop over `"$@"`: validate each `k` against bash regex `^[A-Z_][A-Z0-9_]*$`; on failure emit `✗ project_secrets_render_mcp_env_block: invalid key '$k'` to stderr and `return 1` (D-12).
    - Render via `jq -nc --args 'reduce $ARGS.positional[] as $k ({}; . + {($k): ("${" + $k + "}")})' -- "$@"`.
    - `jq -nc` produces compact single-line output (no trailing newline when piped — verified via the test in plan 02).

    Section 9 — `project_secrets_validate_mcp_env_block <json_string>`. Use the skeleton from PATTERNS.md lines 280-302:
    - Validate `$1` non-empty; emit `✗ project_secrets_validate_mcp_env_block: missing json argument` to stderr and `return 1` if missing.
    - Require `jq`: `command -v jq >/dev/null 2>&1` else emit `✗ project_secrets_validate_mcp_env_block: jq required` to stderr and `return 1`.
    - Stream values via `printf '%s' "$json" | jq -r '.[] | tostring' 2>/dev/null` into a `while IFS= read -r v; do …; done < <(…)` loop.
    - Per value: bash regex test against `^\$\{[A-Z_][A-Z0-9_]*\}$`. On failure:
      - If `${TK_PROJECT_SECRETS_ALLOW_LITERAL:-}" == "1"`: emit `⚠ project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only` to stderr and `continue` (D-15).
      - Else emit `✗ refusing to write literal value into .mcp.json (use \${VAR} substitution)` to stderr and `return 1` (D-14 — the dollar must be escaped in the source string so the literal `${VAR}` lands in the message; use single-quoted printf or escape via `\$`).
    - End of loop: `return 0`.

    Final shellcheck pass: run `shellcheck -S warning scripts/lib/project-secrets.sh` and ensure clean. The `# shellcheck disable=SC2034` comments above `_PROJECT_SECRETS_KEYS` / `_PROJECT_SECRETS_VALUES` array initializers may be needed — match `mcp.sh:447`'s convention.
  </action>

  <verify>
    <automated>
      bash -c '
        set -e
        # 1. file exists and contains the four public function names
        grep -q "^project_secrets_write_env()" scripts/lib/project-secrets.sh
        grep -q "^project_secrets_ensure_gitignore()" scripts/lib/project-secrets.sh
        grep -q "^project_secrets_render_mcp_env_block()" scripts/lib/project-secrets.sh
        grep -q "^project_secrets_validate_mcp_env_block()" scripts/lib/project-secrets.sh
        # 2. private helpers present (D-03 naming)
        grep -q "^_project_secrets_load_env()" scripts/lib/project-secrets.sh
        grep -q "^_project_secrets_index()" scripts/lib/project-secrets.sh
        # 3. lazy-source guard for _mcp_validate_value present (D-16)
        grep -q "command -v _mcp_validate_value" scripts/lib/project-secrets.sh
        # 4. NO `set -euo pipefail` at top (sourced lib invariant)
        ! grep -E "^set -[eu]" scripts/lib/project-secrets.sh
        # 5. SEC-05 stderr message contains the exact contract phrase
        grep -q "refusing to write literal value into .mcp.json" scripts/lib/project-secrets.sh
        # 6. SEC-06 stderr message phrase present
        grep -q "shell metacharacters" scripts/lib/project-secrets.sh
        # 7. SEC-03 gitignore comment phrase
        grep -q "claude-code-toolkit: never commit project-scope MCP secrets" scripts/lib/project-secrets.sh
        # 8. test seam name (D-15)
        grep -q "TK_PROJECT_SECRETS_ALLOW_LITERAL" scripts/lib/project-secrets.sh
        # 9. reuses TK_MCP_TTY_SRC (D-05) — do NOT coin a new seam
        grep -q "TK_MCP_TTY_SRC" scripts/lib/project-secrets.sh
        # 10. shellcheck clean
        shellcheck -S warning scripts/lib/project-secrets.sh
        # 11. sourcing is a no-op (no side effects)
        bash -c "source scripts/lib/project-secrets.sh; declare -f project_secrets_write_env >/dev/null"
        echo OK
      '
    </automated>
  </verify>

  <acceptance_criteria>
    - File `scripts/lib/project-secrets.sh` exists and is non-empty.
    - `grep -c "^project_secrets_" scripts/lib/project-secrets.sh` returns ≥ 4 (the four public functions).
    - `grep -c "^_project_secrets_" scripts/lib/project-secrets.sh` returns ≥ 2 (load + index helpers).
    - `grep -q "command -v _mcp_validate_value" scripts/lib/project-secrets.sh` succeeds (D-16 lazy source).
    - `! grep -E "^set -[eu]" scripts/lib/project-secrets.sh` succeeds (no errexit at top — sourced-lib invariant).
    - `grep -q "refusing to write literal value into .mcp.json" scripts/lib/project-secrets.sh` succeeds (SEC-05 D-14 exact phrase).
    - `grep -q "shell metacharacters" scripts/lib/project-secrets.sh` succeeds (SEC-06 D-17 phrase).
    - `grep -q "claude-code-toolkit: never commit project-scope MCP secrets" scripts/lib/project-secrets.sh` succeeds (SEC-03 D-08 comment).
    - `grep -q "TK_PROJECT_SECRETS_ALLOW_LITERAL" scripts/lib/project-secrets.sh` succeeds (D-15 test seam).
    - `grep -q "TK_MCP_TTY_SRC" scripts/lib/project-secrets.sh` succeeds (D-05 reuse — NOT a new seam).
    - `shellcheck -S warning scripts/lib/project-secrets.sh` exits 0.
    - `bash -c "source scripts/lib/project-secrets.sh; declare -f project_secrets_write_env >/dev/null"` exits 0 (sourcing is a no-op + function defined).
    - No new file created outside `scripts/lib/project-secrets.sh` (the lib lives in one file; tests come in plan 02).
  </acceptance_criteria>

  <done>
    `scripts/lib/project-secrets.sh` exists with the four public functions (`project_secrets_write_env`, `project_secrets_ensure_gitignore`, `project_secrets_render_mcp_env_block`, `project_secrets_validate_mcp_env_block`) plus two private helpers (`_project_secrets_load_env`, `_project_secrets_index`). Lazy-sources `mcp.sh` to reuse `_mcp_validate_value` (D-16) and transitively pick up `tui_tty_read`. Shellcheck clean at `-S warning`. Sourcing has no side effects. SEC-01..06 surface contracts are visible via grep on the file (function names, error messages, test seam, gitignore comment phrase). Tests for these contracts ship in plan 37-02.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Caller (`mcp_wizard_run`, install.sh) → `project_secrets_write_env` | Untrusted user-supplied secret value crosses into a file that is read at every `claude` launch. |
| Caller → `project_secrets_render_mcp_env_block` | Untrusted (technically internal) key list crosses into JSON used to construct `.mcp.json` env block. |
| `claude mcp add` (or any wizard write path) → `project_secrets_validate_mcp_env_block` | Defense-in-depth boundary: the JSON env block is validated BEFORE it can be persisted into a repo-tracked file. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-37-01 | Tampering / Information Disclosure | `.mcp.json` env block (committed to repo) | mitigate | `project_secrets_validate_mcp_env_block` rejects any value not matching `^\$\{[A-Z_][A-Z0-9_]*\}$` and emits `✗ refusing to write literal value into .mcp.json` to stderr (SEC-05 / D-13/D-14). The wizard in Phase 38 will call this helper before invoking `claude mcp add`. |
| T-37-02 | Information Disclosure | `<project>/.env` committed to repo | mitigate | `project_secrets_ensure_gitignore` enforces an exact `^.env$` line in `<project>/.gitignore` before any `.env` write path is exercised by the wizard (SEC-03 / D-07/D-08). Idempotent on re-run; immune to false-positive `*.env` / `# .env` matches. |
| T-37-03 | Tampering / Code Injection | Shell-metacharacter values reaching `.env` | mitigate | `project_secrets_write_env` reuses `_mcp_validate_value` from `mcp.sh` (D-16) — rejects `$`, backtick, backslash, single-quote, double-quote, newline. Refusal returns rc=1 with stderr `✗ project_secrets_write_env: value for <KEY> contains shell metacharacters … — refusing to write` (SEC-06 / D-17). Sharing the helper means a single regression in the regex is caught by both `mcp_secrets_set` and `project_secrets_write_env` test surfaces. |
| T-37-04 | Information Disclosure | World-readable `<project>/.env` after a write | mitigate | `chmod 0600` is applied BEFORE the first byte is written and AGAIN after any rewrite path (D-04 steps 3 + 8). Defends against umask widening on the rewrite-via-`mktemp+mv` path (mktemp default permissions are 0600 already, but mv preserves, so the chmod-after is belt-and-suspenders against future file replacement strategies). |
| T-37-05 | Elevation of Privilege (test-only) | `TK_PROJECT_SECRETS_ALLOW_LITERAL=1` bypass | mitigate | The bypass emits a clearly visible `⚠ project_secrets: literal value allowed via TK_PROJECT_SECRETS_ALLOW_LITERAL — test seam only` warning to stderr on every honored use (D-15). Documented in code comment as test-only. Risk classed LOW — variable name carries `TEST` semantics by convention; production callers do not export it. |
| T-37-06 | Tampering | `_PROJECT_SECRETS_KEYS[]` namespace collision with `MCP_SECRET_*` arrays in callers that source both libs | mitigate | Private helpers use `_PROJECT_SECRETS_*` array namespace (D-03 + PATTERNS.md §_project_secrets_load_env). Audit L1 key guard `^[A-Z_][A-Z0-9_]*$` is preserved verbatim from `mcp.sh:474` so that any malformed line in `<project>/.env` is dropped, not exported. |
</threat_model>

<verification>
Single-task plan — task-level verification (above) is the phase-level verification for plan 01. End-to-end behavior is locked by the test suite in plan 37-02 (Wave 2). Manual verification optional:

```bash
# Source-and-poke smoke check
bash -c '
  source scripts/lib/project-secrets.sh
  echo "render-empty:" $(project_secrets_render_mcp_env_block)
  echo "render-two:" $(project_secrets_render_mcp_env_block FOO BAR)
  project_secrets_validate_mcp_env_block "{\"K\":\"\${K}\"}" && echo "validate-ok-OK"
  project_secrets_validate_mcp_env_block "{\"K\":\"literal\"}" 2>/dev/null && echo "validate-fail-WRONG" || echo "validate-fail-OK"
'
```

Expected output:

```text
render-empty: {}
render-two: {"FOO":"${FOO}","BAR":"${BAR}"}
validate-ok-OK
validate-fail-OK
```
</verification>

<success_criteria>
- [ ] `scripts/lib/project-secrets.sh` exists and contains the four public functions named exactly per D-01.
- [ ] `shellcheck -S warning scripts/lib/project-secrets.sh` exits 0.
- [ ] Sourcing the file produces zero filesystem side effects (verified by grep — no `mkdir`/`touch`/`chmod`/`>>`/`>` outside function bodies, no `set -e` at top level).
- [ ] D-16 reuse confirmed: `command -v _mcp_validate_value` lazy-source guard present; the regex from mcp.sh:431-441 is NOT duplicated in project-secrets.sh.
- [ ] D-05 reuse confirmed: `TK_MCP_TTY_SRC` referenced (no new TTY seam coined).
- [ ] D-15 test seam present: `TK_PROJECT_SECRETS_ALLOW_LITERAL` referenced.
- [ ] Threat model T-37-01..T-37-06 mitigations are visible in the file via the contract phrases listed in acceptance criteria.
</success_criteria>

<output>
After completion, create `.planning/phases/37-project-secrets-library/37-01-SUMMARY.md` summarizing:
- Files created: `scripts/lib/project-secrets.sh`
- Public API surface: 4 functions
- Reused contracts: `_mcp_validate_value` (mcp.sh:431) via lazy source, `tui_tty_read` (tui.sh:457) transitively
- Test seams added: `TK_PROJECT_SECRETS_ALLOW_LITERAL` (new); `TK_MCP_TTY_SRC` (reused)
- Deferred to plan 37-02: hermetic test suite, Makefile wiring, CI quality.yml range bump
- Deferred to Phase 41: `manifest.json` `files.libs[]` insertion at alpha order between `optional-plugins.sh` and `skills.sh` (per PATTERNS.md §`manifest.json` and ROADMAP DIST-01)
</output>
</content>
</invoke>